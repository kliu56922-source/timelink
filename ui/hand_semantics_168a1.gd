extends RefCounted
## Read model only: no quotes, transactions, input or gameplay state are owned here.
const OriginalFacts=preload("res://ui/hand_card_readability.gd")
const CATALOG={
 "P02":["棋子","展开","单用：找炉心建筑\n出场回合不能攻击","选空格部署；可与炉基座组合","单独使用：登场检索炉心建筑到手，仍需另行建造；出场回合不能攻击。"],
 "P05":["建筑","展开","建成：护盾+3\n主动：强化或缓压","选位建造；可与燃芯使魔组合","单独使用：建造时护盾+3。建成后每回合主动一次：优先付2充能，否则付2热，强化最先登场的前场棋子+1/+1；无棋子时付1热，准备下次Depth增长减免1。成功主动按原条件检索炉心延展牌。"],
 "B01":["法术","清路","选敌方普通棋子\n造成2伤害","选敌方棋子，再确认","只打敌方普通棋子，不打Boss本体、要害或建筑；驻军受完整建筑掩护时须先处理城墙。同名每回合成功一次。"],
 "B02":["法术","强化","选友军；本回合\n下次普通攻击+2","选己方棋子，再确认","己方普通棋子本回合下次普通攻击+2，成功攻击后消耗，回合结束失效。也增加要害耐久伤害并消耗，但不增加固定的要害击破本体伤害。不加行动、射程或技能伤害；清墙步骤不消耗。已有未用赋刃不能重复。同名每回合成功一次。"],
 "B03":["法术","防护","选友军；下次交战\n减伤2，至下次己回合","选己方棋子，再确认","己方普通棋子下次棋子交战/反击减伤2，至下次己方回合；取较高护送值，不叠加。不挡Boss法术，不是核心护盾。同名每回合成功一次。"],
 "B04":["法术","增热","获得2热量\n同名每回合一次","无需选格，沿用原确认","获得2热量，受热量上限约束；热量已满不能使用。不抽牌或造成伤害；同名每回合成功一次。0热只指热量支付，其他资格仍按原预览。"],
 "B05":["法术","降压","当前Depth−2\n最低为0","无需选格，沿用原确认","降低当前Depth2，最低0；Depth为0不能使用。不是准备下次增长减免。同名每回合成功一次。"],
 "P08":["建筑","驻军","双格：塔身＋平台\n可驻军；主动+1/+1","选方向与合法双格，再确认","双格建筑，可驻军。建造方向、占地及容量按原预览。主动需本回合已成功出牌2张，再付1热，强化最先登场的前场棋子+1/+1；主动次数沿用原规则。"],
 "P10":["棋子","延展","登场：打1并抽1\n检索炉心延展牌","选空格；出场回合不能攻击","单独登场伤害1并抽1，按原条件检索炉心延展牌到手；起手、连锁与引擎等级的附加收益见完整原文。获得手牌不等于自动使用或生成新配方。出场回合不能攻击。"],
 "P11":["法术","降压","当前Depth−3\n效果热−2；护盾+2","无须部署；条件收益见详情","降低当前Depth3、效果热量−2、护盾+2；这与出牌基础产热是不同来源。条件增益及检索仍按原文，不会自动展开。"],
 "P13":["建筑","缓压","建成：护盾+3\n主动：下次Depth减免","选位建设；不是立即排压","入场护盾+3；主动优先付1热，否则付1冷却充能，准备下次Depth增长减免1，每回合一次。不是立刻降低当前Depth；入场阈值收益见原文。"],
 "S02":["法术","检索","需存活蒸汽棋子\n从牌库找蒸汽牌到手","无需选格；结果按原预览","需己方有存活蒸汽棋子；从牌库取得首张符合条件的蒸汽起手/中转棋子到手，不是自由挑牌或自动召唤。仍需正常费用、容量与休整；手牌没有空位时不能取得。同名每回合一次。"],
 "S03":["法术","回收","墓地蒸汽棋子\n回到手牌，非复活","无需选格；结果按原预览","从墓地取得首张符合条件的蒸汽普通棋子回手，不是直接复活；仍需正常召唤费用、容量与休整。没有对象或手牌空位时不能取得。同名每回合一次。"],
 "R01":["反应","防护","盖伏：攻击减伤3\n手发：付1热减伤2","盖伏或等敌方攻击响应","盖伏监视己方格，首次符合条件的单体攻击减伤3后消耗。手发仅在敌方攻击响应窗口，付1热减伤2；可按原窗口透支Depth+1至减伤3。不是任意时机出手，沿用每敌方回合限次。"]
}
static func recognized(card: CardData) -> bool:
 return is_instance_valid(card) and CATALOG.has(card.card_id)
