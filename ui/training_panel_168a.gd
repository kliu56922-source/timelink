extends CanvasLayer
var owner_ref: WeakRef
var entry: Button
var window: Window
var text: Label
var card_select: OptionButton
var status: Label
var tab168a:="guide"
func scene168a() -> Variant:return owner_ref.get_ref() if owner_ref!=null else null
func setup168a(owner: Node) -> void:
 owner_ref=weakref(owner);layer=67
 var tools: Variant=owner.get_node("IntegratedPlaytestTools")
 entry=Button.new();entry.name="TrainingJournal168A";entry.text="168A训练 · 联动与记录";entry.tooltip_text="查看起步方法、当前真实账单及19张牌；不自动出牌。"
 add_child(entry);entry.position=Vector2(12,92);entry.pressed.connect(open168a)
 window=Window.new();window.name="TrainingInspector168A";window.title="168A真实规则训练场 · 不计普通胜率";window.size=Vector2i(720,330);window.min_size=Vector2i(540,240);window.exclusive=true
 add_child(window);window.hide();window.close_requested.connect(close168a)
 var box:=VBoxContainer.new();window.add_child(box);box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);box.offset_left=16;box.offset_right=-16;box.offset_top=12;box.offset_bottom=-12
 var tabs:=HBoxContainer.new();box.add_child(tabs)
 for spec: Array in [["怎么玩","guide"],["当前联动","current"],["19张牌","cards"],["结算记录","events"]]:
  var button:=Button.new();button.text=spec[0];tabs.add_child(button);button.pressed.connect(select168a.bind(spec[1]))
 card_select=OptionButton.new();box.add_child(card_select);card_select.item_selected.connect(func(_i):refresh168a())
 var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;box.add_child(scroll)
 text=Label.new();text.name="TrainingText168A";text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;text.add_theme_font_size_override("font_size",16);scroll.add_child(text)
 status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(status)
 var bottom:=HBoxContainer.new();box.add_child(bottom)
 var export_button:=Button.new();export_button.name="ExportTraining168A";export_button.text="保存独立训练记录";bottom.add_child(export_button);export_button.pressed.connect(export168a)
 var close:=Button.new();close.name="ReturnTraining168A";close.text="返回训练";bottom.add_child(close);close.pressed.connect(close168a)
func select168a(tab: String) -> void:tab168a=tab;refresh168a()
func _process(_delta: float) -> void:
 var s: Variant=scene168a()
 if s!=null and is_instance_valid(entry):entry.visible=not s.get_node("IntegratedPlaytestTools").panel.visible
func zone_text168a(zone: String) -> String:
 return {"hand":"手牌","deck":"牌库","field":"场上单位","building":"场上建筑","graveyard":"墓地","departed":"已离场"}.get(zone,zone)
func open168a() -> void:
 var s: Variant=scene168a()
 if s==null:return
 if not s.battle_ended and (not s.axis155_native_ready() or not s.recipe166._gate().is_empty()):return
 s.targets167b.dismiss();s.recipe_panel166.dismiss();s.advance_panel165.dismiss();s.support_panel166c.dismiss()
 # Keep selections/windows owned by other interfaces intact; their gate above wins.
 refresh168a();window.popup_centered(Vector2i(mini(880,s.get_window().size.x-40),mini(560,s.get_window().size.y-50)))
