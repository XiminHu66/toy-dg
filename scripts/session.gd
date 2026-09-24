extends RefCounted
const Rules = preload("res://scripts/rules.gd")
const Inventory = preload("res://scripts/inventory.gd")
const BOARD := Vector2i(8,6)
const BAG := Vector2i(6,5)
const STASH := Vector2i(10,8)
const DIRECTIONS := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
const SAVE_VERSION := 3
const Dungeon = preload("res://scripts/dungeon.gd")
const DRAW_COST := 120
const Cards = preload("res://scripts/cards.gd")

var dungeon: Array = []
var map_position := 0
var encounter_kind := "combat"
var scouts := 2
var draw_pity := 0
var draw_history: Array = []

var run_deck: Array = []
var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []
var card_rewards: Array = []
var energy := 3
var momentum := 0.0
var retain_block := false

var rng := RandomNumberGenerator.new()
var catalog: Dictionary
var phase := "camp"
var room := 0
var gold := 120
var run_gold := 0
var serial := 0
var bag: Array = []
var stash: Array = []
var equipment: Dictionary = {}
var pending_loot: Array = []
var after_loot := "event"
var player: Dictionary = {}
var enemies: Array = []
var walls: Array = []
var turn_queue: Array = []
var round_no := 0
var player_turn := false
var ap := 2
var movement := 4
var potions := 2
var log_lines: Array = []
var last_result: Dictionary = {}
var last_error := ""
var event_used := false
var save_path := "user://profile.json"

func _init(seed_value: int = -1) -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var weapon := make_item(0,0)
	var armor := make_item(2,0)
	equipment = {"weapon":weapon,"armor":armor}
	var charm := make_item(3,1)
	charm.affixes = [{"key":"shadowstep","label":"技能：影步","value":1}]
	Inventory.add(stash,charm,STASH)
	player = build_player()
	note("欢迎回来，拾遗者。仓库中的指环可解锁影步；整备后进入封印矿井。装备会为牌组提供专属卡牌。")

func note(message: String) -> void:
	log_lines.append(message)
	if log_lines.size() > 60:
		log_lines.pop_front()

func fail(message: String) -> bool:
	last_error = message
	return false

func make_item(base_index: int = -1, rarity: int = -1) -> Dictionary:
	if base_index < 0:
		base_index = rng.randi_range(0,catalog.bases.size()-1)
	if rarity < 0:
		var roll := rng.randi_range(1,100)
		rarity = 3 if roll > 94 else (2 if roll > 65 else (1 if roll > 25 else 0))
	var item: Dictionary = catalog.bases[base_index].duplicate(true)
	serial += 1
	item.id = "item-%d" % serial
	item.rarity = rarity
	item.level = 0
	item.affixes = []
	item.found = phase != "camp"
	var pool: Array = catalog.affixes.duplicate(true)
	for _i in range(int(catalog.rarities[rarity].affixes)):
		var index := rng.randi_range(0,pool.size()-1)
		var affix: Dictionary = pool.pop_at(index)
		item.affixes.append({"key":affix.key,"label":affix.label,"value":rng.randi_range(int(affix.min),int(affix.max))})
	item.value = int(item.value * float(catalog.rarities[rarity].multiplier))
	item.x = 0
	item.y = 0
	return item

func build_player() -> Dictionary:
	var stats := {"id":"player","name":"凛 · 拾遗者","hp":90,"max_hp":90,"attack":12,"defense":6,"agility":12,"speed":12,"movement":4,"crit":20,"crit_damage":150,"penetration":0,"toughness":14,"perception":60,"will":55,"bleed":0,"shadowstep":0,"position":Vector2i(1,3),"facing":Vector2i.RIGHT,"bleeds":[],"broken":false,"guard":false,"guarded_round":-1,"step_used":false,"block":0}
	for item in equipment.values():
		for key in ["attack","defense","hp"]:
			if item.has(key):
				stats[key] += int(item[key]) + int(item.level)*2
		for affix in item.affixes + ([item.enchantment] if item.has("enchantment") else []):
			if stats.has(affix.key):
				stats[affix.key] += int(affix.value)
	stats.max_hp = stats.hp
	stats.max_toughness = stats.toughness
	return stats

