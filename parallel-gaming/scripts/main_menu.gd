extends Control

var _desk: Control
var _bar: Control
var _windows := {}
var _mixer_bars := {}
var _mixer_trig: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Aero.wallpaper(self)
	_desk = Aero.desk_area(self)
	_build_icons()
	_rebuild_taskbar()
	Audio.play_music("desktop")
	Audio.set_redness(0.0)
	Audio.set_intensity(0.0)
	var args := OS.get_cmdline_user_args()
	if "--autobench" in args:
		get_tree().change_scene_to_file.call_deferred(Aero.SCENE_BENCH)
		return
	if Aero.pending_app != "":
		var id := Aero.pending_app
		Aero.pending_app = ""
		open_app.call_deferred(id)
	else:
		open_app.call_deferred("welcome")
	_toast.call_deferred("FMOD Studio", Audio.status)
	if "--demo" in args or "--demo-zen" in args:
		var mode := "zen" if "--demo-zen" in args else "classic"
		get_tree().create_timer(3.5).timeout.connect(func() -> void: Aero.launch(mode))


func _build_icons() -> void:
	var grid := VFlowContainer.new()
	grid.position = Vector2(14, 12)
	grid.size = Vector2(240, 650)
	grid.add_theme_constant_override("v_separation", 0)
	grid.add_theme_constant_override("h_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desk.add_child(grid)
	for app in Aero.APPS:
		var id: String = app.id
		grid.add_child(Aero.icon_button(app, func() -> void: Aero.launch(id)))


func _rebuild_taskbar() -> void:
	if is_instance_valid(_bar):
		_bar.queue_free()
	var tasks := []
	for id: String in _windows:
		var w: AeroWindow = _windows[id]
		if is_instance_valid(w):
			tasks.append({"name": w.title.get_slice(" - ", 0), "icon": w.icon_name, "active": true,
					"callback": func() -> void: w.move_to_front()})
	_bar = Aero.taskbar(self, tasks)


func open_app(id: String) -> void:
	if _windows.has(id) and is_instance_valid(_windows[id]):
		(_windows[id] as AeroWindow).move_to_front()
		return
	var w: AeroWindow
	match id:
		"welcome":
			w = _welcome()
		"help":
			w = _help()
		"mixer":
			w = _mixer()
		"scores":
			w = _scores()
		"system":
			w = _system()
		_:
			return
	Audio.play(Audio.EV_WINDOW_OPEN)
	_desk.add_child(w)
	var n := _windows.size()
	w.center_in(_desk.size, Vector2(60 + n * 26, -10 + n * 22) if id != "welcome" else Vector2(40, -10))
	_windows[id] = w
	w.closed.connect(func() -> void:
		_windows.erase(id)
		_rebuild_taskbar.call_deferred())
	_rebuild_taskbar()


func _welcome() -> AeroWindow:
	var w := AeroWindow.new("Welcome - Red Painter", "icon_play", Vector2(560, 384))
	var c := w.content
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(UI.icon_rect("icon_play", 84))
	var tv := VBoxContainer.new()
	var t := UI.label("Red Painter", 46, Aero.NAVY)
	t.add_theme_font_override("font", Aero.font_light)
	tv.add_child(t)
	tv.add_child(UI.label("Paint every tile to its target redness before the bleach blobs wash it away.", 14, UI.DIM))
	tv.get_child(1).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.get_child(1).custom_minimum_size.x = 380
	head.add_child(tv)
	c.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var classic := UI.button("Play Classic", func() -> void: Aero.launch("classic"), 230, "GreenButton")
	classic.custom_minimum_size.y = 54
	classic.icon = Aero._scaled(Aero.tex("icon_play"), 30)
	classic.add_theme_font_size_override("font_size", 19)
	var zen := UI.button("Zen Mode", func() -> void: Aero.launch("zen"), 230)
	zen.custom_minimum_size.y = 54
	zen.icon = Aero._scaled(Aero.tex("icon_zen"), 30)
	zen.add_theme_font_size_override("font_size", 19)
	row.add_child(classic)
	row.add_child(zen)
	c.add_child(row)
	var stats := PanelContainer.new()
	stats.theme_type_variation = "InsetPanel"
	var sv := VBoxContainer.new()
	stats.add_child(sv)
	sv.add_child(UI.label("Best classic score   %s" % String.num_int64(int(UI.cfg_get("game", "best", 0))), 16, Aero.NAVY, true))
	sv.add_child(UI.label("Zen boards painted   %d" % int(UI.cfg_get("game", "zen_boards", 0)), 15, UI.DIM))
	sv.add_child(UI.label("Tip: pop the floating bubbles for power-ups. Double-click the desktop icons to explore.", 13, UI.DIM))
	sv.get_child(2).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(stats)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_child(UI.button("How to play", func() -> void: open_app("help"), 150))
	foot.add_child(UI.button("Benchmark Lab", func() -> void: Aero.launch("bench"), 150))
	c.add_child(foot)
	return w


func _help() -> AeroWindow:
	var w := AeroWindow.new("Help - How to play", "icon_help", Vector2(600, 540))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	w.content.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var section := func(title: String) -> void:
		var l := UI.label(title, 18, Aero.NAVY, true)
		v.add_child(l)
	var row := func(icon: String, text: String) -> void:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		if icon != "":
			h.add_child(UI.icon_rect(icon, 34))
		var l := UI.label(text, 14, UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		v.add_child(h)
	section.call("Paint the tiles")
	row.call("icon_play", "Every tile shows a target. FULL needs 90%+ red, HALF needs 41-59%, OFF needs 8% or less.")
	row.call("", "Crimson (1) fills red, Rose (2) is exactly half red, Water (3 or right-click) washes paint away. Mouse wheel or [ ] changes brush size.")
	row.call("", "Quick matches chain into combos. Clear a board without losing a tile for a PERFECT bonus.")
	section.call("Power bubbles")
	row.call("pw_freeze", "Freeze: stops the clock, blobs and shifting tiles for 5 seconds.")
	row.call("pw_bucket", "Bucket: your next two clicks fill a whole tile with the current brush.")
	row.call("pw_mega", "Mega brush: double brush size for 7 seconds.")
	row.call("pw_rinse", "Rinse: pops every blob on the board.")
	row.call("pw_time", "Time: +6 seconds.")
	section.call("Hazards")
	row.call("", "Teal bleach blobs smear water over your paint. Pink spiller blobs (board 4+) drip red where you don't want it. Click blobs to pop them.")
	row.call("", "Shifting tiles (board 5+) change their target every few seconds. Watch for the blinking arrow.")
	section.call("Modes")
	row.call("icon_zen", "Zen mode has no timer, lives or blobs. Just paint, with underwater music.")
	row.call("icon_bench", "The canvas is scanned on every CPU core ten times a second with WorkerThreadPool. Benchmark Lab shows the speed-up.")
	row.call("icon_mixer", "Esc pauses (FMOD Pause snapshot). F3 shows live FMOD telemetry.")
	return w


func _mixer() -> AeroWindow:
	var w := AeroWindow.new("Audio Mixer - FMOD Studio", "icon_mixer", Vector2(480, 430))
	var c := w.content
	c.add_child(UI.label(Audio.status, 13, UI.DIM))
	c.add_child(UI.label("Output: %s" % (Audio.driver_name if Audio.driver_name != "" else "default"), 13, UI.DIM))
	for row in [["Music", "music", Audio.VCA_MUSIC, 0.8], ["Sound effects", "sfx", Audio.VCA_SFX, 0.9]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var l := UI.label(row[0], 16, Aero.NAVY, true)
		l.custom_minimum_size.x = 130
		h.add_child(l)
		var key: String = row[1]
		var vca: String = row[2]
		var s := UI.slider(float(UI.cfg_get("audio", key, row[3])), func(v: float) -> void:
			Audio.set_vca_volume(vca, v)
			UI.cfg_set("audio", key, v))
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.drag_ended.connect(func(_c: bool) -> void: Audio.play(Audio.EV_TILE_MATCH, {Audio.PARAM_COMBO: 3.0}))
		h.add_child(s)
		c.add_child(h)
	c.add_child(HSeparator.new())
	c.add_child(UI.label("Live music parameters", 15, Aero.NAVY, true))
	for p in [Audio.PARAM_REDNESS, Audio.PARAM_INTENSITY, Audio.PARAM_MODE]:
		var h := HBoxContainer.new()
		var l := UI.label(p, 14)
		l.custom_minimum_size.x = 100
		h.add_child(l)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bar)
		_mixer_bars[p] = bar
		c.add_child(h)
	_mixer_trig = UI.label("", 13, UI.DIM)
	c.add_child(_mixer_trig)
	var tests := HBoxContainer.new()
	tests.add_child(UI.button("Test chime", func() -> void: Audio.play(Audio.EV_TILE_MATCH, {Audio.PARAM_COMBO: randf() * 8.0}), 130))
	tests.add_child(UI.button("Test pop", func() -> void: Audio.play(Audio.EV_BLOB_POP, {Audio.PARAM_PAN: randf_range(-1, 1)}), 130))
	tests.add_child(UI.button("Jingle", func() -> void: Audio.play(Audio.EV_BOARD_CLEAR, {Audio.PARAM_COMBO: 2.0}), 120))
	c.add_child(tests)
	return w


func _scores() -> AeroWindow:
	var w := AeroWindow.new("High Scores", "icon_scores", Vector2(440, 440))
	var c := w.content
	c.add_child(UI.label("Classic", 20, Aero.NAVY, true))
	var list: Array = UI.cfg_get("scores", "classic", [])
	var p := PanelContainer.new()
	p.theme_type_variation = "InsetPanel"
	var v := VBoxContainer.new()
	p.add_child(v)
	if list.is_empty():
		v.add_child(UI.label("No runs yet. Go paint something!", 14, UI.DIM))
	for i in list.size():
		var e: Dictionary = list[i]
		var h := HBoxContainer.new()
		var rank := UI.label("%d." % (i + 1), 15, UI.GOLD if i == 0 else UI.DIM, true)
		rank.custom_minimum_size.x = 30
		h.add_child(rank)
		var sc := UI.label(String.num_int64(int(e.get("score", 0))), 16, Aero.NAVY, true)
		sc.custom_minimum_size.x = 110
		h.add_child(sc)
		h.add_child(UI.label("board %d   combo x%d   %s" % [int(e.get("board", 1)), int(e.get("combo", 0)), str(e.get("date", ""))], 13, UI.DIM))
		v.add_child(h)
	c.add_child(p)
	c.add_child(UI.label("Zen", 20, Aero.NAVY, true))
	c.add_child(UI.label("%d boards painted in total" % int(UI.cfg_get("game", "zen_boards", 0)), 15, UI.TEXT))
	return w


func _system() -> AeroWindow:
	var w := AeroWindow.new("System Info", "orb", Vector2(500, 400))
	var c := w.content
	var info := PanelContainer.new()
	info.theme_type_variation = "InsetPanel"
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	info.add_child(g)
	for pair in [
		["Processor", OS.get_processor_name()],
		["Logical cores", str(OS.get_processor_count())],
		["Worker pool", "%d threads" % Telemetry.pool_threads()],
		["Engine", "Godot " + Engine.get_version_info().string],
		["Audio middleware", "FMOD Studio (fmod-gdextension)"],
		["FMOD status", Audio.status],
		["Output device", Audio.driver_name],
		["Build", "editor" if OS.has_feature("editor") else "exported"],
	]:
		g.add_child(UI.label(pair[0], 14, UI.DIM, true))
		var val := UI.label(str(pair[1]), 14)
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		val.custom_minimum_size.x = 280
		g.add_child(val)
	c.add_child(info)
	var result := UI.label("", 14, UI.GOOD, true)
	var run := UI.button("Run a quick parallel scan", func() -> void:
		var img := Image.create_empty(2048, 2048, false, Image.FORMAT_RGBA8)
		img.fill(Color8(200, 40, 60))
		var s := RedSum.sum_single(img)
		var p := RedSum.sum_parallel(img)
		result.text = "2048x2048: single %.1f ms, %d threads %.1f ms  (x%.1f faster)" % [s.ms, p.threads, p.ms, s.ms / maxf(p.ms, 0.001)]
		Audio.play(Audio.EV_NOTIFY), 260, "GreenButton")
	c.add_child(run)
	c.add_child(result)
	return w


func _toast(title: String, body: String) -> void:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(300, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(UI.icon_rect("icon_mixer" if Audio.available else "icon_power", 36))
	var v := VBoxContainer.new()
	v.add_child(UI.label(title, 15, Aero.NAVY, true))
	var b := UI.label(body, 12, UI.DIM)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = 230
	v.add_child(b)
	h.add_child(v)
	p.add_child(h)
	_desk.add_child(p)
	await get_tree().process_frame
	p.position = Vector2(_desk.size.x - p.size.x - 14, _desk.size.y + 10)
	Audio.play(Audio.EV_NOTIFY)
	var tw := p.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "position:y", _desk.size.y - p.size.y - 12, 0.4)
	tw.tween_interval(4.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _process(_dt: float) -> void:
	if _windows.has("mixer") and is_instance_valid(_windows["mixer"]):
		for k: String in _mixer_bars:
			(_mixer_bars[k] as ProgressBar).value = Audio.music_params.get(k, 0.0)
		_mixer_trig.text = "FMOD triggers this session: %d   (music: %s)" % [Audio.total_triggers, Audio.music_kind]
