# Evidence

All footage was captured from the **exported Windows build** (`build/debug/RedPainter.console.exe`) running outside the editor. Frames come from inside the game, and the audio is FMOD's real output, routed to a virtual cable and recorded with ffmpeg. The gameplay is played by the built-in autoplay demo (`--demo`), so the input is scripted.

| File | Shows |
|---|---|
| `fmod_build.mp4` | **With sound, 95 s.** Boot chime, desktop music, then Classic boards 1 to 9: adaptive music, every SFX, power-ups, the Pause snapshot (~20 s) and the F3 overlay reading `build: export` |
| `zen_mode.mp4` | **With sound.** Zen mode with the underwater track (`Mode` = 1) and Mega brush |
| `benchmark.mp4` | Benchmark Lab: a 4096² image loaded from disk, single vs 1 to 20 workers, then export |
| `gameplay.gif`, `zen.gif`, `benchmark.gif` | Silent loops of the above |
| `boot_screen.png`, `desktop.png` | Boot screen and the Aero desktop with the FMOD notification |
| `game_screenshot.png`, `zen_screenshot.png` | HUD with the live parallel tile scan |
| `fmod_telemetry_hud.png` | F3 overlay: driver, build, music params, snapshots, FMOD CPU/memory, trigger counts |
| `pause_snapshot.png` | Pause dialog while `snapshot:/Pause` is active |
| `benchmark_screenshot.png` | Chart, per-run `match` log and export paths |
| `benchmark_telemetry.csv/json` | Exported benchmark runs |
| `audio_log.csv` | Every FMOD trigger from the recorded build run (343 rows, `fmod=yes`, `build=export`) |
| `fmod_perf.csv` | FMOD CPU (dsp/stream/update/studio) and memory, once a second, for the same run |
| `fmod_build_console.log` | Console output of that run |
| `thumb_*.png` | Play-button thumbnails that link to the videos from the README and commentary |
