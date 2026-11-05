# Alarm point following the ISA-18.2 state model

Write one alarm point for a plant alarm list. The alarm state lives in a
structure that the caller owns, so a SCADA client can read the whole alarm
list as one array. Declare this type exactly:

```
TYPE
    ST_Alarm : STRUCT
        xActive   : BOOL;   (* the condition is present now (after delays) *)
        xLatched  : BOOL;   (* raised and not yet returned to normal *)
        xAcked    : BOOL;   (* the operator acknowledged this occurrence *)
        iPriority : INT;
        rTimeInS  : REAL;   (* time stamp of the last occurrence *)
        iCount    : INT;    (* number of occurrences *)
    END_STRUCT;
END_TYPE
```

and this function block:

```
FUNCTION_BLOCK FB_Alarm
VAR_INPUT
    xCondition : BOOL;
    xEnable    : BOOL := TRUE;
    xAck       : BOOL;
    iPriority  : INT := 3;
    tOnDelay   : TIME := T#0s;
    tOffDelay  : TIME := T#0s;
    rNowS      : REAL;          (* current time in seconds, for the time stamp *)
END_VAR
VAR_IN_OUT
    stAlarm    : ST_Alarm;
END_VAR
VAR_OUTPUT
    xNewAlarm  : BOOL;          (* TRUE for one call when the alarm is raised *)
END_VAR
```

Behaviour, evaluated on every call:

1. `stAlarm.iPriority` is set to `iPriority`.
2. `stAlarm.xActive` follows `xCondition AND xEnable`, delayed by `tOnDelay`
   when it becomes TRUE and by `tOffDelay` when it becomes FALSE.
3. When `xActive` rises, the alarm is raised: `xNewAlarm` is TRUE for that
   call only, `xLatched` becomes TRUE, `xAcked` becomes FALSE, `rTimeInS`
   takes `rNowS`, and `iCount` increases by one.
4. `xAck` while the alarm is latched sets `xAcked`. An acknowledgement
   while nothing is latched has no effect.
5. The alarm returns to normal (`xLatched` FALSE) only when it is no longer
   active **and** it has been acknowledged, in either order. A short
   condition therefore stays on the list until someone has seen it.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
  Strict IEC: a solution that only checks with a vendor-specific form does
  not count.
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle. Timers
  use the virtual clock; tests move it with `ADVANCE`.
