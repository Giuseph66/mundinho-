extends Node3D

## Instancia um NPC possuível (npc.tscn) por personagem descoberto na pasta
## playable_characters. Cada um vaga pelo mundo e pode ser assumido com F, igual
## aos outros NPCs. O menu de seleção (character_select.gd) usa `possess()` pra
## fazer o jogador começar já dentro do personagem escolhido.

const NPC_SCENE := preload("res://scenes/npc.tscn")
const CharacterLibrary := preload("res://scripts/character_library.gd")
const GROUP_NAME := "character_spawner"

## Onde os personagens nascem. Espalhados em arco perto do player pra ficarem
## visíveis no início. Y alto porque o terreno é gerado por ruído — eles caem
## pela gravidade até o chão.
@export var spawn_center: Vector3 = Vector3(24, 13, 14)
@export_range(1.0, 8.0, 0.5) var spawn_spacing: float = 2.5

var characters_by_name: Dictionary = {}

func _ready() -> void:
	add_to_group(GROUP_NAME)
	var characters := CharacterLibrary.discover()
	for i in characters.size():
		var entry: Dictionary = characters[i]
		_spawn_character(entry["name"], entry["path"], i, characters.size())

func _spawn_character(character_name: String, model_path: String, index: int, total: int) -> void:
	var model: PackedScene = load(model_path)
	if model == null:
		push_warning("character_spawner: falha ao carregar " + model_path)
		return
	var npc := NPC_SCENE.instantiate()
	npc.model_scene = model
	npc.name = "Playable_" + character_name
	# espalha em linha centrada no spawn_center
	var offset := (float(index) - float(total - 1) * 0.5) * spawn_spacing
	npc.position = spawn_center + Vector3(offset, 0.0, 0.0)
	add_child(npc)
	characters_by_name[character_name] = npc

## Nomes na ordem de descoberta (= ordem do menu).
func get_character_names() -> Array:
	var names := characters_by_name.keys()
	names.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	return names

## Faz o jogador assumir o personagem escolhido. Chamado pelo menu.
func possess(character_name: String) -> void:
	if not characters_by_name.has(character_name):
		return
	var npc: CharacterBody3D = characters_by_name[character_name]
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("possess_specific"):
		player.possess_specific(npc)
