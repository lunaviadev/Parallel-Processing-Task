extends Control

enum State { INTRO, PLAYING, CLEARED, FAILED, OVER }

const SAMPLE_INTERVAL := 0.1
const INTRO_TIME := 1.3
const CLEAR_TIME := 1.7
const COMBO_WINDOW := 2.5
const START_LIVES := 3
const SHIFT_PERIOD := 9.0
const TARGET_NAMES := ["OFF", "HALF", "FULL"]
const WATER := Color8(0, 112, 196)
const BLEACH := Color8(0, 222, 210)
const SPILL := Color8(255, 40, 110)
const TARGET_COLORS := [Color8(0, 112, 196), Color8(128, 30, 150), Color8(255, 30, 60)]
const BRUSHES := [
	{"name": "Crimson", "color": Color8(255, 30, 60), "key": KEY_1, "hint": "FULL"},
	{"name": "Rose", "color": Color8(128, 30, 150), "key": KEY_2, "hint": "HALF"},
	{"name": "Water", "color": Color8(0, 112, 196), "key": KEY_3, "hint": "OFF"},
]
const POWERS := {
	"freeze": {"tex": "pw_freeze", "label": "Freeze"},
	"bucket": {"tex": "pw_bucket", "label": "Bucket x2"},
	"mega": {"tex": "pw_mega", "label": "Mega brush"},
	"rinse": {"tex": "pw_rinse", "label": "Rinse"},
	"time": {"tex": "pw_time", "label": "+6 seconds"},
}

var _zen := false
var _state := State.INTRO
var _state_t := 0.0
var _paused := false
var _level := 1
var _grid := 2
var _targets: PackedInt32Array = []
var _matched: PackedByteArray = []
var _scored: PackedByteArray = []
var _tile_red: PackedFloat32Array = []
var _tile_flash: PackedFloat32Array = []
var _shift_t: PackedFloat32Array = []
var _board_time := 20.0
var _time_left := 20.0
var _last_tick := -1
var _score := 0
var _best := 0
var _lives := START_LIVES
var _combo := 0
var _combo_t := 0.0
var _max_combo := 0
var _boards_cleared := 0
var _tiles_matched := 0
var _blobs_popped := 0
var _powers_used := 0
var _perfects := 0
var _lost_this_board := 0
var _sample_t := 0.0
var _redness := 0.0
var _last_result := {}
var _sample_ms: PackedFloat32Array = []
var _log_t := 0.0
var _shake := 0.0
var _flash := 0.0
var _banner := ""
var _banner_sub := ""
var _banner_color := Color.WHITE

var _blobs: Array[Dictionary] = []
var _blob_max := 0
var _blob_speed := 60.0
var _blob_spawn_t := 2.0
var _spill_chance := 0.0
var _bubbles: Array[Dictionary] = []
var _bubble_t := 6.0
var _freeze_t := 0.0
var _mega_t := 0.0
var _bucket := 0
var _particles: Array[Dictionary] = []
var _popups: Array[Dictionary] = []

var _desk: Control
var _window: AeroWindow
var _canvas: CanvasPainter
var _overlay: Control
var _lives_view: Control
var _lbl_level: Label
var _lbl_score: Label
var _lbl_best: Label
var _lbl_combo: Label
var _lbl_time: Label
var _time_bar: ProgressBar
var _red_bar: ProgressBar
var _lbl_brush: Label
var _lbl_power: Label
var _lbl_compute: Label
var _brush_btns: Array[Button] = []
var _brush_idx := 0
var _dialog: AeroWindow
var _fill_normal: StyleBox
var _fill_red: StyleBox


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zen = Aero.game_mode == "zen"
	_best = int(UI.cfg_get("game", "best", 0))
	Aero.wallpaper(self)
	_desk = Aero.desk_area(self)
	Aero.taskbar(self, [{"name": "Zen Painter" if _zen else "Red Painter", "icon": "icon_zen" if _zen else "icon_play", "active": true}])
	_window = AeroWindow.new("Red Painter", "icon_zen" if _zen else "icon_play", Vector2(1010, 598))
	_window.closed.connect(func() -> void: _leave())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_window.content.add_child(row)
	var frame := PanelContainer.new()
	frame.theme_type_variation = "InsetPanel"
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)
	var board := Control.new()
	board.custom_minimum_size = Vector2(CanvasPainter.SIZE, CanvasPainter.SIZE)
	board.clip_contents = true
	frame.add_child(board)
	_canvas = CanvasPainter.new()
	_canvas.eraser_color = WATER
	_canvas.size = Vector2(CanvasPainter.SIZE, CanvasPainter.SIZE)
	_canvas.intercept = _on_canvas_click
	_canvas.stroke_started.connect(_on_stroke)
	_canvas.painted.connect(_on_painted)
	board.add_child(_canvas)
	_overlay = Control.new()
	_overlay.size = _canvas.size
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	board.add_child(_overlay)
	_build_side(row)
	_desk.add_child(_window)
	_window.center_in(Vector2(1280, 720 - Aero.TASKBAR_H))
	_select_brush(0)
	if "--demo" in OS.get_cmdline_user_args() or "--demo-zen" in OS.get_cmdline_user_args():
		var bot: Node = load("res://scripts/demo_bot.gd").new()
		bot.set("game", self)
		add_child(bot)
	Audio.play_music("zen" if _zen else "game")
	print("[Game] session start: mode=%s sampling tile red sums every %.2fs with WorkerThreadPool (%d threads)" % [
		"zen" if _zen else "classic", SAMPLE_INTERVAL, OS.get_processor_count()])
	_new_board()


