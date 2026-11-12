extends CanvasLayer
## 首次游玩引导 + 卡牌一览。只在战斗场景显示，不修改任何战斗逻辑。

const BATTLE_HINT := "playtest/"
const CARD_JSON := "res://data/cards/player_cards_20.json"

## 三条展开链（步骤 1：先把数据结构定下来）
const CHAIN_DEFS := [
	{
		"name": "阵地链",
		"systems": "建筑",
		"desc": "把战线推到前场",
		"status": "playable",
		"cards": [
			{"id": "P02", "name": "燃芯使魔", "family": "monster"},
			{"id": "P05", "name": "炉基座", "family": "building"},
			{"id": "P08", "name": "铁誓烽堡", "family": "building"},
		],
		"final": "终场：三座建筑立在前场 + 1 个衍生学徒，正面压住 Boss 要害",
		"reward": "建筑三连",
		"extras": [
			{"id": "B04", "name": "蓄火", "family": "spell", "note": "分支：先补 2 热再展开"},
			{"id": "P13", "name": "热沉装置", "family": "building", "note": "分支：少建筑换冷却"},
		],
	},
	{
		"name": "过热链",
		"systems": "OD",
		"desc": "把热量推到 Overdrive",
		"status": "preview",
		"cards": [
			{"id": "B04", "name": "蓄火", "family": "spell"},
			{"id": "P01", "name": "预热仪式", "family": "spell"},
			{"id": "P02", "name": "燃芯使魔", "family": "monster"},
		],
		"final": "终场：热 ≥ 8 进入 Overdrive，伤害 ×1.5，终结牌窗口打开",
		"reward": "过热窗口",
		"extras": [
			{"id": "B05", "name": "降压", "family": "spell", "note": "分支：过热后立刻降压保命"},
		],
	},
	{
		"name": "锋线链",
		"systems": "棋子",
		"desc": "四个单位站成一排",
		"status": "preview",
		"cards": [
			{"id": "P02", "name": "燃芯使魔", "family": "monster"},
			{"id": "S01", "name": "锅炉学徒", "family": "monster"},
			{"id": "P07", "name": "热流导体", "family": "monster"},
		],
		"final": "终场：三个单位成排 + 衍生学徒，形成可连续进攻的推进面",
		"reward": "推进面",
		"extras": [
			{"id": "P10", "name": "连锁导体", "family": "monster", "note": "加塞：再补一个单位"},
			{"id": "B03", "name": "护卫", "family": "spell", "note": "分支：保主力不被反打"},
		],
	},
	{
		"name": "压制链",
		"systems": "Depth / 冷却",
		"desc": "把制动压回去，换出牌空间",
		"status": "preview",
		"cards": [
			{"id": "B04", "name": "蓄火", "family": "spell"},
			{"id": "P13", "name": "热沉装置", "family": "building"},
			{"id": "P11", "name": "冷却回路", "family": "spell"},
		],
		"final": "终场：Depth -3、下回合制动减免 1，等于多出一次行动",
		"reward": "行动空间",
		"extras": [
			{"id": "B05", "name": "降压", "family": "spell", "note": "分支：再压 2 点"},
		],
	},
]

const STEPS := [
	"A1|左边是你的手牌，中间是棋盘，右上角是你和 Boss 的状态。",
	"A2|第一回合只能部署，先不打。找一张「燃芯使魔」。",
	"A3|再放一张「炉基座」。两张凑齐，才能连续展开。",
	"A4|点左边「连续展开」，一次把学徒铺开。",
	"A5|看一眼三件事：生成什么、落在哪、一共多少费。",
	"A6|布局好了。点右下「部署完成」，进入交战。",
	"B1|第二回合：选一个能动的单位。",
	"B2|选一个要害。先打护臂，2 点耐久。",
	"B3|有多条路线时选一条，然后点执行。",
	"B4|受伤了用维护：拿「燃芯使魔」或「炉基座」当素材，能修 2 点。",
	"C1|护臂和阀门都破掉，核心才会露出来。",
	"C2|核心 4 点耐久，破了对本体 12 伤。现在可以打本体了。",
]

var _panel: PanelContainer
var _text: Label
var _index_label: Label
var _card_layer: Control
var _card_grid: GridContainer
var _toggle: Button
var _step := 0
var _cards_loaded := false
var _last_scene := ""
var _tick := 0.0


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_toggle()
	_build_panel()
	_build_card_panel()
	_apply_visibility(false)
	if OS.get_cmdline_user_args().has("--open-chains"):
		_apply_visibility(true)
		_open_chains()
	if OS.get_cmdline_user_args().has("--arm-demo"):
		_apply_visibility(true)
		_arm_chain.call_deferred(0)
	if OS.get_cmdline_user_args().has("--pin-demo"):
		_apply_visibility(true)
		_start_pin.call_deferred(0)
		_demo_pin.call_deferred()


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.4:
		return
	_tick = 0.0
	var cs := get_tree().current_scene
	var p := "" if cs == null else cs.scene_file_path
	if p == _last_scene:
		return
	_last_scene = p
	_apply_visibility(p.find(BATTLE_HINT) >= 0)


