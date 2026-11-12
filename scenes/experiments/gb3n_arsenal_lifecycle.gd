extends "res://scenes/experiments/gb3k_steam_package.gd"
## Separate lifecycle trial; previous fixed-order decks stay unchanged.
const ARSENAL_ENTRY := "res://scenes/experiments/gb3n_arsenal_lifecycle.tscn"
const ARSENAL_ORDER: Array[String] = ["S01","S02","P05","P15","P01","R01","P07","P10","P08","P06","P02","P22","P23","P03","P11","P14","P13","S03","P09"]
func _gb1_prepare_startup() -> void:
	super._gb1_prepare_startup()
	if not _gb1_startup_ok: return
	_gb1_selected_cards.clear()
	for id in ARSENAL_ORDER: _gb1_selected_cards.append(_gb1_cards_by_id[id])
func _setup_game() -> void:
	super._setup_game()
	# The guard/arsenal entry and its engineering successor expose existing skills.
	battle.init_monster_hero_skills(GameConfig.create_monster_hero_skill_snapshot())
func _ready() -> void:
	await super._ready()
	if not _gb1_startup_ok: return
	_expansion_guide._button.text = "守卫与合体 · 查看规则与路线"
	_expansion_guide._dialog.title = "蒸汽战团：守卫支点与合体兑现"
func _build_expansion_route_view() -> Dictionary:
	var view := super._build_expansion_route_view()
	view.text = "防守支线：P15热压壁垒兽入场护盾+5，1/6守卫保护核心相邻列；点棋子菜单的「壁垒推进」，选择自己也能原地防守；共享指令费用以菜单为准。自己或相邻友军实际受战斗伤害积压力，施放消耗压力，护盾增加2＋压力层数；不挡法术，不赠行动。刚登场须等召唤病解除。OD L3或Depth≥2时，可升格为2/5深渊束缚者，入场Depth最多-3，不能主动攻击。\n\n合体路线：先使用一次中级武库（P02→A01或P15→A04）；OD L5或Burst时，选择外场P07/P10点合体。另一素材优先为另一导体，否则按场上顺序选存活的普通蒸汽棋子。两素材入墓，支付3HP，保留所选格与朝向。\n\n合体新单位7/6，本回合不能攻击；不消耗或赠送指令。两处兵力变成一处，不能替代全部卡牌的推进与防护；对手仍可正常交战。驻军须先撤离；未满足条件时菜单显示具体原因。\n\n拆场后用S03支付1热回收普通蒸汽素材到手，再正常召唤；不直接复活，不回收武库单位。中级与终场武库各本局一次。\n\n" + str(view.text)
	return view
func restart_gb1_battle() -> void:
	if _gb1_restarting: return
	_gb1_restarting=true
	if battle != null and battle.reaction_trial != null: battle.reaction_trial.finish_event()
	var err := get_tree().change_scene_to_file(ARSENAL_ENTRY)
	if err != OK:
		_gb1_restarting=false
		push_error("Arsenal trial restart failed: %d" % err)
