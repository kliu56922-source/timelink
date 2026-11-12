extends RefCounted
const Base=preload("res://core/run/run_foundation_config.gd")
const CARD_IDS: Array[String]=["P04","P09","P12","P14","P17","P18"]
const MODULE_IDS: Array[String]=["warm","armor","draw"]
const UPGRADE_IDS: Array[String]=["S01","P02"]
static func validate(raw: Variant) -> Array[String]:
 if not raw is Dictionary:return ["growth config must be dictionary"]
 var errors: Array[String]=[]
 if not Base.whole(raw.get("schema_version")) or raw.get("schema_version")!=1:errors.append("invalid growth schema")
 for key in ["cards","modules"]:
  var expected: Array=CARD_IDS if key=="cards" else MODULE_IDS
  var rows: Variant=raw.get(key)
  if not rows is Array or rows.size()!=expected.size():errors.append("invalid "+key+" count");continue
  var seen: Array=[]
  for row in rows:
   if not row is Dictionary:errors.append("invalid row");continue
   if not row.get("id") is String or row.get("id") not in expected or row.get("id") in seen:errors.append("invalid/duplicate id")
   else:seen.append(row.id)
   for field in (["name","description","related_name"] if key=="cards" else ["name","description"]):
    if not row.get(field) is String or str(row.get(field)).is_empty():errors.append("missing "+field)
   if key=="cards" and (not row.get("role") is String or not row.get("related") is String or row.get("related") not in Base.STARTER):errors.append("invalid card relation")
 return errors
static func validate_contract(c: Dictionary,boss_ids: Array[String]) -> Array[String]:
 var errors: Array[String]=[]
 if not c.get("growth_schema") is int or c.get("growth_schema")!=1:errors.append("invalid growth contract schema")
 var ids: Variant=c.get("deck_ids");var order: Variant=c.get("deck_order")
 if not ids is Array or ids.size()<19 or ids.size()>21:return errors+["invalid growth deck size"]
 if not ids.all(func(id):return id is String):return errors+["card ids must be strings"]
 if ids.slice(0,19)!=Base.STARTER or ids.size()-19!=ids.slice(19).size():errors.append("base identities/order changed")
 var seen: Array=[]
 for id in ids:
  if id not in Base.STARTER and id not in CARD_IDS:errors.append("unknown growth card")
  if id in seen:errors.append("duplicate growth card")
  seen.append(id)
 if not order is Array or order.size()!=ids.size() or not order.all(func(id):return id is String):return errors+["invalid growth order"]
 var sorted: Array=order.duplicate();sorted.sort();var expected: Array=ids.duplicate();expected.sort()
 if sorted!=expected or order.slice(0,6)!=Base.STARTER.slice(0,6):errors.append("invalid growth permutation/opening")
 var upgrades: Variant=c.get("upgrades")
 if not upgrades is Dictionary or upgrades.size()>2:errors.append("invalid upgrade count")
 else:
  for id in upgrades:
   if id not in UPGRADE_IDS or not upgrades[id] is int or upgrades[id]!=1:errors.append("invalid upgrade")
 var modules: Variant=c.get("modules")
 if not modules is Array or modules.size()>2:errors.append("invalid module count")
 else:
  var module_seen: Array=[]
  for id in modules:
   if not id is String or id not in MODULE_IDS or id in module_seen:errors.append("invalid module")
   module_seen.append(id)
 # Retain every base seed/token/HP/encounter check; only normalize validated deck fields.
 var base: Dictionary=c.duplicate(true);base.deck_ids=Base.STARTER.duplicate();base.deck_order=Base.STARTER.duplicate()
 errors.append_array(Base.validate_contract(base,boss_ids))
 return errors
