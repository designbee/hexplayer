## 区块表单项按钮
## 左侧彩色图标背景 + 图标，右侧名称文字；选中时高亮
class_name BlockItem
extends Button

signal selected(item: BlockItemData)

var data: BlockItemData = null


func _ready() -> void:
	pressed.connect(_on_pressed)


func setup(item_data: BlockItemData) -> void:
	data = item_data
	var icon_bg: ColorRect = get_node("HBox/IconBg")
	var icon_rect: TextureRect = get_node("HBox/IconBg/Icon")
	var label: Label = get_node("HBox/Label")
	label.text = item_data.name
	icon_bg.color = item_data.color
	if item_data.icon != null:
		icon_rect.texture = item_data.icon
	else:
		icon_rect.texture = null


func _on_pressed() -> void:
	if data != null:
		selected.emit(data)
