# HexPlayer

在线六边形地图草稿工具，基于 Godot 4 制作，可运行在浏览器中。

## 功能

- 矢量六边形图块渲染（SVG 场景化 TileSet）
- 50+ 种地形地块（平地、林间、湿地、水系等）
- 笔刷绘制 / 橡皮擦除
- Alt+左键临时擦除
- 空格/中键+左键拖动平移
- 滚轮缩放（10% – 200%）
- 撤销 / 重做（Ctrl+Z / Ctrl+Y）
- 鼠标悬停高亮

## 技术栈

- **引擎**：Godot 4.7
- **渲染**：TileSetScenesCollectionSource + Sprite2D（SVG 矢量）
- **字体**：思源黑体 (Source Han Sans SC)
- **协议**：MIT

## 本地运行

需要 Godot 4.7+，打开 `project.godot` 即可。

## Web 导出

```bash
# 在 Godot 编辑器中：项目 → 导出 → Web → 导出到 src/ 目录
# 然后用本地服务器测试：
cd src
python -m http.server 8080
# 访问 http://localhost:8080
```

## 许可证

MIT License，详见 [LICENSE](LICENSE)。