func _apply_visibility(show_it: bool) -> void:
	var bar = _toggle.get_meta("bar", null) if _toggle else null
	if bar != null:
		bar.visible = show_it
	if not show_it:
		if _panel: _panel.visible = false
		if _card_layer: _card_layer.visible = false


# ---------------- 引导面板 ----------------
func _build_toggle() -> void:
	var bar := HBoxContainer.new()
	bar.name = "GuideBar"
	bar.position = Vector2(12, 452)
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)

	_toggle = Button.new()
	_toggle.name = "GuideToggle"
	_toggle.text = "引导"
	_toggle.custom_minimum_size = Vector2(60, 28)
	_toggle.add_theme_font_size_override("font_size", 13)
	_toggle.pressed.connect(func(): _panel.visible = not _panel.visible)
	bar.add_child(_toggle)

	var chain_btn := Button.new()
	chain_btn.name = "ChainBook"
	chain_btn.text = "展开链"
	chain_btn.custom_minimum_size = Vector2(70, 28)
	chain_btn.add_theme_font_size_override("font_size", 13)
	chain_btn.pressed.connect(_open_chains)
	bar.add_child(chain_btn)

	var cards_btn := Button.new()
	cards_btn.name = "CardBook"
	cards_btn.text = "卡牌"
	cards_btn.custom_minimum_size = Vector2(60, 28)
	cards_btn.add_theme_font_size_override("font_size", 13)
	cards_btn.pressed.connect(_open_cards)
	bar.add_child(cards_btn)

	_toggle.set_meta("bar", bar)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "GuidePanel"
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(12, 492)
	_panel.custom_minimum_size = Vector2(360, 0)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_panel.add_child(vb)

	_index_label = Label.new()
	_index_label.add_theme_font_size_override("font_size", 13)
	_index_label.modulate = Color(1, 1, 1, 0.7)
	vb.add_child(_index_label)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(336, 0)
	_text.add_theme_font_size_override("font_size", 16)
	vb.add_child(_text)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)

	var prev := Button.new()
	prev.text = "上一步"
	prev.custom_minimum_size = Vector2(0, 30)
	prev.add_theme_font_size_override("font_size", 13)
	prev.pressed.connect(func(): _go(-1))
	hb.add_child(prev)

	var nxt := Button.new()
	nxt.text = "下一步"
	nxt.custom_minimum_size = Vector2(0, 30)
	nxt.add_theme_font_size_override("font_size", 13)
	nxt.pressed.connect(func(): _go(1))
	hb.add_child(nxt)

	var skip := Button.new()
	skip.text = "跳过"
	skip.custom_minimum_size = Vector2(0, 30)
	skip.add_theme_font_size_override("font_size", 13)
	skip.pressed.connect(func(): _panel.visible = false)
	hb.add_child(skip)

	_refresh()


func _go(step: int) -> void:
	_step = clampi(_step + step, 0, STEPS.size() - 1)
	_refresh()


func _refresh() -> void:
	var parts: PackedStringArray = String(STEPS[_step]).split("|", true, 2)
	_index_label.text = "%d / %d　%s" % [_step + 1, STEPS.size(), parts[0]]
	_text.text = parts[1] if parts.size() > 1 else ""


# ---------------- 卡牌一览 ----------------
func _build_card_panel() -> void:
	_card_layer = Control.new()
	_card_layer.name = "CardLayer"
	_card_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_layer.visible = false
	add_child(_card_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_layer.add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(1180, 700)
	center.add_child(frame)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	frame.add_child(vb)

	var head := HBoxContainer.new()
	vb.add_child(head)

	var title := Label.new()
	title.text = "卡牌一览　·　共 20 张"
	title.add_theme_font_size_override("font_size", 20)
	head.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)

	var close := Button.new()
	close.text = "关闭"
	close.custom_minimum_size = Vector2(90, 34)
	head.add_child(close)
	close.pressed.connect(func(): _card_layer.visible = false)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	_card_grid = GridContainer.new()
	_card_grid.columns = 4
	_card_grid.add_theme_constant_override("h_separation", 8)
	_card_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_card_grid)


func _open_cards() -> void:
	if not _cards_loaded:
		_load_cards()
	_card_layer.visible = true


func _load_cards() -> void:
	_cards_loaded = true
	var f := FileAccess.open(CARD_JSON, FileAccess.READ)
	if f == null:
		_add_card_tile("读取失败", "", "找不到卡牌数据文件", "")
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("cards"):
		_add_card_tile("读取失败", "", "卡牌数据格式不对", "")
		return
	for c in data["cards"]:
		var name_txt := str(c.get("cn_name", c.get("id", "?")))
		var cost := str(c.get("load_cost", "?"))
		var req := int(c.get("require_od", 0))
		var desc := str(c.get("short_description_cn", ""))
		var typ := str(c.get("card_type", ""))
		_add_card_tile(name_txt, cost, desc, typ if req <= 0 else "需 OD %d" % req)


