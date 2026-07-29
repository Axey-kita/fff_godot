# 音频配置 — 定义单个音效的元数据
class_name AudioConfig
extends RefCounted

enum Priority { LOW = 0, NORMAL = 1, HIGH = 2, CRITICAL = 3 }
enum Category { SFX_COMBAT, SFX_UI, MUSIC, AMBIENT }
enum Interrupt { NONE, SELF, LOWER, ALL }
enum FadeCurve { LINEAR, EASE_IN, EASE_OUT, EASE_IN_OUT }

const PRIORITY_NAMES := {"low": Priority.LOW, "normal": Priority.NORMAL, "high": Priority.HIGH, "critical": Priority.CRITICAL}
const CATEGORY_NAMES := {"sfx_combat": Category.SFX_COMBAT, "sfx_ui": Category.SFX_UI, "music": Category.MUSIC, "ambient": Category.AMBIENT}
const INTERRUPT_NAMES := {"none": Interrupt.NONE, "self": Interrupt.SELF, "lower": Interrupt.LOWER, "all": Interrupt.ALL}

var id: String = ""
var path: String = ""
var volume: float = 0.8
var priority: int = Priority.NORMAL
var category: int = Category.SFX_COMBAT
var interrupt: int = Interrupt.NONE
var max_overlap: int = -1               # -1=不限
var fade_in_ms: int = 0
var fade_out_ms: int = 0
var cutoff_ms: int = 0                  # 截断时长（0=播放完整）
var fade_curve: int = FadeCurve.LINEAR
var resumable: bool = false             # 被中断后是否断点恢复
var pitch_variation: float = 0.0        # pitch 随机化范围（播放时 ±variation）
var loop: bool = false                  # 循环播放

func _init(p_id: String = "", p_path: String = "", p_volume: float = 0.8,
		p_priority: int = Priority.NORMAL, p_category: int = Category.SFX_COMBAT,
		p_interrupt: int = Interrupt.NONE, p_max_overlap: int = -1,
		p_fade_in: int = 0, p_fade_out: int = 0,
		p_cutoff: int = 0, p_curve: int = FadeCurve.LINEAR,
		p_resumable: bool = false, p_pitch_var: float = 0.0,
		p_loop: bool = false):
	id = p_id; path = p_path; volume = p_volume; priority = p_priority
	category = p_category; interrupt = p_interrupt; max_overlap = p_max_overlap
	fade_in_ms = p_fade_in; fade_out_ms = p_fade_out
	cutoff_ms = p_cutoff; fade_curve = p_curve; resumable = p_resumable
	pitch_variation = p_pitch_var; loop = p_loop

## 从 Dictionary 构建（支持字符串/数字混合输入）
static func from_dict(d: Dictionary, p_id: String = "") -> AudioConfig:
	return AudioConfig.new(
		p_id,
		d.get("path", ""),
		d.get("volume", 0.8),
		_parse_priority(d.get("priority", Priority.NORMAL)),
		_parse_category(d.get("category", Category.SFX_COMBAT)),
		_parse_interrupt(d.get("interrupt", Interrupt.NONE)),
		d.get("max_overlap", -1),
		d.get("fade_in_ms", 0),
		d.get("fade_out_ms", 0),
		d.get("cutoff_ms", 0),
		_parse_curve(d.get("fade_curve", "linear")),
		d.get("resumable", false),
		d.get("pitch_variation", 0.0),
		d.get("loop", false),
	)

## 获取该分类对应的 Audio Bus 名称
func get_bus_name() -> String:
	match category:
		Category.MUSIC:   return "Music"
		Category.SFX_UI:  return "UI"
		Category.AMBIENT: return "SFX"
		_:                return "SFX"

# ── 私有解析 ──

static func _parse_priority(v) -> int:
	if v is int: return v
	if v is String: return PRIORITY_NAMES.get(v.to_lower(), Priority.NORMAL)
	return Priority.NORMAL

static func _parse_category(v) -> int:
	if v is int: return v
	if v is String: return CATEGORY_NAMES.get(v.to_lower(), Category.SFX_COMBAT)
	return Category.SFX_COMBAT

static func _parse_interrupt(v) -> int:
	if v is int: return v
	if v is String: return INTERRUPT_NAMES.get(v.to_lower(), Interrupt.NONE)
	return Interrupt.NONE

static func _parse_curve(s: String) -> int:
	match s.to_lower():
		"linear":     return FadeCurve.LINEAR
		"ease_in":    return FadeCurve.EASE_IN
		"ease_out":   return FadeCurve.EASE_OUT
		"ease_in_out": return FadeCurve.EASE_IN_OUT
		_:            return FadeCurve.LINEAR
