# Recon map — WearFit Pro (Android) → new native iPhone app

## Scope

- **App / platform:** WearFit Pro `com.wakeup.howear` hw_5.6.19 (Android) → new iPhone app (Swift/SwiftUI).
- **Slice:** everything that talks to the user's smartwatch: connection, health, sports, watch
  faces, files, device settings, notifications. Vendor cloud services are out (see "Cannot clone").
- **For:** the user's own watch first; other WearFit-compatible models only when verified.

## Sources

| source | what it gave | where |
|---|---|---|
| The APK the user supplied (static analysis for interoperability) | screens, capabilities, BLE protocol | `research/*.md`, `research/evidence/` |
| User screenshots of every screen | real layouts, states | **missing — Phase 2** (`replica/screens/`) |
| HCI snoop log from the user's phone + watch | real packets | **missing — Phase 2** |
| Apple HIG, Health app (public) | visual principles only | design phase |

## Screen inventory (new app; original screens in brackets)

| ID | screen | how you get there | purpose | key components | states |
|---|---|---|---|---|---|
| S01 | Onboarding / permissions | first launch | Bluetooth, Health, notifications, location consent | pager, primary button | denied, granted |
| S02 | Today (dashboard) [HealthDashboard, rainbow.*] | tab 1 | rings: steps, kcal, active time; cards for HR, SpO2, sleep, stress, temp | ring, metric card | empty (no device), syncing, filled, stale |
| S03 | Metric detail: steps [Step] | S02 card | day/week/month chart, goal | segmented range, chart | empty, filled |
| S04 | Metric detail: heart rate [Heart, HeartRateSetting] | S02 card | history, measure now, auto-measure setting | chart, measure button | measuring, timeout, unsupported |
| S05 | Metric detail: blood oxygen [BloodOxygen] | S02 | same pattern | | |
| S06 | Metric detail: blood pressure [BloodPressure, BloodPressureAdd] | S02 | device + manual entries | chart, form | |
| S07 | Metric detail: sleep [Sleep, SleepDetail, SleepApnea] | S02 | stages bar, night list | stage bar | no data |
| S08 | Metric detail: stress, temperature, breathing, glucose, weight, menstrual, MET [Fatigue, Temperature, Breathe, BloodGlucose, Weight, Menstrual, Valid] | S02 | one generic detail screen per metric | chart, list | |
| S09 | Workouts [Sport, SportList, SportDetails] | tab 2 | history list, summary stats | list, chart | empty |
| S10 | Start workout [SportGo, SportSelectType] | S09 | phone-led GPS workout with live HR | map, big numbers | GPS denied, paused |
| S11 | Workout detail [SportDetails, SportDynamicTrail] | S09 row | route, HR chart, splits | map, chart | |
| S12 | Watch faces [DialMarket, AlbumDial, DiyDial…] | tab 3 | my faces, create, import | grid, preview | unsupported device |
| S13 | Face editor [AlbumDialNew, DiyDial, PuzzleDial] | S12 | photo picker, crop, style, colour, preview | PhotosPicker, crop, color well | |
| S14 | Transfer progress | S13 / S15 | progress, cancel, result from device | progress ring | failed, done |
| S15 | Files & media [DeviceGallery, LocalMusic, EBookList, NoteAudio] | tab 3 section | send photos / music / books | list, file importer | unsupported |
| S16 | Watch apps [AppMarket, AppMarketInfo] | device tab | installed list, uninstall | list | unsupported |
| S17 | Device (home) [DeviceDetail, DeviceInfo] | tab 4 | connection, battery, firmware, capabilities, settings list | header card, list | disconnected, connecting |
| S18 | Add device / scan [DeviceConnect, NewDeviceConnect] | S17 | scan list with RSSI, connect | list, signal bars | Bluetooth off, none found |
| S19 | My devices [DeviceManagement] | S17 | saved devices, switch, forget | list | |
| S20 | Notifications [DeviceNotify] | S17 | per-category switches on the watch, ANCS explanation | toggles | |
| S21 | Alarms [Clock, ClockDetail] | S17 | list, add, edit | time picker, weekday chips | max reached |
| S22 | Reminders [HealthReminder, WashHandTiem] | S17 | sedentary, drink water, others | toggles, time range | |
| S23 | Do Not Disturb / sleep mode [NotDisturb, SleepMode] | S17 | time ranges | | |
| S24 | Display [DeviceOtherSetting] | S17 | raise to wake, brightness (if supported) | toggles, slider | unsupported |
| S25 | Language, units, time format [SetLanguage, Unit, TemperatureUnit] | S17 | | pickers | |
| S26 | Weather [Weather] | S17 | on/off, location, push now | toggle | location denied |
| S27 | Contacts & SOS [Contact] | S17 | pick contacts, send | contact picker | |
| S28 | Camera remote [Camera] | S17 | camera preview, shutter from watch | camera view | camera denied |
| S29 | Find watch / find phone | S17 | ring watch; respond when watch rings phone | big button | |
| S30 | Firmware [DeviceUpdate, DeviceUpdateInfo] | S17 | version, update (locked, consent-gated) | info rows | blocked |
| S31 | Advanced: reset / clear data | S17 | destructive actions with typed confirmation | destructive button | |
| S32 | Settings (app) [Setting, About, Privacy] | tab 4 / profile | profile (height, weight, age), goals, Apple Health, units, about | form | |
| S33 | Debug / packet log [BleDebugMonitor] | hidden (long-press version) | raw packets in/out, export | log list | |

