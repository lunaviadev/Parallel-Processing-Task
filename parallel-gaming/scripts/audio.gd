extends Node

const BANK_DIR := "res://banks/Desktop/"
const BANKS := ["Master.strings.bank", "Master.bank"]

const EV_MUSIC := "event:/Music/Theme"
const EV_DESKTOP_MUSIC := "event:/Music/Desktop"
const EV_BRUSH := "event:/SFX/Brush"
const EV_TILE_MATCH := "event:/SFX/TileMatch"
const EV_TILE_LOST := "event:/SFX/TileLost"
const EV_BLOB_SPAWN := "event:/SFX/BlobSpawn"
const EV_BLOB_POP := "event:/SFX/BlobPop"
const EV_BOARD_CLEAR := "event:/SFX/BoardClear"
const EV_BOARD_FAIL := "event:/SFX/BoardFail"
const EV_TICK := "event:/SFX/TimeWarning"
const EV_WIN := "event:/SFX/RoundEnd_Win"
const EV_LOSE := "event:/SFX/RoundEnd_Lose"
const EV_CLICK := "event:/UI/Click"
const EV_HOVER := "event:/UI/Hover"
const EV_STARTUP := "event:/UI/Startup"
const EV_WINDOW_OPEN := "event:/UI/WindowOpen"
const EV_WINDOW_CLOSE := "event:/UI/WindowClose"
const EV_NOTIFY := "event:/UI/Notify"
const EV_ERROR := "event:/UI/Error"
const EV_BUBBLE_SPAWN := "event:/SFX/BubbleSpawn"
const EV_POWER := {
	"freeze": "event:/SFX/PowerFreeze",
	"bucket": "event:/SFX/PowerBucket",
	"mega": "event:/SFX/PowerMega",
	"rinse": "event:/SFX/PowerRinse",
	"time": "event:/SFX/PowerTime",
}
const EV_BUCKET_FILL := "event:/SFX/BucketFill"
const EV_TILE_SHIFT := "event:/SFX/TileShift"
const EV_PERFECT := "event:/SFX/Perfect"
const SNAP_PAUSE := "snapshot:/Pause"
const SNAP_FREEZE := "snapshot:/Freeze"
const VCA_MUSIC := "vca:/Music"
const VCA_SFX := "vca:/SFX"

const PARAM_REDNESS := "Redness"
const PARAM_INTENSITY := "Intensity"
const PARAM_COMBO := "Combo"
const PARAM_PAN := "Pan"
const PARAM_MODE := "Mode"

const ALL_EVENTS := [EV_MUSIC, EV_DESKTOP_MUSIC, EV_BRUSH, EV_TILE_MATCH, EV_TILE_LOST, EV_BLOB_SPAWN, EV_BLOB_POP,
		EV_BOARD_CLEAR, EV_BOARD_FAIL, EV_TICK, EV_WIN, EV_LOSE, EV_CLICK, EV_HOVER, EV_STARTUP, EV_WINDOW_OPEN,
		EV_WINDOW_CLOSE, EV_NOTIFY, EV_ERROR, EV_BUBBLE_SPAWN, "event:/SFX/PowerFreeze", "event:/SFX/PowerBucket",
		"event:/SFX/PowerMega", "event:/SFX/PowerRinse", "event:/SFX/PowerTime", EV_BUCKET_FILL, EV_TILE_SHIFT,
		EV_PERFECT, SNAP_PAUSE, SNAP_FREEZE]

const LOAD_BANK_NORMAL := 0
const STOP_ALLOWFADEOUT := 0
const PERF_INTERVAL := 1.0

var available := false
var status := "FMOD not checked"
var missing_events: PackedStringArray = []
var trigger_counts := {}
var total_triggers := 0
var music_params := {PARAM_REDNESS: 0.0, PARAM_INTENSITY: 0.0, PARAM_MODE: 0.0}
var music_kind := ""
var last_perf := {}
var driver_name := ""

var _fmod: Object = null
var _banks: Array = []
var _music: Object = null
var _pause_snap: Object = null
var _freeze_snap: Object = null
var _vcas := {}
var _param_buckets := {}
var _log: FileAccess
var _perf_log: FileAccess
var _perf_t := 0.0
var session_stamp := Time.get_datetime_string_from_system().replace(":", "-")
var _hover_cooldown := 0.0
var _hud: Label
var _hud_layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute("user://telemetry")
	_log = FileAccess.open("user://telemetry/audio_log_%s.csv" % session_stamp, FileAccess.WRITE)
	_log.store_csv_line(PackedStringArray(["time_s", "event", "action", "count", "fmod", "value", "pos_x", "pos_y", "build"]))
	_init_fmod()
	_build_hud()
	print("[Audio] %s  (log: %s)" % [status, ProjectSettings.globalize_path("user://telemetry/audio_log_%s.csv" % session_stamp)])
	if available:
		print("[Audio] driver=\"%s\" events_ok=%d/%d" % [driver_name, ALL_EVENTS.size() - missing_events.size(), ALL_EVENTS.size()])


