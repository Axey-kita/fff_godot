 ## 一、Modifier 系统（属性修饰器系统）

### 1.1 核心思想：从「直接改值」到「声明式影响」

原文档中天赋直接执行 `f.max_hp *= 1.2`，这是一种**破坏性写入**——原始值永久丢失，且多个天赋的叠加顺序不可控。Modifier 系统的核心规则是：

> **天赋不碰 Fighter 的字段，只向属性容器「注册影响」；最终值由容器按需计算。**

```
传统方式：        Modifier 方式：
max_hp = 100      base_max_hp = 100
↓ 天赋A ×1.2      ↓ 注册 modA (MUL, 1.2, "talent.vitality")
max_hp = 120      ↓ 注册 modB (ADD, 50, "talent.berserk")  
↓ 天赋B +50       final_max_hp = (100 + 50) × 1.2 = 180
max_hp = 170  ←   卸载 modA 后自动回退到 150
```

### 1.2 架构设计

#### 1.2.1 修饰器定义

```gdscript
# scripts/attributes/attribute_modifier.gd
class_name AttributeModifier
extends RefCounted

enum Type { ADD, MUL_BASE, MUL_TOTAL, OVERRIDE }

var source: StringName      # 来源标识，如 &"talent.vitality"
var attr: StringName        # 目标属性，如 &"max_hp"
var type: Type
var value: float
var priority: int = 0       # 同类型内的计算顺序
var condition: Callable = func() -> bool: return true  # 动态条件
```

#### 1.2.2 属性容器（替代 Fighter.ad）

```gdscript
# scripts/attributes/attribute_container.gd
class_name AttributeContainer
extends RefCounted

# 基础值：角色裸装时的原始属性
var _base: Dictionary[StringName, float] = {}

# 修饰器列表：按属性分组
var _mods: Dictionary[StringName, Array[AttributeModifier]] = {}

# 缓存与脏标记（性能关键）
var _cache: Dictionary[StringName, float] = {}
var _dirty: Dictionary[StringName, bool] = {}

# 属性变更信号（供UI、血条、天赋联动）
signal attr_changed(attr: StringName, old_val: float, new_val: float)

func set_base(attr: StringName, value: float):
    var old = get_final(attr)
    _base[attr] = value
    _invalidate(attr)
    var new = get_final(attr)
    if not is_equal_approx(old, new):
        attr_changed.emit(attr, old, new)

func get_base(attr: StringName) -> float:
    return _base.get(attr, 0.0)

func get_final(attr: StringName) -> float:
    # 缓存命中直接返回
    if not _dirty.get(attr, true) and _cache.has(attr):
        return _cache[attr]
    
    var base = _base.get(attr, 0.0)
    var list: Array[AttributeModifier] = _mods.get(attr, [])
    
    # 筛选生效的修饰器并按优先级排序
    var active: Array[AttributeModifier] = []
    for m in list:
        if m.condition.call():
            active.append(m)
    active.sort_custom(func(a, b): return a.priority < b.priority)
    
    # 计算顺序：Base → Additive → Multiplicative_Base → Multiplicative_Total → Override
    var adds = 0.0
    var mul_base = 1.0
    var mul_total = 1.0
    var override_val = null
    
    for m in active:
        match m.type:
            AttributeModifier.Type.ADD:
                adds += m.value
            AttributeModifier.Type.MUL_BASE:
                mul_base += m.value - 1.0  # 1.2 表示 +20%
            AttributeModifier.Type.MUL_TOTAL:
                mul_total += m.value - 1.0
            AttributeModifier.Type.OVERRIDE:
                override_val = m.value
    
    var result = (base + adds) * mul_base * mul_total
    if override_val != null:
        result = override_val
    
    _cache[attr] = result
    _dirty[attr] = false
    return result

func add_modifier(mod: AttributeModifier):
    if not _mods.has(mod.attr):
        _mods[mod.attr] = []
    _mods[mod.attr].append(mod)
    _invalidate(mod.attr)

func remove_by_source(source: StringName):
    # 卸载天赋时精确清理，不污染其他系统
    for attr in _mods.keys():
        var list: Array[AttributeModifier] = _mods[attr]
        var before = list.size()
        list = list.filter(func(m): return m.source != source)
        if list.size() != before:
            _mods[attr] = list
            _invalidate(attr)

func _invalidate(attr: StringName):
    _dirty[attr] = true
    # 级联失效：例如 max_hp 变了，hp_percent 等派生属性也要重算
    # 可通过注册依赖图实现，此处简化
```

