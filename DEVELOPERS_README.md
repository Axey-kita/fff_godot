# 焰刃流光 — 开发者文档

> 本文档基于实际项目架构编写，是理解代码结构和开发新功能的入口。

---

## 一、项目概况

| 项目 | 信息 |
|------|------|
| 引擎 | Godot 4.7 |
| 分辨率 | 800×450 (2D) |
| 运行场景 | `res://scenes/main_menu.tscn` |
| 自动加载 | `GameWorld` (`scripts/game_world.gd`), `AudioManager` (`scripts/audio_manager.gd`) |
| 测试框架 | GUT (Godot Unit Test) |
| 目标平台 | Windows, Android |

---

## 二、目录结构（实际）

```
fff_godot/
├── addons/gut/              # GUT 测试框架插件
├── assets/                  # 资源文件
│   ├── char_ani/            # 角色动画帧贴图（按角色/状态分目录）
│   │   ├── archer/
│   │   ├── assassin/
│   │   ├── rose/
│   │   ├── shadowwarrior/
│   │   └── ...              # 每个角色一个目录
│   ├── fx_*.png             # 特效/弹射物贴图
│   ├── ui_*.png             # UI 元素
│   └── bg_*.png             # 背景图
├── data/                    # 配置数据
│   ├── constants.gd         # 常量（物理、AI预设、难度）
│   └── char_configs.gd      # 角色配置（委托给 CharacterFactory）
├── docs/                    # 设计文档
│   └── char-spec.md         # 角色开发规范（历史文档，仅供参考）
├── maps/                    # 地图场景
│   ├── map_01_battlefield.tscn
│   ├── map_02_towers.tscn
│   └── map_03_voids.tscn.tscn
├── rule/                    # 开发规则（检查清单）
│   └── index.md
├── scenes/                  # Godot 场景文件
│   ├── game.tscn
│   └── main_menu.tscn
├── scripts/                 # 核心代码
│   ├── characters/          # 角色脚本（插件单元）
│   │   ├── character_factory.gd   # 注册表 + 调度器
│   │   ├── archer.gd
│   │   ├── assassin.gd
│   │   ├── dragon_knight.gd
│   │   ├── evoker.gd
│   │   ├── knight.gd
│   │   ├── mage.gd
│   │   ├── paladin.gd
│   │   ├── rose.gd
│   │   ├── shadowwarrior.gd
│   │   └── witch.gd
│   ├── components/          # 组件系统
│   │   ├── component_manager.gd    # 控制器
│   │   ├── char_component.gd       # 基类
│   │   ├── archer_component.gd
│   │   ├── assassin_component.gd
│   │   ├── evoker_component.gd
│   │   ├── paladin_component.gd
│   │   ├── rose_component.gd
│   │   ├── shadowwarrior_component.gd
│   │   └── witch_component.gd
│   ├── systems/             # 通用子系统
│   │   ├── ai_system.gd     # AI 有限状态机
│   │   ├── dash_system.gd   # 冲刺系统
│   │   ├── slow_system.gd   # 减速效果
│   │   └── track.gd         # 寻路 AI
│   ├── fighter.gd           # Fighter 类（角色实体）
│   ├── game.gd              # 主游戏循环 + 渲染
│   ├── game_world.gd        # 全局状态（Autoload）
│   ├── skill.gd             # 技能类
│   ├── frame_animation.gd   # 帧动画系统
│   ├── pickup.gd            # 掉落物
│   ├── particle.gd          # 粒子效果
│   ├── status_effect.gd     # 状态效果（燃烧、减速、冰冻等）
│   ├── audio_manager.gd     # 音频管理
│   ├── network.gd           # 网络（PvP）支持
│   ├── map_manager.gd       # 地图管理
│   ├── terrain_tile.gd      # 地形块编辑工具
│   └── touch_controls.gd    # 触控
├── tests/                   # GUT 测试
│   ├── test_ai_bugs.gd
│   ├── test_ai_fsm.gd
│   ├── test_ai_platform.gd
│   ├── test_archer_ai.gd
│   ├── test_assassin_bugs.gd
│   ├── test_assassin_damage.gd
│   ├── test_component_access.gd
│   ├── test_hell_mode.gd
│   ├── test_paladin_bugs.gd
│   └── test_rose_bugs.gd
├── .gutconfig.json          # GUT 配置
├── project.godot            # 项目文件
├── LICENSE
└── struct.md                # 动画引擎架构（历史文档）
```

