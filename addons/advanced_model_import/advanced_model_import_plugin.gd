@tool
@static_unload
class_name AdvancedModelImportPlugin
extends EditorPlugin

const PLUGIN_DIR_PATH: String = "res://addons/advanced_model_import/"
const TITLE: String = "Advanced Model Import"
#  ==================== MODELS REIMPORT OPTION KEYS ====================
const KEY_MESH_EXTRACT: StringName = &"mesh_extract"
const KEY_MESH_EXTRACT_NAME: StringName = &"mesh_extract_name"
const KEY_MESH_EXTRACT_MIRROR: StringName = &"mesh_extract_mirror"
const KEY_MESH_EXTRACT_SOURCE_PATH: StringName = &"mesh_extract_source_path"
const KEY_MESH_EXTRACT_PATH: StringName = &"mesh_extract_path"
const KEY_MATERIAL_EXTRACT: StringName = &"material_extract"
const KEY_MATERIAL_EXTRACT_PATH: StringName = &"material_extract_path"
const KEY_MATERIAL_REPLACE: StringName = &"material_replace"
const KEY_MATERIAL_REPLACE_LIST: StringName = &"material_replace_list"

const _DOCK_SCENE_PATH: String = PLUGIN_DIR_PATH + "bulk_importer/bulk_importer_dock.tscn"

enum MeshName {
	USE_MESH_NAME,
	USE_NODE_NAME,
}

static var _materials_to_set: Dictionary[String, String] = { }

var _import_dock: BulkImporterDock = null


static func _static_init() -> void:
	_materials_to_set = { }


func _enable_plugin() -> void:
	pass


func _disable_plugin() -> void:
	pass


func _enter_tree() -> void:
	var packed_scene: PackedScene = ResourceLoader.load(_DOCK_SCENE_PATH, "PackedScene")

	if !is_instance_valid(packed_scene):
		return

	var node: Node = packed_scene.instantiate()

	if node is not BulkImporterDock:
		return

	_import_dock = node as BulkImporterDock

	if is_instance_valid(_import_dock):
		add_dock(_import_dock)


func _exit_tree() -> void:
	if is_instance_valid(_import_dock):
		remove_dock(_import_dock)

	_import_dock = null


func _get_plugin_name() -> String:
	return TITLE

#region Utilities

static func get_enum_hint_string(enum_dict: Dictionary) -> String:
	var hint: String = ""

	for value: int in enum_dict.values() as Array[int]:
		if !hint.is_empty():
			hint += ","

		hint += "%s:%d" % [str(enum_dict.keys()[value]).capitalize(), value]

	return hint


static func apply_reimport(file_paths: PackedStringArray, options: Dictionary) -> void:
	_materials_to_set.clear()
	var import_error: Error = Error.OK

	print("%s - Applying new import settings." % [TITLE])

	if options.get(KEY_MATERIAL_EXTRACT, false) as bool:
		import_error = _extract_materials(file_paths, options)

		if import_error == Error.OK:
			print(" === Materials extracted === ")
		else:
			printerr("Failed to extract materials: %s" % [error_string(import_error).capitalize()])

	var has_mat_user_list: bool = options.get(KEY_MATERIAL_REPLACE, false) as bool

	if has_mat_user_list || !_materials_to_set.is_empty():
		import_error = _replace_materials(file_paths, options, has_mat_user_list)

		if has_mat_user_list && import_error == Error.OK:
			print(" === Materials replaced === ")
		else:
			printerr("Failed to replace materials: %s" % [error_string(import_error).capitalize()])

	if options.get(KEY_MESH_EXTRACT, false) as bool:
		import_error = _extract_meshes(file_paths, options)

		if import_error == Error.OK:
			print(" === Meshes extracted === ")
		else:
			printerr("Failed to extract meshes: %s" % [error_string(import_error).capitalize()])

	EditorInterface.get_resource_filesystem().scan_sources()


