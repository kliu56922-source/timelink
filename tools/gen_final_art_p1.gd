extends SceneTree

## Phase 16C-3: Generate P1 bright slot device art
## Run: Godot --headless --path . --script res://tools/gen_final_art_p1.gd

const OUT := "res://assets/table/final"

# Bright anime-real palette
const STONE_BRIGHT := Color(0.62, 0.60, 0.57)    # mist white stone
const STONE_MID := Color(0.48, 0.46, 0.44)        # mid gray stone
const STONE_DARK := Color(0.32, 0.30, 0.28)       # dark wet stone
const IRON := Color(0.16, 0.15, 0.14)             # black iron
const IRON_LIGHT := Color(0.24, 0.22, 0.20)       # lighter iron
const BRASS := Color(0.65, 0.48, 0.22)            # warm brass
const BRASS_LIGHT := Color(0.78, 0.60, 0.30)      # bright brass
const CYAN := Color(0.15, 0.68, 0.80)             # bright OD cyan
const CYAN_GLOW := Color(0.25, 0.78, 0.88)        # glowing cyan
const ORANGE := Color(0.75, 0.35, 0.10)           # heat orange
const ORANGE_GLOW := Color(0.90, 0.45, 0.15)      # glowing orange
const PURPLE := Color(0.45, 0.15, 0.40)           # depth purple
const SKY_BLUE := Color(0.55, 0.75, 0.85)         # sky reflection

func _init() -> void:
	print("[GenFinal P1] Generating 8 bright slot device assets...")
	DirAccess.make_dir_recursive_absolute(OUT)

	gen_slot("player_front_slot_active", 140, 106, CYAN_GLOW, false)
	gen_slot("player_front_slot_locked", 140, 106, Color(0.35, 0.35, 0.38), true)
	gen_slot("player_back_slot_build", 132, 86, BRASS_LIGHT, false)
	gen_slot("player_back_slot_counter", 132, 86, Color(0.15, 0.65, 0.45), false)
	gen_slot("boss_front_slot_online", 140, 106, ORANGE_GLOW, false)
	gen_slot("boss_back_slot_online", 132, 86, ORANGE, false)
	gen_engine_gauge_v2()
	gen_arsenal_dock()

	print("[GenFinal P1] Done — 8 PNGs in %s" % OUT)
	quit()


func gen_slot(name: String, w: int, h: int, glow_color: Color, locked: bool) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.0))

	var border := 3

	# Stone base with bright tone
	for x in range(w):
		for y in range(h):
			var fx := float(x) / float(w)
			var fy := float(y) / float(h)
			# Slight gradient: brighter center
			var dcent: float = abs(fx - 0.5) * 2.0  # 0 center, 1 edges
			var base := STONE_BRIGHT.lerp(STONE_MID, dcent * 0.5 + fy * 0.3)
			base.a = 0.92
			img.set_pixel(x, y, base)

	# Iron frame border
	for x in range(w):
		for y in range(h):
			if x < border or x >= w - border or y < border or y >= h - border:
				img.set_pixel(x, y, IRON)

	# Glow border (second inner border, colored by slot type)
	var glow_border := 1
	for x in range(border, w - border):
		for y in range(border, h - border):
			if (x >= border and x < border + glow_border + 1) or \
			   (x >= w - border - glow_border - 1 and x < w - border) or \
			   (y >= border and y < border + glow_border + 1) or \
			   (y >= h - border - glow_border - 1 and y < h - border):
				var c := img.get_pixel(x, y)
				var blend := glow_color; blend.a = 0.55
				img.set_pixel(x, y, c.lerp(blend, 0.6))

	# Locked: dim overlay
	if locked:
		for x in range(w):
			for y in range(h):
				var c := img.get_pixel(x, y)
				var dim := c; dim.r *= 0.4; dim.g *= 0.4; dim.b *= 0.4; dim.a *= 0.7
				img.set_pixel(x, y, dim)

	# Brass corners
	var csize: int = 5
	for cx in [border + csize, w - border - csize]:
		for cy in [border + csize, h - border - csize]:
			for dx in range(-2, 3):
				for dy in range(-2, 3):
					if dx*dx + dy*dy <= 5:
						var px: int = cx + dx; var py: int = cy + dy
						if px >= 0 and px < w and py >= 0 and py < h:
							img.set_pixel(px, py, BRASS_LIGHT)

	img.save_png(OUT + "/%s.png" % name)
	print("  %s.png (%dx%d)" % [name, w, h])


func gen_engine_gauge_v2() -> void:
	var w := 68; var h := 190
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.0))

	# Light iron frame
	for x in range(w):
		for y in range(h):
			if x < 3 or x >= w - 3 or y < 2 or y >= h - 2:
				img.set_pixel(x, y, IRON_LIGHT)

	# Five slots with brass borders and cyan liquid
	var slot_h: int = 30; var gap: int = 5; var start_y: int = 6
	for li in range(5):
		var sy := start_y + li * (slot_h + gap)
		var ey := sy + slot_h
		# Backing: light stone
		for x in range(6, w - 6):
			for y in range(sy, ey):
				img.set_pixel(x, y, STONE_BRIGHT)
		# Brass pipe borders
		for x in range(6, w - 6):
			for y in range(sy, ey):
				if y < sy + 3 or y >= ey - 3:
					img.set_pixel(x, y, BRASS)
		# Cyan liquid fill
		var fill_h: int = int(float(slot_h) * (0.35 + float(li) * 0.15))
		for x in range(8, w - 8):
			for y in range(ey - fill_h, ey - 3):
				var c := CYAN; c.a = 0.7 + float(li) * 0.08
				var existing := img.get_pixel(x, y)
				img.set_pixel(x, y, existing.lerp(c, c.a))

	# Brass gauge at top
	for x in range(14, 54):
		for y in range(2, 8):
			img.set_pixel(x, y, BRASS_LIGHT)

	img.save_png(OUT + "/engine_gauge_placeholder.png")
	print("  engine_gauge_placeholder.png (68x190) v2 brighter")


func gen_arsenal_dock() -> void:
	var w := 200; var h := 44
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.0))

	# Bright stone base
	for x in range(w):
		for y in range(h):
			var c := STONE_BRIGHT.lerp(STONE_MID, float(y) / float(h))
			c.a = 0.95
			img.set_pixel(x, y, c)

	# Iron top/bottom edge
	for x in range(w):
		for y in range(h):
			if y < 3 or y >= h - 3:
				img.set_pixel(x, y, IRON_LIGHT)

	# Brass border
	for x in range(w):
		for y in range(h):
			if x < 3 or x >= w - 3:
				img.set_pixel(x, y, BRASS)

	# Cyan OD indicator lights (left side)
	for i in range(3):
		var lx := 12 + i * 14
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if dx*dx + dy*dy <= 4:
					var c := CYAN_GLOW; c.a = 0.85
					img.set_pixel(lx + dx, 22 + dy, c)

	# Rivets
	for rx in [30, 170]:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx*dx + dy*dy <= 2:
					img.set_pixel(rx + dx, 22 + dy, BRASS_LIGHT)

	img.save_png(OUT + "/arsenal_dock_placeholder.png")
	print("  arsenal_dock_placeholder.png (200x44)")
