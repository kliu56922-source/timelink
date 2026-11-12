extends "res://ui/maintenance_target_panel_167d.gd"
## Merge source + purpose only. Native quote, target, submit and bill remain.
var joint_grid168c: GridContainer
var joint_buttons168c: Dictionary={}
var joint_heading168c: Label
var legacy_toggle168c: Button
var compact168c:=true
var submitted168c:=false
func setup(owner: Node) -> void:
 super.setup(owner)
 joint_heading168c=label(sources.get_parent(),"素材＋用途 · 一次选择，仍需确认")
 joint_grid168c=GridContainer.new();joint_grid168c.columns=2;sources.get_parent().add_child(joint_grid168c)
 legacy_toggle168c=button(sources.get_parent(),"切换分步选择",func():compact168c=not compact168c;sync())
 var body: Node=sources.get_parent();body.move_child(joint_heading168c,1);body.move_child(joint_grid168c,2);body.move_child(legacy_toggle168c,3)
 refresh_joint168c();sync()
func open() -> void:
 compact168c=true;submitted168c=false;super.open();refresh_joint168c();sync()
func open_target167d(actor: CardData) -> void:
 super.open_target167d(actor);refresh_joint168c();sync()
func refresh_sources166c() -> void:
 super.refresh_sources166c()
 if is_instance_valid(joint_grid168c):refresh_joint168c()
func joint_key168c(uid: int,mode_value: String) -> String:return str(uid)+":"+mode_value
func joint_status168c(uid: int,mode_value: String) -> Dictionary:
 var owner: Variant=s()
 if mode_value=="repair":
  if target_uid167d!=0:
   var target: CardData=owner.advance165.resolve(target_uid167d)
   if target==null:return {"ok":false,"reason":"原单位已离场；重新选择，不改修其他单位"}
   return owner.battle.support166_preview(mode_value,uid,owner.battle.get_unit_cell(target))
  var last: Dictionary={"ok":false,"reason":"没有存活受伤友军可修复"}
  for unit: CardData in owner.context.player.field:
   last=owner.battle.support166_preview(mode_value,uid,owner.battle.get_unit_cell(unit))
   if last.get("ok",false):return last
  return last
 var last: Dictionary={"ok":false,"reason":"当前没有合法补位格"}
 for y in [3,4]:
  for x in range(5):
   last=owner.battle.support166_preview(mode_value,uid,Vector2i(x,y))
   if last.get("ok",false):return last
 return last
func refresh_joint168c() -> void:
 if not is_instance_valid(joint_grid168c):return
 for child: Node in joint_grid168c.get_children():joint_grid168c.remove_child(child);child.queue_free()
 joint_buttons168c.clear()
 var count:=0
 for card: CardData in s().context.player.hand:
  if card.card_id not in ["P02","P05"]:continue
  count+=1
  for purpose: String in ["repair","replace"]:
   var uid: int=card.get_instance_id();var status: Dictionary=joint_status168c(uid,purpose)
   var b: Button=button(joint_grid168c,card.get_display_name()+"\n"+("修复友军" if purpose=="repair" else "补回学徒"),choose_joint168c.bind(uid,purpose))
   b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.custom_minimum_size.y=42;b.add_theme_font_size_override("font_size",12)
   b.disabled=not status.get("ok",false);b.tooltip_text="消耗此手牌×1、1指令；热+2/负荷+1。"+("选择后再选合法目标并确认。" if status.get("ok",false) else str(status.get("reason","当前不可用")))
   joint_buttons168c[joint_key168c(uid,purpose)]=b
 joint_heading168c.text="素材＋用途 · 一次选择，仍需确认" if count>0 else "缺少手牌素材：燃芯使魔或炉基座"
func choose_joint168c(uid: int,purpose: String) -> void:
 if s().support166c.running or submitted168c:return
 var status: Dictionary=joint_status168c(uid,purpose)
 if not status.get("ok",false):summary.text=str(status.get("reason","选择已失效，重新预览"));return
 var locked_repair: bool=target_uid167d!=0 and purpose=="repair"
 choose_source(uid)
 if not locked_repair:choose_mode(purpose)
 sync()
func sync() -> void:
 super.sync()
 if not is_instance_valid(joint_grid168c):return
 var busy: bool=s().support166c.running
 joint_grid168c.visible=compact168c and not busy and not submitted168c;joint_heading168c.visible=joint_grid168c.visible
 sources.visible=not compact168c and not busy and not submitted168c;modes.visible=sources.visible
 legacy_toggle168c.visible=not busy and not submitted168c;legacy_toggle168c.text="切换分步选择" if compact168c else "切换合并选择"
func submit() -> void:
 if s().support166c.running or not quote.get("ok",false):return
 submitted168c=true
 await super.submit()
 if not is_instance_valid(s()):return
 if not s().support166c.last_result.get("ok",false):submitted168c=false
 sync()
