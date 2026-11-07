# Recoil Run

Juego mobile (Android + iPhone) hecho en **Godot 4.7**: un arma que avanza con el retroceso de sus propios disparos.

```
game/            proyecto Godot (el juego)
prototype-web/   prototipo web original (solo referencia)
build/           APK / proyecto iOS exportados (no se versiona)
```

## Correr y probar

```bash
cd game
godot --path .                                   # jugar en desktop (click / espacio = disparar, R = reiniciar)
godot --editor --path .                          # abrir el editor
godot --headless --path . -s res://tests/smoke.gd   # pruebas de física y reglas (deben decir SMOKE OK)
godot --path . -- --demo-headshot                # dispara solo al primer headshot (para grabar el slow-mo)
```

## Exportar

```bash
cd game
godot --headless --path . --export-debug "Android" ../build/recoil-run.apk
adb install -r ../build/recoil-run.apk
```

**iPhone:** requiere Xcode (App Store) y una cuenta de Apple Developer. Con Xcode instalado, completar
`application/app_store_team_id` en el preset "iOS" (`game/export_presets.cfg`) y exportar con
`--export-debug "iOS"`; eso genera un proyecto Xcode en `build/ios/` para correr en el teléfono.

## Reglas y "física trucha" a propósito

- Arrancás con 5 balas. Headshot **+3** (con slow-mo ~1 s), kill al cuerpo **+2**.
- Disparar hacia adelante empuja hacia atrás solo el 20 % de lo que empuja hacia adelante un disparo hacia atrás.
- Los personajes son cuerpos sólidos: el arma choca y no los atraviesa. Muertos, son ragdolls.
- El arma nunca queda plana: tiene una mirilla delantera con colisión, así que dada vuelta se apoya inclinada (física real).
- Lift: todo disparo te levanta como mínimo una velocidad fija (6 m/s, tanto desde el piso como en el aire), apunte donde apunte el cañón; el ángulo decide sobre todo lo horizontal.
- **Las balas son la vida**: cada golpe te saca balas. Sin balas, un golpe te mata. Sin balas y quieta = game over.
  Caer en un hueco = game over.
- Récords (guardados en el teléfono): distancia, altura y balas máximas. El game over muestra el leaderboard
  de intentos ordenado por distancia, con la altura y las balas máximas de cada uno.
- Física "lunar": gravedad 6.5 y caída máxima de 10 m/s, para tener tiempo de maniobrar en el aire.
- Piso infinito: el arranque es fijo (plano, con los 3 personajes); después, bloques de altura random
  entre -6 y 10 m (paredes de hasta 3 m para arriba, bajadas de hasta 5 m) con huecos (~30 % de las veces,
  largo random de 3 a 14 m, hasta 20 m con la distancia) y un personaje cada 7–14 m. Cada partida es un piso distinto.
  Cerca de un hueco la cámara se aleja para que se vea dónde aterrizar.

### Enemigos y cosas

| Qué | Cómo funciona |
|---|---|
| Hombrecito | Sin nada. Headshot +3, al cuerpo +2 |
| Con espada | Si te acercás, te pega: -1 bala y te empuja |
| Con escudo | El escudo (del lado de donde venís) rebota las balas: hay que darle a la cabeza |
| Con casco | El casco rebota las balas: hay que darle al torso |
| Resorte | Si lo tocás te manda bastantes metros para atrás |
| Murciélago | Revolotea. Si te choca se muere y te saca 1 bala. De un tiro: +1 |
| Halcón | Cuando te ve, toma tu posición y va lento en línea recta hacia ahí. Si te toca: -1 bala y te hace girar. De un tiro: +1 |
| Cofre | 3 tiros (barrita de vida). Cada tiro escupe 2 balas que hay que pasar a recoger |
| Cofre trampa (1 de cada 3) | Igual, pero al morir abre la boca con dientes y te persigue: si te toca, -2 balas. 2 tiros más lo matan: +3 |

**Poderes**: 3 headshots seguidos (un kill al cuerpo corta la racha) sueltan un orbe; tocalo para agarrarlo.
Balas infinitas 20 s · mirilla láser de 20 m por 1 min · +15 balas · intocable 15 s.

**Niveles especiales** (el primero a los 300 m, después cada 500 m, sin repetir hasta usar los tres):
escalera hacia abajo de 300 m con huecos, escalera hacia arriba de 300 m con huecos, y nivel aéreo
(200 m sin piso, con balas flotando y murciélagos).

En AJUSTES hay botones de prueba: **PROBAR NIVEL** (reinicia con ese nivel justo después del arranque) y
**PROBAR PODER** (te da el poder en el momento).

Los sonidos se generan con `python3 tools/gen_sfx.py` (síntesis, sin dependencias).

Los números del vuelo (gravedad, retroceso, giro, inercia, caída máxima, rebote, lift en piso y aire) se ajustan **en vivo desde el
botón AJUSTES del juego** y quedan guardados en el teléfono; sus valores por defecto están en
`game/scripts/tuning.gd`. El resto de los números fijos está en `game/scripts/config.gd`.

| Archivo | Qué tiene |
|---|---|
| `scripts/tuning.gd` | Números del vuelo ajustables en vivo (gravedad, retroceso, giro, inercia) |
| `scripts/config.gd` | Números fijos (postura de reposo, recompensas, slow-mo, personajes) |
| `scripts/level.gd` | Generador infinito del piso (alturas, huecos, niveles especiales) y de lo que hay encima |
| `scripts/records.gd` | Récords y leaderboard local |
| `scripts/gun.gd` | Física del arma: retroceso asimétrico, lift, mirilla |
| `scripts/enemy.gd` | Personaje (sin nada / espada / escudo / casco): cuerpo sólido vivo, ragdoll muerto |
| `scripts/things/` | Resorte, murciélago y halcón, cofre y cofre trampa, balas sueltas y poderes, barrita de vida |
| `scripts/sfx.gd` | Sonidos |
| `scripts/main.gd` | Mundo, disparo (hitscan), reglas, cámara, slow-mo, efectos |
| `scripts/hud.gd` | HUD y pantallas de inicio / game over |
| `tests/smoke.gd` | Pruebas headless |
