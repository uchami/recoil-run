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

- Arrancás con 20 balas (hasta 30 comprando en el mercado). Headshot **+4** (con slow-mo ~1 s), kill al cuerpo **+2**.
- Es un juego de **puntería**: lo que importa es *a qué parte* le pegás, no cuántos tiros (casi todo muere de un tiro).
- Las balas **vuelan** (55 m/s, con estela): no son instantáneas, se ve adónde van. En slow-mo van lentas.
- **No se puede matar lo que todavía no apareció en pantalla**: la bala le pasa de largo.
- Lo peligroso que está cerca pero fuera de pantalla (cohetes, aviones, ovnis) se marca con una **flecha** en el
  borde, del color del bicho; más grande cuanto más cerca.
- Una bala penetrante que mata a 3 o más: cámara lenta para festejar.
- Disparar hacia adelante empuja hacia atrás solo el 40 % de lo que empuja hacia adelante un disparo hacia atrás.
- Los personajes son cuerpos sólidos: el arma choca y no los atraviesa. Muertos, son ragdolls.
- El arma nunca queda plana: tiene una mirilla delantera con colisión, así que dada vuelta se apoya inclinada (física real).
- Lift: todo disparo te levanta como mínimo una velocidad fija (6 m/s, tanto desde el piso como en el aire), apunte donde apunte el cañón; el ángulo decide sobre todo lo horizontal.
- **Las balas son la vida**: cada golpe te saca balas. Sin balas, un golpe te mata. Sin balas y quieta = game over.
  Caer en un hueco = game over.
- Récords (guardados en el teléfono): distancia, altura y balas máximas. El game over muestra el leaderboard
  de intentos ordenado por distancia, con la altura y las balas máximas de cada uno.
- Física "lunar": gravedad 6.5 y caída máxima de 10 m/s, para tener tiempo de maniobrar en el aire.
- Piso infinito: el arranque es fijo (plano, con los 3 personajes); después, bloques de altura random
  sin límite (paredes de hasta 3 m para arriba, bajadas de hasta 5 m) con huecos (~30 % de las veces,
  largo random de 3 a 14 m, hasta 20 m con la distancia) y algo cada 7–14 m. Cada partida es un piso distinto.
  Cerca de un hueco la cámara se aleja para que se vea dónde aterrizar.

### Enemigos y cosas

| Qué | Cómo funciona |
|---|---|
| Hombrecito | Sin nada. Headshot +4, al cuerpo +2 |
| Con espada | Si te acercás, te pega: -1 bala y te empuja |
| Con escudo | El escudo (del lado de donde venís) rebota las balas: hay que darle a la cabeza |
| Con casco | El casco rebota las balas: hay que darle al torso |
| Resorte | Pared vertical: te devuelve para atrás; cuanto más fuerte chocás, más fuerte te empuja y más te hace girar |
| Ventilador | Pasados los 500 m, a veces. Te sube hasta la altura donde empiezan los cohetes |
| Cohete propulsor | Pasados los 3000 m, a veces. Lo tocás, te agarra y te suelta en el espacio (90 m sobre el piso) |
| Resorte flotando | Igual que el del piso, a cualquier altura |
| Candado | Flota. Muere de un tiro (+3). Si te toca se te pega: el arma pesa el doble 5 s (otro candado renueva el tiempo) |
| Ovni | **Te persigue**: si avanzás, te sigue y se pone al costado tuyo (si lo dejás muy lejos, se va; no más de 2 a la vez). Avisa con una línea finita y a los 0.7 s dispara un láser verde: -5 balas. Se esquiva moviéndote. Se mata de un tiro a la **cúpula** (+5); en el plato rebota |
| Astronauta | Vienen en grupitos (a veces en fila). Flotan dando vueltas; si te choca -1 y te empuja. De un tiro, como los del piso: al casco headshot +4 con slow-mo, al cuerpo +2 |
| Murciélago | Revolotea. Si te choca se muere y te saca 1 bala. De un tiro: +3 |
| Halcón | Cuando te ve, toma tu posición y va lento en línea recta hacia ahí. Si te toca: -1 bala y te hace girar. De un tiro: +3 |
| Avión | Cruza despacio hacia vos. Solo se derriba con un tiro a la **hélice** de adelante (+5); en el resto rebota. Si te choca: -2 |
| Cohete | Te apunta y va derecho, rápido. Si te toca explota: -2. Un tiro lo explota: +3 |
| Cofre (gigante) | Tiene un **candado** adelante. Tiro al candado: se abre (50 % +15 balas, 50 % un poder). Tiros al cofre: nada. Si te chocás el candado, se te pega (pesás el doble 5 s) y el cofre se entierra: "COFRE PERDIDO" |
| Cofre trampa (1 de cada 3) | Al abrirlo abre la boca con dientes y te persigue: si te toca, -2. Se mata de un tiro a la **boca** (la lengua): +5; en la madera rebota. Los primeros 4 cofres que abrís en tu vida nunca son trampa |
| Bañadera con billetes | El **mercado**. Pasados los 300 m, a veces. Si el arma se queda adentro más de 1 s, entrás (ver abajo) |

