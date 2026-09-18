## 主控制器
## 工具切换、区块选择、输入分发、撤销/重做、缩放、鼠标悬停高亮
class_name MainController
extends Node2D

enum ToolMode { BRUSH, PAN, ERASER }

# 节点引用
@onready var hex_map: HexMap = $HexMap
@onready var camera: Camera2D = $MainCamera
@onready var brush_button: Button = $UI/TopMenuMargin/TopMenu/BrushButton
@onready var pan_button: Button = $UI/TopMenuMargin/TopMenu/PanButton
@onready var eraser_button: Button = $UI/TopMenuMargin/TopMenu/EraserButton
@onready var groups_container: VBoxContainer = $UI/BlockForm/Margin/GroupsScroll/Groups
@onready var zoom_out_btn: Button = $UI/ZoomBar/HBox/ZoomOut
@onready var zoom_in_btn: Button = $UI/ZoomBar/HBox/ZoomIn
@onready var zoom_label: Label = $UI/ZoomBar/HBox/ZoomLabel
@onready var undo_btn: Button = $UI/ZoomBar/HBox/UndoButton
@onready var redo_btn: Button = $UI/ZoomBar/HBox/RedoButton
@onready var export_btn: Button = $UI/TopMenuMargin/TopMenu/ExportButton
@onready var import_btn: Button = $UI/TopMenuMargin/TopMenu/ImportButton
@onready var save_reminder: Label = $UI/SaveReminder
@onready var save_timer: Timer = $SaveTimer

# 数据
var block_table: BlockTableData = null
var block_items: Array[BlockItemData] = []  # 扁平化列表，索引即 block_id

# 状态
var _tool: ToolMode = ToolMode.BRUSH
var _selected_block_id: int = 0
var _undo_stack := UndoStack.new()

# 平移
var _panning := false
var _previous_tool: ToolMode = ToolMode.BRUSH  # 临时拖动前的工具模式
var _temp_pan_active := false  # 是否处于空格/中键触发的临时拖动
var _temp_eraser_active := false  # 是否处于右键触发的临时擦除

# 画笔/橡皮擦
var _drawing := false
var _last_painted_coord := Vector2i(99999, 99999)

# 鼠标悬停
var _hover_coord := Vector2i(99999, 99999)

# 保存提醒
var _last_save_time: float = -1.0  # -1 表示从未保存
# 导入轮询（Web 环境）
var _waiting_for_import := false

# 缩放
const ZOOM_MIN := 0.1
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1


func _ready() -> void:
	camera.enabled = true

	# 加载区块表数据
	block_table = BlockTableData.parse_from_text(ColorData.RAW_MD)
	block_items = block_table.get_all_items()

	# 生成 TileSet
	hex_map.setup_tileset(block_items)

	# 构建右侧栏
	_build_block_form()

	# 连接信号
	brush_button.pressed.connect(func(): _set_tool(ToolMode.BRUSH))
	pan_button.pressed.connect(func(): _set_tool(ToolMode.PAN))
	eraser_button.pressed.connect(func(): _set_tool(ToolMode.ERASER))
	zoom_out_btn.pressed.connect(_on_zoom_out)
	zoom_in_btn.pressed.connect(_on_zoom_in)
	undo_btn.pressed.connect(_do_undo)
	redo_btn.pressed.connect(_do_redo)
	export_btn.pressed.connect(_on_export)
	import_btn.pressed.connect(_on_import)
	save_timer.timeout.connect(_on_save_timer_tick)

	# 撤销/重做按钮使用 SVG 图标（缩放到 20x20 适配按钮）
	var undo_tex := load("res://asset/ico/undo.svg") as Texture2D
	var redo_tex := load("res://asset/ico/redo.svg") as Texture2D
	var undo_img := undo_tex.get_image()
	undo_img.resize(20, 20, Image.INTERPOLATE_LANCZOS)
	var redo_img := redo_tex.get_image()
	redo_img.resize(20, 20, Image.INTERPOLATE_LANCZOS)
	undo_btn.icon = ImageTexture.create_from_image(undo_img)
	redo_btn.icon = ImageTexture.create_from_image(redo_img)
	undo_btn.text = ""
	redo_btn.text = ""

	_set_tool(ToolMode.BRUSH)
	if block_items.size() > 0:
		_selected_block_id = 0
	_update_zoom_label()


