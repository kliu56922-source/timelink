extends SceneTree

## Phase 16A: Check table art assets in final/ directory
## Run: Godot --headless --path . --script res://tools/check_table_assets.gd

const FINAL_DIR := "res://assets/table/final"

# Expected files: name, width, height, has_alpha
const EXPECTED := [
	["table_base_final", 1600, 900, false],
	["table_frame_final", 1600, 900, true],
	["player_front_slot_active_final", 140, 106, true],
	["player_front_slot_locked_final", 140, 106, true],
	["player_back_slot_build_final", 132, 86, true],
	["player_back_slot_counter_final", 132, 86, true],
	["boss_front_slot_online_final", 140, 106, true],
	["boss_back_slot_online_final", 132, 86, true],
	["engine_gauge_final", 68, 190, true],
	["deck_box_player_final", 72, 96, true],
	["graveyard_box_player_final", 72, 48, true],
	["deck_box_boss_final", 72, 96, true],
	["graveyard_box_boss_final", 72, 48, true],
	["arsenal_dock_final", 200, 44, true],
	["boss_core_final", 200, 90, true],
	["depth_crack_final", 1600, 900, true],
]

func _init() -> void:
	print("[AssetCheck] Scanning %s ..." % FINAL_DIR)
	var ok := 0
	var missing := 0
	var size_err := 0

	for entry in EXPECTED:
		var name: String = entry[0]
		var exp_w: int = entry[1]
		var exp_h: int = entry[2]
		var path := "%s/%s.png" % [FINAL_DIR, name]

		if not ResourceLoader.exists(path):
			push_warning("[AssetCheck] MISSING: %s" % path)
			missing += 1
			continue

		var tex: Texture2D = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
		if tex == null:
			push_warning("[AssetCheck] FAILED TO LOAD: %s" % path)
			missing += 1
			continue

		var w := tex.get_width()
		var h := tex.get_height()
		if w != exp_w or h != exp_h:
			push_warning("[AssetCheck] SIZE MISMATCH: %s (%dx%d expected, got %dx%d)" % [name, exp_w, exp_h, w, h])
			size_err += 1
			continue

		ok += 1
		print("  OK: %s (%dx%d)" % [name, w, h])

	print("\n[AssetCheck] Summary: %d OK / %d missing / %d size errors / %d total" % [ok, missing, size_err, EXPECTED.size()])
	quit()
