extends RefCounted
## Data-only run authority. Every rejected operation leaves state untouched.
const Config = preload("res://core/run/run_foundation_config.gd")
const SUPPORTED: Array[String]=["B-01","B-02","B-03","B-04","B-07","B-09","B-15","B-16"]
var _config: Dictionary={}
var _state := "idle"
var _generation := 0
var _seed := 0
var _index := 0
var _hp := 35
var _attempt := 0
var _token := ""
var _results: Array[Dictionary]=[]
var _claimed: Array[int]=[]
var _cache: Dictionary={}
func _fail(code: StringName) -> Dictionary:
 return {"ok":false,"reason_code":code}
func configure(config: Dictionary) -> Dictionary:
 if _state!="idle": return _fail(&"already_configured")
 if not Config.validate(config,Config.STARTER,SUPPORTED).is_empty():return _fail(&"invalid_config")
 for i in range(config.encounters.size()):
  var profile: Dictionary=config.encounters[i]
  if not profile.get("encounter") is Dictionary:return _fail(&"invalid_config")
  var encounter: Dictionary=profile.encounter
  if not Config.whole(encounter.get("boss_start_hp")) or float(encounter.get("boss_start_hp",0))<=0 or not encounter.get("phase_locks_enabled") is bool or encounter.phase_locks_enabled!=(i==2):return _fail(&"invalid_config")
 _config=config.duplicate(true)
 return {"ok":true}
func begin(seed: Variant, generation: int) -> Dictionary:
 if not seed is int or seed<0 or seed>2147483646: return _fail(&"invalid_seed")
 if _config.is_empty() or generation<=_generation: return _fail(&"invalid_generation_or_config")
 _generation=generation;_seed=seed;_index=0;_hp=35;_attempt=0;_token=""
 _results.clear();_claimed.clear();_cache.clear();_state="ready"
 return {"ok":true}
func prepare_encounter() -> Dictionary:
 if _state!="ready": return _fail(&"not_ready")
 if not _cache.has(_index):
  var p: Dictionary=_config.encounters[_index]
  var deck_seed := (_seed+1009*(_index+1))%2147483647
  var boss_seed := (_seed+2003*(_index+1))%2147483647
  var order: Array=_config.deck_ids.duplicate()
  var rng := RandomNumberGenerator.new();rng.seed=deck_seed
  for i in range(order.size()-1,5,-1):
   var j := rng.randi_range(6,i)
   var value: Variant=order[i];order[i]=order[j];order[j]=value
  _cache[_index]={"generation":_generation,"encounter_index":_index,"encounter_id":p.id,"display_name":p.display_name,"player_hp":_hp,"encounter":p.encounter.duplicate(true),"boss_deck":p.get("boss_deck",{}).duplicate(true),"inherit_boss_deck":p.inherit_boss_deck,"deck_ids":_config.deck_ids.duplicate(),"deck_order":order,"deck_seed":deck_seed,"boss_seed":boss_seed,"run_seed":_seed}
 _attempt+=1;_token="%d:%d:%d"%[_generation,_index,_attempt];_state="loading"
 var contract: Dictionary=_cache[_index].duplicate(true);contract["token"]=_token
 return {"ok":true,"token":_token,"contract":contract}
func mark_started(token: String) -> Dictionary:
 if _state!="loading" or token!=_token: return _fail(&"stale_start")
 _state="fighting";return {"ok":true}
func cancel_loading(token: String) -> Dictionary:
 if _state!="loading" or token!=_token: return _fail(&"stale_loading")
 _state="ready";_token="";return {"ok":true}
func finish_encounter(token: String, victory: bool, raw_hp: int, turns: int) -> Dictionary:
 if _state!="fighting" or token!=_token: return _fail(&"stale_result")
 if turns<0 or (victory and raw_hp<=0): return _fail(&"contradictory_result")
 var contract: Dictionary=_cache[_index]
 _results.append({"encounter_index":_index,"encounter_id":contract.encounter_id,"display_name":contract.display_name,"initial_hp":contract.player_hp,"raw_hp":raw_hp,"victory":victory,"turns":turns,"run_seed":_seed,"deck_seed":contract.deck_seed,"boss_seed":contract.boss_seed,"deck_order":contract.deck_order.duplicate(),"token":token})
 _hp=maxi(0,raw_hp);_token=""
 _state=("won" if _index==2 else "between") if victory else "lost"
 return {"ok":true}
func advance_encounter() -> Dictionary:
 if _state!="between" or _index in _claimed: return _fail(&"not_between")
 var before := _hp
 _hp+=mini(6,maxi(0,35-_hp));_claimed.append(_index);_index+=1;_state="ready"
 return {"ok":true,"hp_before":before,"hp_after":_hp,"supply":_hp-before}
func abandon() -> Dictionary:
 if _state in ["won","lost","abandoned"]: return _fail(&"terminal")
 _state="abandoned";_token="";return {"ok":true}
func snapshot() -> Dictionary:
 return {"state":_state,"generation":_generation,"run_seed":_seed,"encounter_index":_index,"core_hp":_hp,"deck_ids":_config.get("deck_ids",[]).duplicate(),"results":_results.duplicate(true),"pending_token":_token,"claimed_supply":_claimed.duplicate()}
