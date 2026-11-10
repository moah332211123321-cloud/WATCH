# Firmware update (OTA) — documentation only

**Rule (CLAUDE.md): no firmware is sent to the watch unless the flow is confirmed in Phase 2 and the
user explicitly agrees for that attempt.** A bad flash can brick the watch. Same for factory reset
(`AB 00 03 FF FF 80`) and clear data (`AB 00 04 FF 23 80 00`).

Status: static analysis only. Labels: **O** observed, **D** derived, **I** inferred, **U** unknown.

## 1. Update managers (O: class names; D: dispatch in `DeviceOtaServiceImpl`)

| Manager | Family | Transport | Notes |
|---|---|---|---|
| `NordicOtaMgr` + `NordicDfuService` | Nordic | Nordic Secure DFU, service `FE59`, chars `8EC90001/8EC90002` | uses the `no.nordicsemi` DFU library (zip packages) |
| `SicheOtaMgr.startSiChe` | SiFli | SiFli DFU (`com.sifli.siflidfu.SifliDFUService`) over `…-6473-5f696c666973` | file format U |
| `FOtaMgr` | Bluetrum ("ZK") | FOTA service `FF12`, write `FF15`, notify `FF14`; `com.bluetrum.fota`, `abpartool` | error strings "找不到OTA服务（FF12）" etc. (O) |
| `NetFtpOtaMgr` | Wi-Fi capable devices | EA `25 01` start, `25 02` progress, `25 03` end, `25 04` file list; replies `NetFtpOtaAnalyzer` | firmware fetched over the network by the device (I) |
| `CustomFtpOtaMgr` | custom (glasses?) | U | |
| "ZK OTA fix" | Bluetrum recovery | `sendZkOtaFix1/2` write to `8EC90001/2` on `FE59`; `startZkOta` EA `02 02` | recovery for interrupted updates (I) |

Selection: `DeviceUpdateActivity` reads `DeviceLocalSupports.getOtaType(mac)` and the product id
(special cases for product ids 11 and 23 seen) (D). Value mapping: U.

## 2. Where firmware comes from

- Vendor API: `api/v1/app/firm/queryInfo`, `/device/ota/api`, `/ota/`, `/user/temp/ota_update` [E9];
  version reporting after bind (`DeviceBindMgr.reportDeviceVersion`).
- No firmware images are bundled in the APK (the `.bin.aes` files in `assets/` are AES-encrypted
  AI model files `PMRID_*`, not firmware — I from names; they were not opened or decrypted).
- The download API is private → the iOS app cannot fetch official firmware. An update would only
  be possible with a file the user supplies, for a confirmed flow, with consent.

## 3. Status for the iOS app (proposed)

- Show firmware version (from device info): feasible (`done-unverified` once built).
- Firmware update: `blocked-protocol` until Phase 2 confirms the family and flow **and** a firmware
  file is legally available **and** the user consents. Never automatic.

## 4. Unknowns

1. Which manager the user's watch uses.
2. OTA type values; file formats per family; resume / rollback behaviour.
3. Whether updates are signed/verified by the watch (if signed, we never alter files).
