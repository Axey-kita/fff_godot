# struct.md — fff_godot 动画引擎架构重构

## 一、设计目标

将分散的两套动画系统（`images` 字典 + `FrameAnimation` 播片）统一为单一动画引擎。

**核心原则：**
- `FrameAnimation` 纯数据+计时，不做上帝类
- 渲染位置通过 `position_spec` 依赖注入，与动画逻辑完全解耦
- 所有角色状态（idle/walk/jump/attack/skill1/skill2/ult/charge）都是 `FrameAnimation`
- 良好的可扩展性：新增角色/动画只需添加目录 + timetable，不改代码

---

## 二、核心类型

### 2.1 FrameAnimation（纯动画层）

```gdscript
class_name FrameAnimation
extends RefCounted

class FrameData:
    var texture: Texture2D
    var duration_seconds: float

var frames: Array[FrameData] = []
var total_duration: float = 0.0
var loop: bool = false
var anim_id: String = ""

# 运行时
var _timer: float = 0.0
var _current_index: int = 0
var _playing: bool = false
var _finished: bool = false

func play()                    # 从头播放
func stop()                    # 停止
func update(frame_dt: float)   # 计时推进
func get_current_texture() -> Texture2D
func is_playing() -> bool
func is_finished() -> bool
func get_progress() -> float   # 0.0 ~ 1.0

static func load_from_dir(dir_path: String, prefix: String,
                          timetable_path: String, loop: bool = false) -> FrameAnimation
```

**职责边界：** 只管理「frame → 持续时间」的时序。不知道自己在屏幕的哪里、以什么大小绘制。

### 2.2 PositionSpec（位置注入层）

所有需要渲染的动画通过 `position_spec` 描述绘制位置，由 `game.gd` 统一解析：

```gdscript
# 跟随角色
{"type": "follow", "target": fighter_ref, "offset": Vector2(0, 0)}

# 全屏拉伸
{"type": "fullscreen"}

# 固定屏幕坐标
{"type": "fixed", "rect": Rect2(x, y, w, h)}

# 固定世界坐标（随镜头滚动）
{"type": "world", "x": 100.0, "y": 200.0, "scale": Vector2(1, 1)}
```

**职责边界：** 只描述位置规则。不知道动画内容、不持有纹理引用。

### 2.3 AnimationEntry（胶水层）

把动画和位置粘合在一起，存储在 `GameWorld` 中：

```gdscript
# GameWorld 中的条目
var active_overlays: Array = []   # 技能特效、大招等 overlay
# 条目结构:
# {
#     "anim": FrameAnimation,
#     "position": PositionSpec,
#     "owner": Fighter,         # 谁触发的（用于伤害归属）
#     "z_order": int,           # 绘制顺序
#     "on_finish": Callable,    # 动画结束回调
# }
```

角色本体动画**不走**该数组，而是直接挂在 `Fighter` 上。

### 2.4 Fighter 上的动画

```gdscript
# Fighter 新增字段
var current_anim: FrameAnimation = null   # 当前状态的动画
var image_state: String = "idle"          # 保留，作为动画切换的 key

# Fighter 新增方法
func set_animation_state(state_key: String):
    if image_state == state_key:
        return
    image_state = state_key
    current_anim = config["animations"].get(state_key)
    if current_anim:
        current_anim.play()
```

`_draw_fighter()` 从 `fighter.current_anim.get_current_texture()` 取纹理，在角色屏幕坐标绘制。

---

## 三、文件目录结构

```
assets/char_ani/
├── rose/
│   ├── idle/          rose_idle_f_1.png + timetable.txt
│   ├── walk/          rose_walk_f_1.png + timetable.txt
│   ├── jump/          rose_jump_f_1.png + timetable.txt
│   ├── attack/        rose_attack_f_1.png + timetable.txt
│   ├── skill1/        rose_skill1_f_1.png + timetable.txt
│   ├── skill2/        rose_skill2_f_1.png + timetable.txt
│   ├── ult/           rose_ult_f_1~6.png + timetable.txt
│   └── charge/        rose_charge_f_1.png + timetable.txt
│
├── assassin/
│   ├── idle/          assassin_idle_f_1.png + timetable.txt
│   ├── walk/          (同 idle 或独立)
│   ├── jump/          ...
│   ├── attack/        ...
│   ├── skill1/        ...
│   ├── skill2/        ...
│   ├── ult/           assassin_ult_f_0~20.png + timetable.txt
│   │                   (从 assassin_u/ 的 0~13.jpg + 无标题9x.png 重命名迁移)
│   └── charge/        ...
│
├── knight/
├── mage/
├── archer/
├── paladin/
├── witch/
├── shadowwarrior/
│   ├── ult/           shadowwarrior_iaido_f_1.png + timetable.txt
│   │                   (从 shadowwarrior_iaido_ani/ 迁移)
├── evoker/
│
└── shared/            # 多角色共用的特效动画（可选，未来扩展）
```

