extends SceneTree

## Phase 16C-4: Complete Deck/GY devices — bright anime-real style
## Run: Godot --headless --path . --script res://tools/gen_final_art_p2.gd

const OUT := "res://assets/table/final"

# Bright palette
const STONE_BRIGHT := Color(0.62, 0.60, 0.57)
const STONE_MID := Color(0.48, 0.46, 0.44)
const IRON := Color(0.16, 0.15, 0.14)
const IRON_LIGHT := Color(0.24, 0.22, 0.20)
const BRASS := Color(0.65, 0.48, 0.22)
const BRASS_LIGHT := Color(0.78, 0.60, 0.30)
const CYAN := Color(0.15, 0.68, 0.80)
const CYAN_GLOW := Color(0.25, 0.78, 0.88)
const ORANGE := Color(0.75, 0.35, 0.10)
const PURPLE_DIM := Color(0.38, 0.12, 0.35)

func _init() -> void:
	print("[GenFinal P2] Generating 4 Deck/GY devices...")
	DirAccess.make_dir_recursive_absolute(OUT)

	gen_deck_box("deck_box_player_placeholder", CYAN)
	gen_deck_box("deck_box_boss_placeholder", ORANGE)
	gen_gy_box("graveyard_box_player_placeholder", CYAN)
	gen_gy_box("graveyard_box_boss_placeholder", ORANGE)

	print("[GenFinal P2] Done — 4 PNGs")
	quit()


func gen_deck_box(name: String, accent: Color) -> void:
	var w := 72; var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.0))

	# Stone base (bottom half)
	for x in range(w):
		for y in range(h - 22, h):
			var c := STONE_BRIGHT.lerp(STONE_MID, float(y - (h - 22)) / 22.0)
			c.a = 0.95
			img.set_pixel(x, y, c)

	# Iron card box body
	for x in range(6, w - 6):
		for y in range(8, h - 24):
			var fy := float(y - 8) / float(h - 32)
			var c := IRON.lerp(IRON_LIGHT, fy)
			c.a = 0.95
			img.set_pixel(x, y, c)

	# Card slot opening (top)
	for x in range(14, w - 14):
		for y in range(4, 12):
			var c := Color(0.05, 0.04, 0.04, 0.85)
			img.set_pixel(x, y, c)

	# Brass trim
	for x in range(5, w - 5):
		for y in range(6, 10):
			img.set_pixel(x, y, BRASS)
	# Bottom brass
	for x in range(5, w - 5):
		for y in range(h - 26, h - 22):
			img.set_pixel(x, y, BRASS)

	# OD indicator light
	var lx := 36; var ly := 18
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if dx*dx + dy*dy <= 5:
				var c := accent; c.a = 0.8
				var existing := img.get_pixel(lx + dx, ly + dy)
				img.set_pixel(lx + dx, ly + dy, existing.lerp(c, 0.7))

	# Side rivets
	for ry in [30, 55]:
		for side in [8, w - 9]:
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx*dx + dy*dy <= 2:
						img.set_pixel(side + dx, ry + dy, BRASS_LIGHT)

	img.save_png(OUT + "/%s.png" % name)
	print("  %s.png (%dx%d)" % [name, w, h])


func gen_gy_box(name: String, accent: Color) -> void:
	var w := 72; var h := 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.0))

	# Darker stone base
	for x in range(w):
		for y in range(h):
			var c := STONE_MID.lerp(Color(0.30, 0.28, 0.27), float(y) / float(h))
			c.a = 0.92
			img.set_pixel(x, y, c)

	# Dark iron casing
	for x in range(5, w - 5):
		for y in range(6, h - 6):
			img.set_pixel(x, y, IRON)

	# Edge glow (purple-cyan for GY, indicating "回收/墓地")
	var glow_color := PURPLE_DIM.lerp(accent, 0.3)
	for x in range(w):
		for y in range(h):
			if x < 5 or x >= w - 5 or y < 6 or y >= h - 6:
				var existing := img.get_pixel(x, y)
				img.set_pixel(x, y, existing.lerp(glow_color, 0.4))

	# Brass corner rivets
	for cx in [7, w - 8]:
		for cy in [8, h - 9]:
			for dx in range(-2, 3):
				for dy in range(-2, 3):
					if dx*dx + dy*dy <= 3:
						img.set_pixel(cx + dx, cy + dy, BRASS)

	# Small indicator
	var lx := 36; var ly := 14
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx*dx + dy*dy <= 2:
				var c := accent; c.a = 0.55
				var existing := img.get_pixel(lx + dx, ly + dy)
				img.set_pixel(lx + dx, ly + dy, existing.lerp(c, 0.6))

	img.save_png(OUT + "/%s.png" % name)
	print("  %s.png (%dx%d)" % [name, w, h])
