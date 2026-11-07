// Simulación pura (sin DOM ni Three): física del arma, disparos, enemigos, reglas.
// Se puede correr en Node (ver scripts/smoke.mjs).
import { World, Vec2, Box } from 'planck';
import { CONFIG } from './config.js';
import { buildLevel, START } from './level.js';

// Geometría del arma en coordenadas locales (cañón hacia +x, corredera arriba).
export const GUN = {
  slide: { hx: 0.45, hy: 0.09, cx: 0, cy: 0.09 },
  grip: { hx: 0.09, hy: 0.19, cx: -0.27, cy: -0.14, angle: -0.25 },
  muzzle: { x: 0.46, y: 0.11 },
};

// Personaje: origen en los pies.
export const ENEMY = {
  headR: 0.3,
  headY: 1.68, // centro de la cabeza
  bodyHalfW: 0.28,
  bodyTop: 1.38,
};

const STEP = 1 / 120;
const MAX_SUBSTEPS = 10;

export class Sim {
  constructor() {
    this.level = buildLevel();
    this.blocks = this.level.blocks;
    this.minTop = Math.min(...this.blocks.map((b) => b.top));
    this.events = [];
    this.reset();
  }

  reset() {
    const world = new World({ gravity: new Vec2(0, CONFIG.gravity) });
    for (const b of this.blocks) {
      const body = world.createBody({
        type: 'static',
        position: new Vec2((b.x0 + b.x1) / 2, (b.top + b.bottom) / 2),
      });
      body.createFixture({ shape: new Box((b.x1 - b.x0) / 2, (b.top - b.bottom) / 2), friction: 0.7 });
    }

    const gun = world.createBody({
      type: 'dynamic',
      position: new Vec2(START.x, START.y),
      angle: 0,
      bullet: true,
      angularDamping: CONFIG.angularDamping,
      linearDamping: 0.05,
      gravityScale: 0,
    });
    const s = GUN.slide;
    const g = GUN.grip;
    gun.createFixture({
      shape: new Box(s.hx, s.hy, new Vec2(s.cx, s.cy), 0),
      density: 2.5,
      friction: 0.6,
      restitution: 0.15,
    });
    gun.createFixture({
      shape: new Box(g.hx, g.hy, new Vec2(g.cx, g.cy), g.angle),
      density: 6,
      friction: 0.6,
      restitution: 0.15,
    });

    this.world = world;
    this.gun = gun;
    this.enemies = this.level.enemies.map((e, id) => ({
      id,
      x: e.x,
      y: e.y,
      rot: 0,
      alive: true,
      headshot: false,
      vx: 0,
      vy: 0,
      spin: 0,
      deadTime: 0,
    }));
    this.state = 'ready'; // ready | playing | over
    this.ammo = CONFIG.startAmmo;
    this.distance = 0;
    this.kills = 0;
    this.headshots = 0;
    this.slowmo = 0;
    this.timeScale = 1;
    this.acc = 0;
    this.time = 0;
    this.idleAngle = 0;
    this.restTimer = 0;
    this.emptyTimer = 0;
    this.events.length = 0;
    this.emit({ type: 'reset' });
  }

  emit(ev) {
    this.events.push(ev);
  }

  drainEvents() {
    const out = this.events.slice();
    this.events.length = 0;
    return out;
  }

  get pose() {
    const p = this.gun.getPosition();
    return { x: p.x, y: p.y, angle: this.gun.getAngle() };
  }

  muzzle() {
    const m = this.gun.getWorldPoint(new Vec2(GUN.muzzle.x, GUN.muzzle.y));
    const d = this.gun.getWorldVector(new Vec2(1, 0));
    return { x: m.x, y: m.y, dx: d.x, dy: d.y };
  }

  shoot() {
    if (this.state === 'over') return;
    if (this.state === 'ready') {
      this.state = 'playing';
      this.gun.setGravityScale(1);
      this.gun.setAwake(true);
      this.emit({ type: 'start' });
    }
    if (this.ammo <= 0) {
      this.emit({ type: 'empty' });
      return;
    }
    this.ammo--;

    const m = this.muzzle();

    // Retroceso: empuja en sentido contrario al cañón y hace girar el arma.
    const v = this.gun.getLinearVelocity();
    const k = CONFIG.velocityKeep;
    this.gun.setLinearVelocity(
      new Vec2(v.x * k - m.dx * CONFIG.recoilSpeed, v.y * k - m.dy * CONFIG.recoilSpeed),
    );
    this.gun.setAngularVelocity(CONFIG.spinOnShot);

    // Hitscan: terreno vs enemigos, gana el más cercano.
    const range = CONFIG.bulletRange;
    let bestT = this.rayTerrain(m.x, m.y, m.dx, m.dy, range);
    let hit = bestT < range ? { kind: 'terrain' } : null;
    for (const e of this.enemies) {
      if (!e.alive) continue;
      const tHead = rayCircle(m.x, m.y, m.dx, m.dy, e.x, e.y + ENEMY.headY, ENEMY.headR);
      const tBody = rayAabb(
        m.x, m.y, m.dx, m.dy,
        e.x - ENEMY.bodyHalfW, e.y, e.x + ENEMY.bodyHalfW, e.y + ENEMY.bodyTop,
      );
      const t = Math.min(tHead, tBody);
      if (t < bestT) {
        bestT = t;
        hit = { kind: 'enemy', enemy: e, headshot: tHead <= tBody };
      }
    }

    const end = { x: m.x + m.dx * bestT, y: m.y + m.dy * bestT };
    this.emit({ type: 'shot', from: { x: m.x, y: m.y }, to: end, dir: { x: m.dx, y: m.dy }, hit: hit?.kind ?? null });

    if (hit?.kind === 'enemy') this.kill(hit.enemy, hit.headshot, end, m);
  }

