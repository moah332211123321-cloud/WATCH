# Feature inventory — WearFit Pro hw_5.6.19 (`com.wakeup.howear`)

Status: static analysis only (Phase 1). Screens come from the manifest [E5] (516 app activities
out of 620 total), capabilities from `DeviceFeatures` [E3], commands from [E1]. Status column is a
**proposal** for the iOS app; final status is set in `replica/features.csv` after Phase 2–5.

Labels: **O** observed, **D** derived, **I** inferred, **U** unknown.

## 0. Coverage and gaps

- 516 native screens (Activities) in `com.wakeup.*` (O). Fragments were not inventoried
  individually (U).
- Part of the UI is **React Native** (`assets/index.android.bundle`, Hermes bytecode v96, routes like
  `/devicePage/dialMarket`, `/devicePage/contact`, `/devicePage/update` [E9]). The bundle was not
  decoded (no Hermes tool available) → screens living only there are **U**. Phase 2 screenshots close this gap.
- String resources: 7,926 default (mostly Chinese/English) and 52 locales; **Arabic (`ar`): 5,879
  strings** [E10]. Text is not copied into the new app.
- Large parts of the app are not about the watch: ads (Pangle, AppLovin, Mintegral, Unity, Yandex,
  Bigo…), Chinese payments, live video, courses, news, mini-programs, AI chat. Listed in §12 as `skip`.

## 1. Device discovery and connection (REQUIREMENTS §4)

| Feature | Original evidence | iOS note | Proposed status |
|---|---|---|---|
| Scan, list, connect, disconnect | `DeviceConnectActivity`, `NewDeviceConnectActivity`, `DeviceManagementActivity`, `BleScanner`, `DeviceConnectMgr` | CoreBluetooth | done-unverified after build |
| Auto-reconnect, saved devices | `AutoConnect`, `AutoStrategy`, `DeviceDao.saveLastDeviceMac` | `bluetooth-central` background mode, state restoration | partial (iOS background limits) |
| Bind / unbind | `DeviceBindMgr`, `UNBIND_ORDER` | local only; vendor server bind not used | partial |
| Device info, firmware version, battery | `DeviceInfoActivity`, `92 80 01`, `DeviceInfoModel` | — | needs Phase 2 layout |
| Capability detection | `DeviceFeatures` (169 IDs), device-info bit-fields | from device bytes, not server | partial |
| Dual-mode BT (calls/audio) pairing | `DualModeBtPairManager`, `getAudioBleMac`, EA `3A`, EA `E3 01` | classic BT pairing is done in iOS Settings | blocked-ios (app side) |
| Multiple devices | `DeviceManagementActivity`, `MultipleBluetoothController` | | partial |
| License activation | `DeviceBindMgr.matchLicense` (vendor server) | | blocked-protocol if required (U) |

## 2. Health (REQUIREMENTS §5) — `feature.health.*` (88 screens)

