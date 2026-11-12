extends Node
## AudioManager — 轻量音频管理 autoload
## 支持 BGM 循环 + SFX 多通道 + 安全缺文件不报错

# ============================================================
# 音效 Key 常量
# ============================================================
const SFX := {
	# 原有
	"ui_click":         "ui_click",
	"ui_hover":         "ui_hover",
	"card_draw":        "card_draw",
	"card_play":        "card_play",
	"hit":              "hit",
	"boss_hit":         "boss_hit",
	"player_hit":       "player_hit",
	"od_up":            "od_up",
	"od_down":          "od_down",
	"enter_heated":     "enter_heated",
	"enter_overdrive":  "enter_overdrive",
	"boss_warning":     "boss_warning",
	"chain_step":       "chain_step",
	"chain_complete":   "chain_complete",
	"finisher":         "finisher",
	"victory":          "victory",
	"defeat":           "defeat",
	# Phase 11D: 新增音效事件
	"monster_land":     "monster_land",
	"spell_cast":       "spell_cast",
	"counter_set":      "counter_set",
	"building_land":    "building_land",
	"monster_attack":   "monster_attack",
	"monster_hit":      "monster_hit",
	"card_destroy":     "card_destroy",
	"building_activate":"building_activate",
	"building_replace": "building_replace",
	"od_charge_tick":   "od_charge_tick",
	"od_layer_up":      "od_layer_up",
	"burst":            "burst",
	"depth_warning":    "depth_warning",
	"boss_intent":      "boss_intent",
	"boss_action":      "boss_action",
	"boss_core_online": "boss_core_online",
	"ui_error":         "ui_error",
	"shield_block":     "shield_block",
	"od_release_extract":"od_release_extract",
	"od_release_conduit":"od_release_conduit",
	"od_release_impact": "od_release_impact",
}

# ============================================================
# 音量
# ============================================================
var master_volume: float = 1.0:
	set(v):
		master_volume = clampf(v, 0.0, 1.0)
		_apply_volumes()
var bgm_volume: float = 0.8:
	set(v):
		bgm_volume = clampf(v, 0.0, 1.0)
		_apply_volumes()
var sfx_volume: float = 1.0:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		_apply_volumes()

# ============================================================
# 内部
# ============================================================
var _bgm_player: AudioStreamPlayer = null
var _sfx_pool: Array[AudioStreamPlayer] = []
const MAX_SFX_CHANNELS := 6
var _sfx_index := 0
var _current_bgm: String = ""  # BGM 去重
# Phase 11D: SFX 节流
var _last_sfx_time: Dictionary = {}
var _missing_sfx_warned: Dictionary = {}

const BGM_PATH := "res://audio/bgm/%s.ogg"
const SFX_OGG_PATH := "res://audio/sfx/%s.ogg"
const SFX_WAV_PATH := "res://audio/sfx/%s.wav"

# Legacy callers keep their names; an exact authored asset always takes priority.
# All fallbacks are existing, project-generated greybox sounds.
const SFX_FALLBACKS := {
	"hit": "monster_hit", "boss_hit": "monster_hit", "player_hit": "monster_hit",
	"boss_warning": "enter_heated", "building_activate": "counter_set",
	"chain_step": "od_charge_tick", "chain_complete": "enter_overdrive",
	"ui_hover": "ui_click", "card_draw": "card_play", "od_down": "od_release_extract",
	"finisher": "od_release_impact", "card_destroy": "od_release_impact",
	"building_replace": "building_land", "od_layer_up": "enter_heated",
	"burst": "od_release_impact", "depth_warning": "enter_heated",
	"boss_intent": "counter_set", "boss_action": "monster_attack",
	"boss_core_online": "enter_overdrive",
}


# ============================================================
# 初始化
# ============================================================
func _ready() -> void:
	_setup_bgm_player()
	_setup_sfx_pool()


func _setup_bgm_player() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = "Master"
	add_child(_bgm_player)


func _setup_sfx_pool() -> void:
	for i in range(MAX_SFX_CHANNELS):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer%d" % i
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)


func _apply_volumes() -> void:
	if _bgm_player:
		_bgm_player.volume_db = _to_db(master_volume * bgm_volume)
	for p in _sfx_pool:
		if is_instance_valid(p):
			p.volume_db = _to_db(master_volume * sfx_volume)


func _to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10)


# ============================================================
# BGM API
# ============================================================

## 播放菜单背景音乐
func play_menu_bgm() -> void:
	_play_bgm("menu_theme")


## 播放战斗背景音乐
func play_battle_bgm() -> void:
	_play_bgm("battle_theme")


## 停止 BGM
func stop_bgm() -> void:
	_current_bgm = ""
	if _bgm_player and _bgm_player.playing:
		_bgm_player.stop()