### 命名规范

- **文件**: `{角色}_{状态}_f_{序号}.{ext}`
  - 例: `rose_idle_f_1.png`, `assassin_ult_f_0.png`
- **目录**: `assets/char_ani/{角色}/{状态}/`
- **Timetable**: 每个目录下固定名为 `timetable.txt`

---

## 四、Timetable 格式

```
格式: frameN::Xs[::optional_filename]

frameN  → 加载 {prefix}_f_{N}.png
::Xs    → 该帧持续时间（秒）
::name  → 可选，覆盖默认文件名（用于跨帧复用）
end frames → 结束标记
```

**示例 — 单帧 idle：**
```
frame1::999s
end frames
```
loop=true 时，播放到末尾自动回到开头。

**示例 — 多帧 ult：**
```
frame0::0.2s
frame1::0.2s
frame2::0.3s
frame3::0.1s::assassin_ult_f_0.png    # 帧复用：引用 frame0 的图
end frames
```

---

## 五、渲染管线

### game.gd `_draw()` 重构后流程：

```
_draw():
  1. drawMap()
  
  2. # === 角色本体（POSITIONED 隐式） ===
     for fighter in entities:
         var tex = fighter.current_anim.get_current_texture()
         if tex:
             draw at fighter's screen pos (world→screen + facing flip)
  
  3. # === overlay 动画（统一 position_spec 解析） ===
     for entry in GameWorld.active_overlays:
         var tex = entry.anim.get_current_texture()
         if not tex: continue
         match entry.position.type:
             "fullscreen":
                 draw_texture_rect(tex, full_rect)
                 draw border effect based on entry.owner.char_id
             "fixed":
                 draw_texture_rect(tex, entry.position.rect)
             "follow":
                 var pos = entry.position.target 的屏幕坐标
                 draw at pos with offset
             "world":
                 var screen_pos = world_to_screen(pos)
                 draw at screen_pos
  
  4. drawProjectiles / drawParticles / drawPickups / HUD ...
  5. drawEvoker / drawRoseTrails / drawAssassinSlash ...
```

### 更新管线 `_update()`：

```
_update():
  ...
  CharacterSystems.update_active_overlays()  # tick 所有 overlay
  CharacterSystems.update_assassin_logic()
  CharacterSystems.update_shadowwarrior_logic()
  CharacterSystems.update_rose_logic()
  ...
```

`update_active_overlays()`:
- 遍历 `GameWorld.active_overlays`
- 调用 `entry.anim.update(1)`
- 如果 `anim.is_finished()`，调用 `entry.on_finish` 回调，然后移除条目

---

## 六、迁移计划（开发顺序）

### Phase 1: 纯化 FrameAnimation

