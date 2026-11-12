extends "res://ui/maintenance_panel.gd"
## Target-first inspection; all quotes/payments remain with the native runner.
var target_uid167d:=0
func open() -> void:
 target_uid167d=0;super.open()
func open_target167d(actor: CardData) -> void:
 if not is_instance_valid(actor) or actor not in s().context.player.field:return
 open();target_uid167d=actor.get_instance_id();mode="repair"
 title.text="维护此单位 · 选一张手牌素材"
 summary.text="目标：%s。\n选择燃芯使魔或炉基座作为素材，查看原生费用/恢复量，再确认。\n只修复该单位；不刷新行动，不自动改选其他友军。\n取消不消耗素材/指令；也可改选用途，回到原维护流程。"%actor.get_display_name()
func choose_source(uid: int) -> void:
 super.choose_source(uid)
 if target_uid167d==0:return
 var actor: CardData=s().advance165.resolve(target_uid167d)
 selecting=false;mode="repair"
 if not is_instance_valid(actor) or actor not in s().context.player.field:
  title.text="维护目标已离场";summary.text="未支付。取消后重新点选要维护的单位；不会改修原位置上的其他棋子。";sync();return
 super.choose_target(s().battle.get_unit_cell(actor))
func choose_mode(value: String) -> void:
 target_uid167d=0;super.choose_mode(value)
func dismiss() -> void:
 if s().support166c.running:return
 target_uid167d=0;super.dismiss()
