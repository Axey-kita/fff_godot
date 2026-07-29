# 音频配置 — 定义单个音效的元数据
class_name AudioConfig
extends RefCounted

enum Priority { LOW = 0, NORMAL = 1, HIGH = 2, CRITICAL = 3 }
enum Category { SFX_COMBAT, SFX_UI, MUSIC, AMBIENT }
enum Interrupt { NONE, SELF, LOWER, ALL }
enum FadeCurve { LINEAR, EASE_IN, EASE_OUT, EASE_IN_OUT }

var id: String = ""
var path: String = ""
var volume: float = 0.8
var priority: int = Priority.NORMAL
var category: int = Category.SFX_COMBAT
var interrupt: int = Interrupt.NONE
var max_overlap: int = 0          # 0=不限
var fade_in_ms: int = 0
var fade_out_ms: int = 0
var cutoff_ms: int = 0            # 截断时长（0=播放完整）
var fade_curve: int = FadeCurve.LINEAR
var resumable: bool = false       # 被中断后是否断点恢复

func _init(p_id: String = "", p_path: String = "", p_volume: float = 0.8,
		p_priority: int = Priority.NORMAL, p_category: int = Category.SFX_COMBAT,
		p_interrupt: int = Interrupt.NONE, p_max_overlap: int = 0,
		p_fade_in: int = 0, p_fade_out: int = 0,
		p_cutoff: int = 0, p_curve: int = FadeCurve.LINEAR,
		p_resumable: bool = false):
	id = p_id; path = p_path; volume = p_volume; priority = p_priority
	category = p_category; interrupt = p_interrupt; max_overlap = p_max_overlap
	fade_in_ms = p_fade_in; fade_out_ms = p_fade_out
	cutoff_ms = p_cutoff; fade_curve = p_curve; resumable = p_resumable

## 从 Dictionary 构建（调用层直接传入结构体）
static func from_dict(d: Dictionary, p_id: String = "") -> AudioConfig:
	return AudioConfig.new(
		p_id,
		d.get("path", ""),
		d.get("volume", 0.8),
		d.get("priority", Priority.NORMAL),
		d.get("category", Category.SFX_COMBAT),
		d.get("interrupt", Interrupt.NONE),
		d.get("max_overlap", 0),
		d.get("fade_in_ms", 0),
		d.get("fade_out_ms", 0),
		d.get("cutoff_ms", 0),
		_parse_curve(d.get("fade_curve", "linear")),
		d.get("resumable", false),
	)

static func _parse_curve(s: String) -> int:
	match s.to_lower():
		"linear":     return FadeCurve.LINEAR
		"ease_in":    return FadeCurve.EASE_IN
		"ease_out":   return FadeCurve.EASE_OUT
		"ease_in_out": return FadeCurve.EASE_IN_OUT
		_:            return FadeCurve.LINEAR
