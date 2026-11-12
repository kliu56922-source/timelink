extends SceneTree

## Phase 18I-1: Generate 5 P0 CloudGate v2 table art assets
## Run: Godot --headless --path . --script res://tools/gen_cloudgate_v2_art.gd
##
## Style: Cloud-Gate Magitek Tactical Altar / 云阙魔导战术台
## - Bright cloud-sea white-gray stone
## - Black iron framing
## - Aged brass mechanical trim
## - Cyan/jade OD energy
## - Restrained vermilion Boss heat
## - Limited violet Depth cracks

const OUT := "res://assets/table/cloudgate_v2"

# Cloud-Gate v2 palette — bright, readable, magitek
const STONE_BASE   := Color(0.58, 0.56, 0.53)   # white-gray weathered stone
const STONE_MID    := Color(0.66, 0.64, 0.61)   # mid stone
const STONE_LIGHT  := Color(0.74, 0.72, 0.70)   # light stone highlight
const IRON         := Color(0.07, 0.06, 0.05)   # black iron
const IRON_FRAME   := Color(0.10, 0.09, 0.08)   # iron edge
const BRASS        := Color(0.62, 0.46, 0.20)   # aged brass
const BRASS_LIGHT  := Color(0.72, 0.54, 0.26)   # brass highlight
const CYAN         := Color(0.05, 0.58, 0.55)   # jade OD energy
const CYAN_BRIGHT  := Color(0.10, 0.72, 0.68)   # bright cyan
const ORANGE       := Color(0.68, 0.22, 0.08)   # vermilion heat
const ORANGE_DIM   := Color(0.40, 0.12, 0.04)   # dim heat
const PURPLE       := Color(0.30, 0.05, 0.25)   # depth violet
const CLOUD_WHITE  := Color(0.82, 0.83, 0.85)   # cloud mist


func _init() -> void:
	print("[GenCloudGateV2] Generating 5 P0 CloudGate v2 table art assets...")
	DirAccess.make_dir_recursive_absolute(OUT)

	gen_table_base()
	gen_table_frame()
	gen_od_gauge_housing()
	gen_boss_core_device()
	gen_depth_crack_overlay()

	print("[GenCloudGateV2] Done — 5 PNGs in %s" % OUT)
	quit()


func gen_table_base() -> void:
	var img := Image.create(1600, 900, false, Image.FORMAT_RGBA8)

	# White-gray stone surface with subtle cloud-sea variegation
	for y in range(900):
		for x in range(1600):
			var fx := float(x) / 1600.0
			var fy := float(y) / 900.0
			var grain := sin(fx * 100.0 + fy * 60.0) * 0.015 + sin(fy * 40.0) * 0.01
			var base := STONE_BASE.lerp(STONE_MID, fy * 0.3 + grain)
			# Subtle horizontal cloud bands
			var cloud := sin(fy * 8.0) * 0.02
			base = base.lerp(CLOUD_WHITE, cloud * 0.3)
			img.set_pixel(x, y, base)

	# Iron frame border (6px, refined)
	var border := 6
	for x in range(1600):
		for y in range(900):
			if x < border or x >= 1600 - border or y < border or y >= 900 - border:
				img.set_pixel(x, y, IRON_FRAME)

	# Center OD energy line (thin jade, tapered at edges)
	var center_y := 450
	for x in range(250, 1350):
		var dist_from_center: float = abs(x - 800.0) / 800.0
		var glow: float = 1.0 - dist_from_center * dist_from_center
		for dy in range(-3, 4):
			var c := img.get_pixel(x, center_y + dy)
			var od_color := CYAN
			od_color.a = 0.35 * glow * (1.0 - abs(float(dy)) / 4.0)
			img.set_pixel(x, center_y + dy, c.lerp(od_color, od_color.a))

	# Boss side warm tint (top 250px, very subtle)
	for x in range(1600):
		for y in range(0, 250):
			var c := img.get_pixel(x, y)
			var warm := ORANGE_DIM
			warm.a = (1.0 - float(y) / 250.0) * 0.06
			img.set_pixel(x, y, c.lerp(warm, warm.a))

	# Brass corner rivets (cleaner, more mechanical)
	for corner in [[border+6,border+6], [1594-border,border+6], [border+6,894], [1594-border,894]]:
		for dx in range(-5, 6):
			for dy in range(-5, 6):
				if dx*dx + dy*dy <= 25:
					var c := BRASS
					if dx*dx + dy*dy <= 9: c = BRASS_LIGHT
					img.set_pixel(corner[0]+dx, corner[1]+dy, c)

	# Subtle card-position wear patches (faint, center area)
	for patch_cx in [400, 640, 800, 960, 1200]:
		for dx in range(-35, 36):
			for dy in range(-25, 26):
				if dx*dx + dy*dy <= 1225:
					var px: int = patch_cx + dx
					var py: int = 300 + dy
					if px >= 0 and px < 1600 and py >= 0 and py < 900:
						var c := img.get_pixel(px, py)
						var wear := STONE_LIGHT
						wear.a = 0.06 * (1.0 - float(dx*dx + dy*dy) / 1225.0)
						img.set_pixel(px, py, c.lerp(wear, wear.a))

	img.save_png(OUT + "/table_base_cloudgate.png")
	print("  table_base_cloudgate.png (1600x900)")


