// HUD: resources, selection panel, command card, messages, tooltips
class UI {
  constructor(game, input) {
    this.g = game; this.input = input;
    this.el = {
      resP: document.getElementById('resP'), resS: document.getElementById('resS'), resC: document.getElementById('resC'), resSupply: document.getElementById('resSupply'),
      tier: document.getElementById('tierLabel'), weather: document.getElementById('weatherLabel'), clock: document.getElementById('clock'),
      sel: document.getElementById('selpanel'), cmd: document.getElementById('cmdcard'), log: document.getElementById('msglog'), tip: document.getElementById('tooltip'),
    };
    this.timer = 0; this.lastKey = ''; this.commands = []; this.buildMenu = false;
  }

  update(dt) {
    this.timer -= dt; if (this.timer > 0) return; this.timer = 0.1;
    const g = this.g, p = g.players[g.human], f = p.faction, r = f.resources;
    this.el.resP.innerHTML = `<span>${r.primary.icon}</span> ${r.primary.name}: <b>${Math.floor(p.res.p)}</b>`;
    this.el.resS.innerHTML = `<span>${r.secondary.icon}</span> ${r.secondary.name}: <b>${Math.floor(p.res.s)}</b>`;
    this.el.resC.innerHTML = `<span>${r.catalyst.icon}</span> ${r.catalyst.name}: <b>${Math.floor(p.res.c)}</b>`;
    this.el.resSupply.innerHTML = `Supply: <b style="color:${p.supplyUsed >= p.supplyCap ? '#ff9b6a' : '#fff'}">${p.supplyUsed} / ${p.supplyCap}</b>`;
    this.el.tier.textContent = `Tier ${p.tier} — ${f.tiers[p.tier - 1].name}`;
    this.el.weather.textContent = g.weather.storm ? `⛈ STORM ${Math.ceil(g.weather.storm.until)}s` : (g.clarity ? '👁 Eye of Clarity' : '');
    this.el.clock.textContent = fmtTime(g.time);
    this.el.log.innerHTML = g.messages.map(m => `<div class="${m.cls}" style="opacity:${Math.min(1, m.t / 2)}">${m.text}</div>`).join('');
    this.renderSelection();
    this.renderCommands();
  }

