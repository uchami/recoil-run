class_name Tuning
## Números de feel del vuelo, ajustables en vivo desde el panel AJUSTES del juego.
## Se guardan en el teléfono (user://tuning.cfg). Uso: Tuning.values.gravity

const SAVE_PATH := "user://tuning.cfg"
# Subir esto cuando cambia un valor por defecto que tiene que pisar lo guardado.
# Cada versión lista las claves que se vuelven a poner en su valor por defecto.
const VERSION := 2
const MIGRATIONS := {2: ["backward_recoil_factor"]} # 0.2 -> 0.4

# Física "lunar": poca gravedad para tener tiempo de maniobrar en el aire.
const DEFAULTS := {
	"gravity": 6.5, # m/s² (la "Tierra de juego" de la primera versión era 24)
	"recoil_speed": 7.0, # m/s en sentido contrario al cañón
	# Física trucha a propósito: disparar hacia adelante empuja hacia atrás solo
	# este factor de lo que empuja hacia adelante un disparo hacia atrás.
	"backward_recoil_factor": 0.4,
	"spin_on_shot": 5.0, # rad/s antihorario después de cada disparo
	"velocity_keep": 0.25, # cuánto de la velocidad previa se conserva al disparar
	"max_fall_speed": 10.0, # m/s: tope de velocidad de caída (planea)
	"bounce": 0.7, # rebote del arma contra el piso (0 = seco, 1 = pelota)
	# Lift: velocidad mínima hacia arriba que da cualquier disparo, apunte donde
	# apunte el cañón (0 = solo retroceso puro).
	"ground_lift": 6.0, # disparando apoyada en el piso
	"air_lift": 6.0, # disparando en el aire
}

# [clave, etiqueta, mínimo, máximo, paso]
const SLIDERS := [
	["gravity", "Gravedad", 2.0, 30.0, 0.5],
	["recoil_speed", "Retroceso", 4.0, 20.0, 0.5],
	["backward_recoil_factor", "Empuje hacia atrás", 0.0, 1.0, 0.05],
	["spin_on_shot", "Giro por disparo", 1.0, 14.0, 0.5],
	["velocity_keep", "Inercia entre disparos", 0.0, 1.0, 0.05],
	["max_fall_speed", "Caída máxima", 3.0, 40.0, 1.0],
	["bounce", "Rebote del arma", 0.0, 1.0, 0.05],
	["ground_lift", "Impulso desde el piso", 0.0, 15.0, 0.5],
	["air_lift", "Impulso en el aire", 0.0, 15.0, 0.5],
]

static var values := DEFAULTS.duplicate()
static var _loaded := false


## Carga lo guardado en el teléfono (una sola vez por sesión).
static func load_saved() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		for k in DEFAULTS:
			values[k] = float(cf.get_value("tuning", k, DEFAULTS[k]))
		var saved_version := int(cf.get_value("meta", "version", 1))
		if saved_version < VERSION:
			for v in MIGRATIONS:
				if v > saved_version:
					for k in MIGRATIONS[v]:
						values[k] = DEFAULTS[k]
			_save()


static func set_value(key: String, value: float) -> void:
	values[key] = value
	_save()


static func reset(save := true) -> void:
	values = DEFAULTS.duplicate()
	_loaded = true
	if save:
		_save()


static func _save() -> void:
	var cf := ConfigFile.new()
	for k in DEFAULTS:
		cf.set_value("tuning", k, values[k])
	cf.set_value("meta", "version", VERSION)
	cf.save(SAVE_PATH)
