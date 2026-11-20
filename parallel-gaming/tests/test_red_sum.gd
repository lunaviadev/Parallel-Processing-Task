extends SceneTree


func _init() -> void:
	var failures := 0
	var img := Image.create_empty(301, 199, false, Image.FORMAT_RGBA8)
	img.fill(Color8(10, 50, 90))
	img.fill_rect(Rect2i(0, 0, 100, 100), Color8(255, 0, 0))
	var expected := 10 * (301 * 199 - 100 * 100) + 255 * 100 * 100

	var cases: Array[Dictionary] = [RedSum.sum_single(img)]
	for t in [1, 2, 4, 16]:
		cases.append(RedSum.sum_parallel(img, t))
	cases.append(RedSum.sum_parallel(img, 8, 7))
	cases.append(RedSum.sum_parallel(img, 8, 1000))
	var rgb := RedSum.sum_rgb_parallel(img)
	cases.append(rgb)
	for grid in [1, 2, 3, 4, 7]:
		cases.append(RedSum.sum_tiles(img, grid, grid))
	cases.append(RedSum.sum_tiles(img, 5, 2, 3, 11))

	for c in cases:
		var ok: bool = c.sum == expected
		failures += 0 if ok else 1
		print("%s %-14s threads=%2d chunks=%3d sum=%d" % ["PASS" if ok else "FAIL", c.mode, c.threads, c.chunks, c.sum])

	var exp_g := 50 * (301 * 199 - 100 * 100)
	var exp_b := 90 * (301 * 199 - 100 * 100)
	if rgb.sum_g != exp_g or rgb.sum_b != exp_b:
		failures += 1
		print("FAIL rgb G/B sums: %d %d" % [rgb.sum_g, rgb.sum_b])

	for grid: int in [2, 3, 4, 5]:
		var t := RedSum.sum_tiles(img, grid, grid, 6)
		var ok := true
		var px_total := 0
		for tr in grid:
			for tc in grid:
				var rect := Rect2i(tc * 301 / grid, tr * 199 / grid, (tc + 1) * 301 / grid - tc * 301 / grid, (tr + 1) * 199 / grid - tr * 199 / grid)
				var ref: int = 0
				var data := img.get_region(rect).get_data()
				for i in range(0, data.size(), 4):
					ref += data[i]
				var k: int = tr * grid + tc
				px_total += t.tile_pixels[k]
				if t.tile_sums[k] != ref or t.tile_pixels[k] != rect.size.x * rect.size.y:
					ok = false
		if px_total != 301 * 199:
			ok = false
		failures += 0 if ok else 1
		print("%s tiles %dx%d match per-tile reference" % ["PASS" if ok else "FAIL", grid, grid])

	var rgb8 := img.duplicate() as Image
	rgb8.convert(Image.FORMAT_RGB8)
	if RedSum.sum_parallel(rgb8).sum != expected:
		failures += 1
		print("FAIL RGB8 conversion")

	var big := Image.create_empty(2048, 2048, false, Image.FORMAT_RGBA8)
	big.fill(Color8(200, 0, 0))
	var s := RedSum.sum_single(big)
	var p := RedSum.sum_parallel(big)
	if s.sum != p.sum or s.sum != 200 * 2048 * 2048:
		failures += 1
	print("2048x2048: single %.2f ms, parallel(%d threads) %.2f ms, speed-up x%.2f" % [s.ms, p.threads, p.ms, s.ms / p.ms])

	print("RESULT: %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)
