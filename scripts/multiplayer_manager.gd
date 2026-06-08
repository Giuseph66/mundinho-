extends Node

const DEFAULT_PORT := 24560
const DEFAULT_MAX_CLIENTS := 8
const GAME_SCENE := "res://scenes/main.tscn"
const SERVER_ID := 1

signal input_received(peer_id: int, input: Dictionary)
signal character_choice_received(peer_id: int, character_name: String)
signal weapon_choice_received(peer_id: int, weapon_id: String)
signal snapshot_received(snapshot: Dictionary)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal server_started(port: int)
signal connected_to_host()
signal connection_failed(message: String)
signal server_closed()

var active := false
var headless_server := false
var current_port := DEFAULT_PORT
var peer: ENetMultiplayerPeer = null

func _ready() -> void:
	_connect_multiplayer_signals()
	if _has_server_arg():
		start_headless_server()

func host(port: int = DEFAULT_PORT, max_clients: int = DEFAULT_MAX_CLIENTS) -> bool:
	close()
	var server_peer := ENetMultiplayerPeer.new()
	var error := server_peer.create_server(port, max_clients)
	if error != OK:
		connection_failed.emit("Nao foi possivel abrir a porta %d." % port)
		return false
	peer = server_peer
	multiplayer.multiplayer_peer = peer
	active = true
	current_port = port
	server_started.emit(port)
	return true

func join(ip: String, port: int = DEFAULT_PORT) -> bool:
	close()
	var client_peer := ENetMultiplayerPeer.new()
	var error := client_peer.create_client(ip, port)
	if error != OK:
		connection_failed.emit("Nao foi possivel conectar em %s:%d." % [ip, port])
		return false
	peer = client_peer
	multiplayer.multiplayer_peer = peer
	active = true
	current_port = port
	return true

func close() -> void:
	if peer != null:
		peer.close()
	peer = null
	active = false
	headless_server = false
	multiplayer.multiplayer_peer = null

func is_multiplayer_active() -> bool:
	return active and multiplayer.multiplayer_peer != null

func is_headless_server() -> bool:
	return headless_server

func start_headless_server() -> void:
	var port := _parse_port_arg(DEFAULT_PORT)
	if host(port, DEFAULT_MAX_CLIENTS):
		headless_server = true
		call_deferred("_load_game_scene")

func send_input(input: Dictionary) -> void:
	if not is_multiplayer_active():
		return
	if multiplayer.is_server():
		input_received.emit(SERVER_ID, input)
	else:
		rpc_id(SERVER_ID, "_server_receive_input", input)

func send_character_choice(character_name: String) -> void:
	if not is_multiplayer_active():
		return
	if multiplayer.is_server():
		character_choice_received.emit(SERVER_ID, character_name)
	else:
		rpc_id(SERVER_ID, "_server_receive_character_choice", character_name)

func send_weapon_choice(weapon_id: String) -> void:
	if not is_multiplayer_active():
		return
	if multiplayer.is_server():
		weapon_choice_received.emit(SERVER_ID, weapon_id)
	else:
		rpc_id(SERVER_ID, "_server_receive_weapon_choice", weapon_id)

func broadcast_snapshot(snapshot: Dictionary) -> void:
	if not is_multiplayer_active() or not multiplayer.is_server():
		return
	rpc("_client_receive_snapshot", snapshot)

@rpc("any_peer", "unreliable")
func _server_receive_input(input: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	input_received.emit(multiplayer.get_remote_sender_id(), input)

@rpc("any_peer", "reliable")
func _server_receive_character_choice(character_name: String) -> void:
	if not multiplayer.is_server():
		return
	character_choice_received.emit(multiplayer.get_remote_sender_id(), character_name)

@rpc("any_peer", "reliable")
func _server_receive_weapon_choice(weapon_id: String) -> void:
	if not multiplayer.is_server():
		return
	weapon_choice_received.emit(multiplayer.get_remote_sender_id(), weapon_id)

@rpc("authority", "unreliable")
func _client_receive_snapshot(snapshot: Dictionary) -> void:
	if multiplayer.is_server():
		return
	snapshot_received.emit(snapshot)

func _connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)

func _on_connected_to_server() -> void:
	active = true
	connected_to_host.emit()

func _on_connection_failed() -> void:
	connection_failed.emit("Conexao recusada ou indisponivel.")
	close()

func _on_server_disconnected() -> void:
	server_closed.emit()
	close()

func _load_game_scene() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _has_server_arg() -> bool:
	for arg in _get_args():
		if String(arg) == "--server":
			return true
	return false

func _parse_port_arg(default_port: int) -> int:
	var args := _get_args()
	for i in args.size():
		var arg := String(args[i])
		if arg == "--port" and i + 1 < args.size():
			return int(args[i + 1])
		if arg.begins_with("--port="):
			return int(arg.get_slice("=", 1))
	return default_port

func _get_args() -> PackedStringArray:
	var args := OS.get_cmdline_user_args()
	if args.size() == 0:
		args = OS.get_cmdline_args()
	return args
