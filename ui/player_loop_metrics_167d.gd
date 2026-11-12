extends Node
## Input/time observations only. No commands, RNG, save writes or auto choices.
var owner_ref: WeakRef
var started_us:=0
var last_us:=0
var inputs: Array[Dictionary]=[]
var buckets_ms: Dictionary={}
var bucket_frames: Dictionary={}
var unfocused_ms:=0.0
var frozen:=false
var _frame:=-1
var _seen: Dictionary={}
var _observers: Array[WeakRef]=[]
func setup167d(owner: Node) -> void:
 owner_ref=weakref(owner);started_us=Time.get_ticks_usec();last_us=started_us
 _attach_window167d(owner.get_window())
 for window: Node in owner.find_children("*","Window",true,false):_attach_window167d(window)
 owner.get_tree().node_added.connect(_new_node167d)
func scene167d() -> Variant:
 return owner_ref.get_ref() if owner_ref!=null else null
func _attach_window167d(window: Window) -> void:
 var observer:=preload("res://ui/window_input_observer_167d.gd").new()
 observer.name="LoopInputObserver167D";observer.target_ref=weakref(self);window.add_child(observer);_observers.append(weakref(observer))
func _new_node167d(node: Node) -> void:
 var s: Variant=scene167d()
 if s!=null and node is Window and s.is_ancestor_of(node):_attach_window167d(node)
func observe167d(event: InputEvent) -> void:
 if frozen:return
 var s: Variant=scene167d()
 if not is_instance_valid(s) or s.battle_ended:return
 var kind:=""
 if event is InputEventMouseButton and event.pressed:kind="wheel" if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_LEFT,MOUSE_BUTTON_WHEEL_RIGHT] else "mouse"
 elif event is InputEventKey and event.pressed and not event.echo:kind="key"
 if kind.is_empty():return
 var frame:=Engine.get_process_frames()
 if _frame!=frame:_seen.clear();_frame=frame
 var uid:=event.get_instance_id()
 if _seen.has(uid):return
 _seen[uid]=true
 inputs.append({"kind":kind,"code":event.keycode if event is InputEventKey else event.button_index,"ms":float(Time.get_ticks_usec()-started_us)/1000.0,"round":s.battle.opening166b.player_round,"phase":"部署" if s.battle.preparation_active166b() else "交战","watch":_kind167d(s)})
func _kind167d(s: Variant) -> String:
 if s.recipe166.running:return "展开"
 if s.support166c.running:return "维护"
 if s.advance165.running:return "连续进攻"
 if s.body_busy166d:return "本体收尾"
 if s.transition166d:return "Boss或换回合"
 if s.axis155.running or s._presentation_end_turn_blocked or (s._battle_presentation_director!=null and s._battle_presentation_director.is_busy()):return "其他执行"
 return "决策或空闲"
func _process(_delta: float) -> void:
 if frozen:return
 var s: Variant=scene167d()
 if not is_instance_valid(s):return
 var now:=Time.get_ticks_usec();var ms:=float(now-last_us)/1000.0;last_us=now
 var kind:=_kind167d(s)
 buckets_ms[kind]=float(buckets_ms.get(kind,0.0))+ms;bucket_frames[kind]=int(bucket_frames.get(kind,0))+1
 if not s.get_window().has_focus():unfocused_ms+=ms
 if s.battle_ended:frozen=true
func snapshot167d() -> Dictionary:
 return {"inputs":inputs.duplicate(true),"input_count":inputs.size(),"mouse_presses":inputs.filter(func(e):return e.kind=="mouse").size(),"key_presses":inputs.filter(func(e):return e.kind=="key").size(),"wheel_presses":inputs.filter(func(e):return e.kind=="wheel").size(),"buckets_ms":buckets_ms.duplicate(),"bucket_frames":bucket_frames.duplicate(),"unfocused_ms":unfocused_ms,"frozen":frozen,"scope":"ready-to-native-ending actual input events; release/motion/echo excluded; busy frames measured separately from decision/idle (including tool waiting); loading separate; no human winrate or universal ratio"}
func _exit_tree() -> void:
 for ref: WeakRef in _observers:
  var observer: Variant=ref.get_ref()
  if is_instance_valid(observer):observer.queue_free()
 var s: Variant=scene167d()
 if is_instance_valid(s) and s.get_tree()!=null and s.get_tree().node_added.is_connected(_new_node167d):s.get_tree().node_added.disconnect(_new_node167d)
