//! Modbus TCP server on the process image ([runtime.modbus]).
//!
//! Register *n* is bytes 2n and 2n+1 of an area as one little-endian word;
//! bit *n* is bit n mod 8 of byte n / 8. Coils read `%QX`, discrete inputs
//! read `%IX`, holding registers 0–32767 are `%M` (read/write) and 32768–
//! are `%I` (writable only without an I/O driver), input registers 0–32767
//! are `%I` and 32768– are `%Q`. Outputs are never written over Modbus.

use std::io::{Read, Write};
use std::net::{SocketAddr, TcpListener, TcpStream};
use std::sync::{Arc, Mutex};

use crate::Image;

const ILLEGAL_FUNCTION: u8 = 1;
const ILLEGAL_ADDRESS: u8 = 2;
const ILLEGAL_VALUE: u8 = 3;
const SECOND_BANK: usize = 32_768;

fn exception(func: u8, code: u8) -> Vec<u8> {
    vec![func | 0x80, code]
}

fn word(area: &[u8], reg: usize) -> Option<u16> {
    let b = area.get(2 * reg..2 * reg + 2)?;
    Some(u16::from_le_bytes([b[0], b[1]]))
}

fn be(pdu: &[u8], at: usize) -> usize {
    usize::from(u16::from_be_bytes([pdu[at], pdu[at + 1]]))
}

/// Answer one Modbus request PDU (function code and data) against the
/// image. `inputs_writable`: no I/O driver owns the inputs.
pub fn handle(pdu: &[u8], img: &mut Image, inputs_writable: bool) -> Vec<u8> {
    let Some(&func) = pdu.first() else {
        return exception(0, ILLEGAL_FUNCTION);
    };
    match func {
        1 | 2 => {
            if pdu.len() < 5 {
                return exception(func, ILLEGAL_VALUE);
            }
            let (start, count) = (be(pdu, 1), be(pdu, 3));
            if count == 0 || count > 2000 {
                return exception(func, ILLEGAL_VALUE);
            }
            let area = if func == 1 { &img.output } else { &img.input };
            if (start + count).div_ceil(8) > area.len() {
                return exception(func, ILLEGAL_ADDRESS);
            }
            let mut bytes = vec![0u8; count.div_ceil(8)];
            for i in 0..count {
                let n = start + i;
                if area[n / 8] >> (n % 8) & 1 == 1 {
                    bytes[i / 8] |= 1 << (i % 8);
                }
            }
            let mut out = vec![func, bytes.len() as u8];
            out.extend(bytes);
            out
        }
        3 | 4 => {
            if pdu.len() < 5 {
                return exception(func, ILLEGAL_VALUE);
            }
            let (start, count) = (be(pdu, 1), be(pdu, 3));
            if count == 0 || count > 125 {
                return exception(func, ILLEGAL_VALUE);
            }
            let (area, first) = match (func, start >= SECOND_BANK) {
                (3, false) => (&img.memory, start),
                (3, true) => (&img.input, start - SECOND_BANK),
                (_, false) => (&img.input, start),
                (_, true) => (&img.output, start - SECOND_BANK),
            };
            let mut out = vec![func, (2 * count) as u8];
            for r in first..first + count {
                match word(area, r) {
                    Some(w) => out.extend(w.to_be_bytes()),
                    None => return exception(func, ILLEGAL_ADDRESS),
                }
            }
            out
        }
        6 | 16 => {
            let (start, values): (usize, Vec<u16>) = if func == 6 {
                if pdu.len() < 5 {
                    return exception(func, ILLEGAL_VALUE);
                }
                (be(pdu, 1), vec![be(pdu, 3) as u16])
            } else {
                if pdu.len() < 6 {
                    return exception(func, ILLEGAL_VALUE);
                }
                let (start, count, n) = (be(pdu, 1), be(pdu, 3), usize::from(pdu[5]));
                if count == 0 || count > 123 || n != 2 * count || pdu.len() < 6 + n {
                    return exception(func, ILLEGAL_VALUE);
                }
                (
                    start,
                    (0..count).map(|i| be(pdu, 6 + 2 * i) as u16).collect(),
                )
            };
            let area = if start >= SECOND_BANK {
                if !inputs_writable {
                    return exception(func, ILLEGAL_ADDRESS);
                }
                &mut img.input
            } else {
                &mut img.memory
            };
            let first = start % SECOND_BANK;
            if 2 * (first + values.len()) > area.len() {
                return exception(func, ILLEGAL_ADDRESS);
            }
            for (i, v) in values.iter().enumerate() {
                area[2 * (first + i)..2 * (first + i) + 2].copy_from_slice(&v.to_le_bytes());
            }
            // FC 6 echoes the request; FC 16 answers address and count
            pdu[..5].to_vec()
        }
        _ => exception(func, ILLEGAL_FUNCTION),
    }
}