func start_run() -> bool:
	if phase != "camp":
		return fail("当前已经在探索中。")
	for item in bag:
		item.found = false
	player = build_player()
	room = 0
	run_gold = 0
	event_used = false
	potions = 2
	pending_loot.clear()
	run_deck = starting_deck()
	card_rewards.clear()
	dungeon = Dungeon.generate(rng)
	map_position = 0
	scouts = clampi(1+int(player.perception/50),1,3)
	phase = "explore"
	player_turn = false
	note("抵达入口。点击亮边迷雾探路；数字代表周围八格最初的危险数量。")
	return true

func starting_deck() -> Array:
	var result: Array = Cards.STARTER.duplicate()
	result.append("quick" if equipment.weapon.key == "dagger" else "heavy")
	if build_player().shadowstep > 0:
		result.append("shadowstep")
	return result

func shuffle_cards(cards: Array) -> void:
	for i in range(cards.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var value: Variant = cards[i]
		cards[i] = cards[j]
		cards[j] = value

func draw_cards(count: int) -> void:
	for _i in range(count):
		if hand.size() >= 10:
			break
		if draw_pile.is_empty():
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			shuffle_cards(draw_pile)
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())

func start_encounter() -> void:
	phase = "combat"
	player.bleeds = []
	player.block = 0
	player.broken = false
	player.toughness = player.max_toughness
	walls.clear()
	turn_queue.clear()
	enemies.clear()
	if encounter_kind == "combat":
		enemies.append(enemy("watcher","铜壳守卫",Vector2i(5,2),46,11,8,8))
		enemies.append(enemy("crawler","裂隙猎犬",Vector2i(6,4),32,9,3,14))
	else:
		enemies.append(enemy("warden","遗迹监守者",Vector2i(6,2),85,15,18,9))
		enemies.append(enemy("drone","符文浮游机",Vector2i(5,3),28,10,4,11))
	if encounter_kind == "elite":
		enemies[0].hp = 65
		enemies[0].max_hp = 65
	if run_deck.is_empty():
		run_deck = starting_deck()
	draw_pile = run_deck.duplicate()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	shuffle_cards(draw_pile)
	last_result = {}
	round_no = 0
	retain_block = false
	note("进入%s。观察敌人意图，点击手牌，再点击目标出牌。" % ("矿井入口" if room == 0 else "封印核心"))
	begin_round()

func enemy(id: String, name_value: String, pos: Vector2i, health: int, attack: int, defense: int, speed: int) -> Dictionary:
	return {"id":id,"name":name_value,"position":pos,"facing":Vector2i.LEFT,"hp":health,"max_hp":health,"attack":attack,"defense":defense,"speed":speed,"agility":8,"crit":10,"crit_damage":150,"penetration":0,"movement":2,"toughness":10,"max_toughness":10,"bleeds":[],"broken":false,"guard":false,"guarded_round":-1,"bleed":0,"block":0,"vulnerable":0,"intent":{}}

func begin_round() -> void:
	round_no += 1
	energy = 3
	ap = energy
	momentum = 0.0
	if not retain_block:
		player.block = 0
	retain_block = false
	player_turn = true
	draw_cards(5 + (clampi(int((player.speed-12)/3),0,2) if round_no == 1 else 0))
	for target in enemies:
		if target.hp > 0:
			target.intent = make_intent(target)

