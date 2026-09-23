# toy-dg · 地城拾遗

单人战术刷宝 RPG 的第一份可玩原型。Godot **4.5.2 标准版** + GDScript，中文界面。

核心循环：**营地配装 → 方格战斗 → 事件检定 → 拾取／装包 → 深入或撤离 → 出售／强化 → 再次出发**。

## 运行

1. 下载或克隆本分支，使用 [Godot 4.5.2 标准版](https://github.com/godotengine/godot-builds/releases/tag/4.5.2-stable) 打开 `project.godot`。
2. 按 **F6** 运行当前主场景，或 **F5** 运行项目。
3. 先选择仓库里的「旧世指环」并点击「装备」，可解锁影步；然后点击「进入封印矿井」。

建议桌面1440×900。第一版使用代码绘制占位角色；最终方向为有特色的二次元，尚未进入正式美术制作。

## 操作

| 操作 | 方式 |
| --- | --- |
| 移动 | 选择「移动」，点击可达空格；按路径消耗移动力 |
| 攻击 | 点击敌人，选择斩击／裂伤／突进，查看预览后点击「执行技能」 |
| 突进 | 同行或同列2–4格内目标，路径无障碍，消耗2 AP |
| 影步 | 装备对应词条后点击「影步」，点击3格内空位，消耗1 AP |
| 防御／治疗 | 点击对应按钮，分别消耗1 AP；每次探索2瓶疗伤药 |
| 结束回合 | 点击按钮，或按空格 |
| 整理物品 | 非战斗时拖拽物品到空位；选中后按R或点击「旋转」 |
| 换装与交易 | 营地选择背包／仓库装备，再点击装备、出售、转移 |
| 撤离 | 战斗结束后、事件前或最终出口可撤离 |

攻击先进行d100命中检定，再掷2d6决定伤害浮动。暴击率表示**已命中攻击中的暴击概率**；背面攻击增伤20%。速度决定每轮顺序，不增加行动次数。

探索失败丢失本局新捡的战利品，带入物品与穿戴装备保留，维修最多30金币。每次有效操作后自动保存，包括正在进行的探索与随机数状态。

## 构建下载版和网页包

[Actions](https://github.com/XiminHu66/toy-dg/actions) 中的 `Godot prototype checks and builds` 成功后，运行页面底部提供：

- `toy-dg-windows`：解压后运行 `toy-dg.exe`（未签名原型，未完成Windows实机QA）。
- `toy-dg-web`：解压后通过HTTP服务器运行；例如在目录中执行 `python -m http.server 8000`，再访问 `http://localhost:8000`。不能直接双击HTML。
- `toy-dg-screenshots`：CI渲染的营地与战斗截图。

Actions产物下载可能需要登录GitHub，默认保留14天。此项目尚未部署公开试玩站点，也没有自动修改GitHub Pages配置。网页存档限当前浏览器／站点，清除站点数据可能丢失存档。

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

验证规则边界、命中／暴击分布、路径与位移限制、背包操作守恒、交易与强化、失败损失、存档与随机数恢复，以及6组种子的完整探索流程。UI冒烟检查覆盖营地、战斗、事件、掉落与出口。自动验证不代替人工平衡试玩。

## 文档

- [完整策划 v0.2](docs/design-v0.2.md)
- [原型已实现内容、简化项和下一步](docs/prototype-status.md)
- [第三方素材与引擎说明](THIRD_PARTY_NOTICES.md)

源码当前未选择项目级开源许可证。字体按随附OFL单独授权。