| Feature | Screens | Capability | Protocol | Proposed |
|---|---|---|---|---|
| Steps, calories, distance, goal | `Step`, `SetStepGoal`, `StepShare`, `health.rainbow.*` (daily activity rings) | `STEP=1`, `GOAL_COMPLETION=101` | `51 08` summary (layout D) | done-unverified |
| Heart rate (single, real-time, history, settings, warning) | `Heart`, `HeartRateSetting`, `HeartRingSetting`, `HrEarlyWarning` | `HEARTRATE=5`, `HR_MONITOR_WARNING=89`, `REMIND_HR=56` | `31`, `51 11`, EA `A0 01` | Phase 2 |
| Blood oxygen | `BloodOxygen` | `BLOOD_OXYGEN=4`, `BLOOD_OXYGEN_MEASUREMENT=95` | `31 11/12`, `51 12` | Phase 2 |
| Blood pressure (device + manual) | `BloodPressure`, `BloodPressureAdd` | `BLOOD_PRESSURE=3` | `31 21/22`, `51 14` | Phase 2 |
| Sleep, sleep detail, sleep apnea | `Sleep`, `SleepDetail`, `SleepInfo`, `SleepApnea`, `lenovo.LenovoSleep` | `SLEEP=7`, `SLEEP_APNEA=194`, `CONFIG_SLEEP=186` | `52`, EA `2A 01`; sleep-algorithm key EA `2F 01` | Phase 2; key dependency U |
| Stress / pressure | `Fatigue` | `FATIGUE=48` | `51 0B` | Phase 2 |
| Body temperature (device + manual) | `Temperature`, `TemperatureAdd` | `TEMPERATURE=30`, `TEMPERATURE_UNIT=155` | `31 81`, `51 13`, `86 80`, `EF 80` | Phase 2 |
| Breathing training | `Breathe`, `fatigue.activity.BreathTrain*` | `BREATHE=66` | `SEND_BREATHE` (dynamic) | Phase 2 |
| "Immunity" | `Immunity`, `ImmunityInfo` | `IMMUNITY=31` | `31 41`, `51 18` | Phase 2 |
| ECG | — (capability only) | `ECG=28` | U | U |
| Blood glucose (manual + device estimate) | `BloodGlucose*`, `diabetes.*` | `BLOOD_SUGAR=64` | `SEND_GLUCOSE` | Phase 2 (keep estimates labelled) |
| Weight, BMI, body fat, muscle mass | `Weight*`, `bodyindex.*` | `WEIGHT=46` | `C8 04/05`, `SEND_BMI`, `SEND_WEIGHT` | manual data + send |
| Menstrual tracking | `Menstrual*` (7) | `MENSTRUATION_ASSISTANT=34`, `WOMAN_ASSISTANT=113` | `E7 00/01` | Phase 2 |
| MET / valid activity | `Valid`, `ValidShare` | `VALID_ACTIVITY=49`, `SYNC_MET=165` | `51 09`, `9F 06` | Phase 2 |
| Health dashboard, totals, reports | `HealthDashboard`, `HealthTotal*`, `HealthInfo` | `HEALTH_REPORT=23` | — | done-unverified (local) |
| Health warning to family (cloud) | `health.warning.*` | — | vendor cloud | skip (private API) |
| Apple Health export | — (new) | — | HealthKit | done-unverified after build |

## 3. Watch faces (REQUIREMENTS §6, §12) — see `watchface-format.md`

24 screens in `feature.device.dial.*` + AI dial screens. Market: `skip` on vendor servers, replaced
by own/imported/licensed faces. Photo/DIY faces: Phase 2.

## 4. Watch apps / packages (REQUIREMENTS §7)

| Feature | Evidence | Proposed |
|---|---|---|
| App market on the watch (install, uninstall, list) | `AppMarketActivity`, `AppMarketInfo`, `AppMore`, `ApplicationMarket`; `MARKET_INSTALL` `C9`; EA `13 01/02`; capability `APP_MARKET=45`, `APP_MARKET_NEW=159`; API `applicationSuperMarket/*` | install packages come from the vendor server → `blocked-protocol` for downloads; list/uninstall: Phase 2 |
| Mini-apps (music, audiobooks) | `MINI_MUSIC_APP_ID`, `MUSIC_MINI_PROG`, `com.phancy.mini` SDK | skip (vendor cloud) |

## 5. Files and media (REQUIREMENTS §8)

| Feature | Evidence | Proposed |
|---|---|---|
| Photos / wallpapers to watch | `NormalMTransfer`, `SichePictureTransfer`, gallery EA `1A`, `DeviceGalleryActivity`, `LOCAL_GALLERY=176` | Phase 2 |
| Local music to watch | `LocalMusicActivity`, EA `10 01/02`, `LOCAL_MUSIC=156` | Phase 2 (file format U) |
| E-books | `EBookList`, `LocalEBook`, EA `19 01`, SiFli reader SDK, `E_BOOK=173` | Phase 2 |
| Audio notes / memos | `NoteAudio*`, `Memorandum*`, EA `49`, `AUDIO_MEMORANDUM=175` | Phase 2 |
| Generic file transfer (A0/A1, CRC-16/MODBUS) | `FileTransferMgr`, service `6E400011` | Phase 2 |

