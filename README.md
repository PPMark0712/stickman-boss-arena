# Stickman Boss Arena

一款使用 Godot 4.7.2 和 GDScript 制作的 Web Boss Rush 小游戏。玩家可直接选择两位拥有独立双阶段招式的 Boss，战斗包含即时移动、二段跳、交替挥砍、冲刺、法术、治疗、受伤无敌与本地最佳时间记录。

画面完全由 2D 几何图形实时绘制，音效在运行时合成，不依赖外部图片或音频资源。

## 操作

| 按键 | 动作 |
| --- | --- |
| `←` / `→` | 移动 |
| `Z` | 跳跃 / 二段跳 |
| `X` | 水平斜向挥砍；每次攻击交替方向 |
| `↑` + `X` | 地面或空中上劈 |
| 空中 `↓` + `X` | 下劈；命中后反弹 |
| `C` | 向前冲刺；接触敌人会受击中断 |
| `A` 不超过 0.1 秒 | 消耗 3 点能量释放法术 |
| 长按 `A` | 每轮 0.3 秒准备 + 1 秒蓄力；分三次扣能并可连续回血 |
| `Esc` | 暂停 / 继续 |
| `R` | 重新挑战 |

每次有效剑击获得 1 点能量。选关页可开启练习模式，获得无限生命与能量，练习成绩不会写入纪录。
跳跃和二段跳的脚底最高离地约为角色身高的 1.8 倍；圆形落石可用 `↑` + `X`
上劈，命中后会竖直反弹并飞出屏幕。

## 本地运行

安装 Godot 4.7.2 后，用编辑器打开 `project.godot` 并运行项目。

执行自动验证：

```bash
python3 tools/build.py test
```

首次导出 Web 前下载官方单线程模板，然后构建：

```bash
python3 tools/fetch_templates.py
python3 tools/build.py web
python3 -m http.server 8060 --directory build/web
```

浏览器访问 <http://127.0.0.1:8060>。也可运行 `python3 tools/build.py all`
一次完成导入、235 项玩法检查和 Web 导出。若 Godot 不在系统路径或 macOS
默认位置，请设置 `GODOT=/path/to/godot`。

## 项目结构

- `scripts/player.gd`：玩家有限状态机与战斗能力。
- `scripts/behavior_tree.gd`：Boss 使用的行为树节点。
- `scripts/boss.gd`：裂岩守卫与折光剑使的阶段和招式。
- `scripts/arena.gd`：物理房间、命中、弹体与战斗反馈。
- `scripts/main.gd`：选关、HUD、暂停、结果和本地纪录。
- `tests/`：玩家逻辑与真实场景/物理集成测试。
- `web/shell.html`：Web 加载、错误反馈和 Canvas 容器。
- `docs/development.md`：详细设计参数与模块说明。

## GitHub Pages

`.github/workflows/pages.yml` 会在 `main` 分支推送时使用 Godot 4.7.2 重新运行测试并导出单线程 Web 版本，随后部署 `build/web`。在仓库 **Settings → Pages → Source** 中选择 **GitHub Actions** 即可启用。

Pull Request 只构建和验证，不部署。当前仓库没有配置远端，因此本地完成不代表已发布到 GitHub。

## 许可

项目代码使用 [MIT License](LICENSE)。界面字体为 Noto Sans SC 子集，其许可见 [assets/fonts/OFL.txt](assets/fonts/OFL.txt)。
