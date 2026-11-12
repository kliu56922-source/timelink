# Phase 27K-R1-B Greybox SFX Source

这些音效由项目内 `tools/generate_phase27k_r1b_greybox_sfx.ps1` 确定性生成，不含第三方采样，仅用于 R1-B 灰盒演出验证。后续 R1-F 可直接用同名 `.ogg` 替换，调用方无需修改。

格式：mono / 44.1 kHz / 16-bit PCM WAV，带短 attack/release 包络，峰值低于削波阈值。

| Key | 基频 | 时长 | 用途 |
|---|---:|---:|---|
| ui_click | 620 Hz | 0.09s | 确认 |
| ui_error | 220 Hz | 0.18s | 拒绝 |
| card_play | 420 Hz | 0.20s | 卡牌提交 |
| monster_land | 150 Hz | 0.24s | 怪兽落地 |
| spell_cast | 520 Hz | 0.32s | 魔法施放 |
| monster_attack | 260 Hz | 0.18s | 攻击起手 |
| monster_hit | 120 Hz | 0.16s | 攻击命中 |
| shield_block | 760 Hz | 0.20s | 护盾吸收 |
| building_land | 180 Hz | 0.28s | 建筑落地 |
| counter_set | 680 Hz | 0.22s | 反制触发 |
| od_up | 480 Hz | 0.18s | 热量增长 |
| od_charge_tick | 700 Hz | 0.10s | 充能刻度 |
| enter_heated | 340 Hz | 0.34s | 进入炽热 |
| enter_overdrive | 210 Hz | 0.46s | 进入过载 |
| od_release_extract | 300 Hz | 0.30s | OD 提取 |
| od_release_conduit | 560 Hz | 0.34s | OD 导流 |
| od_release_impact | 105 Hz | 0.38s | OD 冲击 |

## 2026-09-12 Phase E 旧事件名兼容

AudioManager 先查事件本名的 `.ogg` / `.wav`，缺失时才使用以下现有资源；同名正式音效加入后自动优先。仍使用原音量、通道池和调用方，不引入外部采样。

| 旧事件名 | 暂用资源 |
|---|---|
| hit / boss_hit / player_hit | monster_hit |
| boss_warning / od_layer_up / depth_warning | enter_heated |
| building_activate / boss_intent | counter_set |
| chain_step | od_charge_tick |
| chain_complete / boss_core_online | enter_overdrive |
| ui_hover | ui_click |
| card_draw | card_play |
| od_down | od_release_extract |
| finisher / card_destroy / burst | od_release_impact |
| building_replace | building_land |
| boss_action | monster_attack |

普通攻城在视觉命中时请求 `monster_hit`，破坏请求 `card_destroy`；减少动态模式立即播放。P18 保留原 BattleSystem 已有的命中声音发布，表现层不再重复播放。当前 P18 多击声音仍按原结算时序发出，不宣称已逐击音画同步。

这是灰盒声音补全，尚未制作正式音乐和独立角色音色。`battle_theme.ogg`、胜利和失败音效目前仍缺失；未知事件仍返回空路径，不以任意声音冒充。
