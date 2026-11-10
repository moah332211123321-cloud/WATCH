# Watch faces and image transfer — WearFit Pro hw_5.6.19

Status: static analysis only. Labels: **O** observed, **D** derived, **I** inferred, **U** unknown.

## 1. Kinds of watch faces in the app (screens [E5], capability IDs [E3])

| Kind | Screens | Capability ID | Built on the phone? |
|---|---|---|---|
| Market faces (download) | `DialMarket`, `DialInfoDetail`, `DialSearch`, `DialMoreList`, `Dial4G`, `BlindBoxWeb`, `DialExchange` | `DIAL_MARKET=44`, `DIAL_MARKET_TYPE_FREE=149`, `THEME_MARKET=170` | no — file from the vendor server |
| Photo / album face | `AlbumDial`, `AlbumDialNew` | `CUSTOM_DIAL_ALBUM=136` | yes — image + style |
| Module face | `ModuleDial` | `CUSTOM_DIAL_MODULE=137` | yes |
| Puzzle face | `PuzzleDial` | `CUSTOM_DIAL_PUZZLE=140` | yes |
| DIY face (numbers, pointers, positions) | `DiyDial` | `CUSTOM_DIAL_DIY=242` | yes |
| Video face | `VideoDial`, `VideoDialCrop` | `VIDEO_DIAL=184` | yes |
| AI-generated face | `AiDialPlate`, `AiWatchfaceWeb`, `AiGcAlbumDial` | `AI_DIAL_PLATE=160/172`, `AI_ALBUM=174` | vendor cloud |
| Menu wallpaper, desktop wallpaper | `CustomMenuWallpaper`, `Desktop` | `MENU_WALLPAPER=157`, `DESKTOP_WALLPAPER=269` | yes |
| Ring (notification ring) images | `CustomRing`, `CropRing` | `RING=167` | yes |
| Dial memory / thumbnails | — | `DIAL_MEMORY=161`, `DIAL_THUMB=191` | — |

## 2. Custom (photo) face — generic Wakeup path (D)

`com.wakeup.module.device.trans.NormalMTransfer`:
1. `startTransfer`: load each image of the `CustomDialBean`, scale to the device resolution
   (`CustomDialBean.getResolution`, from device info / screen info).
2. `getSourceList`: convert pixels with `BitmapUtils.getHexPixels` + `hexString_16_to_8`
   (I: RGB565, 2 bytes per pixel), split into 1024-byte pieces (`BitmapUtils.split(…, 1024)`).
3. `sendInfo`: compute CRC-16/MODBUS over the data (`BleUtil.crcTable`) and send
   `TransferOrder.startSendPic` (dynamic packet: size / CRC / index — layout U).
4. `sendData`: send each piece with `TransferOrder.sendImageContent` (dynamic, 124-byte groups
   observed as a constant in `sendData` — meaning U); progress via `handlerSendProgress`; the watch
   acknowledges each piece (`handlerAnswer`, "收到写入图片的回调 pkgIndex").
5. Style and options (templates from [E1]):
   - `AB 00 07 FF 9C ?? ?? ?? ?? ??` — style (position / colour, fields U) (`sendStyle`)
   - `AB 00 08 FF 9C … 01` — AI style (`sendStyleAi`)
   - `AB 00 04 FF AD 80 <n>` — number of background images (`sendMultipleWatchBitmapNum`)
   - EA `0D 01` new style / video style, EA `0D 02` transfer state, EA `0D 03` video pixel info
   - EA `08 00 <v>` puzzle flag, EA `0A 01` module face, EA `0F 01` menu background state
   - EA `3D 01..04` DIY numbers / pointer / location / state
6. Device replies are handled by `DialAnalyzer` (dispatch values `AD`, `B0`, `B2`, `A7` in [E2]).

## 3. Market faces and other files

- Download: vendor API `api/v1/dials`, `api/v1/dial/compatible`, `api/v1/dial/download`,
  `auth/dialMarketScreen/*` [E9] — **private API, will not be used** (CLAUDE.md rule).
- Transfer by family:
  - **Generic file transfer** (service `6E400011`): head frame `0xA0…` with whole-file CRC-16/MODBUS,
    blocks `0xA1…` with per-block CRC (`FileTransferOrder`, `FileTransferMgr`, `FileTransfer`) (D).
  - **SiFli**: `com.sifli.watchfacesdk.manager.SFWatchfaceFilePushManager` unzips a `wf.zip`
    (`/zip/wf.zip`) and pushes its files over the SiFli serial transport; log line
    "version=%d,blockLength=%d,blockLeft=%d,result=%d,maxDataLen=%d" shows a block protocol (O strings).
  - **Nordic**: `NordicDialUtil.start` installs the face through Nordic DFU (labels "开始OTA") (D).
  - **Bluetrum**: U (no dedicated face class found; `ZK` image commands exist for barrage/AIGC).
- **File format of market faces: U.** The files are produced by vendor tools and are not in the APK.
  SiFli faces are a zip; inner format U. Bundled `assets/watchFace/*.png` (bg, date_NNN, time_NNN,
  frame_N, preview) are template element images used by the app — **not to be copied**.

## 4. Status for the iOS app (proposed)

- Photo face for the user's watch: possible once the image packet layout is confirmed (Phase 2 capture
  of one photo-face upload). Until then `blocked-protocol` (U fields).
- Market: replaced by user-made / imported / licensed faces (CLAUDE.md).
- Importing third-party face files: only for formats we can verify on the user's watch.

## 5. Unknowns

1. Exact `startSendPic` / `sendImageContent` packet layouts and the ack format.
2. Pixel format (RGB565 assumed, endianness U) and compression (SiFli `ezip` suggests compression on SiFli).
3. Inner format of SiFli `wf.zip` and Nordic DFU face packages.
4. Delete / replace face commands (labels not found in the builders yet — U).
