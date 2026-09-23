extends RefCounted
const Rules = preload("res://scripts/rules.gd")
const Inventory = preload("res://scripts/inventory.gd")
const BOARD := Vector2i(8,6)
const BAG := Vector2i(6,5)
const STASH := Vector2i(10,8)
const DIRECTIONS := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
const SAVE_VERSION := 1

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
	note("欢迎回来，拾遗者。仓库中的指环可解锁影步；整备后进入封印矿井。")

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
	var stats := {"id":"player","name":"凛 · 拾遗者","hp":90,"max_hp":90,"attack":12,"defense":6,"agility":12,"speed":12,"movement":4,"crit":20,"crit_damage":150,"penetration":0,"toughness":14,"perception":60,"will":55,"bleed":0,"shadowstep":0,"position":Vector2i(1,3),"facing":Vector2i.RIGHT,"bleeds":[],"broken":false,"guard":false,"guarded_round":-1,"step_used":false}
	for item in equipment.values():
		for key in ["attack","defense","hp"]:
			if item.has(key):
				stats[key] += int(item[key]) + int(item.level)*2
		for affix in item.affixes:
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
	start_encounter()
	return true

func start_encounter() -> void:
	phase = "combat"
	player.position = Vector2i(1,3)
	player.facing = Vector2i.RIGHT
	player.bleeds = []
	player.broken = false
	player.toughness = player.max_toughness
	walls = [Vector2i(3,1),Vector2i(3,2),Vector2i(5,4)]
	enemies.clear()
	if room == 0:
		enemies.append(enemy("watcher","铜壳守卫",Vector2i(5,2),46,11,8,8))
		enemies.append(enemy("crawler","裂隙猎犬",Vector2i(6,4),32,9,3,14))
	else:
		enemies.append(enemy("warden","遗迹监守者",Vector2i(6,2),85,15,18,9))
		enemies.append(enemy("drone","符文浮游机",Vector2i(5,4-1),28,10,4,11))
	last_result = {}
	round_no = 0
	note("进入%s。敌人会在行动时追踪你；墙体阻挡移动与攻击。" % ("矿井入口" if room == 0 else "封印核心"))
	begin_round()
	advance_turns()

func enemy(id: String, name_value: String, pos: Vector2i, health: int, attack: int, defense: int, speed: int) -> Dictionary:
	return {"id":id,"name":name_value,"position":pos,"facing":Vector2i.LEFT,"hp":health,"max_hp":health,"attack":attack,"defense":defense,"speed":speed,"agility":8,"crit":10,"crit_damage":150,"penetration":0,"movement":2,"toughness":10,"max_toughness":10,"bleeds":[],"broken":false,"guard":false,"guarded_round":-1,"bleed":0}

func begin_round() -> void:
	round_no += 1
	var units: Array = [player]
	for target in enemies:
		if target.hp > 0:
			units.append(target)
	units.sort_custom(func(a,b): return a.speed > b.speed if a.speed != b.speed else str(a.id) < str(b.id))
	turn_queue.clear()
	for unit in units:
		turn_queue.append(unit.id)

func advance_turns() -> void:
	player_turn = false
	while phase == "combat":
		if turn_queue.is_empty():
			begin_round()
		var next_id: String = turn_queue.pop_front()
		if next_id == "player":
			if player.broken:
				player.broken = false
				player.toughness = player.max_toughness
				note("你从失衡中恢复，本回合行动点减半。")
				ap = 1
			else:
				ap = 2
			movement = int(player.movement)
			player.guard = false
			player.step_used = false
			player_turn = true
			return
		var target := unit_by_id(next_id)
		if target.is_empty() or target.hp <= 0:
			continue
		enemy_turn(target)
		tick_bleed(target)
		check_battle()

func unit_by_id(id: String) -> Dictionary:
	if id == "player":
		return player
	for target in enemies:
		if str(target.id) == id:
			return target
	return {}

func inside(point: Vector2i) -> bool:
	return point.x >= 0 and point.y >= 0 and point.x < BOARD.x and point.y < BOARD.y

func occupied(point: Vector2i, ignore_id: String = "") -> bool:
	if not inside(point) or walls.has(point):
		return true
	if player.id != ignore_id and player.position == point and player.hp > 0:
		return true
	for target in enemies:
		if target.id != ignore_id and target.hp > 0 and target.position == point:
			return true
	return false

