extends "res://scenes/experiments/phase76_partial_hero_growth_trial.gd"
## Private natural input policy only. No product auto-selection or state injection.
signal core_actor_selected(row: Dictionary)
var core_actor_choice_records: Array[Dictionary]=[]
func _on_core_command_button_pressed() -> void:
	super._on_core_command_button_pressed()
	if not is_instance_valid(_core_command_panel):return
	var actor: CardData=current_growth_actor()
	if actor==null or not _is_live_player_redeploy_actor(actor):return
	var panel: Variant=_core_command_panel
	var picker: OptionButton=panel._redeploy_actor
	var before := {"charge":context.get_engine_charge(),"heat":context.od_mode.current_od,"long":context.od_mode.engine_total_points,"hp":context.player.hp,"economy":battle.get_command_economy_snapshot("player"),"core":battle.get_core_command_state(),"source_state":battle.get_unit_combat_state(actor).duplicate(true)}
	var row := {"index":core_actor_choice_records.size(),"turn":context.turn_count,"source_runtime_id":actor.get_instance_id(),"source_id":actor.card_id,"source_cell":battle.get_unit_cell(actor),"selected_before":panel.get_redeploy_actor_uid(),"offered":[],"before":before}
	for i in range(picker.item_count):
		row.offered.append({"runtime_id":int(picker.get_item_metadata(i)),"label":picker.get_item_text(i)})
		if int(picker.get_item_metadata(i))==actor.get_instance_id():picker.select(i)
	row["selected_after"]=panel.get_redeploy_actor_uid()
	row["after"]={"charge":context.get_engine_charge(),"heat":context.od_mode.current_od,"long":context.od_mode.engine_total_points,"hp":context.player.hp,"economy":battle.get_command_economy_snapshot("player"),"core":battle.get_core_command_state(),"source_state":battle.get_unit_combat_state(actor).duplicate(true)}
	core_actor_choice_records.append(row);core_actor_selected.emit(row);print("[CORE_ACTOR_SELECTION] ",JSON.stringify(row))