static func build(scene,card: CardData,status: Dictionary={}) -> Dictionary:
 if not recognized(card) or not is_instance_valid(scene) or scene.battle==null:return {}
 var native: Dictionary=scene.battle.get_card_play_status(card) if status.is_empty() else status
 var old: Dictionary=OriginalFacts.build(card,native,scene.battle)
 var row: Array=CATALOG[card.card_id]
 var cost: String=str(old.cost).replace("基础热 +","出牌产热+").replace("费用 1热","消耗1热").replace("免费","支付0热").replace("布置 0热","盖伏0热")
 var state: String=str(native.get("reason","")) if not native.get("ok",false) else str(row[3])
 if state.is_empty():state=str(row[3])
 var detail: String=row[4]
 var combo: Dictionary={}
 if card.card_id in ["P02","P05"]:
  combo=combo_state(scene,card)
  state="单用："+state
  var d: Dictionary=scene.battle.recipe166_definition
  detail+="\n\n组合使用：燃芯使魔＋炉基座 → 炉心阵地。点原「连续展开」入口，选阵型、锚点并确认。整套消耗%d指令，负荷+%d，获得%d热、护盾+%d；独立衍生池生成1个学徒，计入容量且有出场休整。替代两张牌原本的登场/检索，不重复触发；本场限%d次。\n组合当前：%s\n\n可作为维护素材：交战后从原维护入口使用，具体修补/替换目标、费用和次数按原预览；不是再发动整套配方。" % [d.command_cost,d.load_cost,d.heat_gain,d.shield_gain,d.per_battle_limit,combo.text]
 var load_text: String="负荷+%d"%card.load_cost
 var stats: String="攻击%d / 生命%d"%[card.unit_power,card.unit_defense] if row[0]=="棋子" else ""
 var full: String=card.get_detail_description()
 if not stats.is_empty():full+="\n"+stats
 return {"type":row[0],"role":row[1],"summary":row[2],"cost":cost,"load":load_text,"stats":stats,"status":state,"ok":native.get("ok",false),"detail":detail,"full":full,"combo":combo,"name":card.get_display_name(),"uid":card.get_instance_id()}
static func combo_state(scene,card: CardData) -> Dictionary:
 var partner_id: String="P05" if card.card_id=="P02" else "P02"
 var partner_name: String="炉基座" if partner_id=="P05" else "燃芯使魔"
 var result: Dictionary={"partner_id":partner_id,"partner_name":partner_name,"partner_uid":0,"text":"缺少手牌："+partner_name,"ready":false}
 var partner: CardData=scene.battle.recipe166_key(partner_id)
 if partner!=null:result.partner_uid=partner.get_instance_id()
 if int(scene.battle.recipe166_snapshot().used)>=int(scene.battle.recipe166_definition.per_battle_limit):result.text="本场炉心阵地已使用";return result
 if partner==null:return result
 if card not in scene.context.player.hand:result.text="需两张关键牌同时在手";return result
 # Probe legal layouts via the native pure query. Never call recipe.prepare here.
 var first_reason: String=""
 for direction: String in ["arm","valve"]:
  for row: int in [3,4]:
   for col: int in [2,1,3,0,4]:
    var q: Dictionary=scene.battle.recipe166_preview(direction,Vector2i(col,row))
    if first_reason.is_empty():first_reason=str(q.get("reason",""))
    if q.get("ok",false):
     result.text="两key齐全；点连续展开，选位预览";result.ready=true;return result
 result.text="两key齐全；"+first_reason
 return result
