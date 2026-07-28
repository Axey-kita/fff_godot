# 天赋系统设计方案

> **状态：已定稿**
> 基于 `talent_draft.md` 伪代码思路 + 现有架构分析后的融合方案。

---

## 一、天赋定义

天赋是**独立于角色技能之外、可装配的能力模块**，可以是主动技能式的，也可以是被动效果。

### 天赋 vs 技能 vs 组件

```
技能 (Skill)          — 角色的核心战斗能力（攻击、技能1/2、大招），由角色脚本定义
组件 (CharComponent)  — 角色的专属状态管理（暗影能量、血渊、箭矢数），由角色脚本定义
天赋 (Talent)         — 跨角色/可配置的能力模块，独立于角色脚本定义
```

---

## 二、核心架构

### 2.1 TalentInstance — 天赋运行时实例

```gdscript
# scripts/talents/talent_instance.gd
class_name TalentInstance
extends RefCounted

var talent_id: String = ""
var talent_name: String = ""
var description: String = ""
var icon: String = ""
var is_skill: bool = false          # true=主动(需按键), false=被动
var compatible_chars: Array = []    # 空=所有角色可用, 非空=白名单

# 行为回调（由工厂函数赋值）
var on_attach: Callable = func(): pass
var update: Callable = func(): pass
var can_activate: Callable = func(): return false
var activate: Callable = func(): return {"success": false}

# 事件回调（字典参数：永不参数不匹配，新增字段不影响已有天赋）
# 约定字段见第五节
var on_damage_dealt: Callable = func(data: Dictionary): pass
var on_damage_received: Callable = func(data: Dictionary): pass
var on_skill_used: Callable = func(data: Dictionary): pass
var on_dodge: Callable = func(data: Dictionary): pass
var on_kill: Callable = func(data: Dictionary): pass
```

### 2.2 TalentPool — 注册表 + 工厂

参考 `CharacterFactory._char_registry` 模式，使用字典注册，工厂函数返回 `TalentInstance`。

```gdscript
# scripts/talents/talent_pool.gd
class_name TalentPool

static var _registry := {}

static func init():
	if not _registry.is_empty():
		return
	_register_all()

static func _register_all():
	_registry["vitality"]     = { "factory": _make_vitality }
	_registry["thorns"]       = { "factory": _make_thorns }
	_registry["vampiric"]     = { "factory": _make_vampiric }
	_registry["blaze_rush"]   = { "factory": _make_blaze_rush }
	# 新增天赋在这里加一行

static func create(talent_id: String, fighter: Fighter) -> TalentInstance:
	var entry = _registry.get(talent_id)
	if not entry:
		return null
	var inst: TalentInstance = entry["factory"].call(fighter)
	inst.talent_id = talent_id
	return inst

static func get_all_ids() -> Array:
	return _registry.keys()
```

### 2.3 Fighter.`ad` — 天赋专属命名空间

`Fighter` 提供一个字典，天赋按 `talent_id` 隔离存储通用运行时状态（冷却、标志、计数器等）。

```gdscript
# fighter.gd
var ad: Dictionary = {}  # { talent_id: { ...自由字段... } }
```

访问方式：

```gdscript
# 烈焰冲刺的冷却
fighter.ad["blaze_rush"] = {"cd": 0}
```

**约束**：天赋只读写 `ad[talent_id]` 下的内容，不同天赋永远不会冲突。

### 2.4 StatMod — 属性修饰系统

用于管理「多个天赋叠加同一属性」的场景。属性修饰和 `ad` 分开，`ad` 管内部状态，StatMod 管属性叠加。

```gdscript
# fighter.gd 新增
var _stat_base: Dictionary = {}   # 属性原始值快照
var _stat_mods: Dictionary = {}   # { attr: [{ source, add, mul }, ...] }

# setup() 中拍快照
func _snapshot_stats():
	for key in ["max_hp", "max_energy", "attack_damage", "speed", "defense"]:
		_stat_base[key] = get(key)

# 天赋通过此 API 注册修饰
func add_stat_mod(attr: String, source: String, add: float = 0.0, mul: float = 1.0):
	_stat_mods[attr] = _stat_mods.get(attr, [])
	_stat_mods[attr].append({"source": source, "add": add, "mul": mul})
	_recalc_stat(attr)

# 以下为内部方法
func _recalc_stat(attr: String):
	var base = _stat_base.get(attr, get(attr))
	var total_add = 0.0
	var total_mul = 1.0
	for m in _stat_mods.get(attr, []):
		total_add += m.add
		total_mul *= m.mul
	set(attr, (base + total_add) * total_mul)
```

