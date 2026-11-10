# Build log (2026-11-10)

Nothing below is compiled or run. "built" = code written; status per feature is in `features.csv`.

| ID | screen | state | missing / notes |
|---|---|---|---|
| — | WatchCore package | built + 38 unit tests written (plus 5 app tests) | tests not run (no Swift toolchain here) |
| S01 | Onboarding | built | permissions asked on first use |
| S02 | Today | built | battery not shown; distance not decoded |
| S03–S08 | Metric detail (generic) | built | breathing, menstrual, immunity, ECG not built (blocked-protocol) |
| S09–S11 | Workouts | built | watch-recorded workouts not synced |
| S12–S14 | Faces | built | install refuses until packets are confirmed |
| S15 | Files & media | explanation only | all transfers blocked-protocol |
| S16 | Watch apps | explanation only | vendor store |
| S17 | Device | built | battery "not available yet" |
| S18–S19 | Scan, my watches | built | |
| S20 | Notifications | explanation only | blocked-ios |
| S21 | Alarms | built | field order inferred |
| S22 | Reminders | built | other reminder types blocked |
| S23 | Do Not Disturb | built | |
| S24–S25 | Display, time, units | built | language blocked |
| S26 | Weather | explanation only | blocked-protocol |
| S27 | Contacts | explanation only | blocked-protocol |
| S28 | Camera remote | toggle only | shutter signal unknown |
| S29 | Find watch / phone | find watch built; find phone explanation | |
| S30 | Firmware | info only | updates disabled on purpose |
| S31 | Reset / erase | built, typed confirmation | unconfirmed commands |
| S32 | Settings | built | profile not sent to watch |
| S33 | Packet log | built (tap version 5×) | |

Harder than expected: no decompiler and no Swift compiler on this machine — protocol work was done
with home-made DEX parsers and the Swift code was reviewed by hand only. Expect the first CI run to
report compile errors that need a round of fixes.

Screenshots for diff (`replica/clone-screens/`): none — needs a simulator (CI or Mac).
