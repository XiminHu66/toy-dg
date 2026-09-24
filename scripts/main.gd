extends Control
const Session = preload("res://scripts/session.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Arena = preload("res://scripts/arena.gd")
const CardView = preload("res://scripts/card_view.gd")
const Cards = preload("res://scripts/cards.gd")
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
var selected_card := -1
var camp_tab := "出征"
var log_open := false
var board: Control
var item_details: RichTextLabel
var item_buttons: HBoxContainer
var bag_view: Control
var stash_view: Control
var toast := ""
var save_ok := true
var quit_after_test := false

func _ready() -> void:
	if OS.has_feature("launcher") or "--launcher-smoke" in OS.get_cmdline_user_args():
		get_tree().call_deferred("change_scene_to_file","res://launcher/launcher.tscn")
		return
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
	theme_value.set_stylebox("panel","AcceptDialog",box("101e2c",10))
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
	label(title_column,"RELIC / RUNNER     ·     牌与遗物",12,"76b7b2")
	header_stats = label(header,"",17,"e8cc99")
	body = HBoxContainer.new()
	body.add_theme_constant_override("separation",18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var footer_panel := PanelContainer.new()
	footer_panel.add_theme_stylebox_override("panel",box("0e1b28",10))
	footer_panel.custom_minimum_size.y = 65
	page.add_child(footer_panel)
	footer = RichTextLabel.new()
	footer.bbcode_enabled = true
	footer.scroll_following = true
	footer.add_theme_font_override("normal_font",font)
	footer.add_theme_font_size_override("normal_font_size",14)
	footer_panel.add_child(footer)
	refresh()
	if "--capture" in OS.get_cmdline_user_args():
		await capture_screen("camp")
		camp_tab = "仓库"
		refresh()
		await capture_screen("warehouse")
		camp_tab = "牌组"
		refresh()
		await capture_screen("deck")
		game.start_run()
		refresh()
		await capture_screen("combat")
		selected_card = game.hand.find("strike")
		refresh()
		await capture_screen("targeting")
		show_pile("抽牌堆",game.draw_pile)
		await capture_screen("pile")
		for child in get_children():
			if child is AcceptDialog:
				child.queue_free()
		game.phase = "loot"
		game.pending_loot = [game.make_item(0,3),game.make_item(3,2)]
		game.card_rewards = ["reap","bastion","echo"]
		refresh()
		await capture_screen("loot")
		print("CAPTURE_OK")
		get_tree().quit()
	if "--smoke" in OS.get_cmdline_user_args():
		game.start_run()
		for test_phase in ["combat","event","loot","exit","camp"]:
			game.phase = test_phase
			if test_phase == "loot":
				game.pending_loot = [game.make_item(0,3),game.make_item(3,2)]
				game.card_rewards = ["reap","bastion","echo"]
			refresh()
			await get_tree().process_frame
			await get_tree().process_frame
			check_layout(test_phase)
		for tab in ["出征","仓库","牌组"]:
			camp_tab = tab
			refresh()
			await get_tree().process_frame
			await get_tree().process_frame
			check_layout(tab)
		print("UI_SMOKE_OK")
		get_tree().quit()

func capture_screen(name_value: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/screenshots/"+name_value+".png")

func check_layout(phase_name: String) -> void:
	var rect := body.get_global_rect()
	if rect.end.y > get_viewport_rect().size.y-65 or rect.end.x > get_viewport_rect().size.x:
		push_error("Interface exceeds viewport: "+phase_name+" "+str(rect))

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
	item_details = null
	item_buttons = null
	if game.phase == "combat":
		var full := panel(body,true)
		combat(full)
	else:
		var left := panel(body,true)
		match game.phase:
			"camp": camp(left)
			"loot": loot(left)
			"event": event_room(left)
			"exit": exit_room(left)
		var right_wrap := ScrollContainer.new()
		right_wrap.custom_minimum_size.x = 350
		right_wrap.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		right_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(right_wrap)
		var right := panel(right_wrap)
		right.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		build_right(right)
	footer.clear()
	for line in game.log_lines.slice(maxi(0,game.log_lines.size()-2)):
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
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",10)
	column.add_child(tabs)
	for tab in ["出征","仓库","牌组"]:
		button(tabs,("● " if camp_tab==tab else "")+tab,func(): camp_tab=tab; refresh())
	if camp_tab == "仓库":
		label(column,"遗物档案 / 仓库",25,"e9d2aa")
		paragraph(column,"选择查看词条与估值；拖拽整理，R 旋转。右侧操作可穿戴、出售或转移。")
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(scroll)
		stash_view = make_inventory(scroll,game.stash,Session.STASH,49,"stash")
		return
	if camp_tab == "牌组":
		label(column,"出征牌组 · %d 张" % game.starting_deck().size(),25,"e9d2aa")
		paragraph(column,"基础牌 + 武器专属牌 + 特殊装备牌。战后获得的卡牌仅在本次探索中保留，装备长期保留。")
		deck_grid(column,game.starting_deck())
		return
	label(column,"封印矿井",32,"f1e8d8")
	paragraph(column,"在遗物与回声之间，寻找下一种可能。", "b4c6d4")
	var art := TextureRect.new()
	art.texture = load("res://assets/art/sealed-sanctum.webp")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size.y = 190
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(art)
	var itinerary := HBoxContainer.new()
	itinerary.add_theme_constant_override("separation",18)
	column.add_child(itinerary)
	for entry in [["01","入口遭遇"],["02","封印匣"],["03","核心守卫"],["04","带宝撤离"]]:
		var step := panel(itinerary,true)
		label(step,entry[0],23,"68cdb9")
		label(step,entry[1],15,"c6cfdc")
	paragraph(column,"3 能量 · 每回合抽 5 张 · 可见敌人意图
装备决定属性与专属卡牌；战后择牌、拾取装备，再决定是否深入。")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	column.add_child(row)
	var go := button(row,"开始探索  →",func(): selected_card=-1; target_id=""; finish_action(game.start_run()))
	go.custom_minimum_size = Vector2(250,52)
	go.add_theme_stylebox_override("normal",box("356b64",8))
	var cost := 60 + int(game.equipment.weapon.level)*40
	button(row,"强化武器 · %d 金币" % cost,func(): finish_action(game.upgrade_weapon()),game.gold<cost or game.equipment.weapon.level>=3)

func card_summary(id: String) -> String:
	var card: Dictionary = Cards.DATA[id]
	if card.has("attack"):
		return "攻击 ×%.0f%%" % (float(card.attack)*100)
	if card.has("block"):
		return "获得 %d 格挡" % game.card_block(card)
	return "抽 %d 张" % card.draw if card.has("draw") else "获得 2 能量"

func make_card(parent: Node,id: String,action: Callable,index: int = -1,disabled_value: bool = false) -> Button:
	var view := CardView.new()
	view.card_id = id
	view.font = font
	view.summary = card_summary(id)
	view.ordinal = index+1
	view.chosen = index>=0 and index==selected_card
	view.disabled = disabled_value
	view.pressed.connect(action)
	parent.add_child(view)
	return view

func deck_grid(parent: Node,ids: Array) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",10)
	scroll.add_child(grid)
	for id in ids:
		make_card(grid,id,func(): pass)

func show_pile(title_value: String,ids: Array) -> void:
	var window := AcceptDialog.new()
	window.title = title_value
	window.ok_button_text = "返回"
	add_child(window)
	var margin := MarginContainer.new()
	margin.offset_bottom = -50
	window.add_child(margin)
	deck_grid(margin,ids)
	window.confirmed.connect(window.queue_free)
	window.canceled.connect(window.queue_free)
	window.popup_centered(Vector2i(840,550))

func combat(column: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := label(top,"矿井入口" if game.room==0 else "封印核心",22,"e5d1ad")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(top,"第 %d 回合" % game.round_no,17,"c8d2e3")
	button(top,"牌组 %d" % game.run_deck.size(),func(): show_pile("本次探索牌组",game.run_deck))
	button(top,"行囊",show_bag)
	button(top,"战斗记录",show_log)
	board = Arena.new()
	board.session = game
	board.font = font
	board.selected = target_id
	if selected_card>=0 and selected_card<game.hand.size():
		board.preview_card = game.hand[selected_card]
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.target_clicked.connect(on_target)
	column.add_child(board)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",14)
	column.add_child(actions)
	var energy_label := label(actions,"%d / 3  能量" % game.energy,26,"83e0cf")
	energy_label.custom_minimum_size.x = 160
	var hint := label(actions,"选择攻击牌后点击敌人；技能牌直接生效。",15,"bcc8d9")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if selected_card>=0 and selected_card<game.hand.size():
		hint.text = "已选择「%s」· 点击敌人出牌 / Esc 取消" % Cards.DATA[game.hand[selected_card]].name
	elif game.energy==0:
		hint.text = "能量已用完，可使用 0 费牌或结束回合。"
	if game.momentum>0:
		hint.text += "  蓄势 +%d%%" % int(game.momentum*100)
	button(actions,"疗伤药 ×%d" % game.potions,func(): selected_card=-1; finish_action(game.heal()),game.energy<1 or game.potions<1 or game.player.hp>=game.player.max_hp)
	var end := button(actions,"结束回合  [空格]",func(): selected_card=-1; finish_action(game.end_turn()))
	end.add_theme_stylebox_override("normal",box("70554a",8))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 234
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	scroll.add_child(row)
	for i in range(game.hand.size()):
		var index := i
		var card: Dictionary = Cards.DATA[game.hand[i]]
		make_card(row,game.hand[i],func(): select_card(index),i,game.energy<int(card.cost) or game.player.hp<=int(card.get("hp_cost",0)))
	var piles := HBoxContainer.new()
	piles.add_theme_constant_override("separation",12)
	column.add_child(piles)
	button(piles,"抽牌堆 %d" % game.draw_pile.size(),func(): var cards: Array=game.draw_pile.duplicate(); cards.sort(); show_pile("抽牌堆 · 不显示顺序",cards))
	button(piles,"弃牌堆 %d" % game.discard_pile.size(),func(): show_pile("弃牌堆",game.discard_pile))
	button(piles,"消耗区 %d" % game.exhaust_pile.size(),func(): show_pile("消耗区 · 本场不再抽到",game.exhaust_pile))
	label(piles,"快捷键 1–9 选牌 · Esc 取消 · 手牌上限 10",13,"7e96ac")

func select_card(index: int) -> void:
	if index<0 or index>=game.hand.size():
		return
	var card: Dictionary = Cards.DATA[game.hand[index]]
	if card.has("attack"):
		selected_card = -1 if selected_card==index else index
		refresh()
	else:
		selected_card = -1
		finish_action(game.play_card(index))

func on_target(id: String) -> void:
	target_id = id
	if selected_card>=0:
		var index := selected_card
		selected_card = -1
		finish_action(game.play_card(index,id))
	else:
		refresh()

func show_log() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "探索记录"
	dialog.dialog_text = "\n".join(game.log_lines.slice(maxi(0,game.log_lines.size()-18)))
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(820,530))

func show_bag() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "随身行囊 · 战斗中只读"
	add_child(dialog)
	var column := VBoxContainer.new()
	dialog.add_child(column)
	label(column,"空间管理在战斗结束后开放。装备与金币均保持原规则。",14)
	make_inventory(column,game.bag,Session.BAG,50,"bag")
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(650,410))

func loot(column: VBoxContainer) -> void:
	label(column,"战利品 / FIELD RECOVERY",13,"68cdb9")
	label(column,"战利品与新的可能",25,"edf1f7")
	paragraph(column,"右侧背包中的青色标记代表本局新获得的物品。撤离才能保住它们；继续探索会放弃地上未拾取的物品。")
	if not game.card_rewards.is_empty():
		label(column,"战术领悟 · 三选一加入本局牌组（可跳过）",17,"c4a5ef")
		var rewards := HBoxContainer.new()
		rewards.add_theme_constant_override("separation",12)
		column.add_child(rewards)
		for id in game.card_rewards:
			make_card(rewards,id,func(): finish_action(game.choose_reward(id)))
	var gear_row := HBoxContainer.new()
	gear_row.add_theme_constant_override("separation",12)
	column.add_child(gear_row)
	for item in game.pending_loot:
		var card := panel(gear_row,true)
		var color: String = game.catalog.rarities[int(item.rarity)].color
		label(card,"%s · %s" % [game.catalog.rarities[int(item.rarity)].name,item.name],18,color)
		paragraph(card,item_description(item).replace("\n","  "),"c2cbd6")
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
	paragraph(column,"防御／敏捷增强格挡 · 速度增加首回合抽牌\n移动力强化掠影／影步 · 意志增强心刃", "718ca2")
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
		if game.phase == "combat":
			if event.keycode == KEY_SPACE:
				selected_card = -1
				finish_action(game.end_turn())
			elif event.keycode == KEY_ESCAPE:
				selected_card = -1
				refresh()
			elif event.keycode>=KEY_1 and event.keycode<=KEY_9:
				select_card(event.keycode-KEY_1)
			elif event.keycode==KEY_0:
				select_card(9)
