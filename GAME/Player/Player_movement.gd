class_name player extends CharacterBody2D

@export_group("Movimiento")
@export var velocidad : float = 400.0
@export var aceleracion_suelo : float = 6000.0
@export var frenada_suelo : float = 6000.0
@export var aceleracion_aire : float = 3500.0
@export var frenada_aire : float = 1200.0

@export_group("Salto")
@export var altura_salto : float = 160.0        # en píxeles, lo que sube de verdad
@export var tiempo_de_subida : float = 0.38     # segundos hasta el punto más alto
@export var tiempo_de_bajada : float = 0.30     # baja más rápido de lo que sube
@export var saltos_maximos : int = 1            # ponlo a 2 para doble salto
@export_range(0.0, 1.0) var corte_de_salto : float = 0.45  # al soltar, se queda con este % de subida
@export var velocidad_maxima_de_caida : float = 1400.0

@export_group("Dash")
@export var velocidad_dash : float = 900.0      # se aplica de golpe, sin acelerar
@export var duracion_dash : float = 0.18
@export var cooldown_dash : float = 0.35        # empieza a contar al TERMINAR el dash
@export var dashes_en_el_aire : int = 1         # se recargan al tocar suelo
@export var buffer_de_dash : float = 0.12

@export_group("Sonidos")
@export var sonido_salto : AudioStream = preload("res://GAME/SFX/PlayerJump.mp3")
@export var sonido_pasos : AudioStream = preload("res://GAME/SFX/PlayerWalkLoop.mp3")
@export var sonido_dash : AudioStream = preload("res://GAME/SFX/PlayerDash.wav")
@export var sonido_aterrizar : AudioStream = preload("res://GAME/SFX/PlayerLand.mp3")
@export_range(-40.0, 12.0) var volumen_salto : float = 0.0
@export_range(-40.0, 12.0) var volumen_pasos : float = -4.0
@export_range(-40.0, 12.0) var volumen_dash : float = 0.0
@export_range(-40.0, 12.0) var volumen_aterrizar : float = 0.0
# Por debajo de esta velocidad de caída no suena: evita el tic
# al bajar un escalón o al despegarte un frame de una pendiente
@export var caida_minima_para_sonar : float = 220.0
# Cuántos dB más flojo suena la caída más suave respecto a la más fuerte
@export var rango_de_volumen_al_caer : float = 9.0
@export var tono_min : float = 0.94   # variación para que no suene a copia
@export var tono_max : float = 1.06
@export var velocidad_minima_para_pasos : float = 30.0

@export_group("Ayudas al jugador")
@export var coyote_time : float = 0.10          # saltar justo después de salir del borde
@export var buffer_de_salto : float = 0.12      # pulsar justo antes de aterrizar
@export_range(0.0, 1.0) var gravedad_en_el_pico : float = 0.55  # flota un pelín arriba
@export var margen_del_pico : float = 120.0     # a qué velocidad se considera "el pico"

# Estos tres se calculan solos a partir de la altura y los tiempos de arriba.
# Así tú piensas en "quiero saltar 160px en 0.38s" y no en números de gravedad.
@onready var velocidad_salto : float = -2.0 * altura_salto / tiempo_de_subida
@onready var gravedad_subiendo : float = 2.0 * altura_salto / pow(tiempo_de_subida, 2.0)
@onready var gravedad_cayendo : float = 2.0 * altura_salto / pow(tiempo_de_bajada, 2.0)

var direccion : float = 0.0
var mirando : float = 1.0        # 1 derecha, -1 izquierda. Para dashear parado
var saltos_dados : int = 0
var coyote_restante : float = 0.0
var buffer_restante : float = 0.0

var dasheando : bool = false
var dash_restante : float = 0.0
var cooldown_restante : float = 0.0
var dashes_dados : int = 0
var buffer_dash_restante : float = 0.0
var direccion_dash : float = 1.0
var pasos : AudioStreamPlayer2D = null


func _ready() -> void:
	$Sprite2D.play("idle")
	preparar_pasos()


