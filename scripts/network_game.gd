extends Node

const NPC_SCENE := preload("res://scenes/npc.tscn")
const CharacterLibrary := preload("res://scripts/character_library.gd")

const NETWORK_SERVER := 1
const NETWORK_CLIENT_LOCAL := 2
const NETWORK_CLIENT_REMOTE := 3
const REMOTE_SNAPSHOT_ALPHA := 0.45
const BOT_ID_START := -1000
const SIMULATED_PLAYER_ID_START := 10000

@export_range(0, 32, 1) var bot_count: int = 0
@export var bot_character_names: PackedStringArray = PackedStringArray()
@export_range(0.2, 8.0, 0.1) var bot_input_change_interval: float = 1.4
@export_range(0.3, 12.0, 0.1) var player_walk_speed: float = 2.8
@export_range(1.0, 5.0, 0.1) var player_run_multiplier: float = 2.2
@export_range(0.1, 1.0, 0.1) var player_crouch_multiplier: float = 0.6

const SPAWN_POINTS: Array[Vector3] = [
	Vector3(24, 12, 18),
	Vector3(28, 12, 18),
	Vector3(20, 12, 18),
	Vector3(24, 12, 22),
	Vector3(24, 12, 14),
	Vector3(30, 12, 22),
	Vector3(18, 12, 14),
	Vector3(30, 12, 14),
]

var active := false
var players: Dictionary = {}
var player_characters: Dictionary = {}
var latest_inputs: Dictionary = {}
var bot_inputs: Dictionary = {}
var bot_timers: Dictionary = {}
var simulated_peer_ids: Dictionary = {}
var human_peer_ids: Dictionary = {}
var ai_peer_ids: Dictionary = {}
var next_simulated_peer_id: int = SIMULATED_PLAYER_ID_START
var simulated_player_count: int = 0
var input_seq: int = 0
var tick: int = 0
var character_entries: Array = []
var characters_by_name: Dictionary = {}
var select_layer: CanvasLayer = null
var life_label: Label = null

func _ready() -> void:
	add_to_group("network_game")
	active = MultiplayerManager.is_multiplayer_active()
	set_physics_process(false)
	if not active:
		return

	call_deferred("_start_multiplayer")

func _start_multiplayer() -> void:
	_discover_characters()
	_strip_singleplayer_nodes()
	_connect_manager_signals()
	if not MultiplayerManager.is_headless_server():
		_build_life_hud()
	if not MultiplayerManager.is_headless_server():
		_open_character_select()
	if multiplayer.is_server():
		_spawn_bots()
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not active:
		return
	if multiplayer.is_server():
		_server_tick(delta)
	else:
		_client_tick()
	_update_life_hud()

func _unhandled_input(event: InputEvent) -> void:
	if not active or not multiplayer.is_server() or MultiplayerManager.is_headless_server():
		return
	if select_layer != null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		simulate_player_join()

func _server_tick(delta: float) -> void:
	if players.has(1) and not MultiplayerManager.is_headless_server():
		input_seq += 1
		var local_input: Dictionary = players[1].call("collect_network_input", input_seq)
		latest_inputs[1] = _sanitize_input(local_input)

	for peer_id in players.keys():
		var player: Node = players[peer_id]
		if not is_instance_valid(player):
			continue
		var input: Dictionary = _empty_input()
		if ai_peer_ids.has(peer_id):
			input = _update_ai_input(int(peer_id), delta)
		elif human_peer_ids.has(peer_id) and latest_inputs.has(peer_id):
			input = latest_inputs[peer_id]
		player.call("apply_network_input", input, delta)
		if human_peer_ids.has(peer_id) and bool(input.get("jump", false)) and latest_inputs.has(peer_id):
			latest_inputs[peer_id]["jump"] = false
		if human_peer_ids.has(peer_id) and bool(input.get("attack", false)) and latest_inputs.has(peer_id):
			latest_inputs[peer_id]["attack"] = false
		if human_peer_ids.has(peer_id) and bool(input.get("dance", false)) and latest_inputs.has(peer_id):
			latest_inputs[peer_id]["dance"] = false

	tick += 1
	MultiplayerManager.broadcast_snapshot(_build_snapshot())

