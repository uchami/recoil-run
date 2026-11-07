// Nivel fijo (sin randomness): bloques contiguos con escalones.
// Cada entrada: [largo en metros, altura del techo del bloque].
const PATTERN = [
  [22, 0], // zona de arranque con los 3 personajes
  [6, 0.5],
  [8, 0.2],
  [5, 0.9],
  [9, 0.4],
  [7, 1.1],
  [6, 0.6],
  [10, 0.0],
  [6, 0.7],
  [8, 1.3],
  [7, 0.5],
  [9, 0.1],
];

export const START = { x: 0, y: 2.4 };
export const ENEMY_XS = [4, 6.5, 9];
const LEVEL_START_X = -8;
const LEVEL_END_X = 2500;
const BLOCK_BOTTOM = -30;

export function buildLevel() {
  const blocks = [];
  let x = LEVEL_START_X;
  let i = 0;
  while (x < LEVEL_END_X) {
    const [len, top] = PATTERN[i % PATTERN.length];
    blocks.push({ x0: x, x1: x + len, top, bottom: BLOCK_BOTTOM });
    x += len;
    i++;
  }
  const topAt = (px) => {
    const b = blocks.find((b) => px >= b.x0 && px < b.x1);
    return b ? b.top : 0;
  };
  const enemies = ENEMY_XS.map((ex) => ({ x: ex, y: topAt(ex) }));
  return { blocks, enemies, topAt };
}
