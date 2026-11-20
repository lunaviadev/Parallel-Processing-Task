extends Node

const ART := "res://ui/art/"
const NAVY := Color(0.07, 0.22, 0.36)
const NAVY_SOFT := Color(0.22, 0.38, 0.52)
const SKY := Color(0.30, 0.70, 0.95)
const AQUA := Color(0.10, 0.70, 0.90)
const GRASS := Color(0.36, 0.78, 0.25)
const WHITE := Color(1, 1, 1)
const TASKBAR_H := 46
const SCENE_DESKTOP := "res://scenes/main_menu.tscn"
const SCENE_GAME := "res://scenes/game.tscn"
const SCENE_BENCH := "res://scenes/benchmark.tscn"

const APPS := [
	{"id": "classic", "name": "Red Painter", "icon": "icon_play", "hint": "Classic mode: beat the clock"},
	{"id": "zen", "name": "Zen Painter", "icon": "icon_zen", "hint": "No timer, no blobs, just paint"},
	{"id": "bench", "name": "Benchmark Lab", "icon": "icon_bench", "hint": "Parallel red-channel benchmark"},
	{"id": "mixer", "name": "Audio Mixer", "icon": "icon_mixer", "hint": "FMOD VCAs and live parameters"},
	{"id": "scores", "name": "High Scores", "icon": "icon_scores", "hint": "Best runs"},
	{"id": "help", "name": "Help", "icon": "icon_help", "hint": "How to play"},
	{"id": "system", "name": "System Info", "icon": "orb", "hint": "CPU, threads and FMOD status"},
]

var font: FontFile
var font_semi: FontFile
var font_bold: FontFile
var font_light: FontFile
var theme: Theme
var game_mode := "classic"
var pending_app := ""
var booted := false
var _tex := {}
var _start_menu: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://ui/fonts/selawk.ttf")
	font_semi = load("res://ui/fonts/selawksb.ttf")
	font_bold = load("res://ui/fonts/selawkb.ttf")
	font_light = load("res://ui/fonts/selawkl.ttf")
	theme = _build_theme()
	get_tree().root.theme = theme
	ThemeDB.fallback_font = font


func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(ART + name + ".png")
	return _tex[name]


func box(name: String, margin: int, content := -1) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(margin if content < 0 else content)
	return sb