计算顺序：全部 ADD 加总 → 全部 MUL 连乘。同组内可交换，顺序不敏感。

天赋示例：

```gdscript
# 生命强化（add=0, mul=1.2）
f.add_stat_mod("max_hp", "talent.vitality", 0.0, 1.2)

# 生命祝福（add=50, mul=1.0）
f.add_stat_mod("max_hp", "talent.blessing", 50.0, 1.0)

# 结果: (100 + 50) × 1.2 = 180
```

### 2.5 hp_changed / energy_changed 信号

用于天赋响应血量、能量变化（如"低血量触发"、"能量汲取"）。

```gdscript
# fighter.gd
signal hp_changed(old_val: float, new_val: float)
signal energy_changed(old_val: float, new_val: float)

# apply_damage 中应用伤害后
var old_hp = target.hp
target.hp -= final_dmg
target.hp = maxf(0.0, target.hp)
target.hp_changed.emit(old_hp, target.hp)
```

天赋订阅：

```gdscript
# 天赋 on_attach
f.hp_changed.connect(func(old, new):
	if new < f.max_hp * 0.3:
		# 低血量触发的效果
		pass
)
```

注意：`hp_changed` 是常规信号，不是天赋事件总线的一部分。天赋可以选择连接它，也可以不走它（在 `on_damage_received` 回调里直接处理）。

### 2.6 TalentManager — Fighter 上的管理器

```gdscript
# scripts/talents/talent_manager.gd
class_name TalentManager
extends RefCounted

var talents: Array[TalentInstance] = []
var owner: Fighter = null

func init(fighter: Fighter, talent_ids: Array):
	owner = fighter
	for tid in talent_ids:
		var t = TalentPool.create(tid, fighter)
		if t:
			t.on_attach.call()
			talents.append(t)

func update():
	for t in talents:
		t.update.call()

# ── 事件分发（字典化） ──
func on_damage_dealt(data: Dictionary):
	for t in talents:
		if t.on_damage_dealt.is_valid():
			t.on_damage_dealt.call(data)

func on_damage_received(data: Dictionary):
	for t in talents:
		if t.on_damage_received.is_valid():
			t.on_damage_received.call(data)

func on_kill(data: Dictionary):
	for t in talents:
		if t.on_kill.is_valid():
			t.on_kill.call(data)

# 主动天赋接口
func activate_slot(index: int) -> Dictionary:
	if index < 0 or index >= talents.size():
		return {"success": false}
	var t = talents[index]
	if not t.is_skill:
		return {"success": false}
	if not t.can_activate.call():
		return {"success": false}
	return t.activate.call()
```

---

## 三、生命周期

```
游戏启动
  └─ TalentPool.init() 加载所有天赋注册

战斗开始 (Fighter.setup)
  ├─ _init_from_config()  ← 天赋还没装
  ├─ skills 创建完成
  ├─ talent 装配：Fighter 接收 talent_ids 列表
  │    └─ TalentManager.init(fighter, ["vitality", "thorns"])
  │         ├─ 每个天赋 TalentPool.create()
  │         └─ 每个天赋 on_attach.call()  ← 此时直接改 Fighter 字段 + 记 ad
  └─ 后续系统启动，读到的是天赋修改后的值

战斗中
  ├─ 被动天赋：TalentManager.dispatch() 广播事件
  ├─ 主动天赋：TalentManager.activate_slot() 触发
  └─ 需 tick 的：TalentManager.update() 每帧调用

战斗结束 (fighter 释放)
  └─ 自动销毁，不需要清理
```

---

## 四、主动天赋的按键绑定

### Fighter 天赋槽位

```gdscript
# fighter.gd
var talent_slots: Array[TalentInstance] = []  # 装配时自动填充 is_skill=true 的天赋
```

### 装配时填充