func path(start: Vector2i, goal: Vector2i, ignore_id: String = "player") -> Array:
	if not inside(goal) or occupied(goal,ignore_id):
		return []
	var frontier: Array = [start]
	var came := {start:start}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == goal:
			var route: Array = []
			while current != start:
				route.push_front(current)
				current = came[current]
			return route
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if came.has(next) or occupied(next,ignore_id):
				continue
			came[next] = current
			frontier.append(next)
	return []

func distance(a: Vector2i,b: Vector2i) -> int:
	return absi(a.x-b.x) + absi(a.y-b.y)

func face(from: Vector2i,to: Vector2i) -> Vector2i:
	var delta := to-from
	if absi(delta.x) >= absi(delta.y):
		return Vector2i(signi(delta.x),0)
	return Vector2i(0,signi(delta.y))

func move_player(point: Vector2i) -> bool:
	if phase != "combat" or not player_turn:
		return fail("现在无法移动。")
	var route := path(player.position,point)
	if route.is_empty() or route.size() > movement:
		return fail("路径不可达或移动力不足。")
	player.facing = face(player.position,point)
	player.position = point
	movement -= route.size()
	last_result = {"kind":"move","path":route}
	return true

func shadowstep(point: Vector2i) -> bool:
	if phase != "combat" or not player_turn or ap < 1 or player.shadowstep < 1 or player.step_used:
		return fail("影步需要装备对应词条，消耗1 AP，每回合限一次。")
	if occupied(point) or distance(player.position,point) > 3:
		return fail("请选择3格内的空位。")
	player.facing = face(player.position,point)
	player.position = point
	player.step_used = true
	ap -= 1
	note("影步：跨越障碍，抵达新的位置。")
	return true

func strike(target_id: String, skill: String) -> bool:
	if phase != "combat" or not player_turn or ap < 2:
		return fail("攻击需要2 AP。")
	var target := unit_by_id(target_id)
	if target.is_empty() or target.id == "player" or target.hp <= 0:
		return fail("请选择存活敌人。")
	if skill not in ["slash","rupture","dash"]:
		return fail("未知技能。")
	var dist := distance(player.position,target.position)
	if skill == "dash":
		if dist < 2 or dist > 4 or (player.position.x != target.position.x and player.position.y != target.position.y):
			return fail("突进需要直线2–4格内目标。")
		var direction: Vector2i = face(player.position,target.position)
		var cursor: Vector2i = player.position + direction
		while cursor != target.position:
			if occupied(cursor):
				return fail("突进路线被阻挡。")
			cursor += direction
		player.position = target.position - direction
	elif dist != 1:
		return fail("请先移动到目标相邻格。")
	var backstab := Rules.behind(player.position,target.position,target.facing)
	var coefficient := 0.75 if skill == "rupture" else (1.1 if skill == "dash" else 1.0)
	ap -= 2
	player.facing = face(player.position,target.position)
	var result := Rules.resolve(player,target,rng,coefficient,backstab)
	apply_attack(player,target,result)
	if result.hit:
		if skill == "rupture" or player.bleed > 0:
			if target.bleeds.size() < 3:
				target.bleeds.append({"damage":3 + int(player.bleed),"turns":2})
		var stagger_damage := 6 if skill == "dash" else 3
		if int(target.guarded_round) < round_no:
			target.toughness = maxi(0,int(target.toughness)-stagger_damage)
			if target.toughness == 0:
				target.broken = true
				target.guarded_round = round_no + 1
				note("%s 失衡：下一次攻击伤害降低。" % target.name)
	check_battle()
	return true

func apply_attack(attacker: Dictionary,target: Dictionary,result: Dictionary) -> void:
	result.kind = "attack"
	result.target = target.position
	result.actor = attacker.position
	last_result = result
	if not result.hit:
		note("%s → %s：d100=%d / %d，未命中。" % [attacker.name,target.name,result.roll,result.chance])
		return
	if target.guard:
		result.damage = maxi(1,int(result.damage * 0.5))
	target.hp = maxi(0,int(target.hp)-int(result.damage))
	note("%s → %s：d100=%d / %d，2d6=%d+%d，%s%d伤害。" % [attacker.name,target.name,result.roll,result.chance,result.dice[0],result.dice[1],"暴击！" if result.crit else "",result.damage])

func guard() -> bool:
	if phase != "combat" or not player_turn or ap < 1:
		return fail("防御需要1 AP。")
	if player.guard:
		return fail("已处于防御姿态。")
	ap -= 1
	player.guard = true
	note("举盾：下次自己行动前直接伤害减少50%。")
	return true

