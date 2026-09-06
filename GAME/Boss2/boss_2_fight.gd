##
##	Summary:
##	Director de la pelea contra el renacuajo. Es quien manda:
##	las tuberías solo escupen cuando él lo dice y el renacuajo
##	solo salta cuando él lo dice.
##
##	El bucle:
##		PELIGRO → 2 de las 3 tuberías avisan temblando y luego
##		          encienden su zona de muerte. La que no tiembla
##		          es la segura. Se repite de 1 a 3 veces.
##		SALTO   → el renacuajo cruza en arco: la ventana para atacarle
##
##	Dibuja el arco en el editor para que veas la ruta sin darle a play.
##

@tool
extends Node2D

@export var boss : Boss2
@export var pipes : Array[PipeChorro]
@export var marcador_inicio : Marker2D
@export var marcador_fin : Marker2D

@export_group("Fase de peligro")
@export var tuberias_por_tanda : int = 2
@export var tandas_min : int = 1
@export var tandas_max : int = 3
# El tiempo de aviso NO está aquí: lo pone cada tubería en su propio
# Inspector (duracion_del_aviso), y el director espera a la más lenta
@export var duracion_del_peligro : float = 1.6 # cuánto dura el chorro
@export var pausa_entre_tandas : float = 1.0
# La última tanda antes del salto la hacen siempre las tuberías de los
# extremos, así el único sitio a salvo es el centro y el jugador
# llega colocado a donde pasa el arco del renacuajo
@export var ultimo_ataque_lateral : bool = true

@export_group("Fase de salto")
# La ruta es la misma; lo que cambia es por qué punta la empieza
@export_enum("Siempre A a B", "Alternar", "Aleatorio") var sentido : int = 1
@export var altura_del_arco : float = 320.0
@export var duracion_del_salto : float = 1.6
@export var pausa_antes_del_salto : float = 0.9
@export var pausa_despues : float = 1.0

@export_group("Dibujo en el editor")
@export var mostrar_ruta : bool = true
@export var color_ruta : Color = Color(1.0, 0.55, 0.2)

var activo : bool = true
var toca_ida : bool = true   # para el modo Alternar


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if boss == null or marcador_inicio == null or marcador_fin == null:
		push_error("Boss2Fight: faltan el boss o los marcadores del salto")
		return

	bucle()


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
		await fase_peligro()
		if not activo:
			return
		await fase_salto()


func esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


# ---------------------------------------------------------------
#  Fase 1: las tuberías
# ---------------------------------------------------------------

func fase_peligro() -> void:
	var tandas := randi_range(tandas_min, tandas_max)

	for i in tandas:
		if not activo:
			return

		var es_la_ultima := (i == tandas - 1)
		var elegidas := elegir_tuberias()

		if es_la_ultima and ultimo_ataque_lateral:
			elegidas = tuberias_laterales()

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

		# 2) Se enciende la zona de muerte y salen las burbujas
		for tuberia in elegidas:
			tuberia.activar_zona(true)
		await esperar(duracion_del_peligro)

		# 3) Se apaga
		for tuberia in elegidas:
			tuberia.activar_zona(false)
		await esperar(pausa_entre_tandas)


# Baraja y coge las primeras: así son distintas cada vez
# y nunca se repite la misma tubería dentro de una tanda
func elegir_tuberias() -> Array:
	if pipes.is_empty():
		return []

	var barajadas := pipes.duplicate()
	barajadas.shuffle()

	var cuantas := mini(tuberias_por_tanda, barajadas.size())
	return barajadas.slice(0, cuantas)


# Las dos de los extremos, ordenando por su posición en el mundo.
# Se calcula solo: si mueves las tuberías por el nivel, sigue
# funcionando sin tocar nada
func tuberias_laterales() -> Array:
	if pipes.size() < 3:
		return elegir_tuberias()

	var ordenadas := pipes.duplicate()
	ordenadas.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)

	return [ordenadas[0], ordenadas[ordenadas.size() - 1]]


func apagar_todas() -> void:
	for tuberia in pipes:
		if is_instance_valid(tuberia):
			tuberia.activar_zona(false)


# ---------------------------------------------------------------
#  Fase 2: el salto
# ---------------------------------------------------------------

func fase_salto() -> void:
	await esperar(pausa_antes_del_salto)
	if not activo or not is_instance_valid(boss):
		return

	# El arco es idéntico en los dos sentidos: solo cambia
	# por qué extremo lo empieza
	var desde := marcador_inicio.global_position
	var hasta := marcador_fin.global_position

	if not siguiente_sentido():
		var aux := desde
		desde = hasta
		hasta = aux

	boss.saltar(desde, hasta, altura_del_arco, duracion_del_salto)

	# El renacuajo avisa cuando ha terminado, tanto si completa
	# el arco como si le has dado y se ha caído
	await boss.salto_terminado

	if not activo:
		return
	await esperar(pausa_despues)


# true = de A a B, false = de B a A
func siguiente_sentido() -> bool:
	match sentido:
		0:  # Siempre A a B
			return true
		2:  # Aleatorio
			return randf() < 0.5
		_:  # Alternar: va y vuelve, como un pez de verdad
			var este := toca_ida
			toca_ida = not toca_ida
			return este


# ---------------------------------------------------------------
#  Dibujo del arco en el editor
# ---------------------------------------------------------------

func _draw() -> void:
	if not Engine.is_editor_hint() or not mostrar_ruta:
		return
	if marcador_inicio == null or marcador_fin == null:
		return

	var a := to_local(marcador_inicio.global_position)
	var b := to_local(marcador_fin.global_position)
	var medio := (a + b) * 0.5
	medio.y -= altura_del_arco

	# Muestreamos la misma curva que usa el renacuajo
	var puntos : PackedVector2Array = []
	for i in 33:
		var t := float(i) / 32.0
		puntos.append(a.lerp(medio, t).lerp(medio.lerp(b, t), t))

	draw_polyline(puntos, color_ruta, 3.0)
	draw_circle(a, 10.0, color_ruta)
	draw_circle(b, 10.0, color_ruta)
