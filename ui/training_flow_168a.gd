extends "res://ui/player_loop_flow_167d.gd"
func refresh() -> void:
 super.refresh()
 var s: Variant=scene()
 if s==null or not s.ready168a:return
 s.phase_label166b.text=s.phase_label166b.text.replace("167D","168A训练")
 var hint:="训练条件：木桩不主动出牌/进攻。\n保留正常抽牌、费用、休整、部位锁和被动阶段反应。"
 s._boss_status_hud.get_node("IntentRow/IntentText").text="训练：木桩待机 · 无主动进攻"
 var opportunities: Node=s.get_node_or_null("CurrentActionPanel")
 if opportunities!=null:opportunities.threat.text=hint;opportunities.threat.tooltip_text=hint
 if not s.battle.preparation_active166b() and not s.battle_ended and int(snapshot().broken)<3:
  s.recipe_panel166.entry_hint.text="进攻：点场上部位→单位→路线→确认。\n想看联动与账单？顶部「168A训练·联动与记录」。\n没有合适动作可结束回合，正常抽牌/刷新；木桩待机。"
