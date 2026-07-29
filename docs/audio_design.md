# 音频系统设计方案

## 目标
- 支持 MP3 / OGG 音频
- 淡入淡出效果（支持线性、ease_in、ease_out、ease_in_out 曲线）
- 多个音效重叠播放（可配置最大重叠数）
- 优先级控制与中断替换
- Ducking（高优先级压低低优先级）
- 截断播放（定时自动停止）
- 断点恢复（区分长期音效 / 即时音效）
- 三级音量控制（单音效 → 分组 → 全局 Master）

---

## 1. 架构

```
AudioManager (Autoload)
  ├── _sfx_pool: Array[AudioLayer]      ← SFX 播放器池（重叠播放，默认 8 个）
  ├── _music_layer: AudioLayer           ← 背景音乐专用
  ├── _ui_layer: AudioLayer              ← UI 交互专用
  ├── _sfx_volume / _music_volume        ← 分组音量（0~1）
  └── _configs: Dictionary               ← 所有预注册音效定义

AudioLayer (RefCounted)
  ├── player: AudioStreamPlayer          ← Godot 播放器实例
  ├── config: AudioConfig                ← 当前加载的音效配置
  ├── state: State                       ← IDLE / FADING_IN / PLAYING / FADING_OUT / INTERRUPTED
  ├── tween: Tween                       ← 淡入淡出补间
  ├── _cutoff_timer: Timer               ← 截断定時器
  ├── base_volume: float                 ← config.volume × group_volume（未 ducking 前）
  ├── ducked: bool                       ← 是否被压低
  ├── ducked_by: Array                   ← 压低自己的音效 ID 列表
  ├── _saved_config / _saved_position    ← 中断保存（断点重连用）
  └── _finish_callback: Callable         ← 播放结束回调

AudioConfig (RefCounted)
  ├── id: String                         ← 唯一标识
  ├── path: String                       ← 音频文件路径 (res://...)
  ├── volume: float                      ← 默认音量 (linear 0~1)
  ├── priority: Priority                 ← LOW=0 / NORMAL=1 / HIGH=2 / CRITICAL=3
  ├── category: Category                 ← SFX_COMBAT / SFX_UI / MUSIC / AMBIENT
  ├── interrupt: Interrupt               ← 中断行为（NONE / SELF / LOWER / ALL）
  ├── max_overlap: int                   ← 同音效最大重叠数（0=不限）
  ├── fade_in_ms: int                    ← 淡入时长
  ├── fade_out_ms: int                   ← 淡出时长
  ├── cutoff_ms: int                     ← 截断时长（0=播放完整）
  ├── fade_curve: FadeCurve              ← 渐变曲线（LINEAR / EASE_IN / EASE_OUT / EASE_IN_OUT）
  └── resumable: bool                    ← 被中断后是否断点恢复（即时音效=false，长期音效=true）
```

---

## 2. 三级音量控制

| 层级 | 设置方式 | 作用范围 |
|------|---------|---------|
| 单音效 | `AudioConfig.volume`（注册时配置） | 单个音效 |
| 分组 | `set_sfx_volume()` / `set_music_volume()` | 所有 SFX / 所有音乐 |
| 全局 | `set_master_volume()` | 整个 Master 总线 |

**最终音量** = `config.volume × group_volume × master_volume`

- 分组音量变动时，所有活跃层通过 `update_group_volume()` 实时 fade 到新目标音量
- Ducking 压低在 base_volume 基础上额外降 `-12 dB`

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
- `resumable = true` 的音效（如 BGM）：被中断时调用 `save_state()` 保存播放位置、剩余截断时长、分组音量，状态变为 `INTERRUPTED`
- `resumable = false` 的音效（如打击 SFX）：被中断时直接清除保存的状态
- 中断音效播放结束后，自动寻找有保存状态的 INTERRUPTED 层调用 `resume()` 从断点恢复，带短暂 fade in（0.1s）

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
- Duck/unduck 有独立的 fade 时长（duck: 0.15s linear, unduck: 0.25s ease_out）

---

## 5. AudioLayer 状态机

```
  IDLE ──play()──> FADING_IN ──fade_done──> PLAYING
   ↑                 │                         │
   │                 └── save_state() ──> INTERRUPTED ──resume()──> FADING_IN
   │                                                         
   └── FADING_OUT <── stop() ──────┘
         │
         └── fade_done ──> IDLE
```

- **IDLE**: 空闲，可被分配
- **FADING_IN**: 淡入中（时长 = `fade_in_ms`，曲线 = `fade_curve`）
- **PLAYING**: 正常播放中
- **FADING_OUT**: 淡出中（时长 = `fade_out_ms`）
- **INTERRUPTED**: 被中断（保存状态中），等待恢复或放弃

