// Faction registry. Radiance, Sanctuary and Verdance sheets live in the Volume 1 PDF and can be added here in the same schema.
const FACTIONS = { radiance: RADIANCE, sanctuary: SANCTUARY, verdance: VERDANCE, abyss: ABYSS, tempest: TEMPEST };

function unitDef(faction, id) { return faction.units[id] || faction.heroes[id]; }
