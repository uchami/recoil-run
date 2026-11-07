import { Sim } from './sim.js';
import { View } from './render.js';
import { CONFIG } from './config.js';

const $ = (id) => document.getElementById(id);
const BEST_KEY = 'recoil-run.best';

const sim = new Sim();
const view = new View($('app'), sim);

let best = 0;
try { best = Number(localStorage.getItem(BEST_KEY)) || 0; } catch {}
let overAt = 0;

function shoot() {
  if (sim.state === 'over') {
    if (performance.now() - overAt > 600) restart();
    return;
  }
  sim.shoot();
}

function restart() {
  sim.reset();
  $('over').classList.add('hidden');
  $('start').classList.remove('hidden');
}

// --- input ---
window.addEventListener('pointerdown', (e) => {
  if (e.target.closest('button')) return;
  e.preventDefault();
  shoot();
});
window.addEventListener('keydown', (e) => {
  if (e.repeat) return;
  if (e.code === 'Space' || e.code === 'ArrowUp' || e.code === 'Enter') { e.preventDefault(); shoot(); }
  if (e.code === 'KeyR') restart();
});
$('retry').addEventListener('click', restart);

// --- HUD ---
function popup(text, x, y, cls = '') {
  const el = document.createElement('div');
  el.className = `popup ${cls}`;
  el.textContent = text;
  const margin = 110; // que el texto no se salga por los costados
  el.style.left = `${Math.min(Math.max(x, margin), window.innerWidth - margin)}px`;
  el.style.top = `${y}px`;
  el.addEventListener('animationend', () => el.remove());
  $('popups').appendChild(el);
}

function bumpAmmo() {
  const el = $('ammo');
  el.classList.remove('bump');
  void el.offsetWidth;
  el.classList.add('bump');
}

function handleHud(ev) {
  if (ev.type === 'start') $('start').classList.add('hidden');
  if (ev.type === 'kill') {
    const s = view.toScreen(ev.point.x, ev.point.y + 0.4);
    if (ev.headshot) popup(`HEADSHOT! +${ev.reward}`, s.x, s.y, 'headshot');
    else popup(`+${ev.reward}`, s.x, s.y);
    bumpAmmo();
  }
  if (ev.type === 'empty') {
    const p = sim.pose;
    const s = view.toScreen(p.x, p.y + 1.2);
    popup('SIN BALAS', s.x, s.y, 'empty');
  }
  if (ev.type === 'gameover') {
    overAt = performance.now();
    if (ev.distance > best) {
      best = ev.distance;
      try { localStorage.setItem(BEST_KEY, String(best)); } catch {}
    }
    $('over-dist').textContent = `${ev.distance}m`;
    $('over-best').textContent = `BEST: ${best}m · Kills: ${sim.kills} · Headshots: ${sim.headshots}`;
    $('over').querySelector('.title').textContent = ev.reason === 'fall' ? '¡TE CAÍSTE!' : 'SIN BALAS';
    $('over').classList.remove('hidden');
  }
}

function updateHud() {
  $('best').textContent = `BEST: ${Math.max(best, sim.distance)}m`;
  $('dist').textContent = `${sim.distance}m`;
  $('ammo-n').textContent = sim.ammo;
  const p = sim.pose;
  const s = view.toScreen(p.x - 0.1, p.y + 0.75);
  const ammo = $('ammo');
  ammo.style.transform = `translate(${s.x}px, ${s.y}px) translate(-50%, -100%)`;
  ammo.classList.toggle('empty', sim.ammo === 0);
  const slow = (1 - sim.timeScale) / (1 - CONFIG.slowmoScale);
  $('vignette').style.opacity = String(Math.max(0, slow));
}

// --- loop ---
let last = performance.now();
function frame(now) {
  // el primer timestamp de rAF puede ser anterior a performance.now(): nunca dt < 0
  const dt = Math.min(Math.max((now - last) / 1000, 0), 1 / 20);
  last = now;
  sim.update(dt);
  for (const ev of sim.drainEvents()) {
    view.handle(ev);
    handleHud(ev);
  }
  view.render(dt);
  updateHud();
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

// Para tunear desde la consola: window.game.CONFIG.recoilSpeed = 14
window.game = { sim, view, CONFIG };