```gdscript
# talent_manager.gd init() 中
if t.is_skill:
	fighter.talent_slots.append(t)
```

### 输入触发

```gdscript
# game.gd _input() / _process()
if keys.talent1 and player.talent_manager:
	player.talent_manager.activate_slot(0)
```

### HUD 显示

```gdscript
# game.gd _draw() 或独立 UI 节点
for i in player.talent_slots.size():
	var t = player.talent_slots[i]
	# 绘制天赋按钮（图标、冷却状态）
```

---

## 五、事件系统与递归防护

### 5.1 字典约定

每个事件分发的 Dictionary 包含以下字段：

| 事件 | 字典字段 |
|------|---------|
| `on_damage_dealt` | `fighter`, `target`, `damage`, `source`, `recursion_depth` |
| `on_damage_received` | `fighter`, `attacker`, `damage`, `source`, `recursion_depth` |
| `on_kill` | `fighter`, `target` |
| `on_skill_used` | `fighter`, `skill_key` |
| `on_dodge` | `fighter` |

天赋通过具名字段取用：

```gdscript
# 荆棘天赋
inst.on_damage_received = func(data: Dictionary):
	var attacker = data.get("attacker")
	var dmg = data.get("damage", 0)
	var depth = data.get("recursion_depth", 0)
	# ...
```

### 5.2 EventBus

```gdscript
# scripts/talents/talent_event_bus.gd
class_name TalentEventBus

const MAX_RECURSION := 3

static func emit_damage_dealt(fighter: Fighter, target: Fighter, dmg: float,
		source: String, recursion_depth: int = 0):
	if recursion_depth >= MAX_RECURSION:
		return
	if not fighter or not fighter.talent_manager:
		return
	if source.begins_with("talent."):
		return  # 天赋来源的伤害不再触发事件
	fighter.talent_manager.on_damage_dealt({
		"fighter": fighter,
		"target": target,
		"damage": dmg,
		"source": source,
		"recursion_depth": recursion_depth,
	})

static func emit_damage_received(fighter: Fighter, attacker: Fighter, dmg: float,
		source: String, recursion_depth: int = 0):
	if recursion_depth >= MAX_RECURSION:
		return
	if not fighter or not fighter.talent_manager:
		return
	if source.begins_with("talent."):
		return
	fighter.talent_manager.on_damage_received({
		"fighter": fighter,
		"attacker": attacker,
		"damage": dmg,
		"source": source,
		"recursion_depth": recursion_depth,
	})

static func emit_kill(fighter: Fighter, target: Fighter):
	if fighter and fighter.talent_manager:
		fighter.talent_manager.on_kill({"fighter": fighter, "target": target})
```

### 5.3 apply_damage 集成

```gdscript
static func apply_damage(target: Fighter, dmg: float, attacker: Fighter,
	knockback: bool = true,
	hit_color: Color = Color(1.0, 0.53, 0.27),
	sound_name: String = "hit_enemy",
	damage_source: String = "",
	recursion_depth: int = 0):  # ← 递归深度参数化
```

`apply_damage` 末尾：

```gdscript
# 应用伤害
var old_hp = target.hp
target.hp -= final_dmg
target.hp = maxf(0.0, target.hp)
target.hp_changed.emit(old_hp, target.hp)

# 广播事件
TalentEventBus.emit_damage_dealt(attacker, target, final_dmg, damage_source, recursion_depth)
TalentEventBus.emit_damage_received(target, attacker, final_dmg, damage_source, recursion_depth)

# 击杀判定
if target.hp <= 0:
	TalentEventBus.emit_kill(attacker, target)
```

### 5.4 递归阻断演示

```
A 攻击 B (depth=0)
  ├─ B 荆棘反弹 A (depth=1, source="talent.thorns")
  │    ├─ 事件被 source 过滤，不触发 B 的天赋 on_damage_dealt
  │    └─ 事件被 source 过滤，不触发 A 的天赋 on_damage_received
  │    └─ 对 A 造成伤害（depth=1）
  │         └─ A 荆棘反弹 B (depth=2) → 继续但不会无限
  │              └─ ...
  └─ (同时) 环境火焰灼烧 B (depth=0, source="env.fire")
       └─ 独立链，不受影响

A 荆棘反弹 C 荆棘反弹 → depth=3 ≥ MAX → 第4层被阻断
```

