extends "res://ui/training_flow_168a.gd"
func refresh() -> void:
 super.refresh()
 var s: Variant=scene()
 if s==null or not s.get("ready168b"):return
 s.phase_label166b.text=s.phase_label166b.text.replace("168A训练","168B训练")
 s._boss_status_hud.get_node("IntentRow/IntentText").text="训练：守卫不主动行动 · 保留还击"
 var opportunities: Node=s.get_node_or_null("CurrentActionPanel")
 if opportunities!=null:opportunities.threat.text=s.guard_status168b();opportunities.threat.tooltip_text=s.guard_status168b()+"\n原费用/回合保留；守卫清除不重生。"
 if not s.battle.preparation_active166b() and not s.battle_ended and int(snapshot().broken)<3:
  s.recipe_panel166.entry_hint.text="进攻：点场上部位→单位→路线→确认。\n守卫拦截？先清障或改选另一部位。\n手动攻击：点单位→手动操作→攻击。"
