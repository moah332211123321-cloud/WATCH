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

## 2. Custom (photo) face — from decompiled source (JADX 1.5.6), not yet tried on a watch

Evidence: `com/wakeup/module/device/trans/TransferOrder.java` (startSendPic, assemblyImageContent,
sendImageContent, sendStyle, sendCustomPuzzle, sendMultipleWatchBitmapNum), `NormalMTransfer.java`
(startPush, sendInfo, sendData, getSourceList, getShouldSend), `NormalTransferMgr.java` (ack listener),
`work/analyzer/DialAnalyzer.java` (ack 0xAD), `work/channel/WatchNotify` (routing),
`common/utils/BitmapUtils.java` (getHexPixels, hexString_16_to_8, split), `common/temp/BleUtil.java` (crcTable).

1. `AB 00 04 FF AD 80 n` — number of background images (n = 1 for one photo).
2. Pixels: image scaled to the watch resolution, each pixel RGB565 = `(R>>3)<<11 | (G>>2)<<5 | (B>>3)`,
   written **high byte first** (big-endian). File size = width × height × 2.
   Exception: platform type 9 or 12 (`DeviceLocal.byte6`, from the `AB … 20` reply) uses
   `ParTool.bitmapToPar / bitmapToParv3` (Bluetrum `.par`, native library) — **not supported** by Sawar.
3. Split into 1024-byte packages. For package *i*:
   - info packet, 12 raw bytes (not an AB frame): `AD len_hi len_lo i_hi i_lo crc_hi crc_lo end size[4]`
     — CRC-16/MODBUS of the package, `end` = 1 on the last package, size big-endian.
   - content: the package in 124-byte chunks, each `AE (chunkLen+2) seq_hi seq_lo chunk…`, all chunks
     concatenated and written in **128-byte pieces** (`setSplitNum(128)`). `seq` starts at
     `i × (len / 124)` and increments per chunk (the trailing partial chunk overlaps the next package's
     first number — kept as in the reference app).
4. The watch answers with a raw notification `AD x b2 b3 …`. The reference app takes the next index as
   the **decimal concatenation** of b2 and b3 (`Integer.parseInt("" + b2 + b3)`) and sends that package
   (same index = resend). Non-AB/EA notifications bypass reassembly (`WatchNotify`).
5. After the index passes the last package: style `AB 00 07 FF 9C R G B font location` and
   `EA 00 04 00 08 00 00` (not a puzzle face). **Location 1, 2, 3** are built into the app
   (`AlbumDialActivity.<init>` position list, 1 selected by default). **Font** comes from the server
   (`GalleryStyleBean.getFont`). New-style watches use `EA 00 09 00 0D 01 R G B font location function`
   (`TransferOrder.sendStyleNew`; `function` = `GalleryStyleBean.getBottomFirmwareModuleId`, a data
   widget the watch draws itself) — values unknown without the server; Sawar's style tester tries them.
   High-speed mode `AB … 87 80 01` is sent before the transfer and `… 00` after (`AlbumDialActivity`).
8. **DIY faces** (`DiyDialActivity`, EA `3D 01..04`: number colour/font/function, date and data
   positions, pointer style, state) only run on SiFli watches (`DeviceTransServiceImpl.startPushDiyDial`
   requires capability 123) or HiSilicon (`startHsFile`). Not implemented: the user's watch took the
   generic photo path, so it is most likely neither.
6. Resolution: `DeviceInfoModel.getResolution()` = screen reply `EA … 14 01` (width b6–b7, height b8–b9,
   shape b10, rotate b11) if received, else the `byte18` table in `DeviceInfoModel$Byte18Model`
   (implemented as `ScreenTable`).
7. The watch draws the time itself on top of the picture, so only the background is sent.

## 2b. Compiled face files (live data, animation) — HiSilicon platform

Evidence: `com/compress/utils/DialConvertTool.java`, `ImageConvertTool.java`, `WatchFaceImageUtil.java`,
`com/compress/view/Dial*.java`, `com/compress/nativelib/NativeLib.java`, sample `assets/watchFace/watchFace.xml`,
`common/storage/DeviceDao.isSupportHs`, `module/device/trans/FtpTransferMgr.startPushHsFile`.

- A face is described in XML (`<dial size=… version="3.0" watch_type=…>` with layers of `static_img`,
  `sequence_img` (animation frames), `rotate_img` (hands), `option_img`, `digital_img` (digit images
  bound to watch data via `bind_data`, e.g. 1 = time, 70/80 = date parts, 83 = weekday), `label`,
  `arc_label`, `box_progress`, `arc_progress`, `video`, `click`, `kaleidoscope`).