func gen_table_frame() -> void:
	var img := Image.create(1600, 900, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.0))  # transparent center for card area

	# Black iron outer frame with brass inner accent
	var outer := 8
	var inner := 14
	for x in range(1600):
		for y in range(900):
			var edge_dist := mini(mini(x, 1599-x), mini(y, 899-y))
			if edge_dist < outer:
				img.set_pixel(x, y, Color(IRON.r, IRON.g, IRON.b, 0.95))
			elif edge_dist < inner:
				var t := float(edge_dist - outer) / float(inner - outer)
				var c := IRON.lerp(BRASS, t * 0.4)
				c.a = 0.95 - t * 0.4
				img.set_pixel(x, y, c)

	# Brass corner accents (larger, more ornate than base corners)
	for corner in [[inner+2,inner+2], [1598-inner,inner+2], [inner+2,898], [1598-inner,898]]:
		for dx in range(-6, 7):
			for dy in range(-6, 7):
				if dx*dx + dy*dy <= 38:
					var px: int = corner[0] + dx
					var py: int = corner[1] + dy
					if px >= 0 and px < 1600 and py >= 0 and py < 900:
						var c := BRASS
						if dx*dx + dy*dy <= 16: c = BRASS_LIGHT
						c.a = 0.85
						img.set_pixel(px, py, c)

	# Floating underside shadow (bottom edge)
	for x in range(1600):
		for y in range(880, 900):
			var c := img.get_pixel(x, y)
			if c.a > 0:
				continue
			var alpha: float = float(y - 880) / 20.0 * 0.25
			img.set_pixel(x, y, Color(0, 0, 0, alpha))

	img.save_png(OUT + "/table_frame_cloudgate.png")
	print("  table_frame_cloudgate.png (1600x900)")


func gen_od_gauge_housing() -> void:
	var w := 420
	var h := 120
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	# Dark stone base with iron recess
	for y in range(h):
		for x in range(w):
			var fx := float(x) / float(w)
			var grain := sin(fx * 30.0 + float(y) * 0.1) * 0.02
			var c := STONE_BASE.darkened(0.35).lerp(Color(0.04, 0.03, 0.06), 0.5 + grain)
			img.set_pixel(x, y, c)

	# Iron frame
	var bf := 4
	for x in range(w):
		for y in range(h):
			if x < bf or x >= w - bf or y < bf or y >= h - bf:
				img.set_pixel(x, y, IRON)

	# Brass inner rail
	for x in range(8, w - 8):
		for dy in range(-1, 2):
			var py := 28 + dy
			if py >= 0 and py < h:
				img.set_pixel(x, py, BRASS)

	# Five layer rail grooves (subtle indentations)
	for layer in range(5):
		var ly := 20 + layer * 11
		for x in range(12, w - 12):
			for dy in range(-1, 2):
				var py := ly + dy
				if py >= 0 and py < h:
					var c := img.get_pixel(x, py)
					var dark := c.darkened(0.15)
					img.set_pixel(x, py, dark)

	# Left circular ratchet wheel
	var cx := 28
	for dx in range(-9, 10):
		for dy in range(-9, 10):
			var dist := dx*dx + dy*dy
			if dist <= 81 and dist >= 49:
				img.set_pixel(cx+dx, 60+dy, BRASS)
			elif dist <= 49:
				img.set_pixel(cx+dx, 60+dy, IRON)

	# Cyan glass display glow (inner)
	for x in range(14, w - 14):
		for y in range(30, h - 8):
			var c := img.get_pixel(x, y)
			var cyan_glow := CYAN
			cyan_glow.a = 0.08
			img.set_pixel(x, y, c.lerp(cyan_glow, cyan_glow.a))

	img.save_png(OUT + "/od_gauge_housing.png")
	print("  od_gauge_housing.png (420x120)")


