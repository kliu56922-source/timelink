extends "res://scenes/experiments/phase73_paid_hero_growth_trial.gd"
## Explicit partial amount; the original fixed-five entry remains independent.
@export_enum("partial","fixed-five") var amount_profile := "partial"
var _growth_amount: OptionButton

func _setup_game() -> void:
	growth_profile="paid-hero-growth" if amount_profile=="fixed-five" else "partial-hero-growth"
	super._setup_game()

func _build_growth_control() -> void:
	super._build_growth_control()
	_growth_button.visible=true
	_growth_button.tooltip_text="选择实际支付的热量，再查看当前指令费用与长期点。每回合一次。"
	if is_instance_valid(_growth_amount):return
	_growth_amount=OptionButton.new();_growth_amount.name="GrowthAmount"
	_growth_amount.position=Vector2(16,480);_growth_amount.size=Vector2(192,36)
	for amount: int in range(1,6):_growth_amount.add_item("精炼%d热 → %d长期点"%[amount,amount],amount)
	_growth_amount.select(4);_growth_amount.disabled=amount_profile=="fixed-five"
	_growth_button.get_parent().add_child(_growth_amount)

func selected_growth_amount() -> int:
	return _growth_amount.get_selected_id() if is_instance_valid(_growth_amount) else 5

func _open_growth_preview() -> void:
	_growth_button.text="炉心精炼 · 查看费用"
	var actor:=current_growth_actor();var amount:=selected_growth_amount()
	var q: Dictionary=hero_growth.inspect(battle,actor,amount)
	_growth_pending_uid=0;_growth_pending_quote={}
	_growth_confirm.get_ok_button().disabled=not q.ok
	if q.ok:
		_growth_pending_uid=actor.get_instance_id();_growth_pending_quote=q.duplicate(true)
		_growth_confirm.dialog_text="支付 %d 指令（剩余 %d），热量 %d → %d。\n获得%d长期点：L%d / %d充能 → L%d / %d充能。\n每回合一次；不会立即恢复指令、不造成伤害。\n仍可用剩余热量补给、剩余指令行动。\n候选规则，尚未证明更容易通关。"%[q.command_cost,q.remaining_points,q.heat_before,q.heat_after,amount,q.layer_before,q.charge_before,q.layer_after,q.charge_after]
	elif q.reason==&"insufficient_heat":_growth_confirm.dialog_text="当前热量不足以支付所选%d热。"%amount
	elif q.reason==&"invalid_growth_amount":_growth_confirm.dialog_text="请重新选择可用的精炼热量。"
	else:_growth_confirm.dialog_text=_growth_reason(str(q.reason))
	_growth_confirm.popup_centered()

func _confirm_growth() -> void:
	var actor:=current_growth_actor();var pending:=_growth_pending_uid
	var original:=_growth_pending_quote.duplicate(true)
	_growth_pending_uid=0;_growth_pending_quote={}
	if actor==null or actor.get_instance_id()!=pending:return
	var amount:=selected_growth_amount()
	if hero_growth.inspect(battle,actor,amount)!=original:
		_growth_button.text="状态已变化 · 重新查看";return
	var receipt: Dictionary=hero_growth.execute(battle,actor,amount)
	_growth_button.text="炉心精炼 · 查看费用" if receipt.get("ok",false) else "条件已变化 · 查看"
	print("[PAID_HERO_GROWTH] ",JSON.stringify(receipt))

func restart_gb1_battle() -> void:
	if _gb1_restarting:return
	_gb1_restarting=true
	var path:="res://scenes/experiments/phase76_partial_hero_growth_trial.tscn" if amount_profile=="partial" else "res://scenes/experiments/phase76_fixed_hero_growth_trial.tscn"
	var err:=get_tree().change_scene_to_file(path)
	if err!=OK:_gb1_restarting=false;push_error("Partial growth restart failed: %d"%err)
