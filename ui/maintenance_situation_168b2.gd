extends RefCounted
## Pure rule observations; never prepare/authorize a runner quote.
static func build(s) -> Dictionary:
 if not is_instance_valid(s) or s.context==null or s.battle==null:return {}
 var root: Dictionary=s.battle.recipe166_snapshot();var quota: Dictionary=s.battle.support166_snapshot()
 var keys: Array=[];var wounded: Array=[];var leaf_alive:=false
 for c: CardData in s.context.player.hand:
  if is_instance_valid(c) and c.card_id in ["P02","P05"]:keys.append({"uid":c.get_instance_id(),"id":c.card_id,"name":c.get_display_name()})
 for c: CardData in s.context.player.field:
  if not is_instance_valid(c):continue
  var state: Variant=s.battle._state_for_card(c)
  if state==null or state.current_hp<=0:continue
  if c.card_id=="D166_S01":leaf_alive=true
  if state.current_hp<state.max_hp:
   var q: Dictionary={"ok":false,"reason":"需要手中的燃芯使魔或炉基座作素材"}
   if not keys.is_empty():q=s.battle.support166_preview("repair",keys[0].uid,s.battle.get_unit_cell(c))
   wounded.append({"uid":c.get_instance_id(),"name":c.get_display_name(),"hp":state.current_hp,"max_hp":state.max_hp,"heal":mini(2,state.max_hp-state.current_hp),"ready":q.get("ok",false),"reason":str(q.get("reason",""))})
 var missing: bool=int(root.used)>0 and not leaf_alive
 var replacement: Dictionary={"ok":false,"reason":"原学徒仍在场，无需补位" if leaf_alive else "先建立炉心阵地"}
 if missing:
  replacement={"ok":false,"reason":"需要手中的燃芯使魔或炉基座作素材"}
  if not keys.is_empty():
   for y in [3,4]:
    for x in range(5):
     var q: Dictionary=s.battle.support166_preview("replace",keys[0].uid,Vector2i(x,y))
     replacement={"ok":q.get("ok",false),"reason":str(q.get("reason",""))}
     if q.get("ok",false):break
    if replacement.ok:break
 var lines: Array[String]=[]
 for unit: Dictionary in wounded:lines.append("%s %d/%d：修复最多+%d血；%s"%[unit.name,unit.hp,unit.max_hp,unit.heal,"规则前提通过" if unit.ready else unit.reason])
 if wounded.is_empty():lines.append("当前没有存活受伤友军，无需修复。")
 lines.append("学徒已离场："+("可按原规则补位" if replacement.ok else replacement.reason) if missing else "学徒仍在场，无需补位。" if leaf_alive else "尚未成阵，没有待补回的学徒。")
 lines.append("手中燃芯使魔或炉基座 %d张；本场维护%d/2，补位%d/1，每回合最多一次。"%[keys.size(),quota.used,quota.replacements])
 lines.append("消耗燃芯使魔或炉基座×1、1指令；热+2、负荷+1。修复不刷新行动，补位保留休整。")
 var hint:=""
 if s.battle_ended:hint="训练已结束；可查看维护记录或重新挑战。"
 elif s.battle.preparation_active166b():hint="先展开并完成部署；交战后才可维护。\n维护只在受伤或缺员时考虑，不必强行使用。"
 elif not wounded.is_empty():
  var unit: Dictionary=wounded[0]
  hint="%s %d/%d，最多恢复%d血。\n"%[unit.name,unit.hp,unit.max_hp,unit.heal]
  hint+=("点单位→维护此单位→选使魔或炉基座→确认。" if unit.ready else unit.reason)+"\n1指令 / 热+2 / 负荷+1；不刷新行动。"
  if missing:hint+="\n也可选择补回学徒；本回合维护只能择一。"
 elif missing:hint="学徒已离场。\n"+("点连续操作→使魔或炉基座→补回学徒→落点→确认。" if replacement.ok else replacement.reason)+"\n新学徒本回合休整；不返还原展开额度。"
 elif not leaf_alive:hint="当前无受伤友军；未建立炉心阵地，不能补回学徒。"
 else:hint="友军满血，学徒在场：当前无需维护。\n继续选择进攻；维护入口始终可查看。"
 return {"mode":"168B2_maintenance_training","preparation":s.battle.preparation_active166b(),"keys":keys,"wounded":wounded,"leaf_alive":leaf_alive,"missing_leaf":missing,"replacement_ready":replacement.ok,"replacement_reason":replacement.reason,"used":quota.used,"replacements":quota.replacements,"hint":hint,"detail":"\n".join(lines)}
