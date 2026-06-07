extends CanvasLayer

@export var items: Array[String] = ["Madeira", "Pedra", "Comida", "Ferramenta", "Semente", "Corda"]

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

@onready var grid: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/GridContainer
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Header/CloseButton
@onready var animation_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/AnimationOption
@onready var animation_resume_button: Button = $PanelContainer/MarginContainer/VBoxContainer/AnimationResumeButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button.pressed.connect(_toggle)
	_fill_items()
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
	get_tree().paused = visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED

func _fill_items() -> void:
	for child in grid.get_children():
		child.queue_free()
	for item in items:
		var button := Button.new()
		button.custom_minimum_size = Vector2(104, 82)
		button.text = item
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(button)

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
