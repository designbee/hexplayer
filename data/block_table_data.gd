## 区块表总数据
## 整个右侧栏的完整结构：多个分组
class_name BlockTableData
extends Resource

const ICON_DIR := "res://asset/ico/"

@export var groups: Array[BlockGroupData] = []


## 从颜色映射.md 解析构建 BlockTableData
## md 格式：
##   组名
##   名称 #RRGGBB [icon文件名]
##   ...
static func parse_from_md(md_path: String) -> BlockTableData:
	var table := BlockTableData.new()
	if not FileAccess.file_exists(md_path):
		push_error("BlockTableData: md 文件不存在: %s" % md_path)
		return table

	var file := FileAccess.open(md_path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var current_group: BlockGroupData = null
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("#"):
			continue

		if line.contains("#"):
			# 项：名称 #RRGGBB [icon]
			var parts := line.split("#", false, 1)
			var item_name := parts[0].strip_edges()
			var rest := parts[1].strip_edges()
			var color_hex := ""
			var icon_name := ""
			var rest_parts := rest.split(" ", false, 1)
			if rest_parts.size() >= 1:
				color_hex = rest_parts[0].strip_edges()
			if rest_parts.size() >= 2:
				icon_name = rest_parts[1].strip_edges()

			var color := Color.WHITE
			if color_hex.length() == 6:
				color = Color("#" + color_hex)

			var icon: Texture2D = null
			if not icon_name.is_empty():
				var icon_path := ICON_DIR + icon_name + ".svg"
				if ResourceLoader.exists(icon_path):
					icon = load(icon_path)

			var item := BlockItemData.new(item_name, color, icon)
			if current_group == null:
				current_group = BlockGroupData.new("未分组")
				table.groups.append(current_group)
			current_group.items.append(item)
		else:
			# 组名
			current_group = BlockGroupData.new(line)
			table.groups.append(current_group)

	return table


## 获取所有项的扁平化列表（按组顺序）
func get_all_items() -> Array[BlockItemData]:
	var all: Array[BlockItemData] = []
	for g in groups:
		for it in g.items:
			all.append(it)
	return all
