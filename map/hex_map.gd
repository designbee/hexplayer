## 六边形地图
## 负责 TileSet 配置（运行时生成场景化六边形 tile）和单格 paint/erase/get/set 操作
## 不处理连续绘制、撤销栈、高亮预览等交互逻辑（这些由 main.gd 协调）
class_name HexMap
extends TileMapLayer

# 六边形尺寸 = tile 尺寸（变形六边形，刚好填满 tile，边框完全在内部不超出）
# tile_size.y 必须能被 4 整除，使行间距 tile_size.y*3/4 为整数
const TILE_SIZE := Vector2i(68, 76)
const ATLAS_COORD := Vector2i(0, 0)
const INVALID_SOURCE := -1
const INVALID_ATLAS := Vector2i(-1, -1)

# 边框颜色（固定）
const BORDER_COLOR := Color(0.20, 0.12, 0.04, 1.0)
# 图标缩放比例（256px 图标 → 约 34px）
const ICON_SCALE := 0.133
# 图标透明度
const ICON_ALPHA := 0.6
# SVG 资源路径
const BORDER_SVG := "res://asset/ico/hex/hex_border.svg"
const FILL_SVG := "res://asset/ico/hex/hex_fill.svg"


## 根据区块项列表生成 TileSet（索引即 block_id/source_id）
## 每种地形对应一个 TileSetScenesSource，内含一个 PackedScene
func setup_tileset(items: Array[BlockItemData]) -> void:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	ts.tile_layout = TileSet.TILE_LAYOUT_STACKED
	ts.tile_size = TILE_SIZE

	var border_tex := load(BORDER_SVG)
	var fill_tex := load(FILL_SVG)

	for block_id in items.size():
		var item: BlockItemData = items[block_id]
		var packed := _make_tile_scene(border_tex, fill_tex, item)
		var source := TileSetScenesCollectionSource.new()
		source.create_scene_tile(packed, 0)
		var source_id := ts.add_source(source)
		assert(source_id == block_id, "TileSet source_id 与 block_id 不匹配: %d != %d" % [source_id, block_id])

	tile_set = ts
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## 生成单个图块场景：边框(底) + 填充(中) + 图标(顶)
func _make_tile_scene(border_tex: Texture2D, fill_tex: Texture2D, item: BlockItemData) -> PackedScene:
	var root := Node2D.new()

	# 边框层（最底层，深棕色）
	var border := Sprite2D.new()
	border.texture = border_tex
	border.modulate = BORDER_COLOR
	root.add_child(border)
	border.owner = root

	# 填充层（中间，地形色）
	var fill := Sprite2D.new()
	fill.texture = fill_tex
	fill.modulate = item.color
	root.add_child(fill)
	fill.owner = root

	# 图标层（最上层）
	if item.icon:
		var icon := Sprite2D.new()
		icon.texture = item.icon
		icon.scale = Vector2(ICON_SCALE, ICON_SCALE)
		icon.modulate = Color(1.0, 1.0, 1.0, ICON_ALPHA)
		root.add_child(icon)
		icon.owner = root

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("HexMap: 无法打包图块场景: %s" % item.name)
	root.queue_free()
	return packed


## 绘制单个格子（block_id 为区块 ID）
## 返回操作前的格子状态 { source, atlas }
func paint_cell(coord: Vector2i, block_id: int) -> Dictionary:
	var before := get_cell_data(coord)
	set_cell(coord, block_id, ATLAS_COORD)
	return before


## 擦除单个格子
## 返回操作前的格子状态 { source, atlas }
func erase_at(coord: Vector2i) -> Dictionary:
	var before := get_cell_data(coord)
	set_cell(coord, INVALID_SOURCE)
	return before


## 读取格子状态
func get_cell_data(coord: Vector2i) -> Dictionary:
	return {
		"source": get_cell_source_id(coord),
		"atlas": get_cell_atlas_coords(coord),
	}


## 设置格子状态（用于撤销/重做时回退）
func set_cell_data(coord: Vector2i, data: Dictionary) -> void:
	var source: int = int(data.get("source", INVALID_SOURCE))
	var atlas = data.get("atlas", INVALID_ATLAS)
	if source == INVALID_SOURCE:
		set_cell(coord, INVALID_SOURCE)
	else:
		set_cell(coord, source, atlas)


## 获取鼠标位置对应的格子坐标
func get_cell_at_local(local_pos: Vector2) -> Vector2i:
	return local_to_map(local_pos)


## 获取格子中心对应的本地坐标
func get_center_local(coord: Vector2i) -> Vector2:
	return map_to_local(coord)


## 获取所有已绘制（非空）格子的坐标列表
func get_painted_cells() -> Array[Vector2i]:
	return get_used_cells()
