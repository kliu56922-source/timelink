extends RefCounted
## Battle-local targets, never board occupants. Exposure is permanent once earned.
var _definitions: Array[Dictionary]=preload("res://core/config/triple_weakpoint_profile.gd").parts()
var _integrity: Dictionary={}
var _revision:=0
func _init() -> void:
	for part in _definitions:_integrity[part.id]=int(part.max_integrity)
func snapshot(id: String) -> Dictionary:
	for part in _definitions:
		if part.id!=id:continue
		var result: Dictionary=part.duplicate(true)
		result["integrity"]=int(_integrity[id]);result["broken"]=int(_integrity[id])==0
		result["exposed"]=id!="core_ring" or (int(_integrity.pressure_arm)==0 and int(_integrity.energy_valve)==0)
		result["revision"]=_revision;result["battle_identity"]=get_instance_id()
		return result
	return {}
func snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for part in _definitions:result.append(snapshot(part.id))
	return result
func _commit_hit(id: String,amount: int) -> Dictionary:
	var part:=snapshot(id)
	if part.is_empty() or not part.exposed or part.broken or amount<=0:return {"integrity_loss":0,"just_broken":false}
	var before: int=_integrity[id]
	_integrity[id]=maxi(0,before-amount);_revision+=1
	return {"integrity_loss":before-int(_integrity[id]),"just_broken":int(_integrity[id])==0}
