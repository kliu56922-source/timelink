extends SceneTree

## Phase 18I-2: High-quality Cloud-Gate Magitek Table Base + Frame
## Run: Godot --headless --path . --script res://tools/gen_cloudgate_v2_table_art.gd
##
## Style: 云阙机枢 / Cloud-Gate Magitek Tactical Altar
## - Bright cloud-sea high fantasy
## - Weathered white-gray stone (35%), sky blue (15%), black iron (18%), brass (12%), cyan (12%), vermilion (8%)
## - New Chinese architectural rhythm: abstract dougong, hui-pattern, axial symmetry
## - Realistic material grounding, painterly but bright

const OUT := "res://assets/table/cloudgate_v2"
const W := 1600
const H := 900

# ── Cloud-Gate v2 Palette ──
const SKY_TOP    := Color(0.38, 0.52, 0.65)   # distant mountain sky
const SKY_MID    := Color(0.55, 0.65, 0.75)   # mid sky
const CLOUD      := Color(0.82, 0.84, 0.86)   # bright cloud sea
const CLOUD_WARM := Color(0.88, 0.85, 0.82)   # warm cloud near horizon
const STONE_DARK := Color(0.42, 0.40, 0.38)   # dark wet stone
const STONE_MID  := Color(0.58, 0.56, 0.53)   # mid stone
const STONE_LIT  := Color(0.70, 0.68, 0.65)   # sun-lit stone
const STONE_BRIGHT := Color(0.78, 0.76, 0.73) # bright wear patch
const IRON       := Color(0.07, 0.06, 0.05)   # black iron
const IRON_EDGE  := Color(0.12, 0.11, 0.10)   # iron highlight edge
const BRASS_DARK := Color(0.35, 0.26, 0.14)   # dark aged brass
const BRASS      := Color(0.58, 0.43, 0.20)   # aged brass
const BRASS_LIT  := Color(0.72, 0.54, 0.28)   # polished brass highlight
const CYAN_CORE  := Color(0.02, 0.50, 0.48)   # jade OD core
const CYAN_GLOW  := Color(0.08, 0.65, 0.62)   # cyan OD glow
const CYAN_BRIGHT := Color(0.15, 0.78, 0.72)  # bright cyan accent
const VERMILION  := Color(0.68, 0.20, 0.08)   # boss heat
const VERM_DIM   := Color(0.40, 0.12, 0.04)   # dim vermilion
const PURPLE     := Color(0.28, 0.05, 0.22)   # depth violet
const SHADOW     := Color(0.0, 0.0, 0.0, 0.35) # floating shadow


func _init() -> void:
	print("[GenCloudGateV2-Table] Generating high-quality table_base + table_frame...")
	DirAccess.make_dir_recursive_absolute(OUT)
	gen_table_base_cloudgate()
	gen_table_frame_cloudgate()
	print("[GenCloudGateV2-Table] Done — 2 PNGs in %s" % OUT)
	quit()


# ═══════════════════════════════════════════════════════════
# TABLE BASE — Cloud-Gate Stone Board
# ═══════════════════════════════════════════════════════════
func gen_table_base_cloudgate() -> void:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)

	# ── Pass 1: Cloud-sea sky background ──
	_draw_sky_background(img)

	# ── Pass 2: Stone table surface ──
	_draw_stone_surface(img)

	# ── Pass 3: OD energy center line ──
	_draw_od_center_line(img)

	# ── Pass 4: Iron + brass border frame ──
	_draw_board_frame(img)

	# ── Pass 5: Boss-side vermilion warmth ──
	_draw_boss_heat(img)

	# ── Pass 6: Card position wear patches ──
	_draw_card_wear(img)

	# ── Pass 7: Subtle hui-pattern / cloud纹 along inner border ──
	_draw_hui_border(img)

	# ── Pass 8: Floating shadow beneath board ──
	_draw_float_shadow(img)

	img.save_png(OUT + "/table_base_cloudgate.png")
	print("  table_base_cloudgate.png (1600x900) — Cloud-Gate stone board")


