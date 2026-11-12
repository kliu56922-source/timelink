extends RefCounted
## One context owns one instance. This target does not occupy a unit/structure cell.
const ID:="pressure_arm"
var _integrity:=2
var _revision:=0
func snapshot() -> Dictionary:
	return {"id":ID,"name":"承压护臂","column":1,"integrity":_integrity,"max_integrity":2,"broken":_integrity==0,"rupture_damage":10,"revision":_revision,"battle_identity":get_instance_id()}
func _commit_hit(amount: int) -> Dictionary:
	var before:=_integrity
	if before<=0 or amount<=0:return {"integrity_loss":0,"just_broken":false}
	_integrity=maxi(0,before-amount);_revision+=1
	return {"integrity_loss":before-_integrity,"just_broken":_integrity==0}
