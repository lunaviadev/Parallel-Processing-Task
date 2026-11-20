extends Node

var _shot_dir := ""
var _shot_interval := 1.0
var _shot_t := 0.0
var _shot_n := 0

var _rec_dir := ""
var _rec_fps := 30.0
var _rec_next := 0.0
var _rec_n := 0
var _rec_t0 := 0
var _queue: Array = []
var _mutex := Mutex.new()
var _sem := Semaphore.new()
var _worker: Thread
var _quit := false
var _times: FileAccess
var _quit_after := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shot_dir = a.trim_prefix("--shots=")
		elif a.begins_with("--shot-interval="):
			_shot_interval = a.trim_prefix("--shot-interval=").to_float()
		elif a.begins_with("--record="):
			_rec_dir = a.trim_prefix("--record=")
		elif a.begins_with("--quit-after-seconds="):
			_quit_after = a.trim_prefix("--quit-after-seconds=").to_float()
		elif a.begins_with("--record-fps="):
			_rec_fps = a.trim_prefix("--record-fps=").to_float()
	if _shot_dir != "":
		DirAccess.make_dir_recursive_absolute(_shot_dir)
	if _rec_dir != "":
		DirAccess.make_dir_recursive_absolute(_rec_dir)
		_times = FileAccess.open(_rec_dir.path_join("frames.txt"), FileAccess.WRITE)
		var start := FileAccess.open(_rec_dir.path_join("start.txt"), FileAccess.WRITE)
		_rec_t0 = Time.get_ticks_usec()
		start.store_line("%.6f" % Time.get_unix_time_from_system())
		start.close()
		_worker = Thread.new()
		_worker.start(_encode_loop)
		print("[Capture] recording frames to %s  t0_ms=%.1f" % [_rec_dir, _rec_t0 / 1000.0])
	if _quit_after > 0.0:
		get_tree().create_timer(_quit_after, true, false, true).timeout.connect(func() -> void:
			print("[Capture] quit after %.0f s" % _quit_after)
			get_tree().quit())
	set_process(_shot_dir != "" or _rec_dir != "")


func _process(dt: float) -> void:
	if _shot_dir != "":
		_shot_t += dt
		if _shot_t >= _shot_interval:
			_shot_t = 0.0
			_shot_n += 1
			var scene_name: String = get_tree().current_scene.name if get_tree().current_scene else "none"
			get_viewport().get_texture().get_image().save_png("%s/shot_%03d_%s.png" % [_shot_dir, _shot_n, scene_name])
	if _rec_dir != "":
		var t := (Time.get_ticks_usec() - _rec_t0) / 1000000.0
		if t >= _rec_next:
			_rec_next = maxf(_rec_next + 1.0 / _rec_fps, t)
			var img := get_viewport().get_texture().get_image()
			_mutex.lock()
			_queue.append([_rec_n, t, img])
			_mutex.unlock()
			_sem.post()
			_rec_n += 1


func _encode_loop() -> void:
	while true:
		_sem.wait()
		_mutex.lock()
		var item: Variant = null if _queue.is_empty() else _queue.pop_front()
		var done := _quit and _queue.is_empty()
		_mutex.unlock()
		if item != null:
			var img: Image = item[2]
			img.save_jpg(_rec_dir.path_join("f_%06d.jpg" % item[0]), 0.92)
			_mutex.lock()
			_times.store_line("%d %.6f" % [item[0], item[1]])
			_times.flush()
			_mutex.unlock()
		if done and item == null:
			return


func _exit_tree() -> void:
	if _worker:
		_mutex.lock()
		_quit = true
		_mutex.unlock()
		_sem.post()
		while _worker.is_alive():
			_sem.post()
			OS.delay_msec(5)
		_worker.wait_to_finish()
		_times.close()
