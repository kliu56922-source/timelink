# 美术资源目录

> 此目录存放 Overheat Combo Demo 的全部美术资源。
> 当前为占位状态，放入对应文件即可自动生效。

## 目录结构

```
art/
├── boss/forge_guardian/   ← 熔炉守卫画像 + 3D模型
├── cards/
│   ├── starter/           ← 6张 STARTER 卡图
│   ├── extender/          ← 6张 EXTENDER 卡图
│   ├── control/           ← 4张 CONTROL 卡图
│   └── finisher/          ← 4张 FINISHER 卡图
├── ui/
│   ├── icons/             ← UI 图标 (OD/Chain/Trap/Finisher)
│   └── frames/            ← 卡牌边框 (COMMON/RARE/SUPER) + 卡背
├── vfx/                   ← VFX 贴图 (命中/爆发/冲击波/光晕)
└── board/                 ← 牌桌纹理 (桌面金属/法线/能量线)
```

## 命名规则

- 全部小写 + 下划线
- 卡图: `{card_name}.png` (与 card_data.card_name 对应)
- Boss: `forge_guardian_{state}.png`
- 图标: `icon_{name}.png`

## 接入方式

放入对应文件后，代码通过 `ResourceLoader.load()` 加载。
文件不存在时 fallback 到程序化色块（不报错）。

## 参考文档

- [ART_DIRECTION.md](../ART_DIRECTION.md) — 美术方向总纲
- [ASSET_LIST.md](../ASSET_LIST.md) — 完整资源清单
- [CARD_ART_GUIDE.md](../CARD_ART_GUIDE.md) — 卡图设计规范
- [BOSS_ART_GUIDE.md](../BOSS_ART_GUIDE.md) — Boss 美术设计规范
