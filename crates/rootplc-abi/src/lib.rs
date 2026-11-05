//! Runtime ABI shared by codegen-c, the Rust runtime and the C shim: program image, I/O image, variable table, force masks.
//!
//! Roadmap phase: 2-3. See `ARCHITECTURE.md`. Version 0 (spec/14-runtime.md)
//! defines the process image ([runtime.image]), direct addresses, the
//! elementary values that cross the boundary and the [`Program`] a runtime
//! drives. The runtime never sees the compiler: an engine (today the VM,
//! later generated C) implements [`Program`].

use std::fmt;

/// ABI version. Bumped on any incompatible layout change.
pub const ABI_VERSION: u32 = 0;

/// Largest size of one image area in bytes, [runtime.image].
pub const MAX_AREA: usize = 65_536;

/// Image area of a direct address.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Area {
    /// `%I`: inputs, written by the I/O driver.
    Input,
    /// `%Q`: outputs, written by the program.
    Output,
    /// `%M`: memory, shared by the program and other image users.
    Memory,
}

/// Size of a direct address.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Size {
    /// `X` (or none): one bit.
    Bit,
    /// `B`: one byte.
    Byte,
    /// `W`: two bytes.
    Word,
    /// `D`: four bytes.
    DWord,
    /// `L`: eight bytes.
    LWord,
}

impl Size {
    /// Bytes the address occupies (a bit occupies part of one byte).
    pub fn bytes(self) -> usize {
        match self {
            Size::Bit | Size::Byte => 1,
            Size::Word => 2,
            Size::DWord => 4,
            Size::LWord => 8,
        }
    }
}

/// A direct address such as `%IX0.3` or `%QW4`, [variables.located].
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct Address {
    /// Image area.
    pub area: Area,
    /// Size.
    pub size: Size,
    /// Byte offset in the area.
    pub byte: usize,
    /// Bit within the byte (bit addresses only).
    pub bit: u8,
}

impl Address {
    /// Parse `%IX0.3`, `%I0.3`, `%QW4`, `%MD8` (case-insensitive). `%I*`
    /// and hierarchical addresses (`%IW1.2.3`) are not runnable in version 0.
    pub fn parse(text: &str) -> Result<Address, String> {
        let t = text.trim().to_ascii_uppercase();
        let bad = || format!("'{text}' is not a runnable direct address");
        let rest = t.strip_prefix('%').ok_or_else(bad)?;
        let mut cs = rest.chars();
        let area = match cs.next() {
            Some('I') => Area::Input,
            Some('Q') => Area::Output,
            Some('M') => Area::Memory,
            _ => return Err(bad()),
        };
        let rest = cs.as_str();
        if rest.starts_with('*') {
            return Err(format!(
                "'{text}' is not assigned to an address yet (%I* / %Q*)"
            ));
        }
        let (size, num) = match rest.chars().next() {
            Some('X') => (Size::Bit, &rest[1..]),
            Some('B') => (Size::Byte, &rest[1..]),
            Some('W') => (Size::Word, &rest[1..]),
            Some('D') => (Size::DWord, &rest[1..]),
            Some('L') => (Size::LWord, &rest[1..]),
            Some(c) if c.is_ascii_digit() => (Size::Bit, rest),
            _ => return Err(bad()),
        };
        let parts: Vec<&str> = num.split('.').collect();
        let int = |s: &str| s.parse::<usize>().map_err(|_| bad());
        let (byte, bit) = match (size, parts.as_slice()) {
            (Size::Bit, [b, x]) => (int(b)?, int(x)?),
            (Size::Bit, [b]) => (int(b)?, 0),
            (_, [b]) => (int(b)?, 0),
            _ => return Err(bad()),
        };
        if bit > 7 {
            return Err(format!("'{text}': a bit number is 0 to 7"));
        }
        if byte + size.bytes() > MAX_AREA {
            return Err(format!("'{text}' is beyond the {MAX_AREA}-byte image"));
        }
        Ok(Address {
            area,
            size,
            byte,
            bit: bit as u8,
        })
    }
}

impl fmt::Display for Address {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let a = match self.area {
            Area::Input => 'I',
            Area::Output => 'Q',
            Area::Memory => 'M',
        };
        match self.size {
            Size::Bit => write!(f, "%{a}X{}.{}", self.byte, self.bit),
            Size::Byte => write!(f, "%{a}B{}", self.byte),
            Size::Word => write!(f, "%{a}W{}", self.byte),
            Size::DWord => write!(f, "%{a}D{}", self.byte),
            Size::LWord => write!(f, "%{a}L{}", self.byte),
        }
    }
}

/// Elementary type of a variable that crosses the ABI.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Kind {
    /// BOOL.
    Bool,
    /// Signed integer of 1, 2, 4 or 8 bytes (SINT, INT, DINT, LINT).
    Int(u8),
    /// Unsigned integer or bit string of 1, 2, 4 or 8 bytes.
    UInt(u8),
    /// REAL.
    Real,
    /// LREAL.
    LReal,
    /// Any other type (durations, strings, structures): readable as text
    /// only, never located or retained in version 0.
    Other,
}

/// An elementary value.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Scalar {
    /// BOOL.
    Bool(bool),
    /// Signed integer.
    Int(i64),
    /// Unsigned integer or bit string.
    UInt(u64),
    /// REAL or LREAL.
    Real(f64),
}

impl fmt::Display for Scalar {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Scalar::Bool(b) => write!(f, "{}", if *b { "TRUE" } else { "FALSE" }),
            Scalar::Int(i) => write!(f, "{i}"),
            Scalar::UInt(u) => write!(f, "{u}"),
            Scalar::Real(x) => write!(f, "{x:?}"),
        }
    }
}

