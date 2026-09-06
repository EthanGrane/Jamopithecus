##
##	Summary:
##	Boss1. Rueda sin parar por la sala, se mete por una tubería y sale
##	por otra. Al golpearle se queda aturdido y se vuelve inmortal;
##	solo vuelve a ser atacable después de pasar por una tubería.
##

extends CharacterBody2D
class_name Boss1

enum Estado {
	RODANDO,    # va a lo suyo, rebotando por la sala
	ATURDIDO,   # le han dado: quieto, sin colisiones y sin poder recibir más
	DENTRO,     # escondido en una tubería mientras ésta avisa
	HUYENDO,    # inmortal tras un golpe: corre a esconderse en una tubería
}


@export_group("Movimiento")
@export var velocidad_min : float = 500.0
@export var velocidad_max : float = 600.0
@export var gravedad : float = 1800.0
@export var velocidad_maxima_de_caida : float = 1000.0
@export var giro_en_suelo : float = 10.0   # vueltas del sprite al rodar
@export var giro_en_aire : float = 5.0

@export_group("Tuberías")
@export var distancia_de_salida : float = 60.0   # px que sale por delante de la boca
@export var tiempo_entre_tuberias : float = 0.4  # evita el bucle de entrar y salir sin fin
# El boss también se estruja al entrar. Desmárcalo si prefieres
# que solo se deforme la tubería
@export var encogerse_al_entrar : bool = true
@export var escala_al_entrar : Vector2 = Vector2(0.15, 1.3)
@export var duracion_al_entrar : float = 0.18
@export var duracion_al_salir : float = 0.22

@export_group("Colisiones")
# Atraviesa al jugador sin tener que reorganizar capas. Se hace con
# una excepción de colisión, que es por pareja de cuerpos
@export var atravesar_al_jugador : bool = true

@export_group("Huida")
# Tras el golpe es inmortal, así que en vez de quedarse a tiro
# sale disparado a esconderse atravesando el escenario
@export var multiplicador_al_huir : float = 2.0
@export_range(0.0, 1.0) var alpha_al_huir : float = 0.55  # semitransparente = intocable

@export_group("Aturdimiento")
@export var tiempo_aturdido : float = 1.5


var estado : Estado = Estado.RODANDO
var direccion : float = 1.0
var velocidad : float = 0.0
var contador_aturdido : float = 0.0
var cooldown_tuberia : float = 0.0
var contador_dentro : float = 0.0
var ultima_tuberia : Pipe = null
var tuberia_destino : Pipe = null
var tuberia_refugio : Pipe = null
var mascara_original : int = 1
var capa_original : int = 0

@onready var sprite : Sprite2D = $Sprite2D
@onready var salud : HealthComponent = $HealthComponent
@onready var reaccion : HitReactionComponent = $HitReactionComponent


func _ready() -> void:
	$AnimatedSprite2D.play("default")
	capa_original = collision_layer
	mascara_original = collision_mask
	velocidad = randf_range(velocidad_min, velocidad_max)
	direccion = 1.0 if randf() < 0.5 else -1.0

	# En diferido: durante el _ready la escena aún se está montando
	# y el jugador puede no estar accesible todavía
	if atravesar_al_jugador:
		call_deferred("ignorar_al_jugador")


# Le dice al motor que estos dos cuerpos no chocan entre sí, sin
# tocar capas ni máscaras. Se pone en los dos lados por si acaso
func ignorar_al_jugador() -> void:
	var jugador := buscar_jugador()
	if jugador == null:
		push_warning("Boss1: no encuentro al jugador para ignorar su colisión")
		return

	add_collision_exception_with(jugador)
	jugador.add_collision_exception_with(self)


func buscar_jugador() -> PhysicsBody2D:
	# Primero por grupo, que es lo barato
	var por_grupo := get_tree().get_first_node_in_group("player")
	if por_grupo is PhysicsBody2D:
		return por_grupo

	# Y si no está en el grupo, lo buscamos por su clase
	return buscar_por_clase(get_tree().current_scene)


func buscar_por_clase(nodo: Node) -> PhysicsBody2D:
	if nodo == null:
		return null
	if nodo is player:
		return nodo

	for hijo in nodo.get_children():
		var encontrado := buscar_por_clase(hijo)
		if encontrado != null:
			return encontrado

	return null


