(* Tc3_JsonXml compatibility library for RootPLC (see library.toml).

   Written from the public library manual (TE1000 PLC Lib: Tc3_JsonXml,
   version 1.15.0).

   FB_JsonSaxWriter is implemented: it builds the JSON text in RootPLC, so
   structure, keys, strings, integers, booleans, null, raw JSON and
   DATE_AND_TIME values (written as "2017-04-04T12:42:42", the form the
   manual shows) come out as in TwinCAT. Its LREAL / REAL methods, the
   decimal-places setting and the Base64 / hex binary methods are declared
   only: the manual does not define how numbers are formatted, and the
   binary methods need pointer arithmetic. Where the manual is silent,
   RootPLC escapes the double quote and the backslash with a backslash and
   control characters as \b \f \n \r \t or \u00XX, and returns S_OK from
   StartObject / EndObject and the like. The document holds up to 65535
   characters.

   The DOM and SAX parsers, the pretty writer, FB_JsonReadWriteDataType
   (it needs the symbol information of the PLC), FB_XmlDomParser and
   FB_JwtEncode are declared but not implemented (library.toml
   declare_only): calls type-check and give warning RP0120, and running one
   stops with UNSUPPORTED.

   Differences from the manual, all because the manual does not publish the
   definition:
   - SJsonValue, SJsonIterator, SJsonAIterator, SXmlNode, SXmlAttribute and
     SXmlIterator are opaque handles, declared as PVOID; TcJsonLevelInfo is
     declared without members;
   - the methods that take DCTIME or FILETIME values are left out;
   - where a method's syntax block repeats another method's name (a copy
     error in the manual), the section's own name and sample call are used:
     FB_JsonDomParser.AddInt64Member, FB_JsonReadWriteDataType
     .AddJsonKeyPropertiesFromSymbol / .AddJsonKeyValueFromSymbol,
     FB_XmlDomParser.Child, ITcJsonSaxValues.OnNullValue.
   FB_JsonDynDomParser has the same methods as FB_JsonDomParser, as the
   manual says. *)

TYPE
    SJsonValue : PVOID;
    SJsonIterator : PVOID;
    SJsonAIterator : PVOID;
    SXmlNode : PVOID;
    SXmlAttribute : PVOID;
    SXmlIterator : PVOID;
END_TYPE

TYPE TcJsonLevelInfo :
STRUCT
END_STRUCT
END_TYPE

TYPE EJsonType :
(
    eNullType   := 0,
    eFalseType  := 1,
    eTrueType   := 2,
    eObjectType := 3,
    eArrayType  := 4,
    eStringType := 5,
    eNumberType := 6
) DINT;
END_TYPE

TYPE EJsonPrettyFormatOptions :
(
    eFormatDefault := 0,
    eFormatSingleLineArray := 1
) DINT;
END_TYPE

FUNCTION_BLOCK FB_JwtEncode
VAR_INPUT
    bExecute       : BOOL;
    sHeaderAlg     : STRING(46);
    sPayload       : STRING(1023);
    sKeyFilePath   : STRING(511);
    tTimeout       : TIME;
    pKey           : PVOID;
    nKeySize       : UDINT;
    nJwtSize       : UDINT;
END_VAR
VAR_IN_OUT CONSTANT
    sJwt           : STRING;
END_VAR
VAR_OUTPUT
    bBusy          : BOOL;
    bError         : BOOL;
    hrErrorCode    : HRESULT;
    initStatus     : HRESULT;
END_VAR
END_FUNCTION_BLOCK

INTERFACE ITcJsonSaxHandler
METHOD OnBool : HRESULT
VAR_INPUT
    value : BOOL;
END_VAR
END_METHOD
METHOD OnDint : HRESULT
VAR_INPUT
    value : DINT;
END_VAR
END_METHOD
METHOD OnEndArray : HRESULT
END_METHOD
METHOD OnEndObject : HRESULT
END_METHOD
METHOD OnKey : HRESULT
VAR_IN_OUT CONSTANT
    key : STRING;
END_VAR
VAR_INPUT
    len : UDINT;
END_VAR
END_METHOD
METHOD OnLint : HRESULT
VAR_INPUT
    value : LINT;
END_VAR
END_METHOD
METHOD OnLreal : HRESULT
VAR_INPUT
    value : LREAL;
END_VAR
END_METHOD
METHOD OnNull : HRESULT
END_METHOD
METHOD OnStartArray : HRESULT
END_METHOD
METHOD OnStartObject : HRESULT
END_METHOD
METHOD OnString : HRESULT
VAR_IN_OUT CONSTANT
    value : STRING;
END_VAR
VAR_INPUT
    len   : UDINT;
END_VAR
END_METHOD
METHOD OnUdint : HRESULT
VAR_INPUT
    value : UDINT;
END_VAR
END_METHOD
METHOD OnUlint : HRESULT
VAR_INPUT
    value : ULINT;
END_VAR
END_METHOD
END_INTERFACE

INTERFACE ITcJsonSaxValues
METHOD OnBoolValue : HRESULT
VAR_INPUT
    level : UDINT;
    infos : POINTER TO TcJsonLevelInfo;
    value : BOOL;
END_VAR
END_METHOD
METHOD OnDintValue : HRESULT
VAR_INPUT
    level : UDINT;
    infos : POINTER TO TcJsonLevelInfo;
    value : DINT;
END_VAR
END_METHOD
METHOD OnLintValue : HRESULT
VAR_INPUT
    level : UDINT;
    infos : POINTER TO TcJsonLevelInfo;
    value : LINT;
END_VAR
END_METHOD
METHOD OnLrealValue : HRESULT
VAR_INPUT
    level : UDINT;
    infos : POINTER TO TcJsonLevelInfo;
    value : LREAL;
END_VAR
END_METHOD
METHOD OnNullValue : HRESULT
VAR_INPUT
    level : UDINT;
    infos : POINTER TO TcJsonLevelInfo;
END_VAR
END_METHOD
METHOD OnStringValue : HRESULT
VAR_IN_OUT CONSTANT
    value : STRING;
END_VAR
VAR_INPUT
    len : UDINT;
    level : UDINT;
    infos : POINTER TO TcJsonLevelInfo;
END_VAR
END_METHOD
END_INTERFACE

FUNCTION_BLOCK FB_JsonDomParser
VAR_OUTPUT
    initStatus : HRESULT;
END_VAR
METHOD LoadDocumentFromFile : BOOL
VAR_IN_OUT CONSTANT
    sFile      : STRING;
END_VAR
VAR_INPUT
    bExec      : REFERENCE TO BOOL;
END_VAR
VAR_OUTPUT
    hrErrorCode: HRESULT;
END_VAR
END_METHOD
METHOD AddArrayMember : SJsonValue
VAR_INPUT
    v       : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member  : STRING;
END_VAR
VAR_INPUT
    reserve : UDINT;
END_VAR
END_METHOD
METHOD AddBase64Member : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    p      : PVOID;
    n      : DINT;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddBoolMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    value  : BOOL;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddDateTimeMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    value  : DATE_AND_TIME;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddDoubleMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    value  : LREAL;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddHexBinaryMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    p      : PVOID;
    n      : DINT;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddInt64Member : SjsonValue
