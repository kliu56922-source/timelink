extends RefCounted
## Pure perspective fit of interaction points, independent of board decoration/gameplay.
static func project_bounds(points: Array[Vector3], origin: Vector3, basis: Basis, projection: Projection, viewport: Vector2, distance: float, horizontal: float, vertical: float) -> Rect2:
	var camera:=Transform3D(basis,origin+basis*Vector3(horizontal,vertical,distance)).affine_inverse()
	var bounds:=Rect2();var first:=true
	for point: Vector3 in points:
		var local: Vector3=camera*point
		var clip: Vector4=projection*Vector4(local.x,local.y,local.z,1.0)
		if clip.w<=0.01:return Rect2(Vector2(-1e6,-1e6),Vector2(2e6,2e6))
		var screen:=Vector2((clip.x/clip.w+1.0)*viewport.x*0.5,(1.0-clip.y/clip.w)*viewport.y*0.5)
		if first:bounds=Rect2(screen,Vector2.ZERO);first=false
		else:bounds=bounds.expand(screen)
	return bounds
static func fit(points: Array[Vector3], origin: Vector3, projection: Projection, viewport: Vector2, safe: Rect2, yaw: float=90.0,pitch: float=54.0) -> Dictionary:
	if points.is_empty() or viewport.x<=0 or viewport.y<=0 or safe.size.x<=0 or safe.size.y<=0:return {"ok":false}
	var basis:=Basis(Vector3.UP,deg_to_rad(yaw))*Basis(Vector3.RIGHT,deg_to_rad(-pitch))
	var lower:=3.0;var upper:=60.0;var result: Dictionary={}
	for step in range(27):
		var distance: float=upper if step==0 else (lower+upper)*0.5
		var horizontal:=0.0;var vertical:=0.0
		var bounds:=project_bounds(points,origin,basis,projection,viewport,distance,horizontal,vertical)
		for center_step in range(5):
			var midpoint: Vector3=Vector3.ZERO
			for point: Vector3 in points:midpoint+=point
			midpoint/=points.size()
			var depth: float=distance-(basis.inverse()*(midpoint-origin)).z
			horizontal+=(bounds.get_center().x-safe.get_center().x)*depth/(projection.x.x*viewport.x*0.5)
			vertical+=(safe.get_center().y-bounds.get_center().y)*depth/(projection.y.y*viewport.y*0.5)
			bounds=project_bounds(points,origin,basis,projection,viewport,distance,horizontal,vertical)
		var fits: bool=safe.grow(0.05).encloses(bounds)
		if fits:
			upper=distance
			result={"ok":true,"focus_fit":true,"yaw":yaw,"pitch":pitch,"distance":distance,"h_offset":horizontal,"v_offset":vertical,"pan_offset":Vector3.ZERO,"projected_rect":bounds}
		else:lower=distance
	return result
