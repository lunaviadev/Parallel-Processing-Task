extends Control

const SAMPLE_DIR := "res://images/"

var _image: Image
var _image_name := ""
var _thread: Thread
var _running := false
var _single_sum := -1
var _stats: Array[Dictionary] = []

var _sample_pick: OptionButton
var _runs_box: SpinBox
var _rgb_check: CheckBox
var _info: Label
var _status: Label
var _log: RichTextLabel
var _chart: Control
var _run_btn: Button
var _file_dialog: FileDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Aero.wallpaper(self)
	var desk := Aero.desk_area(self)
	Aero.taskbar(self, [{"name": "Benchmark Lab", "icon": "icon_bench", "active": true}])
	Audio.play_music("desktop")
	var win := AeroWindow.new("Benchmark Lab - WorkerThreadPool vs single thread", "icon_bench", Vector2(1240, 662))
	win.closed.connect(func() -> void: Aero.to_desktop())
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	win.content.add_child(root)

	var left_panel := UI.panel(1.0, "InsetPanel")
	root.add_child(left_panel)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size.x = 300
	left_panel.add_child(left)
	var head := HBoxContainer.new()
	head.add_child(UI.icon_rect("icon_bench", 44))
	var ht := UI.label("Benchmark Lab", 28, Aero.NAVY)
	ht.add_theme_font_override("font", Aero.font_light)
	head.add_child(ht)
	left.add_child(head)
	left.add_child(UI.label("Red-channel sum: single thread vs WorkerThreadPool", 13, UI.DIM))
	left.add_child(UI.label("Sample image", 14, Aero.NAVY, true))
	_sample_pick = OptionButton.new()
	_sample_pick.item_selected.connect(_on_sample_selected)
	left.add_child(_sample_pick)
	left.add_child(UI.button("Load image from disk...", _open_dialog))
	_info = UI.label("No image", 14)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_info)
	left.add_child(UI.label("Runs per mode", 14, Aero.NAVY, true))
	_runs_box = SpinBox.new()
	_runs_box.min_value = 1
	_runs_box.max_value = 50
	_runs_box.value = 5
	left.add_child(_runs_box)
	_rgb_check = CheckBox.new()
	_rgb_check.text = "Also run RGB and 4x4 tile passes"
	_rgb_check.button_pressed = true
	left.add_child(_rgb_check)
	_run_btn = UI.button("Run benchmark", _start_benchmark, 260, "GreenButton")
	left.add_child(_run_btn)
	left.add_child(UI.button("Export CSV + JSON", _export))
	left.add_child(UI.button("Back to desktop", func() -> void: win.close()))
	_status = UI.label("Cores: %d logical" % OS.get_processor_count(), 14, UI.DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_status)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	root.add_child(right)
	var chart_panel := UI.panel(1.0, "InsetPanel")
	right.add_child(chart_panel)
	_chart = Control.new()
	_chart.custom_minimum_size = Vector2(0, 300)
	_chart.draw.connect(_draw_chart)
	chart_panel.add_child(_chart)
	var log_panel := UI.panel(1.0, "InsetPanel")
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(log_panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 14)
	log_panel.add_child(_log)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.tga ; Images"])
	_file_dialog.file_selected.connect(_load_from_disk)
	add_child(_file_dialog)
	desk.add_child(win)
	win.center_in(Vector2(1280, 720 - Aero.TASKBAR_H))

	_populate_samples()
	_log_line("[color=#1f6fb8]Benchmark Lab ready.[/color] %s, %d logical cores, pool max threads %d" % [
		OS.get_processor_name(), OS.get_processor_count(), Telemetry.pool_threads()])

	if "--autobench" in OS.get_cmdline_user_args():
		_autobench.call_deferred()


func _populate_samples() -> void:
	_sample_pick.clear()
	var files := Array(ResourceLoader.list_directory(SAMPLE_DIR))
	files.sort_custom(func(a: String, b: String) -> bool:
		return a.get_basename().get_slice("_", 1).to_int() < b.get_basename().get_slice("_", 1).to_int())
	for f: String in files:
		if f.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
			_sample_pick.add_item(f)
	if _sample_pick.item_count > 0:
		_sample_pick.select(_sample_pick.item_count - 1)
		_on_sample_selected(_sample_pick.item_count - 1)


