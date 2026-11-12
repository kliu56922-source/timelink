extends "res://scenes/battle/battle_scene.gd"
## GB-1: 独立、可复现的完整战斗入口。
## 只覆盖初始化接线（_ready 预检 / _setup_game / _setup_deck / _refresh_tables），
## 其余沿用原 battle_scene 权威：原 _ready 仍负责 UI、首回合与正式起手抽牌，本脚本不复制、不重放该流程。
##
## R1 修订：本场景在调用父 _ready 之前一次性加载并校验固定牌序与必需规则，并把结果缓存下来供
## _setup_game / _setup_deck 消费。校验失败时父初始化完全不执行——不建 context、不开回合、不抽牌、
## 不写进度——只呈现本站独立的失败页与返回入口。

const GB1_ENTRY_PATH := "res://scenes/experiments/gb1_integrated_battle.tscn"
const GB1_MENU_PATH := "res://scenes/menu/main_menu.tscn"
const GB1_SIEGE_RULES_PATH := "res://data/config/tactical_siege_rules.json"

## 固定实验牌序：前六张由原 starting_hand_size=6 与 Player.draw 正式抽出。
const GB1_ORDER: Array[String] = [
	"P01", "P02", "P05", "P07", "P08", "P23", "P06", "P22",
	"P10", "P11", "P18", "P03", "P04", "P13", "P17", "P20"
]

const GB1_BOSS_SEED := 2701
const GB1_CARD_CONTAINER := "GB1CardContainer"
const GB1_HELP_PANEL_PATH := NodePath("GB1HelpLayer/GB1HelpPanel")
const GB1_RESTART_BUTTON_PATH := NodePath("GB1HelpLayer/GB1HelpPanel/Body/GB1RestartButton")
const GB1_FAILURE_LAYER := "GB1FailureLayer"
const GB1_FAILURE_BACKDROP := "GB1FailureBackdrop"
const GB1_FAILURE_RETURN_BUTTON := "GB1FailureReturnButton"
const GB1_FALLBACK_LABEL := "GB1CardTextFallback"

## R3：只在实验入口为缺插画的实验卡补最小可读文案。
## 它是卡面辨识用的说明，不替代确认时显示的最终结算结果。
const GB1_CARD_TEXT_FALLBACK := {
	"P22": "铸城修补\n\n选择己方受损墙/门楼\n耐久 +1",
	"P23": "地脉隆起\n\n选择己方合法地块\n高度 +1（最高H2）",
}

const GB1Catalog := preload("res://core/deck/card_catalog_loader.gd")
const GB1RepairRules := preload("res://core/config/tactical_repair_rule_snapshot.gd")
const GB1RaiseRules := preload("res://core/config/tactical_terrain_raise_rule_snapshot.gd")

var _gb1_help_panel: Control = null
var _gb1_restart_button: Button = null
var _gb1_restarting := false

# ── R1 / R2：父初始化之前的一次性预检结果 ──
var _gb1_startup_ok := false
var _gb1_startup_problems: Array[String] = []
var _gb1_load_problems: Array[String] = []
var _gb1_owned_cards: Array = []          # 本次加载创建的全部 CardData 实例
var _gb1_cards_by_id: Dictionary = {}     # card_id -> CardData（本次加载的独立实例）
var _gb1_selected_cards: Array = []       # 按 GB1_ORDER 选中的实例
var _gb1_siege_snapshot: Variant = null
var _gb1_repair_snapshot: Variant = null
var _gb1_raise_snapshot: Variant = null

# ── R1：失败页 ──
var _gb1_failure_layer: CanvasLayer = null
var _gb1_failure_backdrop: ColorRect = null
var _gb1_failure_return_button: Button = null
var _gb1_failure_returning := false


func _ready() -> void:
	# R1：父初始化开始之前完成资源预检；失败则父 _ready 完全不执行。
	_gb1_prepare_startup()
	if not _gb1_startup_ok:
		_gb1_block_startup()
		return

	# 父 _ready 仍是唯一初始化权威；实验 UI 只在它完成之后挂接。
	await super._ready()
	_gb1_help_panel = get_node_or_null(GB1_HELP_PANEL_PATH) as Control
	_gb1_restart_button = get_node_or_null(GB1_RESTART_BUTTON_PATH) as Button
	# Phase 27I-R0-R2 同款接法：用已有信号驱动左侧栏同步，不覆盖父 _process。
	if get_tree() != null and not get_tree().process_frame.is_connected(_sync_gb1_help_panel):
		get_tree().process_frame.connect(_sync_gb1_help_panel)
	_sync_gb1_help_panel()