## 6. Device control (REQUIREMENTS §9) — `feature.device.setting.*` (16 screens)

| Feature | Screen | Capability | Command | Proposed |
|---|---|---|---|---|
| Brightness / wake screen | `DeviceOtherSetting` | `BRIGHT_SCREEN=19`, `WAKE_UP_THE_SCREENE=85`, `MSG_LIGHT_SCREEN=189` | `77 80`, EA `77 01` | Phase 2 |
| Screen timeout | U | U | U | U (not found by name) |
| Vibration | U | U | U | U |
| Alarms | `Clock`, `ClockDetail`, `ClockNameEdit` | `ALARM_CLOCK=13` | `73 80` | Phase 2 |
| Weather | `Weather` | `WEATHER=6`, `WEATHER_PUSH=115` | `7E 80`, `88 80`, EA `7E 01/02` | done-unverified (weather source: WeatherKit or open data) |
| Language | `SetLanguage` | `SET_THE_LANGUAGE=75` | `7B 80`, EA `7B 01/80` | Phase 2 |
| Time format, time sync, time zone | — | `TIME_SYSTEM=25` | `7C 80`, `93 80`, EA `93 01` | done-unverified |
| Units | `Unit`, `TemperatureUnit` | `UNIT_SWITCH=26`, `TEMPERATURE_UNIT_SWITCH=65` | `EF 80`, others U | Phase 2 |
| Notifications (per-app switches) | `DeviceNotify` | `NOTIFICATION=11` | `72 80`, EA `72 01` | partial — see §8 |
| Contacts, SOS | `Contact` | `CONTACT=10`, `NEW_CONTACT=162` | `A5 80`, `A2 FE`, `A3 FE` | done-unverified (Contacts framework) |
| Camera remote | `Camera` | `REMOTE_CAMERA=71`, `SHAKE_TO_TAKE_PICTURES=17`, `CAMERA_PREVIEW=164` | `79 80`, EA `15 03/04` | Phase 2 |
| Find watch | — | `FIND_BOND=14` | `71 80` | done-unverified |
| Find phone | — | `FIND_PHONE=16` | `FindPhoneUtils` (watch → phone, bytes U) | partial (iOS: local notification/sound) |
| Music control | — | `MUSIC_CONTROL=18` | `MusicControlAnalyzer` (bytes U) | partial (iOS limits on controlling other apps) |
| Do Not Disturb | `NotDisturb` | `DND_MODE=77` | `76 80`, EA `76 01` | Phase 2 |
| Sedentary reminder | `HealthReminder` | `SEDENTARY_REMINDER=12`, `STAND_UP_TO_REMIND=97` | `75 80` | Phase 2 |
| Drink water reminder | `HealthReminder` | `DrinkWater=55` | `53 80` | Phase 2 |
| Other reminders (sport, medicine, reading, travel, hand-wash) | `HealthReminder`, `WashHandTiem` | `REMIND_*`=57–61, `TIME_TO_WASH=73` | `9E`, `9F` | Phase 2 |
| Sleep mode, bedside clock | `SleepMode` | `SLEEP_MODE=81`, `BED_CLOCK_MODE=93` | EA `7F 01` | Phase 2 |
| Physical training on/off | `PhyOnOff` | `PHYSICAL_TRAINING_ON_0FF=87` | EA `01 01` | Phase 2 |
| QR codes on watch | `QrList`, `SetQr` | `QR_CODE=54` | `A8` | Phase 2 |
| Schedule / calendar | `Schedule*` | `TYPE_SCHEDULE_NEW=226` | EA `36` | Phase 2 (EventKit) |
| EQ | `EQSetting`, `EQCustom` | `EQ_SET=177` | EA `1F` | Phase 2 |
| Device info, firmware info | `DeviceInfo`, `DeviceUpdateInfo` | — | `92`, `AA`, EA `AA 01` | Phase 2 |
| Firmware update | `DeviceUpdate` | `OTA=21` | see `ota.md` | blocked-protocol (safety rule) |
| Restart | U | U | not found by name | U |
| Factory reset | — | `RESET=15` | `FF 80` | gated behind explicit consent |
| Clear data | — | — | `23 80 00` | gated behind explicit consent |
| NFC cards | `nfc.*` (10) | `NFC_CARD=121` | EA `0E 01` | skip (regional, vendor service) |

