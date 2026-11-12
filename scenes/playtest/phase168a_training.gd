extends "res://scenes/playtest/phase167d_player_loop.gd"
var ready168a:=false
var journal168a: Node
var training_panel168a: CanvasLayer
func _create_battle_system() -> BattleSystem:return preload("res://core/battle/training_battle_168a.gd").new()
func _ready() -> void:
 set_meta("player_trial",true)
 await super._ready()
 var telemetry:=preload("res://core/debug/training_telemetry_168a.gd").new()
 telemetry.adopt167a(_playtest,context);telemetry.run_label="168A_training_not_winrate";_playtest=telemetry
 context.enemy.intent_text="训练木桩：不主动进攻；保留真实玩家规则"
 context.enemy.player_name="训练木桩"
 context.enemy.notify_intent_changed();context.enemy.notify_combat_state_changed()
 journal168a=preload("res://battle/analysis/training_journal_168a.gd").new();add_child(journal168a);journal168a.setup168a(self)
 training_panel168a=preload("res://ui/training_panel_168a.gd").new();add_child(training_panel168a);training_panel168a.setup168a(self)
 var body: Button=flow166d.body_button;var maintenance: Button=flow166d.maintenance167d
 flow166d.set_script(preload("res://ui/training_flow_168a.gd"));flow166d.scene_ref=weakref(self);flow166d.body_button=body;flow166d.maintenance167d=maintenance;flow166d.process_priority=10
 var tools: Variant=get_node("IntegratedPlaytestTools")
 tools.guide_window.dialog_text="168A真实规则训练场：木桩不主动进攻；固定19张牌，保留真实费用、容量、回合、休整和次数。木桩被动护甲/领域与阶段反应仍沿用原规则。先从连续展开入口开始，准备好后点部署完成。顶部「168A训练·联动与记录」可查看起步方法、牌与记录。本模式不计普通胜率。"
 # auto-open disabled for the release build
 ready168a=true
func _training_window_open168a() -> bool:
 return ready168a and is_instance_valid(training_panel168a) and training_panel168a.window.visible
func _refresh_weakpoint162a() -> void:
 super._refresh_weakpoint162a()
 if is_instance_valid(weakpoint_label):weakpoint_label.text=weakpoint_label.text.replace("167D ","168A ")
func axis155_native_ready() -> bool:return not _training_window_open168a() and super.axis155_native_ready()
func _has_non_presentation_end_turn_busy(drag_takeover_card: CardData=null) -> bool:
 return _training_window_open168a() or super._has_non_presentation_end_turn_busy(drag_takeover_card)
func _on_end_turn() -> void:
 if _training_window_open168a():return
 await super._on_end_turn()
func _input(event: InputEvent) -> void:
 if _training_window_open168a():
  if is_instance_valid(metrics167d):metrics167d.observe167d(event)
  if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:training_panel168a.close168a()
  return
 super._input(event)
func _on_card_clicked(card_ui: CardUI) -> void:
 if _training_window_open168a():return
 await super._on_card_clicked(card_ui)
func _on_building_interact(card: CardData) -> void:
 if _training_window_open168a():return
 await super._on_building_interact(card)
func _end_battle(victory: bool) -> void:
 if battle_ended:return
 if is_instance_valid(training_panel168a):training_panel168a.close168a()
 super._end_battle(victory)
 if is_instance_valid(result_panel):
  result_panel.info_label.text="168A训练完成 · 不计普通胜率\n"+result_panel.info_label.text
  # Results are created lazily by the native ending, above the board at1000.
  var result_entry:=Button.new();result_entry.name="TrainingResultRecord168A";result_entry.text="查看 / 保存本次训练记录";result_entry.custom_minimum_size.y=36
  var result_box: Node=result_panel.info_label.get_parent();result_box.add_child(result_entry);result_box.move_child(result_entry,result_box.get_child_count()-2)
  result_entry.pressed.connect(training_panel168a.open168a)
 if is_instance_valid(journal168a):journal168a.capture168a("training_finished",{"outcome":"target_defeated" if victory else "player_defeated","counts_for_winrate":false})
func training_catalog168a() -> Array:
 var result: Array=[]
 for card: CardData in _gb1_selected_cards:
  if not is_instance_valid(card):continue
  var zone:="departed"
  for pair: Array in [["hand",context.player.hand],["field",context.player.field],["building",context.player.traps],["deck",context.player.deck],["graveyard",context.player.graveyard]]:
   if card in pair[1]:zone=pair[0];break
  var status: Dictionary={"ok":false,"reason":"需按正常抽牌取得，再检查费用与目标"}
  if zone=="hand":status=battle.get_card_play_status(card)
  elif zone=="building":status=battle.get_building_interface_status(card,context.player)
  elif zone=="field":status=battle.advance_actor_status(card)
  var note:="手动协同：以原生牌面、目标与当前资格为准；不代表已有自动配方。"
  match card.card_id:
   "P02","P05":note="自动配方的真实key；整套替代单卡登场/检索，不能再触发一遍。也可按原规则单用或作为维护素材。"
   "B01":note="手动协同：只选择敌方普通棋子；木桩部位不是合法目标。守卫情境后续168B。"
   "B02":note="手动协同：下次普通攻击增益，也计入要害耐久伤害并消耗；不提供行动/射程，不增加固定的要害击破本体伤害。"
   "B03":note="手动协同：棋子交战护送，不挡Boss法术；无敌棋时未必有用途。"
   "B04","B05":note="手动协同：真实热量/Depth控制，仍受当前状态和同名每回合限次约束。"
  result.append({"uid":card.get_instance_id(),"id":card.card_id,"name":card.get_display_name(),"description":card.description,"zone":zone,"status":status,"note":note})
 return result
func training_snapshot168a() -> Dictionary:
 var units: Array=[]
 for card: CardData in context.player.field:
  var st: Variant=battle._state_for_card(card)
  units.append({"uid":card.get_instance_id(),"id":card.card_id,"name":card.get_display_name(),"cell":battle.get_unit_cell(card),"power":battle.get_effective_unit_attack(card),"blade":battle.basic_card_trial.blade_amount(card),"escort":battle.frontline_trial.escort_amount(card),"state":st.snapshot() if st!=null else {}})
 return {"mode":"168A_training","counts_for_winrate":false,"player_round":battle.opening166b.player_round,"preparation":battle.preparation_active166b(),"player_hp":context.player.hp,"player_shield":context.player.shield,"target_hp":context.enemy.hp,"target_shield":context.enemy.boss_shield,"target_od":context.enemy.od,"target_domain":context.enemy.forge_domain_active,"target_armor":context.enemy.forge_armor_bonus,"economy":battle.get_command_economy_snapshot("player"),"heat":context.od_mode.current_od,"charge":context.od_mode.engine_charge,"load":context.od_mode.load,"depth":context.depth_pressure,"recipe":battle.recipe166_snapshot(),"support":battle.support166_snapshot(),"units":units,"buildings":context.player.traps.map(func(c):return {"uid":c.get_instance_id(),"id":c.card_id,"state":battle.get_building_state(c)}),"hand":context.player.hand.map(func(c):return {"uid":c.get_instance_id(),"id":c.card_id}),"deck_count":context.player.deck.size(),"parts":battle.get_weakpoint_snapshots(),"terminal":battle_ended}
func axis155_navigate(nav: String) -> void:
 if not ready168a or nav not in ["restart","home"]:return
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
 var path: String="res://scenes/playtest/phase168a_training.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn"
 if get_tree().change_scene_to_file(path)!=OK:_gb1_restarting=false;push_error("168A navigation failed")
