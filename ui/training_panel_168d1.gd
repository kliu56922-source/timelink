extends "res://ui/training_panel_168c.gd"
func refresh168a() -> void:
 super.refresh168a()
 var s: Variant=scene168a()
 if s==null or tab168a!="guide":return
 var state: Dictionary=s.training_snapshot168a()
 var now: String="现在先部署：关闭本窗→左侧「连续展开」→选阵型→点主锚点→确认。" if state.preparation and state.recipe.used==0 else "阵地已展开：可点炉基座预览强化；准备好后点「部署完成」。" if state.preparation else "三要害已破：点己方单位→攻击Boss本体；指令不足可结束回合。" if s.flow166d.snapshot().broken==3 else "现在用现有场面作战：点场上Boss部位→选单位→有分支时选路线→执行。"
 text.text="168D1 · 从当前场面开始\n"+now+"\n\n① 第一回合只部署：凑齐「燃芯使魔」+「炉基座」→ 点左侧「连续展开」→ 选阵型 → 点锚点 → 确认。\n② 准备好后点右下「部署完成」进入交战。\n③ 卡住了点「玩法与目标」，完整规则都在里面。"
