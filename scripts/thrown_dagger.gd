extends Area3D

## Adaga arremessada: voa reto na direção do lançamento, causa dano ao
## encostar em algo do grupo "enemy" (mesma interface take_damage da aranha
## e do player) e se autodestrói por timeout se não acertar nada — Area3D não
## colide com geometria estática, então não há "bater na parede" no v1.

const SPEED := 16.0
const LIFETIME := 3.0
const DAMAGE := 1

var _velocity: Vector3 = Vector3.ZERO
var _thrower: Node = null
var _lifetime_timer: float = LIFETIME

func _ready() -> void:
	body_entered.connect(_on_body_entered)

## Chamado por quem arremessa: define velocidade (já com módulo) e quem
## lançou, pra não acertar a si mesmo.
func launch(velocity: Vector3, thrower: Node) -> void:
	_velocity = velocity
	_thrower = thrower

func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_lifetime_timer -= delta
	if _lifetime_timer <= 0.0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body == _thrower:
		return
	if body.has_method("take_damage"):
		body.take_damage(DAMAGE)
	queue_free()