VAR_INPUT
    v      : SjsonValue;
    value  : LINT;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddIntMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    value  : DINT;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddJsonMember : SJsonValue
VAR_INPUT
    v       : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member  : STRING;
    rawJson : STRING;
END_VAR
END_METHOD
METHOD AddNullMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddObjectMember : SJsonValue
VAR_INPUT
    v       : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddStringMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
    value  : STRING;
END_VAR
END_METHOD
METHOD AddUint64Member : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    value  : ULINT;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddUintMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    value  : UDINT;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD ArrayBegin : SJsonAIterator
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD ArrayEnd : SJsonAIterator
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD ClearArray : BOOL
VAR_INPUT
    v : SJsonValue;
    i : SJsonAIterator;
END_VAR
END_METHOD
METHOD CopyDocument : UDINT
VAR_INPUT
    nDoc : DINT;
END_VAR
VAR_IN_OUT CONSTANT
    pDoc : STRING;
END_VAR
END_METHOD
METHOD CopyFrom : SJsonValue
VAR_INPUT
    v : SJsonValue;
    w : SJsonValue;
END_VAR
END_METHOD
METHOD CopyJson : UDINT
VAR_INPUT
    v    : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    pDoc : STRING;
    nDoc : UDINT;
END_VAR
END_METHOD
METHOD CopyString : UDINT
VAR_INPUT
    v    : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    pStr : STRING;
    nStr : UDINT;
END_VAR
END_METHOD
METHOD ExceptionRaised : BOOL
END_METHOD
METHOD FindMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD FindMemberPath : SJsonValue
VAR_INPUT
    v      : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD GetArraySize : UDINT
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetArrayValue : SJsonValue
VAR_INPUT
    i : SJsonAIterator;
END_VAR
END_METHOD
METHOD GetArrayValueByIdx : SJsonValue
VAR_INPUT
    v   : SJsonValue;
    idx : UDINT;
END_VAR
END_METHOD
METHOD GetBase64 : DINT
VAR_INPUT
    v : SJsonValue;
    p : PVOID;
    n : DINT;
END_VAR
END_METHOD
METHOD GetBool : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetDateTime : DATE_AND_TIME
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetDocument : STRING(255)
END_METHOD
METHOD GetDocumentLength : UDINT
END_METHOD
METHOD GetDocumentRoot : SJsonValue
END_METHOD
METHOD GetDouble : LREAL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetHexBinary : DINT
VAR_INPUT
    v : SJsonValue;
    p : PVOID;
    n : DINT;
END_VAR
END_METHOD
METHOD GetInt : DINT
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetInt64 : LINT
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetJson : STRING(255)
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetJsonLength : UDINT
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetMaxDecimalPlaces : DINT
END_METHOD
METHOD GetMemberName : STRING(255)
VAR_INPUT
    i : SJsonIterator;
END_VAR
END_METHOD
METHOD GetMemberValue : SJsonValue
VAR_INPUT
    i : SJsonIterator;
END_VAR
END_METHOD
METHOD GetString : STRING(255)
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetStringLength : UDINT
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetType : EJsonType
VAR_INPUT
    v            : SJsonValue;
END_VAR
END_METHOD
METHOD GetUint : UDINT
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetUint64 : ULINT
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD HasMember : BOOL
VAR_INPUT
    v      : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD IsArray : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsBase64 : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsBool : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsDouble : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsFalse : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsHexBinary : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsInt : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsInt64 : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsISO8601TimeFormat : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsNull : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsNumber : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsObject : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsString : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsTrue : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsUint : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsUint64 : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD MemberBegin : SJsonIterator
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD MemberEnd : SJsonIterator
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD NewDocument : SJsonValue
END_METHOD
METHOD NextArray : SJsonAIterator
VAR_INPUT
    v : SJsonAIterator;
END_VAR
END_METHOD
METHOD NextMember : SJsonIterator
VAR_INPUT
    v : SJsonIterator;
END_VAR
END_METHOD
METHOD ParseDocument : SJsonValue
VAR_IN_OUT CONSTANT
    sJson : STRING;
END_VAR
END_METHOD
METHOD PushbackBase64Value : SJsonValue
VAR_INPUT
    v : SJsonValue;
    p : PVOID;
    n : DINT;
END_VAR
END_METHOD
METHOD PushbackBoolValue : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : BOOL;
END_VAR
END_METHOD
METHOD PushbackCopyValue : SJsonValue
VAR_INPUT
    v       : SJsonValue;
    json    : SJsonValue;
END_VAR
END_METHOD
METHOD PushbackDateTimeValue : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : DATE_AND_TIME;
END_VAR
END_METHOD
METHOD PushbackDoubleValue : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : LREAL;
END_VAR
END_METHOD
METHOD PushbackHexBinaryValue : SJsonValue
VAR_INPUT
    v : SJsonValue;
    p : PVOID;
    n : DINT;
END_VAR
END_METHOD
METHOD PushbackInt64Value : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : LINT;
END_VAR
END_METHOD
METHOD PushbackIntValue : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : DINT;
END_VAR
END_METHOD
METHOD PushbackJsonValue : SJsonValue
VAR_INPUT
    v       : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    rawJson : STRING;
END_VAR
END_METHOD
METHOD PushbackNullValue : SJsonValue
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD PushbackStringValue : SJsonValue
VAR_INPUT
    v     : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    value : STRING;
END_VAR
END_METHOD
METHOD PushbackUint64Value : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : ULINT;
END_VAR
END_METHOD
METHOD PushbackUintValue : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : UDINT;
END_VAR
END_METHOD
METHOD RemoveAllMembers : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD RemoveArray : BOOL
VAR_INPUT
    v : SJsonValue;
    i : SJsonAIterator;
END_VAR
END_METHOD
METHOD RemoveMember : BOOL
VAR_INPUT
    v : SJsonValue;
    i : SJsonIterator;
    keepOrder : BOOL;
END_VAR
END_METHOD
METHOD RemoveMemberByName : BOOL
VAR_INPUT
    v         : SJsonValue;
    keepOrder : BOOL;
END_VAR
VAR_IN_OUT CONSTANT
    member  : STRING;
END_VAR
END_METHOD
METHOD SaveDocumentToFile : BOOL
VAR_IN_OUT CONSTANT
    sFile    : STRING;
END_VAR
VAR_INPUT
    bExec    : REFERENCE TO BOOL;
END_VAR
VAR_OUTPUT
    hrErrorCode: HRESULT;
END_VAR
END_METHOD
METHOD SetAdsProvider : BOOL
VAR_INPUT
    oid : OTCID;
END_VAR
END_METHOD
METHOD SetArray : SJsonValue
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD SetBase64 : SJsonValue
VAR_INPUT
    v : SJsonValue;
    p : PVOID;
    n : DINT;
END_VAR
END_METHOD
METHOD SetBool : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : BOOL;
END_VAR
END_METHOD
METHOD SetDateTime : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : DATE_AND_TIME;
END_VAR
END_METHOD
METHOD SetDouble : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : LREAL;
END_VAR
END_METHOD
METHOD SetHexBinary : SJsonValue
VAR_INPUT
    v : SJsonValue;
    p : PVOID;
    n : DINT;