- [ ] 从 [frame_animation.gd](file:///c:/workspace/fff_godot/scripts/frame_animation.gd) 删除 `render_mode`、`owner_fighter`、`offset_x/y`、`scale_x/y` 等渲染字段
- [ ] 添加 `loop` 属性（循环播放）
- [ ] 更新 `load_from_dir()` 支持第三列自定义文件名
- [ ] 保证向后兼容 —— rose/assassin/shadowwarrior 现有动画先挂临时兼容层

### Phase 2: 角色动画迁移（先迁一个角色做验证）

- [ ] 创建 `assets/char_ani/rose/{idle,walk,jump,attack,skill1,skill2,ult,charge}/` 目录
- [ ] 将 rose 现有图片复制/移动到对应目录，统一命名为 `rose_{state}_f_1.png`
- [ ] 为每个状态创建 `timetable.txt`
- [ ] 更新 [rose.gd](file:///c:/workspace/fff_godot/scripts/characters/rose.gd) 的 `get_config()`：`"images"` → `"animations"`
- [ ] 更新 [fighter.gd](file:///c:/workspace/fff_godot/scripts/fighter.gd) 的 `apply_physics()`：添加 `set_animation_state()` 调用
- [ ] 更新 [game.gd](file:///c:/workspace/fff_godot/scripts/game.gd) 的 `_draw_fighter()`：从 `current_anim` 取纹理

### Phase 3: 其余角色迁移

- [ ] 刺客 — `assets/char_ani/assassin/`（`assassin_u/` 的 0~13.jpg + 无标题9x 重命名为 `assassin_ult_f_0~20.png`）
- [ ] 影武者 — `assets/char_ani/shadowwarrior/`（合并 `shadowwarrior_iaido_ani/`）
- [ ] 骑士 / 法师 / 弓箭手 / 圣骑士 / 女巫 / 召唤师

### Phase 4: overlay 系统重构

- [ ] `GameWorld.active_animations` → `GameWorld.active_overlays`
- [ ] 条目加 `position_spec` 和 `on_finish` callback
- [ ] 删除 [character_systems.gd](file:///c:/workspace/fff_godot/scripts/systems/character_systems.gd) 中的 `_cleanup_animation()`，改用 `on_finish` callback
- [ ] `game.gd` 渲染改为统一 position_spec 解析

### Phase 5: 清理

- [ ] 删除 `images` 字典相关代码
- [ ] 删除 `Constants.ANIM_STATES` 死代码（或启用）
- [ ] 删除旧动画目录（`rose_utl_ani/`, `assassin_ult_ani/`, `shadowwarrior_iaido_ani/`）
- [ ] 添加 warning：`image_state` key 不存在时输出日志

### Phase 6: 优化

- [ ] `image_state` 写入统一入口（消除三重写入）
- [ ] 全屏 FrameAnimation 期间跳过角色本体绘制
- [ ] 骑士 debug print 清理
- [ ] Fighter 字段拆分（低优先级）

---

## 七、文件影响范围

| 文件 | 改动类型 |
|------|---------|
| `scripts/frame_animation.gd` | **重写** — 纯化为数据+计时，去掉渲染字段，加 loop |
| `scripts/fighter.gd` | **修改** — 加 `current_anim`/`set_animation_state()` |
| `scripts/game.gd` | **修改** — `_draw()` 重构，`_draw_fighter()` 查 current_anim |
| `scripts/game_world.gd` | **修改** — `active_animations` → `active_overlays`，加 position_spec |
| `scripts/systems/character_systems.gd` | **修改** — `update_active_overlays()` 替代旧的 update，用 on_finish callback |
| `scripts/characters/*.gd` (9个) | **修改** — `get_config()` 的 `"images"` → `"animations"` |
| `data/constants.gd` | **修改** — 删除或启用 ANIM_STATES |
| `assets/char_ani/*/` (新) | **新建** — 9 角色 × 5~8 状态的动画目录 |
| `assets/rose_utl_ani/` | **删除** — 迁移后移除 |
| `assets/assassin_ult_ani/` | **删除** — 迁移后移除 |
| `assets/assassin_u/` | **删除** — 迁移后移除（内容移到 char_ani/assassin/ult/） |
| `assets/shadowwarrior_iaido_ani/` | **删除** — 迁移后移除 |

---

## 八、关键设计决策记录

1. **FrameAnimation 不做上帝类** — 不含渲染位置、不含 owner 引用、不含伤害逻辑
2. **position_spec 统一位置注入** — 角色本体隐式跟随，overlay 通过 spec 声明
3. **on_finish callback 替代硬编码 cleanup** — `_cleanup_animation()` 的 match-case 逻辑迁移到各角色注册的 callback
4. **单帧动画和 999s duration + loop** — idle 的 timetable: `frame1::999s`，loop=true
5. **帧复用通过 timetable 第三列实现** — `frame3::0.1s::prefix_f_0.png` 复用第 0 帧的图片
6. **文件命名统一 `{角色}_{状态}_f_{序号}.{ext}`** — 全部 png，jpg 需要转换