static func _get_mesh_instances_from_scene(file_path: String) -> Array[MeshInstance3D]:
	var packed_scene: PackedScene = ResourceLoader.load(
		file_path,
		"",
		ResourceLoader.CacheMode.CACHE_MODE_IGNORE_DEEP,
	)

	if !is_instance_valid(packed_scene):
		return []

	var node_instance: Node = packed_scene.instantiate()

	if !is_instance_valid(node_instance):
		return []

	var mesh_list: Array[MeshInstance3D] = []

	for node: Node in node_instance.find_children("*", "MeshInstance3D", true, true):
		if node is MeshInstance3D:
			mesh_list.append(node as MeshInstance3D)

	return mesh_list


static func _open_import_file(import_file_path: String) -> ConfigFile:
	var import_file: ConfigFile = ConfigFile.new()
	var error: Error = import_file.load(import_file_path)

	if error != Error.OK:
		return null

	return import_file

#endregion

#region Extract Materials

static func _extract_materials(file_paths: PackedStringArray, options: Dictionary) -> Error:
	var material_path: String = str(options.get(KEY_MATERIAL_EXTRACT_PATH, ""))

	if material_path.is_empty():
		return Error.ERR_INVALID_PARAMETER

	if !material_path.ends_with("/"):
		material_path += "/"

	for file: String in file_paths:
		var error: Error = _extract_materials_from_file(file, material_path)

		if error == Error.OK:
			continue

		if error == Error.ERR_INVALID_PARAMETER:
			return error

		if error == Error.ERR_FILE_CANT_OPEN:
			printerr("Can't open model file \"%s\"." % [file])

	return Error.OK


static func _extract_materials_from_file(file_path: String, destination: String) -> Error:
	if file_path.is_empty() || destination.is_empty():
		return Error.ERR_INVALID_PARAMETER

	var mesh_instance_list: Array[MeshInstance3D] = _get_mesh_instances_from_scene(file_path)

	if mesh_instance_list.size() == 0:
		return Error.ERR_FILE_CANT_OPEN

	for mesh_instance: MeshInstance3D in mesh_instance_list:
		var mesh: Mesh = mesh_instance.mesh

		if !is_instance_valid(mesh):
			continue

		for idx: int in range(mesh.get_surface_count()):
			var material: Material = mesh.surface_get_material(idx).duplicate(true) as Material

			if !is_instance_valid(material):
				continue

			if !_materials_to_set.has(material.resource_name):
				var material_path: String = "%s%s.tres" % [destination, material.resource_name]

				if !FileAccess.file_exists(material_path):
					ResourceSaver.save(material, material_path)

				_materials_to_set[material.resource_name] = material_path

	return Error.OK

#endregion

#region Replace Materials

static func _replace_materials(
		file_paths: PackedStringArray,
		options: Dictionary,
		has_user_list: bool,
) -> Error:
	if has_user_list:
		var user_material_list: Dictionary = options.get(
			KEY_MATERIAL_REPLACE_LIST,
			{ },
		) as Dictionary

		if user_material_list.is_empty():
			printerr("No replacement materials provided.")
		else:
			for material_name: String in user_material_list.keys() as Array[String]:
				_materials_to_set[material_name] = str(user_material_list[material_name])

	if _materials_to_set.is_empty():
		return Error.ERR_SKIP

	for file: String in file_paths:
		var error: Error = _replace_materials_from_file(file)

		if error == Error.OK:
			continue

		if error == Error.ERR_INVALID_PARAMETER:
			return error

		if error == Error.ERR_FILE_CANT_READ:
			printerr("Can't open import file of \"%s\"." % [file])

		if error == Error.ERR_FILE_CANT_WRITE:
			printerr("Can't write import file of \"%s\"." % [file])

	return Error.OK


static func _replace_materials_from_file(file_path: String) -> Error:
	if file_path.is_empty() || _materials_to_set.is_empty():
		return Error.ERR_INVALID_PARAMETER

	var import_path: String = "%s.import" % [file_path]
	var import_file: ConfigFile = _open_import_file(import_path)

	if !is_instance_valid(import_file):
		return Error.ERR_FILE_CANT_READ

	var subresources: Dictionary = import_file.get_value(
		"params",
		"_subresources",
		{ },
	) as Dictionary

	if !subresources.has("materials"):
		subresources["materials"] = { }

	for material_name: String in _materials_to_set.keys() as Array[String]:
		subresources["materials"][material_name] = {
			"use_external/enabled": true,
			"use_external/path": _materials_to_set[material_name],
		}

	import_file.set_value("params", "_subresources", subresources)
	var error: Error = import_file.save(import_path)

	if error != Error.OK:
		return Error.ERR_FILE_CANT_WRITE

	return Error.OK

