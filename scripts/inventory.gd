extends RefCounted
## Placement is transactional: an invalid move never removes the original item.

static func fits(items: Array, item: Dictionary, point: Vector2i, bounds: Vector2i, ignore_id: String = "") -> bool:
	var footprint := Vector2i(int(item.w), int(item.h))
	if point.x < 0 or point.y < 0 or point.x + footprint.x > bounds.x or point.y + footprint.y > bounds.y:
		return false
	var rect := Rect2i(point, footprint)
	for other in items:
		if str(other.id) == ignore_id:
			continue
		if rect.intersects(Rect2i(Vector2i(int(other.x), int(other.y)), Vector2i(int(other.w), int(other.h)))):
			return false
	return true

static func first_fit(items: Array, item: Dictionary, bounds: Vector2i) -> Vector2i:
	for y in range(bounds.y):
		for x in range(bounds.x):
			if fits(items, item, Vector2i(x,y), bounds):
				return Vector2i(x,y)
	return Vector2i(-1,-1)

static func add(items: Array, item: Dictionary, bounds: Vector2i) -> bool:
	for existing in items:
		if str(existing.id) == str(item.id):
			return false
	var point := first_fit(items,item,bounds)
	if point.x < 0:
		return false
	item.x = point.x
	item.y = point.y
	items.append(item)
	return true

static func move(items: Array, id: String, point: Vector2i, bounds: Vector2i, rotate: bool = false) -> bool:
	for item in items:
		if str(item.id) != id:
			continue
		var candidate: Dictionary = item.duplicate(true)
		if rotate:
			candidate.w = item.h
			candidate.h = item.w
		if not fits(items,candidate,point,bounds,id):
			return false
		item.x = point.x
		item.y = point.y
		item.w = candidate.w
		item.h = candidate.h
		return true
	return false

static func transfer(source: Array, target: Array, id: String, bounds: Vector2i) -> bool:
	for index in range(source.size()):
		if str(source[index].id) == id:
			if add(target, source[index], bounds):
				source.remove_at(index)
				return true
	return false

static func validate(items: Array, bounds: Vector2i) -> bool:
	var ids := {}
	for item in items:
		if not item is Dictionary:
			return false
		for key in ["id","w","h","x","y","name","type","value","affixes","rarity","level"]:
			if not item.has(key):
				return false
		if ids.has(str(item.id)) or int(item.w) < 1 or int(item.h) < 1:
			return false
		ids[str(item.id)] = true
		if not fits(items,item,Vector2i(int(item.x),int(item.y)),bounds,str(item.id)):
			return false
	return true

static func sort_items(items: Array,bounds: Vector2i) -> bool:
	var ordered := items.duplicate(true)
	ordered.sort_custom(func(a,b): return int(a.w)*int(a.h)>int(b.w)*int(b.h))
	var placed: Array = []
	for item in ordered:
		if not add(placed,item,bounds):
			var old_width: int = item.w
			item.w = item.h
			item.h = old_width
			if not add(placed,item,bounds):
				return false
	items.clear()
	items.append_array(placed)
	return true

static func transfer_all(source: Array,target: Array,bounds: Vector2i) -> bool:
	var staged := target.duplicate(true)
	for item in source:
		if not add(staged,item.duplicate(true),bounds):
			return false
	target.clear()
	target.append_array(staged)
	source.clear()
	return true
