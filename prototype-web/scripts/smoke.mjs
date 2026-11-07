// Prueba headless de la simulación: física de retroceso, headshot/kill, slow-mo y game over.
import assert from 'node:assert/strict';
import { Vec2 } from 'planck';
import { Sim, ENEMY, GUN } from '../src/sim.js';
import { CONFIG } from '../src/config.js';

const run = (sim, seconds) => { for (let i = 0; i < seconds * 60; i++) sim.update(1 / 60); };
const aimAt = (sim, x, y) => {
  // Coloca el arma flotando y apuntando a (x, y) antes de disparar.
  const p = sim.gun.getPosition();
  const a = Math.atan2(y - (p.y + GUN.muzzle.y), x - p.x);
  sim.gun.setTransform(p, a);
};

// 1) Disparar hacia adelante empuja hacia atrás; hacia atrás empuja hacia adelante.
{
  const sim = new Sim();
  sim.gun.setTransform(new Vec2(0, 2.4), 0); // cañón a +x
  sim.idleAngle = 0;
  sim.shoot();
  assert.equal(sim.state, 'playing');
  assert.ok(sim.gun.getLinearVelocity().x < -5, 'adelante => atrás');
  const sim2 = new Sim();
  sim2.gun.setTransform(new Vec2(0, 2.4), Math.PI); // cañón a -x
  sim2.shoot();
  assert.ok(sim2.gun.getLinearVelocity().x > 5, 'atrás => adelante');
  run(sim2, 1);
  assert.ok(sim2.gun.getPosition().x > 2, 'avanzó: ' + sim2.gun.getPosition().x.toFixed(2));
  assert.equal(sim2.ammo, CONFIG.startAmmo - 1);
  console.log('ok retroceso, x tras 1s =', sim2.gun.getPosition().x.toFixed(2), 'distance =', sim2.distance);
}

// 2) Headshot: +3, slow-mo.
{
  const sim = new Sim();
  const e = sim.enemies[0];
  aimAt(sim, e.x, e.y + ENEMY.headY);
  const before = sim.ammo;
  sim.shoot();
  const evs = sim.drainEvents();
  const kill = evs.find((x) => x.type === 'kill');
  assert.ok(kill && kill.headshot, 'headshot');
  assert.equal(sim.ammo, before - 1 + CONFIG.headshotReward);
  sim.update(0.1);
  assert.ok(sim.timeScale < 0.5, 'slow-mo activo');
  run(sim, 1.2);
  assert.equal(sim.timeScale, 1, 'slow-mo terminó');
  console.log('ok headshot, ammo =', sim.ammo);
}

// 3) Kill al cuerpo: +2, sin slow-mo.
{
  const sim = new Sim();
  const e = sim.enemies[0];
  aimAt(sim, e.x, e.y + 0.7);
  const before = sim.ammo;
  sim.shoot();
  const kill = sim.drainEvents().find((x) => x.type === 'kill');
  assert.ok(kill && !kill.headshot, 'body kill');
  assert.equal(kill.id, 0);
  assert.equal(sim.ammo, before - 1 + CONFIG.killReward);
  assert.equal(sim.slowmo, 0);
  console.log('ok body kill, ammo =', sim.ammo);
}

// 4) El terreno tapa la bala.
{
  const sim = new Sim();
  sim.gun.setTransform(new Vec2(0, 2.4), -Math.PI / 2); // apunta al piso
  sim.shoot();
  const shot = sim.drainEvents().find((x) => x.type === 'shot');
  assert.equal(shot.hit, 'terrain');
  assert.ok(sim.gun.getLinearVelocity().y > 5, 'disparo al piso => salta');
  console.log('ok terreno, impacto en y =', shot.to.y.toFixed(2));
}

// 5) Sin balas => game over cuando el arma queda quieta.
{
  const sim = new Sim();
  sim.enemies = []; // que no recupere balas por kills
  sim.gun.setTransform(new Vec2(0, 2.4), Math.PI);
  for (let i = 0; i < CONFIG.startAmmo; i++) { sim.shoot(); run(sim, 0.4); }
  assert.equal(sim.ammo, 0);
  run(sim, 8);
  assert.equal(sim.state, 'over');
  const pos = sim.gun.getPosition();
  console.log('ok game over sin balas, distancia =', sim.distance, 'pos =', pos.x.toFixed(2), pos.y.toFixed(2));
}

// 6) Disparar sin parar durante un rato no rompe la física (sin NaN, no atraviesa el piso).
{
  const sim = new Sim();
  sim.ammo = 999;
  for (let i = 0; i < 200; i++) {
    sim.shoot();
    run(sim, 0.25);
    const p = sim.gun.getPosition();
    assert.ok(Number.isFinite(p.x) && Number.isFinite(p.y), 'NaN');
    assert.ok(p.y > sim.level.topAt(p.x) - 0.3, `atravesó el piso en x=${p.x.toFixed(2)} y=${p.y.toFixed(2)}`);
  }
  console.log('ok estrés, distancia =', sim.distance);
}
console.log('SMOKE OK');