func _physics_process(delta: float) -> void:
	cooldown_tuberia -= delta

	# Dentro de la tubería no existe: ni gravedad, ni movimiento
	if estado == Estado.DENTRO:
		esperar_dentro(delta)
		return

	match estado:
		Estado.RODANDO:
			rodar(delta)
		Estado.ATURDIDO:
			estar_aturdido(delta)
		Estado.HUYENDO:
			huir(delta)

	# Huyendo no le afecta la gravedad: va en línea recta a su tubería
	if estado != Estado.HUYENDO:
		aplicar_gravedad(delta)
	
	if velocity.x > 0:
		$AnimatedSprite2D.flip_h = true
	elif velocity.x < 0:
		$AnimatedSprite2D.flip_h = false
	move_and_slide()

	# Si choca con una pared se da la vuelta y sigue rodando
	if estado == Estado.RODANDO and is_on_wall():
		direccion = -direccion


# ---------------------------------------------------------------
#  Rodar
# ---------------------------------------------------------------

func rodar(delta: float) -> void:
	velocity.x = velocidad * direccion
	# El sprite gira hacia donde avanza, no siempre al mismo lado
	var giro = giro_en_suelo if is_on_floor() else giro_en_aire
	sprite.rotation += giro * direccion * delta


func aplicar_gravedad(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + gravedad * delta, velocidad_maxima_de_caida)


# ---------------------------------------------------------------
#  Huida
# ---------------------------------------------------------------

# Va en línea recta a la tubería más cercana, atravesando lo que haga
# falta. No hace falta detectar la llegada: el Area2D de la tubería
# lo ve igual, porque las áreas miran la CAPA y esa no se toca
func huir(delta: float) -> void:
	if tuberia_refugio == null or not is_instance_valid(tuberia_refugio):
		terminar_huida()
		return

	var hacia := tuberia_refugio.punto_de_salida() - global_position

	velocity = hacia.normalized() * velocidad * multiplicador_al_huir

	if absf(hacia.x) > 1.0:
		direccion = signf(hacia.x)
	sprite.rotation += giro_en_aire * multiplicador_al_huir * direccion * delta

	# Por si el área de la boca se le escapa entre frames
	if hacia.length() < 24.0:
		entrar_en_tuberia(tuberia_refugio)


# Si no hay tuberías a las que ir, sigue rodando normal (pero inmortal)
func terminar_huida() -> void:
	estado = Estado.RODANDO
	set_deferred("collision_mask", mascara_original)


func tuberia_mas_cercana() -> Pipe:
	var mejor : Pipe = null
	var mejor_distancia := INF

	for t in get_tree().get_nodes_in_group("pipes"):
		var d := global_position.distance_to(t.punto_de_salida())
		if d < mejor_distancia:
			mejor_distancia = d
			mejor = t

	return mejor


# ---------------------------------------------------------------
#  Tuberías
# ---------------------------------------------------------------

# La llama la propia tubería cuando el boss entra en su boca
func entrar_en_tuberia(entrada: Pipe) -> void:
	if estado == Estado.ATURDIDO or cooldown_tuberia > 0.0:
		return

	var destino := elegir_otra_tuberia(entrada)
	if destino == null:
		return

	entrada.tragar()   # la tubería se encoge: se lo ha tragado
	meterse_en(destino)


# Desaparece y espera a que la tubería de destino termine de avisar.
# El jugador ve temblar la tubería y sabe por dónde va a salir
func meterse_en(destino: Pipe) -> void:
	estado = Estado.DENTRO
	tuberia_destino = destino
	ultima_tuberia = destino

	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)

	# La tubería avisa y nos dice cuánto va a tardar
	contador_dentro = destino.avisar()

	ser_tragado()


# El punch de entrar: deja de girar en seco y se estruja
# hacia dentro, como si la tubería se lo sorbiera
func ser_tragado() -> void:
	if not encogerse_al_entrar:
		esconderse_del_todo()
		return

	# Endereza el sprite al giro completo más cercano, para que
	# el aplastamiento se vea horizontal y no en diagonal
	var rotacion_recta := roundf(sprite.rotation / TAU) * TAU

	# El Tween lo pide el componente: es el único dueño de la escala
	# del sprite, así este punch nunca pelea con el del golpe
	var tw := reaccion.crear_tween_de_sprite()
	tw.tween_property(sprite, "scale", reaccion.escala_base * escala_al_entrar, duracion_al_entrar)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sprite, "rotation", rotacion_recta, duracion_al_entrar)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tw.tween_callback(esconderse_del_todo)