#### 1.2.3 Fighter 集成

```gdscript
# fighter.gd
var attrs: AttributeContainer = AttributeContainer.new()

func setup(config: Dictionary):
    # 基础属性初始化
    attrs.set_base(&"max_hp", config.max_hp)
    attrs.set_base(&"atk", config.atk)
    attrs.set_base(&"def", config.def)
    # ... 其他基础属性
    
    # 天赋装配（此时 attrs 已就绪）
    talent_manager.init(self, config.talent_ids)
    
    # 初始 HP 设为满值（基于计算后的 max_hp）
    hp = attrs.get_final(&"max_hp")
```

### 1.3 天赋使用方式对比

**原文档（破坏性）：**
```gdscript
# ❌ 直接改值，卸载后无法恢复
inst.on_attach = func():
    f.ad["vitality"] = {"base_hp": f.max_hp}  # 手动备份
    f.max_hp *= 1.2
    f.hp = f.max_hp  # 满血重置，逻辑粗暴
```

**Modifier 系统（声明式）：**
```gdscript
# ✅ 注册影响，卸载自动回退
static func _make_vitality(f: Fighter) -> TalentInstance:
    var cfg = TalentConfigs.get("vitality")
    var inst = TalentInstance.new()
    inst.talent_name = "生命强化"
    
    inst.on_attach = func():
        var mod = AttributeModifier.new()
        mod.source = &"talent.vitality"
        mod.attr = &"max_hp"
        mod.type = AttributeModifier.Type.MUL_BASE
        mod.value = cfg.hp_mult
        f.attrs.add_modifier(mod)
        
        # HP 同步：保持当前血量百分比不变，而非强制满血
        var old_max = f.attrs.get_base(&"max_hp")  # 这里需要小心，get_base 是原始值
        # 实际应记录比例：f.hp = f.hp * (new_max / old_max)
    
    inst.on_detach = func():
        f.attrs.remove_by_source(&"talent.vitality")
    
    return inst
```

### 1.4 解决的核心问题

| 原文档问题 | Modifier 方案 |
|-----------|--------------|
| 叠加顺序不可控 | 显式 `priority` + 分阶段计算（ADD→MUL→OVERRIDE） |
| 卸载后属性残留 | `remove_by_source` 精确清理，缓存自动失效 |
| 对象池复用污染 | 战斗结束调用 `talent_manager.detach_all()` → 所有 modifier 清除 |
| 无法做条件属性 | `condition` Callable 支持动态开关（如"低血量时防御翻倍"） |
| HP 与 max_hp 联动断裂 | `attr_changed` 信号驱动 HP 等比例缩放 |

### 1.5 性能考量

- **脏标记缓存**：`get_final()` 只在 modifier 变更时重算，平时 O(1) 读取
- **分帧分摊**：如果一次战斗同时加载 10 个天赋，可在 `TalentManager.init()` 中批量标记脏标记，直到首次 `get_final` 才实际计算（惰性求值）
- **避免每帧调用**：不要在 `_process` 中每帧 `get_final(&"atk")`，而是在属性变化时缓存到局部变量

---

## 二、类型化事件总线（Typed Event Bus）

### 2.1 核心思想：从「字符串+变长参数」到「强类型事件对象」

原文档的事件系统：
```gdscript
# ❌ 运行时才能发现参数不匹配
inst.on_damage_received = func(attacker, dmg): pass
TalentManager.dispatch("on_damage_received", [attacker, dmg])
# 如果某个天赋写成 func(attacker): pass，调用时崩溃
```

类型化事件总线：
```gdscript
# ✅ 编译期检查（GDScript 中至少能检查属性访问）
func handle_event(event: DamageReceivedEvent):
    var attacker = event.attacker
    var dmg = event.final_damage
```

### 2.2 架构设计

#### 2.2.1 事件基类与具体事件

```gdscript
# scripts/events/talent_event.gd
class_name TalentEvent
extends RefCounted

var source_fighter: Fighter        # 事件发起者
var timestamp: int = Time.get_ticks_msec()

# 事件可被取消（如护盾天赋拦截伤害）
var is_cancelled: bool = false
var is_consumed: bool = false      # 标记已处理，阻止后续传播

func get_event_type() -> StringName:
    return &"generic"
```

