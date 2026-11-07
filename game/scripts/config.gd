class_name Config
## Números fijos del juego. Los del vuelo (gravedad, retroceso, giro, inercia)
## están en scripts/tuning.gd porque se ajustan en vivo desde el panel AJUSTES.

const START_AMMO := 5
const HEADSHOT_REWARD := 3 # balas por headshot (en lugar del +2 del kill normal)
const KILL_REWARD := 2 # balas por kill al cuerpo

const ANGULAR_DAMP := 0.15

const BULLET_RANGE := 40.0

const SLOWMO_DURATION := 1.0 # segundos reales
const SLOWMO_SCALE := 0.2
const SLOWMO_RAMP_OUT := 0.3

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
const FLYER_REWARD := 1 # balas por matar un murciélago o un halcón
const MIMIC_REWARD := 3

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

# Halcón: toma tu posición al verte y va lento en línea recta hacia ahí
const HAWK_SIGHT := 13.0
const HAWK_SPEED := 3.2
const HAWK_SPIN := 14.0 # rad/s que te hace girar al golpearte

# Cofres
const CHEST_HP := 3
const CHEST_SPIT := 2 # balas que escupe por cada tiro
const TRAP_CHANCE := 1.0 / 3.0
const MIMIC_SPEED := 2.6
const MIMIC_DAMAGE := 2
const MIMIC_HP := 2
const PICKUP_LIFE := 14.0

# Poderes (3 headshots seguidos)
const STREAK_FOR_POWER := 3
const POWER_INFINITE_TIME := 20.0
const POWER_LASER_TIME := 60.0
const POWER_LASER_RANGE := 20.0
const POWER_AMMO := 15
const POWER_UNTOUCHABLE_TIME := 15.0
