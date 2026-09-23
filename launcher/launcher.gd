extends Control
const Store = preload("res://launcher/update_store.gd")
var store := Store.new()
var request: HTTPRequest
var status: Label
var version_label: Label
var progress: ProgressBar
var play_button: Button
var check_button: Button
var rollback_button: Button
var busy := false
var stage := ""
var manifest: Dictionary = {}
var integration_test := false
var online_success := false

func _ready() -> void:
	integration_test = "--launcher-update-test" in OS.get_cmdline_user_args()
	if integration_test:
		store = Store.new("user://ci-live-update")
	get_window().content_scale_size = Vector2i(760,440)
	if not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_size(Vector2i(760,440))
		DisplayServer.window_set_title("地城拾遗 · 启动器")
	var theme_value := Theme.new()
	theme_value.default_font = load("res://assets/fonts/DungeonSans.ttf")
	theme_value.default_font_size = 17
	theme = theme_value
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+edge,32)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	margin.add_child(column)
	var title := Label.new()
	title.text = "地城拾遗"
	title.add_theme_font_size_override("font_size",32)
	column.add_child(title)
	version_label = Label.new()
	column.add_child(version_label)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 86
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(status)
	progress = ProgressBar.new()
	progress.show_percentage = true
	column.add_child(progress)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	column.add_child(row)
	play_button = make_button(row,"开始游戏",start_game)
	check_button = make_button(row,"检查更新",check_updates)
	rollback_button = make_button(row,"回退上一版本",rollback)
	var hint := Label.new()
	hint.text = "自动更新不会移动或删除存档。断网时可以启动已安装版本。"
	hint.add_theme_font_size_override("font_size",14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	request = HTTPRequest.new()
	request.max_redirects = 10
	request.request_completed.connect(completed)
	add_child(request)
	if "--launcher-smoke" in OS.get_cmdline_user_args():
		set_status("启动器界面检查完成。",false)
		await get_tree().process_frame
		print("LAUNCHER_SMOKE_OK")
		get_tree().quit()
		return
	check_updates()

func make_button(parent: Node,text_value: String,action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(165,44)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func set_status(message: String,is_busy: bool) -> void:
	status.text = message
	busy = is_busy
	version_label.text = "已安装版本：" + (str(store.index.current) if not str(store.index.current).is_empty() else "首次安装")
	play_button.disabled = is_busy or not store.has_installed()
	check_button.disabled = is_busy
	rollback_button.disabled = is_busy or str(store.index.previous).is_empty()
	if integration_test and not is_busy:
		call_deferred("finish_integration_test")

func check_updates() -> void:
	if busy:
		return
	set_status("正在联网检查游戏版本…",true)
	progress.value = 0
	stage = "manifest"
	request.download_file = ""
	request.body_size_limit = 65536
	request.timeout = 15
	var code := request.request(Store.MANIFEST_URL,["Accept: application/json","User-Agent: toy-dg-launcher/1"])
	if code != OK:
		set_status("无法发起检查，可启动已安装版本或稍后重试。",false)

func completed(result: int,response_code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		set_status("连接或下载失败（HTTP %d）。已有版本保持不变，可离线启动。" % response_code,false)
		return
	if stage == "manifest":
		var parser := JSON.new()
		if parser.parse(body.get_string_from_utf8()) != OK or not store.validate_manifest(parser.data):
			set_status(store.error if not store.error.is_empty() else "更新清单读取失败。",false)
			return
		manifest = parser.data
		if not store.should_update(manifest):
			online_success = true
			set_status("当前没有需要安装的更新。可以开始游戏。",false)
			progress.value = 100
			return
		set_status("发现版本 %s，正在自动下载（%.1f MB）…" % [manifest.version,manifest.windows.size_bytes/1048576.0],true)
		stage = "package"
		request.download_file = store.root.path_join("download.zip")
		request.body_size_limit = int(manifest.windows.size_bytes)
		request.timeout = 300
		# HTTPRequest is ready for reuse after its completion signal returns.
		call_deferred("download_package")
	elif stage == "package":
		set_status("下载完成，正在校验并安装…",true)
		await get_tree().process_frame
		var success := store.install(store.root.path_join("download.zip"),manifest)
		online_success = success
		DirAccess.remove_absolute(store.root.path_join("download.zip"))
		progress.value = 100 if success else 0
		set_status("已更新到 %s。可以开始游戏。" % manifest.version if success else store.error,false)

func download_package() -> void:
	var code := request.request(manifest.windows.url,["User-Agent: toy-dg-launcher/1"])
	if code != OK:
		set_status("下载无法开始。已有版本保持不变。",false)

func _process(_delta: float) -> void:
	if busy and stage == "package" and not manifest.is_empty():
		progress.value = minf(99.0,100.0*request.get_downloaded_bytes()/maxf(1.0,manifest.windows.size_bytes))

func start_game() -> void:
	if busy:
		return
	var executable := store.executable(str(store.index.current))
	if executable.is_empty():
		set_status("已安装文件校验失败，请回退上一版本或检查更新。",false)
		return
	if OS.get_name() != "Windows":
		set_status("这个启动器发布包目前用于 Windows。",false)
		return
	var process_id := OS.create_process(executable,[])
	if process_id <= 0:
		set_status("游戏未能启动，可回退上一版本后重试。",false)
		return
	get_tree().quit()

func rollback() -> void:
	if store.rollback():
		set_status("已回退至 %s，并跳过有问题的更新版本。" % store.index.current,false)
	else:
		set_status(store.error,false)

func finish_integration_test() -> void:
	if not online_success or not store.has_installed() or store.index.current != manifest.get("version",""):
		printerr("LIVE_UPDATE_FAILED: "+status.text)
		get_tree().quit(1)
		return
	if OS.get_name() != "Windows":
		printerr("Live executable test requires Windows")
		get_tree().quit(1)
		return
	var output: Array = []
	var code := OS.execute(store.executable(str(store.index.current)),["--headless","--","--smoke"],output,true)
	var text_value := "\n".join(output)
	print(text_value)
	if code != 0 or not text_value.contains("UI_SMOKE_OK") or text_value.contains("SCRIPT ERROR:"):
		printerr("DOWNLOADED_GAME_FAILED")
		get_tree().quit(1)
		return
	print("LIVE_UPDATE_OK: "+str(store.index.current))
	get_tree().quit()
