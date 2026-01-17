# ProjectW

无限恐怖流Roguelike | Unity 6 + xLua | PolyMesh风格化

## 快速开始

1. Unity 6.x 打开 `Unity/` 目录
2. 入口场景: `Assets/Scenes/Main.unity`

## 目录结构

```
Client/
├── Unity/              # Unity工程
│   └── Assets/
│       ├── _Core/      # C#核心代码
│       ├── _Data/      # 数据资产
│       ├── _Editor/    # 编辑器工具
│       └── LuaScripts/ # Lua代码和配表
└── .cursor/rules/      # AI规则(自动加载)
```

## 开发规范

见 `.cursor/rules/project-rules.mdc`（Cursor自动加载）
