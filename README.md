# toy-dg · 地城拾遗

单人卡牌战斗刷宝 RPG 的可玩原型。Godot **4.5.2 标准版** + GDScript，中文界面。

核心循环：**营地配装 → 揭开迷雾 → 卡牌战斗／事件 → 拾取与估值 → 返回入口或击败首领撤离 → 交易／强化／抽奖／附魔**。

## 运行

**推荐使用自动更新启动器：** 从[最新版本](https://github.com/XiminHu66/toy-dg/releases/latest)
下载 `toy-dg-launcher.zip`，解压运行 `ToyDG-Launcher.exe`。启动器会自动检查、下载并安装游戏更新，
完成后点击“开始游戏”。首次安装需要联网；之后断网也能启动已安装版本。无需安装Godot。

[固定启动器下载链接](https://github.com/XiminHu66/toy-dg/releases/latest/download/toy-dg-launcher.zip)
· [更新与存档说明](docs/updates.md)

从源码运行：

1. 下载或克隆本分支，使用 [Godot 4.5.2 标准版](https://github.com/godotengine/godot-builds/releases/tag/4.5.2-stable) 打开 `project.godot`。
2. 按 **F6** 运行当前主场景，或 **F5** 运行项目。
3. 进入「仓库」页，选择「旧世指环」并点击「装备」，可获得影步专属牌；在「出征」页点击「开始探索」。

建议桌面1440×900，最低窗口960×600，界面等比缩放。新增原创AI二次元角色与遗迹背景；敌人暂为代码绘制的符文造型。

## 操作

| 操作 | 方式 |
| --- | --- |
| 选牌 | 点击手牌，或按1–9 / 0；Esc取消 |
| 攻击 | 点击卡牌再点击敌人，或拖牌至敌人；支持悬停置顶和目标伤害预览 |
| 技能 | 点击直接生效；获得格挡、抽牌、能量或下一击增伤 |
| 回合 | 每回合3能量，抽5张；未使用手牌弃置，空牌堆自动洗牌 |
| 敌人 | 头顶显示下一步意图；失衡会立即反映在预告伤害中 |
| 治疗 | 1能量，每次探索2瓶，恢复最多30生命 |
| 结束回合 | 按钮或空格 |
| 战后选牌 | 首战三选一加入本局牌组，也可直接继续跳过 |
| 整理物品 | 「仓库」页拖拽、R旋转、全部入库、自动整理、锁定防误卖；商店按每格价值排列待售品 |
| 探索 | 揭开与已清理路径相邻的格子；数字代表周围八格危险数；右键标记，可消耗侦察次数查看内容 |
| 撤离 | 返回入口，或击败地图右下角首领后从出口撤离 |
| 养成 | 「商店」购买与出售，「工坊」强化至+5及附魔，「抽奖」消耗120金币，十次内保底稀有以上 |

战斗攻击必定命中，伤害由卡牌与装备属性决定，保留暴击随机。感知／意志事件继续使用d100检定。
基础牌组10张，加武器专属牌；影步词条再加1张专属牌。卡牌成长仅限本局，装备长期保留。
具体属性映射和结算顺序见[卡牌版设计](docs/card-combat-v0.3.md)。

探索失败丢失本局新捡的战利品，带入物品与穿戴装备保留，维修最多30金币。每次有效操作后自动保存，包括正在进行的探索与随机数状态。

## 构建下载版和网页包

[Actions](https://github.com/XiminHu66/toy-dg/actions) 中的 `Godot prototype checks and builds` 成功后，运行页面底部提供：

- `toy-dg-windows`：解压后运行 `toy-dg.exe`（单版本包，本身不检查更新）。
- `toy-dg-launcher`：自动更新启动器，可检查并安装GitHub Releases中的新游戏版本。
- `toy-dg-web`：解压后通过HTTP服务器运行；例如在目录中执行 `python -m http.server 8000`，再访问 `http://localhost:8000`。不能直接双击HTML。
- `toy-dg-screenshots`：CI渲染的营地与战斗截图。

日常下载请用Releases中的启动器包；Actions产物可能需要登录GitHub，默认保留14天。主分支通过测试及Windows冒烟检查后发布Release。此项目尚未部署公开试玩站点，也没有自动修改GitHub Pages配置。网页存档限当前浏览器／站点，清除站点数据可能丢失存档。

本地导出先在Godot中安装4.5.2导出模板，然后执行：

```sh
mkdir -p build/web build/windows
godot --headless --path . --export-release Web build/web/index.html
godot --headless --path . --export-release "Windows Desktop" build/windows/toy-dg.exe
```

分发时随包附带 `THIRD_PARTY_NOTICES.md` 与 `assets/fonts/OFL.txt`。

## 验证

```sh
GODOT=/path/to/godot python3 scripts/ci_check.py
```

验证卡牌循环与状态、完整迷雾探索、交易费用和失败原子性、附魔、抽奖保底、仓库整理、存档迁移与随机数恢复。UI冒烟检查覆盖营地六个分页和所有游戏阶段，并检查1440×900、1280×720、960×600窗口中的真实手牌边界。Windows导出包与公开自动更新另行执行端到端检查。自动验证不代替人工平衡试玩。

## 文档

- [迷雾探索、营地经济与手牌交互 v0.4](docs/exploration-economy-v0.4.md)

- [卡牌战斗与UI改版 v0.3](docs/card-combat-v0.3.md)
- [刷宝经济原始策划 v0.2](docs/design-v0.2.md)
- [原型已实现内容、简化项和下一步](docs/prototype-status.md)
- [第三方素材与引擎说明](THIRD_PARTY_NOTICES.md)
- [自动更新、回退与主分支发布](docs/updates.md)

项目由单人维护，按用户要求直接在`main`开发；CI通过后发布新的可更新版本。

源码当前未选择项目级开源许可证。字体按随附OFL单独授权。
