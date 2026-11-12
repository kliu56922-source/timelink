extends "res://core/run/run_growth_session.gd"
## Content loadouts and validated, data-only battle-node reconstruction.
const PROFILES: Array[String]=["base","armor","warm"]
var _profile:="base"
func set_profile(value: Variant) -> Dictionary:
 if _state!="idle" or not value is String or value not in PROFILES:return _fail(&"invalid_profile")
 _profile=value;return {"ok":true}
func begin(seed: Variant,generation_value: int) -> Dictionary:
 var result: Dictionary=super.begin(seed,generation_value)
 if result.ok and _profile!="base":_hp=30;_modules.append(_profile)
 return result
func _set_stage(value: String) -> void:
 super._set_stage(value)
 if value=="module" and _modules.size()>=2:_offers.clear()
func snapshot() -> Dictionary:
 var result: Dictionary=super.snapshot();result.meta={"profile":_profile,"capacity":2};return result
static func config_key(config: Dictionary) -> String:return JSON.stringify(config,"",true).sha256_text()
func export_checkpoint() -> Dictionary:
 if _state!="between" or _stage not in ["card","done"]:return _fail(&"unsafe_node")
 var results: Array=[];var choices: Array=[]
 for row in _results:results.append({"raw_hp":row.raw_hp,"turns":row.turns})
 for row in _history:choices.append(row.choice_id)
 return {"ok":true,"checkpoint":{"schema":1,"config_key":config_key(_config_for_key()),"profile":_profile,"seed":_seed,"generation":_generation,"stage":_stage,"results":results,"choices":choices,"facts":{"hp":_hp,"deck":_deck.duplicate(),"upgrades":_upgrades.duplicate(true),"modules":_modules.duplicate()}}}
func _config_for_key() -> Dictionary:
 var config: Dictionary=_config.duplicate(true);config.deck_ids=Config.STARTER.duplicate();return config
static func _keys(data: Dictionary,keys: Array) -> bool:
 if data.size()!=keys.size():return false
 for key in keys:
  if not data.has(key):return false
 return true
static func _integer(value: Variant,low: int,high: int) -> bool:return value is int and value>=low and value<=high
static func restore_checkpoint(config: Dictionary,node: Variant,next_generation: int) -> Dictionary:
 var invalid: Dictionary={"ok":false,"reason_code":&"invalid_checkpoint"}
 if not node is Dictionary or not _keys(node,["schema","config_key","profile","seed","generation","stage","results","choices","facts"]):return invalid
 if not _integer(node.schema,1,1) or node.config_key!=config_key(config) or not node.profile is String or node.profile not in PROFILES:return invalid
 if not _integer(node.seed,0,2147483646) or not _integer(node.generation,1,2147483646) or next_generation<=node.generation or next_generation>2147483646:return invalid
 if node.stage not in ["card","done"] or not node.results is Array or node.results.size() not in [1,2] or not node.choices is Array:return invalid
 var expected: int=3*(node.results.size()-1)+(3 if node.stage=="done" else 0)
 if node.choices.size()!=expected or not node.facts is Dictionary or not _keys(node.facts,["hp","deck","upgrades","modules"]):return invalid
 var session=load("res://core/run/run_meta_session.gd").new()
 if not session.set_profile(node.profile).ok or not session.configure(config).ok or not session.begin(node.seed,next_generation).ok:return invalid
 var cursor:=0
 for index in range(node.results.size()):
  var row: Variant=node.results[index]
  if not row is Dictionary or not _keys(row,["raw_hp","turns"]) or not _integer(row.raw_hp,1,1000000) or not _integer(row.turns,0,100000):return invalid
  var prepared: Dictionary=session.prepare_encounter()
  if not prepared.ok or not session.mark_started(prepared.token).ok or not session.finish_encounter(prepared.token,true,row.raw_hp,row.turns).ok:return invalid
  if index<node.results.size()-1 or node.stage=="done":
   for j in range(3):
    if not node.choices[cursor] is String or not session.commit_choice(session.snapshot().growth.token,node.choices[cursor]).ok:return invalid
    cursor+=1
  if index<node.results.size()-1 and not session.advance_encounter().ok:return invalid
 var snap: Dictionary=session.snapshot()
 var facts: Dictionary={"hp":snap.core_hp,"deck":snap.growth.deck_ids,"upgrades":snap.growth.upgrades,"modules":snap.growth.modules}
 if facts!=node.facts or snap.growth.stage!=node.stage:return invalid
 return {"ok":true,"session":session}