func _client_tick() -> void:
	var peer_id: int = multiplayer.get_unique_id()
	if not players.has(peer_id):
		return
	input_seq += 1
	var input: Dictionary = players[peer_id].call("collect_network_input", input_seq)
	MultiplayerManager.send_input(input)

func _connect_manager_signals() -> void:
	if not MultiplayerManager.input_received.is_connected(_on_input_received):
		MultiplayerManager.input_received.connect(_on_input_received)
	if not MultiplayerManager.character_choice_received.is_connected(_on_character_choice_received):
		MultiplayerManager.character_choice_received.connect(_on_character_choice_received)
	if not MultiplayerManager.weapon_choice_received.is_connected(_on_weapon_choice_received):
		MultiplayerManager.weapon_choice_received.connect(_on_weapon_choice_received)
	if not MultiplayerManager.snapshot_received.is_connected(_on_snapshot_received):
		MultiplayerManager.snapshot_received.connect(_on_snapshot_received)
	if not MultiplayerManager.peer_left.is_connected(_on_peer_left):
		MultiplayerManager.peer_left.connect(_on_peer_left)
	if not MultiplayerManager.server_closed.is_connected(_on_server_closed):
		MultiplayerManager.server_closed.connect(_on_server_closed)

func _strip_singleplayer_nodes() -> void:
	var main := get_parent()
	for node_name in ["Player", "NPCs", "CharacterSpawner", "CharacterSelect", "SpiderEnemy", "SpiderEnemy2"]:
		var node := main.get_node_or_null(NodePath(node_name))
		if node != null:
			node.queue_free()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()

func _discover_characters() -> void:
	character_entries = CharacterLibrary.discover()
	characters_by_name.clear()
	for entry in character_entries:
		var character_name: String = String(entry.get("name", ""))
		if character_name != "":
			characters_by_name[character_name] = String(entry.get("path", ""))

func _open_character_select() -> void:
	if character_entries.is_empty():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	select_layer = CanvasLayer.new()
	select_layer.layer = 150
	add_child(select_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	select_layer.add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.08, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(360, 0)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Escolha seu personagem"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	for entry in character_entries:
		var character_name: String = String(entry.get("name", ""))
		var button := Button.new()
		button.text = character_name
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(_on_local_character_chosen.bind(character_name))
		vbox.add_child(button)

	for child in vbox.get_children():
		if child is Button:
			(child as Button).grab_focus()
			break

func _build_life_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 140
	add_child(layer)
	life_label = Label.new()
	life_label.position = Vector2(18, 18)
	life_label.add_theme_font_size_override("font_size", 22)
	life_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.18, 1.0))
	life_label.text = "Vida: --"
	layer.add_child(life_label)

func _update_life_hud() -> void:
	if life_label == null:
		return
	var character: Node = get_local_character()
	if character == null:
		life_label.text = "Vida: --"
		return
	life_label.text = "Vida: %d" % int(character.get("hp"))

func _on_local_character_chosen(character_name: String) -> void:
	if select_layer != null:
		select_layer.queue_free()
		select_layer = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	MultiplayerManager.send_character_choice(character_name)

func equip_local_weapon(weapon_id: String) -> void:
	MultiplayerManager.send_weapon_choice(weapon_id)

func get_local_character() -> Node:
	var peer_id: int = 1 if multiplayer.is_server() else multiplayer.get_unique_id()
	return players.get(peer_id, null)

func _on_character_choice_received(peer_id: int, character_name: String) -> void:
	if not multiplayer.is_server():
		return
	if not characters_by_name.has(character_name):
		character_name = _default_character_name()
	if character_name == "":
		return
	_spawn_server_player(peer_id, character_name)
	human_peer_ids[peer_id] = true

func _on_weapon_choice_received(peer_id: int, weapon_id: String) -> void:
	if not multiplayer.is_server() or not human_peer_ids.has(peer_id) or not players.has(peer_id):
		return
	var player: Node = players[peer_id]
	if player.has_method("equip_weapon"):
		player.call("equip_weapon", weapon_id)

