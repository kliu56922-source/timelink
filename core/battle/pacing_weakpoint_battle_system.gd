extends "res://core/battle/triple_weakpoint_battle_system.gd"
## 163 encounter only: both sides' guards intercept their own column.
## Clone the immutable input; default and 162A/B encounters keep radius1.
func init(ctx: BattleContext) -> void:
	super.init(ctx)
	# Ordinary scene does not inject this optional snapshot. Set it before any turn.
	configure_tactical_core_facing_rules(preload("res://core/config/game_config.gd").create_tactical_core_facing_rule_snapshot())
func configure_tactical_core_facing_rules(snapshot: RefCounted) -> void:
	var source: RefCounted=snapshot if snapshot!=null else TacticalCoreFacingRuleSnapshotClass.new({},false,[])
	var data: Dictionary=source.to_snapshot()
	data.core.guard_intercept_column_radius=0
	super.configure_tactical_core_facing_rules(TacticalCoreFacingRuleSnapshotClass.new(data,false,[]))
func configure_tactical_command_economy(snapshot: RefCounted) -> void:
	var source: RefCounted=snapshot if snapshot!=null else TacticalCommandEconomySnapshotClass.new({},false,[])
	var data: Dictionary=source.to_snapshot()
	data.pool.player_base_by_od_layer["1"]=5
	data.pool.player_base_by_od_layer["2"]=5
	super.configure_tactical_command_economy(TacticalCommandEconomySnapshotClass.new(data,false,[]))
func _find_guard_interceptor(attacker: CardData,owner_side: StringName) -> CardData:
	if attacker==null:return null
	var origin: Vector2i=get_unit_cell(attacker)
	if origin==INVALID_GRID_CELL:return null
	var defending_side: StringName=_opposite_side(owner_side)
	# Threat rank belongs to the attacker: player threatens Boss at1, Boss threatens player at3.
	var threat: int=tactical_core_facing_rules.get_threat_rank(owner_side)
	for raw in _field_for_owner(defending_side):
		var guard:=raw as CardData
		if guard==null or not guard.is_guard_card:continue
		var state: Variant=_state_for_card(guard)
		if state==null or state.is_dead():continue
		var cell: Vector2i=get_unit_cell(guard)
		if cell==INVALID_GRID_CELL or cell.x!=origin.x:continue
		if (defending_side==&"boss" and cell.y<=threat) or (defending_side==&"player" and cell.y>=threat):return guard
	return null
func resolve_monster_attack(attacker: CardData,target: CardData=null,release_bonus: int=0) -> Dictionary:
	var receipt: Dictionary=super.resolve_monster_attack(attacker,target,release_bonus)
	if receipt.get("ok",false) and receipt.get("result","")=="hit_weakpoint" and receipt.get("weakpoint_broken",false) and receipt.get("weakpoint",{}).get("id","")=="core_ring" and context.enemy.hp>0:
		var shield: int=context.enemy.boss_shield
		if shield>0:context.enemy.add_boss_shield(-shield,"Core rupture163")
		receipt["shield_broken"]=shield
		receipt.message+="，护盾清除%d"%shield
	return receipt