END_VAR
END_METHOD
METHOD SetInt : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : DINT;
END_VAR
END_METHOD
METHOD SetInt64 : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : LINT;
END_VAR
END_METHOD
METHOD SetJson : SJsonValue
VAR_INPUT
    v       : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    rawJson : STRING;
END_VAR
END_METHOD
METHOD SetMaxDecimalPlaces
VAR_INPUT
    dp : DINT;
END_VAR
END_METHOD
METHOD SetNull : SJsonValue
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD SetObject : SJsonValue
VAR_INPUT
    v     : SJsonValue;
END_VAR
END_METHOD
METHOD SetString : SJsonValue
VAR_INPUT
    v     : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    value : STRING;
END_VAR
END_METHOD
METHOD SetUint : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : UDINT;
END_VAR
END_METHOD
METHOD SetUint64 : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : ULINT;
END_VAR
END_METHOD
METHOD Swap : BOOL
VAR_INPUT
    v     : SJsonValue;
    w     : SJsonValue;
END_VAR
END_METHOD
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_JsonDynDomParser
VAR_OUTPUT
    initStatus : HRESULT;
END_VAR
METHOD LoadDocumentFromFile : BOOL
VAR_IN_OUT CONSTANT
    sFile      : STRING;
END_VAR
VAR_INPUT
    bExec      : REFERENCE TO BOOL;
END_VAR
VAR_OUTPUT
    hrErrorCode: HRESULT;
END_VAR
END_METHOD
METHOD AddArrayMember : SJsonValue
VAR_INPUT
    v       : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member  : STRING;
END_VAR
VAR_INPUT
    reserve : UDINT;
END_VAR
END_METHOD
METHOD AddBase64Member : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    p      : PVOID;
    n      : DINT;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddBoolMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    value  : BOOL;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddDateTimeMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    value  : DATE_AND_TIME;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddDoubleMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    value  : LREAL;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddHexBinaryMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    p      : PVOID;
    n      : DINT;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddInt64Member : SjsonValue
VAR_INPUT
    v      : SjsonValue;
    value  : LINT;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddIntMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    value  : DINT;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddJsonMember : SJsonValue
VAR_INPUT
    v       : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member  : STRING;
    rawJson : STRING;
END_VAR
END_METHOD
METHOD AddNullMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddObjectMember : SJsonValue
VAR_INPUT
    v       : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddStringMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
    value  : STRING;
END_VAR
END_METHOD
METHOD AddUint64Member : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    value  : ULINT;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD AddUintMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
    value  : UDINT;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD ArrayBegin : SJsonAIterator
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD ArrayEnd : SJsonAIterator
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD ClearArray : BOOL
VAR_INPUT
    v : SJsonValue;
    i : SJsonAIterator;
END_VAR
END_METHOD
METHOD CopyDocument : UDINT
VAR_INPUT
    nDoc : DINT;
END_VAR
VAR_IN_OUT CONSTANT
    pDoc : STRING;
END_VAR
END_METHOD
METHOD CopyFrom : SJsonValue
VAR_INPUT
    v : SJsonValue;
    w : SJsonValue;
END_VAR
END_METHOD
METHOD CopyJson : UDINT
VAR_INPUT
    v    : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    pDoc : STRING;
    nDoc : UDINT;
END_VAR
END_METHOD
METHOD CopyString : UDINT
VAR_INPUT
    v    : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    pStr : STRING;
    nStr : UDINT;
END_VAR
END_METHOD
METHOD ExceptionRaised : BOOL
END_METHOD
METHOD FindMember : SJsonValue
VAR_INPUT
    v      : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD FindMemberPath : SJsonValue
VAR_INPUT
    v      : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD GetArraySize : UDINT
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetArrayValue : SJsonValue
VAR_INPUT
    i : SJsonAIterator;
END_VAR
END_METHOD
METHOD GetArrayValueByIdx : SJsonValue
VAR_INPUT
    v   : SJsonValue;
    idx : UDINT;
END_VAR
END_METHOD
METHOD GetBase64 : DINT
VAR_INPUT
    v : SJsonValue;
    p : PVOID;
    n : DINT;
END_VAR
END_METHOD
METHOD GetBool : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetDateTime : DATE_AND_TIME
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetDocument : STRING(255)
END_METHOD
METHOD GetDocumentLength : UDINT
END_METHOD
METHOD GetDocumentRoot : SJsonValue
END_METHOD
METHOD GetDouble : LREAL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetHexBinary : DINT
VAR_INPUT
    v : SJsonValue;
    p : PVOID;
    n : DINT;
END_VAR
END_METHOD
METHOD GetInt : DINT
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetInt64 : LINT
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetJson : STRING(255)
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetJsonLength : UDINT
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetMaxDecimalPlaces : DINT
END_METHOD
METHOD GetMemberName : STRING(255)
VAR_INPUT
    i : SJsonIterator;
END_VAR
END_METHOD
METHOD GetMemberValue : SJsonValue
VAR_INPUT
    i : SJsonIterator;
END_VAR
END_METHOD
METHOD GetString : STRING(255)
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetStringLength : UDINT
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetType : EJsonType
VAR_INPUT
    v            : SJsonValue;
END_VAR
END_METHOD
METHOD GetUint : UDINT
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD GetUint64 : ULINT
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD HasMember : BOOL
VAR_INPUT
    v      : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    member : STRING;
END_VAR
END_METHOD
METHOD IsArray : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsBase64 : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsBool : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsDouble : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsFalse : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsHexBinary : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsInt : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsInt64 : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsISO8601TimeFormat : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsNull : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsNumber : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsObject : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsString : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsTrue : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsUint : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD IsUint64 : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD MemberBegin : SJsonIterator
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD MemberEnd : SJsonIterator
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD NewDocument : SJsonValue
END_METHOD
METHOD NextArray : SJsonAIterator
VAR_INPUT
    v : SJsonAIterator;
END_VAR
END_METHOD
METHOD NextMember : SJsonIterator
VAR_INPUT
    v : SJsonIterator;
END_VAR
END_METHOD
METHOD ParseDocument : SJsonValue
VAR_IN_OUT CONSTANT
    sJson : STRING;
END_VAR
END_METHOD
METHOD PushbackBase64Value : SJsonValue
VAR_INPUT
    v : SJsonValue;
    p : PVOID;
    n : DINT;
END_VAR
END_METHOD
METHOD PushbackBoolValue : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : BOOL;
END_VAR
END_METHOD
METHOD PushbackCopyValue : SJsonValue
VAR_INPUT
    v       : SJsonValue;
    json    : SJsonValue;
END_VAR
END_METHOD
METHOD PushbackDateTimeValue : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : DATE_AND_TIME;
END_VAR
END_METHOD
METHOD PushbackDoubleValue : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : LREAL;
END_VAR
END_METHOD
METHOD PushbackHexBinaryValue : SJsonValue
VAR_INPUT
    v : SJsonValue;
    p : PVOID;
    n : DINT;
END_VAR
END_METHOD
METHOD PushbackInt64Value : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : LINT;
END_VAR
END_METHOD
METHOD PushbackIntValue : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : DINT;
END_VAR
END_METHOD
METHOD PushbackJsonValue : SJsonValue
VAR_INPUT
    v       : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    rawJson : STRING;
