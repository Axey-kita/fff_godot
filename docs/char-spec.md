# 焰刃流光 — 角色开发规范 v1.0

## 〇、核心原则

**角色即插件，添加角色 = 新建一个文件夹 + 新建一个脚本，不修改任何已有系统文件。**

所有角色资源（贴图、动画、音效、技能、系统逻辑、图鉴文本）必须自治地存在于该角色的脚本/资源目录内，通过统一的注册接口动态挂载到游戏引擎中。

---

## 一、目录结构

```
res://
├── chars/                          # 角色根目录（新）
│   ├── char_base.gd                # 角色基类（吸收 Fighter 中角色无关的通用逻辑）
│   ├── char_registry.gd            # 角色注册表（自动发现 + 手动注册）
│   ├── char_component.gd           # 组件基类
│   ├── skill.gd                    # 技能基类（从 scripts/skill.gd 迁移）
│   ├── input_strategy.gd           # 输入策略基类
│   ├── sound_set.gd                # 音效集基类
│   ├── knight/
│   │   ├── knight.gd               # 角色定义（config + 组件注册 + 技能创建）
│   │   ├── knight_input.gd         # 输入策略
│   │   ├── knight_sounds.gd        # 音效定义
│   │   ├── knight_system.gd        # 角色专属系统逻辑（如招架、剑气）
│   │   ├── animations/
│   │   │   ├── idle/               # 帧贴图 + .import
│   │   │   ├── walk/
│   │   │   ├── jump/
│   │   │   ├── attack/
│   │   │   └── ult/
│   │   └── dex.tres                # 图鉴数据（Godot 资源格式，可被编辑器直接编辑）
│   ├── mage/
│   │   └── ...                     # 同上结构
│   └── ...
├── scripts/                        # 引擎系统（不应包含任何角色特定代码）
│   ├── game.gd
│   ├── game_world.gd
│   ├── fighter.gd                  # 通用 Fighter（不应混入角色特定字段）
│   └── systems/
│       ├── ai_system.gd
│       ├── dash_system.gd
│       ├── projectile_system.gd
│       ├── pickup_system.gd
│       └── ...                     # 通用子系统（不含角色硬编码）
└── assets/                         # 公共资源（UI、背景、通用特效）
```

---

## 二、角色注册（char_registry.gd）

每个角色通过一个静态方法 `register()` 声明自己的元信息。注册表在引擎初始化时自动发现或手动遍历。

```gdscript
# chars/char_registry.gd
class_name CharRegistry

static var _chars: Dictionary = {}
static var _input_strategies: Dictionary = {}
static var _char_systems: Dictionary = {}

## 手动注册一个角色（由 chars/ 下的各角色脚本在引擎启动时调用）
static func register(char_script: GDScript):
    var id = char_script.CHAR_ID
    _chars[id] = char_script
    # 可选：注册输入策略
    if char_script.get("INPUT_STRATEGY"):
        _input_strategies[id] = char_script.INPUT_STRATEGY
    # 可选：注册角色专属系统
    if char_script.get("CHAR_SYSTEM"):
        _char_systems[id] = char_script.CHAR_SYSTEM

static func get_char(id: String) -> GDScript:
    return _chars.get(id)

static func get_all_ids() -> Array:
    return _chars.keys()

static func get_input_strategy(id: String):
    return _input_strategies.get(id)

static func get_char_system(id: String):
    return _char_systems.get(id)
```

### 自动发现（推荐方案）

Godot 4 不支持运行时自动扫描脚本，因此使用一个 **manifest 文件** 列出所有角色：

```gdscript
# chars/char_manifest.gd
static var CHAR_LIST := [
    preload("res://chars/knight/knight.gd"),
    preload("res://chars/mage/mage.gd"),
    preload("res://chars/archer/archer.gd"),
    # ... 新增角色只需加一行
]
```

引擎启动时遍历 `CHAR_LIST` 调用 `register()`。**新增角色只需在这里加一行 preload，不需要修改任何系统脚本。**

---

## 三、角色定义脚本（chars/xxx/xxx.gd）

每个角色的 `.gd` 文件是一个自治单元，包含：

