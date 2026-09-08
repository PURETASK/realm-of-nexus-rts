# Realm of Nexus – RTS Design Bible (working docs)

Recovered from design chat transcripts (Aug 8–12, 2025; pasted Sep 4–6, 2026). This folder holds the faction mechanical sheets in the standard eight-section format:

1. Faction Summary
2. Main Base Upgrade Path
3. Resource System
4. Heroes
5. Buildings & Production
6. Defensive Structures
7. Progression Flow
8. Strengths & Weaknesses

## Faction sheet status

| Faction   | Source in this repo                                  | Status in game                                                     |
|-----------|------------------------------------------------------|--------------------------------------------------------------------|
| Abyss     | `factions/abyss.md` (Volume 1 sheet)                 | Complete, canon                                                    |
| Tempest   | `factions/tempest-v1-stormsteel.md` + `-v2-aetherium.md` | Complete; V1 names + V2 mobility hooks (see below)             |
| Radiance  | `domains-overview.md` + unified building list        | **Provisional** — canon names, invented stats/heroes/tiers         |
| Verdance  | `domains-overview.md` + building list + building specs | **Provisional** — canon names and roles, invented stats/heroes    |
| Sanctuary | `domains-overview.md` + unified building list        | **Provisional** — canon names, invented stats/heroes/tiers         |

The Volume 1 PDF ("Volume 1: Core Faction Mechanics of the Realm of Nexus RTS Design Bible") holds the finished Radiance, Sanctuary and Verdance sheets. It is not in this folder. When it arrives, replace every item marked `(invented)` or `provisional` in `js/data/radiance.js`, `verdance.js`, `sanctuary.js`.

## Unified building list (Aug 12, 2025 transcript)

The building names below are used verbatim for the three provisional factions. Items marked WIP in the source were included too.

| Domain | HQ | Production | Resource | Defense | Advanced / WIP |
|---|---|---|---|---|---|
| Verdance | Everwood Spire | Bloomforge, Verdant Sigil Hall | Groveheart Nexus (Silver Sap), Sapwood Granary | Rootwarden Bastion, Thornwall Gatehouse | Cycle Sanctuary, Sylvan Waystone, Everglen Outpost |
| Radiance | Sunforge Citadel | Solar Crucible | Sunstone Vault | Blazing Bastion, Emberline Gate | Heliarch Spire, Dawnwatch Beacon, Radiant Shrine, Solar Relay, Pyrestorm Battery |
| Sanctuary | Luminarch Citadel | Beaconwright Hall | Sanctified Vault (Sacred Crystals) | Radiant Tower, Refuge Gatehouse | Concord Hall, Eternal Bell Spire, Hall of Luminaries, Sacrosanct Shrine, Lightborne Relay |
| Abyss | Echocraft Citadel | House Forge, Mirefang Hatchery | Soul-Husk Pits (Echo Essence) | Dreadspire, Tidebreaker Bastion | Void Altar, Chasm Gate, Abyssal Obelisk, Soul-Echo Well |
| Tempest | Stormcore Nexus | Maelstrom Forge, Hurricane Docks | Skyvault (Stormglass) | Thunderclad Tower, Lightning Gate | Cyclone Spire, Tempest Relay, Stormwatch Beacon, Cloudspire Outpost |

## OPEN ISSUE 1: Abyss and Tempest have two naming schemes

The Volume 1 sheets (Aug 10) and the unified building list (Aug 12) disagree on Abyss and Tempest structure names and even resources (Soul Essence vs Echo Essence; Necropolis of Shades vs Echocraft Citadel; Stormspire Outpost vs Stormcore Nexus). **The game uses the Volume 1 names** because they come with full mechanics. Renaming is a data-only change in `js/data/abyss.js` and `tempest.js` once you decide which list is canon.

## OPEN ISSUE 2: two incompatible Tempest sheets

Two Tempest sheets were produced in separate sessions and disagree on nearly every named element.

| Element              | Version 1 (Stormsteel)                                   | Version 2 (Aetherium)                                          |
|----------------------|----------------------------------------------------------|----------------------------------------------------------------|
| Base T1 / T2 / T3    | Stormspire Outpost / Skybreaker Citadel / Maelstrom Nexus | Stormpeak Outpost / Skyborne Bastion / Stormspire Nexus        |
| Primary resource     | Stormsteel (tribute alloy)                               | Aetherium / Stormstone crystals                                |
| Secondary resource   | Aether Crystals                                          | Zephyrite Gas                                                  |
| Legendary catalyst   | Tempest Pearls                                           | Eye of the Storm (Astral Core)                                 |
| Heroes               | Rykan, Lyrian, Alyssia                                   | unnamed archetypes                                             |
| Signature mobility   | Zephyrships, base relocates slowly at T3                 | Sky Gates teleport network, base teleports at T3, Airlift      |

Resolution used in the game: V1 names, heroes and tribute economy; V2 base relocation and storm-regenerated nodes.

## Verdance building design specs (Aug 12 transcript)

Full three-tier visual specs exist for Everwood Spire, Bloomforge, Groveheart Nexus, Cycle Sanctuary, Thornwall Gatehouse and Sylvan Waystone (materials, palette, shape language, FX, sound). Their gameplay roles are implemented; the visual specs are for the art pass. Palette: deep forest greens, bark browns, luminous silver-sap highlights, floral pinks/purples on the Bloomforge.
