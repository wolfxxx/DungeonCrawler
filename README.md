# Dungeon Crawler 3D — Godot 4.5

A **3D dark-fantasy dungeon crawler** built in **Godot 4.5** using custom **Blender MCP** character/boss models, **KayKit Dungeon Remastered** 3D architecture, and **ElevenLabs** voice acting, sound effects, and dungeon music.

🎮 **Play in Browser (GitHub Pages):** **[https://wolfxxx.github.io/DungeonCrawler/](https://wolfxxx.github.io/DungeonCrawler/)**

---

## 📸 Screenshots

| Blender 3D Cast (`models/*.glb`) | Entry Hall Combat | Throne of the Abyssal Warden |
| :---: | :---: | :---: |
| ![Blender Cast](screenshots/blender_cast.png) | ![Entry Hall](screenshots/gameplay_chamber1.png) | ![Boss Chamber](screenshots/gameplay_boss_throne.png) |

---

## ⚔️ Features

- **4 Interconnected 3D Dungeon Chambers** (`80m × 20m`) with sealed wooden doors that unseal & swing open as each chamber is cleared:
  1. *I. Entry Hall of the Catacombs*
  2. *II. The Pillared Crypt*
  3. *III. Sanctum of the Obsidian Guard*
  4. *IV. Throne of the Abyssal Warden* (Boss Arena)
- **Custom Blender 3D Cast (`models/*.glb`)**:
  - **Paladin Knight** (`hero_knight.glb`) with Rune Broadsword, shield, and articulated procedural walk/slash animations.
  - **Skeleton Executioner**, **Shadow Goblin**, **Obsidian Rune Golem**, **Cultist Necromancer** (ranged arcane bolts), and **The Abyssal Warden** (final boss with 3-way Hellfire orb volleys).
- **Relic Chests & Breakable Props**:
  - Smash barrels and crates for Gold Coins and Health Elixirs.
  - Open **3 Golden Relic Chests** for permanent upgrades (*Vampiric Blade*, *Sunfire Brand*, *Dragonscale Plate*).
- **20 Custom ElevenLabs Audio Tracks (`sounds/*.mp3`)**:
  - 15 combat & environment sound effects, 4 narrator voice lines, and a looping dark-fantasy soundtrack.

---

## 🎯 Controls

- **`W` `A` `S` `D` / Arrow Keys** — Move
- **Mouse Cursor** — Aim direction
- **`Left Click` or `Space`** — 3-Hit Rune Sword Combo
- **`Right Click` or `Shift`** — Arcane Dash (with invulnerability frames)
- **`Q` or `E`** — 360° Whirlwind Arcane Nova
- **`R`** *(on Victory / Defeat screen)* — Restart run
