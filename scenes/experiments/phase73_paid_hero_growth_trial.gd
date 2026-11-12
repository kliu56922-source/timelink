extends "res://scenes/experiments/phase67_deferred_ember_trial.gd"
const Growth := preload("res://core/battle/paid_hero_growth_trial.gd")
@export_enum("original","paid-hero-growth") var growth_profile := "paid-hero-growth"
var hero_growth: RefCounted
var _growth_button: Button
var _growth_confirm: ConfirmationDialog
var _growth_pending_uid := 0
var _growth_pending_quote: Dictionary = {}

func _setup_game() -> void:
	hero_growth=Growth.new(growth_profile)
	super._setup_game()
	call_deferred("_build_growth_control")

func _build_growth_control() -> void:
	if is_instance_valid(_growth_button): return
	var layer := CanvasLayer.new()
	layer.name="PaidHeroGrowthControls";layer.layer=30;add_child(layer)
	_growth_button=Button.new();_growth_button.name="GrowthButton"
	_growth_button.text="炉心精炼 · 查看费用"
	_growth_button.position=Vector2(16,432);_growth_button.size=Vector2(192,42)
	_growth_button.tooltip_text="独立候选：升格英雄以5热和指令换长期点。先预览，再确认。"
	layer.add_child(_growth_button);_growth_button.pressed.connect(_open_growth_preview)
	_growth_confirm=ConfirmationDialog.new();_growth_confirm.name="GrowthConfirmation"
	_growth_confirm.title="炉心精炼 · 付费转换"
	_growth_confirm.ok_button_text="支付并精炼";_growth_confirm.cancel_button_text="取消"
	_growth_confirm.min_size=Vector2i(480,220);add_child(_growth_confirm)
	_growth_confirm.confirmed.connect(_confirm_growth)
	_growth_confirm.canceled.connect(func(): _growth_pending_uid=0;_growth_pending_quote={})
	_growth_button.visible=growth_profile=="paid-hero-growth"

func current_growth_actor() -> CardData:
	if battle==null or context==null: return null
	var receipt: Dictionary=battle.get_ascension_barrier_trial_status().get("last_receipt",{})
	for actor: CardData in context.player.field:
		if actor.card_id=="A01" and actor.get_instance_id()==int(receipt.get("target_runtime_id",0)): return actor
	return null

func _growth_reason(code: String) -> String:
	return {"disabled":"此对照关未开启精炼。","ascended_source_missing":"需要已升格且仍在场上的炉躯。",
		"unavailable":"等待战斗准备完毕。","native_ascension_not_proven":"需要由燃芯实际升格的炉躯。",
		"insufficient_heat":"需要至少5热。","insufficient_command_points":"当前指令不足。",
		"summoning_sickness":"英雄刚登场，下个己方回合再精炼。","not_player_turn":"请在己方行动窗口使用。",
		"already_used_this_turn":"本回合已精炼，下一回合再试。","outside_L3_L4_trial":"此候选仅用于L3、L4续成长。",
		"resolution_busy":"正在结算，请稍后。","battle_ended":"对局已经结束。","backlash_restricted":"反噬期间不可精炼。",
		"payment_backlash_boundary":"此次指令支付会触发反噬，此候选暂不允许。","withdraw_first":"请先撤离驻军。",
		"source_not_live_on_board":"英雄已离场或失效。"}.get(code,"当前条件不满足。")

func _open_growth_preview() -> void:
	_growth_button.text="炉心精炼 · 查看费用"
	var actor := current_growth_actor()
	var q: Dictionary=hero_growth.inspect(battle,actor)
	_growth_pending_uid=0;_growth_pending_quote={}
	_growth_confirm.get_ok_button().disabled=not q.ok
	if q.ok:
		_growth_pending_uid=actor.get_instance_id();_growth_pending_quote=q.duplicate(true)
		_growth_confirm.dialog_text="支付 %d 指令（剩余 %d），热量 %d → %d。\n获得5长期点：L%d / %d充能 → L%d / %d充能。\n每回合一次；不会立即恢复指令、不造成伤害。\n仍可用剩余指令行动；普通OD和仪式门槛不变。\n候选规则，尚未证明更容易通关。" % [q.command_cost,q.remaining_points,q.heat_before,q.heat_after,q.layer_before,q.charge_before,q.layer_after,q.charge_after]
	else: _growth_confirm.dialog_text=_growth_reason(str(q.reason))
	_growth_confirm.popup_centered()

func _confirm_growth() -> void:
	var actor := current_growth_actor()
	var pending := _growth_pending_uid
	var original := _growth_pending_quote.duplicate(true)
	_growth_pending_uid=0;_growth_pending_quote={}
	if actor==null or actor.get_instance_id()!=pending: return
	# Stale visible cost/benefit requires a fresh preview, never silently repays.
	if hero_growth.inspect(battle,actor)!=original:
		_growth_button.text="状态已变化 · 重新查看";return
	var receipt: Dictionary=hero_growth.execute(battle,actor)
	_growth_button.text="炉心精炼 · 查看费用" if receipt.get("ok",false) else "条件已变化 · 查看"
	print("[PAID_HERO_GROWTH] ",JSON.stringify(receipt))

func restart_gb1_battle() -> void:
	if _gb1_restarting:return
	_gb1_restarting=true
	var path := "res://scenes/experiments/phase73_paid_hero_growth_trial.tscn" if growth_profile=="paid-hero-growth" else "res://scenes/experiments/phase73_original_growth_trial.tscn"
	var err := get_tree().change_scene_to_file(path)
	if err!=OK: _gb1_restarting=false;push_error("Paid growth restart failed: %d" % err)
