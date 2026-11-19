extends SceneTree
## Writes sample PNGs to res://images/ for the Benchmark Lab.
## Run:  godot --headless --path parallel-gaming --script res://tools/generate_samples.gd

const SIZES := [512, 1024, 2048, 4096]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://images")
	for size: int in SIZES:
		var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
		var block := maxi(size / 256, 2)
		for by in range(0, size, block):
			for bx in range(0, size, block):
				var u := float(bx) / size
				var v := float(by) / size
				var r := 0.5 + 0.5 * sin(u * 9.0 + v * 4.0)
				var g := 0.5 + 0.5 * sin(v * 7.0 - u * 3.0 + 1.3)
				var b := 0.5 + 0.5 * cos((u - 0.5) * (v - 0.5) * 40.0)
				img.fill_rect(Rect2i(bx, by, block, block), Color(r, g * 0.6, b))
		var path := "res://images/sample_%d.png" % size
		img.save_png(path)
		print("wrote ", path)
	quit(0)
