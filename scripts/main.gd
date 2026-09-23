extends Control
const Session = preload("res://scripts/session.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Board = preload("res://scripts/board.gd")
const InventoryView = preload("res://scripts/inventory_view.gd")
const Rules = preload("res://scripts/rules.gd")
var game := Session.new()
var font: Font
var body: HBoxContainer
var footer: RichTextLabel
var header_stats: Label
var selection := ""
var selected_container := "bag"
var target_id := ""
var skill := "slash"
var input_mode := "move"
var board: Control
var item_details: RichTextLabel
var item_buttons: HBoxContainer
var bag_view: Control
var stash_view: Control
var toast := ""
var save_ok := true
var quit_after_test := false

func _ready() -> void:
	font = load("res://assets/fonts/DungeonSans.ttf")
	var theme_value := Theme.new()
	theme_value.default_font = font
	theme_value.default_font_size = 16
	theme_value.set_color("font_color","Label",Color("dce5ef"))
	theme_value.set_color("font_color","Button",Color("dce5ef"))
	theme_value.set_color("font_hover_color","Button",Color("ffffff"))
	theme_value.set_color("font_disabled_color","Button",Color("63788b"))
	theme_value.set_stylebox("normal","Button",box("233744",8))
	theme_value.set_stylebox("hover","Button",box("345465",8))
	theme_value.set_stylebox("pressed","Button",box("346a68",8))
	theme_value.set_stylebox("disabled","Button",box("192632",8))
	set_theme(theme_value)
	game.load_game()
	if "--capture" in OS.get_cmdline_user_args() or "--smoke" in OS.get_cmdline_user_args():
		game = Session.new(23)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+edge,22)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation",14)
	margin.add_child(page)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 55
	page.add_child(header)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_column)
	label(title_column,"地城拾遗",29,"eef3fa")
	label(title_column,"RELIC / RUNNER     ·     封印矿井",12,"76b7b2")
	header_stats = label(header,"",17,"e8cc99")
	body = HBoxContainer.new()
	body.add_theme_constant_override("separation",18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var footer_panel := PanelContainer.new()
	footer_panel.add_theme_stylebox_override("panel",box("0e1b28",10))
	footer_panel.custom_minimum_size.y = 108
	page.add_child(footer_panel)
	footer = RichTextLabel.new()
	footer.bbcode_enabled = true
	footer.scroll_following = true
	footer.add_theme_font_override("normal_font",font)
	footer.add_theme_font_size_override("normal_font_size",14)
	footer_panel.add_child(footer)
	refresh()
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/screenshots/camp.png")
		game.start_run()
		refresh()
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/screenshots/combat.png")
		print("CAPTURE_OK")
		get_tree().quit()
	if "--smoke" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		game.start_run()
		refresh()
		await get_tree().process_frame
		var rect := body.get_global_rect()
		if rect.end.y > get_viewport_rect().size.y or rect.end.x > get_viewport_rect().size.x:
			push_error("Interface body exceeds viewport")
		for test_phase in ["event","loot","exit","camp"]:
			game.phase = test_phase
			if test_phase == "loot":
				game.pending_loot = [game.make_item(0,2),game.make_item(3,1)]
			refresh()
			await get_tree().process_frame
		print("UI_SMOKE_OK")
		get_tree().quit()

func box(hex: String, radius: int = 12) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color(hex)
	result.set_corner_radius_all(radius)
	result.content_margin_left = 14
	result.content_margin_right = 14
	result.content_margin_top = 10
	result.content_margin_bottom = 10
	return result

func label(parent: Node,text_value: String,font_size: int = 16,color: String = "dce5ef") -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",Color(color))
	parent.add_child(result)
	return result

func paragraph(parent: Node,text_value: String,color: String = "94aaba") -> Label:
	var result := label(parent,text_value,15,color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func button(parent: Node,text_value: String,action: Callable,disabled: bool = false) -> Button:
	var result := Button.new()
	result.text = text_value
	result.custom_minimum_size.y = 38
	result.disabled = disabled
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func panel(parent: Node,expand: bool = false) -> VBoxContainer:
	var container := PanelContainer.new()
	container.add_theme_stylebox_override("panel",box("101e2c"))
	if expand:
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(container)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	container.add_child(column)
	return column

func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func refresh() -> void:
	clear(body)
	board = null
	bag_view = null
	stash_view = null
	header_stats.text = "%s   /   金币 %d   /   本局 %d" % ["营地" if game.phase == "camp" else "探索中",game.gold,game.run_gold]
	var left := panel(body,true)
	var right_wrap := ScrollContainer.new()
	right_wrap.custom_minimum_size.x = 375
	right_wrap.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right_wrap)
	var right := panel(right_wrap)
	right.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match game.phase:
		"camp": camp(left)
		"combat": combat(left)
		"loot": loot(left)
		"event": event_room(left)
		"exit": exit_room(left)
	build_right(right)
	footer.clear()
	for line in game.log_lines.slice(maxi(0,game.log_lines.size()-5)):
		footer.append_text("[color=#b4c5d5]"+str(line)+"[/color]\n")
	if not toast.is_empty():
		footer.append_text("[color=#f2c981]"+toast+"[/color]\n")

func finish_action(success: bool) -> void:
	toast = "" if success else game.last_error
	if success:
		save_ok = game.save_game()
		if not save_ok:
			toast = "存档写入失败，请保持页面打开。"
	refresh()
	if board != null:
		board.animate()

func camp(column: VBoxContainer) -> void:
	label(column,"01 / 整备营地",13,"68cdb9")
	label(column,"下一次出发，带回更好的答案。",24,"e8edf5")
	paragraph(column,"仓库里的影步指环可以解锁位移。选择装备后可穿戴、出售或转移；拖拽调整位置，按 R 旋转。")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	column.add_child(row)
	button(row,"进入封印矿井  →",func(): target_id=""; finish_action(game.start_run()))
	var cost := 60 + int(game.equipment.weapon.level)*40
	button(row,"强化武器  ·  %d 金币" % cost,func(): finish_action(game.upgrade_weapon()),game.gold<cost or game.equipment.weapon.level>=3)
	label(column,"仓库  /  10 × 8",16,"a4b9cc")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	stash_view = make_inventory(scroll,game.stash,Session.STASH,43,"stash")
	paragraph(column,"探索路线：入口守卫 → 封印匣事件 → 核心战斗 → 撤离。战斗结束后可提前撤离。")
	label(column,"原型美术 · 战斗与经济验证版",12,"677f91")

func combat(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	column.add_child(row)
	var text_value := "02 / 矿井入口" if game.room == 0 else "04 / 封印核心"
	var route := label(row,text_value,18,"e5d1ad")
	route.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(row,"回合 %d   ·   AP %d   ·   移动力 %d" % [game.round_no,game.ap,game.movement],16,"69d7bd")
	var instructions := "点击空格移动，点击敌人选择目标。金色短线表示朝向；从背面攻击增伤20%。"
	paragraph(column,instructions)
	board = Board.new()
	board.session = game
	board.font = font
	board.mode = input_mode
	board.selected = target_id
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.cell_clicked.connect(on_cell)
	column.add_child(board)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",7)
	column.add_child(actions)
	button(actions,"移动",func(): input_mode="move"; refresh())
	for entry in [["slash","斩击"],["rupture","裂伤"],["dash","突进"]]:
		var key: String = entry[0]
		button(actions,("● " if skill==key else "")+entry[1],func(): skill=key; input_mode="move"; refresh())
	button(actions,"影步",func(): input_mode="shadow"; refresh(),game.player.shadowstep<1 or game.player.step_used or game.ap<1)
	button(actions,"防御",func(): finish_action(game.guard()),game.ap<1 or game.player.guard)
	button(actions,"药 ×%d" % game.potions,func(): finish_action(game.heal()),game.ap<1 or game.potions<1 or game.player.hp>=game.player.max_hp)
	button(actions,"结束回合",func(): finish_action(game.end_turn()))
	var selected := game.unit_by_id(target_id)
	if not selected.is_empty() and selected.hp > 0:
		var preview := HBoxContainer.new()
		column.add_child(preview)
		var back := Rules.behind(game.player.position,selected.position,selected.facing)
		var coefficient := 0.75 if skill=="rupture" else (1.1 if skill=="dash" else 1.0)
		var multiplier := 1.2 if back else 1.0
		var low := Rules.damage(game.player.attack*coefficient+2,selected.defense,game.player.penetration,multiplier)
		var high := Rules.damage(game.player.attack*coefficient+12,selected.defense,game.player.penetration,multiplier)
		var summary := "%s  HP %d  韧性 %d\n命中 %d%% · 伤害 %d–%d · %s" % [selected.name,selected.hp,selected.toughness,Rules.chance(game.player,selected),low,high,"背面 ×1.2" if back else "正面／侧面"]
		var info := label(preview,summary,14,"e8c37e")
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button(preview,"执行技能 · 2 AP",func(): finish_action(game.strike(target_id,skill)),game.ap<2)
	else:
		label(column,"敌人意图：向你接近并近战攻击（行动时重新瞄准）。选择目标查看命中率。",14,"91aabc")

func on_cell(point: Vector2i) -> void:
	for target in game.enemies:
		if target.hp > 0 and target.position == point:
			target_id = target.id
			refresh()
			return
	if input_mode == "shadow":
		finish_action(game.shadowstep(point))
	else:
		finish_action(game.move_player(point))

func loot(column: VBoxContainer) -> void:
	label(column,"战利品 / FIELD RECOVERY",13,"68cdb9")
	label(column,"每一格，都值得权衡。",28,"edf1f7")
	paragraph(column,"右侧背包中的青色标记代表本局新获得的物品。撤离才能保住它们；继续探索会放弃地上未拾取的物品。")
	for item in game.pending_loot:
		var card := panel(column)
		var color: String = game.catalog.rarities[int(item.rarity)].color
		label(card,"%s · %s" % [game.catalog.rarities[int(item.rarity)].name,item.name],21,color)
		paragraph(card,item_description(item),"c2cbd6")
		var id: String = item.id
		button(card,"收入背包  ·  %d × %d" % [item.w,item.h],func(): finish_action(game.take_loot(id)))
	if game.pending_loot.is_empty():
		paragraph(column,"这里已经没有待拾取的装备。")
	var stretch := Control.new()
	stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stretch)
	var row := HBoxContainer.new()
	column.add_child(row)
	button(row,"继续探索  →",func(): finish_action(game.continue_route()))
	button(row,"现在撤离 · 保住战利品",func(): finish_action(game.extract()))

func event_room(column: VBoxContainer) -> void:
	label(column,"03 / 遗迹事件",13,"68cdb9")
	label(column,"墙后，传来另一种心跳。",28,"e9d5b1")
	paragraph(column,"裂开的符文墙中嵌着一只旧时代的匣子。你可以观察封印的规律，或以意志压制其中的回声。骰子只在作出选择后投掷。")
	paragraph(column,"成功：获得一件稀有装备与25金币。失败：失去10生命（最低保留1点），事件仍然推进。每次探索只能检定一次。")
	button(column,"观察封印 · 感知 %d%%" % game.player.perception,func(): finish_action(game.resolve_event("perception")))
	button(column,"压制回声 · 意志 %d%%" % game.player.will,func(): finish_action(game.resolve_event("will")))
	button(column,"放弃匣子，进入核心",func(): finish_action(game.resolve_event("leave")))
	button(column,"撤离",func(): finish_action(game.extract()))

func exit_room(column: VBoxContainer) -> void:
	label(column,"05 / 返回地面",13,"68cdb9")
	label(column,"封印沉寂，行囊渐重。",28,"e9d5b1")
	paragraph(column,"本次探索完成。带着战利品回到营地，整理、出售或强化装备，为下一次深入做好准备。")
	button(column,"返回营地  ·  结算%d金币" % game.run_gold,func(): finish_action(game.extract()))

func build_right(column: VBoxContainer) -> void:
	label(column,"凛 / RELIC RUNNER",18,"e6edf7")
	var stats: Dictionary = game.player
	label(column,"生命 %d / %d" % [stats.hp,stats.max_hp],19,"6ed8bf")
	paragraph(column,"攻击 %d   防御 %d   敏捷 %d\n速度 %d   移动力 %d   破甲 %d\n暴击 %d%%   暴击倍率 %.2f\n感知 %d   意志 %d" % [stats.attack,stats.defense,stats.agility,stats.speed,stats.movement,stats.penetration,stats.crit,stats.crit_damage/100.0,stats.perception,stats.will])
	for slot in game.equipment:
		var item: Dictionary = game.equipment[slot]
		label(column,"▸ %s +%d" % [item.name,item.level],14,str(game.catalog.rarities[int(item.rarity)].color))
	var used := 0
	for item in game.bag:
		used += int(item.w)*int(item.h)
	label(column,"随身背包  /  %d · 30格" % used,16,"c5d4df")
	bag_view = make_inventory(column,game.bag,Session.BAG,43,"bag")
	item_details = RichTextLabel.new()
	item_details.custom_minimum_size.y = 115
	item_details.fit_content = true
	item_details.bbcode_enabled = true
	item_details.add_theme_font_override("normal_font",font)
	item_details.add_theme_font_size_override("normal_font_size",14)
	column.add_child(item_details)
	item_buttons = HBoxContainer.new()
	item_buttons.add_theme_constant_override("separation",5)
	column.add_child(item_buttons)
	refresh_selection()
	label(column,"%s" % ("每次操作后自动保存" if save_ok else "存档写入失败"),12,"708a9c")

func make_inventory(parent: Node,items: Array,bounds: Vector2i,cell: float,source: String) -> Control:
	var view := InventoryView.new()
	view.font = font
	view.items = items
	view.bounds = bounds
	view.cell = cell
	view.catalog = game.catalog
	view.editable = game.phase != "combat"
	view.selected_id = selection if selected_container == source else ""
	view.selected.connect(func(id): selection=id; selected_container=source; refresh_selection())
	view.moved.connect(func(id,point): finish_action(Inventory.move(items,id,point,bounds)))
	parent.add_child(view)
	return view

func selected_item() -> Dictionary:
	var items: Array = game.bag if selected_container == "bag" else game.stash
	for item in items:
		if item.id == selection:
			return item
	return {}

func item_description(item: Dictionary) -> String:
	var text_value := "出售 %d金币   每格 %.1f金币\n" % [item.value,float(item.value)/(item.w*item.h)]
	for key in ["attack","defense","hp"]:
		if item.has(key):
			var names := {"attack":"攻击","defense":"防御","hp":"生命"}
			text_value += "%s +%d  " % [names[key],int(item[key])+int(item.level)*2]
	for affix in item.affixes:
		text_value += "\n%s%s" % [affix.label,"" if affix.key=="shadowstep" else " +%d" % affix.value]
	return text_value

func refresh_selection() -> void:
	if item_details == null or not is_instance_valid(item_details):
		return
	if bag_view != null:
		bag_view.selected_id = selection if selected_container=="bag" else ""
		bag_view.queue_redraw()
	if stash_view != null:
		stash_view.selected_id = selection if selected_container=="stash" else ""
		stash_view.queue_redraw()
	clear(item_buttons)
	var item := selected_item()
	item_details.clear()
	if item.is_empty():
		item_details.append_text("[color=#7892a7]选择背包或仓库中的装备查看词条。\n营地可换装、转移和出售。[/color]")
		return
	item_details.append_text("[color=#%s]%s[/color]\n%s" % [game.catalog.rarities[int(item.rarity)].color,item.name,item_description(item)])
	var items: Array = game.bag if selected_container=="bag" else game.stash
	var bounds: Vector2i = Session.BAG if selected_container=="bag" else Session.STASH
	button(item_buttons,"旋转",func(): finish_action(Inventory.move(items,selection,Vector2i(int(item.x),int(item.y)),bounds,true)),game.phase=="combat")
	button(item_buttons,"装备",func(): finish_action(game.equip_item(selection,items)),game.phase!="camp")
	button(item_buttons,"出售",func(): confirm_sell(item,items),game.phase!="camp")
	button(item_buttons,"转移",func(): finish_action(Inventory.transfer(items,game.stash if selected_container=="bag" else game.bag,selection,Session.STASH if selected_container=="bag" else Session.BAG)),game.phase!="camp")

func confirm_sell(item: Dictionary,items: Array) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "出售装备"
	dialog.dialog_text = "出售「%s」，获得%d金币？\n原型尚未提供赎回，请确认。" % [item.name,item.value]
	dialog.ok_button_text = "确认出售"
	dialog.cancel_button_text = "保留"
	add_child(dialog)
	dialog.confirmed.connect(func(): finish_action(game.sell_item(item.id,items)); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(420,180))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and game.phase != "combat":
			var item := selected_item()
			if not item.is_empty():
				var items: Array = game.bag if selected_container=="bag" else game.stash
				finish_action(Inventory.move(items,selection,Vector2i(int(item.x),int(item.y)),Session.BAG if selected_container=="bag" else Session.STASH,true))
		if event.keycode == KEY_SPACE and game.phase == "combat":
			finish_action(game.end_turn())