Los bichos voladores aparecen alrededor de tu altura (no solo cerca del piso), según cuánto subiste sobre el piso:
hasta 20 m halcones y murciélagos; desde 20 m aviones con halcones; desde 40 m astronautas (muchos), cohetes y
aviones, sin pájaros, el cielo pasa a negro con estrellas y la gravedad baja al 45 %; desde 80 m ovnis, astronautas
y cohetes (sin aviones).
Resortes y candados aparecen a cualquier altura.

Al pasar un nivel especial: cartel "¡NIVEL ESPECIAL!" con confeti y +5 balas.

**Poderes** (se aplican solos, no hay que recogerlos): 3 headshots seguidos (perdona los tiros errados; un kill
al cuerpo corta la racha) o 3 kills en 3 tiros (no perdona nada). Al dar un poder se reinician las dos rachas.
Balas infinitas 20 s · mirilla láser de 20 m por 1 min · +15 balas · intocable 15 s.

**Mercado**: se paga con balas; podés gastar todas menos una (siempre seguís jugando). Al salir flotás girando,
inmune, hasta el primer tiro (como al arrancar). En cada visita ofrece **3 mejoras al azar**, como 3 tarjetas
con dibujo: tocás una, abajo se ve en grande qué hace y el botón de comprar; y cada compra en la
misma partida encarece las siguientes un 25 %. Las que tienen duración duran 10 partidas (la actual cuenta).
- **Balas penetrantes** (50): cuando una bala mata, sigue volando, hasta 4 enemigos de un tiro.
- **Balas que rebotan** (40): rebotan una vez en el piso, para tiros de truco.
- **Mirilla láser** (30): una línea corta (6 m) que muestra para dónde apunta el cañón.
- **Cámara lenta larga** (25): los headshots dan el doble de slow-mo.
- **Seguro de vida** (35): la próxima vez que perdés, revivís flotando con 5 balas (si te caíste en un hueco,
  arriba del piso de enfrente). Se usa una vez; no se puede tener dos.
- **+1 bala al inicio** (10 cada una, para siempre): hasta arrancar con 30.

**Niveles especiales** (los primeros 300 m, uno cortito de 60 m a los 100, 200 y 300 m, uno de cada tipo;
después cada 500 m y de largo completo, sin repetir hasta usar los tres):
escalera hacia abajo de 300 m con huecos, escalera hacia arriba de 300 m con huecos, y nivel aéreo
(200 m sin piso, con balas flotando y murciélagos).

En AJUSTES hay botones de prueba: **PROBAR NIVEL** (reinicia con ese nivel, ventilador, cohete o mercado justo después del arranque) y
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
| `scripts/things/` | Resorte, murciélago y halcón, cofre (con candado) y cofre trampa, bañadera del mercado, balas sueltas y poderes |
| `scripts/sfx.gd` | Sonidos |
| `scripts/main.gd` | Mundo, disparo (balas que vuelan), regla de pantalla, reglas, mercado, cámara, slow-mo, efectos |
| `scripts/hud.gd` | HUD y pantallas de inicio / game over |
| `scripts/market_icon.gd` | Dibujos de las mejoras del mercado (vectoriales, hechos por código) |
| `tests/smoke.gd` | Pruebas headless |
