class_name RedSum
extends RefCounted


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


class _TileJob:
	extends RefCounted

	var data: PackedByteArray
	var width: int
	var height: int
	var cols: int
	var rows: int
	var rows_per_chunk: int
	var col_bytes: PackedInt32Array
	var row_of_y: PackedInt32Array
	var partials: PackedInt64Array
	var mutex := Mutex.new()

	func run_chunk(chunk: int) -> void:
		var d := data
		var ry := row_of_y
		var w4 := width * 4
		var c := cols
		var xs := col_bytes
		var local := PackedInt64Array()
		local.resize(c * rows)
		var y0 := chunk * rows_per_chunk
		var y1 := mini(y0 + rows_per_chunk, height)
		for y in range(y0, y1):
			var tile_row := ry[y]
			var base := y * w4
			for tc in c:
				var s := 0
				for i in range(base + xs[tc], base + xs[tc + 1], 4):
					s += d[i]
				local[tile_row * c + tc] += s
		mutex.lock()
		var off := chunk * c * rows
		for k in local.size():
			partials[off + k] = local[k]
		mutex.unlock()


static func to_rgba8(img: Image) -> Image:
	if img.get_format() == Image.FORMAT_RGBA8 and not img.is_compressed():
		return img
	var copy := img.duplicate() as Image
	if copy.is_compressed():
		copy.decompress()
	copy.convert(Image.FORMAT_RGBA8)
	return copy


static func sum_single(img: Image) -> Dictionary:
	var src := to_rgba8(img)
	var t0 := Time.get_ticks_usec()
	var data := src.get_data()
	var s := 0
	for i in range(0, data.size(), 4):
		s += data[i]
	var us := Time.get_ticks_usec() - t0
	return _result("single", src, s, us, 1, 1)


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


@warning_ignore("integer_division")
static func sum_tiles(img: Image, cols: int, rows: int, max_threads := -1, chunks := -1) -> Dictionary:
	var src := to_rgba8(img)
	var t0 := Time.get_ticks_usec()
	var w := src.get_width()
	var h := src.get_height()
	cols = clampi(cols, 1, w)
	rows = clampi(rows, 1, h)
	var threads := max_threads if max_threads > 0 else OS.get_processor_count()
	var n := clampi(chunks if chunks > 0 else threads * 2, 1, h)
	var job := _TileJob.new()
	job.data = src.get_data()
	job.width = w
	job.height = h
	job.cols = cols
	job.rows = rows
	job.rows_per_chunk = ceili(float(h) / n)
	n = ceili(float(h) / job.rows_per_chunk)
	for i in cols + 1:
		job.col_bytes.append((i * w / cols) * 4)
	job.row_of_y.resize(h)
	var row_counts := PackedInt64Array()
	row_counts.resize(rows)
	for tr in rows:
		for y in range(tr * h / rows, (tr + 1) * h / rows):
			job.row_of_y[y] = tr
		row_counts[tr] = (tr + 1) * h / rows - tr * h / rows
	var tiles := cols * rows
	job.partials.resize(n * tiles)
	var gid := WorkerThreadPool.add_group_task(job.run_chunk, n, threads, true, "RedSum tiles")
	WorkerThreadPool.wait_for_group_task_completion(gid)
	var tile_sums := PackedInt64Array()
	tile_sums.resize(tiles)
	for c in n:
		var off := c * tiles
		for k in tiles:
			tile_sums[k] += job.partials[off + k]
	var total := 0
	for v in tile_sums:
		total += v
	var us := Time.get_ticks_usec() - t0
	var tile_pixels := PackedInt64Array()
	tile_pixels.resize(tiles)
	for tr in rows:
		for tc in cols:
			tile_pixels[tr * cols + tc] = row_counts[tr] * ((tc + 1) * w / cols - tc * w / cols)
	var res := _result("parallel_tiles", src, total, us, threads, n)
	res["cols"] = cols
	res["rows"] = rows
	res["tile_sums"] = tile_sums
	res["tile_pixels"] = tile_pixels
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
	n = ceili(float(h) / job.rows_per_chunk)
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
