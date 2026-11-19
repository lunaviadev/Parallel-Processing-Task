# FMOD setup for Red Painter

The game code is already wired for FMOD (`parallel-gaming/scripts/audio.gd`). Until these steps are done it runs silently and logs `fmod=no`.

## 1. Install the FMOD plugin for Godot
**Already done:** fmod-gdextension `6.1.0-4.5.0` (FMOD 2.03.06) is installed in `parallel-gaming/addons/fmod` with Windows libraries only, and it's enabled in `project.godot`. It initialises fine under Godot 4.7.2. Two local changes: `FmodManager.gd` has a guard for a missing `FmodServer.notification()`, and the setting `Fmod/General/banks_path` is set to `res://banks/Desktop`. The steps below are only needed to reinstall it or add other platforms.

1. Download the latest release zip from <https://github.com/utopia-rise/fmod-gdextension/releases>. At the time of writing that is `6.1.0-4.5.0`, built for Godot 4.5+ with FMOD **2.03.06**. Godot 4.7 can load GDExtensions built for 4.5.
2. Extract the zip's `addons/fmod` folder to `parallel-gaming/addons/fmod`.
3. Check that `addons/fmod/libs/windows/` contains `fmod.dll` and `fmodstudio.dll`. If it doesn't, install the **FMOD Engine** (same version) from fmod.com and copy those two DLLs from `api/core/lib/x64` and `api/studio/lib/x64`.
4. Open the project in Godot, go to **Project > Project Settings > Plugins** and enable **FMOD**. Restart the editor.

## 2. Install FMOD Studio
Create a free account at <https://www.fmod.com/download> and install **FMOD Studio** in the **same minor version** as the plugin (2.03.x). Banks built with a different version may refuse to load.

## 3. Create the FMOD Studio project
1. **File > New**, then save it as `fmod-project/RedPainter.fspro`, next to the `parallel-gaming` folder.
2. Get some sounds. CC0 packs from kenney.nl (for example *Interface Sounds* and *Music Jingles*) or freesound.org work well. You need:
   - two music loops (calm and intense), a short brush swish, a click, a win jingle and a lose jingle.
3. Create these events. Right-click in the Events browser, choose **New Event > 2D Timeline**, and use **exactly** these folders and names:

   | Folder / Event | Content |
   |---|---|
   | `Music/Theme` | Two audio tracks: calm loop and intense loop, both with **Loop Region** on |
   | `SFX/Brush` | brush swish (add a small pitch randomisation modulator) |
   | `SFX/RoundEnd_Win` | win jingle |
   | `SFX/RoundEnd_Lose` | lose jingle |
   | `UI/Click` | click |

4. Add the adaptive parameter to **Music/Theme**:
   - **Window > Preset Browser > New Parameter**, or `+` next to the timeline tab, then **Add parameter sheet > New parameter**.
   - Name it **`Redness`**, type **Continuous**, range **0 to 1**, scope **Local**.
   - On the calm track, add volume automation that goes from 0 dB at Redness 0 to -inf at Redness 1. On the intense track, do the opposite.
5. Select all events, right-click and choose **Assign to Bank > Master**.
6. **Edit > Preferences > Build**: set *Built banks output directory* to `../parallel-gaming/banks`.
7. **File > Build** (F7). You should now have `parallel-gaming/banks/Desktop/Master.bank` and `Master.strings.bank`.

## 4. Check it in the editor
Press **F5** in Godot. The footer of the main menu should read `FMOD ready - 2 banks loaded`, and the Output panel shows `[Audio] ... fmod=yes`.

## 5. Export the Windows build
1. **Editor > Manage Export Templates > Download and Install** (once).
2. **Project > Export**, select the **Windows Desktop** preset (already configured: it includes `banks/*.bank`, and the output is `build/RedPainter.exe`), then **Export Project**. Keep **Export With Debug** ticked so the console wrapper is created.
3. Run `build/RedPainter.console.exe`. You should hear the music and SFX, and the console lists every `[Audio]` trigger with `build=export`.
4. The log file is `%APPDATA%\Godot\app_userdata\Red Painter\telemetry\audio_log.csv`.

## Optional: FMOD profiler
Enable **Live Update** in the FMOD Studio window, run the game, then use **Window > Profiler** in FMOD Studio and connect to `127.0.0.1` to watch CPU and voice counts in real time. This covers the brief's optional "middleware profiling" idea; screenshot it.
