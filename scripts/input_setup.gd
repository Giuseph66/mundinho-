extends Node

func _ready() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("strafe_left", KEY_A)
	_add_key("strafe_right", KEY_D)
	_add_key("jump", KEY_SPACE)
	_add_key("sprint", KEY_SHIFT)
	_add_key("crouch", KEY_CTRL)
	_add_key("inventory", KEY_I)
	_add_key("possess", KEY_F)
	_add_key("interact", KEY_E)
	_add_key("dance", KEY_C)
	_add_key("toggle_view", KEY_TAB)
	_add_key("toggle_camera", KEY_F5)
	_add_key("maze_guide", KEY_END)
	_add_key("randomize_maze", KEY_L)
	_add_mouse_button("attack", MOUSE_BUTTON_LEFT)

func _add_key(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _add_mouse_button(action: StringName, button_index: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action, event)
