# Red Painter: Parallel Processing + FMOD Mini-Project

A Godot 4.7 game that covers both weekly mini-projects:

- **Parallel processing:** the red (R) channel of an image is summed across all CPU cores with Godot's `WorkerThreadPool`, the Godot equivalent of Unity Jobs and Unreal ParallelFor. Execution time is logged and exported to CSV/JSON.
- **Audio middleware:** FMOD Studio events (music with an adaptive `Redness` parameter, SFX and UI cues) are triggered through `fmod-gdextension` and logged in a Windows build.

The technical write-up is in [COMMENTARY.md](COMMENTARY.md).

## Run it
Open `parallel-gaming/project.godot` in Godot 4.7, then press **F5**.

| Screen | What it does |
|---|---|
| **Play** | Paint the 512×512 canvas until its redness is inside the target band, then hold it there for 1.5 s. Random splashes push you off. You have 60 s. Keys **1–4** change brush, the **mouse wheel** changes brush size. |
| **Benchmark Lab** | Pick a sample or **load any image from disk**. Runs single-thread vs 1/2/4/8/16 pool workers, logs each run, charts the averages and exports **CSV + JSON**. |

Automated runs:

```powershell
godot --headless --path parallel-gaming --script res://tests/test_red_sum.gd
```

```powershell
godot --path parallel-gaming res://scenes/benchmark.tscn -- --autobench
```

Logs and telemetry are written to `%APPDATA%\Godot\app_userdata\Red Painter\` (`telemetry/benchmark_*.csv|json`, `telemetry/audio_log.csv`, `logs/godot.log`).

## FMOD
Follow [docs/FMOD_SETUP.md](docs/FMOD_SETUP.md) to install the plugin, build the banks and export the Windows build.

## Layout
```
parallel-gaming/
  scripts/red_sum.gd        single, parallel and RGB-parallel sums (WorkerThreadPool)
  scripts/telemetry.gd      run log + CSV/JSON export (autoload)
  scripts/audio.gd          FMOD wrapper + audio_log.csv (autoload)
  scripts/benchmark.gd      Benchmark Lab UI + chart
  scripts/game.gd           Red Painter game loop
  scripts/canvas_painter.gd paintable Image canvas
  images/                   sample PNGs (512 to 4096 px)
  tests/test_red_sum.gd     headless correctness test
  banks/Desktop/            FMOD banks (built from fmod-project/)
fmod-project/               FMOD Studio project
media/                      screenshots, GIF/video evidence
```
