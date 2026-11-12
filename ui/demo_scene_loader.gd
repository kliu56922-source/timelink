extends Node
## Root-owned loader: a departed menu cannot receive a late scene change.
signal completed(result: Dictionary)
var owner_ref: WeakRef
var target:=""
var phase:="paint"
var frames:=2
var worker: Thread
var packed: PackedScene
var started_ms:=0
var metrics: Dictionary={}
func _enter_tree() -> void:add_to_group("demo_scene_loaders")
static func _load_resource(path: String) -> Resource:
	return ResourceLoader.load(path,"PackedScene")
func _exit_tree() -> void:
	if worker!=null and worker.is_started():worker.wait_to_finish()
	worker=null
func setup(owner: Control,path: String) -> void:
	owner_ref=weakref(owner);target=path;started_ms=Time.get_ticks_msec()
	metrics={"path":path,"request_ms":0,"resource_ms":0,"commit_ms":0}
func home() -> Variant:
	var owner: Variant=owner_ref.get_ref() if owner_ref!=null else null
	return owner if is_instance_valid(owner) and owner.is_inside_tree() and get_tree().current_scene==owner else null
func finish(ok: bool,reason: String="") -> void:
	if phase=="done":return
	phase="done";metrics["ok"]=ok;metrics["reason"]=reason;metrics["elapsed_ms"]=Time.get_ticks_msec()-started_ms
	completed.emit(metrics.duplicate(true));queue_free()
func fail(reason: String) -> void:
	var owner: Variant=home()
	if owner!=null:owner._scene_start_failed(reason)
	print("[DEMO_LOAD] ",reason);finish(false,reason)
func _process(_delta: float) -> void:
	if phase=="done":return
	var owner: Variant=home()
	if phase=="paint":
		if owner==null:finish(false,"menu_left_before_request");return
		frames-=1
		if frames>0:return
		# Serialize reads even when another menu was left while loading.
		for other in get_tree().get_nodes_in_group("demo_scene_loaders"):
			if other!=self and other.worker!=null and other.worker.is_started():
				owner._scene_start_message("正在等待前次资源准备完成，请稍候…");return
		if not ResourceLoader.exists(target,"PackedScene"):fail("战斗资源无法打开，请重试或检查文件完整性。");return
		worker=Thread.new()
		var error:=worker.start(_load_resource.bind(target))
		if error!=OK:fail("战斗加载无法开始，请稍后重试。");return
		metrics.request_ms=Time.get_ticks_msec()-started_ms;phase="loading";return
	if phase=="loading":
		if worker.is_alive():
			if owner!=null:owner._scene_start_message("正在加载战斗资源… 已等待%d秒"%int((Time.get_ticks_msec()-started_ms)/1000.0))
			return
		# Drain a completed request even if its menu was removed while loading.
		packed=worker.wait_to_finish() as PackedScene;worker=null
		metrics.resource_ms=Time.get_ticks_msec()-started_ms
		if owner==null:finish(false,"menu_left_during_load");return
		if packed==null:fail("战斗场景无法打开，请重试。");return
		owner._scene_start_message("资源就绪，正在布置战场…")
		phase="handoff";frames=2;return
	if phase=="handoff":
		if owner==null:finish(false,"menu_left_before_handoff");return
		frames-=1
		if frames>0:return
		var begun:=Time.get_ticks_msec()
		var error:=get_tree().change_scene_to_packed(packed)
		metrics.commit_ms=Time.get_ticks_msec()-begun
		if error!=OK:fail("战斗场景无法进入，请重试。");return
		print("[DEMO_LOAD] ",metrics);finish(true)