END_VAR
END_METHOD
METHOD PushbackNullValue : SJsonValue
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD PushbackStringValue : SJsonValue
VAR_INPUT
    v     : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    value : STRING;
END_VAR
END_METHOD
METHOD PushbackUint64Value : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : ULINT;
END_VAR
END_METHOD
METHOD PushbackUintValue : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : UDINT;
END_VAR
END_METHOD
METHOD RemoveAllMembers : BOOL
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD RemoveArray : BOOL
VAR_INPUT
    v : SJsonValue;
    i : SJsonAIterator;
END_VAR
END_METHOD
METHOD RemoveMember : BOOL
VAR_INPUT
    v : SJsonValue;
    i : SJsonIterator;
    keepOrder : BOOL;
END_VAR
END_METHOD
METHOD RemoveMemberByName : BOOL
VAR_INPUT
    v         : SJsonValue;
    keepOrder : BOOL;
END_VAR
VAR_IN_OUT CONSTANT
    member  : STRING;
END_VAR
END_METHOD
METHOD SaveDocumentToFile : BOOL
VAR_IN_OUT CONSTANT
    sFile    : STRING;
END_VAR
VAR_INPUT
    bExec    : REFERENCE TO BOOL;
END_VAR
VAR_OUTPUT
    hrErrorCode: HRESULT;
END_VAR
END_METHOD
METHOD SetAdsProvider : BOOL
VAR_INPUT
    oid : OTCID;
END_VAR
END_METHOD
METHOD SetArray : SJsonValue
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD SetBase64 : SJsonValue
VAR_INPUT
    v : SJsonValue;
    p : PVOID;
    n : DINT;
END_VAR
END_METHOD
METHOD SetBool : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : BOOL;
END_VAR
END_METHOD
METHOD SetDateTime : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : DATE_AND_TIME;
END_VAR
END_METHOD
METHOD SetDouble : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : LREAL;
END_VAR
END_METHOD
METHOD SetHexBinary : SJsonValue
VAR_INPUT
    v : SJsonValue;
    p : PVOID;
    n : DINT;
END_VAR
END_METHOD
METHOD SetInt : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : DINT;
END_VAR
END_METHOD
METHOD SetInt64 : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : LINT;
END_VAR
END_METHOD
METHOD SetJson : SJsonValue
VAR_INPUT
    v       : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    rawJson : STRING;
END_VAR
END_METHOD
METHOD SetMaxDecimalPlaces
VAR_INPUT
    dp : DINT;
END_VAR
END_METHOD
METHOD SetNull : SJsonValue
VAR_INPUT
    v : SJsonValue;
END_VAR
END_METHOD
METHOD SetObject : SJsonValue
VAR_INPUT
    v     : SJsonValue;
END_VAR
END_METHOD
METHOD SetString : SJsonValue
VAR_INPUT
    v     : SJsonValue;
END_VAR
VAR_IN_OUT CONSTANT
    value : STRING;
END_VAR
END_METHOD
METHOD SetUint : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : UDINT;
END_VAR
END_METHOD
METHOD SetUint64 : SJsonValue
VAR_INPUT
    v     : SJsonValue;
    value : ULINT;
END_VAR
END_METHOD
METHOD Swap : BOOL
VAR_INPUT
    v     : SJsonValue;
    w     : SJsonValue;
END_VAR
END_METHOD
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_JsonSaxReader
VAR_OUTPUT
    initStatus : HRESULT;
END_VAR
METHOD DecodeBase64 : BOOL
VAR_INPUT
    sBase64     : STRING;
    pBytes      : POINTER TO BYTE;
    nBytes      : REFERENCE TO DINT;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD DecodeDateTime : BOOL
VAR_IN_OUT CONSTANT
    sDT         : STRING;
END_VAR
VAR_OUTPUT
    nDT         : DATE_AND_TIME;
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD DecodeHexBinary : BOOL
VAR_IN_OUT CONSTANT
    sHex        : STRING;
END_VAR
VAR_INPUT
    pBytes      : POINTER TO BYTE;
    nBytes      : REFERENCE TO DINT;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD IsBase64 : BOOL
VAR_IN_OUT CONSTANT
    sBase64 : STRING;
END_VAR
END_METHOD
METHOD IsHexBinary : BOOL
VAR_IN_OUT CONSTANT
    sHex : STRING;
END_VAR
END_METHOD
METHOD IsISO8601TimeFormat : BOOL
VAR_IN_OUT CONSTANT
    sDT : STRING;
END_VAR
END_METHOD
METHOD Parse : BOOL
VAR_IN_OUT CONSTANT
    sJson       : STRING;
END_VAR
VAR_INPUT
    ipHdl       : ITcJsonSaxHandler;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD ParseValues : BOOL
VAR_IN_OUT CONSTANT
    sJson       : STRING;
END_VAR
VAR_INPUT
    ipHdl       : ITcJsonSaxValues;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_JsonSaxPrettyWriter
VAR_OUTPUT
    initStatus : HRESULT;
END_VAR
METHOD AddBase64
VAR_INPUT
    pBytes : Pointer TO BYTE;
    nBytes : DINT;
END_VAR
END_METHOD
METHOD AddBool
VAR_INPUT
    value : BOOL;
END_VAR
END_METHOD
METHOD AddDateTime
VAR_INPUT
    value : DATE_AND_TIME;
END_VAR
END_METHOD
METHOD AddDint
VAR_INPUT
    value : DINT;
END_VAR
END_METHOD
METHOD AddHexBinary
VAR_INPUT
    pBytes : POINTER TO BYTE;
    nBytes : DINT;
END_VAR
END_METHOD
METHOD AddKey
VAR_IN_OUT CONSTANT
    key : STRING;
END_VAR
END_METHOD
METHOD AddKeyBool
VAR_IN_OUT CONSTANT
    key   : STRING;
END_VAR
VAR_INPUT
    value : BOOL;
END_VAR
END_METHOD
METHOD AddKeyDateTime
VAR_IN_OUT CONSTANT
    key   : STRING;
END_VAR
VAR_INPUT
    value : DATE_AND_TIME;
END_VAR
END_METHOD
METHOD AddKeyLreal
VAR_IN_OUT CONSTANT
    key   : STRING;
END_VAR
VAR_INPUT
    value : LREAL;
END_VAR
END_METHOD
METHOD AddKeyNull
VAR_IN_OUT CONSTANT
    key : STRING;
END_VAR
END_METHOD
METHOD AddKeyNumber
VAR_IN_OUT CONSTANT
    key   : STRING;
END_VAR
VAR_INPUT
    value : DINT;
END_VAR
END_METHOD
METHOD AddKeyString
VAR_IN_OUT CONSTANT
    key   : STRING;
    value : STRING;
END_VAR
END_METHOD
METHOD AddLint
VAR_INPUT
    value : LINT;
END_VAR
END_METHOD
METHOD AddLreal
VAR_INPUT
    value : LREAL;
END_VAR
END_METHOD
METHOD AddNull
END_METHOD
METHOD AddRawArray
VAR_IN_OUT CONSTANT
    rawJson : STRING;
END_VAR
END_METHOD
METHOD AddRawObject
VAR_IN_OUT CONSTANT
    rawJson : STRING;
