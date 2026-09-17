## 区块表组数据
## 对应右侧栏中的一个分组：组名 + 多个表单项
class_name BlockGroupData
extends Resource

@export var name: String = ""
@export var items: Array[BlockItemData] = []


func _init(p_name: String = "") -> void:
	name = p_name
