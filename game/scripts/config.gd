class_name Config
## Números fijos del juego. Los del vuelo (gravedad, retroceso, giro, inercia)
## están en scripts/tuning.gd porque se ajustan en vivo desde el panel AJUSTES.

const START_AMMO := 20
const MAX_EXTRA_START := 10 # en el mercado se compran hasta 10 balas más al inicio (30)
const HEADSHOT_REWARD := 4 # balas por headshot (en lugar del +2 del kill normal)
const KILL_REWARD := 2 # balas por kill al cuerpo

const ANGULAR_DAMP := 0.15

const BULLET_RANGE := 40.0
const BULLET_SPEED := 55.0 # m/s: las balas vuelan (rápido, pero se ven)
const PIERCE_KILLS := 4 # balas penetrantes: matan hasta 4 en fila
const PIERCE_SLOWMO_KILLS := 3 # una bala penetrante que mata 3 o más: cámara lenta
const RICOCHETS := 1 # balas que rebotan (mercado): rebotes en el piso por bala

const SLOWMO_DURATION := 1.0 # segundos reales
const SLOWMO_SCALE := 0.2
const SLOWMO_RAMP_OUT := 0.3
const LONG_SLOWMO := 2.0 # cámara lenta larga (mercado): los headshots duran el doble

const IDLE_SPIN := 2.2 # rad/s mientras el arma flota antes del primer disparo
const REST_SPEED := 0.3
const REST_TIME_TO_GAME_OVER := 0.8
const MAX_EMPTY_TIME := 6.0

# Personajes
const ENEMY_MASS := 60.0 # pesados: el arma choca y rebota, no los atraviesa
const CORPSE_MASS := 6.0
const KILL_IMPULSE := 30.0 # con gravedad baja, menos impulso o salen de órbita
const NECK_Y := 1.38 # impacto por encima de esto (en coords del personaje) = headshot

# Capas de colisión (bits)
const L_TERRAIN := 1
const L_GUN := 2
const L_ENEMY := 4
const L_CORPSE := 8
const L_FLYER := 16 # bichos voladores y cofre-trampa (áreas que las balas pueden pegar)
const L_PICKUP := 32 # balas sueltas y poderes (las balas los atraviesan)

# Daño (balas = vida)
const HURT_COOLDOWN := 0.6 # invulnerable un ratito después de un golpe
const FLYER_REWARD := 3 # balas por matar un murciélago o un halcón
const MIMIC_REWARD := 5

# Espadachín
const SWORD_REACH := 1.5 # m alrededor del pecho
const SWORD_COOLDOWN := 1.1
const SWORD_KNOCK := Vector2(5.0, 4.0) # empujón al golpearte

# Resorte (vertical, como una pared): te devuelve para atrás; cuanto más fuerte
# chocás, más fuerte te empuja y más te hace girar.
const SPRING_HEIGHT := 2.7
const SPRING_BASE_PUSH := 5.0
const SPRING_PUSH_GAIN := 1.2 # m/s de empuje extra por cada m/s de choque
const SPRING_MAX_PUSH := 20.0
const SPRING_SPIN_GAIN := 1.2 # rad/s de giro por cada m/s de choque

# Bichos voladores: aparecen alrededor de tu altura a medida que avanzás o subís
const SKY_SPAWN_EVERY := Vector2(10.0, 18.0) # metros recorridos entre uno y otro
const SKY_SPAWN_AHEAD := Vector2(14.0, 20.0)
const AIR_SPRING_CHANCE := 0.15 # de lo que aparece en el aire, tanto son resortes flotando

# Halcón: toma tu posición al verte y va lento en línea recta hacia ahí
const HAWK_SIGHT := 13.0
const HAWK_SPEED := 3.2
const HAWK_SPIN := 14.0 # rad/s que te hace girar al golpearte

# Cofres: tienen un candado. Tiro al candado = se abre. Si te chocás el candado,
# se te pega (pesás más) y el cofre se entierra: "cofre perdido".
const CHEST_REWARD := 15 # cofre bueno: 50 % te da 15 balas...
const CHEST_POWER_CHANCE := 0.5 # ...y 50 % un poder
const TRAP_CHANCE := 1.0 / 3.0
const SAFE_CHESTS := 4 # los primeros 4 cofres que matás en tu vida nunca son trampa
const MIMIC_SPEED := 2.6
const MIMIC_DAMAGE := 2 # se mata de un tiro a la boca; en la madera rebota
const PICKUP_LIFE := 14.0

# Poderes (3 headshots seguidos)
const STREAK_FOR_POWER := 3
const POWER_INFINITE_TIME := 20.0
const POWER_LASER_TIME := 60.0
const POWER_LASER_RANGE := 20.0
const POWER_AMMO := 15
const POWER_UNTOUCHABLE_TIME := 15.0