func _spawn_server_player(peer_id: int, character_name: String) -> void:
	_remove_player(peer_id)
	var local_view := peer_id == 1 and not MultiplayerManager.is_headless_server()
	var player := _spawn_player(peer_id, character_name, NETWORK_SERVER, local_view)
	if player == null:
		return
	player.global_position = _spawn_position(peer_id)
	player_characters[peer_id] = character_name
	latest_inputs[peer_id] = _empty_input()

func _spawn_client_player(peer_id: int, character_name: String) -> void:
	if players.has(peer_id) and player_characters.get(peer_id, "") == character_name:
		return
	_remove_player(peer_id)
	var local_view := peer_id == multiplayer.get_unique_id()
	var mode: int = NETWORK_CLIENT_LOCAL if local_view else NETWORK_CLIENT_REMOTE
	var player := _spawn_player(peer_id, character_name, mode, local_view)
	if player == null:
		return
	player_characters[peer_id] = character_name

func _spawn_player(peer_id: int, character_name: String, mode: int, local_view: bool) -> Node3D:
	var player: Node3D = NPC_SCENE.instantiate() as Node3D
	if player == null:
		push_warning("network_game: falha ao instanciar NPC.")
		return null
	player.name = "NetCharacter_%s" % str(peer_id).replace("-", "bot_")
	var model_path: String = String(characters_by_name.get(character_name, ""))
	if model_path != "":
		player.set("model_scene", load(model_path))
	player.set("walk_speed", player_walk_speed)
	player.set("run_multiplier", player_run_multiplier)
	player.set("crouch_multiplier", player_crouch_multiplier)
	if not player.has_method("configure_network"):
		push_warning("network_game: npc.tscn sem script npc_walker.gd carregado.")
		player.queue_free()
		return null
	player.call("configure_network", peer_id, mode, local_view, MultiplayerManager.is_headless_server())
	get_parent().add_child(player)
	players[peer_id] = player
	return player

func _remove_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	var player: Node = players[peer_id]
	players.erase(peer_id)
	player_characters.erase(peer_id)
	latest_inputs.erase(peer_id)
	bot_inputs.erase(peer_id)
	bot_timers.erase(peer_id)
	simulated_peer_ids.erase(peer_id)
	human_peer_ids.erase(peer_id)
	ai_peer_ids.erase(peer_id)
	if is_instance_valid(player):
		player.queue_free()

func _spawn_bots() -> void:
	for i in range(bot_count):
		var character_name: String = _bot_character_name(i)
		if character_name == "":
			return
		var peer_id: int = BOT_ID_START - i
		_spawn_server_player(peer_id, character_name)
		ai_peer_ids[peer_id] = true
		bot_inputs[peer_id] = _empty_input()
		bot_timers[peer_id] = 0.0

func simulate_player_join(character_name: String = "") -> void:
	if not active or not multiplayer.is_server():
		return
	if character_name == "" or not characters_by_name.has(character_name):
		character_name = _default_character_name(simulated_player_count)
	if character_name == "":
		return
	var peer_id: int = _next_simulated_peer_id()
	simulated_player_count += 1
	_spawn_server_player(peer_id, character_name)
	simulated_peer_ids[peer_id] = true
	ai_peer_ids[peer_id] = true
	bot_inputs[peer_id] = _empty_input()
	bot_timers[peer_id] = 0.0

func _next_simulated_peer_id() -> int:
	while players.has(next_simulated_peer_id):
		next_simulated_peer_id += 1
	var peer_id: int = next_simulated_peer_id
	next_simulated_peer_id += 1
	return peer_id