# ═══════════════════════════════════════════════════════════
# TABLE FRAME — Iron + Brass Ornamental Frame
# ═══════════════════════════════════════════════════════════
func gen_table_frame_cloudgate() -> void:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.0))  # transparent center

	# ── Outer iron frame ──
	var outer_w := 10
	var inner_w := 22
	for x in range(W):
		for y in range(H):
			var ed := _edge_dist(x, y)
			if ed < outer_w:
				img.set_pixel(x, y, Color(IRON.r, IRON.g, IRON.b, 0.95))
			elif ed < inner_w:
				var t: float = float(ed - outer_w) / float(inner_w - outer_w)
				var c: Color = IRON.lerp(BRASS, t * 0.45)
				c.a = 0.92 - t * 0.50
				img.set_pixel(x, y, c)

	# ── Brass corner dougong brackets ──
	_draw_dougong_corners(img, inner_w)

	# ── Inner brass accent line ──
	var inset := inner_w + 4
	_draw_rect_outline(img, inset, inset, W - inset * 2, H - inset * 2, 2, Color(BRASS.r, BRASS.g, BRASS.b, 0.5))

	# ── Hui-pattern dots along inner edge ──
	_draw_hui_dots(img, inset + 3)

	# ── Floating shadow at bottom ──
	for x in range(W):
		for y in range(H - 30, H):
			var c := img.get_pixel(x, y)
			if c.a < 0.05:
				var a: float = float(y - (H - 30)) / 30.0 * 0.30
				img.set_pixel(x, y, Color(0, 0, 0, a))

	img.save_png(OUT + "/table_frame_cloudgate.png")
	print("  table_frame_cloudgate.png (1600x900) — iron+brass frame")


# ═══════════════════════════════════════════════════════════
# DRAWING HELPERS
# ═══════════════════════════════════════════════════════════

func _edge_dist(x: int, y: int) -> int:
	return mini(mini(x, W - 1 - x), mini(y, H - 1 - y))


func _smooth_noise(x: float, y: float, scale: float) -> float:
	return sin(x * scale + y * 0.7 * scale) * 0.5 + sin(y * scale * 1.3 - x * 0.4 * scale) * 0.3 + sin((x + y) * scale * 0.6) * 0.2


func _draw_sky_background(img: Image) -> void:
	# Gradient from distant mountain sky (top) to cloud sea (bottom)
	for y in range(H):
		var fy := float(y) / float(H)
		for x in range(W):
			var fx := float(x) / float(W)
			# Sky gradient with cloud band at horizon
			var sky_t: float = clampf(fy * 1.4, 0.0, 1.0)
			var c: Color = SKY_TOP.lerp(CLOUD, sky_t)
			# Cloud variation — horizontal bands
			var cloud_var := sin(fy * 14.0 + sin(fx * 6.0) * 0.5) * 0.04
			c = c.lerp(CLOUD_WARM, cloud_var * 0.4 + 0.02)
			# Distant mountain silhouettes at top
			if fy < 0.15:
				var mt := _mountain_silhouette(fx, fy)
				c = c.lerp(SKY_TOP.darkened(0.2), mt * 0.6)
			img.set_pixel(x, y, c)


func _mountain_silhouette(fx: float, fy: float) -> float:
	# Generate distant mountain ridge silhouette
	var ridge := 0.0
	ridge += sin(fx * 3.0 + 0.5) * 0.04
	ridge += sin(fx * 7.0 + 1.2) * 0.025
	ridge += sin(fx * 13.0 + 2.8) * 0.012
	var ridge_y := 0.10 + ridge
	if fy < ridge_y:
		return 1.0 - (ridge_y - fy) / 0.02
	return 0.0


