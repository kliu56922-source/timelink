extends "res://core/battle/key_recipe_battle_system.gd"
## Explicit safe preparation content. Unknown/new content waits for combat.
const SAFE_PREPARATION=["P02","P05","P08","P13","S01","X01","B04","B05"]
var opening166b=preload("res://core/battle/opening_phase_166b.gd").new()
var _opening_card: CardData
func preparation_active166b() -> bool:return opening166b.preparation_active()
func init(ctx: BattleContext) -> void:
	super.init(ctx)
	ctx.player.encounter_damage_allowed=opening166b.damage_allowed
	ctx.enemy.encounter_damage_allowed=opening166b.damage_allowed
	ctx.enemy.opening_intent_provider=opening_intent166b
func opening_intent166b() -> CardData:
	if not preparation_active166b() or opening166b.boss_prepared:return null
	if not is_instance_valid(_opening_card):
		_opening_card=CardData.new();add_child(_opening_card)
		_opening_card.card_id="B166_SETUP";_opening_card.card_name="Pressure Setup";_opening_card.display_name="蓄压护盾"
		_opening_card.short_description="首轮准备：热+2、盾+2，不攻击"
		_opening_card.description="首轮准备保留原热量增长+2，获得护盾2，不攻击。下一轮恢复正常出牌；部署计入总时长。"
		_opening_card.board_zone=CardData.BoardZone.INSTANT
	return _opening_card
func boss_play_card(card: CardData) -> void:
	if card==_opening_card and not preparation_active166b():return
	if not preparation_active166b():super.boss_play_card(card);return
	if card!=_opening_card or not opening166b.commit_boss_preparation():return
	context.enemy.add_boss_shield(2,"166B 蓄压护盾")
	_add_enemy_card_to_graveyard(card)
	context.boss_action_event.emit("prepare","蓄压护盾","护盾+2，不攻击；即将进入交战")
func get_boss_tactical_action_candidates() -> Array[Dictionary]:
	return [] if preparation_active166b() else super.get_boss_tactical_action_candidates()
func execute_boss_tactical_candidate(candidate: Dictionary) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.execute_boss_tactical_candidate(candidate)
func resolve_boss_siege_intent() -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.resolve_boss_siege_intent()
func _on_boss_terrain_tactical_start() -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super._on_boss_terrain_tactical_start()
func _safe_card166b(card: CardData) -> bool:
	return is_instance_valid(card) and card.card_id in SAFE_PREPARATION
func get_card_play_status(card: CardData,ignore_active_building_limit: bool=false,ignore_back_row_limit: bool=false) -> Dictionary:
	if preparation_active166b() and not _safe_card166b(card):return opening166b.refusal()
	return super.get_card_play_status(card,ignore_active_building_limit,ignore_back_row_limit)
func play_card(card: CardData,requested_lane: int=-1,requested_cell: Vector2i=INVALID_GRID_CELL,cast_options: Dictionary={}) -> Dictionary:
	if preparation_active166b() and not _safe_card166b(card):return opening166b.refusal()
	return super.play_card(card,requested_lane,requested_cell,cast_options)
func get_card_piece_status(card: CardData,action_id: StringName,anchor: Variant=null,target: Variant=null,options: Dictionary={}) -> Dictionary:
	if preparation_active166b() and (action_id!=&"play" or not _safe_card166b(card)):return opening166b.refusal()
	return super.get_card_piece_status(card,action_id,anchor,target,options)
func execute_card_piece_action(card: CardData,action_id: StringName,anchor: Variant=null,target: Variant=null,options: Dictionary={}) -> Dictionary:
	if preparation_active166b() and (action_id!=&"play" or not _safe_card166b(card)):return opening166b.refusal()
	return super.execute_card_piece_action(card,action_id,anchor,target,options)
func register_unit(card: CardData,owner_side: StringName,summoned_this_turn: bool,requested_lane: int=-1,requested_cell: Vector2i=INVALID_GRID_CELL):
	var state: Variant=super.register_unit(card,owner_side,summoned_this_turn,requested_lane,requested_cell)
	if state!=null:state.encounter_damage_allowed=opening166b.damage_allowed
	return state
func get_unit_command_status(card: CardData,command_type: String,target: Variant=null,payload: Dictionary={}) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.get_unit_command_status(card,command_type,target,payload)
func advance_actor_status(card: CardData) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.advance_actor_status(card)
func can_monster_attack(card: CardData) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.can_monster_attack(card)
func resolve_monster_attack(attacker: CardData,target: CardData=null,release_bonus: int=0) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.resolve_monster_attack(attacker,target,release_bonus)
func resolve_monster_attack_player_core(attacker: CardData) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.resolve_monster_attack_player_core(attacker)
func get_unit_move_cell_status(card: CardData,target_cell: Vector2i,source: StringName=MOVE_SELF) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.get_unit_move_cell_status(card,target_cell,source)
func get_unit_move_status(card: CardData,target_lane: int,source: StringName=MOVE_SELF) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.get_unit_move_status(card,target_lane,source)
func get_overdrive_core_breach_status(attacker: CardData) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.get_overdrive_core_breach_status(attacker)
func get_arsenal_play_status(card: CardData) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.get_arsenal_play_status(card)
func get_final_arsenal_play_status(card: CardData,_player) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.get_final_arsenal_play_status(card,_player)
func can_ascend_card(base_card: CardData,target_card: CardData,_player) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.can_ascend_card(base_card,target_card,_player)
func get_building_interface_status(card: CardData,player: Player) -> Dictionary:
	if preparation_active166b() and not _safe_card166b(card):return opening166b.refusal()
	return super.get_building_interface_status(card,player)
func get_unit_skill_command_status(card: CardData,skill_id: StringName) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.get_unit_skill_command_status(card,skill_id)
func execute_unit_skill_command(card: CardData,skill_id: StringName,target,options: Dictionary={}) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.execute_unit_skill_command(card,skill_id,target,options)
func get_core_command_status(command_id: StringName,target=null) -> Dictionary:
	if preparation_active166b() and command_id!=ODCoreCommandRuleSnapshotClass.VENT:return opening166b.refusal()
	return super.get_core_command_status(command_id,target)
func get_od_release_source_status(source: CardData) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.get_od_release_source_status(source)
func execute_od_release(side: String,source: CardData,target: Variant,options: Dictionary={}) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.execute_od_release(side,source,target,options)
func get_final_convergence_status(side: String="player") -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.get_final_convergence_status(side)
func execute_final_convergence(side: String,source: CardData,target: Variant,options: Dictionary={}) -> Dictionary:
	return opening166b.refusal() if preparation_active166b() else super.execute_final_convergence(side,source,target,options)
