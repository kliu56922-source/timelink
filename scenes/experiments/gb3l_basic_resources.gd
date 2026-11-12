extends "res://scenes/experiments/gb3k_steam_package.gd"
## Incremental public-card experiment. Two resource cards replace two deck slots.
const BASIC_ENTRY := "res://scenes/experiments/gb3l_basic_resources.tscn"
const BASIC_ORDER: Array[String] = ["B04","S01","S02","P05","B05","R01","P07","P10","P08","P06","P02","P22","P23","P03","P09","P11","P14","P13","S03"]
func _load_gb1_packs() -> Array:
	var packs := super._load_gb1_packs()
	var raw=JSON.parse_string(FileAccess.get_file_as_string("res://data/experiments/basic_resource_cards.json"))
	if not raw is Dictionary or raw.get("schema_version")!=1 or not raw.get("cards") is Array:
		_gb1_load_problems.append("公共资源牌数据无效");return packs
	var loader := GB1Catalog.new()
	var cards: Array[CardData]=[]
	for row in raw.cards:
		if not row is Dictionary:
			_gb1_load_problems.append("公共资源牌条目无效");continue
		var card := loader.convert_to_carddata(row)
		card.art_path="";card.thumb_path="";card.detail_path=""
		cards.append(card)
	loader.free();packs.append(cards)
	return packs
func _gb1_fixed_order_problems(by_id: Dictionary) -> Array[String]:
	var problems := super._gb1_fixed_order_problems(by_id)
	for id in ["B04","B05"]:
		if not by_id.has(id): problems.append("基础资源牌缺失："+id)
	return problems
func _gb1_prepare_startup() -> void:
	super._gb1_prepare_startup()
	if not _gb1_startup_ok: return
	_gb1_selected_cards.clear()
	for id in BASIC_ORDER: _gb1_selected_cards.append(_gb1_cards_by_id[id])
func _setup_game() -> void:
	super._setup_game()
	battle.configure_basic_card_trial(true)
func _ready() -> void:
	await super._ready()
	if not _gb1_startup_ok: return
	_expansion_guide._button.text="基础牌 · 查看用途与路线"
	_expansion_guide._dialog.title="蓄火与排压：资源选择试制"
	_refresh_tables()
func _build_expansion_route_view() -> Dictionary:
	var view := super._build_expansion_route_view()
	view.text="蓄火：热量+2，可用于调度、建筑主动或留下等待OD。\n排压：付热量1，Depth-2；Depth为0时保留。它不会增加仪式控制准备。\n两种牌无需选择地块，同名每回合一次。这里只先试供能/减压，打击、赋刃、护卫基础版待加入。\n\n"+str(view.text)
	return view
func restart_gb1_battle() -> void:
	if _gb1_restarting: return
	_gb1_restarting=true
	if battle!=null and battle.reaction_trial!=null: battle.reaction_trial.finish_event()
	var err := get_tree().change_scene_to_file(BASIC_ENTRY)
	if err!=OK:
		_gb1_restarting=false;push_error("Basic resource restart failed: %d" % err)
