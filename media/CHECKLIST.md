# Evidence checklist

Record with ScreenToGif (GIF) or OBS / Win+Alt+R (video). Save the files in this folder.

Already here:
- [x] `benchmark_screenshot.png`: Benchmark Lab chart and run log on a 4096×4096 image
- [x] `game_screenshot.png`: game HUD with live parallel red sum
- [x] `sample_benchmark_headless.csv`: exported telemetry

To record:
- [ ] `benchmark.gif`: Benchmark Lab: load an image from disk, run the benchmark, export. Include the Godot Output panel with the `[RedSum]` lines.
- [ ] `log_output.png`: screenshot of the Output panel / console log plus the CSV opened in Excel
- [ ] `gameplay.gif`: a round of Red Painter (redness meter and compute time updating)
- [ ] `fmod_build.mp4`: **with sound**, `build/RedPainter.console.exe` running outside the editor: music, brush, click, win/lose. Show the console `[Audio] ... fmod=yes build=export` lines and `audio_log.csv`.
- [ ] (optional) `fmod_profiler.png`: FMOD Studio profiler connected to the running game