END_VAR
END_METHOD
METHOD AddReal
VAR_INPUT
    value : REAL;
END_VAR
END_METHOD
METHOD AddString
VAR_IN_OUT CONSTANT
    value : STRING;
END_VAR
END_METHOD
METHOD AddUdint
VAR_INPUT
    value : UDINT;
END_VAR
END_METHOD
METHOD AddUlint
VAR_INPUT
    value : ULINT;
END_VAR
END_METHOD
METHOD CopyDocument : UDINT
VAR_IN_OUT CONSTANT
    pDoc       : STRING;
END_VAR
VAR_INPUT
    nDoc       : UDINT;
END_VAR
VAR_OUTPUT
    hrErrorCode: HRESULT;
END_VAR
END_METHOD
METHOD EndArray : HRESULT
END_METHOD
METHOD EndObject : HRESULT
END_METHOD
METHOD GetDocument : STRING(255)
VAR_OUTPUT
    hrErrorCode: HRESULT;
END_VAR
END_METHOD
METHOD GetDocumentLength : UDINT
VAR_OUTPUT
    hrErrorCode: HRESULT;
END_VAR
END_METHOD
METHOD GetMaxDecimalPlaces : DINT
END_METHOD
METHOD ResetDocument : HRESULT
END_METHOD
METHOD SetFormatOptions : HRESULT
VAR_INPUT
    options               : EJsonPrettyFormatOptions;
END_VAR
END_METHOD
METHOD SetIndent : HRESULT
VAR_INPUT
    indentChar      : SINT;
    indentCharCount : UDINT;
END_VAR
END_METHOD
METHOD SetMaxDecimalPlaces : HRESULT
VAR_INPUT
    decimalPlaces: DINT;
END_VAR
END_METHOD
METHOD StartArray : HRESULT
END_METHOD
METHOD StartObject : HRESULT
END_METHOD
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_JsonReadWriteDataType
VAR_OUTPUT
    initStatus : HRESULT;
END_VAR
METHOD AddJsonKeyPropertiesFromSymbol : BOOL
VAR_IN_OUT
    fbWriter    : FB_JsonSaxWriter;
END_VAR
VAR_IN_OUT CONSTANT
    sKey        : STRING;
    sDatatype   : STRING;
    sProperties : STRING;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD AddJsonKeyValueFromSymbol : BOOL
VAR_IN_OUT
    fbWriter    : FB_JsonSaxWriter;
END_VAR
VAR_IN_OUT CONSTANT
    sKey        : STRING;
    sDatatype   : STRING;
END_VAR
VAR_INPUT
    nData       : UDINT;
    pData       : PVOID;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD AddJsonValueFromSymbol : BOOL
VAR_IN_OUT
    fbWriter : FB_JsonSaxWriter;
END_VAR
VAR_IN_OUT CONSTANT
    sDatatype   : STRING;
END_VAR
VAR_INPUT
    nData       : UDINT;
    pData       : PVOID;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD CopyJsonStringFromSymbol : UDINT
VAR_INPUT
    nData       : UDINT;
    nDoc        : UDINT;
    pData       : PVOID;
END_VAR
VAR_IN_OUT CONSTANT
    pDoc        : STRING;
    sDatatype   : STRING;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD CopyJsonStringFromSymbolProperties : UDINT
VAR_INPUT
    nDoc        : UDINT;
END_VAR
VAR_IN_OUT CONSTANT
    pDoc        : STRING;
    sDatatype   : STRING;
    sProperties : STRING;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD CopySymbolNameByAddress : UDINT
VAR_INPUT
    nData     : UDINT;
    pData     : PVOID;
END_VAR
VAR_IN_OUT CONSTANT
    sName     : STRING;
END_VAR
VAR_INPUT
    nName     : UDINT;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD GetDataTypeNameByAddress : STRING
VAR_INPUT
    nData       : UDINT;
    pData       : PVOID;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD GetJsonFromSymbol : BOOL
VAR_IN_OUT CONSTANT
    sDatatype : STRING;
END_VAR
VAR_INPUT
    nData       : UDINT;
    pData       : PVOID;
    nJson       : REFERENCE TO UDINT;
    pJson       : POINTER TO STRING;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD GetJsonStringFromSymbol : STRING(255)
VAR_IN_OUT CONSTANT
    sDatatype   : STRING;
END_VAR
VAR_INPUT
    nData       : UDINT;
    pData       : PVOID;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD GetJsonStringFromSymbolProperties : STRING(255)
VAR_IN_OUT CONSTANT
    sDatatype   : STRING;
    sProperties : STRING;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD GetSizeJsonStringFromSymbol : UDINT
VAR_INPUT
    nData       :UDINT;
    pData       :PVOID;
END_VAR
VAR_IN_OUT CONSTANT
    sDatatype   : STRING;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD GetSizeJsonStringFromSymbolProperties : UDINT
VAR_IN_OUT CONSTANT
    sDatatype   : STRING;
    sProperties : STRING;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD GetSymbolNameByAddress : STRING(255)
VAR_INPUT
    nData       : UDINT;
    pData       : PVOID;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
METHOD SetSymbolFromJson : BOOL
VAR_IN_OUT CONSTANT
    sJson       : STRING;
    sDatatype   : STRING;
END_VAR
VAR_INPUT
    nData       : UDINT;
    pData       : PVOID;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
END_METHOD
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_XmlDomParser
VAR_OUTPUT
    initStatus : HRESULT;
END_VAR
METHOD AppendAttribute : SXmlAttribute
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
    value : STRING;
END_VAR
END_METHOD
METHOD AppendAttributeAsBool : SXmlAttribute
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
END_VAR
VAR_INPUT
    value : BOOL;
END_VAR
END_METHOD
METHOD AppendAttributeAsDouble : SXmlAttribute
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
END_VAR
VAR_INPUT
    value : LREAL;
END_VAR
END_METHOD
METHOD AppendAttributeAsFloat : SXmlAttribute
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
END_VAR
VAR_INPUT
    value : REAL;
END_VAR
END_METHOD
METHOD AppendAttributeAsInt : SXmlAttribute
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
END_VAR
VAR_INPUT
    value : DINT;
END_VAR
END_METHOD
METHOD AppendAttributeAsLint : SXmlAttribute
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
END_VAR
VAR_INPUT
    value : LINT;
END_VAR
END_METHOD
METHOD AppendAttributeAsUint : SXmlAttribute
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
END_VAR
VAR_INPUT
    value : UDINT;
END_VAR
END_METHOD
METHOD AppendAttributeAsUlint : SXmlAttribute
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
END_VAR
VAR_INPUT
    value : ULINT;
END_VAR
END_METHOD
METHOD AppendAttributeCopy : SXmlAttribute
VAR_INPUT
    n    : SXmlNode;
    copy : SXmlAttribute;
END_VAR
END_METHOD
METHOD AppendChild : SXmlNode
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
    value : STRING;
END_VAR
VAR_INPUT
    cdata : BOOL;
END_VAR
END_METHOD
METHOD AppendChildAsBool : SXmlNode
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
END_VAR
VAR_INPUT
    value : BOOL;
END_VAR
END_METHOD
METHOD AppendChildAsDouble : SXmlNode
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
END_VAR
VAR_INPUT
    value : LREAL;
