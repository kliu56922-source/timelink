extends SceneTree

## Phase 16C-2: Generate P0 final art in rebased "Cloud Citadel Magitek" style
## Run: Godot --headless --path . --script res://tools/gen_final_art_p0.gd

const OUT := "res://assets/table/final"

# New palette — Cloud Citadel Magitek
const STONE_DARK := Color(0.22, 0.21, 0.20)      # wet dark stone
const STONE_MID := Color(0.31, 0.29, 0.27)       # mid stone
const STONE_LIGHT := Color(0.42, 0.40, 0.38)     # light stone
const IRON := Color(0.12, 0.11, 0.10)            # black iron
const IRON_LIGHT := Color(0.18, 0.17, 0.16)      # lighter iron
const BRASS := Color(0.55, 0.40, 0.18)           # brass
const BRASS_DARK := Color(0.35, 0.25, 0.10)      # dark brass
const CYAN := Color(0.10, 0.55, 0.65)            # OD cyan energy
const CYAN_DIM := Color(0.05, 0.30, 0.40)        # dim cyan
const ORANGE := Color(0.60, 0.25, 0.08)          # heat orange
const ORANGE_DIM := Color(0.35, 0.12, 0.04)      # dim orange
const PURPLE := Color(0.40, 0.08, 0.35)          # depth purple

func _init() -> void:
	print("[GenFinal P0] Generating 5 rebased table art assets...")
	DirAccess.make_dir_recursive_absolute(OUT)

	gen_table_base()
	gen_table_frame()
	gen_engine_gauge()
	gen_boss_core()
	gen_depth_crack()

	print("[GenFinal P0] Done — 5 PNGs in %s" % OUT)
	quit()


func gen_table_base() -> void:
	var img := Image.create(1600, 900, false, Image.FORMAT_RGBA8)
	# Dark wet stone base
	for y in range(900):
		for x in range(1600):
			var fx := float(x) / 1600.0
			var fy := float(y) / 900.0
			# Stone with slight horizontal grain
			var noise := sin(fx * 80.0) * 0.03 + sin(fy * 60.0) * 0.02
			var base := STONE_DARK.lerp(STONE_MID, fy * 0.5 + noise)
			img.set_pixel(x, y, base)

	# Iron frame border (8px, darker at bottom)
	var border := 8
	for x in range(1600):
		for y in range(900):
			if x < border or x >= 1600 - border or y < border or y >= 900 - border:
				var edge := IRON
				if y >= 900 - border: edge = IRON_LIGHT
				img.set_pixel(x, y, edge)

	# Center OD energy line (thin cyan, center horizontal)
	var center_y := 450
	for x in range(200, 1400):
		var glow: float = abs(x - 800.0) / 800.0  # brightest at center
		var alpha: float = 0.5 * (1.0 - glow) * (1.0 - glow)
		for dy in range(-3, 4):
			var c := img.get_pixel(x, center_y + dy)
			var od_color := CYAN
			od_color.a = alpha * (1.0 - abs(float(dy)) / 4.0)
			img.set_pixel(x, center_y + dy, c.lerp(od_color, od_color.a))

	# Boss side warm tint (top third, subtle)
	for x in range(1600):
		for y in range(0, 300):
			var c := img.get_pixel(x, y)
			var warm := ORANGE_DIM
			warm.a = (1.0 - float(y) / 300.0) * 0.08
			img.set_pixel(x, y, c.lerp(warm, warm.a))

	# Brass corner rivets
	for corner in [[border+4,border+4], [1592-border,border+4], [border+4,892], [1592-border,892]]:
		for dx in range(-4, 5):
			for dy in range(-4, 5):
				if dx*dx + dy*dy <= 20:
					img.set_pixel(corner[0]+dx, corner[1]+dy, BRASS)

	img.save_png(OUT + "/table_base_placeholder.png")
	print("  table_base_placeholder.png (1600x900)")


func gen_table_frame() -> void:
	var img := Image.create(1600, 900, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.0))  # transparent center

	var frame_w := 14
	for x in range(1600):
		for y in range(900):
			var on_edge := x < frame_w or x >= 1600 - frame_w or y < frame_w or y >= 900 - frame_w
			if not on_edge: continue
			var alpha: float = 1.0
			# Inner fade
			if x >= frame_w - 4 and x < frame_w: alpha = 0.3 + float(x - frame_w + 4) / 4.0 * 0.7
			if x >= 1600 - frame_w and x < 1600 - frame_w + 4: alpha = 0.3 + float(1600 - frame_w + 4 - x) / 4.0 * 0.7
			var c := IRON
			c.a = alpha
			img.set_pixel(x, y, c)

	# Brass corner accents
	for i in range(2):
		var cx := 30 if i == 0 else 1570
		for cy in [30, 870]:
			for dx in range(-8, 9):
				for dy in range(-8, 9):
					var rad := dx*dx + dy*dy
					if rad <= 48 and img.get_pixel(cx+dx, cy+dy).a > 0.5:
						img.set_pixel(cx+dx, cy+dy, BRASS_DARK)

	# Small cyan conduit ports at corners
	for i in range(2):
		var cx := 18 if i == 0 else 1582
		for cy in [18, 882]:
			for dx in range(-3, 4):
				for dy in range(-3, 4):
					if dx*dx + dy*dy <= 9:
						var c := CYAN_DIM; c.a = 0.6
						img.set_pixel(cx+dx, cy+dy, c)

	img.save_png(OUT + "/table_frame_placeholder.png")
	print("  table_frame_placeholder.png (1600x900)")


