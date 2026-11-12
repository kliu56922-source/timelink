extends "res://ui/training_panel_168b.gd"
func refresh168a() -> void:
 super.refresh168a()
 var s: Variant=scene168a()
 if s==null:return
 text.text=text.text.replace("受损专项/危险区尚未加入。","本例观察真实交战受损/缺员，危险区尚未加入。")
 var intro: String="168B2 受损与维护 · 维护为可选\n"+s.maintenance_situation168b2().get("detail","")+"\n\n"
 if tab168a=="guide":intro+="可选观察：保护使魔后与守卫交战，观察受损→点使魔→维护此单位→选使魔或炉基座→检查实际恢复量与费用→确认。也可保留材料继续战斗。\n补位观察：学徒与守卫交战可能阵亡；原学徒离场后，从连续操作入口选材料→补回学徒→己方合法空格→确认。新学徒需正常休整；这是补缺，不是额外增强。\n\n"
 text.text=intro+text.text