```gdscript
# chars/knight/knight.gd
class_name KnightChar
extends RefCounted

const CHAR_ID := "knight"
const CHAR_NAME := "骑士"
const ANI_DIR := "res://chars/knight/animations/"

# ── 可选：输入策略类 ──
const INPUT_STRATEGY = preload("res://chars/knight/knight_input.gd")

# ── 可选：音效集 ──
const SOUND_SET = preload("res://chars/knight/knight_sounds.gd")

# ── 基础属性 ──
static func get_base_stats() -> Dictionary:
    return {
        "hp": 100, "max_energy": 100, "energy_regen": 0.05,
        "speed": 2.25, "attack_range": 44, "attack_damage": 5,
        "attack_cooldown": 60, "attack_delay": 8, "attack_duration": 68,
    }

# ── 组件注册 ──
static func create_components(owner: Fighter) -> Array:
    return []  # knight 无特殊组件

# ── 动画注册 ──
static func create_animations() -> Dictionary:
    return {
        "idle":   FrameAnimation.load_from_frames(ANI_DIR + "idle/",   "knight_idle_f_",   A({"idx":1,"dur":999})),
        "walk":   FrameAnimation.load_from_frames(ANI_DIR + "walk/",   "knight_walk_f_",   A({"idx":1,"dur":999})),
        "jump":   FrameAnimation.load_from_frames(ANI_DIR + "jump/",   "knight_jump_f_",   A({"idx":1,"dur":999})),
        "attack": FrameAnimation.load_from_frames(ANI_DIR + "attack/", "knight_attack_f_", A({"idx":1,"dur":2})),
        "ult":    FrameAnimation.load_from_frames(ANI_DIR + "ult/",    "knight_ult_f_",    A({"idx":1,"dur":3})),
    }

# ── 技能创建 ──
static func create_skills(owner: Fighter) -> Array:
    return [
        SkillDef.new("skill1", "剑气",   480, 20, null, func(): _skill1(owner)),
        SkillDef.new("skill2", "招架",   600, 30, func(): return owner.grounded, func(): _skill2(owner)),
        SkillDef.new("ult",    "爆发斩", 300, 100, null, func(): _ult(owner)),
    ]

# ── 图鉴数据 ──
static func get_dex() -> Dictionary:
    return {
        "icon": "⚔️",
        "intro": "...",
        "skills": [
            {"name": "挥砍", "desc": "..."},
            {"name": "剑气", "desc": "..."},
        ]
    }

# ── 辅助函数 ──
static func A(specs: Array) -> Array:
    return specs

static func _skill1(owner: Fighter): pass  # 实现...
static func _skill2(owner: Fighter): pass
static func _ult(owner: Fighter):   pass
```

**规则：角色脚本中的任何方法不能直接操作 GameWorld / Game 全局状态。** 如需生成弹射物、粒子等，通过 `owner` 提供的接口间接操作。

---

## 四、组件系统（解决 Fighter 字段污染）

当前 `Fighter` 类包含所有 9 个角色的专属字段（`arrows`、`shadow_energy`、`blood_abyss`、`is_flying` 等）。改为**组件（Component）模式**：

```gdscript
# chars/char_component.gd
class_name CharComponent
extends RefCounted

var owner: Fighter

func _init(p_owner: Fighter):
    owner = p_owner

func on_attach():     pass  # 挂载时调用
func on_detach():     pass
func update():        pass  # 每帧更新
func on_hit(target):  pass  # 攻击命中时
func on_damaged():    pass  # 受伤时
```

示例——弓箭手组件：

```gdscript
# chars/archer/archer_arrows.gd
class_name ArcherArrowsComponent
extends CharComponent

var arrows: int = 10
var max_arrows: int = 10
var regen_timer: int = 0

func update():
    regen_timer += 1
    if regen_timer >= 480 and arrows < max_arrows:
        arrows += 1
        regen_timer = 0
```

角色定义中注册组件：

```gdscript
# chars/archer/archer.gd
static func create_components(owner: Fighter) -> Array:
    return [
        ArcherArrowsComponent.new(owner),
        ArcherFireBuffComponent.new(owner),
    ]
```

**Fighter 类不再包含任何角色特定字段。**

---

## 五、输入策略（解决 InputHandler switch）

当前 `InputHandler` 使用 `match char_id` 硬编码 9 个角色的输入逻辑。改为**策略模式**：