---

## 六、配置系统

```gdscript
# data/talent_configs.gd
class_name TalentConfigs

static var data := {
	"vitality": {
		"hp_mult": 1.2,
		"max_stack": 3,
		"stack_add": 0.2,
	},
	"thorns": {
		"reflect_dmg": 3.0,
		"reflect_per_stack": 1.5,
	},
	"blaze_rush": {
		"dash_damage": 10,
		"cooldown": 300,
	},
	"vampiric": {
		"heal_pct": 0.1,
		"heal_per_stack": 0.05,
	},
}

static func get(id: String) -> Dictionary:
	return data.get(id, {})
```

工厂函数读取配置，不写死数值。

---

## 七、天赋示例

### 7.1 生命强化（被动属性）

```gdscript
static func _make_vitality(f: Fighter) -> TalentInstance:
	var cfg = TalentConfigs.get("vitality")
	var inst = TalentInstance.new()
	inst.talent_name = "生命强化"
	inst.description = "最大生命值 +%.0f%%" % [(cfg.hp_mult - 1) * 100]
	inst.is_skill = false
	inst.on_attach = func():
		f.add_stat_mod("max_hp", "talent.vitality", 0.0, cfg.hp_mult)
	return inst
```

### 7.2 荆棘（被动事件）

```gdscript
static func _make_thorns(f: Fighter) -> TalentInstance:
	var cfg = TalentConfigs.get("thorns")
	var inst = TalentInstance.new()
	inst.talent_name = "荆棘"
	inst.description = "受击时反弹 %.1f 点伤害" % [cfg.reflect_dmg]
	inst.is_skill = false
	inst.on_damage_received = func(data: Dictionary):
		var attacker = data.get("attacker")
		var depth = data.get("recursion_depth", 0)
		if attacker and attacker.hp > 0:
			Fighter.apply_damage(attacker, cfg.reflect_dmg, f, false,
				Color.GREEN, "hit_enemy", "talent.thorns", depth + 1)
	return inst
```

### 7.3 烈焰冲刺（主动天赋）

```gdscript
static func _make_blaze_rush(f: Fighter) -> TalentInstance:
	var cfg = TalentConfigs.get("blaze_rush")
	var inst = TalentInstance.new()
	inst.talent_name = "烈焰冲刺"
	inst.description = "激活后下次冲刺附带 %d 点火焰伤害" % [cfg.dash_damage]
	inst.is_skill = true
	f.ad["blaze_rush"] = {"cd": 0}
	inst.can_activate = func(): return f.ad["blaze_rush"]["cd"] <= 0
	inst.activate = func():
		if f.ad["blaze_rush"]["cd"] > 0:
			return {"success": false}
		f.ad["blaze_rush"]["cd"] = cfg.cooldown
		f.ad["blaze_rush"]["ready"] = true
		return {"success": true}
	inst.update = func():
		if f.ad["blaze_rush"]["cd"] > 0:
			f.ad["blaze_rush"]["cd"] -= 1
	inst.on_damage_dealt = func(data: Dictionary):
		var target = data.get("target")
		var depth = data.get("recursion_depth", 0)
		if f.ad["blaze_rush"].get("ready") and target:
			f.ad["blaze_rush"]["ready"] = false
			Fighter.apply_damage(target, cfg.dash_damage, f, false,
				Color.ORANGE, "hit_enemy", "talent.blaze_rush", depth + 1)
	return inst
```

### 7.4 嗜血（被动事件）

```gdscript
static func _make_vampiric(f: Fighter) -> TalentInstance:
	var cfg = TalentConfigs.get("vampiric")
	var inst = TalentInstance.new()
	inst.talent_name = "嗜血"
	inst.description = "造成伤害的 %.0f%% 转化为生命值" % [cfg.heal_pct * 100]
	inst.is_skill = false
	inst.on_damage_dealt = func(data: Dictionary):
		var dmg = data.get("damage", 0)
		if dmg > 0:
			f.hp = minf(f.max_hp, f.hp + dmg * cfg.heal_pct)
	return inst
```

