extends Control

const CardUIScene: PackedScene = preload("res://ui/card_ui.tscn")
const CardDetailScene: PackedScene = preload("res://ui/card_detail_panel.tscn")
const TC = preload("res://core/theme/theme_colors.gd")
const MAX_DECK_SIZE := 21
const MAX_COPIES_PER_CARD := 3

# ============================================================
# 筛选状态
# ============================================================
enum TypeFilter { ALL, SPELL, UNIT, TRAP }
enum RoleFilter { ALL, STARTER, EXTENDER, CONTROL, FINISHER }

var _type_filter: TypeFilter = TypeFilter.ALL
var _role_filter: RoleFilter = RoleFilter.ALL

# ============================================================
# 数据
# ============================================================
var library: CardLibrary
var deck: DeckData
var card_counts: Dictionary = {}  # card_name → int
var card_detail_panel: CardDetailPanel = null

# ============================================================
# 按钮样式
# ============================================================
var _style_active: StyleBoxFlat
var _style_inactive: StyleBoxFlat

# ============================================================
# @onready 节点
# ============================================================
@onready var cards_grid: GridContainer = $MainArea/LeftPanel/ScrollContainer/GridContainer
@onready var pool_label: Label = $MainArea/LeftPanel/PoolLabel
@onready var deck_vbox: VBoxContainer = $MainArea/RightPanel/DeckScroll/DeckVBox
@onready var deck_count_label: Label = $MainArea/RightPanel/DeckHeader/DeckCountLabel
@onready var role_stats_label: Label = $MainArea/RightPanel/RoleStatsLabel
@onready var od_curve_label: Label = $MainArea/RightPanel/ODCurveLabel
@onready var od_curve_bar: HBoxContainer = $MainArea/RightPanel/ODCurveBar
@onready var save_btn: Button = $TopBar/SaveBtn
@onready var back_btn: Button = $TopBar/BackBtn
@onready var detail_label: Label = $MainArea/RightPanel/DetailLabel

# Filter buttons
@onready var type_all_btn: Button = $FilterBar/TypeAllBtn
@onready var type_spell_btn: Button = $FilterBar/TypeSpellBtn
@onready var type_unit_btn: Button = $FilterBar/TypeUnitBtn
@onready var type_trap_btn: Button = $FilterBar/TypeTrapBtn
@onready var role_all_btn: Button = $FilterBar/RoleAllBtn
@onready var role_starter_btn: Button = $FilterBar/RoleStarterBtn
@onready var role_extender_btn: Button = $FilterBar/RoleExtenderBtn
@onready var role_control_btn: Button = $FilterBar/RoleControlBtn
@onready var role_finisher_btn: Button = $FilterBar/RoleFinisherBtn


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	_apply_theme()
	_build_styles()
	_setup_detail_panel()
	_load_library()
	_load_existing_deck()
	_connect_buttons()
	_apply_filters()


func _apply_theme() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = TC.BG_DARK
	add_theme_stylebox_override("panel", bg)


func _build_styles() -> void:
	_style_active = StyleBoxFlat.new()
	_style_active.bg_color = TC.BG_RAISED
	_style_active.border_width_left = 2
	_style_active.border_width_right = 2
	_style_active.border_width_top = 2
	_style_active.border_width_bottom = 2
	_style_active.border_color = TC.ACCENT_GOLD
	_style_active.set_corner_radius_all(4)

	_style_inactive = StyleBoxFlat.new()
	_style_inactive.bg_color = TC.BG_PANEL
	_style_inactive.border_width_left = 1
	_style_inactive.border_width_right = 1
	_style_inactive.border_width_top = 1
	_style_inactive.border_width_bottom = 1
	_style_inactive.border_color = TC.BORDER_DEFAULT
	_style_inactive.set_corner_radius_all(4)


# ============================================================
# 详情面板（右侧内嵌）
# ============================================================
func _setup_detail_panel() -> void:
	card_detail_panel = CardDetailScene.instantiate()
	card_detail_panel.custom_minimum_size = Vector2(300, 180)
	$MainArea/RightPanel.add_child(card_detail_panel)
	# 放在 DeckScroll 之前
	$MainArea/RightPanel.move_child(card_detail_panel, $MainArea/RightPanel.get_child_count() - 3)