## 构建右侧栏：实例化每个组
func _build_block_form() -> void:
	var item_scene := preload("res://ui/block_item.tscn")
	var group_scene := preload("res://ui/block_group.tscn")
	for group_data in block_table.groups:
		var group: BlockGroup = group_scene.instantiate()
		group.setup(group_data, item_scene)
		group.item_selected.connect(_on_block_selected)
		groups_container.add_child(group)


func _on_block_selected(item: BlockItemData) -> void:
	_selected_block_id = block_items.find(item)
	# 更新所有项的选中状态
	for group in groups_container.get_children():
		for item_node in group.items_grid.get_children():
			if item_node is BlockItem:
				item_node.button_pressed = (item_node.data == item)


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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_SPACE:
			if k.pressed:
				_enter_temp_pan()
			else:
				_exit_temp_pan()
			return
		if k.pressed:
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
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_enter_temp_pan()
				_panning = true  # 中键按下直接开始拖动
			else:
				_panning = false
				_exit_temp_pan()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# 鼠标在右侧表单区域时，滚轮交给表单滚动，不缩放地图
			if $UI/BlockForm.get_global_rect().has_point(get_viewport().get_mouse_position()):
				return
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at_mouse(1.0 + ZOOM_STEP)
			else:
				_zoom_at_mouse(1.0 - ZOOM_STEP)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)


## 进入临时拖动模式（空格/中键按下）
func _enter_temp_pan() -> void:
	if _temp_pan_active:
		return
	_previous_tool = _tool
	_temp_pan_active = true
	_set_tool(ToolMode.PAN)


## 退出临时拖动模式（空格/中键抬起），恢复上一个工具
func _exit_temp_pan() -> void:
	if not _temp_pan_active:
		return
	_temp_pan_active = false
	_set_tool(_previous_tool)


## Alt+左键按下：临时切换到橡皮擦，开始擦除
func _on_left_mouse_down() -> void:
	if _temp_pan_active or _tool == ToolMode.PAN:
		_panning = true
		return
	# Alt+左键 → 临时擦除
	if _temp_eraser_active or (_tool != ToolMode.ERASER and Input.is_key_pressed(KEY_ALT)):
		if not _temp_eraser_active:
			_previous_tool = _tool
			_temp_eraser_active = true
			_set_tool(ToolMode.ERASER)
		_undo_stack.begin_step()
		_drawing = true
		_erase_at(_get_mouse_coord())
		return
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
	if _temp_eraser_active:
		_temp_eraser_active = false
		_set_tool(_previous_tool)
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


# === 缩放 ===