func _on_sample_selected(idx: int) -> void:
	var path := SAMPLE_DIR + _sample_pick.get_item_text(idx)
	var tex := load(path) as Texture2D
	if tex:
		_set_image(tex.get_image(), path)


func _open_dialog() -> void:
	_file_dialog.popup_centered_ratio(0.6)


func _load_from_disk(path: String) -> void:
	var t0 := Time.get_ticks_usec()
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		_log_line("[color=#b9770e]Could not load %s[/color]" % path)
		return
	_log_line("Loaded %s from disk in %.1f ms" % [path.get_file(), (Time.get_ticks_usec() - t0) / 1000.0])
	_set_image(img, path)


func _set_image(img: Image, path: String) -> void:
	_image = RedSum.to_rgba8(img)
	_image_name = path.get_file()
	_info.text = "%s\n%d x %d  (%s pixels)" % [_image_name, _image.get_width(), _image.get_height(),
		String.num_int64(_image.get_width() * _image.get_height())]


func _thread_counts() -> Array[int]:
	var out: Array[int] = []
	var t := 1
	var cores := OS.get_processor_count()
	while t < cores:
		out.append(t)
		t *= 2
	out.append(cores)
	return out


func _start_benchmark() -> void:
	if _running or _image == null:
		return
	_running = true
	_run_btn.disabled = true
	_stats.clear()
	_single_sum = -1
	_chart.queue_redraw()
	_status.text = "Running..."
	_log_line("\n[b]Benchmark %s[/b]  runs/mode=%d" % [_image_name, int(_runs_box.value)])
	_thread = Thread.new()
	_thread.start(_bench_thread.bind(_image, int(_runs_box.value), _thread_counts(), _rgb_check.button_pressed))


func _bench_thread(img: Image, runs: int, counts: Array[int], rgb: bool) -> void:
	RedSum.sum_single(img)
	_run_mode(img, runs, "single", func() -> Dictionary: return RedSum.sum_single(img))
	for t in counts:
		_run_mode(img, runs, "parallel x%d" % t, func() -> Dictionary: return RedSum.sum_parallel(img, t))
	if rgb:
		_run_mode(img, runs, "rgb x%d" % counts[-1], func() -> Dictionary: return RedSum.sum_rgb_parallel(img, counts[-1]))
		_run_mode(img, runs, "tiles4 x%d" % counts[-1], func() -> Dictionary: return RedSum.sum_tiles(img, 4, 4, counts[-1]))
	_on_done.call_deferred()


func _run_mode(_img: Image, runs: int, label: String, fn: Callable) -> void:
	var times := PackedFloat64Array()
	var threads := 1
	for i in runs:
		var r: Dictionary = fn.call()
		times.append(r.ms)
		threads = r.threads
		_on_run.call_deferred(r, label)
	var total := 0.0
	for t in times:
		total += t
	var stat := {"label": label, "avg": total / runs, "min": Array(times).min(), "max": Array(times).max(), "threads": threads}
	_on_mode_done.call_deferred(stat)


func _on_run(r: Dictionary, label: String) -> void:
	Telemetry.record(r, label, _image_name)
	if label == "single":
		_single_sum = r.sum
	var match_txt := ""
	if _single_sum >= 0 and label != "single":
		match_txt = "  [color=#2e9d3a]match[/color]" if r.sum == _single_sum else "  [color=#c0392b]MISMATCH[/color]"
	_log_line("%-14s sum=%s  mean R=%.2f  %.3f ms%s" % [label, String.num_int64(r.sum), r.mean_red, r.ms, match_txt])


func _on_mode_done(stat: Dictionary) -> void:
	_stats.append(stat)
	var base := _stats[0].avg as float
	_log_line("[b]%s[/b] avg %.3f ms  (min %.3f / max %.3f)  speed-up x%.2f" % [
		stat.label, stat.avg, stat.min, stat.max, base / maxf(stat.avg, 0.0001)])
	_chart.queue_redraw()


