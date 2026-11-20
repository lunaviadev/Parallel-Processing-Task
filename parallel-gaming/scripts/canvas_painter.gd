class_name CanvasPainter
extends TextureRect

signal stroke_started(pixel_pos: Vector2i, color: Color)
signal painted(pixel_pos: Vector2i, color: Color)

const SIZE := 512

var image: Image
var brush_color := Color(1, 0, 0)
var brush_radius := 26
var strokes := 0
var editable := true
var eraser_color := Color(0, 0, 0)
var radius_scale := 1.0
var intercept: Callable
var hover_px := Vector2i(-100, -100)

var _tex: ImageTexture
var _painting := false
var _paint_color := Color.BLACK
var _last := Vector2i(-1, -1)
var _dirty := false


func _ready() -> void:
	image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(eraser_color)
	_tex = ImageTexture.create_from_image(image)
	texture = _tex
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS


func clear() -> void:
	image.fill(eraser_color)
	_dirty = true


func _to_px(local: Vector2) -> Vector2i:
	return Vector2i(local * Vector2(SIZE, SIZE) / size)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_px = _to_px((event as InputEventMouseMotion).position)
	if not is_visible_in_tree() or not editable:
		_painting = false
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				var p := _to_px(mb.position)
				if intercept.is_valid() and intercept.call(p, mb.button_index):
					return
				_painting = true
				_paint_color = brush_color if mb.button_index == MOUSE_BUTTON_LEFT else eraser_color
				stamp(p, _paint_color, effective_radius())
				painted.emit(p, _paint_color)
				_last = p
				strokes += 1
				stroke_started.emit(p, _paint_color)
			else:
				_painting = false
				_last = Vector2i(-1, -1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			brush_radius = mini(brush_radius + 3, 90)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			brush_radius = maxi(brush_radius - 3, 6)
	elif event is InputEventMouseMotion and _painting:
		var p := _to_px((event as InputEventMouseMotion).position)
		var from := Vector2(_last if _last.x >= 0 else p)
		var dist := from.distance_to(Vector2(p))
		var r := effective_radius()
		var steps := maxi(1, int(dist / (r * 0.35)))
		for i in range(1, steps + 1):
			stamp(Vector2i(from.lerp(Vector2(p), float(i) / steps)), _paint_color, r)
		if dist > 2.0:
			painted.emit(p, _paint_color)
		_last = p


func effective_radius() -> int:
	return int(brush_radius * radius_scale)


func stop_painting() -> void:
	_painting = false
	_last = Vector2i(-1, -1)


func stamp(c: Vector2i, color: Color, r: int) -> void:
	for dy in range(-r, r + 1):
		var y := c.y + dy
		if y < 0 or y >= SIZE:
			continue
		var w := int(sqrt(float(r * r - dy * dy)))
		var x0 := clampi(c.x - w, 0, SIZE)
		var x1 := clampi(c.x + w + 1, 0, SIZE)
		if x1 > x0:
			image.fill_rect(Rect2i(x0, y, x1 - x0, 1), color)
	_dirty = true


func fill_tile(rect: Rect2i, color: Color) -> void:
	image.fill_rect(rect, color)
	_dirty = true


func _process(_dt: float) -> void:
	if _dirty:
		_tex.update(image)
		_dirty = false