## 以鼠标位置为中心缩放
func _zoom_at_mouse(factor: float) -> void:
	var new_zoom := clampf(camera.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	if new_zoom == camera.zoom.x:
		return
	var mouse_world := get_global_mouse_position()
	camera.zoom = Vector2(new_zoom, new_zoom)
	# 缩放后让鼠标世界坐标保持在原位
	camera.position = mouse_world - (get_viewport().get_mouse_position() - get_viewport().get_visible_rect().size / 2.0) / new_zoom
	_update_zoom_label()


## 以屏幕中心缩放（按钮触发）
func _zoom_by_step(delta: float) -> void:
	var new_zoom := clampf(camera.zoom.x + delta, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(new_zoom, new_zoom)
	_update_zoom_label()


func _on_zoom_out() -> void:
	_zoom_by_step(-ZOOM_STEP)


func _on_zoom_in() -> void:
	_zoom_by_step(ZOOM_STEP)


func _update_zoom_label() -> void:
	zoom_label.text = "%d%%" % int(camera.zoom.x * 100.0)


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


# === 导出 / 导入 / 保存提醒 ===

## 导出 JSON（Web 环境通过 JavaScript 触发下载）
func _on_export() -> void:
	var data := hex_map.get_tile_data()
	var json_str := JSON.stringify(data)
	var filename := "hexmap_%s.json" % Time.get_datetime_string_from_system().replace(":", "").replace(" ", "_")

	if OS.has_feature("web"):
		var js := (
			"var blob = new Blob([\"%s\"], {type: 'application/json'});\n" +
			"var a = document.createElement('a');\n" +
			"a.href = URL.createObjectURL(blob);\n" +
			"a.download = '%s';\n" +
			"document.body.appendChild(a);\n" +
			"a.click();\n" +
			"document.body.removeChild(a);"
		) % [json_str.replace("\"", "\\\""), filename]
		JavaScriptBridge.eval(js)
	else:
		var path := "user://%s" % filename
		FileAccess.open(path, FileAccess.WRITE).store_string(json_str)

	_last_save_time = Time.get_ticks_msec() / 1000.0
	_update_save_reminder()


## 导入 JSON
## Web 环境用浏览器原生文件选择器（通过 JavaScript）
## 桌面环境用 Godot FileDialog
func _on_import() -> void:
	if OS.has_feature("web"):
		var js := (
			"var input = document.createElement('input');\n" +
			"input.type = 'file';\n" +
			"input.accept = '.json';\n" +
			"input.onchange = function(e) {\n" +
			"    var file = e.target.files[0];\n" +
			"    if (!file) return;\n" +
			"    var reader = new FileReader();\n" +
			"    reader.onload = function(ev) {\n" +
			"        window._godot_import_data = ev.target.result;\n" +
			"    };\n" +
			"    reader.readAsText(file);\n" +
			"};\n" +
			"input.click();"
		)
		JavaScriptBridge.eval(js)
		_waiting_for_import = true
	else:
		var dialog := FileDialog.new()
		dialog.title = "选择地图文件"
		dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.filters = PackedStringArray(["*.json ; JSON 文件"])
		add_child(dialog)
		dialog.file_selected.connect(_on_import_file_selected)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered(Vector2i(600, 400))


func _process(_delta: float) -> void:
	if _waiting_for_import:
		var result = JavaScriptBridge.eval("window._godot_import_data")
		if result != null:
			_waiting_for_import = false
			JavaScriptBridge.eval("window._godot_import_data = null")
			_import_from_string(result)


func _on_import_file_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("无法读取文件: %s" % path)
		return
	var json_str := file.get_as_text()
	file.close()
	_import_from_string(json_str)


## 从 JSON 字符串导入地图数据（含校验）
func _import_from_string(json_str: String) -> void:
	var parsed = JSON.parse_string(json_str)
	if not parsed is Dictionary:
		push_error("无效的 JSON 格式")
		return
	if not parsed.has("tiles") or not parsed["tiles"] is Dictionary:
		push_error("不是有效的地图存档（缺少 tiles 字段）")
		return
	hex_map.load_tile_data(parsed)
	_undo_stack = UndoStack.new()
	queue_redraw()
	_last_save_time = Time.get_ticks_msec() / 1000.0
	_update_save_reminder()


## 保存提醒计时器触发
func _on_save_timer_tick() -> void:
	_update_save_reminder()


## 更新左下角保存提醒文字
func _update_save_reminder() -> void:
	if _last_save_time < 0:
		save_reminder.text = "未保存"
		return
	var elapsed := int(Time.get_ticks_msec() / 1000.0 - _last_save_time)
	var minutes := elapsed / 60
	if minutes < 1:
		save_reminder.text = "刚刚保存"
	elif minutes < 60:
		save_reminder.text = "%d 分钟前保存" % minutes
	else:
		save_reminder.text = "%d 小时前保存" % (minutes / 60)