func make_intent(target: Dictionary) -> Dictionary:
	var step := (round_no-1)%3
	if target.id == "watcher" and step == 1:
		return {"name":"筑甲","damage":0,"hits":0,"block":12,"bleed":0}
	if target.id == "warden" and step == 0:
		return {"name":"蓄势","damage":0,"hits":0,"block":8,"bleed":0}
	var hits := 2 if target.id in ["crawler","drone"] and step == 1 else 1
	var raw := int(target.attack) + (8 if target.id == "warden" and step == 1 else 0)
	if hits == 2:
		raw = maxi(1,int(raw*0.65))
	return {"name":"撕咬" if target.id == "crawler" and step == 2 else ("连击" if hits == 2 else "猛攻"),"damage":raw,"hits":hits,"block":0,"bleed":2 if target.id == "crawler" and step == 2 else 0}

func intent_damage(target: Dictionary) -> int:
	var amount := int(target.intent.get("damage",0))
	if target.broken:
		amount = int(amount*0.5)
	return amount

func unit_by_id(id: String) -> Dictionary:
	if id == "player":
		return player
	for target in enemies:
		if str(target.id) == id:
			return target
	return {}

func card_block(card: Dictionary) -> int:
	if not card.has("block"):
		return 0
	return int(card.block) + int(player.defense/3) + int(player.agility/6) + (int(player.movement) if card.has("momentum") else 0)

func card_damage(card: Dictionary,target: Dictionary,critical: bool = false) -> int:
	var raw := float(player.attack)*float(card.get("attack",0)) + float(card.get("flat",0)) + float(player.will)*float(card.get("will",0))
	if not target.bleeds.is_empty():
		raw += float(card.get("bleed_bonus",0))
	var multiplier := (1.0+momentum) * (1.5 if target.get("vulnerable",0)>0 else 1.0)
	if critical:
		multiplier *= float(player.crit_damage)/100.0
	return Rules.damage(raw,0 if card.has("will") else target.defense,player.penetration,multiplier)

func play_card(index: int,target_id: String = "") -> bool:
	if phase != "combat" or not player_turn or index < 0 or index >= hand.size():
		return fail("请选择当前手牌。")
	var id: String = hand[index]
	var card: Dictionary = Cards.DATA[id]
	if energy < int(card.cost):
		return fail("能量不足。")
	if player.hp <= int(card.get("hp_cost",0)):
		return fail("生命不足，无法支付这张牌的代价。")
	var target := unit_by_id(target_id)
	if card.has("attack") and (target.is_empty() or target_id == "player" or target.hp <= 0):
		return fail("请点击一个存活敌人作为目标。")
	energy -= int(card.cost)
	ap = energy
	hand.remove_at(index)
	# Resolve draw before discarding this card, so it cannot draw itself.
	player.hp -= int(card.get("hp_cost",0))
	player.block += card_block(card)
	if card.get("retain_block",false):
		retain_block = true
	if card.has("momentum"):
		momentum += float(card.momentum) + float(player.movement)*0.05
	energy += int(card.get("energy",0))
	ap = energy
	last_result = {"kind":"card","name":card.name,"target_id":target_id,"damage":0,"block":card_block(card),"crit":false}
	if card.has("attack"):
		var critical := rng.randi_range(1,100) <= clampi(int(player.crit),0,100)
		var damage := card_damage(card,target,critical)
		var absorbed := mini(int(target.block),damage)
		target.block -= absorbed
		target.hp = maxi(0,int(target.hp)-damage+absorbed)
		last_result.damage = damage-absorbed
		last_result.crit = critical
		momentum = 0.0
		if card.has("bleed") or player.bleed > 0:
			if target.bleeds.size() < 3:
				target.bleeds.append({"damage":int(card.get("bleed",0))+int(player.bleed),"turns":2})
		target.toughness = maxi(0,int(target.toughness)-int(card.get("stagger",2)))
		if target.toughness == 0:
			target.broken = true
		target.vulnerable = maxi(int(target.vulnerable),int(card.get("vulnerable",0)))
		note("%s → %s：%s%d伤害，格挡吸收%d。" % [card.name,target.name,"暴击 " if critical else "",damage-absorbed,absorbed])
	else:
		note("打出%s，获得%d格挡。" % [card.name,card_block(card)])
	draw_cards(int(card.get("draw",0)))
	if card.get("exhaust",false):
		exhaust_pile.append(id)
	else:
		discard_pile.append(id)
	check_battle()
	return true

