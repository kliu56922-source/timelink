extends Node
## Observation only. Training exports are separate from match telemetry/saves.
var owner_ref: WeakRef
var entries: Array[Dictionary]=[]
var _last_state: Dictionary={}
var _elapsed:=0.0
var started_us:=0
func setup168a(owner: Node) -> void:
 owner_ref=weakref(owner);started_us=Time.get_ticks_usec()
 owner.recipe166.committed.connect(func(r):capture168a("recipe_committed",r))
 owner.support166c.committed.connect(func(r):capture168a("maintenance_committed",r))
 owner.advance165.step_committed.connect(func(i,r):capture168a("advance_step",{"step":i,"native_receipt":r}))
 owner.battle.player_card_committed168a.connect(func(card,r):capture168a("card_committed",{"source_id":card.card_id,"source_uid":card.get_instance_id(),"source_name":card.get_display_name(),"native_receipt":r}))
 owner.battle.weakpoint_attack_committed.connect(func(r):capture168a("part_committed",r))
 capture168a("training_started")
func scene168a() -> Variant:return owner_ref.get_ref() if owner_ref!=null else null
func _process(delta: float) -> void:
 _elapsed+=delta
 if _elapsed<0.15:return
 _elapsed=0.0
 var s: Variant=scene168a()
 if s!=null and s.ready168a:
  var state: Dictionary=s.training_snapshot168a()
  if state!=_last_state:capture168a("state_changed")
func capture168a(kind: String,receipt: Dictionary={}) -> void:
 var s: Variant=scene168a()
 if s==null:return
 var state: Dictionary=s.training_snapshot168a()
 entries.append({"kind":kind,"ms":float(Time.get_ticks_usec()-started_us)/1000.0,"round":state.player_round,"receipt":receipt.duplicate(true),"state":state.duplicate(true)})
 _last_state=state.duplicate(true)
func snapshot168a() -> Dictionary:
 var s: Variant=scene168a()
 if s==null:return {}
 return {"schema":1,"mode":"168A_training","counts_for_winrate":false,"scope":"fixed19 quiet encounter; real player rules; observed receipt/state changes, not proof all combos work; times include idle/tool waiting","state":s.training_snapshot168a(),"entries":entries.duplicate(true),"catalog":s.training_catalog168a(),"input_time":s.metrics167d.snapshot167d()}
func json_safe168a(value: Variant) -> Variant:
 if value is Dictionary:
  var out: Dictionary={}
  for key: Variant in value:out[str(key)]=json_safe168a(value[key])
  return out
 if value is Array:
  var out: Array=[]
  for item: Variant in value:out.append(json_safe168a(item))
  return out
 if value is Vector2i or value is Vector2:return {"x":value.x,"y":value.y}
 if value is Vector3:return {"x":value.x,"y":value.y,"z":value.z}
 if value is StringName:return str(value)
 if value is Object:
  if not is_instance_valid(value):return null
  if value is CardData:return {"uid":value.get_instance_id(),"id":value.card_id,"name":value.get_display_name()}
  return {"type":value.get_class(),"uid":value.get_instance_id()}
 return value
func export168a(path: String="") -> Dictionary:
 if path.is_empty():path="user://training168a/session-%s-%s.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
 if not path.begins_with("user://training168a/") or path.contains("..") or path.get_extension()!="json":return {"ok":false,"reason":"仅保存到独立训练记录目录"}
 DirAccess.make_dir_recursive_absolute("user://training168a")
 # Never overwrite an earlier session/report.
 if FileAccess.file_exists(path):return {"ok":false,"reason":"记录已存在，请使用新文件名"}
 var file:=FileAccess.open(path,FileAccess.WRITE)
 if file==null:return {"ok":false,"reason":"无法保存训练记录"}
 file.store_string(JSON.stringify(json_safe168a(snapshot168a()),"\t"));file.close()
 return {"ok":true,"path":ProjectSettings.globalize_path(path)}
