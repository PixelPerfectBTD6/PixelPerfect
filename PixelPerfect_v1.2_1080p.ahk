#Requires AutoHotkey v2.0+
#SingleInstance Force
#UseHook
#MaxThreadsPerHotkey 1

; ============================================================
; Combined: Coords slots + range overlay (nudges only)
; Target: BTD6 @ 1920x1080, client coords
;
; Slot hotkeys (only when BTD6 active):
;   Ctrl+B  : next slot
;   Ctrl+N  : previous slot
;   Ctrl+M  : move mouse to current slot
;   Ctrl+S  : save current mouse position to current slot as SUPER (type 's')
;   Ctrl+A  : save current mouse position to current slot as NORMAL (type 'a')
;   Ctrl+W  : toggle current slot type (s <-> a)
;   Ctrl+E  : delete current slot
;
; Pixel nudges (overlay shows ONLY on these):
;   Ctrl+I/J/K/L : move 1 pixel (client coords)
;
; Other:
;   Ctrl+Enter : click (no overlay)
;   F6         : show client size
;   F7         : toggle slot list (top-left of client)
;   Ctrl+Esc   : exit
;
; ============================================================

DllCall("SetProcessDpiAwarenessContext", "ptr", -4) ; PER_MONITOR_AWARE_V2

; ---------------------------
; Window / files
; ---------------------------
global btd6WinTitle := "ahk_exe BloonsTD6.exe"
CoordMode "Mouse", "Client"

global TIP_MS := 900
global DATA_FILE := A_ScriptDir "\btd6_slots_list_1080p.txt"

; ---------------------------
; Slots state
; ---------------------------
global currentSlot := 1
global maxSlot := 99
global slots := Map()
global lastSlotsMTime := ""

; ---------------------------
; Range indicator formulae
; ---------------------------
global specialSlotIdx := 1

; Normal towers (slot 2+)
global AxN := 536
global AyN := 464
global SlackN := 400000000

; Special slot 1 tower
global Ax1 := 698
global Ay1 := 604
global Slack1 := 500000000

; ---------------------------
; Overlay behaviour (nudge overlay)
; ---------------------------
global overlayOn := true
global hideAfterMs := 2000

global tipGui := 0
global tipText := 0

; Compact overlay sizing controls
global OVERLAY_TEXT_W := 240
global OVERLAY_LINE_H := 16
global OVERLAY_PAD_TEXT := 6
global OVERLAY_MAX_LINES := 20

; ---------------------------
; Slot list overlay (F7)
; ---------------------------
global slotListGui := 0
global slotListText := 0
global slotListVisible := false

global SLOT_LIST_TEXT_W := 420
global SLOT_LIST_LINE_H := 16
global SLOT_LIST_PAD_TEXT := 6
global SLOT_LIST_OFFSET_X := 6
global SLOT_LIST_OFFSET_Y := 6
global SLOT_LIST_MAX_LINES := 200  ; safety cap

; ---------------------------
; Init
; ---------------------------
LoadSlotsFromFile()
InitOverlayGui()
InitSlotListGui()

ShowTip("Ready (1080). Slot " currentSlot)
OnExit (*) => SaveSlotsToFile()

; ---------------------------
; Hotkeys
; ---------------------------
^Esc:: ExitApp

^j:: MovePixelAndOverlay(-1, 0)
^l:: MovePixelAndOverlay( 1, 0)
^i:: MovePixelAndOverlay( 0,-1)
^k:: MovePixelAndOverlay( 0, 1)

^Enter:: {
    EnsureBTD6Active()
    Click
}

F6:: ShowClientSize()
F7:: ToggleSlotList()

#HotIf WinActive(btd6WinTitle)
^b::NextSlot()
^n::PrevSlot()
^m::MoveCurrentSlot()
^s::SaveCurrentSlot("s")     ; SUPER
^a::SaveCurrentSlot("a")     ; NORMAL
^w::ToggleCurrentSlotType()  ; TOGGLE s <-> a
^e::DeleteCurrentSlot()
#HotIf

; ============================================================
; Slot management
; Each slot stores: {x: int, y: int, t: "s"|"a"}
; "s" = super monkey (included in range checks)
; "a" = normal monkey (ignored by range checks)
; ============================================================
NextSlot() {
    global currentSlot, maxSlot
    currentSlot := Min(maxSlot, currentSlot + 1)
    ShowTip("Slot " currentSlot)
    HideOverlay()
}

