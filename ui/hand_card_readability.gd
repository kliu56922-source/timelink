extends RefCounted
## Presentation only. Live search/payment facts come from the existing authority.
static func build(card: CardData, status: Dictionary, battle) -> Dictionary:
	if card==null: return {}
	var summaries := {
		"P02":"登场：找炉心建筑\n出场回合不能攻击",
		"P05":"入场：护盾 +3\n主动：强化或减压",
		"P07":"登场：打2\n检索蒸汽棋子到手",
		"P08":"双格建筑：可驻军\n主动：棋子 +1/+1",
		"P10":"登场：打1并抽1\n检索炉心延展魔法",
		"P13":"入场：护盾 +3\n主动：准备Depth减免",
		"P15":"入场：护盾 +5\n1攻 / 6血，守卫核心",
		"P14":"交接时Boss热量 −4\n触发一次后消耗",
		"S01":"登场：1攻 / 2血\n有建筑时找蒸汽中转",
		"S02":"无需选格\n找蒸汽起手 / 中转",
		"S03":"无需选格\n墓地蒸汽棋子回手",
		"P22":"选己方受损墙 / 门楼\n耐久 +1",
		"P23":"选己方合法地块\n高度 +1，最高 H2",
	}
	var summary: String=summaries.get(card.card_id,card.short_description)
	if card.card_id=="P04" and battle.reaction_trial!=null: summary="选择监视格盖伏\n敌人移入时阻止移动"
	if battle.frontline_trial!=null:
		if card.card_id=="P01": summary="抽1；效果热量 +1\n选友军可额外护送"
		elif card.card_id=="P06": summary="打4；可选友军赋刃\n攻城额外破盾2"
	if card.card_id=="P09": summary="抽1；效果热量 +2"
	if card.card_id=="P11": summary="Depth −3；护盾 +2\n效果热量 −2"
	if summary.is_empty():
		summary="登场：%d攻 / %d血" % [card.unit_power,card.unit_defense] if card.card_family=="monster" else "查看详情了解效果"
	var gain: int=battle.context.od_mode.get_od_gain(card)
	var fact := {"summary":summary,"cost":"基础热 +%d" % gain,"context":"","detail":"基础产热是出牌收益，受热量上限与来源规则约束，不是支付费用。"}
	if card.card_id in ["E01","E02"] and battle.engineering_trial!=null:
		fact.cost="费用 1热" if card.card_id=="E01" else "费用 0热"
		fact.summary="控制完好己方建筑\n选择找修补 / 升高" if card.card_id=="E01" else "本回合成功工程后\n附近棋子交战减伤1"
		fact.context=("选检索选项，再确认" if card.card_id=="E01" else "选工程附近棋子，再确认") if status.get("ok",false) else str(status.get("reason",""))
		fact.detail=card.description
	elif card.card_id in ["B01","B02","B03"] and battle.basic_card_trial!=null:
		fact.cost="费用 1热"
		fact.summary={"B01":"选敌方棋子\n造成 2 伤害","B02":"选己方棋子\n下次普通攻击 +2","B03":"选己方棋子\n下次棋子交战减伤2"}[card.card_id]
		fact.context="选棋子后预览再确认" if status.get("ok",false) else str(status.get("reason",""))
		fact.detail=card.description
	elif card.card_id in ["B04","B05"] and battle.basic_card_trial!=null:
		fact.cost="免费" if card.card_id=="B04" else "费用 1热"
		fact.summary="获得热量 2" if card.card_id=="B04" else "Depth降低 2\n最低为 0"
		var live: Dictionary=battle.basic_card_trial.status(card)
		fact.context=str(live.get("preview","")) if status.get("ok",false) else str(status.get("reason",""))
		fact.detail="无需选格；同名每回合成功使用一次。" + card.description
	elif card.card_id in ["S02","S03"] and battle.steam_package_trial!=null:
		fact.cost="费用 1热"
		if status.get("ok",false):
			var preview: Dictionary=battle.steam_package_trial.search_status(card)
			var target: CardData=preview.get("target")
			var heat: int=battle.context.od_mode.current_od
			fact.context="%s 热%d→%d" % [target.get_display_name(),heat,heat-1] if target!=null else str(preview.get("reason",""))
		else: fact.context=str(status.get("reason","暂不可用"))
		fact.detail="同名每回合一次；找来的棋子加入手牌，需正常登场。" + str(status.get("reason",""))
	elif not status.get("ok",true): fact.context=str(status.get("reason","暂不可用"))
	elif card.card_id=="S01":
		var entry: Dictionary=battle.steam_package_trial.search_status(card) if battle.steam_package_trial!=null else {}
		fact.context="找："+entry.target.get_display_name() if entry.get("ok",false) else "无建筑也可登场"
	elif card.card_id=="R01":
		fact.cost="布置 0热"
		fact.summary="盖伏：攻击时防护3\n手发：付1热防护2"
		fact.context="敌方攻击时可响应"
	elif card.card_family=="monster": fact.context="出场回合不能攻击"
	elif card.is_building_card(): fact.context="选位建设；有主动效果"
	elif card.card_id=="P22": fact.context="不修棋子或已毁墙"
	elif card.card_id=="P23": fact.context="不是选择棋子"
	else: fact.context="主效果见上，条件见详情"
	return fact