```gdscript
# scripts/events/damage_event.gd
class_name DamageEvent
extends TalentEvent

enum Phase { BEFORE_CALC, AFTER_CALC, AFTER_APPLY }

var target: Fighter
var raw_damage: float           # 原始伤害值
var final_damage: float         # 计算后实际值（可被天赋修改）
var damage_source: StringName   # &"skill.assassin_q" | &"talent.thorns" | &"env.poison"
var recursion_depth: int = 0
var phase: Phase = Phase.AFTER_CALC
var knockback: bool = true
var hit_color: Color = Color(1.0, 0.53, 0.27)

func get_event_type() -> StringName:
    return &"damage_dealt"

func is_from_talent() -> bool:
    return damage_source.begins_with(&"talent.")
```

```gdscript
# scripts/events/damage_received_event.gd
class_name DamageReceivedEvent
extends TalentEvent

var attacker: Fighter
var damage: float
var damage_source: StringName
var recursion_depth: int = 0
var is_reflected: bool = false   # 标记是否为反弹伤害

func get_event_type() -> StringName:
    return &"damage_received"
```

```gdscript
# 其他事件
class_name KillEvent extends TalentEvent
class_name DodgeEvent extends TalentEvent
class_name SkillUsedEvent extends TalentEvent
# ...
```

#### 2.2.2 类型化事件总线

```gdscript
# scripts/events/typed_event_bus.gd
class_name TypedEventBus

const MAX_RECURSION_DEPTH = 3

static func emit(event: TalentEvent):
    if event.source_fighter and event.source_fighter.talent_manager:
        _dispatch_to(event, event.source_fighter.talent_manager)
    
    # 双向事件：伤害事件同时发给攻击者和受击者
    if event is DamageEvent and event.target and event.target != event.source_fighter:
        if event.target.talent_manager:
            _dispatch_to(event, event.target.talent_manager)

static func _dispatch_to(event: TalentEvent, manager: TalentManager):
    # 递归深度保护（框架级，不依赖字符串约定）
    if event is DamageEvent and event.recursion_depth >= MAX_RECURSION_DEPTH:
        push_warning("Event recursion limit reached: source=%s" % event.damage_source)
        return
    
    manager.handle_event(event)
```

#### 2.2.3 TalentInstance 的新接口

```gdscript
# scripts/talents/talent_instance.gd
class_name TalentInstance
extends RefCounted

# 天赋声明自己关心的事件类型（用于优化分发）
var subscribed_events: Array[StringName] = []

# 统一的事件处理入口，替代零散的 Callable 字段
func handle_event(event: TalentEvent) -> void:
    pass

# 可选：声明式订阅，子类可覆盖
func get_subscribed_events() -> Array[StringName]:
    return subscribed_events
```

#### 2.2.4 TalentManager 的事件分发

```gdscript
# scripts/talents/talent_manager.gd
class_name TalentManager
extends RefCounted

var talents: Array[TalentInstance] = []
var owner: Fighter = null

# 按事件类型索引天赋（O(1) 路由，避免全量遍历）
var _event_index: Dictionary[StringName, Array[TalentInstance]] = {}

func init(fighter: Fighter, talent_ids: Array):
    owner = fighter
    for tid in talent_ids:
        var t = TalentPool.create(tid, fighter)
        if t:
            t.on_attach.call()
            talents.append(t)
            # 建立事件索引
            for ev_type in t.get_subscribed_events():
                if not _event_index.has(ev_type):
                    _event_index[ev_type] = []
                _event_index[ev_type].append(t)

func handle_event(event: TalentEvent):
    var ev_type = event.get_event_type()
    var targets: Array[TalentInstance] = _event_index.get(ev_type, [])
    
    for t in targets:
        if event.is_consumed:
            break
        t.handle_event(event)

# 主动天赋接口保持不变，但建议也走事件化
func activate_slot(index: int) -> Dictionary:
    # ...
```

### 2.3 天赋重写示例

#### 荆棘（Thorns）—— 展示递归防护