func _build_side(root: Control) -> void:
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 7)
	side.custom_minimum_size.x = 430
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(side)
	_lbl_level = UI.label("", 17, Aero.NAVY_SOFT, true)
	side.add_child(_lbl_level)
	var score_row := HBoxContainer.new()
	_lbl_score = UI.label("", 40, Aero.NAVY)
	_lbl_score.add_theme_font_override("font", Aero.font_light)
	_lbl_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_row.add_child(_lbl_score)
	_lives_view = Control.new()
	_lives_view.custom_minimum_size = Vector2(100, 34)
	_lives_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lives_view.draw.connect(_draw_lives)
	_lives_view.visible = not _zen
	score_row.add_child(_lives_view)
	side.add_child(score_row)
	var sub_row := HBoxContainer.new()
	_lbl_best = UI.label("", 13, UI.DIM)
	_lbl_best.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_row.add_child(_lbl_best)
	_lbl_combo = UI.label("", 18, UI.GOOD, true)
	sub_row.add_child(_lbl_combo)
	side.add_child(sub_row)
	_time_bar = ProgressBar.new()
	_time_bar.show_percentage = false
	_time_bar.max_value = 1.0
	_time_bar.custom_minimum_size = Vector2(0, 20)
	side.add_child(_time_bar)
	_fill_normal = Aero.box("bar_fill", 8, 0)
	_fill_red = Aero.box("bar_fill_red", 8, 0)
	var meters := HBoxContainer.new()
	_lbl_time = UI.label("", 13, UI.DIM, true)
	_lbl_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meters.add_child(_lbl_time)
	meters.add_child(UI.label("canvas redness ", 12, UI.DIM))
	_red_bar = ProgressBar.new()
	_red_bar.show_percentage = false
	_red_bar.max_value = 1.0
	_red_bar.custom_minimum_size = Vector2(150, 12)
	_red_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_red_bar.add_theme_stylebox_override("fill", _fill_red)
	meters.add_child(_red_bar)
	side.add_child(meters)
	side.add_child(UI.label("Brushes   1-3  -  right-click washes  -  wheel / [ ] size", 12, UI.DIM))
	var brushes := HBoxContainer.new()
	brushes.add_theme_constant_override("separation", 6)
	side.add_child(brushes)
	for i in BRUSHES.size():
		var b := BRUSHES[i] as Dictionary
		var btn := UI.button("%s\n%s" % [b.name, b.hint], _select_brush.bind(i), 136)
		btn.custom_minimum_size.y = 58
		btn.toggle_mode = true
		btn.icon = _swatch(b.color)
		btn.add_theme_font_size_override("font_size", 14)
		brushes.add_child(btn)
		_brush_btns.append(btn)
	_lbl_brush = UI.label("", 12, UI.DIM)
	side.add_child(_lbl_brush)
	_lbl_power = UI.label("", 15, Color(0.1, 0.45, 0.75), true)
	side.add_child(_lbl_power)
	var rules := UI.label("Zen: no clock, no blobs. Paint each tile to its target and enjoy the bubbles." if _zen else "Match every tile: FULL = solid crimson, HALF = rose, OFF = water. Pop blobs and power bubbles with a click.", 13, UI.TEXT)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size.x = 400
	side.add_child(rules)
	var tel := PanelContainer.new()
	tel.theme_type_variation = "InsetPanel"
	_lbl_compute = UI.label("", 12, Color(0.1, 0.45, 0.25))
	_lbl_compute.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tel.add_child(_lbl_compute)
	side.add_child(tel)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(fill)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	btns.add_child(UI.button("Pause  (Esc)", _toggle_pause, 200))
	btns.add_child(UI.button("Desktop", func() -> void: _window.close(), 200))
	side.add_child(btns)


