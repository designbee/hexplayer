## 主控制器
## 工具切换（画笔/拖动/橡皮擦）、区块选择、输入分发、撤销/重做、鼠标悬停高亮。
class_name MainController
extends Node2D

enum ToolMode { BRUSH, PAN, ERASER }

# 节点引用
@onready var hex_map: HexMap = $HexMap
@onready var camera: Camera2D = $MainCamera
@onready var brush_button: Button = $UI/TopMenuMargin/TopMenu/BrushButton
@onready var pan_button: Button = $UI/TopMenuMargin/TopMenu/PanButton
@onready var eraser_button: Button = $UI/TopMenuMargin/TopMenu/EraserButton
@onready var block_grass: Button = $UI/BlockForm/Panel/Margin/Blocks/BlockGrass
@onready var block_mountain: Button = $UI/BlockForm/Panel/Margin/Blocks/BlockMountain
@onready var block_water: Button = $UI/BlockForm/Panel/Margin/Blocks/BlockWater

# 状态
var _tool: ToolMode = ToolMode.BRUSH
var _selected_block_id: int = HexMap.BLOCK_GRASS_ID
var _undo_stack := UndoStack.new()

# 平移
var _panning := false

# 画笔/橡皮擦
var _drawing := false
var _last_painted_coord := Vector2i(99999, 99999)

# 鼠标悬停
var _hover_coord := Vector2i(99999, 99999)


func _ready() -> void:
	camera.enabled = true
	brush_button.pressed.connect(_on_tool_brush)
	pan_button.pressed.connect(_on_tool_pan)
	eraser_button.pressed.connect(_on_tool_eraser)
	block_grass.pressed.connect(_on_block_grass)
	block_mountain.pressed.connect(_on_block_mountain)
	block_water.pressed.connect(_on_block_water)
	_set_tool(ToolMode.BRUSH)
	_set_selected_block(HexMap.BLOCK_GRASS_ID)


func _on_tool_brush() -> void:
	_set_tool(ToolMode.BRUSH)

func _on_tool_pan() -> void:
	_set_tool(ToolMode.PAN)

func _on_tool_eraser() -> void:
	_set_tool(ToolMode.ERASER)

func _on_block_grass() -> void:
	_set_selected_block(HexMap.BLOCK_GRASS_ID)

func _on_block_mountain() -> void:
	_set_selected_block(HexMap.BLOCK_MOUNTAIN_ID)

func _on_block_water() -> void:
	_set_selected_block(HexMap.BLOCK_WATER_ID)


func _set_tool(tool: ToolMode) -> void:
	_tool = tool
	brush_button.button_pressed = (tool == ToolMode.BRUSH)
	pan_button.button_pressed = (tool == ToolMode.PAN)
	eraser_button.button_pressed = (tool == ToolMode.ERASER)
	match tool:
		ToolMode.BRUSH:
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		ToolMode.PAN:
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		ToolMode.ERASER:
			Input.set_default_cursor_shape(Input.CURSOR_FORBIDDEN)
	queue_redraw()


func _set_selected_block(block_id: int) -> void:
	_selected_block_id = block_id
	block_grass.button_pressed = (block_id == HexMap.BLOCK_GRASS_ID)
	block_mountain.button_pressed = (block_id == HexMap.BLOCK_MOUNTAIN_ID)
	block_water.button_pressed = (block_id == HexMap.BLOCK_WATER_ID)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		if k.keycode == KEY_Z and (k.ctrl_pressed or k.meta_pressed):
			_do_undo()
			return
		if k.keycode == KEY_Y and (k.ctrl_pressed or k.meta_pressed):
			_do_redo()
			return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_left_mouse_down()
			else:
				_on_left_mouse_up()
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)


func _on_left_mouse_down() -> void:
	match _tool:
		ToolMode.BRUSH:
			_undo_stack.begin_step()
			_drawing = true
			_paint_at(_get_mouse_coord())
		ToolMode.ERASER:
			_undo_stack.begin_step()
			_drawing = true
			_erase_at(_get_mouse_coord())
		ToolMode.PAN:
			_panning = true


func _on_left_mouse_up() -> void:
	if _drawing:
		_undo_stack.end_step()
		_drawing = false
		_last_painted_coord = Vector2i(99999, 99999)
	if _panning:
		_panning = false


func _on_mouse_motion(mm: InputEventMouseMotion) -> void:
	if _panning:
		# 用屏幕坐标增量，避免相机移动后鼠标全局坐标跟着变导致的震颤
		camera.position -= mm.relative / camera.zoom
		return
	var coord := _get_mouse_coord()
	if coord != _hover_coord:
		_hover_coord = coord
		queue_redraw()
	if _drawing and coord != _last_painted_coord:
		match _tool:
			ToolMode.BRUSH:
				_paint_at(coord)
			ToolMode.ERASER:
				_erase_at(coord)


func _paint_at(coord: Vector2i) -> void:
	var before := hex_map.paint_cell(coord, _selected_block_id)
	_undo_stack.record_change(coord, before.source, before.atlas, _selected_block_id, HexMap.ATLAS_COORD)
	_last_painted_coord = coord


func _erase_at(coord: Vector2i) -> void:
	var before := hex_map.erase_at(coord)
	_undo_stack.record_change(coord, before.source, before.atlas, HexMap.INVALID_SOURCE, HexMap.INVALID_ATLAS)
	_last_painted_coord = coord


func _get_mouse_coord() -> Vector2i:
	return hex_map.local_to_map(get_global_mouse_position())


func _do_undo() -> void:
	var step: Array = _undo_stack.undo()
	if step.is_empty():
		return
	for entry in step:
		var coord: Vector2i = entry["coord"]
		var before: Dictionary = entry["before"]
		hex_map.set_cell_data(coord, before)
	queue_redraw()


func _do_redo() -> void:
	var step: Array = _undo_stack.redo()
	if step.is_empty():
		return
	for entry in step:
		var coord: Vector2i = entry["coord"]
		var after: Dictionary = entry["after"]
		hex_map.set_cell_data(coord, after)
	queue_redraw()


# 绘制鼠标悬停高亮（画笔/橡皮擦模式）
func _draw() -> void:
	if _tool == ToolMode.PAN:
		return
	if _hover_coord == Vector2i(99999, 99999):
		return
	var center := hex_map.map_to_local(_hover_coord)
	var r := 30.0
	var points := PackedVector2Array()
	for i in 6:
		var angle := PI / 6.0 + i * PI / 3.0  # 30°起始 -> 尖顶六边形
		points.append(center + Vector2(r * cos(angle), r * sin(angle)))
	var fill := Color(1.0, 1.0, 1.0, 0.25)
	if _tool == ToolMode.ERASER:
		fill = Color(1.0, 0.3, 0.3, 0.35)
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(1.0, 1.0, 1.0, 0.85), 2.0, true)
