extends RefCounted
## Local expedition data; never registered in the global config registry.
const Validator = preload("res://core/config/config_validator.gd")
const STARTER: Array[String] = ["P05","S01","E01","E02","P01","R01","P23","P22","P07","P10","P08","P06","P02","P15","P03","P11","S03","P13","S02"]
static func whole(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value))
static func validate(raw: Variant, known_ids: Array[String], supported_boss_ids: Array[String]) -> Array[String]:
 var errors: Array[String] = []
 if not raw is Dictionary: return ["run config must be a dictionary"]
 if not whole(raw.get("schema_version")) or raw.get("schema_version")!=1: errors.append("schema_version must be 1")
 for pair in [["initial_hp",35],["supply",6],["protected_opening",6]]:
  if not whole(raw.get(pair[0])) or raw.get(pair[0])!=pair[1]: errors.append("invalid "+pair[0])
 var ids: Variant=raw.get("deck_ids")
 if not ids is Array or ids!=STARTER: errors.append("starter identities/order must match the 19-card contract")
 else:
  for id in ids:
   if not id in known_ids: errors.append("missing card "+str(id))
 var profiles: Variant=raw.get("encounters")
 if not profiles is Array or profiles.size()!=3: return errors+["exactly three encounters required"]
 var seen: Array[String]=[]
 for i in range(profiles.size()):
  var p: Variant=profiles[i]
  if not p is Dictionary: errors.append("encounter must be dictionary");continue
  var id: Variant=p.get("id")
  if not id is String or id.is_empty() or id in seen: errors.append("invalid/duplicate encounter id")
  else: seen.append(id)
  if not p.get("display_name") is String or str(p.get("display_name")).is_empty(): errors.append("missing encounter name")
  if not p.get("phase_locks_enabled") is bool or p.get("phase_locks_enabled")!=(i==2): errors.append("invalid phase flag")
  if not p.get("inherit_boss_deck") is bool or p.get("inherit_boss_deck")!=(i==2): errors.append("invalid inherited deck flag")
  if i<2:
   if not whole(p.get("boss_hp")) or float(p.get("boss_hp",0))<=0: errors.append("invalid boss HP")
   var table: Variant=p.get("boss_deck")
   if not table is Dictionary: errors.append("missing boss deck");continue
   # Guard field types before the existing validator's typed local assignments.
   if not table.get("deck_id") is String or not table.get("pools") is Dictionary: errors.append("invalid boss deck fields");continue
   if table.pools.size()!=3:errors.append("exactly Calm/Heated/Overdrive pools required")
   var safe := true
   for zone in ["Calm","Heated","Overdrive"]:
    var rows: Variant=table.pools.get(zone)
    if not rows is Array: safe=false;continue
    for row in rows:
     if not row is Dictionary or not row.get("card_id") is String: safe=false
   if not safe: errors.append("invalid pool entries");continue
   errors.append_array(Validator.validate_boss_deck_table(table,supported_boss_ids))
 return errors
static func resolve(raw: Dictionary, forge_encounter: Dictionary) -> Dictionary:
 var result: Dictionary=raw.duplicate(true)
 for i in range(result.encounters.size()):
  var p: Dictionary=result.encounters[i]
  var encounter: Dictionary=forge_encounter.duplicate(true)
  encounter["phase_locks_enabled"]=p.phase_locks_enabled
  if i<2:
   encounter["boss_start_hp"]=int(p.boss_hp)
   encounter["boss_start_od"]=0
   encounter["boss_start_shield"]=0
   encounter["boss_deck_id"]=p.boss_deck.deck_id
  p["encounter"]=encounter
 return result

static func validate_contract(c: Dictionary, boss_ids: Array[String]) -> Array[String]:
 var errors: Array[String]=[]
 for key in ["generation","encounter_index","player_hp","deck_seed","boss_seed","run_seed"]:
  if not c.get(key) is int:errors.append("integer required: "+key)
 if not errors.is_empty():return errors
 if c.generation<=0 or c.encounter_index<0 or c.encounter_index>2 or c.player_hp<=0:errors.append("invalid contract bounds")
 for key in ["run_seed","deck_seed","boss_seed"]:
  if c[key]<0 or c[key]>2147483646:errors.append("invalid seed range")
 for key in ["token","encounter_id","display_name"]:
  if not c.get(key) is String or str(c.get(key)).is_empty():errors.append("missing string: "+key)
 if not c.get("deck_ids") is Array or c.deck_ids!=STARTER:errors.append("invalid identities")
 var order: Variant=c.get("deck_order")
 if not order is Array or order.size()!=19:errors.append("invalid order")
 else:
  if not order.all(func(id):return id is String):return errors+["order entries must be strings"]
  var sorted: Array=order.duplicate();sorted.sort()
  var expected: Array=STARTER.duplicate();expected.sort()
  if sorted!=expected or order.slice(0,6)!=STARTER.slice(0,6):errors.append("invalid permutation/opening")
 if not c.get("encounter") is Dictionary:errors.append("missing encounter")
 else:
  if not whole(c.encounter.get("boss_start_hp")) or float(c.encounter.get("boss_start_hp",0))<=0:errors.append("invalid encounter HP")
  if not c.encounter.get("phase_locks_enabled") is bool or c.encounter.phase_locks_enabled!=(c.encounter_index==2):errors.append("invalid encounter phase flag")
 if not c.get("inherit_boss_deck") is bool or c.inherit_boss_deck!=(c.encounter_index==2):errors.append("invalid inherited pool")
 if c.get("inherit_boss_deck")==false:
  var p: Dictionary={"id":"check","display_name":"check","boss_hp":18,"phase_locks_enabled":false,"inherit_boss_deck":false,"boss_deck":c.get("boss_deck")}
  var local: Dictionary={"schema_version":1,"initial_hp":35,"supply":6,"protected_opening":6,"deck_ids":STARTER,"encounters":[p,p.duplicate(true),{"id":"last","display_name":"last","phase_locks_enabled":true,"inherit_boss_deck":true}]}
  local.encounters[1].id="check2"
  errors.append_array(validate(local,STARTER,boss_ids))
 return errors
