extends Node

## LocalizationManager — 最小翻译系统
## 支持中文/英文切换，默认中文
## 用法: LM.t("battle")

const DEFAULT_LANG := "zh"

var _lang: String = DEFAULT_LANG

# ===== 翻译字典 =====
const _DICT := {
	"zh": {
		"battle": "战斗",
		"deck_builder": "卡组构筑",
		"collection": "卡牌收藏",
		"workshop": "工坊",
		"settings": "设置",
		"current_deck": "当前卡组",
		"od_mode": "OD 模式",
		"start_battle": "开始战斗",
		"back": "返回",
		"victory": "胜利",
		"defeat": "失败",
		"retry": "重试",
		"return_menu": "返回主页",
		"select_battle": "选择战斗",
		"cards_count": "%d 张",
		"daily_info": "每日资讯",
		"welcome_back": "欢迎回来",
		"player": "玩家",
		"version": "超频连击 v0.1.0",
		"win_loss": "W:%d L:%d",
		"deck_info": "当前卡组: %s (%d 张)",
		"table_skin": "牌桌皮肤",
		"dark": "暗色",
		"blue": "蓝色",
		"red": "红色",
		"enter_battle": "进入战斗",
		"prepare_combat": "准备战斗",
		"open_deck": "打开卡组",
		"build_strategy": "构筑策略",
		"access_collection": "浏览收藏",
		"browse_cards": "浏览卡牌",
		"customize_deck": "自定义卡组",
		"boss_name": "熔炉守卫",
		"lang_toggle": "中/EN",
	},
	"en": {
		"battle": "Battle",
		"deck_builder": "Deck Builder",
		"collection": "Collection",
		"workshop": "Workshop",
		"settings": "Settings",
		"current_deck": "Current Deck",
		"od_mode": "OD Mode",
		"start_battle": "Start Battle",
		"back": "Back",
		"victory": "Victory",
		"defeat": "Defeat",
		"retry": "Retry",
		"return_menu": "Return to Menu",
		"select_battle": "Select Battle",
		"cards_count": "%d cards",
		"daily_info": "Daily Info",
		"welcome_back": "Welcome back",
		"player": "Player",
		"version": "Overheat Combo v0.1.0",
		"win_loss": "W:%d L:%d",
		"deck_info": "Current Deck: %s (%d cards)",
		"table_skin": "Table Skin",
		"dark": "Dark",
		"blue": "Blue",
		"red": "Red",
		"enter_battle": "ENTER BATTLE",
		"prepare_combat": "Prepare for combat",
		"open_deck": "OPEN DECK",
		"build_strategy": "Build your strategy",
		"access_collection": "ACCESS COLLECTION",
		"browse_cards": "Browse your cards",
		"customize_deck": "Customize your deck",
		"boss_name": "Forge Guardian",
		"lang_toggle": "EN/中",
	},
}


# =========================
# 公开 API
# =========================

func set_language(lang: String) -> void:
	if _DICT.has(lang):
		_lang = lang
		print("[Localization] Language set to: %s" % lang)
	else:
		print("[Localization] Unknown language: %s — kept %s" % [lang, _lang])


func get_language() -> String:
	return _lang


func t(key: String) -> String:
	var dict: Dictionary = _DICT.get(_lang, _DICT["zh"])
	var value = dict.get(key, "")
	if value == "":
		return key
	return value


## 切换语言（zh ↔ en），返回新语言代码
func toggle_language() -> String:
	if _lang == "zh":
		set_language("en")
	else:
		set_language("zh")
	return _lang
