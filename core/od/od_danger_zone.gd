class_name ODDangerZone
extends RefCounted

# 区间枚举
enum Zone {
	SAFE = 0,     # OD 0-3: 安全
	WARNING = 1,  # OD 4-6: 警告
	DANGER = 2,   # OD 7-9: 危险
	CRITICAL = 3  # OD = 10: 暴走/觉醒
}

# 区间阈值（上界）
const SAFE_MAX := 3
const WARNING_MAX := 6
const DANGER_MAX := 9
const MAX_OD := 10

# 区间效果参数
const DAMAGE_TAKEN_MULTIPLIER := {
	Zone.SAFE: 1.0,
	Zone.WARNING: 1.2,
	Zone.DANGER: 1.5,
	Zone.CRITICAL: 2.0,
}

const OVERLOAD_PENALTY_MULTIPLIER := {
	Zone.SAFE: 1.0,
	Zone.WARNING: 1.0,
	Zone.DANGER: 2.0,
	Zone.CRITICAL: 3.0,
}

# 区间显示名称
const ZONE_NAMES := {
	Zone.SAFE: "Safe",
	Zone.WARNING: "Warning",
	Zone.DANGER: "DANGER",
	Zone.CRITICAL: "CRITICAL",
}

# 区间颜色
const ZONE_COLORS := {
	Zone.SAFE: Color(0.3, 0.7, 1.0),    # 蓝
	Zone.WARNING: Color(1.0, 0.85, 0.2), # 黄
	Zone.DANGER: Color(1.0, 0.4, 0.1),   # 橙
	Zone.CRITICAL: Color(1.0, 0.1, 0.1), # 红
}

# =========================
# 区间判断
# =========================
func get_zone(od: int) -> int:
	if od <= SAFE_MAX:
		return Zone.SAFE
	elif od <= WARNING_MAX:
		return Zone.WARNING
	elif od <= DANGER_MAX:
		return Zone.DANGER
	else:
		return Zone.CRITICAL

# =========================
# 区间效果查询
# =========================
func get_damage_taken_multiplier(od: int) -> float:
	return DAMAGE_TAKEN_MULTIPLIER.get(get_zone(od), 1.0)

func get_overload_penalty_multiplier(od: int) -> float:
	return OVERLOAD_PENALTY_MULTIPLIER.get(get_zone(od), 1.0)

func get_zone_name(od: int) -> String:
	return ZONE_NAMES.get(get_zone(od), "Unknown")

func get_zone_color(od: int) -> Color:
	return ZONE_COLORS.get(get_zone(od), Color.WHITE)
