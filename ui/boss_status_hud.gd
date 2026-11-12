extends Panel
class_name BossStatusHUD

## Phase 24A: single-authority Boss status HUD.
## Enemy owns the data; this HUD only renders snapshots, click targeting, and tweens.

signal boss_target_clicked

const FALLBACK_BOSS_NAME := "熔炉守卫"
const FALLBACK_PHASE := "PHASE 1"
const FALLBACK_INTENT := "蓄势中…"

const ZONE_COLORS := {
	"Calm": Color(0.22, 0.78, 0.72),
	"Heated": Color(1.0, 0.50, 0.16),
	"Overdrive": Color(1.0, 0.16, 0.12),
}

const MOJIBAKE_MARKERS: Array[String] = [
	"�", "锟", "鈥", "閳", "闁", "閸", "缂", "閻", "鐎", "婵", "婢",
	"瀹", "缁", "闀", "鍗", "鐨", "瀵", "濡", "澧", "宸", "閫", "绁",
	"镭", "鏀", "鏁", "鍏", "璇", "瑕", "锛", "鐔", "钃", "娍",
]

var _enemy: Enemy = null
var _last_snapshot: Dictionary = {}
var _hp_delay_tween: Tween = null
var _damage_float_tween: Tween = null
var _shield_tween: Tween = null
var _clickable := false