```gdscript
static func _make_thorns(f: Fighter) -> TalentInstance:
    var cfg = TalentConfigs.get("thorns")
    var inst = TalentInstance.new()
    inst.talent_name = "荆棘"
    inst.subscribed_events = [&"damage_received"]
    
    inst.handle_event = func(event: TalentEvent):
        if not (event is DamageReceivedEvent):
            return
        var ev = event as DamageReceivedEvent
        
        # 框架已保证 recursion_depth <= MAX，无需手动锁
        if ev.attacker and ev.attacker.hp > 0 and not ev.is_reflected:
            var reflect = DamageEvent.new()
            reflect.source_fighter = f
            reflect.target = ev.attacker
            reflect.raw_damage = cfg.reflect_dmg
            reflect.final_damage = cfg.reflect_dmg
            reflect.damage_source = &"talent.thorns"
            reflect.recursion_depth = ev.recursion_depth + 1
            reflect.hit_color = Color.GREEN
            reflect.knockback = false
            # 标记这是反射伤害，供其他系统识别
            reflect.set_meta(&"is_reflection", true)
            
            # 直接调用 apply_damage 的底层，或继续走事件
            Fighter.apply_damage_event(reflect)
    
    return inst
```

#### 嗜血（Vampiric）—— 展示事件修改

```gdscript
static func _make_vampiric(f: Fighter) -> TalentInstance:
    var cfg = TalentConfigs.get("vampiric")
    var inst = TalentInstance.new()
    inst.talent_name = "嗜血"
    inst.subscribed_events = [&"damage_dealt"]
    
    inst.handle_event = func(event: TalentEvent):
        if not (event is DamageEvent):
            return
        var ev = event as DamageEvent
        
        # 只在伤害实际生效后触发（AFTER_APPLY 阶段）
        if ev.phase != DamageEvent.Phase.AFTER_APPLY:
            return
        if ev.final_damage <= 0:
            return
        
        var heal = ev.final_damage * cfg.heal_pct
        # 通过事件请求治疗，而非直接改 hp
        var heal_event = HealEvent.new()
        heal_event.source_fighter = f
        heal_event.target = f
        heal_event.amount = heal
        heal_event.heal_source = &"talent.vampiric"
        TypedEventBus.emit(heal_event)
    
    return inst
```

### 2.4 apply_damage 的重构

```gdscript
# fighter.gd
static func apply_damage(target: Fighter, dmg: float, attacker: Fighter, 
    knockback: bool = true, hit_color = Color(1.0, 0.53, 0.27), 
    sound_name: String = "hit_enemy", damage_source: StringName = &""):
    
    # 1. 构建 BEFORE_CALC 事件（天赋可修改 raw_damage）
    var before_ev = DamageEvent.new()
    before_ev.phase = DamageEvent.Phase.BEFORE_CALC
    before_ev.target = target
    before_ev.raw_damage = dmg
    before_ev.source_fighter = attacker
    before_ev.damage_source = damage_source
    TypedEventBus.emit(before_ev)
    
    if before_ev.is_cancelled:
        return {"success": false, "cancelled": true}
    
    # 2. 计算最终伤害（考虑防御、暴击等）
    var final_dmg = _calculate_damage(before_ev.raw_damage, attacker, target)
    
    # 3. 构建 AFTER_CALC 事件（天赋可修改 final_damage）
    var calc_ev = DamageEvent.new()
    calc_ev.phase = DamageEvent.Phase.AFTER_CALC
    calc_ev.target = target
    calc_ev.raw_damage = before_ev.raw_damage
    calc_ev.final_damage = final_dmg
    calc_ev.source_fighter = attacker
    calc_ev.damage_source = damage_source
    TypedEventBus.emit(calc_ev)
    
    final_dmg = calc_ev.final_damage
    
    # 4. 应用伤害
    target.hp -= final_dmg
    target.hp = maxf(0.0, target.hp)
    
    # 5. 构建 AFTER_APPLY 事件（用于吸血、击杀判定等）
    var apply_ev = DamageEvent.new()
    apply_ev.phase = DamageEvent.Phase.AFTER_APPLY
    apply_ev.target = target
    apply_ev.raw_damage = before_ev.raw_damage
    apply_ev.final_damage = final_dmg
    apply_ev.source_fighter = attacker
    apply_ev.damage_source = damage_source
    TypedEventBus.emit(apply_ev)
    
    # 6. 击杀判定
    if target.hp <= 0:
        var kill_ev = KillEvent.new()
        kill_ev.source_fighter = attacker
        kill_ev.target = target
        TypedEventBus.emit(kill_ev)
    
    return {"success": true, "damage": final_dmg}
```

