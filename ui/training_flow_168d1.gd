extends "res://ui/training_flow_168c.gd"
func body_reason168d1(actor: CardData) -> String:
 var s: Variant=scene()
 if actor==null:return "先点一个己方单位。"
 var q: Dictionary=s.battle.get_unit_command_status(actor,"attack_core")
 var gate: String="先完成或取消返回确认。" if s._exit_modal_active else s.recipe166._gate()
 if not gate.is_empty():return gate
 if q.get("ok",false):return ""
 var code: String=str(q.get("reason_code",q.get("reason","")))
 var reason: String=str(q.get("reason_text",q.get("reason","")))
 if code=="insufficient_command_points" or reason=="insufficient_command_points":
  var cost: int=s.battle.get_action_command_cost(actor,"attack_core")
  var points: int=s.battle.get_command_economy_snapshot("player").current_points
  return "攻本体需%d指令，当前%d，还差%d。可换单位，或结束回合后再进攻；手动攻击也要支付相同费用。"%[cost,points,maxi(0,cost-points)]
 var meanings: Dictionary={"summoning_sickness":"本回合刚登场，需休整到下回合。","already_attacked":"本回合攻击次数已用完；可换单位或结束回合。","state_missing":"原单位状态已失效，请重新点选在场单位。","no_legal_target":"当前通路不能攻本体；检查守卫、位置和朝向。","not_on_board":"原单位已不在棋盘上，请重新选择。"}
 if meanings.has(code):return meanings[code]
 if reason.is_empty() or reason.is_valid_identifier():return "当前不能攻本体；检查通路、守卫、朝向、休整和指令，可点手动操作查看条件。"
 return reason
func refresh() -> void:
 super.refresh()
 var s: Variant=scene()
 if s==null or not s.get("ready168d1"):return
 s.phase_label166b.text=s.phase_label166b.text.replace("168C训练","168D1训练")
 if snapshot().broken!=3:return
 var actor: CardData=s.advance165.resolve(s.advance_panel165.actor_uid)
 var reason:=body_reason168d1(actor)
 body_button.tooltip_text="确认后使用原生攻核规则。" if reason.is_empty() else reason
 if s.advance_panel165.panel.visible and s.advance_panel165.config.visible:
  s.advance_panel165.summary.text="三要害已破，不需要选择路线。\n"+("当前单位可攻击Boss本体 · %d指令。"%s.battle.get_action_command_cost(actor,"attack_core") if reason.is_empty() else reason)
 for i in range(mini(s.advance_panel165.source_buttons.size(),s.context.player.field.size())):
  var why:=body_reason168d1(s.context.player.field[i])
  s.advance_panel165.source_buttons[i].tooltip_text="点单位查看本体攻击；预览不付款。" if why.is_empty() else why