func _flat(bg: Color, radius: int, border := Color(0, 0, 0, 0), bw := 0, pad := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = true
	return sb


func _button_styles(t: Theme, type: String, prefix: String) -> void:
	for st in ["normal", "hover", "pressed"]:
		var sb := box(prefix + "_" + st, 12)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 7
		t.set_stylebox(st, type, sb)
	t.set_stylebox("hover_pressed", type, t.get_stylebox("pressed", type))
	var dis := box("btn_disabled", 12)
	t.set_stylebox("disabled", type, dis)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 15
	_button_styles(t, "Button", "btn")
	t.set_color("font_color", "Button", NAVY)
	t.set_color("font_hover_color", "Button", NAVY)
	t.set_color("font_pressed_color", "Button", Color(0.02, 0.14, 0.26))
	t.set_color("font_hover_pressed_color", "Button", Color(0.02, 0.14, 0.26))
	t.set_color("font_focus_color", "Button", NAVY)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.55, 0.62))
	t.set_font("font", "Button", font_semi)
	for v in [["GreenButton", "btn_green", Color(0.08, 0.26, 0.05)], ["RedButton", "btn_red", Color(0.35, 0.03, 0.02)]]:
		t.set_type_variation(v[0], "Button")
		_button_styles(t, v[0], v[1])
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			t.set_color(c, v[0], v[2])
	t.set_type_variation("FlatButton", "Button")
	for st in ["normal", "pressed", "focus", "disabled"]:
		t.set_stylebox(st, "FlatButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "FlatButton", _flat(Color(1, 1, 1, 0.22), 8, Color(1, 1, 1, 0.55), 1))
	t.set_stylebox("hover_pressed", "FlatButton", _flat(Color(1, 1, 1, 0.32), 8, Color(1, 1, 1, 0.7), 1))
	t.set_color("font_color", "FlatButton", WHITE)
	t.set_color("font_hover_color", "FlatButton", WHITE)
	t.set_color("font_pressed_color", "FlatButton", WHITE)
	t.set_color("font_outline_color", "FlatButton", Color(0.0, 0.15, 0.3, 0.8))
	t.set_constant("outline_size", "FlatButton", 4)
	t.set_type_variation("TaskButton", "Button")
	t.set_stylebox("normal", "TaskButton", _flat(Color(1, 1, 1, 0.12), 6, Color(1, 1, 1, 0.35), 1, 8))
	t.set_stylebox("hover", "TaskButton", _flat(Color(0.6, 0.9, 1, 0.3), 6, Color(1, 1, 1, 0.7), 1, 8))
	t.set_stylebox("pressed", "TaskButton", _flat(Color(0.4, 0.8, 1, 0.38), 6, Color(1, 1, 1, 0.8), 1, 8))
	t.set_stylebox("hover_pressed", "TaskButton", t.get_stylebox("pressed", "TaskButton"))
	t.set_stylebox("focus", "TaskButton", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "TaskButton", WHITE)

	t.set_color("font_color", "Label", NAVY)
	t.set_type_variation("LightLabel", "Label")
	t.set_color("font_color", "LightLabel", WHITE)
	t.set_color("font_shadow_color", "LightLabel", Color(0, 0.12, 0.25, 0.6))
	t.set_constant("shadow_offset_x", "LightLabel", 0)
	t.set_constant("shadow_offset_y", "LightLabel", 1)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", font_semi)
	t.set_color("font_color", "TitleLabel", NAVY)
	t.set_color("font_outline_color", "TitleLabel", Color(1, 1, 1, 0.85))
	t.set_constant("outline_size", "TitleLabel", 6)

	t.set_stylebox("panel", "PanelContainer", box("panel_glass", 14, 14))
	t.set_type_variation("DarkPanel", "PanelContainer")
	t.set_stylebox("panel", "DarkPanel", box("panel_dark", 14, 12))
	t.set_type_variation("InsetPanel", "PanelContainer")
	t.set_stylebox("panel", "InsetPanel", _flat(Color(1, 1, 1, 0.75), 8, Color(0.55, 0.72, 0.86, 0.9), 1, 10))

	var pb_bg := box("bar_bg", 8, 0)
	var pb_fill := box("bar_fill", 8, 0)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_color("font_color", "ProgressBar", NAVY)

	t.set_stylebox("slider", "HSlider", _flat(Color(0.82, 0.9, 0.96), 5, Color(0.45, 0.62, 0.76), 1, 3))
	var area := box("bar_fill_blue", 8, 3)
	t.set_stylebox("grabber_area", "HSlider", area)
	t.set_stylebox("grabber_area_highlight", "HSlider", area)
	var grab := _scaled(tex("orb"), 22)
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)

	var le := _flat(Color(1, 1, 1, 0.95), 6, Color(0.5, 0.66, 0.8), 1, 6)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", _flat(Color(1, 1, 1, 1), 6, AQUA, 2, 6))
	t.set_color("font_color", "LineEdit", NAVY)
	t.set_color("font_color", "CheckBox", NAVY)
	t.set_color("font_hover_color", "CheckBox", NAVY)
	t.set_color("font_pressed_color", "CheckBox", NAVY)
	t.set_color("font_hover_pressed_color", "CheckBox", NAVY)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PopupMenu", box("panel_glass", 14, 8))
	t.set_color("font_color", "PopupMenu", NAVY)
	t.set_color("font_hover_color", "PopupMenu", NAVY)
	t.set_stylebox("hover", "PopupMenu", _flat(Color(0.55, 0.85, 1, 0.5), 5))
	t.set_stylebox("panel", "TooltipPanel", box("panel_glass", 14, 8))
	t.set_color("font_color", "TooltipLabel", NAVY)
	t.set_color("default_color", "RichTextLabel", NAVY)
	t.set_font("bold_font", "RichTextLabel", font_bold)
	t.set_font("normal_font", "RichTextLabel", font)
	t.set_stylebox("scroll", "VScrollBar", _flat(Color(0.8, 0.88, 0.94, 0.6), 5, Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("grabber", "VScrollBar", _flat(Color(0.45, 0.7, 0.9), 5))
	t.set_stylebox("grabber_highlight", "VScrollBar", _flat(Color(0.35, 0.65, 0.95), 5))
	t.set_stylebox("grabber_pressed", "VScrollBar", _flat(Color(0.25, 0.55, 0.9), 5))
	t.set_stylebox("normal", "OptionButton", t.get_stylebox("normal", "Button"))
	t.set_stylebox("hover", "OptionButton", t.get_stylebox("hover", "Button"))
	t.set_stylebox("pressed", "OptionButton", t.get_stylebox("pressed", "Button"))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "OptionButton", NAVY)
	t.set_color("font_hover_color", "OptionButton", NAVY)
	return t


func _scaled(src: Texture2D, px: int) -> Texture2D:
	var img := src.get_image()
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


func wallpaper(parent: Control, dim := 0.0) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ui/wallpaper.gdshader")
	mat.set_shader_parameter("dim", dim)
	r.material = mat
	r.resized.connect(func() -> void: mat.set_shader_parameter("aspect", r.size.x / maxf(r.size.y, 1.0)))
	parent.add_child(r)
	return r


func desk_area(parent: Control) -> Control:
	var d := Control.new()
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	d.offset_bottom = -TASKBAR_H
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)
	return d