func _init_fmod() -> void:
	if not Engine.has_singleton("FmodServer"):
		status = "FMOD addon not installed - events are logged only"
		return
	_fmod = Engine.get_singleton("FmodServer")
	_select_driver()
	for b in BANKS:
		var path: String = BANK_DIR + b
		if not FileAccess.file_exists(path):
			status = "FMOD ready but bank missing: " + path
			return
		var bank: Object = _fmod.load_bank(path, LOAD_BANK_NORMAL)
		if bank == null:
			status = "FMOD failed to load " + path
			return
		_banks.append(bank)
	available = true
	for ev: String in ALL_EVENTS:
		if not _fmod.check_event_path(ev):
			missing_events.append(ev)
	for v: String in [VCA_MUSIC, VCA_SFX]:
		if _fmod.check_vca_path(v):
			_vcas[v] = _fmod.get_vca(v)
	if missing_events.is_empty():
		status = "FMOD ready - %d banks, %d events" % [_banks.size(), ALL_EVENTS.size()]
	else:
		status = "FMOD ready - missing %s" % ", ".join(missing_events)
	set_vca_volume(VCA_MUSIC, UI.cfg_get("audio", "music", 0.8))
	set_vca_volume(VCA_SFX, UI.cfg_get("audio", "sfx", 0.9))
	_perf_log = FileAccess.open("user://telemetry/fmod_perf_%s.csv" % session_stamp, FileAccess.WRITE)


func _select_driver() -> void:
	var wanted := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fmod-driver="):
			wanted = a.trim_prefix("--fmod-driver=").to_lower()
	var drivers: Array = _fmod.get_available_drivers()
	var current: int = _fmod.get_driver()
	if wanted != "":
		for i in drivers.size():
			if str(drivers[i].get("name", "")).to_lower().contains(wanted):
				_fmod.set_driver(i)
				current = i
				break
	if current >= 0 and current < drivers.size():
		driver_name = str(drivers[current].get("name", ""))


func play(event_path: String, params := {}, pos := Vector2.ZERO) -> void:
	_record(event_path, "one_shot", pos, float(params.values()[0]) if not params.is_empty() else 0.0)
	if not available or event_path in missing_events:
		return
	if params.is_empty():
		_fmod.play_one_shot(event_path)
	else:
		_fmod.play_one_shot_with_params(event_path, params)


func play_one_shot(event_path: String, pos := Vector2.ZERO) -> void:
	play(event_path, {}, pos)


func play_panned(event_path: String, x01: float, pos := Vector2.ZERO, extra := {}) -> void:
	var params := {PARAM_PAN: clampf(x01 * 2.0 - 1.0, -1.0, 1.0)}
	params.merge(extra)
	play(event_path, params, pos)


func hover() -> void:
	if _hover_cooldown <= 0.0:
		_hover_cooldown = 0.06
		play(EV_HOVER)


func start_music() -> void:
	play_music("game")


func play_music(kind: String) -> void:
	if kind == "zen":
		set_music_param(PARAM_MODE, 1.0)
	elif kind == "game":
		set_music_param(PARAM_MODE, 0.0)
	var path := EV_DESKTOP_MUSIC if kind == "desktop" else EV_MUSIC
	var current := EV_DESKTOP_MUSIC if music_kind == "desktop" else EV_MUSIC
	if _music != null and path == current:
		music_kind = kind
		return
	stop_music()
	music_kind = kind
	_record(path, "start", Vector2.ZERO, music_params[PARAM_MODE])
	if available and not path in missing_events:
		_music = _fmod.create_event_instance(path)
		if _music != null:
			if path == EV_MUSIC:
				for k: String in music_params:
					_music.set_parameter_by_name(k, music_params[k])
			_music.start()


func stop_music() -> void:
	if _music == null:
		music_kind = ""
		return
	_record(EV_DESKTOP_MUSIC if music_kind == "desktop" else EV_MUSIC, "stop")
	_music.stop(STOP_ALLOWFADEOUT)
	_music.release()
	_music = null
	music_kind = ""


func set_redness(value: float) -> void:
	set_music_param(PARAM_REDNESS, value)


func set_intensity(value: float) -> void:
	set_music_param(PARAM_INTENSITY, value)


