(* TwinCAT_BuiltIns compatibility library for RootPLC (see library.toml).

   BIT: a single bit, used as a structure member; RootPLC treats it as BOOL
   (the packing of BIT members into bytes only matters for memory layout).
   IQueryInterface: the base interface TwinCAT code writes as
   __SYSTEM.IQueryInterface; it declares no methods. *)

TYPE
    BIT : BOOL;
END_TYPE

INTERFACE IQueryInterface
END_INTERFACE