func _add_card_tile(title: String, cost: String, desc: String, tail: String) -> void:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(276, 128)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	box.add_child(vb)

	var head := Label.new()
	head.text = "%s　·　费 %s" % [title, cost] if cost != "" else title
	head.add_theme_font_size_override("font_size", 15)
	vb.add_child(head)

	var d := Label.new()
	d.text = desc
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(256, 0)
	d.add_theme_font_size_override("font_size", 12)
	vb.add_child(d)

	if tail != "":
		var t := Label.new()
		t.text = tail
		t.add_theme_font_size_override("font_size", 11)
		t.modulate = Color(1, 1, 1, 0.6)
		vb.add_child(t)

	_card_grid.add_child(box)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			if _toggle.visible:
				_open_cards()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _card_layer.visible:
			_card_layer.visible = false
			get_viewport().set_input_as_handled()


# ---------------- 展开链面板（步骤 1） ----------------
var _chain_layer: Control


func _open_chains() -> void:
	if _chain_layer == null:
		_build_chain_layer()
	_refresh_chains()
	_chain_layer.visible = true


func _build_chain_layer() -> void:
	_chain_layer = Control.new()
	_chain_layer.name = "ChainLayer"
	_chain_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chain_layer.visible = false
	add_child(_chain_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chain_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chain_layer.add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(900, 780)
	center.add_child(frame)

	var vb := VBoxContainer.new()
	vb.name = "ChainRoot"
	vb.add_theme_constant_override("separation", 10)
	frame.add_child(vb)

	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := Label.new()
	title.text = "展开链　·　%d 条路线" % CHAIN_DEFS.size()
	title.add_theme_font_size_override("font_size", 20)
	head.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var close := Button.new()
	close.text = "关闭"
	close.custom_minimum_size = Vector2(90, 34)
	close.pressed.connect(func(): _chain_layer.visible = false)
	head.add_child(close)

	var note := Label.new()
	note.text = "按键位顺序钉位；缺牌时整条链不可用。点「关闭」返回战斗。"
	note.add_theme_font_size_override("font_size", 12)
	note.modulate = Color(1, 1, 1, 0.55)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(note)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "ChainBody"
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)


func _refresh_chains() -> void:
	var body := _chain_layer.find_child("ChainBody", true, false)
	if body == null:
		return
	for child in body.get_children():
		if child is PanelContainer:
			child.queue_free()
	var hand_ids := _hand_ids()
	for chain in CHAIN_DEFS:
		var row_box := _chain_row(chain, hand_ids)
		var idx: int = CHAIN_DEFS.find(chain)
		row_box.gui_input.connect(_on_chain_row_input.bind(idx))
		body.add_child(row_box)


func _chain_row(chain: Dictionary, hand_ids: Array) -> PanelContainer:
	var box := PanelContainer.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	box.add_child(vb)

	var have := 0
	var parts: Array = []
	for c in chain["cards"]:
		var ok: bool = hand_ids.has(c["id"])
		if ok:
			have += 1
		parts.append(("● " if ok else "○ ") + c["name"])
	var ready: bool = have == chain["cards"].size()

	var top := HBoxContainer.new()
	vb.add_child(top)
	var name_label := Label.new()
	name_label.text = chain["name"] + "　·　" + str(chain.get("systems", ""))
	name_label.add_theme_font_size_override("font_size", 17)
	top.add_child(name_label)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	var state := Label.new()
	if hand_ids.is_empty():
		state.text = "—"
	else:
		state.text = "缺 %d 张" % (chain["cards"].size() - have) if not ready else ("已接入结算" if str(chain.get("status", "")) == "playable" else "路线预览")
	state.add_theme_font_size_override("font_size", 13)
	state.modulate = Color(0.45, 0.9, 0.6, 1) if ready else Color(1, 1, 1, 0.45)
	top.add_child(state)

	var flow := HBoxContainer.new()
	flow.add_theme_constant_override("separation", 5)
	vb.add_child(flow)
	for i in range(chain["cards"].size()):
		if i > 0:
			var arrow := Label.new()
			arrow.text = "→"
			arrow.modulate = Color(1, 1, 1, 0.35)
			arrow.add_theme_font_size_override("font_size", 15)
			flow.add_child(arrow)
		var member = chain["cards"][i]
		flow.add_child(_chain_chip(str(member["name"]), str(member.get("family", "spell")), hand_ids.has(member["id"])))
	var tail := Label.new()
	tail.text = "　" + str(chain["reward"])
	tail.add_theme_font_size_override("font_size", 12)
	tail.modulate = Color(1, 1, 1, 0.45)
	flow.add_child(tail)

	if chain.has("extras") and not chain["extras"].is_empty():
		var alt := HBoxContainer.new()
		alt.add_theme_constant_override("separation", 6)
		vb.add_child(alt)
		var tag := Label.new()
		tag.text = "可选 / 分支"
		tag.add_theme_font_size_override("font_size", 11)
		tag.modulate = Color(1, 1, 1, 0.4)
		alt.add_child(tag)
		for ex in chain["extras"]:
			var owned: bool = hand_ids.has(ex["id"])
			var chip := _chain_chip(str(ex["name"]), str(ex.get("family", "spell")), owned)
			chip.modulate = Color(1, 1, 1, 0.55)
			if owned:
				chip.mouse_filter = Control.MOUSE_FILTER_STOP
				chip.gui_input.connect(_toggle_extra.bind(str(ex["id"]), chip))
			alt.add_child(chip)
			var note := Label.new()
			note.text = str(ex.get("note", ""))
			note.add_theme_font_size_override("font_size", 10)
			note.modulate = Color(1, 1, 1, 0.32)
			alt.add_child(note)

	var fin := Label.new()
	fin.text = str(chain.get("final", ""))
	fin.add_theme_font_size_override("font_size", 12)
	fin.modulate = Color(0.75, 0.95, 0.95, 0.85)
	fin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(fin)

	var hint := Label.new()
	hint.text = chain["desc"]
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.45)
	vb.add_child(hint)
	return box