PrevSlot() {
    global currentSlot
    currentSlot := Max(1, currentSlot - 1)
    ShowTip("Slot " currentSlot)
    HideOverlay()
}

SaveCurrentSlot(slotType := "s") {
    global currentSlot, slots
    EnsureBTD6Active()
    MouseGetPos &cx, &cy

    slotType := NormaliseSlotType(slotType)
    slots[currentSlot] := {x: cx, y: cy, t: slotType}

    SaveSlotsToFile()
    ShowTip("Saved slot " currentSlot ": " cx "," cy " (" slotType ")")
    HideOverlay()

    ; Keep the F7 list accurate if it's open
    if (IsSlotListVisible())
        RenderSlotList()
}

ToggleCurrentSlotType() {
    global currentSlot, slots

    EnsureBTD6Active()

    if !slots.Has(currentSlot) {
        ShowTip("Slot " currentSlot " empty")
        HideOverlay()
        return
    }

    pos := slots[currentSlot]
    cur := NormaliseSlotType(pos.t)
    pos.t := (cur = "s") ? "a" : "s"
    slots[currentSlot] := pos

    SaveSlotsToFile()
    ShowTip("Slot " currentSlot " type now (" pos.t ")")
    HideOverlay()

    if (IsSlotListVisible())
        RenderSlotList()
}

MoveCurrentSlot() {
    global currentSlot, slots
    EnsureBTD6Active()
    if !slots.Has(currentSlot) {
        ShowTip("Slot " currentSlot " empty")
        HideOverlay()
        return
    }
    pos := slots[currentSlot]
    MouseMove pos.x, pos.y, 0
    ShowTip("Moved to slot " currentSlot ": " pos.x "," pos.y " (" pos.t ")")
    HideOverlay()
}

DeleteCurrentSlot() {
    global currentSlot, slots
    if slots.Has(currentSlot) {
        slots.Delete(currentSlot)
        SaveSlotsToFile()
        ShowTip("Deleted slot " currentSlot)
    } else {
        ShowTip("Slot " currentSlot " already empty")
    }
    HideOverlay()

    if (IsSlotListVisible())
        RenderSlotList()
}

NormaliseSlotType(t) {
    t := StrLower(Trim(t))
    if (t = "a")
        return "a"
    return "s"
}

SaveSlotsToFile() {
    global DATA_FILE, slots
    fileText := ""

    loop 99 {
        idx := A_Index
        if !slots.Has(idx)
            continue
        pos := slots[idx]
        t := NormaliseSlotType(pos.HasOwnProp("t") ? pos.t : "s")
        fileText .= idx "," pos.x "," pos.y "," t "`n"
    }

    try FileDelete DATA_FILE
    if (fileText != "")
        FileAppend fileText, DATA_FILE

    global lastSlotsMTime
    try lastSlotsMTime := FileGetTime(DATA_FILE, "M")
}

LoadSlotsFromFile() {
    global DATA_FILE, slots, lastSlotsMTime
    slots := Map()

    if !FileExist(DATA_FILE) {
        lastSlotsMTime := ""
        return
    }

    lastSlotsMTime := FileGetTime(DATA_FILE, "M")

    raw := Trim(FileRead(DATA_FILE), "`r`n")
    if (raw = "")
        return

    for line in StrSplit(raw, "`n") {
        line := Trim(line, "`r`n")
        if (line = "")
            continue

        parts := StrSplit(line, ",")
        if (parts.Length < 3)
            continue

        idx := Integer(Trim(parts[1]))
        x := Integer(Trim(parts[2]))
        y := Integer(Trim(parts[3]))

        ; Backwards compat: if no type, default to "s"
        t := "s"
        if (parts.Length >= 4)
            t := NormaliseSlotType(parts[4])

        slots[idx] := {x: x, y: y, t: t}
    }
}

MaybeReloadSlots() {
    global DATA_FILE, lastSlotsMTime
    if !FileExist(DATA_FILE)
        return

    t := FileGetTime(DATA_FILE, "M")
    if (t != lastSlotsMTime) {
        lastSlotsMTime := t
        LoadSlotsFromFile()
    }
}

