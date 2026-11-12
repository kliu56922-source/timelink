extends "res://ui/compact_maintenance_panel_168c.gd"
func refresh_joint168c() -> void:
 super.refresh_joint168c()
 for key: String in joint_buttons168c:
  var b: Button=joint_buttons168c[key]
  if b.disabled:continue
  b.tooltip_text="消耗此手牌×1、1指令；热+2/负荷+1。"+("目标已锁定；选择素材后检查恢复量与费用，点确认。" if target_uid167d!=0 and key.ends_with(":repair") else "选择后点受伤友军，再检查并确认。" if key.ends_with(":repair") else "选择后点己方合法空格，再检查并确认；新学徒仍需休整。")
func sync() -> void:
 super.sync()
 if not is_instance_valid(joint_grid168c) or not compact168c or s().support166c.running or submitted168c:return
 if quote.get("ok",false):title.text="连续维护 · 检查账单，确认后结算"
 elif selecting:title.text="连续维护 · 点受伤友军" if mode=="repair" else "连续维护 · 点合法补位空格"
 else:title.text="维护此单位 · 选一张素材，再确认" if target_uid167d!=0 else "连续维护 · 选择素材＋用途"
