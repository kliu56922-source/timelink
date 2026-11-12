extends "res://scenes/playtest/phase168a1_hand_semantics.gd"
var ready168b:=false
var _guard_ref168b: WeakRef
func guard168b() -> CardData:
 return _guard_ref168b.get_ref() if _guard_ref168b!=null else null
func guard_snapshot168b() -> Dictionary:
 var g: CardData=guard168b()
 var alive: bool=is_instance_valid(g) and g in context.enemy.field and battle.get_unit_current_hp(g)>0
 return {"alive":alive,"id":"B-07","name":"压力护壁","cell":battle.get_unit_cell(g) if alive else Vector2i(1,1),"hp":battle.get_unit_current_hp(g) if alive else 0,"max_hp":4,"attack":3,"initial_cell":Vector2i(1,1),"respawns":false}
func guard_status168b() -> String:
 var g: Dictionary=guard_snapshot168b()
 if not g.alive:return "守卫已清除 · 原要害通路恢复；仍需合法位置、行动和指令。"
 return "压力护壁 · %d列%d行 · 血%d/%d · 攻%d
拦截同列护臂；可清障，或先攻4列阀门。"%[g.cell.x+1,g.cell.y+1,g.hp,g.max_hp,g.attack]
func _adapt168b(node: Node,script: Script,fields: Array) -> void:
 var saved: Dictionary={}
 for field: String in fields:saved[field]=node.get(field)
 node.set_script(script)
 for field: String in fields:node.set(field,saved[field])
func _ready() -> void:
 await super._ready()
 # Scenario setup is not a Boss card play: no entry effects, OD or shield.
 var guard: CardData=boss_deck.create_card_by_id("B-07")
 guard.display_name="压力护壁";guard.description="训练预置守卫：3攻4血，保护同列要害。不会主动行动；受击仍按原交战规则还击。清除后不重生。";guard.short_description=guard.description
 context.enemy.field.append(guard)
 battle.register_unit(guard,&"boss",false,-1,Vector2i(1,1));_guard_ref168b=weakref(guard)
 _adapt168b(training_panel168a,preload("res://ui/training_panel_168b.gd"),["owner_ref","entry","window","text","card_select","status","tab168a"])
 _adapt168b(journal168a,preload("res://battle/analysis/training_journal_168b.gd"),["owner_ref","entries","_last_state","_elapsed","started_us"])
 _adapt168b(flow166d,preload("res://ui/training_flow_168b.gd"),["scene_ref","body_button","maintenance167d"])
 var scroll: Control=player_table.card_detail_panel.get_node("ScrollContainer")
 scroll.offset_left=12;scroll.offset_right=-12
 training_panel168a.entry.text="168B 单守卫 · 规则与记录"
 training_panel168a.window.title="168B 单守卫训练 · 不计普通胜率"
 _playtest.run_label="168B_single_guard_not_winrate"
 context.enemy.player_name="单守卫训练木桩";context.enemy.notify_combat_state_changed()
 get_node("IntegratedPlaytestTools").guide_window.dialog_text="168B：先看手牌类型和用途；两key连续展开后点部署完成。场上压力护壁守住2列护臂，不主动行动但会按原规则还击。可用打击/普通攻击清障，或先攻4列阀门；换路线不能绕过同列拦截。仍由你选择牌、单位、部位与路线。原费用、容量、回合和限次不变。"
 ready168b=true
 journal168a.capture168a("guard_scenario_ready",{"source":"initial_scenario_not_card_play","cell":Vector2i(1,1)})
 _refresh_tables();training_panel168a.refresh168a();flow166d.refresh()
func training_snapshot168a() -> Dictionary:
 var state: Dictionary=super.training_snapshot168a();state.mode="168B_single_guard";state.guard=guard_snapshot168b();return state
func training_catalog168a() -> Array:
 var cards: Array=super.training_catalog168a()
 for c: Dictionary in cards:
  if c.id=="B01":c.note="只选敌方普通棋子。可对场上压力护壁造成2伤害；不能点Boss部位，不自动完成剩余攻击。"
  elif c.id=="B03":c.note="选己方棋子，抵挡下次交战/还击2伤害；至下次己方回合，不挡Boss法术。"
 return cards
func _refresh_weakpoint162a() -> void:
 super._refresh_weakpoint162a()
 if is_instance_valid(weakpoint_label):weakpoint_label.text=weakpoint_label.text.replace("168A1 ","168B ")
func axis155_navigate(nav: String) -> void:
 if not ready168b or nav not in ["restart","home"]:return
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
 var path: String="res://scenes/playtest/phase168b_single_guard.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn"
 if get_tree().change_scene_to_file(path)!=OK:_gb1_restarting=false;push_error("168B navigation failed")