Counts: **33 screens**.

## Flows

```
F01 First connect           S01 -> S18 -> S17                 (4 taps)   edge: BT off, watch already bonded to Android, not found
F02 Morning sync            app open -> auto reconnect -> S02 (0 taps)  edge: background killed, partial sync
F03 Measure heart rate      S02 -> S04 -> Measure             (2 taps)   edge: not worn, timeout, unsupported
F04 Create photo face       S12 -> S13 -> pick -> style -> S14 (5 taps) edge: low battery, transfer fails, resolution mismatch
F05 Set an alarm            S17 -> S21 -> add -> save         (4 taps)   edge: max alarms
F06 Phone-led workout       S09 -> S10 -> start/stop -> S11   (3 taps)   edge: GPS denied, BLE drops mid-run
F07 Change watch setting    S17 -> S22..S26 -> toggle         (2 taps)   edge: device rejects / no ack
F08 Export to Apple Health  S32 -> Apple Health -> allow      (3 taps)
F09 Find watch              S17 -> S29 -> Ring                (2 taps)
F10 Factory reset           S17 -> S31 -> type confirm        (4 taps)   gated
```

## Components

metric ring, metric card, range picker (D/W/M), chart (line, bar, stage bar), measure button with
states, list row with toggle, time-range row, weekday chips, device header card (battery, RSSI,
state), scan row (name, id, RSSI bars, family badge), capability chip, progress ring, empty state,
unsupported-feature state (explains why), destructive confirm sheet, toast/banner, photo crop view,
watch-face preview frame (round/square per screen type).

## Inferred data model

```
Device        id (CBPeripheral UUID), name, family (generic|sifli|bluetrum|nordic|hisilicon|unknown),
              firmwareVersion, bandVersionCode, capabilities (set), screen (w,h,shape), lastSeen, isPrimary
              evidence: devices.md §3   confidence: high (fields) / medium (offsets)
HealthSample  id, deviceId?, kind (hr|spo2|bp|temp|stress|glucose|weight|steps|kcal|…), start, end?,
              value, value2? (diastolic), source (device|manual|healthkit|estimate)
              evidence: protocol.md §5, REQUIREMENTS §5 (keep sources separate)   confidence: high
SleepSession  id, deviceId, start, end, stages [(type,start,minutes)]          confidence: medium
DaySummary    date, deviceId, steps, kcal, distance?, activeMinutes?, lightSleep, deepSleep, awake
Workout       id, type, start, end, distance, kcal, avgHR, maxHR, route [(lat,lon,t)], hrSeries, source
Alarm         id, deviceIndex, time, weekdays mask, enabled, label (local only)
Reminder      kind, enabled, start, end, interval
WatchFace     id, name, kind (photo|diy|imported), imagePath, style, createdAt, installedOn [deviceId]
TransferJob   id, kind (face|photo|music|book|file), deviceId, bytesTotal, bytesSent, state, error
PacketLog     t, direction, bytes, decoded label (debug only)
```

## Feature matrix

`replica/features.csv` — with the extra REQUIREMENTS §13 columns.

## Cannot clone (skip rows in the matrix)

Vendor cloud: account, watch-face/app market downloads, firmware downloads, license activation,
algorithm keys, AI/GPT/translation, WeChat/WhatsApp relay, Ximalaya, courses, news, live video,
mall, wallets/pay codes, NFC transit cards, family health warning. Android-only access: reading
other apps' notifications, SMS, call log. Other hardware: glasses, headsets, rings, jacket.

## Size

33 screens, 10 flows, 10 entities. Hard parts: (1) the BLE protocol is unconfirmed until real
packets are captured; (2) watch-face transfer per chip family; (3) iOS background BLE + notification
limits. Size: **L** (a quarter) for full parity with a confirmed protocol; the first build here is
a complete, honest skeleton that compiles only once CI runs.
