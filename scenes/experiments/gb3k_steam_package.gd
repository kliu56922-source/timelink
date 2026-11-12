extends "res://scenes/experiments/gb3j_build_orientation.gd"
## Separate playable first package; all prior construction/OD authority is inherited.
const STEAM_ENTRY := "res://scenes/experiments/gb3k_steam_package.tscn"
const STEAM_ORDER: Array[String] = ["S01","S02","P05","P01","P04","R01","P07","P10","P08","P06","P02","P22","P23","P03","P09","P11","P14","P13","S03"]

func _load_gb1_packs() -> Array:
	var packs := super._load_gb1_packs()
	for path in ["res://data/experiments/steam_first_package.json","res://data/experiments/steam_recovery_package.json"]:
		var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not raw is Dictionary or raw.get("schema_version") != 1 or not raw.get("cards") is Array:
			_gb1_load_problems.append("蒸汽补强包数据无效："+path)
			continue
		var loader := GB1Catalog.new()
		var cards: Array[CardData] = []
		for row in raw.cards:
			if not row is Dictionary:
				_gb1_load_problems.append("蒸汽补强包卡牌数据无效")
				continue
			var card := loader.convert_to_carddata(row)
			card.art_path=""; card.thumb_path=""; card.detail_path=""
			cards.append(card)
		loader.free()
		packs.append(cards)
	return packs

func _gb1_fixed_order_problems(by_id: Dictionary) -> Array[String]:
	var problems := super._gb1_fixed_order_problems(by_id)
	for id in ["S01","S02","S03"]:
		if not by_id.has(id): problems.append("蒸汽补强卡缺失："+id)
	return problems

func _gb1_prepare_startup() -> void:
	super._gb1_prepare_startup()
	if not _gb1_startup_ok: return
	_gb1_selected_cards.clear()
	for id in STEAM_ORDER: _gb1_selected_cards.append(_gb1_cards_by_id[id])

func _setup_game() -> void:
	super._setup_game()
	battle.configure_steam_package_trial(true)

func _ready() -> void:
	await super._ready()
	if not _gb1_startup_ok: return
	_expansion_guide._button.text = "双轴展开 · 查看参考路线"
	_expansion_guide._dialog.title = "蒸汽战团＋炉心筑城"

func _build_expansion_route_view() -> Dictionary:
	var view := super._build_expansion_route_view()
	if battle == null or battle.steam_package_trial == null: return view
	var text := "蒸汽单轴：锅炉学徒登场（热量+1）→战团调度付热量1找热流导体→热流导体找连锁导体。
"
	text += "建筑混轴：先建炉基座→锅炉学徒登场找热流导体→连锁导体找炉心魔法。
"
	text += "两条路线都先把找来的牌加到手，随后正常选格登场。低层前场上限2：先形成学徒＋导体，连锁导体留手，升层或空出位置后再登场。
"
	text += "学徒没有完好建筑仍能登场；调度无蒸汽棋子、热量不足或牌库无目标时保留手牌。两种效果同名每回合一次。

"
	var dispatch: CardData = _gb1_cards_by_id["S02"]
	var status: Dictionary = battle._steam_card_play_status(dispatch)
	text += "调度当前：" + (str(status.get("preview","可用"))+"；支付热量1" if status.get("ok",false) else str(status.get("reason","不可用"))) + "

"
	var recovery: Dictionary = battle._steam_card_play_status(_gb1_cards_by_id["S03"])
	text += "拆场后续展：炉役回收付热量1，按墓地顺序回收一名蒸汽普通棋子到手；不直接复活，同名每回合一次。\n"
	text += "回收当前：" + str(recovery.get("preview",recovery.get("reason","不可用"))) + "\n\n"
	view.text = text + str(view.text)
	return view

func restart_gb1_battle() -> void:
	if _gb1_restarting: return
	_gb1_restarting=true
	if battle != null and battle.reaction_trial != null: battle.reaction_trial.finish_event()
	var err := get_tree().change_scene_to_file(STEAM_ENTRY)
	if err != OK:
		_gb1_restarting=false
		push_error("Steam package restart failed: %d" % err)
