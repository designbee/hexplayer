## 区块表单组
## 组标题 + 两列表单项网格
class_name BlockGroup
extends VBoxContainer

signal item_selected(item: BlockItemData)

var data: BlockGroupData = null
var items_grid: GridContainer = null


func setup(group_data: BlockGroupData, item_scene: PackedScene) -> void:
	data = group_data
	var title_label: Label = get_node("Title")
	items_grid = get_node("Items")
	title_label.text = group_data.name
	for child in items_grid.get_children():
		child.queue_free()
	for item_data in group_data.items:
		var item: BlockItem = item_scene.instantiate()
		item.setup(item_data)
		item.selected.connect(_on_item_selected)
		items_grid.add_child(item)


func _on_item_selected(item: BlockItemData) -> void:
	item_selected.emit(item)
