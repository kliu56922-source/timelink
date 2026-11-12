extends "res://ui/encounter_flow_167a.gd"
var maintenance167d: Button
func setup167d() -> void:
 maintenance167d=Button.new();maintenance167d.name="MaintainSelectedUnit167D";maintenance167d.text="维护此单位 · 先查看";maintenance167d.custom_minimum_size.y=32
 scene().advance_panel165.config.add_child(maintenance167d)
 maintenance167d.pressed.connect(func():scene().maintain167d(scene().advance_panel165.actor_uid))
func refresh() -> void:
 super.refresh()
 var s: Variant=scene()
 if s==null:return
 s.phase_label166b.text=s.phase_label166b.text.replace("167A","167D")
 var state: Dictionary=snapshot();var body: bool=state.broken==3
 if body:s.advance_panel165.source_title.text="本体收尾 · 点单位："
 if is_instance_valid(maintenance167d):
  var actor: CardData=s.advance165.resolve(s.advance_panel165.actor_uid)
  maintenance167d.visible=actor!=null and actor in s.context.player.field and not state.preparation and not state.terminal
  maintenance167d.disabled=not s.support166c._gate().is_empty()
  maintenance167d.tooltip_text="锁定当前单位→明确选择手牌素材→预览费用与恢复量→确认。取消不付款。"
 if not state.preparation and not state.transition and not state.terminal and not body:
  s.recipe_panel166.entry_hint.text="进攻：点场上Boss部位→选单位→路线→确认。\n受伤？点单位→维护此单位；维护是可选操作。\n没有合适动作时可结束回合，等Boss行动后再决定。"
