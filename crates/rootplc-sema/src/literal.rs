//! Values of literals (spec/01-lexical.md), in the representation units of
//! [types.elementary]: TIME in ms, LTIME in ns, DATE and DT in seconds since
//! 1970-01-01, TOD in ms since midnight, the L-forms in ns.

/// Integer literal body: `1_000`, `16#FF`, `-3`, `2#1010`.
pub fn parse_int(text: &str) -> Option<i128> {
    let t: String = text.chars().filter(|c| *c != '_').collect();
    let (neg, t) = match t.strip_prefix('-') {
        Some(r) => (true, r),
        None => (false, t.strip_prefix('+').unwrap_or(&t)),
    };
    let v = match t.split_once('#') {
        Some((b, d)) => i128::from_str_radix(d, b.parse::<u32>().ok()?).ok()?,
        None => t.parse::<i128>().ok()?,
    };
    Some(if neg { -v } else { v })
}

/// Real literal body.
pub fn parse_real(text: &str) -> Option<f64> {
    text.replace('_', "").parse::<f64>().ok()
}

/// Decode a quoted string literal, [lexical.literal.string].
pub fn decode_str(quoted: &str, wide: bool) -> String {
    let inner = quoted.get(1..quoted.len().saturating_sub(1)).unwrap_or("");
    let mut out = String::new();
    let mut it = inner.chars().peekable();
    while let Some(c) = it.next() {
        if c != '$' {
            out.push(c);
            continue;
        }
        match it.peek().copied() {
            Some(h) if h.is_ascii_hexdigit() => {
                let n = if wide { 4 } else { 2 };
                let hex: String = (0..n).filter_map(|_| it.next()).collect();
                if let Some(ch) = u32::from_str_radix(&hex, 16).ok().and_then(char::from_u32) {
                    out.push(ch);
                }
            }
            Some(e) => {
                it.next();
                out.push(match e.to_ascii_uppercase() {
                    'L' | 'N' => '\n',
                    'P' => '\u{c}',
                    'R' => '\r',
                    'T' => '\t',
                    other => other, // $$ $' $"
                });
            }
            None => {}
        }
    }
    out
}

/// Number of characters of a quoted string literal.
pub fn str_len(quoted: &str, wide: bool) -> usize {
    decode_str(quoted, wide).chars().count()
}

fn body(text: &str) -> &str {
    text.split_once('#').map_or(text, |(_, b)| b)
}

/// Duration literal in nanoseconds: `T#1h_30m`, `T#1.5s`, `t#-250ms`.
pub fn duration_ns(text: &str) -> Option<i128> {
    let b: String = body(text).chars().filter(|c| *c != '_').collect();
    let (neg, b) = match b.strip_prefix('-') {
        Some(r) => (true, r.to_string()),
        None => (false, b.trim_start_matches('+').to_string()),
    };
    let mut total = 0f64;
    let mut chars = b.chars().peekable();
    while chars.peek().is_some() {
        let num: String =
            std::iter::from_fn(|| chars.next_if(|c| c.is_ascii_digit() || *c == '.')).collect();
        let unit: String =
            std::iter::from_fn(|| chars.next_if(char::is_ascii_alphabetic)).collect();
        let n: f64 = num.parse().ok()?;
        let scale = match unit.to_ascii_lowercase().as_str() {
            "d" => 86_400e9,
            "h" => 3_600e9,
            "m" => 60e9,
            "s" => 1e9,
            "ms" => 1e6,
            "us" => 1e3,
            "ns" => 1.0,
            _ => return None,
        };
        total += n * scale;
    }
    let ns = total.round() as i128;
    Some(if neg { -ns } else { ns })
}

/// Days since 1970-01-01 of a proleptic Gregorian date.
pub fn days_from_civil(y: i64, m: i64, d: i64) -> i64 {
    let y = if m <= 2 { y - 1 } else { y };
    let era = y.div_euclid(400);
    let yoe = y - era * 400;
    let mp = (m + 9) % 12;
    let doy = (153 * mp + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

fn date_days(s: &str) -> Option<i64> {
    let mut p = s.splitn(3, '-').map(|x| x.parse::<i64>().ok());
    Some(days_from_civil(p.next()??, p.next()??, p.next()??))
}

fn tod_ns(s: &str) -> Option<i128> {
    let mut p = s.split(':');
    let h: i128 = p.next()?.parse().ok()?;
    let m: i128 = p.next()?.parse().ok()?;
    let sec: f64 = p.next().unwrap_or("0").parse().ok()?;
    Some((h * 3600 + m * 60) * 1_000_000_000 + (sec * 1e9).round() as i128)
}

/// Date literal: days since the epoch.
pub fn date_value(text: &str) -> Option<i64> {
    date_days(body(text))
}

/// Time-of-day literal: nanoseconds since midnight.
pub fn tod_value(text: &str) -> Option<i128> {
    tod_ns(body(text))
}

/// Date-and-time literal: nanoseconds since the epoch.
pub fn dt_value(text: &str) -> Option<i128> {
    let b = body(text);
    // YYYY-MM-DD-hh:mm:ss
    let idx = b.match_indices('-').nth(2)?.0;
    let days = date_days(&b[..idx])?;
    Some(i128::from(days) * 86_400 * 1_000_000_000 + tod_ns(&b[idx + 1..])?)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn values() {
        assert_eq!(parse_int("2#1010_0101"), Some(165));
        assert_eq!(decode_str("'it$'s $$5$N'", false), "it's $5\n");
        assert_eq!(decode_str("'$41'", false), "A");
        assert_eq!(str_len("\"温度\"", true), 2);
        assert_eq!(duration_ns("T#1h_30m"), Some(5_400_000_000_000));
        assert_eq!(duration_ns("t#-250ms"), Some(-250_000_000));
        assert_eq!(duration_ns("T#1.5s"), Some(1_500_000_000));
        assert_eq!(days_from_civil(1970, 1, 1), 0);
        assert_eq!(date_value("D#2026-11-03"), Some(20_760));
        assert_eq!(tod_value("TOD#14:30:00.5"), Some(52_200_500_000_000));
        assert_eq!(dt_value("DT#1970-01-02-00:00:01"), Some(86_401_000_000_000));
    }
}
