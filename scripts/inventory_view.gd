extends Control
const Inventory = preload("res://scripts/inventory.gd")
var hovered_id := ""
var drop_point := Vector2i(-1,-1)
var drop_item: Dictionary = {}
var drop_valid := false
signal selected(id: String)
signal moved(id: String, point: Vector2i)
var items: Array = []
var bounds := Vector2i(6,5)
var cell := 44.0
var font: Font
var selected_id := ""
var drag_id := ""
var editable := true
var catalog: Dictionary

func _ready() -> void:
	custom_minimum_size = Vector2(bounds)*cell
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	mouse_exited.connect(func(): hovered_id=""; queue_redraw())

func at(point: Vector2i) -> String:
	for item in items:
		if Rect2i(Vector2i(int(item.x),int(item.y)),Vector2i(int(item.w),int(item.h))).has_point(point):
			return str(item.id)
	return ""

func _get_tooltip(position_value: Vector2) -> String:
	var id := at(Vector2i(position_value/cell))
	for item in items:
		if item.id==id:
			var result := "%s +%d · %s\n出售 %d金币 / 每格 %.1f金币\n占用 %d×%d格" % [item.name,item.level,catalog.rarities[int(item.rarity)].name,item.value,float(item.value)/(item.w*item.h),item.w,item.h]
			for affix in item.affixes+([item.enchantment] if item.has("enchantment") else []):
				result += "\n%s +%d" % [affix.label,affix.value]
			return result+"\n点击查看 · 拖拽整理 · R旋转"
	return "空闲格 · 将装备拖到这里"

func _notification(what: int) -> void:
	if what==NOTIFICATION_DRAG_END:
		drop_item.clear()
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered_id = at(Vector2i(event.position/cell))
		queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := at(Vector2i(event.position/cell))
		if not id.is_empty():
			selected.emit(id)

func _get_drag_data(position_value: Vector2) -> Variant:
	if not editable:
		return null
	var id := at(Vector2i(position_value/cell))
	if id.is_empty():
		return null
	var preview := Label.new()
	preview.text = "移动装备"
	preview.add_theme_font_override("font",font)
	set_drag_preview(preview)
	selected.emit(id)
	return {"id":id,"source":get_instance_id()}

func _can_drop_data(position_value: Vector2,data: Variant) -> bool:
	if not editable or not data is Dictionary or data.get("source",0)!=get_instance_id():
		return false
	drop_point = Vector2i(position_value/cell)
	for item in items:
		if item.id==data.id:
			drop_item = item.duplicate()
			drop_valid = Inventory.fits(items,item,drop_point,bounds,str(item.id))
			queue_redraw()
			return drop_valid
	return false

func _drop_data(position_value: Vector2,data: Variant) -> void:
	moved.emit(str(data.id),Vector2i(position_value/cell))

func _draw() -> void:
	for y in range(bounds.y):
		for x in range(bounds.x):
			draw_rect(Rect2(Vector2(x,y)*cell,Vector2.ONE*(cell-2)),Color("15222f"))
	for item in items:
		var rect := Rect2(Vector2(float(item.x),float(item.y))*cell+Vector2.ONE,Vector2(float(item.w),float(item.h))*cell-Vector2.ONE*4)
		var color := Color(str(catalog.rarities[int(item.rarity)].color))
		draw_rect(rect,Color(color,0.28 if item.id==hovered_id else 0.14))
		draw_rect(rect,color if item.id == selected_id else Color(color,0.45),false,2 if item.id == selected_id else 1)
		var center_value := rect.get_center()
		if item.type == "weapon":
			draw_line(center_value+Vector2(-9,16),center_value+Vector2(10,-18),color,4)
			draw_line(center_value+Vector2(-11,5),center_value+Vector2(4,13),color,3)
		elif item.type == "armor":
			draw_colored_polygon(PackedVector2Array([center_value+Vector2(-14,-12),center_value+Vector2(14,-12),center_value+Vector2(10,14),center_value+Vector2(-10,14)]),Color(color,0.6))
		else:
			draw_arc(center_value,10,0,TAU,24,color,3)
		if rect.size.x >= 70:
			draw_string(font,rect.position+Vector2(6,17),str(item.name).left(4),HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
		if item.get("found",false):
			draw_circle(rect.position+Vector2(rect.size.x-6,6),3,Color("6fe1c5"))

	if not drop_item.is_empty():
		var footprint := Rect2(Vector2(drop_point)*cell,Vector2(float(drop_item.w),float(drop_item.h))*cell)
		var tint := Color("7de7bf") if drop_valid else Color("ee8795")
		draw_rect(footprint,Color(tint,0.25))
		draw_rect(footprint,tint,false,2)
