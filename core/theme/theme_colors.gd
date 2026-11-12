extends RefCounted
class_name ThemeColors

## 统一主题色板 — "机械熔炉 + 能量核心 + 战术牌桌"
## 所有 UI 文件引用此色板，确保风格统一

# ── 背景层 ──
const BG_DARK: Color       = Color(0.045, 0.045, 0.08, 1)       # 深炉黑 — 页面底色
const BG_PANEL: Color      = Color(0.08,  0.08,  0.13, 1)        # 炉灰 — 面板底色
const BG_RAISED: Color     = Color(0.11,  0.11,  0.17, 1)        # 铁板 — 悬浮面板
const BG_CARD: Color       = Color(0.07,  0.07,  0.115, 0.94)    # 卡牌底色

# ── 边框 ──
const BORDER_DEFAULT: Color = Color(0.17, 0.17, 0.27, 1)
const BORDER_FOCUSED: Color = Color(0.5,  0.5,  0.7,  1)

# ── 能量层：OD 三阶段 ──
const ZONE_CALM: Color      = Color(0.33, 0.57, 0.95, 1)         # 冷蓝 #548FF2
const ZONE_HEATED: Color    = Color(0.95, 0.47, 0.14, 1)         # 熔橙 #F27824
const ZONE_OVERDRIVE: Color = Color(0.95, 0.14, 0.07, 1)         # 炽红 #F22412

# ── 角色标识色 ──
const ROLE_STARTER: Color   = Color(0.33, 0.57, 0.95, 1)         # 蓝 — 与 CALM 同色系
const ROLE_EXTENDER: Color  = Color(0.95, 0.47, 0.14, 1)         # 橙 — 与 HEATED 同色系
const ROLE_CONTROL: Color   = Color(0.24, 0.80, 0.32, 1)         # 绿
const ROLE_FINISHER: Color  = Color(0.95, 0.14, 0.07, 1)         # 红 — 与 OVERDRIVE 同色系
const ROLE_DEFENSE: Color   = Color(0.27, 0.85, 0.76, 1)         # 青 — 防御/冷却

# ── 特殊 ──
const ACCENT_GOLD: Color    = Color(0.97, 0.80, 0.18, 1)         # 超频金 — SUPER/觉醒/Route完成
const LOAD_SAFE: Color      = Color(0.85, 0.65, 0.25, 1)         # Load 安全色
const LOAD_WARN: Color      = Color(0.95, 0.47, 0.14, 1)         # Load 警告色 (= HEATED)
const LOAD_OVER: Color      = Color(0.95, 0.14, 0.07, 1)         # Load 超限色 (= OVERDRIVE)

# ── 文字 ──
const TEXT_PRIMARY: Color   = Color(0.91, 0.91, 0.94, 1)         # 主白
const TEXT_SECONDARY: Color = Color(0.55, 0.55, 0.64, 1)         # 次灰
const TEXT_DIM: Color       = Color(0.35, 0.35, 0.42, 1)         # 暗灰

# ── 语义色 ──
const DANGER: Color         = Color(0.95, 0.14, 0.07, 1)         # 危险 (= OVERDRIVE)
const SUCCESS: Color        = Color(0.24, 0.80, 0.32, 1)         # 成功 (= CONTROL)
const INFO: Color           = Color(0.33, 0.57, 0.95, 1)         # 信息 (= CALM)
const WARNING: Color        = Color(0.95, 0.47, 0.14, 1)         # 警告 (= HEATED)


## 根据 Zone 名称返回对应颜色
static func zone_color(zone_name: String) -> Color:
	match zone_name:
		"Calm":      return ZONE_CALM
		"Heated":    return ZONE_HEATED
		"Overdrive": return ZONE_OVERDRIVE
	return ZONE_CALM

## 根据角色返回对应颜色
static func role_color(role: int) -> Color:
	match role:
		0: return ROLE_STARTER    # STARTER
		1: return ROLE_EXTENDER   # EXTENDER
		2: return ROLE_CONTROL    # CONTROL
		3: return ROLE_FINISHER   # FINISHER
		4: return ROLE_DEFENSE    # DEFENSE
	return TEXT_PRIMARY

## 根据 Route ID 返回对应颜色
static func route_color(route_id: String) -> Color:
	match route_id:
		"heat_route":      return ZONE_HEATED
		"overdrive_route": return ZONE_OVERDRIVE
		"control_route":   return ROLE_CONTROL
	return ACCENT_GOLD

## 创建统一圆角面板样式
static func make_panel_style(bg: Color = BG_PANEL, border: Color = BORDER_DEFAULT, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.border_color = border
	s.set_corner_radius_all(radius)
	return s
