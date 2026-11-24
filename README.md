# Skeleton bow macro

AutoHotkey v2 script (v12) that auto-shoots skeletons with a bow in a Roblox game.
It reads the game window, finds skeletons with a small embedded decision-tree model,
leads moving targets, and tracks hits and misses.

## Keys

| Key | Action |
| --- | --- |
| F1 | Start / stop |
| F5 | Show what the macro sees for 5 seconds |
| F6 | Make the AI forget what it learned while playing |
| F7 | Mark your character (mouse on it, press F7) |
| F9 | Add / remove a no-shoot circle at the mouse |
| F8 | Quit |

## Setup

1. Put the bow in hotbar slot 1 (or change `Cfg.BowSlot`).
2. Stand somewhere safe with the skeletons on screen and close the chat.
3. Put the mouse on your character and press F7 (saved per spot / camera setup).
4. Press F5 to check detection, then F1 to start. Keep the camera still while it runs.

Settings and training examples are written next to the script (`skeleton_bow_settings.txt`, `skeleton_bow_examples_v12.txt`) and are not tracked in git.

Note: automating gameplay can break Roblox's Terms of Use and may get the account banned. Use at your own risk.