func _swatch(c: Color) -> Texture2D:
	var img := Image.create_empty(22, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 22:
		for x in 22:
			var d := Vector2(x - 10.5, y - 10.5).length()
			if d <= 10.5:
				var col := c.lerp(Color.WHITE, 0.45 * clampf((7.0 - y) / 7.0, 0.0, 1.0))
				if d > 9.3:
					col = c.darkened(0.45)
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _level_config(level: int) -> Dictionary:
	if _zen:
		return {"grid": 2 if level == 1 else (3 if level <= 3 else 4), "time": 1.0, "blobs": 0, "speed": 0.0, "mess": 2 + mini(level, 6), "spill": 0.0, "shift": 0}
	if level == 1:
		return {"grid": 2, "time": 22.0, "blobs": 0, "speed": 0.0, "mess": 3, "spill": 0.0, "shift": 0}
	if level == 2:
		return {"grid": 3, "time": 32.0, "blobs": 1, "speed": 55.0, "mess": 4, "spill": 0.0, "shift": 0}
	if level == 3:
		return {"grid": 3, "time": 30.0, "blobs": 2, "speed": 65.0, "mess": 5, "spill": 0.0, "shift": 0}
	@warning_ignore("integer_division")
	var extra := (level - 4) / 2
	return {"grid": 4, "time": maxf(46.0 - (level - 4) * 2.0, 32.0), "blobs": mini(2 + extra, 5),
			"speed": minf(70.0 + (level - 4) * 8.0, 130.0), "mess": 6 + mini(level - 4, 6),
			"spill": 0.35 if level >= 4 else 0.0, "shift": 0 if level < 5 else (1 if level < 7 else 2)}


func _new_board() -> void:
	var cfg := _level_config(_level)
	_grid = cfg.grid
	_board_time = cfg.time
	_time_left = _board_time
	_blob_max = cfg.blobs
	_blob_speed = cfg.speed
	_spill_chance = cfg.spill
	_blob_spawn_t = 2.5
	_blobs.clear()
	_bubbles.clear()
	_lost_this_board = 0
	_combo = 0
	_combo_t = 0.0
	var tiles := _grid * _grid
	_targets.resize(tiles)
	_matched.resize(tiles)
	_scored.resize(tiles)
	_tile_red.resize(tiles)
	_tile_flash.resize(tiles)
	_shift_t.resize(tiles)
	_canvas.clear()
	var tw := CanvasPainter.SIZE / float(_grid)
	for k in tiles:
		_targets[k] = randi() % 3
		_matched[k] = 0
		_scored[k] = 0
		_tile_flash[k] = 0.0
		_shift_t[k] = -1.0
		var roll := randf()
		if roll < 0.18:
			_canvas.fill_tile(_tile_rect(k), BRUSHES[0].color)
		elif roll < 0.3:
			_canvas.fill_tile(_tile_rect(k), BRUSHES[1].color)
	for i in int(cfg.mess):
		var col: Color = BRUSHES[randi() % 2].color
		_canvas.stamp(Vector2i(randi_range(20, CanvasPainter.SIZE - 20), randi_range(20, CanvasPainter.SIZE - 20)), col, randi_range(int(tw * 0.2), int(tw * 0.45)))
	if not _targets.has(1) and not _targets.has(2):
		_targets[randi() % tiles] = 2
	var order := range(tiles)
	order.shuffle()
	for i in int(cfg.shift):
		_shift_t[order[i]] = SHIFT_PERIOD * (0.6 + 0.3 * i)
	_sample()
	var already := 0
	for k in tiles:
		if _tile_ok(k):
			already += 1
	if already * 2 > tiles:
		for k in tiles:
			if _tile_ok(k) and randf() < 0.7:
				_targets[k] = (_targets[k] + 1 + randi() % 2) % 3
	for k in tiles:
		_matched[k] = 1 if _tile_ok(k) else 0
		_scored[k] = _matched[k]
	_set_state(State.INTRO)
	_banner = "Board %d" % _level
	var bits := PackedStringArray(["%dx%d" % [_grid, _grid]])
	if not _zen:
		bits.append("%d s" % int(_board_time))
	if _blob_max > 0:
		bits.append("%d blob%s" % [_blob_max, "s" if _blob_max > 1 else ""])
	if int(cfg.shift) > 0:
		bits.append("%d shifting" % int(cfg.shift))
	_banner_sub = "   -   ".join(bits)
	_banner_color = Color(0.85, 0.55, 0.05)
	_last_tick = -1
	_window.set_title("%s - Board %d" % ["Zen Painter" if _zen else "Red Painter", _level])
	print("[Game] board %d: grid=%dx%d time=%.0fs blobs=%d shift=%d targets=%s" % [_level, _grid, _grid, _board_time, _blob_max, int(cfg.shift), str(Array(_targets).map(func(t: int) -> String: return TARGET_NAMES[t]))])


@warning_ignore("integer_division")
func _tile_rect(k: int) -> Rect2i:
	var s := CanvasPainter.SIZE
	var tr := k / _grid
	var tc := k % _grid
	var x0 := tc * s / _grid
	var y0 := tr * s / _grid
	return Rect2i(x0, y0, (tc + 1) * s / _grid - x0, (tr + 1) * s / _grid - y0)


func _tile_at(p: Vector2i) -> int:
	for k in _targets.size():
		if _tile_rect(k).has_point(p):
			return k
	return -1


func _tile_ok(k: int) -> bool:
	var r := _tile_red[k]
	match _targets[k]:
		0:
			return r <= 0.08
		1:
			return absf(r - 0.5) <= 0.09
		_:
			return r >= 0.9


func _set_state(s: State) -> void:
	_state = s
	_state_t = 0.0
	_canvas.editable = s == State.PLAYING or s == State.INTRO
	if not _canvas.editable:
		_canvas.stop_painting()


func _select_brush(i: int) -> void:
	_brush_idx = i
	_canvas.brush_color = BRUSHES[i].color
	for j in _brush_btns.size():
		_brush_btns[j].set_pressed_no_signal(j == i)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if not k or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE and _state != State.OVER:
		_toggle_pause()
		return
	for i in BRUSHES.size():
		if k.keycode == BRUSHES[i].key:
			_select_brush(i)
			Audio.play(Audio.EV_CLICK)
	if k.keycode == KEY_BRACKETRIGHT:
		_canvas.brush_radius = mini(_canvas.brush_radius + 4, 90)
	elif k.keycode == KEY_BRACKETLEFT:
		_canvas.brush_radius = maxi(_canvas.brush_radius - 4, 6)


func _toggle_pause() -> void:
	if _state == State.OVER:
		return
	_paused = not _paused
	_canvas.editable = not _paused and (_state == State.PLAYING or _state == State.INTRO)
	_canvas.stop_painting()
	Audio.set_paused_mix(_paused)
	if _paused:
		_dialog = AeroWindow.new("Paused", "icon_help", Vector2(400, 196))
		_dialog.closable = false
		var t := UI.label("Paused", 34, Aero.NAVY)
		t.add_theme_font_override("font", Aero.font_light)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dialog.content.add_child(t)
		var sub := UI.label("FMOD snapshot:/Pause is ducking and filtering the mix", 13, UI.DIM)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dialog.content.add_child(sub)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(UI.button("Resume", _toggle_pause, 150, "GreenButton"))
		row.add_child(UI.button("Desktop", func() -> void: _leave(), 150))
		_dialog.content.add_child(row)
		_desk.add_child(_dialog)
		_dialog.center_in(_desk.size)
		Audio.play(Audio.EV_WINDOW_OPEN)
	elif is_instance_valid(_dialog):
		_dialog.closable = true
		_dialog.close()
	print("[Game] %s" % ("paused" if _paused else "resumed"))


func _process(dt: float) -> void:
	_update_fx(dt)
	if _paused:
		_overlay.queue_redraw()
		return
	_state_t += dt
	_sample_t -= dt
	_log_t += dt
	if _sample_t <= 0.0:
		_sample_t = SAMPLE_INTERVAL
		_sample()
		if _state == State.PLAYING:
			_check_tiles()
	match _state:
		State.INTRO:
			if _state_t >= INTRO_TIME:
				_set_state(State.PLAYING)
				_banner = ""
		State.PLAYING:
			_play_tick(dt)
		State.CLEARED:
			if _state_t >= CLEAR_TIME:
				_level += 1
				_new_board()
		State.FAILED:
			if _state_t >= CLEAR_TIME:
				if _lives <= 0:
					_game_over()
				else:
					_new_board()
	var pressure := 0.0
	if _state == State.PLAYING and not _zen and _freeze_t <= 0.0:
		pressure = clampf(1.0 - _time_left / _board_time, 0.0, 1.0) * 0.65 + minf(_blobs.size() / 3.0, 1.0) * 0.2 + minf(_combo / 6.0, 1.0) * 0.15
	Audio.set_intensity(pressure)
	if _log_t >= 2.0 and not _sample_ms.is_empty():
		_log_t = 0.0
		print("[Game] state=%s board=%d time=%.1f redness=%.3f matched=%d/%d score=%d combo=%d blobs=%d bubbles=%d last_tiles_ms=%.3f avg_ms=%.3f" % [
			State.keys()[_state], _level, _time_left, _redness, _count_matched(), _targets.size(), _score, _combo,
			_blobs.size(), _bubbles.size(), _last_result.get("ms", 0.0), _avg_ms()])
	_update_hud()
	_overlay.queue_redraw()


func _play_tick(dt: float) -> void:
	_combo_t -= dt
	if _combo_t <= 0.0 and _combo > 0:
		_combo = 0
	_update_bubbles(dt)
	if _mega_t > 0.0:
		_mega_t -= dt
		if _mega_t <= 0.0:
			_canvas.radius_scale = 1.0
	if _freeze_t > 0.0:
		_freeze_t -= dt
		if _freeze_t <= 0.0:
			Audio.set_freeze_mix(false)
		return
	if _zen:
		return
	_time_left -= dt
	var sec := ceili(_time_left)
	if sec <= 5 and sec != _last_tick and sec > 0:
		_last_tick = sec
		Audio.play(Audio.EV_TICK, {Audio.PARAM_COMBO: float(5 - sec)})
	_update_blobs(dt)
	_update_shifts(dt)
	if _time_left <= 0.0:
		_time_left = 0.0
		_board_failed()


func _sample() -> void:
	var r := RedSum.sum_tiles(_canvas.image, _grid, _grid)
	_last_result = r
	_redness = float(r.sum) / (255.0 * r.pixels)
	var sums: PackedInt64Array = r.tile_sums
	var px: PackedInt64Array = r.tile_pixels
	for k in sums.size():
		_tile_red[k] = float(sums[k]) / (255.0 * px[k])
	_sample_ms.append(r.ms)
	Audio.set_redness(_redness)


func _check_tiles() -> void:
	for k in _targets.size():
		var ok := _tile_ok(k)
		if ok and _matched[k] == 0:
			_matched[k] = 1
			_on_tile_matched(k)
		elif not ok and _matched[k] == 1:
			_matched[k] = 0
			_combo = 0
			_lost_this_board += 1
			var c := Vector2(_tile_rect(k).get_center())
			Audio.play_panned(Audio.EV_TILE_LOST, c.x / CanvasPainter.SIZE, c)
			_popup("lost", c, Color(1, 0.55, 0.5), 18)
	if _count_matched() == _targets.size():
		_board_cleared()


func _on_tile_matched(k: int) -> void:
	var c := Vector2(_tile_rect(k).get_center())
	_tile_flash[k] = 1.0
	if _scored[k] == 1:
		Audio.play_panned(Audio.EV_TILE_MATCH, c.x / CanvasPainter.SIZE, c, {Audio.PARAM_COMBO: 0.0})
		_popup("fixed", c, Color(0.75, 1, 0.8), 18)
		return
	_scored[k] = 1
	_combo = _combo + 1 if _combo_t > 0.0 else 1
	_combo_t = COMBO_WINDOW
	_max_combo = maxi(_max_combo, _combo)
	_tiles_matched += 1
	var pts := 25 * _level * mini(_combo, 8)
	_score += pts
	Audio.play_panned(Audio.EV_TILE_MATCH, c.x / CanvasPainter.SIZE, c, {Audio.PARAM_COMBO: float(mini(_combo - 1, 8))})
	_popup("+%d%s" % [pts, ("  x%d" % _combo) if _combo > 1 else ""], c, Color(0.8, 1, 0.75), 22 + mini(_combo, 6) * 2)
	_burst(c, TARGET_COLORS[_targets[k]].lightened(0.45), 18)
	_shake = maxf(_shake, 2.0 + _combo)


func _count_matched() -> int:
	var n := 0
	for m in _matched:
		n += m
	return n


func _board_cleared() -> void:
	_boards_cleared += 1
	var bonus := 150 * _level if _zen else int(_time_left) * 10 * _level + 200 * _level
	var perfect := _lost_this_board == 0 and _targets.size() > 4
	if perfect:
		bonus = int(bonus * 1.5)
		_perfects += 1
	_score += bonus
	_flash = 1.0
	_shake = 10.0
	for b in _blobs:
		_burst(b.pos, BLEACH, 14)
	_blobs.clear()
	for k in _targets.size():
		_burst(Vector2(_tile_rect(k).get_center()), Color(1, 1, 1), 10)
	_banner = "PERFECT!" if perfect else "Board clear!"
	_banner_sub = ("+%d" % bonus) if _zen else ("+%d   (time bonus %d s)" % [bonus, int(_time_left)])
	_banner_color = Color(0.15, 0.6, 0.2)
	Audio.play(Audio.EV_BOARD_CLEAR, {Audio.PARAM_COMBO: float(mini(_level, 8))})
	if perfect:
		Audio.play(Audio.EV_PERFECT)
	if _zen:
		UI.cfg_set("game", "zen_boards", int(UI.cfg_get("game", "zen_boards", 0)) + 1)
	print("[Game] board %d cleared: bonus=%d perfect=%s score=%d time_left=%.1f" % [_level, bonus, str(perfect), _score, _time_left])
	_set_state(State.CLEARED)


func _board_failed() -> void:
	_lives -= 1
	_combo = 0
	_shake = 14.0
	_banner = "Out of time" if _lives > 0 else "Last life lost"
	_banner_sub = "%d %s left" % [_lives, "life" if _lives == 1 else "lives"]
	_banner_color = Color(0.85, 0.15, 0.2)
	Audio.play(Audio.EV_BOARD_FAIL)
	print("[Game] board %d failed: lives=%d matched=%d/%d" % [_level, _lives, _count_matched(), _targets.size()])
	_set_state(State.FAILED)


func _game_over() -> void:
	_set_state(State.OVER)
	_banner = ""
	var new_best := _score > _best
	if new_best:
		_best = _score
		UI.cfg_set("game", "best", _best)
	var rank := UI.add_score("classic", {"score": _score, "board": _level, "combo": _max_combo})
	Audio.play(Audio.EV_WIN if new_best else Audio.EV_LOSE)
	Audio.set_intensity(0.0)
	var stats := _session_stats()
	_dialog = AeroWindow.new("Session complete", "icon_scores", Vector2(460, 380))
	_dialog.closable = false
	var head := UI.label("New high score!" if new_best else "Game over", 32, UI.GOLD if new_best else Aero.NAVY)
	head.add_theme_font_override("font", Aero.font_light)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog.content.add_child(head)
	var body := UI.label("Score %s   (best %s%s)\nBoards %d   Tiles %d   Perfects %d\nBlobs popped %d   Powers %d   Best combo x%d\n\n%d parallel tile scans, avg %.3f ms, p95 %.3f ms" % [
		String.num_int64(_score), String.num_int64(_best), (", rank #%d" % (rank + 1)) if rank >= 0 else "",
		_boards_cleared, _tiles_matched, _perfects, _blobs_popped, _powers_used, _max_combo,
		stats.samples, stats.avg_ms, stats.p95_ms], 15, UI.TEXT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog.content.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UI.button("Play again", func() -> void: get_tree().reload_current_scene(), 160, "GreenButton"))
	row.add_child(UI.button("Desktop", func() -> void: _leave(), 160))
	_dialog.content.add_child(row)
	_desk.add_child(_dialog)
	_dialog.center_in(_desk.size)
	var path := Telemetry.export_game_session(stats)
	print("[Game] over: score=%d best=%d boards=%d tiles=%d blobs=%d powers=%d samples=%d avg_ms=%.3f -> %s" % [
		_score, _best, _boards_cleared, _tiles_matched, _blobs_popped, _powers_used, stats.samples, stats.avg_ms, path])


func _leave() -> void:
	if _zen and not _sample_ms.is_empty():
		Telemetry.export_game_session(_session_stats())
	Aero.to_desktop()


func _session_stats() -> Dictionary:
	var sorted := Array(_sample_ms)
	sorted.sort()
	var n := sorted.size()
	return {
		"mode": "zen" if _zen else "classic", "score": _score, "best": _best, "level_reached": _level,
		"boards_cleared": _boards_cleared, "tiles_matched": _tiles_matched, "blobs_popped": _blobs_popped,
		"powers_used": _powers_used, "perfects": _perfects, "max_combo": _max_combo,
		"samples": n, "avg_ms": _avg_ms(), "min_ms": sorted[0] if n > 0 else 0.0,
		"max_ms": sorted[-1] if n > 0 else 0.0, "p95_ms": sorted[int(n * 0.95)] if n > 0 else 0.0,
		"threads": _last_result.get("threads", 0), "chunks": _last_result.get("chunks", 0),
		"canvas_pixels": _last_result.get("pixels", 0), "audio_triggers": Audio.total_triggers,
	}


func _avg_ms() -> float:
	if _sample_ms.is_empty():
		return 0.0
	var t := 0.0
	for v in _sample_ms:
		t += v
	return t / _sample_ms.size()


func _update_shifts(dt: float) -> void:
	for k in _shift_t.size():
		if _shift_t[k] < 0.0:
			continue
		_shift_t[k] -= dt
		if _shift_t[k] <= 0.0:
			_shift_t[k] = SHIFT_PERIOD
			_targets[k] = (_targets[k] + 1 + randi() % 2) % 3
			_scored[k] = 0
			if _matched[k] == 1:
				_lost_this_board -= 1
			var c := Vector2(_tile_rect(k).get_center())
			Audio.play_panned(Audio.EV_TILE_SHIFT, c.x / CanvasPainter.SIZE, c)
			_popup("now " + TARGET_NAMES[_targets[k]], c, Color(1, 0.85, 0.4), 20)
			_tile_flash[k] = 0.6


func _update_blobs(dt: float) -> void:
	if _blob_max <= 0:
		return
	_blob_spawn_t -= dt
	if _blobs.size() < _blob_max and _blob_spawn_t <= 0.0:
		_blob_spawn_t = randf_range(2.5, 4.5)
		_spawn_blob()
	var s := float(CanvasPainter.SIZE)
	for b in _blobs:
		var to: Vector2 = b.goal - b.pos
		if to.length() < 12.0:
			b.goal = Vector2(randf_range(30, s - 30), randf_range(30, s - 30))
		b.vel = b.vel.lerp(to.normalized() * _blob_speed, dt * 2.0)
		b.pos += b.vel * dt
		b.wobble += dt * 6.0
		b.trail_t -= dt
		if b.trail_t <= 0.0:
			b.trail_t = 0.035 if not b.spill else 0.09
			_canvas.stamp(Vector2i(b.pos), SPILL if b.spill else BLEACH, int(b.r * (0.55 if b.spill else 0.75)))


func _spawn_blob() -> void:
	var s := float(CanvasPainter.SIZE)
	var p := Vector2(randf_range(40, s - 40), randf_range(40, s - 40))
	match randi() % 4:
		0: p.x = 16
		1: p.x = s - 16
		2: p.y = 16
		_: p.y = s - 16
	var spill := randf() < _spill_chance
	_blobs.append({"pos": p, "vel": Vector2.ZERO, "goal": Vector2(randf_range(60, s - 60), randf_range(60, s - 60)),
			"r": randf_range(15.0, 20.0), "wobble": randf() * TAU, "trail_t": 0.0, "spill": spill})
	Audio.play_panned(Audio.EV_BLOB_SPAWN, p.x / s, p)
	_popup("spiller!" if spill else "bleach!", p, SPILL.lightened(0.4) if spill else BLEACH.lightened(0.3), 16)


func _update_bubbles(dt: float) -> void:
	if _zen or _level >= 2:
		_bubble_t -= dt
		if _bubble_t <= 0.0 and _bubbles.size() < 2:
			_bubble_t = randf_range(9.0, 13.0) if _zen else randf_range(6.5, 10.5)
			var kinds := ["bucket", "mega"] if _zen else POWERS.keys()
			var kind: String = kinds[randi() % kinds.size()]
			var x := randf_range(50, CanvasPainter.SIZE - 50)
			_bubbles.append({"pos": Vector2(x, CanvasPainter.SIZE + 30), "x0": x, "vy": randf_range(-42, -60), "t": randf() * TAU, "kind": kind, "r": 27.0})
			Audio.play_panned(Audio.EV_BUBBLE_SPAWN, x / CanvasPainter.SIZE, Vector2(x, CanvasPainter.SIZE))
	for i in range(_bubbles.size() - 1, -1, -1):
		var b := _bubbles[i]
		b.t += dt
		b.pos.y += b.vy * dt * (0.3 if _freeze_t > 0.0 else 1.0)
		b.pos.x = b.x0 + sin(b.t * 1.7) * 18.0
		if b.pos.y < -40:
			_bubbles.remove_at(i)


func _on_canvas_click(p: Vector2i, button: int) -> bool:
	if _state != State.PLAYING:
		return false
	if button == MOUSE_BUTTON_LEFT:
		for i in range(_bubbles.size() - 1, -1, -1):
			var bb := _bubbles[i]
			if Vector2(p).distance_to(bb.pos) <= bb.r + 8.0:
				_bubbles.remove_at(i)
				_activate_power(bb.kind, bb.pos)
				return true
		for i in range(_blobs.size() - 1, -1, -1):
			var b := _blobs[i]
			if Vector2(p).distance_to(b.pos) <= b.r + 10.0:
				_pop_blob(i)
				return true
		if _bucket > 0:
			var k := _tile_at(p)
			if k >= 0:
				_bucket -= 1
				var rect := _tile_rect(k)
				_canvas.fill_tile(rect, _canvas.brush_color)
				var c := Vector2(rect.get_center())
				Audio.play_panned(Audio.EV_BUCKET_FILL, c.x / CanvasPainter.SIZE, c)
				_burst(c, _canvas.brush_color.lightened(0.4), 24)
				_shake = maxf(_shake, 4.0)
				return true
	return false


func _pop_blob(i: int) -> void:
	var b := _blobs[i]
	_blobs.remove_at(i)
	_blobs_popped += 1
	var pts := 75 * _level
	_score += pts
	_burst(b.pos, SPILL if b.spill else BLEACH, 26)
	_popup("pop +%d" % pts, b.pos, Color(0.85, 1, 1), 22)
	_shake = maxf(_shake, 5.0)
	_blob_spawn_t = maxf(_blob_spawn_t, 2.0)
	Audio.play_panned(Audio.EV_BLOB_POP, b.pos.x / CanvasPainter.SIZE, b.pos)


func _activate_power(kind: String, at: Vector2) -> void:
	_powers_used += 1
	Audio.play_panned(Audio.EV_POWER[kind], at.x / CanvasPainter.SIZE, at)
	_burst(at, Color(0.85, 0.97, 1), 30)
	_popup(POWERS[kind].label, at, Color(1, 1, 1), 24)
	match kind:
		"freeze":
			_freeze_t = 5.0
			Audio.set_freeze_mix(true)
		"bucket":
			_bucket = 2
		"mega":
			_mega_t = 7.0
			_canvas.radius_scale = 2.0
		"rinse":
			for i in range(_blobs.size() - 1, -1, -1):
				_pop_blob(i)
		"time":
			_time_left = minf(_time_left + 6.0, _board_time + 10.0)
	print("[Game] power %s" % kind)


func _on_stroke(p: Vector2i, color: Color) -> void:
	Audio.play_panned(Audio.EV_BRUSH, float(p.x) / CanvasPainter.SIZE, Vector2(p))
	_burst(Vector2(p), color.lightened(0.3), 6)


func _on_painted(p: Vector2i, color: Color) -> void:
	if _particles.size() < 500 and randf() < 0.6:
		_particles.append({"pos": Vector2(p) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _canvas.effective_radius(),
				"vel": Vector2(randf_range(-40, 40), randf_range(-60, 10)), "life": 0.45, "max": 0.45, "color": color.lightened(0.35), "size": randf_range(1.5, 3.5)})


func _burst(at: Vector2, color: Color, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(60, 260)
		var life := randf_range(0.4, 0.9)
		_particles.append({"pos": at, "vel": Vector2.from_angle(a) * sp, "life": life, "max": life, "color": color, "size": randf_range(2.0, 5.0)})


func _popup(text: String, at: Vector2, color: Color, size: int) -> void:
	_popups.append({"text": text, "pos": at, "life": 1.0, "color": color, "size": size})


func _update_fx(dt: float) -> void:
	for i in range(_particles.size() - 1, -1, -1):
		var p := _particles[i]
		p.life -= dt
		if p.life <= 0.0:
			_particles.remove_at(i)
			continue
		p.vel *= 1.0 - dt * 2.5
		p.vel.y += 220.0 * dt
		p.pos += p.vel * dt
	for i in range(_popups.size() - 1, -1, -1):
		var q := _popups[i]
		q.life -= dt * 0.8
		q.pos.y -= 40.0 * dt
		if q.life <= 0.0:
			_popups.remove_at(i)
	for k in _tile_flash.size():
		_tile_flash[k] = maxf(_tile_flash[k] - dt * 2.0, 0.0)
	_flash = maxf(_flash - dt * 1.6, 0.0)
	_shake = maxf(_shake - dt * 30.0, 0.0)
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake if not _paused else Vector2.ZERO
	_canvas.position = off
	_overlay.position = off


func _update_hud() -> void:
	_lbl_level.text = "%s   Board %d   -   %dx%d   -   %d/%d tiles" % ["Zen" if _zen else "Classic", _level, _grid, _grid, _count_matched(), _targets.size()]
	_lbl_score.text = String.num_int64(_score)
	_lbl_best.text = ("boards painted %d" % _boards_cleared) if _zen else ("best %s" % String.num_int64(maxi(_best, _score)))
	_lbl_combo.text = ("combo x%d" % _combo) if _combo > 1 else ""
	var frac := 1.0 if _zen else clampf(_time_left / _board_time, 0.0, 1.0)
	_time_bar.value = frac
	_time_bar.add_theme_stylebox_override("fill", _fill_red if frac < 0.25 and not _zen else _fill_normal)
	_lbl_time.text = "Zen mode  -  no clock" if _zen else ("Time %.1f s%s" % [_time_left, "   (frozen)" if _freeze_t > 0.0 else ""])
	_red_bar.value = _redness
	_lbl_brush.text = "Brush: %s, radius %d px" % [BRUSHES[_brush_idx].name, _canvas.effective_radius()]
	var pw := PackedStringArray()
	if _freeze_t > 0.0:
		pw.append("Frozen %.1f s" % _freeze_t)
	if _mega_t > 0.0:
		pw.append("Mega brush %.1f s" % _mega_t)
	if _bucket > 0:
		pw.append("Bucket x%d (click a tile)" % _bucket)
	_lbl_power.text = "   ".join(pw)
	if not _last_result.is_empty():
		_lbl_compute.text = "Parallel tile scan: %d tiles, %s px, %d threads x %d chunks\nlast %.3f ms   avg %.3f ms   %d samples" % [
			_targets.size(), String.num_int64(_last_result.pixels), _last_result.threads, _last_result.chunks,
			_last_result.ms, _avg_ms(), _sample_ms.size()]
	_lives_view.queue_redraw()


func _draw_lives() -> void:
	for i in START_LIVES:
		var c := Vector2(16 + i * 32, 17)
		var on := i < _lives
		var col := Color(0.95, 0.2, 0.3) if on else Color(0.7, 0.78, 0.85)
		_lives_view.draw_circle(c + Vector2(-5, -3), 7.5, col)
		_lives_view.draw_circle(c + Vector2(5, -3), 7.5, col)
		_lives_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 0), c + Vector2(12, 0), c + Vector2(0, 13)]), col)
		_lives_view.draw_circle(c + Vector2(-5, -6), 3.0, Color(1, 1, 1, 0.65 if on else 0.4))


