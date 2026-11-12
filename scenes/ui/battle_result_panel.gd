extends Control
class_name BattleResultPanel

signal return_to_menu
signal retry

const TC = preload("res://core/theme/theme_colors.gd")

@onready var dark_bg: ColorRect = $DarkBG
@onready var result_label: Label = $ResultMargin/ResultCenter/ResultCard/ResultVBox/ResultLabel
@onready var info_label: Label = $ResultMargin/ResultCenter/ResultCard/ResultVBox/InfoLabel
@onready var stats_content: MarginContainer = $ResultMargin/ResultCenter/ResultCard/ResultVBox/StatsScroll/StatsContent
@onready var return_button: Button = $ResultMargin/ResultCenter/ResultCard/ResultVBox/BtnContainer/ReturnButton
@onready var retry_button: Button = $ResultMargin/ResultCenter/ResultCard/ResultVBox/BtnContainer/RetryButton

var _won: bool = false
var _stats_label: Label = null


func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	hide()


## stats: Dictionary — { "turns": int, "max_od": int, "overdrive": bool, "finisher": bool, "chains": int, "boss_od": int, "combo": int }
func show_result(won: bool, stats: Dictionary = {}) -> void:
	_won = won

	var lm = get_node_or_null("/root/LocalizationManager")

	if won:
		if lm:
			result_label.text = lm.t("victory")
		else:
			result_label.text = "战斗胜利"
		if result_label:
			result_label.add_theme_color_override("font_color", TC.ACCENT_GOLD)
		if info_label:
			info_label.text = "Boss已击败"
	else:
		if lm:
			result_label.text = lm.t("defeat")
		else:
			result_label.text = "战斗失败"
		if result_label:
			result_label.add_theme_color_override("font_color", TC.ZONE_OVERDRIVE)
		if info_label:
			info_label.text = "OD核心崩溃"

	# ── 统计数据 ──
	if not stats.is_empty():
		_build_stats(stats)

	show()


func _build_stats(stats: Dictionary) -> void:
	if _stats_label:
		_stats_label.queue_free()

	_stats_label = Label.new()
	_stats_label.name = "StatsLabel"
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.add_theme_color_override("font_color", TC.TEXT_SECONDARY)

	var lines: Array[String] = []
	lines.append("— 战斗数据 —")
	if stats.has("turns"):
		lines.append("回合数: %d" % stats["turns"])
	if stats.has("total_cards"):
		lines.append("总出牌: %d 张" % stats["total_cards"])
	if stats.has("max_od"):
		lines.append("最高 OD: %d" % stats["max_od"])
	if stats.get("overdrive", false):
		lines.append("进入 Overdrive ⚡")
	if stats.has("chains"):
		lines.append("完成 Chain: %d 条" % stats["chains"])
	if stats.get("finisher", false):
		lines.append("释放 Finisher ★")
	if stats.has("max_hit") and stats["max_hit"] > 0:
		lines.append("最大单次伤害: %d" % stats["max_hit"])
	if stats.has("boss_od"):
		lines.append("Boss 最高 OD: %d" % stats["boss_od"])
	if stats.has("combo") and stats["combo"] > 0:
		lines.append("最高 Combo: %d" % stats["combo"])
	if stats.has("traps") and stats["traps"] > 0:
		lines.append("陷阱触发: %d 次" % stats["traps"])
	if stats.has("boss_overdrives") and stats["boss_overdrives"] > 0:
		lines.append("Boss Overdrive: %d 次" % stats["boss_overdrives"])
	if stats.has("boss_interrupted") and stats["boss_interrupted"] > 0:
		lines.append("Boss 被打断: %d 次" % stats["boss_interrupted"])

	# ── 评价 ──
	var evals: Array[String] = _eval_text(stats)
	if not evals.is_empty():
		lines.append("")
	for e in evals:
		lines.append(e)

	_stats_label.text = "\n".join(lines)

	# Phase 23C0: Add stats inside the StatsContent (child of ScrollContainer), not VBox
	if stats_content:
		stats_content.add_child(_stats_label)


func _eval_text(stats: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if stats.get("overdrive", false):
		result.append("⚡ 高危超驱")
	if stats.get("finisher", false):
		result.append("★ 终结技收束")
	if stats.has("chains") and stats["chains"] > 0:
		result.append("◎ Chain完成: %d条" % stats["chains"])
	if stats.has("max_od") and stats["max_od"] <= 4:
		result.append("❄ 稳定控温")
	if stats.has("max_od") and stats["max_od"] >= 8:
		result.append("🔥 极限压线")
	if stats.has("turns") and stats["turns"] <= 5:
		result.append("⚔ 速攻战术")
	if stats.has("total_cards") and stats["total_cards"] >= 15:
		result.append("📋 全展开策略")
	if stats.has("boss_interrupted") and stats["boss_interrupted"] > 0:
		result.append("🛡 Boss超驱被打断 ×%d" % stats["boss_interrupted"])
	if stats.has("traps") and stats["traps"] > 0:
		result.append("◎ 陷阱战术成功")
	if result.is_empty():
		result.append("核心过载")
	return result


func set_info(text: String) -> void:
	info_label.text = text


func _on_return_pressed() -> void:
	return_to_menu.emit()


func _on_retry_pressed() -> void:
	retry.emit()
