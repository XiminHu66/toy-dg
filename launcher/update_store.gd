extends RefCounted
## Installation logic is independent of UI/network for deterministic testing.
const LAUNCHER_VERSION := 1
const MANIFEST_URL := "https://github.com/XiminHu66/toy-dg/releases/latest/download/update.json"
const RELEASE_PREFIX := "https://github.com/XiminHu66/toy-dg/releases/download/"
const ALLOWED_FILES := ["toy-dg.exe","THIRD_PARTY_NOTICES.md","OFL.txt"]
const MAX_PACKAGE := 300 * 1024 * 1024
const MAX_EXPANDED := 512 * 1024 * 1024
var root := "user://updates"
var error := ""
var index := {"current":"","previous":"","skipped":[]}

func _init(directory: String = "user://updates") -> void:
	root = directory
	DirAccess.make_dir_recursive_absolute(root)
	load_index()

static func valid_version(value: Variant) -> bool:
	if not value is String:
		return false
	var expression := RegEx.new()
	expression.compile("^(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})$")
	return expression.search(value) != null

static func valid_hash(value: Variant) -> bool:
	if not value is String:
		return false
	var expression := RegEx.new()
	expression.compile("^[0-9a-f]{64}$")
	return expression.search(value) != null

static func newer(a: String,b: String) -> bool:
	if not valid_version(a):
		return false
	if b.is_empty():
		return true
	if not valid_version(b):
		return false
	var first := a.split(".")
	var second := b.split(".")
	for i in range(3):
		if int(first[i]) != int(second[i]):
			return int(first[i]) > int(second[i])
	return false

func fail(message: String) -> bool:
	error = message
	return false

func validate_manifest(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema") != 1:
		return fail("更新清单格式不受支持。")
	if not valid_version(data.get("version")):
		return fail("版本号格式无效。")
	if not data.get("minimum_launcher") is float and not data.get("minimum_launcher") is int:
		return fail("缺少启动器兼容信息。")
	if data.minimum_launcher > LAUNCHER_VERSION:
		return fail("此版本需要新版启动器；当前已安装的游戏仍可运行。")
	if not data.get("windows") is Dictionary:
		return fail("更新清单缺少 Windows 包。")
	var package: Dictionary = data.windows
	var expected: String = RELEASE_PREFIX + "v" + data.version + "/toy-dg-windows.zip"
	if package.get("url","") != expected or package.get("entrypoint","") != "toy-dg.exe":
		return fail("更新来源或启动文件无效。")
	if not valid_hash(package.get("sha256")) or not package.get("size_bytes") is float and not package.get("size_bytes") is int:
		return fail("更新校验信息无效。")
	if package.size_bytes <= 0 or package.size_bytes > MAX_PACKAGE:
		return fail("更新包大小超出允许范围。")
	if not package.get("files") is Array or package.files.size() != ALLOWED_FILES.size():
		return fail("更新包文件清单不完整。")
	var seen := {}
	var total := 0
	for record in package.files:
		if not record is Dictionary or not record.get("name") in ALLOWED_FILES or seen.has(record.name):
			return fail("文件名非法或重复。")
		if not valid_hash(record.get("sha256")) or not record.get("size_bytes") is float and not record.get("size_bytes") is int:
			return fail("文件校验信息无效。")
		if record.size_bytes <= 0 or record.size_bytes > MAX_EXPANDED:
			return fail("文件大小超出允许范围。")
		seen[record.name] = true
		total += int(record.size_bytes)
	if total > MAX_EXPANDED:
		return fail("解压后文件大小超出允许范围。")
	return true

func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data

func load_index() -> void:
	for candidate in [root.path_join("installed.json"),root.path_join("installed.json.bak")]:
		var data: Variant = read_json(candidate)
		if not data is Dictionary or not data.get("current") is String or not data.get("previous") is String or not data.get("skipped") is Array:
			continue
		if not data.current.is_empty() and not valid_version(data.current):
			continue
		if not data.previous.is_empty() and not valid_version(data.previous):
			continue
		index = data
		return

func write_json(path: String,data: Dictionary,backup: bool = false) -> bool:
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		return fail("无法写入更新目录。")
	file.store_string(JSON.stringify(data))
	file.close()
	if backup and FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path,path+".bak") != OK:
			return fail("无法备份当前安装状态。")
	if DirAccess.rename_absolute(path+".tmp",path) != OK:
		return fail("无法保存安装状态；原版本保持不变。")
	return true

