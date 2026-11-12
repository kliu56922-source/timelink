extends "res://ui/quick_tactical_axis_panel.gd"
## 158 changes visual order and resumes unpaid inspection, never native actions.
var _waiting_revision:=-1
var _last_camera:=Transform3D.IDENTITY
var _stable_camera_frames:=0
var _order_key:=""
var _was_ready:=true
func setup(scene: Node) -> void:
	super.setup(scene)
	(text.get_parent().get_child(0) as Label).text="小轴158 · 格表随镜头排列，格号不变\n选齐看预览，仍须确认；原19牌与费用不变"
	set_process(true)
func open_axis(axis: String) -> void:
	_waiting_revision=-1;_order_key=""
	super.open_axis(axis)
	_order_grid()
func _preview_selected(revision: int) -> void:
	var s: Variant=_scene.get_ref()
	if not is_instance_valid(s) or revision!=_revision or not panel.visible or s.axis155.running:return
	_waiting_revision=-1
	var complete: bool=build_cell.selected>0 and unit_cell.selected>0 if mode.selected==0 else facility.selected>0 and actor.selected>0 and target.selected>0
	if not complete:return
	if not s.battle_ended and not s.axis155_native_ready():
		quote={};confirm_button.disabled=true;_waiting_revision=revision
		text.text="等待当前行动完成，随后恢复此方案的预览。\n尚未确认或支付；仍由你确认执行。"
		return
	super._preview_selected(revision)
func _process(_delta: float) -> void:
	if not _quick_ready or _scene==null:return
	var s: Variant=_scene.get_ref()
	if not is_instance_valid(s):return
	if not panel.visible:
		if _waiting_revision>=0:_waiting_revision=-1;quote={};confirm_button.disabled=true
		return
	if s.axis155.running:return
	var ready: bool=s.axis155_native_ready()
	if s.battle_ended:
		_waiting_revision=-1
		if not quote.is_empty():s.axis155.stop("战斗已结束");quote={}
		confirm_button.disabled=true;text.text="本局已结束，原方案不再执行。"
		return
	if not ready and _was_ready:_invalidate()
	_was_ready=ready
	if ready and _waiting_revision==_revision:
		var revision:=_waiting_revision;_waiting_revision=-1;_preview_selected.call_deferred(revision)
	var camera: Camera3D=s._get_3d_camera()
	if camera==null:return
	if not camera.global_transform.is_equal_approx(_last_camera):
		_last_camera=camera.global_transform;_stable_camera_frames=0
	else:_stable_camera_frames+=1
	if _stable_camera_frames>=6 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):_order_grid()
func _order_grid() -> void:
	var s: Variant=_scene.get_ref()
	if not is_instance_valid(s):return
	var a: Vector2=s._project_tactical_cell_to_screen(Vector2i(0,2));var b: Vector2=s._project_tactical_cell_to_screen(Vector2i(4,2))
	var c: Vector2=s._project_tactical_cell_to_screen(Vector2i(2,0));var d: Vector2=s._project_tactical_cell_to_screen(Vector2i(2,4))
	if not a.is_finite() or not b.is_finite() or not c.is_finite() or not d.is_finite():return
	var dx:=b-a;var dy:=d-c
	var horizontal_x: bool=absf(dx.x)>=absf(dy.x)
	var horizontal_positive: bool=dx.x>=0 if horizontal_x else dy.x>=0
	var vertical_positive: bool=dy.y>=0 if horizontal_x else dx.y>=0
	var key: String=str(horizontal_x)+str(horizontal_positive)+str(vertical_positive)
	if key==_order_key:return
	_order_key=key
	var grid: GridContainer=cell_buttons[Vector2i.ZERO].get_parent()
	for row in range(5):
		for col in range(5):
			var horizontal:=col if horizontal_positive else 4-col
			var vertical:=row if vertical_positive else 4-row
			var cell:=Vector2i(horizontal,vertical) if horizontal_x else Vector2i(vertical,horizontal)
			grid.move_child(cell_buttons[cell],row*5+col)
