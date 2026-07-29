# 音频系统设计方案

## 目标
- 支持 MP3 / OGG 音频
- 淡入淡出效果（支持线性、ease_in、ease_out、ease_in_out 曲线）
- 多个音效重叠播放（可配置最大重叠数，-1=不限）
- 优先级控制与中断替换
- Ducking（高优先级压低低优先级）
- 截断播放（定时自动停止，到期时检查音效是否已自然结束）
- 断点恢复（区分长期音效 / 即时音效）
- Pitch 随机化（同一音效连续播放时轻微变化，提升质感）
- Loop 循环控制
- 三级音量控制（单音效 → Bus 分组 → Master 全局）

---

## 1. 架构

```
AudioManager (Autoload)
  ├── _sfx_pool: Array[AudioLayer]      ← SFX 池（可配置大小，默认 8）
  ├── _ui_pool: Array[AudioLayer]       ← UI 音效池（3 层）
  ├── _music_layers: Array[AudioLayer]  ← 双缓冲 BGM 层（支持交叉淡入淡出）
  ├── _pending_resumes: Array           ← 被中断的 resumable 音效（等待恢复）
  └── _configs: Dictionary              ← 预注册音效定义

Audio Buses (Godot AudioServer)
  Master
    ├── SFX    （战斗/环境音效）
    ├── Music  （背景音乐）
    └── UI     （UI 交互音效）

AudioLayer (RefCounted)
  ├── player: AudioStreamPlayer          ← Godot 播放器实例
  ├── config: AudioConfig                ← 当前加载的音效配置
  ├── state: State                       ← IDLE / FADING_IN / PLAYING / FADING_OUT
  ├── tween: Tween                       ← 淡入淡出补间（始终只有一个）
  ├── _cutoff_timer: Timer               ← 截断定時器
  ├── base_volume: float                 ← config.volume
  ├── ducked: bool / ducked_by: Array    ← Ducking 状态
  └── _finish_callback / _fail_callback  ← 播放结束/失败回调

AudioConfig (RefCounted)
  ├── id, path, volume, priority, category, interrupt
  ├── max_overlap: int                   ← 最大重叠数（-1=不限）
  ├── fade_in_ms, fade_out_ms, cutoff_ms
  ├── fade_curve: FadeCurve              ← 渐变曲线
  ├── resumable: bool                    ← 是否断点恢复
  ├── pitch_variation: float             ← pitch 随机化范围
  └── loop: bool                         ← 循环播放
```

---

## 2. 三级音量控制（Godot Bus）

| 层级 | 设置方式 | 实现 |
|------|---------|------|
| 单音效 | `AudioConfig.volume` | `AudioStreamPlayer.volume_db` |
| 分组 | `set_sfx_volume()` / `set_music_volume()` / `set_ui_volume()` | `AudioServer.set_bus_volume_db(SFX/Music/UI Bus)` |
| 全局 | `set_master_volume()` | `AudioServer.set_bus_volume_db(Master Bus)` |

**最终音量** = `player.volume_db + Bus.volume_db + Master.volume_db`

- 分组音量直接操作 Godot Audio Bus，不需要逐层遍历更新
- Ducking 在 `player.volume_db` 层面降低 `-12 dB`，不影响 Bus 音量

---

## 3. 优先级与中断规则

### 优先级
| 级别 | 值 | 典型用途 |
|------|----|---------|
| LOW | 0 | 背景音乐 |
| NORMAL | 1 | 普通攻击、拾取、箭矢 |
| HIGH | 2 | 技能命中、受击 |
| CRITICAL | 3 | 大招 |

### 中断行为
| 模式 | 效果 |
|------|------|
| `NONE` | 不可被中断 |
| `SELF` | 仅可被同 ID 音效中断 |
| `LOWER` | 可中断 ≤ 自身优先级的音效 |
| `ALL` | 可中断任何音效 |

### 中断恢复（断点重连）
- `resumable = true` 的音效被中断时：保存播放位置和剩余截断时长到 `_pending_resumes`
- `resumable = false` 的音效被中断时：直接丢弃
- 中断音效播放结束后，按优先级降序恢复 `_pending_resumes` 中的音效（`play_from_position()`）
- Pending resume 被回收的条件：新音效优先级 **严格高于** 被中断音效的优先级

---

## 4. Ducking（音量压低）

高优先级音效播放时，所有低优先级活跃层音量降低 `-12 dB`。

```
ult (CRITICAL) 播放
  → swing (NORMAL) duck → -12 dB
  → hit_enemy (HIGH) 不 duck（同/高优先级不压低）
  → bgm_battle (LOW) duck → -12 dB

ult 结束
  → swing unduck → 恢复 base_volume
  → bgm_battle unduck → 恢复 base_volume
```

- Ducking 级联：每个层维护 `ducked_by[]` 列表，只有当所有压迫者都结束后才 unduck
- Duck: 0.15s linear fade；Unduck: 0.25s ease_out fade
- 同一时刻仅有一个 Tween 操作 `player.volume_db`（`_fade_to()` 内部先 `_stop_tween()`）

---

## 5. AudioLayer 状态机

```
  IDLE ──play()──> FADING_IN ──fade_done──> PLAYING
   ↑                                            │
   │                                   stop() / finished / cutoff
   │                                            ↓
   └── FADING_OUT <──────── stop(fade=true) ────┘
         │
         └── fade_done ──> IDLE（触发 _finish_callback）
```

- **IDLE**: 空闲，可被分配
- **FADING_IN**: 淡入中（时长 = `fade_in_ms`，曲线 = `fade_curve`）
- **PLAYING**: 正常播放中
- **FADING_OUT**: 淡出中（时长 = `fade_out_ms`）

---

## 6. 池分配策略

