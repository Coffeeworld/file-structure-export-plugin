@tool
extends EditorPlugin

var menu_button: MenuButton
const MENU_ITEM_NAME = "Save Folder Structure"
const PLUGIN_NAME = "Folder Structure Export"
const SETTING_PATH = "folder_structure_export/exclusions/"
const DEFAULT_EXCLUSIONS = ["addons", ".godot", ".git", "build"]

func _enter_tree() -> void:
	# Add menu item under Project menu
	menu_button = MenuButton.new()
	menu_button.text = PLUGIN_NAME
	var popup = menu_button.get_popup()
	popup.add_item(MENU_ITEM_NAME)
	popup.id_pressed.connect(_on_menu_item_pressed)
	
	# Add the menu button to the editor's toolbar
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, menu_button)
	
	# Add project settings
	_add_project_settings()

func _exit_tree() -> void:
	# Clean up UI elements
	if menu_button:
		remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, menu_button)
		menu_button.queue_free()
		menu_button = null
	
	# Clean up settings
	_remove_project_settings()

func _add_project_settings() -> void:
	# Add settings for excluded directories
	if not ProjectSettings.has_setting(SETTING_PATH + "excluded_dirs"):
		ProjectSettings.set_setting(SETTING_PATH + "excluded_dirs", DEFAULT_EXCLUSIONS)
	
	var property_info = {
		"name": SETTING_PATH + "excluded_dirs",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": "String",
		"usage": PROPERTY_USAGE_DEFAULT
	}
	ProjectSettings.add_property_info(property_info)
	
	# Add setting for custom output path
	if not ProjectSettings.has_setting(SETTING_PATH + "output_path"):
		ProjectSettings.set_setting(SETTING_PATH + "output_path", "folder_structure.txt")
	
	property_info = {
		"name": SETTING_PATH + "output_path",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.txt",
		"usage": PROPERTY_USAGE_DEFAULT
	}
	ProjectSettings.add_property_info(property_info)
	
	ProjectSettings.save()

func _remove_project_settings() -> void:
	# Only remove the settings if they exist
	var settings_to_remove = [
		SETTING_PATH + "excluded_dirs",
		SETTING_PATH + "output_path"
	]
	
	for setting in settings_to_remove:
		if ProjectSettings.has_setting(setting):
			ProjectSettings.set_setting(setting, null)
	
	# Save changes
	ProjectSettings.save()

func _on_menu_item_pressed(id: int) -> void:
	if id == 0:  # First menu item
		save_folder_structure()

func get_excluded_dirs() -> Array:
	return ProjectSettings.get_setting(SETTING_PATH + "excluded_dirs", DEFAULT_EXCLUSIONS)

func get_output_path() -> String:
	return ProjectSettings.get_setting(SETTING_PATH + "output_path", "folder_structure.txt")

func save_folder_structure() -> void:
	var project_path = ProjectSettings.globalize_path("res://")
	var output = []
	var base_dir_name = project_path.get_file().strip_edges()
	if base_dir_name.is_empty():
		base_dir_name = project_path.get_base_dir().get_file()
	output.append(base_dir_name)
	
	var excluded = get_excluded_dirs()
	_scan_directory("res://", output, 0, excluded)
	
	# Save to file
	var save_path = project_path.path_join(get_output_path())
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(output))
		print("Folder structure saved to: ", save_path)
	else:
		push_error("Failed to save folder structure")

func _scan_directory(path: String, output: Array, indent: int, excluded: Array) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_error("Failed to access path: ", path)
		return
	
	# Get all files and directories first to handle last items correctly
	var items = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not file_name.begins_with("."):  # Skip hidden files/folders
			if dir.current_is_dir():
				if not excluded.has(file_name):  # Skip excluded directories
					items.append({"name": file_name, "is_dir": true})
			else:
				if not file_name.ends_with(".import"):  # Skip .import files
					items.append({"name": file_name, "is_dir": false})
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Sort items (directories first, then files)
	items.sort_custom(func(a, b): 
		if a.is_dir and not b.is_dir:
			return true
		if not a.is_dir and b.is_dir:
			return false
		return a.name < b.name
	)
	
	# Process items
	for i in range(items.size()):
		var item = items[i]
		var is_last = i == items.size() - 1
		var prefix = "│   ".repeat(indent) + ("└───" if is_last else "├───")
		
		output.append(prefix + item.name)
		
		if item.is_dir:
			_scan_directory(path.path_join(item.name), output, indent + 1, excluded)
