extends Area3D

## Bala da arma de fogo: voa reto na direção do disparo, causa dano ao
## encostar em algo do grupo "enemy" (mesma interface take_damage da aranha
## e da adaga arremessada — thrown_dagger.gd) e se autodestrói por timeout
## se não acertar nada (Area3D não colide com geometria estática).

const LIFETIME := 2.0
const DAMAGE := 1

var _velocity: Vector3 = Vector3.ZERO
var _shooter: Node = null
var _lifetime_timer: float = LIFETIME
var visual_only: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func launch(velocity: Vector3, shooter: Node) -> void:
	_velocity = velocity
	_shooter = shooter

func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_lifetime_timer -= delta
	if _lifetime_timer <= 0.0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body == _shooter:
		return
	if not visual_only and body.has_method("take_damage"):
		body.take_damage(DAMAGE)
	queue_free()
