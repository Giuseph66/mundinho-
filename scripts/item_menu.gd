extends CanvasLayer

@export var items: Array[String] = []

## Slot único de arma (espelha as constantes WEAPON_* de npc_walker.gd — não
## importamos o script só por essas strings, mesmo padrão de nomes de clipe
## hardcoded usado no resto deste arquivo). Cada botão chama equip_weapon()
## no NPC possuído; só uma fica "pressionada" por vez (mochila = seletor).
const WEAPON_OPTIONS: Array[Dictionary] = [
	{"id": "sword", "label": "Espada"},
	{"id": "dagger", "label": "Adaga"},
	{"id": "firearm", "label": "Arma de fogo"},
	{"id": "none", "label": "Desarmar"},
]

const WEAPON_ICON_PATHS: Dictionary = {
	"sword": "res://assets/ui/weapons/sword.png",
	"dagger": "res://assets/ui/weapons/dagger.png",
	"firearm": "res://assets/ui/weapons/firearm.png",
}

## Clipes que envolvem locomoção: o NPC continua andando pelo mundo enquanto
## toca esse clipe (não congela no lugar).
const WALK_ANIMATIONS: Array[String] = [
	"Walk_Loop",
	"Jog_Fwd_Loop",
	"Sprint_Loop",
	"Crouch_Fwd_Loop",
	"ClimbUp_1m_RM",
	"NinjaJump_Idle_Loop",
	"NinjaJump_Land",
	"NinjaJump_Start",
	"Shield_Dash_RM",
	"Slide_Exit",
	"Slide_Loop",
	"Slide_Start",
	"Sword_Dash_RM",
	"Walk_Carry_Loop",
	"Zombie_Walk_Fwd_Loop",
]

## Clipes parados/de ação: o NPC fica parado no lugar tocando o clipe.
const STATIONARY_ANIMATIONS: Array[String] = [
	"Crouch_Idle_Loop",
	"Jump_Loop",
	"A_TPose",
	"Chest_Open",
	"Consume",
	"Farm_Harvest",
	"Farm_PlantSeed",
	"Farm_Watering",
	"Hit_Knockback",
	"Hit_Knockback_RM",
	"Idle_FoldArms_Loop",
	"Idle_Lantern_Loop",
	"Idle_No_Loop",
	"Idle_Rail_Call",
	"Idle_Rail_Loop",
	"Idle_Shield_Break",
	"Idle_Shield_Loop",
	"Idle_TalkingPhone_Loop",
	"LayToIdle",
	"Melee_Hook",
	"Melee_Hook_Rec",
	"OverhandThrow",
	"Shield_OneShot",
	"Sword_Block",
	"Sword_Regular_A",
	"Sword_Regular_A_Rec",
	"Sword_Regular_B",
	"Sword_Regular_B_Rec",
	"Sword_Regular_C",
	"Sword_Regular_Combo",
	"TreeChopping_Loop",
	"Yes",
	"Zombie_Idle_Loop",
	"Zombie_Scratch",
]

## Para cada item do OptionButton: nome do clipe ("" pros separadores) e se
## o NPC deve continuar andando enquanto o clipe toca.
var _option_anim_names: Array[String] = []
var _option_keep_moving: Array[bool] = []
var _weapon_buttons: Dictionary = {}

@onready var grid: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/GridContainer
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Header/CloseButton
@onready var animation_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/AnimationOption
@onready var animation_resume_button: Button = $PanelContainer/MarginContainer/VBoxContainer/AnimationResumeButton