func _draw_stone_surface(img: Image) -> void:
	var table_top := 40
	var table_bot := H - 60
	var table_left := 55
	var table_right := W - 55

	for y in range(table_top, table_bot):
		var fy := float(y - table_top) / float(table_bot - table_top)
		for x in range(table_left, table_right):
			var fx := float(x - table_left) / float(table_right - table_left)

			# Base stone color — slight vertical gradient (darker at top/edges)
			var stone := STONE_MID.lerp(STONE_LIT, fy * 0.5)
			stone = stone.lerp(STONE_DARK, (1.0 - fy) * 0.15)  # slightly darker top

			# Stone grain texture
			var grain := _smooth_noise(float(x), float(y), 0.008) * 0.04
			var fine_grain := sin(float(x) * 0.3) * sin(float(y) * 0.25) * 0.015
			stone = stone.lerp(STONE_LIT if grain > 0 else STONE_DARK, abs(grain) + abs(fine_grain))

			# Subtle horizontal strata lines (sedimentary stone)
			var strata := sin(float(y) * 0.08) * 0.012
			stone = stone.lerp(STONE_DARK if strata < 0 else STONE_LIT, abs(strata))

			# Edge darkening — vignette toward frame
			var ed := _edge_dist(x, y)
			if ed < 80:
				var ev: float = 1.0 - float(ed) / 80.0
				stone = stone.lerp(STONE_DARK, ev * ev * 0.25)

			img.set_pixel(x, y, stone)


func _draw_od_center_line(img: Image) -> void:
	var cy := 455  # center Y (slightly below geometric center for visual balance)

	# Main OD energy conduit — horizontal cyan line
	for x in range(300, W - 300):
		var dist_c: float = abs(x - W / 2.0) / (W / 2.0 - 300.0)
		var intensity: float = 1.0 - dist_c * dist_c * dist_c  # cubic falloff for sharper center

		# Core line + glow
		for dy in range(-6, 7):
			var py: int = cy + dy
			if py < 0 or py >= H:
				continue
			var c := img.get_pixel(x, py)
			var od := CYAN_GLOW
			var dy_abs: float = abs(float(dy))
			var line_alpha: float = 0.0
			if dy_abs <= 1.0:
				line_alpha = 0.65 * intensity  # core
			elif dy_abs <= 3.0:
				line_alpha = 0.30 * intensity * (1.0 - (dy_abs - 1.0) / 2.0)  # inner glow
			else:
				line_alpha = 0.10 * intensity * (1.0 - (dy_abs - 3.0) / 3.0)  # outer glow
			od.a = clampf(line_alpha, 0.0, 0.7)
			img.set_pixel(x, py, c.lerp(od, od.a))

	# Bright accent ticks along center line (like energy measurement marks)
	for tick_x in range(400, W - 400, 200):
		if abs(tick_x - W / 2) < 50:
			continue  # skip center
		for tx in range(tick_x - 3, tick_x + 4):
			for ty in range(cy - 3, cy + 4):
				if tx >= 0 and tx < W and ty >= 0 and ty < H:
					var tc := img.get_pixel(tx, ty)
					var ta := CYAN_BRIGHT; ta.a = 0.35
					img.set_pixel(tx, ty, tc.lerp(ta, ta.a))

	# Center jewel — brighter cyan diamond at exact center
	var cjx := W / 2
	var cjy := cy
	for dx in range(-5, 6):
		for dy in range(-5, 6):
			if abs(dx) + abs(dy) <= 5:
				var px := cjx + dx; var py := cjy + dy
				if px >= 0 and px < W and py >= 0 and py < H:
					var cc := img.get_pixel(px, py)
					var cj := CYAN_BRIGHT; cj.a = 0.55
					img.set_pixel(px, py, cc.lerp(cj, cj.a))


func _draw_board_frame(img: Image) -> void:
	var bf := 8   # iron frame width
	var bi := 22  # total frame zone (iron + brass inner)

	# Iron outer frame
	for x in range(W):
		for y in range(H):
			var ed := _edge_dist(x, y)
			if ed < bf:
				img.set_pixel(x, y, IRON)
			elif ed < bi:
				var t: float = float(ed - bf) / float(bi - bf)
				var c := IRON.lerp(BRASS_DARK, t * 0.4)
				img.set_pixel(x, y, c)

	# Brass corner rivets
	for corner in [[bi+2, bi+2], [W-1-bi-2, bi+2], [bi+2, H-1-bi-2], [W-1-bi-2, H-1-bi-2]]:
		for dx in range(-5, 6):
			for dy in range(-5, 6):
				var d2 := dx*dx + dy*dy
				if d2 <= 28:
					var px: int = corner[0] + dx; var py: int = corner[1] + dy
					if px >= 0 and px < W and py >= 0 and py < H:
						var col := BRASS if d2 > 12 else BRASS_LIT
						img.set_pixel(px, py, col)

	# Brass accent line inside iron frame — thin rail
	var rail := bi + 2
	_draw_rect_outline(img, rail, rail, W - rail * 2, H - rail * 2, 2, Color(BRASS.r, BRASS.g, BRASS.b, 0.55))


