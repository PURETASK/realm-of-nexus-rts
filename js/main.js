// Bootstrap: menu, game loop
let game = null, renderer = null, input = null, ui = null, rafId = 0;
let chosenFaction = 'abyss';

function setupMenu() {
  const cards = document.getElementById('factionCards');
  const all = Object.keys(FACTIONS).map(id => ({ id, f: FACTIONS[id] }));
  cards.innerHTML = '';
  for (const c of all) {
    const d = document.createElement('div');
    d.className = 'fcard' + (c.id === chosenFaction ? ' sel' : '');
    d.innerHTML = `<h3 style="color:${c.f.color}">${c.f.name}${c.f.provisional ? ' <span style="font-size:10px;color:#ff9b6a;letter-spacing:1px">PROVISIONAL</span>' : ''}</h3><div style="color:#ffd479;font-size:12px;margin-bottom:6px">${c.f.tagline}</div><p>${c.f.blurb}</p><p style="margin-top:8px;color:#8fa0d8">Heroes: ${Object.values(c.f.heroes).map(h => h.name).join(' · ')}</p>`;
    d.onclick = () => { chosenFaction = c.id; document.querySelectorAll('.fcard').forEach(x => x.classList.remove('sel')); d.classList.add('sel'); };
    cards.appendChild(d);
  }
  const sel = document.getElementById('aiFaction'); sel.innerHTML = all.map(c => `<option value="${c.id}">${c.f.name}</option>`).join('') + '<option value="random">Random</option>';
  sel.value = 'tempest';
  document.getElementById('startBtn').onclick = startGame;
  document.getElementById('endBtn').onclick = () => { document.getElementById('endscreen').style.display = 'none'; stopGame(); document.getElementById('menu').style.display = 'flex'; };
  document.getElementById('menuBtn').onclick = () => { stopGame(); document.getElementById('menu').style.display = 'flex'; };
  document.getElementById('pauseBtn').onclick = () => { if (!game) return; game.paused = !game.paused; document.getElementById('pausebox').style.display = game.paused ? 'block' : 'none'; };
}

function startGame() {
  let aiF = document.getElementById('aiFaction').value;
  if (aiF === 'random') aiF = choice(Object.keys(FACTIONS));
  const diff = document.getElementById('difficulty').value;
  document.getElementById('menu').style.display = 'none';
  document.getElementById('game').style.display = 'block';
  const canvas = document.getElementById('canvas'), mm = document.getElementById('minimap');
  resize();
  game = new Game({ playerFaction: chosenFaction, aiFaction: aiF, difficulty: diff });
  renderer = new Renderer(game, canvas, mm);
  input = new Input(game, renderer, canvas, mm);
  ui = new UI(game, input); input.ui = ui;
  if (!window.sfx) window.sfx = new Sfx();
  sfx.init();
  let shake = 0;
  const base = game.baseOf(0);
  game.camera.x = base.x - renderer.viewW / 2; game.camera.y = base.y - renderer.viewH / 2;
  game.msg(`Enemy: ${FACTIONS[aiF].name} (${DIFFICULTY[diff].name}). Destroy every enemy structure.`, 'warn');
  let last = performance.now();
  window.frame = (dt) => {
    input.updateCamera(dt);
    game.update(dt);
    game.updateWards(game.paused || game.over ? 0 : dt);
    for (const p of game.players) if (p.buffs) for (const k in p.buffs) p.buffs[k] -= dt;
    // sound, screen shake, hit flash
    sfx.view = { x: game.camera.x, y: game.camera.y, w: renderer.viewW, h: renderer.viewH };
    for (const ev of game.events) { const sh = sfx.handle(ev, game.human); if (sh > 0 && ev.x > game.camera.x - 200 && ev.x < game.camera.x + renderer.viewW + 200 && ev.y > game.camera.y - 200 && ev.y < game.camera.y + renderer.viewH + 200) shake = Math.max(shake, sh); }
    game.events.length = 0;
    for (const e of game.entities) if (e.flash > 0) e.flash -= dt;
    const ox = shake > 0.05 ? (Math.random() * 2 - 1) * shake : 0, oy = shake > 0.05 ? (Math.random() * 2 - 1) * shake : 0;
    shake = shake > 0.05 ? shake * Math.exp(-dt * 9) : 0;
    game.camera.x += ox; game.camera.y += oy;
    renderer.draw(input, dt);
    game.camera.x -= ox; game.camera.y -= oy;
    ui.update(dt);
    if (game.over && !game.ended) { game.ended = true; showEnd(); }
  };
  const loop = (now) => {
    const dt = Math.min(0.05, (now - last) / 1000); last = now;
    if (game) window.frame(dt);
    rafId = requestAnimationFrame(loop);
  };
  rafId = requestAnimationFrame(loop);
}

function stopGame() {
  cancelAnimationFrame(rafId);
  document.getElementById('game').style.display = 'none';
  document.getElementById('pausebox').style.display = 'none';
  game = null;
}

function showEnd() {
  const win = game.winner === 0;
  const p = game.players[0];
  document.getElementById('endTitle').textContent = win ? 'VICTORY' : 'DEFEAT';
  document.getElementById('endTitle').style.color = win ? '#ffd479' : '#ff5a3c';
  document.getElementById('endText').innerHTML = `${win ? 'The ' + p.faction.name + ' reigns over the realm.' : 'Your domain has fallen to the ' + game.players[1].faction.name + '.'}<br>Time ${fmtTime(game.time)} · Kills ${p.kills} · Losses ${p.losses} · ${p.faction.resources.primary.name} gathered ${Math.floor(p.stats.p)}`;
  document.getElementById('endscreen').style.display = 'flex';
}

function resize() {
  const canvas = document.getElementById('canvas');
  canvas.width = window.innerWidth; canvas.height = window.innerHeight;
}
window.addEventListener('resize', resize);
window.addEventListener('DOMContentLoaded', setupMenu);