  kill(e, headshot, point, dir) {
    e.alive = false;
    e.headshot = headshot;
    e.vx = dir.dx * 7 + 1.5;
    e.vy = 5 + Math.max(0, dir.dy) * 4;
    e.spin = -(4 + Math.random() * 3);
    const reward = headshot ? CONFIG.headshotReward : CONFIG.killReward;
    this.ammo += reward;
    this.kills++;
    if (headshot) {
      this.headshots++;
      this.slowmo = CONFIG.slowmoDuration;
    }
    this.emit({ type: 'kill', id: e.id, headshot, reward, point });
  }

  // Distancia a lo largo del rayo hasta el terreno (o maxT si no toca).
  rayTerrain(ox, oy, dx, dy, maxT) {
    let best = maxT;
    const xMin = Math.min(ox, ox + dx * maxT);
    const xMax = Math.max(ox, ox + dx * maxT);
    for (const b of this.blocks) {
      if (b.x1 < xMin || b.x0 > xMax) continue;
      const t = rayAabb(ox, oy, dx, dy, b.x0, b.bottom, b.x1, b.top);
      if (t < best) best = t;
    }
    return best;
  }

  update(realDt) {
    this.time += realDt;

    // Slow-mo con salida suave.
    let scale = 1;
    if (this.slowmo > 0) {
      this.slowmo = Math.max(0, this.slowmo - realDt);
      const ramp = CONFIG.slowmoRampOut;
      const s = CONFIG.slowmoScale;
      scale = this.slowmo > ramp ? s : 1 - (this.slowmo / ramp) * (1 - s);
    }
    this.timeScale = scale;
    const dt = realDt * scale;

    if (this.state === 'ready') {
      this.idleAngle += CONFIG.idleSpin * realDt;
      const bob = Math.sin(this.time * 2.5) * 0.12;
      this.gun.setTransform(new Vec2(START.x, START.y + bob), this.idleAngle);
      this.gun.setLinearVelocity(new Vec2(0, 0));
      this.gun.setAngularVelocity(0);
    } else {
      this.acc += dt;
      let n = 0;
      while (this.acc >= STEP && n < MAX_SUBSTEPS) {
        this.world.step(STEP);
        this.acc -= STEP;
        n++;
      }
      if (n === MAX_SUBSTEPS) this.acc = 0;
    }

    // Personajes muertos: salen volando con gravedad.
    for (const e of this.enemies) {
      if (e.alive) continue;
      e.deadTime += dt;
      e.vy += CONFIG.gravity * dt;
      e.x += e.vx * dt;
      e.y += e.vy * dt;
      e.rot += e.spin * dt;
    }

    const p = this.gun.getPosition();
    this.distance = Math.max(this.distance, Math.floor(p.x - START.x));

    if (this.state === 'playing') this.checkGameOver(realDt, p);
  }

  checkGameOver(realDt, p) {
    if (p.y < this.minTop - 8) return this.gameOver('fall');
    if (this.ammo > 0) {
      this.restTimer = 0;
      this.emptyTimer = 0;
      return;
    }
    this.emptyTimer += realDt;
    const speed = this.gun.getLinearVelocity().length();
    const still = speed < CONFIG.restSpeed && Math.abs(this.gun.getAngularVelocity()) < 0.5;
    this.restTimer = still ? this.restTimer + realDt : 0;
    if (this.restTimer > CONFIG.restTimeToGameOver || this.emptyTimer > CONFIG.maxEmptyTime) {
      this.gameOver('ammo');
    }
  }

  gameOver(reason) {
    this.state = 'over';
    this.emit({ type: 'gameover', reason, distance: this.distance });
  }
}

// --- Geometría de rayos (dirección normalizada) ---

function rayCircle(ox, oy, dx, dy, cx, cy, r) {
  const fx = ox - cx;
  const fy = oy - cy;
  const b = fx * dx + fy * dy;
  const c = fx * fx + fy * fy - r * r;
  if (c <= 0) return 0; // empieza adentro
  const disc = b * b - c;
  if (disc < 0) return Infinity;
  const t = -b - Math.sqrt(disc);
  return t >= 0 ? t : Infinity;
}

function rayAabb(ox, oy, dx, dy, x0, y0, x1, y1) {
  let tmin = -Infinity;
  let tmax = Infinity;
  if (Math.abs(dx) < 1e-9) {
    if (ox < x0 || ox > x1) return Infinity;
  } else {
    const a = (x0 - ox) / dx;
    const b = (x1 - ox) / dx;
    tmin = Math.max(tmin, Math.min(a, b));
    tmax = Math.min(tmax, Math.max(a, b));
  }
  if (Math.abs(dy) < 1e-9) {
    if (oy < y0 || oy > y1) return Infinity;
  } else {
    const a = (y0 - oy) / dy;
    const b = (y1 - oy) / dy;
    tmin = Math.max(tmin, Math.min(a, b));
    tmax = Math.min(tmax, Math.max(a, b));
  }
  if (tmax < 0 || tmin > tmax) return Infinity;
  return Math.max(0, tmin);
}