## 7. Sports (REQUIREMENTS §10) — `feature.sport.*` (13 screens)

`Sport`, `SportGo` (phone-led workout with GPS, Baidu/AMap maps), `SportList`, `SportDetails`,
`SportDynamicTrail`, `SportSetting`, `SportSelectType`; sport types: 182 constants in
`SportTypeConstant` [E4] (walking, running, cycling, swimming, climbing, badminton, basketball,
football, yoga…, plus device codes `Device_4e`…`Device_8f`). Protocol: device records `B7`
(layout U), phone-led sport `E1 80`/`EA 80`/`E9`/`EB 80 01`, GPS EA `1B`/`1C`.
iOS: CoreLocation + MapKit instead of Baidu/AMap. Proposed: Phase 2.

## 8. Notifications and calls (REQUIREMENTS §11)

| Feature | Original | iOS | Proposed |
|---|---|---|---|
| App notifications | `MyNotificationListenerService` reads Android notifications and sends them (`72 80`, `setSmartWarnCarryContent`) | third-party apps cannot read notifications; the watch may get them via ANCS (U for this watch) | blocked-ios (app forwarding); ANCS U |
| Incoming call alert, caller name | `READ_PHONE_STATE`, `READ_CONTACTS`, EA `20 01` `sendCallStatus` | via ANCS only (U) | blocked-ios / U |
| Missed calls, SMS | `READ_CALL_LOG`, notification listener | not readable on iOS | blocked-ios |
| Bluetooth calling | dual-mode BT (`DualModeBtPairManager`) | paired in iOS Settings (HFP) | blocked-ios (app side) |
| Notification preferences | `DeviceNotifyActivity` | switches on the watch (`72 80`) | Phase 2 |
| Contact sync | `Contact` screen | Contacts framework | done-unverified |

## 9. Other watch features found

Menstrual, Muslim prayer times / Qibla / Quran (`module.religion.*`, EA `06`, `QIBLA=134`), map
navigation on watch (`BMapNavigation`, EA `09`, EA `17`), barrage/emoji images (EA `21`), friends
(health sharing, avatars `C1`–`C5`), medals, annual goals, white-noise / sleep sounds
(EA `2E`, EA `43`), Wi-Fi settings for Wi-Fi models (EA `33`).

## 10. App-level features (no watch involved)

Account/login, settings, units, privacy, help/feedback, log collection, about. New app keeps local
settings, privacy and about; no vendor account.

## 11. Hidden / debug

`BleDebugMonitor`, `MockSleepSoundTransfer`, `SleepSoundDebugActivity`, `HelpLogCollectActivity`,
SiFli/HiSilicon log and crash-dump pulls (`getSicheLog`, `DeviceHisLogMgr`, `DeviceHisCrashDumpMgr`),
device stats requests EA `00 00..04, 30` (power, CPU, OTA results, crash data).

## 12. Out of scope (`skip`, with reason)

| Area | Reason |
|---|---|
| Ads SDKs, analytics | not a user feature |
| WeChat / Alipay / PayPal wallets, pay code, nucleic-acid code, NFC transit cards | regional vendor services, private APIs |
| GPT / LLM / AI music / translation / AI dials / AI album | require the vendor's cloud (private API) |
| WeChat / WhatsApp reply on watch | vendor cloud relay (NATS) |
| Ximalaya, courses, news, live video, mall, energy/VIP orders, mini-programs | vendor content services |
| Glasses, headsets, jacket, rings | not the user's device |

## 13. Unknowns

1. Screens only present in the React Native bundle.
2. Screen-timeout, vibration, restart commands (not found by name).
3. Which features the user's watch actually supports (Phase 2 device info + screenshots).