  renderSelection() {
    const g = this.g, sel = g.selection, el = this.el.sel;
    if (!sel.length) { el.innerHTML = `<div class="desc" style="margin-top:8px">${g.players[g.human].faction.name} — ${g.players[g.human].faction.tagline}<br><br>${g.players[g.human].faction.blurb}</div>`; return; }
    if (sel.length === 1) {
      const e = sel[0];
      let html = `<h3>${e.name}${e.kind === 'unit' && e.isHero ? ` <span style="color:#ffd479;font-size:12px">Lv ${e.level} · ${e.def.title}</span>` : ''}</h3>`;
      html += `<div class="hpbar"><div style="width:${Math.max(0, e.hp / e.maxHp * 100)}%;background:${e.hp / e.maxHp > 0.5 ? '#3fd66a' : e.hp / e.maxHp > 0.25 ? '#ffd479' : '#ff5a3c'}"></div></div><div>${Math.ceil(e.hp)} / ${e.maxHp}${e.owner !== g.human ? ' <span style="color:#ff9b6a">(Enemy)</span>' : ''}</div>`;
      if (e.kind === 'unit') {
        const st = `Dmg ${Math.round(e.stat('dmg'))} · Armor ${e.stat('armor')} · Range ${e.def.range} · Speed ${(e.stat('speed') / TILE).toFixed(1)}${e.flying ? ' · Flying' : ''}${e.def.air ? ' · Anti-air' : ''}${e.lifetime > 0 ? ` · Expires ${Math.ceil(e.lifetime)}s` : ''}`;
        html += `<div style="color:#9ab;font-size:12px">${st}</div>`;
        if (e.isHero) html += `<div style="color:#9ab;font-size:12px">XP ${Math.floor(e.xp)} / ${e.xpToLevel}</div>`;
        const buffs = e.buffs.filter(b => b.t > 0.5).map(b => b.id.replace(/_/g, ' ')).join(', ');
        if (buffs) html += `<div style="color:#8fd3ff;font-size:11px">Effects: ${buffs}</div>`;
        if (e.isWorker && e.gather.carrying) html += `<div style="font-size:11px">Carrying ${e.gather.carrying} ${e.faction.resources.primary.short}</div>`;
        if (e.maxShield) html += `<div style="color:#9fe0ff;font-size:12px">Shield ${Math.ceil(e.shield)} / ${Math.round(e.stat('maxShield'))}</div>`;
        html += `<div class="desc">${e.def.desc}</div>`;
      } else {
        html += `<div style="color:#9ab;font-size:12px">Armor ${e.stat('armor')}${e.node ? ` · Node: ${e.node.amount >= 1e8 ? '∞' : Math.floor(e.node.amount)}` : ''}${e.def.converter ? ` · Conversion ${e.toggles.convert ? 'ON' : 'OFF'}` : ''}${e.def.catalystGen ? ` · Pearl in ${Math.ceil(e.def.catalystGen.every - e.catalystTimer)}s` : ''}</div>`;
        if (!e.complete) html += `<div>Constructing: ${Math.floor(e.progress * 100)}%${e.builders ? '' : ' <span style="color:#ff9b6a">(no builder!)</span>'}</div>`;
        if (e.relocate) html += `<div style="color:#8fd3ff">Relocating: ${e.relocate.phase}</div>`;
        html += `<div class="desc">${e.def.desc}</div>`;
        if (e.queue.length && e.owner === g.human) {
          html += '<div class="queue">' + e.queue.map((q, i) => { const nm = q.type === 'tier' ? e.faction.tiers[g.players[g.human].tier].name : q.type === 'research' ? e.faction.research[q.id].name : unitDef(e.faction, q.id).name; return `<div class="${i === 0 ? 'active' : ''}" data-q="${i}" title="Click to cancel">${nm}${i === 0 ? ` ${Math.floor(q.elapsed / q.time * 100)}%` : ''}</div>`; }).join('') + '</div>';
        }
      }
      el.innerHTML = html;
      el.querySelectorAll('[data-q]').forEach(q => q.onclick = () => g.dequeue(e, +q.dataset.q));
    } else {
      let html = `<h3>${sel.length} selected</h3><div class="multi">` + sel.map((e, i) => `<div data-i="${i}" title="${e.name}">${e.kind === 'unit' && e.isHero ? '★' : ''}${this.short(e.name)}<div class="b" style="width:${e.hp / e.maxHp * 100}%"></div></div>`).join('') + '</div>';
      el.innerHTML = html;
      el.querySelectorAll('[data-i]').forEach(d => d.onclick = () => { g.selection = [sel[+d.dataset.i]]; });
    }
  }
  short(n) { return n.split(' ').map(w => w[0]).join('').slice(0, 3); }