func taskbar(parent: Control, tasks: Array = []) -> Control:
	var bar := NinePatchRect.new()
	bar.texture = tex("taskbar")
	bar.patch_margin_top = 4
	bar.patch_margin_bottom = 4
	bar.patch_margin_left = 2
	bar.patch_margin_right = 2
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -TASKBAR_H
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(bar)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 70
	row.offset_right = -10
	row.offset_top = 6
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	for t in tasks:
		var b := Button.new()
		b.theme_type_variation = "TaskButton"
		b.text = "  " + str(t.get("name", ""))
		b.icon = _scaled(tex(str(t.get("icon", "orb"))), 22)
		b.custom_minimum_size = Vector2(170, 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = bool(t.get("active", false))
		b.focus_mode = Control.FOCUS_NONE
		if t.has("callback"):
			b.pressed.connect(t.callback)
		row.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var tray := PanelContainer.new()
	tray.add_theme_stylebox_override("panel", _flat(Color(0, 0.1, 0.2, 0.35), 6, Color(1, 1, 1, 0.18), 1, 6))
	row.add_child(tray)
	var tray_row := HBoxContainer.new()
	tray_row.add_theme_constant_override("separation", 10)
	tray.add_child(tray_row)
	var fmod_dot := TextureRect.new()
	fmod_dot.texture = _scaled(tex("icon_mixer" if Audio.available else "icon_power"), 18)
	fmod_dot.tooltip_text = Audio.status + "\nF3 shows live FMOD telemetry"
	fmod_dot.mouse_filter = Control.MOUSE_FILTER_PASS
	tray_row.add_child(fmod_dot)
	var cpu := Label.new()
	cpu.theme_type_variation = "LightLabel"
	cpu.text = "%d threads" % OS.get_processor_count()
	cpu.add_theme_font_size_override("font_size", 12)
	cpu.tooltip_text = OS.get_processor_name()
	cpu.mouse_filter = Control.MOUSE_FILTER_PASS
	tray_row.add_child(cpu)
	var clock := Label.new()
	clock.theme_type_variation = "LightLabel"
	clock.add_theme_font_size_override("font_size", 14)
	clock.custom_minimum_size.x = 44
	tray_row.add_child(clock)
	var tick := func() -> void:
		var tm := Time.get_time_dict_from_system()
		clock.text = "%02d:%02d" % [tm.hour, tm.minute]
	tick.call()
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(tick)
	bar.add_child(timer)
	var orb := TextureButton.new()
	orb.texture_normal = tex("orb")
	orb.ignore_texture_size = true
	orb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	orb.custom_minimum_size = Vector2(56, 56)
	orb.size = Vector2(56, 56)
	orb.position = Vector2(8, -12)
	orb.tooltip_text = "Start"
	orb.mouse_entered.connect(func() -> void:
		orb.modulate = Color(1.15, 1.15, 1.15)
		Audio.hover())
	orb.mouse_exited.connect(func() -> void: orb.modulate = Color.WHITE)
	orb.pressed.connect(func() -> void: toggle_start_menu(parent))
	bar.add_child(orb)
	return bar


func toggle_start_menu(parent: Control) -> void:
	if is_instance_valid(_start_menu) and _start_menu.is_inside_tree():
		close_start_menu()
		return
	Audio.play(Audio.EV_WINDOW_OPEN)
	var shield := Control.new()
	shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	shield.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close_start_menu())
	parent.add_child(shield)
	_start_menu = shield
	var menu := PanelContainer.new()
	menu.theme_type_variation = "DarkPanel"
	menu.position = Vector2(6, parent.size.y - TASKBAR_H - 440)
	menu.custom_minimum_size = Vector2(300, 430)
	shield.add_child(menu)
	var box_v := VBoxContainer.new()
	box_v.add_theme_constant_override("separation", 2)
	menu.add_child(box_v)
	var head := Label.new()
	head.theme_type_variation = "LightLabel"
	head.text = "Red Painter OS"
	head.add_theme_font_override("font", font_semi)
	head.add_theme_font_size_override("font_size", 20)
	box_v.add_child(head)
	var sub := Label.new()
	sub.theme_type_variation = "LightLabel"
	sub.text = "best %s" % String.num_int64(int(UI.cfg_get("game", "best", 0)))
	sub.add_theme_font_size_override("font_size", 12)
	box_v.add_child(sub)
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	box_v.add_child(sep)
	for app in APPS:
		var b := Button.new()
		b.theme_type_variation = "FlatButton"
		b.text = "  " + str(app.name)
		b.icon = _scaled(tex(app.icon), 30)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 42)
		b.add_theme_font_size_override("font_size", 16)
		b.tooltip_text = str(app.hint)
		b.mouse_entered.connect(func() -> void: Audio.hover())
		var id: String = app.id
		b.pressed.connect(func() -> void:
			close_start_menu()
			launch(id))
		box_v.add_child(b)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box_v.add_child(fill)
	var off := Button.new()
	off.theme_type_variation = "RedButton"
	off.text = "Shut down"
	off.icon = _scaled(tex("icon_power"), 20)
	off.pressed.connect(func() -> void:
		close_start_menu()
		shut_down())
	box_v.add_child(off)
	menu.pivot_offset = Vector2(0, 430)
	menu.scale = Vector2(0.9, 0.9)
	menu.modulate.a = 0.0
	var tw := menu.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(menu, "scale", Vector2.ONE, 0.16)
	tw.tween_property(menu, "modulate:a", 1.0, 0.16)


