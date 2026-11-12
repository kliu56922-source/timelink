extends "res://scenes/playtest/phase168b2_maintenance.gd"
var ready168c:=false
var compact168c: Node
func _ready() -> void:
 await super._ready()
 var old: Variant=support_panel166c;var legacy: Button=recipe_panel166.select_row.get_child(recipe_panel166.select_row.get_child_count()-1)
 legacy.pressed.disconnect(old.open);old.free()
 support_panel166c=preload("res://ui/compact_maintenance_panel_168c.gd").new();add_child(support_panel166c);support_panel166c.setup(self)
 support166c.changed.connect(support_panel166c.sync);legacy.pressed.connect(support_panel166c.open)
 _adapt168b(training_panel168a,preload("res://ui/training_panel_168c.gd"),["owner_ref","entry","window","text","card_select","status","tab168a"])
 _adapt168b(journal168a,preload("res://battle/analysis/training_journal_168c.gd"),["owner_ref","entries","_last_state","_elapsed","started_us"])
 _adapt168b(flow166d,preload("res://ui/training_flow_168c.gd"),["scene_ref","body_button","maintenance167d"])
 compact168c=preload("res://ui/compact_actions_168c.gd").new();add_child(compact168c);compact168c.setup(self)
 training_panel168a.entry.text="168C 快捷处理 · 规则与记录";training_panel168a.window.title="168C 快捷处理 · 不计普通胜率";_playtest.run_label="168C_compact_not_winrate"
 get_node("IntegratedPlaytestTools").guide_window.dialog_text="168C：点单位后，可直接选普通攻击敌棋或明确素材修复，再确认。补位合并素材与用途，再选原合法格和确认。普通攻击不自动移动/出牌/强化，不接续要害；原手动、分步、路线和拖拽保留。费用、休整与限次不变。"
 ready168c=true;training_panel168a.refresh168a();flow166d.refresh();journal168a.capture168a("compact_training_ready")
func maintenance_situation168b2() -> Dictionary:
 var facts: Dictionary=super.maintenance_situation168b2()
 if facts.is_empty():return facts
 facts.mode="168C_compact_actions"
 facts.hint=str(facts.hint).replace("点单位→维护此单位→选使魔或炉基座→确认。","点单位→明确素材修复→确认；也可走原维护入口。").replace("点连续操作→使魔或炉基座→补回学徒→落点→确认。","点连续操作→素材＋补位一起选→落点→确认。")
 return facts
func training_snapshot168a() -> Dictionary:
 var state: Dictionary=super.training_snapshot168a();state.mode="168C_compact_actions";return state
func _refresh_weakpoint162a() -> void:
 super._refresh_weakpoint162a()
 if is_instance_valid(weakpoint_label):weakpoint_label.text=weakpoint_label.text.replace("168B2 ","168C ")
func _end_battle(victory: bool) -> void:
 if battle_ended:return
 super._end_battle(victory)
 if is_instance_valid(result_panel):result_panel.info_label.text=result_panel.info_label.text.replace("168B2训练完成","168C训练完成")
func _compact_preview_open168c() -> bool:return is_instance_valid(compact168c) and is_instance_valid(compact168c.dialog) and compact168c.dialog.visible
func axis155_native_ready() -> bool:return not _compact_preview_open168c() and super.axis155_native_ready()
func _on_end_turn() -> void:
 if _compact_preview_open168c():return
 await super._on_end_turn()
func _has_non_presentation_end_turn_busy(drag_takeover_card: CardData=null) -> bool:return _compact_preview_open168c() or super._has_non_presentation_end_turn_busy(drag_takeover_card)
func _input(event: InputEvent) -> void:
 if _compact_preview_open168c():return
 super._input(event)
func axis155_commit(step: Dictionary) -> Dictionary:
 if not step.get("compact168c",false):return await super.axis155_commit(step)
 var actor: CardData=axis155.resolve(step.uid,"field");var target: CardData=axis155.resolve(step.target_uid,"enemy")
 if actor==null or target==null or battle.get_unit_cell(target)!=step.cell:return {"ok":false,"reason":"原单位或目标已变化"}
 _selected_attacker=actor
 var receipt: Dictionary=battle.execute_card_piece_action(actor,&"attack",null,target,{"enhanced_requested":false,"payment_mode":&"none"}) if actor.piece_enabled and actor.card_family=="monster" else battle.execute_unit_command(actor,"attack",target)
 await _handle_attack_result(receipt)
 for i in range(600):
  if axis155_native_ready():break
  await get_tree().process_frame
 return receipt
func axis155_navigate(nav: String) -> void:
 if not ready168c or nav not in ["restart","home"]:return
 if _compact_preview_open168c():compact168c.cancel_attack168c()
 if is_instance_valid(training_panel168a):training_panel168a.close168a()
 if building_committing167a:return
 if _building_preview_open167a():building_preview167a.hide();building_uid167a=0
 if body_busy166d or transition166d:_nav166d=nav;return
 if support166c.running:_support_nav166c=nav;support166c.skip();return
 if recipe166.running:_recipe_nav166=nav;recipe166.skip();return
 if advance165.running:_advance_nav165=nav;advance165.stop("导航");return
 if axis155.running:_axis155_navigation=nav;axis155.stop("导航");return
 if _gb1_restarting or not axis155_native_ready():return
 targets167b.dismiss();support_panel166c.dismiss();recipe_panel166.dismiss();advance_panel165.dismiss();advance165.stop("navigation");axis155.stop("navigation");_gb1_restarting=true
 if nav=="home":_cleanup_structure_presentation_lifecycle(&"return_to_menu");_cancel_monster_summon_interaction(&"return_to_menu")
 var path: String="res://scenes/playtest/phase168c_compact.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn"
 if get_tree().change_scene_to_file(path)!=OK:_gb1_restarting=false;push_error("168C navigation failed")

