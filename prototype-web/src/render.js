// Render 3D con Three.js. Lee el estado de la Sim y dibuja; no toma decisiones de juego.
import * as THREE from 'three';
import { GUN, ENEMY } from './sim.js';

const FOV = 40;
const VISIBLE_WIDTH = 10; // m visibles a lo ancho en z=0 (pantallas verticales)
const MIN_VISIBLE_HEIGHT = 10; // m visibles a lo alto (pantallas horizontales)
const CAM_OFFSET = new THREE.Vector3(-2.2, 1.3, 0); // vista 3/4 desde atrás y un poco arriba
const LOOK_AHEAD = 3.5;
const ENEMY_COLOR = 0xff1a1a;

export class View {
  constructor(container, sim) {
    this.sim = sim;
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    container.appendChild(renderer.domElement);
    this.renderer = renderer;

    const scene = new THREE.Scene();
    scene.fog = new THREE.Fog(0xe7cdfb, 28, 75);
    this.scene = scene;

    this.camera = new THREE.PerspectiveCamera(FOV, 1, 0.1, 250);
    this.camDist = 20;
    this.camTarget = new THREE.Vector3(sim.pose.x + LOOK_AHEAD, sim.pose.y, 0);

    scene.add(new THREE.HemisphereLight(0xf6ecff, 0x8f8bb0, 1.7));
    const sun = new THREE.DirectionalLight(0xffffff, 1.9);
    sun.castShadow = true;
    sun.shadow.mapSize.set(1024, 1024);
    Object.assign(sun.shadow.camera, { left: -14, right: 14, top: 14, bottom: -14, near: 1, far: 60 });
    sun.shadow.bias = -0.0005;
    scene.add(sun, sun.target);
    this.sun = sun;

    this.buildBlocks();
    this.buildGun();
    this.buildRocks();

    this.flashLight = new THREE.PointLight(0xffd27a, 0, 6, 2);
    scene.add(this.flashLight);

    this.effects = [];
    this.enemyViews = [];
    this.reset();

    this.resize();
    window.addEventListener('resize', () => this.resize());
  }

  // --- construcción ---

