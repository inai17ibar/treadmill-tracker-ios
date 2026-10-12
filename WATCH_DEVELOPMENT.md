# Apple Watch prototype

Branch: `feature/apple-watch`. Current App Store submission remains unchanged.

Validation: iPhone + embedded Watch simulator build succeeded, standalone Watch simulator build succeeded, and all 28 Swift tests passed. This Mac currently has no installed watchOS simulator runtime; Watch launch/UI and real sensor checks remain unverified.

## Run on devices

1. Run `xcodegen generate` and open `TreadmillTracker.xcodeproj`.
2. Select the `TreadmillTracker` scheme and install on your paired iPhone.
3. Select `TreadmillWatch` and install on your Apple Watch. Automatic signing uses the existing team; enable HealthKit for the new Watch App ID if Xcode requests it.
4. On iPhone, open Settings → Apple Watch Heart Rate Guide. Set a suitable lower/upper limit and tap “Use this target range on Watch”, which also enables linking. Delivery is asynchronous; confirm the displayed limits on Watch.
5. Wear/unlock Watch, open its app once and authorize HealthKit as requested. Start on iPhone; Watch should launch and start measuring. Confirm heart rate on both screens. Actual measurement requires a physical Watch. Disable linking for phone-only use.
6. Pause/resume, finish/save, and check the iPhone history and heart-rate chart after reconnection.

## Implemented

- SwiftUI watchOS 10+ companion app with existing app icon, Japanese/English UI and permission text.
- Indoor HealthKit workout session, live heart rate, two-minute warmup, 15-second mean, 15-second dwell, 3 bpm hysteresis and 60-second haptic cooldown.
- Stale measurements (>20 seconds) and paused workouts suppress advice. No readings may mean permissions were denied; authorization completion does not imply read access.
- Target limits, haptics and optional HealthKit saving configured on iPhone, cached on Watch, and frozen for each workout.
- Watch saves the HealthKit workout once. Local history includes heart-rate samples; queued file transfers work after reconnect and avoid small-message payload limits. iPhone merges by workout UUID without re-saving to HealthKit.
- Incoming files are copied immediately into a durable iPhone inbox before import. Imported files remain available for replay if the history write fails and are deleted only after a successful atomic history write. Watch history is also an atomic JSON file.
- Reinstall restoration reads compact Watch summary metadata from Apple Health; full heart-rate charts currently require the local Watch/iPhone history. Health data is not sent to a developer server.

## Remaining device validation

- HealthKit signing, heart-rate cadence, wrist-down behavior, denial of permissions, haptics, phone disconnect/reconnect and duplicate-free history/HealthKit saves.
- Test finish failure and storage errors, and repeated delivery of the same record.
- iPhone starts Watch through HealthKit and sends latest start/pause/resume/finish state through WatchConnectivity (15-second heartbeat, stale/out-of-order command rejection). Watch discards its HealthKit workout in linked mode; iPhone owns the saved workout. Heart fragments merge by UUID even after saving.
- This uses paired-device state synchronization, not HealthKit session mirroring. Commands wait for connection when unavailable. Watch offers an emergency end-measurement button; it does not stop the iPhone timer. Recovery after process termination is not yet implemented.
- Apple Watch distance/calories are HealthKit estimates; treadmill speed and incline are not transmitted or controlled.
- The initial target range is a placeholder, not a personalized fat-loss recommendation. Explicit iPhone setup is required before starting.
- Update app support/privacy descriptions and release version/build before submitting a Watch release. No App Store upload has been performed for this branch.