func _hand_ids() -> Array:
	var ids: Array = []
	var root := get_tree().current_scene
	if root == null:
		return ids
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		var parent := n.get_parent()
		if parent != null and str(parent.name).begins_with("BattleHand"):
			var data = n.get("card_data")
			if data != null:
				ids.append(str(data.card_id))
		for c in n.get_children():
			stack.append(c)
	return ids


func _find_context(n: Node):
	if n == null:
		return null
	if n.get("battle") != null:
		return n.get("context")
	for c in n.get_children():
		var r = _find_context(c)
		if r != null:
			return r
	return null


const CHIP_COLORS := {
	"spell": Color(0.29, 0.50, 0.77),
	"monster": Color(0.78, 0.46, 0.24),
	"building": Color(0.34, 0.57, 0.39),
}


func _chain_chip(text: String, family: String, owned: bool) -> PanelContainer:
	var box := PanelContainer.new()
	var col: Color = CHIP_COLORS.get(family, Color(0.5, 0.5, 0.5))
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.62) if owned else Color(0.12, 0.13, 0.15, 1.0)
	sb.border_color = col if owned else Color(0.42, 0.45, 0.48, 1.0)
	sb.border_width_left = 4
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var g = preload("res://ui/card_type_glyph.gd").new()
	g.custom_minimum_size = Vector2(13, 13)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(g)
	g.setup(family, col)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.modulate = Color(1, 1, 1, 1) if owned else Color(1, 1, 1, 0.42)
	row.add_child(l)
	return box


# ---------------- 钉位（步骤 2） ----------------
var _pin_layer: Control
var _pin_chain: Dictionary = {}
var _pin_slots: Array = []
var _pin_buttons: Dictionary = {}
var _pin_status: Label
var _picked_extras: Array = []
var _armed_chain: Dictionary = {}
var _opening_pending: Array = []
var _opening_missing: Array = []
var _tracker: Control
var _tracker_status: Label
var _tracker_chips: Dictionary = {}
var _poll_timer: Timer
var _pin_confirm: Button


func _on_chain_row_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_arm_chain(idx)


func _find_battle_node(n: Node):
	if n == null:
		return null
	if n.has_method("_project_tactical_cell_to_screen"):
		return n
	for c in n.get_children():
		var r = _find_battle_node(c)
		if r != null:
			return r
	return null


func _start_pin(idx: int) -> void:
	_pin_chain = CHAIN_DEFS[idx]
	_picked_extras.clear()
	_pin_slots = []
	for i in range(_pin_chain["cards"].size()):
		_pin_slots.append(null)
	if _pin_layer == null:
		_build_pin_layer()
	if _chain_layer != null:
		_chain_layer.visible = false
	_pin_layer.visible = true
	_rebuild_pin_buttons()
	_update_pin_status()


func _build_pin_layer() -> void:
	_pin_layer = Control.new()
	_pin_layer.name = "PinLayer"
	_pin_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pin_layer.visible = false
	add_child(_pin_layer)

	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 260
	bar.offset_right = -320
	bar.offset_top = 8
	bar.offset_bottom = 56
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.10, 0.94)
	sb.border_color = Color(0.55, 0.75, 0.72, 0.8)
	sb.border_width_left = 3
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("panel", sb)
	_pin_layer.add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)

	_pin_status = Label.new()
	_pin_status.add_theme_font_size_override("font_size", 14)
	_pin_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_pin_status)

	var undo := Button.new()
	undo.text = "撤销上一步"
	undo.custom_minimum_size = Vector2(100, 30)
	undo.pressed.connect(_pin_undo)
	row.add_child(undo)

	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(70, 30)
	cancel.pressed.connect(_cancel_pin)
	row.add_child(cancel)

	_pin_confirm = Button.new()
	_pin_confirm.text = "确认钉位"
	_pin_confirm.custom_minimum_size = Vector2(100, 30)
	_pin_confirm.pressed.connect(_confirm_pin)
	row.add_child(_pin_confirm)


func _rebuild_pin_buttons() -> void:
	for b in _pin_buttons.values():
		if is_instance_valid(b):
			b.queue_free()
	_pin_buttons.clear()
	var bn = _find_battle_node(get_tree().current_scene)
	if bn == null:
		return
	for y in range(5):
		for x in range(5):
			var cell := Vector2i(x, y)
			var pos: Vector2 = bn._project_tactical_cell_to_screen(cell)
			if pos == Vector2.INF:
				continue
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(30, 30)
			dot.size = Vector2(30, 30)
			dot.position = pos - Vector2(15, 15)
			dot.mouse_filter = Control.MOUSE_FILTER_STOP
			var dsb := StyleBoxFlat.new()
			dsb.bg_color = Color(0.06, 0.12, 0.14, 0.62)
			dsb.border_color = Color(0.55, 0.85, 0.80, 0.85)
			dsb.border_width_left = 2
			dsb.border_width_right = 2
			dsb.border_width_top = 2
			dsb.border_width_bottom = 2
			dsb.set_corner_radius_all(15)
			dot.add_theme_stylebox_override("panel", dsb)
			dot.gui_input.connect(_pin_cell_input.bind(cell))
			var lab := Label.new()
			lab.name = "Step"
			lab.set_anchors_preset(Control.PRESET_FULL_RECT)
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lab.add_theme_font_size_override("font_size", 15)
			dot.add_child(lab)
			_pin_layer.add_child(dot)
			_pin_buttons[cell] = dot
	_refresh_pin_buttons()


