(* spec: [stdlib.compat]
   libraries: Tc3_JsonXml
   expect: ok
   run: PRG_Main cycles=1
   assert: sDoc = '{"Timestamp":"2017-04-04T12:42:42","Values":{"Sensor2":[1,2,-3],"On":true,"Name":"Pump \"A\"\\1","Off":null},"Raw":{"x":42},"Big":18446744073709551615}'
   assert: nLen = 151
   assert: nCopied = 152
   assert: sCopy = '{"Timestamp":"2017-04-04T12:42:42","Values":{"Sensor2":[1,2,-3],"On":true,"Name":"Pump \"A\"\\1","Off":null},"Raw":{"x":42},"Big":18446744073709551615}'
   assert: nTooSmall = 0
   assert: sSmall = ''
   assert: sAfterReset = '[]' *)
PROGRAM PRG_Main
VAR
    fbJson : FB_JsonSaxWriter;
    dtTimestamp : DT := DT#2017-04-04-12:42:42;
    sDoc : STRING[255];
    sCopy : STRING[1000];
    sSmall : STRING[10] := 'old';
    sAfterReset : STRING[255];
    nLen, nCopied, nTooSmall : UDINT;
END_VAR
fbJson.ResetDocument();
fbJson.StartObject();
fbJson.AddKeyDateTime('Timestamp', dtTimestamp);
fbJson.AddKey('Values');
fbJson.StartObject();
fbJson.AddKey('Sensor2');
fbJson.StartArray();
fbJson.AddDint(1);
fbJson.AddUdint(2);
fbJson.AddLint(-3);
fbJson.EndArray();
fbJson.AddKeyBool('On', TRUE);
fbJson.AddKeyString('Name', 'Pump "A"\1');
fbJson.AddKeyNull('Off');
fbJson.EndObject();
fbJson.AddKey('Raw');
fbJson.AddRawObject('{"x":42}');
fbJson.AddKey('Big');
fbJson.AddUlint(18446744073709551615);
fbJson.EndObject();
sDoc := fbJson.GetDocument();
nLen := fbJson.GetDocumentLength();
nCopied := fbJson.CopyDocument(sCopy, SIZEOF(sCopy));
nTooSmall := fbJson.CopyDocument(sSmall, SIZEOF(sSmall));
fbJson.ResetDocument();
fbJson.StartArray();
fbJson.EndArray();
sAfterReset := fbJson.GetDocument();
END_PROGRAM