### 2.5 解决的核心问题

| 原文档问题 | 类型化事件方案 |
|-----------|---------------|
| Callable 参数不匹配导致运行时崩溃 | `handle_event(event: TypedEvent)` 单一入口，类型安全 |
| `dispatch("on_damage_dealt", [a, b])` 字符串反射 | `event.get_event_type()` 返回 `StringName`，配合索引表 O(1) 路由 |
| `damage_source` 魔法字符串易拼错 | `StringName` 类型 + 常量定义（`&"talent.thorns"`） |
| 全量遍历所有天赋分发事件 | `_event_index` 预构建，只遍历关心该事件的天赋 |
| 手动递归锁（`reflecting = true/false`）不可靠 | 框架级 `recursion_depth` 计数，超限自动阻断 |
| 天赋直接改 `f.hp` 导致逻辑分散 | 统一走 `HealEvent` / `DamageEvent`，便于统计和拦截 |

---

## 三、两个系统的协同工作流

```
战斗开始
  ├─ Fighter.setup()
  │    ├─ attrs.set_base("max_hp", 100)      ← 基础属性
  │    └─ talent_manager.init(["vitality", "thorns"])
  │         ├─ vitality.on_attach()
  │         │    └─ attrs.add_modifier(MUL, "max_hp", 1.2)  ← Modifier
  │         └─ thorns 注册订阅 [&"damage_received"]          ← 事件索引
  │
  └─ 首次 get_final("max_hp") → 180（自动计算）

战斗中
  ├─ 玩家攻击敌人
  │    └─ Fighter.apply_damage(enemy, 50, player)
  │         ├─ 发 DamageEvent(BEFORE_CALC)  → 无天赋订阅
  │         ├─ 计算 final_dmg = 45
  │         ├─ 发 DamageEvent(AFTER_CALC)   → 无天赋订阅
  │         ├─ enemy.hp -= 45
  │         ├─ 发 DamageEvent(AFTER_APPLY)  
  │         │    ├─ vampiric 收到 → 发 HealEvent(4.5)
  │         │    └─ 其他伤害后天赋...
  │         └─ 发 DamageReceivedEvent 到 enemy
  │              └─ thorns 收到 → 发 DamageEvent(recursion=1)
  │                   └─ player 收到 DamageReceivedEvent
  │                        └─ thorns 再次触发？→ recursion=2，继续
  │                        └─ 如果还有荆棘 → recursion=3，继续
  │                        └─ 再触发 → recursion=4 ≥ MAX，阻断！
  │
  └─ 敌人死亡
       └─ 发 KillEvent → 相关天赋处理

战斗结束 / 卸下天赋
  └─ talent_manager.detach_all()
       ├─ vitality.on_detach()
       │    └─ attrs.remove_by_source("talent.vitality")  ← max_hp 回退
       └─ thorns 从 _event_index 移除
```

---

## 四、迁移路径建议

如果项目已按原文档实现了 Phase 1，不建议推倒重来，可按以下顺序渐进改造：

**Step 1（低风险，高回报）：** 引入 `AttributeContainer`，但保留 `Fighter.ad` 作为过渡期兼容层。把"生命强化"等纯属性天赋改为 Modifier 实现。

**Step 2（中等风险）：** 在 `apply_damage` 中新增 `damage_source: StringName` 参数，同时保留旧的空字符串默认值。逐步把天赋中的字符串改为 `&"talent.xxx"`。

**Step 3（需要测试）：** 实现 `TypedEventBus` 作为并行系统。让 `TalentInstance` 同时支持旧的 Callable 字段和新的 `handle_event`。`TalentManager.dispatch()` 先检查新接口，回退到旧接口。

**Step 4（最终态）：** 所有天赋迁移完成后，删除旧的事件字符串分发和 `ad` 字典，完全切换到新架构。

---

## 五、一句话总结

- **Modifier 系统**解决的是**「状态怎么安全地变」**的问题——通过声明式影响代替破坏性写入，让叠加、卸载、条件化变得可预测。
- **类型化事件总线**解决的是**「天赋怎么响应世界」**的问题——通过强类型事件对象和框架级分发，消灭运行时类型错误和递归灾难，同时把遍历开销从 O(n) 降到 O(1)。