func end_turn() -> bool:
	if phase != "combat" or not player_turn:
		return false
	player_turn = false
	tick_bleed(player)
	check_battle()
	if phase == "combat":
		advance_turns()
	return true

func heal() -> bool:
	if phase != "combat" or not player_turn or ap < 1 or potions < 1:
		return fail("疗伤药需要1 AP，每次探索补给2瓶。")
	if player.hp >= player.max_hp:
		return fail("生命已满。")
	potions -= 1
	ap -= 1
	player.hp = mini(int(player.max_hp),int(player.hp)+30)
	note("使用疗伤药，恢复最多30生命。")
	return true

func enemy_turn(target: Dictionary) -> void:
	var best_route: Array = []
	for direction in DIRECTIONS:
		var goal: Vector2i = player.position + direction
		if goal == target.position:
			best_route = []
			break
		var route := path(target.position,goal,target.id)
		if not route.is_empty() and (best_route.is_empty() or route.size() < best_route.size()):
			best_route = route
	if not best_route.is_empty():
		var destination: Vector2i = best_route[mini(int(target.movement),best_route.size())-1]
		target.facing = face(target.position,destination)
		target.position = destination
	if distance(target.position,player.position) == 1:
		target.facing = face(target.position,player.position)
		var coefficient := 0.5 if target.broken else 1.0
		apply_attack(target,player,Rules.resolve(target,player,rng,coefficient))
	if target.broken:
		target.broken = false
		target.toughness = target.max_toughness

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
	after_loot = "event" if room == 0 else "exit"
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
		pending_loot.clear()
		phase = after_loot
		if phase == "next_battle":
			room = 1
			start_encounter()
		return true
	return false

func resolve_event(choice: String) -> bool:
	if phase != "event" or event_used:
		return false
	if choice not in ["perception","will","leave"]:
		return false
	event_used = true
	if choice == "leave":
		room = 1
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
	after_loot = "next_battle"
	phase = "loot"
	return true

func extract() -> bool:
	if phase not in ["loot","event","exit"]:
		return fail("战斗中无法直接撤离。")
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
			gold += int(source[i].value)
			note("出售 %s，获得%d金币。" % [source[i].name,source[i].value])
			source.remove_at(i)
			return true
	return false

func upgrade_weapon() -> bool:
	if phase != "camp" or not equipment.has("weapon"):
		return false
	var item: Dictionary = equipment.weapon
	var cost := 60 + int(item.level)*40
	if item.level >= 3:
		return fail("原型强化上限为+3。")
	if gold < cost:
		return fail("强化需要%d金币。" % cost)
	gold -= cost
	item.level += 1
	player = build_player()
	note("强化成功：%s +%d，花费%d金币。" % [item.name,item.level,cost])
	return true

func snapshot() -> Dictionary:
	return encode({"version":SAVE_VERSION,"rng_seed":str(rng.seed),"rng_state":str(rng.state),"phase":phase,"room":room,"gold":gold,"run_gold":run_gold,"serial":serial,"bag":bag,"stash":stash,"equipment":equipment,"pending_loot":pending_loot,"after_loot":after_loot,"player":player,"enemies":enemies,"walls":walls,"turn_queue":turn_queue,"round_no":round_no,"player_turn":player_turn,"ap":ap,"movement":movement,"potions":potions,"log_lines":log_lines,"last_result":last_result,"event_used":event_used})

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
	if not data is Dictionary or int(data.get("version",0)) != SAVE_VERSION:
		return false
	for key in snapshot():
		if not data.has(key):
			return false
	if not data.bag is Array or not data.stash is Array or not data.equipment is Dictionary or not data.pending_loot is Array:
		return false
	if not Inventory.validate(data.bag,BAG) or not Inventory.validate(data.stash,STASH):
		return false
	if data.phase not in ["camp","combat","loot","event","exit"] or int(data.gold) < 0:
		return false
	var ids := {}
	for item in data.bag + data.stash + data.equipment.values() + data.pending_loot:
		if not item is Dictionary or not item.has("id") or ids.has(str(item.id)):
			return false
		ids[str(item.id)] = true
	var decoded: Dictionary = decode(data)
	for key in decoded:
		if key not in ["version","rng_seed","rng_state"]:
			set(key,decoded[key])
	rng.seed = str(data.rng_seed).to_int()
	rng.state = str(data.rng_state).to_int()
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
				if candidate.ends_with(".bak"):
					note("主存档不可用，已恢复最近的备份。")
				return true
	return false