# El loop de pasos necesita un reproductor que viva todo el rato,
# no vale el sonar() de un solo uso del GameFeel
func preparar_pasos() -> void:
	if sonido_pasos == null:
		return

	pasos = AudioStreamPlayer2D.new()

	# Duplicamos el stream para poder forzarle el bucle sin tocar
	# el recurso original ni depender de los ajustes de importación
	var stream := sonido_pasos.duplicate()
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true

	pasos.stream = stream
	pasos.volume_db = volumen_pasos
	add_child(pasos)


func _physics_process(delta: float) -> void:
	# Hay que guardarlos ANTES de move_and_slide: al aterrizar, el
	# motor pone la velocidad vertical a cero y ya no sabríamos
	# si ha sido un saltito o una caída de veinte metros
	var estaba_en_el_aire := not is_on_floor()
	var caida := velocity.y

	actualizar_ayudas(delta)
	actualizar_dash(delta)

	if dasheando:
		# Durante el dash: línea recta, ni gravedad ni control
		velocity = Vector2(direccion_dash * velocidad_dash, 0.0)
	else:
		gestionar_salto()
		aplicar_gravedad(delta)
		mover_en_horizontal(delta)

	player_animation()
	move_and_slide()
	comprobar_aterrizaje(estaba_en_el_aire, caida)
	actualizar_pasos()


# Coyote time y buffer: los dos trucos que hacen que un salto
# se sienta justo en vez de tramposo
func actualizar_ayudas(delta: float) -> void:
	if is_on_floor():
		coyote_restante = coyote_time
		saltos_dados = 0
		dashes_dados = 0      # los dashes se recargan al tocar suelo
	else:
		coyote_restante -= delta
		# Si se le acabó el coyote sin saltar, ese salto ya lo ha perdido
		if coyote_restante <= 0.0 and saltos_dados == 0:
			saltos_dados = 1

	# Guardamos la pulsación un ratito por si la ha hecho antes de aterrizar
	if Input.is_action_just_pressed("Salto"):
		buffer_restante = buffer_de_salto
	else:
		buffer_restante -= delta


# ---------------------------------------------------------------
#  Salto
# ---------------------------------------------------------------

func gestionar_salto() -> void:
	if buffer_restante > 0.0 and saltos_dados < saltos_maximos:
		saltar()

	# Salto de altura variable: si sueltas mientras subes, se corta
	if Input.is_action_just_released("Salto") and velocity.y < 0.0:
		velocity.y *= corte_de_salto


func saltar() -> void:
	# La animación se lanza y punto: nada de await, que retrasa el salto un frame
	$Sprite2D.play("jump")
	GameFeel.sonar(sonido_salto, global_position, volumen_salto, tono_min, tono_max)
	velocity.y = velocidad_salto
	saltos_dados += 1
	coyote_restante = 0.0
	buffer_restante = 0.0


func aplicar_gravedad(delta: float) -> void:
	# OJO: multiplicar por delta. Sin esto la gravedad depende
	# de los FPS y el salto se siente distinto en cada ordenador
	velocity.y += gravedad_actual() * delta
	velocity.y = minf(velocity.y, velocidad_maxima_de_caida)


func gravedad_actual() -> float:
	# Cae más rápido de lo que sube: es lo que hace que el salto
	# se sienta con peso en vez de flotar
	var g = gravedad_subiendo if velocity.y < 0.0 else gravedad_cayendo

	# En lo más alto del salto la gravedad baja un poco. Es casi invisible
	# pero da ese momento de control en el aire tipo Hollow Knight
	if absf(velocity.y) < margen_del_pico:
		g *= gravedad_en_el_pico

	return g


func mover_en_horizontal(delta: float) -> void:
	direccion = Input.get_axis("Left", "Right")

	if direccion != 0.0:
		mirando = signf(direccion)

	var acelera = aceleracion_suelo if is_on_floor() else aceleracion_aire
	var frena = frenada_suelo if is_on_floor() else frenada_aire

	if direccion != 0.0:
		velocity.x = move_toward(velocity.x, direccion * velocidad, acelera * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, frena * delta)


