extends Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.background(self)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := UI.label("RED PAINTER", 72, UI.RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UI.label("Paint to the target redness. The canvas red channel is summed in parallel every 0.2 s.", 16)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(Control.new())
	for b in [
		UI.button("Play", func() -> void: get_tree().change_scene_to_file("res://scenes/game.tscn"), 320),
		UI.button("Benchmark Lab", func() -> void: get_tree().change_scene_to_file("res://scenes/benchmark.tscn"), 320),
		UI.button("Quit", func() -> void: get_tree().quit(), 320),
	]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(b)
	var status := UI.label("%s   |   %d logical cores   |   Godot %s" % [
		Audio.status, OS.get_processor_count(), Engine.get_version_info().string], 13, Color(0.6, 0.6, 0.65))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)

	Audio.start_music()
	Audio.set_redness(0.0)