func _on_done() -> void:
	_thread.wait_to_finish()
	_thread = null
	_running = false
	_run_btn.disabled = false
	var best := _stats[0]
	for s in _stats:
		if s.avg < best.avg:
			best = s
	_status.text = "Done. Fastest: %s (%.2f ms, x%.2f)" % [best.label, best.avg, _stats[0].avg / best.avg]
	_log_line("[color=#1f6fb8]Done.[/color] Fastest: %s" % best.label)


func _export() -> void:
	if Telemetry.runs.is_empty():
		_log_line("[color=#b9770e]Nothing to export yet - run the benchmark first.[/color]")
		return
	var paths := Telemetry.export_files({"image": _image_name, "modes": _stats})
	_log_line("Exported:\n  %s\n  %s" % [paths[0], paths[1]])
	_status.text = "Exported to " + paths[0].get_base_dir()


func _log_line(t: String) -> void:
	_log.append_text(t + "\n")


func _draw_chart() -> void:
	var font := Aero.font_semi
	var area := Rect2(Vector2(50, 50), _chart.size - Vector2(70, 96))
	_chart.draw_string(font, Vector2(0, 18), "Average execution time per mode (ms) - lower is faster", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Aero.NAVY)
	for g in 5:
		var y := area.position.y + area.size.y * g / 4.0
		_chart.draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(0.55, 0.7, 0.82, 0.35), 1.0)
	_chart.draw_line(area.position + Vector2(0, area.size.y), area.end, Color(0.3, 0.45, 0.6), 1.5)
	if _stats.is_empty():
		_chart.draw_string(font, area.get_center() - Vector2(130, 0), "Run the benchmark to see results", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.DIM)
		return
	var max_ms := 0.0
	for st in _stats:
		max_ms = maxf(max_ms, st.avg)
	var n := _stats.size()
	var slot := area.size.x / n
	var bar_w := minf(slot * 0.62, 86.0)
	for i in n:
		var st := _stats[i]
		var h: float = area.size.y * (st.avg / max_ms)
		var x := area.position.x + slot * i + (slot - bar_w) / 2.0
		var rect := Rect2(x, area.end.y - h, bar_w, h)
		var base := Color(0.6, 0.66, 0.72) if st.label == "single" else Color(0.2, 0.62, 0.95).lerp(Color(0.3, 0.82, 0.4), float(i) / n)
		_chart.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
				PackedColorArray([base.lightened(0.35), base.lightened(0.35), base.darkened(0.15), base.darkened(0.15)]))
		_chart.draw_rect(Rect2(rect.position, Vector2(rect.size.x * 0.5, rect.size.y)), Color(1, 1, 1, 0.22))
		_chart.draw_rect(rect, base.darkened(0.35), false, 1.0)
		_chart.draw_string(font, Vector2(x, rect.position.y - 6), "%.1f" % st.avg, HORIZONTAL_ALIGNMENT_CENTER, bar_w, 14, Aero.NAVY)
		_chart.draw_string(Aero.font, Vector2(x - 12, area.end.y + 18), st.label, HORIZONTAL_ALIGNMENT_CENTER, bar_w + 24, 13, Aero.NAVY)
		_chart.draw_string(font, Vector2(x, area.end.y + 36), "x%.2f" % (_stats[0].avg / st.avg), HORIZONTAL_ALIGNMENT_CENTER, bar_w, 13, UI.GOOD)


func _autobench() -> void:
	var hold := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--image="):
			_load_from_disk(a.trim_prefix("--image="))
		elif a.begins_with("--hold="):
			hold = a.trim_prefix("--hold=").to_float()
	if hold > 0.0:
		await get_tree().create_timer(hold * 0.4).timeout
	_start_benchmark()
	while _running:
		await get_tree().process_frame
	_export()
	if hold > 0.0:
		await get_tree().create_timer(hold).timeout
	get_tree().quit()


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
