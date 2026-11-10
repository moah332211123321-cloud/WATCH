# BLE protocol — WearFit Pro (`com.wakeup.howear`, version hw_5.6.19)

Status: **static analysis only (Phase 1)**. Nothing here has been seen on the air yet. Every
command must be confirmed against the user's HCI snoop log in Phase 2 before a driver relies on it.

## How this was produced, and how to check it

- Neither decompiler was available: Craft Anything runs in Clean room (Deep mode off), and REA has
  no JADX JAR / apktool / JDK configured. So the DEX files were read with small standard-library
  parsers written for this project (`research/tools/`): `dexdump.py` (strings, classes, fields,
  static constants), `dexasm.py` (a smali-like listing of constants, strings, invokes, field refs,
  byte-array fills and switch tables), `tmpl.py` (rebuilds the byte template of every method that
  builds a packet), `androidres.py` (string resources and the binary manifest). They only parse
  bytes; nothing from the APK was executed.
- Re-run: `python -I research/tools/dexdump.py <apk-unzip-dir> <out>`, then
  `python -I research/tools/tmpl.py <apk-unzip-dir> Lcom/wakeup/`.
- Evidence files are in `research/evidence/` and are cited as `[E1]` … `[E10]`. Class and method
  names are cited as `Class.method` (obfuscation is light; names are real).
- Confidence labels: **O** = observed constant in the bytes, **D** = derived from the bytecode
  flow by the tools above, **I** = inference. **U** = unknown.

## 1. Architecture of the BLE layer (D)

- `com.wakeup.commponent.module.ble.BleWatchService` (impl `com.wakeup.module.ble.BleWatchServiceImpl`,
  168 methods) and ~40 `*Order` classes build packets. Each returns a `BleOrderModel`
  (`type` label string, `bytes`, `isSplit`, `splitNum`) [E1].
- `com.wakeup.module.device.work.DeviceConnectMgr` owns the connection, write queue (`WriteQueue`,
  deferred/pending writes, reconnect-safe orders) and notification channels.
- Two interchangeable GATT stacks: `FastBleStack` and `NordicBleStack` (Nordic Android BLE lib),
  chosen by a remote A/B flag `superAppServiceOptimizeConfig/enableNordicBleStack`
  (`BleStackFactory.init`) (D). Both speak the same app protocol; this is an Android-side choice,
  not a watch family.
- Incoming notifications go through `WatchNotify.onCharacteristicChanged` → `DataPackager`
  (reassembly) → a list of analyzers (`com.wakeup.module.device.work.analyzer.*`) [E2].

## 2. GATT services and characteristics (O, from `BleUUID` statics [E7] and const-strings)