func _pin_cell_input(event: InputEvent, cell: Vector2i) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pin_cell(cell)


func _refresh_pin_buttons() -> void:
	for cell in _pin_buttons.keys():
		var dot: Panel = _pin_buttons[cell]
		if not is_instance_valid(dot):
			continue
		var step := _pin_slots.find(cell)
		var lab := dot.get_node_or_null("Step") as Label
		if lab != null:
			lab.text = str(step + 1) if step >= 0 else ""
		dot.modulate = Color(0.6, 1.0, 0.85, 1.0) if step >= 0 else Color(1, 1, 1, 0.30)


func _pin_cell(cell: Vector2i) -> void:
	var existing := _pin_slots.find(cell)
	if existing >= 0:
		_pin_slots[existing] = null
	else:
		var empty := _pin_slots.find(null)
		if empty >= 0:
			_pin_slots[empty] = cell
	_refresh_pin_buttons()
	_update_pin_status()


func _pin_undo() -> void:
	for i in range(_pin_slots.size() - 1, -1, -1):
		if _pin_slots[i] != null:
			_pin_slots[i] = null
			break
	_refresh_pin_buttons()
	_update_pin_status()


func _update_pin_status() -> void:
	var next := _pin_slots.find(null)
	var total: int = _pin_slots.size()
	if next < 0:
		_pin_status.text = "钉位完成：%s　·　点「确认钉位」" % _pin_chain["name"]
		_pin_confirm.disabled = false
	else:
		var card = _pin_chain["cards"][next]
		_pin_status.text = "%s　第 %d/%d 步：在棋盘上点一个格子放「%s」　·　热 %d/%d" % [
			_pin_chain["name"], next + 1, total, card["name"], _current_heat(), INTERRUPT_HEAT]
		_pin_confirm.disabled = true


func _cancel_pin() -> void:
	_pin_layer.visible = false
	for b in _pin_buttons.values():
		if is_instance_valid(b):
			b.queue_free()
	_pin_buttons.clear()


func _confirm_pin() -> void:
	_pin_confirm.disabled = true
	if str(_pin_chain.get("status", "")) != "playable":
		await _run_free_chain()
		return
	var heat := _current_heat()
	if heat >= INTERRUPT_HEAT:
		_pin_status.text = "链在第 2 步被打断　·　热 %d/%d 已超阈值，后续步骤失效" % [heat, INTERRUPT_HEAT]
		_pin_confirm.disabled = false
		return
	await _play_pin_sequence()
	var bn = _find_battle_node(get_tree().current_scene)
	if bn == null:
		_pin_status.text = "找不到战斗节点"
		_pin_confirm.disabled = false
		return
	var battle = bn.get("battle")
	if battle == null:
		_pin_status.text = "找不到战斗系统"
		_pin_confirm.disabled = false
		return
	var anchor = _pin_slots[0]
	if anchor == null:
		_pin_status.text = "先钉第 1 步"
		_pin_confirm.disabled = false
		return
	var last := ""
	for dir in ["arm", "valve"]:
		var q: Dictionary = battle.recipe166_preview(dir, anchor)
		if q.get("ok", false):
			var r: Dictionary = battle.recipe166_commit(q)
			if r.get("ok", false):
				_pin_status.text = "阵地链 已结算　·　热 %d→%d　·　盾 +%d　·　指令 -%d" % [
					int(q.get("heat_before", 0)), int(q.get("heat_after", 0)),
					int(q.get("shield_gain", 0)), int(q.get("command_cost", 0))]
				var picked := _picked_extra_list()
				var extras_played: Array = []
				if not picked.is_empty():
					extras_played = await _play_extras(picked, battle, bn, anchor)
				_settle_chain(_pin_chain["cards"].size(), _pin_chain["cards"].size(), extras_played)
				_clear_pins()
				return
			last = str(r.get("reason", "结算失败"))
		else:
			last = str(q.get("reason", "落点不可用"))
	_pin_status.text = "无法展开：" + last
	_pin_confirm.disabled = false


func _clear_pins() -> void:
	for i in range(_pin_slots.size()):
		_pin_slots[i] = null
	_refresh_pin_buttons()
	_pin_confirm.disabled = true