---

## 三、核心架构

### 3.1 架构分层

```
场景层          main_menu.tscn / game.tscn
    ↑
核心脚本        game.gd → _update() / _draw()
    ↑
全局状态        GameWorld (Autoload) ← 实体、投射物、粒子等
    ↑
实体层          Fighter ← 玩家和 AI 共用
    ├── ComponentManager → CharComponent (角色专属状态)
    └── skills[] → Skill (技能定义)
    ↑
系统层          AISystem / DashSystem / SlowSystem / TrackSystem
    ↑
配置层          CharConfigs → CharacterFactory → 各角色脚本
```

### 3.2 关键数据流

```
每帧 _update() 流程:
  1. GameWorld.frame++
  2. hit_stop 递减
  3. 输入处理 → CharacterFactory.handle_input() → 角色脚本.handle_input()
  4. Fighter.apply_physics() → 组件更新 + 物理 + 攻击判定
  5. CharacterFactory.update_char_systems() → 角色脚本.update_systems()
  6. DashSystem.update_dash() → 冲刺逻辑 + 刺客闪避检测
  7. SlowSystem.update_slow() → 减速效果
  8. AISystem.update_ai() → AI 逻辑（非玩家）
  9. 投射物/粒子/掉落物/状态效果更新
```

---

## 四、组件系统

组件系统用于将角色特定字段从 `Fighter` 类剥离，实现关注点分离。

### 基类 `CharComponent`

| 方法 | 说明 |
|------|------|
| `init(owner)` | 初始化，绑定所属 Fighter |
| `update()` | 每帧更新（计时器递减等） |
| `on_damage_received(attacker, dmg)` | 受伤回调 |
| `on_attack_hit(target, dmg)` | 攻击命中回调 |
| `get_hud_data()` | 返回 HUD 数据字典 |

### 组件类型

| 组件 | 角色 | 管理字段 |
|------|------|----------|
| `assassin_component.gd` | 刺客 | shadow_energy, is_invincible, dodge_slow_mo, slash_active 等 |
| `shadowwarrior_component.gd` | 影武者 | iaido_active, stealth_timer, shadow_trap 等 |
| `rose_component.gd` | 蔷薇 | blood_abyss, skill1_grab, skill2_active 等 |
| `archer_component.gd` | 弓箭手 | arrows, fire_arrow_buff, tracking_buff 等 |
| `paladin_component.gd` | 圣骑士 | holy_empower_active, divine_shield_absorb 等 |
| `witch_component.gd` | 女巫 | is_flying, ult_lock_timer 等 |
| `evoker_component.gd` | 召唤师 | summons, fire_seas 等 |
| `char_component.gd` | 骑士/法师/龙骑士 | 无专属字段（使用基类） |

### 组件访问

```gdscript
# 获取组件（通过 ComponentManager）
var assassin_comp = f.components.get_component("assassin")
if assassin_comp and assassin_comp.is_invincible:
    # 处理无敌逻辑

# 组件在 Fighter.apply_physics() 开头自动更新
```

### 组件创建流程

`Fighter.setup()` → 创建 `ComponentManager` → `ComponentManager._setup_components()` → `CharacterFactory.create_component(char_id, owner)` → 根据注册表创建对应组件类实例

---

## 五、角色插件系统（CharacterFactory）

### 注册表

