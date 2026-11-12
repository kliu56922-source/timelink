extends RefCounted
## Single public entry contract. Existing practice values and rules are unchanged.
const HOME_PATH="res://scenes/menu/demo_home.tscn"
const BATTLE_PATH="res://scenes/playtest/phase168d1_clarity.tscn"
const PLAYER_HP=80
const BOSS_HP=55
const DECK_COUNT=19
static func developer_enabled() -> bool:
	return OS.get_cmdline_user_args().has("--demo-dev")
static func practice_encounter(base: Dictionary) -> Dictionary:
	var result:=base.duplicate(true)
	result.boss_start_hp=BOSS_HP
	result.phase_locks=[{"phase":2,"hp_threshold":36,"shield_gain":5},{"phase":3,"hp_threshold":16,"shield_gain":8}]
	return result
static func summary_text() -> String:
	return "预设牌组 · %d张\n核心生命%d  /  熔炉守卫生命%d"%[DECK_COUNT,PLAYER_HP,BOSS_HP]

static func later_turn_draw_count() -> int:
	if OS.get_cmdline_user_args().has("--demo-turn-draw=2"):return 2
	if OS.get_cmdline_user_args().has("--demo-turn-draw=1"):return 1
	return 1
