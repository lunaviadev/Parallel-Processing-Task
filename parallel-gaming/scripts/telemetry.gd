extends Node

const DIR := "user://telemetry"
const FIELDS := ["timestamp", "label", "image", "mode", "threads", "chunks", "width", "height",
		"pixels", "sum", "mean_red", "ms"]

var runs: Array[Dictionary] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	print("[Telemetry] cpu=%s logical cores=%d  pool threads=%d  user dir=%s" % [
		OS.get_processor_name(), OS.get_processor_count(), pool_threads(), ProjectSettings.globalize_path(DIR)])


static func pool_threads() -> int:
	var n: int = ProjectSettings.get_setting("threading/worker_pool/max_threads", -1)
	return n if n > 0 else OS.get_processor_count()


func record(result: Dictionary, label: String, image_name := "") -> void:
	var e := result.duplicate()
	e.erase("tile_sums")
	e.erase("tile_pixels")
	e["label"] = label
	e["image"] = image_name
	e["timestamp"] = Time.get_datetime_string_from_system()
	runs.append(e)
	print("[RedSum] label=%s mode=%s threads=%d chunks=%d size=%dx%d sum=%d mean_red=%.2f ms=%.3f" % [
		label, e.mode, e.threads, e.chunks, e.width, e.height, e.sum, e.mean_red, e.ms])


func clear() -> void:
	runs.clear()


func _stamp() -> String:
	return Time.get_datetime_string_from_system().replace(":", "-")


func _system_info() -> Dictionary:
	return {
		"engine": Engine.get_version_info().string,
		"cpu": OS.get_processor_name(),
		"logical_cores": OS.get_processor_count(),
		"pool_threads": pool_threads(),
		"build": "editor" if OS.has_feature("editor") else "export",
	}


func export_files(summary: Dictionary = {}) -> PackedStringArray:
	var stamp := _stamp()
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

	var doc := _system_info()
	doc["summary"] = summary
	doc["runs"] = runs
	var json := FileAccess.open(json_path, FileAccess.WRITE)
	json.store_string(JSON.stringify(doc, "  "))
	json.close()

	var out := PackedStringArray([ProjectSettings.globalize_path(csv_path), ProjectSettings.globalize_path(json_path)])
	print("[Telemetry] exported %d runs -> %s" % [runs.size(), ", ".join(out)])
	return out


func export_game_session(stats: Dictionary) -> String:
	var path := "%s/game_session_%s.json" % [DIR, _stamp()]
	var doc := _system_info()
	doc["session"] = stats
	doc["audio_trigger_counts"] = Audio.trigger_counts
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	return ProjectSettings.globalize_path(path)
