extends Control
## RED PAINTER
## Paint so the canvas "redness" (red-channel sum / max possible) lands inside
## the target band and hold it there. Each cleared target scores and sets a
## new one. Random splashes knock you off. 60 seconds on the clock.
##
## Several times a second the whole canvas red sum is recomputed with
## RedSum.sum_parallel (WorkerThreadPool). That number is the score input and
## also drives FMOD's adaptive "Redness" music parameter.

const ROUND_TIME := 60.0
const HOLD_TIME := 1.5
const SAMPLE_INTERVAL := 0.2
const TARGETS := [0.20, 0.35, 0.15, 0.50, 0.30, 0.65, 0.40, 0.80, 0.25, 0.55]

const BRUSHES := [
	{"name": "Crimson", "color": Color8(255, 0, 0), "key": KEY_1},
	{"name": "Magenta", "color": Color8(160, 0, 200), "key": KEY_2},
	{"name": "Teal", "color": Color8(0, 180, 170), "key": KEY_3},
	{"name": "Eraser", "color": Color8(0, 0, 0), "key": KEY_4},
]

var _canvas: CanvasPainter
var _meter: Control
var _time_left := ROUND_TIME
var _hold := 0.0
var _sample_t := 0.0
var _splash_t := 4.0
var _target_idx := 0
var _score := 0
var _cleared := 0
var _redness := 0.0
var _last_result := {}
var _compute_ms_total := 0.0
var _compute_count := 0
var _log_t := 0.0
var _over := false

var _lbl_time: Label
var _lbl_score: Label
var _lbl_target: Label
var _lbl_red: Label
var _lbl_compute: Label
var _lbl_hold: Label
var _brush_btns: Array[Button] = []
var _overlay: PanelContainer
var _overlay_text: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.background(self)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.margin(self, 32).add_child(root)

	var canvas_frame := UI.panel()
	canvas_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.add_child(canvas_frame)
	_canvas = CanvasPainter.new()
	_canvas.stroke_started.connect(func(p: Vector2i) -> void: Audio.play_one_shot(Audio.EV_BRUSH, Vector2(p)))
	canvas_frame.add_child(_canvas)

	var side_panel := UI.panel()
	side_panel.custom_minimum_size.x = 380
	root.add_child(side_panel)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side_panel.add_child(side)
	side.add_child(UI.label("RED PAINTER", 32, UI.RED))
	_lbl_time = UI.label("", 22)
	_lbl_score = UI.label("", 22)
	side.add_child(_lbl_time)
	side.add_child(_lbl_score)
	_lbl_target = UI.label("", 18, Color(1, 0.8, 0.4))
	side.add_child(_lbl_target)
	_meter = Control.new()
	_meter.custom_minimum_size = Vector2(340, 46)
	_meter.draw.connect(_draw_meter)
	side.add_child(_meter)
	_lbl_red = UI.label("", 16)
	_lbl_hold = UI.label("", 16, Color(0.5, 0.9, 0.6))
	side.add_child(_lbl_red)
	side.add_child(_lbl_hold)
	_lbl_compute = UI.label("", 13, Color(0.65, 0.65, 0.7))
	_lbl_compute.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_lbl_compute)

	side.add_child(UI.label("Brushes (keys 1-4, wheel = size)", 14))
	var grid := GridContainer.new()
	grid.columns = 2
	side.add_child(grid)
	for i in BRUSHES.size():
		var b := BRUSHES[i] as Dictionary
		var c: Color = b.color
		var btn := UI.button("%d  %s  (R=%d)" % [i + 1, b.name, c.r8], _select_brush.bind(i), 170)
		btn.toggle_mode = true
		btn.add_theme_color_override("font_color", c.lightened(0.35) if b.name != "Eraser" else Color(0.8, 0.8, 0.8))
		grid.add_child(btn)
		_brush_btns.append(btn)
	side.add_child(UI.button("Menu", _to_menu))

	var overlay_center := CenterContainer.new()
	overlay_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_center)
	_overlay = UI.panel()
	_overlay.custom_minimum_size = Vector2(440, 260)
	var ov := VBoxContainer.new()
	ov.alignment = BoxContainer.ALIGNMENT_CENTER
	ov.add_theme_constant_override("separation", 12)
	_overlay.add_child(ov)
	_overlay_text = UI.label("", 22)
	_overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(_overlay_text)
	ov.add_child(UI.button("Play again", func() -> void: get_tree().reload_current_scene()))
	ov.add_child(UI.button("Menu", _to_menu))
	_overlay.visible = false
	overlay_center.add_child(_overlay)

	_select_brush(0)
	Audio.start_music()
	print("[Game] round started: %.0fs, sampling red sum every %.2fs on %d threads" % [
		ROUND_TIME, SAMPLE_INTERVAL, OS.get_processor_count()])
	_sample()


