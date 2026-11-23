# Skeleton bow macro

AutoHotkey v2 (64-bit) script that auto-shoots skeletons with a bow in a Roblox game.
It reads the game window, finds skeletons with a small embedded decision-tree model,
leads moving targets, and tracks hits and misses.

## Keys

| Key | Action |
| --- | --- |
| F1 | Start / stop |
| F5 | Show what the macro sees for 5 seconds |
| F6 | Forget the spots it gave up on |
| F9 | Add / remove a no-shoot circle at the mouse |
| F8 | Quit |

## Setup

1. Put the bow in hotbar slot 1 (or change `Cfg.BowSlot`).
2. Roblox Settings: Camera Mode = Classic. Aim the camera at the skeletons and leave it.
3. Press F5 to check detection, then F1 to start.

Settings and the log are written next to the script (`skeleton_bow_settings_v14.txt`, `skeleton_bow_log.txt`) and are not tracked in git.

Note: automating gameplay can break Roblox's Terms of Use and may get the account banned. Use at your own risk.
