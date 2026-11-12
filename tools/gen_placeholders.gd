extends SceneTree

## Phase 14B-0: Generate placeholder PNGs using Godot Image class
## Run: Godot --headless --path . --script res://tools/gen_placeholders.gd

const OUT := "res://assets/table/placeholder"

func _init() -> void:
	print("[PlaceholderGen] Starting...")
	DirAccess.make_dir_recursive_absolute(OUT)

	_placeholder("table_base_placeholder", 1600, 900, Color(0.92, 0.90, 0.85), Color(0.33, 0.27, 0.20), 8)
	_placeholder("table_frame_placeholder", 1600, 900, Color(0, 0, 0, 0), Color(0.22, 0.20, 0.19), 12)
	_placeholder("player_front_slot_active", 140, 106, Color(0.10, 0.12, 0.24), Color(0.16, 0.47, 0.86), 3)
	_placeholder("player_front_slot_locked", 140, 106, Color(0.08, 0.08, 0.10, 0.78), Color(0.16, 0.15, 0.16), 2)
	_placeholder("player_back_slot_build", 132, 86, Color(0.12, 0.09, 0.03), Color(0.63, 0.51, 0.27), 2)
	_placeholder("player_back_slot_counter", 132, 86, Color(0.03, 0.10, 0.07), Color(0.08, 0.47, 0.31), 2)
	_placeholder("boss_front_slot_online", 140, 106, Color(0.14, 0.05, 0.03), Color(0.55, 0.10, 0.06), 3)
	_placeholder("boss_back_slot_online", 132, 86, Color(0.11, 0.04, 0.02), Color(0.47, 0.08, 0.05), 2)
	_placeholder("engine_gauge_placeholder", 68, 190, Color(0.12, 0.11, 0.14), Color(0.63, 0.51, 0.27), 3)
	_placeholder("deck_box_player_placeholder", 72, 96, Color(0.04, 0.16, 0.35), Color(0.63, 0.51, 0.27), 2)
	_placeholder("graveyard_box_player_placeholder", 72, 48, Color(0.08, 0.07, 0.10), Color(0.24, 0.22, 0.23), 2)
	_placeholder("deck_box_boss_placeholder", 72, 96, Color(0.27, 0.06, 0.04), Color(0.55, 0.10, 0.06), 2)
	_placeholder("graveyard_box_boss_placeholder", 72, 48, Color(0.12, 0.04, 0.03), Color(0.39, 0.08, 0.06), 2)
	_placeholder("arsenal_dock_placeholder", 200, 44, Color(0.22, 0.20, 0.19), Color(0.63, 0.51, 0.27), 2)
	_placeholder("boss_core_placeholder", 200, 90, Color(0.16, 0.05, 0.03), Color(0.78, 0.27, 0.08), 4)
	_placeholder("depth_crack_placeholder", 1600, 900, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)

	print("[PlaceholderGen] Done — 16 PNGs in %s" % OUT)
	quit()


func _placeholder(name: String, w: int, h: int, fill: Color, border_c: Color, border_w: int) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	if border_w > 0:
		for x in range(w):
			for y in range(h):
				if x < border_w or x >= w - border_w or y < border_w or y >= h - border_w:
					img.set_pixel(x, y, Color(border_c.r, border_c.g, border_c.b, 1.0))
	var path := "%s/%s.png" % [OUT, name]
	img.save_png(path)
	print("  %s.png (%dx%d)" % [name, w, h])