func esconderse_del_todo() -> void:
	visible = false
	reaccion.restablecer()


func esperar_dentro(delta: float) -> void:
	contador_dentro -= delta
	if contador_dentro <= 0.0:
		salir_de_tuberia()


func salir_de_tuberia() -> void:
	if tuberia_destino == null or not is_instance_valid(tuberia_destino):
		estado = Estado.RODANDO
		visible = true
		set_deferred("collision_layer", capa_original)
		return

	direccion = tuberia_destino.direccion_salida()

	# Aparece un poco por delante de la boca, mirando hacia fuera.
	# Si saliera justo encima volvería a entrar en su propia área
	global_position = tuberia_destino.punto_de_salida() \
			+ Vector2(direccion * distancia_de_salida, 0.0)

	velocity = Vector2.ZERO
	visible = true
	set_deferred("collision_layer", capa_original)

	tuberia_destino.estallar()   # el golpe seco de la tubería
	ser_escupido()               # y el suyo propio
	cooldown_tuberia = tiempo_entre_tuberias
	estado = Estado.RODANDO

	# Sale de la tubería volviendo a ser atacable
	volver_a_ser_vulnerable()


func elegir_otra_tuberia(entrada: Pipe) -> Pipe:
	var todas := get_tree().get_nodes_in_group("pipes")
	var candidatas : Array[Pipe] = []

	# Ni la que acaba de pisar ni la última por la que salió
	for t in todas:
		if t != entrada and t != ultima_tuberia:
			candidatas.append(t)

	# Si con eso no queda ninguna, relajamos y vale cualquiera menos la de entrada
	if candidatas.is_empty():
		for t in todas:
			if t != entrada:
				candidatas.append(t)

	if candidatas.is_empty():
		push_warning("Boss1: no hay otra tubería en el grupo 'pipes'")
		return null

	return candidatas[randi() % candidatas.size()]


# ---------------------------------------------------------------
#  Aturdimiento
# ---------------------------------------------------------------

# La llama el HealthComponent al recibir un golpe.
# Mantengo el nombre para no romper nada de lo que ya tienes
func change_state() -> void:
	# Dentro de una tubería no se le puede dar
	if estado == Estado.ATURDIDO or estado == Estado.DENTRO:
		return
	aturdir()


func aturdir() -> void:
	estado = Estado.ATURDIDO
	contador_aturdido = tiempo_aturdido
	velocity = Vector2.ZERO

	# Inmortal hasta que pase por una tubería
	salud.invulnerable = true

	# Sin colisiones. Se quita la CAPA y no la máscara: así el jugador
	# y la lanza dejan de detectarlo, pero él sigue apoyado en el suelo
	set_deferred("collision_layer", 0)

	# Sonido, destello, punch, onda, hitstop y sacudida, todo de golpe
	reaccion.reaccionar()


func estar_aturdido(delta: float) -> void:
	velocity.x = 0.0
	if $AnimatedSprite2D.animation != "Hit":
		sprite.visible = false
		$AnimatedSprite2D.play("Hit")
	contador_aturdido -= delta
	if contador_aturdido <= 0.0:
		terminar_aturdimiento()


func terminar_aturdimiento() -> void:
	estado = Estado.HUYENDO
	tuberia_refugio = tuberia_mas_cercana()

	# La CAPA vuelve: las tuberías tienen que poder verlo llegar.
	# La MÁSCARA se va a cero: atraviesa suelo, paredes y tuberías
	set_deferred("collision_layer", capa_original)
	set_deferred("collision_mask", 0)

	# Semitransparente para que se lea que ahora no le puedes dar
	modulate.a = alpha_al_huir


func volver_a_ser_vulnerable() -> void:
	sprite.visible = true
	$AnimatedSprite2D.play("default")
	salud.invulnerable = false
	set_deferred("collision_mask", mascara_original)
	modulate.a = 1.0


# Sale estrujado y se despliega de golpe. Es el mismo punch
# de entrar pero al revés
func ser_escupido() -> void:
	sprite.scale = reaccion.escala_base * escala_al_entrar

	var tw := reaccion.crear_tween_de_sprite()
	tw.tween_property(sprite, "scale", reaccion.escala_base, duracion_al_salir)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