func _pill(pos: Vector2, w: float, h: float, bg: Color, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(h / 2.0))
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.anti_aliasing = true
	_overlay.draw_style_box(sb, Rect2(pos, Vector2(w, h)))


func _draw_overlay() -> void:
	var font := Aero.font_semi
	var s := float(CanvasPainter.SIZE)
	_overlay.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s, 0), Vector2(s, s * 0.45), Vector2(0, s * 0.45)]),
			PackedColorArray([Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
	for k in _targets.size():
		var rect := Rect2(_tile_rect(k))
		var t := _targets[k]
		var ok := _matched[k] == 1
		if ok:
			_overlay.draw_rect(rect.grow(-3), Color(0.55, 1.0, 0.55, 0.9), false, 4.0)
			_overlay.draw_rect(rect.grow(-1), Color(1, 1, 1, 0.8), false, 1.0)
		else:
			_overlay.draw_rect(rect.grow(-1), Color(1, 1, 1, 0.45), false, 1.5)
		if _tile_flash[k] > 0.0:
			_overlay.draw_rect(rect, Color(1, 1, 1, _tile_flash[k] * 0.45))
		var shifting := _shift_t[k] >= 0.0
		var blink := shifting and _shift_t[k] < 2.0 and int(_shift_t[k] * 6.0) % 2 == 0
		var bw := 72.0 if shifting else 62.0
		_pill(rect.position + Vector2(6, 6), bw, 22, Color(1, 1, 0.7, 0.95) if blink else Color(1, 1, 1, 0.88), Color(0.4, 0.6, 0.78, 0.9))
		_overlay.draw_circle(rect.position + Vector2(17, 17), 7.0, TARGET_COLORS[t])
		_overlay.draw_circle(rect.position + Vector2(15.5, 15), 2.5, Color(1, 1, 1, 0.7))
		_overlay.draw_string(font, rect.position + Vector2(28, 22), TARGET_NAMES[t], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Aero.NAVY)
		if shifting:
			var ac := rect.position + Vector2(bw - 4, 17)
			_overlay.draw_arc(ac, 5.5, 0.4, TAU - 0.6, 14, Color(0.85, 0.5, 0.05), 2.0)
			_overlay.draw_colored_polygon(PackedVector2Array([ac + Vector2(5, -6), ac + Vector2(8, 0), ac + Vector2(2, -1)]), Color(0.85, 0.5, 0.05))
		var pct := "%d%%" % roundi(_tile_red[k] * 100.0)
		_pill(rect.end - Vector2(52, 28), 46, 21, Color(1, 1, 1, 0.82), Color(0.4, 0.6, 0.78, 0.8))
		_overlay.draw_string(font, rect.end - Vector2(52, 12), pct, HORIZONTAL_ALIGNMENT_CENTER, 46, 12, UI.GOOD if ok else Aero.NAVY)
		if ok:
			var c := rect.position + Vector2(rect.size.x - 20, 18)
			_overlay.draw_circle(c, 10, Color(0.3, 0.75, 0.3, 0.95))
			_overlay.draw_polyline(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(-1, 4), c + Vector2(5, -4)]), Color.WHITE, 2.5)
	for b in _blobs:
		var r: float = b.r + sin(b.wobble) * 1.5
		var base: Color = SPILL if b.spill else BLEACH
		_overlay.draw_circle(b.pos + Vector2(0, 3), r + 2, Color(0, 0.1, 0.2, 0.35))
		_overlay.draw_circle(b.pos, r, base.darkened(0.15))
		_overlay.draw_circle(b.pos + Vector2(0, -r * 0.1), r * 0.85, base.lightened(0.15))
		_overlay.draw_circle(b.pos + Vector2(-r * 0.35, -r * 0.45), r * 0.3, Color(1, 1, 1, 0.55))
		var look := (b.vel as Vector2).normalized() * 3.0
		for e in [-1, 1]:
			var eye: Vector2 = b.pos + Vector2(e * r * 0.38, -r * 0.05)
			_overlay.draw_circle(eye, r * 0.24, Color.WHITE)
			_overlay.draw_circle(eye + look, r * 0.11, Color(0.05, 0.1, 0.15))
			if b.spill:
				_overlay.draw_line(eye + Vector2(-e * r * 0.25, -r * 0.38), eye + Vector2(e * r * 0.2, -r * 0.24), Color(0.3, 0, 0.1), 2.0)
	var bub := Aero.tex("bubble")
	for bb in _bubbles:
		var r2: float = bb.r * (1.0 + 0.05 * sin(bb.t * 5.0))
		var ic := Aero.tex(POWERS[bb.kind].tex)
		_overlay.draw_texture_rect(ic, Rect2(bb.pos - Vector2(r2, r2) * 0.62, Vector2(r2, r2) * 1.24), false)
		_overlay.draw_texture_rect(bub, Rect2(bb.pos - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false)
	for p in _particles:
		var a: float = p.life / p.max
		_overlay.draw_circle(p.pos, p.size * (0.5 + a * 0.5), Color(p.color, a))
	for q in _popups:
		var a: float = clampf(q.life * 1.5, 0.0, 1.0)
		var sz: int = q.size
		var w := font.get_string_size(q.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		_overlay.draw_string_outline(font, q.pos - Vector2(w / 2.0, 0), q.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 6, Color(0.02, 0.15, 0.3, a * 0.85))
		_overlay.draw_string(font, q.pos - Vector2(w / 2.0, 0), q.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(q.color, a))
	if _freeze_t > 0.0:
		_overlay.draw_rect(Rect2(0, 0, s, s), Color(0.75, 0.92, 1.0, 0.16 + 0.05 * sin(_freeze_t * 6.0)))
	if _canvas.editable and _canvas.hover_px.x >= 0 and _canvas.hover_px.x < s and _canvas.hover_px.y >= 0 and _canvas.hover_px.y < s:
		var hc := Vector2(_canvas.hover_px)
		if _bucket > 0:
			var k := _tile_at(_canvas.hover_px)
			if k >= 0:
				_overlay.draw_rect(Rect2(_tile_rect(k)).grow(-6), Color(_canvas.brush_color, 0.35), true)
			_overlay.draw_texture_rect(Aero.tex("pw_bucket"), Rect2(hc - Vector2(14, 14), Vector2(28, 28)), false)
		else:
			var rr := float(_canvas.effective_radius())
			_overlay.draw_arc(hc, rr, 0, TAU, 48, Color(1, 1, 1, 0.85), 1.5)
			_overlay.draw_arc(hc, rr + 1.5, 0, TAU, 48, Color(0.02, 0.2, 0.35, 0.5), 1.0)
	if _flash > 0.0:
		_overlay.draw_rect(Rect2(0, 0, s, s), Color(1, 1, 1, _flash * 0.5))
	if _banner != "":
		var a := 1.0
		if _state == State.INTRO:
			a = clampf((INTRO_TIME - _state_t) * 3.0, 0.0, 1.0)
		var scale := 1.0 + maxf(0.25 - _state_t, 0.0) * 1.5
		var big := int(48 * scale)
		var bf := Aero.font_light
		var w := bf.get_string_size(_banner, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.82 * a)
		sb.set_corner_radius_all(16)
		sb.border_color = Color(0.5, 0.75, 0.9, a)
		sb.set_border_width_all(1)
		sb.shadow_color = Color(0, 0.1, 0.25, 0.3 * a)
		sb.shadow_size = 14
		_overlay.draw_style_box(sb, Rect2(40, s / 2 - 62, s - 80, 112))
		_overlay.draw_string(bf, Vector2((s - w) / 2, s / 2), _banner, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(_banner_color, a))
		var w2 := font.get_string_size(_banner_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_overlay.draw_string(font, Vector2((s - w2) / 2, s / 2 + 32), _banner_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Aero.NAVY, a))
