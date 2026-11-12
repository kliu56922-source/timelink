extends RefCounted
## 162B graybox: no additional defense/OD rewards or final balance claim.
static func values() -> Dictionary:
	return preload("res://core/config/single_weakpoint_profile.gd").values()
static func parts() -> Array[Dictionary]:
	return [
		{"id":"pressure_arm","name":"承压护臂","column":1,"max_integrity":2,"rupture_damage":10},
		{"id":"energy_valve","name":"供能阀门","column":3,"max_integrity":2,"rupture_damage":10},
		{"id":"core_ring","name":"炉心约束环","column":-1,"max_integrity":4,"rupture_damage":12},
	]
