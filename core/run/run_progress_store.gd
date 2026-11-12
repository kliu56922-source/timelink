extends RefCounted
## One manually saved battle node; never touches legacy save_data or player stats.
const Meta=preload("res://core/run/run_meta_session.gd")
var path:="user://roguelike_progress.json"
func _fail(reason: StringName) -> Dictionary:return {"ok":false,"reason_code":reason}
static func _numbers(value: Variant) -> Variant:
 if value is float and is_finite(value) and value==floor(value) and absf(value)<=2147483646:return int(value)
 if value is Array:
  var result: Array=[]
  for item in value:result.append(_numbers(item))
  return result
 if value is Dictionary:
  var result: Dictionary={}
  for key in value:result[key]=_numbers(value[key])
  return result
 return value
func _validate(config: Dictionary,data: Variant) -> Dictionary:
 if not data is Dictionary or not Meta._keys(data,["schema","unlocks","checkpoint"]) or not Meta._integer(data.schema,1,1) or not data.unlocks is Array or data.unlocks.size()>2:return _fail(&"invalid_progress")
 var seen: Array=[]
 for id in data.unlocks:
  if not id is String or id not in ["armor","warm"] or id in seen:return _fail(&"invalid_unlocks")
  seen.append(id)
 if data.checkpoint!=null:
  if not data.checkpoint is Dictionary or not Meta._integer(data.checkpoint.get("generation"),1,2147483645):return _fail(&"invalid_checkpoint")
  if not Meta.restore_checkpoint(config,data.checkpoint,data.checkpoint.generation+1).ok:return _fail(&"invalid_checkpoint")
  if data.checkpoint.profile!="base" and data.checkpoint.profile not in seen:return _fail(&"locked_profile")
 return {"ok":true,"data":data.duplicate(true)}
func read(config: Dictionary) -> Dictionary:
 var source:=path
 if not FileAccess.file_exists(source):
  if FileAccess.file_exists(path+".previous"):source=path+".previous"
  else:return {"ok":true,"data":{"schema":1,"unlocks":[],"checkpoint":null},"recovered":false}
 var file:=FileAccess.open(source,FileAccess.READ)
 if file==null:return _fail(&"read_failed")
 if file.get_length()>65536:file.close();return _fail(&"save_too_large")
 var text:=file.get_as_text();file.close();var json:=JSON.new()
 if json.parse(text)!=OK:return _fail(&"invalid_json")
 var result: Dictionary=_validate(config,_numbers(json.data))
 if result.ok:result.recovered=source!=path
 return result
func record(config: Dictionary,session: RefCounted,save_node: bool) -> Dictionary:
 var old: Dictionary=read(config)
 if not old.ok:return old
 var snap: Dictionary=session.snapshot();var node: Variant=null
 if save_node:
  var exported: Dictionary=session.export_checkpoint()
  if not exported.ok:return exported
  node=exported.checkpoint
 elif snap.state not in ["won","lost"]:return _fail(&"not_terminal")
 var data: Dictionary=old.data.duplicate(true)
 for row in snap.results:
  if row.victory and row.encounter_index in [0,1]:
   var id: String="armor" if row.encounter_index==0 else "warm"
   if id not in data.unlocks:data.unlocks.append(id)
 data.checkpoint=node
 var checked: Dictionary=_validate(config,data)
 if not checked.ok:return checked
 var result: Dictionary=_write(data)
 if result.ok:result.data=data.duplicate(true)
 return result
func _write(data: Dictionary) -> Dictionary:
 var suffix:=".%d-%d"%[Time.get_ticks_usec(),get_instance_id()]
 var temp:=path+suffix+".tmp";var backup:=path+suffix+".bak"
 if FileAccess.file_exists(temp) or FileAccess.file_exists(backup):return _fail(&"temporary_exists")
 var file:=FileAccess.open(temp,FileAccess.WRITE)
 if file==null:return _fail(&"write_failed")
 file.store_string(JSON.stringify(data,"\t",true));file.flush();var code:=file.get_error();file.close()
 if code!=OK:return _fail(&"write_failed")
 var source:=path if FileAccess.file_exists(path) else path+".previous"
 if FileAccess.file_exists(source):
  if DirAccess.copy_absolute(source,backup)!=OK:return _fail(&"backup_failed")
  # Windows rename may delete its target before failing. Keep a readable fallback.
  if DirAccess.copy_absolute(backup,path+".previous")!=OK:return _fail(&"recovery_copy_failed")
  if FileAccess.get_file_as_bytes(backup)!=FileAccess.get_file_as_bytes(path+".previous"):return _fail(&"recovery_copy_failed")
 if _replace_file(temp,path)!=OK:return _fail(&"replace_failed")
 return {"ok":true}

func _replace_file(source: String,destination: String) -> Error:return DirAccess.rename_absolute(source,destination)
