## 撤销/重做栈
## 一次"按下 -> 松开"算一个 step，其中包含若干格子状态变化。
## 调用约定：begin_step() -> 多次 record_change() -> end_step() / cancel_step()
class_name UndoStack
extends RefCounted

# 一个 step = Array[Dictionary]
#   {
#     "coord": Vector2i,
#     "before": { "source": int, "atlas": Vector2i },  # 操作前该格子内容；source == -1 表示空
#     "after":  { "source": int, "atlas": Vector2i },  # 操作后该格子内容
#   }
var _undo_stack: Array = []
var _redo_stack: Array = []

var _step_active: bool = false
var _current: Array = []
var _current_coords: Dictionary = {}  # coord -> index in _current


func begin_step() -> void:
	_step_active = true
	_current = []
	_current_coords = {}


## 记录一次格子状态变化。同一 step 内同一 coord 只记录第一次的 before，after 会被覆盖更新
func record_change(coord: Vector2i, before_source: int, before_atlas: Vector2i, after_source: int, after_atlas: Vector2i) -> void:
	if not _step_active:
		return
	if _current_coords.has(coord):
		var idx: int = _current_coords[coord]
		_current[idx]["after"] = { "source": after_source, "atlas": after_atlas }
	else:
		var idx: int = _current.size()
		_current_coords[coord] = idx
		_current.append({
			"coord": coord,
			"before": { "source": before_source, "atlas": before_atlas },
			"after": { "source": after_source, "atlas": after_atlas },
		})


func end_step() -> void:
	if _step_active and not _current.is_empty():
		_undo_stack.append(_current)
		_redo_stack.clear()
	_step_active = false
	_current = []
	_current_coords = {}


func cancel_step() -> void:
	_step_active = false
	_current = []
	_current_coords = {}


## 执行撤销：返回该 step 让调用方应用反向变化（after -> before）；同时加入 redo 栈
func undo() -> Array:
	if _undo_stack.is_empty():
		return []
	var step: Array = _undo_stack.pop_back()
	_redo_stack.append(step)
	return step


## 执行重做：返回该 step 让调用方应用正向变化（before -> after）；同时加入 undo 栈
func redo() -> Array:
	if _redo_stack.is_empty():
		return []
	var step: Array = _redo_stack.pop_back()
	_undo_stack.append(step)
	return step


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()