/// Does a kind fit a size? ([runtime.image.type])
pub fn fits(kind: Kind, size: Size) -> bool {
    matches!(
        (size, kind),
        (Size::Bit | Size::Byte, Kind::Bool)
            | (Size::Byte, Kind::Int(1) | Kind::UInt(1))
            | (Size::Word, Kind::Int(2) | Kind::UInt(2))
            | (Size::DWord, Kind::Int(4) | Kind::UInt(4) | Kind::Real)
            | (Size::LWord, Kind::Int(8) | Kind::UInt(8) | Kind::LReal)
    )
}

/// Read a value of `kind` at `addr` from an image area (little-endian).
pub fn load(area: &[u8], addr: Address, kind: Kind) -> Scalar {
    let n = addr.size.bytes();
    let mut b = [0u8; 8];
    if let Some(src) = area.get(addr.byte..addr.byte + n) {
        b[..n].copy_from_slice(src);
    }
    let raw = u64::from_le_bytes(b);
    match (addr.size, kind) {
        (Size::Bit, _) => Scalar::Bool(raw >> addr.bit & 1 == 1),
        (_, Kind::Bool) => Scalar::Bool(raw != 0),
        (_, Kind::Real) => Scalar::Real(f64::from(f32::from_bits(raw as u32))),
        (_, Kind::LReal) => Scalar::Real(f64::from_bits(raw)),
        (_, Kind::Int(w)) => {
            let shift = 64 - 8 * u32::from(w);
            Scalar::Int(((raw << shift) as i64) >> shift)
        }
        _ => Scalar::UInt(raw),
    }
}

/// Write `v` at `addr` into an image area (little-endian).
pub fn store(area: &mut [u8], addr: Address, v: Scalar) {
    let n = addr.size.bytes();
    let Some(dst) = area.get_mut(addr.byte..addr.byte + n) else {
        return;
    };
    if addr.size == Size::Bit {
        let on = matches!(v, Scalar::Bool(true))
            || matches!(v, Scalar::Int(i) if i != 0)
            || matches!(v, Scalar::UInt(u) if u != 0);
        if on {
            dst[0] |= 1 << addr.bit;
        } else {
            dst[0] &= !(1 << addr.bit);
        }
        return;
    }
    let raw: u64 = match v {
        Scalar::Bool(b) => u64::from(b),
        Scalar::Int(i) => i as u64,
        Scalar::UInt(u) => u,
        Scalar::Real(x) if n == 4 => u64::from((x as f32).to_bits()),
        Scalar::Real(x) => x.to_bits(),
    };
    dst.copy_from_slice(&raw.to_le_bytes()[..n]);
}

/// One variable of a program, as the runtime sees it.
#[derive(Debug, Clone, PartialEq)]
pub struct VarInfo {
    /// Name, e.g. `start_btn` or a global's name.
    pub name: String,
    /// Elementary type.
    pub kind: Kind,
    /// Type name for reports, e.g. `INT`.
    pub type_name: String,
    /// Direct address text as declared (`AT %IX0.0`), upper case.
    pub at: Option<String>,
    /// Declared in a RETAIN section.
    pub retain: bool,
}

/// A program a runtime can drive, one call per cycle ([runtime.cycle]).
pub trait Program {
    /// The variables the runtime can see: the program's own and those of
    /// global variable lists.
    fn vars(&self) -> &[VarInfo];
    /// Read variable `i` (index into [`Program::vars`]); `None` for a
    /// non-elementary variable.
    fn read(&self, i: usize) -> Option<Scalar>;
    /// Value of variable `i` as IEC literal text.
    fn text(&self, i: usize) -> String;
    /// Write variable `i`; false if it is not elementary.
    fn write(&mut self, i: usize, v: Scalar) -> bool;
    /// Run one cycle; `elapsed_ns` is the time since the previous cycle
    /// started (0 for the first). An error is a fault.
    fn cycle(&mut self, elapsed_ns: u64) -> Result<(), String>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn addresses_parse_and_print() {
        let a = Address::parse("%ix0.3").expect("bit");
        assert_eq!(
            (a.area, a.size, a.byte, a.bit),
            (Area::Input, Size::Bit, 0, 3)
        );
        assert_eq!(a.to_string(), "%IX0.3");
        assert_eq!(
            Address::parse("%I2.7").expect("short").to_string(),
            "%IX2.7"
        );
        assert_eq!(Address::parse("%QW4").expect("word").size, Size::Word);
        assert!(Address::parse("%I*").is_err());
        assert!(Address::parse("%IX0.8").is_err());
        assert!(Address::parse("%QW65535").is_err());
    }

    #[test]
    fn values_round_trip_little_endian() {
        let mut img = vec![0u8; 16];
        let w = Address::parse("%QW2").expect("w");
        store(&mut img, w, Scalar::Int(-2));
        assert_eq!(&img[2..4], &[0xFE, 0xFF]);
        assert_eq!(load(&img, w, Kind::Int(2)), Scalar::Int(-2));
        let d = Address::parse("%QD4").expect("d");
        store(&mut img, d, Scalar::Real(1.5));
        assert_eq!(load(&img, d, Kind::Real), Scalar::Real(1.5));
        let x = Address::parse("%QX0.5").expect("x");
        store(&mut img, x, Scalar::Bool(true));
        assert_eq!(img[0], 0x20);
        assert_eq!(load(&img, x, Kind::Bool), Scalar::Bool(true));
        store(&mut img, x, Scalar::Bool(false));
        assert_eq!(img[0], 0);
        assert!(fits(Kind::Real, Size::DWord) && !fits(Kind::Int(2), Size::Bit));
    }
}