func _update_ai_input(peer_id: int, delta: float) -> Dictionary:
	var input: Dictionary = bot_inputs.get(peer_id, _empty_input()).duplicate(true)
	input["jump"] = false
	input["attack"] = false
	var timer: float = float(bot_timers.get(peer_id, 0.0)) - delta
	if timer > 0.0:
		bot_timers[peer_id] = timer
		if randf() < 0.006:
			input["jump"] = true
		bot_inputs[peer_id] = input
		return input

	bot_timers[peer_id] = randf_range(bot_input_change_interval * 0.55, bot_input_change_interval * 1.45)
	var yaw: float = randf() * TAU
	input = {
		"seq": tick,
		"move": Vector2(0.0, -1.0),
		"jump": randf() < 0.12,
		"sprint": randf() < 0.35,
		"crouch": false,
		"attack": randf() < 0.12,
		"camera_yaw": yaw,
		"camera_pitch": deg_to_rad(-12.0),
	}
	bot_inputs[peer_id] = input
	return input

func _on_input_received(peer_id: int, input: Dictionary) -> void:
	if not multiplayer.is_server() or not players.has(peer_id) or not human_peer_ids.has(peer_id):
		return
	latest_inputs[peer_id] = _sanitize_input(input)

func _on_snapshot_received(snapshot: Dictionary) -> void:
	if multiplayer.is_server():
		return
	var seen := {}
	for raw_state in snapshot.get("players", []):
		if not (raw_state is Dictionary):
			continue
		var state: Dictionary = raw_state
		var peer_id: int = int(state.get("id", 0))
		var character_name: String = String(state.get("character", ""))
		if peer_id == 0 or character_name == "":
			continue
		seen[peer_id] = true
		_spawn_client_player(peer_id, character_name)
		if not players.has(peer_id):
			continue
		var alpha := 1.0 if peer_id == multiplayer.get_unique_id() else REMOTE_SNAPSHOT_ALPHA
		players[peer_id].call("apply_network_snapshot", state, alpha)

	for peer_id in players.keys():
		if not seen.has(peer_id):
			_remove_player(peer_id)

func _on_peer_left(peer_id: int) -> void:
	_remove_player(peer_id)

func _on_server_closed() -> void:
	for peer_id in players.keys():
		_remove_player(peer_id)
	active = false

func _build_snapshot() -> Dictionary:
	var states: Array[Dictionary] = []
	for peer_id in players.keys():
		var player: Node = players[peer_id]
		if is_instance_valid(player):
			var state: Dictionary = player.call("make_network_snapshot")
			state["character"] = String(player_characters.get(peer_id, ""))
			states.append(state)
	return {
		"tick": tick,
		"players": states,
	}

func _sanitize_input(raw_input: Dictionary) -> Dictionary:
	var input := _empty_input()
	input["seq"] = int(raw_input.get("seq", 0))
	input["jump"] = bool(raw_input.get("jump", false))
	input["sprint"] = bool(raw_input.get("sprint", false))
	input["crouch"] = bool(raw_input.get("crouch", false))
	input["attack"] = bool(raw_input.get("attack", false))
	input["dance"] = bool(raw_input.get("dance", false))
	input["camera_yaw"] = wrapf(float(raw_input.get("camera_yaw", 0.0)), -PI, PI)
	input["camera_pitch"] = clampf(float(raw_input.get("camera_pitch", deg_to_rad(-12.0))), deg_to_rad(-60.0), deg_to_rad(10.0))
	var move = raw_input.get("move", Vector2.ZERO)
	if move is Vector2:
		var move_vector: Vector2 = move
		input["move"] = move_vector.limit_length(1.0)
	return input

func _empty_input() -> Dictionary:
	return {
		"seq": 0,
		"move": Vector2.ZERO,
		"jump": false,
		"sprint": false,
		"crouch": false,
		"attack": false,
		"dance": false,
		"camera_yaw": 0.0,
		"camera_pitch": deg_to_rad(-12.0),
	}

func _spawn_position(peer_id: int) -> Vector3:
	var index: int = absi(peer_id - 1) % SPAWN_POINTS.size()
	return SPAWN_POINTS[index]

func _bot_character_name(index: int) -> String:
	if bot_character_names.size() > 0:
		var configured: String = String(bot_character_names[index % bot_character_names.size()])
		if characters_by_name.has(configured):
			return configured
	return _default_character_name(index)

func _default_character_name(offset: int = 0) -> String:
	if character_entries.is_empty():
		return ""
	var index: int = absi(offset) % character_entries.size()
	return String(character_entries[index].get("name", ""))