```gdscript
# chars/input_strategy.gd
class_name InputStrategy
extends RefCounted

## 返回运动方向 mx（-1/0/1）
func get_movement(owner: Fighter, keys: Dictionary) -> int:
    if keys.left:  return -1
    if keys.right: return 1
    return 0

## 处理技能输入（返回 true 表示输入已被消费）
func handle_attack(owner: Fighter, keys: Dictionary) -> bool:
    return false

func handle_skill1(owner: Fighter, keys: Dictionary) -> bool:
    return false

func handle_skill2(owner: Fighter, keys: Dictionary) -> bool:
    return false

func handle_ult(owner: Fighter, keys: Dictionary) -> bool:
    return false

## 每帧更新（用于蓄力等持续输入逻辑）
func update(owner: Fighter, keys: Dictionary):
    pass
```

每个角色可重写此基类，或使用默认策略（适用于 knight / evoker 等标准操作角色）。

---

## 六、角色专属系统（解决 CharacterSystems 污染）

当前 `character_systems.gd` 硬编码了 assassin / shadowwarrior / rose 的每帧逻辑。改为**订阅模式**：

```gdscript
# 在游戏主循环中
for char_id in CharRegistry.get_all_ids():
    var sys = CharRegistry.get_char_system(char_id)
    if sys:
        sys.update(GameWorld.entities)  # 只更新当前活跃的该角色实体
```

每个角色可选定义一个 System 类：

```gdscript
# chars/assassin/assassin_system.gd
class_name AssassinSystem
extends RefCounted

static func update(entities: Array):
    for f in entities:
        if f.char_id != "assassin" or f.hp <= 0:
            continue
        # ... 刺客专属逻辑（暗影能量、次元斩等）
```

**character_systems.gd 不再包含任何角色特定代码**，只做调度。

---

## 七、音效系统

每个角色可定义一个音效集：

```gdscript
# chars/knight/knight_sounds.gd
class_name KnightSounds
extends RefCounted

const ATTACK   = preload("res://chars/knight/sounds/attack.wav")
const SKILL1   = preload("res://chars/knight/sounds/skill1.wav")
const SKILL2   = preload("res://chars/knight/sounds/skill2.wav")
const ULT      = preload("res://chars/knight/sounds/ult.wav")
const HURT     = preload("res://chars/knight/sounds/hurt.wav")
```

音频管理器根据 `owner.char_id` 查找对应的 `SoundSet`，通过事件名播放。

---

## 八、图鉴数据

图鉴信息从角色的 `get_dex()` 动态获取，不硬编码在任何系统 UI 脚本中。支持 `.tres` 资源文件，可在 Godot 编辑器中直接编辑。

---

## 九、迁移路线图

| 阶段 | 内容 | 影响文件 |
|------|------|----------|
| **Phase 1** | 创建 `chars/` 目录结构 + `CharRegistry` + manifest | 新增 |
| **Phase 2** | 实现 `CharComponent` + 将 Fighter 中角色字段抽离为组件 | fighter.gd |
| **Phase 3** | 每个角色迁移到独立目录 + 实现 `register()` | 各角色脚本 |
| **Phase 4** | 输入策略模式替代 InputHandler switch | input_handler.gd |
| **Phase 5** | 角色系统解耦，从 character_systems.gd 中移出 | character_systems.gd |
| **Phase 6** | 音效插件化 | audio_manager.gd |

### 检查清单（Phase 完成后应确保）

- [ ] `InputHandler` 中无 `match char_id`
- [ ] `CharacterSystems` 中无角色特定逻辑
- [ ] `Fighter` 中无角色特定字段
- [ ] `Skill.can_use` 中无 `char_id == "archer"` 硬编码
- [ ] `game.gd` `_draw()` 中无角色特定绘制
- [ ] 新增角色只需创建 `chars/newchar/` 目录 + 在 manifest 加一行

---

## 十、反模式（不应再出现）

```gdscript
# ❌ 在系统脚本中硬编码角色 ID
match p.char_id:
    "knight": _input_knight(p, keys)
    "mage":   _input_mage(p, keys)
    ...

# ❌ 在 Fighter 中混入角色特定字段
var arrows: int = 10        # 只有 archer 用
var blood_abyss: float = 0  # 只有 rose 用
var is_flying: bool = false # 只有 witch 用

# ❌ 在技能系统中硬编码例外
if owner.attacking and owner.char_id != "archer":
    return false

# ✅ 正确做法
var strategy = CharRegistry.get_input_strategy(p.char_id)
strategy.update(p, keys)
```
