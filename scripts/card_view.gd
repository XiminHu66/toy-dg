extends Button
const Cards = preload("res://scripts/cards.gd")
var card_id := "strike"
var font: Font
var chosen := false
var ordinal := 0
var summary := ""
var compact := false
var turn := 0
signal hovered(view: Control)
signal unhovered(view: Control)

func _init() -> void:
	custom_minimum_size = Vector2(180,230)

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var card: Dictionary = Cards.DATA[card_id]
	var color := Color(card.color)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("1a2938") if state!="hover" else Color("304457")
		style.border_color = color if chosen or state in ["hover","focus"] else Color(color,0.55)
		style.set_border_width_all(2)
		style.set_corner_radius_all(9)
		add_theme_stylebox_override(state,style)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,10)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",5)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	add_label(heading,"%d" % card.cost,23,color)
	add_label(heading,card.name,20,color)
	var art := TextureRect.new()
	art.texture = load("res://assets/art/rin.webp") if card.has("attack") else load("res://assets/art/sealed-sanctum.webp")
	art.custom_minimum_size.y = 56
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(color,0.85)
	column.add_child(art)
	add_label(column,summary,14,color)
	var description := add_label(column,card.text,13,Color("e2e6ef"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_label(column,("消耗" if card.get("exhaust",false) else card.type)+("  [%d]" % (ordinal%10) if ordinal>0 else ""),12,Color("97b1c7"))
	ignore_mouse(margin)
	tooltip_text = card.text+"\n"+summary
	# Keep text legible when unaffordable; only tint the artwork.
	if disabled:
		art.modulate.a = 0.35
	mouse_entered.connect(func(): hovered.emit(self))
	mouse_exited.connect(func(): unhovered.emit(self))

func add_label(parent: Node,value: String,font_size: int,color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse(child)

func _get_drag_data(_point: Vector2) -> Variant:
	if ordinal<=0 or disabled:
		return null
	var preview := Label.new()
	preview.text = "「%s」→ 目标" % Cards.DATA[card_id].name
	preview.add_theme_font_override("font",font)
	preview.add_theme_font_size_override("font_size",22)
	set_drag_preview(preview)
	return {"kind":"card","index":ordinal-1,"id":card_id,"turn":turn}