# ============================================================
# 数据加载
# ============================================================
func _load_library() -> void:
	library = CardLibrary.new()
	add_child(library)


func _load_existing_deck() -> void:
	var gm = _gm()
	var existing: DeckData = gm.get_deck()
	if existing and existing.cards.size() > 0:
		deck = existing
		for card in deck.cards:
			card_counts[card.card_name] = card_counts.get(card.card_name, 0) + 1
	else:
		deck = DeckData.new()
	_refresh_deck()


# ============================================================
# 按钮连接
# ============================================================
func _connect_buttons() -> void:
	back_btn.pressed.connect(_on_back)
	save_btn.pressed.connect(_on_save)

	type_all_btn.pressed.connect(_on_type_filter.bind(TypeFilter.ALL))
	type_spell_btn.pressed.connect(_on_type_filter.bind(TypeFilter.SPELL))
	type_unit_btn.pressed.connect(_on_type_filter.bind(TypeFilter.UNIT))
	type_trap_btn.pressed.connect(_on_type_filter.bind(TypeFilter.TRAP))

	role_all_btn.pressed.connect(_on_role_filter.bind(RoleFilter.ALL))
	role_starter_btn.pressed.connect(_on_role_filter.bind(RoleFilter.STARTER))
	role_extender_btn.pressed.connect(_on_role_filter.bind(RoleFilter.EXTENDER))
	role_control_btn.pressed.connect(_on_role_filter.bind(RoleFilter.CONTROL))
	role_finisher_btn.pressed.connect(_on_role_filter.bind(RoleFilter.FINISHER))


# ============================================================
# 筛选回调
# ============================================================
func _on_type_filter(filter: TypeFilter) -> void:
	_type_filter = filter
	_apply_filters()


func _on_role_filter(filter: RoleFilter) -> void:
	_role_filter = filter
	_apply_filters()


func _refresh_filter_button_styles() -> void:
	var type_btns: Dictionary = {
		TypeFilter.ALL: type_all_btn, TypeFilter.SPELL: type_spell_btn,
		TypeFilter.UNIT: type_unit_btn, TypeFilter.TRAP: type_trap_btn,
	}
	for filter in type_btns:
		var btn: Button = type_btns[filter]
		if btn:
			btn.add_theme_stylebox_override("normal", _style_active if filter == _type_filter else _style_inactive)
			btn.add_theme_color_override("font_color",
				TC.ACCENT_GOLD if filter == _type_filter else TC.TEXT_SECONDARY)

	var role_btns: Dictionary = {
		RoleFilter.ALL: role_all_btn, RoleFilter.STARTER: role_starter_btn,
		RoleFilter.EXTENDER: role_extender_btn, RoleFilter.CONTROL: role_control_btn,
		RoleFilter.FINISHER: role_finisher_btn,
	}
	for filter in role_btns:
		var btn: Button = role_btns[filter]
		if btn:
			btn.add_theme_stylebox_override("normal", _style_active if filter == _role_filter else _style_inactive)
			btn.add_theme_color_override("font_color",
				TC.ACCENT_GOLD if filter == _role_filter else TC.TEXT_SECONDARY)


# ============================================================
# 筛选 + 重建左侧卡池
# ============================================================
func _apply_filters() -> void:
	for child in cards_grid.get_children():
		child.queue_free()

	var filtered: Array = []
	for card in library.all_cards:
		if card == null:
			continue
		if _passes_type_filter(card) and _passes_role_filter(card):
			filtered.append(card)

	for card in filtered:
		var ui: CardUI = CardUIScene.instantiate()
		ui.is_playable = false
		ui.setup(card, true)
		var captured_card: CardData = card
		ui.card_clicked.connect(func(_ui: CardUI) -> void:
			_on_add_card(captured_card)
		)
		ui.card_hovered.connect(_on_card_hovered)
		ui.card_unhovered.connect(_on_card_unhovered)
		ui.card_selected.connect(_on_card_selected)
		cards_grid.add_child(ui)

	pool_label.text = "卡牌库 (%d)" % filtered.size()
	_refresh_filter_button_styles()