func gen_boss_core_device() -> void:
	var w := 220
	var h := 100
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	# Dark iron housing
	for y in range(h):
		for x in range(w):
			img.set_pixel(x, y, IRON.darkened(0.3))

	# Iron frame
	var bf := 3
	for x in range(w):
		for y in range(h):
			if x < bf or x >= w - bf or y < bf or y >= h - bf:
				img.set_pixel(x, y, IRON_FRAME)

	# Brass trim top and bottom
	for x in range(4, w - 4):
		for y in range(4, 8):
			img.set_pixel(x, y, BRASS)
		for y in range(h - 8, h - 4):
			img.set_pixel(x, y, BRASS)

	# Vermilion core glow (center)
	var core_cx := w / 2
	var core_cy := h / 2
	for dx in range(-25, 26):
		for dy in range(-18, 19):
			var dist := float(dx*dx) / 625.0 + float(dy*dy) / 324.0
			if dist <= 1.0:
				var c := ORANGE
				c.a = (1.0 - dist) * 0.75
				var px := core_cx + dx
				var py := core_cy + dy
				if px >= 0 and px < w and py >= 0 and py < h:
					var existing := img.get_pixel(px, py)
					img.set_pixel(px, py, existing.lerp(c, c.a))

	# Orange ring around core
	for angle_i in range(24):
		var angle := float(angle_i) * TAU / 24.0
		for r in range(26, 31):
			var px := core_cx + int(cos(angle) * float(r))
			var py := core_cy + int(sin(angle) * float(r) * 0.7)
			if px >= 0 and px < w and py >= 0 and py < h:
				img.set_pixel(px, py, ORANGE)

	# Brass rivets at corners
	for corner in [[8,8], [w-9,8], [8,h-9], [w-9,h-9]]:
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if dx*dx + dy*dy <= 5:
					img.set_pixel(corner[0]+dx, corner[1]+dy, BRASS_LIGHT)

	img.save_png(OUT + "/boss_core_device.png")
	print("  boss_core_device.png (220x100)")


func gen_depth_crack_overlay() -> void:
	var img := Image.create(1600, 900, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.0))  # transparent

	# Subtle violet crack lines — bottom-right quadrant (Depth pressure zone)
	var rng_seed := 42  # fixed seed for reproducibility
	var crack_count := 6

	for ci in range(crack_count):
		# Each crack: jagged line from bottom edge upward
		var sx := 900 + (ci * 100 + (ci * 73) % 80)
		var sy := 750 + (ci * 20)
		var px := sx
		var py := sy
		var segments := 12 + ci * 2

		for si in range(segments):
			var nx := px + (si * 7 + ci * 13) % 25 - 12
			var ny := py - 15 - (si % 8)
			# Draw line segment
			var steps := maxi(abs(nx - px), abs(ny - py))
			for t in range(steps + 1):
				var ratio := float(t) / float(max(1, steps))
				var lx := int(lerpf(float(px), float(nx), ratio))
				var ly := int(lerpf(float(py), float(ny), ratio))
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						var fx := lx + dx
						var fy := ly + dy
						if fx >= 0 and fx < 1600 and fy >= 0 and fy < 900:
							var dist_pen: int = abs(dx) + abs(dy)
							var alpha: float = 0.12 / float(1 + dist_pen)
							# Brighter at crack tips
							var tip_factor: float = 1.0 - float(si) / float(segments)
							alpha += tip_factor * 0.06
							var c := PURPLE
							c.a = clampf(alpha, 0.0, 0.25)
							var existing := img.get_pixel(fx, fy)
							img.set_pixel(fx, fy, existing.lerp(c, c.a))
			px = nx
			py = ny

	# Fewer cracks on left side (player side — controlled)
	for ci in range(3):
		var sx := 200 + ci * 120
		var sy := 800 + ci * 30
		var px := sx
		var py := sy
		for si in range(6):
			var nx := px + (si * 5 + ci * 9) % 18 - 9
			var ny := py - 12 - (si % 5)
			for t in range(maxi(abs(nx - px), abs(ny - py)) + 1):
				var ratio := float(t) / float(max(1, maxi(abs(nx - px), abs(ny - py))))
				var lx := int(lerpf(float(px), float(nx), ratio))
				var ly := int(lerpf(float(py), float(ny), ratio))
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						var fx := lx + dx
						var fy := ly + dy
						if fx >= 0 and fx < 1600 and fy >= 0 and fy < 900:
							var c := PURPLE
							c.a = 0.06
							var existing := img.get_pixel(fx, fy)
							img.set_pixel(fx, fy, existing.lerp(c, c.a))
			px = nx
			py = ny

	# Purple edge tint along bottom (Depth accumulation zone)
	for x in range(1600):
		for y in range(820, 900):
			var c := PURPLE
			c.a = float(y - 820) / 80.0 * 0.06
			var existing := img.get_pixel(x, y)
			img.set_pixel(x, y, existing.lerp(c, c.a))

	img.save_png(OUT + "/depth_crack_overlay.png")
	print("  depth_crack_overlay.png (1600x900)")
