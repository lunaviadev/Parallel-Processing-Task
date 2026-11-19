class_name CanvasPainter
extends TextureRect
## A paintable RGBA8 Image shown as a texture. The game reads `image` to
## compute the red-channel sum in parallel.

signal stroke_started(pixel_pos: Vector2i)

const SIZE := 512

var image: Image
var brush_color := Color(1, 0, 0)
var brush_radius := 22
var strokes := 0

var _tex: ImageTexture
var _painting := false
var _last := Vector2i(-1, -1)
var _dirty := false


func _ready() -> void:
	image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	_tex = ImageTexture.create_from_image(image)
	texture = _tex
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS


func clear() -> void:
	image.fill(Color.BLACK)
	_dirty = true


func _to_px(local: Vector2) -> Vector2i:
	return Vector2i(local * Vector2(SIZE, SIZE) / size)


func _gui_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not editable:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_painting = mb.pressed
			if mb.pressed:
				var p := _to_px(mb.position)
				stamp(p, brush_color, brush_radius)
				_last = p
				strokes += 1
				stroke_started.emit(p)
			else:
				_last = Vector2i(-1, -1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			brush_radius = mini(brush_radius + 2, 80)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			brush_radius = maxi(brush_radius - 2, 4)
	elif event is InputEventMouseMotion and _painting:
		var p := _to_px((event as InputEventMouseMotion).position)
		var from := Vector2(_last if _last.x >= 0 else p)
		var dist := from.distance_to(Vector2(p))
		var steps := maxi(1, int(dist / (brush_radius * 0.35)))
		for i in range(1, steps + 1):
			stamp(Vector2i(from.lerp(Vector2(p), float(i) / steps)), brush_color, brush_radius)
		_last = p


var editable := true


## Filled circle drawn as horizontal spans (fill_rect is native, so this is fast).
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


func _process(_dt: float) -> void:
	if _dirty:
		_tex.update(image)
		_dirty = false