#endregion

#region Extract Meshes

static func _extract_meshes(file_paths: PackedStringArray, options: Dictionary) -> Error:
	var mesh_path: String = str(options.get(KEY_MESH_EXTRACT_PATH, ""))

	if mesh_path.is_empty():
		return Error.ERR_INVALID_PARAMETER

	if !mesh_path.ends_with("/"):
		mesh_path += "/"

	var mesh_name: MeshName = options.get(
		KEY_MESH_EXTRACT_NAME,
		MeshName.USE_MESH_NAME,
	) as MeshName
	var mirror: bool = options.get(KEY_MESH_EXTRACT_MIRROR, false) as bool
	var mesh_source_path: String = str(options.get(KEY_MESH_EXTRACT_SOURCE_PATH, ""))

	if mirror:
		if mesh_source_path.is_empty():
			mirror = false
		elif mesh_source_path.ends_with("/"):
			mesh_source_path = mesh_source_path.trim_suffix("/")

	for file: String in file_paths:
		var destination = mesh_path

		if mirror:
			destination += file.get_base_dir().replace(mesh_source_path, "")
			if !destination.ends_with("/"):
				destination += "/"

		var error: Error = _extract_meshes_from_file(file, destination, mesh_name)

		if error == Error.OK:
			continue

		if error == Error.ERR_INVALID_PARAMETER:
			return error

		if error == Error.ERR_FILE_CANT_OPEN:
			printerr("Can't open model file \"%s\"." % [file])

		if error == Error.ERR_SKIP:
			printerr("No mesh to extract in \"%s\", skipping it." % [file])

		if error == Error.ERR_FILE_CANT_READ:
			printerr("Can't open import file of \"%s\"." % [file])

		if error == Error.ERR_FILE_CANT_WRITE:
			printerr("Can't write import file of \"%s\"." % [file])

	return Error.OK


static func _extract_meshes_from_file(
		file_path: String,
		destination: String,
		mesh_name: MeshName,
) -> Error:
	if file_path.is_empty() || destination.is_empty():
		return Error.ERR_INVALID_PARAMETER

	var mesh_instance_list: Array[MeshInstance3D] = _get_mesh_instances_from_scene(file_path)

	if mesh_instance_list.size() == 0:
		return Error.ERR_FILE_CANT_OPEN

	var mesh_list: Dictionary[String, String] = { }

	for mesh_instance: MeshInstance3D in mesh_instance_list:
		var mesh: Mesh = mesh_instance.mesh

		if !is_instance_valid(mesh):
			continue

		mesh_list[mesh.resource_name] = "%s%s.res" % [
			destination,
			mesh_instance.name if mesh_name == MeshName.USE_NODE_NAME else mesh.resource_name,
		]

	return _set_mesh_on_file(file_path, mesh_list)


static func _set_mesh_on_file(file_path: String, mesh_list: Dictionary[String, String]) -> Error:
	if file_path.is_empty():
		return Error.ERR_INVALID_PARAMETER

	if mesh_list.size() == 0:
		return Error.ERR_SKIP

	var import_path: String = "%s.import" % [file_path]
	var import_file: ConfigFile = _open_import_file(import_path)

	if !is_instance_valid(import_file):
		return Error.ERR_FILE_CANT_READ

	var subresources: Dictionary = import_file.get_value(
		"params",
		"_subresources",
		{ },
	) as Dictionary

	if !subresources.has("meshes"):
		subresources["meshes"] = { }

	for mesh_name: String in mesh_list.keys() as Array[String]:
		subresources["meshes"][mesh_name] = {
			"save_to_file/enabled": true,
			"save_to_file/path": mesh_list[mesh_name],
		}

	import_file.set_value("params", "_subresources", subresources)
	var error: Error = import_file.save(import_path)

	if error != Error.OK:
		return Error.ERR_FILE_CANT_WRITE

	return Error.OK

#endregion
