extends "res://core/run/run_session.gd"
## Growth transaction owner; UI browsing never changes offers or resources.
const GrowthConfig=preload("res://core/run/run_growth_config.gd")
var _growth_config: Dictionary={}
var _stage := "closed"
var _offer_token := ""
var _offers: Array[Dictionary]=[]
var _deck: Array=[]
var _upgrades: Dictionary={}
var _modules: Array[String]=[]
var _history: Array[Dictionary]=[]
func configure(config: Dictionary) -> Dictionary:
 if not GrowthConfig.validate(config.get("growth")).is_empty():return _fail(&"invalid_growth_config")
 var result: Dictionary=super.configure(config)
 if result.ok:_growth_config=config.growth.duplicate(true);_deck=Config.STARTER.duplicate()
 return result
func begin(seed: Variant,generation: int) -> Dictionary:
 var result: Dictionary=super.begin(seed,generation)
 if not result.ok:return result
 _deck=Config.STARTER.duplicate();_config.deck_ids=_deck.duplicate()
 _stage="closed";_offer_token="";_offers.clear();_upgrades.clear();_modules.clear();_history.clear()
 return result
func prepare_encounter() -> Dictionary:
 var result: Dictionary=super.prepare_encounter()
 if result.ok:
  result.contract.growth_schema=1
  result.contract.upgrades=_upgrades.duplicate(true);result.contract.modules=_modules.duplicate()
 return result
func finish_encounter(token: String,victory: bool,raw_hp: int,turns: int) -> Dictionary:
 var result: Dictionary=super.finish_encounter(token,victory,raw_hp,turns)
 if result.ok:
  if _state=="between":_set_stage("card")
  else:_stage="closed";_offer_token="";_offers.clear()
 return result
func _set_stage(value: String) -> void:
 _stage=value;_offer_token="growth:%d:%d:%s"%[_generation,_index,value];_offers.clear()
 if value=="card":
  var available: Array=[]
  for row in _growth_config.cards:
   if row.id not in _deck:available.append(row.duplicate(true))
  var rng:=RandomNumberGenerator.new();rng.seed=(_seed+3001*(_index+1))%2147483647
  for i in range(available.size()-1,0,-1):
   var j:=rng.randi_range(0,i);var temp: Variant=available[i];available[i]=available[j];available[j]=temp
  for row in available.slice(0,3):_offers.append(row)
 elif value=="camp":
  _offers.append({"id":"repair","name":"修复核心","description":"恢复最多8生命，上限35；与本节点改造二选一。"})
  for id in GrowthConfig.UPGRADE_IDS:
   if id in _deck and not _upgrades.has(id):
    var names={"S01":"锅炉学徒","P02":"燃芯使魔"}
    _offers.append({"id":"forge","name":"改造"+names[id],"description":"%s本远征基础攻击+1，跨场生效；放弃营地恢复。"%names[id],"target":id});break
 elif value=="module":
  for row in _growth_config.modules:
   if row.id not in _modules:_offers.append(row.duplicate(true))
 elif value=="done":_offer_token=""
func preview_choice(token: Variant,id: Variant) -> Dictionary:
 if _state!="between" or not token is String or not id is String or token!=_offer_token or _stage not in ["card","camp","module"]:return _fail(&"stale_choice")
 var row: Dictionary={}
 for offer in _offers:
  if offer.id==id:row=offer.duplicate(true);break
 if id=="skip":row={"id":"skip","name":"离开营地" if _stage=="camp" else "跳过","description":"保留当前构筑，不领取此项收益。"}
 if row.is_empty():return _fail(&"unknown_choice")
 row.ok=true;row.stage=_stage;row.hp_before=_hp;row.hp_after=_hp+mini(8,maxi(0,35-_hp)) if _stage=="camp" and id=="repair" else _hp
 row.deck_before=_deck.size();row.deck_after=_deck.size()+1 if _stage=="card" and id!="skip" else _deck.size()
 return row
func commit_choice(token: Variant,id: Variant) -> Dictionary:
 var preview: Dictionary=preview_choice(token,id)
 if not preview.ok:return preview
 var stage_before := _stage
 if id!="skip":
  match _stage:
   "card":_deck.append(id);_config.deck_ids=_deck.duplicate()
   "camp":
    if id=="repair":_hp=int(preview.hp_after)
    else:_upgrades[preview.target]=1
   "module":_modules.append(id)
 _history.append({"encounter_index":_index,"stage":stage_before,"choice_id":id,"token":token,"hp_before":preview.hp_before,"hp_after":_hp,"deck_before":preview.deck_before,"deck_after":_deck.size(),"target":preview.get("target","")})
 _set_stage("camp" if stage_before=="card" else ("module" if stage_before=="camp" else "done"))
 return {"ok":true,"choice":preview.duplicate(true)}
func advance_encounter() -> Dictionary:
 if _stage!="done":return _fail(&"growth_unresolved")
 var result: Dictionary=super.advance_encounter()
 if result.ok:_stage="closed";_offer_token="";_offers.clear()
 return result
func abandon() -> Dictionary:
 var result: Dictionary=super.abandon()
 if result.ok:_stage="closed";_offer_token="";_offers.clear()
 return result
func snapshot() -> Dictionary:
 var result: Dictionary=super.snapshot()
 result.deck_ids=_deck.duplicate()
 result.growth={"stage":_stage,"token":_offer_token,"offers":_offers.duplicate(true),"deck_ids":_deck.duplicate(),"upgrades":_upgrades.duplicate(true),"modules":_modules.duplicate(),"history":_history.duplicate(true)}
 return result
