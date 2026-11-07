//! Types of the checker (spec/02-types.md).

/// An elementary type, [types.elementary].
#[allow(missing_docs)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Elem {
    Bool,
    Sint,
    Int,
    Dint,
    Lint,
    Usint,
    Uint,
    Udint,
    Ulint,
    Real,
    Lreal,
    Byte,
    Word,
    Dword,
    Lword,
    Time,
    Ltime,
    Date,
    Tod,
    Dt,
    Ldate,
    Ltod,
    Ldt,
    Char,
    Wchar,
}

use Elem::*;

impl Elem {
    /// Look up an elementary type name (case-insensitive). `STRING` and
    /// `WSTRING` are not elementary here; see [`Ty::Str`].
    pub fn from_name(s: &str) -> Option<Elem> {
        Some(match s.to_ascii_uppercase().as_str() {
            "BOOL" => Bool,
            "SINT" => Sint,
            "INT" => Int,
            "DINT" => Dint,
            "LINT" => Lint,
            "USINT" => Usint,
            "UINT" => Uint,
            "UDINT" => Udint,
            "ULINT" => Ulint,
            "REAL" => Real,
            "LREAL" => Lreal,
            "BYTE" => Byte,
            "WORD" => Word,
            "DWORD" => Dword,
            "LWORD" => Lword,
            "TIME" => Time,
            "LTIME" => Ltime,
            "DATE" => Date,
            "TIME_OF_DAY" | "TOD" => Tod,
            "DATE_AND_TIME" | "DT" => Dt,
            "LDATE" => Ldate,
            "LTIME_OF_DAY" | "LTOD" => Ltod,
            "LDATE_AND_TIME" | "LDT" => Ldt,
            "CHAR" => Char,
            "WCHAR" => Wchar,
            _ => return None,
        })
    }

    /// Canonical name.
    pub fn name(self) -> &'static str {
        match self {
            Bool => "BOOL",
            Sint => "SINT",
            Int => "INT",
            Dint => "DINT",
            Lint => "LINT",
            Usint => "USINT",
            Uint => "UINT",
            Udint => "UDINT",
            Ulint => "ULINT",
            Real => "REAL",
            Lreal => "LREAL",
            Byte => "BYTE",
            Word => "WORD",
            Dword => "DWORD",
            Lword => "LWORD",
            Time => "TIME",
            Ltime => "LTIME",
            Date => "DATE",
            Tod => "TOD",
            Dt => "DT",
            Ldate => "LDATE",
            Ltod => "LTOD",
            Ldt => "LDT",
            Char => "CHAR",
            Wchar => "WCHAR",
        }
    }

    /// Value range of integer and bit-string types (bit strings as unsigned).
    pub fn int_range(self) -> Option<(i128, i128)> {
        Some(match self {
            Sint => (-128, 127),
            Int => (-32_768, 32_767),
            Dint => (i128::from(i32::MIN), i128::from(i32::MAX)),
            Lint => (i128::from(i64::MIN), i128::from(i64::MAX)),
            Usint | Byte => (0, 255),
            Uint | Word => (0, 65_535),
            Udint | Dword => (0, i128::from(u32::MAX)),
            Ulint | Lword => (0, i128::from(u64::MAX)),
            _ => return None,
        })
    }

    /// `ANY_INT`.
    pub fn is_int(self) -> bool {
        matches!(
            self,
            Sint | Int | Dint | Lint | Usint | Uint | Udint | Ulint
        )
    }

    /// `ANY_REAL`.
    pub fn is_real(self) -> bool {
        matches!(self, Real | Lreal)
    }

    /// `ANY_NUM`.
    pub fn is_num(self) -> bool {
        self.is_int() || self.is_real()
    }

    /// `ANY_BIT`.
    pub fn is_bit(self) -> bool {
        matches!(self, Bool | Byte | Word | Dword | Lword)
    }

    /// `ANY_DURATION`.
    pub fn is_duration(self) -> bool {
        matches!(self, Time | Ltime)
    }

    /// Nanoseconds per stored unit of a time type ([types.elementary]):
    /// milliseconds for `TIME` and `TOD`, seconds for `DATE` and `DT`,
    /// nanoseconds for the `L` forms; `None` for other types.
    pub fn time_unit_ns(self) -> Option<i128> {
        match self {
            Time | Tod => Some(1_000_000),
            Date | Dt => Some(1_000_000_000),
            Ltime | Ldate | Ltod | Ldt => Some(1),
            _ => None,
        }
    }

    fn direct(self) -> &'static [Elem] {
        match self {
            Sint => &[Int, Dint, Lint, Real, Lreal],
            Int => &[Dint, Lint, Real, Lreal],
            Dint => &[Lint, Lreal],
            Usint => &[Uint, Udint, Ulint, Int, Dint, Lint, Real, Lreal],
            Uint => &[Udint, Ulint, Dint, Lint, Real, Lreal],
            Udint => &[Ulint, Lint, Lreal],
            Real => &[Lreal],
            Bool => &[Byte],
            Byte => &[Word],
            Word => &[Dword],
            Dword => &[Lword],
            Time => &[Ltime],
            Date => &[Ldate],
            Tod => &[Ltod],
            Dt => &[Ldt],
            _ => &[],
        }
    }

    /// Implicit conversion allowed, [types.conversion.implicit] (transitive).
    pub fn widens_to(self, to: Elem) -> bool {
        self == to || self.direct().iter().any(|d| d.widens_to(to))
    }
}

/// A type as the checker sees it.
#[derive(Debug, Clone, PartialEq)]
pub enum Ty {
    /// Elementary type.
    Elem(Elem),
    /// `STRING[len]` or `WSTRING[len]`.
    Str {
        /// `WSTRING`.
        wide: bool,
        /// Declared length in characters.
        len: u32,
    },
    /// Array; a dimension is `None` for `*` or non-constant bounds.
    Array {
        /// Bounds per dimension.
        dims: Vec<Option<(i128, i128)>>,
        /// Element type.
        elem: Box<Ty>,
    },
    /// `REF_TO T`.
    Ref(Box<Ty>),
    /// A declared type (structure, enumeration, subrange, POU) by index.
    Named(usize),
    /// Untyped integer literal or constant expression.
    IntLit,
    /// Untyped real literal.
    RealLit,
    /// `NULL`.
    Null,
    /// Unknown after an error, or not checked in this version; never reported.
    Unknown,
}

/// Default string length, [types.elementary].
pub const DEFAULT_STRING_LEN: u32 = 80;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn widening_follows_the_table() {
        assert!(Sint.widens_to(Lreal));
        assert!(Usint.widens_to(Int));
        assert!(Bool.widens_to(Lword));
        assert!(!Dint.widens_to(Real));
        assert!(!Int.widens_to(Sint));
        assert!(!Int.widens_to(Uint));
        assert!(!Int.widens_to(Bool));
        assert!(!Int.widens_to(Word));
    }
}
