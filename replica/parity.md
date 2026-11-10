# Parity report — Sawar vs WearFit Pro (2026-11-10)

**Read this first:** the score below counts features that are *built in code*. It compiles in CI and runs on the user's iPhone, but **nothing has been
tested on a watch yet**. Every built feature is `done-unverified`. Real parity is unknown until Phase 2.

## Scores

- Feature parity (built in code): **71.7 / 100** — 80 features counted, must-haves **33 of 38** built.
- Verified on a real watch: **0**.
- Layout diff: **not run** — no screenshots of the original yet (`replica/screens/` is empty).
- Verdict: **not shippable** (5 must-haves missing, nothing verified on the watch).

Full machine output: `replica/parity-score.md`; per-feature detail: `replica/features.csv`.

## Must-haves not done, and why

| feature | status | why |
|---|---|---|
| Battery percentage | blocked-protocol | battery command not identified in the APK |
| App notifications to watch | blocked-ios | iOS apps cannot read other apps' notifications; the watch may use ANCS itself |
| Incoming call / caller id | blocked-ios | no call access on iOS; ANCS only |
| Capability detection | partial | vendor server list not usable; some bits inferred |
| Sport types | partial | watch sport codes not mapped |

## Behaviour differences (by design)

| flow | original | Sawar | keep / fix |
|---|---|---|---|
| First connect | account + server bind + license | local only, no account | keep |
| Face market | vendor store | own photos / imported images | keep (private API) |
| Notifications | Android listener forwards everything | ANCS via the watch, explained | keep (iOS limit) |
| Unconfirmed features | n/a | explicit "not available yet" with reason | keep (honesty rule) |

## Top five to build next (after Phase 2 captures)

1. Confirm and fix every encoder/decoder against real bytes (packet log screen + HCI log).
2. Battery command and device-info offsets → real capability detection.
3. Photo-face install (startSendPic / sendImageContent) for the user's chip family.
4. Watch-recorded workouts (`B7`) and sleep stages.
5. Weather, contacts, notification switches, language codes.