func end_turn() -> bool:
	if phase != "combat" or not player_turn:
		return false
	player_turn = false
	discard_pile.append_array(hand)
	hand.clear()
	var total_damage := 0
	for target in enemies:
		if target.hp <= 0:
			continue
		tick_bleed(target)
		if target.hp <= 0:
			continue
		target.block = int(target.intent.get("block",0))
		for _hit in range(int(target.intent.get("hits",0))):
			var damage := intent_damage(target)
			var absorbed := mini(int(player.block),damage)
			player.block -= absorbed
			player.hp = maxi(0,int(player.hp)-damage+absorbed)
			total_damage += damage-absorbed
			if target.intent.get("bleed",0)>0 and damage>absorbed and player.bleeds.size()<3:
				player.bleeds.append({"damage":maxi(1,int(target.intent.bleed)-int(player.max_toughness/15)),"turns":2})
		if target.broken:
			target.broken = false
			target.toughness = target.max_toughness
		target.vulnerable = maxi(0,int(target.vulnerable)-1)
		if player.hp <= 0:
			break
	tick_bleed(player)
	last_result = {"kind":"enemy_turn","damage":total_damage}
	note("敌方行动结束：承受%d点直接伤害。" % total_damage)
	check_battle()
	if phase == "combat":
		begin_round()
	return true

func heal() -> bool:
	if phase != "combat" or not player_turn or energy < 1 or potions < 1:
		return fail("疗伤药需要1能量，每次探索补给2瓶。")
	if player.hp >= player.max_hp:
		return fail("生命已满。")
	potions -= 1
	energy -= 1
	ap = energy
	player.hp = mini(int(player.max_hp),int(player.hp)+30)
	last_result = {"kind":"heal"}
	note("使用疗伤药，恢复最多30生命。")
	return true

func choose_reward(id: String) -> bool:
	if phase != "loot" or not card_rewards.has(id):
		return fail("当前没有这张卡牌奖励。")
	run_deck.append(id)
	card_rewards.clear()
	note("%s加入本次探索牌组。" % Cards.DATA[id].name)
	return true

func tick_bleed(unit: Dictionary) -> void:
	var expired: Array = []
	for status in unit.bleeds:
		unit.hp = maxi(0,int(unit.hp)-int(status.damage))
		status.turns -= 1
		note("%s 流血，失去%d生命。" % [unit.name,status.damage])
		if status.turns <= 0:
			expired.append(status)
	for status in expired:
		unit.bleeds.erase(status)

func check_battle() -> void:
	if phase != "combat":
		return
	if player.hp <= 0:
		var retained: Array = []
		for item in bag:
			if not item.get("found",false):
				retained.append(item)
		bag = retained
		run_gold = 0
		gold = maxi(0,gold-30)
		phase = "camp"
		player_turn = false
		note("探索失败：新战利品遗失，带入装备保留；维修最多30金币。营地已恢复生命。")
		player = build_player()
		return
	for target in enemies:
		if target.hp > 0:
			return
	run_gold += 55 if room == 0 else 100
	pending_loot = [make_item(),make_item(-1,2 if room == 1 else 1)]
	card_rewards = Cards.REWARDS.duplicate()
	shuffle_cards(card_rewards)
	card_rewards = card_rewards.slice(0,3) if room == 0 else []
	after_loot = "explore" if not dungeon.is_empty() else ("event" if room == 0 else "exit")
	if not dungeon.is_empty():
		dungeon[map_position].cleared = true
	phase = "loot"
	player_turn = false
	note("战斗胜利。选择值得带走的装备，再决定深入或撤离。")

