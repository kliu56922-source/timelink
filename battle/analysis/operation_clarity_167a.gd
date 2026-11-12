extends RefCounted
## Read-only projections of native legality. Never selects, pays or changes RNG.
static func body_mode(s: Variant) -> bool:
	var parts: Array=s.battle.get_weakpoint_snapshots()
	if parts.is_empty():return false
	for part: Dictionary in parts:
		if not part.broken:return false
	return true
static func body_status(s: Variant,actor: CardData) -> Dictionary:
	var q: Dictionary=s.battle.get_unit_command_status(actor,"attack_core") if actor!=null else {"ok":false,"reason":"先选择单位"}
	var gate: String="请先完成或取消返回确认" if s._exit_modal_active else s.recipe166._gate()
	var ok: bool=q.get("ok",false) and gate.is_empty()
	var reason: String=gate if not gate.is_empty() else str(q.get("reason_text",q.get("reason",q.get("reason_code","检查位置、朝向、守卫、休整与指令"))))
	return {"ok":ok,"label":"可攻本体" if ok else "查看攻本体限制","reason":"" if ok else reason,"cost":q.get("cost",3)}
static func building_status(s: Variant,card: CardData) -> Dictionary:
	var q: Dictionary=s.battle.get_building_interface_status(card,s.context.player)
	var text: String="当前不可发动："+str(q.get("reason","检查建筑状态"))
	if q.get("ok",false):
		text="支付%s → %s。\n每回合一次；确认后支付。"%[str(q.get("cost","")).replace(" OD","热量"),str(q.get("preview","原生建筑效果"))]
		if card.card_id=="P05":
			var charge: int=s.battle.get_building_state(card).get("charge",0)
			if not s.context.player.field.is_empty():
				text="支付2充能（优先）" if charge>=2 else "支付2热量"
				text+=" → %s 攻击+1、生命+1。"%s.context.player.field[0].get_display_name()
			else:text="支付1热量 → 准备下次Depth增长减免1。"
			text+="\n不消耗共享指令；每回合一次。"
			if card.tutor_enabled and card.tutor_timing=="on_building_activate":
				var matches: Array=s.battle.find_cards_in_deck(s.battle._card_tutor_criteria(card))
				text+="\n附带检索："+("牌库没有匹配牌，本次仅执行建筑效果。" if matches.is_empty() else "手牌已满，本次无法取得牌；建筑效果仍执行。" if not s.context.player.can_add_to_hand() else "按牌库顺序取得首张匹配牌。")
	var target_uids: Array=[]
	if card.card_id in ["P05","P08","P19"]:
		for actor: CardData in s.context.player.field:
			target_uids.append(actor.get_instance_id())
			if card.card_id!="P19":break
	var matches: Array=s.battle.find_cards_in_deck(s.battle._card_tutor_criteria(card)) if card.tutor_enabled and card.tutor_timing=="on_building_activate" else []
	var signature: Dictionary={"source":card.get_instance_id(),"turn":s.context.turn_count,"ok":q.get("ok",false),"cost":q.get("cost",""),"preview":q.get("preview",""),"targets":target_uids,"tutor":matches[0].get_instance_id() if not matches.is_empty() and s.context.player.can_add_to_hand() else 0}
	return {"ok":q.get("ok",false),"text":text,"native":q,"signature":signature}
