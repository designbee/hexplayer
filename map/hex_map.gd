## 六边形地图
## 负责 TileSet 配置（运行时生成纯色六边形 tile）和单格 paint/erase/get/set 操作
## 不处理连续绘制、撤销栈、高亮预览等交互逻辑（这些由 main.gd 协调）
class_name HexMap
extends TileMapLayer

# pointy-top 六边形外接矩形：宽 = √3*r，高 = 2*r。取 r=38 → 宽≈65.82，高=76
# 关键：tile_size.y 必须能被 4 整除，使行间距 tile_size.y*3/4 为整数，避免行间半像素缝隙
const TILE_SIZE := Vector2i(66, 76)
const ATLAS_COORD := Vector2i(0, 0)
const INVALID_SOURCE := -1
const INVALID_ATLAS := Vector2i(-1, -1)

# 区块 ID 常量（也用作 TileSet 中的 source_id）
const BLOCK_GRASS_ID := 0
const BLOCK_MOUNTAIN_ID := 1
const BLOCK_WATER_ID := 2

const BLOCK_COLORS := {
	BLOCK_GRASS_ID: Color(0.65, 0.80, 0.55),
	BLOCK_MOUNTAIN_ID: Color(0.62, 0.58, 0.50),
	BLOCK_WATER_ID: Color(0.50, 0.70, 0.85),
}

const BLOCK_NAMES := {
	BLOCK_GRASS_ID: "草原",
	BLOCK_MOUNTAIN_ID: "山地",
	BLOCK_WATER_ID: "水系",
}

const BLOCK_IDS := [BLOCK_GRASS_ID, BLOCK_MOUNTAIN_ID, BLOCK_WATER_ID]


func _ready() -> void:
	_setup_tileset()


func _setup_tileset() -> void:
	var ts := TileSet.new()
	# 尖顶六边形 (pointy-top) + 堆叠布局
	ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	ts.tile_layout = TileSet.TILE_LAYOUT_STACKED
	ts.tile_size = TILE_SIZE
	for block_id in BLOCK_IDS:
		var color: Color = BLOCK_COLORS[block_id]
		var tex := _make_hex_texture(color)
		var source := TileSetAtlasSource.new()
		source.texture = tex
		source.texture_region_size = TILE_SIZE
		source.create_tile(ATLAS_COORD)
		var source_id := ts.add_source(source)
		assert(source_id == block_id, "TileSet source_id 与 block_id 不匹配: %d != %d" % [source_id, block_id])
	tile_set = ts


## 生成纯色尖顶六边形纹理（六边形外的像素透明）
func _make_hex_texture(color: Color) -> ImageTexture:
	var w := TILE_SIZE.x
	var h := TILE_SIZE.y
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(w / 2.0, h / 2.0)
	var r := float(h) / 2.0  # pointy-top 外接圆半径 = 高度的一半
	for y in h:
		for x in w:
			var dx: float = abs(x + 0.5 - center.x)
			var dy: float = abs(y + 0.5 - center.y)
			if _is_in_pointy_hex(dx, dy, r):
				img.set_pixel(x, y, color)
	var tex := ImageTexture.new()
	tex.set_image(img)
	return tex


## 判断像素是否在尖顶六边形内
## dx, dy 是相对中心的绝对偏移；r 是六边形外接圆半径
## 尖顶六边形顶点 (0, ±r), (±r*sqrt(3)/2, ±r/2)
## 包含条件: dy <= r 且 dx <= r*sqrt(3)/2 且 dx/sqrt(3) + dy <= r
func _is_in_pointy_hex(dx: float, dy: float, r: float) -> bool:
	if dy > r:
		return false
	if dx > r * sqrt(3.0) / 2.0:
		return false
	return dx / sqrt(3.0) + dy <= r


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
