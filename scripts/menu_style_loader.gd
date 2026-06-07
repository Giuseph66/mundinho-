@tool
extends Node3D

@export_enum("Escuro verde", "Madeira", "Claro limpo") var menu_style: int = 0:
	set(value):
		menu_style = value
		_update_menu()

const MENU_SCENES: Array[String] = [
	"res://scenes/item_menu.tscn",
	"res://scenes/item_menu_style_wood.tscn",
	"res://scenes/item_menu_style_clean.tscn",
]

func _ready() -> void:
	_update_menu()

func _update_menu() -> void:
	if not is_inside_tree():
		return

	var old_menu := get_node_or_null("ItemMenu")
	if old_menu != null:
		old_menu.queue_free()

	var scene := load(MENU_SCENES[menu_style]) as PackedScene
	if scene == null:
		return

	var menu := scene.instantiate()
	menu.name = "ItemMenu"
	add_child(menu)
	menu.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else null