func gen_engine_gauge() -> void:
	var w := 68; var h := 190
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.0))

	# Iron frame
	for x in range(w):
		for y in range(h):
			if x < 3 or x >= w - 3 or y < 2 or y >= h - 2:
				img.set_pixel(x, y, IRON)

	# Five horizontal slots
	var slot_h: int = 30; var gap: int = 5; var start_y: int = 6
	for li in range(5):
		var sy := start_y + li * (slot_h + gap)
		var ey := sy + slot_h
		# Brass pipe border
		for x in range(6, w - 6):
			for y in range(sy, ey):
				var is_edge := y < sy + 3 or y >= ey - 3 or x < 8 or x >= w - 8
				if is_edge:
					img.set_pixel(x, y, BRASS_DARK)
		# Cyan liquid level (varies by layer)
		var fill_h := int(slot_h * (0.3 + float(li) * 0.15))
		for x in range(8, w - 8):
			for y in range(ey - fill_h, ey - 3):
				var c := CYAN; c.a = 0.6 + float(li) * 0.1
				img.set_pixel(x, y, c)

	# Small pressure gauge at top
	for x in range(20, 48):
		for y in range(2, 10):
			if img.get_pixel(x, y).a < 0.5:
				img.set_pixel(x, y, IRON_LIGHT)

	img.save_png(OUT + "/engine_gauge_placeholder.png")
	print("  engine_gauge_placeholder.png (68x190)")


func gen_boss_core() -> void:
	var w := 200; var h := 90
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.0))

	var cx := 100; var cy := 45
	# Dark iron disc
	for x in range(w):
		for y in range(h):
			var dx := float(x - cx); var dy := float(y - cy)
			var dist := sqrt(dx*dx + dy*dy * 1.8)  # elliptical
			if dist < 38:
				var c := IRON.lerp(IRON_LIGHT, 1.0 - dist / 38.0)
				img.set_pixel(x, y, c)
			# Gear ring
			if dist >= 35 and dist <= 40:
				img.set_pixel(x, y, BRASS_DARK)
	# Orange core
	for x in range(w):
		for y in range(h):
			var dx := float(x - cx); var dy := float(y - cy)
			var dist := sqrt(dx*dx + dy*dy * 1.8)
			if dist < 12:
				var glow: float = 1.0 - dist / 12.0
				var c := ORANGE; c.a = 0.3 + glow * 0.7
				img.set_pixel(x, y, c)
			# Steam vents
			if (x < 25 or x > 175) and abs(y - cy) < 10:
				var c := Color(0.8, 0.8, 0.85, 0.15)
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(c, 0.3))

	img.save_png(OUT + "/boss_core_placeholder.png")
	print("  boss_core_placeholder.png (200x90)")


func gen_depth_crack() -> void:
	var img := Image.create(1600, 900, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.0))

	# Purple crack lines from edges inward
	var rng := RandomNumberGenerator.new()
	rng.set_seed(42)
	for _i in range(30):
		var sx := rng.randi_range(0, 1599)
		var sy := 0 if rng.randf() < 0.5 else 899
		var ex := rng.randi_range(200, 1400)
		var ey := rng.randi_range(150, 750)
		var length := rng.randi_range(80, 300)
		for t in range(length):
			var frac := float(t) / float(length)
			var x := int(lerpf(sx, ex, frac) + rng.randf_range(-3, 3))
			var y := int(lerpf(sy, ey, frac) + rng.randf_range(-2, 2))
			if x >= 0 and x < 1600 and y >= 0 and y < 900:
				var alpha: float = 0.25 * (1.0 - frac) * (0.5 + 0.5 * rng.randf())
				var c := PURPLE; c.a = alpha
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(c, alpha))

	img.save_png(OUT + "/depth_crack_placeholder.png")
	print("  depth_crack_placeholder.png (1600x900)")


func lerpf(a: float, b: float, t: float) -> float:
	return a + (b - a) * t