END_VAR
END_METHOD
METHOD AppendChildAsFloat : SXmlNode
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
END_VAR
VAR_INPUT
    value : REAL;
END_VAR
END_METHOD
METHOD AppendChildAsInt : SXmlNode
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
END_VAR
VAR_INPUT
    value : DINT;
END_VAR
END_METHOD
METHOD AppendChildAsLint : SXmlNode
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
END_VAR
VAR_INPUT
    value : LINT;
END_VAR
END_METHOD
METHOD AppendChildAsUint : SXmlNode
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
END_VAR
VAR_INPUT
    value : UDINT;
END_VAR
END_METHOD
METHOD AppendChildAsUlint : SXmlNode
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name  : STRING;
END_VAR
VAR_INPUT
    value : ULINT;
END_VAR
END_METHOD
METHOD AppendCopy : SXmlNode
VAR_INPUT
    n    : SXmlNode;
    copy : SXmlNode;
END_VAR
END_METHOD
METHOD AppendNode : SXmlNode
VAR_INPUT
    n    : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name : STRING;
END_VAR
END_METHOD
METHOD Attribute : SXmlAttribute
VAR_INPUT
    n    : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name : STRING;
END_VAR
END_METHOD
METHOD AttributeAsBool : BOOL
VAR_INPUT
    a : SXmlAttribute;
END_VAR
END_METHOD
METHOD AttributeAsDouble : LREAL
VAR_INPUT
    a : SXmlAttribute;
END_VAR
END_METHOD
METHOD AttributeAsFloat : REAL
VAR_INPUT
    a : SXmlAttribute;
END_VAR
END_METHOD
METHOD AttributeAsInt : DINT
VAR_INPUT
    a : SXmlAttribute;
END_VAR
END_METHOD
METHOD AttributeAsLint : LINT
VAR_INPUT
    a : SXmlAttribute;
END_VAR
END_METHOD
METHOD AttributeAsUint : UDINT
VAR_INPUT
    a : SXmlAttribute;
END_VAR
END_METHOD
METHOD AttributeAsUlint : ULINT
VAR_INPUT
    a : SXmlAttribute;
END_VAR
END_METHOD
METHOD AttributeBegin : SXmlIterator
VAR_INPUT
    n : SXmlNode;
END_VAR
END_METHOD
METHOD AttributeFromIterator : SXmlAttribute
VAR_INPUT
    it : SXmlIterator;
END_VAR
END_METHOD
METHOD AttributeName : STRING
VAR_INPUT
    a : SXmlAttribute;
END_VAR
END_METHOD
METHOD Attributes : SXmlAttribute
VAR_INPUT
    n : SXmlNode;
    it : REFERENCE TO SXmlIterator;
END_VAR
END_METHOD
METHOD AttributeText : STRING(255)
VAR_INPUT
    a : SXmlAttribute;
END_VAR
END_METHOD
METHOD Begin : SXmlIterator
VAR_INPUT
    n : SXmlNode;
END_VAR
END_METHOD
METHOD BeginByName : SXmlIterator
VAR_INPUT
    n    : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name : STRING;
END_VAR
END_METHOD
METHOD Child : SXmlNode
VAR_INPUT
    n : SXmlNode;
END_VAR
END_METHOD
METHOD ChildByAttribute : SXmlNode
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    attr  : STRING;
    value : STRING;
END_VAR
END_METHOD
METHOD ChildByAttributeAndName : SXmlNode
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    attr  : STRING;
    value : STRING;
    child : STRING;
END_VAR
END_METHOD
METHOD ChildByName : SXmlNode
VAR_INPUT
    n    : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name : STRING;
END_VAR
END_METHOD
METHOD Children : SXmlNode
VAR_INPUT
    n  : SXmlNode;
    it : REFERENCE TO SXmlIterator;
END_VAR
END_METHOD
METHOD ChildrenByName : SXmlNode
VAR_INPUT
    n    : SXmlNode;
    it   : REFERENCE TO SXmlIterator;
END_VAR
VAR_IN_OUT CONSTANT
    name : STRING;
END_VAR
END_METHOD
METHOD ClearIterator : BOOL
VAR_INPUT
    it : SXmlIterator;
END_VAR
END_METHOD
METHOD Compare : BOOL
VAR_INPUT
    it1 : SXmlIterator;
    it2 : SXmlIterator;
END_VAR
END_METHOD
METHOD CopyAttributeText : UDINT
VAR_INPUT
    a    : SXmlAttribute;
END_VAR
VAR_IN_OUT CONSTANT
    sXml : STRING;
END_VAR
VAR_INPUT
    nXml : UDINT;
END_VAR
END_METHOD
METHOD CopyDocument : UDINT
VAR_IN_OUT CONSTANT
    sXml : STRING;
END_VAR
VAR_INPUT
    nXml : UDINT;
END_VAR
END_METHOD
METHOD CopyNodeText : UDINT
VAR_INPUT
    n    : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    sXml : STRING;
END_VAR
VAR_INPUT
    nXml : UDINT;
END_VAR
END_METHOD
METHOD CopyNodeXml : UDINT
VAR_INPUT
    a    : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    sXml : STRING;
END_VAR
VAR_INPUT
    nXml : UDINT;
END_VAR
END_METHOD
METHOD FirstNodeByPath : SXmlNode
VAR_INPUT
    n    : SXmlNode;
    path : STRING;
END_VAR
END_METHOD
METHOD GetAttributeTextLength : UDINT
VAR_INPUT
    a : SXmlAttribute;
END_VAR
END_METHOD
METHOD GetDocumentLength : UDINT
END_METHOD
METHOD GetDocumentNode : SXmlNode
END_METHOD
METHOD GetNodeTextLength : UDINT
VAR_INPUT
    n : SXmlNode;
END_VAR
END_METHOD
METHOD GetNodeXmlLength : UDINT
VAR_INPUT
    n : SXmlNode;
END_VAR
END_METHOD
METHOD GetRootNode : SXmlNode
END_METHOD
METHOD InsertAttributeCopy : SXmlAttribute
VAR_INPUT
    n      : SXmlNode;
    before : SXmlAttribute;
    copy   : SXmlAttribute;
END_VAR
END_METHOD
METHOD InsertAttribute : SXmlAttribute
VAR_INPUT
    n      : SXmlNode;
    before : SXmlAttribute;
END_VAR
VAR_IN_OUT CONSTANT
    name   : STRING;
END_VAR
END_METHOD
METHOD InsertChild : SXmlNode
VAR_INPUT
    n      : SXmlNode;
    before : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name   : STRING;
END_VAR
END_METHOD
METHOD InsertCopy : SXmlNode
VAR_INPUT
    n      : SXmlNode;
    before : SXmlNode;
    copy   : SXmlNode;
END_VAR
END_METHOD
METHOD IsEnd : BOOL
VAR_INPUT
    it : SXmlIterator;
END_VAR
END_METHOD
METHOD LoadDocumentFromFile : BOOL
VAR_IN_OUT CONSTANT
    sFile      : STRING;
END_VAR
VAR_INPUT
    bExec      : REFERENCE TO BOOL;
END_VAR
VAR_OUTPUT
    hrErrorCode: HRESULT;
