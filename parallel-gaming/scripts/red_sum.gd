class_name RedSum
extends RefCounted
## Sums the red (R) channel of an image, either on one thread or spread across
## Godot's WorkerThreadPool (Godot's equivalent of Unity's Job System /
## Unreal's ParallelFor).
##
## Every function returns a Dictionary:
##   { mode, sum, pixels, width, height, mean_red, ms, threads, chunks }
## and, for the RGB variant, also { sum_g, sum_b }.


## One unit of parallel work. The image bytes are shared read-only by every
## worker; each chunk (a band of rows) accumulates into a local variable and
## writes its partial result exactly once, so workers never contend while
## summing.
class _Job:
	extends RefCounted

	var data: PackedByteArray
	var row_bytes: int
	var height: int
	var rows_per_chunk: int
	var partials_r: PackedInt64Array
	var partials_g: PackedInt64Array
	var partials_b: PackedInt64Array
	var mutex := Mutex.new()

	func _range(chunk: int) -> Vector2i:
		var start_row := chunk * rows_per_chunk
		var end_row := mini(start_row + rows_per_chunk, height)
		return Vector2i(start_row * row_bytes, end_row * row_bytes)

	func run_chunk_red(chunk: int) -> void:
		var r := _range(chunk)
		# Local copy (copy-on-write, no real copy): telemetry showed member
		# access in the hot loop made 1-thread "parallel" ~50% slower than single.
		var d := data
		var s := 0
		for i in range(r.x, r.y, 4):
			s += d[i]
		mutex.lock()
		partials_r[chunk] = s
		mutex.unlock()

	func run_chunk_rgb(chunk: int) -> void:
		var r := _range(chunk)
		var sr := 0
		var sg := 0
		var sb := 0
		var d := data
		for i in range(r.x, r.y, 4):
			sr += d[i]
			sg += d[i + 1]
			sb += d[i + 2]
		mutex.lock()
		partials_r[chunk] = sr
		partials_g[chunk] = sg
		partials_b[chunk] = sb
		mutex.unlock()


## Returns an RGBA8, uncompressed version of the image (copying only if needed)
## so every pixel is exactly 4 bytes and byte 0 of each pixel is red.
static func to_rgba8(img: Image) -> Image:
	if img.get_format() == Image.FORMAT_RGBA8 and not img.is_compressed():
		return img
	var copy := img.duplicate() as Image
	if copy.is_compressed():
		copy.decompress()
	copy.convert(Image.FORMAT_RGBA8)
	return copy


## Baseline: one tight loop on the calling thread.
static func sum_single(img: Image) -> Dictionary:
	var src := to_rgba8(img)
	var t0 := Time.get_ticks_usec()
	var data := src.get_data()
	var s := 0
	for i in range(0, data.size(), 4):
		s += data[i]
	var us := Time.get_ticks_usec() - t0
	return _result("single", src, s, us, 1, 1)


## Parallel: rows are split into `chunks` bands, executed by up to
## `max_threads` pool workers. Defaults: all logical cores, 4 chunks per thread
## (small enough bands for load balancing, large enough to hide task overhead).
static func sum_parallel(img: Image, max_threads := -1, chunks := -1) -> Dictionary:
	var src := to_rgba8(img)
	var t0 := Time.get_ticks_usec()
	var job := _make_job(src, max_threads, chunks)
	var threads: int = job.get_meta("threads")
	var n := job.partials_r.size()
	var gid := WorkerThreadPool.add_group_task(job.run_chunk_red, n, threads, true, "RedSum red")
	WorkerThreadPool.wait_for_group_task_completion(gid)
	var s := 0
	for p in job.partials_r:
		s += p
	var us := Time.get_ticks_usec() - t0
	return _result("parallel", src, s, us, threads, n)


## Parallel R, G and B in a single pass over memory (optional extension).
static func sum_rgb_parallel(img: Image, max_threads := -1, chunks := -1) -> Dictionary:
	var src := to_rgba8(img)
	var t0 := Time.get_ticks_usec()
	var job := _make_job(src, max_threads, chunks)
	var threads: int = job.get_meta("threads")
	var n := job.partials_r.size()
	job.partials_g.resize(n)
	job.partials_b.resize(n)
	var gid := WorkerThreadPool.add_group_task(job.run_chunk_rgb, n, threads, true, "RedSum rgb")
	WorkerThreadPool.wait_for_group_task_completion(gid)
	var sr := 0
	var sg := 0
	var sb := 0
	for c in n:
		sr += job.partials_r[c]
		sg += job.partials_g[c]
		sb += job.partials_b[c]
	var us := Time.get_ticks_usec() - t0
	var res := _result("parallel_rgb", src, sr, us, threads, n)
	res["sum_g"] = sg
	res["sum_b"] = sb
	return res


static func _make_job(src: Image, max_threads: int, chunks: int) -> _Job:
	var threads := max_threads if max_threads > 0 else OS.get_processor_count()
	var h := src.get_height()
	var n := chunks if chunks > 0 else threads * 4
	n = clampi(n, 1, h)
	var job := _Job.new()
	job.data = src.get_data()
	job.row_bytes = src.get_width() * 4
	job.height = h
	job.rows_per_chunk = ceili(float(h) / n)
	n = ceili(float(h) / job.rows_per_chunk)  # drop empty trailing chunks
	job.partials_r.resize(n)
	job.set_meta("threads", threads)
	return job


static func _result(mode: String, src: Image, s: int, us: int, threads: int, chunks: int) -> Dictionary:
	var px := src.get_width() * src.get_height()
	return {
		"mode": mode,
		"sum": s,
		"pixels": px,
		"width": src.get_width(),
		"height": src.get_height(),
		"mean_red": float(s) / maxi(px, 1),
		"ms": us / 1000.0,
		"threads": threads,
		"chunks": chunks,
	}
