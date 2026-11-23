; ======================================================================
;  Skeleton bow turret (AI) v15 - shoots skeletons from far away   AutoHotkey v2 (64-bit)
;
;  F1  start / stop          F5  show what the macro sees (5 seconds)
;  F6  forget the spots it gave up on
;  F9  no-shoot circle: mouse on something it must never shoot, press F9
;      (F9 again inside the circle removes it)
;  F8  quit
;
;  NEW IN v15
;    - Fixed: it got stuck on "the bow did not draw - trying again" forever
;      (your 22:04 replay: 183 shots, then 4 minutes of weak arrows and the
;      bow going in and out). The mouse had been left on the last target, so
;      the charge bar showed up there while the macro looked for it under
;      you - and its "take the bow out" key then put the bow AWAY (that key
;      toggles). Now it puts the mouse on you before every draw, reads the
;      bar wherever the mouse really is, and only presses the bow key when the
;      hotbar shows the bow is NOT in your hand (the slot in your hand has a
;      blue outline). If the bar still can't be read, it draws by the clock.
;    - Fixed: "missed one and ignored it". A skeleton it had killed (or given
;      up on) was marked dead for good - when the green "+1 Bone" belonged to
;      another skeleton, or a new one walked into the same spot, it was never
;      shot again. Now a killed spot is left alone for 1.5 s and a given-up
;      one for a while, then shot again. It also no longer lets one skeleton's
;      track steal a neighbour's.
;    - Daytime: a new AI trained on top of v14's with about 1000 daytime
;      looks from your two newest replays (doorway archer, tower archers,
;      blue-armoured ones, the ones by the tree). Tested on daytime it was not
;      taught on: shootable 97-98% of the time (v14: 82-88%). The doorway
;      archer went from 42% to 96%.
;    - Once it is sure something is a skeleton it keeps following it while it
;      half-hides (behind the tree, turning) instead of dropping it.
;    - Skeletons near the big teal crystal or water were taken for the boss's
;      "Spawns in" text and skipped - not any more.
;    - It waits while a game window (backpack, shop...) is open over the middle
;      instead of clicking into it.
;
;  v14: compiled finder (a look takes ~6 ms), reads the charge bar, ~40 shots
;  a minute, finds your character by itself, picks quick kills first, learns
;  spots behind walls, stops when the view is not your turret spot, no idle
;  kick, errors go to skeleton_bow_log.txt.
;
;  HOW TO USE
;    1. Bow in hotbar slot 1 (change BowSlot below if not).
;    2. Stand where you like (high and safe, like the wall in your replay).
;       Roblox menu (Esc) -> Settings: Camera Mode = Classic. Turn the camera
;       so the skeletons are on screen, then do not touch it. Close the chat.
;    3. Press F5: every skeleton it would shoot gets a red box with how sure
;       the AI is (in %) and a yellow dot where it aims; U = you.
;    4. Press F1. It never moves you or the camera.
;
;  Do not run this together with the ore miner or the slime macros - they
;  all use the mouse.
; ======================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Event"
SetKeyDelay 15, 25
SetMouseDelay 10
CoordMode "Mouse", "Client"
CoordMode "Pixel", "Client"
DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")

; ------------------------------ SETTINGS ------------------------------
; Distances are pixels on a 1920x1080 game window (scaled for you).
Cfg := {}

; --- bow ---
Cfg.BowSlot   := 1        ; hotbar slot of the bow
Cfg.FullDrawMs := 1000    ; the bow is fully drawn this long after the charge bar starts (measured in your replay)
Cfg.ExtraHoldMs := 60     ; hold this much longer than a full bar
Cfg.DrawMs    := 1150     ; if the charge bar cannot be seen: hold this long instead
Cfg.GapMs     := 150      ; pause after letting go before drawing the next arrow (it adjusts itself: longer if
                          ;   the game was not ready for the next draw, shorter again after 20 good draws)
Cfg.AimSettleMs := 110    ; the mouse goes onto the aim spot this long before letting go

; --- aiming ---
Cfg.LeadTargets := true    ; aim where a walking skeleton WILL be when the arrow lands
Cfg.LeadFraction := 0.9    ; how much of the walk to aim ahead (1.0 = all of it)
Cfg.MinSpeed    := 8       ; slower than this (pixels per second) counts as standing still
Cfg.LeadWindowMs := 600    ; how much of the recent walk is used to judge speed and direction
Cfg.MaxLeadPx   := 140     ; never aim further ahead than this
; arrow flight time in seconds = FlightA + FlightB * distance (spots further back
; in the picture count FlightDepth times more); fine-tuned from its own hits
Cfg.FlightA     := -0.009
Cfg.FlightB     := 0.0016
Cfg.FlightDepth := 2.4
Cfg.LearnFlight := true
Cfg.PatienceFlight := 0.8  ; for shots longer than this (seconds) at a jumpy walker: wait for a steady moment
Cfg.MaxWaitMs   := 1200    ; ...but never longer than this (the bow stays drawn meanwhile)

; --- targets ---
Cfg.MaxRangePx  := 5000   ; ignore skeletons further than this from your character (5000 = whole screen)
Cfg.MinRangePx  := 120    ; ignore things closer than this (that is you / your bow)
Cfg.MaxHitsSame := 6      ; give up on one that took this many LANDED hits and is still alive
Cfg.MaxMissesInRow := 3   ; ...or that this many arrows in a row missed (out of range, behind a wall)
Cfg.MaxShotsSame := 9     ; ...or after this many shots at it, whatever happened
Cfg.MissGiveUpSec := 12   ; after 3 misses: leave that spot alone this long (seconds)
Cfg.GiveUpSec   := 30     ; after 6 hits / 9 shots: leave it alone this long
Cfg.DecoyMinutes := 15    ; something that never moves and was missed twice in a row: leave it alone this long
Cfg.IgnoreBoss  := true   ; while the boss's health bar shows, do not shoot the boss
Cfg.BossRadius  := 190    ; ...nor anything this close to it (its body, sword and glow)
Cfg.NoShootRadius := 170  ; size of a no-shoot circle made with F9

; --- AI ---
Cfg.AIMinConfidence := 60  ; only shoot what the AI is at least this % sure is a skeleton
Cfg.AIKeepConfidence := 30 ; ...but once it is, keep following it while it is at least this % sure (behind a tree, turning)
                           ;   (raise to 70-80 if it shoots rocks, lower to 45 if it skips skeletons)

; --- you ---
Cfg.PlayerX := 965        ; your character on screen: Roblox keeps it in the middle of the window
Cfg.PlayerY := 550

; --- AFK safety ---
Cfg.StopWhenMoved := true ; stop shooting while the view is not your turret spot (you died, the camera turned)
Cfg.SameViewMin := 0.40   ; how alike the view must be to the turret view (0..1; your replay: 0.8-0.9, other spots: 0.3 or less)
Cfg.AntiIdleMin := 10     ; no shot for this many minutes: one harmless click so Roblox does not kick you as idle
Cfg.RefocusSec  := 30     ; you are away and another window took over: click Roblox back to the front after this long

; ------------------------------ STATE ---------------------------------
State := {}
State.running := false
State.busy := false
State.stop := false
State.hwnd := 0
State.phase := "idle"     ; idle -> draw -> aim -> idle
State.downAt := 0, State.barStart := 0, State.barEver := 0, State.bar0 := 0, State.failDraws := 0, State.lastBowKey := 0
State.mx := 965, State.my := 550, State.bowX := -1, State.timedLeft := 0, State.failBow := 0, State.noBarDraws := 0
State.startKeyTried := false, State.noBarFlag := false, State.menu := false, State.lastMenuChk := 0
State.gap := Cfg.GapMs, State.okDraws := 0
State.releaseAt := 0, State.nextDrawAt := 0, State.aim := 0
State.tracks := []        ; everything the AI calls a skeleton, followed from look to look
State.nextId := 1
State.cur := 0            ; the track it is shooting at
State.pending := []       ; arrows in the air
State.black := []         ; spots to leave alone: {x, y, r, until}
State.strikes := []       ; never-moving things given up on: {x, y, n, t}
State.cells := Map()      ; per 64 px square: arrows sent there and hits (spots behind walls)
State.zones := []         ; no-shoot circles (F9)
State.shots := 0, State.hits := 0, State.misses := 0, State.kills := 0, State.given := 0
State.fsNear := 1.0, State.fsFar := 1.0
State.bossUp := false, State.bossX := 0, State.bossY := 0, State.bossT := 0
State.away := false, State.awaySince := 0, State.lowSince := 0, State.highSince := 0, State.refAt := 0, State.hasRef := false
State.sim := 1.0, State.lastSim := 0
State.lastClick := 0, State.lastActivate := 0, State.startTick := 0, State.lookMs := 0, State.looks := 0
State.overlayUntil := 0, State.wantShow := false, State.wantStart := false, State.wantForget := false, State.zoneAt := 0, State.dets := [], State.inView := 0
State.lastLook := 0, State.skipped := 0

LW := 960, LH := 540      ; the macro works on a half-size copy of the picture
ROW0 := 30, ROW1 := 470   ; rows of that copy that are looked at (no top bar, no hotbar)
NF := 257, CRB := 28, MAXC := 200, MAXB := 70000
HudX := 965, HudY := 590, HudW := 90, HudH := 110       ; your character's box (never a target)
LogFile := A_ScriptDir "\skeleton_bow_log.txt"
SettingsFile := A_ScriptDir "\skeleton_bow_settings_v14.txt"     ; (same file as v14: keeps what it learned)

if (A_PtrSize != 8) {
    MsgBox("Please run this with the 64-bit AutoHotkey v2 (AutoHotkey64.exe).", "Skeleton bow", "Icon!")
    ExitApp
}
MakeStatusBar()
SetStatus("Loading the AI...")
LoadAI()
LoadSettings()
SetStatus("Bow turret v15 ready (AI: " AI.nA "+" AI.nB " trees).  Camera Mode = Classic!   F1 start   F5 show what I see   F9 no-shoot circle   F8 quit")
OnError(TurretError)
OnExit((*) => ReleaseAll())
SetTimer(Tick, 10)
SetTimer(MouseWatch, 200)

F1::ToggleRun()
F5::State.wantShow := true
F6::State.wantForget := true
F9::NoShootKey()
F8::ExitApp()

; ------------------------------ START / STOP --------------------------
ToggleRun() {
    if State.running {
        State.running := false
        State.stop := true
        ReleaseAll()
        State.phase := "idle"
        SetStatus("Stopped.  " Totals() "   F1 start   F5 show what I see   F8 quit")
        return
    }
    State.wantStart := true
}

StartRun() {
    State.hwnd := FindRoblox()
    if !State.hwnd {
        SetStatus("Roblox window not found - open the game first.")
        return
    }
    WinActivate("ahk_id " State.hwnd)
    Sleep 300
    if !Grab() {
        SetStatus("Cannot read the Roblox window.")
        return
    }
    State.stop := false
    State.phase := "idle", State.cur := 0, State.tracks := [], State.pending := [], State.black := []
    State.shots := 0, State.hits := 0, State.misses := 0, State.kills := 0, State.given := 0
    State.away := false, State.hasRef := false, State.lowSince := 0, State.highSince := 0
    State.failDraws := 0, State.nextDrawAt := 0, State.timedLeft := 0, State.failBow := 0, State.noBarDraws := 0
    State.startKeyTried := false, State.noBarFlag := false
    State.startTick := A_TickCount, State.lastClick := A_TickCount, State.looks := 0
    if (SelSlotX() < 0) {                     ; nothing in your hand: take the bow out
        Send "{" Cfg.BowSlot "}"
        State.lastBowKey := A_TickCount
        State.startKeyTried := true
        Sleep 400
        LogLine("nothing in hand at the start - pressed " Cfg.BowSlot)
    }
    ParkMouse()
    State.running := true
    LogLine("started")
}

FindRoblox() {
    for exe in ["RobloxPlayerBeta.exe", "Windows10Universal.exe"] {
        h := WinExist("ahk_exe " exe)
        if h
            return h
    }
    return 0
}

ReleaseAll() {
    if GetKeyState("LButton")
        Click "Up"
}

; Safety: a button the macro pressed is never left held (your own clicks are left alone).
MouseWatch() {
    if (GetKeyState("LButton") && !GetKeyState("LButton", "P") && (!State.running || State.phase = "idle")
        && A_TickCount - State.lastClick > 1500 && A_TickCount - State.lastLook > 400)
        Click "Up"
}

; Any error: write it down, let go of the button and carry on (no message box that stops it).
TurretError(e, mode) {
    ReleaseAll()
    State.phase := "idle"
    LogLine("error: " e.Message " (" e.What ", line " e.Line ")")
    return 1
}

LogLine(t) {
    try {
        if (FileExist(LogFile) && FileGetSize(LogFile) > 300000)
            FileDelete(LogFile)
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "  " t "`n", LogFile)
    }
}

; ------------------------------ MAIN LOOP -----------------------------
Tick() {
    if State.busy
        return
    State.busy := true
    try {
        if State.wantStart {
            State.wantStart := false
            StartRun()
        }
        if State.wantForget {
            State.wantForget := false
            ForgetSpots()
        }
        if State.zoneAt {
            z := State.zoneAt
            State.zoneAt := 0
            ToggleNoShoot(z[1], z[2])
        }
        if State.wantShow {
            State.wantShow := false
            ShowWhatISee()
        }
        if State.running
            Step()
    } catch as e {
        ReleaseAll()
        State.phase := "idle"
        LogLine("error: " e.Message " (" e.What ", line " e.Line ")")
        Sleep 200
    }
    State.busy := false
}

Step() {
    if (A_TickCount < State.overlayUntil)
        return
    if !WinExist("ahk_id " State.hwnd) {
        State.running := false
        ReleaseAll()
        SetStatus("Roblox closed - stopped.  " Totals())
        LogLine("Roblox closed")
        return
    }
    if !WinActive("ahk_id " State.hwnd) {
        if (State.phase != "idle") {
            ReleaseAll()
            State.phase := "idle"
        }
        if (A_TimeIdlePhysical > Cfg.RefocusSec * 1000 && A_TickCount - State.lastActivate > 30000) {
            State.lastActivate := A_TickCount
            try WinActivate("ahk_id " State.hwnd)
            LogLine("clicked Roblox back to the front")
        }
        SetStatus("Paused - Roblox is not the active window (it clicks back in by itself after " Cfg.RefocusSec " s if you are away).")
        Sleep 100
        return
    }
    t0 := A_TickCount
    if !Look()
        return
    State.lookMs := A_TickCount - t0
    PlaceStatusBar()
    now := State.grabTick

    if State.away {
        if (State.phase != "idle") {
            Click "Up"
            State.phase := "idle"
        }
        SetStatus("NOT SHOOTING - this is not your turret view (died? camera moved?)  view match " Round(State.sim * 100)
            . "%  - waiting for it to come back" StatTail())
        return
    }
    if State.menu {
        if (State.phase != "idle") {
            Click "Up"
            State.phase := "idle"
        }
        SetStatus("a game window is open over the middle - waiting until it is closed" StatTail())
        return
    }
    if (State.phase = "idle")
        PhaseIdle(now)
    else if (State.phase = "draw")
        PhaseDraw(now)
    else if (State.phase = "aim")
        PhaseAim(now)
}

; ---- bow not drawn: pick the next skeleton and start drawing ----
PhaseIdle(now) {
    if (now < State.nextDrawAt)
        return
    tgt := PickTarget(now, 0)
    if !tgt {
        if (A_TickCount - State.lastClick > Cfg.AntiIdleMin * 60000) {
            ParkMouse()                       ; one harmless shot at your feet: Roblox sees you are not idle
            Click "Down"
            Sleep 120
            Click "Up"
            State.lastClick := A_TickCount
            LogLine("anti-idle click")
        }
        if State.skipped
            SetStatus(State.skipped " skeleton(s) left alone for a moment (just killed / gave up for a while / too close / no-shoot)" StatTail())
        else if State.inView
            SetStatus("skeleton(s) seen - making sure they are real" StatTail())
        else
            SetStatus("no skeleton in view" StatTail())
        return
    }
    State.cur := tgt
    State.bar0 := BarLength(Cfg.PlayerX, Cfg.PlayerY)   ; anything white there before the draw
    ParkMouse()                               ; always draw with the mouse on you: the bar shows up right under it
    Click "Down"
    State.noBarFlag := false
    State.phase := "draw"
    State.downAt := A_TickCount
    State.barStart := 0
    State.lastClick := A_TickCount
    State.waitNote := ""
}

; ---- bow being drawn: follow the target, read the charge bar, aim at the end ----
PhaseDraw(now) {
    t := A_TickCount
    L := BarLength(State.mx, State.my)        ; the bar sits right under the mouse, wherever it is
    if (L >= State.bar0 + 3 && L <= 40) {    ; the bar grows 44 px in FullDrawMs
        est := t - L / 44 * Cfg.FullDrawMs
        if !State.barStart {                  ; this draw started fine
            State.okDraws += 1
            if (State.okDraws >= 20)
                State.gap := Max(State.gap - 25, 100), State.okDraws := 0
            State.timedLeft := 0, State.failBow := 0
            if (State.bowX < 0 || Mod(State.barEver, 25) = 0) {   ; learn where the bow's slot is lit
                sx := SelSlotX()
                if (sx >= 0)
                    State.bowX := sx
            }
        }
        State.barStart := State.barStart ? State.barStart * 0.6 + est * 0.4 : est
        State.barEver += 1
    } else if (L > 40 && !State.barStart) {
        State.barStart := t - Cfg.FullDrawMs
    }
    if (!State.barStart && !State.timedLeft && State.barEver >= 3 && State.bar0 < 20 && t - State.downAt > 450) {
        ; the bar was always there before, but not this time: the draw did not start
        Click "Up"
        State.phase := "idle"
        State.nextDrawAt := t + 250
        State.failDraws += 1
        State.gap := Min(State.gap + 50, 600), State.okDraws := 0
        DrawFailed(t)
        return
    }
    if (!State.barStart && State.barEver < 3 && t - State.downAt > 600 && !State.noBarFlag) {
        ; no charge bar seen yet since starting: is anything in your hand?
        State.noBarFlag := true
        State.noBarDraws += 1
        sx := (State.noBarDraws >= 2) ? SelSlotX() : 0
        if ((State.noBarDraws >= 2 && sx < 0) || (State.noBarDraws >= 4 && !State.startKeyTried)) {
            Click "Up"
            State.phase := "idle"
            Send "{" Cfg.BowSlot "}"
            State.startKeyTried := true
            State.lastBowKey := t, State.nextDrawAt := t + 600, State.noBarDraws := 0
            LogLine("no charge bar since starting (" (sx < 0 ? "nothing in hand" : "maybe another tool") ") - pressed " Cfg.BowSlot)
            SetStatus("taking the bow out" StatTail())
            return
        }
    }
    if State.barStart
        State.failDraws := 0
    fullAt := State.barStart ? State.barStart + Cfg.FullDrawMs + Cfg.ExtraHoldMs : State.downAt + Cfg.DrawMs

    cur := State.cur
    if (cur && (now < cur.ign || GiveUpNow(cur) || now - cur.seen > 450 || BossZone(cur.x, cur.y) || InNoShoot(cur.x, cur.y))) {
        nt := PickTarget(now, cur)            ; the bow stays drawn meanwhile
        State.cur := cur := nt
    } else if !cur {
        State.cur := cur := PickTarget(now, 0)
    }
    if (t < fullAt - Cfg.AimSettleMs) {
        SetStatus("drawing  (" (cur ? "shot " (cur.shots + 1) " at this one, " cur.hits " landed, AI " Round(cur.score * 100) "% sure" : "looking for a target") ")" StatTail())
        return
    }
    if !cur {
        if (t > fullAt + 4000) {              ; nothing to shoot for 4 s with the bow drawn: let go at your feet
            Click "Up"
            State.phase := "idle"
            State.nextDrawAt := t + State.gap
        }
        SetStatus("bow drawn - waiting for a skeleton" StatTail())
        return
    }
    if !TargetReady(cur, now)
        return
    if (!Steady(cur) && t < fullAt + Cfg.MaxWaitMs) {
        SetStatus("bow drawn - waiting for a steady moment (long shot at a walking skeleton)" StatTail())
        return
    }
    a := AimPoint(cur, t + Cfg.AimSettleMs)
    if (BossZone(a.x, a.y) || InNoShoot(a.x, a.y) || Hud(a.x, a.y)) {
        State.black.Push({x: cur.x, y: cur.y, r: 30, until: now + 5000})
        State.cur := 0
        return
    }
    base := TextCounts(a.x, a.y)              ; the clean picture, before the crosshair moves there
    AimAt(a.x, a.y)
    State.aim := {x: a.x, y: a.y, f: a.f, fBase: a.fBase, lead: a.lead, o0: base.orange, g0: base.green, target: cur}
    State.phase := "aim"
    State.releaseAt := t + Cfg.AimSettleMs
}

; ---- mouse on the aim spot: let go ----
PhaseAim(now) {
    if (A_TickCount < State.releaseAt)
        return
    Click "Up"
    tRel := A_TickCount
    State.lastClick := tRel
    a := State.aim
    cur := a.target
    cur.shots += 1
    State.shots += 1
    if (State.timedLeft > 0)
        State.timedLeft -= 1
    State.lastLead := Round(a.lead)
    State.pending.Push({t: tRel, x: a.x, y: a.y, f: a.f, fBase: a.fBase, o0: a.o0, g0: a.g0, target: cur, hitAt: 0})
    CellAdd(a.x, a.y, 1, 0)
    ParkMouse()                               ; off the target right away: a clean view on the next look
    State.phase := "idle"
    State.nextDrawAt := tRel + State.gap
}

StatTail() {
    el := (A_TickCount - State.startTick) // 1000
    mins := Max(el / 60, 0.25)
    return "  |  in view " State.inView "  |  " Totals() "  |  " Round(State.shots / mins) " shots/min, " Round(State.kills / mins, 1) " kills/min"
        . (State.bossUp ? "  |  boss up: ignored" : "")
        . "  |  " (el // 60) "m" Format("{:02}", Mod(el, 60)) "s " State.lookMs "ms"
}

Totals() => "shots " State.shots "  hit " State.hits "  missed " State.misses "  kills " State.kills "  gave up " State.given

; ------------------------------ LOOKING -------------------------------
; One look: the picture, every skeleton the AI sees, the arrows in the air,
; and (twice a second) whether this is still the turret view.
Look() {
    if !Grab()
        return false
    now := State.grabTick
    MouseGetPos(&mx, &my)                     ; where the mouse really is (the charge bar is drawn under it)
    State.mx := mx * 1920 / State.cw, State.my := my * 1080 / State.ch
    dets := Detect(true)
    State.dets := dets
    nHi := 0
    for d in dets
        nHi += d.hi
    State.inView := nHi
    State.looks += 1
    State.lastLook := A_TickCount
    CheckShots(now)
    if (State.phase != "aim")                 ; (while aiming the game's crosshair sits on the target)
        UpdateTracks(dets, now)
    if (now - State.lastSim >= 500)
        ViewCheck(now)
    if (now - State.lastMenuChk >= 300)
        State.menu := MenuOpen(), State.lastMenuChk := now
    return true
}

; A game window (backpack, shop, ...) open over the middle? Its dark blue panel then
; fills the centre of the screen - no shooting (the clicks would land on its buttons).
MenuOpen() {
    p := State.pBits
    n := 0, hit := 0
    y := 100
    while (y < 430) {
        x := 240
        while (x < 720) {
            c := NumGet(p + (y * LW + x) * 4, "uint")
            r := (c >> 16) & 255, g := (c >> 8) & 255, b := c & 255
            if (Abs(r - 30) <= 8 && Abs(g - 34) <= 8 && Abs(b - 62) <= 10)
                hit += 1
            n += 1
            x += 4
        }
        y += 4
    }
    return hit * 4 > n
}

; Same place as when it started? (edges of a small grey picture compared)
ViewCheck(now) {
    State.lastSim := now
    if !Cfg.StopWhenMoved
        return
    if !State.hasRef {
        DllCall("RtlMoveMemory", "ptr", AI.thumb.Ptr + 32400, "ptr", AI.thumb.Ptr, "uptr", 32400)
        State.hasRef := true, State.refAt := now
        return
    }
    h := AI.H
    n := NumGet(h, 80, "double"), sa := NumGet(h, 88, "double"), sb := NumGet(h, 96, "double")
    sab := NumGet(h, 104, "double"), saa := NumGet(h, 112, "double"), sbb := NumGet(h, 120, "double")
    va := saa - sa * sa / n, vb := sbb - sb * sb / n
    s := (va > 0 && vb > 0) ? (sab - sa * sb / n) / Sqrt(va * vb) : 0
    State.sim := s
    if (s < Cfg.SameViewMin) {
        State.highSince := 0
        if !State.lowSince
            State.lowSince := now
        if (!State.away && now - State.lowSince > 3000) {
            State.away := true, State.awaySince := now
            State.cur := 0, State.tracks := []
            ReleaseAll()
            State.phase := "idle"
            LogLine("view is not the turret spot any more (match " Round(s * 100) "%) - stopped shooting")
        }
    } else {
        State.lowSince := 0
        if State.away {
            if !State.highSince
                State.highSince := now
            if (now - State.highSince > 2000 && s >= Cfg.SameViewMin + 0.1) {
                State.away := false
                LogLine("turret view is back (match " Round(s * 100) "%) - shooting again")
            }
        }
        if (s >= 0.72 && now - State.refAt > 60000) {     ; follow day and night slowly
            DllCall("RtlMoveMemory", "ptr", AI.thumb.Ptr + 32400, "ptr", AI.thumb.Ptr, "uptr", 32400)
            State.refAt := now
        }
    }
}

; ------------------------------ FOLLOWING SKELETONS -------------------
; Every detection is joined to the track it continues (nearest to where that
; track should be by now). A track only counts as a skeleton once it has
; been seen for a quarter of a second and does not fly like an arrow.
UpdateTracks(dets, now) {
    tr := State.tracks
    ; every (track, detection) pair that is close enough, nearest first - so a
    ; track can never take a neighbour's detection just because it came first
    pairs := []
    for ti, o in tr {
        dt := (now - o.seen) / 1000
        p := MotionAt(o, now)
        gate := Min(26 + 170 * dt, 120)
        lowOk := (now - o.hiSeen <= 1500 && now >= o.ign)
        for di, d in dets {
            if (!d.hi && !lowOk)
                continue
            dd := Dist(d.x, d.y, p.x, p.y)
            if (dd <= gate)
                pairs.Push({k: dd - (o = State.cur ? 6 : 0), t: ti, d: di})
        }
    }
    SortPairs(pairs)
    usedT := Map(), usedD := Map()
    for q in pairs {
        if (usedT.Has(q.t) || usedD.Has(q.d))
            continue
        usedT[q.t] := true, usedD[q.d] := true
        AddSample(tr[q.t], now, dets[q.d])
    }
    for i, d in dets {
        if (!usedD.Has(i) && d.hi)            ; a new track only from a sure one
            tr.Push(NewTrack(d, now))
    }
    i := tr.Length
    while (i >= 1) {
        o := tr[i]
        if (now - o.seen > (o = State.cur ? 1500 : 800)) {
            if (o.hits >= 1 && !o.counted) {       ; it was hit and is gone: killed
                o.counted := true
                State.kills += 1
            }
            tr.RemoveAt(i)
        }
        i -= 1
    }
}

; Few pairs (a handful of skeletons): a simple insertion sort by distance.
SortPairs(a) {
    i := 2
    while (i <= a.Length) {
        v := a[i], j := i - 1
        while (j >= 1 && a[j].k > v.k) {
            a[j + 1] := a[j]
            j -= 1
        }
        a[j + 1] := v
        i += 1
    }
}

; ign = left alone until then (just killed, or given up on for a while) - a
; track is never dropped for good: whatever is still standing there gets shot again later.
NewTrack(d, t) {
    o := {id: State.nextId, x: d.x, y: d.y, cx: d.x, cy: d.y, fx: d.x, fy: d.y, h: d.h, n: d.n, score: d.score
        , hist: [], first: t, seen: t, hiSeen: t, moved: 0, shots: 0, hits: 0, missRow: 0, ign: 0, counted: false}
    State.nextId += 1
    o.hist.Push({t: t, x: d.x, y: d.y})
    o.m := {x: d.x, y: d.y, t: t, vx: 0, vy: 0, res: 0}
    return o
}

AddSample(o, t, d) {
    o.hist.Push({t: t, x: d.x, y: d.y})
    while (o.hist.Length > 2 && t - o.hist[1].t > 1600)
        o.hist.RemoveAt(1)
    o.seen := t, o.n := d.n, o.h := d.h
    if d.hi
        o.hiSeen := t
    o.score := o.score * 0.7 + d.score * 0.3
    o.x := d.x, o.y := d.y
    o.moved := Max(o.moved, Dist(d.x, d.y, o.fx, o.fy))
    o.m := Motion(o)
}

; Seen long enough, and not flying like an arrow?
Confirmed(o, now) {
    if (o.hist.Length < 3 || now - o.first < 250 || now - o.hiSeen > 1500)
        return false
    h1 := o.hist[1], h2 := o.hist[o.hist.Length]
    dt := Max((h2.t - h1.t) / 1000, 0.05)
    return Dist(h1.x, h1.y, h2.x, h2.y) / dt < 300
}

TargetReady(cur, now) => (now >= cur.ign && cur.hist.Length >= 2 && now - cur.seen <= 300)

; Fine to let go now? Short shots: always. Long shots: only when the skeleton
; stands still or walks steadily (a jumpy walk can't be predicted that far).
Steady(cur) {
    m := cur.m
    if (m.vx = 0 && m.vy = 0)
        return true
    return (FlightBase(m.x, m.y) * FlightScale(m.y) < Cfg.PatienceFlight || m.res <= 2.5)
}

; Learned correction of the flight time: one for nearer spots, one for the far back.
FlightScale(y) {
    wf := Clamp((Cfg.PlayerY - y - 100) / 200, 0, 1)
    return (1 - wf) * State.fsNear + wf * State.fsFar
}

; Where it is and how fast it walks: a straight line fitted through the last
; LeadWindowMs of looks. Slower than MinSpeed counts as standing still.
Motion(o) {
    tr := o.hist
    last := tr[tr.Length]
    n := 0, st := 0, sx := 0, sy := 0
    for s in tr {
        if (last.t - s.t <= Cfg.LeadWindowMs)
            n += 1, st += s.t, sx += s.x, sy += s.y
    }
    if (n < 2)
        return {x: last.x, y: last.y, t: last.t, vx: 0, vy: 0, res: 0}
    tm := st / n, mx := sx / n, my := sy / n
    stt := 0, stx := 0, sty := 0, t1 := last.t
    for s in tr {
        if (last.t - s.t <= Cfg.LeadWindowMs) {
            d := s.t - tm
            stt += d * d, stx += d * (s.x - mx), sty += d * (s.y - my)
            t1 := Min(t1, s.t)
        }
    }
    if (n < 3 || last.t - t1 < 250 || stt <= 0)
        return {x: mx, y: my, t: last.t, vx: 0, vy: 0, res: 0}
    vx := stx / stt * 1000, vy := sty / stt * 1000            ; pixels per second
    se := 0
    for s in tr {
        if (last.t - s.t <= Cfg.LeadWindowMs) {
            ex := s.x - (mx + vx * (s.t - tm) / 1000), ey := s.y - (my + vy * (s.t - tm) / 1000)
            se += ex * ex + ey * ey
        }
    }
    res := Sqrt(se / n)
    sp := Sqrt(vx * vx + vy * vy)
    if (sp < Cfg.MinSpeed || !Cfg.LeadTargets)
        return {x: mx, y: my, t: last.t, vx: 0, vy: 0, res: res}
    if (sp > 200)
        vx := vx * 200 / sp, vy := vy * 200 / sp
    return {x: mx + vx * (last.t - tm) / 1000, y: my + vy * (last.t - tm) / 1000, t: last.t, vx: vx, vy: vy, res: res}
}

MotionAt(o, tAt) {
    m := o.m
    dt := (tAt - m.t) / 1000
    return {x: m.x + m.vx * dt, y: m.y + m.vy * dt}
}

; How long an arrow flies to this spot.
FlightBase(x, y) {
    dx := x - Cfg.PlayerX, dy := y - Cfg.PlayerY
    if (dy < 0)
        dy := dy * Cfg.FlightDepth
    return Clamp(Cfg.FlightA + Cfg.FlightB * Sqrt(dx * dx + dy * dy), 0.3, 2.0)
}

; The mouse position at release: where the skeleton will be when the arrow lands.
AimPoint(cur, tRel) {
    m := cur.m
    dtNow := Max(0, (tRel - m.t) / 1000)
    fb := FlightBase(m.x, m.y)
    f := fb * FlightScale(m.y)
    T := (dtNow + f) * Cfg.LeadFraction
    lx := m.vx * T, ly := m.vy * T
    L := Sqrt(lx * lx + ly * ly)
    if (L > Cfg.MaxLeadPx)
        lx := lx * Cfg.MaxLeadPx / L, ly := ly * Cfg.MaxLeadPx / L, L := Cfg.MaxLeadPx
    return {x: Round(m.x + lx), y: Round(m.y + ly), f: f, fBase: fb, lead: L}
}

; ------------------------------ WHICH ONE ------------------------------
; The skeleton that is quickest to kill: short flight, standing still, already
; wounded, the AI sure - and not where its arrows keep missing. The one it is
; already shooting at stays first while it can be seen.
PickTarget(now, old) {
    best := 0, bestCost := 1.0e9
    State.skipped := 0
    for o in State.tracks {
        if (o = old || now - o.seen > 150 || !Confirmed(o, now))
            continue
        d := Dist(o.x, o.y, Cfg.PlayerX, Cfg.PlayerY)
        if (now < o.ign || d > Cfg.MaxRangePx || d < Cfg.MinRangePx || IsBlack(o.x, o.y) || BossZone(o.x, o.y) || InNoShoot(o.x, o.y)) {
            State.skipped += 1
            continue
        }
        m := o.m
        sp := Sqrt(m.vx * m.vx + m.vy * m.vy)
        cost := FlightBase(o.x, o.y) * (sp >= Cfg.MinSpeed ? 1 + Min(sp, 80) / 80 : 1)
        cost += CellPenalty(o.x, o.y)
        cost -= (o.hits >= 1 ? 0.5 : 0) + (o.score - 0.6)
        if (o = State.cur)
            cost -= 5
        if (cost < bestCost)
            best := o, bestCost := cost
    }
    return best
}

IsBlack(x, y) {
    now := A_TickCount
    i := State.black.Length
    while (i >= 1) {
        b := State.black[i]
        if (now > b.until)
            State.black.RemoveAt(i)
        else if (Dist(x, y, b.x, b.y) < b.r)
            return true
        i -= 1
    }
    return false
}

; Arrows sent to and hits in each 64 x 64 px square (older ones count less).
CellAdd(x, y, shots, hits) {
    k := (Floor(x / 64)) "_" (Floor(y / 64))
    c := State.cells.Has(k) ? State.cells[k] : (State.cells[k] := {s: 0.0, h: 0.0, t: A_TickCount})
    f := 0.5 ** ((A_TickCount - c.t) / 600000)          ; halves every 10 minutes
    c.s := c.s * f + shots, c.h := c.h * f + hits, c.t := A_TickCount
}

CellPenalty(x, y) {
    k := (Floor(x / 64)) "_" (Floor(y / 64))
    if !State.cells.Has(k)
        return 0
    c := State.cells[k]
    if (c.s < 3)
        return 0
    return 1.5 * (1 - Min(1, c.h / c.s))
}

; ------------------------------ SHOOTING ------------------------------
; Roblox only takes a new mouse spot after a small real move - without the
; nudge its crosshair (and the white charge bar) stay where they were.
ParkMouse() {
    MouseMove Round(Cfg.PlayerX * State.cw / 1920), Round(Cfg.PlayerY * State.ch / 1080), 0
    MouseMove 1, 0, 0, "R"
    MouseMove -1, 0, 0, "R"
}

AimAt(rx, ry) {
    MouseMove Round(rx * State.cw / 1920), Round(ry * State.ch / 1080), 0
    MouseMove 1, 0, 0, "R"
    MouseMove -1, 0, 0, "R"
}

; Length of the white charge bar just under the mouse at (rx, ry), 0..44 px.
BarLength(rx, ry) {
    p := State.pBits
    best := 0
    xs := Max(Floor((rx - 30) / 2), 0), xe := Min(Floor((rx + 30) / 2), LW - 1)
    y := Max(Floor((ry + 30) / 2), 0), ye := Min(Floor((ry + 48) / 2), LH - 1)
    while (y <= ye) {
        run := 0, x := xs
        while (x <= xe) {
            c := NumGet(p + (y * LW + x) * 4, "uint")
            if (((c >> 16) & 255) > 215 && ((c >> 8) & 255) > 215 && (c & 255) > 215) {
                run += 1
                if (run > best)
                    best := run
            } else {
                run := 0
            }
            x += 1
        }
        y += 1
    }
    return best * 2
}

; The hotbar slot in your hand has a bright blue outline. Left edge of that outline
; (1920-wide scale), or -1 when no slot is lit (nothing in your hand).
SelSlotX() {
    p := State.pBits
    y0 := Floor(LH * 0.86)
    x := LW // 4
    while (x < LW * 3 // 4) {
        run := 0, y := y0
        while (y < LH) {
            c := NumGet(p + (y * LW + x) * 4, "uint")
            r := (c >> 16) & 255, g := (c >> 8) & 255, b := c & 255
            if (b > 190 && g > 140 && b - r > 70 && r < 170) {
                run += 1
                if (run >= 24)
                    return x * 2
            } else {
                run := 0
            }
            y += 1
        }
        x += 1
    }
    return -1
}

; No charge bar this time. Is the bow in your hand at all?
;  - no slot lit / another slot lit: press the bow's key (only then - pressing it with the
;    bow already in hand would put the bow AWAY)
;  - the bow's slot is lit: the bow is out, the bar just was not where it was looked for -
;    after 2 of those, draw by the clock (FullDrawMs) for the next 15 shots
DrawFailed(t) {
    sx := SelSlotX()
    if (State.bowX < 0) {                     ; never saw which slot is the bow (hotbar hidden?)
        State.failBow += 1
        if (State.failBow >= 2) {
            State.timedLeft := 15, State.failBow := 0
            LogLine("no charge bar - timing the draws for a while")
        }
        SetStatus("the bow did not draw - trying again" StatTail())
        return
    }
    if (sx < 0 || Abs(sx - State.bowX) > 10) {
        if (t - State.lastBowKey > 1500) {
            Send "{" Cfg.BowSlot "}"
            State.lastBowKey := t
            State.nextDrawAt := t + 500
            LogLine("the bow was not in hand (" (sx < 0 ? "nothing" : "another slot") " selected) - pressed " Cfg.BowSlot)
        }
        SetStatus("the bow was not in your hand - took it out" StatTail())
        return
    }
    State.failBow += 1
    if (State.failBow >= 2) {
        State.timedLeft := 15, State.failBow := 0
        LogLine("bow in hand but no charge bar under the mouse - timing the draws for a while")
    }
    SetStatus("the bow did not draw - trying again" StatTail())
}

; ---- did the arrow land? ----
; Damage numbers are salmon / orange, a kill shows a green "+1 Bone": both pop
; up just above the spot the arrow went to. No number by the time the arrow
; should be there = a miss.
TextCounts(x, y) {
    x1 := Max(Floor((x - 50) / 2), 0), x2 := Min(Floor((x + 50) / 2), LW - 1)
    y1 := Max(Floor((y - 80) / 2), 0), y2 := Min(Floor((y + 15) / 2), LH - 1)
    NumPut("int", 0, "int", 0, "int", x1, "int", y1, "int", x2, "int", y2, AI.P2)
    NumPut("int", 1, AI.P2, 60)
    DllCall(AI.code, "ptr", State.pBits, "ptr", AI.P2, "ptr", AI.K, "ptr", AI.lab, "ptr", AI.stk, "ptr", AI.blk
        , "ptr", AI.B, "ptr", AI.C, "ptr", AI.F, "ptr", AI.H2, "ptr", AI.MI, "ptr", AI.MD, "ptr", AI.roots, "ptr", AI.NR
        , "ptr", AI.bias, "ptr", AI.thumb, "int")
    return {orange: NumGet(AI.H2, 0, "double"), green: NumGet(AI.H2, 8, "double")}
}

CheckShots(now) {
    prevLook := State.HasOwnProp("prevLookT") ? State.prevLookT : now
    State.prevLookT := now
    i := 1
    while (i <= State.pending.Length) {
        s := State.pending[i]
        if (now - s.t < 250) {
            i += 1
            continue
        }
        c := TextCounts(s.x, s.y)
        res := ""
        if (c.green >= s.g0 + 12)
            res := "kill"
        else if (s.hitAt && now - s.hitAt > 350)
            res := "hit"
        else if (!s.hitAt && c.orange >= s.o0 + 5)
            s.hitAt := (prevLook > s.t ? (now + prevLook) / 2 : now)
        else if (!s.hitAt && now > s.t + s.f * 1000 + 450)
            res := "miss"
        if res {
            ShotResult(s, res, now)
            State.pending.RemoveAt(i)
        } else {
            i += 1
        }
    }
}

ShotResult(s, res, now) {
    t := s.target
    if (res = "miss") {
        t.missRow += 1
        State.misses += 1
        return
    }
    t.hits += 1, t.missRow := 0
    State.hits += 1
    CellAdd(s.x, s.y, 0, 1)
    ; learn how long arrows really fly (only from clean hits)
    meas := ((s.hitAt ? s.hitAt : now) - s.t) / 1000
    if (Cfg.LearnFlight && meas > 0.3 && meas < 2.5 && s.fBase > 0) {
        r := Clamp(meas / s.fBase, 0.7, 1.5)
        wf := Clamp((Cfg.PlayerY - s.y - 100) / 200, 0, 1)
        State.fsNear := Clamp(State.fsNear + 0.2 * (1 - wf) * (r - State.fsNear), 0.7, 1.5)
        State.fsFar := Clamp(State.fsFar + 0.2 * wf * (r - State.fsFar), 0.7, 1.5)
        if (A_TickCount - (State.HasOwnProp("savedAt") ? State.savedAt : 0) > 60000) {
            State.savedAt := A_TickCount
            SaveSettings()
        }
    }
    t.hitsEver := true
    if (res = "kill" && A_TickCount >= t.ign) {
        ; "+1 Bone" over it: killed. Leave the spot for 1.5 s (it falls apart, the
        ; bone drops) - if it is still standing after that (the green text was
        ; another skeleton's), it simply gets shot again.
        State.kills += 1
        t.ign := A_TickCount + 1500
        t.shots := 0, t.hits := 0, t.missRow := 0, t.counted := false
        State.black.Push({x: s.x, y: s.y, r: 25, until: now + 1500})     ; ignore the bits it leaves for a moment
        State.black.Push({x: t.x, y: t.y, r: 25, until: now + 1500})
    }
}

; 6 landed hits and still alive, 3 misses in a row (out of range, behind a
; wall...), or far too many shots: leave that spot alone for a while.
; Something that never moves and is given up on twice without a single hit
; (an arrow stuck in the grass...) is left alone for DecoyMinutes.
GiveUpNow(cur) {
    if (A_TickCount < cur.ign)
        return false
    if (cur.hits < Cfg.MaxHitsSame && cur.missRow < Cfg.MaxMissesInRow && cur.shots < Cfg.MaxShotsSame)
        return false
    now := A_TickCount
    secs := Cfg.GiveUpSec, rad := 30
    if (cur.missRow >= Cfg.MaxMissesInRow && !cur.HasOwnProp("hitsEver")) {
        secs := Cfg.MissGiveUpSec, rad := 25
        if (cur.moved <= 10) {
            st := 0
            for o in State.strikes {
                if (Dist(o.x, o.y, cur.x, cur.y) < 30 && now - o.t < 1200000) {
                    st := o
                    break
                }
            }
            if st {
                st.n += 1, st.t := now
            } else {
                st := {x: cur.x, y: cur.y, n: 1, t: now}
                State.strikes.Push(st)
            }
            if (st.n >= 2) {
                secs := Cfg.DecoyMinutes * 60
                LogLine("left a never-moving thing alone at " cur.x "," cur.y)
            }
        }
    }
    State.black.Push({x: cur.x, y: cur.y, r: rad, until: now + secs * 1000})
    State.given += 1
    ; left alone for that long - wherever it walks meanwhile - then a fresh start
    cur.ign := now + secs * 1000
    cur.shots := 0, cur.hits := 0, cur.missRow := 0
    LogLine("gave up on the skeleton at " Round(cur.x) "," Round(cur.y) " for " secs " s")
    return true
}

ForgetSpots() {
    State.black := [], State.strikes := [], State.cells := Map()
    SetStatus("Forgot the spots it gave up on.")
}

Dist(x1, y1, x2, y2) => Sqrt((x1 - x2) ** 2 + (y1 - y2) ** 2)
Clamp(v, lo, hi) => Max(lo, Min(hi, v))
InRect(x, y, x1, y1, x2, y2) => (x >= x1 && x < x2 && y >= y1 && y < y2)

; The game's own buttons and lists, and your character.
Hud(x, y) {
    return InRect(x, y, 1600, 0, 1920, 310) || InRect(x, y, 20, 370, 110, 770) || InRect(x, y, 1620, 830, 1920, 960)
        || InRect(x, y, 0, 0, 320, 70) || x < 30 || x > 1890 || y > 1040
        || InRect(x, y, HudX - HudW, HudY - HudH, HudX + HudW, HudY + HudH)
}

; ------------------------------ BOSS / NO-SHOOT -----------------------
; Near the boss? While its health bar shows, nothing within BossRadius of it
; (its body, its long sword, its glow) is shot. Its spot is kept for a few
; seconds when it cannot be seen for a moment.
BossZone(x, y) {
    return (Cfg.IgnoreBoss && State.bossUp && State.bossT && A_TickCount - State.bossT < 6000
        && Dist(x, y, State.bossX, State.bossY) <= Cfg.BossRadius)
}

InNoShoot(x, y) {
    for z in State.zones {
        if (Dist(x, y, z.x, z.y) <= z.r)
            return true
    }
    return false
}

MouseInGame(&gx, &gy) {
    if !State.hwnd
        State.hwnd := FindRoblox()
    if !State.hwnd
        return false
    try
        WinGetClientPos(&wx, &wy, &ww, &wh, "ahk_id " State.hwnd)
    catch
        return false
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    CoordMode "Mouse", "Client"
    gx := Round((mx - wx) * 1920 / ww), gy := Round((my - wy) * 1080 / wh)
    return true
}

NoShootKey() {
    if !MouseInGame(&gx, &gy) {
        SetStatus("Roblox window not found.")
        return
    }
    State.zoneAt := [gx, gy]
}

ToggleNoShoot(gx, gy) {
    for i, z in State.zones {
        if (Dist(gx, gy, z.x, z.y) <= z.r) {
            State.zones.RemoveAt(i)
            SaveSettings()
            SetStatus("No-shoot circle removed (" State.zones.Length " left).")
            return
        }
    }
    State.zones.Push({x: gx, y: gy, r: Cfg.NoShootRadius})
    SaveSettings()
    SetStatus("No-shoot circle added at " gx "," gy " (" State.zones.Length " in all). F9 inside it again removes it.")
}

SaveSettings() {
    t := "fsNear=" Round(State.fsNear, 4) "`nfsFar=" Round(State.fsFar, 4) "`n"
    for z in State.zones
        t .= "zone=" z.x "," z.y "," z.r "`n"
    try {
        if FileExist(SettingsFile)
            FileDelete(SettingsFile)
        FileAppend(t, SettingsFile)
    }
}

LoadSettings() {
    if !FileExist(SettingsFile)
        return
    try {
        for line in StrSplit(FileRead(SettingsFile), "`n", "`r") {
            kv := StrSplit(line, "=")
            if (kv.Length != 2)
                continue
            if (kv[1] = "fsNear")
                State.fsNear := Clamp(Number(kv[2]), 0.7, 1.5)
            else if (kv[1] = "fsFar")
                State.fsFar := Clamp(Number(kv[2]), 0.7, 1.5)
            else if (kv[1] = "zone") {
                q := StrSplit(kv[2], ",")
                if (q.Length = 3)
                    State.zones.Push({x: Number(q[1]), y: Number(q[2]), r: Number(q[3])})
            }
        }
    }
}

; ------------------------------ SCREEN READING ------------------------
InitCapture() {
    bi := Buffer(40, 0)
    NumPut("uint", 40, "int", LW, "int", -LH, "ushort", 1, "ushort", 32, bi)
    hdcScr := DllCall("GetDC", "ptr", 0, "ptr")
    State.hdcMem := DllCall("CreateCompatibleDC", "ptr", hdcScr, "ptr")
    pBits := 0
    State.hbm := DllCall("CreateDIBSection", "ptr", hdcScr, "ptr", bi, "uint", 0, "ptr*", &pBits, "ptr", 0, "uint", 0, "ptr")
    DllCall("SelectObject", "ptr", State.hdcMem, "ptr", State.hbm, "ptr")
    DllCall("SetStretchBltMode", "ptr", State.hdcMem, "int", 3)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScr)
    State.pBits := pBits
}

; Copies the game picture (half size) into memory.
Grab() {
    if !State.hwnd
        return false
    try
        WinGetClientPos(&wx, &wy, &ww, &wh, "ahk_id " State.hwnd)
    catch
        return false
    if (ww < 300 || wh < 200)
        return false
    State.cx := wx, State.cy := wy, State.cw := ww, State.ch := wh
    if !State.HasOwnProp("pBits")
        InitCapture()
    hdcScr := DllCall("GetDC", "ptr", 0, "ptr")
    DllCall("StretchBlt", "ptr", State.hdcMem, "int", 0, "int", 0, "int", LW, "int", LH
        , "ptr", hdcScr, "int", wx, "int", wy, "int", ww, "int", wh, "uint", 0x00CC0020)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScr)
    State.grabTick := A_TickCount
    return true
}

; ------------------------------ THE FINDER ----------------------------
; SkeletonCodeHex below is the compiled skeleton finder: the light, every
; skeleton-like patch, the AI's 257 numbers for each and both sets of trees,
; the boss and the small picture of the view. It keeps no numbers of its own:
; they come in K.
LoadAI() {
    global AI
    AI := {}
    hex := SkeletonCodeHex()
    len := StrLen(hex) // 2
    AI.code := DllCall("VirtualAlloc", "ptr", 0, "uptr", len, "uint", 0x3000, "uint", 0x40, "ptr")
    if !AI.code {
        MsgBox("Could not set up the AI (no memory).", "Skeleton bow", "Icon!")
        ExitApp
    }
    loop len
        NumPut("uchar", Integer("0x" SubStr(hex, 2 * A_Index - 1, 2)), AI.code, A_Index - 1)
    kv := [0.0, 1.0, 2.0, 64.0, -2.0, 2.5, 50.0, 10.0, 200.0, 32.0, 4.0, 3.0, 20.0, 8.0, 140.0, -1000000000.0, Ln(0.25)]
    AI.K := Buffer(kv.Length * 8, 0)
    for v in kv
        NumPut("double", v, AI.K, (A_Index - 1) * 8)
    AI.P := Buffer(16 * 4, 0)
    AI.lab := Buffer(LW * LH * 2, 0)
    AI.stk := Buffer(LW * LH * 4, 0)
    AI.blk := Buffer(120 * 68 * 4, 0)
    AI.B := Buffer(MAXB * 20 * 4, 0)
    AI.C := Buffer(MAXC * CRB * 8, 0)
    AI.F := Buffer(MAXC * NF * 8, 0)
    AI.H := Buffer(16 * 8, 0)
    AI.P2 := Buffer(16 * 4, 0), AI.H2 := Buffer(16 * 8, 0)      ; for counting damage numbers
    AI.thumb := Buffer(2 * 32400, 0)
    ; both models: nodes "feature:threshold:left:right" or "~leaf value", numbered within each model
    ta := Tokens(ModelAText()), tb := Tokens(ModelBText())
    nA := ta.Length, nn := nA + tb.Length
    AI.MI := Buffer(nn * 12, 0), AI.MD := Buffer(nn * 16, 0)
    PutNodes(ta, 0)
    PutNodes(tb, nA)
    ra := StrSplit(ModelARoots(), " "), rb := StrSplit(ModelBRoots(), " ")
    AI.roots := Buffer((ra.Length + rb.Length) * 4, 0)
    for r in ra
        NumPut("int", Integer(r), AI.roots, (A_Index - 1) * 4)
    for r in rb
        NumPut("int", Integer(r) + nA, AI.roots, (ra.Length + A_Index - 1) * 4)
    AI.NR := Buffer(8, 0), AI.bias := Buffer(16, 0)
    NumPut("int", ra.Length, "int", rb.Length, AI.NR)
    NumPut("double", ModelABase(), "double", ModelBBase(), AI.bias)
    AI.nA := ra.Length, AI.nB := rb.Length
}

Tokens(text) {
    out := []
    for tk in StrSplit(text, " ")
        if (tk != "")
            out.Push(tk)
    return out
}

; Node i of a model goes to slot off + i; its children are numbered within the model too.
PutNodes(toks, off) {
    for tk in toks {
        o := off + A_Index - 1
        if (SubStr(tk, 1, 1) = "~") {
            NumPut("double", Number(SubStr(tk, 2)), AI.MD, o * 16 + 8)
        } else {
            q := StrSplit(tk, ":")
            NumPut("int", Integer(q[1]), "int", Integer(q[3]) + off, "int", Integer(q[4]) + off, AI.MI, o * 12)
            NumPut("double", Number(q[2]), AI.MD, o * 16)
        }
    }
}

; Everything the AI calls a skeleton (at least AIMinConfidence % sure), with
; the spot to aim at: across at its solid core (never out on the sword), up and
; down between the core and the middle of the figure = the chest.
Detect(withThumb) {
    NumPut("int", ROW0, "int", ROW1, "int", HudX, "int", HudY, "int", HudW, "int", HudH, "int", MAXC, "int", MAXB
        , "int", Cfg.IgnoreBoss ? 1 : 0, "int", 1, "int", withThumb ? 1 : 0, "int", 0, "int", 0, "int", 0
        , "int", (withThumb && State.hasRef) ? 1 : 0, "int", 0, AI.P)
    n := DllCall(AI.code, "ptr", State.pBits, "ptr", AI.P, "ptr", AI.K, "ptr", AI.lab, "ptr", AI.stk, "ptr", AI.blk
        , "ptr", AI.B, "ptr", AI.C, "ptr", AI.F, "ptr", AI.H, "ptr", AI.MI, "ptr", AI.MD, "ptr", AI.roots, "ptr", AI.NR
        , "ptr", AI.bias, "ptr", AI.thumb, "int")
    h := AI.H
    State.light := NumGet(h, 8, "double") "/" NumGet(h, 16, "double") "/" NumGet(h, 24, "double")
    State.bossUp := NumGet(h, 32, "double") > 0
    if (State.bossUp && NumGet(h, 40, "double") > 0)
        State.bossX := NumGet(h, 48, "double"), State.bossY := NumGet(h, 56, "double"), State.bossT := A_TickCount
    out := []
    loop n {
        c := AI.C.Ptr + (A_Index - 1) * CRB * 8
        ra := NumGet(c, 96, "double"), rb := NumGet(c, 104, "double")
        pa := 1 / (1 + Exp(-Clamp(ra, -30, 30)))
        p := (rb < -100000000) ? pa / 2 : (pa + 1 / (1 + Exp(-Clamp(rb, -30, 30)))) / 2
        if (p * 100 < Cfg.AIKeepConfidence || NumGet(c, 112, "double") > 0)    ; (teal above: the boss timer text)
            continue
        cx := NumGet(c, 0, "double"), cy := NumGet(c, 8, "double"), ccx := NumGet(c, 16, "double"), ccy := NumGet(c, 24, "double")
        nc := NumGet(c, 88, "double")
        d := {score: p, cx: cx, cy: cy, w: NumGet(c, 64, "double"), h: NumGet(c, 72, "double"), n: NumGet(c, 80, "double"), nc: nc
            , x1: NumGet(c, 32, "double"), y1: NumGet(c, 40, "double"), x2: NumGet(c, 48, "double"), y2: NumGet(c, 56, "double")
            , blue: NumGet(c, 136, "double") > 0, hi: p * 100 >= Cfg.AIMinConfidence}
        if (nc >= 2)
            d.x := Round(ccx), d.y := Round((ccy + cy) / 2)
        else
            d.x := Round(cx), d.y := Round(cy)
        if (BossZone(d.x, d.y) || BossZone(cx, cy) || InNoShoot(d.x, d.y) || Hud(d.x, d.y))
            continue
        out.Push(d)
    }
    ; a thin piece (sword, arm) next to a solid body: keep only the body -
    ; unless it is a second small skeleton standing beside it
    res := []
    for c in out {
        if (c.nc < 2) {
            body := false
            for o in out {
                if (o != c && o.nc >= 2 && (o.hi || !c.hi) && Dist(o.x, o.y, c.x, c.y) <= 40 && !Twin(c, o)) {
                    body := true
                    break
                }
            }
            if body
                continue
        }
        res.Push(c)
    }
    return res
}

Twin(c, o) => (c.h * 10 >= o.h * 7 && c.h * 10 >= c.w * 8 && Abs(c.y - o.y) <= o.h * 2 * 6 // 10 + 2
    && Abs(c.x - o.x) >= c.w + o.w)

; ------------------------------ STATUS BAR / F5 -----------------------
MakeStatusBar() {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")
    g.BackColor := "101418"
    g.MarginX := 0, g.MarginY := 0
    g.SetFont("s9 cFFD24A", "Consolas")
    State.txt := g.Add("Text", "x8 y4 w904 h18", "")
    g.Show("x320 y4 w920 h26 NoActivate")
    WinSetTransparent(235, g)
    State.bar := g
    State.barPos := ""
}

PlaceStatusBar() {
    if !State.HasOwnProp("cx")
        return
    pos := (State.cx + Round(320 * State.cw / 1920)) "," (State.cy + 4)
    if (pos != State.barPos) {
        State.barPos := pos
        State.bar.Show("x" (State.cx + Round(320 * State.cw / 1920)) " y" (State.cy + 4) " NoActivate")
    }
}

SetStatus(t) {
    static last := ""
    if (t != last) {
        last := t
        State.txt.Value := t
    }
}

; F5: red box = a skeleton it would shoot (number = how sure the AI is, %),
;     yellow dot = where it aims, grey "skip" = left alone for a while,
;     U = you. Arrows in flight and new things count only after a moment.
ShowWhatISee() {
    if !State.hwnd
        State.hwnd := FindRoblox()
    if (!State.hwnd || !Grab()) {
        SetStatus("Roblox window not found.")
        return
    }
    if (State.running && State.phase != "idle") {
        Click "Up"
        State.phase := "idle"
    }
    if WinActive("ahk_id " State.hwnd)
        ParkMouse()
    ; look for half a second so that tracks can confirm
    t0 := A_TickCount
    while (A_TickCount - t0 < 500) {
        if !Look()
            break
        Sleep 15
    }
    PlaceStatusBar()
    if State.HasOwnProp("ov") && State.ov {
        State.ov.Destroy()
        State.ov := 0
    }
    sxf := State.cw / 1920, syf := State.ch / 1080
    ov := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")
    ov.BackColor := "010203"
    ov.MarginX := 0, ov.MarginY := 0
    ov.SetFont("s8 bold c000000", "Consolas")
    shown := 0, now := State.grabTick
    for o in State.tracks {
        if (now - o.seen > 150 || !Confirmed(o, now))
            continue
        d := Dist(o.x, o.y, Cfg.PlayerX, Cfg.PlayerY)
        ok := (d <= Cfg.MaxRangePx && d >= Cfg.MinRangePx && !IsBlack(o.x, o.y) && now >= o.ign)
        ax := Round(o.x * sxf), ay := Round(o.y * syf)
        ov.Add("Text", "x" (ax - 14) " y" (ay - 30) " w28 h14 Center Background" (ok ? "FF3030" : "888888"), ok ? Round(o.score * 100) : "skip")
        ov.Add("Text", "x" (ax - 3) " y" (ay - 3) " w6 h6 BackgroundFFE000")
        shown += ok ? 1 : 0
    }
    for z in State.zones
        ov.Add("Text", "x" (Round(z.x * sxf) - 30) " y" (Round(z.y * syf) - 7) " w60 h14 Center Background888888", "NO SHOOT")
    if BossZone(State.bossX, State.bossY)
        ov.Add("Text", "x" (Round(State.bossX * sxf) - 45) " y" (Round(State.bossY * syf) - 7) " w90 h14 Center Background30D0D0", "BOSS: NO SHOOT")
    ov.Add("Text", "x" (Round(Cfg.PlayerX * sxf) - 7) " y" (Round(Cfg.PlayerY * syf) - 7) " w14 h14 Center Background40FF40", "U")
    ov.Show("x" State.cx " y" State.cy " w" State.cw " h" State.ch " NoActivate")
    WinSetTransColor("010203", ov)
    State.ov := ov
    State.overlayUntil := A_TickCount + 5200
    SetStatus("I see " shown " skeleton(s): red = how sure the AI is (%), yellow dot = where it aims"
        . (State.bossUp ? "  |  boss up: ignored" : "") "  |  light " State.light
        . "  |  charge bar " (State.barEver ? "seen" : "not seen yet") "  |  " State.lookMs " ms a look  |  U = you")
    SetTimer(HideOverlay, -5000)
}

HideOverlay() {
    if State.HasOwnProp("ov") && State.ov {
        State.ov.Destroy()
        State.ov := 0
    }
}

; ------------------------------ THE AI'S DATA ----------------------------
; The compiled finder (13530 bytes) and two sets of decision trees (300 + 300) trained on
; 192418 examples (skeleton / not) cut from all your clips (night and day), darker / brighter / sunset copies
; and copies worked out with a wrong light tint; the second set gives every clip equal say.
; Generated - do not edit by hand.
SkeletonCodeHex() {
    s := ""
    s .= "4157415641554154555756534881EC780100008B420C837A3C0148898C24C00100004C8B9C24080200008984242C0100008B421448899424C80100004C898424D00100004C898C24D8010000898424300100000F29B424500100000F29BC24600100000F"
    s .= "84CD010000488B8424C8010000488B8C24D0010000498D93800000008B400889842434010000488B8424C8010000448B7810448B70188B401C89842428010000488B8424C80100008B4024898424F0000000488B8424C80100008B008984242401000048"
    s .= "8B8424C80100008B4004898424000100004C89D8F20F10014883C008F20F1140F84839C275EE488B8424E00100004C8DA800040000C700000000004883C008C740FC000000004939C575EA8B84240001000083F8280F8E4F02000083E829488BBC24C001"
    s .= "000031DBBEABAAAAAAC1E8024C8B8424E00100004889C24C8D8F0067020048C1E2044829C248C1E20A488D841700A30200498D8900F1FFFF4989C4660F1F8400000000008B0189C20FB6FCC1EA100FB6D28D6A0C39FD7D21440FB6D0418D6A0C39FD7D15"
    s .= "01FA83C3014401D2480FAFD648C1EA2141830490014883C1104939C975C24981C1003C00004C89E04D39CC75A083FB320F8EAC010000488B8424E0010000448B00438D040039C37E37B801000000EB034889D0483D000100000F843D320000488BBC24E0"
    s .= "010000488D500144030487438D0C0039D97CD983F81D0F8FB9310000C78424E000000055000000BF1E00000041BA64000000C78424880000005A000000E95D0100008BBC242C0100008B9C243001000039DF0F8F5E320000448B52088B72104863D74889"
    s .= "D048C1E0044829D048C1E0084801C889D929F9488BBC24C00100004801D14889CA48C1E2044829CA31C948C1E208488DAC17000F000031D24989EF4139F20F8F820000004963FAEB2E83FD6E7E4981FDC70000007F1981FB950000007F114129E94531C0"
    s .= "4183F928410F9FC04401C14883C70139FE7C4F8B1CB84189D90FB6EF0FB6DB41C1E9104189E8450FB6C94181F9CD0000007FB24181F8C800000076CF4589C44529CC4183FC3C7EC34129D84183F850410F9FC04883C701450FB6C04401C239FE7DB14805"
    s .= "000F00004939C70F8566FFFFFF660FEFC04531E4F20F2AC1F2410F1103660FEFC0F20F2AC2F2410F1143080F28B424500100000F28BC24600100004489E04881C4780100005B5E5F5D415C415D415E415FC3C78424E000000055000000BF3200000041BA"
    s .= "64000000C78424880000005A000000488BB424E00100004C89E8488D96000C0000C700000000004883C004C780FC070000000000004839C275E78BB424240100008B8C240001000039CE0F8D280100004863D6488B9C24C001000044897C24084531E448"
    s .= "89D048C1E0044829D069D6C003000048C1E008488D9C03000F00008D41FF29F081C2000F0000BEABAAAAAAC1E80269C0000F000001D044897424104C8D8B00F1FFFF660F1F440000418B094189C80FB6ED0FB6C941C1E810450FB6C0458D34284101CE4C"
    s .= "0FAFF649C1EE214539D67C78458D70F64139CE7F6F4139E84189EF4189EE450F4EF84139CF440F4FF94139E8450F4DF04139CE440F4CF14529FE4183FE507F444181FFF90000007F3B4429C14C8BBC24E00100004183C40181C1000100004863C9418344"
    s .= "8D000189E94429C181C1000100004863C94183848F000C000001660F1F4400004983C1104C39CB0F8553FFFFFF448B7424104881C3003C000039D00F84F50C000081C2000F0000E922FFFFFFC744245000000000C744244800000000488B8424C8010000"
    s .= "8B582C85DB74168B403089442448488B8424C80100008B403489442450660FEFC089F8F20F2AC08B442448F2410F114308660FEFC0F20F2AC08B442450F2410F114310660FEFC0F20F2AC0488B8424D8010000488D9000D20F00F2410F1143184531C945"
    s .= "31D24883C00466448948FC66448950FE4839C275E7488B8424E8010000488D90807F0000C700000000004883C008C740FC000000004839C275EA8BB424240100008B84240001000039C60F8DA22E00004863D669CEC00300008D1CFD0000000089B42420"
    s .= "0100004889D0BDABAAAAAA899C241001000048C1E0044C899C24080200004829D0BACDCCCCCC898C24EC000000C78424140100000000000048C1E00848038424C001000048898424F80000004863C1488B8C24D8010000C78424E800000000000000488D"
    s .= "0C4189D8480FAFC248C1E82381FB610200004889C289842404010000B83C0000000F4FC2898424380100008BB42420010000B80B02000048898C24C800000089BC244401000039C648898C24480100000F4EC64489B424400100004C8BB424C001000044"
    s .= "89BC243C01000083C01069C0C003000089842418010000B81000000039C60F4DC669C0C00300008984241C01000031C04989C7660F1F840000000000488B8424C8000000668338000F85730D0000488B8424F80000008B7C2450428B14B889D00FB6CE0F"
    s .= "B6D2C1E8104189CB4189D24189CD0FB6C04129FB8B7C2448448D04014489DB4101D04129FA29C34589C04489D7895C24184C89C64C0FAFC529C749C1E82139C14C894424104189C0440F4DC14139D0440F4CC239C144894424244189C0440F4EC14139D0"
    s .= "440F4FC24129C54589C44189D04129C04181FCFB0000004489442408410F9EC1448B4424104439842488000000410F9EC04520C80F846A1A00008D5F0F83FB4B0F87AA1A00008B5C241883C30F83FB2F0F879A1A00004139C289C3410F4DDA4439DB410F"
    s .= "4CDB4139C2440F4FD04539DA450F4FD34429D383FB3C0F8F701A0000C744242000000000BB010000000F1F8000000000448D47D84531D24183F8417733448B5C2418458D43F44183F8217724456BDB64446BC71C4539C37C17448B942438010000443954"
    s .= "2410410F9DC2450FB6D26690448B8424F00000004585C00F954424700FB67C24704584C90F84DA0B00004084FF0F84D10B00008B7C2408448D47304183F83A0F87971B0000448B5C241044399C24E00000000F8F841B0000458D451EC744241800000000"
    s .= "4183F8230F86661C00008B7C2408448D477D4183F86D0F878C0B000081FE760100000F8E800B0000458D45424183F8420F87720B000039D10F8C6A0B000029D129D06BC9648D04808D048039C10F8C550B0000C7442418010000000F1F440000B8100000"
    s .= "008BB424EC0000004589FC8B8C241C0100004139C7448B9C2418010000410F4DC78D4406F04898458B0486410FB6C04589C589442428B8AF03000041C1ED104139C7450FB6ED410F4EC78D4406104898418B1486428D843900C4FFFF4898418B04860FB6"
    s .= "F289D70FB6D689742430C1EF108944242489C64489C0400FB6FF0FB6C401FA0FB64C2424C1EE104189C08B442428400FB6F64501E8894C2438438D0C3B4101C08B4424304863C94C0FAFC5418B0C8E01C28B442424480FAFD54189CB440FB6C949C1E821"
    s .= "0FB6C441C1EB1001F0450FB6DB48C1EA214401C2448B4424384401C0480FAFC548C1E82101D00FB6D54401DA4401CA480FAFD548C1EA2101D08B542420C1F80285D20F84131800008B5424106BC8648D1492C1E20339D10F8FFE1700006B4C24106469D0"
    s .= "820000004585D20F84221A000039D10F9DC10FB6C9894C24184189C88B5424288B5C24304529D9448B5424384429EA29FB01D34129F24101DA4501D10F88FD19000041C1F9028B54240831C94429CA83FA180F9FC14409C10F84CD09000083FA180F8EAA"
    s .= "1A000005E903000089C28BBC24EC0000004589F889C14869D2D34D62104C89742428448BAC24240100004589E24101F8488BBC24E0010000838424E8000000018BB424E8000000C78424D00000000000000048C1EA26448907488BBC24C800000069D2E8"
    s .= "0300006689B424DC0000004C8BB424E8010000668937C78424C00000000000000029D18D9018FCFFFFC78424B8000000000000008D71FFC78424B0000000000000008B8C242001000089B424A400000031F681FAE7030000400F96C63DCF07000089CAC7"
    s .= "8424AC000000000000000F9FC031FFC78424A8000000000000000FB6C089BC2484000000898424D80000004C89BC2408010000448BBC240001000089B424D400000031F60F1F8400000000004D63D84489C389742424488B7C24284969C389888888C1FB"
    s .= "1F838424A8000000014C89B424E801000048C1E8204401C0C1F8094189C129D8018424D00000004129D94169F1C00300004129F04589C14189C044018C24C000000041C1F8034489CB456BC078C1FB034101D84D63C04383048601468B1C9F8B7C244844"
    s .= "89DE4489DB450FB6DBC1EE100FB6DF400FB6F6448D041E4501D84129FB8B7C24504C0FAFC54129F344019C24B000000029FB448D58028D78FF29F38BB42484000000019C24B800000049C1E82144018424AC0000004439C6440F4DC64539CC450F4FE145"
    s .= "39CA450F4CD139C144898424840000004589D80F4FC839C24489A424980000000F4CD0418D410244899424A000000069DFC00300008944241089942490000000898C249C0000004139FD0F8FB70400004139FF0F8EAE04000044897C2478458D59FF4489"
    s .= "4C247C897C2440448984248000000044896C24744189DD4181FBBF0300000F8750040000438D441D00488BB424D80100008944246048984C8D34466641833E000F852E040000488B7C24288B7424508B5C24488B148789D00FB6CE0FB6D2C1E81089CF41"
    s .= "89D20FB6C029F789D6448D040829DE4189FF458D0C1089F34129C74D89C84C0FAFCD29C344897C245849C1E92139C84D89CC44894C24304189C9440F4DC84139D1440F4CCA39C844894C24644189C9440F4EC84139D1440F4FCA4129C244895424084189"
    s .= "CA4129C24181F9FB0000004589CF4489542438410F9EC24439A42488000000410F9EC14520D10F8468050000448D630F4183FC4B0F87B2050000448B6424584183C40F4183FC2F0F879F05000039F04189F4440F4DE04139FC440F4CE739F00F4EF039FE"
    s .= "0F4FF74129F44183FC3C0F8F78050000C744242000000000C744241801000000448D4BD831FF4183F94177448B742458448D4EF44183F9217736446BCE646BDB1C4139D97C2A8BBC241001000041B93C00000081FF62020000440F4D8C240401000031FF"
    s .= "44394C2430400F9DC70F1F00807C2470000F848D0400004584D20F84840400008B742408448D4E304183F93A0F878A0500008B5C2430399C24E00000000F8F790500008B7424384531E4448D4E1E4183F9230F86EF1400008B742408448D4E7D4183F96D"
    s .= "0F873D0400004181F8760100000F8E30040000448B4424384183C0424183F8420F871D04000039D10F8C1504000029D129D06BC9648D04808D048039C10F8C0004000041BC010000000F1F8000000000B8100000004C8B7C2428448B5424404139C3410F"
    s .= "4DC3418D4405F04898458B04874489C0410FB6F0C1E810897424580FB6C089442438B8AF0300004139C3410F4EC3418D4405104898418B1487B81000000089D60FB6CA0FB6D6C1EE104139C2894C2464B90B020000410F4DC2400FB6F683E81069C0C003"
    s .= "00004401D84898418B04874189C141C1E9104139CA410FB6D9410F4ECA01F2440FB6C8895C24684489C30FB6C40FB6DF83C1104189D88B5C243869C9C00300004101D88B5C24584401D94101D88B5C24644863C94C0FAFC5418B0C8F01DA8B5C2468480F"
    s .= "AFD54189CA440FB6F949C1E82101D841C1EA104401C8450FB6D2480FAFC548C1EA214401C248C1E82101D00FB6D58B4C24204401D24401FA480FAFD548C1EA2101D0C1F80285C90F84070300008B5C24306BC8648D149BC1E20339D10F8FF20200006B4C"
    s .= "24306469D08200000085FF0F84C71000004531E439D1410F9DC44489E28B7C24388B4C24584529D729F98B7C246429F78B74246801CF4129F14101F94501F90F88A310000041C1F9028B4C24084531C04429C983F918410F9FC04109D00F846502000083"
    s .= "F9180F8E2A13000005E903000089C289C10FB7B424DC0000004869D2D34D6210664189368BB424A400000048C1EA2669D2E803000029D18D9018FCFFFF81FAE70300008D740EFF8B4C24600F96C289B424A4000000488BB424E00100000FB6D2019424D4"
    s .= "0000003DCF0700000F9FC00FB6C0018424D80000004863442424890C868D4001894424240F1F40008B4424104183C3014139C30F8592FBFFFF4489EB448B7C24788B7C2440448B4C247C448B842480000000448B6C247483C70181C3C00300004439C70F"
    s .= "852EFBFFFF8B742424448BA424980000008B9424900000008B8C249C000000448B9424A00000004C8BB424E801000085F60F8E151100008B742424488BBC24E001000083EE014863C6448B0487E9BAF9FFFF448B7C24084183FC1D0F8E07F3FFFF418D44"
    s .= "24FF4531C941D1FC4531D2D1F841B8F1D8FFFF89C6EB0E904983C1014981F900020000743E488B8C24E0010000428B8489000400004401D04189C239F07E174181F8F1D8FFFF418D9100FFFFFF0F94C184C9440F45C24439E07EBD478D840800FFFFFF45"
    s .= "31D231DB41B9F1D8FFFFEB150F1F8400000000004983C2014981FA00020000743C488B8C24E0010000428B8491000C000001D889C339C67D174181F9F1D8FFFF418D9200FFFFFF0F94C184C9440F45CA4139C47DBF478D8C1100FFFFFFC7442448000000"
    s .= "004183F8FF7C12C74424482D0000004183F85B0F8E9E1C0000C7442450FBFFFFFF4183F9F50F8C21F2FFFFC7442450140000004183F9290F8F0FF2FFFF4489C8C1E81F4401C8D1F889442450E9FBF1FFFF0F1F80000000004531E48B4424188B74242009"
    s .= "F009F84409E00F85F8FBFFFFBFFFFFFFFF6641893EE91AFEFFFF6690C744242000000000C744241800000000E9DBFAFFFF0F1F008B54241885D20F8502FDFFFF4585E40F84030E00006B4C24306469D08200000085FF0F855310000039D17CAC83C00105"
    s .= "D0070000E948FDFFFF0F1F80000000004181F8390200000F8E430D0000837C2408D80F8C400E00008B7C2438448D4F0F4183F92F0F87BD0D0000837C24083C0F8FB20D0000448B4C246431F64529F94183F93C400F9EC6410F9FC1897424184181F8A301"
    s .= "00007E094584C90F858E0D0000837C2408D87C1E4584C974198B742438448D4E194183F919770B837C24080A0F8EC50F0000C744242000000000E905FAFFFF0F1F4400004531E4E994FAFFFFC7442418000000008B44242009D84409D00B4424180F85A5"
    s .= "F4FFFF488B8424C800000041B8FFFFFFFF6644890048838424C8000000044983C7024981FFC00300000F8561F2FFFF488B8C24480100008384242001000002448BBC243C010000448BB424400100008BBC24440100008B8424200100004881C1000F0000"
    s .= "818424EC0000008007000048818424F8000000001E0000398424000100007E1181BC24E8000000E7FD00000F8E86F1FFFF8BB42414010000660FEFC04C8B9C240802000089F0F20F2AC08B8424E8000000F2410F114340660FEFC0F20F2AC0F2410F1143"
    s .= "4885F60F8E5F1F00008B842434010000488BB424F00100004531E44531ED4429F848984889442408486306486356304C6346344C8D0C85000000004801D24889C14D8D14014D01C04F8D149249C1E2064C39D27C1C4989C249C1E2044929C249C1E2074C"
    s .= "39D27D094D85C00F89911900004D8D140149C1E2024C39D27C254C6BD06E4C39D27D1C4C69D0720100004D39D07C104C69D0020300004D39D00F8C800100004C69D0540600004C39D27C2F4989C249C1E2044929C24C89D348C1E3074839DA7D194869D8"
    s .= "3E0300004939D87C0D49C1E2064D39D00F8C450100004C89C34809D378104901C149C1E1064C39CA0F8C5F0F00004989C149C1E1044929C14D01C94C39CA0F8C170100004C69C8620700004C39CA0F8F070100004C8B4C24084C0FAFC84C39CA7C3B8B9C"
    s .= "2434010000468D0C3B4D63C94C0FAFC84C39CA7D248B9C242C010000448B94243001000089DA4429D24863D2480FAFD04939D00F8D141E00008B56082B56048B461083C2012B460C83C00183FA220F8FA300000083F8280F8F9A000000448D41FB4181F8"
    s .= "EF0100000F87890000008D14928D048001D28D44801E39C27F798B4620446B462C648D1C8999F7F9BA0100000085C00F4FD06B6E24644489C0C1E3034189D19941F7F94189C14189C24489C099F7FF4181F9950000000F9FC23DA9000000410F9FC04184"
    s .= "D0750839DD0F8C18180000458D91E803000039DD450F4CD1488B8C24E00100004963C4448956484183C40144892C814183C5014883C6504439AC24140100000F85EFFDFFFF4539F47E704183FC017E67488B9424E00100004C8B8C24F0010000458D5424"
    s .= "FF4531C0428B4C82048D0489C1E0024898418B6C81484C89C0EB11897482044883E80183F8FF0F84E30D00008B34828D1CB6C1E3024863DB41396C99487CDC83C0014898488D04824983C00189084D39C275B14589F44585E40F8EDE0F0000488B842428"
    s .= "020000488B9C24E00100004489BC24D80000004C8B8C2400020000488B8C24F80100004C899C24080200008B304963C448895C2428488D04834C894C24304C8B8424D001000048898424B80000004963C5488B9C2410020000488D048089B42498000000"
    s .= "48C1E00448038424F00100004489A424DC00000048898424900000004863C6488BB4242002000048898424C00000004C8BA424C0010000488D0486488944246889F84889CF488B8C2418020000898424D00000008B442448898424C80000008B44245089"
    s .= "8424D4000000488B442428660FEFD2660FEFC0660FEFC9488BB424F00100008B008D0480C1E0024898488D34868B5608448B4E04448B5E10448B7E0C89D0448B168B6E3844894C24104429C8895424244589FE8984248800000083C001F2410F2AC28944"
    s .= "247C4489D84429F844897C247483C00144895C2478894424588B463001C0F20F2AD08B463401C0F20F2AC8F20F5ED0F20F5EC84539DF0F8FC1150000418D4301C744242000000000448D5A01894424384963C14569FFC0030000C744240800000000C744"
    s .= "24180000000048894424408B542424395424100F8FA2000000488B5424404585F64963C7410F9FC54801D0488B9424D8010000488D04428B542410EB130F1F800000000083C2014883C0024439DA746B440FB7084139E975EB4584ED74E6440FB78880F8"
    s .= "FFFF4139E975D94181FE1A0200007FD0440FB788800700004139E975C385D27EBF440FB748FE4139E975B581FABE0300007FAD440FB748024139E975A30154240883C2014883C002834424180144017424204439DA75958B4424384183C6014181C7C003"
    s .= "00004139C60F8538FFFFFF8B54241885D20F84DF0E0000B864000000660FEFFF660FEFE439C2F20F2AE2660FEFDB0F4EC2894424648B44240801C0F20F2AF88B44242001C0F20F2AD8F20F5EFCF20F5EDC8B4614448B5E2CC744246000000000C7442440"
    s .= "000000009944899C248000000041F7FA894424708B46209941F7FABA0100000085C00F4FD08B46184189D79941F7FA8984249C0000008B461C9941F7FA898424A0000000416BC3649941F7FF898424A4000000428D04DD000000004429D84189C5488B84"
    s .= "24F00100004839C60F84AC0000008B5030660FEFF6660FEFE4660FEFEDF20F2A30F2410F1000448D0C128B5034F2410F2AE101D2F20F2AEAF20F5EE6F20F5EEEF20F5CE2660F2FC4F20F5CE9760C660F28F0F20F5CF4660F28E6660F2FC57608F20F5CC5"
    s .= "660F28E8F2410F104048660F2FC4721B660F2FC572158B502C8D149201D24439EA0F9DC20FB6D201542440F2410F107068660F2FF5721FF2410F106870660F2FEC72138B50102B500C83FA0C0F9CC20FB6D2015424604883C05048398424900000000F85"
    s .= "39FFFFFF8B542440B808000000C7442420000000004889B424E000000039C244899424E80000000F4EC28B54246048899C241002000048898C2418020000898424B0000000B80600000039C289AC24EC0000008B6C24500F4EC28B5424584889BC24F000"
    s .= "00008B7C2448898424AC000000B80600000039C20F4DC28B5424248D0440D1F8448D7002B8CDCCCCCC468D2CB5000000004489B424840000004C0FAFE88B84248800000083C00349C1ED224139C5440F4CE84489E8C1E81F4401E8D1F8F7D84189C38984"
    s .= "24A80000008B44241001C289D0C1E81F01D08B542478D1F84101C34489F0C1E81F4401F0D1F84189C18B44247441F7D901C289D0C1E81F01D0D1F84401C841F7D989842488000000488B44243044894C24384C8DB0C00000008B742438B8CDCCCCCCB91B"
    s .= "0200008B9C24A80000004D8D8E40FFFFFF480FAFF08B84248800000048C1EE2301C639CE0F4FF131C985F60F48F1F7DB69F6C003000089742408660F1F44000089D8BABF0300008B742408660FEFC0C1F803F2410F1060204401D839D00F4FC231D285C0"
    s .= "0F48C24983C1184401EB01F0BEABAAAAAA4898418B14844189D20FB6CE0FB6D241C1EA10450FB6D2418D040A29E901D029FA4429D1480FAFC64429D248C1E8214429F8F20F2AC0F2410F5E4018F20F5FE0F2410F104028F20F5DC4F2410F1141E8F2410F"
    s .= "107020660FEFC0F20F2AC2F2410F5E4018F20F5FF0F2410F104028F20F5DC6F2410F1141F0F2410F106820660FEFC0F20F2AC1F2410F5E4018F20F5FE8F2410F104028F20F5DC5F2410F1141F84D39CE0F8522FFFFFF83442420188B4424204981C6C000"
    s .= "00008B8C2484000000014C24383DF00000000F85B1FEFFFF448B9424E80000004C8B4C2430B82C010000660FEFC0448B742458660FEFE4448B9C24A4000000660FEFED4139C2488BB424E0000000F20F2AA424D00000008BAC24EC000000410F4EC2488B"
    s .= "BC24F0000000488B9C2410020000F20F2AC0F2410F5E40308B44247CF2410F118180070000660FEFC0488B8C2418020000F20F2AC0F2410F5E40384489F0F2410F118188070000660FEFC0F20F2AC0B858020000F2410F5E4038F2410F11819007000041"
    s .= "39C3660FEFC0410F4EC3448B5C2470F20F2AC0F2410F5E40404489D8F2410F118198070000660FEFC0F20F2AC08B84249C000000F20F5EC4F2410F1181A0070000660FEFC0F20F2AC0F2410F5E4048F2410F1181A8070000660FEFC08B8424A0000000F2"
    s .= "0F2AC0F2410F5E4048F2410F1181B0070000660FEFC08B8424B0000000F20F2AC0F2410F5E4050F2410F1181B8070000660FEFC08B8424AC000000F20F2AC0F2410F5E4058F2410F1181C0070000660FEFC08B942480000000F2410F5E6018F2410F11A1"
    s .= "C80700004429DA448B9C249800000089D0BA01000000F20F2AC0F2410F5E40488B442464F2410F1181D0070000660FEFC0F20F2AC0438D0436F2410F5E4060448B7624F2410F1181D807000085C0660F28C30F4EC2F20F5CC14489F2F20F2AE84489D0F2"
    s .= "0F5EC5660FEFEDF20F2AE88B462889842484000000F2410F1181E0070000660FEFC0F20F2A8424C8000000F2410F5E4048F2410F1181E8070000660FEFC0F20F2A8424D4000000F2410F5E4048F2410F1181F0070000660FEFC0F20F2AC2F20F5EC5F241"
    s .= "0F1181F8070000660FEFC0F20F2AC0488B842430020000F20F5EC5F2410F118100080000F20F1028F2410F1070784585DB0F8E020500004C8BAC2420020000418B45009083E8018D140001D04863D248984C631C834585DB0F84C6040000F20F1004D166"
    s .= "430F2F44D9F80F82AB0400008B448304EBCE660F1F4400008B7C240883FFF10F8CEB0000008B742438448D4E0F4183F92F770983FF3C0F8EC1F2FFFFC7442418000000004181F8A30100000F8EE4F2FFFF0F1F8000000000440FB64C24184183F101E9C2"
    s .= "F2FFFF660F1F84000000000039D10F8CE8F1FFFF83C001E989EFFFFFB9030000004429C9448D4103410F48C84189C941C1F90241F7D9E942EFFFFF9085FF0F84B8F1FFFF31D2E906EFFFFFC7442418000000008B7C2408448D4F5F4183F94F77938B7424"
    s .= "38448D4E324183F932778539D17C814189C94129D1416BF1644189C14129D1478D0C8941C1E1024439CE0F8D58ECFFFF440FB64C24184183F101E922F2FFFF660F1F840000000000C744241800000000E9FAF1FFFF0F1F008B7C2408448D4F5F4183F94F"
    s .= "0F873EF1FFFFC744241800000000EB890F1F4000C74424200000000031DBE9E1E5FFFF85DB0F85FAE7FFFF8B5C241885DB0F84510200006B4C24106469D0820000004585D20F85DC02000039D10F8C04F2FFFF83C00105D0070000E938E8FFFF81FE3902"
    s .= "00000F8EB5010000837C2408D80F8C22020000458D450F4183F82F0F876A020000837C24083C0F8F5F020000448B44242431DB4529E04183F83C0F9EC3410F9FC081FEA30100007E094584C00F853B020000837C2408D87C1A4584C07415458D45194183"
    s .= "F819770B837C24080A0F8E7D020000C744242000000000E920E5FFFF8B9C24A80000008BBC24840000004589D14C8BBC24080100004C8B74242883FB020F8E5EF1FFFF8BB4241401000039B424280100000F8E4AF1FFFF8D04B64C8B9424F001000083C6"
    s .= "01C1E00289B424140100004898498D048289480C8B8C24AC00000089782C8BBC24C00000008948148B8C24B00000008978308BBC24D00000008948188B8C24B80000008978348BBC24E800000089481C8B8C24A400000089188948208B8C24D400000044"
    s .= "8960048948248B8C24D80000004489480889501089482889783848C7403C0000000048C7404400000000E9AAF0FFFF448B4C24644531E44529F94183F940410F9EC4E9F9EAFFFF39D10F9DC24531E40FB6D2E9A2ECFFFF448B4C246431F64529F94183F9"
    s .= "3C400F9EC689742420E932EAFFFF83C0014585E40F847DEFFFFFE9CAECFFFF90C744241800000000E985E4FFFF8B5C240883FBF10F8CBA000000458D450F4183F82F770983FB3C0F8E4FFEFFFF31DB81FEA30100000F8E73FEFFFF4189D84183F001E95B"
    s .= "FEFFFF39D10F8CF4EFFFFF83C001E92DE6FFFFBA030000004429CA8D4A030F48D14189D141C1F90241F7D9E9EAE5FFFF4585D20F84C6EFFFFF4531C0E9AFE5FFFF8B5C2408448D435F4183F84F0F8769FDFFFF31DB458D45324183F832779839D17C9441"
    s .= "89CA4189C04129D24129D0456BD264478D048041C1E0024539C20F8D14E3FFFF4189D84183F001E9CEFDFFFF31DBE9B6FDFFFF31DB448B542408458D425F4183F84F76AD4189D84183F001E9AAFDFFFF448B44242431FF4529E04183F840400F9EC7897C"
    s .= "2418E97FE3FFFF4531C039D1C744241800000000410F9DC0E90BE5FFFF448B4C241883C0014585C90F8408FDFFFFE945E5FFFF90448B4424244531D24529E04183F83C410F9EC24489542420E993E2FFFF4C6BC8464D39C80F8CC1F1FFFFE98FF0FFFF48"
    s .= "89D0E931F2FFFF8B448308E920FBFFFFF20F586CD1084983C5044C396C24680F8506FBFFFF66410F2FA8800000000F83190700004531ED817C24708B0000000F8F72030000660FEFC08B442410438D1492F20F1117F20F2AC08B442474C1E203F20F114F"
    s .= "08F20F117F10F20F115F18F20F114720660FEFC0F20F2AC08B442424F20F116F60F20F117768F20F114728660FEFC0F20F2AC08B442478F20F114730660FEFC0F20F2AC08B44247CF20F114738660FEFC0F20F2AC08B442458F20F114740660FEFC0F20F"
    s .= "2AC04489D0F20F114748660FEFC0F20F2AC08B442418F20F114750660FEFC0F20F2AC04489E8F20F114758660FEFC0F20F2AC08B442470F20F114770660FEFC0F20F2AC08B8424A4000000F20F114778660FEFC0F20F2AC0416BC66439D0F20F11878000"
    s .= "0000660FEFC00F9DC04881C7E00000000FB6C0F20F2AC08B442440F20F1147A8660FEFC0F20F2AC08B442460F20F1147B0660FEFC0F20F2AC08B842484000000F20F1147B8660FEFC0F20F2AC0F20F1147C0660FEFC08B842480000000F20F2AC08B8424"
    s .= "9C000000488344242804488144243008080000F20F1147C8660FEFC0F2410F2AC7F20F1147D0660FEFC0F20F2AC08B8424A0000000F20F1147D8660FEFC0F20F2AC08B4648F20F1147E0660FEFC0F2410F2AC6F20F1147E8660FEFC0F20F2AC0488B4424"
    s .= "28F20F1147F0660FEFC0F20F2AC5F20F1147F848398424B80000000F850DF1FFFF448BBC24D8000000448BA424DC0000004C8B9C2408020000660FEFC04489E0F20F2AC0488B8424C80100008B4820F2410F110385C90F849E000000488B8424C0010000"
    s .= "BA280000004C8D90DC610200498D8A9CFBFFFF31DB0F1F008B010FB6F44189C00FB6C041C1E8104189F13D8B000000400F9FC64181F995000000450FB6C00F9FC04084C674144183F86E770E4529C131C04183F94F0F9FC001C34883C1044939CA75B583"
    s .= "C2014981C2000F000083FA3E7F0583FB777E9531C0660FEFC083FB770F9FC0F20F2AC0F2410F11432083FB770F8F2F070000488B8424C80100008B502885D20F84CADAFFFF488B8424C00100004C8B84243802000041BAABAAAAAA488DB8000F00004C8D"
    s .= "8800B31F00488D9F00F1FFFF4C89C6904889DA31C931C04989DF448B2A4881C2001E00004589EE4489EB450FB6ED41C1EE100FB6EF450FB6F64401F54401ED448BAA08E2FFFF490FAFEA4489EB0FB6DF48C1ED2101C54489E8450FB6EDC1E8100FB6C001"
    s .= "D84401E8490FAFC248C1E82101E883F9020F8455040000B902000000EB98C744246400000000660F28FA660F28D9E946F1FFFFF2410F106010660F28C2BA2D000000F20F5EC4F2440F2CD8660F28C1F20F5EC4F20F2CC039D00F4DD083E8028984248800"
    s .= "000083EA2D39D00F8E50FCFFFFB864000000C7442420000000004139C3C744240800000000410F4DC34489B424A800000048C744243800000000448D689CB85B0300004489BC24AC0000004139C344899424E0000000410F4EC389AC24E80000004889B4"
    s .= "24B000000089D6448D486448898C241802000069C2C00300004489C94401E8894424644139CD0F8F3802000048899C24100200008B4424644D63D54489EAEB1283C20283C0024983C20239CA0F8F0A02000081FE1B0200007FE64C63C8478B348C4589F1"
    s .= "4489F3450FB6F641C1E9100FB6EF4181FE8B000000410F9FC781FDA9000000450FB6C9410F9FC64584F774B04181F99600000077A74429CD83FD457E9F448D4A0383442408014C015424384181F9BF0300007788448D48034D63C9478B0C8C4489CD4489"
    s .= "CB450FB6C9C1ED100FB6DF4181F98B000000440FB6F5400F9FC581FBA90000004189DF410F9FC14484CD0F8448FFFFFF4181FE960000000F873BFFFFFF4529F74183FF450F8E2EFFFFFF89D383EB030F8823FFFFFF448D48FD4D63C9478B0C8C4489CD44"
    s .= "89CB450FB6C9C1ED100FB6DF4181F98B000000440FB6F5400F9FC581FBA90000004189DF410F9FC14484CD0F84E3FEFFFF4181FE960000000F87D6FEFFFF4529F74183FF450F8EC9FEFFFF448D4E034181F91B0200000F87B8FEFFFF448D88400B00004D"
    s .= "63C9478B0C8C4489CD4489CB450FB6C9C1ED100FB6DF4181F98B000000440FB6F5400F9FC581FBA90000004189DF410F9FC14484CD0F8475FEFFFF4181FE960000000F8768FEFFFF4529F74183FF450F8E5BFEFFFF89F383EB030F8850FEFFFF448D88C0"
    s .= "F4FFFF4D63C9478B0C8C4489CD4489CB450FB6C9C1ED100FB6DF4181F98B000000440FB6F5400F9FC581FBA90000004189DF410F9FC14484CD0F840DFEFFFF4181FE960000000F8700FEFFFF4529F74183FF450F8EF3FDFFFF8344242001E9E9FDFFFF0F"
    s .= "1F440000488B9C2410020000814424648007000083C60239B424880000000F8FA7FDFFFF48635424084963C34C8B5C2438448BB424A8000000448BBC24AC000000480FAFC2488BB424B0000000448B9424E00000008BAC24E8000000488B8C2418020000"
    s .= "4989C54D29DD4929C34D0F48DD4531ED83FA0E0F8E24F9FFFF8B4424208D044039D00F8D15F9FFFF4889D04531ED48C1E0044829D048C1E0024C39D8410F9DC5E9F8F8FFFF488B842430020000448B9C2498000000F20F107008488B8424280200008B40"
    s .= "04428D14184439DA0F8EBAF8FFFF488B9424C00000004C8B6C24684C8B4C24304801D0488B942420020000488D04824889442408418B450083E8018D140001D04863D248984C631C834585DB741AF20F1004D166430F2F44D9F872068B448304EBD68B44"
    s .= "8308EBD0F20F5874D1084983C5044C396C240875BBE94AF8FFFF660F1F44000085C08D50034C89FB0F48C24883C3104883C601C1F8028846FF4839DF0F851EFBFFFF4881C7003C00004981C0F00000004939F90F85FCFAFFFF488B8424C80100008B4038"
    s .= "85C00F848FD5FFFF488B8424380200004531C04531C931DB4531D231F6488DB85E090000488DA89E6E0000488D8F12FFFFFF662E0F1F8400000000000FB6110FB64102440FB6A911FFFFFF440FB6B1A17D000029D089C2F7DA0F48D00FB681F100000044"
    s .= "29E84189C541F7DD410F49C5440FB6A9927E000001C20FB681907E00004863D24129C54801D64489E8F7D8410F48C5440FB6A9817F00004529F54589EE41F7DE450F49EE4883C1014401E84989D54898480FAFD24C0FAFE84801C3480FAFC04901D14D01"
    s .= "EA4901C04839CF0F8567FFFFFF4881C7F00000004839FD0F8546FFFFFF660FEFC0B868640000F2480F2AC0F2410F114350660FEFC0F2480F2AC6F2410F114358660FEFC0F2480F2AC3F2410F114360660FEFC0F2490F2AC2F2410F114368660FEFC0F249"
    s .= "0F2AC1F2410F114370660FEFC0F2490F2AC0F2410F114378E94ED4FFFFC744246400000000660F28FA660F28D9C744241800000000E963EBFFFF4C69D0360100004D39D00F8C11E8FFFFE95AE6FFFF8B9C24F000000085DB0F84FDE7FFFF446B4628646B"
    s .= "C91E4139C87C0F3D8B0000007E0884D20F85CAE7FFFF4181F9F90000000F8ED4E7FFFF3D950000000F8FB2E7FFFFE9C4E7FFFF4489C0C7442450FBFFFFFFC1E81F4401C0D1F8894424484183F9F50F8C74D5FFFFE94EE3FFFF488B8424E0010000488D90"
    s .= "E01F0000C700000000004883C008C740FC000000004839C275EA488B8424C001000083BC240001000042488BBC24E0010000488DB000DE0300B8420000007E7589C34531C9C1FB046BDB3C428B0CCE0FB6D5440FB6C14489C54189D229D54529C2440F48"
    s .= "D583FA59762BC1E9100FB6C929CA83FA1D7E1E4129C84183F81D7E154183FA197F0F4489CAC1FA0301DA4863D2830497014983C1014981F9E001000075A983C0024881C6001E0000398424000100007F8B8BBC2434010000448964246431C94D89D9C744"
    s .= "242000000000BE7800000041BD100000004189CB89F8C7442410000000004429F8C7442408000000004898488944241889F88BBC24300100004401F8489848894424488B84242C01000029F8488BBC24E001000048984889442450BA01000000418D858E"
    s .= "FEFFFF8B8C242C0100008B9C24300100003D8F0100004489D844896C243841B810000000410F96C44181FD3D03000044896C24600F9F4424404183C3014589DF41C1E7054183EF1085C00F4EC28D50FF6BC23C4989D6894424284889D048C1E0044829D0"
    s .= "8D14194863CA48C1E00248894C2458488944243031C089C54C89C80F1F4400004981F83F060000771C4983F8130F876501000041B83000000083C5014981F83F06000076E4448D55014181FF3501000076214981F8530600000F86690100004181F86207"
    s .= "00007F0B807C2440000F84550100004983C0204489D54981F890070000759D4989C14983C52083C63C4183FB1E0F85FCFEFFFF837C240813448B6424644989C30F8E8CF6FFFF8B4424108B7C2420B90300000085C08D500F0F49D08D470FC1FA0485FF0F"
    s .= "49C7C1F80439C80F4DC8448D41FDB94000000039C80F4EC88D41034439C00F8C4AF6FFFFB80300000039C20F4DC2448D48FDB87400000039C20F4FD0456BD0784D63C031DB6BC9784C89C048C1E00483C2034C29C048C1E00581C1E001000048038424E8"
    s .= "0100004139D17F104D63C142031C804983C0014439C27DF34183C2784805E00100004439D175DC83FB4F0F8EDAF5FFFF488B8424D0010000F20F1040088B442410F2410F114328660FEFC0F20F2AC08B442420F2410F114330660FEFC0F20F2AC0F2410F"
    s .= "114338E99EF5FFFF4183F86D7F054584E475104981F83F010000771C837C2460457F1583C5014983C020E961FEFFFF660F1F8400000000004C394424187F1D4C394424487E164C396C24507F0F448D55014C396C24580F8F87FEFFFF4539DE0F8F940000"
    s .= "0085EDBA010000004C8B5424308D4D020F4FD544895C2424448B4C24288D5AFF29D14863D24C01D2448D55014863EB4801D131D2488D0C8F0F1F40004139DA7C1F4D63D94901EB4E8D1C9F660F1F8400000000004103134983C3044C39D975F44183C13C"
    s .= "4881C1F00000004439CE75CC448B5C2424395424080F8D00FEFFFF8B4C2438448944241089542408894C2420E9EAFDFFFF31D2448D5501EBD8BA6E00000039D089D70F4EF86BC70E89F9C1E1043D8D0300000F8ECB000000BACDCCCCCC480FAFC248C1E8"
    s .= "2348898424880000008D047F8D04873D5B0300007F4EC78424E00000005500000089C8BACDCCCCCC480FAFC248C1E8234989C2E967CFFFFFBF32000000C78424E00000005500000041BA64000000C78424880000005A000000E941CFFFFF660F1F440000"
    s .= "480FAFC248C1E82348898424E0000000EBAB660FEFC031C0F20F2AC0F2410F114340F2410F11434831C04585F6410F4EC64189C4E91CF3FFFF428D14134863D2480FAFC24939C00F8C96E2FFFFE9D3E1FFFF31D231C9E97ACEFFFF81F9F10300000F8E72"
    s .= "FFFFFFC78424E000000055000000C78424880000005A000000E93BFFFFFF"
    return s
}

ModelABase() => -0.000019045019769368683
ModelARoots() {
    return "1 48 95 142 189 236 283 330 377 424 471 518 565 612 659 706 753 800 847 894 941 988 1035 1082 1129 1176 1223 1270 1317 1364 1411 1458 1505 1552 1599 1646 1693 1740 1787 1834 1881 1928 1975 2022 2069 2116 2163 2210 2257 2304 2351 2398 2445 2492 2539 2586 2633 2680 2727 2774 2821 2868 2915 2962 3009 3056 3103 3150 3197 3244 3291 3338 3385 3432 3479 3526 3573 3620 3667 3714 3761 3808 3855 3902 3949 3996 4043 4090 4137 4184 4231 4278 4325 4372 4419 4466 4513 4560 4607 4654 4701 4748 4795 4842 4889 4936 4983 5030 5077 5124 5171 5218 5265 5312 5359 5406 5453 5500 5547 5594 5641 5688 5735 5782 5829 5876 5923 5970 6017 6064 6111 6158 6205 6252 6299 6346 6393 6440 6487 6534 6581 6628 6675 6722 6769 6816 6863 6910 6957 7004 7051 7098 7145 7192 7239 7286 7333 7380 7427 7474 7521 7568 7615 7662 7709 7756 7803 7850 7897 7944 7991 8038 8085 8132 8179 8226 8273 8320 8367 8414 8461 8508 8555 8602 8649 8696 8743 8790 8837 8884 8931 8978 9025 9072 9119 9166 9213 9260 9307 9354 9401 9448 9495 9542 9589 9636 9683 9730 9777 9824 9871 9918 9965 10012 10059 10106 10153 10200 10247 10294 10341 10388 10435 10482 10529 10576 10623 10670 10717 10764 10811 10858 10905 10952 10999 11046 11093 11140 11187 11234 11281 11328 11375 11422 11469 11516 11563 11610 11657 11704 11751 11798 11845 11892 11939 11986 12033 12080 12127 12174 12221 12268 12315 12362 12409 12456 12503 12550 12597 12644 12691 12738 12785 12832 12879 12926 12973 13020 13067 13114 13161 13208 13255 13302 13349 13396 13443 13490 13537 13584 13631 13678 13725 13772 13819 13866 13913 13960 14007 14054"
}

ModelAText() {
    s := ""
    s .= "253:-0.013888888888889284:2:19 244:0.88:3:6 251:1.359375:4:5 ~-0.09000034174922207 ~0.04725914458069485 249:1.8333333333333335:7:18 243:0.45:8:11 244:1.355:9:10 ~-0.08028990079545899 ~0.0701800088059962 "
    s .= "243:2.3499999999999996:12:17 200:0.765625:13:16 31:0.734375:14:15 ~0.09527590459432275 ~-0.005989889510757575 ~-0.07438545831450642 ~-0.07503521264271869 ~-0.09312581406972026 248:0.375:20:39 244:0.855:21:22 "
    s .= "~-0.09435713527768727 31:0.453125:23:38 139:-0.171875:24:27 117:0.234375:25:26 ~-0.08553100428484581 ~0.06252151299643563 193:0.390625:28:37 235:0.03125:29:36 251:1.203125:30:35 163:0.015625:31:32 ~-0.05789715274341293 "
    s .= "217:-0.09375:33:34 ~-0.05836343796183318 ~0.05092843023605031 ~0.07579742935980499 ~0.06930383544038217 ~-0.038523938894177066 ~-0.0787188669458735 248:0.625:40:47 41:-0.03125:41:46 244:1.015:42:43 ~-0.07477319097930099 "
    s .= "249:1.1666666666666665:44:45 ~0.03273527776991435 ~-0.09491582028052671 ~-0.08902068432649624 ~-0.09503070498516415 253:-0.013888888888889284:49:68 244:0.88:50:53 251:1.359375:51:52 ~-0.08567877395700135 "
    s .= "~0.044947143602930235 249:1.8333333333333335:54:67 243:0.45:55:58 248:0.125:56:57 ~0.08089318101828033 ~-0.0630276394283971 243:2.25:59:66 200:0.75:60:65 31:0.828125:61:64 248:0.875:62:63 ~0.09176796276752325 "
    s .= "~0.02338390991598832 ~-0.013087778901677137 ~-0.06612422090010948 ~-0.06701763878108184 ~-0.08866919032473713 248:0.375:69:86 244:0.855:70:71 ~-0.0898444987286397 31:0.453125:72:85 139:-0.171875:73:76 "
    s .= "141:0.2109375:74:75 ~-0.083431867515486 ~0.04835991093101712 193:0.390625:77:84 235:0.046875:78:83 117:0.234375:79:82 163:0.015625:80:81 ~-0.05317583412528065 ~0.031058529611622917 ~0.07654877870872023 "
    s .= "~0.06718482018808572 ~-0.03661670479552825 ~-0.0749046876403802 248:0.625:87:94 38:-0.046875:88:93 244:1.015:89:90 ~-0.0711405243915394 249:1.1666666666666665:91:92 ~0.03200417782836654 ~-0.08883353975052984 "
    s .= "~-0.08431713344103882 ~-0.09048725127529596 253:-0.013888888888889284:96:113 244:0.88:97:100 251:1.234375:98:99 ~-0.0827573730857619 ~0.026479836379653444 249:1.8333333333333335:101:112 243:0.45:102:105 "
    s .= "244:1.355:103:104 ~-0.074109644264976 ~0.0647086302607957 243:2.3499999999999996:106:111 227:0.71875:107:110 31:0.734375:108:109 ~0.08677553724262937 ~-0.0056448787099528585 ~-0.06678705536616576 ~-0.06831684204937966 "
    s .= "~-0.08476568222486815 248:0.375:114:137 244:0.855:115:116 ~-0.08590139897690537 235:-0.09375:117:122 130:0.4375:118:119 ~0.02250231711813446 251:1.203125:120:121 ~-0.08125217949803012 ~0.024156035044519308 "
    s .= "31:0.453125:123:136 236:0.578125:124:135 184:-0.0625:125:128 251:1.171875:126:127 ~-0.057666321263984466 ~0.08253500019913171 243:2.05:129:134 133:1.09375:130:133 251:0.546875:131:132 ~-0.011145958643223012 "
    s .= "~0.06399363457446831 ~0.07999909962493189 ~-0.08896525246772896 ~-0.08673220992313967 ~-0.05948118569434866 45:0.3359375:138:139 ~-0.0845825843126713 88:1.390625:140:141 ~-0.06385541912003483 ~0.07498670783503424 "
    s .= "253:-0.013888888888889284:143:158 244:0.88:144:147 251:1.359375:145:146 ~-0.07851926586262477 ~0.04154064676905014 249:1.8333333333333335:148:157 243:0.45:149:152 248:0.125:150:151 ~0.07496337117529614 "
    s .= "~-0.058345496162203025 243:2.25:153:156 200:0.765625:154:155 ~0.08250538341845949 ~-0.06635831399169186 ~-0.06126866808420009 ~-0.08131515780879929 248:0.375:159:180 244:0.855:160:161 ~-0.08242414895100045 "
    s .= "235:-0.09375:162:167 130:0.4375:163:164 ~0.021388058215024656 251:1.203125:165:166 ~-0.07772941399521766 ~0.022979187313792077 31:0.296875:168:177 236:0.578125:169:176 184:-0.0625:170:173 178:0.703125:171:172 "
    s .= "~0.05809080163319861 ~-0.07058758267790195 243:2.05:174:175 ~0.06199472628384563 ~-0.08458613253164148 ~-0.0820828062063984 251:1.015625:178:179 ~-0.06707070323666729 ~0.054138830460717324 248:0.625:181:188 "
    s .= "244:0.94:182:183 ~-0.08002328520983784 249:1.1666666666666665:184:187 241:0.22:185:186 ~-0.02970901207407758 ~0.05410554671882653 ~-0.08519842894716595 ~-0.08321354469648432 253:-0.005641656982653053:190:209 "
    s .= "244:0.88:191:194 251:1.171875:192:193 ~-0.0777094301991011 ~0.017613041468327015 249:1.8333333333333335:195:208 31:0.375:196:205 200:0.71875:197:204 241:0.16:198:199 ~-0.03968097340191337 248:0.875:200:201 "
    s .= "~0.08018875025184682 243:0.6499999999999999:202:203 ~-0.07686898698772628 ~0.05151011878613774 ~-0.06857015892174932 251:0.859375:206:207 ~-0.06344027679427335 ~0.05911497391524593 ~-0.07847824276685439 "
    s .= "248:0.375:210:229 244:0.855:211:212 ~-0.07919742351443314 235:-0.078125:213:216 130:0.453125:214:215 ~0.020906849568941187 ~-0.0656855836095353 31:0.296875:217:226 236:0.578125:218:225 184:-0.0625:219:222 "
    s .= "251:0.953125:220:221 ~-0.06459009468315179 ~0.0640879965450729 243:1.95:223:224 ~0.05828140703175099 ~-0.08498030339289755 ~-0.08242905335429701 251:0.453125:227:228 ~-0.08146195208590569 ~0.004464668259340791 "
    s .= "248:0.625:230:235 41:-0.03125:231:234 195:0.484375:232:233 ~-0.043622179187751756 ~0.047804973931612704 ~-0.07509642062994953 ~-0.08052545078094533 253:-0.013888888888889284:237:256 244:0.88:238:241 251:1.234375:239:240 "
    s .= "~-0.07355357050049913 ~0.023858952481112774 249:1.8333333333333335:242:255 243:0.45:243:248 244:1.355:244:245 ~-0.06869979216481835 248:0.375:246:247 ~0.07486944889042839 ~-0.07664694812867343 243:2.25:249:254 "
    s .= "227:0.71875:250:253 37:0.765625:251:252 ~0.07750296600658396 ~-0.017298612100501456 ~-0.06152656065031235 ~-0.05774860599281988 ~-0.07547091064057528 248:0.375:257:276 244:0.855:258:259 ~-0.07657534988276944 "
    s .= "31:0.515625:260:275 139:-0.171875:261:264 117:0.234375:262:263 ~-0.07131703628568926 ~0.05407738858693631 193:0.390625:265:274 163:-0.09375:266:269 256:0.6851851851851852:267:268 ~-0.051617268871686876 "
    s .= "~0.08094188962573974 212:0.5625:270:273 243:1.65:271:272 ~0.05485862808867728 ~-0.033176672096992904 ~-0.05975889853453416 ~-0.03574566380530852 ~-0.06676552126338921 60:0.2890625:277:278 ~-0.07554709433698337 "
    s .= "85:1.171875:279:282 228:0.625:280:281 ~-0.06905439663835927 ~0.007221576896671674 ~0.07076100275492796 253:-0.005641656982653053:284:303 244:0.88:285:286 ~-0.06675636965384767 249:1.8333333333333335:287:302 "
    s .= "31:0.375:288:297 200:0.71875:289:296 243:0.45:290:293 244:1.355:291:292 ~-0.05769666285061327 ~0.06483981652858671 248:1.125:294:295 ~0.07540196819989664 ~-0.03869597228448968 ~-0.0644088486737988 251:0.609375:298:299 "
    s .= "~-0.07108046443108468 248:0.625:300:301 ~0.06839338725645018 ~-0.046332582530644026 ~-0.07322494312861905 248:0.375:304:323 244:0.855:305:306 ~-0.07393095273396648 235:-0.09375:307:310 130:0.4375:308:309 "
    s .= "~0.01635734328976253 ~-0.06277172019397986 31:0.28125:311:320 236:0.578125:312:319 184:-0.0625:313:316 178:0.703125:314:315 ~0.05024624840190339 ~-0.06870062544355682 133:1.09375:317:318 ~0.02827491819362526 "
    s .= "~0.0683397065301654 ~-0.07729399457487102 251:0.453125:321:322 ~-0.07707324954090626 ~0.006739593539495123 248:0.625:324:329 38:-0.046875:325:328 135:0.2890625:326:327 ~-0.03749899831671864 ~0.0641282072892606 "
    s .= "~-0.06944421833265595 ~-0.07535025127496948 253:-0.013888888888889284:331:346 244:0.865:332:333 ~-0.06684310312193595 249:1.8333333333333335:334:345 31:0.375:335:342 243:0.45:336:339 244:1.345:337:338 "
    s .= "~-0.05676646311659133 ~0.061274842387211384 200:0.75:340:341 ~0.07272433226361454 ~-0.05952601021311216 251:0.765625:343:344 ~-0.062091184540424886 ~0.05036201526645154 ~-0.07076609269883771 248:0.375:347:366 "
    s .= "244:0.855:348:349 ~-0.07182656505615702 31:0.515625:350:365 139:-0.171875:351:354 211:-0.03125:352:353 ~-0.06958349737054711 ~0.037556468508722796 193:0.390625:355:364 243:1.95:356:363 223:-0.046875:357:362 "
    s .= "251:1.484375:358:361 106:0.84375:359:360 ~-0.04630488249943831 ~0.036605953481392804 ~0.06970624001763745 ~0.05301648856149169 ~-0.07031224041878166 ~-0.034541492462502696 ~-0.06236349903172805 "
    s .= "249:1.1666666666666665:367:376 160:1.203125:368:375 251:0.734375:369:370 ~-0.07017434676076088 242:0.55:371:372 ~-0.06280293339493896 244:0.86:373:374 ~-0.059570700592737925 ~0.02983258501040172 ~0.030981504074865197 "
    s .= "~-0.07651328427708144 253:-0.005641656982653053:378:397 244:0.88:379:382 251:1.171875:380:381 ~-0.06842305450375183 ~0.022044874463291037 249:1.8333333333333335:383:396 31:0.375:384:391 227:0.71875:385:390 "
    s .= "241:0.16:386:387 ~-0.036093505154343834 248:0.875:388:389 ~0.07071747482410619 ~-0.0067761492387920595 ~-0.06397550326270411 251:0.609375:392:393 ~-0.06572935966281784 243:0.55:394:395 ~-0.06036597845988831 "
    s .= "~0.06188399838403871 ~-0.06887935707973408 248:0.375:398:419 244:0.855:399:400 ~-0.06959562606689246 235:-0.09375:401:404 130:0.4375:402:403 ~0.015364472345087324 ~-0.059035528716834644 31:0.28125:405:416 "
    s .= "236:0.578125:406:415 161:0.625:407:414 109:0.625:408:411 3:0.171875:409:410 ~-0.03824240540816895 ~0.04430104530602851 243:1.45:412:413 ~0.05521836053439967 ~-0.06998917168172494 ~0.07758185491126501 "
    s .= "~-0.0747536463222582 251:0.421875:417:418 ~-0.07415094704137877 ~0.00603952758808722 249:1.1666666666666665:420:423 160:1.09375:421:422 ~-0.06103216310400733 ~0.027066470190696565 ~-0.07474064838618365 "
    s .= "253:-0.013888888888889284:425:442 244:0.865:426:427 ~-0.06284537927123335 249:1.8333333333333335:428:439 243:0.45:429:432 248:0.125:430:431 ~0.06211794912889475 ~-0.050140979736220226 243:2.1500000000000004:433:438 "
    s .= "227:0.71875:434:437 37:0.765625:435:436 ~0.068755938228094 ~-0.02214496712842147 ~-0.05600654636456644 ~-0.050981980612882644 222:0.25:440:441 ~-0.0722690518594543 ~0.11374026464385206 248:0.375:443:462 244:0.9:444:445 "
    s .= "~-0.06207142622882938 139:-0.15625:446:449 141:0.2109375:447:448 ~-0.06756793984231935 ~0.043836697467179386 37:0.390625:450:461 243:1.95:451:460 212:0.59375:452:459 156:0.1796875:453:458 109:0.953125:454:457 "
    s .= "251:0.984375:455:456 ~-0.03224214294058394 ~0.04655046974786662 ~0.05021121812376117 ~0.06489181957572858 ~-0.05748275943132465 ~-0.06875742876375182 ~-0.04556600339493781 248:0.625:463:470 244:0.94:464:465 "
    s .= "~-0.06636430053982323 249:1.1666666666666665:466:469 241:0.22:467:468 ~-0.017523094457706563 ~0.058449206582399396 ~-0.07122470525281012 ~-0.06887807644293667 253:-0.005641656982653053:472:493 244:0.88:473:476 "
    s .= "89:1.15625:474:475 ~-0.06272741169954893 ~0.07024696629618782 249:1.8333333333333335:477:492 31:0.375:478:487 248:0.875:479:484 241:0.16:480:481 ~-0.03339596625251747 200:0.75:482:483 ~0.06715893443857866 "
    s .= "~-0.05952376715670561 243:0.6499999999999999:485:486 ~-0.07605865021037699 ~0.038421139772114525 75:0.1328125:488:491 85:1.453125:489:490 ~-0.0583169037509027 ~0.06791995485243217 ~0.0590202213783822 "
    s .= "~-0.06522626843929262 248:0.375:494:511 244:0.855:495:496 ~-0.06609292532862936 235:-0.09375:497:502 217:-0.078125:498:499 ~-0.06172288561773442 166:-0.078125:500:501 ~-0.058090504412444004 ~0.049493145060564264 "
    s .= "31:0.28125:503:508 175:0.25:504:505 ~0.04675061604615241 106:0.21875:506:507 ~-0.05305455418778004 ~0.028028824261660035 251:0.453125:509:510 ~-0.0696236856213719 ~0.007528362498504463 248:0.625:512:517 "
    s .= "41:-0.03125:513:516 195:0.484375:514:515 ~-0.03167789243130085 ~0.05085061183151366 ~-0.06200396569760877 ~-0.06751489565084569 253:-0.013888888888889284:519:538 244:0.865:520:521 ~-0.059349671269550444 "
    s .= "249:1.8333333333333335:522:537 31:0.28125:523:530 243:0.45:524:527 244:1.3:525:526 ~-0.05370313593971753 ~0.055086090009442416 236:0.625:528:529 ~0.06620555799305448 ~-0.0475056077967228 251:0.546875:531:532 "
    s .= "~-0.06157258790003686 244:0.95:533:534 ~-0.06927789279642048 243:0.45:535:536 ~-0.06618780198765825 ~0.059543223245195676 ~-0.0633824360818712 248:0.375:539:558 244:0.855:540:541 ~-0.06464464797424407 "
    s .= "37:0.390625:542:557 139:-0.171875:543:546 141:0.1328125:544:545 ~-0.06559209292471943 ~0.03165197199769131 243:1.95:547:556 212:0.5625:548:555 161:0.59375:549:554 109:0.921875:550:553 251:1.171875:551:552 "
    s .= "~-0.01592167466285003 ~0.05046309364573616 ~0.0482540073063952 ~0.0686108287540749 ~-0.049682231193389326 ~-0.06720590339515047 ~-0.051137131492489475 45:0.3359375:559:560 ~-0.0635395448971276 139:0.9375:561:564 "
    s .= "219:0.34375:562:563 ~-0.06512687845182023 ~0.0008151963141876384 ~0.07320772196692917 253:-0.005641656982653053:566:587 244:0.88:567:570 251:1.171875:568:569 ~-0.06180988563794481 ~0.026277819808839205 "
    s .= "249:1.8333333333333335:571:586 248:0.875:572:583 243:2.1500000000000004:573:582 243:0.45:574:577 244:1.355:575:576 ~-0.055771144185172976 ~0.05703034428271077 200:0.765625:578:581 31:0.828125:579:580 "
    s .= "~0.06502189289112073 ~-0.020694516001985207 ~-0.05500849699214314 ~-0.04959966385401597 210:0.1875:584:585 ~-0.06366500860145607 ~0.04857918529633787 ~-0.06206543340780544 248:0.375:588:603 244:0.855:589:590 "
    s .= "~-0.06294100566154817 163:-0.15625:591:594 117:0.21875:592:593 ~-0.06396253807448724 ~0.047469855413989126 31:0.265625:595:600 193:0.484375:596:599 136:-0.046875:597:598 ~-0.027800063003767823 ~0.03954452507857645 "
    s .= "~-0.05095961331010257 251:0.421875:601:602 ~-0.06952448273416728 ~0.005287409292615454 249:1.1666666666666665:604:611 160:1.09375:605:610 244:0.94:606:607 ~-0.06431189192058698 242:0.75:608:609 ~-0.0499802130098914 "
    s .= "~0.03862043557863072 ~0.0313404724605679 ~-0.06842497733081884 253:-0.013888888888889284:613:632 244:0.86:614:615 ~-0.05725152650046589 249:1.8333333333333335:616:629 31:0.28125:617:624 243:0.45:618:621 "
    s .= "244:1.235:619:620 ~-0.051795300653884505 ~0.05047345948227229 236:0.625:622:623 ~0.06331530777001414 ~-0.0458102341936908 251:0.546875:625:626 ~-0.05888331812151287 244:0.95:627:628 ~-0.0661743878494309 "
    s .= "~0.04769476197277467 248:0.125:630:631 ~0.14568914121824855 ~-0.06574527246492853 248:0.375:633:650 244:0.855:634:635 ~-0.06171736983343337 251:1.171875:636:647 241:0.62:637:646 121:0.234375:638:645 184:0.0625:639:642 "
    s .= "106:1.0625:640:641 ~-0.03792219143615886 ~0.05925732598521142 244:1.225:643:644 ~0.01432425183521846 ~0.06498631364047527 ~-0.048379142801619666 ~-0.06449141750944055 243:0.45:648:649 ~-0.04260472972414787 "
    s .= "~0.0583618532677753 249:1.1666666666666665:651:658 244:0.95:652:653 ~-0.062092540230575345 241:0.24:654:655 ~-0.042405313566801384 248:0.875:656:657 ~0.05786160857049277 ~-0.03665829163223163 ~-0.06672588770330283 "
    s .= "253:-0.005641656982653053:660:681 244:0.88:661:664 251:1.171875:662:663 ~-0.05906280688283744 ~0.026642775321204328 249:1.8333333333333335:665:680 248:0.875:666:677 243:2.1500000000000004:667:676 243:0.45:668:671 "
    s .= "244:1.355:669:670 ~-0.052351170129153635 ~0.053813821229671904 200:0.765625:672:675 257:0.9850746268656716:673:674 ~0.062384333007390616 ~-0.02735264257984581 ~-0.05218003451447159 ~-0.04748060816641525 "
    s .= "189:0.1875:678:679 ~-0.06262705758179829 ~0.043865144334860356 ~-0.05931695722483976 248:0.375:682:699 244:0.855:683:684 ~-0.06018860591015545 226:-0.21875:685:688 256:0.5714285714285714:686:687 ~-0.06269329785250115 "
    s .= "~0.05104161782069458 31:0.296875:689:698 139:0.03125:690:695 140:-0.359375:691:692 ~0.038437653374796515 251:1.734375:693:694 ~-0.05126898915985957 ~0.05670766705131186 217:0.390625:696:697 ~0.04408166329199518 "
    s .= "~-0.040686997258324004 ~-0.038300778306236696 248:0.625:700:705 244:0.94:701:702 ~-0.05840104391902229 249:1.5:703:704 ~0.018842839610797083 ~-0.06666287864791291 ~-0.061927395474198337 253:-0.013888888888889284:707:726 "
    s .= "244:0.86:708:709 ~-0.05452034921035226 249:1.8333333333333335:710:723 31:0.28125:711:718 236:0.625:712:717 241:0.16:713:714 ~-0.02801138671533304 248:0.875:715:716 ~0.06110638498350654 ~-0.0030722147914571223 "
    s .= "~-0.05279001146941079 251:0.546875:719:720 ~-0.05665596198477829 244:0.95:721:722 ~-0.063573897503132 ~0.04479892178406348 222:0.25:724:725 ~-0.06404712936701663 ~0.1195889683794079 248:0.375:727:744 244:0.855:728:729 "
    s .= "~-0.059142107463209505 251:1.171875:730:739 241:0.62:731:738 121:0.234375:732:737 184:0.0625:733:736 106:0.59375:734:735 ~-0.04619729247157055 ~0.035646486849291 ~0.04792124046245662 ~-0.04592991354443603 "
    s .= "~-0.061851470288036975 252:0.07500000000000001:740:743 74:-0.15625:741:742 ~0.038578590112830595 ~-0.07947470310868368 ~0.06311348762533908 249:1.5:745:752 244:0.935:746:747 ~-0.06047068199721309 241:0.24:748:749 "
    s .= "~-0.03960924990533668 248:0.875:750:751 ~0.04941946528218896 ~-0.034386589713904174 ~-0.06560279243364292 253:-0.013888888888889284:754:773 244:0.86:755:756 ~-0.053170946162357124 249:1.8333333333333335:757:770 "
    s .= "31:0.28125:758:765 243:0.45:759:762 181:0.421875:760:761 ~-0.03354063256275206 ~0.06009363756461934 236:0.625:763:764 ~0.059718945338514476 ~-0.041679921506882864 99:0.140625:766:769 85:0.9375:767:768 "
    s .= "~-0.05372597429998727 ~0.03490355308642127 ~0.049760408595625326 6:0.265625:771:772 ~-0.06330082847096583 ~0.10538789599457571 248:0.375:774:789 244:0.855:775:776 ~-0.057956301299527 251:0.359375:777:782 "
    s .= "242:0.45:778:781 244:1.315:779:780 ~-0.04250132430597534 ~0.0553802573551751 ~-0.05416638878091176 232:-0.15625:783:786 251:1.953125:784:785 ~-0.04599114998512831 ~0.05160960830654028 236:0.578125:787:788 "
    s .= "~0.038718311034511135 ~-0.061506108251393105 249:1.5:790:799 244:0.94:791:792 ~-0.05904430241642479 241:0.24:793:796 156:0.5703125:794:795 ~-0.04494958118924171 ~0.060638014031222126 248:0.875:797:798 "
    s .= "~0.04839322892943759 ~-0.03292384264019204 ~-0.06454775800795898 253:-0.005641656982653053:801:824 244:0.88:802:805 89:1.15625:803:804 ~-0.053281303488966786 ~0.07392881894221524 249:1.8333333333333335:806:821 "
    s .= "248:0.875:807:818 243:2.1500000000000004:808:817 243:0.45:809:812 244:1.355:810:811 ~-0.049820995580236616 ~0.05015192459753809 227:0.71875:813:816 257:0.9850746268656716:814:815 ~0.05908314976562976 "
    s .= "~-0.02832546768869218 ~-0.05117660956976523 ~-0.04563153544866043 210:0.1875:819:820 ~-0.05985672467048715 ~0.04226856341702864 248:0.125:822:823 ~0.12432134299762554 ~-0.06135991215777578 248:0.625:825:846 "
    s .= "244:0.855:826:827 ~-0.05698905470900861 211:-0.078125:828:833 256:0.6724137931034483:829:832 217:-0.015625:830:831 ~-0.05771338345689686 ~-0.011260733255773855 ~0.04637541029195628 251:0.140625:834:835 "
    s .= "~-0.0460933006661908 236:0.578125:836:845 156:0.1640625:837:844 109:1.1875:838:841 251:0.546875:839:840 ~-0.03787407055794259 ~0.018287853713914472 241:0.62:842:843 ~0.056806512131808755 ~-0.028638506122261362 "
    s .= "~0.0553881202816922 ~-0.06476128624388422 ~-0.05855865551545634 253:-0.013888888888889284:848:863 244:0.865:849:850 ~-0.049859862190264795 249:1.8333333333333335:851:862 31:0.28125:852:859 243:0.45:853:856 "
    s .= "181:0.421875:854:855 ~-0.03146763971335649 ~0.05768589321990243 233:0.75:857:858 ~0.05759769298165815 ~-0.06632326302873846 251:0.546875:860:861 ~-0.053875312420012936 ~0.03221157067084103 ~-0.05454584770938362 "
    s .= "248:0.375:864:885 244:0.84:865:866 ~-0.057493778899621845 37:0.390625:867:884 243:1.45:868:881 193:0.5625:869:880 223:-0.0625:870:873 232:0.0625:871:872 ~-0.02045132325635929 ~0.04864383911042383 157:0.71875:874:879 "
    s .= "223:0.34375:875:878 243:0.25:876:877 ~-0.05563245772601268 ~0.03870915459692742 ~-0.0653211530102029 ~0.05584421681570481 ~-0.05615147454628916 251:1.796875:882:883 ~-0.0681561474432507 ~0.05882138588803122 "
    s .= "~-0.044813725826781926 249:1.5:886:893 244:0.935:887:888 ~-0.05705733594951409 241:0.24:889:890 ~-0.035802473487478635 130:0.484375:891:892 ~0.05821579769866342 ~-0.011089195435200035 ~-0.06275661188976638 "
    s .= "253:-0.013888888888889284:895:914 244:0.86:896:897 ~-0.04958141690800722 249:1.8333333333333335:898:911 248:0.625:899:908 243:2.25:900:907 218:0.65625:901:906 238:-0.421875:902:903 ~-0.02520944194081955 "
    s .= "257:0.9850746268656716:904:905 ~0.057176208443853876 ~-0.02295383662151919 ~-0.0544105193991571 ~-0.04373076351549929 147:0.140625:909:910 ~-0.05253656399341971 ~0.04474790770067204 99:0.28125:912:913 "
    s .= "~-0.060296879018108054 ~0.1065771923917724 248:0.625:915:940 244:0.9:916:917 ~-0.050601182486661705 211:-0.09375:918:925 256:0.6724137931034483:919:924 223:-0.140625:920:921 ~-0.060097510224383345 139:0.671875:922:923 "
    s .= "~-0.042986450990732124 ~0.027511055256491196 ~0.0478639930753092 251:0.171875:926:929 4:0:927:928 ~0.013007533596045541 ~-0.06724616349377097 191:0.5625:930:939 156:0.1640625:931:938 190:-0.0625:932:933 "
    s .= "~-0.029247225131570184 1:0.328125:934:937 109:1.1875:935:936 ~0.01583971258973186 ~0.05361561132087013 ~-0.028170998410697475 ~0.05615928051770707 ~-0.05971340901921538 ~-0.05615370043862623 "
    s .= "253:-0.005641656982653053:942:967 244:0.88:943:948 251:1.046875:944:945 ~-0.05389421859879841 243:1.25:946:947 ~0.07987152057447532 ~-0.06155165307507694 249:1.8333333333333335:949:964 248:0.875:950:961 "
    s .= "243:2.1500000000000004:951:960 243:0.45:952:955 244:1.355:953:954 ~-0.04772352820486194 ~0.046483562004060425 227:0.71875:956:959 31:0.828125:957:958 ~0.056340442459023976 ~-0.024408972800158985 ~-0.04999738528150713 "
    s .= "~-0.042585665666642764 147:0.21875:962:963 ~-0.05468093566450344 ~0.04533259068368625 222:0.25:965:966 ~-0.059451110052222804 ~0.10047871543426955 248:0.625:968:987 244:0.855:969:970 ~-0.053877771590512706 "
    s .= "211:-0.09375:971:974 256:0.6724137931034483:972:973 ~-0.04398503190157174 ~0.04067715964723443 251:0.265625:975:980 242:0.45:976:979 157:0.796875:977:978 ~-0.0314305051698636 ~0.05695216191802732 ~-0.053102145666548244 "
    s .= "236:0.578125:981:986 175:0.265625:982:983 ~0.0410878679802061 190:-0.0625:984:985 ~-0.04919911940812555 ~0.020411588204374068 ~-0.06041431483884272 ~-0.05564335034781174 253:-0.013888888888889284:989:1006 "
    s .= "244:0.86:990:991 ~-0.04744794854863119 249:1.5:992:1003 31:0.28125:993:998 212:0.578125:994:997 248:0.875:995:996 ~0.05476448240095569 ~-0.004074156945478938 ~-0.025952894632069057 99:0.140625:999:1002 "
    s .= "106:1.46875:1000:1001 ~-0.045046996153794386 ~0.0602822360275837 ~0.046193950974667775 33:0.25:1004:1005 ~-0.05893858841274346 ~0.06409547732533914 248:0.625:1007:1034 244:0.855:1008:1009 ~-0.05310282407291677 "
    s .= "235:-0.09375:1010:1017 135:0.2578125:1011:1016 178:0.296875:1012:1015 4:0.046875:1013:1014 ~-0.04303776056362966 ~0.028727819840215902 ~-0.05877216781951851 ~0.042084656102712725 251:0.140625:1018:1019 "
    s .= "~-0.04731551440429105 190:0.34375:1020:1029 163:-0.09375:1021:1024 251:0.984375:1022:1023 ~-0.052161021573391676 ~0.05187937781998188 236:0.578125:1025:1028 250:0.9921875:1026:1027 ~0.014380710972672734 "
    s .= "~0.05109743457752917 ~-0.06202860678184668 67:0.265625:1030:1033 157:0.90625:1031:1032 ~-0.017068911422214023 ~0.060797208551795025 ~-0.05335009164794699 ~-0.05424370851956957 248:0.375:1036:1069 244:0.865:1037:1044 "
    s .= "44:-0.109375:1038:1043 246:0.109375:1039:1040 ~-0.05579408420801334 197:0.046875:1041:1042 ~0.12530638485922838 ~-0.041451997636901744 ~-0.05868114282827014 253:-0.008888888888890278:1045:1050 "
    s .= "243:2.3499999999999996:1046:1049 217:0.578125:1047:1048 ~0.053796575182338595 ~-0.01210398709669269 ~-0.045939668900305035 251:1.140625:1051:1064 241:0.62:1052:1063 121:0.171875:1053:1062 184:0.078125:1054:1057 "
    s .= "106:0.59375:1055:1056 ~-0.0404350691267096 ~0.03473813848846117 244:1.32:1058:1061 245:1.6271186440677967:1059:1060 ~-0.07433090470984832 ~0.028523711557061744 ~0.059731925951586655 ~-0.039213192218827866 "
    s .= "~-0.05843833078383778 241:0.42:1065:1068 230:-0.15625:1066:1067 ~0.03622498589158033 ~-0.05959307906866591 ~0.05589954358966218 192:0.34375:1070:1077 251:0.734375:1071:1072 ~-0.054091404601519066 252:0.225:1073:1074 "
    s .= "~-0.04169416674355719 239:0.546875:1075:1076 ~0.0321872335251507 ~-0.0613699496253207 53:0.15625:1078:1081 75:0.1171875:1079:1080 ~-0.027507245303695707 ~0.05944508442708606 ~-0.044483498076860646 "
    s .= "253:-0.005641656982653053:1083:1102 244:0.88:1084:1089 251:1.046875:1085:1086 ~-0.05129436822580118 243:1.35:1087:1088 ~0.07295948552393663 ~-0.06436856167922204 249:1.8333333333333335:1090:1101 243:0.55:1091:1096 "
    s .= "244:1.52:1092:1095 123:0.265625:1093:1094 ~-0.04645656291150035 ~0.050794781739967404 ~0.04613487379381237 243:2.1500000000000004:1097:1100 203:0.75:1098:1099 ~0.05321085229003045 ~-0.04510495947294108 "
    s .= "~-0.040589368806942805 ~-0.05052003202504343 248:0.625:1103:1128 244:0.835:1104:1105 ~-0.0532554748106244 211:-0.09375:1106:1111 130:0.703125:1107:1110 242:0.75:1108:1109 ~-0.0372577357119354 ~0.040794228072124156 "
    s .= "~-0.05114370071348545 190:0.34375:1112:1125 156:0.1484375:1113:1122 187:-0.046875:1114:1115 ~-0.03720807768190842 251:0.171875:1116:1117 ~-0.033913231467201876 236:-0.078125:1118:1119 ~0.04390452185116445 "
    s .= "3:-0.125:1120:1121 ~0.06863233400976022 ~-0.019598711990002734 212:0.46875:1123:1124 ~0.05459103297032522 ~-0.04551465504513769 67:0.15625:1126:1127 ~0.012562803815126323 ~-0.05368369257530985 ~-0.05305941369852321 "
    s .= "248:0.375:1130:1163 253:-0.025641025641031472:1131:1140 256:0.9411764705882353:1132:1139 243:2.3499999999999996:1133:1138 238:-0.421875:1134:1135 ~-0.02673625981580853 100:-0.609375:1136:1137 ~-0.06543250349709841 "
    s .= "~0.05301815667101374 ~-0.042988116164043584 ~-0.048098677546506735 251:1.171875:1141:1158 241:0.64:1142:1157 244:1.34:1143:1150 245:1.7462686567164178:1144:1145 ~-0.052108198941287535 163:-0.03125:1146:1147 "
    s .= "~-0.04893673500198407 172:-0.25:1148:1149 ~-0.06527547222633638 ~0.037342276714982074 184:0.109375:1151:1154 106:1.015625:1152:1153 ~-0.0564741584806184 ~0.04999090270178139 94:0.546875:1155:1156 ~0.05817089638600399 "
    s .= "~-0.0634154310186652 ~-0.05597118472907911 252:0.025:1159:1162 53:-0.109375:1160:1161 ~0.026841378367295457 ~-0.08718630810652475 ~0.05203563614112906 60:0.2890625:1164:1171 251:0.734375:1165:1166 ~-0.053627856675482366 "
    s .= "249:1.5:1167:1170 26:0.09375:1168:1169 ~0.02083756310148249 ~-0.034809775316305046 ~-0.05867717696518815 221:0.1875:1172:1175 244:0.88:1173:1174 ~-0.024081144527966017 ~0.05041760424607186 ~-0.048619577183490775 "
    s .= "248:0.375:1177:1206 253:-0.019999999999998862:1178:1185 244:0.84:1179:1180 ~-0.03808238315629376 243:2.3499999999999996:1181:1184 217:0.578125:1182:1183 ~0.05156918282278822 ~-0.011512096046288393 ~-0.04070696087515887 "
    s .= "244:0.835:1186:1187 ~-0.05283333555106226 34:0.34375:1188:1205 226:-0.3125:1189:1190 ~-0.048826275306990415 243:1.45:1191:1202 106:0.53125:1192:1197 156:0.2265625:1193:1196 241:0.44:1194:1195 ~-0.028516442916524817 "
    s .= "~0.04311920606462363 ~0.0424301557383217 97:0.234375:1198:1199 ~0.04761241130572657 251:0.828125:1200:1201 ~-0.04377190613999025 ~0.055381869885954865 251:1.828125:1203:1204 ~-0.06341872998419684 ~0.057404487695448904 "
    s .= "~-0.03698181041158449 192:0.34375:1207:1218 249:1.1666666666666665:1208:1217 85:1.171875:1209:1216 251:0.734375:1210:1211 ~-0.050572143280174266 242:0.55:1212:1213 ~-0.04720770581594718 218:0.46875:1214:1215 "
    s .= "~0.029155239850344877 ~-0.06141485367103192 ~0.042110786310829124 ~-0.057340810615463915 77:0.1875:1219:1222 99:0.046875:1220:1221 ~-0.029022217251679406 ~0.05702435044271168 ~-0.04198444451445171 248:0.375:1224:1253 "
    s .= "253:-0.025641025641031472:1225:1236 256:0.9411764705882353:1226:1235 243:2.3499999999999996:1227:1234 172:-0.484375:1228:1229 ~-0.03657626370190236 20:0.71875:1230:1233 257:0.9428571428571428:1231:1232 "
    s .= "~0.052415738009599255 ~-0.011587959464077667 ~-0.05879470531184944 ~-0.04042144982871466 ~-0.04665277498885584 244:0.955:1237:1242 251:1.234375:1238:1241 243:0.55:1239:1240 ~-0.026357519203736093 ~-0.06017079019895299 "
    s .= "~0.035680934574930864 214:-0.234375:1243:1246 130:-0.25:1244:1245 ~0.050134815228168074 ~-0.05614594952630775 251:0.359375:1247:1252 242:0.55:1248:1251 67:0.296875:1249:1250 ~0.042585915619840035 ~-0.057579679965202774 "
    s .= "~-0.0533570526081634 ~0.03319358760687135 60:0.2890625:1254:1263 251:0.734375:1255:1256 ~-0.0519582384069375 196:-0.125:1257:1258 ~-0.05464770677374481 23:0.296875:1259:1262 243:0.45:1260:1261 ~-0.024225131654241575 "
    s .= "~0.03311335121756696 ~-0.04272281772791113 218:0.125:1264:1269 244:0.88:1265:1266 ~-0.03271163409701549 210:0.015625:1267:1268 ~-0.012590648362778538 ~0.05997612265701921 ~-0.046398401292207986 248:0.625:1271:1310 "
    s .= "244:0.865:1272:1281 44:-0.078125:1273:1280 246:0.109375:1274:1275 ~-0.05406226350351839 155:-0.03125:1276:1277 ~0.15767429501471175 89:0.78125:1278:1279 ~-0.03890886898791026 ~0.10400966264759247 ~-0.05538328335296157 "
    s .= "253:-0.008888888888890278:1282:1293 252:0.125:1283:1288 196:-0.1875:1284:1285 ~-0.059570685482998036 74:0.5:1286:1287 ~0.029042305626910188 ~-0.15419275992017634 31:0.734375:1289:1292 230:0.828125:1290:1291 "
    s .= "~0.05182578667986459 ~-0.05135876205889768 ~-0.03596246453984076 211:-0.09375:1294:1299 76:0.21875:1295:1296 ~-0.04494964262767678 166:-0.28125:1297:1298 ~-0.05621793477217673 ~0.03593653693705495 166:0.40625:1300:1307 "
    s .= "156:0.1484375:1301:1306 85:1.171875:1302:1305 187:-0.046875:1303:1304 ~-0.04485713209460568 ~0.007299861807696405 ~0.045619656991037566 ~0.044233040152621604 91:0.140625:1308:1309 ~0.022780862684571884 "
    s .= "~-0.03999631247461894 42:0.296875:1311:1312 ~-0.05148121992612516 218:0.09375:1313:1316 88:0.890625:1314:1315 ~-0.00713565038149627 ~0.0663192249700554 ~-0.054373588595005067 248:0.625:1318:1357 244:0.895:1319:1326 "
    s .= "38:-0.078125:1320:1325 246:-0.140625:1321:1322 ~-0.053157877716887826 200:0.421875:1323:1324 ~0.06785160688402658 ~-0.05207829109597786 ~-0.05296034636211149 253:-0.008888888888890278:1327:1338 252:0.125:1328:1333 "
    s .= "196:-0.1875:1329:1330 ~-0.05834021272987719 74:0.5:1331:1332 ~0.027988065010837844 ~-0.1440845973223157 31:0.734375:1334:1337 230:0.828125:1335:1336 ~0.05183397165021478 ~-0.0489532857301252 ~-0.03152791646306108 "
    s .= "211:-0.09375:1339:1344 217:-0.015625:1340:1341 ~-0.04327714492661786 217:0.25:1342:1343 ~0.0431427099132619 ~-0.04592806843904213 156:0.1484375:1345:1354 109:1.1875:1346:1351 251:0.765625:1347:1348 ~-0.03613050482927343 "
    s .= "242:0.6499999999999999:1349:1350 ~-0.02310242688507531 ~0.04083274356960215 241:0.62:1352:1353 ~0.04424266164876774 ~-0.030463742443408832 212:0.5:1355:1356 ~0.04616572093658465 ~-0.05184122092362231 "
    s .= "42:0.296875:1358:1359 ~-0.05061969124362974 218:0.09375:1360:1363 88:0.90625:1361:1362 ~-0.006420500262890579 ~0.06545890464455323 ~-0.05347583450342539 248:0.625:1365:1406 244:0.895:1366:1375 35:-0.0625:1367:1374 "
    s .= "246:-0.140625:1368:1369 ~-0.05232687795765089 47:-0.046875:1370:1373 245:1.1142857142857143:1371:1372 ~-0.053850306055716106 ~0.07488697772492067 ~-0.05533406348950816 ~-0.05224822855828089 "
    s .= "253:-0.008888888888890278:1376:1389 252:0.125:1377:1384 196:-0.1875:1378:1379 ~-0.05721348312810701 109:0.8125:1380:1383 144:0.078125:1381:1382 ~-0.0621256605414273 ~0.03581848019489244 ~0.03879209397339109 "
    s .= "31:0.734375:1385:1388 227:0.71875:1386:1387 ~0.05111382145354838 ~-0.04638875848186069 ~-0.03012594521153976 211:-0.15625:1390:1391 ~-0.03318689372268133 156:0.2421875:1392:1405 251:0.265625:1393:1398 242:0.45:1394:1397 "
    s .= "109:0.8125:1395:1396 ~-0.058182089026233536 ~0.04453645002152415 ~-0.04983382331177611 85:0.59375:1399:1402 121:0.03125:1400:1401 ~-0.023388476211801543 ~0.01940044026599097 236:-0.0625:1403:1404 ~0.04822311977992423 "
    s .= "~-0.009694721220357624 ~0.042508191832852676 251:0.953125:1407:1408 ~-0.05010319597853709 252:0.175:1409:1410 ~-0.04044555405128178 ~0.02881022470453133 248:0.625:1412:1451 244:0.895:1413:1420 41:-0.03125:1414:1419 "
    s .= "246:0.109375:1415:1416 ~-0.043703714519696894 98:-0.046875:1417:1418 ~0.08339972215512689 ~-0.027342520480668955 ~-0.05232102307852063 253:-0.008888888888890278:1421:1432 252:0.125:1422:1427 196:-0.15625:1423:1424 "
    s .= "~-0.05301829928999622 74:0.5:1425:1426 ~0.027276360678177153 ~-0.14216374328989687 31:0.734375:1428:1431 227:0.71875:1429:1430 ~0.05038457287190678 ~-0.04476973003260464 ~-0.028785081281812626 226:-0.140625:1433:1436 "
    s .= "171:0.25:1434:1435 ~-0.04455858773632854 ~0.0484008837042752 193:0.265625:1437:1448 139:0.015625:1438:1441 61:0.125:1439:1440 ~-0.03524700173433982 ~0.03639782849251209 55:0.4375:1442:1445 121:0.359375:1443:1444 "
    s .= "~0.04122612914095052 ~-0.030530097927035683 181:0.296875:1446:1447 ~0.03790484212169043 ~-0.04380915608524198 251:0.953125:1449:1450 ~-0.04859338588140705 ~0.022538435699052405 42:0.296875:1452:1453 "
    s .= "~-0.04909181599933363 218:0.09375:1454:1457 244:0.905:1455:1456 ~-0.038310320342724 ~0.046140177042928256 ~-0.05203479362994262 253:-0.025641025641031472:1459:1480 244:0.88:1460:1467 127:0.9375:1461:1466 "
    s .= "251:0.953125:1462:1463 ~-0.052641311458591605 243:1.25:1464:1465 ~0.07061707481597417 ~-0.05432903852012581 ~0.10780370035559386 252:0.125:1468:1475 248:0.375:1469:1474 125:0.109375:1470:1471 ~0.03465009378303254 "
    s .= "106:1.03125:1472:1473 ~-0.07383517887804143 ~0.03558094596148045 ~-0.04879875160379754 124:-0.453125:1476:1477 ~-0.04041539184407862 243:2.3499999999999996:1478:1479 ~0.048944942280594955 ~-0.034013174739275856 "
    s .= "251:1.140625:1481:1500 244:1.675:1482:1495 23:-0.015625:1483:1494 220:-0.09375:1484:1485 ~-0.05124173235975774 109:0.921875:1486:1491 114:0.5078125:1487:1490 130:0.15625:1488:1489 ~0.01009131734428663 "
    s .= "~-0.042337320684417604 ~0.0686430727129812 187:0.28125:1492:1493 ~0.04265368983587495 ~-0.025588721929864236 ~-0.04914602996527309 245:1.6494845360824741:1496:1497 ~0.06281376057342995 212:-0.65625:1498:1499 "
    s .= "~0.05451305219151792 ~-0.04495053095820208 241:0.44:1501:1504 149:-0.4375:1502:1503 ~0.041128797691659946 ~-0.03467007929622454 ~0.04621062238762328 248:0.625:1506:1545 244:0.865:1507:1514 44:-0.078125:1508:1513 "
    s .= "246:0.109375:1509:1510 ~-0.05095177897824679 197:0.34375:1511:1512 ~0.07693034396614704 ~-0.049962980095411794 ~-0.05243428615377415 253:-0.008888888888890278:1515:1528 211:-0.4375:1516:1517 ~-0.039937539991445066 "
    s .= "31:0.234375:1518:1521 205:-0.296875:1519:1520 ~-0.017923527707852993 ~0.04864466131916902 251:0.421875:1522:1523 ~-0.06134436004312608 97:-0.28125:1524:1527 257:0.35714285714285715:1525:1526 ~0.03306765256856519 "
    s .= "~-0.2605574268252541 ~0.03462564135894897 226:-0.140625:1529:1532 171:0.265625:1530:1531 ~-0.04298594529854537 ~0.04674400901198295 217:0.390625:1533:1544 139:0.015625:1534:1537 61:0.171875:1535:1536 "
    s .= "~-0.03169697001910351 ~0.03199215402046545 43:0.296875:1538:1541 121:0.3125:1539:1540 ~0.038365914162835246 ~-0.011993844551112146 251:0.421875:1542:1543 ~-0.05890642789924745 ~0.015567145114082599 "
    s .= "~-0.037302048761295135 251:0.828125:1546:1547 ~-0.049317542826713294 195:0.234375:1548:1549 ~-0.03421199214437346 8:0.21875:1550:1551 ~0.05185054991493418 ~-0.03855023035350435 248:0.625:1553:1592 244:0.935:1554:1565 "
    s .= "35:-0.09375:1555:1562 246:-0.234375:1556:1557 ~-0.04415544311504837 47:-0.03125:1558:1561 81:-0.0234375:1559:1560 ~-0.042891064984752716 ~0.05844523254552723 ~-0.055818821631258175 251:1.359375:1563:1564 "
    s .= "~-0.050794752631919585 ~0.02404576372659818 253:-0.008888888888890278:1566:1573 252:0.125:1567:1570 211:-0.046875:1568:1569 ~-0.03288913398127964 ~0.0287591813954695 31:0.734375:1571:1572 ~0.04911766142813896 "
    s .= "~-0.030607614157868415 163:-0.109375:1574:1577 117:0.21875:1575:1576 ~-0.045209226348650225 ~0.03298079774306873 249:1.1666666666666665:1578:1591 67:0.1875:1579:1586 233:0.53125:1580:1585 196:0.3125:1581:1584 "
    s .= "243:1.65:1582:1583 ~0.0414983786138273 ~-0.046567190124026964 ~-0.01223884186383758 ~-0.05746565246965665 3:0.21875:1587:1590 97:-0.046875:1588:1589 ~-0.06617966737753987 ~-0.010750928812777772 ~0.04213496316431495 "
    s .= "~-0.04966879364284528 42:0.296875:1593:1594 ~-0.04709950454303316 218:0.125:1595:1598 231:0.015625:1596:1597 ~-0.0379819522547346 ~0.045274448375874084 ~-0.051747762637542105 248:0.625:1600:1639 244:0.935:1601:1612 "
    s .= "20:-0.046875:1602:1609 55:0.203125:1603:1608 197:0.25:1604:1607 246:-0.234375:1605:1606 ~-0.01999721626902112 ~0.059457498474964 ~-0.03676421845221354 ~-0.05023124192844456 251:1.078125:1610:1611 ~-0.05358978468408185 "
    s .= "~0.011709523843820267 253:-0.008888888888890278:1613:1624 252:0.125:1614:1621 109:0.8125:1615:1618 144:0.078125:1616:1617 ~-0.059096824633063975 ~0.02258824422443 232:-0.3125:1619:1620 ~-0.07561707832943475 "
    s .= "~0.03733973581136607 31:0.734375:1622:1623 ~0.04843422154095447 ~-0.02927189268130246 163:-0.109375:1625:1628 117:0.21875:1626:1627 ~-0.0441010457434185 ~0.03164306829159513 249:1.1666666666666665:1629:1638 "
    s .= "187:0.328125:1630:1633 191:0.578125:1631:1632 ~0.03022525701715442 ~-0.05748084411099198 244:1.115:1634:1635 ~-0.05485255818146539 67:0.859375:1636:1637 ~0.03136903390339641 ~-0.051544775487836585 ~-0.04826819581367289 "
    s .= "251:0.828125:1640:1641 ~-0.04802024228511601 195:0.234375:1642:1643 ~-0.0317710873643672 8:0.21875:1644:1645 ~0.050599747283409394 ~-0.03627428755971711 248:0.625:1647:1686 244:0.935:1648:1657 47:-0.046875:1649:1656 "
    s .= "55:0.203125:1650:1655 4:-0.09375:1651:1654 153:0.8359375:1652:1653 ~-0.05276745536746014 ~0.11314453242703193 ~0.036822117095177014 ~-0.04888870055679845 ~-0.047209453655561444 253:-0.008888888888890278:1658:1671 "
    s .= "252:0.125:1659:1664 109:0.8125:1660:1661 ~-0.032189892037978306 232:-0.3125:1662:1663 ~-0.07374476639450621 ~0.03635783102916481 243:2.25:1665:1670 251:0.140625:1666:1667 ~-0.046955217549161175 121:-0.578125:1668:1669 "
    s .= "~-0.08154705729464849 ~0.04961071990599853 ~-0.031230315755532086 211:-0.09375:1672:1677 4:0.03125:1673:1674 ~-0.041022545802132306 202:0.203125:1675:1676 ~0.03224528744695682 ~-0.055088375731295595 31:0.09375:1678:1683 "
    s .= "193:0.265625:1679:1682 243:1.45:1680:1681 ~0.03557405155114843 ~-0.03164963285875731 ~-0.01946402094763244 251:0.421875:1684:1685 ~-0.049045130072892115 ~0.012892598156471733 251:0.828125:1687:1688 ~-0.04730328043904264 "
    s .= "217:-0.09375:1689:1690 ~-0.046348715700684245 243:0.55:1691:1692 ~-0.028668968503017783 ~0.03338944306728865 251:0.734375:1694:1717 248:0.375:1695:1710 31:0.1875:1696:1709 128:0.34375:1697:1708 243:1.45:1698:1707 "
    s .= "193:0.265625:1699:1706 253:0:1700:1703 217:-0.25:1701:1702 ~-0.020648722942904513 ~0.0444705710548943 244:1.405:1704:1705 ~-0.043476281133646606 ~0.04552186291586267 ~-0.0353231847222119 ~-0.05699976849406102 "
    s .= "~-0.04902660950415208 ~-0.045099395887021776 45:0.3515625:1711:1712 ~-0.04668399967918669 152:0.28125:1713:1716 244:0.935:1714:1715 ~-0.01483386928622711 ~0.05513424479961553 ~-0.0541280136304851 252:0.125:1718:1727 "
    s .= "194:-0.140625:1719:1722 229:-0.140625:1720:1721 ~-0.031583845944487425 ~0.03536457081437685 242:0.8500000000000001:1723:1724 ~-0.04856355879673241 11:0.421875:1725:1726 ~-0.05467168235493022 ~0.05709507127017441 "
    s .= "245:1.1547619047619047:1728:1729 ~-0.05461124833144124 20:0.71875:1730:1739 130:1.96875:1731:1738 243:1.45:1732:1733 ~0.05107672245812749 251:1.796875:1734:1737 244:1.1:1735:1736 ~-0.04666202218343949 "
    s .= "~0.036256409590718346 ~0.04925922973529416 ~-0.004362135953290556 ~-0.05654531997242976 253:-0.025641025641031472:1741:1760 248:0.375:1742:1751 256:0.9181818181818182:1743:1750 243:2.1500000000000004:1744:1749 "
    s .= "252:0.175:1745:1748 235:-0.140625:1746:1747 ~-0.03602280663673937 ~0.03250937137063039 ~0.04888843538838711 ~-0.03607626992890692 ~-0.03749699428274056 192:0.28125:1752:1757 252:0.225:1753:1754 ~-0.05018870845103081 "
    s .= "244:0.97:1755:1756 ~-0.04471050823156634 ~0.027643262584485913 194:0.40625:1758:1759 ~0.04478246075926065 ~-0.052570344732406495 249:1.1666666666666665:1761:1786 244:0.835:1762:1763 ~-0.04631791117703731 "
    s .= "251:0.265625:1764:1769 64:0.265625:1765:1768 229:0.953125:1766:1767 ~-0.017379393330746624 ~0.05105671671724722 ~-0.056676886987448105 235:-0.265625:1770:1771 ~-0.030154493875570034 236:0.59375:1772:1785 "
    s .= "85:1.171875:1773:1782 251:1.828125:1774:1779 156:0.5859375:1775:1778 133:0.234375:1776:1777 ~0.03963308590027334 ~-0.009980430700901944 ~0.06189165944641896 243:0.6499999999999999:1780:1781 ~-0.03416742486290474 "
    s .= "~0.059604369102331384 241:0.6:1783:1784 ~0.061318892506871975 ~-0.002901893620836704 ~-0.05045506505208729 ~-0.0507011837537552 251:0.734375:1788:1809 248:0.375:1789:1804 31:0.1875:1790:1803 128:0.34375:1791:1802 "
    s .= "243:1.45:1792:1801 193:0.265625:1793:1800 253:0:1794:1797 217:-0.25:1795:1796 ~-0.01994924388889776 ~0.04298855364985622 244:1.405:1798:1799 ~-0.041473792791860115 ~0.04415704074337899 ~-0.03394774138578102 "
    s .= "~-0.055935494490043675 ~-0.047755345553185564 ~-0.0436933704622626 45:0.3515625:1805:1806 ~-0.04538769076050483 161:0.234375:1807:1808 ~0.03504856521701585 ~-0.04786103216272345 252:0.125:1810:1819 "
    s .= "194:-0.140625:1811:1814 229:-0.140625:1812:1813 ~-0.02978424673131194 ~0.03362078914615634 242:0.8500000000000001:1815:1816 ~-0.04680526278168521 11:0.421875:1817:1818 ~-0.052267030726525665 ~0.055787754549968566 "
    s .= "245:1.1547619047619047:1820:1821 ~-0.05320896561259497 41:0.625:1822:1833 130:1.875:1823:1830 243:1.45:1824:1825 ~0.05065925491122093 251:1.796875:1826:1829 253:-0.04403409090909091:1827:1828 ~0.019979958215552082 "
    s .= "~-0.05712995422389312 ~0.04805634973524686 245:2.13953488372093:1831:1832 ~0.04690614843152343 ~-0.028188010809588243 ~-0.04439186196498312 248:0.625:1835:1874 244:0.82:1836:1837 ~-0.042881495368231354 "
    s .= "253:-0.025641025641031472:1838:1851 252:0.125:1839:1844 196:-0.1875:1840:1841 ~-0.0526657758230206 128:0.125:1842:1843 ~0.03267032304718241 ~-0.026403619650927745 31:0.25:1845:1846 ~0.046752888754490136 "
    s .= "192:0.0625:1847:1850 85:1.453125:1848:1849 ~-0.04693867749858741 ~0.05241816474152997 ~0.04338824999647023 226:-0.296875:1852:1855 256:0.5714285714285714:1853:1854 ~-0.05227162215397786 ~0.03658133691337614 "
    s .= "251:0.734375:1856:1865 241:0.54:1857:1864 121:0.234375:1858:1863 109:0.9375:1859:1862 238:-0.078125:1860:1861 ~0.0387625199168969 ~-0.025918418493566017 ~0.04722179226859502 ~-0.0402005666921178 ~-0.0560095616628897 "
    s .= "241:0.2:1866:1869 104:-0.140625:1867:1868 ~0.023816166925100052 ~-0.04728720348477799 130:2.046875:1870:1873 203:0.640625:1871:1872 ~0.04341679807327334 ~-0.04374991624316634 ~-0.047464205207312676 42:0.25:1875:1876 "
    s .= "~-0.044225386293191365 194:0.21875:1877:1880 85:0.734375:1878:1879 ~-0.006293189592602203 ~0.061748035418592064 ~-0.05021087885073492 251:0.734375:1882:1901 248:0.375:1883:1894 31:0.1875:1884:1893 128:0.34375:1885:1892 "
    s .= "243:1.45:1886:1891 97:0.25:1887:1890 175:-0.1875:1888:1889 ~-0.02766342780438214 ~0.03722412466669158 ~-0.032586535554810926 ~-0.054841862173719724 ~-0.046391480222050474 ~-0.04199532773739398 45:0.3515625:1895:1898 "
    s .= "244:1.975:1896:1897 ~-0.045824410369383284 ~0.02065943614889411 152:0.28125:1899:1900 ~0.029323771484926583 ~-0.05253615279495279 252:0.175:1902:1915 194:-0.15625:1903:1908 229:-0.140625:1904:1905 ~-0.02509757172230642 "
    s .= "157:-0.0625:1906:1907 ~-0.03824027686452404 ~0.0399222533934683 100:-0.109375:1909:1910 ~-0.061273676326274465 176:0.484375:1911:1914 217:-0.125:1912:1913 ~-0.048529639854546 ~0.01574589202613012 ~-0.05901466390875065 "
    s .= "245:1.1547619047619047:1916:1917 ~-0.05128784511116441 243:1.45:1918:1923 130:1.90625:1919:1922 47:0.734375:1920:1921 ~0.051194894258654894 ~-0.04233358567129457 ~0.005328077975826688 251:1.890625:1924:1927 "
    s .= "244:1.095:1925:1926 ~-0.04731133174886363 ~0.028979404385209795 ~0.047093955688161 248:0.625:1929:1970 244:0.935:1930:1939 20:-0.046875:1931:1938 55:0.203125:1932:1937 243:1.45:1933:1936 67:-0.078125:1934:1935 "
    s .= "~-0.041923579730395164 ~0.04139589223068689 ~-0.050504200011589485 ~-0.04634990736692535 ~-0.04477102289791818 253:-0.008888888888890278:1940:1951 252:0.175:1941:1948 109:0.859375:1942:1945 144:0.078125:1943:1944 "
    s .= "~-0.050534509892091406 ~0.023123979479267007 235:-0.125:1946:1947 ~-0.03868946049358475 ~0.04161554773570841 243:2.1500000000000004:1949:1950 ~0.04680256979977276 ~-0.022687835055073047 249:1.5:1952:1969 "
    s .= "243:1.45:1953:1966 31:0.078125:1954:1961 241:0.16:1955:1960 154:0.65625:1956:1959 40:0.015625:1957:1958 ~-0.05366957993695962 ~0.017490974373381606 ~0.051059369998882734 ~0.037667471734503744 251:1.015625:1962:1965 "
    s .= "248:0.125:1963:1964 ~-0.05341761164098918 ~0.0023732945856053305 ~0.02975701225896693 251:2.046875:1967:1968 ~-0.057128177998322094 ~0.04854917784232148 ~-0.05541002752146923 64:-0.0625:1971:1972 ~-0.05047539289477785 "
    s .= "88:1.359375:1973:1974 ~-0.03140013096660689 ~0.053599629027550125 249:1.5:1976:2021 244:0.865:1977:1984 251:1.046875:1978:1979 ~-0.04216907419865586 254:0.734375:1980:1983 89:1.15625:1981:1982 ~-0.05165360089664061 "
    s .= "~0.08235236261806334 ~0.1385887269984109 253:-0.05687830687830658:1985:1994 243:0.45:1986:1987 ~-0.02264182728287422 31:0.21875:1988:1991 218:0.625:1989:1990 ~0.04765356212044859 ~-0.10646966185115006 "
    s .= "88:0.296875:1992:1993 ~-0.03910813280823246 ~0.030420473459402398 251:1.765625:1995:2018 243:1.45:1996:2017 193:0.265625:1997:2016 85:1.171875:1998:2011 133:0.234375:1999:2002 244:1.545:2000:2001 ~0.0529231799155229 "
    s .= "~-0.07143990934075652 244:1.505:2003:2008 242:0.75:2004:2005 ~-0.03215985733791204 154:0.28125:2006:2007 ~0.051202402783863135 ~-0.01660559591176797 184:0.1875:2009:2010 ~-0.014516006917256056 ~0.04860194229902652 "
    s .= "235:-0.171875:2012:2013 ~-0.029033558770662007 28:1.109375:2014:2015 ~0.053450177058607086 ~-0.03943651758667874 ~-0.027880761015352654 ~-0.05534615979820012 243:0.6499999999999999:2019:2020 ~-0.030491564439224697 "
    s .= "~0.052014036769413866 ~-0.04985679570379645 251:0.734375:2023:2050 249:1.1666666666666665:2024:2049 244:0.94:2025:2032 17:-0.03125:2026:2031 154:0.21875:2027:2030 195:0.328125:2028:2029 ~-0.012082950667775323 "
    s .= "~0.07198300200834316 ~-0.047788641915746666 ~-0.04890965171415766 31:0.15625:2033:2046 85:0.78125:2034:2041 208:0.890625:2035:2040 106:0.09375:2036:2037 ~-0.03898656702613831 255:0.265625:2038:2039 ~0.016058244747832042 "
    s .= "~-0.04184664408713365 ~0.049729486034968226 252:2.925:2042:2045 160:-0.125:2043:2044 ~-0.03465308867169122 ~0.04770441503184425 ~-0.055257246299304064 99:0.234375:2047:2048 ~-0.03618051757177126 ~0.035212667059052176 "
    s .= "~-0.05160450184324142 252:0.175:2051:2060 194:-0.15625:2052:2055 229:-0.140625:2053:2054 ~-0.023139191447614317 ~0.03295324634627891 100:-0.109375:2056:2057 ~-0.060203656031541736 176:0.484375:2058:2059 "
    s .= "~-0.00012451559114257509 ~-0.05772705638167929 243:1.45:2061:2066 38:0.5625:2062:2065 130:1.90625:2063:2064 ~0.049200918880769245 ~0.0046178636709851865 ~-0.022798864677995603 244:0.96:2067:2068 ~-0.0418959167596546 "
    s .= "~0.024656676849808223 249:1.5:2070:2113 244:0.82:2071:2072 ~-0.04277990353279168 253:-0.048465909090907644:2073:2086 31:0.21875:2074:2081 243:0.45:2075:2078 181:0.40625:2076:2077 ~-0.049958476024933654 "
    s .= "~0.04417135836275135 218:0.625:2079:2080 ~0.045529134133002004 ~-0.07939884885731463 85:0.71875:2082:2085 251:1.796875:2083:2084 ~-0.04688292914718223 ~0.04673915986650533 ~0.03544090151902835 251:0.265625:2087:2094 "
    s .= "67:0.203125:2088:2093 163:-0.015625:2089:2090 ~-0.0436421550368202 193:0.140625:2091:2092 ~0.02864114544578485 ~-0.04416011200464932 ~-0.05718911886022261 166:-0.328125:2095:2096 ~-0.03742514228233856 "
    s .= "236:0.59375:2097:2112 113:0.765625:2098:2111 85:1.171875:2099:2106 133:0.234375:2100:2101 ~0.03677125754403532 157:0.8125:2102:2103 ~-0.015254218052743365 184:-0.0625:2104:2105 ~-0.04064534794880327 "
    s .= "~0.030421162379783224 241:0.86:2107:2110 214:-0.25:2108:2109 ~-0.0441900240414084 ~0.05531461718435124 ~-0.010109687498624908 ~0.05260785114214023 ~-0.045741969395948934 30:0.3515625:2114:2115 ~-0.0527886449925902 "
    s .= "~0.011661386464545282 249:1.5:2117:2160 244:0.82:2118:2119 ~-0.04210970025253228 253:-0.05687830687830658:2120:2129 252:0.125:2121:2126 146:0.140625:2122:2123 ~0.025335825844613153 106:1.453125:2124:2125 "
    s .= "~-0.06570573052801758 ~0.044477898604766704 243:1.45:2127:2128 ~0.04604695135662706 ~0.006387136007882821 251:1.828125:2130:2157 243:1.25:2131:2156 121:0.3125:2132:2153 85:1.171875:2133:2146 133:0.15625:2134:2137 "
    s .= "244:1.43:2135:2136 ~0.05949094671782417 ~-0.05892937646828052 205:0.90625:2138:2145 190:-0.109375:2139:2140 ~-0.05027705681090083 241:0.12:2141:2142 ~-0.030242535303026664 151:0.15625:2143:2144 ~0.022416330643910798 "
    s .= "~-0.012725561720586608 ~0.05091692961374074 241:0.66:2147:2150 232:-0.21875:2148:2149 ~-0.05329966395678645 ~0.05601020585998841 251:0.484375:2151:2152 ~-0.05801944942531504 ~0.031194782252171212 251:0.484375:2154:2155 "
    s .= "~-0.049862674131222924 ~-0.0017213538726782943 ~-0.04444576459772345 243:0.6499999999999999:2158:2159 ~-0.032322346083470684 ~0.051308250057594255 30:0.3515625:2161:2162 ~-0.052414857543822926 ~0.011062659989924777 "
    s .= "249:1.5:2164:2207 244:0.82:2165:2166 ~-0.04143715514576803 253:-0.04973404255318883:2167:2176 31:0.21875:2168:2173 243:0.45:2169:2170 ~-0.014335364247712402 224:0.640625:2171:2172 ~0.04482076296073113 "
    s .= "~-0.06316647210615692 85:0.71875:2174:2175 ~-0.027407073900238894 ~0.03333331462965023 251:0.265625:2177:2188 67:0.203125:2178:2187 241:0.4:2179:2186 124:0.171875:2180:2185 106:0.375:2181:2184 205:0.765625:2182:2183 "
    s .= "~-0.038887979124203415 ~0.054535332778410085 ~0.055426544775343235 ~-0.03907792347009438 ~-0.057631620177011525 ~-0.055987683670992876 232:-0.15625:2189:2192 133:0.453125:2190:2191 ~0.016985676206926717 "
    s .= "~-0.03537438142735702 236:0.578125:2193:2206 248:0.875:2194:2205 243:1.45:2195:2202 85:0.734375:2196:2201 245:2.217391304347826:2197:2200 238:0.40625:2198:2199 ~0.033108010593684185 ~-0.021521686291925825 "
    s .= "~-0.024751326547400015 ~0.04277324949400494 137:0.59375:2203:2204 ~-0.04437288829439137 ~0.04702388216578258 ~-0.02109650087478066 ~-0.045968737242786745 30:0.3515625:2208:2209 ~-0.05204286257311073 ~0.01049543196190775 "
    s .= "251:0.796875:2211:2238 249:1.1666666666666665:2212:2237 244:0.955:2213:2222 245:1.7572815533980584:2214:2219 127:0.9375:2215:2216 ~-0.0476130179444657 157:0.203125:2217:2218 ~0.11754470656539265 ~-0.061085510307091744 "
    s .= "133:0.28125:2220:2221 ~0.059474450272195646 ~-0.02191309436293342 31:0.15625:2223:2232 85:0.78125:2224:2229 208:0.890625:2225:2228 106:0.171875:2226:2227 ~-0.03412914265536886 ~0.008314329649131955 ~0.04814289537379408 "
    s .= "214:-0.25:2230:2231 ~-0.055535856759869585 ~0.042247143038889455 251:0.265625:2233:2234 ~-0.050284940967792485 190:-0.0625:2235:2236 ~-0.04781537530995963 ~0.013259658608747156 ~-0.04993740986103929 252:0.175:2239:2248 "
    s .= "146:-0.203125:2240:2243 166:-0.296875:2241:2242 ~-0.05077597707792706 ~0.029355949064337406 100:-0.109375:2244:2245 ~-0.05978318843713154 176:0.484375:2246:2247 ~-0.0020274591891505105 ~-0.057995627653984166 "
    s .= "243:1.45:2249:2252 245:1.1547619047619047:2250:2251 ~-0.04053419799505024 ~0.04630853681723706 244:0.915:2253:2254 ~-0.05531488524470283 19:0.390625:2255:2256 ~0.030466571111919583 ~-0.07122938869082752 "
    s .= "249:1.5:2258:2301 244:0.82:2259:2260 ~-0.040191107912013024 253:-0.05687830687830658:2261:2272 88:0.796875:2262:2271 31:0.203125:2263:2270 218:0.578125:2264:2269 241:0.22:2265:2268 245:1.8571428571428572:2266:2267 "
    s .= "~0.04907920512090033 ~-0.07001356464018621 ~0.03759040077809728 ~-0.06972053575601296 ~-0.018125727439529823 ~0.04786834121858857 251:1.765625:2273:2298 243:1.25:2274:2297 121:0.3125:2275:2294 85:1.171875:2276:2289 "
    s .= "133:0.15625:2277:2280 244:1.43:2278:2279 ~0.056728391984832906 ~-0.056799610218035736 184:1.015625:2281:2288 190:-0.109375:2282:2283 ~-0.047750440436478025 241:0.16:2284:2285 ~-0.02419393611822255 130:0.171875:2286:2287 "
    s .= "~0.049843599394152026 ~-0.0030000755496411373 ~0.04061842567512577 241:0.66:2290:2293 232:-0.21875:2291:2292 ~-0.05126844907120923 ~0.054071411749747014 ~-0.013160856423144622 251:0.484375:2295:2296 "
    s .= "~-0.04802210949126169 ~-0.00228181655971654 ~-0.04386938110343471 243:0.6499999999999999:2299:2300 ~-0.028597142648122464 ~0.048740552264362524 30:0.3203125:2302:2303 ~-0.05164248172876606 ~0.008201955570422468 "
    s .= "249:1.5:2305:2348 244:0.82:2306:2309 156:0.7734375:2307:2308 ~-0.04225090726024952 ~0.04288305983597468 253:-0.04973404255318883:2310:2319 88:0.796875:2311:2318 31:0.1875:2312:2315 218:0.578125:2313:2314 "
    s .= "~0.03157878138660369 ~-0.06899073097733166 251:1.796875:2316:2317 ~-0.03466125047906668 ~0.044049549082364206 ~0.04702751517806322 251:1.765625:2320:2345 243:1.25:2321:2344 193:0.265625:2322:2341 85:1.171875:2323:2336 "
    s .= "133:0.234375:2324:2327 244:1.43:2325:2326 ~0.052124892564208214 ~-0.05548861217142131 244:1.505:2328:2333 130:0.15625:2329:2332 73:-0.09375:2330:2331 ~-0.04985632324960671 ~0.03760168453816767 ~-0.025107123955592205 "
    s .= "245:1.8529411764705883:2334:2335 ~0.05083930899984841 ~-0.007011761942051872 235:-0.234375:2337:2338 ~-0.037018324193098424 241:0.66:2339:2340 ~0.05326172351121135 ~-0.0038800499505973647 144:0.125:2342:2343 "
    s .= "~-0.04127481328709546 ~0.011192940634238618 ~-0.0444177990494785 243:0.6499999999999999:2346:2347 ~-0.026949609283291504 ~0.04779663513939789 30:0.3203125:2349:2350 ~-0.051285222149261935 ~0.007783170842648151 "
    s .= "251:0.734375:2352:2375 249:1.1666666666666665:2353:2374 244:0.94:2354:2361 17:-0.046875:2355:2360 154:0.21875:2356:2359 195:0.328125:2357:2358 ~-0.00824097563142773 ~0.07264275816527255 ~-0.04612972577661831 "
    s .= "~-0.045946655407909404 243:1.15:2362:2373 28:0.03125:2363:2368 85:0.9375:2364:2367 220:0.203125:2365:2366 ~0.025252376289740003 ~-0.03281598469633467 ~0.04842973441453846 253:-0.06666666666666857:2369:2370 "
    s .= "~0.03358658607774759 133:0.1875:2371:2372 ~0.051295143838498924 ~-0.0273062675710137 ~-0.037521792617912615 ~-0.049418252332727224 252:0.175:2376:2387 146:-0.203125:2377:2382 166:-0.296875:2378:2379 ~-0.0448972972086192 "
    s .= "243:0.35:2380:2381 ~-0.01478119486307894 ~0.03832375867196347 100:-0.09375:2383:2384 ~-0.05595943762662762 176:0.484375:2385:2386 ~-0.0001725748496918506 ~-0.056148887650385906 243:1.45:2388:2393 224:0.65625:2389:2392 "
    s .= "241:0.4:2390:2391 ~-0.0003437772392049424 ~0.04673640397361367 ~-0.02610466176357634 244:0.915:2394:2395 ~-0.05465114228787206 19:0.390625:2396:2397 ~0.026553850077925652 ~-0.06844866523414 249:1.5:2399:2442 "
    s .= "244:0.82:2400:2407 23:-0.15625:2401:2406 247:0.453125:2402:2403 ~-0.039964524598535445 209:0.21875:2404:2405 ~0.10201196582802625 ~-0.04083022842546491 ~-0.04784033639676942 253:-0.05687830687830658:2408:2417 "
    s .= "88:0.796875:2409:2416 252:0.32499999999999996:2410:2415 98:0.109375:2411:2412 ~0.0181984921866086 222:0.15625:2413:2414 ~-0.030348172577677458 ~-0.1365707608505613 ~0.03683499601498394 ~0.04661874525498391 "
    s .= "251:1.828125:2418:2439 243:1.45:2419:2438 217:0.296875:2420:2437 167:0.515625:2421:2436 130:0.171875:2422:2425 241:0.16:2423:2424 ~-0.0034251977387974664 ~0.05880167587260798 31:0.046875:2426:2433 157:0.703125:2427:2430 "
    s .= "243:0.35:2428:2429 ~-0.03226047247930851 ~0.02393090002486875 214:-0.234375:2431:2432 ~-0.05938214362456689 ~0.042275954529752906 97:0:2434:2435 ~-0.0441716138025372 ~0.0009550015910243268 ~-0.041688900072955 "
    s .= "~-0.02914280562041805 ~-0.04774535527548035 243:0.6499999999999999:2440:2441 ~-0.029059127259871614 ~0.04801580404654484 168:0.28125:2443:2444 ~-0.05040280307831352 ~0.012894864048057562 251:0.796875:2446:2473 "
    s .= "249:1.1666666666666665:2447:2472 244:0.805:2448:2451 90:0.7265625:2449:2450 ~-0.048191005801924564 ~0.04865461921034758 31:0.15625:2452:2469 217:0.25:2453:2466 243:1.45:2454:2465 85:0.734375:2455:2462 "
    s .= "133:0.1875:2456:2457 ~0.05606376470789434 184:0.609375:2458:2461 11:0.453125:2459:2460 ~-0.0237372405119416 ~0.048842088203088135 ~0.040975483219897336 214:-0.25:2463:2464 ~-0.06456766734481614 ~0.043120655827718124 "
    s .= "~-0.04223921203537356 163:0.328125:2467:2468 ~-0.0018692749436962728 ~-0.05895913408995804 129:0.3046875:2470:2471 ~-0.03343235953246718 ~0.026501037940052555 ~-0.04819410962484311 252:0.175:2474:2483 "
    s .= "149:-0.421875:2475:2478 166:-0.28125:2476:2477 ~-0.046324092470271555 ~0.03850187315483576 223:-0.171875:2479:2480 ~-0.05395840424012696 74:0.125:2481:2482 ~0.0021660031841615876 ~-0.04517589434255001 243:1.45:2484:2487 "
    s .= "227:0.734375:2485:2486 ~0.04397836310538312 ~-0.04309206614862227 244:0.905:2488:2489 ~-0.05614808837628874 19:0.390625:2490:2491 ~0.026372007673308467 ~-0.0659759544052793 249:1.5:2493:2536 244:0.82:2494:2495 "
    s .= "~-0.03726411297598258 251:0.296875:2496:2505 67:0.203125:2497:2504 241:0.66:2498:2503 244:1.16:2499:2500 ~-0.023940750013513628 245:1.96:2501:2502 ~0.047842533555537387 ~-0.00959603914932081 ~-0.0556859764478502 "
    s .= "~-0.05182612439962745 88:0.796875:2506:2531 251:1.765625:2507:2528 133:0.234375:2508:2511 230:0.71875:2509:2510 ~0.03987059026937154 ~-0.06139506955547507 244:1.505:2512:2523 144:0.140625:2513:2520 245:1.5625:2514:2517 "
    s .= "97:-0.265625:2515:2516 ~-0.1567520384594672 ~-0.05243089804031344 190:-0.140625:2518:2519 ~-0.0594107859152102 ~-0.010985807968175254 176:0.59375:2521:2522 ~0.015059569344031807 ~-0.05714047199219882 "
    s .= "245:1.990909090909091:2524:2525 ~0.045574926332757025 190:0.015625:2526:2527 ~-0.04606928088336654 ~0.021389117947575653 241:0.52:2529:2530 ~-0.015119190604905403 ~0.048126269463767316 193:-0.21875:2532:2533 "
    s .= "~-0.029649192299051996 233:0.625:2534:2535 ~0.04387282880298542 ~-0.05577618581635649 30:0.3046875:2537:2538 ~-0.05034601059820944 ~0.008336881571186694 249:1.5:2540:2583 244:0.805:2541:2542 ~-0.03846055154637637 "
    s .= "253:-0.05687830687830658:2543:2554 88:0.796875:2544:2553 248:0.125:2545:2546 ~0.03378954079556133 257:0.4375:2547:2550 122:0.09375:2548:2549 ~0.026028277043377603 ~-0.026908545391558892 224:-0.015625:2551:2552 "
    s .= "~-0.048652572147278035 ~-0.20092620033596453 ~0.04541848885799811 251:0.265625:2555:2566 67:0.203125:2556:2565 241:0.4:2557:2564 193:0.140625:2558:2563 106:0.375:2559:2562 160:0.875:2560:2561 ~-0.046223387843307956 "
    s .= "~0.0443221519212737 ~0.04705478489422096 ~-0.03786941681327228 ~-0.055536211550313234 ~-0.05299511949497043 236:0.59375:2567:2582 113:0.765625:2568:2581 243:1.35:2569:2580 85:0.734375:2570:2577 139:0.5:2571:2574 "
    s .= "157:0.8125:2572:2573 ~-0.02452564009394616 ~0.019067173642162993 130:0.1875:2575:2576 ~0.05238590909816181 ~0.004558964775969488 214:-0.3125:2578:2579 ~-0.04837366737127911 ~0.03462423540730351 ~-0.03368680606612006 "
    s .= "~0.04714700809467942 ~-0.042563561058046595 30:0.3046875:2584:2585 ~-0.049988829883800934 ~0.00791092681549771 251:0.796875:2587:2610 232:-0.125:2588:2589 ~-0.04210722271809885 109:0.734375:2590:2603 "
    s .= "156:0.6640625:2591:2600 245:1.57:2592:2595 244:1.4:2593:2594 ~-0.054318265993474106 ~0.05887692767942568 219:0.140625:2596:2597 ~-0.0345068027339497 181:0.21875:2598:2599 ~0.03876291268129048 ~-0.029812792385734723 "
    s .= "107:0.25:2601:2602 ~0.07262991460853468 ~-0.04531619686298685 121:0.359375:2604:2609 217:-0.171875:2605:2606 ~-0.034610920858719856 50:-0.109375:2607:2608 ~0.04233563755421808 ~0.013672638728447456 ~-0.03677672401343309 "
    s .= "252:0.175:2611:2620 149:-0.421875:2612:2615 187:-0.140625:2613:2614 ~-0.03424232899144861 ~0.03816990928167924 223:-0.171875:2616:2617 ~-0.05289979412008347 74:0.125:2618:2619 ~0.0016545925466029514 "
    s .= "~-0.042351852615686726 243:1.45:2621:2628 32:0.578125:2622:2627 241:0.42:2623:2626 31:0.078125:2624:2625 ~0.03902406587450863 ~-0.05271382703467775 ~0.04667762802660307 ~-0.02205472767867568 49:-0.296875:2629:2630 "
    s .= "~-0.06383930153952423 245:1.3118279569892473:2631:2632 ~-0.03950817325663562 ~0.030115948047734833 249:1.5:2634:2677 244:0.805:2635:2638 156:0.7734375:2636:2637 ~-0.040821653820486636 ~0.04657341838432069 "
    s .= "253:-0.05687830687830658:2639:2644 88:0.796875:2640:2643 31:0.1875:2641:2642 ~0.02515035615855306 ~-0.018142958430002503 ~0.04466371163794756 251:0.265625:2645:2654 67:0.203125:2646:2653 241:0.4:2647:2652 "
    s .= "106:0.34375:2648:2649 ~-0.02004456431942804 121:0.265625:2650:2651 ~0.04792123330404866 ~-0.04521884452487162 ~-0.0544821861201357 ~-0.05185722329615792 226:-0.421875:2655:2656 ~-0.04367672806493515 "
    s .= "203:0.65625:2657:2676 113:0.765625:2658:2675 85:1.21875:2659:2674 156:0.5859375:2660:2673 121:-0.171875:2661:2662 ~-0.037963732100449205 139:0:2663:2664 ~-0.024634454580054643 130:0.1875:2665:2668 172:0.21875:2666:2667 "
    s .= "~0.051798681919758977 ~-0.0217283962426313 157:0.8125:2669:2672 238:0.25:2670:2671 ~0.001416247702919672 ~-0.04266558429421688 ~0.025348076861082498 ~0.05449959669076085 ~0.03191481701253376 ~0.04591790091273085 "
    s .= "~-0.04614904739695616 168:0.28125:2678:2679 ~-0.04899995671144066 ~0.014334524555260532 249:1.5:2681:2724 244:0.805:2682:2687 111:0.3359375:2683:2684 ~-0.043200016669442565 23:-0.1875:2685:2686 ~0.08858707459439213 "
    s .= "~-0.03374452899648178 253:-0.05687830687830658:2688:2701 88:0.84375:2689:2698 248:0.125:2690:2691 ~0.032804746897241825 257:0.4375:2692:2697 122:0.09375:2693:2694 ~0.02395801541733371 252:0.275:2695:2696 "
    s .= "~-0.07234189746555122 ~0.013850470455739759 ~-0.0903794330040186 166:0.484375:2699:2700 ~0.04864987176466267 ~-0.019147818703802055 246:0.140625:2702:2713 236:-0.140625:2703:2710 244:1.055:2704:2707 "
    s .= "245:1.8644067796610169:2705:2706 ~-0.051573127852511204 ~0.010154319532513676 85:0.96875:2708:2709 ~0.0026349716975647827 ~0.03610652249728161 63:-0.09375:2711:2712 ~-0.0033014712550941865 ~-0.04946379668560352 "
    s .= "167:0.46875:2714:2721 245:1.96:2715:2720 242:0.25:2716:2717 ~-0.04642607813216875 245:1.1923076923076923:2718:2719 ~-0.045536084823765616 ~0.042657441386003955 ~-0.0019899819724501218 251:1.484375:2722:2723 "
    s .= "~-0.04263769448109894 ~0.02465415830812568 30:0.3046875:2725:2726 ~-0.04919256361426999 ~0.008384598292615756 248:0.875:2728:2771 251:0.734375:2729:2748 188:0.328125:2730:2747 118:0.359375:2731:2744 243:1.45:2732:2743 "
    s .= "193:0.265625:2733:2742 199:-0.1875:2734:2737 245:1.6547619047619047:2735:2736 ~0.01943979215133647 ~-0.05735662764770837 253:0:2738:2739 ~0.03559004367802805 242:0.55:2740:2741 ~0.03489422677275205 ~-0.04359741431136553 "
    s .= "~-0.02878188038159008 ~-0.04924363485301608 142:0.328125:2745:2746 ~-0.0026155260719744576 ~-0.05053325381071595 ~-0.04188783272594511 252:0.225:2749:2762 149:-0.140625:2750:2753 226:-0.3125:2751:2752 "
    s .= "~-0.05317059047906956 ~0.028608188414532165 97:-0.3125:2754:2755 ~-0.08534159081413398 242:0.45:2756:2757 ~-0.03749932386566573 220:-0.078125:2758:2759 ~-0.04300119496958303 227:0.53125:2760:2761 ~0.035788349604607826 "
    s .= "~-0.058799652614792156 243:1.45:2763:2766 38:0.609375:2764:2765 ~0.04404305142343529 ~-0.041918165593855625 49:-0.296875:2767:2768 ~-0.06042402375873941 47:0.4375:2769:2770 ~0.026513380327630627 ~-0.048707003671512705 "
    s .= "225:0.2421875:2772:2773 ~-0.04387448240143474 ~-0.010757555850501511 249:1.5:2775:2818 244:0.805:2776:2783 23:-0.15625:2777:2782 247:0.453125:2778:2779 ~-0.03854340166592615 188:0.3125:2780:2781 ~0.09152173939725063 "
    s .= "~-0.04049888761956577 ~-0.0466539477015607 75:0.1796875:2784:2807 85:1.171875:2785:2802 238:0.328125:2786:2799 163:-0.0625:2787:2790 235:0.0625:2788:2789 ~-0.04283160751444732 ~0.02496204214339681 193:0.25:2791:2798 "
    s .= "249:0.8333333333333333:2792:2797 257:0.8243243243243243:2793:2796 245:2.2375:2794:2795 ~0.03016405862880909 ~-0.006197810463022137 ~-0.023902271965939696 ~-0.02454469668349285 ~-0.02699759000920184 244:1.405:2800:2801 "
    s .= "~-0.05400440351660715 ~0.013790853890340167 238:-0.328125:2803:2804 ~-0.044438481697700725 40:0.875:2805:2806 ~0.03812591991750732 ~-0.03758723474820443 241:0.16:2808:2813 43:0.046875:2809:2810 ~-0.03656216424508432 "
    s .= "3:0.21875:2811:2812 ~-0.0557234424925417 ~0.03790921422130727 203:0.609375:2814:2817 130:2.109375:2815:2816 ~0.040457244016656096 ~-0.06038669332811373 ~-0.025838240187613406 219:0.296875:2819:2820 "
    s .= "~-0.048449786523271934 ~0.010684523018335904 249:1.5:2822:2865 244:0.805:2823:2828 23:-0.15625:2824:2827 247:0.453125:2825:2826 ~-0.03790429962428306 ~0.05169529074631929 ~-0.04629004104932971 251:0.296875:2829:2838 "
    s .= "67:0.203125:2830:2837 241:0.66:2831:2836 244:1.16:2832:2833 ~-0.020879959595072474 245:1.9107142857142858:2834:2835 ~0.04673168688935443 ~-0.008398283147655441 ~-0.05448720782460584 ~-0.048320520938063036 "
    s .= "88:0.796875:2839:2860 133:0.234375:2840:2843 203:0.6875:2841:2842 ~0.03817920138821049 ~-0.058220069136402444 251:1.765625:2844:2859 244:1.49:2845:2856 144:0.0625:2846:2849 245:1.5625:2847:2848 ~-0.08330523113877347 "
    s .= "~-0.022395770108799482 187:-0.078125:2850:2851 ~-0.04285983065110133 167:0.5:2852:2855 255:0.328125:2853:2854 ~0.02830328478799414 ~-0.03840727060000932 ~-0.04730593048614904 245:1.990909090909091:2857:2858 "
    s .= "~0.042419857089111515 ~-0.007353719274703779 ~0.0335393591025019 193:-0.203125:2861:2862 ~-0.027552502520164675 142:0.5:2863:2864 ~0.043641349675753824 ~-0.002179786463974239 168:0.28125:2866:2867 ~-0.047729432985058655 "
    s .= "~0.014938828016783048 248:0.875:2869:2914 211:-0.203125:2870:2875 220:-0.1875:2871:2872 ~-0.04779523597870232 202:0.234375:2873:2874 ~0.010400370917818874 ~-0.05037903782921073 236:0.578125:2876:2913 "
    s .= "251:0.421875:2877:2888 31:0.078125:2878:2887 242:0.6499999999999999:2879:2884 244:1.24:2880:2883 171:0.265625:2881:2882 ~-0.023272641669032083 ~0.03953626279726216 ~0.040413793492622724 250:0.9609375:2885:2886 "
    s .= "~0.01251846045081827 ~-0.04797583934156887 ~-0.03515592225331689 166:0.265625:2889:2908 88:0.296875:2890:2905 106:0.53125:2891:2902 241:0.44:2892:2901 243:0.8500000000000001:2893:2898 205:0.671875:2894:2897 "
    s .= "105:0.3984375:2895:2896 ~-0.039992911626555355 ~0.04519175751023204 ~0.05576720220867885 55:-0.203125:2899:2900 ~-0.3865302445052725 ~-0.07979595281860755 ~0.02804852896873354 106:2.109375:2903:2904 ~0.03462499236187207 "
    s .= "~-0.06135235932637705 130:2.078125:2906:2907 ~0.0450041023145879 ~-0.044343259305133234 244:1.055:2909:2912 160:0.265625:2910:2911 ~0.010432631600016196 ~-0.06518767597977528 ~0.02559960122362729 ~-0.045343417210305714 "
    s .= "~-0.03602648586810198 249:1.8333333333333335:2916:2961 244:0.935:2917:2932 47:-0.015625:2918:2927 154:0.21875:2919:2924 233:0.25:2920:2923 246:-0.140625:2921:2922 ~-0.011165936159032518 ~0.06907907334839067 "
    s .= "~-0.039464432344844945 251:0.828125:2925:2926 ~-0.043735173717512024 ~0.024370782571470736 251:1.046875:2928:2931 169:1.453125:2929:2930 ~-0.04482028330996343 ~0.28190560078330007 ~0.010749408779580048 "
    s .= "253:-0.05687830687830658:2933:2938 252:0.125:2934:2937 223:-0.171875:2935:2936 ~-0.0726902062236494 ~0.007259496909111748 ~0.03912606993507054 251:1.984375:2939:2958 243:1.45:2940:2957 85:1.171875:2941:2954 "
    s .= "156:0.5859375:2942:2953 242:0.8500000000000001:2943:2950 244:1.4:2944:2945 ~-0.0241621489458664 184:0.140625:2946:2947 ~-0.03268137273200284 25:0.203125:2948:2949 ~0.04111296730404669 ~-0.03753425808725146 "
    s .= "178:0.25:2951:2952 ~0.045582392854737495 ~-0.009617444672760017 ~0.048318955618783806 239:-0.359375:2955:2956 ~0.043018149766682875 ~-0.00024664021704072037 ~-0.044934993074096284 241:0.52:2959:2960 "
    s .= "~-0.034508781528198466 ~0.04722366675614453 ~-0.04612708361399074 249:1.8333333333333335:2963:3006 244:0.805:2964:2969 111:0.3359375:2965:2966 ~-0.041344890212381094 82:-0.28125:2967:2968 ~0.08783341398502217 "
    s .= "~-0.02550495679127425 75:0.1796875:2970:2995 85:1.171875:2971:2990 238:0.328125:2972:2987 163:-0.0625:2973:2976 245:1.5233644859813085:2974:2975 ~0.02945493147469551 ~-0.040407874148435705 175:0.234375:2977:2984 "
    s .= "217:0.203125:2978:2983 97:-0.359375:2979:2980 ~-0.03592855893275259 254:1.015625:2981:2982 ~0.030870483656841387 ~-0.023571460176976606 ~-0.021717236965023198 142:0.375:2985:2986 ~-0.0035270595685104726 "
    s .= "~-0.05179453578620309 244:1.465:2988:2989 ~-0.04988478978371031 ~0.01875774999782361 238:-0.328125:2991:2992 ~-0.04269566610828147 40:0.515625:2993:2994 ~0.03637298760017978 ~-0.027082679409182575 241:0.16:2996:2999 "
    s .= "126:0.328125:2997:2998 ~-0.033865561300769925 ~0.01681308601710042 203:0.609375:3000:3005 47:0.34375:3001:3004 130:2.109375:3002:3003 ~0.04276841003137361 ~-0.052880875514925485 ~0.0030490405739116862 "
    s .= "~-0.026209556374315015 251:1.328125:3007:3008 ~-0.050281759564764356 ~0.023532613516534608 220:-0.265625:3010:3017 9:-0.9765625:3011:3012 ~0.06726886425327278 251:1.234375:3013:3014 ~-0.04830116186418859 "
    s .= "94:0.09375:3015:3016 ~-0.045604049394259334 ~0.0369465142029756 47:0.21875:3018:3047 144:0.140625:3019:3038 121:0.234375:3020:3035 122:0.125:3021:3030 249:1.8333333333333335:3022:3029 85:0.78125:3023:3028 "
    s .= "107:0.078125:3024:3027 205:0.671875:3025:3026 ~-0.008772855468477869 ~0.04372835134676706 ~0.04349696391825108 ~0.035673137143222004 ~-0.04534735368321439 246:0.140625:3031:3032 ~-0.055042037078121935 242:0.55:3033:3034 "
    s .= "~-0.03206001926403103 ~0.03387523629864861 251:0.515625:3036:3037 ~-0.046578520069012815 ~-0.0029283711450921396 245:1.1142857142857143:3039:3040 ~-0.054110083084468436 236:0.609375:3041:3046 246:0.140625:3042:3045 "
    s .= "90:0.0546875:3043:3044 ~0.041274068424871864 ~-0.0019951156088252216 ~0.047144526039907014 ~-0.0420010061402775 244:1.065:3048:3049 ~-0.038991442414174446 245:1.9444444444444444:3050:3053 208:-0.203125:3051:3052 "
    s .= "~-0.050586177235672186 ~0.030028016924057183 242:0.6499999999999999:3054:3055 ~-0.05390872955680527 ~0.007208265896489888 251:0.796875:3057:3082 249:1.1666666666666665:3058:3081 131:0.53125:3059:3080 243:1.45:3060:3079 "
    s .= "121:0.28125:3061:3076 43:0.25:3062:3073 85:0.734375:3063:3072 205:0.734375:3064:3071 139:0.421875:3065:3066 ~-0.021560415427872726 219:0.078125:3067:3068 ~-0.012289576952694413 246:0.203125:3069:3070 "
    s .= "~0.008818099890918444 ~0.07381937560522292 ~0.05354196695784097 ~0.036284619107770116 139:0.234375:3074:3075 ~0.013782608894745908 ~-0.046324452158083035 162:0.1875:3077:3078 ~-0.03760929487088091 ~0.02404094137130072 "
    s .= "~-0.04706946250015297 ~-0.04687233477435142 ~-0.044808375661607044 241:0.42:3083:3090 149:-0.4375:3084:3085 ~0.02635340771092151 106:0.640625:3086:3089 243:0.8500000000000001:3087:3088 ~-0.03274547275105826 "
    s .= "~-0.15912504113836035 ~-0.00002914404896848133 166:0.265625:3091:3096 190:-0.234375:3092:3093 ~-0.0045504069302009795 236:0.65625:3094:3095 ~0.044945453571002485 ~-0.04608680830604131 244:1.05:3097:3100 "
    s .= "208:0.265625:3098:3099 ~0.005830277256680801 ~-0.09378793200302564 79:-0.21875:3101:3102 ~-0.05865104019021237 ~0.03424041183461522 217:-0.203125:3104:3113 249:0.8333333333333333:3105:3112 251:1.328125:3106:3111 "
    s .= "105:-0.9765625:3107:3108 ~0.07208511691777598 244:2.01:3109:3110 ~-0.038208777899762944 ~0.038312607862714454 ~0.025162294521499796 ~-0.05146148737963102 233:0.15625:3114:3141 75:0.2265625:3115:3138 "
    s .= "193:0.265625:3116:3135 109:0.640625:3117:3128 211:0.28125:3118:3127 133:2.03125:3119:3126 251:0.796875:3120:3125 142:0.1875:3121:3124 163:0.375:3122:3123 ~-0.008009142011205372 ~0.06417642041078907 ~-0.04475452330091506 "
    s .= "~0.03180127106312555 ~-0.06353898013130056 ~-0.045887896824819675 34:0.203125:3129:3132 223:-0.1875:3130:3131 ~-0.045827977218420135 ~0.03294509617737237 181:0.40625:3133:3134 ~0.02149542689757901 ~-0.04970970903983182 "
    s .= "251:0.453125:3136:3137 ~-0.05123103617473741 ~-0.008846009367340528 14:0.578125:3139:3140 ~0.037431380622125 ~-0.031530847179906916 251:1.140625:3142:3147 188:0.515625:3143:3146 246:0.140625:3144:3145 "
    s .= "~-0.04472703009885434 ~-0.0014166693293920047 ~-0.047444678500949425 241:0.52:3148:3149 ~-0.03814150643229353 ~0.03201870838820045 211:-0.1875:3151:3158 220:-0.203125:3152:3153 ~-0.047913584761910225 "
    s .= "202:0.1875:3154:3157 4:-0.234375:3155:3156 ~-0.0516190675560445 ~0.014169844077309798 ~-0.044694254137743354 85:0.734375:3159:3188 251:1.640625:3160:3183 188:0.515625:3161:3182 156:0.5859375:3162:3181 211:0.25:3163:3178 "
    s .= "243:1.35:3164:3177 133:0.328125:3165:3170 256:0.961038961038961:3166:3169 244:1.075:3167:3168 ~0.05718109522158724 ~-0.0021140798059674656 ~-0.0361371189773006 184:0.0625:3171:3174 242:0.75:3172:3173 "
    s .= "~-0.03891579402311312 ~0.025724898805894594 255:0.265625:3175:3176 ~0.02211808532899119 ~-0.023358109860362533 ~-0.04650875234462299 244:1.09:3179:3180 ~-0.04997962269965717 ~-0.0004878185281251857 ~0.04867643684656969 "
    s .= "~-0.045420976821177766 243:0.6499999999999999:3184:3187 46:0.890625:3185:3186 ~-0.03164689311231815 ~0.1473005558537216 ~0.043250959165385745 142:0.5625:3189:3194 38:-0.015625:3190:3191 ~0.04081186324948431 "
    s .= "253:-0.019999999999998862:3192:3193 ~0.025667026485850855 ~-0.0232186798934058 94:0.546875:3195:3196 ~-0.0003008949784700154 ~-0.06058324956748669 249:1.8333333333333335:3198:3241 98:0.484375:3199:3234 "
    s .= "251:0.421875:3200:3209 31:0.078125:3201:3208 220:0.21875:3202:3207 208:0.03125:3203:3204 ~-0.018313906664326324 13:0.03125:3205:3206 ~0.040344502596698084 ~-0.013099097239558247 ~-0.032743912061565246 "
    s .= "~-0.03421649779158327 88:0.796875:3210:3231 113:0.78125:3211:3228 106:0.78125:3212:3225 190:-0.140625:3213:3214 ~-0.04028668997989696 257:0.8482142857142857:3215:3224 146:-0.125:3216:3217 ~0.0210709223448056 "
    s .= "246:-0.265625:3218:3219 ~-0.07792314161934585 255:0.140625:3220:3221 ~-0.02795589040891887 256:0.19642857142857142:3222:3223 ~-0.007013026019761424 ~0.059336554349093976 ~-0.07000958635538172 136:1.9375:3226:3227 "
    s .= "~0.024165700044101308 ~-0.052696171273434116 191:0.53125:3229:3230 ~0.05664662159021175 ~-0.040687413290055825 172:-0.1875:3232:3233 ~-0.02386404831064756 ~0.039122512875007585 242:0.75:3235:3236 ~-0.05327164231009195 "
    s .= "251:1.484375:3237:3240 11:0.796875:3238:3239 ~-0.04341358724039337 ~0.04451873242755978 ~0.029119375267573883 251:1.328125:3242:3243 ~-0.04956736525302832 ~0.0237376917817593 220:-0.265625:3245:3248 "
    s .= "57:-0.9296875:3246:3247 ~0.06028306669257775 ~-0.03920546208091407 47:0.234375:3249:3282 144:0.140625:3250:3269 121:0.234375:3251:3266 122:0.125:3252:3263 249:1.8333333333333335:3253:3262 85:0.78125:3254:3261 "
    s .= "107:0.078125:3255:3260 157:0.71875:3256:3259 122:-0.5:3257:3258 ~0.014158934895710984 ~-0.03218104600452908 ~0.021030135299391486 ~0.04007199553256552 ~0.03267739748219802 ~-0.04368379095440198 246:0.140625:3264:3265 "
    s .= "~-0.05215415313353855 ~-0.0012591277318606165 251:0.515625:3267:3268 ~-0.044145701335385056 ~-0.0033386611642025467 245:1.1142857142857143:3270:3271 ~-0.053227466629838384 236:0.609375:3272:3281 88:0.125:3273:3278 "
    s .= "164:0.078125:3274:3277 184:-0.046875:3275:3276 ~-0.05407828859952152 ~0.012952842931116712 ~0.041334544491505504 257:0.5555555555555556:3279:3280 ~0.044452132209801404 ~-0.022513195330249928 ~-0.040364901350280175 "
    s .= "244:1.065:3283:3286 202:0.046875:3284:3285 ~-0.017703161416180273 ~-0.054212105911423905 245:1.9444444444444444:3287:3290 208:-0.203125:3288:3289 ~-0.053284122998999345 ~0.030710541309137203 ~-0.02736907650387508 "
    s .= "248:0.875:3292:3337 233:0.5625:3293:3336 232:-0.140625:3294:3301 166:-0.3125:3295:3296 ~-0.04511486025746724 251:1.078125:3297:3298 ~-0.020046761682990286 241:0.48:3299:3300 ~-0.02831937165350448 ~0.03938850967041663 "
    s .= "51:0.2109375:3302:3333 94:0.34375:3303:3328 98:0.59375:3304:3327 243:1.45:3305:3326 157:1.15625:3306:3323 252:0.32499999999999996:3307:3322 255:0.265625:3308:3317 13:0.609375:3309:3316 106:0.53125:3310:3313 "
    s .= "28:0.625:3311:3312 ~-0.020795656358788578 ~0.08693343703927273 202:0.84375:3314:3315 ~0.032289480049084426 ~-0.04073632664312887 ~0.07723757495333262 53:-0.59375:3318:3319 ~0.018220064990737746 11:0.5625:3320:3321 "
    s .= "~-0.058182448249171174 ~0.0903169256553577 ~0.03464240602205403 235:0.015625:3324:3325 ~0.003931316433159206 ~0.046118617883612906 ~-0.03655433557203993 ~-0.08250616274829524 142:0.1875:3329:3332 88:0.65625:3330:3331 "
    s .= "~-0.024079293432788543 ~0.0449253858911347 ~-0.04348294808601977 253:-0.027419739825755112:3334:3335 ~0.04583935906167142 ~0.016221776969170182 ~-0.0417758154842043 ~-0.032227136747926564 "
    s .= "249:1.8333333333333335:3339:3384 98:0.484375:3340:3381 251:0.671875:3341:3366 43:0.25:3342:3361 243:1.45:3343:3360 85:0.734375:3344:3355 205:0.734375:3345:3352 40:-0.046875:3346:3347 ~-0.03047520042273066 "
    s .= "139:0.5:3348:3351 103:-0.390625:3349:3350 ~0.08738695368591132 ~-0.024154797732744697 ~0.024094045269809693 169:0.109375:3353:3354 ~0.055663680478558464 ~-0.04670435999639056 142:0.40625:3356:3357 ~0.036072173273227495 "
    s .= "244:1.545:3358:3359 ~-0.06776040678668395 ~0.03202897872597601 ~-0.046451576592172986 153:0.3671875:3362:3365 169:1.546875:3363:3364 ~-0.04589013397656623 ~0.24662272645786906 ~0.0338562065003356 241:0.4:3367:3374 "
    s .= "184:0.03125:3368:3373 232:0.0625:3369:3372 79:0.40625:3370:3371 ~-0.05138616824211165 ~0.022302817813422436 ~0.023207615843780074 ~0.015578693546579946 243:1.45:3375:3378 245:1.1547619047619047:3376:3377 "
    s .= "~-0.04882352484453529 ~0.039265463445873956 252:1.975:3379:3380 ~-0.040571926019658554 ~0.0201395082726177 242:0.75:3382:3383 ~-0.051857916842102 ~-0.012183174389448118 ~-0.0434956294709469 217:-0.15625:3386:3395 "
    s .= "249:0.8333333333333333:3387:3394 244:1.975:3388:3393 251:1.359375:3389:3392 9:-0.9765625:3390:3391 ~0.06518885802433572 ~-0.03446893580333495 ~0.024628547526451203 ~0.03899467291061067 ~-0.04978907227517282 "
    s .= "233:0.15625:3396:3421 141:0.0390625:3397:3408 193:0.265625:3398:3405 109:0.765625:3399:3404 97:-0.1875:3400:3401 ~-0.06522254018692318 251:0.640625:3402:3403 ~-0.018499655484354154 ~0.02616891811339736 "
    s .= "~0.02197729695222329 26:-0.609375:3406:3407 ~-0.003433327804975397 ~-0.04506919883584774 47:0.203125:3409:3418 253:-0.025641025641031472:3410:3411 ~0.045222540408158964 248:0.125:3412:3415 251:0.984375:3413:3414 "
    s .= "~-0.03425621659041129 ~0.033862199899322154 246:-0.015625:3416:3417 ~0.005297361841682898 ~0.053583047771351755 151:0.578125:3419:3420 ~-0.021287945687848555 ~0.043190153603599235 246:0.140625:3422:3425 "
    s .= "219:0.03125:3423:3424 ~0.004702972175029525 ~-0.06337780295110872 209:0.578125:3426:3431 242:0.8500000000000001:3427:3430 143:0.234375:3428:3429 ~0.029537875340001248 ~-0.02917137264964973 ~0.031695627860241375 "
    s .= "~-0.0387148939355409 249:1.8333333333333335:3433:3476 203:0.578125:3434:3475 251:0.421875:3435:3446 31:0.078125:3436:3445 208:-0.09375:3437:3438 ~-0.03827600143111089 220:0.21875:3439:3444 28:-0.03125:3440:3443 "
    s .= "94:0.21875:3441:3442 ~0.039680604865378756 ~-0.03331920335608004 ~-0.0025441349038578484 ~-0.030329871572357073 ~-0.03223972496646962 88:0.796875:3447:3472 113:0.78125:3448:3469 79:0.734375:3449:3466 "
    s .= "146:-0.125:3450:3457 257:0.8482142857142857:3451:3456 190:-0.140625:3452:3453 ~-0.02342930780306019 245:3.406779661016949:3454:3455 ~0.02163790217576585 ~-0.09153549898397051 ~-0.042551086127256665 "
    s .= "246:-0.140625:3458:3459 ~-0.06234501892744892 11:0.828125:3460:3463 121:-0.078125:3461:3462 ~-0.038736064857418734 ~-0.0016295528885647281 37:-0.046875:3464:3465 ~0.3726257609000651 ~0.04773318501141536 "
    s .= "97:-0.25:3467:3468 ~-0.034191094042653136 ~0.03642902474855615 38:0.484375:3470:3471 ~0.054869137150098835 ~-0.017876979368570866 193:-0.21875:3473:3474 ~-0.02211865273723537 ~0.03626566902745879 ~-0.03710763664035272 "
    s .= "251:1.328125:3477:3478 ~-0.04878173047695761 ~0.027052098234097474 190:-0.296875:3480:3481 ~-0.03737617696240079 166:0.375:3482:3515 218:0.109375:3483:3500 85:0.734375:3484:3497 139:0.5:3485:3494 251:1.390625:3486:3491 "
    s .= "254:1.046875:3487:3490 85:-0.109375:3488:3489 ~0.023924121101452606 ~-0.014200600879344367 ~-0.049125526012451064 241:0.52:3492:3493 ~-0.01685612269067012 ~0.0476881243965421 140:-0.03125:3495:3496 ~0.012726064636207408 "
    s .= "~0.05056901074992809 208:-0.25:3498:3499 ~-0.02904567525355275 ~0.03797988289162781 246:0.140625:3501:3504 237:0.015625:3502:3503 ~0.015555019538156623 ~-0.06653820575724226 146:0.5:3505:3514 250:1.1171875:3506:3507 "
    s .= "~-0.020147637099573745 244:0.695:3508:3511 11:0.875:3509:3510 ~-0.05057102745256954 ~0.3307181840908073 23:0.921875:3512:3513 ~0.03523412580580338 ~0.23728222294498896 ~-0.03503045847268828 142:0.203125:3516:3521 "
    s .= "121:-0.125:3517:3518 ~-0.050852198292323104 220:0.21875:3519:3520 ~0.03847942817769052 ~-0.02569194356994753 244:1.045:3522:3523 ~-0.04891579404507495 123:0.421875:3524:3525 ~-0.022797059269653405 ~0.05526129291292621 "
    s .= "217:-0.15625:3527:3536 249:0.8333333333333333:3528:3535 244:1.975:3529:3534 251:1.359375:3530:3533 9:-0.9921875:3531:3532 ~0.06395016885223267 ~-0.032668149666705275 ~0.023259690055690372 ~0.03796418258631486 "
    s .= "~-0.049100083281851385 88:1.21875:3537:3568 221:0.578125:3538:3567 257:0.9090909090909091:3539:3564 133:2.0625:3540:3563 248:1.125:3541:3560 47:0.140625:3542:3553 246:0.140625:3543:3550 224:0.140625:3544:3549 "
    s .= "4:0.265625:3545:3548 190:-0.078125:3546:3547 ~-0.013331446424064908 ~0.023864630630084427 ~-0.017194252478764032 ~-0.05401840571054785 233:0.328125:3551:3552 ~0.040189192113765274 ~-0.000594582917517284 "
    s .= "106:1.1875:3554:3559 84:0.2421875:3555:3558 49:-0.203125:3556:3557 ~-0.0761624675484982 ~-0.017718957978254863 ~0.01734204058242859 ~0.028690896882721785 46:1.296875:3561:3562 ~-0.03702553295344877 ~0.23168699397232087 "
    s .= "~-0.05398303457172624 157:1.359375:3565:3566 ~-0.0480986035492951 ~0.0574191982448274 ~-0.044589579650808495 142:0.671875:3569:3572 181:-0.1875:3570:3571 ~-0.025757416179675585 ~0.043231146805680506 "
    s .= "~-0.023281088981559867 172:-0.390625:3574:3575 ~-0.041354010739182614 50:-0.09375:3576:3595 144:0.21875:3577:3592 85:1.171875:3578:3589 80:-0.078125:3579:3588 172:0.46875:3580:3587 184:0.046875:3581:3582 "
    s .= "~-0.02209523731722745 244:1.085:3583:3586 245:1.8620689655172413:3584:3585 ~-0.042645185483517284 ~0.025257182776761422 ~0.022871973721354345 ~-0.03221304910169572 ~0.02857253960223521 181:1.578125:3590:3591 "
    s .= "~0.034435279615137496 ~-0.03952844772372985 220:-0.171875:3593:3594 ~-0.023410621953030376 ~0.03935492800453781 244:0.805:3596:3597 ~-0.039512301316105225 245:2.1666666666666665:3598:3619 217:0.28125:3599:3618 "
    s .= "246:0.109375:3600:3609 234:0.03125:3601:3606 228:-0.375:3602:3603 ~-0.056502085449580165 241:1.04:3604:3605 ~0.032941127218578566 ~-0.040836937992819004 194:-0.28125:3607:3608 ~0.0437497733262741 ~-0.060963792153935076 "
    s .= "203:0.640625:3610:3617 242:0.55:3611:3616 128:0.125:3612:3613 ~0.0391825655622344 244:2.01:3614:3615 ~-0.03368389562175144 ~0.05836642645809488 ~0.03730757072918433 ~-0.039960057171979556 ~-0.034646533226015894 "
    s .= "~-0.036645205684576604 249:1.8333333333333335:3621:3664 98:0.484375:3622:3661 251:0.671875:3623:3642 242:0.6499999999999999:3624:3635 244:1.23:3625:3628 195:0.203125:3626:3627 ~-0.027245414424519127 "
    s .= "~0.018048359872578322 157:0.109375:3629:3632 73:-0.0625:3630:3631 ~0.022688304910892135 ~-0.05881087091075176 94:0.5625:3633:3634 ~0.039244564103916045 ~-0.05253408903580512 184:0.21875:3636:3641 "
    s .= "245:1.7804878048780488:3637:3638 ~-0.036960367083909415 217:-0.078125:3639:3640 ~-0.028923886675817037 ~0.04057045043927519 ~-0.04718469154703074 241:0.42:3643:3654 184:0.03125:3644:3651 106:0.421875:3645:3648 "
    s .= "82:1.0625:3646:3647 ~-0.0394482607601995 ~-0.19602942508514495 163:-0.296875:3649:3650 ~-0.08574664622475581 ~0.011719201812363349 212:-0.390625:3652:3653 ~0.03685003413695425 ~0.0015042970450512177 243:1.45:3655:3658 "
    s .= "38:0.5625:3656:3657 ~0.03857044831730806 ~-0.02936213724284978 252:1.975:3659:3660 ~-0.039093995811630734 ~0.01835408461256697 242:0.75:3662:3663 ~-0.04945486785462975 ~-0.010645173275073534 251:1.328125:3665:3666 "
    s .= "~-0.048191294490075545 ~0.02725207399224517 190:-0.296875:3668:3669 ~-0.03562644156841382 166:0.375:3670:3707 218:0.109375:3671:3698 85:0.734375:3672:3693 139:0.5:3673:3688 251:1.390625:3674:3685 254:1.046875:3675:3684 "
    s .= "85:-0.46875:3676:3677 ~0.0899134234860724 254:0.765625:3678:3681 143:-0.421875:3679:3680 ~0.011394315846403897 ~-0.036350525755138086 256:0.20689655172413793:3682:3683 ~-0.0010096239144552772 ~0.07936652735558339 "
    s .= "~-0.047663628814197424 241:0.52:3686:3687 ~-0.016465396111166306 ~0.04637464900018152 140:-0.03125:3689:3690 ~0.011685078749119924 245:2.183673469387755:3691:3692 ~0.05767359653057701 ~-0.02576204390748263 "
    s .= "208:-0.25:3694:3695 ~-0.028065748216461878 130:1.875:3696:3697 ~0.03918309511079567 ~-0.015908742909094453 246:0.140625:3699:3702 237:0.015625:3700:3701 ~0.014723981494582464 ~-0.06431979905221791 146:0.5:3703:3706 "
    s .= "250:1.1171875:3704:3705 ~-0.01906167354348065 ~0.030018735663169233 ~-0.032543204329382784 142:0.203125:3708:3709 ~0.011129003264299251 244:1.045:3710:3711 ~-0.04753958109144313 123:0.421875:3712:3713 "
    s .= "~-0.021424936305476094 ~0.05322939354933351 248:0.875:3715:3756 233:0.578125:3716:3755 166:-0.328125:3717:3718 ~-0.03364165562471468 166:0.296875:3719:3746 88:0.34375:3720:3741 152:-0.0625:3721:3728 "
    s .= "164:0.09375:3722:3727 106:0.8125:3723:3726 207:-0.59375:3724:3725 ~0.07616052623602221 ~-0.008520004444312303 ~0.030544722970039892 ~0.05232109519078529 246:0.203125:3729:3732 186:-0.03125:3730:3731 "
    s .= "~-0.0005148221687551496 ~-0.052460202341778506 242:0.45:3733:3734 ~-0.03376513538976551 254:0.765625:3735:3740 251:1.484375:3736:3739 76:0.5:3737:3738 ~-0.03531278761598061 ~0.07243379254399313 ~0.035069518469475744 "
    s .= "~0.04731546103714131 190:-0.0625:3742:3745 51:0.2421875:3743:3744 ~-0.018465757699749945 ~0.03764721163157514 ~0.03688491214309656 244:1.06:3747:3752 160:0.296875:3748:3751 43:-0.0625:3749:3750 ~-0.061343903546402505 "
    s .= "~0.036480212616908654 ~-0.053987198405805174 142:0.671875:3753:3754 ~0.023164013048173143 ~-0.02756012911283456 ~-0.03933458020949429 225:0.2421875:3757:3758 ~-0.03683108428753495 47:-0.109375:3759:3760 "
    s .= "~0.04607271582173482 ~-0.02984192490467535 172:-0.390625:3762:3763 ~-0.039889024008360086 50:-0.09375:3764:3781 257:0.8482142857142857:3765:3778 144:0.21875:3766:3777 170:0.109375:3767:3776 110:0.015625:3768:3775 "
    s .= "128:-0.5625:3769:3772 144:-0.78125:3770:3771 ~-0.04485500513043343 ~0.02943441986218756 130:2.078125:3773:3774 ~-0.0027235286219805433 ~-0.07618202678877109 ~0.03553948039946549 ~-0.02878986326619559 "
    s .= "~0.035642033811596606 246:-3.078125:3779:3780 ~0.027565992796256114 ~-0.042896976948455796 255:0.328125:3782:3807 256:0.961038961038961:3783:3806 246:0.140625:3784:3793 234:0.03125:3785:3790 228:-0.421875:3786:3787 "
    s .= "~-0.05922758636529675 249:0.16666666666666666:3788:3789 ~0.027505697031749977 ~-0.026308719115442716 230:-0.125:3791:3792 ~-0.007187169796483143 ~-0.06467698991885042 242:0.55:3794:3799 107:0.359375:3795:3798 "
    s .= "245:1.9058823529411764:3796:3797 ~0.03475174492925561 ~-0.03543895441382561 ~-0.041298123300329864 254:0.765625:3800:3805 244:0.93:3801:3804 89:0.9375:3802:3803 ~-0.055861727589126366 ~0.05377559605083304 "
    s .= "~0.025767138459146122 ~0.053845290295013816 ~-0.04206379557480763 ~-0.05879247018884015 249:1.8333333333333335:3809:3852 203:0.609375:3810:3851 251:0.421875:3811:3826 43:0.21875:3812:3825 243:1.25:3813:3824 "
    s .= "244:1.51:3814:3823 150:-0.3046875:3815:3816 ~-0.052398656650590326 95:0.234375:3817:3822 163:-0.0625:3818:3819 ~-0.040809342719970006 130:0.1875:3820:3821 ~0.04735371028561873 ~0.00278423377829814 ~-0.0470012225303901 "
    s .= "~0.030306701863884913 ~-0.04638116885338052 ~-0.041240792643881474 144:0.0625:3827:3838 85:1.15625:3828:3837 97:-0.328125:3829:3830 ~-0.06952105001994024 202:0.1875:3831:3834 121:-0.046875:3832:3833 ~-0.0155956550391339 "
    s .= "~0.02167584814672273 122:-0.453125:3835:3836 ~0.004002419999597867 ~-0.044216155095255706 ~0.024929954301471477 41:0.453125:3839:3850 130:2.03125:3840:3849 242:0.35:3841:3844 243:0.8500000000000001:3842:3843 "
    s .= "~0.004015421197761389 ~-0.17072360223199023 166:0.359375:3845:3846 ~0.037221639897843176 250:1.2109375:3847:3848 ~-0.03975144837331369 ~0.02883081317105328 ~-0.048980540321322596 ~-0.00967874222085894 "
    s .= "~-0.038264920940182204 251:1.328125:3853:3854 ~-0.047594719961524076 ~0.026829696199999295 217:-0.15625:3856:3865 249:0.8333333333333333:3857:3864 244:1.975:3858:3863 251:1.484375:3859:3862 9:-0.9921875:3860:3861 "
    s .= "~0.061841422063861465 ~-0.028813528646966693 ~0.026452137508950063 ~0.03658258493763667 ~-0.04794503447530812 88:1.328125:3866:3899 224:0.578125:3867:3898 202:0.25:3868:3885 133:2.0625:3869:3884 251:0.359375:3870:3875 "
    s .= "28:-0.015625:3871:3874 208:-0.09375:3872:3873 ~-0.044701322879470574 ~0.024660227824469264 ~-0.02352126829449487 121:-0.015625:3876:3881 241:0.16:3877:3878 ~-0.03023127629613298 30:-0.0234375:3879:3880 "
    s .= "~-0.019113593072624162 ~0.021853550973653338 121:0.125:3882:3883 ~0.03930033937971105 ~0.014209413571111721 ~-0.05436725631196326 244:1.09:3886:3891 100:0.3125:3887:3890 238:0.8125:3888:3889 ~-0.022046697174862243 "
    s .= "~0.07517314546699351 ~-0.05274099541678928 239:-0.140625:3892:3895 174:-0.375:3893:3894 ~-0.02909747697111097 ~0.03331111620574597 120:0.203125:3896:3897 ~-0.04510365145443174 ~0.02482390671470125 ~-0.04108598737374783 "
    s .= "142:0.671875:3900:3901 ~0.03787442237386452 ~-0.018604637707752725 190:-0.296875:3903:3904 ~-0.0335567005049871 166:0.375:3905:3944 85:0.734375:3906:3935 251:1.640625:3907:3930 139:0.5:3908:3925 85:-0.140625:3909:3916 "
    s .= "58:-0.859375:3910:3911 ~0.30246754852613683 99:0.3125:3912:3915 244:1.335:3913:3914 ~-0.040130836325390294 ~0.036421986772526505 ~0.06635971440813535 251:0.890625:3917:3918 ~-0.02920342787777627 211:0.3125:3919:3924 "
    s .= "255:0.140625:3920:3921 ~-0.015139738883321836 245:1.4939759036144578:3922:3923 ~0.0853058535333637 ~0.007509778419417745 ~-0.062053402798962126 106:0.015625:3926:3927 ~-0.026412669412929874 4:0.265625:3928:3929 "
    s .= "~0.032894685593491645 ~-0.025923010780801677 241:0.52:3931:3934 46:0.375:3932:3933 ~-0.03512343019377393 ~0.09556387390325394 ~0.045316615465987545 232:-0.0625:3936:3941 245:1.9701492537313432:3937:3938 "
    s .= "~0.019783056916645732 242:0.8500000000000001:3939:3940 ~-0.04765630087896999 ~0.021831363978195097 136:2.078125:3942:3943 ~0.034929055039505594 ~-0.04894083171964215 142:0.203125:3945:3946 ~0.010728377113661952 "
    s .= "244:1.045:3947:3948 ~-0.04506343209981097 ~-0.014011029850548896 172:-0.390625:3950:3951 ~-0.03839925461933492 74:-0.078125:3952:3971 257:0.9428571428571428:3953:3968 253:-0.047281323877067884:3954:3957 "
    s .= "97:-0.203125:3955:3956 ~-0.008266074546845682 ~0.03658721321108996 130:2.078125:3958:3967 174:-0.375:3959:3960 ~-0.0198731353729905 184:0.03125:3961:3964 79:0.296875:3962:3963 ~-0.01543213027720828 ~0.03066154202748282 "
    s .= "73:0.109375:3965:3966 ~0.031904805138031615 ~0.0020447987112160756 ~-0.04989600341105172 136:1.140625:3969:3970 ~-0.04726870121627519 ~0.025808320023767872 249:1.1666666666666665:3972:3995 255:0.328125:3973:3994 "
    s .= "256:0.9803921568627451:3974:3993 246:0.140625:3975:3980 234:-0.015625:3976:3979 225:-0.3359375:3977:3978 ~-0.05521614631753663 ~0.024854614864489796 ~-0.04160779455757591 242:0.55:3981:3986 125:0.125:3982:3983 "
    s .= "~0.027823691659108016 244:2.01:3984:3985 ~-0.03685827395585438 ~0.05290391198043355 254:0.765625:3987:3992 244:0.93:3988:3991 247:0.578125:3989:3990 ~-0.056404908073507676 ~0.03624934922395794 ~0.027305593774286846 "
    s .= "~0.054276454834896695 ~-0.04158365081393904 ~-0.0551106061996369 ~-0.045654656589084464 166:-0.328125:3997:3998 ~-0.035674343243650396 233:0.5625:3999:4042 251:0.671875:4000:4023 118:0.359375:4001:4018 "
    s .= "152:0.09375:4002:4013 97:0.21875:4003:4010 243:1.15:4004:4009 109:0.28125:4005:4008 160:1.03125:4006:4007 ~-0.02391271847971528 ~0.04502171067491338 ~0.030306608847738722 ~-0.023474470004353556 181:0.0625:4011:4012 "
    s .= "~0.022598315628687936 ~-0.03903941024481025 11:0.796875:4014:4015 ~-0.01974660068307893 136:-0.109375:4016:4017 ~0.3066460368444068 ~0.016269526842566603 142:0.1875:4019:4020 ~0.008685914960313469 30:0.2265625:4021:4022 "
    s .= "~-0.048195670780257986 ~0.0072756557364926245 130:1.875:4024:4039 97:-0.140625:4025:4032 34:0.125:4026:4027 ~0.013023684336718706 9:0.0234375:4028:4029 ~-0.08706628320888463 144:0.40625:4030:4031 ~0.023638348333339318 "
    s .= "~-0.08359093951414298 243:0.35:4033:4036 223:0.21875:4034:4035 ~0.015568997400755295 ~-0.04550264878943473 5:0.5625:4037:4038 ~0.032760961814992155 ~-0.03885934602829586 104:-0.578125:4040:4041 ~0.0161751953301656 "
    s .= "~-0.046776716894435084 ~-0.03822521866549133 220:-0.265625:4044:4051 214:-0.203125:4045:4046 ~-0.04736482942608029 248:0.375:4047:4050 251:0.515625:4048:4049 ~-0.03709614787760905 ~0.030220780171584978 "
    s .= "~-0.040139353047303546 47:0.234375:4052:4083 141:0.0703125:4053:4066 224:0.140625:4054:4065 175:0.25:4055:4060 133:2.234375:4056:4059 248:0.875:4057:4058 ~0.021544817310297053 ~-0.017706135461550487 "
    s .= "~-0.06286406805548106 245:1.793103448275862:4061:4062 ~-0.03997157656918115 232:0.015625:4063:4064 ~-0.03102833527272497 ~0.01713955312089958 ~-0.03186129700181591 245:1.1142857142857143:4067:4068 ~-0.051847711430222904 "
    s .= "236:0.5625:4069:4082 251:0.953125:4070:4081 255:0.234375:4071:4080 255:0.140625:4072:4079 243:0.25:4073:4076 136:1.421875:4074:4075 ~0.07792445959269598 ~-0.061765091742149426 85:0.71875:4077:4078 ~-0.025425811334401555 "
    s .= "~0.03379488545665816 ~0.04613778442832072 ~-0.012850485495551038 ~0.0410436562875468 ~-0.03139221945133067 106:1.03125:4084:4087 251:1.765625:4085:4086 ~-0.03377034252468805 ~0.02024299257508881 121:0.234375:4088:4089 "
    s .= "~0.024531062574946864 ~-0.031028468431391044 249:1.8333333333333335:4091:4134 203:0.609375:4092:4133 253:-0.09523809523809727:4093:4096 252:0.125:4094:4095 ~-0.0021779563161394584 ~0.03494858901678659 "
    s .= "246:0.140625:4097:4118 167:-0.140625:4098:4115 244:1.05:4099:4104 245:1.8644067796610169:4100:4103 160:0.1875:4101:4102 ~0.009779680582623601 ~-0.053993922042799486 ~0.012249205010686916 157:0.09375:4105:4108 "
    s .= "106:0.53125:4106:4107 ~-0.05707640635349646 ~0.009949246050768586 142:0.40625:4109:4112 184:-0.046875:4110:4111 ~-0.0070800704481375105 ~0.03143337653603197 70:0.625:4113:4114 ~0.0040714103887789805 "
    s .= "~-0.06150413392554526 63:-0.09375:4116:4117 ~-0.005318950560572061 ~-0.041567634150052685 47:0.46875:4119:4132 152:0.0625:4120:4121 ~0.03868427457991589 242:0.55:4122:4125 161:0.0625:4123:4124 ~0.03877792772381558 "
    s .= "~-0.030272894080990438 255:0.328125:4126:4131 254:0.765625:4127:4130 250:1.2265625:4128:4129 ~-0.026494078563582414 ~0.031224565088485604 ~0.053952303444414096 ~-0.05776815225149295 ~-0.023797464052217235 "
    s .= "~-0.03613455233648876 251:1.328125:4135:4136 ~-0.0467284227467901 ~0.027571083287107813 217:-0.15625:4138:4147 249:0.8333333333333333:4139:4146 16:0.515625:4140:4145 244:1.615:4141:4144 251:1.359375:4142:4143 "
    s .= "~-0.021877822811887583 ~0.029421349517725043 ~0.03875697287182659 ~-0.05046244384113629 ~-0.046757038037820706 88:1.328125:4148:4181 224:0.578125:4149:4180 246:0.140625:4150:4167 244:1.455:4151:4162 "
    s .= "245:1.6547619047619047:4152:4155 242:0.45:4153:4154 ~-0.006685973316641946 ~-0.0646822957063224 197:0.125:4156:4161 254:1.046875:4157:4160 238:0.234375:4158:4159 ~0.015031975258822862 ~-0.022605508134827465 "
    s .= "~-0.035844965830164964 ~-0.06893079370071503 181:0.0625:4163:4164 ~-0.028980915872501407 133:2.203125:4165:4166 ~0.03262560362920748 ~-0.04566435965157533 74:-0.015625:4168:4169 ~0.0326006457572897 242:0.55:4170:4171 "
    s .= "~-0.02500631231707594 254:0.765625:4172:4177 251:1.421875:4173:4176 11:0.796875:4174:4175 ~-0.034432305396874766 ~0.049036289487485334 ~0.03884612230782109 255:0.328125:4178:4179 ~0.05129523888555862 "
    s .= "~-0.06450957737276487 ~-0.03908210743590068 172:-0.078125:4182:4183 ~-0.017715752150490222 ~0.035924990477823854 190:-0.296875:4185:4186 ~-0.03138405303329737 166:0.3125:4187:4216 85:0.546875:4188:4205 139:0.5:4189:4200 "
    s .= "251:1.640625:4190:4197 205:0.625:4191:4196 58:-0.890625:4192:4193 ~0.255835822926525 76:0.640625:4194:4195 ~-0.02413978130320755 ~0.026286771497087066 ~0.02616153566767452 114:0.2265625:4198:4199 ~-0.014646437967993581 "
    s .= "~0.04678899980816097 244:1.275:4201:4202 ~0.03385211730936532 157:0.125:4203:4204 ~-0.06377936219850289 ~0.012912550629358428 53:0.046875:4206:4213 130:1.90625:4207:4212 121:0.359375:4208:4209 ~0.03718659953145339 "
    s .= "75:0.1171875:4210:4211 ~-0.03674639233269341 ~0.04026371591939021 ~-0.021209000236610355 245:1.990909090909091:4214:4215 ~0.01716881482993832 ~-0.03792859384664138 228:-0.515625:4217:4218 ~-0.05400459518338039 "
    s .= "145:-0.15625:4219:4220 ~-0.03968847037420665 244:0.97:4221:4226 100:0.15625:4222:4225 243:0.55:4223:4224 ~0.052131934485059185 ~-0.031234630264900122 ~-0.05056078990854088 170:-0.296875:4227:4228 ~0.032921740482030525 "
    s .= "59:0.125:4229:4230 ~-0.02227444665611346 ~0.020505340409296698 249:1.8333333333333335:4232:4277 98:0.609375:4233:4276 243:1.45:4234:4271 198:-0.53125:4235:4240 23:-0.4375:4236:4239 4:0.265625:4237:4238 "
    s .= "~0.03051633484673822 ~-0.05574196459991154 ~-0.06409248582313416 88:0.828125:4241:4268 133:0.125:4242:4247 244:0.68:4243:4244 ~-0.02741364488860796 244:1.08:4245:4246 ~0.054400600943187286 ~0.010405278142589479 "
    s .= "184:0.90625:4248:4265 190:-0.140625:4249:4250 ~-0.0351529871416986 251:1.640625:4251:4264 255:0.265625:4252:4261 255:0.140625:4253:4256 158:0.46875:4254:4255 ~-0.0000623082135566212 ~-0.04179719934054692 "
    s .= "245:1.9152542372881356:4257:4258 ~0.04254711010894886 218:0.109375:4259:4260 ~0.01331384207060715 ~-0.07707162638426059 98:-0.46875:4262:4263 ~0.004375723353210934 ~-0.04310539480836892 ~0.030402122039943986 "
    s .= "245:1.776470588235294:4266:4267 ~0.05107326108868439 ~0.0020975128838359764 193:-0.09375:4269:4270 ~-0.022129083336002178 ~0.03447564773725922 252:1.6749999999999998:4272:4273 ~-0.0521494032084761 245:2.32:4274:4275 "
    s .= "~-0.020484642460821805 ~0.051423848301172304 ~-0.038656148227174225 ~-0.03753359278723321 166:-0.328125:4279:4280 ~-0.0330566836677711 236:0.578125:4281:4324 75:0.2890625:4282:4317 249:0.5:4283:4302 "
    s .= "172:0.28125:4284:4299 240:0.265625:4285:4294 243:1.45:4286:4291 254:1.109375:4287:4290 136:2.109375:4288:4289 ~0.02649518384827837 ~-0.040808644734074084 ~-0.02609823464286062 251:1.078125:4292:4293 "
    s .= "~-0.03775321376245286 ~0.04104933467973046 252:0.32499999999999996:4295:4298 218:0.015625:4296:4297 ~-0.010324349258910076 ~-0.07804460501215647 ~0.019205322802209757 257:0.6666666666666666:4300:4301 "
    s .= "~-0.004785402038505648 ~-0.04862185771533306 121:-0.046875:4303:4304 ~-0.041668159713334915 245:1.793103448275862:4305:4308 113:0.6875:4306:4307 ~-0.048335545033045706 ~0.03331169791719631 220:-0.0625:4309:4310 "
    s .= "~-0.03692012688391279 244:2.515:4311:4316 74:0.125:4312:4315 1:0.34375:4313:4314 ~0.04247592225827343 ~-0.03729124905163873 ~-0.03472051987481906 ~-0.12856334728474467 253:-0.055855855855857804:4318:4319 "
    s .= "~0.039970050491781726 117:0.265625:4320:4323 146:-0.234375:4321:4322 ~0.01868389968557597 ~-0.022285574223972003 ~0.02721130596090332 ~-0.03756476368441494 251:0.828125:4326:4357 131:0.53125:4327:4356 "
    s .= "249:1.8333333333333335:4328:4355 241:0.66:4329:4346 193:0.203125:4330:4341 85:0.953125:4331:4340 254:1.046875:4332:4339 11:0.4375:4333:4338 152:0.015625:4334:4337 161:-0.203125:4335:4336 ~0.0026596010102833897 "
    s .= "~0.037451643845300996 ~-0.016816491789115453 ~0.05516584322567256 ~-0.0381010914956419 ~0.034091440340294425 84:0.2265625:4342:4345 154:1.53125:4343:4344 ~-0.03890522319865594 ~0.034294148895645755 ~0.03419222497290933 "
    s .= "253:-0.04248366013072058:4347:4354 252:0.375:4348:4349 ~-0.07278868697929745 34:-0.328125:4350:4351 ~-0.11129301086687887 245:1.7625:4352:4353 ~-0.028745960232349377 ~0.045740703991830785 ~-0.045214798148343505 "
    s .= "~-0.04886923592775776 ~-0.04256642508344118 241:0.48:4358:4367 149:-0.4375:4359:4360 ~0.02015140456092869 40:0.34375:4361:4366 106:0.640625:4362:4365 52:1.0625:4363:4364 ~-0.04957715727834907 ~0.09597371037509907 "
    s .= "~-0.00035533916069742356 ~0.02202801272708922 243:1.45:4368:4371 214:0.5625:4369:4370 ~0.03663975133872717 ~-0.03741502981176241 ~-0.008140761853083378 190:-0.296875:4373:4374 ~-0.029448212704095575 "
    s .= "166:0.296875:4375:4402 85:0.546875:4376:4395 139:0.5:4377:4388 89:0.78125:4378:4385 4:-0.03125:4379:4382 181:0.546875:4380:4381 ~-0.010710587794158266 ~0.03786611779819839 58:-0.78125:4383:4384 ~0.20294073244334807 "
    s .= "~-0.025136660597526318 8:0.53125:4386:4387 ~0.050029960817686514 ~-0.041440266556587564 130:1.78125:4389:4394 106:0.015625:4390:4391 ~-0.016189531077074992 49:-0.265625:4392:4393 ~-0.04764003599959732 "
    s .= "~0.03586340437871572 ~-0.04702826061823154 53:0.046875:4396:4399 130:1.90625:4397:4398 ~0.031945860066475526 ~-0.02219844166227821 245:1.990909090909091:4400:4401 ~0.016224313195162748 ~-0.03643368212315392 "
    s .= "142:0.203125:4403:4410 232:0.40625:4404:4409 121:-0.09375:4405:4406 ~-0.026683066808341534 245:1.6547619047619047:4407:4408 ~-0.0015249367393249133 ~0.052800243991614405 ~-0.031494040895684826 156:0.6640625:4411:4418 "
    s .= "244:1.09:4412:4413 ~-0.042382802952607095 211:0.046875:4414:4415 ~-0.04592124751528762 70:0.640625:4416:4417 ~0.014258304602395425 ~-0.054650717974313916 ~0.055680865791083556 251:0.828125:4420:4447 "
    s .= "131:0.53125:4421:4446 249:1.8333333333333335:4422:4445 241:0.66:4423:4438 193:0.203125:4424:4435 85:0.953125:4425:4434 254:1.046875:4426:4433 11:0.4375:4427:4432 152:0.015625:4428:4431 115:0.3125:4429:4430 "
    s .= "~0.026702198836645492 ~-0.008826906946772704 ~-0.01583119763655248 ~0.05266374770660153 ~-0.036661657811277885 ~0.032673023457454424 84:0.2265625:4436:4437 ~-0.02998892297615804 ~0.03199880580090284 "
    s .= "253:-0.04248366013072058:4439:4444 252:0.375:4440:4441 ~-0.07174579908528425 34:-0.328125:4442:4443 ~-0.1061908947391443 ~0.03059574063268169 ~-0.04400447096544527 ~-0.048660319477868835 ~-0.041680804408457145 "
    s .= "241:0.48:4448:4461 184:0.03125:4449:4454 232:0.0625:4450:4453 79:0.375:4451:4452 ~-0.05188573129143803 ~0.015362734707224183 ~0.014567775574888262 4:0.1875:4455:4458 223:-0.171875:4456:4457 ~-0.03532396364627135 "
    s .= "~0.02978032678777473 257:0.15384615384615385:4459:4460 ~0.005368254080619249 ~-0.056632806987118936 243:1.45:4462:4465 214:0.5625:4463:4464 ~0.03558317930960937 ~-0.035471367775713816 ~-0.007514671315864295 "
    s .= "217:-0.15625:4467:4480 249:0.8333333333333333:4468:4479 55:-0.40625:4469:4470 ~-0.06160250433203418 148:-0.296875:4471:4472 ~0.02831759390997049 82:1.09375:4473:4476 251:1.609375:4474:4475 ~-0.02990678619728332 "
    s .= "~0.03181797728890803 16:0.484375:4477:4478 ~0.041732426207573683 ~-0.05637687010036625 ~-0.04501625631577485 224:0.640625:4481:4512 120:0.171875:4482:4503 217:0.296875:4483:4500 133:2.234375:4484:4499 "
    s .= "109:0.65625:4485:4492 130:0.1875:4486:4491 244:1.48:4487:4490 71:0.4375:4488:4489 ~0.040691326286455484 ~-0.032744506755719556 ~-0.03231489619007177 ~-0.01622372464782627 163:-0.28125:4493:4496 51:0.6796875:4494:4495 "
    s .= "~-0.021520521286490384 ~-0.21733873108223678 223:-0.21875:4497:4498 ~-0.05412375238245144 ~0.020317079961006596 ~-0.0651616124581941 26:-0.625:4501:4502 ~0.006274962412699175 ~-0.03816036602642067 88:0.265625:4504:4507 "
    s .= "136:-0.375:4505:4506 ~0.09760814458960473 ~0.0009510215457608729 163:0.25:4508:4509 ~0.04449377690619821 244:0.98:4510:4511 ~-0.04436190232590001 ~0.02872193659321534 ~-0.04260813757787946 251:0.421875:4514:4535 "
    s .= "241:0.32:4515:4532 160:1.203125:4516:4531 209:0.21875:4517:4530 94:0.28125:4518:4527 246:0.296875:4519:4526 109:0.8125:4520:4525 47:-1.015625:4521:4524 107:-0.703125:4522:4523 ~-0.04223197212654854 ~0.1511847298692015 "
    s .= "~-0.038718975032027494 ~0.024159206413394377 ~0.0365771362467088 184:1.09375:4528:4529 ~-0.04802390011484785 ~0.07589703348730308 ~-0.04041760329459485 ~0.04029907247772568 253:-0.07222222222222001:4533:4534 "
    s .= "~0.002171082514618636 ~-0.045893699132763296 130:1.84375:4536:4557 50:-0.09375:4537:4542 121:-0.140625:4538:4539 ~-0.008388543387941951 243:0.35:4540:4541 ~-0.004475154622802332 ~0.028428049118889045 "
    s .= "254:1.015625:4543:4556 209:0.640625:4544:4555 113:0.78125:4545:4554 11:0.828125:4546:4553 249:0.16666666666666666:4547:4548 ~0.013762330585026622 99:0.359375:4549:4550 ~-0.03101517044959355 234:0.109375:4551:4552 "
    s .= "~-0.08878465433576362 ~0.032081269523899884 ~0.06729841306771205 ~0.03862283306836704 ~-0.04214446899097246 ~-0.07115877470391928 223:0.015625:4558:4559 ~-0.05568242963385257 ~-0.0013050757441128574 "
    s .= "187:-0.3125:4561:4564 242:0.75:4562:4563 ~-0.04891042725576428 ~-0.00526266106214395 253:-0.09764309764309784:4565:4570 248:0.125:4566:4567 ~0.03817922841785971 51:0.2890625:4568:4569 ~-0.01640466185708759 "
    s .= "~0.039034898414995876 251:1.640625:4571:4602 167:0.5625:4572:4601 243:1.45:4573:4600 246:0.140625:4574:4587 236:-0.0625:4575:4584 195:-0.34375:4576:4579 160:1.5:4577:4578 ~-0.03488942577002798 ~0.05215753025503748 "
    s .= "125:-0.609375:4580:4581 ~0.02434706290502034 14:-0.03125:4582:4583 ~-0.012465312905118167 ~0.030231763437949068 245:2.1463414634146343:4585:4586 ~-0.01965881818667989 ~-0.06350864384465064 152:0.09375:4588:4591 "
    s .= "244:1.02:4589:4590 ~0.05682673271647205 ~0.016003555240863224 245:2.0434782608695654:4592:4599 245:1.1142857142857143:4593:4594 ~-0.050600878315778974 251:0.921875:4595:4598 106:0.578125:4596:4597 ~-0.01700726187266897 "
    s .= "~0.03389000053055022 ~0.045738897919942456 ~-0.025792142355642467 ~-0.03632640624848619 ~-0.03785796044576512 252:0.42500000000000004:4603:4606 146:-0.265625:4604:4605 ~0.03047326727656214 ~-0.03485294139885378 "
    s .= "~0.03813171289429473 248:1.125:4608:4653 203:0.609375:4609:4652 246:0.140625:4610:4631 236:-0.0625:4611:4628 50:-0.65625:4612:4615 25:0.484375:4613:4614 ~0.027734212693482214 ~-0.025983794414288913 244:1.48:4616:4625 "
    s .= "247:-0.921875:4617:4618 ~-0.06673927074463747 255:0.234375:4619:4624 257:0.9428571428571428:4620:4623 152:0.03125:4621:4622 ~0.026616042568722166 ~-0.04173420168673483 ~-0.051090086572710816 ~-0.03790051326971842 "
    s .= "133:2.40625:4626:4627 ~0.019120277742337342 ~-0.08382720459691545 237:0.03125:4629:4630 ~-0.011432973954660395 ~-0.04790915273601286 152:0.0625:4632:4635 22:-0.265625:4633:4634 ~-0.027113077366994188 "
    s .= "~0.03995031610628546 242:0.45:4636:4639 205:0.546875:4637:4638 ~-0.031130468196594936 ~0.05624927794402225 255:0.328125:4640:4651 254:0.765625:4641:4650 244:0.94:4642:4647 247:0.578125:4643:4644 ~-0.04970626425536495 "
    s .= "154:-0.203125:4645:4646 ~0.1029287310831413 ~-0.020626439397633284 250:1.2109375:4648:4649 ~-0.0064645809096236075 ~0.03870276453173871 ~0.045968692317719974 ~-0.048873083203957286 ~-0.03412667033662605 "
    s .= "~-0.0318806995219414 172:-0.390625:4655:4656 ~-0.033209690816077844 194:0.609375:4657:4700 257:0.9090909090909091:4658:4697 133:2.09375:4659:4696 248:1.125:4660:4695 254:1.296875:4661:4692 47:0.234375:4662:4679 "
    s .= "144:0.078125:4663:4670 128:-0.078125:4664:4667 175:0.25:4665:4666 ~0.027695918443393166 ~-0.0025389672561453316 11:0.421875:4668:4669 ~-0.012480337994741747 ~0.05667494496803197 245:1.1142857142857143:4671:4672 "
    s .= "~-0.04985018053534533 246:0.234375:4673:4678 90:0.0546875:4674:4675 ~0.034621732422207514 184:-0.015625:4676:4677 ~-0.04591654949447722 ~0.010365011961082426 ~0.038388589486701014 24:0.09375:4680:4683 "
    s .= "221:0.328125:4681:4682 ~-0.007924432927654683 ~0.04402202919212717 126:0.296875:4684:4685 ~-0.038178046289638674 178:-0.1875:4686:4689 88:-0.328125:4687:4688 ~0.3562623143390029 ~0.0549864045831272 232:-0.25:4690:4691 "
    s .= "~-0.08068762029716374 ~0.01265043625140639 35:-0.609375:4693:4694 ~0.012175164660452249 ~-0.06686814470495471 ~-0.027173406682241275 ~-0.032451226616078716 245:1.6547619047619047:4698:4699 ~-0.05622507592382771 "
    s .= "~0.0033070452399341626 ~-0.03875056503607985 187:-0.3125:4702:4705 242:0.75:4703:4704 ~-0.047733945249998175 ~-0.004808090985997218 163:0.34375:4706:4733 88:0.359375:4707:4728 205:0.625:4708:4727 79:0.53125:4709:4726 "
    s .= "136:-0.25:4710:4713 1:0.390625:4711:4712 ~0.025053973041471007 ~0.18441475641544014 46:0.625:4714:4725 245:1.9175257731958764:4715:4722 4:1.171875:4716:4721 254:0.078125:4717:4718 ~-0.026468108839102885 "
    s .= "133:0.421875:4719:4720 ~0.03930987251119495 ~-0.016882921557465545 ~0.08931884803144177 211:-0.265625:4723:4724 ~0.04161155422758644 ~-0.03685430571092583 ~0.04516146846361632 ~0.0255633191759597 ~0.03620904306460394 "
    s .= "217:-0.078125:4729:4730 ~-0.0037651473924379475 257:0.6956521739130435:4731:4732 ~0.03524056213729224 ~-0.023202923202334115 244:1.505:4734:4745 187:0.359375:4735:4738 157:0.140625:4736:4737 ~0.03513238797656253 "
    s .= "~-0.014083345952383917 102:0.2421875:4739:4742 251:2.078125:4740:4741 ~-0.0488552032494462 ~0.046292700411463925 244:0.975:4743:4744 ~-0.04495452634323138 ~0.040068721666427255 157:-0.078125:4746:4747 "
    s .= "~-0.06135340671522463 ~0.023231112745267696 251:0.828125:4749:4780 107:0.5:4750:4779 249:1.8333333333333335:4751:4778 241:0.66:4752:4769 85:1.265625:4753:4768 255:0.234375:4754:4761 195:-0.53125:4755:4756 "
    s .= "~-0.04861109159876813 245:1.9175257731958764:4757:4758 ~0.025789415798800758 166:0.0625:4759:4760 ~-0.021751946368871903 ~0.017649599778721207 11:-0.984375:4762:4765 131:-0.625:4763:4764 ~-0.015123956251179932 "
    s .= "~0.08951353037599413 156:0.5546875:4766:4767 ~-0.036418909768613526 ~0.051310868821506185 ~0.03144455680328783 253:-0.04248366013072058:4770:4775 252:0.42500000000000004:4771:4772 ~-0.06953891671215141 "
    s .= "37:-0.21875:4773:4774 ~-0.08216437847389604 ~0.03117702016553219 248:0.125:4776:4777 ~-0.061335091414460786 ~-0.011894377555672029 ~-0.04790549216527319 ~-0.0387498423048725 252:0.32499999999999996:4781:4792 "
    s .= "149:-0.4375:4782:4783 ~0.021062446760843644 246:-0.265625:4784:4785 ~-0.04042872301616309 74:-0.015625:4786:4791 130:1.828125:4787:4790 184:0.15625:4788:4789 ~0.004432957602498587 ~0.05634063882220025 "
    s .= "~-0.05133024634881829 ~-0.024418708508564126 243:1.45:4793:4794 ~0.03472026726891718 ~-0.004865933884776054 190:-0.296875:4796:4797 ~-0.02629776595803537 167:0.5625:4798:4841 113:0.78125:4799:4838 74:-0.09375:4800:4823 "
    s .= "246:-0.015625:4801:4818 26:-0.625:4802:4807 25:0.484375:4803:4806 236:-0.375:4804:4805 ~0.02989972955927549 ~-0.01213931138614875 ~-0.030646216423052094 244:1.49:4808:4815 83:-0.96875:4809:4810 ~-0.07274333932685074 "
    s .= "254:1.046875:4811:4814 245:1.6612903225806452:4812:4813 ~-0.038160565776328835 ~0.004684923307381328 ~-0.0569502669768209 245:3.5454545454545454:4816:4817 ~0.011728170908754205 ~-0.08591437206867611 "
    s .= "233:0.21875:4819:4822 35:0.078125:4820:4821 ~0.041128212030484 ~-0.03338716607442601 ~-0.005398541561005613 245:2.1666666666666665:4824:4837 243:1.25:4825:4836 249:0.16666666666666666:4826:4829 40:0.46875:4827:4828 "
    s .= "~0.02439307579353631 ~-0.0392233767910516 11:0.828125:4830:4835 246:0.015625:4831:4832 ~-0.04725336991054926 128:0.125:4833:4834 ~0.03327024955861679 ~-0.019774503525859313 ~0.09511851095105238 ~-0.03831568751372182 "
    s .= "~-0.03318309000611446 114:0.6171875:4839:4840 ~0.04687118072594281 ~-0.056199908082077865 ~-0.02781625120112955 251:0.421875:4843:4858 241:0.32:4844:4855 160:1.203125:4845:4854 107:0.46875:4846:4853 "
    s .= "195:-0.234375:4847:4848 ~-0.039222265058852325 245:1.9152542372881356:4849:4850 ~0.01818536697808452 31:-0.0625:4851:4852 ~0.014410407116057606 ~-0.03946074229452393 ~-0.050596632915529044 ~0.03881268823286761 "
    s .= "253:-0.07222222222222001:4856:4857 ~0.0015646512892656358 ~-0.04391395735371997 130:1.84375:4859:4886 238:0.296875:4860:4881 187:-0.3125:4861:4862 ~-0.023387904759320673 203:0.640625:4863:4880 242:0.35:4864:4871 "
    s .= "184:0.03125:4865:4866 ~-0.04132528653631301 172:0.765625:4867:4870 169:0.546875:4868:4869 ~0.02112773195110381 ~0.15182882219068808 ~-0.05152707820728221 254:1.046875:4872:4877 50:0.140625:4873:4874 ~0.02982259921549504 "
    s .= "11:0.921875:4875:4876 ~0.002785502293891698 ~0.08669123351802079 26:-0.5:4878:4879 ~0.023489338013692046 ~-0.061479500446519855 ~-0.03050099242781906 244:1.1:4882:4885 211:0.234375:4883:4884 ~0.006592506057161785 "
    s .= "~-0.05655048631960698 ~0.007843604921487267 223:0.015625:4887:4888 ~-0.0536753489794882 ~-0.001540608177026867 98:0.609375:4890:4935 251:0.828125:4891:4922 249:1.8333333333333335:4892:4921 148:0.375:4893:4920 "
    s .= "253:0:4894:4917 85:0.921875:4895:4916 254:1.265625:4896:4915 11:0.796875:4897:4914 188:0.328125:4898:4913 113:-0.15625:4899:4906 255:0.578125:4900:4905 244:1.385:4901:4902 ~-0.028070752771339594 157:0.109375:4903:4904 "
    s .= "~-0.03697192280038931 ~0.03488596704137655 ~0.05902474116084035 125:0.015625:4907:4908 ~0.035289016652711135 244:1.19:4909:4912 254:0.765625:4910:4911 ~-0.028273150164238422 ~0.03982010093875959 ~-0.03734516163426688 "
    s .= "~-0.030283172342305917 ~0.08063937820820113 ~-0.04715541158190962 ~0.027368580450088928 242:0.55:4918:4919 ~0.007822739695281472 ~-0.03851639345236023 ~-0.0246907692291838 ~-0.046869322820201224 241:0.42:4923:4928 "
    s .= "184:0.03125:4924:4927 244:1.125:4925:4926 ~0.018986249619532648 ~-0.042102646510146335 ~0.009595781504975115 243:1.35:4929:4930 ~0.030817722656163296 49:-0.296875:4931:4932 ~-0.0527340097395233 47:0.4375:4933:4934 "
    s .= "~0.021711251598447993 ~-0.044159374535122455 ~-0.03463323098076911 220:-0.265625:4937:4940 214:-0.203125:4938:4939 ~-0.04237864472116494 ~-0.006548279618380311 224:0.640625:4941:4982 133:2.234375:4942:4981 "
    s .= "257:0.8243243243243243:4943:4976 248:1.125:4944:4975 47:0.234375:4945:4964 246:0.203125:4946:4957 224:0.015625:4947:4954 238:0.484375:4948:4953 190:-0.078125:4949:4952 82:0.484375:4950:4951 ~-0.02544486488739489 "
    s .= "~0.027036200150227254 ~0.02231014134078474 ~-0.02337413208064061 240:-0.015625:4955:4956 ~0.016381203902916894 ~-0.04352827358797659 242:0.25:4958:4959 ~-0.04685856659089435 245:1.1142857142857143:4960:4961 "
    s .= "~-0.04824136930393861 254:1.234375:4962:4963 ~0.031818870024302774 ~-0.05211949241076343 106:1.03125:4965:4972 52:1.328125:4966:4971 133:-0.359375:4967:4970 80:0.640625:4968:4969 ~0.01003369761813646 "
    s .= "~0.25645755353010996 ~-0.022299194772506883 ~0.11212853033086952 228:-0.328125:4973:4974 ~-0.12115144690116811 ~0.024602147512711555 ~-0.025153418385163204 245:1.6547619047619047:4977:4978 ~-0.049980882000764976 "
    s .= "240:-0.171875:4979:4980 ~0.024606516716397284 ~-0.040217852432196007 ~-0.04414696796708686 ~-0.040042724253074494 253:-0.09764309764309784:4984:4987 252:0.125:4985:4986 ~-0.007796991999437338 ~0.02896768622263701 "
    s .= "251:1.640625:4988:5025 226:-0.3125:4989:4990 ~-0.03649580242397 176:0.65625:4991:5024 255:0.234375:4992:5013 255:0.140625:4993:5010 241:0.46:4994:4999 184:0.046875:4995:4998 76:0.25:4996:4997 ~-0.025682587236946327 "
    s .= "~0.025829002579181033 ~0.01481054826015 251:0.484375:5000:5001 ~-0.05866330178095559 245:1.6129032258064515:5002:5007 247:0.703125:5003:5004 ~-0.06653336769970672 184:-0.25:5005:5006 ~0.24576410149731048 "
    s .= "~-0.028603552800920803 130:1.9375:5008:5009 ~0.02049641715066991 ~-0.06114716302625453 219:0.125:5011:5012 ~0.001329814368127153 ~0.05086807029463204 26:-0.421875:5014:5021 246:-0.453125:5015:5018 109:1.03125:5016:5017 "
    s .= "~-0.02987587551218407 ~0.016487730774073905 167:0.15625:5019:5020 ~0.04348292686030017 ~-0.06184955598197666 254:0.953125:5022:5023 ~-0.018964912159173744 ~-0.06296492126898191 ~-0.041806233515365915 "
    s .= "252:0.42500000000000004:5026:5029 224:-0.046875:5027:5028 ~0.014139544039408702 ~-0.04556364658873978 ~0.03535086144358714 205:-0.296875:5031:5032 ~-0.025798048642753885 245:1.1142857142857143:5033:5034 "
    s .= "~-0.042914621089928225 163:0.328125:5035:5060 252:0.32499999999999996:5036:5055 184:0.03125:5037:5042 106:0.265625:5038:5041 64:0.625:5039:5040 ~-0.03720669015488371 ~0.043070858777044585 ~0.0006576439794731036 "
    s .= "178:0.53125:5043:5054 109:0.265625:5044:5047 37:0.28125:5045:5046 ~-0.03593338949902926 ~0.060795146391030876 172:0.328125:5048:5051 109:1.734375:5049:5050 ~0.02477076711361139 ~-0.02844983874790191 154:0.625:5052:5053 "
    s .= "~-0.04605838879670555 ~0.04892789270173314 ~0.035587053303572216 251:0.296875:5056:5057 ~-0.03812743810874159 5:0.5625:5058:5059 ~0.033553218685489467 ~-0.0388447175100513 228:-0.515625:5061:5062 ~-0.04917324991713352 "
    s .= "97:-0.21875:5063:5066 15:-0.0234375:5064:5065 ~-0.06313803987685247 ~-0.0015702773563712397 244:0.975:5067:5070 157:0.15625:5068:5069 ~0.03716552745877429 ~-0.04067598829461882 133:2.0625:5071:5076 "
    s .= "250:1.1484375:5072:5073 ~0.0017388729380697122 235:-0.09375:5074:5075 ~-0.013272889706617955 ~0.0372492129921007 ~-0.04002283244831328 146:-0.125:5078:5099 246:-0.390625:5079:5094 26:-0.71875:5080:5085 "
    s .= "143:-0.546875:5081:5084 25:0.484375:5082:5083 ~0.03175229469695888 ~-0.02887682460779197 ~-0.021763213742676476 244:1.455:5086:5091 247:-0.921875:5087:5088 ~-0.05769494787128816 255:0.203125:5089:5090 "
    s .= "~0.0008101578710383348 ~-0.04144743499070164 209:-0.40625:5092:5093 ~0.024619681246712943 ~-0.021906024088465773 30:0.1484375:5095:5098 129:0.0078125:5096:5097 ~0.02108851995261108 ~-0.01976400898892151 "
    s .= "~0.033021564527795276 246:0.109375:5100:5107 244:1.48:5101:5104 170:0.078125:5102:5103 ~-0.025080035317368167 ~-0.064811390032307 162:-0.03125:5105:5106 ~0.019220484147227525 ~-0.042780298502146485 "
    s .= "256:0.9803921568627451:5108:5123 255:0.265625:5109:5122 255:0.140625:5110:5119 110:0.984375:5111:5118 128:0.5:5112:5117 11:0.796875:5113:5116 88:1.09375:5114:5115 ~-0.0077786448838591555 ~0.03833205646807228 "
    s .= "~0.08705190486529765 ~-0.03359348621808851 ~0.04219396804324833 245:1.9107142857142858:5120:5121 ~0.049456181100908304 ~-0.010304062588052838 ~-0.028018714426283127 ~-0.03509094068355813 163:-0.3125:5125:5126 "
    s .= "~-0.031078883135416242 163:0.34375:5127:5152 85:0.734375:5128:5147 205:0.625:5129:5146 76:0.578125:5130:5145 251:0.859375:5131:5138 119:0.15625:5132:5137 254:0.984375:5133:5136 109:0.078125:5134:5135 "
    s .= "~-0.03505203087820008 ~0.01045538981097704 ~-0.04137722218672308 ~-0.037592017414029434 113:0.90625:5139:5144 121:-0.015625:5140:5141 ~-0.033394327602317156 91:0.234375:5142:5143 ~-0.002632509857517535 "
    s .= "~0.039872195369963 ~0.05119912547530069 ~0.03329043914777412 ~0.037651791275474855 38:-0.015625:5148:5149 ~0.032609920453742995 245:1.9770114942528736:5150:5151 ~0.020141880424332 ~-0.02984661381419835 "
    s .= "244:1.505:5153:5168 154:0.171875:5154:5161 226:0.1875:5155:5160 220:-0.046875:5156:5157 ~-0.013348161938595572 217:0.203125:5158:5159 ~0.0490429553254646 ~-0.03941445317945075 ~-0.04385586913467027 "
    s .= "102:0.2421875:5162:5165 245:1.5544554455445545:5163:5164 ~-0.06278736385996804 ~-0.02818022163975753 244:0.99:5166:5167 ~-0.04458137009571769 ~0.030010806442269767 157:-0.078125:5169:5170 ~-0.05856767851951762 "
    s .= "~0.02102327349376669 203:0.609375:5172:5217 144:0.125:5173:5204 175:0.234375:5174:5195 163:-0.28125:5175:5176 ~-0.044282388683656436 133:2.234375:5177:5192 176:-0.171875:5178:5179 ~0.018610319423018638 "
    s .= "8:0.40625:5180:5191 245:1.9027777777777777:5181:5190 240:0.28125:5182:5189 228:-0.328125:5183:5184 ~-0.11522666856850527 95:-0.234375:5185:5186 ~-0.024402259642173896 255:0.328125:5187:5188 ~0.0330453893781993 "
    s .= "~-0.06147409007961731 ~-0.051192072491675636 ~-0.02899158085451923 ~0.04382236009447009 141:-0.2265625:5193:5194 ~0.022134038088626875 ~-0.08054920882701197 229:-0.078125:5196:5197 ~-0.043393497234070294 "
    s .= "244:0.965:5198:5199 ~-0.04207536853447957 184:0.421875:5200:5203 106:0.03125:5201:5202 ~-0.03635249325178934 ~0.022727485019420814 ~-0.022045015303410843 41:0.46875:5205:5216 251:0.953125:5206:5213 28:0.0625:5207:5212 "
    s .= "11:0.796875:5208:5211 191:0.265625:5209:5210 ~0.0222105314104378 ~-0.025605422301514854 ~0.12188889406359396 ~-0.012860583695581474 243:2.8499999999999996:5214:5215 ~0.03412492390565338 ~-0.06692895817688838 "
    s .= "~-0.021687278561721826 ~-0.031201182065013072 98:0.609375:5219:5264 251:0.421875:5220:5233 241:0.32:5221:5230 160:1.203125:5222:5229 55:0.03125:5223:5228 106:0.328125:5224:5227 90:0.7265625:5225:5226 "
    s .= "~-0.029032984024458964 ~0.06099365247294595 ~0.026916722442425725 ~-0.024882903209555187 ~0.037253237454330096 253:-0.07222222222222001:5231:5232 ~0.002204257137067887 ~-0.041354294760372605 130:1.84375:5234:5261 "
    s .= "121:-0.109375:5235:5240 145:0.03125:5236:5239 166:0.15625:5237:5238 ~0.013239100216409758 ~-0.02425734506539404 ~-0.04506273531361896 142:-0.15625:5241:5246 16:-0.140625:5242:5245 109:1.390625:5243:5244 "
    s .= "~-0.06738488892288956 ~0.013431537759001237 ~0.009753708291305743 191:0.5625:5247:5260 113:0.71875:5248:5259 245:1.5233644859813085:5249:5252 67:0.140625:5250:5251 ~0.020947609057580526 ~-0.050831603029159546 "
    s .= "244:2.81:5253:5258 255:0.265625:5254:5255 ~0.029019895355105386 74:-0.328125:5256:5257 ~0.0228098071559662 ~-0.023616643298052714 ~-0.06931392493838515 ~0.04885380189547784 ~-0.019301224673547664 223:0.015625:5262:5263 "
    s .= "~-0.05172524446138822 ~-0.001379297587377563 ~-0.032437263844590586 248:1.125:5266:5311 227:0.625:5267:5310 246:0.140625:5268:5283 167:-0.171875:5269:5278 109:0.984375:5270:5277 254:0.796875:5271:5276 50:-0.75:5272:5273 "
    s .= "~0.039957371438414144 254:0.421875:5274:5275 ~-0.02318710627505402 ~0.02406792187620949 ~-0.026072055296236532 ~0.017334534448921295 240:0.03125:5279:5280 ~-0.00844126405243437 197:0.015625:5281:5282 "
    s .= "~-0.014322333494369384 ~-0.05925798066900974 47:0.453125:5284:5307 242:0.35:5285:5290 205:0.515625:5286:5289 94:0.5:5287:5288 ~-0.04240176020088225 ~0.07057912058960579 ~0.05671846126816461 255:0.328125:5291:5304 "
    s .= "254:0.765625:5292:5299 250:1.2109375:5293:5298 150:0.6796875:5294:5297 109:0.703125:5295:5296 ~-0.028475464951743926 ~0.027176215625456468 ~-0.13581144451385005 ~0.027234011275540967 245:1.9324324324324325:5300:5301 "
    s .= "~0.05232163702319606 128:0.140625:5302:5303 ~0.043248594688879635 ~-0.041205597405949396 247:0.234375:5305:5306 ~0.01748864308162615 ~-0.06609621827144073 46:0.046875:5308:5309 ~0.010703190071442034 "
    s .= "~-0.03901482755625055 ~-0.035149079056644814 ~-0.026992762897110868 172:-0.390625:5313:5314 ~-0.02899958658171477 257:0.8482142857142857:5315:5356 74:-0.078125:5316:5335 130:1.84375:5317:5332 254:1.296875:5318:5329 "
    s .= "234:-0.703125:5319:5320 ~-0.041106850275418126 106:0.3125:5321:5328 91:0.28125:5322:5327 190:0.140625:5323:5326 1:0.296875:5324:5325 ~-0.03321758349142128 ~0.04440530142196639 ~0.024611259065378557 ~0.031187394391131346 "
    s .= "~0.02580345266445415 26:-0.640625:5330:5331 ~0.013226036310235324 ~-0.05584825488367978 128:-0.484375:5333:5334 ~0.014242782012618041 ~-0.04469586835577899 249:1.1666666666666665:5336:5355 255:0.328125:5337:5354 "
    s .= "256:0.9803921568627451:5338:5351 245:2.126315789473684:5339:5350 224:-0.75:5340:5341 ~-0.06754435274325558 243:1.45:5342:5349 178:-0.03125:5343:5344 ~0.04041729395242217 7:0.140625:5345:5346 ~0.02089753644179468 "
    s .= "157:0.28125:5347:5348 ~0.018884379393069212 ~-0.03297998483644536 ~-0.025122930359140712 ~-0.0196918807509242 25:0.65625:5352:5353 ~-0.044462073197643816 ~0.0836581799696916 ~-0.04410189214663933 ~-0.04210021117276109 "
    s .= "136:1.140625:5357:5358 ~-0.04113918867734404 ~0.019509297126779523 190:-0.328125:5360:5361 ~-0.025081353154480276 236:0.578125:5362:5405 256:0.01818181818181818:5363:5390 146:-0.140625:5364:5379 4:0.25:5365:5376 "
    s .= "29:-0.71875:5366:5371 236:-0.484375:5367:5368 ~0.03577836042117193 110:-0.375:5369:5370 ~-0.03992727621206003 ~0.03929331384502494 198:-0.609375:5372:5373 ~-0.057753681872478216 130:2.078125:5374:5375 "
    s .= "~0.009999027424559458 ~-0.0449866054104328 204:-0.25:5377:5378 ~-0.04605201148345859 ~0.0021286991972074153 11:0.59375:5380:5389 249:0.16666666666666666:5381:5386 6:0.46875:5382:5385 228:-0.359375:5383:5384 "
    s .= "~-0.07022015717690551 ~0.006705749373031807 ~-0.06588295396003559 126:0.203125:5387:5388 ~-0.03251546923960843 ~0.0072242252922299745 ~0.05626531424815086 38:0.484375:5391:5404 255:0.328125:5392:5401 "
    s .= "254:0.703125:5393:5400 110:0.4375:5394:5395 ~0.04799761596921835 251:1.203125:5396:5399 11:0.796875:5397:5398 ~-0.03397258248075705 ~0.14863022552465707 ~0.03604225937624967 ~0.05740171909701948 15:0.3046875:5402:5403 "
    s .= "~-0.06828185883186168 ~0.07213789364201524 ~-0.026200296372438425 ~-0.03011608094689825 253:-0.09764309764309784:5407:5414 252:0.125:5408:5409 ~-0.008242561711511115 46:-0.265625:5410:5413 54:0.6953125:5411:5412 "
    s .= "~-0.004062717998714785 ~-0.20443039608299154 ~0.03393335283464682 226:-0.34375:5415:5418 110:0.984375:5416:5417 ~-0.03727243279556209 ~0.042799080799096396 224:0.578125:5419:5452 246:0.203125:5420:5435 "
    s .= "236:-0.0625:5421:5430 26:-0.71875:5422:5423 ~0.01551981327567937 198:-0.484375:5424:5427 160:1.5:5425:5426 ~-0.06327744595662763 ~0.053662270088199515 14:-0.03125:5428:5429 ~-0.010328761622693475 ~0.01980480040502773 "
    s .= "63:-0.09375:5431:5434 82:0:5432:5433 ~0.06846590102092574 ~-0.009116320766112837 ~-0.03921661443444063 254:1.265625:5436:5451 71:0.46875:5437:5450 242:0.35:5438:5443 151:0.5:5439:5442 94:0.21875:5440:5441 "
    s .= "~-0.04622911578309894 ~0.036279058786754546 ~0.05176501488640294 131:0.140625:5444:5445 ~0.04523364379696622 191:0.359375:5446:5447 ~0.024004268718750284 11:0.796875:5448:5449 ~-0.01505019554973617 ~0.1068617968068098 "
    s .= "~-0.01544742742443192 ~-0.05862582343484068 ~-0.0302877779551567 98:0.609375:5454:5499 251:0.421875:5455:5470 241:0.32:5456:5467 160:1.203125:5457:5466 55:0.03125:5458:5465 106:0.328125:5459:5462 69:0.71875:5460:5461 "
    s .= "~-0.027610983395517492 ~0.05751626623602146 94:0.328125:5463:5464 ~0.0339897860384076 ~-0.046489690450986026 ~-0.023727334864222085 ~0.03580399484109782 253:-0.07222222222222001:5468:5469 ~0.0017938016453796805 "
    s .= "~-0.03955101567280647 130:1.84375:5471:5496 238:0.265625:5472:5489 232:-0.234375:5473:5476 166:-0.078125:5474:5475 ~-0.02971156469203891 ~0.016227319650261987 88:0.796875:5477:5488 103:0.8125:5478:5487 "
    s .= "113:0.78125:5479:5486 22:0.953125:5480:5485 2:-0.125:5481:5482 ~0.007471605238268982 11:0.875:5483:5484 ~-0.02416321049701187 ~0.08321725074674595 ~0.06242483417044915 ~0.03793704913516612 ~0.03589163874388236 "
    s .= "~0.03215919376115096 244:1.11:5490:5493 211:0.234375:5491:5492 ~0.007150921657814027 ~-0.05131746765462243 205:0.078125:5494:5495 ~-0.029465493301155766 ~0.021112400049957864 223:0.015625:5497:5498 "
    s .= "~-0.049175922185155874 ~0.00001967382231888864 ~-0.03055511154068761 217:-0.15625:5501:5504 249:0.8333333333333333:5502:5503 ~-0.004777364226920121 ~-0.04086422050891725 88:1.328125:5505:5544 133:2.0625:5506:5543 "
    s .= "202:0.25:5507:5532 224:0.640625:5508:5531 255:0.265625:5509:5526 255:0.140625:5510:5521 82:-0.40625:5511:5512 ~0.06408598716832968 106:0.84375:5513:5520 247:0.546875:5514:5517 245:1.3725490196078431:5515:5516 "
    s .= "~-0.05578810854561589 ~-0.005553273081338841 250:1.2265625:5518:5519 ~-0.03279040243929179 ~0.04721752697405234 ~0.020999101185108116 242:0.45:5522:5525 122:0.09375:5523:5524 ~0.02532404056900507 ~-0.04712690121980584 "
    s .= "~0.03985461867784992 98:-0.46875:5527:5528 ~0.012222847189212087 250:1.1796875:5529:5530 ~-0.04638701765476766 ~0.0024683266191410785 ~-0.042948250395310666 244:1.49:5533:5538 192:0.203125:5534:5535 "
    s .= "~-0.030138080544149404 244:1:5536:5537 ~-0.020196156974919086 ~0.033485188571448284 223:-0.15625:5539:5540 ~-0.11339739464033056 67:0.640625:5541:5542 ~0.03237817404367887 ~-0.07013695232676641 ~-0.04037142373612979 "
    s .= "127:1.375:5545:5546 ~0.029622295493553715 ~-0.017433135876635655 203:0.609375:5548:5593 246:0.140625:5549:5572 236:-0.0625:5550:5569 50:-0.65625:5551:5558 110:-0.234375:5552:5557 143:-0.546875:5553:5556 "
    s .= "25:0.484375:5554:5555 ~0.02216728033645225 ~-0.03010424199322076 ~-0.021259339229807335 ~0.05192082018073943 255:0.234375:5559:5564 174:-0.34375:5560:5561 ~-0.04120046128808376 187:-0.046875:5562:5563 "
    s .= "~-0.01812784376318636 ~0.01851599617292132 244:1.48:5565:5568 219:0.453125:5566:5567 ~-0.047507479447409226 ~0.011892185251444747 ~0.0009739899690654401 42:-0.046875:5570:5571 ~0.003584440569190514 ~-0.03533870585474541 "
    s .= "250:1.1171875:5573:5582 98:0.0625:5574:5577 121:-0.25:5575:5576 ~-0.052734805623873005 ~0.02303377268844649 4:0.078125:5578:5581 249:0.5:5579:5580 ~0.011472166293639462 ~-0.049573028975338405 ~-0.049934651877278885 "
    s .= "111:0.3203125:5583:5592 245:1.1547619047619047:5584:5587 13:0.640625:5585:5586 ~-0.04904575294556738 ~0.17055190021112032 254:0.953125:5588:5591 45:0.0546875:5589:5590 ~0.03258948693616637 ~-0.0023426026307728077 "
    s .= "~0.040575677322947194 ~0.04323979419000523 ~-0.028582386580100136 254:1.359375:5595:5638 146:-0.125:5596:5611 147:-0.6875:5597:5598 ~-0.03637188831990847 98:-0.96875:5599:5602 97:0.484375:5600:5601 ~0.04463470530030324 "
    s .= "~-0.019132879273868655 113:-0.234375:5603:5610 244:1.49:5604:5609 159:-0.1171875:5605:5606 ~-0.023604968513591743 255:0.046875:5607:5608 ~0.04550601465120291 ~-0.008409557263659237 ~0.01471367397624428 "
    s .= "~0.019532287039716965 246:0.015625:5612:5621 244:1.385:5613:5614 ~-0.04473628698051879 162:-0.046875:5615:5620 228:-0.359375:5616:5619 214:1.046875:5617:5618 ~-0.03253127057476604 ~-0.30583052884744544 "
    s .= "~0.02325360511761159 ~-0.04293058181467918 200:0.640625:5622:5637 250:1.1171875:5623:5630 122:0.046875:5624:5625 ~0.01916528872385781 7:0.109375:5626:5629 232:-0.15625:5627:5628 ~-0.06393340406597596 "
    s .= "~0.0003484316027059255 ~-0.05158909683910093 132:0.2890625:5631:5636 245:1.1547619047619047:5632:5633 ~-0.04786413303572801 12:0.515625:5634:5635 ~0.019223031875675103 ~-0.01940305798170129 ~0.03987273772905238 "
    s .= "~-0.03523424262339569 50:-0.6875:5639:5640 ~0.0021087569659895625 ~-0.05543334161911713 257:0.9090909090909091:5642:5685 146:-0.125:5643:5654 247:-0.984375:5644:5649 167:-0.484375:5645:5648 118:0.296875:5646:5647 "
    s .= "~0.01640741519821463 ~-0.03745109965021239 ~-0.05830053428381561 253:-0.04248366013072058:5650:5651 ~0.02688457466361506 130:2.078125:5652:5653 ~0.00855899041935904 ~-0.04019739526399897 245:2.13953488372093:5655:5680 "
    s .= "243:1.45:5656:5677 252:0.42500000000000004:5657:5672 136:0.640625:5658:5669 101:0.515625:5659:5668 35:0.5:5660:5667 106:0.71875:5661:5666 58:1.0625:5662:5665 256:0.20689655172413793:5663:5664 ~-0.046952456781275506 "
    s .= "~0.0014633941374883547 ~0.05713483472364861 ~0.01541520353245658 ~0.054713618304631166 ~-0.04634221011501541 228:-0.359375:5670:5671 ~-0.09092557771866037 ~0.01572674154573676 205:0.1875:5673:5674 ~0.0397242288276885 "
    s .= "251:1.203125:5675:5676 ~-0.03631210465038056 ~0.03502037346468038 251:1.609375:5678:5679 ~-0.05145683123995018 ~0.014696065040681092 252:2.175:5681:5684 202:0.03125:5682:5683 ~-0.052582916563739104 ~-0.01472410058738797 "
    s .= "~0.03497689444249201 245:1.6547619047619047:5686:5687 ~-0.051022778936399615 ~0.00022797058522908972 167:0.5625:5689:5734 113:0.78125:5690:5731 229:-0.1875:5691:5694 178:0.109375:5692:5693 ~-0.0014620339099449548 "
    s .= "~-0.038809030604552826 88:1.15625:5695:5726 257:0.9090909090909091:5696:5721 149:0.125:5697:5718 254:1.265625:5698:5717 246:0.203125:5699:5716 133:2.0625:5700:5713 223:0.578125:5701:5712 128:-0.484375:5702:5703 "
    s .= "~0.023803007621105557 252:0.42500000000000004:5704:5711 242:0.55:5705:5708 184:0.046875:5706:5707 ~-0.0202453719725632 ~0.021711292266630062 149:-0.453125:5709:5710 ~0.02619320878111625 ~-0.04064520087190028 "
    s .= "~0.026696833460059327 ~-0.03237008035818139 73:-0.140625:5714:5715 ~0.03067336552597312 ~-0.060854508552038805 ~0.027138931526453716 ~-0.02497655145220047 103:0.640625:5719:5720 ~-0.019996623167395658 "
    s .= "~0.011074160100363922 115:0.28125:5722:5725 244:1.15:5723:5724 ~-0.036992253939219726 ~0.04351823351693426 ~-0.05551793652645233 127:1.078125:5727:5730 172:-0.21875:5728:5729 ~-0.045737487846925585 ~0.03666984407269258 "
    s .= "~-0.012031043301418723 114:0.5703125:5732:5733 ~0.04147697032969141 ~-0.059017148216809756 ~-0.023139784169337308 248:1.125:5736:5781 257:0.9090909090909091:5737:5778 203:0.640625:5738:5777 205:-0.5:5739:5740 "
    s .= "~-0.03780170111305603 133:2.09375:5741:5774 254:1.296875:5742:5771 228:-0.59375:5743:5746 23:-0.15625:5744:5745 ~0.0008310108419061767 ~-0.07612311684852463 212:-0.546875:5747:5748 ~0.02530571137420158 "
    s .= "246:-2.078125:5749:5750 ~-0.05156707500984368 64:0.625:5751:5768 11:0.921875:5752:5767 79:0.734375:5753:5766 208:0.78125:5754:5765 106:-0.28125:5755:5756 ~0.04113448336965812 77:0.296875:5757:5764 "
    s .= "256:0.03278688524590164:5758:5763 109:1.6875:5759:5762 39:0.421875:5760:5761 ~0.0016495217373454656 ~-0.031844647420720844 ~-0.052460027658292996 ~0.02224169759784268 ~-0.024098761847970423 ~0.03600015285150097 "
    s .= "~0.023756164797808777 ~0.07088733505558195 55:0.96875:5769:5770 ~0.03403880517083164 ~-0.028759431969315505 35:-0.609375:5772:5773 ~0.006619825516917827 ~-0.059826924678224536 255:0.390625:5775:5776 "
    s .= "~-0.04320824618681929 ~0.02146967967184263 ~-0.03064854378132273 133:0.921875:5779:5780 ~-0.04610258013358392 ~0.007795272835588416 ~-0.024180468919831184 190:-0.28125:5783:5784 ~-0.019958268926121348 "
    s .= "166:0.3125:5785:5824 85:0.734375:5786:5815 139:0.5:5787:5802 113:0.71875:5788:5799 4:-0.03125:5789:5792 181:0.578125:5790:5791 ~-0.0064633559553646195 ~0.033049756801913 85:-0.46875:5793:5794 ~0.07129942280502284 "
    s .= "31:0.453125:5795:5798 106:-0.21875:5796:5797 ~0.03856844198967673 ~-0.033229324078572105 ~0.007700074998214063 191:0.5:5800:5801 ~0.04043566699552065 ~-0.034778656282405666 244:1.835:5803:5812 106:0.015625:5804:5805 "
    s .= "~-0.015792948818221124 46:-0.265625:5806:5807 ~-0.040780513495522974 252:0.025:5808:5809 ~0.051631862803442945 4:0.203125:5810:5811 ~0.0274037120001571 ~-0.04481036434302498 157:0.390625:5813:5814 ~-0.07433297912902881 "
    s .= "~0.018412970568968363 232:-0.0625:5816:5821 245:1.9701492537313432:5817:5818 ~0.016980978579544125 242:0.8500000000000001:5819:5820 ~-0.05399706580656828 ~0.020290941267269928 160:-0.1875:5822:5823 "
    s .= "~-0.056511821254441576 ~0.027615589480354648 228:-0.46875:5825:5826 ~-0.04459596918196467 122:-0.59375:5827:5828 ~0.022898130895843555 ~-0.011647393966341136 251:0.328125:5830:5841 241:0.38:5831:5840 94:0.3125:5832:5839 "
    s .= "208:0.171875:5833:5836 106:0.359375:5834:5835 ~-0.03110328673558421 ~0.008893976991128849 136:0.390625:5837:5838 ~-0.021375718226928974 ~0.03521049081876592 ~-0.038225844222623435 ~-0.0433532104674432 "
    s .= "50:-0.109375:5842:5857 246:-0.390625:5843:5846 128:-0.578125:5844:5845 ~0.0155256971277168 ~-0.01955788786526481 121:-0.265625:5847:5848 ~-0.03506513245017006 154:1.984375:5849:5856 143:0.171875:5850:5851 "
    s .= "~0.035478103130028964 57:0.3828125:5852:5853 ~0.02951100983920259 28:0.15625:5854:5855 ~-0.04244094343912872 ~0.041759695258534554 ~-0.04203502992071392 254:1.015625:5858:5875 249:1.1666666666666665:5859:5874 "
    s .= "208:0.21875:5860:5867 79:0.453125:5861:5866 109:1.703125:5862:5863 ~0.006722453248787181 256:0.02564102564102564:5864:5865 ~-0.07769298514575701 ~0.012006560419028941 ~0.030820842899628793 244:1.49:5868:5873 "
    s .= "232:0.109375:5869:5870 ~0.009428371003423273 162:0.625:5871:5872 ~-0.04875684970962578 ~0.04328582280375309 ~0.017315560250405496 ~-0.035978574184093524 ~-0.06361941235115397 253:-0.09764309764309784:5877:5884 "
    s .= "248:0.125:5878:5881 184:-0.234375:5879:5880 ~-0.06003890225983214 ~0.03475309091691911 51:0.2890625:5882:5883 ~-0.019403008553263653 ~0.03246557241654652 254:1.046875:5885:5916 109:1.859375:5886:5911 "
    s .= "167:0.5625:5887:5910 113:0.78125:5888:5907 11:0.828125:5889:5906 226:-0.3125:5890:5891 ~-0.03210318299293688 50:0.25:5892:5903 231:-0.625:5893:5894 ~-0.029933472150269026 224:0.125:5895:5902 110:0.03125:5896:5899 "
    s .= "125:-0.609375:5897:5898 ~0.023670918465851825 ~-0.001232995920331151 56:-0.125:5900:5901 ~0.047171602149099046 ~0.012146276162912369 ~-0.010171926140622711 103:0.96875:5904:5905 ~-0.028541669793902626 "
    s .= "~0.020627352180180237 ~0.06045701152255023 114:0.5859375:5908:5909 ~0.040798925919316234 ~-0.05742695658925739 ~-0.02317338237393018 215:-0.5625:5912:5913 ~0.012761694588291557 256:0:5914:5915 ~-0.053923230471716224 "
    s .= "~0.010926900637819023 26:-0.375:5917:5922 161:-0.25:5918:5921 109:1.015625:5919:5920 ~-0.04222858161308313 ~0.01601714487341156 ~0.03766015670341779 ~-0.06400550461146008 98:0.609375:5924:5969 251:0.828125:5925:5950 "
    s .= "148:0.390625:5926:5949 172:-0.390625:5927:5928 ~-0.03915538905283144 88:0.71875:5929:5944 241:0.5:5930:5943 23:0.71875:5931:5940 184:0.625:5932:5939 133:0.234375:5933:5936 109:0.140625:5934:5935 ~-0.031543086697335916 "
    s .= "~0.03996022175999569 10:1.21875:5937:5938 ~-0.015977430019609495 ~0.08385633630308423 ~0.029871049804917917 191:0.53125:5941:5942 ~0.1382558279234397 ~-0.04309711997130788 ~-0.03267141999767268 142:0.484375:5945:5948 "
    s .= "226:-0.140625:5946:5947 ~-0.0215854419550543 ~0.0378845471946141 ~-0.023903460612791107 ~-0.023073443249950587 252:0.32499999999999996:5951:5964 46:0.625:5952:5963 244:0.965:5953:5956 228:0.171875:5954:5955 "
    s .= "~0.0709676003608376 ~-0.011028609415447966 232:-0.015625:5957:5960 208:0.203125:5958:5959 ~-0.038135913857923635 ~0.026251585248342715 85:0.984375:5961:5962 ~-0.007967481120958391 ~0.0333128860643031 "
    s .= "~0.04589235934006196 19:0.484375:5965:5968 243:1.35:5966:5967 ~0.035566226934453535 ~0.005641776362102367 ~-0.04330906385023644 ~-0.02778198042436176 254:1.359375:5971:6014 47:0.234375:5972:6001 246:0.203125:5973:5992 "
    s .= "212:0.015625:5974:5989 125:-0.59375:5975:5982 144:-0.734375:5976:5977 ~-0.027107404390432622 254:0.890625:5978:5979 ~0.028035378157367775 109:1.1875:5980:5981 ~-0.02795354782313817 ~0.03445827896643072 "
    s .= "246:-2.265625:5983:5984 ~-0.04793616809099883 31:0.046875:5985:5988 223:-0.171875:5986:5987 ~-0.018551773053044382 ~0.016454785986599933 ~-0.014174541523221668 72:-0.03125:5990:5991 ~0.0012634875779600479 "
    s .= "~-0.04640310356813809 245:1.1142857142857143:5993:5994 ~-0.048404711621590796 122:0.296875:5995:5998 242:0.25:5996:5997 ~-0.05184662474067651 ~0.028600160391219032 245:1.8974358974358974:5999:6000 ~0.011598654985412505 "
    s .= "~-0.030076598236206842 228:-0.328125:6002:6003 ~-0.07259870169504777 24:0.09375:6004:6007 194:0.34375:6005:6006 ~-0.010366221508638633 ~0.03343397849724083 102:0.2890625:6008:6009 ~-0.03126459886661991 "
    s .= "178:-0.171875:6010:6011 ~0.07159892582972621 112:0.78125:6012:6013 ~-0.030532895921006022 ~0.02769223862571813 50:-0.6875:6015:6016 ~0.002177892048344811 ~-0.05143077245332938 190:-0.109375:6018:6029 244:1.56:6019:6024 "
    s .= "133:0.125:6020:6023 76:0.140625:6021:6022 ~-0.02058433406371567 ~0.03794964970341394 ~-0.0285831109962165 245:1.6129032258064515:6025:6026 ~0.05808911748901229 252:0.07500000000000001:6027:6028 ~-0.045248926478323986 "
    s .= "~0.022876792264555048 167:0.5625:6030:6063 141:0.0703125:6031:6050 36:0.40625:6032:6049 2:-0.65625:6033:6036 1:0.25:6034:6035 ~0.029500056287776077 ~-0.01981811353774442 175:0.25:6037:6044 79:0.1875:6038:6043 "
    s .= "165:-0.28125:6039:6040 ~0.02363389315459722 106:1.734375:6041:6042 ~-0.010135758055640293 ~-0.09834229727150356 ~0.0184710800730954 96:-0.3671875:6045:6046 ~-0.06669820155450602 244:0.925:6047:6048 ~-0.05632852162952189 "
    s .= "~-0.005798864665655761 ~-0.035889472739435276 88:0.09375:6051:6054 165:0.234375:6052:6053 ~0.015430447130823734 ~-0.018114295056671063 211:0.15625:6055:6056 ~0.03250733059791019 243:0.25:6057:6058 ~0.061302591802225095 "
    s .= "251:0.953125:6059:6062 109:1.296875:6060:6061 ~-0.03883820179822883 ~0.025866319146647717 ~0.025695587708257056 ~-0.02762785851050195 257:0.9090909090909091:6065:6108 205:-0.5:6066:6067 ~-0.03749303844684453 "
    s .= "203:0.609375:6068:6107 254:1.296875:6069:6104 133:2.09375:6070:6099 144:-0.828125:6071:6072 ~-0.04855732387679768 146:-0.125:6073:6076 17:0.21875:6074:6075 ~0.016540674026654704 ~-0.01793450649029055 "
    s .= "144:0.0625:6077:6086 249:0.16666666666666666:6078:6085 228:-0.328125:6079:6082 214:1.046875:6080:6081 ~-0.03641747467821222 ~-0.2644893790222387 213:-0.015625:6083:6084 ~0.02420538651804867 ~-0.01232668579535699 "
    s .= "~-0.0259882079532629 103:0.640625:6087:6098 77:0.015625:6088:6089 ~0.021290477184897596 245:1.9482758620689655:6090:6095 255:0.140625:6091:6094 247:0.578125:6092:6093 ~-0.02637013016378096 ~0.033365053243519925 "
    s .= "~0.03754347573553564 254:0.640625:6096:6097 ~-0.010853260260333916 ~-0.08011531800924296 ~0.02961703413601703 255:0.390625:6100:6103 204:-0.25:6101:6102 ~0.02739943058584181 ~-0.055109162495502934 ~0.03024180599464642 "
    s .= "32:-0.59375:6105:6106 ~0.005439437887978025 ~-0.0517042417757537 ~-0.026007326771497905 245:1.5921052631578947:6109:6110 ~-0.05311521825684026 ~-0.0024913946683675866 251:0.265625:6112:6121 241:0.32:6113:6120 "
    s .= "94:0.3125:6114:6119 205:0.625:6115:6118 106:0.625:6116:6117 ~-0.018893613142086017 ~0.024804204442492882 ~0.04602895485059261 ~-0.04281766658646588 ~-0.03924176823649433 255:0.265625:6122:6151 255:0.140625:6123:6144 "
    s .= "109:2.046875:6124:6143 109:1.1875:6125:6142 110:0.984375:6126:6141 245:1.6320754716981132:6127:6132 247:0.578125:6128:6131 244:1.215:6129:6130 ~-0.051365351826845755 ~0.024873529044394407 ~0.023018031980613876 "
    s .= "43:0.3125:6133:6138 23:0.921875:6134:6137 22:-0.203125:6135:6136 ~-0.039955922218913274 ~0.0008048030149903626 ~0.17019166863391202 252:0.025:6139:6140 ~0.06460574277448829 ~-0.007106106815966827 ~0.039374787918451455 "
    s .= "~0.016943397063302244 ~-0.045821193519005654 245:1.9058823529411764:6145:6146 ~0.04275230298068958 122:0.046875:6147:6150 217:-0.046875:6148:6149 ~-0.02338239323999622 ~0.04216446712363253 ~-0.039030347415977676 "
    s .= "74:-0.546875:6152:6153 ~0.012122817163704565 254:0.828125:6154:6157 257:0.4166666666666667:6155:6156 ~-0.0018565823504349958 ~-0.06627828460265987 ~-0.04354018366254125 253:-0.09764309764309784:6159:6166 "
    s .= "252:0.125:6160:6161 ~-0.008586919701090746 46:-0.265625:6162:6165 233:-0.109375:6163:6164 ~0.021831716823731404 ~-0.07694809596659825 ~0.03165147000810813 254:0.984375:6167:6194 109:1.859375:6168:6187 41:0.5:6169:6182 "
    s .= "11:0.71875:6170:6181 89:0.78125:6171:6180 226:-0.3125:6172:6175 205:0.234375:6173:6174 ~-0.042175123891683215 ~0.03087615584154841 50:0.09375:6176:6179 223:0.421875:6177:6178 ~0.010278056808977485 ~-0.014122850613275601 "
    s .= "~-0.012051349950151873 ~0.038970515656580794 ~0.0727495499188405 107:0.421875:6183:6186 31:-0.171875:6184:6185 ~-0.05950097598621706 ~0.04220106481681084 ~-0.03880353547069624 187:0.125:6188:6191 242:1.05:6189:6190 "
    s .= "~-0.059888540741559394 ~0.025463628906614546 16:-0.015625:6192:6193 ~0.03033256406047363 ~-0.03263758013769705 26:-0.375:6195:6202 161:-0.25:6196:6199 133:1.078125:6197:6198 ~-0.04056088399100585 ~0.01071863254907781 "
    s .= "95:-0.296875:6200:6201 ~0.054692054732770556 ~-0.02505994760695105 255:0.203125:6203:6204 ~0.009239976620467074 ~-0.06413459479103144 251:0.828125:6206:6233 110:0.5625:6207:6232 249:1.8333333333333335:6208:6231 "
    s .= "243:1.15:6209:6230 8:0.53125:6210:6229 55:-0.046875:6211:6216 242:1.25:6212:6215 195:-0.34375:6213:6214 ~-0.024038864929539727 ~0.022826871361922796 ~-0.0647642847569567 88:0.828125:6217:6226 133:0.171875:6218:6221 "
    s .= "109:0.078125:6219:6220 ~-0.057521676242219724 ~0.04119492386195841 243:0.45:6222:6225 184:0.09375:6223:6224 ~-0.03367541346973326 ~0.011897669897837767 ~-0.03162660539245093 181:0.703125:6227:6228 ~0.03021340538272065 "
    s .= "~-0.02373133362052274 ~0.05708226022292543 ~-0.02733636374514037 ~-0.043893760426527983 ~-0.03344727333093713 252:0.32499999999999996:6234:6245 149:-0.4375:6235:6236 ~0.014664205933039177 246:-0.359375:6237:6238 "
    s .= "~-0.03719021862679639 128:0.0625:6239:6242 19:0.21875:6240:6241 ~0.002214928110232777 ~0.06188957066497002 251:1.578125:6243:6244 ~-0.0062661063782944604 ~-0.050887713910245796 19:0.484375:6246:6251 "
    s .= "208:0.390625:6247:6248 ~0.030166610919749877 121:0.0625:6249:6250 ~-0.04213904503166084 ~0.027283216079469243 ~-0.03920072531355444 190:-0.0625:6253:6264 76:0.359375:6254:6261 106:0.59375:6255:6260 "
    s .= "79:-0.078125:6256:6257 ~-0.0037088826173045184 91:0.703125:6258:6259 ~-0.04615261493478981 ~0.005130787740764341 ~-0.00025145990311094973 157:0.3125:6262:6263 ~0.042985383473876135 ~-0.008993667842708358 "
    s .= "167:0.5625:6265:6298 257:0.30985915492957744:6266:6289 64:-0.15625:6267:6268 ~-0.014113384034358124 133:2.15625:6269:6286 248:1.375:6270:6285 242:0.35:6271:6276 70:0.328125:6272:6275 178:0.578125:6273:6274 "
    s .= "~-0.02326929166558812 ~0.03851836390577125 ~0.042534771369400676 253:-0.04403409090909091:6277:6278 ~0.03121048666129128 248:0.125:6279:6282 251:1.203125:6280:6281 ~-0.02070201607754208 ~0.032690369668308634 "
    s .= "244:1.37:6283:6284 ~0.028153286065201018 ~-0.004046884879334688 ~-0.03334046750771266 255:0.390625:6287:6288 ~-0.06855155597056398 ~0.02449877174042953 233:-0.234375:6290:6297 142:0.21875:6291:6292 ~0.019610864142700885 "
    s .= "244:1.05:6293:6294 ~-0.052146889733522085 70:0.625:6295:6296 ~0.010716235159080233 ~-0.05787233099543916 ~-0.039648360484053013 ~-0.027896126404441585 124:-0.484375:6300:6301 ~-0.030237558823484396 91:1.296875:6302:6343 "
    s .= "209:0.640625:6303:6342 254:1.296875:6304:6339 133:2.0625:6305:6338 244:1.505:6306:6327 246:-0.609375:6307:6312 167:-0.3125:6308:6311 245:1.6547619047619047:6309:6310 ~-0.04098368617927122 ~0.005025057848075174 "
    s .= "~-0.05208233540770179 41:-0.015625:6313:6318 170:0.109375:6314:6315 ~0.02452499584690215 210:0.125:6316:6317 ~-0.025803550343304244 ~0.025311118542488315 157:0.28125:6319:6322 76:0.234375:6320:6321 "
    s .= "~-0.005395969318322431 ~0.03976620495958513 7:0.109375:6323:6326 244:0.91:6324:6325 ~-0.05206760603324925 ~0.004653368298604626 ~-0.04728606925079927 157:0.125:6328:6331 106:0.5625:6329:6330 ~-0.06235582415453239 "
    s .= "~0.008682868866092314 235:0:6332:6337 250:1.5234375:6333:6334 ~0.00794779589298137 257:0.30985915492957744:6335:6336 ~0.019654659205545467 ~-0.38771843519282256 ~0.03552852953469229 ~-0.026865613654471807 "
    s .= "26:-0.59375:6340:6341 ~-0.003835889387367588 ~-0.053546591502030755 ~-0.032416455683133644 127:1.28125:6344:6345 ~0.032454428712050606 ~-0.018652152316179834 251:0.421875:6347:6358 241:0.3:6348:6357 "
    s .= "160:1.203125:6349:6356 107:0.46875:6350:6355 55:0.03125:6351:6354 106:0.078125:6352:6353 ~-0.02149488328619949 ~0.023213548938466222 ~-0.01931818031837329 ~-0.05007096312632642 ~0.03379425035381941 "
    s .= "~-0.024584182035726033 238:0.296875:6359:6386 130:1.84375:6360:6383 2:-0.265625:6361:6370 243:0.6499999999999999:6362:6369 166:-0.296875:6363:6364 ~-0.06000992933205268 133:1.5:6365:6366 ~0.020064063640189124 "
    s .= "70:0.546875:6367:6368 ~-0.03655527240454461 ~0.07764012341216675 ~0.02903964728654983 254:1.046875:6371:6382 108:0.3203125:6372:6379 49:-0.09375:6373:6374 ~-0.019097687534712415 255:0.140625:6375:6378 "
    s .= "152:0.59375:6376:6377 ~0.005649678751851939 ~-0.0393909321464207 ~0.0232803726944801 250:1.1640625:6380:6381 ~-0.01987962872818673 ~0.04626509475187634 ~-0.05941598349180452 79:0.234375:6384:6385 ~-0.04106681204059444 "
    s .= "~0.008326312850916276 136:1.046875:6387:6390 214:0.59375:6388:6389 ~-0.01386612328434165 ~-0.05999348399608356 145:0.0625:6391:6392 ~-0.016813434578258953 ~0.038845637015438715 187:-0.3125:6394:6397 242:0.75:6395:6396 "
    s .= "~-0.04096323420612 ~0.004426754376370336 163:0.34375:6398:6423 91:0.796875:6399:6420 136:1.90625:6400:6419 106:0.3125:6401:6410 84:0.2265625:6402:6407 76:0.546875:6403:6406 205:0.625:6404:6405 ~-0.02793358872512069 "
    s .= "~0.0387233414695372 ~0.04594179809895444 106:-0.265625:6408:6409 ~0.06680790687312335 ~0.007469199169878005 166:1.28125:6411:6418 148:0:6412:6415 28:0.40625:6413:6414 ~0.03383507154295943 ~-0.0364718456875216 "
    s .= "244:0.925:6416:6417 ~-0.024462789415781325 ~0.012597920429211202 ~-0.04737267232613329 ~-0.03917037772410496 196:-0.0625:6421:6422 ~-0.016418253088573097 ~0.03630305573705146 244:1.505:6424:6437 186:-0.515625:6425:6426 "
    s .= "~-0.055937770319311776 243:0.45:6427:6432 242:0.55:6428:6431 122:-0.171875:6429:6430 ~0.022312188480305004 ~-0.043932157413452855 ~0.05298966852131103 251:1.015625:6433:6434 ~-0.03418622996015724 245:1.5:6435:6436 "
    s .= "~-0.04461438893087111 ~0.020230031672431842 157:0.0625:6438:6439 ~-0.03556530540474733 ~0.020499709777656305 254:0.984375:6441:6480 254:0.953125:6442:6477 245:1.3768115942028984:6443:6450 247:0.578125:6444:6449 "
    s .= "58:0.703125:6445:6448 85:1.8125:6446:6447 ~-0.04141640435728117 ~-0.3067428260883256 ~0.03622245569678495 ~0.027260356116179288 205:-0.3125:6451:6454 251:0.734375:6452:6453 ~-0.05140699261685693 ~0.0021252640367599813 "
    s .= "133:2.09375:6455:6474 225:-0.6484375:6456:6457 ~-0.035045558555947286 146:-0.5:6458:6465 47:-0.640625:6459:6464 187:-0.109375:6460:6461 ~-0.018791777235900416 218:-0.5:6462:6463 ~0.05211982802932683 "
    s .= "~-0.009892112489094294 ~0.005290105633373359 257:0.4166666666666667:6466:6471 255:0.046875:6467:6470 217:-0.609375:6468:6469 ~0.19527759946075768 ~-0.013995674809728648 ~0.010428955979970544 244:1.47:6472:6473 "
    s .= "~-0.038715017264018166 ~0.014655322923102638 228:-0.234375:6475:6476 ~0.031152938514665315 ~-0.04306608791583636 133:1.296875:6478:6479 ~0.03782474878191951 ~-0.025126368740480267 59:-0.625:6481:6484 "
    s .= "257:0.5555555555555556:6482:6483 ~0.020053380420111306 ~-0.04801491384644877 255:0.234375:6485:6486 ~0.008127432132951492 ~-0.04183321636233637 72:1.078125:6488:6533 11:0.921875:6489:6532 74:0.484375:6490:6531 "
    s .= "256:0.009523809523809525:6491:6516 149:-0.015625:6492:6507 134:-0.15625:6493:6504 230:-0.203125:6494:6503 161:-0.1875:6495:6502 29:-0.71875:6496:6497 ~0.011831683221490098 56:-0.0625:6498:6501 28:0.078125:6499:6500 "
    s .= "~-0.006361825194493891 ~-0.04031879783363079 ~0.03105469603114926 ~0.04008955709212657 ~-0.024046722577270634 184:0:6505:6506 ~-0.010006227592211689 ~0.02669550341280201 245:2.13953488372093:6508:6515 "
    s .= "8:0.40625:6509:6514 249:0.16666666666666666:6510:6513 228:-0.328125:6511:6512 ~-0.10507251513579724 ~0.01058327194750794 ~-0.026987900030307266 ~0.0391628794586463 ~-0.03551180405582147 245:1.1142857142857143:6517:6518 "
    s .= "~-0.037518653874429965 255:0.328125:6519:6528 14:0.609375:6520:6527 254:0.703125:6521:6526 110:0.453125:6522:6523 ~0.044840561011324304 251:1.765625:6524:6525 ~-0.024259058633373756 ~0.03585574420998784 "
    s .= "~0.05299611741396742 ~-0.05697946603869156 12:0.5625:6529:6530 ~-0.05705341599842714 ~0.11264452175675913 ~-0.023687727650478194 ~0.04531397752019509 ~-0.06439742087141363 257:0.9090909090909091:6535:6578 "
    s .= "205:-0.5:6536:6537 ~-0.035513929026561294 101:0.5625:6538:6575 110:-1.125:6539:6540 ~-0.01702825767798418 56:-0.8125:6541:6542 ~0.02466735414870792 255:0.234375:6543:6572 106:2.109375:6544:6571 93:-0.046875:6545:6548 "
    s .= "241:3.86:6546:6547 ~0.025260005744689187 ~0.23390542864287453 110:0.09375:6549:6554 215:-0.109375:6550:6553 208:0:6551:6552 ~-0.02018418976704541 ~0.023142546648672414 ~-0.024351937336858396 103:0.65625:6555:6570 "
    s .= "255:0.140625:6556:6565 136:0.796875:6557:6564 246:1.703125:6558:6563 85:-0.390625:6559:6560 ~0.05123651078017458 175:0.578125:6561:6562 ~-0.03872173628515641 ~0.018221516724334884 ~0.04206914790532959 "
    s .= "~0.024966042118389098 88:0.09375:6566:6569 244:0.905:6567:6568 ~0.07092257105734116 ~-0.027678666602970133 ~0.051357819297745466 ~0.037847867405524684 ~-0.055122172263198446 244:1.055:6573:6574 ~-0.031935012339057524 "
    s .= "~-0.001474672660064089 252:0.32499999999999996:6576:6577 ~-0.03968684153263325 ~0.0031290810190488017 240:-0.171875:6579:6580 ~-0.0013491644262776247 ~-0.05194131095580384 72:0.984375:6582:6627 11:0.921875:6583:6624 "
    s .= "74:0.484375:6584:6623 256:0.009523809523809525:6585:6610 184:0.015625:6586:6597 11:0.4375:6587:6596 105:-0.3984375:6588:6589 ~0.019063367290846633 109:1.703125:6590:6595 64:0.203125:6591:6594 82:0.59375:6592:6593 "
    s .= "~-0.03598950889688313 ~0.006619296369302652 ~0.007477106946757324 ~-0.055145157407400724 ~0.050069089935990053 2:0.078125:6598:6605 73:0.140625:6599:6600 ~0.01391724090161129 126:0.21875:6601:6604 66:0.171875:6602:6603 "
    s .= "~-0.00860156180683886 ~-0.05455323862342762 ~0.021722542513396507 241:0.34:6606:6609 219:-0.109375:6607:6608 ~-0.063653552372813 ~0.008252790464059384 ~-0.03319795432530271 191:0.546875:6611:6622 78:-0.1484375:6612:6613 "
    s .= "~-0.058947599130140485 245:1.1142857142857143:6614:6617 68:0.84375:6615:6616 ~-0.04514463625770759 ~0.14978877426605672 47:0.515625:6618:6619 ~0.03558998531517955 55:0.609375:6620:6621 ~-0.042421373722858535 "
    s .= "~0.07727648700595204 ~-0.01900616008609509 ~-0.02236962889908635 246:1.546875:6625:6626 ~0.06807494229416633 ~-0.037389146369195186 ~-0.05591605998614627 254:0.984375:6629:6664 254:0.953125:6630:6661 "
    s .= "191:-0.46875:6631:6636 190:0.421875:6632:6633 ~0.020482380925560713 151:0.15625:6634:6635 ~0.013547240040569179 ~-0.03767029148124259 246:-2.015625:6637:6638 ~-0.04839015104386289 85:-0.359375:6639:6640 "
    s .= "~0.03447077903577364 245:1.2597402597402598:6641:6642 ~-0.03675229842168441 246:0.015625:6643:6652 63:-0.09375:6644:6649 244:1.48:6645:6648 246:-0.421875:6646:6647 ~-0.02752843454782968 ~0.028557950926102044 "
    s .= "~0.0239858619390646 164:-0.078125:6650:6651 ~-0.004215267083660014 ~-0.047069043974537705 128:0:6653:6654 ~0.025308658323192252 250:1.2109375:6655:6658 126:0.640625:6656:6657 ~-0.007942267467140163 ~-0.08697927217233481 "
    s .= "247:0.546875:6659:6660 ~0.003452838191260442 ~0.0480261128977075 247:0.359375:6662:6663 ~0.009883946997090401 ~0.058971278650313375 2:-0.1875:6665:6672 257:0.5555555555555556:6666:6671 59:-0.703125:6667:6668 "
    s .= "~0.023785084456513964 255:0.234375:6669:6670 ~0.037477455222875024 ~-0.02538942322413438 ~-0.04313337734797465 255:0.234375:6673:6674 ~-0.007515738478524258 ~-0.06460825001037683 124:-0.65625:6676:6677 "
    s .= "~-0.04159058826872624 124:0.203125:6678:6709 64:0.390625:6679:6706 106:0.515625:6680:6699 229:0.078125:6681:6692 252:0.375:6682:6691 70:0.625:6683:6688 1:0.546875:6684:6685 ~-0.03698076378743847 250:1.5234375:6686:6687 "
    s .= "~0.01922240425601821 ~0.2531920953440844 248:0.125:6689:6690 ~-0.04867062739825434 ~0.056563459464274546 ~0.013807837222988374 160:0.984375:6693:6698 235:0.859375:6694:6695 ~-0.009103798890453629 82:-0.03125:6696:6697 "
    s .= "~-0.05693758081953142 ~0.13668813388657652 ~0.04250067444427341 28:0.171875:6700:6703 136:1.90625:6701:6702 ~0.018825544378754857 ~-0.031687955408926154 214:0.3125:6704:6705 ~-0.0008541815793181895 ~-0.07185062318232792 "
    s .= "121:-0.09375:6707:6708 ~-0.008370398238088285 ~0.030647561937856733 183:-0.515625:6710:6711 ~-0.044541201112808515 122:-0.78125:6712:6717 250:0.9609375:6713:6714 ~-0.032050450600238096 243:0.45:6715:6716 "
    s .= "~0.07085769500530383 ~0.01637924339382876 144:0.046875:6718:6721 112:-0.09375:6719:6720 ~0.025910970048298107 ~-0.027015588668036584 ~0.0026782761151799687 253:-0.09764309764309784:6723:6732 248:0.125:6724:6727 "
    s .= "174:0.5625:6725:6726 ~0.0328462712891523 ~-0.056431770491673784 51:0.2890625:6728:6731 181:0.1875:6729:6730 ~0.008005599771519956 ~-0.0368189374146255 ~0.029986769075482207 110:-1.125:6733:6734 ~-0.019476983838507534 "
    s .= "98:-0.984375:6735:6738 17:-0.34375:6736:6737 ~0.04223095385016784 ~-0.04661611391669945 255:0.265625:6739:6760 255:0.140625:6740:6751 134:0.984375:6741:6750 128:0.5:6742:6745 23:0.921875:6743:6744 "
    s .= "~-0.0027866637096634673 ~0.08947102275295492 108:0.3203125:6746:6747 ~-0.04349082482749199 160:-0.15625:6748:6749 ~0.08763740136449463 ~-0.014908485023122482 ~0.03446244395015536 219:0.140625:6752:6759 "
    s .= "236:0.234375:6753:6758 246:0.296875:6754:6757 252:0.025:6755:6756 ~-0.039733891232853674 ~0.01433338859985443 ~0.05518848064003793 ~-0.035734388991580074 ~0.039708739255712916 254:0.859375:6761:6762 "
    s .= "~-0.0022566155955086433 50:-0.3125:6763:6768 161:-0.21875:6764:6765 ~-0.03116746535823613 95:-0.359375:6766:6767 ~0.05637522585983038 ~-0.020531076526078836 ~-0.059851022247752086 72:1.078125:6770:6815 "
    s .= "251:0.328125:6771:6780 241:0.38:6772:6779 94:0.3125:6773:6778 208:0.171875:6774:6775 ~-0.010457201045488477 25:0.1875:6776:6777 ~0.03089078535729646 ~-0.03344565733058943 ~-0.034501046734497665 ~-0.03916490483349554 "
    s .= "252:0.32499999999999996:6781:6810 242:1.75:6782:6809 184:0.046875:6783:6798 79:0.28125:6784:6795 64:0.578125:6785:6794 199:0.015625:6786:6789 245:1.801980198019802:6787:6788 ~-0.006773024440774156 ~-0.05763247719809277 "
    s .= "105:-0.3984375:6790:6791 ~0.050264343729846 232:0.859375:6792:6793 ~-0.03039990009779846 ~0.07984336281470336 ~0.030443427461562013 103:1.5625:6796:6797 ~0.02664740913803298 ~-0.050971308696367346 73:0.109375:6799:6804 "
    s .= "205:-0.203125:6800:6801 ~-0.03541890285792403 77:0.078125:6802:6803 ~0.024505270238837543 ~-0.004411039803299711 238:0.53125:6805:6808 46:0.609375:6806:6807 ~-0.005382215091361463 ~0.05854849298356092 "
    s .= "~-0.049466353408297775 ~-0.11153243119812671 163:0.28125:6811:6812 ~0.02363919356041489 244:0.99:6813:6814 ~-0.04108894440774894 ~0.006075556531124553 ~-0.06355306240841446 219:0.984375:6817:6862 251:0.328125:6818:6825 "
    s .= "241:0.38:6819:6824 94:0.3125:6820:6823 208:0.171875:6821:6822 ~-0.00980638584985905 ~0.02313394113896898 ~-0.0336582397641511 ~-0.03775098332576654 238:0.53125:6826:6861 252:0.32499999999999996:6827:6850 "
    s .= "184:0.046875:6828:6835 79:0.28125:6829:6834 64:0.578125:6830:6833 199:0.015625:6831:6832 ~-0.04299493987174277 ~-0.012843777483151903 ~0.02470648565026284 ~0.012423063063444281 242:1.65:6836:6849 47:-0.625:6837:6838 "
    s .= "~0.028941138042107597 126:0.3125:6839:6846 43:0.453125:6840:6845 249:0.16666666666666666:6841:6844 245:2.1463414634146343:6842:6843 ~0.021551452872168662 ~-0.04202658982948159 ~-0.016098906836383393 ~0.03849540574882627 "
    s .= "107:0.609375:6847:6848 ~0.03681584765591924 ~-0.04482534732167678 ~-0.09792120175596622 163:0.28125:6851:6856 47:0.515625:6852:6853 ~0.029537320875580204 244:1.085:6854:6855 ~-0.050058458291808244 ~0.03602530394444508 "
    s .= "244:0.99:6857:6860 178:-0.5625:6858:6859 ~0.3140921274648541 ~-0.044603418356633395 ~0.009983257043015187 ~-0.016389229191565744 ~-0.05362978825484802 254:0.984375:6864:6897 254:0.953125:6865:6894 "
    s .= "215:-0.484375:6866:6869 214:0.453125:6867:6868 ~0.019289964621358322 ~-0.01864410600406419 246:-2.015625:6870:6871 ~-0.04590667135195896 245:1.3488372093023255:6872:6879 106:-0.265625:6873:6876 129:0.3515625:6874:6875 "
    s .= "~-0.020111696117961347 ~0.08480405920596341 113:1:6877:6878 ~-0.047301324658887076 ~0.026626337560502908 109:1.96875:6880:6893 109:1.1875:6881:6892 246:0.015625:6882:6885 209:-0.15625:6883:6884 ~-0.00008914189015535876 "
    s .= "~-0.031879442515728204 128:0.125:6886:6887 ~0.020525155854801854 250:1.2265625:6888:6889 ~-0.017058399660896995 247:0.546875:6890:6891 ~-0.003308415451589142 ~0.06145962130349336 ~0.015437765906224938 "
    s .= "~-0.028276735224147566 245:1.891566265060241:6895:6896 ~0.03810099342083198 ~-0.011849743386963056 26:-0.140625:6898:6907 244:1.085:6899:6904 137:-0.046875:6900:6901 ~-0.04989966977577744 47:-0.546875:6902:6903 "
    s .= "~0.08343444551449584 ~-0.02226066280559936 196:-0.046875:6905:6906 ~-0.027888313993061062 ~0.017465405878139505 255:0.234375:6908:6909 ~-0.00853473681966028 ~-0.06529692597996252 191:0.78125:6911:6956 "
    s .= "246:1.765625:6912:6955 247:0.765625:6913:6952 124:-0.484375:6914:6915 ~-0.03422350898218234 85:1.171875:6916:6943 254:1.265625:6917:6942 243:1.45:6918:6939 257:0.30985915492957744:6919:6932 245:2.2:6920:6927 "
    s .= "209:0.578125:6921:6926 174:-0.40625:6922:6923 ~-0.03628242127491944 42:-0.0625:6924:6925 ~0.03362016939168609 ~0.009718778755949994 ~-0.025619228885963893 28:-0.046875:6928:6931 205:-0.015625:6929:6930 "
    s .= "~-0.02388495307034491 ~0.03821670350116116 ~-0.020110443166962574 188:-0.265625:6933:6938 151:0.140625:6934:6935 ~0.021611413356741105 244:1.06:6936:6937 ~-0.04936633150056838 ~0.0028398988305438078 "
    s .= "~-0.04595019864987973 245:1.9838709677419355:6940:6941 ~-0.03845235456379998 ~0.019312116652348152 ~-0.02674247107807419 208:0.03125:6944:6947 181:1.46875:6945:6946 ~0.0028298192207246524 ~-0.06016058884768363 "
    s .= "127:1.078125:6948:6949 ~0.0348030505440819 184:0.96875:6950:6951 ~0.027874090331757386 ~-0.026523069044465736 127:-0.34375:6953:6954 ~0.10311011478276194 ~-0.06231394252013427 ~0.037363140820347196 ~-0.03806923372151419 "
    s .= "72:1.078125:6958:7003 11:0.921875:6959:7002 74:0.484375:6960:7001 256:0.009523809523809525:6961:6996 39:0.4375:6962:6989 148:0.796875:6963:6986 237:0.625:6964:6985 124:-0.65625:6965:6966 ~-0.04989136981486249 "
    s .= "247:0.484375:6967:6984 106:0.046875:6968:6971 245:1.8225806451612903:6969:6970 ~0.022169722283404452 ~-0.023435088010119204 34:0.046875:6972:6973 ~0.016001359545781062 244:2.81:6974:6983 124:-0.625:6975:6976 "
    s .= "~0.3130141457092203 252:0.025:6977:6980 82:0.046875:6978:6979 ~0.05705466880202127 ~0.006130290908927761 244:1.56:6981:6982 ~-0.02074604394890152 ~0.02563926171179506 ~-0.07120902030327828 ~-0.0563391316438587 "
    s .= "~-0.040045694872960634 27:0.21875:6987:6988 ~-0.03211782756525801 ~0.03769619469660726 171:0.28125:6990:6991 ~-0.04645884645944362 187:-0.140625:6992:6993 ~-0.07537466996359925 247:0.703125:6994:6995 "
    s .= "~0.020870125617595877 ~-0.09470997985558449 237:-0.21875:6997:6998 ~-0.05557433002468953 191:0.546875:6999:7000 ~0.02364489968624961 ~-0.01664639974507138 ~-0.020696499482308804 ~0.04152631746979408 "
    s .= "~-0.06308459873161189 257:0.9090909090909091:7005:7048 101:0.5625:7006:7043 8:0.796875:7007:7040 253:-0.09764309764309784:7008:7023 252:0.125:7009:7018 30:-0.1171875:7010:7011 ~-0.06375491339629524 155:0.0625:7012:7013 "
    s .= "~0.02454130010993514 246:0.671875:7014:7017 7:0.0625:7015:7016 ~-0.018770995189808265 ~-0.12184116534763374 ~0.02546940325553252 46:-0.265625:7019:7022 109:1.3125:7020:7021 ~-0.060359938127242566 ~0.0310237349938037 "
    s .= "~0.034654008503465575 246:1.640625:7024:7039 226:-0.3125:7025:7028 255:-0.015625:7026:7027 ~0.08632222339975712 ~-0.032683922926592515 245:3.5454545454545454:7029:7038 110:-1.125:7030:7031 ~-0.020079566309119293 "
    s .= "98:-0.984375:7032:7035 17:-0.34375:7033:7034 ~0.04347724152796014 ~-0.04684389013918404 247:0.734375:7036:7037 ~0.0014633598850621798 ~-0.05168737039031458 ~-0.05207190680886006 ~0.03862632927929302 243:0.55:7041:7042 "
    s .= "~0.0731097852868154 ~-0.032717974246599175 252:0.32499999999999996:7044:7045 ~-0.03812691764937848 250:1.1171875:7046:7047 ~-0.042815616074536565 ~0.018396855047224388 245:1.5921052631578947:7049:7050 "
    s .= "~-0.0498842067895333 ~-0.000986148053224151 72:0.984375:7052:7097 190:-0.0625:7053:7060 76:0.359375:7054:7059 106:0.59375:7055:7058 79:-0.078125:7056:7057 ~-0.0010112244034909046 ~-0.03608409957856775 "
    s .= "~0.0002984677964974381 ~0.014658538169466323 167:0.5625:7061:7096 256:0.03278688524590164:7062:7089 170:0.09375:7063:7080 246:-0.296875:7064:7075 188:-0.34375:7065:7074 247:0.015625:7066:7071 118:0.328125:7067:7068 "
    s .= "~0.01865312250918973 245:1.6547619047619047:7069:7070 ~-0.048964140931932756 ~0.003801028238794623 10:-0.53125:7072:7073 ~0.10010094316022067 ~-0.06673712185399945 ~-0.02210441957557162 50:-0.15625:7076:7077 "
    s .= "~0.030811403502616887 12:0.09375:7078:7079 ~-0.0173066866935347 ~0.020929738821617336 23:0.84375:7081:7088 8:0.40625:7082:7087 257:0.4583333333333333:7083:7084 ~-0.016111258155749573 82:1.8125:7085:7086 "
    s .= "~-0.056582083349451064 ~-0.330414388485323 ~0.019758272924731556 ~0.12198146667983473 255:0.328125:7090:7095 44:0.421875:7091:7094 245:1.1358024691358024:7092:7093 ~-0.0335002439378193 ~0.03921658976633511 "
    s .= "~-0.013058979264259973 ~-0.04082652139409029 ~-0.022877821413898193 ~-0.05435208216746695 254:0.984375:7099:7140 254:0.953125:7100:7139 191:-0.46875:7101:7104 190:0.421875:7102:7103 ~0.01881489531646416 "
    s .= "~-0.014520483624421245 110:-1:7105:7106 ~-0.043668546231717474 133:2.125:7107:7138 245:1.3488372093023255:7108:7111 247:0.578125:7109:7110 ~-0.04070481609430734 ~0.019643724128910016 205:-0.3125:7112:7113 "
    s .= "~-0.028284663276420714 250:1.1953125:7114:7121 247:0.390625:7115:7118 15:0.5078125:7116:7117 ~0.00584065624763366 ~-0.04293496981984768 251:1.203125:7119:7120 ~-0.050325649890768015 ~0.0072044785796191975 "
    s .= "111:0.2578125:7122:7137 61:0.59375:7123:7134 106:1.0625:7124:7131 22:0.484375:7125:7130 23:0.921875:7126:7129 160:0.71875:7127:7128 ~-0.03457182709614743 ~0.012406488950804338 ~0.14679830578974207 ~0.057236301594892396 "
    s .= "115:1.546875:7132:7133 ~0.030675567475989297 ~-0.05668836687171746 243:2.95:7135:7136 ~0.032005716665655756 ~0.3582968829775673 ~0.03957210045983789 ~-0.03656786821322801 ~0.023053851533744882 2:-0.203125:7141:7142 "
    s .= "~-0.0029593965292118492 255:0.234375:7143:7144 ~-0.006565935353960751 ~-0.061246338386317836 91:1.296875:7146:7189 244:1.505:7147:7174 246:-0.578125:7148:7161 233:-0.125:7149:7160 254:0.796875:7150:7157 "
    s .= "138:-0.5703125:7151:7154 71:-0.890625:7152:7153 ~-0.0018400461917701914 ~-0.06597686409096741 101:-0.734375:7155:7156 ~0.0344784041910876 ~-0.007312633893118476 10:-0.140625:7158:7159 ~-0.0040594796885047805 "
    s .= "~-0.04734425414609337 ~-0.05865362294367618 41:0:7162:7169 170:0.125:7163:7166 190:-0.109375:7164:7165 ~-0.0076646710380207025 ~0.02312312933664954 245:1.801980198019802:7167:7168 ~0.010395495472585257 "
    s .= "~-0.031232880918850965 157:0.28125:7170:7173 76:0.25:7171:7172 ~-0.009709688649775956 ~0.035037377941796434 ~-0.02484242696839195 157:0.125:7175:7182 58:0.53125:7176:7181 154:0.625:7177:7180 181:0.703125:7178:7179 "
    s .= "~-0.06525380646666652 ~0.008492120349652368 ~0.021693215798344503 ~0.03007727751537645 235:0:7183:7188 133:1.625:7184:7185 ~0.011331139261840406 245:1.4303797468354431:7186:7187 ~-0.2422335209715889 "
    s .= "~-0.02699852800039594 ~0.028490693173483152 127:1.34375:7190:7191 ~0.02737635594040774 ~-0.02486735651409333 219:0.984375:7193:7238 255:0.265625:7194:7233 255:0.140625:7195:7226 106:2.0625:7196:7225 244:1.49:7197:7220 "
    s .= "108:0.3203125:7198:7217 245:1.6271186440677967:7199:7206 7:0.8125:7200:7203 89:1.03125:7201:7202 ~-0.044096293395879525 ~0.04613988574911512 196:-0.609375:7204:7205 ~0.4476766554874776 ~0.03132242777445631 "
    s .= "23:0.921875:7207:7216 238:0.53125:7208:7215 2:-0.3125:7209:7210 ~0.015206108977414376 246:0.484375:7211:7212 ~-0.025694159785982898 131:0.5:7213:7214 ~0.02785675704777804 ~-0.03450315187185612 ~-0.04015300729806365 "
    s .= "~0.10518142682237708 250:1.1953125:7218:7219 ~-0.025323042721963413 ~0.03412076128788282 184:0.125:7221:7224 82:0.21875:7222:7223 ~-0.036370701059103415 ~0.017427018824144713 ~0.02776534454024106 ~-0.04242458221616133 "
    s .= "219:0.140625:7227:7232 252:0.175:7228:7231 245:1.8461538461538463:7229:7230 ~0.013278830925511338 ~-0.032292397422661864 ~0.023428038689016883 ~0.03586953256098422 98:-0.421875:7234:7235 ~0.006995206204560518 "
    s .= "254:0.828125:7236:7237 ~-0.00999151785860885 ~-0.04535342286781722 ~-0.05251468559696343 124:-0.6875:7240:7241 ~-0.04125551050586971 91:1.296875:7242:7283 85:-0.46875:7243:7244 ~0.03663509966081073 244:1.505:7245:7274 "
    s .= "246:-0.578125:7246:7259 212:-0.3125:7247:7258 255:0.015625:7248:7255 246:-1.984375:7249:7252 23:-0.671875:7250:7251 ~0.006369428358925358 ~-0.06721508317794538 107:-0.484375:7253:7254 ~0.05437023767032359 "
    s .= "~-0.020719279516643867 13:-0.421875:7256:7257 ~0.025135282646791823 ~-0.027199910015855634 ~-0.04683608482260845 41:0:7260:7265 170:0.125:7261:7262 ~0.016954813782153643 188:0.21875:7263:7264 ~0.015073938613945934 "
    s .= "~-0.027806141606050702 224:-0.25:7266:7267 ~-0.04347218751519423 49:-0.140625:7268:7269 ~-0.03179413733141067 254:0.765625:7270:7271 ~-0.009722051357600738 245:2.0707070707070705:7272:7273 ~0.03253166438102794 "
    s .= "~-0.058254629628841925 157:0.125:7275:7280 106:0.609375:7276:7277 ~-0.054674962475139456 58:0.046875:7278:7279 ~-0.027071547583348284 ~0.02859569408105746 235:0:7281:7282 ~-0.004668801704847964 ~0.02731894160187125 "
    s .= "127:1.34375:7284:7285 ~0.027548329441948717 ~-0.021908426467099708 72:1.078125:7287:7332 11:0.921875:7288:7329 247:0.984375:7289:7328 246:1.734375:7290:7325 124:-0.65625:7291:7292 ~-0.04980696237257217 "
    s .= "74:0.109375:7293:7318 253:-0.09124423963133665:7294:7299 252:0.125:7295:7298 51:-0.1796875:7296:7297 ~-0.06609995409517709 ~0.007177692989555411 ~0.027241862412060964 246:-2.015625:7300:7305 239:-0.59375:7301:7304 "
    s .= "244:1.4:7302:7303 ~-0.017853039715011846 ~0.02461567524731306 ~-0.04175250052509421 56:-0.8125:7306:7309 209:-0.296875:7307:7308 ~0.03684550140106898 ~-0.01773793700466565 255:0.234375:7310:7317 255:0.140625:7311:7314 "
    s .= "93:-0.015625:7312:7313 ~0.0164937906663389 ~-0.013437333877543117 107:0.015625:7315:7316 ~0.0026330853476805092 ~0.04130008095039986 ~-0.01038502806446677 139:0.671875:7319:7322 46:-0.25:7320:7321 ~-0.05001125328315717 "
    s .= "~-0.01287551779280442 60:0.0078125:7323:7324 ~-0.031595876556205674 ~0.019685367491970692 215:0.625:7326:7327 ~0.04935714507997979 ~-0.042468986488929925 ~-0.0690259842678105 246:1.546875:7330:7331 ~0.05949463441652515 "
    s .= "~-0.036137477980528 ~-0.0624292600243322 254:0.984375:7334:7373 244:2.905:7335:7370 244:1.635:7336:7361 186:-0.546875:7337:7340 47:-0.828125:7338:7339 ~0.0010619548702394334 ~-0.061847406876140966 64:0.625:7341:7360 "
    s .= "130:1.875:7342:7359 146:-0.53125:7343:7344 ~0.01756928588127009 246:-0.234375:7345:7350 164:-0.109375:7346:7349 255:0.234375:7347:7348 ~0.0018536075117891815 ~-0.044235972764374965 ~-0.0576484317088726 "
    s .= "254:0.765625:7351:7352 ~-0.0067593249942430505 245:1.9107142857142858:7353:7356 242:0.35:7354:7355 ~-0.030552654017654564 ~0.04225376641431683 128:0.125:7357:7358 ~0.010529335038309932 ~-0.05181354142090869 "
    s .= "~-0.04264338987559421 ~0.021955242499339556 245:1.6:7362:7363 ~0.04950023117398534 243:0.45:7364:7367 184:0.703125:7365:7366 ~-0.0411521528863483 ~0.04037663389171747 251:0.328125:7368:7369 ~-0.03711187961150358 "
    s .= "~0.03177563629877915 10:0.046875:7371:7372 ~-0.007156232360511772 ~-0.08735731753045375 59:-0.625:7374:7377 257:0.5555555555555556:7375:7376 ~0.017304757721986846 ~-0.04403597022512728 255:0.234375:7378:7379 "
    s .= "~0.005888856236568949 ~-0.035798022400002565 251:0.828125:7381:7410 241:0.48:7382:7395 61:1.28125:7383:7394 55:-0.046875:7384:7391 249:1.8333333333333335:7385:7390 195:-0.34375:7386:7387 ~-0.02946056427687478 "
    s .= "16:0.09375:7388:7389 ~0.01089146236418756 ~0.0474306987696485 ~-0.043899624117281155 145:1.90625:7392:7393 ~-0.009624626338693279 ~0.0915877596494093 ~0.0377187395873389 245:1.7301587301587302:7396:7401 "
    s .= "196:-0.609375:7397:7400 220:-0.09375:7398:7399 ~0.0059570714201074414 ~0.4231721193504817 ~-0.04376041002111883 94:0.015625:7402:7405 162:0.03125:7403:7404 ~-0.05076179792184285 ~0.006016306547342207 "
    s .= "196:-0.125:7406:7407 ~-0.045773638565321774 85:0.546875:7408:7409 ~-0.014725596455525123 ~0.038948056058123626 252:0.32499999999999996:7411:7424 184:0.125:7412:7419 31:0.328125:7413:7416 205:0.46875:7414:7415 "
    s .= "~-0.029322520489412307 ~0.038134470689314484 91:0.109375:7417:7418 ~-0.022762010069463157 ~0.05338103515402313 82:0.109375:7420:7421 ~0.032593554088380765 238:0.25:7422:7423 ~0.013350163423124348 ~-0.023711324027108675 "
    s .= "19:0.484375:7425:7426 ~0.020766580879557548 ~-0.037423271116597503 72:1.078125:7428:7473 257:0.9090909090909091:7429:7470 194:0.640625:7430:7469 8:0.828125:7431:7466 247:0.796875:7432:7465 89:0.78125:7433:7464 "
    s .= "2:-0.125:7434:7457 238:0.59375:7435:7452 184:0.03125:7436:7441 241:0.42:7437:7440 106:0.8125:7438:7439 ~-0.030933413564769665 ~0.008915257285523438 ~0.01955129274139754 73:0.0625:7442:7445 252:4.975:7443:7444 "
    s .= "~0.0211919448463619 ~0.1038750818758417 122:-0.8125:7446:7447 ~0.025541131593958002 113:-0.203125:7448:7449 ~-0.029697936307905754 122:0.046875:7450:7451 ~0.03077721541464945 ~-0.024782152421705745 243:0.55:7453:7456 "
    s .= "92:-0.296875:7454:7455 ~-0.02286094757120606 ~0.06550555388822925 ~-0.05101334322112432 249:0.16666666666666666:7458:7461 168:-0.015625:7459:7460 ~0.02224776350701907 ~-0.006025830430203749 132:0.3515625:7462:7463 "
    s .= "~-0.020439390446597188 ~0.03324813620873139 ~0.0280997779195859 ~-0.044824612219731746 107:0.75:7467:7468 ~0.06748597925954046 ~-0.03450039253831113 ~-0.02787583599899045 240:-0.171875:7471:7472 ~0.00031116575139520855 "
    s .= "~-0.04790585234496788 ~-0.062017165659013884 33:0.921875:7475:7520 124:-0.65625:7476:7477 ~-0.04130920776052466 124:0.203125:7478:7511 91:0.28125:7479:7504 244:1.385:7480:7487 133:0.90625:7481:7486 "
    s .= "139:0.640625:7482:7485 112:0.65625:7483:7484 ~-0.014168944525609718 ~0.021837087908105495 ~0.03219393527185432 ~-0.02350752315719493 181:0.109375:7488:7495 82:0.796875:7489:7494 184:0.203125:7490:7493 "
    s .= "31:0.4375:7491:7492 ~-0.056505062350452544 ~0.06898706274790617 ~0.023428694897865088 ~0.026323832560312156 181:1.46875:7496:7499 109:0.4375:7497:7498 ~-0.004821521349098565 ~0.042504512220982824 232:0.078125:7500:7503 "
    s .= "245:1.4230769230769231:7501:7502 ~-0.2868048706800587 ~-0.03715331447080355 ~0.027141846930822014 100:-0.015625:7505:7508 33:0.1875:7506:7507 ~-0.017484792203354284 ~0.027236001998325418 10:0.59375:7509:7510 "
    s .= "~0.0320572115610991 ~-0.0418169435659286 183:-0.515625:7512:7513 ~-0.04090557270252421 122:-0.78125:7514:7517 250:0.9609375:7515:7516 ~-0.029127748838754054 ~0.03773415561220048 144:0.046875:7518:7519 "
    s .= "~-0.02001990765695024 ~0.0035188195596880753 ~-0.04210736411153467 254:1.359375:7522:7565 29:-0.734375:7523:7528 212:-0.359375:7524:7527 134:-0.84375:7525:7526 ~0.007749950753512504 ~0.041731319704357284 "
    s .= "~-0.013201657656626287 246:0.171875:7529:7548 209:0.140625:7530:7545 193:0.21875:7531:7542 148:1.0625:7532:7541 247:-0.015625:7533:7538 247:-0.921875:7534:7537 128:-0.484375:7535:7536 ~0.002887561177350672 "
    s .= "~-0.056017168363783634 ~0.01547657066974973 248:0.125:7539:7540 ~-0.04170666403349401 ~0.006070975596576721 ~-0.043452541207800316 244:1.015:7543:7544 ~-0.0537605813955389 ~-0.009219701522716114 195:0.03125:7546:7547 "
    s .= "~0.002899059383115212 ~-0.05345043913763678 128:0.125:7549:7550 ~0.020547830240905045 250:1.1171875:7551:7556 122:0.25:7552:7555 97:-0.1875:7553:7554 ~-0.06297397950725464 ~0.009058813239953027 ~-0.0349558798907246 "
    s .= "132:0.2890625:7557:7564 79:0.484375:7558:7563 254:0.953125:7559:7560 ~-0.020452253009314046 191:0.375:7561:7562 ~0.04972949605768044 ~-0.02939948799474153 ~0.02841532806533388 ~0.03389300616338899 50:-0.6875:7566:7567 "
    s .= "~0.000579727945501473 ~-0.04071550388258412 219:0.984375:7569:7614 251:0.828125:7570:7595 243:1.15:7571:7590 249:1.8333333333333335:7572:7589 55:-0.046875:7573:7584 242:1.25:7574:7583 16:0.09375:7575:7580 "
    s .= "193:0.109375:7576:7579 245:1.891566265060241:7577:7578 ~0.03292863676007921 ~-0.0034491978500710216 ~-0.024355434995694213 196:-0.078125:7581:7582 ~-0.03259069811208918 ~0.06293357324135226 ~-0.061789809291930814 "
    s .= "145:1.90625:7585:7588 88:0.828125:7586:7587 ~-0.01111375037268724 ~0.01007949828426163 ~0.08120806733487224 ~-0.04407105397643907 66:-0.015625:7591:7594 110:-0.0625:7592:7593 ~-0.020677340260883748 ~0.04640886103766246 "
    s .= "~-0.045154138173956554 252:0.32499999999999996:7596:7609 244:0.965:7597:7602 64:0.3125:7598:7601 48:0.3671875:7599:7600 ~0.06673867163102774 ~-0.0261131884022556 ~-0.0341863538004745 46:0.421875:7603:7608 "
    s .= "136:1.109375:7604:7607 220:0.796875:7605:7606 ~-0.02296566935971915 ~0.04133925575889616 ~0.0072297835228426815 ~0.031108216709988642 19:0.484375:7610:7613 28:0.59375:7611:7612 ~0.02297835986500064 ~-0.0512072679879389 "
    s .= "~-0.03555961410975032 ~-0.05168429510108041 191:0.78125:7616:7661 246:1.765625:7617:7660 247:0.765625:7618:7657 124:-0.65625:7619:7620 ~-0.047824656032542684 91:1.171875:7621:7654 110:-1.265625:7622:7629 "
    s .= "189:-0.203125:7623:7626 244:1.52:7624:7625 ~-0.026266764286838926 ~0.02644028520561606 162:-0.046875:7627:7628 ~-0.09954352435198614 ~-0.003503032271383932 245:3.5454545454545454:7630:7653 244:1.635:7631:7646 "
    s .= "190:-0.140625:7632:7635 133:0.125:7633:7634 ~0.01089031548280825 ~-0.029937287044090957 211:0.234375:7636:7639 133:1.65625:7637:7638 ~0.009763096791254146 ~-0.030050333914208128 243:0.25:7640:7641 ~0.035555749709519816 "
    s .= "244:1.095:7642:7645 124:-0.625:7643:7644 ~0.22768399783042598 ~-0.03933963419475471 ~0.003498902863816815 157:0.25:7647:7652 58:0.234375:7648:7651 154:0.375:7649:7650 ~-0.05145632854816471 ~0.024450051880657093 "
    s .= "~0.03703612016949984 ~0.023390732125989938 ~-0.04887743847985574 7:0.65625:7655:7656 ~0.021773242513966215 ~-0.046334836862617176 127:-0.34375:7658:7659 ~0.09017278099515652 ~-0.05796051404572723 ~0.03489600452053107 "
    s .= "~-0.03576866340259171 244:2.905:7663:7704 244:1.635:7664:7697 183:-0.53125:7665:7668 148:0.15625:7666:7667 ~-0.004542588932450702 ~-0.057759513780091955 190:-0.140625:7669:7672 102:0.3515625:7670:7671 "
    s .= "~-0.02452374333576739 ~0.009974023814239945 167:0.53125:7673:7696 130:0.15625:7674:7677 67:-0.125:7675:7676 ~-0.019365686772451096 ~0.024784999777520876 220:0.84375:7678:7695 58:-0.34375:7679:7680 ~0.030255332369614016 "
    s .= "64:0.40625:7681:7692 139:0.671875:7682:7689 141:0.1171875:7683:7686 33:0.375:7684:7685 ~-0.019786213894540813 ~-0.05937690077975989 253:-0.055855855855857804:7687:7688 ~0.0277584886614153 ~-0.013735841575900987 "
    s .= "109:1.078125:7690:7691 ~0.028956756405006057 ~-0.029010868600591672 245:1.5544554455445545:7693:7694 ~-0.035989060816392554 ~0.024660668709462052 ~0.04089349589221682 ~-0.02244557151070682 157:0.171875:7698:7703 "
    s .= "154:0.21875:7699:7702 58:0.234375:7700:7701 ~-0.04913456015591094 ~0.02200175240853812 ~0.027180930319389958 ~0.02397175847475088 189:-0.15625:7705:7706 ~0.008285993266529781 143:-0.234375:7707:7708 "
    s .= "~-0.13299353859333168 ~-0.03407488283821557 254:0.984375:7710:7751 244:2.905:7711:7742 251:0.203125:7712:7713 ~-0.013315169919676887 244:1.635:7714:7735 154:1.984375:7715:7734 64:0.625:7716:7731 232:-0.3125:7717:7722 "
    s .= "85:-0.1875:7718:7721 13:-0.109375:7719:7720 ~-0.05201654805235478 ~0.0680008797411155 ~-0.038332266747647836 121:-0.015625:7723:7726 130:0.125:7724:7725 ~0.011738713168693739 ~-0.016325966986826448 77:0.046875:7727:7730 "
    s .= "186:-0.546875:7728:7729 ~-0.03719357216320405 ~0.018823155242952583 ~-0.004918600772751438 211:0.5625:7732:7733 ~0.02967913069694413 ~-0.043910793368348765 ~-0.0484764095628988 82:0.25:7736:7741 181:0.34375:7737:7740 "
    s .= "199:0.015625:7738:7739 ~-0.07379531610154613 ~-0.00004111006416595607 ~0.03665800826477389 ~0.030735523262528642 245:1.7017543859649122:7743:7748 82:1.8125:7744:7745 ~0.028696921900358708 217:0.015625:7746:7747 "
    s .= "~-0.27345314451579483 ~0.031849377669831695 210:-0.15625:7749:7750 ~0.002602988494525331 ~-0.08826191678599049 26:-0.140625:7752:7753 ~-0.0031152894143714168 255:0.234375:7754:7755 ~-0.009757275216250921 "
    s .= "~-0.06143893319644174 72:1.078125:7757:7802 11:0.921875:7758:7801 77:0.640625:7759:7800 246:1.671875:7760:7799 247:0.796875:7761:7798 124:-0.65625:7762:7763 ~-0.047791285920318984 148:0.203125:7764:7781 "
    s .= "133:1.625:7765:7776 252:4.975:7766:7771 243:1.45:7767:7768 ~0.008916286804487463 250:0.8359375:7769:7770 ~0.040583526753314364 ~-0.03434124982238334 248:0.375:7772:7773 ~0.009088331869318685 251:0.546875:7774:7775 "
    s .= "~0.3143071431541057 ~0.0686565617914238 199:0.03125:7777:7778 ~-0.033254159643776905 79:-0.109375:7779:7780 ~0.04727831096189042 ~-0.003508365579141322 108:0.3203125:7782:7795 70:0.421875:7783:7794 244:0.955:7784:7785 "
    s .= "~-0.029123380448206893 220:-0.015625:7786:7787 ~-0.022406333305632374 124:0.203125:7788:7789 ~0.026481488273194395 192:0.171875:7790:7793 34:-0.171875:7791:7792 ~0.030565186258492832 ~-0.024244797904201226 "
    s .= "~0.029939737634264874 ~-0.03732858640717683 250:1.1015625:7796:7797 ~-0.03526328867648739 ~0.05114518049016417 ~-0.0641069072839759 ~0.034803533173830704 ~-0.0251779659465212 ~0.037595302429494735 ~-0.06145906903468036 "
    s .= "29:-0.71875:7804:7809 212:-0.3125:7805:7808 246:-2.015625:7806:7807 ~-0.000031405308712869736 ~0.0309027456698292 ~-0.012789820517278214 255:0.234375:7810:7839 255:0.109375:7811:7830 134:0.984375:7812:7829 "
    s .= "131:0.640625:7813:7824 236:0.375:7814:7823 28:-0.078125:7815:7818 133:0.921875:7816:7817 ~-0.009800027804477602 ~0.019950366925109576 106:1.984375:7819:7822 25:-0.703125:7820:7821 ~0.1399942729716663 "
    s .= "~-0.012272220748482002 ~-0.07112554004393612 ~0.021611580879804252 133:-0.359375:7825:7826 ~0.056487590473976196 110:0.984375:7827:7828 ~-0.04354263392844776 ~0.029767786515877217 ~0.031399426599916846 "
    s .= "245:1.9152542372881356:7831:7832 ~0.028673137146870878 122:-0.03125:7833:7836 217:-0.046875:7834:7835 ~-0.013424091966021318 ~0.040176675226361355 242:0.75:7837:7838 ~-0.046774464457504245 ~0.02084387097642298 "
    s .= "250:1.1640625:7840:7847 247:0.203125:7841:7846 244:1.035:7842:7843 ~-0.0477336646173335 257:0.30985915492957744:7844:7845 ~0.003513274483336397 ~-0.047350775605241466 ~-0.05355834751243164 132:0.1328125:7848:7849 "
    s .= "~-0.008362457097396928 ~0.031162535896661743 33:0.921875:7851:7896 8:0.875:7852:7893 247:0.796875:7853:7890 89:0.9375:7854:7889 224:0.578125:7855:7888 192:0.921875:7856:7887 102:0.3515625:7857:7880 93:0.3125:7858:7879 "
    s .= "148:0.203125:7859:7872 130:2.25:7860:7871 186:0.484375:7861:7870 106:0.046875:7862:7865 245:1.8225806451612903:7863:7864 ~0.01975214309730004 ~-0.02302304130727606 2:-0.171875:7866:7867 ~0.0194576382861355 "
    s .= "255:0.265625:7868:7869 ~0.009647551500813251 ~-0.024766387763278448 ~-0.041308084990477174 ~-0.04564875671806163 166:-0.140625:7873:7874 ~-0.0420740457432108 70:0.421875:7875:7878 226:0.875:7876:7877 "
    s .= "~-0.0034521349559353816 ~0.05005262149656414 ~-0.03468214546514732 ~-0.02265583342123629 141:0.1640625:7881:7886 64:0.484375:7882:7885 37:-0.375:7883:7884 ~0.08066950100688514 ~-0.028115821760950815 ~0.03898236425239797 "
    s .= "~0.023964312498286955 ~-0.05710299002068393 ~-0.027255559855492936 ~0.03466950744300192 189:0.75:7891:7892 ~-0.05864146987247964 ~0.0403842305542509 107:0.75:7894:7895 ~0.06265903874634701 ~-0.04450281314870925 "
    s .= "~-0.04071210363710762 251:0.515625:7898:7915 241:0.3:7899:7912 186:-0.03125:7900:7905 251:0.109375:7901:7902 ~-0.03034536787855561 250:0.6796875:7903:7904 ~-0.0631329190720399 ~0.02531458341859131 110:0.03125:7906:7909 "
    s .= "111:0.6328125:7907:7908 ~-0.029499035635717003 ~0.05094240454289756 125:0.421875:7910:7911 ~0.012062388279979578 ~-0.042506723058734694 253:-0.06666666666666857:7913:7914 ~0.006721585266123255 ~-0.030094369091567583 "
    s .= "238:0.59375:7916:7943 79:0.765625:7917:7940 91:1.09375:7918:7939 86:0.9375:7919:7938 242:1.65:7920:7935 250:1.3515625:7921:7932 136:-0.234375:7922:7923 ~0.03800205939682169 202:0.25:7924:7931 "
    s .= "245:1.925233644859813:7925:7926 ~0.020248988022250714 64:0.15625:7927:7930 190:0.25:7928:7929 ~-0.03280787168515078 ~0.0314101490006658 ~0.02010644063606424 ~-0.016463226353112752 151:0.5:7933:7934 ~-0.03097975553323354 "
    s .= "~0.027093885259673618 251:2.359375:7936:7937 ~-0.039778447971745345 ~0.03327956919147925 ~0.03499151116095307 ~0.025544873642959327 217:0.578125:7941:7942 ~0.023684388254941402 ~-0.05020611433661577 "
    s .= "~-0.01935912832622627 257:0.75:7945:7988 238:0.53125:7946:7979 47:-0.421875:7947:7948 ~0.013701956358043358 255:0.265625:7949:7974 255:0.140625:7950:7965 245:1.3488372093023255:7951:7956 247:0.578125:7952:7953 "
    s .= "~-0.04873504686952448 109:-0.09375:7954:7955 ~0.05843220705447232 ~-0.015223887992233648 236:0.375:7957:7964 243:2.95:7958:7961 256:0.009523809523809525:7959:7960 ~-0.012564063005565422 ~0.012257898115787376 "
    s .= "136:0.546875:7962:7963 ~0.01062649424409576 ~0.23732661094789426 ~0.018789594835573912 219:0.140625:7966:7973 236:0.25:7967:7972 110:0.0625:7968:7971 146:-0.03125:7969:7970 ~0.015627964513990716 ~-0.05409383626645049 "
    s .= "~0.04043161839218375 ~-0.029750833287765163 ~0.03331200594961067 244:1.66:7975:7978 250:1.1171875:7976:7977 ~-0.043225850419361736 ~-0.005893910239187395 ~0.009666386437559496 243:0.75:7980:7987 49:0.140625:7981:7986 "
    s .= "134:-0.140625:7982:7985 223:0.25:7983:7984 ~0.01411005469950382 ~-0.05733265402530783 ~0.041773622777595165 ~-0.032667849813977475 ~-0.04271603935168284 240:-0.171875:7989:7990 ~0.00673855192858314 ~-0.04535129973775045 "
    s .= "254:0.984375:7992:8035 109:1.859375:7993:8024 109:1.1875:7994:8017 254:0.953125:7995:8016 202:0.25:7996:8007 190:-0.125:7997:8002 52:1.328125:7998:8001 235:0.640625:7999:8000 ~-0.026970139515484416 ~0.03236800742766518 "
    s .= "~0.0992806151046439 58:-0.515625:8003:8004 ~0.06285456501633659 221:0.125:8005:8006 ~0.010694434957721976 ~-0.010245380139578049 111:0.3359375:8008:8015 26:-0.921875:8009:8012 43:0.234375:8010:8011 ~0.043968601726143766 "
    s .= "~-0.04882205964078727 250:0.5546875:8013:8014 ~0.11588429840114661 ~-0.02683966391125206 ~0.023222270847124832 ~0.02724701122332634 160:1.609375:8018:8023 121:0.71875:8019:8020 ~0.0202371779474087 213:0.265625:8021:8022 "
    s .= "~-0.049215015614682625 ~0.046458796266450705 ~-0.02155921650658637 254:0.046875:8025:8026 ~-0.06647798245078802 155:-0.546875:8027:8028 ~0.04037642626940489 218:0.40625:8029:8034 245:1.4074074074074074:8030:8033 "
    s .= "241:0.3:8031:8032 ~-0.003986925212504982 ~-0.2823578392888885 ~-0.02549755186575525 ~0.02619933055367305 26:-0.140625:8036:8037 ~-0.0031625372681325773 ~-0.032913300588855963 72:1.078125:8039:8084 251:0.421875:8040:8065 "
    s .= "110:0.5625:8041:8064 245:1.4880952380952381:8042:8047 4:0.765625:8043:8046 242:0.45:8044:8045 ~0.04048783097288282 ~-0.020696222172840343 ~0.13086829260013577 217:-0.09375:8048:8049 ~-0.03738111706852692 "
    s .= "1:-0.171875:8050:8053 22:-0.265625:8051:8052 ~-0.025413765107349356 ~0.03701485178985916 82:1.09375:8054:8063 139:-0.140625:8055:8056 ~-0.058117631620407874 250:1.4765625:8057:8062 175:0.640625:8058:8061 "
    s .= "238:-0.171875:8059:8060 ~0.04424902670245996 ~-0.008466872664426623 ~0.03731485769479441 ~-0.06453360251926663 ~-0.03851430828575154 ~-0.04673267847180618 121:-0.015625:8066:8073 58:1.140625:8067:8072 249:0.5:8068:8069 "
    s .= "~-0.0010352891263311226 123:0.25:8070:8071 ~-0.037110912190909055 ~0.005056918547874355 ~0.029373711787045145 244:2.81:8074:8083 202:0.1875:8075:8080 247:0.859375:8076:8079 49:-0.09375:8077:8078 ~-0.005311095867686771 "
    s .= "~0.02191197010735302 ~-0.06677615253539051 229:-0.203125:8081:8082 ~-0.05219129093471825 ~0.002563084007816456 ~-0.0378477127207349 ~-0.06055830702225798 219:0.984375:8086:8131 251:1.140625:8087:8112 242:2.05:8088:8111 "
    s .= "64:-0.640625:8089:8090 ~-0.04873443537134653 85:-0.46875:8091:8092 ~0.04154519710041121 107:0.796875:8093:8110 255:0.234375:8094:8101 106:1.828125:8095:8096 ~0.005761958375379363 1:-0.078125:8097:8098 "
    s .= "~0.01810262316035176 77:0.421875:8099:8100 ~-0.08612053784839103 ~0.043013950547281535 95:0.078125:8102:8109 254:0.546875:8103:8106 101:-0.65625:8104:8105 ~0.06052753025892215 ~-0.008446180252204144 "
    s .= "109:1.296875:8107:8108 ~-0.01981933579835468 ~0.011552346274059275 ~-0.04512063298392857 ~-0.04789441795929706 ~-0.04648909048362367 241:0.52:8113:8130 136:1.125:8114:8125 74:0.140625:8115:8124 96:-0.2734375:8116:8117 "
    s .= "~-0.06542056937215769 109:1.78125:8118:8123 76:0.0625:8119:8120 ~0.03087738629214894 76:0.34375:8121:8122 ~-0.04483798855936236 ~0.03377457111763384 ~-0.054933908611529615 ~-0.05124774793590017 214:0.03125:8126:8129 "
    s .= "85:0.5625:8127:8128 ~-0.055626063222429634 ~0.030511451484709934 ~0.03870316031929989 ~0.021439265383535827 ~-0.05056608626380228 257:0.75:8133:8176 238:0.53125:8134:8163 47:-0.421875:8135:8136 ~0.012891071617187064 "
    s .= "255:0.265625:8137:8158 255:0.140625:8138:8147 134:1.03125:8139:8146 93:-0.015625:8140:8145 173:-0.578125:8141:8142 ~-0.043813450710760315 106:1.71875:8143:8144 ~0.025164084989835078 ~-0.03505283599881455 "
    s .= "~-0.010811325980437485 ~0.03878419676234185 219:0.140625:8148:8157 252:0.32499999999999996:8149:8156 8:0.5:8150:8155 228:-0.046875:8151:8152 ~0.019577668591736215 235:0.0625:8153:8154 ~-0.048250672790869864 "
    s .= "~0.007423618486483765 ~0.06267283695782079 ~0.028545522548119574 ~0.031714947414892836 244:1.66:8159:8162 250:1.1171875:8160:8161 ~-0.04131894126082971 ~-0.005192036780190386 ~0.009492375409102177 "
    s .= "242:0.8500000000000001:8164:8175 95:-0.875:8165:8166 ~-0.04396547448632441 112:0.40625:8167:8168 ~-0.03133543816388202 52:0.25:8169:8174 112:0.578125:8170:8173 109:0.328125:8171:8172 ~0.2601501123959426 "
    s .= "~0.03704523773936339 ~0.02424691770027965 ~-0.01931345435489208 ~-0.043634559871867665 240:-0.171875:8177:8178 ~0.006042220287061805 ~-0.04378066631353208 72:0.984375:8180:8225 11:0.921875:8181:8224 "
    s .= "247:0.984375:8182:8223 246:1.734375:8183:8222 122:0.09375:8184:8219 190:-0.015625:8185:8198 61:0.8125:8186:8193 103:0.6875:8187:8190 43:0.515625:8188:8189 ~-0.022595215209778273 ~0.032277743985835126 "
    s .= "115:0.734375:8191:8192 ~0.025309324001559885 ~-0.029158789904768306 40:0.5625:8194:8197 28:-0.28125:8195:8196 ~-0.029699109787341055 ~0.04271805171459331 ~-0.044262840016162625 25:0.125:8199:8210 166:0.515625:8200:8207 "
    s .= "151:-0.109375:8201:8204 106:-0.03125:8202:8203 ~-0.014308045284464747 ~0.05161443588789542 109:0.078125:8205:8206 ~-0.019176136047319423 ~0.014923608395909319 37:-0.0625:8208:8209 ~-0.0397949157726266 "
    s .= "~0.008947921433925136 133:0.828125:8211:8214 139:0.796875:8212:8213 ~-0.03158841443006634 ~0.0279264631510731 79:0.796875:8215:8218 198:-0.265625:8216:8217 ~-0.032740878306511685 ~0.0305825370015966 "
    s .= "~-0.04396184990127782 219:-0.21875:8220:8221 ~-0.06903802935248213 ~-0.007098120254086189 ~0.03418360954605535 ~-0.0687379020457187 ~0.036986091690714394 ~-0.05158185740682578 254:1.359375:8227:8270 "
    s .= "29:-0.734375:8228:8231 212:-0.359375:8229:8230 ~0.019865641601253075 ~-0.011866904416077144 120:-0.40625:8232:8235 1:0:8233:8234 ~-0.00789593148035611 ~-0.0627576974597849 245:2.1616161616161618:8236:8257 "
    s .= "243:1.35:8237:8252 39:0.453125:8238:8245 145:-0.40625:8239:8240 ~-0.04114686181779881 257:0.4375:8241:8242 ~0.015119836711870074 247:-0.390625:8243:8244 ~0.00936615963048675 ~-0.04187916791823057 252:0.225:8246:8251 "
    s .= "123:0.4375:8247:8248 ~-0.04798166015895592 107:0.5625:8249:8250 ~0.02114259378805395 ~-0.059575557089267 ~0.017522451649660313 251:1.796875:8253:8256 255:-0.046875:8254:8255 ~0.17889737509522927 ~-0.03666197191529546 "
    s .= "~0.020908838166347265 252:1.775:8258:8269 127:0.984375:8259:8268 91:0.171875:8260:8267 250:0.7265625:8261:8262 ~0.015770473477523635 226:0.234375:8263:8266 84:0.2265625:8264:8265 ~-0.049774926769641785 "
    s .= "~0.004433289521893399 ~0.015427398622926783 ~0.009259316049145889 ~-0.04534141302015651 ~0.035618032462365105 50:-0.6875:8271:8272 ~0.00048334395854645105 ~-0.03764349931401367 110:-1.125:8274:8281 "
    s .= "189:-0.203125:8275:8278 244:1.52:8276:8277 ~-0.021386229395307068 ~0.02581054740889991 257:0.15384615384615385:8279:8280 ~0.013058964788717403 ~-0.06619200600819138 98:-1.046875:8282:8285 143:-0.546875:8283:8284 "
    s .= "~0.044354212656579545 ~-0.03841403567013444 255:0.265625:8286:8311 255:0.109375:8287:8304 245:1.3488372093023255:8288:8293 247:0.578125:8289:8292 243:0.25:8290:8291 ~0.034039638308219836 ~-0.05197421669084706 "
    s .= "~0.018283364798714744 250:1.1953125:8294:8299 191:-0.1875:8295:8296 ~0.011465734909823343 68:-0.359375:8297:8298 ~-0.06975542687107573 ~-0.017285823090206962 246:0.390625:8300:8303 61:0.28125:8301:8302 "
    s .= "~-0.012821480264597097 ~0.02093628902773667 ~0.024993527984066996 219:0.140625:8305:8310 249:0.16666666666666666:8306:8307 ~0.017351138168374258 244:1:8308:8309 ~0.007965377461366606 ~-0.03535026697372608 "
    s .= "~0.027976251406740926 98:-0.421875:8312:8317 246:-0.390625:8313:8314 ~-0.009580466486649957 95:-0.0625:8315:8316 ~0.03992673275129234 ~-0.03565939090337484 254:0.828125:8318:8319 ~-0.00742598689308258 "
    s .= "~-0.03876388121482036 219:0.984375:8321:8366 251:0.234375:8322:8329 243:0.45:8323:8328 205:0.625:8324:8325 ~-0.009092706173587477 25:0.09375:8326:8327 ~0.06494167302859684 ~-0.036124483443357495 ~-0.03175449306363439 "
    s .= "255:0.265625:8330:8357 255:0.140625:8331:8350 109:2.046875:8332:8349 109:1.1875:8333:8348 110:0.984375:8334:8347 252:0.025:8335:8340 248:0.125:8336:8337 ~-0.03471179990765641 43:0.09375:8338:8339 ~-0.003931375728102813 "
    s .= "~0.03587202368997794 244:1.05:8341:8346 109:-0.234375:8342:8343 ~0.02986631609013184 254:0.578125:8344:8345 ~-0.04377359106932079 ~0.06792707989803064 ~-0.004609588690962355 ~0.03357784029931983 ~0.013866770130601214 "
    s .= "~-0.034339786538655374 252:0.175:8351:8356 245:1.891566265060241:8352:8353 ~0.025520523537064556 53:0.015625:8354:8355 ~0.004470827865637533 ~-0.05667785810850309 ~0.03734886854014825 74:-0.5625:8358:8361 "
    s .= "254:0.484375:8359:8360 ~0.04370026428899643 ~0.0026437190432249125 250:1.1953125:8362:8365 244:1.085:8363:8364 ~-0.05305006213458166 ~-0.015508513008716297 ~0.001372923179840799 ~-0.05004788618397781 "
    s .= "191:0.78125:8368:8413 246:-2.015625:8369:8376 233:-0.609375:8370:8375 245:1.7681159420289856:8371:8374 244:1.52:8372:8373 ~-0.051408598443712795 ~0.03874082371919544 ~0.009492361316490278 ~-0.040885738081534166 "
    s .= "56:-0.8125:8377:8378 ~0.01938289267486508 255:0.234375:8379:8404 255:0.140625:8380:8397 104:-0.125:8381:8384 198:-0.234375:8382:8383 ~-0.021004561754183956 ~0.016478388258334413 246:1.734375:8385:8396 "
    s .= "11:0.796875:8386:8395 245:1.353658536585366:8387:8388 ~-0.04202214891756881 256:0:8389:8392 12:0.515625:8390:8391 ~-0.00931987098587985 ~-0.04954837051709917 128:0.4375:8393:8394 ~0.032314625525610784 "
    s .= "~-0.0124853010691112 ~0.038512621058413764 ~0.03274248363327161 245:1.9152542372881356:8398:8399 ~0.027407269745630115 122:-0.046875:8400:8401 ~0.025384682504725045 242:0.75:8402:8403 ~-0.04816496540775106 "
    s .= "~0.021134628188006793 250:1.1640625:8405:8412 247:0.203125:8406:8411 244:1.035:8407:8410 226:0.875:8408:8409 ~-0.050811158929316126 ~0.08871051285922106 ~0.0013906257386763449 ~-0.0517430923691425 ~0.004942659092815957 "
    s .= "~-0.033387462356162405 15:-1.0078125:8415:8416 ~0.05289441218115648 245:4:8417:8460 205:-0.5:8418:8419 ~-0.03564847918833629 85:-0.46875:8420:8421 ~0.03287886885404072 242:2.25:8422:8459 252:1.775:8423:8456 "
    s .= "243:1.45:8424:8455 257:0.30985915492957744:8425:8448 252:0.32499999999999996:8426:8441 184:0.0625:8427:8438 79:0.375:8428:8437 205:0.109375:8429:8432 244:1.2:8430:8431 ~-0.008746028321802254 ~-0.04121500547842565 "
    s .= "202:0.0625:8433:8434 ~0.04358291147500372 154:0.59375:8435:8436 ~-0.051062769879179876 ~0.03485475940790036 ~0.01799249411196768 104:0.5625:8439:8440 ~0.010410949983429922 ~-0.03321448152470987 157:0.171875:8442:8443 "
    s .= "~0.04475858859362303 177:0.25:8444:8445 ~0.015203137860038199 251:1.078125:8446:8447 ~-0.058806065981561476 ~0.020536072609559232 252:0.32499999999999996:8449:8452 4:0.03125:8450:8451 ~0.010363880162431893 "
    s .= "~-0.022801548528941517 244:2.81:8453:8454 ~-0.03207273578832634 ~-0.19328543476942792 ~-0.035507438344576425 251:0.296875:8457:8458 ~-0.045347497858025936 ~0.028659230831329797 ~-0.031407822572469345 "
    s .= "~-0.06138644056211241 176:0.703125:8462:8507 8:0.828125:8463:8504 2:0.640625:8464:8503 256:0.01818181818181818:8465:8494 39:0.4375:8466:8491 34:0.03125:8467:8474 109:0.078125:8468:8471 181:0.359375:8469:8470 "
    s .= "~-0.038989762303718666 ~0.007683098718527803 29:-0.8125:8472:8473 ~0.03343256198929148 ~0.007279296348066099 166:-0.078125:8475:8478 244:1.94:8476:8477 ~-0.03773595132372825 ~0.02681550789673356 61:-0.21875:8479:8480 "
    s .= "~0.050067976310181284 32:0.375:8481:8490 244:2.81:8482:8489 2:-0.125:8483:8488 136:-0.015625:8484:8485 ~-0.047252550911384084 251:0.203125:8486:8487 ~-0.03585708135743603 ~0.011641810439429892 ~-0.02173947894273487 "
    s .= "~-0.06477119244077573 ~0.032638102829260544 171:0.28125:8492:8493 ~-0.04441182879967578 ~-0.00021318570865836727 54:-0.1171875:8495:8496 ~-0.042376384286734015 107:0.40625:8497:8498 ~0.03458940944694073 "
    s .= "252:0.125:8499:8502 229:-0.09375:8500:8501 ~0.029706998376890333 ~-0.04847383516901167 ~0.017243323129679564 ~-0.03634611408740633 89:0.828125:8505:8506 ~0.05985924679726251 ~-0.03389522515425238 ~-0.023728543857121073 "
    s .= "110:-1.015625:8509:8518 167:-0.40625:8510:8517 244:1.52:8511:8514 2:-0.421875:8512:8513 ~-0.004831004746726781 ~-0.05509897022239762 186:-0.234375:8515:8516 ~0.03146799746766756 ~-0.03733730297827055 "
    s .= "~-0.043306410891280185 98:-1.046875:8519:8522 143:-0.5625:8520:8521 ~0.04677337701073431 ~-0.03259437177113371 130:2.109375:8523:8550 77:0.640625:8524:8549 250:1.1328125:8525:8534 159:0.3359375:8526:8533 "
    s .= "217:-0.140625:8527:8530 251:1.421875:8528:8529 ~-0.03907953826152008 ~0.02067974869705974 31:0.046875:8531:8532 ~0.01244876573723091 ~-0.007970208347245532 ~-0.04064829713696911 111:0.2578125:8535:8548 "
    s .= "106:1.046875:8536:8547 4:0.765625:8537:8542 64:1.125:8538:8541 23:0.921875:8539:8540 ~-0.015080519962914882 ~0.07984702174899037 ~0.04683433495891712 245:1.4745762711864407:8543:8546 221:0.109375:8544:8545 "
    s .= "~0.1802903893814176 ~-0.04063111167077982 ~0.018256270509567997 ~0.01994423594904647 ~0.02634952490554044 ~-0.019807882679379902 229:0.265625:8551:8554 175:1.921875:8552:8553 ~-0.057937474373108935 ~0.02751534093485941 "
    s .= "~0.01660447003379463 33:0.921875:8556:8601 124:-0.65625:8557:8558 ~-0.038483239702527504 85:-0.46875:8559:8560 ~0.029973174870936394 85:1.28125:8561:8594 246:-0.265625:8562:8573 247:-0.015625:8563:8572 "
    s .= "209:-0.109375:8564:8571 47:-0.6875:8565:8566 ~0.011307104382864315 34:0.015625:8567:8570 244:1.02:8568:8569 ~-0.03646878441042525 ~0.014397864872203212 ~-0.025848872063986922 ~-0.036977454082834454 ~-0.04908293183310561 "
    s .= "254:0.765625:8574:8585 136:1.125:8575:8584 106:-0.265625:8576:8577 ~0.03623590711458523 159:0.1484375:8578:8579 ~0.0016388717186285762 251:1.484375:8580:8583 81:0.7109375:8581:8582 ~-0.04351946064981838 "
    s .= "~0.03165534852123807 ~0.01274213924909064 ~0.016794624917827617 191:0.234375:8586:8589 72:0.03125:8587:8588 ~-0.00584926852902881 ~0.03282557547344377 242:0.45:8590:8591 ~-0.051077142755715836 233:0.390625:8592:8593 "
    s .= "~0.026045230186810132 ~-0.05715757965748274 181:1.515625:8595:8598 205:-0.28125:8596:8597 ~-0.02782800584280117 ~0.019855173374264536 199:0.03125:8599:8600 ~-0.06065986752772548 ~0.0034615482987457057 "
    s .= "~-0.038579163503349514 72:0.984375:8603:8648 11:0.921875:8604:8645 247:0.984375:8605:8644 246:1.796875:8606:8643 124:-0.65625:8607:8608 ~-0.04637478174512767 122:-0.046875:8609:8624 110:-0.25:8610:8619 "
    s .= "128:-0.484375:8611:8616 254:0.796875:8612:8613 ~0.012835353748637117 133:0.921875:8614:8615 ~-0.03377445292133048 ~0.00855540565973479 34:-0.1875:8617:8618 ~0.015002309577086065 ~-0.02368929447806119 "
    s .= "35:-0.4375:8620:8621 ~0.031898456923149375 173:-0.546875:8622:8623 ~-0.03961726356125847 ~0.00859491676449854 228:-0.328125:8625:8626 ~-0.05362328689226431 245:1.9482758620689655:8627:8634 30:0.4140625:8628:8633 "
    s .= "243:1.25:8629:8632 70:0.234375:8630:8631 ~0.018946767363948756 ~-0.02076728673211193 ~-0.023817035859861713 ~-0.02559021447154732 222:0.15625:8635:8638 237:-0.03125:8636:8637 ~0.006886136330773472 ~-0.03798502752096132 "
    s .= "112:0.671875:8639:8642 214:0.21875:8640:8641 ~-0.04428737971847941 ~0.03214651574689081 ~0.023823631149931246 ~0.03785210316348249 ~-0.06727397632690117 246:1.546875:8646:8647 ~0.052791867921161174 "
    s .= "~-0.036182710885577285 ~-0.051115393854156504 110:-1.265625:8650:8657 189:-0.203125:8651:8654 121:0.34375:8652:8653 ~0.00782340699540413 ~-0.04510602855228491 91:0.078125:8655:8656 ~-0.09529615250227821 "
    s .= "~-0.01750953440458703 53:-0.765625:8658:8663 143:-0.546875:8659:8660 ~0.02238498974209582 110:-0.484375:8661:8662 ~-0.035534537959091776 ~0.012713772809271407 120:-0.40625:8664:8665 ~-0.028473305310995622 "
    s .= "108:-0.3359375:8666:8667 ~0.021625814841516044 246:0.203125:8668:8685 149:-0.015625:8669:8678 56:-0.046875:8670:8675 110:-0.015625:8671:8674 247:0.484375:8672:8673 ~-0.010088220177461825 ~-0.08933427486837853 "
    s .= "~0.02642694397429098 16:0.40625:8676:8677 ~0.010638985024315173 ~0.06518849610080295 245:2.0434782608695654:8679:8684 244:1.235:8680:8683 245:1.793103448275862:8681:8682 ~-0.06288356553668933 ~-0.002438706372508561 "
    s .= "~0.008112267870990349 ~-0.04488805404339385 137:0.265625:8686:8689 92:0.109375:8687:8688 ~0.0321003190523329 ~0.002333572762534008 106:-0.28125:8690:8691 ~0.03424978638066331 251:1.484375:8692:8693 "
    s .= "~-0.011108028660904525 252:0.275:8694:8695 ~-0.01970609755141666 ~0.03168428490881189 254:1.359375:8697:8738 176:0.703125:8698:8737 8:0.828125:8699:8734 2:0.640625:8700:8733 256:0.01818181818181818:8701:8728 "
    s .= "39:0.4375:8702:8725 184:0.03125:8703:8708 8:0.4375:8704:8707 119:0.15625:8705:8706 ~-0.006079272313488357 ~-0.04215428452814659 ~0.03834837285591297 242:0.55:8709:8714 13:0.046875:8710:8711 ~0.02341079633389309 "
    s .= "166:-0.03125:8712:8713 ~-0.04926695449268203 ~0.00574192009413075 245:1.5806451612903225:8715:8720 196:-0.609375:8716:8717 ~0.20405593013101125 38:0.40625:8718:8719 ~-0.06224323930714442 ~0.029238843051692977 "
    s .= "251:0.359375:8721:8724 134:0.046875:8722:8723 ~-0.03876389021077679 ~0.019751704714833507 ~0.011566748129597114 171:0.28125:8726:8727 ~-0.04378793699202704 ~0.0012103368454571487 54:-0.1171875:8729:8730 "
    s .= "~-0.04161050304823968 107:0.40625:8731:8732 ~0.03495621543417058 ~0.0059226403337094705 ~-0.035005588858952164 89:0.828125:8735:8736 ~0.05815413306538961 ~-0.032441342021625276 ~-0.02237738632221097 244:1.32:8739:8740 "
    s .= "~-0.034070330243325654 245:2.5526315789473686:8741:8742 ~0.01979927401425142 ~-0.03061543460059148 219:0.984375:8744:8789 254:0.984375:8745:8776 109:1.859375:8746:8765 251:0.203125:8747:8752 31:0.078125:8748:8751 "
    s .= "208:0.03125:8749:8750 ~-0.03549423704553637 ~0.015796364911829966 ~-0.03764150652728627 163:0.171875:8753:8764 187:-0.3125:8754:8755 ~-0.02418992916899372 85:0.53125:8756:8763 244:0.965:8757:8760 85:0.125:8758:8759 "
    s .= "~0.040655005599834274 ~-0.009417328834807951 79:0.28125:8761:8762 ~-0.01250657054027393 ~0.024117781617235212 ~0.027323302246214938 ~-0.00034365278274691585 254:0.046875:8766:8767 ~-0.059760281711961516 "
    s .= "104:-0.5625:8768:8769 ~0.03874377277942845 106:0.375:8770:8771 ~-0.05531220805174961 134:-0.078125:8772:8775 161:-0.421875:8773:8774 ~0.018492491181927136 ~-0.06646695276364999 ~0.017754503880662364 "
    s .= "2:-0.140625:8777:8788 158:-0.28125:8778:8783 244:1.39:8779:8782 245:2.2705882352941176:8780:8781 ~-0.05302655098220121 ~0.01212226462862602 ~0.006727212850657901 62:-0.421875:8784:8785 ~0.04333211238446183 "
    s .= "255:0.234375:8786:8787 ~0.03655227885799094 ~-0.020209530972286203 ~-0.03221528598582786 ~-0.04987061719114816 246:-2.390625:8791:8794 233:-0.65625:8792:8793 ~-0.0008449659746690465 ~-0.05283358325169907 "
    s .= "257:0.9090909090909091:8795:8834 93:-0.015625:8796:8805 148:0.734375:8797:8804 98:0.171875:8798:8801 250:0.9921875:8799:8800 ~0.0039491574991626826 ~0.022681097236251793 257:0.3333333333333333:8802:8803 "
    s .= "~0.007101929970889576 ~-0.07536572200757137 ~-0.019921328365059318 99:-0.15625:8806:8807 ~-0.03630837932596372 205:0.546875:8808:8831 175:0.578125:8809:8826 100:0.4375:8810:8823 67:0.5625:8811:8822 "
    s .= "106:-0.21875:8812:8813 ~0.02042258021292337 103:0.71875:8814:8821 208:0.78125:8815:8820 244:1.69:8816:8819 64:0.921875:8817:8818 ~-0.020342340493645347 ~0.029267784089393553 ~-0.056501912420978864 ~0.02919193446549147 "
    s .= "~0.010541969958803393 ~0.020401868670267314 245:2.183673469387755:8824:8825 ~0.022525069761903972 ~-0.024385419371945164 193:-0.046875:8827:8828 ~-0.019063316283610215 242:0.25:8829:8830 ~-0.04431780118473938 "
    s .= "~0.03293956822570028 44:-0.125:8832:8833 ~0.04083521583303521 ~0.0004174946765160756 254:0.015625:8835:8836 ~0.011380263231474091 ~-0.04611427838289428 72:1.078125:8838:8883 251:0.515625:8839:8870 241:0.3:8840:8867 "
    s .= "168:0.140625:8841:8860 245:1.9175257731958764:8842:8853 247:0.515625:8843:8850 94:0.109375:8844:8849 30:0.3671875:8845:8848 249:0.8333333333333333:8846:8847 ~0.03700162076341319 ~-0.04811836228083121 "
    s .= "~-0.04807453562758529 ~-0.019692882808940604 4:0.171875:8851:8852 ~-0.044087204324722476 ~0.18367645725941062 202:0.84375:8854:8857 182:-0.453125:8855:8856 ~0.007908682673867833 ~-0.03307145181704761 "
    s .= "190:0.0625:8858:8859 ~-0.04466778160328569 ~0.060726780550776266 55:-0.328125:8861:8864 153:0.3359375:8862:8863 ~-0.03487471821705722 ~0.0709383688161768 175:0.53125:8865:8866 ~-0.027568290389835656 "
    s .= "~0.027254938229429832 253:-0.06666666666666857:8868:8869 ~0.006854976074169481 ~-0.027399766606144228 121:0.015625:8871:8876 249:0.16666666666666666:8872:8873 ~0.008423218386914106 123:0.25:8874:8875 "
    s .= "~-0.02123402267695451 ~0.011545749938090613 250:0.8046875:8877:8880 216:0.109375:8878:8879 ~-0.046054394248116685 ~0.02403538652944483 202:0.265625:8881:8882 ~0.01662498773627464 ~-0.00255493961811519 "
    s .= "~-0.0585373943898918 219:0.984375:8885:8930 220:0.84375:8886:8925 221:0.65625:8887:8924 151:0.140625:8888:8897 242:0.25:8889:8890 ~-0.03218333563687827 106:1.859375:8891:8892 ~0.008470173297740458 "
    s .= "105:-0.3046875:8893:8894 ~0.030148814685639364 181:0.046875:8895:8896 ~-0.08674727385834641 ~-0.018447690460436327 244:1.635:8898:8921 183:-0.53125:8899:8900 ~-0.04779724370423343 250:0.6796875:8901:8902 "
    s .= "~-0.049931443179877 145:-0.109375:8903:8904 ~-0.025403080602791846 229:-0.171875:8905:8908 256:0.01818181818181818:8906:8907 ~-0.04764496530657703 ~0.02030871777541026 245:1.5806451612903225:8909:8912 154:0.25:8910:8911 "
    s .= "~0.021943591889146706 ~-0.037996212410809735 64:0.421875:8913:8920 37:-0.296875:8914:8915 ~0.03695880645127225 202:0.53125:8916:8919 22:0.359375:8917:8918 ~-0.012943599558046534 ~0.03265682649907258 ~0.02999927418615594 "
    s .= "~0.02901331230760379 250:0.9453125:8922:8923 ~-0.009122117264935071 ~0.025339852335409908 ~-0.03492097393807303 187:0.78125:8926:8929 232:-0.21875:8927:8928 ~-0.037209655483594346 ~0.04196750922477017 "
    s .= "~-0.046054305222258604 ~-0.049352873732404025 15:-1.0078125:8932:8933 ~0.050090615091428106 246:-2.390625:8934:8941 233:-0.65625:8935:8940 208:0:8936:8937 ~-0.04067180145057206 115:0.390625:8938:8939 "
    s .= "~0.02924381990860176 ~-0.020480940679647463 ~-0.052057511000112335 257:0.9090909090909091:8942:8975 93:-0.015625:8943:8952 148:0.734375:8944:8951 98:0.171875:8945:8948 88:2.265625:8946:8947 ~0.01558642125017194 "
    s .= "~-0.056641000044549694 257:0.3333333333333333:8949:8950 ~0.006182560317376358 ~-0.07342111183933132 ~-0.020416288750246248 99:-0.15625:8953:8954 ~-0.03468712559471443 117:0.015625:8955:8956 ~-0.016855276265051945 "
    s .= "205:0.546875:8957:8974 175:0.578125:8958:8967 100:0.4375:8959:8964 106:-0.28125:8960:8961 ~0.029263947838522344 64:0.921875:8962:8963 ~-0.012217750126589736 ~0.028084919853669232 144:0.328125:8965:8966 "
    s .= "~0.027788830911866125 ~-0.023249807054289775 242:0.35:8968:8969 ~-0.040393132790248004 217:-0.078125:8970:8973 9:0.1796875:8971:8972 ~-0.058305310000043846 ~0.035767345647682074 ~0.03722715882371886 "
    s .= "~0.023383002091475286 254:0.015625:8976:8977 ~0.010937068097735012 ~-0.0449770849324791 47:1.328125:8979:9024 11:0.921875:8980:9021 211:1.8125:8981:9020 208:0.890625:8982:9015 220:0.84375:8983:9014 205:0.9375:8984:9013 "
    s .= "151:0.140625:8985:9004 79:0.640625:8986:9003 106:1.734375:8987:9002 91:0.75:8988:9001 242:0.25:8989:8990 ~-0.04305098941682496 245:1.925233644859813:8991:8994 243:1.35:8992:8993 ~0.01476925355306805 "
    s .= "~-0.038599151536150594 169:0.3125:8995:8998 253:0.06312275295325914:8996:8997 ~-0.021415531551686913 ~0.04745549914956453 249:0.8333333333333333:8999:9000 ~-0.01870018313500185 ~0.08423411419347901 ~0.03059471577794275 "
    s .= "~-0.053166716220486736 ~0.02185621276594694 257:0.5769230769230769:9005:9012 74:-0.015625:9006:9011 231:-0.484375:9007:9008 ~-0.049141433248340825 253:0.01208576998050622:9009:9010 ~0.010625170587678884 "
    s .= "~-0.01770713205775426 ~-0.01822439818837723 ~-0.03011154951848502 ~0.022350709998911325 ~0.025777565952146416 244:1.605:9016:9019 45:0.1953125:9017:9018 ~-0.02792757520509108 ~0.022462031645738643 ~0.03646325533982848 "
    s .= "~-0.05501934071944754 246:1.546875:9022:9023 ~0.05392333018393524 ~-0.03498348544864607 ~-0.060591755405127595 254:0.984375:9026:9069 191:-0.484375:9027:9040 190:0.421875:9028:9035 106:0.15625:9029:9032 "
    s .= "130:0.8125:9030:9031 ~0.02047672915382914 ~-0.02846486500037511 73:0.609375:9033:9034 ~0.026044158512620846 ~-0.038235609936121365 151:0.15625:9036:9039 120:0.046875:9037:9038 ~0.029727692123357897 "
    s .= "~-0.050978375223381715 ~-0.03163866501783487 246:-2.015625:9041:9042 ~-0.03630232496365026 109:1.953125:9043:9066 247:-0.984375:9044:9045 ~-0.06397525801714199 30:0.4296875:9046:9057 245:1.0266666666666666:9047:9048 "
    s .= "~-0.048210214639822085 9:0.1640625:9049:9056 124:0.828125:9050:9055 2:0.578125:9051:9054 58:0.703125:9052:9053 ~0.0023981286566604116 ~0.02720100828192007 ~-0.04920325982662628 ~-0.02995677865002032 ~0.01698068987047994 "
    s .= "112:0.6875:9058:9063 89:0.75:9059:9062 108:0.6796875:9060:9061 ~-0.036511904917910724 ~0.04691743579526716 ~0.024406986250918795 132:0.1015625:9064:9065 ~-0.02211347285959229 ~0.026114238675680287 "
    s .= "253:-0.0243055555555524:9067:9068 ~0.0010409245294644254 ~-0.04680726528054984 159:0.2734375:9070:9071 ~-0.005189000207136238 ~-0.045048172134874005 219:0.984375:9073:9118 251:0.796875:9074:9101 241:0.38:9075:9096 "
    s .= "245:1.9444444444444444:9076:9089 130:0.703125:9077:9086 127:0.640625:9078:9085 255:0.265625:9079:9082 185:0.453125:9080:9081 ~0.008418603104092665 ~-0.04398577068425823 231:-0.359375:9083:9084 ~0.03547591834718583 "
    s .= "~-0.05210697049434557 ~0.04846673611465882 219:-0.1875:9087:9088 ~-0.017825305657101567 ~0.029422586867818692 118:0:9090:9091 ~-0.028416926860970654 4:-0.109375:9092:9095 57:-0.0234375:9093:9094 ~-0.019476935587890053 "
    s .= "~0.051734302652941204 ~-0.00892495839227491 181:0.171875:9097:9098 ~0.0046355677779101835 163:0.171875:9099:9100 ~-0.002735324332339041 ~-0.03828674593975909 252:0.375:9102:9115 184:0.140625:9103:9108 "
    s .= "199:0.03125:9104:9105 ~-0.031201076831975025 128:0.0625:9106:9107 ~0.01371361276781679 ~-0.025593172553908486 25:0.21875:9109:9112 98:-0.0625:9110:9111 ~0.028756738351317437 ~-0.004975395916050205 116:-0.09375:9113:9114 "
    s .= "~-0.043264682395647625 ~0.015061370915540263 1:0.5:9116:9117 ~0.018601812117958368 ~-0.031192608865227667 ~-0.048799089036890765 33:0.921875:9120:9165 247:0.796875:9121:9162 235:1.78125:9122:9161 107:0.96875:9123:9160 "
    s .= "124:-0.65625:9124:9125 ~-0.04327767107875277 192:0.984375:9126:9159 242:2.05:9127:9154 241:3.86:9128:9151 8:0.96875:9129:9150 77:0.640625:9130:9149 120:0.171875:9131:9148 249:0.5:9132:9137 240:-0.03125:9133:9134 "
    s .= "~0.0120143843918749 107:0.09375:9135:9136 ~-0.014551129242265613 ~0.009930309433856506 245:1.6547619047619047:9138:9139 ~-0.04911522915720829 231:0.109375:9140:9147 122:-0.34375:9141:9144 110:-0.3125:9142:9143 "
    s .= "~-0.015834455530985055 ~0.041314904199802625 12:0.109375:9145:9146 ~-0.04612680003774639 ~0.007444156740816866 ~0.0223201310934508 ~0.009667989459758643 ~-0.025674026009387497 ~0.05272453673985638 248:0.125:9152:9153 "
    s .= "~-0.043502171479615964 ~0.11239742595859022 252:0.675:9155:9156 ~-0.08972562462812154 244:1.05:9157:9158 ~-0.03908006236000319 ~0.016111547132973046 ~-0.061003602230620006 ~0.03440102450925192 ~-0.04819650396482446 "
    s .= "237:0.578125:9163:9164 ~-0.05564159154691874 ~0.03536722215873 ~-0.036282518242265076 254:1.359375:9167:9208 47:-0.625:9168:9181 49:0.5625:9169:9180 205:0.109375:9170:9177 34:0.28125:9171:9176 54:-0.5390625:9172:9173 "
    s .= "~0.035799992537021624 206:-0.53125:9174:9175 ~-0.0011758455585054194 ~-0.04312811110559983 ~0.04234734275318157 43:0.6875:9178:9179 ~0.029406451013074576 ~-0.04450422772162775 ~-0.03539293192934486 "
    s .= "117:-0.59375:9182:9183 ~-0.04171076920487725 246:-2.421875:9184:9187 237:-0.328125:9185:9186 ~0.01535799318155397 ~-0.06606819065203776 217:0.25:9188:9203 93:-0.046875:9189:9200 255:0.265625:9190:9195 77:0.125:9191:9194 "
    s .= "68:-0.109375:9192:9193 ~0.016366356011368332 ~0.04805367988930855 ~-0.01652841276622404 196:0.359375:9196:9199 257:0.4166666666666667:9197:9198 ~-0.0009327028663219396 ~-0.050091446932343436 ~0.0519791288169523 "
    s .= "228:-0.359375:9201:9202 ~-0.060006171114969455 ~-0.00013925367551487216 243:0.25:9204:9205 ~0.03761284714069533 244:1.095:9206:9207 ~-0.033632610596957095 ~-0.0022318208298068177 50:-0.25:9209:9212 "
    s .= "169:-0.109375:9210:9211 ~-0.05085228887944359 ~0.00023749809937182294 ~-0.054709482830711476 47:1.328125:9214:9259 11:0.921875:9215:9256 247:0.984375:9216:9255 246:1.796875:9217:9254 124:-0.65625:9218:9219 "
    s .= "~-0.04456270749927671 91:1.171875:9220:9251 30:0.4296875:9221:9242 115:1.09375:9222:9239 189:0.4375:9223:9236 58:1.0625:9224:9233 110:-1.296875:9225:9226 ~-0.02800073385823428 103:1.015625:9227:9232 243:1.25:9228:9231 "
    s .= "46:0.078125:9229:9230 ~0.010007981123464574 ~-0.006947019282212214 ~-0.02067714455243794 ~0.022715911519029172 244:0.94:9234:9235 ~0.09546320633211725 ~0.01596325284448982 31:-0.359375:9237:9238 ~0.03872518109919587 "
    s .= "~-0.033812401046592305 187:0.109375:9240:9241 ~-0.03873622059749934 ~0.00006190706603613387 141:0.1328125:9243:9246 13:0.21875:9244:9245 ~-0.048057915935023704 ~0.008257185483492606 112:0.671875:9247:9250 "
    s .= "177:0.1875:9248:9249 ~0.012968827012696872 ~-0.03161568298103606 ~0.01955758682796715 97:0:9252:9253 ~-0.007360850647903233 ~0.02690822074899156 ~0.03585816548739387 ~-0.059413826766207246 155:0.6875:9257:9258 "
    s .= "~0.05183975873994933 ~-0.033392530218534236 ~-0.05983205220168946 251:0.515625:9261:9278 205:-0.15625:9262:9265 238:1:9263:9264 ~-0.03681612033176288 ~0.08513373891206612 169:1.453125:9266:9277 6:0.453125:9267:9274 "
    s .= "31:0.0625:9268:9271 22:-0.265625:9269:9270 ~-0.029310749648537478 ~0.008976322612627739 243:2.95:9272:9273 ~-0.01351173424311439 ~0.14011350546387266 94:0.375:9275:9276 ~-0.04310744506536716 ~0.023394467913872886 "
    s .= "~0.05948280222430572 238:0.59375:9279:9306 79:0.796875:9280:9303 91:0.796875:9281:9302 46:0.890625:9282:9301 154:0.625:9283:9294 246:-0.609375:9284:9287 125:-0.625:9285:9286 ~0.001048845845841715 ~-0.044449630244400934 "
    s .= "71:-0.09375:9288:9289 ~0.015656798907954583 178:0.109375:9290:9293 250:1.3515625:9291:9292 ~0.013807872987449324 ~-0.0330742678339221 ~-0.028042670744908904 223:-0.03125:9295:9296 ~-0.021748140125982376 "
    s .= "208:-0.078125:9297:9300 58:0.125:9298:9299 ~0.023417912479306663 ~-0.06812299581897549 ~0.02897090088220866 ~0.04238738534683251 ~0.02011706468648658 151:0.0625:9304:9305 ~0.035489716560555704 ~0.003862623214872179 "
    s .= "~-0.017577217006026012 244:2.905:9308:9351 244:1.635:9309:9344 183:-0.53125:9310:9313 148:0.15625:9311:9312 ~-0.005048991277480661 ~-0.05281439351042642 121:-0.046875:9314:9319 9:0.1953125:9315:9318 127:0.3125:9316:9317 "
    s .= "~-0.008218695267230626 ~-0.04000489909255688 ~0.0032709761635809458 91:0.796875:9320:9341 30:0.4296875:9321:9336 85:-0.390625:9322:9323 ~0.04021319559366124 67:-0.140625:9324:9325 ~-0.01632213561574281 "
    s .= "31:0.03125:9326:9327 ~0.018340755827009066 248:0.125:9328:9331 253:-0.02881355932203178:9329:9330 ~0.012369175817633488 ~-0.04419970354196115 253:-0.008888888888890278:9332:9333 ~-0.022427669928481376 139:0.5:9334:9335 "
    s .= "~0.0019790338583940076 ~0.03614689336164014 141:0.1328125:9337:9338 ~-0.04516672520112054 235:0.25:9339:9340 ~0.006399428339353145 ~-0.04056837151659558 10:0.703125:9342:9343 ~0.0276715650564935 ~-0.05420425785572141 "
    s .= "157:0.25:9345:9350 154:0.3125:9346:9349 58:0.234375:9347:9348 ~-0.04477583477674082 ~0.01836427074283868 ~0.02828271523972511 ~0.022188288376995133 4:0.03125:9352:9353 ~-0.0017698897418030202 ~-0.06451970677066675 "
    s .= "254:0.984375:9355:9386 109:1.859375:9356:9375 251:0.203125:9357:9362 31:0.078125:9358:9361 208:0.03125:9359:9360 ~-0.03458438447276258 ~0.014010280693931045 ~-0.03620395329005426 226:0.21875:9363:9368 "
    s .= "106:1.765625:9364:9365 ~0.008865739381017297 244:2.66:9366:9367 ~-0.008745759056927597 ~-0.09361801960072852 250:0.5546875:9369:9370 ~0.128928710045726 223:0.625:9371:9374 136:1.140625:9372:9373 ~-0.008581374120815949 "
    s .= "~0.023425454517069174 ~-0.034254051357469416 165:-0.21875:9376:9377 ~0.016265764974353343 195:0.25:9378:9383 199:0.515625:9379:9382 83:0.234375:9380:9381 ~-0.07164213458926892 ~-0.004677471137895824 ~0.03161920736806566 "
    s .= "43:-0.03125:9384:9385 ~0.03619769221671922 ~-0.02431616526269426 5:-0.171875:9387:9396 196:0.296875:9388:9393 247:0.234375:9389:9392 257:0.5:9390:9391 ~0.0032458136466885184 ~-0.0447505434480712 ~-0.05176507408767181 "
    s .= "164:-0.171875:9394:9395 ~-0.001995731795248737 ~0.05006169185496352 255:0.234375:9397:9400 51:0.0703125:9398:9399 ~0.02085077919743308 ~-0.04063531666820915 ~-0.05235591795136499 191:0.78125:9402:9447 "
    s .= "211:1.8125:9403:9446 251:0.515625:9404:9443 241:0.3:9405:9428 186:-0.03125:9406:9413 251:0.109375:9407:9408 ~-0.027908535858212038 250:0.6796875:9409:9410 ~-0.057380291787289955 249:1.1666666666666665:9411:9412 "
    s .= "~0.025776402160144114 ~-0.04690173048079033 110:0.03125:9414:9421 10:0.1875:9415:9420 169:0.734375:9416:9419 55:-0.609375:9417:9418 ~0.061259800886870656 ~-0.0443117230228291 ~0.052607537024115095 ~0.012841771010314862 "
    s .= "136:0.390625:9422:9423 ~-0.019272528348221216 48:0.0078125:9424:9425 ~-0.03935003553993182 95:0.21875:9426:9427 ~0.03819417553599018 ~-0.010210658280650467 253:-0.06666666666666857:9429:9436 244:2.07:9430:9433 "
    s .= "252:0.07500000000000001:9431:9432 ~-0.05787200869067047 ~0.026969534402180875 79:0.1875:9434:9435 ~-0.10293200623302086 ~0.014920377201957364 181:1.03125:9437:9442 244:1.615:9438:9441 243:2.95:9439:9440 "
    s .= "~-0.0283421356523472 ~0.08384659052904123 ~0.024134926006718568 ~-0.05352415908411399 144:0.125:9444:9445 ~-0.0004959028283329795 ~0.01052682725261165 ~-0.05152174083690203 ~-0.030361637629725803 219:0.984375:9449:9494 "
    s .= "251:1.140625:9450:9479 242:1.25:9451:9474 172:-0.515625:9452:9453 ~-0.044215486514915345 122:0.625:9454:9473 8:0.4375:9455:9470 95:0.21875:9456:9465 28:-0.015625:9457:9458 ~0.009929720094911628 94:0.015625:9459:9460 "
    s .= "~-0.019616714251910982 113:0:9461:9462 ~-0.005378544929348179 74:-0.09375:9463:9464 ~0.044899440908700385 ~0.003933110494104686 139:-0.265625:9466:9467 ~0.03725791770663369 110:-0.125:9468:9469 ~-0.07787540567222001 "
    s .= "~-0.017220236410089945 110:0.640625:9471:9472 ~0.039318480376783226 ~-0.03261190336222609 ~-0.04737608663529602 252:0.525:9475:9476 ~-0.05957908401583831 37:-0.15625:9477:9478 ~-0.05095545258895349 "
    s .= "~0.0057005331636379095 241:0.52:9480:9493 136:1.125:9481:9488 46:0.453125:9482:9487 79:0.015625:9483:9486 77:0.25:9484:9485 ~0.014656510902239664 ~-0.05637767209494365 ~-0.03770468068024539 ~0.027126926884517094 "
    s .= "214:0.03125:9489:9492 85:0.5625:9490:9491 ~-0.054220641143247594 ~0.029763772638520442 ~0.03463109265921257 ~0.01954015176538633 ~-0.04790549504009632 166:2.03125:9496:9541 205:1.1875:9497:9538 244:2.905:9498:9533 "
    s .= "121:-0.015625:9499:9514 249:0.5:9500:9511 240:0.3125:9501:9508 44:-0.125:9502:9507 217:-0.40625:9503:9504 ~0.04022040695443749 187:0.21875:9505:9506 ~0.00030467067257481463 ~-0.032993849574053345 ~0.018278232630935004 "
    s .= "194:0.109375:9509:9510 ~-0.007592551305559869 ~-0.054471978355993315 168:0.046875:9512:9513 ~-0.03745390178065087 ~-0.00758390668653592 121:0.125:9515:9526 136:1.46875:9516:9525 77:0.046875:9517:9524 "
    s .= "249:1.1666666666666665:9518:9521 64:-0.03125:9519:9520 ~-0.008022314211032491 ~0.02446725048629654 166:0.15625:9522:9523 ~0.014527654680633962 ~0.11298562659444467 ~-0.0013897413039770758 ~-0.01753094310646699 "
    s .= "142:-0.15625:9527:9532 102:0.3671875:9528:9529 ~-0.03661005865722718 196:0.125:9530:9531 ~-0.04529188656774029 ~0.04692044416289372 ~0.0012934239371025823 31:0.015625:9534:9537 250:1.4296875:9535:9536 "
    s .= "~0.02671710288101728 ~-0.04791861624655969 ~-0.056472818147296204 148:1.03125:9539:9540 ~0.027352174387299477 ~-0.027052456982003883 ~-0.04449066433372337 15:-1.0078125:9543:9544 ~0.047145979314075555 245:4:9545:9588 "
    s .= "205:-0.5:9546:9547 ~-0.033545464316159804 85:-0.46875:9548:9549 ~0.027316209889766036 242:2.25:9550:9587 252:1.775:9551:9584 243:1.35:9552:9577 130:0.15625:9553:9562 241:0.18:9554:9561 223:0.3125:9555:9560 "
    s .= "112:0.40625:9556:9557 ~-0.018164180989756824 53:-0.03125:9558:9559 ~0.041645979973902604 ~-0.026583919394771918 ~-0.06302964123554666 ~0.019459866763805404 244:1.555:9563:9576 246:-0.265625:9564:9569 "
    s .= "230:-0.15625:9565:9568 247:0.171875:9566:9567 ~-0.005239913393480939 ~-0.0678530616878345 ~-0.05073954535334244 255:0.046875:9570:9573 144:0.359375:9571:9572 ~-0.05241678583095241 ~0.024956545234438826 "
    s .= "77:0.03125:9574:9575 ~0.015877969805518984 ~-0.00972796521700561 ~0.011612056946261315 252:0.525:9578:9579 ~-0.06777734256535516 199:0.140625:9580:9583 119:-0.0625:9581:9582 ~0.03526481150008056 ~-0.018787548688811807 "
    s .= "~-0.05610363313916388 178:0.296875:9585:9586 ~0.03941028054242719 ~-0.003217692115884434 ~-0.028935707033183922 ~-0.05417380676690045 254:1.359375:9590:9635 122:-0.59375:9591:9598 166:-0.078125:9592:9595 "
    s .= "85:1.484375:9593:9594 ~-0.03132271964221109 ~0.03538304284904482 14:0.265625:9596:9597 ~0.01740258886123813 ~-0.049568518540364974 246:-2.171875:9599:9602 240:-0.21875:9600:9601 ~-0.006074278313129143 "
    s .= "~-0.06912658849326922 174:-0.390625:9603:9604 ~-0.03166033725776728 108:-0.3046875:9605:9606 ~0.022843065402478487 246:-0.578125:9607:9610 111:-0.1953125:9608:9609 ~0.0031846301947824163 ~-0.03544823015966305 "
    s .= "74:-0.078125:9611:9612 ~0.010166844670531349 249:1.1666666666666665:9613:9634 11:0.40625:9614:9629 257:0.4166666666666667:9615:9626 46:-0.25:9616:9617 ~-0.039281029748494255 245:1.891566265060241:9618:9621 "
    s .= "48:0.3984375:9619:9620 ~0.019427238549122035 ~-0.016637252739045618 252:0.525:9622:9625 126:0.296875:9623:9624 ~-0.03389327744216524 ~0.0172024108761089 ~0.013800445792728364 96:0.0546875:9627:9628 ~-0.11168960477842643 "
    s .= "~0.05934503825746656 110:0.5625:9630:9633 241:0.8:9631:9632 ~0.04288168775918082 ~-0.03130440404390055 ~-0.012240202818492106 ~-0.036591643261027526 ~-0.015291427028208876 72:1.078125:9637:9682 5:-1.484375:9638:9639 "
    s .= "~0.028971460783283706 246:-2.390625:9640:9647 158:-1.578125:9641:9642 ~0.022952069664071484 168:-0.140625:9643:9646 176:-0.59375:9644:9645 ~-0.0016541004281391304 ~-0.054909380579870805 ~-0.06248426548662646 "
    s .= "257:0.9090909090909091:9648:9679 188:-0.453125:9649:9654 4:0.25:9650:9651 ~0.015083278897521521 198:0.21875:9652:9653 ~-0.03656522770628383 ~0.025208608741407842 246:-0.640625:9655:9660 66:0.03125:9656:9659 "
    s .= "247:-0.390625:9657:9658 ~0.009591611932049646 ~-0.03611532649612671 ~-0.04477152297854058 22:-0.265625:9661:9666 16:-0.015625:9662:9665 231:0.296875:9663:9664 ~-0.04536946598132837 ~0.002321611280416474 "
    s .= "~0.024670330897994676 153:-0.1328125:9667:9668 ~0.025602991871366994 244:2.81:9669:9676 42:-0.0625:9670:9671 ~0.020126926944724267 9:0.0078125:9672:9673 ~-0.022954583307862292 255:-0.046875:9674:9675 "
    s .= "~-0.04846328626015647 ~0.00497862779056819 218:0.40625:9677:9678 ~-0.06430939008474984 ~0.04035293175586645 160:0.1875:9680:9681 ~0.021462807545086227 ~-0.03768527681298319 ~-0.05633359916247663 254:0.984375:9684:9707 "
    s .= "47:-0.6875:9685:9690 218:-0.515625:9686:9689 184:0.015625:9687:9688 ~-0.0025286824942374977 ~0.03616734278571183 ~-0.012034450771082441 246:-2.015625:9691:9696 210:-0.21875:9692:9695 244:1.615:9693:9694 "
    s .= "~-0.04568284864932345 ~0.023593399161505716 ~-0.05532873156047703 231:-0.46875:9697:9698 ~-0.03798072050319457 105:-0.3984375:9699:9702 16:0.328125:9700:9701 ~0.03855708199477169 ~-0.05699899925557905 "
    s .= "104:-0.90625:9703:9704 ~-0.05525209046658807 109:2.171875:9705:9706 ~0.002569970921758709 ~-0.0325651828628391 250:1.0546875:9708:9721 98:-0.25:9709:9720 161:-0.265625:9710:9715 109:1.109375:9711:9712 "
    s .= "~-0.03955989004994517 51:-0.2578125:9713:9714 ~-0.048223170766259135 ~0.029848050700649876 95:-0.265625:9716:9717 ~0.04590288153395536 205:0.359375:9718:9719 ~-0.049739711351688504 ~0.045169954020022905 "
    s .= "~-0.045663168269457786 241:0.42:9722:9727 244:1.3:9723:9726 29:0.265625:9724:9725 ~-0.043709211333061646 ~0.04326192595458161 ~0.012877835444323402 226:-0.125:9728:9729 ~-0.035181237613583514 ~0.03573152496341274 "
    s .= "106:0.015625:9731:9738 245:1.8072289156626506:9732:9733 ~0.0063333012175518545 252:0.32499999999999996:9734:9737 220:-0.046875:9735:9736 ~-0.054636059499673144 ~-0.013815785383965301 ~0.03064969305126074 "
    s .= "163:0.34375:9739:9758 204:0.390625:9740:9753 93:0.59375:9741:9752 136:1.890625:9742:9751 120:0.046875:9743:9750 249:0.16666666666666666:9744:9745 ~0.016289938414593592 130:0.171875:9746:9749 244:1.155:9747:9748 "
    s .= "~0.03775603732872368 ~-0.010940228601348564 ~-0.01433455102921078 ~0.018311044972370443 ~-0.02149628373335996 ~-0.029542937158834937 252:0.225:9754:9757 108:0.5234375:9755:9756 ~-0.03730517820347233 ~0.03220950312311014 "
    s .= "~0.010101040191906135 244:1.505:9759:9776 154:0.171875:9760:9767 27:0.125:9761:9764 226:0.1875:9762:9763 ~0.03328219536820053 ~-0.04149350669406894 232:0.140625:9765:9766 ~-0.04227096941964085 ~0.02418464875568397 "
    s .= "50:-0.125:9768:9775 207:-0.359375:9769:9770 ~-0.04667245712101227 71:-0.9375:9771:9772 ~0.03904791538003846 251:0.828125:9773:9774 ~-0.025223035371958392 ~0.01376287237319013 ~-0.034070485614328634 ~0.008822314634375248 "
    s .= "253:-0.09898989898990054:9778:9801 252:0.125:9779:9790 70:0.0625:9780:9783 123:-0.1875:9781:9782 ~-0.04900973135509617 ~0.01564232008097158 250:1.2109375:9784:9789 214:-0.265625:9785:9786 ~0.024913291218299324 "
    s .= "214:0.09375:9787:9788 ~-0.10269086475817164 ~-0.02229335028915129 ~0.0058564617985321175 46:-0.265625:9791:9794 103:0.234375:9792:9793 ~0.027130069698463058 ~-0.0608510477547187 257:0.8482142857142857:9795:9800 "
    s .= "244:0.92:9796:9799 55:0.109375:9797:9798 ~0.02654043730845204 ~-0.049731751985597206 ~0.03520214595335177 ~-0.04811825975736057 251:1.140625:9802:9823 248:0.125:9803:9808 240:-0.015625:9804:9807 133:0.75:9805:9806 "
    s .= "~-0.03661178343516538 ~0.01313711089999392 ~-0.02710777108144584 253:-0.02255639097744425:9809:9812 88:0.859375:9810:9811 ~-0.03139931753100888 ~0.008985909500476664 40:-0.015625:9813:9816 10:0.125:9814:9815 "
    s .= "~-0.013493105963193933 ~0.022678967376714848 244:1.37:9817:9822 107:0.390625:9818:9821 32:0.421875:9819:9820 ~0.01919402424079004 ~0.06831209764367094 ~-0.011902252747651516 ~-0.012687674720125866 ~0.005557365392928424 "
    s .= "154:0.609375:9825:9862 100:0.484375:9826:9859 178:0.578125:9827:9856 58:0.703125:9828:9851 67:0.796875:9829:9848 103:0.71875:9830:9847 190:0.6875:9831:9842 111:0.3515625:9832:9841 229:0.671875:9833:9840 "
    s .= "118:0.578125:9834:9837 102:-0.6328125:9835:9836 ~0.028780527912734045 ~-0.02802183600232039 151:0.265625:9838:9839 ~0.03194605798869706 ~-0.040638576090040034 ~0.019708401100057303 ~0.011264088743910008 "
    s .= "103:0.171875:9843:9846 85:1.859375:9844:9845 ~0.04975397310500343 ~-0.09683731530249971 ~-0.05004847079044714 ~0.006344795921187044 145:-0.109375:9849:9850 ~-0.04821602280847609 ~0.039525036320484416 "
    s .= "217:-0.09375:9852:9853 ~0.04669386509848147 34:0.1875:9854:9855 ~0.024482551959836077 ~-0.03088002805163642 103:0.546875:9857:9858 ~0.027040369921924403 ~-0.029437934833208737 154:0.15625:9860:9861 ~0.026369696393328798 "
    s .= "~-0.004975946284208322 208:-0.25:9863:9866 241:0.58:9864:9865 ~-0.06253398460346503 ~-0.005020498322644357 142:0.609375:9867:9870 166:1.625:9868:9869 ~0.013088731740107072 ~-0.08101243732780328 ~-0.018011447027422172 "
    s .= "247:0.765625:9872:9915 233:0.671875:9873:9912 110:0.921875:9874:9909 124:-0.65625:9875:9876 ~-0.041264291550677096 11:0.796875:9877:9908 74:0.109375:9878:9897 107:0.09375:9879:9892 28:-0.015625:9880:9887 "
    s .= "211:-0.015625:9881:9886 84:-0.0234375:9882:9885 110:-1.296875:9883:9884 ~-0.05885352041823405 ~0.02171433785827867 ~-0.030681089763805593 ~0.014325936923111746 199:0.0625:9888:9891 122:-1.109375:9889:9890 "
    s .= "~0.02407340890400296 ~-0.021677135233870826 ~0.001820433589616945 113:0.1875:9893:9894 ~0.027408623549164002 4:-0.015625:9895:9896 ~-0.019396614399117537 ~0.01753421501051608 249:0.8333333333333333:9898:9907 "
    s .= "257:0.4:9899:9902 142:-0.09375:9900:9901 ~-0.029636405731525112 ~0.006818991058311437 47:0.40625:9903:9906 244:2.66:9904:9905 ~-0.03901773965110538 ~-0.18131146150284325 ~0.027415318060326006 ~-0.0345460227412003 "
    s .= "~0.030888893927405077 251:0.859375:9910:9911 ~-0.036142909186193485 ~0.03936669528434139 139:-0.28125:9913:9914 ~0.046387291834848 ~-0.041580265212398576 237:0.578125:9916:9917 ~-0.04827010529227406 ~0.02478730296969489 "
    s .= "219:0.984375:9919:9964 220:0.84375:9920:9959 221:0.65625:9921:9958 8:0.828125:9922:9955 247:0.796875:9923:9954 256:0.01818181818181818:9924:9947 23:0.71875:9925:9944 247:0.203125:9926:9933 42:0.484375:9927:9932 "
    s .= "175:-0.484375:9928:9929 ~-0.04734874420512622 2:-0.15625:9930:9931 ~0.0067834257413217 ~-0.005370781444005564 ~-0.027776569919319108 243:0.55:9934:9943 248:0.125:9935:9936 ~-0.04817576995233907 70:0.140625:9937:9942 "
    s .= "244:0.99:9938:9941 151:0.0625:9939:9940 ~0.04125995529054745 ~-0.03630534562287679 ~-0.038402160508744995 ~0.028320141289290102 ~-0.04454655199664184 252:0.025:9945:9946 ~0.08377288622818137 ~-0.05062063136096824 "
    s .= "14:0.609375:9948:9953 54:-0.1015625:9949:9950 ~-0.031189568396100237 245:1.3020833333333333:9951:9952 ~-0.006653710154019922 ~0.02703185680778509 ~-0.0359169965641429 ~-0.03806389088499578 107:0.75:9956:9957 "
    s .= "~0.052833810644144844 ~-0.03307758351728456 ~-0.0329955267951472 187:0.78125:9960:9963 232:-0.21875:9961:9962 ~-0.03661146952714687 ~0.038078154329165816 ~-0.04315890713391604 ~-0.04730027129328384 "
    s .= "235:1.78125:9966:10011 191:0.78125:9967:10008 246:1.796875:9968:10007 176:0.703125:9969:10006 8:0.875:9970:10005 154:0.609375:9971:9980 100:0.484375:9972:9979 178:0.578125:9973:9976 58:0.703125:9974:9975 "
    s .= "~-0.011334865671305512 ~0.014153410620805476 103:0.546875:9977:9978 ~0.027374178688231776 ~-0.02883115331322041 ~0.012607204804467007 208:-0.25:9981:9982 ~-0.02848718809494129 142:0.4375:9983:10004 242:0.55:9984:9989 "
    s .= "244:1.205:9985:9988 232:0.09375:9986:9987 ~0.023512762108945408 ~-0.03519973220588091 ~0.03506210391476071 244:1.125:9990:9993 166:0.203125:9991:9992 ~0.04292177653594241 ~-0.022056483607450907 251:1.171875:9994:10003 "
    s .= "248:0.125:9995:10000 253:-0.04973404255318883:9996:9997 ~0.01705579867030288 131:0.234375:9998:9999 ~-0.05663508012210033 ~0.029429402466080126 245:1.6081081081081081:10001:10002 ~-0.17618540360183796 "
    s .= "~0.015513010328936185 ~0.02448662403959336 ~-0.013591915369876102 ~0.041799898224880144 ~-0.027444819132402733 ~0.03167296345056639 166:-0.75:10009:10010 ~0.10591168948913571 ~-0.03911329889624637 ~-0.03935994188223475 "
    s .= "77:0.578125:10013:10058 256:0.01818181818181818:10014:10047 247:0.578125:10015:10044 254:0.796875:10016:10029 128:-0.59375:10017:10020 151:0.84375:10018:10019 ~0.02140052842672325 ~-0.00833162851681169 "
    s .= "246:-1.640625:10021:10022 ~-0.03511645014069112 154:1.65625:10023:10026 114:0.2109375:10024:10025 ~0.007252952104880588 ~-0.020158056451745246 223:0.046875:10027:10028 ~-0.06050059988078287 ~0.007614505899102334 "
    s .= "11:0.546875:10030:10043 50:-0.203125:10031:10040 246:-0.609375:10032:10037 244:1.39:10033:10036 251:0.984375:10034:10035 ~-0.042041663995362695 ~-0.00012858424536214103 ~0.0044469503724556235 236:0.1875:10038:10039 "
    s .= "~0.016769431126765155 ~-0.0538402917806043 103:0.859375:10041:10042 ~-0.032430924798433534 ~0.0025106854651755148 ~0.05582284401708318 78:0.8046875:10045:10046 ~-0.06777220162597346 ~0.031622483825028684 "
    s .= "54:-0.1015625:10048:10051 250:1.1328125:10049:10050 ~-0.06228934488098369 ~0.010637694247777848 71:0.46875:10052:10055 245:1.1358024691358024:10053:10054 ~-0.028164191076875417 ~0.02858845519259409 "
    s .= "28:0.21875:10056:10057 ~-0.028749672524851246 ~0.03141540435286163 ~-0.015315195838736573 49:0.859375:10060:10103 220:1.15625:10061:10098 221:0.65625:10062:10097 208:0.890625:10063:10094 205:0.9375:10064:10093 "
    s .= "244:2.81:10065:10088 76:0.96875:10066:10087 64:0.625:10067:10074 110:-1.328125:10068:10071 30:-0.7421875:10069:10070 ~0.037284955213737106 ~-0.04756564100664573 154:0.609375:10072:10073 ~-0.006398229382143592 "
    s .= "~0.005533502436634621 211:0.53125:10075:10084 16:0.921875:10076:10083 82:1.859375:10077:10080 257:0.75:10078:10079 ~0.030338850527823716 ~-0.024768479583962173 250:1.2578125:10081:10082 ~-0.07597574842664663 "
    s .= "~0.05112477859722647 ~-0.04458589384090421 136:1.28125:10085:10086 ~-0.06647674312589207 ~0.023989436648517992 ~0.022082595928044416 189:-0.140625:10089:10092 214:1.109375:10090:10091 ~0.01450850254037508 "
    s .= "~-0.12117135923964202 ~-0.064230666546978 ~0.022676209157876978 190:0.71875:10095:10096 ~0.02738994325755056 ~-0.015540522744883876 ~-0.03161139825960071 127:0.40625:10099:10102 85:1.171875:10100:10101 "
    s .= "~-0.045004037004977966 ~0.0443039137682315 ~0.05469494083752024 137:-0.21875:10104:10105 ~-0.04713535190376498 ~-0.00040156741177002815 33:1.015625:10107:10152 8:0.96875:10108:10151 247:0.984375:10109:10150 "
    s .= "235:1.78125:10110:10149 50:0.71875:10111:10148 107:0.96875:10112:10145 192:0.921875:10113:10144 190:-0.015625:10114:10133 76:0.359375:10115:10132 52:-0.0625:10116:10123 211:-0.296875:10117:10118 ~-0.033664293658223286 "
    s .= "22:-0.03125:10119:10122 67:0.15625:10120:10121 ~0.025711828964112324 ~-0.03669659160569549 ~-0.017572787876081877 91:0.40625:10124:10129 133:0.09375:10125:10128 244:2.07:10126:10127 ~0.010721579975436074 "
    s .= "~-0.13397206084041877 ~-0.0373431563356906 166:0:10130:10131 ~-0.014363373383420825 ~0.03275819591251 ~0.01683405836981612 170:0.09375:10134:10137 44:0.484375:10135:10136 ~0.008084605636178403 ~-0.030968171604183754 "
    s .= "86:0.171875:10138:10141 244:0.755:10139:10140 ~0.10553273792939022 ~-0.024864052011596652 217:0.171875:10142:10143 ~0.013975523921578116 ~-0.027115889152074468 ~-0.05237357067312375 108:0.7421875:10146:10147 "
    s .= "~0.04631336408886169 ~-0.037106447529784675 ~-0.03366954337443967 ~-0.04433002480871079 ~-0.05868782525283383 ~0.037669787632360535 ~-0.052068724881807416 255:0.234375:10154:10179 255:0.109375:10155:10162 "
    s .= "245:1.3488372093023255:10156:10161 132:0.3203125:10157:10160 247:0.609375:10158:10159 ~-0.05130554889369791 ~0.017813372052266067 ~0.017809670381118234 ~0.0001851162061923596 219:0.140625:10163:10174 "
    s .= "236:0.25:10164:10173 246:0.296875:10165:10172 252:0.025:10166:10167 ~-0.03662534316488013 37:0.078125:10168:10171 187:0:10169:10170 ~-0.018684882872056576 ~0.038635340520098455 ~-0.026004885057059408 "
    s .= "~0.039654108412395174 ~-0.029372392156184087 109:1.28125:10175:10178 248:0.125:10176:10177 ~0.010112666451252512 ~0.04443023048875952 ~-0.02200191921607563 98:-0.421875:10180:10187 246:-0.453125:10181:10184 "
    s .= "111:0.0078125:10182:10183 ~0.004448140474511876 ~-0.045738671002202747 62:-0.421875:10185:10186 ~0.04334989080857937 ~-0.010374039626305606 254:0.828125:10188:10199 257:0.30985915492957744:10189:10196 "
    s .= "129:-0.0078125:10190:10193 244:0.99:10191:10192 ~-0.048578563266169696 ~0.01955807458185613 246:1.140625:10194:10195 ~-0.028769467132196067 ~0.02448853129661835 47:0.015625:10197:10198 ~-0.07092278559805128 "
    s .= "~0.022544396312642663 ~-0.03580234511476098 254:1.296875:10201:10238 122:-0.59375:10202:10209 44:-0.046875:10203:10208 137:-0.09375:10204:10207 143:-0.546875:10205:10206 ~0.01467108845949172 ~-0.01620605996551201 "
    s .= "~0.04329326914204709 ~-0.028471481456624054 246:0.015625:10210:10217 28:0:10211:10214 249:1.8333333333333335:10212:10213 ~0.0033480598762786447 ~-0.04807806270232226 19:0.46875:10215:10216 ~-0.022738856632442097 "
    s .= "~0.017407131678608845 128:0.015625:10218:10223 135:0.1328125:10219:10222 2:-0.125:10220:10221 ~0.0435897506367334 ~0.004708174179466068 ~-0.0017033394561056547 250:1.1171875:10224:10235 4:0.1875:10225:10234 "
    s .= "97:-0.109375:10226:10227 ~-0.03758966531945953 144:0.0625:10228:10229 ~-0.014368143542073455 170:0.28125:10230:10233 225:0.4453125:10231:10232 ~0.03928093813421974 ~-0.025755421905118064 ~-0.018322122465692408 "
    s .= "~-0.042867189163270966 12:0.578125:10236:10237 ~0.013240534878544747 ~-0.01564868511065499 244:1.32:10239:10244 23:-0.65625:10240:10243 158:-0.296875:10241:10242 ~-0.03491147723291841 ~0.03794476442056498 "
    s .= "~-0.05527765818083396 245:2.7625:10245:10246 ~0.01612379072912452 ~-0.033528083357094354 242:2.1500000000000004:10248:10291 252:1.775:10249:10288 243:1.45:10250:10287 245:2.2096774193548385:10251:10274 "
    s .= "61:1.28125:10252:10273 144:-0.46875:10253:10254 ~-0.022511314201092734 39:0.453125:10255:10268 148:1.5:10256:10267 154:0.671875:10257:10266 226:-0.015625:10258:10259 ~0.015754185149563203 64:-0.03125:10260:10263 "
    s .= "211:-0.34375:10261:10262 ~0.03484970706630107 ~-0.0361648296302991 225:-0.3359375:10264:10265 ~0.04201904932394519 ~-0.00031341299921162804 ~0.019441295948248602 ~-0.05136507672430232 123:0.4375:10269:10272 "
    s .= "252:0.275:10270:10271 ~-0.04265356988997574 ~0.012916118079593787 ~0.006378572684106395 ~0.027611243341581944 233:-0.640625:10275:10280 208:0:10276:10279 244:1.11:10277:10278 ~0.04309686447974437 ~-0.051518834761988756 "
    s .= "~0.02378694764079841 43:0.3125:10281:10286 130:1.4375:10282:10283 ~-0.011642168901224922 153:-0.4453125:10284:10285 ~0.024155690649786253 ~-0.05063531619650972 ~0.01731615331764327 ~-0.029058789481384618 "
    s .= "178:0.296875:10289:10290 ~0.041808715400489194 ~-0.005174129363609036 251:2.328125:10292:10293 ~-0.032830479867755495 ~0.036864318896577014 33:1.015625:10295:10340 8:0.96875:10296:10337 247:0.984375:10297:10336 "
    s .= "211:1.8125:10298:10335 208:0.890625:10299:10330 220:0.84375:10300:10325 233:0.6875:10301:10324 205:0.9375:10302:10321 246:-2.390625:10303:10308 9:-0.3671875:10304:10305 ~0.009736849485773094 90:-0.4609375:10306:10307 "
    s .= "~-0.006369405287326752 ~-0.06270745163380625 85:-0.46875:10309:10310 ~0.02990079718116828 252:0.375:10311:10314 242:1.35:10312:10313 ~-0.003189810955765136 ~-0.05966538115785722 253:-0.04248366013072058:10315:10318 "
    s .= "232:0.328125:10316:10317 ~0.031092998236480485 ~-0.02797142200693355 251:0.953125:10319:10320 ~-0.024859920023999775 ~0.013685733661570665 202:0.640625:10322:10323 ~0.03836276882828541 ~-0.01308069480013594 "
    s .= "~-0.04116888482181448 73:0.65625:10326:10329 103:0.15625:10327:10328 ~-0.004552018044650103 ~0.052592896300402404 ~-0.04308574406374077 244:1.605:10331:10334 36:0.171875:10332:10333 ~-0.026954811596114743 "
    s .= "~0.021747616330627915 ~0.03339734252788924 ~-0.04712194350757161 ~-0.05785972529378658 47:0.40625:10338:10339 ~0.06064096256951537 ~-0.02298736633696914 ~-0.05075585679398699 255:0.234375:10342:10365 "
    s .= "255:0.109375:10343:10354 245:1.3488372093023255:10344:10349 132:0.3203125:10345:10348 247:0.609375:10346:10347 ~-0.050791964680533964 ~0.01664566742611526 ~0.016450778898597213 236:0.375:10350:10353 "
    s .= "188:-0.296875:10351:10352 ~0.005724269564818269 ~-0.010214312322367042 ~0.016465218906929324 219:0.140625:10355:10362 212:0.34375:10356:10361 72:0.140625:10357:10360 249:0.16666666666666666:10358:10359 "
    s .= "~0.01412527630987234 ~-0.025578454690746384 ~0.03421529569959855 ~-0.039625644822908306 109:1.28125:10363:10364 ~0.032631780541436006 ~-0.020102714636637355 98:-0.5:10366:10377 254:0.546875:10367:10374 "
    s .= "153:0.1171875:10368:10373 183:-0.515625:10369:10372 155:-0.78125:10370:10371 ~0.033105310232014525 ~-0.06825206803012067 ~0.058416101191162466 ~-0.06457208370107574 257:0.5142857142857142:10375:10376 "
    s .= "~0.007179655002384335 ~-0.030480643056721442 85:1.28125:10378:10387 250:1.0078125:10379:10386 196:0.3125:10380:10381 ~-0.04362979385895444 82:0.3125:10382:10385 97:0.21875:10383:10384 ~-0.027965652406709802 "
    s .= "~0.08547671172390446 ~-0.042737283593847174 ~-0.009464539340375536 ~0.00353192946692937 49:0.859375:10389:10430 196:1.234375:10390:10429 208:0.890625:10391:10424 31:0.4375:10392:10419 252:0.42500000000000004:10393:10410 "
    s .= "242:1.45:10394:10409 205:0.625:10395:10404 127:1.421875:10396:10403 253:-0.010416666666667851:10397:10400 88:0.84375:10398:10399 ~-0.026970179663456974 ~0.016739926101358646 10:0.1875:10401:10402 ~-0.006276994925719684 "
    s .= "~0.01691033849934183 ~-0.040705625681073034 214:-0.15625:10405:10406 ~-0.06494893703904331 118:0.46875:10407:10408 ~0.035546691627710396 ~-0.024268592303002528 ~-0.0680876299398495 181:0.1875:10411:10414 "
    s .= "243:1.75:10412:10413 ~0.029672581404798417 ~-0.019145835947986106 251:1.171875:10415:10418 163:0.15625:10416:10417 ~0.004260580861369907 ~-0.036321556688409265 ~0.022731377014549498 184:0.59375:10420:10423 "
    s .= "77:0.5:10421:10422 ~0.028110173270450574 ~-0.04299256700864897 ~-0.019419208648697037 211:0.90625:10425:10428 70:-0.28125:10426:10427 ~-0.029803584465652705 ~0.034627006582500515 ~-0.011033975458900717 "
    s .= "~0.026047269106979562 137:-0.21875:10431:10432 ~-0.045409732411930165 251:2.140625:10433:10434 ~-0.01051664805365371 ~0.057896540244931106 219:0.984375:10436:10481 47:1.328125:10437:10480 11:0.796875:10438:10477 "
    s .= "77:0.578125:10439:10474 256:0.01818181818181818:10440:10457 247:0.484375:10441:10452 23:0.71875:10442:10451 146:0.109375:10443:10446 254:0.796875:10444:10445 ~0.006361596179239368 ~-0.005851412299944252 "
    s .= "86:0.140625:10447:10448 ~-0.027023265923586323 172:0.203125:10449:10450 ~0.007783518382301222 ~-0.03275755183372561 ~0.05276742416105266 70:0.0625:10453:10454 ~-0.07203495785429684 153:0.5546875:10455:10456 "
    s .= "~-0.04359793122811739 ~0.035127611560734295 198:-0.21875:10458:10459 ~-0.053445799852074295 14:0.609375:10460:10473 251:0.859375:10461:10470 4:1.09375:10462:10469 247:0.390625:10463:10464 ~0.024654893664062684 "
    s .= "12:0.328125:10465:10466 ~-0.04956643268597598 180:0.109375:10467:10468 ~0.06805578795983984 ~-0.017974970527754583 ~0.07792895263710953 243:1.95:10471:10472 ~0.032168502563278946 ~-0.01877377931899471 "
    s .= "~-0.04108574159410268 252:0.375:10475:10476 ~-0.04606773853652956 ~0.0028167116354652685 107:0.75:10478:10479 ~0.04792988324068439 ~-0.0320496504789678 ~-0.056688326349514866 ~-0.04633578344305977 "
    s .= "15:-1.0078125:10483:10484 ~0.043720133863664745 124:2.046875:10485:10526 110:-1.265625:10486:10493 90:-0.3359375:10487:10488 ~-0.0011980321404553673 146:-1.421875:10489:10490 ~0.03191573892810325 "
    s .= "234:-0.171875:10491:10492 ~-0.022066019499445585 ~-0.09113869514908814 98:-1.046875:10494:10497 143:-0.546875:10495:10496 ~0.03206816870130735 ~-0.03264651240297794 255:0.265625:10498:10509 255:0.109375:10499:10500 "
    s .= "~-0.0017445795660286417 219:0.140625:10501:10508 236:0.25:10502:10507 246:0.296875:10503:10506 252:0.175:10504:10505 ~-0.017441243765008153 ~0.020408907536367715 ~0.03676677661883553 ~-0.02718000152631081 "
    s .= "~0.024156550381335434 74:-0.328125:10510:10521 246:-0.390625:10511:10518 105:-0.5859375:10512:10513 ~0.04268685008630263 28:0.046875:10514:10515 ~0.00008328360280419498 151:0.3125:10516:10517 ~-0.06028210062925902 "
    s .= "~-0.009001021721846759 121:-0.25:10519:10520 ~-0.046111165740249566 ~0.025516225133689164 106:1.3125:10522:10525 11:0.609375:10523:10524 ~-0.03170345967349935 ~0.0351401626163694 ~0.007771249484458663 6:0.25:10527:10528 "
    s .= "~-0.06895802985114151 ~0.03165321610563417 101:0.5625:10530:10573 256:0.01818181818181818:10531:10562 39:0.4375:10532:10559 11:0.59375:10533:10558 247:0.234375:10534:10553 124:0.828125:10535:10550 2:0.046875:10536:10549 "
    s .= "184:0.03125:10537:10540 90:0.0859375:10538:10539 ~0.00027368414306784994 ~-0.03685644438643034 246:-0.234375:10541:10548 244:1.405:10542:10547 122:-0.75:10543:10544 ~0.014735293465576067 160:0.09375:10545:10546 "
    s .= "~0.020261436909158874 ~-0.028408568689997568 ~0.01709056804344563 ~0.02570653416056809 ~-0.008509043904348578 230:-0.203125:10551:10552 ~-0.0020027685371927814 ~-0.038470680334983014 239:0.375:10554:10557 "
    s .= "192:0.34375:10555:10556 ~-0.04992351231370645 ~-0.00556429090354767 ~0.023785924176929978 ~0.03782942479654764 168:0.109375:10560:10561 ~-0.040129929475213634 ~-0.0013376814098562517 237:-0.234375:10563:10564 "
    s .= "~-0.04656336836366812 245:1.1142857142857143:10565:10566 ~-0.0318538740748549 47:0.453125:10567:10570 20:0.53125:10568:10569 ~0.026326313436690365 ~-0.06058629599215825 46:0.015625:10571:10572 ~0.02217809493533801 "
    s .= "~-0.03973600426697217 252:0.175:10574:10575 ~-0.03756500010849805 ~-0.00026607704274457603 111:-0.5703125:10577:10584 47:-0.578125:10578:10581 232:0:10579:10580 ~-0.028250164672972297 ~0.014073995423155811 "
    s .= "244:1.545:10582:10583 ~-0.060328318135497494 ~0.00192195797226297 57:-0.6171875:10585:10586 ~0.031509386049196675 24:-0.9375:10587:10588 ~0.05451808275013307 245:4:10589:10622 205:-0.5:10590:10591 ~-0.032504983310915926 "
    s .= "107:-1.359375:10592:10593 ~-0.042627622140866774 146:-0.234375:10594:10595 ~0.006406939612259247 246:0.140625:10596:10615 242:0.55:10597:10606 245:1.5806451612903225:10598:10599 ~0.03240803410677367 "
    s .= "188:0.0625:10600:10605 110:-0.15625:10601:10602 ~-0.022257388721725613 109:0.5625:10603:10604 ~-0.03357393168033523 ~0.039469990121375115 ~-0.04764185838927551 252:0.42500000000000004:10607:10612 52:-0.0625:10608:10609 "
    s .= "~-0.004750843737912116 8:0.40625:10610:10611 ~-0.056034707678581944 ~0.034366593481070115 253:-0.0360576923076934:10613:10614 ~0.021217140897633394 ~-0.03290552363203874 137:0.265625:10616:10619 119:0.234375:10617:10618 "
    s .= "~0.020159953344794923 ~-0.013952625849394688 120:0.484375:10620:10621 ~0.0006832663567497817 ~-0.027692673508469875 ~-0.05678269464882146 171:0.984375:10624:10669 195:-0.421875:10625:10630 23:-0.046875:10626:10629 "
    s .= "4:0.265625:10627:10628 ~0.007609100699219506 ~-0.041734532744231286 ~-0.051556225715440135 57:-0.6328125:10631:10634 46:0.328125:10632:10633 ~0.04368419280713922 ~-0.04357574732052691 257:0.4166666666666667:10635:10656 "
    s .= "257:0.022222222222222223:10636:10655 22:-0.234375:10637:10640 207:0.515625:10638:10639 ~-0.026484596703785585 ~0.017140274377214288 245:3.406779661016949:10641:10654 255:-0.046875:10642:10643 ~-0.047209607763224436 "
    s .= "252:0.375:10644:10649 243:1.15:10645:10648 179:0.703125:10646:10647 ~0.0023848714111314806 ~-0.04924521704432437 ~-0.056233611827449154 19:0.5625:10650:10653 253:-0.04248366013072058:10651:10652 ~0.03316682672690574 "
    s .= "~0.004934036620239546 ~-0.04906025091928919 ~-0.04407086550106576 ~0.013730006476425442 255:-0.109375:10657:10658 ~0.05453771912006231 189:-0.21875:10659:10666 238:1.0625:10660:10665 72:-0.21875:10661:10664 "
    s .= "188:-1.078125:10662:10663 ~0.026961414063034275 ~-0.041765256151048244 ~0.02447993748534163 ~-0.07508369104566132 130:0.28125:10667:10668 ~0.007426868891994238 ~-0.03915858985607008 ~-0.04466137554809079 "
    s .= "106:0.015625:10671:10682 245:1.8072289156626506:10672:10673 ~0.006626604185597432 252:0.32499999999999996:10674:10681 28:-0.0625:10675:10680 1:0.171875:10676:10679 165:0.171875:10677:10678 ~-0.037412666936847146 "
    s .= "~0.022199054401628723 ~0.07313049246172973 ~-0.04603765970640178 ~0.028822685315897857 58:0.15625:10683:10694 106:1.75:10684:10689 96:0.8359375:10685:10688 243:1.75:10686:10687 ~0.010258920213904645 "
    s .= "~-0.028763861498218316 ~-0.04925724573499595 223:0.046875:10690:10693 245:1.4230769230769231:10691:10692 ~-0.16128440916565148 ~-0.03468973451147855 ~0.010767842297800208 151:0:10695:10702 226:-0.03125:10696:10699 "
    s .= "241:0.42:10697:10698 ~0.04784882029720502 ~0.005060116394178904 241:0.26:10700:10701 ~-0.036546318441470015 ~0.011629999858737196 88:1.359375:10703:10716 79:1.640625:10704:10715 166:1.046875:10705:10714 "
    s .= "157:0.140625:10706:10707 ~0.004480983803295628 172:0.34375:10708:10711 235:-0.171875:10709:10710 ~-0.06584394914527077 ~-0.02417210597023548 55:0.3125:10712:10713 ~0.014568592197391565 ~-0.028618397369661947 "
    s .= "~0.023914745646736676 ~0.028120071946985493 ~0.020252596817191777 253:-0.09898989898990054:10718:10739 252:0.125:10719:10728 51:-0.1796875:10720:10721 ~-0.06578716613776915 70:0.0625:10722:10723 ~0.014217834638850319 "
    s .= "122:-0.625:10724:10725 ~0.034224267117209745 249:0.16666666666666666:10726:10727 ~0.013179816967213116 ~-0.05971823356716327 46:-0.265625:10729:10734 103:0.234375:10730:10731 ~0.026536003234046663 "
    s .= "67:-0.09375:10732:10733 ~-0.07645567695426295 ~0.011420016734918104 257:0.8482142857142857:10735:10738 244:0.91:10736:10737 ~-0.008921074018858523 ~0.0336214061193256 ~-0.04262302601790138 246:-2.390625:10740:10745 "
    s .= "215:-0.6875:10741:10744 186:-0.03125:10742:10743 ~0.008448171418765702 ~-0.038171724949144906 ~-0.04560385868603977 205:-0.5:10746:10747 ~-0.036041435810258905 61:-0.28125:10748:10761 37:0.28125:10749:10760 "
    s .= "111:-0.1953125:10750:10757 226:-0.265625:10751:10754 223:-0.234375:10752:10753 ~0.027057460050692636 ~0.1616230927025628 244:1.1:10755:10756 ~-0.052378921288912805 ~0.035409465393859564 217:0:10758:10759 "
    s .= "~-0.0438164285390137 ~0.015777169976708263 ~0.06256583138399104 148:-0.015625:10762:10763 ~0.005400946620906572 ~-0.004278315042907677 254:1.296875:10765:10798 144:-0.828125:10766:10767 ~-0.02950836375791376 "
    s .= "170:-1.15625:10768:10769 ~0.024409198250284106 246:-2.296875:10770:10775 56:-1.4375:10771:10772 ~0.03677986015416951 192:-0.296875:10773:10774 ~-0.0017048856499573186 ~-0.048932091570862035 "
    s .= "257:0.9090909090909091:10776:10795 188:-0.453125:10777:10778 ~0.012302576739257226 246:-0.578125:10779:10788 128:-0.484375:10780:10783 217:0.234375:10781:10782 ~0.02571422762978469 ~-0.03880513732359966 "
    s .= "90:-0.2421875:10784:10785 ~0.0047442315221630236 245:1.4363636363636363:10786:10787 ~0.028734156753233542 ~-0.04407369407945096 186:-0.03125:10789:10792 174:0.25:10790:10791 ~0.0179277251840062 ~-0.03045215573181266 "
    s .= "165:0.0625:10793:10794 ~-0.012736010646733784 ~0.002821546439792228 109:0.765625:10796:10797 ~-0.043989546512249844 ~0.011842774103056872 244:1.32:10799:10806 23:-0.65625:10800:10805 158:-0.296875:10801:10804 "
    s .= "240:-0.65625:10802:10803 ~0.043744318358053556 ~-0.04843666939262399 ~0.0362517292253261 ~-0.05389224359262297 245:2.7625:10807:10810 48:-0.2890625:10808:10809 ~-0.02873688303886377 ~0.02864064904071162 "
    s .= "~-0.030795776212376225 247:0.765625:10812:10853 235:1.78125:10813:10852 33:0.921875:10814:10851 89:1.03125:10815:10850 226:0.875:10816:10843 251:0.234375:10817:10822 208:0.015625:10818:10819 ~-0.03409569124604629 "
    s .= "43:0.234375:10820:10821 ~0.0037766551922203424 ~-0.05112414490719868 255:0.265625:10823:10834 255:0.109375:10824:10831 245:1.3768115942028984:10825:10830 13:0.84375:10826:10829 247:0.671875:10827:10828 "
    s .= "~-0.04553937028518553 ~0.02798538824928001 ~0.10129397191183345 ~0.0031889685023144044 252:0.175:10832:10833 ~0.0055255907985223476 ~0.030846000339191333 80:-0.609375:10835:10836 ~0.007231724329841243 "
    s .= "250:1.1953125:10837:10842 247:0.140625:10838:10841 245:1.8421052631578947:10839:10840 ~-0.0465679618982833 ~-0.004045092497712536 ~-0.05359218064352494 ~0.004103318519176202 34:0.328125:10844:10849 "
    s .= "157:-0.046875:10845:10846 ~-0.03589119619848338 49:0.453125:10847:10848 ~0.04055233513560044 ~-0.08052196856088789 ~-0.03410310414542511 ~0.03441719285326832 ~-0.03757566051760463 ~-0.04054803430324185 "
    s .= "237:0.578125:10854:10855 ~-0.04511663169170913 256:0.14285714285714285:10856:10857 ~-0.05827017111984165 ~0.04112857600799706 106:0.015625:10859:10878 245:1.8225806451612903:10860:10867 67:-0.25:10861:10864 "
    s .= "37:0.671875:10862:10863 ~-0.04906599081269955 ~0.10361087478391694 243:1.35:10865:10866 ~0.018686201884157233 ~-0.029078330658824692 252:0.32499999999999996:10868:10877 28:-0.0625:10869:10874 1:0.171875:10870:10873 "
    s .= "165:0.171875:10871:10872 ~-0.03663443604353244 ~0.021480503212810653 ~0.07069439706064777 58:0.34375:10875:10876 ~-0.05508477871501725 ~0.008357463325637634 ~0.02820160184936146 58:0.109375:10879:10886 "
    s .= "106:1.75:10880:10881 ~0.00814798520090541 223:0.046875:10882:10885 245:1.4230769230769231:10883:10884 ~-0.1445526626478697 ~-0.029344140699416345 ~0.011667934956027427 223:0.59375:10887:10904 88:1.328125:10888:10903 "
    s .= "160:0.125:10889:10892 160:-0.21875:10890:10891 ~-0.025217416645998317 ~0.017127399029200473 151:-0.265625:10893:10894 ~0.027512593649240653 244:1.48:10895:10900 220:0.296875:10896:10899 255:0.328125:10897:10898 "
    s .= "~-0.018228966699102907 ~-0.05636926645871666 ~0.00391780538312383 250:0.9921875:10901:10902 ~-0.016519247957998612 ~0.026395085933076348 ~0.02119389629293717 ~-0.035340918071226336 242:2.1500000000000004:10906:10951 "
    s .= "252:1.775:10907:10948 243:1.35:10908:10947 245:2.2096774193548385:10909:10934 39:0.453125:10910:10929 169:-0.484375:10911:10912 ~-0.05822262231358491 226:-0.1875:10913:10918 142:0.625:10914:10917 211:-0.375:10915:10916 "
    s .= "~-0.03383228409479766 ~0.04047366859809381 ~-0.05162649013898551 248:1.375:10919:10928 255:0.234375:10920:10921 ~0.00992473916840728 210:-0.03125:10922:10927 246:-0.984375:10923:10924 ~-0.012609103870395589 "
    s .= "122:-0.453125:10925:10926 ~0.056016778620087776 ~0.0010857739754764537 ~-0.02593821383532747 ~-0.03387537780758667 123:0.4375:10930:10933 252:0.125:10931:10932 ~-0.04506323246822766 ~0.005491674392621118 "
    s .= "~0.006074908374745195 191:0:10935:10944 232:0:10936:10941 40:0.078125:10937:10940 202:0.015625:10938:10939 ~-0.0642406767677006 ~-0.006114605794341175 ~0.009268630513414358 1:-0.234375:10942:10943 ~0.042120525190569164 "
    s .= "~-0.00042524128870340025 43:0.234375:10945:10946 ~-0.039509084852340004 ~0.014220475909765438 ~-0.02425768903575451 178:0.296875:10949:10950 ~0.039869546828035 ~-0.0042273724306969105 ~-0.019264428428477594 "
    s .= "196:1.234375:10953:10994 170:0.6875:10954:10993 8:0.796875:10955:10990 247:0.796875:10956:10985 246:1.484375:10957:10982 25:1.125:10958:10979 31:0.4375:10959:10974 208:0.890625:10960:10973 205:0.625:10961:10966 "
    s .= "252:0.42500000000000004:10962:10963 ~-0.00838784695035196 253:-0.04248366013072058:10964:10965 ~0.022921164330723203 ~-0.00861318362486843 28:-0.375:10967:10968 ~-0.04305206460650118 202:0.59375:10969:10972 "
    s .= "73:0.140625:10970:10971 ~0.04607524652259848 ~-0.03824073882152625 ~-0.007433026269551115 ~0.016595311141127535 184:0.59375:10975:10978 193:-0.125:10976:10977 ~0.057641231525307896 ~0.01392699657177895 "
    s .= "~-0.014953587770285125 214:0.296875:10980:10981 ~-0.011923997643931247 ~-0.08777295577735007 7:-0.046875:10983:10984 ~-0.014517846221707327 ~0.03494522687527185 123:0.65625:10986:10987 ~-0.06255946126252175 "
    s .= "134:0.640625:10988:10989 ~-0.05472511922538945 ~0.05299422278059573 107:0.75:10991:10992 ~0.04471301701880398 ~-0.033545054784144025 ~-0.032502324469917056 175:0.0625:10995:10996 ~-0.033119638797560635 "
    s .= "103:1.3125:10997:10998 ~0.04249365047383381 ~-0.02236050880964532 41:0.546875:11000:11041 8:0.875:11001:11040 89:0.78125:11002:11037 34:0.046875:11003:11020 109:0.078125:11004:11011 166:-0.0625:11005:11010 "
    s .= "124:0.453125:11006:11007 ~-0.005868142996675302 251:0.296875:11008:11009 ~0.17749667710703002 ~0.024689538770707252 ~-0.028149438323957263 39:0.421875:11012:11017 10:0.078125:11013:11014 ~0.005751463380151491 "
    s .= "85:0.203125:11015:11016 ~0.0468443718408344 ~0.003965238589437435 168:0.21875:11018:11019 ~-0.03865019575593605 ~0.010369753151482487 190:-0.015625:11021:11026 76:0.375:11022:11025 91:0.875:11023:11024 "
    s .= "~-0.034363901472385876 ~0.0073056892197237225 ~0.010546174433026849 19:0.765625:11027:11034 211:0.125:11028:11029 ~0.006520555989364464 244:1.465:11030:11031 ~-0.022267681526943816 244:2.405:11032:11033 "
    s .= "~0.020607263030229278 ~-0.030111491787336044 64:0.75:11035:11036 ~0.05268419711605552 ~-0.029665345528784883 112:1.140625:11038:11039 ~0.03415760244757854 ~-0.05293803996105907 ~0.04798588768152664 "
    s .= "107:0.46875:11042:11045 1:-0.140625:11043:11044 ~-0.05193596716612148 ~0.0267584474179485 ~-0.03384322494085815 166:2.03125:11047:11092 205:1.1875:11048:11085 246:-2.015625:11049:11052 212:-0.609375:11050:11051 "
    s .= "~-0.0029297578272745317 ~-0.03402516861305932 56:-0.8125:11053:11058 143:-0.546875:11054:11055 ~0.028683519269400146 2:-0.890625:11056:11057 ~-0.03972067140467137 ~0.01960115530430399 228:-0.453125:11059:11060 "
    s .= "~-0.03447928699571517 108:-0.3359375:11061:11064 169:0.171875:11062:11063 ~0.033227550772022905 ~-0.017490933092549465 68:-0.6875:11065:11068 149:-0.96875:11066:11067 ~0.0651595829054007 ~-0.02890198184668405 "
    s .= "190:-0.109375:11069:11080 8:0.4375:11070:11077 202:0.484375:11071:11074 239:0.234375:11072:11073 ~-0.03033305203603831 ~0.0005825207364458053 209:0.15625:11075:11076 ~0.0397976566856638 ~-0.0403251787883422 "
    s .= "80:0.671875:11078:11079 ~0.03051044863161866 ~-0.041726123927309934 130:2.21875:11081:11084 154:0.609375:11082:11083 ~-0.0001854444116268405 ~0.01219942161403913 ~-0.04187368042127627 238:1.59375:11086:11091 "
    s .= "31:-0.375:11087:11088 ~-0.037142562873556516 73:0.84375:11089:11090 ~0.03263504256974798 ~-0.04331601687990467 ~-0.04684472299801187 ~-0.04047716108435574 47:1.328125:11094:11139 254:0.984375:11095:11116 "
    s .= "85:-0.46875:11096:11101 58:0.359375:11097:11100 175:-0.296875:11098:11099 ~-0.04142275762419957 ~0.046654326204120355 ~-0.04554115118866672 245:1.0266666666666666:11102:11103 ~-0.040784973687860854 "
    s .= "109:1.703125:11104:11107 109:1.1875:11105:11106 ~-0.000021717305410544093 ~0.013068877949043649 208:0.015625:11108:11111 245:1.4303797468354431:11109:11110 ~-0.15717296720582566 ~-0.02566963143706253 1:0:11112:11113 "
    s .= "~0.022529206460848612 199:0.3125:11114:11115 ~-0.029676151810671094 ~0.028965482949860823 26:-0.140625:11117:11134 158:-0.1875:11118:11129 244:1.225:11119:11124 140:-0.140625:11120:11123 26:-1.21875:11121:11122 "
    s .= "~0.009544680708843387 ~-0.0511189534261674 ~0.022269072026803748 51:-0.2734375:11125:11128 55:-0.09375:11126:11127 ~-0.08268118019292164 ~-0.008571181716333314 ~0.0102417669488132 73:-0.1875:11130:11131 "
    s .= "~-0.029632867594627656 122:-0.203125:11132:11133 ~0.03599552167159035 ~-0.008428956554552738 245:1.9736842105263157:11135:11138 221:0.171875:11136:11137 ~-0.03086638284235778 ~0.021973397334382874 ~-0.054154794639661656 "
    s .= "~-0.05540315369136256 219:0.984375:11141:11186 220:0.84375:11142:11179 218:0.65625:11143:11178 220:0.65625:11144:11177 208:0.890625:11145:11174 205:0.9375:11146:11173 109:1.703125:11147:11162 130:0.15625:11148:11151 "
    s .= "44:0.453125:11149:11150 ~0.012826387650075042 ~-0.019408136375022755 31:1.5:11152:11161 103:1.328125:11153:11160 159:-0.4140625:11154:11155 ~-0.026649372499407378 255:0.265625:11156:11157 ~0.000607497882487509 "
    s .= "145:0.671875:11158:11159 ~-0.018612377280319583 ~0.036062377549795216 ~0.018124636816862643 ~0.0466404346355587 181:0.03125:11163:11166 242:1.05:11164:11165 ~-0.06593753748338428 ~0.021559132629475678 "
    s .= "181:1.46875:11167:11172 157:0.53125:11168:11171 154:0.140625:11169:11170 ~-0.06656265636841277 ~0.006871008361229518 ~0.02461600504196569 ~-0.03877746969425558 ~0.02047400613402156 211:0.90625:11175:11176 "
    s .= "~0.028163716060475782 ~-0.008007234606120987 ~-0.033269620677264376 ~-0.03393989245571128 187:0.78125:11180:11185 232:-0.21875:11181:11182 ~-0.0347046280085442 90:0.3203125:11183:11184 ~0.04127302559022765 "
    s .= "~-0.02755548347086209 ~-0.04127654533047746 ~-0.04508713507587958 155:-1.734375:11188:11189 ~0.030544296298172915 246:-2.390625:11190:11195 233:-0.65625:11191:11194 254:0.984375:11192:11193 ~0.00421842783238429 "
    s .= "~-0.04052187722393141 ~-0.0480567055118313 53:-0.765625:11196:11199 143:-0.546875:11197:11198 ~0.02225530569101268 ~-0.00665382790349605 231:-0.46875:11200:11201 ~-0.029422412497755363 165:-0.5625:11202:11203 "
    s .= "~0.05264220999762185 257:0.9090909090909091:11204:11233 250:1.1171875:11205:11226 247:0.421875:11206:11221 217:-0.125:11207:11210 251:1.578125:11208:11209 ~-0.033480354629080306 ~0.02558124327783289 "
    s .= "217:0.140625:11211:11216 31:-0.21875:11212:11213 ~0.04355253347585663 195:0.484375:11214:11215 ~0.007614362803839963 ~-0.05784419860879009 226:0.9375:11217:11220 48:0.2109375:11218:11219 ~-0.02648665394098071 "
    s .= "~0.010686901347127426 ~0.046666161625051 127:-0.15625:11222:11223 ~0.024678683781303723 224:0.125:11224:11225 ~-0.056939328606998046 ~-0.009735406389544695 58:0.515625:11227:11232 64:1.0625:11228:11231 "
    s .= "245:2.1616161616161618:11229:11230 ~0.002701569260019941 ~-0.027139343050727384 ~0.03528682854551459 ~0.021184396454132056 ~-0.030272807155578653 33:1.015625:11235:11280 5:-1.484375:11236:11237 ~0.02590467147687396 "
    s .= "246:-2.015625:11238:11253 244:1.505:11239:11248 218:-0.59375:11240:11247 245:1.7721518987341771:11241:11242 ~-0.04895212027769916 52:0.078125:11243:11246 208:0.015625:11244:11245 ~-0.04740841611736981 "
    s .= "~0.003940749007209382 ~0.022579891528342513 ~-0.05499181087481539 190:0.03125:11249:11252 153:-0.4921875:11250:11251 ~0.021349315329576103 ~-0.05010215107293196 ~0.02353529406917934 44:-0.75:11254:11261 "
    s .= "25:0.578125:11255:11260 122:-0.5625:11256:11257 ~0.03204630901469262 73:0.0625:11258:11259 ~0.016942003602993565 ~-0.041593673854192825 ~-0.058522561521619 231:-0.46875:11262:11263 ~-0.03546249839771919 "
    s .= "105:-0.3984375:11264:11265 ~0.025943310710812264 255:0.234375:11266:11279 255:0.109375:11267:11268 ~-0.002171514556891787 244:0.96:11269:11272 114:-0.0078125:11270:11271 ~-0.020329736476744478 ~0.04339885036675386 "
    s .= "194:0.140625:11273:11278 24:0.125:11274:11277 112:0.703125:11275:11276 ~-0.01987600945058638 ~0.02123852249495896 ~0.03292718244915648 ~-0.02023732015541657 ~-0.009128495991901665 ~-0.04890180253300274 "
    s .= "251:0.515625:11282:11323 241:0.3:11283:11314 168:0.140625:11284:11309 245:1.9175257731958764:11285:11298 247:0.515625:11286:11297 94:0.109375:11287:11296 249:0.8333333333333333:11288:11295 196:-0.09375:11289:11290 "
    s .= "~0.05462560358524185 139:0.390625:11291:11294 109:0.734375:11292:11293 ~-0.039183924553797926 ~0.025208658783322926 ~0.03459749381662771 ~-0.04584938933540376 ~-0.016704196076041827 ~0.0926160368672615 "
    s .= "202:0.84375:11299:11306 143:-0.515625:11300:11303 246:-2.640625:11301:11302 ~-0.03690067696202254 ~0.029768078997047982 117:0.015625:11304:11305 ~-0.04956761438347518 ~-0.004411688904478271 190:0.0625:11307:11308 "
    s .= "~-0.03790324323368621 ~0.05654859746954312 55:-0.359375:11310:11311 ~0.03551716109635938 70:0.484375:11312:11313 ~-0.0257403490760343 ~0.026436627081654285 136:0.96875:11315:11322 112:0.59375:11316:11317 "
    s .= "~-0.020335333650838262 163:0.515625:11318:11321 205:-0.125:11319:11320 ~-0.0430573645132332 ~0.0398069001966993 ~-0.03232333432880033 ~-0.030281623973251556 238:0.59375:11324:11327 79:0.375:11325:11326 "
    s .= "~0.0002222580520921133 ~0.011764362912117854 ~-0.016351309503018017 47:1.328125:11329:11374 251:0.515625:11330:11351 220:-0.296875:11331:11332 ~-0.037337049993695456 169:1.453125:11333:11350 208:0.40625:11334:11339 "
    s .= "188:0.328125:11335:11338 82:1.8125:11336:11337 ~-0.0031920674966766874 ~-0.049044222586837785 ~-0.034496666296793266 33:-0.171875:11340:11341 ~-0.03550931075622881 248:1.125:11342:11349 243:0.25:11343:11344 "
    s .= "~0.05299302796044491 196:0.234375:11345:11348 237:0.328125:11346:11347 ~0.02896712629943698 ~-0.03642537030976816 ~-0.02742087364715148 ~-0.04758541231272681 ~0.05029416329894665 249:0.16666666666666666:11352:11353 "
    s .= "~0.009185056340972442 121:-0.09375:11354:11359 118:-0.3125:11355:11356 ~0.023227477869231128 55:-0.15625:11357:11358 ~-0.04930421077394457 ~-0.012236178014663595 244:2.81:11360:11373 142:-0.0625:11361:11368 "
    s .= "99:0.21875:11362:11363 ~-0.029635110938112715 55:0.421875:11364:11367 120:0.1875:11365:11366 ~-0.04267841005175363 ~0.022691571617549214 ~0.05956358297909751 34:-0.515625:11369:11370 ~0.05414791562070323 "
    s .= "224:0.5625:11371:11372 ~0.00941219712070375 ~-0.03078913575886265 ~-0.04947642252202536 ~-0.05450750904249523 253:-0.09898989898990054:11376:11401 252:0.125:11377:11392 51:-0.1796875:11378:11381 "
    s .= "250:1.0703125:11379:11380 ~-0.0989745470888274 ~-0.010759897334561043 149:-0.171875:11382:11385 141:0.0390625:11383:11384 ~-0.00868435069606812 ~0.04028100758797527 249:0.16666666666666666:11386:11389 "
    s .= "211:-0.046875:11387:11388 ~-0.03932423066890923 ~0.03395448083474591 217:0.390625:11390:11391 ~-0.05612264436647886 ~0.045934943158948666 46:-0.265625:11393:11398 103:0.234375:11394:11395 ~0.025808976523306715 "
    s .= "67:-0.09375:11396:11397 ~-0.07245811554085607 ~0.011703528110341409 245:1.4:11399:11400 ~-0.019478848518292766 ~0.029049713236125457 30:0.4296875:11402:11409 115:1.65625:11403:11406 91:2.078125:11404:11405 "
    s .= "~0.001616639887454743 ~-0.06813332247975344 91:0.046875:11407:11408 ~-0.05457282712547748 ~-0.00745951514426316 251:0.578125:11410:11415 172:0.140625:11411:11412 ~-0.04826062330193237 78:0.6796875:11413:11414 "
    s .= "~-0.030955044154948336 ~0.03976321983615985 191:-0.28125:11416:11417 ~0.022028717130323904 132:0.1484375:11418:11419 ~-0.03120627019537361 112:0.671875:11420:11421 ~-0.013918544749066748 ~0.026682139782736793 "
    s .= "219:0.984375:11423:11468 25:1.125:11424:11461 79:0.765625:11425:11454 64:0.9375:11426:11453 154:0.609375:11427:11446 226:-0.109375:11428:11433 148:0.125:11429:11432 187:-0.375:11430:11431 ~-0.045316813545207356 "
    s .= "~0.021339625736774063 ~-0.02067488076975347 178:0.578125:11434:11445 130:0.15625:11435:11436 ~-0.0005385543169445954 166:0.8125:11437:11444 238:-0.46875:11438:11439 ~0.04620476338983903 184:1.09375:11440:11443 "
    s .= "37:-0.34375:11441:11442 ~0.013816497208992216 ~-0.028441936832645672 ~0.028098762846408876 ~0.028986432676241167 ~0.018804136154583297 223:0:11447:11448 ~-0.010830462300616203 208:-0.234375:11449:11450 "
    s .= "~-0.053160086844718485 127:0.953125:11451:11452 ~0.023543506353932295 ~-0.007305175109899288 ~0.01786965720003208 151:0.0625:11455:11456 ~0.02579694776863974 70:0.640625:11457:11460 214:0.03125:11458:11459 "
    s .= "~-0.02012379359895526 ~0.013993256447512911 ~-0.05685735975436096 214:0.296875:11462:11467 115:0.3125:11463:11466 166:0.03125:11464:11465 ~-0.022543104964756006 ~0.03348703862146588 ~-0.05512642242156847 "
    s .= "~-0.07930415376287736 ~-0.04413155762122056 242:2.05:11470:11511 252:1.6749999999999998:11471:11506 243:1.45:11472:11505 245:2.2096774193548385:11473:11484 145:-0.46875:11474:11475 ~-0.04524890214196135 "
    s .= "61:1.28125:11476:11483 144:-0.46875:11477:11478 ~-0.01935617502441995 79:1.265625:11479:11482 1:0.046875:11480:11481 ~-0.0034538527122980945 ~0.00959420728534397 ~0.02704913184444307 ~0.02601421004099553 "
    s .= "82:0.4375:11485:11500 169:0.6875:11486:11497 202:0.34375:11487:11496 181:0.234375:11488:11495 244:1.115:11489:11490 ~0.011509612311796586 16:0.15625:11491:11492 ~-0.050299939844825184 76:0.078125:11493:11494 "
    s .= "~0.03854688510953268 ~-0.03783864769102663 ~0.011749665462427934 ~0.026706396627399154 234:-0.140625:11498:11499 ~-0.048431354800981055 ~0.06935997576957913 181:0.71875:11501:11502 ~-0.0035683596942353147 "
    s .= "199:1.15625:11503:11504 ~-0.05718990668693337 ~0.02033937566886717 ~-0.027700812492954405 178:0.296875:11507:11508 ~0.0391997268735634 75:0.1484375:11509:11510 ~-0.02775465524494496 ~0.03348373126656407 "
    s .= "251:2.328125:11512:11515 245:2.419753086419753:11513:11514 ~-0.04437120673105718 ~0.01755105236971913 ~0.03658122106374075 247:0.765625:11517:11560 107:0.96875:11518:11559 192:0.984375:11519:11558 97:1.75:11520:11557 "
    s .= "169:1.703125:11521:11554 248:1.125:11522:11543 233:0.78125:11523:11542 88:1.28125:11524:11537 103:1.328125:11525:11536 148:0.0625:11526:11531 238:-0.171875:11527:11528 ~0.02487134635396891 193:0.125:11529:11530 "
    s .= "~0.0030386595797748336 ~-0.02681355375007845 166:-0.125:11532:11535 121:0.421875:11533:11534 ~-0.044750604484823424 ~0.018216853908325968 ~-0.0042170120986921 ~0.015417428844773982 193:0:11538:11541 "
    s .= "30:0.1640625:11539:11540 ~-0.024468779217598068 ~0.029788622585657554 ~0.02683121377052601 ~-0.04709846226772847 238:1.15625:11544:11551 34:-0.09375:11545:11550 20:-0.140625:11546:11549 91:-0.078125:11547:11548 "
    s .= "~-0.035626085590401035 ~0.07081854043455493 ~-0.042307288574365526 ~-0.03556272723756038 130:0.59375:11552:11553 ~0.10056383105411591 ~-0.043944674925861106 202:0.25:11555:11556 ~0.05613831413005708 "
    s .= "~-0.04600776957641008 ~-0.03747254010037212 ~-0.051671994978289164 ~0.029192548026792532 237:0.578125:11561:11562 ~-0.042377395524685224 ~0.01848468520367886 166:2.15625:11564:11609 79:-0.125:11565:11578 "
    s .= "157:1.140625:11566:11577 97:-0.078125:11567:11576 102:-0.1171875:11568:11569 ~-0.036604919061065715 107:-0.234375:11570:11571 ~0.028132406058733624 99:0.25:11572:11575 34:0.765625:11573:11574 ~-0.045822554785673965 "
    s .= "~0.05065965857802229 ~0.016155618801269197 ~0.01615140044015035 ~0.02738204295728593 237:0.484375:11579:11604 110:0.03125:11580:11589 125:-0.609375:11581:11582 ~0.005900977819399758 59:0.125:11583:11584 "
    s .= "~-0.013069582859705718 23:0.109375:11585:11586 ~0.05017289169158601 47:0.359375:11587:11588 ~-0.04428908379433589 ~0.026146022361179085 247:0.796875:11590:11603 188:0.5:11591:11600 72:0.125:11592:11599 "
    s .= "144:0.125:11593:11598 94:-0.109375:11594:11597 11:0.4375:11595:11596 ~-0.053000527314543494 ~0.03591574420365682 ~0.003907554926322269 ~0.03127082719299858 ~0.02346798118225396 233:0.3125:11601:11602 "
    s .= "~0.024295078668509263 ~-0.023637359727112214 ~-0.05554426666879075 112:0.90625:11605:11608 114:0.2890625:11606:11607 ~-0.04048550520409577 ~-0.004529800653596098 ~0.010909150614253465 ~-0.044464131804788434 "
    s .= "47:1.328125:11611:11656 8:0.96875:11612:11655 50:0.71875:11613:11654 23:0.921875:11614:11653 245:1.0595238095238095:11615:11616 ~-0.03520313525840866 256:0:11617:11636 247:0.578125:11618:11635 170:0.09375:11619:11624 "
    s .= "119:0.15625:11620:11623 110:0.03125:11621:11622 ~0.0004235116146784484 ~0.017863297995293063 ~-0.01966657516042229 11:0.171875:11625:11626 ~-0.020728177050278934 252:0.175:11627:11628 ~0.017347243909969595 "
    s .= "257:0.288135593220339:11629:11632 244:1.435:11630:11631 ~-0.043417080489947954 ~0.023008098062090386 221:0.40625:11633:11634 ~-0.14068656337894977 ~0.016334362387473753 ~-0.04514094203171186 14:0.609375:11637:11652 "
    s .= "54:-0.2109375:11638:11639 ~-0.052810741353896934 243:1.95:11640:11651 252:0.125:11641:11646 107:0.46875:11642:11643 ~0.02070005550937217 52:1.40625:11644:11645 ~-0.03829394934216153 ~0.08898942215757491 "
    s .= "250:1.1484375:11647:11650 91:-0.34375:11648:11649 ~-0.12809213922019036 ~0.01311464188462923 ~0.038315586744783595 ~-0.02644132068164073 ~-0.03869334342358249 ~0.04720926176580354 ~-0.03401054075824643 "
    s .= "~0.033064514584782254 ~-0.05403371534858097 25:1.125:11658:11697 220:1.15625:11659:11692 247:0.859375:11660:11689 55:1.203125:11661:11684 64:1.125:11662:11679 89:1.03125:11663:11678 173:0.625:11664:11677 "
    s .= "8:0.71875:11665:11676 127:0.1875:11666:11667 ~0.0028097515622378983 244:1.635:11668:11671 55:0.1875:11669:11670 ~-0.0031498330583750395 ~-0.023474604037288245 115:0.671875:11672:11673 ~0.02363005864096284 "
    s .= "220:0.015625:11674:11675 ~-0.05057210780633246 ~0.011439727924811105 ~0.02822710784637708 ~-0.03129848221200465 ~0.033755893739819035 142:0.609375:11680:11683 244:2.905:11681:11682 ~0.02711216407429411 "
    s .= "~-0.060236347449727834 ~-0.026881613304055165 181:1.09375:11685:11686 ~0.02715126907180429 7:0.015625:11687:11688 ~0.01959146071594573 ~-0.05145797744248383 12:0.828125:11690:11691 ~-0.06201969161767848 "
    s .= "~0.046604415106337366 127:0.40625:11693:11696 85:1.15625:11694:11695 ~-0.04272156731593231 ~0.03654419240348264 ~0.04875360912709491 214:0.296875:11698:11703 115:0.3125:11699:11702 163:0.09375:11700:11701 "
    s .= "~-0.022071104180508807 ~0.0319188252385277 ~-0.05425480105649031 ~-0.07751635000001161 235:1.78125:11705:11750 41:0.546875:11706:11743 8:0.796875:11707:11742 89:0.78125:11708:11739 160:-0.328125:11709:11710 "
    s .= "~-0.024134204069484317 79:-0.125:11711:11720 115:0.734375:11712:11719 176:-0.109375:11713:11714 ~0.025439451522612913 99:0.3125:11715:11718 72:0.125:11716:11717 ~0.005411732560275025 ~-0.06275545523368162 "
    s .= "~0.034850048263842186 ~-0.013889320370648715 88:1.28125:11721:11732 186:0.4375:11722:11731 110:-1.265625:11723:11728 200:-0.890625:11724:11727 178:0.046875:11725:11726 ~0.0460487201426442 ~-0.02226298963690656 "
    s .= "~-0.057504899466654574 55:0.109375:11729:11730 ~0.005105079807274537 ~-0.006422960986553975 ~-0.02666180574238913 193:0:11733:11738 64:0.109375:11734:11735 ~-0.035213306774378866 10:0.359375:11736:11737 "
    s .= "~0.030839032513920957 ~-0.05315342316267671 ~0.024749478688431123 112:1.03125:11740:11741 ~0.033589614341010994 ~-0.042773201912558345 ~0.042186471889049636 91:-0.140625:11744:11747 79:0.21875:11745:11746 "
    s .= "~-0.011890650815633085 ~0.058412792393822105 246:0.921875:11748:11749 ~0.0001737982939315715 ~-0.04914708926153362 ~-0.034190127949614825 254:1.296875:11752:11781 41:0.21875:11753:11778 246:0.203125:11754:11777 "
    s .= "206:0.140625:11755:11776 247:-0.015625:11756:11763 68:-0.03125:11757:11762 246:-0.578125:11758:11761 167:-0.3125:11759:11760 ~0.005131797585967198 ~-0.028852848382230983 ~0.019796184090146565 ~0.02581626364614356 "
    s .= "248:0.125:11764:11769 253:-0.0360576923076934:11765:11768 244:2.03:11766:11767 ~0.014118837889688457 ~-0.1398372335745855 ~-0.05237408636518043 134:-0.015625:11770:11773 198:0.53125:11771:11772 ~-0.03297802994546956 "
    s .= "~0.02030911234119142 139:0.28125:11774:11775 ~0.04918287985810374 ~-0.01629052865547184 ~-0.03109333942438335 ~0.009789071318119485 98:-0.359375:11779:11780 ~-0.04699732817018251 ~-0.0032686806574122973 "
    s .= "98:-0.21875:11782:11797 169:-0.109375:11783:11784 ~-0.04359315792773702 158:-0.28125:11785:11796 59:-0.65625:11786:11795 251:1.203125:11787:11794 244:1.455:11788:11791 245:2.419753086419753:11789:11790 "
    s .= "~-0.061230102836307025 ~0.02405825845037795 250:0.8671875:11792:11793 ~-0.06449976490689828 ~0.035631680367379036 ~0.03435501280565805 ~-0.050486151569938444 ~0.0263544738635216 ~-0.04955551425514498 "
    s .= "33:1.015625:11799:11844 106:0.015625:11800:11817 150:0.2890625:11801:11814 157:0.125:11802:11805 58:0.171875:11803:11804 ~-0.0445328201020733 ~0.006924457730494581 248:1.625:11806:11811 205:0.015625:11807:11808 "
    s .= "~-0.04042755412738097 49:0.4375:11809:11810 ~0.01668745849044732 ~-0.04721081521044015 214:-0.1875:11812:11813 ~0.15718647209493394 ~-0.018677586088608197 106:-0.265625:11815:11816 ~0.04171640745955761 "
    s .= "~-0.007425453572716601 163:0.34375:11818:11831 204:0.390625:11819:11824 136:1.890625:11820:11821 ~0.008448781005497003 37:0.25:11822:11823 ~-0.03517302979148658 ~0.030360459857653916 108:0.5859375:11825:11830 "
    s .= "252:0.225:11826:11827 ~-0.03163586801031282 244:0.97:11828:11829 ~-0.0399958214825289 ~0.02296521129644659 ~0.04146079557272852 217:0.1875:11832:11835 82:-0.09375:11833:11834 ~0.028769274587971762 "
    s .= "~-0.0012593261352846297 166:-0.046875:11836:11837 ~-0.05821005128423007 133:1.15625:11838:11841 115:-0.390625:11839:11840 ~0.038240784731793015 ~-0.031154346439776093 175:0.265625:11842:11843 ~-0.026632893292853895 "
    s .= "~0.023928243349328318 ~-0.04761055186569911 101:0.5625:11846:11887 256:0:11847:11878 32:0.40625:11848:11873 170:0.09375:11849:11860 247:0.234375:11850:11851 ~0.0024928469597495107 43:0.34375:11852:11859 "
    s .= "218:0.109375:11853:11858 104:0:11854:11857 105:0.6015625:11855:11856 ~-0.06477755193516092 ~0.0038506794109608718 ~-0.004957550948230564 ~0.04731724380056315 ~0.020047487140041318 257:0.4375:11861:11870 "
    s .= "234:0.4375:11862:11869 254:0.515625:11863:11866 242:0.45:11864:11865 ~0.033756401784164246 ~-0.01409232464989422 191:0.25:11867:11868 ~-0.002898145189159937 ~-0.04354984636664554 ~-0.05326834546784131 "
    s .= "171:-0.03125:11871:11872 ~0.02258099788503646 ~-0.07507799057922392 243:0.75:11874:11877 245:2.2:11875:11876 ~0.041867507157618264 ~-0.031962997324604364 ~-0.02674985386133587 158:-0.359375:11879:11880 "
    s .= "~-0.041728059041227436 245:1.1142857142857143:11881:11882 ~-0.029940648965219804 19:0.40625:11883:11886 54:-0.1015625:11884:11885 ~-0.0218350532559306 ~0.024334631810244946 ~-0.01934244240823651 252:0.175:11888:11889 "
    s .= "~-0.03552639759501508 46:-0.25:11890:11891 ~-0.056089021211199644 ~0.007266200841352176 166:2.03125:11893:11938 85:1.34375:11894:11919 148:0:11895:11908 242:0.25:11896:11897 ~-0.04640714631236233 244:0.88:11898:11905 "
    s .= "1:-0.09375:11899:11900 ~-0.02263194879199104 141:0.1484375:11901:11904 70:-0.203125:11902:11903 ~0.13974037974613923 ~0.0481356143909118 ~0.015500621608425746 4:0.859375:11906:11907 ~0.004892025982668696 "
    s .= "~-0.040458523410396435 97:-0.078125:11909:11914 30:-0.0234375:11910:11911 ~-0.04462132306796653 22:0.125:11912:11913 ~-0.01959952985606494 ~0.019232874221436675 244:2.07:11915:11916 ~0.0009716688576980602 "
    s .= "58:0.5625:11917:11918 ~-0.006278787603551373 ~-0.0764567642853125 208:0.03125:11920:11937 190:-0.09375:11921:11924 257:0.003861003861003861:11922:11923 ~-0.012380939438781054 ~0.031395952419283606 "
    s .= "112:0.015625:11925:11928 6:-0.359375:11926:11927 ~0.03399084087637284 ~-0.07905564933460155 245:1.4125:11929:11932 163:1.46875:11930:11931 ~0.01744264054136046 ~-0.13030548386704782 181:-0.15625:11933:11934 "
    s .= "~-0.0672249693948842 140:-0.15625:11935:11936 ~0.027822377224415103 ~-0.018474034965707282 ~0.019081720122289876 ~-0.03825756291269724 144:-0.828125:11940:11943 115:0.390625:11941:11942 ~0.011720616386526432 "
    s .= "~-0.051614677402996446 9:-0.6484375:11944:11947 25:0.359375:11945:11946 ~0.03556146095370168 ~-0.022308511486351587 257:0.75:11948:11981 91:0.203125:11949:11972 79:0.53125:11950:11965 229:0.578125:11951:11962 "
    s .= "61:0.34375:11952:11961 244:0.99:11953:11956 243:0.95:11954:11955 ~0.009903493372499465 ~-0.039831992737433 181:0.109375:11957:11960 187:0.4375:11958:11959 ~-0.040730316613589515 ~0.015143028932423669 "
    s .= "~-0.0045650204735591775 ~0.006739037187634814 148:0.03125:11963:11964 ~0.0364030933172843 ~-0.01865946434991081 244:1.5:11966:11971 238:0.1875:11967:11970 169:0.09375:11968:11969 ~0.02253759623168328 "
    s .= "~-0.021800555400949273 ~-0.03487228607557858 ~0.02698163896963035 41:0.546875:11973:11980 193:-0.015625:11974:11975 ~-0.004646206796152488 58:0.5625:11976:11977 ~0.019030054477539027 250:1.3046875:11978:11979 "
    s .= "~-0.034476392905728 ~0.024485592877439667 ~-0.03266824655396496 240:-0.171875:11982:11985 61:-0.28125:11983:11984 ~0.05332807385716231 ~-0.0032218249070987063 ~-0.03664474057274751 254:0.984375:11987:12008 "
    s .= "106:1.828125:11988:11997 109:1.953125:11989:11994 120:0.78125:11990:11993 85:1.34375:11991:11992 ~0.001935213393272176 ~0.015330816180312354 ~-0.029662863772588227 133:0.984375:11995:11996 ~-0.057978214270586165 "
    s .= "~-0.004215873255970678 254:0.015625:11998:11999 ~-0.06081031589291805 245:1.4074074074074074:12000:12003 218:0.40625:12001:12002 ~-0.1305505984466869 ~0.03361465210857201 210:-0.15625:12004:12005 ~0.02916082354364706 "
    s .= "187:0.375:12006:12007 ~-0.03199187276829027 ~0.019920829430875104 250:1.0546875:12009:12024 98:-0.25:12010:12023 161:-0.265625:12011:12018 251:1.109375:12012:12017 130:1.078125:12013:12014 ~-0.05070152873524078 "
    s .= "205:0.171875:12015:12016 ~0.024004131057176886 ~-0.04639841608389191 ~0.009260253432113277 95:-0.25:12019:12020 ~0.040554377873557236 205:0.34375:12021:12022 ~-0.045723263764014276 ~0.04024141702489611 "
    s .= "~-0.041044104593342 241:0.42:12025:12030 244:1.3:12026:12029 29:0.265625:12027:12028 ~-0.04095979351050477 ~0.03678924390126794 ~0.011389908179048495 226:-0.109375:12031:12032 ~-0.028205384065612123 ~0.03383272620010438 "
    s .= "195:-0.421875:12034:12039 23:-0.046875:12035:12038 4:0.265625:12036:12037 ~0.00699795947970825 ~-0.03987616616530646 ~-0.05058056060032078 57:-0.6328125:12040:12043 46:0.328125:12041:12042 ~0.041301437120672774 "
    s .= "~-0.04090495968011491 257:0.4166666666666667:12044:12065 257:0.03333333333333333:12045:12064 22:-0.234375:12046:12047 ~-0.018262513159594342 245:3.406779661016949:12048:12063 255:-0.046875:12049:12050 "
    s .= "~-0.045036737313189995 167:0.84375:12051:12062 252:0.475:12052:12059 242:1.35:12053:12058 248:0.125:12054:12057 181:0.0625:12055:12056 ~-0.03495002909794355 ~0.0025684732024080052 ~0.006204082601008791 "
    s .= "~-0.058285239218402174 253:-0.04248366013072058:12060:12061 ~0.029909001977354962 ~0.0024110851527745416 ~-0.0423150380702344 ~-0.04080452087272271 ~0.012068613799292383 255:-0.109375:12066:12067 ~0.05068436895409213 "
    s .= "236:-0.25:12068:12075 36:-0.1875:12069:12070 ~-0.029808407988830533 106:1.796875:12071:12074 186:-0.203125:12072:12073 ~0.0321898453745677 ~-0.003606674324370833 ~-0.06672809965739344 38:0.359375:12076:12079 "
    s .= "175:-0.078125:12077:12078 ~0.00276305278134834 ~-0.055541337683313444 ~0.031628585269161645 246:1.890625:12081:12126 247:0.765625:12082:12119 124:-0.65625:12083:12084 ~-0.037344154021527125 192:0.984375:12085:12118 "
    s .= "121:0.03125:12086:12099 193:0.171875:12087:12096 166:1.625:12088:12095 192:-0.09375:12089:12092 148:0.578125:12090:12091 ~0.01609613883176294 ~-0.03649811162646921 219:-0.25:12093:12094 ~-0.0612051151561297 "
    s .= "~-0.0021620449394270046 ~-0.04522356671386617 139:-0.265625:12097:12098 ~0.03174292668402635 ~-0.031568840582185044 82:0.09375:12100:12107 37:0.25:12101:12106 46:0.625:12102:12105 178:0.359375:12103:12104 "
    s .= "~-0.0052792811126368515 ~0.024291364678942502 ~0.06044962716640571 ~0.04546876863888586 55:0.109375:12108:12111 245:1.5871559633027523:12109:12110 ~-0.020939781585111394 ~0.016126623847360737 88:1.421875:12112:12117 "
    s .= "118:0.015625:12113:12116 58:0.515625:12114:12115 ~-0.04915812857282415 ~-0.0013820409277830981 ~-0.003908506194809435 ~0.025950847272545104 ~-0.04946730534090484 127:-0.15625:12120:12121 ~0.03918913821437619 "
    s .= "111:0.4140625:12122:12125 222:0.609375:12123:12124 ~-0.03885943728894013 ~0.04989261549176547 ~-0.07434138413113964 ~0.03012767333372356 110:-1:12128:12143 189:-0.203125:12129:12138 124:0.3125:12130:12133 "
    s .= "152:-0.453125:12131:12132 ~0.020359272442702147 ~-0.023150836402428238 244:1.675:12134:12135 ~-0.04350099809183285 64:0.53125:12136:12137 ~0.0401101360815544 ~-0.07595126732334075 257:0.15384615384615385:12139:12140 "
    s .= "~0.016146772909980647 144:0.21875:12141:12142 ~-0.05705712232146124 ~0.0002445247560466399 119:-0.953125:12144:12151 106:0.078125:12145:12146 ~-0.02144959864502896 122:-0.75:12147:12148 ~0.043752901895812296 "
    s .= "210:-0.125:12149:12150 ~-0.03525423371059252 ~0.02224460596721906 224:-1.078125:12152:12153 ~-0.038927091190614896 130:2.109375:12154:12171 154:0.609375:12155:12168 100:0.484375:12156:12167 67:0.5625:12157:12166 "
    s .= "181:0.53125:12158:12165 211:-0.21875:12159:12160 ~0.011030065981095348 118:0.453125:12161:12162 ~-0.017718549913943327 241:0.1:12163:12164 ~0.07087429943043787 ~0.0010791458314788535 ~0.008273080405224452 "
    s .= "~0.02131525385352457 ~0.01391111943533287 208:-0.328125:12169:12170 ~-0.051501378646937115 ~0.010231755383791803 245:2.4754098360655736:12172:12173 ~0.010770191621976325 ~-0.04374935906698958 196:1.234375:12175:12216 "
    s .= "101:0.5625:12176:12211 246:1.546875:12177:12208 8:0.71875:12178:12207 247:0.578125:12179:12202 25:1.125:12180:12201 157:-0.140625:12181:12182 ~-0.018494993720525973 124:0.203125:12183:12184 ~0.0048248227407407425 "
    s .= "192:0.171875:12185:12200 122:-0.796875:12186:12189 159:-0.5390625:12187:12188 ~-0.028401947301465766 ~0.023702951074727717 109:-0.015625:12190:12191 ~0.028467926588325216 244:1.57:12192:12197 244:1.265:12193:12196 "
    s .= "207:-0.3125:12194:12195 ~-0.06125653772177706 ~-0.00824964278241684 ~-0.0510252443594205 235:0.125:12198:12199 ~-0.024116311780040672 ~0.021212982335931226 ~0.011360070049435785 ~-0.029044483935160254 "
    s .= "75:0.6171875:12203:12206 246:0.890625:12204:12205 ~-0.07194488211766638 ~-0.014361759812690313 ~0.013395054887512334 ~0.03324729247735867 215:0.625:12209:12210 ~0.032168713181671714 ~-0.04361584394951145 "
    s .= "252:0.175:12212:12213 ~-0.040597479698377084 46:-0.25:12214:12215 ~-0.056674551695639175 ~0.006754869831243135 143:0.03125:12217:12218 ~0.03153719043098573 99:0.5:12219:12220 ~-0.03737561784942131 ~0.05247422641202466 "
    s .= "253:-0.09898989898990054:12222:12247 252:0.125:12223:12236 33:-0.171875:12224:12227 130:0.171875:12225:12226 ~0.0020613567413827263 ~-0.07933372488430533 70:0.0625:12228:12231 205:-0.1875:12229:12230 "
    s .= "~-0.039666899068075245 ~0.02099427089554139 133:1:12232:12233 ~-0.045355987838238285 112:0:12234:12235 ~-0.06264799799638132 ~0.031758212392042434 163:1.703125:12237:12244 153:0.6796875:12238:12243 244:0.91:12239:12240 "
    s .= "~-0.01768687708543939 25:0.84375:12241:12242 ~0.02939562428493724 ~-0.06278711491137658 ~-0.04993618765149801 197:-0.25:12245:12246 ~0.02834514474512467 ~-0.1320958863949487 76:0.328125:12248:12255 190:0:12249:12252 "
    s .= "148:-0.046875:12250:12251 ~0.0027064671165426876 ~-0.018670460080997885 109:0.078125:12253:12254 ~-0.019508159127602905 ~0.003474048711936518 181:0.234375:12256:12261 124:0:12257:12258 ~-0.007082545456715507 "
    s .= "244:2.81:12259:12260 ~0.028750826320117696 ~-0.07106426287420557 244:1:12262:12267 139:-0.109375:12263:12266 245:1.4074074074074074:12264:12265 ~0.10909721593510208 ~-0.03148784462052848 ~-0.04885460033585512 "
    s .= "~0.0003757672360961149 254:1.296875:12269:12300 97:1.75:12270:12299 169:1.703125:12271:12296 248:1.375:12272:12291 79:-0.078125:12273:12282 29:-0.734375:12274:12275 ~0.03427251209870582 "
    s .= "245:1.9770114942528736:12276:12279 244:1.33:12277:12278 ~0.000031908323367703166 ~0.03313875970805513 138:0.1640625:12280:12281 ~-0.02435910807584758 ~0.02132360639016742 257:0.30985915492957744:12283:12286 "
    s .= "237:0.484375:12284:12285 ~0.004601354829185513 ~-0.013101825171216283 170:-0.78125:12287:12288 ~0.009208675731694994 255:-0.109375:12289:12290 ~0.04632872516989493 ~-0.023417314485096326 208:-0.046875:12292:12295 "
    s .= "192:-0.171875:12293:12294 ~0.10070396124534456 ~-0.013744550657123654 ~-0.0422371388432362 202:0.25:12297:12298 ~0.054050837944083954 ~-0.035143077700403876 ~-0.033316401626973455 98:-0.21875:12301:12314 "
    s .= "169:-0.109375:12302:12303 ~-0.04228092413181794 241:0.36:12304:12313 132:-0.2734375:12305:12308 202:1.0625:12306:12307 ~-0.06809434743788481 ~0.037009802659562274 111:0.0078125:12309:12312 50:-0.625:12310:12311 "
    s .= "~0.040456669839153574 ~-0.04256197808928681 ~-0.0384082587604101 ~0.019037255509945002 ~-0.04837902518838602 251:0.796875:12316:12347 241:0.38:12317:12334 245:1.9175257731958764:12318:12327 189:0.375:12319:12324 "
    s .= "67:0.125:12320:12321 ~0.018835116602018382 250:1.1328125:12322:12323 ~-0.03413036667722426 ~0.018490845270728338 90:0.7265625:12325:12326 ~-0.035782721339120305 ~0.03492316349307654 244:1.04:12328:12333 "
    s .= "166:-0.109375:12329:12330 ~-0.02835275306055255 251:0.203125:12331:12332 ~-0.02579786053950602 ~0.02813629911536371 ~-0.014317221410778567 88:0.625:12335:12340 100:0.953125:12336:12337 ~-0.030673499381384722 "
    s .= "211:1.03125:12338:12339 ~0.022148999845804998 ~-0.08954967136113595 163:0.25:12341:12344 226:-0.140625:12342:12343 ~-0.028966909208927524 ~0.03056195610494941 178:0.0625:12345:12346 ~0.013383658235722138 "
    s .= "~-0.03973444089212827 241:0.54:12348:12359 184:0.140625:12349:12354 31:0.328125:12350:12351 ~-0.020000341782190158 228:0.21875:12352:12353 ~0.03466793516756806 ~-0.031432773256142514 52:0.203125:12355:12356 "
    s .= "~0.017675083884892015 89:-0.21875:12357:12358 ~-0.03385825257940457 ~0.012824549987005008 211:0.21875:12360:12361 ~0.01908590943471154 ~-0.009082216989079414 171:0.984375:12363:12408 121:0.03125:12364:12387 "
    s .= "193:0.171875:12365:12382 152:0.078125:12366:12375 246:-2.046875:12367:12372 234:-0.078125:12368:12371 185:-0.65625:12369:12370 ~0.011297504384651604 ~-0.04340986736308236 ~-0.049268102653392584 "
    s .= "108:-0.3046875:12373:12374 ~0.02686546589294221 ~0.004105274859962283 107:0.125:12376:12377 ~-0.028462767959627145 121:-0.109375:12378:12379 ~-0.018921358562508 43:0.140625:12380:12381 ~0.02048607500831047 "
    s .= "~-0.02595495801725572 139:-0.140625:12383:12384 ~0.021959474337871633 169:-0.03125:12385:12386 ~0.0045595874638912045 ~-0.042983949491957676 121:0.125:12388:12391 136:2.109375:12389:12390 ~0.01369974310192692 "
    s .= "~-0.048268266530230246 58:0.046875:12392:12397 94:0.046875:12393:12396 43:0.234375:12394:12395 ~-0.011516408124696122 ~0.04319639380171197 ~0.02534643278228409 139:-0.234375:12398:12399 ~-0.05150770486079995 "
    s .= "250:0.6953125:12400:12401 ~-0.042067402374748646 130:0.59375:12402:12405 107:0.109375:12403:12404 ~-0.02568600626320927 ~0.002385068572320415 117:-0.703125:12406:12407 ~-0.040637730088607375 ~0.010540944005811364 "
    s .= "~-0.04126722838155292 196:1.234375:12410:12451 244:2.81:12411:12438 244:1.635:12412:12427 162:-0.5625:12413:12418 191:-1.21875:12414:12417 211:0.21875:12415:12416 ~0.03676388603952378 ~-0.038084638746677876 "
    s .= "~-0.039408771299102335 91:0.796875:12419:12424 136:1.5:12420:12421 ~-0.0005214043950155869 232:0.3125:12422:12423 ~-0.03302956744463961 ~0.022721758049491475 193:-0.09375:12425:12426 ~-0.01974813851189776 "
    s .= "~0.020875960402245767 127:0.046875:12428:12435 76:-0.0625:12429:12432 159:-0.0234375:12430:12431 ~0.025474858215604836 ~-0.039926756926281955 55:0.46875:12433:12434 ~-0.0507395964076371 ~0.012066449957767462 "
    s .= "133:0.796875:12436:12437 ~-0.021741565751290257 ~0.02605557397362271 4:0.03125:12439:12450 82:1.828125:12440:12445 133:1.3125:12441:12442 ~-0.0301269301671609 238:1.46875:12443:12444 ~0.03699831522468694 "
    s .= "~-0.04597555483496646 199:0.03125:12446:12449 257:0.2727272727272727:12447:12448 ~-0.022226906413937583 ~-0.12890796180884403 ~0.02538131152938914 ~-0.05525636937433148 166:0.515625:12452:12455 175:0.0625:12453:12454 "
    s .= "~-0.027285095680220497 ~0.03483031414954076 ~-0.04731587794303131 235:1.78125:12457:12502 167:0.84375:12458:12499 246:1.796875:12459:12498 176:0.703125:12460:12495 11:0.796875:12461:12494 137:0.75:12462:12491 "
    s .= "95:0.21875:12463:12488 246:0.203125:12464:12481 247:-0.015625:12465:12478 246:-0.578125:12466:12477 188:-0.296875:12467:12472 56:-0.09375:12468:12471 29:-0.71875:12469:12470 ~0.009479219477680175 ~-0.009165378718537025 "
    s .= "~0.03025905968362281 66:0.03125:12473:12476 247:-0.359375:12474:12475 ~0.0001816039125793495 ~-0.05577654347951664 ~-0.05270327153979008 ~0.014956145711546982 115:0.53125:12479:12480 ~-0.02427139320618318 "
    s .= "~0.008306171644041235 74:-0.078125:12482:12483 ~0.021575039038751936 215:-0.171875:12484:12485 ~-0.03894737373238193 256:0.8857142857142857:12486:12487 ~0.011187083732504923 ~-0.05442197405656184 58:0.875:12489:12490 "
    s .= "~-0.01479236835947809 ~0.02101423391591943 250:0.9453125:12492:12493 ~-0.05054980785536557 ~0.025996769703272818 ~0.03045749406501381 137:0.46875:12496:12497 ~0.015625655968935125 ~-0.042075558341428086 "
    s .= "~0.028151622499522685 88:-0.265625:12500:12501 ~0.04540649614110741 ~-0.04365562106932384 ~-0.0324239285682476 254:1.359375:12504:12541 47:-0.40625:12505:12508 238:0.46875:12506:12507 ~0.008516410491499631 "
    s .= "~-0.015125695349728269 224:-0.765625:12509:12512 20:-0.015625:12510:12511 ~-0.009613419156458572 ~-0.05880802428159702 181:2:12513:12540 255:0.265625:12514:12533 255:0.109375:12515:12524 148:-0.140625:12516:12523 "
    s .= "249:1.1666666666666665:12517:12522 114:-0.0078125:12518:12519 ~0.0445405987155233 236:0.046875:12520:12521 ~-0.03926642885018566 ~0.020799669086836725 ~-0.039562576755386075 ~-0.0057950330079962935 "
    s .= "109:1.109375:12525:12532 219:0.125:12526:12531 109:0.09375:12527:12528 ~-0.02835928755420102 236:0.28125:12529:12530 ~0.024036122462411245 ~-0.030395276941907426 ~0.0293312360204545 ~-0.010623202612525025 "
    s .= "153:-0.4453125:12534:12535 ~0.03866541795407052 100:0.53125:12536:12539 160:0.953125:12537:12538 ~-0.029700489512827985 ~0.006367297989888794 ~0.010852730294069544 ~-0.04318524530202388 169:-0.109375:12542:12543 "
    s .= "~-0.0455054290529521 98:-0.21875:12544:12549 158:-0.28125:12545:12548 59:-0.65625:12546:12547 ~0.00008996235718296389 ~-0.050969823596268816 ~0.023306666040402213 ~-0.045466797360231605 "
    s .= "253:-0.07222222222222001:12551:12566 248:0.125:12552:12559 174:0.5625:12553:12558 257:0.6666666666666666:12554:12555 ~0.028063602063674704 198:0:12556:12557 ~0.008227980587654591 ~-0.0929671526238734 "
    s .= "~-0.0329100341785027 123:0.171875:12560:12565 252:0.475:12561:12562 ~-0.028399892776196447 43:-0.25:12563:12564 ~-0.048301532054115026 ~0.034401120404098505 ~0.018170439526229362 248:0.125:12567:12582 "
    s .= "251:1.203125:12568:12579 244:1.385:12569:12572 253:-0.0243055555555524:12570:12571 ~0.002356233365381813 ~-0.03595235097450663 133:0.734375:12573:12574 ~-0.06309357376471873 245:1.6:12575:12576 ~0.029172186679009504 "
    s .= "149:-1.015625:12577:12578 ~0.04612931892346362 ~-0.011587947219506227 243:0.75:12580:12581 ~-0.016996580795372102 ~0.02532592422457372 253:-0.010416666666667851:12583:12588 252:0.42500000000000004:12584:12585 "
    s .= "~-0.03193460141833165 40:-0.109375:12586:12587 ~-0.03583776000905525 ~0.012753109210673711 244:2.81:12589:12596 13:-0.078125:12590:12595 245:2.382716049382716:12591:12592 ~-0.015612919302255113 169:-0.140625:12593:12594 "
    s .= "~-0.026762751234794643 ~0.0405710139094454 ~0.011558343312355647 ~-0.04864883664358416 242:2.1500000000000004:12598:12639 252:1.875:12599:12636 243:1.35:12600:12631 245:2.2096774193548385:12601:12616 "
    s .= "145:-0.46875:12602:12603 ~-0.044805150174441165 39:0.453125:12604:12609 226:-0.03125:12605:12608 142:0.71875:12606:12607 ~0.01782431388918746 ~-0.02902080340240475 ~0.0021569378675177853 123:0.328125:12610:12611 "
    s .= "~-0.02707834600820236 25:0.03125:12612:12615 253:-0.03913043478260647:12613:12614 ~0.03110342612633904 ~-0.03783412111411834 ~0.02060662879653838 191:0:12617:12628 232:0:12618:12625 40:0.078125:12619:12624 "
    s .= "202:0.015625:12620:12621 ~-0.05840430991271633 73:0.015625:12622:12623 ~0.02844626427648115 ~-0.03603230801233777 ~0.009253982529592808 1:-0.234375:12626:12627 ~0.037886583104981136 ~-0.00016832904081358143 "
    s .= "130:0.59375:12629:12630 ~0.0009515961362957612 ~-0.04240956464373066 4:-0.015625:12632:12633 ~-0.040830333169775766 112:0.328125:12634:12635 ~-0.02771282196417349 ~0.02093276238583593 220:-0.265625:12637:12638 "
    s .= "~-0.033429625852942374 ~0.026949282043999698 251:2.328125:12640:12643 184:1.140625:12641:12642 ~-0.039744956612435184 ~0.03601476361070878 ~0.03297717350726411 245:1.0266666666666666:12645:12648 16:0.671875:12646:12647 "
    s .= "~-0.049475657064674036 ~0.05577605028730897 246:0.203125:12649:12678 247:-0.015625:12650:12671 188:0.0625:12651:12668 246:-0.578125:12652:12661 128:-0.453125:12653:12654 ~0.005263102182797623 8:-0.015625:12655:12658 "
    s .= "24:-0.9375:12656:12657 ~0.0450603580870395 ~-0.0238495517038027 42:0.03125:12659:12660 ~0.031724022491202396 ~-0.03641179406202943 21:0.0234375:12662:12667 112:1.65625:12663:12664 ~0.011103267401794476 "
    s .= "143:-0.21875:12665:12666 ~0.0033077113590575316 ~-0.10338885858279952 ~0.03392018573182332 244:1.48:12669:12670 ~-0.04173713194876144 ~0.010022172741395283 115:0.53125:12672:12675 248:0.125:12673:12674 "
    s .= "~-0.041830187689006974 ~-0.014148826571386067 99:0.109375:12676:12677 ~-0.020552715347743656 ~0.01991856553851714 89:0.15625:12679:12680 ~0.014500733057044 16:0.609375:12681:12690 133:-0.125:12682:12683 "
    s .= "~0.028683552336603208 112:0.671875:12684:12689 51:0.5078125:12685:12688 240:0.375:12686:12687 ~0.003849293645310535 ~-0.02665333272814545 ~-0.039358060986113996 ~0.008966980064210948 ~-0.044456301199862595 "
    s .= "254:0.984375:12692:12709 239:-1.359375:12693:12694 ~0.02761060902267827 144:-0.484375:12695:12700 124:0.203125:12696:12699 185:-0.65625:12697:12698 ~0.017446295948864432 ~-0.033711766356991926 ~-0.04375076455389409 "
    s .= "57:-0.4921875:12701:12702 ~0.02390226367991557 246:-2.421875:12703:12706 188:-1.078125:12704:12705 ~0.014396924738802695 ~-0.041074085279239926 154:1.984375:12707:12708 ~0.002530857434364407 ~-0.02572213750646131 "
    s .= "250:1.0546875:12710:12727 196:0.3125:12711:12722 247:0.171875:12712:12721 190:0:12713:12714 ~-0.039570306692423445 257:0.288135593220339:12715:12720 109:0.859375:12716:12717 ~-0.018217374202028982 253:0:12718:12719 "
    s .= "~0.037833695464264835 ~-0.04294520790629561 ~-0.04668997686148029 ~-0.05158159246276846 232:0.328125:12723:12726 50:-0.25:12724:12725 ~0.04568690294889608 ~-0.031459903143862676 ~-0.030822124438736154 "
    s .= "241:0.42:12728:12735 31:0.015625:12729:12734 195:-0.21875:12730:12731 ~-0.04786586211058163 90:0.1171875:12732:12733 ~0.0343822543171226 ~-0.024882386349100033 ~-0.03072596019156922 226:-0.125:12736:12737 "
    s .= "~-0.029256424829545682 ~0.03218712535516713 251:0.796875:12739:12782 241:0.38:12740:12771 61:1.28125:12741:12770 32:0.421875:12742:12767 100:-0.25:12743:12746 130:0.234375:12744:12745 ~-0.024628296099775664 "
    s .= "~0.03724517000726663 186:-0.03125:12747:12756 231:0.03125:12748:12755 157:0.125:12749:12752 172:-0.09375:12750:12751 ~0.015148761239276757 ~-0.03967245120158511 142:0.3125:12753:12754 ~0.014628654027759785 "
    s .= "~-0.017899628324098384 ~0.04776963121099164 175:0.53125:12757:12764 30:0.0078125:12758:12759 ~-0.03934600909295978 70:-0.1875:12760:12761 ~-0.0510241748326581 243:0.45:12762:12763 ~0.0012866174943368795 "
    s .= "~-0.02699372841820226 116:-0.03125:12765:12766 ~-0.02902096022789724 ~0.03983044386473473 185:0.453125:12768:12769 ~0.042465831989960956 ~-0.02223470926799692 ~0.03427996038502513 163:0.171875:12772:12777 "
    s .= "88:0.625:12773:12774 ~-0.01717264064045237 229:-0.109375:12775:12776 ~-0.02275801250306566 ~0.03160233222839507 181:0.171875:12778:12781 120:-0.015625:12779:12780 ~0.024314441948896138 ~-0.029335062173660838 "
    s .= "~-0.03324326906448749 241:0.54:12783:12784 ~-0.002026378382697291 ~0.010563493034775499 77:0.578125:12786:12829 256:0.01818181818181818:12787:12820 247:0.484375:12788:12815 254:0.796875:12789:12790 ~0.003181221505868897 "
    s .= "11:0.546875:12791:12814 26:-0.140625:12792:12811 191:0.203125:12793:12810 246:-0.609375:12794:12801 244:1.39:12795:12800 186:-0.3125:12796:12797 ~0.0015705189237593378 91:1.09375:12798:12799 ~-0.04838269329405742 "
    s .= "~0.017531015461770452 ~0.002125820631104669 255:0.234375:12802:12805 157:0.15625:12803:12804 ~-0.014789391624041219 ~0.05531146168183158 77:-0.359375:12806:12807 ~0.024600181623516546 184:0.890625:12808:12809 "
    s .= "~-0.036198530953418594 ~0.03050849975015062 ~-0.04391392355705859 103:0.953125:12812:12813 ~-0.03198984161808283 ~0.0035541112008270533 ~0.049341200321368656 70:0.046875:12816:12817 ~-0.06384039782056947 "
    s .= "153:0.5546875:12818:12819 ~-0.03878723595473285 ~0.029806774343652323 71:0.375:12821:12826 19:-0.21875:12822:12823 ~-0.016330571382235173 245:1.1358024691358024:12824:12825 ~-0.030791192073533563 ~0.025743957636511383 "
    s .= "91:-0.140625:12827:12828 ~0.027377790309627722 ~-0.02115738129084264 7:0.15625:12830:12831 ~0.00006916796305041169 ~-0.03847354311746647 49:0.859375:12833:12876 76:0.328125:12834:12871 76:0.09375:12835:12858 "
    s .= "181:0.125:12836:12853 61:0.765625:12837:12852 190:-0.015625:12838:12839 ~-0.023561837244113266 41:0.203125:12840:12851 1:0.0625:12841:12848 252:0.07500000000000001:12842:12847 239:-0.859375:12843:12844 "
    s .= "~0.028737235396020567 49:0.09375:12845:12846 ~-0.0393283732786331 ~0.022790084508978105 ~0.020886736725521507 244:1.115:12849:12850 ~0.04418481917337863 ~-0.013412273396777821 ~-0.03024266302735823 ~0.017912800742569172 "
    s .= "215:-0.1875:12854:12857 57:0.0234375:12855:12856 ~0.005289546895974962 ~0.030826965446160107 ~-0.0011454072918288358 244:1.22:12859:12866 251:0.828125:12860:12863 130:0.109375:12861:12862 ~0.02034371422594189 "
    s .= "~-0.0245100559951759 120:0.140625:12864:12865 ~0.033991640974248664 ~-0.010005876643066673 154:0.625:12867:12870 88:1.09375:12868:12869 ~-0.047503909067929784 ~0.013776539629406725 ~-0.004588604376901487 "
    s .= "157:0.296875:12872:12873 ~0.021951060363715785 244:0.94:12874:12875 ~-0.041699785064463826 ~0.005910895070538928 137:-0.21875:12877:12878 ~-0.04186912824909464 ~0.0005966512360025857 33:1.015625:12880:12925 "
    s .= "8:0.96875:12881:12924 247:0.984375:12882:12923 246:1.796875:12883:12920 192:0.921875:12884:12919 211:1.8125:12885:12918 77:0.640625:12886:12913 124:-0.65625:12887:12888 ~-0.0372960723787872 61:-0.28125:12889:12902 "
    s .= "10:-0.109375:12890:12899 236:-0.296875:12891:12898 224:-0.5625:12892:12897 244:1.17:12893:12894 ~-0.04488243392303734 252:0.07500000000000001:12895:12896 ~-0.0271311324035777 ~0.048562382614430764 ~0.036503707012940825 "
    s .= "~-0.030815022527883037 243:0.75:12900:12901 ~0.05007866841771933 ~0.0012941894768348453 257:0.75:12903:12908 22:-0.265625:12904:12907 148:0.15625:12905:12906 ~0.0024671008904452504 ~-0.03242963119642356 "
    s .= "~0.002494869279813746 236:-0.234375:12909:12912 255:0.015625:12910:12911 ~0.0112417357140575 ~-0.021434931195384865 ~-0.047365458655876755 139:0.75:12914:12917 253:-0.055014430014430425:12915:12916 ~0.007720493233957813 "
    s .= "~-0.04855796792361767 ~0.025388070856703384 ~-0.04145112198356604 ~-0.049064819871132814 215:0.609375:12921:12922 ~0.04303872248145233 ~-0.04267372506711392 ~-0.053953851005354964 ~0.03143720464724471 "
    s .= "~-0.04637603133749547 253:-0.09898989898990054:12927:12958 58:0.046875:12928:12935 57:0.0703125:12929:12934 127:0.375:12930:12931 ~0.017700409440629974 139:0.3125:12932:12933 ~0.008281897006228334 ~-0.06164093138098886 "
    s .= "~0.03692236249633571 58:0.609375:12936:12949 64:0.75:12937:12948 120:0.265625:12938:12947 196:0.296875:12939:12946 241:0.44:12940:12943 132:-0.5390625:12941:12942 ~0.015429400338928742 ~-0.07356133491139086 "
    s .= "240:0.109375:12944:12945 ~0.010935189087487144 ~-0.06269829738525484 ~0.014466244058045225 ~0.014799499988826448 ~0.037368178059067815 253:-0.17333333333333484:12950:12957 190:0.015625:12951:12954 "
    s .= "61:0.359375:12952:12953 ~-0.1167481525454111 ~0.001371524849834229 139:0.4375:12955:12956 ~0.030969985064680468 ~-0.056911031782805405 ~0.034049309277125794 195:-0.421875:12959:12964 23:-0.046875:12960:12963 "
    s .= "4:0.265625:12961:12962 ~0.0026794065237589937 ~-0.036718400387202435 ~-0.05327967361664968 57:-0.6328125:12965:12966 ~0.03131597412937409 139:0.46875:12967:12970 46:0.671875:12968:12969 ~-0.0059554028538751184 "
    s .= "~0.026286311377529226 85:0.359375:12971:12972 ~0.010888985274650216 ~-0.004740959178830633 242:2.1500000000000004:12974:13017 252:1.775:12975:13012 243:1.35:12976:13003 245:2.2533333333333334:12977:12984 "
    s .= "145:-0.46875:12978:12979 ~-0.04453676944960707 39:0.453125:12980:12981 ~0.005517932608856439 123:0.4375:12982:12983 ~-0.023966768276406997 ~0.005914927019699143 82:0.4375:12985:13000 85:0.171875:12986:12999 "
    s .= "25:-0.25:12987:12988 ~0.03954650280512689 213:0.171875:12989:12992 209:-1.328125:12990:12991 ~0.03308440272127713 ~-0.044335627502811246 217:-0.046875:12993:12994 ~-0.042854537131838594 160:0.109375:12995:12996 "
    s .= "~-0.041078582937566104 142:0.21875:12997:12998 ~0.05462669030552726 ~-0.052428088357542896 ~0.015775785656997797 181:0.71875:13001:13002 ~-0.004433397776659439 ~-0.044477148678659824 252:0.525:13004:13007 "
    s .= "148:-0.265625:13005:13006 ~0.00986079280317645 ~-0.07290957710359743 199:0.140625:13008:13011 238:0.140625:13009:13010 ~0.022543270174827407 ~-0.03280657521394847 ~-0.04881287126144764 178:0.296875:13013:13014 "
    s .= "~0.03498973821722468 69:0.125:13015:13016 ~-0.02156399313268247 ~0.02997374736440748 252:0.725:13018:13019 ~-0.07714611207363843 ~-0.00787304044748687 171:0.984375:13021:13066 25:1.125:13022:13061 79:0.375:13023:13046 "
    s .= "175:0.578125:13024:13039 100:-0.25:13025:13028 203:-0.0625:13026:13027 ~0.02767374606780943 ~-0.008368128226164262 73:-0.375:13029:13030 ~-0.043796333365830574 187:0.09375:13031:13036 244:1.105:13032:13033 "
    s .= "~0.0018141350841500811 52:-0.0625:13034:13035 ~-0.0007309430958998103 ~-0.030042365531420246 250:0.6953125:13037:13038 ~-0.04275136896873666 ~0.0035499618039672165 193:-0.0625:13040:13043 75:0.1484375:13041:13042 "
    s .= "~-0.042064908835767315 ~0.018434754961099996 121:-0.046875:13044:13045 ~-0.007078774617971798 ~0.029675624896203803 160:0.078125:13047:13048 ~0.02498176028840759 244:1.48:13049:13056 251:0.390625:13050:13051 "
    s .= "~-0.0328569912216107 208:0.515625:13052:13053 ~0.00525355071683752 130:1:13054:13055 ~-0.05184546278873912 ~0.018049698627936032 64:0.546875:13057:13058 ~0.025727616224693814 40:0.125:13059:13060 ~0.03136239974582748 "
    s .= "~-0.040800915417053545 214:0.296875:13062:13065 115:0.3125:13063:13064 ~0.009543885893262376 ~-0.051896445526228255 ~-0.07217542296259179 ~-0.040540517817641314 253:-0.07222222222222001:13068:13087 248:0.125:13069:13078 "
    s .= "208:-0.234375:13070:13073 160:0.4375:13071:13072 ~-0.05215912019426527 ~0.035635159140026164 257:0.6666666666666666:13074:13075 ~0.02801972786835032 150:-0.1484375:13076:13077 ~0.023907885534363394 ~-0.06286674836740389 "
    s .= "123:0.171875:13079:13084 252:0.475:13080:13081 ~-0.026496598508429167 43:-0.25:13082:13083 ~-0.0451135590135091 ~0.03279736262373124 118:0.28125:13085:13086 ~0.027247401446159426 ~-0.024433525976393762 "
    s .= "248:0.125:13088:13103 251:1.203125:13089:13100 234:0.390625:13090:13099 242:0.55:13091:13096 157:0.5625:13092:13093 ~-0.019229951650712226 181:-0.015625:13094:13095 ~-0.03652292099311035 ~0.028767918667432796 "
    s .= "107:0.1875:13097:13098 ~-0.028597865949290792 ~0.013410026895318831 ~-0.05066809946467139 243:0.75:13101:13102 ~-0.01660990785768136 ~0.02419447513480846 253:-0.010416666666667851:13104:13109 252:0.225:13105:13108 "
    s .= "178:0.875:13106:13107 ~-0.04872686173447393 ~0.020789571922399348 ~-0.0034962712550152294 244:2.81:13110:13113 249:1.8333333333333335:13111:13112 ~0.007914247412275598 ~-0.0333005841724697 ~-0.0459817264654474 "
    s .= "106:0.015625:13115:13132 150:0.2890625:13116:13127 157:0.125:13117:13120 58:0.171875:13118:13119 ~-0.04228884166796803 ~0.005755216098503127 248:1.625:13121:13126 205:0.015625:13122:13123 ~-0.03914888271933345 "
    s .= "214:0.421875:13124:13125 ~0.015668076782750926 ~-0.0352705893951102 ~0.0711874863094824 106:-0.265625:13128:13129 ~0.03856684387804507 55:0.125:13130:13131 ~-0.02401316780110744 ~0.025459636363865876 "
    s .= "245:1.1547619047619047:13133:13134 ~-0.035745279331908165 195:-0.421875:13135:13138 133:0.96875:13136:13137 ~-0.036703673497939265 ~0.0035678783065682578 9:-0.6484375:13139:13140 ~0.031589231912673155 "
    s .= "7:0.890625:13141:13156 220:0.84375:13142:13155 7:0.5625:13143:13154 31:0.03125:13144:13147 217:0.21875:13145:13146 ~0.008677286355077382 ~-0.013552383183480869 82:0.0625:13148:13151 248:0.125:13149:13150 "
    s .= "~-0.01945755683071224 ~0.030035954690741135 19:0.1875:13152:13153 ~-0.017299778839808697 ~0.004138256001269355 ~0.02503811382119276 ~0.02772568207951567 245:1.4939759036144578:13157:13158 ~0.051089443260287075 "
    s .= "25:-0.453125:13159:13160 ~0.020433440449724602 ~-0.05267082321696592 249:0.16666666666666666:13162:13169 177:0.203125:13163:13168 151:1.0625:13164:13167 154:0.65625:13165:13166 ~0.003934208874276608 "
    s .= "~0.021976674492005202 ~-0.011973940339025962 ~-0.009930634800120734 219:0.265625:13170:13203 97:-0.125:13171:13176 20:-0.109375:13172:13175 51:-0.1484375:13173:13174 ~-0.03486697661578856 ~0.008677789916406933 "
    s .= "~-0.04338015182338855 244:1.18:13177:13200 73:0.21875:13178:13193 1:0.0625:13179:13188 205:0.28125:13180:13187 238:1.46875:13181:13186 242:0.45:13182:13183 ~-0.03596165380969762 109:0.65625:13184:13185 "
    s .= "~-0.024865492700616557 ~0.027543719755622916 ~0.08658144718444416 ~0.02402527398245323 193:-0.234375:13189:13190 ~-0.051440929382732196 93:0.453125:13191:13192 ~0.03406276442191557 ~-0.036964968477956814 "
    s .= "238:-0.421875:13194:13195 ~0.03352190433991914 244:1.125:13196:13199 133:0.234375:13197:13198 ~0.007849405960530449 ~-0.046813501868612786 ~0.028288563729383404 214:0.265625:13201:13202 ~-0.0238929490680419 "
    s .= "~0.011988792032608915 234:-0.140625:13204:13205 ~-0.04187406070905874 175:1.015625:13206:13207 ~0.005149002806396637 ~0.0417286148699959 41:0.546875:13209:13250 8:0.875:13210:13249 245:1.0595238095238095:13211:13212 "
    s .= "~-0.04212650728873812 256:0.01818181818181818:13213:13238 247:0.578125:13214:13237 254:0.796875:13215:13222 128:-0.578125:13216:13217 ~0.012458389129845248 246:-1.640625:13218:13219 ~-0.030566227108224833 "
    s .= "52:-0.0625:13220:13221 ~0.011806480206531614 ~-0.0032687956225989747 188:0.328125:13223:13236 246:-0.453125:13224:13227 244:0.98:13225:13226 ~-0.045014438199179 ~-0.008351296072358105 62:-0.375:13228:13231 "
    s .= "98:-0.28125:13229:13230 ~0.03751699026675623 ~-0.018398326829848485 103:0.8125:13232:13235 128:0.0625:13233:13234 ~-0.0008035650418331212 ~-0.03427752614678758 ~0.01755843749561569 ~-0.04113908544101245 "
    s .= "~-0.0385447634248241 19:-0.234375:13239:13242 120:0.109375:13240:13241 ~-0.06067024738944391 ~0.003096487911050643 252:0.125:13243:13246 107:0.46875:13244:13245 ~0.015624960299589553 ~-0.033662744843988235 "
    s .= "16:0.484375:13247:13248 ~0.027481955701280505 ~-0.03589731956092892 ~0.04196534358883272 107:0.390625:13251:13254 129:-0.0390625:13252:13253 ~-0.03973313505953273 ~0.02989351690440264 ~-0.029899503540356878 "
    s .= "242:2.1500000000000004:13256:13295 252:1.875:13257:13288 243:1.35:13258:13277 257:0.30985915492957744:13259:13260 ~0.0025455980803352485 252:0.32499999999999996:13261:13274 186:-0.171875:13262:13269 "
    s .= "25:0.078125:13263:13266 12:0.171875:13264:13265 ~0.020403133625204097 ~-0.03755868292266789 170:-0.78125:13267:13268 ~0.012467770701973774 ~-0.043876456046366766 244:1.16:13270:13271 ~-0.04376143077275284 "
    s .= "246:-1.890625:13272:13273 ~-0.03614394967818265 ~0.009386663090310039 123:-0.203125:13275:13276 ~-0.0009496135739045103 ~-0.06407336894335526 4:-0.015625:13278:13283 55:0.78125:13279:13282 154:-0.3125:13280:13281 "
    s .= "~0.024142732825910045 ~-0.05328420599757029 ~0.02527666806939582 28:0.421875:13284:13287 251:0.953125:13285:13286 ~-0.023704632725816896 ~0.029646510255729466 ~-0.05155040190927386 220:-0.265625:13289:13290 "
    s .= "~-0.03270069907211947 178:0.5625:13291:13294 244:0.805:13292:13293 ~-0.0380171667019249 ~0.04428206475218336 ~-0.0001436906328736887 25:0.015625:13296:13301 52:0.359375:13297:13300 243:1.95:13298:13299 "
    s .= "~0.00685757007271232 ~-0.059828238446808096 ~0.03883448126824781 ~-0.04582310707937748 253:-0.1079059829059806:13303:13338 252:0.125:13304:13323 30:-0.1171875:13305:13308 106:1.0625:13306:13307 ~-0.0699720759109899 "
    s .= "~0.003261174694553448 163:-0.125:13309:13312 84:0.1953125:13310:13311 ~-0.06011503806582022 ~0.02049035974404215 13:0.203125:13313:13320 232:0.015625:13314:13319 142:0.015625:13315:13318 101:0.125:13316:13317 "
    s .= "~0.03485665419171758 ~-0.0391668737157822 ~-0.044120060084745956 ~0.03625958631694775 229:0.09375:13321:13322 ~0.01082834637182967 ~-0.08326336209896981 163:1.703125:13324:13335 25:0.3125:13325:13332 "
    s .= "133:0.65625:13326:13331 244:2.01:13327:13328 ~0.01909627685882452 58:1.40625:13329:13330 ~-0.14949609785836476 ~-0.002168818011567025 ~0.03840252714406375 109:1.28125:13333:13334 ~-0.05512860069989204 "
    s .= "~0.024375078056505323 232:0.140625:13336:13337 ~-0.14302850165655712 ~0.00968602726818479 120:-0.78125:13339:13342 115:0.390625:13340:13341 ~0.010263302000409672 ~-0.052028434641780856 24:-0.9375:13343:13344 "
    s .= "~0.0446342098400229 57:-0.6796875:13345:13348 222:-0.34375:13346:13347 ~-0.01206839527402805 ~0.04251673859808302 ~-0.0016415841903824084 176:0.65625:13350:13389 48:0.2109375:13351:13372 148:0.890625:13352:13367 "
    s .= "54:0.8203125:13353:13366 151:-0.109375:13354:13361 245:1.4939759036144578:13355:13356 ~0.03765664692976869 202:-0.25:13357:13358 ~-0.03404300291632775 26:-0.09375:13359:13360 ~0.024797095382120948 ~-0.013668723293485256 "
    s .= "88:0.75:13362:13365 43:0.453125:13363:13364 ~-0.0077226254189681365 ~0.021279449040714285 ~0.008554203609677303 ~-0.06029394115141382 133:0.765625:13368:13369 ~-0.05411489810768563 23:-0.28125:13370:13371 "
    s .= "~0.016331512127936595 ~-0.02716395216301909 246:-0.578125:13373:13378 212:-0.3125:13374:13377 247:0.015625:13375:13376 ~0.014726351617556433 ~-0.06932755274203582 ~-0.045690451909887214 48:0.3984375:13379:13382 "
    s .= "192:0.09375:13380:13381 ~0.036810098502227516 ~0.009719485813499955 191:-0.046875:13383:13386 74:-0.078125:13384:13385 ~0.028397209901441463 ~-0.014163767836843628 124:0.625:13387:13388 ~-0.01857965307441652 "
    s .= "~0.03411170334623901 72:0.625:13390:13395 251:1.234375:13391:13394 157:1.15625:13392:13393 ~-0.044066311423540755 ~0.030652911720026762 ~0.0233575980662666 ~-0.05516740670117222 219:0.984375:13397:13442 "
    s .= "181:2.421875:13398:13441 253:-0.09898989898990054:13399:13434 58:0.046875:13400:13405 33:0.046875:13401:13402 ~0.0020784530477780064 74:0.21875:13403:13404 ~0.043526066513665314 ~-0.008206923995227556 "
    s .= "58:0.765625:13406:13425 64:0.828125:13407:13424 172:0.359375:13408:13419 133:-0.015625:13409:13410 ~0.025339835272052122 49:0.109375:13411:13416 240:0.15625:13412:13413 ~0.0022898088172962046 96:0.3828125:13414:13415 "
    s .= "~-0.06387596967241817 ~0.010787367405144724 43:0.25:13417:13418 ~-0.07773061973023077 ~0.0027431726313904563 154:0.3125:13420:13423 223:0.203125:13421:13422 ~0.006353324703022999 ~-0.11531488696035408 "
    s .= "~0.03145546809813744 ~0.03426531747546798 253:-0.17333333333333484:13426:13431 190:-0.015625:13427:13430 67:-0.078125:13428:13429 ~0.009000110855984752 ~-0.11548303231974062 ~0.012826319546482987 67:-0.28125:13432:13433 "
    s .= "~-0.029608502491547752 ~0.044113902323709736 246:-2.390625:13435:13440 209:-0.890625:13436:13437 ~0.0005720098082146424 81:-0.8515625:13438:13439 ~0.032999891268257885 ~-0.05193444916861248 ~0.00010511717099148703 "
    s .= "~-0.04085198801518908 ~-0.04164750037171291 33:1.015625:13444:13489 8:0.96875:13445:13488 247:0.984375:13446:13487 246:1.796875:13447:13484 192:0.921875:13448:13483 211:1.8125:13449:13482 250:1.4765625:13450:13475 "
    s .= "151:0.0625:13451:13454 242:0.25:13452:13453 ~-0.0314777308013856 ~0.008268565390375729 121:-0.046875:13455:13460 6:-0.03125:13456:13459 244:2.07:13457:13458 ~-0.04786614022582622 ~0.021030131741954717 "
    s .= "~-0.002789985444826667 67:-0.09375:13461:13466 196:0.296875:13462:13465 130:1.328125:13463:13464 ~-0.03689662628658076 ~0.016439587798960632 ~0.010427686286112505 250:0.6796875:13467:13468 ~-0.025586738181821313 "
    s .= "245:1.5806451612903225:13469:13474 116:0.59375:13470:13473 7:0.421875:13471:13472 ~-0.04395665793510815 ~0.01957008220198822 ~0.03020331378922711 ~0.010426086508855516 235:0.046875:13476:13479 "
    s .= "257:0.30985915492957744:13477:13478 ~-0.021948923056767974 ~-0.09634007027267306 157:0.21875:13480:13481 ~-0.020158680285714266 ~0.018869158865424798 ~-0.03987755212799025 ~-0.04708883851261147 215:0.609375:13485:13486 "
    s .= "~0.041644211244791965 ~-0.04205515042715436 ~-0.05248975915581827 ~0.02989607787799707 ~-0.04515291201296381 77:0.578125:13491:13534 256:0.01818181818181818:13492:13525 247:0.484375:13493:13518 254:0.796875:13494:13495 "
    s .= "~0.0031031734643541145 11:0.546875:13496:13517 26:-0.140625:13497:13516 236:0.203125:13498:13515 246:-0.546875:13499:13508 244:1.385:13500:13507 186:-0.3125:13501:13504 132:-0.4296875:13502:13503 ~-0.029552118310832234 "
    s .= "~0.031964044199421525 91:1.09375:13505:13506 ~-0.04527383581346365 ~0.018885965329585457 ~0.0014705043345917162 255:0.234375:13509:13512 157:0.140625:13510:13511 ~-0.012023545055796149 ~0.05769650936230805 "
    s .= "26:-0.40625:13513:13514 ~0.020172483866904102 ~-0.02613147229431503 ~-0.0437987321662838 ~-0.021639621101323628 ~0.047525747543070825 70:0.046875:13519:13520 ~-0.06065142289006845 153:0.5546875:13521:13524 "
    s .= "106:0.125:13522:13523 ~0.03239059929607679 ~-0.05923690366070172 ~0.028980086722265708 71:0.375:13526:13531 19:-0.21875:13527:13528 ~-0.014565184482501353 245:1.1358024691358024:13529:13530 ~-0.029709848266215224 "
    s .= "~0.023590334685711603 115:-0.15625:13532:13533 ~0.02442350854716404 ~-0.021344682665645657 7:0.15625:13535:13536 ~0.00014514136082467453 ~-0.03762112317560397 176:0.65625:13538:13579 11:0.796875:13539:13578 "
    s .= "26:0.484375:13540:13577 89:0.625:13541:13576 245:1.3409090909090908:13542:13545 79:-0.359375:13543:13544 ~0.04449947558734229 ~-0.04315153403745072 256:0.01818181818181818:13546:13571 247:0.484375:13547:13568 "
    s .= "68:0.5625:13548:13567 203:0.09375:13549:13552 255:-0.140625:13550:13551 ~0.03884495071354323 ~0.0009539957863377802 110:-0.515625:13553:13554 ~-0.06372047429765713 191:-0.15625:13555:13556 ~0.0204813548492156 "
    s .= "136:1.546875:13557:13566 23:-0.09375:13558:13559 ~-0.02818508217241914 239:0.421875:13560:13565 129:0.1796875:13561:13564 103:0.90625:13562:13563 ~-0.03054023927337133 ~0.012384250489419997 ~0.03787647949315739 "
    s .= "~0.03170549271248695 ~-0.04492995153192522 ~0.048531623200725044 75:0.6171875:13569:13570 ~-0.04839385526395032 ~0.0067376083501964465 250:1.1796875:13572:13575 46:-0.28125:13573:13574 ~-0.06660302789165991 "
    s .= "~0.006319968033466203 ~0.029700043581589265 ~0.017877862623681903 ~-0.019606068241292397 ~0.024836685252772665 96:0.3828125:13580:13583 251:1.234375:13581:13582 ~-0.027449398264780295 ~0.026783232073691817 "
    s .= "~-0.044923598900181744 235:1.78125:13585:13630 247:0.890625:13586:13627 107:0.96875:13587:13626 192:0.984375:13588:13625 218:0.65625:13589:13622 124:-0.65625:13590:13591 ~-0.03508520239184465 242:2.05:13592:13619 "
    s .= "252:2.125:13593:13616 243:1.25:13594:13609 245:2.2096774193548385:13595:13596 ~0.004173795012062171 191:0:13597:13606 199:0.109375:13598:13605 202:0.34375:13599:13604 99:-0.25:13600:13601 ~-0.04972559389971706 "
    s .= "208:0:13602:13603 ~-0.024963603891029224 ~0.006611933192482558 ~0.03112916070198144 ~0.01456060451106373 241:0.12:13607:13608 ~0.01932644183324364 ~-0.03337242846570832 4:-0.015625:13610:13613 79:0.875:13611:13612 "
    s .= "~-0.04760553132479196 ~0.012962423709590483 28:0.71875:13614:13615 ~0.009167465127548978 ~-0.06470760278199085 178:0.6875:13617:13618 ~0.03886832030996182 ~-0.017784647457719314 25:0.015625:13620:13621 "
    s .= "~0.004674815972787847 ~-0.04326675876282407 169:0.6875:13623:13624 ~-0.0443617269878624 ~0.021611350925239997 ~-0.04832567814537061 ~0.028020055894485238 42:0.296875:13628:13629 ~-0.06919684005672196 "
    s .= "~0.01272081043385833 ~-0.030639265620272124 249:0.16666666666666666:13632:13635 240:0.53125:13633:13634 ~0.004976141061626694 ~-0.023408814804201643 219:0.265625:13636:13673 253:-0.010416666666667851:13637:13648 "
    s .= "144:0.0625:13638:13643 184:0.875:13639:13642 91:1.171875:13640:13641 ~-0.03971613915538865 ~0.014411500215989205 ~0.010336195900720336 177:0.109375:13644:13645 ~0.016304883023668393 66:0.109375:13646:13647 "
    s .= "~0.011409231135697643 ~-0.041577903247988386 10:0.078125:13649:13658 239:-0.796875:13650:13651 ~0.015603910393993004 49:0.015625:13652:13653 ~-0.02745568902033903 208:-0.046875:13654:13655 ~0.030703219479912114 "
    s .= "244:1.03:13656:13657 ~0.007417588783164637 ~-0.037755212975649585 82:0.046875:13659:13662 103:0.078125:13660:13661 ~-0.0025766464295458695 ~0.05154698455836573 7:-0.03125:13663:13664 ~-0.05428789342405237 "
    s .= "223:0.015625:13665:13666 ~0.024455339440568383 242:0.55:13667:13668 ~-0.0268489670979146 52:0.28125:13669:13672 87:-0.0078125:13670:13671 ~0.04456992678114538 ~-0.02765599695924667 ~-0.02515915080082219 "
    s .= "231:-0.1875:13674:13675 ~-0.05376220760972747 145:0.671875:13676:13677 ~0.00441948770734215 ~0.04087320339091396 253:-0.07222222222222001:13679:13698 248:0.125:13680:13687 174:0.578125:13681:13686 "
    s .= "257:0.6666666666666666:13682:13683 ~0.026073675260125204 198:0:13684:13685 ~0.007265647154208323 ~-0.07915823578670077 ~-0.03349480767879968 12:0.0625:13688:13691 9:-0.2890625:13689:13690 ~0.010137978415651942 "
    s .= "~-0.028321036596152815 146:0.109375:13692:13695 251:1.984375:13693:13694 ~0.026017698508774653 ~-0.04364547234877579 171:0.28125:13696:13697 ~-0.03147299403710518 ~0.019660694195466108 248:0.125:13699:13704 "
    s .= "106:0.109375:13700:13701 ~-0.026894237604091098 40:0.65625:13702:13703 ~-0.00022120547930697915 ~-0.057157956401449155 253:-0.010416666666667851:13705:13710 252:0.225:13706:13709 178:0.875:13707:13708 "
    s .= "~-0.04656342150351249 ~0.020242808913460548 ~-0.0031599929575284965 244:2.81:13711:13724 13:-0.078125:13712:13723 245:2.382716049382716:13713:13722 232:-0.09375:13714:13719 231:0.265625:13715:13718 "
    s .= "214:-0.21875:13716:13717 ~-0.03466685944396429 ~0.03754130031233757 ~-0.05203227320774322 64:0.015625:13720:13721 ~-0.04162341787939006 ~-0.002192427209965841 ~0.023826436748272575 ~0.010081811120224132 "
    s .= "~-0.04330823661728429 154:0.609375:13726:13759 100:1.015625:13727:13758 184:0.609375:13728:13755 244:1.195:13729:13740 127:0.6875:13730:13739 181:0.0625:13731:13734 49:-0.015625:13732:13733 ~-0.011509795606723649 "
    s .= "~0.018473599137338186 232:0.984375:13735:13738 91:0.625:13736:13737 ~-0.020220665164160073 ~0.017388393035272297 ~0.05676885973778574 ~0.02701706591794812 10:0.453125:13741:13754 88:0.125:13742:13749 "
    s .= "193:-0.09375:13743:13744 ~-0.00476104260039208 205:0.71875:13745:13748 40:-0.65625:13746:13747 ~0.05653593772551024 ~-0.05111172147033303 ~0.022811834254997748 79:0.078125:13750:13751 ~0.010153607997111626 "
    s .= "112:0.828125:13752:13753 ~-0.05048757597231951 ~-0.001144779789988149 ~0.016082310815788887 112:0.5625:13756:13757 ~-0.007580799476173725 ~0.021982927398431273 ~0.017206305235363276 208:-0.25:13760:13761 "
    s .= "~-0.023756628378467273 223:0.046875:13762:13765 154:1.46875:13763:13764 ~0.006839284464534028 ~-0.02384069480930438 67:0.625:13766:13771 241:0.66:13767:13768 ~0.027255894944937645 251:0.828125:13769:13770 "
    s .= "~-0.025910444591225174 ~0.018213657254787484 ~-0.025029800902873708 41:0.546875:13773:13814 8:0.875:13774:13813 245:1.0595238095238095:13775:13776 ~-0.041565963410084464 256:0.01818181818181818:13777:13802 "
    s .= "247:0.578125:13778:13799 59:0.4375:13779:13798 122:-0.078125:13780:13781 ~0.0022133679936307145 124:0.203125:13782:13793 5:-0.234375:13783:13788 164:0.265625:13784:13787 109:0.5625:13785:13786 ~-0.017386796049447713 "
    s .= "~0.03781254968504591 ~-0.04154746938693051 68:-0.09375:13789:13790 ~-0.037903576949620044 99:0.25:13791:13792 ~-0.007062965357127921 ~0.025782993010859307 79:0.34375:13794:13795 ~-0.03564246299970613 "
    s .= "190:0.234375:13796:13797 ~0.009587860832098147 ~-0.03600973438205385 ~0.02399333907493124 75:0.6484375:13800:13801 ~-0.0657169946924656 ~0.0037101115325721933 227:-0.359375:13803:13806 30:0.1640625:13804:13805 "
    s .= "~-0.05119361942587598 ~0.010782599626458125 19:-0.234375:13807:13810 120:0.109375:13808:13809 ~-0.07522679211946964 ~0.00026521521256624966 71:0.5625:13811:13812 ~0.022596871581025076 ~-0.022646463508197892 "
    s .= "~0.03933855289459101 107:0.46875:13815:13818 88:0.4375:13816:13817 ~0.028859009668162662 ~-0.027164365613919956 ~-0.030812933147888712 34:0.015625:13820:13845 166:0.84375:13821:13844 136:2.109375:13822:13843 "
    s .= "184:0.609375:13823:13842 88:0.046875:13824:13839 106:0.359375:13825:13834 178:-0.109375:13826:13829 217:-0.09375:13827:13828 ~-0.029540443719931093 ~0.046982776258603726 142:0.5625:13830:13833 213:0.625:13831:13832 "
    s .= "~-0.048767509537338855 ~0.017282997905502834 ~0.03642651660933591 112:1.1875:13835:13836 ~0.015673748962022695 243:0.75:13837:13838 ~-0.04811485342927335 ~0.03425047299856438 243:1.35:13840:13841 ~0.013213702600398006 "
    s .= "~-0.024074891719728604 ~0.017549200538480345 ~-0.03217982763637128 ~-0.021545337078486174 251:0.328125:13846:13851 219:0.0625:13847:13850 66:-0.046875:13848:13849 ~-0.015055062089096592 ~-0.054222300837192476 "
    s .= "~-0.001177743820799825 7:-0.0625:13852:13853 ~-0.015546343436104407 25:1.125:13854:13865 19:0.15625:13855:13860 249:0.8333333333333333:13856:13859 177:0.265625:13857:13858 ~0.008467399709068846 ~-0.021500462261477025 "
    s .= "~-0.029669705367117934 151:0.40625:13861:13862 ~0.019138128174638218 24:0.3125:13863:13864 ~-0.018476429693085505 ~0.02569398992216882 ~-0.028198027404230344 5:-1.484375:13867:13870 22:0.421875:13868:13869 "
    s .= "~0.0343547013926814 ~-0.042199731503287104 246:-2.421875:13871:13884 230:-0.9375:13872:13879 158:-1.53125:13873:13874 ~0.026841092543681513 112:-0.1875:13875:13876 ~-0.09245739876919788 118:0.375:13877:13878 "
    s .= "~0.0036164727671062513 ~-0.0449716880760512 126:-0.8125:13880:13881 ~0.031626491486220216 88:1.328125:13882:13883 ~-0.058178721146203254 ~-0.008231905759730488 154:1.984375:13885:13908 154:0.609375:13886:13899 "
    s .= "100:1.015625:13887:13896 139:0.875:13888:13891 232:0.984375:13889:13890 ~-0.0072447496141514415 ~0.03359404495533075 160:0.265625:13892:13895 244:1.115:13893:13894 ~0.020459405331035574 ~-0.029112690638107716 "
    s .= "~0.02207529582030173 114:0.5234375:13897:13898 ~0.0249832963384466 ~-0.05741961774023158 172:-0.171875:13900:13903 245:1.6842105263157894:13901:13902 ~0.01597465864700387 ~-0.042217540025917044 190:0.4375:13904:13907 "
    s .= "156:0.3671875:13905:13906 ~0.015733723637863985 ~-0.03383703152876328 ~-0.011402947295784652 205:0.09375:13909:13910 ~-0.04707596924801935 250:1.2421875:13911:13912 ~-0.03165903378661767 ~0.03969106810458428 "
    s .= "97:1.75:13914:13959 247:0.796875:13915:13952 107:0.96875:13916:13951 192:0.984375:13917:13950 224:0.578125:13918:13947 169:1.796875:13919:13944 49:0.8125:13920:13935 226:0.875:13921:13928 244:2.81:13922:13923 "
    s .= "~0.0012472543448702122 4:0:13924:13925 ~0.005209649820652963 151:0.140625:13926:13927 ~-0.08059594599842711 ~-0.009666613068303596 217:-0.140625:13929:13930 ~-0.04417833424769502 157:-0.046875:13931:13932 "
    s .= "~-0.029278592962280605 43:0.375:13933:13934 ~0.03615249003835321 ~-0.03581400110028612 139:1.515625:13936:13943 65:-0.5:13937:13938 ~-0.05281485781009773 3:-0.234375:13939:13940 ~0.03544487379618979 "
    s .= "81:0.0546875:13941:13942 ~-0.05237719214460471 ~0.0014010552232815807 ~0.03207328284845906 9:0.3359375:13945:13946 ~0.05356018356009993 ~-0.03393676438702427 109:1.1875:13948:13949 ~-0.03223842640810221 "
    s .= "~0.018625065793774594 ~-0.04711642919650244 ~0.026113439101840233 9:0.3203125:13953:13954 ~-0.05357729660946802 246:1.328125:13955:13956 ~-0.041693502064488165 53:0.21875:13957:13958 ~0.057065750075943035 "
    s .= "~-0.02847433877422531 ~-0.030135947462843204 253:-0.09898989898990054:13961:13978 257:0.6:13962:13977 38:-0.390625:13963:13964 ~0.026663539701942015 249:0.16666666666666666:13965:13970 244:0.905:13966:13967 "
    s .= "~-0.053963637774786445 208:-0.234375:13968:13969 ~-0.031149636341754272 ~0.026936771148078506 58:0.046875:13971:13972 ~0.013573826155974016 61:0.5:13973:13976 158:-0.328125:13974:13975 ~0.021073477329112387 "
    s .= "~-0.04841437262486263 ~0.007362210530847822 ~-0.022987239321916108 217:0.1875:13979:13992 108:0.1328125:13980:13989 106:1.78125:13981:13982 ~0.00602679453727493 167:-0.859375:13983:13984 ~0.032179871336375114 "
    s .= "220:0.046875:13985:13988 12:0.015625:13986:13987 ~-0.0685080194789942 ~-0.011404149752378832 ~0.0032777066235834466 231:0.046875:13990:13991 ~-0.03175334692372276 ~-0.0033981304717103818 243:0.25:13993:13996 "
    s .= "94:-0.0625:13994:13995 ~-0.05348673510001755 ~0.04092620998942087 244:1.085:13997:13998 ~-0.02437031690632926 250:0.6796875:13999:14000 ~-0.05154020480295754 194:0.15625:14001:14006 223:0.1875:14002:14003 "
    s .= "~-0.013877674875172344 214:-0.03125:14004:14005 ~-0.029212070162458234 ~0.023708934763758988 ~-0.03362697383564311 254:1.296875:14008:14045 144:-0.828125:14009:14012 244:1.49:14010:14011 ~-0.052279278574125614 "
    s .= "~0.013468812489338417 170:-1.15625:14013:14016 8:-0.375:14014:14015 ~0.026607276225826506 ~-0.03968522001957528 246:-2.640625:14017:14022 129:-0.2265625:14018:14021 206:-1.09375:14019:14020 ~0.026605048836432985 "
    s .= "~-0.024704161838021804 ~-0.06497228400361102 257:0.9090909090909091:14023:14038 125:-0.453125:14024:14025 ~0.008754423041953582 246:0.015625:14026:14035 247:-0.015625:14027:14034 109:1.703125:14028:14031 "
    s .= "249:0.16666666666666666:14029:14030 ~0.01723502506794411 ~-0.008772250547373435 226:0.1875:14032:14033 ~-0.04135340066669125 ~0.007399225460180921 ~-0.023948855281946513 77:0.015625:14036:14037 ~0.011631896507756721 "
    s .= "~-0.0022836260766622685 109:0.765625:14039:14040 ~-0.03955324269513191 190:0.421875:14041:14044 180:-0.390625:14042:14043 ~-0.021711113891029078 ~0.049163557288062903 ~-0.042994656715782585 244:1.32:14046:14049 "
    s .= "18:-0.3046875:14047:14048 ~0.01441738480915285 ~-0.03927183818702604 214:-0.03125:14050:14051 ~-0.031212527996717084 55:-0.15625:14052:14053 ~-0.03452776950443264 ~0.020770773634985557 196:1.234375:14055:14096 "
    s .= "85:-0.46875:14056:14059 58:0.359375:14057:14058 ~0.028189483559355317 ~-0.04142950309780601 219:0.875:14060:14095 31:0.328125:14061:14080 55:0.109375:14062:14075 205:0.125:14063:14074 250:1.3515625:14064:14073 "
    s .= "8:0.4375:14065:14072 106:0.515625:14066:14071 70:0.4375:14067:14070 252:0.175:14068:14069 ~-0.03111249785379891 ~0.007820547154317967 ~0.020692463121835248 ~0.007293550550076901 ~0.03505125201617493 "
    s .= "~-0.025411324638690665 ~0.008883780560926952 252:0.125:14076:14077 ~-0.020149878242547867 181:0.1875:14078:14079 ~0.01541587892644571 ~-0.010671837929909772 251:0.203125:14081:14082 ~-0.03777284739424151 "
    s .= "77:0.5:14083:14094 184:0.234375:14084:14085 ~0.02526518876112214 193:-0.359375:14086:14087 ~0.05027507204713785 169:0.125:14088:14091 79:1.3125:14089:14090 ~-0.05082662908330541 ~0.015690014252658892 "
    s .= "222:-0.296875:14092:14093 ~-0.04659903448341011 ~0.015708388273277692 ~-0.03454289530809082 ~-0.032115823265698396 76:1.140625:14097:14100 175:-0.03125:14098:14099 ~-0.040866440043501595 ~0.030823221011115468 "
    s .= "~-0.042969559138308244 "
    return s
}

ModelBBase() => -0.053834890007748035
ModelBRoots() {
    return "1 48 95 142 189 236 283 330 377 424 471 518 565 612 659 706 753 800 847 894 941 988 1035 1082 1129 1176 1223 1270 1317 1364 1411 1458 1505 1552 1599 1646 1693 1740 1787 1834 1881 1928 1975 2022 2069 2116 2163 2210 2257 2304 2351 2398 2445 2492 2539 2586 2633 2680 2727 2774 2821 2868 2915 2962 3009 3056 3103 3150 3197 3244 3291 3338 3385 3432 3479 3526 3573 3620 3667 3714 3761 3808 3855 3902 3949 3996 4043 4090 4137 4184 4231 4278 4325 4372 4419 4466 4513 4560 4607 4654 4701 4748 4795 4842 4889 4936 4983 5030 5077 5124 5171 5218 5265 5312 5359 5406 5453 5500 5547 5594 5641 5688 5735 5782 5829 5876 5923 5970 6017 6064 6111 6158 6205 6252 6299 6346 6393 6440 6487 6534 6581 6628 6675 6722 6769 6816 6863 6910 6957 7004 7051 7098 7145 7192 7239 7286 7333 7380 7427 7474 7521 7568 7615 7662 7709 7756 7803 7850 7897 7944 7991 8038 8085 8132 8179 8226 8273 8320 8367 8414 8461 8508 8555 8602 8649 8696 8743 8790 8837 8884 8931 8978 9025 9072 9119 9166 9213 9260 9307 9354 9401 9448 9495 9542 9589 9636 9683 9730 9777 9824 9871 9918 9965 10012 10059 10106 10153 10200 10247 10294 10341 10388 10435 10482 10529 10576 10623 10670 10717 10764 10811 10858 10905 10952 10999 11046 11093 11140 11187 11234 11281 11328 11375 11422 11469 11516 11563 11610 11657 11704 11751 11798 11845 11892 11939 11986 12033 12080 12127 12174 12221 12268 12315 12362 12409 12456 12503 12550 12597 12644 12691 12738 12785 12832 12879 12926 12973 13020 13067 13114 13161 13208 13255 13302 13349 13396 13443 13490 13537 13584 13631 13678 13725 13772 13819 13866 13913 13960 14007 14054"
}

ModelBText() {
    s := ""
    s .= "253:-0.011337868480727107:2:21 244:0.88:3:6 127:0.9375:4:5 ~-0.08984483936345103 ~0.033869435455920104 249:1.8333333333333335:7:18 31:0.78125:8:17 248:0.875:9:14 241:0.16:10:13 181:0.515625:11:12 ~-0.08849897693185821 "
    s .= "~0.0849727684016389 ~0.09475295495888444 243:0.6499999999999999:15:16 ~-0.08696167153686903 ~0.025283784033139863 ~-0.08302174842053799 222:0.25:19:20 ~-0.09546476146131071 ~0.08571589441710975 248:0.375:22:41 "
    s .= "251:0.578125:23:32 229:1.046875:24:29 242:0.6499999999999999:25:28 109:1.1875:26:27 ~-0.06977412369989944 ~0.05657672517778248 ~-0.09157395625951344 232:0.65625:30:31 ~0.10044938566721447 ~-0.07462925987976926 "
    s .= "244:0.855:33:34 ~-0.0932951325035965 232:-0.203125:35:36 ~-0.015414836377559138 236:0.59375:37:40 243:0.45:38:39 ~0.02688988626227869 ~0.07941290917543829 ~-0.08058751070941411 251:2.515625:42:47 45:0.3515625:43:44 "
    s .= "~-0.09035676599340613 88:1.453125:45:46 ~-0.07991568376479531 ~0.08082235539126209 ~0.05519450580974147 253:-0.011337868480727107:49:66 244:0.88:50:53 127:0.9375:51:52 ~-0.08574216099681468 ~0.032170044942467564 "
    s .= "249:1.8333333333333335:54:63 31:0.78125:55:62 248:0.875:56:61 241:0.16:57:60 181:0.515625:58:59 ~-0.08447810960348313 ~0.0807508437358335 ~0.08998555684789432 ~-0.03319715092215544 ~-0.07919734241266653 222:0.25:64:65 "
    s .= "~-0.0911453007000122 ~0.08148358837527951 248:0.375:67:88 251:0.578125:68:79 229:1.046875:69:76 242:0.6499999999999999:70:75 109:0.953125:71:72 ~-0.07189100166277879 211:-0.15625:73:74 ~-0.08329705901936096 "
    s .= "~0.05693868555691797 ~-0.08740305382874754 244:1.035:77:78 ~-0.09171793417550658 ~0.09306725741514235 244:0.855:80:81 ~-0.08907484864542438 217:-0.140625:82:83 ~-0.00509501063054184 31:0.625:84:87 212:0.578125:85:86 "
    s .= "~0.07414490179836179 ~-0.05329879087480434 ~-0.04757514764135301 251:2.515625:89:94 45:0.3515625:90:91 ~-0.08623233172955215 85:1.125:92:93 ~-0.07814253177856346 ~0.06814790421646195 ~0.05241311326018673 "
    s .= "253:-0.011337868480727107:96:115 244:0.88:97:100 127:0.9375:98:99 ~-0.0821247353452606 ~0.030573411286314345 249:1.8333333333333335:101:112 31:0.78125:102:111 248:0.875:103:108 241:0.16:104:107 181:0.515625:105:106 "
    s .= "~-0.08092294026134804 ~0.07700025441913874 ~0.08582453258763084 243:0.6499999999999999:109:110 ~-0.08155100511247854 ~0.025683161052252098 ~-0.07578285015174747 222:0.25:113:114 ~-0.08737983616108813 "
    s .= "~0.07772732619376958 248:0.375:116:135 251:0.546875:117:128 229:1.046875:118:125 244:1.085:119:120 ~-0.08317480735077944 242:0.55:121:124 112:0.9375:122:123 ~-0.03024287876446512 ~0.06064677752739947 "
    s .= "~-0.07561689560554147 232:0.65625:126:127 ~0.09147364576062954 ~-0.06935716712388117 244:0.855:129:130 ~-0.08602848836909498 232:-0.203125:131:132 ~-0.01802676146105299 236:0.59375:133:134 ~0.06296152325269218 "
    s .= "~-0.07562111669989352 251:2.640625:136:141 45:0.3515625:137:138 ~-0.08256914501277009 85:1.125:139:140 ~-0.07443557962725587 ~0.06483352137612639 ~0.054287762059463986 253:-0.014492753623187582:143:166 244:0.88:144:147 "
    s .= "127:0.9375:145:146 ~-0.0787004130308371 ~0.03950801170502232 249:1.8333333333333335:148:163 31:0.78125:149:162 248:0.625:150:157 243:0.45:151:156 244:1.345:152:153 ~-0.05930275575084281 181:0.0625:154:155 "
    s .= "~-0.09209951409489811 ~0.08754917294237011 ~0.08459423264281546 243:0.55:158:159 ~-0.07290655802768656 19:-0.078125:160:161 ~-0.037706154290650426 ~0.06725129910154154 ~-0.07386041545769809 222:0.25:164:165 "
    s .= "~-0.08402843582130862 ~0.07450552179855319 248:0.375:167:184 251:0.578125:168:177 244:1.835:169:174 245:2.1:170:171 ~-0.07485308868717465 158:-0.453125:172:173 ~0.036608220679488934 ~-0.06519476121489191 "
    s .= "243:0.6499999999999999:175:176 ~0.07356803842016423 ~-0.05870207401339829 244:0.855:178:179 ~-0.08194720481179632 220:-0.125:180:181 ~-0.005432867477348352 31:0.625:182:183 ~0.06454814741958609 ~-0.040155003854723544 "
    s .= "251:2.171875:185:186 ~-0.07648444022189593 222:0.515625:187:188 ~-0.06816057223930222 ~0.08744651023273735 253:-0.02063213345039472:190:203 244:0.86:191:192 ~-0.07541477433971062 249:1.8333333333333335:193:202 "
    s .= "31:0.78125:194:201 248:0.625:195:198 241:0.16:196:197 ~-0.008808592984910756 ~0.08006435255787908 243:0.55:199:200 ~-0.07018111641459018 ~0.04644891205429325 ~-0.07110188057800476 ~-0.07501619801125309 248:0.375:204:227 "
    s .= "251:0.546875:205:218 244:1.835:206:213 245:1.7857142857142858:207:208 ~-0.07876384485377193 217:-0.078125:209:210 ~-0.08237003383250589 244:1.11:211:212 ~-0.056127598162018115 ~0.03177560110614953 "
    s .= "242:0.8500000000000001:214:217 28:0.0625:215:216 ~0.0764186656490963 ~-0.07535964519944637 ~-0.07351817044366842 244:0.855:219:220 ~-0.07985008334354174 243:0.45:221:224 3:0.296875:222:223 ~-0.04076976857089424 "
    s .= "~0.05387792598307715 235:-0.28125:225:226 ~-0.030620936324306982 ~0.06414141318473789 251:2.140625:228:233 248:0.625:229:232 109:1.140625:230:231 ~-0.06708731174522004 ~-0.0002449469070328024 ~-0.07831653627697088 "
    s .= "195:0.5:234:235 ~-0.05321793452939562 ~0.08413679241739255 253:-0.011337868480727107:237:254 244:0.88:238:241 127:0.9375:239:240 ~-0.07369781717918168 ~0.029970318379621344 249:1.8333333333333335:242:251 "
    s .= "31:0.78125:243:250 248:0.875:244:249 241:0.16:245:246 ~-0.026958954122351764 257:0.9795918367346939:247:248 ~0.076812213058086 ~-0.006829975014582292 ~-0.02920975715961609 ~-0.06731687165969216 222:0.25:252:253 "
    s .= "~-0.07872617730992464 ~0.07435313749050503 248:0.375:255:276 251:0.546875:256:267 229:1.046875:257:264 244:1.085:258:259 ~-0.07460833147975192 242:0.55:260:263 241:0.12:261:262 ~-0.047137565755521055 "
    s .= "~0.039390638530325664 ~-0.06794277756161388 232:1.078125:265:266 ~0.08107100690463126 ~-0.0750523632650326 244:0.855:268:269 ~-0.07728210038651337 251:1.203125:270:275 109:0.71875:271:272 ~-0.03419378114459946 "
    s .= "232:-0.171875:273:274 ~-0.05310472729671302 ~0.05891406257600186 ~0.06852731933901143 251:2.515625:277:282 45:0.3515625:278:279 ~-0.07407180957728826 88:1.453125:280:281 ~-0.0644349359873979 ~0.07686089906979593 "
    s .= "~0.0436556374017395 253:-0.02063213345039472:284:303 244:0.86:285:286 ~-0.07054563641079002 249:1.8333333333333335:287:302 31:0.78125:288:301 248:0.625:289:296 243:0.45:290:295 211:0.015625:291:292 ~-0.07723788748530745 "
    s .= "244:1.355:293:294 ~-0.034223591380240816 ~0.07919508514849655 ~0.07582557416044691 243:0.55:297:298 ~-0.06731059216093094 55:-0.21875:299:300 ~-0.07730609373008385 ~0.05591819561143971 ~-0.06621808039373998 "
    s .= "~-0.07019901066227872 248:0.375:304:319 251:0.546875:305:310 136:1.171875:306:307 ~-0.06443822279426957 242:0.55:308:309 ~0.06785155545275263 ~-0.05443185848379631 244:0.855:311:312 ~-0.07487608317145932 "
    s .= "193:-0.171875:313:314 ~-0.015624919944917347 31:0.625:315:318 236:0.59375:316:317 ~0.06012712149278207 ~-0.061667397004814786 ~-0.04594415639544491 251:2.078125:320:327 248:0.625:321:326 109:1.140625:322:323 "
    s .= "~-0.06242280545345517 211:-0.03125:324:325 ~-0.06848430086454596 ~0.06735747604028673 ~-0.07341407755565851 195:0.5:328:329 ~-0.0521553059788582 ~0.0783018626212325 253:-0.02063213345039472:331:350 244:0.86:332:333 "
    s .= "~-0.06833134020885855 249:1.8333333333333335:334:347 31:0.78125:335:346 248:0.625:336:343 243:0.45:337:342 211:0.015625:338:339 ~-0.07335000105213342 244:1.355:340:341 ~-0.032485243882723155 ~0.07665921197016776 "
    s .= "~0.07339534700888409 243:0.55:344:345 ~-0.06470392147461297 ~0.04098518594972384 ~-0.06404354967769874 222:0.25:348:349 ~-0.0743187323668456 ~0.07538847293283585 251:1.140625:351:370 244:1.23:352:359 "
    s .= "251:0.828125:353:354 ~-0.07004567848051989 47:-0.125:355:358 220:-0.09375:356:357 ~-0.07117363037338884 ~0.047227733369414576 ~-0.06406879309598619 235:0:360:363 211:0.015625:361:362 ~-0.0674996843737465 "
    s .= "~0.002794058553630066 248:0.875:364:369 31:0.234375:365:368 94:0.578125:366:367 ~0.06439533870498705 ~-0.05134239583295408 ~-0.04477501480103581 ~-0.06919542015637309 248:0.625:371:376 220:-0.203125:372:375 "
    s .= "241:0.72:373:374 ~-0.07750255046244287 ~0.05187501288062504 ~0.06496499120998035 ~-0.05546281576362321 253:-0.011337868480727107:378:397 244:0.88:379:382 127:0.9375:380:381 ~-0.06764833131828211 ~0.033895706701278026 "
    s .= "249:1.5:383:394 31:0.859375:384:393 248:0.875:385:392 241:0.16:386:387 ~-0.024271403190497184 257:0.9130434782608695:388:389 ~0.07045788116694594 254:0.015625:390:391 ~0.06609311058460066 ~-0.08339161357381918 "
    s .= "~-0.031022028165905508 ~-0.06463296922327087 222:0.25:395:396 ~-0.07098618472298714 ~0.06481260628197581 248:0.375:398:417 251:0.546875:399:410 229:1.046875:400:407 242:0.6499999999999999:401:406 109:0.890625:402:403 "
    s .= "~-0.0585885706310059 211:-0.15625:404:405 ~-0.0731549144185915 ~0.049186057598034266 ~-0.07072366430260095 244:1.035:408:409 ~-0.07593327215084665 ~0.07394341991549616 244:0.855:411:412 ~-0.07123785507288614 "
    s .= "243:0.45:413:416 144:0.15625:414:415 ~-0.04206022093063059 ~0.046443292646319995 ~0.049973854446006744 45:0.3515625:418:419 ~-0.06766294797930765 109:1.4375:420:421 ~-0.055794858763444456 88:0.453125:422:423 "
    s .= "~-0.06009961950983819 ~0.07829014154777286 253:-0.02063213345039472:425:442 244:0.86:426:427 ~-0.06457479883588231 249:1.5:428:439 31:0.78125:429:438 248:0.875:430:437 243:0.45:431:436 181:0.5:432:435 "
    s .= "222:0.140625:433:434 ~-0.07261099331781061 ~0.039959803768585565 ~0.06940521913908632 ~0.06912726220238972 ~-0.02292636114931695 ~-0.060319962061796885 33:0.25:440:441 ~-0.06840399542903229 ~0.06674566940584854 "
    s .= "248:0.375:443:458 251:0.546875:444:451 244:1.545:445:446 ~-0.059251137989408245 242:0.8500000000000001:447:450 28:0.0625:448:449 ~0.062232024459227514 ~-0.05602069589220202 ~-0.06359488853265781 244:0.855:452:453 "
    s .= "~-0.06941720912497536 232:-0.203125:454:455 ~-0.018928083291324047 236:0.609375:456:457 ~0.05026702804567551 ~-0.07689312517401697 251:2.078125:459:470 38:-0.15625:460:469 92:-0.0625:461:466 248:0.625:462:465 "
    s .= "136:1.109375:463:464 ~-0.05116901370157263 ~0.028048652376587543 ~-0.06674695577297411 160:1.21875:467:468 ~-0.03950973836133444 ~0.08540738340389856 ~-0.06989040501056171 ~0.027668712678093565 "
    s .= "253:-0.011337868480727107:472:495 244:0.88:473:478 232:0.6875:474:475 ~-0.06587740821130013 32:-0.40625:476:477 ~0.08487268000085428 ~-0.07307734225041558 249:1.5:479:492 31:0.71875:480:491 248:0.875:481:490 "
    s .= "243:0.45:482:487 244:1.355:483:484 ~-0.058512860516879164 181:0.0625:485:486 ~-0.08811924929273644 ~0.07071861806235864 200:0.765625:488:489 ~0.06749617561399417 ~-0.09957950802163047 ~-0.02828410795935027 "
    s .= "~-0.05445721208420101 222:0.25:493:494 ~-0.06742505579028084 ~0.06187409958897414 248:0.375:496:511 251:0.546875:497:502 136:1.171875:498:499 ~-0.056911495776420434 242:0.55:500:501 ~0.06080003929233862 "
    s .= "~-0.04838641598260595 244:0.855:503:504 ~-0.06776595893212826 251:1.203125:505:510 109:0.78125:506:507 ~-0.03269644642604274 232:-0.171875:508:509 ~-0.04794305631440094 ~0.05212686039788215 ~0.05860772245131029 "
    s .= "45:0.3515625:512:513 ~-0.06414869824152118 109:1.4375:514:515 ~-0.05205115687322655 88:0.453125:516:517 ~-0.05643928768655479 ~0.07384635689057456 253:-0.02063213345039472:519:538 244:0.86:520:521 ~-0.061322749270201704 "
    s .= "249:1.8333333333333335:522:537 31:0.78125:523:536 248:0.625:524:531 257:0.9130434782608695:525:528 200:0.765625:526:527 ~0.06530466568772113 ~-0.09213619778975757 245:1.575:529:530 ~-0.10978694589968166 "
    s .= "~0.05156026421702508 243:0.55:532:533 ~-0.0607718513062743 19:-0.078125:534:535 ~-0.04512625237950221 ~0.054411012481281454 ~-0.05694738030282037 ~-0.06154302541889387 251:1.140625:539:560 244:1.225:540:547 "
    s .= "251:0.828125:541:542 ~-0.063497805577047 47:-0.125:543:546 220:-0.09375:544:545 ~-0.06587731287730512 ~0.04719938062384563 ~-0.05775270981267588 235:0:548:551 211:0.015625:549:550 ~-0.06123656220853116 "
    s .= "~0.005273526063614585 248:0.875:552:559 31:0.234375:553:558 94:0.578125:554:557 157:0.171875:555:556 ~0.00006595741489201837 ~0.0672529173805728 ~-0.04781468817941034 ~-0.039711362645386925 ~-0.062458999418477316 "
    s .= "248:0.625:561:564 220:-0.203125:562:563 ~-0.025767322432612528 ~0.058644984832338765 ~-0.048326045215885016 253:-0.006628787878785403:566:589 244:0.88:567:572 2:-0.640625:568:571 246:0.046875:569:570 "
    s .= "~-0.05904803281362382 ~0.08476336895658237 ~-0.0647214780964231 249:1.5:573:586 31:0.859375:574:585 248:0.625:575:580 257:0.9130434782608695:576:577 ~0.06340773577123486 254:0.015625:578:579 ~0.060481213869900824 "
    s .= "~-0.07721392540025052 243:0.55:581:582 ~-0.057607537457195115 140:0.28125:583:584 ~0.05017714886679534 ~-0.059820741248679324 ~-0.057826043184074506 189:0.203125:587:588 ~-0.06485467057378305 ~0.061904441502956535 "
    s .= "248:0.375:590:607 251:0.546875:591:602 229:1.046875:592:599 242:0.6499999999999999:593:598 109:0.890625:594:595 ~-0.05190631087837978 211:-0.15625:596:597 ~-0.06721318997743732 ~0.0494141878316951 ~-0.06535594890794486 "
    s .= "232:1.078125:600:601 ~0.06867138825215906 ~-0.0656134270557293 29:-0.03125:603:606 27:0.015625:604:605 ~0.010124354423403871 ~0.054949419999035944 ~-0.019147665591887086 45:0.3515625:608:609 ~-0.061378795696342504 "
    s .= "109:1.40625:610:611 ~-0.050680881811421157 ~0.04277360455085963 253:-0.02063213345039472:613:634 244:0.86:614:615 ~-0.05848728603450795 249:1.5:616:631 31:0.78125:617:630 248:0.625:618:625 243:0.45:619:624 "
    s .= "211:0.015625:620:621 ~-0.07290532377234198 244:1.355:622:623 ~-0.033818469574857256 ~0.06666316011368897 ~0.0631987609886042 243:0.55:626:627 ~-0.05555624438933709 140:0.25:628:629 ~0.04972623314405359 "
    s .= "~-0.05922286021130833 ~-0.054033178672950724 195:0.1875:632:633 ~-0.06395318655366529 ~0.05303793439806476 248:0.625:635:658 244:1.085:636:645 251:0.828125:637:642 220:0.875:638:639 ~-0.06117881379852955 "
    s .= "193:0.1875:640:641 ~0.08185100395939549 ~-0.0619898005328231 56:0.265625:643:644 ~0.048894025787512396 ~-0.04538087290805574 235:-0.015625:646:651 3:0.390625:647:650 163:-0.28125:648:649 ~-0.06958241190953311 "
    s .= "~-0.0206578725288354 ~0.049924465652849206 28:0.3125:652:655 157:0.125:653:654 ~0.011147361578714605 ~0.056734680108468286 251:0.453125:656:657 ~-0.0655806736240469 ~0.040986435639228845 ~-0.06169489365110418 "
    s .= "253:-0.006628787878785403:660:685 244:0.895:661:666 2:-0.640625:662:665 31:0.015625:663:664 ~0.06240947270224928 ~-0.06831207277512434 ~-0.06081403169044386 249:1.5:667:682 31:0.859375:668:681 248:0.875:669:680 "
    s .= "243:0.45:670:675 244:1.355:671:672 ~-0.06620726529870746 181:0.0625:673:674 ~-0.08664111777270886 ~0.06438513270469833 243:2.1500000000000004:676:677 ~0.06229179957541584 252:2.125:678:679 ~-0.1332434410325577 "
    s .= "~0.041400709464201185 ~-0.02214421426473634 ~-0.05477685200509019 195:0.1875:683:684 ~-0.06345901365397498 ~0.052155371444957827 248:0.625:686:705 244:1.085:687:696 251:0.828125:688:693 220:0.875:689:690 "
    s .= "~-0.05953733184856102 193:0.1875:691:692 ~0.07874276529059715 ~-0.05974997510575883 47:0.265625:694:695 ~0.04498047216352923 ~-0.057796182269996214 235:-0.015625:697:700 217:0:698:699 ~-0.0504179060565222 "
    s .= "~0.013565713095169572 31:0.296875:701:704 149:0.03125:702:703 ~0.054953765380912505 ~0.0018416354231312077 ~-0.017101349544873325 ~-0.060883461980682944 248:0.375:707:734 253:-0.02063213345039472:708:717 "
    s .= "7:0.765625:709:716 244:0.84:710:711 ~-0.0465929245579851 243:2.3499999999999996:712:713 ~0.06017420270768398 58:-0.046875:714:715 ~-0.12397212982244193 ~0.047001753890290904 ~-0.059452993900878374 251:0.546875:718:723 "
    s .= "136:1.171875:719:720 ~-0.0504630185828748 242:0.55:721:722 ~0.05370668180092419 ~-0.04149166225895141 244:0.855:724:725 ~-0.06292134156266825 243:0.45:726:729 3:0.234375:727:728 ~-0.043861480256848134 "
    s .= "~0.03380226478303323 31:0.625:730:733 223:-0.046875:731:732 ~0.014688641994682703 ~0.05607235248609304 ~-0.040073429634178453 144:0.328125:735:746 252:0.125:736:737 ~-0.059244704280358454 109:0.9375:738:741 "
    s .= "251:1.609375:739:740 ~-0.05776461746544484 ~0.035164831804696914 229:-0.171875:742:743 ~-0.06451013535441447 121:0.5:744:745 ~0.05355241607983559 ~-0.04963063698562786 244:0.9:747:748 ~-0.05711145504817092 "
    s .= "217:-0.171875:749:750 ~-0.05782399576753538 243:0.35:751:752 ~-0.03907680724161118 ~0.06337887118635242 253:-0.02063213345039472:754:775 244:0.86:755:756 ~-0.05487921041944305 249:1.5:757:772 7:0.765625:758:771 "
    s .= "243:0.45:759:764 181:0.5:760:763 222:0.171875:761:762 ~-0.06534730769021495 ~0.03191473116841774 ~0.05807375512979959 243:2.1500000000000004:765:768 200:0.765625:766:767 ~0.05915904904860193 ~-0.08817438169362961 "
    s .= "252:2.125:769:770 ~-0.11304979813064926 ~0.045533520231521296 ~-0.05483485394886333 33:0.25:773:774 ~-0.059801475489776684 ~0.06279583043777912 251:1.140625:776:795 244:1.225:777:784 251:0.828125:778:779 "
    s .= "~-0.05725947408389333 47:-0.125:780:783 220:-0.09375:781:782 ~-0.06315558282151433 ~0.04591992906933496 ~-0.05243201142435155 235:0.015625:785:788 211:0.015625:786:787 ~-0.05502144505305963 ~0.010992574873053083 "
    s .= "248:0.875:789:794 97:0.21875:790:793 94:0.546875:791:792 ~0.054112723440875976 ~-0.04468798726184086 ~-0.0461881608480785 ~-0.05540375859813817 248:0.625:796:799 220:-0.203125:797:798 ~-0.022557481090796347 "
    s .= "~0.052676137428101844 ~-0.0402055112767748 248:0.375:801:826 244:0.855:802:803 ~-0.055797543318607735 251:0.328125:804:813 31:0.234375:805:812 243:1.25:806:811 193:0.265625:807:810 46:0.25:808:809 ~0.04937375347228175 "
    s .= "~-0.05276397251617633 ~-0.04771821850650388 ~-0.06355443887009248 ~-0.06733959009658214 253:-0.0007518796992452995:814:817 200:0.765625:815:816 ~0.057899831942897884 ~-0.0924916463173896 226:-0.3125:818:819 "
    s .= "~-0.0600399445931471 73:0.1875:820:823 5:-0.15625:821:822 ~0.05155441667677102 ~0.008791824854995753 251:1.484375:824:825 ~-0.040545859715952294 ~0.055618406070700045 251:0.796875:827:840 61:1.34375:828:837 "
    s .= "109:0.640625:829:830 ~-0.06235294015170342 72:0.15625:831:832 ~-0.054715882136104094 85:0.828125:833:834 ~-0.039955278161882615 41:0.125:835:836 ~0.07462419532545386 ~-0.06338983559202367 34:-0.171875:838:839 "
    s .= "~-0.07399805504393717 ~0.056265126120592215 55:-0.203125:841:842 ~-0.05872282927871594 197:0.171875:843:846 243:0.45:844:845 ~-0.019428900661575196 ~0.05413205266739718 ~-0.037797358925070614 248:0.375:848:879 "
    s .= "253:-0.02063213345039472:849:858 7:0.765625:850:857 244:0.82:851:852 ~-0.04841513723996678 243:2.3499999999999996:853:854 ~0.05657447079137389 251:0.609375:855:856 ~-0.09960125867853656 ~0.050313049660678635 "
    s .= "~-0.05570406824200485 251:0.546875:859:870 136:1.171875:860:865 67:0.1875:861:864 206:-0.015625:862:863 ~-0.011115493349013433 ~-0.0559417963187113 ~-0.06226096615067738 242:0.55:866:869 130:0.09375:867:868 "
    s .= "~-0.0686879025182296 ~0.05865468858050891 ~-0.0384760422622433 244:0.855:871:872 ~-0.05996477748145723 243:0.45:873:876 3:0.234375:874:875 ~-0.04186914908524609 ~0.03076734707203893 235:-0.28125:877:878 "
    s .= "~-0.02934587421886304 ~0.04355507254501392 192:0.34375:880:889 252:0.125:881:882 ~-0.05601321551128994 244:0.98:883:884 ~-0.055180830470178494 229:-0.09375:885:886 ~-0.051971221154882646 218:0.09375:887:888 "
    s .= "~0.05224427830705658 ~-0.030333832046718502 244:0.9:890:891 ~-0.05298611055540756 193:-0.140625:892:893 ~-0.04439335117697434 ~0.056650020016330085 248:0.625:895:934 244:0.855:896:897 ~-0.055168337001395965 "
    s .= "253:-0.006628787878785403:898:917 31:0.71875:899:916 249:1.5:900:913 257:0.9130434782608695:901:910 256:0.9545454545454546:902:909 241:0.22:903:908 181:0.40625:904:907 205:0.453125:905:906 ~-0.0791633082974931 "
    s .= "~0.0799410659640561 ~0.05813532282999304 ~0.05731729597956247 ~-0.10726405672071944 245:1.5666666666666667:911:912 ~-0.10791164334954995 ~0.03518849439207678 192:0.125:914:915 ~-0.05895229244238012 ~0.05065313319283948 "
    s .= "~-0.04771067631759829 235:-0.078125:918:923 251:1.765625:919:922 129:-0.9921875:920:921 ~0.07770593728409339 ~-0.05025495320535797 ~0.034172326075747245 109:1.1875:924:931 251:0.484375:925:928 154:1.71875:926:927 "
    s .= "~-0.03952452482355729 ~0.0578135771678739 6:0.25:929:930 ~0.006424855046229104 ~0.053253525849003294 239:0.03125:932:933 ~0.0582405267390603 ~-0.022927083777662793 251:0.796875:935:936 ~-0.05749859214640243 "
    s .= "26:-0.484375:937:940 229:-0.109375:938:939 ~-0.0386591601873852 ~0.046061417012104935 ~-0.0435016970589235 248:0.625:942:981 244:0.855:943:944 ~-0.05413081556428556 253:-0.006628787878785403:945:964 7:0.765625:946:963 "
    s .= "249:1.5:947:960 257:0.9130434782608695:948:957 256:0.9545454545454546:949:956 243:2.3499999999999996:950:955 243:0.45:951:954 211:0.015625:952:953 ~-0.06745022166935981 ~0.04129425182340842 ~0.057281673039653584 "
    s .= "~-0.02324812461015288 ~-0.09629879659069396 245:1.5666666666666667:958:959 ~-0.1005559442076519 ~0.03398072706315429 168:0.0625:961:962 ~-0.06141051943798889 ~0.039690027584151015 ~-0.05078439547601306 "
    s .= "235:-0.078125:965:968 251:1.703125:966:967 ~-0.0459662815366125 ~0.030991569043239048 31:0.265625:969:978 109:0.703125:970:975 251:1.203125:971:974 162:0.6875:972:973 ~-0.027306939010427883 ~0.06022836908893451 "
    s .= "~0.05001469640207438 32:0.078125:976:977 ~0.05507090486668295 ~-0.015983219329155536 251:0.828125:979:980 ~-0.055550142714564446 ~0.020526216660944674 251:0.796875:982:983 ~-0.056488476464403505 26:-0.484375:984:987 "
    s .= "190:-0.09375:985:986 ~-0.04244590649948837 ~0.043190805502714605 ~-0.04216261544332917 253:-0.026309607704955728:989:1012 244:0.88:990:995 32:-0.609375:991:994 137:-0.03125:992:993 ~-0.06213995907137805 "
    s .= "~0.0976019934815211 ~-0.05736644869313556 249:1.5:996:1009 31:0.9375:997:1008 243:0.45:998:1001 181:0.5:999:1000 ~-0.039997744730155736 ~0.05555928469006865 200:0.765625:1002:1007 257:0.9130434782608695:1003:1004 "
    s .= "~0.05555873170334824 245:1.8245614035087718:1005:1006 ~-0.09606132589949494 ~0.04839591741698512 ~-0.08992904074071045 ~-0.05037756729666218 33:0.21875:1010:1011 ~-0.05707960368260545 ~0.05321791986721171 "
    s .= "251:1.140625:1013:1028 244:1.225:1014:1019 220:0.875:1015:1016 ~-0.05171506427386732 217:0.421875:1017:1018 ~0.06907971787441901 ~-0.05076684693852743 211:-0.0625:1020:1021 ~-0.05137624942173911 28:-0.03125:1022:1025 "
    s .= "190:0.484375:1023:1024 ~0.0530025890350995 ~-0.02851595773108789 85:0.875:1026:1027 ~-0.03811335410169425 ~0.024871369724259376 248:0.625:1029:1034 243:0.45:1030:1031 ~-0.03029715609349074 235:-0.234375:1032:1033 "
    s .= "~-0.021820159698972805 ~0.054886084656113665 ~-0.03581751298423173 248:0.625:1036:1071 244:0.855:1037:1038 ~-0.05233026096245139 253:-0.006628787878785403:1039:1054 31:0.71875:1040:1053 249:1.5:1041:1052 "
    s .= "244:0.935:1042:1045 55:0.234375:1043:1044 ~0.038709205386478596 ~-0.10653743154143638 243:0.55:1046:1051 244:1.275:1047:1048 ~-0.057359846952155895 211:-0.1875:1049:1050 ~-0.08006454546119522 ~0.05197464809951533 "
    s .= "~0.055610796324518375 ~-0.02998368014135824 ~-0.044969159329858635 235:-0.078125:1055:1058 3:0.390625:1056:1057 ~-0.044314722867119904 ~0.02413115831544907 31:0.265625:1059:1068 109:0.703125:1060:1063 "
    s .= "251:0.984375:1061:1062 ~-0.019660672266987905 ~0.04135897746558689 160:-0.171875:1064:1065 ~-0.0677719313925802 236:0.546875:1066:1067 ~0.051836751780705397 ~-0.08042805682393309 251:0.796875:1069:1070 "
    s .= "~-0.054102295585839545 ~0.017665430700812 251:0.796875:1072:1075 241:4.04:1073:1074 ~-0.05559568164136828 ~0.09681112843351371 217:-0.125:1076:1077 ~-0.054647329454386676 53:0.09375:1078:1081 243:0.55:1079:1080 "
    s .= "~-0.02274321710374122 ~0.05202922335048421 ~-0.050606885783179095 248:0.625:1083:1124 244:0.855:1084:1085 ~-0.0513943428289641 253:-0.006628787878785403:1086:1105 7:0.765625:1087:1104 249:1.5:1088:1101 "
    s .= "244:0.935:1089:1092 52:0.21875:1090:1091 ~0.036392413125880034 ~-0.10756727686250159 243:0.55:1093:1096 244:1.275:1094:1095 ~-0.05413250843930262 ~0.04155789910456664 243:2.1500000000000004:1097:1098 "
    s .= "~0.05586448778364788 252:2.125:1099:1100 ~-0.11040745884150223 ~0.039464779710804344 240:0.171875:1102:1103 ~-0.05320015755139548 ~0.05545026905818164 ~-0.048666548358766375 235:-0.078125:1106:1113 "
    s .= "251:0.734375:1107:1108 ~-0.050298956612240577 217:-0.125:1109:1112 65:-1.0625:1110:1111 ~0.07637725763320465 ~-0.06459401983025229 ~0.025514639737962697 109:1.1875:1114:1121 251:0.484375:1115:1118 154:1.71875:1116:1117 "
    s .= "~-0.03628826657321536 ~0.05607567821248715 232:0.53125:1119:1120 ~0.030353787458320597 ~-0.061289563680162175 239:0.03125:1122:1123 ~0.05357416194737959 ~-0.023158573181203373 45:0.3203125:1125:1126 ~-0.0519250117523432 "
    s .= "85:1.125:1127:1128 ~-0.03561031615326079 ~0.0564223178559807 248:0.625:1130:1167 244:0.855:1131:1132 ~-0.05048582941198591 253:-0.006628787878785403:1133:1152 7:0.765625:1134:1151 249:1.5:1135:1148 244:0.935:1136:1139 "
    s .= "55:0.234375:1137:1138 ~0.03711894363972628 ~-0.09485649852857869 243:0.55:1140:1143 244:1.34:1141:1142 ~-0.0468251053987123 ~0.04167604030975676 243:2.1500000000000004:1144:1145 ~0.05503329195310644 252:2.125:1146:1147 "
    s .= "~-0.10404286723885384 ~0.03837981013670319 168:0.0625:1149:1150 ~-0.057761824914788366 ~0.03953863626962393 ~-0.04730581535895855 235:-0.078125:1153:1156 3:0.390625:1154:1155 ~-0.042043789539637146 ~0.023342858733804466 "
    s .= "31:0.265625:1157:1164 109:0.703125:1158:1161 251:1.203125:1159:1160 ~-0.016170112842526698 ~0.04508826825882707 26:0.109375:1162:1163 ~0.049946382287881674 ~-0.019182559628454103 251:0.796875:1165:1166 "
    s .= "~-0.05250794761866587 ~0.015532673154271355 251:0.671875:1168:1169 ~-0.05461245396869983 55:-0.21875:1170:1171 ~-0.05723317383416315 50:-0.078125:1172:1175 243:0.35:1173:1174 ~-0.04331445056655003 ~0.041331279909756186 "
    s .= "~-0.04181319709474152 253:-0.026309607704955728:1177:1200 248:0.375:1178:1187 7:0.765625:1179:1186 244:0.795:1180:1181 ~-0.05474592713729916 187:-0.0625:1182:1185 252:0.07500000000000001:1183:1184 ~-0.061539079551992726 "
    s .= "~0.03708410804301348 ~0.05306024500138573 ~-0.04890171325292211 144:0.265625:1188:1197 252:0.32499999999999996:1189:1192 32:-0.53125:1190:1191 ~-0.0009805996004781695 ~-0.05859526183948487 244:0.915:1193:1194 "
    s .= "~-0.05124767906092882 37:-0.296875:1195:1196 ~-0.12479357534613551 ~0.04140962269301328 143:0.171875:1198:1199 ~0.05555547474554018 ~-0.045525691159602075 248:0.625:1201:1222 244:1:1202:1205 251:1.109375:1203:1204 "
    s .= "~-0.0467668597031195 ~0.02975987634522518 232:-0.0625:1206:1209 123:0.3125:1207:1208 ~-0.037942878599058864 ~0.04005338826996741 193:0.265625:1210:1219 31:0.625:1211:1218 85:0.765625:1212:1217 33:0.21875:1213:1216 "
    s .= "1:-0.0625:1214:1215 ~0.037611745458862214 ~-0.015676058668830324 ~0.05213524976275924 ~0.05562437336338205 ~-0.03028144286089808 251:0.953125:1220:1221 ~-0.042663280658977294 ~0.027580183129446226 ~-0.04987321645565506 "
    s .= "248:0.625:1224:1259 244:0.845:1225:1226 ~-0.050539379601608904 251:0.328125:1227:1238 31:0.234375:1228:1237 235:-0.046875:1229:1230 ~-0.04733283030470553 109:0.8125:1231:1234 157:0.765625:1232:1233 ~-0.04614817203656442 "
    s .= "~0.031328477321639146 46:0.296875:1235:1236 ~0.05250932095386647 ~-0.06618447205272812 ~-0.06285978652119571 249:1.5:1239:1258 243:0.45:1240:1247 211:-0.015625:1241:1242 ~-0.04203248869154344 250:0.9296875:1243:1244 "
    s .= "~-0.03961845944399327 149:0.09375:1245:1246 ~0.05415555722327775 ~-0.030436832200506636 256:0.9545454545454546:1248:1257 226:-0.3125:1249:1250 ~-0.012207063820828453 200:0.765625:1251:1256 "
    s .= "257:0.9428571428571428:1252:1253 ~0.050788113009377724 245:1.8166666666666667:1254:1255 ~-0.08017903714684799 ~0.05558838707148814 ~-0.0824816503187405 ~-0.08240673955627957 ~-0.043568738489760145 251:0.671875:1260:1261 "
    s .= "~-0.05311659484634451 55:-0.21875:1262:1263 ~-0.05578835602610525 50:0.09375:1264:1269 243:0.55:1265:1268 46:0.875:1266:1267 ~-0.032559252332608764 ~0.09539240231750595 ~0.04336742802364066 ~-0.052172702365236 "
    s .= "253:-0.026309607704955728:1271:1290 248:0.375:1272:1281 31:0.78125:1273:1280 244:0.795:1274:1275 ~-0.05345399609223205 187:-0.0625:1276:1279 252:0.07500000000000001:1277:1278 ~-0.05903074413493627 ~0.03641492010053925 "
    s .= "~0.05151432380695501 ~-0.04759231013546353 192:0.265625:1282:1287 251:0.796875:1283:1284 ~-0.04891808278365102 211:-0.234375:1285:1286 ~-0.05759465081431834 ~0.03047076886483075 244:0.9:1288:1289 ~-0.04672648929041237 "
    s .= "~0.052937536492665666 248:0.625:1291:1316 244:1:1292:1299 220:0.875:1293:1296 251:1.484375:1294:1295 ~-0.04854997599442609 ~0.039061667441543095 217:0.421875:1297:1298 ~0.06623771779400574 ~-0.05724848260637318 "
    s .= "232:-0.0625:1300:1305 40:-0.046875:1301:1302 ~-0.046903565551539954 193:-0.015625:1303:1304 ~-0.02593133971049609 ~0.036471867155902934 193:0.265625:1306:1313 31:0.625:1307:1312 85:0.765625:1308:1311 "
    s .= "33:0.21875:1309:1310 ~0.005768345817167144 ~0.04993628603484866 ~0.05318780680205435 ~-0.028616311318437712 251:0.953125:1314:1315 ~-0.0408898186867247 ~0.025266323918168545 ~-0.048195183673255954 "
    s .= "253:-0.026309607704955728:1318:1337 248:0.375:1319:1328 7:0.765625:1320:1327 244:0.795:1321:1322 ~-0.052751372850546374 187:-0.0625:1323:1326 252:0.07500000000000001:1324:1325 ~-0.05482390958525714 ~0.03421558846634152 "
    s .= "~0.050794515855236436 ~-0.04683238102186383 192:0.265625:1329:1334 251:0.671875:1330:1331 ~-0.05119695366751852 55:-0.21875:1332:1333 ~-0.058388424258431215 ~0.0231183944656938 244:0.9:1335:1336 ~-0.04577696091926134 "
    s .= "~0.051868298107717585 251:1.140625:1338:1357 244:1.225:1339:1348 2:-0.125:1340:1347 251:0.421875:1341:1342 ~-0.04716882234861 255:0.234375:1343:1346 255:0.140625:1344:1345 ~-0.0041096606448553915 ~0.0775716154838813 "
    s .= "~-0.03694046035902659 ~-0.05334277203372961 211:-0.0625:1349:1350 ~-0.046330064708802854 28:-0.03125:1351:1354 130:-0.125:1352:1353 ~-0.05915232757253011 ~0.04675450870074489 85:0.875:1355:1356 ~-0.03346274806401391 "
    s .= "~0.019665286000460972 249:1.5:1358:1363 29:0.390625:1359:1362 243:0.45:1360:1361 ~-0.011355347712876055 ~0.04718141100644916 ~-0.03814529607818075 ~-0.04999341737201526 248:0.625:1365:1402 244:0.845:1366:1367 "
    s .= "~-0.04843079256286589 251:0.328125:1368:1377 31:0.234375:1369:1376 243:1.25:1370:1375 118:0.359375:1371:1374 244:1.035:1372:1373 ~-0.030910899320655362 ~0.04301095637902523 ~-0.04535645490408299 ~-0.05804099028995161 "
    s .= "~-0.06123346047810077 249:1.5:1378:1399 243:0.45:1379:1386 211:-0.015625:1380:1381 ~-0.03878898457386166 250:0.9296875:1382:1383 ~-0.03807825779717759 149:0.09375:1384:1385 ~0.05211485625250252 ~-0.02877716203570689 "
    s .= "256:0.9545454545454546:1387:1398 243:2.05:1388:1395 200:0.765625:1389:1394 28:0.46875:1390:1391 ~0.04919306772326815 251:1.671875:1392:1393 ~-0.02551049995536758 ~0.05276834665070488 ~-0.08015908381457636 "
    s .= "253:-0.042911505141282065:1396:1397 ~0.03313516458544034 ~-0.05075542934360856 ~-0.07922866539780182 240:0.265625:1400:1401 ~-0.05372318053502036 ~0.031887237834765526 45:0.2265625:1403:1406 241:4.04:1404:1405 "
    s .= "~-0.049660852421709444 ~0.10116285224868818 85:1.125:1407:1408 ~-0.03634010579435348 218:0.171875:1409:1410 ~0.07968850641711438 ~-0.04524292761265821 253:-0.026309607704955728:1412:1435 244:0.895:1413:1418 "
    s .= "32:-0.609375:1414:1417 137:-0.03125:1415:1416 ~-0.04199003353456662 ~0.0894518355742737 ~-0.05110056837935503 249:1.8333333333333335:1419:1434 251:0.140625:1420:1423 31:0.140625:1421:1422 ~0.035107195724671754 "
    s .= "~-0.06352493407719882 241:0.22:1424:1427 181:0.40625:1425:1426 ~-0.06360503971660667 ~0.049309103803390854 194:0.625:1428:1433 257:0.9130434782608695:1429:1430 ~0.049436912205918344 247:-0.546875:1431:1432 "
    s .= "~0.03144107480924919 ~-0.12687339509595422 ~-0.06340842905164977 ~-0.04689191490719582 248:0.625:1436:1457 244:1:1437:1442 235:1.34375:1438:1441 251:1.484375:1439:1440 ~-0.043642383837810245 ~0.03657317892039428 "
    s .= "~0.062261278952268344 163:-0.171875:1443:1444 ~-0.040018199659564595 243:1.85:1445:1456 249:1.5:1446:1455 241:0.2:1447:1452 82:0.171875:1448:1451 184:0.046875:1449:1450 ~-0.02377380405324469 ~0.041855967767069714 "
    s .= "~-0.03483458034839386 40:0.578125:1453:1454 ~0.041747450707537076 ~-0.040554607280690574 ~-0.050522299732269155 ~-0.05328375591561266 ~-0.046063481282487065 248:0.625:1459:1496 244:0.84:1460:1461 ~-0.04792611737493483 "
    s .= "251:0.328125:1462:1471 31:0.234375:1463:1470 243:1.25:1464:1469 118:0.359375:1465:1468 244:1.035:1466:1467 ~-0.029652400871657027 ~0.04093358283549632 ~-0.04378718149060534 ~-0.05699593656990061 ~-0.06004598926312204 "
    s .= "249:1.1666666666666665:1472:1493 212:0.578125:1473:1492 193:-0.171875:1474:1481 251:1.328125:1475:1480 9:-0.7890625:1476:1477 ~0.06484081464855405 244:1.975:1478:1479 ~-0.0447417050975952 ~0.04800407780625116 "
    s .= "~0.04623784596755426 243:0.45:1482:1487 250:0.9296875:1483:1484 ~-0.03459073964733996 115:-0.15625:1485:1486 ~-0.06925328606593484 ~0.04426922512771993 49:0.296875:1488:1489 ~0.049965533092608594 251:0.765625:1490:1491 "
    s .= "~-0.03154975551510537 ~0.041840811044451594 ~-0.04423038404320426 33:0.21875:1494:1495 ~-0.0473548458861818 ~0.033722257599983256 251:0.671875:1497:1498 ~-0.050009032252410435 55:-0.21875:1499:1500 ~-0.05310345601072905 "
    s .= "50:0.109375:1501:1504 243:0.35:1502:1503 ~-0.037202885398920554 ~0.03398729720356818 ~-0.05013482171583116 253:-0.026309607704955728:1506:1525 248:0.375:1507:1516 31:0.28125:1508:1513 244:0.795:1509:1510 "
    s .= "~-0.04966323319007453 208:-0.453125:1511:1512 ~-0.05158591269095173 ~0.04779799054003946 251:0.609375:1514:1515 ~-0.05933551798007672 ~0.03584924543859228 192:0.265625:1517:1522 251:0.796875:1518:1519 "
    s .= "~-0.045276221782087685 211:-0.234375:1520:1521 ~-0.05550318412808317 ~0.027300574123113465 203:0.265625:1523:1524 ~0.051053104403937205 ~-0.03842437837099782 251:0.828125:1526:1545 244:1.215:1527:1536 "
    s .= "75:0.2890625:1528:1529 ~-0.04879668504558898 161:0.3125:1530:1535 257:0.36904761904761907:1531:1534 255:0.234375:1532:1533 ~0.05933719081395063 ~-0.029491289475124673 ~-0.058223597124185116 ~-0.0541805066569284 "
    s .= "211:-0.0625:1537:1538 ~-0.04738075112247547 28:-0.03125:1539:1542 190:0.796875:1540:1541 ~0.04907860696133384 ~-0.04794197200862865 85:1.171875:1543:1544 ~-0.02831818111634551 ~0.02382409667983073 "
    s .= "217:-0.203125:1546:1547 ~-0.04041920929492741 50:0.296875:1548:1551 243:0.45:1549:1550 ~-0.002925961167805559 ~0.04118332670590683 ~-0.035860521253858794 248:0.625:1553:1590 244:0.84:1554:1555 ~-0.04661407878091898 "
    s .= "253:-0.006628787878785403:1556:1575 31:0.40625:1557:1572 196:-0.1875:1558:1561 198:0.109375:1559:1560 ~-0.035580539963319044 ~0.038346490626842665 257:0.9130434782608695:1562:1569 218:0.65625:1563:1568 "
    s .= "241:0.22:1564:1567 181:0.5:1565:1566 ~-0.03452876297762772 ~0.05244635013760643 ~0.04886982833701037 ~-0.08395806899859908 254:0.015625:1570:1571 ~0.043402337685289484 ~-0.08342073218181945 251:0.703125:1573:1574 "
    s .= "~-0.05868522877929947 ~0.03694653092648927 232:-0.0625:1576:1581 217:-0.046875:1577:1578 ~-0.04532950143975367 202:0.1875:1579:1580 ~0.02482794740237419 ~-0.05099316653509779 31:0.296875:1582:1589 109:0.703125:1583:1586 "
    s .= "33:0.21875:1584:1585 ~-0.01686964380693882 ~0.040063898257052866 32:-0.140625:1587:1588 ~0.04896032644238008 ~0.006986628548882676 ~-0.030522375768900434 251:0.671875:1591:1592 ~-0.04879590497494594 "
    s .= "219:0.28125:1593:1596 26:-0.484375:1594:1595 ~0.008620650002709021 ~-0.04432785532658174 119:0.234375:1597:1598 ~0.061321070966619255 ~-0.039313539208543524 253:-0.026309607704955728:1600:1615 248:0.375:1601:1608 "
    s .= "31:0.25:1602:1605 244:0.795:1603:1604 ~-0.04823744146855908 ~0.04588801428442288 251:0.609375:1606:1607 ~-0.05614199366456531 ~0.033623664547494506 144:0.25:1609:1612 252:0.475:1610:1611 ~-0.042300139933327506 "
    s .= "~0.007520468516145424 119:0.1875:1613:1614 ~0.0510345965276221 ~-0.04302250595935748 29:-0.078125:1616:1637 97:0.25:1617:1634 220:-0.125:1618:1621 249:0.5:1619:1620 ~-0.009077086060494535 ~-0.05600997940153372 "
    s .= "109:0.609375:1622:1629 251:0.765625:1623:1628 21:0.3984375:1624:1625 ~-0.038475554623943004 15:0.4453125:1626:1627 ~0.12156715793497797 ~-0.031243554520073574 ~0.029720853997432236 233:0.203125:1630:1633 "
    s .= "142:-0.15625:1631:1632 ~-0.02753978632546469 ~0.04749141115144053 ~-0.032626826565490395 251:1.421875:1635:1636 ~-0.04605978727344746 ~0.031471733278005384 244:1.64:1638:1641 251:1.484375:1639:1640 ~-0.04831822802823671 "
    s .= "~0.013139980586346562 245:1.7066666666666668:1642:1643 ~0.04900905925329392 236:-0.09375:1644:1645 ~0.026742487796004324 ~-0.044177562978808996 248:0.625:1647:1684 244:0.84:1648:1649 ~-0.045395446582030936 "
    s .= "251:0.328125:1650:1661 31:0.234375:1651:1660 243:1.25:1652:1659 124:0.25:1653:1658 118:0.359375:1654:1657 199:-0.171875:1655:1656 ~-0.0575255653385121 ~0.04499358529735594 ~-0.0352294608707307 ~-0.03488614359749114 "
    s .= "~-0.05573424419163964 ~-0.05773976111948771 220:-0.0625:1662:1675 249:1.1666666666666665:1663:1674 85:0.59375:1664:1671 251:1.578125:1665:1670 103:0.9375:1666:1669 229:0.578125:1667:1668 ~-0.05873086157687385 "
    s .= "~0.050005689477989404 ~0.03267376569249358 ~0.037910613211046905 100:-0.34375:1672:1673 ~-0.06410967584883685 ~0.04121106753140742 ~-0.05562351839072674 194:0.625:1676:1683 241:0.18:1677:1678 ~0.004480873135985673 "
    s .= "257:0.9428571428571428:1679:1680 ~0.04560887073920716 245:1.7857142857142858:1681:1682 ~-0.08414166942811274 ~0.05651623660498087 ~-0.0704779495613708 45:0.2265625:1685:1688 252:4.975:1686:1687 ~-0.04611858073982279 "
    s .= "~0.10212023403793101 85:1.125:1689:1690 ~-0.03209764256525304 218:0.171875:1691:1692 ~0.07821688534809912 ~-0.04111130066139942 253:-0.026309607704955728:1694:1711 248:0.375:1695:1704 31:0.203125:1696:1699 "
    s .= "244:0.795:1697:1698 ~-0.04877169238578677 ~0.045529207733527144 112:0.84375:1700:1703 251:1.015625:1701:1702 ~-0.058714284642352614 ~0.012194299162444243 ~0.047757092431677486 192:0.265625:1705:1708 "
    s .= "5:-0.484375:1706:1707 ~0.012181985866303417 ~-0.03894348216557983 203:0.265625:1709:1710 ~0.04900247687354056 ~-0.03718715511141845 249:1.1666666666666665:1712:1739 244:0.82:1713:1714 ~-0.05198252613371285 "
    s .= "85:1.203125:1715:1734 251:0.484375:1716:1723 67:0.125:1717:1722 205:0.765625:1718:1721 109:0.625:1719:1720 ~-0.04125406650016483 ~0.004673185584169822 ~0.04846135120231297 ~-0.049515364071308965 255:0.328125:1724:1731 "
    s .= "212:0.578125:1725:1730 241:0.24:1726:1729 190:0.109375:1727:1728 ~-0.028810629164097518 ~0.031920084747937005 ~0.040322497153967796 ~-0.04953844401524846 5:-0.390625:1732:1733 ~0.003852716955876061 ~-0.0625899931173043 "
    s .= "202:-0.15625:1735:1736 ~-0.03940890674706487 28:0.6875:1737:1738 ~0.05098064820251113 ~-0.0429869086301738 ~-0.049814814249398466 248:0.625:1741:1776 251:0.765625:1742:1763 31:0.234375:1743:1762 26:0.125:1744:1757 "
    s .= "211:-0.09375:1745:1746 ~-0.03396807793103057 166:0.359375:1747:1756 109:0.71875:1748:1755 205:0.625:1749:1754 255:0.265625:1750:1753 245:1.6290322580645162:1751:1752 ~-0.039441423859020226 ~0.03410823452326392 "
    s .= "~-0.04594805661405874 ~0.08122250277336128 ~0.04803668872221051 ~-0.028562357518999933 136:0.78125:1758:1759 ~-0.05047360498827076 246:0.015625:1760:1761 ~-0.04400029868958461 ~0.029475020403630422 ~-0.04904876561532403 "
    s .= "249:1.1666666666666665:1764:1773 212:0.578125:1765:1772 241:0.24:1766:1769 178:-0.0625:1767:1768 ~-0.06996047712772119 ~0.01782148960769327 256:0.9545454545454546:1770:1771 ~0.04787226086231677 ~-0.05241189277378834 "
    s .= "~-0.04348784647540857 220:-0.0625:1774:1775 ~-0.05207292075146863 ~0.01817132181619482 251:0.671875:1777:1778 ~-0.046720796123498054 55:-0.21875:1779:1780 ~-0.050486051381641944 122:0.203125:1781:1786 243:0.35:1782:1785 "
    s .= "46:1.015625:1783:1784 ~-0.05328007199377818 ~0.1354053801653675 ~0.03375109754914653 ~-0.04781344855814451 253:-0.026309607704955728:1788:1813 244:0.935:1789:1796 29:-0.578125:1790:1793 34:0.140625:1791:1792 "
    s .= "~0.0577209916688545 ~-0.06765641168313903 251:1.359375:1794:1795 ~-0.050009445967655 ~0.062300099169914226 249:1.8333333333333335:1797:1812 251:0.140625:1798:1799 ~-0.03384288383982477 243:0.55:1800:1805 "
    s .= "244:1.3:1801:1802 ~-0.06170047696738824 181:0.0625:1803:1804 ~-0.057399081358798426 ~0.045791415371189526 208:-0.234375:1806:1809 164:-0.078125:1807:1808 ~0.02910337171395786 ~-0.06798908068572442 "
    s .= "257:0.9130434782608695:1810:1811 ~0.04907487097891118 ~-0.015401801964612405 ~-0.04374040531273755 249:1.1666666666666665:1814:1833 244:0.82:1815:1816 ~-0.051147453737706086 26:0.203125:1817:1832 85:1.171875:1818:1829 "
    s .= "144:0.046875:1819:1822 160:1.46875:1820:1821 ~-0.0238279511320441 ~0.03709092915755633 254:1.265625:1823:1828 167:0.5625:1824:1827 161:-0.046875:1825:1826 ~0.003581027032510647 ~0.05170940116861866 ~-0.04304402107238474 "
    s .= "~-0.0608839477923511 232:-0.203125:1830:1831 ~-0.0331693326958402 ~0.0491876524386657 ~-0.03555774885128412 ~-0.04871288420680633 248:0.625:1835:1870 251:0.765625:1836:1861 31:0.234375:1837:1860 26:0.125:1838:1855 "
    s .= "211:-0.125:1839:1840 ~-0.03919936743247915 166:0.359375:1841:1854 193:0.265625:1842:1853 85:0.78125:1843:1852 139:0.5:1844:1849 85:-0.078125:1845:1846 ~0.045734350461730355 106:0.59375:1847:1848 ~-0.036098125829858885 "
    s .= "~0.022845307326080103 136:0.484375:1850:1851 ~0.10939928851715995 ~0.03659858602978118 ~0.05370752837535195 ~-0.02459778674061845 ~-0.02849811666856717 136:0.625:1856:1857 ~-0.05103555121019722 246:0.015625:1858:1859 "
    s .= "~-0.04464398168441609 ~0.02120329931557007 ~-0.04782521081061092 212:0.578125:1862:1869 249:1.5:1863:1868 241:0.24:1864:1865 ~0.002174890243321431 256:0.9545454545454546:1866:1867 ~0.046156242979260666 "
    s .= "~-0.054008973950315724 ~-0.025857147457484516 ~-0.04328515830386933 26:-0.125:1871:1880 138:-0.1171875:1872:1873 ~-0.04109390974628051 85:0.765625:1874:1877 251:0.828125:1875:1876 ~-0.03918272956664897 "
    s .= "~0.024810295654590662 229:-0.171875:1878:1879 ~-0.05261585244124981 ~0.07161946760923445 ~-0.048332723169201966 253:-0.042911505141282065:1882:1897 244:0.895:1883:1884 ~-0.03426842135948339 249:1.5:1885:1894 "
    s .= "85:0.78125:1886:1893 251:0.328125:1887:1888 ~-0.04229200041400269 252:0.07500000000000001:1889:1892 81:0.1171875:1890:1891 ~-0.0620950109459718 ~0.031627446124739826 ~0.03843835611590193 ~0.04924554397083673 "
    s .= "174:0.125:1895:1896 ~-0.05189810404640974 ~0.04903517746009945 251:1.140625:1898:1923 244:1.225:1899:1910 2:-0.125:1900:1909 113:0:1901:1904 109:1.453125:1902:1903 ~-0.04021703751254636 ~0.019212616111429548 "
    s .= "158:0.34375:1905:1908 94:0.28125:1906:1907 ~0.06270948703145796 ~-0.020035081611219665 ~-0.043577292638317416 ~-0.04824311072698412 226:0.015625:1911:1918 249:0.5:1912:1917 106:0.546875:1913:1914 ~-0.05333822931678714 "
    s .= "243:1.15:1915:1916 ~0.03074045307837549 ~-0.043401810140872965 ~-0.05323374130118702 1:0.25:1919:1922 157:0.109375:1920:1921 ~-0.0285344954148207 ~0.03763529471606565 ~-0.04485127177715782 235:-0.3125:1924:1925 "
    s .= "~-0.04006041983850437 243:0.45:1926:1927 ~-0.01644570517293145 ~0.03754789030826589 248:0.625:1929:1968 251:0.765625:1930:1957 31:0.234375:1931:1956 109:0.71875:1932:1943 142:0.046875:1933:1940 143:0.25:1934:1939 "
    s .= "12:0.140625:1935:1938 205:0.65625:1936:1937 ~-0.029061772774689 ~0.06477875487937908 ~0.05091501610292742 ~-0.0540475121907919 154:1.140625:1941:1942 ~-0.045939409382807266 ~0.03921201859229467 226:-0.203125:1944:1945 "
    s .= "~-0.05049656295665494 169:0.21875:1946:1953 199:-0.171875:1947:1948 ~-0.06263441767153471 217:-0.171875:1949:1950 ~-0.041974593333764854 160:-0.125:1951:1952 ~-0.0474935979776103 ~0.049541261994538614 "
    s .= "181:0.234375:1954:1955 ~0.0369929779697583 ~-0.04429279908768041 ~-0.046503122472519504 163:-0.328125:1958:1959 ~-0.030853730244286826 212:0.578125:1960:1967 241:0.24:1961:1964 26:-0.015625:1962:1963 "
    s .= "~0.018464266636947925 ~-0.05650967714022447 245:1.1129032258064515:1965:1966 ~-0.07632482809823539 ~0.04449307129518222 ~-0.04157859318565136 251:0.671875:1969:1970 ~-0.044722490667107845 211:-0.15625:1971:1972 "
    s .= "~-0.047237909728862076 122:0.09375:1973:1974 ~0.02392747556770243 ~-0.04205304008214426 253:-0.042911505141282065:1976:1995 244:0.895:1977:1978 ~-0.03277824619089203 249:1.5:1979:1992 85:0.78125:1980:1989 "
    s .= "251:0.328125:1981:1982 ~-0.040447022551030276 257:0.43478260869565216:1983:1986 209:0.5625:1984:1985 ~0.03921243462365827 ~-0.06164072383823208 98:-0.484375:1987:1988 ~0.038384309145457825 ~-0.10500070524731893 "
    s .= "55:-0.4375:1990:1991 ~-0.047214013384667936 ~0.04977251181767908 174:0.125:1993:1994 ~-0.051030637215914124 ~0.04711104748708813 29:-0.078125:1996:2011 97:0.25:1997:2008 220:-0.125:1998:2001 249:0.5:1999:2000 "
    s .= "~-0.0076466696217544275 ~-0.05325613402462877 248:0.875:2002:2007 64:-0.15625:2003:2004 ~-0.018224653682296654 184:-0.21875:2005:2006 ~-0.05962956789245619 ~0.03516883631341572 ~-0.023686665363639513 "
    s .= "251:1.515625:2009:2010 ~-0.04182467058618031 ~0.03212582848680567 251:1.484375:2012:2019 244:1.63:2013:2014 ~-0.04469332969530689 245:1.7241379310344827:2015:2016 ~0.04240834970325759 188:-0.140625:2017:2018 "
    s .= "~0.03145967531141735 ~-0.04446847804632193 252:0.32499999999999996:2020:2021 ~-0.029703657485070357 ~0.040231760274552636 251:0.796875:2023:2052 109:0.71875:2024:2037 249:0.5:2025:2036 85:0.78125:2026:2035 "
    s .= "205:0.75:2027:2032 163:0.890625:2028:2031 91:0.796875:2029:2030 ~-0.04162105374659148 ~0.04710719736812052 ~0.037507477659190686 70:0.09375:2033:2034 ~0.07194857992045121 ~-0.06118119158950278 ~0.043182112759968055 "
    s .= "~-0.04911181331635983 226:-0.140625:2038:2039 ~-0.04739248917977343 169:0.21875:2040:2049 31:0.296875:2041:2048 199:-0.15625:2042:2043 ~-0.06317610243019152 217:-0.140625:2044:2045 ~-0.03022782390879032 "
    s .= "170:0.109375:2046:2047 ~0.05019902284942604 ~0.012374406091994044 ~-0.03127137396903343 88:1.421875:2050:2051 ~-0.04107813753205267 ~0.034445309940358916 249:1.5:2053:2064 243:0.45:2054:2057 46:0.640625:2055:2056 "
    s .= "~-0.02098642031235029 ~0.05846724623315239 209:0.578125:2058:2063 256:0.9545454545454546:2059:2062 187:-0.140625:2060:2061 ~0.01173820339424405 ~0.04466992779957953 ~-0.04573850809727689 ~-0.029981695063430038 "
    s .= "219:0.296875:2065:2068 51:0.4296875:2066:2067 ~-0.0547501778684567 ~0.06456021070759259 ~0.043020600981933804 248:0.625:2070:2103 244:0.82:2071:2072 ~-0.044428655660148926 27:0.171875:2073:2094 190:-0.0625:2074:2077 "
    s .= "9:-0.6328125:2075:2076 ~0.04321839357556937 ~-0.030254991014815342 109:1.1875:2078:2091 190:0.375:2079:2086 255:0.265625:2080:2083 236:0.15625:2081:2082 ~0.03704194414334889 ~-0.02189850642989625 251:0.765625:2084:2085 "
    s .= "~-0.04438624694595682 ~0.013624968781573736 244:1.095:2087:2088 ~-0.06668597003631917 142:0.625:2089:2090 ~0.02666504327564353 ~-0.050604907743536855 166:0.65625:2092:2093 ~0.043217913754589644 ~-0.000023170584421406787 "
    s .= "167:0.5625:2095:2102 88:0.234375:2096:2101 211:-0.125:2097:2098 ~-0.03427245181374854 130:2.078125:2099:2100 ~0.035634478850475486 ~-0.12254836610468167 ~0.04777711267852146 ~-0.02753650124892265 50:-0.234375:2104:2115 "
    s .= "110:-0.1875:2105:2110 123:-0.109375:2106:2107 ~-0.044104460105733906 109:1.0625:2108:2109 ~-0.025622390479124752 ~0.0575171618444289 167:0.203125:2111:2114 72:0.109375:2112:2113 ~0.0009499854821483416 "
    s .= "~0.07450811006997864 ~-0.038750568499378614 ~-0.04460239812980615 253:-0.042911505141282065:2117:2132 196:-0.15625:2118:2121 201:0.328125:2119:2120 ~-0.036165414627387364 ~0.041340417422028645 85:0.78125:2122:2131 "
    s .= "251:0.828125:2123:2128 112:0.796875:2124:2127 79:0.875:2125:2126 ~-0.0486887538865636 ~0.04828407575428829 ~0.02803356805563155 218:0.625:2129:2130 ~0.04373841876420092 ~-0.08266270860332892 ~0.04725504842131467 "
    s .= "249:1.1666666666666665:2133:2162 244:0.82:2134:2135 ~-0.04674456751075476 243:1.45:2136:2159 85:1.171875:2137:2156 254:1.109375:2138:2155 251:0.484375:2139:2146 94:0.34375:2140:2145 248:0.625:2141:2144 "
    s .= "121:0.265625:2142:2143 ~0.025673277676114017 ~-0.04456666372801815 ~-0.040294194318037616 ~-0.05221190374214355 241:0.24:2147:2152 149:0.125:2148:2151 184:0.046875:2149:2150 ~-0.026770891814474507 ~0.0332476554379841 "
    s .= "~-0.048545275099385415 130:1.953125:2153:2154 ~0.037824851623429606 ~-0.06603880797224937 ~-0.04421537088825395 28:0.75:2157:2158 ~0.04281727146254889 ~-0.046037670500508304 251:1.390625:2160:2161 ~-0.05345846990990998 "
    s .= "~0.021691696575392775 ~-0.04552599915634814 251:0.796875:2164:2191 109:0.71875:2165:2176 249:0.5:2166:2175 205:0.765625:2167:2174 85:0.78125:2168:2173 163:0.890625:2169:2172 91:0.796875:2170:2171 ~-0.03943876979092237 "
    s .= "~0.04523484912347406 ~0.035813439997940115 ~0.04201935412842875 ~0.050188296275096925 ~-0.04773838632186622 226:-0.140625:2177:2178 ~-0.04609043013352406 169:0.21875:2179:2188 31:0.296875:2180:2187 "
    s .= "199:-0.15625:2181:2182 ~-0.06095276297556418 217:-0.140625:2183:2184 ~-0.02824784403856383 170:0.109375:2185:2186 ~0.04845778117636105 ~0.011130880483364873 ~-0.029768923183445387 88:1.421875:2189:2190 "
    s .= "~-0.039460060504537466 ~0.03234936828244777 249:1.5:2192:2205 241:0.24:2193:2196 46:0.71875:2194:2195 ~-0.02183689491395073 ~0.05646975415595171 203:0.609375:2197:2204 256:0.9545454545454546:2198:2203 "
    s .= "187:-0.140625:2199:2202 241:0.5:2200:2201 ~-0.03175434216042718 ~0.033379930852304125 ~0.04353036823736245 ~-0.041462156614904856 ~-0.02941049530425829 219:0.296875:2206:2209 51:0.4296875:2207:2208 "
    s .= "~-0.053631565833971155 ~0.06058181172617153 ~0.04192824862044675 253:-0.042911505141282065:2211:2222 252:0.175:2212:2219 122:0.09375:2213:2218 217:-0.0625:2214:2215 ~-0.03432133650691054 55:0.1875:2216:2217 "
    s .= "~0.04097407538294099 ~-0.017655235202659072 ~-0.05219923522420871 244:0.9:2220:2221 ~-0.025752269331191343 ~0.04247127713937019 29:-0.078125:2223:2246 97:0.25:2224:2243 196:-0.28125:2225:2226 ~-0.042689572544272955 "
    s .= "85:0.734375:2227:2240 254:1.109375:2228:2239 139:0.015625:2229:2230 ~-0.02345494393033533 257:0.75:2231:2238 200:0.203125:2232:2237 246:-0.015625:2233:2236 143:-0.609375:2234:2235 ~0.055531470452714726 "
    s .= "~-0.006327098947316968 ~0.06100684228369422 ~-0.023589556940890873 ~-0.022462608633909205 ~-0.034758090290334935 172:-0.140625:2241:2242 ~-0.04279802996223778 ~0.04536608623520002 251:1.609375:2244:2245 "
    s .= "~-0.038679957876984916 ~0.03432225425639508 249:0.8333333333333333:2247:2256 244:0.93:2248:2249 ~-0.0469075936188422 193:0.265625:2250:2255 243:1.45:2251:2254 255:0.296875:2252:2253 ~0.023050328459968225 "
    s .= "~-0.03924361295640322 ~-0.03986490664789889 ~-0.04474486832077989 ~-0.04993635229996552 248:0.625:2258:2293 251:0.765625:2259:2280 31:0.21875:2260:2279 95:0.21875:2261:2278 166:0.390625:2262:2275 190:-0.0625:2263:2268 "
    s .= "243:1.45:2264:2267 211:-0.125:2265:2266 ~-0.03090936183365567 ~0.020617113295342764 ~-0.058724011239000985 97:0.203125:2269:2272 208:-0.109375:2270:2271 ~-0.030798485126716926 ~0.04127949853264087 85:0.859375:2273:2274 "
    s .= "~-0.039899793391154556 ~0.04304442138257392 142:0.203125:2276:2277 ~0.020418038030540306 ~-0.04640071660542016 ~-0.03770669672217558 ~-0.04223283109155426 253:-0.0007518796992452995:2281:2286 200:0.765625:2282:2285 "
    s .= "163:-0.34375:2283:2284 ~-0.024367017658706216 ~0.04308047839073606 ~-0.08513559610256027 215:0.46875:2287:2292 193:-0.09375:2288:2289 ~-0.01985751880251166 245:3.3620689655172415:2290:2291 ~0.029158672036405642 "
    s .= "~-0.06555128677157206 ~-0.04965684165874452 50:-0.234375:2294:2303 117:-0.125:2295:2296 ~-0.03690620814685574 85:0.609375:2297:2300 67:0.59375:2298:2299 ~-0.016844906750167483 ~0.10818994876471462 "
    s .= "229:-0.171875:2301:2302 ~-0.04325828502179635 ~0.06740181603241559 ~-0.04290417189091317 249:1.5:2305:2348 244:0.82:2306:2307 ~-0.045511393498784546 85:0.78125:2308:2335 251:1.609375:2309:2332 146:0.171875:2310:2331 "
    s .= "9:0.1328125:2311:2326 163:1.25:2312:2325 208:1.390625:2313:2324 255:0.296875:2314:2323 184:0.046875:2315:2318 79:1:2316:2317 ~-0.04633110920190685 ~0.07049727976838872 100:0.1875:2319:2320 ~0.028378718495826502 "
    s .= "157:0.09375:2321:2322 ~0.08542498919143465 ~-0.04770921803914338 ~-0.03884601583202645 ~0.049082891367961484 ~0.04197422263990411 28:0.25:2327:2330 246:-0.078125:2328:2329 ~0.005588614391598204 ~0.04614656523992022 "
    s .= "~-0.03548360859789306 ~-0.040220670580231814 243:0.6499999999999999:2333:2334 ~-0.011380711259033487 ~0.047018305944695145 37:0.53125:2336:2347 208:-0.25:2337:2340 140:-0.234375:2338:2339 ~0.021875473554652646 "
    s .= "~-0.06564638483805317 217:0.375:2341:2346 166:0.4375:2342:2343 ~0.04814954073497557 37:-0.140625:2344:2345 ~-0.06384457669296145 ~0.0286641898651347 ~-0.009498510633359929 ~-0.02905866694951651 219:0.328125:2349:2350 "
    s .= "~-0.05056391690778526 ~0.010334498397782312 249:1.5:2352:2393 244:0.82:2353:2354 ~-0.04500081405924729 85:0.78125:2355:2378 251:1.640625:2356:2375 4:0.28125:2357:2372 146:0.109375:2358:2371 75:0.1484375:2359:2368 "
    s .= "163:1.15625:2360:2367 205:0.59375:2361:2364 100:0.78125:2362:2363 ~-0.022928186020023167 ~0.03426737299664307 211:0.515625:2365:2366 ~0.06659561062725809 ~-0.04463537940343232 ~0.04428062672199166 187:-0.125:2369:2370 "
    s .= "~-0.021761175824597613 ~0.037140971505749604 ~-0.030428445427650264 28:-0.359375:2373:2374 ~0.07041373280686265 ~-0.04510685573552162 190:-0.328125:2376:2377 ~-0.06350189089484616 ~0.0423897575271613 "
    s .= "37:0.515625:2379:2392 208:-0.25:2380:2383 140:-0.234375:2381:2382 ~0.02098363453448496 ~-0.06307115501866442 217:0.375:2384:2389 166:0.4375:2385:2386 ~0.04737827215216499 37:-0.140625:2387:2388 ~-0.06058754687302005 "
    s .= "~0.027992822418628 163:0.265625:2390:2391 ~0.041634687447087426 ~-0.03788314998611987 ~-0.027526534833924633 219:0.328125:2394:2397 51:0.3828125:2395:2396 ~-0.05262132253003415 ~0.02488146591942254 ~0.00980809496820555 "
    s .= "251:0.796875:2399:2426 109:0.71875:2400:2409 249:0.5:2401:2408 205:0.765625:2402:2407 85:0.78125:2403:2406 163:0.890625:2404:2405 ~-0.0339197576648977 ~0.033496922215921814 ~0.038551713817298376 ~0.04836409352495839 "
    s .= "~-0.04576067200551805 226:-0.203125:2410:2411 ~-0.049827430114613165 193:0.203125:2412:2423 169:-0.234375:2413:2414 ~-0.05211820235790726 31:1:2415:2422 199:-0.171875:2416:2419 88:-0.359375:2417:2418 "
    s .= "~0.25777634566261487 ~-0.05103601819170413 248:1.125:2420:2421 ~0.04003210601550719 ~-0.03945178010356767 ~-0.04203817264713289 81:0.2578125:2424:2425 ~-0.043551165952974265 ~0.03683602138508451 217:-0.203125:2427:2430 "
    s .= "249:0.8333333333333333:2428:2429 ~0.007395559915216439 ~-0.049707064884471575 212:0.578125:2431:2444 243:0.45:2432:2435 190:0.046875:2433:2434 ~-0.03295595677543145 ~0.021341923183404676 49:0.90625:2436:2443 "
    s .= "32:0.359375:2437:2442 214:0.375:2438:2439 ~0.04410646620884698 245:1.575:2440:2441 ~-0.1039953390387714 ~0.022012212307612442 ~-0.0008922124306929274 ~-0.04475922039065919 ~-0.038334595843178436 249:1.5:2446:2489 "
    s .= "244:0.82:2447:2448 ~-0.04410952950019839 85:0.78125:2449:2474 251:1.640625:2450:2469 4:0.28125:2451:2468 146:0.109375:2452:2467 254:1.265625:2453:2466 6:0.125:2454:2463 29:-0.828125:2455:2456 ~0.04893407433443331 "
    s .= "163:1.25:2457:2462 223:-0.0625:2458:2459 ~-0.04794975422694116 202:0.25:2460:2461 ~0.016270829071634834 ~-0.03478490875782794 ~0.0443676404975198 246:-0.015625:2464:2465 ~0.008121027947835955 ~0.04965251074513172 "
    s .= "~-0.034207056569214744 ~-0.029195017937582907 ~-0.04003937774033623 241:0.52:2470:2473 218:0:2471:2472 ~0.02029499479393494 ~-0.08139333533398828 ~0.047487973868767866 37:0.53125:2475:2488 208:-0.25:2476:2479 "
    s .= "140:-0.234375:2477:2478 ~0.01966250276911718 ~-0.06085495958360287 217:0.390625:2480:2485 166:0.4375:2481:2482 ~0.04613307192036631 37:-0.140625:2483:2484 ~-0.05779429050422186 ~0.02603084608103903 "
    s .= "163:0.421875:2486:2487 ~0.03386833287542131 ~-0.04494701773245526 ~-0.026518976549685325 219:0.328125:2490:2491 ~-0.04953941742177949 ~0.009817640826441305 253:-0.042911505141282065:2493:2508 26:-0.109375:2494:2497 "
    s .= "193:-0.21875:2495:2496 ~-0.020511365215175013 ~0.03979843231236172 252:0.175:2498:2503 244:1.35:2499:2500 ~-0.05962169169267261 235:0.03125:2501:2502 ~-0.04243390305180753 ~0.034896544991587695 244:0.925:2504:2505 "
    s .= "~-0.04052970661801427 257:0.38:2506:2507 ~0.03934791963014679 ~-0.07577302148923044 249:1.5:2509:2538 244:0.82:2510:2511 ~-0.04390541138143494 243:1.45:2512:2535 85:1.171875:2513:2530 254:1.109375:2514:2529 "
    s .= "198:-0.59375:2515:2516 ~-0.05098223335625564 212:0.46875:2517:2528 144:0.046875:2518:2523 98:-0.984375:2519:2520 ~0.055913004538230754 217:0.203125:2521:2522 ~0.0031204807890439362 ~-0.03798285775008077 "
    s .= "246:0.109375:2524:2525 ~0.0004371791610981794 98:0.296875:2526:2527 ~0.05384011085812767 ~-0.002043281043781344 ~-0.03403302565586538 ~-0.041417550528670376 28:0.75:2531:2534 232:-0.21875:2532:2533 "
    s .= "~-0.025067691274103212 ~0.043609395449109106 ~-0.04443498990241193 251:1.796875:2536:2537 ~-0.04823635113871737 ~0.025772680578774257 ~-0.04773710205269653 251:0.796875:2540:2567 97:0.21875:2541:2566 26:0.125:2542:2565 "
    s .= "196:-0.21875:2543:2544 ~-0.04219895342076814 85:0.78125:2545:2562 133:0.0625:2546:2549 139:0.5:2547:2548 ~-0.009275048388507416 ~0.10438163480690366 254:1.265625:2550:2561 106:-0.109375:2551:2554 90:0.7265625:2552:2553 "
    s .= "~0.03251897619909199 ~0.3602117746461305 229:0.453125:2555:2560 190:-0.03125:2556:2559 76:0.625:2557:2558 ~-0.049726325653561845 ~0.08277191737765527 ~-0.0024272972713499843 ~0.032483990768463825 ~-0.049368577860280254 "
    s .= "142:0.6875:2563:2564 ~0.04585344478300676 ~-0.03170475025080717 ~-0.03751747457253156 ~-0.04141577641271534 220:-0.171875:2568:2573 252:0.175:2569:2570 ~-0.04562002943601843 255:0.421875:2571:2572 ~0.02853319600027476 "
    s .= "~-0.049050933074377384 209:0.578125:2574:2585 241:0.4:2575:2582 184:0.046875:2576:2579 190:0.046875:2577:2578 ~-0.057010869377084106 ~0.01074938836816867 74:0.09375:2580:2581 ~0.03711130686940637 ~-0.03315990137887348 "
    s .= "163:-0.4375:2583:2584 ~-0.04185877246647193 ~0.04094019155829015 ~-0.033847949650243944 249:1.5:2587:2630 244:0.82:2588:2589 ~-0.042868073298755666 85:1.171875:2590:2623 75:0.1796875:2591:2616 74:0.109375:2592:2613 "
    s .= "46:0.28125:2593:2610 187:-0.03125:2594:2599 184:0.0625:2595:2596 ~-0.04171916009676127 31:0.234375:2597:2598 ~0.03038547137018163 ~-0.05183561746243634 238:0.234375:2600:2607 145:0.140625:2601:2606 "
    s .= "217:-0.140625:2602:2603 ~-0.022443058673909853 109:0.171875:2604:2605 ~-0.0007900093009966495 ~0.048929651713243316 ~-0.0068047374581634516 244:1.48:2608:2609 ~-0.03463079793756263 ~0.03248536920314991 "
    s .= "214:1.28125:2611:2612 ~-0.040455243877481055 ~0.14612795695640343 9:0.1796875:2614:2615 ~-0.04286412467478792 ~0.002594095446822236 143:0.484375:2617:2622 255:0.328125:2618:2619 ~0.03767145626281124 "
    s .= "119:-0.546875:2620:2621 ~0.029031082543458687 ~-0.04127302023485153 ~-0.02696540632963884 205:-0.234375:2624:2625 ~-0.029232300711695348 28:0.828125:2626:2629 146:0.265625:2627:2628 ~0.045588626019549806 "
    s .= "~0.004887490411042796 ~-0.03382371902225645 240:0.28125:2631:2632 ~-0.04866872129926938 ~0.011866173007214095 26:-0.125:2634:2659 253:-0.02499999999999858:2635:2644 193:-0.21875:2636:2639 251:0.828125:2637:2638 "
    s .= "~-0.06356623950824701 ~0.015595809732324856 257:0.7741935483870968:2640:2643 248:1.125:2641:2642 ~0.041551783005435765 ~-0.029174665465554958 ~-0.013559183000443079 97:0.25:2645:2656 220:-0.09375:2646:2649 "
    s .= "101:-1.46875:2647:2648 ~0.07064581094766731 ~-0.02719684110415604 64:-0.0625:2650:2651 ~-0.016790192845167192 100:0.25:2652:2655 109:0.21875:2653:2654 ~-0.003612966281842442 ~0.03982482402288676 ~-0.007537180374433016 "
    s .= "251:1.640625:2657:2658 ~-0.03526281681976481 ~0.031829452911107364 249:0.5:2660:2675 244:0.925:2661:2662 ~-0.03730247922769483 255:0.265625:2663:2674 246:0.140625:2664:2667 201:0:2665:2666 ~0.030658440788269015 "
    s .= "~-0.035208886253509646 242:0.55:2668:2671 140:0.28125:2669:2670 ~0.021950167979284185 ~-0.062148047250246356 212:0.6875:2672:2673 ~0.048045810703946264 ~-0.05740746240399981 ~-0.029082780169557666 234:0.3125:2676:2677 "
    s .= "~-0.04768382743247129 152:0.203125:2678:2679 ~0.030269514475115007 ~-0.034376314560878744 244:0.82:2681:2682 ~-0.04330842519631364 249:1.8333333333333335:2683:2724 85:1.1875:2684:2717 144:0.140625:2685:2704 "
    s .= "146:0.109375:2686:2703 190:-0.078125:2687:2690 229:0.703125:2688:2689 ~-0.03542342732455855 ~0.04231591050687049 257:0.9130434782608695:2691:2700 255:0.265625:2692:2695 231:-0.609375:2693:2694 ~-0.050591055114214495 "
    s .= "~0.03276392603596416 17:-0.46875:2696:2697 ~0.021278334345700575 244:1.465:2698:2699 ~-0.050618201173952326 ~0.0061079650125149074 245:1.88:2701:2702 ~-0.0563621546076324 ~0.019136126801279713 ~-0.03386979826030069 "
    s .= "167:0.625:2705:2716 255:0.328125:2706:2711 81:-0.0703125:2707:2708 ~-0.01922688020982638 245:1.1894736842105262:2709:2710 ~-0.07526775691918688 ~0.041003254008262095 53:-0.59375:2712:2715 158:-0.328125:2713:2714 "
    s .= "~-0.028451904091672742 ~0.0695252969165197 ~-0.04756135348299957 ~-0.04804948087327727 205:-0.234375:2718:2719 ~-0.026032422254544982 142:0.6875:2720:2723 194:0.21875:2721:2722 ~0.04654475064910046 "
    s .= "~0.0015751854139556144 ~-0.009277810921843987 171:0.1875:2725:2726 ~-0.051456342851572336 ~0.0229661429574856 251:0.828125:2728:2759 97:0.21875:2729:2758 26:0.125:2730:2757 196:-0.21875:2731:2732 ~-0.03995854173575549 "
    s .= "85:0.78125:2733:2754 133:0.0625:2734:2737 139:0.5:2735:2736 ~-0.004945045009218767 ~0.10109021587280509 254:1.265625:2738:2753 95:0.21875:2739:2752 89:0.015625:2740:2749 245:1.1894736842105262:2741:2742 "
    s .= "~0.23185707053597954 98:-0.984375:2743:2746 246:-1.109375:2744:2745 ~0.026788019485581762 ~0.20239111990659242 109:0.765625:2747:2748 ~-0.028226898691419634 ~0.00797866096535798 143:0.078125:2750:2751 "
    s .= "~0.051644957242171774 ~-0.021792385115982082 ~-0.05082072468583108 ~-0.04767548448813566 142:0.6875:2755:2756 ~0.04353873917714495 ~-0.02980999326301135 ~-0.03497704251737512 ~-0.03903927028887173 252:0.175:2760:2765 "
    s .= "196:0.015625:2761:2762 ~-0.03592634622953777 74:0.109375:2763:2764 ~0.02868085818303138 ~-0.04370686221726561 245:1.1129032258064515:2766:2767 ~-0.06302047863068877 255:0.515625:2768:2771 20:0.71875:2769:2770 "
    s .= "~0.04004965185899814 ~-0.060155381986020655 143:-0.40625:2772:2773 ~0.03123771176431929 ~-0.052823564659498716 249:1.5:2775:2818 244:0.82:2776:2777 ~-0.041181249586142575 85:1.171875:2778:2811 251:1.671875:2779:2806 "
    s .= "43:0.28125:2780:2805 255:0.234375:2781:2798 254:0.484375:2782:2785 243:1.45:2783:2784 ~0.0017767173762983732 ~-0.04932296992829607 133:0.890625:2786:2793 246:-0.609375:2787:2788 ~-0.000451103327987756 "
    s .= "244:0.855:2789:2790 ~0.19439979452183442 11:0.484375:2791:2792 ~0.053489145000753385 ~0.23539877170743725 197:0.125:2794:2797 187:-0.046875:2795:2796 ~-0.02811821160112792 ~0.04984398758791156 ~-0.03208908095906122 "
    s .= "47:-0.5:2799:2802 22:-0.21875:2800:2801 ~-0.04977443231977305 ~0.02059582792384305 244:1.395:2803:2804 ~-0.05391101735622703 ~-0.013556615850398444 ~-0.03771484871878805 241:0.52:2807:2810 200:0.015625:2808:2809 "
    s .= "~0.018811113352399714 ~-0.08145307834353072 ~0.04636608349141544 205:-0.234375:2812:2813 ~-0.026771273700565475 28:0.828125:2814:2817 124:1.03125:2815:2816 ~0.04341091693369078 ~-0.0023619165812563334 "
    s .= "~-0.0330433051284746 219:0.328125:2819:2820 ~-0.047649031617637165 ~0.01164243694229163 244:0.82:2822:2823 ~-0.042051737805713696 249:1.8333333333333335:2824:2865 85:1.1875:2825:2856 144:0.140625:2826:2849 "
    s .= "193:0.265625:2827:2844 190:-0.015625:2828:2837 31:0.046875:2829:2836 205:0.28125:2830:2835 82:0.15625:2831:2832 ~-0.04706325543109626 130:0.3125:2833:2834 ~0.07886154614400523 ~-0.0212011654644517 ~0.039425180428546466 "
    s .= "~-0.044697581909245686 238:0.359375:2838:2843 249:0.16666666666666666:2839:2840 ~0.031159001221281707 146:0.09375:2841:2842 ~0.012707007276791474 ~-0.042814292975988544 ~-0.024293927437070345 251:0.515625:2845:2846 "
    s .= "~-0.05102258913770426 26:-0.171875:2847:2848 ~0.006689564091674436 ~-0.05005012153683457 167:0.5625:2850:2855 33:0.21875:2851:2854 190:-0.140625:2852:2853 ~-0.05624450357271482 ~0.014428135706429632 ~0.03954750015433032 "
    s .= "~-0.0396384601015868 208:-0.265625:2857:2860 257:0.017543859649122806:2858:2859 ~-0.05568655124895361 ~0.03262150682042283 194:0.21875:2861:2864 142:0.6875:2862:2863 ~0.04557799636246329 ~-0.0065403056849819875 "
    s .= "~-0.005071482737554267 171:0.1875:2866:2867 ~-0.05096718091633055 ~0.022235489877894764 251:0.828125:2869:2894 249:0.5:2870:2887 31:0.15625:2871:2884 128:0.34375:2872:2883 193:0.203125:2873:2880 199:-0.25:2874:2875 "
    s .= "~-0.04161671216535698 163:-0.28125:2876:2877 ~-0.055917704136112904 245:1.368421052631579:2878:2879 ~-0.060036128200685636 ~0.03258830497312308 124:0.3125:2881:2882 ~0.010375064095277609 ~-0.04841308436172634 "
    s .= "~-0.038227639918585174 85:1.40625:2885:2886 ~-0.036772314694796235 ~0.019562713923785224 216:0.125:2888:2889 ~-0.04299439742738832 53:0.046875:2890:2893 73:0.1875:2891:2892 ~0.03565898072418063 ~-0.03550992017673208 "
    s .= "~-0.04799583284068629 252:0.175:2895:2902 196:0.015625:2896:2897 ~-0.03436549931735788 122:0.0625:2898:2901 127:1.21875:2899:2900 ~0.03509221953255708 ~-0.033097887656348454 ~-0.03184069961128792 "
    s .= "245:1.1129032258064515:2903:2904 ~-0.06188241505436401 243:1.35:2905:2910 243:0.75:2906:2909 223:0.046875:2907:2908 ~-0.040014456226002845 ~0.033783884933054995 ~0.046138697540466816 244:0.98:2911:2912 "
    s .= "~-0.038684850002610245 49:0.5:2913:2914 ~0.03100715007942369 ~-0.07127923915458545 249:1.5:2916:2959 244:0.82:2917:2918 ~-0.039638106939983556 85:0.78125:2919:2948 251:1.640625:2920:2945 4:0.28125:2921:2944 "
    s .= "243:1.45:2922:2943 133:0.234375:2923:2926 250:0.6796875:2924:2925 ~-0.08689763806731736 ~0.046414480048778496 184:0.90625:2927:2942 190:-0.09375:2928:2929 ~-0.04742277935039297 97:-0.25:2930:2931 ~-0.05704568915356115 "
    s .= "218:0.25:2932:2941 254:1.265625:2933:2940 257:0.8:2934:2939 157:0.140625:2935:2938 103:0.40625:2936:2937 ~-0.02909149084698869 ~0.06874467508618656 ~0.03252513574714032 ~-0.028984085526892973 ~-0.03533994889005212 "
    s .= "~-0.031915503695244686 ~0.04173132808203945 ~-0.044303113086956156 ~-0.0359772825918077 190:-0.328125:2946:2947 ~-0.06373351764606734 ~0.03694612415193812 37:0.515625:2949:2958 232:-0.0625:2950:2953 55:-0.1875:2951:2952 "
    s .= "~-0.04734297072090694 ~0.014848741648632544 208:-0.25:2954:2955 ~-0.05470734396037226 166:0.4375:2956:2957 ~0.044283888731218725 ~0.005756858879687423 ~-0.025021848087296784 240:0.265625:2960:2961 ~-0.046905158647495226 "
    s .= "~0.010661819638946957 26:-0.125:2963:2988 253:-0.042911505141282065:2964:2967 55:-0.4375:2965:2966 ~-0.04309965391752177 ~0.03447210894806601 97:0.25:2968:2985 226:-0.359375:2969:2970 ~-0.05040701434795519 "
    s .= "190:-0.015625:2971:2972 ~-0.008577019539101652 121:-0.1875:2973:2976 123:0.265625:2974:2975 ~-0.0469353191632568 ~0.05107370181101967 233:0.15625:2977:2984 137:-0.0625:2978:2983 133:0.78125:2979:2982 "
    s .= "202:-0.328125:2980:2981 ~0.15653669168911813 ~-0.025961780242322964 ~0.031051440043873266 ~0.05581434111277072 ~-0.02188325538351455 251:1.640625:2986:2987 ~-0.032096088510419146 ~0.029746814219568735 "
    s .= "249:0.8333333333333333:2989:3006 244:0.935:2990:2993 251:1.078125:2991:2992 ~-0.0414529290230754 ~0.025635989103495967 254:1.046875:2994:3005 48:0.2265625:2995:3002 217:0.25:2996:3001 163:-0.046875:2997:3000 "
    s .= "235:0.0625:2998:2999 ~-0.042038197505724455 ~0.03813578317555146 ~0.014319900177105493 ~-0.042111740225900245 170:0.5:3003:3004 ~0.04070132493849321 ~-0.038353071359346284 ~-0.06334762104241497 168:0.28125:3007:3008 "
    s .= "~-0.04977631228005593 ~-0.003337427454440361 217:-0.140625:3010:3017 249:0.8333333333333333:3011:3016 152:-0.140625:3012:3013 ~0.007395845564444022 251:1.484375:3014:3015 ~-0.04477380452910751 ~0.027896139707816733 "
    s .= "~-0.048898510651494614 244:0.82:3018:3023 133:-0.125:3019:3022 191:0.03125:3020:3021 ~0.11301260614060088 ~-0.04135872011839886 ~-0.04554167169471222 193:0.265625:3024:3049 85:0.78125:3025:3044 251:0.828125:3026:3039 "
    s .= "133:0.1875:3027:3030 244:1.375:3028:3029 ~0.07378036075975856 ~-0.026616080828014577 190:-0.078125:3031:3032 ~-0.04553987998171141 82:0.296875:3033:3036 248:0.625:3034:3035 ~0.022938815871267546 ~-0.035878455895555036 "
    s .= "169:-0.046875:3037:3038 ~0.030204416878578017 ~-0.04276407435650001 243:0.75:3040:3043 190:0.125:3041:3042 ~-0.026993088208900968 ~0.031928652492023604 ~0.03759304080619617 163:-0.28125:3045:3046 ~-0.057800702027730355 "
    s .= "142:0.78125:3047:3048 ~0.04077245016328343 ~-0.007287913304388294 251:0.515625:3050:3051 ~-0.04227781718115076 29:-0.0625:3052:3055 144:-0.0625:3053:3054 ~-0.011130056799576167 ~0.035465709682632594 "
    s .= "~-0.03397084360299502 249:1.8333333333333335:3057:3102 244:0.82:3058:3059 ~-0.0388718348784571 85:1.1875:3060:3095 144:0.140625:3061:3080 146:0.09375:3062:3075 43:0.28125:3063:3074 94:-0.21875:3064:3065 "
    s .= "~-0.03037802496313057 187:0.015625:3066:3071 184:0.09375:3067:3070 24:0.09375:3068:3069 ~-0.04292906064375306 ~0.020208266341080094 ~0.01785109046046297 257:0.9130434782608695:3072:3073 ~0.02523673965545302 "
    s .= "~-0.024868994819498582 ~-0.029867038059103942 249:0.16666666666666666:3076:3079 110:0.15625:3077:3078 ~-0.0358227324305694 ~0.015355890664948533 ~-0.0498059707231534 191:0.578125:3081:3094 255:0.328125:3082:3089 "
    s .= "105:-0.0703125:3083:3084 ~-0.022095129969982228 197:0.6875:3085:3088 220:-0.0625:3086:3087 ~0.00557755740347374 ~0.0447097611960803 ~-0.06152183312014038 53:-0.59375:3090:3093 158:-0.328125:3091:3092 "
    s .= "~-0.029762341236353042 ~0.06588021349073218 ~-0.04674511347400073 ~-0.04671581626767784 208:-0.203125:3096:3099 66:0.140625:3097:3098 ~0.0011698486508902278 ~-0.10442763776035618 194:0.21875:3100:3101 "
    s .= "~0.04029297629949005 ~-0.006288093334433524 ~-0.044794876300635195 251:0.828125:3104:3137 208:-0.25:3105:3106 ~-0.048562065016522826 193:0.203125:3107:3130 85:0.78125:3108:3123 31:0.046875:3109:3120 "
    s .= "188:0.359375:3110:3119 205:0.28125:3111:3116 255:0.265625:3112:3115 184:0.0625:3113:3114 ~-0.014693494109336831 ~0.035012192713465846 ~-0.036090884443710954 166:0.21875:3117:3118 ~0.05953165052331177 "
    s .= "~-0.030077868467728825 ~-0.04725982189787845 61:0.9375:3121:3122 ~-0.03306830486305658 ~0.08325412542510462 142:0.6875:3124:3129 190:-0.25:3125:3126 ~-0.05300973818827296 160:-0.15625:3127:3128 ~-0.039385552894329046 "
    s .= "~0.04230506522194655 ~-0.03317380450994186 112:1.515625:3131:3136 21:0.4140625:3132:3133 ~-0.0452652586043024 106:0.03125:3134:3135 ~0.09476402541400973 ~-0.03708325488306724 ~0.022187745097786444 252:0.175:3138:3143 "
    s .= "196:0.015625:3139:3140 ~-0.032791179993280954 122:0.0625:3141:3142 ~0.026284173491473817 ~-0.030399068017288745 253:-0.026309607704955728:3144:3145 ~0.038978882283751126 251:1.796875:3146:3149 106:0.765625:3147:3148 "
    s .= "~-0.03446481029843924 ~0.015363109510939714 ~0.038434143825019584 249:1.8333333333333335:3151:3196 244:0.82:3152:3155 127:0.859375:3153:3154 ~-0.04206216239083426 ~0.02975938851948781 85:1.1875:3156:3187 "
    s .= "75:0.1796875:3157:3182 238:0.234375:3158:3175 163:-0.09375:3159:3160 ~-0.03613824953253176 145:0.140625:3161:3170 74:0.109375:3162:3169 211:-0.203125:3163:3164 ~-0.03899483869367989 255:0.265625:3165:3166 "
    s .= "~0.038822163108819994 146:-0.515625:3167:3168 ~0.034473720255874175 ~-0.013941504347285447 ~-0.016287155153619757 160:-0.25:3171:3172 ~0.1317628936220636 190:-0.125:3173:3174 ~-0.06958584046744586 ~-0.012405389767238456 "
    s .= "244:1.465:3176:3181 220:1.34375:3177:3180 112:-0.4375:3178:3179 ~0.05457189905355817 ~-0.05293468038819206 ~0.07294925442990263 ~0.017983770310290293 143:0.5:3183:3186 241:0.22:3184:3185 ~0.0023497677929464117 "
    s .= "~0.034662741295340256 ~-0.02882723310941699 194:-0.15625:3188:3189 ~0.04030684232687529 181:1.546875:3190:3195 254:1.046875:3191:3194 184:-0.1875:3192:3193 ~-0.041030528617077136 ~0.027693362337718172 "
    s .= "~-0.06008245350808836 ~-0.05656377234714188 ~-0.04408296110207339 217:-0.140625:3198:3207 249:0.8333333333333333:3199:3206 152:-0.140625:3200:3203 251:0.515625:3201:3202 ~-0.020945142477553403 ~0.02611671274154828 "
    s .= "251:1.484375:3204:3205 ~-0.043116145922522955 ~0.026731053200961443 ~-0.04783002439963013 244:0.82:3208:3213 133:-0.125:3209:3212 191:0.03125:3210:3211 ~0.10645275150546472 ~-0.03940537527155025 ~-0.0442130895037247 "
    s .= "193:0.265625:3214:3235 85:0.78125:3215:3230 251:0.828125:3216:3229 133:0.1875:3217:3220 244:1.375:3218:3219 ~0.0704834344875596 ~-0.025486974002539572 190:-0.078125:3221:3222 ~-0.04372112207094627 82:0.296875:3223:3226 "
    s .= "248:0.625:3224:3225 ~0.021679097353629655 ~-0.03433782326524734 169:-0.046875:3227:3228 ~0.029676177014669427 ~-0.04058455651776646 ~0.0237664522918286 208:-0.25:3231:3232 ~-0.047107579663218525 142:0.78125:3233:3234 "
    s .= "~0.03945738783748448 ~-0.009639526252477174 251:0.515625:3236:3237 ~-0.040203625498342284 29:-0.0625:3238:3243 144:-0.0625:3239:3242 122:-0.796875:3240:3241 ~0.02522942358959844 ~-0.045269820158309715 "
    s .= "~0.03346353034459961 ~-0.03234420727649535 26:-0.125:3245:3272 253:-0.042911505141282065:3246:3255 36:0.015625:3247:3254 248:0.125:3248:3249 ~0.03811007660048654 203:0.265625:3250:3253 252:0.32499999999999996:3251:3252 "
    s .= "~-0.04096857394543502 ~0.01933362406150117 ~-0.1280932420366528 ~0.04219730709895539 190:-0.328125:3256:3257 ~-0.04495352947839589 1:0.375:3258:3271 53:-0.9375:3259:3260 ~0.037569537881728135 113:0:3261:3266 "
    s .= "244:0.95:3262:3263 ~-0.04400166872091626 157:0.015625:3264:3265 ~-0.03857148984298076 ~0.008249465679899714 191:0.0625:3267:3268 ~0.04325707566299914 1:0.15625:3269:3270 ~-0.03040630527194385 ~0.06966114106995704 "
    s .= "~-0.03610051197164018 249:0.8333333333333333:3273:3288 244:0.935:3274:3275 ~-0.03194158420340096 254:1.046875:3276:3287 48:0.2265625:3277:3284 243:2.05:3278:3283 202:0.25:3279:3282 31:1.203125:3280:3281 "
    s .= "~0.01714717083212643 ~-0.048404206240354346 ~-0.021638027781578854 ~-0.051170646576196965 170:0.5:3285:3286 ~0.0383165082559684 ~-0.03648483343977376 ~-0.061487162487353975 168:0.28125:3289:3290 ~-0.048458762414247195 "
    s .= "~-0.0016084339654876688 220:-0.265625:3292:3295 56:-1.5:3293:3294 ~0.05014814100797102 ~-0.03988539829844907 244:0.805:3296:3297 ~-0.038609019100198656 251:0.296875:3298:3307 31:0.21875:3299:3306 163:-0.046875:3300:3301 "
    s .= "~-0.04166770683213672 193:0.15625:3302:3305 248:0.875:3303:3304 ~0.025137910292668736 ~-0.04160354270651272 ~-0.026289477638331983 ~-0.047832048391715475 88:0.75:3308:3333 79:0.78125:3309:3332 190:-0.140625:3310:3311 "
    s .= "~-0.03619595613029103 146:-0.078125:3312:3321 254:1.265625:3313:3318 138:-0.0859375:3314:3317 122:-0.515625:3315:3316 ~0.026561245549755055 ~-0.0172521706282654 ~0.03690878174686663 50:-0.6875:3319:3320 "
    s .= "~0.014779508448767333 ~-0.06237050596600607 87:0.0078125:3322:3327 240:0.40625:3323:3324 ~-0.03871829713236118 58:0.1875:3325:3326 ~-0.024926053963187186 ~-0.3546322403188462 212:0.578125:3328:3331 "
    s .= "255:0.265625:3329:3330 ~0.022081340419071397 ~-0.03355483106170118 ~-0.05851303632311966 ~0.030836381979013724 172:-0.1875:3334:3335 ~-0.03223373406633503 26:0.265625:3336:3337 ~0.03875235250140835 "
    s .= "~-0.013502485775130156 249:1.8333333333333335:3339:3384 244:0.805:3340:3341 ~-0.03868817200350168 85:1.1875:3342:3377 255:0.265625:3343:3366 254:0.734375:3344:3359 251:1.765625:3345:3356 245:1.5529411764705883:3346:3351 "
    s .= "244:1.355:3347:3350 193:-0.609375:3348:3349 ~0.20585978417455975 ~-0.07022453758242712 ~0.03786102497238215 190:-0.078125:3352:3353 ~-0.02883320767427415 220:-0.171875:3354:3355 ~-0.04044462002004237 "
    s .= "~0.013382687845102534 241:0.52:3357:3358 ~-0.03222939446796661 ~0.04235196403837575 251:0.203125:3360:3361 ~-0.007825881565421673 257:0.16666666666666666:3362:3365 236:0.25:3363:3364 ~0.05528190064211824 "
    s .= "~0.005660631135746027 ~-0.0076585545144151074 98:-0.515625:3367:3374 110:-0.390625:3368:3371 109:1.03125:3369:3370 ~-0.0238842633149316 ~0.02741740287163444 97:-0.09375:3372:3373 ~-0.03228303751711658 "
    s .= "~0.050321342050457275 254:0.828125:3375:3376 ~-0.017610827593566504 ~-0.052993680700397616 194:-0.15625:3378:3379 ~0.03825254148830221 181:1.546875:3380:3383 254:1.046875:3381:3382 ~0.019175913731232605 "
    s .= "~-0.05840952112165546 ~-0.055041388571605745 ~-0.04268405818301326 26:0.109375:3386:3417 211:-0.1875:3387:3390 195:0.171875:3388:3389 ~-0.03616795162767999 ~0.009071351344367973 253:-0.05:3391:3394 34:0.21875:3392:3393 "
    s .= "~0.03588424066036885 ~-0.003420194842391741 73:0.203125:3395:3412 184:0.03125:3396:3399 109:0.15625:3397:3398 ~-0.04856952972809785 ~-0.0016192861075211371 254:1.359375:3400:3409 166:0.515625:3401:3408 "
    s .= "197:0.25:3402:3407 110:-0.03125:3403:3406 98:-0.984375:3404:3405 ~0.0626472175132353 ~0.013247721692004997 ~0.04981132065846346 ~-0.013381050822688482 ~-0.015531479697490727 32:-0.53125:3410:3411 ~0.008703222686090716 "
    s .= "~-0.066793917267884 251:1.640625:3413:3416 157:1.171875:3414:3415 ~-0.03834803133605237 ~0.0150220580426223 ~0.03881967544988331 251:1.265625:3418:3427 249:0.5:3419:3426 67:0.140625:3420:3425 139:0.671875:3421:3422 "
    s .= "~-0.021116619281798716 135:-0.1953125:3423:3424 ~-0.05524407768670114 ~0.048658317432761417 ~-0.04202404080020175 ~-0.0476526279668919 241:0.6:3428:3431 149:-0.171875:3429:3430 ~0.06164330960029535 ~-0.07817893994080272 "
    s .= "~0.029031734523274247 217:-0.140625:3433:3444 235:-0.265625:3434:3435 ~-0.04687268657635763 58:1.015625:3436:3441 251:1.390625:3437:3440 157:1.09375:3438:3439 ~-0.04059563800980757 ~0.008964045868336261 "
    s .= "~0.020907754632068197 4:-0.296875:3442:3443 ~-0.06420860707728303 ~0.05352264863440225 193:0.265625:3445:3474 233:0.15625:3446:3467 49:0.296875:3447:3466 190:-0.03125:3448:3451 133:1.625:3449:3450 ~0.012641413463131952 "
    s .= "~-0.038382376014724176 133:2.4375:3452:3465 248:0.875:3453:3460 142:0.328125:3454:3455 ~0.039349722193260585 109:0.875:3456:3459 201:0.921875:3457:3458 ~-0.023318094037421883 ~0.23761981321830605 ~0.034395956803159496 "
    s .= "231:0.0625:3461:3462 ~-0.03383186368610661 14:0.0625:3463:3464 ~0.08119289639418666 ~-0.04610483965933953 ~-0.07894645781246139 ~-0.015206609361717688 239:0.578125:3468:3473 246:0.109375:3469:3470 ~-0.04125648191427682 "
    s .= "244:0.925:3471:3472 ~-0.03456682701003183 ~0.02013786922144565 ~-0.04715081557243694 251:0.828125:3475:3476 ~-0.03516566163915706 142:0.328125:3477:3478 ~0.019016155969158375 ~-0.025660153399241367 "
    s .= "249:1.8333333333333335:3480:3525 244:0.805:3481:3482 ~-0.0374977495827319 85:1.265625:3483:3516 255:0.265625:3484:3509 254:0.734375:3485:3500 251:1.796875:3486:3497 245:1.5529411764705883:3487:3492 244:1.355:3488:3491 "
    s .= "193:-0.609375:3489:3490 ~0.18359171423999654 ~-0.06948384497796438 ~0.0364183493340151 190:-0.078125:3493:3494 ~-0.026545876528301073 166:0.515625:3495:3496 ~0.0151748098249338 ~-0.02677004630934456 252:0.275:3498:3499 "
    s .= "~-0.02625965884144619 ~0.04236485540776058 251:0.203125:3501:3502 ~-0.0072314533597472785 110:-0.390625:3503:3506 212:-0.25:3504:3505 ~0.020982116130801143 ~-0.07043737289857166 244:0.855:3507:3508 ~0.12849769510824047 "
    s .= "~0.04264525666702868 98:-0.515625:3510:3513 257:0.8571428571428571:3511:3512 ~0.013992729470636227 ~-0.04199737010769151 244:1.35:3514:3515 ~-0.047288657385299304 ~-0.011734348593902537 218:-0.15625:3517:3520 "
    s .= "160:-0.21875:3518:3519 ~-0.028553354608277817 ~0.041476955767444104 254:0.984375:3521:3524 181:1.703125:3522:3523 ~0.019747707146972975 ~-0.07816478859519953 ~-0.06490081635670675 ~-0.0416380287717648 "
    s .= "251:0.765625:3527:3552 208:-0.25:3528:3529 ~-0.04799629823422327 31:0.09375:3530:3545 233:0.125:3531:3544 166:0.296875:3532:3539 193:0.171875:3533:3536 211:-0.125:3534:3535 ~-0.016054339582116686 ~0.03459417089373589 "
    s .= "175:0.609375:3537:3538 ~-0.030006347992077367 ~0.054292924117356506 163:0.375:3540:3543 246:-0.015625:3541:3542 ~-0.01385069087435337 ~0.08242049251119557 ~-0.03880354611164534 ~-0.02197070509073218 "
    s .= "112:1.296875:3546:3549 61:1.328125:3547:3548 ~-0.03741833139611445 ~0.06025340360249812 169:0.0625:3550:3551 ~-0.043438592007636674 ~0.03781648816452307 241:0.46:3553:3560 184:0.046875:3554:3557 199:0.03125:3555:3556 "
    s .= "~-0.0573904453344008 ~-0.00504891279072279 74:0.109375:3558:3559 ~0.021808395558229745 ~-0.0382154949585103 243:1.45:3561:3568 249:1.1666666666666665:3562:3565 239:0.59375:3563:3564 ~0.04125360681170247 "
    s .= "~-0.03404870811691812 240:0.1875:3566:3567 ~-0.041923604180669316 ~0.04173398937906337 244:0.98:3569:3570 ~-0.05749621404941462 253:0.03703703703703809:3571:3572 ~0.023633997649740862 ~-0.08228310413803301 "
    s .= "248:0.875:3574:3615 217:-0.1875:3575:3578 105:-0.8984375:3576:3577 ~0.05444761411121268 ~-0.02784392976656494 31:0.234375:3579:3606 170:0.234375:3580:3599 120:0.234375:3581:3598 245:1.6231884057971016:3582:3587 "
    s .= "169:0.03125:3583:3586 11:-0.984375:3584:3585 ~0.14184732614986412 ~0.012021162438017945 ~-0.04895635521416557 133:2.46875:3588:3597 109:0.5:3589:3592 139:0.015625:3590:3591 ~-0.03898657348147955 ~0.012858667867789414 "
    s .= "115:-0.109375:3593:3596 241:0.26:3594:3595 ~-0.05467814816181844 ~0.02119364469788949 ~0.03246016776752466 ~-0.09293774054209218 ~0.040647588572108165 257:0.3333333333333333:3600:3603 136:0.9375:3601:3602 "
    s .= "~-0.023284815025418376 ~0.025450786429098732 47:0.40625:3604:3605 ~-0.18424549245766353 ~0.04499260883210258 112:1.28125:3607:3614 251:1.796875:3608:3613 82:0.171875:3609:3612 13:0.828125:3610:3611 ~-0.0184390648510984 "
    s .= "~0.09179214338610378 ~-0.04281513238588813 ~0.021896693691458906 ~0.026828907107641603 222:0.25:3616:3617 ~-0.034843710377854754 8:0.046875:3618:3619 ~0.03995657814141084 ~-0.03802326007966919 "
    s .= "249:1.8333333333333335:3621:3666 244:0.805:3622:3623 ~-0.03627248843968412 85:1.265625:3624:3659 255:0.265625:3625:3646 254:0.734375:3626:3639 113:0.9375:3627:3638 245:1.543859649122807:3628:3631 244:1.515:3629:3630 "
    s .= "~-0.05948243398029455 ~0.03256308173548977 190:-0.078125:3632:3633 ~-0.0220229401992217 167:0.59375:3634:3637 251:0.421875:3635:3636 ~-0.009686813643980581 ~0.02259607159850737 ~-0.048229304201594485 "
    s .= "~0.04495037509830414 251:0.203125:3640:3641 ~-0.006473150872796531 110:-0.390625:3642:3643 ~0.00024167358073221292 212:0.34375:3644:3645 ~0.051502846015540796 ~-0.009650262439783574 98:-0.515625:3647:3654 "
    s .= "161:-0.28125:3648:3651 244:1.035:3649:3650 ~-0.04050450707204659 ~0.011292358759707636 119:-0.390625:3652:3653 ~0.06190794494417521 ~-0.008969693189392027 254:0.828125:3655:3658 251:1.671875:3656:3657 "
    s .= "~-0.02547531042271961 ~0.03627329230383385 ~-0.05076556955574192 218:-0.15625:3660:3661 ~0.036868736502421486 254:0.984375:3662:3665 181:1.703125:3663:3664 ~0.018808135535370942 ~-0.07453843109579306 "
    s .= "~-0.0627855258774249 ~-0.04060814461324177 196:-0.28125:3668:3673 57:-0.6953125:3669:3670 ~0.043170177035992276 251:1.359375:3671:3672 ~-0.04500560470384742 ~0.004231570512007565 170:0.234375:3674:3705 "
    s .= "141:0.0390625:3675:3696 244:1.015:3676:3683 148:0.109375:3677:3682 4:-0.09375:3678:3679 ~-0.057648907103271474 194:-0.859375:3680:3681 ~0.08645904620239334 ~0.004570487377945961 ~-0.045104832039656644 "
    s .= "190:0.015625:3684:3689 31:0:3685:3688 211:0.015625:3686:3687 ~-0.010414159105657222 ~0.03191584460653956 ~-0.029409250128027482 94:0.59375:3690:3695 243:0.25:3691:3692 ~-0.03313025297054198 122:-0.421875:3693:3694 "
    s .= "~0.038051352321566034 ~0.012214136385453966 ~-0.032034570731619444 23:0.484375:3697:3704 254:1.296875:3698:3701 187:-0.09375:3699:3700 ~-0.0018463960882659056 ~0.03584095426685041 26:-0.71875:3702:3703 "
    s .= "~0.025666856665381512 ~-0.05253269661759272 ~-0.02757591982160621 246:-0.234375:3706:3707 ~-0.08433261910866972 197:0.609375:3708:3713 251:0.484375:3709:3710 ~-0.0297563590576045 254:1.015625:3711:3712 "
    s .= "~0.01211547778038965 ~-0.06306236877700429 ~-0.04874770371814561 253:-0.042911505141282065:3715:3734 252:0.175:3716:3723 122:0.09375:3717:3722 118:0.359375:3718:3721 81:0.1015625:3719:3720 ~0.0010552402717648637 "
    s .= "~0.041373775723189316 ~-0.052234032091267195 ~-0.047559832865171084 163:0.296875:3724:3727 208:-0.25:3725:3726 ~-0.012984939980273922 ~0.041992316536302865 244:1.065:3728:3731 166:0.15625:3729:3730 ~0.016347696475263376 "
    s .= "~-0.07451926803663651 238:1.015625:3732:3733 ~0.028825119284364084 ~-0.08522383313098197 249:1.8333333333333335:3735:3760 50:0.34375:3736:3759 254:1.109375:3737:3752 243:1.45:3738:3747 144:0.21875:3739:3746 "
    s .= "193:0.265625:3740:3745 66:0.375:3741:3744 245:3.514705882352941:3742:3743 ~0.01323435073219493 ~-0.06406548876117722 ~-0.03788050816188608 ~-0.01949395836175554 ~0.027568682870642448 245:2.1315789473684212:3748:3749 "
    s .= "~-0.04803578259611733 48:0.0078125:3750:3751 ~-0.064509125728649 ~0.03870388370357149 29:-0.515625:3753:3758 113:-0.15625:3754:3755 ~-0.024135022768819233 167:-0.171875:3756:3757 ~0.06136511122643536 "
    s .= "~-0.047263471138275864 ~-0.05711711639495222 ~-0.03336219173447655 ~-0.04564996420027289 220:-0.265625:3762:3767 9:-0.9765625:3763:3764 ~0.058026880490078606 251:1.234375:3765:3766 ~-0.045286249339656026 "
    s .= "~0.004050025962593837 194:0.21875:3768:3801 120:0.234375:3769:3798 121:0.203125:3770:3791 85:0.625:3771:3784 139:0.5:3772:3779 76:0.59375:3773:3778 190:0.015625:3774:3775 ~-0.03518549195787748 255:0.265625:3776:3777 "
    s .= "~0.01564733632619161 ~-0.02544370842662716 ~0.038465306334310626 22:0.21875:3780:3783 160:1.796875:3781:3782 ~0.03281814129559458 ~-0.061956150186780745 ~-0.03783532282740276 166:0.5625:3785:3790 124:0.703125:3786:3789 "
    s .= "106:2.484375:3787:3788 ~0.036960166067980686 ~-0.10934521702224063 ~-0.010886343680787532 ~-0.019120650319023283 244:1.015:3792:3793 ~-0.04074374477229309 225:0.0859375:3794:3795 ~-0.020225160231202573 "
    s .= "184:-0.21875:3796:3797 ~-0.08231844841041273 ~0.026056589298223177 72:1.078125:3799:3800 ~0.03238326045618662 ~-0.08715148819443871 246:-0.234375:3802:3803 ~-0.07715879756383452 248:0.625:3804:3807 197:0.625:3805:3806 "
    s .= "~0.003736888894867227 ~-0.050932476549370644 ~-0.043379865798702816 251:0.828125:3809:3836 249:1.1666666666666665:3810:3835 31:0.046875:3811:3830 128:0.4375:3812:3829 193:-0.265625:3813:3814 ~-0.033946097073134174 "
    s .= "193:0.203125:3815:3826 160:-0.125:3816:3819 79:0.65625:3817:3818 ~-0.059907604162649564 ~0.08030205049192524 243:2.25:3820:3825 166:0.265625:3821:3824 205:0.140625:3822:3823 ~0.019211553442406794 ~0.050246493154839644 "
    s .= "~0.00014878469791630662 ~-0.06691629986651665 247:0.109375:3827:3828 ~-0.0330877322167518 ~0.0350312112477208 ~-0.04098377621000724 245:1.736842105263158:3831:3832 ~-0.04153589260324542 251:0.453125:3833:3834 "
    s .= "~-0.02721122943987091 ~0.010894085628354212 ~-0.04114217013133602 241:0.46:3837:3846 184:0.046875:3838:3843 228:0.34375:3839:3840 ~-0.019676725010922658 82:1.390625:3841:3842 ~-0.0640439270517323 ~-0.2887776289200829 "
    s .= "74:0.109375:3844:3845 ~0.019966168214921864 ~-0.03688204697803649 243:1.35:3847:3850 214:0.5625:3848:3849 ~0.038053973096371416 ~-0.03094061606070544 244:0.98:3851:3852 ~-0.04110234271206135 49:0.484375:3853:3854 "
    s .= "~0.023227047398568904 ~-0.06559364911022987 253:-0.06072351421188513:3856:3869 252:0.175:3857:3864 122:0.09375:3858:3863 57:0.1484375:3859:3862 248:0.125:3860:3861 ~0.022992028887463184 ~-0.03236911942632247 "
    s .= "~0.040109545610809705 ~-0.0454723157239945 34:-0.34375:3865:3866 ~-0.02986287518436605 256:0.9545454545454546:3867:3868 ~0.036726564726344134 ~-0.06634290276030569 220:-0.265625:3870:3873 57:-0.9296875:3871:3872 "
    s .= "~0.05221249777561152 ~-0.041450171933716695 23:0.265625:3874:3901 254:1.046875:3875:3894 246:0.140625:3876:3887 236:0.09375:3877:3886 193:0.203125:3878:3885 184:-0.0625:3879:3880 ~-0.020381177224982686 "
    s .= "170:-0.515625:3881:3882 ~0.04024457207193559 20:0.0625:3883:3884 ~-0.0004402659407776723 ~0.052444471735439625 ~-0.021979997524239656 ~-0.052499218136503316 200:0.25:3888:3893 144:0.03125:3889:3890 ~0.008514511076500357 "
    s .= "245:1.1129032258064515:3891:3892 ~-0.06561108755262997 ~0.05076911687870821 ~-0.009389367022683483 29:-0.46875:3895:3900 158:-0.28125:3896:3899 157:0.828125:3897:3898 ~-0.03850194808716526 ~0.01755835714817902 "
    s .= "~0.0404115235803244 ~-0.058341210987289144 ~-0.02663340607650985 249:1.8333333333333335:3903:3946 85:1.1875:3904:3941 251:1.140625:3905:3934 95:0.421875:3906:3933 255:0.234375:3907:3924 255:0.109375:3908:3921 "
    s .= "156:0.7109375:3909:3920 139:1.171875:3910:3919 190:-0.03125:3911:3912 ~-0.03977929806239351 73:0.234375:3913:3918 245:1.5529411764705883:3914:3917 1:0.796875:3915:3916 ~-0.04456144516098208 ~0.302636596600818 "
    s .= "~0.013858891592493284 ~-0.04489918770664827 ~0.027949275644079855 ~0.07241397682781558 219:0.140625:3922:3923 ~0.011031253936016573 ~0.051091112605470994 77:-0.453125:3925:3932 161:-0.28125:3926:3929 "
    s .= "109:1.03125:3927:3928 ~-0.03563659758304271 ~0.01942852318431517 119:-0.515625:3930:3931 ~0.08182687370185387 ~-0.009772729776146058 ~-0.03843179180471508 ~-0.047935222594771516 241:0.52:3935:3938 77:0.4375:3936:3937 "
    s .= "~-0.0019733397057681156 ~-0.08310031920928185 243:1.25:3939:3940 ~0.04625997181311023 ~0.005799734595664323 160:-0.203125:3942:3943 ~-0.03495788820048485 166:0.65625:3944:3945 ~0.030474210340730497 "
    s .= "~-0.015782628621015364 171:0.1875:3947:3948 ~-0.04830302977858417 ~0.011025690825930239 248:0.875:3950:3985 190:-0.078125:3951:3958 51:0.3203125:3952:3957 175:0.25:3953:3956 126:-0.59375:3954:3955 ~0.04866382832751656 "
    s .= "~-0.014284467653992062 ~-0.0452570599726631 ~0.012825749654735109 166:0.3125:3959:3976 88:0.96875:3960:3973 236:0.5625:3961:3972 89:0.796875:3962:3971 218:0.125:3963:3970 255:0.265625:3964:3965 ~0.02636012541623687 "
    s .= "41:-0.453125:3966:3969 161:-0.21875:3967:3968 ~0.006907303438766949 ~0.06368387199375003 ~-0.0322186386569719 ~-0.015137440594821317 ~0.057622939053681224 ~-0.04444194960668479 172:-0.15625:3974:3975 "
    s .= "~-0.027179526016554857 ~0.04334912737680908 244:1.085:3977:3982 243:0.25:3978:3981 240:0.5:3979:3980 ~0.00467452049457595 ~0.19182088872877545 ~-0.048183383085902115 238:0.625:3983:3984 ~0.013699286041926407 "
    s .= "~-0.038209763729075516 251:0.515625:3986:3987 ~-0.04214776182947469 122:-0.078125:3988:3995 31:0.328125:3989:3992 228:0.125:3990:3991 ~-0.030166723477584874 ~0.039400318811290296 73:0.203125:3993:3994 "
    s .= "~0.09570955944554445 ~-0.018371696856138174 ~-0.03571116259908913 253:-0.06072351421188513:3997:4016 248:0.125:3998:4003 31:0.1875:3999:4000 ~0.040108292857476774 112:1.328125:4001:4002 ~-0.03206111672163338 "
    s .= "~0.04964812625143888 9:0.1328125:4004:4009 252:0.475:4005:4006 ~-0.040174902533880404 43:-0.25:4007:4008 ~-0.07619421249534168 ~0.029905599638515502 71:0.140625:4010:4011 ~0.03965084441650634 242:0.35:4012:4015 "
    s .= "164:0.25:4013:4014 ~-0.38445558677526154 ~-0.029583821155218085 ~-0.005259536205507115 220:-0.265625:4017:4018 ~-0.03516773042319976 236:0.59375:4019:4042 254:1.046875:4020:4037 251:0.421875:4021:4030 241:0.3:4022:4029 "
    s .= "28:0.140625:4023:4028 208:0.296875:4024:4027 103:0.359375:4025:4026 ~-0.013043862806759426 ~0.05151369081684376 ~0.040105384239243765 ~-0.02989363288985318 ~-0.035736520469667216 130:1.875:4031:4034 243:2.05:4032:4033 "
    s .= "~0.018251824296501122 ~-0.055279367351981135 226:0:4035:4036 ~-0.0897102847223672 ~-0.0026167163883297254 29:-0.390625:4038:4041 158:-0.28125:4039:4040 ~-0.018339687973918932 ~0.03210446785739477 ~-0.06187709202889276 "
    s .= "~-0.04670310351628007 249:1.8333333333333335:4044:4087 146:0.171875:4045:4080 257:0.9130434782608695:4046:4077 253:-0.05845467663649515:4047:4054 34:0.21875:4048:4049 ~0.03227178682272952 112:1.328125:4050:4053 "
    s .= "154:0.671875:4051:4052 ~-0.043837207648015596 ~0.0326320201698201 ~0.047306140702044294 254:1.109375:4055:4074 190:0.015625:4056:4063 184:0.046875:4057:4060 82:0.46875:4058:4059 ~-0.02984542734710391 "
    s .= "~0.015766867238962638 148:0.109375:4061:4062 ~0.028805032232029668 ~-0.020410356631960745 166:0.515625:4064:4069 52:-0.5625:4065:4068 251:0.359375:4066:4067 ~0.28575311635857703 ~0.06522734091702935 ~0.01999663755891316 "
    s .= "145:-0.109375:4070:4071 ~-0.05653549382967682 202:0.453125:4072:4073 ~0.025544357409883714 ~-0.035705604701059705 38:-0.515625:4075:4076 ~-0.001216968156258916 ~-0.05205645210053106 245:1.711111111111111:4078:4079 "
    s .= "~-0.05413060271332812 ~-0.0017142012119484994 251:1.796875:4081:4084 233:0.53125:4082:4083 ~-0.015764886433884875 ~-0.04821223224634663 252:0.32499999999999996:4085:4086 ~-0.057860696899296474 ~0.03927614881163699 "
    s .= "251:1.390625:4088:4089 ~-0.04646516418303028 ~0.01965181540859951 190:-0.3125:4091:4092 ~-0.03241261625708896 74:-0.109375:4093:4122 257:0.6666666666666666:4094:4115 49:0.484375:4095:4114 166:0.515625:4096:4111 "
    s .= "88:0.515625:4097:4110 92:-0.984375:4098:4101 238:0.46875:4099:4100 ~0.06109154088691026 ~-0.04293909587353203 133:1.625:4102:4107 254:1.046875:4103:4104 ~0.024109361130884407 41:-0.4375:4105:4106 ~0.010315158408228192 "
    s .= "~-0.0556894365387107 235:0.125:4108:4109 ~-0.05691104847655653 ~0.022845375657363054 ~0.036602070653953926 145:-0.109375:4112:4113 ~-0.05079696380452151 ~0.008354286081425365 ~-0.02911063271872863 40:0.234375:4116:4121 "
    s .= "212:-0.25:4117:4120 244:1.055:4118:4119 ~-0.03648453996025412 ~0.02552441282322923 ~-0.06961731809220066 ~-0.05448904936485514 255:0.265625:4123:4136 256:0.9545454545454546:4124:4135 246:0.015625:4125:4130 "
    s .= "225:0.0078125:4126:4129 244:1.405:4127:4128 ~-0.035081615138211994 ~0.031053057618378385 ~-0.0416533965235715 203:0.65625:4131:4134 243:2.25:4132:4133 ~0.02099809618157375 ~-0.05764334210167034 ~-0.051060391850788034 "
    s .= "~-0.04391784885853363 ~-0.035686299278637666 248:1.125:4138:4183 163:-0.3125:4139:4140 ~-0.034760446284912434 191:0.578125:4141:4182 257:0.6666666666666666:4142:4177 190:-0.0625:4143:4156 60:0.5390625:4144:4155 "
    s .= "62:-0.96875:4145:4146 ~0.03375446798703323 253:0:4147:4154 31:0.34375:4148:4153 199:-0.1875:4149:4150 ~-0.038878277656932664 85:-0.21875:4151:4152 ~0.07555843174398916 ~0.004000010592923122 ~-0.048330908405631055 "
    s .= "~-0.04159230810511059 ~0.040449203856721884 253:-0.05:4157:4164 252:0.125:4158:4163 164:-0.4375:4159:4160 ~0.03721658225885643 57:0.2578125:4161:4162 ~-0.038884506688173934 ~0.032227715558443726 ~0.038945491434765826 "
    s .= "254:1.359375:4165:4174 242:0.25:4166:4167 ~-0.03905064653664302 130:2.109375:4168:4171 220:-0.1875:4169:4170 ~-0.020708657848889343 ~0.019886237655777177 215:-0.453125:4172:4173 ~0.02653547435040477 "
    s .= "~-0.08130650729724138 35:-0.609375:4175:4176 ~0.005161303054006858 ~-0.057318776224455165 133:0.765625:4178:4179 ~-0.04523802167031327 215:-0.234375:4180:4181 ~0.016937104948008968 ~-0.05923907966127462 "
    s .= "~-0.038018265226367726 ~-0.03376470620305207 251:0.984375:4185:4214 249:1.8333333333333335:4186:4213 131:0.53125:4187:4212 43:0.28125:4188:4209 243:1.45:4189:4204 88:0.84375:4190:4201 133:0.234375:4191:4194 "
    s .= "169:0.09375:4192:4193 ~0.060527233497697945 ~-0.012858971906808772 254:1.265625:4195:4200 100:-0.15625:4196:4197 ~0.028612467179162188 133:2.09375:4198:4199 ~-0.0023456413186864903 ~-0.06589840915861031 "
    s .= "~-0.03859642918467992 124:0.875:4202:4203 ~0.036034406039750964 ~-0.025367999720203135 58:0.59375:4205:4206 ~-0.05521600959484085 37:-0.203125:4207:4208 ~-0.06627768385578184 ~0.03521014086610552 180:0.34375:4210:4211 "
    s .= "~-0.0338167382433032 ~0.03202756438730395 ~-0.04097894754121337 ~-0.04817123325157066 241:0.46:4215:4224 149:0.109375:4216:4223 127:1.328125:4217:4222 157:-0.109375:4218:4219 ~-0.06159649533357048 184:-0.28125:4220:4221 "
    s .= "~-0.06494649450414137 ~0.022781119304536347 ~-0.06295932553656573 ~-0.05063194369149557 243:1.95:4225:4230 245:1.1129032258064515:4226:4227 ~-0.058095245985466906 54:0.0390625:4228:4229 ~0.01246747067016473 "
    s .= "~0.043749634809314764 ~-0.01834615447851821 248:1.125:4232:4277 217:-0.140625:4233:4240 55:-0.375:4234:4235 ~-0.05136984917720497 58:1.015625:4236:4237 ~-0.01645486001499877 16:0.53125:4238:4239 ~0.05534710767490411 "
    s .= "~-0.049543461905829804 88:1.1875:4241:4274 31:0.15625:4242:4261 209:0.578125:4243:4260 257:0.6666666666666666:4244:4259 133:2.4375:4245:4258 205:0.59375:4246:4255 255:0.265625:4247:4250 255:0.140625:4248:4249 "
    s .= "~0.008116806043379374 ~0.036951781417596676 119:-0.46875:4251:4252 ~0.024886394264454888 244:1.325:4253:4254 ~-0.04887134220353424 ~0.004466278672944438 37:-0.203125:4256:4257 ~-0.029978854470411456 ~0.05265336258338971 "
    s .= "~-0.08447201769474727 ~-0.021984433017009284 ~-0.04188193754744423 251:0.453125:4262:4263 ~-0.03879126274984916 166:-0.0625:4264:4267 179:0.3125:4265:4266 ~-0.058206736385667306 ~0.016347461945967225 "
    s .= "97:-0.203125:4268:4269 ~-0.08167567831868645 232:0.4375:4270:4273 236:0.546875:4271:4272 ~0.02645005965798687 ~-0.06271496443859524 ~-0.040956741971096236 196:-0.078125:4275:4276 ~-0.016616764613232634 "
    s .= "~0.03528490253116422 ~-0.03271148237726217 251:0.765625:4279:4302 208:-0.25:4280:4281 ~-0.044698777176453104 31:0.046875:4282:4295 128:0.359375:4283:4294 166:0.484375:4284:4293 205:0.578125:4285:4290 88:0.625:4286:4287 "
    s .= "~-0.0008877230124302764 124:0.46875:4288:4289 ~0.04023477768343471 ~-0.02539013329574477 211:-0.203125:4291:4292 ~-0.0439197982622187 ~0.05071613727326727 ~-0.025153813413139044 ~-0.0325361351858107 "
    s .= "245:1.768421052631579:4296:4299 255:-0.140625:4297:4298 ~0.19485148771288788 ~-0.04048753365361491 251:0.421875:4300:4301 ~-0.02536999316396002 ~0.011670971975239358 241:0.46:4303:4314 184:0.046875:4304:4311 "
    s .= "204:0.21875:4305:4308 199:0.015625:4306:4307 ~-0.04456374558974632 ~0.011645416199222276 82:1.1875:4309:4310 ~-0.052785991434805904 ~-0.20619580970410714 218:0:4312:4313 ~0.020165254732866095 ~-0.02065542345677544 "
    s .= "243:1.45:4315:4320 249:0.8333333333333333:4316:4317 ~0.03617992682479241 57:0.2734375:4318:4319 ~-0.026605037224471058 ~0.04009672876097355 244:0.98:4321:4322 ~-0.05236926257572771 253:0.03703703703703809:4323:4324 "
    s .= "~0.02008717315985488 ~-0.0749888598077855 50:-0.109375:4326:4347 144:0.140625:4327:4338 97:0.65625:4328:4337 85:0.96875:4329:4334 254:0.984375:4330:4333 98:-1:4331:4332 ~0.04455443483716098 ~-0.0019282880078270127 "
    s .= "~-0.020214926390003676 142:0.78125:4335:4336 ~0.026023937066406162 ~-0.028175006927734364 ~-0.0379508542159851 196:-0.046875:4339:4340 ~-0.007279341633196499 35:0.125:4341:4346 246:0.015625:4342:4345 "
    s .= "1:0.578125:4343:4344 ~0.024330771333483023 ~-0.0737230567867904 ~0.05060460798084211 ~-0.04760885567649076 249:0.5:4348:4365 255:0.265625:4349:4364 193:0.265625:4350:4363 244:0.805:4351:4352 ~-0.03738674759459883 "
    s .= "246:0.140625:4353:4356 150:0.0078125:4354:4355 ~0.028244478127501218 ~-0.031089727917916955 212:0.65625:4357:4362 242:0.55:4358:4361 184:-0.015625:4359:4360 ~-0.07346896917695658 ~0.021037892522096355 "
    s .= "~0.04416088675745771 ~-0.04850026297669622 ~-0.029577480837945924 ~-0.02830079918083367 168:0.078125:4366:4367 ~-0.049109594914172244 50:0.234375:4368:4371 254:1.046875:4369:4370 ~0.02331179272963589 "
    s .= "~-0.06677355418946321 ~-0.038467804256266745 248:1.125:4373:4418 203:0.609375:4374:4417 144:0.1875:4375:4412 175:0.234375:4376:4401 163:-0.28125:4377:4378 ~-0.0446792372251503 85:0.609375:4379:4398 "
    s .= "133:0.390625:4380:4385 139:0.5:4381:4384 135:-0.3828125:4382:4383 ~0.08300488149698461 ~-0.007583899645201924 ~0.06391391467971834 178:0.46875:4386:4397 103:0.546875:4387:4396 190:0.625:4388:4395 46:0.640625:4389:4394 "
    s .= "16:0.359375:4390:4391 ~-0.042517306486656636 43:0.25:4392:4393 ~0.07099803024719553 ~-0.045813365293203547 ~0.06970367210671352 ~0.05886867310573121 ~0.019360167705309076 ~0.0280821578553615 175:-0.40625:4399:4400 "
    s .= "~-0.03613361099534448 ~0.02558559998859768 50:-0.328125:4402:4409 245:1.5875:4403:4404 ~-0.04367791882072607 193:-0.078125:4405:4406 ~-0.03780308462849678 1:0.265625:4407:4408 ~0.02760986622842311 ~-0.02608073564487401 "
    s .= "110:0.125:4410:4411 ~-0.041365776506748886 ~-0.004650075422872103 41:0.21875:4413:4416 254:1.328125:4414:4415 ~0.029600273061547673 ~-0.022252897113726813 ~-0.010599954378111879 ~-0.03979218014590371 "
    s .= "~-0.03143921956700831 47:0.234375:4420:4457 144:0.078125:4421:4444 249:0.16666666666666666:4422:4429 189:-0.203125:4423:4428 43:0.28125:4424:4427 238:1.015625:4425:4426 ~0.033233954608722416 ~-0.03965102687478467 "
    s .= "~-0.03177978794514313 ~-0.0021174387341837933 50:-0.65625:4430:4437 51:-0.4140625:4431:4432 ~-0.022782728681026737 167:-0.34375:4433:4434 ~0.03381125777787163 255:0.546875:4435:4436 ~-0.050229459204863394 "
    s .= "~0.04003703704779448 198:0.25:4438:4443 243:2.95:4439:4440 ~-0.032078768108527264 245:1.4105263157894736:4441:4442 ~0.3380061294290473 ~0.0031651901944521155 ~0.017371860795220365 188:0.515625:4445:4456 "
    s .= "246:0.140625:4446:4453 253:-0.06265812776723578:4447:4450 170:0.09375:4448:4449 ~0.03947203180978435 ~-0.06547470286727265 85:1.421875:4451:4452 ~-0.01780789048719165 ~0.03024533977347751 254:1.265625:4454:4455 "
    s .= "~0.04172862842855053 ~-0.025001281128575876 ~-0.02435886292908224 244:1.35:4458:4461 251:1.796875:4459:4460 ~-0.03817425800932624 ~0.02728906498330222 235:0.046875:4462:4465 245:1.4025974025974026:4463:4464 "
    s .= "~-0.18119226475930839 ~-0.011491461245784622 ~0.030324965874939543 163:-0.3125:4467:4468 ~-0.03403479491042441 251:1.140625:4469:4500 131:0.53125:4470:4499 121:0.359375:4471:4498 199:-0.25:4472:4475 "
    s .= "245:1.4444444444444444:4473:4474 ~0.07998864398830949 ~-0.04667121168648194 85:1.265625:4476:4495 255:0.234375:4477:4490 255:0.140625:4478:4481 252:0.125:4479:4480 ~0.01149106319529147 ~-0.0195850260605969 "
    s .= "122:0.09375:4482:4485 257:0.43478260869565216:4483:4484 ~0.0507159057909539 ~-0.032570417533275595 11:0.453125:4486:4489 88:0.171875:4487:4488 ~-0.04416303742645478 ~0.027212454328030312 ~0.1181332848366235 "
    s .= "122:-0.515625:4491:4494 254:0.671875:4492:4493 ~0.06095872210991035 ~-0.0047256133789859 ~-0.03244449148112565 190:1.296875:4496:4497 ~0.032400058790779854 ~-0.05220239956921392 ~-0.027499927583126606 "
    s .= "~-0.03703790978432196 241:0.48:4501:4510 149:0.109375:4502:4509 232:0.734375:4503:4508 168:0.046875:4504:4507 190:0.046875:4505:4506 ~-0.06695571245048738 ~0.0004888083200555153 ~0.02721377954049564 ~0.05991492313678699 "
    s .= "~-0.05004870669242259 227:0.71875:4511:4512 ~0.03320585451446216 ~-0.06243254398593134 124:-0.484375:4514:4515 ~-0.041598608970950295 122:0.09375:4516:4543 120:0.234375:4517:4538 124:0.25:4518:4533 "
    s .= "223:-0.03125:4519:4526 249:0.5:4520:4525 130:1.84375:4521:4524 244:2.135:4522:4523 ~-0.0031999779402106542 ~0.043478158640135156 ~-0.05462438959504143 ~-0.03262686955799165 245:3.8297872340425534:4527:4532 "
    s .= "154:0.65625:4528:4531 94:-0.046875:4529:4530 ~-0.01861339473064731 ~0.01916425796913974 ~0.03464621916916232 ~-0.09935190450247944 251:0.453125:4534:4535 ~-0.03265228785902451 223:0.5625:4536:4537 ~0.004595132898478563 "
    s .= "~-0.05005420402439947 246:-0.015625:4539:4542 85:1.0625:4540:4541 ~-0.016864075123442082 ~0.04120876568120899 ~0.038056937836557204 255:0.265625:4544:4559 236:0.609375:4545:4558 246:0.171875:4546:4549 "
    s .= "68:0.40625:4547:4548 ~-0.04270550619888455 ~0.030463132095306496 242:0.55:4550:4553 128:0.28125:4551:4552 ~0.018966840507978453 ~-0.038510022785762016 254:0.765625:4554:4557 244:0.905:4555:4556 ~-0.03915484715829329 "
    s .= "~0.02444092835290086 ~0.061411056944422886 ~-0.04684385231257092 ~-0.039184716810405355 251:0.765625:4561:4584 208:-0.25:4562:4563 ~-0.043360711694880094 31:0.046875:4564:4575 166:0.484375:4565:4574 "
    s .= "152:0.328125:4566:4573 205:0.578125:4567:4572 243:1.45:4568:4571 88:0.625:4569:4570 ~0.0027938479913621147 ~0.03726401314589082 ~-0.039655915994734836 ~0.04193506638683593 ~-0.027111222733659585 ~-0.0252733444179469 "
    s .= "245:1.768421052631579:4576:4577 ~-0.03670036647562969 94:-0.046875:4578:4579 ~-0.04524289501279921 118:0.359375:4580:4583 251:0.421875:4581:4582 ~-0.008825226076502624 ~0.03167882214546054 ~-0.03869140659328775 "
    s .= "241:0.46:4585:4594 184:0.046875:4586:4591 204:0.21875:4587:4590 117:-0.109375:4588:4589 ~-0.054014185297139465 ~0.006645818479656525 ~-0.06817174445925643 74:0.21875:4592:4593 ~0.01574480207121551 ~-0.034595491634252004 "
    s .= "243:1.45:4595:4600 214:0.5625:4596:4599 217:0.65625:4597:4598 ~0.03415951366835459 ~-0.033355456376075315 ~-0.032417560921349446 244:0.98:4601:4602 ~-0.050464923420070674 28:0.421875:4603:4606 186:-0.328125:4604:4605 "
    s .= "~-0.05924659785086307 ~0.027352958658702964 ~-0.08593906078958427 249:1.8333333333333335:4608:4651 203:0.578125:4609:4650 257:0.7741935483870968:4610:4643 254:1.296875:4611:4640 122:0.09375:4612:4629 "
    s .= "144:0.046875:4613:4624 49:0.53125:4614:4623 188:-0.5:4615:4616 ~0.02431172417382818 255:0.046875:4617:4620 245:1.5277777777777777:4618:4619 ~0.061391468640121065 ~-0.03825951686104708 255:0.234375:4621:4622 "
    s .= "~0.02817114254427194 ~-0.008411958485824043 ~-0.030701062077803366 187:-0.09375:4625:4628 251:0.953125:4626:4627 ~-0.036524095588201126 ~0.025409959235120568 ~0.029545311961220507 246:0.203125:4630:4631 "
    s .= "~-0.026361908225711907 250:1.1171875:4632:4635 161:0.21875:4633:4634 ~0.022160790067698978 ~-0.03366045509075569 242:0.55:4636:4637 ~-0.017769441509444643 245:1.1578947368421053:4638:4639 ~-0.038853471960116744 "
    s .= "~0.04367573330073259 50:-0.6875:4641:4642 ~0.01235786857163405 ~-0.04621649610458102 244:1.145:4644:4645 ~-0.046454534156986596 215:-0.234375:4646:4649 115:0.671875:4647:4648 ~0.03844868603613827 ~-0.023618876087760143 "
    s .= "~-0.07552863182394248 ~-0.0347199148078152 171:0.1875:4652:4653 ~-0.04676610618486943 ~0.014122246425282252 248:1.125:4655:4700 190:-0.140625:4656:4663 244:1.585:4657:4662 127:0.09375:4658:4661 106:0.5:4659:4660 "
    s .= "~-0.036737792758983166 ~0.022029153643797723 ~-0.03968819716311455 ~0.014190212415168794 191:0.578125:4664:4699 257:0.43478260869565216:4665:4690 245:3.8297872340425534:4666:4689 253:-0.042911505141282065:4667:4676 "
    s .= "252:0.175:4668:4673 164:-0.46875:4669:4670 ~0.035645255361684246 60:0.2421875:4671:4672 ~-0.028125963848908704 ~0.0350281403291317 243:2.25:4674:4675 ~0.040925513048095365 ~-0.041267543196576315 220:-0.171875:4677:4678 "
    s .= "~-0.02292750558214644 254:1.296875:4679:4686 248:0.125:4680:4685 251:0.984375:4681:4684 192:-0.078125:4682:4683 ~0.027551182418214512 ~-0.03472196032959423 ~0.029950544337422988 ~0.021300538879475778 "
    s .= "177:-0.09375:4687:4688 ~0.013720174034239136 ~-0.04983309880362971 ~-0.07985660069914137 236:-0.25:4691:4698 40:0.234375:4692:4697 14:-0.9375:4693:4694 ~0.050533941493726246 244:1.06:4695:4696 ~-0.055436370640811944 "
    s .= "~0.014774202192475378 ~-0.04419606353148467 ~-0.05938905926425347 ~-0.03829704664981315 ~-0.029530817461576233 124:-0.484375:4702:4703 ~-0.0399676773053307 74:-0.140625:4704:4717 257:0.6666666666666666:4705:4712 "
    s .= "253:-0.055855855855857804:4706:4707 ~0.028524444601332435 195:-0.328125:4708:4709 ~-0.01883951458109545 191:-0.671875:4710:4711 ~0.03214573562124095 ~0.003598546762697755 239:-0.265625:4713:4716 244:1.045:4714:4715 "
    s .= "~-0.038627687357614245 ~0.014145058644442515 ~-0.06389868095308503 254:1.046875:4718:4747 224:0.65625:4719:4746 246:0.015625:4720:4727 244:1.385:4721:4722 ~-0.03945403549222093 189:-0.15625:4723:4724 "
    s .= "~0.030556253574673266 63:-0.1875:4725:4726 ~0.061517819729711744 ~-0.033247388684171424 131:-0.046875:4728:4729 ~0.05332604741914923 251:1.484375:4730:4745 255:0.265625:4731:4744 255:0.140625:4732:4739 "
    s .= "131:0.640625:4733:4738 11:0.78125:4734:4737 112:0.609375:4735:4736 ~-0.02621929392604791 ~0.017651894325058187 ~0.10463341793900743 ~-0.05067299808840006 245:1.9107142857142858:4740:4741 ~0.047858425217894546 "
    s .= "242:0.75:4742:4743 ~-0.03215219835992463 ~0.03782941661246506 ~-0.03872342883223673 ~0.028500560846665975 ~-0.0502361827901215 ~-0.05344232659586062 163:-0.3125:4749:4752 123:0.421875:4750:4751 ~-0.043454602173151675 "
    s .= "~0.011021543517264844 167:0.5625:4753:4794 121:0.359375:4754:4791 85:0.953125:4755:4784 113:0.78125:4756:4783 139:0.5:4757:4770 103:0.703125:4758:4769 156:0.6953125:4759:4768 190:-0.078125:4760:4763 76:0.65625:4761:4762 "
    s .= "~-0.05078729011232763 ~0.07243918244924406 144:0.0625:4764:4767 70:0.546875:4765:4766 ~-0.027696331613736372 ~0.04594731388393413 ~0.00694495647676679 ~0.06364054404208255 ~0.01768895304351391 110:-0.984375:4771:4772 "
    s .= "~-0.028076555482189226 133:1.90625:4773:4782 245:1.4025974025974026:4774:4775 ~-0.05733292821493448 22:0.234375:4776:4781 16:0.296875:4777:4780 4:0.21875:4778:4779 ~0.03059595562199806 ~-0.0372801265777955 "
    s .= "~0.07980429941599874 ~-0.007857137031594907 ~-0.04471637507646371 ~0.0436030399239491 232:-0.0625:4785:4788 249:0.5:4786:4787 ~0.007454760166233048 ~-0.04178403774669465 190:0.734375:4789:4790 ~0.0338340316568933 "
    s .= "~-0.01593569827013502 251:1.046875:4792:4793 ~-0.027657575314788147 ~0.0103266405239375 ~-0.03177761973132578 47:0.234375:4796:4835 192:0.28125:4797:4832 249:0.5:4798:4819 223:0.34375:4799:4814 "
    s .= "245:3.6333333333333333:4800:4813 170:0.109375:4801:4810 229:0.546875:4802:4809 255:0.234375:4803:4804 ~0.02270494643399845 189:-0.203125:4805:4806 ~0.020508674095700393 252:0.375:4807:4808 ~-0.029633822034016433 "
    s .= "~0.01317926451082299 ~0.046137913466040875 246:0.140625:4811:4812 ~-0.043062177676431945 ~0.0034579811675752104 ~-0.06966035466169673 244:1.8:4815:4818 98:-0.828125:4816:4817 ~0.006875336376820688 ~-0.04698885228602092 "
    s .= "~0.028062616338442942 96:0.0859375:4820:4827 222:0.328125:4821:4824 29:-0.640625:4822:4823 ~-0.007701459166649139 ~-0.04473105409111885 243:1.45:4825:4826 ~0.054502950232699965 ~-0.07414237582028806 50:0.03125:4828:4831 "
    s .= "196:-0.015625:4829:4830 ~-0.021755288788212878 ~0.037185633160376444 ~-0.0321439654373803 57:0.3203125:4833:4834 ~0.007334568485388264 ~0.03675356333507256 244:1.35:4836:4839 251:1.796875:4837:4838 ~-0.03600597305466403 "
    s .= "~0.02384096477752675 235:0.046875:4840:4841 ~-0.018455906423990583 ~0.02923498305370923 190:-0.3125:4843:4844 ~-0.026543720475169254 166:0.390625:4845:4882 85:0.78125:4846:4869 139:0.5:4847:4862 251:1.640625:4848:4859 "
    s .= "76:0.96875:4849:4858 254:1.046875:4850:4857 4:-0.015625:4851:4854 191:-0.09375:4852:4853 ~0.01962344389033313 ~-0.01878605479627084 145:1.78125:4855:4856 ~-0.02561024836921611 ~0.19752370703297756 ~-0.04297094622964795 "
    s .= "~0.033506721961867124 241:0.14:4860:4861 ~-0.06369534405943719 ~0.035154939805386844 218:-0.09375:4863:4866 4:0.28125:4864:4865 ~0.03367843314794162 ~-0.021280695627245116 246:-0.640625:4867:4868 ~-0.04989172529704463 "
    s .= "~0.007512720411349615 208:-0.25:4870:4873 101:-0.734375:4871:4872 ~0.03274305160605697 ~-0.059438768056262775 253:-0.006628787878785403:4874:4875 ~0.03460331728258891 191:-0.03125:4876:4879 243:1.15:4877:4878 "
    s .= "~0.028138195969019786 ~-0.0489353820993097 196:1.4375:4880:4881 ~-0.03482579276134388 ~0.08609095684204326 142:0.203125:4883:4886 238:0.21875:4884:4885 ~0.030489582387856613 ~-0.033396795878852345 136:1.28125:4887:4888 "
    s .= "~-0.03332457535403066 ~0.003144353588461489 53:-0.765625:4890:4895 52:0.34375:4891:4894 215:-0.515625:4892:4893 ~0.03666981511957594 ~-0.00451887792432175 ~-0.01778430051231921 255:0.328125:4896:4929 "
    s .= "246:0.015625:4897:4916 209:-0.171875:4898:4915 244:1.355:4899:4904 245:1.7403846153846154:4900:4901 ~-0.048264386621704375 132:-0.1171875:4902:4903 ~-0.02421534147453301 ~0.026207791956828177 1:-0.09375:4905:4906 "
    s .= "~0.03532485919450234 157:0.515625:4907:4910 85:0.53125:4908:4909 ~-0.06720530357605864 ~0.025617715518588997 184:1.609375:4911:4914 94:0.8125:4912:4913 ~0.031935046230978106 ~-0.10582882488134704 ~-0.06837083016274331 "
    s .= "~-0.030490724623685433 188:0.5:4917:4928 53:0.0625:4918:4919 ~0.0301037435734616 242:0.55:4920:4923 244:1.86:4921:4922 ~-0.040890089468360855 ~0.03061928322924819 243:1.45:4924:4927 130:0.171875:4925:4926 "
    s .= "~0.07186058762961958 ~0.007993873777824099 ~-0.021165399305090225 ~-0.020447180901673204 247:0.234375:4930:4935 244:1.055:4931:4932 ~-0.04330079211593225 223:-0.171875:4933:4934 ~-0.043635150667174466 "
    s .= "~0.004838598508726224 ~-0.06062379237385873 124:-0.6875:4937:4938 ~-0.054230367931503834 170:0.234375:4939:4970 120:0.234375:4940:4965 245:3.8297872340425534:4941:4964 124:0.25:4942:4957 187:-0.3125:4943:4944 "
    s .= "~-0.03981332371269687 109:0.453125:4945:4952 139:0.421875:4946:4949 127:0.375:4947:4948 ~-0.033166302472831206 ~0.018905312555787267 76:-0.0625:4950:4951 ~-0.03651285748453697 ~0.03392639958318947 247:0.203125:4953:4956 "
    s .= "2:0.078125:4954:4955 ~0.024126521082999612 ~-0.011271834026925071 ~-0.016073015194036668 244:1.015:4958:4961 151:0.078125:4959:4960 ~0.024399673573544986 ~-0.0451181066654693 202:0.3125:4962:4963 ~0.008776226041772629 "
    s .= "~-0.021425035728422314 ~-0.07287017509010568 72:1.078125:4966:4969 123:0.03125:4967:4968 ~-0.0017773979354724892 ~0.029350353869671886 ~-0.07689159405460888 257:0.3333333333333333:4971:4980 136:1.03125:4972:4977 "
    s .= "89:0.78125:4973:4974 ~-0.02943092001586044 71:0.578125:4975:4976 ~0.046105029679716164 ~-0.03986365302894705 245:1.9611650485436893:4978:4979 ~0.04578772321512982 ~-0.008277210612540267 47:0.40625:4981:4982 "
    s .= "~-0.12171588006133466 ~0.042125002752610205 248:1.125:4984:5029 203:0.65625:4985:5028 254:1.296875:4986:5025 141:0.0703125:4987:5012 249:0.5:4988:5005 66:0.296875:4989:5004 217:0.3125:4990:5001 94:-0.234375:4991:4992 "
    s .= "~-0.022226408503468256 238:1.59375:4993:5000 133:2.234375:4994:4999 240:-0.015625:4995:4996 ~0.02710661537961455 257:0.24193548387096775:4997:4998 ~0.016384033606314442 ~-0.02871639134582238 ~-0.03825702216685089 "
    s .= "~-0.077000126454785 50:-1.015625:5002:5003 ~0.03125344262253364 ~-0.03900440629730099 ~-0.04988031969063268 198:0.25:5006:5011 17:-0.234375:5007:5010 96:-0.0234375:5008:5009 ~-0.029404025233010056 ~0.023015109212157856 "
    s .= "~-0.0489542872287098 ~0.02872974723608871 217:-0.0625:5013:5016 251:1.140625:5014:5015 ~-0.019084388840389127 ~0.020502733949755547 23:0.484375:5017:5024 242:0.25:5018:5019 ~-0.048014538249455264 88:0.109375:5020:5023 "
    s .= "127:-0.203125:5021:5022 ~0.07906090215648486 ~0.005283538270215234 ~0.03530439910223876 ~-0.020641251758842363 50:-0.6875:5026:5027 ~0.005219061906996957 ~-0.04393718998596305 ~-0.04315672786286315 "
    s .= "~-0.027347597961717707 251:0.421875:5031:5050 94:0.328125:5032:5049 241:0.32:5033:5046 160:0.703125:5034:5045 205:0.625:5035:5042 106:0.609375:5036:5041 49:-0.40625:5037:5040 174:0.515625:5038:5039 "
    s .= "~0.0030059925239625143 ~0.16557532045404044 ~-0.033414193775651746 ~0.02016733992946728 208:0.546875:5043:5044 ~0.0690011833035205 ~-0.028948316794622328 ~0.03388087234680801 253:-0.09786043152478317:5047:5048 "
    s .= "~0.016274985099996205 ~-0.0342938289996349 ~-0.04144270063552785 203:0.609375:5051:5076 254:1.046875:5052:5071 144:0.046875:5053:5066 151:0.21875:5054:5065 152:-0.421875:5055:5056 ~0.03674761898545255 "
    s .= "242:0.8500000000000001:5057:5064 64:0.234375:5058:5063 82:0.6875:5059:5062 97:0.140625:5060:5061 ~-0.05552190440889609 ~0.015670410546947816 ~0.011118539050838943 ~0.02874043113691431 ~0.035945845730155405 "
    s .= "~-0.013537299961684053 130:1.875:5067:5070 41:0.359375:5068:5069 ~0.028450314048445224 ~-0.002703606283614942 ~-0.02986447520055619 26:-0.5:5072:5075 169:-0.09375:5073:5074 ~-0.038447497754884714 ~0.019065352248445744 "
    s .= "~-0.04381658706200839 ~-0.03458491538926789 124:-0.6875:5078:5079 ~-0.05378994158182546 251:0.296875:5080:5095 241:0.32:5081:5094 7:0:5082:5093 94:0.28125:5083:5092 109:0.171875:5084:5089 151:0.578125:5085:5086 "
    s .= "~-0.04736848802984246 121:0.671875:5087:5088 ~0.01937544232533759 ~0.3240469409592157 214:-0.046875:5090:5091 ~-0.01542300373839532 ~0.05149181625550569 ~-0.04433182212670836 ~-0.022926448304299532 ~-0.03663855544423786 "
    s .= "88:0.796875:5096:5115 79:0.78125:5097:5114 98:-0.515625:5098:5101 1:0.328125:5099:5100 ~0.016481493714219725 ~-0.029588972178550832 255:0.234375:5102:5111 255:0.109375:5103:5108 113:0.984375:5104:5107 "
    s .= "184:0.9375:5105:5106 ~-0.026049216092144407 ~0.02119923561262993 ~0.052270984278725875 244:0.88:5109:5110 ~0.07372014789045504 ~0.013206250170680837 254:0.515625:5112:5113 ~0.006177007046232173 ~-0.04088533227386822 "
    s .= "~0.023983633048127406 193:-0.09375:5116:5119 175:0.75:5117:5118 ~0.0011898134747009366 ~-0.07002461911636797 142:0.484375:5120:5123 217:0.734375:5121:5122 ~0.03637154803826707 ~-0.03738386481273481 "
    s .= "~-0.007535003338907305 249:1.8333333333333335:5125:5168 146:0.125:5126:5159 257:0.9130434782608695:5127:5156 253:-0.05845467663649515:5128:5135 30:0.0546875:5129:5134 185:0.28125:5130:5133 248:0.125:5131:5132 "
    s .= "~0.03142749623068737 ~-0.0050283062653143085 ~-0.07064339476225451 ~0.034899282101505474 254:0.984375:5136:5151 248:0.125:5137:5138 ~-0.005077758027515716 121:0.5625:5139:5150 95:0.296875:5140:5149 "
    s .= "246:-0.046875:5141:5148 149:-0.390625:5142:5147 130:0.15625:5143:5144 ~0.07047120732939857 160:1.390625:5145:5146 ~0.007804460784256584 ~0.07915880839767474 ~-0.01811354003169664 ~0.03963948332787324 "
    s .= "~-0.01738735140350865 ~-0.02666274669227739 32:-0.359375:5152:5153 ~-0.0005704059752022808 255:0.203125:5154:5155 ~0.0111646946758601 ~-0.05654443694910567 254:0.015625:5157:5158 ~0.008220281851234022 "
    s .= "~-0.045072001947469506 246:0.171875:5160:5163 68:0.375:5161:5162 ~-0.04614798078854569 ~0.021637552982717384 236:0.59375:5164:5167 255:0.265625:5165:5166 ~0.009238864783440732 ~-0.031724498453289104 "
    s .= "~-0.044931853656899244 251:1.328125:5169:5170 ~-0.044016923943824095 ~0.02108981392728224 166:-0.328125:5172:5173 ~-0.026255115500274564 163:-0.34375:5174:5175 ~-0.04846444821762842 236:0.59375:5176:5217 "
    s .= "251:1.671875:5177:5212 85:1.171875:5178:5207 95:0.453125:5179:5206 246:0.015625:5180:5195 203:-0.171875:5181:5194 238:0.46875:5182:5193 46:0.71875:5183:5190 100:0.921875:5184:5189 254:0.890625:5185:5188 "
    s .= "2:-0.84375:5186:5187 ~0.03611696923849595 ~-0.005597029734394775 ~-0.021657966074937533 ~0.036442607165648816 106:0.625:5191:5192 ~0.09982394645071345 ~-0.025415061467403462 ~-0.03781293523751582 ~-0.03392784856158258 "
    s .= "144:0.0625:5196:5201 11:0.421875:5197:5200 116:0.140625:5198:5199 ~0.004033191923521685 ~-0.036001152309565985 ~0.07821638958421333 245:2.2:5202:5205 243:1.45:5203:5204 ~0.03838425782438509 ~-0.035155240665198664 "
    s .= "~-0.006661319892374765 ~-0.03937200601584569 232:0.015625:5208:5211 181:1.578125:5209:5210 ~0.006555215757399674 ~-0.07128077382824254 ~0.030266864389168355 252:0.07500000000000001:5213:5216 46:0.375:5214:5215 "
    s .= "~-0.042850943069201286 ~0.057312135244554155 ~0.03726097211937995 ~-0.037168374927083005 124:-0.6875:5219:5220 ~-0.05327327833760098 146:0.265625:5221:5264 118:0.375:5222:5261 88:0.71875:5223:5254 205:0.578125:5224:5251 "
    s .= "58:0.609375:5225:5250 46:0.71875:5226:5247 103:0.71875:5227:5244 181:0.5:5228:5239 133:-0.234375:5229:5230 ~0.053216161785594976 67:0.015625:5231:5232 ~-0.03985471836144107 67:0.125:5233:5238 22:-0.03125:5234:5235 "
    s .= "~0.050052528835382984 190:0.09375:5236:5237 ~-0.03684994909314906 ~0.026250124926937225 ~-0.028649830398485607 244:1.32:5240:5243 251:0.828125:5241:5242 ~-0.046152143316816906 ~0.019877156287635575 ~0.034064160056707704 "
    s .= "232:0.1875:5245:5246 ~0.03148666607323725 ~-0.026211798497915467 145:-0.03125:5248:5249 ~-0.059979566628520824 ~0.07282157751310218 ~0.023856388984014047 4:0.25:5252:5253 ~0.03932384361140151 ~-0.03296406761831696 "
    s .= "196:-0.078125:5255:5256 ~-0.01582591312896294 145:0.171875:5257:5258 ~0.03871635976725564 75:0.1484375:5259:5260 ~-0.026910826905488495 ~0.039157460268837284 178:0.390625:5262:5263 ~0.0015811849048881718 "
    s .= "~-0.029533257813502845 ~-0.015764859003912092 248:1.125:5266:5311 243:2.05:5267:5308 245:3.8297872340425534:5268:5307 257:0.30434782608695654:5269:5298 217:-0.125:5270:5271 ~-0.011665509913325843 236:0.5625:5272:5297 "
    s .= "88:0.796875:5273:5294 79:0.78125:5274:5293 190:-0.140625:5275:5276 ~-0.031225284873227118 175:0.578125:5277:5292 76:-0.390625:5278:5279 ~0.054965995172412296 226:-0.265625:5280:5281 ~0.06272932008506509 "
    s .= "255:0.234375:5282:5287 255:0.140625:5283:5284 ~-0.0070754093191747365 244:1:5285:5286 ~0.068932798867797 ~0.00858618377766469 257:0.046511627906976744:5288:5291 26:-0.46875:5289:5290 ~0.0018124199446298344 "
    s .= "~-0.048177583420033206 ~0.03770899524237801 ~0.03769191476055727 ~0.034901133454697385 37:0.765625:5295:5296 ~0.031556947252997576 ~-0.0487999737156643 ~-0.03049045193588287 239:-0.265625:5299:5306 43:0.21875:5300:5305 "
    s .= "254:0.796875:5301:5304 53:-0.734375:5302:5303 ~0.05261543622849938 ~0.004396756466936048 ~-0.019618161116574762 ~-0.04173554380094697 ~-0.04260328581897724 ~-0.05930757828872757 154:-0.421875:5309:5310 "
    s .= "~0.057119297339978316 ~-0.04478690926100685 ~-0.025714731470922254 205:-0.296875:5313:5314 ~-0.024303191855855225 88:1.109375:5315:5352 202:0.234375:5316:5339 224:0.65625:5317:5338 255:0.234375:5318:5335 "
    s .= "254:0.734375:5319:5330 89:1.078125:5320:5329 106:0.921875:5321:5326 125:0.0625:5322:5325 25:-0.234375:5323:5324 ~0.04312323238763528 ~-0.007276160905764312 ~-0.028512303327323452 133:2.203125:5327:5328 "
    s .= "~0.0279743466464858 ~-0.07537537844421964 ~0.05695505923920261 133:0.90625:5331:5332 ~0.04513753761382814 186:-0.03125:5333:5334 ~0.04836688807662032 ~-0.019414460717871198 41:-0.40625:5336:5337 ~0.009872679829830084 "
    s .= "~-0.02660464831339836 ~-0.05703216086160395 244:1.49:5340:5347 100:0.15625:5341:5344 98:-1:5342:5343 ~0.05638770147376568 ~-0.01147036901500576 199:1.03125:5345:5346 ~-0.04307803688491957 ~0.04352812054622146 "
    s .= "223:-0.1875:5348:5349 ~-0.06447208984297387 64:0.546875:5350:5351 ~0.026141113041374228 ~-0.05147132165158633 127:1.078125:5353:5356 172:-0.171875:5354:5355 ~-0.02578699368174089 ~0.035770141718072385 "
    s .= "148:0.625:5357:5358 ~0.003782773069442642 ~-0.05365635197693948 124:-0.6875:5360:5361 ~-0.05262205234444594 251:1.140625:5362:5389 131:0.59375:5363:5388 255:0.234375:5364:5377 246:0.015625:5365:5370 "
    s .= "215:-0.234375:5366:5369 123:-0.484375:5367:5368 ~-0.04055984455340647 ~0.016340477768255736 ~-0.02301052416009482 163:-0.0625:5371:5372 ~-0.014875426232258765 188:0.328125:5373:5376 254:0.765625:5374:5375 "
    s .= "~0.0188703613924706 ~0.05079278752672613 ~-0.0024851862537049775 2:-0.34375:5378:5385 254:0.515625:5379:5382 122:-0.953125:5380:5381 ~0.08077690417918308 ~0.0015657339909660184 257:0.5555555555555556:5383:5384 "
    s .= "~0.0004031575004425381 ~-0.0465032861534603 254:0.859375:5386:5387 ~-0.01527461658248763 ~-0.052095780907456396 ~-0.03622345907254811 241:0.48:5390:5405 160:0.765625:5391:5402 214:0.671875:5392:5401 "
    s .= "77:0.140625:5393:5400 190:0.046875:5394:5397 247:0.515625:5395:5396 ~-0.06951272802594312 ~0.07658076776369688 169:0.328125:5398:5399 ~0.015085421311221793 ~-0.07415043641317302 ~-0.08077948291961105 "
    s .= "~0.04289135296252258 181:0.0625:5403:5404 ~-0.03871481205534236 ~0.04090009646935851 ~0.02536572880409524 249:1.8333333333333335:5407:5452 243:1.45:5408:5445 254:1.296875:5409:5442 257:0.30434782608695654:5410:5437 "
    s .= "167:0.5625:5411:5436 133:2.046875:5412:5433 241:0.48:5413:5428 184:0.046875:5414:5421 79:0.703125:5415:5420 139:0.125:5416:5417 ~-0.0360708041591749 85:-0.09375:5418:5419 ~0.05333441299979588 ~-0.01256327861155756 "
    s .= "~0.0520619046894632 8:0.8125:5422:5427 107:0.5625:5423:5426 174:-0.375:5424:5425 ~-0.03128339487790437 ~0.024676776412898064 ~-0.04117233578590357 ~0.1266726166922897 181:0.171875:5429:5430 ~0.045266910192192485 "
    s .= "34:0.359375:5431:5432 ~0.022851432295051925 ~-0.04191059693192309 152:-0.546875:5434:5435 ~0.03530016567305303 ~-0.04419442695501749 ~-0.02472543705004672 239:-0.265625:5438:5441 166:0.296875:5439:5440 "
    s .= "~0.017135256376224685 ~-0.019542882526874764 ~-0.04603825396889614 50:-0.6875:5443:5444 ~0.0048175738931138246 ~-0.04298908529965605 245:2.0595238095238093:5446:5447 ~-0.03814124055379726 1:-0.375:5448:5449 "
    s .= "~-0.0729559707947457 28:0.40625:5450:5451 ~0.028042359720284144 ~-0.06538537502566143 ~-0.030358705383561443 124:-0.6875:5454:5455 ~-0.052084497569556104 203:0.65625:5456:5499 251:1.671875:5457:5498 "
    s .= "253:-0.09764309764309784:5458:5463 252:0.125:5459:5462 70:0.0625:5460:5461 ~0.01209780646231394 ~-0.05155701139357515 ~0.030776201533839045 243:1.45:5464:5493 254:1.359375:5465:5492 248:1.125:5466:5491 "
    s .= "8:0.8125:5467:5490 245:3.514705882352941:5468:5489 257:0.30434782608695654:5469:5482 217:-0.125:5470:5473 152:-0.546875:5471:5472 ~0.03057202341054986 ~-0.02602668762210781 88:0.828125:5474:5481 139:0.390625:5475:5476 "
    s .= "~-0.005903598210637324 61:-0.21875:5477:5478 ~0.07059189887929977 245:1.9423076923076923:5479:5480 ~0.030875995140580953 ~-0.009700327289193076 ~0.03141517246357727 252:0.32499999999999996:5483:5486 "
    s .= "250:0.7265625:5484:5485 ~-0.06939851999397796 ~0.005451780763297433 245:1.927710843373494:5487:5488 ~-0.09112500756556735 ~-0.00459448584186244 ~-0.05381929303412937 ~0.06990717097872999 ~-0.027927867813063563 "
    s .= "~-0.027376342026550638 245:2.1315789473684212:5494:5497 255:-0.015625:5495:5496 ~0.23246971961233212 ~-0.054436688574361715 ~0.0049432212937295305 ~0.021182899793436957 ~-0.0382754680889427 53:-0.765625:5501:5510 "
    s .= "14:-0.234375:5502:5509 110:-0.265625:5503:5508 212:-0.421875:5504:5507 13:0.390625:5505:5506 ~0.02585358183936992 ~-0.02697656884549203 ~-0.0311072010760677 ~0.05244222101112578 ~-0.04579874177299306 "
    s .= "255:0.328125:5511:5542 133:2.046875:5512:5541 257:0.38461538461538464:5513:5536 227:0.640625:5514:5535 249:1.8333333333333335:5515:5534 243:1.45:5516:5529 252:0.32499999999999996:5517:5526 184:0.0625:5518:5525 "
    s .= "79:0.28125:5519:5524 205:0.125:5520:5523 244:1.22:5521:5522 ~-0.005463913528760823 ~-0.052780379284366796 ~0.0162403499982955 ~0.03538480290897519 ~0.020502110731205805 251:0.953125:5527:5528 ~0.012666983977587235 "
    s .= "~0.046509770354109276 245:2.064516129032258:5530:5533 222:-0.5625:5531:5532 ~0.1880372197331831 ~-0.037518213911389084 ~0.022454179973570312 ~-0.03148451289931268 ~-0.04078956416808771 7:-0.078125:5537:5540 "
    s .= "244:1.16:5538:5539 ~-0.04442108529366434 ~0.027458943995794356 ~-0.03588948574890041 ~-0.038796795347365305 247:0.234375:5543:5546 244:0.945:5544:5545 ~-0.048196052657607534 ~-0.003409870047987511 ~-0.05743242538734472 "
    s .= "163:-0.328125:5548:5549 ~-0.02783009653798174 163:0.34375:5550:5579 85:0.71875:5551:5576 205:0.59375:5552:5573 76:0.625:5553:5572 251:0.859375:5554:5561 109:0.3125:5555:5556 ~-0.03444038673235643 139:0.671875:5557:5560 "
    s .= "226:0.03125:5558:5559 ~-0.039591046543384745 ~0.0004947422940241064 ~0.031041054662655995 241:0.42:5562:5569 37:0.25:5563:5568 77:-0.5625:5564:5567 76:0.0625:5565:5566 ~0.03478768040578558 ~-0.0556109751256775 "
    s .= "~-0.04898892591397294 ~0.038175682816864356 34:0.390625:5570:5571 ~0.034396842693620235 ~-0.055413567616577786 ~0.0333192687757903 4:0.34375:5574:5575 ~0.04520444299967469 ~-0.054604549945489314 38:0:5577:5578 "
    s .= "~0.029497022114666593 ~-0.0007089672124340741 244:1.505:5580:5591 157:0.265625:5581:5586 187:0.265625:5582:5585 88:0.53125:5583:5584 ~0.05533610940244052 ~-0.027160536862920345 ~-0.022816387547772005 "
    s .= "251:0.984375:5587:5588 ~-0.03572285867422625 13:0.21875:5589:5590 ~0.012171059215322834 ~-0.06056523440339423 157:-0.078125:5592:5593 ~-0.043621116799062894 ~0.01787293273879846 47:0.234375:5595:5636 "
    s .= "254:0.984375:5596:5629 246:0.140625:5597:5618 227:-0.1875:5598:5613 151:0.171875:5599:5606 125:-0.609375:5600:5601 ~0.04267439895272744 68:-0.03125:5602:5605 252:0.07500000000000001:5603:5604 ~-0.020826598076414363 "
    s .= "~0.020237220334610312 ~0.05528568402430803 133:1.171875:5607:5610 192:-0.46875:5608:5609 ~-0.057519729555544255 ~-0.007104548870635524 223:-0.0625:5611:5612 ~-0.03119107356752821 ~0.027810227007349572 242:0.55:5614:5617 "
    s .= "249:0.16666666666666666:5615:5616 ~0.026136882718695784 ~-0.029586593064056206 ~-0.03423763297659835 245:1.1129032258064515:5619:5620 ~-0.056624419910483594 144:0.0625:5621:5626 241:0.14:5622:5623 ~-0.03860428026482107 "
    s .= "151:0.203125:5624:5625 ~0.03451700688761638 ~-0.01264892834807991 188:0.5:5627:5628 ~0.03831600584802907 ~-0.006208816473645503 53:-0.640625:5630:5633 257:0.5555555555555556:5631:5632 ~0.01407744185396457 "
    s .= "~-0.04246810158124614 255:0.234375:5634:5635 ~0.020857848571841725 ~-0.03290978805588519 244:1.35:5637:5638 ~-0.026700204233045817 235:0.046875:5639:5640 ~-0.01753264993257533 ~0.027005380796294956 124:-0.6875:5642:5643 "
    s .= "~-0.05149763742387739 146:0.125:5644:5677 253:-0.05845467663649515:5645:5652 6:0.125:5646:5649 248:0.125:5647:5648 ~0.027272901833524762 ~-0.016762866530239895 184:-0.1875:5650:5651 ~-0.04206016021169124 "
    s .= "~0.0380683308962833 254:0.984375:5653:5670 174:-0.484375:5654:5655 ~-0.027447780546037248 98:-0.96875:5656:5659 143:-0.578125:5657:5658 ~0.05714821338005595 ~-0.034250873527952794 130:2.078125:5660:5669 "
    s .= "246:-0.546875:5661:5664 236:-0.15625:5662:5663 ~0.00203057229577821 ~-0.04129658926907168 42:-0.0625:5665:5666 ~0.03955827037558305 90:0.7265625:5667:5668 ~0.002730969890604927 ~0.06802062186119222 ~-0.04300758039942807 "
    s .= "32:-0.359375:5671:5676 246:-0.421875:5672:5673 ~-0.017311992042333493 95:-0.0625:5674:5675 ~0.0380796597959731 ~-0.06629338874885574 ~-0.04035124847912055 248:0.875:5678:5687 246:0.171875:5679:5682 210:0.03125:5680:5681 "
    s .= "~-0.006116113578133184 ~-0.05718851368332331 136:0.796875:5683:5686 113:0.890625:5684:5685 ~-0.017443635657841995 ~0.03134501262727957 ~0.021679751515888142 ~-0.04305627006810426 187:-0.3125:5689:5690 "
    s .= "~-0.02462247218239433 245:3.459016393442623:5691:5734 236:0.59375:5692:5733 163:0.34375:5693:5714 109:0.15625:5694:5697 89:0.828125:5695:5696 ~-0.01768912986807872 ~0.06081682763879212 91:0.796875:5698:5713 "
    s .= "34:0.046875:5699:5704 205:0.359375:5700:5703 82:0.328125:5701:5702 ~-0.0009039747118004488 ~0.02698933367298996 ~0.04556918274604559 187:0.046875:5705:5708 178:-0.015625:5706:5707 ~0.016283136759050233 "
    s .= "~-0.039131033978727386 244:0.955:5709:5710 ~-0.029389395779440927 193:0:5711:5712 ~-0.017887269566585783 ~0.03245747807047369 ~0.03334663756657828 244:1.5:5715:5730 157:0.171875:5716:5719 187:0.265625:5717:5718 "
    s .= "~0.04718797733417633 ~-0.02527439274781776 207:-0.390625:5720:5721 ~-0.06049617188268346 157:0.84375:5722:5727 112:-0.28125:5723:5726 204:-0.203125:5724:5725 ~0.2914112486950917 ~0.030203511297624355 "
    s .= "~-0.03398057711487248 94:0.03125:5728:5729 ~-0.02537916008043528 ~0.027224968502132685 157:-0.078125:5731:5732 ~-0.04319631150230536 ~0.020957550830363113 ~-0.03574923896023015 ~-0.03801118748883431 "
    s .= "53:-0.765625:5736:5743 14:-0.234375:5737:5742 110:-0.265625:5738:5741 212:-0.421875:5739:5740 ~0.017964127757035642 ~-0.029850540499847863 ~0.05005554330489468 ~-0.04331188306298889 255:0.328125:5744:5773 "
    s .= "133:2.046875:5745:5772 257:0.4090909090909091:5746:5767 245:1.1129032258064515:5747:5748 ~-0.04602274752032792 249:1.8333333333333335:5749:5766 191:0.578125:5750:5765 113:0.78125:5751:5764 8:0.859375:5752:5763 "
    s .= "62:0.28125:5753:5758 256:0.01639344262295082:5754:5757 209:0.109375:5755:5756 ~0.015502825036098792 ~-0.007561231434826592 ~0.04148231030551728 103:0.875:5759:5762 119:-0.0625:5760:5761 ~0.0333102620866504 "
    s .= "~-0.03366684667336524 ~0.029558394451608697 ~0.0879435546323167 ~0.0456727835306201 ~-0.022889083028987563 ~-0.03055119118375363 151:0.25:5768:5771 4:-0.046875:5769:5770 ~0.023631818409348096 ~-0.034086538805743846 "
    s .= "~-0.04093492877168066 ~-0.036831835730489475 247:0.203125:5774:5781 244:0.945:5775:5776 ~-0.04669569076313068 257:0.6060606060606061:5777:5780 178:-0.109375:5778:5779 ~-0.03696705884924404 ~0.008224427007905367 "
    s .= "~-0.06126791818313518 ~-0.05342035460424258 124:-0.6875:5783:5784 ~-0.05082971540751479 74:-0.140625:5785:5802 246:-0.265625:5786:5795 191:-0.796875:5787:5790 118:0.328125:5788:5789 ~0.02325683046693783 "
    s .= "~-0.013528703366926837 244:0.955:5791:5792 ~-0.04002144853635545 136:2.046875:5793:5794 ~-0.00047229630727393913 ~-0.06475729622622656 191:0.09375:5796:5799 190:-0.046875:5797:5798 ~0.0038485742776369495 "
    s .= "~0.03593103099599144 63:-0.015625:5800:5801 ~0.03307411936594083 ~-0.021107500074632385 254:1.046875:5803:5828 249:1.1666666666666665:5804:5827 227:-0.640625:5805:5806 ~-0.03898471683286083 224:0.65625:5807:5826 "
    s .= "11:0.90625:5808:5823 113:0.75:5809:5820 31:0.09375:5810:5815 249:0.16666666666666666:5811:5812 ~0.017571209273838536 149:-0.09375:5813:5814 ~0.026903288511134188 ~-0.01801693119741029 184:0.171875:5816:5819 "
    s .= "228:0.21875:5817:5818 ~0.016389497553576993 ~-0.03985699027542411 ~-0.03588282730646441 251:0.890625:5821:5822 ~-0.025686841804466017 ~0.048900072580639636 89:0.6875:5824:5825 ~0.13169143525377439 ~-0.012843082308851492 "
    s .= "~-0.04383185906245814 ~-0.031262558661651715 ~-0.04657989670198186 205:-0.296875:5830:5833 251:0.765625:5831:5832 ~-0.044020338189403305 ~-0.003020531065769225 88:1.109375:5834:5869 202:0.234375:5835:5862 "
    s .= "106:0.59375:5836:5857 16:0.296875:5837:5854 205:0.6875:5838:5853 241:0.52:5839:5850 217:0.46875:5840:5849 43:0.375:5841:5848 190:0.125:5842:5845 79:0.484375:5843:5844 ~-0.051112018064277565 ~0.009316549219557109 "
    s .= "58:0.15625:5846:5847 ~0.008639596463620674 ~-0.05950614111106203 ~0.02960395711842974 ~0.03978960570612158 251:0.984375:5851:5852 ~-0.01565559624038956 ~0.03144805134787169 ~0.03693770591234747 155:0.109375:5855:5856 "
    s .= "~0.0383148862414284 ~-0.016741674623544114 130:2.15625:5858:5861 118:0.296875:5859:5860 ~0.021553455533512053 ~-0.008748967735385093 ~-0.06269344073125695 163:1.28125:5863:5868 163:0.328125:5864:5867 "
    s .= "25:0.203125:5865:5866 ~0.009262725333746853 ~-0.03352102666427156 ~-0.03310175034027447 ~0.024941275834742337 127:1.078125:5870:5873 172:-0.171875:5871:5872 ~-0.023236851021113832 ~0.034000487830396775 "
    s .= "148:0.625:5874:5875 ~0.0033438794098617775 ~-0.05201607824563173 243:2.05:5877:5920 172:-0.390625:5878:5879 ~-0.02818099041883812 88:1.109375:5880:5917 133:0.03125:5881:5882 ~0.02302272543180633 244:1.465:5883:5902 "
    s .= "246:-0.609375:5884:5889 212:-0.25:5885:5888 136:0.1875:5886:5887 ~0.021661210067044148 ~-0.02324035251850964 ~-0.06442222481011077 41:0:5890:5897 254:1.046875:5891:5894 194:0.1875:5892:5893 ~0.02399392986144433 "
    s .= "~-0.013945662532132561 77:-0.46875:5895:5896 ~0.03163448297688198 ~-0.05654561482093454 249:0.16666666666666666:5898:5899 ~0.003828573513239545 181:0.171875:5900:5901 ~-0.008876899353122606 ~-0.052375749380086906 "
    s .= "245:3.514705882352941:5903:5916 184:0.171875:5904:5913 106:0.328125:5905:5908 244:2.69:5906:5907 ~-0.06597199531425495 ~0.032451339540488504 127:-0.125:5909:5910 ~-0.038063909413503495 250:1.5703125:5911:5912 "
    s .= "~0.028495235038803548 ~-0.14043174596964522 31:0.65625:5914:5915 ~0.0310820110443246 ~-0.03431262720246338 ~-0.05568048250186467 127:1.078125:5918:5919 ~0.028097097456002553 ~-0.010945103580673243 "
    s .= "154:-0.421875:5921:5922 ~0.0595273382052389 ~-0.042262672724354765 254:1.296875:5924:5967 47:0.234375:5925:5964 242:0.25:5926:5927 ~-0.036580538513603995 246:0.140625:5928:5949 203:0.125:5929:5948 125:-0.59375:5930:5933 "
    s .= "195:-0.703125:5931:5932 ~-0.03343661810241136 ~0.021588619298442444 109:0.5625:5934:5939 13:0.625:5935:5938 254:1.234375:5936:5937 ~-0.03053933460733038 ~0.08530520453422186 ~0.036242102145426607 109:1.859375:5940:5945 "
    s .= "110:-1:5941:5942 ~-0.027789332920100607 151:0.078125:5943:5944 ~0.029115628326545868 ~0.0026368981167541458 223:0.046875:5946:5947 ~-0.06897718452765218 ~0.013735067041342364 ~-0.046781515990491546 188:0.5:5950:5963 "
    s .= "250:1.1171875:5951:5962 159:0.2265625:5952:5959 144:0.0625:5953:5956 109:0.5625:5954:5955 ~-0.04008622619625554 ~0.012938108740975236 98:0.265625:5957:5958 ~0.04898602304095543 ~-0.021189118342131885 "
    s .= "236:0.359375:5960:5961 ~-0.03916552299147414 ~0.061836328730043355 ~0.0386251017111757 ~-0.015176143827855197 24:0.09375:5965:5966 ~0.003765951578975626 ~-0.023763511066416942 32:-0.59375:5968:5969 "
    s .= "~-0.001065032942667332 ~-0.04285831606729942 124:-0.6875:5971:5972 ~-0.04975766258248824 77:0.625:5973:6016 251:1.140625:5974:6011 247:0.515625:5975:6006 249:0.5:5976:6001 243:1.45:5977:5998 242:0.25:5978:5979 "
    s .= "~-0.03432328354016211 127:0.140625:5980:5985 136:1.859375:5981:5984 4:1.078125:5982:5983 ~0.027046170149153462 ~-0.03255654698667248 ~-0.034166506034542694 244:1.5:5986:5993 163:0.53125:5987:5992 97:-0.03125:5988:5989 "
    s .= "~-0.03085898754525815 175:0.453125:5990:5991 ~-0.0003598630364764362 ~0.04252360101304142 ~-0.03864157349913834 250:0.6484375:5994:5997 252:0.225:5995:5996 ~-0.08392918880734213 ~0.024565720348944796 "
    s .= "~0.026082176602011765 58:0.5625:5999:6000 ~-0.04611368989657922 ~0.014218268884351175 126:0.25:6002:6003 ~-0.02075636935864998 55:-0.546875:6004:6005 ~0.10877755007524803 ~0.008204658451689762 240:0.546875:6007:6008 "
    s .= "~-0.05542380566662594 243:0.25:6009:6010 ~0.10975932920812939 ~-0.01639248714484287 241:0.46:6012:6015 232:0.734375:6013:6014 ~-0.012721045187899441 ~0.04589693572481093 ~0.025343517186471598 ~-0.02852968415175592 "
    s .= "166:-0.328125:6018:6019 ~-0.02216418897957584 163:-0.34375:6020:6021 ~-0.04503010364723704 238:0.234375:6022:6049 130:2.046875:6023:6046 251:0.765625:6024:6039 217:0.21875:6025:6036 31:0.046875:6026:6031 "
    s .= "247:0.484375:6027:6030 160:-0.109375:6028:6029 ~-0.025703115305001797 ~0.021059168436911323 ~-0.045685565107507056 118:0.296875:6032:6035 251:0.421875:6033:6034 ~-0.019674949888114485 ~0.019821725121839343 "
    s .= "~-0.041805125290372586 24:0.421875:6037:6038 ~-0.042189466904405254 ~0.03210769437768328 241:0.38:6040:6043 184:0.046875:6041:6042 ~-0.025195296919520868 ~0.021170999757703195 34:0.390625:6044:6045 ~0.0302678524695107 "
    s .= "~-0.02287152115870394 77:-0.953125:6047:6048 ~0.03639221915915592 ~-0.051654457452906255 244:1.395:6050:6059 246:-0.109375:6051:6052 ~-0.03868384973845934 47:-0.328125:6053:6056 77:-0.09375:6054:6055 "
    s .= "~0.06408610068261243 ~-0.028446907886567077 220:0.875:6057:6058 ~-0.028134302318252397 ~0.054703953048903964 190:0.765625:6060:6061 ~0.018435967370067946 121:0.015625:6062:6063 ~-0.07556089635949081 "
    s .= "~0.008786417484308306 194:-0.125:6065:6086 120:0.234375:6066:6081 247:0.203125:6067:6080 245:4.15:6068:6079 245:1.6557377049180328:6069:6076 196:-0.609375:6070:6071 ~0.19343329011593327 112:0.25:6072:6073 "
    s .= "~0.023774860984439858 244:1.315:6074:6075 ~-0.04844154440862901 ~0.0074059124148515955 172:-0.25:6077:6078 ~-0.023607722393865663 ~0.01129149976593716 ~-0.10170554592727961 ~-0.028045328348578737 246:-0.140625:6082:6085 "
    s .= "109:1.03125:6083:6084 ~-0.027945801655803622 ~0.03298168360161085 ~0.03566685956912525 246:0.015625:6087:6092 219:0.015625:6088:6091 218:0.015625:6089:6090 ~-0.02699096830115494 ~0.01889045286533314 "
    s .= "~-0.041484033001810444 254:1.046875:6093:6110 128:0.046875:6094:6095 ~0.026905600526486936 242:0.75:6096:6101 184:0.109375:6097:6098 ~-0.03143348814485902 161:0.5625:6099:6100 ~0.014150980808963213 ~-0.0482213067003546 "
    s .= "254:0.765625:6102:6107 109:1.0625:6103:6106 110:0.984375:6104:6105 ~-0.03256638262789363 ~0.04339653631259098 ~0.026897671030008938 244:1.21:6108:6109 ~0.06383805464111562 ~-0.01615104074537187 ~-0.052154930582173846 "
    s .= "203:0.65625:6112:6157 238:0.53125:6113:6150 251:0.421875:6114:6129 7:0.078125:6115:6126 208:-0.09375:6116:6117 ~-0.03872953355686235 109:0.28125:6118:6123 214:-0.109375:6119:6122 124:0.703125:6120:6121 "
    s .= "~0.02638075519303982 ~0.24850531485589644 ~-0.03425538784118184 220:0.203125:6124:6125 ~0.02310824281536017 ~-0.012862922927097127 243:2.95:6127:6128 ~-0.029589633337211436 ~0.17665375003031059 130:1.953125:6130:6145 "
    s .= "249:0.16666666666666666:6131:6134 226:0.359375:6132:6133 ~0.023737781662418828 ~-0.011658081004649393 168:0.0625:6135:6144 17:-0.0625:6136:6143 228:0.15625:6137:6142 40:-0.046875:6138:6141 211:0.25:6139:6140 "
    s .= "~-0.051656302226290335 ~0.01171389963783128 ~0.007461879039360884 ~0.03276154162195329 ~-0.035369224442598955 ~0.01319254985916028 13:0.203125:6146:6149 105:-0.3359375:6147:6148 ~0.02424447043565449 "
    s .= "~-0.053413419325787304 ~0.028140284978394686 70:0.546875:6151:6156 243:0.75:6152:6155 85:0.140625:6153:6154 ~-0.03012891655380466 ~0.018519756852410165 ~-0.03836996441733322 ~-0.06169621636608348 ~-0.03540030378084199 "
    s .= "50:-0.65625:6159:6168 236:-0.125:6160:6167 110:-0.234375:6161:6166 254:0.765625:6162:6163 ~0.0225628707992174 109:1.171875:6164:6165 ~-0.022688145330074922 ~0.0232022482806398 ~0.04228941835796521 ~-0.0263812158637054 "
    s .= "254:1.046875:6169:6204 257:0.38461538461538464:6170:6193 130:2.078125:6171:6192 203:0.65625:6172:6191 205:-0.46875:6173:6174 ~-0.03777104120206115 79:0.78125:6175:6188 88:0.65625:6176:6187 113:0.78125:6177:6186 "
    s .= "152:-0.046875:6178:6181 90:0.7265625:6179:6180 ~0.0062410261094280285 ~0.09575182041877738 186:0.4375:6182:6185 11:0.6875:6183:6184 ~-0.013222599956460166 ~0.056945578564421256 ~-0.0625993878438683 ~0.034891060672508245 "
    s .= "~0.01988074917634858 4:-0.28125:6189:6190 ~-0.021712170030098753 ~0.03259607871531098 ~-0.03759809921466125 ~-0.037599015389285395 4:-0.0625:6194:6199 172:0.234375:6195:6198 244:1.33:6196:6197 ~-0.021789193156806635 "
    s .= "~0.040941785667053254 ~-0.04986233209136074 82:1.84375:6200:6203 59:-0.015625:6201:6202 ~-0.04433566455451338 ~0.016591669682069054 ~-0.1343896289382129 ~-0.028696268711782713 243:2.05:6206:6249 172:-0.359375:6207:6210 "
    s .= "9:0.5078125:6208:6209 ~-0.033989227144292526 ~0.03531870454917656 245:3.459016393442623:6211:6248 88:1.21875:6212:6241 202:0.234375:6213:6228 224:0.625:6214:6227 255:0.234375:6215:6224 254:0.734375:6216:6217 "
    s .= "~0.005091406243670087 245:1.9186046511627908:6218:6219 ~0.04416606369844737 242:0.8500000000000001:6220:6223 149:0:6221:6222 ~0.010150794044879381 ~-0.05277701345055508 ~0.05407979471008626 77:-0.34375:6225:6226 "
    s .= "~0.008224068742517231 ~-0.02401788264280727 ~-0.04800621620757429 25:0.21875:6229:6240 163:0.328125:6230:6233 102:0.5546875:6231:6232 ~0.016595844200193884 ~-0.06772385752446404 163:1.28125:6234:6237 "
    s .= "25:-0.046875:6235:6236 ~-0.04569162996978145 ~-0.006782247432570778 106:1.84375:6238:6239 ~0.051437497439430435 ~-0.05327581353804883 ~-0.03269593653706657 193:-0.09375:6242:6245 175:0.6875:6243:6244 "
    s .= "~0.0026469603947102123 ~-0.06869232716228367 214:1.109375:6246:6247 ~0.033527468189364674 ~-0.035369104837316666 ~-0.0360871177863756 154:-0.421875:6250:6251 ~0.054201528412618154 ~-0.04058471664307682 "
    s .= "190:-0.03125:6253:6266 85:-0.109375:6254:6257 202:-0.046875:6255:6256 ~-0.025783172638317815 ~0.03863200198761768 61:0.546875:6258:6261 76:0.625:6259:6260 ~-0.02359546540581232 ~0.03103075623093614 40:0.453125:6262:6265 "
    s .= "4:-0.28125:6263:6264 ~-0.037067808794855855 ~0.026519205313465678 ~-0.0341058595385455 166:0.390625:6267:6290 88:0.84375:6268:6285 251:1.640625:6269:6284 226:0.875:6270:6283 100:1:6271:6282 255:0.265625:6272:6273 "
    s .= "~0.0023946883270694074 95:-0.5625:6274:6281 134:-0.375:6275:6278 244:1.455:6276:6277 ~-0.04650321113485123 ~0.019521194936616935 154:0.203125:6279:6280 ~0.06205869983674936 ~-0.028972856026698798 ~-0.037968248397897086 "
    s .= "~0.028550016411655665 ~0.040346591761934 ~0.02793548989809997 217:0.546875:6286:6289 145:0.65625:6287:6288 ~0.03292840474514605 ~-0.042818454777403564 ~-0.037227481600056185 145:-0.15625:6291:6292 ~-0.036909589855635964 "
    s .= "103:0.203125:6293:6294 ~0.023048452993448616 244:1.01:6295:6296 ~-0.04737774085505186 193:-0.03125:6297:6298 ~-0.04971681680606746 ~0.005696606391913165 41:0.546875:6300:6345 89:0.78125:6301:6342 11:0.71875:6302:6341 "
    s .= "170:0.25:6303:6336 190:-0.015625:6304:6315 34:0.03125:6305:6312 208:-0.25:6306:6307 ~-0.03839839278064889 142:-0.03125:6308:6309 ~0.02145576802852558 141:0.0390625:6310:6311 ~-0.03429484484678159 ~0.02458020082483492 "
    s .= "91:0.8125:6313:6314 ~-0.030026660497904797 ~0.009658845040190414 238:0.484375:6316:6333 88:1.09375:6317:6330 226:0.765625:6318:6329 255:0.265625:6319:6320 ~0.011376830064763324 119:-0.40625:6321:6328 161:-0.25:6322:6325 "
    s .= "244:1.035:6323:6324 ~-0.0432374736736707 ~0.009304836557065507 122:-0.3125:6326:6327 ~0.06139784291554662 ~-0.025428979558619027 ~-0.031365472974068276 ~0.046964286329068204 145:0.546875:6331:6332 ~0.033972399964653545 "
    s .= "~-0.046094119249227405 94:0.671875:6334:6335 ~-0.006959965627609814 ~-0.06817984287247988 136:0.796875:6337:6338 ~-0.03223521241933412 82:1.8125:6339:6340 ~0.006612976998266903 ~-0.06464764188078559 ~0.09071085133777847 "
    s .= "112:1.140625:6343:6344 ~0.052519660090812936 ~-0.04593322481041223 ~-0.025868087404746654 253:-0.09764309764309784:6347:6356 252:0.125:6348:6353 70:0.0625:6349:6350 ~0.006285703052743502 97:-0.125:6351:6352 "
    s .= "~-0.15117256911024943 ~-0.026995759937453373 40:-0.375:6354:6355 ~-0.036130735115185476 ~0.029824629708776536 251:1.671875:6357:6392 95:0.484375:6358:6391 11:0.71875:6359:6390 50:0.265625:6360:6389 107:0.09375:6361:6380 "
    s .= "239:0.140625:6362:6377 25:0.015625:6363:6368 208:-0.1875:6364:6365 ~-0.03867426455818188 219:-0.40625:6366:6367 ~-0.025069138823922518 ~0.012248540993231444 124:0.03125:6369:6372 208:-0.203125:6370:6371 "
    s .= "~0.015584106876181248 ~-0.0439660392410163 142:0.375:6373:6376 16:0.234375:6374:6375 ~-0.007420133413648056 ~0.03154498545041284 ~-0.030558955317225384 162:0.125:6378:6379 ~-0.04781455868446495 ~0.02196820982645098 "
    s .= "255:0.234375:6381:6388 255:0.140625:6382:6387 109:0.546875:6383:6386 25:-0.265625:6384:6385 ~0.04492383724196666 ~-0.04417525917186973 ~0.027340226714501377 ~0.04558448286556848 ~-0.011312333085437833 "
    s .= "~-0.02509323033630392 ~0.07263855315661372 ~-0.030240352006330157 ~0.015081532644294505 254:1.296875:6394:6437 53:-0.78125:6395:6400 14:-0.0625:6396:6399 215:-0.328125:6397:6398 ~0.02774922986547438 "
    s .= "~-0.013057396612465614 ~-0.054230877535552696 257:0.38461538461538464:6401:6428 133:2.078125:6402:6427 227:0.640625:6403:6426 46:-0.265625:6404:6407 16:0.15625:6405:6406 ~-0.02516562393400574 ~0.02550070633919483 "
    s .= "253:-0.07269338303821087:6408:6415 252:0.175:6409:6414 122:0.09375:6410:6411 ~0.02339949068507286 233:-0.046875:6412:6413 ~-0.1159625047208026 ~-0.009187580427322366 ~0.03760288690217134 139:0.46875:6416:6417 "
    s .= "~-0.0039844625858962025 22:0.234375:6418:6425 244:1.15:6419:6422 252:0.025:6420:6421 ~0.07074167372187615 ~0.011827009481538578 115:0.15625:6423:6424 ~-0.023039444039112844 ~0.023136100083000648 ~-0.011283520306263456 "
    s .= "~-0.03824876540487306 ~-0.029270316648810912 4:-0.046875:6429:6432 151:0.25:6430:6431 ~0.017980596955883395 ~-0.034047909699433936 59:0.359375:6433:6436 82:1.8125:6434:6435 ~-0.03509152817682285 ~-0.1444578476408925 "
    s .= "~0.04858543355371299 50:-0.5:6438:6439 ~-0.004215438660414724 ~-0.045179115690581945 72:1.078125:6441:6486 124:-0.6875:6442:6443 ~-0.04810093650061125 146:-0.125:6444:6467 137:-0.140625:6445:6456 124:0.25:6446:6451 "
    s .= "109:0.5:6447:6450 157:0.78125:6448:6449 ~-0.02572272995870324 ~0.01854587117928059 ~0.01521938720339501 26:-0.75:6452:6455 204:-0.515625:6453:6454 ~-0.043238250537644456 ~0.020936713743050152 ~-0.02664663688404012 "
    s .= "95:-0.359375:6457:6460 144:-0.25:6458:6459 ~-0.044385335713786785 ~0.04634262520307756 255:0.234375:6461:6466 82:0.28125:6462:6465 71:-0.109375:6463:6464 ~0.02858257356855619 ~-0.02469869598997131 ~0.03816720029033463 "
    s .= "~-0.013715879110161387 255:0.265625:6468:6483 255:0.140625:6469:6478 136:0.65625:6470:6477 113:0.984375:6471:6476 106:0.828125:6472:6475 11:0.90625:6473:6474 ~-0.03963276692156359 ~0.06993378424989319 "
    s .= "~0.00851551268532445 ~0.039367794110284335 ~0.0059231477524863555 245:1.9107142857142858:6479:6480 ~0.03688122815020931 242:0.8500000000000001:6481:6482 ~-0.033460329349628795 ~0.029621022217208748 "
    s .= "254:0.546875:6484:6485 ~0.012046597181868905 ~-0.0326782973282714 ~-0.07075272568561512 254:0.984375:6488:6527 208:-0.328125:6489:6490 ~-0.021414510875786844 245:1.1129032258064515:6491:6492 ~-0.04473052575812095 "
    s .= "254:0.953125:6493:6526 146:-0.4375:6494:6503 123:-0.71875:6495:6496 ~-0.03766885201324673 242:0.25:6497:6498 ~-0.054305408027462365 47:-0.671875:6499:6500 ~0.037204319818434486 246:-1.328125:6501:6502 "
    s .= "~-0.017221953620913343 ~0.022753742979456162 257:0.38461538461538464:6504:6517 85:0.625:6505:6514 103:0.875:6506:6513 205:0.5625:6507:6510 106:-0.328125:6508:6509 ~0.04604665695421632 ~-0.014443545768153699 "
    s .= "10:0.1875:6511:6512 ~0.044328426883149766 ~-0.04358056369833282 ~0.023427143067013677 142:0.546875:6515:6516 ~0.019157268139541037 ~-0.01671200673827163 52:-0.078125:6518:6521 244:1.335:6519:6520 ~-0.040397356243601995 "
    s .= "~0.03344263196017505 38:0.375:6522:6525 82:1.8125:6523:6524 ~-0.042574447449386994 ~-0.15255497631313272 ~0.0478277099541552 ~0.031096265586316736 247:0.546875:6528:6533 244:1.315:6529:6530 ~-0.019093237793987163 "
    s .= "253:-0.0016420857076717592:6531:6532 ~0.021323763131910423 ~-0.015542741876242822 ~-0.06074415125144344 243:2.05:6535:6576 245:4.15:6536:6575 248:1.125:6537:6568 257:0.30434782608695654:6538:6555 217:-0.125:6539:6544 "
    s .= "235:-0.078125:6540:6543 5:-0.765625:6541:6542 ~0.03477124467866841 ~-0.03537950256985905 ~0.0046303371813707465 227:0.6875:6545:6554 72:1.078125:6546:6553 253:-0.042911505141282065:6547:6550 252:0.175:6548:6549 "
    s .= "~0.00043984860194125206 ~0.03263657134494157 248:0.125:6551:6552 ~-0.007861798082620046 ~0.012656638030336693 ~-0.07065206702845786 ~-0.04675246561170605 247:-0.390625:6556:6563 254:0.796875:6557:6562 "
    s .= "53:-0.734375:6558:6561 250:1.2265625:6559:6560 ~0.045516296425125835 ~-0.02514681565934352 ~-0.0026212004227720107 ~-0.0223736623902462 47:0.390625:6564:6567 16:-0.046875:6565:6566 ~-0.006074965934316254 "
    s .= "~-0.06852439237204726 ~0.04416732611997015 228:0.125:6569:6572 251:1.703125:6570:6571 ~-0.04483754574237396 ~0.04739853502239303 72:-0.015625:6573:6574 ~0.061348889512132965 ~-0.020491288171839428 ~-0.06475756868825781 "
    s .= "196:-0.609375:6577:6580 245:1.5614035087719298:6578:6579 ~0.19397737609589796 ~0.009868854420223429 ~-0.037870474449805486 77:0.625:6582:6627 256:0.01639344262295082:6583:6620 163:-0.28125:6584:6585 "
    s .= "~-0.026255452792321374 151:0.171875:6586:6609 91:0.5:6587:6604 79:0.65625:6588:6601 245:1.9107142857142858:6589:6594 241:0.62:6590:6593 196:0.203125:6591:6592 ~0.02364592111159212 ~-0.03814631113179247 "
    s .= "~-0.0525041057457248 64:0.265625:6595:6600 227:-0.546875:6596:6599 40:-0.203125:6597:6598 ~0.052701932810555435 ~-0.011589608564880713 ~-0.03837532132079663 ~0.028459930260891282 202:-0.15625:6602:6603 "
    s .= "~-0.025841644926688553 ~0.03229002964857788 172:-0.1875:6605:6606 ~-0.02473620037222815 1:0.375:6607:6608 ~0.04222510680402809 ~-0.054503695400294594 223:-0.0625:6610:6611 ~-0.029292595986774222 "
    s .= "245:1.5816326530612246:6612:6617 244:1.34:6613:6614 ~-0.05335723111796014 235:0.046875:6615:6616 ~-0.07786228152511179 ~0.037616647294750165 118:-0.09375:6618:6619 ~-0.022890836202973268 ~0.007339295891840345 "
    s .= "54:-0.1015625:6621:6622 ~-0.04397389939626326 20:0.46875:6623:6626 245:1.1129032258064515:6624:6625 ~-0.04007111723159069 ~0.031827993997972495 ~-0.025070580084322336 ~-0.026238743907422236 254:0.984375:6629:6666 "
    s .= "254:0.953125:6630:6663 191:-0.4375:6631:6634 190:0.421875:6632:6633 ~0.01975915465266702 ~-0.01599350357192068 110:-0.9375:6635:6636 ~-0.04816492604009573 133:1.9375:6637:6658 127:0.125:6638:6653 109:0.3125:6639:6642 "
    s .= "100:0.390625:6640:6641 ~-0.023592019057691125 ~0.03946701873683506 242:0.35:6643:6648 184:0.09375:6644:6647 54:0.0234375:6645:6646 ~0.01131780057157674 ~-0.07142271072864219 ~0.02125387649961743 197:-0.09375:6649:6650 "
    s .= "~0.04269316568944792 246:0.046875:6651:6652 ~-0.015581366034984351 ~0.02644212303175937 244:0.98:6654:6657 163:0.328125:6655:6656 ~-0.005090346047866611 ~-0.05035597718999009 ~0.0006549157863772875 "
    s .= "177:-0.265625:6659:6660 ~0.03845415713557534 256:0:6661:6662 ~-0.05392540691975829 ~0.016470058540092744 256:0.2:6664:6665 ~0.014303744067727173 ~0.07488676216799521 98:-0.25:6667:6672 257:0.48148148148148145:6668:6671 "
    s .= "196:-0.046875:6669:6670 ~-0.02277142900150861 ~0.011947180623372945 ~-0.03794709677571488 255:0.234375:6673:6674 ~0.008362603074460373 ~-0.04756364992956441 247:0.921875:6676:6721 246:1.796875:6677:6720 "
    s .= "124:-0.6875:6678:6679 ~-0.05074045021947304 91:1.171875:6680:6717 242:0.25:6681:6682 ~-0.032824410759700544 248:1.375:6683:6716 133:2.375:6684:6715 244:1.49:6685:6710 252:0.025:6686:6699 139:0.375:6687:6690 "
    s .= "115:0.265625:6688:6689 ~-0.021970024666193314 ~0.020036352389118915 88:0.4375:6691:6698 238:-0.125:6692:6693 ~0.07199572756676241 115:0.09375:6694:6697 242:0.75:6695:6696 ~-0.04494362115131942 ~0.08863280665650147 "
    s .= "~0.04114138013934226 ~-0.01602520037067671 89:0.78125:6700:6709 10:0.25:6701:6708 208:-0.328125:6702:6703 ~-0.05544692934259511 251:1.359375:6704:6707 97:-0.0625:6705:6706 ~-0.02801599929709569 ~-0.002289890415853564 "
    s .= "~0.02191167902297447 ~-0.03741443505195851 ~0.03538948744580557 157:0.265625:6711:6714 58:0.234375:6712:6713 ~-0.03268213192530964 ~0.03253642548505628 ~0.022015670897827206 ~-0.03881795907867436 ~-0.03682104685014936 "
    s .= "193:-0.015625:6718:6719 ~-0.013913933693414593 ~0.033767604947258584 ~0.04653803092650555 ~-0.04742811458763858 72:1.078125:6723:6768 190:-0.03125:6724:6747 85:-0.109375:6725:6728 202:-0.078125:6726:6727 "
    s .= "~-0.02466794420433789 ~0.036084036876448844 82:0.5625:6729:6742 91:0.75:6730:6739 151:0.203125:6731:6738 76:0.375:6732:6737 223:-0.328125:6733:6734 ~0.02985571549559073 133:0.546875:6735:6736 ~-0.007992751565386095 "
    s .= "~-0.053663731981851176 ~0.04014825209340467 ~-0.051031713994601574 64:0.140625:6740:6741 ~-0.03220334415477737 ~0.035763605472344105 1:-0.28125:6743:6744 ~-0.039249156073422165 251:0.296875:6745:6746 "
    s .= "~-0.03167610105833143 ~0.01627335619118254 112:1.15625:6748:6763 202:0.25:6749:6760 212:0.578125:6750:6759 113:0.71875:6751:6758 106:0.859375:6752:6757 196:-0.015625:6753:6756 109:1.328125:6754:6755 "
    s .= "~-0.012913980061981925 ~-0.08441572886092466 ~0.007161400035742807 ~0.0196981940949201 ~0.04219086990763111 ~-0.04258719540738806 220:1.1875:6761:6762 ~-0.018027548078738305 ~0.05638636357655084 127:1.171875:6764:6767 "
    s .= "181:-0.046875:6765:6766 ~-0.01785737837874398 ~0.028131682578501578 ~-0.00794543858264692 ~-0.06863849662513967 101:0.5625:6770:6811 8:0.8125:6771:6808 245:3.459016393442623:6772:6805 124:-0.65625:6773:6774 "
    s .= "~-0.05184679216547297 257:0.9130434782608695:6775:6802 253:-0.09764309764309784:6776:6785 252:0.125:6777:6782 70:0.0625:6778:6779 ~0.014079875328627135 97:-0.125:6780:6781 ~-0.1393214817030633 ~-0.017362491235405866 "
    s .= "40:-0.375:6783:6784 ~-0.03527053459312251 ~0.03393608962646717 251:1.640625:6786:6801 156:0.6328125:6787:6798 159:0.3359375:6788:6797 249:1.8333333333333335:6789:6796 58:-0.578125:6790:6791 ~0.05413338875793719 "
    s .= "91:1.21875:6792:6795 73:0.203125:6793:6794 ~0.0008403814963485556 ~-0.016982329820871854 ~0.021287934220584392 ~-0.03977352902216488 ~-0.03020483869930331 250:1.2265625:6799:6800 ~-0.05005298290701713 "
    s .= "~0.05550699829717598 ~0.020542440721008415 254:0.015625:6803:6804 ~0.007248823390677986 ~-0.039861337651831724 160:0.625:6806:6807 ~-0.07161466543596788 ~-0.0076847777199872715 243:0.55:6809:6810 ~0.09031432433040089 "
    s .= "~-0.02609361667298138 241:0.54:6812:6813 ~-0.04881024411760911 251:1.390625:6814:6815 ~-0.02642641427124381 ~0.030420892098094662 242:2.25:6817:6862 245:4.744186046511628:6818:6861 251:0.203125:6819:6826 "
    s .= "31:0.078125:6820:6825 106:0.109375:6821:6822 ~-0.03137571657534046 243:0.45:6823:6824 ~0.03913137740272681 ~-0.016047362627792203 ~-0.03943616877579279 252:1.775:6827:6858 243:1.45:6828:6857 127:0.1875:6829:6844 "
    s .= "242:0.25:6830:6833 124:0.0625:6831:6832 ~-0.05702961462041759 ~0.02491331968333363 77:0.546875:6834:6843 79:0.25:6835:6842 88:0.15625:6836:6839 184:0.09375:6837:6838 ~-0.01980385055021621 ~0.01944275979063539 "
    s .= "121:0.46875:6840:6841 ~0.027199696641730855 ~-0.04249536468238821 ~0.03279714713416192 ~-0.03212291166306345 250:0.9609375:6845:6854 247:0.515625:6846:6853 243:0.75:6847:6852 127:0.90625:6848:6851 223:1.015625:6849:6850 "
    s .= "~-0.015273277325811394 ~0.09711630313687784 ~-0.050268561768912756 ~0.011230854951877065 ~-0.0707225152936179 214:0.59375:6855:6856 ~0.008600749947252207 ~-0.034266100485645316 ~-0.03486713579512232 "
    s .= "220:-0.265625:6859:6860 ~-0.03093019242890704 ~0.029687524390162985 ~-0.09164099677943714 ~-0.030641727639658695 254:1.359375:6864:6907 194:-0.125:6865:6878 144:-0.046875:6866:6873 90:0.2109375:6867:6872 "
    s .= "2:0.078125:6868:6871 212:-0.53125:6869:6870 ~0.013272311206239394 ~-0.0076090850607914 ~-0.03928523476436503 ~-0.0521696631177644 186:-0.015625:6874:6875 ~0.031034277500343807 120:0.140625:6876:6877 "
    s .= "~-0.009724332449135842 ~0.020954091601771592 246:0.140625:6879:6888 225:0.0390625:6880:6887 249:0.5:6881:6886 82:1.8125:6882:6883 ~0.017864943625840613 25:-0.09375:6884:6885 ~0.03362631076642539 ~-0.09221088537581174 "
    s .= "~-0.03881117762832921 ~-0.036945804070898876 236:0.5625:6889:6906 247:0.921875:6890:6905 242:0.55:6891:6894 205:0.125:6892:6893 ~-0.025607080696813368 ~0.0199100007909855 254:0.765625:6895:6900 110:0.984375:6896:6899 "
    s .= "245:1.6142857142857143:6897:6898 ~-0.04466217433307746 ~0.013943163322197841 ~0.05590261237301615 245:1.9642857142857142:6901:6902 ~0.05798227719615571 92:0.09375:6903:6904 ~0.03952300102869812 ~-0.05043833980244064 "
    s .= "~-0.06803505840741624 ~-0.025838385458604608 50:-0.6875:6908:6909 ~0.001779777681001411 ~-0.036550053193713586 72:1.078125:6911:6956 190:-0.03125:6912:6933 85:-0.109375:6913:6916 202:-0.09375:6914:6915 "
    s .= "~-0.024565465215107184 ~0.03389794281989645 82:0.5625:6917:6930 91:0.75:6918:6927 151:0.203125:6919:6926 76:0.375:6920:6925 223:-0.328125:6921:6922 ~0.029195690538933013 142:0.296875:6923:6924 ~-0.043952710464661614 "
    s .= "~0.012593372837650574 ~0.0381403919204991 ~-0.0496389450413905 99:0.203125:6928:6929 ~-0.02080761089349368 ~0.04388070281716614 1:-0.28125:6931:6932 ~-0.037641185190720045 ~0.008017797856919787 97:-0.25:6934:6941 "
    s .= "25:-0.28125:6935:6938 190:0.46875:6936:6937 ~0.027662812060061538 ~-0.038883025800648216 148:-0.078125:6939:6940 ~-0.0028090148617723274 ~-0.07020440217153895 251:0.484375:6942:6955 94:0.328125:6943:6954 "
    s .= "28:-0.015625:6944:6949 193:0.171875:6945:6946 ~0.027751366854578175 199:0.578125:6947:6948 ~-0.04419814074202228 ~0.061767977398905216 43:0.21875:6950:6953 175:0.125:6951:6952 ~-0.018805405044334818 ~0.0162634047577642 "
    s .= "~-0.051879536449296465 ~-0.034447226289456484 ~0.011487683613034129 ~-0.06763223881404286 148:0.203125:6958:6983 130:2.265625:6959:6982 184:-0.28125:6960:6961 ~-0.023963905549181985 88:0.625:6962:6975 "
    s .= "205:0.59375:6963:6972 76:0.578125:6964:6971 67:0.5625:6965:6970 133:0.3125:6966:6969 167:0.5:6967:6968 ~0.019014283154349852 ~-0.04036303760019266 ~-0.013605833689270305 ~0.03761760997802361 ~0.029214170296261943 "
    s .= "34:0.203125:6973:6974 ~0.03215568032819128 ~-0.03666788535054968 172:-0.1875:6976:6981 245:1.4833333333333334:6977:6978 ~0.10229977993360742 251:1.359375:6979:6980 ~-0.04654307737082216 ~0.03523548734401404 "
    s .= "~0.023116680499472814 ~-0.04666606672483869 121:-0.28125:6984:6985 ~-0.049777534647846684 198:-0.59375:6986:6987 ~-0.048869392401794234 250:1.2265625:6988:6999 244:1.025:6989:6992 181:0.140625:6990:6991 "
    s .= "~0.008878033850339799 ~-0.04675544317043816 191:-0.65625:6993:6994 ~0.02630339980791145 244:2.135:6995:6998 30:0.6796875:6996:6997 ~-0.00032760583690696584 ~-0.1039909360118539 ~-0.05455208391062491 "
    s .= "108:0.3203125:7000:7003 50:-0.390625:7001:7002 ~0.029701417880224585 ~-0.01346462379509658 ~0.06404820062831866 238:0.53125:7005:7042 208:0.734375:7006:7041 245:3.459016393442623:7007:7040 91:1.109375:7008:7037 "
    s .= "79:0.78125:7009:7032 190:-0.3125:7010:7013 255:-0.140625:7011:7012 ~0.2135226324788885 ~-0.036389410772383786 58:-0.578125:7014:7017 172:-0.046875:7015:7016 ~-0.03895857886703199 ~0.07969118155401222 113:0.875:7018:7029 "
    s .= "11:-0.984375:7019:7022 134:-0.875:7020:7021 ~-0.0073547894279050955 ~0.04010252806616955 117:-0.390625:7023:7024 ~-0.039790461356917106 101:0.53125:7025:7028 8:0.71875:7026:7027 ~-0.004547824429220163 "
    s .= "~0.06928509040366952 ~-0.03551015794193654 41:0.53125:7030:7031 ~0.048215656878102225 ~-0.035572729335501534 251:0.390625:7033:7034 ~-0.023313332354229045 151:0.078125:7035:7036 ~0.040299892264660575 "
    s .= "~0.0064895984420587196 193:-0.078125:7038:7039 ~-0.01862101926989742 ~0.030577092942683095 ~-0.035181370842093565 ~0.02019958306919989 70:0.546875:7043:7050 243:0.75:7044:7047 85:0.140625:7045:7046 "
    s .= "~-0.027389717532108993 ~0.017764035165267388 251:1.796875:7048:7049 ~-0.05169120145710457 ~0.019414406625045934 ~-0.061052487677785316 254:0.984375:7052:7081 254:0.953125:7053:7078 146:-0.4375:7054:7059 "
    s .= "47:-0.640625:7055:7056 ~0.02567140096504779 246:-1.328125:7057:7058 ~-0.025540739756149174 ~0.015452541462128875 257:0.38461538461538464:7060:7069 249:0.16666666666666666:7061:7062 ~0.009111781749335328 "
    s .= "231:0.703125:7063:7068 71:0.171875:7064:7067 219:0.140625:7065:7066 ~-0.014122275268585095 ~0.010632184878859703 ~-0.027714426024747177 ~0.035824705445390854 4:-0.09375:7070:7073 169:0.140625:7071:7072 "
    s .= "~0.027105401075790347 ~-0.056548124182174656 35:0.375:7074:7077 98:0.171875:7075:7076 ~-0.03699053266942839 ~-0.10626528760517676 ~0.03872996029797839 247:0.390625:7079:7080 ~0.013861212359972182 ~0.07422124068296075 "
    s .= "122:-0.203125:7082:7095 158:-0.28125:7083:7090 244:1.055:7084:7085 ~-0.048032586060261236 250:0.8046875:7086:7087 ~-0.053412502634106795 185:-0.71875:7088:7089 ~0.017316101776553797 ~-0.020813839983441603 "
    s .= "100:-0.09375:7091:7092 ~-0.03794038651889037 190:0:7093:7094 ~-0.011236594777687474 ~0.03977066131630477 255:0.234375:7096:7097 ~0.003634879829680999 ~-0.04680944642291531 242:2.25:7099:7142 "
    s .= "245:4.744186046511628:7100:7141 252:1.775:7101:7138 243:1.45:7102:7137 245:2.176470588235294:7103:7126 202:0.25:7104:7117 211:0.28125:7105:7114 242:0.55:7106:7111 229:0.578125:7107:7110 3:-0.125:7108:7109 "
    s .= "~0.028564652706675978 ~-0.007455959839440639 ~0.05181169013446775 130:0.171875:7112:7113 ~0.04848878999048635 ~0.01730963689268105 55:-0.015625:7115:7116 ~0.02145674892495668 ~-0.025500586165639744 "
    s .= "109:1.265625:7118:7123 67:-0.140625:7119:7120 ~-0.05373700404432944 40:0.125:7121:7122 ~0.0065734634929366645 ~-0.02740584675223436 157:0.0625:7124:7125 ~-0.04795887779626664 ~0.026957517777803114 236:-0.53125:7127:7128 "
    s .= "~0.011645940730844023 127:0.90625:7129:7136 208:0.515625:7130:7135 64:0.265625:7131:7134 103:-0.046875:7132:7133 ~-0.06030068578923275 ~-0.016172540597172505 ~0.00860029484578616 ~0.02137371714286145 "
    s .= "~-0.03868487309084498 ~-0.03430663910470658 251:0.296875:7139:7140 ~-0.04832202610062221 ~0.024961575712160084 ~-0.08895022331341045 130:0.953125:7143:7144 ~-0.05247462735211836 ~0.010315289919682261 "
    s .= "72:1.078125:7146:7191 257:0.9130434782608695:7147:7188 253:-0.09764309764309784:7148:7161 252:0.125:7149:7156 33:-0.171875:7150:7151 ~-0.07331903580656994 146:0.109375:7152:7153 ~0.019904118919972725 "
    s .= "249:0.16666666666666666:7154:7155 ~0.009258793084639652 ~-0.09204471707190494 46:-0.265625:7157:7160 233:-0.109375:7158:7159 ~0.024165507529257925 ~-0.07150714586946164 ~0.03267039322297809 251:1.671875:7162:7183 "
    s .= "242:2.05:7163:7180 249:1.8333333333333335:7164:7179 8:0.8125:7165:7176 95:0.234375:7166:7175 74:0.34375:7167:7174 245:1.4941176470588236:7168:7173 1:0.859375:7169:7172 151:0.046875:7170:7171 ~0.06074629818923099 "
    s .= "~-0.006650367231212035 ~0.34803332811654075 ~0.0006828652143976273 ~-0.03601056123808026 ~-0.01569251553556996 107:0.75:7177:7178 ~0.08219988171179496 ~-0.0473339562284138 ~-0.03444180307678713 "
    s .= "245:2.4642857142857144:7181:7182 ~-0.05903976607592515 ~0.00982122497744605 252:0.07500000000000001:7184:7187 46:0.265625:7185:7186 ~-0.050879685180029936 ~0.033439489552681584 ~0.025888105800316377 "
    s .= "133:0.765625:7189:7190 ~-0.043237013961148436 ~0.0022551064148347475 ~-0.06633707370511273 254:1.359375:7193:7236 248:1.375:7194:7235 77:0.625:7195:7234 242:0.25:7196:7199 16:0.484375:7197:7198 ~-0.041058695822938494 "
    s .= "~0.037610133769130874 127:0.1875:7200:7211 133:1.5625:7201:7208 243:1.45:7202:7205 223:0.71875:7203:7204 ~0.02144484329501299 ~-0.025726451360778592 61:0.5625:7206:7207 ~-0.0431419269542778 ~0.020844113206731567 "
    s .= "211:0.15625:7209:7210 ~-0.025426097441811235 ~0.023126909084000592 257:0.8571428571428571:7212:7231 47:-0.328125:7213:7224 190:-0.140625:7214:7215 ~-0.023394298944009087 244:1.115:7216:7219 242:1.45:7217:7218 "
    s .= "~0.044880131940954616 ~-0.03582633440322921 215:-0.390625:7220:7221 ~0.019556222583531718 159:-0.0859375:7222:7223 ~-0.054750426422973855 ~0.011519985009854563 249:0.16666666666666666:7225:7226 ~0.004588143098949661 "
    s .= "165:0.125:7227:7228 ~-0.027796968719874134 251:0.953125:7229:7230 ~-0.018762528639996005 ~0.02495054652629089 115:0.28125:7232:7233 ~0.00425203914997658 ~-0.0532748628536876 ~-0.023636137218695848 ~-0.02950239409548157 "
    s .= "50:-0.6875:7237:7238 ~0.0014144227455759899 ~-0.03450213849167321 191:0.71875:7240:7285 246:1.796875:7241:7284 124:-0.6875:7242:7243 ~-0.04886383221433518 148:0.203125:7244:7267 88:0.625:7245:7262 91:0.28125:7246:7261 "
    s .= "193:0.140625:7247:7258 103:0.53125:7248:7257 178:0.46875:7249:7256 124:0.09375:7250:7253 61:0.34375:7251:7252 ~-0.029856617410173848 ~0.019708263551044766 122:-0.65625:7254:7255 ~0.05490027233404916 "
    s .= "~-0.009917544272042559 ~0.021151721306130026 ~0.019628590436192073 16:0.390625:7259:7260 ~-0.03137306842995767 ~0.03758337064406754 ~0.015755467682039056 196:-0.078125:7263:7266 245:1.4941176470588236:7264:7265 "
    s .= "~0.0910412345466574 ~-0.01632591649592068 ~0.022569233378541036 192:0.25:7268:7283 244:0.955:7269:7270 ~-0.035855929760719676 245:3.3620689655172415:7271:7282 112:-0.28125:7272:7273 ~0.04581041805700482 "
    s .= "106:0.140625:7274:7275 ~-0.04716798778823279 142:-0.03125:7276:7279 244:1.885:7277:7278 ~-0.04192351133483406 ~0.0395914032434602 94:0.765625:7280:7281 ~0.010082387935108163 ~-0.05429278348521364 ~-0.07903615588075599 "
    s .= "~0.01235314172528143 ~0.041353845121369776 ~-0.0337437612972535 238:0.53125:7287:7328 190:-0.03125:7288:7305 76:0.59375:7289:7302 61:0.8125:7290:7301 88:-0.109375:7291:7292 ~0.009918887422677644 252:0.525:7293:7298 "
    s .= "46:0.796875:7294:7297 148:0:7295:7296 ~-0.01568913933780402 ~-0.04655038408214521 ~0.036562935832012096 237:0.109375:7299:7300 ~-0.022763749593472438 ~0.0254018636750394 ~0.016057420771421454 184:1.375:7303:7304 "
    s .= "~0.031030322736058453 ~-0.07123947956786021 88:1.09375:7306:7325 257:0.7741935483870968:7307:7320 191:0.265625:7308:7319 89:0.796875:7309:7318 46:0.71875:7310:7317 226:0.765625:7311:7316 119:-0.859375:7312:7313 "
    s .= "~0.025082954845865715 255:0.234375:7314:7315 ~0.009468512357857516 ~-0.015160371904207888 ~0.04025727198021528 ~0.046261594623085954 ~0.052119000753908566 ~-0.013303891901715825 244:1.145:7321:7322 "
    s .= "~-0.049785032204823255 213:-0.078125:7323:7324 ~0.023491724003814766 ~-0.05572522852259243 199:0.015625:7326:7327 ~-0.002255099178611305 ~0.03322989786973163 70:0.609375:7329:7332 243:0.75:7330:7331 "
    s .= "~0.004201165124604659 ~-0.03466536728115307 ~-0.0635959784670321 110:-1.125:7334:7343 43:0.375:7335:7342 155:-0.671875:7336:7341 244:1.48:7337:7340 56:-1.296875:7338:7339 ~0.015413622971004704 ~-0.042073869528697724 "
    s .= "~0.02718853889588286 ~-0.048294678331648286 ~-0.05874341610686954 98:-0.984375:7344:7347 95:-1.015625:7345:7346 ~0.053108514696431956 ~0.000667167829129753 255:0.265625:7348:7371 255:0.140625:7349:7366 "
    s .= "246:1.734375:7350:7365 131:0.609375:7351:7364 106:1.984375:7352:7363 11:0.90625:7353:7362 85:1.171875:7354:7361 61:-0.296875:7355:7356 ~0.029906806620288336 184:1:7357:7360 64:1.3125:7358:7359 ~-0.01224353584314654 "
    s .= "~0.05666164294140295 ~0.023288822046654157 ~0.017853007330303643 ~0.0831447070115706 ~-0.037200001880670845 ~-0.0333676212885025 ~0.03690945858528918 219:0.140625:7367:7370 249:0.16666666666666666:7368:7369 "
    s .= "~0.020388044650800793 ~-0.015072835884052458 ~0.03518374500804149 244:0.91:7372:7373 ~-0.04220259484501551 247:0.203125:7374:7375 ~0.0006694073752000161 3:0.59375:7376:7379 250:1.1171875:7377:7378 ~-0.05225569315566617 "
    s .= "~0.013314992201200799 ~0.04131381773144656 247:0.921875:7381:7426 246:1.890625:7382:7425 175:-0.484375:7383:7386 245:1.4444444444444444:7384:7385 ~0.05672016736891369 ~-0.047811607965114605 243:2.05:7387:7422 "
    s .= "257:0.30434782608695654:7388:7411 253:-0.055855855855857804:7389:7392 248:0.125:7390:7391 ~0.03109491450780857 ~0.001979780036412491 190:0:7393:7400 85:-0.09375:7394:7397 13:-0.265625:7395:7396 ~-0.04353090800357648 "
    s .= "~0.03960954264139384 19:0.125:7398:7399 ~-0.026466500851749397 ~0.004807357134478055 15:0.4453125:7401:7410 115:-0.09375:7402:7403 ~-0.02400049628513276 55:0.09375:7404:7409 109:0.109375:7405:7406 ~-0.011529943772645825 "
    s .= "220:-0.09375:7407:7408 ~-0.01438784067890778 ~0.03498179436678705 ~0.0010443338399672686 ~-0.015558874896551689 13:0.046875:7412:7419 163:1.078125:7413:7414 ~0.011791193829918781 193:0.03125:7415:7418 "
    s .= "1:-0.015625:7416:7417 ~-0.027922118757212407 ~-0.1273301904773839 ~0.016964720197657112 125:-0.59375:7420:7421 ~-0.004068049911297307 ~-0.04905463390142038 245:2.3137254901960786:7423:7424 ~-0.04840570325000853 "
    s .= "~0.011289473573598385 ~0.05565135230156875 ~-0.04401645368661127 254:0.984375:7428:7471 254:0.953125:7429:7468 245:1.3766233766233766:7430:7435 247:0.578125:7431:7434 97:0.6875:7432:7433 ~-0.041910802046868374 "
    s .= "~0.093358917676283 ~0.03548303610291634 97:0.84375:7436:7467 146:-0.484375:7437:7440 11:0.140625:7438:7439 ~0.017225231777723813 ~-0.03151905401341424 246:0.015625:7441:7456 244:1.47:7442:7449 203:-0.046875:7443:7448 "
    s .= "174:-0.25:7444:7445 ~-0.047122137515317075 90:0.0546875:7446:7447 ~0.007617147240888875 ~-0.034516073633267676 ~-0.05034692433186169 247:-0.015625:7450:7455 56:-0.015625:7451:7454 249:0.5:7452:7453 ~0.010039888032861002 "
    s .= "~-0.04979758944979515 ~0.03785265640671728 ~-0.03567321043755224 128:0.046875:7457:7458 ~0.023289178774330822 121:-0.296875:7459:7460 ~-0.050787829050394806 79:0.703125:7461:7466 250:0.6640625:7462:7463 "
    s .= "~-0.04261516737875042 184:0.078125:7464:7465 ~-0.01533131988544735 ~0.011989076406986992 ~0.02524055138258004 ~-0.027315957516959824 247:0.359375:7469:7470 ~0.012208229593921241 ~0.06935481487873535 "
    s .= "247:0.546875:7472:7473 ~-0.00662074933677279 ~-0.05749855978552715 72:1.078125:7475:7520 195:-0.34375:7476:7485 133:0.90625:7477:7480 148:1.78125:7478:7479 ~-0.03453918178592865 ~-0.25268714051847424 "
    s .= "55:-0.078125:7481:7482 ~-0.038912007860840064 4:0.265625:7483:7484 ~0.02328619884918827 ~-0.036484150387930646 191:-0.671875:7486:7487 ~0.015363900166666234 246:-1.984375:7488:7489 ~-0.03725945344192566 "
    s .= "255:0.234375:7490:7513 255:0.140625:7491:7504 188:-0.25:7492:7493 ~0.014668681424664015 134:1:7494:7503 245:1.3571428571428572:7495:7496 ~-0.04132731117965999 250:1.2109375:7497:7502 121:0.125:7498:7499 "
    s .= "~-0.004655167354196718 256:0:7500:7501 ~-0.05150188923101826 ~0.0013314035491434274 ~0.010970043041226325 ~0.04114114308963475 219:0.140625:7505:7512 191:0.25:7506:7511 141:0.0703125:7507:7510 192:-0.09375:7508:7509 "
    s .= "~0.03241157400545339 ~-0.02516327133890064 ~0.04488801280432741 ~-0.03235747601738312 ~0.03892280676866704 244:0.92:7514:7515 ~-0.04334301988725065 219:-0.15625:7516:7517 ~0.015845717556210736 97:-0.28125:7518:7519 "
    s .= "~-0.05147196378320869 ~-0.007748584977500784 ~-0.06504436281715407 110:-1.125:7522:7531 43:0.375:7523:7530 155:-0.671875:7524:7529 244:1.545:7525:7528 233:-0.671875:7526:7527 ~-0.004544953200547663 ~-0.07276440369822414 "
    s .= "~0.028019104249979304 ~-0.04598556603317794 ~-0.05707925371249231 98:-1.046875:7532:7535 143:-0.546875:7533:7534 ~0.04338539778788232 ~-0.039640849256475645 255:0.265625:7536:7551 255:0.140625:7537:7542 "
    s .= "246:1.734375:7538:7541 131:0.609375:7539:7540 ~0.000578466611026625 ~-0.03148956301399996 ~0.03461208365453611 219:0.140625:7543:7550 191:0.25:7544:7549 246:0.296875:7545:7548 210:-0.09375:7546:7547 "
    s .= "~0.021678075541656766 ~-0.02171137080864334 ~0.04427087908102516 ~-0.030994032912541256 ~0.0322660685076381 244:0.935:7552:7553 ~-0.03457390366043083 247:0.203125:7554:7563 226:0.671875:7555:7562 "
    s .= "245:1.6231884057971016:7556:7557 ~-0.03967362338502435 106:0.046875:7558:7559 ~-0.03274862238741066 245:3.3620689655172415:7560:7561 ~0.00987301391829738 ~-0.042565640112115916 ~0.034469212794589484 3:0.59375:7564:7567 "
    s .= "250:1.0703125:7565:7566 ~-0.05235274282534538 ~0.005707017586347309 ~0.038669224310690725 184:2.3125:7569:7614 253:-0.07269338303821087:7570:7583 252:0.125:7571:7576 19:0.0625:7572:7575 128:0.265625:7573:7574 "
    s .= "~0.011431354314726206 ~-0.054404724489891004 ~-0.04872115495253372 46:-0.265625:7577:7580 212:-0.0625:7578:7579 ~0.0213144187419687 ~-0.06041291553455705 257:0.45454545454545453:7581:7582 ~0.031263328704528984 "
    s .= "~-0.01520138264494683 254:0.984375:7584:7605 144:-0.765625:7585:7586 ~-0.04087733136624219 143:-0.71875:7587:7592 2:-0.5:7588:7591 184:0.015625:7589:7590 ~-0.010686321509906276 ~0.0419737879283624 ~-0.011154625100693158 "
    s .= "219:-0.25:7593:7596 160:1.078125:7594:7595 ~-0.042600290490149316 ~0.013402963170749047 130:1.90625:7597:7602 174:-0.4375:7598:7599 ~-0.07383304802980019 194:0.21875:7600:7601 ~0.00814062290973839 ~-0.009151662469552976 "
    s .= "226:0.046875:7603:7604 ~-0.057931848115768396 ~-0.0014717860365910827 32:-0.359375:7606:7611 246:-0.421875:7607:7608 ~-0.015518701230227864 95:-0.0625:7609:7610 ~0.0316170350546967 ~-0.058843910072917185 "
    s .= "255:0.203125:7612:7613 ~0.009950194060914366 ~-0.051340177912869656 ~-0.050443841138551576 72:1.078125:7616:7661 49:0.90625:7617:7660 247:0.921875:7618:7659 253:-0.09764309764309784:7619:7630 252:0.125:7620:7625 "
    s .= "13:0.046875:7621:7624 232:0.015625:7622:7623 ~-0.01951883891250708 ~0.03672070487630178 ~-0.04279194899621289 187:0.28125:7626:7629 153:0.6796875:7627:7628 ~0.03810588476273306 ~-0.0797286888274192 "
    s .= "~-0.0031295666739707935 231:-0.609375:7631:7632 ~-0.028386079696938987 122:-0.78125:7633:7636 119:-0.65625:7634:7635 ~0.025707144487860874 ~-0.013189126231837326 195:-0.328125:7637:7638 ~-0.03707936935782418 "
    s .= "254:1.046875:7639:7656 130:2.046875:7640:7655 106:0.546875:7641:7648 91:0.234375:7642:7647 52:0.515625:7643:7646 31:-0.265625:7644:7645 ~0.016973455921377258 ~-0.02117371375246053 ~0.035299307665199266 "
    s .= "~0.011655867184150417 217:0.21875:7649:7652 181:1.546875:7650:7651 ~0.020057457340507737 ~-0.030251482009729463 196:1.015625:7653:7654 ~-0.025816588521436985 ~0.059725081067819444 ~-0.03329622752830881 "
    s .= "26:-0.359375:7657:7658 ~-0.004631375783754188 ~-0.04601238303860756 ~-0.04509731459324749 ~-0.024671461095738596 ~-0.06420813507810294 203:0.6875:7663:7708 246:0.109375:7664:7693 247:-0.015625:7665:7688 "
    s .= "244:1.49:7666:7675 218:0.046875:7667:7674 134:-0.875:7668:7669 ~-0.021672130309192135 119:-0.859375:7670:7671 ~0.03948407630676207 110:-0.203125:7672:7673 ~-0.010827673420060727 ~0.02079594441567333 "
    s .= "~-0.048665050379324185 181:0.0625:7676:7683 58:0.3125:7677:7680 94:-0.03125:7678:7679 ~0.003349247869454117 ~-0.05472993116222444 58:2.484375:7681:7682 ~0.03439089668527227 ~-0.09066717251371649 43:0.46875:7684:7687 "
    s .= "214:1.109375:7685:7686 ~0.028114168253370972 ~-0.026386023315239995 ~-0.04538646140383895 126:0.171875:7689:7690 ~-0.035734142609657474 55:-0.484375:7691:7692 ~0.07502005803896779 ~-0.010453340919146117 "
    s .= "250:1.1171875:7694:7699 159:0.3359375:7695:7698 217:-0.125:7696:7697 ~-0.03145315366103556 ~0.008223776973773682 ~-0.03818167586709145 111:0.2578125:7700:7707 48:0.0859375:7701:7702 ~0.03197325310575825 "
    s .= "245:1.6290322580645162:7703:7706 254:0.546875:7704:7705 ~-0.05688178641518291 ~0.029085789381995714 ~0.010230281826181362 ~0.04024419980545771 ~-0.03284242900241049 238:0.53125:7710:7751 208:0.734375:7711:7750 "
    s .= "196:1.078125:7712:7749 245:3.459016393442623:7713:7748 100:1:7714:7747 91:1.109375:7715:7744 110:-1.125:7716:7719 139:0.40625:7717:7718 ~-0.006477673175395217 ~-0.059545700376936184 44:-0.96875:7720:7721 "
    s .= "~0.024339423256792562 181:1.609375:7722:7743 61:1.125:7723:7742 190:-0.15625:7724:7727 76:0.6875:7725:7726 ~-0.03055691398335166 ~0.04206961366263056 167:0.5625:7728:7741 113:0.734375:7729:7740 16:0.40625:7730:7737 "
    s .= "211:0.1875:7731:7732 ~-0.0006364006217036509 184:0.015625:7733:7734 ~-0.08626591881108163 37:-0.375:7735:7736 ~0.04355134266478969 ~-0.0213620392230629 253:-0.0007518796992452995:7738:7739 ~-0.02571248589571283 "
    s .= "~0.04250740960111571 ~0.03882554241193767 ~-0.0371605263925727 ~0.024116672112724155 ~-0.047471153965731636 124:-0.125:7745:7746 ~-0.048572715012184575 ~0.02745820126696351 ~0.020493823199809896 ~-0.03536950270441492 "
    s .= "~0.028880107221573293 ~0.018916242640545256 70:0.609375:7752:7755 243:0.75:7753:7754 ~0.004009538043469188 ~-0.03274791713543509 ~-0.06259848123734203 49:0.90625:7757:7802 41:0.546875:7758:7801 11:0.71875:7759:7800 "
    s .= "89:0.78125:7760:7797 74:-0.140625:7761:7784 246:-0.578125:7762:7777 236:-0.234375:7763:7774 250:0.6328125:7764:7765 ~-0.07596904665832527 244:0.955:7766:7769 8:-1.0625:7767:7768 ~0.017621585855691697 "
    s .= "~-0.042754914248484766 128:-0.453125:7770:7771 ~0.01506246659140029 99:-0.171875:7772:7773 ~-0.04378266294246676 ~0.005636582052349513 81:-0.3046875:7775:7776 ~0.013183852942876818 ~-0.04540194351846643 "
    s .= "247:0.203125:7778:7779 ~0.02099260428855133 216:0.390625:7780:7781 ~-0.023400503059278974 253:0.03703703703703809:7782:7783 ~0.03763282164240493 ~-0.06370131722312973 249:0.16666666666666666:7785:7792 "
    s .= "31:0.046875:7786:7791 214:1.03125:7787:7788 ~0.01668625744239292 85:1.84375:7789:7790 ~-0.0011050675170572008 ~-0.11973194447514178 ~-0.013819951398361067 195:0.28125:7793:7794 ~-0.025889504903165113 "
    s .= "127:0.078125:7795:7796 ~0.030758785101208816 ~-0.010710718576305152 112:1.140625:7798:7799 ~0.04778301817375538 ~-0.04324710401451202 ~0.07350137350627146 ~-0.022919404209510948 ~-0.024024884780217897 "
    s .= "72:1.078125:7804:7849 242:2.25:7805:7848 252:1.775:7806:7845 243:1.45:7807:7844 245:2.176470588235294:7808:7835 202:0.25:7809:7822 211:0.28125:7810:7819 242:0.55:7811:7816 229:0.578125:7812:7815 3:-0.125:7813:7814 "
    s .= "~0.02775764011268434 ~-0.006994918604178395 ~0.05049278331342574 130:0.171875:7817:7818 ~0.04618775692541163 ~0.015753078740762618 55:-0.015625:7820:7821 ~0.018644596413902904 ~-0.02331253594087499 100:0.15625:7823:7828 "
    s .= "157:0.078125:7824:7825 ~-0.03642456172837172 34:0.234375:7826:7827 ~0.022947730395858353 ~-0.043931413229190336 244:1.575:7829:7834 67:-0.140625:7830:7831 ~-0.07230608933978051 156:0.0390625:7832:7833 "
    s .= "~-0.04352501691626052 ~0.007651466254828668 ~0.021195662821464248 44:-0.734375:7836:7837 ~0.015212650461546538 127:0.90625:7838:7843 91:1.3125:7839:7842 238:-0.03125:7840:7841 ~-0.031853401960752974 "
    s .= "~-0.0030002547128278856 ~0.029067537979632848 ~-0.03571223163893825 ~-0.03089506151900824 251:0.296875:7846:7847 ~-0.04752286423689918 ~0.024422768063126096 ~-0.02603639845802355 ~-0.06306862235067905 "
    s .= "254:0.984375:7851:7890 208:-0.328125:7852:7859 64:1.796875:7853:7858 154:0.484375:7854:7857 220:-0.046875:7855:7856 ~-0.037399409111033455 ~0.027541972314854266 ~-0.053448131334291986 ~0.05131903432755447 "
    s .= "217:0.21875:7860:7873 106:0.59375:7861:7870 64:0.625:7862:7869 160:0.703125:7863:7868 1:0.0625:7864:7865 ~-0.022587556068509863 245:2.227272727272727:7866:7867 ~0.016651928245250466 ~-0.03229763273701476 "
    s .= "~0.01714015594800836 ~0.03138104579718991 166:0.53125:7871:7872 ~0.01832099119344976 ~-0.011111657197130722 243:0.25:7874:7877 19:0.609375:7875:7876 ~0.0342384514870348 ~0.2199792632460286 220:0.96875:7878:7889 "
    s .= "250:0.6796875:7879:7880 ~-0.07092423959412812 244:1.085:7881:7884 163:0.296875:7882:7883 ~-0.005302162716272399 ~-0.058377510702190265 28:-0.265625:7885:7886 ~0.036401906820742895 94:0.21875:7887:7888 "
    s .= "~-0.03345392330166277 ~0.01629242304218957 ~0.02716680750241259 26:-0.171875:7891:7894 257:0.48148148148148145:7892:7893 ~0.0012020523099837632 ~-0.03735610068897909 255:0.234375:7895:7896 ~-0.0026713245038359934 "
    s .= "~-0.047028606771098526 98:0.625:7898:7943 8:0.8125:7899:7940 245:3.459016393442623:7900:7937 124:-0.65625:7901:7902 ~-0.04705994360682388 124:0.203125:7903:7924 103:0.078125:7904:7919 88:0.109375:7905:7912 "
    s .= "184:0.328125:7906:7909 34:0.546875:7907:7908 ~-0.027583437124536016 ~0.06148341875549179 55:0.015625:7910:7911 ~0.030066105883520662 ~-0.03944671479590202 13:0.09375:7913:7918 154:1.328125:7914:7917 "
    s .= "133:1.78125:7915:7916 ~0.03012875610810621 ~-0.04976413449451885 ~-0.025094805229874857 ~-0.021940767510297388 108:0.1796875:7920:7921 ~0.015831366610338644 251:1.109375:7922:7923 ~-0.026104463843312338 "
    s .= "~0.016490380236994683 114:-0.6015625:7925:7926 ~-0.04012974205841698 98:-0.71875:7927:7928 ~0.0183705037440899 109:-0.078125:7929:7930 ~0.03483881297470007 244:1.585:7931:7934 199:0.8125:7932:7933 ~-0.02161572270423417 "
    s .= "~0.02922307822477807 243:0.55:7935:7936 ~-0.025575001089318664 ~0.02616155109781378 160:0.625:7938:7939 ~-0.0646851271526567 ~-0.003267442768241757 243:0.55:7941:7942 ~0.07793916123627087 ~-0.020715526986871333 "
    s .= "~-0.025985775429135684 110:-1:7945:7950 212:-0.5625:7946:7949 118:0.328125:7947:7948 ~0.008552151133056574 ~-0.035680134398949924 ~-0.0358648513114268 62:-1.015625:7951:7952 ~0.03255426682017171 133:2.46875:7953:7988 "
    s .= "109:0.53125:7954:7967 100:0.578125:7955:7966 89:0.796875:7956:7965 139:0.421875:7957:7960 156:0.6953125:7958:7959 ~-0.026390477248480343 ~0.047697918489904324 190:0.703125:7961:7964 242:0.35:7962:7963 "
    s .= "~0.06813971798999463 ~-0.009384663562440866 ~0.04959530159851812 ~0.024729023639394495 ~0.02861962804893783 205:-0.3125:7968:7969 ~-0.025344345008468418 66:0.109375:7970:7985 148:0.546875:7971:7982 220:0.875:7972:7981 "
    s .= "217:0.21875:7973:7976 124:-0.453125:7974:7975 ~-0.04656898282246489 ~0.020217987313135413 244:1.655:7977:7980 22:-0.34375:7978:7979 ~0.028931340103834247 ~-0.04084805876233484 ~0.031426675903202105 ~0.05662191175409048 "
    s .= "6:0.03125:7983:7984 ~-0.02613243102254892 ~0.019180664838895075 123:0.203125:7986:7987 ~-0.018157476886283223 ~0.007685592384238223 174:-0.203125:7989:7990 ~0.049546261417366205 ~-0.06764151880542195 "
    s .= "254:1.359375:7992:8029 242:0.25:7993:7996 124:0.03125:7994:7995 ~-0.055326412559227614 ~0.007078443359718585 151:0.140625:7997:8010 106:2:7998:8007 103:0.265625:7999:8004 37:0.375:8000:8003 88:0.3125:8001:8002 "
    s .= "~-0.010372969315838004 ~0.02033142315477196 ~0.03918861468984161 214:0.40625:8005:8006 ~0.026876685077033675 ~-0.015101617847160907 161:-0.546875:8008:8009 ~0.015338068230993835 ~-0.058280146134115265 "
    s .= "133:0.671875:8011:8018 250:0.6640625:8012:8013 ~-0.06025130383416591 162:-0.046875:8014:8015 ~-0.0303851453011786 41:0:8016:8017 ~0.014042484654525135 ~-0.02213866263470948 120:0.15625:8019:8026 204:0.375:8020:8025 "
    s .= "117:-0.6875:8021:8022 ~-0.043251626491123955 91:-0.25:8023:8024 ~-0.038168549583999845 ~0.006247724216993704 ~-0.0454901082170942 123:-0.140625:8027:8028 ~-0.04497117232438142 ~0.02393188249288565 244:1.32:8030:8035 "
    s .= "50:-0.6875:8031:8034 164:-0.21875:8032:8033 ~-0.030231244969604616 ~0.040365031161114444 ~-0.05797121602060469 253:0.005024422569535757:8036:8037 ~0.012170400075461718 ~-0.043562509249123825 218:0.65625:8039:8084 "
    s .= "238:0.53125:8040:8079 248:1.125:8041:8074 208:0.734375:8042:8073 181:1.484375:8043:8070 85:1.28125:8044:8065 246:-0.578125:8045:8052 212:-0.25:8046:8049 108:0.0390625:8047:8048 ~0.00146951640487703 "
    s .= "~-0.037316436923443906 106:1.390625:8050:8051 ~-0.04775881735044908 ~0.02641142834707762 62:-0.421875:8053:8054 ~0.02573315907074282 255:0.328125:8055:8064 254:0.765625:8056:8061 11:0.90625:8057:8060 "
    s .= "109:0.546875:8058:8059 ~-0.018416595885511325 ~0.005479351387480055 ~0.06152122024747189 133:0.890625:8062:8063 ~0.036160616719038634 ~-0.0015396997742714656 ~-0.02536007577324298 253:-0.006628787878785403:8066:8067 "
    s .= "~0.027499720134425604 83:-0.125:8068:8069 ~0.01818829688682973 ~-0.04387011832615647 82:1.46875:8071:8072 ~0.0018761625846475446 ~-0.051760938336505885 ~0.023366604552107373 225:0.1484375:8075:8076 ~-0.03744776503384847 "
    s .= "91:0.140625:8077:8078 ~-0.02984966862726477 ~0.04848728901600935 70:0.609375:8080:8083 243:1.75:8081:8082 ~-0.003258917849496664 ~-0.07304481652512193 ~-0.06185245896510168 ~-0.033050474832459036 247:0.921875:8086:8131 "
    s .= "246:1.890625:8087:8130 175:-0.484375:8088:8091 245:1.4444444444444444:8089:8090 ~0.05258773230196591 ~-0.0465500847953303 30:0.9296875:8092:8129 8:0.859375:8093:8128 74:-0.140625:8094:8113 246:-0.578125:8095:8100 "
    s .= "122:-0.65625:8096:8097 ~0.00801119012567128 66:0.0625:8098:8099 ~-0.005134930306175591 ~-0.04490343931329184 119:0.078125:8101:8108 110:0.03125:8102:8107 82:-0.125:8103:8104 ~0.05037430797247098 244:2.405:8105:8106 "
    s .= "~0.006831799897075205 ~-0.05930802946636701 ~0.03182800494684181 245:1.9611650485436893:8109:8110 ~0.01922465445645788 137:0.171875:8111:8112 ~0.009030643257555749 ~-0.04598270022286943 249:0.16666666666666666:8114:8123 "
    s .= "222:0.453125:8115:8122 82:1.8125:8116:8119 227:-0.65625:8117:8118 ~-0.03966017041316466 ~0.014281468771738658 61:0.1875:8120:8121 ~-0.06111722202062561 ~0.0133082857327087 ~-0.030821608732047447 219:0.28125:8124:8125 "
    s .= "~-0.024059916432365602 234:-0.140625:8126:8127 ~-0.07658410091896545 ~0.01311643402582999 ~0.04584169390551818 ~-0.04774812037028439 ~0.05411823939052688 ~-0.040645255197527964 72:1.078125:8133:8178 242:2.25:8134:8177 "
    s .= "252:1.875:8135:8174 243:1.45:8136:8171 245:2.176470588235294:8137:8160 257:0.30434782608695654:8138:8151 248:1.375:8139:8150 100:0.53125:8140:8149 64:-0.1875:8141:8144 130:1.609375:8142:8143 ~-0.028357478906923524 "
    s .= "~0.03265097775310319 212:0.3125:8145:8146 ~0.015343647479518333 24:0.09375:8147:8148 ~0.019544243550397997 ~-0.025020090807762158 ~0.03066441729578397 ~-0.03938633429150659 252:0.32499999999999996:8152:8155 "
    s .= "4:0.078125:8153:8154 ~0.01306456478114366 ~-0.031885235004003344 244:2.79:8156:8157 ~-0.035588048030190056 242:0.95:8158:8159 ~-0.09555013216938296 ~-0.31432371180119556 119:-0.34375:8161:8170 250:0.6328125:8162:8165 "
    s .= "104:-0.40625:8163:8164 ~-0.09323958312547245 ~0.005186678554016302 112:-0.109375:8166:8169 34:0.171875:8167:8168 ~-0.015342507203796096 ~-0.19255364880124912 ~0.013162035152048591 ~-0.017307621671267138 "
    s .= "73:0.265625:8172:8173 ~-0.04238268115335583 ~0.02163629055629214 220:-0.265625:8175:8176 ~-0.04293545479023469 ~0.027439464396953512 ~-0.02478269939252077 ~-0.06157478495665517 254:0.984375:8180:8207 "
    s .= "245:1.1129032258064515:8181:8182 ~-0.03731093743840266 256:0:8183:8198 11:0.78125:8184:8197 233:0.078125:8185:8192 49:0.65625:8186:8191 108:0.1796875:8187:8188 ~0.0076650232290006535 115:0.84375:8189:8190 "
    s .= "~-0.032079454882620276 ~0.03980803326377306 ~-0.03247178685703366 36:0.5625:8193:8196 124:0.828125:8194:8195 ~-0.005382485762602951 ~-0.050405352382083324 ~-0.0585293684275798 ~0.07296015385771058 14:0.421875:8199:8206 "
    s .= "54:-0.1171875:8200:8201 ~-0.03671884176213216 247:0.921875:8202:8205 203:0.59375:8203:8204 ~0.03396696242673785 ~-0.010572435046932985 ~-0.046381586489467226 ~-0.02700947933046746 159:0.2578125:8208:8225 "
    s .= "253:-0.042911505141282065:8209:8210 ~0.011061334878453954 190:0:8211:8216 172:0.4375:8212:8215 255:0.265625:8213:8214 ~0.001351442878602829 ~-0.05772908356097908 ~0.010905474547551308 122:-0.203125:8217:8224 "
    s .= "158:-0.28125:8218:8221 133:1.171875:8219:8220 ~-0.03921198001006824 ~0.011530581960667733 121:-0.15625:8222:8223 ~-0.0436726055464958 ~0.03972135507286433 ~-0.03601151974612726 ~-0.041422151045551955 "
    s .= "127:0.1875:8227:8248 109:0.375:8228:8235 244:1.115:8229:8232 100:0.390625:8230:8231 ~-0.0005971597216789075 ~0.07742607038781221 76:0.203125:8233:8234 ~-0.03706813787270172 ~0.00903761571739768 242:0.25:8236:8239 "
    s .= "124:0.0625:8237:8238 ~-0.05314239236218037 ~0.0283263000153157 112:0.015625:8240:8245 157:0.65625:8241:8242 ~0.015494144621484449 139:0.28125:8243:8244 ~-0.015075186220169873 ~-0.09343207040475361 "
    s .= "160:-0.203125:8246:8247 ~-0.030016658267570162 ~0.01861663580464743 244:1.585:8249:8262 145:-0.09375:8250:8251 ~-0.03404669451121308 190:-0.125:8252:8253 ~-0.028323066053334997 160:0.5:8254:8259 139:0.46875:8255:8258 "
    s .= "118:-0.109375:8256:8257 ~-0.04433383768499432 ~0.006470164283508044 ~0.0292285241044913 251:0.984375:8260:8261 ~-0.024192174313583198 ~0.00998250568095817 244:2.79:8263:8266 133:0.8125:8264:8265 ~-0.020897312978652764 "
    s .= "~0.02430605383100741 36:0.015625:8267:8272 247:-0.328125:8268:8271 238:1.171875:8269:8270 ~0.012715854123318552 ~-0.10578518961716109 ~-0.09141272338001151 ~0.032855828818423964 254:1.359375:8274:8315 77:0.625:8275:8314 "
    s .= "256:0:8276:8305 184:0.03125:8277:8294 8:0.4375:8278:8293 119:0.15625:8279:8292 106:0.59375:8280:8287 64:0.578125:8281:8286 133:1.34375:8282:8285 163:1.109375:8283:8284 ~-0.024854622378391505 ~0.048393966558942396 "
    s .= "~-0.05455732015032682 ~0.03922762884997464 187:0.015625:8288:8291 211:0.25:8289:8290 ~-0.00243743095042598 ~-0.0871121716119921 ~0.026334250632170382 ~-0.0460721925343295 ~0.04275742240486417 242:0.55:8295:8296 "
    s .= "~0.010914887276783598 245:1.5816326530612246:8297:8300 196:-0.609375:8298:8299 ~0.12431662082256241 ~-0.053077585851533694 251:0.359375:8301:8304 255:0.078125:8302:8303 ~-0.05970017515101905 ~-0.010718511441528515 "
    s .= "~0.008856251202696248 54:-0.1015625:8306:8307 ~-0.03936839862422767 71:0.46875:8308:8313 20:0.59375:8309:8312 245:1.1129032258064515:8310:8311 ~-0.03746636414630293 ~0.03208105805108689 ~-0.07475669135345103 "
    s .= "~-0.011069193513959328 ~-0.021008374625464548 98:-0.203125:8316:8319 169:-0.109375:8317:8318 ~-0.045562452453674206 ~0.0008528496329889943 ~-0.05250984184336097 110:-1:8321:8326 43:0.375:8322:8325 212:-0.5625:8323:8324 "
    s .= "~0.004388385103950047 ~-0.032657381347665514 ~-0.05176994640934728 62:-1.015625:8327:8328 ~0.030915640687081726 130:2.453125:8329:8366 195:-0.40625:8330:8331 ~-0.025991751974661827 146:-0.265625:8332:8341 "
    s .= "190:-0.015625:8333:8338 239:-0.28125:8334:8337 28:-0.03125:8335:8336 ~0.013983739412778962 ~-0.03740805203862255 ~0.014455729294868158 115:-0.109375:8339:8340 ~-0.02064139022641266 ~0.018089572021773644 "
    s .= "255:0.265625:8342:8357 255:0.140625:8343:8348 159:0.6796875:8344:8347 244:0.945:8345:8346 ~-0.028339407091604898 ~-0.0020294051269328503 ~0.046780374093928156 245:1.9107142857142858:8349:8350 ~0.03384099351162336 "
    s .= "242:0.75:8351:8356 173:-0.015625:8352:8353 ~0.007206099423478114 230:-0.359375:8354:8355 ~0.06197469294448388 ~-0.058356881161258534 ~0.027181558668061236 254:0.546875:8358:8359 ~0.013059512352208556 "
    s .= "250:1.0703125:8360:8361 ~-0.04002828752237894 59:-0.046875:8362:8365 257:0.30434782608695654:8363:8364 ~-0.013409702852753344 ~-0.10173409557772561 ~0.022542351254982163 ~-0.042156729471429934 191:0.796875:8368:8413 "
    s .= "246:1.796875:8369:8412 8:0.859375:8370:8411 247:0.796875:8371:8410 124:-0.65625:8372:8373 ~-0.046537208128191634 245:3.459016393442623:8374:8409 244:1.64:8375:8402 130:0.171875:8376:8381 76:-0.15625:8377:8378 "
    s .= "~-0.02339509733120468 44:0.453125:8379:8380 ~0.025275929039157083 ~-0.03293764875627478 34:0.046875:8382:8391 134:-0.9375:8383:8384 ~-0.02531248087235636 212:-0.21875:8385:8386 ~0.01672784657750458 94:0.0625:8387:8390 "
    s .= "144:0.0625:8388:8389 ~-0.0424518013320171 ~-0.003472833651732831 ~0.011668589961000253 111:0.6328125:8392:8401 124:0:8393:8396 124:-0.53125:8394:8395 ~0.04923261697550249 ~-0.04392072231796342 40:0:8397:8398 "
    s .= "~-0.036049738386812795 232:0.4375:8399:8400 ~0.0005883111741006005 ~-0.04023431153264979 ~0.08145599340394087 79:0.171875:8403:8408 118:-0.046875:8404:8405 ~0.02660300468313545 181:0.109375:8406:8407 "
    s .= "~-0.048114383611326056 ~-0.001154905165597404 ~0.024339702501610955 ~-0.025882839076019227 ~-0.05276248893484769 ~0.04383146264378898 ~0.037244740816868675 ~-0.03703065309153441 5:-1.484375:8415:8416 "
    s .= "~0.030084021078638203 110:-1.125:8417:8418 ~-0.016121035967630353 133:2.078125:8419:8458 98:-1:8420:8423 95:-1.015625:8421:8422 ~0.04826743111379882 ~0.0007932696710230517 255:0.265625:8424:8441 255:0.109375:8425:8432 "
    s .= "246:1.828125:8426:8431 245:1.3571428571428572:8427:8430 132:0.3203125:8428:8429 ~-0.05023505071496584 ~0.03251345062602377 ~0.0002588850381902642 ~0.043875010183998205 219:0.140625:8433:8440 203:0.09375:8434:8437 "
    s .= "196:-0.140625:8435:8436 ~-0.03586326908054456 ~0.024150993384207495 245:1.7448979591836735:8438:8439 ~0.027762706907512175 ~-0.03177318151552656 ~0.02663861490945842 244:0.91:8442:8443 ~-0.037669588856869586 "
    s .= "247:0.203125:8444:8453 4:0.34375:8445:8452 226:0.671875:8446:8451 245:1.6142857142857143:8447:8448 ~-0.04476576020969552 106:0.046875:8449:8450 ~-0.030902062046200385 ~0.010234437557207125 ~0.038294816347382604 "
    s .= "~-0.03373136142956633 250:1.1484375:8454:8457 119:-0.578125:8455:8456 ~0.018698853053835864 ~-0.05323005091833896 ~0.02417501568671445 255:0.359375:8459:8460 ~-0.04268407727959291 ~0.003400266492410396 "
    s .= "251:1.140625:8462:8485 247:0.515625:8463:8476 249:1.8333333333333335:8464:8475 243:1.45:8465:8470 254:1.359375:8466:8469 58:-0.578125:8467:8468 ~0.04903960990928313 ~0.003080084534526321 ~-0.020187528940299255 "
    s .= "58:0.59375:8471:8472 ~-0.045727655104604414 37:-0.203125:8473:8474 ~-0.060075293210329145 ~0.029113541625899714 ~-0.03787229237280767 250:1.1796875:8477:8480 217:0.578125:8478:8479 ~-0.05891704392974071 "
    s .= "~0.022320064241148317 1:0.328125:8481:8482 ~-0.00921460313636007 106:0.65625:8483:8484 ~0.16776868731860503 ~-0.022514428882904162 241:0.56:8486:8505 160:0.765625:8487:8502 214:0.671875:8488:8501 79:0:8489:8494 "
    s .= "53:-0.0625:8490:8493 109:1.703125:8491:8492 ~0.030721013906364333 ~-0.07345686554516227 ~-0.049081434446497284 160:0.25:8495:8498 139:0.171875:8496:8497 ~-0.04685483266497997 ~0.012859815761435633 118:0.140625:8499:8500 "
    s .= "~-0.09787837774875573 ~-0.0305931260831154 ~0.02916465536507601 181:0.0625:8503:8504 ~-0.035077703915765916 ~0.03018976462218922 19:0.421875:8506:8507 ~0.025523277226736737 ~-0.030690863038782934 "
    s .= "253:-0.07269338303821087:8509:8526 252:0.175:8510:8515 19:0.0625:8511:8514 235:-0.140625:8512:8513 ~-0.03887022495472965 ~0.012148909976524487 ~-0.03760638071867422 34:-0.359375:8516:8517 ~-0.02883129707513149 "
    s .= "211:0.34375:8518:8521 153:0.6796875:8519:8520 ~0.03379349249743422 ~-0.047104748667515836 147:-0.15625:8522:8523 ~0.03501808484100111 78:0.0859375:8524:8525 ~-0.061081098136842996 ~0.024108384733554585 "
    s .= "254:0.984375:8527:8550 248:0.125:8528:8539 251:1.296875:8529:8534 189:-0.03125:8530:8533 243:1.45:8531:8532 ~0.007709436806750032 ~-0.06380266029320031 ~-0.027561233423423544 241:0.5:8535:8538 22:-0.359375:8536:8537 "
    s .= "~0.03862363296224722 ~-0.057708763522265144 ~0.030909052351688057 253:-0.02499999999999858:8540:8543 252:0.475:8541:8542 ~-0.03599581444926702 ~0.0049002987825344894 249:1.8333333333333335:8544:8549 101:0.5625:8545:8548 "
    s .= "244:2.79:8546:8547 ~0.014427692945306894 ~-0.03997792821417786 ~-0.026466419091007894 ~-0.03607733882868984 190:0:8551:8552 ~-0.030387222466971838 88:-0.125:8553:8554 ~-0.04976590525328067 ~0.00032486034975637507 "
    s .= "148:0.203125:8556:8585 130:2.265625:8557:8584 96:0.6640625:8558:8583 255:-0.140625:8559:8562 257:0.07894736842105263:8560:8561 ~-0.057341699900268994 ~0.07977718373447396 91:1.171875:8563:8580 76:0.828125:8564:8579 "
    s .= "242:0.25:8565:8568 169:0.15625:8566:8567 ~-0.04852799823379723 ~0.03514319622353389 205:0.59375:8569:8574 169:1.6875:8570:8573 130:0.09375:8571:8572 ~0.013926033416915007 ~-0.006466273350248234 ~0.06672291127026729 "
    s .= "55:0.1875:8575:8578 130:0.03125:8576:8577 ~-0.0401389267698901 ~0.03402232161985098 ~-0.04271171043609287 ~0.024104226022121224 124:-0.15625:8581:8582 ~-0.038970583834831485 ~0.03442522115120923 ~-0.0264197014448955 "
    s .= "~-0.040221314845424426 121:-0.28125:8586:8587 ~-0.045500039099432454 198:-0.59375:8588:8589 ~-0.04541302939438998 98:-0.71875:8590:8593 160:1.4375:8591:8592 ~0.0063657335557551036 ~0.0536201930762788 "
    s .= "137:-0.171875:8594:8597 34:-0.078125:8595:8596 ~0.00868679624761732 ~-0.03640773979960679 22:-0.265625:8598:8599 ~-0.0345804299794394 44:0.3125:8600:8601 ~0.012016174341864267 ~-0.02257396893557695 "
    s .= "251:0.203125:8603:8610 31:0.078125:8604:8609 106:0.109375:8605:8606 ~-0.03011422979720257 243:0.45:8607:8608 ~0.03542370290594287 ~-0.01654394307553079 ~-0.03767245614729164 175:0.234375:8611:8638 79:0.25:8612:8635 "
    s .= "205:0.140625:8613:8632 109:1.40625:8614:8629 64:0.359375:8615:8628 70:0.53125:8616:8627 243:0.6499999999999999:8617:8626 133:0.484375:8618:8621 31:0.3125:8619:8620 ~-0.00021580492311186656 ~0.12623275673798892 "
    s .= "28:-0.171875:8622:8625 139:0.421875:8623:8624 ~-0.035306488590816414 ~0.05796526819336171 ~-0.04098025923765223 ~0.009595880865409906 ~0.04197666740625826 ~0.026490216861409822 79:-0.078125:8630:8631 "
    s .= "~-0.0011522085718508512 ~-0.05746774233160817 73:0.109375:8633:8634 ~0.02280203220568776 ~-0.024996874463351457 4:-0.140625:8636:8637 ~-0.006263617920388125 ~0.020972737357994164 193:-0.078125:8639:8640 "
    s .= "~-0.02886182587216431 175:0.578125:8641:8648 250:1.2734375:8642:8647 151:0.046875:8643:8644 ~0.026746578382624276 1:-0.328125:8645:8646 ~0.012382428562870968 ~-0.03386176901280617 ~0.013350341727690791 "
    s .= "~0.012511842540869317 242:2.25:8650:8693 252:1.875:8651:8690 243:1.45:8652:8687 245:2.2:8653:8676 211:0.203125:8654:8667 202:0.25:8655:8662 241:0.58:8656:8661 100:0.375:8657:8658 ~0.003259712141159868 "
    s .= "85:-0.265625:8659:8660 ~0.10389890436146652 ~0.023133094114891242 ~0.03257664483655919 157:0.640625:8663:8664 ~-0.02437110844750152 37:0.234375:8665:8666 ~0.02286277857310466 ~-0.06271001841097881 242:0.55:8668:8673 "
    s .= "244:1.315:8669:8672 184:-0.015625:8670:8671 ~-0.08443611686290765 ~-0.0008555688746899588 ~0.0312366506545974 91:0.046875:8674:8675 ~-0.05136814033557072 ~-0.00797636530583625 191:0:8677:8686 243:0.75:8678:8681 "
    s .= "242:0.55:8679:8680 ~0.002832370993656593 ~-0.034431299126155605 55:-0.09375:8682:8685 13:-0.1875:8683:8684 ~0.01450951950754546 ~-0.0738281953593994 ~0.02890585412883679 ~-0.025621445657864506 73:0.265625:8688:8689 "
    s .= "~-0.041066789382668605 ~0.020471618813062822 220:-0.265625:8691:8692 ~-0.04159906977216456 ~0.026088898070091317 130:0.953125:8694:8695 ~-0.04767949760881093 ~0.012123411070682199 243:2.05:8697:8736 "
    s .= "245:4.744186046511628:8698:8735 257:0.30434782608695654:8699:8726 257:0.037037037037037035:8700:8723 193:-0.25:8701:8704 189:0.28125:8702:8703 ~-0.03916162239479373 ~0.01856678007335794 252:0.42500000000000004:8705:8718 "
    s .= "190:0.03125:8706:8715 25:0.375:8707:8712 244:1.145:8708:8709 ~-0.0011886558908511995 181:0.09375:8710:8711 ~-0.05259061829344345 ~-0.008722872791353628 4:1.015625:8713:8714 ~0.03902260136268983 ~-0.051775094895626796 "
    s .= "124:0.984375:8716:8717 ~0.006831399998802917 ~-0.05419440952023019 253:-0.006628787878785403:8719:8720 ~0.0261107609556892 108:0.0390625:8721:8722 ~-0.04622487242942817 ~0.008442409878429107 174:-0.390625:8724:8725 "
    s .= "~-0.020754243364662844 ~0.02080073281514827 114:-0.2109375:8727:8730 136:0.1875:8728:8729 ~0.03437585886803812 ~-0.005407354695870682 255:0.015625:8731:8732 ~0.00006760682972187908 59:0.34375:8733:8734 "
    s .= "~-0.05593049985075991 ~0.041762977674492115 ~-0.07577388077462575 196:-0.609375:8737:8738 ~0.06147256325611074 245:2.3137254901960786:8739:8740 ~-0.05107038873228919 37:-0.28125:8741:8742 ~-0.07846378245828994 "
    s .= "~0.025511291742480326 218:0.65625:8744:8789 246:0.203125:8745:8756 203:0.125:8746:8753 255:-0.140625:8747:8748 ~0.05356302473256776 238:0.578125:8749:8752 66:0.328125:8750:8751 ~0.0032729621499819556 "
    s .= "~-0.021777923090926337 ~-0.021859532657657447 47:0.375:8754:8755 ~-0.03988468420310698 ~0.020538425100096343 250:1.1171875:8757:8772 159:0.2265625:8758:8767 50:0.015625:8759:8762 121:-0.15625:8760:8761 "
    s .= "~-0.03589516318009985 ~0.023186342217509686 249:0.5:8763:8766 67:0.1875:8764:8765 ~0.01741888436894361 ~-0.035318561688032254 ~-0.0450284414907073 251:1.359375:8768:8771 255:0.015625:8769:8770 ~0.04553588528218224 "
    s .= "~-0.049725772043890115 ~0.02046108676241764 111:0.3515625:8773:8788 24:0.078125:8774:8775 ~0.03347041726881625 245:1.596774193548387:8776:8781 254:0.546875:8777:8780 246:1.640625:8778:8779 ~-0.05720368745452134 "
    s .= "~0.020123610242308493 ~0.038149161737201676 23:1:8782:8787 161:0.46875:8783:8784 ~0.023250407165765277 241:0.44:8785:8786 ~-0.0626119517571344 ~0.021225859551574827 ~0.18410427350824204 ~0.04495699230974848 "
    s .= "~-0.03104738374589279 253:-0.09764309764309784:8791:8806 252:0.125:8792:8801 33:-0.171875:8793:8796 106:1.21875:8794:8795 ~-0.09750090679806729 ~0.020228737488827753 146:0.109375:8797:8798 ~0.014242158283483889 "
    s .= "249:0.16666666666666666:8799:8800 ~0.012238514988545324 ~-0.08316810158757955 187:0.28125:8802:8805 153:0.6796875:8803:8804 ~0.034171265669707164 ~-0.06281727167094493 ~-0.0029414343496342865 195:-0.34375:8807:8812 "
    s .= "160:1.453125:8808:8811 26:-0.78125:8809:8810 ~-0.006468880866482148 ~-0.043460781250904794 ~0.03113727852131137 57:-0.6171875:8813:8814 ~0.03936143139246731 133:1.625:8815:8828 127:0.140625:8816:8825 243:1.45:8817:8824 "
    s .= "22:-0.046875:8818:8821 250:1.3359375:8819:8820 ~0.030818147740415663 ~-0.017639435285842074 109:1.859375:8822:8823 ~0.005377813553825817 ~-0.05989983446722577 ~-0.022955239607789654 220:-0.296875:8826:8827 "
    s .= "~-0.03806568513934162 ~-0.0022409208918217544 181:0.015625:8829:8832 252:1.1749999999999998:8830:8831 ~-0.05688650192206085 ~0.006759640935378956 223:0.03125:8833:8836 103:1.765625:8834:8835 ~-0.009076453715274794 "
    s .= "~-0.08433297536965456 ~0.008697782170312982 72:1.078125:8838:8883 11:0.90625:8839:8880 247:0.953125:8840:8879 246:1.890625:8841:8878 74:-0.140625:8842:8871 246:-0.578125:8843:8862 122:-0.65625:8844:8855 "
    s .= "251:0.890625:8845:8854 95:-0.609375:8846:8853 254:0.484375:8847:8850 153:-0.5546875:8848:8849 ~-0.016961813117661186 ~0.03895223056586838 109:1.328125:8851:8852 ~-0.02936960750111761 ~0.023075485514389905 "
    s .= "~-0.03460311776162428 ~0.02083926970399266 66:0.0625:8856:8861 249:0.5:8857:8858 ~0.002305471964543426 240:0.1875:8859:8860 ~-0.04658262624911359 ~0.037555716233184336 ~-0.044023826053485204 191:0.09375:8863:8868 "
    s .= "230:-0.03125:8864:8867 109:0.5625:8865:8866 ~-0.005297848139609179 ~0.02024010826950268 ~0.03804828993070758 63:-0.015625:8869:8870 ~0.025155774444324243 ~-0.018908329520041747 249:0.16666666666666666:8872:8875 "
    s .= "31:0.046875:8873:8874 ~0.011111484995899593 ~-0.010877669584151789 126:0.1875:8876:8877 ~-0.021407824362147845 ~0.006219413012112483 ~0.054767462184039106 ~-0.057483095769000514 104:0.671875:8881:8882 "
    s .= "~0.07779817918938958 ~-0.026420855988919512 ~-0.05894050629527985 110:-1:8885:8894 43:0.375:8886:8893 212:-0.5625:8887:8892 244:1.395:8888:8891 26:-0.8125:8889:8890 ~0.0029662295111236338 ~-0.046960351727789056 "
    s .= "~0.020641027956446997 ~-0.03042369156143392 ~-0.04952326718195793 98:-1.046875:8895:8898 119:-0.640625:8896:8897 ~0.043589488635686645 ~-0.04150612034884625 255:0.234375:8899:8914 255:0.140625:8900:8905 "
    s .= "109:0.515625:8901:8904 82:-0.40625:8902:8903 ~0.04816464554602692 ~-0.014344055601763646 ~0.00459672435748499 219:0.140625:8906:8913 226:-0.15625:8907:8908 ~-0.04727501787746549 200:0.140625:8909:8910 "
    s .= "~0.025221645629634838 242:0.55:8911:8912 ~-0.05323931358071084 ~0.014579381208957673 ~0.03199402893465158 244:0.935:8915:8916 ~-0.03288918563326583 16:0.234375:8917:8928 254:0.546875:8918:8919 ~0.01523316800699928 "
    s .= "50:-0.34375:8920:8927 28:0:8921:8924 143:0.0625:8922:8923 ~0.018247250814125468 ~-0.053180072605255535 110:-0.25:8925:8926 ~-0.04276288355819539 ~0.012700300013513428 ~-0.026906280870581268 16:0.734375:8929:8930 "
    s .= "~0.02625907670636446 ~-0.0365988465883583 184:2.3125:8932:8977 151:0.140625:8933:8942 242:0.25:8934:8937 16:0.484375:8935:8936 ~-0.051971674523198 ~0.032131440334897246 250:1.4765625:8938:8941 254:0.984375:8939:8940 "
    s .= "~0.012616785234792056 ~-0.005240144767758922 ~-0.015164976647202398 244:1.015:8943:8954 103:0.1875:8944:8947 23:-0.28125:8945:8946 ~0.03234237172209495 ~-0.019776821279199025 166:0.171875:8948:8953 148:0:8949:8950 "
    s .= "~0.03495502280282199 196:0.78125:8951:8952 ~-0.04151820494328234 ~0.040855377405489626 ~-0.05042259289445036 247:0.765625:8955:8976 126:0.3125:8956:8975 106:0.046875:8957:8960 245:1.8852459016393444:8958:8959 "
    s .= "~0.020152467286752195 ~-0.046028549869240966 214:0:8961:8964 244:1.16:8962:8963 ~0.017691987006855356 ~-0.024808570781237372 118:0.015625:8965:8968 6:-0.03125:8966:8967 ~-0.0469927863893827 ~0.003580995865679638 "
    s .= "70:0.578125:8969:8974 122:-0.421875:8970:8971 ~0.03435086922400484 86:-0.265625:8972:8973 ~-0.02265202671130169 ~0.01932638865634402 ~-0.029776531122512613 ~0.02331851999415992 ~-0.061949890073386575 "
    s .= "~-0.04438337918631145 191:0.796875:8979:9024 256:0:8980:9019 11:0.71875:8981:9018 247:0.203125:8982:9009 106:0.046875:8983:8988 181:0.109375:8984:8987 1:0.28125:8985:8986 ~-0.045424533883994124 ~0.02751448823101026 "
    s .= "~0.003479706789007732 7:0.90625:8989:9006 217:0.1875:8990:8999 106:1.828125:8991:8992 ~0.01094710500554897 167:-0.6875:8993:8994 ~0.03246639745872538 223:0.09375:8995:8996 ~-0.052390470983612984 241:0.88:8997:8998 "
    s .= "~0.028875578754199112 ~-0.096841655609952 250:0.8046875:9000:9001 ~-0.04150455044654723 245:1.8214285714285714:9002:9005 226:0.765625:9003:9004 ~-0.03371326970771429 ~0.04167328829263893 ~0.009967436337619335 "
    s .= "63:-0.359375:9007:9008 ~0.013703466556526336 ~-0.05134026940151899 130:0.109375:9010:9011 ~0.020806066012144905 217:0.375:9012:9017 123:0.40625:9013:9014 ~-0.04565756031204686 165:0.15625:9015:9016 ~-0.07115673203439339 "
    s .= "~0.011049830372910062 ~0.019150556202930935 ~0.06521848502207156 77:0.578125:9020:9023 54:-0.1015625:9021:9022 ~-0.03228365550832205 ~0.022237111124973608 ~-0.02372889852292781 ~-0.0348989368352187 110:-1:9026:9037 "
    s .= "43:0.375:9027:9036 88:1.4375:9028:9035 115:0.390625:9029:9034 212:-0.5625:9030:9033 208:-0.0625:9031:9032 ~-0.033304768773891484 ~0.02382953500978617 ~-0.03384442481193791 ~-0.03585671008377214 ~0.02349522129805464 "
    s .= "~-0.04784493609401684 98:-1.046875:9038:9041 119:-0.640625:9039:9040 ~0.04235132399876398 ~-0.040322477386002614 205:-0.296875:9042:9045 133:0.375:9043:9044 ~0.012728849524761936 ~-0.03090547785575012 "
    s .= "211:0.1875:9046:9063 79:0.28125:9047:9062 64:0.703125:9048:9061 244:1.11:9049:9050 ~0.009078318610433747 181:0.0625:9051:9056 61:0.71875:9052:9055 235:-0.28125:9053:9054 ~0.02592900431764891 ~-0.05062424712590868 "
    s .= "~0.030895469797113818 76:0.015625:9057:9058 ~0.014896300791568954 124:0.03125:9059:9060 ~-0.06380583785826263 ~0.00005576418435471924 ~0.028522321609747072 ~0.014788213259575828 136:1.09375:9064:9067 "
    s .= "55:0.078125:9065:9066 ~-0.0010469662433268453 ~-0.028515248816012768 127:1.078125:9068:9071 181:-0.046875:9069:9070 ~-0.044500291590471294 ~0.03160167095528413 ~-0.019385452926440068 219:0.953125:9073:9118 "
    s .= "201:0.75:9074:9117 244:0.78:9075:9078 251:0.828125:9076:9077 ~-0.040302345444425756 ~0.023299766162296728 93:0.703125:9079:9114 159:0.3359375:9080:9109 256:0:9081:9104 11:0.71875:9082:9103 170:0.09375:9083:9094 "
    s .= "247:0.265625:9084:9091 141:0.0703125:9085:9088 49:0.625:9086:9087 ~0.002348401203651363 ~-0.031083519314110672 253:-0.06679035250463854:9089:9090 ~0.03833945278998309 ~0.008420657274640853 221:0.203125:9092:9093 "
    s .= "~-0.03751305000886269 ~0.050602109346304894 234:0.4375:9095:9102 14:0.40625:9096:9099 227:0.046875:9097:9098 ~0.014140649904152659 ~-0.02382731805876214 24:0.09375:9100:9101 ~0.04799201758320809 ~-0.021602750764550774 "
    s .= "~-0.07440296088318565 ~0.0662846446895358 38:0.59375:9105:9108 180:-0.109375:9106:9107 ~-0.035371040512266166 ~0.027935929860627148 ~-0.03933247290345054 250:1.1796875:9110:9113 130:0.296875:9111:9112 "
    s .= "~0.012186767774881016 ~-0.04977677683279333 ~0.011548043053980986 237:0.5625:9115:9116 ~-0.05096769722567232 ~0.02352953449429533 ~0.02715973004271508 ~-0.04528446193587889 224:0.625:9120:9165 246:0.203125:9121:9148 "
    s .= "203:0.125:9122:9145 255:-0.140625:9123:9124 ~0.05245672382096486 247:-0.015625:9125:9142 110:-0.984375:9126:9127 ~-0.011493412725443197 125:-0.828125:9128:9129 ~0.026170340543221423 244:0.92:9130:9133 241:4.04:9131:9132 "
    s .= "~-0.04077609653165788 ~0.04980629338328829 130:2.078125:9134:9141 57:-0.1015625:9135:9140 106:0.71875:9136:9137 ~-0.01675053193960858 238:1.171875:9138:9139 ~0.01693795219290224 ~-0.07388005143843315 "
    s .= "~0.016831487263644366 ~-0.03602352215343942 31:-0.453125:9143:9144 ~0.03430367378154005 ~-0.017582402035807486 47:0.375:9146:9147 ~-0.03772088943563779 ~0.0206989860291769 250:1.1171875:9149:9164 159:0.2265625:9150:9159 "
    s .= "168:0.03125:9151:9156 109:0.453125:9152:9153 ~-0.04968992554747753 79:-0.0625:9154:9155 ~-0.06550722598129881 ~0.007849781574675637 236:0.296875:9157:9158 ~0.029401880538825267 ~-0.0181263253432122 "
    s .= "255:0.015625:9160:9161 ~0.044178581036215414 251:1.359375:9162:9163 ~-0.04744038262205161 ~0.013844776640762037 ~0.017229357828269433 ~-0.02452032064807204 5:-1.484375:9167:9168 ~0.028367904020002013 "
    s .= "195:-0.34375:9169:9174 160:1.453125:9170:9171 ~-0.02237431230101053 208:-0.0625:9172:9173 ~-0.04656784863958072 ~0.04478344144228164 57:-0.6328125:9175:9176 ~0.03603208582490069 133:1.625:9177:9206 "
    s .= "166:-0.328125:9178:9181 255:-0.140625:9179:9180 ~0.14325856600667952 ~-0.025194308154081937 211:0.1875:9182:9189 109:1.859375:9183:9188 76:0.5625:9184:9187 209:0.5625:9185:9186 ~0.008301509209255556 "
    s .= "~-0.035003398256320484 ~0.03091042090522543 ~-0.04064486545740042 136:1.09375:9190:9201 243:0.25:9191:9194 91:0.15625:9192:9193 ~-0.03639079767204686 ~0.05788141150082739 244:1.095:9195:9198 220:0.875:9196:9197 "
    s .= "~-0.0450430803091458 ~0.0374804860269505 245:1.8405797101449275:9199:9200 ~0.016828372639969797 ~-0.018499075298998486 184:-0.078125:9202:9203 ~-0.07268481836610223 124:0.984375:9204:9205 ~0.036028737706291086 "
    s .= "~-0.03726612607919717 223:0.03125:9207:9210 4:0.171875:9208:9209 ~-0.04112123319148518 ~0.018929306203227168 181:0.015625:9211:9212 ~-0.039402262823321356 ~0.01065281085264183 217:0.21875:9214:9241 208:-0.3125:9215:9216 "
    s .= "~-0.018479533425036297 85:0.640625:9217:9222 82:-0.109375:9218:9219 ~0.01869617151761911 43:-0.046875:9220:9221 ~-0.020698695070315003 ~0.0012505349821924528 178:0.328125:9223:9228 252:0.025:9224:9227 "
    s .= "84:-0.2109375:9225:9226 ~0.0336092998981755 ~-0.024164637644047225 ~0.024952461052318044 94:0.328125:9229:9238 235:-0.015625:9230:9237 242:0.35:9231:9234 127:-0.0625:9232:9233 ~0.02009212443464798 ~-0.11964174724083401 "
    s .= "72:0.0625:9235:9236 ~-0.034061453221935954 ~0.032352059837519064 ~0.02083653389239741 99:0.15625:9239:9240 ~-0.05647582868109407 ~0.023580594106029654 163:0.328125:9242:9249 115:0.140625:9243:9246 235:0.078125:9244:9245 "
    s .= "~0.004583071954606024 ~-0.04008409240750189 243:0.25:9247:9248 ~0.07315544311106824 ~0.011021880775923122 52:-0.5625:9250:9251 ~0.042771944965959575 79:0.25:9252:9253 ~-0.048508111253733846 251:1.640625:9254:9259 "
    s .= "130:0.796875:9255:9256 ~-0.04909362948323808 55:-0.125:9257:9258 ~-0.10759454886017748 ~0.005266728834950442 ~0.023429136852541443 242:2.25:9261:9304 252:1.875:9262:9301 243:1.45:9263:9298 245:2.2:9264:9269 "
    s .= "140:-1.140625:9265:9266 ~-0.02285020150565238 249:1.5:9267:9268 ~0.007296586272380357 ~-0.025973336150190957 191:0:9270:9293 243:0.75:9271:9288 242:0.55:9272:9283 56:-0.046875:9273:9280 250:0.8046875:9274:9277 "
    s .= "206:-0.015625:9275:9276 ~-0.047459170837228115 ~0.029377600445469717 181:0.0625:9278:9279 ~-0.02331603854208636 ~0.024751272781080226 245:2.5180722891566263:9281:9282 ~-0.03284720020077714 ~0.04898151143317944 "
    s .= "163:0.5625:9284:9285 ~-0.04754657778934266 238:-0.078125:9286:9287 ~-0.10073463352906414 ~0.016261189269739844 242:0.35:9289:9292 210:-0.3125:9290:9291 ~0.039146093135382753 ~-0.10883772050497581 ~0.02043550394208585 "
    s .= "130:0.59375:9294:9297 118:0.015625:9295:9296 ~-0.04001464462288574 ~0.01576692639847303 ~-0.04064628845978421 73:0.265625:9299:9300 ~-0.03939927347480299 ~0.019671301526386898 220:-0.265625:9302:9303 "
    s .= "~-0.03874741597205228 ~0.02493009545741874 245:2.526315789473684:9305:9306 ~-0.0426178590201995 ~0.015526879990574777 253:-0.07269338303821087:9308:9339 252:0.175:9309:9328 19:0.0625:9310:9319 235:-0.140625:9311:9314 "
    s .= "76:0.375:9312:9313 ~-0.060210529090041424 ~0.023941252434768485 250:0.6328125:9315:9316 ~-0.06990220402663656 251:2.265625:9317:9318 ~0.017982152414616415 ~-0.15545624569554647 109:1.171875:9320:9323 "
    s .= "48:0.1796875:9321:9322 ~-0.08334856543195598 ~-0.0062320780762924926 186:0.375:9324:9327 115:0.609375:9325:9326 ~0.03670171599323678 ~-0.08508083500562867 ~-0.10101374098026282 34:-0.359375:9329:9330 "
    s .= "~-0.026053712043697316 211:0.34375:9331:9334 25:0.203125:9332:9333 ~0.0360029397991415 ~-0.0029279158047919402 147:-0.15625:9335:9336 ~0.03452635756511095 144:0.0625:9337:9338 ~-0.05902567373802632 ~0.020543873250105066 "
    s .= "254:0.984375:9340:9341 ~0.0003783504379888448 190:0:9342:9343 ~-0.02815747771193382 88:-0.125:9344:9345 ~-0.04764025098489875 169:-0.140625:9346:9347 ~-0.03867195466896874 29:-0.28125:9348:9353 158:-0.28125:9349:9352 "
    s .= "133:1.078125:9350:9351 ~-0.030936232668731037 ~0.016541918831885733 ~0.03377467658281016 ~-0.024210696527682894 243:2.05:9355:9394 245:4.744186046511628:9356:9393 257:0.30434782608695654:9357:9378 "
    s .= "257:0.037037037037037035:9358:9375 252:0.42500000000000004:9359:9370 184:0.046875:9360:9367 16:0.390625:9361:9366 127:0.078125:9362:9365 100:0.34375:9363:9364 ~-0.01353438970596485 ~0.03729703186653316 "
    s .= "~-0.03486108585856867 ~0.021082215862651733 242:1.15:9368:9369 ~0.005250306515939504 ~-0.051235608084433774 163:0.140625:9371:9372 ~0.026170755156460213 181:0.171875:9373:9374 ~0.021191069838955183 "
    s .= "~-0.018519352924853124 244:1.48:9376:9377 ~0.00041237277811375896 ~0.028945265955146345 125:-0.609375:9379:9384 110:-0.46875:9380:9383 133:0.921875:9381:9382 ~-0.023847928752811748 ~0.01345468598912123 "
    s .= "~0.05080961432225413 4:-0.09375:9385:9388 244:1.11:9386:9387 ~-0.05177365399600519 ~0.020800450996208 44:0.40625:9389:9392 82:1.8125:9390:9391 ~-0.03036339561465054 ~-0.11338706904383627 ~0.03899028191149954 "
    s .= "~-0.07046008405581233 196:-0.59375:9395:9396 ~0.05612838897602917 245:1.9833333333333334:9397:9398 ~-0.0589007018178125 37:-0.28125:9399:9400 ~-0.07812673958407443 ~0.010487014741926488 101:0.5625:9402:9443 "
    s .= "8:0.734375:9403:9440 256:0.01639344262295082:9404:9433 39:0.4375:9405:9430 106:0.046875:9406:9415 226:0.125:9407:9412 1:0.28125:9408:9411 33:0.359375:9409:9410 ~-0.041898355374795006 ~0.021920462946079952 "
    s .= "~0.02972935572540916 214:0.421875:9413:9414 ~0.020247588944162318 ~-0.047998106002572795 7:0.90625:9416:9425 247:0.265625:9417:9420 124:2.0625:9418:9419 ~0.00603669059859254 ~-0.0591720914903621 239:0.46875:9421:9424 "
    s .= "192:0.390625:9422:9423 ~-0.050960951301991055 ~0.004315923563024003 ~0.0405938492083835 6:-0.328125:9426:9429 135:-0.4921875:9427:9428 ~-0.02793516786182781 ~0.06449895049988418 ~-0.04264895491241851 "
    s .= "168:0.109375:9431:9432 ~-0.04780308379898246 ~0.0022149268082846466 14:0.578125:9434:9439 54:-0.1015625:9435:9436 ~-0.026250213215157317 245:1.1129032258064515:9437:9438 ~-0.04312261110289701 ~0.02416408981896581 "
    s .= "~-0.05293904848555564 243:0.45:9441:9442 ~0.08118569865454217 ~0.00028908111005825716 252:0.225:9444:9445 ~-0.042392674932771796 133:0.015625:9446:9447 ~0.05213290092759046 ~-0.0141822079193672 217:0.1875:9449:9476 "
    s .= "208:-0.3125:9450:9451 ~-0.018577092958408512 238:0.328125:9452:9473 76:0.4375:9453:9468 106:0.390625:9454:9465 160:0.703125:9455:9464 244:1.26:9456:9459 70:0.71875:9457:9458 ~-0.0062578192330173706 ~0.06439707411525393 "
    s .= "252:0.175:9460:9463 187:0.15625:9461:9462 ~-0.05940881120894555 ~-0.00528132242436256 ~0.010448883692589075 ~0.0190747061178019 88:-0.0625:9466:9467 ~0.028051668916262498 ~0.004953813888020351 67:0.1875:9469:9470 "
    s .= "~0.03169197683962272 52:0.203125:9471:9472 ~0.03286846174054968 ~-0.03049163620855229 136:0.828125:9474:9475 ~-0.03035038858584442 ~0.007160915625968394 163:0.34375:9477:9486 115:0.140625:9478:9483 "
    s .= "175:-0.109375:9479:9480 ~0.025054331637239552 106:1.15625:9481:9482 ~-0.04091104696564763 ~0.013238443948201421 196:0.140625:9484:9485 ~-0.022336061935801163 ~0.023193160251925055 19:-0.5625:9487:9488 "
    s .= "~0.0338376376971049 160:1.46875:9489:9492 244:2.98:9490:9491 ~-0.030469766303338676 ~-0.18278893273557298 63:0.0625:9493:9494 ~0.02652535821903031 ~-0.06711661323063081 33:0.984375:9496:9541 11:0.90625:9497:9538 "
    s .= "247:0.953125:9498:9537 246:1.796875:9499:9536 124:-0.65625:9500:9501 ~-0.04528191632463799 74:-0.140625:9502:9531 246:-0.578125:9503:9524 128:-0.453125:9504:9523 244:1.455:9505:9518 254:0.609375:9506:9513 "
    s .= "236:-0.21875:9507:9512 156:-0.5234375:9508:9511 151:0.1875:9509:9510 ~0.023406076144090092 ~-0.045424026316861627 ~0.02465961873011606 ~-0.04421544295312568 251:1.078125:9514:9517 98:-1.328125:9515:9516 "
    s .= "~0.012430286943750616 ~-0.04484787698319203 ~0.01287291071975829 250:0.8046875:9519:9522 199:-0.234375:9520:9521 ~0.05059502301004692 ~-0.03564366608586814 ~0.02704223387670454 ~-0.019846987215963636 "
    s .= "119:0.078125:9525:9530 110:0.046875:9526:9529 82:-0.125:9527:9528 ~0.0443239738097736 ~0.002465437257721593 ~0.029964925891695856 ~-0.004738631946061663 68:-0.53125:9532:9535 148:-0.421875:9533:9534 ~0.04536950523715015 "
    s .= "~-0.04376053539530983 ~-0.002952277968864271 ~0.042885950552737834 ~-0.05562154890319279 104:0.671875:9539:9540 ~0.07215591634147112 ~-0.022485136953211825 ~-0.051591421630272194 219:0.953125:9543:9588 "
    s .= "201:0.75:9544:9587 72:0.78125:9545:9586 247:0.796875:9546:9583 116:0.796875:9547:9582 245:1.3571428571428572:9548:9549 ~-0.02877371378527374 256:0.01639344262295082:9550:9577 11:0.71875:9551:9576 247:0.453125:9552:9575 "
    s .= "146:0.109375:9553:9566 238:0.578125:9554:9565 184:0.046875:9555:9560 187:0.03125:9556:9559 24:0.078125:9557:9558 ~-0.02272965485041398 ~0.006771011567358688 ~0.010130161408891312 181:0.171875:9561:9562 "
    s .= "~0.018277407056282724 52:0.203125:9563:9564 ~0.009319997023235802 ~-0.01616519441074632 ~-0.016722354109314105 86:0.125:9567:9568 ~-0.028882693863177124 3:0.078125:9569:9572 248:0.625:9570:9571 ~0.025227985764523925 "
    s .= "~-0.04087006848377263 95:0.234375:9573:9574 ~0.009074316726575915 ~-0.04415329569290269 ~-0.03309660541785024 ~0.05950852508987869 77:0.546875:9578:9581 54:-0.1015625:9579:9580 ~-0.025005637704117026 "
    s .= "~0.030514046360626892 ~-0.022970280382699867 ~0.02919210247744118 9:0.7109375:9584:9585 ~-0.051927340241335496 ~0.04520156719321035 ~-0.03579464560739976 ~0.02565334740920059 ~-0.0442739659395505 191:0.796875:9590:9635 "
    s .= "246:1.796875:9591:9634 11:0.90625:9592:9631 247:0.796875:9593:9628 175:-0.484375:9594:9597 245:1.4941176470588236:9595:9596 ~0.040081671344149486 ~-0.046270181062510574 88:1.28125:9598:9617 110:-1.1875:9599:9602 "
    s .= "189:-0.203125:9600:9601 ~-0.0078077602183208895 ~-0.05704331175880062 98:-1.046875:9603:9606 143:-0.5625:9604:9605 ~0.03647402777985855 ~-0.04697014109579427 103:1.328125:9607:9612 247:-0.953125:9608:9609 "
    s .= "~-0.034674692552767915 46:1.125:9610:9611 ~-0.0022854393878762066 ~0.03908308497887111 103:1.765625:9613:9614 ~0.028411841394267036 217:0.015625:9615:9616 ~-0.0386978850361525 ~0.018506722005826294 193:0:9618:9627 "
    s .= "175:0.34375:9619:9624 243:0.55:9620:9623 37:-0.03125:9621:9622 ~0.023021062660383555 ~-0.08539454855412129 ~0.026280815707904876 9:0.2421875:9625:9626 ~-0.046688886755507114 ~0.038659191177884085 ~0.024056557653789532 "
    s .= "189:0.671875:9629:9630 ~-0.05851942601910979 ~0.03949779938872827 15:0.7265625:9632:9633 ~0.07197767321669472 ~-0.043949991771667626 ~0.035188163986877144 ~-0.033891362612115394 254:1.296875:9637:9670 77:0.625:9638:9669 "
    s .= "8:0.625:9639:9668 246:1.671875:9640:9667 247:0.796875:9641:9666 191:-0.4375:9642:9657 190:0.421875:9643:9652 28:-0.015625:9644:9647 99:-0.171875:9645:9646 ~0.0022319951206480233 ~0.03550184590041002 166:0:9648:9651 "
    s .= "88:1.140625:9649:9650 ~-0.04100701629535039 ~0.023730306520720654 ~0.012109454086049486 50:-0.65625:9653:9656 21:0.2890625:9654:9655 ~0.024404921372281174 ~-0.06674686649629671 ~-0.02692303200611856 "
    s .= "246:-1.640625:9658:9659 ~-0.030866701096280053 133:1.921875:9660:9661 ~0.0015908586914123142 108:-0.3046875:9662:9663 ~0.03679160094333086 110:0.15625:9664:9665 ~-0.05308339027397231 ~0.0023121966625681096 "
    s .= "~-0.060824853532295255 ~0.03648755706994088 ~0.03381526678588797 ~-0.018690333966963003 98:-0.234375:9671:9682 169:-0.109375:9672:9673 ~-0.042813914434687184 246:-0.421875:9674:9679 122:-0.71875:9675:9676 "
    s .= "~0.007849461142728508 169:-0.015625:9677:9678 ~0.013106582343274381 ~-0.0639532666185663 221:-0.0625:9680:9681 ~0.031839066263322696 ~-0.050854793681433655 ~-0.04790588737561499 242:2.25:9684:9727 252:1.875:9685:9724 "
    s .= "243:1.45:9686:9721 245:2.2:9687:9716 202:0.25:9688:9711 211:0.21875:9689:9706 100:0.484375:9690:9703 241:0.42:9691:9702 205:0.34375:9692:9701 136:1.296875:9693:9700 106:0.6875:9694:9699 166:0.625:9695:9698 "
    s .= "37:0.28125:9696:9697 ~-0.019711121496395274 ~0.027714523502636607 ~0.059410998713106636 ~0.022059499915910205 ~-0.037685406134636716 ~0.03202024347910243 ~0.027248121160411604 85:-0.265625:9704:9705 ~0.09686331776744202 "
    s .= "~0.02397719600802473 55:-0.015625:9707:9708 ~0.015811488313064448 196:-0.046875:9709:9710 ~-0.05401478418242698 ~-0.007541832717785524 109:1.265625:9712:9715 67:-0.140625:9713:9714 ~-0.045289371876234955 "
    s .= "~-0.005717683128301552 ~0.01603606267912699 191:0:9717:9718 ~-0.001352284510219538 43:0.40625:9719:9720 ~-0.03166856256958157 ~0.018752845594946513 73:0.265625:9722:9723 ~-0.037768168418459716 ~0.01861254443211862 "
    s .= "220:-0.265625:9725:9726 ~-0.03727302189734654 ~0.02377375884837081 1:0:9728:9729 ~-0.001096991077491466 ~-0.0551309666491759 127:0.1875:9731:9748 124:0.0625:9732:9741 242:0.25:9733:9734 ~-0.04982452520631128 "
    s .= "109:0.484375:9735:9738 244:1.115:9736:9737 ~0.0031459388429612017 ~-0.031936304639301236 112:-0.140625:9739:9740 ~-0.03529224035059192 ~0.011784198482868729 166:-0.078125:9742:9743 ~-0.023305058962650105 "
    s .= "243:0.25:9744:9745 ~-0.03487913102770272 69:0.390625:9746:9747 ~0.03028461420672518 ~-0.017482332294719707 244:1.585:9749:9766 220:0.8125:9750:9765 145:-0.109375:9751:9752 ~-0.03291586557106306 134:-0.9375:9753:9754 "
    s .= "~-0.03135508131697436 250:1.2109375:9755:9762 129:0.2421875:9756:9761 55:0.1875:9757:9758 ~0.006119322115293009 28:0.015625:9759:9760 ~0.01400049447688255 ~-0.031599103607428077 ~-0.03889789265937443 "
    s .= "108:0.3203125:9763:9764 ~0.0009547599120972297 ~0.04923513944701243 ~0.027337654627532626 244:2.79:9767:9770 133:0.8125:9768:9769 ~-0.020124528853898614 ~0.02297699940708013 36:0.015625:9771:9776 "
    s .= "132:-0.3046875:9772:9775 238:1.171875:9773:9774 ~0.0323727639951829 ~-0.09312975153663246 ~-0.06382607877170174 ~0.0296339091181783 253:-0.09764309764309784:9778:9795 252:0.125:9779:9790 211:0.5:9780:9789 "
    s .= "75:-0.1015625:9781:9784 106:0.90625:9782:9783 ~-0.0929277466428834 ~0.0015571308196704258 71:0.140625:9785:9786 ~0.010851542778941438 254:0.203125:9787:9788 ~-0.001683616422459514 ~-0.08639117585253282 "
    s .= "~0.038374959469287824 187:0.28125:9791:9794 153:0.6796875:9792:9793 ~0.03328576927966169 ~-0.056177808776113794 ~-0.00212201520516123 217:0.1875:9796:9811 103:1.828125:9797:9810 108:0.1328125:9798:9807 "
    s .= "106:0.046875:9799:9802 160:0.25:9800:9801 ~-0.03553656765252019 ~0.014382466494482223 195:-0.328125:9803:9806 24:-0.3125:9804:9805 ~0.016698985028000178 ~-0.036253903871036795 ~0.011595038935938412 228:0.65625:9808:9809 "
    s .= "~-0.012332898207233288 ~0.022827842583848096 ~-0.02865324456126179 243:0.25:9812:9817 73:0.46875:9813:9816 244:1.02:9814:9815 ~0.04286027810320964 ~-0.044880367647504055 ~0.10408533835351666 250:0.8671875:9818:9821 "
    s .= "139:-0.265625:9819:9820 ~0.039049248079757466 ~-0.05073509724282981 244:0.955:9822:9823 ~-0.02961662575666651 ~-0.00014884886610905983 41:0.546875:9825:9862 11:0.71875:9826:9861 89:0.78125:9827:9858 "
    s .= "50:0.265625:9828:9853 30:0.9296875:9829:9852 49:0.90625:9830:9849 88:1.28125:9831:9842 110:-1.328125:9832:9837 189:-0.203125:9833:9836 163:0.390625:9834:9835 ~0.01704852953407262 ~-0.03492412593153958 "
    s .= "~-0.07120689061704565 122:-0.78125:9838:9841 119:-0.65625:9839:9840 ~0.026607571647186412 ~-0.013694089431455503 ~-0.0007575970198213484 193:-0.09375:9843:9844 ~-0.015466014821646952 103:0.953125:9845:9846 "
    s .= "~0.03179857174993742 119:-0.609375:9847:9848 ~-0.040754513248288965 ~0.020452610129458097 246:0.578125:9850:9851 ~-0.03236410719258697 ~0.04850546976612993 ~-0.05190649624301996 68:0.40625:9854:9855 "
    s .= "~-0.02483039234029045 40:0.234375:9856:9857 ~0.02307028171787355 ~-0.038824177715607866 112:1.140625:9859:9860 ~0.04317056060885165 ~-0.04008971198760429 ~0.05854671682881717 91:-0.140625:9863:9868 76:0.234375:9864:9865 "
    s .= "~-0.0037064322217615514 163:0.140625:9866:9867 ~0.22125000003803136 ~0.017033160020251677 134:0.46875:9869:9870 ~-0.003105834662523177 ~-0.05049125529702601 151:0.140625:9872:9881 242:0.25:9873:9876 "
    s .= "16:0.484375:9874:9875 ~-0.04898452887183272 ~0.030321479118647795 250:1.4765625:9877:9880 130:2.453125:9878:9879 ~0.008584078205742227 ~-0.05401003695546284 ~-0.015560054782600644 244:1.015:9882:9893 "
    s .= "103:0.1875:9883:9886 23:-0.28125:9884:9885 ~0.029560706299821878 ~-0.01935146605567889 220:0.875:9887:9892 148:-0.015625:9888:9891 46:0.046875:9889:9890 ~0.0429924832799572 ~-0.04771163855836035 ~-0.04409336469835042 "
    s .= "~0.03057059714143592 245:2.157142857142857:9894:9897 121:-0.4375:9895:9896 ~-0.06427003941901036 ~0.008974531394895824 253:-0.006628787878785403:9898:9905 202:-0.03125:9899:9904 252:1.475:9900:9903 73:0.15625:9901:9902 "
    s .= "~-0.07564848481411149 ~0.016664550766736452 ~0.028106539941317628 ~0.017691002777042122 169:0.703125:9906:9915 191:-1.140625:9907:9908 ~0.02686836533068117 24:0.203125:9909:9910 ~-0.04215859112193955 252:1.125:9911:9914 "
    s .= "114:0.0703125:9912:9913 ~0.02223410074566127 ~-0.05754929374194345 ~0.039298574427217445 88:0.65625:9916:9917 ~0.04089740930597281 ~-0.0515653364782567 254:1.296875:9919:9958 218:0.65625:9920:9955 246:0.203125:9921:9932 "
    s .= "206:0.015625:9922:9925 255:-0.140625:9923:9924 ~0.05358191781002754 ~0.0007443170837125009 106:2.046875:9926:9931 110:-0.671875:9927:9928 ~-0.06387970070271286 164:-0.0625:9929:9930 ~0.01847836185828179 "
    s .= "~-0.023705115393500554 ~-0.08294635024700905 89:0.15625:9933:9944 188:0.328125:9934:9941 245:1.9387755102040816:9935:9938 254:0.046875:9936:9937 ~-0.038455196304317214 ~0.042427600470160844 251:0.484375:9939:9940 "
    s .= "~-0.027348108163177533 ~0.021436815056650585 122:-0.171875:9942:9943 ~0.034688652188762575 ~-0.023264770890610395 133:-0.125:9945:9946 ~0.03898905277905966 199:0.71875:9947:9954 184:0.921875:9948:9953 "
    s .= "120:0.03125:9949:9950 ~-0.03612983093300996 222:0.4375:9951:9952 ~0.003996937061907247 ~-0.02417055826527741 ~0.025687418836675458 ~0.03161441466358517 146:-0.109375:9956:9957 ~0.042961064808313305 ~-0.04259762636209065 "
    s .= "244:1.32:9959:9962 18:-0.3046875:9960:9961 ~0.017554489305957127 ~-0.039565591243841916 253:0.005024422569535757:9963:9964 ~0.011259276474652658 ~-0.035592477433660605 251:0.203125:9966:9977 31:0.078125:9967:9976 "
    s .= "208:0.03125:9968:9971 44:-0.59375:9969:9970 ~0.027454757571561763 ~-0.04265889941941455 106:0.078125:9972:9973 ~-0.02518305654857176 67:0.140625:9974:9975 ~0.03672209763561615 ~-0.04180840844684434 ~-0.03689106990419158 "
    s .= "175:0.234375:9978:10001 79:0.25:9979:10000 46:0.71875:9980:9999 178:0.46875:9981:9994 244:1.115:9982:9983 ~0.0038781182673581016 52:-0.0625:9984:9991 242:0.35:9985:9988 235:0.03125:9986:9987 ~-0.06819106403598875 "
    s .= "~0.008802746500792514 85:0.890625:9989:9990 ~-0.005955564693234078 ~0.03731533550324944 181:0.0625:9992:9993 ~-0.05242424275352003 ~-0.017067588392163418 205:0.015625:9995:9998 58:0.75:9996:9997 ~0.003628968273814932 "
    s .= "~-0.09087285160667236 ~0.03232626332733184 ~0.03605353259024401 ~0.014534930209760356 97:-0.046875:10002:10007 12:0:10003:10006 181:1.703125:10004:10005 ~-0.04749738969984005 ~0.03504991671743282 ~-0.0038146382473754135 "
    s .= "175:0.578125:10008:10011 199:0.875:10009:10010 ~-0.012643113029295794 ~0.04412436898540681 ~0.01102055898511833 195:-0.34375:10013:10024 133:0.90625:10014:10017 148:1.65625:10015:10016 ~-0.026770141191671683 "
    s .= "~-0.13362293827745408 55:-0.234375:10018:10019 ~-0.05244788060427205 4:0.265625:10020:10023 27:-0.03125:10021:10022 ~0.026161722281440675 ~-0.028144383606034568 ~-0.03432342287244474 57:-0.6328125:10025:10026 "
    s .= "~0.03640301833559604 257:0.38:10027:10046 257:0.037037037037037035:10028:10045 243:2.25:10029:10044 130:2.453125:10030:10043 64:-0.203125:10031:10032 ~-0.0152338692794939 34:0.90625:10033:10042 79:0.78125:10034:10039 "
    s .= "46:1.015625:10035:10038 106:-0.265625:10036:10037 ~0.040082185177648576 ~-0.001124998418275637 ~0.041622957082648265 19:-0.1875:10040:10041 ~-0.03779512698774181 ~0.027417716513058268 ~-0.02962584096830292 "
    s .= "~-0.048688308503658045 ~-0.03928780102155549 ~0.014636762562367345 253:-0.014492753623187582:10047:10052 236:-0.484375:10048:10049 ~-0.006667931610309531 47:0.40625:10050:10051 ~-0.05692252441863515 ~0.03515310070814527 "
    s .= "36:-0.140625:10053:10054 ~-0.021627796276228926 15:0.0859375:10055:10058 196:-0.140625:10056:10057 ~0.0698453228566423 ~0.015475052752771482 ~-0.017538207474212347 253:-0.09764309764309784:10060:10077 "
    s .= "252:0.125:10061:10070 33:-0.171875:10062:10065 106:1.21875:10063:10064 ~-0.08786427677106606 ~0.01814824784500289 244:1.445:10066:10069 82:0.328125:10067:10068 ~0.015465811616658368 ~-0.04972858043690115 "
    s .= "~0.02545494110990544 163:0.375:10071:10074 153:0.6796875:10072:10073 ~0.03168411425589779 ~-0.057835333141297365 67:-0.3125:10075:10076 ~-0.07823464296207865 ~0.0057101182735222735 231:-0.609375:10078:10081 "
    s .= "148:0.1875:10079:10080 ~-0.0009468568765922292 ~-0.05000891984484371 57:-0.6171875:10082:10085 46:0.328125:10083:10084 ~0.03525367025885982 ~-0.05546601780412838 16:0.296875:10086:10097 107:0.09375:10087:10096 "
    s .= "191:0.03125:10088:10095 25:0.015625:10089:10094 187:-0.265625:10090:10091 ~-0.03891005088126154 239:-0.78125:10092:10093 ~0.02559675946812411 ~0.0008974286352972415 ~-0.016200199406993236 ~-0.033269131722642564 "
    s .= "~0.006143674377160042 152:0.21875:10098:10105 251:0.265625:10099:10100 ~-0.039245411354736796 137:-0.234375:10101:10104 81:0.1171875:10102:10103 ~-0.0171779954358028 ~0.03712083370355087 ~0.03823449801212586 "
    s .= "~-0.024201143051906 219:0.953125:10107:10152 254:0.984375:10108:10121 146:-0.625:10109:10114 41:0.015625:10110:10113 246:-1.109375:10111:10112 ~0.00634113351729107 ~0.035598282420802485 ~-0.037378647809123464 "
    s .= "246:0.015625:10115:10118 66:0.28125:10116:10117 ~-0.0026720083638773957 ~-0.035017437318339416 128:0.03125:10119:10120 ~0.01895823808136431 ~0.0002576996086666952 2:-0.1875:10122:10147 255:0.234375:10123:10124 "
    s .= "~0.03809814394105246 25:0.65625:10125:10146 257:0.48148148148148145:10126:10143 62:-0.5:10127:10138 113:-0.09375:10128:10135 249:0.5:10129:10132 250:0.8046875:10130:10131 ~-0.029940513020953758 ~0.02287235511708442 "
    s .= "251:0.984375:10133:10134 ~-0.044569427283287784 ~0.015366531852261417 233:-0.03125:10136:10137 ~0.055899473930295 ~-0.04742019951936512 247:0.203125:10139:10142 85:1.6875:10140:10141 ~-0.015363584582250782 "
    s .= "~0.037414246867121706 ~-0.05303919242749905 251:2.046875:10144:10145 ~-0.045729325548545426 ~0.03863231371739586 ~-0.059445056006720814 255:0.234375:10148:10151 103:0.9375:10149:10150 ~-0.02330477101971939 "
    s .= "~0.03834759512645568 ~-0.04295966965875959 ~-0.04310566744105928 33:0.984375:10154:10199 11:0.90625:10155:10196 247:0.953125:10156:10195 246:1.890625:10157:10194 192:0.90625:10158:10193 172:-0.390625:10159:10164 "
    s .= "257:0.043478260869565216:10160:10161 ~-0.039050655106533744 106:0.578125:10162:10163 ~-0.04883216374966146 ~0.030293806438633466 55:-0.59375:10165:10168 190:-0.125:10166:10167 ~-0.03476263698218395 ~0.054620929597918914 "
    s .= "88:1.1875:10169:10180 208:0.875:10170:10177 46:1.125:10171:10176 133:1.65625:10172:10175 79:1.3125:10173:10174 ~-0.0033833070041667844 ~0.024086668946420517 ~-0.017958404147066346 ~0.0361986380241541 28:0:10178:10179 "
    s .= "~0.03376133444344238 ~-0.007612075806190251 148:1.171875:10181:10190 253:-0.021825396825401338:10182:10185 214:1.109375:10183:10184 ~0.03590283507304699 ~-0.043000615811776846 252:0.725:10186:10189 93:0.0625:10187:10188 "
    s .= "~0.025451090954388647 ~-0.025863980503456424 ~-0.034154356746553934 99:0.1875:10191:10192 ~-0.04994483391416549 ~0.03030836571196215 ~-0.05225378164129242 ~0.0520038419752373 ~-0.05313499643622763 "
    s .= "104:0.671875:10197:10198 ~0.06564946505221167 ~-0.020948937229406824 ~-0.049717251433962335 245:3.459016393442623:10201:10244 244:1.49:10202:10231 130:0.15625:10203:10212 76:-0.15625:10204:10205 ~-0.025286893059975814 "
    s .= "243:1.35:10206:10211 223:0.625:10207:10210 121:0.5:10208:10209 ~0.03244234026681762 ~-0.025989011481381552 ~-0.033814369791007694 ~-0.02049689615708149 220:0.8125:10213:10230 97:-0.0625:10214:10219 "
    s .= "12:-0.015625:10215:10216 ~-0.040696796225173276 25:-0.28125:10217:10218 ~0.020766186656237928 ~-0.022035076293267356 91:1.109375:10220:10229 145:-0.140625:10221:10222 ~-0.038492941769742925 190:-0.171875:10223:10226 "
    s .= "97:0.03125:10224:10225 ~0.020775085558668725 ~-0.04932959011168177 58:-0.578125:10227:10228 ~0.06736158868182315 ~-0.0015820491746778753 ~0.022879530888867503 ~0.027167593809393986 157:0.265625:10232:10239 "
    s .= "85:0.296875:10233:10238 79:-0.09375:10234:10235 ~0.022309041696204807 243:0.6499999999999999:10236:10237 ~-0.05509639547811518 ~0.0031790337775742398 ~0.01950139128975361 67:0.609375:10240:10243 244:2.79:10241:10242 "
    s .= "~0.023975056125398547 ~-0.004002613647010203 ~-0.023384367736659452 160:0.625:10245:10246 ~-0.05556831242364805 ~0.0037560715818661787 217:0.1875:10248:10273 238:0.359375:10249:10266 130:2.046875:10250:10263 "
    s .= "76:0.4375:10251:10258 190:-0.1875:10252:10253 ~-0.015594461150869189 184:0.15625:10254:10257 244:1.125:10255:10256 ~0.013035789849295314 ~-0.010888258513700348 ~0.012443608964972831 67:0.15625:10259:10262 "
    s .= "217:-0.28125:10260:10261 ~-0.025268182923385257 ~0.0384191648631507 ~-0.0032682321809997072 89:-1.21875:10264:10265 ~0.04015980357123563 ~-0.03534131059002074 136:0.828125:10267:10268 ~-0.02894687925040186 "
    s .= "244:2.98:10269:10272 199:0.125:10270:10271 ~0.026160813995046925 ~-0.025803561847935592 ~-0.0403975299897448 163:0.34375:10274:10283 115:0.140625:10275:10280 175:-0.109375:10276:10277 ~0.023477614828539245 "
    s .= "106:1.15625:10278:10279 ~-0.03899730929856637 ~0.012919793628229655 196:0.140625:10281:10282 ~-0.021886093129244773 ~0.021872892267442032 19:-0.5625:10284:10285 ~0.03252593092803222 250:1.3046875:10286:10293 "
    s .= "244:1.5:10287:10288 ~-0.04416886878943834 116:-1.234375:10289:10290 ~-0.10399375672373318 73:-0.21875:10291:10292 ~-0.0899597029427373 ~0.009452523310246649 ~0.0009124091032726659 224:0.625:10295:10340 "
    s .= "255:0.234375:10296:10317 255:0.109375:10297:10308 246:1.734375:10298:10307 242:0.55:10299:10302 184:0.1875:10300:10301 ~-0.009112396147602937 ~0.020837961056497923 245:1.6142857142857143:10303:10304 "
    s .= "~-0.03514157270606419 251:0.421875:10305:10306 ~-0.03937847873381023 ~0.005038466207222412 ~0.0374150829371741 219:0.140625:10309:10316 226:-0.140625:10310:10311 ~-0.03508613060953344 34:0.3125:10312:10315 "
    s .= "236:0.359375:10313:10314 ~0.0189878261249432 ~-0.039953419830570325 ~-0.04198996010240226 ~0.027400155573940252 254:0.546875:10318:10319 ~0.013252501374240147 50:-0.34375:10320:10333 246:-0.390625:10321:10330 "
    s .= "243:0.75:10322:10327 133:1.203125:10323:10324 ~-0.036205543888985364 54:-0.2890625:10325:10326 ~-0.04372509968613996 ~0.013018454899527838 238:0.578125:10328:10329 ~0.014990236539249089 ~-0.05756948601599067 "
    s .= "167:0.21875:10331:10332 ~0.02031762939013204 ~-0.0481410005003015 250:1.0234375:10334:10337 244:1.575:10335:10336 ~-0.050799015305748485 ~-0.007559176939058096 59:0.03125:10338:10339 ~-0.025524122635515067 "
    s .= "~0.02135522233298944 ~-0.022967682725982663 5:-1.484375:10342:10343 ~0.026568075922489578 246:-1.984375:10344:10357 244:1.49:10345:10352 26:-0.75:10346:10351 254:0.640625:10347:10350 233:-0.609375:10348:10349 "
    s .= "~0.01768988326382971 ~-0.0527998650293945 ~-0.04425217404649952 ~-0.054179662059764905 190:0.03125:10353:10356 153:-0.7890625:10354:10355 ~0.03817518061496118 ~-0.042439689908721025 ~0.02268278621913937 "
    s .= "56:-0.8125:10358:10359 ~0.01659942853493104 68:-0.6875:10360:10365 28:0.015625:10361:10362 ~0.0010905317942767475 74:-1:10363:10364 ~0.047168093570356916 ~-0.046971538820488434 250:1.1171875:10366:10375 "
    s .= "108:0.2734375:10367:10374 28:1.015625:10368:10373 217:-0.21875:10369:10370 ~-0.026785971930518366 169:1.15625:10371:10372 ~0.001652574714668037 ~0.04690159465763945 ~-0.05651654739087295 ~-0.026742703062982282 "
    s .= "111:0.3515625:10376:10387 240:0.09375:10377:10380 1:0.484375:10378:10379 ~0.008081221953972966 ~0.04950007955158283 245:1.6290322580645162:10381:10384 113:0.71875:10382:10383 ~-0.04542884640991749 ~0.017275211606674997 "
    s .= "244:1.09:10385:10386 ~0.025992584872854614 ~-0.013276212547342157 ~0.03739166704337023 151:0.0625:10389:10408 100:0.515625:10390:10407 250:1.3515625:10391:10406 245:1.4754098360655739:10392:10395 47:0.46875:10393:10394 "
    s .= "~0.05168654135705885 ~-0.04226355599863686 242:0.25:10396:10397 ~-0.04072284073916126 160:1.96875:10398:10405 116:0.140625:10399:10404 25:0.875:10400:10403 157:-0.078125:10401:10402 ~-0.017067946289032625 "
    s .= "~0.01637901859096896 ~-0.060714427259742715 ~-0.013947468465184187 ~-0.04880626523671956 ~-0.01985254211366546 ~0.027574738245865645 121:-0.046875:10409:10414 244:2.315:10410:10413 6:-0.03125:10411:10412 "
    s .= "~-0.046569949958819766 ~-0.00636347047825506 ~0.036968177086282056 250:0.6796875:10415:10424 196:1.078125:10416:10423 181:0.140625:10417:10420 79:0.453125:10418:10419 ~-0.03950801765867937 ~0.034580025543725516 "
    s .= "208:0.921875:10421:10422 ~-0.05549557418770443 ~0.03847832495738265 ~0.04684328802387269 67:0.015625:10425:10430 231:0.09375:10426:10427 ~-0.01980572763974957 213:-0.0625:10428:10429 ~0.05868372255700452 "
    s .= "~-0.002893057267302197 103:0.28125:10431:10434 190:-0.046875:10432:10433 ~-0.010088257726255073 ~0.022125423574351145 ~-0.0012160377922415776 61:1.09375:10436:10477 82:1.8125:10437:10470 64:1.109375:10438:10469 "
    s .= "103:1.328125:10439:10468 190:-0.125:10440:10445 148:0.03125:10441:10442 ~0.0017180950410661663 25:0.484375:10443:10444 ~-0.041774550494502405 ~0.013556294503478665 115:-0.109375:10446:10449 214:-0.109375:10447:10448 "
    s .= "~0.02702367489850544 ~-0.029932235672291314 61:-0.296875:10450:10451 ~0.030235201378927226 142:0.21875:10452:10459 239:0.140625:10453:10456 217:-0.140625:10454:10455 ~-0.019887892869880575 ~0.011614460407808358 "
    s .= "107:0.078125:10457:10458 ~-0.04204332307920676 ~0.0012958744626265593 184:1.28125:10460:10467 220:0.875:10461:10466 103:0.1875:10462:10463 ~0.0014527938328418033 130:0.203125:10464:10465 ~0.011595780420217047 "
    s .= "~-0.03190292751540077 ~0.03630889246047719 ~0.04084393388411877 ~0.015466309143937748 ~0.02752176538742837 244:2.69:10471:10476 106:0.96875:10472:10473 ~-0.07718352966070854 133:2.046875:10474:10475 ~0.02188352218025265 "
    s .= "~-0.040277378018505984 ~-0.06916782999183196 181:0.78125:10478:10479 ~0.02091899468491942 13:0.109375:10480:10481 ~0.004805562691346425 ~-0.06001313298506466 203:0.734375:10483:10528 11:0.90625:10484:10525 "
    s .= "247:0.953125:10485:10524 113:0.734375:10486:10519 175:-0.640625:10487:10488 ~-0.05256017814526344 245:1.3766233766233766:10489:10494 7:0.828125:10490:10493 106:-0.28125:10491:10492 ~0.04037700787259149 "
    s .= "~-0.037518885230121646 ~0.09301662544322212 256:0:10495:10512 247:0.515625:10496:10509 33:0.75:10497:10506 132:0.3671875:10498:10505 247:0.203125:10499:10500 ~0.0014368649412931055 217:0.328125:10501:10504 "
    s .= "8:-0.171875:10502:10503 ~-0.045282176821453406 ~-0.007384088869942564 ~0.020139908718875346 ~0.03000907517367246 165:0.53125:10507:10508 ~-0.06593584262744473 ~0.031979723527832196 84:0.7734375:10510:10511 "
    s .= "~-0.045016925025955834 ~0.06771370227452474 62:0.53125:10513:10516 240:-0.265625:10514:10515 ~-0.05198432981963768 ~0.02533018081161205 34:-0.015625:10517:10518 ~0.026024929702726053 ~-0.043510579427666396 "
    s .= "251:0.421875:10520:10521 ~-0.0518609862944776 191:0.65625:10522:10523 ~0.03564999101835583 ~-0.04555614678860884 ~-0.051145711311428844 15:0.7265625:10526:10527 ~0.06305579509324558 ~-0.02509867943755228 "
    s .= "~-0.029328092642458056 217:0.1875:10530:10549 66:0.109375:10531:10538 48:0.1171875:10532:10537 8:0.40625:10533:10536 2:0.078125:10534:10535 ~0.004048277608027319 ~-0.016733050954777114 ~0.037057585185758794 "
    s .= "~0.023345202406255566 245:1.7857142857142858:10539:10546 254:0.765625:10540:10545 247:0.609375:10541:10544 109:1.171875:10542:10543 ~-0.03029138481229442 ~0.0313905649159554 ~0.03238424459496542 ~0.035556175572433374 "
    s .= "252:1.8250000000000002:10547:10548 ~-0.016152301602253418 ~0.026421307909286564 84:0.2265625:10550:10567 220:0.96875:10551:10564 123:-0.078125:10552:10559 174:-0.53125:10553:10554 ~-0.05184953668872351 "
    s .= "226:0.109375:10555:10556 ~-0.030898184432303424 250:0.7578125:10557:10558 ~-0.038511318025929046 ~0.019736500401489762 88:1.75:10560:10563 112:0.53125:10561:10562 ~-0.015902584134964537 ~-0.045581774556269716 "
    s .= "~0.02778558169101944 52:0.296875:10565:10566 ~0.03480689907000608 ~-0.038266631336174306 7:0.453125:10568:10575 1:0.015625:10569:10570 ~0.022828644860001662 113:-0.078125:10571:10572 ~-0.06370605592194377 "
    s .= "62:-0.046875:10573:10574 ~0.03891072133833374 ~-0.0298128686864322 ~0.05400856266744543 242:2.25:10577:10620 252:1.875:10578:10615 243:1.95:10579:10614 245:2.2:10580:10591 242:1.35:10581:10588 143:-1.1875:10582:10583 "
    s .= "~-0.026177733205336853 145:-0.46875:10584:10585 ~-0.042851355737850316 224:0.625:10586:10587 ~0.007799174128305664 ~-0.03433159470033156 251:1.265625:10589:10590 ~-0.041592779794901315 ~0.014566386101013488 "
    s .= "215:-0.46875:10592:10599 244:1.115:10593:10594 ~0.03563947844954634 187:-0.03125:10595:10596 ~-0.028189692143016712 250:0.6484375:10597:10598 ~-0.03652275772513751 ~0.016024829571181586 16:0.15625:10600:10611 "
    s .= "208:0.453125:10601:10608 12:-0.015625:10602:10605 248:0.125:10603:10604 ~0.016553106380167444 ~-0.02573921155412795 148:0.484375:10606:10607 ~-0.04751873611109227 ~-0.0023174204395631864 181:0.75:10609:10610 "
    s .= "~0.027392553197711736 ~-0.03525459946891511 100:0.25:10612:10613 ~0.019909394959405018 ~-0.0277343565360827 ~-0.04576015779348778 251:0.296875:10616:10617 ~-0.047628074840414744 220:-0.265625:10618:10619 "
    s .= "~-0.03035995170017161 ~0.02724478246957253 245:2.6153846153846154:10621:10622 ~-0.03688556964693195 ~0.01640329852254536 254:0.984375:10624:10641 217:0.21875:10625:10626 ~0.003751453432253508 243:0.25:10627:10630 "
    s .= "94:-0.0625:10628:10629 ~-0.04879450535145488 ~0.05481965308057923 47:-0.640625:10631:10636 25:0.234375:10632:10635 183:-0.515625:10633:10634 ~-0.05429740020357128 ~0.033778377174593935 ~-0.04606161623704542 "
    s .= "1:-0.28125:10637:10640 244:1.085:10638:10639 ~-0.043961482584110395 ~0.02480114887563835 ~-0.023806883864492805 1:0.796875:10642:10669 244:1.41:10643:10660 182:-0.3125:10644:10653 245:2.365079365079365:10645:10650 "
    s .= "33:-0.296875:10646:10647 ~-0.002391443349644232 55:0.984375:10648:10649 ~-0.05522847622472776 ~0.01773700126529268 239:-0.9375:10651:10652 ~0.03837506928216162 ~-0.02266573164379114 95:-0.265625:10654:10657 "
    s .= "122:-0.21875:10655:10656 ~0.038949715090281466 ~-0.025627535637684575 250:1.0703125:10658:10659 ~-0.03810015076556414 ~0.006880653285232215 253:-0.0016420857076717592:10661:10662 ~0.02262164081311777 "
    s .= "245:2.1372549019607843:10663:10664 ~0.010873065320173354 25:-0.03125:10665:10668 178:0.21875:10666:10667 ~0.01526586969266969 ~-0.07011527434791887 ~-0.05716092571645966 ~-0.05041858335792775 181:-0.703125:10671:10672 "
    s .= "~-0.04385718852419851 19:-0.5625:10673:10676 222:0.125:10674:10675 ~-0.008064973720493857 ~0.04250241221665637 243:2.05:10677:10712 257:0.30434782608695654:10678:10685 22:-0.265625:10679:10682 19:-0.015625:10680:10681 "
    s .= "~-0.01967387766525088 ~0.030172093322673055 100:0.53125:10683:10684 ~0.001764297472377751 ~0.017057024967608577 136:0.1875:10686:10689 240:0.046875:10687:10688 ~0.03230609475587467 ~-0.0342490343073405 "
    s .= "165:-0.203125:10690:10701 249:0.5:10691:10700 242:0.6499999999999999:10692:10693 ~0.017185997469307577 223:0.390625:10694:10699 245:1.5529411764705883:10695:10696 ~-0.06517455143514504 238:0.96875:10697:10698 "
    s .= "~0.02310221403838199 ~-0.10191233498312838 ~-0.06491006544358405 ~-0.03352675795379239 170:-0.609375:10702:10705 107:-0.9375:10703:10704 ~-0.05073875507990475 ~0.02585322259545903 52:-0.0625:10706:10709 "
    s .= "85:0.34375:10707:10708 ~-0.04660153017827636 ~0.019626406801386574 162:0.25:10710:10711 ~-0.060109240322528935 ~0.034174889177565615 157:0.5:10713:10714 ~-0.049551482489368935 37:-0.125:10715:10716 ~-0.04325829643896571 "
    s .= "~0.02369501963122751 253:-0.07269338303821087:10718:10745 252:0.175:10719:10738 19:0.0625:10720:10729 235:-0.140625:10721:10724 1:0.4375:10722:10723 ~-0.05338368300858434 ~0.03604175340013421 251:2.265625:10725:10728 "
    s .= "250:0.6328125:10726:10727 ~-0.05781479462163415 ~0.01747414563724962 ~-0.12424121027277119 109:1.15625:10730:10733 72:0.171875:10731:10732 ~-0.07748846970440872 ~-0.0003280530429727124 186:0.375:10734:10737 "
    s .= "115:0.609375:10735:10736 ~0.03343425351893604 ~-0.076146974468136 ~-0.0888716996998577 214:0.3125:10739:10744 35:0.125:10740:10741 ~0.030839719290483493 100:0.171875:10742:10743 ~0.024458378719282123 "
    s .= "~-0.03511140355102773 ~-0.009445308358421035 248:0.125:10746:10753 251:1.203125:10747:10750 189:-0.125:10748:10749 ~0.0058299511338583765 ~-0.022987230834328583 243:0.75:10751:10752 ~-0.024452401228260867 "
    s .= "~0.02815833744383596 253:-0.00793650793650929:10754:10757 252:0.225:10755:10756 ~-0.035738365563109324 ~-0.0010613951200683827 101:0.5625:10758:10763 249:1.8333333333333335:10759:10762 255:0.234375:10760:10761 "
    s .= "~0.015543537145259466 ~-0.0017169093263882545 ~-0.03792656800588777 ~-0.033219057286050506 195:-0.34375:10765:10770 160:1.453125:10766:10769 48:-0.1328125:10767:10768 ~-0.006033619713877388 ~-0.0368414591979886 "
    s .= "~0.023450701770225645 57:-0.6328125:10771:10772 ~0.0343501464382873 133:1.625:10773:10802 67:0.171875:10774:10793 139:0.5:10775:10790 88:0.390625:10776:10783 108:-0.1171875:10777:10782 24:-0.109375:10778:10781 "
    s .= "142:0.015625:10779:10780 ~-0.04772849879524804 ~0.01678317309289994 ~0.0264372086662799 ~-0.0138901311039981 118:0.265625:10784:10789 189:0.125:10785:10788 244:1.505:10786:10787 ~-0.005459876581509563 "
    s .= "~0.040335823631719114 ~0.04421991203525877 ~-0.019627829159942652 8:0.421875:10791:10792 ~0.011097663904283421 ~0.05444757404896258 251:0.796875:10794:10797 156:0.4765625:10795:10796 ~-0.022180404254938342 "
    s .= "~0.02664711708908924 23:0.453125:10798:10801 97:-0.21875:10799:10800 ~-0.028208965809440534 ~0.015170164128731376 ~-0.048807001129708795 181:0.015625:10803:10806 97:0.171875:10804:10805 ~-0.0508242585806539 "
    s .= "~0.011060919263979797 223:0.03125:10807:10810 103:1.734375:10808:10809 ~-0.0072894710742709345 ~-0.0653151159283286 ~0.010189417347636516 98:0.625:10812:10857 8:0.734375:10813:10854 245:3.459016393442623:10814:10849 "
    s .= "244:1.64:10815:10834 130:0.15625:10816:10821 76:-0.140625:10817:10818 ~-0.022304105631333424 44:0.453125:10819:10820 ~0.021824111377183097 ~-0.03167347851989366 220:0.8125:10822:10833 134:-0.9375:10823:10826 "
    s .= "6:-0.265625:10824:10825 ~-0.002737248359277799 ~-0.03986307466094577 77:0.03125:10827:10830 130:1.875:10828:10829 ~0.0027889010283362495 ~-0.032892473339676646 89:0.625:10831:10832 ~-0.023095061884458083 "
    s .= "~0.01603730399749742 ~0.023697232585544736 130:0.21875:10835:10838 85:0.296875:10836:10837 ~-0.04401352486407568 ~0.01082942278389915 242:0.55:10839:10842 118:0.515625:10840:10841 ~0.02923443487781395 "
    s .= "~-0.039608905232914084 79:0.171875:10843:10848 166:-0.09375:10844:10845 ~0.021022520874102203 252:0.375:10846:10847 ~-0.06723065258153066 ~-0.0027131979349941846 ~0.017941124457685777 87:-0.4921875:10850:10851 "
    s .= "~0.039958262090400494 67:-0.140625:10852:10853 ~0.01003977831083225 ~-0.05008784322058693 140:0.71875:10855:10856 ~0.04938795959829843 ~-0.042316659158297215 ~-0.02138848946369514 33:0.984375:10859:10904 "
    s .= "11:0.90625:10860:10901 247:0.953125:10861:10900 246:1.890625:10862:10899 192:0.90625:10863:10898 50:0.71875:10864:10897 124:-0.65625:10865:10866 ~-0.037455054834796095 124:0.828125:10867:10890 88:1.109375:10868:10881 "
    s .= "79:-0.125:10869:10870 ~0.011864737347417598 133:0.296875:10871:10874 211:0.53125:10872:10873 ~0.014497965229886972 ~-0.05512587136481533 30:0.3359375:10875:10880 111:-0.4609375:10876:10877 ~-0.02639656737489092 "
    s .= "46:0.078125:10878:10879 ~0.007421204022442099 ~-0.00956603381534514 ~-0.019837243780039496 193:0:10882:10889 25:-0.046875:10883:10884 ~0.01498334087572763 241:0.6:10885:10888 92:-0.296875:10886:10887 "
    s .= "~-0.00923974955815375 ~-0.08653366798515945 ~0.012094269412844236 ~0.026693887261936347 243:0.75:10891:10894 26:0.34375:10892:10893 ~-0.031066236018291546 ~0.03372249794377631 181:0.46875:10895:10896 "
    s .= "~0.028018244415227895 ~-0.013481686673085379 ~-0.0397841269700622 ~-0.050798106119687825 ~0.0501884176562344 ~-0.05086722307887551 246:1.546875:10902:10903 ~0.057145248382514904 ~-0.03401814997054986 "
    s .= "~-0.048245503238836654 242:2.25:10906:10947 252:1.875:10907:10944 243:1.45:10908:10941 245:2.2:10909:10922 144:-0.46875:10910:10911 ~-0.01769296648436672 189:-0.203125:10912:10913 ~0.017346813615324457 "
    s .= "246:-0.328125:10914:10919 85:1.3125:10915:10918 211:0.25:10916:10917 ~-0.007399467732219796 ~-0.04657979268826362 ~0.037992763675282676 254:0.765625:10920:10921 ~-0.00015429330534354592 ~0.017202602166045862 "
    s .= "44:-0.75:10923:10924 ~0.01120173933148637 127:0.625:10925:10940 91:0.203125:10926:10935 211:0.03125:10927:10930 64:0.3125:10928:10929 ~-0.04390968667068754 ~0.025545918009221426 100:-0.328125:10931:10932 "
    s .= "~0.04864509990849918 16:0.15625:10933:10934 ~-0.021910742030632275 ~0.02047023489969906 118:0.359375:10936:10939 202:-0.03125:10937:10938 ~-0.024211529600152593 ~0.031757498804499 ~-0.02346270029945535 "
    s .= "~-0.026451023614741827 73:0.265625:10942:10943 ~-0.03438689378066961 ~0.018274710409380012 251:0.296875:10945:10946 ~-0.047077584861425645 ~0.020613439091015276 1:0:10948:10951 1:-0.515625:10949:10950 "
    s .= "~-0.0567315298732648 ~0.016303512281744485 ~-0.05129471741165902 253:-0.09764309764309784:10953:10980 252:0.125:10954:10967 51:-0.1796875:10955:10958 207:-0.5:10956:10957 ~0.01715693182261871 ~-0.0915224587227191 "
    s .= "14:-0.546875:10959:10960 ~0.03467683462991749 249:0.16666666666666666:10961:10964 208:-0.234375:10962:10963 ~-0.06090558900552798 ~0.03174402796266622 152:0.0625:10965:10966 ~-0.011059942128673148 ~-0.07269516793284686 "
    s .= "46:-0.265625:10968:10973 109:1.3125:10969:10972 103:0.21875:10970:10971 ~0.014672886033692434 ~-0.07428203630827043 ~0.03261369378486628 25:0.9375:10974:10979 257:0.8888888888888888:10975:10978 244:0.91:10976:10977 "
    s .= "~-0.0157042296507608 ~0.03567032510952457 ~-0.035197580449278384 ~-0.08892422810759977 217:0.1875:10981:10988 103:1.828125:10982:10987 103:0.671875:10983:10984 ~-0.0011926591299683937 70:0.609375:10985:10986 "
    s .= "~0.015268956489832146 ~-0.04071104187928973 ~-0.026046273364839934 243:0.25:10989:10992 115:0.203125:10990:10991 ~-0.013009266667173364 ~0.054622955479796766 250:0.8671875:10993:10996 139:-0.265625:10994:10995 "
    s .= "~0.03581839724786555 ~-0.04469769885103387 244:0.955:10997:10998 ~-0.02771933269693429 ~-0.0004058917652398876 254:0.984375:11000:11019 223:1.875:11001:11018 146:-0.4375:11002:11003 ~0.008783900004171443 "
    s .= "246:0.171875:11004:11011 242:0.55:11005:11008 95:-0.40625:11006:11007 ~-0.02933158580094988 ~0.010430196612374341 255:0.171875:11009:11010 ~-0.030405347213077694 ~-0.0021994653245981806 254:0.765625:11012:11013 "
    s .= "~-0.00001752359766237022 245:1.9387755102040816:11014:11017 242:0.35:11015:11016 ~-0.034517611237547485 ~0.048300127588382535 ~-0.012704979560168929 ~-0.07089111065687063 26:-0.109375:11020:11043 137:-0.125:11021:11034 "
    s .= "244:1.225:11022:11025 9:-0.2890625:11023:11024 ~0.013745094879801661 ~-0.04507117942463416 201:-0.078125:11026:11033 249:0.5:11027:11032 245:2.9130434782608696:11028:11031 239:-1.421875:11029:11030 ~-0.07750523613430496 "
    s .= "~0.014060907432737288 ~-0.054066683910369576 ~-0.05683382014309046 ~0.01816314574783499 95:-0.375:11035:11038 236:-0.046875:11036:11037 ~0.04540211386962897 ~-0.04562539709664712 49:0.125:11039:11042 "
    s .= "56:-0.234375:11040:11041 ~-0.04440935531100655 ~0.007657057951558362 ~0.027512519803288005 245:1.975:11044:11045 ~-0.004190178630844125 ~-0.05580126954881001 251:0.078125:11047:11050 250:0.8828125:11048:11049 "
    s .= "~0.011579322925628 ~-0.049302680642018704 250:1.0703125:11051:11076 25:0.640625:11052:11075 159:0.3359375:11053:11072 97:-0.09375:11054:11059 148:0.015625:11055:11058 245:2.6:11056:11057 ~-0.015107490140233047 "
    s .= "~0.027607475137927648 ~-0.031854362672315395 34:0.015625:11060:11069 178:-0.015625:11061:11066 190:0.21875:11062:11065 133:0.53125:11063:11064 ~0.024237827090363585 ~-0.0398232368481876 ~0.03818731146978544 "
    s .= "218:0.21875:11067:11068 ~0.023671511722850928 ~-0.016259418583507084 7:-0.125:11070:11071 ~-0.03940149501104509 ~-0.00004793453080976156 130:0.296875:11073:11074 ~0.013991461003016147 ~-0.0464628530403353 "
    s .= "~-0.04027378965658678 132:0.2890625:11077:11092 33:0.515625:11078:11089 184:0.046875:11079:11088 106:0.8125:11080:11083 252:0.375:11081:11082 ~-0.03704034637281158 ~0.01911662209290006 250:1.2890625:11084:11085 "
    s .= "~0.027359552505819174 243:0.6499999999999999:11086:11087 ~-0.05851809155068789 ~0.011045613809605665 ~0.010405703670185848 138:0.2578125:11090:11091 ~-0.03792632283589206 ~0.011613424441508802 ~0.022940587641737526 "
    s .= "126:0.984375:11094:11139 251:0.203125:11095:11106 31:0.078125:11096:11105 243:0.8500000000000001:11097:11104 106:0.359375:11098:11101 178:0.59375:11099:11100 ~-0.03339247402195077 ~0.04227806324468822 "
    s .= "73:0.078125:11102:11103 ~0.03558409107060551 ~-0.020902210074262795 ~-0.06623174073460007 ~-0.03545656168060576 255:0.265625:11107:11122 255:0.109375:11108:11109 ~-0.0002427066893885755 "
    s .= "245:1.9186046511627908:11110:11115 254:0.421875:11111:11112 ~-0.047832782401416266 92:-0.921875:11113:11114 ~-0.04405674070591747 ~0.03631553533316284 122:0.046875:11116:11117 ~0.01573377394565779 242:0.75:11118:11121 "
    s .= "227:-0.25:11119:11120 ~0.04543251423763159 ~-0.060013379385063896 ~0.015445608830690506 77:-0.453125:11123:11132 246:-0.453125:11124:11129 101:-0.515625:11125:11128 160:1.453125:11126:11127 ~-0.004309716267949561 "
    s .= "~0.03385422555995623 ~-0.04236866316746354 95:0.015625:11130:11131 ~0.0357058461123884 ~-0.036839507652826425 244:1.47:11133:11138 250:0.9921875:11134:11135 ~-0.04069853497488271 11:0.578125:11136:11137 "
    s .= "~-0.013710360429046553 ~0.07426634786615144 ~0.002533634492671169 ~-0.05539221697926492 5:-1.484375:11141:11144 25:0.203125:11142:11143 ~0.043634978369051385 ~-0.02195096453528906 246:-1.984375:11145:11152 "
    s .= "209:-0.640625:11146:11151 115:0.390625:11147:11150 211:-0.015625:11148:11149 ~-0.02511416071116623 ~0.023947081560085636 ~-0.01989292483702565 ~-0.03488743348029841 56:-0.8125:11153:11154 ~0.015015866020975927 "
    s .= "68:-0.6875:11155:11160 28:0.015625:11156:11157 ~0.0016677325681272348 74:-1:11158:11159 ~0.043811909235921466 ~-0.04401435569143334 181:2.140625:11161:11186 120:-0.453125:11162:11165 199:-0.03125:11163:11164 "
    s .= "~0.018543494494671173 ~-0.06466804220397818 47:-0.375:11166:11167 ~0.010474772719675247 255:0.234375:11168:11181 255:0.109375:11169:11170 ~-0.0028700654187791344 245:1.9186046511627908:11171:11176 "
    s .= "254:0.359375:11172:11173 ~-0.03328144802321229 40:-0.03125:11174:11175 ~0.009162461393922468 ~0.04256669604961737 122:-0.03125:11177:11178 ~0.02071640125773068 247:0.046875:11179:11180 ~-0.05254363545856584 "
    s .= "~-0.0031124154215670945 244:0.985:11182:11183 ~-0.04196800725165816 73:0.296875:11184:11185 ~-0.013906569619820668 ~0.01743289613797676 ~-0.048942821432649636 254:0.984375:11188:11231 251:0.203125:11189:11194 "
    s .= "31:0.078125:11190:11193 208:0.015625:11191:11192 ~-0.029566111863132877 ~0.011254513915382515 ~-0.034189624217923244 79:0.25:11195:11214 109:1.703125:11196:11203 61:0.765625:11197:11202 212:-0.359375:11198:11199 "
    s .= "~0.00976819783703571 247:-0.453125:11200:11201 ~-0.039171193611827665 ~-0.0022092319513860397 ~0.02711745679221646 70:0.015625:11204:11209 208:0:11205:11208 118:-0.1875:11206:11207 ~0.01963583609610822 "
    s .= "~-0.06111385651210101 ~0.024689052869749116 223:0.765625:11210:11213 64:1.140625:11211:11212 ~-0.06387006827959177 ~0.01521839502766082 ~0.031212749843068568 178:0.296875:11215:11218 82:0.203125:11216:11217 "
    s .= "~0.03786761801596594 ~0.01200497235814142 243:0.25:11219:11220 ~0.08272500473760849 251:1.078125:11221:11230 85:1.578125:11222:11229 205:0.375:11223:11226 61:0.28125:11224:11225 ~0.012585125617155883 "
    s .= "~-0.0325765348414201 243:2.95:11227:11228 ~-0.051660192881016025 ~0.09487207405710096 ~0.017139709431127758 ~0.011287698849546689 1:0.796875:11232:11233 ~-0.005023586202279781 ~-0.048847453555047916 "
    s .= "191:0.796875:11235:11280 246:1.796875:11236:11279 11:0.90625:11237:11276 247:0.796875:11238:11273 175:-0.484375:11239:11242 245:1.4941176470588236:11240:11241 ~0.03538280743638606 ~-0.043552431761337156 "
    s .= "19:-0.5625:11243:11244 ~0.02345952611893201 243:2.25:11245:11272 257:0.30434782608695654:11246:11257 22:-0.265625:11247:11250 244:1.1:11248:11249 ~-0.04177457244113295 ~-0.0024317148645980283 100:0.53125:11251:11256 "
    s .= "109:0.5625:11252:11253 ~-0.006492664614270062 243:0.35:11254:11255 ~-0.012023011987510412 ~0.0103526376194729 ~0.017277382057701834 247:-0.390625:11258:11265 249:0.8333333333333333:11259:11264 36:0.296875:11260:11263 "
    s .= "96:-0.0703125:11261:11262 ~-0.00251256462435143 ~0.025724541556053977 ~-0.04739470273830645 ~-0.03761579019274068 75:0.0234375:11266:11271 19:-0.0625:11267:11270 250:1.1171875:11268:11269 ~-0.04401335915069879 "
    s .= "~0.04574508680662094 ~-0.06965714725537352 ~-0.001100268372081541 ~-0.02834849891108411 189:0.671875:11274:11275 ~-0.053600061201874966 ~0.03384141031365481 15:0.7265625:11277:11278 ~0.06358984044649195 "
    s .= "~-0.041428684698529956 ~0.03256366175648936 ~-0.03094377131890796 41:0.546875:11282:11319 11:0.71875:11283:11318 89:0.78125:11284:11315 160:-0.328125:11285:11288 242:0.6499999999999999:11286:11287 ~-0.04953199161288861 "
    s .= "~0.0019018995627023496 170:0.109375:11289:11296 247:0.515625:11290:11291 ~0.0030130171974814494 90:0.7265625:11292:11295 251:0.109375:11293:11294 ~0.05091073210976236 ~-0.03644003158102335 ~0.05232661022733323 "
    s .= "86:0.1875:11297:11306 82:-0.046875:11298:11301 136:0.453125:11299:11300 ~-0.052264382768346364 ~0.028529141919047648 253:-0.10476190476190653:11302:11305 240:0.296875:11303:11304 ~0.02974089963769926 "
    s .= "~-0.05941834694337677 ~-0.03133776667926584 112:0.609375:11307:11310 154:0.078125:11308:11309 ~0.012205718006591482 ~-0.02903657860919916 254:0.484375:11311:11314 169:0.234375:11312:11313 ~0.03770533876504238 "
    s .= "~-0.013331529953217009 ~-0.015294328667224003 112:1.140625:11316:11317 ~0.03894617647647566 ~-0.03726942494755493 ~0.053581163708333504 91:-0.140625:11320:11323 28:0.078125:11321:11322 ~-0.017357044983484716 "
    s .= "~0.07558285244096191 134:0.421875:11324:11327 209:0.03125:11325:11326 ~-0.0357959461583789 ~0.03219980810627573 ~-0.0486026652270878 219:0.953125:11329:11374 201:0.75:11330:11373 244:0.78:11331:11338 "
    s .= "133:0.015625:11332:11337 241:0.56:11333:11334 ~-0.033093088553812815 243:1.25:11335:11336 ~0.08441053316409391 ~-0.036497742921765546 ~-0.04073644505840515 93:0.703125:11339:11370 237:0.484375:11340:11365 "
    s .= "107:0.171875:11341:11362 122:-0.78125:11342:11343 ~0.010934122887362036 95:-0.859375:11344:11345 ~-0.0276142571776155 106:1.828125:11346:11359 250:1.1484375:11347:11358 202:-0.140625:11348:11349 ~-0.029540985382093973 "
    s .= "121:0.125:11350:11351 ~0.0058003265068631935 231:0.09375:11352:11357 120:0.15625:11353:11356 208:0.421875:11354:11355 ~-0.05244784593558636 ~0.00034971321807149026 ~0.029052524895062104 ~0.004461754224421118 "
    s .= "~0.012321170007314185 221:-0.53125:11360:11361 ~0.022223270343400367 ~-0.03886414602157626 22:-0.234375:11363:11364 ~-0.020458601691684848 ~0.015413619028213775 40:-0.0625:11366:11367 ~0.014324470831019929 "
    s .= "128:-0.140625:11368:11369 ~0.002807869886776105 ~-0.04449040009179138 237:0.5625:11371:11372 ~-0.048434218251180584 ~0.02242977037808029 ~0.022949184440876413 ~-0.04110485634752001 238:0.53125:11376:11405 "
    s .= "208:0.734375:11377:11402 196:1.078125:11378:11401 195:-0.421875:11379:11380 ~-0.019162781595627437 105:-0.4921875:11381:11382 ~0.023301493145740725 109:1.703125:11383:11394 46:0.71875:11384:11391 58:0.859375:11385:11386 "
    s .= "~-0.0025417363115133665 181:0.328125:11387:11388 ~0.03160620705081875 250:1.0703125:11389:11390 ~-0.038417890991167436 ~0.02644507441996863 242:0.6499999999999999:11392:11393 ~0.04739678779662476 ~-0.014998717913446214 "
    s .= "133:0.90625:11395:11396 ~-0.05152026770483679 199:0.140625:11397:11400 107:0.21875:11398:11399 ~-0.03540415818582109 ~0.01930261145566509 ~0.017532413341968946 ~0.02454990861216297 187:-0.203125:11403:11404 "
    s .= "~-0.0409305477433642 ~0.019386495665740428 242:0.6499999999999999:11406:11413 199:-0.078125:11407:11408 ~0.041706951469777966 196:-0.03125:11409:11410 ~-0.048769821986683136 112:0.171875:11411:11412 "
    s .= "~-0.05460440934821928 ~0.01512077008929521 211:0.25:11414:11417 37:-0.125:11415:11416 ~-0.05354636831685383 ~0.016859695874397396 147:-0.40625:11418:11419 ~0.00975394452992407 216:-0.625:11420:11421 ~-0.1565823108963682 "
    s .= "~-0.047726527066390974 253:-0.07269338303821087:11423:11452 252:0.175:11424:11437 181:-0.265625:11425:11426 ~-0.08124416746532866 208:0.828125:11427:11436 257:0.4090909090909091:11428:11435 146:0.109375:11429:11432 "
    s .= "123:-0.1875:11430:11431 ~-0.0326680693286021 ~0.01637630530840554 249:0.16666666666666666:11433:11434 ~0.0004912314856714197 ~-0.06286978386340865 ~-0.045428024667979315 ~0.03867087016025131 244:0.92:11438:11441 "
    s .= "181:0.09375:11439:11440 ~0.03598802374804829 ~-0.04379787048616425 245:1.5154639175257731:11442:11445 135:0.1015625:11443:11444 ~-0.07427979262219422 ~0.0240918124108737 153:0.6796875:11446:11451 214:0.28125:11447:11450 "
    s .= "67:-0.28125:11448:11449 ~-0.011546829333592194 ~0.03959374316077219 ~0.003754354175532482 ~-0.04298869276759447 243:1.35:11453:11464 245:1.9456521739130435:11454:11463 227:-0.640625:11455:11456 ~-0.014807623638937043 "
    s .= "72:0.34375:11457:11460 46:0.15625:11458:11459 ~0.020274636633764376 ~-0.005679285842599442 156:0.6328125:11461:11462 ~-0.021022007147526056 ~0.06050280205846886 ~-0.004997934706099141 251:1.390625:11465:11468 "
    s .= "58:0.5625:11466:11467 ~-0.04673482306659622 ~0.0030002973702781452 ~0.009606559191405701 126:0.984375:11470:11515 254:0.984375:11471:11488 223:1.875:11472:11487 146:-0.4375:11473:11474 ~0.008977112117419486 "
    s .= "246:0.171875:11475:11482 242:0.55:11476:11479 95:-0.40625:11477:11478 ~-0.02761305878030746 ~0.010105644094798154 147:0:11480:11481 ~-0.004119582906746973 ~-0.030728047056092653 254:0.765625:11483:11484 "
    s .= "~0.0001344031059247572 159:0.1328125:11485:11486 ~0.002814782400434689 ~0.04992814511318104 ~-0.06766927060138948 26:-0.140625:11489:11512 164:-0.21875:11490:11503 244:1.22:11491:11494 9:-0.2890625:11492:11493 "
    s .= "~0.011530995887354623 ~-0.045819497457990195 201:-0.15625:11495:11500 244:1.885:11496:11497 ~-0.04321560842386559 238:1.015625:11498:11499 ~0.02017501256760146 ~-0.07314095764694363 136:2.265625:11501:11502 "
    s .= "~0.0193419704010829 ~-0.05833275373747639 95:-0.390625:11504:11507 190:-0.046875:11505:11506 ~-0.04372260838019018 ~0.04681691452102968 226:0.15625:11508:11511 255:0.203125:11509:11510 ~0.028735660479495207 "
    s .= "~-0.039953782068830414 ~0.023996619315545184 250:1.0546875:11513:11514 ~-0.04503737769108584 ~0.0008901466186699404 ~-0.05394798893857816 77:0.625:11517:11562 256:0.01639344262295082:11518:11551 39:0.4375:11519:11548 "
    s .= "8:0.625:11520:11547 34:0.046875:11521:11522 ~0.003933943381517812 163:1.203125:11523:11546 244:2.79:11524:11545 252:0.025:11525:11536 82:0.046875:11526:11529 97:0.078125:11527:11528 ~0.0015683281660416046 "
    s .= "~0.059096409290144626 251:0.453125:11530:11531 ~-0.029859378277202864 248:0.125:11532:11533 ~-0.04589977588380081 251:0.953125:11534:11535 ~0.03455497497969504 ~-0.015942796776708273 220:0.8125:11537:11544 "
    s .= "244:1.585:11538:11543 243:0.95:11539:11540 ~-0.0386297342995968 245:1.793103448275862:11541:11542 ~-0.040794630904366566 ~0.009632201245528353 ~0.01192968038769769 ~0.042819814433152976 ~-0.06034027295671512 "
    s .= "~0.015164802895634405 ~0.052438009282431676 168:0.109375:11549:11550 ~-0.042487386087208964 ~0.0018542520303988846 20:0.5:11552:11559 144:-0.265625:11553:11554 ~-0.05194827050677575 251:0.828125:11555:11558 "
    s .= "3:0.015625:11556:11557 ~-0.042940911705991236 ~0.011626590760565299 ~0.026093475618397234 118:-0.15625:11560:11561 ~0.03930652066702336 ~-0.048462924219943165 ~-0.01728570500375785 5:-1.484375:11564:11567 "
    s .= "25:0.203125:11565:11566 ~0.04269652153342259 ~-0.0207695785291571 246:-1.984375:11568:11581 244:1.49:11569:11576 26:-0.75:11570:11575 254:0.640625:11571:11574 233:-0.640625:11572:11573 ~0.016904581709921648 "
    s .= "~-0.05064551413095103 ~-0.04002520036014319 ~-0.051037755032583114 190:0.03125:11577:11580 153:-0.7890625:11578:11579 ~0.0362034472091816 ~-0.03971133538992016 ~0.02121126404238313 56:-0.8125:11582:11583 "
    s .= "~0.014493106634483797 181:2.140625:11584:11609 255:0.234375:11585:11598 255:0.109375:11586:11587 ~-0.0016634060996942174 219:0.140625:11588:11597 209:0:11589:11592 118:0.203125:11590:11591 ~0.02901438886922002 "
    s .= "~-0.027833189661630717 107:0.125:11593:11594 ~-0.034728633463332485 236:0.34375:11595:11596 ~0.025009650517132127 ~-0.038622102150300736 ~0.023753148526992965 244:0.91:11599:11600 ~-0.0350409947598541 "
    s .= "257:0.30434782608695654:11601:11604 132:-0.1328125:11602:11603 ~0.01654406611959849 ~-0.007263798730896574 34:-0.234375:11605:11606 ~0.034553512202235896 59:0:11607:11608 ~-0.057854505374185766 ~0.03646526184737722 "
    s .= "~-0.05111194032305369 253:-0.07269338303821087:11611:11640 252:0.475:11612:11637 61:0.859375:11613:11636 58:0.046875:11614:11619 126:0.109375:11615:11618 211:0.03125:11616:11617 ~-0.037215637258998596 "
    s .= "~0.011047977093087209 ~0.03293675447085923 154:0.703125:11620:11633 34:0.1875:11621:11626 243:1.35:11622:11625 130:0.109375:11623:11624 ~0.03281852677902471 ~-0.02684978957648881 ~-0.13117527142421928 "
    s .= "82:1.546875:11627:11630 209:-0.890625:11628:11629 ~0.020853465806529303 ~-0.0559145541876577 52:0.125:11631:11632 ~-0.03361905324845401 ~-0.22193172804532094 205:-0.078125:11634:11635 ~-0.04942427273642089 "
    s .= "~0.03074176373585808 ~0.02227739224023951 34:-0.25:11638:11639 ~-0.02999167428342807 ~0.030850103544654253 243:1.35:11641:11648 245:1.9456521739130435:11642:11647 227:-0.640625:11643:11644 ~-0.013868493342802386 "
    s .= "72:0.359375:11645:11646 ~0.013635539541654532 ~-0.010918992913470815 ~-0.004869669316512873 251:1.390625:11649:11656 58:0.5625:11650:11651 ~-0.045361247251603704 248:0.375:11652:11655 "
    s .= "253:-0.02499999999999858:11653:11654 ~0.02298186373927852 ~-0.05526929650329766 ~0.03571409652726486 ~0.009114469869753712 203:0.734375:11658:11703 11:0.90625:11659:11702 2:0.5625:11660:11701 89:0.78125:11661:11696 "
    s .= "142:-0.65625:11662:11663 ~-0.04047446377349858 19:-0.5625:11664:11665 ~0.024406500220410215 245:3.459016393442623:11666:11693 244:1.64:11667:11674 130:0.1875:11668:11671 121:0.5:11669:11670 ~0.01333067106969476 "
    s .= "~-0.051448858263639353 220:0.8125:11672:11673 ~-0.007687094129839503 ~0.02394500691991203 157:0.25:11675:11680 85:0.140625:11676:11679 79:-0.09375:11677:11678 ~0.021443521177880464 ~-0.04768953256845944 "
    s .= "~0.013914937776082853 94:0.734375:11681:11692 244:2.79:11682:11683 ~0.025711334267371874 252:0.275:11684:11687 7:0.0625:11685:11686 ~0.029097147275036452 ~-0.053000719554393685 91:0.328125:11688:11691 "
    s .= "187:0.296875:11689:11690 ~-0.14549814084512672 ~-0.034006161415942676 ~0.0250755747791175 ~-0.032738926719165444 87:-0.3984375:11694:11695 ~0.035339135132661834 ~-0.03615422371247362 112:0.984375:11697:11700 "
    s .= "191:0.59375:11698:11699 ~0.0497149024041716 ~-0.03247125053295811 ~-0.034144901722560954 ~-0.022912387867847345 ~0.03695327413299917 ~-0.027673187909890193 238:0.53125:11705:11732 208:0.734375:11706:11731 "
    s .= "205:0.96875:11707:11730 181:1.4375:11708:11727 61:1.15625:11709:11726 55:0.671875:11710:11721 10:1.265625:11711:11720 110:-1.125:11712:11713 ~-0.030701005452870606 122:-0.8125:11714:11717 92:-0.609375:11715:11716 "
    s .= "~0.029822278687582873 ~-0.016723136364729396 184:0.78125:11718:11719 ~-0.0066556151054710695 ~0.013134970589571136 ~0.05468082720698091 251:0.234375:11722:11723 ~-0.04449119882321702 172:0.640625:11724:11725 "
    s .= "~0.025643089351045752 ~-0.028788406496878544 ~0.01835799893258901 82:1.46875:11728:11729 ~0.00012773166956975214 ~-0.051396029911181 ~0.023475062460670146 ~0.014482163342542634 242:0.6499999999999999:11733:11742 "
    s .= "199:-0.078125:11734:11737 52:0.328125:11735:11736 ~0.05379125594978651 ~-0.04300409674407189 196:-0.03125:11738:11739 ~-0.047358868373014944 112:0.171875:11740:11741 ~-0.053892040662962805 ~0.014268982291612081 "
    s .= "211:0.25:11743:11748 76:-0.140625:11744:11745 ~-0.05361580263788154 208:-0.09375:11746:11747 ~-0.038643032532376935 ~0.03774272508644563 147:-0.40625:11749:11750 ~0.009253321456560392 ~-0.054111009033140194 "
    s .= "41:0.546875:11752:11789 11:0.71875:11753:11788 89:0.78125:11754:11785 74:-0.140625:11755:11762 246:-0.578125:11756:11761 128:-0.453125:11757:11760 247:-0.046875:11758:11759 ~0.005291055793689288 ~-0.037421073143718 "
    s .= "~-0.018593624422442622 ~0.009470496770341182 249:0.16666666666666666:11763:11780 34:-0.0625:11764:11767 51:-0.0390625:11765:11766 ~-0.020828052513067536 ~0.026252051335607166 8:0.390625:11768:11779 91:0.6875:11769:11778 "
    s .= "130:1.328125:11770:11775 135:-0.0546875:11771:11774 246:-1.015625:11772:11773 ~-0.03746906585971336 ~0.04071053543143585 ~-0.020541787556734553 80:0.40625:11776:11777 ~-0.049113776393175344 ~0.038303472370148646 "
    s .= "~0.01817169655361425 ~0.029719092053094583 195:0.171875:11781:11782 ~-0.02182834564409325 44:-0.0625:11783:11784 ~0.019069794018151256 ~-0.012026308951190723 112:1.140625:11786:11787 ~0.03636570610029692 "
    s .= "~-0.0336413537755742 ~0.05154574184181907 91:-0.140625:11790:11795 76:0.234375:11791:11792 ~-0.004848144892653725 163:0.140625:11793:11794 ~0.1714254290384083 ~0.01186478081496792 134:0.421875:11796:11797 "
    s .= "~-0.0021257710663573817 ~-0.04728883981975562 247:0.796875:11799:11842 111:0.3828125:11800:11837 237:0.484375:11801:11828 106:0.046875:11802:11809 245:1.8405797101449275:11803:11804 ~0.008611642159627274 "
    s .= "157:0.421875:11805:11806 ~-0.04184323897912145 133:1.359375:11807:11808 ~0.010064763545917704 ~-0.035388236678078465 7:0.90625:11810:11825 244:0.78:11811:11812 ~-0.03383590136069601 107:0.09375:11813:11822 "
    s .= "194:0.140625:11814:11817 247:0.203125:11815:11816 ~0.005496531220050345 ~-0.023405660878948614 244:1.47:11818:11819 ~-0.04341417417371593 25:-0.09375:11820:11821 ~0.04517853504083201 ~-0.022623537105082935 "
    s .= "22:-0.1875:11823:11824 ~-0.011602440523259086 ~0.017612244411203414 245:1.596774193548387:11826:11827 ~0.052408618339578654 ~-0.03695988271228971 34:-0.265625:11829:11832 245:1.975:11830:11831 ~-0.030631678494510695 "
    s .= "~0.04852756830864068 88:1.078125:11833:11836 109:-0.09375:11834:11835 ~0.03568859938293559 ~-0.03848471231449255 ~0.019916890215138247 250:1.1953125:11838:11839 ~-0.00929283193762522 249:0.5:11840:11841 "
    s .= "~0.010481433301089322 ~0.07743216035157713 237:0.578125:11843:11844 ~-0.042597862321659186 ~0.027066951875559797 217:0.1875:11846:11863 238:0.359375:11847:11856 76:0.4375:11848:11855 184:0.109375:11849:11852 "
    s .= "241:0.52:11850:11851 ~-0.010579005189376848 ~0.01225854541839264 191:-0.046875:11853:11854 ~0.014621568980299024 ~-0.004362026675410742 ~0.01603406097848386 242:1.35:11857:11862 136:0.828125:11858:11861 "
    s .= "214:-0.046875:11859:11860 ~0.04536682363963416 ~-0.031088252292597186 ~0.008228072661693562 ~-0.052760144816715954 163:0.34375:11864:11875 115:0.140625:11865:11870 235:0.03125:11866:11867 ~0.005882450062501508 "
    s .= "58:0.515625:11868:11869 ~-0.044077177990101725 ~0.02806440051398772 196:0.140625:11871:11872 ~-0.018907533358368922 243:1.05:11873:11874 ~0.025908342495596343 ~-0.018611129066898543 19:-0.5625:11876:11877 "
    s .= "~0.029974174664750077 22:0.125:11878:11881 251:1.015625:11879:11880 ~-0.04917100803907003 ~-0.01040576673219048 163:1.40625:11882:11889 108:0.4140625:11883:11888 64:0.28125:11884:11887 98:-0.078125:11885:11886 "
    s .= "~0.01660303452846856 ~-0.05583806129862593 ~-0.047316378436768045 ~0.08797686308327721 118:0.59375:11890:11891 ~0.0374834967152848 ~-0.0938090491680097 126:0.984375:11893:11938 254:0.984375:11894:11913 "
    s .= "97:0.84375:11895:11908 97:0.6875:11896:11905 125:-0.59375:11897:11900 151:0.1875:11898:11899 ~0.024830866604684206 ~-0.0011190125101876486 96:-0.2421875:11901:11902 ~-0.023302984516486033 246:-2.265625:11903:11904 "
    s .= "~-0.03862617766154887 ~0.0019155406851745543 150:-0.1015625:11906:11907 ~-0.03132661011706041 ~0.057001492825820614 245:2.0125:11909:11912 195:0.09375:11910:11911 ~-0.02382968343403048 ~0.05305335893918667 "
    s .= "~-0.04237004380704829 250:1.0546875:11914:11935 26:-0.171875:11915:11934 164:-0.21875:11916:11929 76:0.015625:11917:11924 186:-0.3125:11918:11919 ~0.03340658532245875 141:0.0078125:11920:11923 241:0.86:11921:11922 "
    s .= "~-0.05080792633560915 ~0.020515620304859688 ~0.0235210018986542 244:1.235:11925:11926 ~-0.06055585113976575 55:-0.15625:11927:11928 ~-0.10497312645862876 ~-0.010007018726521126 49:0.078125:11930:11933 "
    s .= "143:-0.359375:11931:11932 ~0.04463483306085386 ~-0.025429790237307088 ~0.04252997935479746 ~-0.04300546775101392 241:0.54:11936:11937 ~-0.007844951523843414 ~0.027187278372090413 ~-0.05309390759297547 "
    s .= "144:-0.796875:11940:11943 115:0.390625:11941:11942 ~0.01112182149522778 ~-0.051304131383765106 9:-0.6484375:11944:11947 25:0.234375:11945:11946 ~0.04013966228723038 ~-0.01568592613531234 205:-0.5:11948:11949 "
    s .= "~-0.03350622340165154 85:-0.375:11950:11961 14:-0.3125:11951:11952 ~-0.02213156206078278 25:0.265625:11953:11956 151:0.015625:11954:11955 ~-0.034263381486208735 ~0.0418307552591107 136:-0.078125:11957:11960 "
    s .= "76:0.21875:11958:11959 ~-0.020778126042658218 ~0.2773933059202639 ~0.03340385444455068 245:1.1578947368421053:11962:11963 ~-0.031904579422259174 250:1.1796875:11964:11971 159:0.3359375:11965:11968 "
    s .= "28:0.828125:11966:11967 ~0.00038690011153688875 ~-0.04534984464349399 178:0.09375:11969:11970 ~-0.004768212476415151 ~-0.05138704285465593 111:0.2578125:11972:11985 237:0.5625:11973:11982 169:-0.046875:11974:11977 "
    s .= "160:-0.109375:11975:11976 ~-0.022703803931058704 ~0.025260292443371087 196:0.015625:11978:11981 163:1.53125:11979:11980 ~-0.008317422074324525 ~-0.06418145561536276 ~0.005898799170383142 88:1.609375:11983:11984 "
    s .= "~-0.04176448616690926 ~0.031159515712831234 ~0.027103327012341662 33:0.984375:11987:12032 11:0.90625:11988:12029 50:0.71875:11989:12028 142:-0.65625:11990:11991 ~-0.03671970905971161 19:-0.5625:11992:11993 "
    s .= "~0.022442562247217746 124:0.203125:11994:12007 61:0.46875:11995:12000 37:0.375:11996:11997 ~-0.0018593959631222465 49:0.03125:11998:11999 ~-0.013457228114925047 ~0.04735341051314141 181:1.078125:12001:12004 "
    s .= "67:0.46875:12002:12003 ~0.02549100212155287 ~-0.00812303313309785 13:0.0625:12005:12006 ~0.006090417908634217 ~-0.05709829247188576 19:-0.140625:12008:12015 10:-0.234375:12009:12014 187:0.1875:12010:12011 "
    s .= "~-0.044313324476365115 43:-0.25:12012:12013 ~-0.010819280176066318 ~0.04718612323970754 ~-0.03724467583054574 64:0.3125:12016:12021 6:0.46875:12017:12018 ~0.010414202679691684 256:0.04854368932038835:12019:12020 "
    s .= "~-0.050817382653339786 ~0.014380302777925442 184:0.296875:12022:12023 ~0.002334574946311044 84:0.3046875:12024:12025 ~-0.0410616781014676 133:0.984375:12026:12027 ~-0.023623034508114028 ~0.0818246154636558 "
    s .= "~-0.038258610376297714 176:0.671875:12030:12031 ~0.050662248569093876 ~-0.039530850549514225 ~-0.04552468623248134 219:0.953125:12034:12079 201:0.75:12035:12078 72:0.78125:12036:12077 247:0.796875:12037:12074 "
    s .= "116:0.796875:12038:12073 245:1.3571428571428572:12039:12042 247:0.671875:12040:12041 ~-0.032990542785141 ~0.10055206761933627 256:0.01639344262295082:12043:12068 36:0.4375:12044:12063 106:0.078125:12045:12054 "
    s .= "160:-0.015625:12046:12047 ~-0.04078622000710773 127:0.546875:12048:12053 109:0.28125:12049:12052 37:0.53125:12050:12051 ~-0.0250599715789882 ~0.055844253703195984 ~0.018137714571148097 ~-0.03770539953127904 "
    s .= "67:0.171875:12055:12056 ~0.007043581916128238 2:-0.03125:12057:12060 37:0.765625:12058:12059 ~0.0032549441426974815 ~-0.05094485509770317 129:0.3359375:12061:12062 ~-0.03503037354604278 ~0.03589702120556197 "
    s .= "168:0.109375:12064:12067 34:0.3125:12065:12066 ~-0.05094596383190554 ~0.023867332148048478 ~0.005254008347384406 34:0.65625:12069:12072 19:-0.234375:12070:12071 ~-0.018122931576001606 ~0.024444346887988008 "
    s .= "~-0.04469982168959358 ~0.024561961325696137 127:0.03125:12075:12076 ~0.011630572455598846 ~-0.05387597578771067 ~-0.03252606508848079 ~0.021893051273089055 ~-0.039993761130159455 191:0.796875:12081:12126 "
    s .= "246:1.796875:12082:12125 247:0.765625:12083:12124 111:0.3828125:12084:12119 237:0.484375:12085:12112 106:0.046875:12086:12097 245:1.8405797101449275:12087:12088 ~0.008843752944100973 157:0.46875:12089:12092 "
    s .= "40:0.109375:12090:12091 ~-0.05045239954953027 ~0.004449024043963334 133:1.359375:12093:12096 88:0.03125:12094:12095 ~-0.025996254475996412 ~0.03592217433687741 ~-0.03347412314285225 7:0.90625:12098:12109 "
    s .= "107:0.09375:12099:12108 194:0.140625:12100:12103 247:0.203125:12101:12102 ~0.004577810696076263 ~-0.02288338154445367 244:1.47:12104:12105 ~-0.0424589866971454 25:-0.09375:12106:12107 ~0.044380820484920175 "
    s .= "~-0.021455980133996 ~0.011719326378748063 245:1.596774193548387:12110:12111 ~0.049710130797361335 ~-0.03577198032523664 34:-0.265625:12113:12116 245:1.975:12114:12115 ~-0.03010135282179916 ~0.04748862093436144 "
    s .= "88:1.0625:12117:12118 ~-0.03145776649259912 ~0.021173567457404462 195:0.0625:12120:12121 ~-0.03656500815965761 249:0.5:12122:12123 ~0.003700085217151833 ~0.057741040120505405 ~-0.028045381325567855 ~0.031374490162343505 "
    s .= "~-0.02977885453094811 242:2.25:12128:12169 252:1.875:12129:12164 243:1.45:12130:12161 245:2.2:12131:12132 ~0.0036683140029537494 191:0:12133:12156 7:-0.296875:12134:12137 199:-0.078125:12135:12136 ~-0.035522123894833356 "
    s .= "~0.03540813187632634 154:0.625:12138:12147 178:0.5:12139:12146 169:-0.28125:12140:12141 ~0.031252231961530194 133:0.421875:12142:12143 ~0.002062415330117313 91:0.84375:12144:12145 ~-0.052415680142717885 "
    s .= "~0.0031037647715067476 ~0.019126413242230418 151:0.78125:12148:12151 172:-0.203125:12149:12150 ~-0.044407200642362456 ~0.028229234626193773 1:0.140625:12152:12155 248:0.125:12153:12154 ~-0.05349506796139304 "
    s .= "~0.012523759681331745 ~0.02367928686383622 130:0.59375:12157:12160 118:0.015625:12158:12159 ~-0.03839040039185377 ~0.01630202570435543 ~-0.03653488536704748 73:0.265625:12162:12163 ~-0.03232243987058358 "
    s .= "~0.016715044781647526 253:-0.0165111833846857:12165:12166 ~0.033199348889771926 85:0.859375:12167:12168 ~0.01700680417491827 ~-0.03347521391305441 130:0.953125:12170:12173 251:2.046875:12171:12172 ~-0.05566889962502114 "
    s .= "~0.021718389720237204 ~0.011495207899313728 253:-0.10476190476190653:12175:12200 252:0.125:12176:12187 211:0.546875:12177:12186 99:-0.25:12178:12181 210:-0.015625:12179:12180 ~-0.03282513539256928 ~-0.19472001172827644 "
    s .= "14:-0.515625:12182:12183 ~0.025245793727851365 154:0.984375:12184:12185 ~-0.0330248763093399 ~0.01627461016952852 ~0.038953864867791455 25:0.9375:12188:12199 46:-0.265625:12189:12194 163:0.40625:12190:12193 "
    s .= "54:0.6640625:12191:12192 ~0.026459043046808822 ~-0.06259704147438727 ~-0.07753591506729082 257:0.8888888888888888:12195:12198 244:0.92:12196:12197 ~-0.011602388198008927 ~0.03718353736711195 ~-0.03323692390865309 "
    s .= "~-0.0792684450802589 174:-0.46875:12201:12204 45:-0.1328125:12202:12203 ~-0.003206252186348846 ~-0.0440452743026426 57:-0.4921875:12205:12208 46:0.328125:12206:12207 ~0.03368745741067796 ~-0.04535786648367098 "
    s .= "110:-1.328125:12209:12210 ~-0.03332849648464011 139:0.5:12211:12220 40:0.359375:12212:12217 106:0.59375:12213:12216 111:0.2578125:12214:12215 ~-0.019993001729302882 ~0.008214307359508198 ~0.000787095473893485 "
    s .= "104:0.140625:12218:12219 ~0.027588809143083398 ~-0.016473392866129664 ~0.005167799904158097 217:0.1875:12222:12235 238:0.359375:12223:12226 76:0.4375:12224:12225 ~0.0012439161222361494 ~0.015359008032056013 "
    s .= "242:1.35:12227:12234 136:0.828125:12228:12231 214:-0.046875:12229:12230 ~0.0433296033578128 ~-0.029583005928972162 175:0.234375:12232:12233 ~0.017726570581348133 ~-0.024451098425885245 ~-0.051252403638191626 "
    s .= "163:0.328125:12236:12253 115:0.140625:12237:12242 166:-0.03125:12238:12239 ~0.006548034834388552 202:-0.109375:12240:12241 ~0.02143117387477075 ~-0.039158958728661535 196:0.140625:12243:12244 ~-0.018021173592885773 "
    s .= "243:1.05:12245:12252 187:0.265625:12246:12249 142:0.21875:12247:12248 ~0.02418196004105188 ~-0.0250817815414081 55:0.46875:12250:12251 ~0.052663770581001926 ~-0.04921630340999975 ~-0.01747960530069878 "
    s .= "61:-0.390625:12254:12255 ~0.022600771325707276 244:1.48:12256:12261 250:1.3046875:12257:12260 209:-0.875:12258:12259 ~-0.004110017260640647 ~-0.050084774861115434 ~-0.0038077249058845134 116:-1.234375:12262:12263 "
    s .= "~-0.07743451275322205 73:-0.21875:12264:12265 ~-0.067453760071974 178:0.203125:12266:12267 ~-0.03105333596833002 ~0.02507453460657477 190:-0.328125:12269:12274 82:0.515625:12270:12271 ~-0.03122573599286222 "
    s .= "118:0.1875:12272:12273 ~0.010918408106749402 ~-0.050473383270981304 243:2.05:12275:12312 252:1.8250000000000002:12276:12305 242:1.35:12277:12302 98:0.625:12278:12301 244:1.125:12279:12292 133:0.296875:12280:12281 "
    s .= "~0.028669196467824266 245:1.6346153846153846:12282:12283 ~-0.0243459880523968 242:0.45:12284:12289 190:0.140625:12285:12288 136:0.109375:12286:12287 ~0.03869415529805047 ~-0.04699260877187599 ~0.017356135775718186 "
    s .= "214:0.203125:12290:12291 ~0.03316240811367709 ~-0.010419544782461498 245:1.8448275862068966:12293:12296 100:-0.0625:12294:12295 ~0.036386467477770926 ~0.002879610645693397 199:0.03125:12297:12298 ~-0.019030917636884324 "
    s .= "243:0.25:12299:12300 ~-0.050636344533728 ~0.004476518655133251 ~-0.03154683859577905 251:1.265625:12303:12304 ~-0.03193692748529645 ~0.01177576236634835 244:1.025:12306:12307 ~-0.016519146112066833 252:3.325:12308:12309 "
    s .= "~0.03850326246378627 45:0.1953125:12310:12311 ~-0.04389903766702532 ~0.04333306264519429 112:0.484375:12313:12314 ~-0.04444058322544684 ~0.013312630838549378 166:2.125:12316:12361 205:1.1875:12317:12354 "
    s .= "144:-0.796875:12318:12319 ~-0.029349436077663205 12:-0.65625:12320:12321 ~0.02718917352323535 110:-1.328125:12322:12325 90:-0.4453125:12323:12324 ~0.0040821573652644666 ~-0.04766993948294315 "
    s .= "245:3.459016393442623:12326:12351 233:0.75:12327:12350 100:1.046875:12328:12343 226:0.96875:12329:12340 46:0.71875:12330:12335 248:0.875:12331:12334 109:-0.21875:12332:12333 ~0.03343868798115625 ~-0.0012400463895459925 "
    s .= "~-0.0157349899679563 241:0.26:12336:12339 121:-0.140625:12337:12338 ~-0.04956876376152406 ~0.04570383744044918 ~-0.022230600206347016 49:0.375:12341:12342 ~0.029117234777777914 ~-0.06156695941230944 "
    s .= "223:0.4375:12344:12349 244:0.835:12345:12346 ~0.1547828816488732 70:0.71875:12347:12348 ~0.021862341616416994 ~-0.046498071021358445 ~-0.05342054458495343 ~-0.04256492030701652 67:-0.140625:12352:12353 "
    s .= "~0.019469371705793624 ~-0.04530420338678315 202:0.90625:12355:12358 124:1.296875:12356:12357 ~0.03585073886529196 ~-0.033328343328925654 237:0.3125:12359:12360 ~-0.029032285787510128 ~0.03449202417050631 "
    s .= "~-0.03957821650895484 77:0.546875:12363:12408 256:0.01639344262295082:12364:12399 247:0.515625:12365:12398 132:0.3671875:12366:12397 66:0.5625:12367:12396 247:0.203125:12368:12389 50:-0.171875:12369:12376 "
    s .= "246:-0.609375:12370:12375 167:-0.3125:12371:12374 250:0.6328125:12372:12373 ~-0.04797977367276189 ~0.004420084125314132 ~-0.021785912424282846 ~0.01555209563300124 217:0.21875:12377:12388 "
    s .= "245:1.9107142857142858:12378:12385 227:-0.59375:12379:12380 ~-0.03935696484103496 241:0.38:12381:12382 ~0.02586837365935557 163:1.5:12383:12384 ~0.004151470576271602 ~-0.07008342491223729 155:-0.265625:12386:12387 "
    s .= "~0.015529854419546033 ~-0.019348583668037656 ~-0.027515631652471947 120:0.359375:12390:12395 101:-0.140625:12391:12392 ~-0.052778511782119744 178:0.15625:12393:12394 ~0.01602658290743072 ~-0.03575227550006713 "
    s .= "~0.01290157038016878 ~-0.038384095699969485 ~0.02525492616156258 ~-0.029983844117978754 54:-0.1171875:12400:12401 ~-0.02716530197156286 191:0.46875:12402:12405 243:1.35:12403:12404 ~0.028992625802463413 "
    s .= "~-0.006117174607913451 163:-0.109375:12406:12407 ~0.03960460359773305 ~-0.026525159439001675 ~-0.013550313199642842 254:0.984375:12410:12431 44:-0.75:12411:12414 25:0.046875:12412:12413 ~0.024207310267221102 "
    s .= "~-0.005294094964563068 217:0.21875:12415:12428 103:1.828125:12416:12425 79:0.28125:12417:12418 ~-0.0006032287351496317 187:0.265625:12419:12422 251:0.234375:12420:12421 ~-0.02566144403373155 ~0.024069787565481095 "
    s .= "97:-0.265625:12423:12424 ~-0.05501774555701438 ~0.0048693143023854826 218:0.4375:12426:12427 ~-0.04009984170938691 ~0.03631289753848526 243:0.25:12429:12430 ~0.026909533997256707 ~-0.014240806544247371 "
    s .= "250:1.0546875:12432:12453 26:-0.171875:12433:12452 164:-0.21875:12434:12445 76:0.015625:12435:12440 186:-0.3125:12436:12437 ~0.03186544274310789 141:0.0078125:12438:12439 ~-0.03287274465553064 ~0.022763236820991184 "
    s .= "244:1.225:12441:12442 ~-0.06045075369730966 55:-0.15625:12443:12444 ~-0.09725085312032676 ~-0.010128286707659202 49:0.078125:12446:12451 116:-0.4375:12447:12448 ~0.04951135900024138 208:0.390625:12449:12450 "
    s .= "~-0.044357612160560174 ~0.01936681940035802 ~0.04083292422149542 ~-0.041486068333825364 243:0.6499999999999999:12454:12455 ~-0.01322468668010208 ~0.01964861608458518 187:-0.3125:12457:12464 16:0.21875:12458:12461 "
    s .= "57:-0.6328125:12459:12460 ~0.03785327116173192 ~-0.03314978122469819 172:-0.125:12462:12463 ~-0.037112551971338156 ~0.036431018435461586 61:-0.421875:12465:12468 148:-0.46875:12466:12467 ~-0.047186890755470945 "
    s .= "~0.026409218615327204 205:1.1875:12469:12500 211:0.1875:12470:12477 109:1.734375:12471:12474 133:1.90625:12472:12473 ~0.0054574475784180745 ~-0.027648047252291204 70:0.015625:12475:12476 ~0.002285796962854256 "
    s .= "~-0.03229866937055521 136:1.3125:12478:12497 85:1.390625:12479:12496 244:2.79:12480:12495 67:-0.140625:12481:12482 ~-0.03879914700081765 55:0.09375:12483:12490 184:0:12484:12485 ~-0.061309913533962396 "
    s .= "245:1.5529411764705883:12486:12487 ~-0.030288680692655195 220:-0.078125:12488:12489 ~-0.021625702948073765 ~0.02703529385981486 166:0.984375:12491:12494 226:-0.390625:12492:12493 ~0.041373825420062314 "
    s .= "~-0.02802229446595511 ~0.039284475525041114 ~-0.07833100927312975 ~0.021354240484608718 235:-0.03125:12498:12499 ~-0.038652777785995025 ~0.01774862208171941 166:1.6875:12501:12502 ~0.023585422133297958 "
    s .= "~-0.04742809708351303 253:-0.07269338303821087:12504:12537 252:0.475:12505:12534 154:0.75:12506:12527 34:0.171875:12507:12520 242:0.95:12508:12519 252:0.125:12509:12516 178:0.453125:12510:12515 171:0.375:12511:12514 "
    s .= "187:0.609375:12512:12513 ~-0.047634065525393336 ~0.025071161346005885 ~0.03927537468525153 ~0.026322882181876846 214:0.59375:12517:12518 ~0.03339795173154383 ~-0.05164909948622303 ~-0.04537101597142122 "
    s .= "61:0.859375:12521:12526 244:1.55:12522:12525 82:1.546875:12523:12524 ~-0.05128017960795921 ~-0.16969150925984167 ~-0.0016906608215807432 ~0.018353972110307062 196:0.015625:12528:12531 13:-0.078125:12529:12530 "
    s .= "~0.02540557438816575 ~-0.04302117955633152 241:0.2:12532:12533 ~-0.02467322238326278 ~0.03979112559460653 43:-0.28125:12535:12536 ~-0.031183539631755006 ~0.02932363259833262 242:2.25:12538:12545 226:-0.375:12539:12544 "
    s .= "245:1.4444444444444444:12540:12541 ~0.031815020906613 75:0.5234375:12542:12543 ~-0.044566574914557094 ~0.03298128508328238 ~-0.00020344282145887734 28:-0.09375:12546:12549 27:0.109375:12547:12548 ~-0.03370600360783585 "
    s .= "~0.03038433887585862 ~-0.052279543923135954 126:0.984375:12551:12596 254:1.296875:12552:12581 254:1.171875:12553:12580 125:-0.59375:12554:12559 223:0.625:12555:12558 17:0.21875:12556:12557 ~0.012800531032574844 "
    s .= "~-0.044427898707566034 ~-0.03551830923972179 99:-0.21875:12560:12563 37:0.34375:12561:12562 ~-0.0265491906796938 ~0.015359101047911673 106:1.828125:12564:12575 106:0.59375:12565:12572 139:0.671875:12566:12571 "
    s .= "181:0.546875:12567:12570 141:0.1640625:12568:12569 ~-0.02429509822493936 ~-0.00011834524718333349 ~0.015590436015300203 ~0.013609086787424538 190:0.1875:12573:12574 ~0.015020946737327867 ~-0.009171554479727102 "
    s .= "223:0.046875:12576:12579 256:0:12577:12578 ~-0.052587918624979225 ~0.020497161313315068 ~0.004298433800785372 ~0.024518484759120555 98:-0.234375:12582:12595 169:-0.109375:12583:12584 ~-0.03763943842165681 "
    s .= "148:-0.0625:12585:12586 ~0.03448378973437304 251:1.171875:12587:12594 158:-0.28125:12588:12591 230:-1.03125:12589:12590 ~0.003899285816678692 ~-0.05335591986023839 49:0.078125:12592:12593 ~-0.026377705826333288 "
    s .= "~0.03910635555171753 ~0.022601210001362122 ~-0.04427306000316095 ~-0.05075667223129299 203:0.734375:12598:12643 11:0.90625:12599:12640 191:0.71875:12600:12639 116:0.6875:12601:12634 245:1.3571428571428572:12602:12605 "
    s .= "106:-0.28125:12603:12604 ~0.0373577022163441 ~-0.033485725683772796 256:0.01639344262295082:12606:12627 247:0.515625:12607:12624 132:0.3671875:12608:12623 66:0.5625:12609:12622 247:0.203125:12610:12611 "
    s .= "~0.0010944874576839802 120:0.359375:12612:12621 127:0.125:12613:12620 89:0.015625:12614:12615 ~-0.04657851728020113 244:1.065:12616:12617 ~0.05968468012591676 223:0.0625:12618:12619 ~-0.04477514405183891 "
    s .= "~0.03167755047957875 ~-0.041644695933000714 ~0.0131300848546143 ~-0.03657458055843152 ~0.024117532611924647 84:0.7734375:12625:12626 ~-0.03979927974781864 ~0.048925371713456456 77:0.328125:12628:12633 "
    s .= "156:0.3515625:12629:12630 ~0.02997144430615277 250:1.2265625:12631:12632 ~-0.036841478555415044 ~0.04031511734479495 ~-0.01090635270128432 117:0.546875:12635:12638 25:-0.078125:12636:12637 ~-0.00813550421056406 "
    s .= "~0.03991265388987343 ~-0.04812840893329857 ~-0.030826237656691763 15:0.7265625:12641:12642 ~0.05383608896181729 ~-0.024495684845790244 ~-0.026959171877096455 195:-0.328125:12645:12656 133:0.90625:12646:12647 "
    s .= "~-0.027552119598511383 244:1.92:12648:12655 55:-0.09375:12649:12650 ~-0.05289722393157773 199:0.078125:12651:12652 ~-0.023556380824040754 202:0.484375:12653:12654 ~0.029320096548459615 ~-0.038927244721298625 "
    s .= "~0.031191298457454802 105:-0.3046875:12657:12662 196:0.375:12658:12659 ~0.018004131959903656 181:0.21875:12660:12661 ~0.03675982895747547 ~-0.05362541302768368 106:1.84375:12663:12686 112:1.78125:12664:12685 "
    s .= "246:-0.578125:12665:12668 247:-0.265625:12666:12667 ~-0.0007740311029273548 ~-0.029039417304034195 62:-0.421875:12669:12670 ~0.02047200798044005 255:0.328125:12671:12684 254:0.765625:12672:12675 136:1.1875:12673:12674 "
    s .= "~-0.007950563012858139 ~0.014437948579071033 245:1.8484848484848484:12676:12677 ~0.03256592234679585 128:0.125:12678:12681 244:1.125:12679:12680 ~0.035271290046384136 ~-0.004088164212205637 "
    s .= "242:0.6499999999999999:12682:12683 ~-0.04990384292636635 ~0.006296272144533821 ~-0.01946945175567466 ~0.01779151058578617 110:0.15625:12687:12690 16:0.296875:12688:12689 ~-0.037967863389589476 ~0.01895699177987224 "
    s .= "~0.011955557045717238 251:0.078125:12692:12695 250:0.8828125:12693:12694 ~0.013299039066223074 ~-0.04843824090388633 250:1.0703125:12696:12721 25:0.640625:12697:12720 159:0.3359375:12698:12717 97:-0.09375:12699:12704 "
    s .= "148:0.015625:12700:12703 245:2.6:12701:12702 ~-0.014338528340881444 ~0.026468001490765666 ~-0.02925915462251796 73:0.0625:12705:12712 196:-0.1875:12706:12707 ~-0.03960796575341962 82:-0.125:12708:12709 "
    s .= "~0.0461902217724472 115:-0.15625:12710:12711 ~-0.039393713551708814 ~0.012630924652682084 205:0.15625:12713:12716 122:-0.65625:12714:12715 ~0.030440311186965885 ~-0.0021310856395550318 ~-0.01534885719772394 "
    s .= "130:0.296875:12718:12719 ~0.012587737677876097 ~-0.041780817879596144 ~-0.03781621629360358 79:0.234375:12722:12737 34:0.734375:12723:12736 184:0.125:12724:12729 244:1.095:12725:12726 ~0.005362136965384687 "
    s .= "82:0.578125:12727:12728 ~-0.04242159510891792 ~-0.00044780865591401744 242:0.55:12730:12733 251:1.203125:12731:12732 ~0.02764483511523691 ~-0.045442026793025524 247:0.078125:12734:12735 ~-0.02955725934002919 "
    s .= "~0.014027112734957435 ~0.03765158414673776 ~0.01144096671484179 253:-0.07269338303821087:12739:12770 252:0.475:12740:12767 58:0.046875:12741:12750 123:0.109375:12742:12749 248:0.125:12743:12746 4:-0.015625:12744:12745 "
    s .= "~0.03599173421320622 ~-0.02145414021150846 8:-0.484375:12747:12748 ~0.015751929569519645 ~-0.04083973297046714 ~0.032944380193435326 112:1.390625:12751:12766 136:0.078125:12752:12757 34:0.125:12753:12754 "
    s .= "~0.02785283966423013 127:0.609375:12755:12756 ~-0.04839368595129783 ~0.051703678259808775 175:0.546875:12758:12763 61:0.859375:12759:12762 181:0.03125:12760:12761 ~-0.10086700612330085 ~-0.041073259289554666 "
    s .= "~-0.0009815809939962379 22:-0.046875:12764:12765 ~0.038675241318041516 ~-0.029613918021414654 ~0.02275029732819777 34:-0.25:12768:12769 ~-0.026950017257226528 ~0.02931067371282563 248:0.125:12771:12778 "
    s .= "251:1.203125:12772:12775 93:0.046875:12773:12774 ~-0.0028838544153353203 ~-0.029074979847570022 243:0.75:12776:12777 ~-0.021386338225990623 ~0.027273608244899696 253:-0.00793650793650929:12779:12782 "
    s .= "252:0.225:12780:12781 ~-0.03335604449457366 ~-0.000263726257992715 107:0.53125:12783:12784 ~0.007144847878344871 ~-0.02016887575930963 219:0.953125:12786:12831 201:0.75:12787:12830 244:0.78:12788:12795 "
    s .= "247:0.703125:12789:12790 ~-0.030321368309877635 247:0.765625:12791:12794 18:0.1953125:12792:12793 ~0.20855148585975214 ~0.005750448646178956 ~-0.032796562434168494 93:0.703125:12796:12827 237:0.484375:12797:12820 "
    s .= "107:0.171875:12798:12811 2:0.078125:12799:12804 4:-0.53125:12800:12801 ~-0.035167981688118695 122:-0.65625:12802:12803 ~0.010590016898124095 ~-0.001067894841461265 56:0.390625:12805:12810 31:0.046875:12806:12809 "
    s .= "52:0.125:12807:12808 ~-0.01736320060149667 ~0.03332968302181981 ~-0.042507421476048815 ~0.03047121601694874 22:-0.234375:12812:12815 13:0.203125:12813:12814 ~-0.03471802627503703 ~0.031102244252465047 "
    s .= "16:0.59375:12816:12819 106:0.09375:12817:12818 ~-0.010521211003541312 ~0.02024079566243675 ~-0.031869355904522015 128:-0.1875:12821:12824 2:-0.609375:12822:12823 ~-0.027365077204039603 ~0.025826165651245916 "
    s .= "40:-0.0625:12825:12826 ~0.009519461207648931 ~-0.03819185270395939 237:0.5625:12828:12829 ~-0.046300840257435374 ~0.0202331803938937 ~0.02110964266556814 ~-0.03891071932803429 195:-0.328125:12833:12848 "
    s .= "133:0.90625:12834:12839 47:-0.703125:12835:12838 251:0.859375:12836:12837 ~-0.03877096816924286 ~0.018773441881051105 ~-0.046033842582942915 244:1.92:12840:12847 55:-0.09375:12841:12842 ~-0.05140092808338375 "
    s .= "199:0.109375:12843:12844 ~-0.021615490236595446 214:0.5625:12845:12846 ~0.028226489685208425 ~-0.04451636896774309 ~0.02995485577629547 105:-0.3046875:12849:12854 196:0.375:12850:12851 ~0.017071994673851 "
    s .= "181:0.21875:12852:12853 ~0.03529124349299966 ~-0.05204739568289257 106:1.84375:12855:12872 64:1.140625:12856:12867 247:-0.921875:12857:12860 191:-0.953125:12858:12859 ~0.015128282329728543 ~-0.05536090339966945 "
    s .= "165:-0.203125:12861:12862 ~0.014071415905296964 246:-0.578125:12863:12866 244:1.375:12864:12865 ~-0.02799701647636359 ~0.0028558297855603757 ~0.0017255221691567818 52:0.59375:12868:12871 124:-0.109375:12869:12870 "
    s .= "~-0.023904885786687743 ~0.03446406463268704 ~-0.03723979349803663 16:0.234375:12873:12878 80:0.421875:12874:12877 1:-0.15625:12875:12876 ~-0.00042003280156538707 ~-0.04690517172404684 ~0.030644736279202802 "
    s .= "~0.018609718582429546 254:0.984375:12880:12925 223:1.875:12881:12924 251:0.203125:12882:12887 31:0.078125:12883:12886 208:0.03125:12884:12885 ~-0.02628148771814627 ~0.011796017990338194 ~-0.03239672162740759 "
    s .= "146:-0.265625:12888:12891 148:1.78125:12889:12890 ~0.00898561372900531 ~-0.04874148190173205 257:0.22727272727272727:12892:12913 79:0.53125:12893:12908 39:0.4375:12894:12903 51:0.3515625:12895:12902 73:0:12896:12901 "
    s .= "244:2.255:12897:12900 195:0.296875:12898:12899 ~-0.03033560324434105 ~0.009477002452672984 ~0.032652453674839814 ~0.0061197110946175125 ~0.020861237324519635 138:0.1484375:12904:12905 ~-0.04474000384435496 "
    s .= "56:-0.046875:12906:12907 ~0.02021462465385623 ~-0.025284353722572296 178:0.375:12909:12910 ~0.023786183816967055 120:0.203125:12911:12912 ~-0.018253815599963554 ~0.026181032177207464 196:-0.109375:12914:12917 "
    s .= "244:1.5:12915:12916 ~-0.014500501396156572 ~0.04706952152903795 35:-0.03125:12918:12919 ~-0.04495977588686792 147:0:12920:12921 ~0.027560713548432304 44:0.40625:12922:12923 ~-0.05296445635765665 ~0.025810782924370446 "
    s .= "~-0.06255047704138321 ~-0.006107125185504221 194:0.65625:12927:12970 120:0.03125:12928:12951 186:-0.03125:12929:12946 249:0.5:12930:12935 66:0.234375:12931:12934 245:1.3870967741935485:12932:12933 ~-0.027142508028843583 "
    s .= "~0.010613601084494221 ~-0.047447661374202345 204:0.0625:12936:12945 137:-0.1875:12937:12940 136:0.25:12938:12939 ~0.0021782029968449887 ~-0.04074280043911715 171:-0.203125:12941:12942 ~0.04183592855206176 "
    s .= "12:0.109375:12943:12944 ~-0.04991702103834693 ~0.02272566537983554 ~0.03371283308935187 247:-0.015625:12947:12950 55:-0.1875:12948:12949 ~-0.04054655619766392 ~0.0048102502573565305 ~-0.024669601318341897 "
    s .= "121:-0.015625:12952:12967 99:-0.109375:12953:12954 ~-0.041225370481395594 169:-0.28125:12955:12956 ~0.02800419924017491 130:0.109375:12957:12960 241:0.18:12958:12959 ~-0.01792998564890974 ~0.03332594926620094 "
    s .= "115:0.765625:12961:12964 16:-0.015625:12962:12963 ~-0.0039364500252148755 ~-0.037483787092003215 229:-0.0625:12965:12966 ~-0.04576471634009698 ~0.03209108791376198 127:-0.1875:12968:12969 ~0.0397979795209454 "
    s .= "~0.006372819530600298 98:-0.078125:12971:12972 ~0.023324047502019725 ~-0.040161756282950545 253:-0.10476190476190653:12974:13001 252:0.125:12975:12990 51:-0.1796875:12976:12981 192:-0.09375:12977:12978 "
    s .= "~-0.01850719544763077 82:1.09375:12979:12980 ~-0.03872313135589563 ~-0.2066963498384105 14:-0.546875:12982:12983 ~0.032113030512985495 249:0.16666666666666666:12984:12987 211:-0.046875:12985:12986 ~-0.035766228157928875 "
    s .= "~0.036280876066516504 223:0.25:12988:12989 ~-0.04466957929798405 ~0.016408531367007453 25:0.9375:12991:13000 46:-0.28125:12992:12995 233:-0.109375:12993:12994 ~0.018627356828859933 ~-0.05363917946470281 "
    s .= "257:0.8571428571428571:12996:12999 109:0.453125:12997:12998 ~0.00014624557648596284 ~0.039380914685094304 ~-0.03141992815465182 ~-0.07256762623584517 174:-0.46875:13002:13005 21:-0.0703125:13003:13004 "
    s .= "~-0.002681463134561586 ~-0.04172880472019945 57:-0.4921875:13006:13009 46:0.328125:13007:13008 ~0.0314159632489621 ~-0.043925278481840975 110:-1.28125:13010:13013 185:-1.390625:13011:13012 ~0.01530501087407178 "
    s .= "~-0.0444745614714996 16:0.296875:13014:13015 ~-0.002226833125346891 110:0.265625:13016:13019 251:0.265625:13017:13018 ~-0.030526234030273953 ~0.02400408966728374 ~-0.01961690593927573 190:-0.328125:13021:13026 "
    s .= "82:0.515625:13022:13023 ~-0.03047556270902864 118:0.1875:13024:13025 ~0.010368821496785429 ~-0.04844258407074492 196:1.265625:13027:13064 151:-0.109375:13028:13031 121:1.109375:13029:13030 ~0.011028988060114433 "
    s .= "~-0.05231380746239429 55:-0.578125:13032:13033 ~0.03552076692955031 48:0.2109375:13034:13045 97:-0.328125:13035:13036 ~-0.03243584629174762 46:0.796875:13037:13042 219:0.4375:13038:13041 189:0.46875:13039:13040 "
    s .= "~-0.0019254181005290217 ~-0.048236780441414155 ~-0.024528073641901463 163:0.34375:13043:13044 ~0.04148015593566694 ~-0.024761505398828113 176:0.65625:13046:13063 144:-0.234375:13047:13048 ~-0.03863287810754161 "
    s .= "238:0.109375:13049:13052 28:0.6875:13050:13051 ~0.018835195056990273 ~-0.046902845803217394 208:0.015625:13053:13054 ~-0.04696245650423095 251:1.078125:13055:13062 250:1.2265625:13056:13061 103:0.125:13057:13060 "
    s .= "51:0.0703125:13058:13059 ~0.059772023443716474 ~-0.023766854368433205 ~-0.046694852309129516 ~0.01864082905934609 ~0.030185927364460005 ~-0.03727699108746246 241:0.18:13065:13066 ~-0.0142697207566089 "
    s .= "~0.03580520186681146 126:0.984375:13068:13113 255:0.234375:13069:13086 255:0.171875:13070:13071 ~-0.0005392616711002912 244:1.19:13072:13079 131:-0.296875:13073:13074 ~-0.02685958006834656 212:0.34375:13075:13076 "
    s .= "~0.03801094146771844 219:0.140625:13077:13078 ~-0.045484783655847384 ~0.03978351467944398 170:-0.015625:13080:13081 ~0.02156124936838928 100:0.421875:13082:13085 88:0.1875:13083:13084 ~-0.054862674576521366 "
    s .= "~0.0016255117657742388 ~0.02857499717826776 254:0.515625:13087:13094 153:0.1328125:13088:13091 1:0.34375:13089:13090 ~0.022725816690417948 ~-0.031999266529907325 50:-0.328125:13092:13093 ~-0.06961636224750431 "
    s .= "~0.013286729113285002 50:-0.34375:13095:13104 257:0.5555555555555556:13096:13103 167:0.21875:13097:13102 246:-0.390625:13098:13101 154:0.953125:13099:13100 ~-0.012965737185128064 ~0.015489751869958629 "
    s .= "~0.017471912496106103 ~-0.043396671795494314 ~-0.02848231308076772 250:1.0234375:13105:13110 244:1.55:13106:13107 ~-0.04577142350342755 111:-0.2109375:13108:13109 ~0.041831404477625185 ~-0.023673879029071317 "
    s .= "11:0.515625:13111:13112 ~-0.010819357472659597 ~0.05853597666728776 ~-0.050150383124154346 253:-0.07269338303821087:13115:13150 252:0.475:13116:13147 243:1.35:13117:13144 257:0.38:13118:13131 140:-0.09375:13119:13122 "
    s .= "115:0.25:13120:13121 ~0.02970781548235303 ~-0.0037926147108924575 58:0.046875:13123:13126 245:2.4838709677419355:13124:13125 ~0.02528843017625214 ~-0.03881310228601248 3:0.234375:13127:13128 ~0.004740721411252894 "
    s .= "256:0.22772277227722773:13129:13130 ~-0.06077317773264417 ~0.012025596373822812 250:0.9921875:13132:13139 76:0.078125:13133:13134 ~-0.0016946148324680198 147:-0.296875:13135:13136 ~-0.03329642091457839 "
    s .= "69:-0.078125:13137:13138 ~-0.20470045654428015 ~-0.03242254651910039 200:-0.421875:13140:13141 ~0.025571508764842793 159:-0.0078125:13142:13143 ~-0.04572407586063923 ~0.0380287724109554 13:-0.4375:13145:13146 "
    s .= "~0.02157091879596383 ~-0.08528942577782608 34:-0.25:13148:13149 ~-0.025526171066538816 ~0.028588673744025524 242:2.25:13151:13154 226:-0.375:13152:13153 ~-0.020177120422657544 ~-0.0002016090588208533 "
    s .= "28:-0.09375:13155:13160 27:0.109375:13156:13159 118:-0.234375:13157:13158 ~0.03019139180357179 ~-0.06210791297626631 ~0.029313611405598947 ~-0.050471330702226286 33:0.984375:13162:13207 11:0.90625:13163:13204 "
    s .= "50:0.71875:13164:13203 246:1.734375:13165:13198 247:0.796875:13166:13197 192:0.90625:13167:13196 23:0.90625:13168:13193 124:-0.65625:13169:13170 ~-0.0376673944691366 85:1.375:13171:13182 190:-0.171875:13172:13179 "
    s .= "175:1.421875:13173:13178 85:-0.046875:13174:13177 52:-0.015625:13175:13176 ~-0.022128054622489388 ~0.0376968842875859 ~-0.027459848013408863 ~0.033339530679543004 61:-0.421875:13180:13181 ~0.027505958533294596 "
    s .= "~-0.0005609902384492294 181:1.484375:13183:13190 181:0.09375:13184:13189 61:0.78125:13185:13186 ~-0.01892309049647663 37:-0.28125:13187:13188 ~-0.037353078463611515 ~0.0317057229254265 ~0.025555239474419886 "
    s .= "238:0.046875:13191:13192 ~-0.04243642780229211 ~0.006852866618139228 59:0.15625:13194:13195 ~-0.04055092003764051 ~0.14090833859073423 ~-0.04760020939350507 ~-0.0397808625380831 60:0.1953125:13199:13200 "
    s .= "~-0.021428198811500383 215:0.671875:13201:13202 ~0.05868472339477191 ~-0.04089773145708686 ~-0.03625371074970622 86:0.78125:13205:13206 ~0.05941622476035659 ~-0.012171426795227931 ~-0.043127614279074244 "
    s .= "41:0.546875:13209:13248 8:0.4375:13210:13243 50:0.234375:13211:13240 256:0.01639344262295082:13212:13229 149:-0.015625:13213:13220 56:-0.015625:13214:13217 246:-0.046875:13215:13216 ~-0.002853783255205687 "
    s .= "~0.013125079474751397 158:0:13218:13219 ~0.029535128441519065 ~-0.01073133733179136 232:-0.125:13221:13224 257:0.4090909090909091:13222:13223 ~-0.0412205869971279 ~0.03733414075377635 88:0.546875:13225:13228 "
    s .= "193:-0.046875:13226:13227 ~0.010237807574011326 ~-0.02014269032633092 ~0.012044894975897093 251:0.828125:13230:13235 4:1.140625:13231:13234 51:0.3359375:13232:13233 ~-0.03361607007756211 ~0.01347527424746712 "
    s .= "~0.10094935964622168 211:-0.296875:13236:13237 ~-0.019172889507000364 240:-0.140625:13238:13239 ~-0.028484413330204378 ~0.032766548328345545 65:0.4375:13241:13242 ~-0.0200135565483106 ~0.015567008597983475 "
    s .= "130:0.171875:13244:13247 120:0.421875:13245:13246 ~0.059313623551407006 ~-0.03987896085966652 ~0.0055991181495994675 107:0.421875:13249:13254 128:-0.234375:13250:13251 ~-0.045148948970561306 252:0.025:13252:13253 "
    s .= "~0.07760471316679884 ~-0.0042731749770693675 ~-0.031607944126875086 254:1.296875:13256:13285 254:1.171875:13257:13282 166:2.125:13258:13281 205:1.1875:13259:13274 144:-0.765625:13260:13261 ~-0.028843554932195672 "
    s .= "54:-0.6328125:13262:13263 ~0.02679787859229619 133:2.078125:13264:13271 100:1:13265:13266 ~-0.0007328592135389648 154:0.765625:13267:13270 244:0.835:13268:13269 ~0.1354547518286376 ~0.02490733163154179 "
    s .= "~-0.006718127152761715 174:-0.234375:13272:13273 ~0.02216927317341256 ~-0.03644296686768168 202:0.90625:13275:13278 124:1.296875:13276:13277 ~0.034593729919754894 ~-0.03158960460546317 237:0.3125:13279:13280 "
    s .= "~-0.027679078646131672 ~0.032420781699220816 ~-0.04529362755773009 175:-0.078125:13283:13284 ~-0.03808722456623623 ~0.03189023629608625 244:1.455:13286:13295 33:-0.296875:13287:13288 ~0.01045312668160409 "
    s .= "91:1.265625:13289:13294 251:1.203125:13290:13291 ~-0.04868126109428439 74:-0.75:13292:13293 ~0.03978209169826222 ~-0.04276748265588135 ~0.023990478225180287 66:-0.265625:13296:13299 87:-0.3671875:13297:13298 "
    s .= "~0.0011211090232932182 ~-0.06297259779199009 173:-0.21875:13300:13301 ~0.030268935029551088 ~-0.025811171533572843 181:-0.703125:13303:13304 ~-0.040193748782213684 100:1.046875:13305:13336 242:2.05:13306:13331 "
    s .= "88:1.21875:13307:13326 79:-0.125:13308:13315 183:-0.140625:13309:13310 ~0.025310593646398802 105:0.3515625:13311:13312 ~-0.009604150524973014 133:-0.109375:13313:13314 ~0.1468473779785627 ~0.026227970440957173 "
    s .= "246:-0.265625:13316:13317 ~-0.009940397533443848 244:1.26:13318:13323 25:-0.078125:13319:13320 ~-0.014088622246476876 212:0.46875:13321:13322 ~0.016667859461797305 ~-0.02448490951194734 79:0.265625:13324:13325 "
    s .= "~-0.02138055299776309 ~0.005771917756719112 193:-0.09375:13327:13328 ~-0.01620849682051356 163:1.375:13329:13330 ~0.023825628072686688 ~-0.01889319346993245 251:1.640625:13332:13335 142:0.984375:13333:13334 "
    s .= "~-0.048529131655613005 ~0.0311812047215502 ~0.016424767311346997 235:0.453125:13337:13344 244:0.835:13338:13339 ~0.13529659508590394 70:0.890625:13340:13343 250:1.5703125:13341:13342 ~0.022938617410476043 "
    s .= "~-0.030466454098887197 ~-0.0494910872054786 223:0.171875:13345:13346 ~-0.001489964663790897 136:1.46875:13347:13348 ~-0.10577763795396232 ~0.003693890128036602 255:0.234375:13350:13381 255:0.171875:13351:13366 "
    s .= "242:0.55:13352:13359 184:0.1875:13353:13358 154:0.328125:13354:13357 134:-0.328125:13355:13356 ~-0.03919163764981433 ~-0.003935729427382446 ~0.014312530313997561 ~0.016997116760983515 251:0.328125:13360:13361 "
    s .= "~-0.038947174466143854 154:-0.15625:13362:13363 ~0.03009052199271822 245:1.5816326530612246:13364:13365 ~-0.026658966168109095 ~0.00148190508313765 133:1.203125:13367:13380 252:0.125:13368:13379 11:0.453125:13369:13378 "
    s .= "74:0.015625:13370:13373 40:-0.015625:13371:13372 ~-0.016078252087878327 ~0.03159206238541008 32:0.1875:13374:13375 ~-0.04329510740190738 30:0.0546875:13376:13377 ~0.05749437746255659 ~-0.0379414209132721 "
    s .= "~0.06914999310401512 ~0.03144115194941633 ~-0.022382011615972086 254:0.515625:13382:13383 ~0.011410615515765176 38:-0.359375:13384:13389 257:0.5555555555555556:13385:13388 49:0.625:13386:13387 ~0.005295652448003226 "
    s .= "~-0.04162590056951115 ~-0.029781328998029755 250:1.1640625:13390:13393 169:1.796875:13391:13392 ~-0.02902922782581321 ~0.03962540499059705 69:-0.109375:13394:13395 ~-0.03220894654537778 ~0.0104535379359037 "
    s .= "253:-0.10476190476190653:13397:13420 252:0.125:13398:13413 51:-0.1796875:13399:13402 192:-0.09375:13400:13401 ~-0.01774462270564672 ~-0.10927006416531047 14:-0.546875:13403:13404 ~0.030661487313211444 "
    s .= "249:0.16666666666666666:13405:13408 211:-0.046875:13406:13407 ~-0.032122785689199816 ~0.035732622409668714 152:0.0625:13409:13412 159:0.0234375:13410:13411 ~-0.0347332647817085 ~0.025181640342133924 "
    s .= "~-0.05866133849629466 67:-0.59375:13414:13415 ~-0.07081782541961944 28:0.1875:13416:13417 ~0.028255119669147795 112:0.71875:13418:13419 ~-0.035526629913912616 ~0.03725262688319217 174:-0.46875:13421:13426 "
    s .= "23:-0.03125:13422:13425 128:-0.59375:13423:13424 ~0.0033815892442735484 ~-0.049107961524296695 ~-0.05696396103105277 57:-0.4921875:13427:13430 46:0.328125:13428:13429 ~0.030076365072018954 ~-0.042347819200291834 "
    s .= "110:-1.328125:13431:13434 185:-1.6875:13432:13433 ~0.03531439771726113 ~-0.038799930514814916 139:0.46875:13435:13440 40:0.359375:13436:13439 85:0.71875:13437:13438 ~-0.011460772763698009 ~0.005023957545519568 "
    s .= "~0.013932645892597954 61:0.40625:13441:13442 ~0.008735913811846165 ~-0.009840374650331727 238:0.53125:13444:13469 208:0.734375:13445:13466 205:0.96875:13446:13465 246:-2.046875:13447:13450 90:-0.3671875:13448:13449 "
    s .= "~-0.0015198700308221875 ~-0.034237296581735265 44:-0.96875:13451:13454 25:0.109375:13452:13453 ~0.03285855073969038 ~-0.029290169543447372 228:-0.390625:13455:13456 ~-0.02635563488020026 76:0.375:13457:13460 "
    s .= "91:0.734375:13458:13459 ~-0.004598229210275943 ~0.011511090442229756 67:0.125:13461:13462 ~0.02163478906117441 250:0.9921875:13463:13464 ~-0.02729088931203388 ~0.012850002731882783 ~0.022353070958089555 "
    s .= "187:-0.203125:13467:13468 ~-0.04084449870240515 ~0.01775346642355097 242:0.6499999999999999:13470:13483 112:0.40625:13471:13474 103:-0.03125:13472:13473 ~0.027481996641224887 ~-0.054128266520307916 "
    s .= "91:0.515625:13475:13480 115:1.5625:13476:13479 7:0.546875:13477:13478 ~0.041077998831201376 ~-0.0371274745646972 ~-0.041398404606065003 88:0.96875:13481:13482 ~-0.05542439410294118 ~0.012935430941463308 "
    s .= "211:0.25:13484:13487 205:0.0625:13485:13486 ~-0.03581927954428795 ~0.02243963038164384 123:-0.390625:13488:13489 ~0.005734862190846563 ~-0.05025269101629218 126:0.984375:13491:13536 250:1.1171875:13492:13511 "
    s .= "25:0.578125:13493:13508 122:0.25:13494:13507 153:0.4921875:13495:13506 251:1.546875:13496:13505 217:-0.140625:13497:13498 ~-0.01830395476653637 211:0.1875:13499:13500 ~0.006863178871730255 58:0.3125:13501:13504 "
    s .= "184:-0.09375:13502:13503 ~-0.07105993122132168 ~0.00519513938821972 ~-0.029821494187073007 ~0.01687758079402601 ~-0.034992352625769794 ~-0.019827004569851776 232:-0.328125:13509:13510 ~0.024497952110490922 "
    s .= "~-0.04363140374207271 132:0.2890625:13512:13535 27:0.09375:13513:13520 36:0.015625:13514:13519 53:0.21875:13515:13518 148:0.515625:13516:13517 ~0.01127504542166871 ~-0.027701429004073453 ~-0.03433844651478284 "
    s .= "~0.02700521616802832 245:2.552941176470588:13521:13534 252:0.175:13522:13531 251:1.296875:13523:13530 8:0.734375:13524:13529 184:0.203125:13525:13526 ~-0.03603557995435088 53:-0.03125:13527:13528 ~0.030958498130136604 "
    s .= "~-0.03592968159078526 ~0.06281105401657759 ~-0.060399963105151805 251:0.890625:13532:13533 ~-0.022974301081160782 ~0.02154706981589524 ~-0.07467213579172023 ~0.02546622825423633 ~-0.048503235238884446 "
    s .= "190:-0.328125:13538:13549 257:0.03225806451612903:13539:13548 12:0.03125:13540:13541 ~-0.04620836593486838 13:0.265625:13542:13545 165:0.328125:13543:13544 ~-0.04745178507903885 ~0.02853816117728139 "
    s .= "244:1.065:13546:13547 ~-0.04154704938409301 ~0.04314511032749057 ~0.00983479767728958 196:1.265625:13550:13583 151:0.0625:13551:13582 103:0.28125:13552:13577 37:0.359375:13553:13574 160:1.546875:13554:13573 "
    s .= "190:0.625:13555:13572 88:0.515625:13556:13571 245:1.8484848484848484:13557:13564 139:0.359375:13558:13561 247:0.453125:13559:13560 ~-0.02845602876007592 ~0.022929278953486034 211:-0.15625:13562:13563 "
    s .= "~-0.04305326673392458 ~0.04024644145314496 76:-0.0625:13565:13568 116:0.15625:13566:13567 ~0.007878928288028489 ~-0.05619395405517538 100:0.5:13569:13570 ~-0.04625471850367486 ~0.038107339824811404 ~0.015889237019094782 "
    s .= "~0.033041358866545245 ~-0.04300622645866073 88:0.5:13575:13576 ~0.03982040338483586 ~-0.024584240490181833 144:0.359375:13578:13581 214:0.40625:13579:13580 ~0.02590002206597813 ~-0.007466552585838309 "
    s .= "~-0.031301180904870364 ~-0.0026222203341493638 ~0.02116019885673124 249:0.16666666666666666:13585:13594 253:-0.05035714285714334:13586:13589 257:0.33962264150943394:13587:13588 ~0.02463080500498215 ~-0.01354560014500616 "
    s .= "69:0.40625:13590:13593 242:0.55:13591:13592 ~0.00957397690037716 ~-0.006887602857504805 ~-0.02644933615058493 121:-0.1875:13595:13600 148:-0.265625:13596:13597 ~0.0014200521636166636 123:0.40625:13598:13599 "
    s .= "~-0.04106718150428999 ~0.01704278214600483 219:0.265625:13601:13622 82:0.375:13602:13621 139:0.5:13603:13616 76:0.328125:13604:13615 106:0.296875:13605:13608 166:0.625:13606:13607 ~-0.03713146783219011 "
    s .= "~0.03971321250676423 167:-0.1875:13609:13612 22:0.1875:13610:13611 ~0.02910114125131906 ~-0.043832266503136735 31:0.359375:13613:13614 ~-0.031207253147936348 ~0.05035374279011188 ~0.025125667399614415 "
    s .= "244:1.3:13617:13620 15:0.5546875:13618:13619 ~0.03220196360228106 ~-0.05837717637714469 ~-0.006177407879369279 ~-0.01587608164359713 85:-0.203125:13623:13626 205:-0.09375:13624:13625 ~0.11077025082657635 "
    s .= "~0.018425364142553535 231:-0.21875:13627:13628 ~-0.06754918355851275 172:0.484375:13629:13630 ~0.0021435716301303363 ~0.034055251744396824 219:0.953125:13632:13677 250:1.0703125:13633:13658 25:0.640625:13634:13657 "
    s .= "159:0.3359375:13635:13654 97:-0.09375:13636:13643 136:1.625:13637:13642 251:1.234375:13638:13641 12:-0.03125:13639:13640 ~-0.04121589672297989 ~-0.008505998617304021 ~0.01096038913867345 ~0.02641825230833729 "
    s .= "55:0.109375:13644:13647 157:-0.078125:13645:13646 ~-0.032490590461470445 ~0.012044056655616074 251:0.421875:13648:13653 181:0.203125:13649:13652 154:0.75:13650:13651 ~-0.02325146195542765 ~0.04625179033473473 "
    s .= "~-0.0450993681396982 ~0.0018797651147001934 5:-0.015625:13655:13656 ~-0.046575497512030155 ~0.0007556304141690504 ~-0.03522580865943123 132:0.2890625:13659:13676 33:0.515625:13660:13673 184:0.046875:13661:13670 "
    s .= "106:0.8125:13662:13665 252:0.375:13663:13664 ~-0.032302215616326894 ~0.018164428391334007 250:1.2890625:13666:13667 ~0.023729909182151537 243:0.6499999999999999:13668:13669 ~-0.0520283954851361 ~0.008987574876775302 "
    s .= "251:0.140625:13671:13672 ~-0.0323998848144684 ~0.010776767623246574 141:0.1796875:13674:13675 ~-0.04150023866678516 ~-0.0024822898242049096 ~0.019897581080769326 ~-0.037608213786718525 217:0.1875:13679:13690 "
    s .= "66:0.109375:13680:13685 24:0.203125:13681:13684 148:1.46875:13682:13683 ~0.0033228188955113144 ~-0.032474069586266745 ~0.025418158929931534 99:-0.09375:13686:13687 ~-0.03562672687390348 120:0:13688:13689 "
    s .= "~-0.030484895483253973 ~0.0009112048167482023 163:0.328125:13691:13708 115:-0.03125:13692:13695 166:-0.03125:13693:13694 ~0.0009675134624638976 ~-0.044054351641525664 187:0.28125:13696:13703 195:0.328125:13697:13700 "
    s .= "148:0.140625:13698:13699 ~0.01143888047655824 ~-0.023890147401145673 204:0.328125:13701:13702 ~0.04271867323673761 ~-0.01630535036069126 55:0.453125:13704:13707 243:0.8500000000000001:13705:13706 ~0.042396606730034744 "
    s .= "~-0.024145848402801758 ~-0.033759351253342 1:-0.328125:13709:13714 143:-0.4375:13710:13713 251:1.046875:13711:13712 ~-0.060471317763131485 ~0.01666105117798248 ~0.03325752083372676 215:-0.921875:13715:13718 "
    s .= "117:-0.6875:13716:13717 ~-0.05706868014541283 ~0.022218497486556927 22:0.515625:13719:13722 184:-0.140625:13720:13721 ~0.025743865994531535 ~-0.03862619202910186 96:0.1171875:13723:13724 ~-0.02064891416115165 "
    s .= "~0.06080706323986004 21:-0.9453125:13726:13727 ~0.03224016868981224 205:2.171875:13728:13771 205:1.1875:13729:13762 110:-1.203125:13730:13737 90:-0.3359375:13731:13734 183:-0.5:13732:13733 ~-0.02271730782511572 "
    s .= "~0.015810394471358135 82:0.046875:13735:13736 ~-0.0022860618627100634 ~-0.057348916504834015 136:2.171875:13738:13757 68:-1.484375:13739:13740 ~0.04265422073264581 100:1:13741:13750 242:1.95:13742:13745 "
    s .= "243:2.8499999999999996:13743:13744 ~-0.00033240073841605427 ~0.05409065146884806 251:2.359375:13746:13749 169:-0.015625:13747:13748 ~-0.005849192949639152 ~-0.05136835862239003 ~0.03170108599735825 "
    s .= "61:0.515625:13751:13756 205:1.046875:13752:13755 244:0.835:13753:13754 ~0.13112715357682447 ~0.024273467450674248 ~-0.10826288115313248 ~-0.015794316940970023 46:0.328125:13758:13761 241:1.32:13759:13760 "
    s .= "~-0.052700449051960856 ~0.030864106852503993 ~0.032828308477509935 166:1.984375:13763:13770 31:-0.375:13764:13765 ~-0.03726881150813261 202:0.859375:13766:13769 238:1.59375:13767:13768 ~0.04198289738855915 "
    s .= "~-0.034667708426924446 ~-0.0029037949728462774 ~-0.07021700861704455 ~-0.055766273128844294 187:-0.3125:13773:13782 16:0.21875:13774:13779 90:-0.6015625:13775:13776 ~0.027384219644473615 141:0.1484375:13777:13778 "
    s .= "~-0.042489498079944975 ~0.0013383731074862572 217:-0.015625:13780:13781 ~-0.022399412696248844 ~0.03914510055915763 151:-0.109375:13783:13784 ~0.00866510824820634 154:0.609375:13785:13804 181:-0.109375:13786:13789 "
    s .= "243:1.45:13787:13788 ~0.02308869177821684 ~-0.04613702051287128 43:0.453125:13790:13801 112:0.46875:13791:13794 16:0.4375:13792:13793 ~-0.020170319541742823 ~0.028390257845189754 187:0.078125:13795:13798 "
    s .= "252:0.375:13796:13797 ~-0.027351301089189806 ~0.022289316984355285 1:0.234375:13799:13800 ~0.012202101442474219 ~-0.02386464657011181 226:0.171875:13802:13803 ~0.03795799518659654 ~-0.024044418487503237 "
    s .= "223:0:13805:13816 242:0.35:13806:13807 ~0.03470779828171104 243:0.75:13808:13813 76:-0.015625:13809:13810 ~0.0039252671397602785 46:0.71875:13811:13812 ~-0.05427110334960853 ~0.04048850947106581 142:0.15625:13814:13815 "
    s .= "~0.019654355525693033 ~-0.023620525350249482 190:0.484375:13817:13818 ~0.016071962135813845 ~-0.010960631056466538 41:0.546875:13820:13859 11:0.71875:13821:13858 89:0.78125:13822:13855 160:-0.328125:13823:13826 "
    s .= "242:0.6499999999999999:13824:13825 ~-0.045545156623301414 ~0.0007955442388659107 85:1.375:13827:13836 103:1.328125:13828:13833 82:2.03125:13829:13832 64:1.140625:13830:13831 ~-0.003253465078890922 ~0.025143072455237326 "
    s .= "~-0.06796737833124399 133:1.46875:13834:13835 ~0.024782208320237947 ~-0.007987090004743815 199:0.015625:13837:13848 163:1.28125:13838:13845 245:1.9833333333333334:13839:13840 ~0.04042882291998325 124:0.0625:13841:13844 "
    s .= "241:0.5:13842:13843 ~-0.05326569115487149 ~0.00286485218337399 ~0.019346904433458805 48:0.2109375:13846:13847 ~-0.048159742833588454 ~0.0298681277346253 245:2.2580645161290325:13849:13852 40:1.09375:13850:13851 "
    s .= "~0.038323144473977076 ~-0.04042555624005465 112:-0.015625:13853:13854 ~-0.052460411211546536 ~0.011612188545076403 112:1.140625:13856:13857 ~0.0336876632770521 ~-0.033594477663270415 ~0.04749575681998675 "
    s .= "107:0.421875:13860:13865 128:-0.234375:13861:13862 ~-0.044209236211844326 252:0.025:13863:13864 ~0.07157070661436461 ~-0.004131902522182434 ~-0.030986846046683177 46:0.078125:13867:13896 66:0.390625:13868:13895 "
    s .= "23:0.90625:13869:13892 245:2.161764705882353:13870:13875 243:1.35:13871:13874 148:0.765625:13872:13873 ~0.012712739733725838 ~-0.016630541739641912 ~-0.02011473420184373 252:1.6749999999999998:13876:13891 "
    s .= "202:-0.046875:13877:13878 ~-0.03031911410246645 244:1.125:13879:13880 ~0.028132342271209115 13:0:13881:13888 85:0.046875:13882:13887 112:0.1875:13883:13886 98:-0.09375:13884:13885 ~0.03544997202363491 "
    s .= "~-0.057877458644168704 ~-0.0694324906724749 ~0.01577034905242681 52:0.1875:13889:13890 ~-0.036646163564081985 ~0.008811064826030815 ~0.02598710218523328 39:0.21875:13893:13894 ~-0.03262895462460603 ~0.12893909572748857 "
    s .= "~-0.014243227627679118 251:0.796875:13897:13908 243:0.45:13898:13905 250:0.9765625:13899:13904 160:1.140625:13900:13903 150:0.3515625:13901:13902 ~-0.04139083953799158 ~0.024016624603069192 ~0.04249713155212584 "
    s .= "~0.021985650560365014 109:1.15625:13906:13907 ~-0.03512730961866362 ~-0.00036769612851927713 235:0.3125:13909:13912 242:1.55:13910:13911 ~0.012668762514239438 ~-0.02378836594360352 ~-0.02058747383502675 "
    s .= "33:0.890625:13914:13959 247:0.765625:13915:13956 111:0.3828125:13916:13951 249:0.5:13917:13926 248:0.875:13918:13923 237:0.484375:13919:13922 83:0.15625:13920:13921 ~0.002359146512911185 ~0.017022811367363 "
    s .= "~-0.015395301337175156 208:-0.15625:13924:13925 ~0.03580081946666267 ~-0.02886057397964329 245:1.6557377049180328:13927:13932 214:-0.578125:13928:13929 ~0.061290212494986965 90:0.1953125:13930:13931 "
    s .= "~-0.053078792932637335 ~-0.0036030784673966054 121:-0.03125:13933:13938 76:-0.03125:13934:13937 208:-0.15625:13935:13936 ~-0.05150345097511232 ~0.006787024482847976 ~-0.03581863293578619 74:0.140625:13939:13950 "
    s .= "73:0.546875:13940:13949 112:0.359375:13941:13942 ~-0.0076555993281455376 162:-0.4375:13943:13944 ~-0.032479122760646593 244:0.91:13945:13946 ~-0.022668602371378865 127:1.046875:13947:13948 ~0.03551558660497842 "
    s .= "~-0.019387546048901624 ~-0.03434910103082063 ~-0.027352008002900025 249:0.5:13952:13953 ~-0.004099302127908034 250:1.1953125:13954:13955 ~0.008928189448405456 ~0.07589091121212535 3:0.078125:13957:13958 "
    s .= "~-0.05823000375332552 ~-0.0006591719253810115 ~-0.028328288617950028 217:0.1875:13961:13976 93:0.703125:13962:13973 243:0.25:13963:13972 157:0.5625:13964:13971 244:1.025:13965:13970 4:0.25:13966:13969 "
    s .= "142:0.5625:13967:13968 ~-0.03533338256632466 ~0.05971354221865206 ~0.07669080213228907 ~-0.05197047085958502 ~0.03549715487373165 ~0.0032903728131640445 162:0.453125:13974:13975 ~-0.05004231264279527 "
    s .= "~0.016898893112672262 84:0.2265625:13977:13996 4:0.265625:13978:13991 251:0.828125:13979:13986 118:0:13980:13981 ~-0.043133862194150864 163:0.359375:13982:13983 ~0.009611498519954062 133:1.34375:13984:13985 "
    s .= "~-0.05046405494964821 ~0.017924609765401587 220:0.3125:13987:13990 154:0.890625:13988:13989 ~-0.028275374670856397 ~0.01768721954974629 ~0.01702009251699157 28:-0.3125:13992:13993 ~0.04193209043203201 "
    s .= "136:1.4375:13994:13995 ~-0.04590382514482305 ~-0.00036365437736149317 1:0.46875:13997:14006 1:0.015625:13998:14001 33:0.625:13999:14000 ~0.028172733308948213 ~-0.036384302756871094 179:-0.046875:14002:14003 "
    s .= "~-0.04822061467801251 53:0.359375:14004:14005 ~0.02225833585045134 ~-0.06306413291375117 ~0.052534253971246614 81:1.0234375:14008:14053 246:1.890625:14009:14052 247:0.765625:14010:14047 111:0.3828125:14011:14042 "
    s .= "237:0.484375:14012:14035 106:0.046875:14013:14018 245:1.8405797101449275:14014:14015 ~0.007853936963363305 157:0.46875:14016:14017 ~-0.038148988147898355 ~-0.00468762564909279 7:0.90625:14019:14032 "
    s .= "160:0.0625:14020:14027 76:0.484375:14021:14026 248:0.875:14022:14025 174:0.5625:14023:14024 ~0.014404360002439963 ~-0.0481748474640141 ~-0.02928625608897456 ~0.043643530085401144 244:1.465:14028:14031 "
    s .= "91:1.3125:14029:14030 ~-0.005667707605881956 ~0.029392793814762633 ~0.00845120047344994 245:1.596774193548387:14033:14034 ~0.043359830360709645 ~-0.035001998278333696 7:-0.359375:14036:14037 ~0.023983236921404638 "
    s .= "88:1.078125:14038:14041 109:-0.21875:14039:14040 ~0.040632490247054245 ~-0.03058522441477132 ~0.018586585445677282 195:0.0625:14043:14044 ~-0.031151995798703674 249:0.5:14045:14046 ~0.002806142744810539 "
    s .= "~0.05394379058730379 103:0.15625:14048:14051 184:0.21875:14049:14050 ~-0.04082613829315763 ~0.029870575795154793 ~-0.05423334789864164 ~0.031245070994109222 ~-0.04752268701487307 244:2.79:14055:14088 "
    s .= "100:1.046875:14056:14075 184:0.609375:14057:14070 154:0.609375:14058:14065 244:1.27:14059:14062 257:0.7741935483870968:14060:14061 ~0.004033517807899257 ~-0.033779367734855535 79:-0.09375:14063:14064 "
    s .= "~0.0036471593731080016 ~-0.027598544081189127 202:-0.046875:14066:14069 34:0.1875:14067:14068 ~-0.032846384206859806 ~0.01651409509449601 ~0.011508473456411856 124:0.828125:14071:14074 244:1.365:14072:14073 "
    s .= "~-0.003959746316893802 ~0.023456483385184444 ~-0.03941411929681854 223:0.4375:14076:14087 244:0.835:14077:14078 ~0.11003172111499421 241:0.24:14079:14082 10:0.3125:14080:14081 ~-0.03621202658312574 ~0.036580511813989275 "
    s .= "154:0.359375:14083:14084 ~0.04320228756445111 244:1.065:14085:14086 ~-0.046115585828090104 ~0.01897916337889622 ~-0.03704031903531989 186:-0.1875:14089:14096 238:1.171875:14090:14093 112:0.0625:14091:14092 "
    s .= "~-0.036583972656167744 ~0.02751211550049671 252:0.175:14094:14095 ~0.033253159116131144 ~-0.07913097953958909 23:0.359375:14097:14100 37:-0.046875:14098:14099 ~0.007829384490601155 ~-0.057507020376297215 "
    s .= "~0.04014887942747322 "
    return s
}
