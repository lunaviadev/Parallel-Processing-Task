extends Node
## Autoload "Telemetry": records every red-sum run, prints a log line, and
## exports the session to CSV + JSON under user://telemetry/.

const DIR := "user://telemetry"
const FIELDS := ["timestamp", "label", "image", "mode", "threads", "chunks", "width", "height",
		"pixels", "sum", "mean_red", "ms"]

var runs: Array[Dictionary] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	print("[Telemetry] logical cores=%d  pool threads=%d  user dir=%s" % [
		OS.get_processor_count(), pool_threads(), ProjectSettings.globalize_path(DIR)])


## Worker pool size (project setting; -1 means one worker per logical core).
static func pool_threads() -> int:
	var n: int = ProjectSettings.get_setting("threading/worker_pool/max_threads", -1)
	return n if n > 0 else OS.get_processor_count()


func record(result: Dictionary, label: String, image_name := "") -> void:
	var e := result.duplicate()
	e["label"] = label
	e["image"] = image_name
	e["timestamp"] = Time.get_datetime_string_from_system()
	runs.append(e)
	print("[RedSum] label=%s mode=%s threads=%d chunks=%d size=%dx%d sum=%d mean_red=%.2f ms=%.3f" % [
		label, e.mode, e.threads, e.chunks, e.width, e.height, e.sum, e.mean_red, e.ms])


func clear() -> void:
	runs.clear()


## Writes benchmark_<stamp>.csv/.json and returns their absolute paths.
func export_files(summary: Dictionary = {}) -> PackedStringArray:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var csv_path := "%s/benchmark_%s.csv" % [DIR, stamp]
	var json_path := "%s/benchmark_%s.json" % [DIR, stamp]

	var csv := FileAccess.open(csv_path, FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(FIELDS))
	for e in runs:
		var row := PackedStringArray()
		for f in FIELDS:
			row.append(str(e.get(f, "")))
		csv.store_csv_line(row)
	csv.close()

	var json := FileAccess.open(json_path, FileAccess.WRITE)
	json.store_string(JSON.stringify({
		"engine": Engine.get_version_info().string,
		"cpu": OS.get_processor_name(),
		"logical_cores": OS.get_processor_count(),
		"summary": summary,
		"runs": runs,
	}, "  "))
	json.close()

	var out := PackedStringArray([ProjectSettings.globalize_path(csv_path), ProjectSettings.globalize_path(json_path)])
	print("[Telemetry] exported %d runs -> %s" % [runs.size(), ", ".join(out)])
	return out
