extends Node
## Autoload "Audio": thin wrapper over the FMOD GDExtension (utopia-rise
## fmod-gdextension). Loads the FMOD Studio banks, triggers events, drives the
## adaptive "Redness" parameter, and logs every trigger to the console and to
## user://telemetry/audio_log.csv (works in editor and in exported builds).
##
## If the FMOD addon or banks are missing the game still runs: triggers are
## logged with fmod=no so you can see what *would* have played.

const BANK_DIR := "res://banks/Desktop/"
const BANKS := ["Master.strings.bank", "Master.bank"]

const EV_MUSIC := "event:/Music/Theme"
const EV_BRUSH := "event:/SFX/Brush"
const EV_WIN := "event:/SFX/RoundEnd_Win"
const EV_LOSE := "event:/SFX/RoundEnd_Lose"
const EV_CLICK := "event:/UI/Click"
const PARAM_REDNESS := "Redness"

const LOAD_BANK_NORMAL := 0   # FMOD_STUDIO_LOAD_BANK_NORMAL
const STOP_ALLOWFADEOUT := 0  # FMOD_STUDIO_STOP_ALLOWFADEOUT

var available := false
var status := "FMOD not checked"
var trigger_counts := {}

var _fmod: Object = null
var _banks: Array = []
var _music: Object = null
var _last_redness_bucket := -1
var _log: FileAccess


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute("user://telemetry")
	_log = FileAccess.open("user://telemetry/audio_log.csv", FileAccess.WRITE)
	_log.store_csv_line(PackedStringArray(["time_s", "event", "action", "count", "fmod", "value", "pos_x", "pos_y", "build"]))
	_init_fmod()
	print("[Audio] %s  (log: %s)" % [status, ProjectSettings.globalize_path("user://telemetry/audio_log.csv")])


func _init_fmod() -> void:
	if not Engine.has_singleton("FmodServer"):
		status = "FMOD addon not installed - events are logged only"
		return
	_fmod = Engine.get_singleton("FmodServer")
	for b in BANKS:
		var path: String = BANK_DIR + b
		if not FileAccess.file_exists(path):
			status = "FMOD ready but bank missing: " + path
			return
		var bank: Object = _fmod.load_bank(path, LOAD_BANK_NORMAL)
		if bank == null:
			status = "FMOD failed to load " + path
			return
		_banks.append(bank)  # keep a reference or the bank unloads
	available = true
	if _fmod.has_method("check_event_path") and not _fmod.check_event_path(EV_MUSIC):
		status = "FMOD banks loaded, but %s not found (check event names)" % EV_MUSIC
	else:
		status = "FMOD ready - %d banks loaded" % _banks.size()


func play_one_shot(event_path: String, pos := Vector2.ZERO) -> void:
	_record(event_path, "one_shot", pos)
	if available:
		_fmod.play_one_shot(event_path)


func start_music() -> void:
	if _music != null:
		return
	_record(EV_MUSIC, "start")
	if available:
		_music = _fmod.create_event_instance(EV_MUSIC)
		if _music != null:
			_music.start()


func stop_music() -> void:
	if _music == null:
		return
	_record(EV_MUSIC, "stop")
	_music.stop(STOP_ALLOWFADEOUT)
	_music.release()
	_music = null


## 0..1. Sent to FMOD every call; logged when it crosses a 10% step.
func set_redness(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if _music != null:
		_music.set_parameter_by_name(PARAM_REDNESS, value)
	var bucket := int(value * 10.0)
	if bucket != _last_redness_bucket:
		_last_redness_bucket = bucket
		_record(PARAM_REDNESS, "param", Vector2.ZERO, value)


func _record(event_path: String, action: String, pos := Vector2.ZERO, value := 0.0) -> void:
	var key := event_path + ":" + action
	trigger_counts[key] = int(trigger_counts.get(key, 0)) + 1
	var t := Time.get_ticks_msec() / 1000.0
	var build := "editor" if OS.has_feature("editor") else "export"
	print("[Audio] t=%.2fs event=%s action=%s count=%d fmod=%s value=%.2f pos=(%d,%d) build=%s" % [
		t, event_path, action, trigger_counts[key], "yes" if available else "no", value, pos.x, pos.y, build])
	if _log:
		_log.store_csv_line(PackedStringArray([
			"%.3f" % t, event_path, action, str(trigger_counts[key]), "yes" if available else "no",
			"%.3f" % value, str(int(pos.x)), str(int(pos.y)), build]))
		_log.flush()


func _exit_tree() -> void:
	stop_music()
