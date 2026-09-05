##
##	Summary:
##	Efectos de impacto que se pueden llamar desde cualquier sitio,
##	sin autoload ni nodos: son funciones estáticas.
##
##		GameFeel.golpe()                    # hitstop + sacudida
##		GameFeel.congelar(0.10)             # solo el frenazo
##		GameFeel.sacudir(14.0, 0.3)         # solo la sacudida
##

class_name GameFeel
extends RefCounted

static var _congelado : bool = false


# El combo completo de un impacto
static func golpe(hitstop := 0.08, fuerza_sacudida := 10.0, dur_sacudida := 0.25) -> void:
	sacudir(fuerza_sacudida, dur_sacudida)
	congelar(hitstop)


# Hitstop: el juego casi se para un instante. Es el efecto que más
# hace por la sensación de impacto, y el más barato de todos
static func congelar(duracion := 0.08, escala := 0.05) -> void:
	if _congelado:
		return

	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null:
		return

	_congelado = true
	Engine.time_scale = escala

	# El último true es 'ignore_time_scale': si no, el temporizador
	# también iría a cámara lenta y no terminaría nunca
	await arbol.create_timer(duracion, true, false, true).timeout

	Engine.time_scale = 1.0
	_congelado = false


# Avisa a cualquier cámara del grupo "camera_shake"
static func sacudir(fuerza := 10.0, duracion := 0.25) -> void:
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null:
		return
	arbol.call_group("camera_shake", "sacudir", fuerza, duracion)
