extends Control
class_name TableBattleScene

## TableBattleScene 閳?閸╄桨绨?PlayerTable 閹峰吋顢戦惃鍕灛閺傛婧€閺?
## 閺囧じ鍞?main.gd 閻?UI 鐏炲偊绱濇穱婵堟殌閹碘偓閺?BattleSystem / BattleContext 闁槒绶?
# ============================================================
# 妫板嫬濮炴潪?
# ============================================================
const PlayerTableScene: PackedScene = preload("res://scenes/table/player_table.tscn")
const TC = preload("res://core/theme/theme_colors.gd")
const GameCfg = preload("res://core/config/game_config.gd")
const BattleSystemClass = preload("res://battle/battle_system.gd")
const TurnManagerClass = preload("res://core/battle/turn_manager.gd")
const BattleFXClass = preload("res://ui/battle_fx.gd")
const BattleResultPanelScene = preload("res://scenes/ui/battle_result_panel.tscn")
const BossCardDeckClass = preload("res://core/deck/boss_card_library.gd")
const ActionFeedScene = preload("res://ui/action_feed.tscn")
const BossCardPresenterClass = preload("res://ui/boss_card_presenter.gd")
const BossReactionFXClass = preload("res://ui/boss_reaction_fx.gd")
const CardUIScene: PackedScene = preload("res://ui/card_ui.tscn")
const GraveyardViewClass = preload("res://ui/graveyard_view.gd")
const CardVFXControllerClass = preload("res://ui/card_vfx_controller.gd")
const BattleVFXControllerClass = preload("res://ui/battle_vfx_controller.gd")
const PlaytestTelemetryClass = preload("res://core/debug/playtest_telemetry.gd")
const BOARD_PIECE_MODEL_CONFIG := "res://data/config/board_piece_models.json"
const ArsenalPanelClass = preload("res://ui/arsenal_panel.gd")  # Phase 13D
const MonsterCommandMenuClass = preload("res://ui/monster_command_menu.gd")  # Phase 15B
const BoardPieceRegistryClass = preload("res://core/presentation/board_piece_registry.gd")
const ODCoreCommandPanelClass = preload("res://ui/od_core_command_panel.gd")  # Phase 26C
const CommandEconomyHUDClass = preload("res://ui/command_economy_hud.gd")  # Phase 27D-R3
const ODReleaseControlClass = preload("res://ui/od_release_control.gd")  # Phase 27J
const ODEngineGreyboxClass = preload("res://ui/od_engine_greybox.gd")  # Phase 27K-R0
# Phase 23A-V3: View Controls integration
const BattleViewControlsScene = preload("res://ui/battle_view_controls.tscn")
const BossStatusHUDScene = preload("res://ui/boss_status_hud.tscn")  # Phase 24A
const BossStatusHUDScript = preload("res://ui/boss_status_hud.gd")  # Phase 24A: force class parse order
const MonsterCombatPresenterClass = preload("res://scenes/presentation/monster_combat_presenter.gd")  # Phase 24C-A
const SpellActivationPresenterClass = preload("res://scenes/presentation/spell_activation_presenter.gd")  # Phase 26B-T6
const BattlePresentationDirectorClass = preload("res://scenes/presentation/battle_presentation_director.gd")  # Phase 27K-R1-B
const CardDirectionPresenterClass = preload("res://scenes/presentation/card_direction_presenter.gd")  # Phase 27K-R1-D
const ODCompanionBacklinePresenterScene = preload("res://scenes/presentation/od_companion_backline_presenter.tscn")  # Phase 26D
const TacticalTerrainPresenterClass = preload("res://scenes/presentation/tactical_terrain_presenter.gd")
const TacticalStructurePresenterClass = preload("res://scenes/presentation/tactical_structure_presenter.gd")
const StructureInteractionPresenterScene = preload("res://ui/structure_interaction_presenter.tscn")
const TacticalGarrisonPresenterScene = preload("res://scenes/presentation/tactical_garrison_presenter.tscn")

# ============================================================
# Phase 4B-8: 闂嗗棔鑵戝?z_index 鐏炲倻楠囩敮鎼佸櫤閿涘牆鏁稉鈧弶鍐ㄢ枆閺夈儲绨敍?
# ============================================================
const ZI_TABLE_SURFACE   := 0    # 濡楀矂娼版惔鏇熸緲
const ZI_AREA_BG         := 1    # BossArea / PlayerArea 閸楀﹪鈧繑妲戦懗灞炬珯
const ZI_DEBUG_BORDER    := 2
const ZI_SLOT_EMPTY      := 3
const ZI_DROP_ZONE        := 4    # 閹锋牗鏂侀崠鍝勭厵
const ZI_FIELD_CARD      := 5    # 閸﹁桨绗?CardUI閿涘牏甯虹€?Boss 濡叉垝缍呴敍?
const ZI_ACTION_SLOT     := 8    # SPELL/INSTANT 鐞涘苯濮╃仦鏇犮仛濡?
const ZI_HAND_CARD_BASE  := 10   # 閹靛澧?CardUI 閸╄櫣顢?z閿涘牊甯撻崚妤佹鐟曞棛娲婃稉?i閿?
const ZI_HAND_CARD_HOVER := 80   # 閹靛澧?hover 閺冭埖褰侀崡?z
const ZI_BOSS_INTENT     := 50   # Boss 閹板繐娴橀崡?
const ZI_CENTER_TEXT     := 80   # 娑擃厼銇庢径褍鐡?/ EventAnnounceLabel
const ZI_END_TURN        := 100
const ZI_FLOATING_TEXT   := 150
const ZI_DETAIL_PANEL    := 200
const ZI_GRAVEYARD_VIEW  := 300
const ZI_MONSTER_MENU    := 500
const ZI_OVERLAY         := 400  # 姒涙垵绠锋潻鍥ㄦ诞 / 缂佹挾鐣婚棃銏℃緲

# Phase 19B: 3D/2D 妗岄潰瑙嗚妯″紡
# "3d_hybrid" 鈥?3D妫嬬洏鍙锛?D妲戒綅鐑尯淇濈暀锛孴ableArtRoot 浣庨€忔槑搴?# "2d_full"   鈥?鏃ц涓猴細2D妗屽竷瀹屽叏瑕嗙洊
const BOARD_VISUAL_MODE := "3d_hybrid"

# Phase 21B: 3D妗岄潰涓昏儗鏅紑鍏?# true  鈥?Battle3DViewport 鎴愪负鎴樻枟妗岄潰鐨勫彲瑙佷富鑳屾櫙
#         TableArtRoot/TableSurface/TableBorder/CenterDivider 闅愯棌
#         2D CardUI / 妲戒綅鐑尯 / 鎵嬬墝 / 鑿滃崟鍏ㄩ儴淇濈暀
# false 鈥?鍥為€€鍒版棫 2D 妗屽竷椋庢牸锛堝畨鍏ㄩ檷绾у紑鍏筹級
const USE_TRUE_3D_BOARD_BACKGROUND := true
# Phase 24B-R2-R3: 3D board mode disables legacy 2D Guide/Tutorial overlays
const ENABLE_LEGACY_GUIDES_IN_3D := false

# Phase 21C: 3D Slot Anchor 璋冭瘯鍙鍖?# true  鈥?姣忎釜 Anchor 鏄剧ず褰╄壊灏忔爣璁帮紙闈掕摑/缁?绾㈡/鏆楃孩/閾?绱級
const DEBUG_SHOW_3D_SLOT_ANCHORS := false
# Phase 21D: 3D Card Token Sync
# true  鈥?鍦轰笂鍗＄墝鍚屾涓?3D placeholder token
# false 鈥?闄嶇骇锛氫笉鍒涘缓浠讳綍 3D token
const USE_3D_CARD_TOKENS := true
# true  鈥?token 甯﹀井鍏夎嚜鍙戝厜锛屾柟渚胯倝鐪肩‘璁?# false 鈥?token 浠呮樉绀烘极鍙嶅皠棰滆壊
const DEBUG_SHOW_3D_CARD_TOKENS := true

# Phase 21E: 3D Token Click Bridge
const USE_3D_TOKEN_CLICK_BRIDGE := true
# 涓撶敤纰版挒灞?(bit 20)锛岄伩鍏嶄笌浠讳綍鐗╃悊/鍏朵粬 Area 鍐茬獊
const TOKEN_CLICK_COLLISION_LAYER := 1 << 20
const MONSTER_DRAG_INVALID_CELL := Vector2i(-1, -1)
const MONSTER_SUMMON_IDLE := &"idle"
const MONSTER_SUMMON_DRAGGING := &"dragging"
const MONSTER_SUMMON_PENDING_CONFIRM := &"pending_confirm"
const MONSTER_SUMMON_RESELECTING := &"reselecting"
const MONSTER_SUMMON_COMMITTING := &"committing"
const CARD_DRAG_FRIENDLY_ANCHOR := &"friendly_anchor_spell"
const CARD_DRAG_TRIPWIRE := &"tripwire_anchor"
const CARD_DRAG_DIRECTED_SPELL := &"directed_spell"
const CARD_DRAG_CAST_LANE := &"cast_lane"
const CARD_DRAG_FINISHER := &"finisher_cast"

# Phase 21F: Camera Orbit MVP 鈥?3D 妫嬬洏瑙嗚鎺у埗
# 鍙抽敭鎷栧姩鏃嬭浆 + 婊氳疆缂╂斁 + 3 涓璁捐瑙?# CameraRig3D 缁撴瀯锛歒aw 鈫?Pitch(+Z鈫掑墠涓婃柟) 鈫?Distance(+Z) 鈫?Camera
const USE_CAMERA_ORBIT := true
const CAMERA_ORBIT_PITCH_MIN := 20.0
const CAMERA_ORBIT_PITCH_MAX := 82.0
const CAMERA_ORBIT_DISTANCE_MIN := 7.5
const CAMERA_ORBIT_DISTANCE_MAX := 18.0
const CAMERA_ORBIT_ROT_SENSITIVITY := 0.25
const CAMERA_ORBIT_ZOOM_SENSITIVITY := 0.07
const CAMERA_ORBIT_YAW_DEFAULT := 90.0
const CAMERA_ORBIT_PITCH_DEFAULT := 56.0
const CAMERA_ORBIT_DISTANCE_DEFAULT := 11.5
# Phase 23A-V4: Middle-mouse pan sensitivity
const CAMERA_PAN_WORLD_UNITS_PER_PIXEL := 0.008
const CAMERA_PAN_DISTANCE_REFERENCE := 12.5
const CAMERA_PAN_DISTANCE_SCALE_MIN := 0.65
const CAMERA_PAN_DISTANCE_SCALE_MAX := 1.35

# Phase 21G: Hide 2D Field Cards 鈥?鍦轰笂鍗＄墝浠呴€氳繃 3D token 鏄剧ず
# true  鈥?2D CardUI 鍦轰笂鍗′繚鎸佸彲瑙侊紙鏃ц涓猴紝瀹夊叏闄嶇骇锛?# false 鈥?闅愯棌 2D 鍦轰笂 CardUI + SlotPanel锛屽畬鍏ㄤ緷璧?3D token 浜や簰
const SHOW_2D_FIELD_CARDS := false


# Phase 24B-R2-R2: debug diagnostic flag — off by default; set true to dump visible Control tree
const DEBUG_DIAG_VISIBLE_CONTROLS := false
# Phase 22A: Real Board GLB Runtime Hook
# true  鈥?浠?GLB 鍔犺浇鐪熷疄 3D 妫嬬洏妯″瀷锛屾浛鎹㈢▼搴忓寲 _build_3d_table_model()
# false 鈥?濮嬬粓浣跨敤绋嬪簭鍖栨鐩橈紙瀹夊叏闄嶇骇寮€鍏筹級
const USE_GLB_BOARD := true
const BOARD_GLB_PATH := "res://assets/table/3d/cloudgate_battle_board_v03.glb"

# Phase 22B: BoardSpace3D 鈥?缁熶竴鍧愭爣绌洪棿鍙樻崲
# 鎵€鏈夋鐩樼浉鍏宠妭鐐?(BoardRoot3D, SlotAnchors3D, CardTokenRoot3D) 閮芥槸 BoardSpace3D 鐨勫瓙鑺傜偣
# 璋冩暣杩欎簺甯搁噺鍙悓姝ョЩ鍔?缂╂斁/鏃嬭浆鏁翠釜鍙帺鍖哄煙
const BOARD_SPACE_POSITION := Vector3(0.0, 0.0, 0.0)
const BOARD_SPACE_SCALE := Vector3(1.0, 1.0, 1.0)
const BOARD_SPACE_ROTATION_DEGREES := Vector3(0.0, 0.0, 0.0)

const BOARD_PLAY_SURFACE_Y := 0.50

# Phase 22C: CloudGate Board Runtime 鈥?Marker3D Socket 鏉冨▉鏉ユ簮
const BOARD_RUNTIME_SCENE_PATH := "res://scenes/battle/cloudgate_board_runtime.tscn"
# Phase 22D: MODEL_PIVOT_YAW_DEGREES 鐢?CloudGateBoardRuntime.get_model_yaw() 鏉冨▉鎻愪緵
const USE_RUNTIME_BOARD_SCENE := true

# Phase 22E-1: CardCarrier3D token integration
const CARD_CARRIER_SCENE_PATH := "res://scenes/presentation/card_carrier_3d.tscn"
const CARRIER_SCALE_FRONT := 0.54
const CARRIER_SCALE_BACK := 0.48
# Phase 23C0: Carrier grounding uses board surface + carrier AABB bottom computation.
# The old CARRIER_Y_SURFACE is deprecated 鈥?Y offset is now computed per-carrier.
const CARRIER_Y_SURFACE := 0.010  # DEPRECATED: kept for fallback compatibility
## Phase 22F-5R: Token slot mapping 璇婃柇鏃ュ織锛堜粎鍦ㄦ槧灏勫彉鍖栨椂杈撳嚭锛?const DEBUG_TOKEN_SLOT_MAP := false

# ============================================================
# 閺嶇绺剧化鑽ょ埠瀵洜鏁?# ============================================================
var context: BattleContext
var battle: BattleSystem
var turn: TurnManager
var fx: Node2D
var boss_deck = null  # BossCardDeck v2.0 MVP
var action_feed: ActionFeed = null
var boss_card_presenter: BossCardPresenter = null
var boss_intent_card: CardUI = null  # 閹镐椒绠欓崠?Boss 閹板繐娴橀崡?
var boss_reaction_fx: BossReactionFX = null
# Phase 10D: VFX Controller Foundation
var card_vfx: CardVFXController = null
var battle_vfx: BattleVFXController = null
# Phase 24C-A: Monster Combat Presentation
var monster_combat_presenter: Node = null
var spell_activation_presenter: Node = null  # Phase 26B-T6
var _battle_presentation_director = null  # Phase 27K-R1-B: read-only choreography owner
var _card_direction_presenter: Node = null  # Phase 27K-R1-D: non-authoritative visual adapter
var _combat_presentation_profile: RefCounted = null
var _presentation_end_turn_blocked := false
# Phase 11A: Playtest Telemetry
var _playtest: PlaytestTelemetry = null
# Phase 27H-R0: explicit reproducible seed metadata
var _phase27h_style_id: String = "unclassified"
var _phase27h_seed: int = -1
var _phase27h_run_label: String = ""
var _board_piece_registry = null
# Phase 21D: 3D Card Token Sync
var _card_token_root_3d: Node3D = null
var _combat_vfx_root: Control = null  # Phase 26B-T4: full-screen VFX overlay
var _card_token_nodes: Dictionary = {}
var _last_3d_token_count: int = -1
var _last_slot_maps: Dictionary = {}  # Phase 22F-5R: track last slot maps
var _center_text_active := false
var _enemy_od_before_card: int = 0
var _boss_status_hud: Node = null  # Phase 24A (BossStatusHUD)

var _hint_panel: Panel = null
var _hint_click_area: Control = null
var _hint_nodes_to_free: Array = []

# 閳光偓閳光偓 閹存ɑ鏋熼崷鐑樻珯缁狙呯波閺夌喎娲栭崥鍫熷瘻闁?閳光偓閳光偓
var _end_turn_btn: Button = null  # [Phase 27D-R5-R2] deprecated — replaced by _end_turn_control
var _end_turn_control = null  # EndTurnControl (Phase 27D-R5-R2)
var _od_release_control: Control = null
var _od_engine_greybox: Control = null  # Phase 27K-R0
var _od_presentation_profile: RefCounted = null  # Phase 27K-R0
var _od_greybox_release_event_hooked := false  # Phase 27K-R0
var _od_release_context: Dictionary = {
	"active": false,
	"stage": &"",
	"source": null,
	"source_status": {},
	"final_convergence": false,
}
var _od_release_transaction_serial: int = 0
var _od_release_presentation_facts_by_tx: Dictionary = {}  # Phase 27K-R1-B: view-only projection metadata

# ============================================================
# PlayerTable 鐎圭偘绶?# ============================================================
var player_table: PlayerTable
var enemy_table: PlayerTable
var layout_manager: TableLayoutManager

# ============================================================
# 閻樿埖鈧?
# ============================================================
var card_board_position: Vector2

# ============================================================
# 閹存ɑ鏋熺紒鎾存将
# ============================================================
var battle_ended: bool = false
var _card_being_played: bool = false
var _spell_end_turn_blocked: bool = false  # Phase 27C-R1: spell activation blocks End Turn
# Phase 26E-R1: manual lane selection state
const LANE_SELECT_NONE: StringName = &"none"
const LANE_SELECT_SUMMON: StringName = &"summon"
const LANE_SELECT_MOVE: StringName = &"move"
const LANE_SELECT_ATTACK: StringName = &"attack"
const LANE_SELECT_REDEPLOY: StringName = &"redeploy"
const LANE_SELECT_SKILL: StringName = &"skill"  # Phase 27E-R2
var _lane_selection_mode: StringName = LANE_SELECT_NONE
# Phase 27B: pending attack target state
var _pending_attack_card: CardData = null
var _pending_attack_cells: Array[Vector2i] = []
var _lane_selection_card: CardData = null
var _lane_selection_card_ui_ref = null
var _lane_selection_source: StringName = &""
var _lane_selection_zone: String = ""
var _lane_selection_legal: Array[int] = []
# Phase 27A-R1: cell-based summon legal list
var _cell_selection_legal: Array[Vector2i] = []
# Phase 27E-R2: skill targeting state
var _skill_context: Dictionary = {
	"active": false,
	"caster": null,
	"skill_id": "",
	"target_mode": "",
	"legal_cells": [],
	"legal_targets": [],
	"can_target_boss_core": false
}
# Phase 27I-R0: 棋子选择短生命周期上下文（不保存权威费用/合法格副本作为结算依据）
var _piece_context: Dictionary = {
	"active": false,
	"card": null,
	"card_ui": null,
	"action_id": &"",
	"stage": &"",
	"anchor": null,
	"target": null,
	"enhanced_requested": false,
	"payment_mode": &"none",
}
var _tactical_presenter: Node3D = null  # TacticalMovementPresenter
@onready var _monster_summon_drop_target: Control = $MonsterSummonDropLayer/MonsterSummonDropTarget
@onready var _monster_summon_interaction_presenter: Control = $MonsterSummonConfirmationLayer/MonsterSummonInteractionPresenter
var _structure_interaction_presenter: Control = null
var _monster_drag_session: Dictionary = {}
var _card_cast_area_preview_fact: Dictionary = {}
var _monster_drag_generation := 0
var _monster_drag_commit_count := 0
var _monster_drag_last_drop_screen_position := Vector2.INF
var _monster_drag_last_cleanup_reason: StringName = &""
var _structure_drag_last_commit_had_structure_fact := false
var _monster_summon_end_turn_body_entry_count := 0
# Phase 27A-R1: 5×5 grid cell anchors and presentation profile
var _tactical_grid_presentation_profile: RefCounted = null
var _grid_cell_anchor_root: Node3D = null
var _grid_cell_anchors: Dictionary = {}
var _tactical_terrain_presenter: TacticalTerrainPresenter = null
var _tactical_terrain_authority: RefCounted = null
var _tactical_structure_presenter: TacticalStructurePresenter = null
var _tactical_structure_authority: RefCounted = null
var _tactical_structure_presentation_profile: RefCounted = null
var _tactical_garrison_presenter: Node3D = null
var _garrison_context: Dictionary = {
	"active": false,
	"mode": &"none",
	"stage": &"idle",
	"unit": null,
	"candidates": [],
	"pending_status": {},
	"generation": 0,
}
var _garrison_detail_was_visible := false
var _garrison_detail_was_pinned := false
# Phase 27I-R0-R4: P01 友方锚点反馈——只读高亮（无碰撞/无输入），以及持续操作提示
var _piece_anchor_highlights: Dictionary = {}
var _piece_anchor_hint_label: Label = null
var result_panel: BattleResultPanel = null
# Phase 10A: 閹亜鍚旈弨璇插毊闁瀚ㄩ悩鑸碘偓?
var _selected_attacker: CardData = null
var _selected_attacker_slot: Control = null
var _attack_targeting_banner: Label = null  # Phase 27D-R3
# Phase 10B: OD 鐏炲倽绐￠煪顏庣礄閻劋绨Σ鎴掔秴鐟欙綁鏀ｉ崣宥夘洯閿?
var _last_player_engine_layer: int = 1
# Phase 10F: Engine Gauge VFX 閸婄厧褰夐崠鏍嫹闊亷绱欓柆鍨帳闁插秴顦茬憴锕€褰傞敍?
var _last_eg_layer_for_vfx: int = 0
var _last_eg_charge_for_vfx: int = 0
var _last_eg_depth_for_vfx: int = 0
var _last_eg_burst_turns_for_vfx: int = 0
var _eg_vfx_initialized := false
var _boss_od_warn_7 := false
var _boss_overdrive_announced := false  # Phase 27F: dedup BOSS OVERDRIVE major event
var _last_boss_od: int = 0
var _last_boss_trap_count: int = 0
var _prev_od: int = 0
var _prev_depth: int = 0
var _chain_reward_granted_routes: Dictionary = {}

# Phase 4C-4B: ThisTurn 闂堛垺婢?閳?閺堫剙娲栭崥鍫㈠负鐎规儼顢戦崝銊唶瑜?
var _this_turn_panel: Panel = null
var _this_turn_title: Label = null
var _this_turn_labels: Array[Label] = []
const THIS_TURN_MAX_LINES := 5  # Phase 17B: capped at 5 for readability
const THIS_TURN_FONT_SIZE := 10

var _core_status_panel: Panel = null
# Phase 26C: 核心指令面板
var _core_command_panel = null  # ODCoreCommandPanel
var _core_command_button: Button = null
var _command_economy_hud: Control = null  # CommandEconomyHUD (Phase 27D-R3)
var _attack_hover_line: Control = null  # Phase 27D-R4: hover line during attack targeting
var _hover_line_from: Vector2 = Vector2.ZERO
var _hover_line_to: Vector2 = Vector2.ZERO
var _hover_line_color: Color = Color.TRANSPARENT
var _hover_line_frame: int = 0
var _core_od_label: Label = null
var _core_load_label: Label = null
var _core_depth_label: Label = null
var _core_od_segments: Array[ColorRect] = []
var _engine_gauge_labels: Array[Label] = []
var _engine_gauge_progress_bars: Array[ColorRect] = []
var _engine_gauge_status_labels: Array[Label] = []
var _engine_gauge_od_label: Label = null
var _engine_gauge_load_label: Label = null
var _engine_gauge_depth_label: Label = null
var _engine_gauge_burst_label: Label = null
var _engine_gauge_pulse_tween: Tween = null

var _detail_panel_slot: Control = null
var _detail_panel_compact_label: Label = null

# Phase 26D: OD 伙伴后场
var _od_backline_presenter: Node3D = null
var _od_companion_presentation_profile: RefCounted = null
var _od_backline_last_snapshot: Dictionary = {}
var _detail_panel_expanded := false
var _detail_panel_hovered := false
var _detail_panel_pinned_layout := false
var _development_showcase_mode := false
var _development_showcase_reduced_motion := false
var _detail_panel_compact_rect := Rect2(Vector2(1114, 300), Vector2(270, 360))
var _detail_panel_expanded_rect := Rect2(Vector2(1094, 140), Vector2(290, 520))

var _od_delta_label: Label = null
var _depth_delta_label: Label = null

# ============================================================
# 閹存ɑ鏋熺紒鐔活吀閿涘牅绶电紒鎾剁暬闂堛垺婢橀弰鍓с仛閿?
# ============================================================
var _stat_max_player_od: int = 0
var _stat_entered_overdrive: bool = false
var _stat_released_finisher: bool = false
var _stat_chain_completed: int = 0
var _stat_max_boss_od: int = 0
var _stat_max_combo: int = 0
var _stat_total_cards: int = 0
var _stat_max_hit: int = 0
var _stat_player_max_hp_lost: int = 0
var _stat_trap_triggered: int = 0
var _stat_boss_overdrive_count: int = 0
var _stat_boss_interrupted: int = 0
var _finisher_ready_toast_shown := false

# ============================================================
# Toast 閸樺鍣搁敍鍫ヮ浕闁洦褰佺粈鐚寸礆
# ============================================================
var _toast_shown: Dictionary = {}

# Phase 27D-R5-R2-R2: notification stacking tracker
var _last_notification_rect: Rect2 = Rect2()
var _notification_stack_count: int = 0

# ============================================================
# 瀵洖顕辩化鑽ょ埠
# ============================================================
var _guides_enabled: bool = true
var _guide_skip_btn: Button = null

## 瀵洖顕辩憴锕€褰傞敍鍫濆涧閺勫墽銇氭稉鈧▎鈽呯礉閸欘垵鐑︽潻鍥风礆
func _show_guide(key: String, text: String, color: Color = TC.TEXT_PRIMARY) -> void:
	if not _guides_enabled:
		return
	if _toast_shown.get("guide_" + key, false):
		return
	_toast_shown["guide_" + key] = true
	_show_floating_text(text, color, 2.0, 20)

# ============================================================
# @onready 閼哄倻鍋?# ============================================================
@onready var turn_info_label: Label = $BattleTable/CenterLine/TurnInfoLabel
@onready var boss_intent_label: Label = null  # Phase 4B-6: Boss閹板繐娴橀弫鏉戞値閸掔檱ossArea
@onready var boss_intent_slot: Control = $BattleTable/BossArea  # Phase 4B-6: BossArea閹佃儻娴囬幇蹇撴禈閸?
@onready var event_announce_label: Label = $BattleTable/CenterLine/EventAnnounceLabel
@onready var enemy_slot: Control = $BattleTable/BossArea
@onready var player_slot: Control = $BattleTable/PlayerArea
# Phase 4B-6: RightTrack deck/gy count labels
var _boss_deck_label: Label = null
var _player_deck_label: Label = null

# Phase 4B-6D: 閸欏厖鏅?GY 娴溿倓绨伴棃銏℃緲
var _boss_gy_panel: Panel = null
var _player_gy_panel: Panel = null
var _boss_gy_last_label: Label = null
var _player_gy_last_label: Label = null
var _gy_hover_card_data: CardData = null  # 瑜版挸澧犻幃顒€浠犵仦鏇犮仛閻ㄥ嫬顣搁崷鏉垮幢

var _graveyard_view: GraveyardView = null

# Phase 4B-8: 鐠嬪啳鐦鈧崗绛圭礄缂傛牞绶崳銊ュ讲閸掑洦宕查敍宀冪箥鐞涘本妞傛妯款吇閸忔娊妫撮敍?
@export var _debug_borders_enabled := false

# Phase 4B-6C: Avatar HUD elements
var _boss_hud_hp: Label = null
var _boss_hud_od: Label = null
var _player_hud_hp: Label = null
var _player_hud_od: Label = null
var _player_hud_depth: Label = null

var _major_event_tween: Tween = null
var _boss_intent_tween: Tween = null  # Phase 8B: Boss intent danger pulse tween
var _boss_core_light_tween: Tween = null   # Phase 7A-0B: BossCore 閸忓鍓﹂崘?tween 瀵洜鏁ら敍宀勬Щ閺冪娀妾哄顏嗗箚
var _boss_core_root_tween: Tween = null
var _boss_core_visual: Control = null
var _boss_core_ring: ColorRect = null
var _boss_core_eye: ColorRect = null
var _boss_core_glow: ColorRect = null
var _boss_core_hp_label: Label = null
var _boss_core_od_label: Label = null
var _boss_core_name_label: Label = null
var _boss_core_pulse_tween: Tween = null
var _boss_intro_played := false
# Phase 13D: Arsenal Panel
var _arsenal_panel = null  # ArsenalPanel (Phase 13D)
var _arsenal_hints_shown: Dictionary = {}
var _monster_command_menu = null  # MonsterCommandMenu (Phase 15B)
var _monster_command_layer: CanvasLayer = null
var _monster_command_card: CardData = null

# Phase 21F: Camera Orbit state
var _camera_orbit_frozen := false     # 鑿滃崟鎵撳紑鏃跺畾鏍兼憚鍍忔満
var _camera_yaw := CAMERA_ORBIT_YAW_DEFAULT
var _camera_pitch := CAMERA_ORBIT_PITCH_DEFAULT
var _camera_distance := CAMERA_ORBIT_DISTANCE_DEFAULT
var _camera_orbit_dragging := false   # 鍙抽敭鎷栨嫿涓?# Phase 23A-V4: middle-mouse pan dragging
var _camera_pan_dragging := false
var _camera_drag_start: Vector2 = Vector2.ZERO
var _camera_drag_start_yaw: float = 0.0
var _camera_drag_start_pitch: float = 0.0
# Phase 23A-V3: View Controls state
var _camera_state: BattleViewCameraState = null
var _view_controls: BattleViewControls = null
var _camera_tween: Tween = null
var _camera_rig_origin: Vector3 = Vector3.ZERO
var _camera_free_view_enabled := false
var _exit_modal_active := false
var _return_to_menu_guard := false
var _elevated_grid_endpoint_facts: Dictionary = {}
var _terrain_refit_generation := 0
var _terrain_refit_preset: StringName = &""
var _terrain_refit_target_snapshot: Dictionary = {}
var _glb_board_loaded := false
const BoardRuntimeClass = preload("res://scenes/battle/cloudgate_board_runtime.gd")
# Phase 22E-1: CardCarrier3D scene preload
const CardCarrierScene = preload("res://scenes/presentation/card_carrier_3d.tscn")
var _board_runtime = null  # Phase 22C: CloudGateBoardRuntime 寮曠敤 (class_name 渚濊禆 UID锛岀敤 preload 瑙勯伩)

# ============================================================
# 閻㈢喎鎳￠崨銊︽埂
# ============================================================
func _ready() -> void:
	_ensure_structure_interaction_presenter()
	# 0. 鏉╂稑鍙嗘鎴濈
	var enter_overlay: ColorRect = _create_enter_overlay()

	# 0.5. 3D 閻楀本顢戦懗灞炬珯
	_setup_3d_stage()

	# Phase 24B-R4: Disable legacy Guide/Tutorial controls in 3D board mode.
	# Keep the short center floating guide queue; it is lightweight combat feedback.
	if USE_TRUE_3D_BOARD_BACKGROUND and not ENABLE_LEGACY_GUIDES_IN_3D:
		print("[3D_BOARD] Legacy Guide/Tutorial controls disabled for 3D board mode")

	# Phase 24B-R2-R3: Root-level dark background behind 3D viewport
	_create_root_background()
	_purge_legacy_guide_controls()

	# Phase 23A-V3: Instantiate view controls + camera state
	_instantiate_view_controls()
	_cache_camera_rig_origin()

	# Phase 4B-5B: 娑擃厼銇庢径褍鐡?20px閿涘瞼鐓弳鍌氬毉閻滃府绱濇稉濠勑╅柆鍨帳闁喗灏呴崷杞扮瑐閸?
	if event_announce_label:
		event_announce_label.add_theme_font_size_override("font_size", 18)
		event_announce_label.z_index = ZI_CENTER_TEXT  # 80
		event_announce_label.modulate.a = 0.88  # Phase 9B: 閸楀﹪鈧繑妲戦柆鍨帳鐎瑰苯鍙忛柆顔藉皡閸﹁桨绗傞崡?

	# BattleFX layer
	fx = BattleFXClass.new()
	$BattleFX.add_child(fx)

	# Phase 10D: VFX Controller Foundation
	card_vfx = CardVFXControllerClass.new()
	card_vfx.name = "CardVFXController"
	add_child(card_vfx)
	battle_vfx = BattleVFXControllerClass.new()
	battle_vfx.name = "BattleVFXController"
	add_child(battle_vfx)

	# Phase 24C-A: Monster Combat Presentation
	monster_combat_presenter = MonsterCombatPresenterClass.new()
	monster_combat_presenter.name = "MonsterCombatPresenter"
	add_child(monster_combat_presenter)
	if monster_combat_presenter.has_method("setup"):
		monster_combat_presenter.setup(self, battle_vfx, card_vfx)

	# Phase 26B-T6: Spell Activation Presentation
	spell_activation_presenter = SpellActivationPresenterClass.new()
	spell_activation_presenter.name = "SpellActivationPresenter"
	add_child(spell_activation_presenter)
	if spell_activation_presenter.has_method("setup"):
		spell_activation_presenter.setup(self)
	# Phase 27C Task 3-R: connect End Turn block callback
	if spell_activation_presenter.has_method("end_turn_block_callback") or "end_turn_block_callback" in spell_activation_presenter:
		spell_activation_presenter.end_turn_block_callback = Callable(self, "_on_spell_end_turn_blocked")

	# Boss presentation layer
	boss_card_presenter = BossCardPresenterClass.new()
	boss_card_presenter.name = "BossCardPresenter"
	add_child(boss_card_presenter)

	boss_reaction_fx = BossReactionFXClass.new()
	boss_reaction_fx.name = "BossReactionFX"
	add_child(boss_reaction_fx)

	# Phase 4B-8: RightTrack clip_contents
	var right_track := get_node_or_null(NodePath("RightTrack"))
	if right_track:
		right_track.clip_contents = true

	# 1.3. ActionFeed — Phase 27D-R5-R2-R3: migrate to BattleFX/ActionFeedSafeLane
	_ensure_action_feed_safe_lane()
	var feed_instance: Node = ActionFeedScene.instantiate()
	action_feed = feed_instance as ActionFeed
	if action_feed != null:
		action_feed.set_anchors_preset(Control.PRESET_FULL_RECT)
		action_feed.clip_contents = true
		var safe_lane := get_node_or_null(NodePath("BattleFX/ActionFeedSafeLane")) as Control
		if safe_lane and is_instance_valid(safe_lane):
			safe_lane.add_child(action_feed)

	# Phase 27D-R5-R2-R3: hide old ActionFeedSlot
	var feed_slot: Node = get_node_or_null(NodePath("RightTrack/ActionFeedSlot"))
	if feed_slot != null and feed_slot is Control:
		(feed_slot as Control).visible = false
		feed_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Phase 10C: ActionFeed hover — now on SafeLane
	var safe_lane_hover := get_node_or_null(NodePath("BattleFX/ActionFeedSafeLane")) as Control
	if safe_lane_hover and is_instance_valid(safe_lane_hover):
		if not safe_lane_hover.mouse_entered.is_connected(_on_action_feed_hovered):
			safe_lane_hover.mouse_entered.connect(_on_action_feed_hovered)
		if not safe_lane_hover.mouse_exited.is_connected(_on_action_feed_unhovered):
			safe_lane_hover.mouse_exited.connect(_on_action_feed_unhovered)
	# Phase 4C-4B: ThisTurn panel
	_setup_this_turn_panel()
	_setup_core_status_panel()
	_setup_od_release_control()
	_setup_detail_panel_compact()
	# 1.5. 闂婃娊顣?閳?閸掑洦鍨弬?BGM
	var am: Node = _am()
	if am != null:
		am.play_battle_bgm()

	# 2. 濞撳憡鍨欓弽绋跨妇
	_setup_game()
	_ensure_tactical_terrain_presenter()
	_ensure_tactical_structure_presenter()
	_ensure_tactical_garrison_presenter()
	_setup_boss_status_hud()  # Phase 24A: bind HUD after context + enemy exist

	# 3. Setup battle tables and hand/field UI
	_setup_tables()
	_sync_3d_viewport_to_table()
	# 3.5. Create end turn button
	_create_end_turn_button()

	# Phase 10G: Create BossCoreVisual 2D
	_create_boss_core_visual()

	# Phase 12F: 濡楀矂娼伴懗浠嬪櫤缁?閳?鐠愭挳妾宀勬桨閻ㄥ嫭婧€濮婄増鍔呴懗鑺ョ爱缁?
	_create_table_energy_lines()

	# Phase 13D: Create Arsenal Preview Panel

	# Phase 18A: AnimatedODGauge removed 鈥?CoreStatusPanel EngineGauge is authoritative
	_setup_arsenal_panel()
	# Phase 27I-R0-R2: viewport 改变时重新同步左侧栏（详情栏与 Arsenal 互斥）
	if get_viewport() and not get_viewport().size_changed.is_connected(_sync_left_rail_layout):
		get_viewport().size_changed.connect(_sync_left_rail_layout)
	if get_viewport() and not get_viewport().size_changed.is_connected(_sync_structure_interaction_safe_area):
		get_viewport().size_changed.connect(_sync_structure_interaction_safe_area)

	# 3.6. Phase 4B-6D: 鏉╂劘顢戞稉鈧▎?CardUI 瑜版帒鐫樼€孤ゎ吀閿涘潐ebug閿?
	_audit_card_ui_ownership()

	# Phase 14B-1: Create TableArtRoot
	_setup_table_art_root()
	# 4. Setup player and enemy decks
	_setup_deck()

	# 5. 瀵偓鐏炩偓
	card_board_position = get_viewport_rect().size / 2.0
	_start_player_turn_rules(true)
	# Phase 27H-R0: parse explicit debug args before telemetry
	_phase27h_style_id = "unclassified"
	_phase27h_seed = -1
	_phase27h_run_label = ""
	var _p27h_args: PackedStringArray = OS.get_cmdline_user_args()
	for _p27h_arg in _p27h_args:
		if _p27h_arg.begins_with("--phase27h-style="):
			var _p27h_val: String = _p27h_arg.trim_prefix("--phase27h-style=")
			if _p27h_val in ["heat_burst", "control", "hero_synergy"]:
				_phase27h_style_id = _p27h_val
		elif _p27h_arg.begins_with("--phase27h-seed="):
			_phase27h_seed = int(_p27h_arg.trim_prefix("--phase27h-seed="))
		elif _p27h_arg.begins_with("--phase27h-label="):
			_phase27h_run_label = _p27h_arg.trim_prefix("--phase27h-label=")

	# Phase 11A: Playtest Telemetry 閳?閸氼垰濮╅張顒€鐪拋鏉跨秿
	_playtest = PlaytestTelemetryClass.new()
	_playtest.start_run(_phase27h_style_id, _phase27h_seed, _phase27h_run_label)
	_connect_od_feedback_telemetry()
	_playtest.record_turn_snapshot("player", context, battle)
	_announce_major_event("YOUR TURN", TC.TEXT_PRIMARY, 0.8)
	# Phase 11C: 瀵偓鐏炩偓閺佹瑧鈻奸幓鎰仛
	_show_tutorial_hint_once("opening", "建立战线：打出怪兽或建筑，推动OD引擎升级。Boss已全槽在线，你需要逐步解锁前场。")
	print("[STARTUP_DECK] before draw deck=%d hand=%d gy=%d" % [
			context.player.deck.size(),
			context.player.hand.size(),
			context.player.graveyard.size()
		])
	# Phase 25A: 起手手牌数从配置表读取
	var start_hand := GameCfg.get_starting_hand_size()
	print("[STARTUP_DECK] before draw deck=%d hand=%d gy=%d" % [
			context.player.deck.size(),
			context.player.hand.size(),
			context.player.graveyard.size()
		])
	context.player.draw(start_hand)
	_refresh_tables()
	# 閻溾晛顔嶉崶鐐叉値閿涙碍妯夌粈铏圭波閺夌喎娲栭崥鍫熷瘻闁?
	# Phase 27D-R5-R2-R: only show fallback button if new control is absent
	if _end_turn_control and is_instance_valid(_end_turn_control):
		_end_turn_control.visible = true
		_end_turn_control.set_busy(false, "")
		_end_turn_control.refresh()
	elif _end_turn_btn:
		_end_turn_btn.visible = true
		_end_turn_btn.disabled = false
		_end_turn_btn.mouse_filter = Control.MOUSE_FILTER_STOP  # Phase 27D-R5-R2-R: emergency fallback only

	# 6. 鏉╂稑鍙嗗鏂垮毉
	_play_enter_animation(enter_overlay)

	# 6.5. Boss 閸掓繂顫愰幇蹇撴禈
	if context.enemy != null:
		context.enemy.intent_text = "Warming up..."
		context.enemy.intent_color = TC.ZONE_CALM

	# Delayed battle hint
	await get_tree().create_timer(1.2).timeout
	_show_battle_hint()
	_create_guide_skip_btn()
	_purge_legacy_guide_controls()
	# Phase 24B-R2-R2: diagnostic controlled by DEBUG_DIAG_VISIBLE_CONTROLS flag
	if DEBUG_DIAG_VISIBLE_CONTROLS:
		call_deferred("_diagnose_visible_controls")
func _process(_delta: float) -> void:
	# PHASE53_BEGIN_PROCESS
	if _core_surge_selecting and (not _core_surge_window_open() or context.turn_count!=_core_surge_turn):_clear_core_surge_selection()
	# PHASE53_END_PROCESS
	_release_idle_end_turn_busy()
	if _monster_drag_session.get("intent") == &"siege_attack":
		var actor: CardData = _monster_drag_session.get("card")
		if actor == null or context == null or not actor in context.player.field:
			_cancel_monster_summon_interaction(&"source_gone")
	_update_siege_screen_geometry()
	if _is_monster_summon_interaction_active() and _monster_drag_session.get("intent") != &"siege_attack":
		var source_ref: WeakRef = _monster_drag_session.get("card_ui_ref", null) as WeakRef
		if source_ref == null or source_ref.get_ref() == null:
			_cancel_monster_summon_interaction(&"source_freed")
	_sync_detail_panel_compact()
	_update_attack_hover_line()  # Phase 27D-R4


func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cancel_monster_summon_interaction(&"focus_lost")
func _create_enter_overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 1)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	return overlay

func _play_enter_animation(overlay: ColorRect) -> void:
	if not is_instance_valid(enemy_slot) or not is_instance_valid(player_slot):
		return

	var enemy_target := enemy_slot.position
	var player_target := player_slot.position

	# 閺佸本鏌熼悧灞绢攽娴犲簼绗傞弬鐟板毉閻?
	enemy_slot.position.y -= 300
	enemy_slot.modulate.a = 0.2

	# 閻溾晛顔嶉悧灞绢攽娴犲簼绗呴弬鐟板毉閻?
	player_slot.position.y += 300
	player_slot.modulate.a = 0.2

	# 楠炴儼顢戦崝銊ф暰
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(overlay, "color:a", 0.0, 0.6)
	t.tween_property(enemy_slot, "position", enemy_target, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(player_slot, "position", player_target, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(enemy_slot, "modulate:a", 1.0, 0.4)
	t.tween_property(player_slot, "modulate:a", 1.0, 0.4)

	# 濞撳懘娅?overlay
	var t2 := create_tween()
	t2.tween_interval(0.7)
	t2.tween_callback(overlay.queue_free)

# ============================================================
# 濞撳憡鍨欓弽绋跨妇閸掓繂顫愰崠鏍电礄娑?main.gd 鐎瑰苯鍙忔稉鈧懛杈剧礆
# ============================================================
func _get_battle_encounter() -> Dictionary:
	return GameCfg.get_encounter("forge_guard_demo").duplicate(true)


func _create_battle_system() -> BattleSystem:
	return BattleSystemClass.new()

func _setup_game() -> void:
	context = BattleContext.new()
	# Phase 25B: 创建并注入规则快照
	var battle_rules = GameCfg.create_battle_rule_snapshot()
	context.configure_rules(battle_rules)
	add_child(context)
	# Phase 27K-R1-A: configure the read-only feedback ledger after ODMode exists.
	context.configure_od_flow_feedback(GameCfg.create_od_flow_feedback_snapshot())

	# Phase 25A: 使用 GameConfig 配置表设置初始值
	var cfg_player_hp := GameCfg.get_player_start_hp()
	var cfg_encounter := _get_battle_encounter()
	var cfg_boss_hp: int = cfg_encounter.get("boss_start_hp", 85)
	var cfg_boss_name_key: String = cfg_encounter.get("boss_name_key", "")
	var cfg_boss_name: String = GameCfg.text(cfg_boss_name_key, "熔炉守卫")

	var player_obj := Player.new()
	player_obj.hp = cfg_player_hp
	var enemy_obj := Enemy.new()
	enemy_obj.player_name = cfg_boss_name
	enemy_obj.max_hp = cfg_boss_hp
	enemy_obj.set_hp_authoritative(cfg_boss_hp, "Battle Setup")
	context.player = player_obj
	context.enemy = enemy_obj

	# Phase 27H-R0: 用 encounter JSON 的 phase_locks 覆盖旧常量
	context.configure_encounter_rules(cfg_encounter)

	# Phase 25B-R1: bind Player OD callback to context.change_od
	player_obj.od_change_request_callback = Callable(context, "change_od")

	# 鐏?Player/Enemy 閸旂姴鍙嗛崷鐑樻珯閺嶆埊绱濈涵顔荤箽 enemy.act() 娑?get_parent() 閸欘垳鏁?	add_child(player_obj)
	add_child(player_obj)
	add_child(enemy_obj)

	battle = _create_battle_system()
	battle.init(context)
	# Phase 25D: 注入怪兽战斗规则快照（每场战斗一次）
	var monster_combat_rules = GameCfg.create_monster_combat_rule_snapshot()
	battle.configure_monster_combat_rules(monster_combat_rules)
	# Phase 27A: inject tactical grid rules
	var tactical_grid_snapshot = GameCfg.create_tactical_grid_rule_snapshot()
	battle.configure_tactical_grid_rules(tactical_grid_snapshot)
	# Phase 27B: inject tactical unit pattern snapshot
	var pattern_snapshot = GameCfg.create_tactical_unit_pattern_snapshot()
	battle.configure_tactical_unit_patterns(pattern_snapshot)
	# Phase 27D: 注入共享指令经济配置快照
	var command_economy_snapshot = GameCfg.create_tactical_command_economy_snapshot()
	if command_economy_snapshot != null:
		battle.configure_tactical_command_economy(command_economy_snapshot)
	# Phase 27A-R1: store presentation profile for tactical grid overlay
	_tactical_grid_presentation_profile = GameCfg.create_tactical_grid_presentation_profile()
	# Phase 26C: 注入核心指令规则快照
	var core_command_snapshot = GameCfg.create_od_core_command_rule_snapshot()
	if core_command_snapshot != null:
		battle.configure_od_core_commands(core_command_snapshot)
	# Phase 27F: inject Boss tactical AI profile
	var boss_ai_profile = GameCfg.create_boss_tactical_ai_profile()
	if boss_ai_profile != null:
		battle.configure_boss_tactical_ai(boss_ai_profile)
	# Phase 27I-R0-R: 注入棋子身份快照（此前 battle_scene 未配置 → 真实战斗入口无法进入棋子状态机）
	var piece_snapshot = GameCfg.create_card_piece_trait_snapshot()
	if piece_snapshot != null:
		battle.configure_card_piece_traits(piece_snapshot)
	# Elevated Grid Phase C: immutable construction rules are injected once;
	# presenters receive copied preview/commit facts only.
	var structure_snapshot = GameCfg.create_tactical_structure_rule_snapshot()
	if structure_snapshot != null:
		battle.configure_tactical_structure_rules(structure_snapshot)
	# Elevated Grid Phase D1: immutable garrison eligibility/slot overlay.
	var garrison_snapshot = GameCfg.create_tactical_garrison_rule_snapshot()
	if garrison_snapshot != null:
		battle.configure_tactical_garrison_rules(garrison_snapshot)
	var release_snapshot = GameCfg.create_od_release_rule_snapshot()
	if release_snapshot != null:
		battle.configure_od_release_rules(release_snapshot)
	# Phase 26D: 创建只读 OD 伙伴表现配置快照（不可变，战斗范围）
	_od_companion_presentation_profile = GameCfg.create_od_companion_presentation_profile()
	add_child(battle)

	turn = TurnManagerClass.new()
	turn.context = context
	add_child(turn)

	# Boss Card Deck v2.0 MVP
	var boss_deck_id: String = GameCfg.get_encounter_field("forge_guard_demo", "boss_deck_id", "forge_guard_deck")
	var boss_deck_config: Dictionary = GameCfg.get_boss_deck(boss_deck_id)
	boss_deck = BossCardDeckClass.new()
	boss_deck.setup(context, boss_deck_config, _phase27h_seed)
	boss_deck.battle_system = battle
	context.boss_deck = boss_deck
	context.enemy.boss_deck = boss_deck

	# Boss presentation signal connections
	boss_deck.intent_updated.connect(_on_boss_intent_updated)
	boss_deck.boss_reaction_triggered.connect(_on_boss_reaction_triggered)
	add_child(boss_deck)

	# Player OD full presentation hook.
	context.player.awakening_triggered.connect(_on_awakening_triggered)
	context.od_changed.connect(_on_od_changed)
	context.stable_combat_od_awarded.connect(_on_stable_combat_od_awarded)
	# Phase 5B-2: OD 閸栨椽妫块崣妯哄閺冭埖顥呴弻?P19 閸忓骞?	context.od_zone_changed.connect(_on_od_zone_changed_for_building)
	context.od_zone_changed.connect(_on_player_zone_changed)
	enemy_obj.zone_changed.connect(_on_boss_zone_changed)
	context.chain_completed.connect(_on_chain_completed)
	context.chain_system.step_advanced.connect(_on_chain_step)

	# Phase 3B-1: OD Depth signals
	context.depth_changed.connect(_on_depth_changed)
	context.abyss_shock_triggered_signal.connect(_on_abyss_shock_triggered)
	if context.has_signal("boss_field_full"):
		context.boss_field_full.connect(_on_boss_field_full)
	if context.has_signal("boss_back_row_set"):
		context.boss_back_row_set.connect(_on_boss_back_row_set)

	# Phase 4C-4: Boss 鐞涘苯濮╂禍瀣╂娣団€冲娇
	if context.has_signal("boss_instant_played"):
		context.boss_instant_played.connect(_on_boss_instant_played)
	if context.has_signal("boss_instant_card_played"):
		context.boss_instant_card_played.connect(_on_boss_instant_card_played)
	if context.has_signal("boss_action_event"):
		context.boss_action_event.connect(_on_boss_action_event)

	# Phase 25E: unit state signals
	if battle.has_signal("unit_combat_state_changed") and not battle.unit_combat_state_changed.is_connected(_on_unit_combat_state_changed):
		battle.unit_combat_state_changed.connect(_on_unit_combat_state_changed)
	if battle.has_signal("unit_destroyed") and not battle.unit_destroyed.is_connected(_on_unit_destroyed):
		battle.unit_destroyed.connect(_on_unit_destroyed)
	if battle.has_signal("garrison_transaction_committed") and not battle.garrison_transaction_committed.is_connected(_on_garrison_transaction_committed):
		battle.garrison_transaction_committed.connect(_on_garrison_transaction_committed)
# ============================================================
# Phase 24A: Boss 鐘舵€?HUD
# ============================================================
func _setup_boss_status_hud() -> void:
	if _boss_status_hud and is_instance_valid(_boss_status_hud):
		_boss_status_hud.bind_enemy(context.enemy)
	else:
		_boss_status_hud = BossStatusHUDScene.instantiate()
		_boss_status_hud.name = "BossStatusHUD"
		add_child(_boss_status_hud)
		_boss_status_hud.bind_enemy(context.enemy)
	if _boss_status_hud and _boss_status_hud.has_signal("boss_target_clicked"):
		var boss_click_cb := Callable(self, "_request_boss_core_attack")
		if not _boss_status_hud.is_connected("boss_target_clicked", boss_click_cb):
			_boss_status_hud.connect("boss_target_clicked", boss_click_cb)


# ============================================================
# 閹峰吋顢?# ============================================================
func _setup_tables() -> void:
	layout_manager = TableLayoutManager.new()

	# Phase 5C-6: 娴犲酣鍘ょ純顔芥瀮娴犳儼顕伴崣鏍х鐏炩偓 rect 楠炶泛绨查悽銊ュ煂閸氬嫯濡悙?
	var layout_cfg := TableLayoutConfig.new()

	# BattleTable 娴ｈ法鏁?anchors 鐢啫鐪敍灞藉涧鐠?size 娑撳秷顔?position
	var bt_rect := layout_cfg.get_battle_table_rect()
	var battle_table_ctrl := get_node_or_null(NodePath("BattleTable")) as Control
	if battle_table_ctrl:
		battle_table_ctrl.size = bt_rect.size

	# DetailPanelSlot
	var detail_slot_node := get_node_or_null(NodePath("DetailPanelSlot")) as Control
	if detail_slot_node:
		var dp_rect := _get_detail_panel_display_rect(false)
		detail_slot_node.position = dp_rect.position
		detail_slot_node.size = dp_rect.size

	# HandArea
	var hand_area_node := get_node_or_null(NodePath("HandArea")) as Control
	if hand_area_node:
		var ha_rect := layout_cfg.get_hand_area()
		hand_area_node.position = ha_rect.position
		hand_area_node.size = ha_rect.size

	# RightTrack
	var right_track_node := get_node_or_null(NodePath("RightTrack")) as Control
	if right_track_node:
		var rt_rect := layout_cfg.get_right_track_rect()
		right_track_node.position = rt_rect.position
		right_track_node.size = rt_rect.size

	# RightTrack/CoreStatusPanel
	var core_status_node := get_node_or_null(NodePath("BattleTable/CoreStatusPanel")) as Control
	if core_status_node:
		var cs_rect := layout_cfg.get_core_status_rect()
		core_status_node.position = cs_rect.position
		core_status_node.size = cs_rect.size

	# Slot sizes from config
	var f_slot_sz := layout_cfg.get_front_slot_size()
	var b_slot_sz := layout_cfg.get_back_slot_size()

	#閳光偓閳光偓 閻溾晛顔嶉悧灞绢攽 閳光偓閳光偓
	player_table = PlayerTableScene.instantiate()
	player_table.set_anchors_preset(Control.PRESET_FULL_RECT)
	player_slot.add_child(player_table)

	player_table.bind_context(context)
	player_table.bind_player(context.player)
	player_table.set_owner_side("player")
	player_table.set_end_turn_callback(_on_end_turn)
	player_table.set_can_play_check(_get_card_status)
	player_table.card_clicked.connect(_on_card_clicked)
	player_table.field_card_clicked.connect(_on_field_card_attack_clicked)
	# Phase 13F-3: ascension trigger
	if not player_table.ascend_triggered.is_connected(_on_ascend_triggered):
		player_table.ascend_triggered.connect(_on_ascend_triggered)
	player_table.building_interact_requested.connect(_on_building_interact)
	# Phase 5B-2: 瀵よ櫣鐡氶懛顏勫З鐟欙箑褰?+ Depth 閸戝繐鍘ゆ穱鈥冲娇
	battle.building_auto_triggered.connect(_on_building_auto_trigger)
	battle.back_row_triggered.connect(_on_back_row_triggered)
	# Phase 6A: Tutor 娣団€冲娇
	battle.card_tutored.connect(_on_card_tutored)
	battle.tutor_failed.connect(_on_tutor_failed)
	context.depth_reduced.connect(_on_depth_reduced)
	context.depth_gain_mitigated.connect(_on_depth_gain_mitigated)
	player_table.card_dropped.connect(_on_card_dropped)
	player_table.hand_drag_started.connect(_on_player_hand_drag_started)
	player_table.hand_drag_ended.connect(_on_player_hand_drag_ended)
	if _monster_summon_drop_target != null:
		_monster_summon_drop_target.configure(
			Callable(self, "_can_deliver_monster_drop"),
			Callable(self, "_drop_monster_on_board")
		)
	if _monster_summon_interaction_presenter != null and not _monster_summon_interaction_presenter.reselect_requested.is_connected(_on_shared_card_reselect_requested):
		_monster_summon_interaction_presenter.reselect_requested.connect(_on_shared_card_reselect_requested)
	if _monster_summon_interaction_presenter != null and not _monster_summon_interaction_presenter.confirm_requested.is_connected(_on_shared_card_confirm_requested):
		_monster_summon_interaction_presenter.confirm_requested.connect(_on_shared_card_confirm_requested)
	if _monster_summon_interaction_presenter != null and not _monster_summon_interaction_presenter.cancel_requested.is_connected(_on_shared_card_cancel_requested):
		_monster_summon_interaction_presenter.cancel_requested.connect(_on_shared_card_cancel_requested)
	if _structure_interaction_presenter != null and _structure_interaction_presenter.has_signal("activate_requested") and not _structure_interaction_presenter.activate_requested.is_connected(_on_structure_interaction_activate_requested):
		_structure_interaction_presenter.activate_requested.connect(_on_structure_interaction_activate_requested)
	if _structure_interaction_presenter != null and _structure_interaction_presenter.has_signal("candidate_selected") and not _structure_interaction_presenter.candidate_selected.is_connected(_on_structure_candidate_selected):
		_structure_interaction_presenter.candidate_selected.connect(_on_structure_candidate_selected)
	if _structure_interaction_presenter != null and _structure_interaction_presenter.has_signal("build_confirm_requested") and not _structure_interaction_presenter.build_confirm_requested.is_connected(_on_structure_build_confirm_requested):
		_structure_interaction_presenter.build_confirm_requested.connect(_on_structure_build_confirm_requested)
	if _structure_interaction_presenter != null and _structure_interaction_presenter.has_signal("build_reselect_requested") and not _structure_interaction_presenter.build_reselect_requested.is_connected(_begin_structure_build_reselect):
		_structure_interaction_presenter.build_reselect_requested.connect(_begin_structure_build_reselect)
	if _structure_interaction_presenter != null and _structure_interaction_presenter.has_signal("build_cancel_requested") and not _structure_interaction_presenter.build_cancel_requested.is_connected(_on_structure_build_cancel_requested):
		_structure_interaction_presenter.build_cancel_requested.connect(_on_structure_build_cancel_requested)

	# Phase 4B-6: 瀹撳苯鍙嗗Ο鈥崇础 閳?闂呮劘妫岄弮?Header/OD/BottomBar
	player_table.set_embedded_board_mode(true)

	# Phase 4B-6: 鐠囷附鍎忛棃銏℃緲閸嬫粓娼崚鏉夸箯娓?DetailPanelSlot
	var detail_slot := get_node_or_null(NodePath("DetailPanelSlot"))
	if detail_slot:
		player_table.set_detail_panel_host(detail_slot)

	# Phase 4B-6: 閹靛澧濋柌宥呯暰閸氭垵鍩屾惔鏇㈠劥 HandArea
	var hand_area := get_node_or_null(NodePath("HandArea"))
	if hand_area:
		hand_area.clip_contents = true  # Phase 4B-8: 鐟佷礁澹€闂冨弶顒涢幍瀣妞嬬偛鍤崠鍝勭厵
		player_table.set_hand_host(hand_area)
	# Phase 10E: 缂佹垵鐣?CardVFXController
	player_table.set_card_vfx_controller(card_vfx)

	# Phase 4B-6D: 閸?RowSlot 鐎圭懓娅掗崘鍛灡瀵ゅ搫娴愮€规碍蝎娴ｅ秹娼伴弶?
	var p_front_slots := _create_board_slots("BattleTable/PlayerArea/PlayerFrontRowSlot", 5, f_slot_sz, Color(0.1, 0.4, 0.7), "PFS")
	var p_back_slots := _create_board_slots("BattleTable/PlayerArea/PlayerBackRowSlot", 5, b_slot_sz, Color(0.1, 0.6, 0.3), "PBS")
	var b_front_slots := _create_board_slots("BattleTable/BossArea/BossFrontRowSlot", 5, f_slot_sz, Color(0.7, 0.2, 0.1), "BFS")
	var b_back_slots := _create_board_slots("BattleTable/BossArea/BossBackRowSlot", 5, b_slot_sz, Color(0.7, 0.3, 0.1), "BBS")

	# Phase 4B-6D: 閸掓稑缂撶悰灞藉З鐏炴洜銇氬Σ鏂ょ礄SPELL/INSTANT 閻厽娈忛崑婊呮殌閿?
	var boss_action_slot := _create_action_slot("BattleTable/BossArea", "BossActionSlot")
	var player_action_slot := _create_action_slot("BattleTable/PlayerArea", "PlayerActionSlot")

	# Phase 4B-6E: 閸烆垯绔村Σ鎴掔秴閺夈儲绨?閳?閸欘亪鈧俺绻冩径鏍劥濡叉垝缍呴弫鎵矋缂佹垵鐣?	player_table.set_external_board_slots(p_front_slots, p_back_slots)
	player_table.set_action_slot(player_action_slot)

	# 閳光偓閳光偓 閺佸本鏌熼悧灞绢攽 閳光偓閳光偓
	enemy_table = PlayerTableScene.instantiate()
	enemy_table.set_anchors_preset(Control.PRESET_FULL_RECT)
	enemy_slot.add_child(enemy_table)

	enemy_table.bind_context(context)
	enemy_table.bind_player(context.enemy)
	enemy_table.set_owner_side("enemy")
	enemy_table.set_embedded_board_mode(true)
	enemy_table.set_external_board_slots(b_front_slots, b_back_slots)
	enemy_table.set_action_slot(boss_action_slot)
	# Phase 10E: 缂佹垵鐣?CardVFXController閿涘湐oss 閸﹀搫宕卞鍛簚閿?
	enemy_table.set_card_vfx_controller(card_vfx)
	# 閺佸本鏌熸稉宥呭灡瀵ら缚鍤滃杈╂畱鐠囷附鍎忛棃銏℃緲閿涘矂浼╅崗宥夊櫢婢?
	if enemy_table.card_detail_panel and is_instance_valid(enemy_table.card_detail_panel):
		enemy_table.card_detail_panel.queue_free()
		enemy_table.card_detail_panel = null
	# Phase 10A: Boss 閸﹀搫宕遍悙鐟板毊 閳?閺€璇插毊閻╊喗鐖ｉ柅澶嬪
	enemy_table.field_card_clicked.connect(_on_field_card_attack_clicked)
	# Phase 10A: Boss 閺堫兛缍嬮崠鍝勭厵閻愮懓鍤?閳?閻╁瓨甯撮弨璇插毊 Boss HP
	enemy_table.boss_area_clicked.connect(_on_boss_area_attack_clicked)

	# Phase 4B-8: 鐠嬪啳鐦鈧崗铏付閸掕泛鍨庨崠楦垮剹閺咁垰鎷版潏瑙勵攱閿涘牓绮拋銈呭彠闂傤叏绱濋柆鍨帳鐟欏棜顫庨崳顏堢叾閿?
	if _debug_borders_enabled:
		_apply_area_background("BattleTable/BossArea", Color(0.12, 0.03, 0.02, 0.30), "BossAreaBg")
		_apply_area_background("BattleTable/PlayerArea", Color(0.02, 0.04, 0.13, 0.30), "PlayerAreaBg")
		_apply_row_slot_border("BattleTable/BossArea/BossBackRowSlot", Color(0.7, 0.3, 0.1, 0.45))
		_apply_row_slot_border("BattleTable/BossArea/BossFrontRowSlot", Color(0.8, 0.2, 0.1, 0.45))
		_apply_row_slot_border("BattleTable/PlayerArea/PlayerFrontRowSlot", Color(0.1, 0.4, 0.8, 0.45))
		_apply_row_slot_border("BattleTable/PlayerArea/PlayerBackRowSlot", Color(0.1, 0.6, 0.3, 0.45))

	# Phase 4B-6E: 閸ュ搫鐣?z_index 鐏炲倻楠?+ 瀵ゆ儼绻滈幍鎾冲祪鐠嬪啳鐦崸鎰垼
	_apply_board_z_indices()

	# 鎼存梻鏁?1v1 鐢啫鐪?	# Fixed board layout is authored by battle_scene.tscn.
	# Do not call layout_manager.layout_1v1() here: it forces BossArea/PlayerArea
	# to FULL_RECT at runtime and collapses the player board back into the top area.

	# Phase 4B-6: Setup side panel labels
	_setup_side_panel_labels()

	# Phase 4B-7: 閸掓稑缂撴晶鎾虫勾閺屻儳婀呭鍦崶
	_setup_graveyard_view()

	# Phase 4B-6C: 閸掓稑缂撴径鏉戝剼 HUD
	_setup_avatar_huds()

	# Phase 21G: hide 2D field cards when 3D tokens are the visual authority
	if not SHOW_2D_FIELD_CARDS:
		if player_table and player_table.has_method("set_field_cards_visible"):
			player_table.set_field_cards_visible(false)
		if enemy_table and enemy_table.has_method("set_field_cards_visible"):
			enemy_table.set_field_cards_visible(false)

# ============================================================
# Phase 4B-6D: 閸欏厖鏅舵潪銊╀壕闂堛垺婢?閳?閸氼偄褰叉禍銈勭鞍 GY 閺勫墽銇?# ============================================================
func _setup_side_panel_labels() -> void:
	# 閳光偓閳光偓 Boss 閻楀苯绨?婢ф挸婀村Σ?閳光偓閳光偓
	var boss_slot := get_node_or_null(NodePath("BattleTable/BossDeckSlot"))
	if boss_slot:
		_boss_gy_panel = boss_slot
		boss_slot.mouse_filter = Control.MOUSE_FILTER_STOP
		if not boss_slot.mouse_entered.is_connected(_on_boss_gy_hovered):
			boss_slot.mouse_entered.connect(_on_boss_gy_hovered)
		if not boss_slot.mouse_exited.is_connected(_on_gy_unhovered):
			boss_slot.mouse_exited.connect(_on_gy_unhovered)
		if not boss_slot.gui_input.is_connected(_on_boss_gy_clicked):
			boss_slot.gui_input.connect(_on_boss_gy_clicked)
		# 濞撳懐鈹栭弮?children 楠炲爼鍣稿?
		for c in boss_slot.get_children():
			if is_instance_valid(c):
				c.queue_free()
		_boss_deck_label = _create_deck_gy_row(boss_slot, Color(0.7, 0.7, 0.8))
		_boss_gy_last_label = _create_gy_last_label(boss_slot, Color(0.8, 0.5, 0.3))

	# 閳光偓閳光偓 閻溾晛顔嶉悧灞界氨/婢ф挸婀村Σ?閳光偓閳光偓
	var player_slot_p := get_node_or_null(NodePath("BattleTable/PlayerDeckSlot"))
	if player_slot_p:
		_player_gy_panel = player_slot_p
		player_slot_p.mouse_filter = Control.MOUSE_FILTER_STOP
		if not player_slot_p.mouse_entered.is_connected(_on_player_gy_hovered):
			player_slot_p.mouse_entered.connect(_on_player_gy_hovered)
		if not player_slot_p.mouse_exited.is_connected(_on_gy_unhovered):
			player_slot_p.mouse_exited.connect(_on_gy_unhovered)
		if not player_slot_p.gui_input.is_connected(_on_player_gy_clicked):
			player_slot_p.gui_input.connect(_on_player_gy_clicked)
		for c in player_slot_p.get_children():
			if is_instance_valid(c):
				c.queue_free()
		_player_deck_label = _create_deck_gy_row(player_slot_p, Color(0.7, 0.75, 1))
		_player_gy_last_label = _create_gy_last_label(player_slot_p, Color(0.3, 0.6, 0.9))
## 閸︺劌顔栨稉?Panel 閸愬懎鍨卞?Deck/GY 鐠佲剝鏆熺悰?
func _create_deck_gy_row(host: Control, tint: Color) -> Label:
	var lbl := Label.new()
	lbl.name = "DeckGYLabel"
	lbl.text = "Deck: ? | GY: ?"
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", tint)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl.offset_top = 2
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(lbl)
	return lbl
## create GY last label row
func _create_gy_last_label(host: Control, tint: Color) -> Label:
	var lbl := Label.new()
	lbl.name = "GYLastLabel"
	lbl.text = ""
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", tint)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.offset_bottom = -2
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.clip_text = true
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	host.add_child(lbl)
	return lbl
## Phase 4B-6D: 閺囧瓨鏌婇崣鍏呮櫠鏉炪劑浜鹃悧灞界氨/婢ф挸婀寸拋鈩冩殶 + 閺堚偓鏉╂垵宕遍崥?
func _update_side_panel_labels() -> void:
	# Phase 23A-R2: In 3D mode, EngineGauge is the single authority for OD/Depth/HP.
	# Deck/GY counts and last-card names are available via GraveyardView popup.
	if USE_TRUE_3D_BOARD_BACKGROUND:
		return

	# 閳光偓閳光偓 Boss Deck/GY 閳光偓閳光偓
	if _boss_deck_label and is_instance_valid(_boss_deck_label):
		var deck_n := 0
		var gy_n := 0
		if context.enemy:
			if "deck" in context.enemy:
				deck_n = context.enemy.deck.size()
			if "graveyard" in context.enemy:
				gy_n = context.enemy.graveyard.size()
		# Phase 8C: source of truth = context.enemy.graveyard only
		_boss_deck_label.text = "Boss Deck: %d | GY: %d" % [deck_n, gy_n]
	if _boss_gy_last_label and is_instance_valid(_boss_gy_last_label):
		var last_card: CardData = null
		# Phase 8C: 娑撳秴鍟€閻?card_name 閸樺鍣?閳?閸氬苯鎮曢崡鈥冲讲婢舵碍顐奸崙铏瑰箛
		if context.enemy and "graveyard" in context.enemy:
			var gy: Array = context.enemy.graveyard
			if not gy.is_empty():
				last_card = gy[gy.size() - 1]
		if last_card:
			var dname = last_card.get_display_name() if last_card.has_method("get_display_name") else last_card.card_name
			_boss_gy_last_label.text = "Last: %s" % dname
		else:
			_boss_gy_last_label.text = "GY: 0"

	# 閳光偓閳光偓 Player Deck/GY 閳光偓閳光偓
	if _player_deck_label and is_instance_valid(_player_deck_label):
		var deck_n := 0
		var gy_n := 0
		if context.player:
			if "deck" in context.player:
				deck_n = context.player.deck.size()
			if "graveyard" in context.player:
				gy_n = context.player.graveyard.size()
		_player_deck_label.text = "Deck: %d | GY: %d" % [deck_n, gy_n]
	if _player_gy_last_label and is_instance_valid(_player_gy_last_label):
		var last_card: CardData = null
		if context.player and "graveyard" in context.player:
			var gy: Array = context.player.graveyard
			if not gy.is_empty():
				last_card = gy[gy.size() - 1]
		if last_card:
			var dname = last_card.get_display_name() if last_card.has_method("get_display_name") else last_card.card_name
			_player_gy_last_label.text = "Last: %s" % dname
		else:
			_player_gy_last_label.text = "GY: 0"
# ============================================================
# Phase 4B-6D: GY 閹剙浠?閻愮懓鍤穱鈥冲娇婢跺嫮鎮?# ============================================================

func _on_boss_gy_hovered() -> void:
	var card := _get_latest_enemy_gy_card()
	if card:
		_show_gy_card_detail(card)
func _on_player_gy_hovered() -> void:
	var card := _get_latest_player_gy_card()
	if card:
		_show_gy_card_detail(card)
func _on_gy_unhovered() -> void:
	pass  # 娣囨繄鏆€閺堚偓閸氬骸鐫嶇粈铏规畱閸椻槄绱濇稉宥嗙缁岄缚顕涢幆?
func _on_boss_gy_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_gy_view(false)  # false = Boss GY
func _on_player_gy_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_gy_view(true)  # true = Player GY
## 閼惧嘲褰囬悳鈺侇啀婢ф挸婀撮張鈧弬鏉垮幢
func _get_latest_player_gy_card() -> CardData:
	if context.player and "graveyard" in context.player:
		var gy: Array = context.player.graveyard
		if not gy.is_empty():
			return gy[gy.size() - 1]
	return null
## Phase 4B-7: 閼惧嘲褰?Boss 婢ф挸婀撮張鈧弬鏉垮幢閿涘牆鎮庨獮鏈佃⒈婢?GY 閺佺増宓佸┃鎰剁礆
func _get_latest_enemy_gy_card() -> CardData:
	var gy_set: Dictionary = {}
	if context.enemy and "graveyard" in context.enemy:
		for c in context.enemy.graveyard:
			if c and "card_name" in c:
				gy_set[c.card_name] = c
	if boss_deck and "graveyard" in boss_deck:
		for c in boss_deck.graveyard:
			if c and "card_name" in c:
				gy_set[c.card_name] = c
	var merged := gy_set.values()
	if not merged.is_empty():
		return merged[merged.size() - 1]
	return null
## 閸︺劌涔忔笟?DetailPanelSlot 閺勫墽銇?GY 閸椔ゎ嚊閹?
func _show_gy_card_detail(card: CardData) -> void:
	if not card:
		return
	# 婢跺秶鏁?player_table 閻?card_detail_panel
	if player_table and player_table.card_detail_panel and is_instance_valid(player_table.card_detail_panel):
		_gy_hover_card_data = card
		var zone_name: String = ""
		if context and context.has_method("get_od_zone_name"):
			zone_name = context.get_od_zone_name()
		player_table.card_detail_panel.show_card(card, zone_name, {"ok": false, "reason": "已进入墓地"})
## Phase 4B-7: 閸掓稑缂撴晶鎾虫勾閺屻儳婀呭鍦崶楠炴儼绻涢幒銉や繆閸?
func _setup_graveyard_view() -> void:
	_graveyard_view = GraveyardViewClass.new()
	_graveyard_view.name = "GraveyardView"
	_graveyard_view.custom_minimum_size = Vector2(180, 220)
	_graveyard_view.visible = false
	_graveyard_view.z_index = ZI_GRAVEYARD_VIEW  # 300
	# 閺€鎯ф躬閸欏厖绗呯憴?RightTrack 閸栧搫鐓欓梽鍕箮
	_graveyard_view.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_graveyard_view)

	# 连接GraveyardView信号
	if not _graveyard_view.card_hovered.is_connected(_on_gy_entry_hovered):
		_graveyard_view.card_hovered.connect(_on_gy_entry_hovered)
	if not _graveyard_view.card_selected.is_connected(_on_gy_entry_selected):
		_graveyard_view.card_selected.connect(_on_gy_entry_selected)
	if not _graveyard_view.close_requested.is_connected(_on_gy_view_closed):
		_graveyard_view.close_requested.connect(_on_gy_view_closed)
## Phase 4B-7: 閺勫墽銇氭晶鎾虫勾瀵湱鐛ラ敍鍧晄_player: true=Player, false=Boss閿?
func _show_gy_view(is_player: bool) -> void:
	if not _graveyard_view or not is_instance_valid(_graveyard_view):
		return

	var gy: Array = []
	var is_boss := not is_player
	if is_boss:
		# Phase 8C: source of truth = context.enemy.graveyard
		if context.enemy and "graveyard" in context.enemy:
			gy = context.enemy.graveyard
	else:
		if context.player and "graveyard" in context.player:
			gy = context.player.graveyard

	if gy.is_empty():
		if action_feed:
			action_feed.push_message("Graveyard empty", TC.TEXT_DIM)
		return

	# 鐎规矮缍呭鍦崶閸掓澘褰告笟?GY 闂堛垺婢橀梽鍕箮
	var anchor_panel := _player_gy_panel if is_player else _boss_gy_panel
	if anchor_panel and is_instance_valid(anchor_panel):
		var anchor_rect := anchor_panel.get_global_rect()
		_graveyard_view.position = Vector2(
			anchor_rect.position.x - 190,
			anchor_rect.position.y + anchor_rect.size.y / 2 - 110
		)
	else:
		_graveyard_view.position = Vector2(get_viewport_rect().size.x - 210, 200)

	_graveyard_view.show_gy(gy, is_boss)

## _on_gy_entry_hovered
func _on_gy_entry_hovered(card: CardData) -> void:
	_show_gy_card_detail(card)
## Phase 4B-7: GY 閺夛紕娲伴柅澶夎厬 閳?pin 閸掓媽顕涢幆鍛存桨閺?
func _on_gy_entry_selected(card: CardData) -> void:
	_show_gy_card_detail(card)
	if action_feed:
		action_feed.push_message("Selected: %s" % card.card_name, TC.TEXT_SECONDARY)
## Phase 4B-7: GY 瀵湱鐛ラ崗鎶芥４
func _on_gy_view_closed() -> void:
	pass  # 瀵湱鐛ラ懛顏囶攽闂呮劘妫?
# ============================================================

# ============================================================
# ============================================================
# Phase 4C-4B: ThisTurn 闂堛垺婢?閳?閺堫剙娲栭崥鍫㈠负鐎规儼顢戦崝銊︾湽閹?
# ============================================================
func _setup_this_turn_panel() -> void:
	_this_turn_panel = get_node_or_null(NodePath("RightTrack/ThisTurnPanel")) as Panel
	if not _this_turn_panel:
		return
	for c in _this_turn_panel.get_children():
		if is_instance_valid(c):
			c.queue_free()
	_this_turn_labels.clear()
	_this_turn_title = Label.new()
	_this_turn_title.name = "ThisTurnTitle"
	_this_turn_title.text = "This Turn"
	_this_turn_title.add_theme_font_size_override("font_size", 10)
	_this_turn_title.add_theme_color_override("font_color", TC.TEXT_SECONDARY)
	_this_turn_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_this_turn_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_this_turn_title.offset_top = 4
	_this_turn_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_this_turn_panel.add_child(_this_turn_title)
	var content_vbox := VBoxContainer.new()
	content_vbox.name = "ThisTurnContent"
	content_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_vbox.offset_top = 18
	content_vbox.offset_left = 4
	content_vbox.offset_right = -4
	content_vbox.offset_bottom = -4
	content_vbox.add_theme_constant_override("separation", 2)
	content_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_this_turn_panel.add_child(content_vbox)
	for _i in range(THIS_TURN_MAX_LINES):
		var lbl := Label.new()
		lbl.name = "TTLine%d" % _i
		lbl.text = ""
		lbl.add_theme_font_size_override("font_size", THIS_TURN_FONT_SIZE)
		lbl.add_theme_color_override("font_color", TC.TEXT_PRIMARY)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.clip_text = true
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_vbox.add_child(lbl)
		_this_turn_labels.append(lbl)
	# Phase 10C: hover 鐏炴洖绱?閺€鎯版崳
	_this_turn_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not _this_turn_panel.mouse_entered.is_connected(_on_this_turn_hovered):
		_this_turn_panel.mouse_entered.connect(_on_this_turn_hovered)
	if not _this_turn_panel.mouse_exited.is_connected(_on_this_turn_unhovered):
		_this_turn_panel.mouse_exited.connect(_on_this_turn_unhovered)
	print("[ThisTurn] Panel ready, %d lines" % _this_turn_labels.size())
# Phase 10C: ThisTurn/ActionFeed hover 鐏炴洖绱?閺€鎯版崳
func _on_this_turn_hovered() -> void:
	if _this_turn_panel and is_instance_valid(_this_turn_panel):
		_this_turn_panel.custom_minimum_size = Vector2(0, 120)
func _on_this_turn_unhovered() -> void:
	if _this_turn_panel and is_instance_valid(_this_turn_panel):
		_this_turn_panel.custom_minimum_size = Vector2(0, 70)
func _on_action_feed_hovered() -> void:
	# Phase 27D-R5-R2-R3: query new safe lane
	var lane := get_node_or_null(NodePath("BattleFX/ActionFeedSafeLane")) as Control
	if lane and is_instance_valid(lane):
		lane.custom_minimum_size = Vector2(300, 400)
func _on_action_feed_unhovered() -> void:
	var lane := get_node_or_null(NodePath("BattleFX/ActionFeedSafeLane")) as Control
	if lane and is_instance_valid(lane):
		lane.custom_minimum_size = Vector2(300, 162)

func _add_to_this_turn(text: String, color: Color = TC.TEXT_PRIMARY) -> void:
	if _this_turn_labels.is_empty():
		return
	for lbl in _this_turn_labels:
		if not is_instance_valid(lbl):
			continue
		if lbl.text == "":
			lbl.text = text
			lbl.add_theme_color_override("font_color", color)
			return
	for j in range(_this_turn_labels.size() - 1):
		if is_instance_valid(_this_turn_labels[j]) and is_instance_valid(_this_turn_labels[j+1]):
			var above := _this_turn_labels[j]
			var below := _this_turn_labels[j+1]
			above.text = below.text
			above.add_theme_color_override("font_color", below.get_theme_color("font_color", "Label"))
	var last := _this_turn_labels[_this_turn_labels.size() - 1]
	if is_instance_valid(last):
		last.text = text
		last.add_theme_color_override("font_color", color)
func _clear_this_turn() -> void:
	if battle and battle.has_method("reset_building_turn"):
		battle.reset_building_turn()
	# [Fixed]
	if battle and battle.has_method("reset_monster_attacks_turn"):
		battle.reset_monster_attacks_turn()
	# Phase 27B: clear any pending cell selection on turn end
	_cancel_lane_selection(&"turn_end")
	_clear_garrison_selection(&"turn_end")
	for trap in context.player.traps:
		if trap != null and trap.is_building_card() and battle.has_method("get_building_state"):
			var st: Dictionary = battle.get_building_state(trap)
			if not st.is_empty():
				st["_p05_added"] = 0
	for lbl in _this_turn_labels:
		if is_instance_valid(lbl):
			lbl.text = ""
# Phase 4B-6C: 婢舵潙鍎?HUD 閸掓稑缂撴稉搴㈡纯閺?
# ============================================================
	# Phase 7A-2: 娴滄柨鐪板鏇熸惛娴狀亣銆?閳?閺囨寧宕查弮?OD/DEPTH CORE
func _setup_core_status_panel() -> void:
		_core_status_panel = get_node_or_null(NodePath("BattleTable/CoreStatusPanel")) as Panel
		if not _core_status_panel:
			return
		# Phase 13A: Engine Gauge z_index above slot cards, below overlays
		_core_status_panel.z_index = 60
		for c in _core_status_panel.get_children():
			if is_instance_valid(c):
				c.queue_free()
		_core_od_segments.clear()
		_engine_gauge_labels.clear()
		_engine_gauge_progress_bars.clear()
		_engine_gauge_status_labels.clear()

		# Phase 9B: 閺嗘澹婇棃銏℃緲閼冲本娅欓敍宀勬Щ濮濄垻娅ч懝鎻掓健
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.02, 0.025, 0.045, 0.97)
		panel_style.border_width_left = 1
		panel_style.border_width_right = 1
		panel_style.border_width_top = 1
		panel_style.border_width_bottom = 1
		panel_style.border_color = Color(0.28, 0.24, 0.16, 1)
		panel_style.set_corner_radius_all(6)
		panel_style.content_margin_left = 6
		panel_style.content_margin_right = 6
		panel_style.content_margin_top = 4
		panel_style.content_margin_bottom = 4
		_core_status_panel.add_theme_stylebox_override("panel", panel_style)

		# Phase 9B: 閺€鎯с亣闂堛垺婢橀張鈧亸蹇撴槀鐎?

	# Phase 14D: add engine gauge placeholder as mechanical frame base
		# Phase 14D: add gauge placeholder
		_add_gauge_art_background(_core_status_panel)

		# Phase 18B: reduce spacing to fit 5 layers + info in taller panel (196px)
		var title := Label.new()
		title.name = "EngineGaugeTitle"
		title.text = "OD ENGINE"
		title.add_theme_font_size_override("font_size", 10)
		title.add_theme_color_override("font_color", Color(0.65, 0.82, 0.95, 1))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.set_anchors_preset(Control.PRESET_TOP_WIDE)
		title.offset_top = 2
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_core_status_panel.add_child(title)

		# 创建 Engine Layers VBox
		var layers_vbox := VBoxContainer.new()
		layers_vbox.name = "EngineLayersVBox"
		layers_vbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
		layers_vbox.offset_top = 18
		layers_vbox.offset_left = 2
		layers_vbox.offset_right = -2
		layers_vbox.add_theme_constant_override("separation", 2)
		layers_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_core_status_panel.add_child(layers_vbox)

		# Engine Layer Colors (od_mode.ENGINE_LAYER_COLORS)
		const LAYER_COLORS: Array[Color] = [
			Color(0.18, 0.80, 0.25, 1),
			Color(0.00, 0.81, 0.82, 1),
			Color(0.20, 0.60, 0.86, 1),
			Color(0.56, 0.27, 0.68, 1),
			Color(1.0, 0.25, 0.06, 1),
		]
		const LAYER_NAMES_CN: Array[String] = ["Ignite", "Stable", "Pressure", "Heated", "Burst"]

		for li in range(5):
			var layer_idx := li + 1
			var layer_color := LAYER_COLORS[li]
			var layer_name_cn := LAYER_NAMES_CN[li]

			# Phase 9B: 创建 Layer Rail
			var row := HBoxContainer.new()
			row.name = "LayerRail%d" % layer_idx
			row.add_theme_constant_override("separation", 3)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layers_vbox.add_child(row)

			# Layer 标签
			var name_label := Label.new()
			name_label.name = "LayerIdx%d" % layer_idx
			name_label.text = "%d" % layer_idx
			name_label.add_theme_font_size_override("font_size", 8)
			name_label.add_theme_color_override("font_color", layer_color)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.custom_minimum_size = Vector2(16, 16)
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(name_label)
			_engine_gauge_labels.append(name_label)

			# 鏉╂稑瀹抽弶鈥崇俺
			var bar_bg := ColorRect.new()
			bar_bg.name = "RailBg%d" % layer_idx
			bar_bg.color = Color(0.03, 0.03, 0.06, 0.92)
			bar_bg.custom_minimum_size = Vector2(0, 16)
			bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(bar_bg)

			# 鏉╂稑瀹抽弶鈥筹綖閸?
			var bar_fill := ColorRect.new()
			bar_fill.name = "RailFill%d" % layer_idx
			bar_fill.color = layer_color
			bar_fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
			bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar_bg.add_child(bar_fill)
			_engine_gauge_progress_bars.append(bar_fill)

			# Phase 18B: compact status label
			var status_label := Label.new()
			status_label.name = "RailStatus%d" % layer_idx
			status_label.text = layer_name_cn
			status_label.add_theme_font_size_override("font_size", 8)
			status_label.add_theme_color_override("font_color", TC.TEXT_SECONDARY)
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			status_label.custom_minimum_size = Vector2(56, 16)
			status_label.clip_text = true
			status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(status_label)
			_engine_gauge_status_labels.append(status_label)

		# Phase 9B-Fix: 瑜版挸澧犵仦鍌濆墻閸愭彃濮╅悽?
		_safe_kill_eg_pulse()
		var current_layer_for_pulse: int = 1
		if context and context.od_mode and context.od_mode.has_method("get_engine_summary"):
			var pulse_summary: Dictionary = context.od_mode.get_engine_summary()
			current_layer_for_pulse = int(pulse_summary.get("layer", 1))

		if current_layer_for_pulse >= 1 and current_layer_for_pulse <= 5:
			var current_li: int = current_layer_for_pulse - 1
			if current_li < _engine_gauge_progress_bars.size():
				var bar_fill_active: ColorRect = _engine_gauge_progress_bars[current_li]
				if is_instance_valid(bar_fill_active):
					_engine_gauge_pulse_tween = create_tween()
					_engine_gauge_pulse_tween.set_loops()
					_engine_gauge_pulse_tween.tween_property(bar_fill_active, "modulate:a", 0.55, 0.8).set_trans(Tween.TRANS_SINE)
					_engine_gauge_pulse_tween.tween_property(bar_fill_active, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
		# Phase 18B: compact info section
		var info_vbox := VBoxContainer.new()
		info_vbox.name = "EngineInfoVBox"
		info_vbox.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		info_vbox.offset_bottom = -2
		info_vbox.offset_left = 4
		info_vbox.offset_right = -4
		info_vbox.add_theme_constant_override("separation", 0)
		info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_core_status_panel.add_child(info_vbox)

		# Phase 18H-2: compact 2-line info (Load removed 鈥?duplicated by current layer charge)
		_engine_gauge_od_label = _make_eg_label("OD", info_vbox, Color(0.65, 0.82, 0.95, 1))
		_engine_gauge_load_label = _make_eg_label("Load", info_vbox, Color(0.5, 0.5, 0.5, 0.6))
		_engine_gauge_load_label.visible = false
		_engine_gauge_depth_label = _make_eg_label("Depth", info_vbox, Color(0.3, 0.6, 1, 1))
		_engine_gauge_burst_label = _make_eg_label("Burst", info_vbox, Color(1, 0.85, 0.0, 1))

		# Phase 26C: Core Command button (compact, relabeled for Phase 27D-R3)
		# Phase 27K-R0-R: 迁出 EngineInfoVBox（将被隐藏）到专用 CoreStatusActions 交互区，
		# 复用原按钮、pressed 信号与原处理方法，保证调用链不变。
		var core_actions := HBoxContainer.new()
		core_actions.name = "CoreStatusActions"
		core_actions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		core_actions.offset_left = 5
		core_actions.offset_right = -5
		core_actions.offset_top = -60
		core_actions.offset_bottom = -36
		core_actions.add_theme_constant_override("separation", 4)
		core_actions.mouse_filter = Control.MOUSE_FILTER_PASS
		_core_status_panel.add_child(core_actions)
		_core_command_button = Button.new()
		_core_command_button.name = "CoreCommandButton"
		_core_command_button.text = "OD指令"
		_core_command_button.add_theme_font_size_override("font_size", 9)
		_core_command_button.custom_minimum_size = Vector2(60, 0)
		core_actions.add_child(_core_command_button)
		_core_command_button.pressed.connect(_on_core_command_button_pressed)

		# Phase 27D-R5-R1: Tactical Command Economy HUD — persistent screen-space overlay
		_command_economy_hud = CommandEconomyHUDClass.new()
		_command_economy_hud.name = "CommandEconomyHUD"
		_command_economy_hud.custom_minimum_size = Vector2(190, 92)
		# R5-R1: Attach to BattleFX CanvasLayer (layer 10) for guaranteed visibility
		# above all 3D viewport and BattleTable content.  Fallback to BattleTable.
		var fx_layer := get_node_or_null(NodePath("BattleFX")) as CanvasLayer
		if fx_layer and is_instance_valid(fx_layer):
			fx_layer.add_child(_command_economy_hud)
			# Fixed top-right: right edge -200, top 80
			_command_economy_hud.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			_command_economy_hud.offset_left = -200
			_command_economy_hud.offset_right = -4
			_command_economy_hud.offset_top = 80
			_command_economy_hud.offset_bottom = 172
		else:
			var bt_ref := get_node_or_null(NodePath("BattleTable")) as Control
			if bt_ref and is_instance_valid(bt_ref):
				bt_ref.add_child(_command_economy_hud)
				_command_economy_hud.set_anchors_preset(Control.PRESET_TOP_RIGHT)
				_command_economy_hud.offset_left = -200
				_command_economy_hud.offset_right = -4
				_command_economy_hud.offset_top = 80
				_command_economy_hud.offset_bottom = 172
			elif _core_status_panel:
				_core_status_panel.add_child(_command_economy_hud)
		_configure_command_economy_hud()

		_update_core_status_panel()

func _setup_od_release_control() -> void:
	if _od_release_control != null and is_instance_valid(_od_release_control):
		_od_release_control.queue_free()
	_od_release_control = ODReleaseControlClass.new()
	_od_release_control.name = "ODReleaseControl"
	_od_release_control.z_index = 90
	_od_release_control.mouse_filter = Control.MOUSE_FILTER_PASS
	if _core_status_panel != null and is_instance_valid(_core_status_panel):
		_core_status_panel.add_child(_od_release_control)
		_od_release_control.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_od_release_control.offset_left = 5
		_od_release_control.offset_right = -5
		_od_release_control.offset_top = -32
		_od_release_control.offset_bottom = -4
	if _od_release_control.has_signal("release_requested"):
		_od_release_control.release_requested.connect(_begin_od_release_selection)
	if _od_release_control.has_signal("final_requested"):
		_od_release_control.final_requested.connect(_begin_final_convergence_selection)
	if _od_release_control.has_signal("ritual_requested"):
		_od_release_control.ritual_requested.connect(_begin_ritual_final_selection)
	if _od_release_control.has_signal("cancel_requested"):
		_od_release_control.cancel_requested.connect(_clear_od_release_selection.bind(&"control_cancel"))
	# Phase 27K-R0: 灰盒 OD ENGINE 叠加在 CoreStatusPanel 上（单一 HUD 锚点）
	_setup_od_engine_greybox()

func _setup_od_engine_greybox() -> void:
	if _od_engine_greybox != null and is_instance_valid(_od_engine_greybox):
		_od_engine_greybox.queue_free()
	_od_presentation_profile = GameCfg.create_od_presentation_snapshot()
	if _core_status_panel != null and is_instance_valid(_core_status_panel):
		# Phase 27K-R0-R: 灰盒启用时隐藏旧 EngineGauge 渲染器（不依赖灰盒覆盖）。
		# 屏幕中只保留一套 OD ENGINE 状态渲染，交互区由 CoreStatusActions / ODReleaseControl 独立承载。
		_hide_legacy_engine_gauge()
		_od_engine_greybox = ODEngineGreyboxClass.new()
		_od_engine_greybox.name = "ODEngineGreybox"
		_od_engine_greybox.z_index = 10
		_od_engine_greybox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_od_engine_greybox.configure(_od_presentation_profile)
		_core_status_panel.add_child(_od_engine_greybox)
		# 唯一状态渲染区：顶部占位，让出底部给 CoreStatusActions(-60..-36) 与 ODReleaseControl(-32..-4)
		_od_engine_greybox.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_od_engine_greybox.offset_top = 2
		_od_engine_greybox.offset_bottom = -64
	_refresh_od_engine_greybox()


## Phase 27K-R0-R: 隐藏旧 EngineGauge 渲染器，保留其节点引用（_update_core_status_panel 仍安全更新）。
func _hide_legacy_engine_gauge() -> void:
	if _core_status_panel == null or not is_instance_valid(_core_status_panel):
		return
	for node_path in [&"EngineGaugeTitle", &"EngineLayersVBox", &"EngineInfoVBox", &"GaugeArtBg"]:
		var child := _core_status_panel.get_node_or_null(NodePath(node_path)) as Control
		if child == null:
			continue
		child.visible = false
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Phase 27K-R0: 组装只读表现快照（只组合现有权威数据，不重算、不写入）。
func _refresh_od_engine_greybox() -> void:
	if _od_engine_greybox == null or not is_instance_valid(_od_engine_greybox):
		return
	var state: Dictionary = {}
	if context != null and context.od_mode != null:
		var om = context.od_mode
		var snap := om.get_heat_cycle_snapshot()
		state["heat"] = int(snap.get("heat", 0))
		state["heat_max"] = int(snap.get("heat_max", 10))
		state["zone"] = str(snap.get("zone", "Calm"))
		state["charge"] = int(snap.get("charge", 0))
		state["capacity"] = int(snap.get("capacity", 0))
		state["layer"] = int(snap.get("layer", 1))
		state["layer_count"] = 5
	if context != null:
		state["depth"] = int(context.depth_pressure)
		state["depth_max"] = int(context.get_depth_max_value()) if context.has_method("get_depth_max_value") else 6
		state["depth_zone"] = str(context.get_depth_zone()) if context.has_method("get_depth_zone") else "Stable"
	if battle != null and battle.has_method("get_od_release_status"):
		var rel: Dictionary = battle.get_od_release_status("player")
		state["release_ok"] = bool(rel.get("ok", false))
		state["reason_code"] = str(rel.get("reason_code", ""))
		state["readiness_threshold"] = int(rel.get("readiness_threshold", 8))
		state["release_heat_cost"] = int(rel.get("release_heat_cost", 5))
	if bool(_od_release_context.get("active", false)):
		state["selection_active"] = true
		state["selection_stage"] = str(_od_release_context.get("stage", ""))
	# Phase 27K-R0: 惰性连接释放事件，让"处理中/释放中"阶段可见并与 EndTurn BUSY 一致
	if not _od_greybox_release_event_hooked and battle != null and battle.has_signal("od_release_event"):
		battle.od_release_event.connect(_on_od_release_event)
		_od_greybox_release_event_hooked = true
	_od_engine_greybox.refresh(state)


func _on_od_release_event(_event_id: StringName, _payload: Dictionary) -> void:
	_refresh_od_engine_greybox()


func _connect_od_feedback_telemetry() -> void:
	_setup_battle_presentation_director()
	if context == null or not context.has_signal("od_feedback_event_committed"):
		return
	var callback := Callable(self, "_on_od_feedback_event_committed")
	if not context.is_connected("od_feedback_event_committed", callback):
		context.connect("od_feedback_event_committed", callback)


func _on_od_feedback_event_committed(event: Dictionary) -> void:
	if _playtest != null and _playtest.has_method("record_od_feedback_event"):
		_playtest.record_od_feedback_event(event)
	_refresh_od_engine_greybox()
	if _battle_presentation_director != null and is_instance_valid(_battle_presentation_director):
		var presentation_event := event.duplicate(true)
		var tx := StringName(presentation_event.get("transaction_id", &""))
		if tx != &"" and _od_release_presentation_facts_by_tx.has(tx):
			presentation_event["presentation_facts"] = (_od_release_presentation_facts_by_tx[tx] as Dictionary).duplicate(true)
		_battle_presentation_director.consume_od_event(presentation_event)
		if StringName(event.get("event_kind", &"")) in [&"release_committed", &"release_cancelled"]:
			_od_release_presentation_facts_by_tx.erase(tx)


func _setup_battle_presentation_director() -> void:
	if _battle_presentation_director != null and is_instance_valid(_battle_presentation_director):
		return
	_combat_presentation_profile = GameCfg.create_combat_presentation_profile(false)
	_card_direction_presenter = CardDirectionPresenterClass.new()
	_card_direction_presenter.name = "CardDirectionPresenter"
	add_child(_card_direction_presenter)
	_card_direction_presenter.configure(_combat_presentation_profile, battle_vfx)
	if spell_activation_presenter != null and is_instance_valid(spell_activation_presenter):
		if spell_activation_presenter.has_method("configure_profile"):
			spell_activation_presenter.configure_profile(_combat_presentation_profile)
		if spell_activation_presenter.has_method("configure_direction_presenter"):
			spell_activation_presenter.configure_direction_presenter(_card_direction_presenter)
	_battle_presentation_director = BattlePresentationDirectorClass.new()
	_battle_presentation_director.name = "BattlePresentationDirector"
	add_child(_battle_presentation_director)
	_battle_presentation_director.configure(self, context, _combat_presentation_profile, {
		"battle_vfx": battle_vfx,
		"monster_presenter": monster_combat_presenter,
		"monster_combat_presenter": monster_combat_presenter,
		"spell_presenter": spell_activation_presenter,
		"card_direction_presenter": _card_direction_presenter,
		"tactical_presenter": Callable(self, "_get_presentation_tactical_presenter"),
		"od_engine_greybox": Callable(self, "_get_presentation_od_engine_greybox"),
		"board_root": Callable(self, "_get_presentation_board_root"),
		"get_tactical_presenter": Callable(self, "_get_presentation_tactical_presenter"),
		"get_od_engine_greybox": Callable(self, "_get_presentation_od_engine_greybox"),
		"get_audio_manager": Callable(self, "_am"),
		"get_board_root": Callable(self, "_get_presentation_board_root"),
		"get_release_conduit_points": Callable(self, "_get_od_release_conduit_points"),
		"get_release_target_position": Callable(self, "_get_od_release_target_position"),
		"safe_position_resolver": Callable(self, "_get_safe_notification_position"),
		"final_hud_refresh": Callable(self, "_finalize_battle_presentation_hud"),
		"cancel_all_presenters": Callable(self, "_cancel_battle_presentation_dependencies"),
		"timeline_scale": 1.0,
	})
	var busy_callback := Callable(self, "_on_battle_presentation_busy_changed")
	if not _battle_presentation_director.is_connected("presentation_busy_changed", busy_callback):
		_battle_presentation_director.connect("presentation_busy_changed", busy_callback)


func _play_monster_presentation(action_kind: StringName, facts: Dictionary) -> void:
	var committed := facts.duplicate(true)
	committed["status"] = StringName(committed.get("status", &"committed" if bool(committed.get("ok", false)) else &"rejected"))
	if _battle_presentation_director != null and is_instance_valid(_battle_presentation_director) and _battle_presentation_director.has_method("play_monster_action"):
		await _battle_presentation_director.play_monster_action(action_kind, committed)
		return
	if monster_combat_presenter == null or not is_instance_valid(monster_combat_presenter):
		return
	match action_kind:
		&"summon":
			if monster_combat_presenter.has_method("play_summon_sequence"):
				await monster_combat_presenter.play_summon_sequence(committed.get("card", null), committed)
		&"attack":
			if monster_combat_presenter.has_method("play_attack_sequence"):
				await monster_combat_presenter.play_attack_sequence(committed)
		&"skill":
			if monster_combat_presenter.has_method("play_skill_sequence"):
				await monster_combat_presenter.play_skill_sequence(committed.get("card", null), StringName(committed.get("skill_id", &"")), committed.get("target", null), committed)


func _play_generic_presentation(action_kind: StringName, facts: Dictionary) -> void:
	if _battle_presentation_director == null or not is_instance_valid(_battle_presentation_director):
		return
	if not _battle_presentation_director.has_method("play_generic_action"):
		return
	var committed := facts.duplicate(true)
	committed["status"] = StringName(committed.get("status", &"committed" if bool(committed.get("ok", false)) else &"rejected"))
	await _battle_presentation_director.play_generic_action(action_kind, committed)


func _get_presentation_tactical_presenter() -> Node:
	return _tactical_presenter


func _get_presentation_od_engine_greybox() -> Control:
	return _od_engine_greybox


func _get_presentation_board_root() -> Control:
	return get_node_or_null(NodePath("BattleTable")) as Control


func _get_od_release_conduit_points(facts: Dictionary) -> Array[Vector2]:
	var projected: Dictionary = facts.get("presentation_facts", {})
	var result: Array[Vector2] = []
	for raw_point in projected.get("conduit_points", []):
		if raw_point is Vector2 and raw_point != Vector2.INF:
			result.append(raw_point)
	return result


func _get_od_release_target_position(facts: Dictionary) -> Vector2:
	var projected: Dictionary = facts.get("presentation_facts", {})
	return projected.get("target_position", Vector2.INF)


func _finalize_battle_presentation_hud() -> void:
	if not battle_ended:
		_refresh_tables()


func _cancel_battle_presentation_dependencies(_reason: StringName = &"cancel") -> void:
	_cleanup_structure_presentation_lifecycle(_reason)
	if _card_direction_presenter != null and is_instance_valid(_card_direction_presenter) and _card_direction_presenter.has_method("cancel_all"):
		_card_direction_presenter.cancel_all(_reason)
	if battle_vfx != null and is_instance_valid(battle_vfx):
		battle_vfx.stop_all()
	if monster_combat_presenter != null and is_instance_valid(monster_combat_presenter) and monster_combat_presenter.has_method("cancel_all"):
		monster_combat_presenter.cancel_all()
	if spell_activation_presenter != null and is_instance_valid(spell_activation_presenter) and spell_activation_presenter.has_method("cancel_all"):
		spell_activation_presenter.cancel_all()
	if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
		_tactical_presenter.cancel()


func _has_non_presentation_end_turn_busy(drag_takeover_card: CardData = null) -> bool:
	# PHASE53_BEGIN_BUSY
	if _core_surge_selecting or _core_surge_committing:return true
	# PHASE53_END_BUSY
	if battle_ended or _card_being_played or _spell_end_turn_blocked:
		return true
	if spell_activation_presenter != null and is_instance_valid(spell_activation_presenter) and spell_activation_presenter.has_method("is_active") and spell_activation_presenter.is_active():
		return true
	# Mouse press may select this card before Godot detects the drag threshold.
	# Only its initial anchor selection may transfer ownership to that drag.
	var same_anchor: bool = drag_takeover_card != null \
		and _piece_context.get("card", null) == drag_takeover_card \
		and _piece_context.get("action_id", &"") == &"play" \
		and _piece_context.get("stage", &"") == &"anchor"
	return (_is_piece_selection_active() and not same_anchor) \
		or _is_lane_selection_active() \
		or _is_structure_build_drag_active() \
		or bool(_garrison_context.get("active", false)) \
		or bool(_skill_context.get("active", false)) \
		or bool(_od_release_context.get("active", false)) \
		or _building_replace_select_active


func _on_battle_presentation_busy_changed(busy: bool, _reason: StringName) -> void:
	_presentation_end_turn_blocked = busy
	if _end_turn_control == null or not is_instance_valid(_end_turn_control):
		return
	if busy:
		_end_turn_control.set_busy(true, "战斗演出结算中")
	elif not _has_non_presentation_end_turn_busy():
		_end_turn_control.set_busy(false, "")

## A short cue may finish while another owner is still resolving. Its callback
## cannot release the button then; reconcile once all real owners have ended.
## Preserve CONFIRM and keep active selections/presentations blocked.
func _release_idle_end_turn_busy() -> void:
	if _end_turn_control == null or not is_instance_valid(_end_turn_control) or not _end_turn_control.is_busy():
		return
	if _has_non_presentation_end_turn_busy() or _presentation_end_turn_blocked:
		return
	if _battle_presentation_director != null and is_instance_valid(_battle_presentation_director) and _battle_presentation_director.is_busy():
		return
	_end_turn_control.set_busy(false, "")


func _refresh_od_release_control() -> void:
	if _od_release_control == null or not is_instance_valid(_od_release_control):
		return
	var snapshot: Dictionary = {}
	if battle != null and battle.has_method("get_od_release_status"):
		snapshot = battle.get_od_release_status("player")
	if battle != null and battle.has_method("get_final_convergence_status"):
		var final_status: Dictionary = battle.get_final_convergence_status("player")
		snapshot["final_ready"] = bool(final_status.get("ok", false))
		snapshot["final_reason_code"] = final_status.get("reason_code", &"")
		if bool(final_status.get("ritual_trial", false)):
			snapshot["ritual_trial"] = true
			# PHASE62_BEGIN_RITUAL_UI_VALUE
			snapshot["ritual_readiness_threshold"]=int(final_status.get("readiness_threshold",snapshot.get("readiness_threshold",8)))
			# PHASE62_END_RITUAL_UI_VALUE
			for key in ["attack_count", "garrison_count", "control_count", "attack_ready", "guard_ready", "used", "depth", "depth_max", "living_attack_participants", "living_guard_participants", "attack_sources", "guard_sources", "control_sources", "last_receipt"]:
				snapshot[key] = final_status.get(key)
			snapshot["available_paths"] = final_status.get("available_paths", [])
			snapshot["path_effects"] = final_status.get("path_effects", {})
			snapshot["path_previews"] = final_status.get("path_previews", {})
			snapshot["overcharge_available"] = final_status.get("overcharge_available", false)
			snapshot["overcharge_depth_after"] = final_status.get("overcharge_depth_after", 0)
	if context != null and context.od_mode != null:
		snapshot["heat"] = int(context.od_mode.current_od)
	if bool(_od_release_context.get("active", false)):
		snapshot["selection_stage"] = _od_release_context.get("stage", &"source")
	_od_release_control.refresh(snapshot)
	_refresh_od_selection_guidance()
	# Phase 27K-R0: 释放状态变化同步驱动灰盒（释放开始/选择/取消/成功/失败）
	_refresh_od_engine_greybox()

func _begin_od_release_selection(final_convergence: bool = false, ritual_path: String = "", ritual_overcharge: bool = false) -> void:
	# PHASE53_BEGIN_OD
	if _core_surge_committing:return
	_clear_core_surge_selection()
	# PHASE53_END_OD
	if battle == null or battle_ended or _card_being_played:
		return
	var status: Dictionary = battle.get_final_convergence_status("player") if final_convergence else battle.get_od_release_status("player")
	if not bool(status.get("ok", false)):
		if action_feed:
			action_feed.push_message("OD ENGINE 尚未就绪", TC.TEXT_DIM, "", 1.5)
		_refresh_od_release_control()
		return
	_clear_od_release_selection(&"restart")
	_od_release_context = {"active": true, "stage": &"source", "source": null, "source_status": {}, "final_convergence": final_convergence,
		"ritual_path": ritual_path, "ritual_overcharge": ritual_overcharge}
	if _end_turn_control and is_instance_valid(_end_turn_control):
		_end_turn_control.set_busy(true, "OD 释放选择中")
	if action_feed:
		action_feed.push_message("OD ENGINE：选择一枚棋子", Color(0.3, 0.9, 1.0), "", 2.0)
	_refresh_od_release_control()

func _begin_final_convergence_selection() -> void:
	_begin_od_release_selection(true)

func _begin_ritual_final_selection(path: String, overcharge: bool) -> void:
	# PHASE53_BEGIN_RITUAL
	if _core_surge_committing:return
	_clear_core_surge_selection()
	# PHASE53_END_RITUAL
	if battle == null or battle_ended or _card_being_played:
		return
	_od_release_transaction_serial += 1
	var tx := StringName("gui_ritual_%d" % _od_release_transaction_serial)
	var result: Dictionary = battle.execute_final_convergence("player", null, null, {
		"transaction_id": tx, "ritual_path": path, "ritual_overcharge": overcharge})
	if bool(result.get("ok", false)):
		if _playtest:
			_playtest.record_event("final_convergence", {"piece_type": &"ritual", "heat": result.get("od_cost", 0)})
		if action_feed:
			action_feed.push_message("炉心汇流：Boss HP -%d，清盾 %d，抽牌 %d/%d，OD %d→%d" % [
				int(result.get("final_actual_hp_loss", 0)), int(result.get("ritual_boss_shield_removed_total", 0)),
				int(result.get("ritual_cards_drawn", 0)),
				int(result.get("ritual_draw_requested", 0)), int(result.get("heat_before", 0)),
				int(result.get("heat_after", 0))], Color(1.0, 0.75, 0.2), "", 3.0)
		_show_ritual_final_presentation(result)
		_refresh_tables()
		check_battle_end()
	else:
		if action_feed:
			action_feed.push_message("炉心汇流失败：%s" % str(result.get("reason_code", "unknown")), TC.WARNING, "", 2.0)
	_refresh_od_release_control()

func _show_ritual_final_presentation(receipt: Dictionary) -> void:
	var old := get_node_or_null("RitualFinalPresentation")
	if old != null:
		remove_child(old)
		old.queue_free()
	var layer := CanvasLayer.new()
	layer.name = "RitualFinalPresentation"
	layer.layer = 90
	add_child(layer)
	var visual = preload("res://scenes/presentation/ritual_board_presentation.gd").new()
	visual.name = "BoardRitual"
	layer.add_child(visual)
	var geometry: Dictionary = {"engine": _od_engine_greybox.get_global_rect().get_center(),
		"boss": _project_tactical_cell_to_screen(Vector2i(2,0)) + Vector2(0,-56),
		"player": _project_tactical_cell_to_screen(Vector2i(2,4)) + Vector2(0,60),
		"hand": Vector2(get_viewport_rect().size.x * 0.5, get_viewport_rect().size.y - 85),
		"sources": [], "hits": []}
	for source: Dictionary in receipt.get("ritual_sources", []):
		var point := _project_tactical_cell_to_screen(source.cell)
		if point.is_finite(): geometry.sources.append({"position": point, "name": source.name})
	for hit: Dictionary in receipt.get("ritual_unit_hit_facts", []):
		var point := _project_tactical_cell_to_screen(hit.cell)
		if point.is_finite(): geometry.hits.append({"position": point, "hp_loss": hit.hp_loss})
	visual.finished.connect(layer.queue_free)
	visual.present(receipt, geometry, _is_reduced_motion_presentation())

func _select_od_release_source(source: CardData) -> bool:
	if not bool(_od_release_context.get("active", false)) or StringName(_od_release_context.get("stage", &"")) != &"source":
		return false
	var status: Dictionary = battle.get_od_release_source_status(source)
	if not bool(status.get("ok", false)):
		if action_feed:
			action_feed.push_message("该棋子无法释放：" + _od_release_reason_text(status), TC.WARNING, "", 1.5)
		return true
	_od_release_context["stage"] = &"target"
	_od_release_context["source"] = source
	_od_release_context["source_status"] = status
	var target_cells: Array[Vector2i] = []
	for raw_cell in status.get("legal_cells", []):
		if raw_cell is Vector2i and not target_cells.has(raw_cell):
			target_cells.append(raw_cell)
	for target in status.get("legal_targets", []):
		var target_cell: Vector2i = battle.get_unit_cell(target)
		if target_cell != Vector2i(-1, -1) and not target_cells.has(target_cell):
			target_cells.append(target_cell)
	_ensure_tactical_movement_presenter()
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		var no_cells: Array[Vector2i] = []
		_tactical_presenter.show_piece_selection(&"od_release", &"od_release", battle.get_unit_cell(source), no_cells, target_cells, no_cells, {})
	if action_feed:
		var guidance := _build_ritual_selection_summary(status) if bool(_od_release_context.get("final_convergence", false)) else _build_tactical_release_summary(status)
		action_feed.push_message(guidance, Color(1.0, 0.72, 0.18), "", 3.5 if bool(_od_release_context.get("final_convergence", false)) else 2.0)
	_refresh_od_release_control()
	return true

var _od_selection_guidance: Control

func _od_release_reason_text(status: Dictionary) -> String:
	match StringName(status.get("reason_code", &"")):
		&"summoning_sickness": return "刚登场，需等下个己方回合"
		&"source_dead", &"source_missing": return "来源已离场，请重新选择棋子"
		&"piece_release_missing": return "该棋子没有普通战术释放；可用攻击准备仪式"
		&"insufficient_heat": return "需至少%d热（当前%d）" % [int(status.get("readiness_threshold",8)),int(status.get("heat",0))]
		&"insufficient_command_points": return "需%d指令（当前%d）" % [int(status.get("command_cost",0)),int(status.get("points",0))]
		&"no_legal_target", &"stale_target": return "当前没有合法落点或对象，请重选"
		&"not_player_turn": return "请在己方回合释放"
		&"wrong_side": return "请选择己方棋子"
		&"release_busy": return "等待本次释放结算完成"
	return "当前条件变化，请重选"

func _build_tactical_release_summary(status: Dictionary) -> String:
	var effect := ""
	match StringName(status.get("piece_type", &"")):
		&"pawn": effect = "选合法落点推进，己方护盾+1"
		&"knight": effect = "选合法落点跃迁；落点有可攻击敌棋时，干扰伤害%d" % battle.od_release_rules.get_knight_disruption_damage()
		&"bishop": effect = "选斜线合法敌棋交战，攻击额外+1"
		&"rook": effect = "选直线合法友军，准备一次接力"
	var heat := int(status.get("heat",0))
	var text := "战术释放：%s；仅扣热：热量%d→%d，指令-%d；转换热量推进引擎，本次不领取仪式奖励。右键/Escape取消" % [effect,heat,maxi(0,heat-int(status.get("od_cost",0))),int(status.get("command_cost",0))]
	var source: CardData = status.get("source")
	if source == null:
		return text
	if StringName(status.get("piece_type", &"")) == &"knight":
		text += "\n" + _knight_od_landing_summary(source, status.get("legal_cells", []))
	var decision: Dictionary = battle.get_od_release_decision_status(source)
	if not bool(decision.get("ok", false)):
		return text
	var core_options: Array = decision.current_core_options
	if core_options.is_empty():
		text += "\n付款后预计余%d指令；当前没有可执行的核心攻击。" % int(decision.points_after_payment)
	else:
		var example: Dictionary = core_options[0]
		for option: Dictionary in core_options:
			if int(option.cost) < int(example.cost): example = option
		text += "\n当前可攻核心：%s（%d指令），共%d名；付款后预计余%d指令。" % [str(example.name), int(example.cost), core_options.size(), int(decision.points_after_payment)]
		if int(decision.core_payment_shortfall) > 0:
			text += " 比当前最低费用少%d。" % int(decision.core_payment_shortfall)
	if bool(decision.ritual_trial):
		if bool(decision.ritual_used):
			text += "\n仪式已领取；继续普通OD与出牌攻城。"
		else:
			text += "\n%s；奖励仍差%d热（仅扣热预算），准备记录保留。" % ["准备已完成" if bool(decision.preparation_complete) else "准备未完成", int(decision.reward_heat_gap)]
	text += "\n预算未计行动触发；结算后重查目标与费用。"
	return text

func _knight_od_landing_summary(source: CardData, cells: Array) -> String:
	var examples: Array[String] = []
	var unknown := false
	for cell: Vector2i in cells:
		var preview: Dictionary = battle.get_knight_od_landing_preview(source, cell)
		if not bool(preview.get("ok", false)): continue
		if not bool(preview.get("prediction_available", false)):
			unknown = true
			continue
		var target: CardData = preview.get("target")
		if target != null and examples.size() < 2:
			examples.append("%s%d(%d,%d)→%s" % [char(65 + cell.x), cell.y + 1, cell.x, cell.y, target.get_display_name()])
	if not examples.is_empty():
		return "可干扰落点示例：%s；基础伤害%d，实际以结算为准。其他合法落点仍可选择。" % ["；".join(examples), battle.od_release_rules.get_knight_disruption_damage()]
	if unknown:
		return "特殊射程待实际落点结算后核对；仍可位移并转化热量。"
	return "当前落点暂无可干扰对象；仍可位移并转化热量。"

func _refresh_od_selection_guidance() -> void:
	if not bool(_od_release_context.get("active",false)):
		if is_instance_valid(_od_selection_guidance): _od_selection_guidance.clear()
		return
	if not is_instance_valid(_od_selection_guidance):
		_od_selection_guidance = preload("res://scenes/presentation/card_target_guidance.gd").new()
		_od_selection_guidance.name = "ODSelectionGuidance"
		$MonsterSummonConfirmationLayer.add_child(_od_selection_guidance)
	_od_selection_guidance.reserved_rects = _get_od_feedback_reserved_rects()
	var text := "战术释放：选择已解除召唤病且有合法目标的己方棋子；不领取仪式奖励。右键/Escape取消"
	if StringName(_od_release_context.get("stage", &"")) == &"target":
		var status: Dictionary = battle.get_od_release_source_status(_od_release_context.get("source"))
		for cell in status.get("legal_cells", []):
			var point := _project_tactical_cell_to_screen(cell)
			if point.is_finite(): _od_selection_guidance.reserved_rects.append(Rect2(point - Vector2(35,35),Vector2(70,70)))
		for target in status.get("legal_targets", []):
			var point := _project_tactical_cell_to_screen(battle.get_unit_cell(target))
			if point.is_finite(): _od_selection_guidance.reserved_rects.append(Rect2(point - Vector2(35,35),Vector2(70,70)))
		text = _build_ritual_selection_summary(status) if bool(_od_release_context.get("final_convergence",false)) else _build_tactical_release_summary(status)
		if not status.get("ok",false): text = "OD 未支付：" + _od_release_reason_text(status) + "；右键/Escape取消"
	var no_targets: Array[Dictionary] = []
	_od_selection_guidance.show_targets(no_targets, text)
	_place_od_guidance_in_gap(_od_selection_guidance)

func _get_od_feedback_reserved_rects() -> Array[Rect2]:
	var reserved := _get_structure_reserved_ui_rects()
	for path in ["GB1Help", "ViewModeControl", "BattleNavigationControl"]:
		var panel := get_node_or_null(path) as Control
		if panel != null and panel.is_visible_in_tree():
			reserved.append(panel.get_global_rect().grow(8))
	if is_instance_valid(_boss_status_hud):
		reserved.append(_boss_status_hud.get_global_rect().grow(8))
	for panel in [_od_engine_greybox, _od_release_control]:
		if is_instance_valid(panel) and panel.is_visible_in_tree():
			reserved.append(panel.get_global_rect().grow(8))
	return reserved

func _place_od_guidance_in_gap(guidance: Control) -> void:
	# The long decision summary may need a gap between the target badges and hand.
	var banner_rect: Rect2 = guidance.instruction_rect()
	if not _is_notification_rect_safe(banner_rect, guidance.reserved_rects, get_viewport_rect().size, 12):
		for reserved: Rect2 in guidance.reserved_rects:
			var candidate := Rect2(Vector2((get_viewport_rect().size.x-banner_rect.size.x)*0.5, reserved.end.y+8), banner_rect.size)
			if _is_notification_rect_safe(candidate, guidance.reserved_rects, get_viewport_rect().size, 12):
				guidance._banner.position = candidate.position
				break

func _od_release_receipt_text(receipt: Dictionary) -> String:
	var action: Dictionary = receipt.get("action_result",{})
	var effect := ""
	match StringName(receipt.get("piece_type", &"")):
		&"pawn": effect = "推进完成，护盾+%d" % int(action.get("formation_shield",0))
		&"knight": effect = "跃迁完成，干扰实际伤害%d" % int(action.get("disruption",{}).get("applied",0))
		&"bishop":
			var attack: Dictionary = action.get("attack",{})
			effect = "交战完成，目标实际受伤%d" % int(attack.get("target_damage",attack.get("damage",0)))
		&"rook": effect = "接力已准备：%d名友军" % int(action.get("relay",{}).get("granted",0))
	return "战术释放已结算：热量%d→%d，L%d→L%d，指令-%d；%s" % [int(receipt.get("heat_before",0)),int(receipt.get("heat_after",0)),int(receipt.get("layer_before",1)),int(receipt.get("layer_after",1)),int(action.get("cost",0)),effect]

func _show_od_release_receipt(receipt: Dictionary) -> void:
	var visual := preload("res://scenes/presentation/card_target_guidance.gd").new()
	visual.name = "TacticalODReceipt"
	$MonsterSummonConfirmationLayer.add_child(visual)
	visual.reserved_rects = _get_od_feedback_reserved_rects()
	var no_targets: Array[Dictionary] = []
	visual.show_targets(no_targets, _od_release_receipt_text(receipt))
	_place_od_guidance_in_gap(visual)
	var lifetime := create_tween()
	lifetime.tween_interval(3.5)
	lifetime.tween_callback(func() -> void:
		if is_instance_valid(visual): visual.queue_free())

func _build_ritual_selection_summary(source_status: Dictionary) -> String:
	if battle == null or not battle.is_ritual_finisher_trial_enabled():
		return "选择 OD 释放目标"
	var final_status: Dictionary = battle.get_final_convergence_status("player")
	var path: String = str(_od_release_context.get("ritual_path", "early"))
	var overcharge: bool = bool(_od_release_context.get("ritual_overcharge", false))
	var mode: String = "overcharge" if overcharge else "normal"
	var preview: Dictionary = (final_status.get("path_previews", {}) as Dictionary).get(path, {}).get(mode, {})
	var name: String = "提前释放" if path == "early" else "锋线点火" if path == "attack" else "阵地导流"
	var heat: int = int(final_status.get("heat", 0))
	var cost: int = int(source_status.get("od_cost", 5))
	var summary := "%s：OD %d→%d，指令 -%d，Boss HP 预计 -%d" % [
		name, heat, maxi(0, heat - cost), int(source_status.get("command_cost", 0)), int(preview.get("actual_hp_loss", 0))]
	if int(preview.get("phase_lock", 0)) > 0:
		summary += "，阶段锁 %d／溢出 %d" % [int(preview.phase_lock), int(preview.get("overflow", 0))]
	if overcharge:
		summary += "，Depth %d→%d%s" % [int(final_status.get("depth", 0)), int(preview.get("depth_after", 0)), "（反噬）" if bool(preview.get("backlash", false)) else ""]
	return summary

func _confirm_od_release_target(target: Variant) -> bool:
	if not bool(_od_release_context.get("active", false)) or StringName(_od_release_context.get("stage", &"")) != &"target":
		return false
	var source: CardData = _od_release_context.get("source", null)
	var check: Dictionary = battle.get_od_release_target_status(source, target)
	if not bool(check.get("ok", false)):
		if action_feed:
			action_feed.push_message("OD 未支付：" + _od_release_reason_text(check), TC.WARNING, "", 1.5)
		_refresh_od_release_control()
		return true
	_od_release_transaction_serial += 1
	if _od_release_control != null:
		_od_release_control.set_busy(true, "OD 释放中")
	var tx := StringName("gui_od_release_%d" % _od_release_transaction_serial)
	_od_release_presentation_facts_by_tx[tx] = _build_od_release_presentation_facts(source, target, check)
	var is_final: bool = bool(_od_release_context.get("final_convergence", false))
	var final_options := {"transaction_id": tx,
		"ritual_path": str(_od_release_context.get("ritual_path", "early")),
		"ritual_overcharge": bool(_od_release_context.get("ritual_overcharge", false))}
	var result: Dictionary = battle.execute_final_convergence("player", source, target, final_options) \
		if is_final else battle.execute_od_release("player", source, target, {"transaction_id": tx})
	_od_release_presentation_facts_by_tx.erase(tx)
	if bool(result.get("ok", false)):
		if _playtest and is_final:
			_playtest.record_event("final_convergence", {"piece_type": result.get("piece_type", &""), "heat": result.get("od_cost", 0)})
		if action_feed:
			if is_final and result.has("ritual_path"):
				action_feed.push_message("炉心汇流：Boss HP -%d，OD %d→%d，Depth %d→%d" % [
					int(result.get("final_actual_hp_loss", 0)), int(result.get("ritual_boss_od_before", 0)),
					int(result.get("ritual_boss_od_after", 0)), int(result.get("ritual_depth_before", 0)),
					int(result.get("ritual_depth_after", 0))], Color(1.0, 0.75, 0.2), "", 3.0)
			else:
				action_feed.push_message(_od_release_receipt_text(result), Color(0.25, 0.95, 1.0), "", 3.5)
		_clear_od_release_selection(&"success")
		_refresh_tables()
		if not is_final: _show_od_release_receipt(result)
	else:
		if action_feed:
			action_feed.push_message("OD 释放失败：%s" % str(result.get("reason_code", "unknown")), TC.WARNING, "", 2.0)
		_clear_od_release_selection(&"failure")
	return true


func _build_od_release_presentation_facts(source: CardData, target: Variant, status: Dictionary) -> Dictionary:
	var source_cell := battle.get_unit_cell(source) if battle != null and source != null else Vector2i(-1, -1)
	var target_cell := Vector2i(-1, -1)
	if target is Vector2i:
		target_cell = target
	elif target is CardData and battle != null:
		target_cell = battle.get_unit_cell(target as CardData)
	var target_position := Vector2.INF
	if target is CardData:
		var target_token := _get_3d_token_for_card(target as CardData)
		if target_token != null:
			target_position = _project_3d_token_to_screen(target_token)
	elif target_cell != Vector2i(-1, -1):
		var target_anchor := _get_3d_surface_anchor_for_cell(target_cell)
		if target_anchor != null:
			target_position = _project_world_position_to_screen(target_anchor.global_position)
			_record_elevated_grid_endpoint(&"od_release_cell", target_cell, target_anchor.global_position, target_position)
	var engine_position := Vector2.INF
	if _od_engine_greybox != null and is_instance_valid(_od_engine_greybox):
		var engine_rect := _od_engine_greybox.get_global_rect()
		engine_position = Vector2(engine_rect.get_center().x, engine_rect.end.y - 8.0)
	var conduit_points: Array[Vector2] = []
	if engine_position != Vector2.INF:
		conduit_points.append(engine_position)
	if engine_position != Vector2.INF and target_position != Vector2.INF:
		conduit_points.append(Vector2((engine_position.x + target_position.x) * 0.5, minf(engine_position.y, target_position.y) - 28.0))
	if target_position != Vector2.INF:
		conduit_points.append(target_position)
	return {
		"source_cell": source_cell,
		"target_cell": target_cell,
		"target_position": target_position,
		"engine_position": engine_position,
		"conduit_points": conduit_points,
		"piece_type": StringName(status.get("piece_type", &"")),
	}.duplicate(true)

func _clear_od_release_selection(_reason: StringName = &"cleanup") -> void:
	_od_release_context = {"active": false, "stage": &"", "source": null, "source_status": {}, "final_convergence": false}
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.clear_preview()
	if _end_turn_control and is_instance_valid(_end_turn_control):
		_end_turn_control.set_busy(false, "")
	_refresh_od_release_control()
	_refresh_command_economy_surfaces()
func _make_eg_label(prefix: String, parent: Control, color: Color) -> Label:
		var lbl := Label.new()
		lbl.name = "EGInfo_%s" % prefix
		lbl.text = "%s: ?" % prefix
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", color)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.clip_text = true
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(lbl)
		return lbl
# Phase 27D-R3: Command Economy HUD configuration
func _configure_command_economy_hud() -> void:
	if _command_economy_hud == null or not is_instance_valid(_command_economy_hud):
		return
	_command_economy_hud.configure(Callable(self, "_get_command_economy_for_hud"))
	_command_economy_hud.set_depth_provider(Callable(self, "_get_depth_info_for_hud"))

func _get_command_economy_for_hud() -> Dictionary:
	if battle and battle.has_method("get_command_economy_snapshot"):
		return battle.get_command_economy_snapshot("player")
	return {}

func _get_depth_info_for_hud() -> Dictionary:
	var info := {"depth": 0, "max": 6, "zone": ""}
	if context:
		info.depth = context.turn_depth
		info.max = context.get_depth_max_value() if context.has_method("get_depth_max_value") else 6
		if context.has_method("get_depth_zone"):
			info.zone = context.get_depth_zone()
	return info

func _refresh_command_economy_hud() -> void:
	if _command_economy_hud and is_instance_valid(_command_economy_hud):
		_command_economy_hud.refresh()

# Phase 27E-R5: unified refresh for all command economy surfaces
func _refresh_command_economy_surfaces() -> void:
	_refresh_command_economy_hud()
	if _end_turn_control and is_instance_valid(_end_turn_control):
		_end_turn_control.refresh()

func _play_command_economy_gain(amount: int) -> void:
	if _command_economy_hud and is_instance_valid(_command_economy_hud) and amount > 0:
		_command_economy_hud.play_gain(amount)
	_refresh_command_economy_surfaces()  # Phase 27E-R5

func _play_command_economy_spend(amount: int) -> void:
	if _command_economy_hud and is_instance_valid(_command_economy_hud) and amount > 0:
		_command_economy_hud.play_spend(amount)
	_refresh_command_economy_surfaces()  # Phase 27E-R5

func _play_command_economy_refund(amount: int) -> void:
	if _command_economy_hud and is_instance_valid(_command_economy_hud) and amount > 0:
		_command_economy_hud.play_refund(amount)
	_refresh_command_economy_surfaces()  # Phase 27E-R5

# Phase 9B: 鐎瑰鍙忕紒鍫燁剾 Engine Gauge 閼村鍟?tween
func _safe_kill_eg_pulse() -> void:
	if _engine_gauge_pulse_tween and _engine_gauge_pulse_tween.is_valid():
		_engine_gauge_pulse_tween.kill()
	_engine_gauge_pulse_tween = null

func _update_core_status_panel() -> void:
	if not context or not context.od_mode:
		return

	var om = context.od_mode
	var summary := om.get_engine_summary()
	var layer: int = summary.get("layer", 1)
	var charge: int = summary.get("charge", 0)
	var capacity: int = summary.get("capacity", 3)
	var progress: float = summary.get("progress", 0.0)
	var compat_od: int = summary.get("compat_od", 0)
	var burst_turns: int = summary.get("burst_turns", 0)

	# 妫版粏澹婇弫鎵矋
	var layer_colors: Array[Color] = [
		Color(0.18, 0.80, 0.25, 1),
		Color(0.00, 0.81, 0.82, 1),
		Color(0.20, 0.60, 0.86, 1),
		Color(0.56, 0.27, 0.68, 1),
		Color(1.0, 0.25, 0.06, 1),
	]

	# 閳光偓閳光偓 Phase 10F: 閸婄厧褰夐崠鏍梾濞?閳?鐟欙箑褰?VFX 閳光偓閳光偓
	if _eg_vfx_initialized:
		# [Fixed]
		if layer == _last_eg_layer_for_vfx and charge > _last_eg_charge_for_vfx:
			var ci := layer - 1
			if ci >= 0 and ci < _engine_gauge_progress_bars.size():
				var bar := _engine_gauge_progress_bars[ci]
				if is_instance_valid(bar) and battle_vfx:
					battle_vfx.play_engine_charge_tick(bar, layer)
				var am_charge = _am(); if am_charge: am_charge.play_od_charge_tick()
		# [Fixed]
		if layer > _last_eg_layer_for_vfx:
			# 閸撳秳绔寸仦鍌氱暚閹存劕濮╅悽?
			var prev_li := _last_eg_layer_for_vfx - 1
			if prev_li >= 0 and prev_li < _engine_gauge_progress_bars.size():
				var prev_bar := _engine_gauge_progress_bars[prev_li]
				if is_instance_valid(prev_bar) and battle_vfx:
					battle_vfx.play_engine_layer_complete(prev_bar, _last_eg_layer_for_vfx)
			var core_panel := get_node_or_null(NodePath("BattleTable/CoreStatusPanel")) as Control
			if core_panel and battle_vfx:
				battle_vfx.play_engine_layer_up(core_panel, layer)
			var am_layer = _am(); if am_layer: am_layer.play_od_layer_up()
		# Burst: 鏉╂稑鍙?burst_turns
		if burst_turns > 0 and _last_eg_burst_turns_for_vfx == 0:
			var battle_table := get_node_or_null(NodePath("BattleTable")) as Control
			if battle_table and battle_vfx:
				battle_vfx.play_burst_flash(battle_table)
			var am_burst = _am(); if am_burst: am_burst.play_burst()
		# Depth warning
		var depth_now := context.depth_pressure
		if depth_now > _last_eg_depth_for_vfx and depth_now >= 3:
			var core_panel := get_node_or_null(NodePath("BattleTable/CoreStatusPanel")) as Control
			if core_panel and battle_vfx:
				battle_vfx.play_depth_warning(core_panel, depth_now)
			var am_depth = _am(); if am_depth: am_depth.play_depth_warning()
		# Depth zone change to Backlash
		var dz := context.get_depth_zone() if context.has_method("get_depth_zone") else "Stable"
		if dz == "Backlash" and _last_eg_depth_for_vfx < 6:
			var core_panel := get_node_or_null(NodePath("BattleTable/CoreStatusPanel")) as Control
			if core_panel and battle_vfx:
				battle_vfx.play_depth_warning(core_panel, 6)

	# 閺囧瓨鏌婃潻鍊熼嚋閸?
	_last_eg_layer_for_vfx = layer
	_last_eg_charge_for_vfx = charge
	_last_eg_depth_for_vfx = context.depth_pressure
	_last_eg_burst_turns_for_vfx = burst_turns
	_eg_vfx_initialized = true

	# Phase 10F: 妫ｆ牗顐奸崚婵嗩潗閸栨牕鎮?kill 閺冄呮畱 _engine_gauge_pulse_tween閿涘矂浼╅崗宥呭蓟 pulse 閸愯尙鐛?	_safe_kill_eg_pulse()

	# 閳光偓閳光偓 Phase 10F: 娴滄柨鐪板Ο顏呮蒋娑撳鈧浇顫嬬憴?閳光偓閳光偓
	for li in range(5):
		var layer_idx := li + 1
		if li >= _engine_gauge_progress_bars.size():
			continue
		var bar_fill: ColorRect = _engine_gauge_progress_bars[li]
		if not is_instance_valid(bar_fill):
			continue
		var bar_bg: Control = bar_fill.get_parent()
		if not is_instance_valid(bar_bg):
			continue

		var status_label: Label = null
		if li < _engine_gauge_status_labels.size():
			status_label = _engine_gauge_status_labels[li]

		var name_label: Label = null
		if li < _engine_gauge_labels.size():
			name_label = _engine_gauge_labels[li]

		if layer_idx < layer:
			# 閳光偓閳光偓 瀹告彃鐣幋鎰湴閿涙碍鏁圭紓?+ 娴ｅ簼瀵?閳光偓閳光偓
			bar_fill.size = Vector2(bar_bg.size.x, bar_bg.size.y * 0.38)
			bar_fill.position.y = (bar_bg.size.y - bar_bg.size.y * 0.38) * 0.5
			bar_fill.color = Color(0.04, 0.15, 0.18, 0.45)
			if status_label and is_instance_valid(status_label):
				status_label.text = "DONE"
				status_label.add_theme_font_size_override("font_size", 8)
				status_label.add_theme_color_override("font_color", Color(0.18, 0.35, 0.25, 0.55))
			if name_label and is_instance_valid(name_label):
				name_label.add_theme_font_size_override("font_size", 8)
				name_label.add_theme_color_override("font_color", Color(0.18, 0.35, 0.25, 0.55))
		elif layer_idx == layer:
			# 閳光偓閳光偓 瑜版挸澧犵仦鍌︾窗閺€鎯с亣 + 妤傛ü瀵?+ pulse 閳光偓閳光偓
			bar_fill.size = Vector2(bar_bg.size.x * progress, bar_bg.size.y)
			bar_fill.position.y = 0
			bar_fill.color = layer_colors[li].lightened(0.15)
			bar_bg.modulate = Color(1, 1, 1, 0.92)
			if status_label and is_instance_valid(status_label):
				status_label.text = "%d/%d" % [charge, capacity]
				status_label.add_theme_font_size_override("font_size", 11)
				status_label.add_theme_color_override("font_color", layer_colors[li])
			if name_label and is_instance_valid(name_label):
				name_label.add_theme_font_size_override("font_size", 10)
				name_label.add_theme_color_override("font_color", layer_colors[li])
			# Phase 10F: 閻?BattleVFXController 缁狅紕鎮婅ぐ鎾冲鐏?pulse
			if battle_vfx:
				battle_vfx.play_engine_current_pulse(bar_fill, layer)
		else:
			# 閳光偓閳光偓 閺堫亣袙闁夸礁鐪伴敍姘閼?+ 娴?alpha 閳光偓閳光偓
			bar_fill.size = Vector2(0, bar_bg.size.y * 0.32)
			bar_fill.position.y = (bar_bg.size.y - bar_bg.size.y * 0.32) * 0.5
			bar_fill.color = Color(0.04, 0.04, 0.07, 0.3)
			if status_label and is_instance_valid(status_label):
				status_label.text = "LOCKED"
				status_label.add_theme_font_size_override("font_size", 8)
				status_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.16, 0.55))
			if name_label and is_instance_valid(name_label):
				name_label.add_theme_font_size_override("font_size", 8)
				name_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.16, 0.55))

	# 閳光偓閳光偓 鎼存洟鍎存穱鈩冧紖 閳光偓閳光偓
	var zone_name := om.get_zone_name()
	if _engine_gauge_od_label and is_instance_valid(_engine_gauge_od_label):
		_engine_gauge_od_label.text = "OD %d/10 %s" % [compat_od, zone_name]
		_engine_gauge_od_label.add_theme_color_override("font_color", om.get_zone_color())
	if _engine_gauge_load_label and is_instance_valid(_engine_gauge_load_label):
		_engine_gauge_load_label.visible = false
	if _engine_gauge_depth_label and is_instance_valid(_engine_gauge_depth_label):
		var dv := context.depth_pressure
		var dz2 := context.get_depth_zone() if context.has_method("get_depth_zone") else "Stable"
		var depth_color := Color(0.3, 0.6, 1, 1)
		var depth_prefix := "Depth"
		if dz2 == "Warning":
			depth_color = Color(0.95, 0.4, 0.05, 1)
			# Phase 11C: Depth 妫ｆ牗顐肩拃锕€鎲￠幓鎰仛
			_show_tutorial_hint_once("depth_warning", "Depth 警告：透支会增加 Depth；部分控制牌和建筑效果可帮助降压。")
			depth_prefix = "!DEPTH"
		elif dz2 == "Backlash":
			depth_color = Color(0.95, 0.05, 0.2, 1)
			depth_prefix = "!!BACKLASH"
		_engine_gauge_depth_label.text = "%s %d/%d %s" % [depth_prefix, dv, context.get_depth_max_value(), dz2]
		_engine_gauge_depth_label.add_theme_color_override("font_color", depth_color)
		_engine_gauge_depth_label.add_theme_font_size_override("font_size", 10 if dz2 == "Stable" else 12)
	if _engine_gauge_burst_label and is_instance_valid(_engine_gauge_burst_label):
		var bl := context.backlash_turns_remaining if context else 0
		if burst_turns > 0 and bl <= 0:
			_engine_gauge_burst_label.text = "BURST: %dT" % burst_turns
			_engine_gauge_burst_label.add_theme_color_override("font_color", Color(1, 0.85, 0.0, 1))
			_engine_gauge_burst_label.add_theme_font_size_override("font_size", 12)
			_engine_gauge_burst_label.visible = true
		elif bl > 0:
			_engine_gauge_burst_label.text = "BACKLASH: %dT" % bl
			_engine_gauge_burst_label.add_theme_color_override("font_color", Color(0.95, 0.05, 0.2, 1))
			_engine_gauge_burst_label.add_theme_font_size_override("font_size", 12)
			_engine_gauge_burst_label.visible = true
		else:
			_engine_gauge_burst_label.visible = false
	# Phase 27K-R0: Heat/Charge/Layer/Zone 变化同步驱动灰盒刷新
	_refresh_od_engine_greybox()

	# Phase 26C: Update core command button text from authoritative state
	if _core_command_button and is_instance_valid(_core_command_button):
		if battle and battle.has_method("get_core_command_state"):
			var cs: Dictionary = battle.get_core_command_state()
			var used: int = cs.get("used", 0)
			var limit: int = cs.get("limit", 1)
			var charge_now: int = context.get_engine_charge() if context else 0
			_core_command_button.text = "OD %d/%d" % [used, limit]
			_core_command_button.tooltip_text = "充能 %d | 增压(2) 泄压(3)" % charge_now

	# Phase 27D-R3: sync command economy HUD with engine gauge cycle
	_refresh_command_economy_hud()

# ── Phase 26C: Core Command Panel ──

# PHASE53_BEGIN_SURGE
var _core_surge_selecting := false
var _core_surge_committing := false
var _core_surge_turn := -1
func _core_surge_pointer_is_gui(position: Vector2) -> bool:
	var hovered: Control=get_viewport().gui_get_hovered_control()
	while hovered!=null:
		if hovered is BaseButton or hovered is CardUI or hovered is ScrollContainer or hovered is PanelContainer or hovered is Panel:
			if hovered.is_visible_in_tree() and hovered.get_global_rect().has_point(position):return true
		hovered=hovered.get_parent_control()
	for control: Control in [get_node_or_null("HandArea"),_core_command_button,_core_command_panel,_end_turn_control]:
		if is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_point(position):return true
	return false
func _core_surge_window_open() -> bool:
	if _core_surge_committing or battle==null or context==null or context.player==null or context.enemy==null or context.player.hp<=0 or context.enemy.hp<=0:return false
	if battle_ended or _card_being_played or _spell_end_turn_blocked or _presentation_end_turn_blocked or _exit_modal_active:return false
	if battle._od_release_resolving or battle._siege_command_in_progress:return false
	if _battle_presentation_director!=null and is_instance_valid(_battle_presentation_director) and _battle_presentation_director.is_busy():return false
	if _is_lane_selection_active() or _is_piece_selection_active() or _is_monster_summon_interaction_active() or _building_replace_select_active:return false
	if _garrison_context.get("active",false) or _od_release_context.get("active",false) or _skill_context.get("active",false):return false
	return battle.get_core_command_state().get("player_turn_open",false)
func _clear_core_surge_selection() -> void:
	if _core_surge_committing or not _core_surge_selecting:return
	_core_surge_selecting=false;_core_surge_turn=-1
	_release_idle_end_turn_busy()
func _begin_core_surge_selection() -> void:
	if not _core_surge_window_open():return
	var legal := false
	for target: CardData in context.player.field:
		if is_instance_valid(target) and battle.get_core_command_status(&"surge",target).get("ok",false):legal=true;break
	if not legal:return
	_close_monster_command_menu();_clear_attack_selection()
	_core_surge_selecting=true;_core_surge_turn=context.turn_count
	if _end_turn_control!=null and is_instance_valid(_end_turn_control):_end_turn_control.set_busy(true,"增压：选择我方棋子；Esc取消")
func _dispatch_core_surge_target(target: CardData, side: String) -> bool:
	if not _core_surge_selecting:return false
	if not _core_surge_window_open() or context.turn_count!=_core_surge_turn:
		_clear_core_surge_selection();return true
	if not is_instance_valid(target) or side!="player" or target not in context.player.field:return true
	var status: Dictionary=battle.get_core_command_status(&"surge",target)
	if not status.get("ok",false):return true
	# Clear intent before the original spend emits signals; duplicate input is inert.
	_core_surge_selecting=false;_core_surge_turn=-1
	_core_surge_committing=true
	var result: Dictionary=battle.execute_core_command(&"surge",target)
	_handle_core_command_result(result)
	_core_surge_committing=false;_release_idle_end_turn_busy()
	return true
# PHASE53_END_SURGE
func _is_live_player_redeploy_actor(card: CardData) -> bool:
	if not is_instance_valid(card) or battle == null or context == null or context.player == null: return false
	if card not in context.player.field or (card.card_family != "monster" and card.card_type != CardData.CardType.UNIT): return false
	var state: Dictionary = battle.get_unit_combat_state(card)
	return not state.is_empty() and state.get("owner_side") == &"player" and int(state.get("current_hp", 0)) > 0 and battle.get_unit_lane(card) >= 0


func _on_core_command_button_pressed() -> void:
	# PHASE53_BEGIN_BUTTON
	if _core_surge_committing:return
	_clear_core_surge_selection()
	# PHASE53_END_BUTTON
	if _core_command_panel and is_instance_valid(_core_command_panel):
		_core_command_panel.queue_free()
		_core_command_panel = null
		return
	if battle == null or not battle.has_method("get_core_command_state"):
		return
	var cs: Dictionary = battle.get_core_command_state()
	if cs.get("used", 0) >= cs.get("limit", 1):
		return

	_core_command_panel = ODCoreCommandPanelClass.new()
	_core_command_panel.name = "CoreCommandPanel"
	_core_command_panel.z_index = ZI_GRAVEYARD_VIEW
	_core_command_panel.setup()
	var redeploy_actors: Array[Dictionary] = []
	if context and context.player:
		for raw_card in context.player.field:
			var card := raw_card as CardData
			if _is_live_player_redeploy_actor(card):
				var cell: Vector2i = battle.get_unit_cell(card)
				var label := "%s · %d列%d排" % [card.get_display_name(), cell.x + 1, cell.y + 1]
				redeploy_actors.append({"runtime_id": card.get_instance_id(), "label": label})
	_core_command_panel.set_redeploy_actors(redeploy_actors)
	add_child(_core_command_panel)
	if _core_command_button and is_instance_valid(_core_command_button):
		var btn_pos: Vector2 = _core_command_button.global_position
		_core_command_panel.position = btn_pos + Vector2(0, _core_command_button.size.y + 4)

	_core_command_panel.command_requested.connect(_on_core_command_requested)
	_update_core_command_view_model()


func _on_core_command_requested(command_id: StringName) -> void:
	if battle == null:
		return
	var selected_redeploy_uid: int = 0
	if command_id == &"redeploy" and _core_command_panel and is_instance_valid(_core_command_panel):
		selected_redeploy_uid = _core_command_panel.get_redeploy_actor_uid()
	if _core_command_panel and is_instance_valid(_core_command_panel):
		_core_command_panel.queue_free()
		_core_command_panel = null

	# PHASE53_BEGIN_REQUEST
	if _core_surge_committing:return
	_clear_core_surge_selection()
	if command_id==&"surge":
		_begin_core_surge_selection()
	# PHASE53_END_REQUEST
	if command_id == &"vent":
		var result: Dictionary = battle.execute_core_command(&"vent")
		_handle_core_command_result(result)
	elif command_id == &"surge":
		if action_feed:
			action_feed.push_message("核心指令·增压：请在场上选择一只可攻击的我方怪兽", TC.TEXT_PRIMARY)
	elif command_id == &"redeploy":
		# PHASE55_BEGIN_REQUEST
		if not _core_surge_window_open():return
		# PHASE55_END_REQUEST
		# Phase 26E-R1 Task 6: auto-select first living player front monster for redeploy
		var candidate: CardData = null
		if selected_redeploy_uid > 0:
			if context and context.player:
				for raw_card in context.player.field:
					var card := raw_card as CardData
					if is_instance_valid(card) and card.get_instance_id() == selected_redeploy_uid and _is_live_player_redeploy_actor(card):
						candidate = card
						break
			if candidate == null:
				if action_feed: action_feed.push_message("选中的棋子已无法调轨，请重新选择", TC.WARNING, "", 2.0)
				return
		elif context and context.player:
			for raw_card in context.player.field:
				var c := raw_card as CardData
				if c == null:
					continue
				if c.card_family != "monster" and c.card_type != CardData.CardType.UNIT:
					continue
				if battle.get_unit_lane(c) >= 0:
					candidate = c
					break
		if candidate:
			_begin_unit_move_selection(candidate, battle.MOVE_CORE_REDEPLOY)
		else:
			if action_feed:
				action_feed.push_message("没有可调轨的我方前场怪兽", TC.WARNING, "", 2.0)


func _handle_core_command_result(result: Dictionary) -> void:
	# Phase 26C: Record telemetry
	if _playtest and _playtest.has_method("record_core_command_result"):
		_playtest.record_core_command_result(result)

	if result.get("ok", false):
		var cmd_id: String = str(result.get("command_id", ""))
		if cmd_id == "vent":
			var before: int = result.get("depth_before", 0)
			var after: int = result.get("depth_after", 0)
			if action_feed:
				action_feed.push_message("核心指令·泄压：Depth %d→%d" % [before, after], Color(0.3, 0.6, 1, 1))
		elif cmd_id == "surge":
			var atk_before: int = result.get("attack_before", 0)
			var atk_after: int = result.get("attack_after", 0)
			var target_name: String = str(result.get("target_card_id", "?"))
			if action_feed:
				action_feed.push_message("核心指令·增压：%s ATK %d→%d，本回合有效" % [target_name, atk_before, atk_after], Color(0.35, 0.9, 0.9, 1))
		_update_core_status_panel()
	else:
		var reason: String = str(result.get("reason_code", "?"))
		if action_feed:
			action_feed.push_message("核心指令失败：%s" % reason, Color(0.95, 0.4, 0.05, 1))


func _update_core_command_view_model() -> void:
	if not _core_command_panel or not is_instance_valid(_core_command_panel):
		return
	if battle == null or not battle.has_method("get_core_command_state"):
		return
	var cs: Dictionary = battle.get_core_command_state()
	var used: int = cs.get("used", 0)
	var limit: int = cs.get("limit", 1)
	var charge_now: int = context.get_engine_charge() if context else 0
	var capacity: int = context.get_engine_charge_capacity() if context else 0

	var surge_status: Dictionary = battle.get_core_command_status(&"surge", null)
	var vent_status: Dictionary = battle.get_core_command_status(&"vent", null)

	var surge_enabled: bool = used < limit and surge_status.get("reason_code", "") == "invalid_target"
	var vent_enabled: bool = bool(vent_status.get("ok", false))

	# Phase 26E-R1 Task 6: redeploy — check general availability
	var redeploy_enabled := false
	var redeploy_reason := ""
	if used >= limit:
		redeploy_reason = "本回合核心指令已使用"
	elif context and context.is_abyss_locked():
		redeploy_reason = "Backlash 中无法调轨"
	elif charge_now < 1:
		redeploy_reason = "充能不足"
	elif not _has_living_player_front_monster():
		redeploy_reason = "没有存活的我方前场怪兽"
	else:
		redeploy_enabled = true

	_core_command_panel.apply_view_model({
		"usage_text": "本回合 %d/%d" % [used, limit],
		"charge_text": "充能 %d/%d" % [charge_now, capacity],
		"surge_enabled": surge_enabled,
		"surge_reason_text": _core_command_reason_text(surge_status.get("reason_code", &"")),
		"vent_enabled": vent_enabled,
		"vent_reason_text": _core_command_reason_text(vent_status.get("reason_code", &"")),
		"redeploy_enabled": redeploy_enabled,
		"redeploy_reason_text": redeploy_reason,
	})


func _has_living_player_front_monster() -> bool:
	if context == null or context.player == null:
		return false
	for raw_card in context.player.field:
		var card := raw_card as CardData
		if card == null:
			continue
		if card.card_family != "monster" and card.card_type != CardData.CardType.UNIT:
			continue
		if battle and battle.has_method("get_unit_lane"):
			if battle.get_unit_lane(card) >= 0:
				return true
	return false


func _core_command_reason_text(reason_code: StringName) -> String:
	match reason_code:
		&"not_player_turn": return "仅能在玩家回合使用"
		&"already_used_this_turn": return "本回合核心指令已使用"
		&"insufficient_charge": return "充能不足"
		&"backlash_restricted": return "Backlash 中无法增压"
		&"invalid_target": return "请选择合法的我方前场怪兽"
		&"target_already_attacked": return "该怪兽本回合已无法攻击"
		&"depth_already_zero": return "Depth 已经为 0"
		&"unknown_command": return "未知指令"
		_: return ""


# ── end Phase 26C panel ──

func _setup_detail_panel_compact() -> void:

	_detail_panel_slot = get_node_or_null(NodePath("DetailPanelSlot")) as Control
	if not _detail_panel_slot:
		return
	# Phase 27K-R0-R: 空详情区默认隐藏 + IGNORE，不显示占位文字、不悬停展开。
	# 详情区只由真实卡牌生命周期（card_detail_panel.visible）驱动。
	_detail_panel_compact_label = null
	_detail_panel_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel_slot.visible = false
	_detail_panel_expanded = false


## Development-only launch hook used by the isolated Phase B/C/D manual scenes.
## Normal battles never call it; the fixture may hide the detail host, but it
## cannot alter combat, terrain, structure or garrison authority.
func _set_development_showcase_mode(enabled: bool) -> void:
	_development_showcase_mode = enabled
	if not enabled:
		_development_showcase_reduced_motion = false
	if enabled and player_table != null and player_table.card_detail_panel != null \
			and is_instance_valid(player_table.card_detail_panel):
		player_table.card_detail_panel.visible = false
		if player_table.has_method("clear_pinned_detail"):
			player_table.clear_pinned_detail()
	_set_detail_panel_expanded(false, true, false)
	if not enabled:
		_sync_detail_panel_compact()


func _set_development_showcase_reduced_motion(enabled: bool) -> void:
	if _development_showcase_mode:
		_development_showcase_reduced_motion = enabled


func _on_detail_slot_mouse_entered() -> void:
	# Phase 27K-R0-R: 空详情区不悬停展开（详情仅由真实卡牌生命周期触发）
	pass
func _on_detail_slot_mouse_exited() -> void:
	pass
func _sync_detail_panel_compact() -> void:
	if not _detail_panel_slot or not is_instance_valid(_detail_panel_slot):
		return
	var has_card_detail := false
	var detail_pinned := false
	if not _development_showcase_mode and player_table and player_table.card_detail_panel and is_instance_valid(player_table.card_detail_panel):
		has_card_detail = player_table.card_detail_panel.visible
		if player_table.has_method("is_detail_pinned"):
			detail_pinned = bool(player_table.is_detail_pinned())
	# Phase 27K-R0-R: 详情只由真实卡牌生命周期驱动，不再由悬停驱动
	_set_detail_panel_expanded(has_card_detail, false, detail_pinned)
	if _detail_panel_compact_label and is_instance_valid(_detail_panel_compact_label):
		_detail_panel_compact_label.visible = not has_card_detail


func _get_detail_panel_display_rect(pinned: bool) -> Rect2:
	var base_rect := _detail_panel_expanded_rect if pinned else _detail_panel_compact_rect
	var viewport_size := get_viewport_rect().size
	var right_track := get_node_or_null(NodePath("RightTrack")) as Control
	var hand_area := get_node_or_null(NodePath("HandArea")) as Control
	var right_track_left := right_track.position.x if right_track != null else 1404.0
	var hand_top := hand_area.position.y if hand_area != null else 680.0
	var right_edge := minf(right_track_left, viewport_size.x - 20.0)
	var lower_edge := minf(hand_top - 20.0, viewport_size.y - 20.0)
	var x := maxf(20.0, right_edge - base_rect.size.x - 20.0)
	var y := maxf(20.0, lower_edge - base_rect.size.y)
	return Rect2(Vector2(x, y), base_rect.size)


func _set_detail_panel_expanded(expanded: bool, force: bool = false, pinned: bool = false) -> void:
	if not _detail_panel_slot or not is_instance_valid(_detail_panel_slot):
		return
	if _development_showcase_mode:
		expanded = false
		pinned = false
	if not force and _detail_panel_expanded == expanded and _detail_panel_pinned_layout == pinned:
		return
	_detail_panel_expanded = expanded
	_detail_panel_pinned_layout = pinned
	if expanded:
		var rect := _get_detail_panel_display_rect(pinned)
		_detail_panel_slot.offset_left = rect.position.x
		_detail_panel_slot.offset_top = rect.position.y
		_detail_panel_slot.offset_right = rect.position.x + rect.size.x
		_detail_panel_slot.offset_bottom = rect.position.y + rect.size.y
		_detail_panel_slot.visible = true
		_detail_panel_slot.mouse_filter = Control.MOUSE_FILTER_PASS if pinned else Control.MOUSE_FILTER_IGNORE
	else:
		_detail_panel_slot.visible = false
		_detail_panel_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Phase 27I-R0-R2: 详情栏与 Arsenal 互斥——详情展开时隐藏 Arsenal 并禁用输入，不靠 z_index 遮盖
	_sync_arsenal_for_detail(expanded)

## Phase 27I-R0-R2: 详情展开时 Arsenal 隐藏且不拦截鼠标；关闭后恢复
func _sync_arsenal_for_detail(detail_expanded: bool) -> void:
	if _arsenal_panel == null or not is_instance_valid(_arsenal_panel):
		return
	# Phase 27K-R0-R2: 旧 Arsenal 悬停 HUD 禁用时，无论详情状态如何始终隐藏 + IGNORE，
	# 禁止详情关闭后无条件恢复 visible/STOP。
	if not _is_legacy_arsenal_hover_hud_enabled():
		_arsenal_panel.visible = false
		_arsenal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	if detail_expanded:
		_arsenal_panel.visible = false
		_arsenal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		_arsenal_panel.visible = true
		_arsenal_panel.mouse_filter = Control.MOUSE_FILTER_STOP

## Phase 27I-R0-R2: 统一左侧栏布局同步入口（_ready / 详情显示关闭 / Arsenal 建立 / viewport 改变）
func _sync_left_rail_layout() -> void:
	var has_card_detail := false
	var detail_pinned := false
	if not _development_showcase_mode and player_table and player_table.card_detail_panel and is_instance_valid(player_table.card_detail_panel):
		has_card_detail = player_table.card_detail_panel.visible
		if player_table.has_method("is_detail_pinned"):
			detail_pinned = bool(player_table.is_detail_pinned())
	# Phase 27K-R0-R: 详情只由真实卡牌生命周期驱动
	_set_detail_panel_expanded(has_card_detail, false, detail_pinned)
func _setup_avatar_huds() -> void:
	# Boss 婢舵潙鍎?HUD
	var boss_avatar := get_node_or_null(NodePath("BattleTable/BossArea/BossAvatarSlot"))
	if boss_avatar:
		var vbox := VBoxContainer.new()
		vbox.name = "BossHUD"
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		boss_avatar.add_child(vbox)

		_boss_hud_hp = Label.new()
		_boss_hud_hp.name = "HP"
		_boss_hud_hp.add_theme_font_size_override("font_size", 14)
		_boss_hud_hp.add_theme_color_override("font_color", Color(1, 0.35, 0.35, 1))
		_boss_hud_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(_boss_hud_hp)

		_boss_hud_od = Label.new()
		_boss_hud_od.name = "OD"
		_boss_hud_od.add_theme_font_size_override("font_size", 11)
		_boss_hud_od.add_theme_color_override("font_color", Color(1, 0.55, 0.1, 1))
		_boss_hud_od.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(_boss_hud_od)

	# 閻溾晛顔嶆径鏉戝剼 HUD
	var player_avatar := get_node_or_null(NodePath("BattleTable/PlayerArea/PlayerAvatarSlot"))
	if player_avatar:
		var vbox := VBoxContainer.new()
		vbox.name = "PlayerHUD"
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		player_avatar.add_child(vbox)

		_player_hud_hp = Label.new()
		_player_hud_hp.name = "HP"
		_player_hud_hp.add_theme_font_size_override("font_size", 14)
		_player_hud_hp.add_theme_color_override("font_color", Color(0.3, 0.7, 1, 1))
		_player_hud_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(_player_hud_hp)

		_player_hud_od = Label.new()
		_player_hud_od.name = "OD"
		_player_hud_od.add_theme_font_size_override("font_size", 11)
		_player_hud_od.add_theme_color_override("font_color", Color(0.3, 0.5, 1, 1))
		_player_hud_od.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(_player_hud_od)

		_player_hud_depth = Label.new()
		_player_hud_depth.name = "Depth"
		_player_hud_depth.add_theme_font_size_override("font_size", 10)
		_player_hud_depth.add_theme_color_override("font_color", Color(0.4, 0.7, 1, 1))
		_player_hud_depth.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(_player_hud_depth)

func _update_avatar_huds() -> void:
	# Boss HUD
	if _boss_hud_hp and is_instance_valid(_boss_hud_hp):
		if context.enemy:
			var hp_val := 0
			var max_hp := 0
			if "hp" in context.enemy: hp_val = context.enemy.hp
			if "max_hp" in context.enemy: max_hp = context.enemy.max_hp
			_boss_hud_hp.text = "HP: %d/%d" % [hp_val, max_hp]
	if _boss_hud_od and is_instance_valid(_boss_hud_od):
		if context.enemy and "od" in context.enemy:
			_boss_hud_od.text = "OD: %d" % context.enemy.od

	# Player HUD
	if _player_hud_hp and is_instance_valid(_player_hud_hp):
		if context.player:
			var hp_val := 0
			var max_hp := 0
			if "hp" in context.player: hp_val = context.player.hp
			if "max_hp" in context.player: max_hp = context.player.max_hp
			_player_hud_hp.text = "HP: %d/%d" % [hp_val, max_hp]
	if _player_hud_od and is_instance_valid(_player_hud_od):
		var cur_od := 0
		if context.has_method("get_current_od"): cur_od = context.get_current_od()
		_player_hud_od.text = "OD: %d" % cur_od
	if _player_hud_depth and is_instance_valid(_player_hud_depth):
		var depth := 0
		if context: depth = context.turn_depth
		_player_hud_depth.text = "D: %d" % depth

# ============================================================
# 閸楋紕绮嶉崚婵嗩潗閸栨牭绱欐稉?main.gd 娑撯偓閼疯揪绱?# ============================================================
func _setup_deck() -> void:
	var gm = get_node("/root/GameManager")

	# 娴?GameManager 閼惧嘲褰囬幐浣风畽閸栨牜娈?CardLibrary
	var library: CardLibrary = null
	if gm and gm.has_method("get_library"):
		library = gm.get_library()
	else:
		library = CardLibrary.new()
		library.generate_cards()
		add_child(library)  # 娣囨繃瀵斿鏇犳暏闂冨弶顒涢柌濠冩杹

	# Load deck cards from GameManager or library fallback
	var gm_deck = gm.get_deck_cards()
	if library.all_cards.is_empty():
		library.generate_cards()
	if gm_deck.size() > 0:
		# Rebuild from saved card names
		context.player.deck = _rebuild_deck_from_names(library, gm_deck)
	else:
		# Fallback: copy all library cards
		context.player.deck = library.all_cards.duplicate()

	_setup_enemy_deck()

## 閺嶈宓侀崥宥囆為崚妤勩€冩禒?library 闁插秴缂撻崡锛勭矋閿涘牅绻氱拠浣哥穿閻劍婀侀弫鍫礆
func _rebuild_deck_from_names(card_library: CardLibrary, saved_cards: Array) -> Array:
	var result: Array = []
	for saved in saved_cards:
		if saved == null:
			continue
		var name_str := ""
		if saved is CardData:
			name_str = saved.card_name
		elif saved is String:
			name_str = saved
		else:
			continue
		var found := false
		for card in card_library.all_cards:
			if card.card_name == name_str:
				# Phase 27C-R1-R2: 克隆独立 CardData 实体，防止同名卡共享实例
				var cloned := CardData.clone_card_entity(card)
				if cloned != null:
					add_child(cloned)
					result.append(cloned)
					found = true
				break
		if not found:
			print("[Deck] Card '%s' not in library - skipped" % name_str)
	print("[Deck] Rebuilt: %d cards from saved %d" % [result.size(), saved_cards.size()])
	return result

func _build_default_deck() -> Array:
	# Phase 2B: CardLibrary 提供卡牌模板，每张独立克隆为实体卡
	var card_library = CardLibrary.new()
	card_library.generate_cards()
	add_child(card_library)
	var result: Array = []
	for card in card_library.all_cards:
		if card != null:
			var cloned := CardData.clone_card_entity(card)
			if cloned != null:
				add_child(cloned)
				result.append(cloned)
	print("[Deck] Default deck built: %d cards (cloned from library)" % result.size())
	return result

func _setup_enemy_deck() -> void:
	var enemy_deck: Array[CardData] = []
	for i in range(10):
		var edmg := DamageEffect.new()
		edmg.base_damage = randi_range(2, 6)
		var ecard := CardData.new()
		ecard.card_name = "Enemy Attack %d" % (i + 1)
		ecard.card_type = CardData.CardType.SPELL
		ecard.od_cost = 2
		ecard.effects = [edmg]
		add_child(ecard)
		enemy_deck.append(ecard)
	context.enemy.deck = enemy_deck

# ============================================================
# 閸忋劑鍣洪崚閿嬫煀
# ============================================================
func _refresh_tables() -> void:
	_refresh_siege_intent_view()
	_refresh_od_companion_backline()
	_update_core_status_panel()
	_refresh_od_release_control()
	_update_boss_core_visual()
	var dz_boss := context.get_depth_zone() if context.has_method("get_depth_zone") else "Stable"
	if dz_boss == "Warning" or dz_boss == "Backlash":
		_play_boss_action_vfx("back")
	if not _boss_intro_played:
		_play_boss_core_intro()
	# 閻溾晛顔嶉悧灞绢攽
	if player_table:
		player_table.rebuild_hand(context.player.hand)
		player_table.rebuild_field(context.player.field)
		player_table.refresh()
		_rebind_pending_hand_selection()
		# Phase 10A: 鎼存梻鏁ら弨璇插毊 USED 閻樿埖鈧焦鐖ｇ粵?
		if player_table.has_method("apply_monster_attack_used_states") and battle:
			player_table.apply_monster_attack_used_states(battle.get_all_monster_attack_states())

	var current_layer: int = 1
	if context and context.od_mode:
		current_layer = context.od_mode.get_engine_layer()
	if current_layer > _last_player_engine_layer:
		_trigger_slot_unlock_feedback(current_layer)
	_last_player_engine_layer = current_layer

	# 閺佸本鏌熼悧灞绢攽
	if enemy_table:
		enemy_table.rebuild_field(context.enemy.field)
		enemy_table.refresh()

		# Boss 濠垫帗顒撮懘澶婂暱
		if context.enemy.has_method("is_low_hp") and context.enemy.is_low_hp():
			if enemy_table.has_method("start_danger_pulse"):
				enemy_table.start_danger_pulse()
				_animate_boss_core_low_hp()
		else:
			if enemy_table.has_method("stop_danger_pulse"):
				enemy_table.stop_danger_pulse()

	# 閳光偓閳光偓 缂佺喕顓搁弴瀛樻煀 閳光偓閳光偓
	_sync_3d_field_tokens()

	var cur_od: int = context.get_current_od() if context.has_method("get_current_od") else 0
	if cur_od > _stat_max_player_od:
		_stat_max_player_od = cur_od

		# [Fixed]
		if _prev_od != 0 and cur_od != _prev_od:
			var od_delta := cur_od - _prev_od
			if player_table and player_table.has_method("show_od_delta"):
				player_table.show_od_delta(od_delta)
			_add_to_this_turn("OD %+d -> %d" % [od_delta, cur_od], TC.ZONE_CALM)
		_prev_od = cur_od
	if context.enemy and "od" in context.enemy:
		if context.enemy.od > _stat_max_boss_od:
			_stat_max_boss_od = context.enemy.od
	if context.combo_system and context.combo_system.combo_count > _stat_max_combo:
		_stat_max_combo = context.combo_system.combo_count

	# OD overflow detection (Phase Lock -> Boss OD)
	if context.enemy and "od" in context.enemy:
		var od_after := context.enemy.od
		if od_after > _enemy_od_before_card and context.phases_locked_this_turn > 0:
			var gain := od_after - _enemy_od_before_card
			if action_feed:
				action_feed.push_message("Overflow: Boss OD +%d" % gain, TC.ZONE_HEATED)
			if enemy_table and enemy_table.has_method("pulse_od_core"):
				enemy_table.pulse_od_core()
			_show_overflow_indicator(gain)
			_show_phase_lock_indicator(context.phases_locked_this_turn)
			# Phase 4C-4B: Phase Lock 閳?ActionFeed only (not central)
			_enemy_od_before_card = od_after

		# [Fixed]
		if context.enemy and "od" in context.enemy:
			var boss_od_now := context.enemy.od
			if _last_boss_od != 0 and boss_od_now != _last_boss_od:
				var delta := boss_od_now - _last_boss_od
				if delta >= 2:
					if action_feed:
						action_feed.push_message("Boss OD +%d -> %d" % [delta, boss_od_now], TC.ZONE_HEATED)
				elif delta <= -1:
					if action_feed:
						action_feed.push_message("Boss OD %d -> %d" % [delta, boss_od_now], TC.ZONE_CALM)
			_last_boss_od = boss_od_now

		# [Fixed]
		if context.enemy and "traps" in context.enemy:
			var trap_count_now := context.enemy.traps.size()
			if trap_count_now < _last_boss_trap_count:
				if action_feed:
					action_feed.push_message("Boss back-row threat cleared (remaining: %d)" % trap_count_now, TC.ROLE_CONTROL)
			_last_boss_trap_count = trap_count_now

		# Boss 閹板繐娴橀崡鈽呯礄閹镐椒绠欓崠?CardUI 閺囨寧宕查弬鍥х摟閺嶅洨顒烽敍?
	_update_boss_intent_card()

	# Phase 4B-7: 閸掗攱鏌婇弮鎯板殰閸斻劌鍙ч梻顓烆暩閸︽澘鑴婄粣妤嬬礄閺佺増宓侀崣顖濆厴瀹告彃褰夐敍?
	if _graveyard_view and is_instance_valid(_graveyard_view) and _graveyard_view.visible:
		_graveyard_view.hide_gy()

	# Phase 4B-6: 閺囧瓨鏌婇崣鍏呮櫠鏉炪劑浜鹃悧灞界氨/婢ф挸婀寸拋鈩冩殶
	_update_side_panel_labels()

	# Phase 4B-6C: 閺囧瓨鏌婃径鏉戝剼 HUD
	_update_avatar_huds()
	if boss_intent_label:
		var dg := context.enemy.intent_danger if context.enemy else ""
		boss_intent_label.text = _boss_danger_label(dg) if dg != "" else "蓄势中"
		boss_intent_label.add_theme_color_override("font_color", _boss_danger_color(dg) if dg != "" else TC.ZONE_CALM)
	# Boss OD 妫板嫯顒熼幐鍥┿仛閸?
	_boss_od_phase_check()

	# Turn Info
	if turn_info_label:
		var boss_zone := ""
		var boss_od_val := 0
		if context.enemy:
			if "od" in context.enemy:
				boss_od_val = context.enemy.od
			if context.enemy.has_method("get_od_zone_name"):
				boss_zone = context.enemy.get_od_zone_name()

		# Boss OD 閸楅亶娅撴０鍕劅
		var boss_warning := ""
		var boss_color := TC.TEXT_PRIMARY
		if boss_od_val >= 8:
			boss_warning = "  !! BOSS OVERDRIVE !! "
			boss_color = TC.ZONE_OVERDRIVE
		elif boss_od_val >= 7:
			boss_warning = "  Boss Overdrive Imminent!"
			boss_color = TC.ZONE_HEATED

		elif boss_od_val >= 5:
			boss_warning = "  Boss heating up..."
			boss_color = TC.WARNING

		if boss_od_val < 7:
			_boss_od_warn_7 = false

		# Finisher Ready toast
		if not _finisher_ready_toast_shown:
			for c in context.player.hand:
				if c != null and c.rarity == CardData.CardRarity.SUPER and battle.can_play_card(c):
					_show_toast("finisher_ready", "Finisher Ready", TC.ACCENT_GOLD, 2.5)
					_finisher_ready_toast_shown = true
					_trigger_guides_finisher_ready()
					break

		if context.player.is_awakened:
			turn_info_label.text = "AWAKEN!  |  Boss OD:%d [%s]%s" % [boss_od_val, boss_zone, boss_warning]
			turn_info_label.add_theme_color_override("font_color", TC.ACCENT_GOLD)
		else:
			turn_info_label.text = "Your Turn  |  Boss OD:%d [%s]%s" % [boss_od_val, boss_zone, boss_warning]
			turn_info_label.add_theme_color_override("font_color", boss_color)

	# Phase 24A: idempotent HUD refresh after table refresh
	if _boss_status_hud and is_instance_valid(_boss_status_hud):
		_boss_status_hud.refresh_from_enemy()

# ============================================================
# 閻愮懓鍤崙铏瑰閿涘牆鎯堝鏂垮毉閿?
# ============================================================
# Phase 5B-2: 瀵よ櫣鐡氶懛顏勫З鐟欙箑褰傞敍鍦?6/P13/P19缁涘娼悙鐟板毊鐟欙箑褰傞敍?
func _on_building_auto_trigger(card_name: String, message: String) -> void:
	if action_feed:
		action_feed.push_message("%s: %s" % [card_name, message], Color(0.90, 0.55, 0.22, 1))
	_add_to_this_turn("Auto: %s" % card_name, Color(0.90, 0.55, 0.22, 1))
	for source: CardData in context.player.traps:
		if source.card_name == card_name:
			_show_committed_source_feedback(source, Vector2i(-1,-1), message)
			break
	_refresh_tables()
	var board_root := _get_presentation_board_root()
	var center := board_root.global_position + board_root.size * 0.5 if board_root != null else Vector2.ZERO
	_play_generic_presentation(&"building", {"ok": true, "status": &"committed", "label": message, "buff": card_name, "target_position": center})

func _back_row_receipt_text(receipt: Dictionary) -> String:
	match StringName(receipt.get("kind", &"")):
		&"tripwire":
			var text := "已消耗：阻止本次移入，敌军仍支付行动费用"
			if int(receipt.get("opened_column", -1)) >= 0:
				text += "；第%d列穿盾1次已准备，至下个己方回合结束" % (int(receipt.opened_column)+1)
			return text
		&"prepared": return "已消耗：本次实际防伤%d，剩余交战伤害%d" % [int(receipt.get("prevented",0)),int(receipt.get("remaining_damage",0))]
		&"handoff": return "交接已消耗：Boss热量%d→%d，己方热量%d→%d，护盾%d→%d" % [int(receipt.get("boss_heat_before",0)),int(receipt.get("boss_heat_after",0)),int(receipt.get("player_heat_before",0)),int(receipt.get("player_heat_after",0)),int(receipt.get("shield_before",0)),int(receipt.get("shield_after",0))]
	return ""

func _on_back_row_triggered(card: CardData, receipt: Dictionary) -> void:
	if card == null or card.card_id not in ["P04","R01","P14"]: return
	var text := _back_row_receipt_text(receipt)
	if action_feed: action_feed.push_message("%s：%s" % [card.get_display_name(),text],Color("79ffe1"))
	var source := _project_tactical_cell_to_screen(receipt.get("source_cell",Vector2i(-1,-1)))
	if not source.is_finite(): source = _project_3d_token_to_screen(_get_3d_token_for_card(card))
	_show_committed_source_feedback(card,receipt.get("target_cell",Vector2i(-1,-1)),text,source)
	# The surrounding transaction owns full table refresh after combat commits.
	_refresh_back_row_readability()
# Phase 6A: 濡偓缁便垺鍨氶崝?閳?闁氨鐓?UI
func _on_card_tutored(source_card_name: String, found_card: CardData, message: String) -> void:
	if action_feed:
		action_feed.push_message("检索：%s → %s" % [source_card_name, found_card.get_display_name()], Color(0.4, 0.8, 1.0, 1))
	_add_to_this_turn("检索：%s" % found_card.get_display_name(), Color(0.4, 0.8, 1.0, 1))
	_refresh_tables()
# Phase 6A: 濡偓缁便垹銇戠拹?閳?闁氨鐓?UI
func _on_tutor_failed(source_card_name: String, reason: String) -> void:
	if action_feed:
		action_feed.push_message("%s检索失败：%s" % [source_card_name, reason], TC.WARNING)
	print("[TUTOR] %s" % reason)
# [Fixed func]
func _on_depth_reduced(amount: int, source: String, _new_depth: int) -> void:
	if battle and battle.has_method("trigger_heat_sink_charge_on_depth_reduce"):
		battle.trigger_heat_sink_charge_on_depth_reduce(amount, source)

# Phase 5B-2: Depth 閸戝繐鍘ら崣鎴犳晸閺冨爼鈧氨鐓?ActionFeed
func _on_depth_gain_mitigated(source: String, reduced_amount: int, final_amount: int) -> void:
	if action_feed:
		var msg := "Depth pressure: %s +%d" % [source, reduced_amount]
		if final_amount > 0:
			msg += " (Backlash +%d)" % final_amount
		action_feed.push_message(msg, Color(0.2, 0.8, 0.4, 1))
	_add_to_this_turn("Block Depth: %s" % source, Color(0.2, 0.8, 0.4, 1))

func _on_building_interact(card: CardData) -> void:
	if battle_ended or _card_being_played or _is_monster_summon_interaction_active():
		return
	if card == null:
		return


	# Phase 5E-4: 閸忓牊鐓＄拠銏㈠Ц閹礁浠涙０鍕梾
	var status: Dictionary = battle.get_building_interface_status(card, context.player)
	if not status.get("ok", false):
		# 婢惰精瑙﹂敍娆癱tionFeed warning + 閹舵牕濮╅崝銊ф暰
		var fail_reason: String = status.get("reason", "Conditions not met")
		var msg: String = card.get_display_name() + ": " + fail_reason
		if action_feed:
			action_feed.push_message(msg, TC.WARNING)
		print("[BUILDING INTERACT] %s -> FAIL: %s" % [card.card_name, fail_reason])
		# 閹舵牕濮╅崝銊ф暰
		_play_building_denied_animation(card)
		return

	# 閹存劕濮涢敍姘⒔鐞涘本甯撮崣?
	var result: Dictionary = battle.use_building_interface(card, context.player)
	if bool(result.get("ok", false)) and result.has("target_cell"):
		_show_committed_source_feedback(card, result.target_cell, str(result.get("feedback", "")))
	# Phase 11A: Telemetry
	if _playtest:
		_playtest.record_event("building_activated", {"card": card.card_name})
	var am = _am(); if am: am.play_building_activate()
	if action_feed:
		var msg: String = "建筑发动：" + card.get_display_name()
		if result.get("ok", false):
			action_feed.push_message(msg, Color(0.90, 0.55, 0.22, 1))
			_add_to_this_turn("Build: " + card.get_display_name(), Color(0.90, 0.55, 0.22, 1))
			var detail: String = result.get("message", "")
			if detail != "":
				action_feed.push_message("  " + detail, Color(0.85, 0.7, 0.4, 1))
		else:
			action_feed.push_message(card.get_display_name() + ": " + result.get("message", ""), TC.WARNING)
	print("[BUILDING INTERACT] %s -> %s" % [card.card_name, result])

	# [Fixed]
	if result.get("ok", false):
		var building_slot := player_table.find_back_slot_for_card(card) if player_table and player_table.has_method("find_back_slot_for_card") else null
		var building_position := building_slot.global_position + building_slot.size * 0.5 if building_slot != null else Vector2.ZERO
		var building_facts := result.duplicate(true)
		building_facts.merge({"status": &"committed", "card": card, "label": card.get_display_name(), "target_position": building_position}, true)
		await _play_generic_presentation(&"building", building_facts)
		# Phase 6B: 瀵よ櫣鐡氭稉璇插З閸欐垵濮╅幋鎰閸氬氦袝閸欐垶顥呯槐?(on_building_activate)
		# Search was committed by BattleSystem with the interface; presentation only reads it.
	_refresh_tables()

## Phase 5E-4: 瀵よ櫣鐡氶幋鎰閼村鍟块崝銊ф暰
func _play_building_success_animation(card: CardData) -> void:
	var slot := player_table.find_back_slot_for_card(card)
	if slot:
		player_table.play_building_activate_pulse(slot)
	# Phase 12D: 瀵よ櫣鐡氶崗澶屽箚 閳?闁炬粓鍣鹃懗浠嬪櫤閻滎垱澧块弫?
	var _btab4 := get_node_or_null(NodePath("BattleTable")) as Control
	if _btab4 and battle_vfx and slot and is_instance_valid(slot):
		var _aura_pos := slot.global_position + slot.size * 0.5
		battle_vfx.play_building_aura(_btab4, _aura_pos, Color(1.0, 0.68, 0.2, 1))
## Phase 5E-4: 瀵よ櫣鐡氶幏鎺旂卜閹舵牕濮╅崝銊ф暰
func _play_building_denied_animation(card: CardData) -> void:
	var slot := player_table.find_back_slot_for_card(card)
	if slot:
		player_table.play_building_denied_shake(slot)
# Phase 10A: 濞撳懘娅庨弨璇插毊闁瀚ㄩ悩鑸碘偓?
func _clear_attack_selection() -> void:
	# Phase 10D: unselect VFX before clearing state
	if _selected_attacker_slot and is_instance_valid(_selected_attacker_slot) and card_vfx:
		card_vfx.play_card_unselected(_selected_attacker_slot)
	_selected_attacker = null
	_selected_attacker_slot = null
	if player_table and player_table.has_method("clear_attack_highlights"):
		player_table.clear_attack_highlights()
	if enemy_table and enemy_table.has_method("clear_attack_highlights"):
		enemy_table.clear_attack_highlights()

## Phase 27D-R3: idempotent full cleanup of all attack targeting state.
## Safe to call multiple times — all guards use is_instance_valid / null checks.
func _full_cleanup_attack_targeting(reason: StringName = &"cleanup") -> void:
	_hide_attack_targeting_banner()
	_clear_attack_hover_line()  # Phase 27D-R4
	_clear_skill_selection(reason)  # Phase 27E-R4: clear skill targeting on monster switch
	if _boss_status_hud and is_instance_valid(_boss_status_hud) and _boss_status_hud.has_method("set_clickable"):
		_boss_status_hud.set_clickable(false)
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.clear_preview()
	_clear_attack_selection()
	if _lane_selection_mode == LANE_SELECT_ATTACK:
		_lane_selection_mode = LANE_SELECT_NONE
		_lane_selection_card = null
		_lane_selection_card_ui_ref = null
		_lane_selection_legal.clear()
	_pending_attack_card = null
	_pending_attack_cells.clear()
	_cell_selection_legal.clear()
	if _boss_status_hud and is_instance_valid(_boss_status_hud) and _boss_status_hud.has_method("set_clickable"):
		_boss_status_hud.set_clickable(false)
# Phase 26E-R1: manual lane selection helpers

func _begin_manual_summon_selection(card_ui: CardUI, card: CardData, source: StringName, zone: String = "field") -> void:
	if battle == null:
		return
	var legal: Array[Vector2i] = battle.get_legal_summon_cells(&"player")
	if legal.is_empty():
		if action_feed:
			action_feed.push_message("没有可用的召唤格", TC.WARNING, "", 1.5)
		return
	_lane_selection_mode = LANE_SELECT_SUMMON
	_lane_selection_card = card
	_lane_selection_card_ui_ref = weakref(card_ui)
	_lane_selection_source = source
	_lane_selection_zone = zone
	_lane_selection_legal.clear()
	_cell_selection_legal = legal.duplicate()
	var occupied: Dictionary = battle.get_occupied_cells()
	_ensure_tactical_movement_presenter()
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.show_cell_selection(
			&"summon", &"player", Vector2i(-1, -1), legal, occupied, {}
		)
	print("[CELL SELECT] Begin summon selection: %d legal cells" % legal.size())


func _monster_summon_state() -> StringName:
	return StringName(_monster_drag_session.get("state", MONSTER_SUMMON_IDLE))


func _is_monster_drag_active() -> bool:
	return _monster_summon_state() == MONSTER_SUMMON_DRAGGING


func _is_monster_summon_interaction_active() -> bool:
	return _monster_summon_state() != MONSTER_SUMMON_IDLE


func _is_monster_card_for_drag(card: CardData) -> bool:
	return card != null \
		and card.is_front_row_card() \
		and (card.card_family == "monster" or card.card_type == CardData.CardType.UNIT)


func _is_structure_card_for_drag(card: CardData) -> bool:
	if card == null or card.card_family != "building" or battle == null:
		return false
	var rules: Variant = battle.get("tactical_structure_rules")
	return rules != null and rules.has_method("has_profile") and bool(rules.call("has_profile", str(card.card_id)))


func _structure_profile_id_for_card(card: CardData) -> StringName:
	if card == null or battle == null:
		return &""
	var rules: Variant = battle.get("tactical_structure_rules")
	if rules == null or not rules.has_method("get_profile"):
		return &""
	var profile: Dictionary = rules.call("get_profile", str(card.card_id))
	return StringName(str(profile.get("profile_id", &"")))


func _is_piece_structure_card(card: CardData) -> bool:
	return _structure_profile_id_for_card(card) in [&"p05_foundation", &"p08_fortification"]


func _is_generic_d2_structure_card(card: CardData) -> bool:
	return _structure_profile_id_for_card(card) in [&"p13_heat_sink", &"p16_containment_wall", &"p19_core_cathedral"]


func _classify_board_drag_intent(card: CardData) -> StringName:
	if _is_monster_card_for_drag(card):
		return &"monster_summon"
	if _is_structure_card_for_drag(card):
		return &"structure_build"
	if card == null:
		return &"generic_drop"
	var payload := StringName(str(card.piece_payload_id))
	if card.piece_enabled:
		match payload:
			&"p01_formation_shield":
				return CARD_DRAG_FRIENDLY_ANCHOR
			&"p04_tripwire_watch":
				return CARD_DRAG_TRIPWIRE
			&"p06_bishop_blade":
				return CARD_DRAG_DIRECTED_SPELL
	if card.card_family == "spell":
		return CARD_DRAG_FINISHER if card.archetype_role == CardData.ArchetypeRole.FINISHER else CARD_DRAG_CAST_LANE
	if card.card_family == "counter" and not card.piece_enabled:
		return CARD_DRAG_CAST_LANE
	return &"generic_drop"


func _is_card_cast_drag_intent(intent: StringName) -> bool:
	return intent in [
		CARD_DRAG_FRIENDLY_ANCHOR,
		CARD_DRAG_TRIPWIRE,
		CARD_DRAG_DIRECTED_SPELL,
		CARD_DRAG_CAST_LANE,
		CARD_DRAG_FINISHER,
	]


func _can_begin_card_cast_drag(card_ui: CardUI, card: CardData, intent: StringName) -> bool:
	if _is_monster_summon_interaction_active() or not _is_card_cast_drag_intent(intent):
		return false
	if card_ui == null or not is_instance_valid(card_ui) or card_ui.card_data != card:
		return false
	if battle == null or context == null or context.player == null or card == null:
		return false
	if not card in context.player.hand or _classify_board_drag_intent(card) != intent:
		return false
	return not _has_non_presentation_end_turn_busy(card) and not _presentation_end_turn_blocked


func _begin_piece_card_drag(card_ui: CardUI, card: CardData, intent: StringName) -> bool:
	if not _can_begin_card_cast_drag(card_ui, card, intent) \
			or intent not in [CARD_DRAG_FRIENDLY_ANCHOR, CARD_DRAG_TRIPWIRE, CARD_DRAG_DIRECTED_SPELL]:
		return false
	if _is_piece_selection_active():
		if _piece_context.get("card", null) != card:
			return false
	else:
		_begin_piece_selection(card_ui, card, &"play")
	if not _is_piece_selection_active() or _piece_context.get("card", null) != card:
		return false
	if not _start_card_cast_drag_session(card_ui, card, intent):
		return false
	var status: Dictionary = battle.get_card_piece_status(card, &"play", null, null, {})
	_monster_drag_session["legal_cells"] = (status.get("anchor_cells", []) as Array).duplicate()
	_monster_drag_session["fallback_original_only"] = bool(status.get("fallback_original_only", false))
	return true


func _begin_cast_lane_drag(card_ui: CardUI, card: CardData, intent: StringName) -> bool:
	if intent not in [CARD_DRAG_CAST_LANE, CARD_DRAG_FINISHER] \
			or not _can_begin_card_cast_drag(card_ui, card, intent):
		return false
	# Non-spatial spell drags deliberately do not open the piece-selection owner.
	if _is_piece_selection_active():
		return false
	return _start_card_cast_drag_session(card_ui, card, intent)


func _start_card_cast_drag_session(card_ui: CardUI, card: CardData, intent: StringName) -> bool:
	_close_monster_command_menu()
	_monster_drag_generation += 1
	var source_screen := card_ui.get_global_rect().get_center()
	_monster_drag_session = {
		"active": true,
		"intent": intent,
		"origin": &"drag",
		"state": MONSTER_SUMMON_DRAGGING,
		"generation": _monster_drag_generation,
		"card": card,
		"card_ui_ref": weakref(card_ui),
		"source_screen_position": source_screen,
		"last_pointer_screen_position": source_screen,
		"candidate_target": {},
		"locked_preview_fact": {},
		"pending_confirmation": false,
		"last_cleanup_reason": &"",
		"camera_was_frozen": _camera_orbit_frozen,
	}
	card_ui.set_board_reservation_visual(true, intent)
	_camera_orbit_frozen = true
	if _monster_summon_drop_target != null and is_instance_valid(_monster_summon_drop_target):
		_monster_summon_drop_target.set_board_drag_active(true, intent)
	var fact := _make_card_cast_preview_fact(source_screen, source_screen, {}, false, &"awaiting_target")
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		if intent in [CARD_DRAG_CAST_LANE, CARD_DRAG_FINISHER]:
			_monster_summon_interaction_presenter.show_cast_lane(fact, _is_reduced_motion_presentation())
		else:
			_monster_summon_interaction_presenter.show_card_drag(fact, _is_reduced_motion_presentation())
	return true


func _make_card_cast_preview_fact(
		pointer_screen_position: Vector2,
		target_screen_position: Vector2,
		candidate_target: Dictionary,
		legal: bool,
		reason_code: StringName,
		stage: StringName = &"preview"
) -> Dictionary:
	var card: CardData = _monster_drag_session.get("card", null)
	return {
		"session_id": int(_monster_drag_session.get("generation", -1)),
		"card_runtime_id": card.get_instance_id() if card != null else 0,
		"card_id": StringName(str(card.card_id)) if card != null else &"",
		"intent_kind": StringName(_monster_drag_session.get("intent", &"")),
		"stage": stage,
		"source_screen_position": _monster_drag_session.get("source_screen_position", Vector2.INF),
		"pointer_screen_position": pointer_screen_position,
		"target_screen_position": target_screen_position,
		"candidate_target": candidate_target.duplicate(true),
		"legal": legal,
		"reason_code": reason_code,
		"affected_cells": [],
		"affected_targets": [],
		"confirmation_policy": &"pending_spatial",
		"presentation_profile_id": StringName(_monster_drag_session.get("intent", &"")),
		"revision_bundle": {},
	}


func _update_card_cast_drag(screen_position: Vector2) -> Dictionary:
	return _update_card_cast_drag_hit(_raycast_3d_click(screen_position), screen_position)


func _card_cast_lane_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var lane := Rect2(
		Vector2(viewport_size.x * 0.28, viewport_size.y * 0.69),
		Vector2(viewport_size.x * 0.44, viewport_size.y * 0.12))
	# This is only a presentation release target. Fit it around the existing HUD
	# reservations instead of creating another board/gameplay zone.
	for reserved in _get_reserved_ui_rects():
		if not lane.intersects(reserved):
			continue
		if reserved.position.y >= viewport_size.y * 0.55:
			lane.position.y = minf(lane.position.y, reserved.position.y - lane.size.y - 10.0)
		elif reserved.position.x >= viewport_size.x * 0.5:
			lane.size.x = maxf(180.0, reserved.position.x - lane.position.x - 10.0)
		else:
			var right_edge := lane.end.x
			lane.position.x = maxf(lane.position.x, reserved.end.x + 10.0)
			lane.size.x = maxf(180.0, right_edge - lane.position.x)
	lane.position.x = clampf(lane.position.x, 16.0, maxf(16.0, viewport_size.x - lane.size.x - 16.0))
	lane.position.y = clampf(lane.position.y, 16.0, maxf(16.0, viewport_size.y - lane.size.y - 150.0))
	return lane


func _update_card_cast_drag_hit(hit: Dictionary, pointer_screen_position: Vector2 = Vector2.INF) -> Dictionary:
	var intent := StringName(_monster_drag_session.get("intent", &""))
	if _monster_summon_state() not in [MONSTER_SUMMON_DRAGGING, MONSTER_SUMMON_RESELECTING] \
			or not _is_card_cast_drag_intent(intent):
		return {"ok": false, "reason_code": &"drag_inactive"}
	if not pointer_screen_position.is_finite():
		pointer_screen_position = _monster_drag_session.get("last_pointer_screen_position", _monster_source_screen_anchor())
	_monster_drag_session["last_pointer_screen_position"] = pointer_screen_position
	var raise_hover := _p23_terrain_raise_hover(hit, pointer_screen_position)
	if not raise_hover.is_empty():
		return raise_hover
	var repair_hover := _p22_repair_hover(hit, pointer_screen_position)
	if not repair_hover.is_empty():
		return repair_hover
	var siege_hover := _p18_siege_hover(hit, pointer_screen_position)
	if not siege_hover.is_empty():
		return siege_hover
	_clear_siege_presentation(&"hover_changed")
	if intent in [CARD_DRAG_CAST_LANE, CARD_DRAG_FINISHER]:
		var lane := _card_cast_lane_rect()
		var lane_legal := lane.has_point(pointer_screen_position)
		var lane_target := {"target_kind": &"cast_lane"} if lane_legal else {}
		var lane_fact := _make_card_cast_preview_fact(
			pointer_screen_position, pointer_screen_position, lane_target,
			lane_legal, &"ok" if lane_legal else &"outside_cast_lane")
		lane_fact["confirmation_policy"] = &"mandatory" if intent == CARD_DRAG_FINISHER else &"release_commit"
		lane_fact["cast_lane_rect"] = lane
		_monster_drag_session["candidate_target"] = lane_target.duplicate(true)
		if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
			_monster_summon_interaction_presenter.show_cast_lane(lane_fact, _is_reduced_motion_presentation())
		return {
			"ok": lane_legal,
			"reason_code": lane_fact.get("reason_code", &"outside_cast_lane"),
			"preview_fact": lane_fact,
		}
	var candidate: Dictionary = {}
	var target_screen := pointer_screen_position
	var reason := &"target_unresolved"
	var legal := false
	var affected_cells: Array = []
	var fallback_original_only := intent == CARD_DRAG_DIRECTED_SPELL \
			and bool(_monster_drag_session.get("fallback_original_only", false))
	if fallback_original_only:
		legal = true
		reason = &"ok"
	if bool(hit.get("ok", false)):
		var target_kind := StringName(str(hit.get("target_kind", "")))
		candidate = {"target_kind": target_kind}
		if target_kind == &"tactical_cell" and hit.get("board_cell", null) is Vector2i:
			var cell: Vector2i = hit.get("board_cell")
			candidate["board_cell"] = cell
			target_screen = _project_tactical_cell_to_screen(cell)
			if not target_screen.is_finite():
				target_screen = pointer_screen_position
			if intent == CARD_DRAG_TRIPWIRE:
				var card: CardData = _monster_drag_session.get("card", null)
				var anchor := {"type": &"cell", "cell": cell}
				var status: Dictionary = battle.get_card_piece_status(card, &"play", anchor, null, {})
				legal = bool(status.get("ok", false))
				reason = StringName(str(status.get("reason_code", &"ok" if legal else &"piece_anchor_invalid")))
				affected_cells = (status.get("base_cells", []) as Array).duplicate()
			elif intent in [CARD_DRAG_FRIENDLY_ANCHOR, CARD_DRAG_DIRECTED_SPELL]:
				var card: CardData = _monster_drag_session.get("card", null)
				var anchor: Variant = _piece_anchor_from_drag_hit(hit, intent)
				_monster_drag_session["hover_candidate_anchor"] = anchor
				if anchor != null:
					var status: Dictionary = battle.get_card_piece_status(card, &"play", anchor, null, {})
					legal = bool(status.get("ok", false))
					reason = StringName(str(status.get("reason_code", &"ok" if legal else &"piece_anchor_invalid")))
					affected_cells = (status.get("ray_preview_cells", status.get("base_cells", [])) as Array).duplicate()
				else:
					legal = false
					reason = &"piece_anchor_invalid"
	_monster_drag_session["candidate_target"] = candidate.duplicate(true)
	var fact := _make_card_cast_preview_fact(pointer_screen_position, target_screen, candidate, legal, reason)
	fact["affected_cells"] = affected_cells
	if fallback_original_only:
		fact["fallback_original_only"] = true
		fact["candidate_target"] = {}
		fact["confirmation_policy"] = &"existing_multistage"
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		if intent in [CARD_DRAG_CAST_LANE, CARD_DRAG_FINISHER]:
			_monster_summon_interaction_presenter.show_cast_lane(fact, _is_reduced_motion_presentation())
		else:
			_monster_summon_interaction_presenter.show_card_drag(fact, _is_reduced_motion_presentation())
	return {"ok": legal, "reason_code": reason, "preview_fact": fact}


func _stage_card_cast_candidate(card_ui: CardUI, preview_fact: Dictionary) -> Dictionary:
	if _monster_summon_state() not in [MONSTER_SUMMON_DRAGGING, MONSTER_SUMMON_RESELECTING] \
			or card_ui == null or not is_instance_valid(card_ui):
		return {"ok": false, "reason_code": &"drag_inactive"}
	var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
	if source_ref == null or source_ref.get_ref() != card_ui:
		return {"ok": false, "reason_code": &"source_mismatch"}
	if not bool(preview_fact.get("legal", false)):
		return {"ok": false, "reason_code": preview_fact.get("reason_code", &"invalid_target")}
	_monster_drag_session["state"] = MONSTER_SUMMON_PENDING_CONFIRM
	_monster_drag_session["pending_confirmation"] = true
	_monster_drag_session["locked_preview_fact"] = preview_fact.duplicate(true)
	_monster_drag_session["candidate_target"] = (preview_fact.get("candidate_target", {}) as Dictionary).duplicate(true)
	if StringName(_monster_drag_session.get("intent", &"")) == CARD_DRAG_TRIPWIRE:
		var cell: Variant = (_monster_drag_session.get("candidate_target", {}) as Dictionary).get("board_cell", MONSTER_DRAG_INVALID_CELL)
		_monster_drag_session["candidate_anchor"] = {"type": &"cell", "cell": cell}
	elif StringName(_monster_drag_session.get("intent", &"")) in [CARD_DRAG_FRIENDLY_ANCHOR, CARD_DRAG_DIRECTED_SPELL]:
		_monster_drag_session["candidate_anchor"] = _monster_drag_session.get("hover_candidate_anchor", null)
	if _monster_summon_drop_target != null and is_instance_valid(_monster_summon_drop_target):
		_monster_summon_drop_target.set_board_drag_active(false)
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		var card: CardData = _monster_drag_session.get("card", null)
		var candidate: Dictionary = preview_fact.get("candidate_target", {})
		var title := "确认施放这张牌？"
		var confirm_text := "确认施放"
		if StringName(_monster_drag_session.get("intent", &"")) == CARD_DRAG_TRIPWIRE:
			var cell: Vector2i = candidate.get("board_cell", MONSTER_DRAG_INVALID_CELL)
			var display_name := card.get_display_name() if card != null and card.has_method("get_display_name") else (card.card_name if card != null else "断频伏线")
			title = "在格 (%d,%d) 布设「%s」？" % [cell.x, cell.y, display_name]
			confirm_text = "确认布设"
		elif bool(preview_fact.get("fallback_original_only", false)):
			title = "当前无可赋刃友军；将仅结算原法术效果"
			confirm_text = "确认施放"
		elif StringName(_monster_drag_session.get("intent", &"")) in [CARD_DRAG_FRIENDLY_ANCHOR, CARD_DRAG_DIRECTED_SPELL]:
			var anchor: Variant = _monster_drag_session.get("candidate_anchor", null)
			var anchor_name := _piece_drag_anchor_display_name(anchor)
			title = "以「%s」为锚点施放「%s」？" % [anchor_name, card.get_display_name() if card != null else "棋子法术"]
			confirm_text = "确认锚点"
		_monster_summon_interaction_presenter.show_card_pending(
			preview_fact, title, confirm_text, "重新选择", _is_reduced_motion_presentation())
	if bool(preview_fact.get("terrain_raise_mode", false)):
		_monster_drag_session.terrain_raise_status = preview_fact.terrain_raise_status.duplicate(true)
		_monster_drag_session.terrain_raise_mode = true
		_show_terrain_raise_pending(preview_fact.terrain_raise_status)
	if bool(preview_fact.get("repair_mode", false)):
		_monster_drag_session.repair_status = preview_fact.repair_status.duplicate(true)
		_monster_drag_session.repair_mode = true
		_show_repair_pending(preview_fact.repair_status)
	if bool(preview_fact.get("siege_mode", false)):
		_monster_drag_session.siege_status = preview_fact.siege_status.duplicate(true)
		_monster_drag_session.siege_mode = true
		_show_siege_pending(preview_fact.siege_status)
	return {"ok": true, "preview_fact": preview_fact.duplicate(true)}


func _confirm_pending_card_cast() -> Dictionary:
	if _monster_drag_session.get("terrain_raise_mode", false):
		return _confirm_terrain_raise_cast()
	if _monster_drag_session.get("repair_mode", false):
		return _confirm_repair_cast()
	if bool(_monster_drag_session.get("siege_mode", false)):
		return _confirm_siege_selection()
	if _monster_summon_state() != MONSTER_SUMMON_PENDING_CONFIRM \
			or not _is_card_cast_drag_intent(StringName(_monster_drag_session.get("intent", &""))):
		return {"ok": false, "reason_code": &"not_pending"}
	var intent := StringName(_monster_drag_session.get("intent", &""))
	if intent in [CARD_DRAG_TRIPWIRE, CARD_DRAG_FRIENDLY_ANCHOR, CARD_DRAG_DIRECTED_SPELL]:
		var generation := int(_monster_drag_session.get("generation", -1))
		if int(_monster_drag_session.get("piece_anchor_confirmed_generation", -2)) == generation:
			return {"ok": false, "reason_code": &"already_confirmed"}
		var card: CardData = _monster_drag_session.get("card", null)
		var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
		var source := source_ref.get_ref() as CardUI if source_ref != null else null
		var anchor: Variant = _monster_drag_session.get("candidate_anchor", null)
		if anchor is Dictionary:
			anchor = (anchor as Dictionary).duplicate(true)
		var fallback_original_only := intent == CARD_DRAG_DIRECTED_SPELL \
				and bool(_monster_drag_session.get("fallback_original_only", false))
		if battle == null or context == null or context.player == null or card == null \
				or source == null or not is_instance_valid(source) or source.card_data != card \
				or not card in context.player.hand or (anchor == null and not fallback_original_only):
			_begin_card_cast_reselect()
			return {"ok": false, "reason_code": &"card_cast_source_stale"}
		var fresh: Dictionary = battle.get_card_piece_status(card, &"play", anchor, null, {})
		if not bool(fresh.get("ok", false)):
			_begin_card_cast_reselect()
			return {"ok": false, "reason_code": fresh.get("reason_code", &"piece_anchor_invalid"), "status": fresh}
		_monster_drag_session["piece_anchor_confirmed_generation"] = generation
		_monster_drag_session["state"] = MONSTER_SUMMON_COMMITTING
		if not fallback_original_only:
			_confirm_piece_anchor(anchor)
		if not _is_piece_selection_active() or (not fallback_original_only and _piece_context.get("anchor", null) != anchor):
			_monster_drag_session["state"] = MONSTER_SUMMON_PENDING_CONFIRM
			_monster_drag_session.erase("piece_anchor_confirmed_generation")
			return {"ok": false, "reason_code": &"piece_anchor_handoff_failed"}
		return {"ok": true, "handoff": &"piece_flow", "anchor": anchor, "fallback_original_only": fallback_original_only, "status": fresh}
	if intent in [CARD_DRAG_CAST_LANE, CARD_DRAG_FINISHER]:
		var generation := int(_monster_drag_session.get("generation", -1))
		var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
		var source := source_ref.get_ref() as CardUI if source_ref != null else null
		var card: CardData = _monster_drag_session.get("card", null)
		if source == null or not is_instance_valid(source) or source.card_data != card \
				or battle == null or context == null or context.player == null \
				or card == null or not card in context.player.hand or not battle.can_play_card(card):
			_cleanup_card_cast_interaction(&"cast_source_unplayable")
			return {"ok": false, "reason_code": &"cast_source_unplayable"}
		_monster_drag_session["state"] = MONSTER_SUMMON_COMMITTING
		call_deferred("_handoff_card_cast_to_existing_click", source_ref, generation)
		return {"ok": true, "handoff": &"existing_click", "generation": generation}
	return {"ok": false, "reason_code": &"card_cast_confirmation_unavailable"}


func _handoff_card_cast_to_existing_click(card_ui_ref: WeakRef, expected_generation: int) -> void:
	if expected_generation != int(_monster_drag_session.get("generation", -1)):
		return
	var card_ui := card_ui_ref.get_ref() as CardUI if card_ui_ref != null else null
	var card := card_ui.card_data if card_ui != null and is_instance_valid(card_ui) else null
	_cleanup_card_cast_interaction(&"cast_lane_handoff", true)
	if card_ui == null or card == null or context == null or context.player == null \
			or not card in context.player.hand:
		return
	_on_card_clicked(card_ui)


func _begin_card_cast_reselect() -> void:
	_clear_siege_presentation(&"reselect")
	_monster_drag_session.erase("terrain_raise_legal_cells")
	_monster_drag_session.erase("terrain_raise_status")
	_monster_drag_session.erase("terrain_raise_mode")
	_monster_drag_session.erase("repair_status")
	_monster_drag_session.erase("repair_mode")
	_monster_drag_session.erase("siege_status")
	_monster_drag_session.erase("siege_mode")
	if _monster_summon_state() != MONSTER_SUMMON_PENDING_CONFIRM:
		return
	var fact: Dictionary = (_monster_drag_session.get("locked_preview_fact", {}) as Dictionary).duplicate(true)
	_monster_drag_session["state"] = MONSTER_SUMMON_RESELECTING
	_monster_drag_session["pending_confirmation"] = false
	_monster_drag_session["candidate_target"] = {}
	_monster_drag_session["locked_preview_fact"] = {}
	_monster_drag_session.erase("candidate_anchor")
	_monster_drag_session.erase("hover_candidate_anchor")
	_monster_drag_session.erase("piece_anchor_confirmed_generation")
	var card: CardData = _monster_drag_session.get("card", null)
	if card != null and card.card_id == "P23":
		_monster_drag_session.terrain_raise_mode = true
		_refresh_terrain_raise_legal_cells(card)
		_terrain_raise_presenter.show_preview(_terrain_raise_view({}))
	if card != null and _piece_context.get("card", null) == card:
		_piece_context["stage"] = &"anchor"
		_piece_context["anchor"] = null
		var refreshed: Dictionary = battle.get_card_piece_status(card, &"play", null, null, {})
		_monster_drag_session["legal_cells"] = (refreshed.get("anchor_cells", []) as Array).duplicate()
	if _monster_summon_drop_target != null and is_instance_valid(_monster_summon_drop_target):
		_monster_summon_drop_target.set_board_drag_active(card == null or card.card_id != "P23", StringName(_monster_drag_session.get("intent", &"")))
	fact["stage"] = &"preview"
	fact["legal"] = false
	fact["reason_code"] = &"awaiting_target"
	fact["candidate_target"] = {}
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		_monster_summon_interaction_presenter.show_card_drag(fact, _is_reduced_motion_presentation())
	_show_p18_siege_choices()


func _cancel_card_cast_interaction(reason: StringName) -> void:
	if not _is_card_cast_drag_intent(StringName(_monster_drag_session.get("intent", &""))) \
			or _monster_summon_state() == MONSTER_SUMMON_COMMITTING:
		return
	_cleanup_card_cast_interaction(reason)


func _cleanup_card_cast_interaction(reason: StringName = &"cleanup", allow_committing: bool = false) -> void:
	var intent := StringName(_monster_drag_session.get("intent", &""))
	if not _is_card_cast_drag_intent(intent):
		return
	if _monster_summon_state() == MONSTER_SUMMON_COMMITTING and not allow_committing:
		return
	_clear_siege_presentation(reason)
	var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
	var source := source_ref.get_ref() as CardUI if source_ref != null else null
	var card: CardData = _monster_drag_session.get("card", null)
	var camera_was_frozen := bool(_monster_drag_session.get("camera_was_frozen", false))
	var generation := int(_monster_drag_session.get("generation", -1))
	if _is_piece_selection_active() and _piece_context.get("card", null) == card:
		_cancel_piece_context(reason)
	_monster_drag_last_cleanup_reason = reason
	_monster_drag_session = {
		"active": false,
		"intent": &"",
		"state": MONSTER_SUMMON_IDLE,
		"generation": generation,
		"last_cleanup_reason": reason,
	}
	if source != null and is_instance_valid(source):
		source.set_board_reservation_visual(false, intent)
	if _monster_summon_drop_target != null and is_instance_valid(_monster_summon_drop_target):
		_monster_summon_drop_target.set_board_drag_active(false)
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		_monster_summon_interaction_presenter.clear_card_cast()
	if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
		_tactical_presenter.clear_drag_hover()
		_tactical_presenter.clear_preview()
	if _tactical_terrain_presenter != null and is_instance_valid(_tactical_terrain_presenter):
		_tactical_terrain_presenter.clear_focus()
	_clear_drag_reselect_lane_fields()
	_camera_orbit_frozen = camera_was_frozen


func _card_cast_debug_snapshot() -> Dictionary:
	var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
	var drop_snapshot: Dictionary = {}
	var drop_count := 0
	if _monster_summon_drop_target != null and is_instance_valid(_monster_summon_drop_target):
		drop_snapshot = _monster_summon_drop_target.get_debug_snapshot()
		drop_count = 1
	var presenter_snapshot: Dictionary = {}
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		presenter_snapshot = _monster_summon_interaction_presenter.get_card_cast_debug_snapshot()
	return {
		"active": _is_card_cast_drag_intent(StringName(_monster_drag_session.get("intent", &""))) and _is_monster_summon_interaction_active(),
		"state": _monster_summon_state(),
		"intent": StringName(_monster_drag_session.get("intent", &"")),
		"source_alive": source_ref != null and source_ref.get_ref() != null,
		"drop_target_active": bool(drop_snapshot.get("active", false)),
		"drop_target_count": drop_count,
		"camera_orbit_frozen": _camera_orbit_frozen,
		"generation": int(_monster_drag_session.get("generation", -1)),
		"last_cleanup_reason": _monster_drag_session.get("last_cleanup_reason", _monster_drag_last_cleanup_reason),
		"presenter": presenter_snapshot,
	}


func _validate_card_cast_preview_revision(preview_fact: Dictionary, revision_provider: Callable = Callable()) -> Dictionary:
	var bundle: Dictionary = (preview_fact.get("revision_bundle", {}) as Dictionary).duplicate(true)
	if not bundle.has("board_revision") or not revision_provider.is_valid():
		return {"ok": true}
	var expected := int(bundle.get("board_revision", -1))
	var current := int(revision_provider.call())
	if expected != current:
		return {
			"ok": false,
			"reason_code": &"cast_target_stale",
			"reselecting": true,
			"expected_revision": expected,
			"current_revision": current,
		}
	return {"ok": true, "current_revision": current}


func _present_card_cast_preview_fact(
		preview_fact: Dictionary,
		revision_provider: Callable = Callable(),
		reduced_motion: bool = false
) -> Dictionary:
	var fact := preview_fact.duplicate(true)
	var revision_status := _validate_card_cast_preview_revision(fact, revision_provider)
	if not bool(revision_status.get("ok", false)):
		_clear_card_cast_area_preview()
		return revision_status
	if StringName(str(fact.get("intent_kind", &""))) != &"area_cell":
		return {"ok": false, "reason_code": &"unsupported_preview_intent"}
	var candidate: Dictionary = fact.get("candidate_target", {})
	var raw_center: Variant = candidate.get("board_cell", MONSTER_DRAG_INVALID_CELL)
	if not raw_center is Vector2i or raw_center == MONSTER_DRAG_INVALID_CELL:
		return {"ok": false, "reason_code": &"area_center_missing"}
	var center: Vector2i = raw_center
	var affected: Array[Vector2i] = []
	for raw_cell in fact.get("affected_cells", []):
		if raw_cell is Vector2i and not affected.has(raw_cell):
			affected.append(raw_cell)
	if not affected.has(center):
		affected.push_front(center)
	var secondary: Array[Vector2i] = []
	for cell in affected:
		if cell != center:
			secondary.append(cell)
	var projected := _project_tactical_cell_to_screen(center)
	if projected.is_finite():
		fact["target_screen_position"] = projected
	_card_cast_area_preview_fact = fact.duplicate(true)
	_ensure_tactical_movement_presenter()
	if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
		var center_cells: Array[Vector2i] = [center]
		var no_enhanced_cells: Array[Vector2i] = []
		_tactical_presenter.show_piece_selection(
			&"area_preview", &"preview", MONSTER_DRAG_INVALID_CELL,
			center_cells, secondary, no_enhanced_cells, {})
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		_monster_summon_interaction_presenter.show_card_drag(fact, reduced_motion)
	return {"ok": true, "view_only": true, "center_cell": center, "affected_cells": affected.duplicate()}


func _clear_card_cast_area_preview() -> void:
	_card_cast_area_preview_fact = {}
	if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
		_tactical_presenter.clear_preview()
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		_monster_summon_interaction_presenter.clear_card_cast()


func _card_cast_area_debug_snapshot() -> Dictionary:
	var center := MONSTER_DRAG_INVALID_CELL
	var candidate: Dictionary = _card_cast_area_preview_fact.get("candidate_target", {})
	if candidate.get("board_cell", null) is Vector2i:
		center = candidate.get("board_cell")
	var center_count := 0
	var secondary_count := 0
	if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
		var interaction_root := _tactical_presenter.get_node_or_null(NodePath("InteractionRoot"))
		if interaction_root != null:
			for marker in interaction_root.get_children():
				match StringName(str(marker.get_meta("piece_kind", &""))):
					&"anchor": center_count += 1
					&"base": secondary_count += 1
	var presenter_snapshot: Dictionary = {}
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		presenter_snapshot = _monster_summon_interaction_presenter.get_card_cast_debug_snapshot()
	return {
		"center_cell": center,
		"center_marker_count": center_count,
		"secondary_marker_count": secondary_count,
		"mutation_callable_count": 0,
		"fact": _card_cast_area_preview_fact.duplicate(true),
		"presenter": presenter_snapshot,
	}


func _is_structure_build_drag_active() -> bool:
	return _monster_summon_state() in [MONSTER_SUMMON_DRAGGING, MONSTER_SUMMON_RESELECTING] \
		and StringName(_monster_drag_session.get("intent", &"")) == &"structure_build"


func _structure_build_query_options(card: CardData, cell: Vector2i, orientation_edge: StringName = &"") -> Dictionary:
	var options := {"allow_replacement_selection": true}
	if orientation_edge != &"":
		options["orientation_edge"] = orientation_edge
	if card == null or battle == null:
		return options
	# Keep the selected old building through anchor, payment and final requery.
	# Bind it to the active card so a later selection cannot inherit it.
	if is_instance_valid(_pending_piece_replacement_old_card) and _piece_context.get("card") == card:
		options["replacement_old_card"] = _pending_piece_replacement_old_card
		return options
	var structure: Dictionary = battle.get_structure_at_cell(cell)
	if structure.is_empty():
		return options
	var profile_id := _structure_profile_id_for_card(card)
	var existing_profile := StringName(str(structure.get("profile_id", &"")))
	var foundation_state := StringName(str(structure.get("foundation_state", &"stable")))
	var needs_source := (profile_id == &"p08_fortification" and existing_profile == &"p05_foundation") \
		or profile_id == &"p19_core_cathedral" \
		or (profile_id in [&"p13_heat_sink", &"p16_containment_wall"] and foundation_state == &"undermined")
	if not needs_source:
		return options
	var old_card := _find_structure_source_card(int(structure.get("source_runtime_id", 0)))
	if old_card != null:
		options["replacement_old_card"] = old_card
	return options


func _structure_build_candidate_cells(card: CardData) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	if battle == null or card == null:
		return candidates
	if battle.has_method("get_legal_structure_build_targets"):
		for target_value: Variant in battle.get_legal_structure_build_targets(card, {}):
			if not target_value is Dictionary:
				continue
			var target_cell: Variant = (target_value as Dictionary).get("cell", MONSTER_DRAG_INVALID_CELL)
			if target_cell is Vector2i and target_cell not in candidates:
				candidates.append(target_cell)
	for y in range(5):
		for x in range(5):
			var cell := Vector2i(x, y)
			if cell in candidates:
				continue
			var status: Dictionary = battle.get_structure_build_status(
				card, cell, _structure_build_query_options(card, cell))
			if bool(status.get("ok", false)) or bool(status.get("awaiting_replacement", false)):
				candidates.append(cell)
	return candidates


func _structure_build_inspectable_cells(card: CardData) -> Array[Vector2i]:
	var cells := _structure_build_candidate_cells(card)
	if battle == null or card == null:
		return cells
	var profile_id := _structure_profile_id_for_card(card)
	if profile_id not in [&"p13_heat_sink", &"p16_containment_wall", &"p19_core_cathedral"]:
		return cells
	for y in range(5):
		for x in range(5):
			var cell := Vector2i(x, y)
			var structure: Dictionary = battle.get_structure_at_cell(cell)
			if structure.is_empty():
				continue
			var include := profile_id == &"p19_core_cathedral"
			include = include or (profile_id in [&"p13_heat_sink", &"p16_containment_wall"] and StringName(str(structure.get("foundation_state", &"stable"))) != &"stable")
			if include and cell not in cells:
				cells.append(cell)
	return cells


func _begin_structure_build_drag(card_ui: CardUI, card: CardData) -> bool:
	if _is_monster_summon_interaction_active() or card_ui == null or not is_instance_valid(card_ui):
		return false
	if battle == null or context == null or context.player == null:
		return false
	if card_ui.card_data != card or not _is_structure_card_for_drag(card) or not card in context.player.hand:
		return false
	if _has_non_presentation_end_turn_busy(card) or _presentation_end_turn_blocked:
		return false
	# The press that becomes a native drag can already have opened the click path.
	# The drag takes over that same card only; it never creates another selection owner.
	if _is_piece_selection_active():
		if _piece_context.get("card", null) != card:
			return false
		_cancel_piece_context(&"structure_drag_takeover")
	var candidates := _structure_build_candidate_cells(card)
	var inspectable := _structure_build_inspectable_cells(card)
	if candidates.is_empty() and inspectable.is_empty():
		return false
	_monster_drag_generation += 1
	_structure_drag_last_commit_had_structure_fact = false
	_monster_drag_last_drop_screen_position = Vector2.INF
	_monster_drag_session = {
		"active": true,
		"intent": &"structure_build",
		"state": MONSTER_SUMMON_DRAGGING,
		"generation": _monster_drag_generation,
		"card": card,
		"card_ui_ref": weakref(card_ui),
		"legal_cells": candidates.duplicate(),
		"inspectable_cells": inspectable.duplicate(),
		"orientation_edge": &"",
		"hover_cell": MONSTER_DRAG_INVALID_CELL,
		"hover_status": {},
		"candidate_cell": MONSTER_DRAG_INVALID_CELL,
		"last_cleanup_reason": &"",
		"camera_was_frozen": _camera_orbit_frozen,
	}
	card_ui.set_board_reservation_visual(true, &"structure_build")
	_camera_orbit_frozen = true
	if _monster_summon_drop_target != null and is_instance_valid(_monster_summon_drop_target):
		_monster_summon_drop_target.set_board_drag_active(true, &"structure_build")
	_ensure_tactical_movement_presenter()
	if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
		_tactical_presenter.show_cell_selection(
			&"build", &"player", MONSTER_DRAG_INVALID_CELL,
			candidates, battle.get_occupied_cells(), {})
	_set_end_turn_busy_for_structure(true)
	return true


func _begin_structure_build_click_selection(card_ui: CardUI, card: CardData) -> bool:
	if not _begin_structure_build_drag(card_ui, card):
		return false
	_monster_drag_session["origin"] = &"click"
	_monster_drag_session["state"] = MONSTER_SUMMON_RESELECTING
	if _monster_summon_drop_target != null and is_instance_valid(_monster_summon_drop_target):
		_monster_summon_drop_target.set_board_drag_active(false, &"structure_build")
	return true


func _adopt_structure_click_session(card_ui: CardUI, card: CardData, cell: Vector2i) -> bool:
	if _is_monster_summon_interaction_active() or card_ui == null or not is_instance_valid(card_ui):
		return false
	if battle == null or context == null or context.player == null \
			or card_ui.card_data != card or not _is_structure_card_for_drag(card) \
			or not card in context.player.hand:
		return false
	var query_options := _structure_build_query_options(card, cell)
	var status: Dictionary = battle.get_structure_build_status(card, cell, query_options)
	if not bool(status.get("ok", false)) and not bool(status.get("awaiting_replacement", false)):
		return false
	_monster_drag_generation += 1
	_structure_drag_last_commit_had_structure_fact = false
	_monster_drag_session = {
		"active": true,
		"intent": &"structure_build",
		"origin": &"click",
		"state": MONSTER_SUMMON_PENDING_CONFIRM,
		"generation": _monster_drag_generation,
		"card": card,
		"card_ui_ref": weakref(card_ui),
		"legal_cells": _structure_build_candidate_cells(card),
		"inspectable_cells": _structure_build_inspectable_cells(card),
		"orientation_edge": StringName(str(status.get("orientation_edge", &""))),
		"hover_cell": cell,
		"hover_status": status.duplicate(true),
		"candidate_cell": cell,
		"pending_confirmation": false,
		"last_cleanup_reason": &"",
		"camera_was_frozen": _camera_orbit_frozen,
	}
	card_ui.set_board_reservation_visual(true, &"structure_build")
	_camera_orbit_frozen = true
	_set_end_turn_busy_for_structure(true)
	_show_structure_build_preview(status, &"pending")
	return true


func _clear_structure_build_preview() -> void:
	if _tactical_structure_presenter != null and is_instance_valid(_tactical_structure_presenter):
		_tactical_structure_presenter.clear_preview()
	if _tactical_terrain_presenter != null and is_instance_valid(_tactical_terrain_presenter):
		_tactical_terrain_presenter.clear_height_preview()


func _cleanup_structure_presentation_lifecycle(reason: StringName = &"cleanup") -> void:
	var is_structure_session := StringName(_monster_drag_session.get("intent", &"")) == &"structure_build"
	var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
	var source := source_ref.get_ref() as CardUI if source_ref != null else null
	var camera_was_frozen := bool(_monster_drag_session.get("camera_was_frozen", _camera_orbit_frozen))
	var generation := int(_monster_drag_session.get("generation", -1))
	if is_structure_session:
		_cancel_piece_context(reason)
		if source != null and is_instance_valid(source):
			source.set_board_reservation_visual(false, &"structure_build")
		if _monster_summon_drop_target != null and is_instance_valid(_monster_summon_drop_target):
			_monster_summon_drop_target.set_board_drag_active(false, &"structure_build")
		_monster_drag_last_cleanup_reason = reason
		_monster_drag_session = {
			"active": false,
			"intent": &"",
			"state": MONSTER_SUMMON_IDLE,
			"generation": generation,
		}
		_clear_drag_reselect_lane_fields()
		_camera_orbit_frozen = camera_was_frozen
	if _tactical_structure_presenter != null and is_instance_valid(_tactical_structure_presenter):
		if _tactical_structure_presenter.has_method("cancel_presentations"):
			_tactical_structure_presenter.cancel_presentations(reason)
		else:
			_tactical_structure_presenter.clear_preview()
	if _tactical_terrain_presenter != null and is_instance_valid(_tactical_terrain_presenter):
		_tactical_terrain_presenter.clear_height_preview()
		_tactical_terrain_presenter.clear_focus()
	if is_structure_session:
		if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
			_tactical_presenter.clear_drag_hover()
			_tactical_presenter.clear_preview()
		if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
			_monster_summon_interaction_presenter.clear()
	if _structure_interaction_presenter != null and is_instance_valid(_structure_interaction_presenter):
		if _structure_interaction_presenter.has_method("clear_transient"):
			_structure_interaction_presenter.clear_transient(reason)
		elif _structure_interaction_presenter.has_method("clear"):
			_structure_interaction_presenter.clear()
	if is_structure_session:
		_set_end_turn_busy_for_structure(false)


func _show_structure_build_preview(status: Dictionary, visual_state: StringName) -> void:
	if status.is_empty():
		_clear_structure_build_preview()
		return
	var cell: Variant = status.get("piece_anchor_cell", status.get("cell", MONSTER_DRAG_INVALID_CELL))
	var terrain_before: Dictionary = (status.get("terrain_before", {}) as Dictionary).duplicate(true)
	if terrain_before.is_empty() and cell is Vector2i and battle != null:
		terrain_before = battle.get_cell_state(cell).duplicate(true)
	var terrain_after: Dictionary = status.get("terrain_after", terrain_before)
	if not cell is Vector2i or terrain_before.is_empty():
		_clear_structure_build_preview()
		return
	if _tactical_structure_presenter != null and is_instance_valid(_tactical_structure_presenter):
		var preview_fact := status.duplicate(true)
		preview_fact.merge({
			"preview_id": &"structure_drag_preview",
			"cell": cell,
			"target_height": int(terrain_after.get("height", terrain_before.get("height", 0))),
			"profile_id": StringName(str(status.get("profile_id", &""))),
			"visual_state": visual_state,
		}, true)
		_tactical_structure_presenter.show_preview(preview_fact, _is_reduced_motion_presentation())
	if _tactical_terrain_presenter != null and is_instance_valid(_tactical_terrain_presenter):
		_tactical_terrain_presenter.show_height_preview({
			"preview_id": &"structure_drag_height",
			"cell": cell,
			"current_height": int(terrain_before.get("height", 0)),
			"proposed_height": int(terrain_after.get("height", terrain_before.get("height", 0))),
			"visual_state": visual_state,
			"expected_revision": int(terrain_before.get("revision", -1)),
		})


func _structure_orientation_from_drag_hit(card: CardData, cell: Vector2i, hit: Dictionary) -> StringName:
	if _structure_profile_id_for_card(card) != &"p16_containment_wall":
		return &""
	var requested := StringName(str(hit.get("orientation_edge", hit.get("edge", &""))))
	var target_ref: Variant = hit.get("target_ref", {})
	if requested == &"" and target_ref is Dictionary:
		requested = StringName(str((target_ref as Dictionary).get("edge", &"")))
	if requested in [&"north", &"east", &"south", &"west"]:
		return requested
	var hit_position: Variant = hit.get("position", null)
	if hit_position is Vector3 and _tactical_terrain_presenter != null \
			and is_instance_valid(_tactical_terrain_presenter) \
			and _tactical_terrain_presenter.has_method("get_surface_world_position"):
		var center: Vector3 = _tactical_terrain_presenter.get_surface_world_position(cell)
		var delta: Vector3 = hit_position - center
		if absf(delta.x) >= absf(delta.z):
			return &"east" if delta.x >= 0.0 else &"west"
		return &"south" if delta.z >= 0.0 else &"north"
	for candidate: StringName in [&"north", &"east", &"south", &"west"]:
		var probe: Dictionary = battle.get_structure_build_status(card, cell, _structure_build_query_options(card, cell, candidate))
		if bool(probe.get("ok", false)):
			return candidate
	return &"north"


func _decorate_structure_orientation_status(card: CardData, cell: Vector2i, status: Dictionary) -> Dictionary:
	var decorated := status.duplicate(true)
	if _structure_profile_id_for_card(card) != &"p16_containment_wall":
		return decorated
	var legal_edges: Array[StringName] = []
	var edge_states := {}
	for candidate: StringName in [&"north", &"east", &"south", &"west"]:
		var candidate_status: Dictionary = battle.get_structure_build_status(card, cell, _structure_build_query_options(card, cell, candidate))
		var candidate_ok := bool(candidate_status.get("ok", false))
		if candidate_ok:
			legal_edges.append(candidate)
		edge_states[candidate] = {
			"ok": candidate_ok,
			"reason_code": candidate_status.get("reason_code", &"structure_edge_conflict"),
		}
	decorated["legal_orientation_edges"] = legal_edges.duplicate()
	decorated["orientation_edge_states"] = edge_states.duplicate(true)
	return decorated


func _update_structure_drag_hover(screen_position: Vector2) -> Dictionary:
	return _update_structure_drag_hover_hit(_raycast_3d_click(screen_position), screen_position)


func _structure_cell_from_drag_hit(hit: Dictionary) -> Vector2i:
	if not bool(hit.get("ok", false)):
		return MONSTER_DRAG_INVALID_CELL
	var kind := StringName(str(hit.get("target_kind", "")))
	if kind == &"tactical_cell":
		var board_cell: Variant = hit.get("board_cell", MONSTER_DRAG_INVALID_CELL)
		return board_cell if board_cell is Vector2i else MONSTER_DRAG_INVALID_CELL
	if kind in [&"structure_core", &"structure_module"]:
		var target_ref: Variant = hit.get("target_ref", {})
		if target_ref is Dictionary:
			var structure_cell: Variant = (target_ref as Dictionary).get("cell", MONSTER_DRAG_INVALID_CELL)
			return structure_cell if structure_cell is Vector2i else MONSTER_DRAG_INVALID_CELL
	# A legacy card carrier can sit in front of the structure's semantic proxy.
	# Resolve its live source identity through the existing structure authority,
	# never through row/slot indices or visual transforms.
	var hit_card: Variant = hit.get("card", null)
	if kind == &"" and is_instance_valid(hit_card) and hit_card is CardData and battle != null:
		var structures: Dictionary = battle.get_structure_snapshot().get("structures", {})
		for structure: Dictionary in structures.values():
			if int(structure.get("source_runtime_id", 0)) == hit_card.get_instance_id():
				return structure.get("cell", MONSTER_DRAG_INVALID_CELL)
	return MONSTER_DRAG_INVALID_CELL


func _update_structure_drag_hover_hit(hit: Dictionary, pointer_screen_position: Vector2 = Vector2.INF) -> Dictionary:
	if not _is_structure_build_drag_active():
		return {"ok": false, "cell": MONSTER_DRAG_INVALID_CELL, "reason_code": &"drag_inactive"}
	var cell := _structure_cell_from_drag_hit(hit)
	if cell == MONSTER_DRAG_INVALID_CELL:
		_monster_drag_session["hover_cell"] = MONSTER_DRAG_INVALID_CELL
		_monster_drag_session["hover_status"] = {}
		_clear_structure_build_preview()
		_show_structure_build_tether(MONSTER_DRAG_INVALID_CELL, pointer_screen_position)
		return {"ok": false, "cell": MONSTER_DRAG_INVALID_CELL, "reason_code": &"off_board"}
	var card: CardData = _monster_drag_session.get("card", null)
	var orientation_edge := _structure_orientation_from_drag_hit(card, cell, hit)
	var status: Dictionary = battle.get_structure_build_status(
		card, cell, _structure_build_query_options(card, cell, orientation_edge)).duplicate(true)
	status = _decorate_structure_orientation_status(card, cell, status)
	_monster_drag_session["hover_cell"] = cell
	_monster_drag_session["hover_status"] = status.duplicate(true)
	_monster_drag_session["orientation_edge"] = orientation_edge
	var legal := bool(status.get("ok", false)) or bool(status.get("awaiting_replacement", false))
	_show_structure_build_preview(status, &"legal" if legal else &"invalid")
	_show_structure_build_tether(cell, pointer_screen_position)
	if _structure_interaction_presenter != null and is_instance_valid(_structure_interaction_presenter):
		if legal and _structure_interaction_presenter.has_method("clear_build_refusal"):
			_structure_interaction_presenter.clear_build_refusal()
		elif not legal and _structure_interaction_presenter.has_method("show_build_refusal"):
			var display_name := card.get_display_name() if card != null and card.has_method("get_display_name") else "建筑"
			_structure_interaction_presenter.show_build_refusal(status.duplicate(true), display_name)
	return {
		"ok": legal,
		"cell": cell,
		"orientation_edge": orientation_edge,
		"reason_code": status.get("reason_code", &"structure_target_invalid"),
		"preview_fact": status.duplicate(true),
	}


func _show_structure_build_tether(cell: Vector2i, pointer_screen_position: Vector2 = Vector2.INF) -> void:
	if _monster_summon_interaction_presenter == null or not is_instance_valid(_monster_summon_interaction_presenter):
		return
	var source_screen := _monster_source_screen_anchor()
	var target_screen := _project_tactical_cell_to_screen(cell) if cell != MONSTER_DRAG_INVALID_CELL else pointer_screen_position
	if source_screen.is_finite() and target_screen.is_finite():
		_monster_summon_interaction_presenter.show_drag(
			source_screen, target_screen, _is_reduced_motion_presentation())


func _stage_structure_build_candidate(card_ui: CardUI, cell: Vector2i, preview_fact: Dictionary = {}) -> Dictionary:
	if not _is_structure_build_drag_active() or card_ui == null or not is_instance_valid(card_ui):
		return {"ok": false, "reason_code": &"drag_inactive"}
	var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
	if source_ref == null or source_ref.get_ref() != card_ui:
		return {"ok": false, "reason_code": &"source_mismatch"}
	var card: CardData = _monster_drag_session.get("card", null)
	var orientation_edge := StringName(str(preview_fact.get("orientation_edge", _monster_drag_session.get("orientation_edge", &""))))
	var options := _structure_build_query_options(card, cell, orientation_edge)
	var status: Dictionary = battle.get_structure_build_status(card, cell, options).duplicate(true)
	status = _decorate_structure_orientation_status(card, cell, status)
	if not bool(status.get("ok", false)) and not bool(status.get("awaiting_replacement", false)):
		if _structure_interaction_presenter != null and is_instance_valid(_structure_interaction_presenter) and _structure_interaction_presenter.has_method("show_build_refusal"):
			var rejected_name := card.get_display_name() if card != null and card.has_method("get_display_name") else "建筑"
			_structure_interaction_presenter.show_build_refusal(status.duplicate(true), rejected_name)
		return {"ok": false, "reason_code": status.get("reason_code", &"invalid_cell"), "preview_fact": status}
	_monster_drag_session["state"] = MONSTER_SUMMON_PENDING_CONFIRM
	_monster_drag_session["candidate_cell"] = cell
	_monster_drag_session["hover_cell"] = cell
	_monster_drag_session["hover_status"] = status.duplicate(true)
	_monster_drag_session["orientation_edge"] = StringName(str(status.get("orientation_edge", orientation_edge)))
	if _monster_summon_drop_target != null and is_instance_valid(_monster_summon_drop_target):
		_monster_summon_drop_target.set_board_drag_active(false, &"structure_build")
	_show_structure_build_preview(status, &"pending")
	if not _is_piece_structure_card(card):
		_show_structure_pending_confirmation(status, options)
		return {"ok": true, "cell": cell, "preview_fact": status.duplicate(true)}
	if options.get("replacement_old_card", null) is CardData:
		_pending_piece_replacement_old_card = options.get("replacement_old_card") as CardData
	_begin_piece_selection(card_ui, card, &"play")
	if not _is_piece_selection_active():
		return {"ok": false, "reason_code": &"piece_context_rejected", "preview_fact": status}
	_piece_context["construction_cell"] = cell
	_piece_context["construction_preview_fact"] = status.duplicate(true)
	_confirm_piece_anchor({"type": &"cell", "cell": cell})
	if not _is_piece_selection_active():
		return {"ok": false, "reason_code": &"piece_anchor_rejected", "preview_fact": status}
	_piece_context["construction_cell"] = cell
	_piece_context["construction_preview_fact"] = status.duplicate(true)
	return {"ok": true, "cell": cell, "preview_fact": status.duplicate(true)}


func _cancel_structure_build_interaction(reason: StringName = &"cancel") -> void:
	if StringName(_monster_drag_session.get("intent", &"")) != &"structure_build":
		return
	_cleanup_structure_presentation_lifecycle(reason)


func _structure_drag_debug_snapshot() -> Dictionary:
	var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
	var drop_snapshot: Dictionary = {}
	if _monster_summon_drop_target != null and is_instance_valid(_monster_summon_drop_target):
		drop_snapshot = _monster_summon_drop_target.get_debug_snapshot()
	var structure_preview_nodes := 0
	var structure_presenter_snapshot: Dictionary = {}
	if _tactical_structure_presenter != null and is_instance_valid(_tactical_structure_presenter):
		if _tactical_structure_presenter.has_method("get_debug_snapshot"):
			structure_presenter_snapshot = _tactical_structure_presenter.get_debug_snapshot()
		var preview_root := _tactical_structure_presenter.get_node_or_null(NodePath("StructurePreviewRoot"))
		if preview_root != null:
			structure_preview_nodes = preview_root.get_child_count()
	return {
		"active": _is_monster_summon_interaction_active() and StringName(_monster_drag_session.get("intent", &"")) == &"structure_build",
		"state": _monster_summon_state(),
		"intent": StringName(_monster_drag_session.get("intent", &"")),
		"origin": StringName(_monster_drag_session.get("origin", &"")),
		"source_alive": source_ref != null and source_ref.get_ref() != null,
		"legal_cells": _monster_drag_session.get("legal_cells", []).duplicate(),
		"inspectable_cells": _monster_drag_session.get("inspectable_cells", []).duplicate(),
		"orientation_edge": StringName(str(_monster_drag_session.get("orientation_edge", &""))),
		"hover_cell": _monster_drag_session.get("hover_cell", MONSTER_DRAG_INVALID_CELL),
		"candidate_cell": _monster_drag_session.get("candidate_cell", MONSTER_DRAG_INVALID_CELL),
		"preview_fact": (_monster_drag_session.get("hover_status", {}) as Dictionary).duplicate(true),
		"locked_preview_fact": (_monster_drag_session.get("locked_preview_fact", {}) as Dictionary).duplicate(true),
		"drop_target_active": bool(drop_snapshot.get("active", false)),
		"drop_target_intent": StringName(drop_snapshot.get("intent", &"")),
		"structure_preview_nodes": structure_preview_nodes,
		"structure_presenter": structure_presenter_snapshot,
		"camera_orbit_frozen": _camera_orbit_frozen,
		"pending_confirmation": bool(_monster_drag_session.get("pending_confirmation", false)),
		"last_commit_had_structure_fact": _structure_drag_last_commit_had_structure_fact,
	}


func _show_structure_pending_confirmation(status: Dictionary, options: Dictionary) -> Dictionary:
	if StringName(_monster_drag_session.get("intent", &"")) != &"structure_build":
		return {"ok": false, "reason_code": &"not_structure_build"}
	var card: CardData = _monster_drag_session.get("card", null)
	var preview: Dictionary = status.get("structure_build_preview", status)
	if preview.is_empty():
		preview = _monster_drag_session.get("hover_status", {})
	if card == null or preview.is_empty():
		return {"ok": false, "reason_code": &"structure_preview_missing"}
	_monster_drag_session["state"] = MONSTER_SUMMON_PENDING_CONFIRM
	_monster_drag_session["pending_confirmation"] = true
	_monster_drag_session["pending_action_options"] = options.duplicate(true)
	_monster_drag_session["pending_piece_status"] = status.duplicate(true)
	_monster_drag_session["locked_preview_fact"] = preview.duplicate(true)
	_monster_drag_session["orientation_edge"] = StringName(str(preview.get("orientation_edge", options.get("orientation_edge", &""))))
	_monster_drag_session["replacement_structure_id"] = StringName(str(preview.get("replacement_structure_id", &"")))
	_monster_drag_session["replacement_source_runtime_id"] = int(preview.get("replacement_source_runtime_id", 0))
	_monster_drag_session["expected_terrain_revision"] = int(preview.get("expected_terrain_revision", -1))
	_monster_drag_session["expected_structure_revision"] = int(preview.get("expected_structure_revision", -1))
	_monster_drag_session["expected_garrison_revision"] = int(preview.get("expected_garrison_revision", -1))
	_show_structure_build_preview(preview, &"pending")
	if _structure_interaction_presenter != null and is_instance_valid(_structure_interaction_presenter):
		var display_name := card.get_display_name() if card.has_method("get_display_name") else card.card_name
		var target_cell: Vector2i = preview.get("piece_anchor_cell", preview.get("cell", MONSTER_DRAG_INVALID_CELL))
		_structure_interaction_presenter.show_build_pending(preview.duplicate(true), display_name, true, "", _project_tactical_cell_to_screen(target_cell))
	_set_end_turn_busy_for_structure(true, "建设：确认或取消")
	return {"ok": false, "reason_code": &"structure_confirmation_required", "awaiting_confirmation": true, "preview_fact": preview.duplicate(true)}


func _begin_structure_build_reselect() -> void:
	if StringName(_monster_drag_session.get("intent", &"")) != &"structure_build" \
			or _monster_summon_state() != MONSTER_SUMMON_PENDING_CONFIRM:
		return
	var card: CardData = _monster_drag_session.get("card", null)
	var refreshed := _structure_build_candidate_cells(card)
	var inspectable := _structure_build_inspectable_cells(card)
	if card == null or (refreshed.is_empty() and inspectable.is_empty()):
		_cancel_structure_build_interaction(&"reselect_unavailable")
		return
	_cancel_piece_context(&"structure_reselect")
	_monster_drag_session["state"] = MONSTER_SUMMON_RESELECTING
	_monster_drag_session["pending_confirmation"] = false
	_monster_drag_session["candidate_cell"] = MONSTER_DRAG_INVALID_CELL
	_monster_drag_session["hover_cell"] = MONSTER_DRAG_INVALID_CELL
	_monster_drag_session["hover_status"] = {}
	_monster_drag_session["legal_cells"] = refreshed.duplicate()
	_monster_drag_session["inspectable_cells"] = inspectable.duplicate()
	_monster_drag_session["orientation_edge"] = &""
	_monster_drag_session.erase("pending_action_options")
	_monster_drag_session.erase("pending_piece_status")
	_monster_drag_session.erase("locked_preview_fact")
	_monster_drag_session.erase("confirm_authorized")
	_monster_drag_session.erase("replacement_structure_id")
	_monster_drag_session.erase("replacement_source_runtime_id")
	_monster_drag_session.erase("expected_terrain_revision")
	_monster_drag_session.erase("expected_structure_revision")
	_monster_drag_session.erase("expected_garrison_revision")
	_clear_structure_build_preview()
	_set_end_turn_busy_for_structure(true)
	if _structure_interaction_presenter != null and is_instance_valid(_structure_interaction_presenter):
		_structure_interaction_presenter.clear_build_pending()
	if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
		_tactical_presenter.show_cell_selection(
			&"build", &"player", MONSTER_DRAG_INVALID_CELL,
			refreshed, battle.get_occupied_cells(), {})


func _recover_stale_structure_build(status: Dictionary) -> Dictionary:
	_begin_structure_build_reselect()
	return {
		"ok": false,
		"reason_code": status.get("reason_code", &"structure_target_stale"),
		"status": status.duplicate(true),
	}


func _confirm_pending_structure_build() -> Dictionary:
	if StringName(_monster_drag_session.get("intent", &"")) != &"structure_build" \
			or _monster_summon_state() != MONSTER_SUMMON_PENDING_CONFIRM \
			or not bool(_monster_drag_session.get("pending_confirmation", false)):
		return {"ok": false, "reason_code": &"not_pending"}
	var generation := int(_monster_drag_session.get("generation", -1))
	if int(_monster_drag_session.get("committed_generation", -2)) == generation:
		return {"ok": false, "reason_code": &"already_committed"}
	var card: CardData = _monster_drag_session.get("card", null)
	var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
	var card_ui := source_ref.get_ref() as CardUI if source_ref != null else null
	var cell: Vector2i = _monster_drag_session.get("candidate_cell", MONSTER_DRAG_INVALID_CELL)
	if battle == null or context == null or context.player == null or card == null \
			or card_ui == null or not is_instance_valid(card_ui) or card_ui.card_data != card \
			or not card in context.player.hand:
		return _recover_stale_structure_build({"reason_code": &"structure_source_stale"})
	var locked: Dictionary = _monster_drag_session.get("locked_preview_fact", {})
	var orientation_edge := StringName(str(locked.get("orientation_edge", _monster_drag_session.get("orientation_edge", &""))))
	var query_options := _structure_build_query_options(card, cell, orientation_edge)
	if locked.has("footprint_edge"): query_options["footprint_edge"] = locked.footprint_edge
	query_options["expected_terrain_revision"] = int(locked.get("expected_terrain_revision", -1))
	query_options["expected_structure_revision"] = int(locked.get("expected_structure_revision", -1))
	query_options["expected_garrison_revision"] = int(locked.get("expected_garrison_revision", -1))
	var fresh: Dictionary = battle.get_structure_build_status(card, cell, query_options)
	if not bool(fresh.get("ok", false)):
		return _recover_stale_structure_build(fresh)
	_monster_drag_session["state"] = MONSTER_SUMMON_COMMITTING
	_monster_drag_session["confirm_authorized"] = true
	_monster_drag_session["committed_generation"] = generation
	if not _is_piece_structure_card(card):
		var direct_result: Dictionary = battle.commit_structure_build_or_upgrade(card, cell, query_options)
		if not bool(direct_result.get("ok", false)):
			_monster_drag_session["state"] = MONSTER_SUMMON_PENDING_CONFIRM
			_monster_drag_session.erase("confirm_authorized")
			_monster_drag_session.erase("committed_generation")
			return _recover_stale_structure_build(direct_result)
		# Capture the immutable success fact before cleanup clears the shared session.
		var committed_fact: Dictionary = (direct_result.get("structure_build_fact", {}) as Dictionary).duplicate(true)
		_structure_drag_last_commit_had_structure_fact = not committed_fact.is_empty()
		if card_ui.has_method("accept_board_drop"):
			card_ui.accept_board_drop()
		_cleanup_monster_drag_summon(&"structure_confirm_success", true)
		_refresh_tables()
		check_battle_end()
		return direct_result
	var action_options: Dictionary = _monster_drag_session.get("pending_action_options", {}).duplicate(true)
	var result: Dictionary = _confirm_piece_action(action_options)
	if not bool(result.get("ok", false)):
		_monster_drag_session["state"] = MONSTER_SUMMON_PENDING_CONFIRM
		_monster_drag_session.erase("confirm_authorized")
		_monster_drag_session.erase("committed_generation")
		return _recover_stale_structure_build(result)
	_structure_drag_last_commit_had_structure_fact = result.has("structure_build_fact")
	if card_ui.has_method("accept_board_drop"):
		card_ui.accept_board_drop()
	_cleanup_monster_drag_summon(&"structure_confirm_success", true)
	return result


func _on_structure_build_confirm_requested() -> void:
	_confirm_pending_structure_build()


func _on_structure_build_cancel_requested() -> void:
	_cancel_structure_build_interaction(&"panel_cancel")


func _can_begin_monster_drag(card_ui: CardUI, card: CardData) -> bool:
	if card_ui == null or not is_instance_valid(card_ui) or battle == null or context == null:
		return false
	if card_ui.card_data != card or not _is_monster_card_for_drag(card):
		return false
	if _has_non_presentation_end_turn_busy() or _presentation_end_turn_blocked:
		return false
	if context.player == null or not card in context.player.hand:
		return false
	return battle.can_play_card(card)


func _begin_monster_drag_summon(card_ui: CardUI, card: CardData) -> bool:
	if _is_monster_summon_interaction_active():
		return false
	# A left press emits card_clicked before Godot crosses the drag threshold.
	# Let the same card's drag take over that transient click-selection only;
	# every unrelated busy/selection state remains protected below.
	if _lane_selection_mode == LANE_SELECT_SUMMON and _lane_selection_card == card:
		_cancel_lane_selection(&"monster_drag_takeover")
	if not _can_begin_monster_drag(card_ui, card):
		return false
	var legal: Array[Vector2i] = battle.get_legal_summon_cells(&"player")
	if legal.is_empty():
		if action_feed:
			action_feed.push_message("没有可用的召唤格", TC.WARNING, "", 1.5)
		return false
	_monster_drag_generation += 1
	_monster_drag_last_drop_screen_position = Vector2.INF
	_monster_drag_session = {
		"active": true,
		"intent": &"monster_summon",
		"state": MONSTER_SUMMON_DRAGGING,
		"generation": _monster_drag_generation,
		"card": card,
		"card_ui_ref": weakref(card_ui),
		"legal_cells": legal.duplicate(),
		"hover_cell": MONSTER_DRAG_INVALID_CELL,
		"hover_status": {},
		"candidate_cell": MONSTER_DRAG_INVALID_CELL,
		"last_cleanup_reason": &"",
		"camera_was_frozen": _camera_orbit_frozen,
	}
	card_ui.set_summon_reservation_visual(true)
	_camera_orbit_frozen = true
	if _monster_summon_drop_target != null and is_instance_valid(_monster_summon_drop_target):
		_monster_summon_drop_target.set_drag_active(true)
	_ensure_tactical_movement_presenter()
	if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
		_tactical_presenter.show_cell_selection(
			&"summon", &"player", MONSTER_DRAG_INVALID_CELL,
			legal, battle.get_occupied_cells(), {}
		)
	if action_feed:
		action_feed.push_message("拖到高亮格召唤；其他位置松开则取消", TC.INFO, "", 1.2)
	return true


func _on_player_hand_drag_started(card_ui: CardUI) -> void:
	if card_ui == null or not is_instance_valid(card_ui):
		return
	var card := card_ui.card_data
	if _is_monster_summon_interaction_active():
		var active_card: CardData = _monster_drag_session.get("card", null)
		if active_card == card:
			if card.card_id in ["P22", "P23"] and _monster_summon_state() == MONSTER_SUMMON_RESELECTING:
				_monster_drag_session.state = MONSTER_SUMMON_DRAGGING
				_monster_drag_session.origin = &"drag"
				if is_instance_valid(_monster_summon_drop_target):
					_monster_summon_drop_target.set_board_drag_active(true, _monster_drag_session.intent)
				_refresh_card_target_guidance()
				return
			# A BUILD press opens click selection before Godot's drag threshold.
			# Promote that same source/session; pending confirmations stay locked.
			var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
			if _is_structure_build_drag_active() and _monster_drag_session.get("origin", &"") == &"click" \
					and _monster_summon_state() == MONSTER_SUMMON_RESELECTING \
					and source_ref != null and source_ref.get_ref() == card_ui:
				_monster_drag_session["state"] = MONSTER_SUMMON_DRAGGING
				_monster_drag_session["origin"] = &"drag"
				if is_instance_valid(_monster_summon_drop_target):
					_monster_summon_drop_target.set_board_drag_active(true, &"structure_build")
			return
		_cleanup_monster_drag_summon(&"card_switch")
	if _is_monster_card_for_drag(card):
		_begin_monster_drag_summon(card_ui, card)
	elif _is_structure_card_for_drag(card):
		_begin_structure_build_drag(card_ui, card)
	else:
		var intent := _classify_board_drag_intent(card)
		if intent in [CARD_DRAG_FRIENDLY_ANCHOR, CARD_DRAG_TRIPWIRE, CARD_DRAG_DIRECTED_SPELL]:
			_begin_piece_card_drag(card_ui, card, intent)
		elif intent in [CARD_DRAG_CAST_LANE, CARD_DRAG_FINISHER]:
			_begin_cast_lane_drag(card_ui, card, intent)


func _on_player_hand_drag_ended(_card_ui: CardUI) -> void:
	var generation := int(_monster_drag_session.get("generation", -1))
	call_deferred("_finalize_monster_pointer_drag_end", generation)


func _finalize_monster_pointer_drag_end(generation: int) -> void:
	if generation != int(_monster_drag_session.get("generation", -2)):
		return
	if _monster_summon_state() == MONSTER_SUMMON_DRAGGING:
		_cleanup_monster_drag_summon(&"hand_drag_end_without_drop")


func _update_monster_drag_hover(screen_position: Vector2) -> Dictionary:
	var result := _update_monster_drag_hover_hit(_raycast_3d_click(screen_position))
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		var cell: Vector2i = result.get("cell", MONSTER_DRAG_INVALID_CELL)
		var target_screen := _project_tactical_cell_to_screen(cell) if cell != MONSTER_DRAG_INVALID_CELL else screen_position
		var source_screen := _monster_source_screen_anchor()
		if source_screen.is_finite() and target_screen.is_finite():
			_monster_summon_interaction_presenter.show_drag(source_screen, target_screen, _is_reduced_motion_presentation())
	return result


func _update_monster_drag_hover_hit(hit: Dictionary) -> Dictionary:
	if not _is_monster_drag_active():
		return {"ok": false, "cell": MONSTER_DRAG_INVALID_CELL, "reason_code": &"drag_inactive"}
	if not bool(hit.get("ok", false)) or StringName(str(hit.get("target_kind", ""))) != &"tactical_cell":
		_monster_drag_session["hover_cell"] = MONSTER_DRAG_INVALID_CELL
		_monster_drag_session["hover_status"] = {}
		if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
			_tactical_presenter.clear_drag_hover()
		return {"ok": false, "cell": MONSTER_DRAG_INVALID_CELL, "reason_code": &"off_board"}
	var raw_cell: Variant = hit.get("board_cell", MONSTER_DRAG_INVALID_CELL)
	if not raw_cell is Vector2i:
		return {"ok": false, "cell": MONSTER_DRAG_INVALID_CELL, "reason_code": &"bad_cell"}
	var cell: Vector2i = raw_cell
	var previous_cell: Vector2i = _monster_drag_session.get("hover_cell", MONSTER_DRAG_INVALID_CELL)
	var card: CardData = _monster_drag_session.get("card", null)
	var status: Dictionary = battle.get_monster_summon_cell_status(card, cell, &"player")
	_monster_drag_session["hover_cell"] = cell
	_monster_drag_session["hover_status"] = status.duplicate(true)
	if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
		var visual_state: StringName = &"hover" if bool(status.get("ok", false)) else &"invalid"
		_tactical_presenter.set_drag_hover(cell, status, _is_reduced_motion_presentation(), visual_state, card)
	if cell != previous_cell and not bool(status.get("ok", false)) and action_feed:
		action_feed.push_message(_monster_drag_reason_text(status), TC.WARNING, "", 0.8)
	return {"ok": bool(status.get("ok", false)), "cell": cell, "status": status}


func _monster_drag_reason_text(status: Dictionary) -> String:
	match StringName(status.get("reason_code", &"")):
		&"cell_out_of_bounds": return "目标不在棋盘内"
		&"wrong_home_rank": return "只能召唤到己方召唤区"
		&"cell_occupied": return "该格已被占用"
		&"invalid_card": return "卡牌状态已经失效"
		&"not_front_monster": return "该卡牌不能召唤到怪兽区"
		&"card_play_blocked": return str(status.get("reason", "当前不能打出这张牌"))
	return "该位置现在无法召唤"


func _stage_monster_summon_candidate(card_ui: CardUI, cell: Vector2i) -> Dictionary:
	if not _is_monster_drag_active() or card_ui == null or not is_instance_valid(card_ui):
		return {"ok": false, "reason_code": &"drag_inactive"}
	var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
	if source_ref == null or source_ref.get_ref() != card_ui:
		return {"ok": false, "reason_code": &"source_mismatch"}
	var card: CardData = _monster_drag_session.get("card", null)
	var status: Dictionary = battle.get_monster_summon_cell_status(card, cell, &"player")
	if not bool(status.get("ok", false)):
		return {"ok": false, "reason_code": status.get("reason_code", &"invalid_cell"), "status": status}
	_monster_drag_session["state"] = MONSTER_SUMMON_PENDING_CONFIRM
	_monster_drag_session["candidate_cell"] = cell
	_monster_drag_session["hover_cell"] = cell
	if _tactical_terrain_presenter != null and is_instance_valid(_tactical_terrain_presenter):
		_tactical_terrain_presenter.set_focus_cell(cell, _get_3d_camera())
	_monster_summon_drop_target.set_drag_active(false)
	if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
		_tactical_presenter.set_drag_hover(cell, status, _is_reduced_motion_presentation(), &"pending", card)
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		var source_screen := _monster_source_screen_anchor()
		var target_screen := _project_tactical_cell_to_screen(cell)
		if source_screen.is_finite() and target_screen.is_finite():
			var card_name := card.get_display_name() if card.has_method("get_display_name") else card.card_name
			var state: Dictionary = battle.get_cell_state(cell)
			_monster_summon_interaction_presenter.show_pending(source_screen, target_screen, card_name, cell, _is_reduced_motion_presentation(), {"height": battle.get_cell_height(cell), "surface": state.get("surface", &"")})
	return {"ok": true, "cell": cell, "status": status}


func _begin_monster_summon_reselect() -> void:
	if _monster_summon_state() != MONSTER_SUMMON_PENDING_CONFIRM:
		return
	# Re-selection abandons the old visual target before relighting legal cells.
	# The pending summon remains authority-pure, but terrain focus must not stay stale.
	if _tactical_terrain_presenter != null and is_instance_valid(_tactical_terrain_presenter):
		_tactical_terrain_presenter.clear_focus()
	var card: CardData = _monster_drag_session.get("card", null)
	var refreshed: Array[Vector2i] = battle.get_legal_summon_cells(&"player")
	if card == null or refreshed.is_empty() or not battle.can_play_card(card):
		_cleanup_monster_drag_summon(&"reselect_unavailable")
		return
	_monster_drag_session["state"] = MONSTER_SUMMON_RESELECTING
	_monster_drag_session["candidate_cell"] = MONSTER_DRAG_INVALID_CELL
	_monster_drag_session["legal_cells"] = refreshed.duplicate()
	_lane_selection_mode = LANE_SELECT_SUMMON
	_lane_selection_card = card
	_lane_selection_card_ui_ref = _monster_drag_session.get("card_ui_ref")
	_lane_selection_source = &"drag_reselect"
	_cell_selection_legal = refreshed.duplicate()
	_ensure_tactical_movement_presenter()
	if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
		_tactical_presenter.show_cell_selection(
			&"summon", &"player", MONSTER_DRAG_INVALID_CELL,
			refreshed, battle.get_occupied_cells(), {}
		)
	var pointer: Vector2 = _monster_drag_session.get("last_pointer_screen_position", _monster_source_screen_anchor())
	_monster_summon_interaction_presenter.show_reselect(_monster_source_screen_anchor(), pointer, _is_reduced_motion_presentation())


func _stage_reselected_monster_cell(cell: Vector2i) -> Dictionary:
	if _monster_summon_state() != MONSTER_SUMMON_RESELECTING:
		return {"ok": false, "reason_code": &"not_reselecting"}
	var card: CardData = _monster_drag_session.get("card", null)
	var status: Dictionary = battle.get_monster_summon_cell_status(card, cell, &"player")
	if not bool(status.get("ok", false)):
		var refreshed: Array[Vector2i] = battle.get_legal_summon_cells(&"player")
		_monster_drag_session["legal_cells"] = refreshed.duplicate()
		_cell_selection_legal = refreshed.duplicate()
		if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
			_tactical_presenter.play_cell_reject(cell)
			_tactical_presenter.show_cell_selection(
				&"summon", &"player", MONSTER_DRAG_INVALID_CELL,
				refreshed, battle.get_occupied_cells(), {}
			)
		if action_feed:
			action_feed.push_message(_monster_drag_reason_text(status), TC.WARNING, "", 0.8)
		return {"ok": false, "reason_code": status.get("reason_code", &"invalid_cell"), "status": status}
	_clear_drag_reselect_lane_fields()
	_monster_drag_session["state"] = MONSTER_SUMMON_PENDING_CONFIRM
	_monster_drag_session["candidate_cell"] = cell
	_monster_drag_session["hover_cell"] = cell
	_show_pending_monster_candidate(cell, status)
	return {"ok": true, "cell": cell, "status": status}


func _clear_drag_reselect_lane_fields() -> void:
	if _lane_selection_source != &"drag_reselect":
		return
	_lane_selection_mode = LANE_SELECT_NONE
	_lane_selection_card = null
	_lane_selection_card_ui_ref = null
	_lane_selection_source = &""
	_lane_selection_zone = ""
	_cell_selection_legal.clear()


func _show_pending_monster_candidate(cell: Vector2i, status: Dictionary) -> void:
	var card: CardData = _monster_drag_session.get("card", null)
	var source_screen := _monster_source_screen_anchor()
	var target_screen := _project_tactical_cell_to_screen(cell)
	if _tactical_terrain_presenter != null and is_instance_valid(_tactical_terrain_presenter):
		_tactical_terrain_presenter.set_focus_cell(cell, _get_3d_camera())
	if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
		_tactical_presenter.set_drag_hover(cell, status, _is_reduced_motion_presentation(), &"pending", card)
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		_monster_summon_interaction_presenter.show_pending(
			source_screen, target_screen, card.card_name if card != null else "未知怪兽", cell,
			_is_reduced_motion_presentation(), {"height": battle.get_cell_height(cell), "surface": battle.get_cell_state(cell).get("surface", &"")}
		)


func _on_monster_summon_confirm_requested() -> void:
	if _monster_summon_state() != MONSTER_SUMMON_PENDING_CONFIRM:
		return
	await _confirm_pending_monster_summon()


func _on_shared_card_confirm_requested() -> void:
	if _monster_drag_session.get("intent") == &"siege_attack":
		_confirm_siege_selection()
		return
	if bool(_garrison_context.get("active", false)):
		_confirm_pending_garrison()
		return
	var intent := StringName(_monster_drag_session.get("intent", &""))
	if intent == &"structure_build":
		_on_structure_build_confirm_requested()
	elif _is_card_cast_drag_intent(intent):
		await _confirm_pending_card_cast()
	else:
		await _confirm_pending_monster_summon()


func _on_shared_card_reselect_requested() -> void:
	if _monster_drag_session.get("intent") == &"siege_attack":
		_reselect_siege_selection()
		return
	if bool(_garrison_context.get("active", false)):
		_reselect_garrison_selection()
		return
	var intent := StringName(_monster_drag_session.get("intent", &""))
	if intent == &"structure_build":
		_begin_structure_build_reselect()
	elif _is_card_cast_drag_intent(intent):
		_begin_card_cast_reselect()
	else:
		_begin_monster_summon_reselect()


func _on_shared_card_cancel_requested() -> void:
	if bool(_garrison_context.get("active", false)):
		_clear_garrison_selection(&"panel_cancel")
		return
	_cancel_monster_summon_interaction(&"panel_cancel")


func _on_monster_summon_cancel_requested() -> void:
	_cancel_monster_summon_interaction(&"panel_cancel")


func _confirm_pending_monster_summon() -> Dictionary:
	if _monster_summon_state() != MONSTER_SUMMON_PENDING_CONFIRM:
		return {"ok": false, "reason_code": &"not_pending"}
	var generation := int(_monster_drag_session.get("generation", -1))
	if int(_monster_drag_session.get("committed_generation", -2)) == generation:
		return {"ok": false, "reason_code": &"already_committed"}
	var card: CardData = _monster_drag_session.get("card", null)
	var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
	var card_ui := source_ref.get_ref() as CardUI if source_ref != null else null
	var cell: Vector2i = _monster_drag_session.get("candidate_cell", MONSTER_DRAG_INVALID_CELL)
	if battle == null or card == null or card_ui == null or not is_instance_valid(card_ui) or card_ui.card_data != card:
		return _recover_from_stale_monster_candidate({"reason_code": &"stale_candidate"})
	if context == null or context.player == null or not card in context.player.hand or not battle.can_play_card(card):
		return _recover_from_stale_monster_candidate({"reason_code": &"card_play_blocked"})
	var status: Dictionary = battle.get_monster_summon_cell_status(card, cell, &"player")
	if not bool(status.get("ok", false)):
		return _recover_from_stale_monster_candidate(status)
	_monster_drag_session["state"] = MONSTER_SUMMON_COMMITTING
	_monster_drag_session["committed_generation"] = generation
	var source_screen := _monster_source_screen_anchor()
	var target_screen := _project_tactical_cell_to_screen(cell)
	var result: Dictionary = await _commit_monster_summon(card_ui, card, cell, &"drag_confirm")
	if not _is_current_monster_summon_generation(generation, MONSTER_SUMMON_COMMITTING):
		return {"ok": false, "reason_code": &"stale_confirmation_result", "result": result}
	if bool(result.get("ok", false)):
		_cleanup_monster_drag_summon(&"confirm_success", true)
		if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
			_monster_summon_interaction_presenter.play_success(source_screen, target_screen, _is_reduced_motion_presentation())
		return result
	return _recover_from_stale_monster_candidate(result, true)


func _is_current_monster_summon_generation(generation: int, expected_state: StringName) -> bool:
	return int(_monster_drag_session.get("generation", -1)) == generation and _monster_summon_state() == expected_state


func _recover_from_stale_monster_candidate(status: Dictionary, mint_recovery_generation: bool = false) -> Dictionary:
	var card: CardData = _monster_drag_session.get("card", null)
	var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
	var card_ui := source_ref.get_ref() as CardUI if source_ref != null else null
	var refreshed: Array[Vector2i] = []
	if battle != null:
		refreshed = battle.get_legal_summon_cells(&"player")
	if card != null and card_ui != null and is_instance_valid(card_ui) and battle != null and context != null and context.player != null and card in context.player.hand and battle.can_play_card(card) and not refreshed.is_empty():
		# A stale candidate is no longer the pending visual target. Clear its
		# terrain focus before presenting the refreshed reselect choices.
		if _tactical_terrain_presenter != null and is_instance_valid(_tactical_terrain_presenter):
			_tactical_terrain_presenter.clear_focus()
		if mint_recovery_generation:
			_monster_drag_session["failed_generation"] = _monster_drag_session.get("generation", -1)
			_monster_drag_generation += 1
			_monster_drag_session["generation"] = _monster_drag_generation
			_monster_drag_session.erase("committed_generation")
		_monster_drag_session["state"] = MONSTER_SUMMON_RESELECTING
		_monster_drag_session["candidate_cell"] = MONSTER_DRAG_INVALID_CELL
		_monster_drag_session["legal_cells"] = refreshed.duplicate()
		_lane_selection_mode = LANE_SELECT_SUMMON
		_lane_selection_card = card
		_lane_selection_card_ui_ref = source_ref
		_lane_selection_source = &"drag_reselect"
		_cell_selection_legal = refreshed.duplicate()
		_ensure_tactical_movement_presenter()
		if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
			_tactical_presenter.show_cell_selection(
				&"summon", &"player", MONSTER_DRAG_INVALID_CELL,
				refreshed, battle.get_occupied_cells(), {}
			)
		if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
			var pointer: Vector2 = _monster_drag_session.get("last_pointer_screen_position", _monster_source_screen_anchor())
			_monster_summon_interaction_presenter.show_reselect(_monster_source_screen_anchor(), pointer, _is_reduced_motion_presentation())
		return {"ok": false, "reason_code": status.get("reason_code", &"stale_candidate"), "status": status}
	_cleanup_monster_drag_summon(&"stale_candidate_no_recovery", mint_recovery_generation)
	return {"ok": false, "reason_code": status.get("reason_code", &"stale_candidate"), "status": status}


func _can_deliver_monster_drop(screen_position: Vector2, data: Variant) -> bool:
	var intent := StringName(_monster_drag_session.get("intent", &""))
	var card_cast_pointer_active := _is_card_cast_drag_intent(intent) \
			and _monster_summon_state() in [MONSTER_SUMMON_DRAGGING, MONSTER_SUMMON_RESELECTING]
	if (not _is_monster_drag_active() and not card_cast_pointer_active) \
			or not data is CardUI or not is_instance_valid(data):
		return false
	var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
	if source_ref == null or source_ref.get_ref() != data:
		return false
	# The one full-screen receiver consumes every matching native release while
	# the session is active. Semantic raycast legality below decides commit vs
	# cancel, so the OS never substitutes its forbidden-drop cursor off-board.
	if not screen_position.is_finite():
		return false
	if intent == &"structure_build":
		_update_structure_drag_hover(screen_position)
	elif _is_card_cast_drag_intent(intent):
		_update_card_cast_drag(screen_position)
	else:
		_update_monster_drag_hover(screen_position)
	return true


func _drop_monster_on_board(screen_position: Vector2, data: Variant) -> void:
	var active_intent := StringName(_monster_drag_session.get("intent", &""))
	var card_cast_pointer_active := _is_card_cast_drag_intent(active_intent) \
			and _monster_summon_state() in [MONSTER_SUMMON_DRAGGING, MONSTER_SUMMON_RESELECTING]
	if (not _is_monster_drag_active() and not card_cast_pointer_active) \
			or not data is CardUI or not is_instance_valid(data):
		_cleanup_monster_drag_summon(&"invalid_drop_source")
		return
	var source_ref: WeakRef = _monster_drag_session.get("card_ui_ref", null) as WeakRef
	if source_ref == null or source_ref.get_ref() != data:
		_cleanup_monster_drag_summon(&"mismatched_drop_source")
		return
	_monster_drag_last_drop_screen_position = screen_position
	var intent := StringName(_monster_drag_session.get("intent", &""))
	if _is_card_cast_drag_intent(intent):
		var cast_hover := _update_card_cast_drag(screen_position)
		if not bool(cast_hover.get("ok", false)):
			_cleanup_card_cast_interaction(&"invalid_drop_target")
			return
		if intent == CARD_DRAG_CAST_LANE and not bool(cast_hover.get("preview_fact", {}).get("siege_mode", false)) and not bool(cast_hover.get("preview_fact", {}).get("repair_mode", false)) and not bool(cast_hover.get("preview_fact", {}).get("terrain_raise_mode", false)):
			var generation := int(_monster_drag_session.get("generation", -1))
			var card: CardData = _monster_drag_session.get("card", null)
			if battle == null or context == null or context.player == null or card == null \
					or not card in context.player.hand or not battle.can_play_card(card):
				_cleanup_card_cast_interaction(&"cast_source_unplayable")
				return
			_monster_drag_session["state"] = MONSTER_SUMMON_COMMITTING
			_monster_drag_session["locked_preview_fact"] = (cast_hover.get("preview_fact", {}) as Dictionary).duplicate(true)
			call_deferred("_handoff_card_cast_to_existing_click", source_ref, generation)
			return
		var cast_staged := _stage_card_cast_candidate(data as CardUI, cast_hover.get("preview_fact", {}))
		if not bool(cast_staged.get("ok", false)):
			_cleanup_card_cast_interaction(&"invalid_drop_target")
		return
	var hover_result := _update_structure_drag_hover(screen_position) \
		if intent == &"structure_build" else _update_monster_drag_hover(screen_position)
	if not bool(hover_result.get("ok", false)):
		_cleanup_monster_drag_summon(&"invalid_drop_cell")
		return
	var card_ui: CardUI = data as CardUI
	var cell: Vector2i = hover_result.get("cell", MONSTER_DRAG_INVALID_CELL)
	var staged: Dictionary = _stage_structure_build_candidate(
		card_ui, cell, hover_result.get("preview_fact", {})) \
		if intent == &"structure_build" else _stage_monster_summon_candidate(card_ui, cell)
	if not bool(staged.get("ok", false)):
		_cleanup_monster_drag_summon(&"invalid_drop_cell")


func _commit_monster_summon(card_ui: CardUI, card: CardData, cell: Vector2i, source: StringName) -> Dictionary:
	if battle == null or card == null:
		return {"ok": false, "reason_code": &"invalid_state", "reason": "召唤状态已经失效"}
	var status: Dictionary = battle.get_monster_summon_cell_status(card, cell, &"player")
	if not bool(status.get("ok", false)):
		return status
	_card_being_played = true
	_stat_total_cards += 1
	_trigger_guides_on_card_play()
	context.combo_system.on_card_played()
	_monster_drag_commit_count += 1
	var play_result: Dictionary = battle.play_card(card, -1, cell)
	_card_being_played = false
	if not bool(play_result.get("ok", false)):
		if action_feed:
			action_feed.push_message(str(play_result.get("reason", "出牌失败")), TC.WARNING, "", 2.0)
		return play_result
	if source in [&"drag", &"drag_confirm"] and card_ui != null and is_instance_valid(card_ui) and card_ui.has_method("accept_board_drop"):
		card_ui.accept_board_drop()
	if card_ui != null and is_instance_valid(card_ui) and card_ui.has_method("play_leave_animation"):
		card_ui.play_leave_animation()
	_refresh_tables()
	var actual_cell: Vector2i = battle.get_unit_cell(card)
	var summon_token := _get_3d_token_for_card(card)
	var summon_facts := play_result.duplicate(true)
	summon_facts.merge({
		"status": &"committed",
		"card": card,
		"card_id": StringName(card.card_id),
		"piece_type": StringName(card.piece_type if not card.piece_type.is_empty() else "pawn"),
		"board_cell": actual_cell,
		"target_position": _project_3d_token_to_screen(summon_token) if summon_token != null else Vector2.INF,
	}, true)
	await _play_monster_presentation(&"summon", summon_facts)
	check_battle_end()
	if _playtest:
		_playtest.record_event("card_played", {"card": card.card_name, "board_cell": actual_cell})
	return play_result


func _cancel_monster_summon_interaction(reason: StringName) -> void:
	if not _is_monster_summon_interaction_active() or _monster_summon_state() == MONSTER_SUMMON_COMMITTING:
		return
	if StringName(_monster_drag_session.get("intent", &"")) == &"structure_build":
		_cancel_structure_build_interaction(reason)
		return
	if _is_card_cast_drag_intent(StringName(_monster_drag_session.get("intent", &""))):
		_cancel_card_cast_interaction(reason)
		return
	_cleanup_monster_drag_summon(reason)


func _cleanup_monster_drag_summon(reason: StringName = &"cleanup", allow_committing: bool = false) -> void:
	if _monster_summon_state() == MONSTER_SUMMON_COMMITTING and not allow_committing:
		return
	_clear_siege_presentation(reason)
	var intent := StringName(_monster_drag_session.get("intent", &""))
	if intent == &"structure_build":
		_cleanup_structure_presentation_lifecycle(reason)
		return
	if _is_card_cast_drag_intent(intent):
		_cleanup_card_cast_interaction(reason, allow_committing)
		return
	var source_ref: WeakRef = _monster_drag_session.get("card_ui_ref", null) as WeakRef
	var source := source_ref.get_ref() as CardUI if source_ref != null else null
	var camera_was_frozen := bool(_monster_drag_session.get("camera_was_frozen", false))
	var generation := int(_monster_drag_session.get("generation", -1))
	_monster_drag_last_cleanup_reason = reason
	_monster_drag_session = {
		"active": false,
		"intent": &"",
		"state": MONSTER_SUMMON_IDLE,
		"generation": generation,
	}
	if source != null and is_instance_valid(source):
		source.set_summon_reservation_visual(false)
	if _monster_summon_drop_target != null and is_instance_valid(_monster_summon_drop_target):
		_monster_summon_drop_target.set_drag_active(false)
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		_monster_summon_interaction_presenter.clear()
	if _tactical_presenter != null and is_instance_valid(_tactical_presenter):
		_tactical_presenter.clear_drag_hover()
		_tactical_presenter.clear_preview()
	if _tactical_terrain_presenter != null and is_instance_valid(_tactical_terrain_presenter):
		_tactical_terrain_presenter.clear_focus()
	_clear_drag_reselect_lane_fields()
	_camera_orbit_frozen = camera_was_frozen


func _monster_drag_debug_snapshot() -> Dictionary:
	var source_ref: WeakRef = _monster_drag_session.get("card_ui_ref", null) as WeakRef
	var drop_active := false
	if _monster_summon_drop_target != null and is_instance_valid(_monster_summon_drop_target):
		drop_active = bool(_monster_summon_drop_target.get_debug_snapshot().get("active", false))
	var preview_nodes := 0
	var tactical_highlights_active := false
	if _tactical_presenter != null and is_instance_valid(_tactical_presenter) and _tactical_presenter.has_method("get_drag_debug_snapshot"):
		preview_nodes = int(_tactical_presenter.get_drag_debug_snapshot().get("node_count", 0))
		tactical_highlights_active = _tactical_presenter.get_node_or_null(NodePath("GridStructureRoot")) != null \
			or _tactical_presenter.get_node_or_null(NodePath("InteractionRoot")) != null
	return {
		"active": _is_monster_summon_interaction_active(),
		"state": _monster_summon_state(),
		"intent": StringName(_monster_drag_session.get("intent", &"")),
		"dragging": _is_monster_drag_active(),
		"card": _monster_drag_session.get("card", null),
		"source_alive": source_ref != null and source_ref.get_ref() != null,
		"legal_cells": _monster_drag_session.get("legal_cells", []).duplicate(),
		"hover_cell": _monster_drag_session.get("hover_cell", MONSTER_DRAG_INVALID_CELL),
		"candidate_cell": _monster_drag_session.get("candidate_cell", MONSTER_DRAG_INVALID_CELL),
		"drop_target_active": drop_active,
		"camera_locked": _is_monster_summon_interaction_active() and _camera_orbit_frozen,
		"camera_orbit_frozen": _camera_orbit_frozen,
		"input_blocked": _is_monster_summon_interaction_active(),
		"preview_nodes": preview_nodes,
		"tactical_highlights_active": tactical_highlights_active,
		"lane_selection_mode": _lane_selection_mode,
		"lane_selection_source": _lane_selection_source,
		"last_commit_count": _monster_drag_commit_count,
		"last_drop_screen_position": _monster_drag_last_drop_screen_position,
		"last_cleanup_reason": _monster_drag_session.get("last_cleanup_reason", _monster_drag_last_cleanup_reason),
		"end_turn_body_entry_count": _monster_summon_end_turn_body_entry_count,
	}


func _monster_source_screen_anchor() -> Vector2:
	var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
	var source := source_ref.get_ref() as CardUI if source_ref != null else null
	if source == null or not is_instance_valid(source):
		return Vector2.INF
	var rect := source.get_global_rect()
	return rect.position + Vector2(rect.size.x * 0.5, 0.0)


func _project_tactical_cell_to_screen(cell: Vector2i) -> Vector2:
	var anchor := _get_3d_surface_anchor_for_cell(cell)
	if anchor == null or not is_instance_valid(anchor):
		return Vector2.INF
	var cam := _get_3d_camera()
	var vpc := get_node_or_null(NodePath("Battle3DViewport")) as SubViewportContainer
	if cam == null or vpc == null or cam.is_position_behind(anchor.global_position):
		return Vector2.INF
	return vpc.get_global_rect().position + cam.unproject_position(anchor.global_position)

## Build per-lane informational overlays for lane selection.
## Returns {lane_index: {boss_present: bool, guard_risk: bool}}
## Boss/Guard info is read-only — never changes lane legality.
func _build_lane_info_for_selection(owner_side: StringName) -> Dictionary:
	var info: Dictionary = {}
	if battle == null:
		return info
	var enemy_occ := battle.get_occupied_lanes(&"enemy")  # boss side
	for lane_idx in range(5):
		var entry: Dictionary = {}
		# Boss present on same lane
		if enemy_occ.has(lane_idx):
			entry["boss_present"] = true
		# Guard risk: adjacent lane (±1) has an enemy guard
		var guard_left: Variant = enemy_occ.get(lane_idx - 1, null)
		var guard_right: Variant = enemy_occ.get(lane_idx + 1, null)
		var has_guard_risk := false
		for g in [guard_left, guard_right]:
			if g != null and g is CardData and (g as CardData).is_guard_card:
				has_guard_risk = true
				break
		if has_guard_risk:
			entry["guard_risk"] = true
		if not entry.is_empty():
			info[lane_idx] = entry
	return info

## Phase 27B: begin unit move / redeploy cell selection.
## Does not mutate battle state — only renders legal cells.
# PHASE55_BEGIN_REDEPLOY
var _core_redeploy_turn := -1
func _confirm_core_redeploy_cell(cell: Vector2i) -> void:
	if _core_surge_committing:return
	var card: CardData=_lane_selection_card
	if battle==null or context==null or _core_redeploy_turn!=context.turn_count or battle_ended or context.player.hp<=0 or context.enemy.hp<=0 or _card_being_played or _spell_end_turn_blocked or _presentation_end_turn_blocked or _exit_modal_active or not battle.get_core_command_state().player_turn_open:
		_cancel_lane_selection(&"redeploy_expired");return
	var status: Dictionary=battle.get_core_command_status(&"redeploy",{"card":card,"cell":cell})
	if not status.get("ok",false):
		if status.get("reason_code") in [battle.CORE_ALREADY_USED,battle.CORE_INSUFFICIENT_CHARGE,battle.CORE_BACKLASH_RESTRICTED,battle.CORE_NOT_PLAYER_TURN]:_cancel_lane_selection(&"redeploy_unavailable")
		return
	var from_cell: Vector2i=battle.get_unit_cell(card)
	_cancel_lane_selection(&"redeploy_commit")
	if not _core_surge_window_open():return
	_core_surge_committing=true
	var result: Dictionary=battle.execute_core_command(&"redeploy",{"card":card,"cell":cell})
	_handle_core_command_result(result)
	if result.get("ok",false):
		_sync_3d_field_tokens();_refresh_tables()
		await _play_monster_presentation(&"move",{"ok":true,"status":&"committed","card":card,"owner_side":&"player","from_cell":from_cell,"to_cell":cell,"path_cells":[from_cell,cell],"action_consumed":false,"source":battle.MOVE_CORE_REDEPLOY,"duration":0.18})
	_core_surge_committing=false;_release_idle_end_turn_busy()
# PHASE55_END_REDEPLOY
func _begin_unit_move_selection(card: CardData, source: StringName) -> void:
	if battle == null:
		return
	var legal: Array[Vector2i] = battle.get_legal_move_cells(card, source)
	if legal.is_empty():
		if action_feed:
			action_feed.push_message("没有可用的移动格", TC.WARNING, "", 1.5)
		return
	# PHASE55_BEGIN_STAMP
	if source==battle.MOVE_CORE_REDEPLOY:_core_redeploy_turn=context.turn_count
	# PHASE55_END_STAMP
	var mode: StringName = LANE_SELECT_MOVE if source == battle.MOVE_SELF else LANE_SELECT_REDEPLOY
	_lane_selection_mode = mode  # Phase 27C-R1-R3: fix missing assignment
	_lane_selection_card = card
	_lane_selection_source = source
	_lane_selection_zone = "field"
	_lane_selection_card_ui_ref = null
	_lane_selection_legal.clear()
	_cell_selection_legal = legal.duplicate()
	var occupied: Dictionary = battle.get_occupied_cells()
	var from_cell: Vector2i = battle.get_unit_cell(card)
	_ensure_tactical_movement_presenter()
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.show_cell_selection(mode, &"player", from_cell, legal, occupied, {})
	print("[MOVE_SELECT_STATE] begin: %s source=%s legal=%d cells" % [card.card_name, source, legal.size()])

## Phase 27B: begin unit attack cell selection.
func _begin_unit_attack_selection(card: CardData) -> void:
	if battle == null:
		return
	var attack_cells: Array[Vector2i] = battle.get_legal_attack_cells(card)
	for target: Dictionary in battle.get_legal_siege_targets(card):
		if target.cell not in attack_cells:
			attack_cells.append(target.cell)
	if attack_cells.is_empty():
		if action_feed:
			action_feed.push_message("没有可用的攻击范围", TC.WARNING, "", 1.5)
		return
	_lane_selection_mode = LANE_SELECT_ATTACK
	_lane_selection_card = card
	_lane_selection_source = battle.MOVE_SELF
	_lane_selection_zone = "field"
	_lane_selection_card_ui_ref = null
	_lane_selection_legal.clear()
	_pending_attack_card = card
	_pending_attack_cells = attack_cells.duplicate()
	var from_cell: Vector2i = battle.get_unit_cell(card)
	var occupied: Dictionary = battle.get_occupied_cells()
	# Build info_by_cell: mark range cells and occupied-enemy cells as targets
	var info_by_cell: Dictionary = {}
	for cell in attack_cells:
		var occ: Variant = battle.get_unit_at_cell(cell)
		if occ != null:
			var os: Variant = battle._state_for_card(occ) if battle.has_method("_state_for_card") else null
			if os != null and not os.is_dead() and os.owner_side != &"player":
				info_by_cell[cell] = {"is_target": true, "target_card": occ}
	_ensure_tactical_movement_presenter()
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.show_cell_selection(LANE_SELECT_ATTACK, &"player", from_cell, attack_cells, occupied, info_by_cell)
	# Phase 27D-R3: attacker highlight + instruction banner
	_set_3d_command_target_highlight(card, true)
	_show_attack_targeting_banner(card)
	if _boss_status_hud and is_instance_valid(_boss_status_hud) and _boss_status_hud.has_method("set_clickable"):
		var core_status: Dictionary = battle.get_core_attack_cell_status(card)
		_boss_status_hud.set_clickable(bool(core_status.get("ok", false)))
		if bool(core_status.get("ok", false)):
			_boss_status_hud.set_meta("core_target_cost", 3)
	print("[CELL SELECT] Begin attack selection: %s range=%d cells" % [card.card_name, attack_cells.size()])

func _cancel_lane_selection(_reason: StringName = &"cancel") -> void:
	# PHASE53_BEGIN_CANCEL
	if _core_surge_committing:return
	_clear_core_surge_selection()
	# PHASE53_END_CANCEL
	# PHASE55_BEGIN_CANCEL
	_core_redeploy_turn=-1
	# PHASE55_END_CANCEL
	_cleanup_monster_drag_summon(_reason)
	# Phase 27I-R0: 棋子选择随取消路径一并清理
	_cancel_piece_context(_reason)
	# Phase 27E-R2: clear skill targeting first
	if _skill_context.get("active", false):
		_clear_skill_selection(_reason)
	if _lane_selection_mode == LANE_SELECT_NONE:
		return
	_lane_selection_mode = LANE_SELECT_NONE
	_lane_selection_card = null
	_lane_selection_card_ui_ref = null
	_lane_selection_source = &""
	_lane_selection_zone = ""
	_lane_selection_legal.clear()
	_cell_selection_legal.clear()
	_pending_attack_card = null
	_pending_attack_cells.clear()
	_clear_attack_selection()
	# Phase 27D-R3: clear attack targeting visuals
	_hide_attack_targeting_banner()
	_clear_attack_hover_line()  # Phase 27D-R4
	if _boss_status_hud and is_instance_valid(_boss_status_hud) and _boss_status_hud.has_method("set_clickable"):
		_boss_status_hud.set_clickable(false)
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.clear_preview()

func _is_lane_selection_active() -> bool:
	return _lane_selection_mode != LANE_SELECT_NONE

# ═══════════════════════════════════════════
# Phase 27I-R0: 棋子选择状态机（只读展示；合法性/费用/OD/Depth 全部由 BattleSystem 权威查询）
# ═══════════════════════════════════════════

func _set_end_turn_busy_for_piece(busy: bool) -> void:
	if _end_turn_control and is_instance_valid(_end_turn_control):
		if busy:
			_end_turn_control.set_busy(true, "棋子选择中")
		else:
			_end_turn_control.set_busy(false, "")


func _set_end_turn_busy_for_structure(busy: bool, status_text: String = "建设：选择黄色落点") -> void:
	if _end_turn_control == null or not is_instance_valid(_end_turn_control):
		return
	if busy:
		_end_turn_control.set_busy(true, status_text)
	elif not _has_non_presentation_end_turn_busy() and not _presentation_end_turn_blocked:
		_end_turn_control.set_busy(false, "")

func _is_piece_selection_active() -> bool:
	return bool(_piece_context.get("active", false))

## 清理棋子上下文、Presenter 标记与 BUSY（Esc/右键/切卡/死亡/回合结束/战斗结束/失败共用）
func _cancel_piece_context(_reason: StringName = &"cancel") -> void:
	# Phase 27I-R1: 任何出口（成功/取消/Esc/右键/切卡/回合结束/死亡）清理待替换旧建筑上下文。
	_pending_piece_replacement_old_card = null
	if not _piece_context.get("active", false):
		return
	if is_instance_valid(_boss_status_hud):
		_boss_status_hud.set_clickable(false)
	# Phase 27J-R4: payment 面板属于棋子选择生命周期，任何出口都必须同步清除。
	_hide_piece_payment_choices()
	_piece_context = {
		"active": false,
		"card": null,
		"card_ui": null,
		"action_id": &"",
		"stage": &"",
		"anchor": null,
		"target": null,
		"enhanced_requested": false,
		"payment_mode": &"none",
	}
	# Phase 27I-R0-R4: 取消时清理友方锚点高亮与操作提示，不遗留任何视觉/提示/节点
	_clear_piece_friendly_anchor_highlights()
	_hide_piece_anchor_hint()
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.clear_preview()
	_set_end_turn_busy_for_piece(false)

## 开始棋子选择：先请求权威锚点
func _begin_piece_selection(card_ui, card: CardData, action_id: StringName) -> void:
	if battle == null or card == null:
		return
	if not battle.has_method("get_card_piece_status"):
		_cancel_piece_context()
		return
	_piece_context = {
		"active": true,
		"card": card,
		"card_ui": card_ui,
		"action_id": action_id,
		"stage": &"anchor",
		"anchor": null,
		"target": null,
		"enhanced_requested": false,
		"payment_mode": &"none",
	}
	_ensure_tactical_movement_presenter()
	_set_end_turn_busy_for_piece(true)
	_requery_piece_status()

## 重新查询权威状态（每次点击/确认前）
func _requery_piece_status() -> Dictionary:
	if not _piece_context.get("active", false) or battle == null:
		return {}
	var card: CardData = _piece_context.get("card", null)
	if card == null:
		return {}
	var query_options := {
		"enhanced_requested": _piece_context.get("enhanced_requested", false),
		"selected_payment_mode": _piece_context.get("payment_mode", &"none"),
	}
	# Phase 27I-R0-R: 重查必须携带已选的 P02 强化参数（朝向 / 次目标）
	if _piece_context.has("followup_facing"):
		query_options["followup_facing"] = _piece_context.get("followup_facing")
	if _piece_context.has("secondary_target"):
		query_options["secondary_target"] = _piece_context.get("secondary_target")
	# Phase 27I-R1: 建筑替换推迟——查询携带待替换旧建筑（豁免容量门 + 锚点格）
	if _pending_piece_replacement_old_card != null:
		query_options["replacement_old_card"] = _pending_piece_replacement_old_card
	var construction: Dictionary = _piece_context.get("construction_preview_fact", {})
	if construction.has("footprint_edge"): query_options["footprint_edge"] = construction.footprint_edge
	var status: Dictionary = battle.call("get_card_piece_status", card, _piece_context.get("action_id", &""), _piece_context.get("anchor", null), _piece_context.get("target", null), query_options)
	if not bool(status.get("ok", false)):
		var reason: String = str(status.get("reason_code", ""))
		if _piece_context.get("stage", &"") == &"anchor" and reason in ["piece_anchor_required", "piece_anchor_invalid"]:
			# 等待锚点：展示可锚点
			var anchor_cells: Array = status.get("anchor_cells", [])
			if anchor_cells.is_empty():
				# Phase 27I-R0-R4: 合法锚点数为 0 → 显示明确原因并安全取消 BUSY，不静默停留
				var no_anchor_zh := _piece_reason_to_chinese(StringName(reason))
				if no_anchor_zh.is_empty():
					no_anchor_zh = "没有可用的锚点"
				_show_floating_text(no_anchor_zh, TC.WARNING, 1.5, 14)
				_cancel_piece_context()
				return status
			if _tactical_presenter and is_instance_valid(_tactical_presenter):
				_tactical_presenter.call("show_piece_selection", "anchor", _piece_context.get("action_id", &""), Vector2i(-1, -1), _typed_v2i_array(anchor_cells), _typed_v2i_array([]), _typed_v2i_array([]), {})
			# Phase 27I-R0-R4: 友方单位/核心高亮 + 持续操作提示（重查/重闪共用）
			_show_piece_friendly_anchor_highlights(anchor_cells)
			_show_piece_anchor_hint()
			return status
		if _piece_context.get("stage", &"") == &"target" and reason in ["piece_followup_facing_required", "piece_followup_facing_invalid"]:
			# 等待朝向：保留上下文，重渲染支付面板（含朝向选择按钮）
			var syn := status.duplicate(true)
			syn["enhanced_requested"] = true
			syn["payment_options"] = [&"command"] if _piece_context.get("payment_mode", &"none") == &"command" else ([&"depth"] if _piece_context.get("payment_mode", &"none") == &"depth" else [])
			_show_piece_payment_choices(syn)
			return status
		# Phase 27I-R0-R: 失败原因映射中文展示
		var zh := _piece_reason_to_chinese(StringName(reason))
		if not zh.is_empty():
			_show_floating_text(zh, TC.WARNING, 1.5, 14)
		_cancel_piece_context()
		return status
	if _piece_context.get("stage", &"") == &"anchor":
		# Phase 27J-R4: 出牌类先进入 payment，范围在支付选择完成前不可见。
		if _piece_context.get("action_id", &"") == &"play":
			_enter_piece_payment_stage(status)
		else:
			_piece_context["stage"] = &"target"
			_show_piece_target_preview(status)
		# Phase 27I-R0-R4: 支付面板出现后关闭锚点说明/高亮
		_hide_piece_anchor_hint()
		_clear_piece_friendly_anchor_highlights()
	return status

func _show_piece_target_preview(status: Dictionary) -> void:
	if _piece_context.get("action_id") == &"attack" and is_instance_valid(_boss_status_hud):
		var core_status: Dictionary = battle.get_card_piece_status(_piece_context.card, &"attack", null, &"boss_core", {
			"enhanced_requested": _piece_context.get("enhanced_requested", false),
			"selected_payment_mode": _piece_context.get("payment_mode", &"none")})
		_boss_status_hud.set_clickable(core_status.get("ok", false))
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		var base_cells: Array = status.get("base_cells", [])
		var enhanced_cells: Array = status.get("enhanced_cells", [])
		var anchor_cells: Array = status.get("anchor_cells", [])
		_tactical_presenter.call("show_piece_selection", "target", _piece_context.get("action_id", &""), Vector2i(-1, -1), _typed_v2i_array(anchor_cells), _typed_v2i_array(base_cells), _typed_v2i_array(enhanced_cells), {})
	# 怪兽移动/攻击保留原支付入口；play 已在独立 payment 阶段完成选择。
	if _piece_context.get("action_id", &"") != &"play":
		_show_piece_payment_choices(status)

## Phase 27I-R0-R: 把任意 Array 转成 Array[Vector2i]，供 Presenter 类型化参数使用
func _typed_v2i_array(arr: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for v in arr:
		if v is Vector2i:
			out.append(v)
	return out

## Phase 27I-R0-R4: 友方锚点高亮——合法友方怪兽 Token 外圈金黄色呼吸光环（只读视觉，无碰撞/无输入）。
## 我方核心与已有棋子（P04 等）由 Presenter 的 anchor 金色标记表达；敌方目标不在 anchor_cells 中，
## 故不会产生任何合法高亮。高亮位于 Token 视觉上方，不埋于 Token 底下。
func _show_piece_friendly_anchor_highlights(anchor_cells: Array) -> void:
	_clear_piece_friendly_anchor_highlights()
	if not _is_piece_selection_active() or battle == null:
		return
	for raw in anchor_cells:
		var cell := raw as Vector2i
		if cell == Vector2i(-1, -1):
			continue
		if not (battle.has_method("get_unit_at_cell") and battle.has_method("_state_for_card")):
			continue
		var unit: CardData = battle.get_unit_at_cell(cell)
		if unit == null:
			continue
		var state = battle._state_for_card(unit)
		if state == null or state.is_dead() or state.owner_side != &"player":
			continue
		var token := _find_token_node_for_unit(unit)
		if token == null:
			continue
		var halo := _create_piece_anchor_halo()
		token.add_child(halo)
		_piece_anchor_highlights[cell] = halo


func _find_token_node_for_unit(unit: CardData) -> Node3D:
	for key in _card_token_nodes:
		var tok: Node3D = _card_token_nodes[key]
		if tok != null and is_instance_valid(tok) and tok.get_meta("card", null) == unit:
			return tok
	return null


func _create_piece_anchor_halo() -> Node3D:
	var root := Node3D.new()
	root.name = "PieceFriendlyAnchorHighlight"
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.46
	cyl.bottom_radius = 0.46
	cyl.height = 0.035
	ring.mesh = cyl
	ring.position = Vector3(0, 0.22, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.72, 0.10, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.72, 0.10, 1.0)
	mat.emission_energy_multiplier = 0.9
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	root.add_child(ring)
	# 呼吸动画（挂在 halo 自己的 Tween 上，随 halo 释放一并清理）
	var tw := root.create_tween()
	tw.set_loops()
	tw.tween_property(ring, "scale", Vector3.ONE * 1.18, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(ring, "scale", Vector3.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return root


func _clear_piece_friendly_anchor_highlights() -> void:
	for key in _piece_anchor_highlights:
		var halo: Node = _piece_anchor_highlights[key]
		if halo != null and is_instance_valid(halo):
			if halo.get_parent() != null:
				halo.get_parent().remove_child(halo)
			halo.queue_free()
	_piece_anchor_highlights.clear()


## Phase 27I-R0-R4: 持续操作提示（非瞬间 toast）。位置使用安全通知区；不覆盖手牌/详情/指令HUD/结束回合。
func _show_piece_anchor_hint() -> void:
	if not _is_piece_selection_active():
		return
	_hide_piece_anchor_hint()
	var card: CardData = _piece_context.get("card", null)
	var prefix: String = card.get_display_name() if card != null else "棋子"
	var label := Label.new()
	label.name = "PieceAnchorHintLabel"
	var payload := StringName(str(card.piece_payload_id)) if card != null else &""
	match payload:
		&"p04_tripwire_watch":
			label.text = "断频伏线：拖到金色空格布设；伏线不会阻挡该格"
		&"p06_bishop_blade":
			label.text = "%s：选择金色标记中的友军赋刃；确认前查看收益\n下一次合法攻城额外破盾2，成功攻击或回合结束消耗" % prefix
		_:
			label.text = "%s：选择友方怪兽、我方核心或已有棋子作为锚点\n金色目标可选" % prefix
	if card != null and card.card_id == "P01":
		label.text = "护送：选金色友军作为施法中心；不是选择攻击目标\n下一次交战减伤2（强化3），下次己方回合开始过期"
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_top = 44
	label.offset_left = -260
	label.offset_right = 260
	label.offset_bottom = 74
	label.z_index = 90
	add_child(label)
	_piece_anchor_hint_label = label


func _hide_piece_anchor_hint() -> void:
	if _piece_anchor_hint_label and is_instance_valid(_piece_anchor_hint_label):
		_piece_anchor_hint_label.queue_free()
	_piece_anchor_hint_label = null


## 确认锚点（出牌类先选锚点）
## Phase 27I-R0-R4: 最终确认前必须重新查询 BattleSystem（卡仍在手牌 / 锚点仍存在 /
## 友方单位仍存活 / 已有棋子锚点仍有效 / 核心锚点仍合法 / 支付仍可用）。
## 非法锚点（如敌方单位/过期锚点）→ 保持锚点选择，不清除上下文，显示准确提示。
func _live_hand_ui(card: CardData) -> CardUI:
	if card == null or player_table == null or not card in context.player.hand:
		return null
	var host: Node = player_table._hand_layout_external
	if not is_instance_valid(host):
		host = player_table
	for node in host.find_children("*", "Control", true, false):
		if node is CardUI and not node.is_queued_for_deletion() and node.card_data == card:
			return node
	return null


func _rebind_pending_hand_selection() -> void:
	# A table refresh recreates CardUI nodes. Selection belongs to CardData;
	# rebind its presentation source before the old nodes are freed.
	if _piece_context.get("active", false):
		_piece_context["card_ui"] = _live_hand_ui(_piece_context.get("card"))
	if _monster_drag_session.get("active", false):
		var source := _live_hand_ui(_monster_drag_session.get("card"))
		if source != null:
			_monster_drag_session["card_ui_ref"] = weakref(source)
			source.set_board_reservation_visual(true, StringName(_monster_drag_session.get("intent", &"")))


func _confirm_piece_anchor(anchor: Variant) -> void:
	if not _piece_context.get("active", false) or battle == null:
		return
	var card: CardData = _piece_context.get("card", null)
	if card == null:
		return
	# 权威预检：合法才提交；不合法保持锚点阶段并重新闪烁合法锚点
	# Phase 27I-R1-R: 建筑替换推迟——锚点预检同样携带待替换旧建筑（豁免容量门 + 锚点格）
	var probe_opts := {}
	if _pending_piece_replacement_old_card != null:
		probe_opts["replacement_old_card"] = _pending_piece_replacement_old_card
	var probe: Dictionary = battle.call("get_card_piece_status", card, _piece_context.get("action_id", &""), anchor, null, probe_opts)
	if not bool(probe.get("ok", false)):
		var reason: String = str(probe.get("reason_code", ""))
		if reason in ["piece_anchor_required", "piece_anchor_invalid"]:
			_requery_piece_status()  # anchor 阶段分支只重渲染，不取消上下文
			_show_floating_text("请选择友方怪兽、我方核心或已有棋子作为锚点", TC.WARNING, 1.5, 14)
		else:
			_cancel_piece_context()
		return
	_piece_context["anchor"] = anchor
	if _piece_context.get("action_id", &"") == &"play" and _is_structure_card_for_drag(card) \
			and not _is_monster_summon_interaction_active() and anchor is Dictionary:
		var construction_cell: Variant = (anchor as Dictionary).get("cell", MONSTER_DRAG_INVALID_CELL)
		var source_ui := _live_hand_ui(card)
		if construction_cell is Vector2i and _adopt_structure_click_session(source_ui, card, construction_cell):
			_piece_context["construction_cell"] = construction_cell
			_piece_context["construction_preview_fact"] = (_monster_drag_session.get("hover_status", {}) as Dictionary).duplicate(true)
	var is_play_action: bool = _piece_context.get("action_id", &"") == &"play"
	_piece_context["stage"] = &"payment" if is_play_action else &"target"
	var status := _requery_piece_status()
	if not bool(status.get("ok", false)):
		_cancel_piece_context()
		return
	if is_play_action:
		_enter_piece_payment_stage(status)
	else:
		_show_piece_target_preview(status)
	_hide_piece_anchor_hint()
	_clear_piece_friendly_anchor_highlights()

## 确认目标/支付并执行（Phase 27I-R0-R：真实入口，接受 target/move_cell/secondary/followup）
func _confirm_piece_action(options: Dictionary = {}) -> Dictionary:
	if not _piece_context.get("active", false) or battle == null:
		return {}
	var card: CardData = _piece_context.get("card", null)
	if card == null:
		return {}
	var card_cast_intent := StringName(_monster_drag_session.get("intent", &""))
	var card_cast_session_active: bool = _is_card_cast_drag_intent(card_cast_intent) \
			and _monster_drag_session.get("card", null) == card
	var card_cast_source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
	var card_cast_source := card_cast_source_ref.get_ref() as CardUI if card_cast_source_ref != null else null
	if options.has("enhanced_requested"):
		_piece_context["enhanced_requested"] = bool(options.get("enhanced_requested", false))
	if options.has("payment_mode"):
		_piece_context["payment_mode"] = StringName(str(options.get("payment_mode", &"none")))
	if options.has("target"):
		_piece_context["target"] = options.get("target")
	if options.has("move_cell"):
		_piece_context["target"] = options.get("move_cell")
	if options.has("secondary_target"):
		_piece_context["secondary_target"] = options.get("secondary_target")
	if options.has("followup_facing"):
		_piece_context["followup_facing"] = options.get("followup_facing")
	var status := _requery_piece_status()
	if not bool(status.get("ok", false)):
		_cancel_piece_context()
		if card_cast_session_active:
			_cleanup_card_cast_interaction(&"piece_action_stale", true)
		return status
	# Structure drag shares the existing piece/payment/target route, but pauses at
	# one final presentation-only boundary before the authoritative execute call.
	if StringName(_monster_drag_session.get("intent", &"")) == &"structure_build" \
			and _monster_summon_state() == MONSTER_SUMMON_PENDING_CONFIRM \
			and not bool(_monster_drag_session.get("confirm_authorized", false)):
		return _show_structure_pending_confirmation(status, options)
	# Phase 27K-R1-D Task 6: capture only already-selected/context/status facts and
	# existing token projections before execute can invalidate them or context cleanup.
	var play_presentation_facts: Dictionary = {}
	if _piece_context.get("action_id", &"") == &"play":
		play_presentation_facts = _capture_piece_play_presentation_facts(card, status)
		if status.has("structure_build_preview"):
			play_presentation_facts["structure_build_preview"] = (status.get("structure_build_preview", {}) as Dictionary).duplicate(true)
	var exec_options := {
		"enhanced_requested": _piece_context.get("enhanced_requested", false),
		"selected_payment_mode": _piece_context.get("payment_mode", &"none"),
	}
	if _piece_context.has("secondary_target"):
		exec_options["secondary_target"] = _piece_context.get("secondary_target")
	if _piece_context.has("followup_facing"):
		exec_options["followup_facing"] = _piece_context.get("followup_facing")
	# Phase 27I-R1: 建筑替换推迟——执行携带待替换旧建筑（棋子事务内提交 replace_building_and_play）
	if _pending_piece_replacement_old_card != null:
		exec_options["replacement_old_card"] = _pending_piece_replacement_old_card
	var build_preview: Dictionary = status.get("structure_build_preview", {})
	if not build_preview.is_empty():
		if build_preview.has("footprint_edge"): exec_options["footprint_edge"] = build_preview.footprint_edge
		exec_options["expected_terrain_revision"] = int(build_preview.get("expected_terrain_revision", -1))
		exec_options["expected_structure_revision"] = int(build_preview.get("expected_structure_revision", -1))
	var result: Dictionary = battle.call("execute_card_piece_action", card, _piece_context.get("action_id", &""), _piece_context.get("anchor", null), _piece_context.get("target", null), exec_options)
	if bool(result.get("ok", false)) and StringName(str(card.card_id)) == &"P06":
		play_presentation_facts["transaction_id"] = StringName("piece:P06:%d:turn:%d" % [
			card.get_instance_id(), int(context.get_turn_number()) if context != null else 0])
	if result.has("structure_build_fact"):
		play_presentation_facts["structure_build_fact"] = (result.get("structure_build_fact", {}) as Dictionary).duplicate(true)
		var structure_fact: Dictionary = result.get("structure_build_fact", {})
		if structure_fact.has("dual_target_replacement"):
			play_presentation_facts["dual_target_replacement"] = (structure_fact.get("dual_target_replacement", {}) as Dictionary).duplicate(true)
	var action_id: StringName = _piece_context.get("action_id", &"")
	_cancel_piece_context(&"action_done")
	if card_cast_session_active:
		if bool(result.get("ok", false)) and card_cast_source != null and is_instance_valid(card_cast_source):
			card_cast_source.accept_board_drop()
		_cleanup_card_cast_interaction(&"card_cast_confirm_success" if bool(result.get("ok", false)) else &"card_cast_execute_failed", true)
	# 成功后保留对应演出：出牌（魔法/反制/建筑）、攻击（原攻击演出与结果处理）、移动
	if bool(result.get("ok", false)):
		if action_id == &"play":
			_run_piece_play_presentation(card, result, play_presentation_facts)
		elif action_id == &"attack":
			_handle_attack_result(result)
		elif action_id == &"move":
			if action_feed:
				action_feed.push_message("%s 移动到目标格" % card.card_name, Color(0.3, 0.85, 0.85), "", 1.5)
			_play_command_economy_spend(int(result.get("cost", 0)))
			_refresh_tables()
	return result

func _capture_piece_play_presentation_facts(card: CardData, status: Dictionary) -> Dictionary:
	var target_positions: Array[Vector2] = []
	var source_position := Vector2.INF
	var is_rook_relay: bool = card != null and str(card.piece_payload_id) == "p08_rook_relay"
	var card_ui: Control = _live_hand_ui(card)
	if card_ui != null and is_instance_valid(card_ui):
		source_position = card_ui.global_position + card_ui.size * 0.5
	var anchor: Variant = _piece_context.get("anchor", null)
	if anchor is CardData and not is_rook_relay:
		var anchor_token := _get_3d_token_for_card(anchor as CardData)
		var projected := _project_3d_token_to_screen(anchor_token)
		if projected.is_finite():
			target_positions.append(projected)
	var selected_target: Variant = _piece_context.get("target", null)
	if is_rook_relay:
		var committed_targets: Array[CardData] = []
		var seen_runtime_ids := {}
		if bool(status.get("enhanced_requested", false)):
			for candidate in status.get("legal_targets", []):
				if candidate is CardData:
					var candidate_card := candidate as CardData
					var runtime_id := candidate_card.get_instance_id()
					if not seen_runtime_ids.has(runtime_id):
						seen_runtime_ids[runtime_id] = true
						committed_targets.append(candidate_card)
		elif selected_target is CardData:
			committed_targets.append(selected_target as CardData)
		for target_card in committed_targets:
			var target_token := _get_3d_token_for_card(target_card)
			var projected_target := _project_3d_token_to_screen(target_token)
			if projected_target.is_finite():
				target_positions.append(projected_target)
	elif selected_target is CardData:
		if not anchor is CardData or selected_target != anchor:
			var target_token := _get_3d_token_for_card(selected_target as CardData)
			var projected_target := _project_3d_token_to_screen(target_token)
			if projected_target.is_finite() and not target_positions.has(projected_target):
				target_positions.append(projected_target)
	var facts := {
		"card_id": StringName(str(card.card_id)) if card != null else &"",
		"piece_type": StringName(status.get("piece_type", card.piece_type if card != null else &"")),
		"enhanced": bool(status.get("enhanced_requested", false)),
		"payment_mode": StringName(status.get("selected_payment_mode", &"none")),
		"fallback_original_only": bool(status.get("fallback_original_only", false)),
		"replacement": _pending_piece_replacement_old_card != null,
		"target_positions": target_positions,
		"range_cells": (status.get("ray_preview_cells", status.get("base_cells", [])) as Array).duplicate(),
		"selected_target": selected_target,
	}
	if is_rook_relay and anchor is Dictionary:
		facts["anchor_cell"] = (anchor as Dictionary).get("cell", Vector2i(-1, -1))
	if source_position.is_finite():
		facts["source_position"] = source_position
	if not target_positions.is_empty():
		facts["target_position"] = target_positions[0]
		if not source_position.is_finite():
			facts["source_position"] = target_positions[0]
	return facts


## Phase 27I-R0-R: 出牌类棋子成功后演出（execute 已在 BattleSystem 内完成 play_card）
func _run_piece_play_presentation(card: CardData, result: Dictionary, captured_facts: Dictionary = {}) -> void:
	if card == null or battle == null or context == null:
		return
	if action_feed:
		action_feed.push_message("Play: %s" % card.card_name, TC.role_color(card.archetype_role))
	# Boss Reaction
	if boss_deck and boss_deck.has_method("check_player_card_reaction"):
		boss_deck.check_player_card_reaction(context.cards_played_this_turn)
	# 伤害数字 / 声音 / 闪烁
	if enemy_table:
		var am = _am()
		if am: am.play_sfx("card_play")
		if enemy_table.has_method("flash_hit"):
			enemy_table.flash_hit()
		_flash_boss_core()
		if fx and fx.has_method("shake"):
			fx.shake(5.0)
	_refresh_tables()
	if StringName(str(card.card_id)) == &"P06":
		var p06_facts := result.duplicate(true)
		p06_facts.merge(captured_facts, true)
		p06_facts["card_id"] = &"P06"
		p06_facts["status"] = &"committed"
		p06_facts["ok"] = true
		p06_facts["card"] = card
		p06_facts["piece_type"] = &"bishop"
		p06_facts["enhanced"] = bool(captured_facts.get("enhanced", false))
		p06_facts["payment_mode"] = StringName(captured_facts.get("payment_mode", &"none"))
		var original_only := bool(captured_facts.get("fallback_original_only", false))
		p06_facts["fallback_original_only"] = original_only
		p06_facts["direction_fallback_only"] = original_only
		p06_facts["label"] = card.get_display_name() if original_only else ("王火淬刃" if bool(p06_facts.get("enhanced", false)) else "斜锋已授")
		_play_generic_presentation(&"piece_spell", p06_facts)
	elif StringName(str(card.card_id)) == &"P08":
		var p08_facts := result.duplicate(true)
		p08_facts.merge(captured_facts, true)
		p08_facts["card_id"] = &"P08"
		p08_facts["status"] = &"committed"
		p08_facts["ok"] = true
		p08_facts["card"] = card
		p08_facts["piece_type"] = &"rook"
		p08_facts["enhanced"] = bool(captured_facts.get("enhanced", false))
		p08_facts["payment_mode"] = StringName(captured_facts.get("payment_mode", &"none"))
		p08_facts["replacement"] = bool(captured_facts.get("replacement", false))
		var original_only := bool(captured_facts.get("fallback_original_only", false))
		p08_facts["fallback_original_only"] = original_only
		var piece_token := _get_3d_token_for_card(card)
		var piece_position := _project_3d_token_to_screen(piece_token) if piece_token != null else Vector2.INF
		if piece_position.is_finite():
			p08_facts["source_position"] = piece_position
			p08_facts["anchor_position"] = piece_position
		var committed_positions: Variant = p08_facts.get("target_positions", [])
		if committed_positions is Array and not (committed_positions as Array).is_empty():
			p08_facts["target_position"] = (committed_positions as Array)[0]
		var specialized := not original_only and piece_position.is_finite() \
			and committed_positions is Array and not (committed_positions as Array).is_empty()
		if specialized:
			p08_facts["label"] = "烽堡传令"
			_play_generic_presentation(&"piece_building", p08_facts)
		else:
			p08_facts["direction_fallback_only"] = true
			p08_facts["label"] = card.get_display_name()
			if piece_position.is_finite():
				p08_facts["target_position"] = piece_position
			_play_generic_presentation(&"building", p08_facts)
	elif card.card_family in ["building", "counter"]:
		var piece_token := _get_3d_token_for_card(card)
		var piece_position := _project_3d_token_to_screen(piece_token) if piece_token != null else Vector2.ZERO
		var piece_facts := result.duplicate(true)
		piece_facts.merge({
			"status": &"committed",
			"card": card,
			"label": card.get_display_name(),
			"target_position": piece_position,
			"source_position": piece_position,
			"triggered": false,
		}, true)
		_play_generic_presentation(StringName(card.card_family), piece_facts)
	_audit_state_consistency("piece_play")
	check_battle_end()

## Phase 27I-R0-R: 把点击的棋盘格解析为当前棋子卡片的锚点对象（非合法性计算，只解析点击目标）
func _piece_anchor_for_cell(cell: Vector2i) -> Variant:
	if battle == null:
		return null
	var card: CardData = _piece_context.get("card", null)
	if card == null:
		return null
	# 反制/建筑：直接棋盘格锚点
	if card.card_family in ["counter", "building"]:
		return {"type": &"cell", "cell": cell}
	# 魔法：友方单位 / 玩家核心 / 建筑棋子锚点
	if battle.has_method("get_unit_at_cell"):
		var unit: CardData = battle.get_unit_at_cell(cell)
		if unit != null:
			return unit
	if battle.has_method("get_virtual_core_anchor_cell"):
		var core_cell: Vector2i = battle.get_virtual_core_anchor_cell(&"player")
		if cell == core_cell:
			return {"type": &"core"}
	var anchors: Dictionary = battle.get("_piece_anchor_by_runtime_id") if battle.get("_piece_anchor_by_runtime_id") is Dictionary else {}
	for rid in anchors:
		var entry: Dictionary = anchors[rid]
		if entry.get("anchor_cell", Vector2i(-1, -1)) == cell:
			return entry.get("card", null)
	return null


func _piece_anchor_from_drag_hit(hit: Dictionary, intent: StringName) -> Variant:
	if not bool(hit.get("ok", false)) \
			or StringName(str(hit.get("target_kind", &""))) != &"tactical_cell":
		return null
	var raw_cell: Variant = hit.get("board_cell", MONSTER_DRAG_INVALID_CELL)
	if not raw_cell is Vector2i or raw_cell == MONSTER_DRAG_INVALID_CELL:
		return null
	var anchor: Variant = _piece_anchor_for_cell(raw_cell as Vector2i)
	if intent == CARD_DRAG_DIRECTED_SPELL:
		return anchor if anchor is CardData else null
	return anchor if intent == CARD_DRAG_FRIENDLY_ANCHOR else null


func _piece_drag_anchor_display_name(anchor: Variant) -> String:
	if anchor is CardData:
		var card := anchor as CardData
		return card.get_display_name() if card.has_method("get_display_name") else card.card_name
	if anchor is Dictionary and StringName(str((anchor as Dictionary).get("type", &""))) == &"core":
		return "我方核心"
	return "友方锚点"


## Phase 27I-R1-R: P08 目标是否仍属于最新权威 legal_targets（BattleSystem 查询，无副作用）。
func _is_piece_target_legal(token: CardData) -> bool:
	if not _is_piece_selection_active() or battle == null or token == null:
		return false
	var card: CardData = _piece_context.get("card", null)
	if card == null:
		return false
	var qopts := {
		"enhanced_requested": _piece_context.get("enhanced_requested", false),
		"selected_payment_mode": _piece_context.get("payment_mode", &"none"),
	}
	if _pending_piece_replacement_old_card != null:
		qopts["replacement_old_card"] = _pending_piece_replacement_old_card
	var status: Dictionary = battle.call(
		"get_card_piece_status",
		card,
		_piece_context.get("action_id", &""),
		_piece_context.get("anchor", null),
		token,
		qopts
	)
	var targets: Array = status.get("legal_targets", [])
	return targets.has(token)

## Phase 27I-R1-R: P08 非法/过期目标拒绝反馈（不执行、不清上下文）。
func _show_piece_target_reject(_token: CardData) -> void:
	if _tactical_presenter and is_instance_valid(_tactical_presenter) and _tactical_presenter.has_method("play_cell_reject"):
		var cell := battle.get_unit_cell(_token) if (battle and battle.has_method("get_unit_cell") and _token != null) else Vector2i(-1, -1)
		_tactical_presenter.call("play_cell_reject", cell)
	_show_floating_text("目标不在战车连接范围内或已过期", TC.WARNING, 1.5, 14)

## Phase 27I-R1-R: P08 基础支付选择——只设置基础模式并进入“选择 1 个战车连接目标”，不立即执行。
func _begin_p08_base_target_selection(status: Dictionary) -> void:
	_piece_context["enhanced_requested"] = false
	_piece_context["payment_mode"] = &"none"
	_piece_context["stage"] = &"target"
	_hide_piece_payment_choices()
	# 高亮权威 legal_targets（Presenter 只消费 BattleSystem 返回值）
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		var anchor_cells: Array = status.get("anchor_cells", [])
		var base_cells: Array = status.get("base_cells", [])
		var enhanced_cells: Array = status.get("enhanced_cells", [])
		_tactical_presenter.call("show_piece_selection", "target", _piece_context.get("action_id", &""), Vector2i(-1, -1), _typed_v2i_array(anchor_cells), _typed_v2i_array(base_cells), _typed_v2i_array(enhanced_cells), {})
	_show_floating_text("请选择 1 个战车连接目标", Color(1.0, 0.8, 0.3, 1), 1.5, 14)


## Phase 27J-R4: 锚点确认后进入独立 payment 阶段；此时不显示任何作用范围。
func _enter_piece_payment_stage(status: Dictionary) -> void:
	if not _piece_context.get("active", false):
		return
	_piece_context["stage"] = &"payment"
	_piece_context["target"] = null
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.clear_preview()
	_show_piece_payment_choices(_build_piece_play_payment_status(status))
	var card: CardData = _piece_context.get("card", null)
	if card != null and _is_structure_card_for_drag(card):
		_set_end_turn_busy_for_structure(true, "建设：选择施放方式")


## 使用 BattleSystem 对每种支付方式做只读预检。UI 只消费预检结果，不自行判断费用或区域。
func _build_piece_play_payment_status(base_status: Dictionary) -> Dictionary:
	var result := base_status.duplicate(true)
	var card: CardData = _piece_context.get("card", null)
	var supported_modes: Array = []
	var command_cost: int = 1
	var depth_cost: int = 1
	if battle and battle.has_method("get_card_piece_traits"):
		var traits = battle.get_card_piece_traits()
		if traits != null:
			if traits.has_method("get_profile_for_card") and card != null:
				var profile: Dictionary = traits.get_profile_for_card(card)
				for raw_mode in profile.get("enhance_modes", []):
					var supported_mode := StringName(str(raw_mode))
					if not supported_modes.has(supported_mode):
						supported_modes.append(supported_mode)
			if traits.has_method("get_enhance_command_cost"):
				command_cost = int(traits.get_enhance_command_cost())
			if traits.has_method("get_enhance_depth_cost"):
				depth_cost = int(traits.get_enhance_depth_cost())
	var legal_modes: Array = []
	for mode_value in supported_modes:
		var mode := StringName(str(mode_value))
		var query_options := {
			"enhanced_requested": true,
			"selected_payment_mode": mode,
		}
		if _pending_piece_replacement_old_card != null:
			query_options["replacement_old_card"] = _pending_piece_replacement_old_card
		var probe: Dictionary = battle.call(
			"get_card_piece_status",
			card,
			_piece_context.get("action_id", &""),
			_piece_context.get("anchor", null),
			null,
			query_options
		)
		if bool(probe.get("ok", false)) \
			and bool(probe.get("enhanced_requested", false)) \
			and StringName(str(probe.get("selected_payment_mode", &"none"))) == mode:
			legal_modes.append(mode)
			command_cost = int(probe.get("piece_command_cost", command_cost))
			depth_cost = int(probe.get("piece_depth_cost", depth_cost))
	result["supported_payment_modes"] = supported_modes
	result["payment_options"] = legal_modes
	result["piece_command_cost"] = command_cost
	result["piece_depth_cost"] = depth_cost
	result["enhanced_requested"] = false
	return result


## Phase 27J-R4: play 类先选支付。需要主目标才进入 target；自动范围牌直接结算。
func _choose_piece_play_payment(enhanced: bool, mode: StringName) -> void:
	if not _piece_context.get("active", false) or _piece_context.get("stage", &"") != &"payment":
		return
	_piece_context["enhanced_requested"] = enhanced
	_piece_context["payment_mode"] = mode
	_hide_piece_payment_choices()
	var status := _requery_piece_status()
	if not bool(status.get("ok", false)):
		return
	var card: CardData = _piece_context.get("card", null)
	var is_rook_relay: bool = card != null and str(card.piece_payload_id) == "p08_rook_relay"
	var needs_target: bool = str(status.get("target_mode", "none")) != "none" \
		and not bool(status.get("fallback_original_only", false)) \
		and not (is_rook_relay and enhanced)
	if needs_target:
		_piece_context["stage"] = &"target"
		_show_piece_target_preview(status)
		if is_rook_relay:
			_show_floating_text("请选择 1 个战车连接目标", Color(1.0, 0.8, 0.3, 1), 1.5, 14)
		return
	_confirm_piece_action({"enhanced_requested": enhanced, "payment_mode": mode})

## Phase 27I-R0-R: 支付选择 UI——只显示 BattleSystem 返回的 payment_options/费用，不自行计算
func _show_piece_payment_choices(status: Dictionary) -> void:
	if not _piece_context.get("active", false):
		return
	_hide_piece_payment_choices()
	var holder := _get_piece_confirm_layer()
	if holder == null:
		return
	var panel := Panel.new()
	panel.name = "PiecePaymentChoices"
	panel.set_meta("piece_payment_panel", true)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var action_id: StringName = _piece_context.get("action_id", &"")
	var is_play_action: bool = action_id == &"play"
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_bottom = -230
	panel.offset_top = -300 if is_play_action else -370
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 120
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.04, 0.075, 0.97)
	panel_style.border_color = Color(0.22, 0.78, 0.88, 0.9)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", panel_style)
	var button_box: BoxContainer = HBoxContainer.new() if is_play_action else VBoxContainer.new()
	button_box.name = "PaymentButtonBox"
	button_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	button_box.offset_left = 12
	button_box.offset_right = -12
	button_box.offset_top = 9
	button_box.offset_bottom = -9
	button_box.add_theme_constant_override("separation", 8)
	button_box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(button_box)
	var title := Label.new()
	title.text = "第 2 步：选择施放方式" if is_play_action else "选择行动方式"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0, 1.0))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button_box.add_child(title)
	var enhanced: bool = bool(status.get("enhanced_requested", false))
	var pay_options: Array = status.get("payment_options", [])
	var supported_options: Array = status.get("supported_payment_modes", pay_options)
	var base_cost: int = int(status.get("base_command_cost", 0))
	var piece_cost: int = int(status.get("piece_command_cost", 0))
	var depth_cost: int = int(status.get("piece_depth_cost", 0))
	# 出牌类（P01/P04/P05）点击支付按钮即执行；怪兽类（P02/P03）先设置支付模式，再点格执行
	var is_unit_action: bool = action_id == &"move" or action_id == &"attack"
	# 基础效果按钮
	var base_btn := Button.new()
	base_btn.text = "使用基础效果"
	base_btn.add_theme_font_size_override("font_size", 13)
	base_btn.pressed.connect(func() -> void:
		if is_play_action:
			_choose_piece_play_payment(false, &"none")
		elif is_unit_action:
			_set_piece_payment_choice(false, &"none")
		else:
			# Phase 27I-R1-R: P08 基础——只设置基础模式并进入选目标阶段，不得提前打出卡牌；
			# 无候选（fallback_original_only）时直接结算原效果，不进入空目标死循环。
			var p08_pcard: CardData = _piece_context.get("card", null)
			if p08_pcard != null and str(p08_pcard.piece_payload_id) == "p08_rook_relay":
				if bool(status.get("fallback_original_only", false)):
					_hide_piece_payment_choices()
					_confirm_piece_action({"enhanced_requested": false, "payment_mode": &"none"})
				else:
					_begin_p08_base_target_selection(status)
			else:
				_hide_piece_payment_choices()
				_confirm_piece_action({"enhanced_requested": false, "payment_mode": &"none"}))
	button_box.add_child(base_btn)
	# 强化指令按钮（仅当 BattleSystem 返回 command 选项）
	if (is_play_action and supported_options.has(&"command")) or (not is_play_action and enhanced and pay_options.has(&"command")):
		var cmd_btn := Button.new()
		cmd_btn.text = "强化：指令 -%d（合计 %d）" % [piece_cost, base_cost + piece_cost]
		cmd_btn.add_theme_font_size_override("font_size", 13)
		cmd_btn.disabled = is_play_action and not pay_options.has(&"command")
		if cmd_btn.disabled:
			cmd_btn.tooltip_text = "当前战术指令不足"
		cmd_btn.pressed.connect(func() -> void:
			if is_play_action:
				_choose_piece_play_payment(true, &"command")
			elif is_unit_action:
				_set_piece_payment_choice(true, &"command")
			else:
				_hide_piece_payment_choices()
				_confirm_piece_action({"enhanced_requested": true, "payment_mode": &"command"}))
		button_box.add_child(cmd_btn)
	# 强化 Depth 按钮（仅当 BattleSystem 返回 depth 选项；Depth 满时 BattleSystem 不会返回）
	if (is_play_action and supported_options.has(&"depth")) or (not is_play_action and enhanced and pay_options.has(&"depth")):
		var depth_btn := Button.new()
		depth_btn.text = "强化：Depth +%d" % depth_cost
		depth_btn.add_theme_font_size_override("font_size", 13)
		depth_btn.disabled = is_play_action and not pay_options.has(&"depth")
		if depth_btn.disabled:
			depth_btn.tooltip_text = "仅在 Overdrive 且 Depth 未满时可用"
		depth_btn.pressed.connect(func() -> void:
			if is_play_action:
				_choose_piece_play_payment(true, &"depth")
			elif is_unit_action:
				_set_piece_payment_choice(true, &"depth")
			else:
				_hide_piece_payment_choices()
				_confirm_piece_action({"enhanced_requested": true, "payment_mode": &"depth"}))
		button_box.add_child(depth_btn)
	# P02 强化移动：显示朝向选择按钮（选择强化后必须显式提供 followup_facing）
	var piece_card: CardData = _piece_context.get("card", null)
	if enhanced and action_id == &"move" and piece_card != null and str(piece_card.piece_payload_id) == "p02_knight_action":
		var facing_label := Label.new()
		facing_label.text = "选择强化移动朝向："
		facing_label.add_theme_font_size_override("font_size", 12)
		button_box.add_child(facing_label)
		for facing_val in [-1, 1]:
			var facing_btn := Button.new()
			facing_btn.text = "朝向 %s" % ("左" if facing_val == -1 else "右")
			facing_btn.add_theme_font_size_override("font_size", 12)
			facing_btn.pressed.connect(_on_piece_facing_pressed.bind(facing_val))
			button_box.add_child(facing_btn)
	holder.add_child(panel)

## Phase 27I-R0-R: 强化移动朝向选择回调
func _on_piece_facing_pressed(facing_val: int) -> void:
	if not _piece_context.get("active", false):
		return
	_piece_context["followup_facing"] = facing_val
	var st: Dictionary = _requery_piece_status()
	if st.get("ok", false):
		_show_piece_target_preview(st)

## Phase 27I-R0-R: 设置支付选择并重渲染（怪兽类先选支付，再点格执行）
func _set_piece_payment_choice(enhanced: bool, mode: StringName) -> void:
	if not _piece_context.get("active", false):
		return
	_piece_context["enhanced_requested"] = enhanced
	_piece_context["payment_mode"] = mode
	var st: Dictionary = _requery_piece_status()
	if st.get("ok", false):
		_show_piece_target_preview(st)
		_hide_piece_payment_choices()

func _hide_piece_payment_choices() -> void:
	var layer := _get_piece_confirm_layer()
	if layer == null:
		return
	# Phase 27I-R1-R2: remove_child 立即脱离树（释放"PiecePaymentChoices"名字供新面板复用），
	# queue_free 延迟释放——避免在 Button.pressed 信号发射期间 free() 自身面板导致原生崩溃。
	for child in layer.get_children():
		if child.has_meta("piece_payment_panel"):
			layer.remove_child(child)
			child.queue_free()

func _get_piece_confirm_layer() -> Node:
	# 复用 monster command layer 所在 CanvasLayer
	return _get_monster_command_layer() if has_method("_get_monster_command_layer") else null

## Phase 27I-R0-R: 棋子 reason code → 中文（BattleScene 只做展示映射）
func _piece_reason_to_chinese(rc: StringName) -> String:
	match rc:
		&"piece_followup_facing_required": return "强化移动必须先选择朝向"
		&"piece_followup_facing_invalid": return "朝向非法"
		&"piece_secondary_target_required": return "强化攻击必须选择一个相邻次目标"
		&"piece_secondary_target_invalid": return "次目标非法或已过期"
		&"piece_anchor_required": return "请选择锚点"
		&"piece_anchor_invalid": return "锚点无效"
		&"piece_depth_zone_required": return "Depth 支付仅在 Overdrive 可用"
		&"piece_depth_at_cap": return "Depth 已满，不能使用 Depth 支付"
		&"piece_command_insufficient": return "战术指令不足"
		&"piece_enhance_not_applicable": return "该行动不支持强化"
		&"piece_target_invalid": return "目标无效"
	return ""

# Phase 27D-R3: Attack targeting visual helpers

func _show_attack_targeting_banner(card: CardData) -> void:
	_hide_attack_targeting_banner()
	if battle == null:
		return
	var cost: int = 2
	if battle.has_method("get_unit_command_status"):
		var cs: Dictionary = battle.get_unit_command_status(card, "attack")
		cost = int(cs.get("cost", 2))
	var current_points: int = 0
	if battle.has_method("get_command_economy_snapshot"):
		var snap: Dictionary = battle.get_command_economy_snapshot("player")
		current_points = int(snap.get("current_points", 0))
	var after: int = current_points - cost

	_attack_targeting_banner = Label.new()
	_attack_targeting_banner.name = "AttackTargetingBanner"
	_attack_targeting_banner.text = "选择攻击目标  消耗 %d 指令  当前 %d → %d" % [cost, current_points, after]
	_attack_targeting_banner.add_theme_font_size_override("font_size", 11)
	_attack_targeting_banner.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2, 1))
	_attack_targeting_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attack_targeting_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attack_targeting_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_attack_targeting_banner.offset_top = 4
	_attack_targeting_banner.offset_left = -200
	_attack_targeting_banner.offset_right = 200
	_attack_targeting_banner.offset_bottom = 22
	add_child(_attack_targeting_banner)
	# Also preview cost in HUD
	if _command_economy_hud and is_instance_valid(_command_economy_hud):
		_command_economy_hud.preview_cost(cost)

func _hide_attack_targeting_banner() -> void:
	if _attack_targeting_banner and is_instance_valid(_attack_targeting_banner):
		_attack_targeting_banner.queue_free()
	_attack_targeting_banner = null
	if _command_economy_hud and is_instance_valid(_command_economy_hud):
		_command_economy_hud.clear_preview()

# ── Phase 27D-R4: Attack hover line ──

func _ensure_attack_hover_line() -> void:
	if _attack_hover_line and is_instance_valid(_attack_hover_line):
		return
	_attack_hover_line = Control.new()
	_attack_hover_line.name = "AttackHoverLine"
	_attack_hover_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attack_hover_line.z_index = 110  # Above cell markers, below menus
	# We connect a callable that calls queue_redraw
	# draw callback is wired via _draw signal
	add_child(_attack_hover_line)

func _draw_attack_hover_line() -> void:
	if _attack_hover_line == null or not is_instance_valid(_attack_hover_line):
		return
	_attack_hover_line.queue_redraw()

func _on_hover_line_draw() -> void:
	if _attack_hover_line == null or not is_instance_valid(_attack_hover_line):
		return
	if _hover_line_color == Color.TRANSPARENT or _hover_line_from == Vector2.ZERO or _hover_line_to == Vector2.ZERO:
		return
	# Clamp to viewport safe rect
	var vp_rect: Rect2 = get_viewport_rect()
	var margin: float = 8.0
	var clamped_from := Vector2(
		clampf(_hover_line_from.x, margin, vp_rect.size.x - margin),
		clampf(_hover_line_from.y, margin, vp_rect.size.y - margin)
	)
	var clamped_to := Vector2(
		clampf(_hover_line_to.x, margin, vp_rect.size.x - margin),
		clampf(_hover_line_to.y, margin, vp_rect.size.y - margin)
	)
	var local_from := _attack_hover_line.get_global_transform().affine_inverse() * clamped_from
	var local_to := _attack_hover_line.get_global_transform().affine_inverse() * clamped_to
	_attack_hover_line.draw_line(local_from, local_to, _hover_line_color, 3.0, true)

func _update_attack_hover_line() -> void:
	# Only run during attack targeting mode
	if _lane_selection_mode != LANE_SELECT_ATTACK:
		if _hover_line_color != Color.TRANSPARENT:
			_clear_attack_hover_line()
		return
	if _lane_selection_card == null or battle == null:
		_clear_attack_hover_line()
		return

	# Throttle raycast: every 4 frames
	_hover_line_frame += 1
	if _hover_line_frame % 4 != 0:
		return

	# Get attacker token screen position
	var attacker_token := _get_3d_token_for_card(_lane_selection_card)
	if attacker_token == null:
		_clear_attack_hover_line()
		return
	var from_pos := _project_3d_token_to_screen(attacker_token)
	if from_pos == Vector2.INF or from_pos.x < 0 or from_pos.y < 0:
		_clear_attack_hover_line()
		return

	# Get mouse position and raycast
	var mouse_pos := get_viewport().get_mouse_position()
	var vpc := get_node_or_null(NodePath("Battle3DViewport")) as SubViewportContainer
	if not vpc:
		_clear_attack_hover_line(); return
	# Adjust mouse pos relative to viewport container
	var vpc_rect := vpc.get_global_rect()
	if not vpc_rect.has_point(mouse_pos):
		_clear_attack_hover_line(); return

	# Check boss core hover first (boss core is a specific Area3D)
	var hit := _raycast_3d_click(mouse_pos)
	if not bool(hit.get("ok", false)):
		_clear_attack_hover_line(); return

	var target_kind := str(hit.get("target_kind", ""))
	var to_pos := Vector2.INF

	if target_kind == "boss_core":
		# Verify core attack legality
		if _selected_attacker and battle.can_monster_attack_boss(_selected_attacker).get("ok", false):
			to_pos = _get_boss_screen_pos()
			_hover_line_color = Color(1.0, 0.2, 0.05, 0.9)  # red-gold for boss core
		else:
			_clear_attack_hover_line(); return
	elif target_kind == "tactical_cell":
		var cell: Vector2i = hit.get("board_cell", Vector2i(-1, -1))
		if cell == Vector2i(-1, -1):
			_clear_attack_hover_line(); return
		# Check if this cell is in legal attack cells
		var is_legal := false
		for legal_cell in _pending_attack_cells:
			if legal_cell is Vector2i and legal_cell == cell:
				is_legal = true
				break
		if not is_legal:
			_clear_attack_hover_line(); return
		# Project cell world position to screen
		var cell_world_pos: Vector3 = hit.get("position", Vector3.ZERO)
		if typeof(cell_world_pos) != TYPE_VECTOR3:
			_clear_attack_hover_line(); return
		to_pos = _project_world_position_to_screen(cell_world_pos)
		_hover_line_color = Color(1.0, 0.55, 0.15, 0.85)  # orange-red for unit target
	else:
		_clear_attack_hover_line(); return

	if to_pos == Vector2.INF or to_pos.x < 0:
		_clear_attack_hover_line(); return

	# Update the line
	_ensure_attack_hover_line()
	if _attack_hover_line and is_instance_valid(_attack_hover_line):
		if not _attack_hover_line.is_connected("draw", _on_hover_line_draw):
			_attack_hover_line.draw.connect(_on_hover_line_draw)
	_hover_line_from = from_pos
	_hover_line_to = to_pos
	_draw_attack_hover_line()

func _clear_attack_hover_line() -> void:
	if _hover_line_color == Color.TRANSPARENT:
		return
	_hover_line_from = Vector2.ZERO
	_hover_line_to = Vector2.ZERO
	_hover_line_color = Color.TRANSPARENT
	if _attack_hover_line and is_instance_valid(_attack_hover_line):
		_attack_hover_line.queue_redraw()

# [Fixed func]
func _same_card_ref_or_id(a: CardData, b: CardData) -> bool:
	if a == null or b == null:
		return false
	if a == b:
		return true
	if is_instance_valid(a) and is_instance_valid(b):
		return a.get_instance_id() == b.get_instance_id()
	# Field units are runtime entities. Template IDs are intentionally not a
	# fallback because two copies of the same card may coexist on the board.
	return false
func _field_contains_card(field: Array, card: CardData) -> bool:
	if card == null:
		return false
	for c in field:
		if c == null:
			continue
		if _same_card_ref_or_id(c, card):
			return true
	return false

# Phase 19C-2: Global input fallback for field card clicks.
# When a transparent UI layer blocks CardUI._gui_input, this handler
# uses hit-test to find the clicked field card and route it.

# Phase 21F: Process camera orbit input (right-drag rotate + scroll zoom)
# Returns true if the event was consumed by camera orbit
# Phase 23A-V3: Process camera orbit input (right-drag rotate + scroll zoom + preset shortcuts)
# Returns true if the event was consumed by camera orbit
func _process_camera_orbit_input(event: InputEvent) -> bool:
	if not USE_CAMERA_ORBIT:
		return false
	if battle_ended or _camera_orbit_frozen or _exit_modal_active:
		return false

	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var kk := event as InputEventKey
		# Phase 23B-R2: Esc cancels building replacement selection
		if _building_replace_select_active and kk.keycode == KEY_ESCAPE:
			_cancel_building_replace_selection("escape")
			return true
		# Phase 26E-R1 Task 5: Esc cancels lane selection
		# Phase 27I-R0-R3: 纯棋子选择（无 lane selection）时 Esc 也取消，避免 EndTurn 永久 BUSY
		if kk.keycode == KEY_ESCAPE and (_is_lane_selection_active() or _is_piece_selection_active() or bool(_od_release_context.get("active", false))):
			if _is_lane_selection_active():
				_cancel_lane_selection(&"escape")
			elif bool(_od_release_context.get("active", false)):
				_clear_od_release_selection(&"escape")
			else:
				_cancel_piece_context(&"escape")
			return true
		if _camera_free_view_enabled and kk.keycode == KEY_ESCAPE:
			_set_camera_free_view_enabled(false)
			return true
		if kk.keycode == KEY_1:
			_on_base_view_requested()
			return true
		if kk.keycode == KEY_2:
			_on_top_view_requested()
			return true

	if not _camera_free_view_enabled and _building_replace_select_active:
		if event is InputEventMouseButton:
			var locked_mb := event as InputEventMouseButton
			if locked_mb.button_index == MOUSE_BUTTON_RIGHT:
				if locked_mb.pressed:
					_building_replace_right_press_pos = locked_mb.position
					_building_replace_right_dragged = false
					return true
				if not _building_replace_right_dragged:
					_cancel_building_replace_selection("right_click")
				return true
		if event is InputEventMouseMotion and not _building_replace_right_dragged:
			var locked_motion := event as InputEventMouseMotion
			var locked_dist := locked_motion.position.distance_to(_building_replace_right_press_pos)
			if locked_dist >= BUILD_REPLACE_RIGHT_CLICK_CANCEL_THRESHOLD:
				_building_replace_right_dragged = true

	if not _camera_free_view_enabled:
		if _camera_orbit_dragging or _camera_pan_dragging:
			_camera_orbit_dragging = false
			_cancel_camera_pan()
		return false

	# 鈹€鈹€ Scroll wheel: zoom 鈹€鈹€
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			if _is_screen_position_in_3d_viewport(mb.position):
				_safe_kill_camera_tween()
				if _camera_state:
					_camera_state.mark_manual()
					_camera_state.distance = maxf(CAMERA_ORBIT_DISTANCE_MIN, _camera_state.distance - CAMERA_ORBIT_ZOOM_SENSITIVITY * 8.0)
					_sync_state_to_scene()
					if _view_controls:
						_view_controls.set_active_preset("free")
				return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			if _is_screen_position_in_3d_viewport(mb.position):
				_safe_kill_camera_tween()
				if _camera_state:
					_camera_state.mark_manual()
					_camera_state.distance = minf(CAMERA_ORBIT_DISTANCE_MAX, _camera_state.distance + CAMERA_ORBIT_ZOOM_SENSITIVITY * 8.0)
					_sync_state_to_scene()
					if _view_controls:
						_view_controls.set_active_preset("free")
				return true
		# -- Middle button: pan (Phase 23A-V4) --
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if not mb.pressed:
				var was_panning := _camera_pan_dragging
				_cancel_camera_pan()
				return was_panning
			var hovered := get_viewport().gui_get_hovered_control()
			return _try_begin_camera_pan(mb.position, hovered)
		# -- Right button: start / stop drag (Phase 23B-R2: short-press cancel while selecting) --
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed and _is_screen_position_in_3d_viewport(mb.position):
				_cancel_camera_pan()
				_safe_kill_camera_tween()
				_camera_orbit_dragging = true
				_camera_drag_start = mb.position
				_building_replace_right_press_pos = mb.position
				_building_replace_right_dragged = false
				if _camera_state:
					_camera_drag_start_yaw = _camera_state.yaw
					_camera_drag_start_pitch = _camera_state.pitch
				return true
			else:
				_camera_orbit_dragging = false
				# Phase 23B-R2: short right-click cancels building replacement
				if _building_replace_select_active and not _building_replace_right_dragged:
					_cancel_building_replace_selection("right_click")
				# Phase 26E-R1 Task 5: short right-click cancels lane selection
				if _is_lane_selection_active() and not _building_replace_right_dragged:
					_cancel_lane_selection(&"right_click")
				# Phase 27I-R0-R3: short right-click cancels piece selection (纯棋子选择场景)
				if _is_piece_selection_active() and not _building_replace_right_dragged:
					_cancel_piece_context(&"right_click")
				return true
	# 鈹€鈹€ Mouse motion while panning: pan (Phase 23A-V4) 鈹€鈹€
	if event is InputEventMouseMotion and _camera_pan_dragging:
		var pan_motion := event as InputEventMouseMotion
		_apply_camera_pan_relative(pan_motion.relative)
		return true

	# 鈹€鈹€ Mouse motion while orbiting: rotate 鈹€鈹€
	if event is InputEventMouseMotion and _camera_orbit_dragging:
		var mm := event as InputEventMouseMotion
		var dx := mm.position.x - _camera_drag_start.x
		var dy := mm.position.y - _camera_drag_start.y
		if _camera_state:
			_camera_state.mark_manual()
			_camera_state.yaw = _camera_drag_start_yaw - dx * CAMERA_ORBIT_ROT_SENSITIVITY
			_camera_state.pitch = clampi(_camera_drag_start_pitch + dy * CAMERA_ORBIT_ROT_SENSITIVITY, CAMERA_ORBIT_PITCH_MIN, CAMERA_ORBIT_PITCH_MAX)
			_sync_state_to_scene()
			if _view_controls:
				_view_controls.set_active_preset("free")
		# Phase 23B-R2: detect right-drag vs right-click for building replacement
		if _building_replace_select_active and not _building_replace_right_dragged:
			var dist := mm.position.distance_to(_building_replace_right_press_pos)
			if dist >= BUILD_REPLACE_RIGHT_CLICK_CANCEL_THRESHOLD:
				_building_replace_right_dragged = true
		return true
	return false

func _input(event: InputEvent) -> void:
	# The modal owns mouse and keyboard before any board raycast consumes them.
	if _exit_modal_active:return
	# PHASE53_BEGIN_INPUT
	if _core_surge_committing:return
	if _core_surge_selecting and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and _core_surge_pointer_is_gui(event.position):return
	if _core_surge_selecting:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE or event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
			_clear_core_surge_selection();get_viewport().set_input_as_handled();return
	# The existing command panel owns its left-click GUI events.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and is_instance_valid(_core_command_panel) and _core_command_panel.is_visible_in_tree() and _core_command_panel.get_global_rect().has_point(event.position):return
	# PHASE53_END_INPUT
	# Hint controls receive their normal GUI events before any board or camera action.
	if event is InputEventMouse:
		for hint_panel: Control in get_tree().get_nodes_in_group("card_relation_hint_panel"):
			if hint_panel.is_visible_in_tree() and hint_panel.get_global_rect().has_point(event.position):
				# A camera gesture begun outside still ends on its matching release here.
				if event is InputEventMouseButton and not event.pressed:
					if event.button_index == MOUSE_BUTTON_RIGHT:_camera_orbit_dragging=false
					elif event.button_index == MOUSE_BUTTON_MIDDLE:_cancel_camera_pan()
				return
	# Payment is a foreground GUI choice. Never let a board/core raycast
	# consume its click before Control receives it (including after a redraw).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and is_instance_valid(_monster_command_layer):
		var payment_panel := _monster_command_layer.get_node_or_null("PiecePaymentChoices") as Control
		if payment_panel != null and payment_panel.is_visible_in_tree() \
				and payment_panel.get_global_rect().has_point(event.position):
			return
	# Every shared confirmation panel owns its GUI clicks before board input.
	# Structure confirmations have their own presenter, including P08 relay targets.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and is_instance_valid(_structure_interaction_presenter) \
			and _structure_interaction_presenter.owns_build_pointer(event.position):
		return
	# Restricting this to siege/repair let new card intents swallow button presses.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and _monster_summon_state() == MONSTER_SUMMON_PENDING_CONFIRM \
			and is_instance_valid(_monster_summon_interaction_presenter):
		var panel: Control = _monster_summon_interaction_presenter.get_node_or_null("SummonPanel")
		if panel != null and panel.is_visible_in_tree() and panel.get_global_rect().has_point(event.position):
			return
	if bool(_garrison_context.get("active", false)):
		if event is InputEventMouseButton:
			var garrison_mouse := event as InputEventMouseButton
			if garrison_mouse.pressed and garrison_mouse.button_index == MOUSE_BUTTON_RIGHT:
				_clear_garrison_selection(&"right_click")
				get_viewport().set_input_as_handled()
				return
		if event is InputEventKey:
			var garrison_key := event as InputEventKey
			if garrison_key.pressed and not garrison_key.echo and garrison_key.keycode == KEY_ENTER \
					and _garrison_context.get("stage") == &"pending":
				_confirm_pending_garrison()
				get_viewport().set_input_as_handled()
				return
			if garrison_key.pressed and not garrison_key.echo and garrison_key.keycode == KEY_ESCAPE:
				_clear_garrison_selection(&"escape")
				get_viewport().set_input_as_handled()
				return
	if _is_monster_summon_interaction_active() and event is InputEventMouseButton:
		var summon_mouse := event as InputEventMouseButton
		if summon_mouse.pressed and summon_mouse.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_monster_summon_interaction(&"right_click")
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		if _structure_interaction_presenter != null and _structure_interaction_presenter.has_method("close_pinned") and bool(_structure_interaction_presenter.close_pinned()):
			get_viewport().set_input_as_handled()
			return
		if not _structure_interaction_blocked_by_modal():
			var structure_hit := _raycast_3d_click((event as InputEventMouseButton).global_position)
			if _pin_structure_target_hit(structure_hit):
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey:
		var summon_key := event as InputEventKey
		if summon_key.pressed and not summon_key.echo \
				and summon_key.keycode == KEY_ENTER \
				and _monster_summon_state() == MONSTER_SUMMON_PENDING_CONFIRM:
			var pending_intent := StringName(_monster_drag_session.get("intent", &""))
			if pending_intent == &"siege_attack":
				_confirm_siege_selection()
			elif pending_intent == &"structure_build":
				_on_structure_build_confirm_requested()
			elif _is_card_cast_drag_intent(pending_intent):
				_confirm_pending_card_cast()
			else:
				_on_monster_summon_confirm_requested()
			get_viewport().set_input_as_handled()
			return
		if summon_key.pressed and not summon_key.echo \
				and summon_key.keycode == KEY_ESCAPE \
				and _is_monster_summon_interaction_active():
			_cancel_monster_summon_interaction(&"escape")
			get_viewport().set_input_as_handled()
			return
	if bool(_od_release_context.get("active", false)) and event is InputEventMouseButton \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT \
			and (event as InputEventMouseButton).pressed:
		_clear_od_release_selection(&"right_click")
		get_viewport().set_input_as_handled()
		return
	# Phase 21F: Camera orbit 鈥?right-drag rotate + scroll zoom
	if _process_camera_orbit_input(event):
		return  # consumed by camera orbit
	if event is InputEventKey:
		var detail_key := event as InputEventKey
		if detail_key.pressed and not detail_key.echo and detail_key.keycode == KEY_ESCAPE \
				and _structure_interaction_presenter != null and _structure_interaction_presenter.has_method("close_pinned") and bool(_structure_interaction_presenter.close_pinned()):
			get_viewport().set_input_as_handled()
			return
		if detail_key.pressed and not detail_key.echo and detail_key.keycode == KEY_ESCAPE \
				and player_table != null and player_table.has_method("clear_pinned_detail") \
				and bool(player_table.clear_pinned_detail()):
			get_viewport().set_input_as_handled()
			return

	# Phase 27I-R0-R3: 右键短按取消棋子选择（默认相机模式不启用 orbit，右键不消费，需在此处理）
	if _is_piece_selection_active() and event is InputEventMouseButton \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT \
			and (event as InputEventMouseButton).pressed:
		_cancel_piece_context(&"right_click")
		get_viewport().set_input_as_handled()
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if battle_ended or _card_being_played:
		return
	# Skip if MonsterCommandMenu already open (prevent double-open)
		# [CELL_INPUT_RAW] diagnostic
		if _lane_selection_mode != LANE_SELECT_NONE:
			print("[CELL_INPUT_RAW] mode=%s card=%s menu_active=%s" % [_lane_selection_mode, _lane_selection_card.card_name if _lane_selection_card else "null", str(_monster_command_menu != null and is_instance_valid(_monster_command_menu))])
	if _monster_command_menu and is_instance_valid(_monster_command_menu):
		return
	var pos: Vector2 = mouse_event.position
	var hit_3d: Dictionary = {}

	# Phase 21E: 3D token click bridge 鈥?raycast before 2D hit-test
	if USE_3D_TOKEN_CLICK_BRIDGE:
		hit_3d = _raycast_3d_click(mouse_event.global_position)
		if _dispatch_3d_click_hit(hit_3d):
			get_viewport().set_input_as_handled()
			return
		# Active summon interactions may only reach their semantic 3D dispatcher.
		# Do not consume here: GUI controls (including the confirm panel buttons)
		# must retain their normal Control input path.
		if _is_monster_summon_interaction_active():
			return
		# Phase 27C-R1-GUI-FIX: prevent fall-through to field hit-test during selection
		if _is_lane_selection_active():
			return
	if _is_monster_summon_interaction_active():
		return

	# Hit-test player field
	# [CELL_PICK] diagnostic
	if _lane_selection_mode != LANE_SELECT_NONE:
		print("[CELL_PICK] hit_ok=%s target_kind=%s cell=%s selectable=%s" % [str(hit_3d.get("ok", false)), str(hit_3d.get("target_kind", "")), str(hit_3d.get("board_cell", "N/A")), str(hit_3d.get("selectable", false))])
	if player_table and player_table.has_method("get_field_card_at_global_position"):
		var result: Dictionary = player_table.get_field_card_at_global_position(pos)
		if result.get("ok", false):
			var card: CardData = result.get("card")
			var zone: String = result.get("zone", "")
			var side: String = result.get("owner_side", "player")
			var cname: String = card.get_display_name() if card.has_method("get_display_name") else card.card_name

			# Player front-field monster -> open command menu
			if side == "player" and zone == "front" and card.card_family == "monster":
				pass  # [FIELD_HITTEST_OPEN_MENU] silent 鈥?Phase 19D log reduction
				_request_unit_command(card, side, "hit_test")
				get_viewport().set_input_as_handled()
				return
			# Player front-field building -> building interact
			if side == "player" and zone == "front" and card.has_method("is_building_card") and card.is_building_card():
				pass  # [FIELD_HITTEST_BUILDING] silent 鈥?Phase 19D log reduction
				if player_table.has_signal("building_interact_requested"):
					player_table.building_interact_requested.emit(card)
				get_viewport().set_input_as_handled()
				return
			# Player back-field counter -> detail only
			if side == "player" and zone == "back" and card.card_family == "counter":
				pass  # [FIELD_HITTEST_COUNTER] silent 鈥?Phase 19D log reduction
				if player_table and player_table.card_detail_panel:
					player_table.card_detail_panel.visible = true
					player_table.card_detail_panel.show_card(card, "", {})
				get_viewport().set_input_as_handled()
				return
			# Player back-field other (trap/spell) -> detail only
			if side == "player" and zone == "back":
				pass  # [FIELD_HITTEST_BACK] silent 鈥?Phase 19D log reduction
				if player_table and player_table.card_detail_panel:
					player_table.card_detail_panel.visible = true
					player_table.card_detail_panel.show_card(card, "", {})
				get_viewport().set_input_as_handled()
				return

	var slot_result: Dictionary = _hit_test_player_front_slot(pos)
	if slot_result.get("ok", false):
		var slot_card: CardData = slot_result.get("card")
		if slot_card != null:
			var slot_name: String = slot_card.get_display_name() if slot_card.has_method("get_display_name") else slot_card.card_name
			pass  # [FIELD_SLOT_FALLBACK] silent 鈥?Phase 19D log reduction
			_request_unit_command(slot_card, "player", "slot_fallback")
			get_viewport().set_input_as_handled()
			return

	# Hit-test enemy field (for attack targeting)
	if enemy_table and enemy_table.has_method("get_field_card_at_global_position"):
		var e_result: Dictionary = enemy_table.get_field_card_at_global_position(pos)
		if e_result.get("ok", false):
			var e_card: CardData = e_result.get("card")
			var e_side: String = e_result.get("owner_side", "enemy")
			pass  # [FIELD_HITTEST_BOSS] silent 鈥?Phase 19D log reduction
			_request_unit_command(e_card, e_side, "hit_test")
			get_viewport().set_input_as_handled()
			return


# Dispatch a raycast result by semantic target type before reading token-only
# fields. Backline stations intentionally do not carry card/side/zone metadata.
func _dispatch_3d_click_hit(hit_3d: Dictionary) -> bool:
	# PHASE53_BEGIN_HIT
	if _core_surge_committing:return true
	if _core_surge_selecting:
		_dispatch_core_surge_target(hit_3d.get("card") as CardData,str(hit_3d.get("side","")));return true
	# PHASE53_END_HIT
	hit_3d = _guided_card_target(hit_3d, get_viewport().get_mouse_position())
	if bool(hit_3d.get("ok", false)) and _dispatch_siege_hit(hit_3d):
		return true
	if not bool(hit_3d.get("ok", false)):
		return false

	var target_kind := StringName(str(hit_3d.get("target_kind", "")))
	# An existing foundation is a build anchor, even when its structure proxy
	# is in front of the tactical-cell collider.
	if _piece_context.get("active", false) and _piece_context.get("stage") == &"anchor" \
			and _piece_context.get("action_id") == &"play" \
			and _is_structure_card_for_drag(_piece_context.get("card")):
		var build_cell := _structure_cell_from_drag_hit(hit_3d)
		if build_cell != MONSTER_DRAG_INVALID_CELL:
			return _dispatch_tactical_cell_selection(build_cell, true)
	if bool(_garrison_context.get("active", false)) and target_kind in [&"structure_core", &"structure_module"]:
		var structure_cell: Variant = hit_3d.get("board_cell", null)
		if not structure_cell is Vector2i:
			var target_ref: Variant = hit_3d.get("target_ref", {})
			if target_ref is Dictionary:
				structure_cell = (target_ref as Dictionary).get("cell", Vector2i(-1, -1))
		if structure_cell is Vector2i:
			return _dispatch_tactical_cell_selection(structure_cell, true)
		return true
	if _is_monster_summon_interaction_active():
		if StringName(_monster_drag_session.get("intent", &"")) == &"structure_build" \
				and _monster_summon_state() == MONSTER_SUMMON_RESELECTING \
				and target_kind in [&"tactical_cell", &"structure_core", &"structure_module"]:
			var structure_hover := _update_structure_drag_hover_hit(hit_3d)
			var structure_source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
			var structure_source := structure_source_ref.get_ref() as CardUI if structure_source_ref != null else null
			if structure_source != null and is_instance_valid(structure_source) and bool(structure_hover.get("ok", false)):
				_stage_structure_build_candidate(structure_source, structure_hover.get("cell", MONSTER_DRAG_INVALID_CELL), structure_hover.get("preview_fact", {}))
			return true
		# Reselecting is the sole active state allowed to consume a board cell;
		# all unit/core/backline/lane routes remain inert until confirmation.
		if _monster_summon_state() == MONSTER_SUMMON_RESELECTING and target_kind == &"tactical_cell":
			var reselect_cell_variant = hit_3d.get("board_cell", MONSTER_DRAG_INVALID_CELL)
			var reselect_cell: Vector2i = reselect_cell_variant if reselect_cell_variant is Vector2i else MONSTER_DRAG_INVALID_CELL
			return _dispatch_tactical_cell_selection(reselect_cell, bool(hit_3d.get("selectable", false)))
		var readonly_card := hit_3d.get("card") as CardData
		if readonly_card != null:
			# A click-origin P08 structure session still owns its legacy relay target
			# stage. Route that target through the same authority query before the
			# general active-session input shield consumes unrelated board clicks.
			if _is_piece_selection_active() \
					and StringName(_monster_drag_session.get("intent", &"")) == &"structure_build" \
					and str(_piece_context.get("stage", "")) == "target" \
					and _piece_context.get("action_id", &"") == &"play":
				var structure_card: CardData = _piece_context.get("card", null)
				if structure_card != null and str(structure_card.piece_payload_id) == "p08_rook_relay":
					if _is_piece_target_legal(readonly_card):
						_confirm_piece_action({"target": readonly_card})
					else:
						_show_piece_target_reject(readonly_card)
					return true
			_on_3d_token_clicked(readonly_card, str(hit_3d.get("side", "")), str(hit_3d.get("zone", "")), int(hit_3d.get("index", -1)))
		return true
	if target_kind in [&"structure_core", &"structure_module"]:
		if _structure_interaction_blocked_by_modal():
			return true
		return _dispatch_structure_target_hit(hit_3d)
	# Phase 27B-R1-R2-R: tactical_cell — routes all 4 modes through semantic dispatcher
	if target_kind == &"tactical_cell":
		var cell_variant = hit_3d.get("board_cell", Vector2i(-1, -1))
		var cell: Vector2i = cell_variant if cell_variant is Vector2i else Vector2i(-1, -1)
		var selectable: bool = bool(hit_3d.get("selectable", false))
		return _dispatch_tactical_cell_selection(cell, selectable)
	# Phase 26E-R1 Task 5: tactical_lane — highest priority, routes to lane selection
	if target_kind == &"tactical_lane":
		if _is_lane_selection_active():
			var tl_lane: int = int(hit_3d.get("lane_index", -1))
			var tl_selectable: bool = bool(hit_3d.get("selectable", false))
			if tl_selectable and tl_lane >= 0 and tl_lane < 5:
				_confirm_lane_selection(tl_lane)
			return true
		return false
	if target_kind == &"boss_core":
		# Phase 27E-R2: skill targeting takes priority
		if _skill_context.get("active", false) and _skill_context.get("can_target_boss_core", false):
			return _dispatch_monster_skill_selection(&"boss_core", null)
		_request_boss_core_attack()
		return true
	if target_kind != &"" and _resolve_od_backline_target(target_kind):
		return true

	# Phase 27E-R2: skill targeting enemy dispatch
	if _skill_context.get("active", false):
		var skill_token := hit_3d.get("card") as CardData
		var skill_side := str(hit_3d.get("side", ""))
		if skill_token != null and not skill_side.is_empty():
			return _dispatch_monster_skill_selection(&"enemy_unit", skill_token)

	var token_card := hit_3d.get("card") as CardData
	var token_side := str(hit_3d.get("side", ""))
	var token_zone := str(hit_3d.get("zone", ""))
	var token_idx := int(hit_3d.get("index", -1))
	if token_card == null or token_side.is_empty() or token_zone.is_empty():
		return false
	if bool(_od_release_context.get("active", false)):
		if StringName(_od_release_context.get("stage", &"")) == &"source":
			return _select_od_release_source(token_card)
		if StringName(_od_release_context.get("stage", &"")) == &"target":
			return _confirm_od_release_target(token_card)
	# Phase 27I-R0-R: 棋子选择状态优先——点击单位/核心作为 P01 锚点，或作为攻击主目标
	if _is_piece_selection_active():
		var p_stage: String = str(_piece_context.get("stage", ""))
		var p_action: StringName = _piece_context.get("action_id", &"")
		if p_stage == &"anchor":
			_confirm_piece_anchor(token_card)
			return true
		# Phase 27J-R4: payment 阶段只接受面板按钮，棋盘/单位点击安全吞掉。
		if p_stage == &"payment":
			return true
		if p_stage == &"target" and p_action == &"attack":
			if _stage_covered_attack_if_needed(_piece_context.card, token_card):
				return true
			_confirm_piece_action({"target": token_card})
			return true
		# Phase 27I-R1-R: P08 战车连接目标阶段——点击合法友军 Token 汇入 _confirm_piece_action；
		# 非法/过期目标只拒绝、不打出、不扣费、不清上下文、不重开怪兽菜单。
		if p_stage == &"target" and p_action == &"play":
			var p08_card: CardData = _piece_context.get("card", null)
			if p08_card != null and str(p08_card.piece_payload_id) == "p08_rook_relay":
				if _is_piece_target_legal(token_card):
					_confirm_piece_action({"target": token_card})
				else:
					_show_piece_target_reject(token_card)
				return true
	_on_3d_token_clicked(token_card, token_side, token_zone, token_idx)
	return true


func _dispatch_structure_target_hit(hit_3d: Dictionary) -> bool:

	var candidates := _get_structure_semantic_candidates(hit_3d)
	if candidates.is_empty():
		return false
	_sync_structure_interaction_safe_area()
	if candidates.size() > 1:
		if _structure_interaction_presenter != null and _structure_interaction_presenter.has_method("show_semantic_candidates"):
			_structure_interaction_presenter.show_semantic_candidates(candidates.duplicate(true), _project_world_position_to_screen(hit_3d.get("position", Vector3.ZERO)))
		return true
	var target_ref: Dictionary = (candidates[0] as Dictionary).duplicate(true)
	var view_model := _build_structure_view_model(target_ref)
	if view_model.is_empty():
		return false
	if _structure_interaction_presenter != null and _structure_interaction_presenter.has_method("inspect"):
		_structure_interaction_presenter.inspect(view_model.duplicate(true), target_ref.duplicate(true), _project_world_position_to_screen(hit_3d.get("position", Vector3.ZERO)))
	return true


func _get_structure_semantic_candidates(hit_3d: Dictionary) -> Array[Dictionary]:

	var clicked: Variant = hit_3d.get("target_ref", {})
	if not clicked is Dictionary:
		return []
	var clicked_cell: Variant = (clicked as Dictionary).get("cell", null)
	var supplied: Variant = hit_3d.get("legal_targets", [clicked])
	if not supplied is Array:
		return []
	var unique := {}
	for raw in supplied:
		if not raw is Dictionary:
			continue
		var candidate: Dictionary = (raw as Dictionary).duplicate(true)
		var kind := StringName(str(candidate.get("target_kind", &"")))
		if kind not in [&"structure_module", &"structure_core", &"tactical_cell"]:
			continue
		if clicked_cell is Vector2i and candidate.get("cell", clicked_cell) != clicked_cell:
			continue
		var key := "%s|%s|%s|%s" % [kind, candidate.get("structure_id", ""), candidate.get("module_id", ""), candidate.get("edge", "")]
		unique[key] = candidate
	var result: Array[Dictionary] = []
	for key in unique:
		result.append((unique[key] as Dictionary).duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var ranks := {&"structure_module": 0, &"structure_core": 1, &"tactical_cell": 2}
		var left_kind := StringName(str(left.get("target_kind", &"")))
		var right_kind := StringName(str(right.get("target_kind", &"")))
		var left_rank := int(ranks.get(left_kind, 99))
		var right_rank := int(ranks.get(right_kind, 99))
		if left_rank != right_rank: return left_rank < right_rank
		return "%s:%s:%s" % [left.get("structure_id", ""), left.get("module_id", ""), left.get("edge", "")] < "%s:%s:%s" % [right.get("structure_id", ""), right.get("module_id", ""), right.get("edge", "")]
	)
	return result


func _on_structure_candidate_selected(target_ref: Dictionary) -> void:

	var kind := StringName(str(target_ref.get("target_kind", &"")))
	if kind == &"tactical_cell":
		var cell: Variant = target_ref.get("cell", null)
		if cell is Vector2i:
			_dispatch_tactical_cell_selection(cell, true)
		return
	var view_model := _build_structure_view_model(target_ref.duplicate(true))
	if view_model.is_empty():
		return
	_sync_structure_interaction_safe_area()
	_structure_interaction_presenter.inspect(view_model.duplicate(true), target_ref.duplicate(true), Vector2.ZERO)


func _pin_structure_target_hit(hit_3d: Dictionary) -> bool:

	var kind := StringName(str(hit_3d.get("target_kind", &"")))
	if kind not in [&"structure_core", &"structure_module"]:
		return false
	var target_ref: Variant = hit_3d.get("target_ref", {})
	if not target_ref is Dictionary:
		return false
	var view_model := _build_structure_view_model((target_ref as Dictionary).duplicate(true))
	if view_model.is_empty() or _structure_interaction_presenter == null:
		return false
	_sync_structure_interaction_safe_area()
	_structure_interaction_presenter.pin_detail(view_model.duplicate(true), (target_ref as Dictionary).duplicate(true))
	return true


func _structure_interaction_blocked_by_modal() -> bool:

	return battle_ended or _card_being_played or _camera_orbit_frozen or _exit_modal_active \
		or (_monster_command_menu != null and is_instance_valid(_monster_command_menu)) \
		or _is_monster_summon_interaction_active() or _is_lane_selection_active() or _is_piece_selection_active() \
		or bool(_garrison_context.get("active", false)) or bool(_od_release_context.get("active", false)) \
		or _building_replace_select_active or bool(_skill_context.get("active", false))


func _on_structure_interaction_activate_requested(target_ref: Dictionary) -> void:

	var view_model := _build_structure_view_model(target_ref.duplicate(true))
	if view_model.is_empty():
		return
	var card := _find_structure_source_card(int((battle.get_structure_snapshot().get("structures", {}) as Dictionary).get(StringName(str(target_ref.get("structure_id", &""))), {}).get("source_runtime_id", 0))) if battle != null else null
	if card == null:
		return
	# Deliberately reuses the one existing signal/authority path; normal inspection never calls it.
	if player_table != null and player_table.has_signal("building_interact_requested"):
		player_table.building_interact_requested.emit(card)
# Shared battle input entry.
# 2D CardUI and future 3D token picking should both call this method.
func _request_unit_command(card: CardData, owner_side: String, source: String = "2d_card") -> void:
	# PHASE53_BEGIN_TARGET
	if _core_surge_committing:return
	if _dispatch_core_surge_target(card,owner_side):return
	# PHASE53_END_TARGET
	var card_label := card.get_display_name() if card.has_method("get_display_name") else card.card_name
	# Phase 19D: [UNIT_COMMAND_REQUEST] silent unless non-trivial

	if battle_ended or _card_being_played or _is_monster_summon_interaction_active() or bool(_garrison_context.get("active", false)):
		pass  # Phase 19D: silent blocked
		return
	if card == null:
		pass  # Phase 19D: silent null card
		return
	if not battle:
		pass  # Phase 19D: silent null battle
		return

	# Player front-field monster: open command menu
	if owner_side == "player" and _field_contains_card(context.player.field, card):
		if _selected_attacker == card:
			_full_cleanup_attack_targeting(&"deselect_same")
			if action_feed: action_feed.push_message("Deselected: %s" % card_label, TC.TEXT_DIM)
			return
		_full_cleanup_attack_targeting(&"switch_monster")
		_open_monster_command_menu(card)
		return

	# Boss front-field card as attack target (requires selected attacker)
	if owner_side in ["enemy", "boss"] and _selected_attacker != null:
		if not _field_contains_card(context.enemy.field, card):
			pass  # Phase 19D: enemy card not in field
			return
		# Phase 25D: 预检 Guard 目标合法性，非法点击不消费攻击
		var target_status: Dictionary = battle.can_monster_attack_target(_selected_attacker, card)
		if not bool(target_status.get("ok", false)):
			if action_feed:
				action_feed.push_message(str(target_status.get("reason", "无法攻击该目标")), TC.WARNING, "", 2.0)
			return
		# Phase 27D-R4: route through unified atomic transaction
		if _stage_covered_attack_if_needed(_selected_attacker, card):
			return
		var result: Dictionary = battle.execute_unit_command(_selected_attacker, "attack", card)
		_handle_attack_result(result)
		return

	# Counter / non-monster: detail already shown by player_table; no further action
	pass  # Phase 19D: no handler matched 鈥?silent
func _hit_test_player_front_slot(global_pos: Vector2) -> Dictionary:
	if context == null or context.player == null or player_table == null:
		return {"ok": false}
	if not player_table.has_method("find_front_slot_for_card"):
		return {"ok": false}
	for raw_card in context.player.field:
		var card := raw_card as CardData
		if card == null:
			continue
		var slot: Control = player_table.find_front_slot_for_card(card)
		if slot == null or not is_instance_valid(slot):
			continue
		var rect: Rect2 = slot.get_global_rect().grow(18.0)
		if rect.has_point(global_pos):
			var cname: String = card.get_display_name() if card.has_method("get_display_name") else card.card_name
			pass  # Phase 19D: [FIELD_SLOT_FALLBACK] silent
			return {"ok": true, "card": card, "owner_side": "player", "zone": "front", "slot": slot}
	return {"ok": false}
# Phase 10A / 19C: thin forward to unified entry
func _on_field_card_attack_clicked(card: CardData, owner_side: String) -> void:
	_request_unit_command(card, owner_side, "2d_card")
# Phase 25D: Boss 直接攻击入口 — 统一路由
func _on_boss_area_attack_clicked(owner_side: String) -> void:
	if owner_side != "enemy":
		return
	_request_boss_core_attack()

func _request_boss_core_attack() -> void:
	if battle_ended or _card_being_played or _is_monster_summon_interaction_active():
		return
	# Piece attacks have their own selected actor and payment/passive authority.
	if _is_piece_selection_active():
		if _piece_context.get("action_id") == &"attack" and _piece_context.get("stage") == &"target":
			_confirm_piece_action({"target": &"boss_core"})
		return
	if _selected_attacker == null:
		if action_feed:
			action_feed.push_message("先选择可攻击怪兽", TC.WARNING, "", 1.6)
		return
	# Phase 25D: 通过规则快照判断直接攻击合法性（取代旧的 field.is_empty()）
	var boss_status: Dictionary = battle.can_monster_attack_boss(_selected_attacker)
	if not bool(boss_status.get("ok", false)):
		if action_feed:
			action_feed.push_message(str(boss_status.get("reason", "无法直接攻击 Boss")), TC.WARNING, "", 2.0)
		return
	# Phase 27D-R4: route through unified atomic transaction (attack_core)
	var result: Dictionary = battle.execute_unit_command(_selected_attacker, "attack_core", null)
	_handle_attack_result(result)

## Phase 25D: 合法攻击目标高亮 — 通过规则快照判断每个目标
func _highlight_valid_attack_targets() -> void:
	if _selected_attacker == null or not enemy_table or not battle:
		return

	if enemy_table.has_method("clear_attack_highlights"):
		enemy_table.clear_attack_highlights()

	for target_card in context.enemy.field:
		if target_card == null:
			continue
		var target_status: Dictionary = battle.can_monster_attack_target(_selected_attacker, target_card)
		if not bool(target_status.get("ok", false)):
			continue
		var slot := _find_boss_slot_for_card(target_card)
		if slot and is_instance_valid(slot) and enemy_table.has_method("play_attack_target_pulse"):
			enemy_table.play_attack_target_pulse(slot)

	var boss_status: Dictionary = battle.can_monster_attack_boss(_selected_attacker)
	var boss_legal := bool(boss_status.get("ok", false))
	if boss_legal:
		_flash_boss_core()
		if action_feed:
			action_feed.push_message("可攻击 Boss 本体", TC.ZONE_HEATED, "", 1.6)
	if _boss_status_hud and is_instance_valid(_boss_status_hud):
		_boss_status_hud.set_clickable(boss_legal)

func _find_boss_slot_for_card(card: CardData) -> Control:
	if not enemy_table or not enemy_table.has_method("find_front_slot_for_card"):
		return null
	return enemy_table.find_front_slot_for_card(card)
## 婢跺嫮鎮婇弨璇插毊缂佹挻鐏夐敍鍫ｎ潒鐟欏寮芥＃鍫礆
func _handle_attack_result(result: Dictionary) -> void:
	if not result.get("ok", false):
		var reason: String = result.get("reason", str(result.get("reason_code", "攻击失败")))
		if action_feed:
			action_feed.push_message(reason, TC.WARNING, "", 2.0)
		_clear_attack_selection()
		return

	var res_type: String = result.get("result", "")
	var msg: String = result.get("message", "")
	# Phase 27D-R4: cost is now authoritative from execute_unit_command transaction
	var cost: int = int(result.get("cost", 0))
	if action_feed:
		var msg_color := TC.ZONE_HEATED
		match res_type:
			"target_destroyed", "trade":
				msg_color = TC.ACCENT_GOLD
			"attacker_destroyed":
				msg_color = TC.WARNING
			"both_survive":
				msg_color = TC.ZONE_HEATED
			"destroyed":
				msg_color = TC.ACCENT_GOLD
			"blocked":
				msg_color = TC.WARNING
			"hit_core":
				msg_color = TC.ZONE_OVERDRIVE
		action_feed.push_message(msg, msg_color, "", 2.5)
	# Phase 10D: CardVFX attacker lunge animation
	# Phase 11A: Telemetry
	if _playtest:
		_playtest.record_event("monster_attack", {"result": res_type, "attacker": _selected_attacker.card_name if _selected_attacker else "?", "cost": cost})
	# Phase 27K-R1-B: the Director is the single owner of committed attack presentation.
	var attack_facts := result.duplicate(true)
	attack_facts["status"] = &"committed"
	await _play_monster_presentation(&"attack", attack_facts)

	# Phase 27C-R1-R3: apply deferred destruction after presenter finishes animation
	if battle and battle.has_method("_apply_deferred_destruction"):
		battle._apply_deferred_destruction(result)
	_full_cleanup_attack_targeting(&"attack_done")
	# Phase 27D-R4: HUD refresh — economy already debited by execute_unit_command,
	# HUD reads authoritative snapshot on next refresh; animation uses real cost
	_play_command_economy_spend(cost)
	_refresh_tables()
	check_battle_end()

# Phase 10B: OD 閸楀洤鐪?閳?閺傜増蝎娴ｅ秷袙闁夸礁寮芥＃?
func _trigger_slot_unlock_feedback(new_layer: int) -> void:
	if new_layer <= 1 or new_layer > 5:
		return
	var new_slot_limit: int = 2
	# Phase 11C: OD妫ｆ牗顐奸崡鍥х湴閹绘劗銇?	_show_tutorial_hint_once("od_layer_up", "OD 鍗囧眰锛氭柊鐨勬€吔妲戒綅宸茶В閿併€傚崌灞傝秺蹇紝Depth 鍘嬪姏瓒婇珮銆?)
	match new_layer:
		2: new_slot_limit = 3
		3: new_slot_limit = 4
		4, 5: new_slot_limit = 5
	# [Fixed]
	if action_feed:
		action_feed.push_message("OD Up: %d slots (L%d)" % [new_layer, new_slot_limit], TC.ZONE_HEATED, "", 2.0)
	# ThisTurnPanel 缁犫偓閻叀顔囪ぐ?
	_add_to_this_turn("Slot +1 -> %d slots" % new_slot_limit, TC.ZONE_HEATED)
	# 閻厽娈忛懘澶婂暱 閳?閺傛媽袙闁夸胶娈戠粭?N 娑擃亝蝎娴?
	if player_table and player_table.has_method("find_front_slot_for_card"):
		# 鐎佃鏌婂Σ鎴掔秴閿涘牏鍌ㄥ鏇氳礋 new_slot_limit-1閿涘鎸遍弨鎹愋掗柨浣藉墻閸?
		var fresh_slot: Control = player_table.find_front_slot_for_card(null)  # 娑撳秷鍏橀柅姘崇箖 card 閹垫拝绱濋惄瀛樺复閹靛墽鈹栧Σ?
		# [Fixed]
		if player_table.has_method("play_slot_unlock_pulse"):
			player_table.play_slot_unlock_pulse(new_slot_limit - 1)
	# Phase 12F: 濡楀矂娼伴懗浠嬪櫤缁?閳?濡叉垝缍呯憴锝夋敚閺冭埖閮ㄥ宀勬／缁?
	var _bt12f := get_node_or_null(NodePath("BattleTable")) as Control
	if _bt12f and battle_vfx and player_table:
		var _from_p := _bt12f.global_position + Vector2(_bt12f.size.x * 0.5, _bt12f.size.y * 0.55)
		var _to_p := _from_p + Vector2(0, 20)
		var _lcolor: Color = Color(0.15, 0.55, 0.9, 0.7)
		if new_layer == 5:
			_lcolor = Color(1, 0.6, 0.1, 0.8)
		battle_vfx.play_table_energy_pulse(_bt12f, _from_p, _to_p, _lcolor)
	var core_panel := get_node_or_null(NodePath("BattleTable/CoreStatusPanel")) as Control
	if core_panel and battle_vfx:
		battle_vfx.play_engine_layer_up(core_panel, new_layer)
	if new_layer == 5:
		var battle_table := get_node_or_null(NodePath("BattleTable")) as Control
		if battle_table and battle_vfx:
			battle_vfx.play_burst_flash(battle_table)
	print("[Phase 10B] Slot unlock: Layer %d; %d active slots" % [new_layer, new_slot_limit])

func _on_card_clicked(card_ui: CardUI) -> void:
	# PHASE53_BEGIN_HAND
	if _core_surge_committing:return
	_clear_core_surge_selection()
	# PHASE53_END_HAND
	if battle_ended or _card_being_played:
		return
	if _is_monster_summon_interaction_active():
		var active_drag_card: CardData = _monster_drag_session.get("card", null)
		if (StringName(_monster_drag_session.get("intent", &"")) in [&"structure_build", &"siege_attack"] or _monster_drag_session.get("siege_mode", false) or _monster_drag_session.get("repair_mode", false) or _monster_drag_session.get("terrain_raise_mode", false)) \
				and card_ui != null and card_ui.card_data != active_drag_card:
			_cleanup_monster_drag_summon(&"card_switch")
		else:
			return

	# Clear any stale monster attack selection before handling a hand card.
	_clear_attack_selection()
	var card := card_ui.card_data
	if card == null:
		return
	# Phase 27I-R0-R3: 切换手牌卡先取消进行中的棋子选择，避免遗留黄色格 / EndTurn 永久 BUSY
	# Phase 27I-R0-R4: 同卡重复点击——不取消/不重建/不扣费，重新闪烁合法锚点并再次显示操作提示；
	# 只有切换到不同卡才取消旧 P01 选择并进入新卡流程。
	if _is_piece_selection_active():
		var active_card: CardData = _piece_context.get("card", null)
		if active_card != null and active_card == card:
			_requery_piece_status()
			return
		_cancel_piece_context(&"switch_card")
	# F2 chooses a cell before entering any spell animation.
	if card.card_id == "P23":
		if battle.tactical_terrain_raise_rules.is_enabled() and battle.can_play_card(card) and _begin_cast_lane_drag(card_ui, card, CARD_DRAG_CAST_LANE):
			_monster_drag_session.state = MONSTER_SUMMON_RESELECTING
			_monster_drag_session.terrain_raise_mode = true
			_refresh_terrain_raise_legal_cells(card)
			_ensure_terrain_raise_presenter()
			_terrain_raise_presenter.show_preview(_terrain_raise_view({}))
			var pointer := card_ui.get_global_rect().get_center()
			_monster_summon_interaction_presenter.show_card_drag(_make_card_cast_preview_fact(pointer, pointer, {}, false, &"awaiting_target"), _is_reduced_motion_presentation())
			if _monster_summon_drop_target != null:
				_monster_summon_drop_target.set_board_drag_active(false)
			if action_feed:
				action_feed.push_message("请选择己方地块或建筑，再确认升地；右键或 Escape 取消", TC.INFO, "", 3.0)
		return
	# Targeted repair must choose a wall before entering any spell animation.
	if card.card_id == "P22":
		if battle.tactical_repair_rules.is_enabled() and battle.can_play_card(card) and _begin_cast_lane_drag(card_ui, card, CARD_DRAG_CAST_LANE):
			_monster_drag_session.state = MONSTER_SUMMON_RESELECTING
			_monster_drag_session.repair_mode = true
			var pointer := card_ui.get_global_rect().get_center()
			_monster_summon_interaction_presenter.show_card_drag(_make_card_cast_preview_fact(pointer, pointer, {}, false, &"awaiting_target"), _is_reduced_motion_presentation())
			if _monster_summon_drop_target != null:
				_monster_summon_drop_target.set_board_drag_active(false)
			if action_feed:
				action_feed.push_message("请选择己方受损墙面，再确认修复；右键或 Escape 取消", TC.INFO, "", 3.0)
		return
	# Log the authoritative playability result before dispatch.
	_log_card_play_check(card, "click")
	# Generic Phase D2 BUILD cards use the same structure targeting and final
	# confirmation boundary as native drag. They never enter the chess-piece path.
	if _is_generic_d2_structure_card(card):
		if not _begin_structure_build_click_selection(card_ui, card):
			_show_unplayable_reason(card)
			if card_ui.has_method("play_drop_denied_animation"):
				card_ui.play_drop_denied_animation()
		return



	# 閺夆€叉妫板嫭顥呴敍姘瑝濠娐ゅ喕閸掓瑤绗夊☉鍫ｂ偓妤€宕遍悧?
	if not battle.can_play_card(card):
		# [Fixed]
		if battle.needs_building_replacement(card):
				# Phase 23B-R2: true-3D mode uses direct board click
			if USE_TRUE_3D_BOARD_BACKGROUND and USE_3D_TOKEN_CLICK_BRIDGE:
				_begin_building_replace_selection(card, card_ui)
			else:
				_show_building_replace_panel(card, card_ui)
			return
		_show_unplayable_reason(card)
		if card_ui.has_method("play_drop_denied_animation"):
			card_ui.play_drop_denied_animation()
		return

	# Phase 27I-R0-R: 棋型出牌类（P01/P04/P05）先进入棋子选择状态机，不得直接 play_card
	if card.piece_enabled and card.card_family in ["spell", "counter", "building"]:
		_begin_piece_selection(card_ui, card, &"play")
		return

	# Phase 26E-R1: front-row monster enters manual lane selection
	if card.is_front_row_card() and card.card_family == "monster":
		_begin_manual_summon_selection(card_ui, card, &"click")
		return

	_card_being_played = true
	_stat_total_cards += 1
	_trigger_guides_on_card_play()
	context.combo_system.on_card_played()
	if action_feed:
		if card.rarity == CardData.CardRarity.SUPER:
			action_feed.push_message("FINISHER: %s" % card.card_name, TC.ACCENT_GOLD)
		# Phase 11A: Telemetry
		if _playtest:
			_playtest.record_event("finisher_played", {"card": card.card_name})
		else:
			_add_to_this_turn("Play: %s" % card.card_name, TC.role_color(card.archetype_role))

	var boss_hp_before: int = context.enemy.hp
	var boss_shield_before: int = context.enemy.boss_shield if context.enemy and "boss_shield" in context.enemy else 0
	var player_hp_before: int = context.player.hp

	# 閳光偓閳光偓 缁屾椽妫块崠鏍棧鐞涘瞼娲伴弽?閳光偓閳光偓
	var flight_target := _get_boss_screen_pos()  # 姒涙顓绘鐐叉倻 BossCore
	# Phase 2C-0閿涙艾澧犻崷?閸氬骸婧€閸楋繝顥ｉ崥鎴烆攽闂堛垺蝎娴ｅ稄绱濋惉顒€褰傞崡锟狀棧閸?BossCore
	if card and player_table:
		if card.is_front_row_card() or card.is_back_row_card():
			if player_table.has_method("get_next_board_slot_screen_pos"):
				flight_target = player_table.get_next_board_slot_screen_pos(card)
	var is_super := (card.rarity == CardData.CardRarity.SUPER)

	# Phase 12C: 閸楋紕澧?Departure 閳?閸戠儤澧滈崜宥堟崳閹靛妫崗?
	if card_vfx and is_instance_valid(card_ui):
		var _ctype: String = ""
		if card.card_family == "building":
			_ctype = "BUILD"
		else:
			match card.card_type:
				CardData.CardType.UNIT:
					_ctype = "MONSTER"
				CardData.CardType.TRAP:
					_ctype = "COUNTER"
				CardData.CardType.SPELL:
					_ctype = "SPELL"
		card_vfx.play_card_departure(card_ui, _ctype, is_super)
		# Let the departure visual become visible before resolving the card.
		await get_tree().create_timer(0.08).timeout
		if not is_instance_valid(card_ui):
			_card_being_played = false
			return

		# ===== Phase 27C-R1: Two-phase spell activation (SPELL/INSTANT, not finisher) =====
		if card.is_instant_card() and not is_super:
			var spell_handle: Dictionary = await _begin_spell_presentation(card_ui, card, false, _build_spell_presentation_facts(card_ui, card, false))
			if not spell_handle.get("ok", false):
				_card_being_played = false
				return

			# -- COMMIT_RESOLVE: single authoritative commit --
			battle.play_card(card)

			# [Fixed] Telemetry
			if _playtest:
				_playtest.record_event("card_played", {"card": card.card_name, "type": card.card_type, "rarity": card.rarity})

			# Boss Reaction
			if boss_deck and boss_deck.has_method("check_player_card_reaction"):
				boss_deck.check_player_card_reaction(context.cards_played_this_turn)

			# Refresh hand immediately after authoritative commit
			_refresh_tables()

			# -- Finish: resolve flash + GY travel + cleanup --
			var committed_spell_damage := maxi(0, boss_hp_before - context.enemy.hp)
			var committed_spell_absorbed := maxi(0, boss_shield_before - int(context.enemy.boss_shield)) if context.enemy and "boss_shield" in context.enemy else 0
			var spell_result := {"ok": true, "damage": committed_spell_damage, "shield_absorbed": committed_spell_absorbed, "target_position": _get_boss_screen_pos()}
			await _finish_spell_presentation(spell_handle, spell_result)

			# Post-resolution FX (damage numbers, audio, flash)
			var hit_dmg: int = boss_hp_before - context.enemy.hp
			if hit_dmg > _stat_max_hit:
				_stat_max_hit = hit_dmg
			if enemy_table:
				_show_damage_number(hit_dmg, enemy_table, false)
			var am_card = _am()
			if am_card:
				am_card.play_card_play()
				if card.card_type == CardData.CardType.SPELL:
					am_card.play_spell_cast()
				elif card.card_type == CardData.CardType.TRAP:
					am_card.play_counter_set()
			var am_sfx = _am()
			if am_sfx: am_sfx.play_sfx("card_play")
			if enemy_table and enemy_table.has_method("flash_hit"):
				enemy_table.flash_hit()
			_flash_boss_core()
			if fx and fx.has_method("shake"):
				fx.shake(6.0)
			if player_table:
				if player_table.has_method("pulse_od_core"):
					player_table.pulse_od_core()
				if player_table.has_method("flash_od_zone"):
					player_table.flash_od_zone()

			_card_being_played = false
			_audit_state_consistency("spell")
			check_battle_end()
			return

		# ===== Phase 27C-R1: Finisher two-phase activation =====
		if is_super:
			_announce_major_event("FINISHER!\n%s" % card.card_name, TC.ACCENT_GOLD, 1.5)

			var fin_presentation_facts := _build_spell_presentation_facts(card_ui, card, true)
			var fin_handle: Dictionary = await _begin_spell_presentation(card_ui, card, true, fin_presentation_facts)
			if not fin_handle.get("ok", false):
				_card_being_played = false
				return

			_flash_boss_core()
			_play_finisher_fx(card)
			_shake_boss_core_heavy()

			var fin_phase_lock_before := _capture_phase_lock_presentation_snapshot()
			var fin_play_result: Dictionary = battle.play_card(card)
			var fin_phase_lock_after := _capture_phase_lock_presentation_snapshot()

			# Boss Reaction
			if boss_deck and boss_deck.has_method("check_player_card_reaction"):
				boss_deck.check_player_card_reaction(context.cards_played_this_turn)

			var fin_hit_dmg: int = boss_hp_before - context.enemy.hp
			if fin_hit_dmg > _stat_max_hit:
				_stat_max_hit = fin_hit_dmg
			if enemy_table:
				_show_damage_number(fin_hit_dmg, enemy_table, true)

			var am_fin = _am()
			if am_fin: am_fin.play_sfx("card_play")
			if enemy_table and enemy_table.has_method("flash_hit"):
				enemy_table.flash_hit()
			_flash_boss_core()
			var am_boss_fin = _am()
			if am_boss_fin: am_boss_fin.play_boss_hit()
			if player_table:
				if player_table.has_method("pulse_od_core"):
					player_table.pulse_od_core()
				if player_table.has_method("flash_od_zone"):
					player_table.flash_od_zone()

			_refresh_tables()

			var fin_phase_lock_shield_gain := _committed_phase_lock_shield_gain(fin_phase_lock_before, fin_phase_lock_after)
			var fin_absorbed := maxi(0, boss_shield_before + fin_phase_lock_shield_gain - int(context.enemy.boss_shield)) if context.enemy and "boss_shield" in context.enemy else 0
			var fin_result := {
				"ok": bool(fin_play_result.get("ok", false)),
				"status": &"committed" if bool(fin_play_result.get("ok", false)) else &"failed",
				"card_id": StringName(fin_presentation_facts.get("card_id", &"")),
				"damage": maxi(0, fin_hit_dmg),
				"shield_absorbed": fin_absorbed,
				"self_damage": maxi(0, player_hp_before - context.player.hp),
				"source_position": fin_presentation_facts.get("source_position", Vector2.ZERO),
				"target_position": fin_presentation_facts.get("target_position", _get_boss_screen_pos()),
				"player_position": fin_presentation_facts.get("player_position", _get_player_core_presentation_pos()),
			}
			await _finish_spell_presentation(fin_handle, fin_result)

			_card_being_played = false
			_audit_state_consistency("finisher")
			check_battle_end()
			return

		# ===== Non-instant card (monster, building, trap) =====
		await card_ui.play_card_animation(flight_target, 1.2)

		if card.card_type == CardData.CardType.UNIT:
			_flash_boss_core()

		if fx and fx.has_method("shake"):
			fx.shake(6.0)

		battle.play_card(card)

		# Boss Reaction
		if boss_deck and boss_deck.has_method("check_player_card_reaction"):
			boss_deck.check_player_card_reaction(context.cards_played_this_turn)

		var hit_dmg: int = boss_hp_before - context.enemy.hp
		if hit_dmg > _stat_max_hit:
			_stat_max_hit = hit_dmg

		if enemy_table:
			_show_damage_number(hit_dmg, enemy_table, false)

		var am_play = _am()
		if am_play: am_play.play_sfx("card_play")
		if enemy_table and enemy_table.has_method("flash_hit"):
			enemy_table.flash_hit()
		_flash_boss_core()
		var am_boss = _am()
		if am_boss: am_boss.play_boss_hit()

		if player_table:
			if player_table.has_method("pulse_od_core"):
				player_table.pulse_od_core()
			if player_table.has_method("flash_od_zone"):
				player_table.flash_od_zone()

		_card_being_played = false
		_refresh_tables()
		_audit_state_consistency("play")
		check_battle_end()

# ============================================================
# 閹锋牗瀚块崙铏瑰閿涘牆鎯堥柌濠冩杹濠曟柨鍤敍?
# ============================================================
func _on_card_dropped(card_ui: CardUI, card: CardData, zone_type: String) -> void:
	if battle_ended or _card_being_played or _is_monster_summon_interaction_active():
		return

	if card == null:
		return
	# Log the authoritative playability result before drop dispatch.
	_log_card_play_check(card, "drop")



	# 閺夆€叉妫板嫭顥呴敍姘瑝濠娐ゅ喕閸掓瑤绗夊☉鍫ｂ偓妤€宕遍悧?
	if not battle.can_play_card(card):
		if card_ui and card_ui.has_method("play_drop_denied_animation"):
			card_ui.play_drop_denied_animation()
		return

	# ---- 1. 閸氬牊纭堕幀褎顥呴弻銉礄Phase 2A閿涙碍鏁奸悽?CardData helper閿?---
	var is_valid := false
	match zone_type:
		"field":
			is_valid = card.is_front_row_card()
		"spell":
			is_valid = card.is_instant_card()
		"trap":
			is_valid = card.is_back_row_card()
		"graveyard":
			is_valid = true

	if not is_valid:
		if card_ui and card_ui.has_method("play_drop_denied_animation"):
			card_ui.play_drop_denied_animation()
		return

	# Monster field drops always require an exact authoritative board cell.
	if zone_type == "field" and _is_monster_card_for_drag(card):
		_begin_manual_summon_selection(card_ui, card, &"drop_fallback", zone_type)
		return

	# Phase 27I-R0-R: 拖放路径与点击路径统一——棋型出牌类同样进入棋子选择状态机
	if card.piece_enabled and card.card_family in ["spell", "counter", "building"]:
		_begin_piece_selection(card_ui, card, &"play")
		return

	_card_being_played = true
	_stat_total_cards += 1

	# ---- 2. 閼惧嘲褰囬惄顔界垼閸栧搫鐓欐稉顓炵妇 ----
	var target_pos := card_board_position
	if player_table and player_table.has_method("get_zone_global_center"):
		var zone_pos := player_table.get_zone_global_center(zone_type)
		if zone_pos != Vector2.ZERO:
			target_pos = zone_pos

	# ---- 3. 閹绢厽鏂丆ardUI閹存劕濮涢崝銊ф暰 ----
	var is_super := (card.rarity == CardData.CardRarity.SUPER)
	var is_instant := card.is_instant_card()
	if card_ui and not is_instant:
		if is_super and card_ui.has_method("play_super_card_animation"):
			card_ui.play_super_card_animation(target_pos)
		elif card_ui.has_method("play_drop_success_animation"):
			card_ui.play_drop_success_animation(target_pos)

	# ---- 4. 閹绢厽鏂侀崠鍝勭厵闂傤亜鍘?----
	# [Fixed]
	if not is_instant and player_table and player_table.has_method("flash_zone"):
		player_table.flash_zone(zone_type)

	# ---- 5. 鐏炲繐绠烽棁鍥уЗ / SUPER闂傤亜鍘?----
	if is_super:
		_play_finisher_fx(card)
		_shake_boss_core_heavy()
	elif not is_instant:
		if fx and fx.has_method("shake"):
			fx.shake(5.0)

	# ---- 6. 缂佹挾鐣?----
	context.combo_system.on_card_played()
	# Phase 27C-R1: Two-phase spell activation (drop path)
	if card.is_instant_card() and not is_super:
		var spell_handle: Dictionary = await _begin_spell_presentation(card_ui, card, false, _build_spell_presentation_facts(card_ui, card, false))
		if not spell_handle.get("ok", false):
			_card_being_played = false
			return

		var b_hp_before: int = context.enemy.hp
		var b_shield_before: int = context.enemy.boss_shield if context.enemy and "boss_shield" in context.enemy else 0
		_enemy_od_before_card = context.enemy.od if context.enemy else 0

		# -- COMMIT_RESOLVE: single authoritative commit --
		battle.play_card(card)

		# Boss Reaction
		if boss_deck and boss_deck.has_method("check_player_card_reaction"):
			boss_deck.check_player_card_reaction(context.cards_played_this_turn)

		# Refresh hand immediately after authoritative commit
		_refresh_tables()

		# -- Finish: resolve flash + GY travel + cleanup --
		var drop_spell_damage := maxi(0, b_hp_before - context.enemy.hp)
		var drop_spell_absorbed := maxi(0, b_shield_before - int(context.enemy.boss_shield)) if context.enemy and "boss_shield" in context.enemy else 0
		var spell_result := {"ok": true, "damage": drop_spell_damage, "shield_absorbed": drop_spell_absorbed, "target_position": _get_boss_screen_pos()}
		await _finish_spell_presentation(spell_handle, spell_result)

		# Post-resolution FX
		var b_hit: int = b_hp_before - context.enemy.hp
		if b_hit > _stat_max_hit:
			_stat_max_hit = b_hit
		if enemy_table:
			_show_damage_number(b_hit, enemy_table, false)

		var am3 = _am()
		if am3: am3.play_sfx("card_play")
		if enemy_table and enemy_table.has_method("flash_hit"):
			enemy_table.flash_hit()
		_flash_boss_core()
		if fx and fx.has_method("shake"):
			fx.shake(6.0)
		if player_table:
			if player_table.has_method("pulse_od_core"):
				player_table.pulse_od_core()
			if player_table.has_method("flash_od_zone"):
				player_table.flash_od_zone()

		_card_being_played = false
		_audit_state_consistency("spell_drop")
		check_battle_end()
		return

	var b_hp_before: int = context.enemy.hp

	if zone_type == "graveyard":
		if battle.has_method("discard_card"):
			battle.discard_card(card)
	else:
		# Track boss OD before card execution for overflow detection
		_enemy_od_before_card = context.enemy.od if context.enemy else 0
		battle.play_card(card)

	# Boss Reaction 濡偓閺?
	if boss_deck and boss_deck.has_method("check_player_card_reaction"):
		boss_deck.check_player_card_reaction(context.cards_played_this_turn)

	# 娴笺倕顔婄捄鍐茬摟
	var b_hit: int = b_hp_before - context.enemy.hp
	if b_hit > _stat_max_hit:
		_stat_max_hit = b_hit
	if enemy_table:
		var b_super: bool = (card.rarity == CardData.CardRarity.SUPER)
		_show_damage_number(b_hit, enemy_table, b_super)

	# ---- 7. OD 閸欏秹顩?----
	if player_table:
		if player_table.has_method("pulse_od_core"):
			player_table.pulse_od_core()
		if player_table.has_method("flash_od_zone"):
			player_table.flash_od_zone()

	# 閸戣櫣澧濋棅铏櫏
	var am2 = _am()
	if am2: am2.play_sfx("card_play")

	# ---- 8. Boss 閸欐鍤?+ 閸掗攱鏌?----
	if enemy_table and enemy_table.has_method("flash_hit"):
		enemy_table.flash_hit()
	_flash_boss_core()
	var am_bh2 = _am()
	if am_bh2: am_bh2.play_boss_hit()
	_card_being_played = false
	_refresh_tables()
	_audit_state_consistency("play")
	check_battle_end()

# ============================================================
# Phase 9A: Playtest Debug Snapshot (娴?debug 閺嬪嫬缂?
# ============================================================

func _debug_playtest_snapshot(label: String) -> void:
	if not OS.is_debug_build():
		return
	var t := context.turn_count if context else 0
	var ph := context.player.hp if context.player else 0
	var bh := context.enemy.hp if context.enemy else 0
	var ol := 1; var oc := 0; var bt := 0; var dp := 0; var bl := 0
	if context.od_mode:
		ol = context.od_mode.engine_layer
		oc = context.od_mode.engine_charge
		bt = context.od_mode.burst_turns_remaining
	if context.has_method("get_depth_pressure"):
		dp = context.get_depth_pressure()
	if context.has_method("is_abyss_locked"):
		bl = 1 if context.is_abyss_locked() else 0
	var hnd := context.player.hand.size() if context.player else 0
	var dk := context.player.deck.size() if context.player else 0
	var gy := context.player.graveyard.size() if context.player else 0
	var fd := context.player.field.size() if context.player else 0
	var tp := context.player.traps.size() if context.player else 0
	var bf := context.enemy.field.size() if context.enemy else 0
	var btr := context.enemy.traps.size() if context.enemy else 0
	var bgy := context.enemy.graveyard.size() if context.enemy else 0
	print("[PLAYTEST] %s | T%d | HP:%d BHP:%d | L%d c:%d/%d burst:%d | Depth:%d/6 BL:%d | hand:%d deck:%d gy:%d field:%d trap:%d | Bfield:%d Btrap:%d Bgy:%d" % [
		label, t, ph, bh, ol, oc, context.od_mode.ENGINE_LAYER_CAPACITY[ol] if ol <= 5 and context.od_mode else 0, bt, dp, bl, hnd, dk, gy, fd, tp, bf, btr, bgy
	])
# ============================================================
# 缂佹挻娼崶鐐叉値
# ============================================================
func _on_end_turn() -> void:
	# PHASE53_BEGIN_ENDTURN
	if _core_surge_committing:return
	# PHASE53_END_ENDTURN
	if _monster_summon_state() == MONSTER_SUMMON_COMMITTING:
		return
	var structure_build_was_active := _is_structure_build_drag_active()
	_cleanup_structure_presentation_lifecycle(&"end_turn")
	if structure_build_was_active:
		_show_toast("structure_cancelled", "已取消建设选位；再次点击可结束回合", TC.INFO, 1.2)
		return
	if _is_monster_summon_interaction_active():
		_cancel_monster_summon_interaction(&"end_turn_pressed")
		_show_toast("summon_cancelled", "已取消召唤选位；再次点击可结束回合", TC.INFO, 1.2)
		return
	_monster_summon_end_turn_body_entry_count += 1
	if battle_ended:
		return
	var presentation_active: bool = _presentation_end_turn_blocked \
		or (_battle_presentation_director != null and is_instance_valid(_battle_presentation_director) and _battle_presentation_director.is_busy())
	if presentation_active:
		_show_toast("presentation_active", "战斗演出正在收束", Color(1.0, 0.72, 0.28, 1.0), 1.2)
		return
	# Phase 27C-R1: Block End Turn during spell activation
	if _card_being_played or _spell_end_turn_blocked or (spell_activation_presenter and is_instance_valid(spell_activation_presenter) and spell_activation_presenter.is_active()):
		_show_toast("spell_active", "卡牌正在结算", Color(1.0, 0.7, 0.3, 1), 1.5)
		return
	# Phase 23B-R2: cancel building replace on end turn
	_cancel_building_replace_selection("end_turn", false)
	# Phase 26E-R1 Task 5: cancel lane selection on end turn
	_cancel_lane_selection(&"end_turn")
	_clear_od_release_selection(&"end_turn")

	# Phase 10A: 濞撳懘娅庨弨璇插毊闁瀚?	_clear_attack_selection()

	# Phase 26C: 关闭玩家回合核心指令窗口
	if battle and battle.has_method("close_player_turn_core_command"):
		battle.close_player_turn_core_command()

	# Phase 27D: close player economy on end turn
	if battle and battle.has_method("close_command_economy_turn"):
		battle.close_command_economy_turn("player")

	# Phase 27I-R1: 玩家回合结束清除主教赋刃状态（不等待下一个玩家回合开始）
	if battle and battle.has_method("cleanup_piece_enchant_for_turn_end"):
		battle.cleanup_piece_enchant_for_turn_end(&"player")

	# 闂呮劘妫岀紒鎾存将閸ョ偛鎮庨幐澶愭尦閿涘湐oss 閸ョ偛鎮庢稉宥呭讲閹垮秳缍旈敍?
	if _end_turn_control and is_instance_valid(_end_turn_control):
		_end_turn_control.visible = false
	if _end_turn_btn:
		_end_turn_btn.visible = false
		_end_turn_btn.disabled = true
		_end_turn_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Phase 27D-R5-R2-R

	# Phase D2: once input is committed to ending, expire only an already-active
	# player recovery window before the turn authority switches sides.
	if battle and battle.has_method("resolve_foundation_turn_end"):
		var _player_foundation_end: Dictionary = battle.resolve_foundation_turn_end(&"player")

	turn.end_turn()

	# 鐟欙箑褰傛稉鈧▎鈩冣偓褍寮介崚璁圭幢閹镐胶鐢诲铏圭摎/鐠佺偓鏌﹂悾娆忔躬閸氬骸婧€
	var triggerable_traps: Array = []
	for t in context.player.traps:
		if t != null and not t.is_continuous and not (battle.reaction_trial != null and battle.reaction_trial.owns(t)):
			triggerable_traps.append(t)
	if not triggerable_traps.is_empty():
		print("[PHASE] Triggering traps...")
		var _trap_count: int = triggerable_traps.size()
		var trap_names: String = ""
		for t in triggerable_traps:
			if t != null and "card_name" in t:
				var trap_display: String = t.get_display_name() if t.has_method("get_display_name") else t.card_name
				trap_names += trap_display + " "
		if battle.has_method("trigger_traps"):
			battle.trigger_traps("enemy")
		# 闂勭兘妲虹憴锕€褰傞崣宥夘洯
		_stat_trap_triggered += 1
		# Phase 12D: 閸欏秴鍩楅柨渚€鎽?閳?COUNTER 鐟欙箑褰傞弮鍓佹畱闂堟帞璞㈢亸渚€鏀ｇ痪?
		var _btab3 := get_node_or_null(NodePath("BattleTable")) as Control
		if _btab3 and battle_vfx:
			var _boss_target := _btab3.global_position + _btab3.size * Vector2(0.5, 0.35)
			if _boss_core_visual and is_instance_valid(_boss_core_visual):
				_boss_target = _get_boss_screen_pos()
			for _tr in triggerable_traps:
				if _tr == null or not ("card_name" in _tr):
					continue
				var _tr_slot := player_table.find_back_slot_for_card(_tr) if player_table and player_table.has_method("find_back_slot_for_card") else null
				if _tr_slot and is_instance_valid(_tr_slot):
					var _tr_pos := _tr_slot.global_position + _tr_slot.size * 0.5
					await _play_generic_presentation(&"counter", {
						"ok": true,
						"status": &"committed",
						"triggered": true,
						"card": _tr,
						"label": _tr.get_display_name() if _tr.has_method("get_display_name") else _tr.card_name,
						"source_position": _tr_pos,
						"target_position": _boss_target,
						"debuff": "Boss",
					})
		_trigger_guides_trap_set()
		_show_toast("trap_" + str(context.turn_count), "Trap triggered: %s" % trap_names.strip_edges(), TC.ROLE_CONTROL, 2.0)
		_flash_player_zone(TC.ROLE_CONTROL)
		_flash_boss_zone(TC.ZONE_CALM)
		if fx and fx.has_method("flash"):
			fx.flash(Color(TC.ROLE_CONTROL.r, TC.ROLE_CONTROL.g, TC.ROLE_CONTROL.b, 0.2), 0.25)
		# 閺囧瓨鏌婇梽鐑芥Ш閸栫儤妯夌粈?
		_refresh_tables()
		check_battle_end()
		if battle_ended:
			return

	# 鐠佹澘缍?Boss 鐞涘苯濮╅崜宥囧负鐎?HP
	var player_hp_before: int = context.player.hp

	# 閺佸奔姹夌悰灞藉З閿涘湐oss zone_changed 娣団€冲娇閼奉亜濮╂径鍕倞 FX 閸?UI閿?
	# Boss turn with animation pipeline
	# Phase 4C-4: Boss turn with zone-aware announcement
	var boss_zone := context.enemy.get_od_zone_name() if context.enemy else "Calm"
	var zone_color := TC.zone_color(boss_zone)
	var behavior_text := context.enemy._get_zone_behavior_text(boss_zone) if context.enemy.has_method("_get_zone_behavior_text") else ""
	# Phase 11A: Boss turn snapshot
	if _playtest:
		_playtest.record_turn_snapshot("boss", context, battle)
	_announce_major_event("BOSS TURN", TC.ZONE_HEATED, 0.8)
	if action_feed:
		action_feed.push_message("Boss Turn [%s: %s]" % [boss_zone, behavior_text], zone_color, "", 2.5)

	# Phase D2: activate Boss-owned awaiting windows immediately before Boss
	# intent/actions, granting the complete Boss action phase.
	if battle and battle.has_method("resolve_foundation_turn_begin"):
		var _boss_foundation_begin: Dictionary = battle.resolve_foundation_turn_begin(&"boss")

	# Step 1: Reveal intent (OD growth + card draw)
	if context.enemy.has_method("reveal_intent"):
		context.enemy.reveal_intent()

	# Step 2: Show intent card animation if there's a card
	if boss_deck and boss_deck.has_intent():
		var card = boss_deck.current_intent
		var from_pos = _get_boss_screen_pos()
		var gy_pos = enemy_table.get_zone_global_center("graveyard") if enemy_table else card_board_position
		boss_card_presenter.present_intent(card, from_pos, card_board_position, gy_pos)
		await boss_card_presenter.animation_complete

	var _siege_result: Dictionary = _run_boss_turn_rules_before_tactics()
	# Finish the lethal intent itself, then stop before starting another action.
	if context.player.hp <= 0 or context.enemy.hp <= 0:
		if battle.has_method("close_command_economy_turn"):
			battle.close_command_economy_turn("boss")
		_refresh_tables()
		_hide_boss_intent_after_execute()
		_stat_player_max_hp_lost = maxi(_stat_player_max_hp_lost, player_hp_before - context.player.hp)
		check_battle_end()
		return

	# Phase 27F: Boss tactical AI multi-action loop (Planner-driven)
	if battle.reaction_trial != null:
		battle.reaction_trial.begin_turn()
	if battle and battle.has_method("get_boss_tactical_action_candidates"):
		var boss_max_actions: int = 6
		if battle.boss_tactical_ai_profile and battle.boss_tactical_ai_profile.has_method("get_max_actions_per_turn"):
			boss_max_actions = battle.boss_tactical_ai_profile.get_max_actions_per_turn()
		# boss_actions_done removed — using successful_actions + total_attempts
		var boss_fail_streak: int = 0
		var successful_actions: int = 0
		var total_attempts: int = 0
		var excluded_fingerprints: Dictionary = {}
		const BOSS_MAX_TOTAL_ATTEMPTS: int = 20
		const BOSS_FAIL_LIMIT: int = 3
		while successful_actions < boss_max_actions and total_attempts < BOSS_MAX_TOTAL_ATTEMPTS:
			var snap: Dictionary = battle.get_boss_tactical_ai_snapshot()
			if int(snap.get("current_points", 0)) <= 0:
				break
			if snap.get("candidates", []).is_empty():
				break
			var choice: Dictionary = battle.choose_boss_tactical_action(27, excluded_fingerprints)
			var cmd: String = str(choice.get("command_id", "pass"))
			if cmd == "pass":
				break
			if action_feed:
				var ccost: int = int(choice.get("authoritative_cost", 0))
				var tcell = choice.get("target_cell", choice.get("target_runtime_id", 0))
				action_feed.push_message("Boss %s → %s | -%d" % [cmd, str(tcell), ccost], Color(1, 0.55, 0.2), "", 1.2)
			await _before_boss_tactical_candidate(choice)
			if battle_ended or not is_inside_tree():
				return
			var exec_result: Dictionary = battle.execute_boss_tactical_candidate(choice)
			if battle.reaction_trial != null:
				battle.reaction_trial.finish_event()
			# failure does NOT increment successful_actions (Phase 27F-R1-R2)
			if not bool(exec_result.get("ok", false)):
				total_attempts += 1
				boss_fail_streak += 1
				if battle.has_method("get_boss_tactical_candidate_fingerprint"):
					excluded_fingerprints[battle.get_boss_tactical_candidate_fingerprint(choice)] = true
				if action_feed:
					action_feed.push_message("Boss 行动失败: %s" % exec_result.get("reason_code", "unknown"), Color(0.8, 0.3, 0.3), "", 1.5)
				if boss_fail_streak >= BOSS_FAIL_LIMIT:
					break
				continue
			total_attempts += 1
			successful_actions += 1
			boss_fail_streak = 0
			if action_feed:
				var ecost: int = int(exec_result.get("cost", 0))
				var detail: String = str(exec_result.get("message", exec_result.get("reason_code", "")))
				action_feed.push_message("→ %s (-%d)" % [detail, ecost], Color(0.5, 0.8, 0.5), "", 1.5)
			if _playtest:
				_playtest.record_boss_vanguard_action(&"tactical")
			# Phase 27F-R1-R2A: unified action presentation via _present_boss_tactical_action
			await _present_boss_tactical_action(choice, exec_result)
			if battle_ended:
				break
		if battle and battle.has_method("close_command_economy_turn"):
			battle.close_command_economy_turn("boss")


	# Phase 8B: Boss 鐞涘苯濮╅崥搴″煕閺傛壆澧濆?+ 闂呮劘妫岄幇蹇撓禈閸?
	_refresh_tables()
	_hide_boss_intent_after_execute()

	# 缂佺喕顓搁悳鈺侇啀閺堚偓婢堆冨礋濞嗏€冲綀娴?
	var hp_lost: int = player_hp_before - context.player.hp
	if hp_lost > 0:
		context.award_boss_turn_core_damage_comeback(hp_lost)
	if hp_lost > _stat_player_max_hp_lost:
		_stat_player_max_hp_lost = hp_lost

	# 閻溾晛顔嶉崣妤€鍤捄鍐茬摟
	if hp_lost > 0 and player_table:
		_show_damage_number(hp_lost, player_table, false)

	# [Fixed]
	if player_table and player_table.has_method("flash_hit"):
		player_table.flash_hit()
	var am_ph = _am()
	if am_ph: am_ph.play_player_hit()

	check_battle_end()

	if battle_ended:
		return

	# Phase D2: Boss deadlines resolve after all Boss actions/cleanup and before
	# the next player turn is established.
	if battle and battle.has_method("resolve_foundation_turn_end"):
		var _boss_foundation_end: Dictionary = battle.resolve_foundation_turn_end(&"boss")

	# 閺傛澘娲栭崥?
	# Phase 25D-R1: the new player turn must clear per-turn combat state.
	_clear_this_turn()
	_start_player_turn_rules()
	_refresh_command_economy_hud()
	# Phase 11A: Playtest snapshot
	if _playtest:
		_playtest.record_turn_snapshot("player", context, battle)
	_announce_major_event("YOUR TURN", TC.TEXT_PRIMARY, 0.8)
	context.player.draw(_get_player_turn_draw_count())
	# 閻溾晛顔嶉崶鐐叉値閿涙碍妯夌粈铏圭波閺夌喎娲栭崥鍫熷瘻闁?
	# Phase 27D-R5-R2-R: only show fallback button if new control is absent
	if _end_turn_control and is_instance_valid(_end_turn_control):
		_end_turn_control.visible = true
		_end_turn_control.set_busy(false, "")
		_end_turn_control.refresh()
	elif _end_turn_btn:
		_end_turn_btn.visible = true
		_end_turn_btn.disabled = false
		_end_turn_btn.mouse_filter = Control.MOUSE_FILTER_STOP  # Phase 27D-R5-R2-R: emergency fallback only
	# 闁插秶鐤?Boss 閸欏秴绨茬拋鈩冩殶 + 闂冭埖顔屾潻鍊熼嚋
	if boss_deck and boss_deck.has_method("reset_turn"):
		boss_deck.reset_turn()
	_refresh_tables()


## Phase 27F-R1-R2A: unified Boss action presentation + deferred destruction.
func _before_boss_tactical_candidate(_candidate: Dictionary) -> void:
	pass


func _present_boss_tactical_action(action_choice: Dictionary, action_result: Dictionary) -> void:
	var action_cmd: String = str(action_choice.get("command_id", ""))
	var is_attack: bool = action_cmd == "attack" or action_cmd == "attack_core"

	if is_attack:
		var attack_facts := action_result.duplicate(true)
		attack_facts["status"] = &"committed" if bool(action_result.get("ok", false)) else &"rejected"
		attack_facts["boss_action"] = true
		await _play_monster_presentation(&"attack", attack_facts)
	else:
		var target_cell: Variant = action_choice.get("target_cell", Vector2i(-1, -1))
		if target_cell is Vector2i and target_cell != Vector2i(-1, -1):
			if _tactical_presenter and _tactical_presenter.has_method("play_cell_confirm"):
				_tactical_presenter.play_cell_confirm(target_cell)
		await get_tree().create_timer(0.15).timeout

	if is_attack and battle and battle.has_method("_apply_deferred_destruction"):
		battle._apply_deferred_destruction(action_result)

	_refresh_tables()
	check_battle_end()
	if battle_ended:
		return

	var step_delay: float = 0.28
	if battle and battle.boss_tactical_ai_profile and battle.boss_tactical_ai_profile.has_method("get_action_step_delay"):
		step_delay = battle.boss_tactical_ai_profile.get_action_step_delay()
	await get_tree().create_timer(step_delay).timeout


# ============================================================
# 鐟欏鍟嬮崶鐐剁殶
# ============================================================

# ============================================================
# Chain 鐎瑰本鍨氶崶鐐剁殶
# ============================================================
## Boss 閹板繐娴橀弴瀛樻煀閸ョ偠鐨熼敍姘纯閺傜増鍓伴崶鎯у幢 + ActionFeed + 妤傛ê宓勯梻顏勭潌
func _on_boss_intent_updated(card: CardData, danger: String) -> void:
	if card == null:
		return

	# 閺囧瓨鏌婃稉顓炪亷 Boss 閹板繐娴橀崡鈽呯礄CardUI 閸楃姳缍呭鍡礆
	_update_boss_intent_card()
	# 缁犫偓閻?danger 鐠囧稄绱欐稉顓炵妇鎼存洟鍎寸亸蹇撶摟閿?
	if boss_intent_label:
		boss_intent_label.text = _boss_danger_label(danger)
		boss_intent_label.add_theme_color_override("font_color", _boss_danger_color(danger))
	if action_feed:
		action_feed.push_message("Boss Intent: %s" % card.card_name, _boss_danger_color(danger))
	if danger == "HIGH" and fx:
		fx.flash(Color(TC.ZONE_OVERDRIVE.r, TC.ZONE_OVERDRIVE.g, TC.ZONE_OVERDRIVE.b, 0.2), 0.3)
		# Phase 10G: BossCore 閹板繐娴樼悰灞藉З pulse
		_play_boss_action_vfx("intent")
		var am_intent = _am(); if am_intent: am_intent.play_boss_intent()
		if danger == "HIGH" or danger == "OVERDRIVE":
			_play_boss_action_vfx("overdrive")
		var am_baction = _am(); if am_baction: am_baction.play_boss_action()

	# Phase 24A: idempotent HUD refresh after intent update
	if _boss_status_hud and is_instance_valid(_boss_status_hud):
		_boss_status_hud.refresh_from_enemy()

# Boss Reaction trigger callback
func _on_boss_reaction_triggered(card: CardData, shield_amount: int) -> void:
	if boss_reaction_fx:
		boss_reaction_fx.trigger_reaction(card, _get_boss_screen_pos(), shield_amount)
	if action_feed:
		action_feed.push_message("Boss Replace: %s -> Shield+%d, Load+1 -> GY" % [card.card_name, shield_amount], TC.ZONE_HEATED)
## Phase 4C-2: Boss 閸氬骸婧€鐠佹儳宕遍柅姘辩叀
func _on_boss_back_row_set(card_name: String) -> void:
	if action_feed:
		action_feed.push_message("Boss Discard: %s -> GY" % card_name, TC.ZONE_HEATED)

# ============================================================

# Boss 閹板繐娴橀崡鈽呯礄閹镐椒绠欓崠?CardUI閿涘本娴涢幑銏㈠嚱閺傚洤鐡ч弽鍥╊劮閿?

# ============================================================

## 缁犫偓閻?danger 閺嶅洨顒烽弬鍥х摟

func _boss_danger_label(danger: String) -> String:

	match danger:

		pass  # fixed garbled code

		"MID":   return "升温"

		"HIGH":  return "!! 过载预警 !!"

	return ""

## danger 鐎电懓绨叉０婊嗗

func _boss_danger_color(danger: String) -> Color:

	match danger:

		"LOW":   return TC.ZONE_CALM

		"MID":   return TC.ZONE_HEATED

		"HIGH":  return TC.ZONE_OVERDRIVE

	return TC.TEXT_PRIMARY

## 閸掓稑缂?閺囧瓨鏌?Boss 閹板繐娴橀崡?閹镐椒绠欓崠?CardUI)

func _update_boss_intent_card() -> void:
	if not boss_intent_slot:
		return

	# 濡偓閺屻儲妲搁崥锔芥箒閹板繐娴橀崡?
	var has_method_check: bool = false
	var has_intent_result: bool = false

	if boss_deck != null:
		has_method_check = boss_deck.has_method("has_intent")
		if has_method_check:
			has_intent_result = boss_deck.has_intent()

	var has_card: bool = has_method_check and has_intent_result

	if not has_card:
		if boss_intent_card and is_instance_valid(boss_intent_card):
			boss_intent_card.visible = false
		return

	var card: CardData = boss_deck.current_intent

	if card == null:
		return


	# 妫ｆ牗顐奸崚娑樼紦
	if not boss_intent_card or not is_instance_valid(boss_intent_card):
		boss_intent_card = CardUIScene.instantiate()
		boss_intent_card.name = "BossIntentCard"
		boss_intent_card.set_anchors_preset(Control.PRESET_CENTER)
		boss_intent_card.z_index = ZI_BOSS_INTENT  # 50
		boss_intent_slot.add_child(boss_intent_card)

	# 閺囧瓨鏌婇崡锟犳桨(Boss 閸椔ゅ殰閸?furnace-red 闁板秷澹?
	boss_intent_card.setup_boss_intent(card)
	boss_intent_card.visible = true
	# Phase 8B: 閸楅亶娅撻懘澶婂暱
	_kill_boss_intent_tween()
	if context and context.enemy:
		var dg := context.enemy.intent_danger
		var pc := _boss_pulse_color(dg)
		_boss_intent_tween = create_tween()
		_boss_intent_tween.set_loops(2)
		_boss_intent_tween.tween_property(boss_intent_card, "modulate", pc, 0.35).set_trans(Tween.TRANS_SINE)
		_boss_intent_tween.tween_property(boss_intent_card, "modulate", Color(1,1,1,1), 0.35).set_trans(Tween.TRANS_SINE)

# ============================================================

# OD / Phase 閸欘垵顫嗛幐鍥┿仛閸?

# ============================================================

## Boss OD 鐡掑懘鈹嶆０鍕劅閿涘牃澧? 閺冩儼袝閸欐垳绔村▎鈽呯礆

func _show_boss_od_warning(_target_od: int) -> void:
	if action_feed:
		action_feed.push_message("Boss 即将过载：留意下次行动", TC.ZONE_HEATED, "", 1.5)

## Phase Lock 閸欘垵顫嗛幓鎰仛

func _show_phase_lock_indicator(locked_count: int) -> void:

	var pos := card_board_position + Vector2(0, -80)

	_show_indicator("阶段锁定 x%d" % locked_count, TC.ZONE_HEATED, pos, 22, 1.8)

## Overflow 閳?Boss OD 閹绘劗銇?
## _boss_od_phase_check
func _boss_od_phase_check() -> void:
	if not context or not context.enemy:
		return
	var bod: int = context.enemy.od
	if bod < 7:
		_boss_od_warn_7 = false
		return
	if _boss_od_warn_7:
		return
	_boss_od_warn_7 = true
	# Overdrive itself is announced once by the existing zone-transition handler.
	if bod < 8:
		_show_boss_od_warning(bod)

## Phase 27F-R1-R2: dedup Overdrive announcements across all channels.
func _should_announce_boss_overdrive(new_zone: String) -> bool:
	if new_zone != "Overdrive":
		_boss_overdrive_announced = false
		return false
	if _boss_overdrive_announced:
		return false
	_boss_overdrive_announced = true
	return true

func _show_overflow_indicator(gain: int) -> void:

	if not enemy_table:

		return

	var pos := enemy_table.global_position + Vector2(enemy_table.size.x / 2, 10)

	_show_indicator("Overflow -> Boss OD +%d" % gain, TC.ZONE_HEATED, pos, 18, 1.5)

## 闁氨鏁ら幐鍥┿仛閸ｎ煉绱伴幐鍥х暰娴ｅ秶鐤嗗ù顔肩摟閿涘矁鍤滈崝銊﹁窗閸戠儤绉锋径?

func _show_indicator(text: String, color: Color, pos: Vector2, font_size: int, duration: float) -> void:

	var label := Label.new()

	label.text = text

	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	label.add_theme_font_size_override("font_size", font_size)

	label.add_theme_color_override("font_color", color)

	# Phase 27D-R5-R2-R2: safe positioning — avoid reserved UI rects
	var est_w: float = max(font_size * text.length() * 0.55 + 16, 240)
	var est_h: float = font_size * 1.5
	var preferred: Vector2 = pos - Vector2(120, 0)
	var safe_pos: Vector2 = _get_safe_notification_position(Vector2(est_w, est_h), preferred)
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.global_position = safe_pos
	label.custom_minimum_size = Vector2(240, 0)

	label.modulate.a = 0.0

	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(label)

	var t := create_tween()

	t.set_parallel(true)

	t.tween_property(label, "modulate:a", 1.0, 0.15)

	t.tween_property(label, "position:y", label.position.y - 35, duration)

	t.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(duration - 0.3)

	t.tween_callback(label.queue_free).set_delay(duration)

func _on_chain_completed(route_id: String, route_name: String, reward: String) -> void:
	print("[BATTLE FX] Chain Complete: %s - %s" % [route_name, reward])
	# Phase 11A: Telemetry
	if _playtest:
		_playtest.record_event("route_completed", {"route": route_id})

	# Phase 4C-5: 闂冨弶顒涢柌宥咁槻妫板棗顨涢敍鍫濇倱娑撯偓鐠侯垳鍤庡В蹇撶湰閸欘亪顣稉鈧▎鈽呯礆
	if _chain_reward_granted_routes.get(route_id, false):
		print("[CHAIN] Route %s already rewarded this battle - skip" % route_name)
		return
	_chain_reward_granted_routes[route_id] = true

	# 閸忋劌鐫嗛梻顏囧閿涘牊瀵滅捄顖滃殠妫版粏澹婇敍灞煎▏閻劎绮烘稉鈧懝鍙夋緲閿?
	var route_color := TC.ACCENT_GOLD  # 姒涙顓婚柌鎴ｅ
	match route_id:
		"heat_route":
			route_color = Color(TC.ZONE_HEATED.r, TC.ZONE_HEATED.g, TC.ZONE_HEATED.b, 0.5)
		"overdrive_route":
			route_color = Color(TC.ZONE_OVERDRIVE.r, TC.ZONE_OVERDRIVE.g, TC.ZONE_OVERDRIVE.b, 0.5)
		"control_route":
			route_color = Color(TC.ZONE_CALM.r, TC.ZONE_CALM.g, TC.ZONE_CALM.b, 0.5)

	if fx and fx.has_method("flash"):
		fx.flash(route_color, 0.5)
	if fx and fx.has_method("shake"):
		fx.shake(20, 0.4)

	var finisher_name := ""
	match route_id:
		"heat_route": finisher_name = "Final Slash"
		"control_route": finisher_name = "Chain Breaker"
		"overdrive_route": finisher_name = "Overdrive Eruption"

	# Phase 4C-5: ThisTurnPanel 鐠佹澘缍嶇€瑰本鏆ｇ€瑰本鍨氭穱鈩冧紖
	_add_to_this_turn("Route Complete: %s" % route_name, TC.ACCENT_GOLD)
	_add_to_this_turn("Reward: " + reward, route_color)
	if finisher_name != "":
		_add_to_this_turn("Finisher Ready: %s" % finisher_name, TC.ACCENT_GOLD)

	if action_feed:
		action_feed.push_message("Chain: %s - %s" % [route_name, reward], route_color)
		if finisher_name != "":
			action_feed.push_message("FINISHER READY: %s" % finisher_name, TC.ACCENT_GOLD)

	# Phase 4C-5: 娑擃厼銇庨惌顓熷絹缁€鐚寸礄0.6s 娑撳秹浼勯幐鈽呯礆
	if finisher_name != "":
		_announce_major_event("CHAIN COMPLETE!", TC.ACCENT_GOLD, 0.6)

	# [Fixed]
	if player_table:
		if player_table.has_method("pulse_chain_stepper"):
			player_table.pulse_chain_stepper()
		if player_table.has_method("pulse_od_core"):
			player_table.pulse_od_core()

	# 瀵洖顕?	_trigger_guides_chain_done()

	# 缂佺喕顓?	_stat_chain_completed += 1

	# Chain 鐎瑰本鍨氶棅铏櫏
	var am_c = _am()
	if am_c: am_c.play_sfx("chain_complete")
## Chain Route 濮濄儵顎冮幒銊ㄧ箻閸欏秹顩敍鍦ase 4C-5: 婢х偛宸辩捄顖滃殠濞撳懏娅氭惔锔肩礆
func _on_chain_step(route_id: String, route_name: String, step: int, total: int) -> void:
	var route_color := TC.route_color(route_id)
	_pulse_center_line(route_color)

	# 閳光偓閳光偓 Phase 4C-5: 閼惧嘲褰囨稉瀣╃濮濄儲褰佺粈鍝勬嫲婵傛牕濮抽弬鍥ㄦ拱 閳光偓閳光偓
	var next_text := ""
	var reward_text := ""
	if context.chain_system:
		var cs := context.chain_system
		var nc: Array[String] = cs.get_next_cards()
		next_text = ", ".join(nc)
		var def: Dictionary = cs.route_definitions.get(route_id, {})
		reward_text = def.get("combo_reward", "")

	# 閳光偓閳光偓 Step 1: Route Started 閳光偓閳光偓
	if step == 1:
		if action_feed:
			action_feed.push_message("Route Started: %s" % route_name, route_color)
		if reward_text != "":
			_add_to_this_turn("Reward: " + reward_text, TC.ACCENT_GOLD)

	# 閳光偓閳光偓 瑜版挸澧犳潻娑樺 閳光偓閳光偓
	var msg := "%s  %d/%d" % [route_name, step, total]
	_add_to_this_turn("Route: " + msg, route_color)

	# 閳光偓閳光偓 娑撳绔村銉﹀絹缁€?閳光偓閳光偓
	if step < total and next_text != "":
		if action_feed:
			action_feed.push_message("Next: %s" % next_text, route_color, "", 3.0)
		_add_to_this_turn("Next: " + next_text, route_color.lightened(0.3))
	elif step >= total:
		if action_feed:
			action_feed.push_message("Route Complete: %s" % route_name, TC.ACCENT_GOLD)

	# 鐏忓繐鐎烽梻顏勫帨
	if fx and fx.has_method("flash"):
		fx.flash(Color(route_color.r, route_color.g, route_color.b, 0.2), 0.2)

	# Chain 濮濄儵顎冮棅铏櫏
	var am = _am()
	if am: am.play_sfx("chain_step")

	# 瀵洖顕?	_trigger_guides_chain_step()

	# 閻溾晛顔嶉悧灞绢攽 Chain 濮濄儴绻橀崳銊ㄥ墻閸?
	if player_table and player_table.has_method("pulse_chain_stepper"):
		player_table.pulse_chain_stepper()

# ============================================================
# OD Depth / Abyss Pressure 閸ョ偠鐨?閳?Phase 3B-1
# ============================================================
func _on_depth_changed(new_depth: int, depth_zone: String) -> void:
	_refresh_od_companion_backline()
	var depth_delta := new_depth - _prev_depth
	# [Fixed]
	if _prev_depth != 0 and depth_delta != 0:
		if depth_delta < 0:
			# Depth 娑撳妾?閳?閸欘垵鍏橀弰?Control 閸椻剝浠径?
			if action_feed:
				action_feed.push_message("Recovery: Depth %d -> %d [%s]" % [_prev_depth, new_depth, depth_zone], TC.ROLE_CONTROL)
			_add_to_this_turn("Depth %d [%s]" % [new_depth, depth_zone], TC.ROLE_CONTROL)
			if player_table and player_table.has_method("show_depth_delta"):
				player_table.show_depth_delta(depth_delta)
		else:
			if action_feed:
				action_feed.push_message("Depth: %d [%s]" % [new_depth, depth_zone], TC.WARNING)
			_add_to_this_turn("Depth %d [%s]" % [new_depth, depth_zone], TC.WARNING)
			if player_table and player_table.has_method("show_depth_delta"):
				player_table.show_depth_delta(depth_delta)
	elif _prev_depth == 0:
		if action_feed:
			_add_to_this_turn("Depth %d [%s]" % [new_depth, depth_zone], TC.WARNING)
		if player_table and player_table.has_method("show_depth_delta"):
			player_table.show_depth_delta(depth_delta)
	_prev_depth = new_depth
	if player_table and player_table.has_method("set_depth"):
		player_table.set_depth(new_depth, depth_zone)
	_update_core_status_panel()

func _on_abyss_shock_triggered(depth: int) -> void:
	# Depth reaching its cap is a combat state change, not just a small HUD value.
	_announce_major_event("ABYSS LOCK  %d/%d" % [depth, context.get_depth_max_value()], TC.ZONE_OVERDRIVE, 1.1)
	if fx and fx.has_method("flash"):
		fx.flash(Color(0.55, 0.1, 0.8, 0.45))
	if fx and fx.has_method("shake"):
		fx.shake(12)
	# Phase 11A: Telemetry
	if _playtest:
		_playtest.record_event("backlash_triggered", {})
	if action_feed:
		action_feed.push_message("ABYSS LOCK: only CONTROL cards (Cooldown, Heat Sink, etc.)", TC.ZONE_OVERDRIVE, "", 3.5)
	if _this_turn_labels.size() > 0:
		_add_to_this_turn("Abyss Lock: only CONTROL", TC.ZONE_OVERDRIVE)
		_add_to_this_turn("Recovery: Use Cooldown / Heat Sink", TC.ROLE_CONTROL)
	# Phase 4C-4B: Abyss Lock 鐟欏棜顫庨幐鍥┿仛
	if player_table and player_table.has_method("_set_abyss_lock_visual"):
		player_table._set_abyss_lock_visual(true)

func _on_boss_field_full(zone_type: String, card_name: String) -> void:
	if action_feed:
		var zone_cn := "前排" if zone_type == "front" else "后排"
		action_feed.push_message("Boss %s Full - %s -> Gain OD+Shield" % [zone_cn, card_name], TC.WARNING)
	var table := enemy_table if enemy_table else player_table
	if table and table.has_method("flash_zone_full"):
		table.flash_zone_full(zone_type)

## _on_boss_instant_card_played
func _on_boss_instant_card_played(card) -> void:
	if card == null:
		return

	# Phase 10G: BossCore INSTANT 鐞涘苯濮?pulse
	_play_boss_action_vfx("instant")
	var am = _am(); if am: am.play_boss_action()
	await _play_boss_instant_card_visual(card)
	# Phase 11A: Telemetry
	if _playtest:
		_playtest.record_event("boss_card_played", {"card": card.card_name})
func _play_boss_instant_card_visual(card) -> void:
	var action_slot: Control = null
	if enemy_table and enemy_table.has_method("get_action_slot"):
		action_slot = enemy_table.get_action_slot()
	if not action_slot or not is_instance_valid(action_slot):
		# Fallback: ActionFeed only
		if action_feed:
			action_feed.push_message("Boss: %s -> GY" % card.card_name, TC.ZONE_HEATED)
		return

	# 閸掓稑缂撴稉瀛樻 CardUI
	var card_ui := CardUIScene.instantiate()
	card_ui.name = "BossInstantCard"
	card_ui.setup_boss_intent(card)
	card_ui.set_display_mode(CardUI.CardDisplayMode.FEED)
	card_ui.set_anchors_preset(Control.PRESET_CENTER)
	card_ui.z_index = ZI_BOSS_INTENT
	card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_slot.visible = true
	action_slot.add_child(card_ui)

	var tp := create_tween()
	tp.set_parallel(true)
	tp.tween_property(card_ui, "modulate", Color(1.4, 0.7, 0.5, 1), 0.06)
	tp.tween_property(card_ui, "scale", Vector2(1.15, 1.15), 0.06)
	var tp2 := create_tween()
	tp2.tween_property(card_ui, "modulate", Color(1, 1, 1, 1), 0.18)
	tp2.tween_property(card_ui, "scale", Vector2(1.0, 1.0), 0.18)
	await get_tree().create_timer(0.5).timeout

	if not is_instance_valid(card_ui):
		if is_instance_valid(action_slot):
			action_slot.visible = false
		return

	# 濞撴劕鍤崚?Boss GY
	var gy_pos := card_board_position
	if enemy_table and enemy_table.has_method("get_zone_global_center"):
		gy_pos = enemy_table.get_zone_global_center("graveyard")
	var tf := create_tween()
	tf.set_parallel(true)
	tf.tween_property(card_ui, "global_position", gy_pos, 0.28)
	tf.tween_property(card_ui, "modulate:a", 0.0, 0.25)
	tf.tween_property(card_ui, "scale", Vector2(0.5, 0.5), 0.25)
	await tf.finished
	if is_instance_valid(card_ui):
		card_ui.queue_free()
	if is_instance_valid(action_slot):
		action_slot.visible = false
func _on_boss_instant_played(card_name: String) -> void:
	if action_feed:
		action_feed.push_message("Boss Deploy: %s -> GY" % card_name, TC.ZONE_HEATED)

## Phase 4C-4: 闁氨鏁?Boss 鐞涘苯濮╂禍瀣╂ ActionFeed
func _on_boss_action_event(action_type: String, card_name: String, detail: String) -> void:
	if not action_feed:
		return
	match action_type:
		"guard":
			action_feed.push_message("Boss Guard: %s (%s)" % [card_name, detail], TC.ZONE_CALM)
		"instant":
			action_feed.push_message("Boss Instant: %s -> %s" % [card_name, detail], TC.ZONE_HEATED)
		_:
			action_feed.push_message("Boss %s: %s" % [action_type, card_name], TC.TEXT_SECONDARY)

# ============================================================
# Finisher 瀹割喖绱撻崠鏍ㄧ川閸?
# ============================================================
func _play_finisher_fx(card: CardData) -> void:
	if not fx:
		return

	# 濞搭喖鐡ч弰鍓с仛 Finisher 閸椻€虫倳
	var flash_color := TC.ACCENT_GOLD
	var shake_str := 22.0
	var shake_dur := 0.35
	var font_sz := 40

	match card.card_name:
		"Final Slash":
			flash_color = Color(TC.ACCENT_GOLD.r, TC.ACCENT_GOLD.g, TC.ACCENT_GOLD.b, 0.6)
			shake_str = 22.0
			shake_dur = 0.35
		"Chain Breaker":
			flash_color = Color(TC.ZONE_CALM.r, TC.ZONE_CALM.g, TC.ZONE_CALM.b, 0.5)
			shake_str = 18.0
			shake_dur = 0.3
		"Overdrive Eruption":
			flash_color = Color(TC.ZONE_HEATED.r, TC.ZONE_HEATED.g, TC.ZONE_HEATED.b, 0.55)
			shake_str = 20.0
			shake_dur = 0.3
		"Overdrive Eruption":
			flash_color = Color(TC.ZONE_OVERDRIVE.r, TC.ZONE_OVERDRIVE.g, TC.ZONE_OVERDRIVE.b, 0.7)
			shake_str = 28.0
			shake_dur = 0.5
			font_sz = 48

	# 濞搭喖鐡?	_show_floating_text(card.card_name, flash_color, 2.0, font_sz)

	# [Fixed]
	if fx.has_method("flash"):
		fx.flash(flash_color, shake_dur)
	if fx.has_method("shake") and not _is_reduced_motion_presentation():
		fx.shake(shake_str, shake_dur)

	# Finisher 缂佺喕顓?	_stat_released_finisher = true

	var am_f = _am()
	if am_f: am_f.play_sfx("finisher")

func _on_awakening_triggered() -> void:
	print("AWAKENING TRIGGERED!")
	_announce_major_event("AWAKEN!", TC.ACCENT_GOLD, 1.0)
	if fx and fx.has_method("flash"):
		fx.flash(Color(1, 0.7, 0.2, 0.6))
	if fx and fx.has_method("shake"):
		fx.shake(20)

# Phase 5B-2: P19 閻愬绺鹃崷锝呯垶閸斻劍鈧礁鍘滈悳?
func _on_od_zone_changed_for_building(_new_zone: int, _old_zone: int) -> void:
	if battle and battle.has_method("apply_cathedral_overdrive_aura"):
		battle.apply_cathedral_overdrive_aura()

func _on_od_changed(_new_od: int, _new_phase: int, _zone: int) -> void:
	_update_core_status_panel()
	_refresh_od_companion_backline()
	# [Fixed]
	if turn_info_label:
		var t := create_tween()
		t.tween_property(turn_info_label, "modulate", Color(1.5, 1.5, 1.5, 1), 0.06)
		t.tween_property(turn_info_label, "modulate", Color(1, 1, 1, 1), 0.06)

func _on_stable_combat_od_awarded(result: Dictionary) -> void:
	var amount: int = int(result.get("applied", 0))
	if amount <= 0:
		return
	var source: StringName = StringName(result.get("source", ""))
	var message := "Combat charge: OD +%d" % amount
	match source:
		&"unit_damage":
			message = "Combat contact: OD +%d" % amount
		&"enemy_destroyed":
			message = "Enemy destroyed: OD +%d" % amount
		&"boss_core_damage_comeback":
			message = "Core recovery: OD +%d" % amount
	if action_feed:
		action_feed.push_message(message, TC.ZONE_HEATED, "", 2.0)
	_add_to_this_turn(message, TC.ZONE_HEATED)

## 閻溾晛顔?OD Zone 閸掑洦宕查崣宥夘洯閿涘牅绮?zone 閸欐ê瀵查弮鎯靶曢崣鎴礆
func _on_player_zone_changed(new_zone: int, _old_zone: int) -> void:
	match new_zone:
		ODMode.Zone.HEATED:
			if action_feed:
				action_feed.push_message("OD: Heat Up", TC.ZONE_HEATED)
			_pulse_center_line(TC.ZONE_HEATED)
			_show_toast("first_heated", "OD Heated: Card effects up", TC.ZONE_HEATED)
			_trigger_guides_on_heated()
			if fx:
				fx.flash(Color(TC.ZONE_HEATED.r, TC.ZONE_HEATED.g, TC.ZONE_HEATED.b, 0.25), 0.3)
				fx.shake(5, 0.18)
			var am1 = _am()
			if am1: am1.play_sfx("enter_heated")
		ODMode.Zone.OVERDRIVE:
			_stat_entered_overdrive = true
			if action_feed:
				action_feed.push_message("OD: Cool Down", TC.ZONE_OVERDRIVE)
			_pulse_center_line(TC.ZONE_OVERDRIVE)
			_flash_boss_zone(TC.ZONE_OVERDRIVE)
			_show_toast("first_overdrive", "Overdrive: damage boosted, risk increased", TC.ZONE_OVERDRIVE)
			_trigger_guides_on_overdrive()
			if fx:
				fx.flash(Color(TC.ZONE_OVERDRIVE.r, TC.ZONE_OVERDRIVE.g, TC.ZONE_OVERDRIVE.b, 0.4), 0.4)
				fx.shake(12, 0.25)
			var am2 = _am()
			if am2: am2.play_sfx("enter_overdrive")
		ODMode.Zone.CALM:
			if fx:
				fx.flash(Color(TC.ZONE_CALM.r, TC.ZONE_CALM.g, TC.ZONE_CALM.b, 0.15), 0.2)

# ============================================================
# Boss Zone 閸欐ê瀵查崶鐐剁殶
# ============================================================

# ============================================================
# Boss Zone 閸欐ê瀵查崶鐐剁殶 閳?婢х偛宸遍崣宥夘洯
# ============================================================
func _on_boss_zone_changed(old_zone: String, new_zone: String) -> void:
	print("[BATTLE] Boss zone: %s -> %s" % [old_zone, new_zone])
	var is_new_overdrive: bool = _should_announce_boss_overdrive(new_zone)
	# Phase 10G: Boss zone change VFX
	if new_zone == "Overdrive" and is_new_overdrive and not _is_reduced_motion_presentation():
		_play_boss_action_vfx("overdrive")
	elif new_zone == "Heated" and not _is_reduced_motion_presentation():
		_play_boss_action_vfx("front")

	match new_zone:
		"Heated":
			# 濮楁瑨澹婃０鍕劅
			if turn_info_label:
				turn_info_label.text = "FORGE DOMAIN ACTIVE"
				turn_info_label.add_theme_color_override("font_color", TC.ZONE_HEATED)
			_show_toast("boss_heated", "熔炉领域激活：Boss 受到的伤害减少 1", TC.ZONE_HEATED)
			_trigger_guides_boss_danger()
			if not _is_reduced_motion_presentation() and fx and fx.has_method("boss_zone_heated"):
				fx.boss_zone_heated()
			if not _is_reduced_motion_presentation() and fx and fx.has_method("flash"):
				fx.flash(Color(TC.ZONE_HEATED.r, TC.ZONE_HEATED.g, TC.ZONE_HEATED.b, 0.35), 0.3)
			print("[BOSS WARNING] Boss is heating up - Overdrive approaching!")

		"Overdrive":
			# Phase 27F-R1-R2A: one state-machine guard protects every
			# Overdrive announcement, visual effect, and warning sound.
			if is_new_overdrive:
				_stat_boss_overdrive_count += 1
				_announce_major_event("!! BOSS OVERDRIVE !!", TC.ZONE_OVERDRIVE, 1.0)
				_show_toast("boss_overdrive", "Boss Overdrive: Heavy damage!", TC.ZONE_OVERDRIVE)
				if not _is_reduced_motion_presentation() and fx and fx.has_method("boss_zone_overdrive"):
					fx.boss_zone_overdrive()
				if not _is_reduced_motion_presentation() and fx and fx.has_method("flash"):
					fx.flash(Color(TC.ZONE_OVERDRIVE.r, TC.ZONE_OVERDRIVE.g, TC.ZONE_OVERDRIVE.b, 0.5), 0.5)
				if not _is_reduced_motion_presentation() and fx and fx.has_method("shake"):
					fx.shake(18, 0.35)
				var am_bw = _am()
				if am_bw:
					am_bw.play_sfx("boss_warning")

		"Calm":
			# 閽冩繆澹婄€瑰鍙?閳?濡偓濞村妲搁崥锔跨矤Overdrive鐞氼偅澧﹂弬?
			if old_zone == "Overdrive":
				_show_toast("boss_interrupt_" + str(context.turn_count), "Boss Interrupted - Cooling", TC.ZONE_CALM, 2.0)
				_stat_boss_interrupted += 1
			if turn_info_label:
				turn_info_label.text = "Boss cooling down..."
				turn_info_label.add_theme_color_override("font_color", TC.ZONE_CALM)
			if not _is_reduced_motion_presentation() and fx and fx.has_method("flash"):
				fx.flash(Color(TC.ZONE_CALM.r, TC.ZONE_CALM.g, TC.ZONE_CALM.b, 0.2), 0.2)
			print("[BOSS] Returned to Calm; safe for now")

func check_battle_end() -> void:
	if battle_ended:
		return

	if not is_instance_valid(context.player) or not is_instance_valid(context.enemy):
		return

	if context.player.is_dead():
		_end_battle(false)
	elif context.enemy.is_dead():
		_end_battle(true)

func _end_battle(victory: bool) -> void:
	if battle and battle.has_method("clear_boss_siege_intent"):
		battle.clear_boss_siege_intent(&"battle_end")
		battle.clear_boss_terrain_intent(&"battle_end")
	_clear_siege_presentation(&"battle_end")
	_cleanup_structure_presentation_lifecycle(&"battle_end")
	_cancel_monster_summon_interaction(&"battle_end")
	_clear_garrison_selection(&"battle_end")
	_clear_od_release_selection(&"battle_end")
	if _battle_presentation_director != null and is_instance_valid(_battle_presentation_director):
		_battle_presentation_director.cancel_all(&"battle_end")
	# Phase 27K-R0: 战斗结束停止灰盒常驻 Tween
	if _od_engine_greybox and is_instance_valid(_od_engine_greybox) and _od_engine_greybox.has_method("stop_idle_animations"):
		_od_engine_greybox.stop_idle_animations()
	if _end_turn_control and is_instance_valid(_end_turn_control):
		_end_turn_control.visible = false
	if _end_turn_btn:
		_end_turn_btn.visible = false
		_end_turn_btn.disabled = true
		_end_turn_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Phase 27D-R5-R2-R
	battle_ended = true
	# Phase 26D: 清理 OD 伙伴后场表现
	if _od_backline_presenter and is_instance_valid(_od_backline_presenter):
		_od_backline_presenter.cancel_presentations()
	# Phase 23B-R2: cancel building replace on battle end
	_cancel_building_replace_selection("battle_end", false)
	# Phase 26E-R1 Task 5: cancel lane selection on battle end
	_cancel_lane_selection(&"battle_end")
	# Phase 11A: Playtest Telemetry 閳?鐠佹澘缍嶉張鈧紒鍫㈢波閺?
	if _playtest:
		_playtest.finish_run("victory" if victory else "defeat", context, battle)
	_freeze_battle()

	# 缂佹挾鐣荤拋鏉跨秿
	var gm = get_node_or_null("/root/GameManager")
	if gm and not bool(get_meta("player_trial", false)):
		if victory:
			gm.record_win()
		else:
			gm.record_loss()

	var am = _am()
	if fx:
		if victory:
			_show_floating_text("VICTORY", TC.ACCENT_GOLD, 2.5, 48)
			_animate_boss_core_dead()
			_trigger_guides_victory()
			if fx.has_method("boss_defeated"):
				fx.boss_defeated()
			fx.flash(Color(TC.ACCENT_GOLD.r, TC.ACCENT_GOLD.g, TC.ACCENT_GOLD.b, 0.5), 0.5)
			fx.shake(20, 0.4)
			if am: am.play_sfx("victory")
		else:
			_show_floating_text("DEFEAT", TC.ZONE_OVERDRIVE, 2.5, 48)
			fx.flash(Color(TC.ZONE_OVERDRIVE.r, TC.ZONE_OVERDRIVE.g, TC.ZONE_OVERDRIVE.b, 0.5), 0.4)
			fx.shake(18, 0.3)
			if am: am.play_sfx("defeat")

	# 閸?BGM
	if am: am.stop_bgm()

	# Phase 23C0: 缂佹挾鐣婚棃銏℃緲閿涘湑anvasLayer 绾喕绻氱憰鍡欐磰 3D Viewport 閸滃本澧嶉張?HUD閿?
	var result_layer := CanvasLayer.new()
	result_layer.name = "BattleResultLayer"
	result_layer.layer = 1000  # 閺堚偓妤傛ê鐪扮痪褝绱濈搾鍛扮箖閹碘偓閺?HUD (monster menu=500)
	add_child(result_layer)
	result_panel = BattleResultPanelScene.instantiate()
	result_layer.add_child(result_panel)
	var stats: Dictionary = {
		"turns": context.turn_count,
		"max_od": _stat_max_player_od,
		"overdrive": _stat_entered_overdrive,
		"finisher": _stat_released_finisher,
		"chains": _stat_chain_completed,
		"boss_od": _stat_max_boss_od,
		"combo": _stat_max_combo,
		"total_cards": _stat_total_cards,
		"max_hit": _stat_max_hit,
		"boss_max_hit": _stat_player_max_hp_lost,
		"traps": _stat_trap_triggered,
		"boss_overdrives": _stat_boss_overdrive_count,
		"boss_interrupted": _stat_boss_interrupted,
	}
	result_panel.show_result(victory, stats)
	# Phase 4C-4: Playtest 缂佺喕顓搁幗妯款洣
	print("============================================================")
	print("  BATTLE END - turns:%d  win:%s" % [context.turn_count, victory])
	print("  Max OD: player %d / boss %d" % [_stat_max_player_od, _stat_max_boss_od])
	print("  Finisher: %s  Chains: %d  Boss Overdrives: %d" % [_stat_released_finisher, _stat_chain_completed, _stat_boss_overdrive_count])
	print("============================================================")

	result_panel.return_to_menu.connect(_on_return_to_menu)
	result_panel.retry.connect(_on_retry)

func _freeze_battle() -> void:
	print("[BattleScene] Battle frozen - battle_ended = true")

func _on_return_to_menu() -> void:
	_cleanup_structure_presentation_lifecycle(&"return_to_menu")
	_cancel_monster_summon_interaction(&"return_to_menu")
	if _return_to_menu_guard:
		return
	_return_to_menu_guard = true
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("change_scene"):
		gm.change_scene("res://scenes/menu/main_menu.tscn")
	else:
		print("[BattleScene] GameManager not found, cannot return to menu.")

func _on_retry() -> void:
	_cleanup_structure_presentation_lifecycle(&"retry")
	get_tree().reload_current_scene()

func _am():
	return get_node_or_null("/root/AudioManager")

## 鐏?BossCore 3D 娴ｅ秶鐤嗛幎鏇炲閸?2D 鐏炲繐绠烽崸鎰垼
func _get_boss_screen_pos() -> Vector2:
	var vpc := get_node_or_null(NodePath("Battle3DViewport")) as SubViewportContainer
	if vpc == null:
		return card_board_position

	var rect: Rect2 = vpc.get_global_rect()

	var vp := vpc.get_node_or_null(NodePath("SubViewport")) as SubViewport
	if vp == null:
		return rect.position + Vector2(rect.size.x / 2.0, rect.size.y * 0.3)

	var core := _get_boss_core()
	if core == null:
		return rect.position + Vector2(rect.size.x / 2.0, rect.size.y * 0.3)

	var cam := _get_3d_camera()
	if cam == null:
		return rect.position + Vector2(rect.size.x / 2.0, rect.size.y * 0.3)

	var local_pos: Vector2 = cam.unproject_position(core.global_position)
	var viewport_size: Vector2 = Vector2(vp.size)
	var scale_factor: Vector2 = Vector2.ONE
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		scale_factor = rect.size / viewport_size

	return rect.position + local_pos * scale_factor

# ============================================================
# 3D/2.5D 閻楀本顢戠仦鏇犮仛鐏炲偊绱橲ubViewport 閸愬懐鈻兼惔蹇撳閺嬪嫬缂撻敍?
# ============================================================
func _sync_3d_viewport_to_table() -> void:
	var vp_container := get_node_or_null(NodePath("Battle3DViewport")) as SubViewportContainer
	if vp_container == null:
		return
	var vp := vp_container.get_node_or_null(NodePath("SubViewport")) as SubViewport
	if vp == null:
		return

	vp_container.stretch = false
	if USE_TRUE_3D_BOARD_BACKGROUND:
		var root_size: Vector2 = get_viewport_rect().size
		if root_size.x < 1.0 or root_size.y < 1.0:
			root_size = size
		if root_size.x < 1.0 or root_size.y < 1.0:
			root_size = Vector2(1600, 900)
		vp_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		vp_container.offset_left = 0.0
		vp_container.offset_top = 0.0
		vp_container.offset_right = 0.0
		vp_container.offset_bottom = 0.0
		vp.size = Vector2i(maxi(1, int(root_size.x)), maxi(1, int(root_size.y)))
	else:
		var table := get_node_or_null(NodePath("BattleTable")) as Control
		if table:
			vp_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
			vp_container.position = table.position
			vp_container.size = table.size
			vp.size = Vector2i(maxi(1, int(table.size.x)), maxi(1, int(table.size.y)))
		else:
			vp.size = Vector2i(maxi(1, int(vp_container.size.x)), maxi(1, int(vp_container.size.y)))

	vp_container.stretch = true
	vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Phase 21B: 3D viewport z_index 鐣ラ珮浜庤儗鏅絾浣庝簬鎵€鏈?UI 浜や簰灞?	vp_container.z_index = ZI_AREA_BG if USE_TRUE_3D_BOARD_BACKGROUND else ZI_TABLE_SURFACE
	vp_container.z_index = -50 if USE_TRUE_3D_BOARD_BACKGROUND else ZI_TABLE_SURFACE
	vp_container.visible = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true  # Phase 22B-R: 纭繚 SubViewport 鎷ユ湁鐙珛 World3D锛岄伩鍏?raycast 绾㈤敊
	# Phase 23A-R: defer hide to after all UI created
	call_deferred("_hide_2d_overlays_for_3d")
# Phase 21C: 3D Slot Anchor Map
# ============================================================
func _create_3d_slot_anchors(board_space: Node3D) -> void:
	# Clear old anchors if any
	var old_anchors := board_space.get_node_or_null(NodePath("SlotAnchors3D"))
	if old_anchors:
		board_space.remove_child(old_anchors)
		old_anchors.queue_free()

	var root := Node3D.new()
	root.name = "SlotAnchors3D"
	board_space.add_child(root)

	# Anchor definitions: {name, x, z, debug_color}
	var anchor_defs: Array[Dictionary] = [
		# 鈹€鈹€ Player front row (MONSTER) 鈹€鈹€
		{name="P_FRONT_0", x=-3.0, z=0.95, dc=Color(0.16, 0.62, 1.0, 1)},
		{name="P_FRONT_1", x=-1.5, z=0.95, dc=Color(0.16, 0.62, 1.0, 1)},
		{name="P_FRONT_2", x= 0.0, z=0.95, dc=Color(0.16, 0.85, 1.0, 1)},
		{name="P_FRONT_3", x= 1.5, z=0.95, dc=Color(0.16, 0.62, 1.0, 1)},
		{name="P_FRONT_4", x= 3.0, z=0.95, dc=Color(0.16, 0.62, 1.0, 1)},
		# 鈹€鈹€ Player back row (BUILD/COUNTER) 鈹€鈹€
		{name="P_BACK_0",  x=-3.0, z=1.75, dc=Color(0.16, 0.95, 0.56, 1)},
		{name="P_BACK_1",  x=-1.5, z=1.75, dc=Color(0.16, 0.95, 0.56, 1)},
		{name="P_BACK_2",  x= 0.0, z=1.75, dc=Color(0.16, 0.95, 0.56, 1)},
		{name="P_BACK_3",  x= 1.5, z=1.75, dc=Color(0.16, 0.95, 0.56, 1)},
		{name="P_BACK_4",  x= 3.0, z=1.75, dc=Color(0.16, 0.95, 0.56, 1)},
		# 鈹€鈹€ Boss front row 鈹€鈹€
		{name="B_FRONT_0", x=-3.0, z=-0.95, dc=Color(1.0, 0.28, 0.08, 1)},
		{name="B_FRONT_1", x=-1.5, z=-0.95, dc=Color(1.0, 0.28, 0.08, 1)},
		{name="B_FRONT_2", x= 0.0, z=-0.95, dc=Color(1.0, 0.45, 0.10, 1)},
		{name="B_FRONT_3", x= 1.5, z=-0.95, dc=Color(1.0, 0.28, 0.08, 1)},
		{name="B_FRONT_4", x= 3.0, z=-0.95, dc=Color(1.0, 0.28, 0.08, 1)},
		# 鈹€鈹€ Boss back row 鈹€鈹€
		{name="B_BACK_0",  x=-3.0, z=-1.75, dc=Color(0.65, 0.14, 0.06, 1)},
		{name="B_BACK_1",  x=-1.5, z=-1.75, dc=Color(0.65, 0.14, 0.06, 1)},
		{name="B_BACK_2",  x= 0.0, z=-1.75, dc=Color(0.65, 0.14, 0.06, 1)},
		{name="B_BACK_3",  x= 1.5, z=-1.75, dc=Color(0.65, 0.14, 0.06, 1)},
		{name="B_BACK_4",  x= 3.0, z=-1.75, dc=Color(0.65, 0.14, 0.06, 1)},
		# 鈹€鈹€ Special anchors 鈹€鈹€
		{name="ACTION_SLOT", x=0.0, z=0.45, dc=Color(0.85, 0.85, 0.40, 1)},
		{name="BOSS_CORE",   x=0.0, z=-2.35, dc=Color(1.0, 0.12, 0.30, 1)},
		{name="PLAYER_DECK", x=4.05, z=1.72, dc=Color(0.16, 0.75, 1.0, 1)},
		{name="PLAYER_GY",   x=4.05, z=0.96, dc=Color(0.14, 0.55, 0.70, 1)},
		{name="BOSS_DECK",   x=4.05, z=-1.72, dc=Color(1.0, 0.40, 0.12, 1)},
		{name="BOSS_GY",     x=4.05, z=-0.96, dc=Color(0.75, 0.30, 0.10, 1)},
	]

	var count := 0
	for def in anchor_defs:
		var anchor := Node3D.new()
		anchor.name = def.name
		anchor.position = Vector3(def.x, BOARD_PLAY_SURFACE_Y, def.z)  # Phase 22B-R: 缁熶竴琛ㄩ潰楂樺害
		root.add_child(anchor)
		count += 1

		# Debug marker
		if DEBUG_SHOW_3D_SLOT_ANCHORS:
			var marker_mesh := SphereMesh.new()
			marker_mesh.radius = 0.08
			marker_mesh.height = 0.16
			var marker := MeshInstance3D.new()
			marker.name = "DebugMarker"
			marker.mesh = marker_mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = def.dc
			mat.emission_enabled = true
			mat.emission = def.dc
			mat.emission_energy_multiplier = 0.6
			marker.material_override = mat
			anchor.add_child(marker)


	print("[3D_ANCHOR] SlotAnchors3D ready: %d anchors" % count)
	# Print one reference anchor for diagnostics
	var p_f2 := root.get_node_or_null(NodePath("P_FRONT_2")) as Node3D
	if p_f2:
		print("[3D_ANCHOR] P_FRONT_2=%s" % p_f2.position)
	var b_f2 := root.get_node_or_null(NodePath("B_FRONT_2")) as Node3D
	if b_f2:
		print("[3D_ANCHOR] B_FRONT_2=%s" % b_f2.position)
func _get_3d_slot_anchor(anchor_name: String) -> Node3D:
	# Phase 22C: 浼樺厛浣跨敤 runtime scene 鐨?Marker3D socket
	if _board_runtime and is_instance_valid(_board_runtime) and _board_runtime.is_glb_loaded():
		var marker: Marker3D = _board_runtime.get_socket_marker(anchor_name)
		if marker:
			if anchor_name == "BOSS_CORE":
				_ensure_boss_core_click_area(marker)
			return marker

	# Fallback: 鍔ㄦ€?SlotAnchors3D
	var stage := _get_3d_stage()
	if stage == null:
		return null
	var anchors := stage.get_node_or_null(NodePath("BoardSpace3D/SlotAnchors3D")) as Node3D
	if anchors == null:
		anchors = stage.get_node_or_null(NodePath("SlotAnchors3D")) as Node3D
	if anchors == null:
		return null
	var anchor := anchors.get_node_or_null(NodePath(anchor_name)) as Node3D
	if anchor_name == "BOSS_CORE" and anchor:
		_ensure_boss_core_click_area(anchor)
	return anchor

func _ensure_boss_core_click_area(anchor: Node3D) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	var area := anchor.get_node_or_null(NodePath("BossCoreClickArea")) as Area3D
	if area == null:
		area = Area3D.new()
		area.name = "BossCoreClickArea"
		anchor.add_child(area)
	area.set_meta("target_kind", "boss_core")
	area.collision_layer = TOKEN_CLICK_COLLISION_LAYER
	area.collision_mask = 0
	area.monitoring = true
	area.monitorable = true
	var shape := area.get_node_or_null(NodePath("ClickShape")) as CollisionShape3D
	if shape == null:
		shape = CollisionShape3D.new()
		shape.name = "ClickShape"
		area.add_child(shape)
	if shape.shape == null:
		var box := BoxShape3D.new()
		box.size = Vector3(1.8, 1.1, 1.8)
		shape.shape = box
	shape.disabled = false
func _get_3d_anchor_for_zone(side: String, zone: String, index: int) -> Node3D:
	var prefix: String
	if side == "player":
		prefix = "P"
	elif side == "boss" or side == "enemy":
		prefix = "B"
	else:
		return null
	var zone_abbr := "FRONT" if zone == "front" else "BACK"
	var anchor_name := "%s_%s_%d" % [prefix, zone_abbr, clampi(index, 0, 4)]
	return _get_3d_slot_anchor(anchor_name)


# ── Phase 27A-R1: 25-cell stable anchors from semantic board sockets ──

func _ensure_grid_cell_anchors() -> void:
	if _grid_cell_anchor_root != null and is_instance_valid(_grid_cell_anchor_root) and _grid_cell_anchors.size() == 25:
		return
	var stage := _get_3d_stage()
	if stage == null:
		return
	if _grid_cell_anchor_root != null and is_instance_valid(_grid_cell_anchor_root):
		_grid_cell_anchor_root.queue_free()
	_grid_cell_anchors.clear()
	_grid_cell_anchor_root = Node3D.new()
	_grid_cell_anchor_root.name = "GridCellAnchors3D"
	stage.add_child(_grid_cell_anchor_root)
	for column in range(5):
		var rank_sources: Array = [
			_get_3d_anchor_for_zone("boss", "back", column),
			_get_3d_anchor_for_zone("boss", "front", column),
			null,
			_get_3d_anchor_for_zone("player", "front", column),
			_get_3d_anchor_for_zone("player", "back", column),
		]
		var boss_front: Node3D = rank_sources[1] as Node3D
		var player_front: Node3D = rank_sources[3] as Node3D
		if boss_front == null or player_front == null:
			continue
		for rank in range(5):
			var marker := Marker3D.new()
			marker.name = "CELL_%d_%d" % [column, rank]
			_grid_cell_anchor_root.add_child(marker)
			if rank == 2:
				marker.global_transform = player_front.global_transform
				marker.global_position = (boss_front.global_position + player_front.global_position) * 0.5
			elif rank_sources[rank] != null:
				marker.global_transform = (rank_sources[rank] as Node3D).global_transform
			_grid_cell_anchors[Vector2i(column, rank)] = marker


func _get_3d_anchor_for_cell(cell: Vector2i) -> Node3D:
	if cell.x < 0 or cell.x >= 5 or cell.y < 0 or cell.y >= 5:
		return null
	_ensure_grid_cell_anchors()
	return _grid_cell_anchors.get(cell) as Node3D


func _ensure_tactical_terrain_presenter() -> void:
	_ensure_grid_cell_anchors()
	if _grid_cell_anchors.size() != 25 or _tactical_grid_presentation_profile == null:
		return
	var stage := _get_3d_stage()
	if stage == null:
		return
	if _tactical_terrain_presenter == null or not is_instance_valid(_tactical_terrain_presenter):
		_tactical_terrain_presenter = TacticalTerrainPresenterClass.new()
		_tactical_terrain_presenter.name = "TacticalTerrainPresenter"
		stage.add_child(_tactical_terrain_presenter)
	if not _tactical_terrain_presenter.configure(Callable(self, "_get_3d_anchor_for_cell"), _tactical_grid_presentation_profile):
		return
	_connect_tactical_terrain_authority()
	_on_tactical_terrain_transaction_committed({})
	if not _tactical_terrain_presenter.surface_positions_changed.is_connected(_sync_terrain_surface_consumers):
		_tactical_terrain_presenter.surface_positions_changed.connect(_sync_terrain_surface_consumers)


func _ensure_tactical_structure_presenter() -> void:

	if _tactical_terrain_presenter == null or not is_instance_valid(_tactical_terrain_presenter) or battle == null:
		return
	var stage := _get_3d_stage()
	if stage == null:
		return
	if _tactical_structure_presentation_profile == null:
		_tactical_structure_presentation_profile = GameCfg.create_tactical_structure_presentation_profile(false)
	if _tactical_structure_presentation_profile == null:
		return
	if _tactical_structure_presenter == null or not is_instance_valid(_tactical_structure_presenter):
		_tactical_structure_presenter = TacticalStructurePresenterClass.new()
		_tactical_structure_presenter.name = "TacticalStructurePresenter"
		stage.add_child(_tactical_structure_presenter)
	if not _tactical_structure_presenter.configure(_tactical_terrain_presenter, _tactical_structure_presentation_profile, TOKEN_CLICK_COLLISION_LAYER):
		return
	_connect_tactical_structure_authority()
	_on_tactical_structure_transaction_committed({})


func _ensure_tactical_garrison_presenter() -> void:

	if _tactical_terrain_presenter == null or not is_instance_valid(_tactical_terrain_presenter) \
			or _tactical_structure_presenter == null or not is_instance_valid(_tactical_structure_presenter):
		return
	var stage := _get_3d_stage()
	if stage == null:
		return
	if _tactical_garrison_presenter == null or not is_instance_valid(_tactical_garrison_presenter):
		_tactical_garrison_presenter = TacticalGarrisonPresenterScene.instantiate() as Node3D
		_tactical_garrison_presenter.name = "TacticalGarrisonPresenter"
		stage.add_child(_tactical_garrison_presenter)
	if not bool(_tactical_garrison_presenter.call("configure", _tactical_terrain_presenter, _tactical_structure_presenter)):
		return
	if battle != null and context != null and context.tactical_structure_board_state != null:
		_tactical_garrison_presenter.call(
			"apply_garrison_snapshot",
			context.tactical_structure_board_state.get_garrison_snapshot().duplicate(true),
			{},
			_is_reduced_motion_presentation()
		)


func _ensure_structure_interaction_presenter() -> void:

	if _structure_interaction_presenter != null and is_instance_valid(_structure_interaction_presenter):
		return
	var layer := CanvasLayer.new()
	layer.name = "StructureInteractionLayer"
	layer.layer = 92
	add_child(layer)
	_structure_interaction_presenter = StructureInteractionPresenterScene.instantiate() as Control
	_structure_interaction_presenter.name = "StructureInteractionPresenter"
	layer.add_child(_structure_interaction_presenter)
	_sync_structure_interaction_safe_area()


func _sync_structure_interaction_safe_area() -> void:

	if _structure_interaction_presenter != null and is_instance_valid(_structure_interaction_presenter) and _structure_interaction_presenter.has_method("set_reserved_rects"):
		_structure_interaction_presenter.set_reserved_rects(_get_structure_reserved_ui_rects())


func _clear_structure_interaction(_reason: StringName = &"") -> void:

	if _structure_interaction_presenter != null and is_instance_valid(_structure_interaction_presenter) and _structure_interaction_presenter.has_method("clear"):
		_structure_interaction_presenter.clear()


func _connect_tactical_structure_authority() -> void:

	var next_authority: Variant = context.tactical_structure_board_state if context != null else null
	if _tactical_structure_authority != null and _tactical_structure_authority != next_authority and _tactical_structure_authority.transaction_committed.is_connected(_on_tactical_structure_transaction_committed):
		_tactical_structure_authority.transaction_committed.disconnect(_on_tactical_structure_transaction_committed)
	if context == null or context.tactical_structure_board_state == null:
		return
	_tactical_structure_authority = context.tactical_structure_board_state
	if not _tactical_structure_authority.transaction_committed.is_connected(_on_tactical_structure_transaction_committed):
		_tactical_structure_authority.transaction_committed.connect(_on_tactical_structure_transaction_committed)


func _disconnect_tactical_structure_authority() -> void:

	if _tactical_structure_authority != null and _tactical_structure_authority.transaction_committed.is_connected(_on_tactical_structure_transaction_committed):
		_tactical_structure_authority.transaction_committed.disconnect(_on_tactical_structure_transaction_committed)
	_tactical_structure_authority = null


func _on_tactical_structure_transaction_committed(fact: Dictionary) -> void:
	_refresh_siege_intent_view()

	if _tactical_structure_presenter == null or not is_instance_valid(_tactical_structure_presenter) or battle == null:
		return
	var snapshot: Dictionary = battle.get_structure_snapshot().duplicate(true)
	if battle.has_method("get_all_cell_states"):
		snapshot["terrain_cells"] = battle.get_all_cell_states().duplicate(true)
	_tactical_structure_presenter.apply_structure_snapshot(snapshot, fact.duplicate(true), _is_reduced_motion_presentation())
	if _tactical_garrison_presenter != null and is_instance_valid(_tactical_garrison_presenter) \
			and context != null and context.tactical_structure_board_state != null:
		_tactical_garrison_presenter.call(
			"apply_garrison_snapshot",
			context.tactical_structure_board_state.get_garrison_snapshot().duplicate(true),
			{},
			_is_reduced_motion_presentation()
		)


func _on_garrison_transaction_committed(fact: Dictionary) -> void:

	if _tactical_garrison_presenter == null or not is_instance_valid(_tactical_garrison_presenter) \
			or context == null or context.tactical_structure_board_state == null:
		return
	var presentation_fact := fact.duplicate(true)
	var runtime_id := int(presentation_fact.get("unit_runtime_id", 0))
	var unit := _find_field_unit_by_runtime_id(runtime_id)
	if unit != null:
		var token := _get_3d_token_for_card(unit)
		if token != null:
			presentation_fact["unit_visual"] = token
	_tactical_garrison_presenter.call(
		"apply_garrison_snapshot",
		context.tactical_structure_board_state.get_garrison_snapshot().duplicate(true),
		presentation_fact,
		_is_reduced_motion_presentation()
	)
	call_deferred("_sync_3d_field_tokens")


func _find_field_unit_by_runtime_id(runtime_id: int) -> CardData:

	if runtime_id <= 0 or context == null:
		return null
	for side in [context.player, context.enemy]:
		if side == null:
			continue
		for card in side.field:
			if card is CardData and is_instance_valid(card) and card.get_instance_id() == runtime_id:
				return card
	return null


func _build_structure_view_model(target_ref: Dictionary) -> Dictionary:

	if battle == null:
		return {}
	var snapshot: Dictionary = battle.get_structure_snapshot().duplicate(true)
	var structure_id := StringName(str(target_ref.get("structure_id", &"")))
	var structures: Variant = snapshot.get("structures", {})
	if not structures is Dictionary or not (structures as Dictionary).has(structure_id):
		return {}
	var structure: Dictionary = ((structures as Dictionary)[structure_id] as Dictionary).duplicate(true)
	var modules: Array[Dictionary] = []
	var module_table: Variant = snapshot.get("modules", {})
	if module_table is Dictionary:
		for module_id in module_table:
			var module: Variant = (module_table as Dictionary)[module_id]
			if module is Dictionary and StringName(str((module as Dictionary).get("structure_id", &""))) == structure_id:
				modules.append((module as Dictionary).duplicate(true))
	modules.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("module_id", "")) < str(right.get("module_id", "")))
	var card := _find_structure_source_card(int(structure.get("source_runtime_id", 0)))
	var availability := {"action_id": &"activate_building_interface", "available": false, "reason": "Unavailable"}
	if card != null and context != null and context.player != null:
		var status: Dictionary = battle.get_building_interface_status(card, context.player).duplicate(true)
		availability["available"] = bool(status.get("ok", false))
		availability["reason"] = str(status.get("reason", status.get("message", "Unavailable")))
		availability["preview"] = str(status.get("preview", ""))
		availability["cost"] = str(status.get("cost", ""))
	var breaches: Array[StringName] = []
	for module in modules:
		if StringName(str(module.get("status", &""))) == &"destroyed":
			breaches.append(StringName(str(module.get("edge", &""))))
	return {
		"structure_id": structure_id,
		"title": card.get_display_name() if card != null and card.has_method("get_display_name") else str(structure.get("source_card_id", "Structure")),
		"source_card_id": StringName(str(structure.get("source_card_id", &""))),
		"cell": structure.get("cell", Vector2i.ZERO),
		"height": int(_get_structure_cell_height(structure.get("cell", Vector2i.ZERO))),
		"integrity_current": int(structure.get("integrity_current", 0)),
		"integrity_max": int(structure.get("integrity_max", 0)),
		"status": StringName(str(structure.get("status", &"intact"))),
		"modules": modules,
		"breached_edges": breaches,
		"garrison_slots_total": int(structure.get("reserved_garrison_slots", 0)),
		"rules_text": (card.building_charge_text + "\n全局已准备Depth减免%d（下次增长消耗）" % context.pending_depth_reduction) if card != null else "",
		"garrison_slots_enabled": false,
		"available_actions": [availability],
	}.duplicate(true)


func _get_structure_cell_height(cell: Variant) -> int:

	if battle == null or not cell is Vector2i:
		return 0
	var state: Dictionary = battle.get_cell_state(cell) if battle.has_method("get_cell_state") else {}
	return int(state.get("height", 0))


func _find_structure_source_card(runtime_id: int) -> CardData:

	if context == null or context.player == null or runtime_id <= 0:
		return null
	for container in [context.player.traps, context.player.field, context.player.hand]:
		for raw in container:
			var card := raw as CardData
			if card != null and card.get_instance_id() == runtime_id:
				return card
	return null


func _connect_tactical_terrain_authority() -> void:
	_disconnect_tactical_terrain_authority()
	if context == null or context.tactical_board_state == null:
		return
	_tactical_terrain_authority = context.tactical_board_state
	if not _tactical_terrain_authority.transaction_committed.is_connected(_on_tactical_terrain_transaction_committed):
		_tactical_terrain_authority.transaction_committed.connect(_on_tactical_terrain_transaction_committed)


func _disconnect_tactical_terrain_authority() -> void:
	if _tactical_terrain_authority != null and _tactical_terrain_authority.transaction_committed.is_connected(_on_tactical_terrain_transaction_committed):
		_tactical_terrain_authority.transaction_committed.disconnect(_on_tactical_terrain_transaction_committed)
	_tactical_terrain_authority = null


func _on_tactical_terrain_transaction_committed(fact: Dictionary) -> void:
	if _tactical_terrain_presenter == null or not is_instance_valid(_tactical_terrain_presenter) or battle == null:
		return
	var states: Dictionary = battle.get_all_cell_states()
	var cells: Array[Dictionary] = []
	for cell in states:
		cells.append((states[cell] as Dictionary).duplicate(true))
	_tactical_terrain_presenter.apply_board_snapshot({"cells": cells}.duplicate(true), fact.duplicate(true), _is_reduced_motion_presentation())
	_refit_camera_after_terrain_commit(fact)


func _refit_camera_after_terrain_commit(_fact: Dictionary) -> void:
	if _is_reduced_motion_presentation() or _camera_state == null or _camera_state.active_preset == BattleViewCameraState.Preset.FREE:
		return
	var preset_name := &""
	if _camera_state.active_preset == BattleViewCameraState.Preset.BASE:
		preset_name = &"base"
	elif _camera_state.active_preset == BattleViewCameraState.Preset.TOP:
		preset_name = &"top"
	if preset_name == &"":
		return
	var target := _camera_target_snapshot(String(preset_name))
	_terrain_refit_generation += 1
	_terrain_refit_preset = preset_name
	_terrain_refit_target_snapshot = target.duplicate(true)
	_animate_to_preset(String(preset_name), target)


func _get_3d_surface_anchor_for_cell(cell: Vector2i) -> Node3D:
	if _tactical_terrain_presenter != null and is_instance_valid(_tactical_terrain_presenter):
		var surface := _tactical_terrain_presenter.get_surface_anchor(cell)
		if surface != null and is_instance_valid(surface):
			return surface
	return _get_3d_anchor_for_cell(cell)


func _record_elevated_grid_endpoint(kind: StringName, cell: Vector2i, world_position: Vector3, screen_position: Vector2) -> void:
	_elevated_grid_endpoint_facts[kind] = {
		"cell": cell,
		"world_position": world_position,
		"screen_position": screen_position,
	}.duplicate(true)


func get_elevated_grid_presentation_debug_snapshot() -> Dictionary:
	return {
		"endpoint_facts": _elevated_grid_endpoint_facts.duplicate(true),
		"terrain_refit_generation": _terrain_refit_generation,
		"terrain_refit_preset": _terrain_refit_preset,
		"terrain_refit_target_snapshot": _terrain_refit_target_snapshot.duplicate(true),
	}.duplicate(true)


func _get_terrain_visual_offset_for_cell(cell: Vector2i) -> float:
	var base_anchor := _get_3d_anchor_for_cell(cell)
	var surface_anchor := _get_3d_surface_anchor_for_cell(cell)
	if base_anchor == null or surface_anchor == null:
		return 0.0
	return surface_anchor.global_position.y - base_anchor.global_position.y


func _sync_terrain_surface_consumers(_changed_cells: Array[Vector2i]) -> void:
	if _tactical_presenter != null and is_instance_valid(_tactical_presenter) and _tactical_presenter.has_method("refresh_surface_positions"):
		_tactical_presenter.refresh_surface_positions()
	if _monster_summon_state() == MONSTER_SUMMON_PENDING_CONFIRM and _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		var candidate: Vector2i = _monster_drag_session.get("candidate_cell", MONSTER_DRAG_INVALID_CELL)
		_monster_summon_interaction_presenter.update_target(_project_tactical_cell_to_screen(candidate))
	_sync_3d_field_tokens()
	if _tactical_terrain_presenter != null and is_instance_valid(_tactical_terrain_presenter):
		_tactical_terrain_presenter.refresh_occlusion(_get_3d_camera())


func _on_tactical_cell_hover_changed(cell: Vector2i, hovered: bool) -> void:
	if _tactical_terrain_presenter == null or not is_instance_valid(_tactical_terrain_presenter):
		return
	if hovered:
		_tactical_terrain_presenter.set_focus_cell(cell, _get_3d_camera())
	else:
		_tactical_terrain_presenter.clear_focus()


# ── Phase 27I-R0-R4: 棋子选择专用权威格→3D 映射 ──
## 普通 5×5 格复用 _get_3d_anchor_for_cell（不改动普通战术网格 0–4 几何规则）；
## 我方虚拟核心格（(2,5)）映射到玩家侧核心表现节点；其余越界格返回 null。
## 只用于棋子选择的展示，不建立第二套合法性——BattleSystem 仍是合法锚点唯一权威。
func _get_3d_piece_anchor_for_cell(cell: Vector2i) -> Node3D:
	if cell.x >= 0 and cell.x < 5 and cell.y >= 0 and cell.y < 5:
		return _get_3d_surface_anchor_for_cell(cell)
	if battle != null and battle.has_method("get_virtual_core_anchor_cell"):
		var core_cell: Vector2i = battle.get_virtual_core_anchor_cell(&"player")
		if cell == core_cell:
			return _ensure_player_core_piece_anchor()
	return null


## Phase 27I-R0-R4: 玩家核心表现层锚点（棋盘外虚拟格 (2,5) 的 3D 语义对象）。
## 位置固定在玩家侧棋盘下沿中央；不参与 BattleSystem 棋盘占用；
## 只负责显示与输入桥接（选择碰撞层 bit20 / input_ray_pickable / 真实 CollisionShape3D）。
func _ensure_player_core_piece_anchor() -> Node3D:
	var stage := _get_3d_stage()
	if stage == null:
		return null
	var board := stage.get_node_or_null(NodePath("BoardSpace3D")) as Node3D
	if board == null:
		board = stage
	var existing := board.get_node_or_null(NodePath("PlayerCorePieceAnchor3D")) as Node3D
	if existing != null and is_instance_valid(existing):
		return existing
	if battle == null or not battle.has_method("get_virtual_core_anchor_cell"):
		return null
	_ensure_grid_cell_anchors()
	var back_anchor: Node3D = _grid_cell_anchors.get(Vector2i(2, 4), null)
	var front_anchor: Node3D = _grid_cell_anchors.get(Vector2i(2, 3), null)
	if back_anchor == null or front_anchor == null:
		return null
	# 玩家侧下沿中央 = 玩家后排 (2,4) 再沿 rank 方向外推一排
	var global_pos: Vector3 = back_anchor.global_position + (back_anchor.global_position - front_anchor.global_position)
	var core_cell: Vector2i = battle.get_virtual_core_anchor_cell(&"player")
	var core := Area3D.new()
	core.name = "PlayerCorePieceAnchor3D"
	core.collision_layer = TOKEN_CLICK_COLLISION_LAYER
	core.collision_mask = 0
	core.input_ray_pickable = true
	core.monitoring = true
	core.monitorable = true
	core.set_meta("target_kind", "tactical_cell")
	core.set_meta("selection_mode", &"piece_anchor")
	core.set_meta("board_cell", core_cell)
	core.set_meta("piece_kind", "player_core")
	core.set_meta("owner_side", &"player")
	core.set_meta("selectable", true)
	core.position = board.to_local(global_pos)
	# 常驻低调金色核心环（玩家核心位置指示；P01 选择时上方另叠一枚金色锚点标记）
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.30
	cyl.bottom_radius = 0.30
	cyl.height = 0.02
	ring.mesh = cyl
	ring.position = Vector3(0, 0.03, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.72, 0.12, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	core.add_child(ring)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 0.4
	col.shape = shape
	core.add_child(col)
	board.add_child(core)
	return core


# ── Phase 27B-R1-R2-R: 25-cell tactical grid frame for camera composition ──
## Reads all 25 cell anchors; never uses GLB mesh AABB as gameplay geometry.
## Returns a pure Dictionary.  Incomplete anchor sets return {ok=false}.
func _compute_tactical_grid_frame() -> Dictionary:
	_ensure_grid_cell_anchors()
	if _grid_cell_anchors.size() != 25:
		return {"ok": false, "reason": "incomplete_anchors", "count": _grid_cell_anchors.size()}

	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	var cell_centers: Array[Vector3] = []
	for y in range(5):
		for x in range(5):
			var anchor: Node3D = _get_3d_anchor_for_cell(Vector2i(x, y))
			if anchor == null or not is_instance_valid(anchor):
				return {"ok": false, "reason": "missing_anchor", "cell": Vector2i(x, y)}
			var pos := anchor.global_position
			cell_centers.append(pos)
			min_x = minf(min_x, pos.x)
			max_x = maxf(max_x, pos.x)
			min_z = minf(min_z, pos.z)
			max_z = maxf(max_z, pos.z)

	if cell_centers.is_empty():
		return {"ok": false, "reason": "no_anchors"}

	var width_world := max_x - min_x
	var depth_world := max_z - min_z
	var base_y_world := cell_centers[0].y
	var max_surface_y_world := base_y_world
	var height_span_world := 0.0
	if _tactical_terrain_presenter != null and is_instance_valid(_tactical_terrain_presenter):
		for y in range(5):
			for x in range(5):
				var cell := Vector2i(x, y)
				var visual_height := _tactical_terrain_presenter.get_visual_height_world(cell)
				if visual_height > 0.0:
					height_span_world = maxf(height_span_world, visual_height)
					max_surface_y_world = maxf(max_surface_y_world, _tactical_terrain_presenter.get_surface_target_world_position(cell).y)
	var center_world := Vector3((min_x + max_x) * 0.5, base_y_world, (min_z + max_z) * 0.5)

	# Cell spacing: median of adjacent-cell distances
	var spacings_x: Array[float] = []
	var spacings_z: Array[float] = []
	for y in range(5):
		for x in range(4):
			var a1: Node3D = _get_3d_anchor_for_cell(Vector2i(x, y))
			var a2: Node3D = _get_3d_anchor_for_cell(Vector2i(x + 1, y))
			if a1 != null and a2 != null and is_instance_valid(a1) and is_instance_valid(a2):
				spacings_x.append(absf(a2.global_position.x - a1.global_position.x))
	for x in range(5):
		for y in range(4):
			var a1: Node3D = _get_3d_anchor_for_cell(Vector2i(x, y))
			var a2: Node3D = _get_3d_anchor_for_cell(Vector2i(x, y + 1))
			if a1 != null and a2 != null and is_instance_valid(a1) and is_instance_valid(a2):
				spacings_z.append(absf(a2.global_position.z - a1.global_position.z))

	spacings_x.sort()
	spacings_z.sort()
	var column_spacing := spacings_x[spacings_x.size() / 2] if not spacings_x.is_empty() else 1.0
	var rank_spacing := spacings_z[spacings_z.size() / 2] if not spacings_z.is_empty() else 1.0

	return {
		"ok": true,
		"center_world": center_world,
		"width": width_world,
		"depth": depth_world,
		"width_world": width_world,
		"depth_world": depth_world,
		"base_y_world": base_y_world,
		"max_surface_y_world": max_surface_y_world,
		"height_span_world": height_span_world,
		"column_spacing": column_spacing,
		"rank_spacing": rank_spacing,
		"min_world": Vector3(min_x, cell_centers[0].y, min_z),
		"max_world": Vector3(max_x, cell_centers[0].y, max_z),
	}


func _setup_3d_stage() -> void:
	var vp_container := get_node_or_null(NodePath("Battle3DViewport")) as SubViewportContainer
	if not vp_container:
		print("[3D] SubViewportContainer not found - skip 3D stage")
		return
	var vp := vp_container.get_node_or_null(NodePath("SubViewport")) as SubViewport
	if not vp:
		return

	_sync_3d_viewport_to_table()

	# Phase 27A-R1: clear cached cell anchors before stage teardown
	_grid_cell_anchor_root = null
	_grid_cell_anchors.clear()

	var old_stage := vp.get_node_or_null(NodePath("BattleStage3D"))
	if old_stage:
		vp.remove_child(old_stage)
		old_stage.queue_free()

	var stage := Node3D.new()
	stage.name = "BattleStage3D"
	vp.add_child(stage)

	var env := WorldEnvironment.new()
	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.015, 0.018, 0.026, 1)
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.55, 0.52, 0.48, 1) if USE_TRUE_3D_BOARD_BACKGROUND else Color(0.38, 0.36, 0.34, 1)
	env_res.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_res.glow_enabled = true
	env_res.glow_intensity = 0.30 if USE_TRUE_3D_BOARD_BACKGROUND else 0.22
	env.environment = env_res
	stage.add_child(env)

	# Phase 21F: CameraRig3D 鈥?yaw 鈫?pitch 鈫?distance 鈫?camera
	var rig := Node3D.new()
	rig.name = "CameraRig3D"
	rig.rotation_degrees.y = _camera_yaw
	stage.add_child(rig)

	var pitch_node := Node3D.new()
	pitch_node.name = "CameraPitch"
	pitch_node.rotation_degrees.x = _camera_pitch
	rig.add_child(pitch_node)

	var dist_node := Node3D.new()
	dist_node.name = "CameraDistance"
	dist_node.position.z = _camera_distance
	pitch_node.add_child(dist_node)

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3.ZERO
	cam.rotation_degrees = Vector3.ZERO
	cam.fov = 46.0
	dist_node.add_child(cam)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-55, -24, 0)
	sun.light_energy = 1.6 if USE_TRUE_3D_BOARD_BACKGROUND else 1.2
	sun.light_color = Color(1.0, 0.93, 0.82, 1)
	stage.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "ODFillLight"
	fill.light_color = Color(0.24, 0.78, 1.0, 1)
	fill.light_energy = 0.72 if USE_TRUE_3D_BOARD_BACKGROUND else 0.55
	fill.omni_range = 7.0
	fill.position = Vector3(-3.7, 1.2, 2.2)
	stage.add_child(fill)

	var board_space := Node3D.new()
	board_space.name = "BoardSpace3D"
	board_space.position = BOARD_SPACE_POSITION
	board_space.scale = BOARD_SPACE_SCALE
	board_space.rotation_degrees = BOARD_SPACE_ROTATION_DEGREES
	stage.add_child(board_space)

	# Phase 22C-R: 灏濊瘯鍔犺浇杩愯鏃舵鐩樺寘瑁呭満鏅紙鍚?Marker3D socket锛?	# 鍙湁 runtime scene 鍒涘缓鎴愬姛 AND load_glb() 杩斿洖 true 鏃讹紝use_runtime 鎵嶄负 true
	var use_runtime := false
	if USE_RUNTIME_BOARD_SCENE and ResourceLoader.exists(BOARD_RUNTIME_SCENE_PATH):
		var rt_scene := load(BOARD_RUNTIME_SCENE_PATH) as PackedScene
		if rt_scene:
			_board_runtime = rt_scene.instantiate()
			if _board_runtime:
				_board_runtime.name = "CloudGateBoardRuntime"
				board_space.add_child(_board_runtime)
				_glb_board_loaded = _board_runtime.load_glb()
				if _glb_board_loaded:
					use_runtime = true
					_board_runtime.print_socket_diagnostics(false)
					print("[BOARD_SEMANTICS] boss=-X player=+X model_yaw=%.1f runtime=%s" % [_board_runtime.get_model_yaw(), use_runtime])
					# Phase 22C-R: calibration - runtime marker debug spheres
					if DEBUG_SHOW_3D_SLOT_ANCHORS:
						_add_debug_markers_to_runtime_sockets()
				else:
					# Phase 22C-R: GLB 鍔犺浇澶辫触 鈥?鍒犻櫎鏃犳晥 runtime wrapper锛屽洖閫€鍒扮▼搴忓寲
					printerr("[BOARD_SEMANTICS] GLB load failed; using procedural fallback")
					board_space.remove_child(_board_runtime)
					_board_runtime.queue_free()
					_board_runtime = null
			else:
				printerr("[BOARD_SEMANTICS] Runtime scene instantiate failed")
		else:
			printerr("[BOARD_SEMANTICS] Runtime scene load failed")
	else:
		if USE_RUNTIME_BOARD_SCENE:
			print("[BOARD_SEMANTICS] Runtime scene not found: %s; using procedural fallback" % BOARD_RUNTIME_SCENE_PATH)

	# [Fixed]
	if not use_runtime:
		_create_3d_slot_anchors(board_space)
		var board_root := Node3D.new()
		board_root.name = "BoardRoot3D"
		board_space.add_child(board_root)
		_glb_board_loaded = false
		if USE_GLB_BOARD:
			_glb_board_loaded = _load_glb_board(board_root)
		if not _glb_board_loaded:
			_build_3d_table_model(board_root)
		print("[FALLBACK_TEST] procedural_board=%s" % (not _glb_board_loaded))

	# CardTokenRoot3D 鈫?BoardSpace3D锛堜袱绉嶈矾寰勯兘闇€瑕侊級
	_ensure_card_token_root_3d(board_space)

	print("[3D_BOARD] true_3d_background=%s glb_board=%s runtime=%s" % [USE_TRUE_3D_BOARD_BACKGROUND, _glb_board_loaded, use_runtime])
	print("[3D_BOARD] BoardSpace3D pos=%s scale=%s rot=%s" % [BOARD_SPACE_POSITION, BOARD_SPACE_SCALE, BOARD_SPACE_ROTATION_DEGREES])
	var vp_diag := get_node_or_null(NodePath("Battle3DViewport")) as SubViewportContainer
	if vp_diag:
		print("[3D_BOARD] viewport visible=%s rect=%s" % [vp_diag.visible, vp_diag.get_global_rect()])
	print("[3D] CloudGate tactical board ready")

	# Phase 22B-R: 寤惰繜搴旂敤榛樿瑙嗚 + 楠岃瘉宸﹀彸鎶曞奖
	call_deferred("_apply_initial_base_preset")
	call_deferred("_debug_project_slot_anchors")
	# Phase 26D: 棋盘就绪后初始化 OD 伙伴后场
	call_deferred("_ensure_od_companion_backline_presenter")
	# Phase 26E-R1: 棋盘就绪后初始化战术移动展示器
	call_deferred("_ensure_tactical_movement_presenter")
	# Phase 27A-R1: rebuild 25-cell anchors after board is ready
	call_deferred("_ensure_grid_cell_anchors")

# Phase 24B-R2-R3: Dark full-screen background behind 3D viewport
func _create_root_background() -> void:
	if not USE_TRUE_3D_BOARD_BACKGROUND:
		return
	var old_bg := get_node_or_null(NodePath("BattleRootBackground"))
	if old_bg and is_instance_valid(old_bg):
		old_bg.queue_free()
	var bg := ColorRect.new()
	bg.name = "BattleRootBackground"
	bg.color = Color(0.005, 0.006, 0.012, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -100
	add_child(bg)
	move_child(bg, 0)
	_create_hand_stage_scrim()
	print("[3D_BOARD] BattleRootBackground created at z=-100")


func _create_hand_stage_scrim() -> void:
	var old := get_node_or_null(NodePath("HandStageScrim"))
	if old and is_instance_valid(old):
		old.queue_free()
	var scrim := ColorRect.new()
	scrim.name = "HandStageScrim"
	scrim.color = Color(0.0, 0.0, 0.0, 0.62)
	scrim.anchor_left = 0.0
	scrim.anchor_right = 1.0
	scrim.anchor_top = 1.0
	scrim.anchor_bottom = 1.0
	scrim.offset_left = 0.0
	scrim.offset_right = 0.0
	scrim.offset_top = -235.0
	scrim.offset_bottom = 0.0
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.z_index = ZI_HAND_CARD_BASE - 1
	add_child(scrim)

func _make_mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	material.metallic = 0.25
	if color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
func _make_emissive_mat(color: Color, energy: float = 1.0) -> StandardMaterial3D:
	var material := _make_mat(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
func _make_mesh(p_name: String, p_mesh: Mesh, p_mat: Material, p_pos: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = p_name
	mesh_instance.mesh = p_mesh
	mesh_instance.material_override = p_mat
	mesh_instance.position = p_pos
	return mesh_instance
# [Fixed func]
func _load_glb_board(board_root: Node3D) -> bool:
	if not ResourceLoader.exists(BOARD_GLB_PATH):
		print("[GLB_BOARD] GLB file not found: %s; using procedural fallback" % BOARD_GLB_PATH)
		return false

	var glb_scene: PackedScene = load(BOARD_GLB_PATH) as PackedScene
	if glb_scene == null:
		print("[GLB_BOARD] GLB load failed; using procedural fallback")
		return false

	var board_instance := glb_scene.instantiate() as Node3D
	if board_instance == null:
		print("[GLB_BOARD] GLB instantiate failed; using procedural fallback")
		return false

	board_instance.name = "CloudGateBoard"
	# Phase 22B: 涓嶅啀璁剧疆 scale/position/rotation 鈥?BoardSpace3D 缁熶竴鎺у埗
	board_root.add_child(board_instance)

	print("[GLB_BOARD] CloudGate battle board loaded: %s" % BOARD_GLB_PATH)

	# Phase 22B: 閫掑綊璁＄畻 GLB MeshInstance3D 鍚堝苟 AABB
	var glb_aabb := _compute_glb_merged_aabb(board_instance)
	if glb_aabb != null:
		print("[GLB_BOARD] GLB AABB: center=%s size=%s" % [glb_aabb.get_center(), glb_aabb.size])
	else:
		print("[GLB_BOARD] GLB AABB: no MeshInstance3D found (empty root)")
	return true
# Phase 22B: 閫掑綊閬嶅巻鑺傜偣鏍戯紝鏀堕泦鎵€鏈?MeshInstance3D 骞惰绠楀悎骞?AABB
func _compute_glb_merged_aabb(root: Node3D) -> AABB:
	if root == null:
		return AABB()
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(root, meshes)
	if meshes.is_empty():
		return AABB()
	var merged := meshes[0].get_aabb()
	for i in range(1, meshes.size()):
		merged = merged.merge(meshes[i].get_aabb())
	return merged
func _collect_mesh_instances(node: Node, out_meshes: Array) -> void:
	if node is MeshInstance3D:
		out_meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		if is_instance_valid(child):
			_collect_mesh_instances(child, out_meshes)
func _build_3d_table_model(board_root: Node3D) -> void:
	var shell_mat := _make_mat(Color(0.055, 0.055, 0.065, 1))
	shell_mat.metallic = 0.45
	var stone_mat := _make_mat(Color(0.42, 0.43, 0.42, 1))
	stone_mat.roughness = 0.92
	var boss_plate_mat := _make_mat(Color(0.15, 0.055, 0.045, 0.88))
	var player_plate_mat := _make_mat(Color(0.12, 0.18, 0.22, 0.78))
	var brass_mat := _make_mat(Color(0.54, 0.40, 0.22, 1))
	brass_mat.metallic = 0.75
	var cyan_mat := _make_emissive_mat(Color(0.10, 0.82, 1.0, 1), 0.9)
	var red_mat := _make_emissive_mat(Color(1.0, 0.24, 0.08, 1), 0.85)

	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(9.4, 0.34, 5.45)
	board_root.add_child(_make_mesh("FloatingStoneBase", base_mesh, shell_mat, Vector3(0, -0.48, 0)))

	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(8.82, 0.06, 4.88)
	board_root.add_child(_make_mesh("StoneDeck", top_mesh, stone_mat, Vector3(0, -0.25, 0)))

	var boss_mesh := BoxMesh.new()
	boss_mesh.size = Vector3(8.28, 0.045, 2.0)
	board_root.add_child(_make_mesh("BossHalfPlate", boss_mesh, boss_plate_mat, Vector3(0, -0.18, -1.17)))

	var player_mesh := BoxMesh.new()
	player_mesh.size = Vector3(8.28, 0.045, 2.0)
	board_root.add_child(_make_mesh("PlayerHalfPlate", player_mesh, player_plate_mat, Vector3(0, -0.18, 1.17)))

	var center_mesh := BoxMesh.new()
	center_mesh.size = Vector3(8.7, 0.035, 0.055)
	board_root.add_child(_make_mesh("CenterLine", center_mesh, _make_emissive_mat(Color(0.95, 0.38, 0.08, 1), 0.75), Vector3(0, -0.11, 0)))

	_add_3d_edge_rails(board_root, brass_mat)
	_add_3d_slot_rows(board_root)
	_add_3d_corner_devices(board_root, brass_mat, cyan_mat, red_mat)
	_add_3d_od_device(board_root, cyan_mat, brass_mat)
	_add_3d_deck_devices(board_root, brass_mat, cyan_mat, red_mat)
	_add_3d_boss_core(board_root, brass_mat, cyan_mat, red_mat)
func _add_3d_edge_rails(board_root: Node3D, rail_mat: Material) -> void:
	var rail_positions: Array[Vector3] = [
		Vector3(-4.68, -0.12, 0), Vector3(4.68, -0.12, 0),
		Vector3(0, -0.12, -2.72), Vector3(0, -0.12, 2.72),
	]
	var rail_sizes: Array[Vector3] = [
		Vector3(0.18, 0.18, 5.45), Vector3(0.18, 0.18, 5.45),
		Vector3(9.4, 0.18, 0.18), Vector3(9.4, 0.18, 0.18),
	]
	for i in range(rail_positions.size()):
		var mesh := BoxMesh.new()
		mesh.size = rail_sizes[i]
		board_root.add_child(_make_mesh("TableRail%d" % i, mesh, rail_mat, rail_positions[i]))
func _add_3d_slot_rows(board_root: Node3D) -> void:
	_create_3d_slot_row(board_root, "BossBackSlots", "boss", "back", -1.75, Color(1.0, 0.30, 0.10, 0.42))
	_create_3d_slot_row(board_root, "BossFrontSlots", "boss", "front", -0.95, Color(1.0, 0.18, 0.08, 0.48))
	_create_3d_slot_row(board_root, "PlayerFrontSlots", "player", "front", 0.95, Color(0.16, 0.62, 1.0, 0.48))
	_create_3d_slot_row(board_root, "PlayerBackSlots", "player", "back", 1.75, Color(0.16, 0.95, 0.56, 0.42))
func _create_3d_slot_row(board_root: Node3D, row_name: String, owner_side: String, row_kind: String, z_pos: float, color: Color) -> void:
	var row := Node3D.new()
	row.name = row_name
	board_root.add_child(row)
	var slot_mat := _make_mat(Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.30))
	var trim_mat := _make_emissive_mat(color, 0.22)
	for i in range(5):
		var p := _get_3d_slot_pos(owner_side, row_kind, i)
		p.z = z_pos
		var recess := BoxMesh.new()
		recess.size = Vector3(1.12, 0.028, 0.62)
		row.add_child(_make_mesh("%s_Recess%d" % [row_kind, i], recess, slot_mat, Vector3(p.x, -0.08, p.z)))
		var trim := BoxMesh.new()
		trim.size = Vector3(1.22, 0.018, 0.035)
		row.add_child(_make_mesh("%s_TrimTop%d" % [row_kind, i], trim, trim_mat, Vector3(p.x, -0.045, p.z - 0.34)))
		row.add_child(_make_mesh("%s_TrimBottom%d" % [row_kind, i], trim, trim_mat, Vector3(p.x, -0.045, p.z + 0.34)))
func _add_3d_corner_devices(board_root: Node3D, brass_mat: Material, cyan_mat: Material, red_mat: Material) -> void:
	var corner_positions := [
		Vector3(-4.15, -0.02, -2.18), Vector3(4.15, -0.02, -2.18),
		Vector3(-4.15, -0.02, 2.18), Vector3(4.15, -0.02, 2.18),
	]
	for i in range(corner_positions.size()):
		var disk := CylinderMesh.new()
		disk.top_radius = 0.32
		disk.bottom_radius = 0.36
		disk.height = 0.12
		var disk_node := _make_mesh("CornerDevice%d" % i, disk, brass_mat, corner_positions[i])
		board_root.add_child(disk_node)
		var gem := CylinderMesh.new()
		gem.top_radius = 0.13
		gem.bottom_radius = 0.13
		gem.height = 0.13
		var mat := red_mat if i < 2 else cyan_mat
		board_root.add_child(_make_mesh("CornerGem%d" % i, gem, mat, corner_positions[i] + Vector3(0, 0.08, 0)))
func _add_3d_od_device(board_root: Node3D, cyan_mat: Material, brass_mat: Material) -> void:
	var root := Node3D.new()
	root.name = "ODGaugeDevice"
	root.position = Vector3(-3.55, -0.02, 2.18)
	board_root.add_child(root)
	var base := BoxMesh.new()
	base.size = Vector3(1.55, 0.16, 0.64)
	root.add_child(_make_mesh("GaugeHousing", base, brass_mat, Vector3.ZERO))
	for i in range(5):
		var bar := BoxMesh.new()
		bar.size = Vector3(1.1, 0.035, 0.055)
		root.add_child(_make_mesh("LayerBar%d" % (i + 1), bar, cyan_mat, Vector3(0.08, 0.11, -0.22 + i * 0.11)))
func _add_3d_deck_devices(board_root: Node3D, brass_mat: Material, cyan_mat: Material, red_mat: Material) -> void:
	var device_data := [
		["BossDeckDevice", Vector3(4.05, -0.02, -1.72), red_mat],
		["BossGYDevice", Vector3(4.05, -0.02, -0.96), red_mat],
		["PlayerDeckDevice", Vector3(4.05, -0.02, 1.72), cyan_mat],
		["PlayerGYDevice", Vector3(4.05, -0.02, 0.96), cyan_mat],
	]
	for item in device_data:
		var base := BoxMesh.new()
		base.size = Vector3(0.62, 0.18, 0.45)
		board_root.add_child(_make_mesh(item[0], base, brass_mat, item[1]))
		var light := BoxMesh.new()
		light.size = Vector3(0.38, 0.035, 0.055)
		board_root.add_child(_make_mesh("%s_Light" % item[0], light, item[2], item[1] + Vector3(0, 0.12, 0)))
func _add_3d_boss_core(board_root: Node3D, brass_mat: Material, cyan_mat: Material, red_mat: Material) -> void:
	var boss_core_root := Node3D.new()
	boss_core_root.name = "BossCore"
	boss_core_root.position = Vector3(0, 0.02, -1.72)
	board_root.add_child(boss_core_root)

	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.52
	base_mesh.bottom_radius = 0.62
	base_mesh.height = 0.20
	boss_core_root.add_child(_make_mesh("BaseDisk", base_mesh, brass_mat, Vector3(0, -0.05, 0)))

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.36
	ring_mesh.outer_radius = 0.47
	var ring_mat := _make_mat(Color(0.42, 0.30, 0.16, 1))
	ring_mat.metallic = 0.85
	boss_core_root.add_child(_make_mesh("BaseRing", ring_mesh, ring_mat, Vector3(0, 0.06, 0)))

	var pillar_mat := _make_mat(Color(0.32, 0.28, 0.25, 1))
	pillar_mat.metallic = 0.6
	for i in range(4):
		var angle: float = i * PI / 2.0
		var px: float = sin(angle) * 0.38
		var pz: float = cos(angle) * 0.38
		var p_mesh := CylinderMesh.new()
		p_mesh.top_radius = 0.035
		p_mesh.bottom_radius = 0.04
		p_mesh.height = 0.64
		boss_core_root.add_child(_make_mesh("Pillar%d" % i, p_mesh, pillar_mat, Vector3(px, 0.22, pz)))

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.21
	sphere_mesh.height = 0.42
	var sphere_mat := _make_emissive_mat(Color(0.18, 0.65, 1.0, 1), 0.95)
	sphere_mat.metallic = 0.1
	sphere_mat.roughness = 0.28
	boss_core_root.add_child(_make_mesh("CoreSphere", sphere_mesh, sphere_mat, Vector3(0, 0.24, 0)))

	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.36
	glow_mesh.height = 0.72
	var glow_mat := _make_emissive_mat(Color(0.20, 0.45, 1.0, 0.28), 0.65)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.metallic = 0.0
	glow_mat.roughness = 0.9
	boss_core_root.add_child(_make_mesh("CoreGlow", glow_mesh, glow_mat, Vector3(0, 0.24, 0)))

	var core_light := OmniLight3D.new()
	core_light.name = "CoreLight"
	core_light.light_energy = 0.55
	core_light.light_color = Color(0.35, 0.55, 1.0, 1)
	core_light.omni_range = 3.2
	core_light.position = Vector3(0, 0.26, 0)
	boss_core_root.add_child(core_light)
	_ensure_boss_core_click_area(boss_core_root)
func _get_3d_stage() -> Node3D:
	var vpc := get_node_or_null(NodePath("Battle3DViewport")) as SubViewportContainer
	if not vpc:
		return null
	var vp := vpc.get_node_or_null(NodePath("SubViewport")) as SubViewport
	if not vp:
		return null
	return vp.get_node_or_null(NodePath("BattleStage3D")) as Node3D
# [Fixed func]
func _get_3d_camera() -> Camera3D:
	var stage := _get_3d_stage()
	if not stage:
		return null
	# 鏂拌矾寰? BattleStage3D/CameraRig3D/CameraPitch/CameraDistance/Camera3D
	var cam := stage.get_node_or_null(NodePath("CameraRig3D/CameraPitch/CameraDistance/Camera3D")) as Camera3D
	if cam:
		return cam
	return stage.get_node_or_null(NodePath("Camera3D")) as Camera3D
# ============================================================
# Phase 21F: Camera Orbit 鈥?鎽勫儚鏈鸿建閬撴帶鍒?# ============================================================

## 搴旂敤褰撳墠 orbit 鍙傛暟鍒?CameraRig3D 鑺傜偣鏍?# Phase 23A-V3: Sync camera state to CameraRig3D/Camera3D nodes
func _sync_state_to_scene() -> void:
	if not _camera_state:
		return
	var stage := _get_3d_stage()
	if not stage:
		return
	var rig := stage.get_node_or_null(NodePath("CameraRig3D")) as Node3D
	if not rig:
		return

	rig.rotation_degrees.y = _camera_state.yaw
	rig.position = _camera_rig_origin + _camera_state.pan_offset

	var pitch_node := rig.get_node_or_null(NodePath("CameraPitch")) as Node3D
	if pitch_node:
		pitch_node.rotation_degrees.x = -_camera_state.pitch
		var dist_node := pitch_node.get_node_or_null(NodePath("CameraDistance")) as Node3D
		if dist_node:
			dist_node.position.z = _camera_state.distance

	var cam := _get_3d_camera()
	if cam:
		cam.h_offset = _camera_state.h_offset
		cam.v_offset = _camera_state.v_offset

	# Keep legacy variables in sync for backward compatibility
	_camera_yaw = _camera_state.yaw
	_camera_pitch = _camera_state.pitch
	_camera_distance = _camera_state.distance
	_refresh_terrain_occlusion_after_camera_state()


func _refresh_terrain_occlusion_after_camera_state() -> void:
	if _tactical_terrain_presenter != null and is_instance_valid(_tactical_terrain_presenter):
		_tactical_terrain_presenter.refresh_occlusion(_get_3d_camera())

# Phase 23A-V3: View Controls camera preset management

## Instantiates BattleViewControls and BattleViewCameraState
func _instantiate_view_controls() -> void:
	if _view_controls:
		return  # already instantiated
	_camera_state = BattleViewCameraState.new()
	_view_controls = BattleViewControlsScene.instantiate()
	_view_controls.name = "BattleViewControls"
	add_child(_view_controls)

	# Connect signals
	_view_controls.base_view_requested.connect(_on_base_view_requested)
	_view_controls.top_view_requested.connect(_on_top_view_requested)
	_view_controls.camera_free_view_toggled.connect(_on_camera_free_view_toggled)
	_view_controls.exit_modal_opened.connect(_on_exit_modal_opened)
	_view_controls.exit_modal_closed.connect(_on_exit_modal_closed)
	_view_controls.return_to_menu_confirmed.connect(_on_return_to_menu)

## Cache the original CameraRig3D position once
func _cache_camera_rig_origin() -> void:
	var stage := _get_3d_stage()
	if not stage:
		return
	var rig := stage.get_node_or_null(NodePath("CameraRig3D")) as Node3D
	if rig:
		_camera_rig_origin = rig.position

## Apply initial base preset without animation (called deferred after stage setup)
func _apply_initial_base_preset() -> void:
	if not _camera_state:
		return
	_camera_state.apply_preset("base")
	_sync_state_to_scene()
	if _view_controls:
		_view_controls.set_active_preset("base")
	print("[CAMERA_ORBIT] preset=base (initial) yaw=%.1f pitch=%.1f dist=%.2f h=%.2f v=%.2f" % [_camera_state.yaw, _camera_state.pitch, _camera_state.distance, _camera_state.h_offset, _camera_state.v_offset])

## Animate to a named preset with 0.30s ease-in-out transition
func _animate_to_preset(preset_name: String, target_override: Dictionary = {}) -> void:
	if not _camera_state:
		return
	_safe_kill_camera_tween()

	var from := _camera_state.snapshot()
	var to := target_override.duplicate(true) if not target_override.is_empty() else _camera_target_snapshot(preset_name)
	if _is_reduced_motion_presentation():
		_apply_camera_snapshot(to)
		if _view_controls:
			_view_controls.set_active_preset(preset_name)
		return

	var tween := create_tween()
	_camera_tween = tween
	tween.tween_method(_on_camera_tween_step.bind(from, to), 0.0, 1.0, 0.30).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_on_camera_tween_complete.bind(preset_name, to))


func _camera_target_snapshot(preset_name: String) -> Dictionary:
	if _camera_state == null:
		return {}
	var frame := _compute_tactical_grid_frame()
	if _tactical_terrain_presenter == null or not is_instance_valid(_tactical_terrain_presenter) or not bool(frame.get("ok", false)) or float(frame.get("height_span_world", 0.0)) <= 0.0:
		var preset_state := BattleViewCameraState.new()
		return preset_state.apply_preset(preset_name)
	var fit_state := BattleViewCameraState.new()
	var viewport_size := Vector2(1280.0, 720.0)
	var container := get_node_or_null(NodePath("Battle3DViewport")) as SubViewportContainer
	if container != null and container.size.x > 0.0 and container.size.y > 0.0:
		viewport_size = container.size
	return fit_state.apply_grid_fit(frame, viewport_size, _tactical_grid_presentation_profile, preset_name)


func _apply_camera_snapshot(target: Dictionary) -> void:
	if _camera_state == null or target.is_empty():
		return
	_camera_state.yaw = float(target.get("yaw", _camera_state.yaw))
	_camera_state.pitch = float(target.get("pitch", _camera_state.pitch))
	_camera_state.distance = float(target.get("distance", _camera_state.distance))
	_camera_state.h_offset = float(target.get("h_offset", _camera_state.h_offset))
	_camera_state.v_offset = float(target.get("v_offset", _camera_state.v_offset))
	_camera_state.pan_offset = target.get("pan_offset", _camera_state.pan_offset)
	_camera_state.active_preset = int(target.get("active_preset", _camera_state.active_preset))
	_sync_state_to_scene()

## Interpolation step for camera tween
func _on_camera_tween_step(t: float, from: Dictionary, to: Dictionary) -> void:
	if not _camera_state:
		return
	_camera_state.yaw = lerpf(from.yaw, to.yaw, t)
	_camera_state.pitch = lerpf(from.pitch, to.pitch, t)
	_camera_state.distance = lerpf(from.distance, to.distance, t)
	_camera_state.h_offset = lerpf(from.h_offset, to.h_offset, t)
	_camera_state.v_offset = lerpf(from.v_offset, to.v_offset, t)
	_camera_state.pan_offset = lerp(from.pan_offset, to.pan_offset, t)
	_sync_state_to_scene()

## Completion callback for camera tween
func _on_camera_tween_complete(preset_name: String, target: Dictionary) -> void:
	_apply_camera_snapshot(target)
	if _view_controls:
		_view_controls.set_active_preset(preset_name)
	_camera_tween = null

## Safely kill any running camera tween
func _safe_kill_camera_tween() -> void:
	if _camera_tween and is_instance_valid(_camera_tween):
		_camera_tween.kill()
	_camera_tween = null

# 鈹€鈹€ View Controls signal handlers 鈹€鈹€

func _on_base_view_requested() -> void:
	if _is_monster_summon_interaction_active():
		return
	_set_camera_free_view_enabled(false)
	_cancel_camera_pan()
	# Phase 26E-R1 Task 5: cancel lane selection on view switch
	_cancel_lane_selection(&"view_switch")
	_animate_to_preset("base")
	if _view_controls:
		_view_controls.set_active_preset("base")

func _on_top_view_requested() -> void:
	if _is_monster_summon_interaction_active():
		return
	_set_camera_free_view_enabled(false)
	_cancel_camera_pan()
	# Phase 26E-R1 Task 5: cancel lane selection on view switch
	_cancel_lane_selection(&"view_switch")
	_animate_to_preset("top")
	if _view_controls:
		_view_controls.set_active_preset("top")

func _on_camera_free_view_toggled(enabled: bool) -> void:
	if _is_monster_summon_interaction_active():
		return
	_set_camera_free_view_enabled(enabled)

func _set_camera_free_view_enabled(enabled: bool) -> void:
	if _camera_free_view_enabled == enabled:
		if _view_controls:
			_view_controls.set_free_view_active(enabled)
		return
	_camera_free_view_enabled = enabled
	if not enabled:
		_camera_orbit_dragging = false
		_cancel_camera_pan()
	if _view_controls:
		_view_controls.set_free_view_active(enabled)
	if enabled:
		print("[CAMERA_MODE] free_view=ON")
	else:
		print("[CAMERA_MODE] free_view=OFF")

func _on_exit_modal_opened() -> void:
	_cleanup_structure_presentation_lifecycle(&"exit_modal")
	# Phase 23B-R2: cancel building replace on exit modal
	_cancel_building_replace_selection("exit_modal", false)
	_set_camera_free_view_enabled(false)
	_exit_modal_active = true
	_camera_orbit_dragging = false
	_cancel_camera_pan()
	# Only kill tween + mark FREE if a preset transition was actually running
	if _camera_tween and is_instance_valid(_camera_tween):
		_safe_kill_camera_tween()
		if _camera_state:
			_camera_state.mark_manual()
			_sync_state_to_scene()
		if _view_controls:
			_view_controls.set_active_preset("free")

func _on_exit_modal_closed() -> void:
	_exit_modal_active = false

# Phase 23A-V4: Middle-mouse pan helpers

## UI gate: allow MMB pan over Battle3DViewport area, including BattleTable descendants,
## but deny explicit interactive UI blockers (cards, deck slots, detail panel, etc.).
func _is_camera_pan_start_allowed(screen_position: Vector2, hovered: Control) -> bool:
	var vpc := get_node_or_null(NodePath("Battle3DViewport")) as SubViewportContainer
	if vpc == null or not vpc.get_global_rect().has_point(screen_position):
		return false
	var table := get_node_or_null(NodePath("BattleTable")) as Control
	# Fast path: null, self, vpc, or exact table match
	if hovered == null or hovered == self or hovered == vpc or hovered == table:
		return true
	# Explicit interactive blockers 鈥?always deny
	if _is_control_or_descendant_of_blocker(hovered):
		return false
	# BattleTable descendant 鈥?allow (board area including slots, player table, internal layouts)
	if table and _is_descendant_of(hovered, table):
		return true
	# Everything else 鈥?deny (root-level UI, CanvasLayer overlays, etc.)
	return false


## Returns true if `node` is a descendant of `ancestor` (walking up parent chain).
## Accepts Node (not just Control) so CanvasLayer blockers work correctly.
func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current: Node = node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


## Returns true if `control` is a known interactive UI blocker or one of its descendants.
## Blockers are checked by NodePath; missing nodes are safely skipped.
func _is_control_or_descendant_of_blocker(control: Control) -> bool:
	const blocker_paths: Array[String] = [
		"DetailPanelSlot",
		"RightTrack",
		"HandArea",
		"BattleTable/CoreStatusPanel",
		"BattleTable/ArsenalPanel",
		"BattleTable/BossDeckSlot",
		"BattleTable/PlayerDeckSlot",
		"BattleViewControls",
		"MonsterCommandLayer/MonsterCommandMenu",
	]
	for bp in blocker_paths:
		var blocker := get_node_or_null(NodePath(bp))
		if blocker and _is_descendant_of(control, blocker):
			return true
	return false


## Begin pan if conditions allow. Returns true if pan started.
func _try_begin_camera_pan(screen_position: Vector2, hovered: Control) -> bool:
	# 鈹€鈹€ V4-R3 diagnostic log (only on MMB press, not on continuous motion) 鈹€鈹€
	var allowed := _is_camera_pan_start_allowed(screen_position, hovered)
	var hovered_path := "<null>"
	var filter_str := "null"
	if hovered:
		hovered_path = str(hovered.get_path())
		filter_str = str(hovered.mouse_filter)
	print("[PAN_INPUT] pos=", screen_position, " hovered_path=", hovered_path,
		" filter=", filter_str, " allowed=", allowed,
		" frozen=", _camera_orbit_frozen, " modal=", _exit_modal_active)

	if battle_ended or _camera_orbit_frozen or _exit_modal_active:
		return false
	if not allowed:
		return false
	_camera_orbit_dragging = false
	_camera_pan_dragging = true
	return true


## Cancel any active pan drag. Safe to call even when not dragging.
func _cancel_camera_pan() -> void:
	_camera_pan_dragging = false


## Convert screen-relative mouse delta to world XZ pan delta.
func _screen_pan_to_world_delta(relative: Vector2) -> Vector3:
	if relative.is_zero_approx() or _camera_state == null:
		return Vector3.ZERO
	var cam := _get_3d_camera()
	if cam == null:
		return Vector3.ZERO

	var right := Vector3(cam.global_transform.basis.x.x, 0.0, cam.global_transform.basis.x.z)
	var up := Vector3(cam.global_transform.basis.y.x, 0.0, cam.global_transform.basis.y.z)

	if right.length_squared() < 0.000001 or up.length_squared() < 0.000001:
		var yaw_basis := Basis(Vector3.UP, deg_to_rad(_camera_state.yaw))
		right = Vector3(yaw_basis.x.x, 0.0, yaw_basis.x.z)
		up = Vector3(-yaw_basis.z.x, 0.0, -yaw_basis.z.z)

	right = right.normalized()
	up = up.normalized()
	var distance_scale := clampf(
		_camera_state.distance / CAMERA_PAN_DISTANCE_REFERENCE,
		CAMERA_PAN_DISTANCE_SCALE_MIN,
		CAMERA_PAN_DISTANCE_SCALE_MAX
	)
	var sensitivity := CAMERA_PAN_WORLD_UNITS_PER_PIXEL * distance_scale
	return (-right * relative.x + up * relative.y) * sensitivity


## Apply a screen-relative pan delta through the camera state.
func _apply_camera_pan_relative(relative: Vector2) -> Vector3:
	if relative.is_zero_approx() or _camera_state == null:
		return Vector3.ZERO
	_safe_kill_camera_tween()
	var requested := _screen_pan_to_world_delta(relative)
	if requested.is_zero_approx():
		return Vector3.ZERO
	var applied := _camera_state.apply_pan_world_delta(requested)
	_sync_state_to_scene()
	if _view_controls:
		_view_controls.set_active_preset("free")
	return applied


func _is_screen_position_in_3d_viewport(screen_position: Vector2) -> bool:
	var vpc := get_node_or_null(NodePath("Battle3DViewport")) as SubViewportContainer
	if not vpc:
		return false
	return vpc.get_global_rect().has_point(screen_position)


func _is_mouse_in_3d_viewport() -> bool:
	return _is_screen_position_in_3d_viewport(get_viewport().get_mouse_position())
## _ensure_card_token_root_3d
func _ensure_card_token_root_3d(p_parent: Node3D = null) -> void:
	if p_parent == null:
		p_parent = _get_3d_stage()
	if p_parent == null:
		_card_token_root_3d = null
		return
	var existing := p_parent.get_node_or_null(NodePath("CardTokenRoot3D")) as Node3D
	if existing == null:
		existing = Node3D.new()
		existing.name = "CardTokenRoot3D"
		p_parent.add_child(existing)
	_card_token_root_3d = existing

	# Phase 21H keeps a single token authority. Remove the legacy full-rebuild root.
	var legacy_root := p_parent.get_node_or_null(NodePath("CardTokens")) as Node3D
	if legacy_root != null and legacy_root != _card_token_root_3d:
		p_parent.remove_child(legacy_root)
		legacy_root.queue_free()
func _sync_3d_board_tokens() -> void:
	if context == null or context.player == null or context.enemy == null:
		return
	var stage := _get_3d_stage()
	if stage == null:
		return

	var token_root := stage.get_node_or_null(NodePath("CardTokens")) as Node3D
	if token_root:
		for child in token_root.get_children():
			if is_instance_valid(child):
				token_root.remove_child(child)
				child.queue_free()
	else:
		token_root = Node3D.new()
		token_root.name = "CardTokens"
		stage.add_child(token_root)

	_add_3d_tokens_for_cards(token_root, context.enemy.traps, "boss", "back")
	_add_3d_tokens_for_cards(token_root, context.enemy.field, "boss", "front")
	_add_3d_tokens_for_cards(token_root, context.player.field, "player", "front")
	_add_3d_tokens_for_cards(token_root, context.player.traps, "player", "back")
func _add_3d_tokens_for_cards(root: Node3D, cards: Array, owner_side: String, row_kind: String) -> void:
	var count := mini(cards.size(), 5)
	for i in range(count):
		var card := cards[i] as CardData
		if card == null:
			continue
		root.add_child(_make_3d_card_token(card, owner_side, row_kind, i))
func _get_board_piece_registry():
	# Phase 22C: 杩斿洖绫诲瀷閫氳繃 BoardPieceRegistryClass 纭畾
	if _board_piece_registry == null:
		_board_piece_registry = BoardPieceRegistryClass.new()
		_board_piece_registry.load_from_config(BOARD_PIECE_MODEL_CONFIG)
	return _board_piece_registry
func reload_board_piece_models() -> void:
	_board_piece_registry = BoardPieceRegistryClass.new()
	_board_piece_registry.load_from_config(BOARD_PIECE_MODEL_CONFIG)
	_sync_3d_field_tokens()
func register_board_piece_model(card_id: String, scene_path: String) -> void:
	_get_board_piece_registry().register_piece(card_id, scene_path)
	_sync_3d_field_tokens()
func unregister_board_piece_model(card_id: String) -> void:
	_get_board_piece_registry().unregister_piece(card_id)
	_sync_3d_field_tokens()
func _make_3d_card_token(card: CardData, owner_side: String, row_kind: String, slot_idx: int, field_index: int = -1) -> Node3D:
	# Phase 22E-1: CardCarrier3D replaces BoxMesh placeholders
	var token := Node3D.new()
	token.name = "Token_%s_%s_%d" % [owner_side, row_kind, slot_idx]

	# Meta keys for click bridge and card tracking
	token.set_meta("card_id", card.card_id)
	token.set_meta("card_name", card.card_name)
	token.set_meta("owner_side", owner_side)
	token.set_meta("row_kind", row_kind)
	token.set_meta("card", card)
	token.set_meta("side", owner_side)
	token.set_meta("zone", row_kind)
	token.set_meta("slot_index", slot_idx)
	# Phase 22F-5R: field_index is the logical array position (for click/command), slot_index is visual
	if field_index < 0:
		token.set_meta("field_index", slot_idx)
	else:
		token.set_meta("field_index", field_index)
	token.set_meta("visual_slot_index", slot_idx)

	# Scale based on row
	var scale_val := CARRIER_SCALE_FRONT if row_kind == "front" else CARRIER_SCALE_BACK
	token.scale = Vector3(scale_val, scale_val, scale_val)

	# Phase 23C0: Y offset computed from carrier AABB bottom + board surface
	var surface_y := _get_board_surface_y(owner_side, row_kind)
	var target_gap := _get_board_carrier_gap()
	token.set_meta("_surface_y", surface_y)
	token.set_meta("_target_gap", target_gap)

	# Minimal Y offset 鈥?carrier bottom sits at surface + tiny safety margin
	var y_off: float = CARRIER_Y_SURFACE
	token.set_meta("y_offset", y_off)

	# Instantiate CardCarrier3D as child
	var carrier: Node3D = CardCarrierScene.instantiate()
	carrier.name = "CardCarrier"
	token.add_child(carrier)

	# Configure card art and glow after assembly
	if carrier.has_method("configure_card"):
		carrier.configure_card(card, owner_side, row_kind)

	# Boss token: rotate 180 around Y so art faces boss direction
	if owner_side == "boss":
		token.rotation_degrees.y = 180

	# Phase 27E-R3: Card ID badge (Label3D)
	_add_card_id_label(token, card, owner_side)
	# HitArea is inside the carrier scene (layer bit 20). No duplicate needed.
	print("[TOKEN_CARRIER] side=%s zone=%s index=%d scale=%.2f y_off=%.3f" % [owner_side, row_kind, slot_idx, scale_val, y_off])
	return token
# Phase 27E-R3: Add Label3D card ID badge above a 3D board token
func _add_card_id_label(token: Node3D, card: CardData, owner_side: String) -> void:
	if token == null or card == null:
		return
	# Validate card_id: must be non-empty, not instance_id, not null-like
	var cid: String = card.card_id
	if cid.is_empty() or cid.begins_with("@") or cid == "null" or cid.begins_with("uid:"):
		return
	# Only show for valid IDs like P02, P07, P15, A06
	if cid.length() < 2 or cid.length() > 8:
		return
	# Card ID line
	var label := Label3D.new()
	label.name = "CardIDLabel"
	label.visible = not bool(get_meta("player_trial", false))
	label.text = cid
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0018
	label.font_size = 18
	label.outline_size = 2
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.75)
	# Color by side: player = cyan-white, boss = orange-red
	if owner_side == "boss":
		label.modulate = Color(1.0, 0.44, 0.18, 1.0)
	else:
		label.modulate = Color(0.5, 0.85, 1.0, 1.0)
	label.position = Vector3(0.0, 0.34, 0.0)
	token.add_child(label)
	# Phase 27E-R5: compact combat stats line below card ID
	var badge := Label3D.new()
	badge.name = "CombatBadge"
	badge.text = ""
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.no_depth_test = true
	badge.fixed_size = true
	badge.pixel_size = 0.0016
	badge.font_size = 14
	badge.outline_size = 2
	badge.outline_modulate = Color(0.0, 0.0, 0.0, 0.75)
	if owner_side == "boss":
		badge.modulate = Color(1.0, 0.40, 0.15, 1.0)
	else:
		badge.modulate = Color(0.7, 0.88, 1.0, 1.0)
	badge.position = Vector3(0.0, 0.26, 0.0)
	token.add_child(badge)

func _get_3d_slot_pos(owner_side: String, row_kind: String, slot_idx: int) -> Vector3:
	# Phase 21C: 浼樺厛浠?SlotAnchors3D 璇诲彇浣嶇疆
	var anchor := _get_3d_anchor_for_zone(owner_side, row_kind, slot_idx)
	if anchor != null and is_instance_valid(anchor):
		return anchor.position

	var xs: Array[float] = [-3.0, -1.5, 0.0, 1.5, 3.0]
	var z_pos := 0.95
	if owner_side == "boss":
		z_pos = -0.95 if row_kind == "front" else -1.75
	else:
		z_pos = 0.95 if row_kind == "front" else 1.75
	return Vector3(xs[clampi(slot_idx, 0, xs.size() - 1)], 0.0, z_pos)
## Phase 26B-T4: Ensure full-screen CombatVFXRoot exists for attack lines and VFX.
func _ensure_combat_vfx_root() -> Control:
	if _combat_vfx_root != null and is_instance_valid(_combat_vfx_root):
		return _combat_vfx_root
	_combat_vfx_root = Control.new()
	_combat_vfx_root.name = "CombatVFXRoot"
	_combat_vfx_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_combat_vfx_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_vfx_root.z_index = 60  # above everything except cursor
	add_child(_combat_vfx_root)
	print("[26B-T4] CombatVFXRoot created (full-screen)")
	return _combat_vfx_root


# Phase 23C0: Get board surface Y from CloudGateBoardRuntime for a zone.
func _get_board_surface_y(_side: String, zone: String) -> float:
	if _board_runtime and is_instance_valid(_board_runtime) and _board_runtime.is_glb_loaded():
		return _board_runtime.get_board_surface_y_for_zone(zone)
	# Fallback to old constants (from TSCN design values)
	if zone == "front":
		return 0.48
	return 0.42


func _get_board_carrier_gap() -> float:
	if _board_runtime and is_instance_valid(_board_runtime) and _board_runtime.is_glb_loaded():
		return _board_runtime.get_target_carrier_gap()
	return 0.015


## Phase 23C0: Compute grounded Y position for a token's carrier.
## Uses board surface Y + carrier local AABB bottom to place carrier on the surface.
## Pure computation 鈥?does NOT use screen coords or accumulative displacement.
func _compute_carrier_grounded_y(token: Node3D, _side: String, zone: String) -> float:
	var surface_y: float = _get_board_surface_y(_side, zone)
	var target_gap: float = _get_board_carrier_gap()

	# Effective scale from token's world basis (accounts for parent chain)
	var eff_scale_y: float = abs(token.global_basis.get_scale().y) if is_instance_valid(token) else 1.0
	if eff_scale_y < 0.0001:
		eff_scale_y = 1.0

	# Try carrier-internal computation with correct effective scale
	var carrier: Node3D = token.get_node_or_null("CardCarrier") as Node3D
	if carrier and is_instance_valid(carrier) and carrier.has_method("compute_contact_y"):
		var result: Dictionary = carrier.compute_contact_y(surface_y, target_gap, eff_scale_y)
		if result.get("ok", false):
			var grounded_y: float = result.get("carrier_y", surface_y + target_gap + 0.08)
			token.set_meta("_last_grounded_y", grounded_y)
			token.set_meta("_ground_local_bottom_y", result.get("local_bottom_y", 0.0))
			token.set_meta("_ground_actual_gap", result.get("actual_gap", 0.0))
			return grounded_y

	# Fallback: estimate from token scale and known carrier dimensions
	# local_bottom 鈮?-0.08 (unscaled), so grounded_y = surface + gap - local_bottom * scale
	var est_local_bottom: float = -0.08
	var grounded_y: float = surface_y + target_gap - est_local_bottom * eff_scale_y
	token.set_meta("_last_grounded_y", grounded_y)
	return grounded_y


func _build_3d_token_key(side: String, zone: String, index: int) -> String:
	return "%s_%s_%d" % [side, zone, index]
# Phase 22B-R: 鎶曞奖楠岃瘉宸﹀彸/鍓嶅悗鏂瑰悜
## Phase 22C-R: Runtime marker debug spheres for GUI calibration
func _add_debug_markers_to_runtime_sockets() -> void:
	if not _board_runtime or not is_instance_valid(_board_runtime):
		return
	var markers: Array = _board_runtime.get_all_socket_markers()
	if markers.is_empty():
		return
	var colors := {
		"P_FRONT": Color(0.16, 0.62, 1.0, 1),
		"P_BACK": Color(0.16, 0.95, 0.56, 1),
		"B_FRONT": Color(1.0, 0.28, 0.08, 1),
		"B_BACK": Color(0.65, 0.14, 0.06, 1),
		"ACTION_SLOT": Color(0.85, 0.85, 0.40, 1),
		"BOSS_CORE": Color(1.0, 0.12, 0.30, 1),
		"PLAYER_DECK": Color(0.16, 0.75, 1.0, 1),
		"PLAYER_GY": Color(0.14, 0.55, 0.70, 1),
		"BOSS_DECK": Color(1.0, 0.40, 0.12, 1),
		"BOSS_GY": Color(0.75, 0.30, 0.10, 1),
		"OD_DOCK": Color(0.75, 0.20, 0.95, 1),
	}
	var count := 0
	for m: Marker3D in markers:
		if not is_instance_valid(m):
			continue
		# Determine color from name prefix
		var dc := Color(1, 1, 1, 1)
		for prefix in colors:
			if m.name.begins_with(prefix):
				dc = colors[prefix]
				break
		var sphere := SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "DebugMarker"
		mesh_inst.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = dc
		mat.emission_enabled = true
		mat.emission = dc
		mat.emission_energy_multiplier = 0.6
		mesh_inst.material_override = mat
		m.add_child(mesh_inst)
		count += 1
	print("[DEBUG_MARKER] Added %d debug spheres to runtime socket markers" % count)

func _debug_project_slot_anchors() -> void:
	var cam := _get_3d_camera()
	if not cam:
		return
	var p0 := _get_3d_slot_pos("player", "front", 0)
	var p4 := _get_3d_slot_pos("player", "front", 4)
	var b0 := _get_3d_slot_pos("boss", "front", 0)
	var b4 := _get_3d_slot_pos("boss", "front", 4)
	# 闇€瑕佸姞涓?BoardSpace3D 鐨勫叏灞€鍙樻崲
	var bs := _get_3d_stage()
	if bs:
		var bspace := bs.get_node_or_null(NodePath("BoardSpace3D")) as Node3D
		if bspace:
			p0 = bspace.global_transform * p0
			p4 = bspace.global_transform * p4
			b0 = bspace.global_transform * b0
			b4 = bspace.global_transform * b4
	var sp0 := cam.unproject_position(p0)
	var sp4 := cam.unproject_position(p4)
	var sb0 := cam.unproject_position(b0)
	var sb4 := cam.unproject_position(b4)
	# Phase 22F-6: yaw鈮?0掳鏃?Z+鈫掑睆骞曞乏, slot_0(Z=-3.60)鈫掑睆骞曞彸, slot_4鈫掑睆骞曞乏
	var p_front_order := "correct" if sp0.x > sp4.x else "REVERSED"
	var b_front_order := "correct" if sb0.x > sb4.x else "REVERSED"
	print("[22B-R_PROJECTION] P_FRONT_0 screen=(%.0f,%.0f) P_FRONT_4 screen=(%.0f,%.0f) order=%s" % [sp0.x, sp0.y, sp4.x, sp4.y, p_front_order])
	print("[22B-R_PROJECTION] B_FRONT_0 screen=(%.0f,%.0f) B_FRONT_4 screen=(%.0f,%.0f) order=%s" % [sb0.x, sb0.y, sb4.x, sb4.y, b_front_order])
func _update_3d_card_token(token: Node3D, card: CardData, side: String, zone: String, visual_index: int, field_index: int = -1, compact_z: Variant = null) -> void:
	var compact_offset: float = NAN if compact_z == null else float(compact_z)
	if not is_instance_valid(token):
		return

	var anchor := _get_3d_anchor_for_zone(side, zone, visual_index)
	# Phase 23C0: Use board surface + carrier AABB grounding + compact formation
	if anchor != null and is_instance_valid(anchor):
		var carrier_y := _compute_carrier_grounded_y(token, side, zone)
		var z_val: float = anchor.global_position.z
		if not is_nan(compact_offset):
			var center_anchor: Node3D = _get_3d_anchor_for_zone(side, zone, 2)
			if center_anchor and is_instance_valid(center_anchor):
				z_val = center_anchor.global_position.z + compact_offset
		token.global_position = Vector3(anchor.global_position.x, carrier_y, z_val)
		if side == "boss":
			token.rotation_degrees.y = 180
		else:
			token.rotation_degrees.y = 0

	# Phase 22F-5R: 浣嶇疆 meta 姣忔鍚屾蹇呴』鏇存柊锛堝崱鐗屽彲鑳藉洜鍏朵粬鍗＄鍦鸿€岄噸鏂板眳涓級
	token.set_meta("side", side)
	token.set_meta("zone", zone)
	token.set_meta("slot_index", visual_index)
	token.set_meta("visual_slot_index", visual_index)
	if field_index >= 0:
		token.set_meta("field_index", field_index)

	# Phase 25E-R1: token identity follows the runtime CardData instance, not
	# card_id. Duplicate templates can coexist; after one dies the next instance
	# compacts into the same logical index and must replace the stale reference.
	var old_card := token.get_meta("card", null) as CardData
	var old_id := str(token.get_meta("card_id", ""))
	var old_name := str(token.get_meta("card_name", ""))
	var identity_changed := old_card != card or old_id != card.card_id or old_name != card.card_name
	token.set_meta("card", card)
	token.set_meta("card_id", card.card_id)
	token.set_meta("card_name", card.card_name)
	if identity_changed:
		# Reconfigure embedded carrier
		var carrier := token.get_node_or_null("CardCarrier")
		if carrier and carrier.has_method("configure_card"):
			carrier.configure_card(card, side, zone)
	# Phase 25E: refresh combat stats every sync (HP changes while identity stays)
	_apply_runtime_stats_to_token(token, card, zone)
## 濞撳懘娅庢稉宥呭晙濞叉槒绌惃?token

	# Phase 26B-T3: idempotent baseline restore - scale must return to standard
	_reset_token_presentation(token, side, zone)


## Phase 26B-T3: Token presentation baseline API
## TokenRoot scale/rotation must be idempotently restored every sync.

func _get_standard_token_scale(side: String, zone: String) -> Vector3:
	var scale_val: float = CARRIER_SCALE_FRONT if zone == "front" else CARRIER_SCALE_BACK
	return Vector3(scale_val, scale_val, scale_val)


func _reset_token_presentation(token: Node3D, side: String, zone: String) -> void:
	## Idempotent: restore TokenRoot to standard scale and rotation.
	if not is_instance_valid(token):
		return
	var std_scale: Vector3 = _get_standard_token_scale(side, zone)
	if not is_equal_approx(token.scale.x, std_scale.x) or not is_equal_approx(token.scale.y, std_scale.y) or not is_equal_approx(token.scale.z, std_scale.z):
		token.scale = std_scale
	if side == "boss":
		token.rotation_degrees.y = 180
	else:
		token.rotation_degrees.y = 0
	# Also reset CardCarrier visual transform
	var carrier: Node3D = get_token_visual(token)
	if carrier and is_instance_valid(carrier):
		carrier.transform = Transform3D.IDENTITY


func get_token_visual(token: Node3D) -> Node3D:
	## Return the CardCarrier visual child, or the token itself as fallback.
	if token == null or not is_instance_valid(token):
		return null
	var carrier := token.get_node_or_null("CardCarrier") as Node3D
	if carrier and is_instance_valid(carrier):
		return carrier
	return token


func get_token_combat_anchor_world(token: Node3D) -> Vector3:
	## Return world position for attack-line endpoints.
	if token == null or not is_instance_valid(token):
		return Vector3.ZERO
	var visual: Node3D = get_token_visual(token)
	if visual and is_instance_valid(visual):
		return visual.global_position
	return token.global_position


func _clear_missing_3d_tokens(active_keys: Dictionary) -> void:
	var keys_to_remove: Array[String] = []
	for key in _card_token_nodes.keys():
		if not active_keys.has(key):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		var token = _card_token_nodes.get(key)
		if token != null and is_instance_valid(token):
			token.queue_free()
		_card_token_nodes.erase(key)

func _get_3d_token_for_card(card: CardData) -> Node3D:
	if card == null:
		return null
	for key in _card_token_nodes.keys():
		var token := _card_token_nodes.get(key) as Node3D
		if token == null or not is_instance_valid(token):
			continue
		var token_card := token.get_meta("card", null) as CardData
		if token_card != null and _same_card_ref_or_id(token_card, card):
			return token
	return null

func _project_3d_token_to_screen(token: Node3D) -> Vector2:
	if token == null or not is_instance_valid(token):
		return Vector2.INF
	var cam := _get_3d_camera()
	if cam == null:
		return Vector2.INF
	var vpc := get_node_or_null(NodePath("Battle3DViewport")) as SubViewportContainer
	var offset := Vector2.ZERO
	if vpc:
		offset = vpc.get_global_rect().position
	return offset + cam.unproject_position(token.global_position)

func _set_3d_command_target_highlight(card: CardData, active: bool) -> void:
	var token := _get_3d_token_for_card(card)
	if token == null:
		return
	var carrier: Node = token.get_node_or_null("CardCarrier")
	if carrier and carrier.has_method("set_command_target_highlight"):
		carrier.set_command_target_highlight(active)
## Phase 27B-R2: Token root cell-positioning helper.
## Reads battle.get_unit_cell(card) full Vector2i, resolves real
## anchor via _get_3d_anchor_for_cell(), and positions the token.
## Returns true on success; false triggers old zone/lane fallback.
func _apply_token_root_cell_position(token: Node3D, card: CardData, owner_side: String, row_kind: String) -> bool:
	if token == null or not is_instance_valid(token):
		return false
	if card == null or battle == null:
		return false
	# Phase D1: an active assignment presents the existing token at the
	# structure socket. The authoritative occupied cell remains in BattleSystem.
	if battle.has_method("get_garrison_state_for_unit") and _tactical_structure_presenter != null \
			and is_instance_valid(_tactical_structure_presenter):
		var assignment: Dictionary = battle.get_garrison_state_for_unit(card)
		if assignment.get("state") == &"active":
			var socket_transform: Transform3D = _tactical_structure_presenter.get_structure_socket_global_transform(
				StringName(str(assignment.get("structure_id", &""))),
				StringName(str(assignment.get("socket_name", &"Garrison0")))
			)
			if socket_transform != Transform3D():
				token.global_transform = socket_transform
				token.set_meta("garrison_presented", true)
				token.set_meta("board_cell", assignment.get("parent_cell", Vector2i(-1, -1)))
				return true

	# 1. Get full cell from BattleSystem authority
	var cell: Vector2i = battle.get_unit_cell(card)
	if cell == Vector2i(-1, -1):
		# Back-row cards represent structures/pieces on real grid cells too.
		# Keep the existing clickable carrier, anchored to its committed owner.
		var structures: Dictionary = battle.get_structure_snapshot().get("structures", {})
		for structure: Dictionary in structures.values():
			if int(structure.get("source_runtime_id", 0)) == card.get_instance_id():
				cell = structure.get("cell", Vector2i(-1, -1))
				break
		if cell == Vector2i(-1, -1):
			cell = battle._anchor_cell_of_rid(card.get_instance_id())
	if cell.x < 0 or cell.x >= 5 or cell.y < 0 or cell.y >= 5:
		return false

	# 2. Resolve cell-anchored 3D position
	var base_anchor := _get_3d_anchor_for_cell(cell)
	var surface_anchor := _get_3d_surface_anchor_for_cell(cell)
	if base_anchor == null or surface_anchor == null or not is_instance_valid(base_anchor) or not is_instance_valid(surface_anchor):
		return false

	# 3. Grounded Y via carrier AABB
	var carrier_y: float = _compute_carrier_grounded_y(token, owner_side, row_kind)
	var terrain_offset := surface_anchor.global_position.y - base_anchor.global_position.y

	# 4. Position: X and Z from cell anchor, Y from carrier grounding
	token.global_position = Vector3(surface_anchor.global_position.x, carrier_y + terrain_offset, surface_anchor.global_position.z)

	# 5. Facing
	if owner_side == "boss":
		token.rotation_degrees.y = 180
	else:
		token.rotation_degrees.y = 0

	# 6. Write token meta (idempotent)
	token.set_meta("side", owner_side)
	token.set_meta("zone", row_kind)
	token.set_meta("board_cell", cell)

	return true

## Phase 22C-R: Token 鍏ユ爲鍚庣粺涓€璁剧疆 global_position
## 姝ｇ‘椤哄簭锛氬垱寤?Token 鈫?add_child 鈫?浣跨敤 Anchor global_transform 鏇存柊浣嶇疆
func _apply_token_root_position(token: Node3D, owner_side: String, row_kind: String, slot_idx: int, compact_z: Variant = null) -> void:
	var compact_offset: float = NAN if compact_z == null else float(compact_z)
	# Phase 23C0: Use center socket for X, compact Z offset for visual placement
	var center_anchor: Node3D = _get_3d_anchor_for_zone(owner_side, row_kind, 2)  # index 2 = center socket
	var carrier_y := _compute_carrier_grounded_y(token, owner_side, row_kind)

	if center_anchor and is_instance_valid(center_anchor):
		if not is_nan(compact_offset):
			# Compact formation: center X + computed Z offset
			token.global_position = Vector3(center_anchor.global_position.x, carrier_y, center_anchor.global_position.z + compact_offset)
		else:
			# Fallback: individual anchor position
			var anchor: Node3D = _get_3d_anchor_for_zone(owner_side, row_kind, slot_idx)
			if anchor and is_instance_valid(anchor):
				token.global_position = Vector3(anchor.global_position.x, carrier_y, anchor.global_position.z)
			else:
				token.position = Vector3(center_anchor.position.x, carrier_y, center_anchor.position.z + compact_offset if not is_nan(compact_offset) else 0.0)
	else:
		var fallback_pos := _get_3d_slot_pos(owner_side, row_kind, slot_idx)
		if not is_nan(compact_offset):
			fallback_pos.z += compact_offset
		token.position = Vector3(fallback_pos.x, carrier_y, fallback_pos.z)
	## Sync field cards to 3D tokens (called after each _refresh_tables())
## Phase 22F-5R: 涓轰竴琛屽崱鐗岃绠楀眳涓悗鐨?visual_slot_index 鏄犲皠
## 杩斿洖 Dictionary[logical_index] = visual_slot_index
func _compute_centered_slot_map(cards: Array, total_slots: int = 5) -> Dictionary:
	var valid_count := 0
	for c in cards:
		if c != null:
			valid_count += 1
	var centered := PlayerTable.get_centered_slot_indices(valid_count, total_slots)
	var result: Dictionary = {}
	var vi := 0
	for i in cards.size():
		if cards[i] != null and vi < centered.size():
			result[i] = centered[vi]
			vi += 1
	return result

## Phase 23C0: Compute compact Z-axis offsets for `count` cards around a center origin.
## Pure function 鈥?no screen coords, no state, idempotent.
## Default spacing 鈮?1.4m. Max span for count=5 is 5.6m.
static func compute_compact_formation_offsets(count: int, spacing: float = 1.4) -> Array[float]:
	var offsets: Array[float] = []
	if count <= 0:
		return offsets
	if count == 1:
		offsets.append(0.0)
		return offsets
	var total_span: float = float(count - 1) * spacing
	var start: float = -total_span / 2.0
	for i in range(count):
		offsets.append(start + float(i) * spacing)
	return offsets

func _sync_3d_field_tokens() -> void:
	# Deferred refreshes may outlive removal from the tree during restart.
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if not USE_3D_CARD_TOKENS:
		return
	if context == null or context.player == null or context.enemy == null:
		return
	if _card_token_root_3d == null or not is_instance_valid(_card_token_root_3d):
		_ensure_card_token_root_3d()
		if _card_token_root_3d == null:
			return

	var active_keys: Dictionary = {}
	var current_maps: Dictionary = {}

	# Phase 22F-5R: 鍥涙帓缁熶竴浣跨敤涓績闃靛瀷 slot mapping
	var rows := [
		{"cards": context.player.field, "side": "player", "zone": "front"},
		{"cards": context.player.traps, "side": "player", "zone": "back"},
		{"cards": context.enemy.field, "side": "boss", "zone": "front"},
		{"cards": context.enemy.traps, "side": "boss", "zone": "back"},
	]
	for row in rows:
		var cards: Array = row["cards"]
		var side: String = row["side"]
		var zone: String = row["zone"]
		var slot_map := _compute_centered_slot_map(cards, 5)
		current_maps["%s_%s" % [side, zone]] = slot_map

		# Phase 23C0: Compute compact formation Z offsets for this row
		var valid_count := 0
		for c in cards:
			if c != null:
				valid_count += 1
		var compact_offsets: Array[float] = compute_compact_formation_offsets(valid_count)
		var offset_idx := 0

		for i in cards.size():
			var card = cards[i]
			if card == null:
				continue
			# Phase 26E-R1: front-row monsters use authority lane anchor
			var is_lane_front: bool = zone == "front" and (card.card_family == "monster" or card.card_type == CardData.CardType.UNIT)
			var visual_i: int
			var compact_z: float
			var key: String
			if is_lane_front and battle:
				visual_i = battle.get_unit_lane(card)
				if visual_i < 0:
					# Phase 27C-R1-R2: 表现层不得创建/注册 UnitCombatState
					# 前排单位缺少 lane → TOKEN STATE ERROR，使用上一个安全位置
					push_warning("[TOKEN STATE ERROR] card=%s runtime_id=%d — no lane/state; using slot fallback" % [card.card_name, card.get_instance_id()])
					visual_i = slot_map.get(i, i)
				compact_z = NAN
				key = "%s_%s_unit_%d" % [side, zone, card.get_instance_id()]
			else:
				visual_i = slot_map.get(i, i)
				compact_z = compact_offsets[offset_idx] if offset_idx < compact_offsets.size() else 0.0
				offset_idx += 1
				key = _build_3d_token_key(side, zone, i)
			active_keys[key] = true
			var existing = _card_token_nodes.get(key)
			if existing != null and is_instance_valid(existing):
				_update_3d_card_token(existing, card, side, zone, visual_i, i, compact_z)
				# Phase 27B-R2: Override old lane anchor with full cell position
				_apply_token_root_cell_position(existing, card, side, zone)
			else:
				var token := _make_3d_card_token(card, side, zone, visual_i, i)
				_card_token_root_3d.add_child(token)
				# Phase 27B-R2: Use cell anchor first; fallback to old zone/lane
				var cell_positioned := _apply_token_root_cell_position(token, card, side, zone)
				if not cell_positioned:
					_apply_token_root_position(token, side, zone, visual_i, compact_z)
				_card_token_nodes[key] = token

	# Phase 22F-5R: batch diagnostic when mapping changes
	var map_changed := false
	if current_maps.size() != _last_slot_maps.size():
		map_changed = true
	else:
		for key in current_maps:
			var old_map: Dictionary = _last_slot_maps.get(key, {})
			var new_map: Dictionary = current_maps.get(key, {})
			if str(old_map) != str(new_map):
				map_changed = true
				break
	if map_changed and not current_maps.is_empty():
		for key in current_maps:
			var details: Array = []
			var m: Dictionary = current_maps[key]
			var logical_keys := m.keys()
			logical_keys.sort()
			for logical_i in logical_keys:
				details.append("L%d->V%d" % [logical_i, m[logical_i]])
			if details.size() > 0:
				print("[TOKEN_SLOT_MAP] %s: %s" % [key, ", ".join(details)])
		_last_slot_maps = current_maps.duplicate(true)
		# [Fixed]
		for key in current_maps:
			var parts: PackedStringArray = (key as String).split("_")
			if parts.size() >= 2:
				var side: String = parts[0]
				var zone: String = parts[1]
				var row_name := ("P_" if side == "player" else "B_") + zone.to_upper()
				var cards: Array = []
				if side == "player":
					cards = context.player.field if zone == "front" else context.player.traps
				else:
					cards = context.enemy.field if zone == "front" else context.enemy.traps
				_log_formation_check(row_name, cards, current_maps[key])

		# Phase 23C0: Log compact formation diagnostics
		for key in current_maps:
			var parts2: PackedStringArray = (key as String).split("_")
			if parts2.size() >= 2:
				var side2: String = parts2[0]
				var zone2: String = parts2[1]
				var cards2: Array = []
				if side2 == "player":
					cards2 = context.player.field if zone2 == "front" else context.player.traps
				else:
					cards2 = context.enemy.field if zone2 == "front" else context.enemy.traps
				var cnt := 0
				for c2 in cards2:
					if c2 != null:
						cnt += 1
				var offsets_log: Array[float] = compute_compact_formation_offsets(cnt)
				var positions_log: Array = []
				var center_anchor: Node3D = _get_3d_anchor_for_zone(side2, zone2, 2)
				if center_anchor and is_instance_valid(center_anchor):
					for off in offsets_log:
						positions_log.append(Vector3(center_anchor.global_position.x, 0, center_anchor.global_position.z + off))
				print("[23C0_FORMATION] side=%s zone=%s count=%d offsets=%s positions=%s" % [side2, zone2, cnt, offsets_log, positions_log])
	# 娓呯悊宸叉秷澶辩殑 token
	_clear_missing_3d_tokens(active_keys)

	# 鍙€夋棩蹇椻€斺€斿彧鍦ㄦ暟閲忓彉鍖栨椂鎵撳嵃
	var count := _card_token_nodes.size()
	if count != _last_3d_token_count:
		if DEBUG_SHOW_3D_CARD_TOKENS:
			print("[3D_TOKENS] synced count=%d" % count)
		_last_3d_token_count = count


# ── Phase 25E: Unit State Helpers ──

func _on_unit_combat_state_changed(_card: CardData, _snapshot: Dictionary) -> void:
	call_deferred("_sync_3d_field_tokens")

func _on_unit_destroyed(_card: CardData, _owner_side: StringName, _reason: String) -> void:
	# Phase 27I-R0: 单位死亡时清理棋子上下文
	_cancel_piece_context(&"unit_death")
	call_deferred("_refresh_tables")

func _get_runtime_unit_state(card: CardData) -> Dictionary:
	if battle != null and battle.has_method("get_unit_combat_state"):
		return battle.get_unit_combat_state(card)
	return {}

func _apply_runtime_stats_to_token(token: Node3D, card: CardData, zone: String) -> void:
	# Phase 27E-R5: update compact CombatBadge on token
	var badge := token.get_node_or_null("CombatBadge") as Label3D
	if badge and zone == "front" and card != null and card.is_front_row_card():
		var state := _get_runtime_unit_state(card)
		if not state.is_empty():
			var eff_atk: int = battle.get_unit_effective_attack(card) if battle != null and battle.has_method("get_unit_effective_attack") else card.unit_power
			var cur_hp: int = int(state.get("current_hp", 0))
			var max_hp: int = int(state.get("max_hp", card.unit_defense))
			badge.text = "攻%d · 血%d/%d" % [eff_atk, cur_hp, max_hp]
			badge.visible = true
		else:
			badge.visible = false
	elif badge:
		badge.visible = false
	# Phase 27E-R5-R: carrier code removed
	return  # CombatBadge single authority; carrier path removed
	var carrier := token.get_node_or_null("CardCarrier")
	if carrier == null:
		return
	if zone == "front" and card != null and card.is_front_row_card():
		var state := _get_runtime_unit_state(card)
		if false:  # Phase 27E-R5-R: carrier path permanently disabled
			var eff_atk: int = battle.get_unit_effective_attack(card) if battle != null and battle.has_method("get_unit_effective_attack") else card.unit_power
			# Phase 27E-R5-R: carrier badge deactivated — CombatBadge on token is single authority
			pass
	# Phase 27E-R5-R: clear_combat_stats path deactivated


# ═══════════════════════════════════════════════════════════════
# Phase 26D: OD 伙伴后场表现器集成
# ═══════════════════════════════════════════════════════════════

func _ensure_od_companion_backline_presenter() -> void:
	if not USE_TRUE_3D_BOARD_BACKGROUND:
		return
	if _od_backline_presenter and is_instance_valid(_od_backline_presenter):
		return

	# 获取三个语义 Socket 锚点
	var gy_anchor: Node3D = _get_3d_slot_anchor("PLAYER_GY")
	var od_anchor: Node3D = _get_3d_slot_anchor("OD_DOCK")
	var deck_anchor: Node3D = _get_3d_slot_anchor("PLAYER_DECK")
	if gy_anchor == null or od_anchor == null or deck_anchor == null:
		return

	# 实例化 Presenter
	_od_backline_presenter = ODCompanionBacklinePresenterScene.instantiate()
	_od_backline_presenter.name = "ODCompanionBacklinePresenter"

	# 放到底层 3D stage / BoardSpace3D 下
	var stage := _get_3d_stage()
	if stage == null:
		return
	var board_space := stage.get_node_or_null(NodePath("BoardSpace3D")) as Node3D
	var parent: Node3D = board_space if board_space else stage
	parent.add_child(_od_backline_presenter)

	# 组装锚点映射
	var anchor_map := {
		"player_graveyard": gy_anchor,
		"od_companion": od_anchor,
		"player_deck": deck_anchor,
	}

	# 配置 Presenter（使用现有 token-click 碰撞层和不可变 profile）
	_od_backline_presenter.configure(anchor_map, TOKEN_CLICK_COLLISION_LAYER, _od_companion_presentation_profile)

	# 初始应用快照
	_refresh_od_companion_backline()


func _build_od_backline_snapshot() -> Dictionary:
	var snap := {}

	# Layer / Charge / Capacity（从 ODMode）
	if context and context.od_mode:
		snap["layer"] = context.od_mode.get_engine_layer()
		snap["charge"] = context.od_mode.get_engine_charge()
		snap["capacity"] = context.od_mode.get_engine_capacity()
		snap["compat_od"] = context.od_mode.engine_total_points
	else:
		snap["layer"] = 1
		snap["charge"] = 0
		snap["capacity"] = 4
		snap["compat_od"] = 0

	# Depth / Zone / Backlash（从 BattleContext）
	if context:
		snap["depth"] = context.depth_pressure if "depth_pressure" in context else 0
		snap["depth_zone"] = context.get_depth_zone() if context.has_method("get_depth_zone") else "Stable"
		snap["backlash"] = context.depth_pressure > 0 and (snap["depth_zone"] == "Backlash")
	else:
		snap["depth"] = 0
		snap["depth_zone"] = "Stable"
		snap["backlash"] = false

	# 墓地（从 Player）
	if context and context.player:
		var gy: Array = context.player.graveyard if "graveyard" in context.player else []
		snap["graveyard_count"] = gy.size()
		if gy.size() > 0:
			var latest = gy[gy.size() - 1]
			if latest is CardData:
				snap["graveyard_latest_name"] = latest.card_name
				snap["graveyard_latest_art"] = null
			else:
				snap["graveyard_latest_name"] = str(latest)
				snap["graveyard_latest_art"] = null
		else:
			snap["graveyard_latest_name"] = ""
			snap["graveyard_latest_art"] = null
	else:
		snap["graveyard_count"] = 0
		snap["graveyard_latest_name"] = ""
		snap["graveyard_latest_art"] = null

	# 牌库（从 Player）
	if context and context.player:
		var deck: Array = context.player.deck if "deck" in context.player else []
		snap["deck_count"] = deck.size()
	else:
		snap["deck_count"] = 0

	# 核心指令（从 BattleSystem）
	if battle and battle.has_method("get_core_command_state"):
		var cs: Dictionary = battle.get_core_command_state()
		snap["command_used"] = cs.get("used", 0)
		snap["command_limit"] = cs.get("limit", 1)
	else:
		snap["command_used"] = 0
		snap["command_limit"] = 1

	return snap


func _refresh_od_companion_backline() -> void:
	if not _od_backline_presenter or not is_instance_valid(_od_backline_presenter):
		return
	var snap := _build_od_backline_snapshot()
	_od_backline_presenter.apply_snapshot(snap)
	_od_backline_last_snapshot = snap


# ── Phase 26D: 语义点击解析 ──

func _ensure_tactical_movement_presenter() -> void:
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		return
	var tscn := load("res://scenes/presentation/tactical_movement_presenter.tscn")
	if tscn == null:
		return
	_tactical_presenter = tscn.instantiate()
	if _tactical_presenter == null:
		return
	var stage := _get_3d_stage()
	if stage:
		stage.add_child(_tactical_presenter)
		_tactical_presenter.configure(Callable(self, "_get_3d_anchor_for_zone"), TOKEN_CLICK_COLLISION_LAYER)
		# Phase 27A-R1: cell resolver and presentation profile
		if _tactical_presenter.has_method("configure_cell_resolver"):
			_tactical_presenter.configure_cell_resolver(Callable(self, "_get_3d_surface_anchor_for_cell"), TOKEN_CLICK_COLLISION_LAYER)
		# Phase 27I-R0-R4: 棋子选择专用 resolver（普通格复用 + 我方虚拟核心格 → 玩家核心节点）
		if _tactical_presenter.has_method("configure_piece_cell_resolver"):
			_tactical_presenter.configure_piece_cell_resolver(Callable(self, "_get_3d_piece_anchor_for_cell"))
		if _tactical_presenter.has_method("configure_presentation_profile") and _tactical_grid_presentation_profile != null:
			_tactical_presenter.configure_presentation_profile(_tactical_grid_presentation_profile)
		if not _tactical_presenter.lane_selected.is_connected(_on_tactical_lane_selected):
			_tactical_presenter.lane_selected.connect(_on_tactical_lane_selected)
		if _tactical_presenter.has_signal("cell_selected") and not _tactical_presenter.cell_selected.is_connected(_on_tactical_cell_selected):
			_tactical_presenter.cell_selected.connect(_on_tactical_cell_selected)
		if _tactical_presenter.has_signal("cell_hover_changed") and not _tactical_presenter.cell_hover_changed.is_connected(_on_tactical_cell_hover_changed):
			_tactical_presenter.cell_hover_changed.connect(_on_tactical_cell_hover_changed)

func _on_tactical_lane_selected(lane_index: int) -> void:
	if not _is_lane_selection_active():
		return
	_confirm_lane_selection(lane_index)


# ── Phase 27B-R1-R2-R: single semantic cell dispatcher ──
## Routes a tactical-cell hit (from 3D raycast or Area3D.input_event)
## to the correct confirmation handler based on _lane_selection_mode.
## Returns true if the hit was consumed (cell selected or safely ignored).
## Never mutates battle state directly; delegates to _confirm_* helpers.
func _dispatch_tactical_cell_selection(cell: Vector2i, selectable: bool) -> bool:
	if bool(_garrison_context.get("active", false)):
		if _garrison_context.get("stage") != &"selecting" or cell == Vector2i(-1, -1):
			return true
		for raw_status in _garrison_context.get("candidates", []):
			if not raw_status is Dictionary:
				continue
			var status: Dictionary = raw_status
			var candidate_cell: Vector2i = status.get("target_cell", status.get("parent_cell", Vector2i(-1, -1)))
			if candidate_cell == cell and bool(status.get("ok", false)):
				_stage_garrison_candidate(status.duplicate(true))
				return true
		return true
	if _is_monster_summon_interaction_active():
		if StringName(_monster_drag_session.get("intent", &"")) == &"structure_build" \
				and _monster_summon_state() == MONSTER_SUMMON_RESELECTING \
				and selectable and cell != MONSTER_DRAG_INVALID_CELL:
			var source_ref := _monster_drag_session.get("card_ui_ref", null) as WeakRef
			var source := source_ref.get_ref() as CardUI if source_ref != null else null
			var hover := _update_structure_drag_hover_hit({
				"ok": true, "target_kind": &"tactical_cell", "board_cell": cell})
			if source != null and bool(hover.get("ok", false)):
				_stage_structure_build_candidate(source, cell, hover.get("preview_fact", {}))
			return true
		if _monster_summon_state() == MONSTER_SUMMON_RESELECTING \
				and _lane_selection_source == &"drag_reselect" \
				and cell != MONSTER_DRAG_INVALID_CELL:
			_stage_reselected_monster_cell(cell)
		return true
	if bool(_od_release_context.get("active", false)):
		if not selectable or cell == Vector2i(-1, -1):
			return true
		if StringName(_od_release_context.get("stage", &"")) == &"target":
			var source_status: Dictionary = _od_release_context.get("source_status", {})
			if (source_status.get("legal_cells", []) as Array).has(cell):
				return _confirm_od_release_target(cell)
			var unit_target: CardData = battle.get_unit_at_cell(cell)
			if unit_target != null:
				return _confirm_od_release_target(unit_target)
		return true
	# Phase 27I-R0-R: 棋子选择状态优先处理（锚点格 / 移动目标 / 攻击主目标统一汇入棋子确认入口）
	if _is_piece_selection_active():
		if not selectable or cell == Vector2i(-1, -1):
			return true
		var stage: String = str(_piece_context.get("stage", ""))
		var action_id: StringName = _piece_context.get("action_id", &"")
		if stage == &"anchor":
			var anchor: Variant = _piece_anchor_for_cell(cell)
			if anchor != null:
				_confirm_piece_anchor(anchor)
			return true
		if stage == &"target":
			if action_id == &"move":
				_confirm_piece_action({"move_cell": cell})
			elif action_id == &"attack":
				var tgt: CardData = battle.get_unit_at_cell(cell) if (battle and battle.has_method("get_unit_at_cell")) else null
				if tgt == null:
					# 空格不能作为攻击目标
					if _tactical_presenter and is_instance_valid(_tactical_presenter):
						_tactical_presenter.play_cell_reject(cell)
				else:
					_confirm_piece_action({"target": tgt})
			return true
		return true
	if not _is_lane_selection_active():
		print("[CELL_DISPATCH] cell=%s selectable=%s mode=%s active=%s" % [str(cell), str(selectable), _lane_selection_mode, str(_is_lane_selection_active())])
		return false
	if _lane_selection_source == &"drag_reselect":
		_confirm_summon_cell(cell)
		return true
	if not selectable or cell == Vector2i(-1, -1):
		# Consume the click without changing state — player keeps choosing
		return true
	match _lane_selection_mode:
		LANE_SELECT_SUMMON:
			_confirm_summon_cell(cell)
		LANE_SELECT_MOVE, LANE_SELECT_REDEPLOY:
			_confirm_move_cell(cell)
		LANE_SELECT_ATTACK:
			_confirm_attack_on_cell(cell)
		LANE_SELECT_SKILL:  # Phase 27E-R2
			_confirm_skill_cell(cell)
		_:
			return false
	return true

# ── Phase 27A-R1: cell selection callback (Presenter signal entry) ──

func _on_tactical_cell_selected(cell: Vector2i) -> void:
	_dispatch_tactical_cell_selection(cell, true)


## Phase 27A-R1: exact-cell summon confirmation with revalidation before card consumption
func _confirm_summon_cell(cell: Vector2i) -> void:
	if _lane_selection_source == &"drag_reselect":
		await _stage_reselected_monster_cell(cell)
		return
	var card := _lane_selection_card
	if card == null or battle == null:
		_cancel_lane_selection(&"invalid_state")
		return
	var status: Dictionary = battle.get_monster_summon_cell_status(card, cell, &"player")
	if not bool(status.get("ok", false)):
		if _tactical_presenter and is_instance_valid(_tactical_presenter):
			_tactical_presenter.play_cell_reject(cell)
		var refreshed: Array[Vector2i] = battle.get_legal_summon_cells(&"player")
		_cell_selection_legal = refreshed.duplicate()
		if _tactical_presenter and is_instance_valid(_tactical_presenter):
			_tactical_presenter.show_cell_selection(&"summon", &"player", Vector2i(-1, -1), refreshed, battle.get_occupied_cells(), {})
		return
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.play_cell_confirm(cell)
	var card_ui: CardUI = _lane_selection_card_ui_ref.get_ref() if _lane_selection_card_ui_ref else null
	var selection_source := _lane_selection_source
	_lane_selection_mode = LANE_SELECT_NONE
	_lane_selection_card = null
	_lane_selection_card_ui_ref = null
	_cell_selection_legal.clear()
	await _commit_monster_summon(card_ui, card, cell, selection_source)
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.clear_preview()


# ── Phase 27B: Move cell confirmation ──

func _confirm_move_cell(cell: Vector2i) -> void:
	# PHASE55_BEGIN_ROUTE
	if _lane_selection_mode==LANE_SELECT_REDEPLOY:
		await _confirm_core_redeploy_cell(cell);return
	# PHASE55_END_ROUTE
	var card := _lane_selection_card
	if card == null or battle == null:
		_cancel_lane_selection(&"invalid_state")
		return
	# Phase 27B: stale-selection guard
	var move_state: Variant = battle._state_for_card(card) if battle.has_method("_state_for_card") else null
	if move_state != null and move_state.is_dead():
		_cancel_lane_selection(&"attacker_dead")
		return
	var status: Dictionary = battle.get_unit_move_cell_status(card, cell, battle.MOVE_SELF)
	if not bool(status.get("ok", false)):
		if _tactical_presenter and is_instance_valid(_tactical_presenter):
			_tactical_presenter.play_cell_reject(cell)
		# Refresh legal cells
		var refreshed: Array[Vector2i] = battle.get_legal_move_cells(card, battle.MOVE_SELF)
		_cell_selection_legal = refreshed.duplicate()
		var occupied: Dictionary = battle.get_occupied_cells()
		var from_cell: Vector2i = battle.get_unit_cell(card)
		if _tactical_presenter and is_instance_valid(_tactical_presenter):
			_tactical_presenter.show_cell_selection(_lane_selection_mode, &"player", from_cell, refreshed, occupied, {})
		return
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.play_cell_confirm(cell)
	var committed_from_cell: Vector2i = battle.get_unit_cell(card)
	# Phase 27D-R5: route move through atomic execute_unit_command (shared pool)
	var result: Dictionary
	if battle.has_method("execute_unit_command"):
		result = battle.execute_unit_command(card, "move", cell)
		if not bool(result.get("ok", false)):
			# Fallback: economy not configured, use legacy move
			result = battle.move_unit_to_cell(card, cell, battle.MOVE_SELF)
	else:
		result = battle.move_unit_to_cell(card, cell, battle.MOVE_SELF)
	_lane_selection_mode = LANE_SELECT_NONE
	_lane_selection_card = null
	_lane_selection_card_ui_ref = null
	_cell_selection_legal.clear()
	_lane_selection_legal.clear()
	if bool(result.get("ok", false)):
		if action_feed:
			action_feed.push_message("%s 移动到 (%d,%d)" % [card.card_name, cell.x, cell.y], Color(0.3, 0.85, 0.85), "", 1.5)
		_play_command_economy_spend(result.get("cost", 1))
		_refresh_tables()
		var move_facts := result.duplicate(true)
		move_facts.merge({
			"status": &"committed",
			"card": card,
			"from_cell": Vector2i(result.get("from_cell", committed_from_cell)),
			"to_cell": Vector2i(result.get("to_cell", cell)),
			"path_cells": [Vector2i(result.get("from_cell", committed_from_cell)), Vector2i(result.get("to_cell", cell))],
			"duration": 0.18,
		}, true)
		await _play_monster_presentation(&"move", move_facts)
		if _playtest:
			_playtest.record_event("unit_moved", {"card": card.card_name, "to_cell": cell})
			_playtest.record_vanguard_move_attempt(true)
	else:
		if action_feed:
			if _playtest: _playtest.record_vanguard_move_attempt(false)
			action_feed.push_message(str(result.get("reason", "移动失败")), TC.WARNING, "", 2.0)
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.clear_preview()

# ── Phase 27B: Attack target confirmation (cell click) ──

func _confirm_attack_on_cell(cell: Vector2i) -> void:
	var card := _lane_selection_card
	if card == null or battle == null:
		_cancel_lane_selection(&"invalid_state")
		return
	# Phase 27B: stale-selection guard
	var atk_state: Variant = battle._state_for_card(card) if battle.has_method("_state_for_card") else null
	if atk_state != null and atk_state.is_dead():
		_cancel_lane_selection(&"attacker_dead")
		return
	# Check if there's an enemy occupant on this cell
	var target: Variant = battle.get_unit_at_cell(cell)
	if target == null:
		# Empty cell clicked — reject
		if _tactical_presenter and is_instance_valid(_tactical_presenter):
			_tactical_presenter.play_cell_reject(cell)
		if action_feed:
			action_feed.push_message("空格不能攻击", TC.WARNING, "", 1.0)
		return
	var tgt_state: Variant = battle._state_for_card(target) if battle.has_method("_state_for_card") else null
	if tgt_state == null or tgt_state.is_dead() or tgt_state.owner_side == &"player":
		if _tactical_presenter and is_instance_valid(_tactical_presenter):
			_tactical_presenter.play_cell_reject(cell)
		# Phase 27D-R3: specific reason for illegal target click
		var reason_msg: String = "无法攻击该目标"
		if tgt_state != null and tgt_state.owner_side == &"player":
			reason_msg = "无法攻击我方单位"
		elif tgt_state != null and tgt_state.is_dead():
			reason_msg = "目标已被击破"
		if action_feed:
			action_feed.push_message(reason_msg, TC.WARNING, "", 1.2)
		return

	if _stage_covered_attack_if_needed(card, target):
		return
	# Revalidate attack legality
	var atk_status: Dictionary = battle.get_unit_attack_cell_status(card, target)
	if not bool(atk_status.get("ok", false)):
		if _tactical_presenter and is_instance_valid(_tactical_presenter):
			_tactical_presenter.play_cell_reject(cell)
		if action_feed:
			if _playtest: _playtest.record_illegal_cell_click()
			action_feed.push_message(str(atk_status.get("reason", "无法攻击")), TC.WARNING, "", 1.5)
		return

	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.play_cell_confirm(cell)

	# Phase 27D-R4: route through unified atomic transaction (execute_unit_command)
	# Captures attacker info for the unified handler
	_selected_attacker = card
	_lane_selection_mode = LANE_SELECT_NONE
	_lane_selection_card = null
	_lane_selection_card_ui_ref = null
	_cell_selection_legal.clear()
	_lane_selection_legal.clear()
	_pending_attack_card = null
	_pending_attack_cells.clear()

	var result: Dictionary = battle.execute_unit_command(card, "attack", target)
	print("[MOVE_SELECT_STATE] dispatch attack_result=%s cost=%d ok=%s" % [str(result.get("result", "?")), int(result.get("cost", 0)), str(result.get("ok", false))])
	_handle_attack_result(result)

# ═══════════════════════════════════════════
# Phase 27E-R2: Monster Skill Targeting
# ═══════════════════════════════════════════

## Begin skill targeting: query BattleSystem, show targets, enter BUSY
var _skill_selection_guidance: Control
func _refresh_skill_selection_guidance() -> void:
	if not _skill_context.get("active", false) or _skill_context.get("skill_id", "") != "bulwark_advance":
		if is_instance_valid(_skill_selection_guidance): _skill_selection_guidance.clear()
		return
	var caster: CardData = _skill_context.get("caster")
	var query: Dictionary = battle.get_unit_skill_command_status(caster, &"bulwark_advance")
	var cells: Array[Vector2i] = []
	if query.get("ok", false): cells.assign(query.get("legal_cells", []))
	if cells != _skill_context.get("legal_cells", []):
		_skill_context.legal_cells = cells.duplicate()
		_show_skill_cell_targets(caster, cells)
	if not is_instance_valid(_skill_selection_guidance):
		_skill_selection_guidance = preload("res://scenes/presentation/card_target_guidance.gd").new()
		_skill_selection_guidance.name = "GuardSkillSelectionGuidance"
		$MonsterSummonConfirmationLayer.add_child(_skill_selection_guidance)
	var text := "壁垒推进未支付：%s；右键/Escape取消" % _skill_reason_to_chinese(str(query.get("reason_code", "")))
	if query.get("ok", false):
		var stacks := int(query.get("stack_count", 0))
		text = "壁垒推进：点击守卫原地防守，或绿色格移动后防守；指令-%d（当前%d），压力%d→0，护盾+%d。消耗至少2压力且结算时Depth≥3则Depth-1；仍计入累计指令。右键/Escape取消" % [int(query.cost),int(query.current_points),stacks,2+stacks]
	var no_targets: Array[Dictionary] = []
	_skill_selection_guidance.reserved_rects = _get_structure_reserved_ui_rects()
	for legal_cell: Vector2i in cells:
		var point := _project_tactical_cell_to_screen(legal_cell)
		if point.is_finite(): _skill_selection_guidance.reserved_rects.append(Rect2(point-Vector2(35,35),Vector2(70,70)))
	_skill_selection_guidance.show_targets(no_targets, text)

func _guard_skill_receipt_text(result: Dictionary) -> String:
	var movement := "原地防守" if result.get("source_cell") == result.get("destination_cell") else "移动后防守"
	var text := "%s已结算：指令%d→%d（实付%d，返还%d），压力%d→%d，护盾+%d" % [movement,int(result.get("points_before",0)),int(result.get("points_after",0)),int(result.get("cost",0)),int(result.get("refund",0)),int(result.get("stacks_before",0)),int(result.get("stacks_before",0))-int(result.get("stacks_consumed",0)),int(result.get("shield_delta",0))]
	text += "；技能Depth变化%d，累计指令仍记实付费用" % int(result.get("depth_delta",0))
	return text

func _show_guard_skill_receipt(result: Dictionary) -> void:
	var old := $MonsterSummonConfirmationLayer.get_node_or_null("GuardSkillReceipt")
	if old != null:
		old.get_parent().remove_child(old)
		old.queue_free()
	var visual := preload("res://scenes/presentation/card_target_guidance.gd").new()
	visual.name = "GuardSkillReceipt"
	visual.reserved_rects = _get_structure_reserved_ui_rects()
	$MonsterSummonConfirmationLayer.add_child(visual)
	var no_targets: Array[Dictionary] = []
	visual.show_targets(no_targets, _guard_skill_receipt_text(result))
	var cleanup := visual.create_tween()
	cleanup.tween_interval(3.5)
	cleanup.tween_callback(func():
		if is_instance_valid(visual): visual.queue_free())

func _begin_skill_targeting(card: CardData, skill_id: StringName, query: Dictionary) -> void:
	if battle == null: return
	var old_receipt := $MonsterSummonConfirmationLayer.get_node_or_null("GuardSkillReceipt")
	if old_receipt != null:
		old_receipt.get_parent().remove_child(old_receipt)
		old_receipt.queue_free()
	# Get target_mode from the skill snapshot
	var tmode: String = "cell"
	if battle.has_method("get_monster_hero_skills"):
		var skill_snap = battle.get_monster_hero_skills()
		if skill_snap and skill_snap.has_skill(card.card_id):
			var active_def: Dictionary = skill_snap.get_active(card.card_id)
			tmode = str(active_def.get("target_mode", "cell"))

	_skill_context = {
		"active": true,
		"caster": card,
		"skill_id": str(skill_id),
		"target_mode": tmode,
		"legal_cells": query.get("legal_cells", []).duplicate(),
		"legal_targets": query.get("legal_targets", []).duplicate(),
		"can_target_boss_core": bool(query.get("can_target_boss_core", false)),
	}
	_lane_selection_mode = LANE_SELECT_SKILL
	_lane_selection_card = card

	if _end_turn_control and is_instance_valid(_end_turn_control):
		_end_turn_control.set_busy(true, "技能选择中")

	match tmode:
		"cell":
			_show_skill_cell_targets(card, _skill_context["legal_cells"])
		"cell_or_self":
			_show_skill_cell_targets(card, _skill_context["legal_cells"])
		"enemy_unit_or_boss_core":
			_show_skill_enemy_targets(card, _skill_context["legal_targets"], _skill_context["can_target_boss_core"])
	_refresh_skill_selection_guidance()

	print("[SKILL_TARGET] begin: %s skill=%s mode=%s cells=%d targets=%d boss=%s" % [
		card.card_name, str(skill_id), tmode,
		_skill_context["legal_cells"].size(), _skill_context["legal_targets"].size(),
		str(_skill_context["can_target_boss_core"])
	])


## Show cell-based targets (P02 ignition_leap, P15 bulwark_advance)
func _show_skill_cell_targets(card: CardData, legal_cells: Array) -> void:
	_set_3d_command_target_highlight(card, true)
	var occupied: Dictionary = battle.get_occupied_cells() if battle else {}
	var from_cell: Vector2i = battle.get_unit_cell(card) if battle else Vector2i(-1, -1)
	_cell_selection_legal = legal_cells.duplicate()
	_ensure_tactical_movement_presenter()
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.show_cell_selection(LANE_SELECT_SKILL, &"player", from_cell, legal_cells, occupied, {})
	if _skill_context.get("target_mode", "") == "cell_or_self" and legal_cells.has(from_cell):
		var caster_token := _get_3d_token_for_card(card)
		if caster_token:
			caster_token.set_meta("skill_self_target", true)
	else:
		var caster_token := _get_3d_token_for_card(card)
		if caster_token and caster_token.has_meta("skill_self_target"):
			caster_token.remove_meta("skill_self_target")


## Show enemy-unit + boss-core targets (P07 stream_cannon)
func _show_skill_enemy_targets(card: CardData, legal_targets: Array, can_target_boss: bool) -> void:
	_set_3d_command_target_highlight(card, true)
	for target_card in legal_targets:
		var token := _get_3d_token_for_card(target_card)
		if token:
			token.set_meta("skill_target", true)
	if can_target_boss and _boss_status_hud and is_instance_valid(_boss_status_hud) and _boss_status_hud.has_method("set_clickable"):
		_boss_status_hud.set_clickable(true)
		_boss_status_hud.set_meta("skill_boss_target", true)


## Unified skill target dispatch -- all 3D click entries converge here
func _dispatch_monster_skill_selection(target_kind: StringName, target_value: Variant) -> bool:
	if not _skill_context.get("active", false):
		return false
	if battle == null:
		return false
	var caster = _skill_context.get("caster") as CardData
	if caster == null:
		_clear_skill_selection(&"invalid_state")
		return false

	var skill_id: StringName = StringName(_skill_context.get("skill_id", ""))
	var recheck: Dictionary = battle.get_unit_skill_command_status(caster, skill_id)
	if not bool(recheck.get("ok", false)):
		_clear_skill_selection(&"recheck_failed")
		_show_floating_text(_skill_reason_to_chinese(str(recheck.get("reason_code", ""))), TC.WARNING, 1.5, 14)
		return false

	var tmode: String = str(_skill_context.get("target_mode", ""))

	match target_kind:
		&"cell":
			if not (target_value is Vector2i):
				_show_floating_text("请选择有效目标格", TC.WARNING, 1.0, 14)
				return true
			var cell: Vector2i = target_value
			if tmode not in ["cell", "cell_or_self"]: return false
			if not recheck.get("legal_cells", []).has(cell):
				_show_floating_text("该格不是合法目标", TC.WARNING, 1.0, 14)
				if _tactical_presenter and is_instance_valid(_tactical_presenter):
					_tactical_presenter.play_cell_reject(cell)
				return true
			return _execute_skill_command(caster, skill_id, cell)

		&"enemy_unit":
			if tmode != "enemy_unit_or_boss_core": return false
			if target_value == null or not (target_value is CardData): return false
			if not recheck.get("legal_targets", []).has(target_value):
				_show_floating_text("该目标不是合法目标", TC.WARNING, 1.0, 14)
				return true
			return _execute_skill_command(caster, skill_id, target_value)

		&"boss_core":
			if tmode != "enemy_unit_or_boss_core": return false
			if not bool(recheck.get("can_target_boss_core", false)):
				_show_floating_text("无法以Boss核心为目标", TC.WARNING, 1.0, 14)
				return true
			return _execute_skill_command(caster, skill_id, null)

	return false


func _present_committed_skill(facts: Dictionary) -> void:
	await _play_monster_presentation(&"skill", facts)
	if battle != null:
		battle._apply_deferred_destruction(facts)
	_refresh_tables()
	check_battle_end()

## Execute skill via BattleSystem, refresh, cleanup
func _execute_skill_command(card: CardData, skill_id: StringName, target) -> bool:
	if battle == null: return false
	if _end_turn_control and is_instance_valid(_end_turn_control):
		_end_turn_control.set_busy(true, "技能结算中")

	var result: Dictionary = battle.execute_unit_skill_command(card, skill_id, target)

	if bool(result.get("ok", false)):
		var skill_facts := result.duplicate(true)
		var skill_target_position := _get_boss_screen_pos()
		if target is CardData:
			var skill_target_token := _get_3d_token_for_card(target as CardData)
			if skill_target_token != null:
				skill_target_position = _project_3d_token_to_screen(skill_target_token)
		elif target is Vector2i:
			var skill_anchor := _get_3d_surface_anchor_for_cell(target as Vector2i)
			if skill_anchor != null:
				skill_target_position = _project_world_position_to_screen(skill_anchor.global_position)
				_record_elevated_grid_endpoint(&"skill_cell", target as Vector2i, skill_anchor.global_position, skill_target_position)
		skill_facts.merge({
			"status": &"committed",
			"card": card,
			"skill_id": skill_id,
			"target": target,
			"piece_type": StringName(card.piece_type if not card.piece_type.is_empty() else "pawn"),
			"target_position": skill_target_position,
		}, true)
		# Skill target dispatch must stay synchronous because the shared 3D click
		# router returns a bool immediately. Defer the coroutine instead of turning
		# every click path into a coroutine; the presentation director owns BUSY and
		# completes the visual sequence independently after the authoritative commit.
		Callable(self, "_present_committed_skill").call_deferred(skill_facts)
		# Phase 27E-R4: detailed ActionFeed message with card_id, cost, stacks, results
		if action_feed:
			var feed_parts := []
			var card_id_str := card.card_id if card.card_id.length() >= 2 and card.card_id.length() <= 8 else ""
			var prefix := card_id_str + " " if card_id_str != "" else ""
			feed_parts.append("%s%s：消耗%d指令" % [prefix, _tr_skill_name(skill_id), int(result.get("cost", 0))])
			if int(result.get("stacks_consumed", 0)) > 0:
				feed_parts.append("层数%d→0" % int(result.get("stacks_before", 0)))
			if int(result.get("atk_bonus", 0)) > 0:
				feed_parts.append("ATK+%d" % int(result.get("atk_bonus", 0)))
			if int(result.get("od_delta", 0)) > 0:
				feed_parts.append("OD+%d" % int(result.get("od_delta", 0)))
			if int(result.get("damage", 0)) > 0:
				feed_parts.append("造成%d伤害" % int(result.get("damage", 0)))
			if int(result.get("shield_delta", 0)) > 0:
				feed_parts.append("Shield+%d" % int(result.get("shield_delta", 0)))
			if int(result.get("depth_delta", 0)) != 0:
				feed_parts.append("Depth%s%d" % ["+" if int(result.get("depth_delta", 0)) > 0 else "", int(result.get("depth_delta", 0))])
			if int(result.get("refund", 0)) > 0:
				feed_parts.append("返还%d指令" % int(result.get("refund", 0)))
			var feed_msg := " / ".join(feed_parts)
			action_feed.push_message(feed_msg, Color(0.9, 0.75, 0.2), "", 2.5)
		_play_command_economy_spend(int(result.get("cost", 0)))
		_refresh_tables()
		_clear_skill_selection(&"success")
		if skill_id == &"bulwark_advance": _show_guard_skill_receipt(result)
		if _playtest:
			_playtest.record_event("skill_used", {"card": card.card_name, "skill": str(skill_id)})
		return true
	else:
		var reason_text := _skill_reason_to_chinese(str(result.get("reason_code", "unknown")))
		if action_feed:
			action_feed.push_message("技能失败：%s" % reason_text, TC.WARNING, "", 2.0)
		_show_floating_text(reason_text, TC.WARNING, 1.5, 14)
		_clear_skill_selection(&"failure")
		return false


## Confirm skill cell click (P02/P15 route from _dispatch_tactical_cell_selection)
func _confirm_skill_cell(cell: Vector2i) -> void:
	if not _skill_context.get("active", false):
		return
	var caster = _skill_context.get("caster") as CardData
	if caster and _skill_context.get("target_mode") == "cell_or_self":
		var caster_cell: Vector2i = battle.get_unit_cell(caster) if battle else Vector2i(-1, -1)
		if cell == caster_cell:
			_dispatch_monster_skill_selection(&"cell", cell)
			return
	_dispatch_monster_skill_selection(&"cell", cell)


## Unified cleanup: clear all skill targeting state
func _clear_skill_selection(reason: StringName = &"cleanup") -> void:
	if is_instance_valid(_skill_selection_guidance): _skill_selection_guidance.clear()
	if not _skill_context.get("active", false):
		return
	var caster = _skill_context.get("caster") as CardData
	if caster:
		_set_3d_command_target_highlight(caster, false)

	for target_card in _skill_context.get("legal_targets", []):
		var token := _get_3d_token_for_card(target_card)
		if token and token.has_meta("skill_target"):
			token.remove_meta("skill_target")

	if _boss_status_hud and is_instance_valid(_boss_status_hud):
		if _boss_status_hud.has_meta("skill_boss_target"):
			_boss_status_hud.remove_meta("skill_boss_target")
		if _boss_status_hud.has_method("set_clickable"):
			_boss_status_hud.set_clickable(false)

	if caster:
		var caster_token := _get_3d_token_for_card(caster)
		if caster_token and caster_token.has_meta("skill_self_target"):
			caster_token.remove_meta("skill_self_target")

	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.clear_preview()
	_cell_selection_legal.clear()

	_skill_context = {
		"active": false,
		"caster": null,
		"skill_id": "",
		"target_mode": "",
		"legal_cells": [],
		"legal_targets": [],
		"can_target_boss_core": false
	}

	if _lane_selection_mode == LANE_SELECT_SKILL:
		_lane_selection_mode = LANE_SELECT_NONE
		_lane_selection_card = null

	if _end_turn_control and is_instance_valid(_end_turn_control):
		_end_turn_control.set_busy(false, "")

	print("[SKILL_TARGET] cleared: reason=%s" % str(reason))


## Helper: determine target_mode from query result
func _target_mode_from_skill_query(query: Dictionary) -> String:
	if query.has("target_mode") and typeof(query["target_mode"]) == TYPE_STRING and query["target_mode"] != "":
		return query["target_mode"]
	if query.has("legal_targets") and not query.get("legal_targets", []).is_empty():
		return "enemy_unit_or_boss_core"
	if query.has("can_target_boss_core") and query["can_target_boss_core"]:
		return "enemy_unit_or_boss_core"
	return "cell"


## Helper: translate skill reason_code to Chinese
func _skill_reason_to_chinese(reason: String) -> String:
	match reason:
		"no_skill": return "该单位无可用技能"
		"not_player_turn": return "仅能在己方回合使用技能"
		"not_player_unit": return "只能使用己方在场棋子的技能"
		"unit_dead": return "该单位已阵亡"
		"summoning_sickness": return "召唤当回合无法使用技能"
		"insufficient_command_points": return "战术指令不足"
		"no_legal_cell": return "没有可用的目标格"
		"no_legal_target": return "没有可攻击的目标"
		"illegal_cell": return "目标格不合法"
		"cell_occupied": return "目标格已被占用"
		"illegal_target": return "目标不合法"
		"state_missing": return "单位状态异常"
		"insufficient_stacks": return "技能层数不足"
		"target_dead": return "目标已阵亡"
		_: return "技能发动失败"


## Helper: translate skill_id to Chinese display name
func _tr_skill_name(skill_id: StringName) -> String:
	match str(skill_id):
		"ignition_leap": return "点火跃迁"
		"stream_cannon": return "贯流轰击"
		"bulwark_advance": return "壁垒推进"
		"spark_assault": return "火花突击"
		"chain_relay": return "链路转接"
		_: return str(skill_id)


# Phase 27E-R3: Map attack reason_code + rich status → user-readable text
func _map_attack_reason_text(rc: StringName, rich: Dictionary) -> String:
	match rc:
		&"not_breach_rank": return "需到最靠近 Boss 的一排"
		&"facing_away_from_core": return "需转向敌方核心"
		&"guard_intercepted": return "需先清除拦截守卫"
		&"front_arc_blocked": return "需先清除前方敌军"
		&"garrison_entered_this_turn": return "刚驻军，下回合才能攻击"
		&"summoning_sickness": return "刚登场，本回合不能攻击"
		&"insufficient_command_points": return "战术指令不足"
		&"no_legal_target": return "前方攻击范围内没有敌人"
		&"no_legal_cell": return "没有可用的攻击格"
		&"no_geometric_cells": return "该单位没有攻击范围格"
		&"state_missing": return "怪兽战斗状态缺失"
		&"card_missing": return "卡牌不存在"
		&"not_on_board": return "不在场上"
		&"attack_locked":
			if not rich.is_empty():
				return str(rich.get("reason_text", "不能攻击"))
			return "不能攻击"
		&"action_spent": return "本回合已行动"
		&"engaged": return "被牵制中，无法攻击"
		&"selection_busy": return "当前正在结算其他行动"
		_: return "攻击不可用：" + str(rc)


# Phase 27E-R3-R: Map move reason_code + unit cell → user-readable text
func _map_move_reason_text(rc: StringName, move_cs: Dictionary, card: CardData) -> String:
	match rc:
		&"garrison_forced_move_blocked": return "驻军需先选择撤离，再移动"
		&"summoning_sickness": return "刚登场，本回合不能移动"
		&"insufficient_command_points": return "战术指令不足"
		&"no_legal_cell":
			# Check if forward cells are blocked but sides might be open
			# (BattleSystem is sole authority; this is just contextual wording)
			return "前方和侧翼均被占用"
		&"state_missing": return "单位状态缺失"
		&"not_on_board": return "不在场上"
		&"engaged": return "被牵制中，无法移动"
		_: return "无法移动"


# Phase 27E-R3-R: Check if forward cell is blocked but side cells are available
func _get_move_hint(card: CardData, move_cs: Dictionary, legal_cells: Array) -> String:
	if not bool(move_cs.get("ok", false)):
		return ""
	if battle == null or not battle.has_method("get_unit_cell"):
		return ""
	var cell: Vector2i = battle.get_unit_cell(card)
	if cell.x < 0 or cell.y < 0:
		return ""
	var facing := 1
	if battle.has_method("get_unit_facing"):
		facing = battle.get_unit_facing(card)
	# Forward cell in facing direction
	var fwd: Vector2i = cell + Vector2i(0, 1) if facing > 0 else cell + Vector2i(0, -1)
	if battle.has_method("get_unit_at_cell"):
		var occ: Variant = battle.get_unit_at_cell(fwd)
		if occ != null and legal_cells.size() > 0:
			return "前方受阻，可向侧翼移动"
	return ""


## Phase 26E-R1 Task 5: unified lane selection dispatcher.
## Routes to the correct handler based on current _lane_selection_mode.
## Called from both Area3D.input_event (via _on_tactical_lane_selected) and
## central raycast (via _dispatch_3d_click_hit).
func _confirm_lane_selection(lane_index: int) -> void:
	if not _is_lane_selection_active():
		return
	if _lane_selection_mode == LANE_SELECT_SUMMON:
		_confirm_summon_lane(lane_index)
	elif _lane_selection_mode == LANE_SELECT_MOVE:
		_confirm_move_lane(lane_index)
	elif _lane_selection_mode == LANE_SELECT_REDEPLOY:
		_confirm_redeploy_lane(lane_index)

func _confirm_summon_lane(lane_index: int) -> void:
	var card := _lane_selection_card
	if card == null or battle == null:
		_cancel_lane_selection(&"invalid_state")
		return
	var status := battle.get_monster_summon_status(card, lane_index, &"player")
	if not bool(status.get("ok", false)):
		return
	var card_ui: CardUI = _lane_selection_card_ui_ref.get_ref() if _lane_selection_card_ui_ref else null
	_lane_selection_mode = LANE_SELECT_NONE
	_lane_selection_card = null
	_lane_selection_card_ui_ref = null
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.clear_preview()
	_card_being_played = true
	_stat_total_cards += 1
	_trigger_guides_on_card_play()
	context.combo_system.on_card_played()
	var play_result := battle.play_card(card, lane_index)
	_card_being_played = false
	if bool(play_result.get("ok", false)):
		if card_ui and card_ui.has_method("play_leave_animation"):
			card_ui.play_leave_animation()
		_refresh_tables()
		check_battle_end()
		if _playtest:
			_playtest.record_event("card_played", {"card": card.card_name})
	else:
		if action_feed:
			action_feed.push_message(str(play_result.get("reason", "出牌失败")), TC.WARNING, "", 2.0)
	_lane_selection_card = null

## Phase 26E-R1 Task 6: confirm normal move lane selection.
func _confirm_move_lane(lane_index: int) -> void:
	var card := _lane_selection_card
	_cancel_lane_selection(&"confirmed")
	if battle == null or card == null:
		return
	var result: Dictionary = battle.move_unit(card, lane_index, battle.MOVE_SELF)
	if bool(result.get("ok", false)):
		_sync_3d_field_tokens()
		_play_command_economy_spend(result.get("cost", 1))
		_refresh_tables()
		if action_feed:
			var src_lane: int = result.get("from_lane", -1)
			action_feed.push_message("%s 移动 L%d→L%d" % [card.card_name, src_lane, lane_index], TC.TEXT_PRIMARY, "", 1.5)
	else:
		if action_feed:
			action_feed.push_message(str(result.get("reason", "移动失败")), TC.WARNING, "", 2.0)

## Phase 26E-R1 Task 6: confirm OD redeploy lane selection via core command.
func _confirm_redeploy_lane(lane_index: int) -> void:
	var card := _lane_selection_card
	_cancel_lane_selection(&"confirmed")
	if battle == null or card == null:
		return
	var result: Dictionary = battle.execute_core_command(&"redeploy", {"card": card, "lane_index": lane_index})
	if bool(result.get("ok", false)):
		_sync_3d_field_tokens()
		_refresh_tables()
		if action_feed:
			action_feed.push_message("调轨完成: %s → L%d" % [card.card_name, lane_index], Color(0.65, 0.25, 1.0), "", 1.5)
	else:
		if action_feed:
			action_feed.push_message(str(result.get("reason", "调轨失败")), TC.WARNING, "", 2.0)

func _resolve_od_backline_target(target_kind: StringName) -> bool:
	match target_kind:
		&"player_graveyard":
			_show_gy_view(true)
			return true
		&"od_companion":
			_on_core_command_button_pressed()
			return true
		&"player_deck":
			var deck_count: int = 0
			if context and context.player:
				var deck: Array = context.player.deck if "deck" in context.player else []
				deck_count = deck.size()
			if action_feed:
				action_feed.push_message("牌库剩余 %d 张" % deck_count, TC.ROLE_CONTROL, "", 2.0)
			return true
	return false


# ── Phase 26D: 世界坐标投影到屏幕 ──

func _project_world_position_to_screen(world_position: Vector3) -> Vector2:
	var cam := _get_3d_camera()
	if cam == null or cam.is_position_behind(world_position):
		return Vector2(-1.0, -1.0)
	return cam.unproject_position(world_position)


func _extract_tactical_cell_click_hit(node: Node, collider: Object, hit_position: Vector3) -> Dictionary:
	if node == null or str(node.get_meta("target_kind", "")) != "tactical_cell":
		return {"ok": false}
	var raw_cell = node.get_meta("board_cell", Vector2i(-1, -1))
	if not raw_cell is Vector2i:
		return {"ok": false}
	return {
		"ok": true,
		"target_kind": "tactical_cell",
		"selection_mode": StringName(str(node.get_meta("selection_mode", ""))),
		"board_cell": raw_cell,
		"owner_side": StringName(str(node.get_meta("owner_side", ""))),
		"selectable": bool(node.get_meta("selectable", false)),
		"collider": collider,
		"position": hit_position,
	}


func _extract_structure_click_hit(node: Node, collider: Object, hit_position: Vector3) -> Dictionary:

	if node == null:
		return {"ok": false}
	var target_kind := StringName(str(node.get_meta("target_kind", &"")))
	if target_kind not in [&"structure_core", &"structure_module"]:
		return {"ok": false}
	var target_ref: Variant = node.get_meta("target_ref", {})
	if not target_ref is Dictionary:
		return {"ok": false}
	var copied: Dictionary = (target_ref as Dictionary).duplicate(true)
	if StringName(str(copied.get("target_kind", &""))) != target_kind:
		return {"ok": false}
	return {"ok": true, "target_kind": target_kind, "target_ref": copied, "collider": collider, "position": hit_position}


func _raycast_3d_click(screen_pos: Vector2) -> Dictionary:
	var vpc := get_node_or_null(NodePath("Battle3DViewport")) as SubViewportContainer
	if not vpc:
		return {"ok": false}
	var vp := vpc.get_node_or_null(NodePath("SubViewport")) as SubViewport
	if not vp:
		return {"ok": false}
	var cam := _get_3d_camera()
	if not cam:
		return {"ok": false}

	# Convert global screen position to SubViewport-local coordinates
	var vp_rect := vpc.get_global_rect()
	var local_pos := screen_pos - vp_rect.position
	if local_pos.x < 0 or local_pos.y < 0 or local_pos.x > vp_rect.size.x or local_pos.y > vp_rect.size.y:
		return {"ok": false}

	# Ray from camera through the clicked point
	var from := cam.project_ray_origin(local_pos)
	var to := from + cam.project_ray_normal(local_pos) * 30.0

	# Phase 22B-R: 瀹夊叏鑾峰彇 World3D锛岄伩鍏?null instance 绾㈤敊
	var world: World3D = vp.find_world_3d()
	if world == null:
		return {"ok": false}
	var space_state := world.direct_space_state
	if space_state == null:
		return {"ok": false}
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = TOKEN_CLICK_COLLISION_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false

	# While choosing a move, the visible legal cell marker owns its ray even when
	# a raised adjacent token overlaps it. Normal inspection keeps nearest-hit order.
	if _is_piece_selection_active() and _piece_context.get("action_id") == &"move" \
			and _piece_context.get("stage") == &"target":
		var move_hit := _raycast_active_move_cell(space_state, from, to)
		if not move_hit.is_empty():
			return move_hit
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return {"ok": false}

	var collider = result.get("collider")
	if collider == null:
		return {"ok": false}

	# Walk up from the Area3D to find the token node with card meta
	var node: Node = collider
	while node != null:
		var structure_hit := _extract_structure_click_hit(node, collider, result.get("position", Vector3.ZERO))
		if bool(structure_hit.get("ok", false)):
			structure_hit["legal_targets"] = _collect_structure_ray_targets(space_state, from, to)
			return structure_hit
		# Phase 24A-R3: 浼樺厛璇嗗埆 boss_core 鐩爣
		if node.has_meta("target_kind") and node.get_meta("target_kind") == "boss_core":
			return {"ok": true, "target_kind": "boss_core", "token": node}
		# Phase 26D: 后场站点点击（backline_station）
		if node.has_meta("backline_station") and node.has_meta("target_kind"):
			var backline_kind: StringName = StringName(node.get_meta("target_kind"))
			return {
				"ok": true,
				"target_kind": backline_kind,
				"collider": collider,
				"position": result.get("position", Vector3.ZERO)
			}
		# Phase 27A-R1-R2: exact-cell markers must preserve their semantic
		# coordinate through the central raycast bridge.
		var tactical_cell_hit := _extract_tactical_cell_click_hit(
			node, collider, result.get("position", Vector3.ZERO)
		)
		if bool(tactical_cell_hit.get("ok", false)):
			return tactical_cell_hit
		# Phase 26E-R1 Task 5: tactical_lane marker (higher priority than card token)
		if node.has_meta("target_kind") and str(node.get_meta("target_kind", "")) == "tactical_lane":
			var tl_mode: StringName = StringName(str(node.get_meta("selection_mode", "")))
			var tl_lane: int = int(node.get_meta("lane_index", -1))
			var tl_side: StringName = StringName(str(node.get_meta("owner_side", "")))
			var tl_selectable: bool = bool(node.get_meta("selectable", false))
			return {
				"ok": true,
				"target_kind": "tactical_lane",
				"selection_mode": tl_mode,
				"lane_index": tl_lane,
				"owner_side": tl_side,
				"selectable": tl_selectable,
				"collider": collider,
				"position": result.get("position", Vector3.ZERO),
			}
		if node.has_meta("card") and node.has_meta("side") and node.has_meta("zone"):
			return {
				"ok": true,
				"card": node.get_meta("card"),
				"side": node.get_meta("side"),
				"zone": node.get_meta("zone"),
				"index": node.get_meta("field_index", node.get_meta("slot_index", -1)),
				"token": node,
			}
		node = node.get_parent()

	return {"ok": false}


func _raycast_active_move_cell(space_state: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var excluded: Array[RID] = []
	for i in range(32):
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = TOKEN_CLICK_COLLISION_LAYER
		query.collide_with_areas = true
		query.collide_with_bodies = false
		query.exclude = excluded
		var result := space_state.intersect_ray(query)
		if result.is_empty():break
		excluded.append(result.rid)
		var collider: Node = result.get("collider")
		var node: Node = collider
		while node != null:
			var hit := _extract_tactical_cell_click_hit(node, collider, result.position)
			if hit.get("ok", false) and hit.get("selectable", false):return hit
			node = node.get_parent()
	return {}


func _collect_structure_ray_targets(space_state: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Array[Dictionary]:

	var targets: Array[Dictionary] = []
	var excluded: Array[RID] = []
	for _index in range(32):
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = TOKEN_CLICK_COLLISION_LAYER
		query.collide_with_areas = true
		query.collide_with_bodies = false
		query.exclude = excluded
		var result := space_state.intersect_ray(query)
		if result.is_empty():
			break
		var collider: Variant = result.get("collider", null)
		if not collider is CollisionObject3D:
			break
		var collider_rid := (collider as CollisionObject3D).get_rid()
		if collider_rid in excluded:
			break
		excluded.append(collider_rid)
		var node := collider as Node
		while node != null:
			var structure_hit := _extract_structure_click_hit(node, collider, result.get("position", Vector3.ZERO))
			if bool(structure_hit.get("ok", false)):
				targets.append((structure_hit.get("target_ref", {}) as Dictionary).duplicate(true))
				break
			var cell_hit := _extract_tactical_cell_click_hit(node, collider, result.get("position", Vector3.ZERO))
			if bool(cell_hit.get("ok", false)) and bool(cell_hit.get("selectable", false)):
				targets.append({
					"target_kind": &"tactical_cell",
					"cell": cell_hit.get("board_cell", Vector2i(-1, -1)),
					"selection_mode": cell_hit.get("selection_mode", &""),
					"owner_side": cell_hit.get("owner_side", &""),
				}.duplicate(true))
				break
			node = node.get_parent()
	return targets
# Phase 21E: Bridge 3D token click to existing 2D interaction handlers
func _on_3d_token_clicked(card: CardData, side: String, zone: String, index: int) -> void:
	if card == null:
		return
	if _is_monster_summon_interaction_active():
		if player_table and player_table.card_detail_panel:
			player_table.card_detail_panel.visible = true
			player_table.card_detail_panel.show_card(card, "", {})
		return

	# Phase 23B-R2: Intercept for building replacement selection
	if _building_replace_select_active:
		_handle_building_replace_token_click(card, side, zone)
		return

	var card_label := card.get_display_name() if card.has_method("get_display_name") else card.card_name
	print("[3D_TOKEN_CLICK] side=%s zone=%s index=%d card=%s" % [side, zone, index, card_label])

	# Close any existing monster menu first (prevent double-open)
	_close_monster_command_menu()

	# 鈹€鈹€ Player front field 鈹€鈹€
	if side == "player" and zone == "front":
		var ctype := str(card.card_family).to_lower()
		if ctype == "monster" or ctype == "fusion":
			_request_unit_command(card, "player", "3d_token")
			return
		# Other front: show detail
		if player_table and player_table.card_detail_panel:
			player_table.card_detail_panel.visible = true
			player_table.card_detail_panel.show_card(card, "", {})
		return

	# 鈹€鈹€ Player back field 鈹€鈹€
	if side == "player" and zone == "back":
		var ctype := str(card.card_family).to_lower()
		if ctype == "building" or ctype == "build":
			# Trigger building interact through existing signal path
			if player_table.has_signal("building_interact_requested"):
				player_table.building_interact_requested.emit(card)
			return
		# Counter / Spell / other: detail only
		if player_table and player_table.card_detail_panel:
			player_table.card_detail_panel.visible = true
			player_table.card_detail_panel.show_card(card, "", {})
		return

	# 鈹€鈹€ Boss / Enemy field 鈹€鈹€
	if side == "boss" or side == "enemy":
		if _selected_attacker != null:
			# Already selecting an attacker 鈥?treat as attack target
			_request_unit_command(card, side, "3d_token")
			return
		# No attacker selected: show detail
		if player_table and player_table.card_detail_panel:
			player_table.card_detail_panel.visible = true
			player_table.card_detail_panel.show_card(card, "", {})
		return
# ============================================================
# BossCore 閻樿埖鈧礁濮╅悽?
# ============================================================

## 閼惧嘲褰?BossCore 閺嶇濡悙鐧哥礄鐎瑰鍙忛敍?
func _get_boss_core() -> Node3D:
	var vpc := get_node_or_null(NodePath("Battle3DViewport")) as SubViewportContainer
	if not vpc: return null
	var vp := vpc.get_node_or_null(NodePath("SubViewport")) as SubViewport
	if not vp: return null
	var core := vp.get_node_or_null(NodePath("BattleStage3D/BoardSpace3D/BoardRoot3D/BossCore")) as Node3D
	if core: return core
	return vp.get_node_or_null(NodePath("BattleStage3D/BossCore")) as Node3D

func _get_boss_core_node(p_name: String) -> Node:
	var root := _get_boss_core()
	if not root: return null
	return root.get_node_or_null(NodePath(p_name))

## Calm 閳?閺嗘鎽戞担搴″帨閿涘瞼绱﹂幈銏犳嚑閸?
func _animate_boss_core_calm() -> void:
	var core := _get_boss_core_node("CoreSphere") as MeshInstance3D
	var glow := _get_boss_core_node("CoreGlow") as MeshInstance3D
	var light := _get_boss_core_node("CoreLight") as OmniLight3D
	if not core: return

	_tween_material(core, Color(0.25, 0.40, 0.70, 1))
	if glow: _tween_material(glow, Color(0.2, 0.4, 0.8, 0.25))
	if light and is_instance_valid(light):
		if _boss_core_light_tween and _boss_core_light_tween.is_valid():
			_boss_core_light_tween.kill()
		_boss_core_light_tween = create_tween(); _boss_core_light_tween.set_loops()
		_boss_core_light_tween.tween_property(light, "light_energy", 0.35, 2.0).set_trans(Tween.TRANS_SINE)
		_boss_core_light_tween.tween_property(light, "light_energy", 0.2, 2.0).set_trans(Tween.TRANS_SINE)

## _animate_boss_core_heated
func _animate_boss_core_heated() -> void:
	var core := _get_boss_core_node("CoreSphere") as MeshInstance3D
	var glow := _get_boss_core_node("CoreGlow") as MeshInstance3D
	var light := _get_boss_core_node("CoreLight") as OmniLight3D
	if not core: return

	_tween_material(core, Color(0.85, 0.35, 0.08, 1))
	if glow: _tween_material(glow, Color(0.9, 0.4, 0.1, 0.35))
	if light and is_instance_valid(light):
		light.light_color = Color(1, 0.45, 0.1, 1)
		if _boss_core_light_tween and _boss_core_light_tween.is_valid():
			_boss_core_light_tween.kill()
		_boss_core_light_tween = create_tween(); _boss_core_light_tween.set_loops()
		_boss_core_light_tween.tween_property(light, "light_energy", 0.8, 1.2).set_trans(Tween.TRANS_SINE)
		_boss_core_light_tween.tween_property(light, "light_energy", 0.4, 1.2).set_trans(Tween.TRANS_SINE)

## _animate_boss_core_overdrive
func _animate_boss_core_overdrive() -> void:
	_flash_boss_zone(TC.ZONE_OVERDRIVE)
	var root := _get_boss_core()
	var core := _get_boss_core_node("CoreSphere") as MeshInstance3D
	var glow := _get_boss_core_node("CoreGlow") as MeshInstance3D
	var light := _get_boss_core_node("CoreLight") as OmniLight3D
	if not core: return

	_tween_material(core, Color(0.95, 0.08, 0.02, 1))
	if glow: _tween_material(glow, Color(1, 0.1, 0.03, 0.5))
	if light and is_instance_valid(light):
		light.light_color = Color(1, 0.1, 0.02, 1)
		if _boss_core_light_tween and _boss_core_light_tween.is_valid():
			_boss_core_light_tween.kill()
		_boss_core_light_tween = create_tween(); _boss_core_light_tween.set_loops()
		_boss_core_light_tween.tween_property(light, "light_energy", 1.5, 0.6).set_trans(Tween.TRANS_SINE)
		_boss_core_light_tween.tween_property(light, "light_energy", 0.7, 0.6).set_trans(Tween.TRANS_SINE)

	# [Fixed]
	if root and is_instance_valid(root):
		if _boss_core_root_tween and _boss_core_root_tween.is_valid():
			_boss_core_root_tween.kill()
		_boss_core_root_tween = create_tween(); _boss_core_root_tween.set_loops()
		_boss_core_root_tween.tween_property(root, "scale", Vector3(1.08, 1.08, 1.08), 0.4).set_trans(Tween.TRANS_SINE)
		_boss_core_root_tween.tween_property(root, "scale", Vector3(1.0, 1.0, 1.0), 0.4).set_trans(Tween.TRANS_SINE)

## 濠垫帗顒?閳?娑撳秶菙鐎规岸妫悜?
func _animate_boss_core_low_hp() -> void:
	var core := _get_boss_core_node("CoreSphere") as MeshInstance3D
	var light := _get_boss_core_node("CoreLight") as OmniLight3D
	if not core: return

	_tween_material(core, Color(0.9, 0.15, 0.05, 1))
	if light and is_instance_valid(light):
		light.light_color = Color(1, 0.15, 0.05, 1)
		if _boss_core_light_tween and _boss_core_light_tween.is_valid():
			_boss_core_light_tween.kill()
		_boss_core_light_tween = create_tween(); _boss_core_light_tween.set_loops()
		_boss_core_light_tween.tween_property(light, "light_energy", 1.2, 0.3).set_trans(Tween.TRANS_SINE)
		_boss_core_light_tween.tween_property(light, "light_energy", 0.1, 0.5).set_trans(Tween.TRANS_SINE)

## 濮濊楠?閳?閺嶇绺鹃弳妤冧純
func _animate_boss_core_dead() -> void:
	var core := _get_boss_core_node("CoreSphere") as MeshInstance3D
	var glow := _get_boss_core_node("CoreGlow") as MeshInstance3D
	var light := _get_boss_core_node("CoreLight") as OmniLight3D

	# Phase 23C0-R2: Only create Tween when >=1 valid animation target exists
	var has_core := core != null
	var has_glow := glow != null
	var has_light := light != null

	if not has_core and not has_glow and not has_light:
		# No 3D BossCore nodes 鈥?headless or missing GLB, skip animation safely
		return

	var t := create_tween()
	t.set_parallel(true)
	if has_core: t.tween_property(core, "scale", Vector3(0.01, 0.01, 0.01), 0.6).set_trans(Tween.TRANS_CUBIC)
	if has_glow: t.tween_property(glow, "scale", Vector3(0.01, 0.01, 0.01), 0.6).set_trans(Tween.TRANS_CUBIC)
	if has_light: t.tween_property(light, "light_energy", 0.0, 0.5)

	# 绾板氦顥囩喊搴ｅ閿?娑擃亜鐨弬鐟版健閸氭垵顦绘鐐存殠閿?
	var root := _get_boss_core()
	if root:
		for i in range(4):
			var frag := MeshInstance3D.new()
			frag.name = "Fragment%d" % i
			var fm := BoxMesh.new(); fm.size = Vector3(0.06, 0.06, 0.06)
			frag.mesh = fm
			frag.material_override = _make_mat(Color(0.8, 0.3, 0.1, 1))
			frag.position = Vector3(0, 0.05, 0)
			root.add_child(frag)
			var dir := Vector3(sin(i * PI / 2.0) * 1.5, randf_range(0.3, 0.8), cos(i * PI / 2.0) * 1.5)
			var ft := create_tween()
			ft.tween_property(frag, "position", dir, 0.5).set_trans(Tween.TRANS_CUBIC)
			ft.parallel().tween_property(frag, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
			ft.tween_callback(frag.queue_free)

## BossCore 閸欐鍤梻顏嗗
func _flash_boss_core() -> void:
	var core := _get_boss_core_node("CoreSphere") as MeshInstance3D
	var light := _get_boss_core_node("CoreLight") as OmniLight3D
	var root := _get_boss_core()
	if not core: return

	_tween_material(core, Color(1, 0.3, 0.3, 1))
	var t := create_tween()
	t.tween_property(core, "scale", Vector3(1.15, 1.15, 1.15), 0.05)
	t.tween_property(core, "scale", Vector3(1.0, 1.0, 1.0), 0.06)
	if light:
		var lt := create_tween()
		lt.tween_property(light, "light_energy", 2.0, 0.06)
		lt.tween_property(light, "light_energy", 0.5, 0.15)
	if root:
		var rt := create_tween()
		rt.tween_property(root, "position:z", root.position.z + 0.08, 0.04)
		rt.tween_property(root, "position:z", root.position.z, 0.1)

## _tween_material
func _tween_material(node: MeshInstance3D, target: Color) -> void:
	if not node or not node.material_override:
		return
	var t := create_tween()
	t.tween_property(node.material_override, "albedo_color", target, 0.3)

## 閼惧嘲褰?BattleStage3D 娑撳娈戞禒缁樺壈鐎涙劘濡悙?
func _get_board_node(p_name: String) -> MeshInstance3D:
	var vpc := get_node_or_null(NodePath("Battle3DViewport")) as SubViewportContainer
	if not vpc: return null
	var vp := vpc.get_node_or_null(NodePath("SubViewport")) as SubViewport
	if not vp: return null
	var node := vp.get_node_or_null(NodePath("BattleStage3D/BoardSpace3D/BoardRoot3D/" + p_name)) as MeshInstance3D
	if node: return node
	return vp.get_node_or_null(NodePath("BattleStage3D/" + p_name)) as MeshInstance3D

## _pulse_center_line
func _pulse_center_line(flash_color: Color) -> void:
	var line := _get_board_node("CenterLine")
	if not line or not line.material_override:
		return
	var orig: Color = line.material_override.albedo_color
	var t := create_tween()
	t.tween_property(line.material_override, "albedo_color", flash_color, 0.1)
	t.tween_property(line.material_override, "albedo_color", orig, 0.2)

## BossZone 閸栧搫鐓欓梻顏勫帨閿涘湵rap閸欏秴鍩?Boss閸欐ê瀵查敍?
func _flash_boss_zone(flash_color: Color) -> void:
	var zone := _get_board_node("BossZone")
	if not zone or not zone.material_override:
		return
	var orig: Color = zone.material_override.albedo_color
	var t := create_tween()
	t.tween_property(zone.material_override, "albedo_color", flash_color, 0.06)
	t.tween_property(zone.material_override, "albedo_color", orig, 0.25)

## PlayerZone 闂傤亜鍘滈敍鍦眗ap鐠佸墽鐤?Trap鐟欙箑褰傞敍?
func _flash_player_zone(flash_color: Color) -> void:
	var zone := _get_board_node("PlayerZone")
	if not zone or not zone.material_override:
		return
	var orig: Color = zone.material_override.albedo_color
	var t := create_tween()
	t.tween_property(zone.material_override, "albedo_color", flash_color, 0.06)
	t.tween_property(zone.material_override, "albedo_color", orig, 0.25)

## _shake_boss_core_heavy
## Phase 27K-R1-D Task 8: Reduced Motion keeps the Boss core static and
## suppresses heavy screen shake so finisher results remain readable.
func _is_reduced_motion_presentation() -> bool:
	if _development_showcase_mode and _development_showcase_reduced_motion:
		return true
	if _combat_presentation_profile == null:
		return false
	return _combat_presentation_profile.has_method("is_reduced_motion_default") \
		and bool(_combat_presentation_profile.call("is_reduced_motion_default"))


func _shake_boss_core_heavy() -> void:
	if _is_reduced_motion_presentation():
		return
	var root := _get_boss_core()
	if not root: return
	var orig := root.position
	var t := create_tween()
	for i in range(6):
		t.tween_property(root, "position:x", orig.x + randf_range(-0.12, 0.06), 0.03)
		t.tween_property(root, "position:y", orig.y + randf_range(-0.06, 0.06), 0.03)
	t.tween_property(root, "position", orig, 0.08)

# 閳光偓閳光偓 娴笺倕顔婄捄鍐茬摟 閳光偓閳光偓
func _show_damage_number(value: int, target: Control, crit: bool = false) -> void:
	if value <= 0:
		return
	if not is_instance_valid(target):
		return
	var dmg_scene = load("res://ui/damage_number.tscn")
	if dmg_scene == null:
		return
	var dmg = dmg_scene.instantiate()
	if dmg == null:
		return
	add_child(dmg)
	dmg.global_position = target.global_position + Vector2(target.size.x / 2, -20)
	if dmg.has_method("setup"):
		dmg.setup(value, crit)

## 閸楋紕澧濋崣顖氬毉閹勵梾閺屻儻绱欐笟?PlayerTable.rebuild_hand 娴ｈ法鏁ら敍?
## 鏉╂柨娲?Dictionary: {ok: bool, reason: String}
func _get_card_status(card: CardData) -> Dictionary:
	if not battle or not battle.has_method("can_play_card"):
		return {"ok": true, "reason": ""}
	if battle.has_method("get_card_play_status"):
		var status: Dictionary = battle.get_card_play_status(card).duplicate(true)
		if battle._ritual_trial != null and battle.frontline_trial != null:
			status["hand_facts"] = preload("res://ui/hand_card_readability.gd").build(card, status, battle)
		var board_drag_intent := _classify_board_drag_intent(card)
		status["board_drag_intent"] = board_drag_intent
		status["contextual_board_drag"] = board_drag_intent == &"structure_build" \
			and not bool(status.get("ok", false)) and battle.needs_building_replacement(card)
		return status

	var od_mode: ODMode = context.od_mode
	var player: Player = context.player

	if card.require_od > od_mode.current_od:
		return {"ok": false, "reason": "OD:%d/%d" % [od_mode.current_od, card.require_od]}
	if card.require_load > od_mode.load:
		return {"ok": false, "reason": "Load:%d/%d" % [od_mode.load, card.require_load]}
	if card.require_hp_cost > player.hp:
		return {"ok": false, "reason": "Not enough HP"}
	if card.require_awaken and not player.is_awakened:
		return {"ok": false, "reason": "Awaken required"}
	if card.is_front_row_card() and player.field.size() >= 5:
		return {"ok": false, "reason": "Front row full"}
	if card.is_back_row_card() and player.traps.size() >= 5:
		return {"ok": false, "reason": "Back row full"}
	if context and context.has_method("is_abyss_locked") and context.is_abyss_locked():
		if card.archetype_role != CardData.ArchetypeRole.CONTROL:
			return {"ok": false, "reason": "Abyss Lock: only CONTROL. Use Cooldown/Heat Sink"}
	if not battle.can_play_card(card):
		return {"ok": false, "reason": "Cannot play"}
	return {"ok": true, "reason": ""}

# ============================================================
# Phase 27D-R5-R2-R2: Safe notification positioning
# ============================================================

## Build list of reserved UI rects that transient notifications must avoid.
func _get_reserved_ui_rects(margin_etc := 12, margin_hud := 8, margin_core := 8) -> Array[Rect2]:
	var out: Array[Rect2] = []
	# EndTurnControl
	if _end_turn_control and is_instance_valid(_end_turn_control) and _end_turn_control.visible:
		var r: Rect2 = _end_turn_control.get_global_rect()
		if r.size.x > 0 and r.size.y > 0:
			out.append(Rect2(r.position.x - margin_etc, r.position.y - margin_etc, r.size.x + 2*margin_etc, r.size.y + 2*margin_etc))
	# CommandEconomyHUD
	if _command_economy_hud and is_instance_valid(_command_economy_hud) and _command_economy_hud.visible:
		var r: Rect2 = _command_economy_hud.get_global_rect()
		if r.size.x > 0 and r.size.y > 0:
			out.append(Rect2(r.position.x - margin_hud, r.position.y - margin_hud, r.size.x + 2*margin_hud, r.size.y + 2*margin_hud))
	# CoreStatusPanel (OD ENGINE)
	var core_panel := get_node_or_null(NodePath("BattleTable/CoreStatusPanel")) as Control
	if core_panel and core_panel.visible and is_instance_valid(core_panel):
		var r: Rect2 = core_panel.get_global_rect()
		if r.size.x > 0 and r.size.y > 0:
			out.append(Rect2(r.position.x - margin_core, r.position.y - margin_core, r.size.x + 2*margin_core, r.size.y + 2*margin_core))
	# Phase 27I-R0-R2: 手牌区域（HandArea）加入保留矩形，临时提示不得覆盖手牌
	var hand_area := get_node_or_null(NodePath("HandArea")) as Control
	if hand_area and hand_area.visible and is_instance_valid(hand_area):
		var r_hand: Rect2 = hand_area.get_global_rect()
		if r_hand.size.x > 0 and r_hand.size.y > 0:
			out.append(Rect2(r_hand.position.x - margin_etc, r_hand.position.y - margin_etc, r_hand.size.x + 2*margin_etc, r_hand.size.y + 2*margin_etc))
	# DetailPanelSlot（详情栏区域）
	if _detail_panel_slot and is_instance_valid(_detail_panel_slot) and _detail_panel_slot.visible:
		var r_detail: Rect2 = _detail_panel_slot.get_global_rect()
		if r_detail.size.x > 0 and r_detail.size.y > 0:
			out.append(Rect2(r_detail.position.x - margin_etc, r_detail.position.y - margin_etc, r_detail.size.x + 2*margin_etc, r_detail.size.y + 2*margin_etc))
	# ArsenalPanel（底部左侧，仅当可见时保留）
	if _arsenal_panel and is_instance_valid(_arsenal_panel) and _arsenal_panel.visible:
		var r_ars: Rect2 = _arsenal_panel.get_global_rect()
		if r_ars.size.x > 0 and r_ars.size.y > 0:
			out.append(Rect2(r_ars.position.x - margin_etc, r_ars.position.y - margin_etc, r_ars.size.x + 2*margin_etc, r_ars.size.y + 2*margin_etc))
	return out


func _get_structure_reserved_ui_rects() -> Array[Rect2]:

	var out := _get_reserved_ui_rects()
	for overlay in get_tree().get_nodes_in_group("battle_development_overlay"):
		if overlay is Control and overlay.is_visible_in_tree():
			out.append(overlay.get_global_rect().grow(8.0))
	if boss_intent_card != null and is_instance_valid(boss_intent_card) and boss_intent_card.visible:
		var intent_rect: Rect2 = boss_intent_card.get_global_rect()
		if intent_rect.size.x > 0.0 and intent_rect.size.y > 0.0:
			out.append(intent_rect.grow(12.0))
	elif boss_intent_slot != null and is_instance_valid(boss_intent_slot) and boss_intent_slot.visible:
		var intent_slot_rect: Rect2 = boss_intent_slot.get_global_rect()
		if intent_slot_rect.size.x > 0.0 and intent_slot_rect.size.y > 0.0:
			out.append(intent_slot_rect.grow(12.0))
	return out


## Check if a candidate rect is safe (inside viewport margins, no intersection with reserved rects).
func _is_notification_rect_safe(rect: Rect2, reserved: Array[Rect2], vp_size: Vector2, margin := 16) -> bool:
	if rect.position.x < margin or rect.position.y < margin:
		return false
	if rect.end.x > vp_size.x - margin or rect.end.y > vp_size.y - margin:
		return false
	for r: Rect2 in reserved:
		if rect.intersects(r):
			return false
	return true


## Compute a safe global position for a transient notification label.
## Tries: preferred → left-of-ETC → above-ETC → clamp-to-viewport.
func _get_safe_notification_position(label_size: Vector2, preferred_global_pos: Vector2, allow_stacking := true) -> Vector2:
	var vp_rect: Rect2 = get_viewport().get_visible_rect()
	var vp_size: Vector2 = vp_rect.size
	var reserved: Array[Rect2] = _get_reserved_ui_rects()
	const SAFE_MARGIN := 16
	const STACK_GAP := 6

	# If stacking, offset below last notification
	if allow_stacking and _notification_stack_count > 0:
		var stack_y: float = _last_notification_rect.end.y + STACK_GAP
		var stack_pos: Vector2 = Vector2(_last_notification_rect.position.x, stack_y)
		var stack_rect: Rect2 = Rect2(stack_pos, label_size)
		if _is_notification_rect_safe(stack_rect, reserved, vp_size, SAFE_MARGIN):
			_notification_stack_count += 1
			_last_notification_rect = stack_rect
			return stack_pos

	# Candidate 0: preferred position
	var pref_rect: Rect2 = Rect2(preferred_global_pos, label_size)
	if _is_notification_rect_safe(pref_rect, reserved, vp_size, SAFE_MARGIN):
		_track_notification(pref_rect, allow_stacking)
		return preferred_global_pos

	# Candidate 1: left of EndTurnControl
	if _end_turn_control and is_instance_valid(_end_turn_control) and _end_turn_control.visible:
		var etc_r: Rect2 = _end_turn_control.get_global_rect()
		var left_pos: Vector2 = Vector2(etc_r.position.x - label_size.x - 16, preferred_global_pos.y)
		var left_rect: Rect2 = Rect2(left_pos, label_size)
		if _is_notification_rect_safe(left_rect, reserved, vp_size, SAFE_MARGIN):
			_track_notification(left_rect, allow_stacking)
			return left_pos

	# Candidate 2: above EndTurnControl
	if _end_turn_control and is_instance_valid(_end_turn_control) and _end_turn_control.visible:
		var etc_r: Rect2 = _end_turn_control.get_global_rect()
		var above_pos: Vector2 = Vector2(preferred_global_pos.x, etc_r.position.y - label_size.y - 12)
		var above_rect: Rect2 = Rect2(above_pos, label_size)
		if _is_notification_rect_safe(above_rect, reserved, vp_size, SAFE_MARGIN):
			_track_notification(above_rect, allow_stacking)
			return above_pos

	# Fallback: clamp to viewport safe area
	var clamped: Vector2 = Vector2(
		clamp(preferred_global_pos.x, float(SAFE_MARGIN), vp_size.x - SAFE_MARGIN - label_size.x),
		clamp(preferred_global_pos.y, float(SAFE_MARGIN), vp_size.y - SAFE_MARGIN - label_size.y)
	)
	var clamped_rect: Rect2 = Rect2(clamped, label_size)
	_track_notification(clamped_rect, allow_stacking)
	return clamped


func _track_notification(rect: Rect2, allow_stacking: bool) -> void:
	if allow_stacking:
		_notification_stack_count = 1
		_last_notification_rect = rect


func _clear_notification_stack() -> void:
	_notification_stack_count = 0
	_last_notification_rect = Rect2()


# ============================================================
# Toast — 一次性通知（带 key 去重）
# ============================================================
func _show_toast(key: String, text: String, color: Color = Color.WHITE, duration: float = 2.0) -> void:
	if _toast_shown.get(key, false):
		return
	_toast_shown[key] = true

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	# Phase 27D-R5-R2-R2: safe positioning — estimate size, avoid reserved UI
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var est_w: float = min(text.length() * 10.0 + 20, 560)
	var est_h: float = 40.0
	var preferred: Vector2 = Vector2((vp_size.x - est_w) / 2, vp_size.y * 0.82)
	var safe_pos: Vector2 = _get_safe_notification_position(Vector2(est_w, est_h), preferred)
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.global_position = safe_pos
	label.custom_minimum_size = Vector2(est_w, est_h)
	label.modulate.a = 0.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = ZI_CENTER_TEXT
	add_child(label)

	var t := create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.2)
	t.tween_interval(duration)
	t.tween_property(label, "modulate:a", 0.0, 0.35)
	t.tween_callback(label.queue_free)

# ============================================================
# 娑撳秴褰查崙铏瑰閸樼喎娲滈幓鎰仛
# ============================================================
func _show_unplayable_reason(card: CardData) -> void:
	var am = _am()
	if am:
		am.play_ui_error()
	if card == null:
		return


	var status := _get_card_status(card)
	var msg: String = status.get("reason", "")
	if msg == "":
		pass  # fixed garbled code

	# 鏉╂稑鍙?ActionFeed閿涘奔绗夐崡鐘垫暏娑擃厼銇庨崠鍝勭厵
	if msg != "" and action_feed:
		action_feed.push_message(msg, TC.WARNING)

# ============================================================
# Phase 1A閿涙矮鑵戞径顔笺亣娴滃娆㈤幘顓熷Г
# ============================================================
## 娑擃厼銇庢径褌绨ㄦ禒鑸垫尡閹躲儻绱欐禍鎺撴灱閿涘本鏌婃禍瀣╂閹垫挻鏌囬弮褌绨ㄦ禒璁圭礆
func _announce_major_event(text: String, color: Color, duration: float = 0.8) -> void:
	if not event_announce_label:
		return
	# Fade in, hold, then fade out.
	if _major_event_tween and _major_event_tween.is_valid():
		_major_event_tween.kill()
	event_announce_label.text = text
	event_announce_label.add_theme_color_override("font_color", color)
	event_announce_label.modulate.a = 0.0
	event_announce_label.scale = Vector2(0.85, 0.85)
	event_announce_label.visible = true
	_major_event_tween = create_tween()
	_major_event_tween.set_parallel(true)
	_major_event_tween.tween_property(event_announce_label, "modulate:a", 0.85, 0.15)
	_major_event_tween.tween_property(event_announce_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_major_event_tween.tween_property(event_announce_label, "modulate:a", 0.0, 0.3).set_delay(duration - 0.3)
	_major_event_tween.tween_callback(_on_major_event_finished).set_delay(duration)

## 婢堆傜皑娴犺埖鎸遍幎銉ョ暚閹存劕娲栫拫鍐跨礄閸涜棄鎮曢崙鑺ユ殶閿涘本妫?lambda capture閿?
func _on_major_event_finished() -> void:
	if event_announce_label:
		event_announce_label.visible = false
	_major_event_tween = null

# ============================================================
# 闁氨鏁ゅù顔肩摟閸欏秹顩敍鍦眞een 濞ｂ€冲弳娑撳﹥璇炲ǎ鈥冲毉閿?
# ============================================================
## 娑擃厼銇庨崗鎶芥暛娣団剝浼呴敍鍫滅鞍閺傘儻绱版稉鈧▎鈥冲涧閺勫墽銇氭稉鈧弶鈽呯礆
func _show_center_critical(text: String, color: Color, duration: float = 1.5, font_size: int = 32) -> void:
	if _center_text_active:
		return
	_center_text_active = true
	_show_floating_text(text, color, duration, font_size)
	await get_tree().create_timer(duration).timeout
	_center_text_active = false

func _show_floating_text(text: String, color: Color, duration: float = 1.5, font_size: int = 32) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	# Phase 27D-R5-R2-R2: safe positioning for floating text
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var est_w: float = min(font_size * text.length() * 0.55 + 20, 500)
	var est_h: float = font_size * 1.6
	var preferred: Vector2 = Vector2((vp_size.x - est_w) / 2, (vp_size.y - est_h) / 2)
	var safe_pos: Vector2 = _get_safe_notification_position(Vector2(est_w, est_h), preferred)
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.global_position = safe_pos
	label.modulate.a = 0.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = ZI_FLOATING_TEXT
	add_child(label)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(label, "modulate:a", 1.0, 0.06)
	t.tween_property(label, "position:y", label.position.y - 50, duration)
	t.tween_property(label, "modulate:a", 0.0, 0.25).set_delay(duration - 0.25)
	t.tween_callback(label.queue_free).set_delay(duration)

# ============================================================
# 閹存ɑ鏋熼崷鐑樻珯缁狙呯波閺夌喎娲栭崥鍫熷瘻闁筋噯绱欓崣鍏呯瑓鐟欐帪绱濇稉宥堫潶閹靛澧?鐠囷附鍎忛棃銏℃緲闁喗灏呴敍?
# ============================================================
# Phase 27D-R5-R2-R3: ActionFeed safe lane in BattleFX
# ============================================================

## Create/return the ActionFeedSafeLane container in BattleFX CanvasLayer.
## Positioned above EndTurnControl (y=278..440, gap=20px to ETC at y=460).
func _ensure_action_feed_safe_lane() -> Control:
	var existing := get_node_or_null(NodePath("BattleFX/ActionFeedSafeLane")) as Control
	if existing and is_instance_valid(existing):
		return existing

	var fx_layer := get_node_or_null(NodePath("BattleFX")) as CanvasLayer
	if fx_layer == null or not is_instance_valid(fx_layer):
		add_child(CanvasLayer.new())
		var cl := get_child(get_child_count() - 1) as CanvasLayer
		cl.name = "BattleFX"
		fx_layer = cl

	var lane := Control.new()
	lane.name = "ActionFeedSafeLane"
	lane.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Position above EndTurnControl: right-aligned, 20px gap to ETC top (460)
	lane.offset_left = -300
	lane.offset_right = -20
	lane.offset_top = 278
	lane.offset_bottom = 440
	lane.custom_minimum_size = Vector2(280, 162)
	lane.clip_contents = true
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane.z_index = ZI_CENTER_TEXT  # above table content, below overlay
	fx_layer.add_child(lane)
	return lane


# ============================================================
# Phase 27D-R5-R2: Compact EndTurnControl (was full-height blue button)
# ============================================================
func _create_end_turn_button() -> void:
	var ETCClass := load("res://ui/end_turn_control.gd")
	if ETCClass and ETCClass.can_instantiate():
		_end_turn_control = ETCClass.new()
		_end_turn_control.name = "EndTurnControl"
		_end_turn_control.custom_minimum_size = Vector2(140, 56)
		_end_turn_control.mouse_filter = Control.MOUSE_FILTER_STOP
		_end_turn_control.z_index = ZI_END_TURN  # 100

		# Position: right side, mid-board
		_end_turn_control.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_end_turn_control.offset_left = -180
		_end_turn_control.offset_right = -20
		_end_turn_control.offset_top = 460
		_end_turn_control.offset_bottom = 530
		_end_turn_control.size = Vector2(160, 70)

		# Place in BattleFX CanvasLayer for proper z-ordering
		var fx_layer := get_node_or_null(NodePath("BattleFX"))
		if fx_layer:
			fx_layer.add_child(_end_turn_control)
		else:
			add_child(_end_turn_control)

		# Connect end turn signal
		if not _end_turn_control.end_turn_requested.is_connected(_on_end_turn):
			_end_turn_control.end_turn_requested.connect(_on_end_turn)

		# Configure economy callback
		if battle and battle.has_method("get_command_economy_snapshot"):
			_end_turn_control.configure_economy(Callable(battle, "get_command_economy_snapshot").bind("player"))

		_end_turn_control.visible = false
		print("[Phase 27D-R5-R2] EndTurnControl created")
	else:
		# Fallback compact button
		_end_turn_btn = Button.new()
		_end_turn_btn.name = "BattleEndTurnBtn"
		_end_turn_btn.text = "End Turn"
		_end_turn_btn.custom_minimum_size = Vector2(130, 44)
		_end_turn_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_end_turn_btn.z_index = ZI_END_TURN
		_end_turn_btn.anchor_left = 1.0
		_end_turn_btn.anchor_right = 1.0
		_end_turn_btn.anchor_bottom = 1.0
		_end_turn_btn.offset_left = -160
		_end_turn_btn.offset_right = -30
		_end_turn_btn.offset_bottom = -100
		_end_turn_btn.offset_top = -144
		var ns := StyleBoxFlat.new()
		ns.bg_color = Color(0.08, 0.10, 0.18, 0.85)
		ns.border_color = Color(0.2, 0.5, 0.7, 1.0)
		ns.border_width_left = 1; ns.border_width_right = 1
		ns.border_width_top = 1; ns.border_width_bottom = 1
		ns.set_corner_radius_all(8)
		_end_turn_btn.add_theme_stylebox_override("normal", ns)
		_end_turn_btn.add_theme_font_size_override("font_size", 15)
		_end_turn_btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1))
		_end_turn_btn.pressed.connect(_on_end_turn)
		add_child(_end_turn_btn)
		_end_turn_btn.visible = false
		_end_turn_btn.disabled = true
		_end_turn_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Phase 27D-R5-R2-R: hidden by default

func _show_battle_hint() -> void:
	# Phase 23A-R3: 3D board mode 鈥?BattleHint is a legacy 2D overlay.
	# The 3D HUD / EngineGauge is the single authority for boss info.
	if USE_TRUE_3D_BOARD_BACKGROUND:
		return
	if battle_ended:
		return

	# Boss 閸氬秶澧栧ù顔肩湴
	var hint_panel := Panel.new()
	hint_panel.name = "BattleHintPanel"
	hint_panel.set_anchors_preset(Control.PRESET_CENTER)
	hint_panel.custom_minimum_size = Vector2(420, 200)
	hint_panel.offset_left = -210
	hint_panel.offset_top = -100
	hint_panel.offset_right = 210
	hint_panel.offset_bottom = 100
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.06, 0.94)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = TC.ZONE_OVERDRIVE
	style.set_corner_radius_all(8)
	hint_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16; vbox.offset_top = 12
	vbox.offset_right = -16; vbox.offset_bottom = -12
	vbox.add_theme_constant_override("separation", 6)
	hint_panel.add_child(vbox)

	# Boss 閸?
	var title := Label.new()
	title.text = "Boss: 熔炉守卫  HP 85"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", TC.ZONE_OVERDRIVE)
	vbox.add_child(title)

	var tips := [
		"目标：控制 OD → 完成 Chain → 释放 Finisher",
		"Boss 也会积累 OD，注意 Overdrive 爆发",
		"按 Chain Route 顺序出牌可强化终结技",
	]
	for t in tips:
		var l := Label.new()
		l.text = t
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", TC.TEXT_SECONDARY)
		vbox.add_child(l)

	var close_label := Label.new()
	close_label.text = "(Click anywhere to continue)"
	close_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_label.add_theme_font_size_override("font_size", 11)
	close_label.add_theme_color_override("font_color", TC.TEXT_DIM)
	vbox.add_child(close_label)

	add_child(hint_panel)

	var click_area := ColorRect.new()
	click_area.name = "HintClickArea"
	click_area.color = Color(0, 0, 0, 0)
	click_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	click_area.gui_input.connect(_on_hint_clicked)
	add_child(click_area)

	# 鐎涙ê鍙嗛幋鎰喅閸欐﹢鍣洪敍灞肩返 _dismiss_hint / _auto_dismiss_hint 娴ｈ法鏁ら敍鍫熸￥ lambda閿?
	_hint_panel = hint_panel
	_hint_click_area = click_area

	var t := create_tween()
	t.tween_interval(8.0)
	t.tween_callback(_auto_dismiss_hint)

func _auto_dismiss_hint() -> void:
	# 閸涜棄鎮曢崙鑺ユ殶閿涘本妫?lambda capture
	_dismiss_hint()

func _on_hint_clicked(event: InputEvent) -> void:
	# 閸涜棄鎮曢崙鑺ユ殶閿涘本妫?lambda / bind capture
	if event is InputEventMouseButton and event.pressed:
		_dismiss_hint()

func _dismiss_hint() -> void:
	if not is_instance_valid(_hint_panel):
		_hint_panel = null
		_hint_click_area = null
		return

	var panel := _hint_panel
	var click := _hint_click_area
	_hint_panel = null
	_hint_click_area = null

	_hint_nodes_to_free = [panel, click]

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(panel, "modulate:a", 0.0, 0.3)
	t.tween_property(panel, "scale", Vector2(0.95, 0.95), 0.3)
	t.tween_callback(_free_hint_nodes)

func _free_hint_nodes() -> void:
	# 閸涜棄鎮曢崙鑺ユ殶閿涘本妫?lambda capture
	for node in _hint_nodes_to_free:
		if is_instance_valid(node):
			node.queue_free()
	_hint_nodes_to_free.clear()


func _purge_legacy_guide_controls() -> void:
	if not USE_TRUE_3D_BOARD_BACKGROUND or ENABLE_LEGACY_GUIDES_IN_3D:
		return
	for node_name in ["GuideSkipBtn", "TutorialHintPanel", "BattleHintPanel", "HintClickArea"]:
		var node := find_child(node_name, true, false)
		if node and is_instance_valid(node):
			node.queue_free()
	if _guide_skip_btn and is_instance_valid(_guide_skip_btn):
		_guide_skip_btn.queue_free()
	_guide_skip_btn = null
	if _tutorial_hint_panel and is_instance_valid(_tutorial_hint_panel):
		_tutorial_hint_panel.queue_free()
	_tutorial_hint_panel = null

# 閳光偓閳光偓 瀵洖顕辩捄瀹犵箖閹稿鎸?閳光偓閳光偓
func _create_guide_skip_btn() -> void:
	if USE_TRUE_3D_BOARD_BACKGROUND and not ENABLE_LEGACY_GUIDES_IN_3D:
		return
	_guide_skip_btn = Button.new()
	_guide_skip_btn.name = "GuideSkipBtn"
	_guide_skip_btn.text = "Skip"
	_guide_skip_btn.custom_minimum_size = Vector2(70, 24)
	_guide_skip_btn.anchor_left = 1.0; _guide_skip_btn.anchor_top = 0.0
	_guide_skip_btn.offset_left = -80; _guide_skip_btn.offset_top = 6
	_guide_skip_btn.add_theme_font_size_override("font_size", 10)
	_guide_skip_btn.pressed.connect(_toggle_guides)
	add_child(_guide_skip_btn)

func _toggle_guides() -> void:
	_guides_enabled = not _guides_enabled
	if _guide_skip_btn:
		pass  # fixed garbled code

# [Fixed func]
func _trigger_guides_on_card_play() -> void:
	_show_guide("play_card", "Starter 已启动 OD 引擎", TC.ZONE_CALM)

func _trigger_guides_on_heated() -> void:
	pass  # fixed garbled code

func _trigger_guides_on_overdrive() -> void:
	pass  # fixed garbled code

func _trigger_guides_boss_danger() -> void:
	_show_guide("boss_danger", "Boss 即将爆发：可用 Control 或 Trap 降温", TC.ZONE_HEATED)

func _trigger_guides_chain_step() -> void:
	_show_guide("chain_step", "按路线出牌可获得 Chain 奖励", TC.ACCENT_GOLD)

func _trigger_guides_chain_done() -> void:
	pass  # fixed garbled code

func _trigger_guides_finisher_ready() -> void:
	_show_guide("finisher_ready", "终结技已就绪：打出收尾", TC.ACCENT_GOLD)

func _trigger_guides_trap_set() -> void:
	_show_guide("trap_set", "Trap 会在 Boss 回合自动反制", TC.ROLE_CONTROL)

func _trigger_guides_victory() -> void:
	_show_guide("victory_end", "结算面板会展示你的 OD 路线表现", TC.ACCENT_GOLD)

# ============================================================
# Phase 11C: 閺佹瑧鈻兼稉鈧▎鈩冣偓褎褰佺粈铏归兇缂?
# ============================================================

var _tutorial_hints_shown: Dictionary = {}
var _tutorial_hint_panel: Panel = null
var _tutorial_hint_tween: Tween = null
func _show_tutorial_hint_once(key: String, message: String) -> void:
	if USE_TRUE_3D_BOARD_BACKGROUND and not ENABLE_LEGACY_GUIDES_IN_3D:
		return
	if _tutorial_hints_shown.get(key, false):
		return
	_tutorial_hints_shown[key] = true
	_show_tutorial_hint(message)
func _show_tutorial_hint(message: String) -> void:
	if USE_TRUE_3D_BOARD_BACKGROUND and not ENABLE_LEGACY_GUIDES_IN_3D:
		return
	# 濞撳懘娅庨弮褎褰佺粈?
	_hide_tutorial_hint()

	# 閸掓稑缂撳ù顔肩湴 Panel
	_tutorial_hint_panel = Panel.new()
	_tutorial_hint_panel.name = "TutorialHintPanel"
	_tutorial_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_hint_panel.z_index = 95  # 妤傛ü绨径褔鍎撮崚?UI閿涘奔缍嗘禍?DetailPanel(200) 閸?GraveyardView(300)

	var viewport_size := get_viewport_rect().size
	# Phase 15A-R: moved up to avoid covering hand cards (hand at y=680)
	_tutorial_hint_panel.position = Vector2(viewport_size.x * 0.5 - 220, viewport_size.y * 0.65)
	_tutorial_hint_panel.size = Vector2(440, 64)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.12, 0.92)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.5, 0.7, 0.8)
	style.set_corner_radius_all(4)
	_tutorial_hint_panel.add_theme_stylebox_override("panel", style)
	add_child(_tutorial_hint_panel)

	# 鐏忓繑鐖ｆ０?
	var title := Label.new()
	title.name = "TutorialTitle"
	title.text = "提示"
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.position = Vector2(10, 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_hint_panel.add_child(title)

	var body := Label.new()
	body.name = "TutorialBody"
	body.text = message
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.position = Vector2(10, 20)
	body.size = Vector2(420, 40)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_hint_panel.add_child(body)

	# 濞ｂ€冲弳 + 閼奉亜濮╁ǎ鈥冲毉
	_tutorial_hint_panel.modulate.a = 0.0
	_safe_kill_tutorial_tween()
	_tutorial_hint_tween = create_tween()
	_tutorial_hint_tween.tween_property(_tutorial_hint_panel, "modulate:a", 1.0, 0.3)
	_tutorial_hint_tween.tween_interval(3.5)
	_tutorial_hint_tween.tween_property(_tutorial_hint_panel, "modulate:a", 0.0, 0.6)
	_tutorial_hint_tween.tween_callback(_hide_tutorial_hint)
func _hide_tutorial_hint() -> void:
	_safe_kill_tutorial_tween()
	if _tutorial_hint_panel and is_instance_valid(_tutorial_hint_panel):
		_tutorial_hint_panel.queue_free()
	_tutorial_hint_panel = null
func _safe_kill_tutorial_tween() -> void:
	if _tutorial_hint_tween and _tutorial_hint_tween.is_valid():
		_tutorial_hint_tween.kill()
	_tutorial_hint_tween = null

# ============================================================
# Phase 4B-6E: 閺夋寧蝎閸掓稑缂?閳?閹靛濮╃€规矮缍呴敍灞肩瑝娓氭繆绂?HBoxContainer
# ============================================================

const BOARD_SLOT_GAP := 12

## _create_board_slots
func _create_board_slots(container_path: String, count: int, slot_size: Vector2, border_color: Color, prefix: String) -> Array[Control]:
	var container := get_node_or_null(NodePath(container_path))
	if not container:
		push_warning("[BattleScene] _create_board_slots: container not found: %s" % container_path)
		return []

	var slots: Array[Control] = []
	for i in range(count):
		var slot := Control.new()
		slot.name = "Slot%d" % (i + 1)
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.z_index = ZI_SLOT_EMPTY  # 3

		var style := StyleBoxFlat.new()
		style.bg_color = Color(border_color.r, border_color.g, border_color.b, 0.06)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = Color(border_color.r, border_color.g, border_color.b, 0.22)
		style.set_corner_radius_all(4)

		var panel := Panel.new()
		panel.name = "SlotPanel"
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.offset_left = 0; panel.offset_top = 0
		panel.offset_right = 0; panel.offset_bottom = 0
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", style)
		# Phase 22B-R: 3D 涓绘ā寮忛殣钘忔棫 2D 妲戒綅澶栬锛屼繚鐣?Control 鐭╁舰浣滀负 fallback hit-test
		if not SHOW_2D_FIELD_CARDS:
			style.bg_color = Color(0, 0, 0, 0)  # 閫忔槑鑳屾櫙
			style.border_color = Color(0, 0, 0, 0)  # 閫忔槑杈规
			panel.add_theme_stylebox_override("panel", style)
		slot.add_child(panel)

		container.add_child(slot)
		slots.append(slot)

	# 鐎涙ê鍋嶇敮鍐ㄧ湰閸忓啯鏆熼幑顔煎煂 container閿涘奔绶?resize 閸ョ偠鐨熼崪灞芥鏉╃喎绔风仦鈧担璺ㄦ暏
	container.set_meta("_slot_array", slots)
	container.set_meta("_slot_size", slot_size)
	container.set_meta("_slot_gap", BOARD_SLOT_GAP)

	# 瀵ゆ儼绻滈崚棰佺瑓娑撯偓鐢冪鐏炩偓閿涘牏鈥樻穱?container.size 瀹歌尪顓哥粻妤嬬礆
	call_deferred("_layout_board_slots", container, slots, slot_size, BOARD_SLOT_GAP)

	# 鐏忓搫顕崣妯哄閺冨爼鍣搁弬鏉跨鐏炩偓
	if not container.resized.is_connected(_on_board_slot_container_resized):
		container.resized.connect(_on_board_slot_container_resized.bind(container))

	print("[BattleScene] Created %d slots in %s (size=%s, deferred layout)" % [count, container_path, slot_size])
	return slots
## 閹靛濮╃€规矮缍呭Σ鎴掔秴閸?RowSlot 閸愬懎鐪虫稉?
func _layout_board_slots(container: Control, slots: Array, slot_size: Vector2, gap: int) -> void:
	if not container or not is_instance_valid(container):
		return
	var cw := container.size.x
	var ch := container.size.y
	if cw <= 0 or ch <= 0:
		return  # 鐏忓搫顕亸姘弓鐠侊紕鐣婚敍宀€鐡戝?resize 闁插秷鐦?
	var total_w := slots.size() * slot_size.x + (slots.size() - 1) * gap
	var start_x := maxf(0, (cw - total_w) / 2.0)
	var y := maxf(0, (ch - slot_size.y) / 2.0)

	for i in range(slots.size()):
		var slot: Control = slots[i]
		if not is_instance_valid(slot):
			continue
		slot.position = Vector2(start_x + i * (slot_size.x + gap), y)
		slot.size = slot_size
## RowSlot 鐎圭懓娅掔亸鍝勵嚟閸欐ê瀵?閳?闁插秵鏌婄敮鍐ㄧ湰
func _on_board_slot_container_resized(container: Control) -> void:
	var slots: Array = container.get_meta("_slot_array", [])
	var slot_size: Vector2 = container.get_meta("_slot_size", Vector2(136, 104))
	var gap: int = container.get_meta("_slot_gap", BOARD_SLOT_GAP)
	_layout_board_slots(container, slots, slot_size, gap)
# ============================================================
# Phase 4B-6E: z_index 鐏炲倻楠囬崶鍝勭暰
# ============================================================

## Phase 4B-8: 缂佺喍绔?z_index 鐏炲倻楠囬敍鍫濈穿閻劑娉︽稉顓炵埗闁?ZI_*閿?
func _apply_board_z_indices() -> void:
	var surface := get_node_or_null(NodePath("BattleTable/TableSurface"))
	if surface: surface.z_index = ZI_TABLE_SURFACE  # 0

	var table_art := get_node_or_null(NodePath("BattleTable/TableArtRoot"))
	if table_art:
		table_art.z_index = ZI_DEBUG_BORDER  # 2: above legacy area fills, below empty slots/cards.

	var divider := get_node_or_null(NodePath("BattleTable/CenterDivider"))
	if divider:
		divider.z_index = ZI_SLOT_EMPTY  # 3: keep the center seam above the table art.

	# BossArea / PlayerArea 閸楀﹪鈧繑妲戦懗灞炬珯
	for area_path in ["BattleTable/BossArea", "BattleTable/PlayerArea"]:
		var area := get_node_or_null(NodePath(area_path))
		if area: area.z_index = ZI_AREA_BG  # 1

	# RowSlot 鐠嬪啳鐦潏瑙勵攱 z=ZI_DEBUG_BORDER (2)閿涙稒蝎娴ｅ秶鈹栭棃銏℃緲 z=ZI_SLOT_EMPTY (3)
	# DropZone z=ZI_DROP_ZONE (4)
	# 閸﹁桨绗?CardUI z=ZI_FIELD_CARD (5) 閳?閸?CardUI.set_display_mode 娑擃叀顔曠純?
	# ActionSlot z=ZI_ACTION_SLOT (8)
	for act_path in ["BattleTable/BossArea/BossActionSlot", "BattleTable/PlayerArea/PlayerActionSlot"]:
		var act := get_node_or_null(NodePath(act_path))
		if act: act.z_index = ZI_ACTION_SLOT  # 8

	# player_table / enemy_table 閸︺劌绁甸崗銉δ佸蹇庣瑓娑撳秵瑕嗛弻鎾瑰殰瀹歌京娈?UI
	if player_table: player_table.z_index = ZI_TABLE_SURFACE  # 0
	if enemy_table: enemy_table.z_index = ZI_TABLE_SURFACE  # 0

	# 绾喕绻?player_table / enemy_table 娑撳秹妯嗛幐锟犵炊閺嶅洣绨ㄦ禒?
	if player_table: player_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if enemy_table: enemy_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
# ============================================================
# Phase 23A: 3D Board Overlay Cleanup
# ============================================================

## _hide_2d_overlays_for_3d
func _hide_2d_overlays_for_3d(report_diagnostics: bool = false) -> void:
	if not USE_TRUE_3D_BOARD_BACKGROUND:
		return

	var logs: Array[String] = []

	# 鈹€鈹€ 1. Avatar HUD 娴瓧 鈫?EngineGauge 涓哄敮涓€鏉冨▉ 鈹€鈹€
	for item in [
		["_boss_hud_hp", _boss_hud_hp],
		["_boss_hud_od", _boss_hud_od],
		["_player_hud_hp", _player_hud_hp],
		["_player_hud_od", _player_hud_od],
		["_player_hud_depth", _player_hud_depth],
	]:
		var lbl: Label = item[1]
		if lbl and is_instance_valid(lbl):
			lbl.visible = false
			logs.append("[HUD_AUTHORITY] path=%s visible=false purpose=hidden_3d_avatar" % item[0])

	# 鈹€鈹€ 2. BossCoreVisual 2D 闈㈡澘 鈫?3D BossCore 妯″瀷涓烘潈濞?鈹€鈹€
	if _boss_core_visual and is_instance_valid(_boss_core_visual):
		_boss_core_visual.visible = false
		logs.append("[HUD_AUTHORITY] path=BossCoreVisual visible=false purpose=hidden_3d_boss_core")

	# 鈹€鈹€ 3. TurnInfoLabel 鈫?浠呬繚鐣?EventAnnounceLabel 鐭殏浜嬩欢 鈹€鈹€
	if turn_info_label and is_instance_valid(turn_info_label):
		turn_info_label.visible = false
		logs.append("[HUD_AUTHORITY] path=TurnInfoLabel visible=false purpose=hidden_3d_center")

	# 鈹€鈹€ 4. 鏃?2D 妲戒綅 SlotPanel + ActionSlot 鑳屾櫙 鈹€鈹€
	for row_path in [
		"BattleTable/BossArea/BossBackRowSlot",
		"BattleTable/BossArea/BossFrontRowSlot",
		"BattleTable/PlayerArea/PlayerFrontRowSlot",
		"BattleTable/PlayerArea/PlayerBackRowSlot",
	]:
		var row := get_node_or_null(NodePath(row_path))
		if row:
			for panel in row.find_children("SlotPanel", "Panel", true, false):
				if panel is CanvasItem:
					(panel as CanvasItem).visible = false
			logs.append("[HUD_AUTHORITY] path=%s/SlotPanel visible=false" % row_path)

	# 鈹€鈹€ 5. ActionSlot 鑳屾櫙闈㈡澘 鈹€鈹€
	for act_path in ["BattleTable/BossArea/BossActionSlot", "BattleTable/PlayerArea/PlayerActionSlot"]:
		var act := get_node_or_null(NodePath(act_path))
		if act:
			var bg := act.get_node_or_null(NodePath("ActionSlotBg"))
			if bg: bg.visible = false
			logs.append("[HUD_AUTHORITY] path=%s/ActionSlotBg visible=false" % act_path)

	# 鈹€鈹€ 6. Chain stepper锛堣矾绾挎杩涘櫒锛夆啋 Route 浠呭啓鍏?ThisTurn/ActionFeed 鈹€鈹€
	if player_table and player_table.has_method("set_chain_stepper_visible"):
		player_table.set_chain_stepper_visible(false)
		logs.append("[HUD_AUTHORITY] path=chain_stepper visible=false purpose=route_in_this_turn_only")
	if enemy_table and enemy_table.has_method("set_chain_stepper_visible"):
		enemy_table.set_chain_stepper_visible(false)

	# 鈹€鈹€ 7. LOCK/ASCEND/ACT 鏍囩 鈫?榛樿闅愯棌锛宧over/menu 鏃舵墠鏄剧ず 鈹€鈹€
	if player_table and player_table.has_method("set_status_tags_visible"):
		player_table.set_status_tags_visible(false)
		logs.append("[HUD_AUTHORITY] path=slot_status_tags visible=false purpose=hover_or_menu_only")
	if enemy_table and enemy_table.has_method("set_status_tags_visible"):
		enemy_table.set_status_tags_visible(false)

	# 鈹€鈹€ 7b. Legacy table energy lines / center divider 鈫?hidden in 3D mode 鈹€鈹€
	var bt := get_node_or_null(NodePath("BattleTable")) as Control
	if bt:
		for energy_name in ["TableEnergyTop", "TableEnergyBot", "CenterEnergyLine", "CenterDivider"]:
			var en := bt.get_node_or_null(NodePath(energy_name))
			if en and en is CanvasItem:
				en.visible = false
				logs.append("[HUD_AUTHORITY] path=BattleTable/%s visible=false purpose=hidden_3d_energy_lines" % energy_name)

	# 鈹€鈹€ 7c. Old 2D FrontRowVisual / BackRowVisual hidden 鈹€鈹€
	if player_table:
		player_table.set_field_cards_visible(false)
	if enemy_table:
		enemy_table.set_field_cards_visible(false)


	# 鈹€鈹€ 7d. Old Deck/GY text labels 鈫?EngineGauge is authority 鈹€鈹€
	for lbl in [_boss_deck_label, _player_deck_label, _boss_gy_last_label, _player_gy_last_label]:
		if lbl and is_instance_valid(lbl):
			lbl.visible = false
			logs.append("[HUD_AUTHORITY] path=%s visible=false purpose=hidden_3d_deck_gy_text" % lbl.name)

	# 鈹€鈹€ 7e. BossDeckSlot / PlayerDeckSlot backgrounds 鈫?transparent
	#     Keep mouse_filter intact for GY hover/click (GraveyardView popup).
	for slot_path in ["BattleTable/BossDeckSlot", "BattleTable/PlayerDeckSlot"]:
		var slot := get_node_or_null(NodePath(slot_path))
		if slot and slot is CanvasItem:
			slot.modulate = Color(1, 1, 1, 0)
			logs.append("[HUD_AUTHORITY] path=%s background=transparent purpose=hidden_3d_deck_gy_bg" % slot_path)

	# 鈹€鈹€ 8. RightTrack / HandArea z_index 鎻愬崌 鈹€鈹€
	var rt := get_node_or_null(NodePath("RightTrack"))
	if rt: rt.z_index = ZI_END_TURN
	var ha := get_node_or_null(NodePath("HandArea"))
	if ha: ha.z_index = ZI_HAND_CARD_BASE

	# 鈹€鈹€ 9. 鏉冨▉ HUD 娓呭崟 鈹€鈹€
	logs.append("[HUD_AUTHORITY] path=EngineGauge(CoreStatusPanel) visible=true purpose=od_depth_hp_authority")
	logs.append("[HUD_AUTHORITY] path=RightTrack visible=true purpose=this_turn_end_turn_action_feed")
	logs.append("[HUD_AUTHORITY] path=HandArea visible=true purpose=hand_cards")
	logs.append("[HUD_AUTHORITY] path=DetailPanelSlot visible=true purpose=card_detail")
	logs.append("[HUD_AUTHORITY] path=ArsenalPanel visible=true purpose=arsenal")
	logs.append("[HUD_AUTHORITY] path=3D_Board+CardCarrier visible=true purpose=board_tokens")
	logs.append("[HUD_AUTHORITY] path=MonsterCommandMenu visible=conditional purpose=monster_commands")
	logs.append("[HUD_AUTHORITY] path=EventAnnounceLabel visible=conditional purpose=major_events_brief")
	logs.append("[HUD_AUTHORITY] path=DropZone visible=conditional purpose=drag_only")

	if not report_diagnostics:
		return
	for line in logs:
		print(line)
	print("[Phase 23A-R] 2D overlays hidden; %d authority entries confirmed" % logs.size())

# ============================================================
# Phase 4B-6E: 鐠嬪啳鐦幍鎾冲祪閺夋尵閻喎鐤勯崸鎰垼
# ============================================================

func _debug_print_board_rects() -> void:
	print("========== BOARD RECTS DEBUG (Phase 4B-6E) ==========")
	for area_name in ["BossArea", "PlayerArea"]:
		var area := get_node_or_null(NodePath("BattleTable/%s" % area_name))
		if area:
			print("  %s global_rect: %s  size=%s" % [area_name, area.get_global_rect(), area.size])

	var rows := {
		"BossBackRowSlot": "BattleTable/BossArea/BossBackRowSlot",
		"BossFrontRowSlot": "BattleTable/BossArea/BossFrontRowSlot",
		"PlayerFrontRowSlot": "BattleTable/PlayerArea/PlayerFrontRowSlot",
		"PlayerBackRowSlot": "BattleTable/PlayerArea/PlayerBackRowSlot",
	}
	for row_name in rows:
		var row := get_node_or_null(NodePath(rows[row_name]))
		if row and row.size.x > 0:
			print("  %s global_rect: %s  size=%s" % [row_name, row.get_global_rect(), row.size])
			for sn in ["Slot1", "Slot3", "Slot5"]:
				var s := row.get_node_or_null(sn)
				if s:
					print("    %s global_rect: %s" % [sn, s.get_global_rect()])
		else:
			print("  %s: NOT FOUND or zero-size" % row_name)

	var divider := get_node_or_null(NodePath("BattleTable/CenterDivider"))
	if divider:
		print("  CenterDivider global_rect: %s" % divider.get_global_rect())
	print("========================================================")
## 閸︺劍瀵氱€规艾灏崺鐔峰敶閸掓稑缂撶悰灞藉З鐏炴洜銇氬Σ鏂ょ礄SPELL/INSTANT 閻厽娈忛崑婊呮殌閿?
func _create_action_slot(area_path: String, slot_name: String) -> Control:
	var area := get_node_or_null(NodePath(area_path))
	if not area:
		return null

	var slot := Control.new()
	slot.name = slot_name
	slot.custom_minimum_size = Vector2(140, 90)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.18, 0.55)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.6, 0.5, 0.9, 0.6)
	style.set_corner_radius_all(6)

	var panel := Panel.new()
	panel.name = "ActionSlotBg"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	slot.add_child(panel)

	# 鐏炲懍鑵戦弨鍓х枂閸︺劌灏崺鐔惰厬闂?
	slot.set_anchors_preset(Control.PRESET_CENTER)
	area.add_child(slot)

	return slot
## 缂佹瑥灏崺鐔奉啇閸ｃ劍鍧婇崝鐘插磹闁繑妲戦懗灞炬珯 Panel閿涘牐鐨熺拠鏇炲讲鐟欎焦鈧嶇礆
func _apply_area_background(area_path: String, bg_color: Color, bg_name: String) -> void:
	var area := get_node_or_null(NodePath(area_path))
	if not area:
		return
	# 缁夊娅庨弮褑鍎楅弲顖ょ礄婵″倹鐏夌€涙ê婀敍?
	var old := area.get_node_or_null(NodePath(bg_name))
	if old and is_instance_valid(old):
		old.queue_free()
	var panel := Panel.new()
	panel.name = bg_name
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0; panel.offset_top = 0
	panel.offset_right = 0; panel.offset_bottom = 0
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(panel)
	area.move_child(panel, 0)  # 閺€鎯ф躬閺堚偓鎼存洖鐪?
## 缂?RowSlot 鐎圭懓娅掑ǎ璇插缂佸棜绔熷鍡礄鐠嬪啳鐦崣顖濐潌閹嶇礆
func _apply_row_slot_border(slot_path: String, border_color: Color) -> void:
	var slot := get_node_or_null(NodePath(slot_path))
	if not slot:
		return
	var old := slot.get_node_or_null(NodePath("_debug_border"))
	if old and is_instance_valid(old):
		old.queue_free()
	var panel := Panel.new()
	panel.name = "_debug_border"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0; panel.offset_top = 0
	panel.offset_right = 0; panel.offset_bottom = 0
	panel.z_index = ZI_DEBUG_BORDER  # 2
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(panel)
	slot.move_child(panel, 0)

## Phase 4B-6D: INSTANT/SPELL 閸椔ゎ攽閸斻劌鐫嶇粈鐑樞憴鍡氼潕濞翠胶鈻?## 閸楋紕澧濋崗鍫ヮ棧閸?ActionSlot閳帞鐓弳鍌氫粻閻ｆ瑢鍟嬬粵澶婄窡缂佹挾鐣婚埆鎺撶瑤閸戝搫鍩屾晶鎾虫勾
## Phase 8A: SPELL/FINISHER 鐞涘苯濮╃仦鏇犮仛濡茶姤绁︾粙?
## Phase 26B-T6: Public API for 5-phase spell activation.
## Phase 27C-R1: End Turn blocked callback from SpellActivationPresenter.
func _on_spell_end_turn_blocked(blocked: bool) -> void:
	_spell_end_turn_blocked = blocked


## Phase 27C-R1: Two-phase spell activation — begin phase.
func _begin_spell_presentation(card_ui: CardUI, card: CardData, is_finisher: bool = false, presentation_facts: Dictionary = {}) -> Dictionary:
	if not spell_activation_presenter or not is_instance_valid(spell_activation_presenter):
		return {"ok": false, "reason": "no_presenter"}
	return await spell_activation_presenter.begin_spell_activation(card_ui, card, is_finisher, presentation_facts)


## Phase 27C-R1: Two-phase spell activation — finish phase.
func _finish_spell_presentation(handle: Dictionary, play_result: Dictionary) -> void:
	if not spell_activation_presenter or not is_instance_valid(spell_activation_presenter):
		return
	await spell_activation_presenter.finish_spell_activation(handle, play_result)


func _build_spell_presentation_facts(card_ui: CardUI, card: CardData, is_finisher: bool = false) -> Dictionary:
	var target_position := _get_boss_screen_pos()
	var source_position := Vector2.ZERO
	if card_ui != null and is_instance_valid(card_ui):
		source_position = card_ui.global_position + card_ui.size * 0.5
	return {
		"transaction_id": StringName("spell:%s:%d" % [str(card.card_id), card.get_instance_id()]) if card != null else &"spell:unknown",
		"card_id": StringName(str(card.card_id)) if card != null else &"",
		"card_name": str(card.card_name) if card != null else "",
		"piece_type": StringName(str(card.piece_type)) if card != null and "piece_type" in card and not str(card.piece_type).is_empty() else &"pawn",
		"source_position": source_position,
		"target_position": target_position,
		"player_position": _get_player_core_presentation_pos(),
		"target_kind": &"boss_core",
		"is_finisher": is_finisher,
	}


func _capture_phase_lock_presentation_snapshot() -> Dictionary:
	if context == null:
		return {}
	return {
		"locked_count": int(context.phases_locked_this_turn),
		"phase1_triggered": bool(context.boss_phase1_triggered),
		"phase2_triggered": bool(context.boss_phase2_triggered),
		"phase2_lock": context.get_boss_phase_lock(2) if context.has_method("get_boss_phase_lock") else {},
		"phase3_lock": context.get_boss_phase_lock(3) if context.has_method("get_boss_phase_lock") else {},
	}


func _committed_phase_lock_shield_gain(before: Dictionary, after: Dictionary) -> int:
	if int(after.get("locked_count", 0)) <= int(before.get("locked_count", 0)):
		return 0
	if not bool(before.get("phase2_triggered", false)) and bool(after.get("phase2_triggered", false)):
		return maxi(0, int((before.get("phase3_lock", {}) as Dictionary).get("shield_gain", 0)))
	if not bool(before.get("phase1_triggered", false)) and bool(after.get("phase1_triggered", false)):
		return maxi(0, int((before.get("phase2_lock", {}) as Dictionary).get("shield_gain", 0)))
	return 0


func _get_player_core_presentation_pos() -> Vector2:
	var core_panel := get_node_or_null(NodePath("BattleTable/CoreStatusPanel")) as Control
	if core_panel != null and is_instance_valid(core_panel):
		var rect := core_panel.get_global_rect()
		if rect.size != Vector2.ZERO:
			return rect.get_center()
	var viewport_size := get_viewport_rect().size
	return Vector2(viewport_size.x * 0.78, viewport_size.y * 0.78)


## _play_instant_card_visual (Phase 27C-R1: legacy wrapper)
func _play_instant_card_visual(card_ui: CardUI, card: CardData, is_finisher: bool = false) -> void:
	## Phase 27C-R1: This wrapper should NOT call the old present_spell_activation.
	## Callers must use _begin_spell_presentation / play_card / _finish_spell_presentation.
	if spell_activation_presenter and is_instance_valid(spell_activation_presenter):
		print("[SPELL_WARN] _play_instant_card_visual bypassed — use two-phase API")
		return
# ============================================================
# Phase 4B-6D: CardUI 瑜版帒鐫樼€孤ゎ吀閿涘潐ebug閿?
# ============================================================

## 濡偓閺屻儲澧嶉張?CardUI 閺勵垰鎯侀崷銊︻劀绾喚娈戠€瑰じ瀵屾稉瀣剁礉閸欐垹骞囧〒鍝ヮ瀲閸掓瑤鎱ㄦ径?

# ============================================================
# Phase 8B: Boss intent helpers
# ============================================================

func _boss_pulse_color(danger: String) -> Color:
	match danger:
		"HIGH", "OVERDRIVE": return Color(1.2, 0.3, 0.2, 1)
		"MID":                return Color(1.1, 0.55, 0.15, 1)
		_:                    return Color(0.4, 0.6, 1.1, 1)
func _kill_boss_intent_tween() -> void:
	if _boss_intent_tween and _boss_intent_tween.is_valid():
		_boss_intent_tween.kill()
	_boss_intent_tween = null
func _hide_boss_intent_after_execute() -> void:
	_kill_boss_intent_tween()
	if boss_intent_card and is_instance_valid(boss_intent_card):
		var tf := create_tween()
		tf.tween_property(boss_intent_card, "modulate:a", 0.0, 0.2)
		tf.tween_callback(func():
			if boss_intent_card and is_instance_valid(boss_intent_card):
				boss_intent_card.visible = false
		)

# ============================================================
# Phase 10G: BossCoreVisual 2D 闂堛垺婢?# ============================================================

func _create_boss_core_visual() -> void:
	# Boss 閸栧搫鐓欏鏇犳暏
	# Phase 24B-R2-R: 3D mode uses BossStatusHUD, skip legacy 2D overlay
	if USE_TRUE_3D_BOARD_BACKGROUND:
		return
	var boss_area := get_node_or_null(NodePath("BattleTable/BossArea")) as Control
	if not boss_area:
		return

	# 闂堛垺婢樼€圭懓娅?閳?鐠愭潙婀?BossArea 娑撳﹥鏌熸稉顓炪亷
	_boss_core_visual = Panel.new()
	_boss_core_visual.name = "BossCoreVisual"
	_boss_core_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 鐎规矮缍呴敍娆眔ssArea 妞ゅ爼鍎寸仦鍛厬閸嬪繋绗?	_boss_core_visual.position = Vector2(boss_area.size.x * 0.5 - 90, boss_area.position.y - 12)
	_boss_core_visual.size = Vector2(180, 72)  # Phase 12E: 缁嬪秴銇?	_boss_core_visual.z_index = 45  # 妤傛ü绨崷鍝勫幢閿涘奔缍嗘禍搴濊厬婢额喖銇囩€?

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.02, 0.02, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.7, 0.2, 0.1, 0.9)
	style.set_corner_radius_all(8)
	_boss_core_visual.add_theme_stylebox_override("panel", style)
	# Phase 18I-1R: add cloudgate_v2 boss_core_device texture behind panel
	var core_art_path: String = _resolve_table_art_path("boss_core_device.png")
	if core_art_path != "":
		var core_tex: Texture2D = ResourceLoader.load(core_art_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if core_tex:
			var core_bg := TextureRect.new()
			core_bg.name = "BossCoreDeviceArt"
			core_bg.texture = core_tex
			core_bg.modulate = Color(1, 1, 1, 0.40)
			core_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			core_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			core_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
			core_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			core_bg.z_index = -1
			_boss_core_visual.add_child(core_bg)
			_boss_core_visual.move_child(core_bg, 0)

	# Phase 12E: 閼充粙鍣洪悳顖氱湴 閳?閸楀﹪鈧繑妲戦悳顖氳埌鏉堣顢嬮弳妤冦仛
	_boss_core_ring = ColorRect.new()
	_boss_core_ring.name = "CoreRing"
	_boss_core_ring.color = Color(0.85, 0.3, 0.08, 0.18)
	_boss_core_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_core_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_width_left = 1
	ring_style.border_width_right = 1
	ring_style.border_width_top = 1
	ring_style.border_width_bottom = 1
	ring_style.border_color = Color(0.9, 0.35, 0.1, 0.6)
	ring_style.set_corner_radius_all(30)
	_boss_core_ring.add_theme_stylebox_override("panel", ring_style)
	_boss_core_visual.add_child(_boss_core_ring)

	# Phase 12E: 娑擃厼绺鹃弽绋跨妇閻?閳?鐏忓繐鐎锋禍顔垮閺傜懓娼?	_boss_core_eye = ColorRect.new()
	_boss_core_eye.name = "CoreEye"
	_boss_core_eye.color = Color(1, 0.4, 0.1, 0.6)
	_boss_core_eye.size = Vector2(10, 6)
	_boss_core_eye.position = Vector2(85, 20)
	_boss_core_eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_core_visual.add_child(_boss_core_eye)

	# 閸忓妾挎惔鏇″
	_boss_core_glow = ColorRect.new()
	_boss_core_glow.name = "CoreGlow"
	_boss_core_glow.color = Color(0.9, 0.25, 0.05, 0.15)
	_boss_core_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_core_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_core_visual.add_child(_boss_core_glow)

	# Boss 閸氬秶袨
	_boss_core_name_label = Label.new()
	_boss_core_name_label.name = "CoreName"
	_boss_core_name_label.text = "FORGE GUARD"
	_boss_core_name_label.add_theme_font_size_override("font_size", 11)
	_boss_core_name_label.add_theme_color_override("font_color", Color(1, 0.55, 0.2, 1))
	_boss_core_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_core_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_core_name_label.offset_top = 4
	_boss_core_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_core_visual.add_child(_boss_core_name_label)

	var info_row := HBoxContainer.new()
	info_row.name = "CoreInfoRow"
	info_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info_row.offset_bottom = -4
	info_row.offset_left = 8
	info_row.offset_right = -8
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	info_row.add_theme_constant_override("separation", 16)
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_core_visual.add_child(info_row)

	_boss_core_hp_label = Label.new()
	_boss_core_hp_label.name = "CoreHP"
	_boss_core_hp_label.text = "HP: ??/??"
	_boss_core_hp_label.add_theme_font_size_override("font_size", 10)
	_boss_core_hp_label.add_theme_color_override("font_color", Color(1, 0.4, 0.35, 1))
	_boss_core_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(_boss_core_hp_label)

	_boss_core_od_label = Label.new()
	_boss_core_od_label.name = "CoreOD"
	_boss_core_od_label.text = "OD: ?"
	_boss_core_od_label.add_theme_font_size_override("font_size", 10)
	_boss_core_od_label.add_theme_color_override("font_color", Color(1, 0.55, 0.1, 1))
	_boss_core_od_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(_boss_core_od_label)

	var battle_table := get_node_or_null(NodePath("BattleTable")) as Control
	if battle_table:
		battle_table.add_child(_boss_core_visual)

	# 閸掓繂顫愰弳妤佲偓渚婄礉缁涘绶熷鈧崷?Core Online
	_boss_core_visual.modulate.a = 0.25
	print("[Phase 10G] BossCoreVisual created")
func _update_boss_core_visual() -> void:
	if not _boss_core_visual or not is_instance_valid(_boss_core_visual):
		return
	if not context or not context.enemy:
		return

	if _boss_core_hp_label and is_instance_valid(_boss_core_hp_label):
		var hp_val := 0
		var max_hp := 0
		if "hp" in context.enemy: hp_val = context.enemy.hp
		if "max_hp" in context.enemy: max_hp = context.enemy.max_hp
		_boss_core_hp_label.text = "HP: %d/%d" % [hp_val, max_hp]
		if max_hp > 0 and hp_val < max_hp * 0.3:
			_boss_core_hp_label.add_theme_color_override("font_color", Color(1, 0.2, 0.1, 1))

	if _boss_core_od_label and is_instance_valid(_boss_core_od_label):
		var od_val := 0
		if "od" in context.enemy: od_val = context.enemy.od
		_boss_core_od_label.text = "OD: %d" % od_val
		if od_val >= 8:
			_boss_core_od_label.add_theme_color_override("font_color", Color(1, 0.15, 0.05, 1))
# [Fixed func]
func _play_boss_core_intro() -> void:
	if _boss_intro_played:
		return
	# Phase 11C: BossCore 妫ｆ牗顐奸幓鎰仛
	pass  # fixed garbled code
	_boss_intro_played = true
	if not _boss_core_visual or not is_instance_valid(_boss_core_visual):
		return

	# ActionFeed
	if action_feed:
		action_feed.push_message("Boss Core Online - FORGE GUARD", Color(1, 0.45, 0.1, 1), "", 2.5)
	var am = _am(); if am: am.play_boss_core_online()

	# BossCoreVisual 娴犲孩娈崚棰佸瘨 + scale intro
	_safe_kill_boss_core_pulse()
	_hide_building_replace_panel()
	_boss_core_visual.scale = Vector2(0.88, 0.88)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_boss_core_visual, "modulate:a", 1.0, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_boss_core_visual, "scale", Vector2(1.0, 1.0), 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# [Fixed]
	if _boss_core_eye and is_instance_valid(_boss_core_eye):
		_boss_core_eye.color.a = 0.15
		var te: Tween = create_tween()
		te.tween_property(_boss_core_eye, "color:a", 0.85, 0.15)
		te.tween_property(_boss_core_eye, "color:a", 0.6, 0.35)

	# [Fixed]
	if _boss_core_ring and is_instance_valid(_boss_core_ring):
		_boss_core_ring.scale = Vector2(0.8, 0.8)
		_boss_core_ring.modulate.a = 0.3
		var tr: Tween = create_tween()
		tr.set_parallel(true)
		tr.tween_property(_boss_core_ring, "scale", Vector2(1.0, 1.0), 0.35)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tr.tween_property(_boss_core_ring, "modulate:a", 1.0, 0.3)

	# 閸忓妾块惌顓濈妇 pulse
	if _boss_core_glow and is_instance_valid(_boss_core_glow):
		var t2: Tween = create_tween()
		t2.tween_property(_boss_core_glow, "color:a", 0.45, 0.2)
		t2.tween_property(_boss_core_glow, "color:a", 0.15, 0.5)

	var battle_table := get_node_or_null(NodePath("BattleTable")) as Control
	if battle_table and battle_vfx:
		battle_vfx.play_screen_shake(battle_table, 2.0, 0.15)

	# Boss 濡叉垝缍呴惌顓濈妇娴滎喛鎹ｉ敍鍫濐槻閻?battle_vfx閿?
	if player_table and player_table.has_method("play_slot_unlock_pulse"):
		pass  # 閻溾晛顔嶅Σ鎴掔秴娑撳秹娓剁憰?
	if enemy_table:
		# Boss 閸撳秴鎮楅崷鐑樞担宥夆偓鎰嚋閼村鍟?		_boss_slot_pulse_all(0.8)

	# 娣囨繃瀵旈崨鐓庢儧 pulse
		# Phase 10G: Tween-delayed breath pulse (non-blocking)
		var breath_tween: Tween = create_tween()
		breath_tween.tween_interval(0.8)
		breath_tween.tween_callback(func():
			if _boss_core_visual and is_instance_valid(_boss_core_visual):
				_safe_kill_boss_core_pulse()
				_boss_core_pulse_tween = create_tween()
				_boss_core_pulse_tween.set_loops()
				_boss_core_pulse_tween.tween_property(_boss_core_visual, "modulate:a", 0.8, 2.5).set_trans(Tween.TRANS_SINE)
				_boss_core_pulse_tween.tween_property(_boss_core_visual, "modulate:a", 1.0, 2.5).set_trans(Tween.TRANS_SINE)
		)

	print("[Phase 10G] Boss Core Online")
# Boss 濡叉垝缍呴幍褰掑櫤閼村鍟块敍鍫㈡暏娴滃骸绱戦崷?鐞涘苯濮╅敍?
func _boss_slot_pulse_all(duration_scale: float = 1.0) -> void:
	if not enemy_table or not battle_vfx:
		return
	# 闁俺绻?player_table 閻ㄥ嫭蝎娴ｅ秳缍嬬化鏄徯曢崣?Boss 娓氀嗗墻閸?
	# Boss 濡叉垝缍呴崷?_external_front/back_slots 娑?
	for i in range(5):
		if enemy_table.has_method("play_slot_unlock_pulse"):
			enemy_table.play_slot_unlock_pulse(i)
# Phase 10G: Boss 鐞涘苯濮╅崣宥夘洯
func _play_boss_action_vfx(action_type: String) -> void:
	if not _boss_core_visual or not is_instance_valid(_boss_core_visual):
		return
	if not _boss_core_glow or not is_instance_valid(_boss_core_glow):
		return

	_safe_kill_boss_core_pulse()  # 娑撳瓨妞傞幍鎾存焽閸涚厧鎯?pulse

	var color: Color
	var strength: float
	match action_type:
		"intent":
			color = Color(0.8, 0.5, 0.1, 0.3); strength = 1.0
		"front":
			color = Color(1, 0.35, 0.08, 0.35); strength = 1.2
		"back":
			color = Color(0.7, 0.2, 0.5, 0.25); strength = 1.0
		"instant":
			color = Color(1, 0.45, 0.05, 0.45); strength = 1.5
		"overdrive":
			color = Color(1, 0.1, 0.02, 0.5); strength = 2.0
		_:
			color = Color(1, 0.4, 0.1, 0.25); strength = 1.0

	# Glow flash
	var tween: Tween = create_tween()
	tween.tween_property(_boss_core_glow, "color:a", color.a * strength, 0.08)
	tween.tween_property(_boss_core_glow, "color:a", 0.15, 0.3)

	# Phase 12E: CoreEye 閹稿琚崹瀣／閻?
	if _boss_core_eye and is_instance_valid(_boss_core_eye):
		var eye_color := color
		eye_color.a = strength * 0.7
		var te: Tween = create_tween()
		te.tween_property(_boss_core_eye, "modulate", eye_color, 0.08)
		te.tween_property(_boss_core_eye, "modulate", Color(1, 1, 1, 1), 0.2)

	# Phase 12E: CoreRing 閹稿琚崹瀣墻閸?
	if _boss_core_ring and is_instance_valid(_boss_core_ring):
		var ring_scale: float = 1.04
		if action_type == "overdrive":
			ring_scale = 1.08
		var tr: Tween = create_tween()
		tr.tween_property(_boss_core_ring, "scale", Vector2(ring_scale, ring_scale), 0.08)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tr.tween_property(_boss_core_ring, "scale", Vector2(1.0, 1.0), 0.2)

	# BossCore brief scale (per-type intensity)
	var scale_amt: float = 1.03
	if action_type == "overdrive": scale_amt = 1.06
	elif action_type == "instant": scale_amt = 1.04
	var orig_scale := _boss_core_visual.scale
	var t2: Tween = create_tween()
	t2.tween_property(_boss_core_visual, "scale", Vector2(scale_amt, scale_amt), 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(_boss_core_visual, "scale", orig_scale, 0.2)

	# Phase 12E: overdrive 閸旂姴鐫嗛獮鏇㈡缚閸?
	if action_type == "overdrive":
		var bt := get_node_or_null(NodePath("BattleTable")) as Control
		if bt and battle_vfx:
			battle_vfx.play_screen_shake(bt, 4.0, 0.18)
		# [Fixed]
		if _center_energy_line and is_instance_valid(_center_energy_line):
			var _clt: Tween = create_tween()
			_clt.tween_property(_center_energy_line, "color", Color(1, 0.15, 0.25, 0.5), 0.08)
			_clt.tween_property(_center_energy_line, "color", Color(0.2, 0.4, 0.8, 0.15), 0.4)

	# 閸掋倖鏌?Boss 閻樿埖鈧焦浠径宥呮嚑閸?
	var _bs: String = ""
	if "od" in context.enemy:
		var _od := context.enemy.od
		if _od >= 8: _bs = "overdrive"
		elif _od >= 4: _bs = "heated"
	await get_tree().create_timer(0.35).timeout
	_restore_boss_core_breath(_bs)
func _restore_boss_core_breath(boss_state: String = "") -> void:
	if not _boss_core_visual or not is_instance_valid(_boss_core_visual):
		return
	if _boss_core_pulse_tween and _boss_core_pulse_tween.is_valid():
		return  # 閸涚厧鎯?pulse 娴犲秴婀?
	var lo: float = 0.78
	var hi: float = 1.0
	var period: float = 2.5
	match boss_state:
		"heated":
			lo = 0.7; hi = 1.05; period = 1.6
		"overdrive":
			lo = 0.55; hi = 1.1; period = 0.9
		_:  # calm / default
			lo = 0.78; hi = 1.0; period = 2.5

	_boss_core_pulse_tween = create_tween()
	_boss_core_pulse_tween.set_loops()
	_boss_core_pulse_tween.tween_property(_boss_core_visual, "modulate:a", lo, period * 0.5)\
		.set_trans(Tween.TRANS_SINE)
	_boss_core_pulse_tween.tween_property(_boss_core_visual, "modulate:a", hi, period * 0.5)\
		.set_trans(Tween.TRANS_SINE)
# ============================================================
# Phase 12F: 濡楀矂娼伴懗鑺ョ爱缁?閳?鐠愭挳妾?BattleTable 閻ㄥ嫭婧€濮婄増鍔呯痪鎸庢蒋
# ============================================================

func _create_table_energy_lines() -> void:
	var bt := get_node_or_null(NodePath("BattleTable")) as Control
	if not bt:
		return
	# 娑撳﹪鍎?Boss 娓氀嗗厴濠ф劗鍤庨敍鍫熸缁俱垼鐨熼敍?
	var top_line := ColorRect.new()
	top_line.name = "TableEnergyTop"
	top_line.color = Color(0.6, 0.15, 0.1, 0.3)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.size = Vector2(bt.size.x - 20, 1)
	top_line.position = Vector2(10, bt.size.y * 0.48 - 1)
	bt.add_child(top_line)

	# 娑撳鍎?Player 娓氀嗗厴濠ф劗鍤庨敍鍫熺箒閽冩繆鐨熼敍?
	var bot_line := ColorRect.new()
	bot_line.name = "TableEnergyBot"
	bot_line.color = Color(0.1, 0.35, 0.7, 0.25)
	bot_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_line.size = Vector2(bt.size.x - 20, 1)
	bot_line.position = Vector2(10, bt.size.y * 0.52 + 1)
	bt.add_child(bot_line)

	# 娑擃厼銇庨崚鍡涙閼宠姤绨痪鍖＄礄鐠虹喖娈?OD/Boss 閻樿埖鈧礁褰夐懝璇х礆
	_center_energy_line = ColorRect.new()
	_center_energy_line.name = "CenterEnergyLine"
	_center_energy_line.color = Color(0.2, 0.4, 0.8, 0.15)
	_center_energy_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_energy_line.size = Vector2(bt.size.x - 40, 2)
	_center_energy_line.position = Vector2(20, bt.size.y * 0.5 - 1)
	bt.add_child(_center_energy_line)

	print("[Phase 12F] Table energy lines created")
# Phase 12F: 娑擃厼銇庨懗鑺ョ爱缁惧灝绱╅悽顭掔礄娓?overdrive 閸欐澹婇敍?
var _center_energy_line: ColorRect = null

func _safe_kill_boss_core_pulse() -> void:
	if _boss_core_pulse_tween and _boss_core_pulse_tween.is_valid():
		_boss_core_pulse_tween.kill()
	_boss_core_pulse_tween = null
# ============================================================
# Phase 10H: 瀵よ櫣鐡氶弴鎸庡床 UI
# ============================================================

var _building_replace_panel: Panel = null
var _building_replace_new_card: CardData = null
var _building_replace_card_ui: CardUI = null
# Phase 27I-R1: P08 等棋子建筑替换推迟——记录待替换旧建筑，由棋子事务在验证完成后提交
var _pending_piece_replacement_old_card: CardData = null

# Phase 23B-R2: Direct 3D replacement selection state
const BUILD_REPLACE_RIGHT_CLICK_CANCEL_THRESHOLD := 4.0
var _building_replace_select_active := false
var _building_replace_right_press_pos := Vector2.ZERO
var _building_replace_right_dragged := false

func _show_building_replace_panel(new_card: CardData, card_ui: CardUI) -> void:
	if new_card == null or not battle:
		return
	# Phase 11C: 瀵よ櫣鐡氶弴鎸庡床妫ｆ牗顐奸幓鎰仛
	pass  # fixed garbled code
	var buildings := battle.get_replaceable_buildings(context.player)
	if buildings.is_empty():
		_show_unplayable_reason(new_card)
		return

	_building_replace_new_card = new_card
	_building_replace_card_ui = card_ui

	# 濞撳懘娅庡鍙夋箒闂堛垺婢?	_hide_building_replace_panel()
	var mask := ColorRect.new()
	mask.name = "ReplaceMask"
	mask.color = Color(0, 0, 0, 0.3)
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	mask.gui_input.connect(_on_replace_mask_input)
	mask.z_index = 249
	add_child(mask)


	# 閸掓稑缂撻棃銏℃緲
	_building_replace_panel = Panel.new()
	_building_replace_panel.name = "BuildingReplacePanel"
	_building_replace_panel.z_index = 1  # Phase 23B-R2: relative to mask
	_building_replace_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.02, 0.95)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.9, 0.55, 0.22, 1)
	style.set_corner_radius_all(8)
	_building_replace_panel.add_theme_stylebox_override("panel", style)

	# 闂堛垺婢樻径褍鐨崪灞肩秴缂冾噯绱伴悧灞绢攽娑擃厼銇庨崑蹇庣瑐
	var viewport_size := get_viewport_rect().size
	_building_replace_panel.position = Vector2(viewport_size.x * 0.5 - 140, viewport_size.y * 0.3)
	_building_replace_panel.size = Vector2(280, 20 + 42 * buildings.size() + 54)
	mask.add_child(_building_replace_panel)

	var title := Label.new()
	title.name = "ReplaceTitle"
	title.text = "建筑位已满 - 选择要替换的建筑"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 6
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_building_replace_panel.add_child(title)

	# 瀵よ櫣鐡氶幐澶愭尦
	var y_offset := 24.0
	for bld in buildings:
		if bld == null or not is_instance_valid(bld):
			continue
		var bld_name: String = bld.get_display_name() if bld.has_method("get_display_name") else str(bld.card_name)
		var state_info := ""
		if battle.has_method("get_building_state"):
			var st: Dictionary = battle.get_building_state(bld)
			if not st.is_empty():
				state_info = " [Charge %d/%d]" % [st.get("charge", 0), st.get("charge_max", 1)]
		var btn := Button.new()
		btn.name = "ReplaceBtn_%s" % bld.card_name
		btn.text = "%s%s" % [bld_name, state_info]
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_color_override("font_color", Color(1, 0.65, 0.2, 1))
		btn.flat = false
		btn.position = Vector2(12, y_offset)
		btn.size = Vector2(256, 34)
		btn.pressed.connect(_on_building_replace_selected.bind(bld))
		_building_replace_panel.add_child(btn)
		y_offset += 42

	# 閸欐牗绉烽幐澶愭尦
	var cancel_btn := Button.new()
	cancel_btn.name = "ReplaceCancelBtn"
	cancel_btn.text = "取消"
	cancel_btn.add_theme_font_size_override("font_size", 10)
	cancel_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1))
	cancel_btn.position = Vector2(12, y_offset + 4)
	cancel_btn.size = Vector2(256, 30)
	cancel_btn.pressed.connect(_on_building_replace_cancel)
	_building_replace_panel.add_child(cancel_btn)

	# 閸楀﹪鈧繑妲戦懗灞炬珯闁喚鍍甸敍鍫㈠仯閸戣崵鈹栭惂钘夘槱閸欐牗绉烽敍?
	pass  # fixed garbled code
func _on_building_replace_selected(old_card: CardData) -> void:
	_resolve_building_replacement(old_card)
func _on_building_replace_cancel() -> void:
	_hide_building_replace_panel()
	_action_feed_msg("Swap Canceled - Hand unchanged", TC.TEXT_DIM)
	_clear_replace_state()
func _on_replace_mask_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_building_replace_cancel()
		get_viewport().set_input_as_handled()
func _hide_building_replace_panel() -> void:
	# Phase 11C: cleanup tutorial hint
	_hide_tutorial_hint()
	# Phase 23B-R2: mask owns panel 鈫?freeing mask frees panel
	var mask := get_node_or_null(NodePath("ReplaceMask"))
	_building_replace_panel = null
	if mask and is_instance_valid(mask):
		mask.queue_free()
func _clear_replace_state() -> void:
	_building_replace_new_card = null
	_building_replace_card_ui = null

	# ============================================================
	# Phase 23B-R2: Direct 3D building replacement selection
	# ============================================================

func _begin_building_replace_selection(new_card: CardData, card_ui: CardUI) -> void:
	_cancel_building_replace_selection("restart", false)
	if new_card == null or not battle or not battle.needs_building_replacement(new_card):
		var status: Dictionary = battle.get_card_play_status(new_card)
		print("[BUILD_REPLACE_SELECT] blocked reason=%s" % status.get("reason", "invalid"))
		_show_unplayable_reason(new_card)
		return
	var buildings: Array = battle.get_replaceable_buildings(context.player)
	if buildings.is_empty():
		_show_unplayable_reason(new_card)
		return
	_building_replace_new_card = new_card
	_building_replace_card_ui = card_ui
	_building_replace_select_active = true
	_set_building_replace_highlights(true)
	pass  # fixed
	pass  # fixed

func _set_building_replace_highlights(active: bool) -> void:
	for token in _card_token_nodes.values():
		if token == null or not is_instance_valid(token):
			continue
		var card: CardData = token.get_meta("card", null) as CardData
		var eligible: bool = active and token.get_meta("side", "") == "player" and token.get_meta("zone", "") == "back" and card != null and card.is_building_card()
		var carrier: Node = token.get_node_or_null("CardCarrier")
		if carrier and carrier.has_method("set_replacement_target_highlight"):
			carrier.set_replacement_target_highlight(eligible)

func _count_highlighted_replace_targets() -> int:
	var count := 0
	for token in _card_token_nodes.values():
		if token == null or not is_instance_valid(token):
			continue
		var carrier: Node = token.get_node_or_null("CardCarrier")
		if carrier and carrier.has_method("is_replacement_target_highlighted") and carrier.is_replacement_target_highlighted():
			count += 1
	return count

func _cancel_building_replace_selection(reason: String, announce: bool = true) -> void:
	var was_active := _building_replace_select_active
	_set_building_replace_highlights(false)
	_building_replace_select_active = false
	_building_replace_new_card = null
	_building_replace_card_ui = null
	_building_replace_right_dragged = false
	if was_active:
		print("[BUILD_REPLACE_SELECT] cancel reason=%s" % reason)
		if announce:
			pass  # fixed



func _handle_building_replace_token_click(card: CardData, side: String, zone: String) -> void:
	if not _building_replace_select_active or _building_replace_new_card == null:
		return
	if side != "player" or zone != "back" or card == null or not card.is_building_card():
		pass  # fixed
		return
	pass  # fixed
	_resolve_building_replacement(card)

func _resolve_building_replacement(old_card: CardData) -> void:
	if _building_replace_new_card == null or not battle:
		_hide_building_replace_panel()
		_cancel_building_replace_selection("invalid", false)
		return
	var new_card: CardData = _building_replace_new_card
	var new_card_ui: CardUI = _building_replace_card_ui
	# Phase 27I-R1: P08 等棋子建筑——替换推迟到棋子事务内提交（不先删旧建筑）。
	if new_card.piece_enabled and new_card.card_family == "building":
		_pending_piece_replacement_old_card = old_card
		_hide_building_replace_panel()
		_cancel_building_replace_selection("defer_to_piece", false)
		_begin_piece_selection(new_card_ui, new_card, &"play")
		return
	var result: Dictionary = battle.replace_building_and_play(new_card, old_card)
	_hide_building_replace_panel()
	if result.get("ok", false):
		if _playtest:
			_playtest.record_event("building_replaced", {
				"new": new_card.card_name,
				"old": old_card.card_name,
				"same_series": result.get("same_series", false),
			})
		var am_replace = _am()
		if am_replace:
			am_replace.play_building_replace()
		_stat_total_cards += 1
		var color := Color(0.9, 0.55, 0.22, 1)
		if result.get("same_series", false):
			color = Color(0.4, 0.8, 1.0, 1)
		_action_feed_msg(result.get("message", "Building Replace"), color)
		_add_to_this_turn("Replace: %s" % new_card.get_display_name(), color)
		var bonus: String = result.get("bonus", "")
		pass  # fixed
		if bonus != "" and bonus != "??":
			_action_feed_msg(bonus, Color(0.4, 0.8, 1.0, 1))
		_play_building_replace_vfx(old_card, result.get("same_series", false))
		_refresh_tables()
		check_battle_end()
	else:
		_action_feed_msg("Swap Failed: %s" % result.get("reason", "Unknown error"), TC.WARNING)
	_cancel_building_replace_selection("success" if result.get("ok", false) else "failed", false)

func _action_feed_msg(msg: String, color: Color) -> void:
	if action_feed:
		action_feed.push_message(msg, color, "", 2.0)
# [Fixed func]
func _play_building_replace_vfx(old_card: CardData, is_same_series: bool) -> void:
	# 閺冄冪紦缁涙垶蝎娴ｅ秵娈稉瀣З閻紮绱欓柅姘崇箖 player_table 鐎电粯澹橀獮鑸垫尡閺€?destroy閿?
	if player_table and card_vfx:
		var old_slot := player_table.find_back_slot_for_card(old_card)
		if old_slot and is_instance_valid(old_slot):
			card_vfx.play_card_destroy(old_slot)

	# 閺傛澘缂撶粵鎴ｆ儰娴ｅ稄绱欓崷?_refresh_tables 閳?_populate_slot 娑擃叀鍤滈崝銊ㄧ殶閻?landing VFX閿?
	# 閸氬矁閰辨總鏍уС妫版繂顦?pulse
	if is_same_series and battle_vfx:
		var core_panel := get_node_or_null(NodePath("BattleTable/CoreStatusPanel")) as Control
		if core_panel:
			battle_vfx.play_engine_charge_tick(core_panel, context.od_mode.get_engine_layer() if context and context.od_mode else 1)
func _audit_card_ui_ownership() -> void:
	var all_card_uis: Array[Node] = []
	_find_all_card_ui(self, all_card_uis)

	var orphan_count := 0
	for node in all_card_uis:
		if not is_instance_valid(node):
			continue
		var card_ui := node as CardUI
		if not card_ui:
			continue
		var parent := card_ui.get_parent()
		if not parent:
			orphan_count += 1
			push_warning("[AUDIT] Orphaned CardUI: %s (no parent)" % card_ui.name)
			card_ui.queue_free()
			continue

		var parent_name := parent.name
		var grandparent_name := ""
		if parent.get_parent():
			grandparent_name = parent.get_parent().name

		# 閸氬牊纭剁€瑰じ瀵岄崥宥呭礋
		var is_hand_area := (parent_name == "BattleHandLayout" or parent_name == "HandLayout" or grandparent_name == "HandArea")
		var is_row_slot := (parent_name.begins_with("Slot") and (grandparent_name.begins_with("PFS_") or grandparent_name.begins_with("PBS_") or grandparent_name.begins_with("BFS_") or grandparent_name.begins_with("BBS_")))
		var is_action_slot := (parent_name == "BossActionSlot" or parent_name == "PlayerActionSlot")
		var is_detail_host := (parent_name == "DetailPanelSlot" or parent_name == "CardDetailPanel")
		var is_boss_intent := (parent_name == "BossArea" and card_ui.name == "BossIntentCard")

		if not (is_hand_area or is_row_slot or is_action_slot or is_detail_host or is_boss_intent):
			orphan_count += 1
			push_warning("[AUDIT] Orphaned CardUI: %s; parent=%s grandparent=%s" % [card_ui.name, parent_name, grandparent_name])
			# 鐏忔繆鐦€瑰鍙忕粔濠氭珟
			if card_ui.is_inside_tree():
				card_ui.queue_free()

	if orphan_count > 0:
		push_warning("[AUDIT] Found %d orphaned CardUI - cleaned up" % orphan_count)
	else:
		print("[AUDIT] CardUI ownership OK - all cards in correct hosts")
func _find_all_card_ui(root: Node, out_array: Array) -> void:
	if root is CardUI:
		out_array.append(root)
	for child in root.get_children():
		if is_instance_valid(child):
			_find_all_card_ui(child, out_array)
# ============================================================
# Phase 10D: 鐎瑰鍙忓〒鍛倞 閳?閸︾儤娅欓柅鈧崙鐑樻閸嬫粍顒涢幍鈧張?VFX
# ============================================================
func _exit_tree() -> void:
	_clear_siege_presentation(&"exit_tree")
	if is_instance_valid(battle) and battle.has_method("clear_boss_siege_intent"):
		battle.clear_boss_siege_intent(&"exit_tree")
		battle.clear_boss_terrain_intent(&"exit_tree")
	_cleanup_structure_presentation_lifecycle(&"exit_tree")
	_cancel_monster_summon_interaction(&"exit_tree")
	_clear_garrison_selection(&"exit_tree")
	_disconnect_tactical_terrain_authority()
	_disconnect_tactical_structure_authority()
	if _tactical_terrain_presenter != null and is_instance_valid(_tactical_terrain_presenter):
		_tactical_terrain_presenter.reset_for_stage()
		_tactical_terrain_presenter.queue_free()
	_tactical_terrain_presenter = null
	if _tactical_structure_presenter != null and is_instance_valid(_tactical_structure_presenter):
		_tactical_structure_presenter.queue_free()
	_tactical_structure_presenter = null
	if _tactical_garrison_presenter != null and is_instance_valid(_tactical_garrison_presenter):
		_tactical_garrison_presenter.reset_for_stage()
		_tactical_garrison_presenter.queue_free()
	_tactical_garrison_presenter = null
	if _battle_presentation_director != null and is_instance_valid(_battle_presentation_director):
		_battle_presentation_director.cancel_all(&"exit_tree")
	# Phase 23B-R2: cancel building replace on exit tree
	_cancel_building_replace_selection("exit_tree", false)
	# Phase 26E-R1 Task 5: cancel lane selection and clean up presenter
	_cancel_lane_selection(&"exit_tree")
	if _tactical_presenter and is_instance_valid(_tactical_presenter):
		_tactical_presenter.cancel()
		_tactical_presenter.queue_free()
	_tactical_presenter = null
	_cancel_camera_pan()
	if card_vfx:
		card_vfx.stop_all()
	# Phase 10G: kill BossCore pulse
	_safe_kill_boss_core_pulse()
	if battle_vfx:
		battle_vfx.stop_all()
	# Phase 26D: cleanup OD backline presenter
	if _od_backline_presenter and is_instance_valid(_od_backline_presenter):
		_od_backline_presenter.cancel_presentations()
		_od_backline_presenter.queue_free()
	_od_backline_presenter = null
	# Phase 17A: cleanup monster menu

	# Phase 18A: AnimatedODGauge removed
	_close_monster_command_menu()
	if _monster_command_layer and is_instance_valid(_monster_command_layer):
		_monster_command_layer.queue_free()
	_monster_command_layer = null

# ============================================================
# Phase 13D: Arsenal Panel 鈥?Create + Refresh
# ============================================================

func _setup_arsenal_panel() -> void:
	var battle_table := get_node_or_null(NodePath("BattleTable")) as Control
	if not battle_table:
		push_warning("[ArsenalPanel] BattleTable not found; skipping.")
		return

	_arsenal_panel = ArsenalPanelClass.new()
	_arsenal_panel.name = "ArsenalPanel"
	# Phase 14B-2: align Arsenal to bottom-left table edge (near Arsenal dock concept)
	_arsenal_panel.position = Vector2(16, battle_table.size.y - 280)

	# Load Arsenal data
	var gm := get_node_or_null("/root/GameManager")
	var cards: Array[CardData] = []
	if gm and gm.has_method("get_arsenal_catalog"):
		cards = gm.get_arsenal_catalog()
	else:
		# Fallback: load directly from loader
		var loader_cls = preload("res://core/deck/card_catalog_loader.gd")
		var loader = loader_cls.new()
		loader.load_arsenal_cards()
		cards = loader.get_arsenal_cards()
		for owned in cards:
			_arsenal_panel.add_child(owned)
		loader.free()

	_arsenal_panel.set_arsenal_cards(cards)

	# Bind detail panel
	if player_table and player_table.card_detail_panel and is_instance_valid(player_table.card_detail_panel):
		_arsenal_panel.set_detail_panel(player_table.card_detail_panel)

	# Phase 13E: connect click signal
	if not _arsenal_panel.arsenal_card_clicked.is_connected(_on_arsenal_card_clicked):
		_arsenal_panel.arsenal_card_clicked.connect(_on_arsenal_card_clicked)

	battle_table.add_child(_arsenal_panel)
	# Phase 27K-R0-R2: 旧 Arsenal 悬停 HUD 退出当前 3D 战斗主界面。
	# 数据加载、详情绑定、arsenal_card_clicked 业务连接全部保留；仅关闭显示/输入/处理。
	# 后续 R1/R2 再把武库接入 OD ENGINE 的明确"武库"按钮或抽屉。
	_arsenal_panel.set_battle_hud_enabled(_is_legacy_arsenal_hover_hud_enabled())
	# Phase 27I-R0-R2: Arsenal 建立后同步左侧栏（避免与详情栏重叠）
	_sync_left_rail_layout()
	print("[ArsenalPanel] Created: %d cards loaded." % cards.size())


## Phase 27K-R0-R2: 旧 Arsenal 悬停 HUD 是否在战斗主界面启用。
## 当前真实 3D 战斗模式统一返回 false（Arsenal 数据与业务保留，HUD 显示退出）。
func _is_legacy_arsenal_hover_hud_enabled() -> bool:
	return false
func _refresh_arsenal_panel() -> void:
	if not _arsenal_panel or not is_instance_valid(_arsenal_panel):
		return
	if not context or not context.od_mode:
		return

	var layer: int = context.od_mode.get_engine_layer()
	var burst: bool = context.od_mode.is_burst_active()
	_arsenal_panel.refresh_ext(layer, burst, context.arsenal_mid_used, context.arsenal_final_used)

	# One-time hints per layer
	_show_arsenal_hint(layer)
func _show_arsenal_hint(layer: int) -> void:
	# Phase 27K-R0-R2: 旧 Arsenal 悬停入口不可见时，不再提示玩家使用不存在的悬停入口。
	if not _is_legacy_arsenal_hover_hud_enabled():
		return
	var key: String = "arsenal_hint_L%d" % layer
	if _arsenal_hints_shown.get(key, false):
		return
	_arsenal_hints_shown[key] = true

	if action_feed == null:
		return
	match layer:
		2: action_feed.push_message("Arsenal preview online - hover to inspect", Color(0.35, 0.55, 0.75, 1))
		3: action_feed.push_message("Mid Arsenal ready - OD L3 unlocked", Color(0.25, 0.65, 0.35, 1))
		5: action_feed.push_message("Final Arsenal ready - Burst active", Color(1.0, 0.55, 0.10, 1))

# ============================================================
# Phase 13E: Arsenal Card Click Handling
# ============================================================

func _on_arsenal_card_clicked(card: CardData) -> void:
	if card == null or battle == null:
		return

	# Phase 13F-2: block ascension forms from direct summon
	if card.is_ascension_form:
		if action_feed:
			action_feed.push_message("Arsenal: monster ascension only", TC.WARNING)
			_show_floating_text("Arsenal: monster ascension only", TC.WARNING, 1.5, 14)
		return

	# Phase 13F-6: A02/A03/A05 use new final arsenal path
	var is_final_spell_build := card.card_id in ["A02", "A03", "A05"]
	if is_final_spell_build:
		var final_status: Dictionary = battle.get_final_arsenal_play_status(card, context.player)
		if not bool(final_status.get("ok", false)):
			var reason: String = final_status.get("reason", "涓嶅彲浣跨敤")
			if action_feed:
				action_feed.push_message("Arsenal: %s" % reason, TC.WARNING)
			_show_floating_text(reason, TC.WARNING, 1.2, 14)
			return
		var final_result: Dictionary = battle.play_final_arsenal_card(card, context.player)
		if not bool(final_result.get("ok", false)):
			if action_feed:
				action_feed.push_message("Arsenal failed: %s" % final_result.get("message", ""), TC.DANGER)
			return
		var final_msg: String = final_result.get("message", "")
		if action_feed:
			action_feed.push_message(final_msg, Color(1.0, 0.75, 0.2, 1))
		var fdname := card.get_display_name() if card.has_method("get_display_name") else card.card_name
		_add_to_this_turn("Final Arsenal: %s" % fdname, Color(1.0, 0.75, 0.2, 1))
		if _playtest:
			_playtest.record_event("arsenal_card_used", {"card": card.card_name, "tier": "final", "turn": context.turn_count})
		if player_table:
			player_table.flash_zone("spell")
		_refresh_tables()
		return

	# Legacy: mid Arsenal path (should only be reached for non-ascension mid cards, if any)
	var status: Dictionary = battle.get_arsenal_play_status(card)
	if not bool(status.get("ok", false)):
		var reason: String = status.get("reason", "涓嶅彲浣跨敤")
		if action_feed:
			action_feed.push_message("Arsenal: %s" % reason, TC.WARNING)
		_show_floating_text(reason, TC.WARNING, 1.2, 14)
		return

	var result: Dictionary = {}
	if card.arsenal_tier == "final":
		result = battle.play_final_arsenal_card(card, context.player)
	else:
		result = battle.play_mid_arsenal_card(card)
	if not bool(result.get("ok", false)):
		if action_feed:
			action_feed.push_message("Arsenal failed: %s" % result.get("message", ""), TC.DANGER)
		return

	# UI 鍙嶉
	var msg: String = result.get("message", "")
	if action_feed:
		action_feed.push_message(msg, Color(0.25, 0.70, 0.40, 1))
	if player_table and player_table.has_method("_add_to_this_turn"):
		pass  # ThisTurn 鐢?_refresh_tables flow 鏇存柊
	if _add_to_this_turn != null:
		var dname := card.get_display_name() if card.has_method("get_display_name") else card.card_name
		_add_to_this_turn("Arsenal: %s" % dname, Color(0.25, 0.70, 0.40, 1))

	# Telemetry
	if _playtest:
		_playtest.record_event("arsenal_card_used", {"card": card.card_name, "tier": "mid", "turn": context.turn_count})

	# [Fixed]
	if player_table:
		player_table.flash_zone("front")

	# Refresh tables and board
	_refresh_tables()

# ============================================================
# Phase 13F-3: Ascension Trigger Handler
# ============================================================

func _on_ascend_triggered(base_card: CardData, target_card: CardData) -> void:
	if base_card == null or target_card == null or battle == null:
		return

	var result: Dictionary = battle.ascend_card(base_card, target_card, context.player)
	if not result.get("ok", false):
		var reason: String = result.get("message", "ascension blocked")
		if action_feed:
			action_feed.push_message("Ascend failed: %s" % reason, TC.WARNING)
		_show_floating_text(reason, TC.WARNING, 1.2, 14)
		return

	var msg: String = result.get("message", "")
	if action_feed:
		action_feed.push_message(msg, Color(1.0, 0.75, 0.2, 1))

	var dname := target_card.get_display_name() if target_card.has_method("get_display_name") else target_card.card_name
	_add_to_this_turn("Ascend: %s" % dname, Color(1.0, 0.75, 0.2, 1))

	if _playtest:
		_playtest.record_event("ascension_triggered", {"source": base_card.card_name, "target": target_card.card_name, "turn": context.turn_count})

	# Phase 26B-T3: Ascension golden swap visual sequence
	await _play_ascension_visual(base_card, target_card)

	# Visual feedback: front zone flash
	if player_table:
		player_table.flash_zone("front")

	_refresh_tables()
	check_battle_end()


## Phase 26B-T3: Ascension golden swap visual sequence
func _play_ascension_visual(base_card: CardData, target_card: CardData) -> void:
	var token: Node3D = _get_3d_token_for_card(base_card)
	if token == null or not is_instance_valid(token):
		return
	var carrier: Node3D = token.get_node_or_null("CardCarrier") as Node3D
	if carrier == null or not is_instance_valid(carrier):
		return

	# 1. Golden charge on original card (0.20s)
	var gold := Color(1.0, 0.85, 0.3, 1.0)
	if carrier.has_method("set_glow_color"):
		carrier.set_glow_color(gold)
	await get_tree().create_timer(0.20).timeout

	# 2. Brightness up + scale pulse (0.18s)
	if is_instance_valid(carrier):
		var t1: Tween = create_tween()
		t1.set_parallel(true)
		t1.tween_property(carrier, "scale", Vector3(1.08, 1.08, 1.08), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if is_instance_valid(carrier) and carrier.has_method("set_glow_color"):
		carrier.set_glow_color(Color(1.0, 0.95, 0.5, 1.0))
	await get_tree().create_timer(0.18).timeout

	# 3. Switch to target card (0.28s fade in)
	if is_instance_valid(token) and is_instance_valid(carrier) and carrier.has_method("configure_card"):
		carrier.configure_card(target_card, "player", "front")
		_apply_runtime_stats_to_token(token, target_card, "front")

		if carrier.has_method("set_glow_color"):
			carrier.set_glow_color(Color(1.0, 0.75, 0.2, 1.0))

		var t2: Tween = create_tween()
		t2.tween_property(carrier, "scale", Vector3(1.0, 1.0, 1.0), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await t2.finished

	# 4. Restore baseline (0.18s)
	if is_instance_valid(token):
		_reset_token_presentation(token, "player", "front")
		if is_instance_valid(carrier) and carrier.has_method("set_glow_color"):
			# Restore default glow temporarily — next refresh will re-apply proper glow
			pass

	await get_tree().create_timer(0.18).timeout


func _setup_table_art_root() -> void:
	var bt := get_node_or_null(NodePath("BattleTable")) as Control
	if not bt:
		push_warning("[TableArtRoot] BattleTable not found; skipping.")
		return

	_make_table_art_visible(bt)

	var root := bt.get_node_or_null(NodePath("TableArtRoot")) as Control
	if root:
		for child in root.get_children():
			root.remove_child(child)
			child.queue_free()
	else:
		root = Control.new()
		root.name = "TableArtRoot"
		bt.add_child(root)
		bt.move_child(root, 0)
	root.z_index = ZI_DEBUG_BORDER  # 2: visible over old embedded table fills, under slots/cards.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.clip_contents = true

	# Phase 18H-1: try cloudgate naming first, then fall back to placeholder naming
	# Fallback order: cloudgate_v2/ 鈫?final/ 鈫?placeholder/ 鈫?skip
	# 1. Table base + frame
	var table_base_art := _add_art_texture_v2(root, "table_base_cloudgate", "table_base_placeholder", true)
	if table_base_art:
		# Phase 19B: 3d_hybrid mode keeps 2D art faint so 3D board is visible
		table_base_art.modulate.a = 0.04 if BOARD_VISUAL_MODE == "3d_hybrid" else 0.12
	var table_frame_art := _add_art_texture_v2(root, "table_frame_cloudgate", "table_frame_placeholder", true)
	if table_frame_art:
		table_frame_art.modulate.a = 0.06 if BOARD_VISUAL_MODE == "3d_hybrid" else 0.18

	# 2. Player DeckBox + GYBox (bottom-right)
	var pdeck := _add_art_texture_v2(root, "deck_box_player", "deck_box_player_placeholder", false)
	if pdeck:
		# Phase 14B-2: align with narrowed RightTrack (x=1500)
		pdeck.position = Vector2(1495, 770)
	var pgy := _add_art_texture_v2(root, "graveyard_box_player", "graveyard_box_player_placeholder", false)
	if pgy:
		pgy.position = Vector2(1495, 830)

	# 3. Boss DeckBox + GYBox (top-right)
	var bdeck := _add_art_texture_v2(root, "deck_box_boss", "deck_box_boss_placeholder", false)
	if bdeck:
		bdeck.position = Vector2(1495, 10)
	var bgy := _add_art_texture_v2(root, "graveyard_box_boss", "graveyard_box_boss_placeholder", false)
	if bgy:
		bgy.position = Vector2(1495, 65)

	# Phase 21B: 3D 妫嬬洏涓昏儗鏅ā寮忎笅闅愯棌 2D 妗屽竷
	if USE_TRUE_3D_BOARD_BACKGROUND:
		root.visible = false
		print("[3D_BOARD] table_art_hidden=true")
	print("[TableArtRoot] Created: cloudgate_v2 -> final -> placeholder fallback active")
func _make_table_art_visible(bt: Control) -> void:
	# Phase 19B: hide old 2D table layers (TableSurface, TableBorder, CenterDivider)
	for node_name in ["TableSurface", "TableBorder", "CenterDivider"]:
		var old_layer := bt.get_node_or_null(NodePath(node_name)) as CanvasItem
		if old_layer:
			old_layer.visible = false
			if old_layer is Control:
				(old_layer as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
# Phase 18H-1: cloudgate_v2 鈫?final 鈫?placeholder 鈫?skip
func _resolve_table_art_path(file_name: String) -> String:
	var cloudgate_path := "res://assets/table/cloudgate_v2/%s" % file_name
	var final_path := "res://assets/table/final/%s" % file_name
	var placeholder_path := "res://assets/table/placeholder/%s" % file_name
	if ResourceLoader.exists(cloudgate_path): return cloudgate_path
	if ResourceLoader.exists(final_path): return final_path
	if ResourceLoader.exists(placeholder_path): return placeholder_path
	return ""
func _load_table_texture(path: String) -> Texture2D:
	# Exported textures may exist only through .import remapping, without raw PNG.
	if ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return ResourceLoader.load(path,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if path.ends_with(".png"):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var bytes := file.get_buffer(file.get_length())
			var image := Image.new()
			var err := image.load_png_from_buffer(bytes)
			if err == OK:
				return ImageTexture.create_from_image(image)
	var image := Image.new()
	var err := image.load(path)
	if err == OK:
		return ImageTexture.create_from_image(image)
	return ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
func _add_art_texture(parent: Control, name: String, full_rect: bool, warn_on_missing: bool = true) -> TextureRect:
	var path: String = _resolve_table_art_path("%s.png" % name)
	if path == "":
		if warn_on_missing:
			push_warning("[TableArtRoot] Missing: %s; skipped." % name)
		return null
	var tex: Texture2D = _load_table_texture(path)
	if tex == null:
		return null
	var rect := TextureRect.new()
	rect.name = name
	rect.texture = tex
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	if full_rect:
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
	else:
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP
	return rect

# Phase 18H-1: try cloudgate name first, fall back to placeholder name
func _add_art_texture_v2(parent: Control, name_cloudgate: String, name_fallback: String, full_rect: bool) -> TextureRect:
	var rect := _add_art_texture(parent, name_cloudgate, full_rect, false)
	if rect: return rect
	return _add_art_texture(parent, name_fallback, full_rect)

# ============================================================
# Phase 14D: Engine Gauge embedded art
# ============================================================
func _add_gauge_art_background(panel: Panel) -> void:
	# Phase 18I-1R: prefer cloudgate_v2 od_gauge_housing, fallback to old engine_gauge
	var art_path: String = _resolve_table_art_path("od_gauge_housing.png")
	if art_path == "":
		art_path = _resolve_table_art_path("engine_gauge_placeholder.png")
	if art_path == "":
		art_path = _resolve_table_art_path("engine_gauge_final.png")
	if art_path == "":
		return
	var tex: Texture2D = ResourceLoader.load(art_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if tex == null:
		return
	var bg := TextureRect.new()
	bg.name = "GaugeArtBg"
	bg.texture = tex
	bg.modulate = Color(1, 1, 1, 0.35)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -1
	panel.add_child(bg)
	panel.move_child(bg, 0)
	print("[EngineGauge] CloudGate v2 od_gauge_housing loaded")

	print("[EngineGauge] Art background added")
func _refresh_depth_visual(panel: Panel, depth: int, zone: String) -> void:
	var old := panel.get_node_or_null(NodePath("DepthOverlay"))
	if old and is_instance_valid(old):
		old.queue_free()

	var alpha: float = 0.0
	var color := Color(0.0, 0.0, 0.0, 0.0)
	# Phase 15A-R: reduced alpha, thin border strip instead of full rect
	if zone == "Backlash" or depth >= 6:
		color = Color(0.6, 0.05, 0.3, 0.06); alpha = 0.12
	elif depth >= 3:
		color = Color(0.5, 0.25, 0.05, 0.08); alpha = 0.08
	elif depth >= 1:
		color = Color(0.1, 0.2, 0.5, 0.04); alpha = 0.04

	if alpha <= 0.0: return

	if alpha > 0.0:
			var depth_art_path: String = _resolve_table_art_path("depth_crack_overlay.png")
			if depth_art_path != "":
				var depth_tex: Texture2D = ResourceLoader.load(depth_art_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
				if depth_tex:
					var depth_bg := TextureRect.new()
					depth_bg.name = "DepthCrackArt"
					depth_bg.texture = depth_tex
					depth_bg.modulate = Color(1, 1, 1, alpha * 1.5)
					depth_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
					depth_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
					depth_bg.z_index = -2
					panel.add_child(depth_bg)
					panel.move_child(depth_bg, 0)
	var overlay := ColorRect.new()
	overlay.name = "DepthOverlay"
	overlay.color = color
	overlay.anchor_left = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_top = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 4.0
	overlay.offset_right = -4.0
	overlay.offset_top = -6.0
	overlay.offset_bottom = -2.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 0
	panel.add_child(overlay)

# ============================================================
# Phase 15B: Monster Command Menu
# ============================================================

func _get_garrison_command_status(unit: CardData) -> Dictionary:

	var result := {
		"ok": false,
		"mode": &"enter",
		"unit_runtime_id": unit.get_instance_id() if unit != null else 0,
		"action_cost": 1,
		"reason_code": &"garrison_unit_missing",
		"reason_text": "驻防单位不存在",
		"candidates": [],
	}
	if battle == null or unit == null or not battle.has_method("get_garrison_state_for_unit"):
		return result
	var assignment: Dictionary = battle.get_garrison_state_for_unit(unit)
	var candidates: Array[Dictionary] = []
	var first_reject: Dictionary = {}
	if not assignment.is_empty() and StringName(str(assignment.get("state", &""))) in [&"active", &"displaced_pending_exit"]:
		result.mode = &"displaced" if assignment.get("state") == &"displaced_pending_exit" else &"exit"
		var parent_cell: Vector2i = assignment.get("parent_cell", Vector2i(-1, -1))
		for offset in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			var status: Dictionary = battle.get_garrison_exit_status(unit, parent_cell + offset)
			status["mode"] = result.mode
			status["socket_name"] = assignment.get("socket_name", &"Garrison0")
			if bool(status.get("ok", false)):
				candidates.append(status.duplicate(true))
			elif first_reject.is_empty():
				first_reject = status.duplicate(true)
	else:
		var structures_value: Variant = battle.get_structure_snapshot().get("structures", {})
		var structures: Dictionary = structures_value if structures_value is Dictionary else {}
		for raw_structure in structures.values():
			if not raw_structure is Dictionary:
				continue
			var structure: Dictionary = raw_structure
			if StringName(str(structure.get("owner_side", &""))) != &"player" \
					or StringName(str(structure.get("profile_id", &""))) != &"p08_fortification":
				continue
			var structure_id := StringName(str(structure.get("structure_id", &"")))
			var status: Dictionary = battle.get_garrison_enter_status(unit, structure_id, &"garrison_0")
			status["mode"] = &"enter"
			var plan: Dictionary = status.get("assignment_plan", {})
			status["socket_name"] = plan.get("socket_name", &"Garrison0")
			if bool(status.get("ok", false)):
				candidates.append(status.duplicate(true))
			elif first_reject.is_empty():
				first_reject = status.duplicate(true)
		if first_reject.is_empty():
			first_reject = battle.get_garrison_enter_status(unit, &"", &"garrison_0")
	result.candidates = candidates.duplicate(true)
	if not candidates.is_empty():
		var first: Dictionary = candidates[0]
		result.ok = true
		result.reason_code = &"ok"
		result.reason_text = str(first.get("reason_text", "可驻防"))
		result.action_cost = int(first.get("action_cost", 1))
		result.guidance_text = _garrison_guidance_text(first, result.mode)
		return result.duplicate(true)
	if not first_reject.is_empty():
		result.reason_code = first_reject.get("reason_code", &"garrison_target_stale")
		result.reason_text = str(first_reject.get("reason_text", "当前不可驻防"))
		result.action_cost = int(first_reject.get("action_cost", 1))
		result.guidance_text = _garrison_guidance_text(first_reject, result.mode)
	return result.duplicate(true)


## Presentation only: legality always comes from the original status query.
func _garrison_guidance_text(status: Dictionary, mode: StringName) -> String:
	if mode != &"enter":
		return "选择亮起的相邻格并确认撤离。" if bool(status.get("ok", false)) else str(status.get("reason_text", "当前不可撤离"))
	if bool(status.get("ok", false)):
		return "驻防：选择亮起的堡垒并确认，消耗 %d 次移动行动。\n进入后本回合不能攻击；之后仍需目标在合法射程内。" % int(status.get("action_cost", 1))
	var reason := StringName(str(status.get("reason_code", &"")))
	var text := str(status.get("reason_text", "当前不可驻防"))
	if reason == &"garrison_structure_missing":
		return text + "。先建造己方【铁誓烽堡】。"
	if reason not in [&"garrison_not_adjacent", &"garrison_height_or_passage_blocked"]:
		return text
	var cell: Vector2i = status.get("parent_cell", Vector2i(-1, -1))
	var slot: Dictionary = battle.tactical_garrison_rules.get_slot_profile(&"p08_fortification", &"garrison_0")
	var height: int = battle.get_cell_height(cell) + int(slot.get("platform_height_offset", 0))
	var from_cell: Vector2i = status.get("from_cell", Vector2i(-1, -1))
	text += "。\n单位 H%d → 平台 H%d（含托座）；普通进入要求高差≤1。" % [battle.get_cell_height(from_cell), height]
	var gates: Array[String] = []
	var directions := {&"north": "北侧", &"east": "东侧", &"south": "南侧", &"west": "西侧"}
	for edge in directions:
		var module: Dictionary = battle.get_structure_module(cell, edge)
		if module.get("structure_id", &"") == status.get("structure_id", &"") \
				and int(module.get("integrity_current", 0)) > 0 \
				and module.get("status", &"") != &"destroyed" \
				and bool(module.get("allows_owner_passage", false)):
			gates.append(directions[edge])
	if not gates.is_empty():
		text += "\n可先移到堡垒%s门楼外的相邻格，再选驻防；仍需有移动行动。" % "／".join(gates)
	else:
		text += "\n无可用门楼通道；需先调整相邻地块高度，再检查驻防条件。"
	return text


func _begin_garrison_selection(unit: CardData, supplied_status: Dictionary = {}) -> void:

	var status := supplied_status.duplicate(true) if not supplied_status.is_empty() else _get_garrison_command_status(unit)
	if not bool(status.get("ok", false)):
		_show_floating_text(str(status.get("reason_text", "当前不可驻防")), TC.WARNING, 1.2, 14)
		return
	_cancel_lane_selection(&"garrison_begin")
	_clear_skill_selection(&"garrison_begin")
	_clear_od_release_selection(&"garrison_begin")
	_close_monster_command_menu()
	var next_generation := int(_garrison_context.get("generation", 0)) + 1
	_garrison_context = {
		"active": true,
		"mode": StringName(str(status.get("mode", &"enter"))),
		"stage": &"selecting",
		"unit": unit,
		"candidates": (status.get("candidates", []) as Array).duplicate(true),
		"pending_status": {},
		"generation": next_generation,
	}
	_camera_orbit_frozen = true
	_cancel_camera_pan()
	_set_garrison_detail_suppressed(true)
	if _tactical_garrison_presenter != null and is_instance_valid(_tactical_garrison_presenter):
		_tactical_garrison_presenter.call(
			"show_enter_candidates",
			unit.get_instance_id(),
			_garrison_context.get("candidates", []),
			_is_reduced_motion_presentation()
		)
	if _end_turn_control != null and is_instance_valid(_end_turn_control):
		_end_turn_control.set_busy(true, "请选择驻防位置" if _garrison_context.mode == &"enter" else "请选择撤离位置")


func _stage_garrison_candidate(status: Dictionary) -> void:

	if not bool(_garrison_context.get("active", false)) or not bool(status.get("ok", false)):
		return
	_garrison_context.stage = &"pending"
	_garrison_context.pending_status = status.duplicate(true)
	if _tactical_garrison_presenter != null and is_instance_valid(_tactical_garrison_presenter):
		_tactical_garrison_presenter.call("show_pending", status.duplicate(true), _is_reduced_motion_presentation())
	var unit: CardData = _garrison_context.get("unit", null)
	var mode := StringName(str(_garrison_context.get("mode", &"enter")))
	var source_screen := Vector2.ZERO
	var token := _get_3d_token_for_card(unit)
	if token != null:
		source_screen = _project_3d_token_to_screen(token)
	var target_cell: Vector2i = status.get("target_cell", status.get("parent_cell", Vector2i(-1, -1)))
	var target_screen := _project_tactical_cell_to_screen(target_cell)
	var label := unit.get_display_name() if unit != null and unit.has_method("get_display_name") else "单位"
	var verb := "驻防" if mode == &"enter" else "撤离"
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		_monster_summon_interaction_presenter.show_card_pending({
			"source_screen_position": source_screen,
			"target_screen_position": target_screen,
			"pointer_screen_position": target_screen,
			"candidate_target": {"target_kind": &"tactical_cell", "board_cell": target_cell},
			"legal": true,
			"intent_kind": &"garrison",
			"presentation_profile_id": &"monster_summon",
		}, "确认%s「%s」？" % [verb, label], "确认%s" % verb, "重新选择", _is_reduced_motion_presentation())


func _reselect_garrison_selection() -> void:

	if not bool(_garrison_context.get("active", false)):
		return
	var unit: CardData = _garrison_context.get("unit", null)
	var status := _get_garrison_command_status(unit)
	if not bool(status.get("ok", false)):
		_clear_garrison_selection(&"stale_reselect")
		_show_floating_text(str(status.get("reason_text", "驻防状态已变化")), TC.WARNING, 1.2, 14)
		return
	_garrison_context.mode = status.get("mode", &"enter")
	_garrison_context.stage = &"selecting"
	_garrison_context.candidates = (status.get("candidates", []) as Array).duplicate(true)
	_garrison_context.pending_status = {}
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter):
		_monster_summon_interaction_presenter.clear()
	if _tactical_garrison_presenter != null and is_instance_valid(_tactical_garrison_presenter):
		_tactical_garrison_presenter.call(
			"show_enter_candidates", unit.get_instance_id(), _garrison_context.candidates,
			_is_reduced_motion_presentation()
		)


func _confirm_pending_garrison() -> Dictionary:

	if not bool(_garrison_context.get("active", false)) or _garrison_context.get("stage") != &"pending":
		return {"ok": false, "reason_code": &"not_pending"}
	var unit: CardData = _garrison_context.get("unit", null)
	var pending: Dictionary = (_garrison_context.get("pending_status", {}) as Dictionary).duplicate(true)
	var mode := StringName(str(_garrison_context.get("mode", &"enter")))
	var fresh: Dictionary
	if mode == &"enter":
		fresh = battle.get_garrison_enter_status(
			unit,
			StringName(str(pending.get("structure_id", &""))),
			StringName(str(pending.get("slot_id", &"garrison_0")))
		)
	else:
		fresh = battle.get_garrison_exit_status(unit, pending.get("target_cell", Vector2i(-1, -1)))
	if not bool(fresh.get("ok", false)):
		_show_floating_text(str(fresh.get("reason_text", "驻防状态已变化")), TC.WARNING, 1.2, 14)
		_reselect_garrison_selection()
		return fresh
	var fact: Dictionary
	if mode == &"enter":
		fact = battle.commit_garrison_enter(
			unit,
			StringName(str(fresh.get("structure_id", &""))),
			StringName(str(fresh.get("slot_id", &"garrison_0"))),
			{"expected_status": fresh.duplicate(true)}
		)
	else:
		fact = battle.commit_garrison_exit(
			unit,
			fresh.get("target_cell", Vector2i(-1, -1)),
			{"expected_status": fresh.duplicate(true)}
		)
	if not bool(fact.get("ok", false)):
		_show_floating_text(str(fact.get("reason_text", "驻防执行失败")), TC.WARNING, 1.2, 14)
		_reselect_garrison_selection()
		return fact
	_refresh_tables()
	_sync_3d_field_tokens()
	var token := _get_3d_token_for_card(unit)
	var presentation_fact := fact.duplicate(true)
	if token != null:
		presentation_fact["unit_visual"] = token
	if _tactical_garrison_presenter != null and is_instance_valid(_tactical_garrison_presenter):
		_tactical_garrison_presenter.call(
			"apply_garrison_snapshot",
			context.tactical_structure_board_state.get_garrison_snapshot().duplicate(true),
			presentation_fact,
			_is_reduced_motion_presentation()
		)
	var verb := "驻防" if mode == &"enter" else "撤离"
	if action_feed != null:
		action_feed.push_message("%s完成" % verb, Color(0.35, 0.9, 0.86))
	_play_command_economy_spend(int(fact.get("action_cost", 1)))
	_clear_garrison_selection(&"committed")
	return fact.duplicate(true)


func _clear_garrison_selection(reason: StringName = &"cleanup") -> void:

	var was_active := bool(_garrison_context.get("active", false))
	var next_generation := int(_garrison_context.get("generation", 0)) + 1
	_garrison_context = {
		"active": false,
		"mode": &"none",
		"stage": &"idle",
		"unit": null,
		"candidates": [],
		"pending_status": {},
		"generation": next_generation,
	}
	if _tactical_garrison_presenter != null and is_instance_valid(_tactical_garrison_presenter):
		_tactical_garrison_presenter.call("clear_transient", reason)
	if _monster_summon_interaction_presenter != null and is_instance_valid(_monster_summon_interaction_presenter) \
			and not _is_monster_summon_interaction_active():
		_monster_summon_interaction_presenter.clear()
	if was_active:
		_set_garrison_detail_suppressed(false)
	_camera_orbit_frozen = _monster_command_menu != null and is_instance_valid(_monster_command_menu)
	if not _camera_orbit_frozen and not _exit_modal_active:
		_camera_orbit_dragging = false
	if _end_turn_control != null and is_instance_valid(_end_turn_control) and not _has_non_presentation_end_turn_busy():
		_end_turn_control.set_busy(false, "")


func _set_garrison_detail_suppressed(active: bool) -> void:

	if active:
		_garrison_detail_was_visible = _detail_panel_slot != null and _detail_panel_slot.visible
		_garrison_detail_was_pinned = _detail_panel_pinned_layout
		if player_table != null and player_table.card_detail_panel != null:
			player_table.card_detail_panel.visible = false
		_set_detail_panel_expanded(false, true, false)
		return
	if _garrison_detail_was_visible and player_table != null and player_table.card_detail_panel != null:
		player_table.card_detail_panel.visible = true
	_set_detail_panel_expanded(_garrison_detail_was_visible, true, _garrison_detail_was_pinned)
	_garrison_detail_was_visible = false
	_garrison_detail_was_pinned = false

func _get_monster_command_layer() -> CanvasLayer:
	if _monster_command_layer and is_instance_valid(_monster_command_layer):
		return _monster_command_layer
	_monster_command_layer = CanvasLayer.new()
	_monster_command_layer.name = "MonsterCommandLayer"
	_monster_command_layer.layer = 80
	add_child(_monster_command_layer)
	return _monster_command_layer
func _open_monster_command_menu(card: CardData) -> void:
	if card == null: return

	# Phase 18A: AnimatedODGauge removed 鈥?close previous before freezing
	_close_monster_command_menu()
	# Phase 27E-R4: clear skill targeting when switching to a different monster
	if _skill_context.get("active", false):
		var prev_caster = _skill_context.get("caster") as CardData
		if prev_caster and prev_caster.get_instance_id() != card.get_instance_id():
			_clear_skill_selection(&"switch_monster")

	# Phase 23A-V4: freeze camera and cancel pan while menu is open
	_camera_orbit_frozen = true
	_cancel_camera_pan()

	var card_label := card.get_display_name() if card.has_method("get_display_name") else card.card_name
	# Phase 19C: [MONSTER_MENU_OPEN] moved to after positioning

	var menu = MonsterCommandMenuClass.new()  # MonsterCommandMenu
	menu.name = "MonsterCommandMenu"
	var menu_layer := _get_monster_command_layer()
	menu_layer.add_child(menu)
	# Phase 19C-3: CanvasLayer keeps command menu above table/HUD/hand layers.
	menu.z_index = ZI_MONSTER_MENU  # 500
	menu_layer.move_child(menu, menu_layer.get_child_count() - 1)

	# Query ascension status
	var asc_status: Dictionary = {"has_target": false, "ok": false, "reason": ""}
	if battle and battle.has_method("get_ascension_preview_status"):
		asc_status = battle.get_ascension_preview_status(card, context.player)
	# Phase 15C: also query active effect status
	var active_status: Dictionary = {}
	if battle and battle.has_method("get_monster_active_status"):
		active_status = battle.get_monster_active_status(card, context.player)
	# Phase 27D: unified command status queries with economy costs
	var atk_status: Dictionary = {"ok": false, "reason": "", "cost": 2}
	var move_status: Dictionary = {"ok": false, "reason": "不可移动", "legal_cells": [], "reason_code": &"", "engaged": false, "cost": 1}
	var turn_status: Dictionary = {"ok": false, "reason": "不可回防", "cost": 1}
	var od_breach_status: Dictionary = {"ok": false, "reason": "", "cost": 3}
	var economy_snapshot: Dictionary = {}
	if battle and battle.has_method("get_command_economy_snapshot"):
		economy_snapshot = battle.get_command_economy_snapshot("player")
	if battle and battle.has_method("get_unit_command_status"):
		var atk_cs: Dictionary = battle.get_unit_command_status(card, "attack")
		# Phase 27E-R3: Query both get_unit_attack_command_status (geometry) and get_unit_command_status (economy), merge
		var atk_rich: Dictionary = {}
		if battle.has_method("get_unit_attack_command_status"):
			atk_rich = battle.get_unit_attack_command_status(card)
		var atk_ok: bool = bool(atk_cs.get("ok", false))
		var atk_rc: StringName = atk_cs.get("reason_code", &"state_missing")
		var atk_reason: String = _map_attack_reason_text(atk_rc, atk_rich)
		# If economy says ok but geometry says no, use geometry reason
		if atk_ok and not bool(atk_rich.get("ok", true)):
			atk_ok = false
			atk_rc = atk_rich.get("reason_code", &"attack_locked")
			atk_reason = str(atk_rich.get("reason_text", atk_reason))
		atk_status = {
			"ok": atk_ok,
			"reason": atk_reason,
			"reason_code": atk_rc,
			"cost": atk_cs.get("cost", 2),
			"current_points": atk_cs.get("current_points", 0),
			"legal_targets": atk_rich.get("legal_targets", atk_cs.get("legal_targets", [])),
			"legal_target_cells": atk_rich.get("legal_target_cells", []),
			"core_attack_ok": bool(atk_rich.get("core_attack_ok", false)),
			"geometric_attack_cells": atk_rich.get("geometric_attack_cells", []),
		}
		# Phase 27E-R3: diagnostic log on every menu open
		var diag_cell: Vector2i = battle.get_unit_cell(card) if battle.has_method("get_unit_cell") else Vector2i(-1, -1)
		var diag_facing: String = "?"
		if battle.has_method("get_unit_facing"):
			diag_facing = str(battle.get_unit_facing(card))
		elif atk_rich.has("facing"):
			diag_facing = str(atk_rich.get("facing", "?"))
		print("[ATTACK_STATUS] card_id=%s card=%s cell=(%d,%d) facing=%s ok=%s reason_code=%s cost=%d points=%d legal_targets=%d core_ok=%s" % [
			card.card_id, card_label, diag_cell.x, diag_cell.y, diag_facing,
			atk_ok, atk_rc, atk_status.get("cost", 2),
			atk_status.get("current_points", 0),
			(atk_status.get("legal_targets", []) as Array).size(),
			atk_status.get("core_attack_ok", false)
		])
		var move_cs: Dictionary = battle.get_unit_command_status(card, "move")
		var move_rc: StringName = move_cs.get("reason_code", &"")
		move_status = {"ok": move_cs.get("ok", false), "reason": _map_move_reason_text(move_rc, move_cs, card), "legal_cells": move_cs.get("legal_cells", []), "reason_code": move_rc, "engaged": battle.is_unit_engaged(card) if battle.has_method("is_unit_engaged") else false, "cost": move_cs.get("cost", 1), "hint": _get_move_hint(card, move_cs, move_cs.get("legal_cells", []))}
		var turn_cs: Dictionary = battle.get_unit_command_status(card, "turn")
		turn_status = {"ok": turn_cs.get("ok", false), "reason": str(turn_cs.get("reason_text", "不可回防")), "cost": turn_cs.get("cost", 1)}
		var od_cs: Dictionary = battle.get_unit_command_status(card, "overdrive_breach")
		od_breach_status = {"ok": od_cs.get("ok", false), "reason": str(od_cs.get("reason_text", "")), "cost": od_cs.get("cost", 3)}
	var combat_state := _get_runtime_unit_state(card)
	# Phase 27E-R2: query skill status
	var skill_status: Dictionary = {}
	if battle and battle.has_method("get_monster_hero_skills") and battle.get_monster_hero_skills() != null:
		var skill_snap = battle.get_monster_hero_skills()
		if skill_snap.has_skill(card.card_id):
			var skill_def: Dictionary = skill_snap.get_active(card.card_id)
			if not skill_def.is_empty():
				var sid: StringName = StringName(str(skill_def.get("id", "")))
				var ss: Dictionary = battle.get_unit_skill_command_status(card, sid)
				skill_status = {
					"ok": bool(ss.get("ok", false)),
					"skill_name": str(skill_def.get("name", _tr_skill_name(sid))),
					"skill_id": str(sid),
					"passive_name": str(skill_snap.get_passive(card.card_id).get("name", "")),
					"cost": int(ss.get("cost", 0)),
					"base_cost": int(ss.get("base_cost", 0)),
					"stack_count": int(ss.get("stack_count", 0)),
					"max_stacks": int(ss.get("max_stacks", 0)),
					"reason": str(ss.get("reason_code", "")),
					"reason_text": _skill_reason_to_chinese(str(ss.get("reason_code", ""))),
				}
	var garrison_status: Dictionary = _get_garrison_command_status(card)
	menu.setup(card, asc_status, active_status, atk_status, combat_state, move_status, turn_status, od_breach_status, economy_snapshot, skill_status, garrison_status)
	# Phase 27I-R0-R: 怪兽菜单展示棋型与强化费用（P02/P03；只读展示，合法性由 BattleSystem 查询）。
	# 必须在 menu.setup 之后调用，否则 setup 会覆盖标题。
	if battle and battle.has_method("get_card_piece_status") and card.piece_enabled and menu.has_method("set_piece_info"):
		var piece_query: Dictionary = battle.get_card_piece_status(card, &"move")
		var p_name: String = str(piece_query.get("piece_name", ""))
		# 强化费用使用权威棋子快照（基础查询的 piece_command_cost 为 0，不代表强化费用）
		var piece_cost: int = 1
		var depth_cost: int = 1
		if battle.has_method("get_card_piece_traits"):
			var traits = battle.get_card_piece_traits()
			if traits != null and traits.has_method("get_enhance_command_cost"):
				piece_cost = int(traits.get_enhance_command_cost())
			if traits != null and traits.has_method("get_enhance_depth_cost"):
				depth_cost = int(traits.get_enhance_depth_cost())
		menu.set_piece_info(p_name, "基础移动/攻击", "强化：指令 -%d" % piece_cost, "Depth +%d（Overdrive 可选）" % depth_cost)

	# Phase 24A-R4: Prefer the real 3D token projection so the menu visually belongs to the selected monster.
	var vp: Rect2 = get_viewport_rect()
	var menu_size: Vector2 = menu.size
	if menu_size.x <= 0.0 or menu_size.y <= 0.0:
		menu_size = menu.custom_minimum_size
	if menu_size.x <= 0.0 or menu_size.y <= 0.0:
		menu_size = Vector2(310, 60)
	var card_pos: Vector2 = Vector2.ZERO
	var token_3d := _get_3d_token_for_card(card)
	var used_3d_projection := false
	if token_3d != null:
		var projected := _project_3d_token_to_screen(token_3d)
		if projected.x < 1000000.0 and projected.y < 1000000.0:
			card_pos = projected - Vector2(menu_size.x * 0.5, menu_size.y + 18.0)
			if card_pos.y < 60.0:
				card_pos = projected + Vector2(-menu_size.x * 0.5, 18.0)
			used_3d_projection = true
	if not used_3d_projection:
		if player_table and player_table.has_method("find_front_slot_for_card"):
			var slot: Control = player_table.find_front_slot_for_card(card)
			if slot and is_instance_valid(slot):
				var slot_rect: Rect2 = slot.get_global_rect()
				card_pos.x = slot_rect.position.x + (slot_rect.size.x - menu_size.x) * 0.5
				card_pos.y = slot_rect.position.y - menu_size.y - 4.0
				if card_pos.y < 60.0:
					card_pos.y = slot_rect.end.y + 4.0
			else:
				card_pos = vp.size * 0.5
		else:
			card_pos = vp.size * 0.5
	card_pos.x = clampf(card_pos.x, 10.0, maxf(10.0, vp.size.x - menu_size.x - 10.0))
	card_pos.y = clampf(card_pos.y, 60.0, maxf(60.0, vp.size.y - 210.0))
	menu.position = card_pos
	_set_3d_command_target_highlight(card, true)
	print("[MONSTER_MENU_OPEN] card=%s pos=%s vp=%s" % [card_label, card_pos, vp.size])

	if not menu.command_selected.is_connected(_on_monster_command):
		menu.command_selected.connect(_on_monster_command)

	_monster_command_menu = menu
	_monster_command_card = card
func _close_monster_command_menu() -> void:
	if _monster_command_card != null:
		_set_3d_command_target_highlight(_monster_command_card, false)
	if _monster_command_menu and is_instance_valid(_monster_command_menu):
		_monster_command_menu.queue_free()
	_monster_command_menu = null
	print("[MOVE_SELECT_STATE] menu_closed mode=%s card=%s" % [_lane_selection_mode, _lane_selection_card.card_name if _lane_selection_card else "null"])
	_monster_command_card = null
	# Keep selection ownership stable when closing the menu starts a garrison flow.
	_camera_orbit_frozen = bool(_garrison_context.get("active", false))
	if not _exit_modal_active:
		_camera_orbit_dragging = false
func _on_monster_command(action: String, card: CardData) -> void:
	# PHASE53_BEGIN_COMMAND
	if _core_surge_committing:return
	_clear_core_surge_selection()
	# PHASE53_END_COMMAND
	if card == null: return
	var card_label := card.get_display_name() if card.has_method("get_display_name") else card.card_name
	print("[MONSTER_COMMAND] action=%s card=%s" % [action, card_label])
	match action:
		"garrison":
			var garrison_status := _get_garrison_command_status(card)
			if not bool(garrison_status.get("ok", false)):
				_show_floating_text(str(garrison_status.get("reason_text", "当前不可驻防")), TC.WARNING, 1.2, 14)
				return
			_begin_garrison_selection(card, garrison_status)

		"attack":
			_close_monster_command_menu()
			if not battle: return
			# Phase 27I-R0-R: P02/P03 棋型怪兽攻击经棋子执行入口（保留 P03 被动与 P02 强化，不绕过 execute_card_piece_action）
			if card.piece_enabled and card.card_family == "monster" and battle.has_method("get_card_piece_status"):
				_begin_piece_selection(null, card, &"attack")
				return
			# Phase 27D: use unified command status（非棋型怪兽走原路径）
			var can: Dictionary = {"ok": false, "reason": "无法攻击"}
			if battle.has_method("get_unit_command_status"):
				can = battle.get_unit_command_status(card, "attack")
			elif battle.has_method("can_monster_attack"):
				can = battle.can_monster_attack(card)
			if not can.get("ok", false):
				_show_floating_text(str(can.get("reason_text", can.get("reason", "无法攻击"))), TC.WARNING, 1.2, 14)
				return
			_clear_attack_selection()
			_selected_attacker = card
			# Phase 27B: cell-based attack selection
			_begin_unit_attack_selection(card)
			# Also keep boss core clickable if core attack is legal
			if _boss_status_hud and is_instance_valid(_boss_status_hud) and _boss_status_hud.has_method("set_clickable"):
				var core_status: Dictionary = battle.get_core_attack_cell_status(card)
				_boss_status_hud.set_clickable(bool(core_status.get("ok", false)))

		"ascend":
			var asc_status: Dictionary = {"has_target": false, "ok": false, "target": null}
			if battle and battle.has_method("get_ascension_preview_status"):
				asc_status = battle.get_ascension_preview_status(card, context.player)
			if asc_status.get("ok", false):
				var target: CardData = asc_status.get("target")
				_close_monster_command_menu()
				if target and battle and battle.has_method("ascend_card"):
					var result: Dictionary = battle.ascend_card(card, target, context.player)
					if result.get("ok", false):
						if action_feed: action_feed.push_message(result.get("message", ""), Color(1, 0.75, 0.2))
						var dname: String = target.card_name
						if target.has_method("get_display_name"): dname = target.get_display_name()
						_add_to_this_turn("Ascend: %s" % dname, Color(1, 0.75, 0.2))
						_refresh_tables()
						check_battle_end()
					else:
						if action_feed: action_feed.push_message("Ascend failed: %s" % result.get("message", ""), TC.WARNING)
				return
			else:
				var reason: String = asc_status.get("reason", "条件不满足")
				_show_floating_text(reason, TC.WARNING, 1.0, 14)

		"move":
			# Phase 27D: pre-check move via unified status
			if battle and battle.has_method("get_unit_command_status"):
				var mcs: Dictionary = battle.get_unit_command_status(card, "move")
				if not mcs.get("ok", false):
					_show_floating_text(str(mcs.get("reason_text", "无法移动")), TC.WARNING, 1.0, 14)
					return
			_close_monster_command_menu()
			# Phase 27I-R0-R: P02/P03 棋型怪兽移动经棋子执行入口
			if card.piece_enabled and card.card_family == "monster" and battle.has_method("get_card_piece_status"):
				_begin_piece_selection(null, card, &"move")
				return
			_begin_unit_move_selection(card, battle.MOVE_SELF)

		"turn":
			if battle and battle.has_method("turn_unit_for_rear_defense"):
				var turn_result: Dictionary = battle.execute_unit_command(card, "turn") if battle.has_method("execute_unit_command") else battle.turn_unit_for_rear_defense(card)
				if turn_result.get("ok", false):
					_close_monster_command_menu()
					if action_feed:
						action_feed.push_message("回防转向完成", Color(0.6, 0.75, 1.0))
					var dname3: String = card.get_display_name() if card.has_method("get_display_name") else card.card_name
					_add_to_this_turn("Turn: %s" % dname3, Color(0.6, 0.75, 1.0))
					_play_command_economy_spend(turn_result.get("cost", 1))
					_refresh_tables()
				else:
					_show_floating_text(turn_result.get("reason", "回防失败"), TC.WARNING, 1.0, 14)
			else:
				_show_floating_text("回防指令不可用", TC.WARNING, 1.0, 14)

		"od_breach":
			if battle and battle.has_method("resolve_overdrive_core_breach"):
				var breach_result: Dictionary = battle.execute_unit_command(card, "overdrive_breach") if battle.has_method("execute_unit_command") else battle.resolve_overdrive_core_breach(card)
				if breach_result.get("ok", false):
					_close_monster_command_menu()
					if action_feed:
						action_feed.push_message("超频突击！核心受击！", Color(1.0, 0.35, 0.15))
					var dname4: String = card.get_display_name() if card.has_method("get_display_name") else card.card_name
					_add_to_this_turn("OD Breach: %s" % dname4, Color(1.0, 0.35, 0.15))
					_refresh_tables()
				else:
					_show_floating_text(breach_result.get("reason", "超频突击失败"), TC.WARNING, 1.0, 14)
			else:
				_show_floating_text("超频突击不可用", TC.WARNING, 1.0, 14)

		"effect":
			_close_monster_command_menu()
			if battle and battle.has_method("use_monster_active"):
				var eff_result: Dictionary = battle.use_monster_active(card, context.player)
				if eff_result.get("ok", false):
					if action_feed: action_feed.push_message(eff_result.get("message", ""), Color(0.4, 0.85, 1.0))
					var dname2: String = card.get_display_name() if card.has_method("get_display_name") else card.card_name
					_add_to_this_turn("Active: %s" % dname2, Color(0.4, 0.85, 1.0))
					if card_vfx: card_vfx.play_card_effect(player_table.find_front_slot_for_card(card) if player_table.has_method("find_front_slot_for_card") else null, "MONSTER", false)
					_refresh_tables()
				else:
					_show_floating_text(eff_result.get("message", "发动失败"), TC.WARNING, 1.0, 14)

		"detail":
			_close_monster_command_menu()
			if player_table and player_table.card_detail_panel:
				player_table.card_detail_panel.visible = true
				var zone_name: String = ""
				if context and context.has_method("get_od_zone_name"):
					zone_name = context.get_od_zone_name()
				player_table.card_detail_panel.show_card(card, zone_name, {})

		"cancel":
			_close_monster_command_menu()

		"skill":  # Phase 27E-R2
			if card == null or battle == null:
				return
			if not battle.has_method("get_monster_hero_skills"):
				_show_floating_text("技能系统未初始化", TC.WARNING, 1.0, 14)
				return
			var skill_snap = battle.get_monster_hero_skills()
			if skill_snap == null or not skill_snap.has_skill(card.card_id):
				_show_floating_text("该单位无可用技能", TC.WARNING, 1.0, 14)
				return
			var active_def: Dictionary = skill_snap.get_active(card.card_id)
			if active_def.is_empty():
				return
			var skill_id: StringName = StringName(str(active_def.get("id", "")))
			var query: Dictionary = battle.get_unit_skill_command_status(card, skill_id)
			if not bool(query.get("ok", false)):
				var reason_text := _skill_reason_to_chinese(str(query.get("reason_code", "")))
				_show_floating_text(reason_text, TC.WARNING, 1.5, 14)
				return
			_close_monster_command_menu()
			_clear_skill_selection(&"new_skill")
			_begin_skill_targeting(card, skill_id, query)

# ============================================================
# Phase 18A: AnimatedODGauge removed 鈥?CoreStatusPanel EngineGauge is authoritative
# ============================================================

# Phase 18A: AnimatedODGauge removed 鈥?CoreStatusPanel EngineGauge is authoritative OD display

# ============================================================
# Phase 22F-7: Card Playability State Audit
# ============================================================

## _safe_release_play_lock
func _safe_release_play_lock(reason: String = "") -> void:
	if _card_being_played:
		if reason != "":
			print("[PLAY_LOCK] release reason=%s" % reason)
		_card_being_played = false
## _log_card_play_check
func _log_card_play_check(card: CardData, source: String) -> void:
	if card == null:
		return

	var in_hand := false
	if context and context.player:
		var hand := context.player.hand
		for c in hand:
			if c == card:
				in_hand = true
				break
	var status := {"ok": false, "reason": "battle not ready"}
	if battle and battle.has_method("get_card_play_status"):
		status = battle.get_card_play_status(card)
	var abyss := false
	if context and context.has_method("is_abyss_locked"):
		abyss = context.is_abyss_locked()
	print("[CARD_PLAY_CHECK] card=%s in_hand=%s status_ok=%s reason=\"%s\" playing_lock=%s abyss_lock=%s hand=%d front=%d back=%d source=%s" % [
		card.card_id, in_hand, status.get("ok", false),
		status.get("reason", ""), _card_being_played, abyss,
		context.player.hand.size() if context and context.player else -1,
		context.player.field.size() if context and context.player else -1,
		context.player.traps.size() if context and context.player else -1,
		source
	])
## _audit_state_consistency
func _audit_state_consistency(source: String) -> void:
	if context == null or player_table == null:
		return
	var hand_data_count := context.player.hand.size()
	var hand_ui_count := 0
	if player_table.has_method("get_hand_card_count"):
		hand_ui_count = player_table.get_hand_card_count()
	var mismatch := false
	if hand_data_count != hand_ui_count:
		print("[CARD_STATE_MISMATCH] hand_count: data=%d ui=%d source=%s" % [hand_data_count, hand_ui_count, source])
		mismatch = true
	if _card_being_played:
		print("[CARD_STATE_MISMATCH] playing_lock_stuck=true source=%s" % source)
		mismatch = true
	if player_table and player_table.has_method("get_hand_playability_map") and battle and battle.has_method("get_card_play_status"):
		var pmap: Dictionary = player_table.get_hand_playability_map()
		for card_id in pmap:
			var card = pmap[card_id].get("card")
			var ui_playable: bool = pmap[card_id].get("playable", false)
			var status = battle.get_card_play_status(card)
			var actual_ok: bool = status.get("ok", false)
			if ui_playable != actual_ok:
				print("[CARD_STATE_MISMATCH] playability_drift: %s ui=%s actual=%s source=%s" % [card_id, ui_playable, actual_ok, source])
				mismatch = true
	if not mismatch:
		print("[CARD_STATE_AUDIT] ok: hand_data=%d ui=%d lock=%s source=%s" % [hand_data_count, hand_ui_count, _card_being_played, source])
## _log_formation_check
func _log_formation_check(row_name: String, cards: Array, slot_map: Dictionary) -> void:
	var valid_count := 0
	for c in cards:
		if c != null:
			valid_count += 1
	var details: Array = []
	for i in cards.size():
		if cards[i] != null and slot_map.has(i):
			var vi: int = slot_map[i]
			var socket_name := "%s_%d" % [row_name, vi]
			var pos := _get_3d_slot_pos(_row_to_side(row_name), _row_to_zone(row_name), vi)
			details.append("L%d->V%d@%s(%.2f,%.2f)" % [i, vi, socket_name, pos.x, pos.z])
	print("[FORMATION_CHECK] row=%s cards=%d map=%s positions=%s" % [row_name, valid_count, ", ".join(details) if details.size() > 0 else "(empty)", details])
func _row_to_side(row: String) -> String:
	if row.begins_with("P_"): return "player"
	return "boss"
func _row_to_zone(row: String) -> String:
	if row.find("FRONT") > 0: return "front"
	return "back"

# ============================================================
# Phase 24B-R2-R: Diagnostic — locate blue elongated panel / grey frame artifacts
# ============================================================
func _diagnose_visible_controls() -> void:
	if not DEBUG_DIAG_VISIBLE_CONTROLS:
		return
	print("[DIAGNOSTIC] === Visible Control Nodes (>20x20) ===")
	var root := get_tree().root
	_print_visible_controls(root, "")

func _print_visible_controls(node: Node, indent: String) -> void:
	if node is Control:
		var ctrl := node as Control
		if ctrl.visible and ctrl.size.x > 20 and ctrl.size.y > 20:
			var pos := ctrl.global_position
			var sz := ctrl.size
			var rc := ctrl.get_global_rect()
			var has_bg := false
			if ctrl is Panel:
				has_bg = true
			var style_mod := Color(1,1,1,1)
			if "modulate" in ctrl:
				style_mod = ctrl.modulate
			if "self_modulate" in ctrl:
				style_mod = ctrl.self_modulate
			var name_str: String = str(ctrl.name)
			var parent_node: Node = ctrl.get_parent()
			var parent_str: String = str(parent_node.name) if parent_node != null else "ROOT"
			# Only print nodes that might be causing visual issues
			var is_suspicious := has_bg or sz.x > 200 or sz.y > 200 or pos.x > 900
			var marker := " <-- SUSPICIOUS" if is_suspicious else ""
			print("[DIAG] %s/%s rect=(%.0f,%.0f,%.0f,%.0f) size=(%.0f,%.0f) z=%d bg=%s mod=%s%s" % [
				parent_str, name_str,
				rc.position.x, rc.position.y, rc.position.x + rc.size.x, rc.position.y + rc.size.y,
				sz.x, sz.y,
				ctrl.z_index, has_bg, style_mod, marker
			])
	for child in node.get_children():
		_print_visible_controls(child, indent)
	print("[DIAGNOSTIC] === End Diagnostic ===")


## Existing turn orchestration, shared by the live scene and behavioral smokes.
func _start_player_turn_rules(initial: bool = false) -> void:
	_ensure_siege_presenter()
	if initial:
		turn.start_turn()
		# Phase 27D: initialize player command economy at game start
		if battle and battle.has_method("reset_command_economy_for_turn"):
			battle.reset_command_economy_for_turn("player")
		if battle and battle.tactical_siege_rules.is_enabled():
			battle.resolve_foundation_turn_begin(&"player")
	else:
		turn.start_turn()
		# Phase D2: the incremented turn serial now identifies the player's complete
		# recovery turn; activate it before draw or any new player input.
		if battle and battle.has_method("resolve_foundation_turn_begin"):
			var _player_foundation_begin: Dictionary = battle.resolve_foundation_turn_begin(&"player")
		# Phase 26C: 重置玩家回合核心指令
		if battle and battle.has_method("reset_player_turn_core_command"):
			battle.reset_player_turn_core_command()
		# Phase 27D: reset player economy for new turn
		if battle and battle.has_method("reset_command_economy_for_turn"):
			battle.reset_command_economy_for_turn("player")
		# Phase 27I-R1: 下个玩家回合开始清理正常到期的战车连接（来源 set_turn < current_turn）
		if battle and battle.has_method("_rook_clear_expired_for_new_turn"):
			battle._rook_clear_expired_for_new_turn(int(context.get_turn_number()) if context else 0)
	if battle:
		battle._on_player_terrain_window_begin()
	if battle and battle.has_method("_on_player_siege_window_begin"):
		battle._on_player_siege_window_begin()
	_refresh_siege_intent_view()


func _run_boss_turn_rules_before_tactics() -> Dictionary:
	# A duplicate scene boundary must not replenish the spent siege/AI budget.
	if battle and context.boss_terrain_intent.enabled:
		if _boss_terrain_boundary_turn == context.turn_count:
			return {"ok": false, "reason_code": &"boss_boundary_already_completed"}
		_boss_terrain_boundary_turn = context.turn_count
	if battle and battle.tactical_siege_rules.is_enabled() and context._boss_siege_tactical_window_turn == context.turn_count:
		return battle.resolve_boss_siege_intent()
	# Step 3: Execute boss actions
	# Phase 27F-R1: Reset existing boss unit state + economy BEFORE intent
	if battle and battle.has_method("reset_unit_turn_state_for_side"):
		battle.reset_unit_turn_state_for_side("boss")
	if battle and battle.has_method("reset_command_economy_for_turn"):
		battle.reset_command_economy_for_turn("boss")
	context.reset_boss_turn_stable_combat_od()
	if context.enemy.has_method("execute_intent"):
		context.enemy.execute_intent(context.player)
	else:
		context.enemy.act(context.player)  # fallback
	if context.player.hp <= 0 or context.enemy.hp <= 0:
		return {"ok": false, "reason_code": &"boss_intent_terminal"}

	if battle and battle.has_method("_on_boss_siege_tactical_start"):
		var result: Dictionary = battle._on_boss_siege_tactical_start()
		battle._on_boss_terrain_tactical_start()
		_refresh_siege_intent_view()
		if result.get("ok", false):
			_siege_presenter.present_committed(_siege_view(result))
		return result
	return {"ok": false, "reason_code": &"siege_disabled"}


## Phase E presentation uses the existing single interaction session.
var _siege_presenter: Control

func _ensure_siege_presenter() -> void:
	if is_instance_valid(_siege_presenter):
		return
	_siege_presenter = preload("res://scenes/presentation/tactical_siege_presenter.gd").new()
	_siege_presenter.name = "TacticalSiegePresenter"
	_siege_presenter.impact_requested.connect(func(cue: String):
		var audio = _am()
		if audio != null:
			audio.play_sfx(cue))
	$MonsterSummonConfirmationLayer.add_child(_siege_presenter)

func _siege_view(status: Dictionary) -> Dictionary:
	var view := status.duplicate(true)
	view.reduced_motion = _is_reduced_motion_presentation()
	if not view.has("source_cell") and int(status.get("actor_runtime_id", 0)) != 0:
		var actor := _find_field_unit_by_runtime_id(int(status.actor_runtime_id))
		if actor != null:
			view.source_cell = battle.get_unit_cell(actor)
	if view.has("source_cell"):
		view.source_screen_position = _project_tactical_cell_to_screen(view.source_cell)
	var target: Dictionary = status.get("resolved_target", status.get("target", {}))
	view.target_screen_position = _project_tactical_cell_to_screen(target.get("cell", MONSTER_DRAG_INVALID_CELL))
	if is_instance_valid(_tactical_structure_presenter):
		for node in _tactical_structure_presenter.find_children("*", "Area3D", true, false):
			var ref: Dictionary = node.get_meta("target_ref", {})
			if ref.get("target_kind") != target.get("target_kind") or ref.get("structure_id") != target.get("structure_id"):
				continue
			if target.get("target_kind") == &"structure_module" and ref.get("module_id") != target.get("module_id"):
				continue
			view.target_world_position = node.global_position
			view.target_screen_position = _project_world_position_to_screen(node.global_position)
			var shape: CollisionShape3D = node.get_node_or_null("SafeBounds")
			if shape != null and shape.shape is BoxShape3D and target.get("target_kind") == &"structure_module":
				var half: Vector3 = shape.shape.size * 0.5
				var axis := Vector3(half.x, 0, 0) if half.x > half.z else Vector3(0, 0, half.z)
				view.edge_world_points = PackedVector3Array([node.global_position - axis, node.global_position + axis])
				view.edge_points = PackedVector2Array([_project_world_position_to_screen(node.global_position - axis), _project_world_position_to_screen(node.global_position + axis)])
			break
	if view.has("target_world_position"):
		view.target_screen_position = _project_world_position_to_screen(view.target_world_position)
	if view.has("edge_world_points"):
		var points: PackedVector3Array = view.edge_world_points
		view.edge_points = PackedVector2Array([_project_world_position_to_screen(points[0]), _project_world_position_to_screen(points[1])])
	var secondary: Dictionary = status.get("secondary_target", {})
	if not secondary.is_empty():
		view.secondary_screen_position = _project_tactical_cell_to_screen(secondary.get("cell", MONSTER_DRAG_INVALID_CELL))
	return view

func _refresh_siege_intent_view() -> void:
	if not is_instance_valid(_siege_presenter) or not is_instance_valid(battle):
		return
	var status: Dictionary = battle.get_boss_siege_intent_status()
	var view := _siege_view(status) if status.get("active", false) else {}
	if not view.is_empty():
		view.label = "B-07 预备攻城 · %s墙 · 耐久 -1" % _siege_edge_name(status.target.get("edge", &""))
	_siege_presenter.show_intent(view)

func _siege_edge_name(edge: StringName) -> String:
	return {&"north": "北", &"east": "东", &"south": "南", &"west": "西"}.get(edge, "目标")

func _siege_summary(status: Dictionary) -> String:
	var target: Dictionary = status.get("resolved_target", {})
	var name := _siege_edge_name(target.get("edge", &"")) + "墙" if target.get("target_kind") == &"structure_module" else "结构核心"
	var current := int(target.get("integrity_current", 0))
	var summary := "%s %d→%d" % [name, current, maxi(0, current - int(status.get("structure_steps", 0)))]
	if status.get("mode") == &"p18_siege":
		var secondary: Dictionary = status.get("secondary_target", {})
		summary = "P18 攻城 · " + summary
		if secondary.get("target_kind") == &"unit":
			summary += " → 驻防 HP -%d" % int(status.get("unit_damage", 0))
		else:
			summary += " → 核心耐久 %d" % int(status.get("secondary_integrity_after", 0))
		summary += "\n%d 段命中 · 原卡牌费用" % (status.get("hits", []) as Array).size()
	else:
		summary += "\n消耗 %d 指令 · 不伤驻防单位" % int(status.get("costs", {}).get("command", 0))
	return summary

func _show_siege_rejection(status: Dictionary) -> void:
	var reason: StringName = status.get("reason_code", &"")
	var text: String = {&"siege_disabled": "攻城模式未启用", &"siege_profile_invalid": "此攻城能力当前不可用",
		&"siege_preview_stale": "局面已变化，请重新选择目标", &"siege_target_stale": "目标已变化，请重新选择",
		&"siege_guard_priority": "需先处理守卫", &"siege_target_friendly": "不能攻击己方结构",
		&"siege_out_of_reach": "目标超出攻击范围", &"siege_edge_not_facing_source": "无法从此方向攻击这面墙"}.get(reason, status.get("reason_text", status.get("reason", "当前无法攻城，请重新选择目标")))
	if action_feed:
		action_feed.push_message(text, TC.WARNING, "", 2.0)

func _stage_siege_attack(actor: CardData, target: Variant) -> bool:
	var command: Dictionary = battle.get_unit_command_status(actor, "attack", target)
	var status: Dictionary = command.get("siege_plan", command)
	if not command.get("ok", false):
		_show_siege_rejection(command)
		return false
	if not status.get("ok", false):
		_show_siege_rejection(status)
		return false
	_cancel_lane_selection(&"siege_target_selected")
	_monster_drag_generation += 1
	_monster_drag_session = {"active": true, "intent": &"siege_attack", "state": MONSTER_SUMMON_PENDING_CONFIRM,
		"generation": _monster_drag_generation, "card": actor, "candidate_target": status.requested_target.duplicate(true),
		"locked_preview_fact": status.duplicate(true), "pending_confirmation": true,
		"source_screen_position": _project_tactical_cell_to_screen(battle.get_unit_cell(actor)), "camera_was_frozen": _camera_orbit_frozen}
	_camera_orbit_frozen = true
	_show_siege_pending(status)
	return true

func _show_siege_pending(status: Dictionary) -> void:
	_ensure_siege_presenter()
	var view := _siege_view(status)
	view.source_screen_position = _monster_drag_session.get("source_screen_position", Vector2.INF) if _monster_drag_session.get("intent") == &"siege_attack" else _monster_source_screen_anchor()
	view.intent_kind = _monster_drag_session.get("intent", &"")
	view.legal = true
	view.candidate_target = _monster_drag_session.get("candidate_target", {}).duplicate(true)
	_siege_presenter.show_preview(view)
	_monster_summon_interaction_presenter.show_card_pending(view, _siege_summary(status), "确认攻城", "重新选择", _is_reduced_motion_presentation())
	# Use the existing buttons. Details are hidden while this modal session owns input.
	if is_instance_valid(_structure_interaction_presenter):
		_structure_interaction_presenter.close_pinned()

func _confirm_siege_selection() -> Dictionary:
	if _monster_summon_state() != MONSTER_SUMMON_PENDING_CONFIRM:
		return {"ok": false, "reason_code": &"not_pending"}
	var unit_mode: bool = _monster_drag_session.get("intent") == &"siege_attack"
	var card: CardData = _monster_drag_session.get("card")
	var target: Dictionary = _monster_drag_session.get("candidate_target", {})
	var locked: Dictionary = _monster_drag_session.get("siege_status", _monster_drag_session.get("locked_preview_fact", {}))
	var options := {"expected_siege_status": locked.duplicate(true)}
	var command_target: Variant = _find_field_unit_by_runtime_id(int(target.get("unit_runtime_id", 0))) if target.get("target_kind") == &"unit" else target
	_monster_drag_session.state = MONSTER_SUMMON_COMMITTING
	var result: Dictionary = battle.execute_unit_command(card, "attack", command_target, options) if unit_mode else battle.commit_p18_siege_cast(card, target, options)
	if not result.get("ok", false):
		_monster_drag_session.state = MONSTER_SUMMON_PENDING_CONFIRM
		_show_siege_rejection(result)
		_reselect_siege_selection()
		return result
	var view := _siege_view(result)
	if not view.has("source_screen_position"):
		view.source_screen_position = _monster_drag_session.get("source_screen_position", Vector2.INF)
	var source_ref := _monster_drag_session.get("card_ui_ref") as WeakRef
	var source := source_ref.get_ref() as CardUI if source_ref != null else null
	if source != null and is_instance_valid(source):
		source.accept_board_drop()
	_cleanup_monster_drag_summon(&"siege_success", true)
	_refresh_tables()
	_siege_presenter.present_committed(view)
	if action_feed:
		action_feed.push_message(_siege_summary(locked), TC.INFO, "", 2.0)
	return result

func _reselect_siege_selection() -> void:
	if _monster_drag_session.get("intent") != &"siege_attack":
		_begin_card_cast_reselect()
		return
	_monster_drag_session.state = MONSTER_SUMMON_RESELECTING
	_monster_drag_session.pending_confirmation = false
	_monster_drag_session.candidate_target = {}
	_monster_drag_session.locked_preview_fact = {}
	_monster_summon_interaction_presenter.clear()
	_clear_siege_presentation(&"reselect")
	var actor: CardData = _monster_drag_session.card
	var cells: Array[Vector2i] = []
	for target: Dictionary in battle.get_legal_siege_targets(actor):
		if target.cell not in cells:
			cells.append(target.cell)
	_monster_drag_session.legal_cells = cells
	if is_instance_valid(_tactical_presenter):
		_tactical_presenter.show_cell_selection(LANE_SELECT_ATTACK, &"player", battle.get_unit_cell(actor), cells, battle.get_occupied_cells(), {})

func _clear_siege_presentation(reason: StringName) -> void:
	if is_instance_valid(_card_target_guidance):
		_card_target_guidance.clear()
	if is_instance_valid(_terrain_raise_presenter):
		_terrain_raise_presenter.clear(reason)
	if is_instance_valid(_repair_presenter):
		_repair_presenter.clear(reason)
	if is_instance_valid(_siege_presenter):
		_siege_presenter.clear(reason)
		if reason not in [&"exit_tree", &"battle_end", &"battle_reset"]:
			_refresh_siege_intent_view()

func _p18_siege_hover(hit: Dictionary, pointer: Vector2) -> Dictionary:
	var card: CardData = _monster_drag_session.get("card")
	if card == null or card.card_id != "P18" or not battle.tactical_siege_rules.is_enabled():
		return {}
	var ref: Dictionary = _guided_card_target(hit, pointer).get("target_ref", {})
	if ref.get("target_kind") != &"structure_module":
		return {}
	var status: Dictionary = battle.get_p18_siege_cast_status(card, ref)
	var fact := _make_card_cast_preview_fact(pointer, pointer, ref, status.get("ok", false), status.get("reason_code", &""))
	fact.siege_status = status.duplicate(true)
	fact.siege_mode = true
	_monster_drag_session.candidate_target = ref.duplicate(true)
	if status.get("ok", false):
		_ensure_siege_presenter()
		_siege_presenter.show_preview(_siege_view(status))
	else:
		_clear_siege_presentation(&"invalid_hover")
	_monster_summon_interaction_presenter.show_card_drag(fact, _is_reduced_motion_presentation())
	return {"ok": status.get("ok", false), "reason_code": status.get("reason_code"), "preview_fact": fact}

func _dispatch_siege_hit(hit: Dictionary) -> bool:
	if _monster_summon_state() == MONSTER_SUMMON_RESELECTING and _monster_drag_session.get("card") != null and _monster_drag_session.card.card_id == "P23":
		var hover := _p23_terrain_raise_hover(hit, get_viewport().get_mouse_position())
		var source_ref := _monster_drag_session.get("card_ui_ref") as WeakRef
		if hover.get("ok", false) and source_ref != null:
			_stage_card_cast_candidate(source_ref.get_ref(), hover.preview_fact)
		return true
	var kind: StringName = hit.get("target_kind", &"")
	var ref: Dictionary = hit.get("target_ref", {})
	if kind not in [&"structure_core", &"structure_module"]:
		return false
	if _monster_drag_session.get("intent") == &"siege_attack":
		if _monster_summon_state() == MONSTER_SUMMON_RESELECTING:
			_stage_siege_attack(_monster_drag_session.card, ref)
		return true
	if _monster_summon_state() == MONSTER_SUMMON_RESELECTING and _is_card_cast_drag_intent(_monster_drag_session.get("intent", &"")):
		var hover := _p22_repair_hover(hit, get_viewport().get_mouse_position())
		if hover.is_empty():
			hover = _p18_siege_hover(hit, get_viewport().get_mouse_position())
		var source_ref := _monster_drag_session.get("card_ui_ref") as WeakRef
		if hover.get("ok", false) and source_ref != null:
			_stage_card_cast_candidate(source_ref.get_ref(), hover.preview_fact)
		return not hover.is_empty()
	if _is_piece_selection_active() and _piece_context.get("action_id") == &"attack" and battle.tactical_siege_rules.is_enabled():
		_stage_siege_attack(_piece_context.card, ref)
		return true
	if _lane_selection_mode == LANE_SELECT_ATTACK and battle.tactical_siege_rules.is_enabled():
		_stage_siege_attack(_lane_selection_card, ref)
		return true
	return false


func _stage_covered_attack_if_needed(actor: CardData, target: CardData) -> bool:
	var status: Dictionary = battle.get_unit_command_status(actor, "attack", target)
	if status.get("siege_plan", {}).is_empty():
		return false
	_stage_siege_attack(actor, target)
	return true

func _show_p18_siege_choices() -> void:
	var card: CardData = _monster_drag_session.get("card")
	if card == null or card.card_id != "P18" or not battle.tactical_siege_rules.is_enabled():
		return
	var cells: Array[Vector2i] = []
	var board: Variant = context.tactical_structure_board_state
	for module: Dictionary in board.get_snapshot().modules.values():
		var cell: Vector2i = board.get_snapshot().structures[module.structure_id].cell
		var ref: Dictionary = board.make_module_target_ref(cell, module.edge, battle.get_cell_state(cell).revision)
		if battle.get_p18_siege_cast_status(card, ref).get("ok", false) and cell not in cells:
			cells.append(cell)
	_monster_drag_session.legal_cells = cells
	if is_instance_valid(_tactical_presenter):
		_tactical_presenter.show_cell_selection(LANE_SELECT_ATTACK, &"player", MONSTER_DRAG_INVALID_CELL, cells, battle.get_occupied_cells(), {})

func _update_siege_screen_geometry() -> void:
	_refresh_back_row_readability()
	_refresh_skill_selection_guidance()
	_refresh_boss_terrain_threat_view()
	_refresh_card_target_guidance()
	if is_instance_valid(_terrain_raise_presenter):
		var state: Dictionary = _terrain_raise_presenter.get_debug_snapshot()
		if state.preview_active and not state.preview.has("reason_text"):
			_terrain_raise_presenter.show_preview(_terrain_raise_view(state.preview))
		if not state.committed.is_empty():
			_terrain_raise_presenter.update_committed_geometry(_terrain_raise_view(state.committed))
	if is_instance_valid(_repair_presenter):
		var repair_debug: Dictionary = _repair_presenter.get_debug_snapshot()
		if repair_debug.preview_active and not repair_debug.preview.has("reason_text"):
			_repair_presenter.show_preview(_siege_view(repair_debug.preview))
		if not repair_debug.committed.is_empty():
			_repair_presenter.update_committed_geometry(_siege_view(repair_debug.committed))
	if not is_instance_valid(_siege_presenter):
		return
	# Only reproject cached value snapshots. No authority query or rule mutation per frame.
	var debug: Dictionary = _siege_presenter.get_debug_snapshot()
	if debug.get("preview_active", false):
		_siege_presenter.show_preview(_siege_view(debug.preview))
	if not debug.get("intent", {}).is_empty():
		_siege_presenter.show_intent(_siege_view(debug.intent))
	if not debug.get("committed", {}).is_empty():
		_siege_presenter.update_committed_geometry(_siege_view(debug.committed))


## F1 repair shares the original drag session, modal buttons and card payment.
var _repair_presenter: Control

func _ensure_repair_presenter() -> void:
	if is_instance_valid(_repair_presenter):
		return
	_repair_presenter = preload("res://scenes/presentation/tactical_repair_presenter.gd").new()
	_repair_presenter.name = "TacticalRepairPresenter"
	_repair_presenter.impact_requested.connect(func(cue: String):
		var audio = _am()
		if audio != null:
			audio.play_sfx(cue))
	$MonsterSummonConfirmationLayer.add_child(_repair_presenter)

func _p22_repair_hover(hit: Dictionary, pointer: Vector2) -> Dictionary:
	var card: CardData = _monster_drag_session.get("card")
	if card == null or card.card_id != "P22":
		return {}
	var guided := _guided_card_target(hit, pointer)
	var ref: Dictionary = guided.get("target_ref", {})
	var status: Dictionary = battle.get_p22_repair_cast_status(card, ref)
	var fact := _make_card_cast_preview_fact(pointer, pointer, ref, status.get("ok", false), status.get("reason_code", &""))
	fact.repair_mode = true
	fact.repair_status = status.duplicate(true)
	fact.confirmation_policy = &"mandatory"
	_monster_drag_session.candidate_target = ref.duplicate(true)
	_ensure_repair_presenter()
	if status.get("ok", false):
		_repair_presenter.show_preview(_siege_view(status))
	else:
		var reason: String = {&"repair_module_required": "请对准具体墙面，核心不能修复", &"repair_already_full": "这段墙体耐久已满", &"structure_module_destroyed": "城墙已毁，不能通过修补重建", &"repair_target_hostile": "只能修复己方墙体", &"repair_content_not_implemented": "维修实验未启用"}.get(status.get("reason_code"), "此目标当前不可修复，请重新选墙")
		_repair_presenter.show_preview({"target_screen_position": pointer, "reason_text": reason})
	_monster_summon_interaction_presenter.show_card_drag(fact, _is_reduced_motion_presentation())
	return {"ok": status.get("ok", false), "reason_code": status.get("reason_code"), "preview_fact": fact}

func _stage_repair_cast(card_ui: CardUI, target_ref: Dictionary) -> Dictionary:
	var hover := _p22_repair_hover({"target_ref": target_ref}, get_viewport().get_mouse_position())
	if not hover.get("ok", false):
		return hover
	return _stage_card_cast_candidate(card_ui, hover.preview_fact)

func _show_repair_pending(status: Dictionary) -> void:
	_ensure_repair_presenter()
	var view := _siege_view(status)
	view.legal = true
	view.candidate_target = _monster_drag_session.candidate_target.duplicate(true)
	view.source_screen_position = _monster_source_screen_anchor()
	var title := "%s墙 · 耐久 %d→%d\n热量 +%d · OD +%d · HP -%d\n%d 段修复，达到上限后不再增加" % [_siege_edge_name(status.resolved_target.edge), status.before.integrity_current, status.wall_after, status.costs.load, status.costs.od_gain, status.costs.hp, status.hits.size()]
	if status.foundation.get("foundation_state") == &"undermined":
		title += "\n地基仍失稳 · 恢复窗口剩余 %d 个己方回合（不延长）" % int(status.foundation.get("recovery_owner_turns_remaining", 0))
	_repair_presenter.show_preview(view)
	_monster_summon_interaction_presenter.show_card_pending(view, title, "确认修复", "重新选择", _is_reduced_motion_presentation())
	if is_instance_valid(_structure_interaction_presenter):
		_structure_interaction_presenter.close_pinned()

func _confirm_repair_cast() -> Dictionary:
	if _monster_summon_state() != MONSTER_SUMMON_PENDING_CONFIRM:
		return {"ok": false, "reason_code": &"not_pending"}
	var card: CardData = _monster_drag_session.get("card")
	var source_ref := _monster_drag_session.get("card_ui_ref") as WeakRef
	var source := source_ref.get_ref() as CardUI if source_ref != null else null
	if source == null or not is_instance_valid(source) or source.card_data != card:
		_begin_card_cast_reselect()
		return {"ok": false, "reason_code": &"repair_card_unavailable"}
	_monster_drag_session.state = MONSTER_SUMMON_COMMITTING
	var result: Dictionary = battle.commit_p22_repair_cast(card, _monster_drag_session.candidate_target, {"expected_repair_status": _monster_drag_session.repair_status})
	if not result.get("ok", false):
		_monster_drag_session.state = MONSTER_SUMMON_PENDING_CONFIRM
		if action_feed:
			action_feed.push_message("局面已变化，请重新选择己方受损墙体", TC.WARNING, "", 2.0)
		_begin_card_cast_reselect()
		return result
	var view := _siege_view(result)
	source.accept_board_drop()
	_cleanup_monster_drag_summon(&"repair_success", true)
	_refresh_tables()
	_repair_presenter.present_committed(view)
	return result


## F2 terrain raise shares the original drag session, modal buttons and card payment.
var _terrain_raise_presenter: Control

func _ensure_terrain_raise_presenter() -> void:
	if is_instance_valid(_terrain_raise_presenter):
		return
	_terrain_raise_presenter = preload("res://scenes/presentation/tactical_terrain_raise_presenter.gd").new()
	_terrain_raise_presenter.name = "TacticalTerrainRaisePresenter"
	_terrain_raise_presenter.impact_requested.connect(func(cue: String):
		var audio = _am()
		if audio != null:
			audio.play_sfx(cue))
	$MonsterSummonConfirmationLayer.add_child(_terrain_raise_presenter)

func _p23_terrain_raise_hover(hit: Dictionary, pointer: Vector2) -> Dictionary:
	var card: CardData = _monster_drag_session.get("card")
	if card == null or card.card_id != "P23":
		return {}
	_refresh_terrain_raise_legal_cells(card)
	var guided := _guided_card_target(hit, pointer)
	var cell: Variant = guided.get("board_cell", guided.get("target_ref", {}).get("cell", null))
	# Legacy building card tokens can cover the terrain/structure collider.
	# Resolve their authoritative structure cell just as construction does.
	if not cell is Vector2i:
		cell = _structure_cell_from_drag_hit(guided)
	var ref: Dictionary = battle.make_terrain_raise_target_ref(cell) if cell is Vector2i else {}
	var status: Dictionary = battle.get_p23_terrain_raise_cast_status(card, ref)
	var fact := _make_card_cast_preview_fact(pointer, pointer, ref, status.get("ok", false), status.get("reason_code", &""))
	fact.terrain_raise_mode = true
	fact.terrain_raise_status = status.duplicate(true)
	fact.confirmation_policy = &"mandatory"
	_monster_drag_session.candidate_target = ref.duplicate(true)
	_ensure_terrain_raise_presenter()
	if status.get("ok", false):
		_terrain_raise_presenter.show_preview(_terrain_raise_view(status))
	else:
		var reason: String = {&"terrain_raise_cell_required": "请选择己方地块或建筑", &"terrain_raise_height_cap": "地块已达到最高高度 H2", &"terrain_raise_occupied": "不能抬升未驻防单位脚下的地块", &"terrain_raise_hostile_structure": "只能抬升己方地块", &"terrain_raise_outside_build_zone": "请选择己方后两排建设区", &"terrain_raise_disabled": "升地演练未启用"}.get(status.get("reason_code"), "此地块暂不可抬升，请重新选择")
		_terrain_raise_presenter.show_preview({"target_screen_position": pointer, "reason_text": reason})
	_monster_summon_interaction_presenter.show_card_drag(fact, _is_reduced_motion_presentation())
	return {"ok": status.get("ok", false), "reason_code": status.get("reason_code"), "preview_fact": fact}

func _stage_terrain_raise_cast(card_ui: CardUI, target_ref: Dictionary) -> Dictionary:
	var hover := _p23_terrain_raise_hover({"target_ref": target_ref}, get_viewport().get_mouse_position())
	if not hover.get("ok", false):
		return hover
	return _stage_card_cast_candidate(card_ui, hover.preview_fact)

func _show_terrain_raise_pending(status: Dictionary) -> void:
	_ensure_terrain_raise_presenter()
	var view := _terrain_raise_view(status)
	view.legal = true
	view.candidate_target = _monster_drag_session.candidate_target.duplicate(true)
	view.source_screen_position = _monster_source_screen_anchor()
	var title := "地块 (%d,%d) · H%d → H%d\n热量 +%d · OD +%d · HP -%d\n%d 段升高，H2 封顶" % [status.resolved_target.cell.x, status.resolved_target.cell.y, status.before.height, status.height_after, status.costs.load, status.costs.od_gain, status.costs.hp, status.hits.size()]
	var foundation: Dictionary = status.resolved_target.get("structure", {})
	if foundation.get("foundation_state") == &"undermined":
		title += "\n地基将恢复稳定 · 墙体耐久不变"
	var strategy_hint := _terrain_raise_strategy_hint(status)
	if not strategy_hint.is_empty():
		title += "\n" + strategy_hint
	_terrain_raise_presenter.show_preview(view)
	_monster_summon_interaction_presenter.show_card_pending(view, title, "确认升地", "重新选择", _is_reduced_motion_presentation())
	if is_instance_valid(_structure_interaction_presenter):
		_structure_interaction_presenter.close_pinned()

func _confirm_terrain_raise_cast() -> Dictionary:
	if _monster_summon_state() != MONSTER_SUMMON_PENDING_CONFIRM:
		return {"ok": false, "reason_code": &"not_pending"}
	var card: CardData = _monster_drag_session.get("card")
	var source_ref := _monster_drag_session.get("card_ui_ref") as WeakRef
	var source := source_ref.get_ref() as CardUI if source_ref != null else null
	if source == null or not is_instance_valid(source) or source.card_data != card:
		_begin_card_cast_reselect()
		return {"ok": false, "reason_code": &"terrain_raise_card_unavailable"}
	_monster_drag_session.state = MONSTER_SUMMON_COMMITTING
	var result: Dictionary = battle.commit_p23_terrain_raise_cast(card, _monster_drag_session.candidate_target, {"expected_terrain_raise_status": _monster_drag_session.terrain_raise_status})
	if not result.get("ok", false):
		_monster_drag_session.state = MONSTER_SUMMON_PENDING_CONFIRM
		if action_feed:
			action_feed.push_message("局面已变化，请重新选择己方地块", TC.WARNING, "", 2.0)
		_begin_card_cast_reselect()
		return result
	var view := _terrain_raise_view(result)
	source.accept_board_drop()
	_cleanup_monster_drag_summon(&"terrain_raise_success", true)
	_refresh_tables()
	_terrain_raise_presenter.present_committed(view)
	return result


func _terrain_raise_strategy_hint(status: Dictionary) -> String:
	if not bool(status.get("ok", false)) or battle == null or battle.tactical_structure_rules == null:
		return ""
	var structure: Dictionary = status.get("resolved_target", {}).get("structure", {})
	if structure.get("profile_id", &"") == &"p08_fortification":
		return ""
	var heights: Array[int] = battle.tactical_structure_rules.get_allowed_heights(&"p08_fortification")
	if not heights.is_empty() and not int(status.get("height_after", -1)) in heights:
		return "升高后此格不能新建【铁誓烽堡】；如需建堡，请先建造。"
	return ""


func _terrain_raise_view(status: Dictionary) -> Dictionary:
	var view := status.duplicate(true)
	view.reduced_motion = _is_reduced_motion_presentation()
	view.legal_points = PackedVector2Array()
	for cell: Vector2i in _monster_drag_session.get("terrain_raise_legal_cells", []):
		var point := _project_tactical_cell_to_screen(cell)
		if point.is_finite(): view.legal_points.append(point)
	view.target_screen_position = _project_tactical_cell_to_screen(status.get("resolved_target", {}).get("cell", MONSTER_DRAG_INVALID_CELL))
	return view


func _refresh_terrain_raise_legal_cells(card: CardData) -> void:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in battle.context.get_tactical_cell_states():
		if battle.get_p23_terrain_raise_cast_status(card, battle.make_terrain_raise_target_ref(cell)).get("ok", false):
			cells.append(cell)
	_monster_drag_session.terrain_raise_legal_cells = cells


var _card_target_guidance: Control
var _boss_terrain_presenter: Control
var _boss_terrain_boundary_turn := -1

func _refresh_boss_terrain_threat_view() -> void:
	if not is_instance_valid(battle) or context == null: return
	var status: Dictionary = battle.get_boss_terrain_intent_status()
	if not is_instance_valid(_boss_terrain_presenter):
		if status.get("status", &"none") == &"none": return
		_boss_terrain_presenter = preload("res://scenes/presentation/boss_terrain_threat_presenter.gd").new()
		_boss_terrain_presenter.name = "BossTerrainThreatPresenter"
		$MonsterSummonConfirmationLayer.add_child(_boss_terrain_presenter)
	var point := _project_tactical_cell_to_screen(status.cell) if status.get("cell") is Vector2i else Vector2.INF
	_boss_terrain_presenter.present(status, point, _is_monster_summon_interaction_active())

func _guided_card_target(hit: Dictionary, pointer: Vector2) -> Dictionary:
	if is_instance_valid(_card_target_guidance):
		var guided: Dictionary = _card_target_guidance.target_at(pointer)
		if not guided.is_empty(): return guided
	return hit

func _refresh_card_target_guidance() -> void:
	var card: CardData = _monster_drag_session.get("card")
	if card == null or card.card_id not in ["P18", "P22", "P23"] or _monster_summon_state() not in [MONSTER_SUMMON_DRAGGING, MONSTER_SUMMON_RESELECTING]:
		if is_instance_valid(_card_target_guidance): _card_target_guidance.clear()
		return
	if not is_instance_valid(_card_target_guidance):
		_card_target_guidance = preload("res://scenes/presentation/card_target_guidance.gd").new()
		_card_target_guidance.name = "CardTargetGuidance"
		$MonsterSummonConfirmationLayer.add_child(_card_target_guidance)
	var targets: Array[Dictionary] = []
	var rejected: Dictionary = {}
	var message := "升地：拖到绿色地块标记，松手后确认；右键或 Escape 取消"
	if card.card_id == "P23":
		for cell: Vector2i in battle.context.get_tactical_cell_states():
			var ref := battle.make_terrain_raise_target_ref(cell)
			var status := battle.get_p23_terrain_raise_cast_status(card, ref)
			if not status.get("ok", false):
				rejected[StringName(status.get("reason_code", &"unknown"))] = true
				continue
			var point := _project_tactical_cell_to_screen(cell)
			if point.is_finite():
				targets.append({"rect": Rect2(point - Vector2(43, 17), Vector2(86, 34)), "anchor": point,
					"label": "升地 H%d→%d" % [status.before.height, status.height_after],
					"hit": {"ok": true, "target_kind": &"tactical_cell", "board_cell": cell}})
	else:
		message = "修补：拖到绿色墙面标记，无需瞄准细墙边；松手后确认" if card.card_id == "P22" else "贯穿：拖到绿色敌墙标记；其他攻击仍使用原施放区域"
		for structure: Dictionary in battle.context.tactical_structure_board_state.get_snapshot().structures.values():
			var cell: Vector2i = structure.cell
			for edge: StringName in [&"north", &"east", &"south", &"west"]:
				var ref: Dictionary = battle.context.tactical_structure_board_state.make_module_target_ref(cell, edge, battle.get_cell_state(cell).revision)
				var status: Dictionary = battle.get_p22_repair_cast_status(card, ref) if card.card_id == "P22" else battle.get_p18_siege_cast_status(card, ref)
				if not status.get("ok", false):
					rejected[StringName(status.get("reason_code", &"unknown"))] = true
					continue
				var view := _siege_view(status)
				var point: Vector2 = view.target_screen_position
				var center := _project_tactical_cell_to_screen(cell)
				if not point.is_finite() or not center.is_finite(): continue
				var offset := (point - center).normalized() * 36
				targets.append({"rect": Rect2(point + offset - Vector2(45, 17), Vector2(90, 34)), "anchor": point,
					"label": (_siege_edge_name(edge) + " %d→%d" % [int(status.before.integrity_current), int(status.wall_after)]) if card.card_id == "P22" else _siege_edge_name(edge) + "墙 · 贯穿",
					"hit": {"ok": true, "target_kind": &"structure_module", "target_ref": ref}})
	if targets.is_empty() and card.card_id == "P22":
		message = "修补：只选己方受损墙/门楼；目前无可修构件。右键或 Escape 取消"
		if rejected.has(&"repair_already_full"): message = "修补：现有可修墙面耐久已满；不治疗棋子或平台。右键/Escape取消"
		elif rejected.has(&"structure_module_destroyed"): message = "修补：已摧毁构件不能复原；需仍存留的受损墙/门楼。右键/Escape取消"
	elif targets.is_empty() and card.card_id == "P23":
		message = "升地：目前无合法己方地块（检查高度上限或地基限制）；右键/Escape取消"
	if card.card_id == "P22" and not targets.is_empty(): message = "修补：点击或拖到绿色墙/门楼标记，数字为修补前→后；右键/Escape取消"
	elif card.card_id == "P23" and not targets.is_empty(): message = "升地：点击或拖到绿色地块标记，最高H2；不是选择棋子。右键/Escape取消"
	_card_target_guidance.show_targets(targets, message)

var _back_row_readability: Control
func _refresh_back_row_readability() -> void:
	if battle == null or context == null or context.player == null: return
	if not is_instance_valid(_back_row_readability):
		_back_row_readability = preload("res://scenes/presentation/back_row_status_overlay.gd").new()
		_back_row_readability.name = "BackRowStatusOverlay"
		_back_row_readability.z_index = 12
		add_child(_back_row_readability)
	var rows: Array[Dictionary] = []
	for card: CardData in context.player.traps:
		if card.card_id not in ["P05", "P08", "P13", "P14", "P04", "R01"]: continue
		var cell: Vector2i = battle._anchor_cell_of_rid(card.get_instance_id())
		if cell == Vector2i(-1,-1):
			var structure_id: StringName = context.tactical_structure_board_state.get_source_structure_id(card.get_instance_id())
			cell = context.tactical_structure_board_state.get_foundation_status(structure_id).get("cell", Vector2i(-1,-1))
		var point := _project_tactical_cell_to_screen(cell) if cell != Vector2i(-1,-1) else _project_3d_token_to_screen(_get_3d_token_for_card(card))
		if not point.is_finite(): continue
		var passive: Dictionary = battle.get_back_row_trigger_status(card)
		var state_text := str(passive.get("state",""))
		var cost_text := str(passive.get("cost",""))
		var benefit_text := str(passive.get("benefit",""))
		if card.is_building_card():
			var status: Dictionary = battle.get_building_interface_status(card, context.player)
			var state: Dictionary = battle.get_building_state(card)
			state_text = "主动可用" if status.get("ok", false) else "本回合已用" if state.get("used_this_turn", false) else "主动待条件"
			state_text += " · 充能%d" % int(state.get("charge", 0))
			cost_text = str(status.get("cost", ""))
			benefit_text = str(status.get("preview", status.get("reason", ""))) if status.get("ok", false) else str(status.get("reason", ""))
		rows.append({"position": point, "card_id": card.card_id, "title": card.get_display_name(), "state": state_text, "cost": cost_text, "benefit": benefit_text})
	var reserved := _get_reserved_ui_rects()
	for unit: CardData in context.player.field + context.enemy.field:
		var unit_point := _project_tactical_cell_to_screen(battle.get_unit_cell(unit))
		if unit_point.is_finite(): reserved.append(Rect2(unit_point-Vector2(45,55),Vector2(90,90)))
	_back_row_readability.refresh(rows, reserved)

func _show_committed_source_feedback(card: CardData, target_cell: Vector2i, text: String, source_screen: Vector2 = Vector2.INF) -> void:
	if card == null or text.is_empty(): return
	var source_cell: Vector2i = battle._anchor_cell_of_rid(card.get_instance_id())
	if source_cell == Vector2i(-1,-1):
		var structure_id: StringName = context.tactical_structure_board_state.get_source_structure_id(card.get_instance_id())
		source_cell = context.tactical_structure_board_state.get_foundation_status(structure_id).get("cell", Vector2i(-1,-1))
	var source := source_screen if source_screen.is_finite() else _project_tactical_cell_to_screen(source_cell)
	if not source.is_finite(): return
	# An unspecified recipient means source-local state, not heat delivered to OD.
	var target := _project_tactical_cell_to_screen(target_cell) if target_cell != Vector2i(-1,-1) else source
	if not target.is_finite(): return
	for previous in get_children():
		if previous.has_meta("committed_feedback_source") and previous.get_meta("committed_feedback_source") == card.get_instance_id():
			remove_child(previous)
			previous.queue_free()
	var feedback = preload("res://scenes/presentation/source_effect_feedback.gd").new()
	feedback.name = "CommittedBuildingFeedback"
	feedback.set_meta("committed_feedback_source",card.get_instance_id())
	feedback.z_index = 89
	feedback.source = source
	feedback.target = target
	feedback.message = "%s：%s" % [card.get_display_name(), text]
	feedback.reduced = _is_reduced_motion_presentation()
	feedback.reserved_rects = _get_structure_reserved_ui_rects()
	var entry_help := get_node_or_null("GB1HelpLayer/GB1HelpPanel") as Control
	if is_instance_valid(entry_help) and entry_help.is_visible_in_tree():
		feedback.reserved_rects.append(entry_help.get_global_rect().grow(8))
	if is_instance_valid(_boss_status_hud) and _boss_status_hud.is_visible_in_tree():
		feedback.reserved_rects.append(_boss_status_hud.get_global_rect().grow(8))
	if is_instance_valid(_view_controls):
		for control in [_view_controls._exit_button,_view_controls._base_button,_view_controls._top_button,_view_controls._free_button]:
			if is_instance_valid(control) and control.is_visible_in_tree():
				feedback.reserved_rects.append(control.get_global_rect().grow(8))
	if is_instance_valid(_back_row_readability):
		feedback.reserved_rects.append_array(_back_row_readability.occupied)
		feedback.reserved_rects.append_array(_back_row_readability.reserved)
	for previous in get_children():
		if previous.has_meta("committed_feedback_source") and previous.has_method("instruction_rect"):
			feedback.reserved_rects.append(previous.instruction_rect().grow(8))
	add_child(feedback)


## Default legacy authority remains one draw; only explicit player trials override.
func _get_player_turn_draw_count() -> int:
	return 1
