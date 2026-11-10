# Devices and chipset families — WearFit Pro hw_5.6.19

Status: static analysis only. Labels: **O** observed, **D** derived, **I** inferred, **U** unknown.
Evidence files: `research/evidence/` ([E1]…[E10]); see `protocol.md` for method.

## 1. One app protocol, several chip families

All watches use the same vendor app protocol (AB/EA frames on service `6E400001-…`, see
`protocol.md`) (D: one `BleWatchServiceImpl`, one `DeviceConnectMgr`, no per-chip command sets).
The chip family changes three things: **firmware update**, **watch-face / large-file transfer**, and
**diagnostics**. Each family therefore needs its own driver for those parts.

| Family | Evidence in the APK | What the app uses it for | Identified by |
|---|---|---|---|
| **Generic (Wakeup protocol)** | `com.wakeup.module.device.*`, UUIDs `6E400001/11` | all commands, health sync, custom-dial images, A0/A1 file transfer | default |
| **SiFli** (思澈, "Siche") | packages `com.sifli.siflicore`, `serialtransport`, `siflidfu`, `watchfacesdk`, `watchfacelibrary`, `siflireadersdk`, `ezip`; native `libsfwatchface.so`, `libezip.so`; UUID base `…-6473-5f696c666973` (O) | firmware DFU, watch-face push (`SFWatchfaceFilePushManager`, unzips `wf.zip`), video preview (`SFPreviewVideoManager`), e-book reader, logs, camera/navi/picture transfers (`SicheTransferMgr*`) | capability `IS_SICHE = 123` [E3]; `SicheSettingAnalyzer` |
| **Bluetrum** (中科蓝讯, "ZK") | `com.bluetrum.fota`, `com.bluetrum.abpartool`, `libabpartool.so`; FOTA service `FF12` (O); labels "中科FOTA数据", "中科OTA修复指令", "中科弹幕图片", "中科AIGC图片" | firmware FOTA, OTA recovery via `FE59/8EC9…`, barrage/AIGC images, emoji images | `DeviceLocalSupports.isSupportFOta`, OTA type (U which value) |
| **Nordic** (nRF) | `no.nordicsemi` DFU library (458 classes), `NordicDfuService`, `NordicOtaMgr`, `NordicDialUtil` | firmware DFU, watch-face install through DFU | `DeviceInfoModel$Byte15Model.nordic` (int field; bit position U) |
| **HiSilicon** (海思, "Haisi") | `com.hispark.clouddiag`, `com.hispark.crashdump`; `HisSppMgr`, `DeviceHisLogMgr`, `DeviceHisCrashDumpMgr` | diagnostics: logs and crash dumps (over classic-BT SPP — I from `HisSppMgr` name) | capability `IS_HAISI = 266` [E3] |

Searched and **not found** (search boundary: top-level package names of all 136,901 DEX classes and
the native library names): JieLi (杰理 / RCSP), Realtek (RTK), Actions, Telink, Airoha, Goodix SDKs (D).

## 2. Non-watch device types in the same app (out of scope — user owns a watch)

Headsets (`com.wakeup.module.device.headset`, `module.bt.headset` screens, TLV protocol), smart
glasses (`com.wakeup.module.glasses`, 47 screens, Beken IoT Wi-Fi provisioning `BleDeviceActivator`,
`GlassesOrder` EA `33/34/37/43`), "jacket" (`module.jacket`), rings (`RingOrder`, EA `18`).
Status for all of these: `skip` (reason: not the user's device; can be revisited if needed).

## 3. How the app identifies a device

1. **Scan** (`lib.scan.BleScanner`, `BleScanRuleConfig`, `DeviceConnectMgr.scanDevice`): by
   Bluetooth name / MAC; a "bleNameList" filter exists (D). The list of accepted names: U (comes
   from the server product list, `DeviceProductListActivity`, `/client/product_id` [E9] — I).
2. **Device info** request `AB 00 04 FF 92 80 01` → `ConnectAnalyzer.analyzeInfo` fills
   `DeviceInfoModel` (fields O [E7]): `bandVersionCode`, `protocolVersionCode`, `otaVersionCode`,
   `equipmentCode`, `license`, `watchfaceBgNum`, `byte11…byte18`, `info2Byte5…7`. Byte offsets: U.
3. **Capability bit-fields** decoded from those bytes (field names O [E7]):
   - `Byte11Model`: `isLicense`, `isOta`
   - `Byte12Model`: `isAlp`, `isWxp` (Alipay / WeChat pay)
   - `Byte15Model`: `canSet12Hours`, `canSetSleepTime`, `canSetStepLength`, `hasHeartWarn`,
     `isOpenWechatSport`, `menstruationSwitch`, `needPhoneSerialNumber`, `nordic`
   - `Byte16Model`: `hasBloodOxygen`, `hasBloodPressure`, `hasContinuousHeartRate`, `hasECG`
   - `Byte17Model`: `hasConverse`, `hasInstagram`, `hasJiuzuotixing` (sedentary), `hasPagesManager`,
     `hasWeather`, `heartRateHongwai` (infrared HR), `heartRateSaveBattery`, `moreMessage`
   - `Byte18Model`: `resolution[]`, `screenType`, `size`
   - `Info2Byte5Model`: `continuousTemperature`, `hasBodyTemperature`, `hasImmunity`
   - `Info2Byte7Model`: `type`
   - Second info block (`analyzeInfo2`): `equipmentCode` from bytes 6..13, `watchfaceBgNum` from byte 14,
     a JS-framework version from byte 15 (D, partial).
4. **Screen** (EA `14 01` → `DeviceLocalSupports.saveScreen`): `width`, `height`, `screenType`, `rotate`.
5. **Supports list** (`DeviceModel.supports`, IDs in `DeviceFeatures` [E3], 169 IDs from `STEP=1`
   to `APP_NOTE_AUDIO=280`): provided by the vendor server at bind time; a local default
   (`createInitSupport`) is used before that (D). **The iOS app cannot rely on it** (private API).
6. **OTA type** (`DeviceLocalSupports.getOtaType`, stored in `DeviceLocal`): selects Nordic / SiFli /
   Bluetrum / Wi-Fi-FTP path. Where the value comes from and its mapping: U.

## 4. Consequences for the iOS `WatchDriver` design (input for Phase 3)

- One `WakeupProtocol` core (framing, reassembly, command encoders/decoders) shared by all drivers.
- Per-family plug-ins only for: firmware update, watch-face/file transfer, diagnostics.
- Capabilities come from device-info bit-fields + screen info + probing; never from the vendor server.
- Model list cannot be taken from the server; start with **the user's own watch** and add models
  only when verified.

## 5. Unknowns

1. The user's watch model, chip family and firmware version (Phase 2: ask the user, read device info).
2. Byte offsets of the device-info reply and which bit means what.
3. Origin and values of the OTA type.
4. Scan name filters / advertised service UUIDs per family.
5. Whether HiSilicon watches use BLE for the main protocol too (I: yes, same `DeviceConnectMgr`).
