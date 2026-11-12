extends "res://ui/training_flow_168b.gd"
var _reading_elapsed168b2:=0.2
var _reading168b2: Dictionary={}
func refresh() -> void:
 super.refresh()
 var s: Variant=scene()
 if s==null or not s.get("ready168b2"):return
 _reading_elapsed168b2+=get_process_delta_time()
 if _reading_elapsed168b2>=0.2 or _reading168b2.is_empty():
  _reading_elapsed168b2=0;_reading168b2=s.maintenance_situation168b2()
 s.phase_label166b.text=s.phase_label166b.text.replace("168B训练","168B2训练")
 var hint: String=_reading168b2.get("hint","")
 var opportunities: Node=s.get_node_or_null("CurrentActionPanel")
 if opportunities!=null:opportunities.threat.text=hint;opportunities.threat.tooltip_text=_reading168b2.get("detail","")
 if not s.battle.preparation_active166b() and not s.battle_ended and int(snapshot().broken)<3:s.recipe_panel166.entry_hint.text=hint
 var actor: CardData=s.advance165.resolve(s.advance_panel165.actor_uid)
 if actor==null or not is_instance_valid(maintenance167d):return
 var unit: Dictionary={}
 for candidate: Dictionary in _reading168b2.get("wounded",[]):
  if candidate.uid==actor.get_instance_id():unit=candidate;break
 maintenance167d.text="维护此单位 · 可恢复%d血"%unit.heal if not unit.is_empty() and unit.ready else "维护此单位 · 查看限制" if not unit.is_empty() else "维护此单位 · 满血无需修复"
 maintenance167d.tooltip_text="消耗手中燃芯使魔或炉基座×1、1指令；热+2、负荷+1。最多恢复2血，不刷新原行动；取消不付款。"+("\n"+unit.reason if not unit.is_empty() and not unit.ready else "")
