class_name AeroWindow
extends Control

signal closed

const TITLE_H := 34

var title := ""
var icon_name := "orb"
var closable := true
var draggable := true
var content: VBoxContainer

var _title_label: Label
var _dragging := false
var _drag_off := Vector2.ZERO
var _closing := false


func _init(p_title := "", p_icon := "orb", p_size := Vector2(480, 360)) -> void:
	title = p_title
	icon_name = p_icon
	size = p_size
	custom_minimum_size = p_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)


func _ready() -> void:
	var shadow := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.shadow_color = Color(0, 0.08, 0.2, 0.38)
	sb.shadow_size = 22
	sb.shadow_offset = Vector2(0, 8)
	sb.set_corner_radius_all(12)
	shadow.add_theme_stylebox_override("panel", sb)
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shadow)
	var frame := NinePatchRect.new()
	frame.texture = Aero.tex("window")
	frame.patch_margin_left = 12
	frame.patch_margin_right = 12
	frame.patch_margin_top = 38
	frame.patch_margin_bottom = 12
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var head := HBoxContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	head.offset_left = 10
	head.offset_right = -8
	head.offset_top = 5
	head.offset_bottom = TITLE_H - 3
	head.add_theme_constant_override("separation", 7)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	var ic := TextureRect.new()
	ic.texture = Aero.tex(icon_name)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(22, 22)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(ic)
	_title_label = Label.new()
	_title_label.text = title
	_title_label.add_theme_font_override("font", Aero.font_semi)
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", Color(0.04, 0.16, 0.28))
	_title_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.75))
	_title_label.add_theme_constant_override("outline_size", 5)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.clip_text = true
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_title_label)
	if closable:
		head.add_child(_cap_button("win_min", "min", func() -> void: close()))
		head.add_child(_cap_button("win_close", "close", func() -> void: close()))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", TITLE_H + 10)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	margin.add_child(content)
	pivot_offset = size / 2.0
	scale = Vector2(0.93, 0.93)
	modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.22)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)


func set_title(t: String) -> void:
	title = t
	if _title_label:
		_title_label.text = t


func _cap_button(tex_name: String, glyph: String, cb: Callable) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = Aero.tex(tex_name)
	b.texture_hover = Aero.tex(tex_name + "_hover")
	b.texture_pressed = Aero.tex(tex_name)
	b.custom_minimum_size = Vector2(46, 22)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	b.draw.connect(func() -> void:
		var c := b.size / 2.0
		var col := Color.WHITE
		if glyph == "close":
			b.draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), Color(0.2, 0.0, 0.0, 0.5), 3.5)
			b.draw_line(c + Vector2(5, -5), c + Vector2(-5, 5), Color(0.2, 0.0, 0.0, 0.5), 3.5)
			b.draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), col, 2.2)
			b.draw_line(c + Vector2(5, -5), c + Vector2(-5, 5), col, 2.2)
		else:
			b.draw_line(c + Vector2(-6, 4), c + Vector2(6, 4), Color(0.05, 0.2, 0.35), 2.5))
	return b


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			move_to_front()
			if draggable and mb.position.y <= TITLE_H:
				_dragging = true
				_drag_off = mb.position
		else:
			_dragging = false
	var mm := event as InputEventMouseMotion
	if mm and _dragging:
		var parent_rect := (get_parent() as Control).get_rect() if get_parent() is Control else Rect2(Vector2.ZERO, get_viewport_rect().size)
		var p := position + mm.position - _drag_off
		p.x = clampf(p.x, -size.x + 80, parent_rect.size.x - 80)
		p.y = clampf(p.y, 0, parent_rect.size.y - TITLE_H)
		position = p


func center_in(area: Vector2, offset := Vector2.ZERO) -> void:
	position = ((area - size) / 2.0 + offset).round()


func close() -> void:
	if _closing or not closable:
		return
	_closing = true
	Audio.play(Audio.EV_WINDOW_CLOSE)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(0.9, 0.9), 0.14)
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	tw.chain().tween_callback(func() -> void:
		closed.emit()
		queue_free())