func take_loot(id: String) -> bool:
	if phase != "loot":
		return false
	for i in range(pending_loot.size()):
		if str(pending_loot[i].id) == id:
			if not Inventory.add(bag,pending_loot[i],BAG):
				return fail("背包空间不足，可以旋转或整理后再拾取。")
			note("拾取 %s。" % pending_loot[i].name)
			pending_loot.remove_at(i)
			return true
	return false

func continue_route() -> bool:
	if phase == "loot":
		card_rewards.clear()
		pending_loot.clear()
		phase = after_loot
		if phase == "next_battle":
			room = 1
			encounter_kind = "boss"
			start_encounter()
		return true
	return false

func resolve_event(choice: String) -> bool:
	if phase != "event" or event_used:
		return false
	if choice not in ["perception","will","leave"]:
		return false
	event_used = true
	card_rewards.clear()
	if choice == "leave":
		if not dungeon.is_empty():
			dungeon[map_position].cleared = true
			phase = "explore"
		else:
			room = 1
			encounter_kind = "boss"
			start_encounter()
		return true
	var roll := rng.randi_range(1,100)
	var outcome := Rules.event_check(int(player[choice]),roll)
	last_result = {"kind":"event","roll":roll,"chance":player[choice],"outcome":outcome}
	note("封印匣 · %s检定：d100=%d / %d，%s。" % ["感知" if choice == "perception" else "意志",roll,player[choice],outcome])
	if outcome != "失败":
		pending_loot = [make_item(-1,2)]
		run_gold += 25
	else:
		player.hp = maxi(1,int(player.hp)-10)
		pending_loot = []
		note("符文反噬：失去10生命。你仍可继续探索或撤离。")
	after_loot = "explore" if not dungeon.is_empty() else "next_battle"
	if not dungeon.is_empty():
		dungeon[map_position].cleared = true
	phase = "loot"
	return true

func extract() -> bool:
	if phase not in ["loot","event","exit","explore"]:
		return fail("战斗中无法直接撤离。")
	if not dungeon.is_empty() and not can_extract():
		return fail("请先返回入口，或击败核心后在核心撤离。")
	card_rewards.clear()
	gold += run_gold
	note("撤离成功：带回%d金币和背包中的装备。" % run_gold)
	run_gold = 0
	for item in bag:
		item.found = false
	pending_loot.clear()
	phase = "camp"
	player = build_player()
	return true

func equip_item(id: String, source: Array) -> bool:
	if phase != "camp":
		return fail("请在营地更换装备。")
	for i in range(source.size()):
		var item: Dictionary = source[i]
		if item.id != id:
			continue
		var next_source: Array = source.duplicate(true)
		next_source.remove_at(i)
		if equipment.has(item.type):
			var bounds := BAG if is_same(source,bag) else STASH
			if not Inventory.add(next_source,equipment[item.type].duplicate(true),bounds):
				return fail("需要空间存放替换下来的装备。")
		source.clear()
		source.append_array(next_source)
		equipment[item.type] = item
		player = build_player()
		note("装备 %s。" % item.name)
		return true
	return false

func sell_item(id: String, source: Array) -> bool:
	if phase != "camp":
		return fail("请回营地出售装备。")
	for i in range(source.size()):
		if source[i].id == id:
			if source[i].get("locked",false):
				return fail("装备已锁定，请先解锁。")
			gold += int(source[i].value)
			note("出售 %s，获得%d金币。" % [source[i].name,source[i].value])
			source.remove_at(i)
			return true
	return false

func owned_item(id: String) -> Dictionary:
	for item in equipment.values()+bag+stash:
		if str(item.id)==id:
			return item
	return {}

func upgrade_cost(item: Dictionary) -> int:
	return 60+int(item.level)*40