func _draw_boss_heat(img: Image) -> void:
	# Vermilion warmth only on top ~22% (Boss side), fading down
	for y in range(0, 200):
		var fy := float(y) / 200.0
		for x in range(W):
			var c := img.get_pixel(x, y)
			# Gradient: strongest at top edge, fades to nothing at y=200
			var alpha: float = (1.0 - fy) * (1.0 - fy) * 0.10
			# Slightly stronger near center (Boss core area)
			var cx_factor: float = 1.0 - abs(x - W / 2.0) / (W / 2.0) * 0.3
			alpha *= cx_factor
			var heat := VERM_DIM; heat.a = alpha
			img.set_pixel(x, y, c.lerp(heat, alpha))

	# Subtle vermilion edge glow along top frame
	for x in range(60, W - 60):
		for y in range(8, 20):
			var c := img.get_pixel(x, y)
			var edge_alpha: float = float(20 - y) / 12.0 * 0.04
			var heat := VERM_DIM; heat.a = edge_alpha
			img.set_pixel(x, y, c.lerp(heat, edge_alpha))


func _draw_card_wear(img: Image) -> void:
	# 5 subtle wear patches — where cards rest on the stone
	var positions := [
		[320, 300],   # far left
		[520, 310],   # left
		[800, 315],   # center
		[1080, 310],  # right
		[1280, 300],  # far right
	]
	for pos in positions:
		var cx: int = pos[0]; var cy: int = pos[1]
		for dx in range(-38, 39):
			for dy in range(-26, 27):
				var d2 := float(dx*dx) / 1444.0 + float(dy*dy) / 676.0
				if d2 <= 1.0:
					var px := cx + dx; var py := cy + dy
					if px >= 0 and px < W and py >= 0 and py < H:
						var c := img.get_pixel(px, py)
						var wear_alpha: float = (1.0 - d2) * (1.0 - d2) * 0.10
						img.set_pixel(px, py, c.lerp(STONE_BRIGHT, wear_alpha))


func _draw_hui_border(img: Image) -> void:
	# Subtle abstract 回纹 / cloud-pattern dots along inner border
	var margin := 36
	var spacing := 18
	var dot_r := 2

	# Top edge
	for x in range(margin + 30, W - margin - 30, spacing):
		for dx in range(-dot_r, dot_r + 1):
			for dy in range(-dot_r, dot_r + 1):
				if dx*dx + dy*dy <= dot_r*dot_r:
					var px := x + dx; var py := margin + dy
					if px >= 0 and px < W and py >= 0 and py < H:
						var c := img.get_pixel(px, py)
						var dc := BRASS; dc.a = 0.18
						img.set_pixel(px, py, c.lerp(dc, dc.a))
	# Bottom edge
	for x in range(margin + 30, W - margin - 30, spacing):
		for dx in range(-dot_r, dot_r + 1):
			for dy in range(-dot_r, dot_r + 1):
				if dx*dx + dy*dy <= dot_r*dot_r:
					var px := x + dx; var py := H - 1 - margin + dy
					if px >= 0 and px < W and py >= 0 and py < H:
						var c := img.get_pixel(px, py)
						var dc := BRASS; dc.a = 0.18
						img.set_pixel(px, py, c.lerp(dc, dc.a))


func _draw_float_shadow(img: Image) -> void:
	# Shadow beneath the floating altar — bottom edge only
	for x in range(W):
		for y in range(H - 40, H):
			var fy := float(y - (H - 40)) / 40.0
			var alpha: float = fy * fy * 0.45  # quadratic darkening
			var c := img.get_pixel(x, y)
			var sd := Color(0.0, 0.0, 0.0, alpha)
			img.set_pixel(x, y, c.lerp(sd, alpha))


