# Components (SwiftUI)

Principles: original design in the spirit of Apple Health / Apple Watch: black (dark) or grouped grey
(light) backgrounds, rounded surface cards, one colour per metric, big light numerals, rings for
daily goals. No Apple icons or artwork: SF Symbols are used only through the system API
(allowed for apps on Apple platforms); no copied illustrations. Tokens: `tokens.json` (light),
`tokens-dark.json` (dark) → `App/Design/Tokens.swift` (`Color` assets resolved per colour scheme).

Layout: leading/trailing only (never left/right), so Arabic RTL mirrors automatically; numbers stay
Western digits unless the locale asks otherwise; charts keep time flowing in the reading direction.
Dynamic Type supported on every text; minimum touch target 44 pt; VoiceOver labels on every control.

| Component | Variants / states | Tokens | A11y | Used on |
|---|---|---|---|---|
| `MetricRing` | 1–3 concentric rings; empty, partial, complete (>100% overlaps) | metric-* colours, motion.ring | value + goal read as one label | S02 |
| `MetricCard` | filled, empty ("No data yet"), stale (last sync time), unsupported | surface, radius.lg, metric colour title | button trait, summary label | S02 |
| `RangePicker` | Day / Week / Month | accent | segmented control | S03–S08, S09 |
| `MetricChart` | line, bar, range (BP), stage bar (sleep); empty | metric colour, text-muted axes | audio graph via Charts | S03–S08, S11 |
| `MeasureButton` | idle, measuring (pulse), result, timeout, unsupported | accent / metric colour | announces result | S04–S06 |
| `SettingToggleRow` | on, off, pending (waiting for watch ack), failed (retry) | text, accent | toggle trait, failure announced | S20–S26 |
| `TimeRangeRow` | start/end pickers, invalid (end ≤ start allowed overnight) | | | S22, S23 |
| `WeekdayChips` | 7 chips, locale's first weekday | accent | each chip a toggle | S21, S22 |
| `DeviceHeaderCard` | connected / connecting / disconnected / Bluetooth off; battery, firmware | surface, success/warning/danger | | S17 |
| `ScanRow` | name, short id, RSSI bars, family badge, connecting | | RSSI read as "strong/medium/weak" | S18 |
| `CapabilityChip` | supported, unsupported, unknown | success / text-muted | | S17 |
| `ProgressRing` | determinate, waiting for ack, failed, done (only after device ack) | accent | progress value | S14 |
| `EmptyState` | icon (SF Symbol), title, body, action | text-muted | | all lists |
| `UnsupportedState` | explains why (device lacks it / iOS limit / protocol not confirmed) | warning | | all feature screens |
| `DestructiveConfirmSheet` | typed confirmation word, cancel default | danger | | S31 |
| `Banner` | info, success, error | | posted to VoiceOver | global |
| `CropView` | square / round mask from device screen shape | | | S13 |
| `FacePreview` | round or rectangular frame from device screen info | border | | S12, S13 |