END_VAR
END_METHOD
METHOD NewDocument : BOOL
END_METHOD
METHOD Next : SXmlIterator
VAR_INPUT
    it : SXmlIterator;
END_VAR
END_METHOD
METHOD NextAttribute : SXmlAttribute
VAR_INPUT
    a : SXmlAttribute;
END_VAR
END_METHOD
METHOD NextByName : SXmlIterator
VAR_INPUT
    it   : SXmlIterator;
END_VAR
VAR_IN_OUT CONSTANT
    name : STRING;
END_VAR
END_METHOD
METHOD NextSibling : SXmlNode
VAR_INPUT
    n : SXmlNode;
END_VAR
END_METHOD
METHOD NextSiblingByName : SXmlNode
VAR_INPUT
    n    : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name : STRING;
END_VAR
END_METHOD
METHOD Node : SXmlNode
VAR_INPUT
    it : SXmlIterator;
END_VAR
END_METHOD
METHOD NodeAsBool : BOOL
VAR_INPUT
    n : SXmlNode;
END_VAR
END_METHOD
METHOD NodeAsDouble : LREAL
VAR_INPUT
    n : SXmlNode;
END_VAR
END_METHOD
METHOD NodeAsFloat : REAL
VAR_INPUT
    n : SXmlNode;
END_VAR
END_METHOD
METHOD NodeAsInt : DINT
VAR_INPUT
    n : SXmlNode;
END_VAR
END_METHOD
METHOD NodeAsLint : LINT
VAR_INPUT
    n : SXmlNode;
END_VAR
END_METHOD
METHOD NodeAsUint : UDINT
VAR_INPUT
    n : SXmlNode;
END_VAR
END_METHOD
METHOD NodeAsUlint : ULINT
VAR_INPUT
    n : SXmlNode;
END_VAR
END_METHOD
METHOD NodeName : STRING
VAR_INPUT
    n : SXmlNode;
END_VAR
END_METHOD
METHOD NodeText : STRING(255)
VAR_INPUT
    n : SXmlNode;
END_VAR
END_METHOD
METHOD ParseDocument : SXmlNode
VAR_IN_OUT CONSTANT
    sXml : STRING;
END_VAR
END_METHOD
METHOD RemoveChild : BOOL
VAR_INPUT
    n     : SXmlNode;
    child : SXmlNode;
END_VAR
END_METHOD
METHOD RemoveChildByName : BOOL
VAR_INPUT
    n    : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    name : STRING;
END_VAR
END_METHOD
METHOD SaveDocumentToFile : BOOL
VAR_IN_OUT CONSTANT
    sFile      : STRING;
END_VAR
VAR_INPUT
    bExec      : REFERENCE TO BOOL;
END_VAR
VAR_OUTPUT
    hrErrorCode: HRESULT;
END_VAR
END_METHOD
METHOD SetAdsProvider : BOOL
VAR_IN_OUT CONSTANT
    oid : OTCID;
END_VAR
END_METHOD
METHOD SetAttribute : SXmlAttribute
VAR_INPUT
    a     : SXmlAttribute;
END_VAR
VAR_IN_OUT CONSTANT
    value : STRING;
END_VAR
END_METHOD
METHOD SetAttributeAsBool : SXmlAttribute
VAR_INPUT
    a     : SXmlAttribute;
    value : BOOL;
END_VAR
END_METHOD
METHOD SetAttributeAsDouble : SXmlAttribute
VAR_INPUT
    a     : SXmlAttribute;
    value : LREAL;
END_VAR
END_METHOD
METHOD SetAttributeAsFloat : SXmlAttribute
VAR_INPUT
    a     : SXmlAttribute;
    value : REAL;
END_VAR
END_METHOD
METHOD SetAttributeAsInt : SXmlAttribute
VAR_INPUT
    a     : SXmlAttribute;
    value : DINT;
END_VAR
END_METHOD
METHOD SetAttributeAsLint : SXmlAttribute
VAR_INPUT
    a     : SXmlAttribute;
    value : LINT;
END_VAR
END_METHOD
METHOD SetAttributeAsUint : SXmlAttribute
VAR_INPUT
    a     : SXmlAttribute;
    value : UDINT;
END_VAR
END_METHOD
METHOD SetAttributeAsUlint : SXmlAttribute
VAR_INPUT
    a     : SXmlAttribute;
    value : ULINT;
END_VAR
END_METHOD
METHOD SetChild : SXmlNode
VAR_INPUT
    n     : SXmlNode;
END_VAR
VAR_IN_OUT CONSTANT
    value : STRING;
END_VAR
VAR_INPUT
    cdata : BOOL;
END_VAR
END_METHOD
METHOD SetChildAsBool : SXmlNode
VAR_INPUT
    n     : SXmlNode;
    value : BOOL;
END_VAR
END_METHOD
METHOD SetChildAsDouble : SXmlNode
VAR_INPUT
    n     : SXmlNode;
    value : LREAL;
END_VAR
END_METHOD
METHOD SetChildAsFloat : SXmlNode
VAR_INPUT
    n     : SXmlNode;
    value : REAL;
END_VAR
END_METHOD
METHOD SetChildAsInt : SXmlNode
VAR_INPUT
    n     : SXmlNode;
    value : DINT;
END_VAR
END_METHOD
METHOD SetChildAsLint : SXmlNode
VAR_INPUT
    n     : SXmlNode;
    value : LINT;
END_VAR
END_METHOD
METHOD SetChildAsUint : SXmlNode
VAR_INPUT
    n     : SXmlNode;
    value : UDINT;
END_VAR
END_METHOD
METHOD SetChildAsUlint : SXmlNode
VAR_INPUT
    n     : SXmlNode;
    value : ULINT;
END_VAR
END_METHOD
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_JsonSaxWriter
VAR_OUTPUT
    initStatus : HRESULT;
END_VAR
VAR
    _doc      : STRING(65535);
    _count    : ARRAY[0..255] OF UDINT; (* values written at each level *)
    _depth    : INT;
    _afterKey : BOOL;
END_VAR
(* separator before a value: none right after a key, else a comma when the
   array or object already has a value *)
METHOD PRIVATE __Value
IF _afterKey THEN
    _afterKey := FALSE;
ELSIF _depth > 0 THEN
    IF _count[_depth] > 0 THEN
        _doc := CONCAT(_doc, ',');
    END_IF
    _count[_depth] := _count[_depth] + 1;
END_IF
END_METHOD
(* s as a JSON string: quoted, with the double quote, the backslash and
   control characters escaped *)
METHOD PRIVATE __Quote : STRING(65535)
VAR_IN_OUT CONSTANT
    s : STRING;
END_VAR
VAR
    i, n, p : INT;
    c : STRING(1);
END_VAR
VAR CONSTANT
    CTRL : STRING(31) := '$01$02$03$04$05$06$07$08$09$0A$0B$0C$0D$0E$0F$10$11$12$13$14$15$16$17$18$19$1A$1B$1C$1D$1E$1F';
    HEX : STRING(16) := '0123456789ABCDEF';
