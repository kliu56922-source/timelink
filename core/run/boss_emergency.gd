extends RefCounted
## One offer per disposable Boss; no nodes, randomness or battle mutation here.
const OPTIONS=[{"id":"heal","name":"核心修复","description":"核心恢复最多6，最高35。"},{"id":"vent","name":"应急排压","description":"Depth降低2，最低0；按原规则解除反噬。"},{"id":"shield","name":"核心护盾","description":"核心护盾+3，沿原伤害规则消耗。"}]
var _state:="closed"
var _token:=""
var _history: Array[Dictionary]=[]
func setup(token: Variant, enabled: Variant) -> Dictionary:
 if not token is String or token.is_empty() or not enabled is bool:return {"ok":false}
 _token=token+":emergency";_state="armed" if enabled else "closed";_history.clear()
 return {"ok":true}
func observe(phase: Variant,safe: bool,alive: bool) -> bool:
 if _state in ["resolved","closed"]:return false
 if not alive:close();return false
 if not phase is int:return false
 if _state=="armed" and phase>=2:_state="pending"
 if _state=="pending" and safe:_state="open";return true
 return false
func snapshot() -> Dictionary:
 return {"state":_state,"token":_token,"offers":OPTIONS.duplicate(true) if _state=="open" else [],"history":_history.duplicate(true)}
func preview(token: Variant,id: Variant,facts: Dictionary) -> Dictionary:
 if not token is String or not id is String or token!=_token or _state!="open":return {"ok":false,"reason_code":&"stale_or_closed"}
 if id not in ["heal","vent","shield","skip"]:return {"ok":false,"reason_code":&"invalid_choice"}
 for key in ["hp","depth","shield"]:
  if not facts.get(key) is int:return {"ok":false,"reason_code":&"invalid_facts"}
 if facts.hp<=0 or facts.depth<0 or facts.depth>6 or facts.shield<0:return {"ok":false,"reason_code":&"invalid_facts"}
 var row: Dictionary={"id":"skip","name":"跳过应急","description":"继续当前战斗，不领取收益。"}
 for option in OPTIONS:
  if option.id==id:row=option.duplicate(true)
 row.merge({"ok":true,"token":_token,"hp_before":facts.hp,"hp_after":facts.hp+mini(6,maxi(0,35-facts.hp)) if id=="heal" else facts.hp,"depth_before":facts.depth,"depth_after":maxi(0,facts.depth-2) if id=="vent" else facts.depth,"shield_before":facts.shield,"shield_after":facts.shield+3 if id=="shield" else facts.shield})
 return row
func take(token: Variant,id: Variant,facts: Dictionary) -> Dictionary:
 var row:=preview(token,id,facts)
 if not row.ok:return row
 # Resolve before any caller emits resource signals, preventing reentrant claims.
 _state="resolved";_history.append(row.duplicate(true));return row
func close() -> void:_state="closed"