; ============================================================
; Slot list overlay (F7)
; ============================================================
InitSlotListGui() {
    global slotListGui, slotListText, SLOT_LIST_TEXT_W

    slotListGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
    slotListGui.MarginX := 8
    slotListGui.MarginY := 6

    slotListText := slotListGui.AddText("w" SLOT_LIST_TEXT_W, "")
    slotListGui.BackColor := "111111"
    slotListText.Opt("cFFFFFF")
}

IsSlotListVisible() {
    global slotListVisible
    return slotListVisible
}

ToggleSlotList() {
    global slotListVisible
    EnsureBTD6Active()

    slotListVisible := !slotListVisible
    if (slotListVisible)
        RenderSlotList()
    else
        HideSlotList()
}

HideSlotList() {
    global slotListGui
    if IsObject(slotListGui)
        slotListGui.Hide()
}

RenderSlotList() {
    global slotListGui, slotListText, slots
    global SLOT_LIST_TEXT_W, SLOT_LIST_LINE_H, SLOT_LIST_PAD_TEXT
    global SLOT_LIST_OFFSET_X, SLOT_LIST_OFFSET_Y, SLOT_LIST_MAX_LINES
    global specialSlotIdx

    MaybeReloadSlots()

    lastFilled := 0
    for idx, _ in slots {
        if (idx > lastFilled)
            lastFilled := idx
    }

    if (lastFilled <= 0) {
        msg := "No slots assigned"
    } else {
        msg := ""
        Loop lastFilled {
            i := A_Index
            if slots.Has(i) {
                pos := slots[i]
                t := NormaliseSlotType(pos.t)
                label := (t = "s") ? "Super" : "Normal"
                if (i = specialSlotIdx) && (t = "s")
                    label := "Super (VTSG)"
                msg .= "Slot " i " - " pos.x ", " pos.y " - " label "`n"
            } else {
                msg .= "Slot " i " - EMPTY`n"
            }
        }
        msg := RTrim(msg, "`n")
    }

    slotListText.Value := msg

    ; Dynamic height
    lineCount := StrSplit(msg, "`n").Length
    if (lineCount > SLOT_LIST_MAX_LINES)
        lineCount := SLOT_LIST_MAX_LINES

    textH := SLOT_LIST_PAD_TEXT + lineCount * SLOT_LIST_LINE_H
    slotListText.Move(, , SLOT_LIST_TEXT_W, textH)

    guiW := SLOT_LIST_TEXT_W + (slotListGui.MarginX * 2) + 6
    guiH := textH + (slotListGui.MarginY * 2) + 6

    ; Position at top-left of BTD6 client (screen coords)
    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, btd6WinTitle)
        slotListGui.Show("NoActivate x" (cx + SLOT_LIST_OFFSET_X) " y" (cy + SLOT_LIST_OFFSET_Y) " w" guiW " h" guiH)
    } catch {
        ; Fallback: show near cursor if we cannot read client rect
        GetCursorScreenPos(&sx, &sy)
        slotListGui.Show("NoActivate x" (sx + 10) " y" (sy + 10) " w" guiW " h" guiH)
    }
}

; ============================================================
; Overlay + range check (nudge overlay)
; ============================================================
InitOverlayGui() {
    global tipGui, tipText, OVERLAY_TEXT_W
    tipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
    tipGui.MarginX := 8
    tipGui.MarginY := 6
    tipText := tipGui.AddText("w" OVERLAY_TEXT_W, "")
}

