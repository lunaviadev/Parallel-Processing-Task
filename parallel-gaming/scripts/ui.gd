class_name UI
extends RefCounted
## Small helpers so every screen shares the same look and click sound.

const RED := Color(0.92, 0.16, 0.22)
const BG := Color(0.07, 0.06, 0.08)
const PANEL := Color(0.12, 0.10, 0.13)


static func button(text: String, on_pressed: Callable, min_w := 260) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func() -> void:
		Audio.play_one_shot(Audio.EV_CLICK)
		on_pressed.call())
	return b


static func label(text: String, size := 18, color := Color(0.92, 0.9, 0.93)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)


static func margin(parent: Control, px := 24) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	parent.add_child(m)
	return m