# ---------------------------------------------------------------
#  Dash
# ---------------------------------------------------------------

func actualizar_dash(delta: float) -> void:
	cooldown_restante -= delta

	# Mismo truco que el salto: si pulsas un pelín antes de poder, se guarda
	if Input.is_action_just_pressed("Dash"):
		buffer_dash_restante = buffer_de_dash
	else:
		buffer_dash_restante -= delta

	if dasheando:
		dash_restante -= delta
		if dash_restante <= 0.0:
			terminar_dash()
	elif buffer_dash_restante > 0.0 and puede_dashear():
		empezar_dash()


func puede_dashear() -> bool:
	return cooldown_restante <= 0.0 and dashes_dados < dashes_en_el_aire


func empezar_dash() -> void:
	dasheando = true
	dash_restante = duracion_dash
	dashes_dados += 1
	buffer_dash_restante = 0.0

	# Hacia donde pulses; si no pulsas nada, hacia donde mires.
	# Esto es lo que arregla el "dash parado no hace nada"
	var eje := Input.get_axis("Left", "Right")
	direccion_dash = signf(eje) if eje != 0.0 else mirando
	mirando = direccion_dash

	# Los pasos se cortan aquí y no en el siguiente frame: si no,
	# se oye un tic de pisada justo al arrancar el dash
	if pasos != null and pasos.playing:
		pasos.stop()

	GameFeel.sonar(sonido_dash, global_position, volumen_dash, tono_min, tono_max)

	# Si algún día tienes animación de dash, va aquí:
	# $Sprite2D.play("dash")


func terminar_dash() -> void:
	dasheando = false
	cooldown_restante = cooldown_dash

	# Sale del dash a velocidad de carrera, no a 900.
	# Sin esto el dash se siente como un patinazo que no acaba
	velocity.x = direccion_dash * velocidad
	velocity.y = 0.0


# ---------------------------------------------------------------

# Aterrizar es la transición aire -> suelo, no "estar en el suelo"
func comprobar_aterrizaje(estaba_en_el_aire: bool, caida: float) -> void:
	if not estaba_en_el_aire or not is_on_floor():
		return

	if caida < caida_minima_para_sonar:
		return

	# Cuanto más fuerte la caída, más fuerte el golpe. Un salto pequeño
	# y una caída larga sonando igual es lo que hace que un juego
	# suene "plano" sin que sepas por qué
	var fuerza := clampf(caida / velocidad_maxima_de_caida, 0.0, 1.0)
	var volumen := volumen_aterrizar - (1.0 - fuerza) * rango_de_volumen_al_caer

	GameFeel.sonar(sonido_aterrizar, global_position, volumen, tono_min, tono_max)


# Los pasos suenan solo pisando suelo y moviéndose de verdad.
# En el aire y durante el dash se callan
func actualizar_pasos() -> void:
	if pasos == null:
		return

	var andando := is_on_floor() \
			and not dasheando \
			and absf(velocity.x) > velocidad_minima_para_pasos

	if andando and not pasos.playing:
		pasos.play()
	elif not andando and pasos.playing:
		pasos.stop()


func player_animation():
	if velocity.x > 0.0:
		$Sprite2D.flip_h = true
	elif velocity.x < 0.0:
		$Sprite2D.flip_h = false
	if velocity.y > 0.0 and velocity.y < 100.0 or velocity.y < 0.0 and velocity.y > 100.0 or velocity.y == 0.0:
		if velocity.x != 0.0:
			$Sprite2D.play("Walk")
		else:
			$Sprite2D.play("idle")
	else:
		if velocity.y > 0.0:
			$Sprite2D.play("up_jump")
		else:
			$Sprite2D.play("down_jump")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Decoy"):
		decoy()


func decoy():
	pass

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		get_tree().reload_current_scene()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Boss"):
		get_tree().reload_current_scene()