func close168a() -> void:window.hide()
func refresh168a() -> void:
 var s: Variant=scene168a()
 if s==null:return
 var state: Dictionary=s.training_snapshot168a();var catalog: Array=s.training_catalog168a()
 var index:=card_select.selected
 card_select.clear()
 for i in range(catalog.size()):card_select.add_item("%02d %s [%s]"%[i+1,catalog[i].name,zone_text168a(catalog[i].zone)])
 if not catalog.is_empty():card_select.select(clampi(index,0,catalog.size()-1))
 card_select.visible=tab168a=="cards"
 var heading:="训练条件：木桩不主动进攻；正常抽牌/费用/容量/休整/限次保留。\n木桩保留原生部位锁、护甲/领域及阶段反应；当前目标盾%d、OD%d。\n第%d己方回合（含部署），剩%d指令，热%d，负荷%d，Depth%d。\n\n"%[state.target_shield,s.context.enemy.od,state.player_round,state.economy.current_points,state.heat,state.load,state.depth]
 match tab168a:
  "guide":text.text=heading+"① 先关闭本窗。点「连续展开」，选护臂/阀门阵型→主锚点→确认。只消耗真实手中两key，独立池生成1个学徒。\n② 首回合先展开/建造/控压。准备好后点「部署完成」；新单位仍需正常等到交战回合。\n③ 点场上部位→选单位→有分支时选路线→确认，观察移动与攻击。途中停止只停后续，已付费用保留。\n④ 建筑强化、赋刃/护卫、蓄火/排压仍分别按原生目标与费用使用。此处没有自动新增配方。\n⑤ 查看「当前联动」「19张牌」及「结算记录」比较前提、实付和实际结果。正常/加速/跳过只改变观看。\n\n手牌上限10：满手后抽到的牌会进墓地，可从「19张牌」查看去向。\n想重试：战术工具→重新挑战。会重新开局，不是本局回满资源。三部位与木桩可正常被击破，训练可结束。\n\n168B再加守卫、受伤/补位和危险区案例。本阶段不主动制造伤害；维修/防护没有自然用途时可以不使用。"
  "cards":
   var c: Dictionary=catalog[card_select.selected]
   var eligibility: String="当前原生前提通过；仍需合法目标与确认" if c.status.get("ok",false) else str(c.status.get("reason","当前不可用"))
   text.text=heading+"%s · %s\n来源：固定19张牌第%d项 / 当前%s\n\n%s\n\n联动边界：%s\n当前资格：%s\n\n牌库中的牌仍需正常抽到；查看不会取牌/检索/生成。"%[c.id,c.name,card_select.selected+1,zone_text168a(c.zone),c.description,c.note,eligibility]
  "current":
   text.text=heading+"已有自动配方：燃芯使魔＋炉基座 → 独立衍生学徒。已用%d/1、累计生成%d；学徒不算额外出牌。\n维护：本场%d/2。交战后用真实key素材修复/补位，满血/学徒仍在场会拒绝；不刷新行动。\n\n手动协同：炉基座强化主力；赋刃强化下次普通攻击（含要害耐久伤害）；护卫抵挡棋子交战；蓄火与排压管理热/Depth。它们不是另一套自动配方。\n\n目标边界：打击需要敌方普通棋子，不能改点Boss部位；赋刃不增加固定的击破本体伤害，护卫不挡Boss法术。当前无敌棋，打击没有目标属正常；守卫场景后续168B。\n\n原生单位状态：\n"%[state.recipe.used,state.recipe.generated_total,state.support.used]
   for unit: Dictionary in state.units:text.text+="%s · %d列%d行 · 血量%d/%d · 攻击%d · 赋刃%d · 护卫%d · %s\n"%[unit.name,unit.cell.x+1,unit.cell.y+1,unit.state.get("current_hp",0),unit.state.get("max_hp",0),unit.power,unit.blade,unit.escort,"本回合休整" if unit.state.get("summoned_this_turn",false) else "已过休整"]
  "events":
   text.text=heading+"以下是实际结算回执与状态变化；普通观察记录不等于成功触发。保存训练记录可查看完整内容。\n\n"
   var records: Array=s.journal168a.entries
   for i in range(maxi(0,records.size()-14),records.size()):
    var e: Dictionary=records[i]
    var kind: String={"training_started":"训练开始","state_changed":"状态变化","recipe_committed":"展开已结算","maintenance_committed":"维护已结算","advance_step":"推进步骤已结算","card_committed":"单卡已使用","part_committed":"要害命中已结算","training_finished":"训练完成"}.get(e.kind,"观察记录")
    text.text+="#%d 回合%d %s · 指令%d 热%d 负荷%d Depth%d 目标HP%d\n"%[i+1,e.round,kind,e.state.economy.current_points,e.state.heat,e.state.load,e.state.depth,e.state.target_hp]
    if e.kind=="recipe_committed":text.text+="两key已支付；生成学徒%d个，实付%d指令。\n"%[e.receipt.get("generated",0),e.receipt.get("cost",1)]
    elif e.kind=="maintenance_committed":text.text+="实际修复%d生命；补位%d个；实付%d指令。\n"%[e.receipt.get("healed",0),e.receipt.get("generated",0),e.receipt.get("cost",0)]
    elif e.kind=="card_committed":text.text+="来源：%s，已按原生费用和目标结算。\n"%e.receipt.source_name
    elif e.kind=="part_committed":text.text+="耐久实际减少%d，本体生命实际减少%d。\n"%[e.receipt.get("integrity_loss",0),e.receipt.get("actual_hp_loss",0)]
    text.text+="\n"
func export168a() -> void:
 var s: Variant=scene168a()
 if s==null:return
 var r: Dictionary=s.journal168a.export168a()
 status.text="已保存："+str(r.path) if r.ok else str(r.reason)
func _exit_tree() -> void:
 if is_instance_valid(entry):entry.queue_free()