func _draw_rect_outline(img: Image, rx: int, ry: int, rw: int, rh: int, thickness: int, color: Color) -> void:
	for x in range(rx, rx + rw):
		for dy in range(thickness):
			var py_top := ry + dy; var py_bot := ry + rh - 1 - dy
			if py_top >= 0 and py_top < H:
				var c := img.get_pixel(x, py_top)
				img.set_pixel(x, py_top, c.lerp(color, color.a))
			if py_bot >= 0 and py_bot < H:
				var c := img.get_pixel(x, py_bot)
				img.set_pixel(x, py_bot, c.lerp(color, color.a))
	for y in range(ry, ry + rh):
		for dx in range(thickness):
			var px_left := rx + dx; var px_right := rx + rw - 1 - dx
			if px_left >= 0 and px_left < W:
				var c := img.get_pixel(px_left, y)
				img.set_pixel(px_left, y, c.lerp(color, color.a))
			if px_right >= 0 and px_right < W:
				var c := img.get_pixel(px_right, y)
				img.set_pixel(px_right, y, c.lerp(color, color.a))


func _draw_dougong_corners(img: Image, inner: int) -> void:
	# Abstract 斗拱 brackets at 4 corners
	# Simplified: layered horizontal bars with brass accents
	var offsets := [
		[inner, inner, 1, 1],             # top-left
		[W - 1 - inner, inner, -1, 1],    # top-right
		[inner, H - 1 - inner, 1, -1],    # bottom-left
		[W - 1 - inner, H - 1 - inner, -1, -1],  # bottom-right
	]
	for off in offsets:
		var cx: int = off[0]; var cy: int = off[1]
		var dx_sign: int = off[2]; var dy_sign: int = off[3]

		# Three horizontal brackets stacking outward
		for layer in range(3):
			var bw := 28 + layer * 8
			var bh := 5
			var bx := cx + dx_sign * (inner + layer * 6)
			var by := cy + dy_sign * (inner + layer * 4)
			for x in range(bx, bx + dx_sign * bw, dx_sign if dx_sign > 0 else 1):
				for y in range(by, by + dy_sign * bh, dy_sign if dy_sign > 0 else 1):
					var px: int = x if dx_sign > 0 else bx + (x - bx)
					var py: int = y if dy_sign > 0 else by + (y - by)
					if px >= 0 and px < W and py >= 0 and py < H:
						var col := IRON.lerp(BRASS, float(layer) / 2.0)
						col.a = 0.8 - float(layer) * 0.15
						img.set_pixel(px, py, col)

		# Brass cap at end of each bracket
		for layer in range(3):
			var cap_x := cx + dx_sign * (inner + layer * 6 + 28 + layer * 8)
			var cap_y := cy + dy_sign * (inner + layer * 4)
			for dx in range(-3, 4):
				for dy in range(-2, 3):
					if dx*dx + dy*dy <= 10:
						var px := cap_x + dx; var py := cap_y + dy
						if px >= 0 and px < W and py >= 0 and py < H:
							img.set_pixel(px, py, Color(BRASS_LIT.r, BRASS_LIT.g, BRASS_LIT.b, 0.7))


func _draw_hui_dots(img: Image, inset: int) -> void:
	# Small brass dots along inner frame edge — abstract 回纹 rhythm
	var spacing := 20
	for edge in range(4):
		var start_x: int; var start_y: int; var step_x: int; var step_y: int; var count: int
		match edge:
			0:  # top
				start_x = inset + 20; start_y = inset; step_x = spacing; step_y = 0
				count = (W - inset * 2 - 40) / spacing
			1:  # bottom
				start_x = inset + 20; start_y = H - 1 - inset; step_x = spacing; step_y = 0
				count = (W - inset * 2 - 40) / spacing
			2:  # left
				start_x = inset; start_y = inset + 20; step_x = 0; step_y = spacing
				count = (H - inset * 2 - 40) / spacing
			3:  # right
				start_x = W - 1 - inset; start_y = inset + 20; step_x = 0; step_y = spacing
				count = (H - inset * 2 - 40) / spacing
		for i in range(count):
			var px := start_x + i * step_x; var py := start_y + i * step_y
			if px >= 0 and px < W and py >= 0 and py < H:
				var c := img.get_pixel(px, py)
				var dot := BRASS; dot.a = 0.35
				img.set_pixel(px, py, c.lerp(dot, dot.a))