  buildBlocks() {
    const mats = [
      new THREE.MeshStandardMaterial({ color: 0xeef0f7, roughness: 0.9 }),
      new THREE.MeshStandardMaterial({ color: 0xe1e4ef, roughness: 0.9 }),
    ];
    const depth = 3.2;
    this.sim.blocks.forEach((b, i) => {
      const w = b.x1 - b.x0;
      const h = b.top - b.bottom;
      const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, depth), mats[i % 2]);
      mesh.position.set((b.x0 + b.x1) / 2, (b.top + b.bottom) / 2, 0);
      mesh.receiveShadow = true;
      this.scene.add(mesh);
    });
  }

  buildGun() {
    const metal = new THREE.MeshStandardMaterial({ color: 0xaab3bd, metalness: 0.75, roughness: 0.3 });
    const dark = new THREE.MeshStandardMaterial({ color: 0x24272c, roughness: 0.55 });
    const g = new THREE.Group();
    const add = (geo, mat, x, y, rz = 0) => {
      const m = new THREE.Mesh(geo, mat);
      m.position.set(x, y, 0);
      m.rotation.z = rz;
      m.castShadow = true;
      g.add(m);
      return m;
    };
    const s = GUN.slide;
    const gr = GUN.grip;
    add(new THREE.BoxGeometry(s.hx * 2, s.hy * 2, 0.14), metal, s.cx, s.cy);
    add(new THREE.BoxGeometry(s.hx * 1.5, 0.08, 0.12), dark, s.cx - 0.05, -0.02);
    add(new THREE.BoxGeometry(gr.hx * 2, gr.hy * 2, 0.13), dark, gr.cx, gr.cy, gr.angle);
    add(new THREE.TorusGeometry(0.065, 0.015, 6, 14, Math.PI), dark, -0.08, -0.06, Math.PI);
    const bore = add(new THREE.CylinderGeometry(0.03, 0.03, 0.02, 10), dark, GUN.muzzle.x + 0.001, GUN.muzzle.y, Math.PI / 2);
    bore.castShadow = false;
    // ranuras de la corredera
    for (let i = 0; i < 5; i++) {
      add(new THREE.BoxGeometry(0.012, s.hy * 1.6, 0.145), dark, -0.38 + i * 0.035, s.cy);
    }
    this.scene.add(g);
    this.gunMesh = g;
  }

  buildRocks() {
    const mat = new THREE.MeshStandardMaterial({ color: 0xc9b6f7, roughness: 1, flatShading: true });
    this.rocks = [];
    for (let i = 0; i < 22; i++) {
      const r = 0.4 + Math.random() * 1.2;
      const mesh = new THREE.Mesh(new THREE.IcosahedronGeometry(r, 0), mat);
      mesh.position.set(-40 + Math.random() * 80, 2 + Math.random() * 18, -18 - Math.random() * 30);
      mesh.rotation.set(Math.random() * 3, Math.random() * 3, 0);
      mesh.userData.spin = (Math.random() - 0.5) * 0.3;
      this.scene.add(mesh);
      this.rocks.push(mesh);
    }
  }

  makeEnemy() {
    const mat = new THREE.MeshStandardMaterial({ color: ENEMY_COLOR, roughness: 0.55 });
    const g = new THREE.Group();
    const part = (geo, x, y, z, rz = 0) => {
      const m = new THREE.Mesh(geo, mat);
      m.position.set(x, y, z);
      m.rotation.z = rz;
      m.castShadow = true;
      g.add(m);
      return m;
    };
    const head = part(new THREE.SphereGeometry(ENEMY.headR, 22, 16), 0, ENEMY.headY, 0);
    part(new THREE.CapsuleGeometry(0.2, 0.42, 6, 14), 0, 1.06, 0);
    const legs = [
      part(new THREE.CapsuleGeometry(0.09, 0.6, 4, 10), 0.08, 0.42, 0.11, -0.18),
      part(new THREE.CapsuleGeometry(0.09, 0.6, 4, 10), -0.08, 0.42, -0.11, 0.18),
    ];
    const arms = [
      part(new THREE.CapsuleGeometry(0.075, 0.5, 4, 10), -0.05, 1.02, 0.27, 0.15),
      part(new THREE.CapsuleGeometry(0.075, 0.5, 4, 10), 0.05, 1.02, -0.27, -0.15),
    ];
    this.scene.add(g);
    return { group: g, mat, head, legs, arms, phase: Math.random() * 6 };
  }

  reset() {
    for (const ev of this.enemyViews) this.scene.remove(ev.group);
    this.enemyViews = this.sim.enemies.map(() => this.makeEnemy());
    for (const fx of this.effects) this.scene.remove(fx.obj);
    this.effects = [];
    const p = this.sim.pose;
    this.camTarget.set(p.x + LOOK_AHEAD, p.y, 0);
  }

  resize() {
    const w = window.innerWidth;
    const h = window.innerHeight;
    this.renderer.setSize(w, h);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    const tan = Math.tan(THREE.MathUtils.degToRad(FOV / 2));
    const byWidth = VISIBLE_WIDTH / 2 / (tan * this.camera.aspect);
    const byHeight = MIN_VISIBLE_HEIGHT / 2 / tan;
    this.camDist = Math.max(byWidth, byHeight);
  }

  // --- eventos de la simulación ---

  handle(ev) {
    if (ev.type === 'reset') this.reset();
    if (ev.type === 'shot') this.onShot(ev);
    if (ev.type === 'kill') this.onKill(ev);
  }

  onShot({ from, to, hit }) {
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const len = Math.hypot(dx, dy);
    // trazador
    const tracer = new THREE.Mesh(
      new THREE.BoxGeometry(len, 0.035, 0.035),
      new THREE.MeshBasicMaterial({ color: 0xfff3b0, transparent: true, opacity: 0.9, fog: false }),
    );
    tracer.position.set(from.x + dx / 2, from.y + dy / 2, 0);
    tracer.rotation.z = Math.atan2(dy, dx);
    this.addEffect(tracer, 0.1, (o, k) => (o.material.opacity = 0.9 * (1 - k)));

    // fogonazo
    const flash = new THREE.Mesh(
      new THREE.SphereGeometry(0.16, 10, 8),
      new THREE.MeshBasicMaterial({ color: 0xfff6d0, transparent: true }),
    );
    flash.position.set(from.x, from.y, 0);
    this.addEffect(flash, 0.08, (o, k) => {
      o.scale.setScalar(1 + k * 1.5);
      o.material.opacity = 1 - k;
    });
    this.flashLight.position.set(from.x, from.y, 0.6);
    this.flashLight.intensity = 25;

    if (hit === 'terrain') this.puff(to, 0x55555f, 6, 0.6);
  }

  onKill({ id, point, headshot }) {
    const ev = this.enemyViews[id];
    if (ev) ev.mat.color.set(0xb30f0f);
    this.puff(point, 0xff2a2a, headshot ? 16 : 10, 1.0, true);
  }

  puff(at, color, count, life, gravity = false) {
    for (let i = 0; i < count; i++) {
      const m = new THREE.Mesh(
        new THREE.IcosahedronGeometry(0.05 + Math.random() * 0.07, 0),
        new THREE.MeshStandardMaterial({ color, transparent: true, flatShading: true }),
      );
      m.position.set(at.x, at.y, (Math.random() - 0.5) * 0.4);
      const v = new THREE.Vector3((Math.random() - 0.5) * 4, Math.random() * 3.5, (Math.random() - 0.5) * 3);
      this.addEffect(m, life * (0.6 + Math.random() * 0.4), (o, k, dt) => {
        if (gravity) v.y -= 14 * dt;
        o.position.addScaledVector(v, dt);
        o.material.opacity = 1 - k;
      });
    }
  }

  addEffect(obj, life, update) {
    this.scene.add(obj);
    this.effects.push({ obj, life, t: 0, update });
  }

  // --- frame ---

  render(realDt) {
    const sim = this.sim;
    const dt = realDt * sim.timeScale;

    // arma
    const p = sim.pose;
    this.gunMesh.position.set(p.x, p.y, 0);
    this.gunMesh.rotation.z = p.angle;

    // personajes
    sim.enemies.forEach((e, i) => {
      const ev = this.enemyViews[i];
      ev.group.position.set(e.x, e.y, 0);
      ev.group.rotation.z = e.rot;
      ev.group.visible = e.deadTime < 4;
      if (e.alive) {
        ev.phase += dt * 2;
        const s = Math.sin(ev.phase);
        ev.arms[0].rotation.z = 0.15 + s * 0.12;
        ev.arms[1].rotation.z = -0.15 - s * 0.12;
        ev.head.position.y = ENEMY.headY + Math.abs(s) * 0.02;
      } else {
        ev.arms[0].rotation.z = 1.2;
        ev.arms[1].rotation.z = -1.2;
      }
    });

    // efectos (corren en tiempo de juego => se ven lentos en slow-mo)
    this.effects = this.effects.filter((fx) => {
      fx.t += dt;
      const k = Math.min(1, fx.t / fx.life);
      fx.update(fx.obj, k, dt);
      if (k >= 1) {
        this.scene.remove(fx.obj);
        fx.obj.geometry.dispose();
        fx.obj.material.dispose();
        return false;
      }
      return true;
    });
    this.flashLight.intensity *= Math.exp(-dt * 40);

    // cámara
    const ground = sim.level.topAt(p.x);
    const ty = Math.max(p.y * 0.6 + ground * 0.4, ground) + 1.6;
    const goal = new THREE.Vector3(p.x + LOOK_AHEAD, ty, 0);
    this.camTarget.lerp(goal, 1 - Math.exp(-realDt * 5));
    const slowZoom = 1 - (1 - sim.timeScale) * 0.18; // acerca un poco en slow-mo
    const dist = this.camDist * slowZoom;
    this.camera.position.set(
      this.camTarget.x + CAM_OFFSET.x,
      this.camTarget.y + CAM_OFFSET.y,
      dist,
    );
    this.camera.lookAt(this.camTarget);

    this.sun.position.set(this.camTarget.x - 6, this.camTarget.y + 14, 8);
    this.sun.target.position.copy(this.camTarget);

    // rocas flotantes con parallax (se reciclan alrededor de la cámara)
    for (const r of this.rocks) {
      r.rotation.y += r.userData.spin * realDt;
      if (r.position.x < this.camTarget.x - 45) r.position.x += 90;
      if (r.position.x > this.camTarget.x + 45) r.position.x -= 90;
    }

    this.renderer.render(this.scene, this.camera);
  }

  // Proyecta un punto del mundo a píxeles de pantalla (para el HUD).
  toScreen(x, y, z = 0) {
    const v = new THREE.Vector3(x, y, z).project(this.camera);
    return { x: (v.x + 1) / 2 * window.innerWidth, y: (1 - v.y) / 2 * window.innerHeight };
  }
}
