# Technical Commentary: Red Painter

**Engine:** Godot 4.7.2 (GDScript) · **CPU tested:** AMD Ryzen 7 260 (8 cores / 16 threads) · **Middleware:** FMOD Studio via the `fmod-gdextension` plugin

Red Painter covers both mini-projects in one game. The player paints on a 512×512 canvas to hit a target "redness". The red-channel sum that decides the score is computed in parallel several times a second. FMOD plays the music and sound effects, and the same red value drives an adaptive music parameter.

---

## Part 1: Parallel Processing (≈500 words)

### How multithreading was implemented
The brief names Unity's Job System and Unreal's ParallelFor. Godot's equivalent is the **`WorkerThreadPool`**, a pool with one worker per logical core. Its `add_group_task(callable, elements, tasks_needed)` behaves like `ParallelFor` or `IJobParallelFor`: it calls one function once per element index and spreads those calls across the workers.

`scripts/red_sum.gd` (`RedSum`) implements three paths:

- **`sum_single`**: one tight loop over the RGBA8 byte array, reading every 4th byte (the R byte). This is the baseline.
- **`sum_parallel`**: splits the image's rows into bands (by default 4 per thread, e.g. 64 for 16 threads). Each element of the group task sums one band. All workers read the same byte array, which is never written, so no locking is needed while summing. Each band adds into a local variable and writes its partial total once, into its own slot of a `PackedInt64Array`, guarded by a mutex that is taken only once per band. The main thread waits with `wait_for_group_task_completion` and then adds up the partial totals. This is the same map-reduce pattern a Burst `IJobParallelFor` with a per-batch `NativeArray` would use.
- **`sum_rgb_parallel`**: an optional extension that sums R, G and B in one pass over memory.

Images are loaded from disk with `Image.load_from_file` (a native file dialog in the Benchmark Lab) or from sample PNGs in `res://images/`. Every image is converted to `FORMAT_RGBA8` first, so byte 0 of each pixel is always red. In the game, `RedSum.sum_parallel` runs every 0.2 s over the whole canvas (262,144 pixels). It takes about **1.4 ms**, well inside a 16.6 ms frame.

### Telemetry collected
Each run records its mode, worker count, chunk count, resolution, pixel count, the sum, mean R, and execution time in microseconds (`Time.get_ticks_usec`). The `Telemetry` autoload prints a `[RedSum] …` line per run and exports the session to **CSV and JSON** under `user://telemetry/`. The JSON also records the CPU name and core count. The Benchmark Lab runs single-thread, then 1, 2, 4, 8 and 16 workers, N times each (on a separate `Thread`, so the UI keeps drawing). It reports average, minimum and maximum times and the speed-up, and draws a bar chart. Every parallel result is checked against the single-thread sum ("match"). A headless test (`tests/test_red_sum.gd`) checks the sums against a known total, including uneven chunking and RGB8 input.

Results on a 4096×4096 image (16.7 M pixels, 5 runs, windowed):

| Mode | Avg ms | Speed-up |
|---|---|---|
| single | 372.0 | ×1.00 |
| parallel ×1 | 372.0 | ×1.00 |
| parallel ×2 | 189.3 | ×1.97 |
| parallel ×4 | 110.5 | ×3.37 |
| parallel ×8 | 66.2 | ×5.62 |
| parallel ×16 | ≈43 | ≈×8.7 |

### Tools and APIs
Godot `WorkerThreadPool`, `Thread`, `Mutex`, `Image`/`PackedByteArray`, `Time.get_ticks_usec`, `FileAccess`/`JSON` for export, and `OS.get_processor_count`.

### How the results inform optimisation
Going from 1 to 2 workers almost doubles the speed. Beyond 8 workers the gains flatten: there are only 8 physical cores, so the 16 SMT threads share execution units, and the loop becomes limited by memory bandwidth. Two optimisation rules follow. First, size the pool to the physical cores for this kind of memory-heavy work. Second, chunks need to be big enough to hide the cost of scheduling a task. In headless runs, "parallel ×1" was about 1.5× slower than single-thread, which suggests that handing work to a pool worker has a real cost for small amounts of work. The game therefore samples the canvas only five times a second instead of every frame.

The biggest remaining cost is the GDScript interpreter itself, at about 22 ns per pixel. The telemetry points to the next step: move the inner loop into a C++ GDExtension (Godot's equivalent of Burst), or into a compute shader. The same CSV would then measure the improvement.

---

## Part 2: Audio Middleware, FMOD (≈500 words)

### How FMOD was integrated
FMOD is connected through **fmod-gdextension** (utopia-rise), a GDExtension that exposes the FMOD Studio API to GDScript as the `FmodServer` singleton. The plugin sits in `parallel-gaming/addons/fmod/` along with the FMOD runtime DLLs. The sound design lives in an FMOD Studio project (`fmod-project/RedPainter.fspro`), whose banks are built into `parallel-gaming/banks/Desktop/` (see `docs/FMOD_SETUP.md`).

All game code goes through one autoload, `scripts/audio.gd`. At start-up it checks `Engine.has_singleton("FmodServer")` and loads `Master.strings.bank` and `Master.bank` with `load_bank`, keeping references so the banks stay loaded. It then checks the event paths with `check_event_path`. Gameplay code only calls `Audio.play_one_shot()`, `start_music()` or `set_redness()`. This keeps the middleware behind one interface. If the plugin or banks are missing, the game still runs and the log marks each trigger `fmod=no`.

### Events triggered and logged
| Event | Trigger |
|---|---|
| `event:/Music/Theme` | Starts on the menu and persists. It has a continuous **`Redness`** parameter (0–1) that crossfades from a calm layer to an intense layer. |
| `event:/SFX/Brush` | Each new paint stroke |
| `event:/SFX/RoundEnd_Win` | A target is held for 1.5 s, or the game ends with 3+ targets |
| `event:/SFX/RoundEnd_Lose` | Time runs out with fewer than 3 targets |
| `event:/UI/Click` | Every button press |

The music is adaptive: every parallel red-sum sample calls `set_parameter_by_name("Redness", redness)`, so the soundtrack tracks how red the canvas is. Every trigger is logged to the console and to `user://telemetry/audio_log.csv` with a timestamp, the event path, the action, a **per-event trigger count**, whether FMOD was active, the parameter value, the **brush position** for brush events, and whether it ran in the **editor or the exported build**.

### Validating in a packaged build
The Windows export preset (`export_presets.cfg`) adds `banks/*.bank` to the include filter. Banks are not Godot resources, so without this they would be left out of the `.pck` and FMOD would load nothing. The GDExtension copies the FMOD DLLs next to the executable. Validation steps:

1. Export **Windows Desktop** to `build/RedPainter.exe`, with the console wrapper enabled.
2. Run `RedPainter.console.exe` on its own, outside the editor. The console must show `[Audio] FMOD ready - 2 banks loaded`, and the menu footer shows the same status.
3. Play a round and confirm by ear that the music, brush, click and win/lose events play, and that the music intensifies as the canvas gets redder.
4. Open `%APPDATA%\Godot\app_userdata\Red Painter\telemetry\audio_log.csv` and check that its rows read `build=export`, `fmod=yes`, with the trigger counts rising. This shows the events fired from the packaged build itself, not the editor.

The video in `media/` shows these steps.