func _ready() -> void:
	add_to_group("item_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button.pressed.connect(_toggle)
	_fill_items()
	_build_weapon_section()
	_add_animation_group("— Andando —", WALK_ANIMATIONS, true)
	_add_animation_group("— Parado —", STATIONARY_ANIMATIONS, false)
	animation_option.item_selected.connect(_on_animation_selected)
	animation_resume_button.pressed.connect(_on_animation_resume_pressed)

## Atalho de preview: segurar Shift/Ctrl troca a animação dos NPCs na hora
## (sem precisar abrir o menu), pra comparar "correr" e "andar agachando"
## rapidamente. Solta a tecla, NPC volta a andar normal.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		_toggle()
		return
	if _is_multiplayer_active():
		return
	elif event.is_action_pressed("sprint", false):
		for npc in get_tree().get_nodes_in_group("npc_walker"):
			npc.set_override_animation("Sprint_Loop", true, 2.2)
	elif event.is_action_released("sprint"):
		_resume_npc_walk()
	elif event.is_action_pressed("crouch", false):
		_preview_npc_animation("Crouch_Fwd_Loop", true)
	elif event.is_action_released("crouch"):
		_resume_npc_walk()
	elif event.is_action_pressed("jump", false):
		for npc in get_tree().get_nodes_in_group("npc_walker"):
			npc.trigger_jump()

func _preview_npc_animation(anim_name: String, keep_moving: bool) -> void:
	for npc in get_tree().get_nodes_in_group("npc_walker"):
		npc.set_override_animation(anim_name, keep_moving)

func _resume_npc_walk() -> void:
	for npc in get_tree().get_nodes_in_group("npc_walker"):
		npc.clear_override_animation()

func _toggle() -> void:
	visible = not visible
	if not _is_multiplayer_active():
		get_tree().paused = visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
	if visible:
		_refresh_weapon_buttons()

## Adiciona item ao inventário (chamado por baús/objetos coletáveis) e
## atualiza a grade se o menu já tiver sido construído.
func add_item(item_name: String) -> void:
	items.append(item_name)
	if grid != null:
		_fill_items()

func _fill_items() -> void:
	for child in grid.get_children():
		child.queue_free()
	for item in items:
		var button := Button.new()
		button.custom_minimum_size = Vector2(104, 82)
		button.text = item
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var weapon_id := _weapon_id_from_label(item)
		if weapon_id != "":
			_apply_weapon_icon(button, weapon_id)
		grid.add_child(button)

## Seção "arma equipada": uma fileira de botões (Espada/Adaga/Arma de fogo/
## Desarmar) logo abaixo da grade de itens — a mochila vira o seletor de
## arma do NPC possuído (slot único, ver equip_weapon em npc_walker.gd).
## Construída em código e inserida no VBoxContainer existente, igual ao
## padrão de _fill_items — evita duplicar nós em item_menu_style_wood/clean.tscn.
func _build_weapon_section() -> void:
	var vbox := grid.get_parent()
	var insert_at := grid.get_index() + 1

	var separator := HSeparator.new()
	vbox.add_child(separator)
	vbox.move_child(separator, insert_at)

	var label := Label.new()
	label.text = "Arma equipada"
	vbox.add_child(label)
	vbox.move_child(label, insert_at + 1)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)
	vbox.move_child(row, insert_at + 2)

	_weapon_buttons.clear()
	for option in WEAPON_OPTIONS:
		var weapon_id: String = option["id"]
		var button := Button.new()
		button.text = option["label"]
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_weapon_icon(button, weapon_id)
		button.pressed.connect(_on_weapon_button_pressed.bind(weapon_id))
		row.add_child(button)
		_weapon_buttons[weapon_id] = button

func _weapon_id_from_label(label: String) -> String:
	var normalized_label := label.strip_edges().to_lower()
	for option in WEAPON_OPTIONS:
		if String(option["label"]).to_lower() == normalized_label:
			return String(option["id"])
	return ""

func _apply_weapon_icon(button: Button, weapon_id: String) -> void:
	var path := String(WEAPON_ICON_PATHS.get(weapon_id, ""))
	if path == "":
		return
	var icon := load(path) as Texture2D
	if icon == null:
		return
	var label := button.text
	button.icon = icon
	button.tooltip_text = label
	button.text = ""

## Equipa a arma escolhida no NPC possuído pelo jogador (acessível via
## player.possessed_npc — o player fica no grupo "player", mesmo acesso
## usado por character_spawner.gd). Sem possessão ativa, o clique não faz
## nada (não há em quem equipar).
func _on_weapon_button_pressed(weapon_id: String) -> void:
	var network_game := _get_network_game()
	if network_game != null and network_game.has_method("equip_local_weapon"):
		network_game.equip_local_weapon(weapon_id)
		_refresh_weapon_buttons()
		return
	var npc := _get_equip_target()
	if npc != null and npc.has_method("equip_weapon"):
		npc.equip_weapon(weapon_id)
	_refresh_weapon_buttons()

func _get_equip_target() -> Node:
	var network_game := _get_network_game()
	if network_game != null and network_game.has_method("get_local_character"):
		return network_game.get_local_character()
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	if "possessed_npc" in player:
		return player.possessed_npc
	return null

func _get_network_game() -> Node:
	if not _is_multiplayer_active():
		return null
	return get_tree().get_first_node_in_group("network_game")

func _is_multiplayer_active() -> bool:
	var manager := get_node_or_null("/root/MultiplayerManager")
	return manager != null and manager.has_method("is_multiplayer_active") and bool(manager.call("is_multiplayer_active"))

## Mantém só o botão da arma equipada "pressionado" — usa set_pressed_no_signal
## pra não emitir pressed acidentalmente (toggle_mode buttons emitem pressed quando
## button_pressed é setado programaticamente no Godot 4, causando loop).
func _refresh_weapon_buttons() -> void:
	var npc := _get_equip_target()
	var equipped: String = ""
	if npc != null and "equipped_weapon" in npc:
		equipped = npc.equipped_weapon
	for weapon_id in _weapon_buttons:
		(_weapon_buttons[weapon_id] as Button).set_pressed_no_signal(weapon_id == equipped)

func _add_animation_group(header: String, anim_names: Array[String], keep_moving: bool) -> void:
	animation_option.add_item(header)
	animation_option.set_item_disabled(animation_option.get_item_count() - 1, true)
	_option_anim_names.append("")
	_option_keep_moving.append(false)
	for anim_name in anim_names:
		animation_option.add_item(anim_name)
		_option_anim_names.append(anim_name)
		_option_keep_moving.append(keep_moving)

func _on_animation_selected(index: int) -> void:
	var anim_name := _option_anim_names[index]
	if anim_name == "":
		return
	var keep_moving := _option_keep_moving[index]
	for npc in get_tree().get_nodes_in_group("npc_walker"):
		npc.set_override_animation(anim_name, keep_moving)

func _on_animation_resume_pressed() -> void:
	for npc in get_tree().get_nodes_in_group("npc_walker"):
		npc.clear_override_animation()
