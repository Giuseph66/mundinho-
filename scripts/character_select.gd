extends CanvasLayer

## Menu de seleção de personagem: lista os descobertos na pasta
## playable_characters. Abre sozinho no início (escolhe quem assumir já de
## cara) e pode ser reaberto a qualquer momento com a tecla [P] pra trocar de
## personagem no meio do jogo. Enquanto aberto, o jogo fica pausado e o mouse
## visível; ao escolher, esconde de novo (não se destrói — fica pronto pra
## reabrir).

const SPAWNER_GROUP := "character_spawner"
const TOGGLE_ACTION := "character_menu"

var _spawner: Node = null
var _root: Control = null
var _was_mouse_captured: bool = false

func _ready() -> void:
	# Funciona com o jogo pausado (o resto congela enquanto se escolhe).
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_ensure_runtime_input()
	# Espera o spawner nascer e popular os personagens (mesma fase de init).
	await get_tree().process_frame
	await get_tree().process_frame
	_spawner = get_tree().get_first_node_in_group(SPAWNER_GROUP)
	var names: Array = []
	if _spawner != null and _spawner.has_method("get_character_names"):
		names = _spawner.get_character_names()

	if names.is_empty():
		# Sem personagens jogáveis: nada a escolher, segue o jogo normal.
		queue_free()
		return

	_build_ui(names)
	_open()

func _unhandled_input(event: InputEvent) -> void:
	if _root == null:
		return
	if event.is_action_pressed(TOGGLE_ACTION):
		if _root.visible:
			_close(false)
		else:
			_open()

func _ensure_runtime_input() -> void:
	if InputMap.has_action(TOGGLE_ACTION):
		return
	InputMap.add_action(TOGGLE_ACTION)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_P
	InputMap.action_add_event(TOGGLE_ACTION, event)

func _build_ui(names: Array) -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.09, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(360, 0)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Escolha seu personagem"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "Os outros ficam no mundo — assuma com F\nReabra este menu a qualquer hora com [P]"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	hint.add_theme_font_size_override("font_size", 14)
	vbox.add_child(hint)

	vbox.add_child(HSeparator.new())

	for character_name in names:
		var button := Button.new()
		button.text = character_name
		button.custom_minimum_size = Vector2(0, 44)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_character_chosen.bind(character_name))
		vbox.add_child(button)

	# Foca o primeiro botão pra dar pra escolher no teclado também.
	for child in vbox.get_children():
		if child is Button:
			(child as Button).grab_focus()
			break

func _open() -> void:
	_root.visible = true
	_was_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in _root.find_children("", "Button", true, false):
		(child as Button).grab_focus()
		break

func _close(picked: bool) -> void:
	_root.visible = false
	get_tree().paused = false
	if _was_mouse_captured or picked:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_character_chosen(character_name: String) -> void:
	if _spawner != null and _spawner.has_method("possess"):
		_spawner.possess(character_name)
	_close(true)
