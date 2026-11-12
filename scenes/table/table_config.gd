extends RefCounted
class_name TableConfig

## TableConfig — 牌桌配置数据类
## 保存玩家牌桌的全部皮肤/装饰选择，由 GameManager 持有，PlayerTable 读取应用。

# ===== 皮肤 ID =====
var table_skin_id: String = "default_dark"
var od_core_skin_id: String = "default_core"
var card_back_id: String = "default_back"
var graveyard_skin_id: String = "default_grave"

# ===== 装饰槽位（未来DIY系统使用）=====
## 格式：{ "slot_1": {"item_id": "", "unlocked": false}, ... }
var decoration_slots: Dictionary = {}
