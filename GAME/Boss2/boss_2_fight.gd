##
##	Summary:
##	Director de la pelea contra el renacuajo. Es quien manda:
##	las tuberías solo escupen cuando él lo dice y el renacuajo
##	solo salta cuando él lo dice.
##
##	El bucle:
##		GÉISERES → 2 de las 3 tuberías avisan temblando y luego
##		           te lanzan hacia arriba. NO matan: son la forma
##		           de moverte por la sala. La que no tiembla nunca
##		           es la misma dos tandas seguidas.
##		           A la vez que arranca el chorro, el renacuajo sale
##		           del agua, te apunta y se lanza a por ti hasta
##		           salirse de la pantalla. Tocarlo mata: se esquiva
##		           dasheando, que te vuelve inmune.
##
##	Si hay un BossIntro apuntando a este nodo, la pelea espera a que
##	termine el paneo. Si no hay ninguno, arranca sola.
##
##	Dibuja en el editor la franja de agua por la que puede emerger.
##

@tool
extends Node2D

@export var boss : Boss2
@export var pipes : Array[PipeChorro]
@export var marcador_inicio : Marker2D
@export var marcador_fin : Marker2D

@export_group("Fase de géiseres")
@export var tuberias_por_tanda : int = 2
@export var tandas_min : int = 3
@export var tandas_max : int = 5
# El tiempo de aviso NO está aquí: lo pone cada tubería en su propio
# Inspector (duracion_del_aviso), y el director espera a la más lenta
@export var duracion_del_peligro : float = 1.6 # cuánto dura el chorro
@export var pausa_entre_tandas : float = 1.0
# La última tanda antes del salto la hacen siempre las tuberías de los
# extremos, así el único sitio a salvo es el centro y el jugador
# llega colocado a donde pasa el arco del renacuajo
@export var ultimo_ataque_lateral : bool = true

@export_group("Ataque del renacuajo")
# Emerge por un punto aleatorio de la franja entre los dos
# marcadores, así nunca sabes por dónde va a salir
@export var ataca_cada_tanda : bool = true
@export var retardo_del_ataque : float = 0.0   # respecto al chorro

@export_group("Dibujo en el editor")
@export var mostrar_ruta : bool = true
@export var color_ruta : Color = Color(1.0, 0.55, 0.2)

var activo : bool = false
var arrancada : bool = false
var esperando_intro : bool = false
var ultima_segura : PipeChorro = null   # para no repetir el patrón


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if boss == null or marcador_inicio == null or marcador_fin == null:
		push_error("Boss2Fight: faltan el boss o los marcadores del agua")
		return

	limpiar_tuberias()

	# En diferido: así le da tiempo al BossIntro a decir "quieto" en
	# su propio _ready. Sin esto dependería del orden del árbol
	call_deferred("arrancar_si_toca")


# La llama BossIntro al cargar la escena. Es lo que evita tener que
# acordarse de desmarcar una casilla en el Inspector
func esperar_intro() -> void:
	esperando_intro = true


func arrancar_si_toca() -> void:
	if not esperando_intro:
		empezar()


# La llama BossIntro al terminar el paneo
func empezar() -> void:
	if arrancada:
		return

	arrancada = true
	activo = true
	bucle()


# Si Godot guarda la escena mientras el script de las tuberías tiene
# un error, el array typeado se llena de nulls y todo revienta luego
# con un "null instance". Los quitamos aquí y avisamos una sola vez
func limpiar_tuberias() -> void:
	var validas : Array[PipeChorro] = []

	for t in pipes:
		if t != null and is_instance_valid(t):
			validas.append(t)

	if validas.size() != pipes.size():
		push_error("Boss2Fight: hay tuberías sin asignar en 'pipes'. " +
				"Vuelve a arrastrarlas en el Inspector.")

	pipes = validas


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _exit_tree() -> void:
	activo = false
	apagar_todas()


# ---------------------------------------------------------------
#  El bucle de la pelea
# ---------------------------------------------------------------

# Es una corutina: se lee de arriba abajo como el guion de la pelea
func bucle() -> void:
	while activo:
		await fase_geiseres()


func esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


# ---------------------------------------------------------------
#  Fase 1: los géiseres
# ---------------------------------------------------------------