func _play_pin_sequence() -> void:
	var total: int = _pin_slots.size()
	var chain_name := str(_pin_chain["name"])
	var bn = _find_battle_node(get_tree().current_scene)
	for i in range(total):
		var cell = _pin_slots[i]
		if cell == null:
			continue
		var member: Dictionary = _pin_chain["cards"][i]
		_pin_status.text = "%s　·　%d/%d　「%s」打出" % [chain_name, i + 1, total, member["name"]]
		await _fly_card(str(member["id"]), str(member.get("family", "spell")), str(member["name"]), cell, bn)
	_pin_status.text = "%s　·　链条完成，正在结算…" % chain_name
	await get_tree().create_timer(0.2).timeout


func _hand_card_node(card_id: String) -> Control:
	var root := get_tree().current_scene
	if root == null:
		return null
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		var parent := n.get_parent()
		if parent != null and str(parent.name).begins_with("BattleHand"):
			var data = n.get("card_data")
			if data != null and str(data.card_id) == card_id:
				return n as Control
		for c in n.get_children():
			stack.append(c)
	return null


func _fly_card(card_id: String, family: String, card_name: String, cell: Vector2i, bn) -> void:
	var to := Vector2(800, 620)
	if bn != null:
		var projected: Vector2 = bn._project_tactical_cell_to_screen(cell)
		if projected != Vector2.INF:
			to = projected
	var from := Vector2(800, 790)
	var src := _hand_card_node(card_id)
	if src != null:
		var r := src.get_global_rect()
		from = r.position + r.size * 0.5
		src.modulate = Color(1, 1, 1, 0.30)

	var proxy := Panel.new()
	proxy.size = Vector2(124, 158)
	proxy.position = from - proxy.size * 0.5
	proxy.pivot_offset = proxy.size * 0.5
	proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = CHIP_COLORS.get(family, Color(0.5, 0.5, 0.5))
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.55)
	sb.border_color = col.lightened(0.25)
	sb.border_width_left = 5
	sb.border_width_right = 3
	sb.border_width_top = 4
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(10)
	sb.shadow_size = 8
	sb.shadow_color = Color(col.r, col.g, col.b, 0.5)
	proxy.add_theme_stylebox_override("panel", sb)
	var lab := Label.new()
	lab.text = card_name
	lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_size_override("font_size", 16)
	proxy.add_child(lab)
	_pin_layer.add_child(proxy)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(proxy, "position", to - proxy.size * 0.5, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(proxy, "scale", Vector2(0.6, 0.6), 0.36)
	tw.tween_property(proxy, "rotation", 0.16, 0.36)
	await tw.finished

	var ring := Panel.new()
	ring.size = Vector2(44, 44)
	ring.position = to - Vector2(22, 22)
	ring.pivot_offset = Vector2(22, 22)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(col.r, col.g, col.b, 0.18)
	rsb.border_color = col.lightened(0.35)
	rsb.border_width_left = 3
	rsb.border_width_right = 3
	rsb.border_width_top = 3
	rsb.border_width_bottom = 3
	rsb.set_corner_radius_all(22)
	ring.add_theme_stylebox_override("panel", rsb)
	_pin_layer.add_child(ring)
	var rt := create_tween()
	rt.set_parallel(true)
	rt.tween_property(ring, "scale", Vector2(2.2, 2.2), 0.28)
	rt.tween_property(ring, "modulate", Color(1, 1, 1, 0), 0.28)
	await rt.finished
	ring.queue_free()
	proxy.queue_free()
	if src != null:
		src.modulate = Color(1, 1, 1, 1)


func _demo_pin() -> void:
	await get_tree().create_timer(0.4).timeout
	if OS.get_cmdline_user_args().has("--demo-free"):
		_start_pin(1)
	await get_tree().create_timer(0.6).timeout
	_pin_slots = [Vector2i(2, 3), Vector2i(3, 3), Vector2i(2, 4)]
	_refresh_pin_buttons()
	_update_pin_status()
	if OS.get_cmdline_user_args().has("--demo-extra"):
		_picked_extras.append("B04")
	if OS.get_cmdline_user_args().has("--force-heat"):
		var bn = _find_battle_node(get_tree().current_scene)
		if bn != null:
			var ctx = bn.get("context")
			if ctx != null and ctx.get("od_mode") != null:
				ctx.get("od_mode").set("current_od", 9)
	await get_tree().create_timer(0.8).timeout
	_confirm_pin()


const INTERRUPT_HEAT := 8


func _current_heat() -> int:
	var bn = _find_battle_node(get_tree().current_scene)
	if bn == null:
		return 0
	var ctx = bn.get("context")
	if ctx == null:
		return 0
	var od = ctx.get("od_mode")
	if od == null:
		return 0
	return int(od.get("current_od"))


func _hand_card_data(battle, card_id: String):
	var bn = _find_battle_node(get_tree().current_scene)
	if bn == null:
		return null
	var ctx = bn.get("context")
	if ctx == null:
		return null
	var player = ctx.get("player")
	if player == null:
		return null
	var hand = player.get("hand")
	if hand == null:
		return null
	for c in hand:
		if c != null and str(c.card_id) == card_id:
			return c
	return null


func _run_free_chain() -> void:
	var bn = _find_battle_node(get_tree().current_scene)
	if bn == null:
		_pin_status.text = "找不到战斗节点"
		_pin_confirm.disabled = false
		return
	var battle = bn.get("battle")
	if battle == null:
		_pin_status.text = "找不到战斗系统"
		_pin_confirm.disabled = false
		return
	var chain_name := str(_pin_chain["name"])
	var total: int = _pin_chain["cards"].size()
	var done := 0
	for i in range(total):
		var member: Dictionary = _pin_chain["cards"][i]
		var cell = _pin_slots[i]
		_pin_status.text = "%s　·　%d/%d　「%s」打出　·　热 %d/%d" % [
			chain_name, i + 1, total, member["name"], _current_heat(), INTERRUPT_HEAT]
		await _fly_card(str(member["id"]), str(member.get("family", "spell")), str(member["name"]), cell, bn)
		var card = _hand_card_data(battle, str(member["id"]))
		if card == null:
			_pin_status.text = "第 %d 步失败：手牌里没有「%s」" % [i + 1, member["name"]]
			break
		var target := Vector2i(-1, -1)
		if cell != null:
			target = cell
		var r: Dictionary = battle.play_card(card, -1, target)
		if not bool(r.get("ok", false)):
			_pin_status.text = "第 %d 步失败：%s" % [i + 1, str(r.get("reason", "条件不足"))]
			break
		done += 1
		if i == 1:
			var h := _current_heat()
			if h >= INTERRUPT_HEAT:
				_pin_status.text = "链在第 %d 步被打断　·　热 %d/%d 已超阈值，后续步骤失效" % [i + 1, h, INTERRUPT_HEAT]
				break
	if done >= total:
		var picked := _picked_extra_list()
		var extras_played: Array = []
		if not picked.is_empty():
			var base_cell = null
			for c in _pin_slots:
				if c != null:
					base_cell = c
					break
			extras_played = await _play_extras(picked, battle, bn, base_cell)
		_settle_chain(done, total, extras_played)
	_clear_pins()
	_pin_confirm.disabled = true


func _toggle_extra(event: InputEvent, extra_id: String, chip: Control) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _picked_extras.has(extra_id):
		_picked_extras.erase(extra_id)
		chip.modulate = Color(1, 1, 1, 0.55)
	else:
		_picked_extras.append(extra_id)
		chip.modulate = Color(1.25, 1.25, 1.25, 1.0)


func _picked_extra_list() -> Array:
	var out: Array = []
	for ex in _pin_chain.get("extras", []):
		if _picked_extras.has(str(ex["id"])):
			out.append(ex)
	return out


func _play_extras(extras: Array, battle, bn, base_cell) -> Array:
	var done: Array = []
	for ex in extras:
		var cell = base_cell
		_pin_status.text = "%s　·　分支「%s」打出" % [str(_pin_chain["name"]), str(ex["name"])]
		await _fly_card(str(ex["id"]), str(ex.get("family", "spell")), str(ex["name"]), cell, bn)
		var card = _hand_card_data(battle, str(ex["id"]))
		if card == null:
			_pin_status.text = "分支失败：手牌里没有「%s」" % str(ex["name"])
			break
		var target := Vector2i(-1, -1)
		if cell != null:
			target = cell
		var r: Dictionary = battle.play_card(card, -1, target)
		if not bool(r.get("ok", false)):
			_pin_status.text = "分支「%s」失败：%s" % [str(ex["name"]), str(r.get("reason", "条件不足"))]
			break
		done.append(str(ex["id"]))
	return done


# ---------------- 终场结算 ----------------
const BRANCH_EFFECTS := {
	"B04": {"heat": 2, "label": "热 +2 结转"},
	"B05": {"heat": -2, "label": "热 -2"},
	"P13": {"depth": -1, "label": "Depth -1"},
	"P11": {"depth": -1, "label": "Depth -1"},
	"B03": {"shield": 2, "label": "护盾 +2"},
	"P10": {"shield": 1, "label": "护盾 +1"},
	"E02": {"command": 1, "label": "指令 +1"},
}


func _settle_chain(done: int, total: int, played_ids: Array) -> void:
	var bn = _find_battle_node(get_tree().current_scene)
	if bn == null:
		return
	var ctx = bn.get("context")
	if ctx == null:
		return
	var player = ctx.get("player")
	if player == null:
		return
	var parts: Array = []
	if done >= total and total > 0:
		player.set("shield", int(player.get("shield")) + 1)
		parts.append("链完整 · 护盾 +1")
		var battle = bn.get("battle")
		if battle != null and battle.has_method("_economy_for_side"):
			var econ = battle._economy_for_side("player")
			if econ != null:
				econ.current_points += 1
				parts.append("指令 +1")
	else:
		parts.append("链中断 · 无终场奖励")

	for id in played_ids:
		var eff: Dictionary = BRANCH_EFFECTS.get(str(id), {})
		if eff.is_empty():
			player.set("shield", int(player.get("shield")) + 1)
			parts.append("分支 · 护盾 +1")
			continue
		if eff.has("heat"):
			var od = ctx.get("od_mode")
			if od != null:
				var cur := int(od.get("current_od"))
				var cap := int(od.get("max_value"))
				od.set("current_od", clampi(cur + int(eff["heat"]), 0, cap))
		if eff.has("depth"):
			var d := int(ctx.get("depth_pressure"))
			ctx.set("depth_pressure", maxi(0, d + int(eff["depth"])))
		if eff.has("shield"):
			player.set("shield", int(player.get("shield")) + int(eff["shield"]))
		if eff.has("command"):
			var battle2 = bn.get("battle")
			if battle2 != null and battle2.has_method("_economy_for_side"):
				var econ2 = battle2._economy_for_side("player")
				if econ2 != null:
					econ2.current_points += int(eff["command"])
		parts.append("分支 · " + str(eff["label"]))

	_pin_status.text = "%s　·　%s" % [str(_pin_chain["name"]), "　·　".join(parts)]


# ---------------- 手动起手 + 自动收尾 ----------------
func _arm_chain(idx: int) -> void:
	_armed_chain = CHAIN_DEFS[idx]
	_opening_pending.clear()
	var hand_now := _hand_ids()
	_opening_missing.clear()
	for c in _armed_chain["cards"]:
		if hand_now.has(str(c["id"])):
			_opening_pending.append(str(c["id"]))
		else:
			_opening_missing.append(str(c["id"]))
	_picked_extras.clear()
	if _chain_layer != null:
		_chain_layer.visible = false
	if _pin_layer != null:
		_pin_layer.visible = false
	_build_tracker()
	_tracker.visible = true
	_refresh_tracker()
	if _poll_timer != null:
		_poll_timer.queue_free()
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.4
	_poll_timer.timeout.connect(_poll_opening)
	add_child(_poll_timer)
	_poll_timer.start()


func _build_tracker() -> void:
	if _tracker != null:
		for c in _tracker.get_children():
			c.queue_free()
	else:
		_tracker = Control.new()
		_tracker.name = "ChainTracker"
		_tracker.set_anchors_preset(Control.PRESET_FULL_RECT)
		_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tracker)

	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 300
	bar.offset_right = -300
	bar.offset_top = -252
	bar.offset_bottom = -206
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.10, 0.94)
	sb.border_color = Color(0.55, 0.85, 0.78, 0.85)
	sb.border_width_left = 3
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("panel", sb)
	_tracker.add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(row)

	var title := Label.new()
	title.text = str(_armed_chain["name"])
	if not _opening_missing.is_empty():
		title.text += "（缺 %d 张）" % _opening_missing.size()
	title.add_theme_font_size_override("font_size", 14)
	row.add_child(title)

	_tracker_chips.clear()
	for c in _armed_chain["cards"]:
		var cid := str(c["id"])
		var has_it: bool = not _opening_missing.has(cid)
		var label := ("○ " if has_it else "✕ 缺 ") + str(c["name"])
		var chip := _chain_chip(label, str(c.get("family", "spell")), false)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not has_it:
			chip.modulate = Color(1, 1, 1, 0.35)
		row.add_child(chip)
		_tracker_chips[cid] = chip

	_tracker_status = Label.new()
	_tracker_status.text = "自己打出 %d 张 → 自动展开" % _opening_pending.size()
	_tracker_status.add_theme_font_size_override("font_size", 12)
	_tracker_status.modulate = Color(1, 1, 1, 0.6)
	row.add_child(_tracker_status)