RenderOverlay(x, y) {
    global tipGui, tipText, slots, hideAfterMs

    MaybeReloadSlots()

    ; When nudging pixels, always pretend the "candidate" at (x,y) is a SUPER placement.
    ; Saved NORMAL slots are still ignored as blockers.
    hits := []

    for idx, pos in slots {
        ; Only SUPER slots participate in range formulas
        if (NormaliseSlotType(pos.t) != "s")
            continue

        if IsInRangePair(x, y, pos.x, pos.y, 0, idx)
            hits.Push(idx)
    }

    msg := x "," y

    if (hits.Length > 0) {
        SortNumericArray(hits)

        msg .= "`nIN range of " hits.Length " slot(s)"
        msg .= "`ninterferes with:"

        maxList := 12
        shown := 0
        for _, idx in hits {
            shown += 1
            if (shown > maxList)
                break
            msg .= "`nSlot " idx
        }
        if (hits.Length > maxList)
            msg .= "`n... +" (hits.Length - maxList) " more"

        tipGui.BackColor := "AA0000"
        tipText.Opt("cFFFFFF")
    } else {
        msg .= "`nOUT of range (all super slots)"
        tipGui.BackColor := "00AA00"
        tipText.Opt("c000000")
    }

    tipText.Value := msg
    sz := ComputeOverlaySize(msg)

    GetCursorScreenPos(&sx, &sy)
    tipGui.Show("NoActivate x" (sx + 18) " y" (sy + 18) " w" sz.w " h" sz.h)

    SetTimer(HideOverlay, 0)
    SetTimer(HideOverlay, -hideAfterMs)
}

ComputeOverlaySize(msg) {
    global tipGui, tipText
    global OVERLAY_TEXT_W, OVERLAY_LINE_H, OVERLAY_PAD_TEXT, OVERLAY_MAX_LINES

    lineCount := StrSplit(msg, "`n").Length
    if (lineCount > OVERLAY_MAX_LINES)
        lineCount := OVERLAY_MAX_LINES

    textH := OVERLAY_PAD_TEXT + lineCount * OVERLAY_LINE_H

    tipText.Move(, , OVERLAY_TEXT_W, textH)

    guiW := OVERLAY_TEXT_W + (tipGui.MarginX * 2) + 6
    guiH := textH + (tipGui.MarginY * 2) + 6

    return {w: guiW, h: guiH}
}

HideOverlay() {
    global tipGui
    if IsObject(tipGui)
        tipGui.Hide()
}

IsInRangePair(x1, y1, x2, y2, idx1, idx2) {
    global specialSlotIdx, AxN, AyN, SlackN, Ax1, Ay1, Slack1
    if (idx1 = specialSlotIdx) || (idx2 = specialSlotIdx)
        return IsInRangeEllipseSlack(x1, y1, x2, y2, Ax1, Ay1, Slack1)
    else
        return IsInRangeEllipseSlack(x1, y1, x2, y2, AxN, AyN, SlackN)
}

IsInRangeEllipseSlack(x1, y1, x2, y2, Ax, Ay, slack) {
    dx := Abs(x2 - x1)
    dy := Abs(y2 - y1)

    left  := 4*dx*dx*Ay*Ay + 4*dy*dy*Ax*Ax
    right := Ax*Ax*Ay*Ay

    return left <= right + slack
}

MovePixelAndOverlay(dx, dy) {
    global overlayOn
    EnsureBTD6Active()

    DllCall("mouse_event", "UInt", 0x0001, "Int", dx, "Int", dy, "UInt", 0, "UPtr", 0)

    if overlayOn {
        MouseGetPos(&x, &y)
        RenderOverlay(x, y)
    }
}

; ============================================================
; Utility
; ============================================================
ShowTip(msg) {
    global TIP_MS
    ToolTip msg
    SetTimer(() => ToolTip(), -TIP_MS)
}

EnsureBTD6Active() {
    global btd6WinTitle
    if !WinExist(btd6WinTitle) {
        ShowTip("BTD6 not found")
        return
    }
    if !WinActive(btd6WinTitle) {
        try WinActivate btd6WinTitle
        try WinWaitActive btd6WinTitle, , 0.3
    }
}

GetCursorScreenPos(&sx, &sy) {
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "Ptr", pt)
    sx := NumGet(pt, 0, "Int")
    sy := NumGet(pt, 4, "Int")
}

ShowClientSize() {
    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, "A")
        ToolTip "Client size: " cw " x " ch "`nClient top-left (screen): " cx "," cy
        SetTimer(() => ToolTip(), -2000)
    } catch {
        ToolTip "Could not read client size."
        SetTimer(() => ToolTip(), -2000)
    }
}

SortNumericArray(arr) {
    len := arr.Length
    if (len < 2)
        return
    Loop len - 1 {
        Loop len - A_Index {
            j := A_Index
            if (arr[j] > arr[j + 1]) {
                tmp := arr[j]
                arr[j] := arr[j + 1]
                arr[j + 1] := tmp
            }
        }
    }
}
