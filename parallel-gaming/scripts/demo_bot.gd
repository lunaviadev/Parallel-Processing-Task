extends Node

const SPEED := 1500.0

var game: Control
var _canvas: CanvasPainter
var _path: Array[Dictionary] = []
var _cursor := Vector2(256, 256)
var _held := false
var _think_t := 0.5
var _paused_once := false
var _pause_t := 0.0
var _age := 0.0


func _ready() -> void:
	_canvas = game._canvas
	print("[Demo] autoplay bot active (input is injected into CanvasPainter)")


func _process(dt: float) -> void:
	_age += dt
	var hud_on := (_age > 3.0 and _age < 11.0) or (_age > 44.0 and _age < 52.0)
	if Audio._hud_layer.visible != hud_on:
		Audio._hud_layer.visible = hud_on
	if _pause_t > 0.0:
		_pause_t -= dt
		if _pause_t <= 0.0:
			game._toggle_pause()
		return
	if game._paused:
		return
	if game._state != game.State.PLAYING:
		if _held:
			_send_button(false)
		_path.clear()
		_think_t = 0.4
		return
	if not _paused_once and game._level == 2 and game._state_t > 2.5:
		_paused_once = true
		if _held:
			_send_button(false)
		_path.clear()
		game._toggle_pause()
		_pause_t = 2.5
		return
	if _path.is_empty():
		_think_t -= dt
		if _think_t <= 0.0:
			_plan()
		return
	var step := SPEED * dt
	while step > 0.0 and not _path.is_empty():
		var wp := _path[0]
		var to: Vector2 = wp.pos - _cursor
		var d := to.length()
		if d <= step:
			_cursor = wp.pos
			step -= d
			_send_motion()
			if wp.has("brush"):
				game._select_brush(wp.brush)
			if wp.has("down"):
				_send_button(wp.down)
			_path.pop_front()
		else:
			_cursor += to / d * step
			step = 0.0
			_send_motion()


func _plan() -> void:
	_think_t = randf_range(0.08, 0.25)
	for bb in game._bubbles:
		if bb.pos.y > 40 and bb.pos.y < 480 and randf() < 0.8:
			var at: Vector2 = bb.pos + Vector2(0, bb.vy * 0.15)
			_path.append({"pos": at, "down": true})
			_path.append({"pos": at + Vector2(1, 0), "down": false})
			return
	for b in game._blobs:
		if randf() < 0.75:
			_path.append({"pos": b.pos + b.vel * 0.18, "down": true})
			_path.append({"pos": b.pos + b.vel * 0.18 + Vector2(1, 0), "down": false})
			return
	var todo: Array[int] = []
	for k in game._targets.size():
		if game._matched[k] == 0:
			todo.append(k)
	if todo.is_empty():
		return
	var k: int = todo[randi() % mini(todo.size(), 2)]
	var rect := Rect2(game._tile_rect(k))
	var t: int = game._targets[k]
	var brush: int = [2, 1, 0][t]
	var r := clampi(int(rect.size.x / 5.0), 12, 40)
	_canvas.brush_radius = r
	var m := float(r) * 0.9
	var span := rect.size.y - 2.0 * m
	var rows_n := maxi(2, ceili(span / (r * 1.15)) + 1)
	var left := true
	for i in rows_n:
		var y := rect.position.y + m + span * i / float(rows_n - 1)
		var xa := rect.position.x + m
		var xb := rect.end.x - m
		var a := Vector2(xa if left else xb, y)
		var b := Vector2(xb if left else xa, y)
		if i == 0:
			_path.append({"pos": a, "brush": brush, "down": true})
		else:
			_path.append({"pos": a})
		_path.append({"pos": b})
		left = not left
	_path.append({"pos": _path[-1].pos, "down": false})


func _send_motion() -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _cursor
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if _held else 0
	_canvas._gui_input(ev)


func _send_button(down: bool) -> void:
	_held = down
	var ev := InputEventMouseButton.new()
	ev.position = _cursor
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	_canvas._gui_input(ev)
