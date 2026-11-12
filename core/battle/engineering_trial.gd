extends RefCounted
## Opt-in engineering axis. Queries never grant preparation or consume resources.
var _ref: WeakRef
var used_turn_by_id: Dictionary = {}
var _events: Dictionary = {}
var _cells: Dictionary = {}
const IDS := ["E01","E02"]
func _init(owner: Node) -> void: _ref=weakref(owner)
func begin_turn(side: String) -> void:
 if side=="player": _events.clear();_cells.clear()
func snapshot() -> Dictionary:
 return {"used":used_turn_by_id.duplicate(true),"events":_events.duplicate(true),"cells":_cells.duplicate(true)}
func choices() -> Array[String]:
 var b=_ref.get_ref()
 var found: Array[String]=[]
 for id in ["P22","P23"]:
  for card: CardData in b.context.player.deck:
   if is_instance_valid(card) and card.card_id==id and card not in b.context.player.hand:
    found.append(id);break
 return found
func _buildings() -> Dictionary:
 var b=_ref.get_ref();var found := {}
 for st: Dictionary in b.get_structure_snapshot().get("structures",{}).values():
  if st.get("owner_side")!=&"player" or st.get("status")!=&"intact" or int(st.get("integrity_current",0))<=0: continue
  for source: CardData in b.context.player.traps:
   if is_instance_valid(source) and source.is_building_card() and not source.has_meta("engineering_site_tx") and source.get_instance_id()==int(st.get("source_runtime_id",-1)):
    found[st.structure_id]=st.duplicate(true)
 return found
func status(card: CardData) -> Dictionary:
 var b=_ref.get_ref()
 if card==null or not is_instance_valid(card) or card.card_id not in IDS: return {"ok":false,"reason":"不是工程牌"}
 if b._siege_command_in_progress: return {"ok":false,"reason":"等待当前工程结算完成"}
 if not b.get_command_economy_snapshot("player").get("turn_open",false): return {"ok":false,"reason":"请在己方回合使用"}
 if b.context.player.hp<=0 or b.context.enemy.hp<=0: return {"ok":false,"reason":"对局已结束"}
 if card not in b.context.player.hand: return {"ok":false,"reason":"卡牌不在手牌中"}
 if used_turn_by_id.get(card.card_id,-1)==b.context.turn_count: return {"ok":false,"reason":"同名工程牌本回合已使用"}
 if card.card_id=="E01":
  if _buildings().is_empty(): return {"ok":false,"reason":"先控制一处完好的己方建筑"}
  if b.context.od_mode.current_od<1: return {"ok":false,"reason":"需要支付1热"}
  if b.context.player.hand.size()>=b.context.player.MAX_HAND_SIZE: return {"ok":false,"reason":"手牌已满，不能检索"}
  if choices().is_empty(): return {"ok":false,"reason":"牌库没有修补或升高牌"}
 else:
  for target: CardData in b.context.player.field:
   if _target_status(target).get("ok",false): return {"ok":true,"reason":""}
  return {"ok":false,"reason":"先成功修补/升高，再选择工程格或相邻格的普通己方棋子；已有防护的棋子无需补给"}
 return {"ok":true,"reason":""}
func _target_status(target: Variant) -> Dictionary:
 var b=_ref.get_ref()
 if not target is CardData or not is_instance_valid(target): return {"ok":false,"reason":"请选择工程附近的普通己方棋子"}
 var state=b._state_for_card(target)
 if target not in b.context.player.field or target.is_arsenal_card or not target.is_front_row_card() or target.card_family!="monster" or state==null or state.is_dead():
  return {"ok":false,"reason":"请选择存活的普通己方棋子（武库除外）"}
 var cell: Vector2i=b.get_unit_cell(target)
 if cell==b.INVALID_GRID_CELL or b.get_unit_at_cell(cell)!=target: return {"ok":false,"reason":"棋子已离场"}
 if b.frontline_trial==null or b.frontline_trial.escort_amount(target)>=1: return {"ok":false,"reason":"已有同等或更强防护，无需补给"}
 var prepared := false
 for origin: Vector2i in _cells:
  if _cells[origin]==b.context.turn_count and maxi(absi(cell.x-origin.x),absi(cell.y-origin.y))<=1: prepared=true;break
 if not prepared: return {"ok":false,"reason":"本回合尚未在此格或相邻格成功修补/升高"}
 return {"ok":true,"reason":"","target_runtime_id":target.get_instance_id(),"cell":cell,"hp":state.current_hp,"escort":b.frontline_trial.escort_amount(target),"engineering_cells":_cells.duplicate(true)}
func cast_status(card: CardData, selection: Variant) -> Dictionary:
 var base := status(card)
 if not base.get("ok",false): return base
 var b=_ref.get_ref();var result: Dictionary
 if card.card_id=="E01":
  if not selection is String or selection not in choices(): return {"ok":false,"reason":"请选择牌库中现有的修补或升高牌"}
  var selected: CardData
  for candidate: CardData in b.context.player.deck:
   if candidate.card_id==selection: selected=candidate;break
  result={"ok":true,"reason":"","choice":selection,"choice_runtime_id":selected.get_instance_id(),"choices":choices(),"buildings":_buildings(),"hand_size":b.context.player.hand.size(),"preview":"支付1热，检索「%s」到手；仍需正常出牌" % selected.get_display_name()}
 else:
  result=_target_status(selection)
  if not result.get("ok",false): return result
  result.preview="下一次棋子交战减伤1；至下次己方回合到期，不挡Boss法术"
 result.heat=b.context.od_mode.current_od
 result.turn=b.context.turn_count
 return result
func record_success(receipt: Dictionary) -> void:
 var b=_ref.get_ref()
 if not receipt.get("ok",false) or receipt.get("source_kind") not in [&"p22_repair",&"p23_terrain_raise"] or int(receipt.get("actual_steps",0))<=0: return
 var id: StringName=receipt.get("transaction_id",&"")
 var cell: Variant=receipt.get("resolved_target",{}).get("cell")
 if id==&"" or _events.has(id) or not cell is Vector2i: return
 _events[id]={"cell":cell,"turn":b.context.turn_count,"source_kind":receipt.source_kind}
 _cells[cell]=b.context.turn_count
func commit(card: CardData, transaction_id: StringName, plan: Dictionary, selection: Variant) -> Dictionary:
 # BattleSystem holds the common mutation lock and has validated this exact plan.
 var b=_ref.get_ref();var p=b.context.player
 used_turn_by_id[card.card_id]=b.context.turn_count
 var before: int=b.context.od_mode.current_od
 var result := {"ok":true,"heat_before":before,"heat_after":before}
 if card.card_id=="E01":
  var found: CardData
  for candidate: CardData in p.deck:
   if candidate.get_instance_id()==plan.choice_runtime_id: found=candidate;break
  p.deck.erase(found);p.hand.append(found)
  b.context.add_heat(-1,&"engineering_survey:payment",transaction_id,{"source_descriptor":b.build_heat_source_descriptor(&"payment",&"engineering_survey:payment",card)})
  result.heat_after=b.context.od_mode.current_od
  result.card=found
  result.message="测绘：%s加入手牌，需正常使用" % found.get_display_name()
  b.card_tutored.emit(card.get_display_name(),found,result.message)
 else:
  b.frontline_trial.grant_escort_amount(selection,1)
  result.target_runtime_id=selection.get_instance_id()
  result.cell=plan.cell
  result.message="补给已就绪：下一次棋子交战减伤1；下次己方回合到期"
 return result
