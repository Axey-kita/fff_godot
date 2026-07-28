class_name FrameInterrupter

# ── 帧中断器（角色注册计时项，on_break 接管帧执行权）──
# 每项: {tag: String, remaining: int, on_break: Callable}
#   on_break 签名: func(remaining: int) → void
#   不传 on_break = 纯冻结（这帧什么都不跑，只递减计时器 + frame++）
#   传了 on_break = 回调接管帧执行权，可选择性调用任意子系统
static var _interrupts: Array = []

## 角色调用以注册一个带时长的中断
## on_break 可选，每中断帧调用，不传则纯冻结
static func add(tag: String, ticks: int, on_break: Callable = Callable()):
	_interrupts.append({"tag": tag, "remaining": ticks, "on_break": on_break})

## 每中断帧：递减所有计时器，调用 on_break 接管执行权，到期自动移除
static func run_breaks():
	for i in range(_interrupts.size() - 1, -1, -1):
		var entry = _interrupts[i]
		entry["remaining"] -= 1
		var cb: Callable = entry.get("on_break", Callable())
		if cb.is_valid():
			cb.call(entry["remaining"])
		if entry["remaining"] <= 0:
			_interrupts.remove_at(i)

## 列表非空即有活跃中断
static func has_active() -> bool:
	return not _interrupts.is_empty()

## 每帧开始时清空（角色重新注册）
static func reset():
	_interrupts.clear()