func _play_bgm(name: String) -> void:
	if not _bgm_player:
		return
	# BGM 去重
	if _current_bgm == name and _bgm_player.playing:
		return
	_current_bgm = name
	_bgm_player.stop()

	var path: String = BGM_PATH % name
	if not ResourceLoader.exists(path):
		print("[AudioManager] BGM not found: %s — silent" % path)
		return

	var stream = load(path)
	if stream == null:
		print("[AudioManager] BGM load failed: %s" % path)
		return

	_bgm_player.stream = stream
	_bgm_player.volume_db = _to_db(master_volume * bgm_volume)
	_bgm_player.play()
	print("[AudioManager] BGM playing: %s" % name)


# ============================================================
# SFX API
# ============================================================

func play_sfx(sfx_key: String) -> void:
	if sfx_key == "":
		return
	_play_sfx_file(sfx_key)


# ── 便捷方法 ──
func play_ui_click() -> void:    play_sfx("ui_click")
func play_ui_hover() -> void:    play_sfx("ui_hover")
func play_card_play() -> void:   play_sfx("card_play")
func play_card_draw() -> void:   play_sfx("card_draw")
func play_hit() -> void:         play_sfx("hit")
func play_boss_hit() -> void:    play_sfx("boss_hit")
func play_player_hit() -> void:  play_sfx("player_hit")
func play_od_up() -> void:       play_sfx("od_up")
func play_enter_heated() -> void:   play_sfx("enter_heated")
func play_enter_overdrive() -> void: play_sfx("enter_overdrive")
func play_chain_step() -> void:     play_sfx("chain_step")
func play_chain_complete() -> void: play_sfx("chain_complete")
func play_finisher() -> void:       play_sfx("finisher")
func play_victory() -> void:        play_sfx("victory")
func play_defeat() -> void:         play_sfx("defeat")


# Phase 11D: 新增便捷方法
func play_monster_land() -> void:      play_sfx("monster_land")
func play_spell_cast() -> void:        play_sfx("spell_cast")
func play_counter_set() -> void:       play_sfx("counter_set")
func play_building_land() -> void:     play_sfx("building_land")
func play_monster_attack() -> void:    play_sfx("monster_attack")
func play_monster_hit() -> void:       play_sfx("monster_hit")
func play_card_destroy() -> void:      play_sfx("card_destroy")
func play_building_activate() -> void: play_sfx("building_activate")
func play_building_replace() -> void:  play_sfx("building_replace")
func play_od_charge_tick() -> void:    play_sfx("od_charge_tick")
func play_od_layer_up() -> void:       play_sfx("od_layer_up")
func play_burst() -> void:             play_sfx("burst")
func play_depth_warning() -> void:     play_sfx("depth_warning")
func play_boss_intent() -> void:       play_sfx("boss_intent")
func play_boss_action() -> void:       play_sfx("boss_action")
func play_boss_core_online() -> void:  play_sfx("boss_core_online")
func play_ui_error() -> void:          play_sfx("ui_error")
func play_shield_block() -> void:       play_sfx("shield_block")
func play_od_release_extract() -> void: play_sfx("od_release_extract")
func play_od_release_conduit() -> void: play_sfx("od_release_conduit")
func play_od_release_impact() -> void:  play_sfx("od_release_impact")
func play_sfx_throttled(key: String, min_interval: float = 0.03) -> void:
	var now: float = Time.get_ticks_msec() * 0.001
	var last_val = _last_sfx_time.get(key, -1.0)
	var last: float = last_val if typeof(last_val) == TYPE_FLOAT else -1.0
	if now - last < min_interval:
		return
	_last_sfx_time[key] = now
	play_sfx(key)

func get_sfx_resource_path(name: String) -> String:
	var exact := _get_exact_sfx_path(name)
	if not exact.is_empty():
		return exact
	return _get_exact_sfx_path(SFX_FALLBACKS[name]) if SFX_FALLBACKS.has(name) else ""


func _get_exact_sfx_path(name: String) -> String:
	var ogg_path := SFX_OGG_PATH % name
	if ResourceLoader.exists(ogg_path):
		return ogg_path
	var wav_path := SFX_WAV_PATH % name
	if ResourceLoader.exists(wav_path):
		return wav_path
	return ""


func has_sfx(name: String) -> bool:
	return not get_sfx_resource_path(name).is_empty()


func _play_sfx_file(name: String) -> void:
	var path := get_sfx_resource_path(name)
	if path.is_empty():
		if not _missing_sfx_warned.has(name):
			_missing_sfx_warned[name] = true
			print("[AudioManager] SFX not found: %s / %s — silent" % [SFX_OGG_PATH % name, SFX_WAV_PATH % name])
		return

	var stream = load(path)
	if stream == null:
		print("[AudioManager] SFX load failed: %s" % path)
		return

	# 轮转 SFX 通道
	var player: AudioStreamPlayer = _sfx_pool[_sfx_index % MAX_SFX_CHANNELS]
	_sfx_index += 1

	if not is_instance_valid(player):
		return

	player.stop()
	player.stream = stream
	player.volume_db = _to_db(master_volume * sfx_volume)
	player.play()


# ============================================================
# 便捷音量接口
# ============================================================

func set_master_vol(v: float) -> void:
	master_volume = v


func set_bgm_vol(v: float) -> void:
	bgm_volume = v


func set_sfx_vol(v: float) -> void:
	sfx_volume = v
