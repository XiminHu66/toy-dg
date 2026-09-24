extends RefCounted
const WIDTH := 7
const HEIGHT := 5
const COUNT := WIDTH*HEIGHT
const HAZARDS := ["combat","elite","boss","trap"]
const KINDS := ["empty","entrance","combat","elite","boss","trap","chest","event","rest"]
const TITLES := {"empty":"通道","entrance":"入口","combat":"战斗","elite":"精英","boss":"核心","trap":"陷阱","chest":"宝箱","event":"事件","rest":"营火"}

static func neighbors(index: int,diagonal: bool = false) -> Array:
	var result: Array = []
	var point := Vector2i(index%WIDTH,index/WIDTH)
	for dy in range(-1,2):
		for dx in range(-1,2):
			if dx==0 and dy==0 or not diagonal and absi(dx)+absi(dy)!=1:
				continue
			var next := point+Vector2i(dx,dy)
			if next.x>=0 and next.x<WIDTH and next.y>=0 and next.y<HEIGHT:
				result.append(next.y*WIDTH+next.x)
	return result

static func generate(rng: RandomNumberGenerator) -> Array:
	var cells: Array = []
	var slots: Array = []
	for i in range(COUNT):
		cells.append({"kind":"empty","seen":false,"cleared":false,"flag":false,"scouted":false})
		if i not in [0,1,7,8,COUNT-1]:
			slots.append(i)
	for i in range(slots.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var value: Variant = slots[i]
		slots[i] = slots[j]
		slots[j] = value
	for kind in ["combat","combat","combat","elite","trap","trap","trap","chest","chest","chest","event","event","rest"]:
		cells[slots.pop_back()].kind = kind
	cells[0] = {"kind":"entrance","seen":true,"cleared":true,"flag":false,"scouted":true}
	cells[COUNT-1].kind = "boss"
	return cells

static func danger(cells: Array,index: int) -> int:
	var count := 0
	for next in neighbors(index,true):
		if cells[next].kind in HAZARDS:
			count += 1
	return count

static func accessible(cells: Array,index: int) -> bool:
	if index<0 or index>=cells.size():
		return false
	if cells[index].seen and cells[index].cleared:
		return true
	for next in neighbors(index):
		if cells[next].seen and cells[next].cleared:
			return true
	return false

static func reveal_empty(cells: Array,index: int) -> void:
	var queue: Array = [index]
	var visited := {}
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if visited.has(current) or cells[current].kind != "empty" or cells[current].flag:
			continue
		visited[current] = true
		cells[current].seen = true
		cells[current].cleared = true
		if danger(cells,current)==0:
			queue.append_array(neighbors(current))

static func validate(cells: Variant,position: int) -> bool:
	if not cells is Array or cells.size()!=COUNT or position<0 or position>=COUNT:
		return false
	for cell in cells:
		if not cell is Dictionary or cell.get("kind","") not in KINDS:
			return false
		for key in ["seen","cleared","flag","scouted"]:
			if not cell.get(key) is bool:
				return false
		if cell.cleared and not cell.seen:
			return false
	return cells[0].kind=="entrance" and cells[0].seen and cells[0].cleared and cells[COUNT-1].kind=="boss" and cells[position].seen
