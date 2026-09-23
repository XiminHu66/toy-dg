extends SceneTree
const Store = preload("res://launcher/update_store.gd")
var checks := 0
var failures := 0
var test_root: String

func check(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: "+message)

func _initialize() -> void:
	test_root = "user://updater-tests-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(test_root)
	check(Store.newer("0.1.10","0.1.9"),"numeric version order")
	check(not Store.newer("0.1.9","0.1.10"),"no version downgrade")
	for invalid in ["../evil","1.2.3/evil","1.2","v1.2.3","01.2.3",null,3]:
		check(not Store.valid_version(invalid),"reject invalid version")
	var store := Store.new(test_root.path_join("installed"))
	var one := make_package("0.1.1")
	check(store.validate_manifest(one.manifest),"valid manifest")
	check(store.install(one.path,one.manifest),"initial package installed")
	check(store.index.current=="0.1.1" and store.has_installed(),"current points to verified game")
	var corrupt := make_package("0.1.2")
	corrupt.manifest.windows.sha256 = "0".repeat(64)
	check(not store.install(corrupt.path,corrupt.manifest),"bad archive hash rejected")
	check(store.index.current=="0.1.1" and store.has_installed(),"bad update preserves installed version")
	var bad_file := make_package("0.1.2")
	bad_file.manifest.windows.files[0].sha256 = "0".repeat(64)
	check(not store.install(bad_file.path,bad_file.manifest),"bad extracted hash rejected")
	check(store.index.current=="0.1.1","bad extraction cannot activate")
	var traversal := make_package("0.1.2","../escape.exe")
	check(not store.install(traversal.path,traversal.manifest),"archive path traversal rejected")
	check(not FileAccess.file_exists(test_root.path_join("escape.exe")),"nothing extracted outside staging")
	var invalid: Dictionary = one.manifest.duplicate(true)
	invalid.windows.url = "https://example.com/evil.zip"
	check(not store.validate_manifest(invalid),"foreign source rejected")
	invalid = one.manifest.duplicate(true)
	invalid.minimum_launcher = 99
	check(not store.validate_manifest(invalid),"future launcher requirement respected")
	invalid = one.manifest.duplicate(true)
	invalid.windows.files[0].name = "C:\\evil.exe"
	check(not store.validate_manifest(invalid),"absolute filename rejected")
	invalid = one.manifest.duplicate(true)
	invalid.windows.files[0].size_bytes = Store.MAX_EXPANDED+1
	check(not store.validate_manifest(invalid),"oversized file rejected")
	var two := make_package("0.1.2")
	check(store.install(two.path,two.manifest),"second version installed")
	check(store.index.previous=="0.1.1" and store.index.current=="0.1.2","previous retained")
	check(FileAccess.file_exists(store.version_dir("0.1.1").path_join("toy-dg.exe")),"old executable not overwritten")
	check(not store.install(one.path,one.manifest),"older package cannot replace current")
	var reloaded := Store.new(store.root)
	check(reloaded.index.current=="0.1.2" and reloaded.has_installed(),"offline load of installed game")
	check(reloaded.rollback(),"manual rollback")
	check(reloaded.index.current=="0.1.1" and reloaded.has_installed(),"rollback points to old game")
	check(not reloaded.should_update(two.manifest),"rolled-back version not reinstalled")
	var three := make_package("0.1.3")
	check(reloaded.should_update(three.manifest) and reloaded.install(three.path,three.manifest),"later version allowed after rollback")
	var file := FileAccess.open(reloaded.root.path_join("installed.json"),FileAccess.WRITE)
	file.store_string("truncated")
	file.close()
	var recovered := Store.new(store.root)
	check(recovered.index.current=="0.1.1" and recovered.has_installed(),"broken index recovers backup")
	# Save data lives outside the updater-owned tree and must survive all operations.
	var sentinel := FileAccess.open(test_root.path_join("profile.json"),FileAccess.WRITE)
	sentinel.store_string("save-data")
	sentinel.close()
	var four := make_package("0.1.4")
	check(recovered.install(four.path,four.manifest),"update after index recovery")
	check(FileAccess.get_file_as_string(test_root.path_join("profile.json"))=="save-data","save file untouched")
	remove_test_tree(test_root)
	print("UPDATER_TEST_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func hash_bytes(bytes: PackedByteArray) -> String:
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(bytes)
	return hasher.finish().hex_encode()

func make_package(version: String,unsafe_name: String = "") -> Dictionary:
	var path := test_root.path_join("package-"+version+".zip")
	var zip := ZIPPacker.new()
	zip.open(path)
	var records: Array = []
	for name_value in Store.ALLOWED_FILES:
		var bytes: PackedByteArray = (name_value+" version "+version).to_utf8_buffer()
		zip.start_file(unsafe_name if name_value=="toy-dg.exe" and not unsafe_name.is_empty() else name_value)
		zip.write_file(bytes)
		zip.close_file()
		records.append({"name":name_value,"sha256":hash_bytes(bytes),"size_bytes":bytes.size()})
	zip.close()
	var file := FileAccess.open(path,FileAccess.READ)
	var size_value := file.get_length()
	file.close()
	var manifest := {"schema":1,"version":version,"minimum_launcher":1,"windows":{"url":Store.RELEASE_PREFIX+"v"+version+"/toy-dg-windows.zip","entrypoint":"toy-dg.exe","size_bytes":size_value,"sha256":FileAccess.get_sha256(path),"files":records}}
	return {"path":path,"manifest":manifest}

func remove_test_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for name_value in directory.get_files():
		DirAccess.remove_absolute(path.path_join(name_value))
	for name_value in directory.get_directories():
		remove_test_tree(path.path_join(name_value))
	DirAccess.remove_absolute(path)
