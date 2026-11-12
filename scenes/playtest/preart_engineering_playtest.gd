extends "res://scenes/playtest/preart_training_playtest.gd"
## Optional public acquisition route. Uses existing card and construction authority.
const FUSION_PATH="res://scenes/playtest/preart_engineering_playtest.tscn"
func _gb1_prepare_startup() -> void:
	super._gb1_prepare_startup()
	if not _gb1_startup_ok:return
	if _gb1_selected_cards.size()!=DemoProfile.DECK_COUNT:
		_gb1_startup_ok=false;_gb1_startup_problems.append("试玩牌组张数与入口配置不一致")
		return
	var cooling: CardData=_gb1_cards_by_id.get("P13")
	var strike_index:=-1
	var guard_index:=-1
	for i in range(_gb1_selected_cards.size()):
		if _gb1_selected_cards[i].card_id=="B01" and strike_index<0:strike_index=i
		if _gb1_selected_cards[i].card_id=="B03":guard_index=i
	if cooling!=null and strike_index>=0 and guard_index>=6:
		# Keep the opening guard; move its later duplicate's slot to the first strike.
		# Composition remains 19 with exactly one B03 exchanged for canonical P13.
		var removed: CardData=_gb1_selected_cards[guard_index]
		_gb1_selected_cards[guard_index]=_gb1_selected_cards[strike_index]
		_gb1_selected_cards[strike_index]=cooling
		if removed not in _gb1_owned_cards:removed.free()
		return
	_gb1_startup_ok=false
	push_error("Engineering fusion startup requires original P13 and a B03 slot")
func _ready() -> void:
	await super._ready()
	if not _gb1_startup_ok:return
	var tools: Variant=get_node("IntegratedPlaytestTools")
	tools.toggle.text="营造 · 战术工具 ▾"
	tools.guide_window.dialog_text="工程融合练习：玩家80生命 / Boss55生命，19张牌。
热沉装置＝冷却设施；换一张护卫，册仅预备围护。

手牌直建：拖热沉装置到合法格，按原出牌流程确认。
成功才在本场发现冷却图纸；查看、取消、失败不发现。
整备施工：先付费安排当前计划，再将手中冷却牌
整备进空工程位；不算出牌，不推进连锁。
工程册下回合会补计划，整备请在当前空位时完成。
稳筑2指令，下个己方回合完工；急筑另花2热。
施工占地可受击；完工后在设施入口主动使用。

普通OD需7热；升格仪式另需8热与实际准备。
指令累计提高Depth；冷却设施使用可为后续行动减压。
炉心指令可再部署；建筑不能占用需要退守的完整空间。
冷却施工1×1/1×2/2×2耐久2/3/4，原能力和费用不变。
墙门沿格边，围护仍1×1；预览后再确认，可取消。
图纸发现只限本场；重开恢复初始牌组和工程册。"
func restart_gb1_battle() -> void:
	if _gb1_restarting or not integrated_navigation_ready():return
	_gb1_restarting=true
	var err:=get_tree().change_scene_to_file(FUSION_PATH)
	if err!=OK:_gb1_restarting=false;push_error("Engineering fusion restart failed: %d"%err)

func _get_player_turn_draw_count() -> int:
	return DemoProfile.later_turn_draw_count()