---

## 6. SFX 池（重叠播放）

- 预创建 8 个 `AudioLayer`（`POOL_SIZE = 8`）
- `play_sfx()` 分配策略（优先级从高到低）：
  1. 如果有可被中断的目标层 → 使用该层
  2. 如果有空闲层（IDLE）→ 使用空闲层
  3. 如果有 INTERRUPTED 层（放弃其恢复）→ 使用该层
  4. 替换最低优先级的活跃层
- 同一个 config_id 可通过 `max_overlap` 限制同时播放数量
- 内联 dict 传入（无注册 id）不受 `max_overlap` 限制

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
| max_overlap | int | 0 | 最大重叠数 (0=不限) |
| fade_in_ms | int | 0 | 淡入时长 (ms) |
| fade_out_ms | int | 0 | 淡出时长 (ms) |
| cutoff_ms | int | 0 | 截断时长 (0=播放完整) |
| fade_curve | int | 0 (LINEAR) | 渐变曲线 |
| resumable | bool | false | 是否断点恢复 |

### 内联 dict 构建
```gdscript
# 长期音效（断点恢复）
AudioManager.play_sfx({
    "path": "res://assets/audio/bgm/ambient.mp3",
    "volume": 0.5,
    "priority": 0,
    "category": 3,              # AMBIENT
    "interrupt": 2,             # LOWER
    "max_overlap": 1,
    "fade_in_ms": 1000,
    "fade_out_ms": 2000,
    "fade_curve": "ease_in_out",
    "resumable": true
})

# 即时音效（被中断不恢复）
AudioManager.play_sfx({
    "path": "res://assets/audio/sfx/explosion.mp3",
    "volume": 1.0,
    "priority": 3,              # CRITICAL
    "interrupt": 2,             # LOWER
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
AudioManager.play_music("bgm_battle")                  # 播放 BGM
AudioManager.play_sound("swing")                       # 兼容旧 API（等同 play_sfx）

# ── 停止 ──
AudioManager.stop_music(true)                          # 停止 BGM（淡出）
AudioManager.stop_all_sfx(true)                        # 停止所有 SFX（淡出）

# ── 音量控制 ──
AudioManager.set_master_volume(0.8)                    # 全局 Master 总线音量
AudioManager.set_sfx_volume(0.7)                       # SFX 分组音量
AudioManager.set_music_volume(0.5)                     # 音乐分组音量

# ── 注册 ──
AudioManager.register_config(my_config)                # 动态注册 AudioConfig
AudioManager.get_registered_ids()                      # 获取所有已注册 ID
```

---

## 9. 预注册音效

| ID | 优先级 | 分类 | 中断 | 重叠 | 淡入 | 淡出 | 截断 | 可恢复 |
|----|--------|------|------|------|------|------|------|--------|
| swing | NORMAL | COMBAT | NONE | 0 | 0 | 50 | - | false |
| wave | NORMAL | COMBAT | NONE | 2 | 0 | 80 | - | false |
| parry | HIGH | COMBAT | NONE | 0 | 0 | 50 | - | false |
| ult | CRITICAL | COMBAT | LOWER | 1 | 50 | 200 | - | false |
| hit_player | HIGH | COMBAT | NONE | 0 | 0 | 50 | - | false |
| hit_enemy | HIGH | COMBAT | NONE | 0 | 0 | 50 | - | false |
| pickup | NORMAL | UI | NONE | 0 | 0 | 30 | - | false |
| arrow | NORMAL | COMBAT | NONE | 0 | 0 | 50 | - | false |
| bgm_battle | LOW | MUSIC | NONE | 1 | 1000 | 2000 | - | **true** |

---

## 10. 已有调用迁移

| 旧调用 | 新调用 |
|--------|--------|
| `play_sound("swing")` | `play_sfx("swing")` |
| `play_sound("parry")` | `play_sfx("parry")` |
| `play_sound("ult")` | `play_sfx("ult")` |
| `play_sound("hit_player")` | `play_sfx("hit_player")` |
| `play_sound("hit_enemy")` | `play_sfx("hit_enemy")` |
| `play_sound("pickup")` | `play_sfx("pickup")` |
| `play_sound("arrow")` | `play_sfx("arrow")` |

`play_sound()` 保留为兼容包装，内部直接调用 `play_sfx()`。

---

## 11. 文件结构

```
scripts/audio/
  ├── audio_config.gd          AudioConfig 类（音频配置元数据）
  ├── audio_layer.gd           AudioLayer 类（单层播放器）
  └── (audio_manager.gd)       AudioManager（Autoload，位于 scripts/ 根目录）
```
