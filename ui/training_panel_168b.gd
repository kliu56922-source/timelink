extends "res://ui/training_panel_168a.gd"
func refresh168a() -> void:
 super.refresh168a()
 var s: Variant=scene168a()
 if s==null:return
 text.text=text.text.replace("当前无敌棋，打击没有目标属正常；守卫场景后续168B。","守卫在场时可用打击选择它；清除后无敌棋属于正常，不能改打部位。")
 text.text=text.text.replace("168B再加守卫、受伤/补位和危险区案例。本阶段不主动制造伤害；维修/防护没有自然用途时可以不使用。","本例仅增加一个预置守卫，不主动移动/进攻；交战仍可能造成还击伤害。维修/护卫是否使用由当前场面决定；不强制完整连招。受损专项/危险区尚未加入。")
 text.text="168B 单守卫：初始3攻4血，不触发出牌护盾/OD、不重生。\n"+s.guard_status168b()+"\n清障：打击选敌棋；或点己方单位→手动操作→攻击。\n可以先攻另一部位；换路线不能绕过同列守卫。\n\n"+text.text