func version_dir(version: String) -> String:
	if not valid_version(version):
		return ""
	return root.path_join("versions").path_join(version)

func executable(version: String) -> String:
	var folder := version_dir(version)
	if folder.is_empty():
		return ""
	var manifest: Variant = read_json(folder.path_join("manifest.json"))
	if not validate_manifest(manifest) or manifest.version != version:
		return ""
	for record in manifest.windows.files:
		var path := folder.path_join(record.name)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != record.sha256:
			return ""
	return ProjectSettings.globalize_path(folder.path_join("toy-dg.exe"))

func has_installed() -> bool:
	return not executable(str(index.current)).is_empty()

func should_update(manifest: Dictionary) -> bool:
	return not index.skipped.has(manifest.version) and (newer(manifest.version,str(index.current)) or manifest.version == index.current and not has_installed())

func clear_staging(folder: String) -> void:
	# Only delete files owned by this updater; never recursively remove arbitrary data.
	for name_value in ALLOWED_FILES + ["manifest.json","manifest.json.tmp"]:
		if FileAccess.file_exists(folder.path_join(name_value)):
			DirAccess.remove_absolute(folder.path_join(name_value))
	DirAccess.remove_absolute(folder)

func install(zip_path: String,manifest: Variant) -> bool:
	if not validate_manifest(manifest):
		return false
	if not should_update(manifest):
		return fail("该版本无需安装，或已被回退跳过。")
	var package: Dictionary = manifest.windows
	var file := FileAccess.open(zip_path,FileAccess.READ)
	if file == null:
		return fail("下载文件不存在。")
	var actual_size := file.get_length()
	file.close()
	if actual_size != int(package.size_bytes) or FileAccess.get_sha256(zip_path) != package.sha256:
		return fail("下载校验失败，保留已安装版本。")
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		return fail("无法读取更新包。")
	var names := reader.get_files()
	if names.size() != ALLOWED_FILES.size():
		reader.close()
		return fail("压缩包包含意外文件。")
	var seen := {}
	for name_value in names:
		if name_value not in ALLOWED_FILES or seen.has(name_value):
			reader.close()
			return fail("拒绝非法压缩路径或重复文件。")
		seen[name_value] = true
	var folder := version_dir(manifest.version)
	var staging := folder + ".staging"
	clear_staging(staging)
	if DirAccess.make_dir_recursive_absolute(staging) != OK:
		reader.close()
		return fail("无法创建安装目录。")
	for record in package.files:
		var bytes := reader.read_file(record.name)
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(bytes)
		if bytes.size() != int(record.size_bytes) or context.finish().hex_encode() != record.sha256:
			reader.close()
			clear_staging(staging)
			return fail("解压文件校验失败；原版本保持不变。")
		var output := FileAccess.open(staging.path_join(record.name),FileAccess.WRITE)
		if output == null:
			reader.close()
			clear_staging(staging)
			return fail("写入更新文件失败；原版本保持不变。")
		output.store_buffer(bytes)
		output.close()
	reader.close()
	if not write_json(staging.path_join("manifest.json"),manifest):
		clear_staging(staging)
		return false
	if DirAccess.dir_exists_absolute(folder):
		if executable(manifest.version).is_empty():
			# Never overwrite a possibly running executable, even if it is damaged.
			clear_staging(staging)
			return fail("该版本目录已损坏。可回退旧版或等待下一版本。")
		clear_staging(staging)
	elif DirAccess.rename_absolute(staging,folder) != OK:
		clear_staging(staging)
		return fail("无法完成安装；原版本保持不变。")
	var next_index := index.duplicate(true)
	next_index.previous = index.current
	next_index.current = manifest.version
	if not write_json(root.path_join("installed.json"),next_index,true):
		return false
	index = next_index
	error = ""
	return true

func rollback() -> bool:
	var previous: String = index.previous
	if executable(previous).is_empty():
		return fail("没有可用的上一版本。")
	var next_index := index.duplicate(true)
	next_index.current = previous
	next_index.previous = ""
	if not next_index.skipped.has(index.current):
		next_index.skipped.append(index.current)
	if not write_json(root.path_join("installed.json"),next_index,true):
		return false
	index = next_index
	error = ""
	return true
