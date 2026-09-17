## 六边形图块基底资源
## 从 SVG 解析出外六边形（边框外边界）和内六边形（填充边界）的顶点，
## 运行时根据不同地块颜色生成带固定边框的纹理。
class_name HexShape
extends Resource

## 外六边形顶点（边框外边界）
@export var outer_points: PackedVector2Array = PackedVector2Array()
## 内六边形顶点（填充边界，外六边形与内六边形之间为边框）
@export var inner_points: PackedVector2Array = PackedVector2Array()
## 固定边框颜色
@export var border_color: Color = Color(0.20, 0.12, 0.04, 1.0)


## 从 SVG 文件解析六边形顶点
## SVG 需包含两个 path：第一个为外六边形，第二个为内六边形
static func from_svg(svg_path: String, p_border_color: Color = Color(0.20, 0.12, 0.04, 1.0)) -> HexShape:
	var file := FileAccess.open(svg_path, FileAccess.READ)
	assert(file != null, "无法打开 SVG: %s" % svg_path)
	var content := file.get_as_text()
	file.close()

	# 解析 transform 偏移（如 translate(-68.608)）
	var offset_x := 0.0
	var offset_y := 0.0
	var transform_regex := RegEx.new()
	transform_regex.compile("translate\\(([-\\d.]+)(?:,\\s*([-\\d.]+))?\\)")
	var tr_match := transform_regex.search(content)
	if tr_match:
		offset_x = float(tr_match.get_string(1))
		if tr_match.get_string(2) != "":
			offset_y = float(tr_match.get_string(2))

	# 提取所有 path 的 d 属性
	var paths: Array[String] = []
	var path_regex := RegEx.new()
	path_regex.compile("<path[^>]*d=\"([^\"]+)\"")
	var pm := path_regex.search(content)
	while pm:
		paths.append(pm.get_string(1))
		pm = path_regex.search(content, pm.get_end())

	assert(paths.size() >= 2, "SVG 至少需要两个 path（外六边形 + 内六边形）")

	var shape := HexShape.new()
	shape.border_color = p_border_color
	shape.outer_points = _parse_path(paths[0], offset_x, offset_y)
	shape.inner_points = _parse_path(paths[1], offset_x, offset_y)
	return shape


## 解析 SVG path d 属性，返回顶点数组（仅支持 M/L/Z 命令）
static func _parse_path(d: String, offset_x: float, offset_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var regex := RegEx.new()
	regex.compile("([MLZ])\\s*([-\\d.]+)?\\s*([-\\d.]+)?")
	var m := regex.search(d)
	while m:
		var cmd := m.get_string(1)
		if cmd == "M" or cmd == "L":
			var x := float(m.get_string(2)) + offset_x
			var y := float(m.get_string(3)) + offset_y
			points.append(Vector2(x, y))
		m = regex.search(d, m.get_end())
	return points


## 根据地块颜色生成六边形纹理（外边框 + 内填充，外部透明）
func make_texture(fill_color: Color, size: Vector2i) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	# 默认全透明
	img.fill(Color(0, 0, 0, 0))
	# 1. 外六边形填充边框色
	if outer_points.size() >= 3:
		_fill_polygon(img, outer_points, border_color)
	# 2. 内六边形填充地块色（覆盖边框色）
	if inner_points.size() >= 3:
		_fill_polygon(img, inner_points, fill_color)
	var tex := ImageTexture.new()
	tex.set_image(img)
	return tex


## 扫描线多边形填充（Godot 4 Image 无 fill_polygon，自行实现）
static func _fill_polygon(img: Image, points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var w := img.get_width()
	var h := img.get_height()
	# 边界框
	var min_y := int(ceil(points[0].y))
	var max_y := int(floor(points[0].y))
	for p in points:
		min_y = min(min_y, int(ceil(p.y)))
		max_y = max(max_y, int(floor(p.y)))
	min_y = max(min_y, 0)
	max_y = min(max_y, h - 1)

	# 逐扫描线求交点并填充
	for y in range(min_y, max_y + 1):
		var intersections: Array[float] = []
		var n := points.size()
		for i in range(n):
			var p1 := points[i]
			var p2 := points[(i + 1) % n]
			var y1 := p1.y
			var y2 := p2.y
			# 边跨越扫描线 y
			if (y1 <= y and y2 > y) or (y2 <= y and y1 > y):
				var t := (y - y1) / (y2 - y1)
				var x := p1.x + t * (p2.x - p1.x)
				intersections.append(x)
		intersections.sort()
		# 奇偶配对填充
		for i in range(0, intersections.size() - 1, 2):
			var x1 := int(ceil(intersections[i]))
			var x2 := int(floor(intersections[i + 1]))
			x1 = max(x1, 0)
			x2 = min(x2, w - 1)
			for x in range(x1, x2 + 1):
				img.set_pixel(x, y, color)