  // Build the command list for the current selection
  buildCommands() {
    const g = this.g, p = g.players[g.human], f = p.faction, sel = g.selection.filter(e => e.owner === g.human);
    const cmds = [];
    if (!sel.length) return cmds;
    const units = sel.filter(e => e.kind === 'unit'), buildings = sel.filter(e => e.kind === 'building');
    const inp = this.input;
    if (units.length) {
      if (this.buildMenu && units.some(u => u.isWorker)) {
        for (const id in f.buildings) {
          const d = f.buildings[id]; if (d.isBase) continue;
          const locked = d.tier > p.tier, afford = p.canAfford(d.cost);
          cmds.push({ label: d.name, key: d.hotkey, cost: costStr(d.cost, f), tip: `<b>${d.name}</b><br>${d.desc}<br><span class="c">${costStr(d.cost, f)} · ${d.time}s · Tier ${d.tier}</span>${d.needsNode ? '<br>Must be placed on a ' + (d.needsNode === 'primary' ? 'stormglass / soul font node' : 'aether vent') : ''}`, disabled: locked || !afford, why: locked ? 'Requires Tier ' + d.tier : 'Not enough resources', active: inp.pending && inp.pending.kind === 'build' && inp.pending.defId === id,
            act: () => { inp.pending = { kind: 'build', defId: id }; } });
        }
        cmds.push({ label: 'Cancel', key: 'Escape', tip: 'Close build menu', act: () => { this.buildMenu = false; inp.pending = null; } });
        return cmds;
      }
      cmds.push({ label: 'Move', key: 'M', tip: 'Move to a point (right-click also moves)', active: inp.pending && inp.pending.kind === 'move', act: () => inp.pending = { kind: 'move' } });
      cmds.push({ label: 'Stop', key: 'S', tip: 'Stop all actions', act: () => g.orderStop(units) });
      cmds.push({ label: 'Hold', key: 'H', tip: 'Hold position: attack only what comes in range', act: () => g.orderHold(units) });
      if (units.some(u => u.def.dmg > 0 && !u.isWorker)) cmds.push({ label: 'Attack', key: 'A', tip: 'Attack-move: engage enemies met along the way', active: inp.pending && inp.pending.kind === 'attack', act: () => inp.pending = { kind: 'attack' } });
      if (units.some(u => u.isWorker)) {
        cmds.push({ label: 'Build', key: 'B', tip: 'Open the structure menu', act: () => { this.buildMenu = true; inp.pending = null; } });
        if (f.gathers) cmds.push({ label: 'Gather', key: 'G', tip: `Gather ${f.resources.primary.name} from a resource node (or right-click a node)`, active: inp.pending && inp.pending.kind === 'gather', act: () => inp.pending = { kind: 'gather' } });
      }
      const heroes = units.filter(u => u.isHero);
      if (heroes.length === 1) {
        const h = heroes[0];
        for (const id of h.abilities) {
          const ab = ABILITIES[id]; const c = g.canCast(h, id);
          cmds.push({ label: ab.name, key: ab.key, tip: `<b>${ab.name}</b>${ab.ult ? ' <span class="c">(Ultimate, hero level 5)</span>' : ''}<br>${ab.desc}<br><span class="c">${ab.passive ? 'Passive' : 'Cooldown ' + ab.cooldown + 's' + (ab.range ? ' · Range ' + ab.range : '')}${ab.cost ? ' · ' + costStr(ab.cost, f) : ''}</span>`,
            disabled: !c.ok, why: c.why, cd: ab.passive ? 0 : (h.cooldowns[id] || 0) / (ab.cooldown || 1), active: inp.pending && inp.pending.kind === 'cast' && inp.pending.ability === id,
            act: () => { if (ab.passive) return; if (ab.target === 'none') g.orderCast(h, id); else inp.pending = { kind: 'cast', ability: id, caster: h }; } });
        }
      }
      return cmds;
    }
    if (buildings.length === 1) {
      const b = buildings[0];
      if (!b.complete) { cmds.push({ label: 'Cancel construction', key: 'Escape', tip: 'Refund 75% and remove', act: () => { p.refund({ p: (b.def.cost.p || 0) * 0.75, s: (b.def.cost.s || 0) * 0.75 }); g.kill(b, null); g.selection = []; } }); return cmds; }
      if (b.def.trains) for (const id of b.def.trains) {
        const d = unitDef(f, id); if (!d) continue;
        const c = g.canQueue(b, { type: 'unit', id });
        cmds.push({ label: d.name, key: d.hotkey, cost: costStr(d.cost, f), tip: `<b>${d.name}</b><br>${d.desc}<br><span class="c">${costStr(d.cost, f)} · ${d.time}s · Supply ${d.supply || 0} · Tier ${d.tier}</span><br>HP ${d.hp} · Dmg ${d.dmg} · Armor ${d.armor} · Range ${d.range} · Speed ${d.speed}`, disabled: !c.ok, why: c.why, act: () => g.enqueue(b, { type: 'unit', id }) });
      }
      if (b.def.isBase) {
        for (const id in f.heroes) {
          const d = f.heroes[id]; const c = g.canQueue(b, { type: 'hero', id });
          cmds.push({ label: '★ ' + d.name, key: d.hotkey, cost: costStr(d.cost, f), tip: `<b>${d.name}</b>, ${d.title}<br><i>${d.role} hero</i><br>${d.desc}<br><span class="c">${costStr(d.cost, f)} · ${d.time}s</span><br>Abilities: ${d.abilities.map(a => ABILITIES[a].name).join(', ')}`, disabled: !c.ok, why: c.why, act: () => g.enqueue(b, { type: 'hero', id }) });
        }
        if (p.tier < 3) { const t = f.tiers[p.tier]; const c = g.canQueue(b, { type: 'tier' }); cmds.push({ label: '▲ ' + t.name, key: 'U', cost: costStr(t.cost, f), tip: `<b>Ascend to ${t.name}</b><br>${t.desc}<br><span class="c">${costStr(t.cost, f)} · ${t.time}s · Requires ${f.buildings[t.requires].name}</span>`, disabled: !c.ok, why: c.why, act: () => g.enqueue(b, { type: 'tier' }) }); }
      }
      if (b.def.research) for (const id of b.def.research) {
        const r = f.research[id]; const c = g.canQueue(b, { type: 'research', id });
        cmds.push({ label: '⚗ ' + r.name, key: r.hotkey, cost: costStr(r.cost, f), tip: `<b>${r.name}</b><br>${r.desc}<br><span class="c">${costStr(r.cost, f)} · ${r.time}s · Tier ${r.tier}</span>`, disabled: !c.ok, why: c.why, done: p.research.has(id), act: () => g.enqueue(b, { type: 'research', id }) });
      }
      if (b.def.abilities) for (const id of b.def.abilities) {
        const ab = ABILITIES[id];
        const onCd = (b.cooldowns[id] || 0) > 0, afford = !ab.cost || p.canAfford(ab.cost);
        cmds.push({ label: ab.name + (id === 'toggle_convert' ? (b.toggles.convert ? ' (ON)' : ' (OFF)') : ''), key: ab.key, tip: `<b>${ab.name}</b><br>${ab.desc}<br><span class="c">${ab.cooldown ? 'Cooldown ' + ab.cooldown + 's' : ''}${ab.cost ? ' · ' + costStr(ab.cost, f) : ''}</span>`, disabled: onCd || !afford || !!b.relocate, why: onCd ? 'Cooldown' : 'Not enough resources', cd: (b.cooldowns[id] || 0) / (ab.cooldown || 1), active: inp.pending && inp.pending.kind === 'relocate',
          act: () => { if (id === 'relocate') inp.pending = { kind: 'relocate', building: b }; else if (ab.target && ab.target !== 'none') inp.pending = { kind: 'bcast', building: b, ability: id }; else g.buildingCast(b, id); } });
      }
      if (b.def.trains && !b.def.isBase) cmds.push({ label: 'Rally', key: 'Y', tip: 'Set rally point (or right-click with the building selected)', active: inp.pending && inp.pending.kind === 'rally', act: () => inp.pending = { kind: 'rally', building: b } });
    }
    return cmds;
  }

