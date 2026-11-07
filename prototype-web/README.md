# Recoil Run

Juego de un arma que se mueve con el retroceso de sus propios disparos.

```bash
npm install
npm run dev     # abre http://localhost:5173 (con --host para probar desde el celular en la misma red)
npm run smoke   # prueba headless de la simulación (física, headshot, kill, slow-mo, game over)
```

- **Controles:** tocar / click / barra espaciadora = disparar. `R` = reiniciar.
- **Reglas:** arrancás con 5 balas. Headshot +3 (con slow-mo), kill al cuerpo +2. Sin balas y quieto = game over.

## Estructura

| Archivo | Qué tiene |
|---|---|
| `src/config.js` | Todos los números de feel (retroceso, giro, gravedad, recompensas, slow-mo) |
| `src/level.js` | Nivel fijo: bloques y posición de los 3 personajes |
| `src/sim.js` | Simulación pura (planck.js): arma, hitscan, enemigos, reglas. Corre en Node |
| `src/render.js` | Escena Three.js, cámara, efectos |
| `src/main.js` | Loop, input, HUD |

Para tunear en vivo desde la consola del navegador: `game.CONFIG.recoilSpeed = 14`.
