extends Control

const STEPS := [
	"Starting Red Painter OS",
	"Loading FMOD Studio banks",
	"Spinning up the worker thread pool",
	"Polishing the glass",
	"Welcome",
]

var _wall: ColorRect
var _bar: ProgressBar
var _status: Label
var _orb: TextureRect
var _halo: TextureRect
var _t := 0.0
var _done := false
var _length := 3.4


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color(0.01, 0.04, 0.09)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	_wall = Aero.wallpaper(self, 0.55)
	_wall.modulate.a = 0.0
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var orb_holder := Control.new()
	orb_holder.custom_minimum_size = Vector2(150, 150)
	box.add_child(orb_holder)
	_halo = TextureRect.new()
	_halo.texture = Aero.tex("glow")
	_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo.size = Vector2(260, 260)
	_halo.position = Vector2(-55, -55)
	_halo.modulate = Color(0.6, 1.0, 0.9, 0.0)
	orb_holder.add_child(_halo)
	_orb = TextureRect.new()
	_orb.texture = Aero.tex("orb")
	_orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_orb.size = Vector2(150, 150)
	_orb.pivot_offset = Vector2(75, 75)
	_orb.modulate.a = 0.0
	orb_holder.add_child(_orb)
	var title := UI.light_label("Red Painter", 54)
	title.add_theme_font_override("font", Aero.font_light)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UI.light_label("O S   E D I T I O N", 13)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate.a = 0.8
	box.add_child(sub)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(320, 16)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	box.add_child(_bar)
	_status = UI.light_label("", 14)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	for n: Control in [title, sub, _bar, _status]:
		n.modulate.a = 0.0
		create_tween().tween_property(n, "modulate:a", 1.0, 0.7).set_delay(0.35)
	create_tween().tween_property(_wall, "modulate:a", 1.0, 1.2)
	create_tween().tween_property(_orb, "modulate:a", 1.0, 0.6).set_delay(0.15)
	get_tree().create_timer(0.35).timeout.connect(func() -> void: Audio.play(Audio.EV_STARTUP))
	if Aero.booted or "--autobench" in OS.get_cmdline_user_args() or "--skip-boot" in OS.get_cmdline_user_args():
		_length = 0.2
	Aero.booted = true
	print("[Boot] %s | %s | %d threads" % [Audio.status, OS.get_processor_name(), OS.get_processor_count()])


func _process(dt: float) -> void:
	_t += dt
	var k := clampf(_t / _length, 0.0, 1.0)
	_bar.value = ease(k, 0.6)
	_status.text = STEPS[mini(int(k * STEPS.size()), STEPS.size() - 1)] + "..."
	_orb.rotation = sin(_t * 1.6) * 0.06
	_orb.scale = Vector2.ONE * (1.0 + 0.03 * sin(_t * 3.0))
	_halo.modulate.a = 0.35 + 0.25 * sin(_t * 2.2)
	if k >= 1.0 and not _done:
		_finish()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _t > 0.6:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.35)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(Aero.SCENE_DESKTOP))
