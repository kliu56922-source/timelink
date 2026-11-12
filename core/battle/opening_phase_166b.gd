extends RefCounted
## One encounter-local phase authority. No reliance on UI or turn serial parity.
const REASON="首回合部署阶段：可展开、建造和控压；移动、攻击、技能与OD释放在交战阶段启用。护卫等短效战斗牌请留到交战。准备好后点「部署完成 · 进入交战」，余点不结转。"
var phase: String="deployment"
var player_round:=0
var boss_prepared:=false
var preparation_receipt: Dictionary={}
func begin_player_turn() -> void:
	player_round+=1
	phase="deployment" if player_round==1 else "combat"
func preparation_active() -> bool:return phase!="combat"
func damage_allowed() -> bool:return player_round==0 or not preparation_active()
func refusal() -> Dictionary:return {"ok":false,"reason_code":&"opening_deployment","reason":REASON,"reason_text":REASON,"cost":0,"legal_cells":[],"legal_targets":[]}
func commit_boss_preparation() -> bool:
	if not preparation_active() or boss_prepared:return false
	boss_prepared=true;phase="boss_preparation"
	preparation_receipt={"kind":"boss_preparation","shield_gain":2,"natural_heat_gain":2,"damage":0}
	return true
func snapshot() -> Dictionary:return {"phase":phase,"player_round":player_round,"boss_prepared":boss_prepared,"receipt":preparation_receipt.duplicate(true)}
