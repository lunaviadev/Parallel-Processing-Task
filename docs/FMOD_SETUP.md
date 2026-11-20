# FMOD setup for Red Painter

The game uses FMOD Studio through **fmod-gdextension** `6.1.0-4.5.0` (FMOD runtime 2.03.06), installed in `parallel-gaming/addons/fmod` with the Windows libraries. The plugin is enabled in `project.godot`, and `Fmod/General/banks_path` is `res://banks/Desktop`. `FmodManager.gd` has one local patch: a guard for the missing `FmodServer.notification()` under Godot 4.7.

The built banks are committed, so the game plays as soon as it is cloned. The steps below are only needed to change the sound design.

## Rebuild the FMOD project
1. Install **FMOD Studio 2.03.x** from fmod.com.
2. The source audio is in `fmod-project/source_audio/`: licensed CC0 / CC-BY music and SFX converted to OGG (see `CREDITS.md`). To swap a placeholder, replace the OGG and keep the file name, or edit the name in `build_project.js`.
3. Run the build script. It deletes and recreates every event, parameter, bus, VCA and snapshot, then saves the project and builds the Desktop banks into `parallel-gaming/banks/Desktop/`:

```powershell
& "C:\Program Files\FMOD SoundSystem\FMOD Studio 2.03.15\fmodstudiocl.exe" -script fmod-project/tools/build_project.js fmod-project/RedPainter/RedPainter.fspro
```

`tools/make_template.js` shows how the empty project was made. FMOD's command-line tool can't create a new project, so it strips the bundled Examples project and saves the result as `RedPainter.fspro`.

## What the script creates
| Path | Details |
|---|---|
| `event:/Music/Desktop` | Bossa loop with an ADSR fade in/out, for the desktop and menus |
| `event:/Music/Theme` | Two async looping tracks (Brassy Bubbles / Underwater) crossfaded by `Mode`. `Redness` drives a low-pass from 900 Hz to 22 kHz, `Intensity` drives volume and pitch |
| `event:/SFX/TileMatch`, `BoardClear`, `TimeWarning` | `Combo` (0 to 8) automates pitch |
| `event:/SFX/Brush`, `BlobPop`, `BubbleSpawn` | Multi-instruments with randomiser modulators, panned by `Pan` |
| `event:/SFX/TileLost`, `BlobSpawn`, `Power*`, `BucketFill`, `TileShift` | Panned one-shots |
| `event:/SFX/BoardFail`, `Perfect`, `RoundEnd_Win`, `RoundEnd_Lose` | Stingers |
| `event:/UI/Startup`, `Click`, `Hover`, `WindowOpen`, `WindowClose`, `Notify`, `Error` | OS sounds |
| `bus:/Music` (with low-pass), `bus:/SFX`, `bus:/UI` | Group buses |
| `vca:/Music`, `vca:/SFX` | Driven by the Audio Mixer sliders |
| `snapshot:/Pause` | Music -12 dB, SFX -8 dB, Music low-pass down to 700 Hz |
| `snapshot:/Freeze` | Music pitch -3 semitones, low-pass down to 2.6 kHz |

## Export and validate the Windows build
1. In Godot, go to **Project > Export > Windows Desktop**. The preset includes `banks/*.bank` and writes to `build/RedPainter.exe` (this repo exports to `build/debug/` and `build/release/`). Keep **Export With Debug** ticked so the console wrapper is created.
2. Run `build/debug/RedPainter.console.exe`. The console should print `FMOD ready - 2 banks, 30 events` and `[Audio] ... fmod=yes build=export` for every trigger.
3. Press **F3** in game to see the live FMOD telemetry. The per-session logs (`audio_log_*.csv`, `fmod_perf_*.csv`) are in `%APPDATA%\Godot\app_userdata\Red Painter\telemetry\`.

## Optional: FMOD profiler
The plugin starts FMOD with Live Update enabled. Open the project in FMOD Studio, go to **File > Connect to Game** (`127.0.0.1`), then open **Window > Profiler** to watch voices and CPU in real time.