# Altura sobre el piso: qué aparece en el cielo
const PLANE_ALT := 20.0 # desde acá: aviones junto con los halcones
const ROCKET_ALT := 40.0 # desde acá: cohetes y aviones, sin pájaros, y cielo de noche
const SPACE_FADE := 12.0 # metros en los que el cielo pasa de violeta a negro
const SPACE_GRAVITY := 0.45 # en el espacio la gravedad es el 45 % (baja junto con el cielo)

# Avión: cruza volando hacia vos, despacio. Se mata de un tiro a la hélice;
# en el resto del avión las balas rebotan.
const PLANE_SPEED := 3.5
const PLANE_DAMAGE := 2
const PLANE_REWARD := 5

# Cohete: toma tu posición al salir y va rápido en línea recta. Un tiro lo explota.
const ROCKET_SPEED := 9.0
const ROCKET_DAMAGE := 2
const ROCKET_REWARD := 3
const ROCKET_SIGHT := 22.0

# Ventilador: pasados los 500 m, a veces. Te sube hasta donde empiezan los cohetes.
const FAN_FROM := 500.0
const FAN_CHANCE := 0.06 # por bloque
const FAN_WIDTH := 2.4
const FAN_MAX_SPEED := 14.0

# Pasar un nivel especial
const SPECIAL_REWARD := 5

# Candado volador: muere de un tiro; si te toca, se te pega y el arma pesa más
const PADLOCK_REWARD := 3
const LOCK_TIME := 5.0
const LOCK_WEIGHT := 2.0 # gravedad x2 mientras lo tenés pegado
const PADLOCK_CHANCE := 0.12 # de lo que aparece en el cielo

# Más arriba todavía: ovnis y astronautas (ya no hay aviones; los cohetes siguen)
const UFO_ALT := 80.0
const UFO_REWARD := 5 # se mata de un tiro a la cúpula; en el plato rebota
const UFO_MAX := 2 # te persiguen: no más de 2 a la vez
const UFO_CHASE_SPEED := 7.0 # m/s máximos para seguirte
const UFO_HOVER := Vector2(5.5, 1.5) # se pone a esta distancia de vos (al costado, un poco arriba)
const UFO_GIVE_UP := 45.0 # si quedás más lejos que esto, se va
const UFO_DAMAGE := 5 # el láser verde te saca 5 balas
const UFO_SIGHT := 18.0
const UFO_FIRE_EVERY := 3.0
const UFO_AIM_TIME := 0.7 # aviso (línea finita) antes de disparar
const UFO_BEAM_WIDTH := 0.6
# Astronautas (desde la altura de los cohetes): de un tiro, como los del piso:
# headshot (casco) +4 con slow-mo, al cuerpo +2. Vienen en grupitos.
const ASTRONAUT_DAMAGE := 1
const ASTRONAUT_GROUP := Vector2i(2, 4)

# Cohete propulsor: pasados los 3000 m, a veces. Te agarra y te suelta en el espacio.
const BOOSTER_FROM := 3000.0
const BOOSTER_CHANCE := 0.04 # por bloque
const BOOSTER_SPEED := 22.0
const BOOSTER_DROP_ALT := 90.0 # te suelta a esta altura sobre el piso (entre los ovnis)

# Mercado: pasados los 300 m, a veces, una bañadera con billetes. Si el arma
# queda adentro más de 1 s, entrás. Se paga con balas (siempre te queda 1).
const MARKET_FROM := 300.0
const MARKET_CHANCE := 0.05 # por bloque de piso normal
const MARKET_MIN_GAP := 150.0 # metros mínimos entre dos bañaderas
const MARKET_STAY := 1.0
const TUB_SIZE := Vector3(3.2, 1.0, 1.6)
# En cada visita ofrece MARKET_OFFERS mejoras al azar; cada compra en la misma
# partida encarece las siguientes un MARKET_PRICE_STEP.
const MARKET_OFFERS := 3
const MARKET_PRICE_STEP := 0.25
const PERK_RUNS := 10 # las mejoras con duración duran 10 partidas (la actual cuenta)
const PIERCE_COST := 50
const RICOCHET_COST := 40
const SIGHT_COST := 30
const SLOWMO_COST := 25
const INSURANCE_COST := 35
const EXTRA_START_COST := 10
const INSURANCE_AMMO := 5 # el seguro de vida te revive con 5 balas
const SIGHT_RANGE := 6.0 # mirilla láser corta (la del poder llega a POWER_LASER_RANGE)

# Flechas en el borde de la pantalla: lo peligroso que viene de afuera
const ARROW_RANGE := 26.0