func fase_geiseres() -> void:
	var tandas := randi_range(tandas_min, tandas_max)

	for i in tandas:
		if not activo:
			return

		var es_la_ultima := (i == tandas - 1)
		var es_la_penultima := (i == tandas - 2)

		var elegidas : Array = []

		if es_la_ultima and ultimo_ataque_lateral:
			elegidas = tuberias_laterales()
		else:
			# La segura de esta tanda no puede ser la de la anterior.
			# Y si la siguiente es la lateral (que deja libre la del
			# centro), esta tampoco puede dejar libre la del centro
			var prohibidas : Array = [ultima_segura]
			if es_la_penultima and ultimo_ataque_lateral:
				prohibidas.append(tuberia_central())

			elegidas = elegir_tuberias(prohibidas)

		# 1) Avisan temblando. Las que NO tiemblan son las seguras,
		#    y el jugador tiene este rato para llegar a una de ellas.
		#    Cada tubería devuelve cuánto va a tardar y esperamos
		#    a la más lenta, por si les pones tiempos distintos
		var espera := 0.0
		for tuberia in elegidas:
			espera = maxf(espera, tuberia.avisar())

		await esperar(espera)
		if not activo:
			return

		# 2) Se enciende el géiser y salen las burbujas
		for tuberia in elegidas:
			tuberia.activar_zona(true)

		# 3) Y con las burbujas sale el renacuajo. Sin await: te
		#    persigue mientras los chorros siguen activos
		if ataca_cada_tanda:
			lanzar_ataque()

		await esperar(duracion_del_peligro)

		# 4) Se apaga
		for tuberia in elegidas:
			tuberia.activar_zona(false)
		await esperar(pausa_entre_tandas)


# Elegimos primero cuál queda A SALVO y disparan las demás.
# Es la vuelta del revés de lo obvio, pero es lo que permite
# garantizar que el sitio seguro cambia en cada tanda
func elegir_tuberias(prohibidas: Array = []) -> Array:
	if pipes.is_empty():
		return []

	var candidatas : Array = []
	for t in pipes:
		if not prohibidas.has(t):
			candidatas.append(t)

	# Si las prohibiciones no dejan ninguna, mejor repetir que no disparar
	if candidatas.is_empty():
		candidatas = pipes.duplicate()

	var segura = candidatas[randi() % candidatas.size()]
	ultima_segura = segura

	var disparan : Array = []
	for t in pipes:
		if t != segura:
			disparan.append(t)

	disparan.shuffle()
	return disparan.slice(0, mini(tuberias_por_tanda, disparan.size()))


# Las dos de los extremos, ordenando por su posición en el mundo.
# Se calcula solo: si mueves las tuberías por el nivel, sigue
# funcionando sin tocar nada
func tuberias_laterales() -> Array:
	if pipes.size() < 3:
		return elegir_tuberias()

	var ordenadas := ordenar_por_x()
	ultima_segura = tuberia_central()

	return [ordenadas[0], ordenadas[ordenadas.size() - 1]]


# La del medio: la que queda a salvo en el ataque lateral
func tuberia_central() -> PipeChorro:
	if pipes.size() < 3:
		return null

	var ordenadas := ordenar_por_x()
	return ordenadas[ordenadas.size() / 2]


func ordenar_por_x() -> Array:
	var ordenadas := pipes.duplicate()
	ordenadas.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	return ordenadas


func apagar_todas() -> void:
	for tuberia in pipes:
		if is_instance_valid(tuberia):
			tuberia.activar_zona(false)


# ---------------------------------------------------------------
#  Fase 2: el ataque
# ---------------------------------------------------------------

# Sin await: el renacuajo hace su ataque entero por su cuenta
# mientras la fase de géiseres sigue su ritmo
func lanzar_ataque() -> void:
	if not is_instance_valid(boss):
		return

	if retardo_del_ataque > 0.0:
		await esperar(retardo_del_ataque)
		if not activo or not is_instance_valid(boss):
			return

	boss.embestir_desde(punto_de_agua_aleatorio())


func punto_de_agua_aleatorio() -> Vector2:
	return marcador_inicio.global_position.lerp(marcador_fin.global_position, randf())


# ---------------------------------------------------------------
#  Dibujo en el editor
# ---------------------------------------------------------------

func _draw() -> void:
	if not Engine.is_editor_hint() or not mostrar_ruta:
		return
	if marcador_inicio == null or marcador_fin == null:
		return

	var a := to_local(marcador_inicio.global_position)
	var b := to_local(marcador_fin.global_position)

	# La franja de agua por la que puede emerger y hundirse
	draw_line(a, b, color_ruta, 4.0)
	draw_circle(a, 10.0, color_ruta)
	draw_circle(b, 10.0, color_ruta)

	# Una marca cada poco, para ver por dónde puede asomar
	for i in 9:
		var t := float(i) / 8.0
		draw_circle(a.lerp(b, t), 5.0, color_ruta)