func _passes_type_filter(card: CardData) -> bool:
	match _type_filter:
		TypeFilter.ALL: return true
		TypeFilter.SPELL: return card.card_type == CardData.CardType.SPELL
		TypeFilter.UNIT: return card.card_type == CardData.CardType.UNIT
		TypeFilter.TRAP: return card.card_type == CardData.CardType.TRAP
	return true


func _passes_role_filter(card: CardData) -> bool:
	match _role_filter:
		RoleFilter.ALL: return true
		RoleFilter.STARTER: return card.archetype_role == CardData.ArchetypeRole.STARTER
		RoleFilter.EXTENDER: return card.archetype_role == CardData.ArchetypeRole.EXTENDER
		RoleFilter.CONTROL: return card.archetype_role == CardData.ArchetypeRole.CONTROL
		RoleFilter.FINISHER: return card.archetype_role == CardData.ArchetypeRole.FINISHER
	return true


# ============================================================
# 加入卡组
# ============================================================
func _on_add_card(card: CardData) -> void:
	if deck.cards.size() >= MAX_DECK_SIZE:
		print("[DeckBuilder] Deck full (%d max)" % MAX_DECK_SIZE)
		return

	var copies: int = int(card_counts.get(card.card_name, 0))
	if copies >= MAX_COPIES_PER_CARD:
		print("[DeckBuilder] Max %d copies of %s" % [MAX_COPIES_PER_CARD, card.card_name])
		return

	deck.add_card(card)
	card_counts[card.card_name] = copies + 1
	_refresh_deck()


# ============================================================
# 从卡组中移除
# ============================================================
func _on_remove_card_by_name(card_name: String) -> void:
	for card in deck.cards:
		if card.card_name == card_name:
			deck.remove_card(card)
			var count: int = int(card_counts.get(card_name, 1))
			if count <= 1:
				card_counts.erase(card_name)
			else:
				card_counts[card_name] = count - 1
			_refresh_deck()
			return


# ============================================================
# 右侧卡组列表重建
# ============================================================
func _refresh_deck() -> void:
	for child in deck_vbox.get_children():
		child.queue_free()

	# 按名称聚合
	var aggregated: Dictionary = {}
	var aggregated_card: Dictionary = {}  # card_name → CardData (保留引用)
	for card in deck.cards:
		aggregated[card.card_name] = aggregated.get(card.card_name, 0) + 1
		aggregated_card[card.card_name] = card

	for card_name in aggregated:
		var count: int = aggregated[card_name]
		var card: CardData = aggregated_card[card_name]

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)

		# 角色颜色指示条
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(4, 0)
		dot.color = _archetype_color(card)
		hbox.add_child(dot)

		# 卡名 + 数量
		var label: Label = Label.new()
		label.text = "%s  x%d" % [card_name, count]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", _archetype_color(card))
		label.mouse_entered.connect(_on_card_hovered.bind(card))
		label.mouse_exited.connect(_on_card_unhovered)
		hbox.add_child(label)

		# OD cost
		var cost_label: Label = Label.new()
		cost_label.text = str(card.od_cost)
		cost_label.custom_minimum_size = Vector2(24, 0)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.add_theme_font_size_override("font_size", 12)
		cost_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1, 1))
		hbox.add_child(cost_label)

		# 移除按钮
		var remove_btn: Button = Button.new()
		remove_btn.text = "-"
		remove_btn.custom_minimum_size = Vector2(28, 28)
		remove_btn.add_theme_font_size_override("font_size", 14)
		remove_btn.pressed.connect(_on_remove_card_by_name.bind(card_name))
		hbox.add_child(remove_btn)

		deck_vbox.add_child(hbox)

	_update_stats()
	_update_od_curve()