[`character_factory.gd`](file:///c:/workspace/fff_godot/scripts/characters/character_factory.gd) 维护全局角色注册表：

```gdscript
static var _char_registry := {
    "knight":   { "cls": Knight,   "config": null, "comp": COMP_KNIGHT },
    "mage":     { "cls": Mage,     "config": null, "comp": COMP_MAGE },
    "archer":   { "cls": Archer,   "config": null, "comp": COMP_ARCHER },
    # ... 新增角色在这里加一行
}
```

### 调度方法

| 方法 | 作用 |
|------|------|
| `get_config(id)` | 获取角色配置字典（惰性加载） |
| `create_skills(id)` | 创建技能数组 |
| `handle_input(char_id, fighter, keys)` | 调度角色输入处理（返回 mx） |
| `update_char_systems(fighter)` | 每帧更新角色专属逻辑 |
| `create_component(char_id, owner)` | 创建角色组件 |

### 角色脚本必须实现

| 方法 | 签名 | 说明 |
|------|------|------|
| `get_config()` | `static func get_config() -> Dictionary` | 角色配置 |
| `create_skills()` | `static func create_skills() -> Array` | 技能数组 |

### 角色脚本可选实现

| 方法 | 说明 |
|------|------|
| `handle_input(fighter, keys)` | 自定义输入处理 |
| `update_systems(fighter)` | 每帧专属系统逻辑 |

### get_config() 必须字段

| 字段 | 说明 |
|------|------|
| `id` | 角色 ID，与 registry key 一致 |
| `name` | 显示名称 |
| `hp` | 生命值 |
| `max_energy` | 能量上限 |
| `energy_regen` | 每帧能量回复 |
| `speed` | 移动速度倍率 |
| `attack_range` | 攻击范围（像素，远程角色设为 0） |
| `attack_damage` | 普攻伤害 |
| `attack_cooldown` | 普攻冷却（帧数） |
| `attack_delay` | 攻击判定延迟（帧数） |
| `attack_duration` | 攻击动画时长（帧数） |
| `fields` | Dictionary，角色专属字段（通过 `set()` 动态注入 Fighter） |
| `animations` | Dictionary，含 idle/walk/jump/attack/ult 等 FrameAnimation |
| `world_arrays` | Array，角色使用的世界数组名（如 `["phantoms"]`） |
| `dex` | Dictionary，图鉴数据 |

---

## 六、Fighter 类

> ⚠️ **注意**：本文件不允许角色代码写入，必须用反向注入的方式放入角色自身代码库（`scripts/characters/*.gd` 与 `scripts/components/*.gd`）。

[`fighter.gd`](file:///c:/workspace/fff_godot/scripts/fighter.gd) 是所有角色实体的基类，包含：

### 关键字段分组

| 分组 | 字段 |
|------|------|
| 位置/物理 | `pos_x`, `pos_y`, `vx`, `vy`, `w`, `h`, `facing`, `grounded` |
| 身份 | `char_id`, `is_player`, `config`, `skills[]`, `components` |
| 生命/能量 | `hp`, `max_hp`, `energy`, `max_energy`, `energy_regen` |
| 战斗 | `attacking`, `attack_timer`, `attack_delay`, `attack_damage` |
| 状态 | `dashing`, `blocking`, `shield_active`, `charging` |
| 无敌 | `is_invincible`, `invincible_timer`（通用） |
| 状态标志 | `state_flags: Dictionary`（跨系统通信黑板） |

### 关键方法

| 方法 | 说明 |
|------|------|
| `setup(x, y, is_player, char_id, skills)` | 初始化 Fighter |
| `apply_physics()` | 物理更新 + 组件更新 + 攻击判定 |
| `apply_damage(target, dmg, attacker, knockback, color)` | **静态方法**：统一伤害入口 |
| `get_hit_box()` | 受击体积（刺客冲刺时沿方向延伸 25px） |
| `get_attack_box()` | 攻击判定框 |
| `set_animation_state(state_key)` | 切换动画状态 |
| `emit_particles(...)` | 静态方法：发射粒子 |
| `grab_fighter_in_rect(grabber, area, teleport_x)` | 静态方法：抓取对手 |

### 伤害流程 (`apply_damage`)

1. 刺客闪避检测（冲刺+无敌）→ 完全免疫 + 积攒暗影能量
2. 刺客无敌 → 免疫
3. 通用无敌 → 免疫
4. 格挡 → 弹开攻击者
5. 护盾 → 吸收（50% 转为治疗）
6. 计算伤害（攻击增益、神圣增幅、龙化加成）
7. 神圣壁垒 → 吸收 + 转能量
8. 暗影游走暴击判定
9. 圣佑/龙鳞/龙化减免
10. 应用最终伤害

---

## 七、技能系统

[`skill.gd`](file:///c:/workspace/fff_godot/scripts/skill.gd) 定义技能的数据和行为：

```gdscript
var key: String         # 技能键名（"attack", "skill1", "skill2", "ult"）
var skill_name: String  # 显示名称
var cooldown: int       # 冷却帧数
var energy_cost: int    # 能量消耗
var cd: int             # 当前冷却
var can_use_func: Callable  # 额外使用条件
var execute_func: Callable  # 执行回调
```

**禁用 `owner.char_id == "xxx"` 判断**：技能使用条件通过配置驱动和 `can_use_func` Callable 实现。

---

## 八、帧动画系统

[`frame_animation.gd`](file:///c:/workspace/fff_godot/scripts/frame_animation.gd) 是纯数据+计时层：

- 不含渲染位置信息（通过 `position_spec` 外部注入）
- 渲染由 `game.gd` 的 `_draw_fighter()` 统一处理

### 加载动画

```gdscript
# 单帧静态（idle/duration 用 999.0 表示无限）
FrameAnimation.load_from_frames(DIR + "idle/", "char_idle_f_", [
    {"index": 1, "duration": 999.0}
], true)

# 多帧序列
FrameAnimation.load_from_frames(DIR + "ult/", "char_ult_f_", [
    {"index": 1, "duration": 0.8},
    {"index": 2, "duration": 0.1},
], false)
```

### 动画状态切换

```gdscript
# Fighter 中统一切换
f.set_animation_state("idle")  # 自动从 config["animations"] 查找
```

---

## 九、系统脚本

### AI 系统 ([`ai_system.gd`](file:///c:/workspace/fff_godot/scripts/systems/ai_system.gd))

- 有限状态机 (`IDLE` / `APPROACH` / `ATTACK` / `DODGE` / `JUMP`)
- 通过 `Constants.AI_PRESETS` 配置难度
- 难度等级: easy → medium → hard → hell

### 冲刺系统 ([`dash_system.gd`](file:///c:/workspace/fff_godot/scripts/systems/dash_system.gd))

- 处理冲刺移动和碰撞
- 刺客「一瞬」闪避检测：连续碰撞检测（路径矩形与投射物相交）

### 减速系统 ([`slow_system.gd`](file:///c:/workspace/fff_godot/scripts/systems/slow_system.gd))

- 每帧应用减速因子

### 寻路系统 ([`track.gd`](file:///c:/workspace/fff_godot/scripts/systems/track.gd))

- 基于平台的有向可达图寻路
- 支持跳跃决策和路径规划

---

## 十、GameWorld 全局状态

[`game_world.gd`](file:///c:/workspace/fff_godot/scripts/game_world.gd) 是 Autoload 单例，管理：

| 类别 | 内容 |
|------|------|
| 游戏状态 | `game_running`, `game_over`, `game_mode`, `difficulty`, `frame` |
| 实体 | `player`, `enemy`, `entities[]` |
| 世界数组 | `projectiles[]`, `particles[]`, `pickups[]`, `flame_zones[]` 等 |
| 慢动作 | `slow_mo_timer`, `slow_mo_tick`, `SLOW_FACTOR` |
| 镜头 | `camera`, `screen_shake` |
| 平台 | `platforms[]` |

---

## 十一、游戏循环

### `_update()` 主循环（game.gd）

1. 全局时钟暂停检测（hit_stop / slow_motion）
2. 输入采集 → `CharacterFactory.handle_input()`
3. `Fighter.apply_physics()`（物理 + 攻击判定）
4. `CharacterFactory.update_char_systems()`（角色专属逻辑）
5. `DashSystem.update_dash()`（冲刺）
6. `SlowSystem.update_slow()`（减速）
7. `AISystem.update_ai()`（AI）
8. 各世界数组更新（投射物、粒子、掉落物、火焰区域等）
9. 碰撞检测和伤害结算
10. 摄像头追踪

### `_draw()` 渲染管线

1. 地图绘制（`drawMap()`）
2. 角色实体绘制（`_draw_fighter()`）
3. Overlay 动画绘制
4. 投射物/粒子/掉落物绘制
5. 角色专属特效绘制（玫瑰刀光、刺客次元斩等）
6. HUD 绘制

---

## 十二、测试

### 测试框架

使用 GUT (Godot Unit Test)，配置文件见 [`.gutconfig.json`](file:///c:/workspace/fff_godot/.gutconfig.json)。

### 运行测试

```bash
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

### 测试命名规范

- 测试文件放在 `tests/` 目录
- 命名格式：`test_<功能>.gd`
- 文件前缀必须为 `test_`

---

## 十三、地图系统

地图保存在 `maps/` 目录，使用 `MapManager` 管理。

### 内置地图

- `map_01_battlefield.tscn` — 战场
- `map_02_towers.tscn` — 塔楼
- `map_03_voids.tscn.tscn` — 虚空

### 地形块类型

通过 `TerrainTile` 编辑器的 `tile_type` 枚举标识：
- `GROUND` — 地面
- `WALL` — 墙壁
- `PLATFORM` — 平台
- `VOID` — 虚空（无碰撞）
- `FIRE` — 火焰区域
- `WATER` — 水域

---

## 十四、常量与配置

### [`constants.gd`](file:///c:/workspace/fff_godot/data/constants.gd)

| 常量 | 值 | 说明 |
|------|-----|------|
| `W`, `H` | 800, 450 | 视口尺寸 |
| `MAP_W` | 2400 | 地图宽度 |
| `GROUND_Y` | 380 | 地面 Y 坐标 |
| `GRAVITY` | 0.22 | 重力加速度 |
| `JUMP_SPEED` | -10.0 | 跳跃初速度 |
| `FRICTION` | 0.88 | 地面摩擦力系数 |
| `FIGHTER_W`, `FIGHTER_H` | 32, 56 | 角色碰撞体尺寸 |

### AI 预设

| 难度 | react | aggro | dodge | skill_rate | move_speed | jump_rate |
|------|-------|-------|-------|------------|------------|-----------|
| easy | 600 | 0.3 | 0.1 | 0.15 | 0.75 | 0.0 |
| medium | 350 | 0.5 | 0.25 | 0.3 | 0.9 | 0.02 |
| hard | 120 | 0.8 | 0.4 | 0.6 | 1.1 | 0.05 |
| hell | 60 | 0.95 | 0.6 | 0.9 | 1.3 | 0.08 |

---

## 十五、命名规范

### 文件前缀

| 前缀 | 用途 | 示例 |
|------|------|------|
| `bg_` | 背景图 | `bg_main_menu.png` |
| `ui_` | UI 元素 | `ui_btn_pve.png` |
| `fx_` | 特效贴图 | `fx_explosion.png` |
| `{char_id}_` | 角色帧贴图 | `knight_idle_f_1.png` |

### 动画帧文件格式

```
{char_id}_{state}_f_{index}.png
```

- `{char_id}`：角色标识（如 `knight`, `archer`）
- `{state}`：动画状态（`idle`, `walk`, `jump`, `attack`, `ult`, `charge`）
- `{index}`：帧序号，从 1 开始

---

## 十六、Git 工作流

### 分支策略

```
main
  ├── feat/{描述}         ← 新功能
  ├── fix/{描述}          ← 修复
  ├── refactor/{描述}     ← 重构
  └── docs/{描述}         ← 文档
```

### 强制规则

- 使用 `git add <具体文件>`（禁止 `git add -A` / `git add .`）
- 每个 commit 只做一件事
- commit message 用中文，格式：`类型: 简述`

---

## 十七、新增角色清单

1. [`character_factory.gd`](file:///c:/workspace/fff_godot/scripts/characters/character_factory.gd) — registry 加一行 + preload 脚本和组件
2. `scripts/characters/xxx.gd` — 实现 `get_config()` + `create_skills()`（可选实现 `handle_input()`, `update_systems()`）
3. `scripts/components/xxx_component.gd` — 如需要专属组件（继承 `CharComponent`）
4. `assets/char_ani/xxx/` — 创建动画帧目录（idle/walk/jump/attack/ult）
5. 动画使用 `FrameAnimation.load_from_frames()`（不使用 timetable.txt）
6. 所有图像数据使用 `FrameAnimation` 包装

### 不允许修改的文件

- `systems/` 下任何文件
- `fighter.gd`（除非通用逻辑变更）
- `skill.gd`
- `game.gd`
- `game_world.gd`

---

## 十八、关键架构原则

1. **角色即插件** — 添加角色只需 registry 加一行 + 创建脚本 + 放置贴图
2. **组件隔离** — 角色专属字段在组件中管理，`Fighter` 只保留通用字段
3. **配置驱动** — 行为差异通过 `config` 配置，不使用 `match char_id`
4. **黑板通信** — 组件通过 `Fighter.state_flags` + 信号与系统层通信
5. **统一伤害入口** — `Fighter.apply_damage()` 处理所有伤害类型和闪避检测
