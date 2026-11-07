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
- Sin balas y quieta = game over. Caer en un hueco = game over.
- Récords (guardados en el teléfono): distancia, altura y balas máximas. El game over muestra el leaderboard
  de intentos ordenado por distancia, con la altura y las balas máximas de cada uno.
- Física "lunar": gravedad 6.5 y caída máxima de 10 m/s, para tener tiempo de maniobrar en el aire.
- Piso infinito: el arranque es fijo (plano, con los 3 personajes); después, bloques de altura random
  entre -6 y 10 m (paredes de hasta 3 m para arriba, bajadas de hasta 5 m) con huecos (~30 % de las veces,
  largo random de 3 a 14 m, hasta 20 m con la distancia) y un personaje cada 7–14 m. Cada partida es un piso distinto.
  Cerca de un hueco la cámara se aleja para que se vea dónde aterrizar.

Los números del vuelo (gravedad, retroceso, giro, inercia, caída máxima, rebote, lift en piso y aire) se ajustan **en vivo desde el
botón AJUSTES del juego** y quedan guardados en el teléfono; sus valores por defecto están en
`game/scripts/tuning.gd`. El resto de los números fijos está en `game/scripts/config.gd`.

| Archivo | Qué tiene |
|---|---|
| `scripts/tuning.gd` | Números del vuelo ajustables en vivo (gravedad, retroceso, giro, inercia) |
| `scripts/config.gd` | Números fijos (postura de reposo, recompensas, slow-mo, personajes) |
| `scripts/level.gd` | Generador infinito del piso (alturas, huecos) y de los personajes |
| `scripts/records.gd` | Récords y leaderboard local |
| `scripts/gun.gd` | Física del arma: retroceso asimétrico, lift, mirilla |
| `scripts/enemy.gd` | Personaje: cuerpo sólido vivo, ragdoll muerto, detección de headshot |
| `scripts/main.gd` | Mundo, disparo (hitscan), reglas, cámara, slow-mo, efectos |
| `scripts/hud.gd` | HUD y pantallas de inicio / game over |
| `tests/smoke.gd` | Pruebas headless |
