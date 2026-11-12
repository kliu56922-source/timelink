extends RefCounted
const DURATION:=5.2
static func build(receipt: Dictionary,keys: Array) -> Dictionary:
	if not receipt.get("ok",false) or receipt.get("layout",[]).size()!=3 or keys.size()!=2 or int(receipt.get("derived_uid",0))<=0:return {}
	var sources: Array=[]
	for i in range(2):
		var source: Dictionary=keys[i].duplicate(true)
		if int(source.get("uid",0))<=0:return {}
		source.cell=receipt.layout[i].cell;source.from_zone="hand";source.to_zone="field" if i==0 else "traps";sources.append(source)
	sources.append({"uid":int(receipt.derived_uid),"card_id":str(receipt.derived_id),"name":str(receipt.layout[2].name),"cell":receipt.layout[2].cell,"from_zone":"independent_pool","to_zone":"field"})
	var events: Array=[
		{"kind":"keys_gather","title":"两张关键牌离手，组成展开指令","start":0.0,"end":0.65,"uids":[sources[0].uid,sources[1].uid]},
		{"kind":"foundation_arrives","title":"炉基座牌到达建筑格","start":0.65,"end":1.85,"uids":[sources[1].uid]},
		{"kind":"familiar_arrives","title":"燃芯使魔牌到达主锚点","start":1.85,"end":3.05,"uids":[sources[0].uid]},
		{"kind":"derived_arrives","title":"独立衍生池学徒到达衍生格","start":3.05,"end":4.25,"uids":[sources[2].uid]},
		{"kind":"conduits_shown","title":"显示本次成阵连接与已结算收益","start":4.25,"end":DURATION,"uids":sources.map(func(s):return s.uid)}]
	for i in range(events.size()):events[i].sequence=i;events[i].transaction=str(receipt.transaction)
	return {"transaction":str(receipt.transaction),"committed":true,"duration":DURATION,"sources":sources,"events":events,"bill":{"command":receipt.cost,"load":receipt.load_cost,"heat_before":receipt.heat_before,"heat_after":receipt.heat_after,"shield_gain":receipt.shield_gain,"generated":receipt.generated}}
