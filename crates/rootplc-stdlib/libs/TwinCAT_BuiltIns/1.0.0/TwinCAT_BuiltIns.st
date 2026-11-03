(* TwinCAT_BuiltIns compatibility library for RootPLC (see library.toml).

   BIT: a single bit, used as a structure member; RootPLC treats it as BOOL
   (the packing of BIT members into bytes only matters for memory layout).
   IQueryInterface: the base interface TwinCAT code writes as
   __SYSTEM.IQueryInterface; it declares no methods. *)

TYPE
    BIT : BOOL;
    (* special data types, 64-bit target (RootPLC's TwinCAT layout) *)
    XINT : LINT;
    UXINT : ULINT;
    XWORD : LWORD;
    PVOID : ULINT;
    __XINT : LINT;
    __UXINT : ULINT;
    __XWORD : LWORD;
END_TYPE

INTERFACE IQueryInterface
END_INTERFACE
