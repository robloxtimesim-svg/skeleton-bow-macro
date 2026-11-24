; ======================================================================
;  Skeleton bow turret (AI) v12 - shoots skeletons from far away  AutoHotkey v2
;
;  F1  start / stop          F5  show what the macro sees (5 seconds)
;  F6  make the AI forget what it learned while playing
;  F7  mark your character: put the mouse on your character, press F7
;  F9  no-shoot circle: mouse on something it must never shoot, press F9
;      (F9 again inside the circle removes it)
;  F8  quit
;
;  THE AI
;    It finds every skeleton-like thing - bones, light armour and helmets,
;    the dark blue armour that does not stand out by brightness on a sunny
;    day - by day, at dusk and at night. The light's colour is measured on
;    every look and taken off first, but (new in v11) plain white still
;    counts when that measurement is fooled, e.g. by lots of blue-grey stone
;    on screen, and so do sunlit bones that look a little yellow and (new
;    in v12) bones turned cream / peach by the low orange sun at sunset.
;    Then TWO trained models (300 + 300 decision trees, learned from ~88,000
;    examples cut from all your clips plus darker / brighter / sunset-orange
;    copies and copies worked out with a wrong light colour; the second one
;    gives every clip equal say so the far-back crowd counts as much as the
;    close ones) vote on what is a skeleton: white or armoured, near or far in the back
;    - against rocks, ore, trees, flowers, water, text, arrows, pop-ups,
;    dropped bones and the boss.
;    It aims at the chest: across at the solid middle of the body (never out
;    on the sword), up and down between the head and the hips.
;    THE BOSS: while its health bar shows, it finds the boss by the teal glow
;    it stands in and shoots nothing within BossRadius of it - not its body,
;    not its sword, and it lets go of a target that walks into it.
;    The AI no longer shifts itself while playing (that made it drift into
;    shooting the boss after an hour or two). Every hit is still written to
;    skeleton_bow_examples_v12.txt - send it over to train the next version.
;
;  HOW TO USE
;    1. Bow in hotbar slot 1 (change BowSlot below if not).
;    2. Stand anywhere you like (somewhere safe and high is best, like the
;       rock in your clip) with any camera angle, as long as the skeletons
;       are on screen. Close the chat window.
;    3. Put the mouse on your character and press F7 (once per spot /
;       camera setup - it is saved). Arrow flight times are worked out
;       from there.
;    4. Press F5: every skeleton it would shoot gets a red box with how sure
;       the AI is (in %) and a yellow dot where it aims. Keep the camera
;       still while it runs.
;    5. Press F1. It does NOT move you or the camera. For each skeleton it
;       holds the left button while watching the skeleton (the mouse waits
;       on your own character so the game's crosshair does not get in the
;       way), works out where it is walking, and at the end of the draw
;       puts the mouse where the skeleton WILL be when the arrow lands
;       (arrows fly 0.6-1.0 s), then lets go. It reads the damage numbers
;       and the green "+1 Bone" to know if it hit, missed or killed, and
;       keeps shooting the same one until it dies. If it dies while the
;       next arrow is drawn, that arrow goes to another skeleton.
;
;  Do not run this together with the ore miner - both use the mouse.
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
Cfg.AutoEquip := true     ; take the bow out again if it gets put away
Cfg.DrawMs    := 1150     ; how long the button is held (full draw; you hold 1.0-1.2 s in the clip)
Cfg.GapMs     := 300      ; pause between two shots

; --- aiming ---
Cfg.LeadTargets := true    ; aim where a walking skeleton WILL be when the arrow lands
Cfg.LeadFraction := 0.8    ; how much of the walk to aim ahead (1.0 = all of it)
Cfg.MinSpeed    := 8       ; slower than this (pixels per second) counts as standing still
Cfg.LeadWindowMs := 600    ; how much of the recent walk is used to judge speed and direction
Cfg.MaxLeadPx   := 120     ; never aim further ahead than this
Cfg.AimSettleMs := 120     ; the mouse goes onto the aim spot this long before letting go
; arrow flight time in seconds = FlightA + FlightB * distance (spots further back
; in the picture count FlightDepth times more) - measured in your clip
Cfg.FlightA     := -0.009
Cfg.FlightB     := 0.0016
Cfg.FlightDepth := 2.4
Cfg.LearnFlight := true    ; fine-tune the flight time from the damage numbers of its own hits
Cfg.PatienceFlight := 0.8  ; for shots longer than this (seconds) at a jumpy walker: wait for a steady moment
Cfg.MaxWaitMs   := 1500    ; ...but never wait longer than this (the bow stays drawn meanwhile)

; --- targets ---
Cfg.MaxRangePx  := 5000   ; ignore heads further than this from your character (5000 = whole screen)
Cfg.MinRangePx  := 130    ; ignore heads closer than this (that is you / your bow)
Cfg.SameTargetPx := 70    ; a head this close to the last shot is "the same skeleton"
Cfg.MaxHitsSame := 5      ; give up on one that took this many LANDED hits and is still alive
Cfg.MaxMissesInRow := 3   ; ...or that this many arrows in a row missed (out of range, behind a wall)
Cfg.MaxShotsSame := 8     ; ...or after this many shots at it, whatever happened
Cfg.MissGiveUpSec := 12   ; after 3 misses: leave that spot alone this long (seconds)
Cfg.GiveUpSec   := 30     ; after 5 hits / 8 shots: leave it alone this long
Cfg.IgnoreBoss  := true   ; while the boss's health bar shows, do not shoot the boss
Cfg.BossRadius  := 190    ; ...nor anything this close to it (its body, sword and glow)
Cfg.NoShootRadius := 170  ; size of a no-shoot circle made with F9

; --- AI ---
Cfg.UseAI         := true  ; false = use the old hand-written rules instead of the AI
Cfg.AIMinConfidence := 60  ; only shoot what the AI is at least this % sure is a skeleton
                           ;   (raise to 70-80 if it shoots rocks, lower to 45 if it skips skeletons)
Cfg.LearnWhilePlaying := false ; true = let the AI shift itself from hits while playing. Off: it only
                           ;   ever learned "shoot more" and after an hour or two shot the boss too.
                           ;   Hits are still saved to the examples file (send it over to improve the AI).

Cfg.PlayerX := 965        ; where your character stands on screen - set it with F7
Cfg.PlayerY := 590        ; (mouse on your character, press F7; it is saved)

; ------------------------------ STATE ---------------------------------
State := {}
State.running := false
State.busy := false
State.stop := false
State.hwnd := 0
State.heads := []
State.black := []
State.cur := 0            ; {x, y, shots}
State.shots := 0
State.kills := 0
State.given := 0
State.lastEquip := 0
State.equipTries := 0
State.equipOff := false
State.overlayUntil := 0
State.scanMs := 0
State.startTick := 0
State.viewMoved := false
State.allCands := []
State.pending := []       ; arrows in the air: {t, x, y, f, target...}
State.hits := 0
State.misses := 0
State.lastLead := 0
State.lastLook := 0
State.grabTick := 0
State.prevTick := 0
State.fsNear := 1.0       ; learned flight-time correction, nearer spots
State.fsFar := 1.0        ; ... and spots far back
State.strikes := []
State.zones := []         ; no-shoot circles (F9)
State.bossUp := false
State.bossX := 0, State.bossY := 0, State.bossT := 0, State.bossLook := 0
State.lab := 0

LW := 960, LH := 540      ; the macro works on a half-size copy of the picture
RINGK := 16
GM := 60                  ; brightness of the grass, measured on every look
BrainFile := A_ScriptDir "\skeleton_bow_learned_v12.txt"    ; v12: a new AI, so it starts fresh
ExamplesFile := A_ScriptDir "\skeleton_bow_examples_v12.txt"
SettingsFile := A_ScriptDir "\skeleton_bow_settings.txt"
Brain := 0, MA := 0, MB := 0
BLK := Buffer(120 * 68 * 4, 0)   ; skeleton-like stuff per 16x16 spot (finds the boss)
TB := 90, TintB := 0, TintG := 0
ROW0 := 30, ROW1 := 470       ; rows of that copy that are looked at (no top bar, no hotbar)

MakeStatusBar()
SetStatus("Loading the AI...")
LoadModel()
LoadBrain()
LoadSettings()
SetStatus("Bow turret ready (AI: " MA.roots.Length "+" MB.roots.Length " trees, learned from " Brain.kills " hits).  "
    . "F7 mark your character   F9 no-shoot circle   F1 start   F5 show what I see   F8 quit")
SetTimer(Tick, 60)
OnExit((*) => ReleaseAll())

F1::ToggleRun()
F5::ShowWhatISee()
F6::ForgetLearning()
F7::SetPlayerSpot()
F9::ToggleNoShoot()
F8::ExitApp()

; ------------------------------ START / STOP --------------------------
ToggleRun() {
    if State.running {
        State.running := false
        State.stop := true
        ReleaseAll()
        SetStatus("Stopped.  F1 start   F5 show what I see   F6 forget learning   F8 quit")
        return
    }
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
    State.cur := 0, State.black := [], State.pending := [], State.strikes := []
    State.hits := 0, State.misses := 0, State.kills := 0, State.shots := 0, State.given := 0
    State.equipTries := 0, State.equipOff := false
    State.startTick := A_TickCount
    State.running := true
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

; ------------------------------ MAIN LOOP -----------------------------
Tick() {
    if (!State.running || State.busy)
        return
    State.busy := true
    try
        TickBody()
    finally
        State.busy := false
}

TickBody() {
    if (A_TickCount < State.overlayUntil)
        return
    if !WinExist("ahk_id " State.hwnd) {
        State.running := false
        ReleaseAll()
        SetStatus("Roblox closed - stopped.")
        return
    }
    if !WinActive("ahk_id " State.hwnd) {
        ReleaseAll()
        SetStatus("Paused - click the Roblox window to continue.")
        Sleep 200
        return
    }

    ; the game draws its own crosshair at the mouse: move it onto our own
    ; character first so it is never mistaken for a head
    ParkMouse()
    Sleep 70
    t0 := A_TickCount
    if !Scan()
        return
    State.scanMs := A_TickCount - t0
    PlaceStatusBar()
    EnsureBow()

    if State.viewMoved {
        State.cur := 0
        SetStatus("the view moved - looking again" StatTail())
        Sleep 200
        return
    }
    cur := State.cur
    if (cur && (cur.dead || GiveUpNow(cur))) {
        State.cur := 0, cur := 0
    }
    tgt := PickTarget()
    same := (cur && tgt && SameTarget(cur, tgt))
    if (cur && !same) {
        LeaveTarget(cur)
        State.cur := 0, cur := 0
    }
    if !tgt {
        SetStatus("no skeleton in view" StatTail())
        Sleep 250
        return
    }
    if same {
        AddSample(cur, State.grabTick, tgt)
        cur.score := tgt.score
    } else {
        cur := NewTarget(tgt, State.grabTick)
        State.cur := cur
    }
    SetStatus("shooting  (shot " (cur.shots + 1) " at this one, " cur.hits " landed, AI " Round(cur.score * 100) "% sure, lead "
        . State.lastLead "px)" StatTail())
    Shoot(cur)
    Sleep Cfg.GapMs
}

; We stop aiming at the old target. If it was shot and nothing skeleton-like
; is left where it stood, it died: count it and let the AI learn from it.
LeaveTarget(cur) {
    if (cur.counted || cur.hits < 1)
        return                        ; never hit: it walked away or hid, not a kill
    pr := MotionAt(cur, State.grabTick)
    for o in State.allCands {
        if (Abs(o.cx - pr.x) <= Cfg.SameTargetPx && Abs(o.cy - pr.y) <= Cfg.SameTargetPx)
            return                    ; still there (we just picked something else)
    }
    cur.counted := true
    State.kills += 1
    if !cur.learned {
        cur.learned := true
        LearnFrom(cur, 1)
    }
}

; Is this detection the skeleton we are already shooting (where it should be by now)?
SameTarget(cur, h) {
    pr := MotionAt(cur, State.grabTick)
    return Dist(h.x, h.y, pr.x, pr.y) <= Cfg.SameTargetPx
}

StatTail() {
    el := (A_TickCount - State.startTick) // 1000
    return "  |  in view " State.heads.Length "  |  shots " State.shots "  hit " State.hits "  missed " State.misses
        . "  kills " State.kills "  gave up " State.given
        . (State.bossUp ? "  |  boss up: ignored" : "")
        . (Cfg.UseAI ? "  |  AI learned " Brain.kills " hits, " Brain.wrong " wrong" : "  |  AI off")
        . "  |  " (el // 60) "m" Format("{:02}", Mod(el, 60)) "s  " State.scanMs "ms"
}

; Same skeleton as before if it is still there, otherwise the one the AI is surest about.
PickTarget() {
    px := Cfg.PlayerX, py := Cfg.PlayerY
    cur := State.cur
    best := 0, bestScore := -1.0e9
    for h in State.heads {
        d := Dist(h.x, h.y, px, py)
        if (d > Cfg.MaxRangePx || d < Cfg.MinRangePx)
            continue
        if IsBlack(h.x, h.y)
            continue
        sc := h.score                          ; the one the AI is surest about first
        if (cur && !cur.dead && SameTarget(cur, h))
            sc += 1000
        if (sc > bestScore)
            best := h, bestScore := sc
    }
    return best
}

IsBlack(x, y) {
    now := A_TickCount
    i := State.black.Length
    while (i >= 1) {
        b := State.black[i]
        if (b.until && now > b.until)
            State.black.RemoveAt(i)
        else if (Dist(x, y, b.x, b.y) < (b.HasOwnProp("r") ? b.r : 30))
            return true
        i -= 1
    }
    return false
}

; Roblox only takes a new mouse spot after a small real move - without the
; nudge its crosshair (and the white charge bar) stay where they were.
ParkMouse() {
    MouseMove Round(Cfg.PlayerX * State.cw / 1920), Round(Cfg.PlayerY * State.ch / 1080), 0
    MouseMove 1, 0, 0, "R"
    MouseMove -1, 0, 0, "R"
}

; Hold the bow, keep watching the skeleton with the mouse waiting on your own
; character (so the game's white crosshair and charge bar never cover it),
; work out where it is walking, and only at the very end put the mouse where
; the skeleton WILL be when the arrow lands. Then let go.
; If the skeleton dies or is lost while drawing, another one is picked and the
; drawn arrow goes to that one instead.
Shoot(cur) {
    ParkMouse()
    Sleep 30
    Click "Down"
    t0 := A_TickCount
    Sleep 60                                  ; let the game move its crosshair away first
    holdUntil := t0 + Cfg.DrawMs
    waitEnd := holdUntil - Cfg.AimSettleMs + Cfg.MaxWaitMs
    hardEnd := waitEnd + 2500
    loop {
        if (State.stop || !WinActive("ahk_id " State.hwnd)) {
            Click "Up"
            return false
        }
        now := A_TickCount
        if (now >= holdUntil - Cfg.AimSettleMs && TargetReady(cur, now)) {
            if (now >= waitEnd || Steady(cur))
                break
            SetStatus("waiting for a steady moment (long shot at a walking skeleton)" StatTail())
        }
        if (now >= hardEnd)
            break
        ok := TrackStep(cur)
        now := A_TickCount
        if BossZone(cur.x, cur.y)
            cur.dead := true, cur.counted := true
        if (cur.dead || GiveUpNow(cur) || (!ok && now - cur.seen > 450)) {
            nt := FindNewTarget(cur)          ; the bow stays drawn meanwhile
            if nt {
                cur := nt
                State.cur := nt
                SetStatus("switched target while drawing (AI " Round(nt.score * 100) "% sure)" StatTail())
            }
        }
        Sleep 15
    }
    ; ---- aim where it will be, then let go ----
    tRel := A_TickCount + Cfg.AimSettleMs
    a := AimPoint(cur, tRel)
    if (BossZone(cur.x, cur.y) || BossZone(a.x, a.y)) {
        Click "Up"                            ; nothing safe to shoot: let go on our own spot
        State.cur := 0
        return false
    }
    base := TextCounts(a.x, a.y)              ; the clean picture, before the crosshair moves there
    AimAt(a.x, a.y)
    MouseMove 1, 0, 0, "R"                    ; Roblox only notices the mouse after a nudge
    Sleep Cfg.AimSettleMs
    Click "Up"
    tRel := A_TickCount
    cur.shots += 1
    State.shots += 1
    State.lastLead := Round(a.lead)
    State.pending.Push({t: tRel, x: a.x, y: a.y, f: a.f, fBase: a.fBase, o0: base.orange, g0: base.green
        , target: cur, hitAt: 0})
    ParkMouse()                               ; off the target right away: a clean view of the next look
    return true
}

AimAt(rx, ry) {
    MouseMove Round(rx * State.cw / 1920), Round(ry * State.ch / 1080), 0
    MouseMove 1, 0, 0, "R"
    MouseMove -1, 0, 0, "R"
}

; ---- tracking ----
; Targets are followed by their "core" (head / chest / helmet), so a swinging
; sword does not pull the aim off the body.
NewTarget(c, t) {
    o := {x: c.x, y: c.y, cx: c.x, cy: c.y, h: c.h, n: c.n, tr: [], seen: t, fx: c.x, fy: c.y, moved: 0
        , shots: 0, hits: 0, missRow: 0, dead: false, counted: false, learned: false
        , score: c.score, raw: c.raw, sc: c.sc}
    if c.HasOwnProp("feat")
        o.feat := c.feat
    o.tr.Push({t: t, x: c.x, y: c.y})
    return o
}

AddSample(cur, t, s) {
    cur.tr.Push({t: t, x: s.x, y: s.y})
    while (cur.tr.Length > 2 && t - cur.tr[1].t > 1500)
        cur.tr.RemoveAt(1)
    cur.seen := t, cur.n := s.n, cur.h := s.h
    cur.cx := s.x, cur.cy := s.y
    cur.x := Round(s.x), cur.y := Round(s.y)
    cur.moved := Max(cur.moved, Dist(s.x, s.y, cur.fx, cur.fy))
}

; One look at the target: the skeleton-like patch nearest to where it should be now.
TrackStep(cur) {
    if !Grab()
        return false
    now := State.grabTick
    CheckShots(now)
    if cur.dead
        return false
    p := State.pBits
    pr := MotionAt(cur, now)
    R := Min(26 + (now - cur.seen) // 25, 60)          ; search radius (half-size pixels)
    hx := Round(pr.x / 2), hy := Round(pr.y / 2)
    lab := Buffer(LW * LH * 2, 0)
    k := 0
    best := 0, bestCost := 1.0e9, bx := 0, by := 0
    y := Max(hy - R, ROW0), yEnd := Min(hy + R, ROW1 - 1)
    while (y <= yEnd) {
        x := Max(hx - R, 0), xEnd := Min(hx + R, LW - 1)
        while (x <= xEnd) {
            j := y * LW + x
            if !NumGet(lab, j * 2, "ushort") {
                rr := BodyPx(p, x, y)
                if rr {
                    k += 1
                    bl := FillBody(p, lab, k, x, y, rr)
                    if (!Hud(bl.cx, bl.cy) && bl.n >= 4 && bl.n <= 500 && bl.w <= 34 && bl.h <= 40) {
                        AimSpot(bl)
                        ax := bl.x, ay := bl.y
                        cost := Dist(ax, ay, pr.x, pr.y) + Abs(bl.n - cur.n) * 0.5
                        if (cost < bestCost)
                            best := bl, bestCost := cost, bx := ax, by := ay
                    }
                } else {
                    NumPut("ushort", 65535, lab, j * 2)
                }
            }
            x += 2
        }
        y += 2
    }
    if (!best || Dist(bx, by, pr.x, pr.y) > R * 2)
        return false
    AddSample(cur, now, {x: bx, y: by, n: best.n, h: best.h})
    return true
}

TargetReady(cur, now) => (!cur.dead && cur.tr.Length >= 2 && now - cur.seen <= 300)

; Fine to let go now? Short shots: always. Long shots: only when the skeleton
; stands still or walks steadily (a jumpy walk can't be predicted that far).
Steady(cur) {
    m := Motion(cur)
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
Motion(cur) {
    tr := cur.tr
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
    ; how far the looks are from a straight steady walk (pixels)
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

MotionAt(cur, tAt) {
    m := Motion(cur)
    dt := (tAt - m.t) / 1000
    return {x: m.x + m.vx * dt, y: m.y + m.vy * dt}
}

; How long an arrow flies to this spot (measured in your clip: 0.6 s to the
; sides and closer, up to 1.0 s for spots further back in the picture).
FlightBase(x, y) {
    dx := x - Cfg.PlayerX, dy := y - Cfg.PlayerY
    if (dy < 0)
        dy := dy * Cfg.FlightDepth
    return Clamp(Cfg.FlightA + Cfg.FlightB * Sqrt(dx * dx + dy * dy), 0.3, 2.0)
}

; The mouse position at release: where the skeleton will be when the arrow lands.
AimPoint(cur, tRel) {
    m := Motion(cur)
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

; While the bow is drawn: look for another skeleton (old one died / was lost).
FindNewTarget(old) {
    cands := Detect()
    now := State.grabTick
    best := 0, bestScore := -1.0e9
    for c in cands {
        d := Dist(c.x, c.y, Cfg.PlayerX, Cfg.PlayerY)
        if (d > Cfg.MaxRangePx || d < Cfg.MinRangePx || IsBlack(c.x, c.y))
            continue
        if (old && Dist(c.x, c.y, old.x, old.y) < 30)
            continue                              ; that is the old one (or what is left of it)
        if (c.score > bestScore)
            best := c, bestScore := c.score
    }
    return best ? NewTarget(best, now) : 0
}

; ---- did the arrow land? ----
; Damage numbers are orange, a kill shows a green "+1 Bone": both pop up just
; above the spot the arrow went to. No number by the time the arrow should be
; there = a miss.
TextCounts(x, y) {
    p := State.pBits
    x1 := Max(Floor((x - 50) / 2), 0), x2 := Min(Floor((x + 50) / 2), LW - 1)
    y1 := Max(Floor((y - 80) / 2), 0), y2 := Min(Floor((y + 15) / 2), LH - 1)
    o := 0, g := 0
    yy := y1
    while (yy <= y2) {
        q := p + (yy * LW + x1) * 4
        xx := x1
        while (xx <= x2) {
            c := NumGet(q, "uint")
            q += 4
            r := (c >> 16) & 255, gg := (c >> 8) & 255, b := c & 255
            if (r > 205 && gg > 110 && gg < 200 && b < 135 && r - gg > 40)
                o += 1
            else if (gg > 200 && gg - r > 60 && gg - b > 80)
                g += 1
            xx += 1
        }
        yy += 1
    }
    return {orange: o, green: g}
}

CheckShots(now) {
    prevLook := State.lastLook
    State.lastLook := now
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
            ShotResult(s, res, now, prevLook)
            State.pending.RemoveAt(i)
        } else {
            i += 1
        }
    }
}

ShotResult(s, res, now, prevLook) {
    t := s.target
    if (res = "miss") {
        t.missRow += 1
        State.misses += 1
        return
    }
    t.hits += 1, t.missRow := 0
    State.hits += 1
    ; learn how long arrows really fly (only from clean hits)
    seenAt := s.hitAt ? s.hitAt : (prevLook > s.t ? (now + prevLook) / 2 : now)
    meas := (seenAt - s.t) / 1000
    if (Cfg.LearnFlight && meas > 0.3 && meas < 2.5 && s.fBase > 0) {
        r := Clamp(meas / s.fBase, 0.7, 1.5)
        wf := Clamp((Cfg.PlayerY - s.y - 100) / 200, 0, 1)
        State.fsNear := Clamp(State.fsNear + 0.2 * (1 - wf) * (r - State.fsNear), 0.7, 1.5)
        State.fsFar := Clamp(State.fsFar + 0.2 * wf * (r - State.fsFar), 0.7, 1.5)
        SaveSettings()
    }
    t.hitsEver := true
    if !t.learned {
        t.learned := true
        LearnFrom(t, 1)                       ; damage seen: that WAS a skeleton
    }
    if (res = "kill" && !t.counted) {
        t.dead := true, t.counted := true
        State.kills += 1
        State.black.Push({x: s.x, y: s.y, r: 25, until: now + 1500})     ; ignore the bits it leaves for a moment
        State.black.Push({x: t.x, y: t.y, r: 25, until: now + 1500})
    }
}

; 5 landed hits and still alive, or 3 misses in a row (out of range, behind
; a wall...), or far too many shots: leave that spot alone for a short while.
; Only something that never moves and is given up on twice without a single
; hit is left alone longer - and teaches the AI "not a skeleton".
GiveUpNow(cur) {
    if cur.dead
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
                if (Dist(o.x, o.y, cur.x, cur.y) < 30 && now - o.t < 600000) {
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
                secs := 120
                if !cur.learned {
                    cur.learned := true
                    LearnFrom(cur, 0)
                }
            }
        }
    }
    State.black.Push({x: cur.x, y: cur.y, r: rad, until: now + secs * 1000})
    State.given += 1
    cur.dead := true, cur.counted := true
    return true
}

Dist(x1, y1, x2, y2) => Sqrt((x1 - x2) ** 2 + (y1 - y2) ** 2)


; ------------------------------ BOW IN HAND ---------------------------
BowEquipped() {
    left := 602 + 85 * (Cfg.BowSlot - 1)
    x1 := Round((left + 10) * State.cw / 1920), x2 := Round((left + 70) * State.cw / 1920)
    y1 := Round(974 * State.ch / 1080), y2 := Round(986 * State.ch / 1080)
    try
        return PixelSearch(&fx, &fy, x1, y1, x2, y2, 0xF2D88E, 45)
    catch
        return true
}

EnsureBow() {
    if (!Cfg.AutoEquip || State.equipOff || A_TickCount - State.lastEquip < 4000)
        return
    State.lastEquip := A_TickCount
    if BowEquipped() {
        State.equipTries := 0
        return
    }
    State.equipTries += 1
    if (State.equipTries > 3) {
        State.equipOff := true      ; cannot read the hotbar: leave it alone
        return
    }
    Send "{" Cfg.BowSlot "}"
    Sleep 250
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
    State.prevBuf := Buffer(LW * LH * 4, 0)
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

LumAt(p, x, y) {
    c := NumGet(p + (y * LW + x) * 4, "uint")
    return (((c >> 16) & 255) + ((c >> 8) & 255) + (c & 255)) // 3
}

InRect(x, y, x1, y1, x2, y2) => (x >= x1 && x < x2 && y >= y1 && y < y2)

; The game's own buttons and lists, and your character.
Hud(x, y) {
    return InRect(x, y, 1600, 0, 1920, 310) || InRect(x, y, 20, 370, 110, 770) || InRect(x, y, 1620, 830, 1920, 960)
        || InRect(x, y, 0, 0, 320, 70) || x < 30 || x > 1890
        || InRect(x, y, Cfg.PlayerX - 90, Cfg.PlayerY - 110, Cfg.PlayerX + 90, Cfg.PlayerY + 110)
}

; Teal text (the boss name, e.g. MORTEN) just above this spot? Then the
; white text under it is the "Spawns in" timer, not a skeleton.
TealAbove(cx, cy) {
    p := State.pBits
    hx := Floor(cx / 2), hy := Floor(cy / 2)
    cnt := 0
    y := Max(hy - 45, 0)
    while (y <= hy - 3) {
        x := Max(hx - 100, 0), xEnd := Min(hx + 100, LW - 1)
        while (x <= xEnd) {
            c := NumGet(p + (y * LW + x) * 4, "uint")
            r := (c >> 16) & 255, g := (c >> 8) & 255, b := c & 255
            if (g >= 170 && b >= 140 && r <= 150 && g - r >= 70)
                cnt += 1
            x += 2
        }
        y += 2
    }
    return cnt >= 15
}

; ---- the light: day, dusk, night, rain ----
; GM   = how bright the grass is
; TintB, TintG = how blue / green white things look right now (moonlight and
;        dusk make everything bluish) - taken off before colours are judged.
SceneLight() {
    global GM, TB, TintB, TintG
    p := State.pBits
    hist := Buffer(1024, 0)
    cnt := 0
    y := 40
    while (y < ROW1) {
        q := p + y * LW * 4
        loop 240 {
            c := NumGet(q, "uint")
            q += 16
            r := (c >> 16) & 255, g := (c >> 8) & 255, b := c & 255
            if (g > r + 12 && g > b + 12) {
                hh := ((r + g + b) // 3) * 4
                NumPut("uint", NumGet(hist, hh, "uint") + 1, hist, hh)
                cnt += 1
            }
        }
        y += 4
    }
    gmed := 50
    if (cnt > 50) {
        acc := 0
        loop 256 {
            acc += NumGet(hist, (A_Index - 1) * 4, "uint")
            if (acc * 2 >= cnt) {
                gmed := A_Index - 1
                break
            }
        }
    }
    GM := Max(30, Min(gmed, 110))
    TB := Max(90, GM * 14 // 10)
    tl := Max(100, GM * 16 // 10)
    hb := Buffer(512 * 4, 0), hg := Buffer(512 * 4, 0)
    n := 0
    y := ROW0
    while (y < ROW1) {
        q := p + y * LW * 4
        loop 240 {
            c := NumGet(q, "uint")
            q += 16
            r := (c >> 16) & 255, g := (c >> 8) & 255, b := c & 255
            if ((r + g + b) // 3 >= tl && b >= r - 10) {
                mx := Max(r, g, b), mn := Min(r, g, b)
                if (mx - mn <= 80 && mn < 250) {
                    i := (b - r + 256) * 4
                    NumPut("uint", NumGet(hb, i, "uint") + 1, hb, i)
                    i := (g - r + 256) * 4
                    NumPut("uint", NumGet(hg, i, "uint") + 1, hg, i)
                    n += 1
                }
            }
        }
        y += 4
    }
    if (n < 30) {
        TintB := 0, TintG := 0
        return
    }
    TintB := Clamp(HistMedian(hb, n), 0, 45)
    TintG := Clamp(HistMedian(hg, n), -5, 20)
}

; Median of the values counted in a histogram (value v stored at v + 256),
; the middle two averaged and cut to a whole number - same as in training.
HistMedian(h, n) {
    k1 := (n - 1) // 2, k2 := n // 2
    v1 := "", v2 := "", acc := 0
    loop 512 {
        acc += NumGet(h, (A_Index - 1) * 4, "uint")
        if (v1 = "" && acc > k1)
            v1 := A_Index - 1 - 256
        if (acc > k2) {
            v2 := A_Index - 1 - 256
            break
        }
    }
    return Integer((v1 + v2) / 2)
}

; Is this pixel part of a skeleton-like thing?  0 if not, otherwise the
; brightness of what is around it + 1 (+ 1000 when it is armour blue).
;   pale:  bright (well above the grass), white / grey / blue-grey once the
;          light's tint is taken off - or plain white / grey as it is, in
;          case the tint was misjudged (lots of blue-grey stone on screen),
;          or sunlit slightly-yellow white when very bright, or cream /
;          peach bone in low orange sunlight (sunset) - and clearly
;          brighter than what is 32 px left, right, above and below (bones,
;          light helmets)
;   armour blue: clearly blue and a little green (not water, not rock) and
;          much bluer than its surroundings - the dark blue armour that is
;          not brighter than the grass on a sunny day
BodyPx(p, x, y) {
    c := NumGet(p + (y * LW + x) * 4, "uint")
    r := (c >> 16) & 255, g := (c >> 8) & 255, b := c & 255
    lum := (r + g + b) // 3
    g2 := g - TintG, b2 := b - TintB
    db := b2 - r, dg := g2 - r
    isA := false
    if (lum >= TB && Min(r, g, b) < 252) {
        if (db >= -15 && db <= 60 && dg >= -15 && dg <= 32) {
            mx := r > g2 ? r : g2
            if (b2 > mx)
                mx := b2
            mn := r < g2 ? r : g2
            if (b2 < mn)
                mn := b2
            isA := (mx - mn <= 60)
        }
        if !isA {                                 ; plain white even if the tint was misjudged,
            db0 := b - r, dg0 := g - r            ; and sunlit (slightly yellow) bone when very bright
            if (db0 >= (lum >= 190 ? -40 : -15) && db0 <= 60 && dg0 >= -15 && dg0 <= 32)
                isA := (Max(r, g, b) - Min(r, g, b) <= 60)
            ; bone in low orange sunlight (sunset, 'Scorching'): cream to peach
            if (!isA && lum >= 140 && db0 >= -95 && db0 < -15 && dg0 >= -50 && dg0 <= 0 && g >= b
                && (g - b) * 100 >= (r - b) * 20)
                isA := true
        }
    }
    isB := (db >= 40 && db <= 105 && dg >= 12 && dg <= 45 && dg * 100 >= db * 28 && lum >= Max(60, GM * 8 // 10))
    if (!isA && !isB)
        return 0
    xl := x >= RINGK ? x - RINGK : 0, xr := x + RINGK < LW ? x + RINGK : LW - 1
    yu := y >= RINGK ? y - RINGK : 0, yd := y + RINGK < LH ? y + RINGK : LH - 1
    ring := (LumAt(p, xl, y) + LumAt(p, xr, y) + LumAt(p, x, yu) + LumAt(p, x, yd)) // 4
    if (isA && lum * 100 < ring * 130)
        isA := false
    if isB {
        rdb := Floor((BlueAt(p, xl, y) + BlueAt(p, xr, y) + BlueAt(p, x, yu) + BlueAt(p, x, yd)) / 4)
        isB := (b - r - rdb >= 25)
    }
    if (!isA && !isB)
        return 0
    return ring + 1 + (isB ? 1000 : 0)
}

BlueAt(p, x, y) {
    c := NumGet(p + (y * LW + x) * 4, "uint")
    return (c & 255) - ((c >> 16) & 255)
}

; One connected patch of skeleton-like pixels (labelled k in lab), with its
; colour numbers and its "core": the pixels whose 4 neighbours are part of the
; patch too. Thin things - a sword, an arm, an arrow - have no core; a skull,
; a helmet or a chest has. The core is where it aims.
FillBody(p, lab, k, sx0, sy0, ring0) {
    stack := [sy0 * LW + sx0]
    NumPut("ushort", k, lab, (sy0 * LW + sx0) * 2)
    n := 0, sLum := 0, sDb := 0, sDg := 0, sRing := Mod(ring0, 1000) - 1, nBlue := (ring0 >= 1000), lmax := 0, sx := 0, sy := 0
    bx1 := sx0, bx2 := sx0, by1 := sy0, by2 := sy0
    while stack.Length {
        idx := stack.Pop()
        x := Mod(idx, LW), y := idx // LW
        n += 1
        bi := ((y >> 3) * 120 + (x >> 3)) * 4     ; how much skeleton-like stuff is in each 16x16 spot
        NumPut("uint", NumGet(BLK, bi, "uint") + 1, BLK, bi)
        c := NumGet(p + idx * 4, "uint")
        r := (c >> 16) & 255, g := (c >> 8) & 255, b := c & 255
        lum := (r + g + b) // 3
        sLum += lum, sDb += b - TintB - r, sDg += g - TintG - r, sx += x, sy += y
        if (lum > lmax)
            lmax := lum
        if (x < bx1)
            bx1 := x
        if (x > bx2)
            bx2 := x
        if (y < by1)
            by1 := y
        if (y > by2)
            by2 := y
        loop 3 {
            yy := y + A_Index - 2
            if (yy < ROW0 || yy >= ROW1)
                continue
            loop 3 {
                xx := x + A_Index - 2
                if (xx < 0 || xx >= LW)
                    continue
                j := yy * LW + xx
                if NumGet(lab, j * 2, "ushort")
                    continue
                rr := BodyPx(p, xx, yy)
                if rr {
                    NumPut("ushort", k, lab, j * 2)
                    sRing += Mod(rr, 1000) - 1
                    nBlue += (rr >= 1000)
                    stack.Push(j)
                } else {
                    NumPut("ushort", 65535, lab, j * 2)
                }
            }
        }
    }
    o := {n: n, x1: bx1, x2: bx2, y1: by1, y2: by2, w: bx2 - bx1 + 1, h: by2 - by1 + 1
        , lum: sLum // n, lmax: lmax, ring: Max(sRing // n, 1), db: Integer(sDb / n), dg: Integer(sDg / n)
        , cx: sx * 2 / n, cy: sy * 2 / n, nc: 0, nBlue: nBlue}
    o.ccx := o.cx, o.ccy := o.cy
    if (n <= 500) {
        nc := 0, scx := 0, scy := 0
        y := by1
        while (y <= by2) {
            x := bx1
            while (x <= bx2) {
                j := y * LW + x
                if (NumGet(lab, j * 2, "ushort") = k
                    && y > 0 && NumGet(lab, (j - LW) * 2, "ushort") = k
                    && y < LH - 1 && NumGet(lab, (j + LW) * 2, "ushort") = k
                    && x > 0 && NumGet(lab, (j - 1) * 2, "ushort") = k
                    && x < LW - 1 && NumGet(lab, (j + 1) * 2, "ushort") = k)
                    nc += 1, scx += x, scy += y
                x += 1
            }
            y += 1
        }
        if nc
            o.nc := nc, o.ccx := scx * 2 / nc, o.ccy := scy * 2 / nc
    }
    return o
}

; Is the boss up? (its teal health bar across the top of the screen)
BossUp() {
    p := State.pBits
    y := 40
    while (y <= 62) {
        q := p + (y * LW + 350) * 4
        cnt := 0
        loop 281 {
            c := NumGet(q, "uint")
            q += 4
            r := (c >> 16) & 255, g := (c >> 8) & 255, b := c & 255
            if (g >= 150 && b >= 140 && r <= 110 && g - r >= 80)
                cnt += 1
        }
        if (cnt >= 120)
            return true
        y += 1
    }
    return false
}

; How much skeleton-like stuff is around this spot (k = 3: about 110 x 110 px).
Density(x, y, k := 3) {
    bx := Floor(x / 16), by := Floor(y / 16), cnt := 0
    j := Max(by - k, 0)
    while (j <= Min(by + k, 67)) {
        i := Max(bx - k, 0)
        while (i <= Min(bx + k, 119)) {
            cnt += NumGet(BLK, (j * 120 + i) * 4, "uint")
            i += 1
        }
        j += 1
    }
    return cnt
}

; Where is the boss? It stands in a teal glow (day and night) - the
; strongest patch of teal on screen, with a big white / armour figure on it.
FindBoss() {
    State.bossLook := A_TickCount
    p := State.pBits
    T := Buffer(60 * 34 * 4, 0)
    y := 66                                       ; below its health bar
    while (y < ROW1) {
        q := p + y * LW * 4
        row := (y >> 4) * 60
        loop 480 {
            c := NumGet(q, "uint")
            q += 8
            r := (c >> 16) & 255, g := (c >> 8) & 255, b := c & 255
            if (g >= 90 && g - r >= 30 && b - r >= 30 && Abs(g - b) <= 25) {
                i := (row + ((A_Index - 1) >> 3)) * 4
                NumPut("uint", NumGet(T, i, "uint") + 1, T, i)
            }
        }
        y += 2
    }
    best := 0, bx := 0, by := 0
    j := 0
    while (j < 30) {
        i := 0
        while (i < 60) {
            cx := i * 32 + 16, cy := j * 32 + 16
            if !Hud(cx, cy) {
                sm := 0
                jj := Max(j - 1, 0)
                while (jj <= Min(j + 1, 33)) {
                    ii := Max(i - 1, 0)
                    while (ii <= Min(i + 1, 59)) {
                        sm += NumGet(T, (jj * 60 + ii) * 4, "uint")
                        ii += 1
                    }
                    jj += 1
                }
                if (sm > best)
                    best := sm, bx := cx, by := cy
            }
            i += 1
        }
        j += 1
    }
    if (best >= 20 && Density(bx, by) >= 80)
        State.bossX := bx, State.bossY := by, State.bossT := A_TickCount
}

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

; Finds everything that could be a skeleton and lets the AI judge each one.
Detect() {
    global BLK
    SceneLight()
    p := State.pBits
    BLK := Buffer(120 * 68 * 4, 0)
    lab := Buffer(LW * LH * 2, 0)
    State.lab := lab
    allb := []
    k := 0
    y := ROW0
    while (y < ROW1 && k < 65000) {
        base := y * LW
        x := 0
        while (x < LW) {
            if !NumGet(lab, (base + x) * 2, "ushort") {
                rr := BodyPx(p, x, y)
                if rr {
                    k += 1
                    bl := FillBody(p, lab, k, x, y, rr)
                    if (bl.n >= 3)
                        allb.Push(bl)
                } else {
                    NumPut("ushort", 65535, lab, (base + x) * 2)
                }
            }
            x += 2
        }
        y += 2
    }

    ; ---- hard limits: game buttons, far too big / small / long, too faint ----
    cands := []
    for c in allb {
        if Hud(c.cx, c.cy)
            continue
        if (c.w > 34 || c.h > 40 || c.n < 5 || c.n > 500 || c.w * 10 > c.h * 25 + 30)
            continue
        c.con := c.lmax * 100 // c.ring           ; how much it stands out
        c.blue := (c.nBlue * 100 >= c.n * 40)     ; mostly armour blue
        if (!c.blue && (c.con < 150 || c.lmax * 100 // GM < 170))
            continue
        c.pri := c.con + (c.blue ? 1000 : 0)
        cands.Push(c)
    }
    if (cands.Length > 200) {                     ; armour first, then the most striking (keeps it quick)
        SortByKey(cands, "pri")
        cands.Length := 200
    }
    ; ---- neighbours: dots of an ore node, letters of a line of text ----
    for c in cands {
        nb := 0, row := 0
        for o in allb {
            if (o = c)
                continue
            if (Abs(o.cx - c.cx) <= 32 && Abs(o.cy - c.cy) <= 32 && o.lmax * 10 >= c.lmax * 7)
                nb += 1
            if (Abs(o.cy - c.cy) <= 8 && Abs(o.cx - c.cx) <= 140 && o.h <= 12)
                row += 1
        }
        c.nb := nb, c.row := row
    }
    State.allCands := cands
    boss := Cfg.IgnoreBoss && BossUp()
    State.bossUp := boss
    if (boss && A_TickCount - State.bossLook >= 500)
        FindBoss()

    ; ---- judge each one ----
    out := []
    for c in cands {
        AimSpot(c)
        if (InNoShoot(c.x, c.y) || BossZone(c.x, c.y) || BossZone(c.cx, c.cy))
            continue
        if (c.lum >= 140 && TealAbove(c.cx, c.cy))
            continue                              ; boss timer ("Spawns in ...") under the teal name
        if Cfg.UseAI {
            AIFeatures(c)
            c.raw := AIScore(c.feat)
            c.score := AIProb(c)
            if (c.score * 100 < Cfg.AIMinConfidence)
                continue
        } else {
            if (c.con < 200 || c.nb >= 3 || c.row >= 2)
                continue
            c.raw := 0, c.sc := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            c.score := Min(c.con, 999) / 1000
        }
        out.Push(c)
    }
    ; a thin piece (sword, arm) next to a solid body: keep only the body -
    ; unless it is a second small skeleton standing beside it (about as tall,
    ; upright, same row, a gap between them), as in the crowds in the back
    res := []
    for c in out {
        if (c.nc < 2) {
            body := false
            for o in out {
                if (o != c && o.nc >= 2 && Dist(o.x, o.y, c.x, c.y) <= 40 && !Twin(c, o)) {
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

; Where to aim on a patch: across, at its solid core (never out on the
; sword); up and down, half way between the core and the middle of the whole
; figure = the chest. Tiny far ones: their middle.
AimSpot(c) {
    if (c.nc >= 2) {
        c.x := Round(c.ccx), c.y := Round((c.ccy + c.cy) / 2)
    } else {
        c.x := Round(c.cx), c.y := Round(c.cy)
    }
}

; Sorts an array of objects by one number, biggest first (insertion sort - short lists).
SortByKey(arr, key) {
    i := 2
    while (i <= arr.Length) {
        v := arr[i], j := i - 1
        while (j >= 1 && arr[j].%key% < v.%key%) {
            arr[j + 1] := arr[j]
            j -= 1
        }
        arr[j + 1] := v
        i += 1
    }
}

; ------------------------------ THE AI ---------------------------------
; What the AI looks at for one candidate (256 numbers, same order as in
; training): an 8 x 10 grid over the thing and a bit around it - brightness
; against its surroundings, blue and green once the light's tint is taken
; off - and 15 numbers about the patch (size, shape, contrast, colour,
; core, neighbours, the light, how much of it is armour blue).
AIFeatures(c) {
    p := State.pBits
    x := []
    h := c.h, w := c.w
    ph := Max(h, 6) * 3 // 2 + 2
    pw := Max(ph * 4 // 5, w + 2)
    mx := (c.x1 + c.x2) // 2, my := (c.y1 + c.y2) // 2
    x0 := mx - pw // 2, y0 := my - ph // 2
    ring := c.ring
    loop 10 {
        j := A_Index - 1
        yy := Min(Max(y0 + (j * ph + ph // 2) // 10, 0), LH - 1)
        loop 8 {
            i := A_Index - 1
            xx := Min(Max(x0 + (i * pw + pw // 2) // 8, 0), LW - 1)
            col := NumGet(p + (yy * LW + xx) * 4, "uint")
            r := (col >> 16) & 255, g := (col >> 8) & 255, b := col & 255
            x.Push(Clamp(((r + g + b) // 3 - ring) / 64.0, -2.0, 2.5))
            x.Push(Clamp((b - TintB - r) / 64.0, -2.0, 2.5))
            x.Push(Clamp((g - TintG - r) / 64.0, -2.0, 2.5))
        }
    }
    gmx := Max(GM, 1)
    sc := [Min(c.n, 300) / 50.0, w / 10.0, h / 10.0, Min(c.con, 600) / 200.0, c.lum / gmx, c.db / 32.0, c.dg / 32.0
        , Min(c.nb, 8) / 4.0, Min(c.row, 6) / 3.0, GM / 64.0, (c.lmax - c.lum) / 32.0, Min(c.nc, 100) / 20.0
        , (c.ccy - c.cy) / Max(h * 2, 1), TintB / 32.0, TintG / 32.0]
    for v in sc
        x.Push(v)
    x.Push(c.nBlue / Max(c.n, 1))
    c.feat := x, c.sc := sc
}

; Runs the trees. Above 0 = more likely a skeleton than not.
AIRaw(m, x) {
    s := m.bias
    fa := m.F, ta := m.T, la := m.L, ra := m.R, va := m.V
    for root in m.roots {
        i := root
        while (k := fa[i])
            i := (x[k] <= ta[i]) ? la[i] : ra[i]
        s += va[i]
    }
    return s
}

; Turns the trees' answer into a 0..1 chance, including what it learned while playing.
AIProb(c) {
    z := Brain.A * c.raw + Brain.B
    loop 10
        z += Brain.W[A_Index] * c.sc[A_Index]
    z := Max(-30, Min(30, z))
    return 1 / (1 + Exp(-z))
}

LoadModel() {
    global MA, MB
    MA := LoadTrees(ModelAText(), ModelARoots(), ModelABase())
    MB := LoadTrees(ModelBText(), ModelBRoots(), ModelBBase())
}

; Both models' answers averaged (as log-odds, so the learning below works on it).
; Things the first model is already sure are not skeletons skip the second.
AIScore(x) {
    pa := 1 / (1 + Exp(-Clamp(AIRaw(MA, x), -30, 30)))
    p := (pa < 0.2) ? pa / 2 : (pa + 1 / (1 + Exp(-Clamp(AIRaw(MB, x), -30, 30)))) / 2
    p := Clamp(p, 0.000001, 0.999999)
    return Ln(p / (1 - p))
}

LoadTrees(text, rootsText, bias0) {
    m := {F: [], T: [], L: [], R: [], V: [], roots: [], bias: bias0}
    for tk in StrSplit(text, " ") {
        if (tk = "")
            continue
        if (SubStr(tk, 1, 1) = "~") {
            m.F.Push(0), m.T.Push(0.0), m.L.Push(0), m.R.Push(0), m.V.Push(Number(SubStr(tk, 2)))
        } else {
            q := StrSplit(tk, ":")
            m.F.Push(Integer(q[1])), m.T.Push(Number(q[2])), m.L.Push(Integer(q[3])), m.R.Push(Integer(q[4])), m.V.Push(0.0)
        }
    }
    for r in StrSplit(rootsText, " ")
        m.roots.Push(Integer(r))
    return m
}

; ---- learning while playing ----
; A damage number or "+1 Bone" where the arrow went = it WAS a skeleton.
; Something that never moves and was given up on twice without a single hit
; = it was NOT one. Small, bounded steps: it can tune the AI, never ruin it.
; Saved in skeleton_bow_learned_v12.txt; F6 makes it forget. Every lesson is
; also written to skeleton_bow_examples_v12.txt (send it over to improve the AI).
LearnFrom(t, y) {
    if (!Cfg.UseAI || !t.HasOwnProp("sc"))
        return
    SaveExample(t, y)
    if !Cfg.LearnWhilePlaying
        return
    g := AIProb(t) - y
    if !y
        g := g * Min(1.0, (Brain.kills + 5) / (Brain.wrong + 5))
    rc := Max(-6, Min(6, t.raw))
    Brain.A := Clamp(Brain.A - 0.01 * g * rc - 0.02 * (Brain.A - 1), 0.8, 1.3)
    Brain.B := Clamp(Brain.B - 0.10 * g - 0.02 * Brain.B, -0.7, 1.5)
    loop 10 {
        k := A_Index
        Brain.W[k] := Clamp(Brain.W[k] - 0.05 * g * t.sc[k] - 0.02 * Brain.W[k], -0.3, 0.3)
    }
    if y
        Brain.kills += 1
    else
        Brain.wrong += 1
    SaveBrain()
}

SaveExample(t, y) {
    if !t.HasOwnProp("feat")
        return
    try {
        if (FileExist(ExamplesFile) && FileGetSize(ExamplesFile) > 8000000)
            return
        s := y
        for v in t.feat
            s .= " " Round(v, 4)
        FileAppend(s "`n", ExamplesFile)
    }
}

Clamp(v, lo, hi) => Max(lo, Min(hi, v))

NewBrain() {
    return {A: 1.0, B: 0.0, W: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], kills: 0, wrong: 0}
}

SaveBrain() {
    s := Format("{:.6f} {:.6f}", Brain.A, Brain.B)
    for v in Brain.W
        s .= Format(" {:.6f}", v)
    s .= " " Brain.kills " " Brain.wrong
    try {
        f := FileOpen(BrainFile, "w")
        f.Write(s)
        f.Close()
    }
}

LoadBrain() {
    global Brain
    Brain := NewBrain()
    if !FileExist(BrainFile)
        return
    try {
        v := StrSplit(Trim(FileRead(BrainFile), "`r`n "), " ")
        if (v.Length < 14)
            return
        Brain.A := Number(v[1]), Brain.B := Number(v[2])
        loop 10
            Brain.W[A_Index] := Number(v[A_Index + 2])
        Brain.kills := Integer(v[13]), Brain.wrong := Integer(v[14])
    } catch {
        Brain := NewBrain()
    }
}

ForgetLearning() {
    global Brain
    Brain := NewBrain()
    try FileDelete(BrainFile)
    SetStatus("AI forgot what it learned while playing - back to the trained model.")
}

; ---- your character's spot, no-shoot zones, learned arrow flight times ----
MouseInGame(&gx, &gy) {
    h := FindRoblox()
    if !h {
        SetStatus("Roblox window not found.")
        return false
    }
    State.hwnd := h
    WinGetClientPos(&wx, &wy, &ww, &wh, "ahk_id " h)
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    CoordMode "Mouse", "Client"
    gx := Round((mx - wx) * 1920 / ww), gy := Round((my - wy) * 1080 / wh)
    return true
}

SetPlayerSpot() {
    if !MouseInGame(&gx, &gy)
        return
    Cfg.PlayerX := gx, Cfg.PlayerY := gy
    State.fsNear := 1.0, State.fsFar := 1.0       ; a new spot: learn the flight times again
    SaveSettings()
    SetStatus("Your character is at " gx ", " gy " (saved). F1 start   F5 show what I see")
}

; F9: mouse on the boss / anything it must never shoot, press F9 = no-shoot
; circle there. F9 again inside a circle removes it.
ToggleNoShoot() {
    if !MouseInGame(&gx, &gy)
        return
    i := State.zones.Length
    while (i >= 1) {
        if (Dist(gx, gy, State.zones[i].x, State.zones[i].y) <= State.zones[i].r) {
            State.zones.RemoveAt(i)
            SaveSettings()
            SetStatus("No-shoot circle removed (" State.zones.Length " left).")
            return
        }
        i -= 1
    }
    State.zones.Push({x: gx, y: gy, r: Cfg.NoShootRadius})
    SaveSettings()
    SetStatus("No-shoot circle added at " gx ", " gy " (" State.zones.Length " in total, saved). F9 inside it removes it.")
}

SaveSettings() {
    s := Cfg.PlayerX " " Cfg.PlayerY " " Format("{:.4f} {:.4f}", State.fsNear, State.fsFar)
    for z in State.zones
        s .= " " z.x "," z.y "," z.r
    try {
        f := FileOpen(SettingsFile, "w")
        f.Write(s)
        f.Close()
    }
}

LoadSettings() {
    if !FileExist(SettingsFile)
        return
    try {
        v := StrSplit(Trim(FileRead(SettingsFile), "`r`n "), " ")
        if (v.Length >= 2)
            Cfg.PlayerX := Integer(v[1]), Cfg.PlayerY := Integer(v[2])
        if (v.Length >= 4)
            State.fsNear := Clamp(Number(v[3]), 0.7, 1.5), State.fsFar := Clamp(Number(v[4]), 0.7, 1.5)
        i := 5
        while (i <= v.Length) {
            q := StrSplit(v[i], ",")
            if (q.Length = 3)
                State.zones.Push({x: Integer(q[1]), y: Integer(q[2]), r: Integer(q[3])})
            i += 1
        }
    }
}

; Remembers the current picture so the next one can be compared with it.
SavePrev(cands) {
    DllCall("RtlMoveMemory", "ptr", State.prevBuf, "ptr", State.pBits, "uptr", LW * LH * 4)
    State.prevCands := cands
    State.prevTick := State.grabTick
}

PixDiff(a, b) {
    return Abs(((a >> 16) & 255) - ((b >> 16) & 255)) + Abs(((a >> 8) & 255) - ((b >> 8) & 255)) + Abs((a & 255) - (b & 255))
}

; Share of the whole picture that changed (camera turned, you walked...).
ViewChange() {
    p := State.pBits, q := State.prevBuf.Ptr
    total := 0, changed := 0
    y := 40
    while (y < 460) {
        x := 0
        while (x < LW) {
            off := (y * LW + x) * 4
            total += 1
            if (PixDiff(NumGet(p + off, "uint"), NumGet(q + off, "uint")) > 45)
                changed += 1
            x += 12
        }
        y += 12
    }
    return changed / total
}

; Finds the skeletons worth shooting. Result in State.heads.
; Something only counts if the AI also picked it on the look before (near
; the same spot) - arrows in flight, wind streaks and damage numbers are not.
Scan() {
    if !Grab()
        return false
    CheckShots(State.grabTick)
    cands := Detect()
    if (!State.HasOwnProp("prevTick") || A_TickCount - State.prevTick > 6000) {
        SavePrev(cands)             ; nothing recent to compare with: look twice
        Sleep 350
        if !Grab()
            return false
        CheckShots(State.grabTick)
        cands := Detect()
    }
    ; something counts if it was also there on the look before - or within
    ; walking distance of it, so walking skeletons count too
    rad := 40 + Min(140, 70 * (State.grabTick - State.prevTick) / 1000)
    State.viewMoved := (ViewChange() > 0.30)
    heads := []
    if !State.viewMoved {
        for c in cands {
            for o in State.prevCands {
                if (Abs(o.cx - c.cx) <= rad && Abs(o.cy - c.cy) <= rad) {
                    heads.Push(c)
                    break
                }
            }
        }
    }
    SavePrev(cands)
    State.heads := heads
    return true
}

; ------------------------------ STATUS BAR / F5 -----------------------
MakeStatusBar() {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")
    g.BackColor := "101418"
    g.MarginX := 0, g.MarginY := 0
    g.SetFont("s9 cFFD24A", "Consolas")
    State.txt := g.Add("Text", "x8 y4 w764 h18", "")
    g.Show("x320 y4 w780 h26 NoActivate")
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

; F5: red box = skeleton found by its bones, blue box = by its armour (number = how
;     sure the AI is, %), grey skip = missed 3 times there, left alone for a while.
ShowWhatISee() {
    if !State.hwnd
        State.hwnd := FindRoblox()
    if (!State.hwnd || !Grab()) {
        SetStatus("Roblox window not found.")
        return
    }
    if WinActive("ahk_id " State.hwnd) {
        ParkMouse()
        Sleep 70
    }
    Scan()
    PlaceStatusBar()
    if State.HasOwnProp("ov") && State.ov {
        State.ov.Destroy()
        State.ov := 0
    }
    ov := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")
    ov.BackColor := "010203"
    ov.MarginX := 0, ov.MarginY := 0
    ov.SetFont("s8 bold c000000", "Consolas")
    shown := 0
    for h in State.heads {
        d := Dist(h.x, h.y, Cfg.PlayerX, Cfg.PlayerY)
        ok := (d <= Cfg.MaxRangePx && d >= Cfg.MinRangePx && !IsBlack(h.x, h.y))
        ax := Round(h.x * State.cw / 1920), ay := Round(h.y * State.ch / 1080)
        ov.Add("Text", "x" (ax - 14) " y" (ay - 30) " w28 h14 Center Background" (ok ? "FF3030" : "888888"), ok ? Round(h.score * 100) : "skip")
        ov.Add("Text", "x" (ax - 3) " y" (ay - 3) " w6 h6 BackgroundFFE000")         ; the exact aim spot
        shown += ok ? 1 : 0
    }
    for z in State.zones
        ov.Add("Text", "x" (Round(z.x * State.cw / 1920) - 30) " y" (Round(z.y * State.ch / 1080) - 7) " w60 h14 Center Background888888", "NO SHOOT")
    if BossZone(State.bossX, State.bossY)
        ov.Add("Text", "x" (Round(State.bossX * State.cw / 1920) - 45) " y" (Round(State.bossY * State.ch / 1080) - 7) " w90 h14 Center Background30D0D0", "BOSS: NO SHOOT")
    ov.Add("Text", "x" (Round(Cfg.PlayerX * State.cw / 1920) - 7) " y" (Round(Cfg.PlayerY * State.ch / 1080) - 7) " w14 h14 Center Background40FF40", "U")
    ov.Show("x" State.cx " y" State.cy " w" State.cw " h" State.ch " NoActivate")
    WinSetTransColor("010203", ov)
    State.ov := ov
    State.overlayUntil := A_TickCount + 5200
    SetStatus("I see " shown " skeleton(s): red = how sure the AI is (%), yellow dot = where it aims"
        . (State.bossUp ? "  |  boss up: ignored" : "") "  |  light " GM "/" TintB "/" TintG
        . "  |  bow " (BowEquipped() ? "out" : "away") "  |  U = you (F7 to fix)")
    SetTimer(HideOverlay, -5000)
}

HideOverlay() {
    if State.HasOwnProp("ov") && State.ov {
        State.ov.Destroy()
        State.ov := 0
    }
}

; ------------------------------ THE TRAINED MODELS ----------------------
; Two sets of decision trees (300 + 300) trained on 88399 examples (skeleton / not) cut from
; your clips plus darker / brighter copies of them and copies worked out with a wrong light
; tint; the second one gives every clip equal say.
; Their two answers are averaged. Generated - do not edit by hand.
ModelABase() => 0.00003229794841411605
ModelARoots() {
    return "1 48 95 142 189 236 283 330 377 424 471 518 565 612 659 706 753 800 847 894 941 988 1035 1082 1129 1176 1223 1270 1317 1364 1411 1458 1505 1552 1599 1646 1693 1740 1787 1834 1881 1928 1975 2022 2069 2116 2163 2210 2257 2304 2351 2398 2445 2492 2539 2586 2633 2680 2727 2774 2821 2868 2915 2962 3009 3056 3103 3150 3197 3244 3291 3338 3385 3432 3479 3526 3573 3620 3667 3714 3761 3808 3855 3902 3949 3996 4043 4090 4137 4184 4231 4278 4325 4372 4419 4466 4513 4560 4607 4654 4701 4748 4795 4842 4889 4936 4983 5030 5077 5124 5171 5218 5265 5312 5359 5406 5453 5500 5547 5594 5641 5688 5735 5782 5829 5876 5923 5970 6017 6064 6111 6158 6205 6252 6299 6346 6393 6440 6487 6534 6581 6628 6675 6722 6769 6816 6863 6910 6957 7004 7051 7098 7145 7192 7239 7286 7333 7380 7427 7474 7521 7568 7615 7662 7709 7756 7803 7850 7897 7944 7991 8038 8085 8132 8179 8226 8273 8320 8367 8414 8461 8508 8555 8602 8649 8696 8743 8790 8837 8884 8931 8978 9025 9072 9119 9166 9213 9260 9307 9354 9401 9448 9495 9542 9589 9636 9683 9730 9777 9824 9871 9918 9965 10012 10059 10106 10153 10200 10247 10294 10341 10388 10435 10482 10529 10576 10623 10670 10717 10764 10811 10858 10905 10952 10999 11046 11093 11140 11187 11234 11281 11328 11375 11422 11469 11516 11563 11610 11657 11704 11751 11798 11845 11892 11939 11986 12033 12080 12127 12174 12221 12268 12315 12362 12409 12456 12503 12550 12597 12644 12691 12738 12785 12832 12879 12926 12973 13020 13067 13114 13161 13208 13255 13302 13349 13396 13443 13490 13537 13584 13631 13678 13725 13772 13819 13866 13913 13960 14007 14054"
}

ModelAText() {
    s := ""
    s .= "244:0.91:2:13 220:1.171875:3:10 244:0.85:4:5 ~-0.09795081195462049 57:0.2578125:6:7 ~-0.08612031218269196 8:-0.484375:8:9 ~0.06484652230624348 ~-0.06543051176540186 251:0.796875:11:12 ~-0.09569770101779218 ~0.09692889277449235 "
    s .= "248:0.625:14:37 211:-0.234375:15:20 196:-0.140625:16:17 ~-0.08874856904036107 253:-0.0218253968253966:18:19 ~0.07027508856450318 ~-0.03822862464397846 243:0.45:21:26 244:1.315:22:23 ~-0.05275484292947178 131:0.0625:24:25 "
    s .= "~0.07851961574480104 ~-0.0704851664910971 243:2.25:27:34 253:-0.005208333333335702:28:29 ~0.09628680499624814 26:0.015625:30:31 ~0.0789028090099053 251:0.921875:32:33 ~-0.05135821652239303 ~0.06176158142799174 253:-0.0625:35:36 "
    s .= "~0.07780827671973872 ~-0.09323488792338433 252:0.125:38:41 219:0.3828125:39:40 ~-0.09223993442799441 ~-0.004090818499839174 238:-0.09375:42:43 ~-0.08218905545513577 253:0.007483380816713255:44:47 167:0.28125:45:46 "
    s .= "~0.07741203727640365 ~-0.061283864927471614 ~-0.05363249211424609 244:0.91:49:56 220:1.171875:50:55 127:0.9375:51:52 ~-0.09141902899138753 130:0.25:53:54 ~0.08573639369846658 ~-0.09261304574216152 ~0.05040630750776223 "
    s .= "248:0.625:57:82 211:-0.203125:58:63 196:-0.140625:59:60 ~-0.08039962353951838 253:-0.0218253968253966:61:62 ~0.06847319024030712 ~-0.02540492274927666 243:0.35:64:69 111:0.0234375:65:68 244:1.3:66:67 ~-0.04258058423929712 "
    s .= "~0.0671025703672784 ~-0.07341343408698428 243:2.25:70:79 253:-0.005208333333335702:71:72 ~0.09111744543103 244:1.085:73:76 26:-0.25:74:75 ~0.05197526348449216 ~-0.06343833796532537 28:0.5:77:78 ~0.0796521613720611 "
    s .= "~-0.01936193697654789 253:-0.0625:80:81 ~0.07415591849957834 ~-0.08865977966172488 252:0.125:83:88 219:0.3828125:84:85 ~-0.08781964008602443 52:-0.015625:86:87 ~0.04959514493246049 ~-0.07675628514459983 238:-0.09375:89:90 "
    s .= "~-0.07823271461478777 85:0.6875:91:94 253:-0.02550884990132192:92:93 ~0.04685606837100964 ~-0.07997060556754973 ~0.06898060682647948 244:0.91:96:107 220:1.171875:97:106 244:0.85:98:99 ~-0.08936380829348645 133:0.0625:100:103 "
    s .= "90:0.1953125:101:102 ~-0.07877372110319618 ~0.07347576035686118 226:0.9375:104:105 ~-0.08038517248223838 ~0.04397747604119627 ~0.04800750323014298 248:0.625:108:131 211:-0.234375:109:114 253:-0.0218253968253966:110:113 "
    s .= "193:-0.140625:111:112 ~-0.06385578098156688 ~0.06714138070273445 ~-0.07382866601778619 243:0.45:115:120 244:1.315:116:117 ~-0.049129882797898275 131:0.0625:118:119 ~0.07158648327385402 ~-0.06646700501622708 243:2.25:121:130 "
    s .= "253:-0.005208333333335702:122:123 ~0.08772941709741797 251:0.984375:124:129 85:1.140625:125:128 157:0.8125:126:127 ~-0.05880931844957195 ~0.027183109996829574 ~0.07741544895669455 ~0.08161123314278976 ~-0.048165772761939264 "
    s .= "252:0.125:132:135 219:0.3828125:133:134 ~-0.08394147999929667 ~-0.003706452034117017 238:-0.09375:136:137 ~-0.07469931835300132 253:0.007483380816713255:138:141 239:0.265625:139:140 ~0.07048124379015364 ~-0.06641707996499081 "
    s .= "~-0.04947144237393273 244:0.91:143:154 220:1.171875:144:151 244:0.85:145:146 ~-0.08580153652761197 57:0.2578125:147:148 ~-0.07487957544870578 76:0.0625:149:150 ~0.05006000213634431 ~-0.07037119439680246 251:0.796875:152:153 "
    s .= "~-0.09582784135992702 ~0.08814368864917016 248:0.625:155:176 211:-0.203125:156:161 196:-0.140625:157:158 ~-0.0744044187742808 253:-0.0218253968253966:159:160 ~0.06255764199940511 ~-0.021351697282711926 243:0.45:162:167 "
    s .= "244:1.3:163:164 ~-0.04690378394187556 131:0.0625:165:166 ~0.06873301969289387 ~-0.06284689350444704 243:2.25:168:175 253:-0.005208333333335702:169:170 ~0.08434312461285762 85:0.796875:171:174 251:1.046875:172:173 "
    s .= "~-0.02677054560959909 ~0.06962348588928638 ~0.07908890126656053 ~-0.045138091708491444 252:0.125:177:182 219:0.3828125:178:179 ~-0.08050768766929808 2:-0.03125:180:181 ~0.04187116490924915 ~-0.08574853180524977 "
    s .= "226:-0.09375:183:184 ~-0.08101213182165362 85:0.53125:185:186 ~-0.0408428741849198 26:0.140625:187:188 ~0.07179339314080585 ~-0.051667675483213577 244:0.91:190:203 220:1.171875:191:200 127:0.9375:192:197 226:0.90625:193:194 "
    s .= "~-0.08207151459163026 11:-0.390625:195:196 ~0.08157373538195645 ~-0.07816135609563796 96:0.3046875:198:199 ~-0.08128134647915722 ~0.08621804107954065 251:0.796875:201:202 ~-0.09143495367315485 ~0.08468854996368161 "
    s .= "248:0.625:204:225 205:-0.25:205:208 232:-0.1875:206:207 ~-0.070999207908496 ~0.009995687469294108 253:-0.006060606060605716:209:212 249:1.8333333333333335:210:211 ~0.07948554315698395 ~-0.060644189612305145 26:-0.109375:213:220 "
    s .= "157:0.8125:214:219 251:0.734375:215:218 109:0.953125:216:217 ~-0.05858835571973693 ~0.03776964127167868 ~0.06464133075012424 ~0.07541997589167833 251:1.046875:221:224 115:0.828125:222:223 ~-0.06608092533669972 "
    s .= "~0.012691722169247924 ~0.050847007386449206 252:0.125:226:229 219:0.4296875:227:228 ~-0.0769282929836987 ~0.004676741181733418 226:-0.09375:230:231 ~-0.07765462521893482 248:0.875:232:233 ~0.06460126006909067 85:0.53125:234:235 "
    s .= "~-0.08648440812936829 ~0.018847901443437596 244:0.91:237:250 220:1.171875:238:247 244:0.85:239:240 ~-0.07994784754644939 133:0.0625:241:244 90:0.1953125:242:243 ~-0.06981116447104024 ~0.06968087534989094 226:0.9375:245:246 "
    s .= "~-0.07134254924951046 ~0.039916687729441125 251:0.796875:248:249 ~-0.08760195662719839 ~0.08163136686706725 248:0.625:251:274 211:-0.234375:252:257 196:-0.140625:253:254 ~-0.07351201885689494 253:-0.07183673469387689:255:256 "
    s .= "~0.06537211623327596 ~-0.017949289713990887 243:0.35:258:263 111:0.0234375:259:262 244:1.3:260:261 ~-0.03609727645316276 ~0.0557341503311341 ~-0.06684254836803409 243:2.25:264:271 253:-0.005208333333335702:265:266 "
    s .= "~0.07771842875541045 26:0.015625:267:268 ~0.06256410849963424 244:1.13:269:270 ~-0.07592750265285834 ~0.030463747981224504 253:-0.0625:272:273 ~0.07146707763084302 ~-0.08047258762878223 60:0.1484375:275:278 "
    s .= "252:0.42500000000000004:276:277 ~-0.07332037849872962 ~-0.00044749925079065915 252:0.07500000000000001:279:280 ~-0.05497859096619922 194:0.21875:281:282 ~0.06867108780095396 ~-0.07420926150354146 244:0.91:284:295 "
    s .= "220:1.171875:285:292 244:0.855:286:287 ~-0.07720575820532731 57:0.2578125:288:289 ~-0.06555243136332438 100:0.1875:290:291 ~0.0408694403629361 ~-0.07723968637974152 251:0.796875:293:294 ~-0.08422958456394262 ~0.07890751261868365 "
    s .= "248:0.625:296:319 205:-0.25:297:302 232:-0.1875:298:299 ~-0.06664774960661665 253:-0.015714285714285837:300:301 ~0.06450818489014949 ~-0.03577072630145975 253:-0.008590102707748947:303:306 249:1.8333333333333335:304:305 "
    s .= "~0.07447080225403954 ~-0.05473951514409427 26:-0.109375:307:314 157:0.8125:308:313 251:0.734375:309:312 109:0.953125:310:311 ~-0.057407931645146376 ~0.0366331837248834 ~0.06003643588592919 ~0.0706239380724648 251:0.921875:315:318 "
    s .= "139:1.296875:316:317 ~-0.06100419053889029 ~0.038328251258434566 ~0.04127887151521195 60:0.1484375:320:325 252:0.42500000000000004:321:322 ~-0.0707561619583915 241:1.02:323:324 ~0.03929871339620004 ~-0.07262965263561982 "
    s .= "252:0.07500000000000001:326:327 ~-0.05280043064309571 194:0.21875:328:329 ~0.0657726939753154 ~-0.07124058054059972 244:0.91:331:340 220:1.171875:332:339 127:0.9375:333:336 226:0.90625:334:335 ~-0.07462473904425841 "
    s .= "~-0.0018466633677767447 130:0.25:337:338 ~0.08304707621442625 ~-0.07503248590871742 ~0.03935550356883626 248:0.625:341:364 211:-0.203125:342:347 196:-0.140625:343:344 ~-0.06623097133293067 146:-0.109375:345:346 "
    s .= "~0.05367200712155151 ~-0.023392919511490983 243:0.45:348:353 244:1.315:349:350 ~-0.042818557626394645 111:0.0234375:351:352 ~0.06265611931916598 ~-0.03908672793028542 243:2.1500000000000004:354:363 256:0.907608695652174:355:362 "
    s .= "253:-0.006060606060605716:356:357 ~0.07430619581519336 85:0.796875:358:361 251:1.171875:359:360 ~-0.022353987792614986 ~0.0638761723159312 ~0.07036509926424638 ~-0.06855725368560371 ~-0.03710912160753309 252:0.125:365:370 "
    s .= "219:0.3828125:366:367 ~-0.07019694890925286 52:-0.015625:368:369 ~0.04870866995486581 ~-0.06597609874249333 196:-0.09375:371:372 ~-0.07129167016533093 85:0.703125:373:376 253:-0.02550884990132192:374:375 ~0.0456255922456877 "
    s .= "~-0.07099544661023464 ~0.062367585980162614 244:0.91:378:387 244:0.855:379:380 ~-0.0730446983191023 220:0.9375:381:386 133:0.0625:382:385 90:0.1953125:383:384 ~-0.06173438758798873 ~0.06959432328986766 ~-0.06258044579112108 "
    s .= "~0.06314662862754664 248:0.625:388:415 211:-0.203125:389:394 196:-0.140625:390:391 ~-0.06391379625234146 146:-0.109375:392:393 ~0.05146617320092015 ~-0.02221419582753151 243:0.45:395:402 244:1.315:396:399 62:-0.359375:397:398 "
    s .= "~0.008413422137920795 ~-0.06320792159638991 131:0.0625:400:401 ~0.05811694150450512 ~-0.05878057185879888 243:2.25:403:412 191:0.625:404:411 256:0.9583333333333334:405:410 249:1.8333333333333335:406:409 28:0.8125:407:408 "
    s .= "~0.069630597130495 ~-0.01321596431108528 ~-0.05282192568028679 ~-0.10698956344189647 ~-0.03437490443121322 253:-0.0625:413:414 ~0.06690202794783766 ~-0.07543751938719415 60:0.1484375:416:419 252:0.42500000000000004:417:418 "
    s .= "~-0.06646692703092705 ~-0.0009474006603734551 252:0.07500000000000001:420:421 ~-0.04851850458162986 53:0.15625:422:423 ~0.06071543543261411 ~-0.07861526083416435 244:0.91:425:434 244:0.855:426:427 ~-0.0711755613717038 "
    s .= "220:0.9375:428:433 133:0.0625:429:432 90:0.1953125:430:431 ~-0.05980987729769326 ~0.06666590396632963 ~-0.0606274312207799 ~0.06078111911688501 248:0.625:435:460 205:-0.25:436:439 232:-0.1875:437:438 ~-0.06178133966328034 "
    s .= "~0.006383394280871157 253:-0.008590102707748947:440:443 214:1.96875:441:442 ~0.06836297406674983 ~-0.07017589179833064 29:-0.125:444:455 251:0.171875:445:446 ~-0.06415290348548562 243:1.45:447:454 187:-0.3125:448:449 "
    s .= "~-0.07567888969697305 157:0.8125:450:453 251:0.734375:451:452 ~-0.01469778499148326 ~0.0613884287824245 ~0.07017229191401718 ~-0.03723571793726043 251:1.046875:456:459 139:1.1875:457:458 ~-0.051211179845316174 "
    s .= "~0.031018640919091196 ~0.0396143049114271 45:0.2265625:461:466 249:0.16666666666666666:462:465 241:0.36:463:464 ~-0.06237386059112374 ~0.04059351599060362 ~-0.06384675580609821 252:0.07500000000000001:467:468 "
    s .= "~-0.04629992123948262 98:0.25:469:470 ~0.06196873927818938 ~-0.07536082614482073 244:0.91:472:481 244:0.855:473:474 ~-0.06946839488620131 249:0.5:475:480 46:0.234375:476:479 191:0.03125:477:478 ~0.0520574766008501 "
    s .= "~-0.06428937369955702 ~-0.06949629188437233 ~-0.06992307275843206 248:0.625:482:505 253:-0.006060606060605716:483:488 249:1.8333333333333335:484:487 232:-0.28125:485:486 ~0.011849629219743876 ~0.06689257743053442 "
    s .= "~-0.05919987245245935 211:-0.109375:489:492 251:1.203125:490:491 ~-0.060174568948485246 ~0.020038784963843908 53:0.046875:493:502 85:0.796875:494:501 154:0.859375:495:500 251:0.671875:496:499 112:0.9375:497:498 "
    s .= "~-0.04769303798626615 ~0.04579742518462188 ~0.03966514167062316 ~0.060900803503180126 ~0.06606235418730039 251:1.421875:503:504 ~-0.045597247439789164 ~0.040832096020344606 60:0.1484375:506:513 249:1.8333333333333335:507:512 "
    s .= "243:0.55:508:509 ~-0.058909793270870515 248:0.875:510:511 ~0.03530937298190123 ~-0.03917232170412587 ~-0.07333563238003722 252:0.07500000000000001:514:515 ~-0.04477716933874934 194:0.21875:516:517 ~0.058332206345420745 "
    s .= "~-0.06533541466749848 244:0.91:519:528 244:0.855:520:521 ~-0.06790249373777392 249:0.5:522:527 46:0.234375:523:526 191:0.09375:524:525 ~0.047902649518804886 ~-0.07177414018750923 ~-0.06771018149431621 ~-0.06810454284450229 "
    s .= "248:0.625:529:552 253:-0.008590102707748947:530:537 249:1.8333333333333335:531:536 243:0.45:532:535 244:1.355:533:534 ~-0.06261931717462241 ~0.05471801890212528 ~0.06552186153714666 ~-0.05568462207920009 211:-0.109375:538:541 "
    s .= "217:-0.125:539:540 ~-0.06974325778748079 ~-0.012093292423591195 26:0.109375:542:549 157:0.8125:543:548 251:0.828125:544:547 245:2.258426966292135:545:546 ~-0.05257171573148239 ~0.024461507252024048 ~0.051334351960130545 "
    s .= "~0.061576825683559114 251:1.328125:550:551 ~-0.04954807807989389 ~0.03813169751713373 57:0.1484375:553:560 244:2.045:554:557 220:0.71875:555:556 ~-0.0631761252623297 ~0.009610419141057881 232:0:558:559 ~-0.06460051136954992 "
    s .= "~0.06898664275008617 252:0.07500000000000001:561:562 ~-0.04623426279512188 194:0.21875:563:564 ~0.05934794252545842 ~-0.06264478354374578 244:0.91:566:573 244:0.855:567:568 ~-0.06646039012617383 220:0.9375:569:572 "
    s .= "133:0.0625:570:571 ~0.022493068163692714 ~-0.05609120496131455 ~0.056526999442016536 248:0.625:574:599 220:-0.140625:575:582 251:0.859375:576:579 38:-0.640625:577:578 ~0.014482123088663576 ~-0.06809756823649185 248:0.375:580:581 "
    s .= "~0.051942500302705454 ~-0.04893648296846366 243:0.45:583:588 130:0.90625:584:585 ~-0.03334892663154647 107:0.0625:586:587 ~0.05723786851432239 ~-0.0694757151509728 243:1.85:589:596 249:1.8333333333333335:590:595 "
    s .= "256:0.9583333333333334:591:594 71:1.078125:592:593 ~0.0631003947225428 ~-0.09364602090647656 ~-0.11391335258392635 ~-0.05043675520111599 253:-0.05829228243021589:597:598 ~0.06246830816988727 ~-0.0533523887736188 252:0.125:600:605 "
    s .= "219:0.2890625:601:602 ~-0.06253729991805078 52:-0.015625:603:604 ~0.04715756458672683 ~-0.056330938715090095 196:-0.078125:606:607 ~-0.06374897090608624 85:0.703125:608:611 253:-0.02550884990132192:609:610 ~0.04015127095752341 "
    s .= "~-0.06384013067717796 ~0.056760412016663424 244:0.91:613:624 244:0.85:614:615 ~-0.06544664650966628 249:0.5:616:623 46:0.234375:617:622 236:0.09375:618:621 251:0.296875:619:620 ~-0.06416416983794973 ~0.059990727462797114 "
    s .= "~-0.07050079702406065 ~-0.06563936769701342 ~-0.06578297059450955 248:0.625:625:648 253:-0.008590102707748947:626:633 249:1.8333333333333335:627:632 243:0.45:628:631 244:1.355:629:630 ~-0.05837422084901746 ~0.05171031085696764 "
    s .= "~0.06268248267031055 ~-0.05190789922973421 211:-0.09375:634:637 251:1.203125:635:636 ~-0.0534175230142788 ~0.019267506922647337 53:0.046875:638:645 157:0.8125:639:644 251:0.828125:640:643 245:1.9743589743589745:641:642 "
    s .= "~-0.06411460417453793 ~0.011105721670113143 ~0.051614341362464955 ~0.059346590122510416 251:1.234375:646:647 ~-0.04335152257231789 ~0.03209602122429332 45:0.2265625:649:656 249:1.8333333333333335:650:655 243:0.55:651:652 "
    s .= "~-0.052384604121999724 73:0.140625:653:654 ~0.02199006672274075 ~-0.050732216294829616 ~-0.06899339026543033 248:0.875:657:658 ~0.051077712762083186 ~-0.0338820463001725 244:0.91:660:671 244:0.85:661:662 ~-0.06422034373715868 "
    s .= "249:0.5:663:670 46:0.234375:664:669 191:0.03125:665:668 211:-0.078125:666:667 ~-0.06598069598076016 ~0.05780544427567517 ~-0.060174321100942445 ~-0.06419327822411254 ~-0.06431846798245147 248:0.625:672:695 "
    s .= "253:-0.008590102707748947:673:680 232:-0.3125:674:675 ~-0.007284736232310166 214:1.96875:676:679 256:0.9583333333333334:677:678 ~0.061479596435271136 ~-0.12266298574104034 ~-0.06363907683904571 211:-0.09375:681:684 "
    s .= "217:-0.125:682:683 ~-0.06455051646069805 ~-0.009830458862506946 26:0.203125:685:692 157:0.8125:686:691 251:0.796875:687:690 245:2.258426966292135:688:689 ~-0.04717830133034981 ~0.02160150152833945 ~0.04543514431675413 "
    s .= "~0.05656057119717775 251:1.328125:693:694 ~-0.06407631392742494 ~0.03339691430153042 60:0.1484375:696:701 249:1.8333333333333335:697:700 243:0.55:698:699 ~-0.05282745447489509 ~0.0006164357669230028 ~-0.06788777669441613 "
    s .= "248:0.875:702:705 53:0.15625:703:704 ~0.055659482064119484 ~-0.0604478418564585 ~-0.034200230380987094 244:0.91:707:718 244:0.85:708:709 ~-0.06308032165020351 249:0.5:710:717 46:0.234375:711:716 236:0.09375:712:715 "
    s .= "251:0.296875:713:714 ~-0.06262718844391406 ~0.0557175506311695 ~-0.06812871199722358 ~-0.06284514667205009 ~-0.06295239877220314 248:0.625:719:742 253:-0.008590102707748947:720:727 232:-0.3125:721:722 ~-0.006915926483252665 "
    s .= "214:1.96875:723:726 256:0.9583333333333334:724:725 ~0.06020446364883175 ~-0.11419854529107265 ~-0.06150225648572243 211:-0.09375:728:731 220:-0.125:729:730 ~-0.05961230655612574 ~-0.0047821818473805 2:-0.203125:732:737 "
    s .= "157:0.8125:733:736 251:0.828125:734:735 ~-0.012949218323793595 ~0.05007127954434131 ~0.06025586235565348 251:0.921875:738:741 112:0.921875:739:740 ~-0.05269286595530079 ~0.012360154552638598 ~0.034632318190260324 "
    s .= "252:0.125:743:748 219:0.2890625:744:745 ~-0.05858015483912922 52:-0.015625:746:747 ~0.04569939408832949 ~-0.052489357947244776 196:-0.078125:749:750 ~-0.060500419480970215 109:0.65625:751:752 ~-0.044537042405711345 "
    s .= "~0.04717545993069758 244:0.9:754:765 232:0.703125:755:760 220:0.9375:756:757 ~-0.062409757366928525 217:0.34375:758:759 ~0.06533564402789054 ~-0.06569627515406883 235:0.28125:761:764 53:-0.515625:762:763 ~0.09645949678383901 "
    s .= "~-0.06439836252308086 ~-0.06153985161656555 248:0.625:766:787 253:-0.014619883040936088:767:774 249:1.8333333333333335:768:773 243:0.45:769:772 244:1.355:770:771 ~-0.06571591544816444 ~0.047450109977575615 ~0.05957904775474409 "
    s .= "~-0.04937430028688486 211:-0.234375:775:776 ~-0.051645605779212594 26:0.09375:777:784 157:0.8125:778:783 251:1.046875:779:782 109:0.953125:780:781 ~-0.03594303868845688 ~0.02867266868366755 ~0.049201434367095925 "
    s .= "~0.05303003959580426 244:1.13:785:786 ~-0.06927941310567542 ~-0.0014955716068929818 60:0.1484375:788:795 249:1.8333333333333335:789:794 244:2.01:790:793 253:-0.0607697824527861:791:792 ~0.019530941046814323 ~-0.05032356101838417 "
    s .= "~0.04228920857500241 ~-0.06578459553270231 248:0.875:796:799 53:0.15625:797:798 ~0.053010094081187356 ~-0.05806396292491152 ~-0.0331799581668462 244:0.9:801:812 232:0.703125:802:807 220:0.9375:803:804 ~-0.06138684106347985 "
    s .= "217:0.34375:805:806 ~0.06366958738257793 ~-0.06460430532421582 235:0.28125:808:811 53:-0.515625:809:810 ~0.0929397840930869 ~-0.06329926935646986 ~-0.06044142498154786 248:0.375:813:830 205:-0.25:814:817 232:-0.1875:815:816 "
    s .= "~-0.051843683407034324 ~0.019299042222735593 243:2.1500000000000004:818:829 256:0.907608695652174:819:828 241:0.22:820:825 146:0.015625:821:824 242:0.55:822:823 ~0.044744225806621206 ~-0.0833392357209787 ~-0.049206194458176984 "
    s .= "28:0.8125:826:827 ~0.05846557536142486 ~-0.03396179479029678 ~-0.07465763777377708 ~-0.04152939822027061 252:0.125:831:838 120:0.2421875:832:835 220:0.984375:833:834 ~-0.05761793220804501 ~0.010700035691127189 "
    s .= "119:-0.234375:836:837 ~0.02799329920956291 ~-0.054289352076435815 220:-0.140625:839:840 ~-0.06347402599934347 109:0.65625:841:844 251:1.234375:842:843 ~-0.059519899735059216 ~0.02435189513813925 167:0.28125:845:846 "
    s .= "~0.056107217687450174 ~-0.034972601901762025 244:0.9:848:859 232:0.703125:849:854 220:0.9375:850:851 ~-0.06042676152659411 217:0.34375:852:853 ~0.0621061839340622 ~-0.06359029207707227 235:0.28125:855:858 53:-0.515625:856:857 "
    s .= "~0.08972340139123659 ~-0.06227315419657179 ~-0.05940561985398729 248:0.375:860:877 251:0.296875:861:866 226:0:862:863 ~-0.05362136700517017 245:2.0843373493975905:864:865 ~-0.030903185809452272 ~0.045453291835317905 "
    s .= "205:-0.25:867:868 ~-0.015624417324489288 122:0.71875:869:876 256:0.907608695652174:870:875 28:0.921875:871:874 243:2.55:872:873 ~0.056367085176250144 ~-0.04567563040858258 ~-0.03548282346676815 ~-0.07068825775801375 "
    s .= "~-0.07727749075671436 252:0.125:878:885 219:0.2890625:879:882 67:1.140625:880:881 ~-0.05565284628881561 ~0.01773752336995329 28:0.015625:883:884 ~0.03736859414254472 ~-0.054336659313405346 226:-0.140625:886:887 "
    s .= "~-0.06334423518747621 166:0.40625:888:893 167:0.28125:889:892 248:1.125:890:891 ~0.05570310302785295 ~-0.03348969822401922 ~-0.04567703415626226 ~-0.04211473894009634 244:0.9:895:904 232:0.703125:896:899 220:0.9375:897:898 "
    s .= "~-0.05952284104442264 ~0.0063119630907325225 235:0.28125:900:903 53:-0.515625:901:902 ~0.0867679977713745 ~-0.061312406100702245 ~-0.058425538627294764 248:0.625:905:926 253:-0.014619883040936088:906:911 235:-0.3125:907:910 "
    s .= "232:-0.0625:908:909 ~-0.04912366974858069 ~0.0534832572839548 ~0.05574317790370336 2:-0.15625:912:921 214:-0.234375:913:914 ~-0.04773009669812302 109:0.109375:915:916 ~-0.027094859477132607 157:0.8125:917:920 251:0.734375:918:919 "
    s .= "~-0.017299419881880034 ~0.04753683680035873 ~0.05648494926625883 251:1.046875:922:925 115:0.78125:923:924 ~-0.051608438945846026 ~0.0029553239170584194 ~0.029302695977856227 57:0.1484375:927:936 232:0:928:929 ~-0.0614404965321428 "
    s .= "244:1.985:930:935 251:0.859375:931:932 ~-0.04927675082830358 8:-0.65625:933:934 ~0.08870295802628257 ~-0.023379748967433795 ~0.06633850403779244 252:0.07500000000000001:937:938 ~-0.03832376443610027 194:0.21875:939:940 "
    s .= "~0.0515321769281653 ~-0.05696463914580879 244:0.9:942:955 232:0.703125:943:950 220:0.9375:944:947 251:1.515625:945:946 ~-0.05974471129936885 ~0.026943331281428715 217:0.34375:948:949 ~0.060485494126906375 ~-0.06273765601985871 "
    s .= "11:-0.546875:951:954 166:0.1875:952:953 ~0.08580473536568856 ~-0.06017896447427462 ~-0.06082511298566406 248:0.375:956:971 251:0.296875:957:962 58:0.203125:958:961 218:0.046875:959:960 ~0.036999597225222836 ~-0.0578060768389734 "
    s .= "~-0.058489227231665365 205:-0.25:963:964 ~-0.015112960960170492 122:0.75:965:970 256:0.907608695652174:966:969 28:0.921875:967:968 ~0.053746389841302034 ~-0.034142986712690136 ~-0.06910775543356942 ~-0.07829246318577956 "
    s .= "252:0.125:972:979 120:0.2421875:973:976 220:0.984375:974:975 ~-0.05441145847589873 ~0.01254852009751751 11:-0.59375:977:978 ~0.048278724910067544 ~-0.029619278624210994 220:-0.140625:980:981 ~-0.06057863033501856 "
    s .= "109:0.65625:982:985 251:1.234375:983:984 ~-0.05753007196196435 ~0.02096818975182699 248:1.125:986:987 ~0.05281206979979911 ~-0.039185225065270765 244:0.9:989:1002 232:0.703125:990:997 244:0.855:991:992 ~-0.0599450436250252 "
    s .= "251:0.828125:993:996 220:0.9375:994:995 ~-0.05499907264278308 ~0.055759027068562485 ~0.03789682373197767 11:-0.546875:998:1001 166:0.1875:999:1000 ~0.08308767369511022 ~-0.05938633202834698 ~-0.06000375878802849 "
    s .= "248:0.375:1003:1018 253:-0.014619883040936088:1004:1005 ~0.05482512132299175 243:1.25:1006:1015 244:1.085:1007:1012 112:1.34375:1008:1011 190:0.21875:1009:1010 ~-0.0005221856530029188 ~-0.07823890681088481 ~0.054138054650466394 "
    s .= "243:0.25:1013:1014 ~-0.0293894921138155 ~0.04763536926333638 251:1.421875:1016:1017 ~-0.06895938449631354 ~0.033806781628925996 252:0.125:1019:1028 251:0.765625:1020:1021 ~-0.05376908977330334 14:-0.640625:1022:1023 "
    s .= "~0.049539188375081575 235:-0.125:1024:1025 ~-0.06378726231238707 250:0.6484375:1026:1027 ~0.07372815745089344 ~-0.025372988479102156 196:-0.09375:1029:1030 ~-0.0476213254701308 88:0.796875:1031:1034 "
    s .= "253:-0.02550884990132192:1032:1033 ~0.03665128764137113 ~-0.03968942643472029 ~0.05713942582732228 244:0.9:1036:1049 232:0.703125:1037:1044 244:0.855:1038:1039 ~-0.059266629699200046 251:0.828125:1040:1043 220:0.9375:1041:1042 "
    s .= "~-0.0540129177578828 ~0.054232472871292736 ~0.03583888324941838 11:-0.546875:1045:1048 166:0.1875:1046:1047 ~0.08055649001350579 ~-0.05864013756465475 ~-0.05923034102952132 248:0.875:1050:1079 220:-0.140625:1051:1058 "
    s .= "251:0.859375:1052:1055 104:-1.8125:1053:1054 ~0.06061145886142351 ~-0.05658687527007912 249:0.8333333333333333:1056:1057 ~0.039786030647789905 ~-0.04572666280499359 253:-0.0014972776769525352:1059:1068 243:0.45:1060:1063 "
    s .= "122:0.03125:1061:1062 ~0.0266382111847426 ~-0.08182856050834843 203:0.828125:1064:1067 187:-0.3125:1065:1066 ~-0.012482093300609535 ~0.05594062220843637 ~-0.11865985906042183 2:0:1069:1076 55:0.5:1070:1075 109:0.109375:1071:1072 "
    s .= "~-0.017525976912697108 243:1.25:1073:1074 ~0.045415756950558855 ~-0.041771566873483865 ~-0.019569267311305552 251:1.234375:1077:1078 ~-0.04577554828291219 ~0.022092530332557578 251:1.703125:1080:1081 ~-0.05221523887581463 "
    s .= "~0.014904470143125154 244:0.9:1083:1094 232:0.703125:1084:1089 244:0.855:1085:1086 ~-0.05862965150472178 251:0.828125:1087:1088 ~-0.044074538783866545 ~0.03391137649968868 14:-0.421875:1090:1093 166:0.1875:1091:1092 "
    s .= "~0.07818581953833853 ~-0.05810894886384881 ~-0.06044966740589444 248:0.375:1095:1108 253:-0.014619883040936088:1096:1097 ~0.05310717045095196 243:1.25:1098:1105 244:1.085:1099:1102 251:1.171875:1100:1101 ~-0.02763515371660946 "
    s .= "~0.05029332845416365 157:-0.046875:1103:1104 ~-0.027294002100691092 ~0.04575406368425647 251:1.421875:1106:1107 ~-0.06624045309943799 ~0.03255612377445437 252:0.125:1109:1122 249:1.8333333333333335:1110:1121 "
    s .= "253:-0.10989010989011051:1111:1112 ~0.04783354983219092 250:0.8671875:1113:1118 184:0.3125:1114:1115 ~-0.0287206468393581 145:0.234375:1116:1117 ~0.09447336399717954 ~-0.033665445597718606 160:1.671875:1119:1120 "
    s .= "~-0.050217365786222656 ~0.01724052566106193 ~-0.060878459392801426 226:-0.140625:1123:1124 ~-0.05963316314945079 166:0.40625:1125:1128 167:0.28125:1126:1127 ~0.04744130433997443 ~-0.04423738177119915 ~-0.041375607627071265 "
    s .= "244:0.9:1130:1143 232:0.703125:1131:1138 244:0.855:1132:1133 ~-0.058030364336881274 251:1.171875:1134:1137 220:0.9375:1135:1136 ~-0.05016335028813456 ~0.05689057239807316 ~0.0661282563213702 14:-0.421875:1139:1142 "
    s .= "166:0.1875:1140:1141 ~0.07584652897112312 ~-0.05745419833943943 ~-0.05981340349666858 248:0.375:1144:1157 253:-0.014619883040936088:1145:1146 ~0.052223628156744674 243:1.25:1147:1154 244:1.085:1148:1153 109:1.484375:1149:1152 "
    s .= "190:0.21875:1150:1151 ~0.0008004052667637155 ~-0.0767778508649139 ~0.05634401648142831 ~0.04104911476744294 251:1.421875:1155:1156 ~-0.06449516027930188 ~0.031390782246321684 252:0.125:1158:1169 249:1.8333333333333335:1159:1168 "
    s .= "243:0.45:1160:1163 70:-0.609375:1161:1162 ~0.08103735260042669 ~-0.043959580917608064 49:0.34375:1164:1167 2:0.0625:1165:1166 ~0.04259346787097293 ~-0.05156200634076585 ~-0.062151741830647804 ~-0.060149310272675977 "
    s .= "196:-0.09375:1170:1171 ~-0.04513855928228083 109:0.703125:1172:1175 251:1.203125:1173:1174 ~-0.05678617385522866 ~0.028325309218824715 ~0.04734744490077817 244:0.88:1177:1184 232:0.703125:1178:1181 220:0.9375:1179:1180 "
    s .= "~-0.05697947923708783 ~0.005192638547072556 133:-0.125:1182:1183 ~0.07869478346420224 ~-0.044651330873667294 248:0.875:1185:1220 220:-0.140625:1186:1193 251:0.859375:1187:1190 104:-1.8125:1188:1189 ~0.05736005932519424 "
    s .= "~-0.0549108034543797 249:0.8333333333333333:1191:1192 ~0.03619706433044203 ~-0.043431630254761905 253:-0.005208333333335702:1194:1205 243:0.45:1195:1198 29:-0.109375:1196:1197 ~0.02729599421330181 ~-0.07295051908455413 "
    s .= "187:-0.3125:1199:1200 ~-0.019526746473511658 236:0.625:1201:1204 256:0.9583333333333334:1202:1203 ~0.05434299675101409 ~-0.10319864495822384 ~-0.07794709592087906 2:0:1206:1217 85:0.8125:1207:1214 109:0.109375:1208:1209 "
    s .= "~-0.0435049818138508 70:0.40625:1210:1213 180:0.3984375:1211:1212 ~0.03599078531492736 ~-0.04249576603248786 ~-0.041185143052686196 55:0.546875:1215:1216 ~0.053600714861999924 ~-0.01157231987651996 251:1.234375:1218:1219 "
    s .= "~-0.043680358473437805 ~0.02534258979197614 219:0.2890625:1221:1222 ~-0.05171909257857876 ~-0.002931336601825379 244:0.88:1224:1231 74:-0.46875:1225:1230 75:0.2890625:1226:1227 ~-0.05190838435525091 124:0.390625:1228:1229 "
    s .= "~-0.04715074819075782 ~0.07197124880014161 ~-0.05626776514509899 248:0.375:1232:1251 251:0.296875:1233:1238 58:0.203125:1234:1237 218:0.046875:1235:1236 ~0.030416199152008785 ~-0.05511074590248878 ~-0.05685831829867314 "
    s .= "205:-0.25:1239:1240 ~-0.01992180361758795 256:0.9583333333333334:1241:1250 253:-0.02550884990132192:1242:1243 ~0.05415149788120756 243:1.45:1244:1249 193:0.5:1245:1248 28:0.5:1246:1247 ~0.04475393747246828 ~-0.030630514398306524 "
    s .= "~-0.0366546124832366 ~-0.028139691093381915 ~-0.08585487860977664 252:0.125:1252:1263 251:0.765625:1253:1254 ~-0.05005738816184955 14:-0.640625:1255:1256 ~0.04730789345751879 235:-0.125:1257:1258 ~-0.06079952378245739 "
    s .= "122:0.046875:1259:1262 96:0.0234375:1260:1261 ~-0.028527393286543485 ~0.058871422851267285 ~-0.055723484433882 226:-0.140625:1264:1265 ~-0.05739137728697257 166:0.390625:1266:1269 253:0.008620689655174374:1267:1268 "
    s .= "~0.04713280588156136 ~-0.018747092735214275 ~-0.03927204065468226 244:0.865:1271:1276 232:0.71875:1272:1273 ~-0.05575887303707277 55:-0.15625:1274:1275 ~0.062002303767762605 ~-0.05788716079937539 248:0.375:1277:1300 "
    s .= "251:0.359375:1278:1285 253:-0.0297619047619051:1279:1280 ~0.03805643459913112 112:1.1875:1281:1282 ~-0.05184631627869282 202:-0.078125:1283:1284 ~-0.06221558509730627 ~0.050278768464127044 238:-0.109375:1286:1291 "
    s .= "162:0.3671875:1287:1290 232:-0.3125:1288:1289 ~-0.03570044077061548 ~0.03387891448150044 ~-0.07818780918059004 245:1.3578947368421053:1292:1293 ~-0.10300846766934804 122:0.75:1294:1299 243:0.35:1295:1296 ~0.003307570777682023 "
    s .= "243:2.1500000000000004:1297:1298 ~0.05225977959395836 ~-0.03719919429716642 ~-0.07710662795239592 220:-0.125:1301:1302 ~-0.054641817338399123 253:-0.043604651162790255:1303:1308 243:0.55:1304:1305 ~-0.03875440356413542 "
    s .= "37:-0.25:1306:1307 ~-0.05135447139221664 ~0.053978316977119946 109:0.703125:1309:1310 ~-0.04081220406174692 29:0:1311:1316 244:1.21:1312:1315 241:0.34:1313:1314 ~-0.06073986402477034 ~0.027797916843745968 ~0.04202119196644752 "
    s .= "~-0.03958442077926853 244:0.98:1318:1335 251:1.265625:1319:1332 253:-0.027777777777778567:1320:1327 248:0.375:1321:1326 166:0.1875:1322:1325 2:0.1875:1323:1324 ~0.048457262686261576 ~-0.06400121239312428 ~-0.06664261167883674 "
    s .= "~-0.05091681866681842 220:0.9375:1328:1329 ~-0.05446185982712681 193:0.421875:1330:1331 ~0.05245409465262705 ~-0.060235018477879855 243:1.25:1333:1334 ~0.0539411256542263 ~-0.07529675689848558 249:1.8333333333333335:1336:1363 "
    s .= "243:0.45:1337:1346 248:0.375:1338:1343 190:0.015625:1339:1340 ~-0.04777184437414188 49:0.28125:1341:1342 ~0.03888327280132481 ~-0.07703822969686383 70:-0.609375:1344:1345 ~0.08234450329937965 ~-0.04094997828659072 "
    s .= "208:-0.234375:1347:1350 2:-0.265625:1348:1349 ~0.014315641971917217 ~-0.055062707005665956 31:0.71875:1351:1362 243:2.25:1352:1361 248:0.875:1353:1358 256:0.9583333333333334:1354:1357 251:0.109375:1355:1356 ~-0.07611098974932518 "
    s .= "~0.05095341185371114 ~-0.09142618432040406 25:0.046875:1359:1360 ~0.03851492111870665 ~-0.038429747813630746 ~-0.03497369658440567 ~-0.03501728046279225 ~-0.05615575911442233 244:0.865:1365:1370 232:0.71875:1366:1367 "
    s .= "~-0.054784728317050696 151:-0.046875:1368:1369 ~0.0596424257784334 ~-0.05698998894393662 248:0.375:1371:1390 251:0.359375:1372:1379 253:-0.0297619047619051:1373:1374 ~0.036008999051888584 112:1.1875:1375:1376 "
    s .= "~-0.05002200654589452 202:-0.078125:1377:1378 ~-0.060806775535991835 ~0.048510094714736295 238:-0.109375:1380:1385 162:0.3671875:1381:1384 232:-0.3125:1382:1383 ~-0.03370156632874687 ~0.03213147980573718 ~-0.07407894542033377 "
    s .= "245:1.3578947368421053:1386:1387 ~-0.09860078320237328 122:0.71875:1388:1389 ~0.04860435902584046 ~-0.07192984282988325 220:-0.125:1391:1392 ~-0.05315037819122126 253:-0.043604651162790255:1393:1398 243:0.55:1394:1395 "
    s .= "~-0.036300675189469285 37:-0.25:1396:1397 ~-0.04876107288075208 ~0.05229626079861913 91:1.3125:1399:1408 251:1.203125:1400:1403 244:2.145:1401:1402 ~-0.03816744649879675 ~0.038709022447589087 178:-0.09375:1404:1405 "
    s .= "~-0.07250018598200626 146:0.125:1406:1407 ~0.04470844079195377 ~-0.04445836075731003 121:0.265625:1409:1410 ~0.053357196797219224 ~-0.06809919790426124 244:0.865:1412:1417 232:0.71875:1413:1414 ~-0.05429571486579628 "
    s .= "55:-0.15625:1415:1416 ~0.05726902397259969 ~-0.05661765278475955 248:0.875:1418:1455 253:-0.0218253968253966:1419:1430 235:-0.28125:1420:1423 217:0.265625:1421:1422 ~-0.04426793971450379 ~0.039226689980790735 "
    s .= "233:0.671875:1424:1429 243:0.45:1425:1428 29:-0.109375:1426:1427 ~0.028842355374488007 ~-0.07483576121644563 ~0.05014407875169322 ~-0.07746378057330494 251:1.046875:1431:1448 11:-0.453125:1432:1439 157:1.28125:1433:1438 "
    s .= "55:0.296875:1434:1437 214:-0.109375:1435:1436 ~-0.06497106892122538 ~0.02116546109627872 ~-0.05146523974404678 ~0.04898341327633249 220:-0.0625:1440:1441 ~-0.054972476827338135 112:0.875:1442:1443 ~-0.03414700488162545 "
    s .= "97:0.25:1444:1447 217:0.40625:1445:1446 ~0.039703496732009194 ~-0.05592899556857298 ~-0.06038146425621618 249:1.1666666666666665:1449:1452 243:1.55:1450:1451 ~0.046172997407734145 ~-0.02564074053055064 181:0.3125:1453:1454 "
    s .= "~-0.06598530344561192 ~0.0283991222019265 251:1.703125:1456:1457 ~-0.046725391347350605 ~0.018121665033849217 244:0.865:1459:1464 232:0.71875:1460:1461 ~-0.053823421949225396 133:-0.125:1462:1463 ~0.06895958535399022 "
    s .= "~-0.04888289522123389 248:0.375:1465:1484 253:-0.0218253968253966:1466:1469 232:-0.3125:1467:1468 ~-0.009469427312620307 ~0.04943772439873965 243:1.25:1470:1481 251:0.578125:1471:1476 130:1.09375:1472:1473 ~-0.041200965387466565 "
    s .= "97:0.25:1474:1475 ~0.046058987514628655 ~-0.0696539672563441 191:0.40625:1477:1480 163:-0.3125:1478:1479 ~-0.06744644103891412 ~0.04477272754532707 ~-0.03479445780982908 251:1.484375:1482:1483 ~-0.057407179280881876 "
    s .= "~0.025504163494379783 220:-0.125:1485:1488 236:-0.984375:1486:1487 ~0.02050208698315195 ~-0.05537106312429028 253:-0.043604651162790255:1489:1494 243:0.55:1490:1491 ~-0.034693111288734285 37:-0.25:1492:1493 ~-0.047497300535629935 "
    s .= "~0.050428746357498666 109:0.703125:1495:1496 ~-0.037421712020560764 2:0:1497:1504 244:1.21:1498:1501 241:0.34:1499:1500 ~-0.05838432223733314 ~0.025672169735404163 154:0.078125:1502:1503 ~-0.031402265659432486 "
    s .= "~0.04852357993389489 ~-0.037544767653886285 244:0.98:1506:1521 251:1.265625:1507:1518 244:0.84:1508:1509 ~-0.05256721144426671 253:-0.0607697824527861:1510:1515 143:0.1875:1511:1514 255:0.265625:1512:1513 ~0.05157494409453696 "
    s .= "~-0.038297055987035755 ~-0.07037670822729014 220:0.9375:1516:1517 ~-0.044764586845491165 ~0.029015955508124903 243:1.25:1519:1520 ~0.051601132581904845 ~-0.07462964287257944 249:1.8333333333333335:1522:1551 243:0.45:1523:1532 "
    s .= "184:0.078125:1524:1525 ~-0.04309372948830977 244:1.345:1526:1529 250:0.8671875:1527:1528 ~0.03436582029874019 ~-0.041833867511555996 131:0.015625:1530:1531 ~0.04754607846732112 ~-0.04059975255930298 208:-0.234375:1533:1538 "
    s .= "2:-0.265625:1534:1537 27:-0.0625:1535:1536 ~-0.049171656277725934 ~0.037118443165624564 ~-0.053291045389986885 31:0.71875:1539:1550 243:2.25:1540:1549 253:-0.02550884990132192:1541:1542 ~0.052143505480335445 85:0.71875:1543:1548 "
    s .= "251:0.703125:1544:1545 ~-0.035748738445920296 243:0.6499999999999999:1546:1547 ~-0.033576213798333594 ~0.0412653103176685 ~0.04738312372337904 ~-0.034056014121558925 ~-0.0336947738932847 ~-0.05415370785592874 244:0.865:1553:1558 "
    s .= "232:0.71875:1554:1555 ~-0.052977503384973736 151:-0.046875:1556:1557 ~0.05669708761273984 ~-0.05561130717152401 248:0.875:1559:1596 220:-0.140625:1560:1567 251:0.859375:1561:1564 104:-1.8125:1562:1563 ~0.05485934923153238 "
    s .= "~-0.05121018048180215 249:0.8333333333333333:1565:1566 ~0.030739576502438495 ~-0.038077159136385506 253:-0.02550884990132192:1568:1579 241:0.22:1569:1574 104:-0.046875:1570:1573 222:-0.1484375:1571:1572 ~-0.07479565707273561 "
    s .= "~0.043043013970641905 ~-0.09551558899065349 163:-0.265625:1575:1578 10:0.140625:1576:1577 ~0.02493820896422764 ~-0.09687625161750893 ~0.049920486464084396 26:0.203125:1580:1595 251:1.203125:1581:1594 112:0.875:1582:1589 "
    s .= "251:0.484375:1583:1584 ~-0.04136571183170648 249:0.5:1585:1588 153:0.2734375:1586:1587 ~0.035944677660547604 ~-0.07455221255393091 ~-0.04002184320620315 97:0.46875:1590:1593 247:0.453125:1591:1592 ~0.04448136552976825 "
    s .= "~-0.07929551571576854 ~-0.03924587261280879 ~0.044871282631734836 ~-0.042046629312102166 219:0.2890625:1597:1598 ~-0.04642678845517436 ~0.0003902529491372727 244:0.98:1600:1613 244:0.84:1601:1602 ~-0.05176391715567859 "
    s .= "249:0.5:1603:1612 70:0.28125:1604:1611 50:0.15625:1605:1610 246:-0.015625:1606:1609 122:-0.46875:1607:1608 ~0.02875254722090122 ~-0.060717643221198804 ~0.050433692904614094 ~-0.04912114751697763 ~-0.056546837052524695 "
    s .= "~-0.04567278777748121 249:1.8333333333333335:1614:1643 243:0.45:1615:1624 184:0.078125:1616:1617 ~-0.04133965700887277 244:1.345:1618:1621 250:0.8671875:1619:1620 ~0.033000448236264655 ~-0.03996567347326298 131:0.015625:1622:1623 "
    s .= "~0.045741008970233955 ~-0.03894587174229429 208:-0.234375:1625:1630 2:-0.265625:1626:1629 27:-0.0625:1627:1628 ~-0.04672388155168592 ~0.03524527297935787 ~-0.05134536885155272 25:0.640625:1631:1642 243:1.95:1632:1641 "
    s .= "49:0.625:1633:1640 167:0.59375:1634:1639 256:0.9583333333333334:1635:1638 190:-0.484375:1636:1637 ~-0.036405458841176234 ~0.047854919010744984 ~-0.09642207700638962 ~-0.0283571801059716 ~-0.0325523616453394 ~-0.02249502866699085 "
    s .= "~-0.03598467441449122 192:0.3984375:1644:1645 ~-0.05648807078378418 ~0.057078378252271016 244:0.865:1647:1652 232:0.71875:1648:1649 ~-0.052187890826951515 157:0.21875:1650:1651 ~0.056445692188814504 ~-0.05521629982336464 "
    s .= "248:0.375:1653:1674 253:-0.0218253968253966:1654:1663 238:-0.125:1655:1662 186:0.6171875:1656:1661 243:0.55:1657:1658 ~-0.056033470198728036 30:0.7578125:1659:1660 ~0.0383263038750725 ~-0.09716904764200923 ~-0.18013753105438712 "
    s .= "~0.0491085133290522 243:1.25:1664:1671 251:0.546875:1665:1668 130:1.09375:1666:1667 ~-0.040330961106406105 ~0.035381466030245334 249:1.1666666666666665:1669:1670 ~0.03978572748922943 ~-0.036102167827625056 251:1.484375:1672:1673 "
    s .= "~-0.054959831969768426 ~0.022286851404927616 217:-0.109375:1675:1676 ~-0.04919096003098327 253:-0.043604651162790255:1677:1680 243:0.55:1678:1679 ~-0.030503650105832683 ~0.044015157560188395 109:0.21875:1681:1682 "
    s .= "~-0.05017121594455039 244:1.21:1683:1684 ~-0.029098996928089767 157:0.109375:1685:1686 ~-0.04621326032046935 1:0.625:1687:1692 184:-0.1875:1688:1689 ~-0.0697004919028324 218:0.171875:1690:1691 ~0.057318026532162274 "
    s .= "~-0.02968214453766496 ~-0.07496550297725375 244:0.865:1694:1699 232:0.71875:1695:1696 ~-0.05177566326033221 55:-0.15625:1697:1698 ~0.05522588933783458 ~-0.05477227986108701 249:1.5:1700:1737 253:-0.02550884990132192:1701:1714 "
    s .= "241:0.22:1702:1707 104:-0.046875:1703:1706 174:-0.03125:1704:1705 ~-0.042213950306140294 ~0.04680852930074133 ~-0.08969458367639548 233:0.625:1708:1713 187:-0.28125:1709:1710 ~-0.019347679674125623 28:0.921875:1711:1712 "
    s .= "~0.047932991761944085 ~-0.053118295428692286 ~-0.06700000355550696 251:1.203125:1715:1732 157:1.109375:1716:1727 220:0.9375:1717:1724 238:-0.09375:1718:1719 ~-0.054450434322840725 245:2.425531914893617:1720:1721 "
    s .= "~-0.032446120468810534 248:0.875:1722:1723 ~0.027125298210896483 ~-0.05396440084889264 115:0.375:1725:1726 ~-0.059464040415896584 ~0.06572584226249364 28:0.484375:1728:1731 243:1.35:1729:1730 ~0.03880284641251664 "
    s .= "~-0.03991585001473838 ~-0.059000213730688235 85:0.265625:1733:1734 ~0.001287503379634506 243:1.55:1735:1736 ~0.04877701220713893 ~-0.0542153442856067 198:0.265625:1738:1739 ~-0.05411590945965843 ~0.017428725552120668 "
    s .= "244:0.99:1741:1758 244:0.84:1742:1743 ~-0.05061182542666529 249:0.5:1744:1755 70:0.28125:1745:1754 50:0.15625:1746:1753 251:0.296875:1747:1748 ~-0.04200056100222474 76:0.203125:1749:1750 ~0.05080152491669106 "
    s .= "127:0.234375:1751:1752 ~0.051753719264577815 ~-0.057255161059622285 ~-0.04608765393796083 ~-0.055274638968959344 251:1.390625:1756:1757 ~-0.04802640429272006 ~0.03747619913034324 249:1.8333333333333335:1759:1786 "
    s .= "241:0.22:1760:1773 122:0:1761:1772 109:0.3125:1762:1763 ~-0.038407943893934066 244:1.21:1764:1767 251:0.515625:1765:1766 ~-0.052079307893479455 ~0.029097847378256853 181:-0.109375:1768:1769 ~-0.06518751114703157 "
    s .= "131:0.21875:1770:1771 ~0.044500482285550064 ~-0.06192903918003098 ~-0.049287640396972233 238:-0.171875:1774:1779 122:-0.359375:1775:1776 ~0.027989434551158772 27:0.171875:1777:1778 ~-0.05935489319532464 ~0.0019809842114128597 "
    s .= "243:1.85:1780:1785 25:0.578125:1781:1784 190:-0.1875:1782:1783 ~-0.009971507307459972 ~0.047201729092568485 ~-0.028227645725251545 ~-0.021922133995725387 ~-0.052849863849419476 244:0.865:1788:1793 232:0.71875:1789:1790 "
    s .= "~-0.05104228882008578 9:0.2421875:1791:1792 ~-0.0545946914295296 ~0.05476983723890514 248:0.375:1794:1813 253:-0.02550884990132192:1795:1802 241:0.22:1796:1799 104:-0.046875:1797:1798 ~0.02378469260981106 ~-0.10089170510752046 "
    s .= "187:-0.21875:1800:1801 ~-0.006824715529135043 ~0.04822902629518893 251:1.140625:1803:1812 245:2.425531914893617:1804:1809 31:0.171875:1805:1808 243:0.95:1806:1807 ~0.010704230801310461 ~-0.050109762255266234 ~-0.0596183795796727 "
    s .= "87:0.1484375:1810:1811 ~0.036064896283025685 ~-0.04945020241861575 ~0.039418839747913076 229:-0.09375:1814:1815 ~-0.04746072890947603 109:0.703125:1816:1823 251:0.484375:1817:1818 ~-0.04820500263217868 5:-0.140625:1819:1822 "
    s .= "255:0.296875:1820:1821 ~0.054163638638669555 ~-0.013620883189968513 ~-0.04101579263884464 243:0.45:1824:1827 40:-0.515625:1825:1826 ~0.10303330115743144 ~-0.032929359109399856 121:-0.25:1828:1829 ~-0.05455610758017946 "
    s .= "49:0.28125:1830:1833 248:1.125:1831:1832 ~0.05062122423292285 ~-0.04121826587314226 ~-0.030883052552075786 244:0.855:1835:1840 232:0.71875:1836:1837 ~-0.051984502900308274 55:-0.171875:1838:1839 ~0.05618927432793506 "
    s .= "~-0.05390909028478777 248:0.375:1841:1862 253:-0.02550884990132192:1842:1847 238:-0.125:1843:1846 186:0.6171875:1844:1845 ~0.01949672841028853 ~-0.1715978406453593 ~0.047231622062655486 243:1.55:1848:1859 251:1.046875:1849:1858 "
    s .= "130:1.03125:1850:1855 190:0.28125:1851:1854 238:-0.03125:1852:1853 ~-0.044515327581562764 ~0.013426809097188106 ~-0.05846627227695744 187:-0.3125:1856:1857 ~-0.06016491038303828 ~0.03527476695430839 ~0.04133149325851305 "
    s .= "3:0.1953125:1860:1861 ~-0.06518451003479674 ~0.014097963432231892 229:-0.09375:1863:1864 ~-0.04671006491369542 85:1.15625:1865:1878 251:1.359375:1866:1875 168:-0.0546875:1867:1868 ~-0.04749568851652797 77:0.09375:1869:1874 "
    s .= "232:0.40625:1870:1873 235:0.625:1871:1872 ~0.00910999892256875 ~0.09724266266499366 ~-0.04668718509143204 ~-0.05217295047628018 218:0.09375:1876:1877 ~0.04285600541376247 ~-0.05849885345412266 148:-0.171875:1879:1880 "
    s .= "~-0.04593937035903056 ~0.04447313181677115 244:0.855:1882:1887 232:0.71875:1883:1884 ~-0.051678694693631434 157:0.21875:1885:1886 ~0.05449815993870627 ~-0.053831190402563914 249:1.5:1888:1925 253:-0.02550884990132192:1889:1904 "
    s .= "241:0.22:1890:1895 104:-0.046875:1891:1894 174:-0.03125:1892:1893 ~-0.04168843874520725 ~0.044023768464769006 ~-0.08525856037751786 208:-0.234375:1896:1899 163:-0.140625:1897:1898 ~-0.0721717655079448 ~0.024422731605747428 "
    s .= "233:0.625:1900:1903 25:0.703125:1901:1902 ~0.046547750890479515 ~-0.047027971200447105 ~-0.06598210543092983 26:0.265625:1905:1924 251:0.671875:1906:1919 112:1.40625:1907:1916 220:0.9375:1908:1915 250:0.8671875:1909:1914 "
    s .= "238:-0.046875:1910:1911 ~-0.0584597803843836 94:0.203125:1912:1913 ~0.04013625304846685 ~-0.03294733380803976 ~-0.043127648131159664 ~0.04676331584147814 202:-0.0625:1917:1918 ~-0.03872211290007438 ~0.043149010339176355 "
    s .= "85:0.578125:1920:1921 ~0.0074085303099255114 243:1.45:1922:1923 ~0.04591745827728216 ~-0.04042150541874913 ~-0.04918305579904476 198:0.265625:1926:1927 ~-0.0527132850842921 ~0.015433438409608952 244:0.99:1929:1944 "
    s .= "244:0.84:1930:1931 ~-0.049220241120943524 249:0.5:1932:1941 70:0.28125:1933:1940 50:0.15625:1934:1939 113:-0.03125:1935:1938 85:0.5625:1936:1937 ~-0.05386039872462 ~0.02997393271656061 ~0.04963230666177316 ~-0.04433543938827918 "
    s .= "~-0.053360855233087916 251:1.390625:1942:1943 ~-0.046061046481225706 ~0.03535661381654021 249:1.8333333333333335:1945:1974 241:0.22:1946:1957 122:0:1947:1956 109:0.3125:1948:1949 ~-0.036485666448519076 244:1.21:1950:1953 "
    s .= "251:0.515625:1951:1952 ~-0.04904855075833789 ~0.026354668316146343 181:-0.109375:1954:1955 ~-0.06432479695579806 ~0.03766316662846969 ~-0.046701740234750884 238:-0.171875:1958:1963 122:-0.359375:1959:1962 16:0.296875:1960:1961 "
    s .= "~0.037452486091732844 ~-0.06914910905297589 ~-0.033474501236837796 243:1.85:1964:1973 25:0.578125:1965:1972 122:0.046875:1966:1967 ~0.047900207428800745 252:0.125:1968:1969 ~-0.07167845769718781 248:0.875:1970:1971 "
    s .= "~0.03935959737940459 ~-0.04272439161863587 ~-0.02713644533239834 ~-0.02096098108036315 ~-0.05128366572180504 244:0.855:1976:1981 232:0.71875:1977:1978 ~-0.05110444092732748 23:-0.53125:1979:1980 ~0.05514144292762572 "
    s .= "~-0.053533557328894324 249:1.5:1982:2017 253:-0.02550884990132192:1983:1996 122:0.078125:1984:1989 243:0.45:1985:1988 219:-0.1328125:1986:1987 ~-0.06552838115526956 ~0.027459337493126203 ~0.04556814533712361 241:0.42:1990:1993 "
    s .= "240:0.328125:1991:1992 ~-0.06099194584774628 ~-0.19790298183326924 220:-0.171875:1994:1995 ~-0.044547228708404545 ~0.036386311595311055 85:1.15625:1997:2012 251:1.203125:1998:2009 163:1.1875:1999:2008 220:0.9375:2000:2005 "
    s .= "242:0.45:2001:2004 250:0.8671875:2002:2003 ~0.022922569950922348 ~-0.029571183735962882 ~-0.04343318686165404 127:0.375:2006:2007 ~-0.05619700788505674 ~0.06198008715705329 ~0.02874159456182898 248:0.375:2010:2011 "
    s .= "~0.03614431545529836 ~-0.010014693613815214 202:-0.109375:2013:2014 ~-0.03493655759832529 161:0.53125:2015:2016 ~0.045625215014316454 ~-0.06739705197224198 195:0.2109375:2018:2021 6:0.515625:2019:2020 ~-0.05593778136789162 "
    s .= "~0.051447106024988656 ~0.010060407184342549 244:0.99:2023:2038 244:0.84:2024:2025 ~-0.04848461931354238 97:0.203125:2026:2037 243:1.25:2027:2036 239:0.203125:2028:2035 246:-0.015625:2029:2032 122:-0.46875:2030:2031 "
    s .= "~0.013478376974588062 ~-0.0544219038250235 121:-0.21875:2033:2034 ~-0.04682879171690468 ~0.04902185567605253 ~-0.04977960810537314 ~-0.0641358230605106 ~-0.04955898629923259 249:1.8333333333333335:2039:2068 "
    s .= "253:-0.02550884990132192:2040:2051 241:0.22:2041:2044 184:0.296875:2042:2043 ~-0.06634543065039963 ~0.03492325971314988 40:-0.265625:2045:2048 212:-0.03125:2046:2047 ~0.03846952456304443 ~-0.07835332021848307 1:0.84375:2049:2050 "
    s .= "~0.04753973780107315 ~-0.049210064248104556 122:0.015625:2052:2063 195:-0.0546875:2053:2058 88:1.3125:2054:2057 163:1.234375:2055:2056 ~-0.02908636753958399 ~0.03712232105638582 ~0.03888299378451512 187:-0.3125:2059:2060 "
    s .= "~-0.05647593861941096 52:0.65625:2061:2062 ~0.03734622805545653 ~-0.032989124857027374 252:0.07500000000000001:2064:2065 ~-0.04569708953972032 31:0.09375:2066:2067 ~0.01348183514910385 ~-0.04606986820022155 ~-0.050321314316685434 "
    s .= "244:0.855:2070:2075 232:0.71875:2071:2072 ~-0.05055193504660421 151:-0.046875:2073:2074 ~0.05581076148991931 ~-0.05290554828446414 248:0.375:2076:2101 238:-0.078125:2077:2090 26:-0.390625:2078:2081 43:0.359375:2079:2080 "
    s .= "~0.02960486128993341 ~-0.08636349341983948 241:0.48:2082:2085 243:0.8500000000000001:2083:2084 ~-0.03780754049094534 ~-0.16094627031240433 31:0.390625:2086:2089 253:-0.02285714285714643:2087:2088 ~0.046501221868024495 "
    s .= "~-0.019339410736648095 ~-0.05810034016379228 253:-0.020833333333333925:2091:2092 ~0.045156862753201805 191:0.09375:2093:2100 243:1.55:2094:2099 85:0.71875:2095:2098 193:0.328125:2096:2097 ~0.025951333451073717 "
    s .= "~-0.03329808129027947 ~0.04671398478019071 ~-0.04007964735132575 ~-0.019789372187204866 229:-0.09375:2102:2103 ~-0.044295923978048844 85:1.15625:2104:2113 168:0.0234375:2105:2106 ~-0.03439974449152929 77:0.09375:2107:2112 "
    s .= "251:0.734375:2108:2111 128:-0.0625:2109:2110 ~-0.034585610148473056 ~0.03604075980563722 ~0.04416554851210822 ~-0.03736071641433614 76:-0.1875:2114:2115 ~-0.04062808785717487 ~0.04195940817664301 244:0.98:2117:2132 "
    s .= "244:0.815:2118:2119 ~-0.04988445783707896 94:0.203125:2120:2131 49:0.171875:2121:2130 249:0.8333333333333333:2122:2127 191:0.234375:2123:2126 211:-0.109375:2124:2125 ~-0.035115298101813394 ~0.04853493301216816 "
    s .= "~-0.049898215718753386 108:0.2578125:2128:2129 ~-0.05312067972064957 ~0.02838355851028155 ~-0.05222513328861115 ~-0.04700338663823889 249:1.8333333333333335:2133:2160 253:-0.02550884990132192:2134:2145 241:0.22:2135:2138 "
    s .= "184:0.296875:2136:2137 ~-0.06453655061010363 ~0.03252927878273811 40:-0.265625:2139:2142 212:-0.03125:2140:2141 ~0.03763145044775856 ~-0.07198444430808713 1:0.84375:2143:2144 ~0.04652734568644717 ~-0.044215229502666945 "
    s .= "238:-0.09375:2146:2149 248:0.125:2147:2148 ~-0.002695989806950071 ~-0.043824700119092175 109:0.109375:2150:2153 85:0.296875:2151:2152 ~-0.051569475444376435 ~0.039572496072051544 181:-0.125:2154:2155 ~-0.052858354420808364 "
    s .= "122:0.25:2156:2159 251:0.171875:2157:2158 ~-0.024283794393908154 ~0.03312782880402554 ~-0.02509610641666553 192:0.3984375:2161:2162 ~-0.053010092489916685 ~0.0604160955138697 244:0.855:2164:2169 232:0.71875:2165:2166 "
    s .= "~-0.05000847465919364 6:0.21875:2167:2168 ~-0.052861792154647896 ~0.055196867332943315 220:-0.140625:2170:2175 44:-0.75:2171:2172 ~0.0245134766965678 99:0.3203125:2173:2174 ~-0.045195074477397845 ~0.023977359703003416 "
    s .= "253:-0.043604651162790255:2176:2189 241:0.22:2177:2180 184:0.140625:2178:2179 ~-0.07963961399928476 ~0.015580314240358323 163:-0.265625:2181:2182 ~-0.030500554238407897 256:0.8333333333333334:2183:2188 55:-0.21875:2184:2187 "
    s .= "186:0.5078125:2185:2186 ~0.025938502703429296 ~-0.20361691791250203 ~0.04763166116620643 ~-0.054187610255270025 251:1.203125:2190:2205 112:1.375:2191:2202 169:0.15625:2192:2201 109:0.25:2193:2194 ~-0.039905839001801516 "
    s .= "145:-0.0625:2195:2196 ~-0.03622168610435939 238:-0.046875:2197:2198 ~-0.036140887499505364 26:0.265625:2199:2200 ~0.03660026123402675 ~-0.043631049623565704 ~-0.03775471534734687 187:0.046875:2203:2204 ~-0.01631378985356029 "
    s .= "~0.040457217405118824 178:-0.09375:2206:2207 ~-0.03173825951662248 53:0.265625:2208:2209 ~0.04120635015071962 ~-0.019751077195958058 244:0.99:2211:2226 244:0.795:2212:2213 ~-0.05170471832356154 249:0.5:2214:2223 "
    s .= "76:0.203125:2215:2220 166:0.1875:2216:2219 214:-0.109375:2217:2218 ~-0.03592319472444934 ~0.04735385362642687 ~-0.034884583921469973 7:1.5:2221:2222 ~-0.04908500088996305 ~0.11498544259789865 251:1.390625:2224:2225 "
    s .= "~-0.04454425525482794 ~0.0315404520606271 249:1.8333333333333335:2227:2256 253:-0.02550884990132192:2228:2237 122:0.046875:2229:2230 ~0.04376160514686802 241:0.4:2231:2234 3:0.2109375:2232:2233 ~-0.03786767526924304 "
    s .= "~-0.1512808865244304 40:-0.234375:2235:2236 ~-0.07110783182316262 ~0.03759545650309047 214:-0.171875:2238:2239 ~-0.03575992376853503 109:0.109375:2240:2243 85:0.15625:2241:2242 ~-0.05124899514197689 ~0.02945335909056576 "
    s .= "28:0.484375:2244:2253 5:-0.625:2245:2246 ~0.043859609359014916 254:1.046875:2247:2252 50:0.28125:2248:2251 196:-0.1875:2249:2250 ~-0.03355713127474317 ~0.03214567917182037 ~-0.028084584547391846 ~-0.0426516807441638 "
    s .= "184:0.1875:2254:2255 ~0.006038949905551732 ~-0.0657036184427353 ~-0.048838135754348484 244:0.855:2258:2263 232:0.71875:2259:2260 ~-0.04947077118373597 55:-0.171875:2261:2262 ~0.05364539196348272 ~-0.05220102550398829 "
    s .= "248:0.375:2264:2285 251:0.546875:2265:2274 28:0.25:2266:2273 119:0.109375:2267:2272 245:1.5932203389830508:2268:2269 ~-0.10520848360001832 196:-0.15625:2270:2271 ~-0.040149308602665655 ~0.032562645138525234 ~-0.032535805196858156 "
    s .= "~-0.058383586026539626 74:-0.140625:2275:2276 ~0.04152134447546896 252:0.175:2277:2282 131:0.0625:2278:2279 ~0.00921254850264632 254:0.046875:2280:2281 ~0.03884319655033573 ~-0.09838587708825923 25:0.328125:2283:2284 "
    s .= "~0.035547003314258446 ~-0.0541874831745289 229:-0.15625:2286:2287 ~-0.04696913118282986 109:0.46875:2288:2295 91:0.171875:2289:2290 ~-0.04444050164414975 91:0.203125:2291:2292 ~0.08251148256124806 245:1.9473684210526316:2293:2294 "
    s .= "~0.018867272621170036 ~-0.05206543046385545 244:1.13:2296:2299 251:0.515625:2297:2298 ~-0.051668725804979165 ~0.003528276987590011 233:0.4375:2300:2303 121:-0.140625:2301:2302 ~-0.021218011365517337 ~0.039623469163533584 "
    s .= "~-0.051717465854802 244:0.855:2305:2310 232:0.71875:2306:2307 ~-0.049198644389535875 23:-0.53125:2308:2309 ~0.052600228379461746 ~-0.052252212154604905 249:1.5:2311:2344 253:-0.02550884990132192:2312:2323 122:0.078125:2313:2318 "
    s .= "243:0.45:2314:2317 205:0.34375:2315:2316 ~-0.03558768397618132 ~0.04792979832288296 ~0.0421630847840212 241:0.42:2319:2320 ~-0.07842073829016542 190:-0.1875:2321:2322 ~-0.057395978373652914 ~0.03074333729424584 "
    s .= "26:0.265625:2324:2343 251:0.671875:2325:2336 112:1.40625:2326:2333 171:-0.046875:2327:2328 ~-0.04213555691166562 220:0.9375:2329:2332 250:0.8671875:2330:2331 ~0.018226198569822546 ~-0.03199350871728108 ~0.06042538073249322 "
    s .= "202:-0.0625:2334:2335 ~-0.03497287363287751 ~0.03910072339547981 243:1.25:2337:2342 243:0.35:2338:2339 ~-0.012461883230058358 190:-0.328125:2340:2341 ~-0.051110807175292754 ~0.0375641246204286 ~-0.02126187840918111 "
    s .= "~-0.044672386215866916 219:0.2578125:2345:2348 9:0.4765625:2346:2347 ~-0.05469438009544845 ~0.04429336342150966 245:2.196969696969697:2349:2350 ~-0.05070707822687696 ~0.04996600976612349 244:0.98:2352:2365 244:0.795:2353:2354 "
    s .= "~-0.05117020434537076 94:0.203125:2355:2364 49:0.171875:2356:2363 249:0.8333333333333333:2357:2362 191:0.234375:2358:2361 211:-0.0625:2359:2360 ~-0.0271019751410363 ~0.04730929782287938 ~-0.04838044978017769 ~-0.03267457861757877 "
    s .= "~-0.05094735045274884 ~-0.04582457265877743 249:1.8333333333333335:2366:2395 253:-0.02550884990132192:2367:2382 241:0.22:2368:2371 184:0.296875:2369:2370 ~-0.06055111490788473 ~0.029729649211116357 55:-0.21875:2372:2377 "
    s .= "140:0.1875:2373:2374 ~0.03176137771790366 242:0.35:2375:2376 ~-0.2284927410035015 ~-0.043156984434608615 163:-0.265625:2378:2379 ~-0.02385331015670817 4:0.796875:2380:2381 ~0.04693398733909522 ~-0.04017912809872742 "
    s .= "122:0.015625:2383:2392 195:-0.0546875:2384:2387 88:1.3125:2385:2386 ~-0.01901961570086073 ~0.03539648949498841 187:-0.3125:2388:2389 ~-0.053237726487630616 52:0.65625:2390:2391 ~0.03291308980917166 ~-0.03312619946421363 "
    s .= "254:0.140625:2393:2394 ~0.0025625205799766747 ~-0.03759794526063551 192:0.3984375:2396:2397 ~-0.05176648311134169 ~0.05721143474617382 244:0.855:2399:2404 232:0.71875:2400:2401 ~-0.048663207668496716 166:0.015625:2402:2403 "
    s .= "~0.051406988240524365 ~-0.05183324197797734 220:-0.140625:2405:2412 32:-0.828125:2406:2409 28:0.328125:2407:2408 ~0.042996868762511936 ~-0.0590391877905356 99:0.2578125:2410:2411 ~-0.04500953741909193 ~0.015647435677942134 "
    s .= "253:-0.043604651162790255:2413:2424 241:0.22:2414:2417 202:0.4375:2415:2416 ~-0.04865263061970873 ~0.040563624445930764 163:-0.21875:2418:2419 ~-0.022380658463614814 55:-0.21875:2420:2423 186:0.5078125:2421:2422 "
    s .= "~0.02077712064185136 ~-0.146501513309746 ~0.044732850549676656 251:1.203125:2425:2442 112:1:2426:2435 61:1.453125:2427:2434 255:0.296875:2428:2433 122:0.25:2429:2432 251:0.484375:2430:2431 ~-0.01865135542618557 "
    s .= "~0.027618029197200633 ~-0.05591998808751038 ~-0.04286593530755253 ~0.04663614348692388 94:-0.25:2436:2437 ~-0.05604186606367206 193:0.53125:2438:2441 187:0.046875:2439:2440 ~-0.0066808105152547 ~0.04022623732869987 "
    s .= "~-0.0448354657298764 130:1.96875:2443:2444 ~0.03328854553604854 ~-0.03279557831145001 248:0.375:2446:2477 244:0.98:2447:2456 166:0.171875:2448:2455 26:0.109375:2449:2454 190:-0.171875:2450:2451 ~-0.05136391698254011 "
    s .= "244:0.795:2452:2453 ~-0.050034838540707484 ~0.04423169208750915 ~-0.04768025748843738 ~-0.059575289664703414 187:-0.046875:2457:2464 241:0.52:2458:2463 146:-0.09375:2459:2462 184:-0.234375:2460:2461 ~-0.07484973793722369 "
    s .= "~0.018397157874878688 ~-0.0970388154934169 ~0.01896267792287397 28:0.5:2465:2474 256:0.9583333333333334:2466:2473 252:0.07500000000000001:2467:2472 245:1.6491228070175439:2468:2469 ~-0.09925090957543896 49:0.390625:2470:2471 "
    s .= "~0.0303134482391105 ~-0.0883660507447297 ~0.043561488037380997 ~-0.08970014946804755 244:1.58:2475:2476 ~-0.06193388753656309 ~0.037546153170175005 251:0.734375:2478:2487 244:1.2:2479:2482 7:1.5:2480:2481 ~-0.045955363355936946 "
    s .= "~0.08294165067283672 109:0.484375:2483:2484 ~-0.05703175929731263 217:-0.125:2485:2486 ~-0.048053547951566605 ~0.030171321392195683 191:-0.046875:2488:2491 168:0.1484375:2489:2490 ~-0.00392126937965893 ~0.041722791684649145 "
    s .= "~-0.02956789475257531 244:0.84:2493:2496 214:1.375:2494:2495 ~-0.046591610438495405 ~0.11200534533494469 248:0.875:2497:2532 190:-0.125:2498:2505 109:1.3125:2499:2502 18:0.3359375:2500:2501 ~-0.05285930504921243 "
    s .= "~0.0017215155520095224 218:-0.359375:2503:2504 ~0.03402003858306529 ~-0.025450366088818552 26:-0.15625:2506:2519 27:-0.09375:2507:2516 109:1.171875:2508:2515 77:-0.703125:2509:2512 70:0.359375:2510:2511 ~0.044805880182724474 "
    s .= "~-0.055691896952442504 254:1.359375:2513:2514 ~-0.014151117714284525 ~-0.08406171446029832 ~0.03298390520765767 28:0.421875:2517:2518 ~0.041986617125360705 ~-0.025005141536565252 252:0.175:2520:2525 250:0.9140625:2521:2524 "
    s .= "71:0.25:2522:2523 ~0.0159113328456593 ~-0.045120002743200424 ~-0.049920779554560965 31:0.171875:2526:2529 243:2.25:2527:2528 ~0.03726938121370313 ~-0.05981564187646025 231:0.4453125:2530:2531 ~-0.04904877449277355 "
    s .= "~0.030187257820639465 61:0.515625:2533:2534 ~-0.040183793504924695 202:0.234375:2535:2538 202:-0.046875:2536:2537 ~-0.031892485277568376 ~0.06391406744096984 ~-0.04622254285575514 244:0.84:2540:2543 232:0.734375:2541:2542 "
    s .= "~-0.049176620960116296 ~0.0028775825543496856 196:-0.140625:2544:2551 249:0.8333333333333333:2545:2550 149:-0.328125:2546:2549 157:1.015625:2547:2548 ~-0.016814691535614868 ~0.04628137106437564 ~-0.029873862294825488 "
    s .= "~-0.05073145804562182 253:-0.043604651162790255:2552:2559 163:-0.140625:2553:2556 249:0.16666666666666666:2554:2555 ~0.0239070980226819 ~-0.0705191253630687 243:0.45:2557:2558 ~-0.01933992663931946 ~0.0413167250872593 "
    s .= "26:0.265625:2560:2585 251:1.203125:2561:2580 154:1.140625:2562:2577 255:0.296875:2563:2570 187:-0.046875:2564:2565 ~-0.04141530955498339 75:-0.1640625:2566:2567 ~-0.0446735984569161 108:0.1171875:2568:2569 ~0.038362173866738444 "
    s .= "~-0.00644722413729645 5:-0.71875:2571:2574 251:0.359375:2572:2573 ~-0.04447176880218581 ~0.03173329863483256 220:0.984375:2575:2576 ~-0.05412508249047974 ~0.029082675489039225 121:0.5625:2578:2579 ~0.035458230100974306 "
    s .= "~-0.030913249649474558 85:0.28125:2581:2582 ~0.004061204241447931 243:1.45:2583:2584 ~0.04752519768204177 ~-0.040469503849731164 ~-0.04426083830914778 248:0.375:2587:2612 251:0.546875:2588:2599 28:0.25:2589:2598 "
    s .= "119:0.109375:2590:2597 196:-0.125:2591:2592 ~-0.03657313578089968 245:1.5797101449275361:2593:2594 ~-0.08299977719443652 111:0.2890625:2595:2596 ~0.03180450201524198 ~-0.07630396080274511 ~-0.0379684829515175 "
    s .= "~-0.05452188712573807 256:0.9583333333333334:2600:2611 211:-0.09375:2601:2606 138:0.2890625:2602:2603 ~0.01379168948437746 241:0.56:2604:2605 ~-0.1146073365093137 ~0.00758554031053716 233:0.625:2607:2610 "
    s .= "245:1.3157894736842106:2608:2609 ~-0.07593660094585246 ~0.03817609039148678 ~-0.06039702581661885 ~-0.06653021552496485 251:0.671875:2613:2624 244:1.2:2614:2617 250:0.8359375:2615:2616 ~-0.0125098652205138 ~-0.04898857032255798 "
    s .= "211:0.578125:2618:2621 67:0.25:2619:2620 ~-0.04373958842740972 ~0.030578378600566003 145:0.234375:2622:2623 ~0.051420725684021 ~-0.06165444182603178 191:-0.046875:2625:2632 190:-0.1875:2626:2627 ~-0.031624258843784385 "
    s .= "145:-0.234375:2628:2629 ~-0.03967610075484622 174:-0.265625:2630:2631 ~-0.028049898477205827 ~0.038379511708077615 ~-0.02982835385024006 244:0.84:2634:2637 232:0.734375:2635:2636 ~-0.048759442000929513 ~0.0033515465529442706 "
    s .= "249:1.5:2638:2675 253:-0.0607697824527861:2639:2646 140:0.078125:2640:2641 ~0.04184661288972379 242:0.35:2642:2643 ~-0.12069907238357068 46:-0.265625:2644:2645 ~-0.05659886948224724 ~0.02823358134262884 251:1.203125:2647:2666 "
    s .= "85:1.25:2648:2661 255:0.296875:2649:2658 26:0.0625:2650:2657 195:-0.0546875:2651:2652 ~-0.02439807268745126 156:0.2109375:2653:2656 122:0.09375:2654:2655 ~0.04602327681420395 ~-0.02709349364630841 ~-0.027511233940687135 "
    s .= "~-0.03244147392614776 98:-0.515625:2659:2660 ~-0.0068500552612405854 ~-0.053624531365149275 208:-0.125:2662:2663 ~-0.027326446485477503 87:0.3984375:2664:2665 ~0.04267257279476986 ~-0.08757985579612072 243:1.95:2667:2674 "
    s .= "243:0.35:2668:2671 244:1.11:2669:2670 ~0.0581989690752203 ~-0.05245668808214911 50:0.28125:2672:2673 ~0.03818460576296764 ~-0.019753351867000685 ~-0.05883003687129195 195:0.2109375:2676:2679 6:0.515625:2677:2678 "
    s .= "~-0.05397253690022305 ~0.049425622783833625 ~0.008284433787673566 26:-0.109375:2681:2704 27:-0.03125:2682:2693 109:1.171875:2683:2688 242:0.55:2684:2687 195:-0.0703125:2685:2686 ~-0.03044542865444119 ~0.021241352715199526 "
    s .= "~-0.04167504137529665 208:-0.171875:2689:2690 ~-0.042029238607360186 247:0.296875:2691:2692 ~0.03350883836964928 ~-0.054431528153062805 248:0.875:2694:2703 244:0.795:2695:2696 ~-0.05055298077067058 52:0.265625:2697:2700 "
    s .= "245:1.3578947368421053:2698:2699 ~-0.07663967173461869 ~0.04068513877150793 251:0.921875:2701:2702 ~-0.04269068323833273 ~0.03077847886801076 ~-0.01655795112203517 244:1.415:2705:2720 251:1.578125:2706:2717 26:0.109375:2707:2716 "
    s .= "255:0.265625:2708:2715 235:-0.078125:2709:2710 ~-0.05160476647697309 47:0.21875:2711:2714 145:0.109375:2712:2713 ~0.044576795237863294 ~-0.021611013884101596 ~-0.06218467308001359 ~-0.05391206520115385 ~-0.048983337228903676 "
    s .= "256:0.38461538461538464:2718:2719 ~-0.05008762914337438 ~0.04517906134311317 252:0.07500000000000001:2721:2724 140:-0.140625:2722:2723 ~0.02418311348191269 ~-0.04261341049541205 130:2.0625:2725:2726 ~0.031282940636083285 "
    s .= "~-0.05203914497499479 244:0.84:2728:2733 205:0.734375:2729:2730 ~-0.04836209625538783 12:0.2578125:2731:2732 ~-0.050575871651540864 ~0.05746110763643908 217:-0.140625:2734:2741 26:-0.78125:2735:2738 109:1.484375:2736:2737 "
    s .= "~-0.013170991832511218 ~0.05835189437748202 195:0.1953125:2739:2740 ~-0.046933338426983315 ~0.006253414058916983 253:-0.043604651162790255:2742:2753 49:0.328125:2743:2750 49:-0.140625:2744:2749 140:0.03125:2745:2746 "
    s .= "~0.030607879086630596 186:0.3828125:2747:2748 ~-0.024756512961063876 ~-0.1381342631862835 ~0.042745858368193515 109:1.34375:2751:2752 ~-0.04703260461031125 ~0.03721919592753069 26:0.265625:2754:2773 251:0.203125:2755:2758 "
    s .= "250:0.8671875:2756:2757 ~0.012320832267991211 ~-0.0479025916954317 255:0.265625:2759:2764 190:-0.3125:2760:2761 ~-0.038837057209274925 95:0.515625:2762:2763 ~0.03609921544090188 ~-0.02769332962178353 26:-0.4375:2765:2768 "
    s .= "95:0.0625:2766:2767 ~0.02531569355394391 ~-0.05657319729224496 254:0.953125:2769:2772 157:1.046875:2770:2771 ~-0.03135855075289486 ~0.020752706318628293 ~-0.06678099380295258 ~-0.0406910650887174 244:0.815:2775:2776 "
    s .= "~-0.04670678921932467 249:0.8333333333333333:2777:2812 28:0.5:2778:2809 191:-0.03125:2779:2798 187:-0.3125:2780:2781 ~-0.04070302194096872 243:0.35:2782:2789 49:-0.546875:2783:2784 ~0.15590037375566934 184:0.375:2785:2786 "
    s .= "~-0.028783921668406917 190:0.296875:2787:2788 ~0.07057778830233732 ~-0.018313208609586473 243:1.65:2790:2797 251:0.515625:2791:2796 97:0.25:2792:2795 111:0.2890625:2793:2794 ~0.03344285069870689 ~-0.0703820687111916 "
    s .= "~-0.062343445677893676 ~0.043083765360540115 ~-0.017284090183802555 46:-0.25:2799:2800 ~-0.048710867669311035 252:0.275:2801:2806 122:0.046875:2802:2805 255:0.234375:2803:2804 ~0.02910706820545671 ~-0.034166273369147036 "
    s .= "~-0.03548110949591593 118:0.296875:2807:2808 ~0.03337751203424558 ~-0.019177751143938666 244:1.715:2810:2811 ~-0.041851091448122886 ~0.0311597398380746 195:0.1484375:2813:2816 63:0.3515625:2814:2815 ~-0.0454639368368924 "
    s .= "~0.02672435326903197 244:1.065:2817:2818 ~-0.03722288721527013 29:0.046875:2819:2820 ~0.039219915719431495 ~-0.03683208587495373 244:0.815:2822:2823 ~-0.046322703212535496 238:-0.09375:2824:2833 251:0.765625:2825:2828 "
    s .= "244:1.47:2826:2827 ~-0.051596849918399496 ~-0.0032189098924511753 26:-0.65625:2829:2830 ~0.038926203861334774 46:-0.25:2831:2832 ~-0.05373816109064805 ~0.0026362095506429345 248:0.875:2834:2861 109:1.140625:2835:2856 "
    s .= "214:0.265625:2836:2849 190:-0.140625:2837:2838 ~-0.05839389643826022 143:0.140625:2839:2848 255:0.265625:2840:2843 244:0.855:2841:2842 ~0.1631074473630534 ~0.042191835937300685 122:-0.328125:2844:2845 ~0.03316075258802406 "
    s .= "89:0.25:2846:2847 ~-0.04458960168098552 ~0.038126530281980105 ~-0.011725137928221073 242:0.55:2850:2855 166:0.578125:2851:2854 250:0.8203125:2852:2853 ~0.06529495993204047 ~-0.007943292674688456 ~-0.05653644668644231 "
    s .= "~-0.04627517184682972 247:0.546875:2857:2860 245:4.878048780487805:2858:2859 ~0.03933267566811634 ~-0.16730817086004496 ~-0.040785908662309994 61:0.515625:2862:2865 46:1.21875:2863:2864 ~-0.03941876887150275 ~0.09332428454845372 "
    s .= "202:0.234375:2866:2867 ~0.04730221810629275 ~-0.04181202720353717 251:0.671875:2869:2894 244:1.2:2870:2885 14:-0.953125:2871:2874 70:0.171875:2872:2873 ~0.04542306683366364 ~-0.04543573903689054 255:0.296875:2875:2884 "
    s .= "2:0.03125:2876:2883 76:0.28125:2877:2882 235:-0.09375:2878:2879 ~-0.050968255052369495 250:0.9765625:2880:2881 ~0.04816568908820705 ~-0.015218757405258597 ~-0.052127865762670124 ~-0.0488311467847906 ~-0.05274186299258087 "
    s .= "202:-0.09375:2886:2887 ~-0.044681277280637054 109:0.25:2888:2889 ~-0.03324391779205862 193:0.265625:2890:2893 90:0.3203125:2891:2892 ~0.03897718123897424 ~-0.0690128944408232 ~-0.025999818292670247 191:-0.046875:2895:2906 "
    s .= "187:-0.28125:2896:2897 ~-0.03153613753576014 109:0.53125:2898:2905 137:0.5625:2899:2904 100:1.09375:2900:2903 249:0.16666666666666666:2901:2902 ~0.018512259041500022 ~-0.03295955106640681 ~0.05121856630441001 ~0.05553336230096817 "
    s .= "~0.038326961500988986 255:0.265625:2907:2912 20:0.453125:2908:2911 236:0.625:2909:2910 ~0.02692968066251237 ~-0.04151352615082436 ~-0.04242097025657532 251:2.484375:2913:2914 ~-0.04219206236271075 ~0.0355277123995076 "
    s .= "26:-0.109375:2916:2941 27:-0.03125:2917:2932 109:1.203125:2918:2929 220:0.984375:2919:2928 242:0.55:2920:2927 150:-0.1171875:2921:2922 ~-0.031447308157876074 250:0.8359375:2923:2924 ~0.06039535526008302 130:1.421875:2925:2926 "
    s .= "~-0.028653134518024145 ~0.04850901322032095 ~-0.045225685917690495 ~0.04455081328948221 199:-0.0625:2930:2931 ~-0.025311787918392434 ~0.02999350211962192 253:-0.005208333333335702:2933:2934 ~0.03844494204490543 "
    s .= "109:0.5625:2935:2938 175:0.53125:2936:2937 ~-0.02006253167348039 ~0.038562791063277924 97:0.484375:2939:2940 ~0.029991077206645612 ~-0.05722135170475187 249:0.16666666666666666:2942:2953 31:0.1875:2943:2952 244:0.83:2944:2945 "
    s .= "~-0.050235518146437466 67:-0.265625:2946:2947 ~-0.04669698620985935 194:0.59375:2948:2951 243:2.25:2949:2950 ~0.03791825485810908 ~-0.04025558868961113 ~-0.04656394371213177 ~-0.03958680382881044 251:1.765625:2954:2959 "
    s .= "244:1.26:2955:2956 ~-0.04656177633816122 174:0.296875:2957:2958 ~-0.02859140719578491 ~0.02457237178801279 114:0.1015625:2960:2961 ~-0.049296475914042626 ~0.036662247861996546 244:0.815:2963:2964 ~-0.04558011896371607 "
    s .= "249:0.8333333333333333:2965:3000 28:0.5:2966:2997 88:1.109375:2967:2992 251:0.671875:2968:2979 255:0.265625:2969:2976 2:0.03125:2970:2975 254:0.640625:2971:2972 ~0.002510237570751207 221:0.109375:2973:2974 ~0.05139506493537856 "
    s .= "~-0.05289174943618894 ~-0.02816768599030682 122:-0.5:2977:2978 ~0.0030911957038105157 ~-0.05000029460052653 243:0.35:2980:2981 ~-0.019313305164747222 190:-0.3125:2982:2983 ~-0.03321156891602027 136:2.1875:2984:2991 "
    s .= "162:0.3671875:2985:2986 ~0.0356195812678493 251:1.609375:2987:2990 106:0.796875:2988:2989 ~-0.09238173388132145 ~0.019692504486043524 ~0.04679369583818612 ~-0.07249943013841141 90:0.1953125:2993:2996 243:1.85:2994:2995 "
    s .= "~0.04766060354580392 ~-0.05813138186117235 ~-0.029990398991888108 244:1.715:2998:2999 ~-0.04000041021958903 ~0.02895773078967287 195:0.1484375:3001:3004 63:0.3515625:3002:3003 ~-0.04397175583841752 ~0.025066326123494388 "
    s .= "244:1.07:3005:3006 ~-0.034334678204070844 29:0.046875:3007:3008 ~0.037032707294021354 ~-0.034894132963413066 244:0.815:3010:3011 ~-0.04516235435780835 232:-0.15625:3012:3019 70:-0.25:3013:3014 ~-0.05111783918344829 "
    s .= "251:1.140625:3015:3018 112:1.4375:3016:3017 ~-0.04184608926346549 ~0.010131129422508675 ~0.015669041591399823 253:-0.0607697824527861:3020:3027 55:-0.21875:3021:3024 140:0.203125:3022:3023 ~0.017580054408804866 "
    s .= "~-0.09053690983015088 256:0.8596491228070176:3025:3026 ~0.03863011224264999 ~-0.06473116432111123 251:1.109375:3028:3047 85:1.25:3029:3044 255:0.296875:3030:3039 26:0.0625:3031:3038 147:-0.2109375:3032:3033 ~-0.04698849777473568 "
    s .= "109:0.109375:3034:3035 ~-0.031899709385048255 247:0.515625:3036:3037 ~0.03402564574025726 ~-0.048265510901248365 ~-0.031058408909884257 98:-0.515625:3040:3043 113:0:3041:3042 ~-0.015057540382553206 ~0.05348441466469511 "
    s .= "~-0.0505382840352412 249:1.5:3045:3046 ~0.034693959496292025 ~-0.053644383969466004 243:1.95:3048:3055 252:0.175:3049:3054 152:0.09375:3050:3053 85:0.28125:3051:3052 ~-0.009323640816352176 ~0.04292730682400486 "
    s .= "~-0.06089544994434237 ~0.039581019641854676 ~-0.056962219748553145 26:-0.109375:3057:3086 27:-0.03125:3058:3077 62:-0.59375:3059:3068 251:0.234375:3060:3061 ~-0.04180555687418206 235:-0.15625:3062:3065 80:-1.390625:3063:3064 "
    s .= "~0.03287435881052755 ~-0.0603385435974638 73:0.5625:3066:3067 ~0.04085433673445533 ~-0.032576123893777335 193:-0.234375:3069:3070 ~-0.05949615351931789 254:1.046875:3071:3076 247:0.359375:3072:3075 251:0.296875:3073:3074 "
    s .= "~-0.027173462857256997 ~0.025490029589040453 ~-0.04864534031219434 ~-0.03835801984022096 253:-0.020833333333333925:3078:3079 ~0.03812308220285818 85:0.734375:3080:3085 109:0.109375:3081:3082 ~-0.03931656046161927 "
    s .= "52:0.296875:3083:3084 ~0.017100731616290495 ~-0.03912762168743014 ~0.033792050738594856 249:0.16666666666666666:3087:3094 31:0.1875:3088:3093 244:0.83:3089:3090 ~-0.04989907324200258 22:-0.265625:3091:3092 ~-0.03275095468234746 "
    s .= "~0.02971474318156237 ~-0.03805335889538656 251:1.765625:3095:3100 244:1.26:3096:3097 ~-0.04541387582497066 232:-0.078125:3098:3099 ~-0.04781682267456669 ~-0.002638324217267638 114:0.1640625:3101:3102 ~-0.03785944018415423 "
    s .= "~0.03923018557627819 244:0.795:3104:3105 ~-0.04874471663185839 249:0.8333333333333333:3106:3139 122:0.09375:3107:3128 99:0.0078125:3108:3123 190:-0.3125:3109:3110 ~-0.05610715636251121 157:0.8125:3111:3118 251:0.328125:3112:3113 "
    s .= "~-0.041742799784418035 145:-0.15625:3114:3115 ~-0.04528874580611515 148:0.234375:3116:3117 ~0.02956686502423745 ~-0.017142387639985154 28:0.53125:3119:3122 159:0.2421875:3120:3121 ~0.0325899381894765 ~-0.08164511288322329 "
    s .= "~-0.04387834979070002 49:0.6875:3124:3127 211:-0.078125:3125:3126 ~0.010951309305658831 ~0.03908834083556025 ~-0.04672794780393935 252:0.175:3129:3132 254:0.015625:3130:3131 ~0.020672252236962136 ~-0.0525860396876633 "
    s .= "255:0.328125:3133:3138 46:-0.21875:3134:3135 ~-0.04940494172078572 31:0.40625:3136:3137 ~0.029795657192402125 ~-0.048844570957005916 ~-0.05786431876785636 195:0.1484375:3140:3143 63:0.3515625:3141:3142 ~-0.04279629003008844 "
    s .= "~0.022724715851641375 245:2.0535714285714284:3144:3147 114:0.2265625:3145:3146 ~-0.057612348196169866 ~0.01021289547389261 29:0.09375:3148:3149 ~0.03583374804863347 ~-0.04205001835228547 244:0.795:3151:3152 ~-0.048572955871565904 "
    s .= "217:-0.140625:3153:3160 26:-0.78125:3154:3157 109:1.484375:3155:3156 ~-0.012771435822378913 ~0.056318690140465144 195:0.1953125:3158:3159 ~-0.04470114019183481 ~0.0016328108204805626 248:0.875:3161:3190 49:0.359375:3162:3185 "
    s .= "190:-0.09375:3163:3166 252:0.375:3164:3165 ~-0.03390664685488242 ~0.011265699285630745 14:-0.609375:3167:3170 160:-0.234375:3168:3169 ~-0.12206266012342165 ~0.04467449069213032 255:0.265625:3171:3176 26:0.25:3172:3173 "
    s .= "~0.036235256818323604 252:0.175:3174:3175 ~-0.05086985826119964 ~0.01821274010173604 244:1.035:3177:3180 250:1.4296875:3178:3179 ~-0.0597077682612027 ~0.02197248614677437 162:0.3203125:3181:3184 233:0.296875:3182:3183 "
    s .= "~0.02033452803963691 ~-0.057573093819882626 ~-0.077236216703663 109:1.390625:3186:3189 121:0.109375:3187:3188 ~0.0031633949123066004 ~-0.056553190004418975 ~0.019552652397825814 223:0.921875:3191:3194 251:1.578125:3192:3193 "
    s .= "~-0.03798367995514936 ~0.024282798371320597 148:0.015625:3195:3196 ~0.0902974929804898 ~-0.053305951734349925 251:0.671875:3198:3227 244:1.21:3199:3218 23:-0.640625:3200:3205 10:0.25:3201:3204 77:-0.40625:3202:3203 "
    s .= "~0.035034022503057226 ~-0.03926153815743966 ~-0.05150052800031965 250:0.9453125:3206:3217 31:0.125:3207:3216 235:-0.09375:3208:3209 ~-0.056452093424312635 255:0.234375:3210:3213 2:0.03125:3211:3212 ~0.057360192607143506 "
    s .= "~-0.027584349885929095 157:-0.3125:3214:3215 ~0.3168720416846746 ~-0.03297848606103257 ~-0.05524183480921627 ~-0.048095790784881194 202:-0.09375:3219:3220 ~-0.04152551231374531 109:0.25:3221:3222 ~-0.031626010648968673 "
    s .= "90:0.3515625:3223:3226 193:0.265625:3224:3225 ~0.03693534919695228 ~-0.020609799279759228 ~-0.07374392489705633 191:-0.046875:3228:3237 187:-0.28125:3229:3230 ~-0.029769644880569535 109:0.53125:3231:3236 137:0.5625:3232:3235 "
    s .= "100:1.09375:3233:3234 ~-0.015809418143883282 ~0.04917434728275469 ~0.054635299370837165 ~0.03562987500265496 255:0.265625:3238:3243 20:0.453125:3239:3242 236:0.625:3240:3241 ~0.024706540250932912 ~-0.04042585891498664 "
    s .= "~-0.04050717825064366 ~-0.03261440557198148 244:0.795:3245:3246 ~-0.048243045740033824 249:0.8333333333333333:3247:3276 49:0.6875:3248:3275 191:-0.03125:3249:3266 99:-0.0234375:3250:3261 157:0.8125:3251:3258 85:0.84375:3252:3257 "
    s .= "121:0.671875:3253:3256 160:1.203125:3254:3255 ~-0.03825912102546708 ~0.03578066599387126 ~0.06453778535139103 ~0.024291368584658996 28:0.5625:3259:3260 ~0.02956221959129268 ~-0.0601360325440957 211:-0.078125:3262:3265 "
    s .= "138:0.2890625:3263:3264 ~0.020053157861863753 ~-0.06701065982104214 ~0.037892448021521266 255:0.234375:3267:3272 2:0.0625:3268:3269 ~0.025194215513963038 241:0.5:3270:3271 ~-0.040329296799912734 ~0.0060296078414448645 "
    s .= "244:1.07:3273:3274 ~-0.060913235790256606 ~-0.016760464694084067 ~-0.040859573337097214 193:-0.078125:3277:3280 219:0.5546875:3278:3279 ~-0.05322097723004951 ~0.02156083883885658 244:1.16:3281:3286 109:1.1875:3282:3285 "
    s .= "238:1.109375:3283:3284 ~-0.04750148410673596 ~0.09880143084911398 ~0.015687823142024774 26:0.046875:3287:3290 148:0.203125:3288:3289 ~0.041191301922765336 ~-0.01534335032644868 ~-0.03633974420182461 244:0.795:3292:3293 "
    s .= "~-0.04806303303147766 238:-0.09375:3294:3303 251:0.765625:3295:3298 244:1.47:3296:3297 ~-0.04994706890411302 ~-0.001006228337657337 62:-0.4375:3299:3300 ~0.032009026662040904 46:-0.140625:3301:3302 ~-0.04563884029942125 "
    s .= "~0.0016931132585923819 85:1.15625:3304:3331 251:1.578125:3305:3326 255:0.296875:3306:3317 53:0.0625:3307:3316 251:0.171875:3308:3309 ~-0.035805412558867857 247:0.515625:3310:3315 254:0.671875:3311:3314 150:0.0390625:3312:3313 "
    s .= "~-0.011498513212528691 ~0.03243500018415589 ~0.05010168609401873 ~-0.06298065893446557 ~-0.021983339493401324 98:-0.53125:3318:3323 155:-0.328125:3319:3322 245:2.289855072463768:3320:3321 ~-0.044471898471112936 "
    s .= "~0.02091872275366998 ~0.03832105195075178 100:0.578125:3324:3325 ~-0.05286294147119624 ~-0.004004614697777296 243:0.6499999999999999:3327:3330 46:0.453125:3328:3329 ~-0.04975164361261477 ~0.0702084547534835 ~0.04107458881654285 "
    s .= "61:-0.296875:3332:3333 ~-0.03226734820365456 243:1.75:3334:3337 37:0.84375:3335:3336 ~0.04262779223559199 ~-0.02352010257272524 ~-0.035251269934491535 244:0.795:3339:3340 ~-0.047879502832014524 220:-0.140625:3341:3348 "
    s .= "251:0.671875:3342:3343 ~-0.04364851642759165 74:-0.765625:3344:3345 ~0.03978961103397769 196:-0.234375:3346:3347 ~-0.045122069091850014 ~0.004635548703106726 88:1.109375:3349:3380 251:1.109375:3350:3365 "
    s .= "245:1.5797101449275361:3351:3352 ~-0.0667804322951532 255:0.265625:3353:3360 2:0.0625:3354:3359 254:0.640625:3355:3356 ~0.0056152142121520315 184:0:3357:3358 ~-0.013094131379078234 ~0.05129231533434089 ~-0.02394433904135245 "
    s .= "26:-0.4375:3361:3364 235:-0.109375:3362:3363 ~-0.05246623978135001 ~0.011606043089769811 ~-0.04367595930542448 241:0.46:3366:3375 204:0.3515625:3367:3372 128:0.234375:3368:3371 130:1.9375:3369:3370 ~0.0350584225521545 "
    s .= "~-0.07175530466966801 ~-0.049528072484050896 184:0.09375:3373:3374 ~-0.11069158018088321 ~0.008089561688782906 243:1.35:3376:3377 ~0.04532306351927001 245:1.6626506024096386:3378:3379 ~-0.1080924374992486 ~0.02019591593449796 "
    s .= "121:0.703125:3381:3384 243:1.85:3382:3383 ~0.04038070348047809 ~-0.051143216814873604 ~-0.04198744190718876 244:0.795:3386:3387 ~-0.04769210477474733 249:0.8333333333333333:3388:3419 122:0.046875:3389:3408 99:0.0078125:3390:3405 "
    s .= "190:-0.3125:3391:3392 ~-0.05426749215353847 247:0.359375:3393:3404 85:1.203125:3394:3403 163:1.1875:3395:3402 163:0.546875:3396:3401 223:0.921875:3397:3400 249:0.16666666666666666:3398:3399 ~0.01907196704252281 "
    s .= "~-0.0250962024530225 ~0.08481886511567456 ~-0.04457452302981165 ~0.04419511587565575 ~0.03322795883931725 ~-0.05262390377821431 49:0.6875:3406:3407 ~0.032667888682363526 ~-0.04519515587644598 252:0.175:3409:3412 "
    s .= "254:0.046875:3410:3411 ~0.02092266407131308 ~-0.050539168269715655 255:0.328125:3413:3418 243:1.35:3414:3417 25:0.21875:3415:3416 ~0.03706914577772686 ~-0.02845312064363705 ~-0.020101976844056773 ~-0.05341202143319643 "
    s .= "193:-0.078125:3420:3421 ~-0.04680244584259382 244:1.25:3422:3429 106:0.25:3423:3428 248:0.875:3424:3427 77:-0.03125:3425:3426 ~0.04746391802877854 ~-0.0419853585485691 ~-0.051237922998030976 ~-0.046567747984694506 "
    s .= "29:0.046875:3430:3431 ~0.031470288127577274 ~-0.03519667783704572 251:0.671875:3433:3458 244:1.21:3434:3449 235:-0.09375:3435:3436 ~-0.05427262320249228 46:0.078125:3437:3448 250:0.9765625:3438:3445 55:0.09375:3439:3444 "
    s .= "184:0:3440:3441 ~-0.03106163608782349 136:-0.34375:3442:3443 ~0.3550126506451748 ~0.04134406862912929 ~-0.01925379197444736 47:-0.9375:3446:3447 ~0.04286274724278696 ~-0.04230124619685133 ~-0.04206914594313952 "
    s .= "202:-0.09375:3450:3451 ~-0.03948643795070268 109:0.25:3452:3453 ~-0.03135625917575575 90:0.3515625:3454:3457 193:0.265625:3455:3456 ~0.03484715441762939 ~-0.019846263975440002 ~-0.07055208652099397 50:-0.609375:3459:3462 "
    s .= "109:0.53125:3460:3461 ~0.004789107010919915 ~0.04331246484666755 254:1.046875:3463:3478 203:0.609375:3464:3477 232:-0.15625:3465:3468 70:-0.15625:3466:3467 ~-0.054218730406032124 ~0.001684309533185423 "
    s .= "245:1.3157894736842106:3469:3470 ~-0.0565337015199104 244:2.86:3471:3476 121:-0.125:3472:3475 152:-0.140625:3473:3474 ~0.028349642171348246 ~-0.030552669098519048 ~0.03208050543258641 ~-0.08571635279509428 ~-0.0476055855344986 "
    s .= "~-0.043549898585074194 244:0.795:3480:3481 ~-0.04734257085261197 249:0.8333333333333333:3482:3517 49:0.71875:3483:3516 191:0.28125:3484:3513 243:1.55:3485:3510 243:0.35:3486:3499 97:0.546875:3487:3494 103:0.15625:3488:3493 "
    s .= "157:0.015625:3489:3490 ~-0.04233063318987658 193:0.078125:3491:3492 ~0.03544894015248911 ~-0.029400543960190158 ~-0.0518174342871809 127:0.6875:3495:3498 33:0.1015625:3496:3497 ~0.11844137196027445 ~-0.04945388533250886 "
    s .= "~-0.06686329770785275 245:4.878048780487805:3500:3509 190:-0.3125:3501:3502 ~-0.02442320408691078 255:0.296875:3503:3504 ~0.0382647415957042 26:-0.375:3505:3506 ~0.03272153698903581 241:0.46:3507:3508 ~-0.045458143515972854 "
    s .= "~0.010301668162967209 ~-0.21803229348440728 253:-0.0607697824527861:3511:3512 ~0.017655191669352335 ~-0.03980030330976951 244:1.085:3514:3515 ~-0.05250810485128729 ~-0.001841873228421039 ~-0.04054999142606917 "
    s .= "120:0.1640625:3518:3523 41:-0.625:3519:3522 195:-0.3203125:3520:3521 ~-0.05231564726411676 ~0.035111174557026184 ~-0.04212034482024121 244:1.16:3524:3525 ~-0.023771964595976774 ~0.032623965579351814 26:-0.109375:3527:3558 "
    s .= "109:0.609375:3528:3543 168:0.0546875:3529:3536 248:0.125:3530:3533 130:0.65625:3531:3532 ~-0.04762192727959847 ~0.030379051474970505 61:0.96875:3534:3535 ~-0.043726321549355573 ~0.017619031022111858 196:-0.046875:3537:3538 "
    s .= "~-0.03022686405649872 76:0.203125:3539:3540 ~0.03219540612156096 244:1.09:3541:3542 ~-0.05660828245676555 ~0.02823232167738184 238:-0.1875:3544:3547 244:1.555:3545:3546 ~-0.029122106997933273 ~0.024028878346609623 "
    s .= "251:0.234375:3548:3551 244:1.23:3549:3550 ~-0.06163300450606973 ~0.013215318015280845 255:0.296875:3552:3553 ~0.043187872564076586 26:-0.609375:3554:3555 ~0.037027689148617086 97:-0.125:3556:3557 ~-0.04273732912206836 "
    s .= "~0.009905562187343087 249:0.16666666666666666:3559:3566 31:0.1875:3560:3565 46:-0.265625:3561:3562 ~-0.03914796942552268 244:0.83:3563:3564 ~-0.048430903163826776 ~0.026819379791143596 ~-0.034998586515263906 "
    s .= "251:1.765625:3567:3570 244:1.26:3568:3569 ~-0.04245320394020362 ~-0.016582030245739073 83:0.09375:3571:3572 ~-0.05078445486587035 ~0.030413308089227865 251:0.671875:3574:3605 235:-0.078125:3575:3578 244:1.45:3576:3577 "
    s .= "~-0.05122924556906029 ~-0.0025215038412349645 85:1.265625:3579:3604 245:1.5797101449275361:3580:3581 ~-0.05637366891250242 49:0.265625:3582:3599 248:0.875:3583:3594 190:-0.03125:3584:3585 ~-0.03220028922382533 "
    s .= "217:-0.125:3586:3587 ~-0.05082066252010327 26:0.25:3588:3593 242:0.6499999999999999:3589:3592 97:0.515625:3590:3591 ~0.028344604235061396 ~0.12506832020859468 ~-0.009688499328682505 ~-0.0454606074829041 103:-0.390625:3595:3598 "
    s .= "196:-0.0625:3596:3597 ~-0.03246274066791683 ~0.5054032744555468 ~-0.0460323559520224 193:0.15625:3600:3603 196:0.609375:3601:3602 ~-0.027624359064945137 ~0.11725500215707779 ~-0.06321026699713427 ~0.0309926477658932 "
    s .= "50:-0.609375:3606:3607 ~0.033384462737491426 255:0.265625:3608:3613 191:0.484375:3609:3612 196:-0.28125:3610:3611 ~-0.03325053495994467 ~0.028882403197286296 ~-0.026611485914017265 254:0.953125:3614:3617 125:-0.203125:3615:3616 "
    s .= "~0.018392378140088497 ~-0.02164369500016962 249:0.16666666666666666:3618:3619 ~-0.008247969672754868 ~-0.06254053847611728 244:0.795:3621:3622 ~-0.04679422203679136 187:-0.203125:3623:3624 ~-0.031724482093297875 "
    s .= "253:-0.0607697824527861:3625:3634 55:-0.21875:3626:3629 235:-0.015625:3627:3628 ~-0.07687006380243878 ~0.011047176228554495 241:0.22:3630:3633 235:0.078125:3631:3632 ~-0.09033662073190617 ~0.024924466790780746 "
    s .= "~0.035314690444287214 251:1.109375:3635:3660 85:1.25:3636:3657 243:0.55:3637:3654 109:0.109375:3638:3639 ~-0.04414904950995996 214:-0.171875:3640:3641 ~-0.06551332110405554 55:-0.578125:3642:3643 ~0.1026335283875327 "
    s .= "177:0.4453125:3644:3653 220:0.9375:3645:3652 103:0.125:3646:3649 205:0.078125:3647:3648 ~-0.016888128556067913 ~0.040549122484615174 154:0.640625:3650:3651 ~-0.03979956841140059 ~0.019144654588564403 ~0.0590781831142032 "
    s .= "~-0.06239823993309612 124:1.125:3655:3656 ~-0.03713986532661025 ~0.02952398009354473 100:-0.40625:3658:3659 ~-0.047632268530109725 ~0.026557565775937347 130:1.96875:3661:3666 243:1.95:3662:3665 23:0.5:3663:3664 "
    s .= "~0.028745266733662334 ~-0.04199861950057224 ~-0.05331246158179016 ~-0.04145900167469402 53:0.0625:3668:3703 99:0.0234375:3669:3690 193:-0.21875:3670:3673 2:-1.125:3671:3672 ~0.03448269734886553 ~-0.05062742248110205 "
    s .= "249:0.16666666666666666:3674:3677 247:0.265625:3675:3676 ~0.024027911753504237 ~-0.04647887649956628 127:0.1875:3678:3683 231:-0.0390625:3679:3682 71:-1.234375:3680:3681 ~0.06542899416561294 ~-0.02805192217075705 "
    s .= "~0.029199038304745087 238:1.109375:3684:3689 251:0.484375:3685:3686 ~-0.05862373937145418 35:-0.71875:3687:3688 ~0.02375913629483177 ~-0.0322337589339803 ~0.044655958556346576 253:-0.020833333333333925:3691:3694 "
    s .= "71:-0.03125:3692:3693 ~0.040679331146129705 ~0.006866544780053996 168:0.1484375:3695:3700 109:0.5:3696:3699 166:0.671875:3697:3698 ~-0.04542215678266207 ~0.08123329881456116 ~0.008750757856554794 25:0.3125:3701:3702 "
    s .= "~0.028486621900691424 ~-0.040754956276322946 244:1.42:3704:3709 251:1.578125:3705:3706 ~-0.04095613164686152 89:0.734375:3707:3708 ~-0.02133501331954783 ~0.05291386516664473 135:-0.0859375:3710:3711 ~0.04457157160748808 "
    s .= "252:0.32499999999999996:3712:3713 ~-0.03894900648425186 ~0.023623115121603235 244:0.795:3715:3720 190:0.875:3716:3717 ~-0.05041718829311326 136:0.078125:3718:3719 ~0.4408210699840141 ~-0.041727463306470564 187:-0.203125:3721:3722 "
    s .= "~-0.030417290474679975 122:0.25:3723:3756 251:0.515625:3724:3745 28:0.25:3725:3742 109:0.109375:3726:3729 61:0.828125:3727:3728 ~-0.05352038980196075 ~0.04488708329325011 46:0.078125:3730:3737 22:-0.265625:3731:3732 "
    s .= "~-0.030457269058301647 55:0.09375:3733:3736 160:-0.109375:3734:3735 ~-0.04800290925035142 ~0.044336129248250096 ~-0.012393912314866607 195:0.1484375:3738:3739 ~-0.04052865346227879 127:0.1875:3740:3741 ~0.04571677173653885 "
    s .= "~-0.04212375421210571 238:1.203125:3743:3744 ~-0.05041186592262679 ~0.05162178351271875 255:0.265625:3746:3747 ~0.03230086386052122 26:-0.625:3748:3751 243:1.45:3749:3750 ~0.036143186738466615 ~-0.0410066985935453 "
    s .= "254:1.046875:3752:3755 244:0.98:3753:3754 ~-0.04026344070825417 ~0.011403879552596067 ~-0.0381861833876526 252:0.275:3757:3758 ~-0.04392049870483075 248:0.375:3759:3760 ~0.014133697697916956 ~-0.03633260242326211 "
    s .= "244:0.795:3762:3767 190:0.875:3763:3764 ~-0.050372321285737126 249:1.5:3765:3766 ~-0.041453050410848756 ~0.35733818167823567 249:0.5:3768:3791 191:0.21875:3769:3790 253:-0.05:3770:3777 252:0.175:3771:3776 210:0.4453125:3772:3775 "
    s .= "36:0.0703125:3773:3774 ~-0.022314024670974514 ~0.03979030796236062 ~-0.09115186166341242 ~0.042715381606632345 243:1.55:3778:3789 193:0.328125:3779:3788 187:-0.3125:3780:3781 ~-0.04731196572800397 90:0.5546875:3782:3787 "
    s .= "245:4.017543859649122:3783:3786 255:0.296875:3784:3785 ~0.03504268417817634 ~0.011021623718850607 ~-0.08628942913168117 ~-0.06772644769675866 ~-0.02297586644730383 ~-0.0390134210588761 ~-0.015287518041229249 "
    s .= "219:0.1796875:3792:3801 17:-0.609375:3793:3794 ~0.007273418392387924 96:0.0859375:3795:3796 ~-0.05229603669347463 196:-0.078125:3797:3798 ~-0.05723648576129037 197:0.0625:3799:3800 ~0.02629508971625415 ~-0.03910545892642905 "
    s .= "245:1.6551724137931034:3802:3803 ~-0.05865798560693713 53:0.046875:3804:3807 202:-0.109375:3805:3806 ~-0.0385376095908037 ~0.03239360757451649 ~-0.019053488800320706 251:0.484375:3809:3830 244:1.21:3810:3825 55:0.09375:3811:3824 "
    s .= "250:0.9765625:3812:3823 235:-0.09375:3813:3814 ~-0.053036734918556594 133:0.75:3815:3822 25:0.109375:3816:3821 97:0.546875:3817:3820 145:0.109375:3818:3819 ~0.04977376986618673 ~-0.049475572987752375 ~0.14142101588899392 "
    s .= "~-0.050435819857665744 ~-0.029610962255524145 ~-0.04600586992716545 ~-0.049606680556925936 202:-0.09375:3826:3827 ~-0.05393773077178243 109:0.109375:3828:3829 ~-0.05492593878116954 ~0.01988463889732118 38:-0.671875:3831:3832 "
    s .= "~0.032352804086272745 255:0.265625:3833:3844 203:0.609375:3834:3843 172:-0.296875:3835:3836 ~-0.033412824864085804 71:0.203125:3837:3838 ~0.03250151028352174 252:0.32499999999999996:3839:3842 210:0.4296875:3840:3841 "
    s .= "~-0.0077667758075524495 ~-0.0954803081290085 ~0.023336905427142784 ~-0.04402765998083292 244:0.99:3845:3846 ~-0.04659419180263588 254:0.953125:3847:3850 235:-0.171875:3848:3849 ~-0.03858632722575878 ~0.015608445321332494 "
    s .= "247:0.234375:3851:3854 253:-0.043604651162790255:3852:3853 ~0.023136550761205795 ~-0.03500855219293811 ~-0.07151309825887109 244:0.795:3856:3861 190:0.875:3857:3858 ~-0.0502959201798876 139:-0.09375:3859:3860 ~0.2961265457924834 "
    s .= "~-0.040891062425632396 217:-0.125:3862:3867 17:-0.78125:3863:3864 ~0.023829021103610834 251:1.390625:3865:3866 ~-0.03759188099555193 ~0.006773376489586354 88:1.109375:3868:3897 193:0.15625:3869:3882 190:-0.203125:3870:3871 "
    s .= "~-0.045617303777738163 119:0.109375:3872:3879 255:0.296875:3873:3874 ~0.03495627309481587 98:-0.53125:3875:3876 ~0.024143516401206405 254:1.265625:3877:3878 ~0.000019794892313189152 ~-0.0658693849803544 252:0.125:3880:3881 "
    s .= "~-0.039096468066090996 ~0.010096304584356251 199:0.9375:3883:3896 244:1.085:3884:3887 82:0.3125:3885:3886 ~-0.015980931719105074 ~-0.0646944412962408 91:0.171875:3888:3891 151:0.640625:3889:3890 ~-0.0393359280732174 "
    s .= "~0.026443621951081905 250:0.8046875:3892:3895 109:1.0625:3893:3894 ~-0.10844244093793559 ~0.01850266055980254 ~0.027249247829746494 ~0.03212909546086096 70:0.53125:3898:3901 248:1.125:3899:3900 ~0.039091899147379115 "
    s .= "~-0.0508373917576348 ~-0.033236234958968526 251:0.671875:3903:3930 235:-0.078125:3904:3907 244:1.45:3905:3906 ~-0.05002447902826205 ~-0.0009993445799584815 85:1.265625:3908:3927 245:1.5797101449275361:3909:3910 "
    s .= "~-0.0563739799359849 242:0.6499999999999999:3911:3922 195:-0.0546875:3912:3913 ~-0.024424174790713002 26:0.046875:3914:3921 214:-0.046875:3915:3916 ~-0.06754819457741691 136:0.65625:3917:3918 ~0.048053497219237226 "
    s .= "156:0.2265625:3919:3920 ~0.01814950272049599 ~-0.065138632812156 ~-0.025999362208185307 202:0.109375:3923:3926 85:0.609375:3924:3925 ~-0.03555976837171103 ~0.029616000633325215 ~-0.056689959032677206 151:-0.125:3928:3929 "
    s .= "~-0.051407861739477284 ~0.03477032870028282 191:-0.046875:3931:3942 202:-0.046875:3932:3937 181:0.1875:3933:3934 ~-0.02776239319386639 112:-0.203125:3935:3936 ~-0.05586671580173519 ~0.028363079018746625 142:-0.171875:3938:3941 "
    s .= "154:0.953125:3939:3940 ~-0.03682746876569424 ~0.04353584181697485 ~0.03069659916775154 255:0.265625:3943:3946 20:0.453125:3944:3945 ~0.015714047513559704 ~-0.036690935729439926 244:1.07:3947:3948 ~-0.06177636010826736 "
    s .= "~-0.013719367623781197 109:0.609375:3950:3973 251:1.578125:3951:3970 2:0.046875:3952:3969 249:0.5:3953:3962 133:0.03125:3954:3955 ~0.038296372618214426 13:0.9375:3956:3961 112:1.625:3957:3960 217:0.765625:3958:3959 "
    s .= "~-0.025867531491763476 ~0.05724599134873031 ~0.04323447868532168 ~0.06695733001925254 241:0.1:3963:3966 115:0.40625:3964:3965 ~-0.020788093868070998 ~0.11263835580041243 220:0.984375:3967:3968 ~-0.04455034963437663 "
    s .= "~0.05047009275354741 ~-0.04476627015261194 169:0.46875:3971:3972 ~0.023759234913485337 ~-0.07145263456801584 235:-0.1875:3974:3979 244:1.505:3975:3976 ~-0.03519916467876228 1:-0.15625:3977:3978 ~-0.04369608228494448 "
    s .= "~0.03596365318069513 253:-0.055555555555561874:3980:3987 241:0.24:3981:3984 235:0.078125:3982:3983 ~-0.11653637565935447 ~0.010217341364106652 140:0.328125:3985:3986 ~0.041990916600310985 ~-0.015403582090156421 "
    s .= "217:0.203125:3988:3993 193:-0.109375:3989:3990 ~-0.02185324361767649 130:2.46875:3991:3992 ~0.02376108114462799 ~-0.11485878408255863 251:1.265625:3994:3995 ~-0.0337180122471717 ~0.020550399194191007 251:0.484375:3997:4022 "
    s .= "112:1.1875:3998:4019 250:0.9765625:3999:4018 31:0.078125:4000:4013 145:0.109375:4001:4008 235:-0.09375:4002:4003 ~-0.05029307366782008 195:-0.0390625:4004:4005 ~-0.025904143889560624 53:0.03125:4006:4007 ~0.05285102632659151 "
    s .= "~-0.008904167195825301 100:0.578125:4009:4010 ~-0.06242227989779556 100:0.640625:4011:4012 ~0.10252879432203732 ~-0.05139459533414639 196:0.609375:4014:4015 ~-0.04900354372739942 169:0.203125:4016:4017 ~0.0913542294238159 "
    s .= "~-0.05369093453443268 ~-0.04541591966459781 202:-0.0625:4020:4021 ~-0.03718610975245357 ~0.023192210404578608 38:-0.671875:4023:4024 ~0.03058973537713612 255:0.265625:4025:4032 203:0.609375:4026:4031 172:-0.296875:4027:4028 "
    s .= "~-0.031730653411846645 2:0.09375:4029:4030 ~0.030389732319510476 ~0.0015389825709141614 ~-0.04256777348009346 244:0.99:4033:4034 ~-0.044799317079261915 254:0.953125:4035:4038 235:-0.140625:4036:4037 ~-0.03307105544304426 "
    s .= "~0.014615140868622582 247:0.234375:4039:4042 90:-0.1328125:4040:4041 ~-0.04812433597833151 ~0.005085180968356125 ~-0.06994027035465848 248:0.375:4044:4073 31:0.25:4045:4068 252:0.175:4046:4057 47:0:4047:4052 "
    s .= "242:0.6499999999999999:4048:4051 133:2.40625:4049:4050 ~0.02386154319703959 ~-0.11243926986327722 ~-0.03336680395084472 254:0.046875:4053:4054 ~0.03247870380017443 131:0.0625:4055:4056 ~-0.014897481868842433 ~-0.07768316626191397 "
    s .= "253:-0.05317460317460308:4058:4059 ~0.045022676773683275 243:1.55:4060:4065 251:0.921875:4061:4064 244:1.26:4062:4063 ~-0.03923435796172318 ~0.0294579120344986 ~0.045504605578651255 3:0.2109375:4066:4067 ~-0.06069092159758082 "
    s .= "~0.02255657815692461 244:1.58:4069:4072 154:0.953125:4070:4071 ~-0.0502580133880318 ~0.0005523233958302965 ~0.02082140857260424 2:0.0625:4074:4089 121:-0.21875:4075:4076 ~-0.04386245322244559 121:0.21875:4077:4088 "
    s .= "88:0.328125:4078:4085 91:0.140625:4079:4082 205:0.6875:4080:4081 ~-0.03485477813296408 ~0.039212533577222264 252:0.07500000000000001:4083:4084 ~0.05344557819977347 ~-0.03309637977628829 118:0.234375:4086:4087 ~0.0447703017805487 "
    s .= "~-0.013093962851751451 ~-0.02551065068989074 ~-0.03558351629679295 122:0.25:4091:4130 251:0.515625:4092:4111 220:-0.140625:4093:4094 ~-0.0423056845775755 28:0.25:4095:4108 109:0.109375:4096:4097 ~-0.03972926931485843 "
    s .= "245:1.5797101449275361:4098:4099 ~-0.06309008484272408 46:0.078125:4100:4103 22:-0.265625:4101:4102 ~-0.026412422316179962 ~0.03186756492855981 76:-0.078125:4104:4105 ~-0.07777519419446671 127:0.1875:4106:4107 "
    s .= "~0.03585140401152397 ~-0.03141540629927714 238:1.203125:4109:4110 ~-0.050495963694049295 ~0.04340011037755659 249:0.16666666666666666:4112:4115 133:2.40625:4113:4114 ~0.029021748374096847 ~-0.06759544456211304 41:-0.625:4116:4119 "
    s .= "122:-0.390625:4117:4118 ~0.036101214769566944 ~-0.012622820797122467 96:0.0859375:4120:4123 205:0.640625:4121:4122 ~-0.03200431600287731 ~0.01628538528687667 55:-0.21875:4124:4125 ~-0.03597282793738376 238:0.234375:4126:4129 "
    s .= "190:-0.03125:4127:4128 ~-0.010706458491829858 ~0.037518072833529294 ~-0.022093809040959835 252:0.275:4131:4132 ~-0.0435603728026387 244:1.405:4133:4136 251:1.703125:4134:4135 ~-0.037870700190105334 ~0.020066407201777436 "
    s .= "~0.024284840524726174 253:-0.05829228243021589:4138:4151 140:0.09375:4139:4144 109:0.609375:4140:4143 232:0.296875:4141:4142 ~0.01189353698026101 ~-0.06298902791266411 ~0.03501079943735399 242:0.35:4145:4146 ~-0.08718903083139416 "
    s .= "40:-0.25:4147:4148 ~-0.05004527748786844 244:0.98:4149:4150 ~-0.030074734106228164 ~0.026934167431036785 26:0.265625:4152:4183 187:-0.203125:4153:4154 ~-0.03507371268129089 255:0.296875:4155:4168 251:0.203125:4156:4157 "
    s .= "~-0.027429012371235198 254:0.703125:4158:4163 157:0.8125:4159:4162 242:0.55:4160:4161 ~0.0140909861986823 ~-0.020688444141854626 ~0.025214088713124208 244:0.855:4164:4167 211:0.03125:4165:4166 ~0.19214979730583348 "
    s .= "~-0.03406836475992496 ~0.03297767280889288 53:-0.375:4169:4180 52:0.640625:4170:4179 191:-0.828125:4171:4172 ~0.029162816171796408 246:-0.828125:4173:4176 109:1.09375:4174:4175 ~-0.06181297326989743 ~0.008463695333756918 "
    s .= "121:-0.109375:4177:4178 ~-0.04834362654929548 ~0.021363942614146966 ~-0.03832903096504266 254:0.765625:4181:4182 ~0.004205135925740313 ~-0.04244976975274271 ~-0.036609257414014794 244:0.795:4185:4190 190:0.875:4186:4187 "
    s .= "~-0.050085297201330606 136:0.078125:4188:4189 ~0.237670237036577 ~-0.03916383339591638 249:0.8333333333333333:4191:4222 49:0.71875:4192:4221 245:4.017543859649122:4193:4220 97:-0.25:4194:4197 176:-0.296875:4195:4196 "
    s .= "~0.014107000379538796 ~-0.041631272807868026 88:1.109375:4198:4217 251:1.109375:4199:4210 247:0.515625:4200:4209 255:0.265625:4201:4206 122:0.0625:4202:4203 ~0.030380802852463015 103:0.5:4204:4205 ~-0.03883145769617665 "
    s .= "~0.02141763291509926 2:-0.359375:4207:4208 ~0.005472427344101717 ~-0.03603051990385992 ~-0.04794847832146176 241:0.46:4211:4216 190:0.015625:4212:4215 181:0.109375:4213:4214 ~-0.08785023516819081 ~0.002621764846534633 "
    s .= "~0.02308075474588504 ~0.038026335254708436 90:0.4765625:4218:4219 ~0.03909063440174586 ~-0.07008189288121146 ~-0.09388234013389632 ~-0.03932753863010697 251:1.234375:4223:4228 217:-0.09375:4224:4225 ~-0.053175549414830006 "
    s .= "38:0.078125:4226:4227 ~-0.004350761652375748 ~-0.05340846123680139 245:1.6551724137931034:4229:4230 ~-0.05430157941647317 ~0.02029058159006289 109:0.609375:4232:4251 251:1.578125:4233:4246 47:0.1875:4234:4245 "
    s .= "168:0.0546875:4235:4236 ~-0.026748806385099147 242:0.75:4237:4244 46:0.09375:4238:4243 115:0.203125:4239:4242 222:0.0703125:4240:4241 ~0.04542189127684283 ~-0.027318239439761773 ~0.05609784120712424 ~-0.03291890882331407 "
    s .= "~-0.022918368467141417 ~-0.04567918254217751 138:0.1328125:4247:4250 208:-0.0625:4248:4249 ~-0.0968721815326356 ~0.0033193738922020176 ~0.03452437510681167 235:-0.1875:4252:4257 244:1.58:4253:4254 ~-0.031555789213167255 "
    s .= "49:-0.203125:4255:4256 ~-0.0595023360260618 ~0.04135422881350816 217:0.421875:4258:4275 248:1.125:4259:4274 133:2.40625:4260:4273 193:-0.109375:4261:4264 175:0.765625:4262:4263 ~0.005922884124015709 ~-0.062089485537123956 "
    s .= "88:1.109375:4265:4272 254:1.078125:4266:4267 ~0.02360795278574572 53:-0.953125:4268:4269 ~0.031568137812976474 244:1.46:4270:4271 ~-0.06597141135297525 ~0.011976386008729016 ~0.04216860268228511 ~-0.07057067687922998 "
    s .= "~-0.026665502877713312 34:-0.515625:4276:4277 ~0.050010971845727364 ~-0.03700995077744858 251:0.671875:4279:4306 256:0.2111111111111111:4280:4305 238:-0.203125:4281:4282 ~-0.042147734574768704 49:0.21875:4283:4298 "
    s .= "109:0.109375:4284:4287 61:0.234375:4285:4286 ~-0.04704598933051582 ~0.032518724685330846 46:0.078125:4288:4291 64:-0.375:4289:4290 ~-0.056955223359572926 ~0.024368577189720426 160:0.90625:4292:4297 88:0.828125:4293:4296 "
    s .= "10:-0.578125:4294:4295 ~0.1454507164020679 ~-0.04828460190718165 ~0.019763644337958842 ~0.030602706106205788 241:0.16:4299:4304 196:0.609375:4300:4301 ~-0.024877776118315237 145:0.46875:4302:4303 ~0.10871248492232047 "
    s .= "~-0.04679181412142855 ~-0.04860680894208512 ~-0.05295879633334402 50:-0.609375:4307:4310 243:0.35:4308:4309 ~-0.02304321862938889 ~0.03364586288421664 254:1.046875:4311:4324 46:-0.21875:4312:4315 63:-0.2109375:4313:4314 "
    s .= "~0.03306656233490587 ~-0.03153050524476742 245:1.3157894736842106:4316:4317 ~-0.049919605739836094 245:3.8275862068965516:4318:4323 203:0.671875:4319:4322 118:0.296875:4320:4321 ~0.026955092915619278 ~-0.00448939073903807 "
    s .= "~-0.05643042337088383 ~-0.087115241997147 ~-0.03861601356827829 249:0.16666666666666666:4326:4341 253:-0.05:4327:4328 ~0.031004363815260307 243:1.65:4329:4340 73:0.203125:4330:4337 64:-0.25:4331:4332 ~-0.03794773819271083 "
    s .= "90:0.4140625:4333:4336 193:0.515625:4334:4335 ~0.02869966965267298 ~-0.04933296957344763 ~-0.03851582532126076 76:0.53125:4338:4339 ~-0.0035196954126214736 ~-0.059606026445707595 ~-0.04127315686182404 26:-0.0625:4342:4367 "
    s .= "99:-0.1015625:4343:4350 160:1.140625:4344:4349 235:1.328125:4345:4348 174:-0.15625:4346:4347 ~-0.05587866418909492 ~-0.01817753922754329 ~0.04570257597913918 ~0.011627726111174339 245:1.5797101449275361:4351:4354 "
    s .= "89:0.609375:4352:4353 ~-0.07218446303708202 ~0.026807181704785455 190:-0.015625:4355:4360 168:0.1484375:4356:4357 ~-0.03374181553838423 31:-0.140625:4358:4359 ~0.05276469066914 ~-0.018302526216657334 193:0.15625:4361:4362 "
    s .= "~0.030802969125410057 71:-0.0625:4363:4366 113:0.078125:4364:4365 ~-0.004137564678589272 ~0.05894442283039906 ~-0.051261850787808344 251:1.421875:4368:4369 ~-0.03326956676246336 141:0.1171875:4370:4371 ~-0.03596547082842138 "
    s .= "~0.02123229184550671 122:0.25:4373:4416 187:-0.3125:4374:4375 ~-0.03542054128560581 251:0.515625:4376:4397 28:0.25:4377:4394 109:0.109375:4378:4379 ~-0.03947174278012843 46:0.078125:4380:4389 184:0:4381:4382 ~-0.02029804204400354 "
    s .= "55:0.09375:4383:4386 214:-0.09375:4384:4385 ~-0.04034630356546723 ~0.041921301986048064 130:1.015625:4387:4388 ~-0.04261592820025677 ~0.0384670900923374 76:-0.015625:4390:4391 ~-0.0630226434619681 127:0.1875:4392:4393 "
    s .= "~0.028275726237617482 ~-0.034874382552338996 238:1.203125:4395:4396 ~-0.046980430161336025 ~0.04144930702342123 255:0.265625:4398:4401 205:-0.25:4399:4400 ~-0.021054298814652747 ~0.029040896254498266 26:-0.625:4402:4407 "
    s .= "109:0.5625:4403:4406 242:1.15:4404:4405 ~0.011151990870853248 ~-0.07174558593631529 ~0.03634997802042155 254:0.953125:4408:4413 140:-0.125:4409:4410 ~0.018586495313834234 251:1.703125:4411:4412 ~-0.04022419748457271 "
    s .= "~0.028831011468065666 249:0.16666666666666666:4414:4415 ~-0.0006449113399020706 ~-0.05273377183375763 252:0.275:4417:4418 ~-0.041583958494024534 ~-0.00940327005773345 253:-0.0607697824527861:4420:4439 252:0.275:4421:4434 "
    s .= "26:-0.03125:4422:4433 242:0.95:4423:4432 82:0.328125:4424:4427 244:1.91:4425:4426 ~0.0424594145653772 ~-0.08780576623388858 255:0.234375:4428:4429 ~0.02714191834185284 122:-0.484375:4430:4431 ~0.009951102664104669 "
    s .= "~-0.0758831070309651 ~-0.07753485039506604 ~-0.045637658886117594 238:0.53125:4435:4438 256:0.8333333333333334:4436:4437 ~0.04000299788042276 ~-0.04940973622172419 ~-0.05679378873907162 26:0.265625:4440:4465 "
    s .= "187:-0.203125:4441:4442 ~-0.032725583745452716 255:0.296875:4443:4454 251:0.203125:4444:4447 250:0.5859375:4445:4446 ~0.07551291428549861 ~-0.03442005623695972 254:0.703125:4448:4451 157:0.8125:4449:4450 ~-0.0037045523500717765 "
    s .= "~0.023301582787776456 244:0.85:4452:4453 ~0.1305445114068787 ~0.031470913749565774 53:-0.375:4455:4462 52:0.640625:4456:4461 191:-0.828125:4457:4458 ~0.027470567043019728 246:-0.828125:4459:4460 ~-0.030817547022262578 "
    s .= "~0.009337059659831719 ~-0.03635974178837668 254:0.765625:4463:4464 ~0.00426212065907713 ~-0.03973698950807428 ~-0.03431991358242381 249:0.16666666666666666:4467:4478 253:-0.05:4468:4469 ~0.02973598673137204 243:1.65:4470:4477 "
    s .= "1:0.28125:4471:4476 130:2.46875:4472:4475 183:0.5234375:4473:4474 ~0.01819069097410547 ~-0.0632055419181769 ~-0.11265140318079946 ~-0.027649333319971287 ~-0.03972269320399261 26:-0.609375:4479:4486 123:-0.3046875:4480:4481 "
    s .= "~-0.028117034058287443 119:-0.484375:4482:4483 ~0.03351754036201207 85:1.1875:4484:4485 ~-0.023046941511489595 ~0.03860808334053689 219:0.2578125:4487:4508 196:-0.125:4488:4489 ~-0.04888721729829751 127:0.140625:4490:4501 "
    s .= "88:0.171875:4491:4494 103:0.125:4492:4493 ~-0.043666363330619073 ~0.014254874201927267 214:0.609375:4495:4498 253:-0.05829228243021589:4496:4497 ~0.04699993447839689 ~-0.02071575655306258 178:-0.0625:4499:4500 "
    s .= "~0.19489848645397487 ~0.03959783449654154 22:0.078125:4502:4505 252:0.42500000000000004:4503:4504 ~-0.06170871791773663 ~-0.014988944194654375 238:1.203125:4506:4507 ~-0.01963562900908803 ~0.06513470365343178 "
    s .= "133:0.609375:4509:4510 ~-0.027815159744991054 208:-0.328125:4511:4512 ~-0.06855655001090152 ~0.022545338662157646 256:0.9583333333333334:4514:4559 49:0.359375:4515:4552 145:-0.171875:4516:4521 17:-0.78125:4517:4520 "
    s .= "222:-0.2109375:4518:4519 ~-0.09193846468633317 ~0.042623784589521756 ~-0.031307932820094544 252:0.275:4522:4545 190:0.015625:4523:4534 91:0.390625:4524:4531 226:0.59375:4525:4530 34:-0.125:4526:4527 ~-0.008332913444406547 "
    s .= "106:-0.71875:4528:4529 ~0.09039061686987424 ~-0.063061136391371 ~0.019228332134506768 1:0.0625:4532:4533 ~-0.03446474692199654 ~0.036287248817932063 122:0.25:4535:4544 73:0.625:4536:4543 242:0.55:4537:4540 97:0.546875:4538:4539 "
    s .= "~0.020820642147123838 ~0.07709703807148074 70:0.46875:4541:4542 ~0.005772366854460596 ~-0.0829773121263986 ~-0.0615073568806541 ~-0.03571100552746007 253:-0.043604651162790255:4546:4547 ~0.039601806914210634 "
    s .= "251:1.484375:4548:4551 133:0.90625:4549:4550 ~-0.04125886378115714 ~0.015430945107771588 ~0.03610054378891044 244:1.715:4553:4558 103:0.578125:4554:4557 109:0.671875:4555:4556 ~-0.04630563406612184 ~0.007107627186034741 "
    s .= "~-0.05751425039996527 ~0.015799371618101268 ~-0.050161531099251755 251:0.671875:4561:4584 256:0.2111111111111111:4562:4583 217:-0.125:4563:4566 65:-0.890625:4564:4565 ~0.01421254773149927 ~-0.04651785670563277 "
    s .= "169:0.15625:4567:4576 88:0.5:4568:4573 55:-0.140625:4569:4570 ~0.03356881781695734 238:0.96875:4571:4572 ~-0.020079744476679786 ~0.04636472382020859 76:-0.28125:4574:4575 ~-0.05435511035654505 ~0.03635570363785277 "
    s .= "112:1.296875:4577:4582 79:-0.234375:4578:4581 241:0.12:4579:4580 ~0.13441175389119822 ~-0.0193471881458676 ~-0.04714136725286198 ~0.026671091603340448 ~-0.052496710302077136 191:-0.046875:4585:4598 34:0.796875:4586:4597 "
    s .= "208:0:4587:4592 252:0.32499999999999996:4588:4591 204:0.3515625:4589:4590 ~-0.003606997529108004 ~-0.07788733420378664 ~0.027871152170543225 109:0.53125:4593:4596 121:0.1875:4594:4595 ~0.018985704979227684 ~-0.038510669757520384 "
    s .= "~0.03534933375064609 ~-0.045307471592545175 43:-0.171875:4599:4600 ~-0.03627975577170941 243:0.75:4601:4604 166:0.8125:4602:4603 ~-0.033531495055495096 ~0.04220795148023063 235:0.171875:4605:4606 ~0.023870249275382498 "
    s .= "~-0.02875607256298683 256:0.9583333333333334:4608:4653 49:0.359375:4609:4646 145:-0.171875:4610:4619 102:-0.8671875:4611:4612 ~0.05271999996736807 3:0.1796875:4613:4616 244:1.44:4614:4615 ~-0.055422837439192366 "
    s .= "~-0.014017188647564094 73:-0.09375:4617:4618 ~0.02663580248626736 ~-0.049764862987745 252:0.275:4620:4639 190:0.015625:4621:4632 91:0.390625:4622:4627 82:-0.09375:4623:4626 202:0.171875:4624:4625 ~-0.02991140446035666 "
    s .= "~0.061293201242447894 ~-0.0476894620321582 106:0.5:4628:4631 151:0.546875:4629:4630 ~0.044691395840726504 ~-0.0678664728121343 ~-0.04234505955860985 122:0.25:4633:4638 73:0.625:4634:4637 243:1.55:4635:4636 ~0.017875653863511195 "
    s .= "~-0.10995270098704056 ~-0.060526283192091315 ~-0.03429393775581314 253:-0.043604651162790255:4640:4641 ~0.03864807613748686 251:1.484375:4642:4645 133:0.90625:4643:4644 ~-0.039749373100145785 ~0.0143758473463792 "
    s .= "~0.03485610770777432 244:1.11:4647:4648 ~-0.04276831266285919 46:0.453125:4649:4650 ~-0.0228998984351969 70:0.609375:4651:4652 ~0.05305054093694503 ~-0.03877393093048575 ~-0.04970728236447604 249:0.5:4655:4682 "
    s .= "191:0.28125:4656:4679 255:0.234375:4657:4662 243:2.1500000000000004:4658:4661 254:0.453125:4659:4660 ~0.01708629507922375 ~0.041758396159182753 ~-0.04152206891824997 26:-0.375:4663:4674 85:1.25:4664:4673 190:-0.03125:4665:4668 "
    s .= "202:0.546875:4666:4667 ~-0.042187751463162115 ~0.03922344996662154 158:-0.28125:4669:4672 247:-0.171875:4670:4671 ~0.013087069335646554 ~-0.044611968521844424 ~0.034692510700897836 ~0.032499664000921163 244:1.48:4675:4676 "
    s .= "~-0.03563629664303219 106:0.328125:4677:4678 ~-0.056396150445612185 ~0.019113900418643994 244:1.415:4680:4681 ~-0.035061531810551716 ~0.008524522820561327 245:1.690721649484536:4683:4686 87:0.2109375:4684:4685 "
    s .= "~-0.06521891086142309 ~-0.014939590243286772 235:-0.15625:4687:4690 27:0.375:4688:4689 ~-0.052746881272262486 ~0.01058585056125814 127:0.1875:4691:4698 26:0.09375:4692:4697 251:0.203125:4693:4694 ~-0.036093999947371745 "
    s .= "25:0.25:4695:4696 ~0.03899112529044482 ~-0.03423064046792785 ~-0.034365435210246174 222:0.3515625:4699:4700 ~-0.02841253383807354 ~0.019036992928253702 251:1.109375:4702:4729 256:0.38461538461538464:4703:4728 "
    s .= "88:1.203125:4704:4723 187:-0.171875:4705:4706 ~-0.04187244264067992 255:0.296875:4707:4712 254:0.671875:4708:4709 ~-0.007003382472933329 251:0.203125:4710:4711 ~-0.022064141896694686 ~0.03219804780288379 5:-0.546875:4713:4714 "
    s .= "~0.0020622792628102295 241:0.12:4715:4720 154:0.390625:4716:4717 ~-0.03518432200674571 157:0.5625:4718:4719 ~0.08213977856874344 ~-0.03355985256860049 103:1.203125:4721:4722 ~-0.051702176220160656 ~0.001084540414398961 "
    s .= "64:-0.3125:4724:4725 ~-0.04532835671771027 31:0.578125:4726:4727 ~0.03576721907873872 ~-0.0440100173861968 ~-0.04992586570611504 241:0.46:4730:4739 41:-0.0625:4731:4736 178:-0.09375:4732:4733 ~-0.05733647384429158 "
    s .= "118:0.65625:4734:4735 ~0.029285224544590777 ~-0.09587671253531072 250:0.7734375:4737:4738 ~0.02511027749095466 ~-0.05710556176043061 214:0.453125:4740:4747 243:1.35:4741:4742 ~0.03938258084422571 245:1.6626506024096386:4743:4744 "
    s .= "~-0.06942457180820102 28:0.3125:4745:4746 ~0.028828611275001078 ~-0.0703537580708529 ~-0.05001685232590034 122:0.25:4749:4790 251:0.515625:4750:4769 250:0.9765625:4751:4764 148:0.21875:4752:4761 220:-0.140625:4753:4754 "
    s .= "~-0.034938939125231015 37:0.0625:4755:4756 ~0.029723449101273853 112:0.59375:4757:4758 ~-0.048581701866773803 145:-0.046875:4759:4760 ~-0.07836926224516477 ~0.03707945522629826 104:0.234375:4762:4763 ~-0.032593366958005784 "
    s .= "~0.042706774443059585 245:2.4153846153846152:4765:4766 ~-0.043166719166251345 226:0.109375:4767:4768 ~-0.03405730552180813 ~0.03327576933993239 249:0.16666666666666666:4770:4773 133:2.40625:4771:4772 ~0.025150806821708022 "
    s .= "~-0.06358532782426889 157:1.046875:4774:4785 44:-0.09375:4775:4778 123:-0.0078125:4776:4777 ~-0.017165561810935356 ~0.020151166197255238 178:0.234375:4779:4784 160:0.09375:4780:4781 ~-0.04509711907997834 49:0.09375:4782:4783 "
    s .= "~0.027785189948042396 ~-0.04007500735224667 ~-0.04775276745403739 191:-0.203125:4786:4787 ~0.03505260095946759 245:2.0793650793650795:4788:4789 ~0.04019376711738646 ~-0.026083523882919558 86:0.84375:4791:4794 112:1.0625:4792:4793 "
    s .= "~-0.03811519157123453 ~0.00005424841628381416 ~0.014108395536469781 256:0.9583333333333334:4796:4841 49:0.359375:4797:4832 145:-0.171875:4798:4803 102:-0.8671875:4799:4800 ~0.05188148727951955 3:0.1015625:4801:4802 "
    s .= "~-0.040484528250436386 ~0.000344911540020537 252:0.275:4804:4827 190:0.015625:4805:4814 217:0.609375:4806:4813 202:0.625:4807:4812 192:0.3046875:4808:4809 ~-0.05437822149818 58:0.375:4810:4811 ~0.022662091981110993 "
    s .= "~-0.09507134993910515 ~0.02412853283061106 ~0.03264968836956734 122:0.25:4815:4826 242:0.55:4816:4817 ~0.020622805932100977 160:0.40625:4818:4821 253:-0.1352941176470594:4819:4820 ~0.03343476399944948 ~-0.05615805070915371 "
    s .= "75:0.1171875:4822:4825 79:0.734375:4823:4824 ~-0.037234825822232025 ~0.04095690127220547 ~0.038013674331294295 ~-0.03212114453688569 118:0.28125:4828:4831 208:-0.21875:4829:4830 ~-0.012106640843714043 ~0.034405801804024 "
    s .= "~-0.004818614641966052 244:1.715:4833:4840 103:0.578125:4834:4839 109:0.671875:4835:4836 ~-0.04411012921989043 118:0.4375:4837:4838 ~-0.014927548423398477 ~0.04343830482148023 ~-0.05526221751858256 ~0.01441495382357948 "
    s .= "~-0.04893945470188425 251:0.484375:4843:4868 250:0.9765625:4844:4865 148:0.21875:4845:4858 217:-0.109375:4846:4847 ~-0.03163285428985926 223:0.515625:4848:4857 91:0.75:4849:4856 223:-0.1875:4850:4851 ~0.054745156575353 "
    s .= "243:0.6499999999999999:4852:4855 250:0.6015625:4853:4854 ~0.039198801198833205 ~-0.04099511971155273 ~0.024593525918067113 ~0.05108336017628062 ~0.06294828693886743 251:0.109375:4859:4862 244:1.08:4860:4861 ~-0.043212183259665 "
    s .= "~0.10618943673265338 202:0.90625:4863:4864 ~-0.04534224182556679 ~0.03007246428558132 245:2.425531914893617:4866:4867 ~-0.043549619283079384 ~0.009932716383180006 143:0.140625:4869:4882 202:-0.046875:4870:4873 "
    s .= "245:3.8275862068965516:4871:4872 ~-0.0038873363886324855 ~-0.09142170447708353 255:0.265625:4874:4877 32:0.390625:4875:4876 ~0.032825300875310014 ~-0.022475998368028233 122:-0.3125:4878:4881 34:0.859375:4879:4880 "
    s .= "~0.022487783447376283 ~-0.05037529448482708 ~-0.018697245028909192 46:-0.125:4883:4884 ~-0.039597695160988045 244:1:4885:4886 ~-0.0356399191040316 226:0.28125:4887:4888 ~0.013694081920793931 ~-0.04176554886820387 "
    s .= "249:0.16666666666666666:4890:4903 253:-0.0607697824527861:4891:4892 ~0.028818221352668507 31:0.15625:4893:4900 4:-0.25:4894:4895 ~-0.025883388185407426 130:2.46875:4896:4899 1:0.265625:4897:4898 ~0.02349407038710627 "
    s .= "~-0.03490437463219397 ~-0.08760423001660732 90:0.0859375:4901:4902 ~-0.0011443485006641183 ~-0.05220948773529202 190:-0.1875:4904:4907 109:1.671875:4905:4906 ~-0.04765003886442458 ~0.004150164597702545 26:-0.609375:4908:4913 "
    s .= "102:-0.3984375:4909:4912 223:-0.359375:4910:4911 ~0.048968516615655176 ~-0.047552063357109695 ~0.0235879164518261 254:1.078125:4914:4935 245:1.6219512195121952:4915:4918 113:0.625:4916:4917 ~-0.06024398468803645 "
    s .= "~0.001556365297881751 219:0.2890625:4919:4932 196:-0.125:4920:4921 ~-0.04496954136684523 246:-0.671875:4922:4923 ~-0.04826749377769299 214:0.578125:4924:4929 50:-0.078125:4925:4926 ~0.016848115937870986 55:0.734375:4927:4928 "
    s .= "~-0.03458258184273088 ~0.03470947019470593 145:0.25:4930:4931 ~0.05749256638936338 ~-0.043798674570203214 84:0.4453125:4933:4934 ~0.023166765526659583 ~-0.04155508254678794 ~-0.0461951988978331 251:1.109375:4937:4968 "
    s .= "256:0.5106382978723404:4938:4967 88:1.203125:4939:4962 254:1.265625:4940:4959 2:0.0625:4941:4954 110:0.015625:4942:4951 245:1.9423076923076923:4943:4946 244:1.07:4944:4945 ~-0.05578530568081336 ~0.002835427535994417 "
    s .= "122:-0.125:4947:4950 123:-0.0390625:4948:4949 ~-0.006242169602003469 ~0.029408323262366545 ~-0.035918415484399606 231:0.3984375:4952:4953 ~0.025706611235697608 ~-0.04014493992422439 244:1.21:4955:4956 ~-0.044012292628549575 "
    s .= "79:0.28125:4957:4958 ~-0.04331963766930782 ~0.020714625451469623 80:-0.96875:4960:4961 ~0.014701807451857271 ~-0.04678374050327974 64:-0.3125:4963:4964 ~-0.044258994592588335 43:0.453125:4965:4966 ~0.0346954803445235 "
    s .= "~-0.03486353216879139 ~-0.052776167718823055 130:1.96875:4969:4980 61:1.453125:4970:4977 191:-0.21875:4971:4972 ~0.033107057079602965 226:0.234375:4973:4976 94:-0.25:4974:4975 ~-0.044192547428525075 ~0.02289226627649793 "
    s .= "~-0.032527288957471916 55:-0.21875:4978:4979 ~-0.07556365615198847 ~0.006079975289040494 250:0.9453125:4981:4982 ~-0.07842010684672113 ~0.0053170087287950155 256:0.9583333333333334:4984:5029 118:0.28125:4985:5016 "
    s .= "49:0.34375:4986:5015 205:-0.25:4987:4988 ~-0.026607620889584613 245:4.313725490196078:4989:5014 88:0.515625:4990:5009 178:0.859375:4991:5008 91:0.171875:4992:5003 243:0.6499999999999999:4993:4998 187:0.078125:4994:4995 "
    s .= "~-0.051228012322340505 248:0.375:4996:4997 ~0.018322617335228213 ~-0.030270992673690985 186:0.5078125:4999:5002 211:0.53125:5000:5001 ~0.02501143392707484 ~-0.04367294998908157 ~-0.04894330398908719 241:0.18:5004:5005 "
    s .= "~0.04538930531704841 251:0.765625:5006:5007 ~-0.03864986075763385 ~0.019721625761507693 ~0.034712499222321565 70:0.34375:5010:5013 251:0.171875:5011:5012 ~-0.0543092482065783 ~0.03553807527962136 ~-0.024361283080779627 "
    s .= "~-0.11384206575160623 ~-0.02476807097564863 244:1.025:5017:5020 88:-0.4375:5018:5019 ~0.05734640960646427 ~-0.04218776368766915 163:-0.078125:5021:5022 ~-0.053438763581235095 2:-0.40625:5023:5024 ~0.019952856624704113 "
    s .= "79:0.34375:5025:5026 ~-0.03188773441574174 148:0.515625:5027:5028 ~0.025565444910902818 ~-0.04462698350507939 ~-0.0480398459527812 122:0.25:5031:5072 255:0.234375:5032:5045 249:1.5:5033:5044 254:0.453125:5034:5039 "
    s .= "243:1.55:5035:5036 ~0.014113778195892289 245:2.0652173913043477:5037:5038 ~-0.06772946605463 ~0.008381974861899726 122:0.09375:5040:5041 ~0.04407176743930507 88:0.21875:5042:5043 ~-0.05640632810178608 ~0.04095061525242616 "
    s .= "~-0.03833337756773655 41:-0.625:5046:5059 5:-0.375:5047:5058 110:-0.234375:5048:5057 245:2.161290322580645:5049:5052 140:-0.234375:5050:5051 ~-0.033893711191626284 ~0.043245207140998165 160:-0.234375:5053:5054 "
    s .= "~-0.08544743178108406 87:0.0546875:5055:5056 ~0.03530248928339944 ~-0.025649688996974226 ~0.041697417679259774 ~-0.03344134894260244 244:1.035:5060:5065 157:0.046875:5061:5064 181:0.015625:5062:5063 ~-0.039461473285505214 "
    s .= "~0.04283037041015945 ~-0.04865057443747365 254:1.359375:5066:5071 162:0.3203125:5067:5070 130:2.140625:5068:5069 ~0.005304310558777489 ~-0.04644055296787959 ~-0.046986197148039394 ~-0.04019398635119904 194:0.59375:5073:5076 "
    s .= "86:0.796875:5074:5075 ~-0.02221895342340416 ~0.029131119023430848 ~-0.052395362191943795 251:1.109375:5078:5107 256:0.5106382978723404:5079:5106 97:0.765625:5080:5105 85:1.15625:5081:5102 255:0.296875:5082:5091 "
    s .= "254:0.671875:5083:5086 242:0.45:5084:5085 ~0.00924687455198425 ~-0.024928553721087817 251:0.203125:5087:5088 ~-0.02317643133643395 191:0.234375:5089:5090 ~0.04052031982914567 ~-0.030397641370051277 122:-0.296875:5092:5101 "
    s .= "164:-0.28125:5093:5098 112:1.625:5094:5097 100:-0.328125:5095:5096 ~0.03872272002052888 ~-0.040040957159628035 ~0.03664853257230333 119:-0.453125:5099:5100 ~0.05068225448645756 ~-0.014966463660331856 ~-0.041290415639326686 "
    s .= "208:-0.21875:5103:5104 ~-0.035089989376849554 ~0.027741938304337882 ~-0.043432855714158405 ~-0.0522129184998058 241:0.46:5108:5117 242:0.55:5109:5112 146:-0.0625:5110:5111 ~0.024524029716425293 ~-0.03097066912769906 "
    s .= "181:0.21875:5113:5116 163:1.109375:5114:5115 ~-0.10465068397754942 ~0.037229007643784 ~-0.0014197607344715048 214:0.453125:5118:5123 243:1.35:5119:5120 ~0.03784653460846331 245:1.7088607594936709:5121:5122 ~-0.06444866043213225 "
    s .= "~0.01844999179768581 ~-0.047691388806990614 249:0.16666666666666666:5125:5142 245:4.878048780487805:5126:5141 90:0.0859375:5127:5134 67:-0.328125:5128:5129 ~-0.039358687903149545 70:0.40625:5130:5133 "
    s .= "243:2.1500000000000004:5131:5132 ~0.029904633397484687 ~-0.054193414087959 ~-0.012240943196155141 251:1.109375:5135:5138 114:0.2109375:5136:5137 ~-0.004051588783919784 ~-0.05095899052202564 73:-0.21875:5139:5140 "
    s .= "~-0.0519589954921888 ~0.03386748318082382 ~-0.1583444625335942 190:-0.1875:5143:5146 39:0.5546875:5144:5145 ~-0.04372667930992334 ~0.017443918706502963 245:1.5797101449275361:5147:5150 113:0.625:5148:5149 ~-0.07016664931094845 "
    s .= "~0.003331630896978166 163:-0.3125:5151:5152 ~-0.0646529122878594 26:-0.625:5153:5156 102:-0.3984375:5154:5155 ~-0.021800202459393483 ~0.026168870850467513 254:1.078125:5157:5170 174:0.015625:5158:5161 118:0.296875:5159:5160 "
    s .= "~-0.003141985458190664 ~-0.04580057636032709 71:0.171875:5162:5165 162:0.4296875:5163:5164 ~0.0242082378627137 ~-0.03324345307269819 184:0.09375:5166:5167 ~-0.05514559716619958 241:0.1:5168:5169 ~0.1048284682881116 "
    s .= "~-0.008157468526694285 ~-0.04154599695543332 251:0.671875:5172:5193 256:0.2111111111111111:5173:5192 238:-0.203125:5174:5175 ~-0.03916864994567014 46:0.078125:5176:5185 109:0.109375:5177:5178 ~-0.03008345064061085 "
    s .= "31:0.078125:5179:5184 64:-0.15625:5180:5183 109:0.421875:5181:5182 ~0.048492607123215174 ~-0.034294784743845896 ~0.02975260714556385 ~-0.015332666091517858 244:1.21:5186:5189 160:0.28125:5187:5188 ~-0.004538064271687826 "
    s .= "~-0.05228616901147746 145:-0.046875:5190:5191 ~-0.06246474093808291 ~0.01621587162474259 ~-0.05095430600021694 109:0.53125:5194:5205 100:1.09375:5195:5204 137:0.578125:5196:5201 121:0.21875:5197:5200 172:-0.15625:5198:5199 "
    s .= "~-0.061124224610178225 ~-0.0071860473853387705 ~-0.06334439964908188 119:0.59375:5202:5203 ~0.036566197622434536 ~-0.05129477200370352 ~0.033453314875750796 140:-0.078125:5206:5211 253:-0.03333333333333144:5207:5208 "
    s .= "~0.03806253746079372 181:-0.125:5209:5210 ~-0.05971419984977168 ~0.019657206392878546 241:0.46:5212:5215 204:0.3515625:5213:5214 ~-0.005901770921077235 ~-0.08297356406041886 22:-0.109375:5216:5217 ~-0.02261314202551486 "
    s .= "~0.03015522854748867 253:-0.0607697824527861:5219:5234 252:0.275:5220:5229 44:-0.03125:5221:5226 99:-0.1171875:5222:5225 41:-0.671875:5223:5224 ~0.018231219950442138 ~-0.059596284206922916 ~0.02776929739915675 112:1.25:5227:5228 "
    s .= "~-0.04905483378607126 ~0.01870611373510121 238:0.53125:5230:5233 223:0.375:5231:5232 ~0.03854659342329733 ~-0.028826627653130474 ~-0.05577024500969188 211:-0.296875:5235:5236 ~-0.03606724997476787 130:2.46875:5237:5264 "
    s .= "154:1:5238:5259 251:1.203125:5239:5254 242:0.45:5240:5247 34:-0.171875:5241:5242 ~0.03297283770083053 124:0.4375:5243:5244 ~-0.018648368473593604 199:0.1875:5245:5246 ~0.05688440012005515 ~-0.04740810818776604 "
    s .= "249:0.16666666666666666:5248:5253 90:0.2578125:5249:5252 25:0.203125:5250:5251 ~0.014587326616989997 ~-0.04269431315983937 ~-0.06337590017412202 ~-0.040708178550795754 112:0.390625:5255:5258 226:0.171875:5256:5257 "
    s .= "~0.00532403145694629 ~-0.06688379693295102 ~0.026764823812543866 94:0.4375:5260:5261 ~0.0227950582633349 175:0.28125:5262:5263 ~0.01883584160283497 ~-0.058921501081293265 ~-0.07864828866153126 2:0.3125:5266:5309 "
    s .= "255:0.296875:5267:5284 251:0.203125:5268:5269 ~-0.02464570527522275 245:4.878048780487805:5270:5283 239:0.609375:5271:5282 205:-0.25:5272:5273 ~-0.013787390764269464 127:0.1875:5274:5277 112:0.03125:5275:5276 "
    s .= "~0.0007824872853733916 ~0.035244411642663155 249:0.5:5278:5281 111:0.3671875:5279:5280 ~0.02584677116692042 ~-0.03467045972769885 ~-0.015432519276447518 ~-0.03364472218963859 ~-0.11218531692662209 77:-0.5625:5285:5298 "
    s .= "95:0.046875:5286:5297 246:-0.484375:5287:5296 109:1.171875:5288:5293 230:-1.15625:5289:5290 ~0.02804658646715418 20:-0.4375:5291:5292 ~-0.049654029872185895 ~0.011837683992034408 160:-0.1875:5294:5295 ~-0.093612903934749 "
    s .= "~0.028417230025717125 ~0.036730544689994364 ~-0.0534036325261566 254:1.359375:5299:5308 244:0.99:5300:5303 79:-0.421875:5301:5302 ~0.04196846791324948 ~-0.045418361255298904 235:-0.171875:5304:5305 ~-0.041888146284410094 "
    s .= "218:0.046875:5306:5307 ~0.008221236073675064 ~-0.032206091683228626 ~-0.04531961135973892 244:1.14:5310:5311 ~-0.04905525202346714 ~-0.0077588259272213245 88:1.109375:5313:5352 251:1.109375:5314:5335 "
    s .= "245:1.5797101449275361:5315:5316 ~-0.05453230252448276 162:0.4296875:5317:5334 254:1.265625:5318:5331 187:-0.171875:5319:5320 ~-0.034196274404182055 136:2.265625:5321:5330 146:0.328125:5322:5329 242:0.6499999999999999:5323:5324 "
    s .= "~0.015088968236856633 103:1.25:5325:5328 134:0:5326:5327 ~-0.0432757108763403 ~0.0044512000627596245 ~0.029181573397500573 ~-0.03163744921706387 ~-0.09613446654701098 9:-0.2578125:5332:5333 ~0.010433192767996292 "
    s .= "~-0.04471237074132792 ~-0.053984479848893 142:0.390625:5336:5351 89:0.59375:5337:5350 245:1.6140350877192982:5338:5339 ~-0.051358180294315985 184:0.140625:5340:5349 204:0.3515625:5341:5346 61:0.078125:5342:5345 241:0.82:5343:5344 "
    s .= "~-0.052256618430463454 ~0.0479888899144226 ~0.027453084004817364 252:0.42500000000000004:5347:5348 ~-0.08559725559908044 ~0.03260561933746855 ~0.026952089001932703 ~0.03916651273841502 ~-0.021907700360488388 202:-0.0625:5353:5356 "
    s .= "215:-0.625:5354:5355 ~0.03070936337010476 ~-0.03443427225045392 121:0.703125:5357:5358 ~0.03128363222177616 ~-0.046593407017467 143:0.140625:5360:5397 252:0.175:5361:5386 242:0.55:5362:5381 184:0.046875:5363:5372 "
    s .= "146:-0.109375:5364:5371 138:-0.5234375:5365:5366 ~-0.0887674488751776 249:0.8333333333333333:5367:5370 49:-0.0625:5368:5369 ~0.043801755123091084 ~-0.006548967994422901 ~-0.04015621879179462 ~-0.049303804738703716 "
    s .= "118:0.359375:5373:5378 159:0.2734375:5374:5377 195:-0.0703125:5375:5376 ~0.002129604116027704 ~0.033158150782650365 ~-0.019012386135905605 112:1.296875:5379:5380 ~-0.03233619232730386 ~0.02949915544666412 220:0.625:5382:5385 "
    s .= "160:0.84375:5383:5384 ~-0.06146630552906818 ~-0.005099648031639202 ~0.0339095075689334 31:0.25:5387:5394 226:-0.234375:5388:5389 ~-0.018282720206693772 142:0.296875:5390:5391 ~0.03317050744789148 244:1.375:5392:5393 "
    s .= "~-0.031976338029988005 ~0.030323300224091566 213:0.3671875:5395:5396 ~-0.03341688257689054 ~0.026790594692602965 121:-0.25:5398:5399 ~-0.05245175934905564 145:0.515625:5400:5405 244:0.935:5401:5402 ~-0.0376010388258968 "
    s .= "112:0.390625:5403:5404 ~-0.019566307192886375 ~0.0146980468944107 ~-0.057073920687060936 251:0.484375:5407:5428 250:0.9765625:5408:5425 148:0.21875:5409:5418 223:0.515625:5410:5417 191:-0.0625:5411:5416 153:-0.0703125:5412:5415 "
    s .= "109:1.140625:5413:5414 ~-0.045264005094027865 ~0.024507349791562286 ~0.029727442349640282 ~-0.02205060833000995 ~0.053606298517782494 251:0.109375:5419:5422 232:0.21875:5420:5421 ~0.0905828730509776 ~-0.04326470401756044 "
    s .= "217:0.671875:5423:5424 ~-0.04388308300814527 ~0.027770312281257183 245:2.425531914893617:5426:5427 ~-0.04186443220762948 ~0.008562407044051824 38:-0.671875:5429:5432 122:-0.09375:5430:5431 ~0.02641247221614633 "
    s .= "~-0.0260763423813795 255:0.265625:5433:5440 254:0.765625:5434:5437 239:0.609375:5435:5436 ~0.008661025353672563 ~-0.03762842504997076 85:1.328125:5438:5439 ~0.041808598312824845 ~-0.024651028478903027 254:1.296875:5441:5452 "
    s .= "23:-0.078125:5442:5447 224:0.03125:5443:5446 247:0.296875:5444:5445 ~0.015620516987847161 ~-0.027618721275580377 ~-0.04167972892728199 21:0.0078125:5448:5451 144:0.2890625:5449:5450 ~-0.019081711542181225 ~0.05010530100210734 "
    s .= "~-0.04646901014806023 ~-0.04107604733074182 249:0.16666666666666666:5454:5463 253:-0.0607697824527861:5455:5456 ~0.026486338662644965 73:0.203125:5457:5462 100:-0.140625:5458:5459 ~-0.024282660129869467 239:0.078125:5460:5461 "
    s .= "~0.02264893643074106 ~-0.013450574986348322 ~-0.020506305981877873 190:-0.1875:5464:5467 39:0.5546875:5465:5466 ~-0.04226635407716267 ~0.017603007377555564 245:1.5797101449275361:5468:5471 113:0.625:5469:5470 "
    s .= "~-0.06925793786392323 ~0.004570480168962246 163:-0.3125:5472:5473 ~-0.06369792314623564 127:0.140625:5474:5487 34:-0.125:5475:5478 244:0.82:5476:5477 ~0.1241887451914253 ~0.02798582162309878 252:0.175:5479:5486 "
    s .= "173:0.078125:5480:5485 190:0.03125:5481:5482 ~-0.0408550476541328 181:1.296875:5483:5484 ~0.02299062778922853 ~-0.09213266080821124 ~-0.05730161818198592 ~0.036007370208898604 79:0.890625:5488:5499 184:0:5489:5490 "
    s .= "~-0.05778920731096959 77:-0.078125:5491:5494 207:-0.1640625:5492:5493 ~-0.031692417672761555 ~0.01390789426567998 242:0.25:5495:5496 ~0.08106855088228708 251:1.828125:5497:5498 ~-0.0438556711602602 ~0.014782834229330034 "
    s .= "~0.016821536530371748 85:1.15625:5501:5536 251:1.484375:5502:5525 159:0.2109375:5503:5520 255:0.296875:5504:5515 254:0.703125:5505:5508 242:0.45:5506:5507 ~0.010215971487105877 ~-0.019910306714541744 251:0.203125:5509:5510 "
    s .= "~-0.02202007473606848 145:-0.0625:5511:5512 ~-0.011517991064624533 244:2.25:5513:5514 ~0.0452116956934419 ~-0.09146787731073348 5:-0.359375:5516:5517 ~-0.0034350880697482595 241:0.12:5518:5519 ~0.000960159804585037 "
    s .= "~-0.048428451273702676 55:-0.609375:5521:5522 ~0.06834825536167088 255:-0.046875:5523:5524 ~0.06476254762800308 ~-0.0422595923498737 252:0.375:5526:5531 172:0.46875:5527:5530 184:0.625:5528:5529 ~-0.043931374067772866 "
    s .= "~0.02964128042284704 ~0.04369631748049129 243:1.25:5532:5533 ~0.04579792309154335 245:1.6626506024096386:5534:5535 ~-0.07549196434898947 ~0.020338759520818407 208:-0.078125:5537:5540 242:0.6499999999999999:5538:5539 "
    s .= "~-0.0443379256653415 ~0.0029898175952257472 73:0.65625:5541:5546 245:4.878048780487805:5542:5545 248:1.375:5543:5544 ~0.029726349141906708 ~-0.0735681226473736 ~-0.11391481869767489 ~-0.0478060648355051 49:0.53125:5548:5593 "
    s .= "245:1.5866666666666667:5549:5554 113:0.609375:5550:5551 ~-0.059738546292192156 167:0.171875:5552:5553 ~0.04669664179224675 ~-0.03756129072840034 245:4.017543859649122:5555:5590 145:-0.125:5556:5565 119:0.234375:5557:5564 "
    s .= "144:0.0390625:5558:5561 244:1.4:5559:5560 ~-0.05881740988233252 ~0.001698280425137978 73:-0.125:5562:5563 ~0.03485075247063165 ~-0.020035012407523173 ~-0.05114875377810157 162:0.3671875:5566:5589 "
    s .= "253:-0.043604651162790255:5567:5572 205:-0.25:5568:5571 154:0.953125:5569:5570 ~-0.06407041027224643 ~0.03588308615884566 ~0.03121526997191933 190:0:5573:5580 181:0.09375:5574:5577 241:0.58:5575:5576 ~-0.05624472337413671 "
    s .= "~0.012048066618914898 121:0.265625:5578:5579 ~0.01951744045034603 ~-0.041378484872107706 217:0.21875:5581:5582 ~0.020159306878613673 136:1.09375:5583:5586 220:0.625:5584:5585 ~-0.042546039939036696 ~0.03492469654544877 "
    s .= "250:0.7734375:5587:5588 ~-0.06782035059610915 ~0.02956437756549254 ~-0.023841454940176653 232:0.34375:5591:5592 ~-0.08869921501758024 ~0.019834160764352404 ~-0.025257663432219676 248:1.375:5595:5638 217:-0.125:5596:5605 "
    s .= "17:-0.78125:5597:5598 ~0.02124616215543082 251:1.390625:5599:5602 100:1.09375:5600:5601 ~-0.03930673358909273 ~0.011880348018274402 46:0.09375:5603:5604 ~-0.022720162423123205 ~0.03538521309190302 159:0.4921875:5606:5637 "
    s .= "88:1.109375:5607:5634 255:0.296875:5608:5615 2:0.0625:5609:5614 136:2.1875:5610:5613 195:-0.3359375:5611:5612 ~-0.038829728394167984 ~0.021332677892130295 ~-0.09462177283186227 ~-0.008294282219881271 98:-0.328125:5616:5627 "
    s .= "246:-0.390625:5617:5622 245:1.9838709677419355:5618:5621 42:-0.1953125:5619:5620 ~0.0036472724528370335 ~-0.07511385816205703 ~0.004094626753141532 119:-0.453125:5623:5624 ~0.04463004353245187 220:0.40625:5625:5626 "
    s .= "~-0.020031873549439 ~0.04538089003363295 254:0.609375:5628:5629 ~0.01995876672428337 86:0.421875:5630:5633 79:0.71875:5631:5632 ~-0.05156354263493943 ~0.0003715841310619801 ~0.013890201762477542 70:0.53125:5635:5636 "
    s .= "~0.03095489777148415 ~-0.03199446028392027 ~-0.04510036620233751 112:2:5639:5640 ~-0.05662103575627028 ~0.03161436778640921 28:0.5:5642:5679 157:1.109375:5643:5670 255:0.234375:5644:5657 254:0.453125:5645:5654 "
    s .= "245:1.5866666666666667:5646:5649 113:1.03125:5647:5648 ~-0.05845868114421459 ~0.037862630746522886 168:0.1953125:5650:5651 ~-0.00890744291484918 162:0.4765625:5652:5653 ~0.024950890289862866 ~-0.0277132269751844 "
    s .= "145:-0.0625:5655:5656 ~-0.013788356779528582 ~0.03686708930082929 50:-0.65625:5658:5659 ~0.007834880563008939 254:0.546875:5660:5661 ~0.020958982490379304 79:1.171875:5662:5669 241:0.1:5663:5666 91:0.265625:5664:5665 "
    s .= "~-0.02719377375431717 ~0.05494175011517258 251:2.453125:5667:5668 ~-0.04232546657959721 ~0.020535165751181 ~0.013268247662537183 202:-0.203125:5671:5672 ~-0.026714758463066514 159:0.4765625:5673:5678 130:2.46875:5674:5675 "
    s .= "~0.025846866109908558 185:-0.78125:5676:5677 ~0.03186444873376831 ~-0.1048279784826387 ~-0.0712348069762121 244:1.715:5680:5687 157:0.5625:5681:5686 79:0.578125:5682:5683 ~-0.0409007040576286 226:0.046875:5684:5685 "
    s .= "~-0.029219431105689267 ~0.05004355767233162 ~-0.05598920510806136 ~0.02028356537415143 249:0.16666666666666666:5689:5710 90:0.0859375:5690:5703 67:-0.328125:5691:5692 ~-0.03711460517246123 245:4.313725490196078:5693:5702 "
    s .= "70:0.40625:5694:5697 243:2.1500000000000004:5695:5696 ~0.02794400182032103 ~-0.05386286448481103 157:0.1875:5698:5699 ~0.030270774113793687 163:1.296875:5700:5701 ~-0.05599163105347722 ~0.03586303879564678 ~-0.08953921657568473 "
    s .= "251:1.109375:5704:5707 114:0.2109375:5705:5706 ~-0.005084714854619665 ~-0.04821565795630116 73:-0.21875:5708:5709 ~-0.046718876540480854 ~0.030414689343236045 184:-0.21875:5711:5712 ~-0.039772583330538236 "
    s .= "245:1.5797101449275361:5713:5716 89:0.78125:5714:5715 ~-0.05770132188702618 ~0.02419458657918229 168:0.0546875:5717:5726 17:-0.46875:5718:5723 243:0.25:5719:5720 ~-0.05554988987883558 197:-0.203125:5721:5722 ~0.018080506666673227 "
    s .= "~-0.028038765348891683 204:0.0703125:5724:5725 ~-0.032147516321302756 ~0.0061427746898863045 53:0.0625:5727:5732 246:-0.078125:5728:5731 87:0.1171875:5729:5730 ~0.014049549267913734 ~-0.038688100478693734 ~0.03132741158976978 "
    s .= "190:0.84375:5733:5734 ~-0.02450099900038474 ~0.061465434008127866 251:0.484375:5736:5751 109:0.109375:5737:5738 ~-0.04411057887971427 46:0.078125:5739:5744 55:0.09375:5740:5743 250:1.0546875:5741:5742 ~0.026926499005417784 "
    s .= "~-0.01878246743526022 ~-0.02728986264015673 76:-0.015625:5745:5746 ~-0.061665434945524816 244:1.21:5747:5750 55:-0.53125:5748:5749 ~0.10000930015088028 ~-0.04125500410609995 ~0.009416954866695887 238:0.46875:5752:5777 "
    s .= "249:0.5:5753:5764 245:4.017543859649122:5754:5763 255:0.546875:5755:5760 162:0.3671875:5756:5757 ~0.023817904910448818 112:0:5758:5759 ~-0.059380511374237534 ~0.010707907213622185 14:-0.671875:5761:5762 ~0.017084019455594512 "
    s .= "~-0.04087532271041951 ~-0.07774683805670493 245:1.5932203389830508:5765:5766 ~-0.04958409855919733 235:-0.15625:5767:5770 72:0.2109375:5768:5769 ~-0.05046968679806351 ~0.014241251390106785 31:-0.21875:5771:5772 "
    s .= "~0.03415032552257607 253:-0.10989010989011051:5773:5774 ~0.036789857094825025 251:1.703125:5775:5776 ~-0.023002020502865428 ~0.026192240080319902 243:0.6499999999999999:5778:5781 114:0.2109375:5779:5780 ~0.020643312448655343 "
    s .= "~-0.05562407757109923 ~-0.05118594738775859 248:1.375:5783:5828 85:1.15625:5784:5821 251:1.484375:5785:5814 217:-0.125:5786:5787 ~-0.03341196067666781 159:0.3359375:5788:5811 254:1.265625:5789:5808 "
    s .= "245:1.5866666666666667:5790:5793 250:0.9453125:5791:5792 ~0.054208340442603455 ~-0.04643263267765154 123:-0.2578125:5794:5797 160:1.140625:5795:5796 ~-0.05093584697360043 ~0.021785794880278 130:2.46875:5798:5807 "
    s .= "242:0.6499999999999999:5799:5800 ~0.020177587975738244 252:0.175:5801:5806 226:0.328125:5802:5805 157:0.96875:5803:5804 ~-0.08594864376661121 ~0.01701487189029815 ~0.030471309463023868 ~0.011284735786043512 ~-0.08754443419670353 "
    s .= "80:-0.96875:5809:5810 ~0.02179980284955163 ~-0.03864092448293608 31:-0.390625:5812:5813 ~0.03658504459983324 ~-0.0511880744160645 168:0.1484375:5815:5820 91:-0.328125:5816:5817 ~-0.09177633782102684 "
    s .= "245:3.4262295081967213:5818:5819 ~0.009897838276527 ~-0.1010603856897103 ~0.0345947315512324 208:-0.078125:5822:5825 242:0.6499999999999999:5823:5824 ~-0.04212089331804662 ~0.004417083248737342 73:0.65625:5826:5827 "
    s .= "~0.026924548772294568 ~-0.04410602728442496 ~-0.041196222479925576 119:0.125:5830:5873 251:0.203125:5831:5838 250:0.8828125:5832:5837 43:0.078125:5833:5836 223:0:5834:5835 ~-0.055116331100487664 ~0.04020166925123113 "
    s .= "~-0.05640119593606672 ~-0.046135554210499814 255:0.296875:5839:5850 136:2.109375:5840:5849 254:0.703125:5841:5844 243:1.35:5842:5843 ~0.013716480918734737 ~-0.023511347211730656 162:0.3203125:5845:5848 139:-0.3125:5846:5847 "
    s .= "~-0.050763697029670034 ~0.03991724412561471 ~-0.02025966408861093 ~-0.05406903916898298 122:-0.328125:5851:5862 158:-0.25:5852:5859 245:1.9838709677419355:5853:5856 9:-0.1484375:5854:5855 ~-0.00022367826343626355 "
    s .= "~-0.06498296180838674 181:-0.03125:5857:5858 ~-0.029178029375206388 ~0.016755616370084932 62:-0.453125:5860:5861 ~0.04492236605593836 ~0.007272656857419075 241:0.46:5863:5866 254:0.796875:5864:5865 ~-0.000009125044568162921 "
    s .= "~-0.05093785721883486 244:1.48:5867:5872 250:1.3671875:5868:5871 100:0.140625:5869:5870 ~-0.00848331390959353 ~-0.06500132398947178 ~0.025857815018647708 ~0.02507812252702682 79:0.3125:5874:5875 ~-0.02472928126629483 "
    s .= "~0.00197943222793384 122:0.25:5877:5916 255:0.234375:5878:5893 249:1.5:5879:5892 147:-0.1796875:5880:5883 244:1.54:5881:5882 ~-0.0322030533708134 ~0.03208550752262728 133:2.40625:5884:5891 191:0.59375:5885:5890 "
    s .= "53:0.0625:5886:5887 ~0.02610209927176706 7:0.109375:5888:5889 ~0.01846275960290324 ~-0.027427215974085185 ~-0.03583607703640766 ~-0.07130397622837688 ~-0.035314837005455346 122:-0.328125:5894:5909 247:0.234375:5895:5906 "
    s .= "134:-0.34375:5896:5905 176:-0.65625:5897:5904 245:2.154639175257732:5898:5901 244:1.46:5899:5900 ~-0.03647763862179746 ~0.030852080102259455 160:-0.328125:5902:5903 ~-0.06901797231573663 ~0.02689599195398165 "
    s .= "~-0.017931402352803702 ~0.023470191479354186 251:2.015625:5907:5908 ~-0.048608960051479515 ~0.034382217990214334 86:0.40625:5910:5915 106:1.09375:5911:5912 ~-0.03752099181704223 253:-0.02408008658008627:5913:5914 "
    s .= "~0.02078294085289349 ~-0.02769232339932744 ~0.0215897924111998 89:0.75:5917:5920 19:-0.09375:5918:5919 ~-0.051971362013970526 ~-0.01612958924723251 173:0.625:5921:5922 ~0.0314694481869418 ~-0.03937903301782071 28:0.5:5924:5967 "
    s .= "154:1:5925:5960 190:-0.125:5926:5931 168:0.0234375:5927:5928 ~-0.04549481718117571 17:0:5929:5930 ~0.02129702088318653 ~-0.040359634353460634 162:0.4765625:5932:5959 202:0.203125:5933:5952 184:0.359375:5934:5951 "
    s .= "109:1.71875:5935:5948 1:0.25:5936:5947 239:0.4375:5937:5946 190:0.625:5938:5945 148:0.265625:5939:5944 64:0.234375:5940:5943 178:-0.0625:5941:5942 ~-0.04222275807926643 ~0.013786258403073485 ~0.040413717267452805 "
    s .= "~-0.034385763413004526 ~0.05567813619186991 ~-0.0402420234827121 ~-0.04984156782284471 199:0.15625:5949:5950 ~-0.06957467584284889 ~0.03412634839033246 ~0.027235049930317112 190:0.4375:5953:5956 44:-0.078125:5954:5955 "
    s .= "~0.013598587899834064 ~-0.02121870343163645 154:0.28125:5957:5958 ~-0.00748517941338034 ~-0.06778504776483706 ~-0.045489977939169965 172:-0.421875:5961:5962 ~-0.04230157798938147 156:0.3671875:5963:5966 136:2.1875:5964:5965 "
    s .= "~0.025466546550638264 ~-0.04465211759815091 ~-0.060018374752861516 244:1.715:5968:5969 ~-0.03164715240053712 ~0.018859421860090847 253:-0.05829228243021589:5971:5986 252:0.275:5972:5981 122:0.03125:5973:5980 "
    s .= "99:-0.1171875:5974:5975 ~-0.02440461838790379 245:1.8111111111111111:5976:5977 ~-0.03449215497937284 133:1.59375:5978:5979 ~0.03720877295037319 ~-0.031701562853598715 ~-0.03841890255024619 238:0.53125:5982:5985 "
    s .= "223:0.375:5983:5984 ~0.03636669817803241 ~-0.027356897358966327 ~-0.04845716222830346 243:1.55:5987:6014 248:1.375:5988:6013 73:0.625:5989:6010 85:0.640625:5990:6007 205:0.625:5991:6004 64:0.15625:5992:5999 190:0.625:5993:5996 "
    s .= "245:3.3389830508474576:5994:5995 ~-0.020463430927797184 ~-0.08173261357166298 175:0:5997:5998 ~0.06422745340253978 ~-0.01995269073453687 142:0.21875:6000:6001 ~0.018631274042617735 28:0.671875:6002:6003 ~-0.027911526668140393 "
    s .= "~0.05741388277334462 208:0.609375:6005:6006 ~0.04230626074743283 ~-0.01101644097208382 208:-0.21875:6008:6009 ~-0.031483303817739054 ~0.018724869638855238 31:0:6011:6012 ~0.0017905195554090841 ~-0.05309541404758139 "
    s .= "~-0.046563014676628225 72:0.1328125:6015:6016 ~-0.05219492820883657 ~-0.003532997102674941 251:0.671875:6018:6033 46:0.078125:6019:6028 64:-0.375:6020:6021 ~-0.0529815836386812 31:0.078125:6022:6027 184:0:6023:6026 "
    s .= "88:0.21875:6024:6025 ~-0.04392607203700295 ~0.018214300121795972 ~0.020598213140766663 ~-0.020666926390075613 244:1.21:6029:6030 ~-0.036658178959938295 145:0:6031:6032 ~-0.051592078724694214 ~0.009376852055854716 "
    s .= "238:0.5:6034:6061 244:2.86:6035:6060 203:0.671875:6036:6059 252:0.275:6037:6052 207:0.3203125:6038:6049 130:2.40625:6039:6048 181:0.4375:6040:6047 91:-0.140625:6041:6042 ~-0.04089744498590264 196:-0.234375:6043:6044 "
    s .= "~-0.0573483078072069 118:0.296875:6045:6046 ~0.02495579699009634 ~-0.018459954660011057 ~0.03041297684025454 ~-0.09124519991535102 25:-0.4375:6050:6051 ~0.05442375230493333 ~-0.04090353599251349 243:0.6499999999999999:6053:6054 "
    s .= "~-0.05652231456701885 169:0.5:6055:6058 40:0.53125:6056:6057 ~0.030724338369008182 ~-0.04669215764181314 ~-0.042584555671640524 ~-0.05329264250846249 ~-0.057178864617750014 136:1.046875:6062:6063 ~-0.04345794242924276 "
    s .= "~0.020233191713790816 88:1.109375:6065:6104 251:1.109375:6066:6087 245:1.5797101449275361:6067:6068 ~-0.052176109430309106 247:0.484375:6069:6084 254:1.265625:6070:6081 187:-0.171875:6071:6072 ~-0.0295331427583518 "
    s .= "136:2.265625:6073:6080 146:0.28125:6074:6079 135:-0.2734375:6075:6076 ~-0.01793115809447512 242:2.05:6077:6078 ~0.013095331067879332 ~-0.03845983236912089 ~-0.028939755576254046 ~-0.08385809166733299 12:-0.2578125:6082:6083 "
    s .= "~0.008683726920778814 ~-0.040895197683501694 251:0.109375:6085:6086 ~0.047010089197555546 ~-0.04705550984516735 243:0.25:6088:6089 ~-0.05087995578039009 61:1.453125:6090:6103 117:0.1953125:6091:6098 81:0.2578125:6092:6097 "
    s .= "98:-0.203125:6093:6094 ~0.025375242435205926 243:0.75:6095:6096 ~-0.05672500236536962 ~0.01033767280024741 ~-0.035209184491070994 75:-0.1328125:6099:6100 ~-0.0490179572555735 239:0.5625:6101:6102 ~0.03685551705772224 "
    s .= "~-0.03736724297738684 ~-0.0321005476695019 70:0.53125:6105:6110 193:-0.03125:6106:6109 58:-0.328125:6107:6108 ~-0.05469364159333914 ~0.00882504799105979 ~0.032893480100013854 ~-0.033693583852298564 245:4.878048780487805:6112:6157 "
    s .= "249:0.16666666666666666:6113:6126 253:-0.06723484848484773:6114:6115 ~0.02679825204412378 73:0.203125:6116:6125 202:-0.296875:6117:6118 ~-0.04620055212531243 231:0.3359375:6119:6124 255:0.390625:6120:6123 212:0.046875:6121:6122 "
    s .= "~0.03366173561482382 ~-0.001997392190986816 ~-0.011408505992161063 ~-0.020469145611641634 ~-0.017825155568259584 184:-0.21875:6127:6128 ~-0.03784471337028416 127:0.265625:6129:6142 245:1.381578947368421:6130:6131 "
    s .= "~-0.04790498146109898 25:0.5:6132:6141 251:0.171875:6133:6134 ~-0.03988576088721066 22:0.984375:6135:6140 112:0.015625:6136:6139 211:0.046875:6137:6138 ~-0.04744849250553291 ~0.025720986999799418 ~0.020999463042036162 "
    s .= "~-0.0468977231854153 ~-0.04360272424309153 216:0.2265625:6143:6152 41:-0.640625:6144:6145 ~0.005361557853756711 40:0.5:6146:6149 79:1.109375:6147:6148 ~-0.04485664455462884 ~0.003390747820916284 244:1.19:6150:6151 "
    s .= "~-0.052523316955745684 ~0.040950065536922535 103:0.25:6153:6154 ~0.0315445002405819 245:2.122448979591837:6155:6156 ~-0.04217108896142599 ~0.017750663444969287 ~-0.09839703852598762 49:0.53125:6159:6204 145:-0.125:6160:6169 "
    s .= "17:-0.78125:6161:6164 222:-0.2109375:6162:6163 ~-0.06678220703067837 ~0.03936219255042581 119:0.234375:6165:6168 54:0.0546875:6166:6167 ~-0.029398028631101726 ~0.00674080556661601 ~-0.05336361261827528 "
    s .= "252:0.32499999999999996:6170:6197 190:0.03125:6171:6180 217:0.609375:6172:6179 202:0.484375:6173:6178 192:0.2890625:6174:6175 ~-0.04808222058246126 58:0.390625:6176:6177 ~0.023319865105592096 ~-0.08066296901477915 "
    s .= "~0.014797514790678052 ~0.029898207656804166 245:1.5866666666666667:6181:6182 ~-0.04462989758551467 247:0.546875:6183:6194 118:-0.140625:6184:6187 58:-0.109375:6185:6186 ~0.014667203479766114 ~-0.061044904216965595 "
    s .= "130:2.46875:6188:6193 118:0.28125:6189:6190 ~0.024218101084436866 220:0.625:6191:6192 ~-0.010080766805379027 ~0.047511282368885556 ~-0.08122242444000452 239:0.796875:6195:6196 ~-0.06057853075783398 ~0.04236133148094043 "
    s .= "253:-0.043604651162790255:6198:6199 ~0.033503080828663885 202:0.203125:6200:6203 243:2.3499999999999996:6201:6202 ~0.021356991707036692 ~-0.05502462870594519 ~-0.022531298087365276 ~-0.022796944582825607 77:-0.125:6206:6229 "
    s .= "255:0.234375:6207:6210 147:-0.1640625:6208:6209 ~-0.011859219208314195 ~0.02478251341363284 122:-0.359375:6211:6224 247:0.265625:6212:6221 123:-0.2734375:6213:6220 39:-0.2578125:6214:6217 148:0.40625:6215:6216 "
    s .= "~0.02664444460067197 ~-0.04043952884060091 45:-0.3046875:6218:6219 ~-0.13721348035106634 ~-0.030393892994172653 ~0.01658240670117365 251:1.171875:6222:6223 ~-0.0648021862266419 ~0.014258175971131057 250:1.3671875:6225:6228 "
    s .= "254:0.609375:6226:6227 ~0.012392980534854773 ~-0.03590837506492427 ~0.021860306610850196 254:1.265625:6230:6251 89:0.625:6231:6246 79:0.765625:6232:6241 122:0.25:6233:6240 186:0.4765625:6234:6239 235:-0.078125:6235:6236 "
    s .= "~-0.03163253002468346 117:0.0546875:6237:6238 ~-0.013034396099744772 ~0.014008069521349304 ~-0.05689029765610393 ~-0.043065614305820746 28:0.5:6242:6245 19:-0.21875:6243:6244 ~-0.03920049245519255 ~0.0249734284163369 "
    s .= "~-0.04382023686556842 71:0.5625:6247:6250 203:0.65625:6248:6249 ~0.04117069317872205 ~-0.05452119788508767 ~-0.029337134960542494 ~-0.06115459123093815 251:0.484375:6253:6274 109:0.109375:6254:6255 ~-0.04333323359913227 "
    s .= "46:0.078125:6256:6263 55:0.09375:6257:6260 250:1.0546875:6258:6259 ~0.02509802699379099 ~-0.01832117616988807 112:1.3125:6261:6262 ~-0.04391873491936706 ~0.022203249422718535 76:-0.015625:6264:6265 ~-0.05938254925473514 "
    s .= "127:0.1875:6266:6269 191:0.015625:6267:6268 ~0.02804649246457318 ~-0.052349501279707444 238:1.203125:6270:6273 242:0.25:6271:6272 ~0.045102867380090755 ~-0.04813739378219811 ~0.04547259281369296 26:-0.765625:6275:6278 "
    s .= "14:-0.4375:6276:6277 ~0.027802995898325772 ~-0.02251559687240521 254:1.046875:6279:6298 110:-0.9375:6280:6281 ~-0.054433141129274304 191:0.59375:6282:6297 46:-0.21875:6283:6286 65:-0.09375:6284:6285 ~0.010243210769454853 "
    s .= "~-0.034263111413401895 245:4.017543859649122:6287:6296 49:0.359375:6288:6295 245:1.3157894736842106:6289:6290 ~-0.04439885029858397 162:0.3671875:6291:6292 ~0.02237719133994203 112:0:6293:6294 ~-0.060728696370968054 "
    s .= "~0.011990176231027386 ~-0.012866187009191912 ~-0.08177394663912933 ~-0.03424981683366241 ~-0.02640761429883808 88:1.109375:6300:6341 251:1.109375:6301:6330 245:1.5797101449275361:6302:6303 ~-0.05119821986973481 "
    s .= "159:0.2109375:6304:6325 97:0.765625:6305:6324 254:1.265625:6306:6321 26:-0.109375:6307:6314 246:-0.109375:6308:6313 245:2.016949152542373:6309:6312 87:-0.0546875:6310:6311 ~-0.002745308461766654 ~-0.07152081702289712 "
    s .= "~0.010047344879466728 ~0.028666816431004286 241:0.12:6315:6320 154:0.4375:6316:6317 ~-0.015856663791580346 157:0.5625:6318:6319 ~0.09254839299380029 ~-0.02385144464590768 ~-0.017232410027451715 9:-0.2578125:6322:6323 "
    s .= "~0.012405174126788236 ~-0.03799848697696063 ~-0.04398416801591307 85:0.03125:6326:6327 ~0.007181571559312496 255:0.015625:6328:6329 ~0.03668211726558722 ~-0.05236806447031705 130:1.9375:6331:6340 149:0.140625:6332:6335 "
    s .= "137:0.546875:6333:6334 ~0.011726166813489168 ~0.04601069713242169 241:0.42:6336:6339 90:0.4765625:6337:6338 ~-0.07267173282929891 ~0.018425084461356152 ~0.005849281290144405 ~-0.03565671684870499 70:0.53125:6342:6345 "
    s .= "202:-0.0625:6343:6344 ~-0.01024457424365073 ~0.02855580167023184 ~-0.031730702437167434 154:1:6347:6384 142:-0.203125:6348:6351 124:-0.125:6349:6350 ~-0.000048869664959942194 ~-0.04704628855449611 162:0.4765625:6352:6383 "
    s .= "112:0.40625:6353:6362 235:0.265625:6354:6361 71:0.171875:6355:6358 139:0.953125:6356:6357 ~0.00970987332452157 ~-0.033674951221337734 187:0.25:6359:6360 ~-0.04766797259059027 ~0.01075897283863404 ~-0.03834920682896172 "
    s .= "251:1.328125:6363:6382 163:-0.078125:6364:6365 ~-0.04513417133440238 148:0.515625:6366:6377 220:0.859375:6367:6376 103:0.1875:6368:6369 ~0.02048585024671949 244:1.21:6370:6375 163:0.125:6371:6374 243:0.55:6372:6373 "
    s .= "~-0.06422699973519017 ~0.04869119289757127 ~-0.048259887537797586 ~0.022051681607679383 ~0.046969383416299554 123:0.1015625:6378:6379 ~-0.05108975967780696 121:0.453125:6380:6381 ~0.04349218168150576 ~-0.05980392729526435 "
    s .= "~0.028412070263459235 ~-0.04222222947812291 156:0.3671875:6385:6392 172:-0.421875:6386:6387 ~-0.040264295527263495 28:0.453125:6388:6391 245:4.878048780487805:6389:6390 ~0.022880367836936245 ~-0.10355962621956712 "
    s .= "~-0.024013678268646484 ~-0.051702519010035336 255:0.296875:6394:6411 77:-0.046875:6395:6406 110:0:6396:6405 111:0.2109375:6397:6404 251:0.265625:6398:6401 178:1.15625:6399:6400 ~-0.04416225020951125 ~0.03493298621668744 "
    s .= "236:-0.453125:6402:6403 ~0.03386299541791444 ~0.0013318844859674722 ~-0.04233719458728878 ~0.028279287949289956 73:-0.203125:6407:6408 ~-0.028455937470397725 202:0.203125:6409:6410 ~0.010818188740870207 ~-0.020663615289248604 "
    s .= "122:-0.28125:6412:6439 247:0.234375:6413:6436 246:-0.390625:6414:6431 109:1.03125:6415:6424 103:-0.15625:6416:6417 ~0.027299114153168713 245:2.338709677419355:6418:6421 112:-0.140625:6419:6420 ~0.03041526285523959 "
    s .= "~-0.053673182704449034 69:0.0390625:6422:6423 ~0.01630876245437177 ~-0.05979941649099949 160:-0.203125:6425:6426 ~-0.06748103672605772 133:0.1875:6427:6428 ~-0.05779148302549987 146:-0.53125:6429:6430 ~0.031168839885599375 "
    s .= "~-0.014109683115907571 44:0.03125:6432:6435 97:-0.109375:6433:6434 ~-0.030302425014103525 ~0.03850434557193984 ~-0.04194813325010074 251:1.984375:6437:6438 ~-0.04482695179520554 ~0.03422950713377274 ~-0.022783115338607062 "
    s .= "249:0.16666666666666666:6441:6456 90:0.0859375:6442:6447 67:-0.328125:6443:6444 ~-0.032548614615402295 133:2.40625:6445:6446 ~0.019857712782554854 ~-0.048993690772603564 251:1.109375:6448:6451 255:0.234375:6449:6450 "
    s .= "~-0.00594507190255553 ~-0.04711222386639355 252:0.175:6452:6455 160:0.703125:6453:6454 ~-0.06937243437655767 ~0.026529361082369564 ~0.03156866312236364 187:-0.3125:6457:6458 ~-0.04168645027434077 127:0.265625:6459:6472 "
    s .= "88:0.328125:6460:6467 146:-0.375:6461:6466 135:-0.7265625:6462:6463 ~-0.09775230191092825 242:0.55:6464:6465 ~0.024874793155505625 ~-0.027895345557520088 ~-0.018225036140732984 13:0.421875:6468:6471 243:1.45:6469:6470 "
    s .= "~0.030103994827314035 ~-0.04120929992346839 ~-0.037883578361452556 216:0.2265625:6473:6484 79:0.375:6474:6477 44:-0.796875:6475:6476 ~0.004500034113701753 ~-0.04644321927564911 91:-0.25:6478:6479 ~-0.06434359138004302 "
    s .= "244:1.21:6480:6483 28:1.265625:6481:6482 ~-0.03277408471483028 ~0.06195678197402016 ~0.018932233682134564 103:0.25:6485:6486 ~0.029290533888163148 ~-0.007515235856449591 253:-0.05829228243021589:6488:6503 252:0.175:6489:6498 "
    s .= "71:0.15625:6490:6497 242:0.75:6491:6496 147:0.0390625:6492:6495 251:0.765625:6493:6494 ~-0.044351896666425486 ~0.018904010591572592 ~0.030592967585286204 ~-0.054767889153561816 ~-0.05808645588088294 19:-0.203125:6499:6500 "
    s .= "~-0.012204007905844123 1:0.671875:6501:6502 ~0.03402948438654458 ~-0.055708949989002866 243:1.55:6504:6529 248:1.375:6505:6528 73:1.140625:6506:6527 254:1.265625:6507:6522 2:0.3125:6508:6521 246:0.640625:6509:6518 "
    s .= "108:0.1796875:6510:6513 245:1.644736842105263:6511:6512 ~-0.038216060900820095 ~0.009056158230428227 85:1.265625:6514:6517 112:1.578125:6515:6516 ~-0.051965595433570835 ~0.02474815356805922 ~0.03353310952732682 "
    s .= "132:0.5703125:6519:6520 ~0.024917589079328742 ~-0.05307407810807723 ~-0.02236507794233215 29:-0.375:6523:6526 159:0.0703125:6524:6525 ~0.004214761663000685 ~-0.05100504332247624 ~-0.05979211483229461 ~-0.047198707918418445 "
    s .= "~-0.045376600247630273 72:0.1328125:6530:6531 ~-0.050978472629803685 121:-0.140625:6532:6533 ~-0.04234523503260332 ~0.02270897963541012 245:4.878048780487805:6535:6580 85:1.15625:6536:6575 251:1.484375:6537:6568 "
    s .= "159:0.2109375:6538:6563 217:-0.15625:6539:6540 ~-0.02702297315699866 255:0.234375:6541:6546 254:0.484375:6542:6543 ~-0.002996379980876059 191:0.09375:6544:6545 ~0.04225522324613266 ~-0.011249650824025919 241:0.14:6547:6552 "
    s .= "154:0.359375:6548:6549 ~-0.007480287518874693 208:0.546875:6550:6551 ~0.059432114244415316 ~-0.04308746415930511 5:-0.4375:6553:6560 164:-0.21875:6554:6559 136:1.640625:6555:6558 26:-1.15625:6556:6557 ~0.0187693543703412 "
    s .= "~-0.054908560957362365 ~0.03664568950696094 ~0.018865882793181386 100:1.09375:6561:6562 ~-0.04767662917886163 ~0.024093529346977366 55:-0.609375:6564:6565 ~0.05509668769035578 255:-0.046875:6566:6567 ~0.05650753488712214 "
    s .= "~-0.038128894435751834 252:0.375:6569:6574 172:0.46875:6570:6573 184:0.640625:6571:6572 ~-0.04053351729353722 ~0.02758290065305301 ~0.04011969017913299 ~0.027071871626969696 208:-0.078125:6576:6577 ~-0.015934357954540408 "
    s .= "73:0.65625:6578:6579 ~0.024485225564536445 ~-0.039311694472104516 ~-0.09126640011799009 118:0.28125:6582:6617 49:0.453125:6583:6612 245:3.8275862068965516:6584:6611 50:0.390625:6585:6610 254:0.984375:6586:6607 "
    s .= "235:-0.34375:6587:6588 ~-0.029088805361287596 88:0.328125:6589:6602 175:0.453125:6590:6601 79:1.375:6591:6600 238:-0.015625:6592:6595 35:-0.9375:6593:6594 ~0.03999838101905595 ~-0.03866062751682831 19:0.25:6596:6599 "
    s .= "239:-0.109375:6597:6598 ~0.013789052162892416 ~-0.025762925683612728 ~0.04159329596938637 ~0.03673943134026218 ~0.03319030725992064 67:0.234375:6603:6604 ~0.03584750244368955 199:0.203125:6605:6606 ~0.01886328921943702 "
    s .= "~-0.04272309795719654 50:-0.65625:6608:6609 ~0.011550400176534826 ~-0.016689387041784135 ~-0.02668077989147788 ~-0.05222964158058473 178:0.5:6613:6616 136:-0.046875:6614:6615 ~0.016174918689421263 ~-0.05558837104465214 "
    s .= "~0.006146238986472461 2:-0.40625:6618:6619 ~0.005020687557195062 79:0.3125:6620:6621 ~-0.037135382692745494 148:0.515625:6622:6627 196:0.609375:6623:6626 244:1.38:6624:6625 ~-0.03218234351426931 ~0.01806973973368764 "
    s .= "~0.06071350404370938 ~-0.04895817089803301 253:-0.05829228243021589:6629:6646 252:0.275:6630:6641 122:0.015625:6631:6640 99:-0.1171875:6632:6633 ~-0.022106080853193218 245:1.8111111111111111:6634:6635 ~-0.032780920619425946 "
    s .= "133:1.59375:6636:6637 ~0.03556172688110561 221:-0.5625:6638:6639 ~0.027629122261054396 ~-0.08627295003837787 ~-0.03348132229423866 238:0.53125:6642:6645 223:0.375:6643:6644 ~0.0346631285327229 ~-0.025761551166609244 "
    s .= "~-0.04599730892559516 243:1.55:6647:6670 248:1.375:6648:6669 73:1.140625:6649:6668 254:1.265625:6650:6665 2:0.3125:6651:6664 246:0.640625:6652:6659 108:0.1796875:6653:6656 245:1.644736842105263:6654:6655 ~-0.03662871190901326 "
    s .= "~0.008500587250828437 143:-0.65625:6657:6658 ~0.017080272501729138 ~-0.043485431335823756 132:0.5703125:6660:6663 239:0.34375:6661:6662 ~0.03252085223982209 ~-0.004439747956753281 ~-0.05201566471853208 ~-0.020996348250026147 "
    s .= "29:-0.375:6666:6667 ~-0.004318300646694333 ~-0.05840920153593193 ~-0.04451694745240576 ~-0.044489407128778184 245:2.127659574468085:6671:6672 ~-0.05151485345334596 110:0.015625:6673:6674 ~-0.05171070676122931 "
    s .= "~0.023301489534680177 159:0.5234375:6676:6719 157:1.15625:6677:6710 147:-0.1640625:6678:6683 160:1.15625:6679:6682 85:1.25:6680:6681 ~-0.03632552264485991 ~0.00946023974749449 ~0.01315455659836243 255:0.234375:6684:6697 "
    s .= "77:-0.0625:6685:6686 ~0.022920351709870754 232:0.21875:6687:6696 89:0.625:6688:6695 89:0.25:6689:6694 249:1.5:6690:6693 79:0.765625:6691:6692 ~0.0021266719771017685 ~0.0429525993244482 ~-0.04741412826734106 ~-0.03463688479502579 "
    s .= "~0.02924467828006662 ~-0.031260464014898154 11:-0.890625:6698:6699 ~0.0244095864307694 254:0.515625:6700:6701 ~0.025341467618144226 24:0.0078125:6702:6705 196:0.484375:6703:6704 ~-0.01421802834563584 ~0.02505015835632167 "
    s .= "252:1.225:6706:6707 ~-0.0400513719927546 244:1.015:6708:6709 ~-0.03625118127703011 ~0.03727305077602882 191:-0.203125:6711:6714 160:-0.234375:6712:6713 ~-0.044599573275503006 ~0.026961986663305144 172:-0.1875:6715:6716 "
    s .= "~-0.05446821875951285 130:1.625:6717:6718 ~0.01474087205401998 ~-0.03148471942307514 100:-0.53125:6720:6721 ~0.041257348553699565 ~-0.05132715700119385 28:0.5:6723:6766 100:1.09375:6724:6765 184:0:6725:6738 241:0.58:6726:6735 "
    s .= "127:-0.15625:6727:6730 160:-0.203125:6728:6729 ~-0.05019491052685735 ~0.03389593853309671 13:0.203125:6731:6732 ~-0.050812603781790144 1:0.15625:6733:6734 ~-0.05566416075879415 ~0.02551101472481177 243:1.35:6736:6737 "
    s .= "~0.033535303487384184 ~-0.019607333950025972 242:1.15:6739:6758 196:-0.1875:6740:6741 ~-0.019650899617645823 85:0.671875:6742:6755 82:-0.109375:6743:6744 ~0.028955043567249917 13:0.359375:6745:6754 158:-0.21875:6746:6749 "
    s .= "202:0.875:6747:6748 ~-0.03219402100448645 ~0.036155951005349574 74:0.03125:6750:6753 91:-0.0625:6751:6752 ~-0.03634872609935346 ~0.024712177804996474 ~-0.018993079768639138 ~-0.04735241452316481 208:-0.203125:6756:6757 "
    s .= "~-0.04542745151294657 ~0.026335150756720428 199:0.140625:6759:6762 235:0.171875:6760:6761 ~0.008681324044911091 ~-0.054443405739440946 109:1.234375:6763:6764 ~-0.061958969247438204 ~0.009217449827377457 ~0.023250363929207495 "
    s .= "69:0.1640625:6767:6768 ~-0.007763644410107098 ~-0.05114673921102954 251:0.484375:6770:6787 214:0.65625:6771:6782 178:0.015625:6772:6775 187:0.53125:6773:6774 ~-0.05049062563984848 ~0.010489965158918986 190:0.375:6776:6781 "
    s .= "193:-0.078125:6777:6778 ~-0.03406228124148218 71:0.265625:6779:6780 ~0.009804435769086343 ~-0.04464997132596662 ~-0.047580291014593955 115:0.21875:6783:6784 ~-0.0277041991356217 70:0.46875:6785:6786 ~0.06186191094942483 "
    s .= "~-0.03773790845720131 26:-0.765625:6788:6793 38:-0.3125:6789:6790 ~0.0250933434290686 85:1.46875:6791:6792 ~-0.06277479838920705 ~0.03934285020415478 254:1.296875:6794:6815 110:-0.9375:6795:6798 244:2.01:6796:6797 "
    s .= "~-0.07767926317336041 ~0.025664922702079065 191:0.59375:6799:6814 249:1.1666666666666665:6800:6813 34:0.859375:6801:6812 245:4.017543859649122:6802:6811 243:1.35:6803:6806 241:0.56:6804:6805 ~0.010035944598597081 "
    s .= "~0.029065797620253866 245:1.6219512195121952:6807:6808 ~-0.0700392126222487 40:-0.265625:6809:6810 ~-0.05441282713012329 ~0.014377030362507901 ~-0.06768206652521784 ~-0.0532791220810679 ~-0.01707920274153499 "
    s .= "~-0.033007927962131554 ~-0.033148824443304366 249:0.16666666666666666:6817:6840 253:-0.06723484848484773:6818:6819 ~0.02448458299631025 130:2.40625:6820:6839 228:0.3515625:6821:6836 55:0.34375:6822:6833 67:-0.25:6823:6824 "
    s .= "~-0.03901019437563806 154:0.4375:6825:6830 91:0.5:6826:6829 113:0.546875:6827:6828 ~-0.029369725416467502 ~0.030967458740437038 ~0.03824450029153645 156:0.2578125:6831:6832 ~0.03422558046768337 ~-0.03891797412191559 "
    s .= "244:1.515:6834:6835 ~-0.03322400994318883 ~0.015246493181900411 243:0.8500000000000001:6837:6838 ~-0.05504025504404211 ~0.0032475805591688535 ~-0.07413296150341503 184:-0.21875:6841:6842 ~-0.036761388711205385 "
    s .= "50:-0.609375:6843:6848 51:-0.4296875:6844:6847 106:1.640625:6845:6846 ~-0.045907265458901114 ~0.04420504439242123 ~0.0168293304664778 174:-0.078125:6849:6854 143:-0.046875:6850:6851 ~-0.040495306814031164 157:0.203125:6852:6853 "
    s .= "~0.0348177214442576 ~-0.03448720751694195 241:0.1:6855:6858 91:0.125:6856:6857 ~-0.018746890575268706 ~0.06188381685220197 95:0.171875:6859:6860 ~0.0019069493083884058 117:0.2421875:6861:6862 ~-0.04053937216469003 "
    s .= "~0.005592491837888857 251:0.734375:6864:6887 256:0.2857142857142857:6865:6886 64:1.375:6866:6885 250:0.9765625:6867:6880 214:0.578125:6868:6877 223:0.921875:6869:6876 169:0.21875:6870:6873 238:-0.09375:6871:6872 "
    s .= "~-0.035768078503588034 ~0.004783341217149531 112:-0.109375:6874:6875 ~0.03431980387480093 ~-0.04763044760135569 ~0.04683275748318497 115:0:6878:6879 ~-0.045169466574859346 ~0.04285974165543483 244:1.405:6881:6884 "
    s .= "10:1.453125:6882:6883 ~-0.03744273182182669 ~0.04861526361356363 ~0.00433689272876808 ~0.037146541115759345 ~-0.04859790812001946 157:0.96875:6888:6909 238:0.25:6889:6904 124:0.234375:6890:6899 121:-0.09375:6891:6894 "
    s .= "106:0.59375:6892:6893 ~-0.037970761308889156 ~0.012185320491836328 245:3.125:6895:6898 133:-0.078125:6896:6897 ~-0.04047443620263546 ~0.030876146425625535 ~-0.04549572119712039 55:1.171875:6900:6903 121:0.171875:6901:6902 "
    s .= "~0.001588787893988437 ~-0.04947787415573153 ~0.04199743297596076 154:0.609375:6905:6908 18:-0.3203125:6906:6907 ~0.04043167430535865 ~-0.05029067886882902 ~0.008059181357753124 ~0.01825613360636368 255:0.296875:6911:6930 "
    s .= "251:0.203125:6912:6917 178:0.4375:6913:6914 ~-0.045217074870572964 250:0.8203125:6915:6916 ~0.042614484838818203 ~-0.038456604400732904 119:0.453125:6918:6929 205:-0.25:6919:6920 ~-0.017015702120364042 133:2.40625:6921:6928 "
    s .= "53:0.0625:6922:6923 ~0.01992580256666722 31:0.140625:6924:6927 79:0.15625:6925:6926 ~-0.007644061903257971 ~0.02683185524367911 ~-0.029140904779104707 ~-0.053671439564921035 ~-0.017734173225175818 122:-0.28125:6931:6956 "
    s .= "247:0.265625:6932:6953 246:-0.390625:6933:6948 109:1.03125:6934:6943 103:-0.171875:6935:6936 ~0.02625224913768159 245:2.338709677419355:6937:6940 112:-0.140625:6938:6939 ~0.02926378191428521 ~-0.05169606906835017 "
    s .= "69:0.0390625:6941:6942 ~0.01608197542026957 ~-0.05602208220869245 160:-0.203125:6944:6945 ~-0.05974180155942439 148:0.46875:6946:6947 ~0.025681075130367916 ~-0.019348621183529174 44:0.03125:6949:6952 97:-0.125:6950:6951 "
    s .= "~-0.028710505051845227 ~0.035421092572638334 ~-0.037573779332463024 251:1.984375:6954:6955 ~-0.04767847910271934 ~0.030835029181435693 ~-0.021082639422048497 118:0.28125:6958:6993 49:0.34375:6959:6988 127:2.453125:6960:6987 "
    s .= "253:-0.02550884990132192:6961:6968 242:0.35:6962:6965 52:-0.28125:6963:6964 ~0.039198023772944096 ~-0.03800676868737801 256:0.8596491228070176:6966:6967 ~0.02492435876199352 ~-0.047354205014828475 94:-0.03125:6969:6974 "
    s .= "181:0.296875:6970:6973 89:0.640625:6971:6972 ~-0.0432684272848828 ~0.02456892267361417 ~0.005914767070410176 172:-0.25:6975:6976 ~-0.05079569192924419 214:0.578125:6977:6984 251:0.484375:6978:6981 193:0:6979:6980 "
    s .= "~-0.055061701278066116 ~0.0033247833313356616 238:0.359375:6982:6983 ~0.017968872181756437 ~-0.05020378594432162 108:0.1953125:6985:6986 ~0.05009074520171728 ~-0.05038272096533423 ~-0.08635639886252951 178:0.5:6989:6992 "
    s .= "31:-0.09375:6990:6991 ~0.005861278267660089 ~-0.0521936249823626 ~0.00917043147443892 163:1.265625:6994:7003 220:0.984375:6995:7002 241:0.1:6996:6997 ~0.025833829765852575 2:-0.515625:6998:7001 22:0.015625:6999:7000 "
    s .= "~0.021353253328222438 ~-0.024177126796360318 ~-0.034717902288307366 ~0.030792342003927393 ~0.02154753493373922 245:4.878048780487805:7005:7050 85:1.15625:7006:7043 251:1.484375:7007:7032 217:-0.125:7008:7009 ~-0.02861823115600619 "
    s .= "241:0.14:7010:7017 250:0.8671875:7011:7012 ~0.03443808138905901 103:-0.25:7013:7014 ~0.05419222743195471 46:1.140625:7015:7016 ~-0.028457457700791163 ~0.04492304409679904 255:0.234375:7018:7021 254:0.765625:7019:7020 "
    s .= "~-0.015178912508253237 ~0.03224697526131438 220:0.984375:7022:7031 100:1.25:7023:7030 205:0.734375:7024:7029 61:-0.4375:7025:7026 ~0.027099112240328085 203:-1.3125:7027:7028 ~0.031015121736852575 ~-0.04567191130723606 "
    s .= "~0.015167826484774058 ~0.02722827353891005 ~0.03444792629039416 252:0.375:7033:7038 46:0.375:7034:7037 181:0.640625:7035:7036 ~-0.0415594941008953 ~0.025907042085874 ~0.033952794856099165 243:1.25:7039:7040 ~0.041591269720181144 "
    s .= "245:1.6626506024096386:7041:7042 ~-0.0657819836944436 ~0.018059043405044165 208:-0.078125:7044:7045 ~-0.014512699602355714 73:0.65625:7046:7049 248:1.375:7047:7048 ~0.02480817560709894 ~-0.0664415373266151 ~-0.03741190469494355 "
    s .= "~-0.0834932682888712 159:0.5234375:7052:7097 124:-0.703125:7053:7054 ~-0.05214411770267611 154:1:7055:7092 142:-0.203125:7056:7059 106:1.09375:7057:7058 ~-0.043013667689899816 ~0.00920555842177187 112:0.40625:7060:7079 "
    s .= "235:0.265625:7061:7076 71:0.1875:7062:7071 238:0.234375:7063:7070 139:0.6875:7064:7067 50:0.1875:7065:7066 ~0.019281205682206697 ~-0.04786926104757005 58:-0.109375:7068:7069 ~0.036430122197770184 ~-0.038869884039927825 "
    s .= "~-0.03371797360785528 140:0.125:7072:7073 ~0.010797723717466824 214:0.8125:7074:7075 ~-0.056474854097200114 ~0.058601069164500245 140:-0.84375:7077:7078 ~0.027019945233345468 ~-0.04605808202175551 148:0.515625:7080:7087 "
    s .= "145:-0.078125:7081:7086 139:1.046875:7082:7085 130:0.921875:7083:7084 ~-0.04013102792596955 ~0.013172244000591788 ~0.03790947867993489 ~0.01709626574981106 123:0.1015625:7088:7089 ~-0.04240815316703397 121:0.453125:7090:7091 "
    s .= "~0.0335330669395638 ~-0.039157381920151835 118:0.59375:7093:7096 136:2.1875:7094:7095 ~0.02010808321475417 ~-0.04327894069625813 ~-0.021285970940476913 ~-0.0366013772226448 253:-0.05829228243021589:7099:7118 252:0.275:7100:7113 "
    s .= "17:-0.09375:7101:7110 36:-0.0546875:7102:7109 194:-1.125:7103:7104 ~0.04104659886579045 251:1.296875:7105:7108 24:0.1171875:7106:7107 ~-0.07552437086640097 ~0.021513283337039876 ~0.026356556258785375 ~0.025508826923340028 "
    s .= "161:-0.125:7111:7112 ~0.02471814129937782 ~-0.04465083132061798 235:0.359375:7114:7117 37:-0.28125:7115:7116 ~-0.02960193487331967 ~0.03554232935456854 ~-0.02330060366151791 243:1.55:7119:7140 248:1.375:7120:7137 "
    s .= "254:1.265625:7121:7132 73:0.625:7122:7129 171:-0.34375:7123:7124 ~-0.02425908646277331 87:-0.1640625:7125:7126 ~0.02234301209722464 133:2.046875:7127:7128 ~0.004265646731177336 ~-0.03825125226045438 112:1:7130:7131 "
    s .= "~-0.05203534222075427 ~0.005101416033603114 29:-0.375:7133:7136 171:0.046875:7134:7135 ~0.0060361862591542005 ~-0.0380043626284894 ~-0.05577780669572455 46:1.4375:7138:7139 ~-0.05674958428098847 ~0.043076621542605095 "
    s .= "134:0.03125:7141:7142 ~-0.05507634372679285 245:1.736842105263158:7143:7144 ~-0.060785700685399124 ~0.012832773262915223 70:0.609375:7146:7189 88:1.109375:7147:7184 100:1.09375:7148:7179 251:1.328125:7149:7172 "
    s .= "156:0.2109375:7150:7165 122:0.09375:7151:7164 255:0.234375:7152:7155 156:0.0078125:7153:7154 ~-0.008114253106200163 ~0.031432203218643186 98:-0.515625:7156:7157 ~0.004777398090720718 241:0.12:7158:7161 154:0.390625:7159:7160 "
    s .= "~-0.03818058487257996 ~0.04314637751659149 79:0.6875:7162:7163 ~-0.04692506434128474 ~0.0006089003071614906 ~-0.026174102700284148 241:0.1:7166:7169 250:0.8359375:7167:7168 ~0.05988493317233223 ~-0.03821972261182381 "
    s .= "253:-0.11176470588235328:7170:7171 ~0.022086493668562857 ~-0.05622843060593551 125:-0.25:7173:7176 124:0.484375:7174:7175 ~0.03278875098392755 ~-0.0502907008089616 86:0.75:7177:7178 ~-0.0137064504334993 ~0.03360545135968079 "
    s .= "46:-0.328125:7180:7181 ~-0.05545120478999393 1:0.453125:7182:7183 ~0.033941763505663296 ~-0.038631325855154004 202:-0.0625:7185:7188 72:0.1953125:7186:7187 ~-0.026665983168211484 ~0.03206417790145525 ~0.02539549283529349 "
    s .= "178:0.15625:7190:7191 ~0.005997482856612852 ~-0.04525743673698097 249:0.16666666666666666:7193:7206 253:-0.06723484848484773:7194:7195 ~0.023262163924676855 130:2.40625:7196:7205 228:0.3515625:7197:7202 37:0.703125:7198:7201 "
    s .= "73:-0.34375:7199:7200 ~-0.04214166177016902 ~0.012548980035511949 ~-0.03460479039110139 243:0.8500000000000001:7203:7204 ~-0.052716080790904896 ~0.0040110992614172366 ~-0.06980160564839705 184:-0.21875:7207:7208 "
    s .= "~-0.035512228178832726 127:0.28125:7209:7220 245:1.381578947368421:7210:7211 ~-0.044139917782963556 19:0.984375:7212:7219 251:0.171875:7213:7214 ~-0.03638411755611367 28:0.5:7215:7216 ~0.013371129957537368 175:0.375:7217:7218 "
    s .= "~-0.06855801440865016 ~0.029287112220371586 ~-0.043139695393745243 216:0.2265625:7221:7234 211:0.484375:7222:7231 249:0.5:7223:7228 85:0.546875:7224:7227 76:-0.0625:7225:7226 ~0.00972552243083994 ~-0.05748236582649217 "
    s .= "~0.01590239629653544 219:0.7109375:7229:7230 ~-0.04746780228915845 ~0.03151643433613328 232:0.484375:7232:7233 ~0.02897473112309126 ~-0.030039310894715232 205:0.59375:7235:7238 109:1.03125:7236:7237 ~-0.023583302913725318 "
    s .= "~0.0277202590555205 ~0.03500724747557991 245:4.878048780487805:7240:7285 249:0.16666666666666666:7241:7250 90:0.0859375:7242:7245 67:-0.328125:7243:7244 ~-0.028590946172932577 ~0.01696759230990148 31:0.140625:7246:7249 "
    s .= "15:0.0234375:7247:7248 ~-0.04654841008815896 ~0.011454036626677044 ~-0.03366748191543411 187:-0.34375:7251:7252 ~-0.042996895988204005 122:0:7253:7274 168:0.0546875:7254:7267 160:1.140625:7255:7266 41:-0.375:7256:7265 "
    s .= "243:0.25:7257:7258 ~-0.060530909152358925 85:0.09375:7259:7260 ~-0.03230662061320116 114:-0.1328125:7261:7264 235:0.03125:7262:7263 ~-0.059616594952359575 ~0.010753893305720814 ~0.03122544104612815 ~-0.03292917285784949 "
    s .= "~0.015822492135954658 183:0.0546875:7268:7269 ~0.030835659010971198 255:0.234375:7270:7271 ~0.019344161951075224 28:-0.484375:7272:7273 ~0.04448847949428727 ~-0.022344564269697664 168:0.5390625:7275:7284 241:0.1:7276:7279 "
    s .= "154:0.40625:7277:7278 ~-0.0487436580623301 ~0.07248242435479411 79:0.765625:7280:7283 72:0.2109375:7281:7282 ~-0.046802692839009896 ~-0.011192979429173052 ~0.003121790748587533 ~0.023054580065888976 ~-0.08009742594919556 "
    s .= "255:0.296875:7287:7304 251:0.203125:7288:7291 178:0.4375:7289:7290 ~-0.04387397916569211 ~0.012272945834189712 119:0.453125:7292:7303 133:2.40625:7293:7302 205:-0.25:7294:7295 ~-0.015653839777038426 254:0.703125:7296:7299 "
    s .= "254:0.265625:7297:7298 ~0.013585120556919246 ~-0.015059151811616071 162:0.3203125:7300:7301 ~0.0294468189534293 ~-0.024122628402239152 ~-0.04469471500443267 ~-0.016221422828173054 146:-0.234375:7305:7324 247:0.234375:7306:7321 "
    s .= "246:-0.390625:7307:7318 109:1.03125:7308:7313 245:1.9875:7309:7312 96:-0.3203125:7310:7311 ~0.012827043047780604 ~-0.060750728418500544 ~-0.0035849528716387913 160:-0.03125:7314:7317 94:-0.046875:7315:7316 ~0.012381644856651587 "
    s .= "~-0.08138108093030574 ~0.017245541799468175 129:0.1015625:7319:7320 ~0.030062842818295576 ~-0.01581527293372073 251:1.984375:7322:7323 ~-0.04147967077471593 ~0.03277191972900457 254:0.515625:7325:7326 ~0.018748002672333754 "
    s .= "252:0.275:7327:7330 103:-0.625:7328:7329 ~0.052230466431983674 ~-0.0451920819982241 140:-0.125:7331:7332 ~0.019131960834386088 ~-0.026238904322996304 194:0.625:7334:7379 89:0.625:7335:7374 245:1.5866666666666667:7336:7339 "
    s .= "113:0.609375:7337:7338 ~-0.05602379777188157 ~0.022085835575060806 34:0.90625:7340:7373 130:2.46875:7341:7370 160:1.140625:7342:7367 55:1.171875:7343:7366 147:-0.2578125:7344:7345 ~-0.03619486872846766 25:0.640625:7346:7365 "
    s .= "178:1.109375:7347:7364 244:1.985:7348:7361 44:0.390625:7349:7360 113:-0.03125:7350:7357 245:1.9423076923076923:7351:7352 ~-0.031498300045655625 253:-0.07323867478025742:7353:7354 ~0.032709994198015006 94:0.28125:7355:7356 "
    s .= "~0.004013214961422039 ~-0.04716280776148897 4:-0.03125:7358:7359 ~-0.006703093089213314 ~0.02229482230995253 ~-0.037482995987665295 181:0.96875:7362:7363 ~-0.053432853736144564 ~0.03526831555237434 ~0.028854392852614225 "
    s .= "~-0.04808246824507423 ~0.03569652010043069 238:-0.203125:7368:7369 ~-0.025032861195972644 ~0.021646026790897693 168:-0.1796875:7371:7372 ~0.010905562284633026 ~-0.08168715308822488 ~-0.0316611624478659 235:0.328125:7375:7378 "
    s .= "95:0.53125:7376:7377 ~0.0399173762360052 ~-0.009923080374354914 ~-0.03747711305408976 ~-0.03471091698211003 191:-0.6875:7381:7394 52:0.25:7382:7389 190:0.453125:7383:7386 211:-0.0625:7384:7385 ~-0.010431583769215554 "
    s .= "~0.033484765029180685 244:1.4:7387:7388 ~-0.050581250363598056 ~0.030225720810480746 245:2.122448979591837:7390:7391 ~-0.04885241529784571 70:0.484375:7392:7393 ~0.022997750491383837 ~-0.05227696110134997 255:0.234375:7395:7412 "
    s .= "246:-1.703125:7396:7397 ~-0.04626246100095916 77:-0.0625:7398:7403 246:-0.015625:7399:7402 90:0.3046875:7400:7401 ~0.012309812871454542 ~-0.051576690906142524 ~0.029200446635656324 248:1.125:7404:7411 218:0.640625:7405:7410 "
    s .= "97:-0.09375:7406:7407 ~-0.016973961375261873 202:0.203125:7408:7409 ~0.020095561191635823 ~-0.016905263050792166 ~-0.04817257301506691 ~-0.047834533903905366 156:0.1484375:7413:7426 254:0.515625:7414:7417 96:-0.2109375:7415:7416 "
    s .= "~-0.03999035517373158 ~0.034334993246670734 26:-0.3125:7418:7423 134:-0.40625:7419:7420 ~-0.02387050352679423 239:-0.03125:7421:7422 ~0.015720383860735366 ~-0.032422400361813604 190:0.84375:7424:7425 ~-0.031086224521699297 "
    s .= "~0.02106083629119564 ~-0.032426290257752365 124:-0.703125:7428:7429 ~-0.05057870979026327 85:1.15625:7430:7465 251:1.484375:7431:7454 159:0.2109375:7432:7447 46:0.078125:7433:7436 238:-0.359375:7434:7435 ~-0.054572064986757124 "
    s .= "~0.005214150721876988 160:1.40625:7437:7446 145:-0.078125:7438:7439 ~-0.053953164890554656 242:0.25:7440:7441 ~0.03997789867876268 220:0.984375:7442:7445 49:0.265625:7443:7444 ~-0.010952892827888083 ~-0.05475401608019509 "
    s .= "~0.0354153577010015 ~0.029703145800072633 31:-0.265625:7448:7451 202:0.09375:7449:7450 ~0.03881002234575047 ~-0.054971888252218486 255:0.015625:7452:7453 ~0.019493061336371322 ~-0.041826699077891036 252:0.375:7455:7460 "
    s .= "46:0.375:7456:7459 181:0.640625:7457:7458 ~-0.04010054780014291 ~0.02438296736986598 ~0.03259794419367648 22:-0.25:7461:7464 88:0.234375:7462:7463 ~-0.08856916697861647 ~0.01292632214402077 ~0.03318539283491724 "
    s .= "208:-0.078125:7466:7467 ~-0.012366992031910095 248:1.375:7468:7473 87:0.3984375:7469:7472 245:4.878048780487805:7470:7471 ~0.025705817223841545 ~-0.08498469131027674 ~-0.024121784801732223 ~-0.06276660454454945 "
    s .= "159:0.5234375:7475:7520 254:1.296875:7476:7515 248:1.375:7477:7514 118:0.28125:7478:7505 91:0.15625:7479:7500 151:0.640625:7480:7497 178:0.640625:7481:7494 252:0.175:7482:7491 79:-0.125:7483:7486 168:0.2734375:7484:7485 "
    s .= "~-0.020199132684876508 ~0.03429863860972549 205:0.265625:7487:7488 ~-0.044654293809038216 146:0.09375:7489:7490 ~0.013574466777081975 ~-0.05773011771477859 49:0.109375:7492:7493 ~0.019332310496484373 ~-0.03580437916432004 "
    s .= "205:-0.109375:7495:7496 ~-0.030497640641484206 ~0.029967352113199976 142:-0.359375:7498:7499 ~-0.05337843121668487 ~0.02886176915064713 22:-0.203125:7501:7504 242:0.8500000000000001:7502:7503 ~0.01180722222933633 "
    s .= "~-0.04711799013690784 ~0.0211167649659041 241:0.1:7506:7507 ~0.03226306229645314 163:1.140625:7508:7513 220:0.9375:7509:7512 2:-0.5:7510:7511 ~0.0005935547754421531 ~-0.03198287606330705 ~0.03813493986840212 ~0.019812223568568828 "
    s .= "~-0.03951057660269848 50:-0.25:7516:7519 191:-1:7517:7518 ~0.017669016061408464 ~-0.016647970762908602 ~-0.05812069471038003 ~-0.03455141376337346 251:0.734375:7522:7545 256:0.2857142857142857:7523:7544 64:1.375:7524:7543 "
    s .= "250:0.9765625:7525:7538 214:0.578125:7526:7535 223:0.921875:7527:7534 169:0.21875:7528:7531 238:-0.09375:7529:7530 ~-0.03409523454390737 ~0.0042499372845079654 112:-0.109375:7532:7533 ~0.03306788292076563 ~-0.04513567741887406 "
    s .= "~0.043318625497537164 115:0:7536:7537 ~-0.04429937330659878 ~0.039380023215835724 244:1.405:7539:7542 10:1.453125:7540:7541 ~-0.03624831211112895 ~0.04512737312793599 ~0.003973492725264131 ~0.035828639396801865 "
    s .= "~-0.04651428325633425 244:2.86:7546:7567 157:0.96875:7547:7562 238:0.25:7548:7557 46:-0.203125:7549:7550 ~-0.023667717695290098 17:0.46875:7551:7556 158:-0.46875:7552:7555 109:0.5:7553:7554 ~-0.0549897047816321 "
    s .= "~0.010033599153870662 ~0.019217546721362236 ~-0.03406688254125014 172:0.296875:7558:7561 178:0.90625:7559:7560 ~-0.05112912702951897 ~0.02914206915086133 ~0.00729179862657808 236:-0.125:7563:7564 ~0.02929077255320789 "
    s .= "229:-0.1875:7565:7566 ~-0.05486157509093237 ~0.010790394043243702 ~-0.05423419739131066 124:-0.703125:7569:7570 ~-0.049825113218403425 88:1.109375:7571:7608 79:1.171875:7572:7605 117:-0.2421875:7573:7576 163:1.265625:7574:7575 "
    s .= "~-0.03767694434639536 ~0.03171179417564759 108:-0.2265625:7577:7580 139:1.015625:7578:7579 ~0.034906855200210446 ~-0.04733372785969007 255:0.234375:7581:7592 254:0.703125:7582:7587 86:0.875:7583:7586 "
    s .= "245:1.5866666666666667:7584:7585 ~-0.05645052080360807 ~-0.005114449390064448 ~0.029522128252669474 218:0.09375:7588:7589 ~0.03527253888001964 245:1.87:7590:7591 ~0.025747028620927898 ~-0.04555632977853125 100:-0.328125:7593:7594 "
    s .= "~0.029033730233858523 180:0.0546875:7595:7600 168:0.0546875:7596:7599 97:0.4375:7597:7598 ~-0.024857703445752374 ~0.01691811112714293 ~0.016617501583325204 251:1.828125:7601:7602 ~-0.04422917823034046 217:0.21875:7603:7604 "
    s .= "~0.029533778857292487 ~-0.07319353672460692 133:1.984375:7606:7607 ~0.023030616733382914 ~-0.04780546233715188 70:0.53125:7609:7614 193:-0.03125:7610:7611 ~-0.0014498642616048037 217:0.5625:7612:7613 ~0.03541916892057991 "
    s .= "~-0.028920806424623708 ~-0.029900131640519186 28:0.5:7616:7653 184:0.0625:7617:7632 252:0.42500000000000004:7618:7629 127:0.890625:7619:7628 250:0.9296875:7620:7625 221:0.125:7621:7624 245:4.017543859649122:7622:7623 "
    s .= "~0.01782932686507471 ~-0.06235688522108682 ~-0.04248159129121011 125:-0.46875:7626:7627 ~-0.0007737895730886669 ~-0.046627127314069566 ~-0.05997684707813533 46:-0.15625:7630:7631 ~-0.025726558507558357 ~0.029979525339408564 "
    s .= "142:0.21875:7633:7646 148:0.15625:7634:7639 249:1.8333333333333335:7635:7638 251:0.140625:7636:7637 ~-0.04986590106577892 ~0.022916729718067054 ~-0.041936326106029626 142:-0.1875:7640:7641 ~-0.04038915677287851 "
    s .= "220:-0.15625:7642:7643 ~-0.049402645162785315 130:0.59375:7644:7645 ~-0.014541234843203377 ~0.02555569342503954 244:1.035:7647:7652 136:1.09375:7648:7651 220:0.5625:7649:7650 ~-0.04702790449007691 ~0.01679258104327494 "
    s .= "~0.035485540186375904 ~0.004190874156974022 184:0.1875:7654:7657 40:0:7655:7656 ~-0.052057441380499316 ~0.016151275148522118 115:1.90625:7658:7661 240:-0.640625:7659:7660 ~0.01176219862195775 ~-0.05700776732949056 "
    s .= "~0.039840835648952064 245:4.878048780487805:7663:7708 249:0.16666666666666666:7664:7681 253:-0.06723484848484773:7665:7666 ~0.023596234537769212 73:0.203125:7667:7680 64:-0.25:7668:7669 ~-0.03647621938198986 "
    s .= "90:0.0859375:7670:7673 205:-0.09375:7671:7672 ~-0.014738038052431707 ~0.025292196720663532 251:0.796875:7674:7677 220:0.328125:7675:7676 ~-0.048670560092237934 ~0.02778897271329871 31:0.140625:7678:7679 ~0.02491830686769744 "
    s .= "~-0.040245771151412424 ~-0.015554775752647418 184:-0.265625:7682:7683 ~-0.03819781629367297 127:0.28125:7684:7701 91:0.125:7685:7694 88:0.3125:7686:7691 35:0.09375:7687:7690 99:-0.2421875:7688:7689 ~-0.054619702382773916 "
    s .= "~0.0003364157726270798 ~-0.05197211089624603 141:0.0859375:7692:7693 ~-0.010481954842920123 ~0.03991472941099706 243:1.45:7695:7700 31:-0.046875:7696:7697 ~0.03883390778868717 85:0.09375:7698:7699 ~-0.04651281308919684 "
    s .= "~0.015251025158704896 ~-0.035997004336768466 216:0.1953125:7702:7707 79:0.375:7703:7704 ~-0.03384422028710446 91:-0.25:7705:7706 ~-0.06578396841214249 ~0.0009152338125257632 ~0.0056737463241029245 ~-0.07490549098983122 "
    s .= "254:1.296875:7710:7753 248:1.375:7711:7752 256:0.9583333333333334:7712:7751 118:0.28125:7713:7736 49:0.453125:7714:7733 245:3.8275862068965516:7715:7732 211:-0.296875:7716:7719 244:1.46:7717:7718 ~-0.04154576989828779 "
    s .= "~0.02421580131463642 194:0.109375:7720:7725 85:0.609375:7721:7724 45:-0.3046875:7722:7723 ~-0.04747771223574152 ~0.01177240845855756 ~0.026771283556027523 57:0.2890625:7726:7731 187:0.328125:7727:7730 252:0.275:7728:7729 "
    s .= "~-0.04602071716773434 ~-0.000630247303849004 ~0.016756762642410317 ~0.023068328886257383 ~-0.04223908179955149 178:0.5:7734:7735 ~-0.03602051243355917 ~0.01134722135672698 163:-0.078125:7737:7738 ~-0.047536776192574126 "
    s .= "148:0.515625:7739:7750 196:0.609375:7740:7749 157:0.828125:7741:7748 127:0.109375:7742:7743 ~0.016423156389469402 250:0.8515625:7744:7745 ~-0.07182360175868698 124:0.40625:7746:7747 ~-0.03502772296538319 ~0.017789887905101772 "
    s .= "~0.017988474972588025 ~0.039045908943917074 ~-0.027179920273796673 ~-0.04016525844290584 ~-0.039049856361749014 38:-0.59375:7754:7755 ~0.0015127420128832683 ~-0.03604651716615203 145:-0.109375:7757:7770 244:1.4:7758:7767 "
    s .= "147:-0.1015625:7759:7760 ~-0.06194278304593645 1:0.140625:7761:7766 245:2.0701754385964914:7762:7763 ~-0.026567470952257984 191:0.046875:7764:7765 ~0.03786758341752509 ~-0.023297676108718888 ~-0.05738042259097013 "
    s .= "113:0.1875:7768:7769 ~0.01387432639558387 ~-0.03273915904175286 252:0.32499999999999996:7771:7798 207:0.3203125:7772:7795 130:2.46875:7773:7794 242:0.8500000000000001:7774:7793 73:0.90625:7775:7792 154:0.40625:7776:7789 "
    s .= "127:1.109375:7777:7788 251:0.328125:7778:7781 16:-0.0625:7779:7780 ~0.016112051222905304 ~-0.04866897294480002 142:-0.28125:7782:7783 ~-0.06783117394200085 2:0.0625:7784:7787 139:1.125:7785:7786 ~0.024367250929973792 "
    s .= "~-0.027436063217713948 ~-0.02511825512180836 ~-0.05825497316063704 67:0.546875:7790:7791 ~0.022340830788927082 ~-0.031856162797531215 ~-0.04475290394198702 ~-0.02751983989575829 ~-0.07455319724991616 31:-0.28125:7796:7797 "
    s .= "~0.022634774141301675 ~-0.0405886331958294 253:-0.03939393939393909:7799:7800 ~0.029359437009183278 202:0.203125:7801:7802 ~0.012744078491239236 ~-0.02564611871910377 255:0.296875:7804:7821 251:0.203125:7805:7810 "
    s .= "178:0.4375:7806:7807 ~-0.04234221143574346 250:0.8203125:7808:7809 ~0.03704035554718941 ~-0.03703236996008135 143:0.1875:7811:7818 142:0.578125:7812:7815 109:1.859375:7813:7814 ~0.017377188909118012 ~-0.013350305660370702 "
    s .= "115:0.828125:7816:7817 ~-0.0339607807516027 ~0.01902109797502527 236:0.328125:7819:7820 ~0.00421541588441104 ~-0.024020571464457158 122:-0.25:7822:7847 247:0.234375:7823:7844 246:-0.390625:7824:7839 82:1.140625:7825:7838 "
    s .= "82:0.59375:7826:7835 109:0.53125:7827:7832 58:-0.140625:7828:7829 ~0.020440690331851474 139:0.515625:7830:7831 ~-0.062220101384488996 ~0.003583998097993148 151:0.4375:7833:7834 ~0.022728939217702096 ~-0.021762953842225718 "
    s .= "251:1.265625:7836:7837 ~-0.06725021437184846 ~0.01637908830701509 ~0.01825537801225372 44:0.03125:7840:7843 97:-0.125:7841:7842 ~-0.026876927224615862 ~0.03188320299227361 ~-0.0308307838020873 251:1.984375:7845:7846 "
    s .= "~-0.03974677930543118 ~0.030990848922992333 19:-0.09375:7848:7849 ~-0.03934985193679774 ~-0.011280605106880828 191:-0.6875:7851:7864 52:0.25:7852:7859 190:0.453125:7853:7856 211:-0.0625:7854:7855 ~-0.011153402715330428 "
    s .= "~0.03212687732238317 160:1.03125:7857:7858 ~-0.04445295890948068 ~0.03490207323930782 245:2.122448979591837:7860:7861 ~-0.045291164436570164 70:0.484375:7862:7863 ~0.021745239792470037 ~-0.05051594036143885 255:0.234375:7865:7882 "
    s .= "246:-1.078125:7866:7867 ~-0.03653908923329137 77:-0.0625:7868:7871 110:0:7869:7870 ~0.005965269599214586 ~0.02913627233177282 190:-0.125:7872:7873 ~-0.028926230975874614 202:0.203125:7874:7879 97:-0.09375:7875:7876 "
    s .= "~-0.018516687140444087 143:0.078125:7877:7878 ~0.03346167283331223 ~0.0022802894035069696 254:0.015625:7880:7881 ~0.01820689318637934 ~-0.02765903499366272 159:0.2578125:7883:7896 254:0.515625:7884:7887 96:-0.2109375:7885:7886 "
    s .= "~-0.040048264503109124 ~0.03020404713444455 233:0.296875:7888:7895 2:-0.28125:7889:7892 193:-0.203125:7890:7891 ~-0.03548570102199935 ~0.00316642151323435 190:0.84375:7893:7894 ~-0.03001619806790988 ~0.026554152883123766 "
    s .= "~-0.05548338460048813 ~-0.0408643710492172 251:0.734375:7898:7921 64:1.375:7899:7920 250:0.9765625:7900:7917 214:0.578125:7901:7912 223:0.921875:7902:7911 214:0.25:7903:7908 238:-0.09375:7904:7905 ~-0.03299263946880417 "
    s .= "109:1.5625:7906:7907 ~0.0067414021161788925 ~-0.047482317958631455 235:0.859375:7909:7910 ~-0.04817067788410573 ~0.054629367191970805 ~0.04051610494940796 115:0.09375:7913:7914 ~-0.0314351936680774 46:0.53125:7915:7916 "
    s .= "~0.046470437685491445 ~-0.05032970089639437 244:1.365:7918:7919 ~-0.03319124266463726 ~0.0010122269909370431 ~0.03017656985396233 109:0.53125:7922:7931 250:1.2578125:7923:7930 163:0.109375:7924:7929 178:-0.0625:7925:7926 "
    s .= "~-0.055466233462295435 94:-0.03125:7927:7928 ~-0.02922801511136233 ~0.029955779208072186 ~-0.028029241025512047 ~0.01988048156759381 191:-0.390625:7932:7933 ~0.022650617807292325 248:0.875:7934:7943 46:-0.28125:7935:7936 "
    s .= "~-0.028829771831485426 241:0.46:7937:7940 52:0.125:7938:7939 ~-0.027463943745126104 ~0.021140597982793143 19:0.59375:7941:7942 ~0.028871456045927554 ~-0.0602409079580589 ~-0.02981058443121526 254:1.296875:7945:7986 "
    s .= "248:1.375:7946:7985 242:2.05:7947:7982 142:0.6875:7948:7977 252:0.42500000000000004:7949:7972 184:0.046875:7950:7961 250:0.9453125:7951:7958 115:0.546875:7952:7957 197:0.140625:7953:7956 245:4.017543859649122:7954:7955 "
    s .= "~0.028190939413629962 ~-0.05943165614582483 ~-0.04043713108095492 ~-0.04921105311880039 8:-0.453125:7959:7960 ~-0.007303434970947076 ~-0.049310288178519485 242:0.6499999999999999:7962:7967 214:0.609375:7963:7966 "
    s .= "2:0.296875:7964:7965 ~0.013668544216177358 ~-0.04743031855226322 ~0.041905264040222205 241:0.36:7968:7969 ~-0.05816102232058415 28:0.390625:7970:7971 ~0.011867074331740942 ~-0.04950721890718357 145:-0.140625:7973:7974 "
    s .= "~-0.016721793025083108 199:0.328125:7975:7976 ~0.028951669889503148 ~-0.00884358446847945 234:0.3671875:7978:7981 163:-0.046875:7979:7980 ~-0.05973794832788858 ~0.002013587035807548 ~-0.05711575513881854 120:0.1171875:7983:7984 "
    s .= "~-0.05094231444180648 ~0.0013935049364541038 ~-0.03760731635857291 50:-0.25:7987:7990 247:0.171875:7988:7989 ~-0.00022895392650346686 ~-0.044403476728825705 ~-0.05659391977031587 251:0.671875:7992:8009 46:0.078125:7993:8002 "
    s .= "64:-0.375:7994:7995 ~-0.05046466361059152 205:0.046875:7996:7999 79:0.140625:7997:7998 ~-0.03293686898584183 ~0.006311805664584044 55:0.1875:8000:8001 ~0.02197883428061038 ~-0.01869782192109925 193:-0.046875:8003:8004 "
    s .= "~-0.044624764119703314 193:0.203125:8005:8006 ~0.0038418383565920243 130:1.359375:8007:8008 ~-0.05148404790843139 ~0.02146816037658501 238:0.484375:8010:8033 184:0.15625:8011:8024 241:0.56:8012:8023 127:0.890625:8013:8022 "
    s .= "204:0.3515625:8014:8019 106:1.28125:8015:8018 106:-0.171875:8016:8017 ~-0.05879193951161202 ~0.015634432865782713 ~-0.04351608283498521 140:-0.0625:8020:8021 ~-0.003425615812631544 ~-0.07287385506708431 ~-0.05545851683475081 "
    s .= "~0.020027571649834652 28:0.8125:8025:8032 191:-0.15625:8026:8027 ~0.025811148606709147 22:-0.25:8028:8031 171:0.34375:8029:8030 ~-0.06470815525932809 ~0.02267984650432929 ~0.010004061258129285 ~-0.05068748813598717 "
    s .= "136:1.046875:8034:8037 199:0.9375:8035:8036 ~-0.05265249145043334 ~0.011105386232189034 ~0.018534305366999952 253:-0.05592105263157876:8039:8062 252:0.175:8040:8053 71:0.15625:8041:8052 242:0.75:8042:8051 133:1.59375:8043:8048 "
    s .= "251:0.453125:8044:8047 127:0.15625:8045:8046 ~0.02586369845038978 ~-0.053945152124584755 ~0.033646349901415566 199:0.078125:8049:8050 ~-0.07467569544265233 ~0.024690377065358926 ~-0.04997623299521951 ~-0.05072572243060626 "
    s .= "238:0.53125:8054:8061 249:0.5:8055:8058 119:0.75:8056:8057 ~0.03487166933561118 ~-0.059407826332719585 250:1.1328125:8059:8060 ~-0.0261930221720541 ~0.028913940704344488 ~-0.040981150928284346 242:2.05:8063:8082 "
    s .= "73:1.140625:8064:8081 254:1.296875:8065:8076 248:1.375:8066:8075 50:0.40625:8067:8074 246:0.640625:8068:8073 108:0.1796875:8069:8072 191:0.09375:8070:8071 ~0.007042325624890062 ~-0.022018026615283688 ~-0.025234179077579168 "
    s .= "~0.01728004712238834 ~-0.024295337274486545 ~-0.04106415028096297 14:-0.59375:8077:8080 159:-0.0703125:8078:8079 ~0.011829645634397042 ~-0.035218303651978554 ~-0.04490397086332021 ~-0.04219550802435399 142:0.953125:8083:8084 "
    s .= "~-0.04912622034481543 ~0.03181710521207764 159:0.5234375:8086:8131 100:1.09375:8087:8128 242:1.25:8088:8121 184:0:8089:8102 241:0.58:8090:8099 202:0.515625:8091:8098 148:-0.109375:8092:8095 250:0.8671875:8093:8094 "
    s .= "~0.03332799670797649 ~-0.02971425316757086 46:0.703125:8096:8097 ~-0.05259805883130059 ~0.03236032582494713 ~0.025047030319478098 248:0.375:8100:8101 ~0.04113478071029545 ~-0.03587476803801973 97:0.765625:8103:8120 "
    s .= "85:1.25:8104:8117 193:-0.046875:8105:8106 ~-0.012850902344709494 113:-0.140625:8107:8112 112:1.34375:8108:8111 151:0.640625:8109:8110 ~-0.026975304037656897 ~0.016708934944050794 ~0.028475961067451795 119:-0.234375:8113:8114 "
    s .= "~0.037098150424281204 94:0.015625:8115:8116 ~-0.018775749571198607 ~0.017474342440416214 208:-0.1875:8118:8119 ~-0.03462775231942399 ~0.02686665937244996 ~-0.0453304234310524 245:2.3582089552238807:8122:8125 "
    s .= "160:0.453125:8123:8124 ~-0.013211543665804015 ~-0.052183428269018096 3:0.0390625:8126:8127 ~-0.018939132442743454 ~0.035320164883492974 1:0.453125:8129:8130 ~0.024337567270457713 ~-0.03415472346086362 ~-0.03233040126943191 "
    s .= "245:4.878048780487805:8133:8178 85:1.15625:8134:8165 251:1.484375:8135:8162 174:0.5625:8136:8161 241:0.12:8137:8150 208:0.546875:8138:8149 154:0.359375:8139:8148 37:0.0625:8140:8145 94:0.078125:8141:8144 238:-0.171875:8142:8143 "
    s .= "~0.040949004096761416 ~-0.039932059837085504 ~0.03890058008826064 3:0.4453125:8146:8147 ~-0.04946088454798489 ~0.03382013043808312 ~0.04724523750298395 ~-0.04857417033085318 255:0.265625:8151:8156 254:0.703125:8152:8155 "
    s .= "136:1.09375:8153:8154 ~-0.022541509588537137 ~0.007549606626672541 ~0.025673132977566817 98:-0.515625:8157:8158 ~-0.006294602634684602 100:1.203125:8159:8160 ~-0.03725754004563135 ~0.019774068286397 ~-0.04719857697106445 "
    s .= "252:0.375:8163:8164 ~-0.004453409813820472 ~0.023047523543740324 208:-0.234375:8166:8167 ~-0.022250921071826083 218:-0.1875:8168:8173 73:0.65625:8169:8172 114:-0.7890625:8170:8171 ~-0.032270188218236955 ~0.03495004091853925 "
    s .= "~-0.04017727384516842 73:-0.203125:8174:8175 ~-0.04078719717686149 248:0.875:8176:8177 ~0.02304643327409822 ~-0.032519434047099484 ~-0.06950432859535081 253:-0.11547619047619265:8180:8187 252:0.125:8181:8186 44:0.140625:8182:8185 "
    s .= "36:0.0390625:8183:8184 ~-0.029288186495445036 ~0.031912011601977756 ~-0.058837194004248465 ~0.028831049881757154 159:0.3984375:8188:8225 160:0.9375:8189:8218 147:-0.2578125:8190:8191 ~-0.035814524673312635 178:0.9375:8192:8217 "
    s .= "109:1.5625:8193:8214 241:0.1:8194:8201 139:0.625:8195:8200 190:0.34375:8196:8199 193:0:8197:8198 ~-0.04709067798906288 ~0.02606779084907278 ~0.05851796888399431 ~-0.051970799064485734 238:0.21875:8202:8209 22:0.28125:8203:8208 "
    s .= "82:1.125:8204:8207 88:0.515625:8205:8206 ~-0.0047353230615803385 ~0.021000466451807205 ~0.03865010206466341 ~-0.03236792253402207 196:0.546875:8210:8213 7:1.125:8211:8212 ~-0.04265147210014978 ~0.04066267223270073 "
    s .= "~0.020349729155441358 88:0.4375:8215:8216 ~-0.05099332280186797 ~0.00046029545635153945 ~0.02143924926506012 31:0.765625:8219:8224 232:-0.15625:8220:8223 117:-0.1953125:8221:8222 ~0.021025207191553767 ~-0.0396126938086856 "
    s .= "~0.018105895950003625 ~-0.036665742178339164 ~-0.02569808025275104 251:0.765625:8227:8254 256:0.2857142857142857:8228:8253 64:1.3125:8229:8252 181:0.640625:8230:8247 238:-0.203125:8231:8232 ~-0.03927362103475922 184:0:8233:8236 "
    s .= "79:0.25:8234:8235 ~-0.03882430538650333 ~0.009240752995275934 46:0.078125:8237:8240 46:0:8238:8239 ~0.005347026124447329 ~0.035088254582528344 43:0.453125:8241:8244 163:1.1875:8242:8243 ~-0.028250862123062173 ~0.03865622393419929 "
    s .= "169:0.1875:8245:8246 ~0.039967094827279545 ~-0.047235340398748854 130:1.28125:8248:8249 ~-0.040785326235821304 55:0.4375:8250:8251 ~0.02117294704266401 ~-0.04609098123683801 ~0.03074258256331045 ~-0.04522639030751041 "
    s .= "244:2.86:8255:8272 157:0.6875:8256:8269 124:0.234375:8257:8264 238:0.25:8258:8261 109:0.1875:8259:8260 ~-0.0186425929310245 ~0.021172463865040094 225:-0.0859375:8262:8263 ~0.019262916609607966 ~-0.04398651120039778 "
    s .= "55:1.375:8265:8268 157:0.1875:8266:8267 ~-0.00007301261864456481 ~-0.046630137753647424 ~0.03244552673336396 162:0.3671875:8270:8271 ~0.019897417537665992 ~-0.019024720864397344 ~-0.05557659042530763 254:0.984375:8274:8301 "
    s .= "245:1.6219512195121952:8275:8280 113:0.546875:8276:8277 ~-0.049359108503133436 203:0.28125:8278:8279 ~0.036183304647700684 ~-0.031179630928893094 181:-0.40625:8281:8282 ~-0.03599014067530056 49:0.09375:8283:8294 "
    s .= "253:-0.11956521739130466:8284:8285 ~0.03450500212386925 79:0.765625:8286:8289 88:0.328125:8287:8288 ~-0.0054481773388171595 ~0.014612689732878971 4:-0.234375:8290:8291 ~-0.020378950281280905 226:-0.1875:8292:8293 "
    s .= "~-0.035640427252338056 ~0.03636166127001677 70:0.5:8295:8300 91:0.15625:8296:8299 82:-0.125:8297:8298 ~0.027636299165279522 ~-0.02202250707495757 ~0.014181443358119572 ~-0.03499373683514037 146:-0.21875:8302:8317 "
    s .= "246:-0.390625:8303:8314 152:-1.15625:8304:8305 ~0.02745251296494738 211:0.3125:8306:8311 127:0.203125:8307:8308 ~0.011047729606283202 253:-0.012037037037038721:8309:8310 ~-0.0004513658452632477 ~-0.05430495943102728 "
    s .= "175:0.59375:8312:8313 ~-0.059703899655083104 ~0.0028506208673103953 100:-0.03125:8315:8316 ~-0.03270989253389828 ~0.026329838251729326 255:0.203125:8318:8319 ~-0.002553185246729846 ~-0.042327506450300506 26:-0.765625:8321:8324 "
    s .= "13:0.3125:8322:8323 ~0.018393148995233446 ~-0.022878973807499616 254:1.359375:8325:8366 246:-1.328125:8326:8331 244:1.4:8327:8328 ~-0.05321730069165731 152:-0.296875:8329:8330 ~0.014542758454179834 ~-0.07476954768449388 "
    s .= "256:0.9583333333333334:8332:8365 49:0.828125:8333:8364 249:0.16666666666666666:8334:8345 228:0.3203125:8335:8342 130:2.40625:8336:8341 251:0.546875:8337:8340 4:0.109375:8338:8339 ~0.016573169781090403 ~-0.03490396421222652 "
    s .= "~0.026744875513559557 ~-0.06394532889015786 252:0.42500000000000004:8343:8344 ~-0.029466418800830254 ~0.01638921498504805 141:0.1171875:8346:8357 91:-0.109375:8347:8350 223:0.40625:8348:8349 ~-0.05897190720776098 "
    s .= "~0.01054715345017025 95:0.140625:8351:8354 72:0.0234375:8352:8353 ~-0.009464127837858887 ~0.01749083129450328 28:0.03125:8355:8356 ~-0.04920721792796446 ~-0.0010822985928551831 99:-0.1484375:8358:8359 ~-0.04298281234329221 "
    s .= "122:0.046875:8360:8361 ~0.02045843790516283 87:0.1328125:8362:8363 ~-0.04102420551542159 ~0.008417020780824907 ~-0.03258931151269861 ~-0.051226412855436436 ~-0.028078511265307367 191:-0.6875:8368:8377 52:0.25:8369:8370 "
    s .= "~0.01771485070412939 55:1.265625:8371:8376 22:-0.140625:8372:8373 ~0.018392153694267752 136:1.96875:8374:8375 ~-0.060009208349298154 ~0.03943305484875284 ~0.027820816764403573 255:0.234375:8378:8395 246:-1.703125:8379:8380 "
    s .= "~-0.043051085132011835 77:-0.0625:8381:8386 246:-0.015625:8382:8385 247:0.078125:8383:8384 ~0.015154340610299612 ~-0.032335978790699806 ~0.02662366953178473 7:0.109375:8387:8392 249:1.5:8388:8391 233:0.671875:8389:8390 "
    s .= "~0.01150821832300218 ~-0.04444783072794428 ~-0.042279285800604194 16:0.21875:8393:8394 ~-0.03547694472438552 ~0.003961638791849454 156:0.1484375:8396:8411 254:0.515625:8397:8400 96:-0.2109375:8398:8399 ~-0.034216902889869616 "
    s .= "~0.03148990723744872 146:-0.234375:8401:8410 134:-0.40625:8402:8405 179:-0.5625:8403:8404 ~-0.0019927264152535813 ~-0.04858429897184735 145:-0.15625:8406:8407 ~-0.031409633538425547 221:-0.890625:8408:8409 ~-0.05652602896575218 "
    s .= "~0.01676430149976094 ~-0.023658338945108142 14:-0.625:8412:8413 ~0.009470588023321458 ~-0.03782370179566087 130:2.46875:8415:8458 154:1:8416:8453 142:-0.203125:8417:8420 124:-0.125:8418:8419 ~0.004792297064235584 "
    s .= "~-0.04272963935708586 162:0.5078125:8421:8452 112:0.40625:8422:8441 235:0.25:8423:8438 58:-0.109375:8424:8427 124:0.015625:8425:8426 ~-0.004628773779885322 ~0.04495235528745224 193:0.140625:8428:8435 249:0.5:8429:8434 "
    s .= "251:0.328125:8430:8431 ~-0.034736764327298504 186:0.4765625:8432:8433 ~0.02042277719641719 ~-0.049758224704374014 ~-0.024830484815945027 124:0.4375:8436:8437 ~-0.050718210329984664 ~0.01808287876308985 237:-0.4140625:8439:8440 "
    s .= "~0.022657010818585316 ~-0.04445932698891013 148:0.515625:8442:8447 251:0.984375:8443:8446 235:-0.09375:8444:8445 ~-0.0357197647702587 ~0.008946074519481758 ~0.02403841179183864 127:0.390625:8448:8449 ~0.020045391348259695 "
    s .= "55:-0.640625:8450:8451 ~0.04986145342823365 ~-0.04328404592868107 ~-0.040498576742565906 118:0.59375:8454:8457 156:0.3671875:8455:8456 ~0.018462619767713344 ~-0.04156799228285068 ~-0.024075408353405298 61:0.546875:8459:8460 "
    s .= "~-0.0679041039651564 ~0.02681191317905729 253:-0.05592105263157876:8462:8477 250:1.2578125:8463:8476 247:0.140625:8464:8471 245:1.8:8465:8466 ~-0.03005450915927406 133:1.59375:8467:8468 ~0.02538169629940712 223:0.09375:8469:8470 "
    s .= "~-0.0700743587983052 ~0.03343082223055604 58:0.203125:8472:8475 99:0.0078125:8473:8474 ~-0.04949796741225143 ~0.019469396536932124 ~-0.03900546839688549 ~0.03127581048306151 242:2.05:8478:8505 124:-0.109375:8479:8486 "
    s .= "119:-0.59375:8480:8481 ~0.011619681613703336 226:0.90625:8482:8485 6:0.53125:8483:8484 ~-0.0412800002130444 ~0.018000893467581578 ~0.02378002549948238 142:-0.265625:8487:8490 46:0.1875:8488:8489 ~-0.05506395450438767 "
    s .= "~0.0161389222992501 214:0.65625:8491:8502 55:-0.609375:8492:8493 ~0.04359186726206147 79:0.6875:8494:8499 205:0.625:8495:8498 61:1.15625:8496:8497 ~-0.013136654430349663 ~0.026369898556105144 ~0.0205046908167439 "
    s .= "70:0.65625:8500:8501 ~0.01854402838951281 ~-0.046543842878066795 52:0.453125:8503:8504 ~0.03326970391159681 ~-0.04061055678141632 142:0.953125:8506:8507 ~-0.04669511213300749 ~0.030526528550935034 254:0.984375:8509:8540 "
    s .= "118:0.28125:8510:8529 50:0.34375:8511:8528 120:0.1328125:8512:8517 90:-0.1328125:8513:8514 ~0.01694461639820632 94:0.0625:8515:8516 ~-0.016677790623460746 ~0.008590145026059027 88:0.359375:8518:8527 21:0.1484375:8519:8520 "
    s .= "~0.03217081471309485 175:0.421875:8521:8526 163:0.28125:8522:8525 242:1.55:8523:8524 ~-0.03553459143184005 ~0.02516486647220606 ~0.015167199033139254 ~0.03591556303901402 ~0.03242024482112909 ~-0.01886213132235043 "
    s .= "163:1.140625:8530:8539 142:0.6875:8531:8536 1:-0.4375:8532:8533 ~0.03316183444991066 249:0.8333333333333333:8534:8535 ~-0.003748183335360135 ~-0.04577978118762836 111:-0.1796875:8537:8538 ~0.007339038680736815 "
    s .= "~-0.0630051917398086 ~0.017019094418616026 221:-0.15625:8541:8552 85:1.265625:8542:8551 113:-0.109375:8543:8546 203:-1.3125:8544:8545 ~0.023149599532646253 ~-0.023921608972318043 49:0.078125:8547:8550 215:-0.75:8548:8549 "
    s .= "~0.03749524631995372 ~-0.041158761731127626 ~0.035556349858704935 ~0.01953445869042067 245:1.9519230769230769:8553:8554 ~-0.002521776981531346 ~-0.04520160929080089 251:0.765625:8556:8583 66:0.5703125:8557:8582 "
    s .= "64:1.3125:8558:8581 31:0.078125:8559:8576 187:-0.171875:8560:8561 ~-0.040892853047504035 46:0.078125:8562:8571 115:0.171875:8563:8566 178:0.90625:8564:8565 ~-0.01650746060099124 ~0.02928414747696803 1:-0.109375:8567:8570 "
    s .= "160:0.4375:8568:8569 ~0.02805898352099206 ~-0.03406725572788335 ~0.03311520602586419 99:-0.0078125:8572:8573 ~-0.05121611418487859 202:0.03125:8574:8575 ~0.029886627185654397 ~-0.031868917962704045 242:0.55:8577:8580 "
    s .= "85:0.171875:8578:8579 ~-0.03886897585585944 ~0.0046879416632406076 ~-0.03487627143717276 ~0.029825888598552064 ~-0.054120033855674925 244:2.86:8584:8601 109:0.53125:8585:8596 151:0.765625:8586:8595 "
    s .= "245:1.8313253012048192:8587:8592 243:1.25:8588:8589 ~0.02337838193695303 184:0.390625:8590:8591 ~-0.061330326194650675 ~0.01726237008887027 16:0.421875:8593:8594 ~-0.03669555321929903 ~0.02191306484582078 ~0.02166996391208962 "
    s .= "248:0.875:8597:8598 ~0.014603201892442045 225:0.2421875:8599:8600 ~-0.03737575228380049 ~0.019582326831926754 ~-0.052812049572334846 124:-0.703125:8603:8604 ~-0.046378675307202216 85:1.15625:8605:8638 251:1.484375:8606:8637 "
    s .= "159:0.2109375:8607:8632 241:0.12:8608:8615 208:0.546875:8609:8614 154:0.359375:8610:8613 40:0.109375:8611:8612 ~0.010966604335735708 ~-0.04012311598956819 ~0.0463533253573999 ~-0.04530594940988043 255:0.265625:8616:8621 "
    s .= "254:0.703125:8617:8618 ~-0.008325842320844766 191:0.109375:8619:8620 ~0.03500586874510522 ~-0.013762090805375025 163:1.265625:8622:8631 220:0.625:8623:8630 205:0.734375:8624:8629 70:-0.390625:8625:8626 ~0.01908079909871388 "
    s .= "208:0.984375:8627:8628 ~-0.041096134321854855 ~0.023612007339969307 ~0.013180254375473103 ~0.020028674821296114 ~0.01867566360506215 1:-0.4375:8633:8634 ~0.023697469130422234 253:-0.1875:8635:8636 ~0.029565447331360756 "
    s .= "~-0.03605872666801027 ~0.010125054345503925 208:-0.078125:8639:8640 ~-0.010726242375250602 37:0.78125:8641:8646 142:1.796875:8642:8645 137:0.5:8643:8644 ~0.026595623744427324 ~-0.023026962627064957 ~-0.05012499609944219 "
    s .= "88:1.53125:8647:8648 ~-0.05751267598452418 ~0.023071344523500514 253:-0.05592105263157876:8650:8663 252:0.175:8651:8658 71:0.15625:8652:8657 242:0.75:8653:8656 171:-0.1875:8654:8655 ~-0.03402803585029028 ~0.019856574720495974 "
    s .= "~-0.04729248566916764 ~-0.04671450210614625 19:-0.203125:8659:8660 ~-0.012681521526916914 1:0.671875:8661:8662 ~0.02973866972178 ~-0.0393884923929366 242:2.05:8664:8693 254:1.296875:8665:8690 239:-0.109375:8666:8677 "
    s .= "70:0.609375:8667:8674 178:-0.078125:8668:8671 73:0.0625:8669:8670 ~0.0025210078318597933 ~-0.0497212534600702 111:0.3359375:8672:8673 ~0.014975006088833046 ~-0.027755924671122086 172:0.046875:8675:8676 ~0.0153275345487964 "
    s .= "~-0.05612494413195216 246:0.015625:8678:8681 244:1.785:8679:8680 ~-0.043810548007031894 ~0.006762465870542603 190:0.84375:8682:8689 47:-0.109375:8683:8684 ~0.013959186099770836 118:0.40625:8685:8688 252:1.875:8686:8687 "
    s .= "~-0.014703227025888239 ~0.03022148551242312 ~-0.05264993119996511 ~0.037840125281975306 14:-0.59375:8691:8692 ~-0.0009912721306928674 ~-0.043343926881764444 216:0.1640625:8694:8695 ~-0.05749768476870727 ~0.0041819615945619245 "
    s .= "245:4.878048780487805:8697:8742 100:1.09375:8698:8737 242:1.25:8699:8730 184:0:8700:8715 241:0.58:8701:8712 31:0.40625:8702:8711 127:-0.15625:8703:8704 ~0.010103534682305156 244:1.49:8705:8706 ~-0.056927451370841355 "
    s .= "163:0.046875:8707:8708 ~-0.047682360394940206 134:-0.015625:8709:8710 ~0.02703704073757329 ~-0.06362338143573536 ~0.021973623006111467 248:0.375:8713:8714 ~0.03953571908305128 ~-0.03500735064334967 97:0.71875:8716:8729 "
    s .= "85:0.640625:8717:8728 82:0.15625:8718:8723 184:0.15625:8719:8722 244:1.02:8720:8721 ~0.021136447036741585 ~-0.03987614560242314 ~0.02409617598895368 112:0.859375:8724:8727 178:0.53125:8725:8726 ~-0.03232249933405309 "
    s .= "~0.006837542283269213 ~0.01890232130045076 ~0.015133918544773193 ~-0.04074147038738603 245:2.3582089552238807:8731:8734 160:0.453125:8732:8733 ~-0.011239174051917678 ~-0.049019271126321616 3:0.0390625:8735:8736 "
    s .= "~-0.01702544413132231 ~0.032071620827172256 37:0.4375:8738:8741 22:-0.234375:8739:8740 ~-0.031169516518553587 ~0.02859717838538698 ~-0.03561442616861523 ~-0.06579507326707272 130:2.46875:8744:8787 146:0.21875:8745:8780 "
    s .= "118:0.6875:8746:8775 154:1:8747:8772 34:0.0625:8748:8755 99:-0.1484375:8749:8754 184:0.21875:8750:8753 82:1.015625:8751:8752 ~-0.06309932655180142 ~0.016474620827619014 ~0.0020649840573550254 ~0.012843185604547135 "
    s .= "251:0.328125:8756:8757 ~-0.04318819067426075 136:0.171875:8758:8761 244:0.89:8759:8760 ~0.030151061012932648 ~-0.048079815714187485 242:1.25:8762:8769 127:0.890625:8763:8768 142:-0.21875:8764:8767 233:-0.015625:8765:8766 "
    s .= "~-0.05903487194438568 ~0.017435006208145885 ~0.019041373241801666 ~-0.030955411028950743 244:1.48:8770:8771 ~-0.052600366355668206 ~0.024108324165722186 222:0.0703125:8773:8774 ~0.003949002584369343 ~0.027397923952699396 "
    s .= "23:-0.390625:8776:8777 ~0.005206523246702412 149:0.109375:8778:8779 ~-0.04916572218944497 ~0.010599053181200203 254:0.046875:8781:8782 ~0.016951705877665806 220:0.203125:8783:8786 6:0.515625:8784:8785 ~-0.020005959818344993 "
    s .= "~0.020656312601950506 ~-0.045345409214877175 61:0.546875:8788:8789 ~-0.0657967735258549 ~0.025356762084152537 245:1.5866666666666667:8791:8796 113:0.609375:8792:8793 ~-0.04813351368513778 167:0.1875:8794:8795 "
    s .= "~0.038973731083112854 ~-0.028116230239881714 254:0.984375:8797:8818 72:0.8203125:8798:8817 248:1.375:8799:8816 181:-0.40625:8800:8801 ~-0.034060265258830706 49:0.359375:8802:8813 127:2.453125:8803:8812 "
    s .= "253:-0.11547619047619265:8804:8805 ~0.027755354127211654 251:1.328125:8806:8811 247:0.515625:8807:8808 ~0.00651336192866946 240:0.546875:8809:8810 ~-0.05009400275973859 ~0.015880293316728366 ~0.01982447553745542 "
    s .= "~-0.06766613243606855 163:1.1875:8814:8815 ~-0.017864997916010577 ~0.028705804855636535 ~-0.03557732390639853 ~-0.05059830209833069 146:-0.125:8819:8836 247:0.234375:8820:8835 246:-0.390625:8821:8832 191:-0.796875:8822:8827 "
    s .= "211:0.328125:8823:8824 ~0.02456478243395131 160:1.140625:8825:8826 ~-0.0551911541285404 ~0.020251844263885505 31:0.03125:8828:8829 ~-0.006248425197101116 123:0.4296875:8830:8831 ~-0.05496648173677238 ~0.02894909862024904 "
    s .= "220:-0.0625:8833:8834 ~-0.025695231258462542 ~0.028112224613207223 ~-0.03224513257440115 ~-0.03391795472768371 249:0.16666666666666666:8838:8859 178:-0.078125:8839:8844 251:1.328125:8840:8843 244:1.47:8841:8842 "
    s .= "~-0.05558875629934537 ~-0.004289347723701572 ~0.026386258468819358 166:0.234375:8845:8850 253:-0.05:8846:8847 ~0.03219940758264206 211:-0.21875:8848:8849 ~-0.038880459714560806 ~0.012571481231388355 250:0.7734375:8851:8854 "
    s .= "172:0.09375:8852:8853 ~0.0031836246489473155 ~-0.0783149864578403 247:0.296875:8855:8858 134:-0.5:8856:8857 ~-0.017145673916336406 ~0.025086533286394087 ~-0.045814916010037676 192:0.2734375:8860:8875 214:0.15625:8861:8870 "
    s .= "58:0.578125:8862:8869 194:0.09375:8863:8868 24:0.0859375:8864:8867 65:-1.265625:8865:8866 ~0.03471769183969513 ~-0.03327194164919867 ~-0.002373841353906077 ~-0.047651827444654266 ~0.002826590279908899 242:0.45:8871:8872 "
    s .= "~0.020127263557574302 139:0.1875:8873:8874 ~-0.040923116674091424 ~-0.0026871655983537056 58:-0.046875:8876:8877 ~0.025277812980300934 112:0.765625:8878:8883 178:0.484375:8879:8882 154:0.59375:8880:8881 ~-0.04759589684160611 "
    s .= "~0.013687713745733993 ~0.012047349600932048 ~0.02073348075196244 156:0.6328125:8885:8930 124:-0.703125:8886:8887 ~-0.04504516654643896 88:1.109375:8888:8927 79:1.375:8889:8926 46:0.8125:8890:8925 205:0.96875:8891:8924 "
    s .= "89:0.625:8892:8923 245:1.5866666666666667:8893:8894 ~-0.04635582661576038 100:-0.21875:8895:8898 130:0.546875:8896:8897 ~-0.020662535119320563 ~0.02503791073948801 220:0.625:8899:8920 238:0.125:8900:8913 133:1.484375:8901:8910 "
    s .= "80:0.046875:8902:8907 255:0.234375:8903:8904 ~0.02449047969254383 112:0.1875:8905:8906 ~0.019132899768825058 ~-0.02287714088868718 252:0.575:8908:8909 ~-0.04230891644096645 ~0.006108083728627815 1:0.15625:8911:8912 "
    s .= "~-0.0592392640468868 ~0.006926051054360172 163:1.234375:8914:8917 206:0.171875:8915:8916 ~-0.039876250768993496 ~-0.0007097589421660839 22:-0.0625:8918:8919 ~-0.09621173029690266 ~0.04024040325207906 211:0.53125:8921:8922 "
    s .= "~0.029157451566086248 ~-0.049489394304008415 ~0.017955433478457967 ~0.023772154782657796 ~0.025737185474556574 ~0.020742497356578557 70:0.578125:8928:8929 ~0.01714618446585875 ~-0.025540620095577057 ~-0.04093438874282357 "
    s .= "34:0.90625:8932:8977 256:0.9583333333333334:8933:8976 1:1.640625:8934:8975 55:1.21875:8935:8972 52:0.90625:8936:8971 160:0.9375:8937:8966 147:-0.2578125:8938:8939 ~-0.034208202883869526 178:1.109375:8940:8965 113:0.5625:8941:8962 "
    s .= "245:1.5866666666666667:8942:8943 ~-0.05558402689193166 244:2.095:8944:8961 23:0.21875:8945:8960 246:-0.015625:8946:8951 108:0.1796875:8947:8950 239:-0.140625:8948:8949 ~0.005797411758037542 ~-0.03836426289218708 "
    s .= "~-0.039078646773623237 77:-0.125:8952:8957 184:0.21875:8953:8956 123:0.4609375:8954:8955 ~0.014501444151808242 ~-0.06500137407372802 ~0.04010933060519481 139:0.21875:8958:8959 ~0.014820247030269003 ~-0.0183555653973655 "
    s .= "~-0.02551747290374476 ~-0.03949567965586673 119:0.453125:8963:8964 ~0.031893588713111536 ~-0.01347556926805105 ~0.02409533728649519 236:-0.109375:8967:8968 ~0.02085401452548505 244:1.47:8969:8970 ~-0.025469355590548515 "
    s .= "~0.013086241969161683 ~-0.03701061390048709 157:1.953125:8973:8974 ~0.02794067692955925 ~-0.05777757210295401 ~-0.05467191387692293 ~-0.049610860087457284 ~-0.023404446868704073 245:4.017543859649122:8979:9022 "
    s .= "145:-0.125:8980:8991 250:0.7578125:8981:8984 219:-0.1171875:8982:8983 ~-0.04963986409134577 ~0.027244549367122773 130:0.796875:8985:8988 253:-0.13262032085561656:8986:8987 ~0.012152788165203703 ~-0.04490576924974598 "
    s .= "137:0.0625:8989:8990 ~0.010617418978442166 ~-0.035184004751379304 142:-0.3125:8992:8993 ~-0.02612321185720792 217:0.21875:8994:9019 252:0.42500000000000004:8995:9014 202:-0.03125:8996:9003 205:0.140625:8997:9002 "
    s .= "79:1.28125:8998:9001 199:0.09375:8999:9000 ~-0.05694208426126629 ~0.007076945125289081 ~0.034810904463377416 ~0.02330108351968889 154:0.609375:9004:9013 46:0.4375:9005:9012 127:0.796875:9006:9011 71:0.171875:9007:9010 "
    s .= "238:0.25:9008:9009 ~0.011574208214789376 ~-0.02743913378516491 ~-0.03450508309145293 ~-0.04575130647558548 ~0.032692084766239894 ~0.023696983301409125 31:0.515625:9015:9018 223:0.296875:9016:9017 ~0.02772458003481818 "
    s .= "~-0.026805201515422556 ~-0.044911166276528545 50:-0.140625:9020:9021 ~0.0017572574400337082 ~-0.025626030582903272 235:0.109375:9023:9024 ~-0.06406757853001775 ~0.015636322732014325 255:0.234375:9026:9049 254:0.453125:9027:9042 "
    s .= "251:0.671875:9028:9037 242:0.55:9029:9032 61:-0.0625:9030:9031 ~0.023096599622391783 ~-0.010587213807769615 85:1.15625:9033:9034 ~-0.04104018625114146 193:-0.140625:9035:9036 ~-0.057977666802098454 ~0.025765647774576184 "
    s .= "109:0.53125:9038:9041 199:0.171875:9039:9040 ~0.005031710849043631 ~-0.032892924184984094 ~0.0147119788268825 218:0.09375:9043:9046 158:-0.28125:9044:9045 ~-0.014884162609307042 ~0.03489265962132046 245:1.765625:9047:9048 "
    s .= "~0.03346379342991722 ~-0.030031162593519314 122:-0.328125:9050:9059 247:0.234375:9051:9056 82:1.15625:9052:9055 82:0.59375:9053:9054 ~0.00749636088618095 ~-0.02618304715157855 ~0.022530845082455595 251:1.171875:9057:9058 "
    s .= "~-0.04759922425440926 ~0.003904866654626426 89:0.3125:9060:9069 140:-0.09375:9061:9066 252:0.225:9062:9065 254:0.546875:9063:9064 ~0.021119435604062223 ~-0.03764345398870835 ~0.01072641168798086 238:0.96875:9067:9068 "
    s .= "~-0.039013546558760104 ~0.01854649583900063 209:0.328125:9070:9071 ~0.017401840539970594 ~-0.037025620302764344 253:-0.05592105263157876:9073:9092 252:0.175:9074:9087 71:0.15625:9075:9086 242:0.75:9076:9085 133:1.59375:9077:9082 "
    s .= "245:1.967741935483871:9078:9079 ~-0.018091236872944335 129:-0.2421875:9080:9081 ~-0.023957287053337308 ~0.03943717387916602 199:0.078125:9083:9084 ~-0.06635431546417951 ~0.022884996035462207 ~-0.043631647659401085 "
    s .= "~-0.04390370264688035 238:0.53125:9088:9091 249:0.5:9089:9090 ~0.030980357489016896 ~-0.005219631823623892 ~-0.03897379578304533 243:2.25:9093:9118 214:-0.03125:9094:9095 ~-0.011641906102156308 205:-0.109375:9096:9099 "
    s .= "103:1.359375:9097:9098 ~-0.03975561951033921 ~0.022311519171324696 202:0.09375:9100:9103 124:-0.1875:9101:9102 ~-0.035976488638233516 ~0.017517084493098283 242:1.15:9104:9117 73:0.65625:9105:9116 91:0.46875:9106:9113 "
    s .= "151:0.296875:9107:9110 251:1.328125:9108:9109 ~-0.026985684202613713 ~0.017426286336063485 169:0:9111:9112 ~-0.03818710628726954 ~0.019625462507721028 70:0.578125:9114:9115 ~0.03083228727170466 ~-0.023630450043948485 "
    s .= "~-0.0480816245635597 ~-0.03922990380011388 ~-0.0422892829858518 248:1.375:9120:9163 254:1.296875:9121:9160 191:-0.4375:9122:9125 22:0.0625:9123:9124 ~0.019137771800099575 ~-0.001967007927594067 246:-0.859375:9126:9127 "
    s .= "~-0.03315915623780034 22:-0.265625:9128:9133 171:0.3125:9129:9130 ~-0.03735778048454605 184:0.21875:9131:9132 ~-0.037926627586545386 ~0.03349738239833922 118:0.296875:9134:9157 252:0.42500000000000004:9135:9154 "
    s .= "234:0.4453125:9136:9151 166:0.40625:9137:9150 127:0.328125:9138:9147 151:0.03125:9139:9146 49:-0.15625:9140:9143 47:0.09375:9141:9142 ~0.040000720722849964 ~-0.03601709086471524 174:-0.078125:9144:9145 ~0.013710171783075735 "
    s .= "~-0.04908005416219924 ~0.019247076399255304 115:0.203125:9148:9149 ~-0.004886932025181812 ~-0.05385053940309486 ~0.03438441335243094 152:0.078125:9152:9153 ~-0.0036067866556959366 ~-0.06502661059750263 145:-0.140625:9155:9156 "
    s .= "~-0.016884341167307946 ~0.028478600825226155 73:0.34375:9158:9159 ~-0.020138628263062675 ~0.016155283798949958 50:-0.25:9161:9162 ~-0.006084987545918607 ~-0.053383604665898476 112:2:9164:9165 ~-0.054288566820209494 "
    s .= "~0.02770315480500158 130:2.46875:9167:9210 249:0.16666666666666666:9168:9187 228:0.2265625:9169:9182 251:0.578125:9170:9181 28:0.046875:9171:9176 73:-0.28125:9172:9173 ~-0.04589556520377548 1:0.109375:9174:9175 "
    s .= "~0.024204579698253917 ~-0.0730622068876916 118:0.21875:9177:9180 13:0.078125:9178:9179 ~-0.04711374339228219 ~0.017570401604112364 ~-0.05026892444312131 ~0.019259834099923427 241:0.42:9183:9186 79:-0.109375:9184:9185 "
    s .= "~0.01822224521615416 ~-0.04459827101617252 ~0.009268429279059255 187:-0.3125:9188:9189 ~-0.04210037374369649 127:0.140625:9190:9205 28:0.40625:9191:9204 133:0.171875:9192:9195 61:0.34375:9193:9194 ~-0.05031417722006283 "
    s .= "~0.03031159163734062 195:-0.2265625:9196:9199 145:-0.03125:9197:9198 ~-0.05812606727716618 ~0.014444047015180131 149:-0.34375:9200:9201 ~0.031801300856327826 246:-0.421875:9202:9203 ~-0.038247776683391306 ~0.012372022488571388 "
    s .= "~-0.040308765507727384 55:1.3125:9206:9209 196:-0.234375:9207:9208 ~-0.0433152293310461 ~-0.008165185063085209 ~0.022904744950398227 61:0.546875:9211:9212 ~-0.0625554510218465 ~0.023463071967872624 26:-0.765625:9214:9223 "
    s .= "13:0.3125:9215:9222 20:-0.515625:9216:9219 243:1.55:9217:9218 ~0.026405662870342517 ~-0.036817554910174015 13:0:9220:9221 ~0.01381041880456818 ~-0.044016659807655914 ~-0.02237364473476029 246:-1.296875:9224:9229 "
    s .= "244:2.145:9225:9228 195:0.1796875:9226:9227 ~-0.0517285765111032 ~0.0006380045249400755 ~0.01922910100955831 255:0.234375:9230:9241 77:-0.0625:9231:9232 ~0.01655056806618795 31:0.140625:9233:9238 97:-0.09375:9234:9235 "
    s .= "~-0.015483374351268155 249:1.1666666666666665:9236:9237 ~0.017096503949258476 ~-0.03554835606804115 70:-0.03125:9239:9240 ~-0.05538333323801378 ~-0.008175522076524437 254:0.515625:9242:9243 ~0.01675478996847167 "
    s .= "233:0.296875:9244:9259 245:3.463768115942029:9245:9258 190:0.75:9246:9257 199:1.03125:9247:9256 252:0.375:9248:9251 16:0.296875:9249:9250 ~-0.028427836574436666 ~0.006370699532403067 244:1.47:9252:9255 251:1.390625:9253:9254 "
    s .= "~-0.03231989326472761 ~0.014098649417172933 ~0.027211538881108 ~0.0261475778575595 ~0.020993829308613623 ~-0.04646445597370711 ~-0.04640199871244065 253:-0.05592105263157876:9261:9268 250:1.2578125:9262:9267 "
    s .= "247:0.140625:9263:9264 ~0.012239262943587573 58:0.203125:9265:9266 ~0.007306601215008277 ~-0.03553840850484791 ~0.029858999869495785 242:0.55:9269:9284 184:0.046875:9270:9281 46:0.390625:9271:9280 250:0.6015625:9272:9273 "
    s .= "~0.03131832894437242 172:-0.078125:9274:9279 130:1.21875:9275:9278 124:0.328125:9276:9277 ~-0.05075704748859067 ~0.03500218148419934 ~0.022759972971887768 ~-0.043741468407648705 ~0.026293186277624503 118:0.65625:9282:9283 "
    s .= "~0.011934833085355923 ~-0.026339701812013713 252:0.07500000000000001:9285:9290 220:0.515625:9286:9289 163:1.140625:9287:9288 ~-0.05103553348114568 ~0.00352112457963378 ~0.026755049324157804 72:0.1171875:9291:9300 "
    s .= "241:2.06:9292:9299 40:-0.09375:9293:9294 ~-0.035836281840146714 199:0.359375:9295:9298 25:0.4375:9296:9297 ~0.019596417557069607 ~-0.048211695458297774 ~-0.030793757346818374 ~-0.0522642806374953 31:0.234375:9301:9304 "
    s .= "238:0.1875:9302:9303 ~0.026967047450761134 ~-0.011655508937182745 244:1.585:9305:9306 ~-0.04803326853959783 ~0.029483563815060888 251:0.921875:9308:9335 16:0.78125:9309:9334 64:1.375:9310:9333 214:-0.3125:9311:9312 "
    s .= "~-0.038688205809340556 245:1.5866666666666667:9313:9314 ~-0.039540090260933455 181:0.640625:9315:9326 58:0.59375:9316:9323 184:0:9317:9322 202:0.546875:9318:9321 166:0.21875:9319:9320 ~-0.05262575836745445 ~0.002846832554703198 "
    s .= "~0.02579205107627307 ~0.004538900059738916 193:0.0625:9324:9325 ~0.03672964574969378 ~-0.014866386593699397 55:0.4375:9327:9332 130:1.296875:9328:9331 245:1.8313253012048192:9329:9330 ~0.014005637091948209 ~-0.03719392426480976 "
    s .= "~0.02344245090244221 ~-0.04936136053914025 ~0.032077929125172315 ~-0.04108142643356699 157:0.59375:9336:9349 124:0.203125:9337:9346 61:-0.046875:9338:9341 244:1.225:9339:9340 ~0.01037098190600218 ~-0.0489346061309685 "
    s .= "238:0.25:9342:9343 ~0.021234907366085656 240:-0.09375:9344:9345 ~0.023221821553768323 ~-0.04940462814522334 226:0.03125:9347:9348 ~0.003856266218874706 ~-0.04257543804363927 229:-0.1875:9350:9351 ~-0.014038520216776922 "
    s .= "244:2.45:9352:9353 ~0.023003596333700072 ~-0.046437177425258054 248:1.375:9355:9398 85:1.15625:9356:9391 251:1.484375:9357:9390 217:-0.15625:9358:9361 127:0.671875:9359:9360 ~-0.0442881106494423 ~-0.0014258399270986911 "
    s .= "241:0.14:9362:9375 154:0.359375:9363:9372 49:-0.1875:9364:9365 ~0.03365038235885815 193:0.078125:9366:9371 248:0.625:9367:9370 103:0.140625:9368:9369 ~0.024236114506360155 ~-0.05142906227682878 ~-0.04222663252701647 "
    s .= "~-0.056458103440068685 208:0.546875:9373:9374 ~0.04030091177929418 ~-0.039557152080859026 220:0.9375:9376:9389 208:0.984375:9377:9388 255:0.234375:9378:9381 254:0.484375:9379:9380 ~-0.021060293630741456 ~0.026241847681540528 "
    s .= "98:-0.90625:9382:9383 ~0.005038497763637439 79:1.53125:9384:9387 100:-0.609375:9385:9386 ~0.0362240587346952 ~-0.03974616655680891 ~0.022786244252866527 ~0.03270686332828742 ~0.03205446218795258 ~0.009482259357311075 "
    s .= "208:-0.234375:9392:9393 ~-0.020846864802982996 37:0.78125:9394:9397 142:1.796875:9395:9396 ~0.020169529041710516 ~-0.04981929830441361 ~-0.020797062496937413 201:0.2890625:9399:9400 ~-0.054840712969856986 ~0.024084641239189606 "
    s .= "243:2.1500000000000004:9402:9445 253:-0.11547619047619265:9403:9412 7:0.125:9404:9405 ~0.024719701796768703 199:-0.15625:9406:9407 ~-0.07896609213536826 41:-0.0625:9408:9409 ~0.026100526069169017 244:1.54:9410:9411 "
    s .= "~-0.06502050158774851 ~0.03167331891242316 254:1.296875:9413:9442 63:-0.0703125:9414:9415 ~0.008961289981820773 99:-0.2265625:9416:9417 ~-0.041374706010626094 89:0.640625:9418:9437 245:1.5797101449275361:9419:9422 "
    s .= "116:0.625:9420:9421 ~-0.05400798610302398 ~0.025796476386878205 142:1.140625:9423:9436 37:0.703125:9424:9435 77:-0.125:9425:9432 152:0.15625:9426:9431 239:0.171875:9427:9430 107:-0.203125:9428:9429 ~-0.0077108196114349745 "
    s .= "~0.017468900606482176 ~-0.051423871555590875 ~0.036305977843716954 94:0.015625:9433:9434 ~-0.02206862421065162 ~0.0015847735549431533 ~-0.039795525593606516 ~-0.042750592551516094 235:0.328125:9438:9441 71:0.609375:9439:9440 "
    s .= "~0.03449549987890423 ~-0.01473488027860964 ~-0.034548398504036265 38:-0.59375:9443:9444 ~-0.001338525606306327 ~-0.03690722452111879 252:2.825:9446:9447 ~-0.05832645878957715 ~0.0025369792549436183 130:2.46875:9449:9492 "
    s .= "100:1.09375:9450:9487 242:1.25:9451:9482 184:0.046875:9452:9463 241:0.58:9453:9460 250:0.9921875:9454:9459 31:0.40625:9455:9458 127:0.203125:9456:9457 ~0.002086569663815214 ~-0.04240359895488342 ~0.029986403944601055 "
    s .= "~-0.03776431792978101 49:-0.15625:9461:9462 ~-0.037765337529437004 ~0.03143345088617621 97:0.71875:9464:9481 85:1.609375:9465:9480 79:0.109375:9466:9467 ~0.01195337676671223 154:0.5625:9468:9475 97:0.59375:9469:9474 "
    s .= "184:0.59375:9470:9471 ~-0.03599552969980354 235:0.265625:9472:9473 ~0.025830953474840098 ~-0.03650496905808466 ~0.03817423815316583 100:0.46875:9476:9477 ~0.021681864625764418 187:0.203125:9478:9479 ~0.022442005733451193 "
    s .= "~-0.06394307789802678 ~0.02740506433334196 ~-0.03871390957709524 245:2.135593220338983:9483:9484 ~-0.0319369504040525 145:0.25:9485:9486 ~0.01356231665559066 ~-0.04043499525149645 37:0.4375:9488:9491 94:-0.21875:9489:9490 "
    s .= "~-0.03487774725050473 ~0.028488256552622715 ~-0.03917735356793115 61:0.546875:9493:9494 ~-0.06043683202934286 ~0.021707418286280908 122:0.25:9496:9539 34:0.90625:9497:9538 251:0.515625:9498:9509 31:-0.0625:9499:9500 "
    s .= "~0.00665527041652846 160:0.15625:9501:9502 ~-0.03806845218439859 179:0.09375:9503:9508 112:1.1875:9504:9507 14:-0.953125:9505:9506 ~0.013900558238524914 ~-0.03857597341108231 ~0.016593661846280167 ~0.022902070505779748 "
    s .= "184:0.15625:9510:9521 55:0.734375:9511:9520 85:0.140625:9512:9517 208:-0.125:9513:9514 ~0.013326142631173755 181:0.640625:9515:9516 ~-0.058186656696618426 ~0.031807911780422846 154:0.15625:9518:9519 ~0.022129115101979888 "
    s .= "~-0.009393145059940683 ~0.03109681542536152 109:0.515625:9522:9533 28:0.421875:9523:9532 88:0.15625:9524:9527 232:0.40625:9525:9526 ~0.029362903688126663 ~-0.03670389190451156 243:0.55:9528:9529 ~-0.07486212954687081 "
    s .= "94:0.0625:9530:9531 ~-0.04072628767936457 ~0.013227099336956975 ~-0.05963317771228879 242:1.25:9534:9535 ~0.02395027130728293 217:-0.140625:9536:9537 ~-0.0584863377568731 ~0.007071918331592539 ~-0.02521142401660575 "
    s .= "89:0.75:9540:9541 ~-0.02055935727336886 ~0.01689685636822248 245:4.878048780487805:9543:9588 100:1.09375:9544:9583 50:0.328125:9545:9580 246:0.640625:9546:9575 109:0.515625:9547:9556 43:0.265625:9548:9553 242:0.55:9549:9552 "
    s .= "108:0.1953125:9550:9551 ~0.011008743082003114 ~-0.0443411710906286 ~-0.026284926238194728 154:-0.234375:9554:9555 ~0.027127891091198005 ~-0.05412240422323239 247:0.171875:9557:9572 251:0.515625:9558:9571 202:-0.125:9559:9560 "
    s .= "~-0.04594433071867695 121:0.125:9561:9568 22:0.015625:9562:9563 ~0.025456457462932253 145:-0.046875:9564:9565 ~-0.06057335279616294 154:0.03125:9566:9567 ~-0.06919262894251961 ~0.020456311817515116 160:1.484375:9569:9570 "
    s .= "~-0.03773891301135683 ~0.03751838106588707 ~0.01287202391589338 130:0.34375:9573:9574 ~0.011785653353830874 ~-0.03183402259886249 168:0.0390625:9576:9577 ~-0.013024030378134297 191:0.59375:9578:9579 ~0.023617387695852827 "
    s .= "~-0.026678278274277933 89:0.9375:9581:9582 ~-0.032009278179570014 ~0.03172927749788074 70:0.640625:9584:9587 22:-0.234375:9585:9586 ~-0.030951041347153364 ~0.025878841982868057 ~-0.04733271344269033 ~-0.06052906239582188 "
    s .= "127:2.453125:9590:9635 249:0.16666666666666666:9591:9610 178:-0.078125:9592:9597 251:1.328125:9593:9596 244:1.47:9594:9595 ~-0.052899537881683806 ~-0.003202378414133178 ~0.02578187549534169 166:0.265625:9598:9603 "
    s .= "253:-0.043604651162790255:9599:9600 ~0.03191454653036404 211:-0.25:9601:9602 ~-0.04814377854895027 ~0.011966915666396134 250:0.7734375:9604:9605 ~-0.043141208922511616 247:0.296875:9606:9609 134:-0.5:9607:9608 "
    s .= "~-0.01853003243610465 ~0.023685533923368442 ~-0.04440963623546905 120:0.1328125:9611:9632 239:-0.84375:9612:9619 102:-0.3515625:9613:9616 223:-0.359375:9614:9615 ~0.036538287088508 ~-0.053167979047989394 214:0.734375:9617:9618 "
    s .= "~0.031273734166135325 ~-0.04358986954003236 196:0.5625:9620:9631 175:0.203125:9621:9630 91:0.125:9622:9629 223:0.234375:9623:9628 103:1.046875:9624:9627 117:0.3515625:9625:9626 ~-0.04746695816848861 ~0.03736681610485711 "
    s .= "~0.01275776694530762 ~0.021875128943129138 ~0.0025998190611119998 ~-0.030699179890564084 ~0.00990367931838586 70:0.53125:9633:9634 ~0.007757513663872964 ~-0.03652090737018355 ~-0.04706872433554071 159:0.5234375:9637:9682 "
    s .= "145:-0.125:9638:9647 244:1.4:9639:9646 147:-0.1015625:9640:9641 ~-0.05640360195643648 73:-0.109375:9642:9645 245:2.0142857142857142:9643:9644 ~-0.02538152087944975 ~0.02723772155723397 ~-0.04117220374034919 ~0.004090092063622485 "
    s .= "245:3.463768115942029:9648:9677 154:1:9649:9674 142:-0.21875:9650:9651 ~-0.029058442005149978 112:0.390625:9652:9667 13:-0.0625:9653:9656 22:-0.25:9654:9655 ~-0.03088175336659349 ~0.021555784781782345 244:1.265:9657:9660 "
    s .= "251:0.703125:9658:9659 ~-0.022107001916088637 ~0.015942635093097474 193:0.140625:9661:9666 178:0.46875:9662:9665 79:0.90625:9663:9664 ~-0.04977415003857052 ~0.014022507793338633 ~0.03404509041810743 ~-0.06583355319904974 "
    s .= "148:0.515625:9668:9669 ~0.013534859208118637 19:-0.40625:9670:9671 ~0.032598978341124275 85:0.78125:9672:9673 ~-0.0479380361879192 ~0.007739202928406349 253:-0.015714285714285837:9675:9676 ~0.03460608931295073 "
    s .= "~0.0032115767535354847 67:-0.15625:9678:9679 ~0.024489256510620172 1:0.15625:9680:9681 ~-0.06013647350965963 ~0.014628149090702841 ~-0.028490525509606686 248:1.375:9684:9727 254:0.984375:9685:9704 245:1.6219512195121952:9686:9691 "
    s .= "113:0.546875:9687:9688 ~-0.04492934725408129 203:0.28125:9689:9690 ~0.03297664715735122 ~-0.028433363098081615 72:0.8984375:9692:9703 47:-0.671875:9693:9696 251:0.359375:9694:9695 ~-0.015071363474350266 ~0.026573355124431482 "
    s .= "83:-0.890625:9697:9698 ~-0.03926749443804618 127:2.453125:9699:9702 181:-0.40625:9700:9701 ~-0.03832993119925413 ~0.006424385306308896 ~-0.0597515684759835 ~-0.055867825839811994 247:0.203125:9705:9722 246:-0.390625:9706:9717 "
    s .= "152:-1.15625:9707:9708 ~0.022265968911285933 234:-0.0390625:9709:9712 88:0.078125:9710:9711 ~-0.006524794305963137 ~-0.04516013684761612 85:1.25:9713:9716 231:0.0078125:9714:9715 ~0.028984595321536574 ~-0.032214234964784455 "
    s .= "~0.0323507758599589 221:-0.15625:9718:9719 ~0.024154390223895122 242:0.75:9720:9721 ~-0.03908361302479808 ~0.009782046884675186 245:1.9285714285714286:9723:9724 ~0.0011505359357281745 239:-0.640625:9725:9726 "
    s .= "~-0.004570306580636732 ~-0.06015713201481709 34:-0.25:9728:9729 ~0.023197808009581794 ~-0.05428177471995857 156:0.6328125:9731:9776 251:1.328125:9732:9765 256:0.5106382978723404:9733:9764 142:-0.4375:9734:9735 "
    s .= "~-0.04163524289826019 85:1.453125:9736:9761 217:-0.15625:9737:9738 ~-0.024429893839909605 241:0.12:9739:9744 91:0.09375:9740:9743 79:-0.125:9741:9742 ~0.025447336241333815 ~-0.03020069887484671 ~0.027934221074452367 "
    s .= "169:0.078125:9745:9750 82:0.546875:9746:9749 91:0:9747:9748 ~0.016346845661571043 ~-0.022520170211502127 ~0.022873844756344474 82:0.375:9751:9756 76:0.046875:9752:9753 ~-0.03210632270829204 112:0.359375:9754:9755 "
    s .= "~-0.029074557661143766 ~0.024254561454652518 244:1.48:9757:9760 61:-0.34375:9758:9759 ~0.021807355600593777 ~-0.054474582256027526 ~0.0017289085548252555 127:-0.3125:9762:9763 ~-0.041354637792315276 ~0.01809892906358892 "
    s .= "~-0.03651104159086957 241:0.46:9766:9773 242:0.55:9767:9770 146:-0.234375:9768:9769 ~0.026897175403591586 ~-0.012347458244731865 163:1.109375:9771:9772 ~-0.05598320289504734 ~0.02412156287178398 214:0.46875:9774:9775 "
    s .= "~0.021729090743742335 ~-0.02539147601565446 ~-0.038269366028356594 26:-0.765625:9778:9783 13:0.3125:9779:9782 20:-0.515625:9780:9781 ~0.022402354444995675 ~-0.00959920408115468 ~-0.020912743865438597 246:-1.296875:9784:9789 "
    s .= "244:1.965:9785:9788 219:0.1953125:9786:9787 ~-0.05270968676335874 ~-0.0019946754827141664 ~0.014439723561054708 255:0.234375:9790:9807 77:-0.0625:9791:9796 110:0:9792:9795 245:1.967741935483871:9793:9794 ~-0.0214564638471048 "
    s .= "~0.01352455751538634 ~0.02663036179722742 31:0.140625:9797:9804 97:-0.09375:9798:9799 ~-0.014860048102776314 252:0.125:9800:9803 200:0.25:9801:9802 ~0.005824105792610434 ~-0.05087762978108406 ~0.02322017587253622 "
    s .= "70:-0.03125:9805:9806 ~-0.053596789426435455 ~-0.007512384256484155 87:-0.1796875:9808:9809 ~0.011626044481444615 46:0:9810:9813 149:-0.609375:9811:9812 ~0.009967329693196237 ~-0.029110672812021694 157:-0.234375:9814:9815 "
    s .= "~0.04144311235223368 251:1.609375:9816:9823 208:0.40625:9817:9822 66:0.0703125:9818:9821 167:-0.328125:9819:9820 ~0.011519604623039165 ~-0.02826359162854586 ~-0.04067651457984292 ~0.014625310111776722 ~0.015038774808266268 "
    s .= "243:2.1500000000000004:9825:9868 253:-0.11547619047619265:9826:9833 166:0.734375:9827:9832 252:0.125:9828:9831 17:-0.09375:9829:9830 ~0.018060954144967688 ~-0.03535418574685261 ~0.03273848888662939 ~-0.04605964266974177 "
    s .= "254:1.296875:9834:9865 239:-0.109375:9835:9854 238:0.15625:9836:9841 48:-0.0078125:9837:9840 69:0.0234375:9838:9839 ~0.002120884171437903 ~-0.05111653638272995 ~0.018775324734964054 109:1.171875:9842:9851 118:0.015625:9843:9844 "
    s .= "~-0.05335712757384541 106:0.5625:9845:9848 36:-0.0234375:9846:9847 ~0.029689697937644213 ~-0.026950049127310218 251:1.109375:9849:9850 ~-0.05635022183694042 ~0.025797801230988234 70:0.34375:9852:9853 ~0.02578092147711556 "
    s .= "~-0.026083172220422796 175:-0.15625:9855:9858 60:0.6171875:9856:9857 ~-0.048135062676912616 ~0.030116824988170483 169:1.765625:9859:9864 145:0.5:9860:9863 187:0.375:9861:9862 ~-0.008654276640542365 ~0.013492376420658786 "
    s .= "~-0.03673485631827887 ~0.038214750844782486 15:-0.1953125:9866:9867 ~0.007365079877445416 ~-0.027345550604840525 252:2.825:9869:9870 ~-0.05608623340987338 ~0.001606114071492021 245:4.878048780487805:9872:9917 "
    s .= "249:0.16666666666666666:9873:9886 253:-0.06723484848484773:9874:9875 ~0.021240689537047303 130:2.40625:9876:9885 90:0.1171875:9877:9880 40:-0.296875:9878:9879 ~-0.03647977270967593 ~0.011872383261816938 "
    s .= "253:0.005405405405404906:9881:9884 91:0.46875:9882:9883 ~-0.03859797049680336 ~0.0043365954248952305 ~0.020432081832315388 ~-0.056568082131558756 38:-0.96875:9887:9888 ~0.016130838324738325 120:0.0703125:9889:9904 235:0:9890:9893 "
    s .= "72:0.1328125:9891:9892 ~-0.03803796991758976 ~0.010201944018931618 81:0.1640625:9894:9903 175:0.453125:9895:9900 91:0.125:9896:9899 109:1.03125:9897:9898 ~-0.039296627545757135 ~0.008808839303622659 ~0.01801361502965586 "
    s .= "240:0.3125:9901:9902 ~-0.03723283647977862 ~0.025157838301292514 ~-0.045130008920295506 71:0.171875:9905:9912 246:-0.140625:9906:9909 239:-0.15625:9907:9908 ~0.0007264267273244285 ~-0.05364718958376066 53:0.0625:9910:9911 "
    s .= "~0.024432840318837818 ~-0.0141429294421316 165:0.2109375:9913:9914 ~-0.03452390002995885 15:0.2734375:9915:9916 ~0.022230366751639516 ~-0.03313982904854976 ~-0.05859610991550186 222:-0.3984375:9919:9924 179:-0.859375:9920:9923 "
    s .= "34:0.296875:9921:9922 ~0.020115854255661415 ~-0.05912574716363122 ~-0.046347391889714686 87:-0.1796875:9925:9928 163:1.140625:9926:9927 ~0.005778725403901109 ~0.03472641731769491 246:-1.328125:9929:9930 ~-0.03607840978613675 "
    s .= "245:3.463768115942029:9931:9964 70:-0.09375:9932:9937 123:0.1640625:9933:9936 132:-0.0078125:9934:9935 ~-0.012504288874317586 ~-0.04990504482903223 ~0.009461690401266952 159:0.4921875:9938:9963 154:0.78125:9939:9960 "
    s .= "178:0.53125:9940:9957 34:-0.0625:9941:9944 235:0.25:9942:9943 ~0.02687231032725076 ~-0.022436074638465555 169:0.140625:9945:9952 154:0.25:9946:9949 49:0.109375:9947:9948 ~0.01705536280738136 ~-0.024883414742036685 "
    s .= "121:0.78125:9950:9951 ~-0.028819988961326905 ~0.04144118613532327 31:0.40625:9953:9956 115:1.546875:9954:9955 ~-0.046369276247505385 ~0.02443084540606867 ~0.013776663229069239 166:0.609375:9958:9959 ~0.024713046949011896 "
    s .= "~-0.04720961615739934 10:0:9961:9962 ~-0.0015402958620454954 ~0.027220956864377872 ~-0.03574633647170137 ~-0.03138216713876955 251:0.921875:9966:9993 247:0.484375:9967:9988 64:1.375:9968:9987 199:-0.15625:9969:9974 "
    s .= "97:-0.234375:9970:9973 242:0.55:9971:9972 ~0.027066938077319594 ~-0.04670460019828271 ~-0.04253271738194781 248:1.375:9975:9986 245:1.5866666666666667:9976:9977 ~-0.039402286470777016 246:-0.390625:9978:9983 85:-0.1875:9979:9980 "
    s .= "~0.026587091848886177 213:0.0234375:9981:9982 ~-0.005077623833048417 ~-0.03987717274042803 250:0.8046875:9984:9985 ~-0.008720353379320301 ~0.015245926981143352 ~-0.0514120275456359 ~0.028801364750701587 255:-0.015625:9989:9990 "
    s .= "~0.036489289799048585 109:0.28125:9991:9992 ~-0.0014700248371294303 ~-0.052511737917540435 157:0.59375:9994:10007 124:0.203125:9995:10004 61:-0.046875:9996:9999 244:1.225:9997:9998 ~0.010926340708336136 ~-0.04595541901322764 "
    s .= "238:0.25:10000:10001 ~0.02020904108485842 240:-0.09375:10002:10003 ~0.02295343570211303 ~-0.04540844868198632 226:0.03125:10005:10006 ~0.003882264013198692 ~-0.04004789719801244 229:-0.1875:10008:10009 ~-0.01380564280543086 "
    s .= "244:2.45:10010:10011 ~0.02163666704939828 ~-0.04202135224018335 170:0.34375:10013:10058 246:0.609375:10014:10055 247:0.484375:10015:10054 245:1.5866666666666667:10016:10017 ~-0.04726598571981142 "
    s .= "253:-0.05592105263157876:10018:10031 214:0.703125:10019:10030 252:0.275:10020:10029 58:-0.03125:10021:10022 ~0.028302567713863438 199:0.109375:10023:10028 133:1.53125:10024:10027 238:0:10025:10026 ~-0.03825316927739965 "
    s .= "~0.02054152900385013 ~-0.07210329371329603 ~0.015779561360415476 ~0.03234315755636146 ~-0.027957262707026816 239:-0.125:10032:10047 134:-0.125:10033:10044 242:0.55:10034:10039 34:-0.078125:10035:10036 ~0.02010447703452342 "
    s .= "178:-0.09375:10037:10038 ~-0.051805227549992255 ~0.0011261933683051767 157:0.875:10040:10041 ~-0.03644804091164346 241:1.74:10042:10043 ~0.012291229908560367 ~-0.048504858962471045 129:0.1484375:10045:10046 ~0.023158038814746318 "
    s .= "~-0.01551548507241671 241:0.18:10048:10051 243:0.35:10049:10050 ~-0.01858973369976624 ~0.025381069882051993 22:0.03125:10052:10053 ~-0.04714950163509885 ~-0.011176268375464302 ~-0.04334561184367825 120:0.1796875:10056:10057 "
    s .= "~0.0003998269652042061 ~0.024535451545655795 ~-0.014759216936959689 243:2.1500000000000004:10060:10103 153:0.7578125:10061:10102 255:0.234375:10062:10081 254:0.453125:10063:10074 85:1.15625:10064:10071 112:1.625:10065:10070 "
    s .= "89:0.9375:10066:10069 50:0.421875:10067:10068 ~-0.005793568643354752 ~-0.0436688277410998 ~0.031152725227353295 ~0.02355303844272766 112:2:10072:10073 ~0.02126390652186076 ~-0.02947470616189303 218:0.09375:10075:10078 "
    s .= "246:-0.328125:10076:10077 ~-0.01042685191665365 ~0.03503288799429499 245:1.8644067796610169:10079:10080 ~0.026231132269384623 ~-0.03740764346857949 122:-0.296875:10082:10087 247:0.234375:10083:10084 ~0.005563311003080987 "
    s .= "251:1.421875:10085:10086 ~-0.03446917836159382 ~0.014323198837030069 89:0.25:10088:10099 79:0.90625:10089:10094 88:1.46875:10090:10093 34:-0.234375:10091:10092 ~-0.0010569701049982542 ~-0.04058613721443748 ~0.008783728224684905 "
    s .= "49:0.09375:10095:10098 4:-0.234375:10096:10097 ~-0.043122635933201314 ~0.03257789543963268 ~-0.03491581454419581 206:0.375:10100:10101 ~0.015269906892848914 ~-0.04069094892804198 ~-0.039671551782160745 252:2.825:10104:10105 "
    s .= "~-0.0550243024049402 ~0.0012280275731747922 222:-0.3984375:10107:10112 34:0.3125:10108:10111 185:-0.875:10109:10110 ~0.02116629023330407 ~-0.035721292591674385 ~-0.0660425654099186 87:-0.1796875:10113:10118 "
    s .= "130:1.046875:10114:10117 84:-0.6484375:10115:10116 ~-0.04722452453163919 ~0.0061932927440439284 ~0.02324014923640712 246:-1.328125:10119:10120 ~-0.03410146426592675 245:3.463768115942029:10121:10152 70:-0.09375:10122:10127 "
    s .= "123:0.1640625:10123:10126 132:-0.0078125:10124:10125 ~-0.012327237772864697 ~-0.04842120201132827 ~0.00887973153470243 159:0.4921875:10128:10151 154:0.78125:10129:10148 205:0.59375:10130:10147 190:0.703125:10131:10146 "
    s .= "154:0.15625:10132:10137 64:0.15625:10133:10136 34:-0.046875:10134:10135 ~0.01806074205749184 ~-0.024474774880534997 ~0.0208291564705205 175:0.609375:10138:10145 112:1.046875:10139:10144 191:-0.703125:10140:10141 "
    s .= "~0.011935204684939192 160:0.171875:10142:10143 ~-0.006906158703753285 ~-0.044033386690771885 ~0.010214358490341163 ~0.01762132978271907 ~0.02880673375790709 ~0.025923803442133176 10:0:10149:10150 ~-0.0016324628121722612 "
    s .= "~0.026305777454781278 ~-0.03381351389712033 ~-0.029536838390361093 130:2.46875:10154:10197 100:1.09375:10155:10192 148:0.21875:10156:10173 124:0:10157:10162 22:0:10158:10159 ~0.006523043821405595 199:0:10160:10161 "
    s .= "~-0.037367842626509065 ~-0.0043435654231078515 154:0.96875:10163:10172 94:-0.015625:10164:10169 199:0.046875:10165:10166 ~0.006978810262956115 25:-0.265625:10167:10168 ~0.008754398125286241 ~-0.056210510220751825 "
    s .= "181:-0.0625:10170:10171 ~-0.02742510354019716 ~0.015190630955333285 ~0.030093211269675832 100:-0.53125:10174:10175 ~0.03627797090648607 226:0.734375:10176:10191 242:0.25:10177:10180 154:0.5:10178:10179 ~-0.040848808032602185 "
    s .= "~0.0506455116181478 160:1.1875:10181:10190 99:0.0859375:10182:10187 151:0.203125:10183:10186 208:0.125:10184:10185 ~0.03225470141666904 ~-0.040691890015185236 ~-0.04267684990898646 178:1.046875:10188:10189 ~-0.01551793298664264 "
    s .= "~0.030899505857156853 ~0.010868187047839165 ~0.020562385650802498 37:0.4375:10193:10196 19:-0.265625:10194:10195 ~-0.024782477956636788 ~0.02809898218990487 ~-0.03621689265048802 61:0.546875:10198:10199 ~-0.0568555705298947 "
    s .= "~0.020437584136986507 251:0.921875:10201:10224 66:0.5703125:10202:10223 64:1.375:10203:10222 241:0.12:10204:10209 91:0.09375:10205:10208 79:-0.125:10206:10207 ~0.020892253454591544 ~-0.03745322486268076 ~0.023932643317683928 "
    s .= "67:0.53125:10210:10221 249:1.5:10211:10220 202:0.5:10212:10219 61:0.5625:10213:10218 184:-0.046875:10214:10215 ~-0.04882144862097869 208:0.453125:10216:10217 ~-0.014392333364530741 ~0.020603479789666847 ~0.015583060583912218 "
    s .= "~0.017748082418213077 ~-0.04586424756199449 ~-0.0388460415596858 ~0.026166632815736564 ~-0.04350811501972643 157:0.59375:10225:10238 252:1.0750000000000002:10226:10235 124:0.203125:10227:10230 61:-0.046875:10228:10229 "
    s .= "~-0.030325575765860247 ~0.010251967942052001 178:1.25:10231:10234 199:-0.171875:10232:10233 ~0.015437823769612872 ~-0.04783376033582894 ~0.02990276831105622 243:1.75:10236:10237 ~0.03464269197123525 ~-0.017247509656329436 "
    s .= "170:-0.421875:10239:10240 ~0.028022696423238066 72:0.1796875:10241:10246 245:3.4262295081967213:10242:10245 112:0.34375:10243:10244 ~-0.0391660980543809 ~0.011383591764009535 ~-0.07329784720195737 ~0.0216637270304905 "
    s .= "16:0.828125:10248:10293 203:0.796875:10249:10292 89:0.625:10250:10289 245:1.5866666666666667:10251:10254 113:0.609375:10252:10253 ~-0.048291964571624046 ~0.01829537255490541 247:0.484375:10255:10286 251:0.203125:10256:10259 "
    s .= "178:0.4375:10257:10258 ~-0.037839459044798573 ~0.007800252640313735 130:2.46875:10260:10285 55:1.265625:10261:10282 52:0.71875:10262:10279 215:0.328125:10263:10276 242:2.05:10264:10275 67:0.015625:10265:10274 "
    s .= "34:-0.0625:10266:10269 118:0.65625:10267:10268 ~0.015418370963282912 ~-0.03733250204966367 154:1.0625:10270:10273 112:0.359375:10271:10272 ~-0.05052879451321482 ~-0.009314578260898362 ~0.018244872023271862 ~0.01298123712143256 "
    s .= "~-0.02900712357638808 96:0.2421875:10277:10278 ~-0.041237792255454916 ~0.013909867802374978 46:0.078125:10280:10281 ~-0.004319122705324313 ~-0.06861413055900599 88:1.6875:10283:10284 ~0.03224986186575149 ~-0.035901545547011866 "
    s .= "~-0.03426040359546413 206:0.375:10287:10288 ~-0.03656199104957249 ~0.019068487597975643 235:0.328125:10290:10291 ~0.02584740839205171 ~-0.03605445985164171 ~-0.04058346904843139 ~-0.02183593931274991 254:1.296875:10295:10338 "
    s .= "143:0.140625:10296:10333 142:0.71875:10297:10328 111:0.5234375:10298:10327 89:0.53125:10299:10326 245:1.5866666666666667:10300:10301 ~-0.038866947039948266 251:0.296875:10302:10311 61:-0.03125:10303:10306 97:-0.0625:10304:10305 "
    s .= "~-0.028871071728503894 ~0.03149273538886757 160:1.203125:10307:10310 110:0:10308:10309 ~-0.05688530340661427 ~-0.0017188832670092338 ~0.021950308857299487 159:0.2109375:10312:10321 242:2.05:10313:10320 109:1.859375:10314:10315 "
    s .= "~0.01635031751328528 146:-0.59375:10316:10317 ~0.0323398804558514 187:0.28125:10318:10319 ~-0.0445115077370565 ~0.024805546969696834 ~-0.025046216088160562 19:-0.390625:10322:10323 ~0.038605336717811536 250:1.0546875:10324:10325 "
    s .= "~-0.037479733474529354 ~0.006148494644830253 ~0.029950722742818264 ~-0.03664500378776616 115:0.734375:10329:10330 ~-0.03926605089673192 76:0.890625:10331:10332 ~0.022601301202057597 ~-0.059214840225134506 "
    s .= "172:-0.171875:10334:10335 ~-0.03936132148360643 145:0.515625:10336:10337 ~-0.0013229693078662813 ~-0.04306621446547814 50:-0.25:10339:10340 ~-0.005570969301844978 ~-0.051427803890414174 26:-0.765625:10342:10345 "
    s .= "13:0.3125:10343:10344 ~0.015857341105483314 ~-0.01976904141851195 246:-1.296875:10346:10351 244:1.965:10347:10350 195:0.1796875:10348:10349 ~-0.05005394843105318 ~0.0008934009466939116 ~0.014051915986583686 "
    s .= "255:0.234375:10352:10375 122:0.046875:10353:10364 254:0.484375:10354:10361 35:-0.328125:10355:10356 ~0.022955241102831613 211:0.09375:10357:10358 ~0.010778859125237572 245:1.9193548387096775:10359:10360 ~-0.05149166441912996 "
    s .= "~-0.003717628456031857 172:-0.15625:10362:10363 ~-0.022684667724830358 ~0.03394705554640634 79:0.34375:10365:10370 88:0.109375:10366:10369 180:-0.0546875:10367:10368 ~0.022885571047386446 ~-0.047342880805348604 "
    s .= "~-0.0037282759465678615 31:0.109375:10371:10372 ~0.02323735686973704 238:0.21875:10373:10374 ~-0.03726232658250469 ~0.019066926838484526 254:0.515625:10376:10377 ~0.016160243246883386 203:0.265625:10378:10387 "
    s .= "19:0.21875:10379:10384 252:0.375:10380:10383 199:0.5625:10381:10382 ~-0.029074042458714224 ~0.012873904491681243 ~0.0014182683621914716 19:0.671875:10385:10386 ~0.014606932083112228 ~-0.031234795698600232 ~-0.0417306606045117 "
    s .= "253:-0.04464285714285676:10389:10406 252:0.175:10390:10399 195:0.3671875:10391:10396 180:0.1953125:10392:10395 24:0.0546875:10393:10394 ~-0.02655137960602041 ~0.012658523461360677 ~-0.05299626989958898 "
    s .= "245:1.9838709677419355:10397:10398 ~-0.03642861674790762 ~0.042771024181186695 214:0.703125:10400:10405 22:-0.265625:10401:10404 85:1.390625:10402:10403 ~-0.040280480324855546 ~0.027077989903375926 ~0.026180488246398927 "
    s .= "~-0.03278641864660376 242:0.55:10407:10418 184:0.046875:10408:10415 250:0.8671875:10409:10414 115:0.546875:10410:10413 178:-0.09375:10411:10412 ~-0.04858801430124677 ~0.02814479776243376 ~-0.06469510132145313 "
    s .= "~-0.024371419525008528 118:0.65625:10416:10417 ~0.011135146017357272 ~-0.023088136492932745 252:0.025:10419:10424 220:0.515625:10420:10423 4:0.796875:10421:10422 ~-0.04703515017307622 ~0.02556722742887982 ~0.022210879997625978 "
    s .= "202:0.25:10425:10430 28:0.421875:10426:10429 49:-0.140625:10427:10428 ~-0.018490859349714946 ~0.016012646323064636 ~-0.032561377580562094 196:0.984375:10431:10434 91:1.09375:10432:10433 ~-0.04059226127524722 ~0.02645706390134214 "
    s .= "~0.02153236660517563 248:1.375:10436:10479 85:1.15625:10437:10470 16:0.875:10438:10469 205:0.6875:10439:10466 91:0.328125:10440:10457 120:0.0703125:10441:10454 202:0.71875:10442:10453 76:1.109375:10443:10452 "
    s .= "103:-0.078125:10444:10445 ~0.0020988764976011707 235:0.109375:10446:10451 196:0.328125:10447:10450 16:0.484375:10448:10449 ~-0.03542191552955406 ~0.035128960918089584 ~0.018404342992716576 ~-0.06056765419109768 "
    s .= "~0.02594746012893062 ~0.02855963687786885 118:0.359375:10455:10456 ~0.005052292434239487 ~-0.04684478131759988 151:0.265625:10458:10459 ~0.019640300627089102 134:-0.359375:10460:10461 ~-0.04520130748915359 "
    s .= "245:2.154639175257732:10462:10465 231:0.4140625:10463:10464 ~0.023244729382154102 ~-0.036631256101292684 ~-0.020142976567822043 208:0.625:10467:10468 ~0.028942223993867828 ~-0.010722120942474489 ~-0.035683921975740274 "
    s .= "208:-0.234375:10471:10472 ~-0.019571181270797006 70:0.921875:10473:10478 242:0.35:10474:10477 181:1.296875:10475:10476 ~0.011170273574857257 ~-0.06241290675977482 ~0.021806073845625187 ~-0.023625419753648003 "
    s .= "201:0.2890625:10480:10481 ~-0.05271483556283996 ~0.022728798920375395 26:-0.765625:10483:10494 13:0.3125:10484:10493 20:-0.515625:10485:10490 243:1.55:10486:10489 251:0.234375:10487:10488 ~-0.022184777862963505 "
    s .= "~0.027738174396290893 ~-0.03185317105532266 13:0:10491:10492 ~0.013300268878270028 ~-0.040795126801142285 ~-0.018479080115374354 246:-1.296875:10495:10502 244:1.4:10496:10497 ~-0.04654974798124149 179:-0.8125:10498:10499 "
    s .= "~0.0304281225538521 191:-0.625:10500:10501 ~0.004989177050649908 ~-0.061785447049250514 255:0.234375:10503:10520 59:-0.109375:10504:10513 110:0:10505:10512 111:0.0703125:10506:10509 244:0.98:10507:10508 ~-0.036277923923315525 "
    s .= "~0.021380757119127663 85:-0.140625:10510:10511 ~0.0295315203658683 ~-0.03940613701598064 ~0.03257394887922571 128:0.359375:10514:10515 ~0.005205237529538682 89:0.9375:10516:10519 218:0.328125:10517:10518 ~-0.00683343639622239 "
    s .= "~-0.0430474625471758 ~0.02159265154046451 254:0.515625:10521:10524 28:0.296875:10522:10523 ~0.024391414729266522 ~-0.028196628009671168 203:0.265625:10525:10526 ~-0.007965535279535066 86:0.6875:10527:10528 ~-0.052961975019458624 "
    s .= "~0.016226306135238965 145:-0.125:10530:10537 250:0.7578125:10531:10532 ~0.012761137747118512 130:0.953125:10533:10536 253:-0.1420634920634901:10534:10535 ~0.012421454391566104 ~-0.03908152703707349 ~0.001972674135695344 "
    s .= "142:-0.34375:10538:10539 ~-0.026308790457037257 85:0.625:10540:10565 205:0.6875:10541:10564 220:0.40625:10542:10561 217:0.21875:10543:10556 251:1.484375:10544:10555 241:0.14:10545:10552 91:0.09375:10546:10551 "
    s .= "79:-0.078125:10547:10548 ~0.02761920285126096 208:-0.265625:10549:10550 ~0.039592365970786365 ~-0.05675784580329601 ~0.02105661386363109 253:-0.0607697824527861:10553:10554 ~0.004538365549549238 ~-0.029698369622047117 "
    s .= "~0.01848267708305387 62:-0.234375:10557:10560 157:0.359375:10558:10559 ~-0.04631315838607061 ~0.010936624102346 ~-0.05889403540288249 232:0.375:10562:10563 ~0.030206986529180076 ~-0.026453907099554416 ~0.02082306549038928 "
    s .= "248:1.125:10566:10575 208:-0.21875:10567:10570 91:0.9375:10568:10569 ~-0.03787601305882223 ~0.029231128082924086 70:0.46875:10571:10572 ~0.0216104679336571 172:0.078125:10573:10574 ~0.02557308356501774 ~-0.03273548893889129 "
    s .= "~-0.047367955134035335 251:0.921875:10577:10600 247:0.703125:10578:10599 145:-0.109375:10579:10586 25:-0.1875:10580:10583 241:0.38:10581:10582 ~0.02240208365412129 ~-0.0295254440265612 214:1.265625:10584:10585 "
    s .= "~-0.040594523205406484 ~0.030240526709429623 64:1.375:10587:10598 205:-0.28125:10588:10589 ~-0.04318055925976355 207:0.3203125:10590:10595 242:2.05:10591:10594 246:-0.390625:10592:10593 ~-0.006272139775850991 "
    s .= "~0.009997064335819185 ~-0.04274090627715624 181:-0.015625:10596:10597 ~0.01241194953980761 ~-0.03531291547655616 ~0.032511587667025214 ~-0.04184638873597653 109:0.515625:10601:10608 151:0.765625:10602:10607 137:0.625:10603:10606 "
    s .= "100:1.25:10604:10605 ~-0.027902060937573255 ~0.027145014230135114 ~0.01539458654909457 ~0.020555219098727068 109:1.859375:10609:10618 23:-0.03125:10610:10611 ~0.02293132887185939 245:2.4719101123595504:10612:10617 "
    s .= "241:0.46:10613:10614 ~-0.03966434756225065 67:-0.265625:10615:10616 ~-0.06480828625517915 ~0.018733197741146533 ~0.02240405806515994 133:0.796875:10619:10620 ~-0.05055334569107846 171:0.296875:10621:10622 ~-0.015850050851490344 "
    s .= "~0.03824069851956744 222:-0.3984375:10624:10629 34:0.3125:10625:10628 185:-0.875:10626:10627 ~0.019744523940927784 ~-0.03404135515138584 ~-0.06353556500444649 87:-0.1796875:10630:10635 163:1.140625:10631:10634 "
    s .= "48:-0.2109375:10632:10633 ~-0.013492165406893365 ~0.017402565022583128 ~0.03362623723874028 246:-1.328125:10636:10637 ~-0.031131111724223445 245:3.463768115942029:10638:10669 196:-0.125:10639:10644 55:0.734375:10640:10643 "
    s .= "251:1.671875:10641:10642 ~-0.031981017735420475 ~0.013411949720912947 ~0.023529494594848724 31:0.140625:10645:10664 252:0.42500000000000004:10646:10659 184:0:10647:10652 127:-0.078125:10648:10649 ~0.01398539446858707 "
    s .= "253:0:10650:10651 ~-0.050116324191300736 ~0.02411635040508064 100:-0.328125:10653:10654 ~0.039072463626300125 207:0.3203125:10655:10658 120:0.0703125:10656:10657 ~-0.008031363007486934 ~0.021309629197067796 ~-0.02163117086162728 "
    s .= "10:-0.28125:10660:10661 ~-0.023809263124140594 235:0.21875:10662:10663 ~0.03203332505767419 ~-0.005113002969674312 40:-0.03125:10665:10666 ~-0.041302315625655873 112:0.390625:10667:10668 ~-0.01946948161238746 ~0.00952112929746228 "
    s .= "~-0.028888733955033177 98:-0.140625:10671:10698 99:-0.1171875:10672:10679 63:0.0078125:10673:10678 251:0.328125:10674:10675 ~-0.022718636582883527 141:-0.0859375:10676:10677 ~-0.002785505683099279 ~0.02456142634539143 "
    s .= "~-0.0344536485334281 252:0.42500000000000004:10680:10695 242:0.55:10681:10684 102:0.1328125:10682:10683 ~0.02060325176383916 ~-0.0014309389505627154 220:0.625:10685:10694 205:0.578125:10686:10693 160:0.609375:10687:10690 "
    s .= "64:1.421875:10688:10689 ~-0.05524741113815729 ~0.03049686714358424 94:0:10691:10692 ~-0.05033535648508576 ~0.02044910574510301 ~0.02804831578844923 ~0.032565444024505064 166:0.4375:10696:10697 ~0.030424094653329837 "
    s .= "~-0.01788656240231693 226:-0.15625:10699:10700 ~-0.02692129471230613 229:0.1875:10701:10712 190:0.703125:10702:10711 243:0.6499999999999999:10703:10708 166:0.46875:10704:10705 ~-0.02895205741380476 76:0.234375:10706:10707 "
    s .= "~0.03910301989317134 ~-0.05084995531442196 235:0.21875:10709:10710 ~0.015159456750220882 ~-0.02824184579944344 ~0.033137081961809825 184:1:10713:10716 202:0.90625:10714:10715 ~-0.029980332100641327 ~0.01634463513582812 "
    s .= "~0.02382880565378968 249:0.16666666666666666:10718:10745 178:-0.078125:10719:10728 235:-0.015625:10720:10723 106:0.375:10721:10722 ~-0.04641469233831265 ~0.0225868725628634 76:0.03125:10724:10725 ~-0.0033174543567770047 "
    s .= "100:0.859375:10726:10727 ~-0.09479739334940752 ~0.005353295691106115 166:0.234375:10729:10734 253:-0.043604651162790255:10730:10731 ~0.03063610983847258 211:-0.21875:10732:10733 ~-0.04261621478207966 ~0.010989664063297124 "
    s .= "250:0.7734375:10735:10738 145:0.09375:10736:10737 ~0.004822352947230784 ~-0.06867769794562754 247:0.296875:10739:10744 244:1.08:10740:10741 ~-0.027543935724016366 248:0.375:10742:10743 ~0.027722538438524402 ~-0.027190429744574765 "
    s .= "~-0.040728831051365745 149:-0.6875:10746:10749 247:0.296875:10747:10748 ~0.014375750856030173 ~-0.03979393824019103 246:-0.828125:10750:10753 130:0.96875:10751:10752 ~-0.05123627359432852 ~-0.006502678282838681 "
    s .= "121:-0.1875:10754:10757 142:0.03125:10755:10756 ~-0.0010257976936305124 ~-0.0461654720135341 122:0:10758:10759 ~0.005200579650971183 124:0.140625:10760:10763 121:-0.078125:10761:10762 ~-0.03948862354073496 ~0.008977921674933545 "
    s .= "~-0.029079191432789715 254:1.015625:10765:10802 191:-0.421875:10766:10779 22:0:10767:10770 2:-0.546875:10768:10769 ~0.036254655884915936 ~0.008061931128153408 52:0.25:10771:10776 160:1.109375:10772:10775 106:0.375:10773:10774 "
    s .= "~-0.027641564307989475 ~0.016827600963248614 ~0.03487929242604466 244:1.795:10777:10778 ~-0.04036018345048191 ~0.02490873557095265 110:-0.78125:10780:10783 160:1.515625:10781:10782 ~-0.06511435270827545 ~0.017022336863550414 "
    s .= "157:1.8125:10784:10801 118:0.40625:10785:10796 50:0.40625:10786:10795 211:-0.34375:10787:10788 ~-0.022387399699725394 89:0.625:10789:10794 245:1.5866666666666667:10790:10791 ~-0.03226324837591762 247:0.484375:10792:10793 "
    s .= "~0.00966021669496763 ~-0.019689566608111667 ~0.028469049847562773 ~-0.02224480274222926 245:1.962962962962963:10797:10800 221:-0.015625:10798:10799 ~-0.025821596956972132 ~0.02262244427220264 ~-0.029751593340157062 "
    s .= "~-0.033500162782511105 146:-0.109375:10803:10810 190:-0.015625:10804:10805 ~-0.022769893288857562 25:0.640625:10806:10809 245:2.80327868852459:10807:10808 ~0.011186920714954075 ~-0.01913828379910175 ~-0.05258487089959878 "
    s .= "~-0.037964489302629856 35:-0.9375:10812:10819 52:0.3125:10813:10818 160:0.015625:10814:10817 241:0.22:10815:10816 ~-0.05452319807566778 ~0.0289429336289883 ~0.029150919344978096 ~-0.018127519891270642 254:1.296875:10820:10851 "
    s .= "83:-1.03125:10821:10822 ~-0.03489320715148554 249:0.16666666666666666:10823:10830 111:-0.0078125:10824:10825 ~0.016100993303993564 113:0.0625:10826:10827 ~-0.020112624509338484 198:0.4375:10828:10829 ~0.013604678855270473 "
    s .= "~-0.028855462095026364 168:0.0703125:10831:10848 91:-0.109375:10832:10835 226:0.78125:10833:10834 ~-0.045607856296910075 ~0.020666252868056813 225:0.2734375:10836:10847 82:0.515625:10837:10842 160:1.140625:10838:10839 "
    s .= "~-0.03208910656081712 202:-0.078125:10840:10841 ~-0.05384676327797369 ~0.02620553744890765 178:0.265625:10843:10844 ~0.02409011794449445 1:-0.171875:10845:10846 ~-0.0686029368736093 ~-0.0054775120408695685 ~0.018105450437029137 "
    s .= "20:0.453125:10849:10850 ~0.006718637301083502 ~-0.02716878499877179 247:0.171875:10852:10857 114:-0.1328125:10853:10854 ~-0.0298598035498607 77:-0.265625:10855:10856 ~0.015452456854445965 ~-0.03672603010575175 "
    s .= "~-0.04798980205342527 253:-0.12445278298936874:10859:10862 49:0.34375:10860:10861 ~0.01886906794359075 ~-0.024581330899137912 254:1.015625:10863:10888 251:0.734375:10864:10869 213:0.5546875:10865:10868 205:-0.328125:10866:10867 "
    s .= "~-0.048941241478146574 ~-0.0020770007553852976 ~-0.05532278446809087 191:-0.109375:10870:10879 157:0.984375:10871:10878 214:0.28125:10872:10875 211:-0.0625:10873:10874 ~-0.01239556161224324 ~0.020571606297846226 "
    s .= "77:-0.546875:10876:10877 ~0.020611110806882577 ~-0.03900986541233788 ~0.028848253892945458 91:-0.328125:10880:10881 ~-0.05352245307703516 73:-0.25:10882:10883 ~-0.02645454821910311 226:0.171875:10884:10885 ~0.011316361077709945 "
    s .= "40:0.34375:10886:10887 ~-0.02473926396461081 ~0.024785951735913785 247:0.234375:10889:10904 190:0:10890:10891 ~-0.024485055181768044 25:0.640625:10892:10903 218:-0.109375:10893:10902 246:-0.390625:10894:10901 "
    s .= "98:-1.21875:10895:10896 ~0.03206732738257735 31:0.03125:10897:10900 211:0.3125:10898:10899 ~0.0225555912623199 ~-0.027860074231959082 ~-0.03398039480167584 ~0.03015773976368437 ~-0.03719167791443232 ~-0.0610242745590934 "
    s .= "~-0.03897242032013867 127:2.453125:10906:10951 82:1.140625:10907:10946 147:-0.1796875:10908:10911 163:1.375:10909:10910 ~-0.023568952284281307 ~0.029773739263416768 181:0.53125:10912:10943 191:0.59375:10913:10942 "
    s .= "46:0.703125:10914:10939 120:0.1328125:10915:10926 58:0.59375:10916:10925 154:0.359375:10917:10918 ~-0.031173016113606705 241:0.14:10919:10920 ~0.0269752214426231 202:0.484375:10921:10924 157:0.34375:10922:10923 "
    s .= "~0.009133713039144375 ~-0.034349382298003134 ~0.023017838228618522 ~0.01792507863353782 204:0.1953125:10927:10932 196:-0.125:10928:10929 ~-0.03567173760035913 158:-0.25:10930:10931 ~-0.019969475849947252 ~0.027019742720674242 "
    s .= "243:0.55:10933:10936 64:0.421875:10934:10935 ~-0.06136249200676365 ~0.0132893334831071 160:0.75:10937:10938 ~-0.013445637061628882 ~0.03698260596162805 109:1.359375:10940:10941 ~0.037696420752070955 ~-0.04149548776172948 "
    s .= "~-0.04397967373277952 103:0.546875:10944:10945 ~0.019307605768802538 ~-0.012271347241443692 181:1.5625:10947:10950 28:0.3125:10948:10949 ~0.018852356529312726 ~-0.013498683741501727 ~-0.023414381976395376 ~-0.041497410105270464 "
    s .= "248:1.375:10953:10996 245:4.878048780487805:10954:10995 85:1.25:10955:10990 100:1.09375:10956:10985 169:1.765625:10957:10984 217:-0.140625:10958:10959 ~-0.01956887021398417 100:-0.328125:10960:10961 ~0.02485112348148264 "
    s .= "169:0.21875:10962:10977 205:0.578125:10963:10974 61:0.46875:10964:10973 16:0.296875:10965:10970 238:0.09375:10966:10969 136:0.875:10967:10968 ~0.009130307080220642 ~-0.02961330992273651 ~-0.0292081607531868 "
    s .= "187:0.296875:10971:10972 ~0.024929113309115857 ~-0.04744741303816823 ~0.019553172476895142 208:0.578125:10975:10976 ~0.038603992422782056 ~-0.01624189204910516 97:0.109375:10978:10979 ~-0.0496422771074962 "
    s .= "243:0.6499999999999999:10980:10981 ~0.011495128215081436 219:0.2734375:10982:10983 ~-0.040733484689194924 ~0.013128394628912098 ~0.03643167934573901 243:0.6499999999999999:10986:10989 82:0.5625:10987:10988 ~-0.04320488746402182 "
    s .= "~0.024562989207899493 ~0.029996916420989273 208:-0.078125:10991:10994 2:-0.625:10992:10993 ~0.02167354707001081 ~-0.022778462635465558 ~0.016234918426814675 ~-0.05373648126720059 34:-0.25:10997:10998 ~0.021268102117411175 "
    s .= "~-0.05144276626522562 251:0.921875:11000:11021 199:-0.15625:11001:11002 ~-0.022188822182791938 153:0.5703125:11003:11020 121:-0.515625:11004:11005 ~-0.0544296739149069 248:1.375:11006:11019 245:1.5866666666666667:11007:11008 "
    s .= "~-0.03720546218165011 127:1.875:11009:11018 178:1.0625:11010:11015 163:-0.09375:11011:11012 ~-0.026319681403987272 142:-0.171875:11013:11014 ~-0.03471246558179807 ~0.005209691312382181 37:0.4375:11016:11017 ~0.035613430418642976 "
    s .= "~-0.04109641471254374 ~-0.0442037505205523 ~-0.048833740038246136 ~-0.048989347993583066 157:0.59375:11022:11041 252:1.0750000000000002:11023:11036 124:0.203125:11024:11033 61:-0.046875:11025:11028 37:0.28125:11026:11027 "
    s .= "~-0.041872261154062784 ~0.03032777802502558 69:0.2109375:11029:11032 147:0.4453125:11030:11031 ~0.024447791507138505 ~-0.038981551096834315 ~-0.012098743781252344 178:1.25:11034:11035 ~-0.03631764711607358 ~0.028728084907932536 "
    s .= "243:1.75:11037:11038 ~0.033074195298097235 82:0.96875:11039:11040 ~-0.046591057758129203 ~0.029369122561349242 229:-0.1875:11042:11043 ~-0.013876099793827751 244:2.45:11044:11045 ~0.020256083783109356 ~-0.03907956963994358 "
    s .= "253:-0.055555555555561874:11047:11072 250:1.2578125:11048:11071 245:1.8111111111111111:11049:11054 148:0.140625:11050:11053 74:-0.265625:11051:11052 ~-0.0434451995129612 ~0.026846799495007387 ~-0.05772900379242521 "
    s .= "202:-0.015625:11055:11060 133:1.59375:11056:11059 1:0.203125:11057:11058 ~0.010442415984308798 ~-0.04352137946500817 ~-0.0540357863805577 256:0.07692307692307693:11061:11070 214:0.75:11062:11069 241:0.26:11063:11068 "
    s .= "136:1.15625:11064:11067 80:0.03125:11065:11066 ~0.03358560650520459 ~-0.049362415589246 ~-0.0694210592047093 ~0.032598181776964046 ~-0.03565006746492219 ~-0.025997301714047873 ~0.02838684828271959 73:1.140625:11073:11092 "
    s .= "242:0.55:11074:11079 25:-0.4375:11075:11076 ~0.028464265377456804 129:0.1640625:11077:11078 ~0.006616183595103024 ~-0.02023723428267648 136:0.34375:11080:11083 96:0.1171875:11081:11082 ~-0.04232591423663339 ~-0.008464398018556201 "
    s .= "75:0.0703125:11084:11091 178:0.203125:11085:11088 171:0:11086:11087 ~0.020518775499880237 ~-0.024882976845804667 240:0.03125:11089:11090 ~-0.04128314842497413 ~0.0003200417626471855 ~0.011710416848994019 ~-0.034791114114703904 "
    s .= "248:0.375:11094:11115 98:-0.640625:11095:11096 ~0.01578108776720689 107:-0.890625:11097:11098 ~-0.03662146568690574 254:1.390625:11099:11114 31:0.15625:11100:11109 245:3.463768115942029:11101:11108 "
    s .= "252:0.42500000000000004:11102:11105 210:0.4140625:11103:11104 ~0.008727081323410721 ~-0.03318495925170661 244:1.01:11106:11107 ~-0.01783371016572208 ~0.026459652478290043 ~-0.030197664489385375 244:1.47:11110:11113 "
    s .= "195:0.2890625:11111:11112 ~-0.050186639997422205 ~-0.003816338511180047 ~0.013767025372923914 ~-0.03360051373098908 121:-0.21875:11116:11119 151:-0.4375:11117:11118 ~0.017524491051838908 ~-0.04684404853049859 "
    s .= "214:0.578125:11120:11137 232:-0.15625:11121:11122 ~-0.034926983129387294 232:0.40625:11123:11136 25:-0.265625:11124:11125 ~0.02612200016438341 220:0.328125:11126:11135 241:0.32:11127:11132 31:-0.078125:11128:11129 "
    s .= "~0.0038129955788906373 31:0.203125:11130:11131 ~-0.05683092574826089 ~-0.0020605322821703686 172:0.25:11133:11134 ~0.020263379331535436 ~-0.031006735544590748 ~0.021496539957753823 ~-0.03000633647148203 175:0.390625:11138:11139 "
    s .= "~0.03208998901803525 ~-0.02149048497948038 143:0.140625:11141:11184 253:-0.04464285714285676:11142:11157 252:0.175:11143:11152 219:0.3046875:11144:11149 58:0:11145:11146 ~0.013794701421753526 17:-0.890625:11147:11148 "
    s .= "~0.012402189309267389 ~-0.037263636562572686 245:1.9423076923076923:11150:11151 ~-0.03004194688388795 ~0.038192889587663675 214:0.703125:11153:11154 ~0.026671671625348614 112:0.609375:11155:11156 ~-0.0749628912999547 "
    s .= "~0.015866262167741584 242:0.55:11158:11173 34:-0.203125:11159:11160 ~0.018707167539957516 130:1.265625:11161:11170 4:-0.03125:11162:11167 223:1.21875:11163:11166 1:-0.3125:11164:11165 ~0.004942823267813557 ~-0.04658496440798146 "
    s .= "~0.035724106615681955 246:-0.359375:11168:11169 ~-0.014809195905504067 ~0.015572038176626666 248:0.375:11171:11172 ~0.026033193426680725 ~-0.01099729131070341 252:0.025:11174:11177 220:0.9375:11175:11176 ~-0.04181845018931776 "
    s .= "~0.0222116664660746 75:0.0859375:11178:11181 42:-0.1640625:11179:11180 ~0.0057241350192718185 ~-0.025125704762471935 28:0.421875:11182:11183 ~0.021827428856473662 ~-0.027924135655815127 172:-0.171875:11185:11186 "
    s .= "~-0.038584006403177745 ~-0.005082223010996538 249:0.16666666666666666:11188:11211 178:-0.078125:11189:11198 235:-0.015625:11190:11193 106:0.375:11191:11192 ~-0.04475740016304298 ~0.021977406835553458 76:0.03125:11194:11195 "
    s .= "~-0.003222883284364384 100:0.859375:11196:11197 ~-0.089909567548563 ~0.005039988857650354 166:0.234375:11199:11204 253:-0.043604651162790255:11200:11201 ~0.02959611281979307 211:-0.25:11202:11203 ~-0.04193753405897619 "
    s .= "~0.010405553860402927 250:0.7734375:11205:11208 145:0.09375:11206:11207 ~0.005903721196355001 ~-0.0656800729837289 247:0.296875:11209:11210 ~0.01090146150952441 ~-0.0395378016112329 38:-0.96875:11212:11213 ~0.015767177754834865 "
    s .= "120:0.0703125:11214:11223 235:0:11215:11220 82:1.265625:11216:11219 201:0.2734375:11217:11218 ~-0.048981962974431345 ~0.0007129315282513744 ~0.002960985423514046 81:0.1640625:11221:11222 ~-0.00206874710452537 "
    s .= "~-0.04190760722026876 71:0.171875:11224:11229 50:0.21875:11225:11228 246:-0.140625:11226:11227 ~-0.0069222978521347915 ~0.019275190970687674 ~-0.029380159763600634 165:0.2109375:11230:11231 ~-0.03237061904256596 "
    s .= "15:0.2734375:11232:11233 ~0.021697653543976906 ~-0.029535225773989537 251:0.921875:11235:11262 242:2.05:11236:11261 66:0.5703125:11237:11260 64:1.375:11238:11259 181:0.640625:11239:11250 184:0:11240:11247 100:0.125:11241:11246 "
    s .= "163:0.921875:11242:11245 223:1.078125:11243:11244 ~-0.05152002691035416 ~0.02803388185787908 ~0.01973816038477386 ~0.005811776921122854 100:0.140625:11248:11249 ~0.011888290821168324 ~-0.0055482340105159865 "
    s .= "55:0.453125:11251:11258 130:1.203125:11252:11255 245:1.8313253012048192:11253:11254 ~0.009791790243509846 ~-0.03549249942981057 160:1.609375:11256:11257 ~0.029648272214450662 ~-0.03115910681116449 ~-0.04545336547785999 "
    s .= "~0.02629751921696731 ~-0.03955829039032512 ~-0.04106448697945117 235:0.109375:11263:11278 245:3.5076923076923077:11264:11277 241:0.48:11265:11274 23:0.015625:11266:11271 207:0.4140625:11267:11270 139:0.109375:11268:11269 "
    s .= "~-0.004188524589454272 ~0.03433708601752739 ~-0.036376375897836426 46:0.5:11272:11273 ~-0.038167404148957716 ~0.027930088894577293 40:0.53125:11275:11276 ~0.025817166876903982 ~-0.035514702836453145 ~-0.04299922019664616 "
    s .= "152:-0.265625:11279:11280 ~0.013228586819813253 ~-0.016133381207693014 255:0.296875:11282:11317 251:0.203125:11283:11286 178:0.4375:11284:11285 ~-0.03658802099018811 ~0.010218118546500794 254:0.703125:11287:11310 "
    s .= "14:-0.421875:11288:11291 49:0.21875:11289:11290 ~0.025677912575965207 ~-0.01221999625099491 245:1.6219512195121952:11292:11295 246:1.765625:11293:11294 ~-0.045508004123935714 ~0.02867044204815013 11:-0.140625:11296:11303 "
    s .= "200:-0.359375:11297:11298 ~0.009234512146455789 246:0.171875:11299:11302 61:1.34375:11300:11301 ~-0.0698422808997446 ~0.0073565393038912755 ~-0.008105142134953966 142:0.453125:11304:11307 255:0.078125:11305:11306 "
    s .= "~0.017494505483599942 ~-0.006270897792013507 196:0:11308:11309 ~0.006822994798560866 ~-0.03816934563567782 244:1.145:11311:11312 ~0.03124240376542082 160:0.28125:11313:11314 ~-0.013895351996874026 19:-0.234375:11315:11316 "
    s .= "~-0.030240109294337826 ~0.025389704716736003 159:0.3984375:11318:11327 146:-0.125:11319:11320 ~0.0008738197713137552 89:0.5625:11321:11326 254:0.609375:11322:11323 ~0.0061188638587140005 19:-0.03125:11324:11325 "
    s .= "~-0.0531768576309069 ~-0.015809170514267053 ~0.02364586742100855 ~-0.04484191929012113 222:-0.3984375:11329:11336 179:-0.84375:11330:11335 34:0.296875:11331:11334 248:0.375:11332:11333 ~0.03348704013695861 ~-0.031146832759510856 "
    s .= "~-0.053712994185295994 ~-0.04256754082230557 87:-0.1796875:11337:11346 130:0.953125:11338:11343 180:-0.3828125:11339:11340 ~-0.041422846377715185 109:0.609375:11341:11342 ~-0.017671920003230562 ~0.017353719927879867 "
    s .= "86:-0.234375:11344:11345 ~0.0255375021862045 ~-0.024407120626618484 255:0.234375:11347:11356 110:-0.296875:11348:11349 ~-0.019791565140844375 77:-0.125:11350:11351 ~0.019412259514612132 112:0.359375:11352:11355 "
    s .= "225:0.0234375:11353:11354 ~0.015101628730375169 ~-0.02243015392318172 ~0.006476941029004428 241:0.12:11357:11360 174:0.140625:11358:11359 ~0.01805555474941009 ~-0.026650418122919357 251:1.390625:11361:11368 85:1.28125:11362:11363 "
    s .= "~-0.02603461548166372 253:-0.03472222222222143:11364:11365 ~0.026200833076940846 26:-0.453125:11366:11367 ~0.016552230572904628 ~-0.03699761587853758 246:0.609375:11369:11374 131:0.015625:11370:11371 ~0.008904951450832203 "
    s .= "23:-0.40625:11372:11373 ~0.0018260383433372402 ~-0.06123418639859664 ~0.023746737654288 130:2.46875:11376:11419 249:0.16666666666666666:11377:11398 178:-0.078125:11378:11381 251:1.328125:11379:11380 ~-0.02615850182372725 "
    s .= "~0.0256287344369622 166:0.234375:11382:11385 253:-0.043604651162790255:11383:11384 ~0.03033144574313712 ~0.007636245902300844 250:0.7734375:11386:11389 205:0.03125:11387:11388 ~0.021251498283460644 ~-0.053221532517569704 "
    s .= "256:0.07692307692307693:11390:11395 244:1.08:11391:11392 ~-0.028849181294221565 248:0.375:11393:11394 ~0.02862964759877569 ~-0.026820045022717162 70:0.125:11396:11397 ~-0.08264119713929305 ~0.013295017298586818 "
    s .= "187:-0.3125:11399:11400 ~-0.03745895976057681 58:-0.0625:11401:11404 151:0.0625:11402:11403 ~0.023106951204137884 ~-0.006025073424538972 91:0.015625:11405:11410 36:0.5234375:11406:11409 79:0.890625:11407:11408 "
    s .= "~-0.042848499196532594 ~0.004843740453926815 ~0.015146402588309111 16:0.828125:11411:11418 245:1.736842105263158:11412:11415 116:0.625:11413:11414 ~-0.03387578143339017 ~0.0265671726648626 157:-0.015625:11416:11417 "
    s .= "~-0.026573754781281423 ~0.007142199891748944 ~-0.0452564180088481 22:0.234375:11420:11421 ~-0.05138239768936013 ~0.02245284304754115 124:0:11423:11434 43:-0.0625:11424:11425 ~0.0055456104197176125 241:0.46:11426:11431 "
    s .= "163:1.234375:11427:11430 208:-0.234375:11428:11429 ~0.016740602571181054 ~-0.04095495877609242 ~0.02402862254745128 52:0.125:11432:11433 ~0.014679589406880716 ~-0.02786903833617693 124:0.109375:11435:11440 64:0:11436:11439 "
    s .= "169:0:11437:11438 ~0.01907180336517852 ~-0.03249282294638466 ~0.02257492259253073 244:1.47:11441:11458 163:0.625:11442:11455 139:0.171875:11443:11446 199:0.671875:11444:11445 ~-0.027265362270787005 ~0.025787557222525376 "
    s .= "145:-0.078125:11447:11448 ~-0.03294177406645748 154:0.65625:11449:11454 82:0.140625:11450:11451 ~0.023169694367503213 223:0.921875:11452:11453 ~-0.025013752170539624 ~0.039578107786279154 ~0.025213666703052508 "
    s .= "72:0.2265625:11456:11457 ~-0.04260033753087729 ~-0.000014391563913686742 252:0.375:11459:11468 160:0.390625:11460:11463 31:0.765625:11461:11462 ~-0.04545597298868704 ~0.032555653599928916 19:0.03125:11464:11467 "
    s .= "253:-0.04812030075187985:11465:11466 ~0.0394324066014331 ~-0.04706495174928217 ~0.02643710845593048 ~0.026075145380892187 243:2.1500000000000004:11470:11515 253:-0.13262032085561656:11471:11476 7:0.125:11472:11473 "
    s .= "~0.024020395280617193 109:1.203125:11474:11475 ~-0.03606321671596026 ~0.01838611520924581 160:0.9375:11477:11512 147:-0.2578125:11478:11479 ~-0.02704568431778734 178:0.9375:11480:11511 109:1.5625:11481:11506 "
    s .= "190:-0.171875:11482:11483 ~-0.030133884385046335 85:1.46875:11484:11505 67:-0.0625:11485:11492 172:0.453125:11486:11489 243:0.75:11487:11488 ~-0.04633815172106535 ~-0.0023623670611390146 202:0.375:11490:11491 "
    s .= "~0.038123507701627736 ~-0.04248552715917137 46:0.078125:11493:11498 177:0.2265625:11494:11495 ~0.02058746496961191 151:0.546875:11496:11497 ~-0.04002235011761149 ~0.0211808469512683 251:1.734375:11499:11504 241:0.1:11500:11503 "
    s .= "46:0.328125:11501:11502 ~-0.04133762509619199 ~0.03540537009001803 ~-0.02515550868664287 ~0.02252052389693153 ~0.03577276754527245 88:0.4375:11507:11510 25:-0.265625:11508:11509 ~0.0075808382763755955 ~-0.05850194668278555 "
    s .= "~0.004440804286335685 ~0.01670358156715129 31:0.765625:11513:11514 ~0.009451288701087001 ~-0.031491328892931617 ~-0.024917774494152875 98:-0.140625:11517:11548 99:-0.1171875:11518:11521 90:0.1484375:11519:11520 "
    s .= "~-0.0017061812375460204 ~-0.046510282151421015 252:0.475:11522:11545 205:0.5625:11523:11542 242:0.55:11524:11535 105:0.0703125:11525:11526 ~0.02105045907698906 184:0.15625:11527:11532 236:-0.78125:11528:11529 "
    s .= "~0.021522135838903254 142:0.421875:11530:11531 ~-0.045096174521711774 ~0.021909854598026815 127:0.328125:11533:11534 ~0.027363087938687743 ~-0.023554455710606867 220:0.625:11536:11541 160:0.546875:11537:11540 "
    s .= "64:1.421875:11538:11539 ~-0.05120700298100039 ~0.02989805991787467 ~-0.0012227658504660667 ~0.030195301584899525 190:0.671875:11543:11544 ~0.030720132905301175 ~-0.02541839336956261 37:-0.234375:11546:11547 ~-0.024005450633259234 "
    s .= "~0.02869438097401208 89:0.625:11549:11560 218:0.328125:11550:11557 133:2.046875:11551:11556 100:1.046875:11552:11555 65:-0.125:11553:11554 ~-0.024025959921206628 ~-0.0013616469235823551 ~0.025396425980474258 ~-0.04314265237798768 "
    s .= "131:0.296875:11558:11559 ~0.002111257886205226 ~-0.045193008023885 232:0.375:11561:11562 ~0.01963774799236761 ~-0.03867037400624706 248:1.375:11564:11607 96:0.8828125:11565:11606 120:0.0703125:11566:11583 247:0.359375:11567:11582 "
    s .= "242:2.05:11568:11581 40:-0.015625:11569:11570 ~-0.00819873240009124 109:0.609375:11571:11574 175:0.28125:11572:11573 ~-0.022306613861753758 ~0.012185038658238903 245:3.5483870967741935:11575:11578 121:-0.34375:11576:11577 "
    s .= "~-0.038317828478835 ~0.01682381449055663 23:-1.28125:11579:11580 ~0.0335682003007236 ~-0.07266688701886011 ~-0.038676865154366386 ~-0.04325057154841618 28:0.5:11584:11603 142:0.6875:11585:11600 143:0.21875:11586:11599 "
    s .= "251:0.171875:11587:11588 ~-0.02779034231826747 76:0.09375:11589:11590 ~0.022412331257178668 76:0.375:11591:11596 97:-0.015625:11592:11593 ~-0.043941655325308804 236:0.109375:11594:11595 ~0.013799061089150542 "
    s .= "~-0.048257509031669164 133:0.671875:11597:11598 ~-0.011299522902433953 ~0.03428976649087647 ~-0.004525694594232247 241:1.5:11601:11602 ~-0.03682667075390888 ~0.02019712700702181 211:0.03125:11604:11605 ~0.005407338674856266 "
    s .= "~-0.05106902508588082 ~-0.04322474520879286 34:-0.25:11608:11609 ~0.020004955086987943 ~-0.05020411383750894 251:0.921875:11611:11630 199:-0.15625:11612:11615 243:1.05:11613:11614 ~-0.009608652951353672 ~-0.051821524636374953 "
    s .= "153:0.5703125:11616:11629 121:-0.515625:11617:11618 ~-0.05175912383107156 248:1.375:11619:11628 245:1.5866666666666667:11620:11621 ~-0.035435526895945445 127:1.875:11622:11627 178:1.0625:11623:11624 ~0.0007737809667429218 "
    s .= "37:0.4375:11625:11626 ~0.034155480148833704 ~-0.038564595085448496 ~-0.040730266019854494 ~-0.047108819159028 ~-0.046699329575824705 157:0.59375:11631:11652 199:0.09375:11632:11641 252:0.07500000000000001:11633:11640 "
    s .= "242:0.55:11634:11637 151:0.078125:11635:11636 ~-0.0240908048976599 ~0.03318885554512396 163:0.515625:11638:11639 ~-0.05750622393736082 ~0.02938447175302597 ~0.01784119968555442 124:0.203125:11642:11649 130:1.140625:11643:11648 "
    s .= "217:0.140625:11644:11645 ~0.004429706926528016 253:-0.09523809523809253:11646:11647 ~0.02778197484117839 ~-0.06080292912758998 ~0.03023757554700006 191:-0.234375:11650:11651 ~-0.0034203152975168408 ~-0.05293382322606974 "
    s .= "229:-0.1875:11653:11654 ~-0.014210816982669926 244:2.45:11655:11656 ~0.019736827373522087 ~-0.03528704910223939 170:0.34375:11658:11703 246:0.609375:11659:11696 247:0.234375:11660:11691 239:-0.125:11661:11684 "
    s .= "187:0.03125:11662:11665 109:1.703125:11663:11664 ~0.0011947623611731433 ~-0.03515470563427962 52:0.453125:11666:11679 85:1.25:11667:11678 134:-0.125:11668:11677 112:1.578125:11669:11676 88:0.09375:11670:11671 "
    s .= "~0.012822293815321776 67:0.484375:11672:11675 64:0.078125:11673:11674 ~-0.03350447937136976 ~0.004852642604923428 ~-0.055733026990179374 ~0.028229576985969264 ~0.02381186385246761 ~0.029368299744951216 94:0.921875:11680:11683 "
    s .= "214:0.65625:11681:11682 ~0.007175133376717698 ~-0.05263487220206712 ~-0.06792182301847866 253:-0.04464285714285676:11685:11686 ~0.009849323155948723 241:0.18:11687:11688 ~0.0020939529136888894 22:0.03125:11689:11690 "
    s .= "~-0.047887586968514445 ~-0.010496610359134191 130:0.3125:11692:11695 192:0.3828125:11693:11694 ~-0.02297872308037488 ~0.030178495595878554 ~-0.03241041217174094 168:0.0703125:11697:11698 ~-0.005653566996982204 "
    s .= "20:0.453125:11699:11700 ~0.024519129218279007 138:0.2578125:11701:11702 ~-0.046621513823810724 ~0.019319924398678433 ~-0.013637879260987307 72:0.8203125:11705:11750 254:0.984375:11706:11737 191:-0.421875:11707:11714 "
    s .= "251:0.234375:11708:11709 ~-0.024693080684973053 22:0:11710:11711 ~0.026632783447910174 70:0.40625:11712:11713 ~0.012332344770121849 ~-0.02838378202229147 72:0.1328125:11715:11728 151:0.203125:11716:11723 206:-0.375:11717:11718 "
    s .= "~0.02443789213635812 221:-0.421875:11719:11720 ~-0.05363158531116469 251:0.484375:11721:11722 ~-0.021453981638663737 ~0.011385586085545253 249:0.16666666666666666:11724:11725 ~-0.0021282568987786776 169:2.078125:11726:11727 "
    s .= "~-0.03824514612675058 ~0.030965708207942495 252:1.125:11729:11736 204:0.1484375:11730:11735 170:0.09375:11731:11732 ~0.02421513793524009 22:0.09375:11733:11734 ~-0.03459546440982844 ~0.018281997547779864 ~-0.01192041613709677 "
    s .= "~0.026199346413923453 247:0.203125:11738:11749 168:-0.0390625:11739:11748 115:1.15625:11740:11747 73:0.34375:11741:11746 115:0.203125:11742:11745 40:0.09375:11743:11744 ~-0.025393968286048868 ~0.016118325742768804 "
    s .= "~-0.0406310669181753 ~0.013650586995129534 ~0.014714131019818697 ~0.008756268568177917 ~-0.02675477857516726 ~-0.035623503732654466 124:-0.703125:11752:11753 ~-0.037766406620031445 85:1.453125:11754:11789 16:0.828125:11755:11788 "
    s .= "79:1.5625:11756:11785 46:0.8125:11757:11784 178:1.0625:11758:11783 211:0.125:11759:11768 246:-1.953125:11760:11761 ~-0.04023726258812212 212:0.109375:11762:11767 187:0.015625:11763:11766 229:0.078125:11764:11765 "
    s .= "~0.004672161923563974 ~-0.03429922570422627 ~0.014765152462411177 ~-0.014560983020875495 210:0.2890625:11769:11780 184:0.375:11770:11777 106:0.453125:11771:11774 91:0.171875:11772:11773 ~-0.029875239560708523 "
    s .= "~0.015395615910504368 217:0.1875:11775:11776 ~-0.022641117913239545 ~-0.0703464301990357 166:0.609375:11778:11779 ~0.013201389244345819 ~-0.027148981797435502 256:0.1111111111111111:11781:11782 ~-0.05002846900267706 "
    s .= "~0.004527882712462651 ~0.014177868334758637 ~0.023212600825196186 133:1.765625:11786:11787 ~0.03560984438395921 ~-0.030893067485532767 ~-0.031180062925309972 181:1.296875:11790:11793 181:-0.015625:11791:11792 "
    s .= "~-0.008823606779490208 ~0.024897671313213347 242:0.35:11794:11795 ~-0.0551425894514832 94:0.421875:11796:11797 ~0.013421776857802173 ~-0.05210973366512339 243:2.1500000000000004:11799:11842 255:0.234375:11800:11819 "
    s .= "254:0.453125:11801:11810 251:0.671875:11802:11803 ~-0.008853450281066107 131:0.4375:11804:11805 ~0.012438928921772403 44:-0.09375:11806:11807 ~0.018383068078312744 246:1.390625:11808:11809 ~-0.03778805323692471 "
    s .= "~0.006575061954900416 218:0.09375:11811:11814 86:-0.3125:11812:11813 ~-0.016469806797113684 ~0.03195470903954274 245:1.8644067796610169:11815:11816 ~0.023773413136594132 125:-0.03125:11817:11818 ~0.02333681521738205 "
    s .= "~-0.04964343927087464 98:-0.578125:11820:11823 239:-0.078125:11821:11822 ~0.00875464687455304 ~-0.029724331719533488 129:0.1640625:11824:11837 124:0.03125:11825:11828 56:0.109375:11826:11827 ~-0.02601082409574615 "
    s .= "~0.013362762207701577 178:0.078125:11829:11830 ~0.01593577554103309 122:0:11831:11834 134:0.125:11832:11833 ~-0.0081278967859636 ~0.028128219912965033 184:1.1875:11835:11836 ~-0.04216296066592762 ~0.027567562365582884 "
    s .= "28:-0.3125:11838:11839 ~0.013872590037525615 85:1.546875:11840:11841 ~-0.04627514359642765 ~0.007134451251445358 252:2.825:11843:11844 ~-0.049701882811392206 ~0.001417814264965401 248:0.375:11846:11865 98:-0.640625:11847:11848 "
    s .= "~0.014645341150792846 107:-0.890625:11849:11850 ~-0.03366332486676817 100:1.09375:11851:11862 254:1.390625:11852:11861 238:0.53125:11853:11858 205:0.71875:11854:11857 250:0.5859375:11855:11856 ~-0.03515968167397545 "
    s .= "~0.0014452018661559706 ~0.028763693071379826 112:1.015625:11859:11860 ~-0.05095759232241284 ~0.021255387382843587 ~-0.03737455623398534 253:-0.008590102707748947:11863:11864 ~0.04572626665780932 ~-0.003978009196986071 "
    s .= "121:-0.21875:11866:11869 151:-0.4375:11867:11868 ~0.015178367776084237 ~-0.045374720028341385 99:-0.4453125:11870:11871 ~-0.04740113180424552 214:0.578125:11872:11889 232:-0.15625:11873:11874 ~-0.032132312154920066 "
    s .= "232:0.40625:11875:11888 220:0.5:11876:11887 25:-0.203125:11877:11878 ~0.02348664113433211 241:0.32:11879:11884 124:0.0625:11880:11881 ~-0.047651906734642056 118:0.234375:11882:11883 ~0.006884659470162985 ~-0.04795710115330977 "
    s .= "172:0.3125:11885:11886 ~0.020232502672136263 ~-0.02117768814717318 ~0.030026644453984497 ~-0.02667640824017294 175:0.34375:11890:11891 ~0.0334227846241794 ~-0.013711130371074631 253:-0.12445278298936874:11893:11896 "
    s .= "49:0.34375:11894:11895 ~0.01771941553259183 ~-0.02347686560367602 239:-0.109375:11897:11930 75:-0.0390625:11898:11907 63:-0.0703125:11899:11906 141:-0.0859375:11900:11903 191:-0.390625:11901:11902 ~0.002182432679647677 "
    s .= "~-0.029041654895580266 162:0.0703125:11904:11905 ~0.029745458577897933 ~-0.014201272056023968 ~-0.027138767534989464 110:-0.5:11908:11917 122:-1.1875:11909:11910 ~0.0326375261272864 109:1.15625:11911:11914 "
    s .= "158:-0.21875:11912:11913 ~-0.04758642477529848 ~0.017456048113536165 125:-0.578125:11915:11916 ~0.02656805217760746 ~-0.03996967555968771 238:0.171875:11918:11923 249:0.5:11919:11920 ~0.025303723472605896 31:-0.109375:11921:11922 "
    s .= "~0.019934692933353912 ~-0.01808637590307743 251:1.078125:11924:11927 240:-0.03125:11925:11926 ~0.010291253232024606 ~-0.03465800591185873 106:0.515625:11928:11929 ~-0.012933044229746497 ~0.03875556464618521 "
    s .= "175:-0.171875:11931:11934 60:0.6171875:11932:11933 ~-0.04604062425120275 ~0.025056718915448795 254:1.078125:11935:11938 169:1.765625:11936:11937 ~-0.003994386472747496 ~0.033672997710140255 ~-0.04046660511410308 "
    s .= "130:2.46875:11940:11983 205:-0.34375:11941:11942 ~-0.020649770637820163 160:1.140625:11943:11976 147:-0.2578125:11944:11945 ~-0.022835827901795877 178:0.9375:11946:11975 55:1.078125:11947:11974 244:1.985:11948:11971 "
    s .= "250:0.9453125:11949:11954 214:0.609375:11950:11953 248:0.875:11951:11952 ~0.00635524467498502 ~-0.04010797398474099 ~0.032418659207077045 151:0.984375:11955:11970 58:-0.046875:11956:11959 126:0.1328125:11957:11958 "
    s .= "~-0.02151604121708651 ~0.02160654743735635 115:0.765625:11960:11969 61:0.96875:11961:11966 232:0.0625:11962:11963 ~-0.01414897070801672 169:0.671875:11964:11965 ~-0.053431934041023456 ~0.021229754564317003 "
    s .= "121:-0.046875:11967:11968 ~-0.03249837870026172 ~0.03254429951583797 ~0.007863625647643662 ~0.02400937037435036 181:0.96875:11972:11973 ~-0.04302396819395248 ~0.03126296646091102 ~0.02268188271173345 ~0.018189649650940824 "
    s .= "7:0.265625:11977:11982 162:0.3203125:11978:11981 61:-0.234375:11979:11980 ~-0.012698957390804667 ~0.02409422884535319 ~-0.03772823973640255 ~-0.01723579082879446 61:0.546875:11984:11985 ~-0.050869101846021274 ~0.01783636487087324 "
    s .= "251:0.921875:11987:12002 247:0.703125:11988:12001 64:1.375:11989:12000 181:0.640625:11990:11993 184:0:11991:11992 ~-0.014168455654640142 ~0.0034796569626806178 55:0.453125:11994:11999 130:1.296875:11995:11996 "
    s .= "~-0.020899675726730023 160:1.671875:11997:11998 ~0.030001890247160476 ~-0.03336395302646399 ~-0.04152012248988388 ~0.023577792557987403 ~-0.0378917878968889 184:0.46875:12003:12028 245:3.5483870967741935:12004:12027 "
    s .= "252:0.575:12005:12018 242:0.55:12006:12009 194:-0.140625:12007:12008 ~0.015814247800943048 ~-0.015002071864320864 163:1.421875:12010:12017 248:0.125:12011:12012 ~0.00026183092016120017 253:0.1830357142857153:12013:12016 "
    s .= "250:1.3671875:12014:12015 ~-0.055590190729591475 ~0.007846322884706767 ~0.02323635493988564 ~0.02878913574157221 223:0.1875:12019:12022 49:-0.265625:12020:12021 ~-0.03381629999132764 ~0.03180806783251201 209:-0.046875:12023:12024 "
    s .= "~0.024480437275067966 117:0.0703125:12025:12026 ~-0.10734493171266529 ~-0.007031519917355207 ~-0.05261858840079639 28:0.453125:12029:12032 97:0.5:12030:12031 ~0.022897170164302906 ~-0.02359390644830196 ~-0.02413842110794173 "
    s .= "253:-0.04464285714285676:12034:12051 252:0.225:12035:12046 245:1.8235294117647058:12036:12037 ~-0.03189398635359152 219:0.3046875:12038:12045 88:0.09375:12039:12042 235:0.078125:12040:12041 ~-0.05897921927546667 "
    s .= "~0.01617660630688408 49:0.21875:12043:12044 ~0.017955954783151273 ~-0.03795921042587638 ~0.0310198698352364 166:0.1875:12047:12048 ~0.026987317292567616 97:0:12049:12050 ~-0.040319964286361296 ~0.020804005599200842 "
    s .= "190:0:12052:12063 181:0.15625:12053:12060 52:0.078125:12054:12057 256:0.43478260869565216:12055:12056 ~-0.0508109910791565 ~0.009206887510516982 19:-0.0625:12058:12059 ~-0.0527375587296997 ~0.0041873933100515645 "
    s .= "148:0.203125:12061:12062 ~0.014914802438592152 ~-0.02012515671507024 142:-0.328125:12064:12065 ~-0.0438279708937052 55:0.109375:12066:12069 115:-0.34375:12067:12068 ~-0.059507719654046914 ~0.010235151702440253 "
    s .= "148:1.046875:12070:12079 136:1.09375:12071:12076 190:0.125:12072:12073 ~0.002559117637652304 251:1.640625:12074:12075 ~-0.04325908974808415 ~0.005520382851041596 133:1.921875:12077:12078 ~0.01355454332821151 "
    s .= "~-0.043058954000944914 ~0.023855489119763845 35:-0.9375:12081:12088 251:0.359375:12082:12085 34:-0.015625:12083:12084 ~0.021066411839084444 ~-0.0432054390044017 52:0.328125:12086:12087 ~0.027754773230138193 ~-0.007949919671574565 "
    s .= "255:0.265625:12089:12112 254:0.703125:12090:12105 245:1.6219512195121952:12091:12094 246:1.734375:12092:12093 ~-0.03857459003037597 ~0.028836119918780462 246:-1.203125:12095:12098 203:-0.390625:12096:12097 ~-0.002368517181552719 "
    s .= "~-0.05699666104094506 255:0.078125:12099:12100 ~0.010844186029330913 242:0.55:12101:12102 ~0.004928007009707601 188:0.296875:12103:12104 ~-0.036435792722341355 ~0.0040821180853750465 218:0.09375:12106:12107 ~0.02289845723843035 "
    s .= "245:1.765625:12108:12109 ~0.028606265416267734 125:-0.015625:12110:12111 ~0.01969460651065648 ~-0.042461858200068196 247:0.296875:12113:12122 224:0.015625:12114:12117 113:0.328125:12115:12116 ~-0.0030271947562115083 "
    s .= "~0.02474109708825364 254:0.515625:12118:12119 ~0.026939858481827745 140:-0.078125:12120:12121 ~0.001208145905441987 ~-0.05027188626884308 251:2.421875:12123:12126 9:0.6015625:12124:12125 ~-0.044293063763638035 "
    s .= "~0.018204897053886775 ~0.027254972237640274 248:1.375:12128:12171 124:0:12129:12138 119:-0.796875:12130:12131 ~0.015904801655334044 255:0.453125:12132:12137 22:0.015625:12133:12136 64:0.578125:12134:12135 ~0.008578033396185911 "
    s .= "~-0.031302476058140336 ~-0.01701084862223404 ~-0.03265116732827188 124:0.109375:12139:12144 64:0:12140:12143 169:0:12141:12142 ~0.018634089031348992 ~-0.030368498006887852 ~0.02129451248667239 244:1.63:12145:12162 "
    s .= "142:-0.265625:12146:12147 ~-0.037431886612913634 70:0.46875:12148:12159 59:-0.15625:12149:12152 204:-0.3671875:12150:12151 ~-0.024251872096195712 ~0.013183253853719002 202:0.25:12153:12156 34:-0.234375:12154:12155 "
    s .= "~0.028914719915115197 ~-0.00796531402226775 120:0.0859375:12157:12158 ~-0.05936400267714366 ~-0.008188770518764512 172:0.140625:12160:12161 ~0.005913884343734001 ~-0.042948607891554025 245:3.8275862068965516:12163:12170 "
    s .= "252:0.375:12164:12169 52:0.34375:12165:12168 111:-0.1796875:12166:12167 ~0.024751587923455276 ~-0.041117344992776375 ~0.034706305608310714 ~0.035840482976404 ~-0.040759924916988405 201:0.2890625:12172:12173 ~-0.04876788746557644 "
    s .= "~0.019512942791997653 253:-0.055555555555561874:12175:12204 208:0.15625:12176:12193 252:0.275:12177:12188 194:0.21875:12178:12187 133:1.59375:12179:12184 242:1.15:12180:12183 150:0.5859375:12181:12182 ~0.03087775203961431 "
    s .= "~-0.03225749719300101 ~-0.024950208468330057 199:0.15625:12185:12186 ~-0.05049042041290552 ~0.029174971589123574 ~-0.044265386867563976 166:0.1875:12189:12190 ~0.0368809434062951 235:0.125:12191:12192 ~0.018212492620235526 "
    s .= "~-0.0443433097559729 109:1.171875:12194:12199 60:0.3828125:12195:12198 17:-0.625:12196:12197 ~0.01489590210811563 ~-0.04405837719078027 ~0.02078483953070136 184:0.0625:12200:12203 46:0:12201:12202 ~0.018718611261658667 "
    s .= "~-0.07038022015978194 ~0.025773377826210322 242:2.05:12205:12218 73:1.140625:12206:12217 214:0.65625:12207:12210 70:-0.390625:12208:12209 ~0.01924396017370787 ~-0.004378646457942915 112:-0.078125:12211:12212 ~-0.03648474370275064 "
    s .= "52:0.0625:12213:12214 ~0.030279102399172055 250:0.8671875:12215:12216 ~0.021851898438338124 ~-0.04694393398932721 ~-0.033945313690212385 216:0.1640625:12219:12220 ~-0.04786042206373217 ~0.005949362932223846 249:0.5:12222:12247 "
    s .= "248:0.875:12223:12246 251:0.515625:12224:12235 46:0.015625:12225:12234 91:0.171875:12226:12231 206:-0.75:12227:12228 ~0.026244068435669878 103:0.75:12229:12230 ~-0.03523399511476871 ~0.011452223454568485 61:-0.09375:12232:12233 "
    s .= "~-0.03627625338578704 ~0.03208559976265182 ~-0.017017009166290807 255:0.546875:12236:12245 231:0.3671875:12237:12238 ~0.016543462227552142 252:0.42500000000000004:12239:12244 103:-0.25:12240:12241 ~0.028795978637119392 "
    s .= "46:0.09375:12242:12243 ~-0.04888389223152765 ~0.004892661067347479 ~0.019685371963001692 ~-0.009702169215950504 ~-0.02097882403617272 196:-0.15625:12248:12251 212:-0.578125:12249:12250 ~0.004410410670014106 ~-0.044834372996411076 "
    s .= "245:1.6990291262135921:12252:12253 ~-0.03290262911166828 52:-0.109375:12254:12255 ~0.017719106434736585 145:-0.046875:12256:12257 ~-0.03500147535314554 214:0.15625:12258:12263 253:-0.019131056677987805:12259:12260 "
    s .= "~0.009020924143342953 169:1.515625:12261:12262 ~-0.04106588420791316 ~0.024761537473696558 166:0.15625:12264:12265 ~-0.025341217675603458 52:0.453125:12266:12267 ~0.032359396625458246 ~-0.02310246361221105 "
    s .= "245:4.878048780487805:12269:12314 85:1.46875:12270:12305 16:1.0625:12271:12304 79:1.5625:12272:12301 34:0.90625:12273:12300 205:0.71875:12274:12299 61:0.71875:12275:12294 16:0.421875:12276:12293 202:0.5:12277:12290 "
    s .= "202:0.203125:12278:12285 251:1.484375:12279:12284 241:0.12:12280:12283 154:0.390625:12281:12282 ~-0.009250654118099102 ~0.03282499088343231 ~-0.01711948145034654 ~0.01660148152508865 94:0.46875:12286:12289 "
    s .= "120:0.0859375:12287:12288 ~-0.05277573962089378 ~-0.010822904952479333 ~0.015771416599033895 190:0.453125:12291:12292 ~0.02079477045253432 ~-0.03339160564886993 ~0.015690542976301257 178:0.171875:12295:12296 ~0.033303951402828234 "
    s .= "181:0.21875:12297:12298 ~0.024441621530772242 ~-0.030266263911612426 ~0.014727272908752238 ~-0.035540820817044315 133:1.765625:12302:12303 ~0.03422078428472195 ~-0.028839263097826265 ~-0.0340444244139785 124:-0.109375:12306:12307 "
    s .= "~-0.011342750066349643 248:0.625:12308:12311 88:0.09375:12309:12310 ~-0.005477554617764467 ~0.03373206077708274 236:-0.296875:12312:12313 ~0.01921888298599204 ~-0.038421218249318 ~-0.04847448741495668 50:0.34375:12316:12359 "
    s .= "246:0.640625:12317:12352 111:0.0703125:12318:12343 172:-0.5:12319:12320 ~-0.0303773534308956 160:1.140625:12321:12340 178:1.125:12322:12339 109:1.875:12323:12336 85:0.671875:12324:12333 241:0.14:12325:12326 ~0.005871310324230914 "
    s .= "55:1.265625:12327:12332 164:-0.296875:12328:12331 100:-0.53125:12329:12330 ~0.03140745446626123 ~-0.04437694484603465 ~-0.00748337557880613 ~0.03236132027111085 238:0.5625:12334:12335 ~0.017993957358749167 ~-0.038097563598134855 "
    s .= "184:0.71875:12337:12338 ~-0.04985338048711901 ~0.012199091539056654 ~0.023899868390399866 252:3.975:12341:12342 ~0.01607859305843751 ~-0.046213498572714395 163:0.53125:12344:12349 69:0.1640625:12345:12346 ~0.0069609949718135574 "
    s .= "134:0.015625:12347:12348 ~-0.03715055469487349 ~-0.0008073923872426054 29:-0.28125:12350:12351 ~-0.011067518683564965 ~-0.05930061235834455 168:0.0390625:12353:12354 ~-0.01106941262786234 201:0.1796875:12355:12356 "
    s .= "~0.027227827539384478 252:0.175:12357:12358 ~-0.025495376075109794 ~0.013659798773996368 193:0.171875:12360:12361 ~-0.0045119349766811825 ~-0.042575253544331663 98:-0.140625:12363:12396 246:-0.390625:12364:12383 "
    s .= "87:0.0703125:12365:12380 75:-0.0390625:12366:12379 152:-0.5625:12367:12374 244:1.4:12368:12373 30:-0.2578125:12369:12372 175:0.484375:12370:12371 ~0.024182056316850678 ~-0.02809260852231605 ~-0.03247552523549717 "
    s .= "~0.020583105990013784 254:0.890625:12375:12378 195:-0.2578125:12376:12377 ~-0.03799018898090574 ~0.010917356132612325 ~-0.03537793258692197 ~0.01601050533911665 112:1.53125:12381:12382 ~-0.033797520809006464 ~0.015275154897692073 "
    s .= "121:-0.1875:12384:12385 ~-0.01375385614194297 91:-0.15625:12386:12387 ~-0.01832101855295731 44:-0.078125:12388:12391 196:-0.125:12389:12390 ~-0.011852688208524614 ~0.023351971877696456 140:0.140625:12392:12393 "
    s .= "~0.015080172345217028 192:0.2578125:12394:12395 ~-0.04839332946157739 ~0.012668902345962602 89:0.625:12397:12406 218:0.328125:12398:12403 247:0.515625:12399:12402 254:0.796875:12400:12401 ~0.003360344790148353 "
    s .= "~-0.01597410025477634 ~-0.0345259159123272 112:1.15625:12404:12405 ~-0.04097231061502722 ~0.006273416617668045 232:0.375:12407:12408 ~0.018409353970769586 ~-0.03558253905963411 253:-0.13262032085561656:12410:12417 "
    s .= "7:0.125:12411:12412 ~0.022203311662299465 109:1.203125:12413:12416 133:0.4375:12414:12415 ~0.01495181200682725 ~-0.05630052755740528 ~0.018667633761470466 94:0.015625:12418:12435 73:0.0625:12419:12428 2:-0.671875:12420:12421 "
    s .= "~0.018516115923311035 254:1.046875:12422:12427 238:0.15625:12423:12424 ~0.008708121426572455 106:1.265625:12425:12426 ~-0.031791166591534296 ~0.015153342883375512 ~-0.03380778490162724 193:0:12429:12432 82:1.28125:12430:12431 "
    s .= "~-0.062306609755038544 ~0.0003371958345142699 99:0.1328125:12433:12434 ~-0.029629287025863173 ~0.010161126219831207 251:0.484375:12436:12447 91:0.234375:12437:12438 ~-0.026399606045757276 34:0.0625:12439:12442 "
    s .= "37:-0.203125:12440:12441 ~-0.03492146360596534 ~0.030792068746794535 133:0.859375:12443:12444 ~-0.047113980955084366 100:0.59375:12445:12446 ~0.014619504865493384 ~-0.053138227539262686 20:0.59375:12448:12455 "
    s .= "162:0.3671875:12449:12454 245:1.5866666666666667:12450:12453 113:0.609375:12451:12452 ~-0.05044571981148435 ~0.020205132607898912 ~0.011206755851327122 ~-0.016286960551053463 ~-0.034186594361405025 205:-0.25:12457:12458 "
    s .= "~-0.014710541620807963 70:0.8125:12459:12502 88:1.421875:12460:12497 79:1.53125:12461:12494 100:-0.390625:12462:12463 ~0.022538621725318897 124:0:12464:12467 13:-0.0625:12465:12466 ~0.006149976830041525 ~-0.021668228124189046 "
    s .= "124:0.109375:12468:12473 64:0:12469:12470 ~-0.020311418464503597 52:0.328125:12471:12472 ~0.023392047254242147 ~-0.03359729623750495 55:1.078125:12474:12493 97:-0.234375:12475:12476 ~-0.04531023820765564 196:0.59375:12477:12490 "
    s .= "169:0.09375:12478:12483 244:1.225:12479:12480 ~-0.015119351613181632 160:0.15625:12481:12482 ~-0.026626200656618124 ~0.027334342900940348 112:1.390625:12484:12489 220:0.40625:12485:12486 ~-0.03276384949848334 245:2:12487:12488 "
    s .= "~0.02308477868176732 ~-0.04159646059253699 ~0.021549277575982597 148:0.546875:12491:12492 ~0.03247155054442087 ~-0.026587963070813844 ~0.027652235218438504 133:1.984375:12495:12496 ~0.03043545452749008 ~-0.026692073219669432 "
    s .= "124:-0.109375:12498:12499 ~-0.01763214971977405 148:0.734375:12500:12501 ~0.03281873910385657 ~-0.008272104955121295 ~-0.01930723761033179 248:0.375:12504:12539 202:0.90625:12505:12538 250:0.5546875:12506:12507 "
    s .= "~-0.03665986449773864 244:1.47:12508:12529 31:0.234375:12509:12526 193:0.40625:12510:12525 163:0.640625:12511:12520 184:0:12512:12515 251:1.109375:12513:12514 ~-0.03356780772468548 ~0.024007985938440994 235:0.171875:12516:12517 "
    s .= "~0.02437764288590703 243:1.25:12518:12519 ~0.00646230603618599 ~-0.056401177239143785 133:0.84375:12521:12524 244:1:12522:12523 ~-0.05211333038562615 ~0.027817940748220374 ~-0.03417462195704046 ~-0.036623843210738215 "
    s .= "245:2.7246376811594204:12527:12528 ~-0.037647095822109 ~0.02620148395841609 79:0.3125:12530:12537 132:-0.0703125:12531:12534 255:0.609375:12532:12533 ~0.02373216096367703 ~-0.03239895262139863 208:0.4375:12535:12536 "
    s .= "~-0.004696575566753173 ~-0.0645628723362975 ~0.02475046082135597 ~0.024982207456967914 121:-0.21875:12540:12543 151:-0.4375:12541:12542 ~0.01518226906088406 ~-0.044213789734000336 99:-0.4453125:12544:12545 ~-0.04499800569008976 "
    s .= "214:0.578125:12546:12547 ~-0.004854475070246337 175:0.34375:12548:12549 ~0.031380828958487754 ~-0.013606080700107319 253:-0.04464285714285676:12551:12560 252:0.225:12552:12555 146:0.21875:12553:12554 ~0.0004091298911215613 "
    s .= "~-0.039883630035901424 166:0.1875:12556:12557 ~0.02607920253759552 97:0:12558:12559 ~-0.03728301023498227 ~0.02009644147369538 190:0:12561:12582 181:0.15625:12562:12575 25:0.296875:12563:12572 241:0.52:12564:12569 "
    s .= "220:0.671875:12565:12568 126:-0.4765625:12566:12567 ~0.013624187966812522 ~-0.05813656178440886 ~0.008323745933273232 243:1.25:12570:12571 ~0.022280198225428455 ~-0.034969200021158116 43:0:12573:12574 ~-0.04601225745919371 "
    s .= "~0.028873973242064047 148:0.203125:12576:12579 205:-0.328125:12577:12578 ~-0.04780308629037189 ~0.019430229568903192 169:0.078125:12580:12581 ~0.006939366966382985 ~-0.037489805933914905 202:0.171875:12583:12590 "
    s .= "124:-0.1875:12584:12585 ~-0.022513878018746408 217:0.84375:12586:12589 241:2.54:12587:12588 ~0.013645467752204024 ~-0.034058162268331485 ~-0.035636340962357474 241:1.26:12591:12594 73:0.625:12592:12593 ~-0.0011493607907172288 "
    s .= "~-0.04446064138487527 48:0.3203125:12595:12596 ~-0.060602863902162775 ~0.01422129797381342 251:0.765625:12598:12631 181:0.640625:12599:12624 205:0.28125:12600:12619 251:0.171875:12601:12602 ~-0.040106720153475175 "
    s .= "238:-0.125:12603:12604 ~-0.031711432933759914 109:1.546875:12605:12618 85:0.71875:12606:12617 58:-0.140625:12607:12608 ~0.027351701312628974 103:0.046875:12609:12610 ~0.01681578384262639 112:1:12611:12614 109:1.125:12612:12613 "
    s .= "~-0.04518288632960493 ~0.020545252727280205 76:0.171875:12615:12616 ~-0.03564785375502579 ~0.03765772728984353 ~0.027291891946580122 ~-0.02770648144690699 67:-0.25:12620:12621 ~-0.04768861891921677 234:0.3828125:12622:12623 "
    s .= "~0.02279297725541418 ~-0.03571437675447147 130:1.359375:12625:12628 169:0.171875:12626:12627 ~-0.01797664132479461 ~-0.055918761106952146 79:1.765625:12629:12630 ~0.014923874266691749 ~-0.05189306369322624 "
    s .= "146:-0.046875:12632:12635 181:0.625:12633:12634 ~0.002332338057476509 ~0.021312452119542667 89:0.640625:12636:12643 19:-0.234375:12637:12638 ~-0.04452415716253298 241:0.46:12639:12642 245:1.9519230769230769:12640:12641 "
    s .= "~0.0022396476116440423 ~-0.04542635950921931 ~0.005390182016016012 ~0.01958472134914195 249:0.16666666666666666:12645:12670 251:0.734375:12646:12659 178:-0.078125:12647:12650 226:-0.125:12648:12649 ~0.000025422784774852648 "
    s .= "~-0.060263971916170715 166:0.5:12651:12656 250:0.9609375:12652:12653 ~0.01602037570056657 1:-0.015625:12654:12655 ~0.012141081995915667 ~-0.02728060972498586 172:0.109375:12657:12658 ~0.015956393054526275 ~-0.047348182104769675 "
    s .= "245:3.5483870967741935:12660:12669 106:0.78125:12661:12668 127:0.921875:12662:12667 115:0.5:12663:12666 232:0.203125:12664:12665 ~0.006595556411060526 ~-0.039059314063690696 ~0.030782884104451198 ~-0.040338596392342836 "
    s .= "~0.026059080967448463 ~-0.035390043708342415 38:-0.96875:12671:12672 ~0.01527832344204845 120:0.0703125:12673:12684 196:0.5625:12674:12681 139:0.1875:12675:12680 226:0.265625:12676:12679 79:1.53125:12677:12678 "
    s .= "~-0.04072495720913101 ~0.014418882493210945 ~0.0035048337154586114 ~-0.007419503341454198 139:0.625:12682:12683 ~0.02640515955372006 ~-0.024036750210667465 71:0.171875:12685:12686 ~0.006364696137975146 165:0.2109375:12687:12688 "
    s .= "~-0.030397064324253632 15:0.2734375:12689:12690 ~0.020395159865646273 ~-0.026585718760753607 253:-0.13262032085561656:12692:12699 7:0.125:12693:12694 ~0.021672629899801815 109:1.203125:12695:12698 133:0.4375:12696:12697 "
    s .= "~0.014181918568240455 ~-0.053523418821426874 ~0.018472503265923583 239:-0.109375:12700:12729 160:0.984375:12701:12718 134:-0.40625:12702:12711 85:-0.1875:12703:12704 ~0.017429691315110893 61:1.3125:12705:12710 "
    s .= "53:-1.28125:12706:12707 ~0.02004032825642131 163:1.34375:12708:12709 ~-0.03454816847846037 ~0.021855242212327472 ~0.016875219573027688 244:1.83:12712:12715 1:0.328125:12713:12714 ~0.010896311885656693 ~-0.01394179395014836 "
    s .= "55:0.265625:12716:12717 ~-0.041509416649817436 ~0.013069274256970749 162:0.3203125:12719:12728 177:-0.0078125:12720:12727 208:0.34375:12721:12726 134:-1.5625:12722:12723 ~0.030558571424526268 154:1.46875:12724:12725 "
    s .= "~-0.003163451489542931 ~-0.060319913524694346 ~0.022610952149545435 ~0.026677232566363625 ~-0.03939361357957136 175:-0.171875:12730:12733 60:0.6015625:12731:12732 ~-0.044840360511660377 ~0.020890823185884783 "
    s .= "254:1.078125:12734:12737 228:-0.0390625:12735:12736 ~0.011070953955806125 ~-0.00655395532992064 ~-0.03819247005507572 253:-0.04464285714285676:12739:12760 109:0.890625:12740:12747 49:0.171875:12741:12744 205:0.15625:12742:12743 "
    s .= "~0.015858743715273852 ~-0.0173061589351392 250:1.2578125:12745:12746 ~-0.05320227528087469 ~0.03155326738468455 252:0.42500000000000004:12748:12757 140:0.046875:12749:12754 251:0.890625:12750:12753 65:-0.15625:12751:12752 "
    s .= "~-0.019757419838212664 ~0.0312152377191278 ~0.0337112603260726 199:0.09375:12755:12756 ~-0.04295933145425628 ~0.011256669403506558 76:-0.234375:12758:12759 ~-0.015468234167208173 ~0.039871823577767404 190:0:12761:12770 "
    s .= "9:0.6640625:12762:12769 181:0.15625:12763:12764 ~-0.02607781779693545 121:0.265625:12765:12768 214:-0.3125:12766:12767 ~-0.037757611182870215 ~0.012623465307196569 ~-0.03491451524148313 ~0.02884300662862709 "
    s .= "115:-0.34375:12771:12772 ~-0.04686323084546558 55:0.109375:12773:12774 ~0.008361556309241248 148:1.046875:12775:12784 136:1.09375:12776:12783 229:0.1875:12777:12782 109:0.703125:12778:12781 25:0.03125:12779:12780 "
    s .= "~0.0016107508953136136 ~-0.048267016699764756 ~0.00966709586214389 ~-0.04358223184439143 ~0.0034965347564648547 ~0.022335224782845876 130:2.46875:12786:12829 248:0.375:12787:12818 130:1.25:12788:12815 "
    s .= "245:2.491228070175439:12789:12808 214:0.5:12790:12805 79:1.171875:12791:12804 242:1.35:12792:12801 76:-0.046875:12793:12794 ~0.0137771720722408 25:-0.0625:12795:12796 ~-0.03653244954792497 91:0.3125:12797:12800 "
    s .= "181:0.5:12798:12799 ~-0.02266536275857392 ~0.015045668642794366 ~0.018988550436109797 222:0.1640625:12802:12803 ~-0.052101372947184324 ~-0.00410101106553532 ~0.033354145423922815 167:-0.203125:12806:12807 ~-0.06053904091752478 "
    s .= "~-0.005467605492625167 241:0.32:12809:12814 145:-0.015625:12810:12811 ~-0.032758495973025464 118:0.375:12812:12813 ~0.023645438962562375 ~-0.039115532286445175 ~0.02814975775458521 250:0.5859375:12816:12817 ~-0.04804365457901655 "
    s .= "~0.01879889461949609 121:-0.21875:12819:12822 151:-0.4375:12820:12821 ~0.014862201894445577 ~-0.04303628308006512 99:-0.4453125:12823:12824 ~-0.04382375705838312 214:0.578125:12825:12826 ~-0.004590704256466977 "
    s .= "175:0.34375:12827:12828 ~0.03069771242443094 ~-0.012457147786339533 22:0.234375:12830:12831 ~-0.04672861270422564 ~0.01929310812840265 98:-0.140625:12833:12854 246:-0.390625:12834:12845 87:0.0703125:12835:12842 "
    s .= "254:1.015625:12836:12837 ~0.009435913870329294 191:-1.078125:12838:12839 ~0.01504644079536455 31:0.015625:12840:12841 ~-0.001953780816533504 ~-0.040843755265922176 112:1.53125:12843:12844 ~-0.032245934258150005 "
    s .= "~0.014238256253594931 62:-0.5:12846:12847 ~0.02376223059665125 255:0.234375:12848:12849 ~0.015424506631867875 132:-0.0546875:12850:12851 ~0.012124586477063137 143:-0.328125:12852:12853 ~0.0076167934100771955 "
    s .= "~-0.027778535902546836 226:-0.15625:12855:12856 ~-0.024331068413628518 202:0.203125:12857:12870 184:0.375:12858:12867 190:0.515625:12859:12866 243:0.6499999999999999:12860:12863 43:0.46875:12861:12862 ~-0.03883354896545801 "
    s .= "~0.017985277075422117 112:0.5:12864:12865 ~-0.010923991061234066 ~0.023105591760029992 ~0.026897570324833177 31:0.6875:12868:12869 ~0.022770522941334036 ~-0.03628462504159246 109:1.265625:12871:12876 144:0.0703125:12872:12873 "
    s .= "~-0.042519451035311205 210:0.1796875:12874:12875 ~0.007874582141274093 ~-0.028394126525275606 253:-0.02550884990132192:12877:12878 ~0.030795664705549494 ~-0.017629140207654558 251:0.765625:12880:12913 181:0.640625:12881:12908 "
    s .= "205:0.28125:12882:12903 251:0.203125:12883:12884 ~-0.03384122462939489 238:-0.125:12885:12886 ~-0.03010728872189076 136:-0.015625:12887:12888 ~0.03155297241353889 64:0.53125:12889:12902 220:0.328125:12890:12901 "
    s .= "49:0.125:12891:12900 166:0.140625:12892:12897 241:0.28:12893:12896 22:0.578125:12894:12895 ~-0.055735960678930246 ~0.025523399967249134 ~0.006984561417596433 145:0:12898:12899 ~-0.026487949461728083 ~0.030400171443629748 "
    s .= "~-0.03738424071464363 ~0.028176534371347248 ~0.023614417460290187 67:-0.25:12904:12905 ~-0.047084677192124814 37:0.09375:12906:12907 ~0.029467664507567062 ~-0.0029945214418168878 130:1.359375:12909:12910 ~-0.02904443811508278 "
    s .= "79:1.765625:12911:12912 ~0.014127703461697295 ~-0.04860830839052818 194:0.21875:12914:12925 243:0.35:12915:12920 1:-0.34375:12916:12917 ~0.02982063215843979 118:0.109375:12918:12919 ~-0.0017818571827951772 ~-0.05487654673858575 "
    s .= "28:0.8125:12921:12924 149:-0.671875:12922:12923 ~0.02737435931705224 ~0.006253524210173972 ~-0.0284063604316286 ~-0.012105900365393928 248:0.875:12927:12966 203:0.71875:12928:12965 251:0.765625:12929:12962 "
    s .= "178:-0.078125:12930:12935 229:-0.234375:12931:12932 ~0.010304113981225767 190:0.265625:12933:12934 ~-0.06156040152085382 ~0.005201011578632769 217:-0.125:12936:12939 74:-1.015625:12937:12938 ~0.02796873381141279 "
    s .= "~-0.030477179358443404 181:0.21875:12940:12947 79:0.25:12941:12946 229:0.015625:12942:12943 ~-0.028985349995397355 1:0.234375:12944:12945 ~0.018173236315574142 ~-0.032441978681335776 ~0.027419108751999363 "
    s .= "234:0.3828125:12948:12961 55:0.203125:12949:12958 46:0.078125:12950:12957 130:0.4375:12951:12954 188:-0.8125:12952:12953 ~0.03444429462149156 ~-0.04196470014638196 7:-0.359375:12955:12956 ~-0.03892443442428245 "
    s .= "~0.032496408610243284 ~-0.019837453857794705 239:-1.09375:12959:12960 ~0.02614499254150525 ~-0.0319489690773045 ~-0.04146847657925112 244:2.38:12963:12964 ~0.007390863844396295 ~-0.023234394835864924 ~-0.04182611776798018 "
    s .= "214:0.453125:12967:12970 224:-0.171875:12968:12969 ~-0.0014568737459458004 ~-0.0431943039849905 246:-0.765625:12971:12972 ~-0.03511653865806207 ~0.025155411338386093 255:0.296875:12974:12993 133:1.984375:12975:12992 "
    s .= "100:1.140625:12976:12991 95:0.53125:12977:12990 50:0.328125:12978:12987 113:0.515625:12979:12986 245:2.942857142857143:12980:12985 181:1.53125:12981:12984 251:0.171875:12982:12983 ~-0.024193217766824024 ~0.0039733874561283505 "
    s .= "~-0.04205870661433571 ~0.018239285180792725 ~0.023674758750776743 196:0.171875:12988:12989 ~0.00004678024292330548 ~-0.05217818969829146 ~-0.02180394824632226 ~0.024150257114106007 ~-0.01954286081209687 194:-0.09375:12994:13017 "
    s .= "190:-0.015625:12995:13002 139:0.40625:12996:13001 82:1.109375:12997:13000 25:0.15625:12998:12999 ~-0.030080247652603448 ~0.011185714988114378 ~0.022149216843307895 ~-0.033112436823395985 145:-0.125:13003:13006 "
    s .= "226:0.875:13004:13005 ~-0.021722228258395027 ~0.031230864775677793 28:0.8125:13007:13016 85:1.09375:13008:13015 15:-0.1796875:13009:13010 ~0.019122936393758776 202:-0.140625:13011:13012 ~0.02771026917362514 "
    s .= "118:0.03125:13013:13014 ~-0.0357755178169292 ~-0.0004946011059777551 ~0.02702525419878988 ~-0.03496862703223986 30:0.3515625:13018:13019 ~-0.026996394127165486 ~0.008840337689692172 253:-0.04464285714285676:13021:13040 "
    s .= "109:0.890625:13022:13029 49:0.171875:13023:13026 205:0.15625:13024:13025 ~0.01553921073212107 ~-0.016524316901637106 250:1.2578125:13027:13028 ~-0.051207241568609424 ~0.030930149612720753 252:0.625:13030:13039 "
    s .= "199:0.109375:13031:13038 245:2.6122448979591835:13032:13035 140:0.0625:13033:13034 ~0.027707355817580354 ~-0.02638278128754777 202:0.578125:13036:13037 ~-0.0552471525319171 ~0.0290619900357081 ~0.021820858494407666 "
    s .= "~0.03340973185954044 142:-0.28125:13041:13046 139:-0.25:13042:13045 192:0.1015625:13043:13044 ~-0.037286514889394315 ~0.03214331935418479 ~-0.04346924654608739 239:-0.109375:13047:13052 70:0.609375:13048:13049 "
    s .= "~0.00525195132815916 148:0.125:13050:13051 ~0.010841203275095435 ~-0.04616189990699053 246:0.328125:13053:13060 244:2.2:13054:13059 148:0:13055:13056 ~-0.05104108987348086 73:0.0625:13057:13058 ~0.00013380586281716388 "
    s .= "~-0.0388440470390326 ~0.012165166008850955 190:0.359375:13061:13066 248:0.875:13062:13065 218:0.25:13063:13064 ~0.008280034708436428 ~-0.026453048336059156 ~-0.047972925681254046 ~0.02007802103982299 243:2.25:13068:13113 "
    s .= "153:0.7578125:13069:13112 253:-0.08990051156513783:13070:13079 252:0.125:13071:13076 71:0.15625:13072:13075 36:-0.0546875:13073:13074 ~-0.02392771690643191 ~0.020888919425578082 ~-0.04196392585737446 166:0.671875:13077:13078 "
    s .= "~0.025216675302674765 ~-0.024954274012979023 187:-0.3125:13080:13083 68:0.21875:13081:13082 ~-0.04377161492293789 ~0.015798080487667218 217:0.21875:13084:13103 251:1.578125:13085:13098 87:0.0234375:13086:13087 "
    s .= "~0.006385400351864121 255:0.046875:13088:13089 ~0.014508241243744677 76:0.0625:13090:13095 120:0.0546875:13091:13092 ~-0.03262046511969142 132:0.1953125:13093:13094 ~0.017875971577015853 ~-0.0232898734049488 "
    s .= "73:0.40625:13096:13097 ~-0.03679088030891298 ~0.004768142841809084 252:0.025:13099:13102 172:0.390625:13100:13101 ~-0.03651254981657069 ~0.034444953359961276 ~0.028182227081459385 238:0.28125:13104:13111 244:1.125:13105:13106 "
    s .= "~0.005545388659455499 199:0.0625:13107:13108 ~-0.004288037728693664 10:0.65625:13109:13110 ~-0.05645619449415223 ~0.022664050545083518 ~0.007347717459191146 ~-0.03478469317855734 ~-0.025933030780301344 "
    s .= "249:0.16666666666666666:13115:13132 251:0.734375:13116:13125 90:0.1171875:13117:13122 64:-0.25:13118:13119 ~-0.0387893229738008 22:0:13120:13121 ~0.02041072884200963 ~-0.005149313833700387 217:0.671875:13123:13124 "
    s .= "~-0.03064665429854513 ~0.028094280586270816 245:3.5483870967741935:13126:13131 46:-0.140625:13127:13130 70:-0.328125:13128:13129 ~0.020866024164368297 ~-0.026458658807306874 ~0.020260263851433022 ~-0.033024953793568505 "
    s .= "35:-0.9375:13133:13134 ~0.014780384382904015 184:-0.21875:13135:13136 ~-0.032899108046066196 219:0.2578125:13137:13150 178:0.125:13138:13141 190:0.359375:13139:13140 ~-0.004885202917677948 ~0.026081973911832153 "
    s .= "243:0.55:13142:13147 226:0.265625:13143:13146 169:0.1875:13144:13145 ~-0.00328972426903061 ~-0.05123678336883425 ~0.01544002745297486 181:0.171875:13148:13149 ~-0.0016299372869024006 ~-0.037756217224217736 "
    s .= "245:1.8541666666666667:13151:13154 25:0.078125:13152:13153 ~-0.032295111381630014 ~0.01082139471478464 19:0.65625:13155:13160 178:-0.0625:13156:13157 ~-0.01965850286013432 1:0.59375:13158:13159 ~0.022689517411417483 "
    s .= "~-0.03824837855485486 ~-0.03162183914500373 255:0.234375:13162:13189 254:0.453125:13163:13182 17:-0.421875:13164:13167 25:0.046875:13165:13166 ~0.026332510383727883 ~-0.0066281030466895825 246:-0.859375:13168:13171 "
    s .= "244:1.965:13169:13170 ~-0.05280363999139268 ~0.0074811369908736785 254:0.234375:13172:13179 244:0.99:13173:13176 250:1.6328125:13174:13175 ~-0.03156541936388735 ~0.023595698407714555 146:0.34375:13177:13178 ~0.014799211666675369 "
    s .= "~-0.01085554031434965 208:0.21875:13180:13181 ~-0.003766872085537366 ~-0.04205182732944432 218:0.09375:13183:13186 246:-0.328125:13184:13185 ~-0.010310267084526486 ~0.030702371727594165 245:1.765625:13187:13188 "
    s .= "~0.027960948255711323 ~-0.02547369049604556 122:-0.296875:13190:13195 247:0.234375:13191:13192 ~0.004400752963674757 106:0.15625:13193:13194 ~0.009138640541206678 ~-0.03226658811546881 89:0.25:13196:13205 82:0.78125:13197:13202 "
    s .= "225:0.6171875:13198:13201 205:0.28125:13199:13200 ~-0.04368322602984471 ~-0.013362598279104047 ~0.01869528964550905 165:-0.1796875:13203:13204 ~0.0248241147045756 ~-0.014444369455761883 206:0.375:13206:13207 ~0.01205331510251887 "
    s .= "~-0.03617545606658735 253:-0.04464285714285676:13209:13224 109:0.890625:13210:13217 49:0.171875:13211:13214 193:0.09375:13212:13213 ~0.013766776727803635 ~-0.018172782434308653 250:1.2578125:13215:13216 ~-0.04962495480643409 "
    s .= "~0.030444462689770233 241:0.26:13218:13219 ~-0.012853185848374383 55:-0.21875:13220:13223 94:-0.03125:13221:13222 ~0.0177674270962675 ~-0.04450048792246455 ~0.026245895356858246 142:-0.28125:13225:13230 139:-0.25:13226:13229 "
    s .= "192:0.1015625:13227:13228 ~-0.036331394529282024 ~0.03148676509458025 ~-0.04203863398948233 239:-0.109375:13231:13236 70:0.609375:13232:13233 ~0.004890906928173411 148:0.125:13234:13235 ~0.010290555674211794 ~-0.04486055658750847 "
    s .= "246:0.328125:13237:13246 244:2.2:13238:13245 148:0:13239:13240 ~-0.04961920229499307 124:0.15625:13241:13244 91:0.171875:13242:13243 ~-0.025221622452049258 ~0.025341032981531026 ~-0.03676705243897315 ~0.011437998424903218 "
    s .= "190:0.359375:13247:13254 248:0.875:13248:13253 218:0.25:13249:13250 ~0.007734914300660676 184:1.046875:13251:13252 ~-0.039859533068579145 ~0.02017906127037795 ~-0.047068574312746914 ~0.01906778120308289 222:-0.3984375:13256:13261 "
    s .= "179:-0.859375:13257:13260 34:0.296875:13258:13259 ~0.016720118547039618 ~-0.04729509674589272 ~-0.03834401806164543 87:-0.1796875:13262:13267 130:0.953125:13263:13266 110:-0.390625:13264:13265 ~-0.015181210544295127 "
    s .= "~0.01735884803559554 ~0.01965480048023575 255:0.234375:13268:13275 254:0.453125:13269:13270 ~-0.000967299374853816 218:0.09375:13271:13272 ~0.02474748877589316 245:1.765625:13273:13274 ~0.02925681203790268 ~-0.024314589039144345 "
    s .= "254:0.515625:13276:13277 ~0.012433152538505082 224:0.015625:13278:13297 252:0.475:13279:13294 206:0.015625:13280:13293 207:-0.1328125:13281:13284 170:-0.53125:13282:13283 ~0.020895398906916777 ~-0.019023583954724893 "
    s .= "63:0.0078125:13285:13288 45:-0.0703125:13286:13287 ~-0.03575805200039139 ~0.010978379632017482 67:1.53125:13289:13292 178:1.0625:13290:13291 ~-0.04498326640785455 ~0.014819042677528607 ~0.027905567812842542 ~0.01891093370943575 "
    s .= "244:0.98:13295:13296 ~-0.030635658436700155 ~0.014711049329259214 141:0.1171875:13298:13299 ~-0.04076613284929028 24:0.0859375:13300:13301 ~0.02342442806184572 ~-0.02860394496017897 149:-1.59375:13303:13304 ~0.029471728540257137 "
    s .= "147:-0.3828125:13305:13308 129:-0.4453125:13306:13307 ~-0.002276024979116764 ~-0.03988731462374639 95:0.515625:13309:13348 113:0.5:13310:13345 245:1.5866666666666667:13311:13312 ~-0.03805239565787988 127:1.984375:13313:13340 "
    s .= "111:0.0703125:13314:13327 117:0.1640625:13315:13324 40:0.015625:13316:13319 25:0:13317:13318 ~0.0038234459919301925 ~-0.019227668589745506 73:0.578125:13320:13323 154:0.4375:13321:13322 ~-0.0006659874072862467 "
    s .= "~0.020245857237106736 ~-0.02937043542063125 139:0.640625:13325:13326 ~0.028894842726865516 ~-0.015086202451958873 163:0.671875:13328:13339 190:0.359375:13329:13338 130:0.125:13330:13333 181:-0.0625:13331:13332 "
    s .= "~-0.03722128575405287 ~0.030030273446447937 154:1:13334:13337 40:-0.140625:13335:13336 ~0.0065184703302408765 ~-0.03200074507212871 ~0.010957640561383555 ~0.020400533823241015 ~-0.03456154449848464 245:2.5:13341:13342 "
    s .= "~0.01926260654372213 1:0.203125:13343:13344 ~-0.06615917832010014 ~0.005986933742972306 176:0.65625:13346:13347 ~0.020122363464475 ~-0.02816789340394418 ~-0.01766797327302108 253:-0.04464285714285676:13350:13373 "
    s .= "252:0.175:13351:13366 195:0.3671875:13352:13363 124:-0.140625:13353:13356 76:-0.265625:13354:13355 ~-0.031722792973031017 ~0.024462147836434862 178:0.25:13357:13360 172:-0.109375:13358:13359 ~0.01832947281226267 "
    s .= "~-0.05006846731158531 58:0.21875:13361:13362 ~0.02054552670061013 ~-0.030315442597206255 245:1.9838709677419355:13364:13365 ~-0.027897614043042793 ~0.039753488268062055 19:-0.203125:13367:13368 ~-0.011492631022753537 "
    s .= "235:0.359375:13369:13370 ~0.025346995335183545 244:1.175:13371:13372 ~-0.045607952906345256 ~0.02350604526917562 243:1.55:13374:13391 245:1.9519230769230769:13375:13380 231:0.2734375:13376:13379 220:-0.09375:13377:13378 "
    s .= "~-0.031988160628201 ~0.01783257342056594 ~-0.016791417925592772 34:-0.15625:13381:13382 ~0.010977409460358512 241:0.14:13383:13386 139:0.625:13384:13385 ~0.012134396238151017 ~-0.029065507929608898 85:1.46875:13387:13390 "
    s .= "244:1.655:13388:13389 ~-0.03458511773063847 ~-0.0009737572690223235 ~0.006305611680437483 134:0.03125:13392:13393 ~-0.048473779080813545 245:1.736842105263158:13394:13395 ~-0.04385661286273345 ~0.013834303097978659 "
    s .= "249:0.5:13397:13432 248:0.875:13398:13431 115:1.15625:13399:13430 139:0.6875:13400:13421 251:0.171875:13401:13402 ~-0.04711326993094321 103:1.015625:13403:13420 244:1.115:13404:13409 142:0.0625:13405:13406 ~0.029452460769569068 "
    s .= "244:1.005:13407:13408 ~-0.01849563708923452 ~0.019916772732860896 61:0.46875:13410:13419 208:0.25:13411:13416 34:0.09375:13412:13413 ~0.010617671018801518 219:0.3203125:13414:13415 ~-0.04519670643659906 ~0.0070098915064520165 "
    s .= "19:-0.375:13417:13418 ~0.025089297913603526 ~-0.05443328452021499 ~0.01680143754107259 ~0.02440507682867736 51:-0.0078125:13422:13427 183:-0.1015625:13423:13426 83:-0.359375:13424:13425 ~-0.03321193702052077 ~0.02258233739316234 "
    s .= "~-0.05274689730244691 90:0.1328125:13428:13429 ~0.015525087198009414 ~-0.022924172400802925 ~0.01872405368694741 ~-0.019563281316960727 196:-0.15625:13433:13436 185:-0.734375:13434:13435 ~0.008881294788771688 "
    s .= "~-0.04067584326240917 245:1.6990291262135921:13437:13438 ~-0.03141391878093221 222:0.4296875:13439:13442 127:0.34375:13440:13441 ~0.003916266089686288 ~-0.018440476717630022 ~0.018393520938070784 205:-0.25:13444:13445 "
    s .= "~-0.01398549115013653 250:1.1328125:13446:13487 148:-0.265625:13447:13448 ~0.018850543418435436 145:-0.1875:13449:13454 250:0.8359375:13450:13453 37:-0.234375:13451:13452 ~0.03770683296871495 ~-0.02590701571894253 "
    s .= "~-0.040618311502854575 217:0.21875:13455:13474 251:1.671875:13456:13473 247:0.140625:13457:13466 109:0.515625:13458:13463 16:-0.125:13459:13460 ~0.020871199834999382 250:0.8203125:13461:13462 ~0.0007332236870653836 "
    s .= "~-0.044684023249103574 109:1.90625:13464:13465 ~0.014177259463688086 ~-0.020176999973592263 133:0.328125:13467:13468 ~0.013865729697108996 252:2.125:13469:13472 196:-0.015625:13470:13471 ~-0.05374132480708052 "
    s .= "~-0.013798508565148103 ~0.022818994871171203 ~0.020051278470131433 151:0.5625:13475:13482 112:0.40625:13476:13479 102:0.3203125:13477:13478 ~-0.0514732763283966 ~0.02073214278856428 109:0.40625:13480:13481 ~0.03387374266843817 "
    s .= "~-0.0026851536884170252 211:0.0625:13483:13484 ~0.0015905027133371807 184:1.015625:13485:13486 ~-0.06169118098896397 ~0.006618536110089031 252:0.32499999999999996:13488:13489 ~-0.0008532505762300018 ~0.021508521869115484 "
    s .= "253:-0.13262032085561656:13491:13496 7:0.125:13492:13493 ~0.02088012244757094 199:0.015625:13494:13495 ~-0.039016455152158215 ~0.010743483400808176 94:0.015625:13497:13506 73:0.0625:13498:13499 ~0.00014091936384002642 "
    s .= "193:0:13500:13501 ~-0.04811276710949475 99:0.1328125:13502:13505 160:1.0625:13503:13504 ~-0.04029710609911428 ~0.0009320905679168844 ~0.010849582618550232 251:0.484375:13507:13518 91:0.234375:13508:13509 ~-0.025290688748311065 "
    s .= "34:0.0625:13510:13513 37:-0.203125:13511:13512 ~-0.03235194935142847 ~0.027588507873133057 196:0.1875:13514:13515 ~-0.04134703218098738 199:0.1875:13516:13517 ~0.032519180768536216 ~-0.02484422478892414 20:0.59375:13519:13536 "
    s .= "184:0.8125:13520:13535 217:0.21875:13521:13526 109:1.359375:13522:13525 243:1.55:13523:13524 ~0.019623627956645635 ~-0.016262624259270952 ~-0.010436540460062762 199:0.9375:13527:13534 37:0.546875:13528:13533 "
    s .= "7:-0.265625:13529:13530 ~0.011851036304653013 25:0.140625:13531:13532 ~-0.05916944956752987 ~-0.012750465957924853 ~0.022155564750469467 ~0.029676955817362058 ~0.020520759447952557 ~-0.03163602592697398 248:0.375:13538:13567 "
    s .= "244:1.47:13539:13556 31:0.234375:13540:13553 163:0.640625:13541:13552 184:0:13542:13547 251:0.921875:13543:13546 88:0.890625:13544:13545 ~-0.04906939018583659 ~0.010517601914661348 ~0.011785494097781226 49:0.359375:13548:13551 "
    s .= "235:0.171875:13549:13550 ~0.022382606161085308 ~0.0008822545413213313 ~-0.04637793717433852 ~-0.01546536369530381 56:-0.125:13554:13555 ~-0.011501758650122986 ~-0.04815533719919475 250:0.6328125:13557:13562 "
    s .= "127:1.515625:13558:13561 245:2.9571428571428573:13559:13560 ~-0.040952148181857745 ~0.012835456972064792 ~-0.06842900998783023 76:0.265625:13563:13566 109:0.75:13564:13565 ~-0.01896952293440115 ~0.014283770286870874 "
    s .= "~0.030429634788723584 121:-0.21875:13568:13571 21:0.3515625:13569:13570 ~-0.04368875327917346 ~0.00942869480653457 99:-0.4453125:13572:13573 ~-0.04219540651606733 91:0.171875:13574:13577 109:0.3125:13575:13576 "
    s .= "~-0.03664038043876638 ~-0.0010967420737831573 127:0.734375:13578:13583 245:3.0338983050847457:13579:13582 242:0.95:13580:13581 ~0.02300824425771119 ~-0.014290994282257226 ~-0.04035672523887642 ~-0.017064932557080817 "
    s .= "96:0.8828125:13585:13630 120:0.0703125:13586:13613 247:0.359375:13587:13612 242:2.05:13588:13611 248:0.375:13589:13606 252:3.325:13590:13605 202:0.8125:13591:13604 85:0.671875:13592:13599 232:0.0625:13593:13594 "
    s .= "~0.009721392785448361 25:-0.21875:13595:13596 ~0.01798623781270511 230:-1.0625:13597:13598 ~0.018796922611505718 ~-0.036384932911061346 139:1.6875:13600:13603 145:-0.109375:13601:13602 ~-0.010849774536400313 ~0.02534368722674726 "
    s .= "~-0.030841052514249696 ~0.03103252562504502 ~-0.05225514552218244 58:0.453125:13607:13610 95:-0.046875:13608:13609 ~-0.007361991284071025 ~-0.03653895526747865 ~0.009137724351646004 ~-0.03442596008123768 ~-0.03874693081006411 "
    s .= "118:0.296875:13614:13627 194:0.09375:13615:13624 204:0.1484375:13616:13619 251:0.171875:13617:13618 ~-0.034533869125712865 ~0.024166945758833797 244:1.19:13620:13623 151:-0.15625:13621:13622 ~0.02854316479180622 "
    s .= "~-0.02106168403846355 ~0.015264996818804638 57:0.1640625:13625:13626 ~-0.02591337746076875 ~0.007957603687775603 7:-0.265625:13628:13629 ~0.016935331073056874 ~-0.01818629963750262 ~-0.03811373079888285 "
    s .= "253:-0.04464285714285676:13632:13653 252:1.775:13633:13652 243:1.35:13634:13647 252:0.42500000000000004:13635:13646 195:0.2890625:13636:13643 237:0.4140625:13637:13642 251:0.421875:13638:13641 133:0.625:13639:13640 "
    s .= "~0.017534153994558564 ~-0.04338840562885714 ~0.007193841433835312 ~-0.04092379702592228 245:1.9:13644:13645 ~-0.01912578817019175 ~0.030571310999546727 ~0.025669655250863663 154:-0.234375:13648:13649 ~0.02724430079907198 "
    s .= "109:1:13650:13651 ~-0.05252552626226146 ~0.0024150199916391202 ~0.03416043950597538 190:0:13654:13667 9:0.6640625:13655:13666 181:0.15625:13656:13661 76:0.640625:13657:13660 253:0.0414835164835182:13658:13659 "
    s .= "~-0.03903325251721986 ~0.0058660746174259495 ~0.009048513755647683 121:0.265625:13662:13665 214:-0.3125:13663:13664 ~-0.03476637381870961 ~0.012207067383384191 ~-0.03222388485665601 ~0.027792192768538962 202:0.171875:13668:13671 "
    s .= "124:-0.1875:13669:13670 ~-0.021127329947297616 ~0.009199364961309056 136:0.1875:13672:13675 61:0.5:13673:13674 ~-0.05451172015989904 ~0.02238533042954787 82:-0.234375:13676:13677 ~0.02627675872933301 ~-0.007074563865541533 "
    s .= "255:0.296875:13679:13694 26:-0.640625:13680:13683 241:0.18:13681:13682 ~-0.008086968692369132 ~0.02745288139557929 246:-1.296875:13684:13685 ~-0.030003322032822584 133:2.046875:13686:13691 256:0.9583333333333334:13687:13690 "
    s .= "100:1.140625:13688:13689 ~0.0031307057611863194 ~0.02566538859007704 ~-0.03939833960457764 255:0.015625:13692:13693 ~0.017061845022129186 ~-0.04127566341197781 146:-0.234375:13695:13716 128:-0.234375:13696:13711 "
    s .= "125:-0.65625:13697:13704 109:1.265625:13698:13701 103:0.421875:13699:13700 ~0.008386124698604303 ~-0.032145371988038664 193:-0.03125:13702:13703 ~-0.007502792481837595 ~0.03092545400841243 123:-0.2734375:13705:13706 "
    s .= "~-0.03882430506804178 63:0.0078125:13707:13708 ~0.0025224822350590845 152:-0.203125:13709:13710 ~-0.03596039973462862 ~0.022273537753147665 129:0.1015625:13712:13713 ~0.02453596849825242 119:-0.4375:13714:13715 "
    s .= "~0.025823134159813785 ~-0.03712051709977866 254:0.796875:13717:13718 ~0.0018176678805714428 241:0.48:13719:13720 ~-0.03884364425218315 50:-0.03125:13721:13722 ~0.003255924986496313 247:-0.109375:13723:13724 ~0.011373248616360455 "
    s .= "~-0.0445945684456864 251:0.921875:13726:13747 199:-0.15625:13727:13730 243:1.05:13728:13729 ~-0.008326646505732211 ~-0.047543082231049284 153:0.5703125:13731:13746 217:-0.1875:13732:13735 65:-0.828125:13733:13734 "
    s .= "~0.013725000587222877 ~-0.042220885888784726 121:-0.390625:13736:13737 ~-0.03802935917655137 100:-0.328125:13738:13739 ~0.028391925180113565 205:1.140625:13740:13745 246:-0.359375:13741:13744 7:0:13742:13743 ~0.004208009909484036 "
    s .= "~-0.022731242309873882 ~0.0038354984432733587 ~0.026835300133318307 ~-0.040573581157664726 191:-0.71875:13748:13751 13:0.34375:13749:13750 ~0.02688949098702972 ~-0.018473798861889375 235:0.109375:13752:13765 "
    s .= "245:3.5483870967741935:13753:13764 203:0.625:13754:13763 241:0.48:13755:13762 250:0.9921875:13756:13759 139:0.109375:13757:13758 ~-0.020303870413360035 ~0.028123372274942132 214:0.09375:13760:13761 ~-0.04052227665768668 "
    s .= "~0.017624929552756543 ~0.021392013713265032 ~-0.03888844047353396 ~-0.0398665006262325 112:0.390625:13766:13769 82:0.828125:13767:13768 ~-0.0355580180832849 ~0.007417878125894544 152:-0.265625:13770:13771 ~0.019870830134247872 "
    s .= "~-0.009508258735637081 149:-1.59375:13773:13774 ~0.02861805407065455 222:-0.3984375:13775:13776 ~-0.021033736133710085 124:0:13777:13784 73:0.140625:13778:13783 14:-0.453125:13779:13780 ~0.009100343466240028 "
    s .= "67:0.578125:13781:13782 ~-0.004450590780852747 ~-0.037017518195693856 ~-0.028813317220891838 124:0.109375:13785:13790 64:0:13786:13789 169:0:13787:13788 ~0.017393981229606954 ~-0.030268668403427713 ~0.020643628996995844 "
    s .= "184:1.046875:13791:13814 85:1.53125:13792:13813 241:0.14:13793:13796 139:0.796875:13794:13795 ~0.017153923661815576 ~-0.029135985267730646 49:-0.140625:13797:13798 ~-0.03343951435575911 112:0.421875:13799:13806 "
    s .= "100:0.859375:13800:13805 106:-0.03125:13801:13802 ~0.02248320695584587 245:1.7704918032786885:13803:13804 ~-0.0065675125313812855 ~-0.05378218934190581 ~0.024236429235409633 109:0.40625:13807:13808 ~0.02843272585140243 "
    s .= "251:1.328125:13809:13810 ~-0.015329376908407303 44:-0.03125:13811:13812 ~0.030807258444018305 ~-0.012993706678647255 ~0.015162262627610635 163:-0.046875:13815:13816 ~-0.0368486442603813 252:0.025:13817:13818 "
    s .= "~-0.018753045620883667 ~0.03370637223172722 253:-0.055555555555561874:13820:13837 250:1.2578125:13821:13836 245:1.8064516129032258:13822:13825 218:0.015625:13823:13824 ~-0.04129604624825195 ~0.009089333773133975 "
    s .= "133:1.59375:13826:13833 194:0.140625:13827:13832 118:0.625:13828:13831 4:0.6875:13829:13830 ~0.0253583538793774 ~-0.029032810724097132 ~-0.029883455476569572 ~-0.016231305504143104 223:0.09375:13834:13835 ~-0.051159693633015035 "
    s .= "~0.021184534598766236 ~0.025153726460145815 243:2.25:13838:13865 50:0.421875:13839:13864 246:0.609375:13840:13863 108:0.1796875:13841:13858 250:0.9296875:13842:13855 127:1.6875:13843:13852 40:-0.015625:13844:13849 "
    s .= "40:-0.1875:13845:13846 ~0.011813984672625153 193:-0.015625:13847:13848 ~0.0019558334914128494 ~-0.042393084730615996 136:2.359375:13850:13851 ~0.016322331642894827 ~-0.041856152464811315 38:-0.421875:13853:13854 "
    s .= "~0.012214867304523985 ~-0.059167808624418755 193:-0.109375:13856:13857 ~-0.02938162866493972 ~-0.0016928409537398843 85:1.46875:13859:13862 207:0.0703125:13860:13861 ~-0.008083572731553459 ~-0.044881306712546566 "
    s .= "~0.017632257641690484 ~0.010010496952735187 ~-0.023294710692591876 ~-0.03536015362560337 248:0.375:13867:13900 115:1.15625:13868:13897 214:0.328125:13869:13886 190:0:13870:13877 241:0.54:13871:13876 226:-0.171875:13872:13873 "
    s .= "~0.020504278201411957 37:-0.125:13874:13875 ~0.008720676283696226 ~-0.04045889100182973 ~0.01040542852724474 74:0.03125:13878:13883 109:1.859375:13879:13880 ~0.01677814167924731 238:0.125:13881:13882 ~-0.03824652785734844 "
    s .= "~0.028170057923497322 31:0.15625:13884:13885 ~0.0010367275161923286 ~-0.03918407858858599 85:1.46875:13887:13896 178:1.21875:13888:13895 100:-0.078125:13889:13890 ~0.0024369817212767948 127:0.671875:13891:13892 "
    s .= "~-0.05458881972929857 85:0.953125:13893:13894 ~0.02362693831546088 ~-0.06148539363905034 ~0.023834325023124887 ~0.02401190579051776 214:0:13898:13899 ~-0.0032750652313706893 ~0.028204785328561646 121:-0.21875:13901:13904 "
    s .= "151:-0.4375:13902:13903 ~0.014227379974368515 ~-0.041099701891673855 99:-0.4453125:13905:13906 ~-0.04088833161647902 166:-0.34375:13907:13908 ~-0.036100159090364306 214:0.578125:13909:13910 ~-0.002623864796855226 "
    s .= "142:0.640625:13911:13912 ~0.028890863033830195 ~-0.01826963747675472 254:1.296875:13914:13957 191:-0.421875:13915:13916 ~0.007907942674281977 246:-0.859375:13917:13918 ~-0.027982533396659466 22:-0.265625:13919:13926 "
    s .= "127:0.484375:13920:13923 112:0.5:13921:13922 ~-0.024714975328613286 ~0.018477687344239095 151:-0.015625:13924:13925 ~0.017859436209214808 ~-0.05509110486749794 252:1.025:13927:13950 207:0.3203125:13928:13949 "
    s .= "245:2.142857142857143:13929:13940 242:1.15:13930:13935 154:0.40625:13931:13934 47:0.125:13932:13933 ~0.014325309910440063 ~-0.021302535115020397 ~0.02594745843968868 103:1.203125:13936:13939 130:0.015625:13937:13938 "
    s .= "~0.015390153648099023 ~-0.04834142435866093 ~0.029967298176437514 130:1:13941:13946 139:0.03125:13942:13943 ~-0.023328599453071752 118:0.375:13944:13945 ~0.021263455785998187 ~-0.02740187718352336 215:-0.328125:13947:13948 "
    s .= "~0.01718457826688813 ~-0.03521071033054 ~-0.021852086703664498 244:1.015:13951:13952 ~-0.015447290905732998 222:0.1328125:13953:13956 41:0.109375:13954:13955 ~0.017789205303110244 ~-0.030886803067687575 ~0.03543720069816415 "
    s .= "50:-0.25:13958:13959 ~-0.004724471470690187 ~-0.045117796226167683 255:0.234375:13961:13990 254:0.453125:13962:13985 85:1.15625:13963:13980 112:1.625:13964:13979 89:0.9375:13965:13978 76:1.46875:13966:13977 "
    s .= "250:0.9140625:13967:13968 ~-0.0008747190498780791 130:1.328125:13969:13976 165:0.0859375:13970:13971 ~-0.0460247864049427 216:0.1015625:13972:13973 ~0.021080826265064707 110:0.90625:13974:13975 ~-0.02945829045243772 "
    s .= "~0.02286792816547427 ~0.006311117539470582 ~0.025762706224982168 ~0.026565189382430517 ~0.019458978152054756 109:1.875:13981:13982 ~0.018788680547509585 206:-0.359375:13983:13984 ~0.024173291934260918 ~-0.035238892177015 "
    s .= "218:0.09375:13986:13987 ~0.023326730509059233 245:1.765625:13988:13989 ~0.02647865727774297 ~-0.023622892393546216 122:-0.359375:13991:13994 247:0.265625:13992:13993 ~0.004647830728144274 ~-0.022989732729349358 "
    s .= "254:0.609375:13995:13996 ~0.006734445517224576 252:0.275:13997:14004 40:0.0625:13998:13999 ~-0.04532970107268178 14:-0.546875:14000:14001 ~0.01792838084377525 190:0.5:14002:14003 ~-0.03725645269198157 ~0.017642224932764017 "
    s .= "50:-0.03125:14005:14006 ~0.006197303427449569 ~-0.027920007163240543 251:0.734375:14008:14029 213:0.5546875:14009:14028 205:-0.28125:14010:14011 ~-0.036985672394197616 64:1.375:14012:14027 61:-0.03125:14013:14014 "
    s .= "~0.0072846731185319015 85:0.15625:14015:14018 170:-0.390625:14016:14017 ~-0.051129670484076684 ~-0.010337647359702638 169:0.21875:14019:14024 4:-0.0625:14020:14021 ~-0.016004308822247224 250:0.9609375:14022:14023 "
    s .= "~0.020246195949110597 ~-0.012332887670942134 112:1.59375:14025:14026 ~-0.04147415000845186 ~0.03193084537947744 ~0.026581313786868423 ~-0.044541243835705076 249:0.16666666666666666:14030:14041 245:3.5483870967741935:14031:14040 "
    s .= "106:0.78125:14032:14039 127:0.921875:14033:14038 202:-0.015625:14034:14037 245:2.536231884057971:14035:14036 ~-0.03338515284921568 ~0.02216986105233037 ~0.020508541334077174 ~-0.03755833547538062 ~0.024698721056360118 "
    s .= "~-0.028739162424543094 215:-0.46875:14042:14043 ~0.010765259233589333 96:0.1484375:14044:14051 178:0.109375:14045:14046 ~0.0012407677520951197 223:0.25:14047:14048 ~-0.038028774734266135 16:0.1875:14049:14050 "
    s .= "~-0.023875461216457453 ~0.020622055475033447 235:0.15625:14052:14053 ~0.015066873215210892 ~-0.020170391395490646 253:-0.04464285714285676:14055:14074 252:0.225:14056:14067 47:-0.734375:14057:14058 ~0.022050414079715405 "
    s .= "60:0.2109375:14059:14064 246:0.109375:14060:14063 8:-0.328125:14061:14062 ~-0.02920050400170364 ~0.011594531736164211 ~-0.03787368041464842 245:1.8181818181818181:14065:14066 ~-0.02652794646915639 ~0.02322140866796374 "
    s .= "166:0.1875:14068:14069 ~0.02452077067815804 97:0:14070:14071 ~-0.03370077967539407 43:-0.109375:14072:14073 ~-0.03805634010642849 ~0.02901275804771294 187:-0.3125:14075:14078 3:0.6015625:14076:14077 ~-0.043980684677786167 "
    s .= "~0.013599962684324465 243:1.55:14079:14096 100:-0.375:14080:14081 ~0.022202684553702667 217:0.21875:14082:14085 87:0.3671875:14083:14084 ~0.004017213449002937 ~-0.017652130242616634 220:0.328125:14086:14089 "
    s .= "82:1.234375:14087:14088 ~-0.04178553218966346 ~0.011164447570900916 106:0.5625:14090:14093 148:0.4375:14091:14092 ~0.02623622492784046 ~-0.024564769233505493 115:1.34375:14094:14095 ~-0.031281562638723795 ~0.028224426913627434 "
    s .= "134:0.03125:14097:14098 ~-0.04623960672508953 245:1.736842105263158:14099:14100 ~-0.04167281100498801 ~0.013325137586529576 "
    return s
}

ModelBBase() => -0.0780689667078697
ModelBRoots() {
    return "1 48 95 142 189 236 283 330 377 424 471 518 565 612 659 706 753 800 847 894 941 988 1035 1082 1129 1176 1223 1270 1317 1364 1411 1458 1505 1552 1599 1646 1693 1740 1787 1834 1881 1928 1975 2022 2069 2116 2163 2210 2257 2304 2351 2398 2445 2492 2539 2586 2633 2680 2727 2774 2821 2868 2915 2962 3009 3056 3103 3150 3197 3244 3291 3338 3385 3432 3479 3526 3573 3620 3667 3714 3761 3808 3855 3902 3949 3996 4043 4090 4137 4184 4231 4278 4325 4372 4419 4466 4513 4560 4607 4654 4701 4748 4795 4842 4889 4936 4983 5030 5077 5124 5171 5218 5265 5312 5359 5406 5453 5500 5547 5594 5641 5688 5735 5782 5829 5876 5923 5970 6017 6064 6111 6158 6205 6252 6299 6346 6393 6440 6487 6534 6581 6628 6675 6722 6769 6816 6863 6910 6957 7004 7051 7098 7145 7192 7239 7286 7333 7380 7427 7474 7521 7568 7615 7662 7709 7756 7803 7850 7897 7944 7991 8038 8085 8132 8179 8226 8273 8320 8367 8414 8461 8508 8555 8602 8649 8696 8743 8790 8837 8884 8931 8978 9025 9072 9119 9166 9213 9260 9307 9354 9401 9448 9495 9542 9589 9636 9683 9730 9777 9824 9871 9918 9965 10012 10059 10106 10153 10200 10247 10294 10341 10388 10435 10482 10529 10576 10623 10670 10717 10764 10811 10858 10905 10952 10999 11046 11093 11140 11187 11234 11281 11328 11375 11422 11469 11516 11563 11610 11657 11704 11751 11798 11845 11892 11939 11986 12033 12080 12127 12174 12221 12268 12315 12362 12409 12456 12503 12550 12597 12644 12691 12738 12785 12832 12879 12926 12973 13020 13067 13114 13161 13208 13255 13302 13349 13396 13443 13490 13537 13584 13631 13678 13725 13772 13819 13866 13913 13960 14007 14054"
}

ModelBText() {
    s := ""
    s .= "248:0.625:2:39 244:0.9:3:12 220:1.21875:4:11 53:-0.5:5:10 75:0.2890625:6:7 ~-0.08953837729704776 127:0.4375:8:9 ~-0.09035060986392827 ~0.09604432380123931 ~-0.09263112726610463 ~0.0838941806242875 249:1.8333333333333335:13:36 "
    s .= "253:-0.011046253879119273:14:21 243:0.45:15:18 244:1.355:16:17 ~-0.06686124555943902 ~0.08500854636921686 256:0.9433962264150944:19:20 ~0.09933938531142562 ~-0.09151127396027732 251:0.921875:22:33 112:1.171875:23:28 "
    s .= "245:2.4057971014492754:24:25 ~-0.0667591551927265 38:-0.734375:26:27 ~0.07314333211585826 ~-0.029575930070630974 205:-0.078125:29:30 ~-0.07011408026819842 95:0.125:31:32 ~0.09214260824675492 ~-0.04856948972022903 243:0.45:34:35 "
    s .= "~0.00905016589433305 ~0.08672693121799938 192:0.2890625:37:38 ~-0.09365539689262577 ~0.06631533893411933 251:1.109375:40:45 61:1.40625:41:42 ~-0.08920023061010851 85:1.53125:43:44 ~-0.0882682571987447 ~0.08759219138244484 "
    s .= "32:-0.671875:46:47 ~0.05356479944044323 ~-0.05783743668963629 248:0.625:49:86 244:0.9:50:59 220:1.21875:51:58 53:-0.5:52:57 75:0.2890625:53:54 ~-0.08555727311132089 127:0.4375:55:56 ~-0.08641482907727105 ~0.09114335644554832 "
    s .= "~-0.08852092571596121 ~0.07962063814986102 249:1.8333333333333335:60:83 253:-0.011046253879119273:61:68 243:0.45:62:65 244:1.355:63:64 ~-0.0637997617679368 ~0.08065850295322739 256:0.9433962264150944:66:67 ~0.09423463609955252 "
    s .= "~-0.08764164215612179 251:0.921875:69:80 112:1.171875:70:75 245:2.4057971014492754:71:72 ~-0.06366757102248913 85:1.15625:73:74 ~-0.025910719210300304 ~0.07646635838175886 211:-0.109375:76:77 ~-0.05629054336270354 "
    s .= "247:0.390625:78:79 ~0.08658558980714942 ~-0.08987691001756859 243:0.45:81:82 ~0.008597802900633491 ~0.08226558893630051 192:0.3984375:84:85 ~-0.08902660525732065 ~0.0712767970670598 251:1.109375:87:92 61:1.40625:88:89 "
    s .= "~-0.08521586977008755 85:1.53125:90:91 ~-0.08439327048105319 ~0.08315081748913307 32:-0.671875:93:94 ~0.05083762951848652 ~-0.055125725868248515 248:0.625:96:133 244:0.9:97:106 220:1.21875:98:105 8:-0.484375:99:104 "
    s .= "51:0.2890625:100:101 ~-0.0798110761700825 127:0.453125:102:103 ~-0.06931657232026903 ~0.08279849686641381 ~-0.08516684854197765 ~0.07582083552120342 220:-0.125:107:118 211:-0.234375:108:111 230:-0.671875:109:110 "
    s .= "~0.037546137286176146 ~-0.08231225564896943 253:-0.017857142857142856:112:113 ~0.07506117930409907 232:-0.0625:114:115 ~-0.06082776743330708 244:1.225:116:117 ~-0.05051726642635351 ~0.06773312608448094 243:0.45:119:124 "
    s .= "244:1.315:120:121 ~-0.0482648710787536 184:0.078125:122:123 ~-0.023694060822223428 ~0.08039528165308883 253:-0.011046253879119273:125:128 249:1.8333333333333335:126:127 ~0.09113547746901497 ~-0.052071197100424495 "
    s .= "251:0.734375:129:132 112:0.84375:130:131 ~-0.057780284676863795 ~0.06245144040713463 ~0.07978437445990587 251:1.109375:134:139 61:1.40625:135:136 ~-0.08169788869248928 85:1.53125:137:138 ~-0.08096392903653093 ~0.07922440895921445 "
    s .= "51:0.4140625:140:141 ~-0.05255276313651062 ~0.05264902423400432 248:0.625:143:176 244:0.865:144:145 ~-0.07864954998970153 220:-0.125:146:157 211:-0.234375:147:150 219:0.4296875:148:149 ~-0.07844694354622679 ~0.049310622150665125 "
    s .= "253:-0.017857142857142856:151:152 ~0.06935623902178827 245:2.985294117647059:153:156 251:1.578125:154:155 ~-0.0640960748237218 ~0.06204602158964559 ~0.04648715541441578 253:-0.011046253879119273:158:167 2:0.6875:159:166 "
    s .= "241:0.16:160:163 181:0.515625:161:162 ~-0.07749973802861733 ~0.08866771569575892 249:1.8333333333333335:164:165 ~0.08609984331760537 ~-0.05135364145891094 ~-0.08702642037004917 26:0.125:168:173 251:0.578125:169:172 "
    s .= "112:0.90625:170:171 ~-0.05174347114986018 ~0.0684928032289359 ~0.0728832753477782 251:1.234375:174:175 ~-0.06695290215356335 ~0.040173743046583554 251:1.109375:177:182 61:1.40625:178:179 ~-0.07856566877611189 85:1.53125:180:181 "
    s .= "~-0.07790459324111575 ~0.07572114149095716 167:-0.578125:183:184 ~0.04624964939048747 219:0.2578125:185:186 ~-0.07054348912050461 184:0.21875:187:188 ~-0.06023518146471041 ~0.06566521919354017 248:0.625:190:227 244:0.9:191:200 "
    s .= "220:1.21875:192:199 98:-0.5:193:198 75:0.2890625:194:195 ~-0.07635045571429398 124:0.390625:196:197 ~-0.07323412714627685 ~0.08777412620313797 ~-0.07937354934383058 ~0.0696503792439243 249:1.5:201:224 "
    s .= "253:-0.011046253879119273:202:211 243:0.45:203:206 244:1.355:204:205 ~-0.05908687279009653 ~0.07113370219333928 256:0.9433962264150944:207:210 28:0.96875:208:209 ~0.08332206998823125 ~-0.05087005316996242 ~-0.08764457209325131 "
    s .= "251:0.921875:212:221 112:1.171875:213:218 11:-0.6875:214:217 106:1.265625:215:216 ~-0.026933945532254006 ~0.0844053454333455 ~-0.05115212328338577 211:-0.109375:219:220 ~-0.05094538374914335 ~0.07202813622319566 236:0.625:222:223 "
    s .= "~0.06985089052627 ~-0.08727820034446537 195:0.2109375:225:226 ~-0.07971183172186752 ~0.035367398150641126 45:0.3515625:228:229 ~-0.07469220035512628 85:0.890625:230:233 251:1.828125:231:232 ~-0.07555074684015965 "
    s .= "~0.04008858071138921 28:0.125:234:235 ~0.0946865987884693 ~-0.07463986408448121 248:0.625:237:274 244:0.865:238:245 127:0.9375:239:242 226:0.890625:240:241 ~-0.07934161568698749 ~0.025909114360150993 130:0.1875:243:244 "
    s .= "~0.08428207769711098 ~-0.08061815330524555 220:-0.125:246:257 211:-0.234375:247:250 195:0.2109375:248:249 ~-0.07661969439763652 ~0.01636120600850613 253:-0.017857142857142856:251:252 ~0.06349459542958831 125:-0.8125:253:254 "
    s .= "~0.06203899342304197 251:1.390625:255:256 ~-0.06119219172584081 ~0.05047442662358829 253:-0.011046253879119273:258:265 2:0.6875:259:264 241:0.16:260:263 181:0.515625:261:262 ~-0.07317065331273973 ~0.0830261831977929 "
    s .= "~0.07928374961767475 ~-0.08280345231675944 26:0.125:266:271 251:0.578125:267:270 112:0.90625:268:269 ~-0.04753726071531681 ~0.06340065569995075 ~0.06737276363749127 251:1.234375:272:273 ~-0.06272675193263404 ~0.03625311037208725 "
    s .= "251:1.109375:275:280 61:1.40625:276:277 ~-0.07331981222214055 85:1.53125:278:279 ~-0.07268308371575256 ~0.07267179046189784 32:-0.671875:281:282 ~0.047403092621476 ~-0.046304688914360376 248:0.375:284:305 244:0.905:285:292 "
    s .= "53:-0.5:286:291 10:-0.03125:287:290 34:-0.078125:288:289 ~-0.07394503696843023 ~0.07731392197345006 ~-0.07160261851047384 ~-0.07197566026487662 253:-0.020229505523620725:293:294 ~0.07695372444687826 251:0.359375:295:298 "
    s .= "137:-0.765625:296:297 ~0.06277209332950838 ~-0.05771750288189803 26:0.203125:299:302 202:-0.140625:300:301 ~-0.004730590949295856 ~0.06414342846249718 244:1.14:303:304 ~-0.08647504777522813 ~0.0229812739749526 "
    s .= "251:1.171875:306:321 64:1.28125:307:318 109:0.9375:308:309 ~-0.0713976555794081 252:0.125:310:311 ~-0.07243407734828282 217:-0.109375:312:313 ~-0.07857314982463798 49:0.28125:314:317 248:1.125:315:316 ~0.0839610653399199 "
    s .= "~-0.06231862018406499 ~-0.07460008033456177 199:-0.03125:319:320 ~-0.07030132330468546 ~0.06671520360206633 192:0.2421875:322:327 253:-0.0218253968253966:323:326 208:-0.234375:324:325 ~-0.07295456479336852 ~0.05745456663866488 "
    s .= "~-0.05466653278753684 167:-0.125:328:329 ~0.07740843751714493 ~-0.027950084531902737 248:0.625:331:368 244:0.865:332:333 ~-0.06941700478219802 220:-0.15625:334:345 211:-0.1875:335:340 193:-0.0625:336:337 ~-0.07335000330433927 "
    s .= "77:-0.015625:338:339 ~0.0594642359731723 ~-0.07602481933559499 244:1.08:341:342 ~-0.04633373356416759 251:0.859375:343:344 ~-0.0052359337748080275 ~0.06405458925986363 253:-0.011046253879119273:346:357 "
    s .= "249:1.8333333333333335:347:356 243:0.45:348:353 172:-0.109375:349:350 ~0.0761983739038468 154:0.78125:351:352 ~-0.0714375464273312 ~0.05784370642096162 2:0.6875:354:355 ~0.07566782526027349 ~-0.07850761050318635 "
    s .= "~-0.055936651414143126 251:1.046875:358:367 112:0.84375:359:364 251:0.484375:360:361 ~-0.06523515742491899 156:0.1171875:362:363 ~0.027691343345461007 ~-0.05864382408565632 95:0.1875:365:366 ~0.058856886586994096 "
    s .= "~-0.043608932104845725 ~0.06823599206421276 45:0.3515625:369:370 ~-0.06794233126484688 85:0.890625:371:374 251:1.828125:372:373 ~-0.06886034540473612 ~0.03638557155424101 53:0.09375:375:376 ~0.08851093622549683 "
    s .= "~-0.070028223396689 248:0.375:378:399 244:0.865:379:384 50:-0.484375:380:383 75:0.2890625:381:382 ~-0.07216112072889118 ~0.04632469732742961 ~-0.07348150841413952 251:0.296875:385:390 253:-0.041666666666666664:386:387 "
    s .= "~0.05602299936288069 137:-0.71875:388:389 ~0.043649533028234884 ~-0.06271758913943998 253:-0.024227642276423468:391:392 ~0.07308229551197473 77:-0.125:393:396 187:-0.3125:394:395 ~-0.06918217616931278 ~0.06166656853296973 "
    s .= "244:1.21:397:398 ~-0.04402824921917767 ~0.04014764657182829 251:1.171875:400:415 64:1.28125:401:412 109:0.640625:402:403 ~-0.0700957277094521 252:0.125:404:405 ~-0.06441557935205032 121:0.25:406:411 217:-0.109375:407:408 "
    s .= "~-0.07558520605516483 244:0.865:409:410 ~-0.056865123317392643 ~0.06609054702493894 ~-0.06875530655434982 199:-0.03125:413:414 ~-0.06628543632485655 ~0.06271223247625006 192:0.2421875:416:421 220:-0.21875:417:418 "
    s .= "~-0.07575764487593548 253:-0.023114581505527098:419:420 ~0.05264499967249791 ~-0.035149671758251816 167:-0.125:422:423 ~0.07291982278578663 ~-0.026090600021060506 248:0.625:425:458 244:0.865:426:427 ~-0.06577276126620557 "
    s .= "220:-0.125:428:439 211:-0.234375:429:432 219:0.4296875:430:431 ~-0.06682615166871277 ~0.04164036282066593 253:-0.020229505523620725:433:434 ~0.055664652680796206 125:-0.8125:435:436 ~0.0557540389533303 251:1.390625:437:438 "
    s .= "~-0.055482475006360714 ~0.0433778354279318 243:0.45:440:445 244:1.315:441:442 ~-0.0365222382075038 184:0.078125:443:444 ~-0.02874301889067207 ~0.06403669393855332 251:0.328125:446:449 85:0.828125:447:448 ~-0.04399022136051636 "
    s .= "~0.05246120966961202 256:0.9583333333333334:450:457 31:0.734375:451:456 203:0.828125:452:455 249:1.8333333333333335:453:454 ~0.069915384988872 ~-0.04532796387673132 ~-0.09406160026812896 ~-0.022654867298580458 "
    s .= "~-0.07880284696659429 251:1.109375:459:464 61:1.40625:460:461 ~-0.06546016237380525 85:1.53125:462:463 ~-0.06588876525679052 ~0.06834672813098588 184:0.28125:465:466 ~-0.053607272602124924 193:-0.21875:467:468 "
    s .= "~-0.0681852515192043 167:0.15625:469:470 ~0.07387691164637905 ~-0.04961713186123605 248:0.625:472:505 244:0.865:473:474 ~-0.06405587178311227 220:-0.15625:475:486 211:-0.1875:476:479 193:-0.0625:477:478 ~-0.06841392344194883 "
    s .= "~0.015903199002340482 106:0.609375:480:483 251:1.484375:481:482 ~-0.07058904104356455 ~0.06063132473847969 191:-0.140625:484:485 ~0.05947474779692452 ~-0.01771510914352362 253:-0.011046253879119273:487:494 243:0.45:488:491 "
    s .= "172:-0.109375:489:490 ~0.07086631936844162 ~-0.026582639566203877 249:1.8333333333333335:492:493 ~0.06934181513345943 ~-0.0516091393156709 251:1.046875:495:504 112:0.84375:496:501 251:0.484375:497:498 ~-0.061153963581835225 "
    s .= "156:0.1171875:499:500 ~0.02429250657807406 ~-0.05644400824987294 256:0.16326530612244897:502:503 ~0.05027158644131827 ~-0.08304024410884203 ~0.06228691094160145 251:0.671875:506:509 214:0.640625:507:508 ~-0.06942832055772352 "
    s .= "~-0.03992521413769584 219:0.2890625:510:515 50:-0.5625:511:514 252:0.275:512:513 ~-0.04164211534524024 ~0.06520438867444155 ~-0.061500748422997756 2:0.0625:516:517 ~0.04739593392217432 ~-0.05994043869414897 248:0.375:519:538 "
    s .= "244:0.905:520:527 53:-0.5:521:526 10:-0.03125:522:525 34:-0.078125:523:524 ~-0.06602892140574257 ~0.07410018447779702 ~-0.0643800055575371 ~-0.06403898756356038 253:-0.020229505523620725:528:529 ~0.06702174196166044 "
    s .= "251:0.578125:530:533 137:-0.765625:531:532 ~0.057095306624073576 ~-0.04002462472346027 162:0.4296875:534:537 181:-0.03125:535:536 ~-0.0037200682193943633 ~0.05822015440229059 ~-0.04138138346112046 251:1.171875:539:556 "
    s .= "64:1.28125:540:553 109:0.640625:541:542 ~-0.06544362557609916 252:0.125:543:544 ~-0.05975347229048683 121:0.25:545:552 217:-0.109375:546:547 ~-0.07117730574624574 248:1.125:548:551 121:-0.203125:549:550 ~-0.06626813669208154 "
    s .= "~0.07134476431721444 ~-0.06057844634400547 ~-0.0644857687445604 22:-0.0625:554:555 ~-0.07107461354132627 ~0.055559302056200646 168:0.2578125:557:562 61:0.15625:558:559 ~-0.056991531714032456 148:-0.1875:560:561 "
    s .= "~-0.06726313543090301 ~0.032694763551300576 191:-0.078125:563:564 ~0.06972370899124117 ~-0.037979608677708936 248:0.625:566:597 244:0.865:567:568 ~-0.061243237385831865 220:-0.15625:569:578 211:-0.1875:570:573 193:-0.0625:571:572 "
    s .= "~-0.06579266992426207 ~0.014503843100163059 249:0.5:574:577 191:0.09375:575:576 ~0.04801325312512714 ~-0.0365311041656651 ~-0.04933481417855945 253:-0.011046253879119273:579:588 243:0.45:580:585 172:-0.109375:581:582 "
    s .= "~0.06727199369606485 154:0.78125:583:584 ~-0.06930017567801869 ~0.050974169697285 2:0.6875:586:587 ~0.06606687044046614 ~-0.07767865032052751 29:-0.03125:589:594 251:0.578125:590:593 112:1.1875:591:592 ~-0.031845558145364626 "
    s .= "~0.061520652127288904 ~0.05595010060774696 251:1.046875:595:596 ~-0.047407397059293435 ~0.031955531864768204 251:0.671875:598:603 214:0.640625:599:600 ~-0.06661569846120041 139:1.421875:601:602 ~-0.056309687393184565 "
    s .= "~0.10046487627862202 219:0.2890625:604:609 50:-0.5625:605:608 79:-0.015625:606:607 ~-0.06652490526485787 ~0.02943512851955346 ~-0.058593841742653786 35:0.0625:610:611 ~0.051355195661779776 ~-0.045669538369636845 248:0.375:613:632 "
    s .= "244:0.905:614:619 53:-0.5:615:618 94:0.140625:616:617 ~0.051030281417660896 ~-0.0642352231194991 ~-0.06144627723417687 253:-0.023114581505527098:620:621 ~0.0642861044127928 251:0.359375:622:627 112:1.1875:623:624 "
    s .= "~-0.056123336364310675 202:-0.078125:625:626 ~-0.07299304901012484 ~0.06364707988936233 77:-0.15625:628:629 ~0.05343693557380339 244:1.08:630:631 ~-0.051769126303140636 ~0.030190958252706197 251:1.171875:633:650 "
    s .= "64:1.28125:634:647 109:0.640625:635:636 ~-0.06278515323915447 249:1.1666666666666665:637:646 85:1.234375:638:643 253:-0.04450757575757791:639:642 171:-0.015625:640:641 ~-0.06118367180372053 ~0.044734452620725326 "
    s .= "~-0.0476505122259657 229:-0.09375:644:645 ~-0.0601476402217877 ~0.07392712704906677 ~-0.06541576545840709 57:0.1796875:648:649 ~-0.03555203954860321 ~0.06555138634825307 141:0.2109375:651:656 64:0.09375:652:653 "
    s .= "~-0.052103915103216686 184:0.015625:654:655 ~-0.052892869482987825 ~0.04134175213065328 218:0.40625:657:658 ~0.06426735953899539 ~-0.06842794747032631 248:0.625:660:693 244:0.865:661:666 98:-0.5:662:665 51:0.2890625:663:664 "
    s .= "~-0.06192767487807497 ~0.05831733842740982 ~-0.06523839768170556 220:-0.125:667:676 211:-0.234375:668:671 230:-0.671875:669:670 ~0.027753271450631098 ~-0.061892526818431354 253:-0.0218253968253966:672:673 ~0.04868937813795117 "
    s .= "244:1.215:674:675 ~-0.05953474721735104 ~0.011017035006040336 243:0.45:677:684 130:0.9375:678:681 82:-0.046875:679:680 ~0.026662646215750103 ~-0.0496307452448838 107:0.0625:682:683 ~0.05358854841504334 ~-0.06773377171530388 "
    s .= "253:-0.0218253968253966:685:686 ~0.06386966955923096 251:0.765625:687:690 85:1.140625:688:689 ~-0.03386695460077756 ~0.04913552344286096 211:-0.234375:691:692 ~-0.054531670404014826 ~0.058315201674193684 251:0.671875:694:699 "
    s .= "214:0.640625:695:696 ~-0.06419292845651767 139:1.421875:697:698 ~-0.05347689796660421 ~0.09076232192412521 229:-0.109375:700:701 ~-0.06256126114953307 85:0.796875:702:703 ~-0.03989104860100771 122:0.25:704:705 "
    s .= "~0.06428107941693732 ~-0.05250968087543592 248:0.375:707:726 244:0.85:708:709 ~-0.05891096929426699 253:-0.023114581505527098:710:711 ~0.06083461690596759 251:0.359375:712:717 112:1.1875:713:714 ~-0.0566597490112044 "
    s .= "202:-0.078125:715:716 ~-0.07012167043798241 ~0.057653073726017225 26:0.171875:718:723 187:-0.3125:719:720 ~-0.05871208456635643 243:1.35:721:722 ~0.05104423607393058 ~-0.00951878228536578 244:1.315:724:725 ~-0.0681849631950258 "
    s .= "~0.026403283476128487 251:1.171875:727:744 64:1.28125:728:741 109:0.640625:729:730 ~-0.06043033832370445 249:1.1666666666666665:731:740 85:1.234375:732:737 253:-0.04450757575757791:733:736 171:-0.015625:734:735 "
    s .= "~-0.05898492184219434 ~0.04229322884716735 ~-0.04485740793188942 229:-0.171875:738:739 ~-0.06927253612263058 ~0.06763992071581436 ~-0.06315770730640492 22:-0.0625:742:743 ~-0.06738443245556901 ~0.05051869204477244 "
    s .= "168:0.2578125:745:750 196:-0.078125:746:747 ~-0.06029255195555289 85:0.28125:748:749 ~-0.043352819423827 ~0.04366448086086584 191:-0.078125:751:752 ~0.06449776411808812 ~-0.03620519105421384 248:0.625:754:787 244:0.865:755:762 "
    s .= "127:0.9375:756:759 226:0.890625:757:758 ~-0.06340318640076852 ~0.0391205537667107 130:0.1875:760:761 ~0.08177067616099565 ~-0.06488821551303783 220:-0.15625:763:768 2:-0.671875:764:765 ~0.04362087381151981 195:0.2890625:766:767 "
    s .= "~-0.051668298350638235 ~0.03529499287375443 253:-0.011046253879119273:769:776 243:0.45:770:773 172:-0.109375:771:772 ~0.06214676170315661 ~-0.030288403696574387 256:0.9433962264150944:774:775 ~0.06095824109095638 "
    s .= "~-0.10740941771044613 251:1.140625:777:786 112:0.875:778:783 151:0.953125:779:782 220:0.890625:780:781 ~-0.04425854290010556 ~0.04120763595535129 ~0.050371881746788395 247:0.453125:784:785 ~0.04505976650978074 "
    s .= "~-0.07080169384065595 ~0.05519130296718242 251:0.671875:788:791 244:2.785:789:790 ~-0.05872488432391292 ~0.09688233174412698 219:0.2890625:792:797 50:-0.5625:793:796 88:0.375:794:795 ~-0.04290439990824919 ~0.046880275430281004 "
    s .= "~-0.0539336162927115 2:0.0625:798:799 ~0.04280493175840597 ~-0.053470776201936576 248:0.375:801:824 244:0.905:802:809 53:-0.5:803:808 10:-0.03125:804:807 34:-0.078125:805:806 ~-0.060545860882078584 ~0.06784172892436764 "
    s .= "~-0.05900161629876558 ~-0.05747626376855669 253:-0.023114581505527098:810:813 256:0.9433962264150944:811:812 ~0.05987250863658297 ~-0.10652467150821635 251:1.046875:814:823 130:1.046875:815:818 245:2.682926829268293:816:817 "
    s .= "~-0.04683056999897326 ~0.01608719765589175 243:1.35:819:822 214:-0.203125:820:821 ~-0.03631003514164027 ~0.05292379055714504 ~-0.06507761404905187 ~0.05172041124707551 251:1.171875:825:838 109:0.9375:826:831 220:0.96875:827:828 "
    s .= "~-0.05688037042635846 26:-0.09375:829:830 ~0.07632816580420114 ~-0.0597318401486593 252:0.125:832:833 ~-0.05476569181664035 196:-0.125:834:835 ~-0.0656595872281998 248:1.125:836:837 ~0.06325428320209024 ~-0.058173836365917976 "
    s .= "141:0.2109375:839:844 253:-0.01339285714285765:840:843 55:-0.125:841:842 ~-0.0633273064829334 ~0.04962519542586944 ~-0.04457296983882931 191:-0.09375:845:846 ~0.06368682448335682 ~-0.024708310410411816 248:0.625:848:883 "
    s .= "244:0.865:849:854 98:-0.5:850:853 75:0.2890625:851:852 ~-0.060263891961781516 ~0.05028186753008307 ~-0.061496255315589735 220:-0.125:855:864 211:-0.1875:856:859 195:0.2109375:857:858 ~-0.058456129449085736 ~0.01699116128866641 "
    s .= "244:1.08:860:861 ~-0.03931132276154822 251:0.296875:862:863 ~-0.06087263552361553 ~0.041856800187796576 243:0.45:865:870 130:0.90625:866:867 ~-0.0330777098942325 107:0.0625:868:869 ~0.04853532206955439 ~-0.06782827093792493 "
    s .= "253:-0.02592592592592524:871:872 ~0.05963969555256465 251:0.765625:873:878 85:1.140625:874:875 ~-0.030784736698824727 211:-0.21875:876:877 ~-0.07544806868381944 ~0.0559873914242411 211:-0.234375:879:880 ~-0.05224875277368313 "
    s .= "236:0.625:881:882 ~0.05581972546245878 ~-0.0816629898594993 244:1.285:884:885 ~-0.055649660485485725 252:0.125:886:889 219:0.3828125:887:888 ~-0.05533490757291568 ~0.03100648323451577 248:0.875:890:893 196:-0.09375:891:892 "
    s .= "~-0.06624143070452994 ~0.07780532653802029 ~-0.03170261635693032 248:0.375:895:918 244:0.85:896:897 ~-0.0551847746068308 253:-0.02592592592592524:898:907 25:0.65625:899:906 241:0.16:900:903 181:0.515625:901:902 "
    s .= "~-0.0744203979537233 ~0.06686520706949202 256:0.9433962264150944:904:905 ~0.05906919905382313 ~-0.10208375218577909 ~-0.06087785034697523 251:0.546875:908:913 203:-0.71875:909:910 ~0.04246353018826346 163:1.203125:911:912 "
    s .= "~-0.04828450876715903 ~0.01839337147541552 50:0.3125:914:917 202:-0.09375:915:916 ~-0.0014005488775462116 ~0.048843436154784335 ~-0.04101946611942918 251:1.171875:919:932 109:0.9375:920:923 220:0.96875:921:922 "
    s .= "~-0.05491147200033724 ~0.015596627414538801 252:0.125:924:925 ~-0.05269631357953267 196:-0.125:926:927 ~-0.06392621375931162 248:1.125:928:931 49:0.28125:929:930 ~0.06599176329589197 ~-0.050620716708416204 ~-0.05599475595363482 "
    s .= "141:0.2109375:933:938 64:0.09375:934:935 ~-0.046358948751568735 184:0.015625:936:937 ~-0.04973142261197031 ~0.03729318295535687 191:0.15625:939:940 ~0.059726472722775904 ~-0.040566721165371196 248:0.625:942:969 244:0.9:943:952 "
    s .= "220:0.890625:944:949 232:0.703125:945:946 ~-0.05808734437937732 184:0.109375:947:948 ~0.0732303536996533 ~-0.05422310765718669 217:0.34375:950:951 ~0.0679771507853744 ~-0.06358401906467291 217:-0.140625:953:958 211:-0.125:954:955 "
    s .= "~-0.047233429794440646 244:1.13:956:957 ~-0.038339556561691614 ~0.040431943013143394 253:-0.02592592592592524:959:960 ~0.05678461080145574 29:-0.03125:961:966 251:1.171875:962:965 112:0.84375:963:964 ~-0.014145971297821282 "
    s .= "~0.04601757914368019 ~0.05526056702889607 157:0.71875:967:968 ~-0.04927441468855875 ~0.012042165811844571 251:0.671875:970:979 214:0.640625:971:972 ~-0.05880889309995261 139:1.421875:973:978 241:0.1:974:977 223:0.09375:975:976 "
    s .= "~0.18291691605044985 ~-0.058098817677841766 ~-0.05468331516101439 ~0.07873339922112878 226:-0.140625:980:981 ~-0.059148217303888154 85:0.796875:982:985 160:1.640625:983:984 ~-0.03942295216619229 ~0.06874061781606765 "
    s .= "122:0.25:986:987 ~0.05901993351910309 ~-0.048025021955806414 248:0.625:989:1016 244:0.865:990:993 127:0.9375:991:992 ~-0.056791597250213335 ~0.0005163260202740922 220:-0.15625:994:999 251:0.859375:995:996 ~-0.044599837776035545 "
    s .= "252:0.125:997:998 ~-0.04112742464372567 ~0.04399736873811951 253:-0.02592592592592524:1000:1003 241:0.16:1001:1002 ~-0.023031537656388986 ~0.055898990439120916 26:0:1004:1011 251:0.578125:1005:1010 157:0.8125:1006:1009 "
    s .= "31:-0.09375:1007:1008 ~0.022500127005410084 ~-0.051971525033483415 ~0.04401310199044345 ~0.04596294000212858 244:1.315:1012:1013 ~-0.0550440627934034 136:0.1875:1014:1015 ~-0.053941175172732884 ~0.029308384561460128 "
    s .= "251:0.671875:1017:1026 214:0.640625:1018:1019 ~-0.0580029744987172 139:1.078125:1020:1025 241:0.1:1021:1024 223:0.09375:1022:1023 ~0.16369426070621776 ~-0.05717210848443463 ~-0.05697299303019293 ~0.06303474054443738 "
    s .= "229:-0.109375:1027:1028 ~-0.05586820934914153 85:0.796875:1029:1032 8:-0.640625:1030:1031 ~0.02979440026421904 ~-0.04318956954828743 122:0.25:1033:1034 ~0.056679244880102224 ~-0.046921415432920444 248:0.375:1036:1061 "
    s .= "244:0.85:1037:1038 ~-0.05266317950867401 253:-0.02592592592592524:1039:1044 25:0.65625:1040:1043 241:0.16:1041:1042 ~-0.016896356684144916 ~0.055988745019125534 ~-0.05984653113315255 251:0.359375:1045:1050 112:1.1875:1046:1047 "
    s .= "~-0.050543085521378955 202:-0.078125:1048:1049 ~-0.06556517265985454 ~0.050569702815096595 77:-0.125:1051:1058 187:-0.3125:1052:1053 ~-0.06627143933403276 243:1.45:1054:1057 243:0.25:1055:1056 ~-0.04858347866913959 "
    s .= "~0.05099584736573673 ~-0.03753595205436378 244:1.21:1059:1060 ~-0.03793277793378024 ~0.02685534858360423 251:1.203125:1062:1073 109:0.9375:1063:1066 220:0.96875:1064:1065 ~-0.0524272754598864 ~0.017166992704794066 "
    s .= "252:0.125:1067:1068 ~-0.04993828420083746 196:-0.140625:1069:1070 ~-0.06284074059662019 248:1.125:1071:1072 ~0.05689153570940765 ~-0.05410622484256955 141:0.2109375:1074:1079 184:0.03125:1075:1076 ~-0.051804794145765956 "
    s .= "196:-0.09375:1077:1078 ~-0.05130789281644707 ~0.03023080583864581 194:0.46875:1080:1081 ~0.056053847172252584 ~-0.061753632915554024 248:0.625:1083:1114 244:0.855:1084:1085 ~-0.05305315109987463 187:-0.265625:1086:1089 "
    s .= "253:-0.07552083333333215:1087:1088 ~0.015840321024670437 ~-0.05902524959483969 253:-0.0218253968253966:1090:1099 157:-0.53125:1091:1092 ~-0.06340016160611776 243:0.45:1093:1096 232:0.203125:1094:1095 ~-0.06454449200107497 "
    s .= "~0.037998912016251725 256:0.9433962264150944:1097:1098 ~0.055747084321208576 ~-0.10127576503897984 38:-0.15625:1100:1109 202:-0.0625:1101:1102 ~-0.013407414356904993 251:1.171875:1103:1108 157:0.8125:1104:1107 "
    s .= "220:0.890625:1105:1106 ~-0.023106260038462702 ~0.06516359245954173 ~0.051070654687966954 ~0.0583825162014949 244:1.215:1110:1111 ~-0.04528728743292268 130:2:1112:1113 ~0.022449114872639876 ~-0.07070121634172603 "
    s .= "251:0.671875:1115:1122 214:0.640625:1116:1117 ~-0.056620881307314 139:1.421875:1118:1121 241:0.1:1119:1120 ~0.062222798710151496 ~-0.05205727335094125 ~0.0710450838716594 226:-0.140625:1123:1124 ~-0.05674522830374565 "
    s .= "85:0.765625:1125:1126 ~-0.02998948908310838 167:0.234375:1127:1128 ~0.05540622735430221 ~-0.03839083940883315 248:0.375:1130:1153 244:0.91:1131:1136 53:-0.5:1132:1135 94:0.15625:1133:1134 ~0.0459669570803385 ~-0.05642430505751744 "
    s .= "~-0.051903609483930094 253:-0.024227642276423468:1137:1140 256:0.9433962264150944:1138:1139 ~0.0538119536659802 ~-0.10024961146209772 251:1.046875:1141:1150 130:1.046875:1142:1145 160:0.890625:1143:1144 ~-0.04174910685216079 "
    s .= "~0.013708835529931957 243:1.35:1146:1149 205:-0.421875:1147:1148 ~-0.06741668119842079 ~0.04395123731596873 ~-0.05996017878102941 142:-0.484375:1151:1152 ~-0.09916508198583163 ~0.04677324851356956 251:1.203125:1154:1167 "
    s .= "109:0.640625:1155:1156 ~-0.05278095034725913 211:-0.046875:1157:1158 ~-0.0546528719812453 248:0.875:1159:1166 166:0.234375:1160:1165 241:0.2:1161:1162 ~-0.0292047795460032 49:0.28125:1163:1164 ~0.06536376880717917 "
    s .= "~-0.059229871404895974 ~-0.034971142230886786 ~-0.04158713835101168 141:0.2109375:1168:1173 184:0.34375:1169:1170 ~-0.0391414242778447 184:1.5625:1171:1172 ~0.04217622372586935 ~-0.05983983715079666 191:0.15625:1174:1175 "
    s .= "~0.056572833029258585 ~-0.03748671020087099 248:0.375:1177:1202 244:0.85:1178:1183 232:0.734375:1179:1180 ~-0.058069983246141335 208:0.53125:1181:1182 ~0.07949135862367339 ~-0.058463074748943716 253:-0.02592592592592524:1184:1189 "
    s .= "28:0.796875:1185:1188 241:0.16:1186:1187 ~-0.018490534727056293 ~0.0536197898890122 ~-0.06496811779021198 251:0.546875:1190:1193 203:-0.71875:1191:1192 ~0.037593075351685656 ~-0.035186950469547666 50:0.3125:1194:1201 "
    s .= "28:0.625:1195:1200 142:-0.484375:1196:1197 ~-0.08600523288418192 85:0.375:1198:1199 ~0.019018285110275316 ~0.05144867188339624 ~-0.06596857860639302 ~-0.03842968453767257 251:1.171875:1203:1216 109:0.640625:1204:1205 "
    s .= "~-0.05191580948640051 232:-0.125:1206:1207 ~-0.05738574399388631 85:1.125:1208:1213 253:-0.04450757575757791:1209:1212 96:0.0859375:1210:1211 ~-0.0429013665330293 ~0.048660113881232425 ~-0.03525959299341059 252:0.125:1214:1215 "
    s .= "~-0.023875488839102073 ~0.058124096093013035 193:-0.203125:1217:1218 ~-0.05220879366511878 191:-0.078125:1219:1222 243:0.35:1220:1221 ~-0.04730724113789249 ~0.05377229369339273 ~-0.01900532271727466 248:0.625:1224:1251 "
    s .= "244:0.9:1225:1230 8:-0.484375:1226:1229 232:0.46875:1227:1228 ~-0.043084584514980234 ~0.047750098921901435 ~-0.05175112646854385 217:-0.140625:1231:1236 235:-0.28125:1232:1233 ~-0.05500830852707013 251:0.859375:1234:1235 "
    s .= "~-0.02346268699791662 ~0.03459635667948404 253:-0.04278074866310145:1237:1238 ~0.05359365379674472 26:0.09375:1239:1248 85:0.671875:1240:1245 255:0.328125:1241:1242 ~0.03212331369797662 98:-0.671875:1243:1244 "
    s .= "~0.027912568224998314 ~-0.04106561994108916 31:0.640625:1246:1247 ~0.050492469818212295 ~-0.03734413627558971 244:1.315:1249:1250 ~-0.05486975749852962 ~0.007748543926632025 251:0.671875:1252:1263 214:0.640625:1253:1258 "
    s .= "238:1.09375:1254:1255 ~-0.05622705789922834 245:1.8679245283018868:1256:1257 ~0.17904668687330594 ~-0.0553682353060769 139:1.078125:1259:1262 241:0.1:1260:1261 ~0.06826087972056379 ~-0.0534172626869063 ~0.056128123988171554 "
    s .= "226:-0.140625:1264:1265 ~-0.05460010395706595 194:0.171875:1266:1269 243:0.55:1267:1268 ~-0.02281160278236034 ~0.046672069932865524 ~-0.05215666258945228 248:0.625:1271:1298 244:0.855:1272:1273 ~-0.05056054987069393 "
    s .= "187:-0.265625:1274:1277 75:0.2421875:1275:1276 ~-0.05552654727246534 ~0.017720349784131097 253:-0.02592592592592524:1278:1287 157:-0.53125:1279:1280 ~-0.062104542078473005 243:0.45:1281:1284 205:0.34375:1282:1283 "
    s .= "~-0.03823856688545525 ~0.05553717921822119 256:0.9433962264150944:1285:1286 ~0.05322558050628384 ~-0.09648173662008154 77:-0.125:1288:1293 99:-0.0234375:1289:1292 157:0.8125:1290:1291 ~-0.0228029186801515 ~0.03392932631699021 "
    s .= "~0.045463738356606054 251:1.328125:1294:1297 133:0.671875:1295:1296 ~-0.060499336490317406 ~-0.010301163905174972 ~0.03390544580173317 251:0.671875:1299:1310 214:0.640625:1300:1305 238:1.09375:1301:1302 ~-0.05564925950693961 "
    s .= "245:1.8679245283018868:1303:1304 ~0.15806429788490065 ~-0.054801264882166495 139:1.078125:1306:1309 241:0.1:1307:1308 ~0.06257573993663339 ~-0.052709799420342346 ~0.05357153806918491 232:-0.15625:1311:1312 ~-0.053892326949522146 "
    s .= "194:0.21875:1313:1316 253:-0.04278074866310145:1314:1315 ~0.06015116516444307 ~-0.008261070811474319 ~-0.05455144547486084 248:0.375:1318:1345 244:0.85:1319:1324 232:0.734375:1320:1321 ~-0.056658202038808274 208:0.53125:1322:1323 "
    s .= "~0.07726869020764335 ~-0.057081828739949395 253:-0.02592592592592524:1325:1330 28:0.796875:1326:1329 243:0.45:1327:1328 ~0.011654989112295261 ~0.052641710531443536 ~-0.06369478437868312 251:1.171875:1331:1344 244:1.225:1332:1337 "
    s .= "220:0.890625:1333:1336 170:-1.046875:1334:1335 ~0.03090669945008824 ~-0.047336061985609974 ~0.0499779250497566 243:1.75:1338:1343 187:-0.15625:1339:1340 ~-0.04036314688135918 90:0.3984375:1341:1342 ~0.04273889817589014 "
    s .= "~-0.07794666796235974 ~-0.06470604814070861 ~0.04410003082266308 251:0.765625:1346:1351 211:0.625:1347:1348 ~-0.04704907293687256 160:1.21875:1349:1350 ~-0.04177341808066133 ~0.05141599163514715 253:-0.04278074866310145:1352:1357 "
    s .= "37:-0.28125:1353:1354 ~-0.05580342265580018 215:0.21875:1355:1356 ~0.0552870485998898 ~-0.028322803826482165 229:-0.078125:1358:1359 ~-0.052832872624038664 29:-0.0625:1360:1363 109:0.21875:1361:1362 ~-0.055615594925784356 "
    s .= "~0.03493337768329612 ~-0.04338184709839285 248:0.625:1365:1400 244:0.85:1366:1367 ~-0.05018754760559024 220:-0.125:1368:1375 251:0.859375:1369:1372 50:-0.78125:1370:1371 ~0.02020673680976604 ~-0.047786442348945676 "
    s .= "252:0.125:1373:1374 ~-0.03509420902228654 ~0.03865370677016952 253:-0.04278074866310145:1376:1381 243:0.45:1377:1380 184:0.75:1378:1379 ~-0.05283347228315628 ~0.057238026523608126 ~0.052188961404896705 26:0.125:1382:1397 "
    s .= "99:-0.0234375:1383:1392 157:0.8125:1384:1389 251:0.734375:1385:1386 ~-0.042722611892361734 118:-0.046875:1387:1388 ~-0.12666988268000826 ~0.027499368875147603 242:1.85:1390:1391 ~0.040349254178169064 ~-0.09654296315319284 "
    s .= "97:0.234375:1393:1394 ~0.04541702680487622 251:1.390625:1395:1396 ~-0.03430050644473821 ~0.04294740295574512 244:1.14:1398:1399 ~-0.06085103981935628 ~-0.0028777506312739325 109:0.65625:1401:1402 ~-0.05048530661005005 "
    s .= "249:1.8333333333333335:1403:1410 85:1.234375:1404:1407 251:2.140625:1405:1406 ~-0.027593363542927643 ~0.07423894095785177 40:-0.15625:1408:1409 ~-0.05347473556544723 ~0.05265550073007308 ~-0.05631578186765779 248:0.375:1412:1437 "
    s .= "244:0.98:1413:1424 166:0.1875:1414:1423 221:0.125:1415:1422 190:-0.078125:1416:1417 ~-0.043097638509051434 244:0.795:1418:1419 ~-0.05589456410853436 97:0.234375:1420:1421 ~0.05300548909993045 ~-0.05710875697525988 "
    s .= "~-0.053624435956930595 ~-0.06263964129385471 205:-0.25:1425:1426 ~-0.021769185858040843 256:0.9433962264150944:1427:1436 253:-0.011046253879119273:1428:1429 ~0.05105735033316762 243:2.25:1430:1435 243:0.25:1431:1432 "
    s .= "~-0.041692481955786675 28:0.625:1433:1434 ~0.03811653022528258 ~-0.03472943346417636 ~-0.06507279798616049 ~-0.0940365089753982 120:0.2421875:1438:1451 38:-0.625:1439:1444 85:1.234375:1440:1443 251:0.734375:1441:1442 "
    s .= "~-0.0472600471132911 ~0.02539348483579647 ~0.04897228544234249 249:0.16666666666666666:1445:1450 154:1.265625:1446:1449 251:0.765625:1447:1448 ~-0.045258502369731154 ~0.01785941518311895 ~0.061029914142496255 "
    s .= "~-0.047874445476320054 244:0.9:1452:1453 ~-0.050516529952242886 119:0.21875:1454:1457 248:0.875:1455:1456 ~0.05514550222434195 ~-0.021375287809151107 ~-0.043712078156349865 244:0.855:1459:1460 ~-0.0515002085742039 "
    s .= "249:1.5:1461:1502 253:-0.02592592592592524:1462:1477 243:0.45:1463:1466 205:0.34375:1464:1465 ~-0.04380007056605 ~0.05000161366271997 233:0.671875:1467:1476 28:0.875:1468:1475 256:0.9433962264150944:1469:1474 244:0.9:1470:1473 "
    s .= "76:0.15625:1471:1472 ~0.04585138851864129 ~-0.07657452729686595 ~0.05258392164047091 ~-0.08573540886690775 ~-0.05065899913133198 ~-0.07454011056116504 26:0:1478:1497 251:0.296875:1479:1482 160:1.21875:1480:1481 "
    s .= "~-0.043367273474487024 ~0.02279109334115921 85:0.578125:1483:1492 255:0.328125:1484:1489 162:0.3828125:1485:1488 248:0.875:1486:1487 ~0.04297002658734202 ~-0.03952541437964575 ~-0.06617526413824652 59:-0.4375:1490:1491 "
    s .= "~0.002576237661584652 ~-0.05780868474686324 187:-0.3125:1493:1494 ~-0.06866287671907348 73:0.5625:1495:1496 ~0.04981025990642558 ~-0.03330884486157146 244:1.62:1498:1499 ~-0.04199844977456984 167:-0.046875:1500:1501 "
    s .= "~0.05020683362823121 ~-0.022702362051298736 219:0.2578125:1503:1504 ~-0.05655412878502261 ~0.020352352155585583 248:0.375:1506:1531 244:0.98:1507:1518 166:0.1875:1508:1517 197:0.15625:1509:1516 190:-0.078125:1510:1511 "
    s .= "~-0.041960822928237704 97:0.234375:1512:1515 244:0.795:1513:1514 ~-0.05463557702496638 ~0.051647881995982595 ~-0.05913692795873117 ~-0.05469210002655997 ~-0.061663671881417595 253:-0.020229505523620725:1519:1520 "
    s .= "~0.04856931825281908 202:-0.140625:1521:1524 148:1.09375:1522:1523 ~-0.04590338153296738 ~0.04256184934011714 243:2.25:1525:1530 90:0.4921875:1526:1529 142:-0.375:1527:1528 ~-0.06972835823617886 ~0.035451386834494926 "
    s .= "~-0.06031582015279216 ~-0.05922744740411735 251:0.765625:1532:1543 109:0.609375:1533:1534 ~-0.05133131847643901 223:-0.0625:1535:1536 ~-0.05334128319865135 193:0.203125:1537:1542 85:0.53125:1538:1539 ~-0.0177609827379719 "
    s .= "193:-0.234375:1540:1541 ~-0.06153768711002325 ~0.058155947774461585 ~-0.0493986148324097 217:-0.15625:1544:1545 ~-0.04565079867317325 248:0.875:1546:1551 191:-0.0625:1547:1548 ~0.04967224127140926 224:0.0625:1549:1550 "
    s .= "~0.027888735519800596 ~-0.04506558152147258 ~-0.031021137373077053 244:0.855:1553:1554 ~-0.05043920796737942 249:1.5:1555:1596 253:-0.02592592592592524:1556:1571 243:0.45:1557:1562 205:0.34375:1558:1561 178:0.796875:1559:1560 "
    s .= "~-0.05887564201680467 ~0.055483642922648214 ~0.04849215062025357 233:0.671875:1563:1570 187:-0.34375:1564:1565 ~-0.0262587742278876 256:0.9433962264150944:1566:1569 28:0.96875:1567:1568 ~0.051113987282609886 "
    s .= "~-0.051136965657515604 ~-0.08485904361637059 ~-0.07159964712534542 26:0.046875:1572:1591 251:0.296875:1573:1578 160:1.21875:1574:1575 ~-0.04240714837158108 238:0.015625:1576:1577 ~-0.04596706613122368 ~0.05179587546944489 "
    s .= "85:0.71875:1579:1588 255:0.328125:1580:1585 162:0.3828125:1581:1584 187:-0.15625:1582:1583 ~-0.030409722553616205 ~0.0399030251031291 ~-0.047101833176756085 38:-0.46875:1586:1587 ~0.0050271173769207205 ~-0.05547500463997154 "
    s .= "28:0.625:1589:1590 ~0.04700354537750045 ~-0.04816087073944267 244:1.46:1592:1593 ~-0.0445207476034742 212:0.046875:1594:1595 ~0.031297245701738065 ~-0.034509802916825615 219:0.2578125:1597:1598 ~-0.05568712843642914 "
    s .= "~0.01936257833265964 244:0.855:1600:1605 232:0.71875:1601:1602 ~-0.05285874628772587 157:0.21875:1603:1604 ~0.061850477866030644 ~-0.0566737866128633 249:1.5:1606:1643 253:-0.02592592592592524:1607:1622 243:0.45:1608:1613 "
    s .= "205:0.34375:1609:1612 208:0.8125:1610:1611 ~-0.05653515630520376 ~0.057584884562023535 ~0.047058792068110554 233:0.671875:1614:1621 190:-0.25:1615:1618 256:0.13131313131313133:1616:1617 ~0.024284726500098174 ~-0.11216001722165003 "
    s .= "244:0.9:1619:1620 ~-0.0030043943620207372 ~0.05147072441102599 ~-0.06893284686576749 85:0.671875:1623:1636 248:0.875:1624:1635 50:0.09375:1625:1634 255:0.328125:1626:1631 235:-0.09375:1627:1628 ~-0.01546504170107222 "
    s .= "109:0.109375:1629:1630 ~-0.015872019067706314 ~0.04177546035653534 59:-0.578125:1632:1633 ~0.009387389237598845 ~-0.04533892401543876 ~-0.04216182316276835 ~-0.046865714674895934 28:0.625:1637:1642 208:-0.1875:1638:1639 "
    s .= "~-0.03198638898675741 87:0.5703125:1640:1641 ~0.04515522162849575 ~-0.05810514206387976 ~-0.05827716884319215 219:0.2578125:1644:1645 ~-0.05516810760352843 ~0.018457160179596855 244:0.855:1647:1652 232:0.71875:1648:1649 "
    s .= "~-0.05242663761568849 157:0.21875:1650:1651 ~0.05912814036840767 ~-0.05625759942663662 249:1.5:1653:1690 253:-0.04278074866310145:1654:1665 243:0.45:1655:1658 202:0.4375:1656:1657 ~-0.053301439377511896 ~0.0574722903276215 "
    s .= "31:0.84375:1659:1664 55:-0.4375:1660:1661 ~-0.02314376995793297 256:0.9433962264150944:1662:1663 ~0.050515697519978676 ~-0.08003749730715783 ~-0.04295196700051213 85:0.671875:1666:1683 248:0.875:1667:1682 98:-0.15625:1668:1675 "
    s .= "255:0.515625:1669:1672 147:-0.1796875:1670:1671 ~-0.026900944444262137 ~0.03604014360075738 62:-1.03125:1673:1674 ~0.0421558432312315 ~-0.04064932829332351 251:1.484375:1676:1681 255:0.265625:1677:1680 122:0.25:1678:1679 "
    s .= "~-0.0010143094480329956 ~-0.06048012376951402 ~-0.06492645419078358 ~0.027871973052290527 ~-0.046060974111206826 28:0.625:1684:1689 208:-0.25:1685:1686 ~-0.04040500887480687 87:0.5703125:1687:1688 ~0.04348831675515014 "
    s .= "~-0.05710464215220609 ~-0.051141028167536844 219:0.2578125:1691:1692 ~-0.05466174621010163 ~0.01759216705441916 244:0.855:1694:1699 232:0.71875:1695:1696 ~-0.05200607156018799 157:0.21875:1697:1698 ~0.056560667871149856 "
    s .= "~-0.055862519430338126 249:1.5:1700:1737 253:-0.04278074866310145:1701:1712 243:0.45:1702:1705 187:0.5:1703:1704 ~-0.052495457314332666 ~0.05607709498837821 190:-0.1875:1706:1711 256:0.13131313131313133:1707:1710 "
    s .= "245:1.8970588235294117:1708:1709 ~-0.08589302040288585 ~0.036854832035874176 ~-0.09937395831879227 ~0.04970177996295892 26:0.09375:1713:1734 251:0.234375:1714:1717 223:1.078125:1715:1716 ~-0.038823471404921484 ~0.0995936713491498 "
    s .= "85:0.71875:1718:1729 255:0.265625:1719:1722 248:0.875:1720:1721 ~0.03803921674012253 ~-0.02847289560785339 77:-0.5625:1723:1726 190:0:1724:1725 ~-0.0324338728884501 ~0.029386231465238583 244:1.9:1727:1728 ~-0.04542127019406167 "
    s .= "~0.024391888849456665 243:1.55:1730:1733 28:0.625:1731:1732 ~0.046123137248141814 ~-0.02757240765581122 ~-0.04896395423713573 251:1.328125:1735:1736 ~-0.04138266268886643 ~0.00635582078604453 219:0.2578125:1738:1739 "
    s .= "~-0.05416614771519116 ~0.01676592744696752 244:0.855:1741:1742 ~-0.04850290562612044 249:1.5:1743:1784 253:-0.04278074866310145:1744:1755 243:0.45:1745:1748 202:0.4375:1746:1747 ~-0.05053103836223727 ~0.056091882391751516 "
    s .= "31:0.84375:1749:1754 55:-0.4375:1750:1751 ~-0.023765717111041248 244:0.9:1752:1753 ~-0.0064997492446652845 ~0.050090334940188136 ~-0.04270999787429519 157:0.8125:1756:1775 99:0.2890625:1757:1770 190:-0.078125:1758:1759 "
    s .= "~-0.05649819560543562 251:0.828125:1760:1765 242:0.55:1761:1764 250:0.8671875:1762:1763 ~0.014968228747278406 ~-0.03152455553901207 ~-0.05466357875409864 124:-0.09375:1766:1767 ~-0.045338286979688225 11:0.3125:1768:1769 "
    s .= "~0.03076066861873124 ~-0.04313534728626232 243:0.25:1771:1772 ~-0.045360610366474347 97:0.484375:1773:1774 ~0.04115981738417579 ~-0.051818149435440476 28:0.5:1776:1783 214:-0.203125:1777:1778 ~-0.029157172675941114 "
    s .= "248:0.875:1779:1782 243:2.25:1780:1781 ~0.045282113928179345 ~-0.06687711715862425 ~-0.013413400474414059 ~-0.049182715135228594 219:0.2578125:1785:1786 ~-0.05367954973158517 ~0.01597683718068188 244:0.855:1788:1793 "
    s .= "232:0.71875:1789:1790 ~-0.05121796347862171 20:-0.640625:1791:1792 ~0.06106167220747963 ~-0.051827625370228336 249:1.5:1794:1831 253:-0.02592592592592524:1795:1808 243:0.45:1796:1801 184:0.75:1797:1800 208:0.421875:1798:1799 "
    s .= "~-0.05421620677128876 ~0.04148561907964638 ~0.05822082069302127 233:0.671875:1802:1807 187:-0.34375:1803:1804 ~-0.03000431411698981 256:0.9433962264150944:1805:1806 ~0.04701993185319796 ~-0.076970595650022 ~-0.06879061552982624 "
    s .= "50:0.09375:1809:1830 251:0.296875:1810:1815 160:1.21875:1811:1812 ~-0.041239308850455084 238:0.015625:1813:1814 ~-0.04487208127959194 ~0.04930576781530681 187:-0.3125:1816:1817 ~-0.057526319876696264 85:0.15625:1818:1823 "
    s .= "184:0.234375:1819:1820 ~-0.029359953749644646 244:1.07:1821:1822 ~-0.04288515323295532 ~0.038600176081479115 73:0.5625:1824:1827 243:1.45:1825:1826 ~0.03862204996919172 ~-0.021012108912221925 31:0.328125:1828:1829 "
    s .= "~0.025098425312467032 ~-0.07967900016918004 ~-0.032751970519355356 198:0.265625:1832:1833 ~-0.053043605761449564 ~0.017372742513594355 244:0.855:1835:1836 ~-0.04750933506626389 249:1.5:1837:1878 253:-0.04278074866310145:1838:1847 "
    s .= "243:0.45:1839:1842 187:0.5:1840:1841 ~-0.048849725872826745 ~0.05388063438439437 190:-0.1875:1843:1846 256:0.13131313131313133:1844:1845 ~0.022875391177600186 ~-0.09706481038347478 ~0.047766735146291886 85:1.15625:1848:1871 "
    s .= "251:1.265625:1849:1864 190:-0.046875:1850:1851 ~-0.04803911476302175 163:1.140625:1852:1863 220:0.890625:1853:1862 244:1.085:1854:1855 ~-0.039915519825973245 109:0.265625:1856:1857 ~-0.04093091363236115 146:0.296875:1858:1861 "
    s .= "254:1.078125:1859:1860 ~0.034349798671030676 ~-0.02470258459302337 ~-0.06299223115387106 ~0.049337019793481124 ~0.042062964538744446 241:0.48:1865:1868 184:0.046875:1866:1867 ~-0.056560591971824926 ~0.012338829544552317 "
    s .= "31:0.5625:1869:1870 ~0.047627667149286186 ~-0.12114576717729131 211:-0.28125:1872:1873 ~-0.0459643703577404 87:0.5703125:1874:1877 55:1.984375:1875:1876 ~0.0450852251145056 ~-0.08157738232283801 ~-0.06855202577644168 "
    s .= "219:0.2578125:1879:1880 ~-0.05274178340191108 ~0.014866136594137722 249:0.5:1882:1909 244:0.84:1883:1888 232:0.5625:1884:1885 ~-0.053828376349657904 166:0.015625:1886:1887 ~0.07194251351799578 ~-0.053974268024116416 "
    s .= "253:-0.023114581505527098:1889:1896 1:0.859375:1890:1895 55:-0.359375:1891:1892 ~-0.021625028122869195 241:0.16:1893:1894 ~-0.04645717259241689 ~0.047630079941581895 ~-0.05842636071779364 26:0.203125:1897:1908 "
    s .= "187:-0.3125:1898:1899 ~-0.05759710375898108 251:0.203125:1900:1901 ~-0.0332061947059499 255:0.296875:1902:1903 ~0.04039996689690968 8:-0.390625:1904:1905 ~0.029922767621656233 254:1.046875:1906:1907 ~-0.010982431034189194 "
    s .= "~-0.06652146863103207 ~-0.0369128471374433 251:1.109375:1910:1921 109:0.78125:1911:1912 ~-0.04911652827798535 211:-0.03125:1913:1914 ~-0.05136354901652919 244:1.21:1915:1918 251:0.828125:1916:1917 ~-0.04357262986400933 "
    s .= "~0.030304630431910513 245:2.95:1919:1920 ~0.047000590781169034 ~-0.025747280342329912 181:-0.140625:1922:1923 ~-0.049816805630666566 222:0.2578125:1924:1927 11:-0.265625:1925:1926 ~0.028218226525572928 ~-0.035269434465999366 "
    s .= "~0.04440078774497127 244:0.855:1929:1936 214:1.40625:1930:1935 127:0.9375:1931:1932 ~-0.05074970008331014 130:0.1875:1933:1934 ~0.06851296770341743 ~-0.054022600545960524 ~0.1004906282422115 249:1.5:1937:1972 "
    s .= "253:-0.04278074866310145:1938:1947 49:0.71875:1939:1946 243:0.45:1940:1943 202:0.4375:1941:1942 ~-0.046293272789472255 ~0.05630576451548393 233:0.671875:1944:1945 ~0.04572626953691272 ~-0.06515121147589335 ~-0.03966796838548349 "
    s .= "157:0.8125:1948:1963 99:0.2734375:1949:1958 190:-0.078125:1950:1951 ~-0.05428019395534818 190:0.203125:1952:1957 106:0.4375:1953:1954 ~-0.02817521547032628 214:-0.125:1955:1956 ~-0.06322300873897262 ~0.03034902618237268 "
    s .= "~-0.033636982801621376 243:0.25:1959:1960 ~-0.0441670692373325 98:0.25:1961:1962 ~0.04076777914230184 ~-0.03324912000916895 28:0.5:1964:1971 214:-0.203125:1965:1966 ~-0.027549461989231024 248:0.875:1967:1970 243:2.25:1968:1969 "
    s .= "~0.04269175316333638 ~-0.06562945010102349 ~-0.012102773684827896 ~-0.047433906419732635 192:0.2109375:1973:1974 ~-0.052008707630772005 ~0.014904027178654187 244:0.855:1976:1985 232:0.71875:1977:1982 190:0.890625:1978:1979 "
    s .= "~-0.05157781385481572 136:-0.21875:1980:1981 ~0.24301130460115428 ~-0.05083369814307747 157:0.21875:1983:1984 ~0.05469846938637307 ~-0.054203288545911145 249:1.8333333333333335:1986:2019 253:-0.04278074866310145:1987:1998 "
    s .= "243:0.45:1988:1991 187:0.5:1989:1990 ~-0.04701352235507186 ~0.05247860883584994 190:-0.1875:1992:1997 256:0.13131313131313133:1993:1996 245:1.9012345679012346:1994:1995 ~-0.0890729790073651 ~0.03122484153643744 "
    s .= "~-0.09665056961004531 ~0.0460036410008595 98:-0.140625:1999:2012 195:-0.0703125:2000:2005 85:1.234375:2001:2004 163:1.25:2002:2003 ~-0.03083368409309037 ~0.04261762557373554 ~0.0377186968995848 73:0.5625:2006:2011 "
    s .= "255:0.328125:2007:2008 ~0.04394848704707163 95:-0.421875:2009:2010 ~0.03450272409611293 ~-0.038469154251437813 ~-0.04751735776571395 255:0.265625:2013:2018 26:0.265625:2014:2017 190:-0.0625:2015:2016 ~-0.03505929028322549 "
    s .= "~0.02455713580872946 ~-0.03766581914369216 ~-0.044783393239597076 252:0.575:2020:2021 ~-0.05341363344521277 ~0.03619911794140426 249:0.5:2023:2054 244:0.84:2024:2029 232:0.5625:2025:2026 ~-0.05314809002271671 "
    s .= "166:0.015625:2027:2028 ~0.06765844728692577 ~-0.05319609924795502 253:-0.02592592592592524:2030:2037 1:0.859375:2031:2036 55:-0.359375:2032:2033 ~-0.023863670162701023 241:0.16:2034:2035 ~-0.0436747405402949 ~0.0463524265727106 "
    s .= "~-0.05775895405376307 26:0.203125:2038:2053 187:-0.3125:2039:2040 ~-0.0564580065781689 251:0.296875:2041:2044 112:1.1875:2042:2043 ~-0.03579443219121609 ~0.03294594670719897 193:0.546875:2045:2052 255:0.546875:2046:2049 "
    s .= "90:0.5546875:2047:2048 ~0.037515099194829225 ~-0.0588997607568395 14:-0.609375:2050:2051 ~0.02993409881743645 ~-0.05376178528966498 ~-0.06638597305577379 ~-0.03487300565279705 251:1.234375:2055:2066 109:0.78125:2056:2057 "
    s .= "~-0.04789339289786828 238:-0.078125:2058:2059 ~-0.05134413179843093 96:0.0703125:2060:2063 194:-0.421875:2061:2062 ~0.01168346215343922 ~-0.05068490247321579 95:0.265625:2064:2065 ~0.04542923045488277 ~-0.037948927879703775 "
    s .= "220:-0.21875:2067:2068 ~-0.041776514879198506 ~0.030073355354285448 244:0.855:2070:2071 ~-0.045442053644722716 249:1.8333333333333335:2072:2113 253:-0.04278074866310145:2073:2082 190:-0.125:2074:2077 109:0.671875:2075:2076 "
    s .= "~-0.05632915218389947 ~0.022149077522514826 243:0.45:2078:2081 211:0.59375:2079:2080 ~-0.04174256090417433 ~0.05861998013598683 ~0.045383044616818614 85:1.15625:2083:2108 251:1.296875:2084:2101 190:-0.046875:2085:2086 "
    s .= "~-0.04659852995469393 114:0.3203125:2087:2100 249:0.5:2088:2097 211:0.25:2089:2094 236:0.21875:2090:2093 243:0.25:2091:2092 ~-0.043055233424083905 ~0.03789665026563585 ~-0.04443617248661662 112:1.71875:2095:2096 "
    s .= "~-0.03437516405057466 ~0.04479612654256334 55:-0.5625:2098:2099 ~0.12039035191521244 ~-0.032003155000156 ~-0.056314734888245566 241:0.48:2102:2105 184:0.5:2103:2104 ~-0.02900993190010903 ~0.044475611674580987 31:0.5625:2106:2107 "
    s .= "~0.04546013523925638 ~-0.11212114707630925 202:-0.109375:2109:2110 ~-0.027537001153487718 87:0.5703125:2111:2112 ~0.04198167382374073 ~-0.06631663723767155 252:0.575:2114:2115 ~-0.05285273554948642 ~0.03515688296017339 "
    s .= "244:0.845:2117:2120 214:1.40625:2118:2119 ~-0.047317910230537906 ~0.090440316684461 249:1.5:2121:2160 253:-0.055855855855857804:2122:2131 119:0.125:2123:2126 244:0.9:2124:2125 ~-0.023176725896222758 ~0.04675127318779014 "
    s .= "220:-0.15625:2127:2128 ~-0.06891099918423883 242:0.45:2129:2130 ~-0.07055662834812301 ~0.030532211144524125 85:0.671875:2132:2153 251:1.578125:2133:2152 163:1.140625:2134:2151 220:0.890625:2135:2148 242:0.45:2136:2143 "
    s .= "248:0.875:2137:2142 50:0.078125:2138:2141 254:1.109375:2139:2140 ~0.026952550513057255 ~-0.02504884124898867 ~-0.048979482036843304 ~-0.04818544021049348 184:0.8125:2144:2145 ~-0.05037879490750178 124:0.015625:2146:2147 "
    s .= "~-0.06335592062206855 ~0.033082613913333635 127:0.375:2149:2150 ~-0.05685589274323393 ~0.06691687349632905 ~0.032571192046217896 ~0.028224699053224268 28:0.625:2154:2159 208:-0.203125:2155:2156 ~-0.026865922602693704 "
    s .= "87:0.5703125:2157:2158 ~0.03936021647611094 ~-0.05309596272183569 ~-0.04783230791175031 195:0.2109375:2161:2162 ~-0.05112757469612551 ~0.011760613926773958 249:0.5:2164:2187 244:0.82:2165:2166 ~-0.04752988290772205 "
    s .= "253:-0.011046253879119273:2167:2172 212:0.375:2168:2171 49:0.71875:2169:2170 ~0.0424779670298668 ~-0.044291310833340786 ~-0.021440212630736383 243:1.45:2173:2186 29:0.28125:2174:2185 187:-0.3125:2175:2176 ~-0.05365035705966801 "
    s .= "251:0.171875:2177:2180 115:-0.203125:2178:2179 ~0.12940476286091837 ~-0.05278726660227258 255:0.234375:2181:2182 ~0.04124567633529124 26:-0.375:2183:2184 ~0.030442895146598675 ~-0.030071368337113755 ~-0.03986898374050129 "
    s .= "~-0.04323390778893526 251:1.109375:2188:2203 235:0.015625:2189:2190 ~-0.05002569457380895 244:1.08:2191:2196 103:-0.390625:2192:2195 241:0.1:2193:2194 ~0.2023354765468327 ~-0.0513944614264518 ~-0.04726162298539133 "
    s .= "142:-0.0625:2197:2198 ~-0.058061812108606975 245:2.95:2199:2202 184:-0.015625:2200:2201 ~-0.057525445708994954 ~0.050312157655658746 ~-0.030815283194173024 178:-0.171875:2204:2205 ~-0.049089886582827987 152:0.5:2206:2209 "
    s .= "195:0.1484375:2207:2208 ~0.00006731285747555662 ~0.04415706940518636 ~-0.044355494594888856 244:0.845:2211:2216 232:0.734375:2212:2215 190:0.890625:2213:2214 ~-0.05130226292733148 ~0.06277047143737116 ~0.0007400573585006836 "
    s .= "249:1.8333333333333335:2217:2254 253:-0.055855855855857804:2218:2223 119:0.125:2219:2220 ~0.043288135416763115 247:0.421875:2221:2222 ~0.023203526767915292 ~-0.04750923714892482 238:-0.0625:2224:2231 27:0.375:2225:2230 "
    s .= "105:-0.8515625:2226:2227 ~0.04503162303166232 205:1.1875:2228:2229 ~-0.04430306032250863 ~0.04035744255756468 ~0.01946649435647964 85:0.671875:2232:2249 248:0.875:2233:2242 50:0.09375:2234:2241 255:0.234375:2235:2238 "
    s .= "244:0.85:2236:2237 ~0.2888155530475185 ~0.03624655034557928 101:-0.453125:2239:2240 ~0.0208246436165654 ~-0.02670076677371727 ~-0.031174975488960407 166:0.625:2243:2246 46:1.171875:2244:2245 ~-0.053323569197946535 "
    s .= "~0.11698355453841221 139:0.328125:2247:2248 ~0.16547644170752585 ~-0.05347442787289741 28:0.484375:2250:2253 243:1.95:2251:2252 ~0.04151096487378827 ~-0.08715488276190858 ~-0.03958371787525869 252:0.575:2255:2256 "
    s .= "~-0.05209181586752673 ~0.032300208633745726 251:0.765625:2258:2289 249:0.5:2259:2278 143:0.140625:2260:2277 28:0.25:2261:2276 85:0.71875:2262:2273 205:0.59375:2263:2270 112:1.1875:2264:2269 255:0.234375:2265:2268 "
    s .= "255:0.171875:2266:2267 ~-0.020945984440427723 ~0.04897381592588539 ~-0.040254469970982414 ~0.03508129778814146 22:0.09375:2271:2272 ~0.0639507275845204 ~-0.043645522214879245 28:-0.34375:2274:2275 ~-0.03045342330931182 "
    s .= "~0.047221273878765485 ~-0.03611644118782862 ~-0.04098862854175477 235:0.015625:2279:2280 ~-0.05288488820584734 244:1.21:2281:2286 103:-0.390625:2282:2285 241:0.1:2283:2284 ~0.18438198292870403 ~-0.05288730294706833 "
    s .= "~-0.04569369599255152 184:0:2287:2288 ~-0.05636293450433885 ~0.03737568068052712 248:0.875:2290:2303 256:0.9583333333333334:2291:2302 249:1.1666666666666665:2292:2299 245:4.658536585365853:2293:2298 233:0.671875:2294:2297 "
    s .= "187:-0.328125:2295:2296 ~-0.026997873706689674 ~0.04003989590980614 ~-0.05253580487666898 ~-0.14983410580909148 192:0.1171875:2300:2301 ~-0.04757641138656183 ~0.02141712606383346 ~-0.057177093366253956 ~-0.03205854297678103 "
    s .= "244:0.84:2305:2306 ~-0.04515374577433652 217:-0.140625:2307:2314 198:0.21875:2308:2311 104:-1.578125:2309:2310 ~0.05335390644176612 ~-0.04402036336347681 28:0.25:2312:2313 ~0.03138403283191277 ~-0.05589396192576105 "
    s .= "248:0.875:2315:2348 253:-0.04278074866310145:2316:2325 163:-0.28125:2317:2320 208:-0.09375:2318:2319 ~-0.11573960831210926 ~0.018809544977615996 244:0.9:2321:2324 76:0.15625:2322:2323 ~0.03960620083831881 ~-0.07003106901883997 "
    s .= "~0.04387753172816053 26:0.265625:2326:2347 97:0.21875:2327:2338 243:1.55:2328:2335 255:0.234375:2329:2330 ~0.04363860805623938 26:-0.375:2331:2332 ~0.0334210327784989 244:1.29:2333:2334 ~-0.05577307834759743 ~0.007801350940363006 "
    s .= "12:0.1171875:2336:2337 ~-0.07368506925100678 ~0.0280382454239234 251:0.546875:2339:2344 1:-0.234375:2340:2343 94:0.171875:2341:2342 ~0.10291155725917467 ~-0.07859065893827094 ~-0.06073293545998834 142:-0.28125:2345:2346 "
    s .= "~-0.0973684584593479 ~0.01507144651358914 ~-0.03648388933333886 223:0.90625:2349:2350 ~-0.032390183593803766 ~0.04421812419866309 244:0.84:2352:2355 214:1.40625:2353:2354 ~-0.04607145367067602 ~0.0786793849713206 "
    s .= "211:-0.234375:2356:2361 240:0.484375:2357:2360 17:-0.71875:2358:2359 ~0.00879225298734557 ~-0.04910481687226188 ~0.031159189135402356 248:0.875:2362:2395 85:0.71875:2363:2386 251:1.015625:2364:2379 77:0.03125:2365:2376 "
    s .= "255:0.265625:2366:2369 97:0.25:2367:2368 ~0.03586257746108229 ~-0.05906757023045242 85:0.296875:2370:2375 26:-0.34375:2371:2374 229:0.109375:2372:2373 ~-0.017733374884731427 ~0.044136010624470166 ~-0.03677719347661673 "
    s .= "~-0.0496299817709026 180:-0.0703125:2377:2378 ~0.01927727929462166 ~-0.05453847067565626 243:0.6499999999999999:2380:2383 242:0.55:2381:2382 ~0.0184043397628507 ~-0.06529573432764686 238:0.53125:2384:2385 ~0.04474387623020106 "
    s .= "~-0.1126884652905551 97:0.765625:2387:2394 245:4.658536585365853:2388:2393 243:0.45:2389:2390 ~-0.025199144532955672 243:1.95:2391:2392 ~0.044829064519220606 ~-0.030966277140404792 ~-0.21180023674867493 ~-0.03138738461512298 "
    s .= "219:0.3984375:2396:2397 ~-0.03407248459483833 ~0.03385573334212924 26:-0.109375:2399:2430 27:-0.03125:2400:2415 109:1.171875:2401:2410 238:-0.1875:2402:2403 ~-0.05313348320663999 244:1.085:2404:2407 55:1.359375:2405:2406 "
    s .= "~-0.044655764356492045 ~0.081907436418018 109:0.234375:2408:2409 ~-0.029106547561508413 ~0.02348717003321603 202:-0.28125:2411:2412 ~-0.046417323150092914 108:0.2734375:2413:2414 ~0.032621245701434626 ~-0.07963098242390204 "
    s .= "253:-0.023114581505527098:2416:2419 130:2.453125:2417:2418 ~0.04613666815400972 ~-0.09459952221076741 85:0.71875:2420:2429 109:0.109375:2421:2422 ~-0.04365911076838922 52:0.359375:2423:2428 255:0.234375:2424:2425 "
    s .= "~0.04198948577161771 119:-0.34375:2426:2427 ~0.019915123315126376 ~-0.031251552579686884 ~-0.04714129351194326 ~0.036776681508925886 251:1.015625:2431:2438 244:1.285:2432:2433 ~-0.042591406159019435 235:-0.109375:2434:2435 "
    s .= "~-0.048043265404375694 85:0.71875:2436:2437 ~-0.018578028430416418 ~0.02945423695676352 241:0.58:2439:2442 146:-0.078125:2440:2441 ~0.01770397485276162 ~-0.049429923999206024 7:0.359375:2443:2444 ~0.03754792349544673 "
    s .= "~-0.050750849534447806 249:0.5:2446:2469 244:0.795:2447:2448 ~-0.05231448593182693 253:-0.02592592592592524:2449:2456 1:0.859375:2450:2455 55:-0.359375:2451:2452 ~-0.030244902129044616 241:0.16:2453:2454 ~-0.04285323663419176 "
    s .= "~0.04200024674499174 ~-0.05786665319198388 187:-0.3125:2457:2458 ~-0.05420550559664224 191:-0.015625:2459:2468 254:1.265625:2460:2465 193:0.546875:2461:2464 243:0.35:2462:2463 ~-0.0011825974758813312 ~0.038204166498288304 "
    s .= "~-0.0406212701393977 35:-0.546875:2466:2467 ~0.01010580213869255 ~-0.061553682758901974 ~-0.014137488114490511 251:0.796875:2470:2485 235:0.015625:2471:2472 ~-0.051866324991901296 244:1.21:2473:2480 241:0.1:2474:2479 "
    s .= "73:-0.140625:2475:2478 229:0.0625:2476:2477 ~0.21282471947115625 ~-0.025471679698104127 ~-0.031445183448619816 ~-0.04724824694738171 88:-0.109375:2481:2482 ~-0.060201492309756535 244:1.66:2483:2484 ~0.04771753715237645 "
    s .= "~-0.05649820985585651 196:-0.078125:2486:2489 198:0.265625:2487:2488 ~-0.0494704884431173 ~0.01590085129607567 50:0.03125:2490:2491 ~0.03153973843232726 ~-0.02297855595726042 244:0.84:2493:2494 ~-0.04355427630025747 "
    s .= "220:-0.140625:2495:2504 99:0.2421875:2496:2503 77:-0.984375:2497:2498 ~0.026592013788371283 55:0.359375:2499:2500 ~-0.05109580627905635 244:1.685:2501:2502 ~-0.039428490872134424 ~0.04842026048437551 ~0.021314511156594378 "
    s .= "253:-0.04278074866310145:2505:2516 243:0.45:2506:2509 202:0.4375:2507:2508 ~-0.04571277255345463 ~0.04816886422806879 163:-0.265625:2510:2513 208:-0.1875:2511:2512 ~-0.11521235634848698 ~0.017135017969622492 244:0.9:2514:2515 "
    s .= "~-0.015629048710205044 ~0.04396808777555225 29:-0.125:2517:2530 73:0.5625:2518:2529 254:1.265625:2519:2526 205:-0.25:2520:2521 ~-0.05757944732718054 195:-0.0546875:2522:2523 ~0.007450274571372358 178:-0.0625:2524:2525 "
    s .= "~-0.02136435157394151 ~0.04213346113533637 71:-0.578125:2527:2528 ~0.019385105051308887 ~-0.05332240985777026 ~-0.03460135250283263 255:0.265625:2531:2536 26:0.265625:2532:2535 109:0.109375:2533:2534 ~-0.039959191184425 "
    s .= "~0.022116386756440218 ~-0.03321240795818885 251:1.421875:2537:2538 ~-0.05076608186279679 ~0.010039825816187568 249:0.5:2540:2571 244:0.795:2541:2542 ~-0.05206686529098767 253:-0.02592592592592524:2543:2548 119:0.25:2544:2547 "
    s .= "245:4.054054054054054:2545:2546 ~0.040033061490868646 ~-0.1392183552194437 ~-0.009573743428620418 187:-0.3125:2549:2550 ~-0.05335042904503115 239:0.25:2551:2570 251:0.296875:2552:2561 52:0.171875:2553:2560 250:0.8984375:2554:2559 "
    s .= "46:-0.15625:2555:2558 199:0.234375:2556:2557 ~-0.009318258186323997 ~0.17741669583378075 ~0.009636560682949056 ~-0.04065613611933874 ~-0.057829212979116765 193:0.546875:2562:2569 255:0.546875:2563:2566 90:0.5546875:2564:2565 "
    s .= "~0.03270836846577939 ~-0.06846898576629278 14:-0.609375:2567:2568 ~0.025358770334206433 ~-0.05262031197254205 ~-0.0600237740359473 ~-0.03001047952315681 251:1.234375:2572:2583 235:0:2573:2574 ~-0.04760839769369103 "
    s .= "244:1.07:2575:2580 103:-0.390625:2576:2579 241:0.1:2577:2578 ~0.13952631147850925 ~-0.048748663264758484 ~-0.0441353206725202 184:-0.015625:2581:2582 ~-0.05364320580900276 ~0.024656477107074484 220:-0.1875:2584:2585 "
    s .= "~-0.03404425354281481 ~0.025512637893008967 26:-0.109375:2587:2618 27:-0.03125:2588:2605 109:1.171875:2589:2600 214:-0.1875:2590:2591 ~-0.0544924419016162 245:2.1058823529411765:2592:2595 220:0.96875:2593:2594 "
    s .= "~-0.04214778245662628 ~0.0640232368567923 174:-0.078125:2596:2597 ~-0.01760334865789842 63:0.1484375:2598:2599 ~0.04068405111258869 ~-0.09288043140540987 199:-0.171875:2601:2602 ~-0.035531708735406974 108:0.2734375:2603:2604 "
    s .= "~0.032892106828241216 ~-0.079205546426776 253:-0.023114581505527098:2606:2607 ~0.04361595966756992 85:0.71875:2608:2617 109:0.109375:2609:2610 ~-0.042438214763629106 52:0.359375:2611:2616 255:0.234375:2612:2613 "
    s .= "~0.03961174876160922 159:0.0390625:2614:2615 ~0.019509080349928983 ~-0.030748409283631206 ~-0.045986799739890186 ~0.034638138227059544 251:1.015625:2619:2626 244:1.285:2620:2621 ~-0.0410643694881381 238:-0.15625:2622:2623 "
    s .= "~-0.05325919548244451 252:0.125:2624:2625 ~-0.021634852093533143 ~0.02618436691701644 241:0.58:2627:2630 146:-0.078125:2628:2629 ~0.01691831015125942 ~-0.04773345412219823 7:0.359375:2631:2632 ~0.03585245194755537 "
    s .= "~-0.04863161226049373 244:0.84:2634:2635 ~-0.04246682918365125 211:-0.234375:2636:2639 213:0.4609375:2637:2638 ~-0.042496464292314365 ~0.029005156484138952 85:0.71875:2640:2669 27:0.390625:2641:2664 190:-0.046875:2642:2647 "
    s .= "202:0.546875:2643:2646 115:-0.53125:2644:2645 ~0.07464047789870869 ~-0.051119158022424886 ~0.033271195917850965 160:0.9375:2648:2661 220:0.890625:2649:2658 181:0.84375:2650:2657 217:0.203125:2651:2656 145:-0.125:2652:2653 "
    s .= "~-0.0560858631567769 109:0.109375:2654:2655 ~-0.046986524561742314 ~0.007777048722877446 ~-0.04369643015975758 ~0.03739958449428293 106:0.296875:2659:2660 ~-0.05242811071647161 ~0.06897945134022583 176:-0.203125:2662:2663 "
    s .= "~0.041592635345359875 ~-0.007251320437589862 28:0.40625:2665:2668 143:0.109375:2666:2667 ~0.04541283495445868 ~-0.013926867865951166 ~-0.06937041780307708 97:0.46875:2670:2677 245:4.658536585365853:2671:2676 "
    s .= "243:2.1500000000000004:2672:2675 37:0.6875:2673:2674 ~0.0410062913221559 ~-0.010268762587973409 ~-0.047214210818340416 ~-0.16010613095651224 251:0.671875:2678:2679 ~-0.05289677883936435 ~0.011322338973283769 249:0.5:2681:2710 "
    s .= "244:0.795:2682:2683 ~-0.05176981585501955 28:0.265625:2684:2703 243:0.35:2685:2688 184:0.265625:2686:2687 ~-0.037241912704073676 ~0.023905846492521518 191:-0.03125:2689:2696 243:2.05:2690:2695 103:2.484375:2691:2694 "
    s .= "193:0.46875:2692:2693 ~0.043235140101585766 ~-0.00996448954394661 ~-0.1276596765639828 ~-0.03559776637564719 40:-0.265625:2697:2698 ~-0.06186729766877681 241:0.42:2699:2702 59:0.03125:2700:2701 ~0.01164554509523033 "
    s .= "~-0.0607023491458972 ~0.0285785813464383 251:0.578125:2704:2707 238:1.203125:2705:2706 ~-0.05711724569711869 ~0.0519993105689904 35:0.28125:2708:2709 ~0.019828987039307005 ~-0.051132694952421044 219:0.1796875:2711:2718 "
    s .= "38:-0.671875:2712:2715 248:0.875:2713:2714 ~0.021701284124313148 ~-0.04248380245418268 75:0.1953125:2716:2717 ~-0.046712218339659384 ~-0.004417158982255762 244:0.955:2719:2724 52:-0.59375:2720:2723 223:0.0625:2721:2722 "
    s .= "~-0.04255948811966291 ~0.23460423622455764 ~-0.052817879370491067 181:-0.046875:2725:2726 ~-0.03114824863287324 ~0.03271666702310017 251:0.609375:2728:2749 244:1.21:2729:2742 31:0.078125:2730:2741 12:0.2421875:2731:2738 "
    s .= "250:0.9609375:2732:2737 235:-0.09375:2733:2734 ~-0.05621315749188155 130:0.5625:2735:2736 ~-0.028661381609934252 ~0.0312023502370785 ~-0.04958877889928526 135:0.1953125:2739:2740 ~0.041857655179333604 ~-0.04450128851288664 "
    s .= "~-0.04949346857755745 202:-0.09375:2743:2744 ~-0.04991922058437445 109:0.109375:2745:2746 ~-0.04716501359271989 193:0.25:2747:2748 ~0.034955815939937386 ~-0.02748833257981296 248:0.375:2750:2763 256:0.9583333333333334:2751:2762 "
    s .= "28:0.796875:2752:2761 245:4.658536585365853:2753:2760 109:0.59375:2754:2759 251:1.421875:2755:2756 ~-0.013364464470295115 54:-0.0859375:2757:2758 ~-0.06488829014406976 ~0.04632000618929286 ~0.03957425587072098 "
    s .= "~-0.13977598991614207 ~-0.05321553298715745 ~-0.06529039587260686 226:-0.171875:2764:2765 ~-0.04411365204922839 191:-0.046875:2766:2771 255:0.328125:2767:2768 ~0.0407752145136461 146:-0.609375:2769:2770 ~0.031192877651919207 "
    s .= "~-0.03113390442288265 224:0.109375:2772:2773 ~0.0033143514631557586 ~-0.045079708362182364 26:-0.109375:2775:2804 27:-0.03125:2776:2793 109:1.171875:2777:2790 238:-0.1875:2778:2779 ~-0.05106256684520614 "
    s .= "245:2.1058823529411765:2780:2785 130:1.078125:2781:2782 ~-0.046674749480845094 131:-0.375:2783:2784 ~-0.03839582718121101 ~0.07187067393131441 166:0.390625:2786:2789 109:0.28125:2787:2788 ~-0.01762861345802846 "
    s .= "~0.04104820474584961 ~-0.03408638320268172 199:-0.0625:2791:2792 ~-0.025277167908022088 ~0.029866831657345178 253:-0.024227642276423468:2794:2795 ~0.04226443830582774 85:0.71875:2796:2803 109:0.109375:2797:2798 "
    s .= "~-0.04080299333279566 52:0.359375:2799:2802 255:0.234375:2800:2801 ~0.037666627569043376 ~-0.0018060679895436664 ~-0.044569740593781104 ~0.03219538891087636 244:0.925:2805:2806 ~-0.04525340033685517 252:0.275:2807:2814 "
    s .= "235:0:2808:2809 ~-0.05007741346045466 146:0.296875:2810:2813 254:0.796875:2811:2812 ~0.01956789117886857 ~-0.03814670098507603 ~-0.05737240762234707 31:0.40625:2815:2820 226:-0.234375:2816:2817 ~-0.046826285029397646 "
    s .= "255:0.328125:2818:2819 ~0.038251152150613456 ~-0.025071441996480412 ~-0.05577588393690824 249:0.5:2822:2851 244:0.795:2823:2824 ~-0.051495443885115344 253:-0.06290174471992445:2825:2828 212:0.375:2826:2827 ~0.03945379759728318 "
    s .= "~-0.02393181173992659 28:0.28125:2829:2846 191:-0.015625:2830:2845 243:0.35:2831:2838 175:0.453125:2832:2835 112:1.40625:2833:2834 ~-0.04742510816567527 ~0.03205078153520257 112:0.234375:2836:2837 ~0.10127424037999427 "
    s .= "~-0.013121445481532877 243:2.05:2839:2844 193:0.53125:2840:2843 187:-0.171875:2841:2842 ~-0.012596294785192167 ~0.040477226828485625 ~-0.03649626328965921 ~-0.06138179103843952 ~-0.008911419109565366 251:1.140625:2847:2850 "
    s .= "244:1.66:2848:2849 ~-0.04720267399284062 ~0.013284664950408524 ~0.012309803126766774 195:0.1328125:2852:2859 60:0.1484375:2853:2854 ~-0.04230658314146865 37:0.0625:2855:2858 80:0.125:2856:2857 ~0.03355711618658214 "
    s .= "~-0.03915197744625798 ~-0.04514173765994989 244:0.91:2860:2863 214:0.859375:2861:2862 ~-0.051294885589923594 ~0.09651531239196842 122:0.515625:2864:2867 172:-0.171875:2865:2866 ~-0.022483898983895228 ~0.031772655457402176 "
    s .= "~-0.044743811206639346 251:0.609375:2869:2894 244:1.21:2870:2887 46:0.09375:2871:2886 12:0.2421875:2872:2883 235:-0.09375:2873:2874 ~-0.05449447743985389 250:0.9609375:2875:2882 130:0.546875:2876:2877 ~-0.03391003667459429 "
    s .= "91:0.25:2878:2879 ~-0.0042143892792684 91:0.359375:2880:2881 ~0.16178859609131271 ~0.03050083576066459 ~-0.043035398295936396 77:0.046875:2884:2885 ~0.0380343552169461 ~-0.04282354594287356 ~-0.04934878490040556 "
    s .= "202:-0.09375:2888:2889 ~-0.04886196754293217 109:0.109375:2890:2891 ~-0.046213777911626445 193:0.25:2892:2893 ~0.033082355291399544 ~-0.02640148180212559 248:0.375:2895:2906 256:0.9583333333333334:2896:2905 28:0.796875:2897:2904 "
    s .= "245:4.658536585365853:2898:2903 109:0.59375:2899:2902 48:-0.0078125:2900:2901 ~-0.03621224572944128 ~0.02517565028405677 ~0.03810215657233647 ~-0.13133961623217794 ~-0.050076523831161894 ~-0.0642996302064154 "
    s .= "226:-0.171875:2907:2908 ~-0.04294646920577676 191:-0.046875:2909:2912 141:-0.1484375:2910:2911 ~-0.015223436531408202 ~0.03372536361191722 224:0.109375:2913:2914 ~0.003333576298073258 ~-0.04366028236406622 26:-0.109375:2916:2943 "
    s .= "27:-0.03125:2917:2928 214:-0.203125:2918:2919 ~-0.04603731142074452 109:0.609375:2920:2925 163:1.65625:2921:2924 220:1.015625:2922:2923 ~-0.03815379907497568 ~0.05849693194858816 ~0.03762522281230909 118:0.546875:2926:2927 "
    s .= "~0.02646902810350789 ~-0.023539841924762273 253:-0.024227642276423468:2929:2930 ~0.04088563099736342 97:0.234375:2931:2940 248:0.875:2932:2937 162:0.3671875:2933:2936 196:-0.015625:2934:2935 ~-0.004417339053405838 "
    s .= "~0.03670014630187433 ~-0.045461801174970375 166:0.265625:2938:2939 ~-0.0506366492194352 ~0.034107948257708305 252:0.07500000000000001:2941:2942 ~-0.057535903691460125 ~0.007346756530199745 244:0.925:2944:2945 "
    s .= "~-0.04417996563364117 252:0.275:2946:2953 235:0:2947:2948 ~-0.049206451965019986 146:0.296875:2949:2952 254:0.796875:2950:2951 ~0.018280783010411337 ~-0.03690200426105099 ~-0.05614280828355808 31:0.40625:2954:2961 "
    s .= "220:-0.171875:2955:2956 ~-0.0348502382182218 254:1.078125:2957:2960 243:2.25:2958:2959 ~0.038401603700228576 ~-0.056407906829750346 ~-0.06948912888643581 ~-0.053271842981425045 249:0.5:2963:2990 244:0.795:2964:2965 "
    s .= "~-0.05125746171201304 49:0.734375:2966:2989 253:-0.06290174471992445:2967:2970 119:0.25:2968:2969 ~0.04149390966662587 ~-0.0036181716529040393 243:2.25:2971:2988 2:0.3125:2972:2987 255:0.234375:2973:2978 254:0.484375:2974:2975 "
    s .= "~0.02201149183594739 244:0.855:2976:2977 ~0.23054551575922055 ~0.04479037056625787 26:-0.375:2979:2984 190:0:2980:2983 181:0.078125:2981:2982 ~-0.054029524499284734 ~0.020141421685140732 ~0.0292882044936527 254:1.046875:2985:2986 "
    s .= "~-0.008418709902221844 ~-0.05799381097652358 ~-0.033768830051428896 ~-0.06900767654144963 ~-0.04547549206209016 195:0.1328125:2991:3002 17:-0.625:2992:2995 248:0.875:2993:2994 ~0.018230429856165725 ~-0.040090499011586046 "
    s .= "120:0.1328125:2996:2997 ~-0.04793763123613488 196:-0.09375:2998:2999 ~-0.056370925296260435 50:0.03125:3000:3001 ~0.03334914521277003 ~-0.039415721454553375 244:0.91:3003:3006 214:0.859375:3004:3005 ~-0.05076251490506617 "
    s .= "~0.08742165852983619 122:0.515625:3007:3008 ~0.02416913394742451 ~-0.043354863836945694 251:0.765625:3010:3037 244:1.18:3011:3026 46:0.078125:3012:3025 211:-0.078125:3013:3014 ~-0.05099397188509347 145:0.1875:3015:3024 "
    s .= "8:0.09375:3016:3023 105:-0.0390625:3017:3020 85:0.671875:3018:3019 ~-0.05285153618369701 ~0.035203559114002886 88:-0.015625:3021:3022 ~-0.023566142564901253 ~0.05327557032208557 ~-0.04002219577922924 ~-0.038250757626732114 "
    s .= "~-0.04583586704892942 235:0:3027:3032 249:0.5:3028:3031 22:0.109375:3029:3030 ~0.011904204228725762 ~-0.05490592569055456 ~-0.046550427451433715 178:-0.09375:3033:3034 ~-0.05077701400267664 193:0.265625:3035:3036 "
    s .= "~0.0322347302484667 ~-0.01103437864716704 248:0.875:3038:3055 109:0.5625:3039:3046 251:1.328125:3040:3043 47:-0.125:3041:3042 ~-0.0020163261347488823 ~-0.05010935403745329 243:0.6499999999999999:3044:3045 ~-0.029457612585478094 "
    s .= "~0.034080757657573686 238:-0.078125:3047:3050 23:-0.1875:3048:3049 ~0.0250149603847448 ~-0.022637111849512188 243:2.25:3051:3054 103:2.484375:3052:3053 ~0.041075479909592705 ~-0.09158560212079571 ~-0.1222975161127974 "
    s .= "~-0.025604032018735408 244:0.815:3057:3062 190:0.890625:3058:3059 ~-0.04745071701588427 136:0.078125:3060:3061 ~0.1350004054864383 ~-0.04796701667889147 196:-0.234375:3063:3066 20:-0.828125:3064:3065 ~0.021307529214480328 "
    s .= "~-0.041015537131889 253:-0.06161616161616242:3067:3076 163:-0.265625:3068:3069 ~-0.03657944378841835 238:0.53125:3070:3075 250:0.6640625:3071:3074 245:2.627906976744186:3072:3073 ~-0.0944374618694427 ~0.01928593658420369 "
    s .= "~0.03968074226130592 ~-0.03945719950474374 251:1.203125:3077:3098 154:1.140625:3078:3095 190:-0.078125:3079:3080 ~-0.048957485778586225 254:1.265625:3081:3092 26:0.25:3082:3091 31:0.078125:3083:3086 109:0.15625:3084:3085 "
    s .= "~-0.046308652437787416 ~0.031021135408353093 251:0.484375:3087:3088 ~-0.040541918010711976 242:1.15:3089:3090 ~0.025056447695811765 ~-0.07309007821907158 ~-0.041879195225376406 2:-0.96875:3093:3094 ~0.027766070326560505 "
    s .= "~-0.05402992195075751 121:0.34375:3096:3097 ~0.031120081864111276 ~-0.03177465260795476 243:0.35:3099:3100 ~-0.032049159301159404 243:2.25:3101:3102 ~0.030561433344225106 ~-0.07540449052887525 26:-0.109375:3104:3133 "
    s .= "51:-0.0078125:3105:3120 190:-0.328125:3106:3107 ~-0.05587672103235852 244:1.08:3108:3113 163:0.09375:3109:3112 187:-0.046875:3110:3111 ~-0.04529477981291055 ~0.03926956529308431 ~-0.0420561493181976 108:0.2421875:3114:3119 "
    s .= "109:0.28125:3115:3116 ~-0.023679830615766038 238:-0.1875:3117:3118 ~-0.019759648711993545 ~0.029785063146395868 ~-0.08236150160203971 253:-0.023114581505527098:3121:3122 ~0.03931022519642943 181:0.078125:3123:3128 "
    s .= "243:0.75:3124:3127 190:0:3125:3126 ~-0.07101899161704907 ~-0.01059586846034919 ~0.027752546188601963 73:0.46875:3129:3132 244:0.82:3130:3131 ~-0.04971153700835709 ~0.027772513002208305 ~-0.04963948922309144 244:0.925:3134:3135 "
    s .= "~-0.042817932900504056 46:-0.25:3136:3137 ~-0.049208528527690254 252:0.32499999999999996:3138:3145 235:0:3139:3140 ~-0.04482796771375028 146:0.296875:3141:3144 58:-0.4375:3142:3143 ~-0.06188940372937726 ~0.016685844986840195 "
    s .= "~-0.05179120349290889 31:0.40625:3146:3149 255:0.328125:3147:3148 ~0.035925185478284605 ~-0.020033989812750726 ~-0.049100260483722596 249:0.5:3151:3176 244:0.795:3152:3153 ~-0.050955298145980016 49:0.71875:3154:3175 "
    s .= "191:0.09375:3155:3168 255:0.234375:3156:3161 254:0.484375:3157:3158 ~0.027760300460353583 244:0.855:3159:3160 ~0.19253084645880755 ~0.05101267704638886 14:-0.609375:3162:3163 ~0.031215771605770833 254:1.296875:3164:3167 "
    s .= "244:0.99:3165:3166 ~-0.03736163164327774 ~0.013436394707102907 ~-0.04663262442701052 251:0.578125:3169:3170 ~-0.03888477875596685 248:0.375:3171:3174 232:0.390625:3172:3173 ~0.02995807449062933 ~-0.05859373492708882 "
    s .= "~-0.03118677285564335 ~-0.04328556267608812 219:0.1328125:3177:3184 17:-0.609375:3178:3181 248:0.875:3179:3180 ~0.017529433774844366 ~-0.04036722522151646 96:0.0859375:3182:3183 ~-0.04979320747868365 ~-0.019481020832407644 "
    s .= "244:0.935:3185:3190 241:0.1:3186:3189 245:2:3187:3188 ~-0.04823756549088675 ~0.12204247225523018 ~-0.05328155307726623 53:0.046875:3191:3194 202:-0.109375:3192:3193 ~-0.04072201471795978 ~0.03749281245339296 184:0.5625:3195:3196 "
    s .= "~-0.04567047630315029 ~0.021495630341262287 251:0.671875:3198:3223 235:-0.078125:3199:3202 244:1.445:3200:3201 ~-0.050512382609349406 ~-0.009174636574030861 25:0.203125:3203:3218 245:1.5731707317073171:3204:3205 "
    s .= "~-0.05868185081798785 109:0.109375:3206:3207 ~-0.03803357462576337 52:0.265625:3208:3217 2:0.03125:3209:3216 255:0.234375:3210:3211 ~0.047414781404074124 17:-0.640625:3212:3213 ~0.04169622058844995 46:0.078125:3214:3215 "
    s .= "~0.01182629591721985 ~-0.03700659430329065 ~-0.011669417667589237 ~-0.03723369579403673 244:1.21:3219:3220 ~-0.05128456008826168 244:1.235:3221:3222 ~0.08660786439870338 ~-0.02527520310913515 187:-0.3125:3224:3225 "
    s .= "~-0.04073225560657922 212:0.4375:3226:3243 255:0.265625:3227:3234 196:-0.265625:3228:3229 ~-0.02040974692707299 14:0.609375:3230:3233 245:3.603448275862069:3231:3232 ~0.04219702024868385 ~-0.042693357278968586 "
    s .= "~-0.04524555503736261 50:-0.65625:3235:3236 ~0.03517454007182402 254:1.046875:3237:3240 244:0.955:3238:3239 ~-0.04696714601644057 ~0.01703347832356705 247:0.171875:3241:3242 ~-0.021775402892951073 ~-0.0809266118823278 "
    s .= "~-0.03179889126489296 244:0.815:3245:3252 190:0.890625:3246:3249 127:0.9375:3247:3248 ~-0.05112277440022864 ~0.03651377199197493 136:0.078125:3250:3251 ~0.12036088312757734 ~-0.046950266742167936 217:-0.140625:3253:3258 "
    s .= "17:-0.78125:3254:3255 ~0.022515220626709406 195:0.1953125:3256:3257 ~-0.04357215997587793 ~0.006231120592907894 253:-0.055855855855857804:3259:3268 252:0.125:3260:3267 26:-0.03125:3261:3266 99:-0.1328125:3262:3265 "
    s .= "107:-0.65625:3263:3264 ~0.004178678074574833 ~-0.11628351110951739 ~0.03801997225987942 ~-0.06594370017294482 ~0.03790936214950497 26:0.265625:3269:3290 255:0.265625:3270:3279 251:0.203125:3271:3274 110:0.265625:3272:3273 "
    s .= "~-0.03994569136329507 ~0.07507005763176935 254:0.703125:3275:3276 ~0.018488791722985485 244:0.855:3277:3278 ~0.18630608519728323 ~0.046341695989732874 26:-0.375:3280:3285 162:0.3046875:3281:3284 248:0.875:3282:3283 "
    s .= "~0.019101921281411423 ~-0.021059454151153133 ~-0.0580697062391704 244:1.21:3286:3287 ~-0.053689131398443946 254:1.234375:3288:3289 ~0.006119872530921819 ~-0.06179988810838747 ~-0.031703825783806164 109:0.609375:3292:3309 "
    s .= "251:1.578125:3293:3306 47:-0.125:3294:3305 168:0.0546875:3295:3298 163:1.203125:3296:3297 ~-0.032412660062554 ~0.022656142682006792 217:0.5625:3299:3304 253:-0.020229505523620725:3300:3303 118:0.1875:3301:3302 "
    s .= "~0.046709800202087794 ~-0.05890009591806847 ~-0.013314232882719702 ~0.0777696107437224 ~-0.0402406230858138 138:-0.0546875:3307:3308 ~-0.04555441393723456 ~0.0313284406935966 238:-0.1875:3310:3317 244:1.9:3311:3314 "
    s .= "232:-0.09375:3312:3313 ~-0.04895522507916155 ~-0.0034390215156478105 28:-0.1875:3315:3316 ~-0.05663638795684026 ~0.051823826235027716 253:-0.055855855855857804:3318:3321 166:0.4375:3319:3320 ~0.041576299716307025 "
    s .= "~-0.006074478017941135 181:-0.125:3322:3323 ~-0.04283937582791248 251:0.984375:3324:3337 193:0.265625:3325:3336 244:1.21:3326:3331 255:0.296875:3327:3330 254:0.671875:3328:3329 ~-0.02061763865099142 ~0.05272907417274847 "
    s .= "~-0.0452966000961833 109:0.828125:3332:3333 ~0.0760722178956959 187:0.03125:3334:3335 ~-0.016176765714311835 ~0.03216247070244581 ~-0.034646166154853206 ~0.03305592209158572 187:-0.203125:3339:3340 ~-0.037058860140154214 "
    s .= "244:0.815:3341:3346 136:-0.46875:3342:3343 ~0.08513391220830892 127:0.9375:3344:3345 ~-0.05098456880602084 ~0.024224711416990945 248:0.875:3347:3382 49:0.34375:3348:3375 191:0.59375:3349:3374 245:4.054054054054054:3350:3373 "
    s .= "255:0.265625:3351:3358 249:1.5:3352:3357 251:0.203125:3353:3356 237:0.1953125:3354:3355 ~-0.040859263665424174 ~0.04019155761594626 ~0.037517321273927116 ~-0.02697104500271784 38:-0.625:3359:3360 ~0.034399989459721274 "
    s .= "244:1.29:3361:3368 254:1.296875:3362:3367 5:-0.359375:3363:3364 ~0.015160252058856058 251:1.484375:3365:3366 ~-0.04632761886862942 ~0.03810836900036288 ~-0.06770223133820455 247:0.328125:3369:3370 ~0.022447317234451435 "
    s .= "251:2.328125:3371:3372 ~-0.0873781599458544 ~0.052329954302378 ~-0.07581079405498233 ~-0.04438958145839339 251:0.765625:3376:3377 ~-0.04372238183451124 142:-0.28125:3378:3379 ~-0.08933873292790137 26:-0.234375:3380:3381 "
    s .= "~0.035553343783646184 ~-0.02556106926639692 219:0.1796875:3383:3384 ~-0.03332516244025167 ~0.011256223553487698 26:-0.109375:3386:3419 205:-0.28125:3387:3390 15:0.3359375:3388:3389 ~-0.04810032846651951 ~0.014986523349884737 "
    s .= "109:0.609375:3391:3406 168:0.0546875:3392:3397 195:0.1640625:3393:3394 ~-0.03444741986827165 242:1.25:3395:3396 ~0.020705531947362337 ~-0.07618529330575854 238:0.125:3398:3401 196:-0.046875:3399:3400 ~-0.013006273898684055 "
    s .= "~0.039063843542293454 244:1.09:3402:3405 238:0.8125:3403:3404 ~-0.06521641849439282 ~0.054393974947589886 ~0.016287933919372544 251:0.234375:3407:3408 ~-0.029569309985464837 255:0.515625:3409:3414 245:4.658536585365853:3410:3413 "
    s .= "187:-0.328125:3411:3412 ~-0.03142948450672314 ~0.03891209753562383 ~-0.09675486908009694 35:-0.609375:3415:3416 ~0.027956793913220857 85:1.265625:3417:3418 ~-0.05228963581326104 ~0.008880152995676684 "
    s .= "249:0.16666666666666666:3420:3427 31:0.1875:3421:3426 146:0.25:3422:3425 243:2.25:3423:3424 ~0.03310700831686835 ~-0.04704066491104078 ~-0.01859019200781066 ~-0.03480874747074478 120:0.1640625:3428:3429 ~-0.041690892169997815 "
    s .= "244:0.955:3430:3431 ~-0.04322625055382118 ~0.013135104754717273 251:0.671875:3433:3456 235:-0.078125:3434:3437 244:1.42:3435:3436 ~-0.05004036170636033 ~-0.008357594279058278 31:0.078125:3438:3451 109:0.171875:3439:3440 "
    s .= "~-0.036357163558864286 46:0.078125:3441:3448 10:-0.265625:3442:3443 ~-0.02039877440497795 1:0.1875:3444:3447 190:-0.078125:3445:3446 ~-0.016314667400666616 ~0.0464221398542376 ~-0.06715860367165857 202:0.0625:3449:3450 "
    s .= "~0.016785555717898477 ~-0.05376251996213968 112:0.78125:3452:3453 ~-0.04238295265323071 103:0.546875:3454:3455 ~0.025827631635686205 ~-0.04574203434746347 191:-0.046875:3457:3470 187:-0.3125:3458:3459 ~-0.03384502475304381 "
    s .= "109:0.53125:3460:3465 48:-0.0234375:3461:3462 ~-0.031160522116569736 136:1.875:3463:3464 ~0.024280800778584022 ~-0.08302161603876597 118:-0.671875:3466:3467 ~-0.05320660675616003 34:0.90625:3468:3469 ~0.035981592802181 "
    s .= "~-0.03984971760613701 243:0.75:3471:3474 3:-0.0234375:3472:3473 ~0.003605244203325032 ~-0.045270355004724316 43:-0.1875:3475:3476 ~-0.047194828591670006 244:0.98:3477:3478 ~-0.030409675203521575 ~0.02969461592671571 "
    s .= "249:0.5:3480:3509 244:0.795:3481:3482 ~-0.050519161930991874 253:-0.06290174471992445:3483:3486 119:0.125:3484:3485 ~0.03735147295359563 ~-0.0015346210667416377 124:-0.28125:3487:3488 ~-0.04152758857760241 193:0.484375:3489:3508 "
    s .= "190:-0.03125:3490:3499 181:0.15625:3491:3496 241:0.48:3492:3495 136:-0.0625:3493:3494 ~0.021943401689397353 ~-0.06994590682547651 ~0.014780368651037747 10:0.171875:3497:3498 ~0.02922271556647818 ~-0.05606817640615863 "
    s .= "251:0.484375:3500:3507 112:1.046875:3501:3506 79:0.109375:3502:3505 196:0:3503:3504 ~-0.06125338981937526 ~0.04188566137715719 ~-0.04589897489767908 ~0.03235912256200746 ~0.028999816299051396 ~-0.030954527654392845 "
    s .= "196:-0.078125:3510:3511 ~-0.041557597173556796 244:0.91:3512:3515 157:-0.4375:3513:3514 ~0.08487953897221545 ~-0.04828628984414646 120:0.0546875:3516:3521 146:-0.390625:3517:3520 195:-0.1796875:3518:3519 ~-0.033472583873026526 "
    s .= "~0.026798174173950667 ~-0.041684138987633235 50:0.03125:3522:3523 ~0.03768895326435375 192:0.3046875:3524:3525 ~-0.04837264413783195 ~0.025245446953806025 187:-0.28125:3527:3528 ~-0.04254162759374103 244:0.815:3529:3534 "
    s .= "202:-0.3125:3530:3533 196:0:3531:3532 ~-0.04784781436328217 ~0.06959546897905061 ~-0.05081607833879277 253:-0.055855855855857804:3535:3542 37:-0.28125:3536:3537 ~-0.026549198333794957 250:0.6640625:3538:3539 "
    s .= "~-0.018409086489464568 241:0.22:3540:3541 ~-0.016545244075680268 ~0.0368331043521197 238:-0.078125:3543:3550 2:-0.078125:3544:3549 142:-0.03125:3545:3548 199:-0.046875:3546:3547 ~-0.027016464577521906 ~0.03474198480791259 "
    s .= "~-0.031489135984909565 ~-0.045729671507529844 157:0.8125:3551:3566 147:-0.1640625:3552:3553 ~-0.03532921306051278 170:0.34375:3554:3565 113:0.5:3555:3564 162:0.1640625:3556:3559 146:0.015625:3557:3558 ~0.01927023715731771 "
    s .= "~-0.02298336785341587 55:-0.59375:3560:3561 ~0.13799814526515583 85:1.34375:3562:3563 ~-0.04988269422574315 ~0.035847116340863426 ~0.04328271219608259 ~-0.038095230680615 73:0.46875:3567:3572 248:0.875:3568:3571 "
    s .= "133:2.453125:3569:3570 ~0.033736684843893264 ~-0.07134986496314218 ~-0.019938358772396688 ~-0.03552097891732924 251:0.671875:3574:3601 214:-0.0625:3575:3578 244:1.57:3576:3577 ~-0.04783159193914058 ~0.00014711260894714672 "
    s .= "31:0.125:3579:3594 109:0.171875:3580:3581 ~-0.03425936600001472 46:0.078125:3582:3587 46:-0.25:3583:3584 ~-0.02464743152242696 115:0.203125:3585:3586 ~0.012767256645272455 ~0.047041819438729426 202:0.09375:3588:3591 "
    s .= "193:-0.0625:3589:3590 ~-0.054617263459308577 ~0.03737025942965139 85:1.15625:3592:3593 ~-0.06488356083763515 ~0.023438298133277784 244:1.19:3595:3596 ~-0.04601562853991282 112:0.375:3597:3598 ~-0.055220618498613684 "
    s .= "67:0.546875:3599:3600 ~0.03194002472750184 ~-0.07038545710629655 212:0.4375:3602:3619 187:-0.3125:3603:3604 ~-0.03410961555021769 255:0.265625:3605:3612 136:2.015625:3606:3611 142:-0.5:3607:3608 ~-0.0518339757012827 "
    s .= "14:0.609375:3609:3610 ~0.037978198198130926 ~-0.04488987388325468 ~-0.04141547834011013 50:-0.65625:3613:3614 ~0.03187948760784739 254:1.046875:3615:3618 194:-0.140625:3616:3617 ~0.021541163924749345 ~-0.020036051956909398 "
    s .= "~-0.03696422978358551 ~-0.03090719741401986 26:0.109375:3621:3658 27:0.046875:3622:3647 235:-0.1875:3623:3626 105:-0.7734375:3624:3625 ~0.02549979588029479 ~-0.04660645416033274 157:0.8125:3627:3642 220:0.96875:3628:3641 "
    s .= "245:1.7403846153846154:3629:3630 ~-0.05107060610399793 55:0.703125:3631:3640 242:0.55:3632:3637 1:-0.34375:3633:3634 ~0.05734993547715061 238:1.09375:3635:3636 ~-0.01890724206300115 ~0.13462368204604852 85:0.53125:3638:3639 "
    s .= "~-0.06038218876026347 ~-0.011376777036019754 ~0.024880789726270357 ~0.0547911481785922 31:0.484375:3643:3646 159:0.3203125:3644:3645 ~0.025696329679668808 ~-0.07598055490064899 ~-0.041662996268162944 "
    s .= "253:-0.024227642276423468:3648:3649 ~0.03427595785235913 251:0.984375:3650:3655 159:0.1640625:3651:3654 96:0.2734375:3652:3653 ~-0.008741635340385814 ~0.03880189423705023 ~-0.03973391066033115 243:0.35:3656:3657 "
    s .= "~-0.02971123520081875 ~0.031388925613046056 244:0.955:3659:3660 ~-0.047837946640376085 142:-0.1875:3661:3662 ~-0.058301392696292635 241:0.56:3663:3666 161:-0.140625:3664:3665 ~0.023917423959431763 ~-0.038351998700999146 "
    s .= "~0.01353276178134204 217:-0.125:3668:3677 35:-0.765625:3669:3672 157:0.953125:3670:3671 ~-0.023347853858021433 ~0.05170940371788151 251:0.671875:3673:3674 ~-0.048101753608900434 46:-0.125:3675:3676 ~-0.04644617524647991 "
    s .= "~0.002414054614699768 109:0.609375:3678:3699 242:1.15:3679:3694 251:0.765625:3680:3691 43:0.265625:3681:3690 109:0.109375:3682:3683 ~-0.038912665540862576 55:0.078125:3684:3687 214:-0.03125:3685:3686 ~-0.03578007622480648 "
    s .= "~0.05071664459855601 112:0.671875:3688:3689 ~-0.04642487149165497 ~0.048195692100058286 ~-0.06235550245673258 133:1.796875:3692:3693 ~0.023477804560506136 ~-0.06432898394214052 55:0.828125:3695:3698 139:0.8125:3696:3697 "
    s .= "~-0.06455810976560968 ~0.028450747212689132 ~0.023271529793982112 217:0.25:3700:3709 245:4.658536585365853:3701:3708 163:-0.265625:3702:3703 ~-0.043428935317672265 248:1.125:3704:3707 111:0.5234375:3705:3706 ~0.032203898107605745 "
    s .= "~-0.06497168822079871 ~-0.026952170783420853 ~-0.11931708262382108 251:1.265625:3710:3713 112:1.4375:3711:3712 ~-0.0412302262298635 ~0.010587371330892086 ~0.029753425230129672 249:0.5:3715:3736 191:0.09375:3716:3729 "
    s .= "255:0.234375:3717:3722 254:0.484375:3718:3721 251:0.296875:3719:3720 ~-0.022317709039711794 ~0.025187321575376266 ~0.05162402173240663 98:-0.515625:3723:3724 ~0.02033097436963748 85:1.15625:3725:3728 251:1.359375:3726:3727 "
    s .= "~-0.033802053053417845 ~0.01652614906309358 ~0.014505313252049632 251:0.578125:3730:3731 ~-0.04029505692055963 248:0.375:3732:3735 191:0.65625:3733:3734 ~0.023487674611524966 ~-0.04596163977350084 ~-0.03382009818094151 "
    s .= "196:-0.078125:3737:3742 137:-1.703125:3738:3739 ~0.09026832204241725 192:0.3984375:3740:3741 ~-0.04913055893105617 ~0.0013304686326983239 244:0.91:3743:3746 157:-0.4375:3744:3745 ~0.07561670353835087 ~-0.04730650423381254 "
    s .= "120:0.0546875:3747:3754 146:-0.390625:3748:3753 1:-0.421875:3749:3750 ~0.07539584583790832 17:-0.640625:3751:3752 ~0.022678693093839634 ~-0.03267945925602964 ~-0.04004557685924354 50:0.03125:3755:3758 246:-0.859375:3756:3757 "
    s .= "~-0.03052729321093586 ~0.04174407999746848 231:0.2265625:3759:3760 ~-0.05146235164675689 ~0.018764690100356942 187:-0.203125:3762:3763 ~-0.03312909711423759 85:0.671875:3764:3791 74:0.109375:3765:3788 255:0.234375:3766:3771 "
    s .= "254:0.703125:3767:3770 168:0.0859375:3768:3769 ~-0.01314541593499692 ~0.021524087612251816 ~0.04596105262278686 122:-0.296875:3772:3787 158:-0.25:3773:3782 245:2.3333333333333335:3774:3779 157:-0.0625:3775:3776 "
    s .= "~0.029242336907796297 244:1.455:3777:3778 ~-0.05332272275498933 ~0.02460764615792062 90:0.1328125:3780:3781 ~0.025473305076436525 ~-0.0699402178973713 119:-0.453125:3783:3784 ~0.06036864062849534 199:0.5:3785:3786 "
    s .= "~-0.02398858499744524 ~0.06126607427699368 ~-0.033007169127537574 251:1.390625:3789:3790 ~-0.044556708719319264 ~0.010820120934710194 208:-0.203125:3792:3795 23:-0.703125:3793:3794 ~0.028101152124797663 ~-0.04983891218689922 "
    s .= "70:0.46875:3796:3805 245:4.277777777777778:3797:3804 25:0.71875:3798:3803 232:-0.0625:3799:3802 186:0.5234375:3800:3801 ~0.014848351604966295 ~-0.20912314750360764 ~0.03850500963419329 ~-0.029302688034034376 ~-0.07317643762643813 "
    s .= "169:0.0625:3806:3807 ~0.01208857400211874 ~-0.04983984635300994 244:0.815:3809:3812 190:0.890625:3810:3811 ~-0.0457511555414466 ~0.0468782983977181 187:-0.3125:3813:3814 ~-0.040188173121960435 253:-0.055855855855857804:3815:3826 "
    s .= "55:-0.234375:3816:3821 123:0.2578125:3817:3820 248:0.125:3818:3819 ~0.029608666028363942 ~-0.06409208504912839 ~0.048202289185559945 244:0.955:3822:3825 255:0.265625:3823:3824 ~0.024329078622729636 ~-0.06193280056002625 "
    s .= "~0.0339972951723941 238:-0.078125:3827:3832 146:-0.15625:3828:3831 142:-0.0625:3829:3830 ~0.015607965292811561 ~-0.0300903946432291 ~-0.04102273932958379 142:-0.15625:3833:3834 ~-0.032809764623449235 70:0.609375:3835:3854 "
    s .= "159:0.5078125:3836:3853 85:0.671875:3837:3850 205:0.703125:3838:3849 55:-0.578125:3839:3840 ~0.10488271752616887 121:0.671875:3841:3848 251:1.578125:3842:3847 163:1.140625:3843:3846 46:0.765625:3844:3845 ~-0.023646934080085235 "
    s .= "~0.07124491273423955 ~0.03331600098267276 ~0.03179604236007025 ~0.05687978285878201 ~0.04655062867064666 160:-0.15625:3851:3852 ~-0.06286805029886104 ~0.032396877995395194 ~-0.05815843308498406 ~-0.027686777157961046 "
    s .= "251:0.484375:3856:3877 244:1.21:3857:3870 55:0.09375:3858:3869 211:-0.015625:3859:3860 ~-0.045643270820523094 145:0.109375:3861:3866 133:0.734375:3862:3865 250:1.0546875:3863:3864 ~0.05204220451931431 ~-0.04658105241269941 "
    s .= "~-0.022706020088063203 97:0.5625:3867:3868 ~-0.055487990605522466 ~0.08350349941957073 ~-0.05035686039935753 202:-0.09375:3871:3872 ~-0.05420062512388975 109:0.109375:3873:3874 ~-0.053390301870420556 193:0.25:3875:3876 "
    s .= "~0.029287908887953757 ~-0.019480963000901665 14:-0.625:3878:3881 109:0.53125:3879:3880 ~0.0020165801092235825 ~0.036920091713865025 255:0.328125:3882:3897 249:0.8333333333333333:3883:3894 191:0.59375:3884:3893 "
    s .= "245:3.7777777777777777:3885:3892 256:0.9583333333333334:3886:3891 46:-0.21875:3887:3890 119:-0.09375:3888:3889 ~0.02507008901210649 ~-0.03982779118627794 ~0.032205999139961694 ~-0.05784206067815383 ~-0.07483331526217588 "
    s .= "~-0.042228905428785934 141:0.1484375:3895:3896 ~-0.03582564914329637 ~0.010728883743945324 247:0.296875:3898:3901 254:1.296875:3899:3900 ~-0.0006821429226896358 ~-0.03875326532627364 ~-0.06946864698109585 2:0.0625:3903:3936 "
    s .= "75:0.0546875:3904:3921 214:-0.1875:3905:3908 239:-0.953125:3906:3907 ~0.03341425935960059 ~-0.04431997392067269 249:0.16666666666666666:3909:3912 70:0.40625:3910:3911 ~0.023218088094779286 ~-0.0304401729794639 "
    s .= "127:0.1875:3913:3918 109:0.1875:3914:3915 ~-0.03732848231993694 149:-0.34375:3916:3917 ~0.03780770389242897 ~-0.011337360339811493 245:1.7413793103448276:3919:3920 ~-0.06993917483624937 ~-0.017028481604772924 "
    s .= "253:-0.0218253968253966:3922:3927 250:0.6953125:3923:3926 88:0.71875:3924:3925 ~-0.05747383099054154 ~0.04736117702658679 ~0.03551016664907524 254:1.296875:3928:3935 159:0.5078125:3929:3934 67:0.015625:3930:3933 "
    s .= "95:-0.4375:3931:3932 ~0.02439682219153262 ~-0.026775760148101804 ~0.023831701870132088 ~-0.06580245592245006 ~-0.03595308553089874 251:1.328125:3937:3944 244:1.21:3938:3939 ~-0.04467518706839798 79:0.375:3940:3941 "
    s .= "~-0.03362156705390115 229:-0.171875:3942:3943 ~-0.05337255870808201 ~0.025258166228381885 241:0.46:3945:3948 192:0.4296875:3946:3947 ~-0.06410246327091783 ~0.03575203504827978 ~0.02764124147526133 217:-0.15625:3950:3957 "
    s .= "77:-0.765625:3951:3954 157:0.953125:3952:3953 ~-0.02878795571132785 ~0.05123980845596319 198:0.328125:3955:3956 ~-0.03994833565918085 ~0.008180511917354963 85:0.71875:3958:3983 74:0.109375:3959:3978 168:0.0546875:3960:3969 "
    s .= "249:0.16666666666666666:3961:3962 ~0.009975382356430581 127:0.203125:3963:3968 118:-0.0625:3964:3965 ~-0.05757596659427642 109:0.1875:3966:3967 ~-0.04574215305391785 ~0.028843159012021405 ~-0.04017939234815588 158:-0.25:3970:3975 "
    s .= "55:-0.578125:3971:3972 ~0.10309895354396166 160:0.875:3973:3974 ~-0.03804552115147915 ~0.03130721300326699 10:-0.203125:3976:3977 ~-0.030150237044403824 ~0.03447729825086582 190:0.828125:3979:3982 251:1.390625:3980:3981 "
    s .= "~-0.04602723430390095 ~0.00711291705811155 ~0.05200232638949081 208:-0.234375:3984:3987 99:0.5390625:3985:3986 ~-0.03899129989289815 ~-0.19004558609039518 243:0.45:3988:3989 ~-0.03884398312318587 166:0.46875:3990:3993 "
    s .= "218:0.1875:3991:3992 ~0.03904373664506933 ~-0.0024490896463125332 136:1.296875:3994:3995 ~-0.027594985113378406 ~0.03596167341422329 244:0.815:3997:4002 202:-0.3125:3998:4001 205:0.171875:3999:4000 ~-0.04833781903509922 "
    s .= "~0.061506922501563546 ~-0.050482578652993396 196:-0.234375:4003:4010 77:-0.71875:4004:4005 ~0.015322764970652348 251:1.390625:4006:4007 ~-0.04357146477572655 46:0.046875:4008:4009 ~-0.04646216345980364 ~0.03682436813688945 "
    s .= "88:1.125:4011:4038 255:0.328125:4012:4031 2:0.0625:4013:4026 73:0.234375:4014:4021 136:2.234375:4015:4020 159:0.5234375:4016:4019 142:1.078125:4017:4018 ~0.029272601157028358 ~-0.039340791881415725 ~-0.05717361849413921 "
    s .= "~-0.09871170283031348 118:-0.265625:4022:4023 ~-0.07640258807063742 251:0.265625:4024:4025 ~-0.051277483304346165 ~0.010266100425037901 252:0.375:4027:4028 ~-0.03288098128812696 217:0.25:4029:4030 ~0.018380099578187776 "
    s .= "~-0.05276834770048058 98:-0.515625:4032:4033 ~0.004458451068081143 254:0.546875:4034:4037 115:0.390625:4035:4036 ~0.04200372863074265 ~-0.05206152048176041 ~-0.04373580594411548 121:0.796875:4039:4042 100:-0.3125:4040:4041 "
    s .= "~-0.03646859744994867 ~0.03685735584057912 ~-0.041468769518593275 109:0.609375:4044:4065 251:1.578125:4045:4062 47:0.140625:4046:4061 168:0.0546875:4047:4054 88:0.28125:4048:4051 91:0.171875:4049:4050 ~-0.028381277453800098 "
    s .= "~0.018434262486890226 55:1.4375:4052:4053 ~-0.05364782516445293 ~0.06510918123485447 172:-0.25:4055:4056 ~-0.0662718255647745 159:0.2109375:4057:4058 ~0.021828450561633638 240:0.46875:4059:4060 ~-0.04799520082038047 "
    s .= "~0.019089838702348247 ~-0.045728361776293046 86:0.375:4063:4064 ~-0.011155721518584042 ~0.039536008791859714 238:-0.1875:4066:4069 244:1.9:4067:4068 ~-0.0300110263030472 ~0.026867365777624847 245:5.03030303030303:4070:4089 "
    s .= "253:-0.055855855855857804:4071:4074 238:0.53125:4072:4073 ~0.03711254110326978 ~-0.021730033608906178 181:-0.078125:4075:4078 242:0.75:4076:4077 ~-0.06181671729817737 ~0.006063666472088483 193:0.21875:4079:4086 "
    s .= "142:-0.1875:4080:4081 ~-0.03677943639488462 193:-0.109375:4082:4083 ~-0.006967347185049749 90:0.5546875:4084:4085 ~0.03258360501492708 ~-0.05826918998140286 251:0.609375:4087:4088 ~-0.04780630902055709 ~0.014281958286910163 "
    s .= "~-0.14402525408863406 2:0.3125:4091:4136 75:0.0703125:4092:4117 193:-0.234375:4093:4096 5:-1.046875:4094:4095 ~0.039876807978988536 ~-0.0484630460900311 148:0.21875:4097:4108 178:-0.296875:4098:4099 ~-0.05715180335174447 "
    s .= "251:0.203125:4100:4101 ~-0.024953450469668542 133:2.390625:4102:4107 94:-0.09375:4103:4106 157:0.734375:4104:4105 ~-0.033522823979436706 ~0.01982712831214846 ~0.025614682575113942 ~-0.04889259163523172 244:1.035:4109:4110 "
    s .= "~-0.048710210931051684 247:0.328125:4111:4116 166:0.5:4112:4115 238:-0.078125:4113:4114 ~-0.03630195211523374 ~0.022919412460456836 ~-0.03803173079171113 ~-0.087484222074458 88:0.546875:4118:4133 130:2.03125:4119:4132 "
    s .= "28:0.515625:4120:4131 170:0.328125:4121:4130 142:1.125:4122:4129 255:0.234375:4123:4124 ~0.028300523279924206 119:-0.65625:4125:4126 ~0.03538008473817601 254:0.546875:4127:4128 ~0.042460519145679755 ~-0.022222102586719306 "
    s .= "~-0.0854555523776063 ~-0.028002855280949826 ~-0.0563693765340195 ~-0.06536211359812093 40:0.578125:4134:4135 ~0.034321203837069714 ~-0.03485750080634878 ~-0.032709677895901734 251:0.484375:4138:4157 244:1.21:4139:4152 "
    s .= "55:0.171875:4140:4151 211:-0.015625:4141:4142 ~-0.043736810585739826 145:0.109375:4143:4148 133:0.71875:4144:4147 245:1.5731707317073171:4145:4146 ~-0.05034983599758863 ~0.04715709180635693 ~-0.022322474646749718 "
    s .= "97:0.5625:4149:4150 ~-0.05116613916205364 ~0.07748045562947525 ~-0.053520776498372974 202:-0.09375:4153:4154 ~-0.05298961435201336 109:0.109375:4155:4156 ~-0.05268223480421326 ~0.01891355047900697 122:0.21875:4158:4179 "
    s .= "202:-0.046875:4159:4170 229:0.40625:4160:4169 252:0.32499999999999996:4161:4164 26:-0.859375:4162:4163 ~0.024506233967431568 ~-0.04679328389793613 145:-0.15625:4165:4168 188:-0.6875:4166:4167 ~0.032400144358629916 "
    s .= "~-0.07777638709953835 ~0.02181175421632163 ~0.038911761659035045 94:-0.25:4171:4174 245:1.8235294117647058:4172:4173 ~-0.08453099894034881 ~-0.00024081115768130324 255:0.265625:4175:4176 ~0.03519378401318826 "
    s .= "98:-0.171875:4177:4178 ~0.020938425566435857 ~-0.02474253307600112 255:0.265625:4180:4183 241:0.42:4181:4182 ~-0.0430759989956423 ~0.008395502313129228 ~-0.045961609182458646 249:0.16666666666666666:4185:4200 1:0.28125:4186:4197 "
    s .= "133:2.453125:4187:4196 67:-0.328125:4188:4189 ~-0.03992153331793016 253:-0.05:4190:4191 ~0.03879589191401469 243:1.65:4192:4195 90:0.3359375:4193:4194 ~0.024179570971506928 ~-0.026450671904246256 ~-0.0341843912322448 "
    s .= "~-0.07834352875497404 251:0.609375:4198:4199 ~-0.05019241913261411 ~0.0010238207556155204 50:-0.609375:4201:4210 195:-0.2109375:4202:4205 85:1.1875:4203:4204 ~-0.04057508946826447 ~0.025802500652571614 239:-0.125:4206:4207 "
    s .= "~0.0309814475446908 246:0.671875:4208:4209 ~-0.06533360111233617 ~0.040930772999374976 219:0.3515625:4211:4226 196:-0.125:4212:4213 ~-0.048875713070721805 127:0.140625:4214:4221 214:0.609375:4215:4218 248:0.875:4216:4217 "
    s .= "~0.00202166313251415 ~-0.04442593552790795 178:0.125:4219:4220 ~0.07414282926861553 ~-0.023719558651615257 252:1.4249999999999998:4222:4225 238:1.09375:4223:4224 ~-0.04018394912284858 ~0.02650729963117043 ~0.008748862684190012 "
    s .= "228:0.0234375:4227:4228 ~-0.07454025981879775 32:0.03125:4229:4230 ~0.02784149240927021 ~-0.015557823679522971 244:0.815:4232:4237 202:-0.3125:4233:4236 205:0.171875:4234:4235 ~-0.04777918839566199 ~0.05744334307734257 "
    s .= "~-0.05034209812916224 187:-0.3125:4238:4239 ~-0.03680906673675583 254:1.296875:4240:4275 122:0.09375:4241:4266 249:1.8333333333333335:4242:4265 118:0.28125:4243:4258 130:2.453125:4244:4255 85:0.625:4245:4254 "
    s .= "109:0.109375:4246:4249 252:0.025:4247:4248 ~-0.05028100021618769 ~0.01488684492685945 202:-0.015625:4250:4251 ~-0.00641109338778947 118:-0.28125:4252:4253 ~-0.032522183906671005 ~0.034461391446604595 ~0.03570107483269386 "
    s .= "144:-0.1953125:4256:4257 ~0.03464595478548852 ~-0.10995822422637179 244:1.025:4259:4264 88:-0.421875:4260:4261 ~0.11134882271297007 196:0.78125:4262:4263 ~-0.052103316826588676 ~0.02645711413964466 ~0.012257519296885996 "
    s .= "~-0.034848337060130206 252:0.32499999999999996:4267:4270 254:0.015625:4268:4269 ~0.016519319187252003 ~-0.03909403939126403 46:-0.21875:4271:4272 ~-0.05945880165168062 31:0.40625:4273:4274 ~0.02532735888040512 "
    s .= "~-0.04768273304293412 35:-0.609375:4276:4277 ~0.00922560748062768 ~-0.050881751705838335 244:0.815:4279:4284 202:-0.3125:4280:4283 205:0.171875:4281:4282 ~-0.04762359069750533 ~0.055413211588396884 ~-0.05029258482447494 "
    s .= "187:-0.3125:4285:4286 ~-0.035601088589849346 253:-0.055855855855857804:4287:4296 119:0.234375:4288:4293 245:5.03030303030303:4289:4292 36:0.0859375:4290:4291 ~0.012543105413155578 ~0.03880020060663629 ~-0.17310766472841393 "
    s .= "55:0.5:4294:4295 ~-0.03540436970581836 ~0.03748811775611398 254:1.296875:4297:4322 243:2.25:4298:4321 205:-0.265625:4299:4300 ~-0.03399529248723595 122:0.25:4301:4320 147:-0.1640625:4302:4305 160:0.875:4303:4304 "
    s .= "~-0.03240362473903315 ~0.018577174410244496 158:0.171875:4306:4315 63:-0.1796875:4307:4308 ~0.04282067852097368 121:0.28125:4309:4314 87:0.4453125:4310:4313 181:-0.0625:4311:4312 ~-0.02507224343721656 ~0.018929940142535073 "
    s .= "~-0.051380333859658546 ~-0.024108249224950976 119:0.078125:4316:4317 ~0.04802882968202161 97:-0.046875:4318:4319 ~-0.043492132790553084 ~0.0234419709803172 ~-0.017812864060907374 ~-0.0671624044526795 38:-0.59375:4323:4324 "
    s .= "~0.0012067968224297643 ~-0.05557040372078625 251:0.984375:4326:4357 256:0.23076923076923078:4327:4356 208:-0.265625:4328:4329 ~-0.04133615794942938 85:1.15625:4330:4353 255:0.296875:4331:4340 254:0.671875:4332:4335 "
    s .= "242:0.45:4333:4334 ~0.005902199776398309 ~-0.027069532149011612 251:0.203125:4336:4337 ~-0.024672310172359397 191:0.15625:4338:4339 ~0.045655533280483204 ~-0.02433237966865016 82:0.3125:4341:4348 26:-0.375:4342:4347 "
    s .= "229:0.140625:4343:4346 229:-0.203125:4344:4345 ~0.037450359497885194 ~-0.036332693206093565 ~0.028436766820242366 ~-0.033542395890893 244:1.21:4349:4350 ~-0.06303876798912199 196:0.546875:4351:4352 ~-0.027683058453630956 "
    s .= "~0.04978725865193271 249:1.8333333333333335:4354:4355 ~0.032971769421714106 ~-0.04986258508670398 ~-0.04807151392568816 252:0.175:4358:4365 146:-0.0625:4359:4364 127:1.421875:4360:4363 157:-0.125:4361:4362 ~-0.05645465115655928 "
    s .= "~0.0208674587673486 ~-0.0639542473772474 ~-0.04205380168607982 214:0.59375:4366:4371 256:0.9583333333333334:4367:4370 28:0.421875:4368:4369 ~0.035757836590346696 ~-0.02008583395645978 ~-0.05967516361258506 ~-0.04456876182842323 "
    s .= "109:0.609375:4373:4392 220:1.015625:4374:4389 190:-0.125:4375:4376 ~-0.04478504785016238 143:0.09375:4377:4388 113:0.546875:4378:4387 34:0.046875:4379:4384 202:0.21875:4380:4383 205:0.28125:4381:4382 ~0.003944814118876595 "
    s .= "~0.05840146391990149 ~-0.02218829399725662 130:0.9375:4385:4386 ~-0.043958652169411416 ~0.009151694188013607 ~0.04785568537876648 ~-0.031444876665871 133:0.9375:4390:4391 ~0.05848453775335959 ~-0.043861814618626364 "
    s .= "238:-0.1875:4393:4396 244:1.9:4394:4395 ~-0.02803141864719141 ~0.02710486448734305 245:5.03030303030303:4397:4418 253:-0.055855855855857804:4398:4403 140:0.09375:4399:4400 ~0.03873546899740703 242:0.35:4401:4402 "
    s .= "~-0.16823882359839723 ~0.011595243613550216 181:-0.078125:4404:4407 242:0.75:4405:4406 ~-0.05930065646954205 ~0.007097514007078378 217:0.203125:4408:4413 226:-0.078125:4409:4410 ~-0.012903162543537931 111:0.4765625:4411:4412 "
    s .= "~0.027558669539524124 ~-0.06183535995603883 251:0.609375:4414:4417 244:1.905:4415:4416 ~-0.0560519567379031 ~0.03394546889056144 ~0.00835552116349998 ~-0.12470012384536946 251:0.484375:4420:4441 31:0.015625:4421:4432 "
    s .= "211:-0.0625:4422:4423 ~-0.03645140699530425 145:0.109375:4424:4427 191:0.328125:4425:4426 ~0.02823205420803118 ~-0.046494553264958355 100:0.578125:4428:4429 ~-0.05048796472357713 241:0.14:4430:4431 ~0.11043704182054595 "
    s .= "~-0.040497303187923224 112:0.75:4433:4434 ~-0.04489077536675962 37:0.546875:4435:4440 40:0.53125:4436:4439 160:1.21875:4437:4438 ~-0.02837693780174191 ~0.03011265329502834 ~0.07666785855395998 ~-0.05716916074464267 "
    s .= "203:0.609375:4442:4465 249:0.16666666666666666:4443:4452 245:4.054054054054054:4444:4451 214:0.484375:4445:4448 211:-0.109375:4446:4447 ~-0.0011377144459339887 ~0.033190561488981384 244:1.46:4449:4450 ~-0.054390179299460106 "
    s .= "~0.024498304659975326 ~-0.07775769299919771 50:-0.609375:4453:4454 ~0.02084668324270182 254:1.015625:4455:4464 72:0.1796875:4456:4461 238:-0.1875:4457:4458 ~-0.05541190345574986 109:0.53125:4459:4460 ~-0.029671950453368484 "
    s .= "~0.010628109892086877 256:0.9166666666666666:4462:4463 ~0.02231721441324235 ~-0.05942612221375489 ~-0.04917123157358934 ~-0.0434330068004906 2:0.3125:4467:4512 75:0.0703125:4468:4493 193:-0.234375:4469:4472 5:-1.046875:4470:4471 "
    s .= "~0.03896940737127749 ~-0.04693523477839024 148:0.21875:4473:4484 181:0.015625:4474:4479 163:0.921875:4475:4476 ~-0.029001000489918244 46:-0.21875:4477:4478 ~-0.07248240034864943 ~0.05074677605281668 94:-0.0625:4480:4483 "
    s .= "154:0.59375:4481:4482 ~-0.03782408111001207 ~0.024221751893869464 ~0.025549966591949958 244:1.035:4485:4486 ~-0.046534123124299706 247:0.328125:4487:4492 234:0.0234375:4488:4491 82:1.015625:4489:4490 ~-0.03398148567137409 "
    s .= "~0.026208035447607025 ~0.02540104323285159 ~-0.08279616768753172 88:1.21875:4494:4511 255:0.234375:4495:4500 191:0.59375:4496:4499 130:2.03125:4497:4498 ~0.02455946667349201 ~-0.07403949646589267 ~-0.05037268799822479 "
    s .= "119:-0.5625:4501:4504 246:-0.390625:4502:4503 ~-0.01095861376391791 ~0.049808920572296224 251:1.609375:4505:4510 108:0.1484375:4506:4509 214:0.609375:4507:4508 ~-0.027876441641429908 ~0.04918482802512726 ~-0.06001281903291882 "
    s .= "~0.021290670967882407 ~0.03838469513152835 ~-0.030046859022124252 251:0.984375:4514:4541 245:1.5806451612903225:4515:4516 ~-0.05485698496002753 247:0.515625:4517:4538 249:0.8333333333333333:4518:4535 255:0.234375:4519:4524 "
    s .= "26:0.265625:4520:4523 251:0.203125:4521:4522 ~-0.017201204703907003 ~0.029786900198156958 ~-0.026742616393811355 26:-0.375:4525:4534 159:0.0390625:4526:4531 75:0.2578125:4527:4530 245:2.359375:4528:4529 ~-0.01344070435502885 "
    s .= "~0.024636192386117153 ~0.05004891637092162 84:0.0703125:4532:4533 ~0.011435820105807938 ~-0.058278341647286305 ~-0.026818283267919782 195:0.1328125:4536:4537 ~-0.03629960021290115 ~0.006207777339703811 255:-0.015625:4539:4540 "
    s .= "~0.0620152095452704 ~-0.053808429973354346 130:1.96875:4542:4557 252:0.175:4543:4552 152:0.21875:4544:4549 127:1.421875:4545:4548 157:-0.125:4546:4547 ~-0.04626991269243733 ~0.020461550561127674 ~-0.07214527736989307 "
    s .= "117:0.5234375:4550:4551 ~-0.07593902682184953 ~0.03383870300018596 31:0.40625:4553:4556 209:0.5625:4554:4555 ~0.03568627625402756 ~-0.041897093043656845 ~-0.026317537772534323 250:1.0546875:4558:4559 ~-0.058108459772319626 "
    s .= "~0.006252593243216209 122:0.09375:4561:4594 99:0.0390625:4562:4587 145:-0.171875:4563:4566 111:-0.1328125:4564:4565 ~-0.010717443054200845 ~-0.05617313331119644 94:-0.25:4567:4568 ~-0.0369763789268071 49:0.53125:4569:4586 "
    s .= "245:3.7777777777777777:4570:4585 136:1.09375:4571:4582 169:0.265625:4572:4577 85:0.53125:4573:4576 217:0.5625:4574:4575 ~-0.01391609060088202 ~0.07530162391201989 ~0.0336153987354352 220:1.015625:4578:4581 109:0.234375:4579:4580 "
    s .= "~0.021795889620135366 ~-0.053624303859873594 ~0.051072924749939 109:0.21875:4583:4584 ~-0.02334499590791783 ~0.03344629129222517 ~-0.059223825720960965 ~-0.036562778529228755 253:-0.023114581505527098:4588:4589 "
    s .= "~0.03147052668682589 254:1.265625:4590:4591 ~0.01127855990249337 119:-0.546875:4592:4593 ~-0.0031389584889171575 ~-0.0699206456898828 252:0.32499999999999996:4595:4600 254:0.015625:4596:4599 146:0.328125:4597:4598 "
    s .= "~0.04685012867621972 ~-0.03870804962944693 ~-0.042804849669715185 46:-0.21875:4601:4602 ~-0.05932073256894556 226:-0.15625:4603:4604 ~-0.038858161305982915 31:0.40625:4605:4606 ~0.02352047516566265 ~-0.04263487008495363 "
    s .= "187:-0.203125:4608:4609 ~-0.026779672348610395 85:1.15625:4610:4639 251:1.328125:4611:4636 255:0.296875:4612:4623 254:0.703125:4613:4620 242:0.45:4614:4615 ~0.0055507026258794735 160:0.90625:4616:4619 220:1.015625:4617:4618 "
    s .= "~-0.04530299957566125 ~0.04501047819970138 ~0.005016576603083746 251:0.203125:4621:4622 ~-0.02416232560636758 ~0.03551178259681587 47:-0.375:4624:4633 220:0.5625:4625:4630 82:-0.109375:4626:4627 ~0.022966259034884293 "
    s .= "245:2.9714285714285715:4628:4629 ~-0.03708378990769619 ~0.02683968992123248 211:0.53125:4631:4632 ~0.05381993181307781 ~-0.056509401047443814 241:0.12:4634:4635 ~0.0019020357015756475 ~-0.052244517989140295 130:2.03125:4637:4638 "
    s .= "~0.024898006255853308 ~-0.0568253806378812 208:-0.203125:4640:4641 ~-0.03583878818200125 243:2.1500000000000004:4642:4653 73:0.65625:4643:4652 245:4.277777777777778:4644:4651 218:-0.1875:4645:4646 ~0.04361498182384203 "
    s .= "55:-0.1875:4647:4650 6:0.34375:4648:4649 ~-0.018557191337134276 ~-0.24804685220088812 ~0.026622818369883373 ~-0.06358193584738628 ~-0.03497094412209093 ~-0.07516627318971725 249:0.16666666666666666:4655:4676 1:0.28125:4656:4673 "
    s .= "133:2.453125:4657:4672 67:-0.328125:4658:4659 ~-0.036588506541778906 90:0.0859375:4660:4663 243:2.1500000000000004:4661:4662 ~0.032289019535224256 ~-0.04167492025905248 251:1.046875:4664:4667 255:0.234375:4665:4666 "
    s .= "~0.0033401655358944286 ~-0.04716968865352006 252:0.175:4668:4671 160:1.015625:4669:4670 ~-0.08480308237384616 ~0.03491393897879526 ~0.04608615449048754 ~-0.07051818317545543 251:0.421875:4674:4675 ~-0.061412384905519785 "
    s .= "~-0.0064307708044472785 17:-0.625:4677:4682 52:-0.046875:4678:4679 ~0.03225610157827386 64:0.015625:4680:4681 ~-0.03811859548029476 ~0.01053271476680364 219:0.1328125:4683:4686 72:0.1484375:4684:4685 ~-0.035467915927662026 "
    s .= "~-0.004943149194490055 53:0.046875:4687:4698 184:-0.28125:4688:4689 ~-0.07899003905802639 234:-0.1484375:4690:4693 227:-0.859375:4691:4692 ~0.03404186460728146 ~-0.08972324455795926 255:0.234375:4694:4695 ~0.03397578929756317 "
    s .= "218:-0.59375:4696:4697 ~0.02648212884810644 ~-0.025716941507100372 187:0.703125:4699:4700 ~-0.03341526898439678 ~0.023131994209768695 251:0.484375:4702:4725 31:0.015625:4703:4716 211:-0.0625:4704:4707 244:2.035:4705:4706 "
    s .= "~-0.04440737303360351 ~0.049250086486925804 145:0.109375:4708:4711 191:0.328125:4709:4710 ~0.026598021916002097 ~-0.04507578260839257 100:0.578125:4712:4713 ~-0.04952954286764405 241:0.14:4714:4715 ~0.10037727037962539 "
    s .= "~-0.040320550178646296 112:0.75:4717:4718 ~-0.04352075584657271 37:0.546875:4719:4724 40:0.53125:4720:4723 160:1.21875:4721:4722 ~-0.027963501452589575 ~0.028878831689855868 ~0.07112758164608922 ~-0.056844501000879614 "
    s .= "159:0.3984375:4726:4745 248:0.875:4727:4738 254:1.046875:4728:4735 236:0.625:4729:4734 172:-0.3125:4730:4731 ~-0.017353817999923495 136:2.375:4732:4733 ~0.02425618819851653 ~-0.0644343562342674 ~-0.0414571097550386 "
    s .= "77:-0.8125:4736:4737 ~0.03102175167713337 ~-0.023868873944955057 146:0.09375:4739:4744 228:0.0703125:4740:4743 9:-0.2578125:4741:4742 ~0.035720913002022646 ~-0.03911892342049982 ~0.024863966455736387 ~-0.05228384496098712 "
    s .= "251:1.484375:4746:4747 ~-0.052614778926787856 ~0.011382978638298614 256:0.9583333333333334:4749:4794 217:-0.125:4750:4753 77:-0.765625:4751:4752 ~0.018729846128087126 ~-0.025206378937869523 217:0.21875:4754:4783 "
    s .= "163:-0.265625:4755:4756 ~-0.04383594740931977 85:0.53125:4757:4774 205:0.703125:4758:4773 251:0.984375:4759:4766 241:0.18:4760:4765 55:-0.140625:4761:4762 ~0.05916312800401376 109:0.609375:4763:4764 ~-0.037151827156947814 "
    s .= "~0.015328278220899492 ~-0.03657995670599943 243:0.6499999999999999:4767:4772 242:0.55:4768:4771 190:0.03125:4769:4770 ~-0.06115652231154837 ~0.0381703776178268 ~-0.08356724083713024 ~0.038770689977967156 ~0.04487082585897001 "
    s .= "37:0.765625:4775:4782 55:-0.21875:4776:4781 218:-0.203125:4777:4778 ~0.030409780826508227 186:0.5078125:4779:4780 ~-0.044743893725757065 ~-0.31341107086017694 ~0.03260073346796434 ~-0.03872512876694056 220:1.015625:4784:4793 "
    s .= "112:1.59375:4785:4792 181:0.890625:4786:4791 87:0.2109375:4787:4788 ~-0.04102302407562444 58:0.109375:4789:4790 ~0.03474191220055483 ~-0.0430971810581878 ~0.023314692608230034 ~0.019791344849746127 ~0.026884273363385586 "
    s .= "~-0.049055577326681775 122:0.046875:4796:4829 99:0.0390625:4797:4822 190:-0.328125:4798:4799 ~-0.04647757196478556 145:-0.171875:4800:4803 129:-0.4609375:4801:4802 ~0.027148444120411078 ~-0.03896825275186071 148:0.21875:4804:4809 "
    s .= "112:0.03125:4805:4808 58:0.71875:4806:4807 ~-0.04066184269705564 ~0.03911738629969212 ~0.02271763769531452 234:0.0234375:4810:4819 85:1.15625:4811:4818 163:1.390625:4812:4817 220:1.015625:4813:4816 79:1.328125:4814:4815 "
    s .= "~-0.06649504273524902 ~0.02856074718713 ~0.04243733498290972 ~0.024423582049727995 ~0.013264947541791378 90:0.0859375:4820:4821 ~0.026678345555028345 ~-0.07333934067441235 253:-0.023114581505527098:4823:4826 "
    s .= "118:0.328125:4824:4825 ~0.03689310082025582 ~-0.009191987729595312 254:1.265625:4827:4828 ~0.010391126715218165 ~-0.03220869942900225 46:-0.25:4830:4831 ~-0.05733061016413578 252:0.175:4832:4837 254:0.015625:4833:4834 "
    s .= "~0.024196848870365936 26:-0.015625:4835:4836 ~-0.012333573847176886 ~-0.0571564888154856 255:0.265625:4838:4841 167:0.203125:4839:4840 ~0.03575941683412039 ~-0.004860538815833099 ~-0.02611401320552625 "
    s .= "256:0.9583333333333334:4843:4888 49:0.640625:4844:4887 249:0.8333333333333333:4845:4874 255:0.328125:4846:4863 143:0.078125:4847:4862 245:3.7777777777777777:4848:4861 242:2.05:4849:4860 252:0.175:4850:4859 "
    s .= "242:0.8500000000000001:4851:4858 222:-0.2890625:4852:4853 ~-0.03819508733628828 240:0.59375:4854:4855 ~0.02937117395758056 232:-0.046875:4856:4857 ~-0.17602678839466682 ~-0.011800371400660202 ~-0.053134858045606116 "
    s .= "~0.03864550512417774 ~-0.027813575268449433 ~-0.06083641911665556 ~-0.0018111044307353085 247:0.234375:4864:4873 85:1.125:4865:4870 122:-0.96875:4866:4867 ~0.026558722641008416 97:0.40625:4868:4869 ~-0.022600115414982143 "
    s .= "~0.021485344919479447 106:2.4375:4871:4872 ~0.03159398742551339 ~-0.06987219634190411 ~-0.052290424146981734 196:-0.09375:4875:4876 ~-0.04344282846382715 118:0.28125:4877:4886 121:0.15625:4878:4883 121:-0.078125:4879:4880 "
    s .= "~-0.018568848166271964 238:0.453125:4881:4882 ~0.021111011361678016 ~0.08220998745130934 109:1.046875:4884:4885 ~-0.04632915826918231 ~0.016133122111762658 ~-0.03807310638363299 ~-0.03302925315075898 ~-0.04846911348976957 "
    s .= "251:0.484375:4890:4907 34:0.0625:4891:4902 250:1.0546875:4892:4901 145:0.109375:4893:4896 220:-0.140625:4894:4895 ~-0.033574192427701086 ~0.02901349470056367 100:0.578125:4897:4898 ~-0.04957382791786585 241:0.16:4899:4900 "
    s .= "~0.09081858866111299 ~-0.05726728019282893 ~-0.033364095186861294 112:0.78125:4903:4904 ~-0.049519106144979036 103:0.546875:4905:4906 ~0.019385065167979398 ~-0.04324475585802497 203:0.609375:4908:4935 254:1.296875:4909:4932 "
    s .= "187:-0.203125:4910:4911 ~-0.016924949370921285 109:0.515625:4912:4925 242:1.15:4913:4922 137:0.421875:4914:4921 100:1.21875:4915:4920 251:0.546875:4916:4917 ~0.0483961521566472 121:0.203125:4918:4919 ~-0.008627476673707597 "
    s .= "~-0.07041858637565422 ~0.05393758880715632 ~0.04192869967483748 251:1.484375:4923:4924 ~-0.05260028171161579 ~0.011571857919743996 248:1.125:4926:4931 245:4.658536585365853:4927:4930 245:1.6582278481012658:4928:4929 "
    s .= "~-0.01513882304751686 ~0.027323780751088395 ~-0.07319797734993104 ~-0.0224390902594497 53:-0.625:4933:4934 ~0.013274787704989936 ~-0.04482470699088657 ~-0.04012931059488588 88:1.125:4937:4976 251:1.171875:4938:4961 "
    s .= "187:-0.171875:4939:4940 ~-0.04394413398338405 245:1.5806451612903225:4941:4942 ~-0.05246457485810965 254:1.265625:4943:4958 247:0.484375:4944:4955 136:2.234375:4945:4954 2:0.0625:4946:4953 135:-0.2734375:4947:4950 "
    s .= "185:-0.609375:4948:4949 ~0.0035995797826942157 ~-0.056307861722648726 242:2.05:4951:4952 ~0.019570482579068123 ~-0.042691491427337344 ~-0.014756448806073305 ~-0.0784794012547046 251:0.109375:4956:4957 ~0.060986122989978256 "
    s .= "~-0.04896972479025858 80:-0.96875:4959:4960 ~0.02251780030137828 ~-0.04018528708131113 241:0.44:4962:4971 204:0.3515625:4963:4968 130:1.9375:4964:4967 146:0.046875:4965:4966 ~0.024402046620519174 ~-0.042419994795274 "
    s .= "~-0.06037541335986177 174:0.328125:4969:4970 ~-0.18083678801065622 ~-0.04311798883108502 232:0.5:4972:4975 245:3.4761904761904763:4973:4974 ~0.030557378450517238 ~-0.09346222783721181 ~-0.057563298762977416 100:-0.3125:4977:4978 "
    s .= "~-0.03949751623472581 70:0.53125:4979:4982 148:1.359375:4980:4981 ~0.033908933168903733 ~-0.020528741059125794 ~-0.023351482915693413 249:0.16666666666666666:4984:5005 1:0.28125:4985:5000 133:2.453125:4986:4999 16:-0.25:4987:4990 "
    s .= "139:0.421875:4988:4989 ~0.00906426108850606 ~-0.05331202924260611 31:0.1875:4991:4994 162:0.3671875:4992:4993 ~0.028539562645295714 ~-0.020933303491515527 251:0.640625:4995:4996 ~-0.04566753078693788 112:0.421875:4997:4998 "
    s .= "~-0.04750627121173683 ~0.03164869899286109 ~-0.06531409403955564 251:0.421875:5001:5002 ~-0.05984688522887482 132:0.1796875:5003:5004 ~0.009185677581959128 ~-0.051850392437252917 17:-0.625:5006:5013 28:0:5007:5008 "
    s .= "~0.029195990590816685 26:-0.75:5009:5012 251:0.359375:5010:5011 ~-0.03389704828815304 ~0.030512580511957377 ~-0.03340943544811569 120:0.0859375:5014:5017 220:0.96875:5015:5016 ~-0.028697224645212557 ~0.022059197812125227 "
    s .= "95:0.421875:5018:5029 89:0.640625:5019:5028 245:1.7903225806451613:5020:5021 ~-0.03484557891771988 238:-0.09375:5022:5023 ~-0.023440623635251467 94:0.421875:5024:5027 94:0.015625:5025:5026 ~-0.0028309801749986483 "
    s .= "~0.03696516231225006 ~-0.04480131566220875 ~0.04506481546149316 ~-0.03147615021408189 122:0.046875:5031:5064 124:-0.671875:5032:5033 ~-0.05238143478711848 85:1.15625:5034:5059 254:1.046875:5035:5052 147:-0.1640625:5036:5039 "
    s .= "160:1.125:5037:5038 ~-0.03433388524059904 ~0.029735505045609713 119:0.109375:5040:5051 158:0.125:5041:5050 90:0.2421875:5042:5047 245:1.9848484848484849:5043:5046 110:-0.03125:5044:5045 ~-0.04147012488885985 ~0.018085182124402268 "
    s .= "~0.02746615284457299 252:0.07500000000000001:5048:5049 ~-0.06528292663324531 ~0.013694236050311684 ~0.044699876518576875 ~-0.00983713644727884 77:-0.578125:5053:5056 113:-0.09375:5054:5055 ~-0.011774238177767737 "
    s .= "~0.04376788659233997 190:0.828125:5057:5058 ~-0.046253111127625104 ~0.030610511844026984 208:-0.234375:5060:5061 ~-0.023444588932889386 245:4.658536585365853:5062:5063 ~0.031123323958636536 ~-0.0795651031080464 46:-0.25:5065:5066 "
    s .= "~-0.05581125083057146 252:0.175:5067:5072 254:0.015625:5068:5069 ~0.022557973557556784 26:-0.015625:5070:5071 ~-0.011902084442146058 ~-0.05661311908517224 255:0.265625:5073:5076 167:0.203125:5074:5075 ~0.03413106377745832 "
    s .= "~-0.0044146613959128505 ~-0.024799980826876792 256:0.9583333333333334:5078:5123 49:0.53125:5079:5118 205:-0.25:5080:5085 88:0.328125:5081:5082 ~-0.0513446131803089 75:0.1796875:5083:5084 ~-0.029104960457991283 "
    s .= "~0.026586415144785148 255:0.234375:5086:5093 254:0.703125:5087:5090 251:0.671875:5088:5089 ~-0.004799888725373833 ~0.01859916388933881 249:1.5:5091:5092 ~0.041736179136702765 ~-0.03475412094867461 14:-0.609375:5094:5095 "
    s .= "~0.017475502519015244 247:0.296875:5096:5115 245:1.5806451612903225:5097:5098 ~-0.072285208434812 254:1.359375:5099:5114 146:-0.46875:5100:5101 ~0.021511998396226376 245:3.4761904761904763:5102:5113 190:0.78125:5103:5112 "
    s .= "79:0.90625:5104:5111 175:0.3125:5105:5110 88:1.125:5106:5109 251:1.640625:5107:5108 ~-0.061170283207347326 ~0.02476407386072137 ~0.021904348447135596 ~0.0056277510607165146 ~0.027131589181094207 ~0.04024782641202577 "
    s .= "~-0.07237173277064007 ~-0.03060142135132103 251:2.453125:5116:5117 ~-0.0522507799526183 ~0.0507870021648332 121:0.0625:5119:5122 235:0.09375:5120:5121 ~0.01980352166769181 ~-0.05329856260862606 ~-0.04338125475134353 "
    s .= "~-0.04767399801001177 88:1.125:5125:5166 251:1.171875:5126:5153 245:1.5806451612903225:5127:5128 ~-0.051514485402386116 187:-0.171875:5129:5130 ~-0.04187268522104805 254:1.265625:5131:5150 247:0.484375:5132:5147 "
    s .= "136:2.234375:5133:5146 243:2.1500000000000004:5134:5145 73:0.0625:5135:5136 ~0.016880876345270183 106:0.640625:5137:5142 241:0.44:5138:5141 94:-0.078125:5139:5140 ~-0.04644971264998878 ~0.02816800576612051 ~-0.03841237505045911 "
    s .= "251:0.671875:5143:5144 ~-0.05264081125621605 ~0.010947088419129003 ~-0.06195675123960884 ~-0.07494062906434487 251:0.109375:5148:5149 ~0.058396711800780446 ~-0.04771767396778525 80:-0.96875:5151:5152 ~0.020712834748829297 "
    s .= "~-0.03821125673923209 241:0.44:5154:5163 204:0.3515625:5155:5160 130:1.9375:5156:5159 109:0.46875:5157:5158 ~-0.021650554893329982 ~0.029711608971822703 ~-0.05787801902098817 174:0.609375:5161:5162 ~-0.10559182209948387 "
    s .= "~0.014262704397256694 232:0.5:5164:5165 ~0.027536388207196255 ~-0.054816873297006775 100:-0.3125:5167:5168 ~-0.03785630758829863 70:0.53125:5169:5170 ~0.028691168739878876 ~-0.02249626155417171 2:0.3125:5172:5215 "
    s .= "255:0.234375:5173:5182 249:1.5:5174:5181 254:0.453125:5175:5178 85:0.71875:5176:5177 ~-0.0025063271202781508 ~0.02224665745739597 239:0.09375:5179:5180 ~0.04572430681989734 ~-0.00035196652266089134 ~-0.03211729908862993 "
    s .= "122:-0.296875:5183:5204 247:0.234375:5184:5201 157:1.203125:5185:5200 178:-0.09375:5186:5187 ~-0.033679391832443235 242:0.45:5188:5193 123:-0.2421875:5189:5190 ~-0.023011559562269305 142:-0.21875:5191:5192 ~-0.052822983267378776 "
    s .= "~0.03690375943176574 134:-0.328125:5194:5199 245:2.161764705882353:5195:5196 ~-0.06020088629350796 191:-0.6875:5197:5198 ~0.031350567666126906 ~-0.04210435398675023 ~0.018534537932971353 ~0.027921664515864055 "
    s .= "251:2.015625:5202:5203 ~-0.042650682477863106 ~0.031075599806814205 254:0.546875:5205:5206 ~0.01204532411750767 241:0.56:5207:5210 214:0.6875:5208:5209 ~-0.05122716646340855 ~0.008405334714078835 244:1.395:5211:5214 "
    s .= "250:1.1484375:5212:5213 ~-0.049501209010906606 ~0.006427696168152666 ~0.015651536042342856 244:1.17:5216:5217 ~-0.04843867437063408 ~-0.00876268480991458 211:-0.296875:5219:5222 43:0.0625:5220:5221 ~-0.04669352243693958 "
    s .= "~0.0003819264254057268 85:1.15625:5223:5256 251:1.421875:5224:5249 245:1.5806451612903225:5225:5226 ~-0.04646856125310129 247:0.640625:5227:5248 255:0.234375:5228:5233 254:0.703125:5229:5230 ~-0.0010725652918544479 "
    s .= "239:0.078125:5231:5232 ~0.043702324271211075 ~-0.011791033972290688 241:0.12:5234:5239 154:0.359375:5235:5236 ~-0.00812724120034804 208:0.546875:5237:5238 ~0.05848637762417717 ~-0.033771078255448325 26:-0.484375:5240:5245 "
    s .= "220:0.609375:5241:5244 136:1.59375:5242:5243 ~-0.025351058547588567 ~0.03469767093790705 ~0.05080972434374992 100:1.15625:5246:5247 ~-0.044166072853778555 ~0.026840487075881943 ~-0.05197327508100489 243:0.75:5250:5255 "
    s .= "184:0.5:5251:5254 46:0.09375:5252:5253 ~-0.06605739320422299 ~0.006456656163188257 ~0.03241389179567144 ~0.03218386890321899 208:-0.21875:5257:5258 ~-0.039851058565397876 37:0.765625:5259:5264 218:-0.1875:5260:5261 "
    s .= "~0.03845270510031753 55:-0.234375:5262:5263 ~-0.05755053773068143 ~0.022506155895471416 ~-0.023373916761495885 122:0.09375:5266:5303 124:-0.671875:5267:5268 ~-0.050671751114637835 85:1.15625:5269:5296 254:1.015625:5270:5287 "
    s .= "147:-0.2109375:5271:5274 160:0.921875:5272:5273 ~-0.04217327957926679 ~0.021834851718553126 119:0.109375:5275:5286 158:0.125:5276:5285 90:0.1640625:5277:5282 245:1.9848484848484849:5278:5279 ~-0.014705258843740368 "
    s .= "194:-0.203125:5280:5281 ~0.036922135094671335 ~-0.004582866195353734 252:0.07500000000000001:5283:5284 ~-0.051721254427178835 ~0.007917343358501248 ~0.04238533340374154 ~-0.010332666017554261 77:-0.578125:5288:5295 "
    s .= "113:-0.09375:5289:5294 244:1.445:5290:5293 71:-1.0625:5291:5292 ~0.020470046199263403 ~-0.05116356318706851 ~0.016674581160025344 ~0.04178390585922824 ~-0.03442083201893175 208:-0.234375:5297:5298 ~-0.021869971135528608 "
    s .= "218:-0.1875:5299:5300 ~0.03593934418008237 207:-0.3984375:5301:5302 ~-0.07523333615155103 ~0.013644204839032996 79:0.34375:5304:5309 88:0.234375:5305:5306 ~-0.04852480372714904 127:0.125:5307:5308 ~0.012092244379511194 "
    s .= "~-0.034244454173007165 238:-0.234375:5310:5311 ~-0.06294678723585469 ~0.007483437686172287 49:0.640625:5313:5358 256:0.9583333333333334:5314:5357 253:-0.055855855855857804:5315:5326 252:0.275:5316:5323 71:-0.078125:5317:5320 "
    s .= "171:0.015625:5318:5319 ~-0.013990389436718403 ~0.03839677556589536 184:-0.046875:5321:5322 ~-0.11518148491805175 ~-0.012026776979656624 31:-0.421875:5324:5325 ~-0.06436467714032054 ~0.034368461432292975 190:0:5327:5342 "
    s .= "15:0.5234375:5328:5341 181:0.15625:5329:5336 241:0.52:5330:5333 184:0.078125:5331:5332 ~-0.06552236138597471 ~-0.012406412416059333 243:1.35:5334:5335 ~0.027856439022444363 ~-0.04825222230155061 121:0.296875:5337:5340 "
    s .= "214:-0.203125:5338:5339 ~-0.033491502795383245 ~0.022073373794679576 ~-0.05413329285561041 ~0.029116555229576586 243:1.85:5343:5356 142:-0.21875:5344:5345 ~-0.03649065388801246 202:0.21875:5346:5349 124:-0.1875:5347:5348 "
    s .= "~-0.027035836401194464 ~0.020865275490311825 112:1.09375:5350:5355 163:0.53125:5351:5354 136:0.609375:5352:5353 ~-0.02038661241325875 ~0.024630303205336636 ~-0.05660640081319588 ~0.01953139365047996 ~-0.062338875072183546 "
    s .= "~-0.04648832062855462 ~-0.030743161071060333 251:0.484375:5360:5379 46:0.078125:5361:5372 31:0.0625:5362:5371 109:0.171875:5363:5364 ~-0.040808761054546845 214:-0.203125:5365:5366 ~-0.04323431414822001 121:0.109375:5367:5368 "
    s .= "~0.033463198917894364 169:0.453125:5369:5370 ~-0.041722508130148384 ~0.0446490677529212 ~-0.03756526902181294 244:1.21:5373:5374 ~-0.04397937467532126 160:0.265625:5375:5376 ~-0.06388072217200216 238:0.015625:5377:5378 "
    s .= "~-0.05386194907073613 ~0.026357463714879004 159:0.3984375:5380:5403 191:-0.71875:5381:5382 ~0.025465924318142742 254:1.296875:5383:5402 46:-0.171875:5384:5389 126:0.2578125:5385:5388 121:0.34375:5386:5387 ~-0.014309985954552136 "
    s .= "~-0.06715034523506343 ~0.020551614232710392 130:1.9375:5390:5399 118:0.296875:5391:5398 238:0.21875:5392:5393 ~0.026075630836356202 136:0.828125:5394:5395 ~-0.03201635704304947 181:-0.046875:5396:5397 ~-0.07794225605965174 "
    s .= "~0.03683936388650923 ~-0.004306160000668995 256:0:5400:5401 ~-0.05704577770862414 ~0.029488613907873475 ~-0.031754239095405555 251:1.484375:5404:5405 ~-0.04974913958850549 ~0.009099826985806766 249:0.16666666666666666:5407:5420 "
    s .= "253:-0.06679035250463854:5408:5409 ~0.028313452700294863 1:0.28125:5410:5419 4:-0.28125:5411:5412 ~-0.027997624190512438 133:2.453125:5413:5418 90:0.3359375:5414:5415 ~0.018708921060319218 251:1.171875:5416:5417 "
    s .= "~-0.06510927933189811 ~0.020884332535318188 ~-0.07659099608968467 ~-0.027405656751159455 17:-0.09375:5421:5444 99:-0.1015625:5422:5425 157:1.03125:5423:5424 ~-0.032145629119401664 ~0.010557900224605878 127:-0.15625:5426:5427 "
    s .= "~0.04030139532940894 205:0.625:5428:5441 91:-0.140625:5429:5430 ~-0.05959766539444187 127:0.34375:5431:5434 245:3.3220338983050848:5432:5433 ~0.019010885805788198 ~-0.06448861842675706 109:0.609375:5435:5436 ~-0.05235822598102097 "
    s .= "226:0.453125:5437:5440 243:0.6499999999999999:5438:5439 ~-0.055961687319805054 ~0.016856894744171586 ~0.05315379082657693 10:-0.15625:5442:5443 ~-0.03811871575067069 ~0.046103450082107596 144:0.1328125:5445:5446 "
    s .= "~-0.03456551412160757 172:-0.171875:5447:5448 ~-0.05680518592047047 170:0.453125:5449:5452 184:-0.078125:5450:5451 ~-0.04916037144180251 ~0.02063811740605964 ~-0.03566026736519748 251:0.828125:5454:5485 "
    s .= "256:0.2653061224489796:5455:5484 208:-0.265625:5456:5457 ~-0.03796398065719417 85:1.15625:5458:5483 46:0.078125:5459:5470 31:0.078125:5460:5469 4:-0.25:5461:5464 103:-0.1875:5462:5463 ~0.031885864013867296 ~-0.04738196122389642 "
    s .= "91:0.25:5465:5468 205:0.28125:5466:5467 ~-0.013095463574700667 ~0.033640056926912285 ~0.04263442109804351 ~-0.029513822494256367 160:1.171875:5471:5480 241:0.1:5472:5475 91:0.5:5473:5474 ~-0.028292325717561007 ~0.0713488777918926 "
    s .= "220:0.96875:5476:5479 202:0.09375:5477:5478 ~-0.019011409797086612 ~-0.06509802046204062 ~0.04081335859391849 52:0.296875:5481:5482 ~0.04517360254062738 ~-0.04995483976151611 ~0.021602750388561822 ~-0.04796900453480258 "
    s .= "248:0.875:5486:5497 109:0.546875:5487:5496 151:0.46875:5488:5495 235:0.125:5489:5492 202:-0.015625:5490:5491 ~-0.046199157242522305 ~0.017008862584877202 133:0.109375:5493:5494 ~0.015418091297290042 ~-0.0745209479562831 "
    s .= "~0.018817706803383523 ~0.020416460073148304 46:1.171875:5498:5499 ~-0.027361998119068077 ~0.07271272701737547 196:-0.125:5501:5504 149:-0.140625:5502:5503 ~-0.002931533024301115 ~-0.03397677269931067 88:1.21875:5505:5544 "
    s .= "190:-0.109375:5506:5509 21:0.5546875:5507:5508 ~-0.030304397807648587 ~0.027125570062997408 193:0.15625:5510:5527 133:2.453125:5511:5526 243:0.6499999999999999:5512:5523 214:0.59375:5513:5522 191:0.078125:5514:5519 "
    s .= "242:0.6499999999999999:5515:5518 70:0.515625:5516:5517 ~0.0017242756484360602 ~0.055516875279398796 ~-0.05272370628002945 184:0.234375:5520:5521 ~-0.061159358063195425 ~0.007805952288155265 ~0.04214129648241487 "
    s .= "238:0.5625:5524:5525 ~0.028075922806210293 ~-0.03823749153627101 ~-0.07240753081666348 25:0.21875:5528:5541 234:0.3828125:5529:5540 245:1.603448275862069:5530:5531 ~-0.04627278527801357 94:0.5:5532:5539 91:0.171875:5533:5538 "
    s .= "49:-0.203125:5534:5535 ~0.035249780701593396 252:0.175:5536:5537 ~-0.04336763845046907 ~0.02441979616483738 ~0.0371808353175289 ~-0.041197399274672544 ~-0.04921688036698316 55:-0.453125:5542:5543 ~0.07426779296645582 "
    s .= "~-0.051007819693611234 121:0.796875:5545:5546 ~0.02931779478777611 ~-0.04129412434537654 70:0.609375:5548:5591 211:-0.296875:5549:5552 43:0.0625:5550:5551 ~-0.045975520908374146 ~0.003399023749789796 88:1.125:5553:5588 "
    s .= "254:1.015625:5554:5575 2:0.0625:5555:5570 162:0.3671875:5556:5567 130:1.875:5557:5564 251:0.828125:5558:5561 245:1.5806451612903225:5559:5560 ~-0.054133285935132204 ~0.010528757750740345 14:0.28125:5562:5563 ~0.03354715357713675 "
    s .= "~-0.045130719404579384 135:-0.2265625:5565:5566 ~0.019152975239252384 ~-0.06585140595726761 61:1.265625:5568:5569 ~-0.013337118006757848 ~-0.12482063649180489 100:1.03125:5571:5574 251:1.484375:5572:5573 ~-0.03167618423578311 "
    s .= "~0.009950424721841144 ~0.029143366110521842 56:-0.515625:5576:5585 113:-0.09375:5577:5582 28:0:5578:5579 ~0.010306140911472254 203:-1.375:5580:5581 ~0.0332744696665732 ~-0.04540914793436688 245:2.1744186046511627:5583:5584 "
    s .= "~0.05997591202488785 ~-0.04171862433920431 190:0.828125:5586:5587 ~-0.03975898369674038 ~0.029653040543361278 148:1.359375:5589:5590 ~0.02918493704313689 ~-0.028553888952418116 178:0.15625:5592:5593 ~-0.0025807593302955385 "
    s .= "~-0.04657993062284059 249:0.16666666666666666:5595:5616 253:-0.06875:5596:5597 ~0.0277404530397074 73:0.203125:5598:5611 64:-0.25:5599:5600 ~-0.04454193083662179 243:1.55:5601:5610 90:0.0859375:5602:5603 ~0.02938341002604193 "
    s .= "241:0.58:5604:5609 9:0.2734375:5605:5606 ~-0.06177879872593059 91:0.28125:5607:5608 ~-0.0399893352545935 ~0.03948510316021925 ~0.0319214969531727 ~-0.029118178374014998 58:0.328125:5612:5615 154:0.421875:5613:5614 "
    s .= "~-0.044773528274978165 ~0.02740430871382786 ~-0.0438310331743076 192:0.2734375:5617:5636 127:0.328125:5618:5625 2:0.0625:5619:5624 106:-0.1875:5620:5621 ~-0.04146982435581849 251:0.171875:5622:5623 ~-0.0390002055855965 "
    s .= "~0.014053110792803783 ~-0.032747931358740136 187:0.3125:5626:5629 163:1.703125:5627:5628 ~-0.04628169334001768 ~0.04158011260460809 1:-0.265625:5630:5631 ~-0.057008630224922446 49:0.53125:5632:5635 24:-0.0078125:5633:5634 "
    s .= "~0.031716956185077264 ~-0.016699184504555858 ~-0.05300050990280064 193:0.15625:5637:5638 ~0.020807384305692428 178:0.640625:5639:5640 ~-0.03998913578613434 ~0.026154486476446942 217:-0.125:5642:5647 17:-0.78125:5643:5644 "
    s .= "~0.019714698227212557 251:0.640625:5645:5646 ~-0.04290579989759345 ~-0.010116284486941808 217:0.21875:5648:5679 133:2.390625:5649:5678 159:0.5234375:5650:5677 205:0.09375:5651:5668 241:0.5:5652:5665 31:-0.328125:5653:5654 "
    s .= "~0.04770269063697298 204:0.3515625:5655:5662 118:-0.03125:5656:5657 ~-0.05407729877738815 242:0.55:5658:5661 249:0.5:5659:5660 ~0.020123781816044378 ~-0.04025830744945314 ~-0.05330634129378828 181:0.890625:5663:5664 "
    s .= "~-0.06512589996712119 ~-0.24879313272841938 145:-0.15625:5666:5667 ~-0.059919182798905804 ~0.027477875288354128 70:0.609375:5669:5676 244:1.44:5670:5675 187:0.015625:5671:5672 ~-0.0264060946486699 249:0.8333333333333333:5673:5674 "
    s .= "~0.02822257286101408 ~-0.007883957939222789 ~0.04072489053252197 ~-0.0349667267958781 ~-0.055801059920383846 ~-0.054430779097451414 44:-0.078125:5680:5687 113:0:5681:5684 112:1.390625:5682:5683 ~-0.027469096656163712 "
    s .= "~0.02579640944009666 91:0.0625:5685:5686 ~-0.0316827578542564 ~0.04005699760643331 ~-0.02946791316972306 122:0.046875:5689:5724 124:-0.671875:5690:5691 ~-0.04956688913965243 253:-0.0897435897435912:5692:5699 "
    s .= "245:1.8181818181818181:5693:5694 ~-0.02249346505417239 33:-0.1015625:5695:5698 252:0.125:5696:5697 ~-0.05595571825435365 ~0.022425431787182357 ~0.041811696374286056 160:1.171875:5700:5721 147:-0.1640625:5701:5702 "
    s .= "~-0.025882014695269597 246:0.671875:5703:5718 108:0.1796875:5704:5717 139:0.640625:5705:5716 241:0.16:5706:5709 118:-0.046875:5707:5708 ~-0.020995568118718347 ~0.03756607331045744 85:0.71875:5710:5715 127:0.703125:5711:5712 "
    s .= "~-0.03887544691757871 106:0.390625:5713:5714 ~-0.06692171014757904 ~0.03183749902071472 ~0.023511985943924243 ~-0.017527316901075604 ~-0.031819138658238176 23:0.5:5719:5720 ~0.031157501356601905 ~-0.05325028565204964 "
    s .= "7:0.453125:5722:5723 ~0.023391899942783536 ~-0.03196219988825499 46:-0.25:5725:5726 ~-0.05259995725575564 79:0.34375:5727:5732 88:0.234375:5728:5729 ~-0.04089402161197582 210:0.1171875:5730:5731 ~-0.03210682537333034 "
    s .= "~0.015444470307096806 31:0.109375:5733:5734 ~0.025002017175200987 ~-0.013155842308667183 194:0.59375:5736:5781 255:0.296875:5737:5758 249:0.8333333333333333:5738:5751 245:3.7777777777777777:5739:5750 143:0.125:5740:5749 "
    s .= "251:0.203125:5741:5742 ~-0.018935814097661176 254:0.703125:5743:5746 88:1.09375:5744:5745 ~0.008969069876789817 ~0.0401330747980688 243:0.25:5747:5748 ~-0.04593660596920946 ~0.04143235219536706 ~-0.0019229655128834581 "
    s .= "~-0.04628748227892282 216:0.1328125:5752:5755 238:0:5753:5754 ~-0.05172159001097629 ~-0.008840117898093951 17:0.328125:5756:5757 ~0.023756183371035425 ~-0.04522971976470393 122:-0.28125:5759:5772 247:0.265625:5760:5769 "
    s .= "158:-0.3125:5761:5766 133:1.1875:5762:5765 245:1.9848484848484849:5763:5764 ~-0.04750837696824163 ~-0.004117336712717614 ~0.013094236388410783 121:-0.296875:5767:5768 ~-0.04489206771860502 ~0.027440315822483616 "
    s .= "251:1.984375:5770:5771 ~-0.04761731643930322 ~0.02999322875489084 46:-0.25:5773:5774 ~-0.05778078400819802 244:1.145:5775:5778 234:0.1328125:5776:5777 ~-0.05383434224718944 ~-0.00750246639464755 162:0.2109375:5779:5780 "
    s .= "~0.0006012756046181224 ~-0.056119179291949574 ~-0.03879083127339546 232:-0.15625:5783:5792 22:-0.234375:5784:5785 ~-0.04233802618203204 112:1.4375:5786:5791 251:1.015625:5787:5790 249:0.16666666666666666:5788:5789 "
    s .= "~-0.009666330914406529 ~-0.05859682597792847 ~0.005427111689523752 ~0.02353445477277713 256:0.9583333333333334:5793:5828 254:1.015625:5794:5823 118:0.28125:5795:5810 49:0.34375:5796:5807 245:3.7777777777777777:5797:5806 "
    s .= "88:0.515625:5798:5803 205:-0.25:5799:5800 ~-0.04636488143424316 186:0.6328125:5801:5802 ~0.016572774631888356 ~-0.06356633536801913 43:0.234375:5804:5805 ~0.039808590762296835 ~-0.012855572536773966 ~-0.0504757523951043 "
    s .= "154:0.796875:5808:5809 ~-0.03689482744954839 ~0.020356521870866222 163:1.203125:5811:5822 220:0.890625:5812:5821 241:0.1:5813:5816 1:-0.34375:5814:5815 ~0.08351759055435386 ~-0.009951756366342945 244:1.01:5817:5818 "
    s .= "~-0.052210343677074125 245:2.020408163265306:5819:5820 ~0.01952036374832021 ~-0.03397906904604443 ~0.03834124257836356 ~0.030416089649001533 53:-0.5625:5824:5827 25:0.65625:5825:5826 ~0.010625473602427908 ~-0.061223232940637695 "
    s .= "~-0.028444422135972883 ~-0.05354555405634346 243:2.05:5830:5875 238:-0.078125:5831:5840 2:-0.078125:5832:5839 127:0.4375:5833:5836 55:-0.34375:5834:5835 ~-0.05864124571952727 ~0.01615627821891387 115:0.46875:5837:5838 "
    s .= "~-0.0001437179795741592 ~-0.051029569163809324 ~-0.0311540495853246 85:0.671875:5841:5872 184:0.8125:5842:5869 241:0.12:5843:5850 250:0.8671875:5844:5847 100:0.078125:5845:5846 ~-0.0005186064274059183 ~0.06212293352747064 "
    s .= "34:-0.125:5848:5849 ~0.03206328198354579 ~-0.04462557978835556 220:0.609375:5851:5868 251:1.546875:5852:5865 163:1.140625:5853:5864 103:0.1875:5854:5861 120:0.1328125:5855:5858 73:-0.6875:5856:5857 ~0.06028826107158089 "
    s .= "~-0.045579260832118565 118:0.234375:5859:5860 ~0.02777655478298954 ~-0.05960101160468526 55:1.25:5862:5863 ~-0.05398193342453564 ~0.029934511075696835 ~0.022498097825632446 232:0.4375:5866:5867 ~0.02822036199720876 "
    s .= "~-0.05795144264277094 ~0.03117403822281232 1:0.421875:5870:5871 ~0.03435654459038564 ~-0.06734368942486964 121:0.421875:5873:5874 ~0.02183934965052024 ~-0.020643199406436847 ~-0.037610176480290664 159:0.3984375:5877:5920 "
    s .= "251:0.484375:5878:5897 46:0.078125:5879:5890 31:0.0625:5880:5889 109:0.171875:5881:5882 ~-0.03894689515664664 214:-0.203125:5883:5884 ~-0.04048862246618079 121:0.109375:5885:5886 ~0.0323824748239668 169:0.453125:5887:5888 "
    s .= "~-0.041051264536921775 ~0.04224055309638383 ~-0.03427422908632677 244:1.21:5891:5892 ~-0.04281192600153073 160:0.265625:5893:5894 ~-0.06326203675520464 238:-0.03125:5895:5896 ~-0.05838052764577015 ~0.02338966702170106 "
    s .= "191:-0.71875:5898:5905 214:0.421875:5899:5902 109:0.53125:5900:5901 ~0.002356773538922452 ~0.040869069607101655 148:0.671875:5903:5904 ~-0.03731631445546323 ~0.05508117646145647 254:1.296875:5906:5919 46:-0.171875:5907:5910 "
    s .= "62:-0.09375:5908:5909 ~0.004426516538851659 ~-0.034179663658519065 245:4.054054054054054:5911:5918 118:0.296875:5912:5917 238:0.21875:5913:5914 ~0.023437884294475297 112:0.734375:5915:5916 ~-0.02862392496780869 "
    s .= "~0.023338619601024322 ~-0.006975455027404262 ~-0.061623346386851185 ~-0.02924681053117433 255:0.078125:5921:5922 ~0.005318808729033677 ~-0.052213763719570386 249:0.16666666666666666:5924:5943 253:-0.06679035250463854:5925:5928 "
    s .= "245:3.92:5926:5927 ~0.028778483330362693 ~-0.08088303298695525 73:0.203125:5929:5940 127:-0.21875:5930:5931 ~-0.04181279707800842 90:0.0859375:5932:5933 ~0.022004087928879642 251:1.109375:5934:5939 180:0.1640625:5935:5938 "
    s .= "175:0.265625:5936:5937 ~-0.037575343213456715 ~0.03462329097264779 ~-0.052525490650086895 ~0.02544509010375099 4:0.296875:5941:5942 ~-0.005607872871657998 ~-0.05544607648960499 17:-0.625:5944:5949 77:-0.421875:5945:5948 "
    s .= "195:-0.2265625:5946:5947 ~-0.011347002336174965 ~0.028587392307988558 ~-0.016504779232522204 121:-0.1875:5950:5953 248:0.125:5951:5952 ~0.002079749932799742 ~-0.049107982662738615 142:-0.21875:5954:5955 ~-0.04207959552372758 "
    s .= "219:0.1328125:5956:5957 ~-0.015323862510026452 31:-0.34375:5958:5959 ~0.046338122611070454 178:0.609375:5960:5969 154:0.75:5961:5966 127:0.328125:5962:5965 64:0.484375:5963:5964 ~-0.01588017837575883 ~0.0347928089144293 "
    s .= "~-0.04507745327102841 217:0.390625:5967:5968 ~0.035349920778337894 ~-0.0821538498816815 ~0.028919921990403566 49:0.640625:5971:6016 243:2.1500000000000004:5972:6015 118:0.28125:5973:5998 127:2.421875:5974:5997 248:0.875:5975:5990 "
    s .= "252:0.42500000000000004:5976:5987 47:0.1875:5977:5986 184:0.046875:5978:5983 204:0.1171875:5979:5982 178:0:5980:5981 ~-0.027948691203918526 ~0.028469024396316822 ~-0.03920212641767789 242:1.25:5984:5985 ~0.021454284650729096 "
    s .= "~-0.07902381927879776 ~-0.031222118925931453 145:-0.140625:5988:5989 ~-0.02277015113632027 ~0.03213199744846232 73:0.03125:5991:5996 91:0.140625:5992:5995 223:1.078125:5993:5994 ~-0.03998790162166832 ~0.05554918600998603 "
    s .= "~0.03633124502690956 ~-0.036965789649291196 ~-0.08434904249149722 244:1.03:5999:6004 196:0.78125:6000:6003 88:-0.421875:6001:6002 ~0.06773291433941636 ~-0.05020398250254376 ~0.027375541860793724 163:0.0625:6005:6008 "
    s .= "76:0.328125:6006:6007 ~-0.05736035498211694 ~0.022076230296334196 106:0.578125:6009:6012 73:0.34375:6010:6011 ~0.007856064627686626 ~0.05833878597314927 109:1.375:6013:6014 ~-0.02794549400598492 ~0.019645961348408056 "
    s .= "~-0.03995246134299585 ~-0.027315942704771525 194:0.59375:6018:6063 255:0.234375:6019:6034 249:1.5:6020:6031 254:0.453125:6021:6028 251:0.609375:6022:6025 238:1.09375:6023:6024 ~-0.01326685182304133 ~0.042574382825040974 "
    s .= "191:0.640625:6026:6027 ~0.016204759585759114 ~-0.05609566181602971 239:0.09375:6029:6030 ~0.041825929374258664 ~-0.000888730847323401 216:0.2265625:6032:6033 ~-0.04581753545591549 ~0.02732560737725434 122:-0.296875:6035:6052 "
    s .= "247:0.234375:6036:6051 158:-0.3125:6037:6046 176:-0.65625:6038:6045 245:2.119047619047619:6039:6040 ~-0.02230767296578056 181:-0.09375:6041:6042 ~-0.019360373712395153 40:0.453125:6043:6044 ~0.038982767095538794 "
    s .= "~-0.020487855681043676 ~-0.016057645625884555 119:-0.515625:6047:6048 ~0.04505895685777101 73:0.28125:6049:6050 ~-0.005817354008112141 ~0.04533981357575162 ~-0.028749137991962433 254:0.609375:6053:6056 24:-0.2421875:6054:6055 "
    s .= "~-0.08133106843599597 ~0.015958087712278288 79:0.359375:6057:6058 ~-0.03991267928350674 244:1.21:6059:6060 ~-0.038217843376720274 238:-0.15625:6061:6062 ~-0.05480724254348656 ~0.019221748019345924 ~-0.03704079795433627 "
    s .= "251:1.328125:6065:6098 247:0.484375:6066:6095 245:1.5806451612903225:6067:6068 ~-0.044277052836620735 172:-0.3125:6069:6072 32:-0.828125:6070:6071 ~0.028340535621310465 ~-0.04530631815276738 85:1.15625:6073:6088 "
    s .= "255:0.296875:6074:6079 254:0.703125:6075:6076 ~-0.004047458272881795 251:0.203125:6077:6078 ~-0.021145094233587836 ~0.03177531189526943 241:0.12:6080:6081 ~0.013326335494351908 220:0.609375:6082:6087 100:1.265625:6083:6086 "
    s .= "202:1.1875:6084:6085 ~-0.03691785307752731 ~0.04033231808522017 ~0.0341932520063995 ~0.027480294492900126 127:-0.25:6089:6090 ~-0.05091896166031428 245:5.03030303030303:6091:6094 248:0.875:6092:6093 ~0.03148550688979221 "
    s .= "~-0.01637272753562065 ~-0.09197141432777355 255:-0.015625:6096:6097 ~0.04776921250178916 ~-0.04319257398048363 241:0.46:6099:6108 214:0.09375:6100:6103 184:0.15625:6101:6102 ~-0.07036439862871094 ~0.01247157674714939 "
    s .= "184:-0.15625:6104:6105 ~-0.06802010681227992 127:1.21875:6106:6107 ~0.0306967061223293 ~-0.05554539821099047 214:0.59375:6109:6110 ~0.028278785947355722 ~-0.04526892049159493 122:0.25:6112:6153 202:-0.03125:6113:6122 "
    s .= "229:0.125:6114:6121 229:0:6115:6118 28:0.40625:6116:6117 ~-0.006943770268627711 ~-0.04717557907664893 241:0.42:6119:6120 ~-0.07904121185805224 ~-0.010654903569888623 ~0.017628725222689913 148:0.203125:6123:6134 "
    s .= "249:1.8333333333333335:6124:6133 254:1.015625:6125:6128 139:2.09375:6126:6127 ~0.022917395335140422 ~-0.07946210294421581 56:-0.515625:6129:6130 ~0.016383646574394013 241:0.42:6131:6132 ~-0.05439407235402308 ~0.0041625460523311 "
    s .= "~-0.036293645516435394 70:0.46875:6135:6150 142:-0.21875:6136:6137 ~-0.04189691391505435 112:-0.078125:6138:6139 ~0.04337902351679626 112:0.609375:6140:6145 67:0.25:6141:6142 ~-0.038171189829328614 70:0.171875:6143:6144 "
    s .= "~0.046871880875617736 ~-0.03429465685314287 142:0.625:6146:6149 85:0.109375:6147:6148 ~-0.03438478486209871 ~0.026147781705469365 ~-0.02514092758468472 85:-0.203125:6151:6152 ~0.059875716987234144 ~-0.05008943014800848 "
    s .= "89:0.75:6154:6155 ~-0.026549880801743475 173:0.625:6156:6157 ~0.03183977163201619 ~-0.03983384956847833 256:0.9583333333333334:6159:6204 254:1.015625:6160:6191 235:-0.34375:6161:6164 244:1.85:6162:6163 ~-0.04023208886634824 "
    s .= "~0.03141669047727365 118:0.28125:6165:6182 50:0.34375:6166:6181 88:0.328125:6167:6174 205:-0.265625:6168:6169 ~-0.048776410338808335 245:3.5555555555555554:6170:6173 162:0.3984375:6171:6172 ~0.015291420012131494 "
    s .= "~-0.03122660222232826 ~-0.04564693945794698 145:0.375:6175:6178 67:0.640625:6176:6177 ~0.03566318635202331 ~-0.01275687700334336 61:0.59375:6179:6180 ~-0.04312331001743759 ~0.031926861245788675 ~-0.020674097369418786 "
    s .= "31:-0.46875:6183:6184 ~0.03705751871831126 249:0.16666666666666666:6185:6188 52:0.1875:6186:6187 ~0.020523430347153957 ~-0.02190577930528814 116:0.71875:6189:6190 ~-0.03289437752990237 ~0.02217549703746209 146:-0.109375:6192:6203 "
    s .= "247:0.234375:6193:6202 246:-0.390625:6194:6197 191:-0.984375:6195:6196 ~0.017685462390851323 ~-0.025082931127395375 124:0.0625:6198:6201 136:0.46875:6199:6200 ~0.030332271937252582 ~-0.049101895819095916 ~0.03697536489801478 "
    s .= "~-0.04319001486511942 ~-0.048513127560151 ~-0.043817195327236574 251:0.765625:6206:6231 245:1.5918367346938775:6207:6208 ~-0.052236856744316766 217:-0.125:6209:6212 107:-1.390625:6210:6211 ~0.031080150574321775 "
    s .= "~-0.03471987715228382 31:0.125:6213:6220 109:0.109375:6214:6217 133:0.484375:6215:6216 ~0.014636943692090155 ~-0.05112782192042773 105:-0.3671875:6218:6219 ~-0.028869736123240033 ~0.016301870304596698 241:0.16:6221:6226 "
    s .= "193:0.15625:6222:6225 187:0.4375:6223:6224 ~-0.01314340793697452 ~0.05568469257692552 ~-0.03272113434391221 112:1.28125:6227:6230 85:1.1875:6228:6229 ~-0.05812103048551462 ~0.003895979778783216 ~0.0082981418050536 "
    s .= "253:-0.04450757575757791:6232:6241 140:-0.09375:6233:6234 ~0.033677127515721404 241:0.42:6235:6238 138:0.2421875:6236:6237 ~-0.018019992500151686 ~-0.15738548554173892 238:0.296875:6239:6240 ~0.026878651522021263 "
    s .= "~-0.0504536504527247 67:0.015625:6242:6247 36:0.5390625:6243:6246 181:0.8125:6244:6245 ~-0.035026540595056624 ~0.00837415537549272 ~0.027068127424635158 245:3.5555555555555554:6248:6251 243:1.65:6249:6250 ~0.015043209504123953 "
    s .= "~-0.04648678612867962 ~-0.06040530588164599 243:2.05:6253:6298 190:-0.03125:6254:6267 241:0.52:6255:6264 202:0.484375:6256:6261 97:-0.03125:6257:6260 143:-0.171875:6258:6259 ~0.008160924183731029 ~-0.048797864561442035 "
    s .= "~-0.05137010904603363 104:-0.046875:6262:6263 ~0.03947827915322279 ~-0.04892475636469676 19:-0.078125:6265:6266 ~-0.02309003721588604 ~0.020460874849625096 184:-0.234375:6268:6269 ~-0.05740449640909129 49:0.53125:6270:6295 "
    s .= "85:1.125:6271:6292 217:-0.203125:6272:6273 ~-0.03109447828184646 202:0.21875:6274:6285 205:0.703125:6275:6284 169:0.390625:6276:6283 61:0.515625:6277:6282 238:0.21875:6278:6281 243:0.75:6279:6280 ~-0.006010173678523355 "
    s .= "~0.02817121918869317 ~-0.032953859382417204 ~0.036279927373495544 ~0.04232196269640459 ~0.049435772201781636 94:0.046875:6286:6287 ~-0.03212187297511289 82:0.296875:6288:6289 ~0.02402886267267932 251:0.796875:6290:6291 "
    s .= "~-0.04686414805737511 ~0.011620797329564718 163:-0.265625:6293:6294 ~-0.05161407221503309 ~0.026933225061235574 31:0:6296:6297 ~0.021315841688049883 ~-0.045101584183094956 ~-0.03497589407315708 159:0.5234375:6300:6345 "
    s .= "245:4.658536585365853:6301:6344 249:0.16666666666666666:6302:6323 253:-0.06875:6303:6304 ~0.02809884466996645 243:1.65:6305:6322 214:0.1875:6306:6311 1:0.28125:6307:6310 103:-0.125:6308:6309 ~-0.048423568517967114 "
    s .= "~0.024651275322339215 ~-0.02410442001668326 115:1.265625:6312:6321 16:0.46875:6313:6320 229:0.828125:6314:6319 127:1.015625:6315:6318 251:1.515625:6316:6317 ~-0.062173573668907293 ~0.02878064008016336 ~0.017055262756165455 "
    s .= "~0.03784241791304127 ~0.020743857845135858 ~0.04299784990374846 ~-0.030629723208880105 192:0.2734375:6324:6343 127:0.328125:6325:6332 2:0.0625:6326:6331 195:-0.2265625:6327:6328 ~-0.025382340578305337 154:0.0625:6329:6330 "
    s .= "~-0.010873894420517198 ~0.020293480772428374 ~-0.028687622790641083 187:0.3125:6333:6336 163:1.703125:6334:6335 ~-0.04206202263334191 ~0.04113428965776722 1:-0.265625:6337:6338 ~-0.05520370584853789 49:0.53125:6339:6342 "
    s .= "24:-0.0078125:6340:6341 ~0.030330393664432992 ~-0.01546115969474014 ~-0.04803452096903223 ~0.013015178476653361 ~-0.06906638080302217 ~-0.040050189627488374 70:0.609375:6347:6390 88:1.125:6348:6387 184:-0.21875:6349:6350 "
    s .= "~-0.03010307399040879 205:0.703125:6351:6384 251:1.328125:6352:6377 245:1.5918367346938775:6353:6354 ~-0.049892623889432684 241:0.1:6355:6358 91:0.125:6356:6357 ~-0.016553161901910047 ~0.05080177741250195 156:0.2578125:6359:6374 "
    s .= "255:0.234375:6360:6365 254:0.484375:6361:6362 ~-0.0035707087359168215 53:0.03125:6363:6364 ~0.04203625300437373 ~-0.011407957807977438 82:1.15625:6366:6373 220:0.609375:6367:6370 136:1.671875:6368:6369 ~-0.03430708454196766 "
    s .= "~0.015357981373931549 23:-0.46875:6371:6372 ~0.05122055899237382 ~-0.05084285617203356 ~0.015566892899155055 100:1.078125:6375:6376 ~-0.05335998140265339 ~0.02776588536622972 61:-0.046875:6378:6381 243:0.75:6379:6380 "
    s .= "~-0.061139783588660734 ~0.007468945389026774 85:1.796875:6382:6383 ~0.025003019468441925 ~-0.049643788061939614 208:0.6875:6385:6386 ~0.03997763043587227 ~-0.0033587162480590094 196:-0.234375:6388:6389 ~-0.02333411532634362 "
    s .= "~0.02370304958172044 178:0.15625:6391:6392 ~0.00033703906203528617 ~-0.043128165849996895 122:0.046875:6394:6425 124:-0.6875:6395:6396 ~-0.04941933820564413 253:-0.0897435897435912:6397:6404 245:1.8181818181818181:6398:6401 "
    s .= "250:1.2578125:6399:6400 ~-0.06404285197482183 ~0.020809532030522344 33:-0.1015625:6402:6403 ~-0.005091850384340407 ~0.040065060733175006 160:1.125:6405:6422 147:-0.1640625:6406:6407 ~-0.02498696981794568 246:0.671875:6408:6419 "
    s .= "108:0.1796875:6409:6418 139:0.640625:6410:6417 242:0.6499999999999999:6411:6412 ~0.018549508691405727 252:0.375:6413:6414 ~-0.046687709590506124 245:1.7971014492753623:6415:6416 ~-0.05327557969814112 ~0.024744921182742397 "
    s .= "~-0.01702363144767846 ~-0.03047237134433683 20:0.421875:6420:6421 ~0.03033222610884831 ~-0.04086251176727764 7:0.453125:6423:6424 ~0.021037730875724296 ~-0.030417710735304422 46:-0.25:6426:6427 ~-0.04892694656416858 "
    s .= "79:0.34375:6428:6435 88:0.234375:6429:6432 175:0.453125:6430:6431 ~-0.05244835867690232 ~0.012405959245741548 148:0.28125:6433:6434 ~0.007785177480459277 ~-0.040726639555468985 226:-0.15625:6436:6437 ~-0.042429212721428335 "
    s .= "169:0.109375:6438:6439 ~0.03066212402743797 ~-0.01130205994271391 191:-0.6875:6441:6450 52:0.25:6442:6447 211:-0.0625:6443:6444 ~-0.00964869517269684 190:0.453125:6445:6446 ~0.03464377132791903 ~-0.005296148301508185 "
    s .= "245:2.119047619047619:6448:6449 ~-0.05338571212791261 ~0.007808156572177254 255:0.234375:6451:6466 254:0.703125:6452:6461 246:-1.703125:6453:6454 ~-0.04742649936855459 245:1.6451612903225807:6455:6458 246:1.765625:6456:6457 "
    s .= "~-0.045016194864929124 ~0.035451636106072576 255:0.078125:6459:6460 ~0.015560335944770388 ~-0.008136420878018531 151:-0.03125:6462:6463 ~-0.01526148584783533 251:0.171875:6464:6465 ~-0.030960926716977807 ~0.04012677728406355 "
    s .= "132:0.0859375:6467:6482 146:-0.234375:6468:6477 134:-0.40625:6469:6472 157:0.765625:6470:6471 ~-0.040992898576935236 ~0.010326725056691532 221:-0.890625:6473:6474 ~-0.05191620642787188 145:-0.15625:6475:6476 ~-0.02285684485750626 "
    s .= "~0.023354241137799547 254:0.609375:6478:6479 ~0.014874926648867816 6:0.640625:6480:6481 ~-0.038199041470041044 ~0.04270179765569792 157:-0.234375:6483:6484 ~0.032597918200596473 15:0.5859375:6485:6486 ~-0.04170966758257055 "
    s .= "~0.013668535599340914 251:0.484375:6488:6505 34:0.0625:6489:6500 46:0.078125:6490:6497 109:0.171875:6491:6492 ~-0.036155584833780625 64:-0.375:6493:6494 ~-0.04893245904524011 91:0.1875:6495:6496 ~0.005667013011151675 "
    s .= "~0.03697670467215131 133:0.265625:6498:6499 ~0.044983256299010885 ~-0.04740084552166464 112:0.78125:6501:6502 ~-0.046512138133579725 103:0.546875:6503:6504 ~0.016071867648125984 ~-0.03728101402258193 203:0.609375:6506:6533 "
    s .= "255:0.296875:6507:6512 136:2.015625:6508:6511 254:0.765625:6509:6510 ~0.009586093823944705 ~0.030689490605764275 ~-0.02876864611898222 44:-0.109375:6513:6532 247:0.265625:6514:6529 218:0.203125:6515:6528 246:-0.390625:6516:6525 "
    s .= "245:1.9848484848484849:6517:6520 250:1.0859375:6518:6519 ~-0.08029858879956137 ~0.016046116839510852 146:-0.6875:6521:6522 ~0.026741978796416623 252:0.07500000000000001:6523:6524 ~-0.03759044594446167 ~0.013232111732402366 "
    s .= "50:-0.21875:6526:6527 ~0.0353616653078408 ~-0.01238233546698533 ~-0.04898721237824613 39:0.3984375:6530:6531 ~-0.055525036314861345 ~0.012595746132099734 ~-0.025517483852329062 ~-0.03530106786461178 245:5.03030303030303:6535:6580 "
    s .= "249:0.16666666666666666:6536:6557 253:-0.06875:6537:6538 ~0.026289180406228792 64:-0.25:6539:6540 ~-0.03730141114757054 73:0.203125:6541:6552 90:0.0859375:6542:6549 243:1.55:6543:6546 137:-0.953125:6544:6545 "
    s .= "~-0.016089584816898678 ~0.03358254694283044 72:0.1015625:6547:6548 ~-0.06142753827168408 ~0.0394589399495997 251:1.109375:6550:6551 ~-0.023528148510886394 ~0.019744508913995776 58:0.328125:6553:6556 154:0.421875:6554:6555 "
    s .= "~-0.03861451208353348 ~0.02791739119083458 ~-0.04230766743112674 17:-0.625:6558:6559 ~0.010513861416910845 121:-0.1875:6560:6563 112:1.5:6561:6562 ~-0.047139459657819786 ~0.0013544192017566651 127:0.140625:6564:6571 "
    s .= "226:-0.171875:6565:6566 ~-0.053129913250429296 112:0.28125:6567:6570 82:0.203125:6568:6569 ~-0.03744768867562991 ~0.01582375671576037 ~0.025742185106231597 46:0.453125:6572:6577 216:0.3203125:6573:6576 120:0.3984375:6574:6575 "
    s .= "~-0.034028516204631196 ~0.01638155789989242 ~0.003971143607000869 229:0.203125:6578:6579 ~0.03514312918161535 ~-0.035039047883673874 ~-0.08307080355281835 254:1.296875:6582:6623 184:-0.1875:6583:6586 241:0.58:6584:6585 "
    s .= "~-0.037971300856966206 ~0.009606435445049008 248:1.375:6587:6622 245:1.6451612903225807:6588:6591 113:0.5625:6589:6590 ~-0.04106194283697645 ~0.020744152919361183 162:0.3671875:6592:6617 144:0.1328125:6593:6614 "
    s .= "97:0.765625:6594:6613 205:0.703125:6595:6612 64:0.15625:6596:6605 154:0.28125:6597:6602 82:1.125:6598:6601 190:0.6875:6599:6600 ~-0.045898132316157914 ~0.04312044961599272 ~0.029347567479103137 145:-0.25:6603:6604 "
    s .= "~-0.06731374682357531 ~0.009881950398849185 169:0.265625:6606:6609 79:-0.03125:6607:6608 ~-0.018891857499069263 ~0.028058611623393567 127:0.390625:6610:6611 ~0.021490792137231346 ~-0.04049378016584675 ~0.028303247891786357 "
    s .= "~-0.035615335555846055 25:0.4375:6615:6616 ~0.02628555833536087 ~-0.02466847101800513 130:0.28125:6618:6619 ~0.02027537773559038 232:-0.0625:6620:6621 ~-0.08267683930857006 ~-0.014576458811663237 ~-0.04597142492489507 "
    s .= "50:-0.25:6624:6627 247:0.171875:6625:6626 ~0.001201186382492509 ~-0.04543424657292346 ~-0.056048151597070765 243:2.1500000000000004:6629:6672 190:-0.015625:6630:6647 241:0.52:6631:6642 202:0.484375:6632:6641 "
    s .= "184:0.078125:6633:6636 187:0.1875:6634:6635 ~-0.055097506471887395 ~0.025933012049440086 141:0.1171875:6637:6638 ~-0.028902076176273703 28:-0.125:6639:6640 ~0.05876372746847183 ~-0.030028501175534107 ~0.02348912459944279 "
    s .= "16:-0.03125:6643:6644 ~-0.016525242065237946 31:0.546875:6645:6646 ~0.03063333345965018 ~-0.03163042546270325 49:0.53125:6648:6669 184:-0.234375:6649:6650 ~-0.05665470443113723 85:1.125:6651:6668 191:0.59375:6652:6667 "
    s .= "217:-0.203125:6653:6654 ~-0.02872474049448397 202:0.125:6655:6656 ~0.018682414822640686 121:0.671875:6657:6666 160:0.890625:6658:6665 113:0.125:6659:6664 151:0.96875:6660:6663 199:1.015625:6661:6662 ~-0.048799593979748125 "
    s .= "~0.032563410834906416 ~0.026139214259842853 ~0.011541951819296695 ~0.0180619887691376 ~0.04214461098344896 ~-0.0388051713433209 ~0.02288325849529452 31:0:6670:6671 ~0.02049519787483197 ~-0.045762167366789876 252:2.825:6673:6674 "
    s .= "~-0.0779127430247176 ~-0.006360425283369692 251:0.765625:6676:6701 238:-0.09375:6677:6682 244:2.23:6678:6681 214:0.65625:6679:6680 ~-0.04212253415640752 ~0.020098105029820297 ~0.04749399195120429 245:1.5918367346938775:6683:6684 "
    s .= "~-0.048567619868405416 70:0.609375:6685:6700 64:0.5:6686:6695 184:0:6687:6688 ~-0.03746179893170878 13:0.265625:6689:6692 211:-0.109375:6690:6691 ~-0.04801678453183294 ~0.0125610627238434 151:1.46875:6693:6694 "
    s .= "~-0.047316453524855195 ~0.03620493232167931 66:0.3515625:6696:6699 169:0.1875:6697:6698 ~0.04202443357031144 ~-0.007978683257657533 ~-0.06540980157328974 ~-0.03196801888761872 191:-0.71875:6702:6707 13:0.34375:6703:6704 "
    s .= "~0.03037442102694167 157:0.59375:6705:6706 ~-0.07044691275691334 ~0.02765713023633547 254:0.984375:6708:6717 47:-0.109375:6709:6710 ~0.018506208522245746 241:0.46:6711:6714 190:0.09375:6712:6713 ~-0.05245109463886521 "
    s .= "~0.010615338608805047 142:0.21875:6715:6716 ~0.022719513707125175 ~-0.016867815699792312 194:-0.171875:6718:6721 246:-0.546875:6719:6720 ~-0.03727169283254653 ~0.014197609747428308 ~-0.04497944022982621 "
    s .= "245:5.03030303030303:6723:6768 249:0.16666666666666666:6724:6749 253:-0.06875:6725:6726 ~0.025652864539736038 64:-0.25:6727:6730 178:1.03125:6728:6729 ~-0.05727411014972718 ~0.023631838325572196 73:0.203125:6731:6744 "
    s .= "243:1.55:6732:6743 90:0.0859375:6733:6736 137:-0.953125:6734:6735 ~-0.015358984808353186 ~0.03222714741352153 241:0.58:6737:6742 9:0.2734375:6738:6739 ~-0.05698912179329511 91:0.28125:6740:6741 ~-0.038191593084339864 "
    s .= "~0.03654621858319811 ~0.03028830162988498 ~-0.02540494603009366 58:0.34375:6745:6748 145:0.21875:6746:6747 ~-0.031722003371585775 ~0.027359833242067855 ~-0.04144758908875481 50:-0.609375:6750:6755 51:-0.3828125:6751:6754 "
    s .= "106:1.609375:6752:6753 ~-0.04052414699915864 ~0.038847355782140464 ~0.015308384596566067 174:-0.0625:6756:6761 143:-0.03125:6757:6758 ~-0.038378137936510015 157:0.265625:6759:6760 ~0.03178300964762404 ~-0.029203859773271813 "
    s .= "122:0:6762:6765 118:0.671875:6763:6764 ~0.009432423327723434 ~-0.045281168177993374 89:0.734375:6766:6767 ~-0.025809970445332054 ~0.01786245711088653 ~-0.08185756572631309 159:0.3984375:6770:6813 251:0.484375:6771:6784 "
    s .= "46:0.078125:6772:6779 34:0.0625:6773:6778 109:0.171875:6774:6775 ~-0.03405109476663581 64:-0.375:6776:6777 ~-0.04819209254873616 ~0.020317147799086985 ~-0.03325183670263063 76:-0.015625:6780:6781 ~-0.05946727456311886 "
    s .= "244:1.21:6782:6783 ~-0.035770499866925536 ~0.00449693376284289 238:0.53125:6785:6808 184:0.8125:6786:6807 109:1.859375:6787:6802 2:0.296875:6788:6801 255:0.515625:6789:6798 109:0.515625:6790:6797 94:0.125:6791:6796 "
    s .= "94:-0.015625:6792:6795 21:0.5078125:6793:6794 ~-0.03162028157905558 ~0.030966082517528016 ~0.03521547509376546 ~-0.024341598666408375 ~0.0217608032982495 247:0.171875:6799:6800 ~0.00044815658993665927 ~-0.06315764298483151 "
    s .= "~-0.023929354739229258 84:0.2578125:6803:6806 160:1.15625:6804:6805 ~-0.05840423199819309 ~0.015527974450118859 ~0.02423889219316495 ~0.02504915644729976 243:0.75:6809:6812 254:0.984375:6810:6811 ~0.023486810995069014 "
    s .= "~-0.03326186039663641 ~-0.059592414095147574 255:0.078125:6814:6815 ~0.005844113911493907 ~-0.047857967382512655 256:0.9583333333333334:6817:6862 254:0.984375:6818:6843 211:-0.234375:6819:6822 43:0.0625:6820:6821 "
    s .= "~-0.037736116028763894 ~0.00491547012646848 248:1.375:6823:6842 133:2.453125:6824:6839 118:0.28125:6825:6832 49:0.453125:6826:6829 88:0.515625:6827:6828 ~0.011657900363705865 ~0.030215629887555426 178:1.359375:6830:6831 "
    s .= "~-0.03451300899852058 ~0.03801276682102703 163:1.328125:6833:6838 61:-0.359375:6834:6835 ~0.038541798419368445 173:0.125:6836:6837 ~-0.02676211643648227 ~0.006747984897092986 ~0.03787477431112967 228:-0.2578125:6840:6841 "
    s .= "~0.043507091168432585 ~-0.0706466692102428 ~-0.0435540704767308 146:-0.21875:6844:6861 247:0.234375:6845:6860 246:-0.390625:6846:6857 245:1.9848484848484849:6847:6852 109:1.140625:6848:6851 148:0.421875:6849:6850 "
    s .= "~-0.07768841046818489 ~0.0042738973069873796 ~0.03248654608782502 191:-0.71875:6853:6854 ~0.018761931703277154 84:-0.0546875:6855:6856 ~-0.0423797535323891 ~0.013501946062846014 100:-0.03125:6858:6859 ~-0.021363190869450887 "
    s .= "~0.0338699650541739 ~-0.03666581606997404 ~-0.035016033786066006 ~-0.04211325385294349 194:0.59375:6864:6909 86:0.546875:6865:6904 245:1.5806451612903225:6866:6869 113:0.609375:6867:6868 ~-0.06126152086464838 ~0.02535966363651947 "
    s .= "247:0.484375:6870:6899 251:0.203125:6871:6874 178:0.4375:6872:6873 ~-0.04362412485939053 ~0.005961846293011547 50:-0.75:6875:6876 ~0.01829920792274403 255:0.234375:6877:6888 246:-1.203125:6878:6879 ~-0.031225681747612217 "
    s .= "53:0.0625:6880:6881 ~0.02299975978592883 162:-0.0703125:6882:6883 ~0.03744700233961506 241:0.48:6884:6887 3:0.2421875:6885:6886 ~-0.024114260552383547 ~-0.10600494013747237 ~0.007437967054054511 254:0.515625:6889:6890 "
    s .= "~0.01953866483190209 26:-0.359375:6891:6896 247:0.234375:6892:6895 134:-0.40625:6893:6894 ~-0.015940316805238577 ~0.01585241734397295 ~-0.04672049284451134 244:1.475:6897:6898 ~-0.03636839571953432 ~-0.005392937703044027 "
    s .= "221:0.265625:6900:6901 ~-0.04729144987851721 98:0:6902:6903 ~0.0596512520749114 ~-0.044193095447690636 20:0.46875:6905:6908 120:0.0703125:6906:6907 ~-0.006908544115125512 ~0.03951405490899885 ~-0.01632514852608127 "
    s .= "~-0.03362430372018919 245:5.03030303030303:6911:6956 249:0.16666666666666666:6912:6925 253:-0.06875:6913:6914 ~0.02479859394943098 130:2.453125:6915:6924 228:0.3515625:6916:6921 242:2.05:6917:6920 217:-0.1875:6918:6919 "
    s .= "~-0.023900390867820996 ~0.014208970493506862 ~-0.04292630212685214 243:0.8500000000000001:6922:6923 ~-0.05617197946017541 ~0.007430060579859384 ~-0.07177782188068163 17:-0.09375:6926:6945 99:-0.1015625:6927:6934 "
    s .= "157:1.03125:6928:6933 40:0.265625:6929:6930 ~-0.041454180327447854 192:-0.2265625:6931:6932 ~-0.05055348186998862 ~0.0270077366129418 ~0.010920781984196194 127:-0.15625:6935:6936 ~0.03877732675625615 205:0.625:6937:6944 "
    s .= "91:-0.140625:6938:6939 ~-0.057605072609155455 127:0.34375:6940:6941 ~0.011353855887369804 109:0.609375:6942:6943 ~-0.04673690533634492 ~0.0005463676310641168 ~0.031319686166316515 190:-0.125:6946:6947 ~-0.05038730720221222 "
    s .= "175:0.234375:6948:6953 124:0:6949:6950 ~-0.025006280164705116 43:0.453125:6951:6952 ~0.0033065210046669155 ~0.04930283956794209 144:0.3046875:6954:6955 ~-0.044352830700911734 ~0.011323972213692739 ~-0.07950246535552313 "
    s .= "243:2.1500000000000004:6958:7001 238:-0.078125:6959:6968 142:0.03125:6960:6965 232:-0.203125:6961:6962 ~-0.021984242894173996 184:-0.125:6963:6964 ~0.03548992392940146 ~-0.002353083096067963 115:1.484375:6966:6967 "
    s .= "~-0.034044744068213534 ~0.018479345741556484 85:1.15625:6969:6996 254:1.015625:6970:6991 143:0.125:6971:6988 246:0.671875:6972:6987 245:1.6181818181818182:6973:6974 ~-0.0625362644205974 1:-0.421875:6975:6976 ~0.043810686212050996 "
    s .= "238:0.109375:6977:6978 ~0.017468802623101826 163:1.140625:6979:6986 179:0:6980:6985 55:1.359375:6981:6984 109:1.171875:6982:6983 ~-0.050268561411988155 ~0.004763103224972947 ~0.041426861708266496 ~0.014614195591412369 "
    s .= "~0.030991032814787975 ~0.036728295766674815 94:-0.046875:6989:6990 ~-0.051528213254954984 ~-0.004825505875091944 190:-0.03125:6992:6993 ~-0.04746058869730238 53:-0.984375:6994:6995 ~0.02478713605027259 ~-0.015551848325634807 "
    s .= "181:-0.046875:6997:6998 ~-0.01745130960191868 248:0.875:6999:7000 ~0.02957936590667969 ~-0.012410494085711118 252:2.825:7002:7003 ~-0.07600722090685079 ~-0.005518485289436537 251:1.328125:7005:7038 247:0.640625:7006:7037 "
    s .= "245:1.5806451612903225:7007:7008 ~-0.040624580416130485 172:-0.3125:7009:7012 116:-0.890625:7010:7011 ~0.024208450878296286 ~-0.04551299224911411 142:-0.359375:7013:7014 ~-0.03927950187768298 85:1.15625:7015:7030 "
    s .= "55:-0.59375:7016:7017 ~0.05558594685715909 112:1.625:7018:7029 158:-0.25:7019:7028 87:0.1015625:7020:7025 245:2.7045454545454546:7021:7024 211:0.28125:7022:7023 ~-0.00960484157958666 ~-0.051041820016577394 ~0.017743302771982446 "
    s .= "228:-0.4921875:7026:7027 ~0.044642056790645215 ~-0.06446837246344782 ~0.0035256261838265235 ~0.025764367198870486 245:5.03030303030303:7031:7036 248:0.875:7032:7035 127:-0.296875:7033:7034 ~-0.044728053188909635 "
    s .= "~0.02953783944262822 ~-0.017276208532973826 ~-0.08220600677255681 ~-0.04375129423715906 241:0.46:7039:7048 149:-0.21875:7040:7043 184:-0.171875:7041:7042 ~-0.05317789990413782 ~0.021609593654761138 87:0.6484375:7044:7047 "
    s .= "214:0.90625:7045:7046 ~-0.06024077064967967 ~0.030214791650284352 ~0.05044060471838427 214:0.59375:7049:7050 ~0.026372539580908967 ~-0.04040013235665063 159:0.5234375:7052:7097 127:2.421875:7053:7096 178:1.0625:7054:7093 "
    s .= "190:-0.125:7055:7060 251:0.765625:7056:7057 ~-0.03999744553374368 59:-0.1875:7058:7059 ~0.013728898622633275 ~-0.031040454072072288 243:2.25:7061:7092 202:0.21875:7062:7079 205:0.28125:7063:7078 241:0.6:7064:7075 "
    s .= "31:-0.359375:7065:7066 ~0.04407201584221543 148:0.265625:7067:7074 91:0.09375:7068:7073 190:0.03125:7069:7070 ~-0.05273471914932465 211:-0.15625:7071:7072 ~0.04571108835882321 ~-0.019966081194969218 ~0.01236026297967218 "
    s .= "~-0.05462983890475978 238:0.40625:7076:7077 ~0.026601446655448127 ~-0.05419810821050304 ~0.028329643575229407 136:1.09375:7080:7087 46:0.078125:7081:7086 94:0.046875:7082:7083 ~-0.028975256399981095 242:0.75:7084:7085 "
    s .= "~0.03264081773406656 ~-0.0403490408792023 ~-0.03885588143789162 250:0.6015625:7088:7089 ~-0.07472732059658807 160:0.265625:7090:7091 ~-0.04054096995832679 ~0.029110797691523443 ~-0.051127176414707654 205:-0.234375:7094:7095 "
    s .= "~-0.038041707869796874 ~0.023955963499297427 ~-0.05658574155132137 ~-0.036379110522574164 122:0.25:7099:7140 255:0.234375:7100:7119 249:1.8333333333333335:7101:7118 254:0.453125:7102:7117 221:0.203125:7103:7116 "
    s .= "85:1.1875:7104:7113 245:2.88:7105:7112 191:-0.421875:7106:7107 ~0.01030970121404244 208:0.203125:7108:7111 79:0.265625:7109:7110 ~-0.029483234399133442 ~0.012963742415975999 ~-0.05041281382161995 ~0.016150896220396584 "
    s .= "208:-0.25:7114:7115 ~-0.029045067885583965 ~0.029865811358869218 ~0.029280804643038612 ~0.030119757899753952 ~-0.04304383090218428 47:-0.375:7120:7125 254:1.296875:7121:7122 ~0.01202420028046634 191:-1.078125:7123:7124 "
    s .= "~0.0234829779440366 ~-0.017254509562567934 244:1.46:7126:7129 241:0.14:7127:7128 ~0.0016357260400671567 ~-0.031181112015793485 245:3.4761904761904763:7130:7139 241:0.56:7131:7138 160:0.390625:7132:7135 211:0.3125:7133:7134 "
    s .= "~-0.059910389900629295 ~0.02726848004850851 125:-0.25:7136:7137 ~0.04077339544930183 ~-0.022649613231949733 ~0.031120825775792917 ~-0.05230219169999806 89:0.75:7141:7144 79:0.703125:7142:7143 ~-0.03393792982678633 "
    s .= "~0.0004938023942464403 ~0.014145842095442557 70:0.609375:7146:7189 88:1.125:7147:7186 79:0.765625:7148:7181 235:-0.09375:7149:7158 251:1.828125:7150:7157 241:0.16:7151:7154 178:0.09375:7152:7153 ~-0.029699076810025645 "
    s .= "~0.039108629762606546 105:-0.8046875:7155:7156 ~0.03239961331749795 ~-0.05168771292520357 ~0.013865643007517353 214:-0.046875:7159:7162 223:-0.09375:7160:7161 ~0.013596566036736214 ~-0.04127342577076242 141:-0.4453125:7163:7164 "
    s .= "~-0.03900944300545619 98:-0.125:7165:7174 1:-0.328125:7166:7167 ~0.036451430738730486 178:-0.125:7168:7169 ~-0.05840991964144309 220:0.4375:7170:7171 ~0.0037700930165123904 243:0.6499999999999999:7172:7173 ~0.04695407966693939 "
    s .= "~-0.030362217327066395 202:0.25:7175:7178 88:0.234375:7176:7177 ~-0.01603272990153926 ~0.024477441560479284 254:0.046875:7179:7180 ~0.01411372546457829 ~-0.04284645123128852 37:-0.203125:7182:7183 ~-0.03045112375829644 "
    s .= "133:2.234375:7184:7185 ~0.023116876484508612 ~-0.06589825455451113 193:-0.03125:7187:7188 ~-0.00420446741769826 ~0.02751648757082206 178:0.15625:7190:7191 ~0.0017376890689149882 ~-0.04071161747901578 251:1.328125:7193:7224 "
    s .= "247:0.640625:7194:7223 245:1.5806451612903225:7195:7196 ~-0.038967804932369024 243:2.1500000000000004:7197:7222 171:-0.34375:7198:7201 244:1.875:7199:7200 ~-0.034693751479829234 ~0.03218931541937894 97:0.765625:7202:7221 "
    s .= "85:1.484375:7203:7216 254:1.265625:7204:7211 199:-0.140625:7205:7208 197:-0.703125:7206:7207 ~0.030140001330236893 ~-0.03044681798905842 153:0.5390625:7209:7210 ~0.009825986399532638 ~-0.0641881027209349 247:-0.015625:7212:7215 "
    s .= "56:-0.375:7213:7214 ~0.010871695911748795 ~-0.05212068729633871 ~-0.05079658675678762 127:-0.375:7217:7218 ~-0.051198030122551946 245:4.054054054054054:7219:7220 ~0.03209064172363562 ~-0.052564939638009414 ~-0.03263004187356369 "
    s .= "~-0.04869989682448557 ~-0.04260319869703793 241:0.46:7225:7234 190:0.09375:7226:7229 184:0.171875:7227:7228 ~-0.061278174403785635 ~0.024275637590551312 118:0.015625:7230:7231 ~-0.032649688100612216 118:0.296875:7232:7233 "
    s .= "~0.041158363399877745 ~-0.015393883165552059 214:0.59375:7235:7238 245:3.4761904761904763:7236:7237 ~0.02796520682165454 ~-0.06539592478881064 ~-0.038493117140859345 50:0.34375:7240:7281 168:0.0546875:7241:7260 "
    s .= "132:0.1796875:7242:7259 249:0.16666666666666666:7243:7244 ~0.008400978185474969 225:0.2734375:7245:7256 214:0.265625:7246:7251 61:1.015625:7247:7250 79:1.4375:7248:7249 ~-0.03523459061389258 ~0.01666675837611443 "
    s .= "~0.01649704089872672 112:1:7252:7255 242:0.6499999999999999:7253:7254 ~0.0003692272389777702 ~-0.06465847995321528 ~0.02460070380344795 112:0.765625:7257:7258 ~-0.012606999998331835 ~0.04711581840520579 ~-0.04371275161013955 "
    s .= "201:0.1796875:7261:7266 196:-0.03125:7262:7265 251:0.921875:7263:7264 ~-0.02940857546162373 ~0.017371743480455722 ~0.025613912264511512 243:0.55:7267:7272 49:-0.34375:7268:7269 ~0.042730245300659976 235:0.828125:7270:7271 "
    s .= "~-0.046856503034081794 ~0.047698586937475994 214:0.28125:7273:7278 242:0.35:7274:7277 114:0.1640625:7275:7276 ~0.029095499286842505 ~-0.12474336077269171 ~0.02098683702213418 109:1.03125:7279:7280 ~-0.06830124634223389 "
    s .= "~0.019703478632146335 89:0.9375:7282:7285 106:1.03125:7283:7284 ~-0.04571949219080291 ~-0.005708619003429877 ~0.02256470448361285 191:-0.03125:7287:7320 185:0:7288:7317 157:1.15625:7289:7312 139:0.59375:7290:7307 "
    s .= "245:1.970873786407767:7291:7298 113:-0.03125:7292:7295 251:1.203125:7293:7294 ~-0.05105590387987616 ~0.013853219767075535 41:-0.1875:7296:7297 ~0.044652321717706354 ~-0.02454523170826908 147:-0.1640625:7299:7302 "
    s .= "85:0.265625:7300:7301 ~-0.049167301529490164 ~0.0067921737615152175 98:-0.125:7303:7306 37:0.546875:7304:7305 ~0.02724137304478762 ~-0.030179393060226756 ~-0.01652362587451513 114:0.0703125:7308:7311 "
    s .= "249:0.16666666666666666:7309:7310 ~0.009020423451600292 ~-0.027151721340591736 ~-0.0641261112731765 133:2.453125:7313:7316 118:1.640625:7314:7315 ~0.023601214350260063 ~-0.05600056825869248 ~-0.03967282543647138 "
    s .= "30:0.0390625:7318:7319 ~-0.008753159196829181 ~0.03408512238505031 254:1.078125:7321:7332 190:0.6875:7322:7329 244:0.88:7323:7324 ~-0.046868880500861444 118:0.40625:7325:7328 208:-0.234375:7326:7327 ~-0.03316600379506428 "
    s .= "~0.0036310167529660696 ~-0.03137049146595115 223:0.15625:7330:7331 ~0.03766066548835878 ~-0.03428876986214664 ~-0.04818216180212058 49:0.859375:7334:7379 127:2.421875:7335:7378 251:0.765625:7336:7361 46:0.078125:7337:7350 "
    s .= "31:0.078125:7338:7349 211:-0.203125:7339:7340 ~-0.03263937094222644 115:0.203125:7341:7348 178:0.4375:7342:7347 61:0.4375:7343:7346 160:0.4375:7344:7345 ~-0.056609100474720835 ~0.005061769543957134 ~0.04015961685831393 "
    s .= "~0.02441545484817099 ~0.02351671138154237 ~-0.02201405303528632 145:-0.046875:7351:7354 88:-0.421875:7352:7353 ~0.06208031563125807 ~-0.053106554184202584 217:0.28125:7355:7360 196:0.25:7356:7359 127:0.1875:7357:7358 "
    s .= "~0.01253645768511736 ~-0.03728161221997361 ~0.022385389951186604 ~-0.04560287218261777 191:-0.09375:7362:7369 181:0.09375:7363:7368 252:0.32499999999999996:7364:7367 244:1.17:7365:7366 ~0.021370728097133113 ~-0.041127004545901596 "
    s .= "~0.02767653308410736 ~0.022215488575878257 20:0.453125:7370:7377 43:-0.171875:7371:7372 ~-0.029982747411031175 243:0.75:7373:7376 166:0.8125:7374:7375 ~-0.022161717853363856 ~0.052058484504401994 ~0.01958925045207461 "
    s .= "~-0.04040483882304539 ~-0.058928421444327854 ~-0.027649403293806354 255:0.296875:7381:7404 254:0.703125:7382:7393 85:1.15625:7383:7390 255:0.078125:7384:7387 86:0.875:7385:7386 ~-0.0014916564755086989 ~0.039334183038306963 "
    s .= "241:0.2:7388:7389 ~0.0027359227433932497 ~-0.032315752105089184 208:-0.25:7391:7392 ~-0.026171909739241717 ~0.02081423435737448 251:0.203125:7394:7395 ~-0.025577659917269964 244:1.14:7396:7399 147:-0.1328125:7397:7398 "
    s .= "~-0.037828413840573255 ~0.04405423531216673 160:0.015625:7400:7403 64:0.15625:7401:7402 ~-0.06747414961868085 ~0.02699571373606105 ~0.0173982847341623 122:-0.265625:7405:7426 95:0.125:7406:7425 155:-0.25:7407:7420 "
    s .= "85:1.265625:7408:7419 112:1.625:7409:7418 100:-0.328125:7410:7411 ~0.026119030233732934 55:1.25:7412:7417 164:-0.21875:7413:7416 154:0.5:7414:7415 ~-0.05086857285488003 ~-0.01182681510151734 ~0.019921226308037013 "
    s .= "~0.028413608197911396 ~0.028485642395805616 ~0.01836257355544627 62:-0.46875:7421:7422 ~0.04194578585274031 244:1.51:7423:7424 ~-0.015358986226479044 ~0.03684058818417206 ~-0.037593347933390565 ~-0.020582638061980074 "
    s .= "245:4.658536585365853:7428:7473 122:0.046875:7429:7466 41:0.5:7430:7465 246:0.609375:7431:7460 247:0.296875:7432:7457 253:-0.06161616161616242:7433:7436 245:1.8041237113402062:7434:7435 ~-0.036911037791207406 ~0.02537854891509588 "
    s .= "242:0.55:7437:7444 250:0.9765625:7438:7439 ~0.015845190587055934 205:0.09375:7440:7441 ~-0.043402230815050215 129:-0.2890625:7442:7443 ~-0.03279040791665426 ~0.020799620735917977 252:0.07500000000000001:7445:7450 "
    s .= "220:0.890625:7446:7449 79:1.03125:7447:7448 ~-0.05999550955208909 ~0.009655590494113755 ~0.04042395707162146 49:-0.140625:7451:7452 ~-0.0370006489507531 52:0.46875:7453:7454 ~0.01591355475470435 109:1.703125:7455:7456 "
    s .= "~-0.052413817861144 ~0.028250389662611314 240:0.421875:7458:7459 ~-0.05202360936860128 ~0.0005699638833244511 96:-0.1171875:7461:7462 ~-0.05160721572481322 119:0.078125:7463:7464 ~0.04035419480564659 ~0.005595927930823178 "
    s .= "~-0.04143699443554183 79:0.34375:7467:7468 ~-0.020881044680746006 238:-0.234375:7469:7470 ~-0.05373330901169702 169:0.15625:7471:7472 ~0.019724968078326924 ~-0.017349435633326245 ~-0.061274412076751585 "
    s .= "243:2.1500000000000004:7475:7518 248:1.375:7476:7515 184:-0.1875:7477:7482 241:0.58:7478:7481 229:0.546875:7479:7480 ~-0.04569853287559823 ~0.019530605556545105 ~0.010871423292473325 148:0.21875:7483:7496 217:-0.171875:7484:7487 "
    s .= "92:-0.59375:7485:7486 ~0.0212068129021454 ~-0.027328217924111012 88:0.953125:7488:7495 184:-0.140625:7489:7492 250:0.8203125:7490:7491 ~0.07702352830828983 ~-0.0015601504925793553 196:0.328125:7493:7494 ~0.0006718768628756919 "
    s .= "~0.028175190911976407 ~0.028482485815075006 70:0.46875:7497:7512 75:0.0703125:7498:7507 247:0.171875:7499:7506 202:0.875:7500:7505 112:-0.078125:7501:7502 ~0.03649276749694 64:-0.0625:7503:7504 ~-0.05369614185010568 "
    s .= "~-0.006486552615404185 ~0.036346569687881115 ~-0.05253848605317432 115:0.5625:7508:7511 106:0.78125:7509:7510 ~-0.021582186341425207 ~0.02506977289216569 ~0.029914827804936567 85:-0.203125:7513:7514 ~0.043293246935686584 "
    s .= "~-0.044716457483705514 112:2.015625:7516:7517 ~-0.05373511107702496 ~0.03580392671691857 252:2.825:7519:7520 ~-0.07289165912506092 ~-0.004367790041746059 256:0.9583333333333334:7522:7567 254:0.984375:7523:7552 "
    s .= "118:0.28125:7524:7539 49:0.34375:7525:7532 245:3.7777777777777777:7526:7531 205:-0.25:7527:7530 88:0.328125:7528:7529 ~-0.0457386580811236 ~0.007673970820196878 ~0.016204363354463854 ~-0.04115227942925552 244:1.75:7533:7536 "
    s .= "97:0.046875:7534:7535 ~0.004826488703051277 ~-0.04787380267768856 100:0.046875:7537:7538 ~-0.048872674241829714 ~0.046472728863279356 166:-0.09375:7540:7541 ~-0.04958812634850779 163:1.140625:7542:7549 220:0.890625:7543:7548 "
    s .= "127:0.109375:7544:7545 ~0.012316564225583276 242:0.25:7546:7547 ~0.04097659670609417 ~-0.027699612387935203 ~0.036478491265538864 205:0.359375:7550:7551 ~0.038852585518542954 ~-0.0277448462494786 146:-0.21875:7553:7566 "
    s .= "152:-0.1875:7554:7563 85:1.265625:7555:7562 211:0.328125:7556:7559 111:0.1015625:7557:7558 ~0.0015989909054839474 ~-0.045290844314351694 232:1.359375:7560:7561 ~-0.047330580724824683 ~0.043263341949999534 ~0.019237262141185433 "
    s .= "121:-0.046875:7564:7565 ~-0.033162224327075655 ~0.04048505105372727 ~-0.032604329648723576 ~-0.041089469447104454 124:-0.671875:7569:7570 ~-0.04401479374059925 159:0.5234375:7571:7612 255:0.234375:7572:7591 254:0.703125:7573:7582 "
    s .= "245:1.6451612903225807:7574:7579 246:1.734375:7575:7578 53:-0.5625:7576:7577 ~0.0347373964473552 ~-0.05249712024671931 ~0.03717234724004591 144:0.2421875:7580:7581 ~0.00009886946378461709 ~0.019180703050534403 "
    s .= "145:-0.0625:7583:7586 23:-0.03125:7584:7585 ~0.011069292209856273 ~-0.058631155801370384 251:0.203125:7587:7588 ~-0.016968873706845487 205:-0.21875:7589:7590 ~-0.035790208755218246 ~0.043551523630651255 122:-0.296875:7592:7599 "
    s .= "247:0.234375:7593:7594 ~0.008234352608560806 38:-0.59375:7595:7598 158:-0.328125:7596:7597 ~-0.039297600073308896 ~0.03884492284484061 ~-0.047290736892139605 254:0.515625:7600:7603 21:-0.1796875:7601:7602 ~-0.06010344658074721 "
    s .= "~0.024126682511555614 79:0.34375:7604:7607 88:1.421875:7605:7606 ~-0.04164499803928337 ~0.0006614403714372742 190:-0.1875:7608:7609 ~-0.05548148580567132 244:1.17:7610:7611 ~-0.028807425256968163 ~0.011723210872848333 "
    s .= "127:-0.484375:7613:7614 ~0.05258501984905559 ~-0.045906495917455846 251:0.828125:7616:7643 256:0.2653061224489796:7617:7642 64:1.359375:7618:7641 242:0.55:7619:7636 136:0.8125:7620:7627 208:0.578125:7621:7626 208:0.4375:7622:7625 "
    s .= "245:1.7403846153846154:7623:7624 ~-0.03449606131431714 ~0.016605235910078793 ~0.052800767955559595 ~-0.037019290789904256 202:0.4375:7628:7633 238:0:7629:7630 ~-0.05469050675193318 151:-0.15625:7631:7632 ~0.04582152556216401 "
    s .= "~-0.01910699912390112 112:1.40625:7634:7635 ~-0.018889992061155422 ~0.04483986941739235 1:-0.109375:7637:7638 ~-0.044899505334166055 4:0.125:7639:7640 ~0.009304474891403791 ~-0.04058164745486319 ~0.03437036917323185 "
    s .= "~-0.04396136047744768 252:0.32499999999999996:7644:7655 207:0.3203125:7645:7650 181:0.53125:7646:7649 37:0.3125:7647:7648 ~-0.014292888333022644 ~0.02186453521228625 ~0.025704163106796674 19:-0.390625:7651:7652 "
    s .= "~0.036430596125817526 38:-0.296875:7653:7654 ~-0.009705046510616738 ~-0.0762839282617204 214:0.59375:7656:7661 49:-0.296875:7657:7658 ~-0.023307926885300246 256:0.9166666666666666:7659:7660 ~0.02731100667897017 "
    s .= "~-0.04059626964490523 ~-0.048826445121092715 127:2.421875:7663:7708 251:1.328125:7664:7699 247:0.484375:7665:7696 249:0.8333333333333333:7666:7693 154:1.171875:7667:7690 238:0.109375:7668:7679 235:-0.078125:7669:7670 "
    s .= "~-0.013330093717915888 10:0.265625:7671:7678 61:0.453125:7672:7677 124:0.0625:7673:7674 ~-0.01145912334607923 127:1.03125:7675:7676 ~0.03637831714187689 ~-0.0316119036476082 ~0.04278439884210364 ~-0.025094548137183478 "
    s .= "242:1.15:7680:7689 220:0.609375:7681:7688 105:-0.2421875:7682:7683 ~-0.04923257626300467 100:-0.21875:7684:7685 ~0.03462530794245299 160:1.21875:7686:7687 ~-0.018213578827247917 ~0.034304107831754305 ~0.029932924854689954 "
    s .= "~-0.05598604966271922 127:-0.3125:7691:7692 ~-0.06640696660020201 ~0.023371393030233608 196:-0.078125:7694:7695 ~-0.04822337290021447 ~-0.006295361559560045 241:0.1:7697:7698 ~0.01746682140705682 ~-0.04197129981293585 "
    s .= "241:0.46:7700:7707 149:-0.21875:7701:7702 ~0.013381849938511296 214:1.28125:7703:7706 244:1.095:7704:7705 ~0.02371299257266951 ~-0.0570759698337447 ~0.04234078530478799 ~0.021408585015505938 ~-0.0526260501485776 "
    s .= "245:4.658536585365853:7710:7755 243:2.1500000000000004:7711:7754 249:0.16666666666666666:7712:7729 90:0.0859375:7713:7718 40:-0.25:7714:7715 ~-0.02145552255860219 73:0.203125:7716:7717 ~0.0257388581215461 ~-0.004036656074867852 "
    s .= "31:0.140625:7719:7728 241:0.4:7720:7725 82:0.328125:7721:7724 91:0.234375:7722:7723 ~-0.03256164548151463 ~0.03179111508906694 ~-0.06694436095389228 19:-0.21875:7726:7727 ~-0.03571988362615459 ~0.03347795963721104 "
    s .= "~-0.033082126027623 187:-0.3125:7730:7731 ~-0.040183820941698756 127:0.265625:7732:7745 25:-0.28125:7733:7734 ~0.03126692302997982 199:-0.15625:7735:7736 ~-0.04070077055430362 88:0.15625:7737:7740 65:0.15625:7738:7739 "
    s .= "~-0.0018033251270086874 ~-0.05398804153405878 214:0.609375:7741:7744 238:0.21875:7742:7743 ~0.016175253483000657 ~-0.033500478286107194 ~0.0468255612326159 216:0.1953125:7746:7753 211:0.484375:7747:7750 40:0.5:7748:7749 "
    s .= "~-0.0340702409576948 ~0.014885043234330318 232:0.484375:7751:7752 ~0.03150947847628606 ~-0.03523667439402329 ~0.0070017134841658295 ~-0.03209164667596201 ~-0.059715371311222815 254:1.296875:7757:7796 248:1.375:7758:7793 "
    s .= "184:-0.1875:7759:7762 241:0.58:7760:7761 ~-0.035583766401901466 ~0.010400406412006513 245:1.6451612903225807:7763:7768 113:0.5625:7764:7765 ~-0.03848568163056665 167:0.234375:7766:7767 ~0.03838736581132157 ~-0.02555203816326836 "
    s .= "222:-0.3984375:7769:7772 20:-0.84375:7770:7771 ~0.014502539027165046 ~-0.046776431905090794 44:0.890625:7773:7792 186:0.6171875:7774:7789 49:0.859375:7775:7788 168:0.0703125:7776:7785 247:0.140625:7777:7784 "
    s .= "215:-0.421875:7778:7779 ~0.024655280001624976 130:1.859375:7780:7783 249:1.1666666666666665:7781:7782 ~0.01014076100412799 ~-0.04689584678580596 ~-0.0485373997488451 ~-0.02415665487653129 244:2.385:7786:7787 ~0.01930578046747322 "
    s .= "~-0.05033636751690947 ~-0.02150636734317501 22:-0.046875:7790:7791 ~0.017172108376421497 ~-0.06235264423337215 ~-0.06197033186123224 225:0.4453125:7794:7795 ~-0.05368777632893901 ~0.03100651279976757 50:-0.25:7797:7802 "
    s .= "247:0.171875:7798:7801 246:-0.453125:7799:7800 ~-0.009280073025267163 ~0.02503402562389615 ~-0.04076022854959358 ~-0.05320693502566847 251:0.484375:7804:7823 31:-0.0625:7805:7814 241:0.14:7806:7809 109:0.171875:7807:7808 "
    s .= "~-0.04339851904160705 ~0.041039071260429966 166:0.390625:7810:7813 211:-0.015625:7811:7812 ~-0.03126260325930653 ~0.015498006703709663 ~-0.04910072312239339 238:1.09375:7815:7822 171:0.125:7816:7817 ~-0.03576702446194607 "
    s .= "159:0.1640625:7818:7821 175:-0.015625:7819:7820 ~-0.0565092077679492 ~0.02682526744396978 ~-0.040607621509854926 ~0.031120755754421747 203:0.609375:7824:7849 255:0.296875:7825:7826 ~0.011478935253573937 44:-0.109375:7827:7848 "
    s .= "247:0.265625:7828:7845 218:0.203125:7829:7844 246:-0.390625:7830:7841 245:1.9848484848484849:7831:7834 250:1.0859375:7832:7833 ~-0.07363946594474091 ~0.015444633904051331 146:-0.65625:7835:7836 ~0.022214899319177465 "
    s .= "241:0.54:7837:7840 222:0.3203125:7838:7839 ~-0.04695246017437897 ~0.018884764138548987 ~0.018204251449957742 121:-0.03125:7842:7843 ~-0.008122833404810155 ~0.032458268349695736 ~-0.045485846144988525 54:0.3984375:7846:7847 "
    s .= "~-0.047945805028166484 ~0.0130340060839542 ~-0.021696239047753543 ~-0.03214537435111417 251:0.765625:7851:7874 66:0.5703125:7852:7873 46:0.078125:7853:7868 184:0:7854:7859 244:1.62:7855:7856 ~-0.038675972125106095 "
    s .= "22:-0.03125:7857:7858 ~0.03720439151530457 ~-0.047803354684538335 163:0.53125:7860:7863 91:0.171875:7861:7862 ~0.002304151479462075 ~0.03234007762674261 244:1.49:7864:7865 ~-0.04195036302207307 46:-0.109375:7866:7867 "
    s .= "~-0.04011358892910681 ~0.03740881545337934 193:-0.0625:7869:7870 ~-0.04375991341231127 217:0.234375:7871:7872 ~0.0035393458262997384 ~-0.03632505119356141 ~-0.058995092422863084 184:0.484375:7875:7894 "
    s .= "245:3.3389830508474576:7876:7893 55:-0.21875:7877:7880 194:-0.25:7878:7879 ~-0.0027510309252308397 ~-0.05699056639989686 181:0.53125:7881:7892 49:0.359375:7882:7889 105:0.1171875:7883:7884 ~0.0193302364415366 "
    s .= "252:0.42500000000000004:7885:7888 46:0.703125:7886:7887 ~-0.048261743356860565 ~0.02880887464425093 ~0.021391574642230585 250:1.2578125:7890:7891 ~-0.052626570341934326 ~0.020680593321812386 ~0.028758483739175663 "
    s .= "~-0.04600665952940854 28:0.46875:7895:7896 ~0.021209278498710876 ~-0.0340607725344419 245:5.03030303030303:7898:7943 249:0.16666666666666666:7899:7914 253:-0.06875:7900:7901 ~0.023637898324886712 242:2.05:7902:7913 "
    s .= "228:0.3515625:7903:7908 130:2.453125:7904:7907 217:-0.1875:7905:7906 ~-0.02230875987637948 ~0.012521645029604123 ~-0.07502232090723004 243:0.8500000000000001:7909:7912 87:-0.0390625:7910:7911 ~0.004466138824719207 "
    s .= "~-0.07281228579815835 ~0.011963530727308725 ~-0.03787997820000923 17:-0.78125:7915:7916 ~0.013511323501322184 121:-0.1875:7917:7920 64:-0.046875:7918:7919 ~-0.01206721931098293 ~-0.050110532586388215 166:-0.34375:7921:7922 "
    s .= "~-0.0463617059725519 127:0.140625:7923:7930 124:0:7924:7927 26:-0.0625:7925:7926 ~0.006770783127771431 ~-0.043177939597511886 118:-0.09375:7928:7929 ~-0.022029355241490453 ~0.028433219099007225 22:0.09375:7931:7938 "
    s .= "19:-0.390625:7932:7935 124:0.46875:7933:7934 ~0.03520474605231287 ~-0.04814292592615254 252:0.42500000000000004:7936:7937 ~-0.042064971177262725 ~0.002322569125547089 145:-0.046875:7939:7940 ~-0.052803151251757656 "
    s .= "244:0.885:7941:7942 ~-0.04610735491112127 ~0.018933738413274472 ~-0.07100185891400759 254:0.984375:7945:7976 118:0.28125:7946:7967 50:0.34375:7947:7966 120:0.1328125:7948:7953 159:0.1484375:7949:7952 227:0.09375:7950:7951 "
    s .= "~0.012714839843728119 ~-0.01922154978171733 ~-0.028598214056315546 88:0.21875:7954:7965 175:0.453125:7955:7964 187:0.234375:7956:7963 241:0.6:7957:7962 76:0:7958:7961 191:-0.09375:7959:7960 ~0.02101939704867643 "
    s .= "~-0.07350283411046069 ~-0.07159495229823779 ~0.02310158039415509 ~0.023953678591806634 ~0.0389996748150701 ~0.03041133729415392 ~-0.018343103727020485 166:-0.09375:7968:7969 ~-0.0482641597829114 163:1.140625:7970:7975 "
    s .= "220:0.890625:7971:7974 241:0.1:7972:7973 ~0.025743174449951296 ~-0.01938371492314521 ~0.03324786800237511 ~0.023526902519569657 146:-0.109375:7977:7990 247:0.234375:7978:7989 246:-0.390625:7979:7986 191:-0.796875:7980:7983 "
    s .= "245:2.161764705882353:7981:7982 ~-0.03283525431882525 ~0.022923347965381674 31:0.03125:7984:7985 ~-0.004866475771495234 ~-0.04192717621131636 124:0.0625:7987:7988 ~-0.009183869497048372 ~0.030155916317410898 ~-0.03185633511260599 "
    s .= "~-0.035412991723977404 251:1.328125:7992:8021 247:0.640625:7993:8020 245:1.5806451612903225:7994:7995 ~-0.036985883982863434 243:2.1500000000000004:7996:8019 171:-0.34375:7997:8000 244:1.875:7998:7999 ~-0.03214969584297102 "
    s .= "~0.03016834019336913 97:0.765625:8001:8018 85:1.484375:8002:8015 255:0.234375:8003:8008 254:0.484375:8004:8005 ~0.0019345161435955376 191:0.234375:8006:8007 ~0.03198172728723899 ~-0.04179491625209112 241:0.12:8009:8012 "
    s .= "154:0.359375:8010:8011 ~-0.007215352120594463 ~0.038439125730000245 26:-0.484375:8013:8014 ~0.0013443511038641344 ~-0.027053180398924615 127:-0.375:8016:8017 ~-0.04663663637584301 ~0.025989389276765102 ~-0.028230222772788128 "
    s .= "~-0.044968969615206585 ~-0.03938840468643728 241:0.46:8022:8033 242:0.55:8023:8028 146:-0.265625:8024:8025 ~0.026340632434902325 232:-0.03125:8026:8027 ~-0.0641628341225978 ~0.00513180144634889 163:0.171875:8029:8030 "
    s .= "~-0.08010022390952466 226:0.484375:8031:8032 ~0.013349139555178536 ~-0.08113028435985477 209:0.5625:8034:8037 245:3.4761904761904763:8035:8036 ~0.026578757842653 ~-0.06207849620822521 ~-0.032848988966435476 254:1.296875:8039:8082 "
    s .= "248:1.375:8040:8081 256:0.9166666666666666:8041:8080 251:0.484375:8042:8053 31:-0.0625:8043:8048 241:0.14:8044:8045 ~0.03472157300389139 121:0.28125:8046:8047 ~0.0031859296918997702 ~-0.061086797502465665 238:1.09375:8049:8052 "
    s .= "219:0.1796875:8050:8051 ~-0.03170827226854346 ~0.0020485647211359566 ~0.03299721721728619 184:0.15625:8054:8069 252:0.42500000000000004:8055:8066 153:0.1328125:8056:8063 1:0.0625:8057:8060 82:0.25:8058:8059 ~-0.04754329449181041 "
    s .= "~0.002933745841569829 127:1.421875:8061:8062 ~0.028637580233498994 ~-0.05874919030789805 232:-0.0625:8064:8065 ~-0.07797752081513804 ~-0.016372048164181294 238:0.21875:8067:8068 ~0.029227562465145452 ~-0.03218207753164503 "
    s .= "28:0.484375:8070:8079 77:-0.125:8071:8072 ~0.025420922747432358 244:1.46:8073:8078 235:0.21875:8074:8077 148:0.296875:8075:8076 ~0.01657880740113594 ~-0.03641638065377536 ~-0.03940043354681407 ~0.025033928755203286 "
    s .= "~-0.02539753324797326 ~-0.03362285291829517 ~-0.03679726734334707 50:-0.25:8083:8084 ~-0.0051258856694441695 ~-0.05224502949605262 245:5.03030303030303:8086:8131 100:1.125:8087:8126 242:2.05:8088:8123 109:0.109375:8089:8096 "
    s .= "21:0.4296875:8090:8095 253:-0.2:8091:8092 ~0.03940613288706148 251:1.765625:8093:8094 ~-0.04275384338601812 ~0.021376852747953007 ~0.016459584157305265 147:-0.3828125:8097:8100 244:1.8:8098:8099 ~-0.0432249001259369 "
    s .= "~0.036423583484244744 146:-0.640625:8101:8104 234:0.4609375:8102:8103 ~0.023540351444600677 ~-0.019452141313692415 255:0.234375:8105:8110 254:0.453125:8106:8107 ~0.00142983521954706 151:-0.03125:8108:8109 ~-0.015900835339861315 "
    s .= "~0.035963574140969554 254:0.546875:8111:8112 ~0.019231197897695205 26:-0.359375:8113:8118 195:0.1328125:8114:8115 ~0.007209426982751917 221:-0.59375:8116:8117 ~0.00502943934106424 ~-0.05056070021378446 252:0.275:8119:8122 "
    s .= "190:0.828125:8120:8121 ~-0.049025312253320665 ~0.017506910357585212 ~-0.008790879842900853 245:2.682926829268293:8124:8125 ~-0.05259724535842985 ~0.02064143424295627 223:0.4375:8127:8130 1:0.4375:8128:8129 ~0.029343753194588807 "
    s .= "~-0.025313692309708525 ~-0.04051098747479424 ~-0.07031357462499448 127:2.421875:8133:8178 251:1.328125:8134:8169 247:0.640625:8135:8168 245:1.5806451612903225:8136:8137 ~-0.035688702555871525 34:0.6875:8138:8167 "
    s .= "100:1.078125:8139:8166 109:0.109375:8140:8145 21:0.4296875:8141:8144 58:0.5:8142:8143 ~-0.04597576864790973 ~0.02830090221293055 ~0.028103598312265977 241:0.12:8146:8155 154:0.0625:8147:8150 106:0.171875:8148:8149 "
    s .= "~-0.054102696730362256 ~0.016490313222239157 139:0.796875:8151:8154 245:1.7636363636363637:8152:8153 ~-0.043220062668732066 ~0.04104209108752517 ~-0.03871551880223567 88:1.171875:8156:8165 255:0.265625:8157:8162 "
    s .= "26:-0.09375:8158:8159 ~0.014615115934561999 88:0.59375:8160:8161 ~-0.028238755327941012 ~0.015460746836160923 26:-0.484375:8163:8164 ~-0.004364362762263262 ~-0.034172497340451406 ~0.01910377188235913 ~0.023729284666479042 "
    s .= "~-0.028752216092569 ~-0.038159112384642285 241:0.46:8170:8177 149:-0.21875:8171:8172 ~0.012435244712513008 87:0.6484375:8173:8176 214:0.90625:8174:8175 ~-0.05078995328990952 ~0.03042918401454353 ~0.04380325552871325 "
    s .= "~0.019801942084661798 ~-0.04972466608234882 96:0.8828125:8180:8225 254:0.984375:8181:8210 191:-0.421875:8182:8185 251:0.234375:8183:8184 ~-0.03056551425512946 ~0.019150615339142443 118:0.28125:8186:8203 49:0.34375:8187:8200 "
    s .= "64:0.015625:8188:8195 49:0.15625:8189:8194 58:0.609375:8190:8193 209:0.28125:8191:8192 ~-0.0005880019596775934 ~-0.04444847054416768 ~0.032182006378332205 ~-0.05585644280019778 245:3.5555555555555554:8196:8199 17:0.5625:8197:8198 "
    s .= "~0.01958668211891193 ~-0.032447008737315174 ~-0.04921033393818966 97:0.078125:8201:8202 ~0.0034377819147450015 ~-0.04574880290460184 244:1.01:8204:8205 ~-0.044332970737201376 245:2.020408163265306:8206:8209 "
    s .= "232:-0.140625:8207:8208 ~-0.06611165960276541 ~0.02581765019336338 ~-0.021575822723714392 146:-0.109375:8211:8224 247:0.234375:8212:8223 246:-0.390625:8213:8220 191:-1.078125:8214:8215 ~0.01872121315607668 31:0.03125:8216:8217 "
    s .= "~0.0006008821305541342 177:0.3359375:8218:8219 ~-0.042713607354885594 ~0.02635471647695129 100:-0.015625:8221:8222 ~-0.017275798403164157 ~0.026146289572399384 ~-0.030423078592322725 ~-0.03335091100140048 ~-0.05233966942031938 "
    s .= "243:2.1500000000000004:8227:8270 245:5.03030303030303:8228:8269 253:-0.09206349206349076:8229:8236 252:0.125:8230:8235 71:0.140625:8231:8234 36:-0.0546875:8232:8233 ~-0.04138351324892453 ~0.02708837196932073 ~-0.07399683777386969 "
    s .= "~0.026914629298691223 163:1.25:8237:8266 163:0.625:8238:8261 205:0.5625:8239:8258 124:0:8240:8243 43:0.171875:8241:8242 ~-0.007125304317084108 ~-0.04781248448460393 241:0.12:8244:8247 243:0.25:8245:8246 ~-0.022532266598801823 "
    s .= "~0.03512784134440683 220:0.890625:8248:8257 252:0.32499999999999996:8249:8256 37:-0.296875:8250:8251 ~0.03120089722614075 190:0:8252:8253 ~-0.05618950542383732 151:0.09375:8254:8255 ~0.01638808883023135 ~-0.030154508893650463 "
    s .= "~0.010219528337021635 ~0.03278990421883014 208:0.65625:8259:8260 ~0.03123801700032235 ~-0.013952760332765638 112:1.578125:8262:8265 51:0.0078125:8263:8264 ~-0.04902048287671401 ~-0.009626366944421393 ~0.03734306602513295 "
    s .= "70:-0.140625:8267:8268 ~-0.038163283501556525 ~0.026106453834118068 ~-0.06876667906689476 252:2.825:8271:8272 ~-0.06892602117058201 ~-0.0021551611522957013 251:0.484375:8274:8293 31:-0.0625:8275:8284 94:0.328125:8276:8283 "
    s .= "64:-0.375:8277:8278 ~-0.04705805803357942 245:2.0144927536231885:8279:8282 151:0.65625:8280:8281 ~-0.036051299822281786 ~0.043679312810904265 ~0.028870822777986083 ~-0.03752201602260276 238:1.09375:8285:8292 171:0.125:8286:8287 "
    s .= "~-0.03311348205082913 159:0.1640625:8288:8291 175:-0.015625:8289:8290 ~-0.054605065325302474 ~0.025377082359893346 ~-0.03942504254552098 ~0.0296806148267745 238:0.53125:8294:8317 253:-0.04450757575757791:8295:8304 "
    s .= "252:0.275:8296:8303 202:0.015625:8297:8300 220:0.296875:8298:8299 ~-0.048713717077029865 ~0.04115017643214339 245:1.8235294117647058:8301:8302 ~-0.030573794695186524 ~0.02610527116839442 ~0.028470561688779036 "
    s .= "238:-0.078125:8305:8314 6:0.390625:8306:8313 235:0.671875:8307:8312 232:0.734375:8308:8311 33:-0.7890625:8309:8310 ~0.03896912568876983 ~-0.04061450130269778 ~0.02515163188489805 ~0.03442561264786545 ~0.01318577196247632 "
    s .= "184:-0.234375:8315:8316 ~-0.047394181585856045 ~0.007642851733276862 243:0.75:8318:8319 ~0.003985436116648831 ~-0.054264688269049524 248:1.375:8321:8364 254:1.296875:8322:8361 243:2.25:8323:8360 118:0.28125:8324:8347 "
    s .= "181:-0.4375:8325:8326 ~-0.03960388019897762 153:0.7578125:8327:8346 178:1.078125:8328:8345 252:0.575:8329:8342 184:0.046875:8330:8335 31:0.40625:8331:8334 160:0.625:8332:8333 ~-0.03599634015443518 ~0.008281808034402515 "
    s .= "~0.0244372668062597 242:0.55:8336:8339 91:0.171875:8337:8338 ~0.006275492400117176 ~0.03552348405225105 157:0.6875:8340:8341 ~-0.02878102598250933 ~0.014709004475518329 145:-0.140625:8343:8344 ~-0.021605484462895022 "
    s .= "~0.027938134461883576 ~0.027268283322509287 ~-0.0468433119056322 166:-0.09375:8348:8349 ~-0.0459261900112542 22:0.609375:8350:8359 127:-0.03125:8351:8352 ~0.028416053067412256 49:-0.203125:8353:8354 ~-0.04793178791468091 "
    s .= "91:0.40625:8355:8356 ~-0.01526561638651188 250:0.6328125:8357:8358 ~-0.051031904134650745 ~0.020624788934229435 ~-0.04012527898237622 ~-0.03357430226188219 50:-0.25:8362:8363 ~-0.0050384679773264026 ~-0.050893159873316565 "
    s .= "112:2.015625:8365:8366 ~-0.053100277024441256 ~0.031657183494065176 122:0.25:8368:8411 246:0.640625:8369:8408 247:0.234375:8370:8405 245:1.5806451612903225:8371:8372 ~-0.05287270731731132 251:0.203125:8373:8374 "
    s .= "~-0.02155121394580468 127:1.875:8375:8402 191:0.21875:8376:8399 253:-0.07236842105263008:8377:8378 ~0.020703050119865472 242:0.55:8379:8388 205:0.09375:8380:8387 1:0.078125:8381:8384 136:0.625:8382:8383 ~0.007837993347615963 "
    s .= "~-0.039542705967083626 240:0.03125:8385:8386 ~0.0370387421590708 ~-0.02500795697593739 ~0.019813060758489296 134:-0.359375:8389:8392 157:0.78125:8390:8391 ~-0.05495544358182333 ~-0.0024557626346091875 40:-0.109375:8393:8396 "
    s .= "105:0.0703125:8394:8395 ~-0.046486086293808127 ~0.027236371648681063 25:0.203125:8397:8398 ~0.025700466375138717 ~-0.02431699215688958 254:0.203125:8400:8401 ~0.02225836770593265 ~-0.047863570100257324 191:-0.6875:8403:8404 "
    s .= "~0.018476213433544563 ~-0.05310677409162889 130:0.3125:8406:8407 ~0.009395676115408588 ~-0.03325552345034895 121:-0.15625:8409:8410 ~-0.019494291684957227 ~0.020397672959502726 86:0.765625:8412:8413 ~-0.022362109623439572 "
    s .= "~0.015274660430047104 159:0.5234375:8415:8460 127:2.421875:8416:8459 178:1.0625:8417:8456 190:-0.125:8418:8425 251:0.765625:8419:8420 ~-0.036645426408636265 59:-0.1875:8421:8424 1:0.1875:8422:8423 ~-0.010423176668125362 "
    s .= "~0.03726437245480756 ~-0.028745800086116047 217:0.21875:8426:8441 124:0:8427:8432 19:0.03125:8428:8429 ~0.00420821702348509 251:0.515625:8430:8431 ~-0.059210477189657024 ~-0.012104331710180518 121:0.09375:8433:8434 "
    s .= "~0.021416737344200746 235:-0.078125:8435:8436 ~-0.028312541085332828 245:3.3389830508474576:8437:8440 70:0.65625:8438:8439 ~0.01546378072867124 ~-0.04321722726941309 ~-0.051816956633642754 148:0.59375:8442:8453 "
    s .= "220:0.5625:8443:8452 184:0.734375:8444:8451 115:1.5625:8445:8450 127:0.359375:8446:8449 235:0.3125:8447:8448 ~-0.03795936428212801 ~0.015255221544638198 ~-0.05742946349299532 ~0.03764408030968769 ~0.02822388895128582 "
    s .= "~0.023060485331176384 103:1.34375:8454:8455 ~-0.06373709367812909 ~0.022477797913006737 205:-0.234375:8457:8458 ~-0.03525338299234735 ~0.021403006496036873 ~-0.04756429009669551 ~-0.03185726951045057 251:0.828125:8462:8491 "
    s .= "66:0.5703125:8463:8490 64:1.359375:8464:8489 242:0.55:8465:8480 31:-0.0625:8466:8467 ~0.013988904892044211 124:0:8468:8471 25:0.375:8469:8470 ~-0.05453877700575932 ~0.012488986107971809 169:0.15625:8472:8477 136:1.25:8473:8474 "
    s .= "~0.02386583749650291 166:0.109375:8475:8476 ~-0.06011971924191556 ~0.01356506613740122 136:1.4375:8478:8479 ~-0.04219874992529718 ~0.022997582644773657 31:0.109375:8481:8488 1:-0.109375:8482:8483 ~-0.04195384980973642 "
    s .= "196:-0.15625:8484:8485 ~-0.05977124694226045 252:0.07500000000000001:8486:8487 ~-0.01745989907175606 ~0.024795651555258685 ~-0.03858748852220847 ~0.03172800741623186 ~-0.05754602327566275 109:0.5:8492:8503 100:1.125:8493:8502 "
    s .= "137:0.625:8494:8499 172:0.453125:8495:8498 46:0.21875:8496:8497 ~-0.023081912716117522 ~-0.06711752400183323 ~0.012650261129580776 191:0.578125:8500:8501 ~0.03594680259033863 ~-0.04071647698722164 ~0.03508438044831675 "
    s .= "248:0.875:8504:8505 ~0.014450644530768567 219:0.2890625:8506:8507 ~-0.0383347558770088 ~0.016401665759483732 44:0.890625:8509:8554 89:0.640625:8510:8551 245:1.5806451612903225:8511:8514 113:0.609375:8512:8513 "
    s .= "~-0.06002125582705784 ~0.017910280152316074 122:0.328125:8515:8550 184:0:8516:8529 220:-0.09375:8517:8520 1:0.171875:8518:8519 ~-0.007095096899373181 ~0.03626147423395887 252:1.375:8521:8528 64:0.21875:8522:8525 "
    s .= "70:0.046875:8523:8524 ~-0.027211982155311877 ~-0.07571302298323568 151:0.171875:8526:8527 ~0.024457464137196877 ~-0.046811129826586945 ~0.024943690020498996 28:0.296875:8530:8543 211:-0.09375:8531:8534 251:0.984375:8532:8533 "
    s .= "~-0.02871115114779906 ~0.013194521366383525 142:1.671875:8535:8542 85:1.125:8536:8541 144:0.0859375:8537:8540 87:0.0234375:8538:8539 ~0.006557725847303679 ~-0.022469215341173437 ~0.018765223189191153 ~0.028784449545718162 "
    s .= "~-0.06234668437801703 244:1.58:8544:8549 106:0.578125:8545:8548 97:0.28125:8546:8547 ~-0.05062850567765226 ~0.026876129039871945 ~-0.04376275432945425 ~0.01711678318388357 ~-0.0219724691817376 176:0.75:8552:8553 "
    s .= "~0.025246584007040024 ~-0.039234163816803495 ~-0.05209951964681817 249:0.16666666666666666:8556:8577 178:-0.078125:8557:8562 251:1.328125:8558:8561 244:1.48:8559:8560 ~-0.05224440448222173 ~-0.0040861166690729775 "
    s .= "~0.02409928674469658 166:0.546875:8563:8570 253:-0.04278074866310145:8564:8565 ~0.030731890824091924 242:2.05:8566:8569 238:-0.390625:8567:8568 ~-0.05435292384577465 ~0.011740283283907856 ~-0.05265702663828936 "
    s .= "178:0.15625:8571:8572 ~0.021870148402086745 244:1.505:8573:8574 ~-0.057193258974581856 235:0.171875:8575:8576 ~-0.06272881900376978 ~0.035104346175827514 192:0.2734375:8578:8597 214:0.15625:8579:8588 79:0.46875:8580:8587 "
    s .= "49:0.28125:8581:8586 28:0.109375:8582:8585 202:0.625:8583:8584 ~-0.03521155936305572 ~0.014381503719720948 ~0.005385860722250896 ~-0.06670773358082117 ~-0.0016252444036070524 242:0.45:8589:8592 195:-0.0546875:8590:8591 "
    s .= "~-0.005337639182806875 ~0.030834708589139892 112:0.390625:8593:8594 ~-0.03774859338294628 178:0.359375:8595:8596 ~0.0157906246711885 ~-0.029576402731771395 238:0.15625:8598:8599 ~0.01719718467589292 178:0.546875:8600:8601 "
    s .= "~-0.03390665500542438 ~0.01894896464221759 248:1.375:8603:8646 245:4.658536585365853:8604:8645 85:1.15625:8605:8640 251:1.484375:8606:8639 241:0.14:8607:8616 154:0.359375:8608:8613 49:-0.15625:8609:8610 ~0.025703885492260683 "
    s .= "226:-0.109375:8611:8612 ~0.026687549851407963 ~-0.035602273761182655 208:0.546875:8614:8615 ~0.03893721952040314 ~-0.04005403254960713 220:0.890625:8617:8638 100:1.125:8618:8637 100:0.171875:8619:8632 244:1.115:8620:8625 "
    s .= "145:-0.0625:8621:8622 ~-0.020707547740055985 174:0.453125:8623:8624 ~0.026116687108249 ~-0.05473314853773096 163:0.28125:8626:8629 7:-0.015625:8627:8628 ~-0.015357420363158611 ~-0.06187397642703531 70:-0.09375:8630:8631 "
    s .= "~-0.053597131046795345 ~0.0174746934330017 151:0.046875:8633:8634 ~-0.0011506419609671017 196:1.484375:8635:8636 ~-0.04441086433182931 ~0.04107250822514388 ~0.024780656814041905 ~0.03055638717443637 ~0.011591394124059375 "
    s .= "208:-0.078125:8641:8644 2:-0.640625:8642:8643 ~0.0232727235982369 ~-0.028159348310610795 ~0.019057659841481653 ~-0.054162897086249065 112:2.015625:8647:8648 ~-0.05253469891537138 ~0.028838353966926335 119:0.125:8650:8689 "
    s .= "113:0.0625:8651:8684 245:1.6451612903225807:8652:8653 ~-0.04278928752797429 253:-0.09206349206349076:8654:8657 166:0.671875:8655:8656 ~0.02550744256897876 ~-0.032767212128416455 87:-0.0078125:8658:8671 177:0.2890625:8659:8670 "
    s .= "187:-0.28125:8660:8661 ~-0.0449722629124442 26:-0.640625:8662:8665 251:0.296875:8663:8664 ~-0.02229337965751015 ~0.021049035300931603 249:0.16666666666666666:8666:8669 84:-0.3359375:8667:8668 ~-0.03234247322809022 "
    s .= "~0.01460319440506692 ~-0.019272050948818894 ~0.02990960853069249 112:0.109375:8672:8677 91:0.125:8673:8676 34:0.0625:8674:8675 ~0.0047324748283648875 ~-0.0593496170172248 ~0.030185136208717885 232:0.328125:8678:8681 "
    s .= "251:1.953125:8679:8680 ~-0.045809991523203114 ~0.023406506751784874 223:0.046875:8682:8683 ~0.027494319359700016 ~-0.024829570437057788 245:2.1744186046511627:8685:8688 118:-0.28125:8686:8687 ~-0.05044937733846109 "
    s .= "~0.028060701966154084 ~-0.0021047023428588363 97:-0.125:8690:8693 11:0.03125:8691:8692 ~-0.063233219693494 ~-0.015251722755610837 122:-0.546875:8694:8695 ~-0.054681863472384976 ~0.00018279250424588724 127:2.421875:8697:8742 "
    s .= "249:0.16666666666666666:8698:8715 178:-0.078125:8699:8704 251:1.328125:8700:8703 244:1.48:8701:8702 ~-0.04991141084537576 ~-0.0019006100711814952 ~0.024873061576606986 166:0.296875:8705:8710 253:-0.04278074866310145:8706:8707 "
    s .= "~0.032007111777284956 211:-0.25:8708:8709 ~-0.05080608740167784 ~0.013039694090409169 250:0.7890625:8711:8712 ~-0.040506322963141266 25:0.3125:8713:8714 ~0.013785120343991725 ~-0.04184669955657198 122:0:8716:8737 "
    s .= "16:1.0625:8717:8736 195:-0.1796875:8718:8721 160:1.171875:8719:8720 ~-0.03478483880558015 ~0.016430053619413767 119:-0.21875:8722:8733 242:1.15:8723:8732 164:-0.15625:8724:8731 66:0.1171875:8725:8728 236:-0.453125:8726:8727 "
    s .= "~0.031429291997260016 ~-0.006637690753444489 185:-0.328125:8729:8730 ~-0.033525454024475515 ~0.021456552694704215 ~0.03928427180222958 ~-0.024390059619912013 121:-0.1875:8734:8735 ~-0.042607493896438635 ~0.0014901273876698363 "
    s .= "~-0.05136291993492301 6:0.546875:8738:8741 187:0.3125:8739:8740 ~-0.03268522573915033 ~-0.0017226776624250783 ~0.01755750564018176 ~-0.046931845585312396 194:0.609375:8744:8789 86:0.546875:8745:8788 "
    s .= "245:1.5806451612903225:8746:8749 113:0.609375:8747:8748 ~-0.057260962852148205 ~0.02236713775602601 247:0.484375:8750:8783 130:2.453125:8751:8780 238:-0.453125:8752:8753 ~-0.03497141396650431 79:1.234375:8754:8777 "
    s .= "157:1.1875:8755:8776 139:0.640625:8756:8763 110:-0.40625:8757:8760 242:0.55:8758:8759 ~0.0015132422292506117 ~-0.04989441141238469 50:0.078125:8761:8762 ~0.011756516707608671 ~-0.018259084770711052 85:0.921875:8764:8775 "
    s .= "184:0.25:8765:8772 226:0.125:8766:8771 142:0.421875:8767:8770 241:0.5:8768:8769 ~-0.057822733350768575 ~0.03291543536328445 ~0.017539881445350482 ~-0.060753644761789884 231:0.2734375:8773:8774 ~0.019333762846762262 "
    s .= "~-0.038310219536257045 ~-0.04946978424624248 ~0.014847898832413784 7:0.234375:8778:8779 ~0.02892947974387273 ~-0.014974286090106226 22:0.25:8781:8782 ~-0.055784391652833 ~0.025549389759328453 217:0.5625:8784:8787 "
    s .= "99:0.5234375:8785:8786 ~-0.05647653425107049 ~0.007394940318873675 ~0.03564860629134159 ~0.017278956152407567 ~-0.029457796206655215 255:0.296875:8791:8810 254:0.703125:8792:8803 85:1.15625:8793:8802 254:0.296875:8794:8797 "
    s .= "245:1.6285714285714286:8795:8796 ~-0.029469649179797643 ~0.00250503664657518 164:0.265625:8798:8799 ~-0.0367614164132447 62:-0.0625:8800:8801 ~0.03598541352802372 ~-0.0312933651836502 ~0.013806986182403821 "
    s .= "245:1.8842105263157896:8804:8805 ~0.035110611678142147 194:0.140625:8806:8809 244:2.385:8807:8808 ~0.017405278167631873 ~-0.03494505400845363 ~-0.06035009492205167 146:-0.125:8811:8832 247:0.171875:8812:8829 "
    s .= "199:-0.15625:8813:8816 12:-0.0859375:8814:8815 ~-0.04411774382937034 ~0.005859451687253112 109:1.171875:8817:8824 246:-0.828125:8818:8823 236:-1.125:8819:8820 ~0.018478228972499216 88:-0.0625:8821:8822 ~0.0022688765372478473 "
    s .= "~-0.0567687846940285 ~0.010972908947557296 250:0.6640625:8825:8828 121:0.078125:8826:8827 ~0.006178259037682305 ~-0.07819889366503642 ~0.023630085037737485 216:0.2734375:8830:8831 ~-0.04030972453093033 ~0.002286701296095226 "
    s .= "254:0.515625:8833:8834 ~0.015207069275287234 6:0.578125:8835:8836 ~-0.03335936736481609 ~0.01846626424766052 159:0.5234375:8838:8883 124:-0.6875:8839:8840 ~-0.042530046863970716 178:1.0625:8841:8882 184:1.046875:8842:8879 "
    s .= "55:1.25:8843:8878 28:0.78125:8844:8877 241:0.12:8845:8852 208:0.546875:8846:8851 154:0.390625:8847:8850 73:0.015625:8848:8849 ~0.019079203842830496 ~-0.03229475003158573 ~0.04047800557482634 ~-0.04987908593810731 "
    s .= "220:0.609375:8853:8876 217:0.21875:8854:8873 85:0.53125:8855:8862 251:1.546875:8856:8861 1:0.640625:8857:8860 205:0.703125:8858:8859 ~-0.03259756884454523 ~0.02133803523299501 ~0.02894826306365736 ~0.013140041436165954 "
    s .= "166:0.390625:8863:8870 235:-0.078125:8864:8869 187:0.046875:8865:8868 214:-0.265625:8866:8867 ~0.004935066279703303 ~-0.07675617351795283 ~0.02564707775583281 ~0.023540025248964175 211:-0.015625:8871:8872 ~0.024597547880661957 "
    s .= "~-0.048141039834991566 163:2.03125:8874:8875 ~-0.03165313855312207 ~0.0429173976207546 ~0.02140205223380862 ~-0.045364900224124996 ~0.020856210733602665 1:0.8125:8880:8881 ~0.02232398739715862 ~-0.05604157609481485 "
    s .= "~0.015050477660053192 ~-0.03082854132857124 248:1.375:8885:8928 254:0.984375:8886:8923 191:-0.421875:8887:8896 251:0.203125:8888:8889 ~-0.03531692477345994 211:-0.0625:8890:8893 226:0:8891:8892 ~0.009880091917736911 "
    s .= "~-0.04198683451806858 52:0.265625:8894:8895 ~0.03291890349935932 ~-0.007184059449416494 246:-1.140625:8897:8898 ~-0.04105976471401371 121:0.125:8899:8918 121:-0.125:8900:8905 249:0.5:8901:8902 ~0.0018669687685529458 "
    s .= "226:0.15625:8903:8904 ~-0.0520394170439199 ~0.005045034306695404 61:0.390625:8906:8917 53:0.0625:8907:8912 174:0.25:8908:8911 157:1.609375:8909:8910 ~0.024983495195071183 ~-0.04491235281521019 ~-0.015025261878750222 "
    s .= "241:0.54:8913:8916 97:-0.1875:8914:8915 ~0.02876128603599942 ~-0.05381498331804149 ~0.010327125978111452 ~0.03009568844856017 244:0.94:8919:8920 ~-0.04104314500600716 48:0.2421875:8921:8922 ~-0.01471762215060376 "
    s .= "~0.011372001314162591 146:-0.109375:8924:8927 73:0.34375:8925:8926 ~-0.006499518899243111 ~0.017777729868733973 ~-0.030245452921738164 201:0.2890625:8929:8930 ~-0.05266716601640096 ~0.0260178002007532 44:0.890625:8932:8977 "
    s .= "251:0.828125:8933:8956 64:1.359375:8934:8955 242:0.55:8935:8946 34:-0.0625:8936:8937 ~0.014068733890450068 124:0:8938:8941 238:0:8939:8940 ~-0.07394033173583105 ~-0.017007116541296385 250:0.9296875:8942:8945 169:0.25:8943:8944 "
    s .= "~0.019174068380008596 ~-0.03353109322381156 ~-0.018920034918091237 40:-0.109375:8947:8948 ~-0.043423228611355405 4:0.078125:8949:8954 252:0.125:8950:8951 ~-0.025491437082795273 31:0.109375:8952:8953 ~0.025910342503953833 "
    s .= "~-0.03200342658783076 ~-0.034066556551938756 ~0.028842736414831545 245:3.4761904761904763:8957:8974 252:1.025:8958:8971 243:1.45:8959:8968 160:0.734375:8960:8967 124:0.21875:8961:8966 199:-0.078125:8962:8963 "
    s .= "~-0.034458087765971514 244:1.16:8964:8965 ~0.03846231734885833 ~0.0015873212044543328 ~-0.01864998676356181 ~0.02063549856603429 151:-0.234375:8969:8970 ~0.023284630624214445 ~-0.07749910527791823 49:-0.296875:8972:8973 "
    s .= "~-0.03565619257702154 ~0.02815331875623553 244:1.55:8975:8976 ~0.020731846849959844 ~-0.04960963275581266 ~-0.050945158271143855 243:2.1500000000000004:8979:9020 153:0.7578125:8980:9019 255:0.234375:8981:8998 "
    s .= "254:0.703125:8982:8993 251:0.671875:8983:8988 67:0.625:8984:8987 64:0.53125:8985:8986 ~-0.010152635321579097 ~0.024287034101875573 ~-0.04627331377890831 191:0.578125:8989:8990 ~0.012428144059218604 18:-0.0703125:8991:8992 "
    s .= "~0.03839401063275663 ~-0.03936808951008356 151:-0.03125:8994:8997 47:0.03125:8995:8996 ~0.014676422221257089 ~-0.058436987239407795 ~0.031185269747182387 122:-0.359375:8999:9008 159:0.0390625:9000:9003 142:-0.453125:9001:9002 "
    s .= "~-0.048679035914561755 ~0.011037912663307933 25:-0.453125:9004:9005 ~0.03486360149506656 82:1.21875:9006:9007 ~-0.027325563400719344 ~0.027439341090869037 86:0.296875:9009:9016 159:-0.1484375:9010:9013 81:-0.2265625:9011:9012 "
    s .= "~-0.0431091335456767 ~0.015525224042182968 26:-0.390625:9014:9015 ~-0.0034487271595381053 ~-0.03602162209333445 206:0.375:9017:9018 ~0.01612972678444813 ~-0.039326623240946344 ~-0.042551124539791416 252:2.825:9021:9022 "
    s .= "~-0.06584134400316907 253:-0.06290174471992445:9023:9024 ~0.039345199841556246 ~-0.02796921917994713 245:5.03030303030303:9026:9071 249:0.16666666666666666:9027:9030 253:-0.06679035250463854:9028:9029 ~0.021528530242069223 "
    s .= "~0.0012905343983785152 184:-0.21875:9031:9032 ~-0.03161075111300962 127:0.28125:9033:9054 97:-0.015625:9034:9043 71:0.125:9035:9040 16:0.078125:9036:9037 ~0.012198000548192332 205:0.09375:9038:9039 ~-0.06168064055968895 "
    s .= "~0.007224951853087177 223:-0.21875:9041:9042 ~0.02165042342317364 ~-0.06459389406517115 49:0.25:9044:9051 251:0.203125:9045:9046 ~-0.0408798531881667 157:-0.09375:9047:9048 ~-0.03182830312060369 118:-0.109375:9049:9050 "
    s .= "~-0.02061176506911585 ~0.03210694632929211 256:0.1111111111111111:9052:9053 ~-0.03964099258393403 ~0.029825640923957588 205:0.625:9055:9066 79:0.359375:9056:9061 208:1.203125:9057:9060 201:0.6484375:9058:9059 "
    s .= "~-0.039047890510435064 ~0.028508950122424038 ~0.03944627918119359 148:1.03125:9062:9065 196:0.546875:9063:9064 ~-0.018287260906008792 ~0.030366227104122498 ~0.034350875435515876 28:0.28125:9067:9070 211:-0.28125:9068:9069 "
    s .= "~-0.0462841472886784 ~0.02976338260609772 ~-0.04703160966900535 ~-0.0631560930484131 130:2.453125:9073:9116 222:-0.3984375:9074:9079 34:0.3125:9075:9078 185:-0.875:9076:9077 ~0.02102388354412829 ~-0.03398813538068548 "
    s .= "~-0.06406221586318746 87:-0.1796875:9080:9083 130:1.140625:9081:9082 ~0.0028261037744197284 ~0.028232910547912483 246:-1.328125:9084:9085 ~-0.03713334835681646 255:0.234375:9086:9105 77:-0.0625:9087:9092 110:0:9088:9091 "
    s .= "203:-0.421875:9089:9090 ~0.035048632614565915 ~-0.010658342570450048 ~0.02947001773710107 97:-0.125:9093:9096 50:0.0625:9094:9095 ~-0.05543261699282881 ~-0.003834507782315241 31:0.140625:9097:9104 252:0.125:9098:9103 "
    s .= "200:0.25:9099:9102 226:0.015625:9100:9101 ~-0.03434637949093612 ~0.02318561785361418 ~-0.054169629038879785 ~0.025634121610617313 ~-0.016762692746407088 191:-0.59375:9106:9107 ~0.011856870155966266 132:0.0859375:9108:9113 "
    s .= "254:0.515625:9109:9110 ~0.024388763591478457 197:-0.03125:9111:9112 ~-0.001899666632642642 ~-0.034298100755269255 157:-0.390625:9114:9115 ~0.03842706257379931 ~-0.0313666152986665 22:0.234375:9117:9118 ~-0.05440489441928945 "
    s .= "~0.02232047649106758 96:0.8828125:9120:9165 248:1.375:9121:9162 254:1.296875:9122:9159 243:2.25:9123:9158 184:-0.21875:9124:9127 241:0.6:9125:9126 ~-0.03359198241359115 ~0.012810066124747624 222:-0.3984375:9128:9129 "
    s .= "~-0.022730378367746124 245:1.6451612903225807:9130:9137 113:0.5625:9131:9136 254:0.953125:9132:9133 ~-0.050308982204668375 137:0:9134:9135 ~-0.046713805616649694 ~0.03349159494273587 ~0.02164222057652286 133:1.984375:9138:9153 "
    s .= "253:-0.09206349206349076:9139:9140 ~0.02408488707478186 52:0.203125:9141:9144 79:0.6875:9142:9143 ~0.007161800942459082 ~0.030942310736524765 244:1.46:9145:9152 160:0.5625:9146:9151 79:0.46875:9147:9148 ~-0.036407330281722654 "
    s .= "106:0.640625:9149:9150 ~0.03905342100567236 ~-0.027391694069101233 ~-0.04122497059696983 ~0.016672312023785413 146:-0.59375:9154:9155 ~0.028327969100099323 61:0.4375:9156:9157 ~-0.047730302276069565 ~0.005440712404916383 "
    s .= "~-0.031732273335397784 50:-0.25:9160:9161 ~-0.004251542277028978 ~-0.048908274128913964 112:2.015625:9163:9164 ~-0.05181690195975637 ~0.026268743600570243 ~-0.04918052564464099 251:0.765625:9167:9192 66:0.5703125:9168:9191 "
    s .= "46:0.078125:9169:9186 184:0:9170:9175 244:1.62:9171:9172 ~-0.034959364219715905 22:-0.03125:9173:9174 ~0.03470971483668918 ~-0.04504673913143144 46:0:9176:9183 249:0.8333333333333333:9177:9182 31:0:9178:9181 211:-0.125:9179:9180 "
    s .= "~-0.051296258874590064 ~0.017472314775453822 ~-0.017115073931495885 ~-0.029869064182385503 103:0.21875:9184:9185 ~0.03913641323653962 ~0.0001979444902012185 193:-0.0625:9187:9188 ~-0.04049472193171359 217:0.28125:9189:9190 "
    s .= "~0.0002212115468683091 ~-0.03844660002764864 ~-0.05559679981859298 243:0.35:9193:9200 1:-0.34375:9194:9195 ~0.035780334638212515 244:1.11:9196:9197 ~0.020753861753031 31:0.4375:9198:9199 ~-0.056781287805234754 "
    s .= "~0.009284259846500494 50:-0.65625:9201:9202 ~0.023656966382488858 43:-0.171875:9203:9204 ~-0.01556855996612831 245:3.5555555555555554:9205:9212 249:0.16666666666666666:9206:9209 138:0.2734375:9207:9208 ~0.03156556686080674 "
    s .= "~-0.009851320437351839 196:-0.234375:9210:9211 ~-0.04211265713840112 ~0.0048957175050335896 ~-0.04758688192186526 124:-0.671875:9214:9215 ~-0.03982192578944732 88:1.125:9216:9253 79:1.234375:9217:9250 46:0.84375:9218:9249 "
    s .= "220:0.96875:9219:9246 178:1.078125:9220:9245 241:0.1:9221:9224 190:0.265625:9222:9223 ~-0.01705468025030233 ~0.033947032623563266 205:0.96875:9225:9244 193:0.078125:9226:9237 195:-0.1640625:9227:9228 ~-0.045472339483160734 "
    s .= "211:0.125:9229:9234 163:-0.140625:9230:9231 ~-0.03543459820534989 106:0.375:9232:9233 ~-0.006787328333446681 ~0.020778597347382195 253:-0.005766526019688929:9235:9236 ~0.0008274439123961549 ~-0.04186241984900563 "
    s .= "207:0.3046875:9238:9243 169:1.703125:9239:9242 163:1.34375:9240:9241 ~-0.022743120430950836 ~0.0302181891131827 ~0.050473766174401906 ~-0.05367060440944077 ~0.0228955953663625 ~0.0157147321022562 91:0.234375:9247:9248 "
    s .= "~-0.013925346786237473 ~0.04216119000037652 ~0.027682298541718123 133:1.625:9251:9252 ~0.02728089683374295 ~-0.01951397041335848 70:1.1875:9254:9259 148:0.328125:9255:9256 ~0.024227168251414133 30:0.3515625:9257:9258 "
    s .= "~-0.020248895565229227 ~0.0321518640775607 ~-0.04057578463994071 122:0.25:9261:9302 34:0.84375:9262:9301 251:0.484375:9263:9270 37:0.0625:9264:9265 ~0.002894956840040846 160:0.890625:9266:9269 196:0.609375:9267:9268 "
    s .= "~-0.04504764479833314 ~0.01764743906175988 ~0.006526720727072494 55:1.25:9271:9300 52:0.71875:9272:9297 46:0.703125:9273:9296 184:0.21875:9274:9291 241:0.58:9275:9288 147:0.0859375:9276:9283 127:0.90625:9277:9282 "
    s .= "242:0.95:9278:9281 243:0.45:9279:9280 ~-0.010360753568060647 ~0.029171418013184753 ~-0.08160907857735285 ~-0.04368131489885219 46:-0.359375:9284:9285 ~0.03186863095606309 244:1.15:9286:9287 ~-0.0042954841880425455 "
    s .= "~-0.05603473738462265 99:0.0390625:9289:9290 ~-0.022312199358085334 ~0.03060539987129713 242:2.05:9292:9295 249:1.5:9293:9294 ~0.01768397850654787 ~-0.026545202960792238 ~-0.03599165131737898 ~0.032211544532472304 "
    s .= "46:0.078125:9298:9299 ~-0.005114145706648204 ~-0.07800444322441169 ~0.030682099674267712 ~-0.02401175872529307 9:0.5703125:9303:9306 252:0.575:9304:9305 ~-0.0332018604486498 ~-0.0009292567904696195 ~0.021181099369520354 "
    s .= "159:0.5234375:9308:9353 145:-0.125:9309:9316 244:1.385:9310:9315 147:-0.1015625:9311:9312 ~-0.058773097733445905 73:-0.109375:9313:9314 ~0.007379817480109071 ~-0.04112881978248233 ~0.006078328954963477 "
    s .= "252:0.42500000000000004:9317:9346 242:1.15:9318:9343 207:0.3203125:9319:9340 133:2.390625:9320:9339 154:0.40625:9321:9334 166:0.625:9322:9333 226:-0.234375:9323:9324 ~0.03186386444555949 178:0.4375:9325:9332 46:0.765625:9326:9331 "
    s .= "175:1.28125:9327:9330 253:0.15178571428571427:9328:9329 ~-0.031858690697375035 ~0.03991266070792842 ~0.0406002866736468 ~0.03171585983219379 ~0.02255244906819823 ~0.03161502267395161 67:0.546875:9335:9338 160:-0.296875:9336:9337 "
    s .= "~-0.045287066221481945 ~0.01994289361878014 ~-0.03203072500157785 ~-0.04258284951050185 31:-0.28125:9341:9342 ~0.02165401420206239 ~-0.03178060846244867 130:0.109375:9344:9345 ~0.013954708029277507 ~-0.06474948373398426 "
    s .= "253:-0.02690166975881019:9347:9348 ~0.02961244117719434 202:0.1875:9349:9350 ~0.009809832845257386 213:0.2421875:9351:9352 ~-0.04757213520140002 ~0.01691953572349576 ~-0.02954725595554606 243:2.1500000000000004:9355:9398 "
    s .= "73:1.140625:9356:9397 127:2.421875:9357:9396 55:1.296875:9358:9395 52:0.984375:9359:9394 160:1.171875:9360:9389 147:-0.1796875:9361:9362 ~-0.020836927155706685 178:0.9375:9363:9388 25:-0.390625:9364:9365 ~0.025135196641892267 "
    s .= "205:0.625:9366:9385 244:1.985:9367:9380 202:0.203125:9368:9375 190:-0.125:9369:9370 ~-0.02918237262742206 241:0.58:9371:9374 180:0.2734375:9372:9373 ~0.009151371040274218 ~-0.04496994898490769 ~0.02208853785114828 "
    s .= "220:0.671875:9376:9379 100:-0.390625:9377:9378 ~0.03659540280126807 ~-0.0279971894345213 ~0.02588323176305776 13:-0.3125:9381:9382 ~0.03903141335137687 252:0.575:9383:9384 ~-0.060505457257315404 ~0.017146434819781113 "
    s .= "190:0.546875:9386:9387 ~0.034256826711652685 ~-0.03783140929783571 ~0.022771070102995433 61:-0.234375:9390:9391 ~-0.019340798130037355 185:0.46875:9392:9393 ~0.023841061595514274 ~-0.034205777021104194 ~-0.04218280773652196 "
    s .= "~0.0231090077443964 ~-0.04888382250220469 ~-0.03077426223801365 252:2.325:9399:9400 ~-0.07208291531380157 ~-0.005765382329563414 248:1.375:9402:9445 254:0.984375:9403:9428 191:-0.421875:9404:9411 251:0.234375:9405:9406 "
    s .= "~-0.02579076160998814 211:-0.0625:9407:9408 ~-0.004597607214625263 52:0.265625:9409:9410 ~0.03206791849222565 ~-0.00482127436886575 246:-1.140625:9412:9413 ~-0.037969579906299934 118:0.28125:9414:9421 49:0.34375:9415:9420 "
    s .= "145:-0.25:9416:9417 ~-0.021382747778895442 245:3.603448275862069:9418:9419 ~0.013016438960169652 ~-0.036806214297718486 ~-0.02115495989836448 244:1.01:9422:9423 ~-0.0421369370829541 232:-0.140625:9424:9425 ~-0.04972589921367039 "
    s .= "245:2.020408163265306:9426:9427 ~0.02392355879151653 ~-0.011521354865080633 146:-0.109375:9429:9444 246:-0.390625:9430:9439 191:-0.796875:9431:9436 245:2.161764705882353:9432:9435 148:1.390625:9433:9434 ~-0.04640838100557876 "
    s .= "~0.04531807432236376 ~0.01914477750709328 65:-0.421875:9437:9438 ~-0.03526559772619241 ~-0.0011628934411295486 100:0.0625:9440:9443 134:0.140625:9441:9442 ~0.0031057573531487657 ~-0.0484646238382172 ~0.025875257099894335 "
    s .= "~-0.028977805999359132 201:0.2890625:9446:9447 ~-0.051792953230899046 ~0.02492597283313286 26:-0.765625:9449:9456 13:0.3125:9450:9455 20:-0.515625:9451:9454 243:1.55:9452:9453 ~0.026839274490294142 ~-0.03828012967924127 "
    s .= "~-0.010167834029157108 ~-0.02281194184844033 246:-1.296875:9457:9460 244:1.965:9458:9459 ~-0.041186886178228375 ~0.013336488691363533 255:0.234375:9461:9484 77:-0.0625:9462:9469 110:0:9463:9468 245:1.9425287356321839:9464:9465 "
    s .= "~-0.032608174445704755 227:-0.375:9466:9467 ~0.03976193181748747 ~-0.002971553854962575 ~0.028394527706591517 97:-0.125:9470:9473 50:0.0625:9471:9472 ~-0.05243713602413561 ~-0.007904724462427699 31:0.140625:9474:9483 "
    s .= "252:0.125:9475:9480 200:0.25:9476:9479 226:0.015625:9477:9478 ~-0.03261462338803338 ~0.020539187040710692 ~-0.053663401665927805 208:-0.25:9481:9482 ~-0.03773053295559174 ~0.02842885340788542 ~-0.016386989926174166 "
    s .= "254:0.515625:9485:9486 ~0.015426956275232249 146:-0.234375:9487:9488 ~-0.003226215562975733 252:0.275:9489:9492 234:-0.1796875:9490:9491 ~0.005327934478620383 ~-0.04682740512814339 236:-0.15625:9493:9494 ~0.011753755950711486 "
    s .= "~-0.02488115545584349 119:0.125:9496:9535 113:0.0625:9497:9530 245:1.6451612903225807:9498:9499 ~-0.03918421378241482 253:-0.09206349206349076:9500:9507 202:-0.046875:9501:9506 250:1.0703125:9502:9505 61:0.140625:9503:9504 "
    s .= "~-0.08584110375481983 ~0.011227039404730159 ~0.02513911751025698 ~0.02881585267569611 87:-0.0078125:9508:9519 177:0.2890625:9509:9518 26:-0.640625:9510:9511 ~0.012209364195599783 249:0.16666666666666666:9512:9517 "
    s .= "241:0.14:9513:9516 214:0.25:9514:9515 ~0.04348615607435083 ~-0.031469068669358946 ~-0.005733774918060663 ~-0.020163929354815046 ~0.028414491405668638 229:0.5625:9520:9529 22:0.828125:9521:9528 88:0.109375:9522:9525 "
    s .= "139:0.140625:9523:9524 ~-0.03843248311909 ~0.007798520656524983 100:1.078125:9526:9527 ~-0.047695262131796284 ~0.011929394629474739 ~0.028922399808732364 ~0.015205778114106902 245:2.1744186046511627:9531:9534 "
    s .= "118:-0.28125:9532:9533 ~-0.0481213239900293 ~0.02595070365529722 ~-0.0015471267374353882 97:-0.125:9536:9539 49:-0.140625:9537:9538 ~-0.055266033444148745 ~-0.0072245219713043115 122:-0.546875:9540:9541 ~-0.05205806508775856 "
    s .= "~0.00013754395694528856 181:-0.703125:9543:9544 ~-0.047054136038457456 162:0.3671875:9545:9586 141:0.2578125:9546:9583 146:0.265625:9547:9582 132:0.2109375:9548:9579 242:2.05:9549:9576 245:5.03030303030303:9550:9575 "
    s .= "254:0.984375:9551:9560 251:0.296875:9552:9557 178:0.28125:9553:9554 ~-0.029618074730516076 82:0.375:9555:9556 ~0.033182181545173904 ~-0.037847995310370725 109:1.859375:9558:9559 ~0.014994800030674386 ~-0.009970898129329817 "
    s .= "146:-0.21875:9561:9574 246:-0.390625:9562:9571 152:-1.140625:9563:9564 ~0.024766360035758998 244:1.455:9565:9568 241:0.12:9566:9567 ~0.008711517818814005 ~-0.041956047476760926 152:-0.546875:9569:9570 ~0.022867713131237664 "
    s .= "~-0.02521294667957757 121:0.03125:9572:9573 ~-0.012009705070965413 ~0.03414305593482943 ~-0.025230188107054394 ~-0.06058879504633677 245:2.4157303370786516:9577:9578 ~-0.05818116697438774 ~0.01587009334037391 130:0:9580:9581 "
    s .= "~0.03319226387834574 ~-0.030761755526649427 ~-0.01926680005562648 147:-0.0234375:9584:9585 ~-0.02352548357277804 ~0.021082050739229603 255:0.078125:9587:9588 ~0.006529091957873896 ~-0.02942597249668796 44:0.890625:9590:9635 "
    s .= "88:1.125:9591:9630 100:1.078125:9592:9627 242:2.05:9593:9626 138:-0.5234375:9594:9595 ~-0.03777892141147356 46:0.75:9596:9625 205:0.703125:9597:9624 89:0.625:9598:9623 245:1.5806451612903225:9599:9600 ~-0.053919295969656035 "
    s .= "100:-0.21875:9601:9604 242:0.6499999999999999:9602:9603 ~0.02272720535964114 ~-0.030492231076865686 220:0.5625:9605:9620 252:0.575:9606:9617 204:0.2265625:9607:9614 242:0.55:9608:9611 202:0.359375:9609:9610 ~-0.010533040849939649 "
    s .= "~0.024010678587530976 160:0.828125:9612:9613 ~-0.044124036340009054 ~0.006977638523031092 31:-0.40625:9615:9616 ~0.031961695024686626 ~-0.048684784301888905 251:0.890625:9618:9619 ~-0.015135400188851992 ~0.030978524610102393 "
    s .= "245:1.9848484848484849:9621:9622 ~0.03847302746920296 ~-0.022033133115995304 ~0.020789433906775324 ~0.015121816992783374 ~0.02458452733199305 ~-0.035887089968652156 67:-0.34375:9628:9629 ~-0.054056774764749176 "
    s .= "~0.02344902305651532 127:0.578125:9631:9634 121:1:9632:9633 ~0.025562703499970526 ~-0.05059236767356681 ~-0.005559033659432531 ~-0.04873471465686616 96:0.8828125:9637:9682 248:0.875:9638:9671 115:1.15625:9639:9670 "
    s .= "142:0.703125:9640:9669 242:2.05:9641:9666 251:0.890625:9642:9657 124:0:9643:9648 34:-0.046875:9644:9647 46:0.0625:9645:9646 ~0.013039709492753238 ~-0.057046328206562504 ~-0.03790209099497799 245:1.5731707317073171:9649:9650 "
    s .= "~-0.05300719223725714 248:0.125:9651:9654 190:0.34375:9652:9653 ~-0.0001593478143160338 ~-0.05434103915630461 214:-0.1875:9655:9656 ~-0.04221056654069805 ~0.0164279098267249 106:0.578125:9658:9665 186:0.3359375:9659:9664 "
    s .= "235:0.109375:9660:9661 ~0.02235342433026201 181:0.53125:9662:9663 ~-0.03717038209838148 ~0.029431154163312163 ~-0.046561196970433164 ~0.020298645558877927 76:1.140625:9667:9668 ~-0.04334105854952483 ~0.03298040816774775 "
    s .= "~-0.02408206649348628 ~0.016415718082658872 214:0.578125:9672:9679 224:-0.171875:9673:9678 154:0.09375:9674:9675 ~-0.04544622408346111 151:0.1875:9676:9677 ~0.03497603002040944 ~-0.017618821618977657 ~-0.04353462063940406 "
    s .= "246:-0.765625:9680:9681 ~-0.04298986438375586 ~0.031293652492551505 ~-0.04776343255160621 194:0.609375:9684:9729 86:0.546875:9685:9728 245:1.5806451612903225:9686:9689 113:0.609375:9687:9688 ~-0.0547620830534629 "
    s .= "~0.020209167118593843 89:0.4375:9690:9727 130:2.453125:9691:9724 100:1.078125:9692:9721 159:0.2109375:9693:9712 34:0.84375:9694:9711 175:-0.40625:9695:9696 ~-0.03416856119394782 157:1.1875:9697:9708 246:-0.828125:9698:9707 "
    s .= "125:-0.671875:9699:9706 109:1.203125:9700:9705 245:2.2857142857142856:9701:9704 26:-1.453125:9702:9703 ~0.033291581632481596 ~-0.05602128902529983 ~0.013392177843839516 ~0.03358672244231841 ~-0.0352966480545167 "
    s .= "~0.005640757859388359 179:-0.125:9709:9710 ~0.025893987704165417 ~-0.004330084116257354 ~-0.031026746084406278 7:-0.34375:9713:9714 ~0.023351726932685196 256:0.03409090909090909:9715:9720 58:0.84375:9716:9719 "
    s .= "130:0.28125:9717:9718 ~-0.007917902492096248 ~-0.06114281306222489 ~0.020374075372195787 ~0.00900601966864687 22:-0.234375:9722:9723 ~-0.031553210142768504 ~0.025889193678412137 62:-0.59375:9725:9726 ~0.013560655007926534 "
    s .= "~-0.057244042920514396 ~-0.02718193448963684 ~0.01540868241683483 ~-0.02731875516496033 248:1.375:9731:9774 190:-0.015625:9732:9757 241:0.54:9733:9750 202:0.484375:9734:9747 115:-0.390625:9735:9736 ~0.022898751018818598 "
    s .= "25:0.375:9737:9744 141:0.2109375:9738:9741 35:-1.203125:9739:9740 ~0.021005237782672992 ~-0.05690928642328805 130:0.75:9742:9743 ~0.02018652733811123 ~-0.05080782912261065 121:0.03125:9745:9746 ~0.04360157711891772 "
    s .= "~-0.030802745863616632 72:0.0703125:9748:9749 ~0.035308842451139376 ~-0.03323726732019225 78:0.1171875:9751:9756 253:-0.014619883040936088:9752:9755 7:0.09375:9753:9754 ~0.020580838669295342 ~-0.03183145458433225 "
    s .= "~-0.03332161820173803 ~0.02394474304281758 184:-0.234375:9758:9759 ~-0.04964247285770061 243:1.95:9760:9773 202:0.21875:9761:9762 ~0.011253977375127382 190:0.375:9763:9770 52:0.4375:9764:9769 94:0.046875:9765:9768 "
    s .= "85:1.109375:9766:9767 ~-0.031821001735768746 ~0.034951603572019735 ~0.02168441115775605 ~-0.03628153912647774 136:1.375:9771:9772 ~-0.031146320508346148 ~0.013356614690349081 ~-0.03809909722654879 201:0.2890625:9775:9776 "
    s .= "~-0.051046183881243316 ~0.022809877607036094 119:0.453125:9778:9821 113:0.5:9779:9818 245:1.5806451612903225:9780:9781 ~-0.04744998176044158 253:-0.055855855855857804:9782:9799 252:0.275:9783:9794 58:0.046875:9784:9785 "
    s .= "~0.01960894956569271 220:0.125:9786:9793 124:-0.203125:9787:9788 ~0.022778507737457432 252:0.125:9789:9790 ~-0.07448259732154898 76:0.125:9791:9792 ~0.025475497470505894 ~-0.060303797319146785 ~0.009771855394617009 "
    s .= "214:0.71875:9795:9796 ~0.031769875472596146 238:0.109375:9797:9798 ~0.03099627367474328 ~-0.08616528991585203 108:0.1796875:9800:9815 190:0:9801:9810 202:0.515625:9802:9809 214:0.65625:9803:9808 136:-0.015625:9804:9807 "
    s .= "211:-0.078125:9805:9806 ~-0.048816129761611066 ~0.03239876722146308 ~-0.031781295037395615 ~0.023268069093848695 ~0.018856161806869127 73:0.6875:9811:9814 118:-0.046875:9812:9813 ~-0.012224398668564505 ~0.010504702510129048 "
    s .= "~-0.036614411040631595 36:0.5390625:9816:9817 ~-0.032269447148188156 ~0.014502495850006156 148:0.296875:9819:9820 ~0.027595022795775498 ~-0.011448493170206091 97:-0.078125:9822:9823 ~-0.05036721668674604 ~-0.004444967836385521 "
    s .= "72:0.7890625:9825:9870 132:0.6015625:9826:9869 222:-0.3984375:9827:9832 34:0.3125:9828:9831 185:-0.875:9829:9830 ~0.01998594619854239 ~-0.032170348342203524 ~-0.06004747382682273 87:-0.1796875:9833:9844 163:1.140625:9834:9843 "
    s .= "117:-0.2421875:9835:9840 22:0.328125:9836:9839 103:-0.125:9837:9838 ~-0.052101859620574564 ~0.0098768788710797 ~-0.05493532096325006 242:0.55:9841:9842 ~0.032918344599619925 ~-0.008520054762153227 ~0.035090272111485875 "
    s .= "246:-1.328125:9845:9846 ~-0.033851634833898823 255:0.234375:9847:9860 254:0.453125:9848:9855 255:0.078125:9849:9854 245:1.603448275862069:9850:9853 134:1:9851:9852 ~-0.058743065067527994 ~0.03749697196988227 ~0.014849546907198778 "
    s .= "~-0.010282616649516562 109:1.28125:9856:9859 191:0.15625:9857:9858 ~0.0351302385286645 ~-0.006844964288865174 ~-0.032861453826150376 14:-0.609375:9861:9862 ~0.010547305257661054 86:0.40625:9863:9866 247:0.296875:9864:9865 "
    s .= "~-0.011607039545822921 ~-0.04416840120225003 251:1.171875:9867:9868 ~-0.018330853872493325 ~0.02756561974706816 ~-0.03906105085101578 ~-0.03428189185382242 124:-0.671875:9872:9873 ~-0.03815136734286789 88:1.125:9874:9913 "
    s .= "79:1.234375:9875:9910 46:0.84375:9876:9909 220:0.96875:9877:9908 58:0.109375:9878:9891 120:0.0390625:9879:9886 241:0.18:9880:9885 154:0.390625:9881:9884 130:0.296875:9882:9883 ~-0.05389653723406084 ~0.004596621953454223 "
    s .= "~0.024887967496490408 ~-0.026499390011212487 91:0.859375:9887:9890 245:1.368421052631579:9888:9889 ~-0.04855349570034668 ~0.012639861580337315 ~-0.052229218540890854 61:0.125:9892:9897 151:0.28125:9893:9894 ~-0.05670639614603691 "
    s .= "109:0.75:9895:9896 ~-0.037573904734862926 ~0.025050724599619642 76:0.5:9898:9905 132:0.0546875:9899:9900 ~0.006361223319638886 73:0.390625:9901:9904 47:0.15625:9902:9903 ~-0.013529840844721789 ~-0.05589496670935992 "
    s .= "~0.02311462574352873 75:0.1640625:9906:9907 ~-0.05103835198300949 ~0.002006898031723568 ~0.02124055445727106 ~0.0250098213660928 133:1.625:9911:9912 ~0.025871853079904833 ~-0.017985634740694183 70:1.1875:9914:9917 "
    s .= "248:1.125:9915:9916 ~0.01808093993760807 ~-0.03240700633310765 ~-0.037283683890088265 254:1.296875:9919:9962 248:1.375:9920:9961 118:0.28125:9921:9940 132:0.5390625:9922:9939 120:0.0703125:9923:9924 ~-0.00041493704970265105 "
    s .= "194:0.09375:9925:9932 134:-0.078125:9926:9929 245:1.9848484848484849:9927:9928 ~-0.03599369948580038 ~0.012337911436474485 201:0.1796875:9930:9931 ~0.040073948348107284 ~0.008161736346185482 57:0.2890625:9933:9938 "
    s .= "187:0.359375:9934:9937 252:0.175:9935:9936 ~-0.06542264413889147 ~-0.011476026167399405 ~0.014751438112182975 ~0.0215552953722682 ~-0.03510273853710118 166:-0.09375:9941:9942 ~-0.04306252873674585 139:1.234375:9943:9960 "
    s .= "55:-0.5:9944:9945 ~0.032413765875636685 196:0.609375:9946:9957 142:0.53125:9947:9956 184:0.15625:9948:9951 82:0.734375:9949:9950 ~-0.05595451604471011 ~0.015028727585905314 244:1.08:9952:9955 70:-0.3125:9953:9954 "
    s .= "~0.04003343853109352 ~-0.03760743830026179 ~0.015805758420013107 ~-0.039549446666437116 175:0.625:9958:9959 ~0.035213670181292386 ~-0.026074567105853926 ~0.02171487669468883 ~-0.03423043926615227 50:-0.25:9963:9964 "
    s .= "~-0.004599152249828829 ~-0.04810847560622976 181:-0.703125:9966:9967 ~-0.04624873523516877 44:0.890625:9968:10011 88:1.125:9969:10010 100:1.125:9970:10009 241:0.14:9971:9986 154:0.359375:9972:9981 49:-0.15625:9973:9974 "
    s .= "~0.025511933406308935 103:0.15625:9975:9980 94:0.015625:9976:9977 ~-0.03899308989437395 251:0.484375:9978:9979 ~-0.021727051340639424 ~0.03165667475414615 ~-0.054206554989236745 208:0.546875:9982:9985 18:0.2578125:9983:9984 "
    s .= "~0.03923024788995738 ~-0.03681377864863369 ~-0.03255061705665965 245:3.4761904761904763:9987:10008 251:1.484375:9988:10007 58:1.46875:9989:10006 220:0.890625:9990:10005 100:0.171875:9991:10000 119:0.125:9992:9999 "
    s .= "195:-0.1796875:9993:9994 ~-0.03431377391918759 177:0.2265625:9995:9996 ~0.011741565584781745 91:-0.25:9997:9998 ~0.03542130299281791 ~-0.041787413187862166 ~-0.03166130222578511 245:2.985294117647059:10001:10004 "
    s .= "61:-0.25:10002:10003 ~0.013326416981951568 ~-0.03925248487134722 ~0.01380485315474696 ~0.02674963007565594 ~0.03143465674258162 ~0.011740836073675362 ~-0.05217466340227426 ~0.019888733190302307 ~0.01101780830027385 "
    s .= "~-0.0475120658139698 249:0.16666666666666666:10013:10032 178:-0.078125:10014:10019 251:1.328125:10015:10018 73:0.0625:10016:10017 ~-0.009708454844872138 ~-0.06261336239586156 ~0.023050583430541855 166:0.234375:10020:10021 "
    s .= "~0.014689295035923195 250:0.7734375:10022:10025 172:0.109375:10023:10024 ~0.005392359556534694 ~-0.06322227402964702 25:0.296875:10026:10031 244:1.01:10027:10028 ~-0.027259738010435977 248:0.375:10029:10030 ~0.03215910780472327 "
    s .= "~-0.039163152967137724 ~-0.034649625012303474 184:-0.21875:10033:10034 ~-0.030504013965049395 127:0.28125:10035:10048 97:-0.015625:10036:10041 71:0.140625:10037:10038 ~0.00272860974007786 223:-0.21875:10039:10040 "
    s .= "~0.02090543953374834 ~-0.06045094926737715 49:0.25:10042:10047 157:0.109375:10043:10046 138:0.1484375:10044:10045 ~-0.03558506651866105 ~0.031723948945378354 ~0.0262478618236149 ~-0.018035902462923983 38:-0.984375:10049:10052 "
    s .= "169:0.203125:10050:10051 ~0.03800305286289922 ~-0.029751505819992675 216:0.1484375:10053:10058 196:0.546875:10054:10055 ~-0.02921663677808319 238:0.203125:10056:10057 ~-0.027521514397235065 ~0.032997476379748474 "
    s .= "~0.0015006575364918816 127:2.421875:10060:10105 244:1.455:10061:10096 52:0.3125:10062:10091 17:0.421875:10063:10090 235:-0.09375:10064:10069 251:0.734375:10065:10066 ~-0.03859999286257359 244:1.115:10067:10068 "
    s .= "~0.028041633064740168 ~-0.02038968844096259 238:0.109375:10070:10079 243:0.6499999999999999:10071:10078 34:-0.234375:10072:10073 ~0.03682303211757025 139:0.890625:10074:10077 82:0.171875:10075:10076 ~0.020120366041552134 "
    s .= "~-0.028610204282320154 ~-0.05750882750620409 ~0.027029985280147037 94:0.046875:10080:10085 57:0.2421875:10081:10084 55:-0.5:10082:10083 ~0.025131734181382148 ~-0.04556125813984929 ~0.015514024991262525 85:0.109375:10086:10087 "
    s .= "~-0.0347413438174494 25:-0.078125:10088:10089 ~-0.01452525880159768 ~0.025719865871087783 ~-0.03153812026252438 157:-0.015625:10092:10093 ~0.017331316229952338 241:0.16:10094:10095 ~0.004554839104670918 ~-0.037836712154811436 "
    s .= "106:0.25:10097:10100 13:-0.0625:10098:10099 ~0.01854677129834432 ~-0.03439349908606767 79:-0.28125:10101:10102 ~-0.02679448914790917 128:-0.015625:10103:10104 ~0.023196777308677134 ~0.0014605253727412297 ~-0.041132458192353206 "
    s .= "251:0.828125:10107:10124 66:0.5703125:10108:10123 64:1.359375:10109:10122 242:0.55:10110:10111 ~0.0011558095986265937 40:-0.109375:10112:10115 27:0.375:10113:10114 ~-0.05197187043898796 ~0.014395547405272569 "
    s .= "31:0.109375:10116:10121 252:0.125:10117:10118 ~-0.02643494441544042 196:-0.15625:10119:10120 ~-0.04914094335351826 ~0.0244864657405667 ~-0.030568961839623605 ~0.028849316534454814 ~-0.05255916028725313 109:0.53125:10125:10130 "
    s .= "100:1.125:10126:10129 137:0.625:10127:10128 ~-0.02211811408786129 ~0.016559344396406748 ~0.03154463965487131 248:0.875:10131:10152 241:0.46:10132:10143 184:0.15625:10133:10142 17:-0.609375:10134:10135 ~0.0257869998696367 "
    s .= "31:0.453125:10136:10141 140:-0.25:10137:10140 21:0.0078125:10138:10139 ~-0.0495316907404561 ~0.03151733276590082 ~-0.07070475960323679 ~0.021840351854034823 ~0.020878202231134915 49:-0.265625:10144:10147 242:0.95:10145:10146 "
    s .= "~0.027626876179774686 ~-0.04535981453269202 214:0.71875:10148:10151 238:-0.375:10149:10150 ~-0.02394186138432336 ~0.03746101878318223 ~-0.04380471379034172 ~-0.019971209491595775 16:1.0625:10154:10199 122:0.046875:10155:10192 "
    s .= "238:0.15625:10156:10175 48:-0.0078125:10157:10162 202:0.484375:10158:10161 190:-0.03125:10159:10160 ~-0.032322645899483575 ~0.0007089660263658182 ~0.021473541458360557 243:0.6499999999999999:10163:10174 229:0.203125:10164:10173 "
    s .= "105:0.2265625:10165:10172 254:1.015625:10166:10171 127:0.890625:10167:10170 115:0.015625:10168:10169 ~-0.03176117482293949 ~0.029880095011606978 ~-0.04524753481596282 ~-0.037028402121446695 ~-0.04550955245577025 "
    s .= "~0.026782923321108168 ~0.024912693149178336 136:1.09375:10176:10187 91:0.1875:10177:10180 85:1.109375:10178:10179 ~-0.04090628932331228 ~0.01314954470223902 139:0.765625:10181:10184 226:0.203125:10182:10183 ~-0.019006932815506472 "
    s .= "~0.023680514197037175 251:1.453125:10185:10186 ~-0.06214672503870833 ~0.034241718459246194 42:-0.0078125:10188:10189 ~0.02520128757222036 208:0.34375:10190:10191 ~-0.02592902935239142 ~0.02571430943923348 79:0.34375:10193:10194 "
    s .= "~-0.018754726643375005 19:-0.203125:10195:10196 ~-0.03710383821458837 169:0.15625:10197:10198 ~0.021582747858113878 ~-0.017865826810451967 ~-0.023005409542384562 245:5.03030303030303:10201:10246 "
    s .= "249:0.16666666666666666:10202:10223 253:-0.06679035250463854:10203:10204 ~0.020597204764300263 245:1.7719298245614035:10205:10210 178:0.609375:10206:10209 55:0.25:10207:10208 ~0.035148105655169806 ~-0.015859336131871304 "
    s .= "~-0.03868570138739888 90:0.1328125:10211:10220 121:0.359375:10212:10217 245:2.2580645161290325:10213:10216 21:0.0234375:10214:10215 ~-0.028525408158916944 ~0.012900845448104643 ~0.017994903166895736 205:0.71875:10218:10219 "
    s .= "~-0.04119264230657133 ~0.020502720843791903 252:0.525:10221:10222 ~-0.04040089904038652 ~0.010703601790252315 17:-0.78125:10224:10225 ~0.01153382265873626 121:-0.1875:10226:10227 ~-0.02827798030998196 166:0.15625:10228:10241 "
    s .= "241:0.56:10229:10236 205:0.640625:10230:10235 127:0.140625:10231:10234 47:0.078125:10232:10233 ~0.0009935091915183063 ~-0.05405324601955284 ~-0.04547417892482497 ~0.018175089328842563 235:0.171875:10237:10240 "
    s .= "240:0.1875:10238:10239 ~-0.006274127979639631 ~0.03448998557163513 ~-0.03730200914240535 103:0.234375:10242:10243 ~0.020620523323916517 244:1.085:10244:10245 ~-0.0344433412933654 ~0.005248722208288922 ~-0.05721635497868598 "
    s .= "130:2.453125:10248:10291 244:1.455:10249:10276 52:0.3125:10250:10271 26:-0.9375:10251:10252 ~0.022877727032441647 246:-1.328125:10253:10254 ~-0.03681589153146234 17:0.421875:10255:10270 254:1.359375:10256:10269 "
    s .= "145:-0.0625:10257:10262 36:0.0859375:10258:10259 ~-0.032914915322606784 73:-0.109375:10260:10261 ~0.024081483036927708 ~-0.023268208003331514 193:0.078125:10263:10266 238:0.21875:10264:10265 ~0.02782546520617088 "
    s .= "~-0.020188621378845726 166:0.140625:10267:10268 ~-0.019485088120253995 ~0.01331926085337943 ~-0.025203943122985236 ~-0.03007975040020654 157:-0.015625:10272:10273 ~0.016379621788329923 241:0.16:10274:10275 ~0.004316262245287811 "
    s .= "~-0.03613963424917182 106:0.390625:10277:10284 184:0.15625:10278:10283 223:0.203125:10279:10282 124:1.71875:10280:10281 ~-0.052812240402366456 ~0.027032174033541603 ~0.015153234690895481 ~0.011009534022202313 "
    s .= "132:-0.1015625:10285:10286 ~0.02793881088734464 243:0.45:10287:10288 ~-0.02293659727074153 19:-0.1875:10289:10290 ~-0.020006720249444845 ~0.0216772887119151 22:0.234375:10292:10293 ~-0.050548250251149056 ~0.02132189555920129 "
    s .= "251:0.484375:10295:10306 31:-0.0625:10296:10299 94:0.328125:10297:10298 ~0.011508929426368292 ~-0.03242538025855283 112:0.453125:10300:10301 ~-0.03684389732577122 127:-0.015625:10302:10303 ~-0.05002964104840632 "
    s .= "97:0.328125:10304:10305 ~0.008114548727488664 ~-0.03485933058471876 238:0.53125:10307:10338 170:0.703125:10308:10337 253:-0.04450757575757791:10309:10320 252:0.275:10310:10317 202:0.015625:10311:10314 103:0.265625:10312:10313 "
    s .= "~-0.05047133463836023 ~0.01564262795702803 245:1.8235294117647058:10315:10316 ~-0.02676245815106981 ~0.025208763543331056 223:0.375:10318:10319 ~0.031533220377235195 ~-0.019869748886166966 94:0.015625:10321:10328 "
    s .= "168:0.0859375:10322:10323 ~-0.02425949888361256 73:0.0625:10324:10325 ~0.019759862779117208 193:-0.015625:10326:10327 ~-0.06323140359572571 ~0.01066616767724652 217:0.21875:10329:10332 37:0.453125:10330:10331 ~0.01615221696370836 "
    s .= "~-0.015598957516080252 235:0.453125:10333:10336 7:0.375:10334:10335 ~-0.03783563599563763 ~0.01678878937165742 ~0.024833953270452652 ~-0.044204967051604885 243:0.75:10339:10340 ~0.0025782326392750237 ~-0.04640736548982915 "
    s .= "243:2.25:10342:10385 73:1.140625:10343:10384 127:2.421875:10344:10383 85:1.15625:10345:10376 169:1.8125:10346:10375 205:0.703125:10347:10372 178:1.109375:10348:10371 211:0.109375:10349:10360 193:0.078125:10350:10355 "
    s .= "109:1.265625:10351:10352 ~0.013317774460221522 208:0.453125:10353:10354 ~-0.029086789930936743 ~0.041025445953627865 56:0.015625:10356:10359 113:0:10357:10358 ~-0.027692379759160658 ~0.025676681240150896 ~-0.04804192401826129 "
    s .= "241:0.1:10361:10362 ~0.020304071799325866 112:-0.03125:10363:10364 ~0.01871891985341519 160:0.890625:10365:10366 ~-0.03067917526205643 190:0.359375:10367:10370 94:0.21875:10368:10369 ~-0.012506920691373097 ~0.038769425743419635 "
    s .= "~-0.0386088680347213 ~0.02139572412926523 183:0.2109375:10373:10374 ~0.02373297126283788 ~-0.03264497241806826 ~0.041511255612642066 208:-0.1875:10377:10378 ~-0.02192014225291745 248:0.875:10379:10380 ~0.02236125956538826 "
    s .= "61:1.09375:10381:10382 ~-0.04263562032400661 ~0.018610080192881222 ~-0.043443145520470766 ~-0.02875823562484718 82:1:10386:10387 ~-0.0614902337547977 ~0.0048308703678889755 251:0.765625:10389:10410 217:-0.15625:10390:10393 "
    s .= "35:-0.96875:10391:10392 ~0.022751706324171353 ~-0.034625950239504634 31:0.078125:10394:10403 157:1.46875:10395:10400 46:0.078125:10396:10397 ~0.01276301076232153 136:0.515625:10398:10399 ~0.014311811751477275 "
    s .= "~-0.034972979448121784 151:-0.046875:10401:10402 ~-0.07984130881574965 ~-0.010782809383913653 160:1.5:10404:10409 193:0.15625:10405:10408 196:-0.015625:10406:10407 ~-0.04303802384773268 ~0.006831498998568814 ~-0.03878888174545919 "
    s .= "~0.020461279550907888 243:0.35:10411:10420 1:-0.34375:10412:10413 ~0.03231553591058463 244:1.11:10414:10415 ~0.019840022309645877 193:0.296875:10416:10417 ~-0.05849946540764725 127:0.0625:10418:10419 ~0.033505550346003415 "
    s .= "~-0.043639030714995426 50:-0.65625:10421:10422 ~0.02249744664620318 49:-0.203125:10423:10428 242:1.15:10424:10425 ~-0.001312825422027533 151:0.015625:10426:10427 ~0.0066826627887178885 ~-0.06021977330342028 "
    s .= "94:-0.265625:10429:10430 ~-0.024204353896000376 73:-0.265625:10431:10432 ~-0.03254512875287497 244:2.785:10433:10434 ~0.014000553314159368 ~-0.04054799446863615 255:0.296875:10436:10463 254:0.703125:10437:10456 "
    s .= "85:1.15625:10438:10455 112:1.625:10439:10454 89:0.9375:10440:10453 245:1.5731707317073171:10441:10442 ~-0.05393734331790321 100:1.265625:10443:10452 158:0.171875:10444:10449 242:0.55:10445:10446 ~-0.005570211093942469 "
    s .= "26:-0.609375:10447:10448 ~0.011421117987028358 ~-0.04726572917592787 122:0.328125:10450:10451 ~0.010278293598662655 ~-0.02491730536622537 ~0.024668617815532964 ~0.0249440177365743 ~0.020111922739909652 ~0.012924443629337024 "
    s .= "245:1.8842105263157896:10457:10458 ~0.03224160562789446 194:0.140625:10459:10462 118:0.546875:10460:10461 ~0.01703919220844134 ~-0.025244172895040606 ~-0.05185610263965887 159:0.3984375:10464:10481 146:-0.125:10465:10478 "
    s .= "145:-0.125:10466:10471 244:1.385:10467:10470 99:0.3515625:10468:10469 ~-0.052399676174951976 ~0.016609207621044127 ~0.004686802994031152 190:-0.015625:10472:10475 199:0.515625:10473:10474 ~-0.017285514008524 ~0.02926015736132681 "
    s .= "49:0.53125:10476:10477 ~0.013046834240461897 ~-0.03211747172159666 89:0.640625:10479:10480 ~-0.022983298999018218 ~0.026676645438342916 ~-0.04606500165143887 254:1.296875:10483:10526 191:-0.421875:10484:10491 "
    s .= "251:0.734375:10485:10488 250:0.9765625:10486:10487 ~0.011568548892459464 ~-0.016255599180858105 34:0.8125:10489:10490 ~0.02087393316092025 ~-0.039736448969598534 246:-0.859375:10492:10493 ~-0.03165355281005449 "
    s .= "232:-0.140625:10494:10497 118:0.296875:10495:10496 ~-0.005178273535807723 ~-0.050010622161115285 256:0.9433962264150944:10498:10525 252:0.42500000000000004:10499:10520 37:0.40625:10500:10515 244:1.115:10501:10506 "
    s .= "82:0.3125:10502:10505 246:-0.265625:10503:10504 ~-0.04155337474523282 ~0.02459035774368447 ~-0.021838547314484216 131:-0.109375:10507:10510 121:0.140625:10508:10509 ~0.019141696337479492 ~-0.0293460678446824 184:0:10511:10512 "
    s .= "~-0.059532206985302386 251:0.828125:10513:10514 ~-0.0031062902579446668 ~-0.0364247380957365 88:0.703125:10516:10517 ~0.03230177099170796 9:0.7109375:10518:10519 ~-0.0359995339955702 ~0.044552137095006106 235:0.171875:10521:10522 "
    s .= "~0.023501789322472086 253:-0.02592592592592524:10523:10524 ~0.013159520571776767 ~-0.03458217241919172 ~-0.04723780358058449 50:-0.25:10527:10528 ~-0.004628078877047366 ~-0.04702391324808186 245:5.03030303030303:10530:10575 "
    s .= "88:1.46875:10531:10570 100:1.078125:10532:10565 138:-0.5703125:10533:10534 ~-0.03645467844076095 122:0.09375:10535:10562 255:0.234375:10536:10543 254:0.703125:10537:10540 245:1.936842105263158:10538:10539 ~-0.014836850907474594 "
    s .= "~0.008184573446760879 246:-0.328125:10541:10542 ~-0.023345522724055337 ~0.0344975748091656 159:0.0390625:10544:10557 242:0.55:10545:10550 239:-0.359375:10546:10547 ~0.020390422204349494 139:0.015625:10548:10549 "
    s .= "~-0.04194884681482429 ~0.005409784873270273 246:-0.703125:10551:10552 ~-0.03553655430895008 23:-0.25:10553:10556 251:0.671875:10554:10555 ~-0.02478577602534054 ~0.025542268488090075 ~-0.03154519081910192 1:-0.4375:10558:10559 "
    s .= "~0.017916509794502673 251:2.453125:10560:10561 ~-0.03198851833323062 ~0.02735442449417047 89:0.734375:10563:10564 ~-0.019710813197550293 ~0.01605153434097917 22:-0.296875:10566:10567 ~-0.04865380880100732 1:0.265625:10568:10569 "
    s .= "~0.03127594718555105 ~-0.017990213882062563 70:1.1875:10571:10574 193:-0.140625:10572:10573 ~-0.009178310589226317 ~0.027730820217111537 ~-0.04644346081306601 ~-0.05639008973879445 253:-0.04450757575757791:10577:10590 "
    s .= "252:0.275:10578:10587 124:-0.140625:10579:10580 ~0.020363640656200752 184:0:10581:10584 34:0.40625:10582:10583 ~-0.07367825171784702 ~0.025794329953834346 36:0.2109375:10585:10586 ~-0.01753656501599157 ~0.02028958149932522 "
    s .= "214:0.71875:10588:10589 ~0.025041810994759203 ~-0.03850494470342675 243:1.55:10591:10618 245:2.020408163265306:10592:10597 175:-0.140625:10593:10594 ~-0.039878243465941245 94:-0.25:10595:10596 ~-0.036180009244083704 "
    s .= "~0.014124560118676834 34:-0.15625:10598:10601 121:0.484375:10599:10600 ~0.017108828864346812 ~-0.037012010476215815 245:2.985294117647059:10602:10613 241:0.18:10603:10608 242:0.35:10604:10607 250:0.9609375:10605:10606 "
    s .= "~0.02625171748303964 ~-0.024412177039492486 ~-0.02497451278290499 251:1.453125:10609:10612 61:1.375:10610:10611 ~-0.04423928496782452 ~0.01235086687308121 ~0.009147013903758673 148:-0.09375:10614:10615 ~0.0324520683159537 "
    s .= "22:0.171875:10616:10617 ~-0.02390327565831027 ~0.01350687001225489 245:2.130434782608696:10619:10620 ~-0.05909739042349459 134:0.03125:10621:10622 ~-0.046145836106731994 ~0.020479714165295555 119:0.453125:10624:10667 "
    s .= "113:0.5:10625:10664 245:1.5806451612903225:10626:10627 ~-0.045922021115654105 253:-0.055855855855857804:10628:10643 252:0.175:10629:10640 60:0.2109375:10630:10639 124:-0.140625:10631:10634 172:-0.1875:10632:10633 "
    s .= "~-0.04741492371766926 ~0.03466832059771585 238:0:10635:10636 ~-0.07255810626010047 245:1.9848484848484849:10637:10638 ~-0.04988231008140423 ~0.006328494017262255 ~0.025809019784709293 214:0.71875:10641:10642 ~0.02694030589976977 "
    s .= "~-0.038767107544024376 108:0.1796875:10644:10659 190:0:10645:10654 154:0.453125:10646:10649 12:-0.1953125:10647:10648 ~0.0028443534048208548 ~-0.041955386228434664 241:0.18:10650:10651 ~0.0330446154722086 211:0:10652:10653 "
    s .= "~-0.02305560965324646 ~0.01445863460532452 73:0.6875:10655:10658 184:-0.234375:10656:10657 ~-0.04438652547720698 ~0.007601208977367583 ~-0.03442840153729762 182:0.4375:10660:10663 85:1.46875:10661:10662 ~-0.03372033663099127 "
    s .= "~0.02206842233792036 ~0.022525071690599932 176:0.625:10665:10666 ~0.02236317615769232 ~-0.029710909262408543 97:-0.078125:10668:10669 ~-0.04872649419923776 ~-0.004082038930937891 248:1.375:10671:10714 254:1.296875:10672:10711 "
    s .= "256:0.9166666666666666:10673:10710 96:0.8828125:10674:10709 144:0.1328125:10675:10688 132:0.2109375:10676:10687 249:1.1666666666666665:10677:10684 242:2.05:10678:10683 79:0.3125:10679:10680 ~-0.0005059951137083781 "
    s .= "244:1.505:10681:10682 ~0.0020282829246154994 ~0.02810844474995804 ~-0.033677213088077466 2:-0.25:10685:10686 ~0.0017087165599944032 ~-0.047350954579600674 ~-0.028539904590682227 252:1.125:10689:10708 242:0.75:10690:10703 "
    s .= "231:0.1484375:10691:10692 ~0.030002619094067685 25:-0.40625:10693:10694 ~0.04168509950571615 113:0.5:10695:10702 139:0.359375:10696:10699 160:-0.03125:10697:10698 ~-0.05835026511697849 ~0.011418290587991708 "
    s .= "162:0.1171875:10700:10701 ~-0.0009442322979153284 ~-0.06147647383171117 ~0.0248223775343464 49:-0.046875:10704:10705 ~-0.04326800572401052 217:0.40625:10706:10707 ~0.010077892025466571 ~-0.05196399861909006 ~0.026535610666208565 "
    s .= "~-0.04403797346908374 ~-0.030843468225071825 50:-0.25:10712:10713 ~-0.004547386515068087 ~-0.04600047294726755 34:-0.25:10715:10716 ~0.02111762964016487 ~-0.0498056316326114 122:0.25:10718:10761 251:0.515625:10719:10734 "
    s .= "34:0.0625:10720:10733 91:0.1875:10721:10730 178:0.09375:10722:10725 205:0.34375:10723:10724 ~-0.04636349963840923 ~0.01744224878697979 190:0.359375:10726:10729 239:-0.03125:10727:10728 ~0.025749467628034362 ~-0.02692971526163268 "
    s .= "~-0.04627603321697474 222:-0.1328125:10731:10732 ~-0.024024457886237388 ~0.023536572084607493 ~-0.018390748216330622 184:0.15625:10735:10752 252:0.575:10736:10749 153:0.1328125:10737:10746 4:0.046875:10738:10743 "
    s .= "82:0.25:10739:10740 ~-0.04169844668338073 193:0.078125:10741:10742 ~0.0230012458255132 ~-0.03823067146780406 127:1.453125:10744:10745 ~0.01863765551649148 ~-0.04220923951562089 140:-0.4375:10747:10748 ~0.004345036909385128 "
    s .= "~-0.0439854903913635 43:-0.171875:10750:10751 ~-0.027905507983136693 ~0.02990704993030884 242:1.15:10753:10756 109:0.515625:10754:10755 ~-0.00014472309745253067 ~0.021077231336735967 245:2.130434782608696:10757:10760 "
    s .= "250:0.9921875:10758:10759 ~-0.055235362571732144 ~-0.003981645398428378 ~0.009791146965621328 89:0.75:10762:10763 ~-0.019532989405944192 ~0.013684734064832397 159:0.5234375:10765:10808 145:-0.125:10766:10775 244:1.385:10767:10774 "
    s .= "147:-0.1015625:10768:10769 ~-0.05554932425417761 73:-0.09375:10770:10773 17:-0.21875:10771:10772 ~0.02695926825837648 ~-0.020314769244655473 ~-0.038242011638719875 ~0.004819807000852363 252:0.42500000000000004:10776:10801 "
    s .= "242:1.15:10777:10798 207:0.3203125:10778:10793 154:0.40625:10779:10790 166:0.625:10780:10789 226:-0.234375:10781:10782 ~0.029959246469294477 187:0.640625:10783:10788 127:0.21875:10784:10787 178:0.4375:10785:10786 "
    s .= "~-0.013295299301212064 ~0.034429188190240226 ~-0.03997139434037843 ~0.0227021965283021 ~0.025510738986305754 67:0.546875:10791:10792 ~0.014353886602401174 ~-0.02984045678108171 139:0.515625:10794:10795 ~-0.00342870565654406 "
    s .= "180:0.4921875:10796:10797 ~-0.0640178673437282 ~0.008853142519856416 130:0.109375:10799:10800 ~0.014152258916983766 ~-0.055520732578007305 253:-0.02690166975881019:10802:10803 ~0.027383690273780403 202:0.1875:10804:10805 "
    s .= "~0.00998306278691282 213:0.2421875:10806:10807 ~-0.04355472163448414 ~0.01586986963893389 121:-0.453125:10809:10810 ~0.03175928792269899 ~-0.0393262974861551 130:2.453125:10812:10855 249:0.16666666666666666:10813:10824 "
    s .= "64:-0.25:10814:10817 178:0.640625:10815:10816 ~-0.03723172929787838 ~0.020721389655903425 115:1.15625:10818:10823 166:0.546875:10819:10822 175:0.359375:10820:10821 ~0.0010052484004584642 ~0.02602076019011459 "
    s .= "~-0.019903993298139817 ~0.026963764309234074 187:-0.3125:10825:10826 ~-0.03678816153724537 58:-0.0625:10827:10832 175:0.078125:10828:10829 ~0.02136915431687579 219:0.1484375:10830:10831 ~-0.024995081650328255 "
    s .= "~0.011324268516532858 245:1.7903225806451613:10833:10836 7:-0.015625:10834:10835 ~-0.05632078765510257 ~-0.01209797928352262 16:0.59375:10837:10854 40:-0.015625:10838:10845 28:-0.015625:10839:10842 238:0.234375:10840:10841 "
    s .= "~0.01778539226844628 ~-0.03152020045805865 142:0.171875:10843:10844 ~-0.05807217313896194 ~-0.005472386336189607 157:-0.09375:10846:10847 ~-0.04379198239179235 129:0.1015625:10848:10849 ~0.017397454948529813 "
    s .= "106:0.6875:10850:10851 ~0.009723199368877881 85:1.609375:10852:10853 ~-0.041865009365347094 ~0.029635331778154608 ~-0.041789557290332215 22:0.234375:10856:10857 ~-0.04905842169821262 ~0.019833055979613178 205:-0.25:10859:10860 "
    s .= "~-0.015068285480039535 154:2.453125:10861:10904 85:1.46875:10862:10895 16:1.0625:10863:10894 178:0.9375:10864:10893 211:0.125:10865:10876 214:-0.03125:10866:10873 253:-0.055855855855857804:10867:10868 ~0.014594443849904376 "
    s .= "226:-0.296875:10869:10870 ~0.02913061528670119 190:0.734375:10871:10872 ~-0.03396404787912081 ~0.03715089675878933 211:-0.234375:10874:10875 ~-0.04299422547744458 ~0.012951250290531402 241:0.1:10877:10878 ~0.01972013599306879 "
    s .= "91:1.296875:10879:10892 55:1.359375:10880:10891 55:0.34375:10881:10890 172:0.453125:10882:10889 184:0.875:10883:10888 253:-0.10779505582137183:10884:10885 ~0.011982178341611983 112:0.796875:10886:10887 ~-0.046998414687038165 "
    s .= "~-0.013697087419453333 ~0.02036437066203617 ~0.016307956628424602 ~-0.04640250750990133 ~0.028648901652502647 ~0.02942141232723818 ~0.01616734576109927 ~-0.040550823844265026 248:0.625:10896:10903 94:1.765625:10897:10902 "
    s .= "112:0.015625:10898:10901 248:0.125:10899:10900 ~0.029660872171183475 ~-0.04254388113582305 ~0.03134588931027252 ~-0.04109604793585263 ~-0.01672040404426456 ~-0.049359082410174906 251:0.765625:10906:10937 181:0.640625:10907:10932 "
    s .= "184:0:10908:10913 250:0.5703125:10909:10910 ~0.033075806553925884 64:0.625:10911:10912 ~-0.033971729162314036 ~0.01316572209088775 46:0.078125:10914:10921 46:0:10915:10920 31:-0.0625:10916:10917 ~0.016157662468355597 "
    s .= "85:0.3125:10918:10919 ~-0.04040470388225022 ~0.007366030195590585 ~0.028467540405679528 160:0.90625:10922:10927 184:0.421875:10923:10924 ~-0.03539587730669933 202:0.203125:10925:10926 ~0.03219467140925981 ~-0.03873590039704511 "
    s .= "52:0.296875:10928:10929 ~0.033876641019597684 103:1.296875:10930:10931 ~-0.051230805770985655 ~0.033919105168166826 130:1.296875:10933:10934 ~-0.035682340283892014 55:0.4375:10935:10936 ~0.022552130824568053 ~-0.03966186499388828 "
    s .= "243:0.35:10938:10943 1:-0.34375:10939:10940 ~0.030160611916720648 115:0.25:10941:10942 ~-0.007803131414466523 ~-0.060410424978712324 50:-0.65625:10944:10945 ~0.021818817865628424 49:-0.203125:10946:10949 242:1.15:10947:10948 "
    s .= "~-0.0011088931148757772 ~-0.03935461714430718 94:-0.265625:10950:10951 ~-0.02277609481000311 ~0.009663662333752057 255:0.296875:10953:10990 254:0.703125:10954:10975 85:1.15625:10955:10974 255:0.078125:10956:10969 "
    s .= "134:-0.515625:10957:10960 227:-0.875:10958:10959 ~0.01432822897004904 ~-0.04823434274233815 167:-0.015625:10961:10966 251:0.578125:10962:10965 203:-0.296875:10963:10964 ~0.02950827786680213 ~-0.04055357792757078 "
    s .= "~0.0341435988763889 245:1.603448275862069:10967:10968 ~-0.05008789886185529 ~0.001139461601927189 242:0.55:10970:10971 ~-0.001984261361994049 158:0.109375:10972:10973 ~-0.05839377508691467 ~-0.010187954345755831 "
    s .= "~0.01238651709040533 252:0.175:10976:10987 53:0.0625:10977:10984 113:-0.0625:10978:10981 179:-0.546875:10979:10980 ~0.021716823130088842 ~-0.029434616767213425 153:-0.0390625:10982:10983 ~-0.03369603250194165 ~0.03515693131224772 "
    s .= "64:0.234375:10985:10986 ~-0.06862267333827714 ~0.013017416263499277 133:1.28125:10988:10989 ~0.03452715321134485 ~-0.016718208291739558 233:0.296875:10991:10998 159:0.3984375:10992:10997 246:0.734375:10993:10996 "
    s .= "44:-0.078125:10994:10995 ~0.0004291288879969129 ~-0.02422308689542039 ~0.02089290773378212 ~-0.04154350283991394 ~-0.036514620638872744 245:5.03030303030303:11000:11045 249:0.16666666666666666:11001:11018 "
    s .= "253:-0.06679035250463854:11002:11003 ~0.019513264914939533 64:-0.25:11004:11005 ~-0.028813609574253732 85:-0.1875:11006:11007 ~0.0344096745913431 190:0.203125:11008:11009 ~0.006386537134396355 163:1.203125:11010:11017 "
    s .= "127:0.6875:11011:11014 251:1.859375:11012:11013 ~-0.054733220524879604 ~0.02570638473294027 142:0.671875:11015:11016 ~0.025715429203832116 ~-0.04310345531889623 ~0.025361249100539163 38:-0.96875:11019:11020 ~0.01621545008103554 "
    s .= "120:0.1640625:11021:11038 121:-0.1875:11022:11025 226:0.75:11023:11024 ~-0.03978339986102279 ~0.015267990400084076 166:0.171875:11026:11033 205:0.640625:11027:11032 48:0.3046875:11028:11031 217:0.140625:11029:11030 "
    s .= "~-0.017757593159882273 ~-0.05423414379373679 ~0.010956658593308261 ~0.017520700069732175 103:0.234375:11034:11037 208:0.1875:11035:11036 ~0.03571853130690907 ~-0.0017791481186456724 ~-0.01231949591105523 24:0.2578125:11039:11042 "
    s .= "99:-0.1484375:11040:11041 ~-0.03884609574269899 ~0.01880352133098701 193:0.078125:11043:11044 ~0.005988557489213287 ~-0.027920604460886 ~-0.05434035106058041 95:0.515625:11047:11092 89:0.578125:11048:11087 "
    s .= "245:1.5806451612903225:11049:11050 ~-0.03958623108809629 130:2.453125:11051:11084 34:0.84375:11052:11083 55:1.25:11053:11082 25:0.625:11054:11079 88:1.171875:11055:11076 205:0.96875:11056:11075 208:0.984375:11057:11074 "
    s .= "241:0.12:11058:11059 ~0.009813332378666698 79:0.6875:11060:11073 13:-0.328125:11061:11064 124:0.484375:11062:11063 ~0.024270131745451617 ~-0.0495441794873486 10:0.46875:11065:11072 43:-0.265625:11066:11067 ~-0.05427886955999665 "
    s .= "252:1.8250000000000002:11068:11071 245:1.912280701754386:11069:11070 ~-0.0005755749664794351 ~-0.027537590453226825 ~0.020269521154050764 ~0.02058224173712056 ~0.010373362475243765 ~0.027305074518061724 ~0.021366399509577465 "
    s .= "249:1.8333333333333335:11077:11078 ~0.019491147856175683 ~-0.0413999497190387 250:1.1171875:11080:11081 ~-0.048916252591285264 ~0.014651093911801395 ~0.024954395818087245 ~-0.0225916040248611 62:-0.59375:11085:11086 "
    s .= "~0.013644170765156208 ~-0.05282242666629525 20:0.4375:11088:11091 169:-0.140625:11089:11090 ~-0.025500654730463708 ~0.03282783898482185 ~-0.02938759449290339 ~-0.018508236089815482 254:0.984375:11094:11137 "
    s .= "191:-0.421875:11095:11104 251:0.734375:11096:11101 213:-0.1171875:11097:11098 ~0.013001482724029182 28:-0.015625:11099:11100 ~0.006361465491419621 ~-0.04573905922517732 34:0.8125:11102:11103 ~0.024735289525716297 "
    s .= "~-0.03439805192470795 110:-0.78125:11105:11108 200:-0.890625:11106:11107 ~0.01849967060032757 ~-0.06273682091141444 154:1.9375:11109:11136 121:0.125:11110:11129 124:0.03125:11111:11122 119:0.125:11112:11119 "
    s .= "202:-0.015625:11113:11114 ~-0.012850936443761701 73:0.0625:11115:11116 ~0.025188115506245935 245:3.0294117647058822:11117:11118 ~0.006584575705889189 ~-0.08376957775764993 251:1.015625:11120:11121 ~-0.03902301079587166 "
    s .= "~0.0037937116733623845 127:0.15625:11123:11124 ~0.028770099276387486 16:-0.03125:11125:11128 82:1.203125:11126:11127 ~-0.03256476232450867 ~0.023046914951809223 ~0.014334680308944206 72:0.2578125:11130:11135 "
    s .= "81:0.1328125:11131:11132 ~-0.0064585031909706716 112:1.296875:11133:11134 ~-0.04937767964422953 ~0.02038004155125532 ~0.007741656977223845 ~-0.03443350205345035 247:0.203125:11138:11139 ~-0.0025907269526625107 "
    s .= "~-0.028162538410055057 248:0.875:11141:11178 203:0.703125:11142:11177 70:0.40625:11143:11168 88:1.125:11144:11165 133:2.390625:11145:11164 55:1.25:11146:11163 89:0.625:11147:11162 245:1.5731707317073171:11148:11149 "
    s .= "~-0.03904126003290617 52:0.609375:11150:11159 184:0.078125:11151:11156 252:0.675:11152:11155 173:-0.03125:11153:11154 ~-0.006956789075606229 ~-0.048824737562110934 ~0.026557505520953942 64:0.59375:11157:11158 "
    s .= "~0.009538366201173163 ~-0.03629177055770765 103:1.21875:11160:11161 ~-0.04346794451497034 ~0.026163976469043407 ~0.023000737765221022 ~0.025424867231368303 ~-0.04237259645929822 193:-0.03125:11166:11167 ~0.00048235139272887547 "
    s .= "~0.03230508596254888 88:0.5:11169:11174 109:0.546875:11170:11171 ~-0.02262325492502231 118:0.75:11172:11173 ~0.03173136793425804 ~-0.043632310842175615 244:1.685:11175:11176 ~-0.042148998175108934 ~0.0008174969573306261 "
    s .= "~-0.04209256550391612 214:0.46875:11179:11184 224:-0.171875:11180:11183 211:-0.140625:11181:11182 ~0.029715054669202337 ~-0.017015983578268928 ~-0.04136922747927969 246:-0.765625:11185:11186 ~-0.0404701715735542 "
    s .= "~0.024646827161117463 255:0.234375:11188:11207 254:0.453125:11189:11198 251:0.671875:11190:11191 ~-0.00914723685316993 131:0.4375:11192:11193 ~0.011764289801634853 59:-0.046875:11194:11195 ~0.022743302618272836 "
    s .= "86:0.765625:11196:11197 ~-0.03736509515886259 ~0.008248755250382307 199:-0.140625:11199:11200 ~-0.02668847255247904 218:0.09375:11201:11202 ~0.03178752678470449 245:1.890625:11203:11204 ~0.0296966943630191 243:1.05:11205:11206 "
    s .= "~-0.06478192138686065 ~0.027375627384417286 122:-0.359375:11208:11223 247:0.265625:11209:11222 200:-0.4375:11210:11221 34:-0.0625:11211:11212 ~0.014186339563484366 40:-0.015625:11213:11216 16:-0.28125:11214:11215 "
    s .= "~0.017827862659582538 ~-0.05111418329195745 178:-0.09375:11217:11218 ~-0.042307383810210326 43:0.46875:11219:11220 ~0.010980862965989498 ~-0.02750917545113012 ~0.017059442750075073 ~-0.02549622010571975 254:0.609375:11224:11227 "
    s .= "24:-0.2421875:11225:11226 ~-0.0509109992895031 ~0.01192308787753015 79:0.359375:11228:11233 2:-0.484375:11229:11230 ~-0.003869473263096625 91:1.3125:11231:11232 ~-0.04075945572961995 ~0.010614782456172532 ~-0.004659632092325254 "
    s .= "159:0.5234375:11235:11280 145:-0.125:11236:11245 244:1.385:11237:11244 147:-0.1015625:11238:11239 ~-0.05402554693357038 73:0.015625:11240:11243 17:-0.140625:11241:11242 ~0.01851116483463411 ~-0.024780723122477533 "
    s .= "~-0.04732873699405586 ~0.0043419478247706585 252:0.42500000000000004:11246:11275 242:1.15:11247:11272 207:0.3203125:11248:11267 196:0.3125:11249:11264 136:2.1875:11250:11263 178:1.0625:11251:11262 91:-0.0625:11252:11253 "
    s .= "~-0.027973168910477228 105:0.2109375:11254:11261 190:-0.046875:11255:11256 ~-0.021433971473600787 251:0.484375:11257:11260 97:0.140625:11258:11259 ~0.010405208126570024 ~-0.04506171113368082 ~0.02311497197842795 "
    s .= "~-0.02136604748952353 ~0.029322761549229633 ~-0.0419445821340624 232:0.40625:11265:11266 ~0.02541793776773465 ~-0.018321875464977027 139:0.515625:11268:11269 ~-0.003247499781274971 180:0.4921875:11270:11271 ~-0.060981128501326566 "
    s .= "~0.007245755566211182 130:0.109375:11273:11274 ~0.012899983129905264 ~-0.05368764103452252 253:-0.02690166975881019:11276:11277 ~0.02642127526079921 202:0.1875:11278:11279 ~0.00985270697646814 ~-0.02669169090313167 "
    s .= "~-0.026220492477895003 205:-0.25:11282:11283 ~-0.014661346161639794 154:2.453125:11284:11327 85:1.46875:11285:11318 16:1.0625:11286:11317 163:1.25:11287:11314 238:0.125:11288:11301 22:0.34375:11289:11300 79:0.765625:11290:11299 "
    s .= "97:-0.015625:11291:11296 202:0.5625:11292:11295 82:0.421875:11293:11294 ~-0.03131333798429546 ~0.006964802121429255 ~0.029004265578331884 67:0.015625:11297:11298 ~-0.00647303598066259 ~0.018457323102191347 ~0.02477011389207519 "
    s .= "~-0.020283523501919278 163:0.671875:11302:11311 94:0.09375:11303:11308 103:0.015625:11304:11305 ~0.000854621165582309 136:-0.015625:11306:11307 ~0.020862243755480323 ~-0.039757218335594015 208:-0.015625:11309:11310 "
    s .= "~-0.04181488855086379 ~0.010762346657228049 178:1.21875:11312:11313 ~-0.04808507109062099 ~0.030281082776230973 70:-0.140625:11315:11316 ~-0.037022787941024045 ~0.02967695182539215 ~-0.038399611813771495 248:0.625:11319:11326 "
    s .= "181:1.3125:11320:11321 ~0.02851237750966812 242:0.35:11322:11323 ~-0.07265873448062614 142:0.25:11324:11325 ~0.03328106241351327 ~-0.038861424487020825 ~-0.015651211205498984 ~-0.04587358913935605 243:2.25:11329:11372 "
    s .= "153:0.7578125:11330:11371 253:-0.09206349206349076:11331:11338 252:0.125:11332:11337 71:0.15625:11333:11336 36:-0.0546875:11334:11335 ~-0.03629467792735683 ~0.02394331393916594 ~-0.05899663409766418 ~0.02534911727438226 "
    s .= "163:1.25:11339:11366 147:-0.2578125:11340:11343 244:1.94:11341:11342 ~-0.029683042630271873 ~0.017522054071373333 124:0:11344:11347 76:0.0625:11345:11346 ~-0.001820254006237838 ~-0.03028313436452327 184:1.046875:11348:11365 "
    s .= "124:0.109375:11349:11352 64:0:11350:11351 ~-0.02397271180139854 ~0.022634850241019813 163:0.625:11353:11364 166:0.546875:11354:11363 172:0.453125:11355:11362 121:-0.015625:11356:11357 ~0.013393310451509578 "
    s .= "49:-0.421875:11358:11359 ~0.03626105547201798 160:0.3125:11360:11361 ~-0.049372062291121614 ~-0.008459404255904563 ~0.015757997816585458 ~0.030916938029692694 ~-0.027928619818466716 ~0.029537091915521077 70:-0.140625:11367:11368 "
    s .= "~-0.031205134228297265 214:-0.046875:11369:11370 ~-0.008680514635829435 ~0.029947897636027006 ~-0.036472172780320056 82:1:11373:11374 ~-0.05790446179696887 ~0.004313866362685266 122:0.25:11376:11417 255:0.234375:11377:11406 "
    s .= "249:1.8333333333333335:11378:11405 254:0.453125:11379:11398 221:0.203125:11380:11397 85:1.1875:11381:11394 245:2.88:11382:11393 130:1.328125:11383:11390 130:0.1875:11384:11389 138:0.1953125:11385:11388 177:0.3828125:11386:11387 "
    s .= "~-0.049889253451445466 ~0.02993871308550705 ~0.027728480996242623 ~-0.030029716135395648 245:2.5483870967741935:11391:11392 ~0.025282271411883134 ~-0.031804668570232474 ~0.012933343218986731 154:1.46875:11395:11396 "
    s .= "~0.028810787933266177 ~-0.01062812190749881 ~0.02282884569719479 122:0.09375:11399:11402 131:-0.296875:11400:11401 ~-0.01366008984101769 ~0.03357766685359966 88:0.21875:11403:11404 ~-0.05398566121350096 ~0.03174698267299721 "
    s .= "~-0.03824146591250063 122:-0.359375:11407:11410 247:0.265625:11408:11409 ~0.005289788446088889 ~-0.024043275473776687 86:0.265625:11411:11416 250:1.1328125:11412:11413 ~-0.023070630949562385 208:-0.125:11414:11415 "
    s .= "~-0.04452882252851274 ~0.013207945774525354 ~0.009376125705299552 229:0.203125:11418:11421 89:0.75:11419:11420 ~-0.012303472611296041 ~0.02023535655383725 ~-0.03375941375825583 251:0.828125:11423:11458 "
    s .= "256:0.2653061224489796:11424:11457 64:1.359375:11425:11456 181:0.640625:11426:11451 202:0.515625:11427:11448 238:-0.09375:11428:11429 ~-0.02978938556644486 136:0:11430:11431 ~0.031214422721587087 64:0.390625:11432:11443 "
    s .= "190:0:11433:11436 55:0.640625:11434:11435 ~-0.051126094534052514 ~0.015292141842964586 238:0.109375:11437:11438 ~0.010989420352375691 22:0.59375:11439:11442 67:0.109375:11440:11441 ~-0.006401226840627477 ~-0.04963502478254067 "
    s .= "~0.0408559091628781 245:1.7010309278350515:11444:11445 ~-0.04460888749037886 153:-0.0859375:11446:11447 ~-0.015975452315086746 ~0.036636771588013706 175:0.65625:11449:11450 ~0.03168192706585212 ~-0.0354703325255337 "
    s .= "244:1.48:11452:11453 ~-0.032889002304521915 165:-0.0390625:11454:11455 ~0.018330629464724572 ~-0.03503936709299129 ~0.029135766022950756 ~-0.03923779794518349 109:0.5:11459:11466 100:1.125:11460:11465 137:0.625:11461:11464 "
    s .= "172:0.453125:11462:11463 ~-0.029590665202374224 ~0.014667736780503635 ~0.014692661806208025 ~0.030054126408189216 248:0.875:11467:11468 ~0.012043072913492745 ~-0.01630715356355094 72:0.7890625:11470:11515 254:0.984375:11471:11502 "
    s .= "47:-0.671875:11472:11473 ~0.018616950218950715 83:-0.890625:11474:11475 ~-0.039279119136604077 148:0.203125:11476:11487 124:0:11477:11486 22:0.015625:11478:11485 101:-0.09375:11479:11480 ~0.01971287515794419 "
    s .= "86:0.546875:11481:11484 253:-0.03472222222222143:11482:11483 ~0.0054408494657385295 ~-0.046410770793533805 ~0.021493670146897906 ~-0.018655404224604474 ~0.013886845588417641 112:-0.078125:11488:11489 ~0.02556065583737783 "
    s .= "75:0.0859375:11490:11495 87:-0.0078125:11491:11494 198:0.203125:11492:11493 ~-0.019041670145951418 ~0.027613497054638614 ~-0.03714611973434522 154:0.65625:11496:11501 184:0.515625:11497:11500 82:0.125:11498:11499 "
    s .= "~0.018515099754112058 ~-0.04266559907174483 ~0.018877476331485725 ~0.015184097453034884 122:-0.109375:11503:11514 246:-0.390625:11504:11511 115:1.15625:11505:11510 103:-0.21875:11506:11507 ~0.021358788182107735 "
    s .= "178:0.75:11508:11509 ~-0.028334775917455604 ~0.007672888865595126 ~0.01904168710932756 100:0.0625:11512:11513 ~-0.01242122119084062 ~0.023671577240328902 ~-0.02627841395579777 ~-0.031511272790514064 119:0.46875:11517:11560 "
    s .= "113:0.5:11518:11557 245:1.5806451612903225:11519:11520 ~-0.04233042189397199 253:-0.04450757575757791:11521:11540 252:0.42500000000000004:11522:11537 58:-0.03125:11523:11526 118:0.34375:11524:11525 ~0.02938215364257073 "
    s .= "~-0.03307754931230752 184:0:11527:11532 31:0.46875:11528:11531 52:-0.25:11529:11530 ~0.026924546848028204 ~-0.06770178928187003 ~0.03199700141643916 242:0.95:11533:11536 124:0:11534:11535 ~-0.016552197895908397 "
    s .= "~0.02210050149120329 ~-0.04073358621035685 238:0.5625:11538:11539 ~0.03077655007891729 ~-0.04174067696286448 242:0.55:11541:11542 ~0.002412217808327919 241:0.32:11543:11548 193:0.28125:11544:11545 ~-0.053364701616643355 "
    s .= "94:0.109375:11546:11547 ~-0.04329320117440283 ~0.02881160868279242 27:0.0625:11549:11552 49:-0.140625:11550:11551 ~-0.03944923470602925 ~-0.0069045295197412765 52:0.109375:11553:11554 ~0.025541424371924033 244:1.515:11555:11556 "
    s .= "~-0.02658201809473087 ~0.02620733729009696 148:0.296875:11558:11559 ~0.024359762217877376 ~-0.01192227273559568 97:-0.078125:11561:11562 ~-0.04632098406703998 ~-0.004310190233672194 248:0.875:11564:11601 70:0.40625:11565:11590 "
    s .= "88:1.125:11566:11587 133:2.390625:11567:11586 79:1.546875:11568:11585 162:0.3203125:11569:11582 40:-0.015625:11570:11577 28:-0.015625:11571:11574 211:-0.15625:11572:11573 ~-0.039215983436615615 ~0.010984187884786637 "
    s .= "160:1.484375:11575:11576 ~-0.036651455749131825 ~0.02873668945595606 178:-0.078125:11578:11581 91:0.21875:11579:11580 ~-0.05115108342927922 ~0.009839422735102793 ~0.011498306650338321 97:0.03125:11583:11584 ~-0.03548938064527259 "
    s .= "~0.003741002945137207 ~0.025585498889664268 ~-0.04001328515853151 193:-0.03125:11588:11589 ~0.000055929930054453034 ~0.030426736479017214 88:0.5:11591:11598 109:0.546875:11592:11595 21:0.4140625:11593:11594 ~-0.04377716166345841 "
    s .= "~0.015359092057585011 118:0.75:11596:11597 ~0.02937661481395141 ~-0.042800691114486374 244:1.685:11599:11600 ~-0.041049424860746295 ~-0.0005614263271852292 225:0.1328125:11602:11609 236:0.015625:11603:11608 88:0.0625:11604:11605 "
    s .= "~-0.04548229903578557 148:0.21875:11606:11607 ~0.02003892218436906 ~-0.03066642839891532 ~-0.048522400407123606 ~0.008021667936748285 243:2.25:11611:11654 73:1.140625:11612:11653 127:2.421875:11613:11652 251:1.328125:11614:11641 "
    s .= "247:0.484375:11615:11638 239:0.34375:11616:11635 195:-0.1953125:11617:11624 244:1.94:11618:11623 145:-0.125:11619:11620 ~-0.0632494833653909 5:-0.53125:11621:11622 ~0.00311568191218301 ~-0.03303480872825684 ~0.02475210322604751 "
    s .= "85:1.484375:11625:11634 255:0.234375:11626:11629 254:0.484375:11627:11628 ~0.002120134057224443 ~0.024330411534489237 241:0.12:11630:11631 ~0.01151690604331545 87:-0.1796875:11632:11633 ~0.012034397592039097 ~-0.01643460914963956 "
    s .= "~0.0209101288489367 119:0.171875:11636:11637 ~0.009383097101238552 ~-0.04308561356786137 240:0.546875:11639:11640 ~-0.03696475270710388 ~0.008257628177290905 241:0.46:11642:11649 149:-0.21875:11643:11646 160:-0.078125:11644:11645 "
    s .= "~-0.040008394815561586 ~0.020232448775875135 31:0.4375:11647:11648 ~-0.034885481158776946 ~0.024379694383996533 248:0.625:11650:11651 ~0.02547759960445309 ~-0.012723988189774667 ~-0.03857422203412051 ~-0.027319101176471485 "
    s .= "82:1:11655:11656 ~-0.05635345337611522 ~0.0037892898850580142 245:5.03030303030303:11658:11703 191:-0.0625:11659:11690 75:-0.0390625:11660:11671 247:0.203125:11661:11670 9:-0.1953125:11662:11667 146:-0.71875:11663:11664 "
    s .= "~0.023339853764016073 245:1.9183673469387754:11665:11666 ~0.024411700242926004 ~-0.013754193887391717 190:-0.015625:11668:11669 ~-0.02843359035696293 ~-0.0024522879623375803 ~-0.0462122725924229 28:0.265625:11672:11685 "
    s .= "185:-0.0625:11673:11684 111:0.0234375:11674:11679 245:1.9848484848484849:11675:11678 244:1.025:11676:11677 ~-0.03700893534276114 ~0.016417502829377754 ~0.02395148171921182 104:0.3125:11680:11683 88:-0.21875:11681:11682 "
    s .= "~0.028564727027728984 ~-0.01988407609966701 ~0.029308717063293813 ~0.029354792929388942 58:0.140625:11686:11687 ~0.021555343729594955 7:0.203125:11688:11689 ~-0.05980633636834244 ~-0.011829847547003069 193:-0.21875:11691:11692 "
    s .= "~-0.03021906243499914 190:0.6875:11693:11700 255:0.265625:11694:11695 ~-0.00016930149077136445 15:-0.1328125:11696:11697 ~0.011139762211170844 252:1.025:11698:11699 ~-0.03578168162704059 ~0.0018977205843543393 "
    s .= "202:0.453125:11701:11702 ~0.02987542297991111 ~-0.025195584248916842 ~-0.051594819610950395 254:1.296875:11705:11748 191:-0.421875:11706:11717 251:0.734375:11707:11708 ~-0.001286179317785158 157:0.984375:11709:11716 "
    s .= "52:0.265625:11710:11715 211:-0.09375:11711:11714 182:-0.390625:11712:11713 ~-0.04907303231933069 ~0.02254604926497432 ~0.026947545578881085 ~-0.02437366417311847 ~0.03301809486517505 246:-0.859375:11718:11719 "
    s .= "~-0.02896605090548053 232:-0.140625:11720:11723 118:0.296875:11721:11722 ~-0.004839938342700379 ~-0.04822540746144325 256:0.9433962264150944:11724:11747 252:0.42500000000000004:11725:11742 146:0.328125:11726:11739 "
    s .= "199:0.453125:11727:11738 251:1.921875:11728:11737 244:1.9:11729:11734 241:0.14:11730:11731 ~0.020571910609725196 255:0.234375:11732:11733 ~0.005778066929433629 ~-0.024818901319333002 52:0.0625:11735:11736 ~-0.04721174526338326 "
    s .= "~0.003774850697741386 ~-0.044675946191389516 ~0.02200815860850398 30:0.5390625:11740:11741 ~-0.04673292362757939 ~0.015979229159825817 235:0.171875:11743:11746 28:0.28125:11744:11745 ~0.0266429132617782 ~-0.018903802737233376 "
    s .= "~-0.00930504837553378 ~-0.04493860488148039 29:-0.3125:11749:11750 ~-0.004290337170444898 ~-0.04287554366843399 243:1.55:11752:11791 252:0.42500000000000004:11753:11782 207:0.3203125:11754:11775 184:0.15625:11755:11770 "
    s .= "31:0.40625:11756:11769 160:0.578125:11757:11766 178:0.9375:11758:11765 136:1:11759:11764 120:0.0703125:11760:11761 ~-0.03513066607529461 197:0.125:11762:11763 ~0.011578000651955954 ~-0.04777024744978339 ~-0.04991443394772194 "
    s .= "~0.016446154695363407 202:-0.234375:11767:11768 ~-0.050554224196891755 ~0.016126074106723075 ~0.020626894148287278 82:0.15625:11771:11772 ~0.02014458709103527 154:0.640625:11773:11774 ~-0.012708335154327705 ~0.010655728446293889 "
    s .= "1:-0.421875:11776:11777 ~0.023386536012714673 109:0.34375:11778:11779 ~0.00301508212713678 139:0.4375:11780:11781 ~-0.02226273133874762 ~-0.06369104366111088 253:-0.02592592592592524:11783:11786 217:-0.15625:11784:11785 "
    s .= "~-0.01461565058991362 ~0.031559733478148555 178:0.234375:11787:11788 ~0.018675597967509387 234:0.0859375:11789:11790 ~-0.03530346420799202 ~0.007324605007840807 245:1.9540229885057472:11792:11793 ~-0.045949834595545504 "
    s .= "37:-0.25:11794:11795 ~-0.044344426731589164 10:0.15625:11796:11797 ~0.020534296757077703 ~-0.041608289655375164 181:-0.703125:11799:11800 ~-0.042641908406255605 245:5.03030303030303:11801:11844 100:1.125:11802:11839 "
    s .= "88:1.46875:11803:11836 138:-0.5703125:11804:11805 ~-0.033249420125296934 122:0.09375:11806:11833 70:-0.34375:11807:11808 ~0.017821756430676027 70:-0.140625:11809:11810 ~-0.016711420830371235 163:1.25:11811:11832 "
    s .= "238:0.21875:11812:11825 22:0:11813:11818 199:0.171875:11814:11817 244:1.905:11815:11816 ~0.026362020092214944 ~-0.027419144674940346 ~-0.010874094355132261 251:0.484375:11819:11820 ~-0.024443047036743354 178:-0.09375:11821:11824 "
    s .= "252:0.475:11822:11823 ~-0.05974013686059866 ~0.022315372165329344 ~0.009583368473122168 79:0.078125:11826:11827 ~0.012981730980403838 196:0.609375:11828:11831 97:0.390625:11829:11830 ~-0.05122580259341667 ~0.0011396961936930795 "
    s .= "~0.023155596489220262 ~0.02520748513969988 89:0.9375:11834:11835 ~-0.015840846098423355 ~0.023836306929686434 124:-0.125:11837:11838 ~-0.018148736390401096 ~0.02339762438396971 196:0.375:11840:11843 70:0.640625:11841:11842 "
    s .= "~0.02754136655527259 ~-0.04580322254757616 ~-0.02675696237234834 ~-0.050847090143772415 248:1.375:11846:11889 254:1.296875:11847:11880 256:0.9166666666666666:11848:11879 243:2.25:11849:11878 70:0.40625:11850:11873 "
    s .= "38:-0.8125:11851:11852 ~0.021214995740065964 83:-0.890625:11853:11854 ~-0.02962038521486799 252:0.42500000000000004:11855:11866 199:0.5625:11856:11865 184:0.15625:11857:11864 160:0.578125:11858:11861 242:0.55:11859:11860 "
    s .= "~-0.01281027355983937 ~-0.047479619931655205 250:0.9765625:11862:11863 ~0.023407135509470964 ~-0.028386060521210912 ~0.005747741604080009 ~0.019001162034221263 121:-0.265625:11867:11868 ~-0.027142104996566437 "
    s .= "202:0.21875:11869:11870 ~0.024939589586867483 253:-0.02592592592592524:11871:11872 ~0.02108404442915601 ~-0.033236655922847594 199:0.140625:11874:11877 250:0.8984375:11875:11876 ~0.02415481895376201 ~-0.016285160358772876 "
    s .= "~-0.026026366696809786 ~-0.026351739381275725 ~-0.030045134099536505 50:-0.3125:11881:11888 250:0.7421875:11882:11883 ~-0.0350936761960896 247:0.140625:11884:11887 176:-0.4375:11885:11886 ~-0.0028366250230254676 "
    s .= "~0.02998177059076156 ~-0.02847692490118945 ~-0.04087999773599759 201:0.2890625:11890:11891 ~-0.04782872248987802 ~0.02013319110769195 44:0.890625:11893:11938 251:0.828125:11894:11913 64:1.359375:11895:11912 "
    s .= "181:0.640625:11896:11907 202:0.515625:11897:11904 238:-0.09375:11898:11899 ~-0.029830377942433706 136:0:11900:11901 ~0.028108558749294382 64:0.390625:11902:11903 ~-0.010293958012937587 ~0.016111855393924766 "
    s .= "175:0.65625:11905:11906 ~0.029744655396546027 ~-0.036017652422907886 55:0.203125:11908:11911 130:1.296875:11909:11910 ~-0.02399537400005597 ~0.017695094741572347 ~-0.04469087054200454 ~0.025526908868153238 "
    s .= "245:3.4761904761904763:11914:11935 109:0.53125:11915:11920 100:1.125:11916:11919 137:0.625:11917:11918 ~-0.017071573669391535 ~0.016176582934249364 ~0.028689493620262126 248:0.875:11921:11934 136:1.09375:11922:11931 "
    s .= "238:0.359375:11923:11930 241:0.56:11924:11929 184:0.15625:11925:11928 124:-0.140625:11926:11927 ~0.024632928226238256 ~-0.04458274065369689 ~0.026386070008076204 ~0.026185272583374216 ~-0.02379308007424707 "
    s .= "238:-0.09375:11932:11933 ~-0.0022843009687254895 ~0.037352066013898684 ~-0.014972412527082654 244:1.55:11936:11937 ~0.01916343685149019 ~-0.04336803771988117 ~-0.042570418132305686 249:0.16666666666666666:11940:11967 "
    s .= "253:-0.06679035250463854:11941:11942 ~0.017494656157817527 245:1.7719298245614035:11943:11948 178:0.609375:11944:11947 55:0.34375:11945:11946 ~0.032184243261427325 ~-0.020091527347833944 ~-0.0349215691454649 "
    s .= "121:0.359375:11949:11962 245:2.2580645161290325:11950:11957 251:1.546875:11951:11956 130:1.34375:11952:11955 91:0.65625:11953:11954 ~-0.03994467961319132 ~0.011917876995732195 ~0.012576020206871347 ~0.03143951625131088 "
    s .= "87:0.1484375:11958:11959 ~0.0159891188033686 6:0.40625:11960:11961 ~-0.03652724296118983 ~0.0224022222800974 223:1:11963:11966 100:1.21875:11964:11965 ~-0.05436119746798638 ~0.01248229614969636 ~0.029700620310989537 "
    s .= "38:-0.96875:11968:11969 ~0.015504717503391283 120:0.1640625:11970:11985 121:-0.1875:11971:11974 226:0.75:11972:11973 ~-0.03823993092234209 ~0.015662979338381722 166:0.171875:11975:11982 205:0.640625:11976:11981 "
    s .= "48:0.3046875:11977:11980 217:0.140625:11978:11979 ~-0.01665006035366606 ~-0.051870534055846185 ~0.009969816631950713 ~0.015493252264661118 103:0.234375:11983:11984 ~0.019552561359116562 ~-0.011850521964303194 "
    s .= "~0.0037063796733847023 95:0.4375:11987:12030 113:0.5:11988:12027 245:1.5806451612903225:11989:11990 ~-0.041016200409693185 253:-0.055855855855857804:11991:12004 252:0.175:11992:12001 60:0.2109375:11993:11998 "
    s .= "137:0.015625:11994:11997 225:0.1015625:11995:11996 ~-0.021430062196165223 ~0.025447160247529917 ~-0.05136676991730743 159:0.2421875:11999:12000 ~0.035618115613336415 ~-0.02707737208778573 214:0.71875:12002:12003 "
    s .= "~0.02561861678597202 ~-0.0329352277082287 108:0.1796875:12005:12022 190:0:12006:12017 154:0.453125:12007:12010 12:-0.1953125:12008:12009 ~0.002706743334910911 ~-0.03936329899931665 241:0.18:12011:12012 ~0.031377239744122716 "
    s .= "211:0:12013:12016 16:0.109375:12014:12015 ~-0.03641867854531129 ~0.007340206054841564 ~0.01367501443030102 73:0.6875:12018:12021 243:1.85:12019:12020 ~0.00698101671249907 ~-0.04060927398251265 ~-0.033726086306059465 "
    s .= "36:0.5390625:12023:12026 250:1.4140625:12024:12025 ~-0.033406535883949255 ~0.02149093249532152 ~0.011599570042132211 176:0.640625:12028:12029 ~0.02003325074191221 ~-0.02991857961638851 97:-0.046875:12031:12032 "
    s .= "~-0.04662127795180271 ~-0.0027759620352888668 122:0.25:12034:12077 251:0.515625:12035:12058 46:0.0625:12036:12049 55:0.203125:12037:12046 187:0.078125:12038:12043 202:-0.015625:12039:12040 ~-0.03980585421134861 "
    s .= "139:0.875:12041:12042 ~0.016291377112157272 ~-0.044263440109165705 64:-0.25:12044:12045 ~-0.020193108180403138 ~0.023855778668852797 124:1.140625:12047:12048 ~-0.03709295291769714 ~0.03216192416230457 76:-0.015625:12050:12051 "
    s .= "~-0.046504650320356 73:-0.109375:12052:12053 ~0.025864642439425614 160:1.21875:12054:12057 202:0.21875:12055:12056 ~-0.00948396199845652 ~-0.0474651266956285 ~0.016196374259751255 255:0.296875:12059:12060 ~0.009809462411636327 "
    s .= "84:-0.1953125:12061:12068 114:-0.2578125:12062:12067 104:-0.671875:12063:12064 ~0.013284992795597795 234:0.3515625:12065:12066 ~-0.04621806265988543 ~0.02454745704525903 ~0.027694170866350332 41:0.0625:12069:12074 "
    s .= "238:0.53125:12070:12071 ~0.0010736588481584412 109:1.46875:12072:12073 ~-0.05433275280441807 ~0.020652320421028523 93:-0.0078125:12075:12076 ~-0.0010169687715662924 ~-0.048928592876954585 229:0.203125:12078:12079 "
    s .= "~-0.0033139226397030925 ~-0.03244841975820096 205:-0.25:12081:12082 ~-0.014066418296267104 154:2.453125:12083:12126 217:0.21875:12084:12109 243:0.25:12085:12086 ~-0.0215439617178559 145:-0.125:12087:12090 175:0.046875:12088:12089 "
    s .= "~0.007402828405908964 ~-0.0253501857670891 193:-0.21875:12091:12092 ~-0.024196647778432695 151:0.578125:12093:12106 88:0.71875:12094:12103 22:0.140625:12095:12100 219:0.2421875:12096:12097 ~-0.017057876475439365 "
    s .= "221:-0.015625:12098:12099 ~0.020930509830170696 ~-0.037797848031414984 242:0.6499999999999999:12101:12102 ~0.023941110349206124 ~-0.016161366734172854 252:0.025:12104:12105 ~-0.00996731800836359 ~0.030323622356100213 "
    s .= "91:0.703125:12107:12108 ~0.028760076286098897 ~-0.006426730055123675 220:0.328125:12110:12115 190:0.6875:12111:12114 63:-0.1953125:12112:12113 ~0.001194472882628572 ~-0.03780587949510138 ~0.021000210167597677 "
    s .= "106:0.453125:12116:12119 232:0.4375:12117:12118 ~0.03420151347620502 ~-0.026803567264579116 220:1.140625:12120:12125 85:1.78125:12121:12124 81:0.4140625:12122:12123 ~-0.04147380422234838 ~0.026151153658259336 ~0.0372116511020161 "
    s .= "~0.021917861637101518 ~-0.042081735519379104 248:0.875:12128:12165 203:0.703125:12129:12164 251:0.765625:12130:12143 178:-0.078125:12131:12136 229:-0.234375:12132:12133 ~0.012382988298867421 190:0.1875:12134:12135 "
    s .= "~-0.062036781250259104 ~-0.0010951127425197847 46:0.078125:12137:12138 ~0.005954125157801107 202:0.078125:12139:12140 ~0.0074800336529534835 160:1.21875:12141:12142 ~-0.036937524487766 ~0.013564610868990142 244:2.385:12144:12163 "
    s .= "136:0.71875:12145:12160 106:0.578125:12146:12153 220:0.515625:12147:12152 22:-0.09375:12148:12149 ~0.008503011530076673 127:-0.203125:12150:12151 ~0.023687362449762606 ~-0.0376479533514158 ~0.028918210772369248 "
    s .= "28:0.484375:12154:12159 214:0.46875:12155:12158 169:0.484375:12156:12157 ~0.02555933689543771 ~-0.04277268758635085 ~-0.02482454381086673 ~-0.03564156917858532 142:-0.28125:12161:12162 ~-0.03387667988065948 ~0.02179242309391231 "
    s .= "~-0.026636648297222704 ~-0.03995665157973957 225:0.1328125:12166:12173 236:0.015625:12167:12172 88:0.0625:12168:12169 ~-0.044693792563573344 148:0.21875:12170:12171 ~0.01865643985900039 ~-0.029166781022663114 "
    s .= "~-0.04716084569186335 ~0.007310631545835442 149:-1.59375:12175:12176 ~0.030200674005243445 147:-0.3828125:12177:12180 244:1.645:12178:12179 ~-0.03453020237006878 ~0.010953376283302375 97:1.625:12181:12220 95:0.515625:12182:12219 "
    s .= "89:0.546875:12183:12216 245:1.5731707317073171:12184:12187 136:1.015625:12185:12186 ~-0.05054986362028309 ~0.02469217011449419 77:-0.125:12188:12211 246:-0.078125:12189:12206 245:1.9848484848484849:12190:12193 "
    s .= "171:-0.125:12191:12192 ~0.007489054353395837 ~-0.03795435827983411 146:-0.640625:12194:12197 22:0.46875:12195:12196 ~0.02448568574765711 ~-0.0221973019863001 86:-0.3125:12198:12203 87:-0.1796875:12199:12202 "
    s .= "255:0.453125:12200:12201 ~0.017521518512709444 ~-0.026861669847232962 ~-0.025744383882535634 27:-0.140625:12204:12205 ~-0.018861110305823384 ~0.02339339623842689 184:0.21875:12207:12210 191:0.09375:12208:12209 "
    s .= "~0.011601100371400743 ~-0.03428097200519264 ~0.031187644686256885 79:0.734375:12212:12215 162:0.1953125:12213:12214 ~-0.004204663380537534 ~-0.03457219853123092 ~0.009791549308066106 235:0.328125:12217:12218 ~0.025839674121338044 "
    s .= "~-0.022100182426287373 ~-0.018147889422794175 ~-0.037616746191410144 254:1.296875:12222:12257 248:1.375:12223:12256 256:0.9166666666666666:12224:12255 118:0.28125:12225:12244 120:0.0859375:12226:12229 138:0.2265625:12227:12228 "
    s .= "~0.001130555857651331 ~-0.03379473275122179 50:0.34375:12230:12243 204:0.2265625:12231:12234 251:0.171875:12232:12233 ~-0.03829926185512523 ~0.023694262976172685 243:0.95:12235:12242 12:0.1171875:12236:12237 ~0.02154517903797749 "
    s .= "160:1.25:12238:12241 193:-0.15625:12239:12240 ~0.018578146465668355 ~-0.041883701553970996 ~0.03056976013117695 ~0.02413970386164766 ~-0.015698620243727864 166:-0.09375:12245:12246 ~-0.03934044349275092 139:1.234375:12247:12254 "
    s .= "220:0.703125:12248:12253 241:0.1:12249:12250 ~0.020068645916720047 2:-0.515625:12251:12252 ~0.004905072098816927 ~-0.022425028821601883 ~0.02824138013671509 ~0.01985829599311524 ~-0.028906384559904026 ~-0.0314711324621306 "
    s .= "50:-0.25:12258:12267 250:0.7421875:12259:12260 ~-0.03405232101440297 247:0.171875:12261:12266 176:-0.4375:12262:12265 128:-0.640625:12263:12264 ~0.007296938832870081 ~-0.02884217170849307 ~0.02545725701224993 "
    s .= "~-0.029763179653589197 ~-0.04351504171966188 249:0.16666666666666666:12269:12270 ~0.004393877745771861 184:-0.21875:12271:12272 ~-0.028469916500174237 196:-0.125:12273:12278 55:0.703125:12274:12277 208:0.46875:12275:12276 "
    s .= "~-0.039277756731962515 ~0.008432122538204419 ~0.020106994868169928 202:-0.21875:12279:12280 ~0.028259886701303805 245:1.5918367346938775:12281:12284 116:0.625:12282:12283 ~-0.05884975507811854 ~0.018358582496845653 "
    s .= "94:0.015625:12285:12292 7:0.046875:12286:12291 127:-0.15625:12287:12288 ~0.030751102759545304 250:1.0546875:12289:12290 ~-0.017252310827102754 ~0.01728737658595879 ~-0.02975799743556297 121:-0.234375:12293:12294 "
    s .= "~-0.03123876333179191 58:-0.140625:12295:12296 ~0.03470420795169439 187:0.53125:12297:12312 148:0.203125:12298:12307 88:0.109375:12299:12304 152:0:12300:12303 106:0.203125:12301:12302 ~-0.04549127546976569 ~0.022225591979080007 "
    s .= "~-0.05085813521634711 52:0.375:12305:12306 ~0.020830442658768798 ~-0.03723773742162164 157:1.453125:12308:12311 124:0.140625:12309:12310 ~0.008993748284804436 ~-0.03847613752771288 ~0.025496169416699205 202:0.46875:12313:12314 "
    s .= "~0.03259137855256602 ~-0.02291503954003947 251:1.328125:12316:12349 247:0.484375:12317:12346 249:0.8333333333333333:12318:12343 85:1.1875:12319:12340 238:0.109375:12320:12329 22:-0.015625:12321:12322 ~0.017074860852741788 "
    s .= "97:-0.015625:12323:12324 ~-0.029468650868275176 130:1.6875:12325:12328 49:0.34375:12326:12327 ~0.017335015851951897 ~-0.034537727757926906 ~-0.03495607457961292 112:1.046875:12330:12339 22:0.390625:12331:12336 "
    s .= "199:0.578125:12332:12335 253:-0.19684601113172562:12333:12334 ~0.034610868880728285 ~-0.03849734288700921 ~0.011693822067337952 76:0.5:12337:12338 ~0.029350217366301886 ~-0.04191252670185023 ~0.008016001647910373 "
    s .= "181:-0.03125:12341:12342 ~-0.01690503125196394 ~0.018867731299718696 196:-0.078125:12344:12345 ~-0.042185694864242645 ~-0.00591452614353506 255:0.015625:12347:12348 ~0.01435407211169714 ~-0.03388079917031554 241:0.46:12350:12357 "
    s .= "242:0.55:12351:12354 146:0.015625:12352:12353 ~0.01584033764362868 ~-0.029820053176070196 163:1.125:12355:12356 ~-0.04250834236798437 ~0.019919788040055786 245:3.4761904761904763:12358:12361 209:0.5625:12359:12360 "
    s .= "~0.023284616428913482 ~-0.026408902683850793 ~-0.044491587979977 253:-0.04450757575757791:12363:12378 252:0.175:12364:12375 219:0.1953125:12365:12370 48:0.2109375:12366:12369 124:-0.140625:12367:12368 ~0.009512010483282369 "
    s .= "~-0.0482210824105488 ~0.021593546571613033 245:1.970873786407767:12371:12372 ~-0.03330515183473888 122:0.125:12373:12374 ~0.03662213692733602 ~-0.050251864736163936 16:-0.234375:12376:12377 ~-0.015502826052726343 "
    s .= "~0.022338171759705948 243:1.55:12379:12404 245:2.020408163265306:12380:12385 94:-0.25:12381:12382 ~-0.03455671582786021 175:-0.140625:12383:12384 ~-0.032893513513185306 ~0.013601519995757634 34:-0.15625:12386:12389 "
    s .= "121:0.5625:12387:12388 ~0.014645293887243794 ~-0.04177385915837658 16:-0.375:12390:12391 ~0.02833369984321857 244:1.66:12392:12399 241:0.12:12393:12396 91:0.1875:12394:12395 ~-0.02914195845479639 ~0.022944450387461356 "
    s .= "61:1.4375:12397:12398 ~-0.03214346195069389 ~0.02362408678853138 111:-0.1484375:12400:12401 ~0.019095626355495963 73:-0.109375:12402:12403 ~0.02303111462379772 ~-0.021968981405763758 245:2.130434782608696:12405:12406 "
    s .= "~-0.05350864005647017 134:0.03125:12407:12408 ~-0.042091174240165 ~0.0195031756293832 245:5.03030303030303:12410:12455 249:0.16666666666666666:12411:12426 253:-0.06679035250463854:12412:12413 ~0.01829315854662063 "
    s .= "245:1.7719298245614035:12414:12419 178:0.609375:12415:12418 127:0.34375:12416:12417 ~-0.004373438472301133 ~0.03598131631406268 ~-0.03314427612819958 121:0.15625:12420:12423 245:2.2580645161290325:12421:12422 "
    s .= "~-0.012557689415197266 ~0.01354624359440829 70:0.40625:12424:12425 ~-0.0060541159193022815 ~-0.05038640526801145 38:-0.96875:12427:12428 ~0.014788191979897784 120:0.1640625:12429:12454 121:-0.1875:12430:12431 "
    s .= "~-0.02911276713961454 166:0.171875:12432:12449 127:0.328125:12433:12444 199:0.40625:12434:12443 166:-0.078125:12435:12436 ~-0.04020640447354908 241:0.22:12437:12440 118:0.15625:12438:12439 ~-0.03797191861007394 "
    s .= "~0.014461977901483583 109:0.421875:12441:12442 ~-0.031110065404288387 ~0.030045774172882803 ~0.02522169352540839 19:0.296875:12445:12448 73:-0.15625:12446:12447 ~0.004168493019691391 ~-0.050525254868893414 ~0.009873236499242169 "
    s .= "103:0.234375:12450:12453 208:0.1875:12451:12452 ~0.032669485475734436 ~-0.003495358932539132 ~-0.010942409143822331 ~0.0037211670746024337 ~-0.04901434828004899 138:-0.7421875:12457:12458 ~-0.02854330437355281 "
    s .= "26:-0.765625:12459:12470 38:-0.296875:12460:12467 251:0.359375:12461:12464 109:1.375:12462:12463 ~-0.03149892230146615 ~0.026259114009070796 162:0.1953125:12465:12466 ~0.02415086355145812 ~-0.015664169078129078 "
    s .= "85:1.46875:12468:12469 ~-0.045970834987661 ~0.024717160971212796 83:-0.859375:12471:12472 ~-0.03312336352518032 255:0.234375:12473:12490 254:0.453125:12474:12485 245:1.6285714285714286:12475:12478 246:1.734375:12476:12477 "
    s .= "~-0.040590431394309345 ~0.02993935463162562 255:0.078125:12479:12482 246:-0.859375:12480:12481 ~-0.027118788977163064 ~0.012962213897759027 107:-0.4375:12483:12484 ~0.032169964167398195 ~-0.012181901020165324 "
    s .= "109:1.28125:12486:12489 83:-0.328125:12487:12488 ~-0.021752811264328722 ~0.027135248161321065 ~-0.024744837911829243 254:0.515625:12491:12492 ~0.015501072194346214 79:0.3125:12493:12500 122:-0.296875:12494:12497 "
    s .= "199:0.5:12495:12496 ~-0.0119741060268859 ~0.022405884170469462 88:0.421875:12498:12499 ~-0.04460439641528828 ~-0.014524061056648323 232:-0.1875:12501:12502 ~-0.03416007834279986 ~0.004246753954858498 251:0.890625:12504:12531 "
    s .= "184:0:12505:12514 208:0.046875:12506:12513 163:0.875:12507:12512 100:0.125:12508:12511 181:0.203125:12509:12510 ~-0.04764692701064126 ~0.007035631479375683 ~0.008829952415062714 ~0.025571447210740113 ~-0.04731370503675111 "
    s .= "211:-0.125:12515:12516 ~-0.02451682672765912 181:0.21875:12517:12524 251:0.171875:12518:12519 ~-0.0319893538354473 85:0.5:12520:12523 4:0.265625:12521:12522 ~0.010927830381964598 ~-0.03792771850809708 ~0.03149531265855327 "
    s .= "234:0.3828125:12525:12530 55:0.203125:12526:12527 ~0.008832587855673785 242:0.25:12528:12529 ~0.03272556674600333 ~-0.025039425407233973 ~-0.04576846395141018 243:0.35:12532:12537 115:0.171875:12533:12536 148:0.171875:12534:12535 "
    s .= "~0.017311399355869034 ~-0.04372419065874212 ~-0.04608889175389562 149:-0.375:12538:12541 142:-0.140625:12539:12540 ~-0.008756451020599687 ~0.025963755830541835 245:3.4761904761904763:12542:12549 231:-0.3828125:12543:12544 "
    s .= "~-0.04960947579317648 252:0.825:12545:12548 242:1.15:12546:12547 ~0.0031093101481858383 ~-0.030062776914885948 ~0.018717639591808357 ~-0.04081754262350092 254:1.296875:12551:12594 143:0.140625:12552:12589 116:0.0625:12553:12582 "
    s .= "122:-0.125:12554:12577 160:-0.328125:12555:12556 ~-0.04107743735520873 245:1.9425287356321839:12557:12564 244:1.04:12558:12561 158:-0.125:12559:12560 ~-0.05032203158158452 ~0.005585483186303328 243:1.55:12562:12563 "
    s .= "~0.014794320659185824 ~-0.05095193645441905 147:-0.1640625:12565:12570 212:-0.578125:12566:12567 ~0.014556638871331335 244:1.94:12568:12569 ~-0.03769989456523846 ~0.009652766075821627 251:0.171875:12571:12572 "
    s .= "~-0.03182845967506361 118:0.671875:12573:12574 ~0.019250131999684318 229:0:12575:12576 ~0.021989694053076672 ~-0.04284870426408284 106:0.546875:12578:12579 ~-0.028440519851874208 49:0.0625:12580:12581 ~0.012360340276307042 "
    s .= "~-0.021132134933356986 124:1.71875:12583:12588 242:0.35:12584:12587 182:0.046875:12585:12586 ~0.02093555723889654 ~-0.04899096554917587 ~0.020041668880652258 ~-0.04488967843980385 172:-0.171875:12590:12591 ~-0.03602552739655834 "
    s .= "145:0.515625:12592:12593 ~-0.0005746666407650747 ~-0.03786493854584828 29:-0.3125:12595:12596 ~-0.0045890525813131414 ~-0.04069171797129795 153:0.7578125:12598:12643 253:-0.125:12599:12602 49:0.328125:12600:12601 "
    s .= "~0.019766787858106937 ~-0.02619980374592607 243:1.55:12603:12636 252:0.575:12604:12631 207:0.3046875:12605:12626 225:0.2890625:12606:12625 245:1.831578947368421:12607:12608 ~0.013205601927422796 172:-0.125:12609:12614 "
    s .= "249:1.1666666666666665:12610:12613 244:1.35:12611:12612 ~-0.012504360695620921 ~0.030346504195254788 ~-0.026881353476508097 181:-0.046875:12615:12616 ~-0.043017833039279446 121:-0.140625:12617:12618 ~-0.0360822644612298 "
    s .= "85:0.09375:12619:12622 52:-0.078125:12620:12621 ~0.01235528792152647 ~-0.035021251989634246 58:0.109375:12623:12624 ~0.02201441572861932 ~-0.008396905707972411 ~0.0182981619733632 139:0.4375:12627:12628 ~-0.002998892508520356 "
    s .= "183:0.4765625:12629:12630 ~-0.053645380135521975 ~-0.0009370319039578817 251:1.578125:12632:12635 82:0.703125:12633:12634 ~-0.02037051628318624 ~0.014387526062664552 ~0.032285959067790845 245:1.9540229885057472:12637:12638 "
    s .= "~-0.04816338947068166 145:-0.15625:12639:12640 ~-0.04110918046463106 252:0.925:12641:12642 ~-0.03698039310304672 ~0.020194016576551326 ~-0.03311293895786503 205:-0.25:12645:12646 ~-0.013995220771354617 70:0.609375:12647:12690 "
    s .= "88:1.125:12648:12687 79:0.6875:12649:12684 70:-0.390625:12650:12651 ~0.02204283703357459 40:0.015625:12652:12659 7:0.0625:12653:12658 109:0.625:12654:12657 100:-0.15625:12655:12656 ~-0.03881301820008697 ~0.013254879422185423 "
    s .= "~-0.01815300440445068 ~-0.03778609698432978 4:0.125:12660:12673 58:-0.140625:12661:12662 ~0.02765545784765568 160:0.34375:12663:12668 103:-0.125:12664:12665 ~0.015012139125848215 252:0.175:12666:12667 ~-0.05402820880395626 "
    s .= "~-0.005620891365375776 237:0.3984375:12669:12672 214:-0.09375:12670:12671 ~-0.04650320864692491 ~0.015938657756358908 ~-0.041969409539628626 145:-0.140625:12674:12675 ~-0.0338521411942317 251:0.765625:12676:12681 "
    s .= "241:0.16:12677:12678 ~0.022203499447473327 112:0.734375:12679:12680 ~-0.046160033464074 ~0.008979676959565542 49:0.53125:12682:12683 ~0.03546286736623564 ~-0.038395000423006594 181:0.40625:12685:12686 ~0.022070992944720657 "
    s .= "~-0.005582301237606364 148:0.75:12688:12689 ~0.0208124744280518 ~-0.01726005046807184 ~-0.015025918589927665 248:0.875:12692:12729 115:1.15625:12693:12724 142:0.21875:12694:12715 251:0.171875:12695:12696 ~-0.03806173340593319 "
    s .= "120:0.0703125:12697:12712 40:0.015625:12698:12705 82:0.765625:12699:12700 ~-0.03092118326291514 7:0.046875:12701:12702 ~0.013442795382542814 70:-0.34375:12703:12704 ~0.02079082821499006 ~-0.06196059665653332 242:1.15:12706:12709 "
    s .= "84:0.0546875:12707:12708 ~0.024123162944981617 ~-0.009403695838489034 245:2.119047619047619:12710:12711 ~-0.043610810847675534 ~0.012480165041633844 28:0.5:12713:12714 ~0.014881291529064162 ~-0.023265614868538915 "
    s .= "85:0.203125:12716:12717 ~0.0052628866125007095 196:0.875:12718:12723 184:0.984375:12719:12722 149:-0.75:12720:12721 ~0.007508732659280973 ~-0.031077957471318737 ~0.005389056805202318 ~0.023117188510111027 214:0:12725:12726 "
    s .= "~-0.0035517831505777497 40:-0.296875:12727:12728 ~-0.029139083458691113 ~0.028993554474512406 146:0.09375:12730:12737 228:0.0546875:12731:12736 18:0.0078125:12732:12735 154:0.109375:12733:12734 ~-0.04128958616753216 "
    s .= "~0.011746379628453598 ~-0.04195882166940826 ~0.014253205132464279 ~-0.03610858611034419 159:0.5234375:12739:12782 245:5.03030303030303:12740:12781 244:1.455:12741:12770 52:0.3125:12742:12761 50:-1.21875:12743:12744 "
    s .= "~0.0368325087795043 134:-0.90625:12745:12746 ~-0.03319253390446096 196:-0.125:12747:12748 ~-0.016087014161638807 193:0.078125:12749:12752 238:0.125:12750:12751 ~0.019848147205427397 ~-0.00785697553366004 91:0.171875:12753:12756 "
    s .= "76:-0.25:12754:12755 ~0.01643362994082788 ~-0.02607808737510854 103:0.421875:12757:12758 ~0.020954273011373505 199:1:12759:12760 ~-0.042145097686129736 ~0.03619365209524009 28:0.09375:12762:12765 139:0.234375:12763:12764 "
    s .= "~0.027452511081233744 ~-0.02461341095188239 106:0.578125:12766:12769 133:0.859375:12767:12768 ~-0.03495223151884997 ~0.019491552298105702 ~-0.0463991653953317 106:0.390625:12771:12776 184:0.15625:12772:12775 "
    s .= "223:0.203125:12773:12774 ~-0.03981768411363171 ~0.01158183107103681 ~0.011524953386822412 130:2.453125:12777:12780 132:-0.1796875:12778:12779 ~0.031719529123868294 ~0.008707846103010399 ~-0.026426586530186924 ~-0.0475605189816769 "
    s .= "121:-0.453125:12783:12784 ~0.027172005168360464 ~-0.03564588630431688 253:-0.04450757575757791:12786:12811 252:0.175:12787:12798 219:0.1953125:12788:12793 45:0.2109375:12789:12792 124:-0.140625:12790:12791 ~0.00835062532385258 "
    s .= "~-0.045818859816726315 ~0.02101263690883248 245:1.970873786407767:12794:12795 ~-0.03190933414296671 122:0.125:12796:12797 ~0.03566783079510898 ~-0.04842220999728505 16:-0.234375:12799:12800 ~-0.014360513278608279 "
    s .= "112:0.65625:12801:12810 58:0.671875:12802:12809 76:1:12803:12808 49:0.03125:12804:12807 142:0.1875:12805:12806 ~0.02701358261847942 ~-0.03691155882281629 ~-0.04611259618648327 ~0.041075957751035425 ~0.04112520096914222 "
    s .= "~0.0358590246433058 243:1.55:12812:12827 245:2.020408163265306:12813:12818 94:-0.25:12814:12815 ~-0.03349732453613988 145:-0.109375:12816:12817 ~-0.021008379956397042 ~0.013613985042830215 31:-0.34375:12819:12820 "
    s .= "~0.01697104958801003 148:-0.09375:12821:12824 245:2.4347826086956523:12822:12823 ~-0.025771333861778625 ~0.020672174808111156 46:0.46875:12825:12826 ~-0.01596598522002658 ~0.010390716151554113 245:2.130434782608696:12828:12829 "
    s .= "~-0.050441624782819716 134:0.03125:12830:12831 ~-0.04018701507551635 ~0.01836600140462296 248:0.875:12833:12870 70:0.40625:12834:12867 88:1.125:12835:12864 136:2.234375:12836:12863 55:1.25:12837:12862 52:0.609375:12838:12861 "
    s .= "20:0.453125:12839:12860 89:0.5625:12840:12859 184:0.078125:12841:12850 193:0.09375:12842:12847 187:0.03125:12843:12844 ~-0.014668523810485338 106:0.296875:12845:12846 ~-0.027963641010076798 ~0.032448686646170524 "
    s .= "22:0.140625:12848:12849 ~-0.04841044546537179 ~0.0043465720031488275 136:1.65625:12851:12858 163:0.625:12852:12853 ~0.008177612145772912 208:0.984375:12854:12857 27:0.03125:12855:12856 ~-0.05202189684499926 ~0.0006941502548586086 "
    s .= "~0.036201322271560664 ~0.032654713216841054 ~0.02579021306182855 ~-0.029017577166130033 ~-0.024550699416886475 ~0.022655051258672114 ~-0.03658997385760445 193:-0.03125:12865:12866 ~0.00009282776520472353 ~0.02915773775100602 "
    s .= "172:0.046875:12868:12869 ~0.007481168025140353 ~-0.021917457174003854 46:0.375:12871:12878 73:-0.03125:12872:12877 151:0:12873:12876 64:-0.265625:12874:12875 ~-0.03516581361034339 ~0.03412833011773838 ~-0.020942001537845326 "
    s .= "~-0.033127587090425535 ~0.014161473344697329 254:1.296875:12880:12923 191:-0.421875:12881:12886 251:0.734375:12882:12883 ~-0.0014627350440360022 157:0.96875:12884:12885 ~0.006571761442708751 ~0.03147369217057176 "
    s .= "246:-0.859375:12887:12888 ~-0.0271231151170437 157:1.640625:12889:12920 79:0.328125:12890:12911 190:-0.015625:12891:12898 58:-0.046875:12892:12893 ~0.0038130274621657302 34:0.28125:12894:12897 241:0.62:12895:12896 "
    s .= "~-0.05771317702675169 ~-0.009181257281824137 ~0.005302050519054319 118:0.640625:12899:12910 125:0.0625:12900:12907 118:-0.046875:12901:12904 194:0.015625:12902:12903 ~-0.033420902230892884 ~0.025999773867667608 "
    s .= "87:0.2890625:12905:12906 ~0.023041280026990338 ~-0.013913720433798613 184:0.125:12908:12909 ~-0.03128109267019397 ~0.005312664099549919 ~-0.02507507116765242 202:0.25:12912:12917 31:0.109375:12913:12916 235:0.171875:12914:12915 "
    s .= "~0.03170557980614541 ~-0.0065369383396298875 ~0.0006658571158665692 244:1.505:12918:12919 ~-0.023711416583250725 ~0.015383939990551404 130:1.6875:12921:12922 ~-0.00029939119250057606 ~-0.04684563030743741 50:-0.25:12924:12925 "
    s .= "~-0.00503332978456505 ~-0.04183918265148551 255:0.296875:12927:12954 133:1.90625:12928:12953 254:0.703125:12929:12940 85:1.125:12930:12939 112:1.625:12931:12938 254:0.296875:12932:12933 ~-0.0013657526742174941 "
    s .= "158:0.265625:12934:12935 ~-0.0365802387897352 41:0.03125:12936:12937 ~0.025914792825443997 ~-0.03563778898410271 ~0.02328637184195688 ~0.01395540697117042 252:0.175:12941:12950 53:0.0625:12942:12947 83:-0.34375:12943:12946 "
    s .= "182:-0.578125:12944:12945 ~0.020056211879286977 ~-0.03794714162680771 ~0.021707310164836457 91:0.828125:12948:12949 ~-0.05304746960113863 ~0.026446416073264853 133:1.28125:12951:12952 ~0.03297735522483497 ~-0.013783447880072295 "
    s .= "~-0.017137150376307638 194:-0.09375:12955:12970 251:1.171875:12956:12965 145:-0.109375:12957:12960 130:1.03125:12958:12959 ~-0.04533815077008167 ~-0.00040465991976321386 247:0.203125:12961:12964 203:-0.484375:12962:12963 "
    s .= "~-0.006397807666322943 ~0.015224160292401343 ~-0.028067406318097572 14:-0.265625:12966:12967 ~0.01764228464342185 190:0.15625:12968:12969 ~-0.03323974046501893 ~0.010561013159474686 77:-0.40625:12971:12972 ~0.008353847951429195 "
    s .= "~-0.02511391099443952 149:-1.59375:12974:12975 ~0.028939898080556067 147:-0.3828125:12976:12977 ~-0.02227315745565127 97:1.625:12978:13019 85:1.46875:12979:13014 16:1.0625:12980:13011 205:0.703125:12981:13010 46:0.75:12982:13009 "
    s .= "76:1.09375:12983:13008 49:0.796875:12984:13007 89:0.625:12985:13006 245:1.5806451612903225:12986:12987 ~-0.04016375605194904 202:0.96875:12988:13005 199:1.140625:12989:13004 253:-0.09206349206349076:12990:12991 "
    s .= "~0.010734844484060431 70:-0.0625:12992:12993 ~-0.024135671254425662 46:0.109375:12994:13001 241:0.16:12995:12996 ~0.019284910615308935 208:-0.15625:12997:12998 ~-0.05059240841543699 243:0.45:12999:13000 ~-0.03285768694864368 "
    s .= "~0.006699093460678806 61:-0.21875:13002:13003 ~0.03173991983432517 ~-0.020976783643782998 ~0.03002569279321375 ~0.026796382714183994 ~0.016690805183940925 ~-0.04792403226919907 ~0.020386508722656224 ~0.022317274974856777 "
    s .= "~0.014949359473816337 91:-0.46875:13012:13013 ~0.029435214651423056 ~-0.04909209825492427 208:-0.03125:13015:13018 26:-0.734375:13016:13017 ~0.031589233140689225 ~-0.02418404493416645 ~0.02069272825425994 ~-0.035897852797782195 "
    s .= "248:1.375:13021:13064 254:0.984375:13022:13049 87:-0.0546875:13023:13028 48:0.1953125:13024:13027 243:1.45:13025:13026 ~0.00917681094668144 ~-0.030228737092673298 ~0.03294074598120728 133:1.921875:13029:13048 "
    s .= "123:-0.1796875:13030:13031 ~-0.029883358084702695 186:-0.0859375:13032:13035 114:-0.2421875:13033:13034 ~-0.037167669551227675 ~0.028186736452619827 72:0.1328125:13036:13041 214:0.203125:13037:13038 ~-0.0008433351517857891 "
    s .= "136:1.296875:13039:13040 ~-0.04398285410618141 ~0.014648192530430447 158:-0.5625:13042:13043 ~-0.047086438566897704 151:0.53125:13044:13047 23:0.5:13045:13046 ~0.006530151433604702 ~-0.028744294576353115 ~0.02604585127333528 "
    s .= "~-0.026086724863333705 247:0.203125:13050:13063 246:-0.390625:13051:13058 115:1.15625:13052:13057 103:-0.21875:13053:13054 ~0.017677261971270987 178:0.90625:13055:13056 ~-0.02799577356598043 ~0.00958362892234536 "
    s .= "~0.015342440283796475 122:-0.125:13059:13060 ~0.019369750440519654 32:0.171875:13061:13062 ~-0.03212224965628344 ~0.02360881055456825 ~-0.02536327925995755 34:-0.25:13065:13066 ~0.018333430070166388 ~-0.04609861740195345 "
    s .= "138:-0.7421875:13068:13069 ~-0.02722263603607272 11:-0.953125:13070:13073 40:0.453125:13071:13072 ~0.02084562501886347 ~-0.02065731030347065 254:1.296875:13074:13113 133:1.984375:13075:13108 244:1.475:13076:13097 "
    s .= "195:-0.1953125:13077:13080 109:0.234375:13078:13079 ~0.012860737239686152 ~-0.04047713094763547 17:0.421875:13081:13094 242:1.15:13082:13087 139:0.890625:13083:13086 184:0:13084:13085 ~-0.0057801776589473525 ~0.014494176932364173 "
    s .= "~-0.018356454423644003 245:2.6065573770491803:13088:13093 250:0.9921875:13089:13090 ~-0.03565589118911626 245:1.6285714285714286:13091:13092 ~-0.045577511326255565 ~0.012270421240654087 ~0.022961444781767162 "
    s .= "138:0.2109375:13095:13096 ~-0.05010322029528024 ~-0.002741110076069007 79:0.3125:13098:13105 111:-0.0703125:13099:13100 ~0.01456313202011966 14:-0.0625:13101:13104 64:0.15625:13102:13103 ~-0.04972848426720096 "
    s .= "~-0.0044522847300248495 ~0.003078937426842508 10:0.84375:13106:13107 ~0.025371597680208025 ~-0.025759680436853796 122:-0.625:13109:13110 ~0.025494948804518348 61:2.25:13111:13112 ~-0.03564487386520632 ~0.02786436485675735 "
    s .= "~-0.014916713278043843 251:1.328125:13115:13144 247:0.484375:13116:13141 64:1.359375:13117:13140 250:0.9296875:13118:13137 130:1.703125:13119:13134 40:-0.03125:13120:13123 31:-0.046875:13121:13122 ~0.003719819022298419 "
    s .= "~-0.027972813427922835 142:0.171875:13124:13127 251:0.171875:13125:13126 ~-0.03160012642566068 ~0.0258004028122031 251:0.515625:13128:13133 82:0.515625:13129:13130 ~-0.04071379270818323 169:0.15625:13131:13132 "
    s .= "~0.03253189551045749 ~-0.03291353993832263 ~0.016126210024449802 73:0.015625:13135:13136 ~0.007606365488599397 ~-0.05252500682900279 244:1.94:13138:13139 ~-0.011715717911738067 ~0.017685735967257126 ~0.021884735388815118 "
    s .= "241:0.1:13142:13143 ~0.00967962763809585 ~-0.034571874432766096 241:0.46:13145:13152 242:0.55:13146:13149 146:0.015625:13147:13148 ~0.014557057816282857 ~-0.027325402699320808 166:0.671875:13150:13151 ~-0.04000064367924077 "
    s .= "~0.016850413277536627 248:0.125:13153:13154 ~0.02875057509292647 143:-0.28125:13155:13156 ~0.02894337936712357 151:0.125:13157:13158 ~0.013412411928023494 244:1.105:13159:13160 ~0.018611114491471556 ~-0.0507270590060994 "
    s .= "145:-0.125:13162:13171 244:1.4:13163:13170 147:-0.1015625:13164:13165 ~-0.05054936248671276 73:0.015625:13166:13169 17:-0.109375:13167:13168 ~0.018399396232174643 ~-0.02406204581586512 ~-0.04364545248049632 ~0.003283852450288403 "
    s .= "252:0.42500000000000004:13172:13197 207:0.3203125:13173:13194 243:1.25:13174:13193 154:0.40625:13175:13182 166:0.625:13176:13181 14:-0.640625:13177:13178 ~0.010982664347522462 64:0:13179:13180 ~-0.036705581071299544 "
    s .= "~-0.00835673147622493 ~0.0214993834783506 67:0.546875:13183:13192 130:0.765625:13184:13187 82:1.015625:13185:13186 ~0.02871636382656187 ~-0.032039666444401586 4:0.0625:13188:13191 97:-0.046875:13189:13190 ~0.013229822879069361 "
    s .= "~-0.023676596156487126 ~0.01903549401887933 ~-0.024048982688123 ~-0.040336811176927966 7:-0.34375:13195:13196 ~0.017536067480625438 ~-0.027352484607750534 253:-0.005766526019688929:13198:13205 82:1.203125:13199:13204 "
    s .= "10:-0.1875:13200:13201 ~-0.031689216164180314 220:-0.0625:13202:13203 ~-0.012227002103857257 ~0.025304709055797653 ~0.03681281984668157 207:0.1328125:13206:13207 ~-0.023122784288096433 ~0.01643586920481435 "
    s .= "181:-0.703125:13209:13210 ~-0.03995038657815886 251:0.890625:13211:13242 256:0.2653061224489796:13212:13241 64:1.359375:13213:13240 181:0.640625:13214:13231 184:0:13215:13220 250:0.5703125:13216:13217 ~0.029948663186205444 "
    s .= "166:0.21875:13218:13219 ~-0.030515602259315364 ~0.00855353015643009 205:0.625:13221:13230 136:-0.015625:13222:13223 ~0.031145915328983045 244:0.9:13224:13225 ~-0.026248262299360114 103:0.09375:13226:13227 ~0.014755200295680563 "
    s .= "97:0:13228:13229 ~-0.028495111516899742 ~0.0027215401411897822 ~0.028726622224342236 55:0.4375:13232:13239 130:1.296875:13233:13236 235:-0.015625:13234:13235 ~-0.04944895627527906 ~-0.008646696761627824 160:1.671875:13237:13238 "
    s .= "~0.028064510926956568 ~-0.02793802385806618 ~-0.04318464013991684 ~0.024932233822480578 ~-0.0324222281728255 243:0.35:13243:13248 115:0.171875:13244:13247 148:0.171875:13245:13246 ~0.016796992883964017 ~-0.04152174577232396 "
    s .= "~-0.04469724246615199 149:-0.375:13249:13252 142:-0.109375:13250:13251 ~-0.007023567250997344 ~0.026653551609950726 209:-0.8125:13253:13254 ~-0.03867729034745531 ~0.00375504202384061 253:-0.04450757575757791:13256:13277 "
    s .= "252:0.175:13257:13268 219:0.1953125:13258:13263 45:0.2109375:13259:13262 124:-0.140625:13260:13261 ~0.007343558585655792 ~-0.04314922797255023 ~0.02053161608444891 245:1.970873786407767:13264:13265 ~-0.029129134660911517 "
    s .= "122:0.125:13266:13267 ~0.03514933203457204 ~-0.04582805469829172 16:-0.234375:13269:13270 ~-0.013922918702209103 112:0.65625:13271:13276 58:0.671875:13272:13275 76:0.671875:13273:13274 ~-0.020845517090568037 ~0.03146529466979174 "
    s .= "~0.040349473327711105 ~0.03496106082854706 243:1.55:13278:13297 245:2.020408163265306:13279:13290 175:-0.140625:13280:13281 ~-0.03258198683154332 130:0.609375:13282:13285 238:0.234375:13283:13284 ~0.004953893477243725 "
    s .= "~-0.03356045500895643 234:0.4765625:13286:13289 253:-0.03202759300320291:13287:13288 ~-0.031400999352626024 ~0.02718236468771731 ~-0.031383702047374305 31:-0.34375:13291:13294 222:0.2109375:13292:13293 ~-0.005893738977809816 "
    s .= "~0.035377832126627304 221:0.046875:13295:13296 ~-0.004208117156614277 ~-0.024684286765882316 245:2.130434782608696:13298:13299 ~-0.04864888632684917 134:0.03125:13300:13301 ~-0.03775484129527973 ~0.017912000299546375 "
    s .= "248:0.375:13303:13338 244:1.475:13304:13327 31:0.234375:13305:13324 88:1.59375:13306:13323 50:-1.1875:13307:13308 ~0.0401158445249384 134:-0.921875:13309:13310 ~-0.04773801896518414 169:0.09375:13311:13316 238:0.40625:13312:13315 "
    s .= "175:-0.140625:13313:13314 ~-0.017254118854499324 ~0.01675786259953636 ~-0.028009458009067595 109:0.234375:13317:13318 ~0.02367768768836053 100:-0.46875:13319:13320 ~0.03322658553019222 220:0.703125:13321:13322 "
    s .= "~-0.034902003636437355 ~0.0254306608057048 ~0.03233694282080829 245:3.088235294117647:13325:13326 ~-0.0355892878580217 ~0.02513062779009096 250:0.6328125:13328:13333 127:1.53125:13329:13332 245:2.95:13330:13331 "
    s .= "~-0.03786502293591375 ~0.016188473480146116 ~-0.05954272192703996 76:0.265625:13334:13337 109:0.75:13335:13336 ~-0.019713174043673874 ~0.017566464133219502 ~0.029072017780033144 121:-0.21875:13339:13342 151:-0.421875:13340:13341 "
    s .= "~0.009976100858466279 ~-0.04223374308177631 99:-0.4453125:13343:13344 ~-0.04180429302612482 214:0.578125:13345:13346 ~-0.003918722725249439 202:0.453125:13347:13348 ~0.027947322156093204 ~-0.016026483091432637 "
    s .= "248:0.875:13350:13389 203:0.703125:13351:13388 251:0.765625:13352:13361 178:-0.078125:13353:13358 229:-0.234375:13354:13355 ~0.010573397804808411 190:0.1875:13356:13357 ~-0.060102723061773215 ~-0.002206978649396465 "
    s .= "217:-0.125:13359:13360 ~-0.02113413007261268 ~0.0024474568494553452 109:0.546875:13362:13371 100:1.125:13363:13370 238:0.21875:13364:13369 172:-0.1875:13365:13366 ~-0.04218682302919599 242:1.15:13367:13368 ~0.015793364804290073 "
    s .= "~-0.020131267923783704 ~-0.032361044131217154 ~0.028665724352293444 241:0.46:13372:13381 181:0.109375:13373:13378 166:0.890625:13374:13377 169:1.8125:13375:13376 ~-0.04117030555129367 ~0.02933849034977731 ~0.03625663411418266 "
    s .= "140:0.171875:13379:13380 ~0.021987381455759278 ~-0.023188519784205518 178:0.21875:13382:13383 ~0.03447206795160503 7:-0.078125:13384:13387 6:0.109375:13385:13386 ~-0.04309164721512744 ~0.023908185319723534 ~0.01711703458243782 "
    s .= "~-0.038060389240827754 146:0.09375:13390:13395 228:0.0546875:13391:13394 18:0.0078125:13392:13393 ~0.00021568117291741466 ~-0.040948633884722994 ~0.013797287207743637 ~-0.0352716401206329 255:0.234375:13397:13410 "
    s .= "254:0.453125:13398:13403 85:1.125:13399:13402 112:1.609375:13400:13401 ~-0.006720932285946829 ~0.01799742607434418 ~0.010654655541730758 205:-0.21875:13404:13405 ~-0.029160770461166455 145:-0.0625:13406:13407 "
    s .= "~-0.005467964757521549 251:0.140625:13408:13409 ~-0.022677839942282046 ~0.031307023538321266 122:-0.359375:13411:13428 247:0.265625:13412:13427 200:-0.4375:13413:13424 34:-0.0625:13414:13419 133:1.171875:13415:13418 "
    s .= "112:0.046875:13416:13417 ~0.027388303968395006 ~-0.01787368635467182 ~0.026238961363657082 199:0.015625:13420:13423 61:0.140625:13421:13422 ~-0.050089496987349394 ~-0.005581829203937038 ~0.000079554929698941 "
    s .= "47:0.078125:13425:13426 ~0.01900722934140413 ~-0.030312044850855004 ~-0.021977348041207812 254:0.609375:13429:13432 24:-0.2421875:13430:13431 ~-0.04042789427898613 ~0.01184249327537231 252:0.275:13433:13440 40:0.0625:13434:13435 "
    s .= "~-0.04525212789838805 238:0.140625:13436:13439 20:-0.59375:13437:13438 ~0.010653961252061698 ~-0.04617355387059182 ~0.00610123281829912 50:-0.03125:13441:13442 ~0.005670727030755619 ~-0.02627602960431017 124:-0.6875:13444:13445 "
    s .= "~-0.03316627905533411 253:-0.13229995810640985:13446:13451 49:0.328125:13447:13450 67:0.421875:13448:13449 ~0.024641613350918235 ~-0.022830954437171883 ~-0.023590507135239587 239:-0.125:13452:13483 51:-0.0078125:13453:13464 "
    s .= "87:0.0234375:13454:13461 148:-0.046875:13455:13456 ~0.014852890749602205 184:0.015625:13457:13460 109:0.53125:13458:13459 ~0.006675174173683252 ~-0.04780134530349193 ~-0.000544740825737223 2:-0.84375:13462:13463 "
    s .= "~0.01439009694553471 ~-0.03805561732712204 251:0.984375:13465:13476 158:-0.21875:13466:13471 36:0.0078125:13467:13468 ~0.012367765449226804 186:-0.1328125:13469:13470 ~0.004061111449625852 ~-0.03890970582849277 "
    s .= "31:0.1875:13472:13475 153:0.2109375:13473:13474 ~0.0336233125169871 ~-0.007444996218443723 ~-0.02557781678669785 243:0.35:13477:13480 103:0.140625:13478:13479 ~0.019851111691147484 ~-0.04763081084561521 103:-0.03125:13481:13482 "
    s .= "~-0.003236206574482787 ~0.030682508574695802 254:1.078125:13484:13489 175:-0.15625:13485:13488 60:0.6171875:13486:13487 ~-0.03712004514199124 ~0.026134509075108753 ~-0.0018670552889361624 ~-0.03664070119281448 "
    s .= "249:0.16666666666666666:13491:13510 178:-0.078125:13492:13499 235:-0.015625:13493:13496 106:0.375:13494:13495 ~-0.03878243648130364 ~0.021415073117178066 76:0.015625:13497:13498 ~-0.00212311923259887 ~-0.05802363999486582 "
    s .= "253:-0.04278074866310145:13500:13503 166:0.4375:13501:13502 ~0.027762668188983226 ~-0.015741342360448815 242:1.85:13504:13509 245:1.7719298245614035:13505:13508 178:0.609375:13506:13507 ~0.027770286842179637 "
    s .= "~-0.028308145935888457 ~-0.0007909050671855256 ~-0.03606968481532962 184:-0.21875:13511:13512 ~-0.026856838296075547 245:1.5918367346938775:13513:13516 89:0.796875:13514:13515 ~-0.044858752524340836 ~0.023378225076660278 "
    s .= "16:1.0625:13517:13536 219:0.2578125:13518:13529 178:0.125:13519:13522 190:0.359375:13520:13521 ~-0.0010188134102273674 ~0.025984084190712377 44:-0.09375:13523:13526 59:-0.890625:13524:13525 ~0.0190808479432929 "
    s .= "~-0.00852896483960649 244:1.62:13527:13528 ~-0.04637346365487808 ~-0.0067424748833361655 31:-0.34375:13530:13531 ~0.032603769677442614 51:0.0546875:13532:13535 205:0.625:13533:13534 ~-0.02606728140963805 ~0.02613927930059212 "
    s .= "~0.013502414713771935 ~-0.03579553037800699 103:2.484375:13538:13581 248:0.375:13539:13570 244:1.475:13540:13565 31:0.234375:13541:13562 88:1.59375:13542:13561 50:-1.1875:13543:13544 ~0.0392781502358113 134:-0.921875:13545:13546 "
    s .= "~-0.0458410133697088 169:0.09375:13547:13552 238:0.21875:13548:13549 ~0.013641215770303762 51:0.3046875:13550:13551 ~-0.03748142019247494 ~0.018580595149249392 109:0.3125:13553:13556 154:0.25:13554:13555 ~-0.0276319268033229 "
    s .= "~0.036930453756095764 100:-0.46875:13557:13558 ~0.032013332670384934 220:0.703125:13559:13560 ~-0.03580610883360084 ~0.024634603649033693 ~0.031235804955505927 245:3.088235294117647:13563:13564 ~-0.03443170005425523 "
    s .= "~0.024738719815223728 250:0.6328125:13566:13569 121:0.09375:13567:13568 ~0.010006733140129722 ~-0.039387966791623374 ~0.017273459277730663 121:-0.21875:13571:13572 ~-0.03087063077504057 99:-0.4453125:13573:13574 "
    s .= "~-0.04083322805145143 109:0.1875:13575:13576 ~-0.020554846709190035 106:1.46875:13577:13580 166:-0.34375:13578:13579 ~-0.03293179042316159 ~0.009502179275536114 ~-0.02125893336869563 252:0.42500000000000004:13582:13583 "
    s .= "~-0.048669000351639985 ~0.022469212784562348 251:0.484375:13585:13602 37:0.0625:13586:13595 91:0.21875:13587:13590 26:-0.75:13588:13589 ~0.022598521725452375 ~-0.013024448004045508 64:-0.078125:13591:13592 ~-0.03892586803876334 "
    s .= "124:0.140625:13593:13594 ~0.035331618461380575 ~-0.005972412088223468 145:-0.046875:13596:13597 ~-0.04828111406236629 112:0.734375:13598:13599 ~-0.030461259312417124 250:0.6640625:13600:13601 ~-0.03940100757103156 "
    s .= "~0.015157677408570073 209:0.578125:13603:13630 255:0.296875:13604:13605 ~0.007901018315108562 84:-0.1953125:13606:13609 117:-0.1953125:13607:13608 ~-0.0040477867279390374 ~0.02893118547227702 246:-0.734375:13610:13615 "
    s .= "1:-0.21875:13611:13612 ~0.009715863912242516 85:1.53125:13613:13614 ~-0.04157952984514604 ~0.016833670019459356 119:-0.34375:13616:13623 98:-0.171875:13617:13620 204:0.2265625:13618:13619 ~0.030620062982448428 "
    s .= "~-0.007485674985101239 149:-0.515625:13621:13622 ~0.03021555250226904 ~-0.033037904019703634 81:0.2578125:13624:13629 251:1.609375:13625:13628 198:-0.09375:13626:13627 ~0.006191854455681611 ~-0.02412666557167147 "
    s .= "~0.01720917956777859 ~-0.03846586182763806 ~-0.02104725391514764 253:-0.04450757575757791:13632:13651 252:1.775:13633:13650 140:0.140625:13634:13645 250:1.0703125:13635:13644 102:-0.0078125:13636:13641 193:-0.015625:13637:13638 "
    s .= "~-0.04222693896060771 245:2.0943396226415096:13639:13640 ~-0.04003654689510049 ~0.02079329450374226 160:-0.15625:13642:13643 ~-0.028913398050757384 ~0.02069117836797513 ~0.024624835525080723 199:0.078125:13646:13647 "
    s .= "~-0.03401230407967965 48:0.1171875:13648:13649 ~-0.025936043341075563 ~0.01560422133313804 ~0.032818607457509225 243:1.55:13652:13669 73:1.140625:13653:13668 136:2.1875:13654:13665 61:1.359375:13655:13664 205:0.703125:13656:13663 "
    s .= "208:0.46875:13657:13662 245:1.9298245614035088:13658:13659 ~0.006118561984437044 241:0.12:13660:13661 ~0.00900563782486126 ~-0.017685245417791838 ~0.01168021379325525 ~0.013224202579446294 ~0.023106530722984794 "
    s .= "1:0.21875:13666:13667 ~-0.04393596378850162 ~0.017293519835144114 ~-0.032976899554113384 245:2.130434782608696:13670:13673 225:0.6328125:13671:13672 ~-0.05650453576414619 ~0.012118945620891199 145:-0.078125:13674:13675 "
    s .= "~-0.03878153984244759 23:-0.28125:13676:13677 ~-0.031567465044864344 ~0.028750321058589698 248:0.875:13679:13720 115:1.15625:13680:13719 142:0.703125:13681:13716 242:2.05:13682:13713 103:1.078125:13683:13704 "
    s .= "123:-0.2578125:13684:13685 ~-0.02234648543875311 220:1.015625:13686:13703 143:0.15625:13687:13698 25:-0.421875:13688:13689 ~0.027004688285874573 178:1.078125:13690:13697 193:0.140625:13691:13692 ~0.004709017959255022 "
    s .= "79:0.109375:13693:13696 220:0.328125:13694:13695 ~-0.01911595227879974 ~0.030310211300215436 ~-0.023395069960700607 ~0.02538390527090811 17:0.078125:13699:13702 49:0.015625:13700:13701 ~-0.027452138849970283 ~0.02032824099181104 "
    s .= "~-0.029749221025078945 ~0.03155624244174271 181:1.5625:13705:13712 241:0.2:13706:13707 ~-0.02841144538328526 172:-0.25:13708:13709 ~-0.023584447213169817 1:-0.359375:13710:13711 ~-0.017389426718130676 ~0.040031487755666756 "
    s .= "~-0.029255587082445633 136:0.171875:13714:13715 ~0.007625478069112664 ~-0.04529315103409498 253:0.009475084038269103:13717:13718 ~-0.030650251682572495 ~0.014960584167408548 ~0.012825931512010029 146:0.09375:13721:13724 "
    s .= "88:0.125:13722:13723 ~-0.02442276469503929 ~0.005728734095848547 ~-0.034559413088368976 251:0.828125:13726:13745 66:0.5703125:13727:13744 64:1.359375:13728:13743 181:0.640625:13729:13734 202:0.515625:13730:13731 "
    s .= "~-0.003629037907545866 175:0.65625:13732:13733 ~0.027968438992517514 ~-0.03219002587876406 55:0.203125:13735:13742 130:1.28125:13736:13739 25:-0.09375:13737:13738 ~-0.04401240348525034 ~-0.004125627143556578 "
    s .= "160:1.5625:13740:13741 ~0.029130760283505943 ~-0.029644056579977065 ~-0.0388235191241734 ~0.024178622650685717 ~-0.04238629399272528 243:0.35:13746:13751 244:1.11:13747:13748 ~0.026522699101584637 1:-0.34375:13749:13750 "
    s .= "~0.022278858371510113 ~-0.037260623343441275 149:-0.671875:13752:13753 ~0.024131242583015883 231:-0.3828125:13754:13755 ~-0.03735219099613199 109:0.5625:13756:13759 151:0.765625:13757:13758 ~-0.013920502733337673 "
    s .= "~0.01709812577436346 245:3.4761904761904763:13760:13771 252:1.025:13761:13770 132:-0.1015625:13762:13763 ~0.023946785752580208 244:1.2:13764:13765 ~0.021275808308134237 140:-0.078125:13766:13767 ~0.010121246761194703 "
    s .= "214:0.203125:13768:13769 ~-0.04302371886405474 ~0.012788342134188148 ~0.02765891932720061 ~-0.02831896784604855 254:0.984375:13773:13814 191:-0.421875:13774:13783 251:0.734375:13775:13780 213:-0.1953125:13776:13777 "
    s .= "~0.015803106074024978 58:-0.0625:13778:13779 ~0.014141470586283601 ~-0.032878331418417645 34:0.8125:13781:13782 ~0.022518992885496483 ~-0.02591345939156587 110:-0.78125:13784:13787 200:-0.890625:13785:13786 ~0.017668555823081758 "
    s .= "~-0.0545897785884802 121:0.125:13788:13805 124:0.03125:13789:13798 157:1.609375:13790:13797 200:-0.359375:13791:13792 ~0.024100920344911497 118:0.109375:13793:13796 215:-0.3125:13794:13795 ~-0.04275258459741909 "
    s .= "~0.007282049168735031 ~-0.021212429749136553 ~-0.037820882967863206 94:-0.09375:13799:13800 ~-0.01411559446929123 127:0.15625:13801:13802 ~0.030805864508712828 11:-0.34375:13803:13804 ~-0.021190327529789204 ~0.014091969660308299 "
    s .= "48:0.2890625:13806:13813 242:1.15:13807:13812 1:-0.234375:13808:13809 ~0.01990314530515789 1:0.015625:13810:13811 ~-0.04165034290201123 ~-0.006666155864527842 ~-0.03658160253122441 ~0.006824150349908343 194:0.078125:13815:13816 "
    s .= "~-0.0037675156882903517 245:1.9298245614035088:13817:13818 ~0.0077746297326574156 ~-0.05144956398823865 205:-0.25:13820:13827 61:-0.046875:13821:13822 ~-0.041265791860361556 58:0.046875:13823:13824 ~0.018604679342777927 "
    s .= "245:2.6065573770491803:13825:13826 ~-0.032376669873570706 ~0.01176244393022368 70:0.609375:13828:13863 88:1.125:13829:13860 79:0.6875:13830:13859 70:-0.390625:13831:13832 ~0.020686353740908835 226:-0.234375:13833:13834 "
    s .= "~0.01923782973556084 178:0.4375:13835:13852 73:0.0625:13836:13845 97:0.078125:13837:13844 184:0.375:13838:13843 190:0.78125:13839:13840 ~-0.02901610793182435 223:-0.03125:13841:13842 ~0.04169179961422441 ~-0.047688838730357536 "
    s .= "~0.008788863023578238 ~0.025120980091635988 175:0.28125:13846:13851 172:0.421875:13847:13850 243:1.05:13848:13849 ~-0.04801164046987026 ~-0.0020243663369137214 ~0.018623653954163984 ~0.006859168390603909 49:-0.25:13853:13856 "
    s .= "178:0.953125:13854:13855 ~-0.0515249227337706 ~0.014167592444470032 217:-0.140625:13857:13858 ~-0.031922769883156496 ~0.013514330858808802 ~0.011026319073404442 148:0.75:13861:13862 ~0.019686426191124488 ~-0.01569128877231823 "
    s .= "151:0.4375:13864:13865 ~0.0001150927925271603 ~-0.03513167444663164 249:0.5:13867:13894 248:0.875:13868:13891 115:1.15625:13869:13888 99:-0.0390625:13870:13883 139:0.640625:13871:13880 61:0.140625:13872:13877 "
    s .= "103:0.734375:13873:13876 241:0.12:13874:13875 ~0.01644004089998832 ~-0.042031077749425744 ~0.0195402424794323 87:0.0703125:13878:13879 ~0.02130367001088252 ~-0.03234077903961717 165:-0.1015625:13881:13882 ~-0.009315806319021968 "
    s .= "~-0.051532900402026495 193:0.09375:13884:13885 ~0.012421126123219602 106:1.1875:13886:13887 ~-0.012181040677677599 ~0.02161099184852965 208:-0.078125:13889:13890 ~-0.010129640417943038 ~0.027193180999446977 "
    s .= "175:-0.140625:13892:13893 ~0.020316026054914314 ~-0.030378532716653306 172:-0.203125:13895:13898 211:0.578125:13896:13897 ~-0.042399390102232065 ~0.023488827861199112 127:-0.15625:13899:13900 ~0.02451444544496159 "
    s .= "245:1.5918367346938775:13901:13902 ~-0.05063164320353203 145:-0.125:13903:13904 ~-0.033789838256847546 251:0.828125:13905:13910 211:0.34375:13906:13909 64:1.28125:13907:13908 ~-0.03135190207613503 ~0.029106377270598983 "
    s .= "~0.013553837612299086 19:0.390625:13911:13912 ~0.014450266072887685 ~-0.02889873879115303 159:0.5234375:13914:13959 145:-0.125:13915:13922 244:1.4:13916:13921 147:-0.1015625:13917:13918 ~-0.04724598567476467 "
    s .= "73:0.015625:13919:13920 ~0.00359824834060674 ~-0.04137826438108823 ~0.0027742772555808437 252:0.42500000000000004:13923:13948 190:0:13924:13935 202:0.484375:13925:13934 217:0.640625:13926:13933 46:0.453125:13927:13932 "
    s .= "73:0.828125:13928:13931 253:0.1857142857142861:13929:13930 ~-0.038817338623152904 ~0.02964180449177243 ~0.027130829596616158 ~0.013975342164894761 ~0.0267134705693452 ~0.01918665011946986 73:0.6875:13936:13947 "
    s .= "118:-0.046875:13937:13938 ~-0.012870039921285506 49:0.53125:13939:13946 1:0.15625:13940:13945 55:0.171875:13941:13942 ~0.009549830747693078 154:0.59375:13943:13944 ~-0.03955956379195094 ~0.015862681859007254 ~0.020479161506150128 "
    s .= "~-0.027520374498077267 ~-0.04355581638815367 253:-0.008872756604153173:13949:13954 82:0.78125:13950:13951 ~0.004914438547933361 1:0.8125:13952:13953 ~0.03487234100921743 ~-0.04217254028833334 207:0.1328125:13955:13958 "
    s .= "241:1.86:13956:13957 ~-0.002243761146324338 ~-0.044241695346545096 ~0.016866204717333133 ~-0.02373609393353743 253:-0.13229995810640985:13961:13968 252:0.125:13962:13967 71:0.140625:13963:13966 36:-0.0390625:13964:13965 "
    s .= "~-0.02536429781762921 ~0.024986511889671655 ~-0.04834081778014589 ~0.027847857811821548 239:-0.125:13969:13992 252:0.475:13970:13987 242:0.55:13971:13980 138:-0.5703125:13972:13973 ~-0.02704815583837742 183:0.1953125:13974:13975 "
    s .= "~0.01185123010930439 23:-0.0625:13976:13979 34:-0.28125:13977:13978 ~0.017729049966310733 ~-0.03309662648501968 ~0.01649508732685495 85:0.15625:13981:13982 ~-0.036935003504383945 253:0.025862068965513647:13983:13986 "
    s .= "87:-0.2578125:13984:13985 ~0.013177641338012122 ~-0.024405754565271845 ~0.01742451035582977 48:0.0078125:13988:13991 241:1.26:13989:13990 ~0.012408411548312105 ~-0.02663913302120646 ~0.026005532071959436 246:0.359375:13993:13996 "
    s .= "255:0.234375:13994:13995 ~-0.006432989417315391 ~-0.029563696161577 252:2.125:13997:14006 214:0.390625:13998:14003 191:0.5625:13999:14002 248:0.875:14000:14001 ~-0.00018016123056385363 ~-0.03474240869605008 ~-0.042310539651238106 "
    s .= "27:0.296875:14004:14005 ~0.02800453260170061 ~-0.02255374620063276 ~0.02360039709631053 122:0.25:14008:14051 246:0.609375:14009:14048 247:0.234375:14010:14043 249:1.8333333333333335:14011:14042 178:1.078125:14012:14039 "
    s .= "160:1.125:14013:14036 246:-0.828125:14014:14019 122:-0.546875:14015:14018 118:0.0625:14016:14017 ~-0.025287366998351126 ~0.006464772755477997 ~-0.041166474871456485 244:1.985:14020:14033 249:0.16666666666666666:14021:14024 "
    s .= "90:0.1328125:14022:14023 ~0.018778941077563754 ~-0.017796999999042523 119:-0.46875:14025:14028 53:-0.421875:14026:14027 ~0.03126475048843013 ~-0.018898978557112537 124:0.109375:14029:14032 81:0.0859375:14030:14031 "
    s .= "~0.010951753764359702 ~-0.02688975524109374 ~-0.028469173111423707 32:0.171875:14034:14035 ~-0.0330720494598418 ~0.031534051528628315 7:0.25:14037:14038 ~0.021101652758290186 ~-0.015035657028387845 175:1.625:14040:14041 "
    s .= "~0.02218517002088219 ~-0.018228235253232573 ~-0.027650521406950845 130:0.3125:14044:14047 192:0.3828125:14045:14046 ~-0.022649343256184604 ~0.02927230377530825 ~-0.027749014416953766 120:0.1796875:14049:14050 "
    s .= "~-0.0009558459525685044 ~0.02347353645102533 86:0.765625:14052:14053 ~-0.017720567780593867 ~0.011532129594920951 256:0.9166666666666666:14055:14100 254:0.984375:14056:14085 118:0.28125:14057:14074 50:0.34375:14058:14073 "
    s .= "120:0.1640625:14059:14072 227:-0.375:14060:14063 152:0.109375:14061:14062 ~0.016304328725563273 ~-0.031388021667283446 103:0:14064:14069 85:0.09375:14065:14066 ~-0.050942804422007104 207:0.1328125:14067:14068 "
    s .= "~-0.02530728928324974 ~0.027672486249168772 124:0.21875:14070:14071 ~0.01252308186483272 ~-0.014307228446239925 ~0.015921873377713402 ~-0.015116847430662465 249:0.8333333333333333:14075:14084 253:0.019999999999998862:14076:14083 "
    s .= "178:0.03125:14077:14078 ~0.013262240955017832 58:0.59375:14079:14082 208:0.40625:14080:14081 ~-0.01709320538075799 ~0.021024436744474802 ~-0.0406725141796941 ~0.0180666489308328 ~-0.02508972806262882 122:-0.109375:14086:14097 "
    s .= "246:-0.390625:14087:14094 191:-0.796875:14088:14093 245:2.161764705882353:14089:14090 ~-0.022236199998359872 255:0.609375:14091:14092 ~0.02677609639933519 ~-0.017453006407572833 ~-0.018614263118162035 100:0.0625:14095:14096 "
    s .= "~-0.011327911574187324 ~0.02221427866911517 245:1.921875:14098:14099 ~0.002275820631807378 ~-0.03683486727830558 ~-0.0288673100537254 "
    return s
}
