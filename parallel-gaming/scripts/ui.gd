class_name UI
extends RefCounted

const RED := Color(0.86, 0.12, 0.22)
const ROSE := Color8(128, 30, 150)
const TEAL := Color8(0, 170, 170)
const GOLD := Color(0.85, 0.55, 0.05)
const GOOD := Color(0.16, 0.62, 0.22)
const TEXT := Color(0.07, 0.22, 0.36)
const DIM := Color(0.27, 0.42, 0.56)
const CFG_PATH := "user://settings.cfg"

static var _cfg: ConfigFile


static func button(text: String, on_pressed: Callable, min_w := 220, variant := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 40)
	b.add_theme_font_size_override("font_size", 16)
	b.focus_mode = Control.FOCUS_NONE
	if variant != "":
		b.theme_type_variation = variant
	b.mouse_entered.connect(func() -> void: Audio.hover())
	b.pressed.connect(func() -> void:
		Audio.play(Audio.EV_CLICK)
		on_pressed.call())
	return b


static func label(text: String, size := 16, color := TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", Aero.font_semi)
	return l


static func light_label(text: String, size := 16) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "LightLabel"
	l.add_theme_font_size_override("font_size", size)
	return l


static func panel(_alpha := 1.0, variant := "") -> PanelContainer:
	var p := PanelContainer.new()
	if variant != "":
		p.theme_type_variation = variant
	return p


static func background(parent: Control) -> void:
	Aero.wallpaper(parent)


static func margin(parent: Control, px := 24) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	parent.add_child(m)
	return m


static func slider(value: float, on_changed: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(220, 26)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(on_changed)
	return s


static func icon_rect(name: String, px: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Aero.tex(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func _load_cfg() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(CFG_PATH)
	return _cfg


static func cfg_get(section: String, key: String, default: Variant) -> Variant:
	return _load_cfg().get_value(section, key, default)


static func cfg_set(section: String, key: String, value: Variant) -> void:
	_load_cfg().set_value(section, key, value)
	_cfg.save(CFG_PATH)


static func add_score(mode: String, entry: Dictionary) -> int:
	var list: Array = cfg_get("scores", mode, [])
	entry["date"] = Time.get_date_string_from_system()
	list.append(entry)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("score", 0)) > int(b.get("score", 0)))
	list = list.slice(0, 8)
	cfg_set("scores", mode, list)
	return list.find(entry)