func set_music_param(param: String, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	music_params[param] = value
	if _music != null and music_kind != "desktop":
		_music.set_parameter_by_name(param, value)
	var bucket := int(value * 10.0)
	if bucket != int(_param_buckets.get(param, -1)):
		_param_buckets[param] = bucket
		_record(param, "param", Vector2.ZERO, value)


func set_paused_mix(paused: bool) -> void:
	_pause_snap = _snapshot(SNAP_PAUSE, _pause_snap, paused)


func set_freeze_mix(on: bool) -> void:
	_freeze_snap = _snapshot(SNAP_FREEZE, _freeze_snap, on)


func _snapshot(path: String, inst: Object, on: bool) -> Object:
	if on and inst == null:
		_record(path, "start")
		if available and not path in missing_events:
			inst = _fmod.create_event_instance(path)
			if inst:
				inst.start()
			return inst
		return null
	if not on and inst != null:
		_record(path, "stop")
		inst.stop(STOP_ALLOWFADEOUT)
		inst.release()
		return null
	return inst


func set_vca_volume(vca_path: String, v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	if _vcas.has(vca_path):
		_vcas[vca_path].volume = v


func _record(event_path: String, action: String, pos := Vector2.ZERO, value := 0.0) -> void:
	var key := event_path + ":" + action
	trigger_counts[key] = int(trigger_counts.get(key, 0)) + 1
	total_triggers += 1
	var t := Time.get_ticks_msec() / 1000.0
	var build := "editor" if OS.has_feature("editor") else "export"
	print("[Audio] t=%.2fs event=%s action=%s count=%d fmod=%s value=%.2f pos=(%d,%d) build=%s" % [
		t, event_path, action, trigger_counts[key], "yes" if available else "no", value, pos.x, pos.y, build])
	if _log:
		_log.store_csv_line(PackedStringArray([
			"%.3f" % t, event_path, action, str(trigger_counts[key]), "yes" if available else "no",
			"%.3f" % value, str(int(pos.x)), str(int(pos.y)), build]))
		_log.flush()


func _process(dt: float) -> void:
	_hover_cooldown -= dt
	_perf_t += dt
	if available and _perf_t >= PERF_INTERVAL:
		_perf_t = 0.0
		_sample_perf()
	if _hud_layer.visible:
		_update_hud()


const PERF_FIELDS := ["dsp", "stream", "update", "studio", "geometry", "currently_allocated", "max_allocated", "sample_bytes_read", "stream_bytes_read"]


func _sample_perf() -> void:
	var pd: Object = _fmod.get_performance_data()
	if pd == null:
		return
	var flat := {}
	for f: String in PERF_FIELDS:
		flat[f] = pd.get(f)
	last_perf = flat
	if _perf_log:
		if _perf_log.get_position() == 0:
			var head := PackedStringArray(["time_s", "triggers", "music_redness", "music_intensity"])
			head.append_array(PackedStringArray(PERF_FIELDS))
			_perf_log.store_csv_line(head)
		var row := PackedStringArray(["%.2f" % (Time.get_ticks_msec() / 1000.0), str(total_triggers),
				"%.3f" % music_params[PARAM_REDNESS], "%.3f" % music_params[PARAM_INTENSITY]])
		for f: String in PERF_FIELDS:
			row.append(str(flat[f]))
		_perf_log.store_csv_line(row)
		_perf_log.flush()


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 100
	_hud_layer.visible = false
	add_child(_hud_layer)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "DarkPanel"
	panel.position = Vector2(12, 12)
	_hud_layer.add_child(panel)
	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 13)
	_hud.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9))
	panel.add_child(_hud)


func _update_hud() -> void:
	var lines := PackedStringArray()
	lines.append("FMOD TELEMETRY  (F3)   %s" % status)
	lines.append("driver: %s   build: %s" % [driver_name, "editor" if OS.has_feature("editor") else "export"])
	lines.append("music: %s   Redness %.2f   Intensity %.2f   Mode %.0f" % [
		music_kind if _music else "stopped", music_params[PARAM_REDNESS], music_params[PARAM_INTENSITY], music_params[PARAM_MODE]])
	lines.append("snapshots: Pause %s   Freeze %s" % ["on" if _pause_snap else "off", "on" if _freeze_snap else "off"])
	if not last_perf.is_empty():
		lines.append("CPU %%  dsp %.2f  stream %.2f  update %.2f  studio %.2f" % [
			last_perf.dsp, last_perf.stream, last_perf.update, last_perf.studio])
		lines.append("memory  %.2f MB now   %.2f MB peak" % [
			last_perf.currently_allocated / 1048576.0, last_perf.max_allocated / 1048576.0])
	lines.append("triggers total: %d" % total_triggers)
	var keys := trigger_counts.keys()
	keys.sort()
	for k: String in keys:
		lines.append("  %-40s %d" % [k, trigger_counts[k]])
	_hud.text = "\n".join(lines)


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F3:
		_hud_layer.visible = not _hud_layer.visible


func _exit_tree() -> void:
	set_paused_mix(false)
	set_freeze_mix(false)
	stop_music()
