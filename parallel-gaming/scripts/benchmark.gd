extends Control
## Benchmark Lab: load an image from disk, sum its red channel single-threaded
## and with 1..N pool threads, log each run, chart the averages and export
## CSV/JSON telemetry. The benchmark runs on its own Thread so the UI (and
## recording software) keeps updating while it works.

const SAMPLE_DIR := "res://images/"

var _image: Image
var _image_name := ""
var _thread: Thread
var _running := false
var _single_sum := -1
var _stats: Array[Dictionary] = []  # {label, avg, min, max, threads}

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
	UI.background(self)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	UI.margin(self).add_child(root)

	# --- left: controls ---
	var left_panel := UI.panel()
	root.add_child(left_panel)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size.x = 300
	left_panel.add_child(left)
	left.add_child(UI.label("BENCHMARK LAB", 28, UI.RED))
	left.add_child(UI.label("Red-channel sum: single thread vs WorkerThreadPool", 13))
	left.add_child(UI.label("Sample image", 14))
	_sample_pick = OptionButton.new()
	_sample_pick.item_selected.connect(_on_sample_selected)
	left.add_child(_sample_pick)
	left.add_child(UI.button("Load image from disk...", _open_dialog))
	_info = UI.label("No image", 14)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_info)
	left.add_child(UI.label("Runs per mode", 14))
	_runs_box = SpinBox.new()
	_runs_box.min_value = 1
	_runs_box.max_value = 50
	_runs_box.value = 5
	left.add_child(_runs_box)
	_rgb_check = CheckBox.new()
	_rgb_check.text = "Also run R+G+B parallel pass"
	left.add_child(_rgb_check)
	_run_btn = UI.button("Run benchmark", _start_benchmark)
	left.add_child(_run_btn)
	left.add_child(UI.button("Export CSV + JSON", _export))
	left.add_child(UI.button("Back to menu", func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn")))
	_status = UI.label("Cores: %d logical" % OS.get_processor_count(), 14, Color(0.7, 0.7, 0.75))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_status)

	# --- right: chart + log ---
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	root.add_child(right)
	var chart_panel := UI.panel()
	right.add_child(chart_panel)
	_chart = Control.new()
	_chart.custom_minimum_size = Vector2(0, 300)
	_chart.draw.connect(_draw_chart)
	chart_panel.add_child(_chart)
	var log_panel := UI.panel()
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

	_populate_samples()
	_log_line("[color=#ff5566]Benchmark Lab ready.[/color] %s, %d logical cores, pool max threads %d" % [
		OS.get_processor_name(), OS.get_processor_count(), Telemetry.pool_threads()])

	if "--autobench" in OS.get_cmdline_user_args():
		_autobench.call_deferred()


func _populate_samples() -> void:
	_sample_pick.clear()
	var files := Array(ResourceLoader.list_directory(SAMPLE_DIR))
	# smallest -> largest, so the default (last) is the biggest image
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


## "Load an image from disk": read straight from the file system.
func _load_from_disk(path: String) -> void:
	var t0 := Time.get_ticks_usec()
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		_log_line("[color=yellow]Could not load %s[/color]" % path)
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


# ---- runs on the benchmark thread ----
func _bench_thread(img: Image, runs: int, counts: Array[int], rgb: bool) -> void:
	RedSum.sum_single(img)  # warm-up (page in memory, JIT-free but caches cold)
	_run_mode(img, runs, "single", func() -> Dictionary: return RedSum.sum_single(img))
	for t in counts:
		_run_mode(img, runs, "parallel x%d" % t, func() -> Dictionary: return RedSum.sum_parallel(img, t))
	if rgb:
		_run_mode(img, runs, "rgb x%d" % counts[-1], func() -> Dictionary: return RedSum.sum_rgb_parallel(img, counts[-1]))
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


# ---- main thread callbacks ----
func _on_run(r: Dictionary, label: String) -> void:
	Telemetry.record(r, label, _image_name)
	if label == "single":
		_single_sum = r.sum
	var match_txt := ""
	if _single_sum >= 0 and label != "single":
		match_txt = "  [color=#66dd88]match[/color]" if r.sum == _single_sum else "  [color=red]MISMATCH[/color]"
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
	_log_line("[color=#ff5566]Done.[/color] Fastest: %s" % best.label)


func _export() -> void:
	if Telemetry.runs.is_empty():
		_log_line("[color=yellow]Nothing to export yet - run the benchmark first.[/color]")
		return
	var paths := Telemetry.export_files({"image": _image_name, "modes": _stats})
	_log_line("Exported:\n  %s\n  %s" % [paths[0], paths[1]])
	_status.text = "Exported to " + paths[0].get_base_dir()


func _log_line(t: String) -> void:
	_log.append_text(t + "\n")


func _draw_chart() -> void:
	var font := ThemeDB.fallback_font
	var area := Rect2(Vector2(60, 56), _chart.size - Vector2(80, 100))
	_chart.draw_string(font, Vector2(0, 18), "Average execution time per mode (ms) - lower is faster", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.9, 0.92))
	_chart.draw_line(area.position + Vector2(0, area.size.y), area.end, Color(0.5, 0.5, 0.55), 1.0)
	if _stats.is_empty():
		_chart.draw_string(font, area.get_center() - Vector2(140, 0), "Run the benchmark to see results", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.6, 0.65))
		return
	var max_ms := 0.0
	for s in _stats:
		max_ms = maxf(max_ms, s.avg)
	var n := _stats.size()
	var slot := area.size.x / n
	var bar_w := minf(slot * 0.6, 90.0)
	for i in n:
		var s := _stats[i]
		var h: float = area.size.y * (s.avg / max_ms)
		var x := area.position.x + slot * i + (slot - bar_w) / 2.0
		var rect := Rect2(x, area.end.y - h, bar_w, h)
		var col := Color(0.55, 0.55, 0.6) if s.label == "single" else UI.RED.lerp(Color(1, 0.6, 0.3), float(i) / n)
		_chart.draw_rect(rect, col)
		_chart.draw_string(font, Vector2(x - 6, rect.position.y - 6), "%.1f" % s.avg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		_chart.draw_string(font, Vector2(x - 10, area.end.y + 18), s.label, HORIZONTAL_ALIGNMENT_LEFT, bar_w + 30, 13, Color(0.85, 0.85, 0.9))
		_chart.draw_string(font, Vector2(x, area.end.y + 36), "x%.2f" % (_stats[0].avg / s.avg), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.85, 0.6))


## Headless/automation hook: `godot --path parallel-gaming res://scenes/benchmark.tscn -- --autobench`
func _autobench() -> void:
	_start_benchmark()
	while _running:
		await get_tree().process_frame
	_export()
	get_tree().quit()


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