  renderCommands() {
    const cmds = this.buildCommands(); this.commands = cmds;
    const el = this.el.cmd;
    const sig = cmds.map(c => c.label + (c.disabled ? 'd' : '') + (c.active ? 'a' : '') + (c.done ? 'k' : '') + Math.round((c.cd || 0) * 20)).join('|');
    if (sig === this.lastSig) return; this.lastSig = sig;
    el.innerHTML = '';
    for (const c of cmds) {
      const d = document.createElement('div');
      d.className = 'cmd' + (c.disabled ? ' disabled' : '') + (c.active ? ' active' : '');
      d.innerHTML = `<span class="key">${c.key === 'Escape' ? 'Esc' : (c.key || '')}</span>${c.done ? '✔ ' : ''}${c.label}${c.cost ? `<span class="cost">${c.cost}</span>` : ''}${c.cd ? `<div class="cd" style="height:${Math.min(100, c.cd * 100)}%"></div>` : ''}`;
      d.onclick = (ev) => { ev.stopPropagation(); if (c.disabled) { if (c.why) this.g.msg(c.why, 'warn'); return; } c.act(); this.lastSig = ''; };
      d.onmouseenter = (ev) => this.showTip(c.tip + (c.disabled && c.why ? `<br><span style="color:#ff9b6a">${c.why}</span>` : ''), ev);
      d.onmousemove = (ev) => this.moveTip(ev);
      d.onmouseleave = () => this.hideTip();
      el.appendChild(d);
    }
  }

  handleKey(key) {
    const k = key.length === 1 ? key.toUpperCase() : key;
    this.commands = this.buildCommands();
    const c = this.commands.find(c => c.key === k);
    if (!c) return false;
    if (c.disabled) { if (c.why) this.g.msg(c.why, 'warn'); return true; }
    c.act(); this.lastSig = '';
    return true;
  }

  showTip(html, ev) { const t = this.el.tip; t.innerHTML = html; t.style.display = 'block'; this.moveTip(ev); }
  moveTip(ev) { const t = this.el.tip; const w = t.offsetWidth, h = t.offsetHeight; t.style.left = Math.min(window.innerWidth - w - 8, ev.clientX + 14) + 'px'; t.style.top = Math.max(4, ev.clientY - h - 12) + 'px'; }
  hideTip() { this.el.tip.style.display = 'none'; }
}