# ============================================================
# 统计更新
# ============================================================
func _update_stats() -> void:
	var starter := 0
	var extender := 0
	var control := 0
	var finisher := 0

	for card in deck.cards:
		match card.archetype_role:
			CardData.ArchetypeRole.STARTER: starter += 1
			CardData.ArchetypeRole.EXTENDER: extender += 1
			CardData.ArchetypeRole.CONTROL: control += 1
			CardData.ArchetypeRole.FINISHER: finisher += 1

	role_stats_label.text = "STARTER:%d  EXTENDER:%d  CONTROL:%d  FINISHER:%d" % [starter, extender, control, finisher]

	deck_count_label.text = "%d/%d" % [deck.cards.size(), MAX_DECK_SIZE]


# ============================================================
# OD 曲线
# ============================================================
func _update_od_curve() -> void:
	var low_od := 0   # 1-2
	var mid_od := 0   # 3-4
	var high_od := 0  # 5+

	for card in deck.cards:
		var cost: int = card.od_cost
		if cost <= 2:
			low_od += 1
		elif cost <= 4:
			mid_od += 1
		else:
			high_od += 1

	od_curve_label.text = "OD曲线: 低OD %d  |  中OD %d  |  高OD %d" % [low_od, mid_od, high_od]

	# 可视化条形
	for child in od_curve_bar.get_children():
		child.queue_free()

	var total := maxi(1, low_od + mid_od + high_od)
	_add_curve_bar(od_curve_bar, low_od, total, Color(0.3, 0.6, 1, 1))
	_add_curve_bar(od_curve_bar, mid_od, total, Color(1, 0.5, 0.1, 1))
	_add_curve_bar(od_curve_bar, high_od, total, Color(1, 0.15, 0.05, 1))


func _add_curve_bar(parent: HBoxContainer, count: int, total: int, color: Color) -> void:
	var bar := ColorRect.new()
	bar.color = color
	bar.custom_minimum_size = Vector2(maxf(4, 120.0 * count / total), 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)


# ============================================================
# 卡牌详情（hover / right-click）
# ============================================================
func _on_card_hovered(card: CardData) -> void:
	if card_detail_panel:
		card_detail_panel.show_card(card, "")
		if detail_label:
			detail_label.visible = false


func _on_card_unhovered() -> void:
	pass  # 保留详情


func _on_card_selected(card: CardData) -> void:
	if card_detail_panel and card_detail_panel.visible:
		card_detail_panel.clear()
		if detail_label:
			detail_label.visible = true
	else:
		_on_card_hovered(card)


# ============================================================
# 按钮回调
# ============================================================
func _on_back() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_sfx("ui_click")
	_gm().change_scene("res://scenes/menu/main_menu.tscn")


func _on_save() -> void:
	if deck.cards.size() == 0:
		print("[DeckBuilder] Cannot save empty deck")
		return

	var gm = _gm()

	# 使用 GameManager 持久化 library 重建卡组，确保引用不失效
	var persistent_lib = gm.get_library()
	var rebuilt_deck := DeckData.new()
	rebuilt_deck.deck_name = deck.deck_name if deck.deck_name != "" else "My Deck"
	for card in deck.cards:
		var found := false
		for lib_card in persistent_lib.all_cards:
			if lib_card.card_name == card.card_name:
				rebuilt_deck.add_card(lib_card)
				found = true
				break
		if not found:
			print("[DeckBuilder] Card '%s' not in persistent library — skipped" % card.card_name)

	gm.set_deck(rebuilt_deck)
	gm.current_deck_name = rebuilt_deck.deck_name
	print("[DeckBuilder] Deck saved: %s (%d cards)" % [rebuilt_deck.deck_name, rebuilt_deck.cards.size()])
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_sfx("ui_click")
	_gm().change_scene("res://scenes/menu/main_menu.tscn")


# ============================================================
# 辅助
# ============================================================
func _gm():
	return get_node("/root/GameManager")


func _archetype_color(card: CardData) -> Color:
	match card.archetype_role:
		CardData.ArchetypeRole.STARTER: return Color(0.3, 0.6, 1, 1)
		CardData.ArchetypeRole.EXTENDER: return Color(1, 0.5, 0.1, 1)
		CardData.ArchetypeRole.CONTROL: return Color(0.3, 1, 0.3, 1)
		CardData.ArchetypeRole.FINISHER: return Color(1, 0.1, 0.1, 1)
	return Color(0.7, 0.7, 0.7, 1)