func _ready() -> void:
	# Programmatic layout keeps the HUD stable when instantiated by tests or battle_scene.
	set_anchors_and_offsets_preset(PRESET_CENTER_TOP, PRESET_MODE_KEEP_SIZE)
	offset_left = -260.0
	offset_top = 48.0
	offset_right = 260.0
	offset_bottom = 166.0
	custom_minimum_size = Vector2(440.0, 112.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 220
	_set_all_children_ignore(self)


func bind_enemy(enemy: Enemy) -> void:
	_disconnect_enemy()
	_enemy = enemy
	if _enemy == null:
		return
	if not _enemy.combat_state_changed.is_connected(_on_combat_state_changed):
		_enemy.combat_state_changed.connect(_on_combat_state_changed)
	if not _enemy.intent_state_changed.is_connected(_on_intent_state_changed):
		_enemy.intent_state_changed.connect(_on_intent_state_changed)
	apply_snapshot(_enemy.get_boss_status_snapshot(), false)


func refresh_from_enemy() -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	var snapshot: Dictionary = _enemy.get_boss_status_snapshot()
	if snapshot == _last_snapshot:
		return
	apply_snapshot(snapshot, false)


func set_clickable(enabled: bool) -> void:
	_clickable = enabled
	if enabled:
		mouse_filter = Control.MOUSE_FILTER_STOP
		modulate = Color(1.0, 0.85, 0.65, 1.0)
		if not gui_input.is_connected(_on_hud_gui_input):
			gui_input.connect(_on_hud_gui_input)
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate = Color.WHITE
		if gui_input.is_connected(_on_hud_gui_input):
			gui_input.disconnect(_on_hud_gui_input)
	# Children stay transparent to input; the root panel is the only clickable target.
	_set_all_children_ignore(self)


func apply_snapshot(snapshot: Dictionary, animate: bool = true) -> void:
	var max_hp: int = maxi(1, int(snapshot.get("max_hp", 1)))
	var hp: int = clampi(int(snapshot.get("hp", 0)), 0, max_hp)
	var shield: int = maxi(0, int(snapshot.get("shield", 0)))
	var od_max: int = maxi(1, int(snapshot.get("max_od", 10)))
	var od: int = clampi(int(snapshot.get("od", 0)), 0, od_max)
	var zone: String = str(snapshot.get("zone", "Calm"))
	var previous_hp: int = int(_last_snapshot.get("hp", hp))
	var previous_shield: int = int(_last_snapshot.get("shield", shield))

	_set_label_text("Header/BossName", _sanitize_visible_text(str(snapshot.get("name", FALLBACK_BOSS_NAME)), FALLBACK_BOSS_NAME))
	_set_label_text("Header/PhaseLabel", _sanitize_visible_text(str(snapshot.get("phase", FALLBACK_PHASE)), FALLBACK_PHASE).to_upper())

	var hp_bar: ProgressBar = get_node("HPStack/HPBar") as ProgressBar
	var hp_delay_bar: ProgressBar = get_node("HPStack/HPDelayBar") as ProgressBar
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_delay_bar.max_value = max_hp
	_set_label_text("HPStack/HPValue", "%d/%d" % [hp, max_hp])
	_set_label_text("MetaRow/ShieldValue", "SHIELD %d" % shield)
	_set_label_text("MetaRow/ODValue", "OD %d/%d" % [od, od_max])
	_set_label_text("MetaRow/ZoneValue", zone.to_upper())

	var zone_label: Label = get_node("MetaRow/ZoneValue") as Label
	zone_label.add_theme_color_override("font_color", ZONE_COLORS.get(zone, Color.WHITE))
	_apply_intent(snapshot)

	if not animate or _last_snapshot.is_empty():
		hp_delay_bar.value = hp
	elif hp < previous_hp:
		_play_hp_loss_feedback(previous_hp, hp, max_hp)
	elif shield < previous_shield:
		_play_shield_feedback()
	else:
		hp_delay_bar.value = hp
	_last_snapshot = snapshot.duplicate(true)


func get_debug_snapshot() -> Dictionary:
	return {
		"hp": int((get_node("HPStack/HPBar") as ProgressBar).value),
		"hp_delay": int((get_node("HPStack/HPDelayBar") as ProgressBar).value),
		"hp_text": (get_node("HPStack/HPValue") as Label).text,
		"shield_text": (get_node("MetaRow/ShieldValue") as Label).text,
		"od_text": (get_node("MetaRow/ODValue") as Label).text,
		"zone_text": (get_node("MetaRow/ZoneValue") as Label).text,
		"intent_text": (get_node("IntentRow/IntentText") as Label).text,
	}


func _apply_intent(snapshot: Dictionary) -> void:
	var raw_text: String = _sanitize_visible_text(str(snapshot.get("intent_text", "")), "").strip_edges()
	var intent_label: Label = get_node("IntentRow/IntentText") as Label
	var intent_icon: ColorRect = get_node("IntentRow/IntentIcon") as ColorRect
	if raw_text.is_empty():
		intent_label.text = FALLBACK_INTENT
		intent_icon.visible = false
		return
	intent_label.text = raw_text
	intent_icon.visible = true
	intent_icon.color = _danger_color(str(snapshot.get("intent_danger", "LOW")))


func _sanitize_visible_text(text: String, fallback: String) -> String:
	var clean: String = text.strip_edges()
	if clean.is_empty():
		return fallback
	for marker: String in MOJIBAKE_MARKERS:
		if clean.find(marker) >= 0:
			return fallback
	return clean


func _danger_color(danger: String) -> Color:
	match danger:
		"MID":
			return Color(1.0, 0.55, 0.12)
		"HIGH", "OVERDRIVE":
			return Color(1.0, 0.12, 0.10)
		_:
			return Color(0.20, 0.78, 0.72)


func _play_hp_loss_feedback(previous_hp: int, hp: int, max_hp: int) -> void:
	_kill_tween(_hp_delay_tween)
	_kill_tween(_damage_float_tween)

	var hp_delay_bar: ProgressBar = get_node("HPStack/HPDelayBar") as ProgressBar
	hp_delay_bar.max_value = max_hp
	hp_delay_bar.value = previous_hp
	_hp_delay_tween = create_tween()
	_hp_delay_tween.tween_interval(0.18)
	_hp_delay_tween.tween_property(hp_delay_bar, "value", hp, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var damage_float: Label = get_node("HPStack/DamageFloat") as Label
	damage_float.text = "-%d" % maxi(0, previous_hp - hp)
	damage_float.position = Vector2((get_node("HPStack") as Control).size.x - 72.0, -4.0)
	damage_float.modulate = Color(1.0, 0.28, 0.18, 1.0)
	damage_float.visible = true
	_damage_float_tween = create_tween()
	_damage_float_tween.set_parallel(true)
	_damage_float_tween.tween_property(damage_float, "position:y", -22.0, 0.45)
	_damage_float_tween.tween_property(damage_float, "modulate:a", 0.0, 0.45)
	_damage_float_tween.chain().tween_callback(_hide_damage_float)


func _hide_damage_float() -> void:
	var damage_float: Label = get_node_or_null("HPStack/DamageFloat") as Label
	if damage_float != null and is_instance_valid(damage_float):
		damage_float.visible = false


func _play_shield_feedback() -> void:
	_kill_tween(_shield_tween)
	var shield_label: Label = get_node("MetaRow/ShieldValue") as Label
	shield_label.modulate = Color(0.25, 1.0, 1.0, 1.0)
	_shield_tween = create_tween()
	_shield_tween.tween_property(shield_label, "modulate", Color.WHITE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_combat_state_changed(snapshot: Dictionary) -> void:
	apply_snapshot(snapshot, true)


func _on_intent_state_changed(snapshot: Dictionary) -> void:
	apply_snapshot(snapshot, true)


func _on_hud_gui_input(event: InputEvent) -> void:
	if not _clickable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		boss_target_clicked.emit()


func _set_label_text(path: String, value: String) -> void:
	var label: Label = get_node(path) as Label
	label.text = value


func _set_all_children_ignore(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_all_children_ignore(child)


func _disconnect_enemy() -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	if _enemy.combat_state_changed.is_connected(_on_combat_state_changed):
		_enemy.combat_state_changed.disconnect(_on_combat_state_changed)
	if _enemy.intent_state_changed.is_connected(_on_intent_state_changed):
		_enemy.intent_state_changed.disconnect(_on_intent_state_changed)


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _exit_tree() -> void:
	_kill_tween(_hp_delay_tween)
	_kill_tween(_damage_float_tween)
	_kill_tween(_shield_tween)
	_disconnect_enemy()