## 启动被阻止时父 _ready 从未运行，父 _exit_tree 依赖的 battle / presenter / context 都还是默认值。
## 外部探针实测：当前 battle_scene._exit_tree 在这条路径上恰好没有报错，但那是父实现的偶然容忍，
## 本场景不应依赖它。这条路径从未进入父生命周期，也没有创建任何需要父类收尾的东西，因此直接返回。
func _exit_tree() -> void:
	if not _gb1_startup_ok:
		return
	super._exit_tree()


# ============================================================
# R1 / R2：父初始化之前的预检
# ============================================================
func _gb1_prepare_startup() -> void:
	var problems: Array[String] = []
	_gb1_load_problems = []
	_gb1_owned_cards = []
	_gb1_cards_by_id = _load_gb1_cards()
	problems.append_array(_gb1_load_problems)
	problems.append_array(_gb1_fixed_order_problems(_gb1_cards_by_id))

	var rules: Dictionary = _load_gb1_rule_snapshots(problems)
	_gb1_siege_snapshot = rules.get("siege", null)
	_gb1_repair_snapshot = rules.get("repair", null)
	_gb1_raise_snapshot = rules.get("raise", null)

	_gb1_startup_problems = problems
	_gb1_startup_ok = problems.is_empty()
	if not _gb1_startup_ok:
		_gb1_selected_cards = []
		_gb1_release_owned_cards()
		return

	_gb1_selected_cards = []
	for card_id in GB1_ORDER:
		_gb1_selected_cards.append(_gb1_cards_by_id[card_id])


## 默认 20 张表 + 两个实验包。覆写点：测试用局部子类可注入坏卡包。
func _load_gb1_packs() -> Array:
	var loader := GB1Catalog.new()
	var packs: Array = [
		loader.load_player_cards(),
		loader.load_player_pack(&"phase_f1"),
		loader.load_player_pack(&"phase_f2"),
	]
	loader.free()
	return packs


## 按 card_id 建索引；每张都是本次新生成的独立实例。
## 副作用：把本次加载创建的全部实例记入 _gb1_owned_cards；坏数据记入 _gb1_load_problems。
func _load_gb1_cards() -> Dictionary:
	var packs: Array = _load_gb1_packs()

	var by_id: Dictionary = {}
	for pack in packs:
		for card in pack:
			if card == null:
				_gb1_load_problems.append("card loader returned a null entry")
				continue
			_gb1_owned_cards.append(card)
			var card_id := str(card.card_id).strip_edges()
			if card_id.is_empty():
				_gb1_load_problems.append("card loader returned a card with an empty id")
				continue
			if by_id.has(card_id):
				# R2：不复用第一张，也不静默丢弃第二张；坏数据必须浮到统一失败结果。
				_gb1_load_problems.append("duplicate card id across loaded packs: %s" % card_id)
				continue
			by_id[card_id] = card
	return by_id


