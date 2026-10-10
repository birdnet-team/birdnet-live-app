# ARU Mode

!!! note "Early implementation"
    ARU Mode saves scheduled deployment checkpoints, records scheduled cycles, runs live inference during active cycles, saves retained detection clips when that recording mode is selected, and shows Android foreground notification controls. iOS background behavior still needs field validation.

ARU (Autonomous Recording Unit) Mode is the fixed-location workflow for scheduled acoustic deployments.

## Current Setup Flow

- **Details and analysis settings**:
    - **Metadata**: Enter a deployment name, ARU/station ID, and observer name.
    - **Location**: Use GPS :app-myLocation:, manual coordinates :app-editLocationAlt:, or skip location :app-locationOff:. The map picker uses :app-mapSheet:. Latitude and longitude are required if using sun-anchored scheduling.
    - **Analysis**: Choose the microphone, inference rate, confidence threshold, and sensitivity.
    - **Recording Format**: Choose between FLAC (compressed lossless) and WAV (uncompressed) formats.
    - **Recording Mode**:
        - *Full*: Records the entire duration of each active cycle.
        - *Detections Only*: Saves short audio clips around detected bird sounds. You can customize the clip context (adding between 0 and 5 seconds of pre- and post-detection audio buffer) and choose the sampling method (*All*, *Top N*, or *Smart* sampling to limit storage use).
        - *Off*: Runs real-time inference during cycles and logs detections, but saves no audio files.
- **Schedule**:
    - **Duration and Repeat**: Select how long each active recording cycle lasts and how frequently it repeats.
    - **Recording Window (Diel Pattern)**: Choose to record 24/7 (*Any time*) or restrict cycles to *Day only*, *Night only*, or specific windows *Around sunrise*, *Around sunset*, or *Around sunrise and sunset*. Sunrise/sunset windows are calculated dynamically based on the deployment's coordinates.
    - **Schedule End**: Choose whether to stop the deployment manually, stop after a fixed number of completed cycles, or stop automatically at a specific date and time.
    - **Battery Management**: Set a low-battery stop threshold (0-50%) to pause deployments and prevent complete battery drain. If configured, you can set a low-battery resume threshold to automatically resume recording cycles when the battery level recovers (e.g., via solar charging).
    - **Test Run**: An optional one-minute test cycle is enabled by default to verify microphone input and inference immediately upon starting, without counting toward the scheduled cycle limit.
    - **Session Grouping**: Configure whether to save each cycle as a separate session (recommended for faster load times and modular viewing) or combine all cycles into a single, multi-segment session.
- **Ready**: Review the schedule, estimated audio storage consumption, and diel constraints, then start the deployment.

The setup controls use the same icons as the other wizards: :app-micRounded:
microphone, :app-speedRounded: inference rate, :app-verifiedRounded: confidence,
:app-hearing: sensitivity, :app-fiberManualRecordRounded: recording mode,
:app-timerOutlined: clip context and cycle duration, :app-filterAltRounded:
detection sampling, and :app-formatListNumberedRounded: the per-species clip
limit. The repeat interval uses :app-repeatRounded:, the low-battery controls use
:app-batteryAlert: and :app-batteryChargingFull:, and test run and
Session grouping use :app-scienceRounded: and :app-libraryBooks:.
Tap the :app-helpOutline: button beside a setup control for its explanation.

Starting a deployment immediately saves a `SessionType.aru` session with ARU schedule metadata. Recording cycles are also checkpointed every 30 seconds, including cycles with no detections. After a crash or power loss, the latest partial deployment appears in Session Library as an ended Session; recording does not restart. Work since its last checkpoint may be lost.

JSON and ZIP exports include ARU deployment metadata. ZIP exports bundle saved per-cycle recording files under `aru_cycles/`.

## Active Deployment Screen

The active ARU screen shows whether the deployment is waiting, recording, or complete. Its layout uses four tabs:
- **Status**: Displays the current deployment state, active schedule timer, and a list of real-time detections.
- **Audio**: Displays a live scrolling spectrogram to verify audio input while keeping detections visible below.
- **Schedule**: Lists the upcoming 10 scheduled cycle times, indicating sunrise/sunset alignments if diel restrictions are active.
- **Summary**: Summarizes elapsed time, total recorded audio duration, and detection statistics.

On Android, active deployments display a foreground notification with Stop and Open actions.

Stopping a deployment opens Session Review. If cycles were grouped into a single session, it opens that combined session; if saved as separate sessions, it opens the latest completed cycle session.

On iOS, treat this early implementation as a foreground workflow until scheduled audio and background behavior have been validated on the platform.

## Still Planned

- iOS background behavior validation.
- Full Session Review playback and spectrogram support for multi-file segmented ARU recordings.