func enchant_cost(item: Dictionary) -> int:
	return 80+int(item.get("enchant_count",0))*40

func upgrade_item(id: String) -> bool:
	var item := owned_item(id)
	if phase!="camp" or item.is_empty():
		return fail("请在营地选择自己的装备。")
	if int(item.level)>=5:
		return fail("强化已达到+5。")
	var cost := upgrade_cost(item)
	if gold<cost:
		return fail("强化需要%d金币。" % cost)
	gold -= cost
	item.level += 1
	player = build_player()
	note("%s强化至+%d，花费%d金币。" % [item.name,item.level,cost])
	return true

func upgrade_weapon() -> bool:
	return upgrade_item(str(equipment.weapon.id))

func enchant_item(id: String) -> bool:
	var item := owned_item(id)
	if phase!="camp" or item.is_empty():
		return fail("请在营地选择自己的装备。")
	var cost := enchant_cost(item)
	if gold<cost:
		return fail("附魔需要%d金币。" % cost)
	var pool: Array = catalog.affixes.duplicate(true)
	if item.has("enchantment"):
		pool = pool.filter(func(a): return a.key!=item.enchantment.key)
	var affix: Dictionary = pool[rng.randi_range(0,pool.size()-1)]
	gold -= cost
	item.enchantment = {"key":affix.key,"label":affix.label,"value":rng.randi_range(int(affix.min),int(affix.max))}
	item.enchant_count = int(item.get("enchant_count",0))+1
	player = build_player()
	note("附魔完成：%s获得%s +%d。" % [item.name,affix.label,item.enchantment.value])
	return true

func shop_price(base_index: int) -> int:
	return ceili(float(catalog.bases[base_index].value)*1.25)

func shop_buy(base_index: int) -> bool:
	if phase!="camp" or base_index<0 or base_index>=catalog.bases.size():
		return fail("当前不能购买。")
	var cost := shop_price(base_index)
	if gold<cost:
		return fail("金币不足。")
	if Inventory.first_fit(stash,catalog.bases[base_index],STASH).x<0:
		return fail("仓库空间不足，请先整理。")
	var item := make_item(base_index,0)
	Inventory.add(stash,item,STASH)
	gold -= cost
	note("购入%s，花费%d金币，已放入仓库。" % [item.name,cost])
	return true

func draw_equipment() -> bool:
	if phase!="camp" or gold<DRAW_COST:
		return fail("遗物抽奖需要%d金币，仅营地开放。" % DRAW_COST)
	for base in catalog.bases:
		if Inventory.first_fit(stash,base,STASH).x<0:
			return fail("请先为可能获得的装备腾出仓库空间（最大2×3）。")
	var roll := rng.randi_range(1,100)
	var rarity := 0 if roll<=55 else (1 if roll<=85 else (2 if roll<=98 else 3))
	if draw_pity>=9:
		rarity = maxi(2,rarity)
	var item := make_item(-1,rarity)
	Inventory.add(stash,item,STASH)
	gold -= DRAW_COST
	draw_pity = 0 if rarity>=2 else draw_pity+1
	draw_history.push_front({"name":item.name,"rarity":rarity,"id":item.id})
	draw_history = draw_history.slice(0,8)
	note("遗物抽奖：%s · %s，已入库。" % [catalog.rarities[rarity].name,item.name])
	return true

func toggle_lock(id: String) -> bool:
	var item := owned_item(id)
	if phase!="camp" or item.is_empty():
		return false
	item.locked = not item.get("locked",false)
	return true

func tidy_stash() -> bool:
	if phase!="camp":
		return false
	return Inventory.sort_items(stash,STASH) or fail("自动整理无法放下所有物品，原位置保留。")

func deposit_all() -> bool:
	if phase!="camp":
		return false
	return Inventory.transfer_all(bag,stash,STASH) or fail("仓库空间不足，未转移任何物品。")