## 固定牌序自身的重复与必需 ID 缺失。
func _gb1_fixed_order_problems(by_id: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var seen: Dictionary = {}
	for card_id in GB1_ORDER:
		if seen.has(card_id):
			problems.append("duplicate card id in fixed order: %s" % card_id)
			continue
		seen[card_id] = true
		if not by_id.has(card_id):
			problems.append("required card id not loadable: %s" % card_id)
	return problems


## 必需规则：围城表读/解析/校验失败，或修复 / 升地快照无效或未启用，都算实验启动失败。
## 只缓存快照，不在父初始化里重新读一份数据。
func _load_gb1_rule_snapshots(problems: Array[String]) -> Dictionary:
	var out: Dictionary = {}

	var text := _read_gb1_siege_table_text()
	if text.strip_edges().is_empty():
		problems.append("siege rule table unreadable: %s" % GB1_SIEGE_RULES_PATH)
	else:
		# 用 JSON.parse() 而不是 JSON.parse_string()：后者在失败时会额外向控制台推一条 ERR_PRINT。
		var parser := JSON.new()
		if parser.parse(text) != OK:
			problems.append("siege rule table is not valid JSON: %s" % GB1_SIEGE_RULES_PATH)
		elif not parser.data is Dictionary:
			problems.append("siege rule table is not a JSON object: %s" % GB1_SIEGE_RULES_PATH)
		elif not (parser.data as Dictionary).get("enabled") is bool:
			problems.append("siege rule table has no bool 'enabled' field")
		else:
			var table: Dictionary = (parser.data as Dictionary).duplicate(true)
			table["enabled"] = true
			var siege: Variant = GameCfg.create_tactical_siege_rule_snapshot(false, table)
			# is_enabled() 只反映 enabled 字段，不反映 profiles 校验；used_fallback 才代表
			# 快照存在 validation_errors（即缺档 / 越界 / 未知字段）。
			if siege == null:
				problems.append("siege rule snapshot could not be built")
			elif not siege.is_enabled():
				problems.append("siege rule snapshot is not enabled; siege would stay disabled")
			elif bool(siege.get_snapshot().get("used_fallback", true)):
				problems.append("siege rule snapshot rejected the table: %s"
					% str(siege.get_snapshot().get("validation_errors", [])))
			else:
				out["siege"] = siege

	var repair: Variant = GB1RepairRules.from_table({
		"schema_version": 1,
		"enabled": true,
		"card_ids": ["P22"],
		"module_kinds": ["wall", "gatehouse"],
	})
	if repair == null or not repair.is_enabled() or not repair.is_card_supported(&"P22"):
		problems.append("repair rule snapshot invalid or not enabled")
	else:
		out["repair"] = repair

	var raise_rules: Variant = GB1RaiseRules.from_table({
		"schema_version": 1,
		"enabled": true,
		"card_ids": ["P23"],
	})
	if raise_rules == null or not raise_rules.is_enabled() or not raise_rules.is_card_supported(&"P23"):
		problems.append("terrain raise rule snapshot invalid or not enabled")
	else:
		out["raise"] = raise_rules

	return out


## 覆写点：测试用局部子类可返回损坏文本以验证规则表失败路径。
func _read_gb1_siege_table_text() -> String:
	return FileAccess.get_file_as_string(GB1_SIEGE_RULES_PATH)


## R2：释放本次加载拥有的全部 CardData。失败时全部释放；成功时未采用的实例在 _setup_deck 里释放。
func _gb1_release_owned_cards() -> void:
	for card in _gb1_owned_cards:
		if card != null and is_instance_valid(card):
			card.free()
	_gb1_owned_cards = []


# ============================================================
# 初始化接线（只在预检通过后被父 _ready 调用）
# ============================================================
func _get_gb1_boss_seed() -> int:
	return GB1_BOSS_SEED


func _setup_game() -> void:
	# 进度隔离与 Boss RNG 必须在父初始化真正建立 context / Boss deck 之前生效。
	set_meta("player_trial", true)
	_phase27h_seed = _get_gb1_boss_seed()
	super._setup_game()
	_apply_gb1_rule_switches()
	print("[GB-1] boss deck rng seed = %d" % boss_deck.get_rng_seed())


func _setup_deck() -> void:
	var container := Node.new()
	container.name = GB1_CARD_CONTAINER
	add_child(container)

	# R2：采用的实例挂入场景私有容器，其余本次拥有的实例立即释放；释放后清空所有权记录。
	var selected: Dictionary = {}
	for card in _gb1_selected_cards:
		selected[card.get_instance_id()] = true
	for card in _gb1_owned_cards:
		if card == null or not is_instance_valid(card):
			continue
		if selected.has(card.get_instance_id()):
			container.add_child(card)
		else:
			card.free()
	_gb1_owned_cards.clear()

	# 保留一次原 _setup_enemy_deck：备用伤害牌仍走原实现。
	_setup_enemy_deck()

	context.player.deck = _gb1_selected_cards.duplicate()
	print("[GB-1] fixed order deck ready: %d cards" % context.player.deck.size())


## E / F1 / F2 三个既有开关只在本子场景启用，不写回 JSON、不改全局 Registry。
## 快照已在预检阶段校验通过并缓存，此处只做应用。
func _apply_gb1_rule_switches() -> void:
	if battle == null:
		return
	battle.configure_tactical_siege_rules(_gb1_siege_snapshot)
	battle.configure_tactical_repair_rules(_gb1_repair_snapshot)
	battle.configure_tactical_terrain_raise_rules(_gb1_raise_snapshot)


# ============================================================
# R3：缺插画实验卡的基础可读性
# ============================================================
func _refresh_tables() -> void:
	super._refresh_tables()
	_gb1_apply_card_text_fallback()


## 只在实验入口给缺图卡挂一层只读文字。文字层 mouse_filter=IGNORE，
## 不改 CardUI 的输入、费用、目标判定或卡牌身份；已在的卡不重复叠加。
func _gb1_apply_card_text_fallback() -> void:
	if not is_inside_tree():
		return
	for node in find_children("*", "Control", true, false):
		if not node is CardUI:
			continue
		var ui := node as CardUI
		if ui.card_data == null:
			continue
		var text: String = GB1_CARD_TEXT_FALLBACK.get(str(ui.card_data.card_id), "")
		if text.is_empty():
			continue
		if ui.get_node_or_null(GB1_FALLBACK_LABEL) != null:
			continue
		var label := Label.new()
		label.name = GB1_FALLBACK_LABEL
		label.text = text
		label.position = Vector2(10.0, 44.0)
		label.size = Vector2(100.0, 112.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color("ffe08a"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(label)


# ============================================================
# R1：启动被阻止后的独立失败页
# ============================================================
func _gb1_block_startup() -> void:
	_gb1_stop_inherited_runtime()
	_gb1_hide_inherited_display()
	_gb1_build_failure_screen()
	print("GB1_STARTUP_BLOCKED: %s" % " | ".join(_gb1_startup_problems))


## 父初始化从未运行：停掉继承的处理 / 输入回调，避免它们读取尚未创建的战斗对象。
func _gb1_stop_inherited_runtime() -> void:
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)
	set_process_shortcut_input(false)


## 隐藏继承的战斗显示；本场景自己的失败页在这之后单独挂载。
func _gb1_hide_inherited_display() -> void:
	for child in get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		elif child is CanvasItem:
			(child as CanvasItem).visible = false
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gb1_build_failure_screen() -> void:
	var layer := CanvasLayer.new()
	layer.name = GB1_FAILURE_LAYER
	layer.layer = 100
	add_child(layer)
	_gb1_failure_layer = layer

	var backdrop := ColorRect.new()
	backdrop.name = GB1_FAILURE_BACKDROP
	backdrop.color = Color(0.03, 0.04, 0.06, 1.0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)
	_gb1_failure_backdrop = backdrop

	var body := VBoxContainer.new()
	body.name = "GB1FailureBody"
	body.offset_left = 120.0
	body.offset_top = 120.0
	body.offset_right = 780.0
	body.offset_bottom = 520.0
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 12)
	layer.add_child(body)

	body.add_child(_gb1_failure_label("GB1FailureTitle",
		"实验启动已阻止", 24, Color(0.98, 0.62, 0.58, 1.0)))
	body.add_child(_gb1_failure_label("GB1FailureDetail",
		"阵地对决 · 整合试玩的牌库或规则配置未通过校验，战斗没有启动。\n"
		+ "未创建战斗上下文、未开启回合、未抽牌、未写入任何进度。",
		14, Color(0.85, 0.88, 0.92, 1.0)))
	body.add_child(_gb1_failure_label("GB1FailureProblems",
		"\n".join(_gb1_startup_problems), 13, Color(0.96, 0.8, 0.5, 1.0)))

	var button := Button.new()
	button.name = GB1_FAILURE_RETURN_BUTTON
	button.text = "返回主菜单"
	button.custom_minimum_size = Vector2(160.0, 36.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(gb1_return_to_menu)
	body.add_child(button)
	_gb1_failure_return_button = button


func _gb1_failure_label(node_name: String, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## 失败页的返回入口。父初始化从未运行，这里不触碰父类的任何收尾逻辑。
func gb1_return_to_menu() -> void:
	if _gb1_failure_returning:
		return
	_gb1_failure_returning = true
	if _gb1_failure_return_button != null and is_instance_valid(_gb1_failure_return_button):
		_gb1_failure_return_button.disabled = true
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("change_scene"):
		gm.change_scene(GB1_MENU_PATH)
	else:
		print("[GB-1] GameManager missing; cannot return to menu")


# ============================================================
# 实验说明与重新挑战
# ============================================================
## 详情面板展开时让出位置：说明隐藏，按钮仍可用。
func _sync_gb1_help_panel() -> void:
	if _gb1_help_panel == null or not is_instance_valid(_gb1_help_panel):
		return
	var detail_expanded := bool(_detail_panel_expanded)
	var desired := not detail_expanded
	if _gb1_help_panel.visible != desired:
		_gb1_help_panel.visible = desired


## 只负责离开本场景并重新加载实验入口；不在旧 context 中清牌或重跑 setup。
func restart_gb1_battle() -> void:
	if _gb1_restarting:
		return
	_gb1_restarting = true
	if _gb1_restart_button != null and is_instance_valid(_gb1_restart_button):
		_gb1_restart_button.disabled = true
	get_tree().change_scene_to_file(GB1_ENTRY_PATH)