fn serve_client(mut s: TcpStream, image: Arc<Mutex<Image>>, inputs_writable: bool) {
    let mut head = [0u8; 7];
    while s.read_exact(&mut head).is_ok() {
        let len = usize::from(u16::from_be_bytes([head[4], head[5]]));
        if !(2..=254).contains(&len) {
            return;
        }
        let mut pdu = vec![0u8; len - 1];
        if s.read_exact(&mut pdu).is_err() {
            return;
        }
        let reply = {
            let mut img = image.lock().unwrap_or_else(|e| e.into_inner());
            handle(&pdu, &mut img, inputs_writable)
        };
        let mut out = head[..4].to_vec();
        out.extend(((reply.len() + 1) as u16).to_be_bytes());
        out.push(head[6]);
        out.extend(reply);
        if s.write_all(&out).is_err() {
            return;
        }
    }
}

/// Listen on `addr` (`PORT` alone means 127.0.0.1:PORT) and serve every
/// client in its own thread. Returns the bound address.
pub fn serve(
    addr: &str,
    image: Arc<Mutex<Image>>,
    inputs_writable: bool,
) -> std::io::Result<SocketAddr> {
    let addr = if addr.contains(':') {
        addr.to_string()
    } else {
        format!("127.0.0.1:{addr}")
    };
    let listener = TcpListener::bind(&addr)?;
    let bound = listener.local_addr()?;
    std::thread::spawn(move || {
        for s in listener.incoming().flatten() {
            let image = Arc::clone(&image);
            std::thread::spawn(move || serve_client(s, image, inputs_writable));
        }
    });
    Ok(bound)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn img() -> Image {
        Image {
            input: vec![0b0000_0101, 0, 0x34, 0x12],
            output: vec![0b1000_0001, 0, 0xFF, 0x00],
            memory: vec![0; 4],
        }
    }

    #[test]
    fn reads_bits_and_registers() {
        let mut i = img();
        assert_eq!(
            handle(&[1, 0, 0, 0, 8], &mut i, true),
            vec![1, 1, 0b1000_0001]
        );
        assert_eq!(handle(&[2, 0, 1, 0, 2], &mut i, true), vec![2, 1, 0b10]);
        // %IW2 = 0x1234 is input register 1
        assert_eq!(
            handle(&[4, 0, 1, 0, 1], &mut i, true),
            vec![4, 2, 0x12, 0x34]
        );
        // %QW2 = 255 is input register 32768 + 1
        assert_eq!(
            handle(&[4, 0x80, 1, 0, 1], &mut i, true),
            vec![4, 2, 0x00, 0xFF]
        );
    }

    #[test]
    fn writes_memory_and_inputs_only_when_allowed() {
        let mut i = img();
        assert_eq!(
            handle(&[6, 0, 1, 0x00, 0x2A], &mut i, false),
            vec![6, 0, 1, 0, 0x2A]
        );
        assert_eq!(&i.memory[2..4], &[0x2A, 0]);
        let w16 = [16, 0x80, 0, 0, 1, 2, 0x00, 0x07];
        assert_eq!(handle(&w16, &mut i, false), vec![0x90, ILLEGAL_ADDRESS]);
        assert_eq!(handle(&w16, &mut i, true), vec![16, 0x80, 0, 0, 1]);
        assert_eq!(i.input[0], 7);
        // outputs are never written; unknown functions are refused
        assert_eq!(
            handle(&[5, 0, 0, 0xFF, 0], &mut i, true),
            vec![0x85, ILLEGAL_FUNCTION]
        );
        assert_eq!(
            handle(&[3, 0, 9, 0, 1], &mut i, true),
            vec![0x83, ILLEGAL_ADDRESS]
        );
    }

    #[test]
    fn serves_over_tcp() {
        let image = Arc::new(Mutex::new(img()));
        let addr = serve("0", Arc::clone(&image), true).expect("bind");
        let mut c = TcpStream::connect(addr).expect("connect");
        // transaction 7, read input register 1
        c.write_all(&[0, 7, 0, 0, 0, 6, 1, 4, 0, 1, 0, 1])
            .expect("send");
        let mut r = [0u8; 11];
        c.read_exact(&mut r).expect("reply");
        assert_eq!(r, [0, 7, 0, 0, 0, 5, 1, 4, 2, 0x12, 0x34]);
    }
}