func close_start_menu() -> void:
	if is_instance_valid(_start_menu):
		_start_menu.queue_free()
	_start_menu = null


func launch(id: String) -> void:
	Audio.play(Audio.EV_CLICK)
	match id:
		"classic", "zen":
			game_mode = id
			get_tree().change_scene_to_file(SCENE_GAME)
		"bench":
			get_tree().change_scene_to_file(SCENE_BENCH)
		_:
			var scene := get_tree().current_scene
			if scene and scene.has_method("open_app"):
				scene.open_app(id)
			else:
				pending_app = id
				get_tree().change_scene_to_file(SCENE_DESKTOP)


func to_desktop() -> void:
	get_tree().paused = false
	Audio.set_paused_mix(false)
	Audio.set_freeze_mix(false)
	get_tree().change_scene_to_file(SCENE_DESKTOP)


func shut_down() -> void:
	Audio.play(Audio.EV_WINDOW_CLOSE)
	var root := get_tree().current_scene as Control
	if root == null:
		get_tree().quit()
		return
	var cover := ColorRect.new()
	cover.color = Color(0.02, 0.1, 0.2, 0.0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(cover)
	var lbl := Label.new()
	lbl.theme_type_variation = "LightLabel"
	lbl.text = "Shutting down..."
	lbl.add_theme_font_override("font", font_light)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	lbl.modulate.a = 0.0
	cover.add_child(lbl)
	Audio.stop_music()
	var tw := cover.create_tween()
	tw.tween_property(cover, "color:a", 1.0, 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.0)
	tw.tween_callback(func() -> void: get_tree().quit())


func icon_button(app: Dictionary, on_open: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "FlatButton"
	b.icon = tex(app.icon)
	b.text = str(app.name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = false
	b.custom_minimum_size = Vector2(104, 108)
	b.add_theme_font_size_override("font_size", 14)
	b.tooltip_text = "%s\nDouble-click to open" % app.hint
	b.mouse_entered.connect(func() -> void: Audio.hover())
	b.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
			on_open.call())
	return b
