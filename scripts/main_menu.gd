extends CanvasLayer

## Tela de título: aparece ao abrir o jogo. "Jogar" troca pra cena do mundo
## (main.tscn); "Opções" abre um painel simples (tela cheia); "Sair" fecha
## o jogo. Constrói a UI em código, igual ao character_select.gd.

const GAME_SCENE := "res://scenes/main.tscn"

var _options_panel: Control = null
var _ip_edit: LineEdit = null
var _status_label: Label = null

func _ready() -> void:
	if MultiplayerManager.is_headless_server():
		return
	layer = 100
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_connect_multiplayer_signals()
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(320, 0)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Mundionho"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var play_button := Button.new()
	play_button.text = "Jogar"
	play_button.custom_minimum_size = Vector2(0, 44)
	play_button.pressed.connect(_on_play_pressed)
	vbox.add_child(play_button)

	var host_button := Button.new()
	host_button.text = "Hospedar LAN"
	host_button.custom_minimum_size = Vector2(0, 44)
	host_button.pressed.connect(_on_host_pressed)
	vbox.add_child(host_button)

	var join_box := HBoxContainer.new()
	join_box.add_theme_constant_override("separation", 8)
	vbox.add_child(join_box)

	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.placeholder_text = "IP do host"
	_ip_edit.custom_minimum_size = Vector2(0, 44)
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_box.add_child(_ip_edit)

	var join_button := Button.new()
	join_button.text = "Entrar LAN"
	join_button.custom_minimum_size = Vector2(118, 44)
	join_button.pressed.connect(_on_join_pressed)
	join_box.add_child(join_button)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_status_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_status_label)

	var options_button := Button.new()
	options_button.text = "Opções"
	options_button.custom_minimum_size = Vector2(0, 44)
	options_button.pressed.connect(_on_options_pressed)
	vbox.add_child(options_button)

	var quit_button := Button.new()
	quit_button.text = "Sair"
	quit_button.custom_minimum_size = Vector2(0, 44)
	quit_button.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_button)

	_options_panel = _build_options_panel()
	vbox.add_child(_options_panel)

	play_button.grab_focus()

func _build_options_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.visible = false
	panel.add_theme_constant_override("separation", 8)
	panel.add_child(HSeparator.new())

	var fullscreen_check := CheckButton.new()
	fullscreen_check.text = "Tela cheia"
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	panel.add_child(fullscreen_check)

	return panel

func _on_play_pressed() -> void:
	MultiplayerManager.close()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_host_pressed() -> void:
	_set_status("Hospedando LAN na porta %d..." % MultiplayerManager.DEFAULT_PORT)
	if MultiplayerManager.host():
		get_tree().change_scene_to_file(GAME_SCENE)

func _on_join_pressed() -> void:
	var ip := _ip_edit.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	_set_status("Conectando em %s:%d..." % [ip, MultiplayerManager.DEFAULT_PORT])
	MultiplayerManager.join(ip)

func _on_options_pressed() -> void:
	_options_panel.visible = not _options_panel.visible

func _on_fullscreen_toggled(pressed: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _connect_multiplayer_signals() -> void:
	if not MultiplayerManager.connected_to_host.is_connected(_on_connected_to_host):
		MultiplayerManager.connected_to_host.connect(_on_connected_to_host)
	if not MultiplayerManager.connection_failed.is_connected(_on_connection_failed):
		MultiplayerManager.connection_failed.connect(_on_connection_failed)
	if not MultiplayerManager.server_closed.is_connected(_on_server_closed):
		MultiplayerManager.server_closed.connect(_on_server_closed)

func _on_connected_to_host() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_connection_failed(message: String) -> void:
	_set_status(message)

func _on_server_closed() -> void:
	_set_status("Servidor desconectado.")

func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
