extends "res://ui/compact_actions_168c.gd"
const ForecastD1=preload("res://battle/analysis/compact_combat_forecast_168d1.gd")
func request_attack168c(actor_uid: int,target_uid: int) -> Dictionary:
 var result: Dictionary=super.request_attack168c(actor_uid,target_uid)
 if not result.get("ok",false):return result
 var owner: Variant=s()
 var prediction:=ForecastD1.inspect(owner.battle,actor168c(actor_uid),owner.axis155.resolve(target_uid,"enemy"))
 dialog.dialog_text=ForecastD1.describe(prediction)+"\n\n"+dialog.dialog_text
 dialog.popup_centered(Vector2i(640,420))
 return result