func _refresh_tracker() -> void:
	for c in _armed_chain["cards"]:
		var id := str(c["id"])
		var chip = _tracker_chips.get(id)
		if chip == null:
			continue
		var done: bool = not _opening_pending.has(id)
		var lab := chip.get_child(0).get_child(1) as Label
		if lab != null:
			lab.text = ("● " if done else "○ ") + str(c["name"])
		chip.modulate = Color(0.6, 1.0, 0.8, 1.0) if done else Color(1, 1, 1, 0.55)


func _poll_opening() -> void:
	if _armed_chain.is_empty():
		return
	var hand := _hand_ids()
	for id in _opening_pending.duplicate():
		if not hand.has(str(id)):
			_opening_pending.erase(id)
	_refresh_tracker()
	if _opening_pending.is_empty():
		if _poll_timer != null:
			_poll_timer.stop()
		_tracker_status.text = "起手完成，自动展开开始…"
		await get_tree().create_timer(0.5).timeout
		await _run_auto_follow()


func _run_auto_follow() -> void:
	var bn = _find_battle_node(get_tree().current_scene)
	if bn == null:
		_tracker_status.text = "找不到战斗节点"
		return
	var battle = bn.get("battle")
	var played: Array = []
	var owned: Array = []
	for ex in _armed_chain.get("extras", []):
		if _hand_ids().has(str(ex["id"])):
			owned.append(ex)
	for ex in owned:
		_tracker_status.text = "自动展开：「%s」" % str(ex["name"])
		await _fly_card(str(ex["id"]), str(ex.get("family", "spell")), str(ex["name"]), Vector2i(-1, -1), bn)
		var card = _hand_card_data(battle, str(ex["id"]))
		if card == null:
			continue
		var r: Dictionary = battle.play_card(card, -1, Vector2i(-1, -1))
		if not bool(r.get("ok", false)):
			_tracker_status.text = "自动展开中断：%s" % str(r.get("reason", "条件不足"))
			break
		played.append(str(ex["id"]))
	_settle_chain(_armed_chain["cards"].size(), _armed_chain["cards"].size(), played)
	await get_tree().create_timer(3.0).timeout
	if _tracker != null:
		_tracker.visible = false
	_armed_chain = {}