END_VAR
__Quote := '"';
n := LEN(s);
FOR i := 1 TO n DO
    c := MID(s, 1, i);
    p := FIND(CTRL, c);
    IF c = '"' THEN
        __Quote := CONCAT(__Quote, '\"');
    ELSIF c = '\' THEN
        __Quote := CONCAT(__Quote, '\\');
    ELSIF p = 8 THEN
        __Quote := CONCAT(__Quote, '\b');
    ELSIF p = 9 THEN
        __Quote := CONCAT(__Quote, '\t');
    ELSIF p = 10 THEN
        __Quote := CONCAT(__Quote, '\n');
    ELSIF p = 12 THEN
        __Quote := CONCAT(__Quote, '\f');
    ELSIF p = 13 THEN
        __Quote := CONCAT(__Quote, '\r');
    ELSIF p > 0 THEN
        __Quote := CONCAT(CONCAT(__Quote, '\u00'), CONCAT(MID(HEX, 1, p / 16 + 1), MID(HEX, 1, p MOD 16 + 1)));
    ELSE
        __Quote := CONCAT(__Quote, c);
    END_IF
END_FOR
__Quote := CONCAT(__Quote, '"');
END_METHOD
METHOD PRIVATE __Raw
VAR_IN_OUT CONSTANT
    text : STRING;
END_VAR
__Value();
_doc := CONCAT(_doc, text);
END_METHOD
METHOD AddBase64
VAR_INPUT
    pBytes : POINTER TO BYTE;
    nBytes : DINT;
END_VAR
END_METHOD
METHOD AddBool
VAR_INPUT
    value : BOOL;
END_VAR
IF value THEN
    __Raw('true');
ELSE
    __Raw('false');
END_IF
END_METHOD
METHOD AddDateTime
VAR_INPUT
    value : DATE_AND_TIME;
END_VAR
VAR
    s : STRING;
END_VAR
(* DT_TO_STRING gives DT#yyyy-mm-dd-hh:mm:ss *)
s := DT_TO_STRING(value);
__Raw(CONCAT(CONCAT('"', MID(s, 10, 4)), CONCAT(CONCAT('T', MID(s, 8, 15)), '"')));
END_METHOD
METHOD AddDint
VAR_INPUT
    value : DINT;
END_VAR
__Raw(DINT_TO_STRING(value));
END_METHOD
METHOD AddHexBinary
VAR_INPUT
    pBytes : POINTER TO BYTE;
    nBytes : DINT;
END_VAR
END_METHOD
METHOD AddKey
VAR_IN_OUT CONSTANT
    key : STRING;
END_VAR
IF _depth > 0 THEN
    IF _count[_depth] > 0 THEN
        _doc := CONCAT(_doc, ',');
    END_IF
    _count[_depth] := _count[_depth] + 1;
END_IF
_doc := CONCAT(CONCAT(_doc, __Quote(key)), ':');
_afterKey := TRUE;
END_METHOD
METHOD AddKeyBool
VAR_IN_OUT CONSTANT
    key : STRING;
END_VAR
VAR_INPUT
    value : BOOL;
END_VAR
AddKey(key);
AddBool(value);
END_METHOD
METHOD AddKeyDateTime
VAR_IN_OUT CONSTANT
    key : STRING;
END_VAR
VAR_INPUT
    value : DATE_AND_TIME;
END_VAR
AddKey(key);
AddDateTime(value);
END_METHOD
METHOD AddKeyLreal
VAR_IN_OUT CONSTANT
    key : STRING;
END_VAR
VAR_INPUT
    value : LREAL;
END_VAR
END_METHOD
METHOD AddKeyNull
VAR_IN_OUT CONSTANT
    key : STRING;
END_VAR
AddKey(key);
AddNull();
END_METHOD
METHOD AddKeyNumber
VAR_IN_OUT CONSTANT
    key : STRING;
END_VAR
VAR_INPUT
    value : DINT;
END_VAR
AddKey(key);
AddDint(value);
END_METHOD
METHOD AddKeyString
VAR_IN_OUT CONSTANT
    key : STRING;
    value : STRING;
END_VAR
AddKey(key);
AddString(value);
END_METHOD
METHOD AddLint
VAR_INPUT
    value : LINT;
END_VAR
__Raw(LINT_TO_STRING(value));
END_METHOD
METHOD AddLreal
VAR_INPUT
    value : LREAL;
END_VAR
END_METHOD
METHOD AddNull
__Raw('null');
END_METHOD
METHOD AddRawArray
VAR_IN_OUT CONSTANT
    rawJson : STRING;
END_VAR
__Raw(rawJson);
END_METHOD
METHOD AddRawObject
VAR_IN_OUT CONSTANT
    rawJson : STRING;
END_VAR
__Raw(rawJson);
END_METHOD
METHOD AddReal
VAR_INPUT
    value : REAL;
END_VAR
END_METHOD
METHOD AddString
VAR_IN_OUT CONSTANT
    value : STRING;
END_VAR
__Raw(__Quote(value));
END_METHOD
METHOD AddUdint
VAR_INPUT
    value : UDINT;
END_VAR
__Raw(UDINT_TO_STRING(value));
END_METHOD
METHOD AddUlint
VAR_INPUT
    value : ULINT;
END_VAR
__Raw(ULINT_TO_STRING(value));
END_METHOD
(* returns the length with the terminating null; 0 and an emptied target
   when the document does not fit in nDoc bytes *)
METHOD CopyDocument : UDINT
VAR_IN_OUT CONSTANT
    pDoc : STRING;
END_VAR
VAR_INPUT
    nDoc : UDINT;
END_VAR
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
IF INT_TO_UDINT(LEN(_doc)) + 1 <= nDoc THEN
    pDoc := _doc;
    CopyDocument := INT_TO_UDINT(LEN(_doc)) + 1;
ELSE
    pDoc := '';
    CopyDocument := 0;
END_IF
END_METHOD
METHOD EndArray : HRESULT
_doc := CONCAT(_doc, ']');
IF _depth > 0 THEN
    _depth := _depth - 1;
END_IF
END_METHOD
METHOD EndObject : HRESULT
_doc := CONCAT(_doc, '}');
IF _depth > 0 THEN
    _depth := _depth - 1;
END_IF
END_METHOD
(* the document, or '' when it is longer than 255 characters *)
METHOD GetDocument : STRING(255)
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
IF LEN(_doc) <= 255 THEN
    GetDocument := _doc;
END_IF
END_METHOD
METHOD GetDocumentLength : UDINT
VAR_OUTPUT
    hrErrorCode : HRESULT;
END_VAR
GetDocumentLength := INT_TO_UDINT(LEN(_doc));
END_METHOD
METHOD GetMaxDecimalPlaces : DINT
END_METHOD
METHOD ResetDocument : HRESULT
_doc := '';
_depth := 0;
_afterKey := FALSE;
END_METHOD
METHOD SetMaxDecimalPlaces : HRESULT
VAR_INPUT
    decimalPlaces : DINT;
END_VAR
END_METHOD
METHOD StartArray : HRESULT
__Value();
_doc := CONCAT(_doc, '[');
IF _depth < 255 THEN
    _depth := _depth + 1;
    _count[_depth] := 0;
END_IF
END_METHOD
METHOD StartObject : HRESULT
__Value();
_doc := CONCAT(_doc, '{');
IF _depth < 255 THEN
    _depth := _depth + 1;
    _count[_depth] := 0;
END_IF
END_METHOD
END_FUNCTION_BLOCK
