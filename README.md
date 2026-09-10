# Roblox Luau Portfolio

A selection of production-oriented Roblox systems written in Luau. This repository contains the script layer of a Roblox game and is intended for code review as part of job applications.

## Highlights

- Server-authoritative player progression, XP, levels, rebirths, and movement
- DataStore protection with retries and safeguards against overwriting player data after failed loads
- Client/server communication through centralized remotes
- Game Pass and Developer Product purchase handling
- Item shop, inventory, cosmetics, trails, auras, perks, checkpoints, and teleportation
- Tutorial, loading screen, UI scaling, graphics, music, and HUD controllers
- Rate limiting and server-side validation for client requests

## Recommended Starting Points

| File | What it demonstrates |
| --- | --- |
| [`GameConfig.lua`](src/ReplicatedStorage/GameConfig.lua) | Shared configuration, progression formulas, and typed Luau APIs |
| [`SpeedSystem.server.lua`](src/ServerScriptService/SpeedSystem.server.lua) | Player persistence, progression, validation, autosaving, and lifecycle management |
| [`SafeStore.lua`](src/ServerScriptService/SafeStore.lua) | Defensive DataStore access with retry handling |
| [`ItemShopSystem.server.lua`](src/ServerScriptService/ItemShopSystem.server.lua) | Server-side shop and inventory logic |
| [`InventoryUI.client.lua`](src/StarterPlayer/StarterPlayerScripts/InventoryUI.client.lua) | Client UI state and inventory interaction |
| [`TutorialClient.client.lua`](src/StarterPlayer/StarterPlayerScripts/TutorialClient.client.lua) | Multi-step onboarding and client-side presentation |

## Project Structure

```text
src/
├── ReplicatedStorage/       Shared configuration, data modules, and remotes
├── ServerScriptService/     Server-authoritative gameplay and persistence
├── StarterGui/              Interface-specific client controllers
├── StarterPlayer/           Player client systems and UI controllers
└── Workspace/               Scripts attached to world gameplay objects
```

Files ending in `.server.lua` are server scripts, files ending in `.client.lua` are client scripts, and the remaining `.lua` files are modules or shared scripts.

## Running with Rojo

This repository includes a minimal [`default.project.json`](default.project.json). With [Rojo](https://rojo.space/) installed, run:

```sh
rojo serve
```

Then connect from Roblox Studio using the Rojo plugin. The original game's models, UI instances, sounds, animations, and other assets are not included, so the complete experience cannot be reproduced from this repository alone.

## Notes

- Roblox asset, Game Pass, Developer Product, and group IDs are public platform identifiers rather than credentials.
- No API keys, passwords, webhooks, or private authentication tokens are included.
- This code is published for portfolio review. Reuse or redistribution requires permission from the author.