- `DialConvertTool.writeDataToBin` writes a header + one record per element + an image section
  (`BinHeader`, `SeekInfo` table, image data).
- Images are compressed with **HFBC** (`ImageHeader.compressMode = 4`, `cmpMode "HFBC"/"HFBC_ABYPASS"`)
  by a **native** library (`NativeLib.CompressInJNI`, `libnativelib.so`) — not in Java.
- Used for watches with platform type **11** and the own-file-transfer flag (`isSupportHs`); sent with
  `FtpTransferMgr.startPushHsFile` (types: photo_album, clock_diy_bg, setting, …).
- Status: **not implemented**. Needs (1) the user's platform byte to know if this applies at all,
  (2) a reimplementation of the native HFBC encoder (or proof that the watch accepts uncompressed
  images), (3) the Hs/FTP transfer protocol.

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

## 3b. Market face install dispatch, and the `<id>_2_dial.bin` format (2026-11-12)

**Dispatch (O, `asm2/com.wakeup.module.device.DeviceTransServiceImpl.txt` `startPushDial`):**
`type = DeviceLocalSupports.getType(mac)`; if type ∈ {9, 11, 12} **and** `isSupportFileTrans(mac)` →
`FtpTransferMgr.startPushDial` → `FileTransferMgr.startPushFile(path, "watchface")` (generic file
transfer). **Every other watch → `NordicDialUtil.start` = Nordic Secure DFU** (`DfuServiceInitiator`
`.setZip(file)`, keepBond, PRN 12, MTU 512, buttonless-without-bond enabled). So on a Nordic watch a
market face goes through the **bootloader, the same path as a firmware update**.
User's watch (UrjwanPlus fw 1.02): GATT has FE59 (Nordic DFU); platform byte not received yet
(log header `platform: -`) → it most likely takes the DFU path (I).

**File layout (D, from 4 MIT-labelled samples in github.com/fbiego/watch-face-wearfit; files are
named like vendor market ids, so the artwork is the vendor's — used only to learn the layout):**
- `u32 LE` element count N, then N records of 20 bytes, then image data (first record's offset = 4 + 20·N).
- Record: `type u8, flags u8, u16 ?, x u16, y u16, w u16, h u16, start u32, end u32` (all LE).
- Seen types: `09` static image (record 0 = background 240×280), `0d` pre-rotated hand frames
  (centre 120,140, one record per angle step), `00/01/02/03` digit strips (h = 10 × digit height →
  10 glyphs stacked), `06` other bound images. Several records share one offset (shared glyph strip).
- Image data (O, decoded and checked visually on the user's 1 139 files, `research/tools/dial_bg.py`):
  `[start, end)` is a **RGB565 LE palette** (≤ 256 entries), followed by **w·h one-byte palette
  indices**, uncompressed (next image starts at `end + w·h`). Animated backgrounds are frames stacked
  vertically (h = frames × screen height). 19 files use another background encoding (U).
- Trailer: Chronos appends ASCII `screenConfig` + one byte (`tag.py`), not part of the vendor file.
- Samples are 240×280; the user's watch reports 240×288 (byte-18 table) — size match U.

**DFU package around the .bin: U.** The server sends a zip for `setZip`; the init packet (`.dat`)
may be signed (Secure DFU). Not obtainable without the private market API. **Not implemented**:
writing through the bootloader can brick the watch; needs the CLAUDE.md firmware gate (confirmed
flow + explicit user consent for each attempt). If the init packet must be signed → `blocked-protocol`.

## 4. Status for the iOS app (proposed)

- Photo face: implemented as an explicit **experimental** action (layout from source, untested on a watch).
- Market: replaced by user-made / imported / licensed faces (CLAUDE.md).
- Importing third-party face files: only for formats we can verify on the user's watch.

## 5. Unknowns

1. Behaviour of the user's watch (urjwanplus, fw 1.02) — needs a real try with the Bluetooth log on.
2. SiFli picture path (`SichePictureTransfer`) and the `.par` format for platforms 9/12: not implemented.
3. Inner format of SiFli `wf.zip` and Nordic DFU face packages.
4. Delete / replace face commands (labels not found in the builders yet — U).
5. Photo-face time not drawn (user photo, log 2026-11-10): the picture showed, no time. Command order
   matches the reference (`NormalMTransfer.sendInfo` → `setStyle` → `sendIsPuzzle`, speed on/off
   around it). Every classic `AB … 9C` style was sent with **font 0**; font values only come from the
   server (`DialStyleModel.font`, no local defaults). Hypothesis (I): 0 = no time. Sawar now defaults to
   font 1; the next log must show `9C … 01 01` and whether the time appears.
