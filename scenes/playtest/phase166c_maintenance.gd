extends "res://scenes/playtest/phase166b_deployment_combat.gd"
const ORDER166C=["B04","P02","B01","B02","B03","P05","P02","P05","B01","S02","P08","B02","B03","P10","B05","S03","P11","R01","P13"]
var ready166c:=false
var support166c: Node
var support_panel166c: CanvasLayer
var support_fx166c: Control
var _support_nav166c:=""
func _create_battle_system() -> BattleSystem:return preload("res://core/battle/maintenance_battle_system.gd").new()
func _gb1_prepare_startup() -> void:
	super._gb1_prepare_startup()
	if not _gb1_startup_ok:return
	_gb1_selected_cards.clear();var seen: Array=[]
	for id: String in ORDER166C:
		var template: CardData=_gb1_cards_by_id[id]
		var chosen:=CardData.clone_card_entity(template) if id in seen else template
		if chosen!=template:_gb1_owned_cards.append(chosen)
		_gb1_selected_cards.append(chosen);seen.append(id)
func _ready() -> void:
	await super._ready()
	support166c=preload("res://battle/analysis/maintenance_runner.gd").new();add_child(support166c);support166c.setup(self)
	var layer166c:=CanvasLayer.new();layer166c.layer=62;add_child(layer166c)
	support_fx166c=preload("res://ui/maintenance_board_fx.gd").new();layer166c.add_child(support_fx166c);support_fx166c.setup(self)
	support_panel166c=preload("res://ui/maintenance_panel.gd").new();add_child(support_panel166c);support_panel166c.setup(self)
	support166c.changed.connect(support_panel166c.sync)
	recipe_panel166.entry.pressed.disconnect(recipe_panel166.open);recipe_panel166.entry.pressed.connect(_open_operations166c)
	recipe_panel166.button(recipe_panel166.select_row,"维护已有单位",support_panel166c.open)
	get_node("IntegratedPlaytestTools").guide_window.dialog_text+="\n166C：交战后，连续操作入口可维护已有场面。选手牌素材P02/P05→修复/补位→目标格→确认。修复最多2HP；补位只补离场的衍生学徒且保留休整。每次1指令/热+2/负荷+1，每回合一次、全场两次、补学徒一次。短演出可×4/跳过；不刷新行动或整套展开次数。独立19张灰盒牌序，两种key各两张。"
	ready166c=true
func _open_operations166c() -> void:
	if not ready166c:return
	if battle.recipe166_snapshot().used>0 and not battle.preparation_active166b():support_panel166c.open()
	else:support_panel166c.dismiss();recipe_panel166.open()
func _process(delta: float) -> void:
	super._process(delta)
	if ready166c:phase_label166b.text=phase_label166b.text.replace("166B","166C")
func _refresh_weakpoint162a() -> void:
	super._refresh_weakpoint162a()
	if is_instance_valid(weakpoint_label):weakpoint_label.text=weakpoint_label.text.replace("166B ","166C ")
func _has_non_presentation_end_turn_busy(drag_takeover_card: CardData=null) -> bool:
	if ready166c and support166c.running:return true
	return super._has_non_presentation_end_turn_busy(drag_takeover_card)
func axis155_native_ready() -> bool:
	if ready166c and support166c.running:return false
	return super.axis155_native_ready()
func integrated_navigation_ready() -> bool:
	if ready166c and support166c.running:return false
	return super.integrated_navigation_ready()
func _input(event: InputEvent) -> void:
	if _exit_modal_active:return
	if not ready166c:super._input(event);return
	if event is InputEventMouse:
		if support_panel166c.owns_pointer(event.position):return
		if is_instance_valid(_view_controls) and _view_controls._exit_button.get_global_rect().has_point(event.position):return
	if support166c.running:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_ESCAPE:support166c.skip()
			elif event.keycode==KEY_SPACE:support166c.accelerate()
		get_viewport().set_input_as_handled();return
	if support_panel166c.panel.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_ESCAPE:support_panel166c.dismiss();get_viewport().set_input_as_handled();return
			if event.keycode==KEY_ENTER:support_panel166c.submit();get_viewport().set_input_as_handled();return
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			if _end_turn_control.get_global_rect().has_point(event.position):support_panel166c.dismiss();return
			support_panel166c.pointer(event.position);get_viewport().set_input_as_handled();return
	super._input(event)
func _coordinates_needed164() -> bool:
	return super._coordinates_needed164() or (ready166c and support_panel166c.panel.visible and support_panel166c.selecting)
func _on_card_clicked(card_ui: CardUI) -> void:
	if ready166c and support166c.running:return
	if ready166c:support_panel166c.dismiss()
	await super._on_card_clicked(card_ui)
func _on_building_interact(card: CardData) -> void:
	if ready166c and support166c.running:return
	if ready166c:support_panel166c.dismiss()
	await super._on_building_interact(card)
func _open_monster_command_menu(card: CardData) -> void:
	if ready166c and support166c.running:return
	if ready166c:support_panel166c.dismiss()
	super._open_monster_command_menu(card)
func _on_end_turn() -> void:
	if ready166c and support166c.running:return
	if ready166c:support_panel166c.dismiss()
	await super._on_end_turn()
func axis155_navigate(nav: String) -> void:
	if not ready166c:return
	if support166c.running:_support_nav166c=nav;support166c.skip();return
	if recipe166.running:_recipe_nav166=nav;recipe166.skip();return
	if advance165.running:_advance_nav165=nav;advance165.stop("导航");return
	if axis155.running:_axis155_navigation=nav;axis155.stop("导航");return
	if nav not in ["restart","home"] or _gb1_restarting or not axis155_native_ready():return
	support_panel166c.dismiss();recipe_panel166.dismiss();advance_panel165.dismiss();advance165.stop("navigation");axis155.stop("navigation");_gb1_restarting=true
	if nav=="home":_cleanup_structure_presentation_lifecycle(&"return_to_menu");_cancel_monster_summon_interaction(&"return_to_menu")
	var target: String="res://scenes/playtest/phase166c_maintenance.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn"
	var error:=get_tree().change_scene_to_file(target)
	if error!=OK:_gb1_restarting=false;push_error("166C navigation failed")
func support166c_finished() -> void:
	if not _support_nav166c.is_empty():
		var nav:=_support_nav166c;_support_nav166c="";axis155_navigate(nav)
func _set_building_replace_highlights(active: bool) -> void:
	# A retired derived card can be freed one frame before its 3D token.
	# Validate the raw metadata before casting, including immediate scene exit.
	for token: Variant in _card_token_nodes.values():
		if not is_instance_valid(token):continue
		var raw: Variant=token.get_meta("card",null)
		var card: CardData=raw as CardData if is_instance_valid(raw) else null
		var eligible: bool=active and token.get_meta("side","")=="player" and token.get_meta("zone","")=="back" and card!=null and card.is_building_card()
		var carrier: Node=token.get_node_or_null("CardCarrier")
		if is_instance_valid(carrier) and carrier.has_method("set_replacement_target_highlight"):carrier.set_replacement_target_highlight(eligible)