| Purpose | Service | Write | Notify | Used by |
|---|---|---|---|---|
| Main command channel (all watches) | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` | `6E400002-…` | `6E400003-…` | `DeviceConnectMgr`, `BleUUID.WATCH_*` |
| File transfer channel | `6E400011-B5A3-F393-E0A9-E50E24DCCA9E` | `6E400012-…` | `6E400013-…` | `BleUUID.FILE_TRANS_*`, `WriteQueue`, `FileTransNotify` |
| SiFli ("Siche") serial transport / DFU / log | `00000000-0000-0000-6473-5f696c666973` | `00000000-0000-0200-6473-5f696c666973` | same char | `com.sifli.serialtransport`, `SifliDFUService`, `SicheLogHandler` |
| Bluetrum ("ZK", 中科) FOTA | `0000FF12-0000-1000-8000-00805F9B34FB` | `0000FF15-…` | `0000FF14-…` | `BleUUID.ZK_FOTA_*`, `FOtaMgr`, `com.bluetrum.fota` |
| Nordic Secure DFU (also "ZK OTA fix") | `0000FE59-0000-1000-8000-00805F9B34FB` | `8EC90001-F315-4F60-9FB8-838830DAEA50`, `8EC90002-…` | — | `no.nordicsemi` DFU lib, `BleUUID.ZK_OTA_FIX_*` |
| Pay code (Alipay offline code, China) | `00003803-0000-1000-8000-00805F9B34FB` | `00004A03-…` | `00004A03-…` | `SichePayCodeHandler` |
| Beken IoT activator (Wi-Fi provisioning; glasses/IoT, not watches — I) | `0000EA01-…` / `0000FA00-…` | `0000EA02-…` | `0000EA05/EA06-…` | `com.beken.iot.smartsdk.core.ble.BleDeviceActivator` |

Note: the `6E4000xx` UUIDs are the Nordic UART Service base, reused by the vendor on all chips (I).

## 3. Framing

### 3.1 "AB" frames (classic command set) — D

```
byte 0     0xAB
byte 1..2  length, big-endian = total_frame_length - 3
byte 3     0xFF
byte 4     command id
byte 5     0x80 for most commands (sometimes a sub-command / first parameter)
byte 6..   payload
```

Evidence: 77 statically resolved AB templates [E1], e.g. `BleWatchServiceImpl.findBand` =
`AB 00 03 FF 71 80` (total 6 bytes, length field 3); `setTimeSync` = 14 bytes with length `0x0B`.

### 3.2 "EA" frames (newer command set) — D

```
byte 0     0xEA
byte 1..2  length, big-endian = total_frame_length - 3
byte 3     0x00 in most builders, 0xFF in a few (e.g. mesNotifyPush)   — meaning U
byte 4     command group
byte 5     sub-command
byte 6..   payload
```

Evidence: 234 EA templates [E1], e.g. `EQOrder.requestDeviceEQMode` = `EA 00 03 00 1F 03`.

### 3.3 Reassembly of notifications — D (`DataPackager.packageData`)

A notification shorter than 3 bytes is ignored. Expected total = `((b[1]&0xFF)<<8 | (b[2]&0xFF)) + 3`.
If the first notification is shorter, following notifications are appended until the buffer is full;
a mismatch clears the buffer. **No checksum is verified on AB/EA frames** in this path, and none of
the 311 statically resolved AB/EA templates ends with a checksum. The 35 dynamically built packets
were not all traced (U).

### 3.4 Writing — D

- `SplitWriter.splitByte` splits a long packet into chunks (size from the negotiated MTU stored as
  `device_mtu`) and sends them with a delay `mIntervalBetweenTwoPackage`; it warns above 20 chunks.
- `getMtu` = `AB 00 04 FF A7 80 ??`; speed switch `switchSpeed` = `AB 00 04 FF 87 80 ??`
  (labels "BLE高速传输/低速传输" = high/low-speed transfer).
- Values of the write interval and whether writes are with/without response: U.

### 3.5 File-transfer frames ("A0"/"A1") and CRC — D

- `FileTransferOrder.genFileHead` builds a head frame starting `0xA0`; `genFileBlock` builds data
  blocks starting `0xA1`, each with a block CRC (`BleUtil.crcTable`); the head carries a whole-file
  CRC (`BleUtil.crcFile`). Exact field order inside head/block: U (built with helper calls).
- **CRC = CRC-16/MODBUS**: table entry 1 = `0xC0C1` (reflected poly 0x8005 → 0xA001), init `0xFFFF`,
  `crc = (crc >>> 8) ^ T[(crc ^ b) & 0xFF]`, no final XOR (`BleUtil.<clinit>` table, `crcTable`).
- Responses: `SEND_TRANS_FILE_HEAD_RESP` / `SEND_TRANS_FILE_DATA_RESP` labels exist
  (`WatchBleOrder` [E7]); their byte layout: U.

## 4. Command catalog

The full list (346 builders: frame, command, sub-command, template with `??` for runtime values,
and the APK's own Chinese label) is `research/evidence/E1-commands.tsv`. Main ones grouped by
feature (AB unless marked EA):

| Feature | Command | Template / notes |
|---|---|---|
| Time sync | `93 80` | `AB 00 0B FF 93 80 00 YY YY MM DD hh mm ss` (year 16-bit BE) — D |
| Time zone | EA `93 01` | `setTimeZoneSync` |
| 12/24 h | `7C 80` | `AB 00 04 FF 7C 80 <v>` |
| Language | `7B 80`; EA `7B 01` (v2); EA `7B 80` | `setBandLanguage`, `setBandLanguage2`, `setSetLanguageSettings` |
| Phone OS | `20 80` | `AB 00 05 FF 20 80 01 02` (constant in `setSendPhoneSystem`) |
| Device info | `92 80 01` | request; reply parsed by `ConnectAnalyzer` (see §5) |
| SN / FN | `AA 80` / EA `AA 01` | `getDeviceSN`, `getDeviceFN` |
| Audio (classic BT) MAC | `A6 80` | `getAudioBleMac`; BT status EA `3A 01`, reconnect EA `3A 02`, dual-link EA `E3 01` |
| Find watch | `71 80` | `AB 00 03 FF 71 80` |
| Single / real-time measure | `31 <type> <on>` | `setOnceOrRealTimeMeasure`; body temp `86 80 <v>` |
| Hourly auto measure | `78 80 <v>` | `setOnTimeMeasure` |
| User profile | `74 80` | 12-byte payload (`sendUserInfo`), fields U |
| Sedentary | `75 80` + 6 bytes | `setSedentaryWarn` |
| Drink water | `53 80` + 6 bytes | `setDrinkWater` |
| Alarm | `73 80` + 6 bytes | `setAlertClock` |
| DND | `76 80` + 5 bytes; EA `76 01` | `setDisturbanceModel`, `notDisturbMode` |
| Raise to wake | `77 80 <v>`; EA `77 01` | `setUpHandLightScreen`, `setWakeUpScreenSettings` |
| Shake to take photo | `79 80 <v>` | camera remote; live preview EA `15 03/04` |
| Sleep range / sleep mode | `7F 80` + 5 bytes; EA `7F 01` | `setSleepTimeRange`, `setSleepMode` |
| Notification switches | `72 80 <type> <on>` | `smartWarnNoContent`; with content: `setSmartWarnCarryContent` (dynamic, UTF-8); EA `72 01` `mesNotifyPush` |
| Reminders (sport/medicine/read/travel) | `9E` + 6 bytes | `setRemind`; HR/eyes `9F`, exercise duration `9F 03`, activity count `9F 04`, MET goal `9F 06`, heat `9F 07` |
| Reminder master switch | `A0 80` | `reminderSwitch`; heart warning EA `A0 01` |
| Contacts | `A5 80` (count + SOS), `A2 FE` name, `A3 FE` phone | dynamic lengths |
| Weather | `7E 80`, `88 80` (17-byte payload each); EA `7E 01` city, EA `7E 02` forecast; switch `SEND_WEATHER_SWITCH` | `sendWeatherInfo`, `sendWeatherInfo2`, `sendCityName`, `sendCityWeather` |
| Air pressure / UV, altitude | `8A 80`, `E4 80` | |
| Temperature unit | `EF 80 <v>` | |
| Sync health history | `52 80` + 4 bytes (sleep), "SYNC_DATA_ORDER2" (dynamic, date-based) | `syncSleepData`, `setSyncDataHr` |
| Sport (phone-led) | `E1 80`, `EA 80`, `E9`, `EB 80 01` | status, data, response, disconnect check |
| GPS data / log | EA `1C 01`, EA `1B 04`; phone location EA `1B 02`, EA `3E 01`; ephemeris EA `1B 01` | |
| Menstrual | `E7 01` (dynamic), `E7 00` | |
| QR code | `A8 <v>` | |
| App market on watch | `C9` + 3 bytes; EA `13 01` list, EA `13 02` uninstall | |
| Watch faces / images | see `watchface-format.md` | `9C`, `AD 80`, EA `0A`,`0D`,`0F`,`08`,`3D` |
| Clear data | `23 80 00` | **destructive** |
| Factory reset | `FF 80` | `AB 00 03 FF FF 80` — **never send without explicit user consent** |
| Disconnect / connect type | `E0 80 <v>` | `sendConnectRequestType` |
| Heartbeat reply | EA `0B 02` | `replyDeviceHeartBeat` |
| Schedule | EA `36 01/02` | |
| EQ | EA `1F 01..03` | |
| Local music on watch | EA `10 01/02` | |
| Wi-Fi (Wi-Fi models) | EA `33 01..10` | |
| License / algorithm keys | EA `38 01` sendLicense, EA `43 08` requestLicenseEncryption, EA `2F 01` sleep-algorithm key, EA `2F 02` "YouJie" key, `CB` license number | values come from the vendor server — see §6 |
| Cloud AI features | EA `05`, `17`, `24`, `25`, `26`, `28`, `32`, `3C`, `46`, `4B` … | GPT, translate, AI music, LLM — need the vendor's cloud |
| China-only services | EA `35` WeChat, EA `47` WhatsApp, EA `2C` Ximalaya, EA `06` Muslim prayer/Qibla, `E5` nucleic-acid code, pay code service | |

## 5. Receive side (D, [E2])

`HealthDataAnalyzer.analyzeOrder` (frames with `b[0]=0xAB`, dispatch on `b[4]`, then `b[5]`):

| b[4] | b[5] | Handler (`DataSyncMgr` → `DataSyncProxy`) |
|---|---|---|
| `31` | `09` / `0A` | single / real-time heart rate |
| `31` | `11` / `12` | single / real-time SpO2 |
| `31` | `21` / `22` | single / real-time blood pressure |
| `31` | `41` | single "immunity" |
| `31` | `81` | single temperature |
| `32` | — | `saveOnceKey` |
| `51` | `08` | current day summary (`saveCurrentStep`) |
| `51` | `0B` | stress/pressure (`savePressure`) |
| `51` | `11`/`12`/`13`/`14` | history HR / SpO2 / temperature / BP |
| `51` | `18` | history immunity |
| `51` | `20` / `21` | hourly measurement v1 / v2 |
| `52` | — | sleep history (`saveSleep`) |
| `B7` | — | sport records (`saveSport`) |

Current-day summary `AB .. 51 08` payload (D, `DataSyncProxy.saveCurrentStep`, needs ≥16 bytes):
steps = `b6<<16 | b7<<8 | b8`; kcal = `b9<<16 | b10<<8 | b11`; light sleep minutes = `b12*60 + b13`;
deep sleep minutes = `b14*60 + b15`; awake count = `b16`; if length ≥18: sport time = `b17..b18`;
if length ≥19: sport count = `b19`. Units of kcal and distance: U.

Other analyzers (all D, dispatch values in [E2]): `ConnectAnalyzer` (`20`,`21`,`92` device info,
`9B`,`A1`,`A6`,`CB`,`E0`), `CommonAnalyzer` (`79`,`7B`,`7D`,`87`,`91`,`A8`,`AA`,`C9`),
`MusicControlAnalyzer`, `CameraControlAnalyzer` (EA `15`), `DialAnalyzer`, `GpsAnalyzer` (EA `1B`, `3E`),
`EQModeAnalyzer` (EA `1F`), `HealthDataAnalyzer2` (EA `2A 01` sleep apnea), `OtherAnalyzer` (EA `13`,
`14` screen size, `17`, `1A`, `1D`, `22`…), `MenstrualAnalyzer`, `NetFtpOtaAnalyzer` (EA `25`),
`FriendsAnalyzer`, `SettingsAnalyzer`, `SicheSettingAnalyzer`, `CallRecordAnalyzer` (EA `40`).

Field layouts for sleep, sport, HR history, device info: **U** (parsers are long coroutine
lambdas; to be traced next, then confirmed with Phase-2 bytes).

## 6. Authentication, encryption, server dependence

- **No pairing key, challenge or encryption was found on the main AB/EA channel** (no crypto calls
  in `DeviceConnectMgr`, `WatchNotify`, `DataPackager`, `SplitWriter`) (D, search boundary: those
  classes and the AB/EA builders).
- **License:** after connect, `DeviceBindMgr.startBind` asks the watch for an encrypted license
  (`requestLicenseEncryption`, EA `43 08`); if the device-info model carries a license,
  `matchLicense` activates it on the vendor server (`BasicRequest$ActivateLicense`,
  `/license/device/file`, `/license/permission/verify` [E9]). Whether the watch refuses to work
  without this: **U**. If it does, that part is `blocked-protocol` (server-side authorization —
  we will not bypass it).
- **Algorithm keys:** `OtherAnalyzer.getGoMoreKey`, `getYouJieKey`, `handleLicense` fetch keys from
  the server and send them to the watch (EA `2F 01/02`, EA `38 01`). Which watch features depend on
  them (sleep staging? sport recognition?): **U**.
- **Capabilities ("supports")** are a list of `DeviceFeatures` IDs [E3]. On first connect the app
  uses a local default (`DeviceFeatures.createInitSupport`); the real list comes from the vendor
  server at bind time. The iOS app cannot use that private API, so it must derive capabilities
  from the watch's own device-info bit-fields (§ devices.md) and by probing. (D)

## 7. Unknowns (to settle in Phase 2 or by deeper tracing)

1. Meaning of byte 3 (`00` vs `FF`) in EA frames.
2. Write type (with/without response) and inter-packet delay.
3. Device-info (`92`) reply byte offsets (fields known by name only, see devices.md).
4. Sleep, sport, history record layouts; timestamps and units.
5. Whether license / algorithm keys are required for basic functions.
6. Bytes of the 35 dynamically built packets (contacts, notifications, weather, file head/block).
7. How the watch notifies "find phone", camera shutter, music keys (analyzers identified, bytes U).
8. Which family the user's watch belongs to (decides OTA / watch-face path).
