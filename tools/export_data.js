// Exports the JavaScript faction data and ability metadata to JSON for the Godot port.
//   node tools/export_data.js  ->  godot/data/factions.json, godot/data/abilities.json
const fs = require('fs'), path = require('path'), vm = require('vm');
const root = path.join(__dirname, '..');
const ctx = { console, Math, Object, Array, Set, Map, JSON, String, Number, window: {}, document: { getElementById: () => null } };
ctx.Game = function () {}; // abilities.js attaches to Game.prototype
vm.createContext(ctx);
for (const f of ['js/config.js', 'js/util.js', 'js/data/abyss.js', 'js/data/tempest.js', 'js/data/radiance.js', 'js/data/verdance.js', 'js/data/sanctuary.js', 'js/data/index.js', 'js/abilities.js', 'js/abilities_domains.js']) {
  vm.runInContext(fs.readFileSync(path.join(root, f), 'utf8') + `\n`, ctx, { filename: f });
}
const factions = vm.runInContext('JSON.parse(JSON.stringify(FACTIONS))', ctx);
const abilities = vm.runInContext(`(() => { const o = {}; for (const id in ABILITIES) { const a = ABILITIES[id]; o[id] = { name: a.name, key: a.key || '', target: a.target || 'none', range: a.range || 0, cooldown: a.cooldown || 0, desc: a.desc || '', passive: !!a.passive, ult: !!a.ult, building: !!a.building, cost: a.cost || null }; } return o; })()`, ctx);
const difficulty = vm.runInContext('JSON.parse(JSON.stringify(DIFFICULTY))', ctx);
const outDir = path.join(root, 'godot', 'data');
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'factions.json'), JSON.stringify(factions, null, 1));
fs.writeFileSync(path.join(outDir, 'abilities.json'), JSON.stringify(abilities, null, 1));
fs.writeFileSync(path.join(outDir, 'difficulty.json'), JSON.stringify(difficulty, null, 1));
console.log('factions:', Object.keys(factions).join(','), '| abilities:', Object.keys(abilities).length);
