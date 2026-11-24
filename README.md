# Skeleton Bow Macro v12

Skeleton bow turret (AI) for AutoHotkey v2 — shoots skeletons from far away using two trained tree-ensemble models.

## Hotkeys

| Key | Action |
|---|---|
| F1 | Start / stop |
| F5 | Show what the macro sees (5 s) |
| F6 | Forget what it learned while playing |
| F7 | Mark your character (mouse on character) |
| F9 | Toggle a no-shoot circle at the mouse |
| F8 | Quit |

## How to use

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Bow in hotbar slot 1 (or change `BowSlot` in the script).
3. Stand somewhere safe with the skeletons on screen and close the chat.
4. Put the mouse on your character and press **F7**.
5. Press **F5** to preview targets, then **F1** to start.

Hits are logged to `skeleton_bow_examples_v12.txt` for training the next version. Don't run this alongside the ore miner — both use the mouse.