### 7.5 能量汲取（跨实体操作）

```gdscript
static func _make_energy_tap(f: Fighter) -> TalentInstance:
	var inst = TalentInstance.new()
	inst.talent_name = "能量汲取"
	inst.description = "造成伤害时减少目标 5 能量"
	inst.is_skill = false
	inst.on_damage_dealt = func(data: Dictionary):
		var target = data.get("target")
		if target and target.energy > 0:
			target.energy = maxf(0, target.energy - 5)
	return inst
```

---

## 八、天赋与角色的兼容性

天赋的 `compatible_chars` 字段声明白名单：

```gdscript
# 弓箭专用天赋
var compatible_chars = ["archer"]

# 通用天赋（空 = 所有角色可用）
var compatible_chars = []
```

`TalentManager.init()` 中过滤：

```gdscript
if t.compatible_chars.size() > 0 and not f.char_id in t.compatible_chars:
	continue  # 不兼容，跳过装配
```

---

## 九、目录结构

```
scripts/talents/
├── talent_instance.gd       # 运行时实例基类
├── talent_pool.gd           # 注册表 + 工厂
├── talent_manager.gd        # Fighter 上的管理器
├── talent_event_bus.gd      # 事件广播（字典化 + 递归深度控制）

scripts/diff: fighter.gd
  ├─ var ad: Dictionary              # 天赋命名空间
  ├─ var talent_manager: TalentManager
  ├─ var talent_slots: Array         # 主动天赋槽位
  ├─ add_stat_mod() / _recalc_stat() # 属性修饰系统
  ├─ signal hp_changed               # 血量变化信号
  ├─ signal energy_changed           # 能量变化信号
  └─ apply_damage() 扩展 damage_source + recursion_depth

data/
└── talent_configs.gd        # 天赋数值配置
```

---

## 十、反模式清单

```gdscript
# ❌ 天赋中引用角色 ID
if owner.char_id == "assassin":
    damage *= 1.5
# ✅ 兼容性通过 compatible_chars 声明

# ❌ 天赋直接改属性字段，不经过 StatMod
owner.max_hp *= 1.2
# ✅ 用 add_stat_mod，自动处理叠加和顺序
owner.add_stat_mod("max_hp", "talent.vitality", 0.0, 1.2)

# ❌ 天赋用位置参数写事件回调（签名不匹配就崩）
inst.on_damage_dealt = func(target, dmg): pass
# ✅ 用字典参数，只取需要的字段
inst.on_damage_dealt = func(data: Dictionary):
    var dmg = data.get("damage", 0)

# ❌ 天赋手动维护递归锁
f.ad["thorns"]["reflecting"] = true
Fighter.apply_damage(...)
f.ad["thorns"]["reflecting"] = false
# ✅ 参数传递 recursion_depth，框架级自动阻断
Fighter.apply_damage(attacker, dmg, f, false, Color.GREEN, "hit_enemy", "talent.thorns", depth + 1)

# ❌ 天赋系统全局轮询
# 禁止每帧检查 hp 是否变化
# ✅ 事件驱动：on_damage_received / hp_changed 信号

# ❌ 天赋 on_attach 在 TalentPool.init() 之前调用
# on_attach 依赖 Fighter.ad / add_stat_mod 存在
# ✅ on_attach 在 Fighter.setup() 中调用，此时所有基础设施就绪
```

---

## 十一、实施优先级

```
Phase 1 — 基础设施 + 被动属性天赋
  ├─ talent_instance.gd
  ├─ talent_pool.gd
  ├─ talent_manager.gd
  ├─ talent_configs.gd
  ├─ Fighter.ad + talent_manager 字段 + setup() 集成
  └─ 纯属性天赋（生命强化）
  └─ GUT 测试

Phase 2 — 事件驱动天赋
  ├─ talent_event_bus.gd
  ├─ apply_damage 加 damage_source + 事件广播
  └─ 事件响应天赋（荆棘、嗜血）
  └─ GUT 测试（含递归锁验证）

Phase 3 — 主动天赋 + UI
  ├─ talent_slots 按键绑定
  ├─ HUD 天赋按钮绘制
  └─ 主动天赋（烈焰冲刺）
  └─ GUT 测试
```