### SFX / UI 池
`play_sfx()` 自动按 `AudioConfig.category` 路由：
- `SFX_COMBAT`, `AMBIENT` → SFX 池
- `SFX_UI` → UI 池（3 层）
- `MUSIC` → 音乐层（双缓冲）

层分配优先级：
1. 如果有可被中断的层 → 使用该层
2. 如果有空闲层（IDLE）→ 使用空闲层
3. 回收 `_pending_resumes` 中优先级最低的（仅新音效优先级更高）→ 使用空出的层
4. 替换池中最低优先级的活跃层

### 音乐层（双缓冲）
- 2 层轮转：播放新 BGM 时停止当前层，轮转到另一层播放
- 支持交叉淡入淡出：上一层 fade out，新层 fade in 可重叠
- 同 ID BGM 已在播放时跳过

---

## 7. AudioConfig

### 属性一览
| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| id | String | "" | 唯一标识 |
| path | String | "" | 音频文件路径 |
| volume | float | 0.8 | 单音效音量 (0~1) |
| priority | int | 1 (NORMAL) | 优先级 |
| category | int | 0 (SFX_COMBAT) | 分类 |
| interrupt | int | 0 (NONE) | 中断模式 |
| max_overlap | int | -1 | 最大重叠数 (-1=不限) |
| fade_in_ms | int | 0 | 淡入时长 (ms) |
| fade_out_ms | int | 0 | 淡出时长 (ms) |
| cutoff_ms | int | 0 | 截断时长 (0=播放完整) |
| fade_curve | int | 0 (LINEAR) | 渐变曲线 |
| resumable | bool | false | 是否断点恢复 |
| pitch_variation | float | 0.0 | pitch 随机化范围 |
| loop | bool | false | 循环播放 |

### 内联 dict（支持字符串/数字混合）
```gdscript
# 长期音效（断点恢复）
AudioManager.play_sfx({
    "path": "res://assets/audio/bgm/ambient.mp3",
    "volume": 0.5,
    "priority": "low",          # 字符串自动转换
    "category": "ambient",
    "interrupt": "lower",
    "max_overlap": 1,
    "fade_in_ms": 1000,
    "fade_out_ms": 2000,
    "fade_curve": "ease_in_out",
    "resumable": true,
    "loop": true,
    "pitch_variation": 0.05     # ±5% pitch 随机
})

# 即时音效
AudioManager.play_sfx({
    "path": "res://assets/audio/sfx/explosion.mp3",
    "volume": 1.0,
    "priority": 3,
    "interrupt": "lower",
    "fade_in_ms": 30,
    "fade_out_ms": 100,
    "cutoff_ms": 3000
})
```

---

## 8. API

```gdscript
# ── 播放 ──
AudioManager.play_sfx("swing")                        # 预注册音效
AudioManager.play_sfx({"path": "...", ...})            # 内联 dict
AudioManager.play_music("bgm_battle")                  # 播放 BGM（双缓冲）
AudioManager.play_sound("swing")                       # 兼容旧 API（等同 play_sfx）

# ── 停止 ──
AudioManager.stop_music(true)                          # 停止所有音乐层（淡出）
AudioManager.stop_all_sfx(true)                        # 停止所有 SFX（淡出）

# ── 音量控制 ──
AudioManager.set_master_volume(0.8)                    # Master Bus 音量
AudioManager.set_sfx_volume(0.7)                       # SFX Bus 音量
AudioManager.set_music_volume(0.5)                     # Music Bus 音量
AudioManager.set_ui_volume(0.8)                        # UI Bus 音量

# ── 注册 ──
AudioManager.register_config(my_config)                # 动态注册 AudioConfig
AudioManager.get_registered_ids()                      # 获取所有已注册 ID
```

---

## 9. 预注册音效

| ID | 优先级 | 分类 | 中断 | 重叠 | 淡入 | 淡出 | 可恢复 |
|----|--------|------|------|------|------|------|--------|
| swing | NORMAL | COMBAT | NONE | -1 | 0 | 50 | false |
| wave | NORMAL | COMBAT | NONE | 2 | 0 | 80 | false |
| parry | HIGH | COMBAT | NONE | -1 | 0 | 50 | false |
| ult | CRITICAL | COMBAT | LOWER | 1 | 50 | 200 | false |
| hit_player | HIGH | COMBAT | NONE | -1 | 0 | 50 | false |
| hit_enemy | HIGH | COMBAT | NONE | -1 | 0 | 50 | false |
| pickup | NORMAL | UI | NONE | -1 | 0 | 30 | false |
| arrow | NORMAL | COMBAT | NONE | -1 | 0 | 50 | false |
| bgm_battle | LOW | MUSIC | NONE | -1 | 1000 | 2000 | **true** |

---

## 10. 已有调用迁移

| 旧调用 | 新调用 | 说明 |
|--------|--------|------|
| `play_sound("swing")` | `play_sfx("swing")` | `play_sound()` 作为兼容包装保留 |

---

## 11. 文件结构

```
scripts/audio/
  ├── audio_config.gd          AudioConfig 类（音频配置元数据）
  ├── audio_layer.gd           AudioLayer 类（单层播放器）
  └── (audio_manager.gd)       AudioManager（Autoload，位于 scripts/ 根目录）
```

---

## 12. Godot Audio Bus 结构

```
Master
 ├── SFX     ← _sfx_pool 所有层路由到此
 ├── Music   ← _music_layers 双缓冲路由到此
 └── UI      ← _ui_pool 所有层路由到此
```

- Bus 在 `_ready()` 中自动创建（幂等，已存在则复用）
- 可通过 Godot 编辑器 Audio 面板直接查看和添加效果器
- `ProjectSettings: audio/sfx_pool_size` 控制 SFX 池大小（默认 8）
