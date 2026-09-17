## 区块表单项数据
## 对应右侧栏中的一个可选项：名称、颜色、图标
class_name BlockItemData
extends Resource

@export var name: String = ""
@export var color: Color = Color.WHITE
@export var icon: Texture2D = null


func _init(p_name: String = "", p_color: Color = Color.WHITE, p_icon: Texture2D = null) -> void:
	name = p_name
	color = p_color
	icon = p_icon
