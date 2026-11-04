(* spec: [stdlib.compat.declare-only]
   libraries: Tc3_JsonXml
   expect: warning RP0120
   run: PRG_Main cycles=1
   assert: n = 2 *)
PROGRAM PRG_Main
VAR
    parse : BOOL;
    fbDom : FB_JsonDomParser;
    fbJson : FB_JsonSaxWriter;
    jsonDoc, jsonProp : SJsonValue;
    sDoc : STRING[255] := '{"a":1}';
    f : LREAL;
    n : UDINT;
END_VAR
fbJson.StartArray();
fbJson.AddDint(1);
IF parse THEN
    (* declared only: a run that reaches these stops with UNSUPPORTED *)
    jsonDoc := fbDom.ParseDocument(sDoc);
    jsonProp := fbDom.FindMember(jsonDoc, 'a');
    f := fbDom.GetDouble(jsonProp);
    fbJson.AddLreal(f);
END_IF;
fbJson.EndArray();
n := fbJson.GetDocumentLength() - 1;
END_PROGRAM