func can_extract() -> bool:
	if dungeon.is_empty():
		return phase in ["loot","event","exit"]
	return phase in ["explore","loot"] and (map_position==0 or map_position==Dungeon.COUNT-1 and dungeon[map_position].cleared)

func reveal_tile(index: int) -> bool:
	if phase!="explore" or not Dungeon.accessible(dungeon,index):
		return fail("只能探索与已清理区域相邻的迷雾。")
	var tile: Dictionary = dungeon[index]
	if tile.flag:
		return fail("此处已标记危险，请先取消标记。")
	map_position = index
	if tile.seen and tile.cleared:
		return true
	tile.seen = true
	tile.scouted = true
	match str(tile.kind):
		"combat","elite","boss":
			encounter_kind = tile.kind
			room = 0 if tile.kind=="combat" else 1
			start_encounter()
		"chest":
			tile.cleared = true
			pending_loot = [make_item(),make_item(-1,1)]
			card_rewards.clear()
			run_gold += 25
			after_loot = "explore"
			phase = "loot"
			note("发现遗物宝箱，获得25待结算金币。")
		"event":
			event_used = false
			phase = "event"
		"trap":
			tile.cleared = true
			var roll := rng.randi_range(1,100)
			if Rules.event_check(int(player.perception),roll)=="失败":
				player.hp = maxi(1,int(player.hp)-12)
				note("触发陷阱：感知检定%d，失去12生命（最低1）。" % roll)
			else:
				note("感知检定%d，成功避开陷阱。" % roll)
		"rest":
			tile.cleared = true
			player.hp = mini(int(player.max_hp),int(player.hp)+35)
			note("找到营火，恢复最多35生命。")
		"empty":
			Dungeon.reveal_empty(dungeon,index)
		_:
			tile.cleared = true
	return true

func flag_tile(index: int) -> bool:
	if phase!="explore" or index<0 or index>=dungeon.size() or dungeon[index].seen:
		return false
	dungeon[index].flag = not dungeon[index].flag
	return true

func scout_tile(index: int) -> bool:
	if phase!="explore" or scouts<=0 or not Dungeon.accessible(dungeon,index):
		return fail("侦察次数不足，或目标不在相邻迷雾。")
	if dungeon[index].seen or dungeon[index].scouted:
		return fail("这个格子已经看清。")
	scouts -= 1
	dungeon[index].scouted = true
	note("侦察发现：%s。进入后才会触发。" % Dungeon.TITLES[dungeon[index].kind])
	return true

func snapshot() -> Dictionary:
	return encode({"version":SAVE_VERSION,"dungeon":dungeon,"map_position":map_position,"encounter_kind":encounter_kind,"scouts":scouts,"draw_pity":draw_pity,"draw_history":draw_history,"run_deck":run_deck,"draw_pile":draw_pile,"hand":hand,"discard_pile":discard_pile,"exhaust_pile":exhaust_pile,"card_rewards":card_rewards,"energy":energy,"momentum":momentum,"retain_block":retain_block,"rng_seed":str(rng.seed),"rng_state":str(rng.state),"phase":phase,"room":room,"gold":gold,"run_gold":run_gold,"serial":serial,"bag":bag,"stash":stash,"equipment":equipment,"pending_loot":pending_loot,"after_loot":after_loot,"player":player,"enemies":enemies,"walls":walls,"turn_queue":turn_queue,"round_no":round_no,"player_turn":player_turn,"ap":ap,"movement":movement,"potions":potions,"log_lines":log_lines,"last_result":last_result,"event_used":event_used})

func encode(value: Variant) -> Variant:
	if value is Vector2i:
		return {"__cell":[value.x,value.y]}
	if value is Array:
		var result: Array = []
		for element in value:
			result.append(encode(element))
		return result
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = encode(value[key])
		return result
	return value

func decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("__cell"):
			return Vector2i(int(value.__cell[0]),int(value.__cell[1]))
		var result := {}
		for key in value:
			result[key] = decode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for element in value:
			result.append(decode(element))
		return result
	return value

func restore(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("version",0)) not in [1,2,SAVE_VERSION]:
		return false
	var legacy := int(data.version) == 1
	var converted: Dictionary = data.duplicate(true)
	if int(data.version)<3:
		converted.dungeon = []
		converted.map_position = 0
		converted.encounter_kind = "combat" if int(data.room)==0 else "boss"
		converted.scouts = 2
		converted.draw_pity = 0
		converted.draw_history = []
	if legacy:
		for key in ["run_deck","draw_pile","hand","discard_pile","exhaust_pile","card_rewards"]:
			converted[key] = []
		converted.energy = 3
		converted.momentum = 0.0
		converted.retain_block = false
	for key in snapshot():
		if not converted.has(key):
			return false
	if not converted.bag is Array or not converted.stash is Array or not converted.equipment is Dictionary or not converted.pending_loot is Array:
		return false
	if not Inventory.validate(converted.bag,BAG) or not Inventory.validate(converted.stash,STASH):
		return false
	if converted.phase not in ["camp","combat","loot","event","exit","explore"] or int(converted.gold) < 0:
		return false
	for key in ["run_deck","draw_pile","hand","discard_pile","exhaust_pile","card_rewards"]:
		if not converted[key] is Array:
			return false
		for id in converted[key]:
			if not id is String or not Cards.DATA.has(id):
				return false
	if converted.hand.size()>10 or int(converted.energy)<0:
		return false
	if not legacy and converted.phase == "combat":
		var all_cards: Array = converted.draw_pile + converted.hand + converted.discard_pile + converted.exhaust_pile
		var deck_copy: Array = converted.run_deck.duplicate()
		all_cards.sort()
		deck_copy.sort()
		if all_cards != deck_copy or deck_copy.is_empty():
			return false
	if not converted.dungeon is Array or (not converted.dungeon.is_empty() and not Dungeon.validate(converted.dungeon,int(converted.map_position))):
		return false
	if converted.phase=="explore" and converted.dungeon.is_empty():
		return false
	if int(converted.draw_pity)<0 or int(converted.draw_pity)>9 or int(converted.scouts)<0 or not converted.draw_history is Array:
		return false
	var ids := {}
	for item in converted.bag + converted.stash + converted.equipment.values() + converted.pending_loot:
		if not item is Dictionary or not item.has("id") or ids.has(str(item.id)):
			return false
		ids[str(item.id)] = true
	var decoded: Dictionary = decode(converted)
	for key in snapshot():
		if key not in ["version","rng_seed","rng_state"]:
			set(key,decoded[key])
	rng.seed = str(converted.rng_seed).to_int()
	rng.state = str(converted.rng_state).to_int()
	if legacy:
		run_deck = starting_deck()
		player.block = 0
		if phase == "combat":
			start_encounter()
		note("存档已升级为卡牌版：装备、仓库、金币和生命保留；进行中的旧战斗从当前房间重新开始。")
	return true

func save_game() -> bool:
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(snapshot()))
	file.close()
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path,save_path+".bak")
	return DirAccess.rename_absolute(temporary,save_path) == OK

func load_game() -> bool:
	for candidate in [save_path,save_path+".bak"]:
		if FileAccess.file_exists(candidate):
			var parser := JSON.new()
			if parser.parse(FileAccess.get_file_as_string(candidate)) != OK:
				continue
			if restore(parser.data):
				if int(parser.data.version)<SAVE_VERSION:
					var backup := save_path+".v"+str(int(parser.data.version))
					if not FileAccess.file_exists(backup):
						DirAccess.copy_absolute(candidate,backup)
				if candidate.ends_with(".bak"):
					note("主存档不可用，已恢复最近的备份。")
				return true
	return false