func _select_brush(i: int) -> void:
	_canvas.brush_color = BRUSHES[i].color
	for j in _brush_btns.size():
		_brush_btns[j].button_pressed = j == i


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		for i in BRUSHES.size():
			if k.keycode == BRUSHES[i].key:
				_select_brush(i)


func _target() -> float:
	return TARGETS[_target_idx % TARGETS.size()]


func _tolerance() -> float:
	return maxf(0.05 - 0.004 * _cleared, 0.02)


func _process(dt: float) -> void:
	if _over:
		return
	_time_left -= dt
	_sample_t -= dt
	_splash_t -= dt
	_log_t += dt
	if _sample_t <= 0.0:
		_sample_t = SAMPLE_INTERVAL
		_sample()
	if _splash_t <= 0.0:
		_splash_t = maxf(4.5 - 0.3 * _cleared, 2.0)
		_random_splash()

	var in_band := absf(_redness - _target()) <= _tolerance()
	_hold = _hold + dt if in_band else 0.0
	if _hold >= HOLD_TIME:
		_target_cleared()

	if _log_t >= 2.0 and _compute_count > 0:
		_log_t = 0.0
		print("[Game] redness=%.3f target=%.2f +/-%.3f  avg parallel sum %.3f ms over %d samples" % [
			_redness, _target(), _tolerance(), _compute_ms_total / _compute_count, _compute_count])

	if _time_left <= 0.0:
		_game_over()
	_update_hud(in_band)


## The parallel computation: whole-canvas red sum via WorkerThreadPool.
func _sample() -> void:
	var r := RedSum.sum_parallel(_canvas.image)
	_last_result = r
	_redness = float(r.sum) / (255.0 * r.pixels)
	_compute_ms_total += r.ms
	_compute_count += 1
	Audio.set_redness(_redness)


func _random_splash() -> void:
	var col: Color = Color8(0, 180, 170) if randf() < 0.6 else Color8(255, 0, 0)
	var p := Vector2i(randi_range(40, CanvasPainter.SIZE - 40), randi_range(40, CanvasPainter.SIZE - 40))
	_canvas.stamp(p, col, randi_range(30, 60))


func _target_cleared() -> void:
	_cleared += 1
	var bonus := int(_time_left)
	_score += 100 + bonus
	_hold = 0.0
	_target_idx += 1
	Audio.play_one_shot(Audio.EV_WIN)
	print("[Game] target cleared #%d  score=%d" % [_cleared, _score])


func _game_over() -> void:
	_over = true
	_time_left = 0.0
	_canvas.editable = false
	Audio.play_one_shot(Audio.EV_WIN if _cleared >= 3 else Audio.EV_LOSE)
	var avg := _compute_ms_total / maxi(_compute_count, 1)
	_overlay_text.text = "TIME!\nScore %d  -  %d targets\n\n%d parallel red sums, avg %.2f ms" % [
		_score, _cleared, _compute_count, avg]
	_overlay.visible = true
	print("[Game] over: score=%d cleared=%d samples=%d avg_ms=%.3f" % [_score, _cleared, _compute_count, avg])


func _update_hud(in_band: bool) -> void:
	_lbl_time.text = "Time  %.1f s" % maxf(_time_left, 0.0)
	_lbl_score.text = "Score  %d   (targets %d)" % [_score, _cleared]
	_lbl_target.text = "Target redness  %d%%  +/- %.1f%%" % [roundi(_target() * 100), _tolerance() * 100]
	_lbl_red.text = "Canvas redness  %.1f%%" % (_redness * 100)
	_lbl_hold.text = ("HOLD IT!  %.1f / %.1f s" % [_hold, HOLD_TIME]) if in_band else ""
	if not _last_result.is_empty():
		_lbl_compute.text = "Red sum %s over %s px\n%.3f ms on %d threads (%d chunks)" % [
			String.num_int64(_last_result.sum), String.num_int64(_last_result.pixels),
			_last_result.ms, _last_result.threads, _last_result.chunks]
	_meter.queue_redraw()


func _draw_meter() -> void:
	var w := _meter.size.x
	var h := 28.0
	_meter.draw_rect(Rect2(0, 0, w, h), Color(0.2, 0.18, 0.2))
	var t := _target()
	var tol := _tolerance()
	_meter.draw_rect(Rect2(w * (t - tol), 0, w * tol * 2, h), Color(1, 0.8, 0.3, 0.45))
	_meter.draw_rect(Rect2(0, 6, w * _redness, h - 12), UI.RED)
	_meter.draw_line(Vector2(w * _redness, 0), Vector2(w * _redness, h), Color.WHITE, 2.0)
	var font := ThemeDB.fallback_font
	_meter.draw_string(font, Vector2(0, h + 16), "0%", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.6, 0.6))
	_meter.draw_string(font, Vector2(w - 34, h + 16), "100%", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.6, 0.6))


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
