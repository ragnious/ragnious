#Requires AutoHotkey v2.0
#SingleInstance Off

; EARLY DEFAULTS: hotkeys (Enter / Escape and their #HotIf conditions) are live from the very first moment the script runs, also while the
; startup MsgBox dialogs below are open. Every global they read must therefore already have a value here, otherwise a key press
; during startup raised "This global variable has not been assigned a value". (The normal declarations further down stay as they are.)
global isKeyActionDown := false, enterBuffered := false, riskKeyHeld := false, enterPressCancelled := false, riskKeyCancel := false
global pressedControl := "", riskPressedName := "", riskViewActive := false, riskViewBusy := false, riskBtnAnimating := false
global fadeInTail := false, actionLocked := false, toggleRunning := false, togglePending := 0, connLost := false
global rpcConnecting := false, rpcConnectStart := 0, helperLaunching := false, helperLaunchStart := 0
global isSearchMenuOpen := false, isGameSearchFocused := false, isExiting := false

isExiting := false
; Set to true to write click-to-screen timestamps for Start (exe) and Continue (Rich Presence) to Ragnious_timing.log next to the script.
global debugTiming := false
selectorFrameGui := ""
selectorPopup := ""
global refreshOverlay := "", refreshOverlayCtl := "", refreshOverlayShown := false, refreshOverlayGeom := ""
global emptyQueryTitles := "", emptyQuerySource := ""   ; cached dropdown contents for an empty search (built once per loaded list)
global suppressFilterStatus := false                     ; true while a caller will set the final status message itself
global prewarmBuildActive := false                          ; true only while PrewarmDropdown builds the hidden dropdown
isGameSearchFocused := false
isSearchMenuOpen := false
riskViewActive := false      ; read by a #HotIf condition: must exist before the first key press, even while the script is still starting
global searchMenuGui := "", searchMenuItems := [], searchMenuHover := 0, searchMenuPressed := 0
global searchMenuLeftWasDown := false, searchMenuAnyWasDown := false, searchMenuSwallowRightUp := false
appIsInactive := false
dropdownToggleCooldown := 0
actionBtnColor := "208A4E"
actionBtnLabel := "Start"
actionBtnBaseFontSize := 22        ; Start / Stop label size (pt); the press animation scales it down from here
actionBtnFontSize := actionBtnBaseFontSize
actionBtnScale := 1.0              ; press animation scale (the pill is drawn smaller INSIDE the fixed-size window)
keyNavMouseX := 0
keyNavMouseY := 0

mutexName := "Local\MyProject_AHK_SingleInstance_7A3D91"
DllCall("SetLastError", "UInt", 0)
mutexHandle := DllCall("CreateMutexW", "Ptr", 0, "Int", 0, "Str", mutexName, "Ptr")
if (A_LastError = 183) {
    DllCall("CloseHandle", "Ptr", mutexHandle)
    MsgBox("The application is already running.", "Ragnious: Discord Quests Completer", "Iconi")
    ExitApp()
}

if (!IsInternetAvailable()) {
    MsgBox("No internet connection was detected.`n`nYou need to connect to the internet, then open the application again.", "Ragnious: Discord Quests Completer", "Iconi")
    ExitApp()
}

; UPDATER: leftovers of a finished update (the previous version is renamed to .old while the new one starts)
try FileDelete(A_ScriptFullPath ".old")
try FileDelete(A_Temp "\Ragnious_update.download")

Persistent()
DllCall("winmm\timeBeginPeriod", "UInt", 1)
try ProcessSetPriority("AboveNormal")

gdiplusStartupInput := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
NumPut("UInt", 1, gdiplusStartupInput, 0)
gdiplusTokenBuffer := Buffer(A_PtrSize, 0)
gdiplusToken := 0
if (DllCall("gdiplus\GdiplusStartup", "Ptr", gdiplusTokenBuffer, "Ptr", gdiplusStartupInput, "Ptr", 0, "UInt") = 0)
    gdiplusToken := NumGet(gdiplusTokenBuffer, 0, "UPtr")

global isActionAnimating := false, currentAnimId := 0, isKeyActionDown := false
global globalExitAppAfter := false, globalMinimizeAfter := false, pressedControl := ""
global isRunning := false, sanitizingText := false, targetPid := 0, tempExePath := "", tempScriptPath := "", tempWorkDir := "", activeProcessName := "", hasMinimizedBefore := false
global statusMarqueeGui := "", statusMarqueeText := "", marqueeTrackText := ""
global marqueeStripDc := 0, marqueeStripBmp := 0, marqueeStripOld := 0, marqueeStripH := 0, marqueeStripDirty := true
global marqueeViewportX := 0, marqueeViewportY := 0, marqueeViewportW := 0, marqueeViewportH := 0, marqueeViewportNeedsShow := true, marqueeRenderedX := 0
global isWindowMoving := false
; Internet status messages (see the CONNECTION LOSS HANDLING block: lost / interrupted / paused messages are locked on the status line until the connection is back).
global internetMsgNone := "System Error: No internet connection. You need to connect to the internet."
global internetMsgLost := "System Error: Internet connection was interrupted while loading the game list. You need to reconnect."
global internetMsgBack := "Internet connection restored. You can continue using the app."
global internetWatchXhr := "", internetWatchStart := 0
; ---- CONNECTION LOSS HANDLING (see HandleConnectionLoss / HandleConnectionRestored / ConnectionWatchTick) ----
global internetMsgGeneral := "System Error: Internet connection was lost. You need to reconnect to continue using the app."
global internetMsgPaused := "System Error: The system has paused because the internet connection was lost. It will continue automatically once you reconnect."
global internetMsgBackResume := "Internet connection restored. The system is continuing and starting the process again..."
global connLost := false            ; true from the moment the loss is detected until the connection is back: Start / Continue / Refresh are frozen
global connMsg := ""                ; the ONE connection-lost message of this outage; nothing else (not even another lost message) may replace it
global connBusy := false            ; true while HandleConnectionLoss is still stopping the process (a restore must wait)
global connLastStart := ""          ; how the current / last process was started: ["exe", name, safeDir, exePath] or ["rpc", name, appId]
global connResume := ""             ; what to start again automatically when the connection is back (set when a running process was paused)
global connResumeToken := 0, connResumeDelayMs := 2500   ; the "restored + continuing" message stays this long before the process starts again
global connProbe := "", connProbeStart := 0, connProbeIdx := 0, connFails := 0
global windowDragActive := false, windowDragMouseX := 0, windowDragMouseY := 0, windowDragWinX := 0, windowDragWinY := 0, windowDragLastX := 0, windowDragLastY := 0
; MOTION MODEL: the speed table (Hz -> N -> px/s) is unchanged. N is still the number of screen refreshes that make up ONE pixel.
; ONE ENGINE FOR ALL THREE MARQUEES (status line, popup title, dropdown titles): the same speed table, the same MarqueeTick step, the
; same sub-pixel strips (BuildSubpixelBands), the same refresh counting. Every one of them spreads the pixel over the N refreshes
; (1/N px on EVERY refresh) = same speed, 30-43 visible updates/s become one per display refresh. Only the STYLE differs
; (status: endless loop | popup title + dropdown: slide to the end, hold, jump back) and each one keeps its own look.
; Original description of the whole-pixel mode: both marquees move in whole pixels, locked to the display refresh: ONE pixel every marqueeFrameStep (= N) screen refreshes.
; ONE speed for the status message AND the dropdown titles. Every jump is exactly 1 px and lasts exactly N real refreshes,
; so there is no timing stutter. N comes from a per-refresh-rate table in ChooseMarqueeStep (speeds 24-43 px/s, never below
; 30 px/s from 60 Hz up, never above ~43 px/s). The speed rises gently with the refresh rate; whole-number N makes a few small
; dips unavoidable (e.g. 75 Hz -> 37.5 but 90 Hz -> 30), they are kept as small as possible.
; Unlisted refresh rates use the fallback in ChooseMarqueeStep: target ramps from marqueeMinSpeed (30 px/s at 60 Hz) to
; marqueeTopSpeed (40 px/s at 240 Hz and above); marqueeCapSpeed is the hard ceiling; below 60 Hz the floor is marqueeFloorLowSpeed.
global marqueeTopSpeed := 40, marqueeMinSpeed := 30, marqueeCapSpeed := 43, marqueeFloorSpeed := 29.9, marqueeFloorLowSpeed := 23.9, marqueeLowHz := 60, marqueePeakHz := 240, marqueePxStep := 1
global marqueeRefreshHz := 60, marqueeFrameStep := 1, marqueeFrames := 0, dropdownMarqueeFrames := 0
global marqueeOffset := 0.0, dropdownMarqueeOffset := 0.0
; SMOOTH MOTION (status line + popup title). The speed table above is unchanged (same px/s at every refresh rate), but instead of
; jumping 1 whole pixel every N refreshes these two now move 1/N px on EVERY refresh. The text is pre-rendered at marqueeSubpxPhases
; sub-pixel offsets (grayscale anti-aliased, GDI+), and each frame copies the band that matches the exact position.
;   marqueeSubpixel     false = old whole-pixel stepping (everything else in this fix stays active)
;   marqueeSubpxYAdjust nudge the smooth text up/down in pixels if it sits 1 px off compared to the old text (e.g. -1 or 1)
;   marqueeSubpxUsePath  true = glyph OUTLINES are filled at the exact fractional position (no per-letter pixel snapping, no shaking);
;                         false = GDI+ DrawString (crisper, but GDI+ may snap each letter to a whole pixel on its own = letters 'shake')
;   mainWindowComposited  false = drop WS_EX_COMPOSITED from the main window (test switch if flicker remains)
global marqueeSubpixel := true, marqueeSubpxPhases := 8, marqueeSubpxYAdjust := 0.0, marqueeSubpxUsePath := true
global marqueeStripPhases := 1, marqueeRenderedPhase := 0, marqueeCycleText := ""
global riskTitleStripPhases := 1, riskTitleRenderedPhase := 0
global mainWindowComposited := true
; FRAME-PACING FIX: time budget (ms) one MarqueeMaster call may spend AFTER its first display refresh before it hands control back.
; Measured from the first DwmFlush return (the wait for the refresh itself no longer eats the budget), so at 60-144 Hz one call serves
; several refreshes in a row instead of returning after every single one (each return used to cost a timer-latency gap = skipped refresh).
; Lower = more responsive buttons while text scrolls, higher = steadier text. 10 = old behaviour.
global marqueeBudgetMs := 20
; SHIMMER FIX: true = the sub-pixel text is anti-aliased with gamma-correct blending (GDI+ CompositingQualityGammaCorrected). Plain
; blending makes a stem look dimmer when it straddles two pixels than when it sits on one, so the text pulses in brightness while
; it slides = "shimmer". Gamma-correct blending keeps the total light constant at every sub-pixel position. false = old look.
global marqueeSubpxGamma := true
; FADE-IN HITCH FIX: false = while the main window fades IN (popup closing) the status line stays in its own real control and is painted
; directly every refresh, exactly like during normal scrolling. true = old behaviour: the line is moved into the stand-alone overlay
; window for the fade and handed back at the end (that hand-over shows the control again, which re-prints the composited window tree
; = the one-frame stall at the end of the fade-in). The fade-OUT (popup opening) still uses the overlay either way.
global statusFadeInOverlay := false
global riskBuildDone := false
global refreshBlockMsg := "", refreshBlockPrevText := "", refreshBlockPrevType := "ready"   ; refresh is refused while a created process is active (see RefreshBlockedWhileActive)
global dotPaintHex := ""     ; current tone of the blinking status dot (the dot is owner-drawn and painted straight onto its own pixels)
; Popup (Rich Presence warning) title marquee: third user of the SAME frame engine (MarqueeAdvance / MarqueeMaster).
global riskTitleCtl := "", riskTitleActive := false, riskTitleText := "", riskTitleOffset := 0.0, riskTitleLastTick := 0, riskTitlePauseUntil := 0
global riskTitleOverflowW := 0, riskTitleCycleW := 0, riskTitleTrackW := 0, riskTitleInset := 8, riskTitleRenderedX := 0, riskTitleFrames := 0
global riskTitleStripDc := 0, riskTitleStripBmp := 0, riskTitleStripOld := 0, riskTitleStripH := 0, riskTitleStripDirty := true
global riskLineGui := "", riskLineCtl := ""
InitMarqueeTiming()
OnMessage(0x8001, MarqueeKickMsg)   ; wake-up message posted by MarqueeMaster (faster than a SetTimer(-1) tick)

mainGui := Gui("-Caption +E0x80000" . (mainWindowComposited ? " +E0x02000000" : ""), "Ragnious")
mainGui.BackColor := "000000"
mainGui.OnEvent("Close", CloseApplication)

; ================================ UPDATER ================================
; appVersion is the version of THIS build. updateInfoUrl must point to a small text file (HTTPS) that you publish next to your downloads:
;     version=1.0.1
;     url=https://example.com/Ragnious/Ragnious_1.2.0.ahk        (a .exe if you run the compiled app; same kind of file as the one running)
;     sha256=<64 hex characters of the new file>                  (required: a download is refused if its hash does not match)
; (GitHub works well: put version.txt in the repo and use its raw link.)  Empty = the Update button explains that it is not set up yet.
global appVersion := "1.0.1", appChannel := "Stable"
global updateInfoUrl := "https://raw.githubusercontent.com/ragnious/ragnious/refs/heads/main/version.txt?token=GHSAT0AAAAAAEMZEQP4UXZZHHYG5HOVHKW42W7XW4A"
global updateState := "idle"          ; idle | checking | available | downloading | installing
global updateInfo := "", updateReq := "", updateReqStart := 0, updateHovered := false, updateFile := ""
updateBtn := "", updateSep := ""

versionText := mainGui.Add("Text", "x24 y0 w120 h56 Background000000 cA0A0A0 +0x200 +0x100", appVersion " " appChannel)
versionText.SetFont("s12 Norm", "Segoe UI Semibold")
; Terms-of-service icon shown in the warning view (replaces the version text there). A click opens Discord's self-bot page.
global tosPageUrl := "https://discord.com/safety/platform-manipulation-policy-explainer-oct-2023"
global tosIconPressed := false, riskTosGui := "", riskTosCtl := ""
global tosHoverFrom := 0.0, tosHoverTo := 0, tosHoverStartedAt := 0, tosHoverDuration := 130   ; hover colour fade (same timing as the refresh button)
global tosRippleStart := 0, tosRippleDuration := 550                                              ; click ripple (same as the refresh button)

titleBar := mainGui.Add("Text", "x144 y0 w319 h57 Background000000 cA0A0A0 +0x200 +0x100", "")
titleBar.SetFont("", "Segoe UI")

; "version | Update": the separator and the button sit right of the version text (positions are set by InitUpdaterLayout / PositionChildWindows).
updateSep := mainGui.Add("Text", "x144 y0 w22 h56 Center Background000000 c707070 +0x200 +0x100", "|")
updateSep.SetFont("s12 Norm", "Segoe UI Semibold")
updateBtn := mainGui.Add("Text", "x166 y0 w110 h56 Center Background000000 cA0A0A0 +0x200 +0x100", "Update")
updateBtn.SetFont("s12 Norm", "Segoe UI Semibold")

minBtn := mainGui.Add("Text", "x371 y0 w58 h56 Center +0x200 +0x100 Background000000 cFFFFFF", "—")
minBtn.SetFont("s16", "Segoe UI")
minBtn.Opt("+0x000D")
minBtn.Text := ""

closeBtn := mainGui.Add("Text", "x429 y0 w58 h56 Center +0x200 +0x100 Background000000 cFFFFFF", "✕")
closeBtn.SetFont("s16", "Segoe UI")
closeBtn.Opt("+0x000D")
closeBtn.Text := ""

appName := mainGui.Add("Text", "x0 y50 w587 h74 Center +0x200 BackgroundTrans cFFFFFF", "RAGNIOUS")
appName.SetFont("s40 Bold", "Segoe UI")

taglineY := (50 + 74 - 18) + 3
appTagline := mainGui.Add("Text", Format("x0 y{} w587 h42 Center +0x200 BackgroundTrans cA0A0A0", taglineY), "Discord Quests Completer")
appTagline.SetFont("s16 Norm", "Segoe UI Semibold")

frameGui := Gui("-Caption -Border -E0x200 +0x40000000", "")
frameGui.Opt("+Parent" mainGui.Hwnd)
frameGui.BackColor := "FFFFFF"
RemoveNativeOutline(frameGui.Hwnd)

selectGui := Gui("-Caption -Border -E0x200 +0x40000000 +0x02000000", "")
selectGui.Opt("+Parent" mainGui.Hwnd)
selectGui.BackColor := "000000"
RemoveNativeOutline(selectGui.Hwnd)

processOptions := []
global gameAppIds := Map()      ; lower-case game title -> Discord application id (used for the Rich Presence fallback)
global rpcConnecting := false, rpcCancel := false   ; Discord connection in progress / cancelled by a Start-Stop press
global rpcPipe := 0, rpcLastError := ""   ; open handle of discord-ipc-N while Rich Presence mode is active
global riskFadeEndTick := 0
global statusFadeOv := "", statusFadeCtl := "", statusFadeShown := false, windowAlphaNow := 255
global riskViewActive := false, riskViewBusy := false, riskGui := "", riskBtnAccept := "", riskBtnCancel := ""   ; Rich Presence risk warning (shown inside the main window)
global riskPendingName := "", riskPendingAppId := "", riskDeferredStatus := ""
global riskPressedName := "", riskBtnAnimating := false   ; which warning button is held down / is being animated
global riskKeyHeld := false                                ; true while Enter holds the Continue button down
global riskBtnRegistry := Map()                            ; control hwnd -> warning button object (so the very first paint always finds its button)
global riskPrevDown := false, riskAnimTick := 0            ; polled left-button edge / start of the running button animation
global rpcConnectName := "", rpcConnectAppId := "", rpcConnectStart := 0   ; background Discord connection (the UI shows Active at once)
global rpcConnHandle := 0, rpcConnPhase := 0, rpcConnPhaseStart := 0, rpcConnNonce := ""   ; non-blocking connect state machine (see RpcConnectTick)
global rpcLastStopTick := 0, rpcStartUnix := 0, rpcResendHandle := 0   ; Rich Presence: settle time after a Stop, activity start time, handle the re-send belongs to
global fadeInTail := false, enterBuffered := false   ; Enter pressed while the last part of a view fade-in is still running is remembered and run when it ends
global enterPressCancelled := false                  ; Esc cancelled a held-Enter press: the still-held Enter (auto-repeat) is ignored until it is released
global riskKeyCancel := false                        ; Esc asked RiskViewTick to cancel the Continue press that Enter is holding down
global lastToggleDoneTick := 0                               ; tick of the last finished Start / Stop (presses right after it are ignored)
global toggleRunning := false, togglePending := 0, actionLocked := false   ; Start / Stop requests are queued and run one at a time
global helperLaunchId := 0, helperLaunching := false, helperLaunchStart := 0, helperCompilerPid := 0, helperThreadBusy := false   ; background build of the helper .exe (the button shows Active / Stop at once, see BeginHelperLaunch)
global riskWarnSign := "", riskWarnBlinkStep := 0, riskWarnSignPs := 10, riskWarnBmps := [], riskWarnShown := 0, riskHandCtl := "", riskHandBmp := 0   ; blinking warning sign in front of "WARNING"
; Game icons in the dropdown: a round icon in front of every title. Icons are downloaded on demand (only for rows that are actually painted),
; cut to a circle once, and cached. rowIconsEnabled false = no icons, titles start at the old position.
; ICON SOURCE: Discord's own application icons (the same detectable-games list that gives the titles also gives every game's icon hash).
global rowIconsEnabled := true, rowIconPx := 32, rowIconGap := 10, gameIconMasterPx := 32, gameIconFetchPx := 128, gameIconRadiusRatio := 0.25   ; corner radius of the icon / its size: 0.25 = exactly like Discord (8 px corners on a 32 px icon)
global gameIconHashes := Map()      ; lower-case title -> Discord icon hash (read from the detectable list)
global gameIconBitmaps := Map()     ; lower-case title -> GDI+ bitmap (rowIconPx x rowIconPx, already round, transparent corners)
global gameIconState := Map()       ; lower-case title -> 1 queued / downloading, 3 failed (no picture found anywhere: shows Discord's "?" icon)
global unknownIconMaster := 0       ; Discord's "?" icon (a die with a question mark), built once, shown for every game whose picture could not be found
global gameIconQueue := [], gameIconJobs := [], gameIconPrefetch := [], gameIconArrived := []
global gameIconDir := A_AppData "\Ragnious\icons"   ; the folder of the icon pack: it holds ONE file, icons.pack (all finished 32 x 32 icons), so the next start needs no download
; ICON PACK: ALL finished icons (32 x 32 lossless PNGs, exactly the pixels that were kept before) live in ONE file, icons\icons.pack (see the layout
; description at "---- cache ----"). An icon's version is its DISCORD ICON HASH: "the hash of the fresh list differs from the stored hash" = "the icon was updated".
global gameIconPackPath := gameIconDir "\icons.pack"
global gameIconUnknownKey := Chr(7) "unknown"   ; key of the "?" icon inside the pack (no game can have this title)
global gameIconFileNames := Map()   ; lower-case title -> Discord icon hash of the icon stored in the pack
global gameIconPackLoc := Map()     ; lower-case title -> [segment id, offset of its PNG inside the segment's data, PNG length]
global gameIconPackSegs := []       ; segment id -> segment record (position in the file, sizes, mode, crc)
global gameIconPackPend := Map()    ; title -> [kind, hash, payload]: entries not written to the file yet (kind 1 icon, 2 "no picture", 0 deleted)
global gameIconSegCache := Map(), gameIconSegOrder := []   ; the last few decompressed segments (kept in memory)
global gameIconPackDead := 0, gameIconPackNeedsRewrite := false, gameIconComp := 0, gameIconDecomp := 0
global gameIconNoIcon := Map()      ; title -> [day number, hash it was checked with]: Discord has no picture for this game (kept in the pack: a refresh does not ask again)
global gameIconNoIconDays := 1      ; ... until this many days have passed (or the fresh list brings another hash)
global gameIconMaxJobs := 32        ; parallel icon downloads (lowered automatically when Discord answers 429)
global gameIconMig := ""            ; an object while the old one-PNG-per-icon folder is being moved into the pack
global gameIconUnknownFile := ""    ; (old folder only) file name of its "?" icon
global gameIconUpdateTried := Map() ; titles whose icon was already checked since the last refresh (cleared by every refresh)
global gameIconIdxReady := false, gameIconIdxStage := 0, gameIconIdxSegs := "", gameIconIdxSegPos := 1, gameIconIdxLines := "", gameIconIdxLinePos := 1, gameIconIdxOff := 0   ; the pack's directory is read in tiny slices at start-up
global gameIconBulkList := "", gameIconBulkPos := 1, gameIconBulkStartAt := 0      ; every title of the loaded list: all icons are fetched in the background (see StartBulkIconPreload)
global gameIconBitmapCap := 20000                         ; 32 x 32 icons are ~4 KB each (10,000 icons = ~40 MB): lower this number if memory matters more than instant icons
global gameIconRetryAt := 0                                ; Discord rate limit (HTTP 429) pause
global searchIconCtl := "", searchIconHbm := 0, searchIconKey := "", searchIconReal := false, searchIconOff := 0   ; icon in the search box
global riskIconCtl := "", riskIconHbm := 0, riskIconKey := "", riskIconReal := false, riskIconPx := 0           ; icon in the warning title
global gameExecutables := Map()   ; lower-case game title -> Discord detectable Windows executable path (e.g. "riot games\valorant\live\...\valorant-win64-shipping.exe")
selectedProcessTitle := ""
gameSearchHint := "Enter a verified game title (e.g., Minecraft)"
isShowingGameSearchHint := true
selectorList := ""
selectorDisplayedOptions := []
selectorRowHeight := 37   ; title area + 1px separator line; recomputed when the dropdown is first built
selectorRowSep1 := "", selectorRowSep2 := ""
selectorHoveredIndex := -1
selectorPreviousHoveredIndex := -1
selectorHoverProgress := 1.0
selectorHoverStartedAt := 0
selectorHoverDuration := 0
selectorMouseLeaveTracking := false
selectorPressedIndex := -1
selectorClickIndex := -1
selectorCommitIndex := -1
selectorPressColorCurrent := "3A3A3A"
selectorPressColorFrom := "3A3A3A"
selectorPressColorTo := "5C5C5C"
selectorPressStartedAt := 0
selectorPressDuration := 75
selectorPressPhase := "idle"
isKeyboardNavigating := false

; Dropdown Item Marquee State
dropdownMarqueeIndex := -1
dropdownMarqueeOffset := 0.0
dropdownMarqueeLastTick := 0
dropdownMarqueePauseUntil := 0
dropdownMarqueeTitle := ""
dropdownMarqueeOverflowW := 0
dropdownMarqueeCycleW := 0
dropdownMarqueeRenderedX := 0
; Dropdown title strip: the dropdown now uses the SAME smooth sub-pixel strip engine as the status line and the popup title
; (see BuildDropdownStrip / MarqueeTick). dropdownSmooth false = old whole-pixel GDI text. dropdownSubpxYAdjust nudges the
; smooth dropdown text up/down in pixels if it sits 1 px off compared to the static (GDI) rows.
global dropdownSmooth := false, dropdownSubpxYAdjust := 0.0   ; false: the scrolling title is drawn by the same GDI code as the static rows, so its look never changes when the marquee starts (true = smoother motion, but the text turns heavier)
; VERTICAL CENTRE OF THE ICON + TEXT in the search box and in every dropdown title area.
; The icon is centred on the VISIBLE area exactly (equal gap above and below). The text is centred on the same point: the capital
; letters are an odd number of pixel rows tall (11) and the areas are an even number of rows (50 / 38), so the capitals can only sit
; half a pixel above or below the centre; the tie is resolved downwards, which gives the tallest letters (F L h i t) exactly the same
; gap above their top as below their baseline. textVCenterNudge moves ONLY the text (whole pixels): 1 = one pixel down, -1 = one up.
global textVCenterNudge := 0
; Popup (warning) title: the game icon and the title's capital letters get the SAME vertical centre. riskIconVNudge moves ONLY the icon
; (whole pixels: 1 = one pixel down, -1 = one up) if it ever looks 1 px off on your screen.
global riskIconVNudge := 0
; Popup title: gap between the game icon and the title text, in px. Its own independent value (not linked to the search box). 12 = what the search box's 9 px icon-to-text gap + 33.3 % comes to at the default size.
global riskIconTitleGap := 12
; ---- INDEPENDENT VALUES: each of these belongs to ONE element only and no other element reads it or follows it. Every number is
; exactly what the element had before (measured at the fixed 587 x 413 window), so nothing moved when they were separated. ----
global searchIconSize := 32          ; search box: game icon size (px)
global searchIconTextGap := 9        ; search box: space between the icon and the text (px)
global searchRightPad := 9           ; search box: space between the end of the text and the refresh divider (px)
global rowIconTextGap := 9           ; dropdown rows: space between the icon and the title (px)
global rowRightPad := 9              ; dropdown rows: space between the end of the title and the right edge (px)
global riskIconSize := 32            ; popup title: game icon size (px)
global riskTitleSideInset := 25      ; popup title: free space left and right of the title (px, + 1 px per 96 DPI added where it is used)
global statusRightPad := 25          ; status line: free space to the right of the moving text (px, + 1 px per 96 DPI added where it is used)
global dropdownRowHeightPx := 39     ; dropdown: height of one row incl. its 1 px line (px)
global mainSearchY := 180            ; main window: top of the search box (px)
global mainActionY := 273            ; main window: top of the Start / Stop button (px)
global mainStatusY := 358            ; main window: top of the status line (px; it used to be computed from the window height: 413 - 42 - 10 - 2.1, rounded down)
global dropdownGapBelowSearch := 0   ; dropdown: space between the bottom of the search box and the top of the list (px)
global riskTitleVNudge := 0          ; popup: moves ONLY the title text up / down (whole px: 1 = one down, -1 = one up); the icon, ID and the rest stay
global riskBtnAcceptX := 131         ; popup: left edge of Continue (px, window coordinates). Fixed: it no longer follows the description's text width. "" = old automatic layout
global riskBtnCancelX := 318         ; popup: left edge of Cancel (px, window coordinates). Fixed. "" = old automatic layout
; ---- ONE VALUE PER ELEMENT (main window + popup). Each number below belongs to ONE element only; nothing else reads it or follows it.
; Defaults are exactly what every element had before (measured at the fixed 587 x 413 window), so nothing moved when they were separated.
; The only groups that still move together on purpose: app name + tagline, app name + the popup's white line, the whole marquee engine.
global verTextX := 24, verTextY := 0, verTextW := 120, verTextH := 56               ; version text
global titleBarX := 144, titleBarY := 0, titleBarW := 327, titleBarH := 57          ; drag bar
global minBtnX := 471, minBtnY := 0, minBtnW := 58, minBtnH := 56                   ; minimize button
global closeBtnX := 529, closeBtnY := 0, closeBtnW := 58, closeBtnH := 56           ; close button
global updSepX := 0, updSepW := 22, updBtnX := 0, updBtnW := 110                    ; updater: "|" separator and Update button (set by InitUpdaterLayout)
InitUpdaterLayout()
global appNameX := 0, appNameY := 50, appNameW := 587, appNameH := 74               ; app name (the tagline and the popup line follow it)
global appTaglineH := 42                                                            ; tagline height
global searchFrameX := 61, searchFrameW := 464, searchFrameH := 53                  ; search box white frame (its Y is mainSearchY)
global searchInnerX := 62, searchInnerY := 181, searchInnerW := 462, searchInnerH := 51   ; search box black inside
global searchEditX := 1, searchEditW := 398                                         ; the edit field inside the search box
global searchTextLeftInset := 9                                                     ; search box: space before the text
global searchIconX := 10                                                            ; search box: left edge of the game icon
global refreshSepX := 409, refreshSepY := 1, refreshSepW := 1, refreshSepH := 49    ; divider before the refresh button
global refreshBtnX := 410, refreshBtnY := 1, refreshBtnW := 51, refreshBtnH := 49   ; refresh button
global actionBtnPosX := 188, actionBtnPosW := 210, actionBtnPosH := 60              ; Start / Stop button (its Y is mainActionY)
global statusDotX := 25                                                             ; status dot: left edge
global statusTextX := 27                                                            ; status text: start (the width of the dot glyph + space is added, it is font metrics)
global riskBtnW := 137, riskBtnH := 39, riskBtnFontSize := 14.3                     ; popup Continue / Cancel size (no longer follow the Start button)
global rowLeftInset := 9                                                           ; dropdown rows: space before the icon / title
global riskContentTopY := 131                                                          ; popup: top of the content area (no longer follows the white line)
; Popup (warning) vertical margins, measured between the VISIBLE parts (ink / icon edge / button edge), each one its own value (px). Nothing is
; derived from the window height or from another margin any more; the defaults are exactly what was on screen before. Chain from the top:
;   white line -> icon / title -> ID -> description -> warning -> buttons. The space left under the buttons is the only leftover (the window
;   has a fixed height, so one margin has to take what the others do not use): with these defaults it is 25 px, the same as before.
global riskGapLineToTitle := 20      ; popup: white line -> top of the icon / title
global riskGapTitleToId := 5         ; popup: bottom of the icon / title -> top of the ID
global riskGapIdToDesc := 13         ; popup: ID -> description
global riskGapDescToWarn := 13       ; popup: description -> warning
global riskGapWarnToButtons := 14    ; popup: warning -> Continue / Cancel buttons
; Popup icon size = EXACTLY the search box's icon size (RowIconSize). true = if the icon and the title's capital letters have a different
; parity (even / odd number of pixel rows) the icon is made 1 px smaller / bigger so that the two centres are the same pixel position.
global riskIconMatchCenterParity := false
global dropdownStripDc := 0, dropdownStripBmp := 0, dropdownStripOld := 0, dropdownStripH := 0, dropdownStripDirty := true
global dropdownStripPhases := 1, dropdownRenderedPhase := 0, dropdownStripText := "", dropdownMarqueeTextW := 0

; Custom Scrollbar State Variables
selectorScrollUpBtn := ""
selectorScrollDownBtn := ""
selectorScrollThumb := ""
selectorScrollThumbTrack := ""
selectorScrollSeparator := ""
selectorScrollHoverTarget := ""
; Anti-flicker state for the dropdown list
global selectorListFrozen := false          ; true while ScrollListLines changes selection/scroll/hover together (no painting then)
global wheelPendingLines := 0               ; mouse-wheel notches collected until one scroll+repaint is done for all of them
global rowBufDc := 0, rowBufBmp := 0, rowBufOld := 0, rowBufW := 0, rowBufH := 0   ; row back-buffer, created once and reused
global rowTextCache := Map()                ; title -> [textWidth, bearingA, bearingC] (measured once, not on every paint)
scrollBarWidth := 18
scrollButtonHeight := 20
isDraggingThumb := false
thumbDragStartY := 0
thumbDragStartThumbY := 0
thumbDragTrackTopY := 0
thumbDragTrackTravel := 0
scrollAnimationCurrentPos := 0.0
scrollAnimationTargetPos := 0.0
scrollAnimationActive := false
scrollContinuousAction := ""
scrollContinuousNextTick := 0
; Icon click animation (shared by minimize, close, refresh and the scroll buttons)
iconAnimState := Map()
refreshKickStart := 0
refreshKickDuration := 550
iconPressScale := 0.78
iconPressDuration := 90
iconReleaseDuration := 170
minBtnBg := "000000"
closeBtnBg := "000000"

isFilteringGameList := false
isSelectingGame := false
refreshButtonBgCurrent := "000000"
refreshButtonBgFrom := "000000"
refreshButtonBgTo := "000000"
refreshButtonAnimationStartedAt := 0
refreshButtonAnimationDuration := 130
refreshArrowAngle := 0.0
refreshArrowAnimating := false
refreshArrowStartedAt := 0
refreshArrowDuration := 2600
refreshIsLocked := false
refreshShowCheck := false
gameFetchPending := false
gameFetchStartedAt := 0
asyncXhr := ""
lastGameRefreshAt := 0

processSelect := selectGui.Add("Edit", "x0 y0 w382 h49 -Theme -Border -E0x200 -Multi -VScroll -HScroll cFFFFFF Background000000", gameSearchHint)
processSelect.SetFont("s12 cFFFFFF", "Segoe UI")
searchEditBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00000000, "Ptr")
scrollHoverBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00303030, "Ptr")
refreshLockedBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00555555, "Ptr")
refreshBgBrushes := Map()
processSelect.OnEvent("Focus", OnGameSearchFocus)
processSelect.OnEvent("LoseFocus", OnGameSearchLoseFocus)
processSelect.OnEvent("Change", OnGameSearchChange)
RemoveNativeOutline(processSelect.Hwnd)
processSelect.Opt("+0x04000000")      ; WS_CLIPSIBLINGS: the edit never paints over the game icon that sits in front of its text
; Game icon in front of the text (shown only while the text is a valid game title). A bitmap static control above the edit; it is
; click-through (no SS_NOTIFY), so a click on it reaches the edit below like before.
searchIconCtl := selectGui.Add("Text", "x0 y0 w1 h1 +0xE +0x04000000 Hidden", "")
DllCall("User32\SetWindowPos", "Ptr", searchIconCtl.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")   ; on top of the edit

refreshSeparator := selectGui.Add("Text", "x407 y1 w1 h47 BackgroundFFFFFF", "")
refreshButton := selectGui.Add("Text", "x408 y0 w52 h49 Center +0x200 +0x100 -Theme -Border cFFFFFF", "↻")
refreshButton.SetFont("s18", "Segoe UI")
refreshButton.Opt("+0x000D")
refreshButton.Text := ""
RemoveNativeOutline(refreshButton.Hwnd)

actionGui := Gui("-Caption +0x40000000", "")
actionGui.Opt("+Parent" mainGui.Hwnd)
actionGui.BackColor := "000000"      ; fixed: the button paints its own colour; the corners / shrunk-press margin are the window's black

actionBtn := actionGui.Add("Text", "x0 y0 w210 h60 -Theme +0x100", "Start")
actionBtn.SetFont("s" actionBtnBaseFontSize " Bold", "Segoe UI")
actionBtn.Opt("+0x000D")

statusDot := mainGui.Add("Text", "x0 y0 w16 h42 +0x200 BackgroundTrans c208A4E", "●")
statusDot.SetFont("s12 Norm", "Segoe UI Semibold")
statusDot.Opt("+0x000D")      ; owner-drawn (DrawStatusDot): its 80 ms colour blink no longer re-prints the whole composited window

statusText := mainGui.Add("Text", "x0 y0 w453 h42 +0x200 BackgroundTrans c208A4E", "System is ready; awaiting input...")
statusText.SetFont("s12 Norm", "Segoe UI Semibold")

statusMarqueeGui := Gui("-Caption -Border -E0x200 +0x40000000", "")
statusMarqueeGui.Opt("+Parent" mainGui.Hwnd)
statusMarqueeGui.BackColor := "000000"
RemoveNativeOutline(statusMarqueeGui.Hwnd)

statusMarqueeText := statusMarqueeGui.Add("Text", "x0 y0 w468 h42 +0x000D", "")
statusMarqueeText.SetFont("s12 Norm", "Segoe UI Semibold")

#HotIf IsMyGuiActive()
Enter:: {
    if (IsProcessSelectorOpen() && IsWindowValid(selectorList)) {
        if (IsDropdownPressHeld())
            return
        global selectorHoveredIndex, selectorDisplayedOptions
        hoveredIdx := GetActiveHoverIndex()
        if (hoveredIdx < 0 && selectorHoveredIndex >= 0 && selectorHoveredIndex < selectorDisplayedOptions.Length)
            hoveredIdx := selectorHoveredIndex
            
        if (hoveredIdx >= 0 && hoveredIdx < selectorDisplayedOptions.Length) {
            global selectorClickIndex
            selectorClickIndex := hoveredIdx
            BeginDropdownItemPress()
            return
        }
    }
    TriggerActionDown()
}
Enter Up:: {
    global enterPressCancelled
    if (!GetKeyState("Enter", "P") && !GetKeyState("NumpadEnter", "P"))
        enterPressCancelled := false           ; the cancelled press is over: the NEXT Enter press must work again
    if (IsProcessSelectorOpen() && IsWindowValid(selectorList)) {
        global selectorClickIndex, selectorCommitIndex
        if (selectorClickIndex >= 0 && selectorClickIndex < selectorDisplayedOptions.Length) {
            pressedIndex := selectorClickIndex
            selectorClickIndex := -1
            EndDropdownItemPress()
            selectorCommitIndex := pressedIndex
            SetTimer(CommitDropdownSelection, -50)
            return
        }
    }
    TriggerActionUp()
}
NumpadEnter:: {
    if (IsProcessSelectorOpen() && IsWindowValid(selectorList)) {
        if (IsDropdownPressHeld())
            return
        global selectorHoveredIndex, selectorDisplayedOptions
        hoveredIdx := GetActiveHoverIndex()
        if (hoveredIdx < 0 && selectorHoveredIndex >= 0 && selectorHoveredIndex < selectorDisplayedOptions.Length)
            hoveredIdx := selectorHoveredIndex
            
        if (hoveredIdx >= 0 && hoveredIdx < selectorDisplayedOptions.Length) {
            global selectorClickIndex
            selectorClickIndex := hoveredIdx
            BeginDropdownItemPress()
            return
        }
    }
    TriggerActionDown()
}
NumpadEnter Up:: {
    global enterPressCancelled
    if (!GetKeyState("Enter", "P") && !GetKeyState("NumpadEnter", "P"))
        enterPressCancelled := false           ; the cancelled press is over: the NEXT Enter press must work again
    if (IsProcessSelectorOpen() && IsWindowValid(selectorList)) {
        global selectorClickIndex, selectorCommitIndex
        if (selectorClickIndex >= 0 && selectorClickIndex < selectorDisplayedOptions.Length) {
            pressedIndex := selectorClickIndex
            selectorClickIndex := -1
            EndDropdownItemPress()
            selectorCommitIndex := pressedIndex
            SetTimer(CommitDropdownSelection, -50)
            return
        }
    }
    TriggerActionUp()
}
+Enter::return
+NumpadEnter::return
!F4::CloseApplication()
#HotIf

; Esc pressed while a button press is still HELD (Enter on Start / Stop or the warning's Continue, or the left mouse
; button on any button) cancels that press: the button springs back and nothing runs, as if it had never been pressed.
; This variant must stay ABOVE the other Escape hotkeys (when several variants are eligible the first one in the script
; wins); it is only eligible while such a press is actually held, so Escape behaves as before in every other situation.
#HotIf IsPressCancellable()
Escape:: {
    global pressedControl, riskPressedName, riskKeyHeld, riskKeyCancel, enterBuffered, enterPressCancelled, isKeyActionDown
    ; --- mouse press (left button still down) ---
    if (GetKeyState("LButton", "P")) {
        if (pressedControl != "")
            CancelMousePress()
        else if (riskViewActive && riskPressedName != "" && !riskKeyHeld)
            riskKeyCancel := true              ; RiskViewTick releases the held warning button (after its press animation ended)
    }
    ; --- Enter press (key still down) ---
    if ((GetKeyState("Enter", "P") || GetKeyState("NumpadEnter", "P")) && (isKeyActionDown || enterBuffered || riskKeyHeld)) {
        enterPressCancelled := true            ; auto-repeat of the still-held Enter must not press the button again
        enterBuffered := false                 ; Enter pressed during the end of a fade-in and not run yet: just forget it
        if (riskViewActive) {
            if (riskKeyHeld)
                riskKeyCancel := true
        } else
            CancelActionPress()
    }
}
#HotIf

IsPressCancellable() {
    global isKeyActionDown, enterBuffered, riskKeyHeld, pressedControl, riskPressedName
    held := false
    if ((isKeyActionDown || enterBuffered || riskKeyHeld) && (GetKeyState("Enter", "P") || GetKeyState("NumpadEnter", "P")))
        held := true                           ; an Enter press is held
    else if ((pressedControl != "" || (riskViewActive && riskPressedName != "")) && GetKeyState("LButton", "P"))
        held := true                           ; a mouse press is held
    return held && IsMyGuiActive()             ; (released already = the click is complete, nothing left to cancel)
}

#HotIf (IsProcessSelectorOpen() || IsGameSearchControlFocused()) && !IsContextMenuOpen()
Escape:: {
    CloseProcessSelector()
    isGameSearchFocused := false
    if (IsWindowValid(mainGui))
        DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
}
#HotIf

#HotIf IsProcessSelectorOpen() && IsMyGuiActive()
~LButton:: {
    BeginDropdownClick()
}
~LButton Up:: {
    FinishDropdownClick()
}
Up:: {
    ScrollListLines(-1)
}
Down:: {
    ScrollListLines(1)
}
WheelUp:: {
    QueueWheelScroll(-1)
}
WheelDown:: {
    QueueWheelScroll(1)
}
#HotIf

; The wheel hotkey used to scroll + repaint inside the hotkey thread. Fast spinning then dropped notches (a hotkey that
; is still running ignores new presses) and repainted once per notch, which looked like stutter. Now the hotkey only
; counts the notch and returns at once; ONE timer thread scrolls by the whole sum and repaints the list once.
QueueWheelScroll(dir) {
    global wheelPendingLines
    wheelPendingLines += dir
    SetTimer(FlushWheelScroll, -1)
}

FlushWheelScroll(*) {
    global wheelPendingLines
    lines := wheelPendingLines
    wheelPendingLines := 0
    if (lines != 0)
        ScrollListLines(lines)
}

; Keyboard mode (arrows / wheel / scroll buttons) ignores the mouse position.
; It ends as soon as the mouse physically moves, so hover goes back to the mouse.
RefreshKeyboardNavMode() {
    global isKeyboardNavigating, keyNavMouseX, keyNavMouseY, selectorHoveredIndex, selectorDisplayedOptions
    if (!isKeyboardNavigating)
        return false
    if (selectorHoveredIndex < 0 || selectorHoveredIndex >= selectorDisplayedOptions.Length) {
        isKeyboardNavigating := false
        return false
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    if (Abs(mx - keyNavMouseX) > 3 || Abs(my - keyNavMouseY) > 3)
        isKeyboardNavigating := false
    return isKeyboardNavigating
}

; The row that counts as "hovered": the keyboard row in keyboard mode, otherwise the mouse row.
GetActiveHoverIndex() {
    global selectorHoveredIndex
    if (RefreshKeyboardNavMode())
        return selectorHoveredIndex
    return GetDropdownItemAtMouse()
}

SetActionColor(color, paint := true) {
    global actionGui, actionBtnColor
    if (actionBtnColor = color)
        return
    actionBtnColor := color
    ; NOTE: actionGui.BackColor is NOT changed any more. Assigning BackColor runs InvalidateRect(erase = true) on a child of the
    ; layered + composited main window, which made Windows re-print the whole window tree (status line included) on every
    ; hover / press colour change. The button is fully owner-drawn, so its colour is painted directly (see below).
    if (paint)
        RepaintActionButtonNoErase()      ; paint := false when AnimateActionButton follows: its first step paints the new colour anyway
}

SetActionLabel(text) {
    global actionBtnLabel
    actionBtnLabel := text                ; repainted together with the colour change that follows
}

RepaintActionButtonNoErase() {
    global actionBtn
    ; Direct paint: only the button's own pixels are touched, nothing is invalidated (no window-tree re-print).
    if (PaintControlDirect(actionBtn, DrawActionButton))
        return
    if (IsWindowValid(actionBtn)) {
        DllCall("User32\InvalidateRect", "Ptr", actionBtn.Hwnd, "Ptr", 0, "Int", false)
        DllCall("User32\UpdateWindow", "Ptr", actionBtn.Hwnd)
    }
}

; Start/Stop button: the whole button (fill + label) is rendered off-screen and
; copied in one BitBlt, so no number of repaints can show an erased/half-drawn state.
DrawActionButton(drawItemStruct) {
    global actionBtnColor, actionBtnLabel, actionBtnFontSize, actionBtnScale
    return DrawPillButton(drawItemStruct, actionBtnColor, actionBtnLabel, actionBtnFontSize, actionBtnScale, 24)
}

DrawPillButton(drawItemStruct, btnColor, btnLabel, btnFontSize, scale := 1.0, cornerSize := 24) {
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    targetHdc := NumGet(drawItemStruct, itemHwndOffset + A_PtrSize, "Ptr")
    rectOffset := itemHwndOffset + A_PtrSize * 2
    left := NumGet(drawItemStruct, rectOffset, "Int")
    top := NumGet(drawItemStruct, rectOffset + 4, "Int")
    width := NumGet(drawItemStruct, rectOffset + 8, "Int") - left
    height := NumGet(drawItemStruct, rectOffset + 12, "Int") - top
    if (width <= 0 || height <= 0 || !targetHdc)
        return 1

    memoryDc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", targetHdc, "Ptr")
    if (!memoryDc)
        return 1
    bitmap := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", targetHdc, "Int", width, "Int", height, "Ptr")
    if (!bitmap) {
        DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
        return 1
    }
    oldBitmap := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", bitmap, "Ptr")

    localRect := Buffer(16, 0)
    NumPut("Int", width, localRect, 8)
    NumPut("Int", height, localRect, 12)
    ; SCALED MODE (press animation of the Start / Stop button): the WINDOW never moves or resizes (that made Windows re-print the
    ; whole composited window tree, status line included, on every animation step). Instead the shrunken pill is drawn INSIDE the
    ; full-size window: black around it (= the window background), the pill as a rounded region exactly like the old window region.
    px0 := 0, py0 := 0, pw := width, ph := height
    if (scale < 0.999) {
        pw := Max(1, Round(width * scale)), ph := Max(1, Round(height * scale))
        px0 := (width - pw) // 2, py0 := (height - ph) // 2
        blackBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00000000, "Ptr")
        DllCall("User32\FillRect", "Ptr", memoryDc, "Ptr", localRect, "Ptr", blackBrush)
        DllCall("Gdi32\DeleteObject", "Ptr", blackBrush)
        cs := Round(cornerSize * scale)
        pillRgn := DllCall("Gdi32\CreateRoundRectRgn", "Int", px0, "Int", py0, "Int", px0 + pw, "Int", py0 + ph, "Int", cs, "Int", cs, "Ptr")
        brush := DllCall("Gdi32\CreateSolidBrush", "UInt", HexToColorRef(btnColor), "Ptr")
        DllCall("Gdi32\FillRgn", "Ptr", memoryDc, "Ptr", pillRgn, "Ptr", brush)
        DllCall("Gdi32\DeleteObject", "Ptr", brush)
        DllCall("Gdi32\DeleteObject", "Ptr", pillRgn)
    } else {
        brush := DllCall("Gdi32\CreateSolidBrush", "UInt", HexToColorRef(btnColor), "Ptr")
        DllCall("User32\FillRect", "Ptr", memoryDc, "Ptr", localRect, "Ptr", brush)
        DllCall("Gdi32\DeleteObject", "Ptr", brush)
    }

    DllCall("Gdi32\SetBkMode", "Ptr", memoryDc, "Int", 1)
    DllCall("Gdi32\SetTextColor", "Ptr", memoryDc, "UInt", 0x00FFFFFF)
    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(btnFontSize * DllCall("Gdi32\GetDeviceCaps", "Ptr", targetHdc, "Int", 90) / 72), "Int", 0, "Int", 0, "Int", 0, "Int", 700, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", "Segoe UI", "Ptr")
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", hFont, "Ptr")
    ; Centre the letters (middle of the capitals), not the font's line box, on the middle of the visible button
    ; (the rounded-corner region drops the last row, so the visible height is height - 1).
    GetFontCenterMetrics(memoryDc, &labelLineH, &labelCapCenter)
    labelTop := py0 + Ceil((ph - 1) / 2 - labelCapCenter - 0.5)
    labelRect := Buffer(16, 0)
    NumPut("Int", px0, labelRect, 0)
    NumPut("Int", labelTop, labelRect, 4)
    NumPut("Int", px0 + pw, labelRect, 8)
    NumPut("Int", labelTop + labelLineH + 2, labelRect, 12)
    DllCall("User32\DrawTextW", "Ptr", memoryDc, "Str", btnLabel, "Int", -1, "Ptr", labelRect, "UInt", 0x00000021)   ; DT_CENTER | DT_SINGLELINE
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)

    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBitmap, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", bitmap)
    DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
    return 1
}

IsMouseOverScrollArrowButton() {
    global selectorScrollUpBtn, selectorScrollDownBtn, selectorDisplayedOptions
    if (!IsProcessSelectorOpen() || selectorDisplayedOptions.Length <= 3)
        return false
    MouseGetPos(,,, &hoveredCtl, 2)
    return (IsWindowValid(selectorScrollUpBtn) && hoveredCtl = selectorScrollUpBtn.Hwnd)
        || (IsWindowValid(selectorScrollDownBtn) && hoveredCtl = selectorScrollDownBtn.Hwnd)
}

; Clicking the scroll-up / scroll-down buttons must not take focus from the search box.
OnMouseActivate(wParam, lParam, msg, hwnd) {
    global isExiting, isGameSearchFocused
    if (isExiting || !isGameSearchFocused)
        return
    if (IsMouseOverScrollArrowButton() || IsMouseOverDropdownArea())
        return 3                              ; MA_NOACTIVATE
}

IsContextMenuOpen() {
    global isSearchMenuOpen
    return (isSearchMenuOpen || WinExist("ahk_class #32768")) ? true : false
}

IsDropdownPressHeld() {
    global selectorClickIndex, selectorPressPhase
    return (selectorClickIndex >= 0 && (selectorPressPhase = "press" || selectorPressPhase = "held"))
}

; True when the window belongs to this app's own GUIs (main window or dropdown).
; Foreign windows of this process (e.g. the Windows right-click menu) are ignored.
IsOwnGuiWindow(hwnd) {
    global mainGui, selectorFrameGui
    if (!hwnd || !IsSet(mainGui) || !mainGui)
        return false
    root := DllCall("User32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    if (!root)
        root := hwnd
    if (root = mainGui.Hwnd)
        return true
    return IsWindowValid(selectorFrameGui) && root = selectorFrameGui.Hwnd
}

IsForegroundOurProcess() {
    fg := DllCall("User32\GetForegroundWindow", "Ptr")
    if (!fg)
        return false
    pid := 0
    DllCall("User32\GetWindowThreadProcessId", "Ptr", fg, "UInt*", &pid, "UInt")
    return pid = DllCall("Kernel32\GetCurrentProcessId", "UInt")
}

IsMouseOverDropdownArea() {
    global selectorFrameGui
    if (!IsProcessSelectorOpen())
        return false
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    rect := Buffer(16, 0)
    if (!DllCall("User32\GetWindowRect", "Ptr", selectorFrameGui.Hwnd, "Ptr", rect, "Int"))
        return false
    return mx >= NumGet(rect, 0, "Int") && mx < NumGet(rect, 8, "Int")
        && my >= NumGet(rect, 4, "Int") && my < NumGet(rect, 12, "Int")
}

; Returns the exact (case-sensitive) dropdown title typed in the search box, or "".
ResolveTypedGameTitle() {
    global processSelect, processOptions, isShowingGameSearchHint
    if (!IsWindowValid(processSelect) || isShowingGameSearchHint)
        return ""
    typed := Trim(processSelect.Value)
    if (typed = "")
        return ""
    for title in processOptions {
        if (StrCompare(title, typed, true) = 0)
            return title
    }
    return ""
}

IsWindowValid(ctrl) {
    try {
        return IsObject(ctrl) && ctrl.Hwnd && DllCall("User32\IsWindow", "Ptr", ctrl.Hwnd, "Int")
    } catch {
        return false
    }
}

; Safety net for "stuck" buttons: a mouse-up can be lost (released outside the window, or while the press animation
; was still running and the message handler was busy). The physical button state is the truth, so whenever a control
; is still marked as pressed but the button is no longer down, the release is processed here.
ReleaseWatchdog() {
    global pressedControl, isKeyActionDown, isExiting, mainGui, enterPressCancelled
    if (isExiting || !IsSet(mainGui) || !mainGui)
        return
    if (enterPressCancelled && !GetKeyState("Enter", "P") && !GetKeyState("NumpadEnter", "P"))
        enterPressCancelled := false           ; safety net: the key-up of a cancelled press was missed (window lost focus, ...)
    if (pressedControl != "" && !GetKeyState("LButton", "P")) {
        try HandleLeftButtonUp(0, 0, 0x0202, mainGui.Hwnd)
        pressedControl := ""
    }
    if (isKeyActionDown && !GetKeyState("Enter", "P") && !GetKeyState("NumpadEnter", "P"))
        TriggerActionUp()
}

TriggerActionDown() {
    global actionGui, actionBtn, isRunning, isKeyActionDown, actionLocked, rpcConnecting, rpcConnectStart, fadeInTail, enterBuffered, riskViewBusy, enterPressCancelled
    global helperLaunching, helperLaunchStart
    if (connLost)
        return                                 ; connection lost: Start / Continue are frozen
    if (enterPressCancelled) {
        if (GetKeyState("Enter", "P") || GetKeyState("NumpadEnter", "P"))
            return                             ; Esc cancelled this press: ignore the still-held key (auto-repeat) until it is released
        enterPressCancelled := false
    }
    if (fadeInTail && riskViewBusy) {
        enterBuffered := true                  ; the window already looks ready (cubic ease: ~100 ms of nearly invisible fade left): keep the press
        return
    }
    if (riskViewActive) {
        RiskKeyDown()                          ; Enter in the warning = press "Continue" (same motion as Start)
        return
    }
    if (isKeyActionDown && !GetKeyState("Enter", "P") && !GetKeyState("NumpadEnter", "P"))
        isKeyActionDown := false               ; stale flag (its key-up was swallowed while the warning was fading): never block a new press
    if (isKeyActionDown || actionLocked || (rpcConnecting && A_TickCount - rpcConnectStart < 700) || (helperLaunching && A_TickCount - helperLaunchStart < 700))
        return                                 ; while Discord is being connected a press does nothing (it used to cancel the start)
    isKeyActionDown := true
    SetActionColor(isRunning ? "9A1E15" : "186B3C", false)      ; repaints by itself; the animation's first pass paints again
    AnimateActionButton(true)
}

TriggerActionUp() {
    global actionGui, actionBtn, isRunning, isKeyActionDown
    if (riskViewActive)
        return                                 ; the warning's Continue is released by RiskViewTick (polls the key state)
    if (!isKeyActionDown)
        return
    isKeyActionDown := false
    SetActionColor(isRunning ? "D12F26" : "279B5A", false)
    AnimateActionButton(false, QueueToggle)
}

; Esc while Enter holds the Start / Stop button down: same result as releasing the mouse button OUTSIDE the button -
; the button springs back (no callback, so no Start / Stop is queued) and the colour returns to what the mouse position
; says (hover colour if the cursor is over the button, normal colour otherwise).
CancelActionPress() {
    global actionGui, actionBtn, isRunning, isKeyActionDown, lastHover
    if (!isKeyActionDown)
        return
    isKeyActionDown := false
    MouseGetPos(,,, &hoveredControl, 2)
    over := (hoveredControl = actionGui.Hwnd || hoveredControl = actionBtn.Hwnd)
    SetActionColor(isRunning ? (over ? "D12F26" : "B42318") : (over ? "279B5A" : "208A4E"), false)
    lastHover := -1                            ; the hover logic re-checks the colour once the spring-back is finished
    AnimateActionButton(false)
}

; Esc while the LEFT MOUSE BUTTON holds a button down: the same result as releasing the mouse outside the button. Every
; "pressed" state is cleared right here (pressedControl first), so the later real mouse-up finds nothing to do and the
; button can never stay stuck. The hover logic then repaints the button for the current mouse position.
CancelMousePress() {
    global pressedControl, lastHover, iconAnimState
    target := pressedControl
    if (target = "")
        return
    pressedControl := ""
    if (target = "tos") {
        TosIconUp(0)                           ; 0 = "released elsewhere": no page is opened
    } else if (target = "min" || target = "close") {
        if (iconAnimState.Has(target))
            ReleaseIcon(target)                ; icon springs back (otherwise it waits for the physical mouse-up)
    } else if (target = "action") {
        AnimateActionButton(false)             ; no callback: no Start / Stop
    }
    lastHover := -1                            ; force the hover logic to repaint colours (min / close / refresh / Start)
    UpdateButtonHover()
}

; Start / Stop requests are never run inside the button animation (a new press cancels the running animation, which used
; to throw the click away) and never two at a time (a second run used to overlap the first one: "Failed to process setup").
; Every press is remembered here and the requests are executed one after the other.
QueueToggle(*) {
    global togglePending, actionLocked, isExiting, toggleRunning, rpcConnecting, rpcConnectStart, riskViewActive, riskViewBusy, lastToggleDoneTick
    global helperLaunching, helperLaunchStart
    if (isExiting || actionLocked || connLost)
        return
    ; Pressing Start many times must never turn into Start-Stop-Start or cancel a start that is still running:
    ; a press is only accepted when nothing is being started / stopped / connected and the warning is not involved,
    ; and not in the first moments after the previous Start / Stop finished (mashed Enter would stop it again at once).
    if (toggleRunning || (rpcConnecting && A_TickCount - rpcConnectStart < 700) || (helperLaunching && A_TickCount - helperLaunchStart < 700) || riskViewActive || riskViewBusy || togglePending > 0)
        return
    if (A_TickCount - lastToggleDoneTick < 250)
        return                                 ; only a real double-click / key repeat is swallowed (it was 500 ms: a normal re-click was lost)
    togglePending := 1
    SetTimer(ProcessToggleQueue, -1)
}

ProcessToggleQueue() {
    global toggleRunning, togglePending, actionLocked, isExiting, riskViewActive, riskViewBusy, lastToggleDoneTick
    if (toggleRunning)
        return
    toggleRunning := true
    try {
        while (togglePending > 0 && !isExiting) {
            togglePending -= 1
            try {
                ToggleAction()
            } catch Error as err {
                SetStatus("System Error: " err.Message, "error")
            }
            if (riskViewActive || riskViewBusy || actionLocked) {
                togglePending := 0           ; the warning took over: further presses belong to the warning
                break
            }
        }
    } finally {
        toggleRunning := false
        togglePending := 0
        lastToggleDoneTick := A_TickCount
    }
}

A_TrayMenu.Delete()
A_TrayMenu.Add("Show", RestoreWindow)
A_TrayMenu.Add("Hide", HideWindowFromTray)
A_TrayMenu.Add("Exit", CloseApplication)
A_TrayMenu.Default := "Show"
A_TrayMenu.ClickCount := 2

animationActive := false, animationShowing := false, animationStart := 0, animationDuration := 450, isWindowVisible := false, lastHover := 0

SetTimer(UpdateButtonHover, 25)
SetTimer(ReleaseWatchdog, 20)
SetTimer(PollDropdownHover, 15)
SetTimer(MarqueeMaster, 8)

marqueeIndex := 1, marqueeTimerRunning := false, currentStatusRaw := "", currentStatusColor := "208A4E"
marqueeBaseX := 0, marqueeBaseY := 0, marqueeCycleWidth := 0, marqueeTrackWidth := 0
marqueeOffset := 0.0, marqueeLastTick := 0, marqueePauseUntil := 0
dotBlinkStep := 0, dotBlinkTimerRunning := false, currentStatusTextOnly := "", isMarqueeActive := false

SetWindowOpacity(0)
mainGui.Show("NA w587 h413")
PositionChildWindows()
ApplyAllCorners()
AnimateVisibility(true)
SetStatus("System is ready; awaiting input...", "ready")
SetTimer(ConnectionWatchTick, 1500)      ; watches the internet connection for as long as the app runs

OnMessage(0x0083, OnNcCalcSize)
OnMessage(0x0006, OnActivateWindow)
OnMessage(0x0010, OnWmClose)
OnMessage(0x0112, OnSysCommand)
OnMessage(0x0231, OnEnterSizeMove)
OnMessage(0x0232, OnExitSizeMove)
OnMessage(0x002B, DrawSelectorItem)
OnMessage(0x002C, MeasureSelectorItem)
OnMessage(0x0200, TrackSelectorMouseMove)
OnMessage(0x02A3, SelectorMouseLeave)
OnMessage(0x0020, OnSetCursor)
OnMessage(0x0133, WmCtlColorEdit)
OnMessage(0x0134, WmCtlColorListBox)
OnMessage(0x0138, WmCtlColorStatic)
OnMessage(0x0003, MainGuiMoved)
OnMessage(0x0005, OnWmSize)
OnMessage(0x0201, HandleLeftButtonDown)
OnMessage(0x0202, HandleLeftButtonUp)
OnMessage(0x0203, OnSearchBoxDoubleClick)
OnMessage(0x0100, OnWmKeyDown)
OnMessage(0x0021, OnMouseActivate)
OnMessage(0x0204, HandleRightButtonDown)
OnMessage(0x0205, HandleRightButtonUp)
OnMessage(0x007B, HandleContextMenuMsg)
OnMessage(0x0014, OnEraseBackground)
OnMessage(0x0084, RefreshOverlayHitTest)
SetTimer(PrewarmDropdown, -900)          ; build the hidden dropdown once, while the app is idle after start-up
GameIconNetworkTune()                    ; more parallel connections to Discord's servers (icons arrive several times faster)
OnExit(GameIconPackOnExit)               ; icons collected in memory are written to icons.pack when the app closes
SetTimer(GameIconIndexTick, -300)        ; read the icon pack's directory in tiny slices while the app is idle (see GameIconIndexStep)
refreshButton.Redraw()
minBtn.Redraw()
closeBtn.Redraw()
; The Start/Stop button is owner-drawn too. It was first painted (blank) before the WM_DRAWITEM handler above existed,
; so repaint it now that the handler is registered; otherwise the label only appears at the next incidental repaint.
RepaintActionButtonNoErase()

; Right button: dropdown keeps the focus, search box opens the Windows menu, anywhere else blurs the search box.
HandleRightButtonDown(wParam, lParam, msg, hwnd) {
    global mainGui, processSelect, selectorFrameGui, isGameSearchFocused, isExiting, isSearchMenuOpen, searchMenuSwallowRightUp
    if (isExiting || !IsSet(mainGui) || !mainGui || !IsOwnGuiWindow(hwnd))
        return
    if (isSearchMenuOpen) {
        CloseSearchMenu(false)
        searchMenuSwallowRightUp := true   ; the matching button-up must not open a new menu
        return 0
    }
    root := DllCall("User32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    if (IsWindowValid(selectorFrameGui) && root = selectorFrameGui.Hwnd)
        return 0
    if (IsWindowValid(processSelect) && hwnd = processSelect.Hwnd) {
        if (DllCall("User32\GetFocus", "Ptr") != processSelect.Hwnd)
            DllCall("User32\SetFocus", "Ptr", processSelect.Hwnd)
        return
    }
    if (isGameSearchFocused || (IsWindowValid(processSelect) && DllCall("User32\GetFocus", "Ptr") = processSelect.Hwnd)) {
        isGameSearchFocused := false
        DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
    }
    if (IsProcessSelectorOpen())
        CloseProcessSelector()
}

HandleRightButtonUp(wParam, lParam, msg, hwnd) {
    global selectorFrameGui, processSelect, isExiting, searchMenuSwallowRightUp
    if (isExiting || !IsOwnGuiWindow(hwnd))
        return
    if (searchMenuSwallowRightUp) {
        searchMenuSwallowRightUp := false
        return 0
    }
    if (IsWindowValid(selectorFrameGui) && DllCall("User32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") = selectorFrameGui.Hwnd)
        return 0
    if (IsWindowValid(processSelect) && hwnd = processSelect.Hwnd) {
        SetTimer(ShowSearchContextMenu, -1)
        return 0
    }
}

HandleContextMenuMsg(wParam, lParam, msg, hwnd) {
    global processSelect, isExiting
    if (isExiting || !IsWindowValid(processSelect) || hwnd != processSelect.Hwnd)
        return
    SetTimer(ShowSearchContextMenu, -1)
    return 0
}

; Edit menu for the search box (Undo / Cut / Copy / Paste / Delete / Select All).
; It is a small script-drawn popup that never takes focus (like the game dropdown), so the search
; box keeps its caret/selection, rows highlight on hover, press and release, and the normal arrow
; cursor is shown. It closes on an outside click, Escape, or when the app loses the foreground.

ShowSearchContextMenu() {
    global processSelect, mainGui, isExiting, isSearchMenuOpen, searchMenuGui, searchMenuItems
    global searchMenuHover, searchMenuPressed, searchMenuLeftWasDown, searchMenuAnyWasDown
    if (isExiting || !IsWindowValid(processSelect) || !IsWindowValid(mainGui))
        return
    CloseSearchMenu(false)
    edit := processSelect.Hwnd
    if (DllCall("User32\GetFocus", "Ptr") != edit)
        DllCall("User32\SetFocus", "Ptr", edit)

    selStart := Buffer(4, 0), selEnd := Buffer(4, 0)
    SendMessage(0x00B0, selStart.Ptr, selEnd.Ptr, edit)
    hasSelection := NumGet(selStart, 0, "UInt") != NumGet(selEnd, 0, "UInt")
    textLength := StrLen(processSelect.Value)
    canUndo := SendMessage(0x00C6, 0, 0, edit)
    canPaste := DllCall("User32\IsClipboardFormatAvailable", "UInt", 13, "Int")
    allSelected := hasSelection && (NumGet(selStart, 0, "UInt") = 0) && (NumGet(selEnd, 0, "UInt") >= textLength)

    ; label, enabled, edit message (0 = separator)
    defs := [["Undo", canUndo, 0x00C7, 0, 0], [""], ["Cut", hasSelection, 0x0300, 0, 0], ["Copy", hasSelection, 0x0301, 0, 0]
        , ["Paste", canPaste, 0x0302, 0, 0], ["Delete", hasSelection, 0x0303, 0, 0], [""]
        , ["Select All", (textLength > 0 && !allSelected), 0x00B1, 0, -1]]

    menuW := 190, rowH := 34, sepH := 9
    totalH := 2
    for d in defs
        totalH += (d.Length = 1) ? sepH : rowH

    searchMenuGui := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x08000000 +Owner" mainGui.Hwnd, "")
    searchMenuGui.BackColor := "454545"          ; 1px border colour
    searchMenuGui.MarginX := 0, searchMenuGui.MarginY := 0
    searchMenuItems := []
    y := 1
    for d in defs {
        if (d.Length = 1) {
            searchMenuGui.Add("Text", Format("x{} y{} w{} h1 Background454545", 8, y + 4, menuW - 16), "")
            y += sepH
            continue
        }
        enabled := d[2] ? true : false
        ctl := searchMenuGui.Add("Text", Format("x1 y{} w{} h{} +0x200 +0x100 Background1E1E1E c{}", y, menuW - 2, rowH, enabled ? "FFFFFF" : "6E6E6E"), "     " d[1])
        ctl.SetFont("s11", "Segoe UI")
        searchMenuItems.Push({ctrl: ctl, enabled: enabled, msg: d[3], wp: d[4], lp: d[5], edit: edit})
        y += rowH
    }

    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    posX := mx, posY := my
    monCount := MonitorGetCount()
    Loop monCount {
        MonitorGetWorkArea(A_Index, &ml, &mt, &mr, &mb)
        if (mx >= ml && mx < mr && my >= mt && my < mb) {
            posX := Min(mx, mr - menuW), posY := Min(my, mb - totalH)
            posX := Max(posX, ml), posY := Max(posY, mt)
            break
        }
    }
    searchMenuGui.Show(Format("NoActivate x{} y{} w{} h{}", posX, posY, menuW, totalH))
    try DllCall("Dwmapi\DwmSetWindowAttribute", "Ptr", searchMenuGui.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)

    searchMenuHover := 0, searchMenuPressed := 0
    searchMenuLeftWasDown := GetKeyState("LButton", "P")
    searchMenuAnyWasDown := searchMenuLeftWasDown || GetKeyState("RButton", "P")
    isSearchMenuOpen := true
    ClearDropdownHover()
    SetTimer(SearchMenuTick, 10)
}

ClearDropdownHover() {
    global selectorList, selectorHoveredIndex, dropdownMarqueeIndex, isKeyboardNavigating
    isKeyboardNavigating := false
    dropdownMarqueeIndex := -1
    if (IsProcessSelectorOpen() && IsWindowValid(selectorList))
        SetSelectorHoverIndex(-1)
}

SetSearchMenuRowColor(item, state) {
    ; state: 0 normal, 1 hover, 2 pressed
    color := (!item.enabled || state = 0) ? "1E1E1E" : (state = 1 ? "3A3A3A" : "505050")
    MarqueeFrameAlign()
    item.ctrl.Opt("+Background" color)
    item.ctrl.Redraw()
}

SearchMenuTick() {
    global searchMenuGui, searchMenuItems, searchMenuHover, searchMenuPressed, isSearchMenuOpen
    global searchMenuLeftWasDown, searchMenuAnyWasDown, isExiting
    if (isExiting || !isSearchMenuOpen || !IsWindowValid(searchMenuGui)) {
        CloseSearchMenu(false)
        return
    }
    if (!IsForegroundOurProcess()) {
        CloseSearchMenu()
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my, , &ctl, 2)

    hovered := 0
    for i, item in searchMenuItems {
        if (ctl = item.ctrl.Hwnd) {
            hovered := i
            break
        }
    }
    leftDown := GetKeyState("LButton", "P")
    anyDown := leftDown || GetKeyState("RButton", "P")

    rect := Buffer(16, 0)
    DllCall("User32\GetWindowRect", "Ptr", searchMenuGui.Hwnd, "Ptr", rect, "Int")
    insideMenu := mx >= NumGet(rect, 0, "Int") && mx < NumGet(rect, 8, "Int") && my >= NumGet(rect, 4, "Int") && my < NumGet(rect, 12, "Int")

    ; Any new button press outside the menu closes it (the click still reaches what is under it).
    if (anyDown && !searchMenuAnyWasDown && !insideMenu) {
        CloseSearchMenu()
        return
    }

    ; Left press on a row starts the press effect.
    if (leftDown && !searchMenuLeftWasDown && hovered > 0 && searchMenuItems[hovered].enabled)
        searchMenuPressed := hovered

    ; Left release: run the pressed row when released on the same row.
    if (!leftDown && searchMenuLeftWasDown && searchMenuPressed > 0) {
        item := searchMenuItems[searchMenuPressed]
        run := (hovered = searchMenuPressed && item.enabled)
        searchMenuPressed := 0
        searchMenuLeftWasDown := false
        searchMenuAnyWasDown := false
        if (run) {
            SetSearchMenuRowColor(item, 2)
            MarqueeSafeWait(60)                 ; Sleep(60) froze the marquee for 4 frames
            CloseSearchMenu()
            SendMessage(item.msg, item.wp, item.lp, item.edit)
            return
        }
    }
    searchMenuLeftWasDown := leftDown
    searchMenuAnyWasDown := anyDown

    for i, item in searchMenuItems {
        state := 0
        if (item.enabled && i = hovered)
            state := (searchMenuPressed = i && leftDown) ? 2 : 1
        if (!HasProp(item, "state") || item.state != state) {
            item.state := state
            SetSearchMenuRowColor(item, state)
        }
    }
}

CloseSearchMenu(restoreFocus := true) {
    global searchMenuGui, searchMenuItems, isSearchMenuOpen
    SetTimer(SearchMenuTick, 0)
    isSearchMenuOpen := false
    if (IsObject(searchMenuGui)) {
        try searchMenuGui.Destroy()
        searchMenuGui := ""
    }
    searchMenuItems := []
    if (restoreFocus)
        SetTimer(RestoreSearchFocusAfterMenu, -30)
}

RestoreSearchFocusAfterMenu(*) {
    global processSelect, isExiting
    if (isExiting || !IsWindowValid(processSelect) || IsContextMenuOpen())
        return
    if (IsForegroundOurProcess() && DllCall("User32\GetFocus", "Ptr") != processSelect.Hwnd)
        DllCall("User32\SetFocus", "Ptr", processSelect.Hwnd)
}

#HotIf isSearchMenuOpen
Escape::CloseSearchMenu()
#HotIf

OnEraseBackground(wParam, lParam, msg, hwnd) {
    global refreshButton, minBtn, closeBtn, selectorList, selectorDisplayedOptions, selectorRowHeight
    ; Dropdown list: every row paints itself completely (black fill + highlight + text, copied in one BitBlt), so the
    ; system's erase-to-black pass over the rows only produced a blink. Erase just the empty area UNDER the last row.
    if (IsObject(selectorList) && IsWindowValid(selectorList) && hwnd = selectorList.Hwnd) {
        rc := Buffer(16, 0)
        DllCall("User32\GetClientRect", "Ptr", hwnd, "Ptr", rc)
        topIndex := SendMessage(0x018E, 0, 0, hwnd)
        if (topIndex < 0)
            topIndex := 0
        usedBottom := (selectorDisplayedOptions.Length - topIndex) * selectorRowHeight
        if (usedBottom < NumGet(rc, 12, "Int")) {
            NumPut("Int", Max(0, usedBottom), rc, 4)
            brush := DllCall("Gdi32\GetStockObject", "Int", 4, "Ptr")   ; BLACK_BRUSH
            DllCall("User32\FillRect", "Ptr", wParam, "Ptr", rc, "Ptr", brush)
        }
        return 1
    }
    if (IsWindowValid(refreshButton) && hwnd = refreshButton.Hwnd)
        return 1
    if (IsWindowValid(minBtn) && hwnd = minBtn.Hwnd)
        return 1
    if (IsWindowValid(closeBtn) && hwnd = closeBtn.Hwnd)
        return 1
}

; Moves the main window with the mouse from a normal timer, so the marquee timer keeps running while the button is held
; (a press without moving does nothing at all, and the text never pauses).
StartWindowDrag() {
    global mainGui, windowDragActive, windowDragMouseX, windowDragMouseY, windowDragWinX, windowDragWinY
    global windowDragLastX, windowDragLastY, isWindowMoving
    if (windowDragActive || !IsWindowValid(mainGui))
        return
    pt := Buffer(8, 0)
    rect := Buffer(16, 0)
    if (!DllCall("User32\GetCursorPos", "Ptr", pt, "Int") || !DllCall("User32\GetWindowRect", "Ptr", mainGui.Hwnd, "Ptr", rect, "Int"))
        return
    windowDragMouseX := NumGet(pt, 0, "Int"), windowDragMouseY := NumGet(pt, 4, "Int")
    windowDragWinX := NumGet(rect, 0, "Int"), windowDragWinY := NumGet(rect, 4, "Int")
    windowDragLastX := windowDragWinX, windowDragLastY := windowDragWinY
    windowDragActive := true
    isWindowMoving := true
    SetTimer(WindowDragTick, 8)
}

WindowDragTick() {
    global mainGui, isExiting, windowDragActive, windowDragMouseX, windowDragMouseY, windowDragWinX, windowDragWinY
    global windowDragLastX, windowDragLastY
    if (!windowDragActive || isExiting || !IsWindowValid(mainGui)) {
        EndWindowDrag()
        return
    }
    if (!GetKeyState("LButton", "P")) {
        EndWindowDrag()
        return
    }
    pt := Buffer(8, 0)
    if (!DllCall("User32\GetCursorPos", "Ptr", pt, "Int"))
        return
    newX := windowDragWinX + (NumGet(pt, 0, "Int") - windowDragMouseX)
    newY := windowDragWinY + (NumGet(pt, 4, "Int") - windowDragMouseY)
    if (newX = windowDragLastX && newY = windowDragLastY)
        return
    windowDragLastX := newX, windowDragLastY := newY
    ; SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
    DllCall("User32\SetWindowPos", "Ptr", mainGui.Hwnd, "Ptr", 0, "Int", newX, "Int", newY, "Int", 0, "Int", 0, "UInt", 0x0015, "Int")
    SyncRefreshOverlay()      ; keep the refresh overlay glued to the button while the window is dragged
}

EndWindowDrag() {
    global mainGui, windowDragActive, isWindowMoving, isExiting
    SetTimer(WindowDragTick, 0)
    if (!windowDragActive)
        return
    windowDragActive := false
    isWindowMoving := false
    if (isExiting || !IsWindowValid(mainGui))
        return
    ApplyMarqueeRefresh(GetMarqueeHz(mainGui.Hwnd))
    PositionChildWindows()
}

OnEnterSizeMove(wParam, lParam, msg, hwnd) {
    global mainGui, isWindowMoving
    if (hwnd = mainGui.Hwnd)
        isWindowMoving := true
}

OnExitSizeMove(wParam, lParam, msg, hwnd) {
    global mainGui, isWindowMoving
    if (hwnd = mainGui.Hwnd) {
        isWindowMoving := false
        ApplyMarqueeRefresh(GetMarqueeHz(mainGui.Hwnd))
        PositionChildWindows()
    }
}

GetDropdownItemAtMouse() {
    global selectorList, selectorDisplayedOptions, selectorRowHeight, isSearchMenuOpen
    if (isSearchMenuOpen)
        return -1
    if (!IsWindowValid(selectorList) || selectorDisplayedOptions.Length = 0)
        return -1
        
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseX, &mouseY, &windowUnderMouse)
    if (windowUnderMouse && !IsOwnGuiWindow(windowUnderMouse))
        return -1
    
    rect := Buffer(16, 0)
    if (!DllCall("User32\GetWindowRect", "Ptr", selectorList.Hwnd, "Ptr", rect, "Int"))
        return -1
        
    lX := NumGet(rect, 0, "Int")
    tY := NumGet(rect, 4, "Int")
    rX := NumGet(rect, 8, "Int")
    bY := NumGet(rect, 12, "Int")
    
    if (mouseX < lX || mouseX >= rX || mouseY < tY || mouseY >= bY)
        return -1
        
    localY := mouseY - tY
    visibleRow := localY // selectorRowHeight
    topIndex := SendMessage(0x018E, 0, 0, selectorList.Hwnd)
    if (topIndex < 0)
        topIndex := 0
        
    itemIndex := topIndex + visibleRow
    if (itemIndex < 0 || itemIndex >= selectorDisplayedOptions.Length)
        return -1
        
    return itemIndex
}

UpdateDropdownItemHover(itemIndex) {
    global selectorList, selectorDisplayedOptions, selectorHoveredIndex, dropdownMarqueeIndex
    if (itemIndex < 0 || itemIndex >= selectorDisplayedOptions.Length)
        return

    ; Start the marquee BEFORE the row is repainted as highlighted: the first highlighted paint then already uses the smooth strip
    ; (same order UpdateDropdownMarquee uses), and the row that lost the highlight is no longer drawn as the scrolling one.
    if (dropdownMarqueeIndex != itemIndex) {
        if (!StartDropdownMarquee(itemIndex))
            dropdownMarqueeIndex := -1
    }

    if (itemIndex != selectorHoveredIndex) {
        SetSelectorHoverIndex(itemIndex)
    }
}

; Measures the hovered title once (not on every timer tick) and starts its marquee if the title is cut off.
; The movement itself keeps the original style: slide to the end of the title, hold, jump back, pause.
StartDropdownMarquee(itemIndex) {
    global selectorList, selectorDisplayedOptions
    global dropdownMarqueeIndex, dropdownMarqueeOffset, dropdownMarqueeLastTick, dropdownMarqueePauseUntil
    global dropdownMarqueeTitle, dropdownMarqueeOverflowW, dropdownMarqueeCycleW, dropdownMarqueeRenderedX, dropdownMarqueeFrames
    global dropdownRenderedPhase, dropdownMarqueeTextW

    dropdownMarqueeTitle := ""
    dropdownMarqueeOverflowW := 0
    dropdownMarqueeCycleW := 0
    if (itemIndex < 0 || itemIndex >= selectorDisplayedOptions.Length || !IsWindowValid(selectorList))
        return false

    titleText := selectorDisplayedOptions[itemIndex + 1]
    WinGetPos(,, &listW,, "ahk_id " selectorList.Hwnd)
    leftTextInset := rowLeftInset                 ; its own value (no longer 2 % of the list width)
    textW := MeasureRowTextWidth(titleText)
    GetRowTextBearings(titleText, &bearingA, &bearingC)
    maxTextW := listW - RowRightEdgeInset() - 1 - leftTextInset - rowRightPad - bearingA + bearingC - RowIconOffset(leftTextInset)
    if (textW <= maxTextW)
        return false

    dropdownMarqueeTitle := titleText
    dropdownMarqueeOverflowW := textW - maxTextW
    dropdownMarqueeCycleW := dropdownMarqueeOverflowW + (leftTextInset * 2)

    now := NowMs()
    dropdownMarqueeIndex := itemIndex
    dropdownMarqueeOffset := 0.0
    dropdownMarqueeLastTick := FrameStamp()
    dropdownMarqueePauseUntil := now + MarqueePauseMs()
    dropdownMarqueeRenderedX := 0
    dropdownRenderedPhase := 0
    dropdownMarqueeFrames := 0
    dropdownMarqueeTextW := textW
    ; Render the title strip NOW (during the hold), so the row is already drawn with the smooth text when it first gets highlighted
    ; and nothing has to be built at the moment the text starts to move.
    BuildDropdownStrip()
    return true
}

PollDropdownHover(*) {
    global selectorFrameGui, selectorList, selectorDisplayedOptions, dropdownMarqueeIndex, selectorHoveredIndex, isKeyboardNavigating
    if (IsContextMenuOpen())
        return
    if (!IsProcessSelectorOpen() || !IsWindowValid(selectorList)) {
        if (dropdownMarqueeIndex != -1) {
            dropdownMarqueeIndex := -1
        }
        return
    }

    if (RefreshKeyboardNavMode())
        return

    itemIndex := GetDropdownItemAtMouse()
    if (itemIndex >= 0 && itemIndex < selectorDisplayedOptions.Length)
        UpdateDropdownItemHover(itemIndex)
}

UpdateDropdownMarquee(*) {
    global selectorList, dropdownMarqueeIndex, dropdownMarqueeOffset, dropdownMarqueeLastTick, dropdownMarqueePauseUntil
    global dropdownMarqueeTitle, dropdownMarqueeOverflowW, dropdownMarqueeCycleW, dropdownMarqueeRenderedX
    global marqueeRefreshHz, marqueeFrameStep, dropdownMarqueeFrames, marqueePxStep
    global selectorHoveredIndex, selectorDisplayedOptions, selectorRowHeight
    global dropdownStripPhases, dropdownRenderedPhase, dropdownStripDirty
    if (IsContextMenuOpen())
        return
    if (!IsProcessSelectorOpen() || !IsWindowValid(selectorList)) {
        if (dropdownMarqueeIndex != -1) {
            dropdownMarqueeIndex := -1
        }
        return
    }

    itemIndex := GetActiveHoverIndex()
    if (itemIndex < 0 || itemIndex >= selectorDisplayedOptions.Length) {
        if (dropdownMarqueeIndex != -1) {
            dropdownMarqueeIndex := -1
            RepaintSelectorList()
        }
        return
    }

    ; Measure only when the hovered row or its text changed, not on every frame.
    if (dropdownMarqueeIndex != itemIndex || dropdownMarqueeCycleW <= 0 || dropdownMarqueeTitle !== selectorDisplayedOptions[itemIndex + 1]) {
        wasActive := (dropdownMarqueeIndex != -1)
        if (!StartDropdownMarquee(itemIndex)) {
            dropdownMarqueeIndex := -1
            if (wasActive)
                RepaintSelectorList()
            return
        }
        SetSelectorHoverIndex(itemIndex)
    }

    if (dropdownStripDirty)                 ; refresh rate changed: the phase count depends on it (BuildDropdownStrip is cheap)
        BuildDropdownStrip()
    ; Same shared step as the status line and the popup title (smooth: 1/N px on EVERY refresh; fallback strip: 1 px per N refreshes).
    ; The title holds at its end until the cycle is over, then jumps back and pauses.
    if (!MarqueeTick(&dropdownMarqueeOffset, &dropdownMarqueeFrames, &dropdownMarqueeLastTick, &dropdownMarqueePauseUntil
        , &dropdownMarqueeRenderedX, &dropdownRenderedPhase, dropdownMarqueeCycleW, dropdownMarqueeOverflowW, dropdownStripPhases))
        return

    WinGetPos(,,, &listHeight, "ahk_id " selectorList.Hwnd)
    topIndex := SendMessage(0x018E, 0, 0, selectorList.Hwnd)
    visibleRow := dropdownMarqueeIndex - topIndex
    visibleRows := Max(1, Floor(listHeight / selectorRowHeight))
    if (visibleRow >= 0 && visibleRow < visibleRows) {
        itemRect := Buffer(16, 0)
        SendMessage(0x0198, dropdownMarqueeIndex, itemRect.Ptr, selectorList.Hwnd)
        DllCall("User32\InvalidateRect", "Ptr", selectorList.Hwnd, "Ptr", itemRect, "Int", false)
        DllCall("User32\UpdateWindow", "Ptr", selectorList.Hwnd)
    } else {
        RepaintSelectorList()
    }
}

OnWmSize(wParam, lParam, msg, hwnd) {
    global mainGui, isMarqueeActive, isWindowVisible
    if (!IsSet(mainGui) || !IsObject(mainGui) || !IsSet(isMarqueeActive) || !IsSet(isWindowVisible))
        return
    if (hwnd = mainGui.Hwnd) {
        if (wParam = 1) {
            CloseProcessSelector()
            isWindowVisible := false
        } else {
            isWindowVisible := true
            ResumeMarquee()
        }
    }
}

OnSysCommand(wParam, lParam, msg, hwnd) {
    global mainGui, isExiting, isWindowVisible, frameGui, selectGui, actionGui, selectorFrameGui
    if (isExiting || !IsSet(mainGui) || !mainGui)
        return
    ; ALT FIX: pressing and releasing Alt (or Alt + a letter) makes Windows enter "menu mode" (SC_KEYMENU = 0xF100) even though
    ; this window has no menu bar: the keyboard focus leaves the search box / window and the next key beeps. Swallow it.
    if ((wParam & 0xFFF0) = 0xF100 && IsOwnGuiWindow(hwnd))
        return 0
    if (hwnd = mainGui.Hwnd) {
        cmd := wParam & 0xFFF0
        if (cmd = 0xF060) {
            if (!isExiting)
                CloseApplication()
            return 0
        }
        if (cmd = 0xF020) {
            CloseProcessSelector()
        }
        if (cmd = 0xF120) {
            isWindowVisible := true
            ResumeMarquee()
            SetTimer(() => (frameGui.Show("NA"), selectGui.Show("NA"), actionGui.Show("NA"), PositionChildWindows()), -10)
        }
    }
}

OnWmClose(wParam, lParam, msg, hwnd) {
    global mainGui, isExiting
    if (isExiting || !IsSet(mainGui) || !mainGui)
        return
    if (hwnd = mainGui.Hwnd) {
        if (!isExiting)
            CloseApplication()
        return 0
    }
}

OnNcCalcSize(wParam, lParam, msg, hwnd) {
    global mainGui, isExiting
    if (isExiting || !IsSet(mainGui) || !mainGui)
        return 0
    if (hwnd = mainGui.Hwnd)
        return 0
}

OnActivateWindow(wParam, lParam, msg, hwnd) {
    global mainGui, actionGui, actionBtn, minBtn, closeBtn, isExiting, isWindowVisible, frameGui, selectGui, selectorFrameGui, appIsInactive, riskViewBusy, riskFadeEndTick
    if (isExiting || !IsSet(mainGui) || !mainGui)
        return
    if (hwnd = mainGui.Hwnd)
        appIsInactive := ((wParam & 0xFFFF) = 0)
    if (hwnd = mainGui.Hwnd)
        DropdownZOrderGuard()
    if (hwnd = mainGui.Hwnd && wParam != 0) {
        if (!isWindowVisible) {
            isWindowVisible := true
            frameGui.Show("NA")
            selectGui.Show("NA")
            actionGui.Show("NA")
        }
        ; Focus changes made by the view switch itself (FocusMainWindowAfterFade) must not trigger a full repaint of the
        ; window: it landed right after the fade and showed as a flicker / hitch of the scrolling status line.
        if (riskViewBusy || A_TickCount - riskFadeEndTick < 500)
            return
        ResumeMarquee()
        DllCall("User32\RedrawWindow", "Ptr", mainGui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0181)
        RepaintRefreshButtonNoErase()
        SetTimer(() => (RepaintRefreshButtonNoErase(), RepaintActionButtonNoErase(), minBtn.Redraw(), closeBtn.Redraw(), PositionChildWindows(), DllCall("InvalidateRect", "Ptr", actionGui.Hwnd, "Ptr", 0, "Int", false)), -10)
    }
}

ResumeMarquee() {
    global isMarqueeActive, marqueeTimerRunning, marqueeLastTick, marqueePauseUntil
    if (isMarqueeActive) {
        marqueeLastTick := FrameStamp()
        if (!riskViewActive && !riskViewBusy)
            marqueePauseUntil := Min(marqueePauseUntil, NowMs() + 300)
        PositionStatusControls()
        if (!marqueeTimerRunning) {
            SetTimer(MarqueeMaster, 8)
            marqueeTimerRunning := true
        }
    }
}

ScrollListLines(lines) {
    global selectorList, selectorDisplayedOptions, selectorRowHeight, isKeyboardNavigating, selectorHoveredIndex, keyNavMouseX, keyNavMouseY, selectorListFrozen
    if (!IsWindowValid(selectorList))
        return
    if (selectorDisplayedOptions.Length = 0)
        return
        
    topIndex := SendMessage(0x018E, 0, 0, selectorList.Hwnd)
    if (topIndex < 0)
        topIndex := 0
    WinGetPos(,,, &listHeight, "ahk_id " selectorList.Hwnd)
    visibleRows := Max(1, Floor(listHeight / selectorRowHeight))
    maxTop := Max(0, selectorDisplayedOptions.Length - visibleRows)
    
    if (!RefreshKeyboardNavMode()) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&keyNavMouseX, &keyNavMouseY)
    }
    currSel := GetActiveHoverIndex()
    if (currSel < 0) {
        if (selectorHoveredIndex >= 0 && selectorHoveredIndex < selectorDisplayedOptions.Length)
            currSel := selectorHoveredIndex
        else
            currSel := SendMessage(0x0188, 0, 0, selectorList.Hwnd)
    }
    if (currSel < 0)
        currSel := topIndex
        
    newSel := Max(0, Min(selectorDisplayedOptions.Length - 1, currSel + lines))
    newTop := Max(0, Min(maxTop, newSel - 1))
    
    ; Freeze painting while selection, scroll position and hover index change together,
    ; so the list is never drawn with the OLD hover row at the top/bottom of the new view.
    isKeyboardNavigating := true
    selectorListFrozen := true
    SendMessage(0x000B, 0, 0, selectorList.Hwnd)
    try {
        SendMessage(0x0185, 1, currSel, selectorList.Hwnd)
        SendMessage(0x0186, newSel, 0, selectorList.Hwnd)
        SendMessage(0x0197, newTop, 0, selectorList.Hwnd)
        SetSelectorHoverIndex(newSel)
    } finally {
        SendMessage(0x000B, 1, 0, selectorList.Hwnd)
        selectorListFrozen := false
    }
    RepaintSelectorList()
    UpdateScrollThumbPosition()

}

BeginDropdownClick() {
    global isKeyboardNavigating, selectorClickIndex, selectorPopup, selectorScrollUpBtn, selectorScrollDownBtn, selectorScrollThumb, selectorScrollThumbTrack, isDraggingThumb, thumbDragStartY, thumbDragStartThumbY, thumbDragTrackTopY, thumbDragTrackTravel, selectorList, selectorDisplayedOptions, selectorRowHeight, scrollContinuousAction, scrollContinuousNextTick
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseX, &mouseY)
    
    if (IsWindowValid(selectorPopup) && selectorDisplayedOptions.Length > 3 && IsWindowValid(selectorScrollUpBtn) && IsWindowValid(selectorScrollDownBtn) && IsWindowValid(selectorScrollThumb) && IsWindowValid(selectorScrollThumbTrack)) {
        WinGetPos(&tX, &tY, &tW, &tH, "ahk_id " selectorScrollThumb.Hwnd)
        WinGetPos(&uX, &uY, &uW, &uH, "ahk_id " selectorScrollUpBtn.Hwnd)
        WinGetPos(&dX, &dY, &dW, &dH, "ahk_id " selectorScrollDownBtn.Hwnd)
        WinGetPos(&trackX, &trackY, &trackW, &trackH, "ahk_id " selectorScrollThumbTrack.Hwnd)
        
        onUp := (mouseX >= uX && mouseX < uX + uW && mouseY >= uY && mouseY < uY + uH)
        onDown := (mouseX >= dX && mouseX < dX + dW && mouseY >= dY && mouseY < dY + dH)
        onThumb := (mouseX >= tX && mouseX < tX + tW && mouseY >= tY && mouseY < tY + tH)
        onTrack := (mouseX >= trackX && mouseX < trackX + trackW && mouseY >= trackY && mouseY < trackY + trackH)
        
        if (onUp || onDown || onThumb || onTrack)
            selectorClickIndex := -1

        if (onUp) {
            ScrollListLines(-1)
            PressIcon("up")
            scrollContinuousAction := "up"
            scrollContinuousNextTick := A_TickCount + 450
            SetTimer(ProcessContinuousScroll, 40)
            RepaintIconButton("up")
            return
        } else if (onDown) {
            ScrollListLines(1)
            PressIcon("down")
            scrollContinuousAction := "down"
            scrollContinuousNextTick := A_TickCount + 450
            SetTimer(ProcessContinuousScroll, 40)
            RepaintIconButton("down")
            return
        } else if (onThumb) {
            thumbDragStartY := mouseY
            thumbDragStartThumbY := tY
            thumbDragTrackTopY := trackY
            thumbDragTrackTravel := Max(0, trackH - tH)
            isDraggingThumb := true
            DllCall("User32\SetCapture", "Ptr", selectorScrollThumb.Hwnd)
            UpdateScrollControllerHover()
            return
        } else if (onTrack) {
            totalTrackTravel := Max(1, trackH - tH)
            relY := mouseY - trackY - (tH / 2)
            ratio := Max(0.0, Min(1.0, relY / totalTrackTravel))
            WinGetPos(,,, &listHeight, "ahk_id " selectorList.Hwnd)
            visibleRows := Max(1, Floor(listHeight / selectorRowHeight))
            maxTop := Max(0, selectorDisplayedOptions.Length - visibleRows)
            targetTop := Round(ratio * maxTop)
            SendMessage(0x0197, targetTop, 0, selectorList.Hwnd)
            UpdateScrollThumbPosition()

            WinGetPos(&newThumbX, &newThumbY, &newThumbW, &newThumbH, "ahk_id " selectorScrollThumb.Hwnd)
            thumbDragStartY := mouseY
            thumbDragStartThumbY := newThumbY
            thumbDragTrackTopY := trackY
            thumbDragTrackTravel := Max(0, trackH - newThumbH)
            isDraggingThumb := true
            DllCall("User32\SetCapture", "Ptr", selectorScrollThumb.Hwnd)
            UpdateScrollControllerHover()
            return
        }
    }
    isKeyboardNavigating := false
    selectorClickIndex := GetDropdownItemAtMouse()
    if (selectorClickIndex >= 0 && IsWindowValid(selectorList)) {
        BeginDropdownItemPress()
    }
}

FinishDropdownClick() {
    global selectorClickIndex, selectorCommitIndex, isDraggingThumb, selectorScrollThumb, scrollContinuousAction, selectorScrollUpBtn, selectorScrollDownBtn
    if (isDraggingThumb && IsWindowValid(selectorScrollThumb)
        && DllCall("User32\GetCapture", "Ptr") = selectorScrollThumb.Hwnd)
        DllCall("User32\ReleaseCapture", "Int")
    isDraggingThumb := false
    scrollContinuousAction := ""
    SetTimer(ProcessContinuousScroll, 0)
    MarqueeFrameAlign()
    RepaintIconButton("up")
    RepaintIconButton("down")
    
    pressedIndex := selectorClickIndex
    selectorClickIndex := -1
    if (pressedIndex < 0)
        return
    releasedIndex := GetDropdownItemAtMouse()
    EndDropdownItemPress()
    if (releasedIndex != pressedIndex)
        return   ; released away from the title it was pressed on: not a click, nothing is selected
    selectorCommitIndex := pressedIndex
    SetTimer(CommitDropdownSelection, -50)
}

ProcessContinuousScroll(*) {
    global scrollContinuousAction, scrollContinuousNextTick
    if (scrollContinuousAction = "") {
        SetTimer(ProcessContinuousScroll, 0)
        return
    }
    if (!GetKeyState("LButton", "P")) {
        scrollContinuousAction := ""
        SetTimer(ProcessContinuousScroll, 0)
        return
    }
    if (A_TickCount >= scrollContinuousNextTick) {
        if (scrollContinuousAction = "up")
            ScrollListLines(-1)
        else if (scrollContinuousAction = "down")
            ScrollListLines(1)
        scrollContinuousNextTick := A_TickCount + 220
    }
}

; ---------------------------------------------------------------------------------------------
; Icon click animation. Minimize, close, refresh and the two scroll buttons all use the same
; motion: the ICON (not the button) shrinks quickly while the mouse is held and springs back
; with a tiny overshoot on release. One set of speeds / scale for every button keeps them a group.
; ---------------------------------------------------------------------------------------------
EaseOutCubic(t) => 1 - (1 - t) ** 3

EaseOutBack(t) {
    c1 := 1.70158, c3 := c1 + 1
    return 1 + c3 * (t - 1) ** 3 + c1 * (t - 1) ** 2
}

GetIconScale(key) {
    global iconAnimState
    if (!iconAnimState.Has(key))
        return 1.0
    s := iconAnimState[key]
    progress := Min(1.0, Max(0.0, (A_TickCount - s.startTick) / s.dur))
    eased := (s.ease = "back") ? EaseOutBack(progress) : EaseOutCubic(progress)
    return s.fromScale + (s.toScale - s.fromScale) * eased
}

StartIconAnim(key, toScale, dur, ease, held) {
    global iconAnimState
    iconAnimState[key] := {fromScale: GetIconScale(key), toScale: toScale, startTick: A_TickCount, dur: dur, ease: ease, held: held}
    SetTimer(IconAnimTick, 16)
}

PressIcon(key) {
    global iconPressScale, iconPressDuration
    StartIconAnim(key, iconPressScale, iconPressDuration, "cubic", true)
}

ReleaseIcon(key) {
    global iconReleaseDuration
    StartIconAnim(key, 1.0, iconReleaseDuration, "back", false)
}

RepaintIconButton(key) {
    global minBtn, closeBtn, refreshButton, selectorScrollUpBtn, selectorScrollDownBtn, riskTosCtl
    if (key = "tos") {
        PaintTosDirect()
        return
    }
    ctrl := ""
    switch key {
        case "min": ctrl := minBtn
        case "close": ctrl := closeBtn
        case "refresh": ctrl := refreshButton
        case "up": ctrl := selectorScrollUpBtn
        case "down": ctrl := selectorScrollDownBtn
    }
    if (!IsWindowValid(ctrl))
        return
    ; Direct paint (no InvalidateRect / UpdateWindow): on the layered + composited main window those re-print the WHOLE window
    ; tree, status marquee included = the marquee shook whenever the minimize / close / refresh / arrow buttons animated.
    if (key = "min" || key = "close") {
        if (PaintControlDirect(ctrl, (d) => DrawTopButton(d, key)))
            return
    } else if (key = "refresh") {
        RepaintRefreshButtonNoErase()
        return
    } else if (key = "up" || key = "down") {
        isUp := (key = "up")
        if (PaintControlDirect(ctrl, (d) => DrawScrollButton(d, isUp)))
            return
    }
    DllCall("User32\InvalidateRect", "Ptr", ctrl.Hwnd, "Ptr", 0, "Int", false)
    DllCall("User32\UpdateWindow", "Ptr", ctrl.Hwnd)
}

IconAnimTick(*) {
    global iconAnimState, isExiting
    if (iconAnimState.Count = 0) {
        SetTimer(IconAnimTick, 0)
        return
    }
    buttonDown := GetKeyState("LButton", "P")
    keys := []
    for key in iconAnimState
        keys.Push(key)
    anyActive := false
    MarqueeFrameAlign()                         ; paint right after a marquee frame, never in the middle of a refresh interval
    for key in keys {
        s := iconAnimState[key]
        if (s.held && !buttonDown) {
            ReleaseIcon(key)
            s := iconAnimState[key]
        }
        RepaintIconButton(key)
        progress := (A_TickCount - s.startTick) / s.dur
        if (s.held || progress < 1.0)
            anyActive := true
        else if (s.toScale = 1.0)
            iconAnimState.Delete(key)
    }
    if (!anyActive)
        SetTimer(IconAnimTick, 0)
    ResyncMarqueeClocks()                       ; drop refreshes missed during the paint instead of catching up
}

StartRefreshKick() {
    global refreshKickStart
    refreshKickStart := A_TickCount
    SetTimer(RefreshKickTick, 16)
}

RefreshKickTick(*) {
    global refreshKickStart, refreshKickDuration
    RepaintRefreshButtonNoErase()
    if (A_TickCount - refreshKickStart >= refreshKickDuration) {
        refreshKickStart := 0
        SetTimer(RefreshKickTick, 0)
        RepaintRefreshButtonNoErase()
    }
}

; White round-capped pen shared by every icon (same stroke weight everywhere).
CreateIconPen() {
    penBuffer := Buffer(A_PtrSize, 0)
    if (DllCall("gdiplus\GdipCreatePen1", "UInt", 0xFFFFFFFF, "Float", 1.8, "Int", 2, "Ptr", penBuffer, "UInt") != 0)
        return 0
    pen := NumGet(penBuffer, 0, "Ptr")
    DllCall("gdiplus\GdipSetPenStartCap", "Ptr", pen, "Int", 2, "UInt")
    DllCall("gdiplus\GdipSetPenEndCap", "Ptr", pen, "Int", 2, "UInt")
    DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", pen, "Int", 2, "UInt")
    return pen
}

; Draws one vector icon centred on (cx, cy), scaled about its own centre.
DrawIconGlyph(graphics, kind, cx, cy, scale) {
    pen := CreateIconPen()
    if (!pen)
        return
    DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", graphics, "Float", cx, "Float", cy, "Int", 0, "UInt")
    DllCall("gdiplus\GdipScaleWorldTransform", "Ptr", graphics, "Float", scale, "Float", scale, "Int", 0, "UInt")
    if (kind = "min") {
        DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", -7.1, "Float", 0.0, "Float", 7.1, "Float", 0.0, "UInt")
    } else if (kind = "close") {
        DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", -7.1, "Float", -7.1, "Float", 7.1, "Float", 7.1, "UInt")
        DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", -7.1, "Float", 7.1, "Float", 7.1, "Float", -7.1, "UInt")
    } else {
        sign := (kind = "up") ? 1.0 : -1.0
        pts := Buffer(24, 0)
        NumPut("Float", -4.5, "Float", 2.2 * sign, "Float", 0.0, "Float", -2.2 * sign, "Float", 4.5, "Float", 2.2 * sign, pts)
        DllCall("gdiplus\GdipDrawLines", "Ptr", graphics, "Ptr", pen, "Ptr", pts, "Int", 3, "UInt")
    }
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen, "UInt")
}

SetTopButtonBg(which, color) {
    global minBtn, closeBtn, minBtnBg, closeBtnBg
    if (which = "min") {
        if (minBtnBg = color)
            return
        minBtnBg := color
        ctrl := minBtn
    } else {
        if (closeBtnBg = color)
            return
        closeBtnBg := color
        ctrl := closeBtn
    }
    kind := which
    if (PaintControlDirect(ctrl, (d) => DrawTopButton(d, kind)))
        return                                 ; direct paint: no window-tree re-print (see RepaintRefreshButtonNoErase)
    if (IsWindowValid(ctrl)) {
        DllCall("User32\InvalidateRect", "Ptr", ctrl.Hwnd, "Ptr", 0, "Int", false)
        DllCall("User32\UpdateWindow", "Ptr", ctrl.Hwnd)
    }
}

; Owner-drawn minimize / close button: background + icon composed off-screen, copied once.
DrawTopButton(drawItemStruct, kind) {
    global minBtnBg, closeBtnBg, gdiplusToken
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    targetHdc := NumGet(drawItemStruct, itemHwndOffset + A_PtrSize, "Ptr")
    rectOffset := itemHwndOffset + A_PtrSize * 2
    left := NumGet(drawItemStruct, rectOffset, "Int")
    top := NumGet(drawItemStruct, rectOffset + 4, "Int")
    width := NumGet(drawItemStruct, rectOffset + 8, "Int") - left
    height := NumGet(drawItemStruct, rectOffset + 12, "Int") - top
    if (width <= 0 || height <= 0 || !targetHdc)
        return 1
    memoryDc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", targetHdc, "Ptr")
    if (!memoryDc)
        return 1
    bitmap := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", targetHdc, "Int", width, "Int", height, "Ptr")
    if (!bitmap) {
        DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
        return 1
    }
    oldBitmap := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", bitmap, "Ptr")
    localRect := Buffer(16, 0)
    NumPut("Int", width, localRect, 8)
    NumPut("Int", height, localRect, 12)
    brush := DllCall("Gdi32\CreateSolidBrush", "UInt", HexToColorRef(kind = "min" ? minBtnBg : closeBtnBg), "Ptr")
    DllCall("User32\FillRect", "Ptr", memoryDc, "Ptr", localRect, "Ptr", brush)
    DllCall("Gdi32\DeleteObject", "Ptr", brush)
    if (gdiplusToken) {
        graphicsBuffer := Buffer(A_PtrSize, 0)
        if (DllCall("gdiplus\GdipCreateFromHDC", "Ptr", memoryDc, "Ptr", graphicsBuffer, "UInt") = 0) {
            graphics := NumGet(graphicsBuffer, 0, "Ptr")
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4, "UInt")
            DrawIconGlyph(graphics, kind, width / 2.0, height / 2.0, GetIconScale(kind))
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics, "UInt")
        }
    }
    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBitmap, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", bitmap)
    DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
    return 1
}

IsGameSearchControlFocused() {
    global isGameSearchFocused, isExiting
    return (IsSet(isExiting) && IsSet(isGameSearchFocused) && !isExiting && isGameSearchFocused)
}

EnsureGameSearchFocus(*) {
    global processSelect, isExiting
    if (!IsSet(isExiting) || isExiting || !IsWindowValid(processSelect))
        return
    DllCall("User32\SetFocus", "Ptr", processSelect.Hwnd)
}

IsProcessSelectorOpen() {
    global selectorFrameGui, isExiting
    return (IsSet(isExiting) && IsSet(selectorFrameGui) && !isExiting && IsWindowValid(selectorFrameGui) && DllCall("User32\IsWindowVisible", "Ptr", selectorFrameGui.Hwnd, "Int"))
}

CommitDropdownSelectionFromMouse(*) {
    global selectorPopup, selectorList
    if (!IsWindowValid(selectorPopup) || !IsWindowValid(selectorList))
        return

    hitIndex := GetDropdownItemAtMouse()
    if (hitIndex >= 0) {
        EndDropdownItemPress()
        selectorCommitIndex := hitIndex
        SetTimer(CommitDropdownSelection, -50)
    }
}

HandleSearchAreaMouseDown(*) {
    BlurGameSearchOnOutsideClick()
    BeginDropdownItemPress()
}

BeginDropdownItemPress(*) {
    global selectorPressedIndex, selectorPressColorCurrent, selectorPressColorFrom, selectorPressColorTo
    global selectorPressStartedAt, selectorPressPhase, selectorList, selectorClickIndex, selectorDisplayedOptions
    itemIndex := (selectorClickIndex >= 0) ? selectorClickIndex : GetDropdownItemAtMouse()
    if (itemIndex >= 0 && itemIndex = selectorPressedIndex && (selectorPressPhase = "press" || selectorPressPhase = "held"))
        return
    if (itemIndex < 0 && IsWindowValid(selectorList)) {
        sel := SendMessage(0x0188, 0, 0, selectorList.Hwnd)
        if (sel >= 0 && sel < selectorDisplayedOptions.Length)
            itemIndex := sel
    }
    if (itemIndex < 0)
        return
    selectorPressedIndex := itemIndex
    selectorPressColorCurrent := "4A4A4A"
    selectorPressColorFrom := "4A4A4A"
    selectorPressColorTo := "5C5C5C"
    selectorPressStartedAt := A_TickCount
    selectorPressPhase := "press"
    SetTimer(UpdateSelectorPressAnimation, 16)
    MarqueeFrameAlign()
    if (IsWindowValid(selectorList))
        RepaintSelectorList()
}

EndDropdownItemPress() {
    global selectorPressedIndex, selectorPressColorCurrent, selectorPressColorFrom, selectorPressColorTo
    global selectorPressStartedAt, selectorPressPhase, selectorList
    if (selectorPressedIndex < 0 || selectorPressPhase = "idle")
        return
    selectorPressColorFrom := selectorPressColorCurrent
    selectorPressColorTo := "3A3A3A"
    selectorPressStartedAt := A_TickCount
    selectorPressPhase := "release"
    SetTimer(UpdateSelectorPressAnimation, 16)
    MarqueeFrameAlign()
    if (IsWindowValid(selectorList))
        RepaintSelectorList()
}

UpdateSelectorPressAnimation(*) {
    global selectorList, selectorPressedIndex, selectorPressColorCurrent, selectorPressColorFrom
    global selectorPressColorTo, selectorPressStartedAt, selectorPressDuration, selectorPressPhase
    if (selectorPressPhase = "idle")
        return
    progress := Min(1.0, (A_TickCount - selectorPressStartedAt) / selectorPressDuration)
    eased := progress * progress * (3 - 2 * progress)
    selectorPressColorCurrent := BlendHexColor(selectorPressColorFrom, selectorPressColorTo, eased)
    MarqueeFrameAlign()
    if (IsWindowValid(selectorList))
        RepaintSelectorList()
    if (progress >= 1.0) {
        selectorPressColorCurrent := selectorPressColorTo
        if (selectorPressPhase = "press")
            selectorPressPhase := "held"
        else {
            selectorPressPhase := "idle"
            selectorPressedIndex := -1
        }
        SetTimer(UpdateSelectorPressAnimation, 0)
        if (IsWindowValid(selectorList))
            RepaintSelectorList()
    }
}

BlurGameSearchOnOutsideClick(*) {
    global mainGui, frameGui, selectGui, actionGui, processSelect, selectorFrameGui, selectorPopup, selectorList, isGameSearchFocused
    if ((!isGameSearchFocused && !IsProcessSelectorOpen()) || !IsWindowValid(processSelect))
        return

    MouseGetPos(&mouseX, &mouseY, &windowUnderCursor, &hoveredControl, 2)
    
    clickOnSearchEdit := (hoveredControl = processSelect.Hwnd)
    WinGetPos(&selectX, &selectY, &selectW, &selectH, "ahk_id " selectGui.Hwnd)
    clickInsideSelectorContainer := mouseX >= selectX && mouseX < selectX + selectW && mouseY >= selectY && mouseY < selectY + selectH
    
    clickOnDropdownWindow := false
    if (IsProcessSelectorOpen()) {
        for hwndTarget in [selectorFrameGui.Hwnd, IsWindowValid(selectorPopup) ? selectorPopup.Hwnd : 0, IsWindowValid(selectorList) ? selectorList.Hwnd : 0] {
            if (hwndTarget && (windowUnderCursor = hwndTarget || hoveredControl = hwndTarget)) {
                clickOnDropdownWindow := true
                break
            }
        }
        if (!clickOnDropdownWindow && hwndTarget := selectorFrameGui.Hwnd) {
            rect := Buffer(16, 0)
            if (DllCall("User32\GetWindowRect", "Ptr", hwndTarget, "Ptr", rect, "Int")) {
                fX := NumGet(rect, 0, "Int"), fY := NumGet(rect, 4, "Int")
                fW := NumGet(rect, 8, "Int") - fX, fH := NumGet(rect, 12, "Int") - fY
                if (mouseX >= fX && mouseX < fX + fW && mouseY >= fY && mouseY < fY + fH)
                    clickOnDropdownWindow := true
            }
        }
    }
    
    if (clickOnSearchEdit || clickInsideSelectorContainer || clickOnDropdownWindow)
        return

    clickRoot := windowUnderCursor ? DllCall("User32\GetAncestor", "Ptr", windowUnderCursor, "UInt", 2, "Ptr") : 0
    clickInsideApp := clickRoot = mainGui.Hwnd
    CloseProcessSelector()
    if (isGameSearchFocused && clickInsideApp) {
        isGameSearchFocused := false
        DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
    }
}

IsMyGuiActive() {
    global mainGui, frameGui, selectGui, actionGui, selectorFrameGui, selectorPopup, isExiting
    if ((IsSet(isExiting) && isExiting) || !IsSet(mainGui) || !mainGui)
        return false
    if (IsContextMenuOpen())
        return false
    curr := WinExist("A")
    return (curr = mainGui.Hwnd || curr = frameGui.Hwnd || curr = selectGui.Hwnd || curr = actionGui.Hwnd || (IsWindowValid(selectorFrameGui) && curr = selectorFrameGui.Hwnd) || (IsWindowValid(selectorPopup) && curr = selectorPopup.Hwnd))
}

OnSetCursor(wParam, lParam, msg, hwnd) {
    global minBtn, closeBtn, titleBar, refreshButton, processSelect, selectorList, selectorHoveredIndex, actionBtn, actionGui, mainGui, isExiting, refreshIsLocked
    global selectorPopup, selectorScrollUpBtn, selectorScrollDownBtn, selectorScrollThumb, selectorScrollThumbTrack, selectorScrollSeparator, selectorDisplayedOptions
    if (RiskDialogCursor(hwnd))
        return true
    if (isSearchMenuOpen) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32512, "Ptr"))
        return true
    }
    if (isExiting || !IsSet(mainGui) || !mainGui || !IsOwnGuiWindow(hwnd) || IsContextMenuOpen())
        return

    MouseGetPos(,,, &hovered, 2)
    if (IsWindowValid(processSelect) && hovered = processSelect.Hwnd) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32513, "Ptr"))
        return true
    }
    global updateBtn
    if (IsWindowValid(updateBtn) && hovered = updateBtn.Hwnd) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", UpdateBtnClickable() ? 32649 : 32648, "Ptr"))   ; hand / "not allowed" while frozen
        return true
    }
    if (IsWindowValid(refreshButton) && hovered = refreshButton.Hwnd) {
        ; Refreshing (locked): the "not allowed" cursor (IDC_NO, 32648). Finished: back to the hand (IDC_HAND, 32649).
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", (refreshIsLocked || RefreshDisabled()) ? 32648 : 32649, "Ptr"))
        return true
    }
    if (IsWindowValid(selectorPopup) && selectorDisplayedOptions.Length > 3) {
        if ((IsWindowValid(selectorScrollUpBtn) && hovered = selectorScrollUpBtn.Hwnd)
            || (IsWindowValid(selectorScrollDownBtn) && hovered = selectorScrollDownBtn.Hwnd)
            || (IsWindowValid(selectorScrollThumb) && hovered = selectorScrollThumb.Hwnd)
            || (IsWindowValid(selectorScrollThumbTrack) && hovered = selectorScrollThumbTrack.Hwnd)
            || (IsWindowValid(selectorScrollSeparator) && hovered = selectorScrollSeparator.Hwnd)) {
            cursorId := (hovered = selectorScrollThumb.Hwnd || hovered = selectorScrollThumbTrack.Hwnd) ? 32512 : 32649
            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", cursorId, "Ptr"))
            return true
        }
    }
    if (IsWindowValid(selectorList) && (hwnd = selectorList.Hwnd || hovered = selectorList.Hwnd || hovered = selectorPopup.Hwnd)) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32649, "Ptr"))
        return true
    }
    if (connLost && (hovered = actionBtn.Hwnd || hovered = actionGui.Hwnd)) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32648, "Ptr"))   ; frozen while the connection is lost
        return true
    }
    if (hovered = minBtn.Hwnd || hovered = closeBtn.Hwnd || hovered = actionBtn.Hwnd || hovered = actionGui.Hwnd) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32649, "Ptr"))
        return true
    }

    DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32512, "Ptr"))
    return true
}

GetRefreshBgBrush(hex) {
    global refreshBgBrushes
    if (!refreshBgBrushes.Has(hex))
        refreshBgBrushes[hex] := DllCall("Gdi32\CreateSolidBrush", "UInt", HexToColorRef(hex), "Ptr")
    return refreshBgBrushes[hex]
}

WmCtlColorStatic(wParam, lParam, msg, hwnd) {
    global appName, appTagline, statusText, statusDot, isExiting, refreshSeparator, versionText, titleBar
    global selectorPopup, selectorScrollUpBtn, selectorScrollDownBtn, selectorScrollThumb, selectorScrollThumbTrack, selectorScrollSeparator, selectorScrollHoverTarget, searchEditBrush, scrollHoverBrush, selectorDisplayedOptions
    global refreshButton, refreshIsLocked, refreshLockedBrush, selectorRowSep1, selectorRowSep2, refreshButtonBgCurrent
    if (isExiting || !IsSet(mainGui) || !mainGui)
        return
    if (IsWindowValid(refreshButton) && (hwnd = refreshButton.Hwnd || lParam = refreshButton.Hwnd)) {
        ; Whatever the system pre-fills the button with must be the colour the icon is about to be drawn on
        ; (locked grey while refreshing, hover/normal colours otherwise), so no frame can show a different colour.
        bgHex := refreshIsLocked ? "555555" : (RefreshDisabled() ? "2E2E2E" : refreshButtonBgCurrent)
        DllCall("Gdi32\SetBkColor", "Ptr", wParam, "UInt", HexToColorRef(bgHex))
        DllCall("Gdi32\SetBkMode", "Ptr", wParam, "Int", 2)
        return GetRefreshBgBrush(bgHex)
    }
    if ((IsWindowValid(selectorRowSep1) && (hwnd = selectorRowSep1.Hwnd || lParam = selectorRowSep1.Hwnd))
        || (IsWindowValid(selectorRowSep2) && (hwnd = selectorRowSep2.Hwnd || lParam = selectorRowSep2.Hwnd))) {
        DllCall("Gdi32\SetBkColor", "Ptr", wParam, "UInt", 0x00FFFFFF)
        return DllCall("Gdi32\GetStockObject", "Int", 0, "Ptr")
    }
    if (IsWindowValid(selectorPopup) && selectorDisplayedOptions.Length > 3) {
        if (IsWindowValid(selectorScrollThumb) && hwnd = selectorScrollThumb.Hwnd) {
            thumbColor := (selectorScrollHoverTarget = "thumb" || selectorScrollHoverTarget = "track") ? 0x00DADADA : 0x00FFFFFF
            DllCall("Gdi32\SetBkColor", "Ptr", wParam, "UInt", thumbColor)
            return (selectorScrollHoverTarget = "thumb" || selectorScrollHoverTarget = "track") ? scrollHoverBrush : DllCall("Gdi32\GetStockObject", "Int", 0, "Ptr")
        }
        if (IsWindowValid(selectorScrollThumbTrack) && hwnd = selectorScrollThumbTrack.Hwnd) {
            isHovered := (selectorScrollHoverTarget = "track" || selectorScrollHoverTarget = "thumb")
            DllCall("Gdi32\SetTextColor", "Ptr", wParam, "UInt", 0x00FFFFFF)
            DllCall("Gdi32\SetBkColor", "Ptr", wParam, "UInt", isHovered ? 0x00303030 : 0x00000000)
            return isHovered ? scrollHoverBrush : searchEditBrush
        }
        if (IsWindowValid(selectorScrollSeparator) && hwnd = selectorScrollSeparator.Hwnd) {
            DllCall("Gdi32\SetBkColor", "Ptr", wParam, "UInt", 0x00FFFFFF)
            return DllCall("Gdi32\GetStockObject", "Int", 0, "Ptr")
        }
    }
    if (IsWindowValid(refreshSeparator) && hwnd = refreshSeparator.Hwnd) {
        DllCall("Gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
        return DllCall("Gdi32\GetStockObject", "Ptr", 0)
    }
    global updateBtn, updateSep
    if (IsSet(updateBtn) && IsObject(updateBtn) && IsSet(updateSep) && IsObject(updateSep) && (hwnd = updateBtn.Hwnd || hwnd = updateSep.Hwnd)) {
        DllCall("Gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
        DllCall("Gdi32\SetTextColor", "Ptr", wParam, "UInt", (hwnd = updateBtn.Hwnd) ? HexToColorRef(UpdateBtnTextHex()) : 0x00707070)
        return DllCall("Gdi32\GetStockObject", "Int", 5)
    }
    if (hwnd = appName.Hwnd || hwnd = appTagline.Hwnd || hwnd = statusText.Hwnd || hwnd = statusDot.Hwnd || hwnd = versionText.Hwnd || hwnd = titleBar.Hwnd) {
        DllCall("Gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
        DllCall("Gdi32\SetTextColor", "Ptr", wParam, "UInt", 0x00A0A0A0)
        return DllCall("Gdi32\GetStockObject", "Int", 5)
    }
}

WmCtlColorEdit(wParam, lParam, msg, hwnd) {
    global selectGui, searchEditBrush
    if (!IsSet(selectGui) || !IsObject(selectGui) || hwnd != selectGui.Hwnd)
        return
    DllCall("Gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xFFFFFF)
    DllCall("Gdi32\SetBkColor", "Ptr", wParam, "UInt", 0x00000000)
    DllCall("Gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
    return searchEditBrush
}

WmCtlColorListBox(wParam, lParam, msg, hwnd) {
    global selectorList, searchEditBrush
    if (!IsWindowValid(selectorList) || hwnd != selectorList.Hwnd)
        return
    DllCall("Gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xFFFFFF)
    DllCall("Gdi32\SetBkColor", "Ptr", wParam, "UInt", 0x00000000)
    DllCall("Gdi32\SetBkMode", "Ptr", wParam, "Int", 2)
    return searchEditBrush
}

OnWmKeyDown(wParam, lParam, msg, hwnd) {
    global selectorList, isExiting
    if (isExiting || !IsWindowValid(selectorList) || hwnd != selectorList.Hwnd)
        return
    if (wParam = 38 || wParam = 40 || wParam = 33 || wParam = 34)
        return
    return 0
}

; Ascent (baseline distance from the top of the text) and line height of a font, in pixels (used to put two different
; fonts on the same baseline).
GetFontAscentH(fontName, pointSize, weight, &ascent, &height) {
    hdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(pointSize * DllCall("Gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 90) / 72), "Int", 0, "Int", 0, "Int", 0, "Int", weight, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", fontName, "Ptr")
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
    tm := Buffer(80, 0)
    DllCall("Gdi32\GetTextMetricsW", "Ptr", hdc, "Ptr", tm)
    height := NumGet(tm, 0, "Int"), ascent := NumGet(tm, 4, "Int")
    DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)
    DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
}

GetTextWidth(text, fontName, pointSize, weight := 400) {
    hdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
    if !hdc
        return 0
    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(pointSize * DllCall("Gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 90) / 72), "Int", 0, "Int", 0, "Int", 0, "Int", weight, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", fontName, "Ptr")
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
    size := Buffer(8, 0)
    DllCall("Gdi32\GetTextExtentPoint32W", "Ptr", hdc, "Str", text, "Int", StrLen(text), "Ptr", size)
    DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)
    DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return NumGet(size, 0, "Int")
}

; Status dot X and status text X are two separate values (statusDotX / statusTextX). Only the text's glyph-width term is font metrics.
GetStatusDotX(mainWidth) {
    global statusDotX
    return statusDotX
}

GetStatusTextX(mainWidth) {
    global statusTextX
    static glyphW := 0
    if (!glyphW)
        glyphW := GetTextWidth("● ", "Segoe UI Semibold", 12)
    return statusTextX + glyphW
}

SetStatus(text, type := "ready") {
    global mainGui, statusText, statusDot, statusMarqueeGui, statusMarqueeText
    global marqueeIndex, marqueeTimerRunning, currentStatusRaw, currentStatusColor
    global dotBlinkTimerRunning, currentStatusTextOnly, isMarqueeActive, dotBlinkStep, isExiting
    global marqueeCycleWidth, marqueeTrackWidth, marqueeOffset, marqueeLastTick, marqueePauseUntil
    global marqueeViewportNeedsShow, marqueeRenderedX, marqueeTrackText, marqueeStripDirty, marqueeFrames
    global marqueeCycleText, marqueeRenderedPhase
    if (isExiting || !IsSet(mainGui) || !mainGui)
        return

    ; CONNECTION LOCK: while the connection is lost only the connection messages (the locked lost message, or a "restored" one) may be shown.
    if (ConnStatusBlocked(text))
        return

    if (riskViewActive) {
        DeferRiskStatus(text, type)
        return
    }

    Critical("On")

    if (type = "error")
        currentStatusColor := "E50914"
    else if (type = "running")
        currentStatusColor := "3A86FF"
    else if (type = "stopped")
        currentStatusColor := "F2A900"
    else
        currentStatusColor := "208A4E"

    currentStatusTextOnly := text
    currentStatusRaw := "● " text
    marqueeIndex := 1

    if marqueeTimerRunning {
        ; (shared frame timer keeps running; UpdateMarquee exits early when inactive)
        marqueeTimerRunning := false
    }

    textWidth := GetTextWidth(currentStatusRaw, "Segoe UI Semibold", 12)

    if (textWidth > 468) {
        isMarqueeActive := true
        dotBlinkStep := 0
        if (!dotBlinkTimerRunning) {
            SetTimer(UpdateDotBlink, 80)
            dotBlinkTimerRunning := true
        }

        marqueeCycle := currentStatusTextOnly . "     ●     "
        marqueeCycleWidth := GetTextWidth(marqueeCycle, "Segoe UI Semibold", 12)
        marqueeTrack := marqueeCycle . marqueeCycle . marqueeCycle . marqueeCycle
        marqueeTrackWidth := GetTextWidth(marqueeTrack, "Segoe UI Semibold", 12)
        marqueeTrackText := marqueeTrack
        marqueeCycleText := marqueeCycle         ; one cycle: the smooth strip draws it 4 times at exact cycle-width spacing

        ; START-PRESS SHIMMER FIX: the new state is made COMPLETE and CONSISTENT before any window is touched. The old order
        ; (SetFont / dot / Hide / Move first, strip rebuilt later) let every one of those calls trigger an immediate repaint of
        ; the layered + composited main window, and that repaint re-printed the status line from a half-swapped state (new
        ; colour / new text with the old scroll position or a strip being rebuilt) = a one-frame flash of the moving text.
        ; Now: reset the scroll position, render the new strip off-screen, THEN touch the windows. Any repaint that happens
        ; from here on already finds the finished strip at its start position.
        marqueeOffset := 0.0
        marqueeFrames := 0
        marqueeRenderedX := -2147483648
        marqueeRenderedPhase := 0
        marqueeLastTick := FrameStamp()
        marqueePauseUntil := NowMs() + MarqueePauseMs()
        PrebuildStatusMarqueeStrip()

        SetStatusDotBase(currentStatusColor)
        ; (no statusMarqueeText.SetFont here: the control is owner-drawn and takes its colour from the strip, and SetFont made
        ;  Windows repaint it at once = one more re-print of the whole window tree)
        ; (no statusDot.Value := "●" either: it already holds that glyph, and re-setting it repaints immediately)

        PositionStatusControls()                 ; shows / moves the marquee and paints it directly (new strip, start position)
        statusText.Opt("+Hidden")                ; only now: the plain text goes away AFTER the marquee has its first frame, so there is no blank frame
        if (!marqueeTimerRunning) {
            SetTimer(MarqueeMaster, 8)
            marqueeTimerRunning := true
        }
    } else {
        isMarqueeActive := false
        statusMarqueeGui.Hide()
        marqueeViewportNeedsShow := true
        statusText.Opt("-Hidden")
        marqueeCycleWidth := 0
        marqueeTrackWidth := 0
        marqueeOffset := 0.0
        if marqueeTimerRunning {
            ; (shared frame timer keeps running; UpdateMarquee exits early when inactive)
            marqueeTimerRunning := false
        }
        SetStatusDotBase(currentStatusColor)
        statusText.SetFont("s12 Norm c" currentStatusColor, "Segoe UI Semibold")
        statusDot.Value := "●"
        statusText.Value := currentStatusTextOnly
        PositionStatusControls()

        dotBlinkStep := 0
        if (!dotBlinkTimerRunning) {
            SetTimer(UpdateDotBlink, 80)
            dotBlinkTimerRunning := true
        }
    }
    Critical("Off")
}

UpdateDotBlink() {
    global statusDot, dotBlinkStep, currentStatusColor, isMarqueeActive, isExiting, dotPaintHex
    if (isExiting || !IsSet(mainGui) || !mainGui)
        return

    switch currentStatusColor {
        case "E50914": toneList := ["cE50914", "cC90812", "cAD0710", "c92060D", "c76050B", "c5A0408", "c3F0306", "c5A0408", "c76050B", "c92060D", "cAD0710", "cC90812"]
        case "3A86FF": toneList := ["c3A86FF", "c3476E3", "c2E65C6", "c2954AA", "c23438E", "c1D3272", "c182255", "c1D3272", "c23438E", "c2954AA", "c2E65C6", "c3476E3"]
        case "F2A900": toneList := ["cF2A900", "cD79500", "cBD8200", "cA36F00", "c895C00", "c6F4900", "c553600", "c6F4900", "c895C00", "cA36F00", "cBD8200", "cD79500"]
        default: toneList := ["c208A4E", "c1C7B45", "c186B3C", "c145C33", "c104D2A", "c0C3E21", "c082F18", "c0C3E21", "c104D2A", "c145C33", "c186B3C", "c1C7B45"]
    }

    toneIndex := Mod(dotBlinkStep, toneList.Length) + 1
    ; BLINK-HITCH FIX: SetFont made Windows re-print the whole (layered + composited) window tree every 80 ms, which cost
    ; several ms on the one script thread and made the scrolling status line / popup fade skip a refresh 12 times a second.
    ; The dot now paints only its own 16 x 42 pixels (one BitBlt). SetFont stays as the fallback when it cannot be painted
    ; directly (hidden / minimised), so AHK's stored colour keeps following the blink.
    dotPaintHex := SubStr(toneList[toneIndex], 2)
    if (!PaintControlDirect(statusDot, DrawStatusDot))
        statusDot.SetFont("s12 Norm " toneList[toneIndex], "Segoe UI Semibold")
    dotBlinkStep++
    UpdateWarnSignBlink(toneIndex)     ; the warning sign takes exactly the same step as the dot
}

; Base colour of the status dot (set whenever the status changes); the blink then steps through the tones from there.
SetStatusDotBase(hex) {
    global statusDot, dotPaintHex
    dotPaintHex := hex
    ; The dot is owner-drawn from dotPaintHex (DrawStatusDot), so its colour is painted straight onto its own pixels.
    ; SetFont repainted it through the layered + composited window = a re-print of the whole tree (status line included).
    ; SetFont stays as the fallback for when it cannot be painted directly (hidden / minimised).
    if (!PaintControlDirect(statusDot, DrawStatusDot))
        statusDot.SetFont("s12 Norm c" hex, "Segoe UI Semibold")
}

; Renders the strip of the CURRENT status text off-screen, before any window is touched (see SetStatus).
PrebuildStatusMarqueeStrip() {
    global statusMarqueeText, marqueeStripDirty, marqueeStripH
    if (!IsWindowValid(statusMarqueeText))
        return
    hdc := DllCall("User32\GetDC", "Ptr", statusMarqueeText.Hwnd, "Ptr")
    if (!hdc) {
        marqueeStripDirty := true            ; could not prebuild: DrawStatusMarquee builds it on the first paint, as before
        return
    }
    BuildStatusMarqueeStrip(hdc, 42)         ; 42 = statusHeight (the marquee control's height)
    DllCall("User32\ReleaseDC", "Ptr", statusMarqueeText.Hwnd, "Ptr", hdc)
}

; Owner-draw routine of the status dot: the whole 16 x 42 area is composed off-screen and copied once (no erase, no flash).
DrawStatusDot(drawItemStruct) {
    global statusDot, dotPaintHex, currentStatusColor
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    targetHdc := NumGet(drawItemStruct, itemHwndOffset + A_PtrSize, "Ptr")
    rectOffset := itemHwndOffset + A_PtrSize * 2
    left := NumGet(drawItemStruct, rectOffset, "Int")
    top := NumGet(drawItemStruct, rectOffset + 4, "Int")
    width := NumGet(drawItemStruct, rectOffset + 8, "Int") - left
    height := NumGet(drawItemStruct, rectOffset + 12, "Int") - top
    if (width <= 0 || height <= 0 || !targetHdc)
        return 1
    memoryDc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", targetHdc, "Ptr")
    if (!memoryDc)
        return 1
    bitmap := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", targetHdc, "Int", width, "Int", height, "Ptr")
    if (!bitmap) {
        DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
        return 1
    }
    oldBitmap := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", bitmap, "Ptr")
    localRect := Buffer(16, 0)
    NumPut("Int", width, localRect, 8)
    NumPut("Int", height, localRect, 12)
    brush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00000000, "Ptr")
    DllCall("User32\FillRect", "Ptr", memoryDc, "Ptr", localRect, "Ptr", brush)
    DllCall("Gdi32\DeleteObject", "Ptr", brush)
    hFont := 0
    try hFont := SendMessage(0x31, 0, 0, statusDot.Hwnd)     ; WM_GETFONT: the very font the control already uses
    oldFont := hFont ? DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", hFont, "Ptr") : 0
    DllCall("Gdi32\SetBkMode", "Ptr", memoryDc, "Int", 1)
    DllCall("Gdi32\SetTextColor", "Ptr", memoryDc, "UInt", HexToColorRef((dotPaintHex != "") ? dotPaintHex : currentStatusColor))
    ; DT_LEFT | DT_SINGLELINE | DT_VCENTER | DT_NOCLIP | DT_NOPREFIX (what a static with SS_CENTERIMAGE draws)
    DllCall("User32\DrawTextW", "Ptr", memoryDc, "Str", "●", "Int", -1, "Ptr", localRect, "UInt", 0x00000924)
    if (oldFont)
        DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBitmap, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", bitmap)
    DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
    return 1
}

PositionStatusControls() {
    global mainGui, statusDot, statusText, statusMarqueeGui, statusMarqueeText, statusFadeShown
    if (statusFadeShown)
        return                               ; the overlay carries the line during a fade; the real control comes back afterwards
    global currentStatusTextOnly, isExiting, isWindowVisible
    global isMarqueeActive, marqueeBaseX, marqueeBaseY, marqueeCycleWidth, marqueeTrackWidth, marqueeOffset
    global marqueeViewportX, marqueeViewportY, marqueeViewportW, marqueeViewportH, marqueeViewportNeedsShow, marqueeRenderedX
    global marqueeStripPhases, marqueeRenderedPhase, statusRightPad, mainStatusY
    if (isExiting || !isWindowVisible || !IsSet(mainGui) || !mainGui)
        return
    try {
        WinGetPos(,, &mainWidth, &mainHeight, "ahk_id " mainGui.Hwnd)
    } catch {
        return
    }
    if (riskViewActive)
        return

    statusWidth := 468
    statusHeight := 42

    statusY := mainStatusY                                                   ; its own value (no longer computed from the window height)

    dotY := statusY
    dotX := GetStatusDotX(mainWidth)

    static dotWidthCache := 0
    if (!dotWidthCache)
        dotWidthCache := GetTextWidth("●", "Segoe UI Semibold", 12)
    dotWidth := dotWidthCache

    ; Move() repaints the control at once even when nothing changes, which re-prints the composited window tree
    ; (status line included): only move the dot when its geometry really differs.
    statusDot.GetPos(&curDotX, &curDotY, &curDotW, &curDotH)
    if (curDotX != dotX || curDotY != dotY || curDotW != dotWidth || curDotH != statusHeight)
        statusDot.Move(dotX, dotY, dotWidth, statusHeight)

    textX := GetStatusTextX(mainWidth)
    if (isMarqueeActive) {
        marqueeBaseX := textX
        marqueeBaseY := statusY
        ; Right padding of the moving text = left padding before the status row.
        ; Left padding = dotX + the dot glyph's ~1px left bearing (measured: ink starts 26px from the window edge).
        ; The visible window is 1px narrower than mainWidth (rounded-corner region drops the last column), so the
        ; right edge is measured from mainWidth - 1. Only the viewport's right edge moves; textX is unchanged.
        dotGlyphBearing := Round(A_ScreenDPI / 96)
        viewportWidth := Max(1, mainWidth - 1 - textX - statusRightPad - dotGlyphBearing)
        if (marqueeViewportNeedsShow || !DllCall("User32\IsWindowVisible", "Ptr", statusMarqueeGui.Hwnd, "Int")) {
            statusMarqueeGui.Show(Format("NA x{} y{} w{} h{}", textX, statusY, viewportWidth, statusHeight))
            marqueeViewportNeedsShow := false
        } else if (marqueeViewportX !== textX || marqueeViewportY !== statusY || marqueeViewportW !== viewportWidth || marqueeViewportH !== statusHeight) {
            statusMarqueeGui.Move(textX, statusY, viewportWidth, statusHeight)
        }
        if (marqueeViewportW !== viewportWidth || marqueeViewportH !== statusHeight)
            statusMarqueeText.Move(0, 0, viewportWidth, statusHeight)
        marqueeViewportX := textX, marqueeViewportY := statusY, marqueeViewportW := viewportWidth, marqueeViewportH := statusHeight
        kq := Max(1, marqueeStripPhases)
        qq := Floor(marqueeOffset * kq + 0.000001)
        marqueeRenderedX := -(qq // kq)
        marqueeRenderedPhase := Mod(qq, kq)
        RepaintStatusMarquee()
    } else {
        msgWidth := GetTextWidth(currentStatusTextOnly, "Segoe UI Semibold", 12)
        statusText.GetPos(&curTxtX, &curTxtY, &curTxtW, &curTxtH)
        if (curTxtX != textX || curTxtY != statusY || curTxtW != msgWidth + 20 || curTxtH != statusHeight)
            statusText.Move(textX, statusY, msgWidth + 20, statusHeight)
    }
}

RepaintStatusMarquee() {
    global statusMarqueeText, riskViewActive, statusFadeShown
    if (riskViewActive)
        return                               ; hidden behind the warning: only the position advances
    if (statusFadeShown) {
        PaintStatusFadeOverlay()             ; during a fade the line lives in its own overlay window (see StatusFadeOverlayOn)
        return
    }
    ; Direct paint: only this control's own pixels are touched (no window-tree re-print); falls back to a normal repaint.
    if (PaintControlDirect(statusMarqueeText, DrawStatusMarquee))
        return
    if (IsWindowValid(statusMarqueeText)) {
        DllCall("User32\InvalidateRect", "Ptr", statusMarqueeText.Hwnd, "Ptr", 0, "Int", false)
        DllCall("User32\UpdateWindow", "Ptr", statusMarqueeText.Hwnd)
    }
}

; ---------------------------------------------------------------------------------------------
; Status line during the warning's fades. The main window is layered + composited, so repainting the status line inside it
; on every frame of a fade makes Windows re-print the whole window tree (stutter / flicker). Exactly like the refresh
; button's spin, the line therefore moves into a small stand-alone top-level window (colour-keyed: only the text is
; visible, at the same opacity as the fading window) for the duration of the fade; the real control is hidden meanwhile
; and put back, freshly painted, when the fade is over.
; ---------------------------------------------------------------------------------------------
StatusFadeOverlayOn(alpha) {
    global statusFadeOv, statusFadeCtl, statusFadeShown, statusMarqueeGui, isMarqueeActive, mainGui, isExiting
    if (statusFadeShown || isExiting || !isMarqueeActive || !IsWindowValid(statusMarqueeGui) || !IsWindowValid(mainGui))
        return
    if (!DllCall("User32\IsWindowVisible", "Ptr", statusMarqueeGui.Hwnd, "Int"))
        return
    try WinGetPos(&x, &y, &w, &h, "ahk_id " statusMarqueeGui.Hwnd)
    catch
        return
    if (w <= 0 || h <= 0)
        return
    if (!IsWindowValid(statusFadeOv)) {
        statusFadeOv := Gui("-Caption +ToolWindow +E0x08000000 +E0x80000 +Owner" mainGui.Hwnd, "")
        statusFadeOv.BackColor := "000000"
        statusFadeOv.MarginX := 0, statusFadeOv.MarginY := 0
        statusFadeCtl := statusFadeOv.Add("Text", Format("x0 y0 w{} h{} +0x000D", w, h), "")
        RemoveNativeOutline(statusFadeOv.Hwnd)
        RemoveNativeOutline(statusFadeCtl.Hwnd)
    }
    statusFadeCtl.Move(0, 0, w, h)
    ; LWA_COLORKEY | LWA_ALPHA: black (the line's background) is see-through, the text has the window's current opacity
    DllCall("User32\SetLayeredWindowAttributes", "Ptr", statusFadeOv.Hwnd, "UInt", 0, "UChar", alpha, "UInt", 3, "Int")
    statusFadeOv.Show(Format("NA x{} y{} w{} h{}", x, y, w, h))
    statusFadeShown := true
    PaintStatusFadeOverlay()
    statusMarqueeGui.Hide()                  ; the real control is hidden only AFTER the overlay shows the same text
}

; restore = true: put the real control back and repaint it BEFORE the overlay disappears (seamless hand-over).
StatusFadeOverlayOff(restore) {
    global statusFadeOv, statusFadeShown, statusMarqueeGui, isMarqueeActive, riskViewActive, isExiting
    if (!statusFadeShown)
        return
    statusFadeShown := false
    if (restore && !isExiting && !riskViewActive && isMarqueeActive && IsWindowValid(statusMarqueeGui)) {
        statusMarqueeGui.Show("NA")
        RepaintStatusMarquee()
    }
    if (IsWindowValid(statusFadeOv))
        statusFadeOv.Hide()
}

PaintStatusFadeOverlay() {
    global statusFadeCtl, statusFadeOv, statusFadeShown, isExiting
    if (isExiting || !statusFadeShown || !IsWindowValid(statusFadeCtl))
        return
    rc := Buffer(16, 0)
    if (!DllCall("User32\GetClientRect", "Ptr", statusFadeCtl.Hwnd, "Ptr", rc, "Int"))
        return
    hdc := DllCall("User32\GetDC", "Ptr", statusFadeCtl.Hwnd, "Ptr")
    if (!hdc)
        return
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    fake := Buffer(itemHwndOffset + A_PtrSize * 2 + 16 + A_PtrSize, 0)
    NumPut("Ptr", hdc, fake, itemHwndOffset + A_PtrSize)
    rectOffset := itemHwndOffset + A_PtrSize * 2
    NumPut("Int", 0, "Int", 0, "Int", NumGet(rc, 8, "Int"), "Int", NumGet(rc, 12, "Int"), fake, rectOffset)
    DrawStatusMarquee(fake)
    DllCall("User32\ReleaseDC", "Ptr", statusFadeCtl.Hwnd, "Ptr", hdc)
}

; High-resolution clock in milliseconds (A_TickCount only ticks every ~15.6 ms, which makes the movement judder).
InitMarqueeTiming() {
    ApplyMarqueeRefresh(GetMarqueeHz(0))
}

; Hold before every loop: the same for the status message and the dropdown titles.
MarqueePauseMs() {
    return 750
}

; EVERY step lasts exactly the same time (a whole number N of real screen refreshes), so there is no timing stutter at any
; refresh rate. One jump of marqueePxStep px (num = 1) every marqueeFrameStep refreshes (den = N)  ->  speed = Hz / N.
; Table (Hz -> N -> px/s):
;   30->1->30 | 48->2->24 | 50->2->25 | 60->2->30 | 72->2->36 | 75->2->37.5 | 90->3->30 | 100->3->33.3 | 120->4->30
;   144->4->36 | 165->5->33 | 180->5->36 | 200->5->40 | 240->6->40 | 280->7->40 | 300->8->37.5 | 360->9->40
;   480->12->40 | 500->12->41.7 | 540->13->41.5 | 600->14->42.9
; Fractional rates (59.94, 119.88, 143.98 ...) round to the nearest table entry and use the same N.
ChooseMarqueeStep(hz, &num, &den) {
    global marqueeTopSpeed, marqueeMinSpeed, marqueeCapSpeed, marqueeFloorSpeed, marqueeFloorLowSpeed, marqueeLowHz, marqueePeakHz
    static table := Map(30,1, 48,2, 50,2, 60,2, 72,2, 75,2, 90,3, 100,3, 120,4, 144,4, 165,5, 180,5
        , 200,5, 240,6, 280,7, 300,8, 360,9, 480,12, 500,12, 540,13, 600,14)
    num := 1, den := 2
    r := Round(hz)
    if (table.Has(r)) {
        den := table[r]
        return
    }
    ; Unlisted refresh rate: any whole N, speed closest to the target ramp (small preference for even N).
    t := Max(0.0, Min(1.0, (hz - marqueeLowHz) / (marqueePeakHz - marqueeLowHz)))
    target := marqueeMinSpeed + (marqueeTopSpeed - marqueeMinSpeed) * t
    floorSpeed := (hz >= 59.5) ? marqueeFloorSpeed : marqueeFloorLowSpeed
    bestErr := 1.0e9
    bestN := 0
    n := 1
    while (n <= 120) {
        speed := hz / n
        if (speed < floorSpeed - 0.000001)
            break
        if (speed <= marqueeCapSpeed + 0.001) {
            err := Abs(speed - target) + (Mod(n, 2) ? 0.7 : 0)
            if (err < bestErr - 0.001) {
                bestErr := err
                bestN := n
            }
        }
        n += 1
    }
    if (bestN)
        den := bestN
}

ApplyMarqueeRefresh(hz) {
    global marqueeRefreshHz, marqueeFrameStep, marqueePxStep
    global marqueeOffset, marqueeFrames, dropdownMarqueeOffset, dropdownMarqueeFrames, riskTitleOffset, riskTitleFrames
    global marqueeStripDirty, riskTitleStripDirty, dropdownStripDirty
    ChooseMarqueeStep(hz, &newPx, &newStep)
    marqueeRefreshHz := hz
    if (newStep != marqueeFrameStep || newPx != marqueePxStep) {
        ; keep the text exactly where it is when the rate changes (e.g. window dragged to another monitor)
        marqueeFrames := Integer(Round(marqueeOffset * newStep / newPx))
        dropdownMarqueeFrames := Integer(Round(dropdownMarqueeOffset * newStep / newPx))
        riskTitleFrames := Integer(Round(riskTitleOffset * newStep / newPx))
        marqueeFrameStep := newStep
        marqueePxStep := newPx
        marqueeStripDirty := true            ; the phase count depends on N: rebuild both strips for the new rate
        riskTitleStripDirty := true
        dropdownStripDirty := true
    }
}

; Refresh rate of the monitor the given window is on (0 = primary monitor).
GetMarqueeHz(hwnd) {
    hz := 0
    hMon := DllCall("User32\MonitorFromWindow", "Ptr", hwnd, "UInt", 1, "Ptr")
    mi := Buffer(104, 0)
    NumPut("UInt", 104, mi, 0)
    if (hMon && DllCall("User32\GetMonitorInfoW", "Ptr", hMon, "Ptr", mi, "Int")) {
        dm := Buffer(220, 0)
        NumPut("UShort", 220, dm, 68)
        if (DllCall("User32\EnumDisplaySettingsW", "Ptr", mi.Ptr + 40, "UInt", 0xFFFFFFFF, "Ptr", dm, "Int"))
            hz := NumGet(dm, 184, "UInt")
    }
    if (hz < 30 || hz > 600) {
        hdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
        hz := hdc ? DllCall("Gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 116, "Int") : 60
        if (hdc)
            DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    }
    hz := (hz < 30 || hz > 600) ? 60 : hz
    ; Use the exact rate (e.g. 59.94 instead of 60) when the compositor reports one that matches this monitor.
    info := Buffer(304, 0)
    NumPut("UInt", 304, info, 0)
    if (DllCall("Dwmapi\DwmGetCompositionTimingInfo", "Ptr", 0, "Ptr", info, "Int") = 0) {
        num := NumGet(info, 4, "UInt"), den := NumGet(info, 8, "UInt")
        if (den > 0 && Abs(num / den - hz) < 1.5)
            hz := num / den
    }
    return hz
}

; Reads the display compositor's own refresh counter (DWM_TIMING_INFO.cRefresh, offset 40 of the 304-byte struct).
; Returns 0 when it is unavailable (then the clock fallback below is used).
GetDwmRefreshCount() {
    static info := Buffer(304, 0), ok := true
    if (!ok)
        return 0
    NumPut("UInt", 304, info, 0)
    if (DllCall("Dwmapi\DwmGetCompositionTimingInfo", "Ptr", 0, "Ptr", info, "Int") != 0) {
        ok := false
        return 0
    }
    return NumGet(info, 40, "Int64")
}

; The "time" stamp the marquees keep: the real display refresh counter when available, else the high-res clock.
FrameStamp() {
    vc := GetDwmRefreshCount()
    return vc ? vc : NowMs()
}

; Shared motion step used by BOTH marquees. Counts REAL screen refreshes (the compositor's own counter), not clock
; guesses, so a 59.94/143.98 Hz display or a jittery timer can never make one jump a frame early or late. If the script
; was late and several refreshes went by, they are NOT caught up in one big jump (that is the visible hitch):
; at most ONE jump (marqueeFrameStep refreshes) is counted per call, so the text never moves more than 1 px at a time,
; while the speed stays correct even when the script is called less often than the display refreshes (144 Hz and up). Returns the new text offset in pixels, or -1 when no refresh has passed yet.
;
; fine = false (any marquee whose sub-pixel strip could not be built): whole-pixel stepping, one jump of marqueePxStep px every marqueeFrameStep refreshes.
; fine = true (status line, popup title, dropdown titles; they have sub-pixel strips): the text moves marqueePxStep / marqueeFrameStep px on EVERY
; refresh (same average speed, Hz / N px/s). A late call may catch up to two jumps' worth of refreshes: that is at most ~2 px of
; smooth motion, so the position stays true to the display clock instead of lagging behind after one late frame.
; Returns the new offset in px (a fraction when fine), or -1 when no refresh has passed yet.
MarqueeAdvance(&lastTick, &frames, now, fine := false) {
    global marqueeRefreshHz, marqueeFrameStep, marqueePxStep
    ; SHAKE FIX 1: smooth mode used to catch up to 2 whole pixels after a late frame (e.g. during the Start button press animation),
    ; which showed as a jerk. Now at most 2 refreshes' worth (2/N px) is caught up; the text may lag the display clock a little
    ; during a stall, but it never visibly jumps.
    cap := fine ? 2 : marqueeFrameStep
    vc := GetDwmRefreshCount()
    if (vc) {
        passed := vc - lastTick
        if (passed < 1)
            return -1
        lastTick := vc
        frames += Min(passed, cap)   ; count the real refreshes that passed (bounded, so a long stall can never cause a big jump)
    } else {
        passed := Round((now - lastTick) * marqueeRefreshHz / 1000)
        if (passed < 1)
            return -1
        lastTick := now                    ; resync instead of catching up
        frames += Min(passed, cap)
    }
    if (fine)
        return frames * marqueePxStep / marqueeFrameStep
    return (frames // marqueeFrameStep) * marqueePxStep      ; one jump of marqueePxStep px every marqueeFrameStep refreshes
}

; One frame driver for both marquees. While anything is actually moving it waits for the display's next refresh
; (DwmFlush) and then updates both, so frames are evenly spaced instead of following the jittery WM_TIMER clock.
MarqueeMaster() {
    global marqueeTimerRunning, isMarqueeActive, isExiting, marqueePauseUntil, dropdownMarqueeIndex, dropdownMarqueePauseUntil
    global riskViewActive, riskViewBusy, riskTitleActive, riskTitlePauseUntil, marqueeBudgetMs
    static busy := false
    ; While the warning is being shown / hidden (the window fades out and in inside a Sleep loop) this driver must NOT run:
    ; with a scrolling status line (long game name) its loop never ends, so it kept the fade's thread suspended and the
    ; window stayed half transparent (ghosted) for as long as the text scrolled.
    if (isExiting || busy || riskViewBusy)
        return
    busy := true
    try {
        ; The 8 ms timer can fire at most ~125 times a second, fewer than the refreshes of a 144 Hz+ display. So while
        ; something is moving this loop stays here and does ONE update per real refresh (DwmFlush paces it); Sleep(-1)
        ; lets clicks, hover and other timers run between frames. When nothing moves it returns to the timer.
        ;
        ; FREEZE FIX: AutoHotkey threads form a stack. This timer thread starts ON TOP of whatever thread it interrupted (the
        ; Sleep(8) of a button press animation, the Enter hotkey, the Continue / Start action ...). A thread underneath can only
        ; go on once everything above it has returned. With a scrolling title this loop used to stay here for the whole scroll
        ; (about 6-7 s for a long game name), so the interrupted button animation / click was frozen for exactly that long
        ; ("Start" and "Continue" dead, then suddenly working again). The loop now has a short time budget: it serves one or
        ; two display refreshes and returns, so every thread below it continues immediately. The timer calls it again at once,
        ; and the frame pacing (DwmFlush + refresh counting) is unchanged.
        loopStart := 0
        Loop {
            if (riskViewBusy)
                break
            now := NowMs()
            ; The status line and the dropdown are hidden while the warning is open, so they do not drive frames then.
            statusMoving := (marqueeTimerRunning && isMarqueeActive && now >= marqueePauseUntil)
            dropdownMoving := (!riskViewActive && dropdownMarqueeIndex != -1 && now >= dropdownMarqueePauseUntil)
            riskTitleMoving := (riskViewActive && riskTitleActive && now >= riskTitlePauseUntil)
            moving := (statusMoving || dropdownMoving || riskTitleMoving)
            if (moving) {
                if (DllCall("Dwmapi\DwmFlush", "Int") != 0)
                    Sleep(1)
                if (!loopStart)
                    loopStart := NowMs()         ; budget starts AFTER the first refresh wait
            }
            UpdateMarquee()                      ; the status line keeps advancing even while the warning is shown / fading
            if (!riskViewActive)
                UpdateDropdownMarquee()
            UpdateRiskTitleMarquee()
            if (isExiting || !moving)
                break
            Sleep(-1)
            if (isExiting)
                break
            if (loopStart && NowMs() - loopStart >= marqueeBudgetMs) {    ; time budget used up: give the threads underneath their turn
                ; Still moving: ask to be called again ASAP (a separate one-shot timer; the 8 ms periodic timer is untouched).
                ; Without this the next frame waited for the next 8 ms tick, which at 120 Hz+ (8.3 ms or less per refresh) could
                ; skip a whole refresh and make one step late and the next one early = visible stutter.
                ; A posted message wakes the script as soon as its message loop runs; a SetTimer(-1) waits for the 10-16 ms timer tick.
                if (!DllCall("User32\PostMessageW", "Ptr", A_ScriptHwnd, "UInt", 0x8001, "Ptr", 0, "Ptr", 0, "Int"))
                    SetTimer(MarqueeKick, -1)
                break
            }
        }
    } finally {
        busy := false
    }
}

MarqueeKick() {
    MarqueeMaster()
}

MarqueeKickMsg(wParam, lParam, msg, hwnd) {
    MarqueeMaster()
    return 0
}

; ONE motion step for ALL marquees (status line, popup title, dropdown titles). The three update routines used to repeat this
; logic; now they only check their own conditions, call this, and repaint when it returns 1.
;   hold                   the hold for the end of the track is `holdW` px: the text stops there until the cycle ends
;                          (dropdown + popup title). holdW < 0 = no hold, the text runs the whole cycle (status loop).
;   phases                 sub-pixel phases of the strip (1 = whole-pixel strip)
; Returns 1 when the drawn position (whole pixel or sub-pixel phase) changed and a repaint is needed, else 0.
MarqueeTick(&offset, &frames, &lastTick, &pauseUntil, &renderedX, &renderedPhase, cycleW, holdW, phases) {
    now := NowMs()
    if (now < pauseUntil) {
        lastTick := FrameStamp()
        return 0
    }
    newOffset := MarqueeAdvance(&lastTick, &frames, now, phases > 1)
    if (newOffset < 0)
        return 0
    offset := newOffset
    if (offset >= cycleW) {
        offset := 0
        frames := 0
        pauseUntil := now + MarqueePauseMs()
    }
    ; position in 1/k px: whole pixels -> source x, remainder -> which pre-rendered band to copy
    k := Max(1, phases)
    pos := (holdW >= 0) ? Min(offset, holdW) : offset
    q := Floor(pos * k + 0.000001)
    x := -(q // k)
    p := Mod(q, k)
    if (x = renderedX && p = renderedPhase)
        return 0
    renderedX := x
    renderedPhase := p
    return 1
}

FreeDropdownStrip() {
    global dropdownStripDc, dropdownStripBmp, dropdownStripOld
    if (dropdownStripDc) {
        DllCall("Gdi32\SelectObject", "Ptr", dropdownStripDc, "Ptr", dropdownStripOld, "Ptr")
        DllCall("Gdi32\DeleteObject", "Ptr", dropdownStripBmp)
        DllCall("Gdi32\DeleteDC", "Ptr", dropdownStripDc)
    }
    dropdownStripDc := 0, dropdownStripBmp := 0, dropdownStripOld := 0
}

; Dropdown title strip: the hovered title rendered ONCE at `phases` sub-pixel offsets (same BuildSubpixelBands as the status line
; and the popup title). The background is the row's highlight colour (3A3A3A), because the scrolling row is always highlighted;
; DrawSelectorItem only uses the strip when the row really is filled with that colour and otherwise falls back to the GDI text.
; If anything fails, dropdownStripPhases stays 1 = the old whole-pixel behaviour.
BuildDropdownStrip() {
    global selectorList, selectorRowHeight, dropdownMarqueeIndex, dropdownMarqueeTitle, dropdownMarqueeTextW
    global dropdownStripDc, dropdownStripBmp, dropdownStripOld, dropdownStripH, dropdownStripDirty, dropdownStripPhases, dropdownStripText
    global dropdownSmooth, dropdownSubpxYAdjust, gdiplusToken
    FreeDropdownStrip()
    dropdownStripDirty := false
    dropdownStripPhases := 1
    dropdownStripText := ""
    if (!dropdownSmooth || !gdiplusToken || dropdownMarqueeTitle = "" || dropdownMarqueeTextW <= 0 || !IsWindowValid(selectorList))
        return
    rowH := SendMessage(0x01A1, 0, 0, selectorList.Hwnd)              ; LB_GETITEMHEIGHT
    if (dropdownMarqueeIndex >= 0) {
        rc := Buffer(16, 0)
        if (SendMessage(0x0198, dropdownMarqueeIndex, rc.Ptr, selectorList.Hwnd) != -1)   ; LB_GETITEMRECT: the real row height
            rowH := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
    }
    if (rowH <= 4 || rowH > 200)
        rowH := selectorRowHeight
    refDc := DllCall("User32\GetDC", "Ptr", selectorList.Hwnd, "Ptr")
    if (!refDc)
        return
    listFont := SendMessage(0x0031, 0, 0, selectorList.Hwnd)          ; WM_GETFONT: exactly the font the rows are drawn with
    oldFont := listFont ? DllCall("Gdi32\SelectObject", "Ptr", refDc, "Ptr", listFont, "Ptr") : 0
    face := "Segoe UI", bold := false
    emPx := Round(12 * DllCall("Gdi32\GetDeviceCaps", "Ptr", refDc, "Int", 90) / 72)
    lf := Buffer(92, 0)                                              ; LOGFONTW
    if (listFont && DllCall("Gdi32\GetObjectW", "Ptr", listFont, "Int", 92, "Ptr", lf, "Int")) {
        h := NumGet(lf, 0, "Int")
        if (h != 0)
            emPx := Abs(h)
        bold := (NumGet(lf, 16, "Int") >= 600)
        f := StrGet(lf.Ptr + 28, 32, "UTF-16")
        if (f != "")
            face := f
    }
    GetFontCenterMetrics(refDc, &lineH, &capCenter)
    ; the same vertical position DrawSelectorItem gives the GDI text: textTop - rowTop = Floor((rowH - 1) / 2 - capCenter + 0.5) + textVCenterNudge
    yTop := Floor((rowH - 1) / 2 - capCenter + 0.5) + textVCenterNudge + dropdownSubpxYAdjust
    if (oldFont)
        DllCall("Gdi32\SelectObject", "Ptr", refDc, "Ptr", oldFont, "Ptr")

    stripW := Min(Max(dropdownMarqueeTextW + 64, 64), 30000)
    phases := MarqueeChoosePhases(stripW, rowH)
    ok := false
    if (phases > 1) {
        dc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", refDc, "Ptr")
        bmp := dc ? DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", refDc, "Int", stripW, "Int", rowH * phases, "Ptr") : 0
        if (dc && bmp) {
            oldBmp := DllCall("Gdi32\SelectObject", "Ptr", dc, "Ptr", bmp, "Ptr")
            fullRect := Buffer(16, 0)
            NumPut("Int", stripW, fullRect, 8)
            NumPut("Int", rowH * phases, fullRect, 12)
            brush := DllCall("Gdi32\CreateSolidBrush", "UInt", HexToColorRef("3A3A3A"), "Ptr")
            DllCall("User32\FillRect", "Ptr", dc, "Ptr", fullRect, "Ptr", brush)
            DllCall("Gdi32\DeleteObject", "Ptr", brush)
            ; one copy of the title, stretched to the GDI-measured width so the end-of-title stop lands on the same pixel as before
            ok := BuildSubpixelBands(dc, stripW, rowH, phases, dropdownMarqueeTitle, 1, 0, dropdownMarqueeTextW
                , face, emPx, bold, "FFFFFF", lineH, yTop)
            if (ok) {
                dropdownStripDc := dc, dropdownStripBmp := bmp, dropdownStripOld := oldBmp, dropdownStripH := rowH
                dropdownStripPhases := phases
                dropdownStripText := dropdownMarqueeTitle
            } else {
                DllCall("Gdi32\SelectObject", "Ptr", dc, "Ptr", oldBmp, "Ptr")
                DllCall("Gdi32\DeleteObject", "Ptr", bmp)
                DllCall("Gdi32\DeleteDC", "Ptr", dc)
            }
        } else {
            if (bmp)
                DllCall("Gdi32\DeleteObject", "Ptr", bmp)
            if (dc)
                DllCall("Gdi32\DeleteDC", "Ptr", dc)
        }
    }
    DllCall("User32\ReleaseDC", "Ptr", selectorList.Hwnd, "Ptr", refDc)
}

; Chooses how many sub-pixel phases a strip of this size can afford (each phase is one more copy of the strip in memory).
MarqueeChoosePhases(stripW, bandH) {
    global marqueeSubpxPhases, marqueeSubpixel, gdiplusToken, marqueeFrameStep
    if (!marqueeSubpixel || !gdiplusToken)
        return 1
    ; SMOOTHNESS FIX: the number of phases is a whole multiple of N (refreshes per pixel), so every refresh advances by EXACTLY
    ; the same whole number of phases. With a fixed 8 phases and N = 3, 5, 6, 7 ... the 1/N px step did not divide evenly:
    ; some refreshes moved 2 phases, some 1, some 0 (uneven speed = shake / stutter). Speed (Hz / N px/s) is unchanged.
    n := Max(1, Integer(marqueeFrameStep))
    m := Max(1, Round(Max(1, Integer(marqueeSubpxPhases)) / n))        ; phases moved per refresh (aim: about 8 phases per pixel)
    while (m >= 1) {
        k := n * m
        if (stripW * bandH * k * 4 <= 50331648)                        ; keep one strip under ~48 MB
            return (k >= 2) ? k : 1
        m -= 1
    }
    return 1                                                          ; strip too long: plain whole-pixel strip, as before
}

; Renders `copies` copies of `text` into a tall bitmap that already holds `phases` bands (each bandH rows high, filled black).
; Band i holds the text shifted LEFT by i/phases of a pixel, so the viewer can show any position in 1/phases px steps with one
; BitBlt. Copy c starts at copyStepPx * c (the same spacing the old whole-pixel strip used), and each copy is stretched by a
; hair (GDI+ vs GDI glyph advances differ by ~1 %) so its width equals targetWidthPx exactly: loops and end-of-title stops
; keep landing on the same pixels as before. Text origin sits 1 px to the right of the band's left edge (the viewer adds it back).
; Returns false when GDI+ cannot do it; the caller then falls back to the old GDI strip.
BuildSubpixelBands(dc, stripW, bandH, phases, text, copies, copyStepPx, targetWidthPx, fontName, emPx, bold, colorHex, tmHeight, yTopOverride := "") {
    global gdiplusToken, marqueeSubpxYAdjust, marqueeSubpxUsePath, marqueeSubpxGamma
    if (!gdiplusToken || phases < 2 || text = "" || !dc)
        return false
    g := 0, fam := 0, font := 0, fmt := 0, brush := 0, gpath := 0, ok := false
    try {
        if (DllCall("gdiplus\GdipCreateFromHDC", "Ptr", dc, "Ptr*", &g, "Int") != 0 || !g)
            throw Error("graphics")
        DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", g, "Int", 4, "Int")            ; AntiAlias: fractional glyph positions
        if (marqueeSubpxGamma)
            DllCall("gdiplus\GdipSetCompositingQuality", "Ptr", g, "Int", 3, "Int")       ; CompositingQualityGammaCorrected (see marqueeSubpxGamma)
        if (DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", fontName, "Ptr", 0, "Ptr*", &fam, "Int") != 0 || !fam) {
            fam := 0
            if (DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &fam, "Int") != 0 || !fam)
                throw Error("family")
        }
        if (DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", emPx + 0.0, "Int", bold ? 1 : 0, "Int", 2, "Ptr*", &font, "Int") != 0 || !font)
            throw Error("font")
        ; typographic format = no built-in side padding, so the text starts exactly at the layout origin
        gf := 0
        DllCall("gdiplus\GdipStringFormatGetGenericTypographic", "Ptr*", &gf, "Int")
        if (!gf || DllCall("gdiplus\GdipCloneStringFormat", "Ptr", gf, "Ptr*", &fmt, "Int") != 0 || !fmt)
            throw Error("format")
        fl := 0
        DllCall("gdiplus\GdipGetStringFormatFlags", "Ptr", fmt, "Int*", &fl, "Int")
        DllCall("gdiplus\GdipSetStringFormatFlags", "Ptr", fmt, "Int", fl | 0x1000 | 0x4000 | 0x800, "Int")   ; NoWrap | NoClip | MeasureTrailingSpaces
        argb := 0xFF000000 | Integer("0x" colorHex)
        if (DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &brush, "Int") != 0 || !brush)
            throw Error("brush")

        layout := Buffer(16, 0)
        bbox := Buffer(16, 0)
        NumPut("Float", 0.0, "Float", 0.0, "Float", 100000.0, "Float", bandH + 0.0, layout, 0)
        fitChars := 0, fitLines := 0
        sx := 1.0
        if (DllCall("gdiplus\GdipMeasureString", "Ptr", g, "WStr", text, "Int", -1, "Ptr", font, "Ptr", layout, "Ptr", fmt, "Ptr", bbox, "Int*", &fitChars, "Int*", &fitLines, "Int") = 0) {
            mw := NumGet(bbox, 8, "Float")
            if (mw > 1 && targetWidthPx > 1)
                sx := Max(0.9, Min(1.1, targetWidthPx / mw))
        }
        yTop := ((bandH - tmHeight) // 2) + marqueeSubpxYAdjust        ; same vertical centring the GDI DrawText (DT_VCENTER) used
        if (yTopOverride != "")
            yTop := yTopOverride                                       ; caller places the text itself (dropdown rows)
        usePath := false
        if (marqueeSubpxUsePath) {
            ; Text as an outline: the glyph shapes are anti-aliased at the exact fractional position, so every letter moves
            ; in perfect step with the others (DrawString may snap each glyph to a whole pixel separately).
            if (DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &gpath, "Int") = 0 && gpath) {
                NumPut("Float", 0.0, "Float", 0.0, "Float", 100000.0, "Float", bandH + 0.0, layout, 0)
                if (DllCall("gdiplus\GdipAddPathString", "Ptr", gpath, "WStr", text, "Int", -1, "Ptr", fam, "Int", bold ? 1 : 0, "Float", emPx + 0.0, "Ptr", layout, "Ptr", fmt, "Int") = 0) {
                    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4, "Int")     ; AntiAlias
                    usePath := true
                }
            }
        }

        Loop phases {
            i := A_Index - 1
            yBase := i * bandH
            DllCall("gdiplus\GdipResetWorldTransform", "Ptr", g, "Int")
            DllCall("gdiplus\GdipSetClipRectI", "Ptr", g, "Int", 0, "Int", yBase, "Int", stripW, "Int", bandH, "Int", 0, "Int")   ; a band never bleeds into the next
            Loop copies {
                c := A_Index - 1
                x0 := 1.0 + c * copyStepPx - i / phases
                DllCall("gdiplus\GdipResetWorldTransform", "Ptr", g, "Int")
                DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", g, "Float", x0, "Float", yBase + yTop + 0.0, "Int", 0, "Int")
                DllCall("gdiplus\GdipScaleWorldTransform", "Ptr", g, "Float", sx, "Float", 1.0, "Int", 0, "Int")
                if (usePath) {
                    DllCall("gdiplus\GdipFillPath", "Ptr", g, "Ptr", brush, "Ptr", gpath, "Int")
                } else {
                    NumPut("Float", 0.0, "Float", 0.0, "Float", 100000.0, "Float", bandH + 0.0, layout, 0)
                    DllCall("gdiplus\GdipDrawString", "Ptr", g, "WStr", text, "Int", -1, "Ptr", font, "Ptr", layout, "Ptr", fmt, "Ptr", brush, "Int")
                }
            }
        }
        DllCall("gdiplus\GdipFlush", "Ptr", g, "Int", 1, "Int")
        ok := true
    } catch {
        ok := false
    }
    if (gpath)
        DllCall("gdiplus\GdipDeletePath", "Ptr", gpath, "Int")
    if (brush)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush, "Int")
    if (fmt)
        DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", fmt, "Int")
    if (font)
        DllCall("gdiplus\GdipDeleteFont", "Ptr", font, "Int")
    if (fam)
        DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", fam, "Int")
    if (g)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g, "Int")
    return ok
}

; Paints an owner-drawn control straight onto its own DC (one BitBlt from the pre-rendered strip) WITHOUT invalidating anything.
; The main window is layered + WS_EX_COMPOSITED, so InvalidateRect/UpdateWindow on a child makes Windows re-print and re-compose
; the WHOLE window tree for every single marquee frame (the stutter and flicker); this touches only the control's own pixels.
; Same technique as PaintRefreshButtonDirect. Returns false when it could not paint (caller falls back to InvalidateRect).
PaintControlDirect(ctl, drawFunc) {
    if (!IsWindowValid(ctl))
        return false
    if (!DllCall("User32\IsWindowVisible", "Ptr", ctl.Hwnd, "Int"))
        return false
    rc := Buffer(16, 0)
    if (!DllCall("User32\GetClientRect", "Ptr", ctl.Hwnd, "Ptr", rc, "Int"))
        return false
    hdc := DllCall("User32\GetDC", "Ptr", ctl.Hwnd, "Ptr")
    if (!hdc)
        return false
    ; Minimal DRAWITEMSTRUCT: only the hDC and rcItem fields are read by the draw functions.
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    fake := Buffer(itemHwndOffset + A_PtrSize * 2 + 16 + A_PtrSize, 0)
    NumPut("Ptr", hdc, fake, itemHwndOffset + A_PtrSize)
    rectOffset := itemHwndOffset + A_PtrSize * 2
    NumPut("Int", 0, "Int", 0, "Int", NumGet(rc, 8, "Int"), "Int", NumGet(rc, 12, "Int"), fake, rectOffset)
    drawFunc(fake)
    DllCall("User32\ReleaseDC", "Ptr", ctl.Hwnd, "Ptr", hdc)
    DllCall("Gdi32\GdiFlush")               ; GDI batches drawing calls: flush now so the new Start / Stop state is on screen before any long work starts
    return true
}

DbgLog(msg) {
    global debugTiming
    if (!debugTiming)
        return
    try FileAppend(A_Hour ":" A_Min ":" A_Sec "." A_MSec "  " msg "`n", A_ScriptDir "\Ragnious_timing.log", "UTF-8")
}

NowMs() {
    static freq := 0
    if (!freq) {
        f := 0
        DllCall("QueryPerformanceFrequency", "Int64*", &f)
        freq := f / 1000.0
    }
    c := 0
    DllCall("QueryPerformanceCounter", "Int64*", &c)
    return c / freq
}

FreeStatusMarqueeStrip() {
    global marqueeStripDc, marqueeStripBmp, marqueeStripOld
    if (marqueeStripDc) {
        DllCall("Gdi32\SelectObject", "Ptr", marqueeStripDc, "Ptr", marqueeStripOld, "Ptr")
        DllCall("Gdi32\DeleteObject", "Ptr", marqueeStripBmp)
        DllCall("Gdi32\DeleteDC", "Ptr", marqueeStripDc)
    }
    marqueeStripDc := 0, marqueeStripBmp := 0, marqueeStripOld := 0
}

; Renders the whole scrolling track ONCE into an off-screen bitmap. Each frame then only copies a window of it,
; instead of creating a font/bitmap and re-drawing thousands of pixels of text 60+ times a second.
BuildStatusMarqueeStrip(refDc, height) {
    global marqueeTrackText, marqueeTrackWidth, currentStatusColor, marqueeCycleText, marqueeCycleWidth
    global marqueeStripDc, marqueeStripBmp, marqueeStripOld, marqueeStripH, marqueeStripDirty, marqueeStripPhases
    FreeStatusMarqueeStrip()
    marqueeStripDirty := false
    marqueeStripPhases := 1
    stripW := Min(Max(marqueeTrackWidth + 64, 64), 30000)
    ; Smooth mode: the bitmap holds `phases` bands, band i = the text shifted left by i/phases px (see BuildSubpixelBands).
    phases := (marqueeCycleText != "" && marqueeCycleWidth > 0) ? MarqueeChoosePhases(stripW, height) : 1
    dc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", refDc, "Ptr")
    if (!dc)
        return
    bmp := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", refDc, "Int", stripW, "Int", height * phases, "Ptr")
    if (!bmp && phases > 1) {
        phases := 1
        bmp := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", refDc, "Int", stripW, "Int", height, "Ptr")
    }
    if (!bmp) {
        DllCall("Gdi32\DeleteDC", "Ptr", dc)
        return
    }
    oldBmp := DllCall("Gdi32\SelectObject", "Ptr", dc, "Ptr", bmp, "Ptr")

    fullRect := Buffer(16, 0)
    NumPut("Int", stripW, fullRect, 8)
    NumPut("Int", height * phases, fullRect, 12)
    brush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00000000, "Ptr")
    DllCall("User32\FillRect", "Ptr", dc, "Ptr", fullRect, "Ptr", brush)
    DllCall("Gdi32\DeleteObject", "Ptr", brush)

    dpi := DllCall("Gdi32\GetDeviceCaps", "Ptr", refDc, "Int", 90)
    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(12 * dpi / 72), "Int", 0, "Int", 0, "Int", 0, "Int", 400, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", "Segoe UI Semibold", "Ptr")
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", dc, "Ptr", hFont, "Ptr")

    smoothOk := false
    if (phases > 1) {
        tm := Buffer(80, 0)
        DllCall("Gdi32\GetTextMetricsW", "Ptr", dc, "Ptr", tm)
        tmHeight := NumGet(tm, 0, "Int")
        ; 4 copies of one cycle, spaced exactly marqueeCycleWidth apart (the same layout as marqueeTrackText)
        smoothOk := BuildSubpixelBands(dc, stripW, height, phases, marqueeCycleText, 4, marqueeCycleWidth, marqueeCycleWidth
            , "Segoe UI Semibold", Round(12 * dpi / 72), false, currentStatusColor, tmHeight)
        if (!smoothOk) {
            ; GDI+ could not do it: start over with the plain GDI strip (whole-pixel motion), exactly like before.
            phases := 1
            NumPut("Int", height, fullRect, 12)
            brush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00000000, "Ptr")
            DllCall("User32\FillRect", "Ptr", dc, "Ptr", fullRect, "Ptr", brush)
            DllCall("Gdi32\DeleteObject", "Ptr", brush)
        }
    }
    if (!smoothOk) {
        DllCall("Gdi32\SetBkMode", "Ptr", dc, "Int", 1)
        DllCall("Gdi32\SetTextColor", "Ptr", dc, "UInt", HexToColorRef(currentStatusColor))
        ; DT_SINGLELINE | DT_VCENTER | DT_NOCLIP | DT_NOPREFIX (same flags as before)
        NumPut("Int", height, fullRect, 12)
        DllCall("User32\DrawTextW", "Ptr", dc, "Str", marqueeTrackText, "Int", -1, "Ptr", fullRect, "UInt", 0x00000B24)
    }
    DllCall("Gdi32\SelectObject", "Ptr", dc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)

    marqueeStripDc := dc, marqueeStripBmp := bmp, marqueeStripOld := oldBmp, marqueeStripH := height
    marqueeStripPhases := phases
}

; Double-buffered: the whole frame is composed off-screen and copied once, so the moving text never flickers.
DrawStatusMarquee(drawItemStruct) {
    global marqueeTrackText, marqueeRenderedX, currentStatusColor, marqueeRenderedPhase
    global marqueeStripDc, marqueeStripH, marqueeStripDirty, marqueeStripPhases
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    targetHdc := NumGet(drawItemStruct, itemHwndOffset + A_PtrSize, "Ptr")
    rectOffset := itemHwndOffset + A_PtrSize * 2
    left := NumGet(drawItemStruct, rectOffset, "Int")
    top := NumGet(drawItemStruct, rectOffset + 4, "Int")
    width := NumGet(drawItemStruct, rectOffset + 8, "Int") - left
    height := NumGet(drawItemStruct, rectOffset + 12, "Int") - top
    if (width <= 0 || height <= 0 || !targetHdc)
        return 1

    ; Fast path: copy the visible window of the pre-rendered track in a single BitBlt.
    if (marqueeStripDirty || marqueeStripH != height || !marqueeStripDc)
        BuildStatusMarqueeStrip(targetHdc, height)
    if (marqueeStripDc) {
        srcX := (marqueeRenderedX < -1000000) ? 0 : -marqueeRenderedX
        srcY := 0
        if (marqueeStripPhases > 1) {
            ; smooth strip: text origin is 1 px in; pick the band that holds the current sub-pixel shift
            srcX += 1
            if (marqueeRenderedX >= -1000000)
                srcY := Min(Max(marqueeRenderedPhase, 0), marqueeStripPhases - 1) * height
        }
        DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", marqueeStripDc, "Int", srcX, "Int", srcY, "UInt", 0x00CC0020)
        return 1
    }

    memoryDc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", targetHdc, "Ptr")
    if (!memoryDc)
        return 1
    bitmap := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", targetHdc, "Int", width, "Int", height, "Ptr")
    if (!bitmap) {
        DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
        return 1
    }
    oldBitmap := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", bitmap, "Ptr")

    localRect := Buffer(16, 0)
    NumPut("Int", width, localRect, 8)
    NumPut("Int", height, localRect, 12)
    brush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00000000, "Ptr")
    DllCall("User32\FillRect", "Ptr", memoryDc, "Ptr", localRect, "Ptr", brush)
    DllCall("Gdi32\DeleteObject", "Ptr", brush)

    textX := (marqueeRenderedX < -1000000) ? 0 : marqueeRenderedX
    textRect := Buffer(16, 0)
    NumPut("Int", textX, textRect, 0)
    NumPut("Int", 0, textRect, 4)
    NumPut("Int", textX + 20000, textRect, 8)
    NumPut("Int", height, textRect, 12)

    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(12 * DllCall("Gdi32\GetDeviceCaps", "Ptr", targetHdc, "Int", 90) / 72), "Int", 0, "Int", 0, "Int", 0, "Int", 400, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", "Segoe UI Semibold", "Ptr")
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", hFont, "Ptr")
    DllCall("Gdi32\SetBkMode", "Ptr", memoryDc, "Int", 1)
    DllCall("Gdi32\SetTextColor", "Ptr", memoryDc, "UInt", HexToColorRef(currentStatusColor))
    ; DT_SINGLELINE | DT_VCENTER | DT_NOCLIP | DT_NOPREFIX
    DllCall("User32\DrawTextW", "Ptr", memoryDc, "Str", marqueeTrackText, "Int", -1, "Ptr", textRect, "UInt", 0x00000B24)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)

    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBitmap, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", bitmap)
    DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
    return 1
}

UpdateMarquee() {
    global statusMarqueeText, statusMarqueeGui, marqueeTimerRunning, isExiting, isMarqueeActive, isWindowVisible
    global marqueeCycleWidth, marqueeOffset, marqueeLastTick, marqueePauseUntil, marqueeRenderedX
    global marqueeRefreshHz, marqueeFrameStep, marqueeFrames, marqueePxStep, marqueeStripPhases, marqueeRenderedPhase

    if (isExiting || !isMarqueeActive || !IsSet(mainGui) || !mainGui)
        return

    if (!isWindowVisible || DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd)) {
        if (marqueeTimerRunning) {
            ; (shared frame timer keeps running; UpdateMarquee exits early when inactive)
            marqueeTimerRunning := false
        }
        return
    }

    if (marqueeCycleWidth <= 0)
        return
    ; Smooth strip: the text advances 1/marqueeFrameStep px on EVERY refresh. Plain strip: one pixel per marqueeFrameStep refreshes.
    ; (shared MarqueeTick: pause, refresh counting, wrap and position are the same for every marquee)
    if (MarqueeTick(&marqueeOffset, &marqueeFrames, &marqueeLastTick, &marqueePauseUntil, &marqueeRenderedX, &marqueeRenderedPhase
        , marqueeCycleWidth, -1, marqueeStripPhases))
        RepaintStatusMarquee()
}

MinimizeWindow(*) {
    global animationActive, mainGui
    if (animationActive)
        return
    if (WinExist("ahk_id " mainGui.Hwnd)) {
        DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
    }
    CloseProcessSelector()
    AnimateVisibility(false, false, true)
}

HideWindowFromTray(*) {
    global animationActive, isWindowVisible, hasMinimizedBefore, mainGui
    if (animationActive || !isWindowVisible)
        return
    if (WinExist("ahk_id " mainGui.Hwnd)) {
        DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
    }
    CloseProcessSelector()
    if (!hasMinimizedBefore) {
        TrayTip("Application minimized to tray. It will continue running in the background.", "Ragnious: Discord Quests Completer", 1)
        SetTimer(() => TrayTip(), -4000)
        hasMinimizedBefore := true
    }
    AnimateVisibility(false, false, false)
}

RestoreWindow(*) {
    global mainGui, isWindowVisible, animationActive
    if (animationActive)
        return
    if (WinExist("ahk_id " mainGui.Hwnd)) {
        DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
    }
    CloseProcessSelector()
    if (isWindowVisible && WinExist("ahk_id " mainGui.Hwnd)) {
        if (!DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd) && WinActive("ahk_id " mainGui.Hwnd))
            return
    }
    TrayTip()
    if (!isWindowVisible || DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd)) {
        SetWindowOpacity(0)
        mainGui.Restore()
        AnimateVisibility(true)
    }
    if (WinExist("ahk_id " mainGui.Hwnd)) {
        try WinActivate("ahk_id " mainGui.Hwnd)
    }
    ResumeMarquee()
    SetStatus("Application restored and ready.", "ready")
}

CloseApplication(*) {
    global isExiting, gameFetchPending, asyncXhr
    if (isExiting)
        return
    isExiting := true
    if (gameFetchPending) {
        try asyncXhr.abort()
        FinishDiscordGameLoad()
    }
    AnimateVisibility(false, true, false)
}

AnimateVisibility(show, exitAppAfter := false, minimizeAfter := false) {
    global mainGui, animationActive, animationShowing, animationStart, animationDuration, isWindowVisible, isExiting, globalExitAppAfter, globalMinimizeAfter, frameGui, selectGui, actionGui, processSelect, selectorFrameGui
    CloseProcessSelector()
    animationActive := true, animationShowing := show, animationStart := A_TickCount, isWindowVisible := show, globalExitAppAfter := exitAppAfter, globalMinimizeAfter := minimizeAfter
    if show {
        SetWindowOpacity(0)
        mainGui.Show("NA")
        PositionChildWindows()
        ApplyAllCorners()
        TrayTip()
    }
    SetTimer(AnimationFrame, 16)
}

AnimationFrame() {
    global frameGui, selectGui, actionGui, mainGui, animationActive, animationShowing, animationStart, animationDuration, globalExitAppAfter, globalMinimizeAfter, isMarqueeActive, marqueeTimerRunning, marqueeLastTick, marqueePauseUntil, gdiplusToken, selectorFrameGui
    progress := Min((A_TickCount - animationStart) / animationDuration, 1)
    eased := (progress < 0.5) ? (4 * progress ** 3) : (1 - (-2 * progress + 2) ** 3 / 2)
    currentAlpha := Round(255 * (animationShowing ? eased : 1 - eased))
    SetWindowOpacity(currentAlpha)
    if (progress >= 1) {
        SetTimer(AnimationFrame, 0)
        animationActive := false
        if !animationShowing {
            if globalExitAppAfter {
                try frameGui.Hide()
                try selectGui.Hide()
                try actionGui.Hide()
                try mainGui.Hide()
                SetWindowOpacity(255)
                SetTimer(UpdateButtonHover, 0)
                SetTimer(AnimateRefreshArrow, 0)
                
                SetTimer(MarqueeMaster, 0)
                SetTimer(UpdateDotBlink, 0)
                SetTimer(PollDropdownHover, 0)
                CancelHelperLaunch()
                StopTargetProcess()
                DllCall("winmm\timeEndPeriod", "UInt", 1)
                ExitApp()
            } else if globalMinimizeAfter {
                try frameGui.Hide()
                try selectGui.Hide()
                try actionGui.Hide()
                DllCall("ShowWindow", "Ptr", mainGui.Hwnd, "Int", 6)
                SetWindowOpacity(255)
            } else {
                try frameGui.Hide()
                try selectGui.Hide()
                try actionGui.Hide()
                try mainGui.Hide()
                SetWindowOpacity(255)
            }
        } else {
            SetWindowOpacity(255)
            ResumeMarquee()
        }
    }
}

ShowOwnedWindows() => PositionChildWindows()

; Vertical layout of the search box and the Start button (the app name, tagline and status text never move).
; The three gaps are IDENTICAL BY CONSTRUCTION:
;     tagline -> search box  =  search box -> button  =  button -> status text  =  gap
; All gaps are measured between the VISIBLE edges: the baseline of the tagline, the box / button edges,
; and the ink top of the status sentence. Rounded-corner regions drop the last pixel row, so the
; visible height is the height - 1.
GetMainLayoutY(mainHeight, &textY, &actionY) {
    global mainSearchY, mainActionY
    textY := mainSearchY, actionY := mainActionY   ; their own values (they no longer follow the tagline / status line)
}

; Moves a control only when its geometry really differs (a Move repaints the control even when nothing changes, which re-prints the composited window).
MoveCtlIfChanged(ctl, x, y, w, h) {
    try {
        ctl.GetPos(&cx, &cy, &cw, &ch)
        if (cx = x && cy = y && cw = w && ch = h)
            return
    }
    ctl.Move(x, y, w, h)
}

PositionChildWindows() {
    global mainGui, titleBar, appName, appTagline, minBtn, closeBtn, versionText, frameGui, selectGui, actionGui, actionBtn, statusText, processSelect, refreshSeparator, refreshButton, selectorFrameGui, selectorPopup, selectorList, selectorDisplayedOptions, isExiting, isActionAnimating, selectorRowHeight, scrollBarWidth, isWindowMoving
    global verTextX, verTextY, verTextW, verTextH, titleBarX, titleBarY, titleBarW, titleBarH, minBtnX, minBtnY, minBtnW, minBtnH, closeBtnX, closeBtnY, closeBtnW, closeBtnH
    global appNameX, appNameY, appNameW, appNameH, appTaglineH
    global updateSep, updateBtn, updSepX, updSepW, updBtnX, updBtnW
    global searchFrameX, searchFrameW, searchFrameH, searchInnerX, searchInnerY, searchInnerW, searchInnerH, searchEditX, searchEditW, searchTextLeftInset
    global refreshSepX, refreshSepY, refreshSepW, refreshSepH, refreshBtnX, refreshBtnY, refreshBtnW, refreshBtnH
    global actionBtnPosX, actionBtnPosW, actionBtnPosH, searchIconOff
    if (isExiting || !isWindowVisible || !IsSet(mainGui) || !mainGui || isActionAnimating || isWindowMoving)
        return
    try {
        WinGetPos(,, &mainWidth, &mainHeight, "ahk_id " mainGui.Hwnd)
    } catch {
        return
    }

    GetMainLayoutY(mainHeight, &textY, &actionY)
    taglineY := (appNameY + appNameH - 18) + 3      ; tagline follows the app name (allowed group)

    MoveCtlIfChanged(versionText, verTextX, verTextY, verTextW, verTextH)
    MoveCtlIfChanged(updateSep, updSepX, verTextY, updSepW, verTextH)
    MoveCtlIfChanged(updateBtn, updBtnX, verTextY, updBtnW, verTextH)
    MoveCtlIfChanged(titleBar, titleBarX, titleBarY, titleBarW, titleBarH)
    MoveCtlIfChanged(minBtn, minBtnX, minBtnY, minBtnW, minBtnH)
    MoveCtlIfChanged(closeBtn, closeBtnX, closeBtnY, closeBtnW, closeBtnH)
    MoveCtlIfChanged(appName, appNameX, appNameY, appNameW, appNameH)
    MoveCtlIfChanged(appTagline, appNameX, taglineY, appNameW, appTaglineH)

    if (riskViewActive) {
        PositionRiskView(mainWidth, mainHeight)
        return
    }

    static lastFrameKey := "", lastInnerKey := "", lastActionKey := "", lastMarginKey := "", lastSelectLayout := "", lastDropKey := ""

    ; A window is (re)shown only when its geometry changed or it is hidden; showing it again with the same geometry repaints it for nothing.
    frameKey := Format("{}|{}|{}|{}|{}", frameGui.Hwnd, searchFrameX, textY, searchFrameW, searchFrameH)
    if (frameKey != lastFrameKey || !DllCall("User32\IsWindowVisible", "Ptr", frameGui.Hwnd, "Int")) {
        frameGui.Show(Format("NA x{} y{} w{} h{}", searchFrameX, textY, searchFrameW, searchFrameH))
        lastFrameKey := frameKey
    }
    innerKey := Format("{}|{}|{}|{}|{}", selectGui.Hwnd, searchInnerX, searchInnerY, searchInnerW, searchInnerH)
    if (innerKey != lastInnerKey || !DllCall("User32\IsWindowVisible", "Ptr", selectGui.Hwnd, "Int")) {
        selectGui.Show(Format("NA x{} y{} w{} h{}", searchInnerX, searchInnerY, searchInnerW, searchInnerH))
        lastInnerKey := innerKey
    }

    ; Single-line edits draw their text at the top, so the edit is made exactly one line tall and
    ; placed so the centre of the text sits on the centre of the box.
    GetControlFontCenterMetrics(processSelect.Hwnd, &editHeight, &editCapCenter)
    editHeight := Max(editHeight, 1)
    ; The rounded-corner region drops the last pixel row of the box, so the VISIBLE area is searchInnerH - 1 rows tall
    ; and its centre is (searchInnerH - 1) / 2.
    editY := Floor((searchInnerH - 1) / 2 - editCapCenter + 0.5) + textVCenterNudge
    MoveCtlIfChanged(processSelect, searchEditX, editY, searchEditW, editHeight)

    marginKey := Format("{}|{}|{}", processSelect.Hwnd, searchTextLeftInset, searchIconOff)
    if (marginKey != lastMarginKey) {
        SetSearchEditMargins(searchTextLeftInset)
        lastMarginKey := marginKey
    }

    selectLayout := Format("{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}", frameGui.Hwnd, selectGui.Hwnd, searchFrameX, textY, searchFrameW, searchFrameH, searchInnerW, searchInnerH, refreshSepX, refreshSepY, refreshSepW, refreshSepH, refreshBtnX, refreshBtnW, refreshBtnH)
    if (selectLayout != lastSelectLayout) {
        lastSelectLayout := selectLayout
        MoveCtlIfChanged(refreshSeparator, refreshSepX, refreshSepY, refreshSepW, refreshSepH)
        MoveCtlIfChanged(refreshButton, refreshBtnX, refreshBtnY, refreshBtnW, refreshBtnH)
        ApplyRoundedCorners(frameGui, 24)
        ApplyRoundedCorners(selectGui, 22)
        PositionSearchIcon()
    }

    actionKey := Format("{}|{}|{}|{}|{}", actionGui.Hwnd, actionBtnPosX, actionY, actionBtnPosW, actionBtnPosH)
    if (actionKey != lastActionKey || !DllCall("User32\IsWindowVisible", "Ptr", actionGui.Hwnd, "Int")) {
        actionGui.Show(Format("NA x{} y{} w{} h{}", actionBtnPosX, actionY, actionBtnPosW, actionBtnPosH))
        lastActionKey := actionKey
    }
    MoveCtlIfChanged(actionBtn, 0, 0, actionBtnPosW, actionBtnPosH)
    ApplyRoundedCorners(actionGui, 24)
    PositionStatusControls()

    if (IsWindowValid(selectorFrameGui) && WinExist("ahk_id " selectorFrameGui.Hwnd)) {
        WinGetPos(&selectScreenX, &selectScreenY, &selectW, &selectH, "ahk_id " selectGui.Hwnd)
        dropdownY := selectScreenY + selectH + dropdownGapBelowSearch
        visibleTitleRows := Min(3, Max(1, selectorDisplayedOptions.Length))
        dropdownHeight := (selectorRowHeight * visibleTitleRows) + 2
        dropdownY := Min(dropdownY, A_ScreenHeight - dropdownHeight - 12)
        totalPopupW := selectW

        innerPopupW := totalPopupW - 2
        innerPopupH := dropdownHeight - 2
        listW := (selectorDisplayedOptions.Length <= 3) ? innerPopupW : (innerPopupW - scrollBarWidth - 2)

        dropKey := Format("{}|{}|{}|{}|{}|{}|{}", selectorFrameGui.Hwnd, selectScreenX, dropdownY, totalPopupW, dropdownHeight, listW, selectorDisplayedOptions.Length)
        if (dropKey != lastDropKey) {
            lastDropKey := dropKey
            DropdownPaintLock(true)
            try {
                selectorFrameGui.Move(selectScreenX, dropdownY, totalPopupW, dropdownHeight)
                selectorPopup.Move(1, 1, totalPopupW - 2, dropdownHeight - 2)
                if (IsWindowValid(selectorList))
                    MoveCtlIfChanged(selectorList, 1, 0, listW, innerPopupH)
                ApplyRoundedCorners(selectorFrameGui, 24)
                ApplyRoundedCorners(selectorPopup, 22)
            } finally {
                DropdownPaintLock(false)
            }
            PositionScrollbarControls(totalPopupW, dropdownHeight)
        }
        DropdownZOrderGuard()
    }
}

; Rows always start at the top of the list and always have the same height, so the lines between the
; visible titles are always at the same two places no matter how far the list is scrolled.
UpdateRowSeparators() {
    global selectorList, selectorRowSep1, selectorRowSep2, selectorRowHeight, selectorDisplayedOptions
    if (!IsWindowValid(selectorList) || !IsWindowValid(selectorRowSep1) || !IsWindowValid(selectorRowSep2))
        return
    selectorList.GetPos(&listX, &listY, &listW)
    visibleItems := Min(3, selectorDisplayedOptions.Length)
    static lastSepGeom := Map()
    for k, sep in [selectorRowSep1, selectorRowSep2] {
        if (k < visibleItems) {
            ; Move, size, raise above the list and show in one call (HWND_TOP, SWP_NOACTIVATE | SWP_SHOWWINDOW).
            sepGeom := listX "|" (listY + k * selectorRowHeight - 1) "|" listW
            DllCall("User32\SetWindowPos", "Ptr", sep.Hwnd, "Ptr", 0, "Int", listX, "Int", listY + k * selectorRowHeight - 1, "Int", listW, "Int", 1, "UInt", 0x0050, "Int")
            if (!lastSepGeom.Has(sep.Hwnd) || lastSepGeom[sep.Hwnd] != sepGeom) {     ; repaint only when the line really moved / resized (and never erase first)
                lastSepGeom[sep.Hwnd] := sepGeom
                DllCall("User32\InvalidateRect", "Ptr", sep.Hwnd, "Ptr", 0, "Int", false)
                DllCall("User32\UpdateWindow", "Ptr", sep.Hwnd)
            }
        } else {
            ; SWP_HIDEWINDOW | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
            DllCall("User32\SetWindowPos", "Ptr", sep.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0097, "Int")
            if (lastSepGeom.Has(sep.Hwnd))
                lastSepGeom.Delete(sep.Hwnd)
        }
    }
}

PositionScrollbarControls(popupW, popupH) {
    global selectorScrollUpBtn, selectorScrollDownBtn, selectorScrollThumb, selectorScrollThumbTrack, selectorScrollSeparator, selectorList
    global scrollButtonHeight, scrollBarWidth, selectorDisplayedOptions, selectorRowHeight, selectorScrollHoverTarget
    
    if (!IsWindowValid(selectorScrollUpBtn) || !IsWindowValid(selectorScrollDownBtn) || !IsWindowValid(selectorScrollThumb) || !IsWindowValid(selectorScrollThumbTrack) || !IsWindowValid(selectorScrollSeparator))
        return

    innerPopupW := popupW - 2
    innerPopupH := popupH - 2
    barX := innerPopupW - scrollBarWidth

    ; Same geometry, same controls and the bar is already showing: nothing to move or redraw (the repeated Redraw() calls made the bar flicker).
    static lastBarKey := ""
    barKey := Format("{}|{}|{}|{}", selectorScrollUpBtn.Hwnd, popupW, popupH, scrollBarWidth)
    if (selectorDisplayedOptions.Length > 3 && barKey = lastBarKey && DllCall("User32\IsWindowVisible", "Ptr", selectorScrollUpBtn.Hwnd, "Int")) {
        if (IsWindowValid(selectorList))
            MoveCtlIfChanged(selectorList, 1, 0, innerPopupW - scrollBarWidth - 2, innerPopupH)
        UpdateRowSeparators()
        UpdateScrollThumbPosition()
        return
    }
    if (selectorDisplayedOptions.Length > 3)
        lastBarKey := barKey

    if (selectorDisplayedOptions.Length <= 3) {
        selectorScrollUpBtn.Opt("+Hidden")
        selectorScrollDownBtn.Opt("+Hidden")
        selectorScrollThumbTrack.Opt("+Hidden")
        selectorScrollThumb.Opt("+Hidden")
        selectorScrollSeparator.Opt("+Hidden")
        selectorScrollUpBtn.Redraw()
        selectorScrollDownBtn.Redraw()
        selectorScrollThumb.Redraw()
        selectorScrollSeparator.Redraw()
        selectorScrollHoverTarget := ""
        if (IsWindowValid(selectorList))
            MoveCtlIfChanged(selectorList, 1, 0, innerPopupW, innerPopupH)
        UpdateRowSeparators()
        return
    }
    topInset := 0
    bottomInset := 1
    
    selectorScrollUpBtn.Move(barX, topInset, scrollBarWidth, scrollButtonHeight)
    selectorScrollDownBtn.Move(barX, popupH - 2 - bottomInset - scrollButtonHeight, scrollBarWidth, scrollButtonHeight)
    trackY := topInset + scrollButtonHeight
    trackH := Max(1, popupH - 2 - topInset - bottomInset - (scrollButtonHeight * 2))
    selectorScrollThumbTrack.Move(barX, trackY, scrollBarWidth, trackH)
    selectorScrollSeparator.Move(barX - 1, 0, 1, innerPopupH)
    
    selectorScrollUpBtn.Opt("-Hidden")
    selectorScrollDownBtn.Opt("-Hidden")
    selectorScrollThumbTrack.Opt("-Hidden")
    selectorScrollThumb.Opt("-Hidden")
    selectorScrollSeparator.Opt("-Hidden")
    selectorScrollUpBtn.Redraw()
    selectorScrollDownBtn.Redraw()
    selectorScrollSeparator.Redraw()
    if (IsWindowValid(selectorList))
        MoveCtlIfChanged(selectorList, 1, 0, innerPopupW - scrollBarWidth - 2, innerPopupH)
    UpdateRowSeparators()
    UpdateScrollThumbPosition()
}

ApplyAnchorScrollThumb() {
    global selectorScrollThumb, selectorScrollThumbTrack
    if (!IsWindowValid(selectorScrollThumb))
        return
    rect := Buffer(16, 0)
    if (!DllCall("User32\GetWindowRect", "Ptr", selectorScrollThumb.Hwnd, "Ptr", rect, "Int"))
        return
    width := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")
    height := NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int")
    if (width < 2 || height < 2)
        return
    
    DllCall("User32\SetWindowRgn", "Ptr", selectorScrollThumb.Hwnd, "Ptr", 0, "Int", false)
    if (IsWindowValid(selectorScrollThumbTrack))
        DllCall("User32\InvalidateRect", "Ptr", selectorScrollThumbTrack.Hwnd, "Ptr", 0, "Int", true)
    DllCall("User32\InvalidateRect", "Ptr", selectorScrollThumb.Hwnd, "Ptr", 0, "Int", true)
}

UpdateScrollThumbPosition() {
    global selectorDisplayedOptions
    if (selectorDisplayedOptions.Length <= 3)
        return
    UpdateScrollThumbPositionCore()
}

RepaintScrollThumbNoErase() {
    global selectorScrollThumb, selectorScrollThumbTrack
    if (IsWindowValid(selectorScrollThumbTrack)) {
        DllCall("User32\InvalidateRect", "Ptr", selectorScrollThumbTrack.Hwnd, "Ptr", 0, "Int", false)
        DllCall("User32\UpdateWindow", "Ptr", selectorScrollThumbTrack.Hwnd)
    }
    if (IsWindowValid(selectorScrollThumb)) {
        DllCall("User32\InvalidateRect", "Ptr", selectorScrollThumb.Hwnd, "Ptr", 0, "Int", false)
        DllCall("User32\UpdateWindow", "Ptr", selectorScrollThumb.Hwnd)
    }
}

UpdateScrollThumbPositionCore() {
    global selectorList, selectorDisplayedOptions, selectorScrollThumb, selectorScrollThumbTrack, selectorRowHeight, selectorScrollHoverTarget, isDraggingThumb, scrollBarWidth
    if (!IsWindowValid(selectorList) || !IsWindowValid(selectorScrollThumb) || !IsWindowValid(selectorScrollThumbTrack))
        return
    if (selectorDisplayedOptions.Length <= 3)
        return
    selectorScrollThumbTrack.GetPos(&trackX, &trackY, &trackW, &trackH)
    selectorList.GetPos(,, &listW, &listHeight)
    
    thumbWidth := 6
    ; Shift thumb to the left by 5% of its track area width
    thumbX := trackX + ((trackW - thumbWidth) // 2) - Round(trackW * 0.05)
    
    totalItems := selectorDisplayedOptions.Length
    visibleRows := Max(1, Floor(listHeight / selectorRowHeight))
    if (totalItems <= visibleRows) {
        selectorScrollThumb.Move(thumbX, trackY, thumbWidth, trackH)
        ApplyAnchorScrollThumb()
        return
    }
    topIndex := SendMessage(0x018E, 0, 0, selectorList.Hwnd)
    if (topIndex < 0)
        topIndex := 0
    
    thumbH := Min(trackH, Max(24, Round(trackH * (visibleRows / totalItems))))
    maxScroll := totalItems - visibleRows
    ratio := (maxScroll > 0) ? (topIndex / maxScroll) : 0
    thumbY := trackY + Round(ratio * (trackH - thumbH))
    
    selectorScrollThumb.GetPos(&curX, &curY, &curW, &curH)
    if (curX = thumbX && curY = thumbY && curW = thumbWidth && curH = thumbH)
        return
    if (curW = thumbWidth && curH = thumbH) {
        DllCall("User32\SetWindowPos", "Ptr", selectorScrollThumb.Hwnd, "Ptr", 0, "Int", thumbX, "Int", thumbY, "Int", 0, "Int", 0, "UInt", 0x001D, "Int")
    } else {
        selectorScrollThumb.Move(thumbX, thumbY, thumbWidth, thumbH)
        ApplyAnchorScrollThumb()
    }
    RepaintScrollThumbNoErase()
}

BlendHexColor(fromColor, toColor, amount) {
    fromValue := Integer("0x" fromColor)
    toValue := Integer("0x" toColor)
    red := Round(((fromValue >> 16) & 0xFF) + (((toValue >> 16) & 0xFF) - ((fromValue >> 16) & 0xFF)) * amount)
    green := Round(((fromValue >> 8) & 0xFF) + (((toValue >> 8) & 0xFF) - ((fromValue >> 8) & 0xFF)) * amount)
    blue := Round((fromValue & 0xFF) + ((toValue & 0xFF) - (fromValue & 0xFF)) * amount)
    return Format("{:02X}{:02X}{:02X}", red, green, blue)
}

HexToColorRef(color) {
    value := Integer("0x" color)
    red := (value >> 16) & 0xFF
    green := (value >> 8) & 0xFF
    blue := value & 0xFF
    return red | (green << 8) | (blue << 16)
}

StartRefreshButtonStyle(state) {
    global refreshButtonBgCurrent, refreshButtonBgFrom, refreshButtonBgTo, refreshButtonAnimationStartedAt, refreshIsLocked, isRunning
    if (refreshIsLocked) {
        SetTimer(AnimateRefreshButtonStyle, 0)
        refreshButtonBgCurrent := "555555"
        return
    }
    ; A created process is active (helper .exe or Rich Presence): the button is unavailable and is drawn with the fixed click-effect
    ; disabled look (dark 2E2E2E fill + grey 808080 icon, see DrawRefreshButton / WmCtlColorStatic). It takes NO hover and NO press change: every request ("hover",
    ; "pressed", "normal") is ignored; the stored colour is reset to plain so the hover fade starts from black again after Stop.
    if (RefreshDisabled()) {
        SetTimer(AnimateRefreshButtonStyle, 0)
        if (refreshButtonBgCurrent != "000000") {
            refreshButtonBgCurrent := "000000"
            RepaintRefreshButtonNoErase()
        }
        return
    }
    refreshButtonBgFrom := refreshButtonBgCurrent
    if (state = "pressed") {
        ; Pressed colour == locked colour (555555) and is applied instantly, with no fade: if the button were still
        ; mid-fade when the refresh locks it, the lock would show as a visible colour jump (the one-time flicker).
        SetTimer(AnimateRefreshButtonStyle, 0)
        refreshButtonBgCurrent := "555555"
        RepaintRefreshButtonNoErase()
        return
    } else if (false) {
        refreshButtonBgTo := "555555"
    } else if (state = "hover") {
        refreshButtonBgTo := "3A3A3A"
    } else {
        refreshButtonBgTo := "000000"
    }
    ; Already at the target colour (e.g. the hover logic re-checks after every Start / Stop press): nothing to fade, no timer.
    if (refreshButtonBgCurrent = refreshButtonBgTo) {
        SetTimer(AnimateRefreshButtonStyle, 0)
        return
    }
    refreshButtonAnimationStartedAt := A_TickCount
    SetTimer(AnimateRefreshButtonStyle, 16)
}

AnimateRefreshButtonStyle(*) {
    global refreshButton, refreshButtonBgCurrent, refreshButtonBgFrom, refreshButtonBgTo
    global refreshButtonAnimationStartedAt, refreshButtonAnimationDuration, refreshIsLocked
    if (refreshIsLocked) {
        refreshButtonBgCurrent := "555555"
        RepaintRefreshButtonNoErase()
        SetTimer(AnimateRefreshButtonStyle, 0)
        return
    }
    progress := Min(1.0, (A_TickCount - refreshButtonAnimationStartedAt) / refreshButtonAnimationDuration)
    eased := progress * progress * (3 - 2 * progress)
    refreshButtonBgCurrent := BlendHexColor(refreshButtonBgFrom, refreshButtonBgTo, eased)
    RepaintRefreshButtonNoErase()
    if (progress >= 1.0) {
        refreshButtonBgCurrent := refreshButtonBgTo
        SetTimer(AnimateRefreshButtonStyle, 0)
    }
}

StartRefreshArrowAnimation() {
    global refreshArrowAnimating, refreshArrowStartedAt, refreshArrowAngle
    global refreshButton, refreshIsLocked, refreshShowCheck, lastHover, refreshButtonBgCurrent
    refreshIsLocked := true
    lastHover := -1
    refreshShowCheck := false
    refreshButtonBgCurrent := "555555"
    SetTimer(AnimateRefreshButtonStyle, 0)
    SyncRefreshOverlay()                       ; cover the button with the stand-alone overlay BEFORE the first locked frame
    SetTimer(SyncRefreshOverlay, 10)
    RepaintRefreshButtonNoErase(true)
    refreshArrowAnimating := true
    refreshArrowStartedAt := NowMs()
    refreshArrowAngle := 0.0
    SetTimer(AnimateRefreshArrow, 16)
}

AnimateRefreshArrow(*) {
    global refreshButton, refreshArrowAnimating, refreshArrowStartedAt, refreshArrowDuration, refreshArrowAngle
    if (!refreshArrowAnimating)
        return
    ; High-resolution clock (A_TickCount only moves every ~15.6 ms, which makes the spin judder).
    newAngle := Mod((NowMs() - refreshArrowStartedAt) * 360.0 / refreshArrowDuration, 360.0)
    if (Abs(newAngle - refreshArrowAngle) < 0.3)
        return
    refreshArrowAngle := newAngle
    RepaintRefreshButtonNoErase(true)
}

; While the button is locked (refreshing), AnimateRefreshArrow is its ONLY painter (force = true). Every other
; caller (hover timer, activation, kick ripple, ...) is ignored, so the button is never painted twice per frame or
; at a moment the animation did not choose, and the whole window never repaints more often than needed.
RepaintRefreshButtonNoErase(force := false) {
    global refreshButton, refreshIsLocked
    if (refreshIsLocked && !force)
        return
    if (force && refreshIsLocked) {
        PaintRefreshButtonDirect()
        return
    }
    ; START-PRESS SHIMMER FIX: this used to InvalidateRect + UpdateWindow the refresh button. The main window is layered +
    ; WS_EX_COMPOSITED, so that makes Windows re-print the WHOLE window tree, status marquee included, and the marquee
    ; flickers ("shimmer"). Every Start / Stop press reaches this through ToggleAction -> UpdateButtonHover (lastHover := -1),
    ; and the colour fade then repeated it on every 16 ms tick. Paint the button's own pixels directly instead (one BitBlt).
    if (PaintControlDirect(refreshButton, DrawRefreshButton))
        return
    if (IsWindowValid(refreshButton)) {
        DllCall("User32\InvalidateRect", "Ptr", refreshButton.Hwnd, "Ptr", 0, "Int", false)
        DllCall("User32\UpdateWindow", "Ptr", refreshButton.Hwnd)
    }
}

; Spin frames are drawn straight onto the button's own DC with the same off-screen renderer (DrawRefreshButton),
; WITHOUT invalidating anything. The main window uses WS_EX_COMPOSITED + layered, so every normal
; InvalidateRect/UpdateWindow on a child makes Windows re-print and re-compose the WHOLE window tree;
; at 60 repaints per second that is what produced the stutter and the flashing of the locked colour.
; Direct painting touches only the button's own 51x47 pixels, one BitBlt per frame.
PaintRefreshButtonDirect() {
    global refreshButton, isExiting, isWindowVisible, mainGui, refreshOverlayShown, refreshOverlayCtl
    if (isExiting || !isWindowVisible || !IsWindowValid(refreshButton) || !IsWindowValid(mainGui))
        return
    if (DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int") || !DllCall("User32\IsWindowVisible", "Ptr", refreshButton.Hwnd, "Int"))
        return
    ; While the overlay covers the button, the frames go to the overlay's own control (a normal top-level window,
    ; outside the composited tree); otherwise to the real button.
    target := (refreshOverlayShown && IsWindowValid(refreshOverlayCtl)) ? refreshOverlayCtl : refreshButton
    rc := Buffer(16, 0)
    if (!DllCall("User32\GetClientRect", "Ptr", target.Hwnd, "Ptr", rc, "Int"))
        return
    hdc := DllCall("User32\GetDC", "Ptr", target.Hwnd, "Ptr")
    if (!hdc)
        return
    ; Minimal DRAWITEMSTRUCT: only the hDC and rcItem fields are read by DrawRefreshButton.
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    fake := Buffer(itemHwndOffset + A_PtrSize * 2 + 16 + A_PtrSize, 0)
    NumPut("Ptr", hdc, fake, itemHwndOffset + A_PtrSize)
    rectOffset := itemHwndOffset + A_PtrSize * 2
    NumPut("Int", 0, "Int", 0, "Int", NumGet(rc, 8, "Int"), "Int", NumGet(rc, 12, "Int"), fake, rectOffset)
    DrawRefreshButton(fake)
    DllCall("User32\ReleaseDC", "Ptr", target.Hwnd, "Ptr", hdc)
}

; While a refresh is running, the spinning button lives in this small stand-alone window laid exactly over the real
; button (same rect, clipped to the search box's rounded corners). It is a normal top-level owned popup like the
; dropdown, so it is NOT part of the main window's layered/composited tree: nothing that shows, hides, moves or
; repaints other controls can ever re-print, erase or overwrite it. It never takes focus and is click-through.
SyncRefreshOverlay(*) {
    global refreshOverlay, refreshOverlayCtl, refreshOverlayShown, refreshOverlayGeom
    global refreshButton, selectGui, mainGui, refreshIsLocked, isExiting, isWindowVisible, animationActive
    want := !isExiting && refreshIsLocked && isWindowVisible && !animationActive
        && IsWindowValid(refreshButton) && IsWindowValid(mainGui) && IsWindowValid(selectGui)
    if (want)
        want := !DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int")
            && DllCall("User32\IsWindowVisible", "Ptr", refreshButton.Hwnd, "Int")
    if (!want) {
        if (refreshOverlayShown && IsWindowValid(refreshOverlay))
            refreshOverlay.Hide()
        refreshOverlayShown := false
        refreshOverlayGeom := ""
        return
    }
    try {
        WinGetPos(&bx, &by, &bw, &bh, "ahk_id " refreshButton.Hwnd)
        WinGetPos(&sx, &sy, &sw, &sh, "ahk_id " selectGui.Hwnd)
    } catch {
        return
    }
    geom := bx "|" by "|" bw "|" bh "|" sx "|" sy "|" sw "|" sh
    if (refreshOverlayShown && geom = refreshOverlayGeom)
        return

    justCreated := false
    if (!IsWindowValid(refreshOverlay)) {
        refreshOverlay := Gui("-Caption +ToolWindow +E0x08000000 +Owner" mainGui.Hwnd, "")
        refreshOverlay.BackColor := "555555"
        refreshOverlay.MarginX := 0, refreshOverlay.MarginY := 0
        refreshOverlayCtl := refreshOverlay.Add("Text", Format("x0 y0 w{} h{} +0x000D", bw, bh), "")
        RemoveNativeOutline(refreshOverlay.Hwnd)
        RemoveNativeOutline(refreshOverlayCtl.Hwnd)
        justCreated := true
    }
    refreshOverlayCtl.Move(0, 0, bw, bh)
    refreshOverlay.Show(Format("NA x{} y{} w{} h{}", bx, by, bw, bh))

    ; Clip to the search box's rounded outline (the real button is clipped by it too).
    rgn := DllCall("Gdi32\CreateRectRgn", "Int", 0, "Int", 0, "Int", bw, "Int", bh, "Ptr")
    selRgn := DllCall("Gdi32\CreateRoundRectRgn", "Int", sx - bx, "Int", sy - by, "Int", sx - bx + sw, "Int", sy - by + sh, "Int", 22, "Int", 22, "Ptr")
    if (rgn && selRgn) {
        DllCall("Gdi32\CombineRgn", "Ptr", rgn, "Ptr", rgn, "Ptr", selRgn, "Int", 1)   ; RGN_AND
        if (!DllCall("User32\SetWindowRgn", "Ptr", refreshOverlay.Hwnd, "Ptr", rgn, "Int", true, "Int"))
            DllCall("Gdi32\DeleteObject", "Ptr", rgn)
    } else if (rgn)
        DllCall("Gdi32\DeleteObject", "Ptr", rgn)
    if (selRgn)
        DllCall("Gdi32\DeleteObject", "Ptr", selRgn)

    firstShow := !refreshOverlayShown
    refreshOverlayShown := true
    refreshOverlayGeom := geom
    if (firstShow)
        PaintRefreshButtonDirect()
}

; Mouse input goes straight through the overlay to the real button underneath (hover / cursor logic is unchanged).
RefreshOverlayHitTest(wParam, lParam, msg, hwnd) {
    global refreshOverlay, statusFadeOv
    if ((IsObject(refreshOverlay) && hwnd = refreshOverlay.Hwnd) || (IsObject(statusFadeOv) && hwnd = statusFadeOv.Hwnd))
        return -1          ; HTTRANSPARENT
}

; Used when a refresh could not be started: leaves the locked state without showing the check mark.
CancelRefreshArrowAnimation() {
    global refreshArrowAnimating, refreshArrowAngle, refreshIsLocked, refreshShowCheck, lastHover, refreshButtonBgCurrent
    refreshArrowAnimating := false
    refreshArrowAngle := 0.0
    refreshIsLocked := false
    refreshShowCheck := false
    lastHover := -1
    refreshButtonBgCurrent := "555555"      ; the hover logic fades out of this colour
    SetTimer(AnimateRefreshArrow, 0)
    RepaintRefreshButtonNoErase()           ; real button repaints (hidden under the overlay) ...
    SetTimer(SyncRefreshOverlay, 0)
    SyncRefreshOverlay()                    ; ... and only then the overlay goes away
}

StopRefreshArrowAnimation() {
    global refreshButton, refreshArrowAnimating, refreshArrowAngle, refreshIsLocked, refreshShowCheck, lastHover, refreshButtonBgCurrent
    refreshArrowAnimating := false
    refreshArrowAngle := 0.0
    refreshIsLocked := false
    refreshShowCheck := true
    lastHover := -1
    refreshButtonBgCurrent := "000000"
    SetTimer(AnimateRefreshArrow, 0)
    RepaintRefreshButtonNoErase()           ; real button repaints (hidden under the overlay) ...
    SetTimer(SyncRefreshOverlay, 0)
    SyncRefreshOverlay()                    ; ... and only then the overlay goes away
}

DrawRefreshButton(drawItemStruct) {
    global refreshButtonBgCurrent, refreshArrowAngle, gdiplusToken, refreshIsLocked, refreshShowCheck, refreshKickStart, refreshKickDuration, isRunning
    ; While a created process is active (exe or Rich Presence) or the 60 s pause runs, the button looks disabled: very dark grey fill (2E2E2E, barely lighter
    ; than the black window) and a dimmed grey icon (808080). While refreshing (locked) it keeps 555555 with the normal white icon.
    procDisabled := !refreshIsLocked && RefreshDisabled()
    effectiveBg := refreshIsLocked ? "555555" : (procDisabled ? "2E2E2E" : refreshButtonBgCurrent)
    iconArgb := procDisabled ? 0xFF808080 : 0xFFFFFFFF
    
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    targetHdc := NumGet(drawItemStruct, itemHwndOffset + A_PtrSize, "Ptr")
    rectOffset := itemHwndOffset + A_PtrSize * 2
    left := NumGet(drawItemStruct, rectOffset, "Int")
    top := NumGet(drawItemStruct, rectOffset + 4, "Int")
    right := NumGet(drawItemStruct, rectOffset + 8, "Int")
    bottom := NumGet(drawItemStruct, rectOffset + 12, "Int")
    width := right - left
    height := bottom - top
    if (width <= 0 || height <= 0 || !targetHdc)
        return 1

    memoryDc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", targetHdc, "Ptr")
    if (!memoryDc)
        return 1
    bitmap := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", targetHdc, "Int", width, "Int", height, "Ptr")
    if (!bitmap) {
        DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
        return 1
    }
    oldBitmap := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", bitmap, "Ptr")

    localRect := Buffer(16, 0)
    NumPut("Int", 0, localRect, 0)
    NumPut("Int", 0, localRect, 4)
    NumPut("Int", width, localRect, 8)
    NumPut("Int", height, localRect, 12)
    backgroundBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", HexToColorRef(effectiveBg), "Ptr")
    if (backgroundBrush) {
        DllCall("User32\FillRect", "Ptr", memoryDc, "Ptr", localRect, "Ptr", backgroundBrush)
        DllCall("Gdi32\DeleteObject", "Ptr", backgroundBrush)
    }

    if (gdiplusToken) {
        graphicsBuffer := Buffer(A_PtrSize, 0)
        if (DllCall("gdiplus\GdipCreateFromHDC", "Ptr", memoryDc, "Ptr", graphicsBuffer, "UInt") = 0) {
            graphics := NumGet(graphicsBuffer, 0, "Ptr")
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4, "UInt")
            DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", graphics, "Float", -left, "Float", -top, "Int", 0, "UInt")

            ; ---- Icon geometry (same size as before: ring radius ~12 px) ----
            ; The ring has a gap and an arrowhead, so its circle centre is NOT the visual centre of the icon.
            ; The bounding box of the finished drawing (ring + arrowhead + half the pen width) is computed
            ; here and the whole icon is shifted so that box sits exactly in the middle of the button.
            ; The ring still spins around its own (fixed) circle centre, so the animation does not wobble.
            radius := (28.0 - 1.8) / 2   ; icon is 28 px across including the stroke
            ringPenW := 1.8
            ; Arrowhead: a solid triangle (softened by a thin round-joined outline). Its base is centred ON the ring's
            ; end point and lies along the radius, so the head is symmetric about the ring instead of leaning to one side;
            ; the tip points along the direction of travel.
            headHalfW := 3.3, headLen := 5.0, headEdgePenW := 1.0
            gapStart := -30.0, sweepAngle := 300.0
            rad := 0.0174532925199433

            ; bounding box of the icon at rest (angle 0)
            minX := 1.0e9, maxX := -1.0e9, minY := 1.0e9, maxY := -1.0e9
            sampleAngle := gapStart
            Loop 61 {
                sx := radius * Cos(sampleAngle * rad), sy := radius * Sin(sampleAngle * rad)
                minX := Min(minX, sx), maxX := Max(maxX, sx), minY := Min(minY, sy), maxY := Max(maxY, sy)
                sampleAngle := Min(gapStart + sweepAngle, sampleAngle + 5.0)
            }
            restEnd := (gapStart + sweepAngle) * rad
            restBaseX := radius * Cos(restEnd), restBaseY := radius * Sin(restEnd)
            restTanX := -Sin(restEnd), restTanY := Cos(restEnd)
            restRadX := Cos(restEnd), restRadY := Sin(restEnd)
            for hp in [[restBaseX + restRadX * headHalfW, restBaseY + restRadY * headHalfW]
                     , [restBaseX - restRadX * headHalfW, restBaseY - restRadY * headHalfW]
                     , [restBaseX + restTanX * headLen, restBaseY + restTanY * headLen]] {
                minX := Min(minX, hp[1] - headEdgePenW / 2), maxX := Max(maxX, hp[1] + headEdgePenW / 2)
                minY := Min(minY, hp[2] - headEdgePenW / 2), maxY := Max(maxY, hp[2] + headEdgePenW / 2)
            }
            minX -= ringPenW / 2, maxX += ringPenW / 2, minY -= ringPenW / 2, maxY += ringPenW / 2

            ; button centre (the visible area is 1 px taller than the control's lower edge, hence -0.5)
            buttonCX := left + width / 2.0
            buttonCY := top + height / 2.0 - 0.5
            centerX := buttonCX - (minX + maxX) / 2
            centerY := buttonCY   ; ring and check are centred on the button itself (not on the box that includes the arrowhead)

            penBuffer := Buffer(A_PtrSize, 0)
            if (DllCall("gdiplus\GdipCreatePen1", "UInt", iconArgb, "Float", ringPenW, "Int", 2, "Ptr", penBuffer, "UInt") = 0) {
                pen := NumGet(penBuffer, 0, "Ptr")
                DllCall("gdiplus\GdipSetPenStartCap", "Ptr", pen, "Int", 2, "UInt")      ; round caps
                DllCall("gdiplus\GdipSetPenEndCap", "Ptr", pen, "Int", 2, "UInt")
                DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", pen, "Int", 2, "UInt")      ; round joins

                startAngle := gapStart + refreshArrowAngle
                DllCall("gdiplus\GdipDrawArc", "Ptr", graphics, "Ptr", pen, "Float", centerX - radius, "Float", centerY - radius, "Float", radius * 2, "Float", radius * 2, "Float", startAngle, "Float", sweepAngle, "UInt")

                endRadians := (startAngle + sweepAngle) * rad
                baseX := centerX + radius * Cos(endRadians)
                baseY := centerY + radius * Sin(endRadians)
                tangentX := -Sin(endRadians), tangentY := Cos(endRadians)
                radialX := Cos(endRadians), radialY := Sin(endRadians)
                headPoints := Buffer(24, 0)                                                   ; 3 x PointF triangle
                NumPut("Float", baseX + radialX * headHalfW, "Float", baseY + radialY * headHalfW
                     , "Float", baseX + tangentX * headLen, "Float", baseY + tangentY * headLen
                     , "Float", baseX - radialX * headHalfW, "Float", baseY - radialY * headHalfW, headPoints)
                headBrushBuffer := Buffer(A_PtrSize, 0)
                if (DllCall("gdiplus\GdipCreateSolidFill", "UInt", iconArgb, "Ptr", headBrushBuffer, "UInt") = 0) {
                    headBrush := NumGet(headBrushBuffer, 0, "Ptr")
                    DllCall("gdiplus\GdipFillPolygon", "Ptr", graphics, "Ptr", headBrush, "Ptr", headPoints, "Int", 3, "Int", 0, "UInt")
                    DllCall("gdiplus\GdipDeleteBrush", "Ptr", headBrush, "UInt")
                }
                edgePenBuffer := Buffer(A_PtrSize, 0)
                if (DllCall("gdiplus\GdipCreatePen1", "UInt", iconArgb, "Float", headEdgePenW, "Int", 2, "Ptr", edgePenBuffer, "UInt") = 0) {
                    edgePen := NumGet(edgePenBuffer, 0, "Ptr")
                    DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", edgePen, "Int", 2, "UInt")  ; round joins = softened corners
                    DllCall("gdiplus\GdipDrawPolygon", "Ptr", graphics, "Ptr", edgePen, "Ptr", headPoints, "Int", 3, "UInt")
                    DllCall("gdiplus\GdipDeletePen", "Ptr", edgePen, "UInt")
                }
                DllCall("gdiplus\GdipDeletePen", "Ptr", pen, "UInt")
            }

            ; click animation: a soft ripple leaves the icon on release - a thin ring that grows and fades out
            if (refreshKickStart > 0) {
                rippleProgress := (A_TickCount - refreshKickStart) / refreshKickDuration
                if (rippleProgress < 1.0) {
                    rippleRadius := radius + 1.0 + 9.0 * EaseOutCubic(rippleProgress)
                    rippleAlpha := Round(150 * (1.0 - rippleProgress) ** 1.5)
                    ripplePenBuffer := Buffer(A_PtrSize, 0)
                    if (DllCall("gdiplus\GdipCreatePen1", "UInt", (rippleAlpha << 24) | 0xFFFFFF, "Float", 1.5, "Int", 2, "Ptr", ripplePenBuffer, "UInt") = 0) {
                        ripplePen := NumGet(ripplePenBuffer, 0, "Ptr")
                        DllCall("gdiplus\GdipDrawEllipse", "Ptr", graphics, "Ptr", ripplePen, "Float", centerX - rippleRadius, "Float", centerY - rippleRadius, "Float", rippleRadius * 2, "Float", rippleRadius * 2, "UInt")
                        DllCall("gdiplus\GdipDeletePen", "Ptr", ripplePen, "UInt")
                    }
                }
            }

            if (refreshShowCheck) {
                ; Checkmark: sits inside the ring, centred on the ring's own centre (centerX, centerY), which is the
                ; middle of the finished icon, drawn with round caps and round joins like the
                ; ring, so arrow + check read as one icon. Colour = the Start button's green (208A4E).
                ; Box 14.5 x 10 px with 45-degree arms, 2.2 px stroke (elbow ~30% across), centred exactly on the ring centre.
                ; Hover effect of the check: it lights up from the Start button's normal green (208A4E) to the Start button's
                ; hover green (279B5A), driven by the SAME 130 ms fade as the grey hover background (000000 -> 3A3A3A), so
                ; the full-button hover effect and the check's own hover effect always run together (in and out).
                checkLight := Min(1.0, Integer("0x" SubStr(effectiveBg, 1, 2)) / 58.0)
                checkColor := procDisabled ? iconArgb : (0xFF000000 | Integer("0x" BlendHexColor("208A4E", "279B5A", checkLight)))
                checkPenBuffer := Buffer(A_PtrSize, 0)
                if (DllCall("gdiplus\GdipCreatePen1", "UInt", checkColor, "Float", 2.2, "Int", 2, "Ptr", checkPenBuffer, "UInt") = 0) {
                    checkPen := NumGet(checkPenBuffer, 0, "Ptr")
                    DllCall("gdiplus\GdipSetPenStartCap", "Ptr", checkPen, "Int", 2, "UInt")
                    DllCall("gdiplus\GdipSetPenEndCap", "Ptr", checkPen, "Int", 2, "UInt")
                    DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", checkPen, "Int", 2, "UInt")
                    checkPoints := Buffer(24, 0)
                    NumPut("Float", centerX - 7.83, "Float", centerY + 0.54
                         , "Float", centerX - 2.97, "Float", centerY + 5.4
                         , "Float", centerX + 7.83, "Float", centerY - 5.4, checkPoints)
                    DllCall("gdiplus\GdipDrawLines", "Ptr", graphics, "Ptr", checkPen, "Ptr", checkPoints, "Int", 3, "UInt")
                    DllCall("gdiplus\GdipDeletePen", "Ptr", checkPen, "UInt")
                }
            }
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics, "UInt")
        }
    }

    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBitmap, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", bitmap)
    DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
    return 1
}

DrawScrollTrack(drawItemStruct) {
    global selectorScrollThumb, selectorScrollThumbTrack, selectorScrollHoverTarget
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    targetHdc := NumGet(drawItemStruct, itemHwndOffset + A_PtrSize, "Ptr")
    rectOffset := itemHwndOffset + A_PtrSize * 2
    left := NumGet(drawItemStruct, rectOffset, "Int")
    top := NumGet(drawItemStruct, rectOffset + 4, "Int")
    width := NumGet(drawItemStruct, rectOffset + 8, "Int") - left
    height := NumGet(drawItemStruct, rectOffset + 12, "Int") - top
    if (width <= 0 || height <= 0 || !targetHdc)
        return 1

    memoryDc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", targetHdc, "Ptr")
    if (!memoryDc)
        return 1
    bitmap := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", targetHdc, "Int", width, "Int", height, "Ptr")
    if (!bitmap) {
        DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
        return 1
    }
    oldBitmap := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", bitmap, "Ptr")

    hovered := (selectorScrollHoverTarget = "thumb" || selectorScrollHoverTarget = "track")
    localRect := Buffer(16, 0)
    NumPut("Int", width, localRect, 8)
    NumPut("Int", height, localRect, 12)
    backgroundBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", hovered ? 0x00303030 : 0x00000000, "Ptr")
    DllCall("User32\FillRect", "Ptr", memoryDc, "Ptr", localRect, "Ptr", backgroundBrush)
    DllCall("Gdi32\DeleteObject", "Ptr", backgroundBrush)

    if (IsWindowValid(selectorScrollThumb) && IsWindowValid(selectorScrollThumbTrack)
        && DllCall("User32\IsWindowVisible", "Ptr", selectorScrollThumb.Hwnd, "Int")) {
        selectorScrollThumbTrack.GetPos(&trackX, &trackY)
        selectorScrollThumb.GetPos(&thumbX, &thumbY, &thumbW, &thumbH)
        relX := thumbX - trackX
        relY := thumbY - trackY
        if (thumbW >= 2 && thumbH >= 2)
            PaintScrollThumbPill(memoryDc, relX, relY, thumbW, thumbH, hovered)
    }

    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBitmap, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", bitmap)
    DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
    return 1
}

PaintScrollThumbPill(hdc, x, y, w, h, hovered) {
    global gdiplusToken
    inset := hovered ? 0 : 1
    px := x + inset
    pw := w - inset * 2
    if (pw < 2 || h < 2)
        return
    fillColor := hovered ? 0xFFDADADA : 0xFFFFFFFF
    drawn := false
    if (gdiplusToken) {
        graphicsBuffer := Buffer(A_PtrSize, 0)
        if (DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr", graphicsBuffer, "UInt") = 0) {
            graphics := NumGet(graphicsBuffer, 0, "UPtr")
            brush := 0
            path := 0
            try {
                DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4, "UInt")
                brushBuffer := Buffer(A_PtrSize, 0)
                pathBuffer := Buffer(A_PtrSize, 0)
                if (DllCall("gdiplus\GdipCreateSolidFill", "UInt", fillColor, "Ptr", brushBuffer, "UInt") = 0
                    && DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr", pathBuffer, "UInt") = 0) {
                    brush := NumGet(brushBuffer, 0, "UPtr")
                    path := NumGet(pathBuffer, 0, "UPtr")
                    d := pw + 0.0
                    left := px + 0.0, top := y + 0.0, right := px + pw, bottom := y + h
                    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", left, "Float", top, "Float", d, "Float", d, "Float", 180.0, "Float", 90.0, "UInt")
                    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", right - d, "Float", top, "Float", d, "Float", d, "Float", 270.0, "Float", 90.0, "UInt")
                    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", right - d, "Float", bottom - d, "Float", d, "Float", d, "Float", 0.0, "Float", 90.0, "UInt")
                    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", left, "Float", bottom - d, "Float", d, "Float", d, "Float", 90.0, "Float", 90.0, "UInt")
                    DllCall("gdiplus\GdipClosePathFigure", "Ptr", path, "UInt")
                    drawn := (DllCall("gdiplus\GdipFillPath", "Ptr", graphics, "Ptr", brush, "Ptr", path, "UInt") = 0)
                }
            } finally {
                if (path)
                    DllCall("gdiplus\GdipDeletePath", "Ptr", path, "UInt")
                if (brush)
                    DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush, "UInt")
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics, "UInt")
            }
        }
    }
    if (!drawn) {
        pill := DllCall("Gdi32\CreateRoundRectRgn", "Int", px, "Int", y, "Int", px + pw, "Int", y + h, "Int", pw, "Int", pw, "Ptr")
        pillBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", hovered ? 0x00DADADA : 0x00FFFFFF, "Ptr")
        DllCall("Gdi32\FillRgn", "Ptr", hdc, "Ptr", pill, "Ptr", pillBrush)
        DllCall("Gdi32\DeleteObject", "Ptr", pillBrush)
        DllCall("Gdi32\DeleteObject", "Ptr", pill)
    }
}

DrawScrollThumbWindow(drawItemStruct) {
    global selectorScrollHoverTarget
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    targetHdc := NumGet(drawItemStruct, itemHwndOffset + A_PtrSize, "Ptr")
    rectOffset := itemHwndOffset + A_PtrSize * 2
    left := NumGet(drawItemStruct, rectOffset, "Int")
    top := NumGet(drawItemStruct, rectOffset + 4, "Int")
    width := NumGet(drawItemStruct, rectOffset + 8, "Int") - left
    height := NumGet(drawItemStruct, rectOffset + 12, "Int") - top
    if (width <= 0 || height <= 0 || !targetHdc)
        return 1
    memoryDc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", targetHdc, "Ptr")
    if (!memoryDc)
        return 1
    bitmap := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", targetHdc, "Int", width, "Int", height, "Ptr")
    if (!bitmap) {
        DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
        return 1
    }
    oldBitmap := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", bitmap, "Ptr")
    hovered := (selectorScrollHoverTarget = "thumb" || selectorScrollHoverTarget = "track")
    localRect := Buffer(16, 0)
    NumPut("Int", width, localRect, 8)
    NumPut("Int", height, localRect, 12)
    backgroundBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", hovered ? 0x00303030 : 0x00000000, "Ptr")
    DllCall("User32\FillRect", "Ptr", memoryDc, "Ptr", localRect, "Ptr", backgroundBrush)
    DllCall("Gdi32\DeleteObject", "Ptr", backgroundBrush)
    PaintScrollThumbPill(memoryDc, 0, 0, width, height, hovered)
    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBitmap, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", bitmap)
    DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
    return 1
}

DrawScrollButton(drawItemStruct, isUpButton) {
    global selectorScrollHoverTarget, selectorScrollUpBtn, selectorScrollDownBtn, gdiplusToken
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    targetHdc := NumGet(drawItemStruct, itemHwndOffset + A_PtrSize, "Ptr")
    rectOffset := itemHwndOffset + A_PtrSize * 2
    left := NumGet(drawItemStruct, rectOffset, "Int")
    top := NumGet(drawItemStruct, rectOffset + 4, "Int")
    right := NumGet(drawItemStruct, rectOffset + 8, "Int")
    bottom := NumGet(drawItemStruct, rectOffset + 12, "Int")
    width := right - left
    height := bottom - top
    if (width <= 0 || height <= 0 || !targetHdc)
        return 1

    isHovered := (isUpButton && selectorScrollHoverTarget = "up") || (!isUpButton && selectorScrollHoverTarget = "down")
    isPressed := false
    if (GetKeyState("LButton", "P")) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mouseX, &mouseY)
        if (isUpButton && IsWindowValid(selectorScrollUpBtn)) {
            WinGetPos(&uX, &uY, &uW, &uH, "ahk_id " selectorScrollUpBtn.Hwnd)
            isPressed := (mouseX >= uX && mouseX < uX + uW && mouseY >= uY && mouseY < uY + uH)
        } else if (!isUpButton && IsWindowValid(selectorScrollDownBtn)) {
            WinGetPos(&dX, &dY, &dW, &dH, "ahk_id " selectorScrollDownBtn.Hwnd)
            isPressed := (mouseX >= dX && mouseX < dX + dW && mouseY >= dY && mouseY < dY + dH)
        }
    }

    bgColor := isPressed ? 0x00555555 : (isHovered ? 0x00303030 : 0x00000000)

    memoryDc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", targetHdc, "Ptr")
    layerDc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", targetHdc, "Ptr")
    bitmap := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", targetHdc, "Int", width, "Int", height, "Ptr")
    layerBitmap := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", targetHdc, "Int", width, "Int", height, "Ptr")
    if (!memoryDc || !layerDc || !bitmap || !layerBitmap) {
        for h in [bitmap, layerBitmap]
            if (h)
                DllCall("Gdi32\DeleteObject", "Ptr", h)
        for h in [memoryDc, layerDc]
            if (h)
                DllCall("Gdi32\DeleteDC", "Ptr", h)
        return 1
    }
    oldBitmap := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", bitmap, "Ptr")
    oldLayerBitmap := DllCall("Gdi32\SelectObject", "Ptr", layerDc, "Ptr", layerBitmap, "Ptr")

    localRect := Buffer(16, 0)
    NumPut("Int", width, localRect, 8)
    NumPut("Int", height, localRect, 12)
    brush := DllCall("Gdi32\CreateSolidBrush", "UInt", bgColor, "Ptr")
    DllCall("User32\FillRect", "Ptr", memoryDc, "Ptr", localRect, "Ptr", brush)
    DllCall("User32\FillRect", "Ptr", layerDc, "Ptr", localRect, "Ptr", brush)
    DllCall("Gdi32\DeleteObject", "Ptr", brush)

    ; The arrow is drawn exactly as before, on its own layer that has the button's background colour.
    DllCall("Gdi32\SetBkMode", "Ptr", layerDc, "Int", 1)
    DllCall("Gdi32\SetTextColor", "Ptr", layerDc, "UInt", 0x00FFFFFF)
    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(11 * DllCall("Gdi32\GetDeviceCaps", "Ptr", targetHdc, "Int", 90) / 72), "Int", 0, "Int", 0, "Int", 0, "Int", 600, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", "Segoe UI", "Ptr")
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", layerDc, "Ptr", hFont, "Ptr")
    glyph := isUpButton ? "⌃" : "⌄"
    offsetX := -Round(width * 0.025) - Round(width * 0.01)
    offsetY := isUpButton ? Round(height * 0.20) : -Round(height * 0.27)
    textRect := Buffer(16, 0)
    NumPut("Int", offsetX, textRect, 0)
    NumPut("Int", offsetY, textRect, 4)
    NumPut("Int", width + offsetX, textRect, 8)
    NumPut("Int", height + offsetY, textRect, 12)
    DllCall("User32\DrawTextW", "Ptr", layerDc, "Str", glyph, "Int", -1, "Ptr", textRect, "UInt", 0x00000025)
    DllCall("Gdi32\SelectObject", "Ptr", layerDc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)

    ; Click animation: the layer is scaled about the button centre (the rest of the button is the same colour).
    scale := GetIconScale(isUpButton ? "up" : "down")
    if (Abs(scale - 1.0) < 0.004) {
        DllCall("Gdi32\BitBlt", "Ptr", memoryDc, "Int", 0, "Int", 0, "Int", width, "Int", height, "Ptr", layerDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    } else {
        destW := Max(1, Round(width * scale)), destH := Max(1, Round(height * scale))
        destX := Round((width - destW) / 2), destY := Round((height - destH) / 2)
        DllCall("Gdi32\SetStretchBltMode", "Ptr", memoryDc, "Int", 4)
        DllCall("Gdi32\SetBrushOrgEx", "Ptr", memoryDc, "Int", 0, "Int", 0, "Ptr", 0)
        DllCall("Gdi32\StretchBlt", "Ptr", memoryDc, "Int", destX, "Int", destY, "Int", destW, "Int", destH, "Ptr", layerDc, "Int", 0, "Int", 0, "Int", width, "Int", height, "UInt", 0x00CC0020)
    }

    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBitmap, "Ptr")
    DllCall("Gdi32\SelectObject", "Ptr", layerDc, "Ptr", oldLayerBitmap, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", bitmap)
    DllCall("Gdi32\DeleteObject", "Ptr", layerBitmap)
    DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
    DllCall("Gdi32\DeleteDC", "Ptr", layerDc)
    return 1
}

MainGuiMoved(wParam, lParam, msg, hwnd) {
    global mainGui, isExiting, isWindowMoving
    if (isExiting || !IsSet(mainGui) || !mainGui || isWindowMoving)
        return
    if (hwnd = mainGui.Hwnd)
        PositionChildWindows()
}

; Re-bases every marquee on the current display refresh, so refreshes missed during a stall are dropped, not caught up.
ResyncMarqueeClocks() {
    global marqueeLastTick, riskTitleLastTick, dropdownMarqueeLastTick, isMarqueeActive, riskTitleActive, dropdownMarqueeIndex
    stamp := FrameStamp()
    if (isMarqueeActive)
        marqueeLastTick := stamp
    if (riskTitleActive)
        riskTitleLastTick := stamp
    if (dropdownMarqueeIndex != -1)
        dropdownMarqueeLastTick := stamp
}

; PRESS-SHIMMER FIX: while the Start / Stop button animates, this thread sat in Sleep(8) and repainted the pill (several ms per
; paint) between the marquee timer's turns, so one display refresh of the scrolling status line was skipped = a visible hitch on
; every press. Instead of sleeping, the animation now serves the marquees itself, paced by the display refresh (DwmFlush), exactly
; like MarqueeMaster does; the button paint then happens right after a marquee frame, inside the same refresh interval.
ServiceMarqueesDuringAnimation() {
    global marqueeTimerRunning, isMarqueeActive, marqueePauseUntil, dropdownMarqueeIndex, dropdownMarqueePauseUntil
    global riskViewActive, riskViewBusy, riskTitleActive, riskTitlePauseUntil, isExiting
    if (isExiting || riskViewBusy) {
        Sleep(8)
        return
    }
    now := NowMs()
    moving := (marqueeTimerRunning && isMarqueeActive && now >= marqueePauseUntil)
        || (!riskViewActive && dropdownMarqueeIndex != -1 && now >= dropdownMarqueePauseUntil)
        || (riskViewActive && riskTitleActive && now >= riskTitlePauseUntil)
    if (!moving) {
        Sleep(8)
        return
    }
    if (DllCall("Dwmapi\DwmFlush", "Int") != 0)
        Sleep(1)
    UpdateMarquee()
    if (!riskViewActive)
        UpdateDropdownMarquee()
    UpdateRiskTitleMarquee()
    Sleep(-1)
}

; UNIVERSAL PRESS-SHIMMER FIX (same technique as Start / Stop / Continue / Cancel): every button press / release / hover paint first
; waits for the next display refresh and gives the moving marquees their frame, so the button's GDI work always happens right AFTER a
; marquee frame, inside a fresh refresh interval, and can never push the marquee's next frame past its refresh (= the 1-frame shake).
; Does nothing when no marquee is moving.
MarqueeFrameAlign() {
    global marqueeTimerRunning, isMarqueeActive, marqueePauseUntil, dropdownMarqueeIndex, dropdownMarqueePauseUntil
    global riskViewActive, riskViewBusy, riskTitleActive, riskTitlePauseUntil, isExiting
    if (isExiting || riskViewBusy)
        return
    now := NowMs()
    if ((marqueeTimerRunning && isMarqueeActive && now >= marqueePauseUntil)
        || (!riskViewActive && dropdownMarqueeIndex != -1 && now >= dropdownMarqueePauseUntil)
        || (riskViewActive && riskTitleActive && now >= riskTitlePauseUntil))
        ServiceMarqueesDuringAnimation()
}

; Waits ms milliseconds WITHOUT stalling the marquees (replacement for Sleep(ms) in click paths).
MarqueeSafeWait(ms) {
    t0 := A_TickCount
    while (A_TickCount - t0 < ms)
        ServiceMarqueesDuringAnimation()
    ResyncMarqueeClocks()
}

AnimateActionButton(pressed, onComplete := "") {
    global actionBtn, mainGui, isActionAnimating, currentAnimId, actionBtnFontSize, actionBtnBaseFontSize, actionBtnScale
    global marqueeTimerRunning, isMarqueeActive, marqueePauseUntil
    if (!IsSet(mainGui) || !mainGui)
        return

    local thisAnimId := ++currentAnimId
    isActionAnimating := true
    local callbackFired := false

    try {
        ; The window itself never moves, resizes or changes its region during the animation (each of those made Windows re-print the
        ; whole composited window tree, which showed up as a 1-frame glitch of the scrolling status line on every Start press).
        ; Only the scale variable changes; the pill + label are redrawn smaller INSIDE the fixed window with a direct paint.
        scaleStart := actionBtnScale
        scaleEnd := pressed ? 0.94 : 1.0
        ; ALIGN TO THE REFRESH (same as AnimateRiskButton): if the status line is moving, wait for the next refresh and give it its
        ; frame first, so the button paints cannot push the status line's next frame past its refresh.
        if (marqueeTimerRunning && isMarqueeActive && NowMs() >= marqueePauseUntil)
            ServiceMarqueesDuringAnimation()
        startTime := A_TickCount, duration := 45

        Loop {
            if (thisAnimId != currentAnimId)
                return
            elapsed := A_TickCount - startTime
            progress := Min(elapsed / duration, 1.0)
            eased := 1 - (1 - progress) ** 3
            currScale := scaleStart + (scaleEnd - scaleStart) * eased
            actionBtnScale := currScale
            actionBtnFontSize := (currScale >= 0.999) ? actionBtnBaseFontSize : Max(14, Round(actionBtnBaseFontSize * currScale, 1))
            RepaintActionButtonNoErase()

            if (progress >= 1.0)
                break
            ServiceMarqueesDuringAnimation()
        }

        if (thisAnimId != currentAnimId)
            return

        ; (the last loop pass already painted the final scale: no extra repaint here, it only delayed the next marquee frame)
        if (!pressed) {
            actionBtnScale := 1.0
            actionBtnFontSize := actionBtnBaseFontSize
        }
        ; the animation stalls the marquee's frames; drop the missed refreshes instead of catching up
        ResyncMarqueeClocks()

        if (!pressed && IsObject(onComplete)) {
            callbackFired := true
            onComplete()
        }
    } finally {
        if (thisAnimId = currentAnimId)
            isActionAnimating := false
        ; A newer press cancels this animation, but the CLICK it belongs to must still happen (spamming Enter used to drop clicks).
        if (!pressed && !callbackFired && IsObject(onComplete)) {
            callbackFired := true
            onComplete()
        }
    }
}

HandleLeftButtonDown(wParam, lParam, msg, hwnd) {
    global mainGui, titleBar, versionText, processSelect, selectGui, selectorFrameGui, selectorPopup, selectorList, selectorScrollUpBtn, selectorScrollDownBtn, selectorScrollThumb, selectorScrollThumbTrack, minBtn, closeBtn, refreshButton, actionGui, actionBtn, isRunning, pressedControl, isExiting, selectorDisplayedOptions
    global dropdownToggleCooldown, refreshIsLocked, isGameSearchFocused, isSearchMenuOpen
    global updateBtn, updateSep
    if (isExiting || !IsSet(mainGui) || !mainGui || !IsOwnGuiWindow(hwnd))
        return
    if (riskViewActive) {
        RiskViewLeftDown(hwnd)
        return
    }
    ; The Edit menu is open and this click is outside it: this single click only closes the menu.
    ; (Handled here because a click on the window background starts the window-drag loop, which
    ; would otherwise keep the menu timer from ever seeing the click.)
    if (isSearchMenuOpen) {
        CloseSearchMenu(false)
        return 0
    }
    
    if (hwnd = mainGui.Hwnd || hwnd = titleBar.Hwnd || hwnd = versionText.Hwnd || hwnd = updateSep.Hwnd) {
        if (isGameSearchFocused) {
            isGameSearchFocused := false
            DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
            CloseProcessSelector()
        }
        ; Own drag loop instead of the system one (WM_NCLBUTTONDOWN / HTCAPTION): the system loop is modal and keeps
        ; the script's timers from running for as long as the button is held, which froze the marquee.
        StartWindowDrag()
        return
    }

    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseX, &mouseY, &windowUnderCursor, &hoveredControl, 2)
    
    WinGetPos(&selectX, &selectY, &selectW, &selectH, "ahk_id " selectGui.Hwnd)
    processSelect.GetPos(&editX, &editY, &editW, &editH)
    
    screenPoint := Buffer(8, 0)
    NumPut("Int", mouseX, screenPoint, 0)
    NumPut("Int", mouseY, screenPoint, 4)
    DllCall("User32\ScreenToClient", "Ptr", selectGui.Hwnd, "Ptr", screenPoint)
    localX := NumGet(screenPoint, 0, "Int")
    localY := NumGet(screenPoint, 4, "Int")
    
    ; The right padding of the search box is outside the edit control now, but a click there still counts as a click in the box.
    searchRightPad := 10                          ; its own value (click area right of the edit)
    clickInsideRealEditBox := (localX >= editX && localX <= editX + editW + searchRightPad && localY >= editY && localY <= editY + editH)
    clickInsideSelectorContainer := (mouseX >= selectX && mouseX < selectX + selectW && mouseY >= selectY && mouseY < selectY + selectH)
    
    clickOnScrollbar := IsProcessSelectorOpen() && selectorDisplayedOptions.Length > 3
        && ((IsWindowValid(selectorScrollUpBtn) && hoveredControl = selectorScrollUpBtn.Hwnd)
            || (IsWindowValid(selectorScrollDownBtn) && hoveredControl = selectorScrollDownBtn.Hwnd)
            || (IsWindowValid(selectorScrollThumb) && hoveredControl = selectorScrollThumb.Hwnd)
            || (IsWindowValid(selectorScrollThumbTrack) && hoveredControl = selectorScrollThumbTrack.Hwnd))
            
    clickOnDropdown := IsProcessSelectorOpen() && (windowUnderCursor = selectorFrameGui.Hwnd || (IsWindowValid(selectorPopup) && windowUnderCursor = selectorPopup.Hwnd)
        || (IsWindowValid(selectorList) && (hwnd = selectorList.Hwnd || hoveredControl = selectorList.Hwnd))
        || clickOnScrollbar)
        
    if (clickOnDropdown) {
        DropdownZOrderGuard()
        return 0          ; swallow: the list box must not take focus from the search box
    }
        
    if (clickInsideRealEditBox || hoveredControl = processSelect.Hwnd) {
        if (A_TickCount > dropdownToggleCooldown) {
            dropdownToggleCooldown := A_TickCount + 300
            if (!DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd)) {
                if (!IsProcessSelectorOpen())
                    SetTimer(OpenProcessSelector, -1)
            }
            SetTimer(EnsureGameSearchFocus, -1)
        }
        return
    }

    if (IsProcessSelectorOpen()) {
        dropdownOutside := true
        if (IsWindowValid(selectorFrameGui)) {
            WinGetPos(&fX, &fY, &fW, &fH, "ahk_id " selectorFrameGui.Hwnd)
            if (mouseX >= fX && mouseX < fX + fW && mouseY >= fY && mouseY < fY + fH)
                dropdownOutside := false
        }
        if (clickInsideSelectorContainer)
            dropdownOutside := false

        if (dropdownOutside) {
            CloseProcessSelector()
            if (isGameSearchFocused) {
                isGameSearchFocused := false
                DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
            }
        }
    } else {
        if (isGameSearchFocused) {
            isGameSearchFocused := false
            DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
            CloseProcessSelector()
        }
    }

    pressedControl := ""
    if (hoveredControl = minBtn.Hwnd || hoveredControl = closeBtn.Hwnd || (IsWindowValid(refreshButton) && (hoveredControl = refreshButton.Hwnd || hwnd = refreshButton.Hwnd)))
        MarqueeFrameAlign()
    if (hoveredControl = minBtn.Hwnd) {
        pressedControl := "min"
        SetTopButtonBg("min", "555555")
        PressIcon("min")
    } else if (hoveredControl = closeBtn.Hwnd) {
        pressedControl := "close"
        SetTopButtonBg("close", "B30710")
        PressIcon("close")
    } else if (IsWindowValid(refreshButton) && (hoveredControl = refreshButton.Hwnd || hwnd = refreshButton.Hwnd)) {
        if (refreshIsLocked || connLost)
            return                                 ; connection lost: Refresh is frozen (no press, no message)
        if (RefreshDisabled()) {
            ; Refresh is refused (process active = exe / Rich Presence, or the 60 s cooldown is still running): NO press colour,
            ; no ripple. FLICKER FIX: in the cooldown every click used to snap the button to the pressed grey, restart the ripple and
            ; start the grey -> hover fade again; clicking fast interrupted each fade half way, so the button flashed between the
            ; colours. The click is only remembered so the message can show when the mouse is released over the button.
            pressedControl := "refreshblocked"
            return
        }
        pressedControl := "refresh"
        StartRefreshButtonStyle("pressed")
    } else if (IsWindowValid(updateBtn) && (hoveredControl = updateBtn.Hwnd || hwnd = updateBtn.Hwnd)) {
        if (!UpdateBtnClickable())
            return                                 ; connection lost / check or download running: Update is frozen (no press, no action)
        pressedControl := "update"
    } else if (hoveredControl = actionGui.Hwnd || hoveredControl = actionBtn.Hwnd) {
        if (connLost)
            return                                 ; connection lost: Start is frozen (no press, no animation)
        pressedControl := "action"
        SetActionColor(isRunning ? "9A1E15" : "186B3C", false)
        AnimateActionButton(true)
    } else if (clickInsideSelectorContainer && !clickInsideRealEditBox) {
        return 0
    } else if (!clickInsideRealEditBox && !clickOnDropdown && !clickInsideSelectorContainer) {
        CloseProcessSelector()
        DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
        return 0
    }
}

; Terms-of-service icon (top left): press = brighter icon, release over the icon = open Discord's self-bot page.
IsTosIconHwnd(h) {
    global riskTosGui, riskTosCtl
    return IsWindowValid(riskTosGui) && IsWindowValid(riskTosCtl) && h && (h = riskTosGui.Hwnd || h = riskTosCtl.Hwnd)
}

TosIconDown() {
    global pressedControl, tosIconPressed
    pressedControl := "tos"
    tosIconPressed := true                   ; darker blurple while the button is held (no shrinking)
    PaintTosDirect()
}

TosIconUp(hoveredControl) {
    global tosIconPressed, tosPageUrl
    tosIconPressed := false
    if (IsTosIconHwnd(hoveredControl))
        try Run(tosPageUrl)                  ; no after-click ripple: only the hover fade and the held (pressed) colour remain
    PaintTosDirect()
}

; Paints the logo straight onto the control's own DC, WITHOUT invalidating anything (same technique as the refresh
; button's spin, see PaintRefreshButtonDirect): the main window is layered + composited, so InvalidateRect / UpdateWindow
; on a child makes Windows re-print the whole window tree, which showed up as flicker and stutter.
PaintTosDirect() {
    global riskTosCtl, riskViewActive, isExiting, isWindowVisible, mainGui
    if (isExiting || !isWindowVisible || !riskViewActive || !IsWindowValid(riskTosCtl) || !IsWindowValid(mainGui))
        return
    if (DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int") || !DllCall("User32\IsWindowVisible", "Ptr", riskTosCtl.Hwnd, "Int"))
        return
    rc := Buffer(16, 0)
    if (!DllCall("User32\GetClientRect", "Ptr", riskTosCtl.Hwnd, "Ptr", rc, "Int"))
        return
    hdc := DllCall("User32\GetDC", "Ptr", riskTosCtl.Hwnd, "Ptr")
    if (!hdc)
        return
    ; Minimal DRAWITEMSTRUCT: only the hDC and rcItem fields are read by DrawRiskTosIcon.
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    fake := Buffer(itemHwndOffset + A_PtrSize * 2 + 16 + A_PtrSize, 0)
    NumPut("Ptr", hdc, fake, itemHwndOffset + A_PtrSize)
    rectOffset := itemHwndOffset + A_PtrSize * 2
    NumPut("Int", 0, "Int", 0, "Int", NumGet(rc, 8, "Int"), "Int", NumGet(rc, 12, "Int"), fake, rectOffset)
    DrawRiskTosIcon(fake)
    DllCall("User32\ReleaseDC", "Ptr", riskTosCtl.Hwnd, "Ptr", hdc)
}

; Hover colour: fades grey -> Discord blurple over 130 ms (smoothstep), like the refresh button's hover fade.
TosHoverValue() {
    global tosHoverFrom, tosHoverTo, tosHoverStartedAt, tosHoverDuration
    p := Min(1.0, (A_TickCount - tosHoverStartedAt) / tosHoverDuration)
    return tosHoverFrom + (tosHoverTo - tosHoverFrom) * (p * p * (3 - 2 * p))
}

TosHoverPoll() {
    global tosHoverFrom, tosHoverTo, tosHoverStartedAt, tosIconPressed
    if (tosIconPressed)
        return                               ; while the button is held the colour stays as it is
    MouseGetPos(,,, &hovered, 2)
    want := IsTosIconHwnd(hovered) ? 1 : 0
    if (want = tosHoverTo)
        return
    tosHoverFrom := TosHoverValue()
    tosHoverTo := want
    tosHoverStartedAt := A_TickCount
    SetTimer(TosAnimTick, 16)
}

TosAnimTick(*) {
    global tosHoverStartedAt, tosHoverDuration, tosRippleStart, tosRippleDuration, riskTosCtl
    PaintTosDirect()
    hoverDone := (A_TickCount - tosHoverStartedAt >= tosHoverDuration)
    rippleDone := (tosRippleStart = 0 || A_TickCount - tosRippleStart >= tosRippleDuration)
    if (rippleDone && tosRippleStart != 0) {
        tosRippleStart := 0
        PaintTosDirect()
    }
    if (hoverDone && rippleDone)
        SetTimer(TosAnimTick, 0)
}

TosResetState() {
    global tosHoverFrom, tosHoverTo, tosHoverStartedAt, tosRippleStart, tosIconPressed
    SetTimer(TosAnimTick, 0)
    tosHoverFrom := 0.0, tosHoverTo := 0, tosHoverStartedAt := 0, tosRippleStart := 0, tosIconPressed := false
}

; While pressed the Start / Stop button shrinks to 94 %, so a click near its edge ends with the cursor OUTSIDE the shrunk window:
; the release then looked like "released elsewhere" and the click was thrown away (needed a second click). The release is
; therefore also tested against the button's normal size (same geometry as AnimateActionButton).
CursorOverActionButtonNormalSize() {
    global mainGui
    try {
        WinGetPos(&mx, &my, &mw, &mh, "ahk_id " mainGui.Hwnd)
        GetMainLayoutY(mh, &textY, &actionY)
        actionX := actionBtnPosX
        CoordMode("Mouse", "Screen")
        MouseGetPos(&cx, &cy)
        return cx >= mx + actionX && cx < mx + actionX + actionBtnPosW && cy >= my + actionY && cy < my + actionY + actionBtnPosH
    }
    return false
}

HandleLeftButtonUp(wParam, lParam, msg, hwnd) {
    global mainGui, pressedControl, selectorFrameGui, selectorPopup, selectorList, minBtn, closeBtn, refreshButton, actionGui, actionBtn, isRunning, isExiting, refreshIsLocked, selectGui, lastHover
    global updateBtn
    if (isExiting || !IsSet(mainGui) || !mainGui || !IsOwnGuiWindow(hwnd))
        return

    MouseGetPos(,,, &hoveredControl, 2)
    if (pressedControl = "")
        return

    activeTarget := pressedControl
    pressedControl := ""
    if (activeTarget = "min" || activeTarget = "close" || activeTarget = "refresh" || activeTarget = "tos")
        MarqueeFrameAlign()

    if (activeTarget = "tos") {
        TosIconUp(hoveredControl)
    } else if (activeTarget = "update") {
        if (IsWindowValid(updateBtn) && hoveredControl = updateBtn.Hwnd)
            UpdateButtonClicked()
    } else if (activeTarget = "min" && hoveredControl = minBtn.Hwnd) {
        SetTopButtonBg("min", "3A3A3A")
        MinimizeWindow()
    } else if (activeTarget = "close" && hoveredControl = closeBtn.Hwnd) {
        SetTopButtonBg("close", "E50914")
        CloseApplication()
    } else if (activeTarget = "action" && (hoveredControl = actionGui.Hwnd || hoveredControl = actionBtn.Hwnd || CursorOverActionButtonNormalSize())) {
        SetActionColor(isRunning ? "D12F26" : "279B5A", false)
        AnimateActionButton(false, QueueToggle)
    } else if (activeTarget = "refreshblocked") {
        ; Press started while a process was active: no colour, no ripple, no spin. Only the message is shown.
        CoordMode("Mouse", "Screen")
        MouseGetPos(&bX, &bY)
        if (IsWindowValid(refreshButton)) {
            WinGetPos(&brX, &brY, &brW, &brH, "ahk_id " refreshButton.Hwnd)
            if (bX >= brX && bX < brX + brW && bY >= brY && bY < brY + brH) {
                if (!RefreshBlockedWhileActive() && RefreshCooldownMs() > 0)   ; process message first, else the cooldown message
                    RefreshProcessList()             ; (shows "Refresh available in N seconds." - rebuilt only when the text changes)
            }
        }
        ; (no hover re-check / repaint here: nothing about the button changed, and repainting on every click made it flicker)
    } else if (activeTarget = "refresh") {
        if (!refreshIsLocked) {
            CoordMode("Mouse", "Screen")
            MouseGetPos(&mX, &mY)
            if (IsWindowValid(refreshButton)) {
                WinGetPos(&rX, &rY, &rW, &rH, "ahk_id " refreshButton.Hwnd)
                if (mX >= rX && mX < rX + rW && mY >= rY && mY < rY + rH) {
                    if (RefreshBlockedWhileActive()) {   ; no ripple, no spin, no dropdown change
                        StartRefreshButtonStyle("hover") ; (a process became active during the press: this resets the colour to plain)
                        return
                    }
                    CloseProcessSelector()
                    isGameSearchFocused := false
                    if (IsWindowValid(mainGui))
                        DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
                    StartRefreshKick()
                    RefreshProcessList()
                    ; Only animate back to the hover colour when no refresh started; a started refresh
                    ; keeps the locked colour (same as the pressed colour) with no colour change at all.
                    if (!refreshIsLocked)
                        StartRefreshButtonStyle("hover")
                } else {
                    StartRefreshButtonStyle("normal")
                }
            } else {
                StartRefreshButtonStyle("normal")
            }
        }
    } else {
        if (activeTarget = "action")
            AnimateActionButton(false)
        UpdateButtonHover()
    }
}

UpdateButtonHover() {
    global minBtn, closeBtn, refreshButton, actionBtn, actionGui, isRunning, lastHover, mainGui, isWindowVisible, isExiting, pressedControl, isActionAnimating, refreshIsLocked, refreshButtonBgCurrent
    global updateBtn, updateHovered
    if (isExiting || !isWindowVisible || !IsSet(mainGui) || !mainGui || pressedControl != "" || isActionAnimating || IsContextMenuOpen())
        return

    MouseGetPos(,,, &hoveredControl, 2)
    isActionHovered := (hoveredControl = actionGui.Hwnd || hoveredControl = actionBtn.Hwnd) && !connLost
    ; While a created process is active (exe or Rich Presence) the refresh button is unavailable: it never counts as hovered,
    ; so it shows no hover colour. (Its "not allowed" cursor is chosen separately in OnSetCursor and is unchanged.)
    refreshHovered := IsWindowValid(refreshButton) && hoveredControl = refreshButton.Hwnd && !RefreshDisabled()
    updHovered := IsWindowValid(updateBtn) && hoveredControl = updateBtn.Hwnd && UpdateBtnClickable()
    currentHoverState := isActionHovered ? 1 : (hoveredControl = minBtn.Hwnd ? 2 : (hoveredControl = closeBtn.Hwnd ? 3 : (refreshHovered ? 4 : (updHovered ? 5 : 0))))
    if (currentHoverState = lastHover)
        return
    if (updHovered != updateHovered) {
        updateHovered := updHovered
        RedrawUpdateBtn()
    }

    SetTopButtonBg("min", hoveredControl = minBtn.Hwnd ? "3A3A3A" : "000000")
    SetTopButtonBg("close", hoveredControl = closeBtn.Hwnd ? "E50914" : "000000")
    if (refreshIsLocked) {
        refreshButtonBgCurrent := "555555"
        SetTimer(AnimateRefreshButtonStyle, 0)
    } else {
        StartRefreshButtonStyle(refreshHovered ? "hover" : "normal")
    }
    SetActionColor(isRunning ? (isActionHovered ? "D12F26" : "B42318") : (isActionHovered ? "279B5A" : "208A4E"))
    RepaintRefreshButtonNoErase()
    RepaintActionButtonNoErase()
    lastHover := currentHoverState
}

; =====================================================================================================================
; UPDATER
;   Update button (header, right of the version text):  click = check;  new version found = the button becomes "Download";
;   click again = download -> verify SHA-256 -> replace this file -> restart.  Everything runs without blocking the window
;   (asynchronous HTTP + a polling timer, like the game-list download), and everything is frozen while the connection is lost.
; =====================================================================================================================
InitUpdaterLayout() {
    global appVersion, appChannel, verTextX, verTextW, updSepX, updSepW, updBtnX, updBtnW, titleBarX, titleBarW, minBtnX
    f := A_ScreenDPI / 96
    W := (t) => Ceil(GetTextWidth(t, "Segoe UI Semibold", 12, 600) / f)
    verTextW := W(appVersion " " appChannel) + 6
    updSepX := verTextX + verTextW
    updBtnX := updSepX + updSepW
    updBtnW := Max(W("Update"), W("Download"), W("Checking..."), W("Downloading..."), W("Installing...")) + 16
    titleBarX := updBtnX + updBtnW                       ; the drag bar starts after the button
    titleBarW := minBtnX - titleBarX
}

UpdateBtnLabel() {
    global updateState
    switch updateState {
        case "checking":    return "Checking..."
        case "available":   return "Download"
        case "downloading": return "Downloading..."
        case "installing":  return "Installing..."
    }
    return "Update"
}

UpdateBtnClickable() {
    global updateState, riskViewActive
    return !connLost && !riskViewActive && (updateState = "idle" || updateState = "available")
}

UpdateBtnTextHex() {
    global updateState, updateHovered
    if (connLost || updateState = "checking" || updateState = "downloading" || updateState = "installing")
        return "5A5A5A"                                   ; frozen
    if (updateState = "available")
        return updateHovered ? "2FB36C" : "208A4E"        ; a new version is waiting: green
    return updateHovered ? "FFFFFF" : "A0A0A0"
}

RedrawUpdateBtn() {
    global updateBtn, isExiting
    if (isExiting || !IsWindowValid(updateBtn))
        return
    label := UpdateBtnLabel()
    if (updateBtn.Text != label)
        updateBtn.Text := label
    updateBtn.Redraw()
}

SetUpdateState(state) {
    global updateState, updateHovered
    updateState := state
    if (!UpdateBtnClickable())
        updateHovered := false
    RedrawUpdateBtn()
}

UpdaterConnectionChanged() {
    global updateState, updateReq, updateInfo, updateFile, updateHovered
    if (connLost) {
        SetTimer(UpdateCheckPoll, 0)
        SetTimer(UpdateDownloadPoll, 0)
        if (updateState = "checking" || updateState = "downloading") {
            try updateReq.abort()
            updateReq := ""
            try FileDelete(A_Temp "\Ragnious_update.download")
            updateState := IsObject(updateInfo) && updateState = "downloading" ? "available" : "idle"
        }
        updateHovered := false
    }
    RedrawUpdateBtn()
}

NewUpdateHttp() {
    for cls in ["MSXML2.XMLHTTP.6.1", "MSXML2.XMLHTTP", "WinHttp.WinHttpRequest.5.1", "Microsoft.XMLHTTP"] {
        try {
            req := ComObject(cls)
            if IsObject(req)
                return req
        }
    }
    return ""
}

UpdateButtonClicked() {
    global updateState
    if (!UpdateBtnClickable())
        return
    if (updateState = "available")
        StartUpdateDownload()
    else
        StartUpdateCheck()
}

StartUpdateCheck() {
    global updateInfoUrl, updateReq, updateReqStart, updateInfo
    if (updateInfoUrl = "") {
        SetStatus("Updater is not set up yet: set updateInfoUrl in the script.", "error")
        return
    }
    SetUpdateState("checking")
    SetStatus("Checking for updates...", "ready")
    updateInfo := ""
    req := NewUpdateHttp()
    if (!IsObject(req)) {
        UpdateFailed("Update check failed: no HTTP component on this system.")
        return
    }
    try {
        url := updateInfoUrl (InStr(updateInfoUrl, "?") ? "&" : "?") "nocache=" A_TickCount   ; never a cached copy
        req.Open("GET", url, true)
        req.SetRequestHeader("Cache-Control", "no-cache")
        req.SetRequestHeader("User-Agent", "Ragnious-Updater")
        req.Send()
    } catch {
        UpdateFailed("Update check failed: could not reach the update server.")
        return
    }
    updateReq := req
    updateReqStart := A_TickCount
    SetTimer(UpdateCheckPoll, 60)
}

UpdateFailed(msg) {
    global updateInfo, updateReq
    SetTimer(UpdateCheckPoll, 0)
    SetTimer(UpdateDownloadPoll, 0)
    try updateReq.abort()
    updateReq := ""
    SetUpdateState(IsObject(updateInfo) ? "available" : "idle")
    if (!IsInternetAvailable())
        SetInternetLostStatus()
    else
        SetStatus(msg, "error")
}

UpdateCheckPoll(*) {
    global updateState, updateReq, updateReqStart, updateInfo, appVersion, isExiting
    if (isExiting || updateState != "checking" || !IsObject(updateReq)) {
        SetTimer(UpdateCheckPoll, 0)
        return
    }
    try {
        if (updateReq.readyState != 4) {
            if (A_TickCount - updateReqStart > 20000)
                UpdateFailed("Update check failed: the update server did not answer in time.")
            return
        }
        status := updateReq.status
        text := updateReq.responseText
    } catch {
        UpdateFailed("Update check failed: could not read the answer of the update server.")
        return
    }
    SetTimer(UpdateCheckPoll, 0)
    updateReq := ""
    if (status != 200) {
        UpdateFailed("Update check failed: the update server answered HTTP " status ".")
        return
    }
    info := ParseUpdateInfo(text)
    if (!IsObject(info)) {
        UpdateFailed("Update check failed: the update information is invalid.")
        return
    }
    if (VerCompare(info["version"], appVersion) > 0) {
        updateInfo := info
        SetUpdateState("available")
        SetStatus("New version " info["version"] " is available (you have " appVersion "). Press Download to get it.", "stopped")
    } else {
        updateInfo := ""
        SetUpdateState("idle")
        SetStatus("You already have the latest version (" appVersion ").", "ready")
    }
}

; version=..  url=..  sha256=..   (one per line). Returns a Map, or "" when something is missing or malformed.
ParseUpdateInfo(text) {
    if (SubStr(text, 1, 1) = Chr(0xFEFF))
        text := SubStr(text, 2)
    m := Map()
    for line in StrSplit(text, "`n", "`r")
        if RegExMatch(line, "^\s*(\w+)\s*=\s*(.+?)\s*$", &r)
            m[StrLower(r[1])] := r[2]
    if (!m.Has("version") || !RegExMatch(m["version"], "^\d+(\.\d+){1,3}$"))
        return ""
    if (!m.Has("url") || !RegExMatch(m["url"], "i)^https://\S+$"))
        return ""
    if (!m.Has("sha256") || !RegExMatch(m["sha256"], "^[0-9A-Fa-f]{64}$"))
        return ""
    return m
}

StartUpdateDownload() {
    global updateInfo, updateReq, updateReqStart, isRunning, rpcConnecting, helperLaunching
    if (!IsObject(updateInfo))
        return
    if (isRunning || rpcConnecting || helperLaunching) {
        SetStatus("Stop the running process first, then download the update.", "stopped")   ; installing restarts the application
        return
    }
    SetUpdateState("downloading")
    SetStatus("Downloading version " updateInfo["version"] "...", "ready")
    req := NewUpdateHttp()
    if (!IsObject(req)) {
        UpdateFailed("Download failed: no HTTP component on this system.")
        return
    }
    try {
        req.Open("GET", updateInfo["url"], true)
        req.SetRequestHeader("User-Agent", "Ragnious-Updater")
        req.Send()
    } catch {
        UpdateFailed("Download failed: could not reach the download server.")
        return
    }
    updateReq := req
    updateReqStart := A_TickCount
    SetTimer(UpdateDownloadPoll, 80)
}

UpdateDownloadPoll(*) {
    global updateState, updateReq, updateReqStart, updateInfo, updateFile, isExiting
    if (isExiting || updateState != "downloading" || !IsObject(updateReq)) {
        SetTimer(UpdateDownloadPoll, 0)
        return
    }
    file := A_Temp "\Ragnious_update.download"
    try {
        if (updateReq.readyState != 4) {
            if (A_TickCount - updateReqStart > 600000)
                UpdateFailed("Download failed: it took too long.")
            return
        }
        status := updateReq.status
        if (status != 200) {
            UpdateFailed("Download failed: the server answered HTTP " status ".")
            return
        }
        SetTimer(UpdateDownloadPoll, 0)
        try FileDelete(file)
        stm := ComObject("ADODB.Stream")
        stm.Type := 1                                   ; binary
        stm.Open()
        stm.Write(updateReq.responseBody)
        stm.SaveToFile(file, 2)
        stm.Close()
    } catch {
        UpdateFailed("Download failed: the file could not be saved.")
        return
    }
    updateReq := ""
    got := Sha256OfFile(file)
    if (got = "" || got != StrLower(updateInfo["sha256"])) {
        try FileDelete(file)
        SetUpdateState("available")
        SetStatus("Update rejected: the downloaded file does not match its checksum.", "error")
        return
    }
    if (!UpdateFileLooksRight(file)) {
        try FileDelete(file)
        SetUpdateState("available")
        SetStatus("Update rejected: the downloaded file is not the right kind of file.", "error")
        return
    }
    updateFile := file
    InstallUpdate()
}

UpdateFileLooksRight(file) {
    try {
        if (A_IsCompiled) {
            buf := FileRead(file, "RAW m2")
            return buf.Size >= 2 && NumGet(buf, 0, "UShort") = 0x5A4D          ; "MZ" = a Windows program
        }
        head := FileRead(file, "UTF-8 m400")
        return InStr(head, "#Requires AutoHotkey")
    }
    return false
}

; SHA-256 of a file (Windows CNG, no helper process). Returns lower-case hex, or "" on any failure.
Sha256OfFile(path) {
    try {
        buf := FileRead(path, "RAW")
    } catch {
        return ""
    }
    hAlg := 0
    if (DllCall("bcrypt\BCryptOpenAlgorithmProvider", "Ptr*", &hAlg, "WStr", "SHA256", "Ptr", 0, "UInt", 0, "UInt") != 0)
        return ""
    out := Buffer(32, 0)
    st := DllCall("bcrypt\BCryptHash", "Ptr", hAlg, "Ptr", 0, "UInt", 0, "Ptr", buf, "UInt", buf.Size, "Ptr", out, "UInt", 32, "UInt")
    DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hAlg, "UInt", 0)
    if (st != 0)
        return ""
    hex := ""
    loop 32
        hex .= Format("{:02x}", NumGet(out, A_Index - 1, "UChar"))
    return hex
}

InstallUpdate() {
    global updateFile, updateInfo, mutexHandle, mutexName
    SetUpdateState("installing")
    SetStatus("Update verified. Installing version " updateInfo["version"] " and restarting...", "ready")
    target := A_ScriptFullPath
    backup := target ".old"
    try FileDelete(backup)
    try {
        FileMove(target, backup, 1)                     ; a running file can be renamed even when it cannot be overwritten
        FileMove(updateFile, target, 1)
    } catch {
        try {
            if (!FileExist(target) && FileExist(backup))
                FileMove(backup, target, 1)             ; roll back: the old version stays in place
        }
        SetUpdateState("available")
        SetStatus("Update failed: the application file could not be replaced (is its folder write-protected?).", "error")
        return
    }
    if (mutexHandle) {                                  ; free the single-instance lock so the new copy can start
        DllCall("CloseHandle", "Ptr", mutexHandle)
        mutexHandle := 0
    }
    try {
        Run(A_IsCompiled ? '"' target '"' : '"' A_AhkPath '" "' target '"', A_ScriptDir)
    } catch {
        try {                                           ; the new copy could not start: put the old version back and carry on
            FileMove(target, updateFile, 1)
            FileMove(backup, target, 1)
        }
        mutexHandle := DllCall("CreateMutexW", "Ptr", 0, "Int", 0, "Str", mutexName, "Ptr")
        SetUpdateState("available")
        SetStatus("Update failed: the new version could not be started. The old version was restored.", "error")
        return
    }
    CloseApplication()
}

GetAutoHotkeyInterpreter() {
    if (!A_IsCompiled && FileExist(A_AhkPath))
        return A_AhkPath
    for path in [A_ProgramFiles "\AutoHotkey\v2\AutoHotkey64.exe", A_ProgramFiles "\AutoHotkey\v2\AutoHotkey32.exe", A_ProgramFiles "\AutoHotkey\AutoHotkey64.exe", A_AppData "\AutoHotkey\v2\AutoHotkey64.exe"]
        if FileExist(path)
            return path
    try {
        regCmd := RegRead("HKEY_CLASSES_ROOT\AutoHotkeyScript\Shell\Open\Command", "", "")
        regPath := RegExReplace(regCmd, '["%]*\s*([^"]+?\.exe).*', "$1")
        if FileExist(regPath)
            return regPath
    }
    return ""
}

GetAutoHotkeyCompiler(ahkPath := "") {
    if (!ahkPath)
        ahkPath := GetAutoHotkeyInterpreter()
    if (!ahkPath)
        return ""
    SplitPath(ahkPath, , &ahkDir)
    for path in [ahkDir "\Compiler\Ahk2Exe.exe", ahkDir "\..\Compiler\Ahk2Exe.exe", A_ProgramFiles "\AutoHotkey\Compiler\Ahk2Exe.exe", A_ProgramFiles "\AutoHotkey\v2\Compiler\Ahk2Exe.exe"]
        if FileExist(path)
            return path
    return ""
}

OpenProcessSelector(*) {
    global processSelect, selectorFrameGui, selectorPopup, selectorList, selectGui, mainGui, isExiting, processOptions, gameFetchPending, selectorRowHeight
    global selectorScrollUpBtn, selectorScrollDownBtn, selectorScrollThumb, selectorScrollThumbTrack, selectorScrollSeparator, selectorRowSep1, selectorRowSep2, scrollBarWidth, scrollButtonHeight, isShowingGameStateHint, isShowingGameSearchHint, selectorDisplayedOptions
    if (isExiting)
        return
    if (gameFetchPending) {
        ; While a refresh is running the status line already says it is loading: rebuilding it (text measuring, marquee
        ; and dot-blink timers) on every click into the box would only steal time from the button's spin.
        return
    }
    if (processOptions.Length = 0) {
        SetStatus("No game list loaded. Press refresh to fetch Discord titles.", "ready")
        return
    }

    query := isShowingGameSearchHint ? "" : Trim(processSelect.Value)
    if (query != "") {
        matchFound := false
        for title in processOptions {
            if (InStr(title, query, false)) {
                matchFound := true
                break
            }
        }
        if (!matchFound) {
            CloseProcessSelector()
            return
        }
    }

    if (IsWindowValid(selectorFrameGui)) {
        selectorWasVisible := IsProcessSelectorOpen()
        FilterDiscordGameList()
        if (!selectorWasVisible && IsWindowValid(selectorFrameGui)) {
            WinGetPos(&selectScreenX, &selectScreenY, &selectW, &selectH, "ahk_id " selectGui.Hwnd)
            dropdownY := selectScreenY + selectH + dropdownGapBelowSearch
            visibleTitleRows := Min(3, Max(1, selectorDisplayedOptions.Length))
            dropdownHeight := (selectorRowHeight * visibleTitleRows) + 2
            dropdownY := Min(dropdownY, A_ScreenHeight - dropdownHeight - 12)
            availableHeight := A_ScreenHeight - dropdownY - 8
            ResizeProcessSelector(selectScreenX, dropdownY, selectW, availableHeight, true)
            initialHover := GetDropdownItemAtMouse()
            if (initialHover >= 0 && initialHover < selectorDisplayedOptions.Length)
                UpdateDropdownItemHover(initialHover)
        }
        EnsureGameSearchFocus()
        return
    }

    selectorFrameGui := Gui("-Caption -Border +ToolWindow +E0x08000000 +0x02000000", "")
    selectorFrameGui.BackColor := "FFFFFF"
    selectorFrameGui.Opt("+Owner" mainGui.Hwnd)
    RemoveNativeOutline(selectorFrameGui.Hwnd)

    selectorPopup := Gui("-Caption -Border +ToolWindow +0x04000000", "")
    selectorPopup.Opt("+Parent" selectorFrameGui.Hwnd)
    selectorPopup.BackColor := "000000"
    RemoveNativeOutline(selectorPopup.Hwnd)

    WinGetPos(&selectScreenX, &selectScreenY, &selectW, &selectH, "ahk_id " selectGui.Hwnd)
    dropdownY := selectScreenY + selectH + dropdownGapBelowSearch
    UpdateDropdownRowHeight(dropdownY)
    visibleTitleRows := Min(3, Max(1, selectorDisplayedOptions.Length))
    listHeight := (selectorRowHeight * visibleTitleRows)
    dropdownHeight := listHeight + 2
    dropdownY := Min(dropdownY, A_ScreenHeight - dropdownHeight - 12)
    availableHeight := A_ScreenHeight - dropdownY - 8
    totalPopupW := selectW
    
    innerPopupW := totalPopupW - 2
    innerPopupH := dropdownHeight - 2
    contentWidth := (selectorDisplayedOptions.Length <= 3) ? innerPopupW : (innerPopupW - scrollBarWidth - 2)
    
    selectorList := selectorPopup.Add("ListBox", Format("x1 y0 w{} h{} -Theme -Border -HScroll -VScroll +0x04000000 +0x1000 +0x0001 +0x0010 +0x2000 +0x0100 cFFFFFF Background000000", contentWidth, innerPopupH), [])
    selectorList.SetFont("s12", "Segoe UI")
    RemoveNativeOutline(selectorList.Hwnd)

    barX := innerPopupW - scrollBarWidth
    selectorScrollUpBtn := selectorPopup.Add("Text", Format("x{} y1 w{} h{} +0x000D Hidden Background000000 cFFFFFF", barX, scrollBarWidth, scrollButtonHeight), "")
    RemoveNativeOutline(selectorScrollUpBtn.Hwnd)

    selectorScrollDownBtn := selectorPopup.Add("Text", Format("x{} y{} w{} h{} +0x000D Hidden Background000000 cFFFFFF", barX, innerPopupH - scrollButtonHeight - 1, scrollBarWidth, scrollButtonHeight), "")
    RemoveNativeOutline(selectorScrollDownBtn.Hwnd)

    selectorScrollThumbTrack := selectorPopup.Add("Text", Format("x{} y{} w{} h{} +0x000D Hidden Background000000", barX, scrollButtonHeight + 1, scrollBarWidth, innerPopupH - (scrollButtonHeight * 2) - 2), "")
    RemoveNativeOutline(selectorScrollThumbTrack.Hwnd)

    selectorScrollThumb := selectorPopup.Add("Text", Format("x{} y{} w6 h{} +0x000D Hidden BackgroundFFFFFF", barX + 6, scrollButtonHeight + 1, 30), "")
    RemoveNativeOutline(selectorScrollThumb.Hwnd)

    selectorScrollSeparator := selectorPopup.Add("Text", Format("x{} y1 w1 h{} Hidden +0x04000000 BackgroundFFFFFF", barX - 1, innerPopupH), "")
    RemoveNativeOutline(selectorScrollSeparator.Hwnd)

    ; Fixed 1px white lines between the visible titles (created after the list so they sit above it).
    selectorRowSep1 := selectorPopup.Add("Text", "x1 y0 w10 h1 Hidden +0x04000000 BackgroundFFFFFF", "")
    selectorRowSep2 := selectorPopup.Add("Text", "x1 y0 w10 h1 Hidden +0x04000000 BackgroundFFFFFF", "")
    RemoveNativeOutline(selectorRowSep1.Hwnd)
    RemoveNativeOutline(selectorRowSep2.Hwnd)

    ApplyAnchorScrollThumb()
    
    uxtheme := DllCall("LoadLibrary", "Str", "uxtheme.dll", "Ptr")
    if (uxtheme) {
        DllCall("uxtheme.dll\SetWindowTheme", "Ptr", selectorList.Hwnd, "Str", "", "Str", "")
        DllCall("FreeLibrary", "Ptr", uxtheme)
    }

    SendMessage(0x01A0, 0, selectorRowHeight, selectorList.Hwnd)
    if (prewarmBuildActive)
        return              ; pre-warm: the (hidden) dropdown now exists; the real open later takes the fast "already built" path
    FilterDiscordGameList()
    ResizeProcessSelector(selectScreenX, dropdownY, selectW, availableHeight, true)
    
    initialHover := GetDropdownItemAtMouse()
    if (initialHover >= 0 && initialHover < selectorDisplayedOptions.Length) {
        UpdateDropdownItemHover(initialHover)
    }

    EnsureGameSearchFocus()
}

ResizeProcessSelector(popupX := "", popupY := "", popupW := "", availableHeight := "", animateOpen := false) {
    global mainGui, selectGui, selectorFrameGui, selectorPopup, selectorList, selectorDisplayedOptions, selectorRowHeight
    global selectorHoveredIndex, selectorPreviousHoveredIndex, selectorHoverProgress, scrollBarWidth, selectorScrollSeparator
    if (!IsWindowValid(selectorFrameGui) || !IsWindowValid(selectorPopup) || !IsWindowValid(selectorList))
        return
    if (popupX = "" || popupY = "" || popupW = "" || availableHeight = "") {
        WinGetPos(&selectScreenX, &selectScreenY, &selectW, &selectH, "ahk_id " selectGui.Hwnd)
        popupX := selectScreenX
        popupY := selectScreenY + selectH + dropdownGapBelowSearch
        popupW := selectW
    }
    visibleTitleRows := Min(3, Max(1, selectorDisplayedOptions.Length))
    dropdownHeight := (selectorRowHeight * visibleTitleRows) + 2
    popupY := Min(popupY, A_ScreenHeight - dropdownHeight - 12)
    availableHeight := A_ScreenHeight - popupY - 8
    popupClientW := popupW
    
    innerPopupW := popupClientW - 2
    innerPopupH := dropdownHeight - 2
    listW := (selectorDisplayedOptions.Length <= 3) ? innerPopupW : (innerPopupW - scrollBarWidth - 2)

    ; Whenever the dropdown is currently hidden, it is opened the same smooth way as when it is created fresh for a
    ; typed match: resized and rounded while still hidden, then shown once, fully formed. Without this, a dropdown that
    ; already exists (hidden) was shown first and resized / rounded afterwards, which is what looked rough on focus.
    if (!DllCall("User32\IsWindowVisible", "Ptr", selectorFrameGui.Hwnd, "Int"))
        animateOpen := true

    DropdownPaintLock(true)
    try {
        if (animateOpen)
            selectorFrameGui.Move(popupX, popupY, popupClientW, dropdownHeight)
        else
            selectorFrameGui.Show("NoActivate " Format("x{} y{} w{} h{}", popupX, popupY, popupClientW, dropdownHeight))
        selectorPopup.Show("NoActivate " Format("x1 y1 w{} h{}", popupClientW - 2, dropdownHeight - 2))
        selectorList.Move(1, 0, listW, innerPopupH)
        PositionScrollbarControls(popupClientW, dropdownHeight)
        ApplyRoundedCorners(selectorFrameGui, 24)
        ApplyRoundedCorners(selectorPopup, 22)
        if (animateOpen)
            selectorFrameGui.Show("NoActivate " Format("x{} y{} w{} h{}", popupX, popupY, popupClientW, dropdownHeight))
    } finally {
        DropdownPaintLock(false)
    }
    if (IsWindowValid(selectorScrollSeparator))
        selectorScrollSeparator.Redraw()
    selectorHoveredIndex := -1
    selectorPreviousHoveredIndex := -1
    selectorHoverProgress := 1.0
    SetTimer(UpdateSelectorHover, 0)
    SetTimer(RefreshInitialScrollThumbShape, -30)
    SetTimer(UpdateScrollControllerHover, 40)
    DropdownZOrderGuard()
    SetTimer(DropdownZOrderGuard, 50)
    EnsureGameSearchFocus()
}

RefreshInitialScrollThumbShape(*) {
    global selectorPopup, selectorScrollThumb, selectorDisplayedOptions, selectorScrollSeparator
    if (!IsWindowValid(selectorPopup) || !IsWindowValid(selectorScrollThumb)
        || !DllCall("User32\IsWindowVisible", "Ptr", selectorPopup.Hwnd, "Int")
        || !DllCall("User32\IsWindowVisible", "Ptr", selectorScrollThumb.Hwnd, "Int"))
        return
    if (selectorDisplayedOptions.Length > 3) {
        UpdateScrollThumbPosition()
        ApplyAnchorScrollThumb()
        selectorScrollThumb.Redraw()
        if (IsWindowValid(selectorScrollSeparator))
            selectorScrollSeparator.Redraw()
    }
}

MeasureSelectorItem(wParam, lParam, msg, hwnd) {
    global selectorPopup, selectorRowHeight
    if (!IsWindowValid(selectorPopup) || hwnd != selectorPopup.Hwnd || NumGet(lParam, 0, "UInt") != 2)
        return
    NumPut("UInt", selectorRowHeight, lParam, 16)
    return 1
}

OnSearchBoxDoubleClick(wParam, lParam, msg, hwnd) {
    global processSelect, isExiting
    if (!IsSet(isExiting) || isExiting || !IsWindowValid(processSelect) || hwnd != processSelect.Hwnd)
        return
    SendMessage(0x00B1, 0, -1, processSelect.Hwnd)
    return 0
}

TrackSelectorMouseMove(wParam, lParam, msg, hwnd) {
    global selectorList, selectorFrameGui, selectorDisplayedOptions, selectorMouseLeaveTracking, isDraggingThumb, thumbDragStartY, thumbDragStartThumbY, thumbDragTrackTopY, thumbDragTrackTravel, selectorScrollThumbTrack, selectorScrollThumb, selectorRowHeight, isKeyboardNavigating
    global processSelect, isSearchMenuOpen
    if (!IsOwnGuiWindow(hwnd))
        return
    if (isSearchMenuOpen)
        return
    if ((wParam & 0x0001) && IsWindowValid(processSelect) && hwnd = processSelect.Hwnd)
        return 0

    UpdateScrollControllerHover()
    
    if (isDraggingThumb && selectorDisplayedOptions.Length > 3) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mouseX, &mouseY)
        totalItems := selectorDisplayedOptions.Length
        selectorList.GetPos(,, &listW, &listHeight)
        visibleRows := Max(1, Floor(listHeight / selectorRowHeight))
        maxScroll := Max(0, totalItems - visibleRows)
        if (maxScroll > 0 && thumbDragTrackTravel > 0) {
            desiredThumbY := thumbDragStartThumbY + (mouseY - thumbDragStartY)
            clampedThumbY := Max(thumbDragTrackTopY, Min(thumbDragTrackTopY + thumbDragTrackTravel, desiredThumbY))
            scrollRatio := (clampedThumbY - thumbDragTrackTopY) / thumbDragTrackTravel
            newTop := Round(scrollRatio * maxScroll)
            SendMessage(0x0197, newTop, 0, selectorList.Hwnd)
            UpdateScrollThumbPosition()
        }
        return
    }

    if (!IsWindowValid(selectorList) || hwnd != selectorList.Hwnd
        || !IsWindowValid(selectorFrameGui)
        || !DllCall("User32\IsWindowVisible", "Ptr", selectorFrameGui.Hwnd, "Int"))
        return

    if (!selectorMouseLeaveTracking) {
        tracking := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", tracking.Size, tracking, 0)
        NumPut("UInt", 0x00000002, tracking, 4)
        NumPut("Ptr", selectorList.Hwnd, tracking, 8)
        NumPut("UInt", 0, tracking, 8 + A_PtrSize)
        if (DllCall("User32\TrackMouseEvent", "Ptr", tracking, "Int"))
            selectorMouseLeaveTracking := true
    }

    itemIndex := GetDropdownItemAtMouse()
    nextIndex := (itemIndex >= 0 && itemIndex < selectorDisplayedOptions.Length) ? itemIndex : -1
    if (nextIndex >= 0 && !RefreshKeyboardNavMode())
        UpdateDropdownItemHover(nextIndex)
}

UpdateScrollControllerHover() {
    global selectorFrameGui, selectorScrollUpBtn, selectorScrollDownBtn, selectorScrollThumb, selectorScrollThumbTrack, selectorScrollHoverTarget, searchEditBrush, scrollHoverBrush, isDraggingThumb, selectorDisplayedOptions
    if (IsContextMenuOpen())
        return
    if (!IsWindowValid(selectorFrameGui) || !DllCall("User32\IsWindowVisible", "Ptr", selectorFrameGui.Hwnd, "Int") || selectorDisplayedOptions.Length <= 3)
        return
    MouseGetPos(,, &windowUnderCursor, &hoveredControl, 2)
    target := ""
    if (IsWindowValid(selectorScrollUpBtn) && hoveredControl = selectorScrollUpBtn.Hwnd)
        target := "up"
    else if (IsWindowValid(selectorScrollDownBtn) && hoveredControl = selectorScrollDownBtn.Hwnd)
        target := "down"
    else if (isDraggingThumb || (IsWindowValid(selectorScrollThumb) && hoveredControl = selectorScrollThumb.Hwnd))
        target := "thumb"
    else if (IsWindowValid(selectorScrollThumbTrack) && hoveredControl = selectorScrollThumbTrack.Hwnd)
        target := "track"
    if (target = selectorScrollHoverTarget)
        return
    selectorScrollHoverTarget := target
    if (IsWindowValid(selectorScrollUpBtn)) {
        selectorScrollUpBtn.Redraw()
    }
    if (IsWindowValid(selectorScrollDownBtn)) {
        selectorScrollDownBtn.Redraw()
    }
    if (IsWindowValid(selectorScrollThumbTrack)) {
        selectorScrollThumbTrack.Opt((target = "track" || target = "thumb") ? "+Background202020" : "+Background000000")
    }
    if (IsWindowValid(selectorScrollThumb)) {
        selectorScrollThumb.Opt(target = "thumb" ? "+BackgroundDADADA" : "+BackgroundFFFFFF")
        UpdateScrollThumbPosition()
    }
    RepaintScrollThumbNoErase()
}

SelectorMouseLeave(wParam, lParam, msg, hwnd) {
    global selectorList, selectorMouseLeaveTracking, dropdownMarqueeIndex, isKeyboardNavigating
    if (IsWindowValid(selectorList) && hwnd = selectorList.Hwnd) {
        selectorMouseLeaveTracking := false
        dropdownMarqueeIndex := -1
        if (!isKeyboardNavigating)
            SetSelectorHoverIndex(-1)
    }
}

SetSelectorHoverIndex(nextIndex) {
    global selectorList, selectorHoveredIndex, selectorPreviousHoveredIndex, selectorHoverProgress
    if (!IsWindowValid(selectorList) || nextIndex = selectorHoveredIndex)
        return
    selectorPreviousHoveredIndex := selectorHoveredIndex
    selectorHoveredIndex := nextIndex
    selectorHoverProgress := 1.0
    SetTimer(UpdateSelectorHover, 0)
    ; Repaint ONLY the row that lost the highlight and the row that got it, and never erase to black first.
    ; (The old full Redraw() erased the whole list and then repainted it: that was the visible blink.)
    RepaintSelectorRows(selectorPreviousHoveredIndex, selectorHoveredIndex)
}

; Repaints the whole list without the erase-to-background pass (every row paints itself completely).
RepaintSelectorList() {
    global selectorList, selectorListFrozen
    if (!IsWindowValid(selectorList))
        return
    DllCall("User32\InvalidateRect", "Ptr", selectorList.Hwnd, "Ptr", 0, "Int", false)
    if (!selectorListFrozen)
        DllCall("User32\UpdateWindow", "Ptr", selectorList.Hwnd)
}

; Repaints only the given rows (by index; rows that are not on screen are ignored).
RepaintSelectorRows(indexA, indexB := -1) {
    global selectorList, selectorDisplayedOptions, selectorListFrozen
    if (!IsWindowValid(selectorList))
        return
    rc := Buffer(16, 0)
    for idx in [indexA, indexB] {
        if (idx < 0 || idx >= selectorDisplayedOptions.Length)
            continue
        if (SendMessage(0x0198, idx, rc.Ptr, selectorList.Hwnd) = -1)   ; LB_GETITEMRECT fails for rows that are not visible
            continue
        DllCall("User32\InvalidateRect", "Ptr", selectorList.Hwnd, "Ptr", rc, "Int", false)
    }
    if (!selectorListFrozen)
        DllCall("User32\UpdateWindow", "Ptr", selectorList.Hwnd)
}

UpdateSelectorHover(*) {
    global selectorFrameGui, selectorList, selectorPreviousHoveredIndex, selectorHoverProgress
    if (!IsWindowValid(selectorFrameGui) || !IsWindowValid(selectorList)
        || !DllCall("User32\IsWindowVisible", "Ptr", selectorFrameGui.Hwnd, "Int")) {
        SetTimer(UpdateSelectorHover, 0)
        return
    }
    selectorHoverProgress := 1.0
    RepaintSelectorList()
    SetTimer(UpdateSelectorHover, 0)
}

; Distance from the top of the 42px status line to the middle of the sentence (ascender top to descender bottom).
GetStatusInkCenterOffset() {
    hdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
    dpi := DllCall("Gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 90)
    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(12 * dpi / 72), "Int", 0, "Int", 0, "Int", 0, "Int", 400, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", "Segoe UI", "Ptr")
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
    tm := Buffer(80, 0)
    DllCall("Gdi32\GetTextMetricsW", "Ptr", hdc, "Ptr", tm)
    lineH := NumGet(tm, 0, "Int"), ascent := NumGet(tm, 4, "Int"), internalLeading := NumGet(tm, 12, "Int")
    DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)
    DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    emHeight := lineH - internalLeading
    baseline := (42 - lineH) / 2 + ascent
    return baseline - emHeight * 0.275      ; ink spans about 0.76em above to 0.21em below the baseline
}

; Sets the dropdown's row height from its OWN setting (dropdownRowHeightPx). It used to be fitted to the status sentence and the
; window's bottom edge; it no longer follows either of them.
UpdateDropdownRowHeight(dropdownTop) {
    global selectorRowHeight, dropdownRowHeightPx
    selectorRowHeight := dropdownRowHeightPx      ; its own fixed value (it no longer follows the status line / window bottom)
}

; Line height of the font selected into hdc, and the distance from the top of the line to the
; centre of the capital letters. Placing that point on the centre of an area centres the text visually.
GetFontCenterMetrics(hdc, &lineH, &capCenter) {
    tm := Buffer(80, 0)
    DllCall("Gdi32\GetTextMetricsW", "Ptr", hdc, "Ptr", tm)
    lineH := NumGet(tm, 0, "Int")
    ascent := NumGet(tm, 4, "Int")
    internalLeading := NumGet(tm, 12, "Int")
    capCenter := ascent - ((lineH - internalLeading) * 0.7) / 2     ; estimate, used only if the glyph can't be measured
    ; Measure the real "H" of the selected font (hinted, at this exact size / weight / DPI) and use the middle of its ink.
    gm := Buffer(20, 0), mat := Buffer(16, 0)                       ; GLYPHMETRICS, MAT2 (identity)
    NumPut("Int", 0x10000, mat, 0), NumPut("Int", 0x10000, mat, 12)
    if (DllCall("Gdi32\GetGlyphOutlineW", "Ptr", hdc, "UInt", 72, "UInt", 0, "Ptr", gm, "UInt", 0, "Ptr", 0, "Ptr", mat, "UInt") != 0xFFFFFFFF) {
        inkH := NumGet(gm, 4, "UInt"), inkTop := NumGet(gm, 12, "Int")   ; ink height, ink top above the baseline
        if (inkH > 0)
            capCenter := ascent - (inkTop - inkH / 2)
    }
}

GetControlFontCenterMetrics(hwnd, &lineH, &capCenter) {
    hdc := DllCall("User32\GetDC", "Ptr", hwnd, "Ptr")
    font := SendMessage(0x0031, 0, 0, hwnd)
    oldFont := font ? DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", font, "Ptr") : 0
    GetFontCenterMetrics(hdc, &lineH, &capCenter)
    if (oldFont)
        DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
    DllCall("User32\ReleaseDC", "Ptr", hwnd, "Ptr", hdc)
}

DrawSelectorItem(wParam, lParam, msg, hwnd) {
    global selectorPopup, selectorList, selectorDisplayedOptions, refreshButton, selectGui, processSelect
    global selectorScrollUpBtn, selectorScrollDownBtn, selectorScrollThumbTrack, selectorScrollThumb
    global selectorHoveredIndex, selectorPreviousHoveredIndex, selectorHoverProgress
    global selectorPressedIndex, selectorPressColorCurrent, selectorPressPhase
    global dropdownMarqueeIndex, dropdownMarqueeOffset, isKeyboardNavigating, actionGui, actionBtn
    global dropdownMarqueeRenderedX, dropdownRenderedPhase, dropdownStripDc, dropdownStripH, dropdownStripDirty, dropdownStripPhases, dropdownStripText
    global statusMarqueeGui, statusMarqueeText, mainGui, minBtn, closeBtn, statusDot
    global refreshOverlay, refreshOverlayCtl, statusFadeOv, statusFadeCtl
    global rowBufDc, rowBufBmp, rowBufOld, rowBufW, rowBufH
    if (!lParam)
        return
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    itemHwnd := NumGet(lParam, itemHwndOffset, "Ptr")

    if (IsObject(statusMarqueeGui) && IsWindowValid(statusMarqueeText) && hwnd = statusMarqueeGui.Hwnd && itemHwnd = statusMarqueeText.Hwnd)
        return DrawStatusMarquee(lParam)
    
    if (IsObject(mainGui) && hwnd = mainGui.Hwnd) {
        if (IsWindowValid(statusDot) && itemHwnd = statusDot.Hwnd)
            return DrawStatusDot(lParam)
        if (IsWindowValid(minBtn) && itemHwnd = minBtn.Hwnd)
            return DrawTopButton(lParam, "min")
        if (IsWindowValid(closeBtn) && itemHwnd = closeBtn.Hwnd)
            return DrawTopButton(lParam, "close")
    }
    if (IsWindowValid(refreshButton) && IsObject(selectGui) && hwnd = selectGui.Hwnd) {
        if (itemHwnd = refreshButton.Hwnd)
            return DrawRefreshButton(lParam)
    }
    if (IsObject(refreshOverlay) && IsWindowValid(refreshOverlayCtl) && hwnd = refreshOverlay.Hwnd && itemHwnd = refreshOverlayCtl.Hwnd)
        return DrawRefreshButton(lParam)
    if (IsObject(statusFadeOv) && IsWindowValid(statusFadeCtl) && hwnd = statusFadeOv.Hwnd && itemHwnd = statusFadeCtl.Hwnd)
        return DrawStatusMarquee(lParam)
    if (IsWindowValid(actionBtn) && IsObject(actionGui) && hwnd = actionGui.Hwnd && itemHwnd = actionBtn.Hwnd)
        return DrawActionButton(lParam)
    drawnTos := RiskTosOwnerDraw(hwnd, itemHwnd, lParam)
    if (drawnTos != "")
        return drawnTos
    drawnRiskIcon := RiskIconOwnerDraw(hwnd, itemHwnd, lParam)
    if (drawnRiskIcon != "")
        return drawnRiskIcon
    drawnRiskLine := RiskLineOwnerDraw(hwnd, itemHwnd, lParam)
    if (drawnRiskLine != "")
        return drawnRiskLine
    drawnRiskTitle := RiskTitleOwnerDraw(hwnd, itemHwnd, lParam)
    if (drawnRiskTitle != "")
        return drawnRiskTitle
    drawnRiskButton := RiskButtonOwnerDraw(hwnd, itemHwnd, lParam)
    if (drawnRiskButton != "")
        return drawnRiskButton
    if (IsWindowValid(selectorPopup) && hwnd = selectorPopup.Hwnd && selectorDisplayedOptions.Length > 3) {
        if (IsWindowValid(selectorScrollUpBtn) && itemHwnd = selectorScrollUpBtn.Hwnd)
            return DrawScrollButton(lParam, true)
        if (IsWindowValid(selectorScrollDownBtn) && itemHwnd = selectorScrollDownBtn.Hwnd)
            return DrawScrollButton(lParam, false)
        if (IsWindowValid(selectorScrollThumbTrack) && itemHwnd = selectorScrollThumbTrack.Hwnd)
            return DrawScrollTrack(lParam)
        if (IsWindowValid(selectorScrollThumb) && itemHwnd = selectorScrollThumb.Hwnd)
            return DrawScrollThumbWindow(lParam)
    }
    if (!IsWindowValid(selectorPopup) || hwnd != selectorPopup.Hwnd || NumGet(lParam, 0, "UInt") != 2)
        return

    if (!IsWindowValid(selectorList) || itemHwnd != selectorList.Hwnd)
        return

    itemIndex := NumGet(lParam, 8, "UInt")
    hdc := NumGet(lParam, itemHwndOffset + A_PtrSize, "Ptr")
    rectOffset := itemHwndOffset + A_PtrSize * 2
    left := NumGet(lParam, rectOffset, "Int")
    top := NumGet(lParam, rectOffset + 4, "Int")
    right := NumGet(lParam, rectOffset + 8, "Int")
    bottom := NumGet(lParam, rectOffset + 12, "Int")
    itemRect := Buffer(16, 0)
    NumPut("Int", left, itemRect, 0)
    NumPut("Int", top, itemRect, 4)
    NumPut("Int", right, itemRect, 8)
    NumPut("Int", bottom, itemRect, 12)

    ; Compose the row off-screen (origin shifted so the existing coordinates still apply), then copy it once.
    realHdc := hdc
    bufW := right - left, bufH := bottom - top
    if (bufW <= 0 || bufH <= 0)
        return 1
    ; One back-buffer is created once and reused for every row (creating + deleting a DC and a bitmap per row per
    ; repaint was a large part of the stutter while scrolling fast).
    if (!rowBufDc || rowBufW != bufW || rowBufH != bufH) {
        if (rowBufDc) {
            DllCall("Gdi32\SelectObject", "Ptr", rowBufDc, "Ptr", rowBufOld, "Ptr")
            DllCall("Gdi32\DeleteObject", "Ptr", rowBufBmp)
            DllCall("Gdi32\DeleteDC", "Ptr", rowBufDc)
            rowBufDc := 0, rowBufBmp := 0
        }
        rowBufDc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", realHdc, "Ptr")
        rowBufBmp := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", realHdc, "Int", bufW, "Int", bufH, "Ptr")
        if (!rowBufDc || !rowBufBmp) {
            if (rowBufBmp)
                DllCall("Gdi32\DeleteObject", "Ptr", rowBufBmp)
            if (rowBufDc)
                DllCall("Gdi32\DeleteDC", "Ptr", rowBufDc)
            rowBufDc := 0, rowBufBmp := 0
            return 1
        }
        rowBufOld := DllCall("Gdi32\SelectObject", "Ptr", rowBufDc, "Ptr", rowBufBmp, "Ptr")
        rowBufW := bufW, rowBufH := bufH
    }
    bufDc := rowBufDc, bufBmp := rowBufBmp, bufOldBmp := rowBufOld
    DllCall("Gdi32\SetViewportOrgEx", "Ptr", bufDc, "Int", -left, "Int", -top, "Ptr", 0)
    listFont := SendMessage(0x0031, 0, 0, selectorList.Hwnd)
    if (listFont)
        DllCall("Gdi32\SelectObject", "Ptr", bufDc, "Ptr", listFont, "Ptr")
    hdc := bufDc

    backgroundBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00000000, "Ptr")
    DllCall("User32\FillRect", "Ptr", hdc, "Ptr", itemRect, "Ptr", backgroundBrush)
    DllCall("Gdi32\DeleteObject", "Ptr", backgroundBrush)

    if (itemIndex >= selectorDisplayedOptions.Length) {
        FlushBufferedRow(realHdc, bufDc, bufBmp, bufOldBmp, left, top, bufW, bufH)
        return 1
    }

    contentBottom := bottom - 1   ; the last pixel row of every item is reserved for the separator line
    isPressed := (itemIndex = selectorPressedIndex && selectorPressPhase != "idle")
    isHighlightedViaKeyboard := isKeyboardNavigating && (itemIndex = SendMessage(0x0188, 0, 0, selectorList.Hwnd))
    rowFillHex := ""
    fillBottom := contentBottom
    if (isPressed || itemIndex = selectorHoveredIndex || isHighlightedViaKeyboard) {
        rowColor := isPressed ? selectorPressColorCurrent : "3A3A3A"
        rowFillHex := rowColor
        ; Plain rectangle over the whole title area, edge to edge. The rounded outer corners come from the dropdown's own
        ; rounded window region (ApplyRoundedCorners on selectorPopup), so the highlight matches the box exactly and
        ; middle rows get square edges against the white separator lines. The last visible row has no separator under
        ; it, so its highlight also covers the reserved bottom pixel row.
        GetClientRectHeight := Buffer(16, 0)
        DllCall("User32\GetClientRect", "Ptr", selectorList.Hwnd, "Ptr", GetClientRectHeight)
        listClientH := NumGet(GetClientRectHeight, 12, "Int")
        fillBottom := (bottom >= listClientH) ? bottom : contentBottom
        fillRect := Buffer(16, 0)
        NumPut("Int", left, fillRect, 0), NumPut("Int", top, fillRect, 4), NumPut("Int", right, fillRect, 8), NumPut("Int", fillBottom, fillRect, 12)
        selectionBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", HexToColorRef(rowColor), "Ptr")
        DllCall("User32\FillRect", "Ptr", hdc, "Ptr", fillRect, "Ptr", selectionBrush)
        DllCall("Gdi32\DeleteObject", "Ptr", selectionBrush)
    }

    ; The white lines between titles are separate fixed controls (see UpdateRowSeparators), so they never move or repaint while scrolling.

    DllCall("Gdi32\SetBkMode", "Ptr", hdc, "Int", 1)
    DllCall("Gdi32\SetTextColor", "Ptr", hdc, "UInt", 0xFFFFFF)
    
    selectionWidth := right - left
    leftTextInset := rowLeftInset                 ; its own value (no longer 2 % of the row width)

    titleText := selectorDisplayedOptions[itemIndex + 1]
    
    ; Ink-exact padding: the gap from the box's inner edge to the first visible pixel of the title (gapLeft)
    ; is also the gap from the last visible pixel to the box's inner edge, both for a title that is cut off
    ; (static row) and for the end of the scrolling title. The glyphs' own side bearings are accounted for.
    GetRowTextBearings(titleText, &bearingA, &bearingC)
    iconOff := RowIconOffset(leftTextInset)
    exactTextLeft := left + leftTextInset + iconOff          ; the title starts after the round icon
    gapRight := rowRightPad + 1 + bearingA                   ; its own right padding (no longer the left padding)
    exactTextRight := right - RowRightEdgeInset() - gapRight
    maxTextW := exactTextRight + bearingC - exactTextLeft

    textX := exactTextLeft
    textW := MeasureRowTextWidth(titleText)
    isScrollingRow := false

    if (itemIndex = dropdownMarqueeIndex && textW > maxTextW) {
        isScrollingRow := true
        overflowW := textW - maxTextW
        cycleW := overflowW + (leftTextInset * 2)
        currentOffset := Mod(dropdownMarqueeOffset, cycleW)
        if (currentOffset <= overflowW) {
            textX -= Round(currentOffset)
        } else {
            textX -= Round(overflowW)
        }
    }

    GetFontCenterMetrics(hdc, &textLineH, &textCapCenter)
    rowCenterY := top + (contentBottom - top) / 2                  ; centre of the title area (between the borders / separator lines)
    textTop := Floor(rowCenterY - textCapCenter + 0.5) + textVCenterNudge
    if (iconOff > 0) {
        ; the icon is centred exactly on the title area's centre: equal gap above and below
        iconY := Round(rowCenterY - RowIconSize() / 2)
        DrawRowIcon(hdc, left, top, left + leftTextInset, iconY, titleText)
    }
    textRect := Buffer(16, 0)
    NumPut("Int", textX, textRect, 0)
    NumPut("Int", textTop, textRect, 4)
    NumPut("Int", exactTextRight, textRect, 8)
    NumPut("Int", textTop + textLineH + 2, textRect, 12)
    ; While the title scrolls, its left end must stop at the left padding exactly like its right end stops at the right
    ; padding (the DrawTextW rectangle already clips the right side at exactTextRight). The clip starts at the first
    ; ink pixel of the title at rest: gapLeft pixels after the box's inner edge (left - 1), the same gap as on the right.
    ; SMOOTH PATH (same engine as the status line / popup title): copy the visible window of the pre-rendered title strip, band =
    ; current sub-pixel shift. Only when the row is filled with the strip's own background colour; any other case (pressed colour,
    ; strip missing / outdated / other row height) uses the plain GDI text below, exactly like before.
    drawnSmooth := false
    if (isScrollingRow && dropdownStripPhases > 1 && dropdownStripDc && !dropdownStripDirty && dropdownStripH = bufH
        && dropdownStripText == titleText && rowFillHex = "3A3A3A") {
        clipL := exactTextLeft + bearingA                  ; left end of the visible text area (same clip the GDI path uses)
        clipW := exactTextRight - clipL                    ; right end = exactTextRight (the DrawTextW rectangle's right edge)
        srcX := (clipL - exactTextLeft) - dropdownMarqueeRenderedX + 1      ; strip text origin is 1 px in
        if (srcX < 0) {
            clipL -= srcX
            clipW += srcX
            srcX := 0
        }
        blitH := fillBottom - top
        if (clipW > 0 && blitH > 0) {
            srcY := Min(Max(dropdownRenderedPhase, 0), dropdownStripPhases - 1) * bufH
            DllCall("Gdi32\BitBlt", "Ptr", hdc, "Int", clipL, "Int", top, "Int", clipW, "Int", blitH, "Ptr", dropdownStripDc, "Int", srcX, "Int", srcY, "UInt", 0x00CC0020)
            drawnSmooth := true
        }
    }
    if (!drawnSmooth) {
        if (isScrollingRow)
            DllCall("Gdi32\IntersectClipRect", "Ptr", hdc, "Int", exactTextLeft + bearingA, "Int", top, "Int", right, "Int", bottom)
        DllCall("User32\DrawTextW", "Ptr", hdc, "Str", titleText, "Int", -1, "Ptr", textRect, "UInt", 0x00000820)   ; + DT_NOPREFIX: an "&" in a title is a normal character
        if (isScrollingRow)
            DllCall("Gdi32\SelectClipRgn", "Ptr", hdc, "Ptr", 0)
    }
    FlushBufferedRow(realHdc, bufDc, bufBmp, bufOldBmp, left, top, bufW, bufH)
    return 1
}

; EM_SETMARGINS (0x00D3) with EC_LEFTMARGIN | EC_RIGHTMARGIN (0x0003): low word = left, high word = right.
; Only the left margin is used: the right padding is made by the control's own width (see PositionChildWindows),
; because the edit's right margin did not reliably stop the text at the padding.
SetSearchEditMargins(inset) {
    global processSelect
    global searchIconOff
    SendMessage(0x00D3, 0x0003, inset + searchIconOff, processSelect.Hwnd)   ; (+ the room of the game icon when it is shown)
}

; Inner edge of the dropdown box: the list starts 1px inside the frame outline on the left, but its right edge
; runs 2px past the inner edge of the outline (no extra offset when the scrollbar sits to the right of the list).
RowRightEdgeInset() {
    global selectorDisplayedOptions
    return (selectorDisplayedOptions.Length > 3) ? 0 : 2
}

; Left bearing (empty pixels before the first glyph's ink) and right bearing (empty pixels after the last glyph's ink).
GetRowTextBearings(text, &bearingA, &bearingC) {
    global selectorList, rowTextCache
    bearingA := 0, bearingC := 0
    if (text = "" || !IsWindowValid(selectorList))
        return
    if (rowTextCache.Has(text) && rowTextCache[text][2] != "") {
        c := rowTextCache[text]
        bearingA := c[2], bearingC := c[3]
        return
    }
    hdc := DllCall("User32\GetDC", "Ptr", selectorList.Hwnd, "Ptr")
    if (!hdc)
        return
    listFont := SendMessage(0x0031, 0, 0, selectorList.Hwnd)
    oldFont := listFont ? DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", listFont, "Ptr") : 0
    abc := Buffer(12, 0)   ; ABC: int a, UINT b, int c
    firstCode := Ord(text)
    if (firstCode <= 0xFFFF && !(firstCode >= 0xD800 && firstCode <= 0xDFFF)
        && DllCall("Gdi32\GetCharABCWidthsW", "Ptr", hdc, "UInt", firstCode, "UInt", firstCode, "Ptr", abc, "Int"))
        bearingA := Max(-3, Min(6, NumGet(abc, 0, "Int")))
    lastCode := Ord(SubStr(text, -1))
    if (lastCode <= 0xFFFF && !(lastCode >= 0xD800 && lastCode <= 0xDFFF)
        && DllCall("Gdi32\GetCharABCWidthsW", "Ptr", hdc, "UInt", lastCode, "UInt", lastCode, "Ptr", abc, "Int"))
        bearingC := Max(-3, Min(6, NumGet(abc, 8, "Int")))
    if (oldFont)
        DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
    DllCall("User32\ReleaseDC", "Ptr", selectorList.Hwnd, "Ptr", hdc)
    StoreRowTextCache(text, "", bearingA, bearingC)
}

; Measured values are kept per title: DrawSelectorItem used to call GetDC / font / measure for every row on every
; repaint, which made fast scrolling heavy. The cache is cleared when it grows large.
StoreRowTextCache(text, width := "", bearingA := "", bearingC := "") {
    global rowTextCache
    if (rowTextCache.Count > 3000)
        rowTextCache.Clear()
    c := rowTextCache.Has(text) ? rowTextCache[text] : ["", "", ""]
    if (width != "")
        c[1] := width
    if (bearingA != "") {
        c[2] := bearingA
        c[3] := bearingC
    }
    rowTextCache[text] := c
}

; Width of a title exactly as the row draws it (same font, same DrawTextW flags), so the end of the scrolling
; title lands precisely on the right padding edge instead of a pixel or two short of it.
MeasureRowTextWidth(text) {
    global selectorList, rowTextCache
    if (!IsWindowValid(selectorList))
        return GetTextWidth(text, "Segoe UI", 12)
    if (rowTextCache.Has(text) && rowTextCache[text][1] != "")
        return rowTextCache[text][1]
    hdc := DllCall("User32\GetDC", "Ptr", selectorList.Hwnd, "Ptr")
    if (!hdc)
        return GetTextWidth(text, "Segoe UI", 12)
    listFont := SendMessage(0x0031, 0, 0, selectorList.Hwnd)
    oldFont := listFont ? DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", listFont, "Ptr") : 0
    calcRect := Buffer(16, 0)
    ; DT_CALCRECT | DT_SINGLELINE (the row itself draws with DT_SINGLELINE)
    DllCall("User32\DrawTextW", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", calcRect, "UInt", 0x00000C20)   ; + DT_NOPREFIX (same flags as the row)
    width := NumGet(calcRect, 8, "Int")
    if (oldFont)
        DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
    DllCall("User32\ReleaseDC", "Ptr", selectorList.Hwnd, "Ptr", hdc)
    StoreRowTextCache(text, width)
    return width
}

; ---------------------------------------------------------------------------------------------
; GAME ICONS: an icon in front of every game title (dropdown rows, the text of the search box, the title of the warning), in Discord's style:
; 32 px rounded square (8 px corners), the picture fills it completely, nothing behind it (measured on Discord screenshots).
; ---------------------------------------------------------------------------------------------
; Which picture: Discord's own application icon of the game (found with the game's app ID + icon hash from the detectable list, or from the
; app's public record). It is fetched at 128 x 128 and decoded ONCE into a 32 x 32 "master" (shrunk with high quality bicubic scaling):
; the picture is scaled so it fills the whole square (shorter side = the square, no extra zoom) and gets rounded corners (gameIconRadiusRatio)
; with smooth edges; nothing is drawn behind it, so see-through icons stay see-through. Every place scales that master to its own
; size. The finished masters are also kept on disk (32 x 32 PNGs named with the Discord icon hash), so after the first run the icons appear at once.
; On every refresh each cached icon's file name (its hash) is compared with the hash in the fresh list; a changed icon is fetched in the
; background and swapped in without any hitch (the old one stays visible until the new one is ready).
RowIconSize() {
    global rowIconPx, selectorRowHeight
    return Max(14, Min(rowIconPx, selectorRowHeight - 5))
}

; Width the icon takes in front of a dropdown title (0 when icons are off / GDI+ is missing). The padding that used to be in front
; of the title (leftTextInset) is now in front of the icon AND after it: [padding][icon][padding][title].
RowIconOffset(leftTextInset) {
    global rowIconsEnabled, gdiplusToken, rowIconTextGap
    return (rowIconsEnabled && gdiplusToken) ? RowIconSize() + rowIconTextGap : 0   ; its own gap (leftTextInset is no longer used here)
}

FontEmPx(pointSize) {
    return pointSize * A_ScreenDPI / 72
}

; Draws the master scaled to size x size at (x, y) of a GDI+ graphics.
GdipDrawMasterIcon(g, master, x, y, size) {
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4, "Int")
    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", g, "Int", 7, "Int")      ; high quality bicubic
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", g, "Int", 2, "Int")
    DllCall("gdiplus\GdipDrawImageRectI", "Ptr", g, "Ptr", master, "Int", x, "Int", y, "Int", size, "Int", size, "Int")
}

; A rounded square (corner radius = size * gameIconRadiusRatio) as a GDI+ path. Returns the path (delete it with GdipDeletePath) or 0.
GdipRoundedSquarePath(x, y, size) {
    global gameIconRadiusRatio
    path := 0
    if (DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path, "Int") != 0 || !path)
        return 0
    d := size * gameIconRadiusRatio * 2
    x0 := x + 0.0, y0 := y + 0.0, x1 := x + size - d, y1 := y + size - d
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x0, "Float", y0, "Float", d, "Float", d, "Float", 180.0, "Float", 90.0, "Int")
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x1, "Float", y0, "Float", d, "Float", d, "Float", 270.0, "Float", 90.0, "Int")
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x1, "Float", y1, "Float", d, "Float", d, "Float", 0.0, "Float", 90.0, "Int")
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x0, "Float", y1, "Float", d, "Float", d, "Float", 90.0, "Float", 90.0, "Int")
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", path, "Int")
    return path
}

; Grey rounded square shown ONLY while an icon is still loading (a game without any picture gets the "?" icon below instead).
GdipDrawIconPlaceholder(g, x, y, size) {
    brush := 0
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4, "Int")
    if (DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF4F4F4F, "Ptr*", &brush, "Int") = 0 && brush) {
        path := GdipRoundedSquarePath(x, y, size)
        if (path) {
            DllCall("gdiplus\GdipFillPath", "Ptr", g, "Ptr", brush, "Ptr", path, "Int")
            DllCall("gdiplus\GdipDeletePath", "Ptr", path, "Int")
        }
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush, "Int")
    }
}

; True when every source was asked and none had a picture for this game (the job failed): the game then gets Discord's "?" icon.
GameIconIsMissing(title) {
    global gameIconState, gameIconBitmaps
    key := StrLower(title)
    if (gameIconBitmaps.Has(key))
        return false
    return ((gameIconState.Has(key) && gameIconState[key] = 3) || GameIconNoIconFresh(key))
}

; Discord's icon for a game that has no picture: a light rounded square like a die, a "?" in the middle and a dot in every corner.
; The "?" and the dots are CUT OUT of the square (the colour of whatever is behind shows through, exactly like on Discord).
; Built once as a master (same size / format as every other master) and then scaled like any game icon. Returns the GDI+ bitmap or 0.
BuildUnknownIconMaster(M) {
    global gdiplusToken
    if (!gdiplusToken)
        return 0
    bmp := 0, g := 0, path := 0, textPath := 0, brush := 0, fam := 0, gf := 0, mtx := 0, ok := false
    try {
        if (DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", M, "Int", M, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp, "Int") != 0 || !bmp)
            throw Error("bitmap")
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &g, "Int")
        if (!g)
            throw Error("graphics")
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", 0x00000000, "Int")
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4, "Int")

        ; one path, even-odd fill (FillModeAlternate): everything that lies INSIDE the rounded square and is added to the same path
        ; (the "?" and the four dots) becomes a hole
        path := GdipRoundedSquarePath(0, 0, M)
        if (!path)
            throw Error("path")

        ; four dots, one in every corner
        inset := M * 0.19, dotR := M * 0.07
        for pt in [[inset, inset], [M - inset, inset], [inset, M - inset], [M - inset, M - inset]]
            DllCall("gdiplus\GdipAddPathEllipse", "Ptr", path, "Float", pt[1] - dotR, "Float", pt[2] - dotR, "Float", dotR * 2, "Float", dotR * 2, "Int")

        ; the "?" : bold Segoe UI outline, scaled to half the icon's height and centred on the icon
        if (DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &fam, "Int") != 0 || !fam)
            throw Error("family")
        DllCall("gdiplus\GdipStringFormatGetGenericTypographic", "Ptr*", &gf, "Int")      ; shared GDI+ object: never deleted by us
        if (!gf)
            throw Error("format")
        if (DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &textPath, "Int") != 0 || !textPath)
            throw Error("textpath")
        layout := Buffer(16, 0)
        NumPut("Float", 0.0, "Float", 0.0, "Float", 1000.0, "Float", 1000.0, layout, 0)
        if (DllCall("gdiplus\GdipAddPathString", "Ptr", textPath, "WStr", "?", "Int", -1, "Ptr", fam, "Int", 1, "Float", 100.0, "Ptr", layout, "Ptr", gf, "Int") != 0)
            throw Error("text")
        bounds := Buffer(16, 0)
        if (DllCall("gdiplus\GdipGetPathWorldBounds", "Ptr", textPath, "Ptr", bounds, "Ptr", 0, "Ptr", 0, "Int") != 0)
            throw Error("bounds")
        bx := NumGet(bounds, 0, "Float"), by := NumGet(bounds, 4, "Float"), bw := NumGet(bounds, 8, "Float"), bh := NumGet(bounds, 12, "Float")
        if (bw <= 0 || bh <= 0)
            throw Error("bounds")
        sc := (M * 0.50) / bh
        dx := M / 2 - (bx + bw / 2) * sc
        dy := M / 2 - (by + bh / 2) * sc
        if (DllCall("gdiplus\GdipCreateMatrix2", "Float", sc, "Float", 0.0, "Float", 0.0, "Float", sc, "Float", dx, "Float", dy, "Ptr*", &mtx, "Int") != 0 || !mtx)
            throw Error("matrix")
        DllCall("gdiplus\GdipTransformPath", "Ptr", textPath, "Ptr", mtx, "Int")
        DllCall("gdiplus\GdipAddPathPath", "Ptr", path, "Ptr", textPath, "Int", 0, "Int")

        ; Discord's light grey (220, 220, 223)
        if (DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFFDCDCDF, "Ptr*", &brush, "Int") != 0 || !brush)
            throw Error("brush")
        if (DllCall("gdiplus\GdipFillPath", "Ptr", g, "Ptr", brush, "Ptr", path, "Int") != 0)
            throw Error("fill")
        ok := true
    } catch {
        ok := false
    }
    if (brush)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush, "Int")
    if (mtx)
        DllCall("gdiplus\GdipDeleteMatrix", "Ptr", mtx, "Int")
    if (textPath)
        DllCall("gdiplus\GdipDeletePath", "Ptr", textPath, "Int")
    if (path)
        DllCall("gdiplus\GdipDeletePath", "Ptr", path, "Int")
    if (fam)
        DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", fam, "Int")
    if (g)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g, "Int")
    if (!ok) {
        if (bmp)
            DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp, "Int")
        return 0
    }
    return bmp
}

; The "?" icon as a finished 32 x 32 master. It is drawn ONCE (at 4x size, shrunk with high quality bicubic scaling = extra smooth edges) and
; saved in the icon pack; every later start just loads it from there.
GetUnknownIconMaster() {
    global gdiplusToken, gameIconMasterPx, unknownIconMaster, gameIconUnknownKey
    if (unknownIconMaster)
        return unknownIconMaster
    if (!gdiplusToken)
        return 0
    GameIconIndexEnsure()
    saved := GameIconPackLoadMaster(gameIconUnknownKey)
    if (saved) {
        unknownIconMaster := saved
        return saved
    }
    GameIconPackDrop(gameIconUnknownKey)             ; lost or damaged: drawn again below and saved again
    M := gameIconMasterPx
    big := BuildUnknownIconMaster(M * 4)
    master := 0
    if (big) {
        master := DownscaleIconMaster(big, M)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", big, "Int")
    }
    if (!master)
        master := BuildUnknownIconMaster(M)
    if (!master)
        return 0
    unknownIconMaster := master
    GameIconUnknownPersist(master)
    return master
}

; A GDI+ bitmap shrunk to M x M (premultiplied ARGB, transparency kept exactly). Returns the new bitmap or 0.
DownscaleIconMaster(src, M) {
    sw := 0, sh := 0, dst := 0, g := 0, ia := 0
    DllCall("gdiplus\GdipGetImageWidth", "Ptr", src, "UInt*", &sw, "Int")
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", src, "UInt*", &sh, "Int")
    if (DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", M, "Int", M, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &dst, "Int") != 0 || !dst)
        return 0
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", dst, "Ptr*", &g, "Int")
    if (!g) {
        DllCall("gdiplus\GdipDisposeImage", "Ptr", dst, "Int")
        return 0
    }
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", 0x00000000, "Int")
    DllCall("gdiplus\GdipSetCompositingMode", "Ptr", g, "Int", 1, "Int")
    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", g, "Int", 7, "Int")
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", g, "Int", 2, "Int")
    DllCall("gdiplus\GdipCreateImageAttributes", "Ptr*", &ia, "Int")
    if (ia)
        DllCall("gdiplus\GdipSetImageAttributesWrapMode", "Ptr", ia, "Int", 3, "UInt", 0, "Int", 0, "Int")
    DllCall("gdiplus\GdipDrawImageRectRect", "Ptr", g, "Ptr", src
        , "Float", 0.0, "Float", 0.0, "Float", M + 0.0, "Float", M + 0.0
        , "Float", 0.0, "Float", 0.0, "Float", sw + 0.0, "Float", sh + 0.0
        , "Int", 2, "Ptr", ia, "Ptr", 0, "Ptr", 0, "Int")
    if (ia)
        DllCall("gdiplus\GdipDisposeImageAttributes", "Ptr", ia, "Int")
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g, "Int")
    return dst
}

; Draws the "?" icon (falls back to the grey square only if it could not be built).
GdipDrawIconUnknown(g, x, y, size) {
    master := GetUnknownIconMaster()
    if (master)
        GdipDrawMasterIcon(g, master, x, y, size)
    else
        GdipDrawIconPlaceholder(g, x, y, size)
}

; Draws the icon of `title` at (x, y) of the row's buffer DC. GDI+ draws in plain buffer coordinates, so the DC's shifted
; viewport origin is set to 0 for this call and restored after it.
DrawRowIcon(hdc, originLeft, originTop, x, y, title) {
    global gdiplusToken
    if (!gdiplusToken)
        return
    size := RowIconSize()
    master := GetGameIconBitmap(title)
    DllCall("Gdi32\SetViewportOrgEx", "Ptr", hdc, "Int", 0, "Int", 0, "Ptr", 0)
    g := 0
    if (DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr*", &g, "Int") = 0 && g) {
        if (master)
            GdipDrawMasterIcon(g, master, x - originLeft, y - originTop, size)
        else if (GameIconIsMissing(title))
            GdipDrawIconUnknown(g, x - originLeft, y - originTop, size)      ; no picture exists for this game: Discord's "?" icon
        else
            GdipDrawIconPlaceholder(g, x - originLeft, y - originTop, size)  ; still loading
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g, "Int")
    }
    DllCall("Gdi32\SetViewportOrgEx", "Ptr", hdc, "Int", -originLeft, "Int", -originTop, "Ptr", 0)
}

; A size x size GDI bitmap of the icon on a black background, for static controls. master = 0: the grey square (still loading),
; or the "?" icon when missing = true (no picture exists for the game).
MakeIconHBitmap(master, size, missing := false) {
    global gdiplusToken
    if (!gdiplusToken || size < 4)
        return 0
    bmp := 0, g := 0, hbm := 0
    if (DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", size, "Int", size, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp, "Int") != 0 || !bmp)
        return 0
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &g, "Int")
    if (g) {
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", 0xFF000000, "Int")
        if (master)
            GdipDrawMasterIcon(g, master, 0, 0, size)
        else if (missing)
            GdipDrawIconUnknown(g, 0, 0, size)
        else
            GdipDrawIconPlaceholder(g, 0, 0, size)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g, "Int")
    }
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bmp, "Ptr*", &hbm, "UInt", 0xFF000000, "Int")
    DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp, "Int")
    return hbm
}

; ---- cache ----------------------------------------------------------------------------------
; ALL icons live in ONE file: icons\icons.pack (nothing else is kept in the icons folder). The icons inside are the very same 32 x 32 PNG files
; that were kept one by one before (PNG is lossless, so every pixel is identical); they are only grouped into segments of up to 128 icons and each
; segment is compressed with Windows' own compression (XPRESS Huffman), so there are no thousands of small files to open, scan and write any more.
;
; FILE LAYOUT (all numbers little endian):
;   file header  (8 bytes)   "RGNP", UInt version = 1
;   then any number of segments, one after the other:
;     segment header (28 bytes)  "RSG1", UInt mode (0 stored / 4 compressed), UInt idxBytes, UInt rawSize, UInt packedSize, UInt crc32 of the stored data, UInt entries
;     idxBytes of UTF-8 text, one line per entry:   title TAB hash TAB pngLength      an icon (its PNG is inside the data, in line order)
;                                                   title TAB !hash TAB dayNumber     Discord has no picture for it (asked again after a few days)
;                                                   title TAB -     TAB 0             the icon was deleted
;     packedSize bytes: the PNG files of all icon lines back to back (compressed together when mode = 4)
; The directory (the text of every segment) is read at start-up in tiny slices; a segment's data is only read + decompressed when one of its
; icons is needed (the last few segments stay in memory). New icons are collected in memory and appended to the file as ONE new segment every
; 128 icons / 2.5 s of quiet / when the app closes. The last line of a title wins; superseded data is removed by an occasional rewrite (GameIconPackCompact).

GameIconKeyIsSafe(key) {
    return !(InStr(key, "`t") || InStr(key, "`n") || InStr(key, "`r"))
}

; Windows' compression API (cabinet.dll). One compressor / decompressor handle is created on first use and reused.
; Returns true and the compressed bytes only when they are smaller than the original (otherwise the segment is simply stored).
GameIconCompress(src, srcLen, &out, &outLen) {
    global gameIconComp
    out := 0, outLen := 0
    if (srcLen < 64)
        return false
    try {
        if (!gameIconComp) {
            h := 0
            if (DllCall("cabinet\CreateCompressor", "UInt", 4, "Ptr", 0, "Ptr*", &h, "Int") && h)
                gameIconComp := h
        }
        if (!gameIconComp)
            return false
        buf := Buffer(srcLen + 4096)
        got := 0
        if (DllCall("cabinet\Compress", "Ptr", gameIconComp, "Ptr", src, "UPtr", srcLen, "Ptr", buf, "UPtr", buf.Size, "UPtr*", &got, "Int") && got > 0 && got < srcLen) {
            out := buf, outLen := got
            return true
        }
    }
    return false
}

GameIconDecompress(src, srcLen, rawSize) {
    global gameIconDecomp
    try {
        if (!gameIconDecomp) {
            h := 0
            if (DllCall("cabinet\CreateDecompressor", "UInt", 4, "Ptr", 0, "Ptr*", &h, "Int") && h)
                gameIconDecomp := h
        }
        if (!gameIconDecomp)
            return 0
        out := Buffer(Max(rawSize, 1))
        got := 0
        if (DllCall("cabinet\Decompress", "Ptr", gameIconDecomp, "Ptr", src, "UPtr", srcLen, "Ptr", out, "UPtr", rawSize, "UPtr*", &got, "Int") && got = rawSize)
            return out
    }
    return 0
}

GameIconCrc(buf, len) {
    c := 0
    if (len > 0) {
        try c := DllCall("ntdll\RtlComputeCrc32", "UInt", 0, "Ptr", buf, "UInt", len, "UInt")
    }
    return c
}

; Appends ONE segment to the open file f. items: array of [key, kind, hash, payload] (kind 1 icon: payload = PNG Buffer, kind 2 "no picture": payload =
; day number, kind 0 deleted). The segment is registered in segs / loc only after every byte was written. Returns true on success.
GameIconPackWriteSegment(f, items, segs, loc) {
    global gameIconPackNeedsRewrite
    total := 0
    for it in items {
        if (it[2] = 1)
            total += it[4].Size
    }
    raw := Buffer(Max(total, 1))
    idxText := ""
    offs := []
    off := 0
    for it in items {
        if (it[2] = 1) {
            len := it[4].Size
            DllCall("kernel32\RtlMoveMemory", "Ptr", raw.Ptr + off, "Ptr", it[4].Ptr, "UPtr", len)
            idxText .= it[1] "`t" it[3] "`t" len "`n"
            offs.Push(off)
            off += len
        } else if (it[2] = 2) {
            idxText .= it[1] "`t!" it[3] "`t" it[4] "`n"
            offs.Push(0)
        } else {
            idxText .= it[1] "`t-`t0`n"
            offs.Push(0)
        }
    }
    payload := raw, packedLen := total, mode := 0
    if (total > 0) {
        cbuf := 0, clen := 0
        if (GameIconCompress(raw, total, &cbuf, &clen))
            payload := cbuf, packedLen := clen, mode := 4
    }
    ib := Buffer(StrPut(idxText, "UTF-8"))
    StrPut(idxText, ib, "UTF-8")
    idxBytes := ib.Size - 1
    crc := GameIconCrc(payload, packedLen)
    hdr := Buffer(28, 0)
    NumPut("UInt", 0x31475352, hdr, 0)
    NumPut("UInt", mode, hdr, 4)
    NumPut("UInt", idxBytes, hdr, 8)
    NumPut("UInt", total, hdr, 12)
    NumPut("UInt", packedLen, hdr, 16)
    NumPut("UInt", crc, hdr, 20)
    NumPut("UInt", items.Length, hdr, 24)
    f.Seek(0, 2)                                       ; (append mode is already at the end; this also makes sure nothing is buffered)
    startLen := f.Pos
    extra := (startLen = 0) ? 8 : 0                    ; a new file starts with the file header
    blob := Buffer(extra + 28 + idxBytes + packedLen)
    if (extra) {
        NumPut("UInt", 0x504E4752, blob, 0)
        NumPut("UInt", 1, blob, 4)
    }
    DllCall("kernel32\RtlMoveMemory", "Ptr", blob.Ptr + extra, "Ptr", hdr.Ptr, "UPtr", 28)
    if (idxBytes > 0)
        DllCall("kernel32\RtlMoveMemory", "Ptr", blob.Ptr + extra + 28, "Ptr", ib.Ptr, "UPtr", idxBytes)
    if (packedLen > 0)
        DllCall("kernel32\RtlMoveMemory", "Ptr", blob.Ptr + extra + 28 + idxBytes, "Ptr", payload.Ptr, "UPtr", packedLen)
    n := 0
    try n := f.RawWrite(blob, blob.Size)
    if (n != blob.Size) {
        gameIconPackNeedsRewrite := true                ; a half written tail: the whole pack is rewritten cleanly before anything else is appended
        return false
    }
    segId := segs.Length + 1
    segs.Push({pos: startLen + extra, dataPos: startLen + extra + 28 + idxBytes, rawSize: total, packed: packedLen, mode: mode, crc: crc, bad: false, text: ""})
    for i, it in items {
        if (it[2] = 1)
            loc[it[1]] := [segId, offs[i], it[4].Size]
    }
    return true
}

; Reads the segment directory of the pack file (headers + index text only, the icon data is skipped). Returns false when the file is not a pack
; of this format. A damaged / half written tail is ignored and flagged (the pack is then rewritten without it).
GameIconPackScan() {
    global gameIconPackPath, gameIconPackSegs, gameIconIdxSegs, gameIconPackNeedsRewrite
    f := ""
    try f := FileOpen(gameIconPackPath, "r", "UTF-8-RAW")
    if (!IsObject(f))
        return false
    ok := false
    segs := []
    try {
        size := f.Length
        h := Buffer(8)
        if (size >= 8 && f.RawRead(h, 8) = 8 && NumGet(h, 0, "UInt") = 0x504E4752 && NumGet(h, 4, "UInt") = 1) {
            ok := true
            pos := 8
            hdr := Buffer(28)
            while (pos + 28 <= size) {
                f.Pos := pos
                if (f.RawRead(hdr, 28) != 28 || NumGet(hdr, 0, "UInt") != 0x31475352)
                    break
                mode := NumGet(hdr, 4, "UInt"), idxBytes := NumGet(hdr, 8, "UInt"), rawSize := NumGet(hdr, 12, "UInt")
                packed := NumGet(hdr, 16, "UInt"), crc := NumGet(hdr, 20, "UInt")
                end := pos + 28 + idxBytes + packed
                if ((mode != 0 && mode != 4) || end > size)
                    break
                text := ""
                if (idxBytes > 0) {
                    tb := Buffer(idxBytes)
                    if (f.RawRead(tb, idxBytes) != idxBytes)
                        break
                    text := StrGet(tb, idxBytes, "UTF-8")
                }
                segs.Push({pos: pos, dataPos: pos + 28 + idxBytes, rawSize: rawSize, packed: packed, mode: mode, crc: crc, bad: false, text: text})
                pos := end
            }
            if (pos != size)
                gameIconPackNeedsRewrite := true
        }
    }
    try f.Close()
    if (!ok)
        return false
    gameIconPackSegs := segs
    gameIconIdxSegs := segs
    return true
}

; The decompressed data of a segment (kept in a small least-recently-used cache), or 0 when it cannot be read / is damaged.
GameIconPackSegmentRaw(segId) {
    global gameIconPackSegs, gameIconSegCache, gameIconSegOrder, gameIconPackPath
    if (gameIconSegCache.Has(segId)) {
        for i, v in gameIconSegOrder {
            if (v = segId) {
                gameIconSegOrder.RemoveAt(i)
                break
            }
        }
        gameIconSegOrder.Push(segId)
        return gameIconSegCache[segId]
    }
    if (segId < 1 || segId > gameIconPackSegs.Length)
        return 0
    seg := gameIconPackSegs[segId]
    if (seg.bad)
        return 0
    packed := Buffer(Max(seg.packed, 1))
    ok := false
    try {
        f := FileOpen(gameIconPackPath, "r", "UTF-8-RAW")
        f.Pos := seg.dataPos
        got := (seg.packed > 0) ? f.RawRead(packed, seg.packed) : 0
        f.Close()
        ok := (got = seg.packed)
    }
    if (ok && GameIconCrc(packed, seg.packed) != seg.crc)
        ok := false
    raw := 0
    if (ok)
        raw := (seg.mode = 0) ? packed : GameIconDecompress(packed, seg.packed, seg.rawSize)
    if (!raw) {
        seg.bad := true
        return 0
    }
    gameIconSegCache[segId] := raw
    gameIconSegOrder.Push(segId)
    while (gameIconSegOrder.Length > 8) {
        old := gameIconSegOrder.RemoveAt(1)
        if (gameIconSegCache.Has(old))
            gameIconSegCache.Delete(old)
    }
    return raw
}

; Where the PNG bytes of an icon are right now: {ptr, len, keep} or 0. (keep holds the memory alive while ptr is used.)
GameIconPackGet(key) {
    global gameIconPackPend, gameIconPackLoc, gameIconMig, gameIconFileNames, gameIconUnknownKey, gameIconUnknownFile, gameIconDir
    if (gameIconPackPend.Has(key)) {
        p := gameIconPackPend[key]
        if (p[1] != 1)
            return 0
        return {ptr: p[3].Ptr, len: p[3].Size, keep: p[3]}
    }
    if (gameIconPackLoc.Has(key)) {
        loc := gameIconPackLoc[key]
        raw := GameIconPackSegmentRaw(loc[1])
        if (!raw || loc[2] < 0 || loc[2] + loc[3] > raw.Size)
            return 0
        return {ptr: raw.Ptr + loc[2], len: loc[3], keep: raw}
    }
    if (IsObject(gameIconMig)) {                       ; the old folder is still being moved into the pack: this icon is still its own PNG file there
        name := (key = gameIconUnknownKey) ? gameIconUnknownFile : (gameIconFileNames.Has(key) ? gameIconFileNames[key] : "")
        if (name != "") {
            buf := 0
            try buf := FileRead(gameIconDir "\" name ".png", "RAW")
            if (buf && buf.Size >= 16)
                return {ptr: buf.Ptr, len: buf.Size, keep: buf}
        }
    }
    return 0
}

; The finished 32 x 32 master of an icon stored in the pack (no network), or 0.
GameIconPackLoadMaster(key) {
    r := GameIconPackGet(key)
    if (!r)
        return 0
    return GameIconBuildMaster(r.ptr, r.len, true)
}

GameIconPackSchedule() {
    global gameIconPackPend
    if (gameIconPackPend.Count >= 128)
        GameIconPackFlush()
    else
        SetTimer(GameIconPackFlush, -2500)
}

; Remembers a new icon (PNG bytes). It is written to the file with the next segment; until then it is served from memory.
GameIconPackAdd(key, hash, png) {
    global gameIconPackPend, gameIconPackLoc, gameIconPackDead
    if (!IsObject(png) || !GameIconKeyIsSafe(key))
        return
    if (gameIconPackLoc.Has(key))
        gameIconPackDead += 1
    gameIconPackPend[key] := [1, hash, png]
    GameIconPackSchedule()
}

GameIconPackAddMissing(key, hash, day) {
    global gameIconPackPend
    if (!GameIconKeyIsSafe(key))
        return
    if (gameIconPackPend.Has(key) && gameIconPackPend[key][1] = 1)
        return
    gameIconPackPend[key] := [2, hash, day]
    GameIconPackSchedule()
}

; An icon is gone / damaged: removed from the pack's directory (the bytes are dropped by the next rewrite).
GameIconPackDrop(key) {
    global gameIconPackPend, gameIconPackLoc, gameIconPackDead
    if (gameIconPackPend.Has(key))
        gameIconPackPend.Delete(key)
    if (gameIconPackLoc.Has(key)) {
        gameIconPackLoc.Delete(key)
        gameIconPackDead += 1
        if (GameIconKeyIsSafe(key)) {
            gameIconPackPend[key] := [0, "-", 0]
            GameIconPackSchedule()
        }
    }
}

; Writes everything collected in memory as one new segment at the end of the pack file.
GameIconPackFlush(*) {
    global gameIconPackPend, gameIconPackPath, gameIconPackSegs, gameIconPackLoc, gameIconIdxReady, gameIconPackNeedsRewrite
    SetTimer(GameIconPackFlush, 0)
    if (gameIconPackPend.Count = 0)
        return true
    if (!gameIconIdxReady)
        return false
    if (gameIconPackNeedsRewrite) {
        if (!GameIconPackCompact()) {
            SetTimer(GameIconPackFlush, -20000)
            return false
        }
        return true                                    ; the rewrite wrote the pending entries too
    }
    items := []
    for key, p in gameIconPackPend
        items.Push([key, p[1], p[2], p[3]])
    dir := ""
    SplitPath(gameIconPackPath, , &dir)
    try DirCreate(dir)
    f := ""
    try f := FileOpen(gameIconPackPath, "a", "UTF-8-RAW")
    ok := false
    if (IsObject(f)) {
        try ok := GameIconPackWriteSegment(f, items, gameIconPackSegs, gameIconPackLoc)
        try f.Close()
    }
    if (!ok) {
        SetTimer(GameIconPackFlush, -15000)
        return false
    }
    gameIconPackPend.Clear()
    return true
}

GameIconPackOnExit(*) {
    try GameIconPackFlush()
    return 0
}

; Rewrites the whole pack into a fresh file: only live icons, sorted by title (so icons that are shown together sit in the same segment),
; no superseded data, no damaged tail. Also writes everything that is still pending. Returns true when done.
GameIconPackCompact() {
    global gameIconPackPath, gameIconPackSegs, gameIconPackLoc, gameIconPackPend, gameIconSegCache, gameIconSegOrder
    global gameIconPackDead, gameIconPackNeedsRewrite, gameIconFileNames, gameIconNoIcon, gameIconUnknownKey
    list := ""
    for key in gameIconPackLoc {
        if (gameIconPackPend.Has(key) && gameIconPackPend[key][1] != 1)
            continue
        list .= key "`n"
    }
    for key, p in gameIconPackPend {
        if (p[1] = 1 && !gameIconPackLoc.Has(key))
            list .= key "`n"
    }
    list := RTrim(list, "`n")
    if (list != "")
        list := Sort(list)
    newPath := gameIconPackPath ".new"
    try FileDelete(newPath)
    dir := ""
    SplitPath(gameIconPackPath, , &dir)
    try DirCreate(dir)
    f := ""
    try f := FileOpen(newPath, "a", "UTF-8-RAW")
    if (!IsObject(f))
        return false
    newSegs := [], newLoc := Map()
    ok := true
    items := []
    if (list != "") {
        for key in StrSplit(list, "`n") {
            r := GameIconPackGet(key)
            if (!r)
                continue                               ; unreadable: dropped (it is fetched again when needed)
            hash := (key = gameIconUnknownKey) ? "u" : (gameIconFileNames.Has(key) ? gameIconFileNames[key] : "")
            if (hash = "")
                continue
            buf := Buffer(r.len)
            DllCall("kernel32\RtlMoveMemory", "Ptr", buf.Ptr, "Ptr", r.ptr, "UPtr", r.len)
            items.Push([key, 1, hash, buf])
            if (items.Length >= 128) {
                if (!GameIconPackWriteSegment(f, items, newSegs, newLoc)) {
                    ok := false
                    break
                }
                items := []
            }
        }
    }
    if (ok) {
        for key, rec in gameIconNoIcon {
            if (!gameIconFileNames.Has(key) && GameIconKeyIsSafe(key))
                items.Push([key, 2, rec[2], rec[1]])
        }
        if (items.Length > 0 && !GameIconPackWriteSegment(f, items, newSegs, newLoc))
            ok := false
    }
    try f.Close()
    if (ok && newSegs.Length = 0) {                    ; nothing left to keep
        try FileDelete(newPath)
        try FileDelete(gameIconPackPath)
    } else if (ok) {
        try {
            FileMove(newPath, gameIconPackPath, 1)
        } catch {
            ok := false
        }
    }
    if (!ok) {
        try FileDelete(newPath)
        return false
    }
    gameIconPackSegs := newSegs
    gameIconPackLoc := newLoc
    gameIconPackPend.Clear()
    gameIconSegCache := Map()
    gameIconSegOrder := []
    gameIconPackDead := 0
    gameIconPackNeedsRewrite := false
    return true
}

; Idle check after the directory was read: a rewrite is only worth it when a lot of superseded data piled up / the tail is damaged.
GameIconPackMaintain(*) {
    global gameIconMig, isExiting, animationActive, isWindowMoving, gameIconPackLoc, gameIconPackDead, gameIconPackNeedsRewrite, gameIconPackSegs
    if (isExiting)
        return
    if (IsObject(gameIconMig) || animationActive || isWindowMoving) {
        SetTimer(GameIconPackMaintain, -3000)
        return
    }
    if (gameIconPackNeedsRewrite || (gameIconPackDead > 600 && gameIconPackDead * 4 > gameIconPackLoc.Count) || gameIconPackSegs.Length > 500)
        GameIconPackCompact()
}

; ---- the directory (which icon is in the pack) ---------------------------------------------------------------------------------
; There is NO directory scan of the disk and no file per icon: "does this game have an icon?" is a plain Map lookup, so the cache check on
; refresh costs next to nothing.
GameIconIndexForget(key) {
    global gameIconFileNames
    if (gameIconFileNames.Has(key))
        gameIconFileNames.Delete(key)
    GameIconPackDrop(key)
}

GameIconPackApplyLine(segId, line) {
    global gameIconFileNames, gameIconPackLoc, gameIconNoIcon, gameIconPackDead, gameIconIdxOff, gameIconUnknownKey
    if (line = "")
        return
    f := StrSplit(line, "`t")
    if (f.Length < 3)
        return
    key := f[1], h := f[2], n := 0
    try n := Integer(f[3])
    if (h = "-") {
        if (gameIconPackLoc.Has(key)) {
            gameIconPackLoc.Delete(key)
            gameIconPackDead += 1
        }
        if (gameIconFileNames.Has(key))
            gameIconFileNames.Delete(key)
        if (gameIconNoIcon.Has(key))
            gameIconNoIcon.Delete(key)
        return
    }
    if (SubStr(h, 1, 1) = "!") {
        gameIconNoIcon[key] := [n, SubStr(h, 2)]
        return
    }
    if (gameIconPackLoc.Has(key))
        gameIconPackDead += 1
    gameIconPackLoc[key] := [segId, gameIconIdxOff, n]
    gameIconIdxOff += n
    if (key != gameIconUnknownKey) {
        gameIconFileNames[key] := h
        if (gameIconNoIcon.Has(key))
            gameIconNoIcon.Delete(key)
    }
}

; ---- the old folder (one PNG per icon + icons.idx) is moved into the pack once -------------------------------------------------
GameIconLegacyApplyLine(line) {
    global gameIconUnknownFile, gameIconFileNames
    if (line = "")
        return
    f := StrSplit(line, "`t")
    if (f.Length < 2)
        return
    key := f[1]
    if (key = "") {                                  ; special line: <tab>unknown<tab><file of the "?" icon>
        if (f[2] = "unknown" && f.Length >= 3)
            gameIconUnknownFile := f[3]
        return
    }
    if (f[2] = "-") {
        if (gameIconFileNames.Has(key))
            gameIconFileNames.Delete(key)
        return
    }
    if (f[2] != "")
        gameIconFileNames[key] := f[2]
}

; Icons of the very old naming scheme (named after the game's title, 64 x 64, no icons.idx) are not used any more. The whole folder is renamed
; (instant, nothing to wait for) and deleted by a hidden background command, so the app never waits for thousands of deletes.
GameIconLegacyMove() {
    global gameIconDir
    if (!DirExist(gameIconDir))
        return
    if (!FileExist(gameIconDir "\*.png"))
        return
    old := gameIconDir "_old_" A_TickCount
    try {
        DirMove(gameIconDir, old, "R")
        Run(A_ComSpec ' /c rd /s /q "' old '"', , "Hide")
    }
}

; The directory of the old folder is known (title -> hash); the PNG files are copied into a new pack in the background (sorted by title, a few
; milliseconds per slice). Until a file is copied it is read straight from the old folder, so no icon is ever missing meanwhile.
GameIconMigrateBegin() {
    global gameIconFileNames, gameIconMig, gameIconPackPath, gameIconDir, gameIconUnknownFile, gameIconUnknownKey
    gameIconPackPath := gameIconDir "\icons.pack.new"
    try FileDelete(gameIconPackPath)
    list := ""
    for key in gameIconFileNames
        list .= key "`n"
    list := RTrim(list, "`n")
    if (list != "")
        list := Sort(list)
    keys := (list = "") ? [] : StrSplit(list, "`n")
    if (gameIconUnknownFile != "")
        keys.InsertAt(1, gameIconUnknownKey)
    gameIconMig := {keys: keys, pos: 1}
    SetTimer(GameIconMigrateTick, -400)
}

GameIconMigrateTick(*) {
    global gameIconMig, gameIconPackLoc, gameIconPackPend, gameIconFileNames, gameIconUnknownKey, gameIconUnknownFile, gameIconDir
    global isExiting, isWindowMoving, animationActive
    if (!IsObject(gameIconMig) || isExiting)
        return
    if (isWindowMoving || animationActive) {
        SetTimer(GameIconMigrateTick, -80)
        return
    }
    t0 := A_TickCount
    keys := gameIconMig.keys
    n := keys.Length
    while (gameIconMig.pos <= n && A_TickCount - t0 < 8) {
        key := keys[gameIconMig.pos]
        gameIconMig.pos += 1
        if (gameIconPackLoc.Has(key) || gameIconPackPend.Has(key))
            continue                                   ; already in the pack (downloaded in the meantime)
        isUnknown := (key = gameIconUnknownKey)
        name := isUnknown ? gameIconUnknownFile : (gameIconFileNames.Has(key) ? gameIconFileNames[key] : "")
        if (name = "")
            continue
        buf := 0
        try buf := FileRead(gameIconDir "\" name ".png", "RAW")
        if (!buf || buf.Size < 16) {
            if (!isUnknown && gameIconFileNames.Has(key))
                gameIconFileNames.Delete(key)          ; file lost: fetched again
            continue
        }
        GameIconPackAdd(key, isUnknown ? "u" : name, buf)
    }
    if (gameIconMig.pos <= n) {
        SetTimer(GameIconMigrateTick, -12)
        return
    }
    GameIconMigrateFinish()
}

GameIconMigrateFinish() {
    global gameIconMig, gameIconPackPath, gameIconPackPend, gameIconDir
    GameIconPackFlush()
    if (gameIconPackPend.Count > 0) {                  ; the file could not be written just now: try again in a moment
        SetTimer(GameIconMigrateTick, -5000)
        return
    }
    final := gameIconDir "\icons.pack"
    try FileMove(gameIconPackPath, final, 1)
    if (FileExist(final) && !FileExist(gameIconPackPath))
        gameIconPackPath := final                      ; (the offsets stay valid: it is the same file)
    if (gameIconPackPath = final)
        try Run(A_ComSpec ' /c del /q "' gameIconDir '\*.png" "' gameIconDir '\icons.idx"', , "Hide")
    gameIconMig := ""
    SetTimer(GameIconPackMaintain, -3000)
}

; ---- reading the directory in slices -------------------------------------------------------------------------------------------
; Decides what is on disk: a pack (read its directory), the old one-PNG-per-icon folder (moved into a pack), or nothing.
GameIconIndexStart() {
    global gameIconPackPath, gameIconDir, gameIconIdxStage, gameIconIdxSegPos, gameIconIdxLines, gameIconIdxLinePos
    try FileDelete(gameIconPackPath ".new")            ; leftover of an interrupted rewrite / move
    if (FileExist(gameIconPackPath)) {
        if (GameIconPackScan()) {
            gameIconIdxStage := 1
            gameIconIdxSegPos := 1
            return
        }
        try FileDelete(gameIconPackPath)               ; not a pack of this version: thrown away (its icons are fetched again)
    }
    idx := gameIconDir "\icons.idx"
    if (FileExist(idx)) {
        text := ""
        try text := FileRead(idx, "UTF-8")
        gameIconIdxLines := StrSplit(text, "`n", "`r")
        gameIconIdxLinePos := 1
        gameIconIdxStage := 2
        return
    }
    GameIconLegacyMove()
    GameIconIndexFinish()
}

GameIconIndexFinish() {
    global gameIconIdxReady, gameIconDir, gameIconPackPath, gameIconMig
    gameIconIdxReady := true
    if (IsObject(gameIconMig))
        return
    if (FileExist(gameIconPackPath) && (FileExist(gameIconDir "\icons.idx") || FileExist(gameIconDir "\*.png")))
        try Run(A_ComSpec ' /c del /q "' gameIconDir '\*.png" "' gameIconDir '\icons.idx"', , "Hide")   ; strays of the old format next to a good pack
    SetTimer(GameIconPackMaintain, -2500)
}

; One step of reading the directory. budgetMs > 0: stops after about that many milliseconds (called again by the timer); 0: finishes at once.
GameIconIndexStep(budgetMs) {
    global gameIconIdxReady, gameIconIdxStage, gameIconIdxSegs, gameIconIdxSegPos, gameIconIdxLines, gameIconIdxLinePos, gameIconIdxOff
    if (gameIconIdxReady)
        return
    t0 := A_TickCount
    if (gameIconIdxStage = 0) {
        GameIconIndexStart()
        if (gameIconIdxReady || budgetMs > 0)
            return
    }
    if (gameIconIdxStage = 1) {
        while (gameIconIdxSegPos <= gameIconIdxSegs.Length) {
            seg := gameIconIdxSegs[gameIconIdxSegPos]
            if (!IsObject(gameIconIdxLines)) {
                gameIconIdxLines := StrSplit(seg.text, "`n", "`r")
                seg.text := ""
                gameIconIdxLinePos := 1
                gameIconIdxOff := 0
            }
            n := gameIconIdxLines.Length
            while (gameIconIdxLinePos <= n) {
                GameIconPackApplyLine(gameIconIdxSegPos, gameIconIdxLines[gameIconIdxLinePos])
                gameIconIdxLinePos += 1
                if (budgetMs > 0 && Mod(gameIconIdxLinePos, 50) = 0 && A_TickCount - t0 >= budgetMs)
                    return
            }
            gameIconIdxLines := ""
            gameIconIdxSegPos += 1
        }
        gameIconIdxSegs := ""
        GameIconIndexFinish()
        return
    }
    if (gameIconIdxStage = 2) {
        n := gameIconIdxLines.Length
        while (gameIconIdxLinePos <= n) {
            GameIconLegacyApplyLine(gameIconIdxLines[gameIconIdxLinePos])
            gameIconIdxLinePos += 1
            if (budgetMs > 0 && Mod(gameIconIdxLinePos, 200) = 0 && A_TickCount - t0 >= budgetMs)
                return
        }
        gameIconIdxLines := ""
        GameIconMigrateBegin()
        GameIconIndexFinish()
    }
}

GameIconIndexTick(*) {
    global gameIconIdxReady, isExiting
    if (gameIconIdxReady || isExiting)
        return
    GameIconIndexStep(4)
    if (!gameIconIdxReady)
        SetTimer(GameIconIndexTick, -8)
}

; Makes sure the directory is read (normally done long before: the timer reads it in the background).
GameIconIndexEnsure() {
    global gameIconIdxReady
    while (!gameIconIdxReady)
        GameIconIndexStep(0)
}

; Encodes a master as PNG into memory (lossless). Returns a Buffer with the PNG bytes, or 0.
GameIconEncodeMaster(master) {
    if (!master)
        return 0
    stm := 0, hg := 0, len := 0, out := 0
    try {
        clsid := Buffer(16, 0)
        DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)   ; PNG encoder
        if (DllCall("ole32\CreateStreamOnHGlobal", "Ptr", 0, "Int", true, "Ptr*", &stm, "Int") != 0 || !stm)
            return 0
        if (DllCall("gdiplus\GdipSaveImageToStream", "Ptr", master, "Ptr", stm, "Ptr", clsid, "Ptr", 0, "Int") = 0) {
            ComCall(5, stm, "Int64", 0, "UInt", 1, "UInt64*", &len)           ; IStream::Seek(0, CUR) = number of bytes written
            DllCall("ole32\GetHGlobalFromStream", "Ptr", stm, "Ptr*", &hg)
            p := DllCall("Kernel32\GlobalLock", "Ptr", hg, "Ptr")
            if (p) {
                if (len > 0) {
                    out := Buffer(len)
                    DllCall("kernel32\RtlMoveMemory", "Ptr", out.Ptr, "Ptr", p, "UPtr", len)
                }
                DllCall("Kernel32\GlobalUnlock", "Ptr", hg)
            }
        }
    }
    if (stm)
        ObjRelease(stm)
    return out
}

; Saves the "?" icon in the pack.
GameIconUnknownPersist(master) {
    global gameIconUnknownKey
    png := GameIconEncodeMaster(master)
    if (png)
        GameIconPackAdd(gameIconUnknownKey, "u", png)
}

GameIconForgetState(key) {
    global gameIconState
    if (gameIconState.Has(key))
        gameIconState.Delete(key)
}

GameIconCacheStore(key, master) {
    global gameIconBitmaps, gameIconBitmapCap
    if (gameIconBitmaps.Count > gameIconBitmapCap) {                  ; keep memory bounded (the cap holds the whole list)
        for k, b in gameIconBitmaps
            DllCall("gdiplus\GdipDisposeImage", "Ptr", b, "Int")
        gameIconBitmaps.Clear()
    }
    if (gameIconBitmaps.Has(key) && gameIconBitmaps[key] != master)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", gameIconBitmaps[key], "Int")
    gameIconBitmaps[key] := master
    GameIconForgetState(key)
}

; Is the icon in the pack older than what Discord offers now? The stored hash IS the hash the icon was made from, so this is one string
; comparison with the hash of the fresh list (only Map lookups: cheap enough to ask for thousands of titles per second).
GameIconNeedsUpdate(key) {
    global gameIconFileNames, gameIconHashes
    if (!gameIconFileNames.Has(key))
        return true
    return gameIconHashes.Has(key) && gameIconHashes[key] != gameIconFileNames[key]
}

; Days since 2000-01-01 (UTC).
GameIconToday() {
    return DateDiff(A_NowUTC, "20000101", "Days")
}

; True when Discord was asked recently (and with the same icon hash) and had no picture for this game: it keeps showing "?" and is not asked again
; on every refresh (that was thousands of useless requests per refresh).
GameIconNoIconFresh(key) {
    global gameIconNoIcon, gameIconHashes, gameIconNoIconDays
    if (!gameIconNoIcon.Has(key))
        return false
    rec := gameIconNoIcon[key]
    want := gameIconHashes.Has(key) ? gameIconHashes[key] : ""
    return (rec[2] = want && GameIconToday() - rec[1] < gameIconNoIconDays)
}

GameIconNoIconSet(key, hash) {
    global gameIconNoIcon, gameIconFileNames
    if (gameIconFileNames.Has(key))
        return
    day := GameIconToday()
    gameIconNoIcon[key] := [day, hash]
    GameIconPackAddMissing(key, hash, day)
}

; True when nothing has to be fetched for this title right now (icon in the pack and up to date, known to have no picture, or already looked at since the last refresh).
GameIconIsCurrent(key) {
    global gameIconFileNames, gameIconUpdateTried
    if (gameIconUpdateTried.Has(key))
        return true
    if (gameIconFileNames.Has(key))
        return !GameIconNeedsUpdate(key)
    return GameIconNoIconFresh(key)
}

; Called by every refresh of the list: the icon check starts over (failed icons get another chance, every icon is compared with the fresh list).
GameIconRefreshCycle() {
    global gameIconUpdateTried
    gameIconUpdateTried := Map()
}

; Loads a game's finished icon from the pack (no network). Returns the master or 0.
TryLoadIconFromDisk(key) {
    global gameIconFileNames
    GameIconIndexEnsure()
    if (!gameIconFileNames.Has(key))
        return 0
    master := GameIconPackLoadMaster(key)
    if (!master) {
        GameIconIndexForget(key)                     ; missing / damaged / another size: fetched again (the new icon replaces it)
        return 0
    }
    GameIconCacheStore(key, master)
    return master
}

; Stores the finished icon (32 x 32 PNG with transparent corners, lossless) in the pack.
GameIconSaveMaster(key, master, hash) {
    global gameIconFileNames, gameIconNoIcon
    if (!master || hash = "" || !GameIconKeyIsSafe(key))
        return
    GameIconIndexEnsure()
    png := GameIconEncodeMaster(master)
    if (!png)
        return
    gameIconFileNames[key] := hash
    if (gameIconNoIcon.Has(key))
        gameIconNoIcon.Delete(key)
    GameIconPackAdd(key, hash, png)
}

; The cached icon of a title, or 0 (the picture is then loaded from the pack at once if it is there, otherwise queued).
; A cached icon that is out of date stays on screen and is replaced quietly in the background when the new one has arrived.
GetGameIconBitmap(title) {
    global gameIconBitmaps, gameIconState, gameIconUpdateTried, gameIconPrefetch
    key := StrLower(title)
    if (gameIconBitmaps.Has(key)) {
        if (!gameIconState.Has(key) && !gameIconUpdateTried.Has(key) && GameIconNeedsUpdate(key)) {
            gameIconState[key] := 1
            gameIconPrefetch.InsertAt(1, title)
            SetTimer(GameIconTick, 10)
        }
        return gameIconBitmaps[key]
    }
    if (!gameIconState.Has(key)) {
        master := TryLoadIconFromDisk(key)
        if (master)
            return master
        if (GameIconNoIconFresh(key))
            return 0                                 ; Discord has no picture (checked recently): "?" without asking again
        QueueGameIcon(title)
    }
    return 0
}

; Finds the list key of a game from its title (or, when that fails, from its app ID).
FindGameKey(name, appId := "") {
    global gameAppIds
    key := StrLower(Trim(name))
    if (key != "" && gameAppIds.Has(key))
        return key
    if (appId != "") {
        for k, v in gameAppIds {
            if (v = appId)
                return k
        }
    }
    return ""
}

; ---- downloading ----------------------------------------------------------------------------
; Where a picture comes from: Discord's own application icon, https://cdn.discordapp.com/app-icons/<appId>/<hash>.png (the hash comes from
; the detectable list; when the list has none, the app's public record is asked for it first).
; Stages of a job: "meta" (find the hash) / "img" (the picture).
QueueGameIcon(title) {
    global gameIconState, gameIconQueue, gdiplusToken
    if (!gdiplusToken)
        return
    key := StrLower(title)
    if (gameIconState.Has(key))
        return                                       ; already queued / downloading / failed
    gameIconState[key] := 1
    gameIconQueue.Push(title)
    if (gameIconQueue.Length > 40) {                 ; fast scrolling: forget the oldest rows that are long gone
        dropped := gameIconQueue.RemoveAt(1)
        GameIconForgetState(StrLower(dropped))
    }
    SetTimer(GameIconTick, 10)
}

; Queues the icons of the first `count` titles (the ones the user will see first), behind everything that is on screen now.
PrefetchGameIcons(titles, count) {
    global gameIconState, gameIconBitmaps, gameIconPrefetch, gdiplusToken, rowIconsEnabled
    if (!gdiplusToken || !rowIconsEnabled || !IsObject(titles))
        return
    n := Min(count, titles.Length)
    queued := 0
    Loop n {
        t := titles[A_Index]
        key := StrLower(t)
        if (gameIconState.Has(key) || GameIconIsCurrent(key))
            continue                                 ; (an icon that is in the cache and up to date is loaded only when a row shows it)
        gameIconState[key] := 1
        gameIconPrefetch.Push(t)
        queued += 1
    }
    while (gameIconPrefetch.Length > 400) {
        dropped := gameIconPrefetch.Pop()
        GameIconForgetState(StrLower(dropped))
    }
    if (queued > 0)
        SetTimer(GameIconTick, 10)
}

; Fetches / loads the icons of the WHOLE list in the background (after the on-screen rows and the prefetch list), so no icon is
; still loading when the user scrolls. GameIconTick feeds from this list in small slices (see NextBulkIconTitle).
StartBulkIconPreload(titles) {
    global gameIconBulkList, gameIconBulkPos, gameIconBulkStartAt, gdiplusToken, rowIconsEnabled
    if (!gdiplusToken || !rowIconsEnabled || !IsObject(titles) || titles.Length = 0)
        return
    gameIconBulkList := titles
    gameIconBulkPos := 1
    gameIconBulkStartAt := A_TickCount + 600        ; lets the dropdown finish opening before the background work begins
    SetTimer(GameIconTick, 20)
}

; The next title of the bulk list that still needs its icon ("" = none right now). Looks at a limited number of titles per call,
; so a list that is mostly loaded already never causes a hitch; the list is dropped when its end is reached.
NextBulkIconTitle() {
    global gameIconBulkList, gameIconBulkPos, gameIconBulkStartAt, gameIconState
    if (!IsObject(gameIconBulkList) || A_TickCount < gameIconBulkStartAt)
        return ""
    n := gameIconBulkList.Length
    scanned := 0
    while (gameIconBulkPos <= n) {
        if (++scanned > 400)
            return ""
        t := gameIconBulkList[gameIconBulkPos]
        gameIconBulkPos += 1
        key := StrLower(t)
        if (gameIconState.Has(key) || GameIconIsCurrent(key))
            continue                                 ; already in the cache and up to date: nothing to do
        gameIconState[key] := 1
        return t
    }
    gameIconBulkList := ""
    return ""
}

; Discord answered 429 (too many requests): the game goes back to the front of the prefetch list and nothing new starts until the pause is over.
GameIconRequeue(job) {
    global gameIconPrefetch, gameIconRetryAt, gameIconMaxJobs
    gameIconMaxJobs := Max(10, gameIconMaxJobs - 6)    ; Discord says "too fast": fewer parallel downloads from now on
    wait := 0.0
    try wait := Number(job.xhr.getResponseHeader("Retry-After"))
    gameIconRetryAt := A_TickCount + Max(1500, Round(wait * 1000) + 250)
    gameIconPrefetch.InsertAt(1, job.title)
}

; Windows allows only a few connections per server by default (2-6): that is what made the icons arrive one after the other. Raised for this
; process (affects the WinINet based XMLHTTP objects used for the list and the icons).
GameIconNetworkTune() {
    v := Buffer(4, 0)
    NumPut("UInt", 32, v, 0)
    try DllCall("wininet\InternetSetOptionW", "Ptr", 0, "UInt", 73, "Ptr", v.Ptr, "UInt", 4, "Int")   ; INTERNET_OPTION_MAX_CONNS_PER_SERVER
    try DllCall("wininet\InternetSetOptionW", "Ptr", 0, "UInt", 74, "Ptr", v.Ptr, "UInt", 4, "Int")   ; INTERNET_OPTION_MAX_CONNS_PER_1_0_SERVER
}

CreateIconXhr() {
    for cls in ["MSXML2.XMLHTTP.6.1", "MSXML2.XMLHTTP", "WinHttp.WinHttpRequest.5.1", "Microsoft.XMLHTTP"] {
        try {
            x := ComObject(cls)
            if (IsObject(x))
                return x
        }
    }
    return ""
}

; Starts the request of one stage of a job. Returns false when it could not be started.
GameIconStartRequest(job, stage) {
    global gameIconFetchPx
    switch stage {
        case "meta":
            url := "https://discord.com/api/v10/applications/" job.appId "/rpc"
        case "img":
            url := "https://cdn.discordapp.com/app-icons/" job.appId "/" job.hash ".png?size=" gameIconFetchPx
        default:
            return false
    }
    xhr := CreateIconXhr()
    if (!IsObject(xhr))
        return false
    try {
        xhr.Open("GET", url, true)
        xhr.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        xhr.Send()
    } catch {
        return false
    }
    job.xhr := xhr, job.stage := stage, job.start := A_TickCount
    return true
}

; Nothing could be found for this game: it gets Discord's "?" icon until the next refresh of the list (unless a picture is already shown).
GameIconFail(job, definitive := false) {
    global gameIconState, gameIconBitmaps, gameIconArrived
    if (gameIconBitmaps.Has(job.key)) {
        GameIconForgetState(job.key)
        return
    }
    gameIconState[job.key] := 3
    if (definitive)
        GameIconNoIconSet(job.key, job.hash)         ; Discord really has no picture: remembered in the pack, not asked again on every refresh
    gameIconArrived.Push(job.key)                    ; repaint everything that shows this game: the grey square turns into the "?" icon
}

; Starts a job: the icon's hash is known (list) -> the picture is requested; otherwise the app's record is asked for the hash first.
; An icon that is already cached stays on screen meanwhile and is replaced when the new one has arrived.
GameIconBegin(job) {
    return (job.appId != "" && GameIconStartRequest(job, job.hash != "" ? "img" : "meta"))
}

; Runs while icons are queued / downloading. Up to gameIconMaxJobs (32) downloads run side by side; the work done per tick is
; limited to ~14 ms so the window never stutters. Newest requests (the rows on screen) go first, then the prefetch list in order.
GameIconTick(*) {
    global gameIconQueue, gameIconPrefetch, gameIconJobs, gameIconHashes, gameAppIds, gameIconBitmaps, isExiting, gameIconArrived
    global gameIconBulkList, gameIconRetryAt, isWindowMoving, animationActive
    global gameIconUpdateTried, gameIconState, gameIconMaxJobs
    if (isExiting) {
        SetTimer(GameIconTick, 0)
        return
    }
    ; Rows that are on screen right now (gameIconQueue) are urgent: bigger time slice, fast timer. Everything else (prefetch + the
    ; whole-list preload) is background work: a small slice every 20 ms, and it waits while the window is being dragged.
    urgent := (gameIconQueue.Length > 0)
    if (!urgent && (isWindowMoving || animationActive)) {
        SetTimer(GameIconTick, 40)
        return
    }
    budget := urgent ? 14 : 8
    t0 := A_TickCount
    i := gameIconJobs.Length
    while (i >= 1) {
        job := gameIconJobs[i]
        finished := false
        try {
            if (A_TickCount - job.start > 25000) {
                try job.xhr.abort()
                GameIconFail(job)
                finished := true
            } else if (job.xhr.readyState = 4 && A_TickCount - t0 < budget) {
                finished := GameIconJobDone(job)
            }
        } catch {
            GameIconFail(job)
            finished := true
        }
        if (finished)
            gameIconJobs.RemoveAt(i)
        i -= 1
    }
    maxJobs := gameIconMaxJobs
    while (gameIconJobs.Length < maxJobs && A_TickCount - t0 < budget) {
        if (A_TickCount < gameIconRetryAt)
            break
        title := ""
        if (gameIconQueue.Length > 0)
            title := gameIconQueue.Pop()
        else if (gameIconPrefetch.Length > 0)
            title := gameIconPrefetch.RemoveAt(1)
        else if (gameIconJobs.Length < maxJobs - 6)      ; the whole-list preload never takes the last 6 slots: new on-screen rows start at once
            title := NextBulkIconTitle()
        if (title = "")
            break
        key := StrLower(title)
        hadOld := gameIconBitmaps.Has(key)
        if (!hadOld && TryLoadIconFromDisk(key)) {   ; finished icon kept on disk from an earlier run: shown at once, no download needed for it
            hadOld := true
            gameIconArrived.Push(key)
        }
        if (hadOld && !GameIconNeedsUpdate(key)) {   ; cached and still up to date
            GameIconForgetState(key)
            continue
        }
        if (hadOld)
            gameIconState[key] := 1                  ; (loading the cached icon cleared it)
        gameIconUpdateTried[key] := true             ; asked once per refresh, whatever the answer is
        appId := gameAppIds.Has(key) ? gameAppIds[key] : ""
        job := {title: title, key: key, appId: appId, hash: gameIconHashes.Has(key) ? gameIconHashes[key] : "", stage: "", xhr: "", start: 0}
        if (GameIconBegin(job))
            gameIconJobs.Push(job)
        else
            GameIconFail(job)
    }
    if (gameIconArrived.Length > 0)
        GameIconFlushArrived()
    if (gameIconJobs.Length = 0 && gameIconQueue.Length = 0 && gameIconPrefetch.Length = 0 && !IsObject(gameIconBulkList)) {
        SetTimer(GameIconTick, 0)
    } else {
        SetTimer(GameIconTick, urgent ? 10 : 16)
    }
}

; New / better icons are in: repaint everything that shows them (once per tick, not once per icon).
GameIconFlushArrived() {
    global gameIconArrived, searchIconKey
    keys := gameIconArrived
    gameIconArrived := []
    try {
        if (IsProcessSelectorOpen())
            RepaintArrivedRows(keys)
    }
    forceSearch := false
    for key in keys {
        if (key = searchIconKey)
            forceSearch := true
    }
    try UpdateSearchIcon(forceSearch)                ; (an icon that was replaced by a better picture is redrawn too)
    for key in keys {
        try RiskIconRefresh(key)
    }
}

; Repaints only the visible dropdown rows whose icon just arrived. During the whole-list preload dozens of icons arrive per second,
; almost all of them for rows that are not on screen: repainting the whole list for each of those would make scrolling heavy.
RepaintArrivedRows(keys) {
    global selectorList, selectorDisplayedOptions, selectorRowHeight, selectorListFrozen
    if (!IsWindowValid(selectorList) || selectorDisplayedOptions.Length = 0)
        return
    want := Map()
    for k in keys
        want[k] := true
    top := SendMessage(0x018E, 0, 0, selectorList.Hwnd)            ; LB_GETTOPINDEX
    if (top < 0)
        top := 0
    selectorList.GetPos(,,, &listH)
    rows := listH // Max(1, selectorRowHeight) + 2
    rc := Buffer(16, 0)
    hit := false
    Loop rows {
        idx := top + A_Index - 1
        if (idx >= selectorDisplayedOptions.Length)
            break
        if (!want.Has(StrLower(selectorDisplayedOptions[idx + 1])))
            continue
        if (SendMessage(0x0198, idx, rc.Ptr, selectorList.Hwnd) = -1)   ; LB_GETITEMRECT
            continue
        DllCall("User32\InvalidateRect", "Ptr", selectorList.Hwnd, "Ptr", rc, "Int", false)
        hit := true
    }
    if (hit && !selectorListFrozen)
        DllCall("User32\UpdateWindow", "Ptr", selectorList.Hwnd)
}

; One answered request. Returns true when the job is over (success or failure), false when it went on to its next stage.
GameIconJobDone(job) {
    global gameIconHashes, gameIconArrived
    stage := job.stage
    status := job.xhr.status
    if (status = 429) {                              ; rate limited (many icons at once): try this game again a moment later, not "?"
        GameIconRequeue(job)
        return true
    }
    if (status != 200)
        return GameIconDiscordFailed(job, status = 404)
    if (stage = "meta") {
        hasIcon := false
        if (RegExMatch(job.xhr.responseText, '"icon(?:_hash)?"\s*:\s*"([A-Za-z0-9_]+)"', &m)) {
            hasIcon := true
            job.hash := m[1]
            gameIconHashes[job.key] := m[1]
            if (GameIconStartRequest(job, "img"))
                return false
        }
        return GameIconDiscordFailed(job, !hasIcon)  ; the app has no icon
    }
    arr := job.xhr.responseBody
    size := arr.MaxIndex() + 1
    pData := NumGet(ComObjValue(arr), 8 + A_PtrSize, "Ptr")          ; SAFEARRAY.pvData
    master := GameIconBuildMaster(pData, size)
    if (!master)
        return GameIconDiscordFailed(job)
    GameIconCacheStore(job.key, master)              ; replaces the old picture (it is disposed there)
    gameIconArrived.Push(job.key)
    GameIconSaveMaster(job.key, master, job.hash)    ; goes into icons.pack (collected in memory, written as one segment); replaces the previous icon of the game
    return true
}

; Any problem ends the job: a picture that is already cached simply stays, a game without one gets the "?" icon (see GameIconFail).
GameIconDiscordFailed(job, definitive := false) {
    GameIconFail(job, definitive)
    return true
}

; Turns a picture (PNG / JPEG bytes in memory) into the round master (gameIconMasterPx square, see the comment at the top of this
; section). isMaster = the bytes are an already finished master from the disk cache: it is only copied. Returns the GDI+ bitmap or 0.
GameIconBuildMaster(pData, size, isMaster := false) {
    global gdiplusToken, gameIconMasterPx
    if (!gdiplusToken || size < 16)
        return 0
    stream := DllCall("shlwapi\SHCreateMemStream", "Ptr", pData, "UInt", size, "Ptr")   ; makes its own copy of the bytes
    if (!stream)
        return 0
    M := gameIconMasterPx
    src := 0, tmp := 0, dst := 0, g1 := 0, g2 := 0, brush := 0, ia := 0, path := 0, ok := false
    try {
        if (DllCall("gdiplus\GdipCreateBitmapFromStream", "Ptr", stream, "Ptr*", &src, "Int") != 0 || !src)
            throw Error("decode")
        sw := 0, sh := 0
        DllCall("gdiplus\GdipGetImageWidth", "Ptr", src, "UInt*", &sw, "Int")
        DllCall("gdiplus\GdipGetImageHeight", "Ptr", src, "UInt*", &sh, "Int")
        if (sw < 2 || sh < 2)
            throw Error("size")

        if (isMaster && (sw != M || sh != M))
            throw Error("size")                        ; a saved icon of another size (e.g. the old 32 x 32 files): rejected, so it is fetched again at the right size
        if (isMaster && sw = M && sh = M) {
            ; A finished icon from the disk cache is already the right size, round and anti-aliased: copied 1:1, pixel for pixel
            ; (SourceCopy keeps the alpha exactly), no scaling and no second corner cut = no quality loss and a much faster load.
            if (DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", M, "Int", M, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &dst, "Int") != 0 || !dst)
                throw Error("bitmap")
            DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", dst, "Ptr*", &g2, "Int")
            if (!g2)
                throw Error("graphics")
            DllCall("gdiplus\GdipSetCompositingMode", "Ptr", g2, "Int", 1, "Int")
            DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", g2, "Int", 5, "Int")
            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", g2, "Int", 2, "Int")
            DllCall("gdiplus\GdipDrawImageRectI", "Ptr", g2, "Ptr", src, "Int", 0, "Int", 0, "Int", M, "Int", M, "Int")
            ok := true
        } else {
        ; Exactly like Discord: the picture is scaled so that it fills the whole square (its shorter side = the square; a non-square
        ; picture is centred and the longer side cut), nothing is put behind it, and the square gets rounded corners.
        sc := M / Min(sw, sh)
        dw := sw * sc, dh := sh * sc
        dx0 := (M - dw) / 2, dy0 := (M - dh) / 2

        ; 2) the picture, scaled and centred (nothing behind it)
        if (DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", M, "Int", M, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &tmp, "Int") != 0 || !tmp)
            throw Error("bitmap")
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", tmp, "Ptr*", &g1, "Int")
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", g1, "UInt", 0x00000000, "Int")
        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", g1, "Int", 7, "Int")           ; high quality bicubic (the picture is fetched at gameIconFetchPx, 4x the final size, so shrinking it gives a sharp, clean 32 x 32)
        DllCall("gdiplus\GdipSetCompositingQuality", "Ptr", g1, "Int", 2, "Int")          ; high quality
        DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", g1, "Int", 2, "Int")
        DllCall("gdiplus\GdipCreateImageAttributes", "Ptr*", &ia, "Int")
        if (ia)
            DllCall("gdiplus\GdipSetImageAttributesWrapMode", "Ptr", ia, "Int", 3, "UInt", 0, "Int", 0, "Int")   ; no colour bleeding at the picture's edge
        DllCall("gdiplus\GdipDrawImageRectRect", "Ptr", g1, "Ptr", src
            , "Float", dx0, "Float", dy0, "Float", dw, "Float", dh
            , "Float", 0.0, "Float", 0.0, "Float", sw + 0.0, "Float", sh + 0.0
            , "Int", 2, "Ptr", ia, "Ptr", 0, "Ptr", 0, "Int")

        ; 3) cut the rounded corners with smooth (anti-aliased) edges
        if (DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", M, "Int", M, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &dst, "Int") != 0 || !dst)
            throw Error("bitmap")
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", dst, "Ptr*", &g2, "Int")
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g2, "Int", 4, "Int")
        if (DllCall("gdiplus\GdipCreateTexture", "Ptr", tmp, "Int", 4, "Ptr*", &brush, "Int") != 0 || !brush)   ; 4 = WrapModeClamp
            throw Error("brush")
        path := GdipRoundedSquarePath(0, 0, M)
        if (!path)
            throw Error("path")
        DllCall("gdiplus\GdipFillPath", "Ptr", g2, "Ptr", brush, "Ptr", path, "Int")
        ok := true
        }
    } catch {
        ok := false
    }
    if (path)
        DllCall("gdiplus\GdipDeletePath", "Ptr", path, "Int")
    if (brush)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush, "Int")
    if (g2)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g2, "Int")
    if (g1)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g1, "Int")
    if (ia)
        DllCall("gdiplus\GdipDisposeImageAttributes", "Ptr", ia, "Int")
    if (tmp)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", tmp, "Int")
    if (src)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", src, "Int")        ; the decoder is done with the stream now
    ObjRelease(stream)
    if (!ok) {
        if (dst)
            DllCall("gdiplus\GdipDisposeImage", "Ptr", dst, "Int")
        return 0
    }
    return dst
}

; ---- icon in the search box (in front of the text, when the text is a valid game title) ------------------------------
; The search box text and the dropdown titles are both 12 pt, so the box uses EXACTLY the dropdown's icon size.
SearchIconPx() {
    global searchIconSize
    return searchIconSize                             ; its own size (no longer the dropdown's icon size)
}

SearchIconGap() {
    global searchIconTextGap
    return searchIconTextGap                          ; its own gap (no longer the padding in front of the icon)
}

; Icon size / gap for a text of another size: the same proportion to the text as in the dropdown (28 px icon for 12 pt text).
IconSizeForFont(pointSize) {
    return Max(12, Round(RowIconSize() * pointSize / 12))
}
IconGapForFont(pointSize) {
    global rowIconGap
    return Max(4, Round(rowIconGap * pointSize / 12))
}

SearchLeftInset() {
    global searchTextLeftInset
    return searchTextLeftInset                        ; its own value (no longer 2 % of the box width)
}

PositionSearchIcon() {
    global searchIconCtl, searchIconOff, selectGui, searchIconX
    if (searchIconOff <= 0 || !IsWindowValid(searchIconCtl))
        return
    px := SearchIconPx()
    try {
        selectGui.GetClientPos(, , &cw, &ch)
        MoveCtlIfChanged(searchIconCtl, searchIconX, SearchIconTop(ch, px), px, px)
    }
}

HideSearchIcon() {
    global searchIconCtl, searchIconKey, searchIconReal, searchIconOff
    searchIconKey := "", searchIconReal := false
    if (IsWindowValid(searchIconCtl))
        searchIconCtl.Opt("+Hidden")
    if (searchIconOff != 0) {
        searchIconOff := 0
        SetSearchEditMargins(SearchLeftInset())
    }
}

; Shows the game's icon in front of the text of the search box while the text is exactly a title of the dropdown list (letter case must match),
; and removes it (and the room it takes) otherwise. Same picture as in the dropdown.
UpdateSearchIcon(force := false) {
    global processSelect, searchIconCtl, searchIconHbm, searchIconKey, searchIconReal, searchIconOff
    global isShowingGameSearchHint, gameAppIds, rowIconsEnabled, gdiplusToken, selectGui, isExiting
    if (isExiting || !IsWindowValid(processSelect) || !IsWindowValid(searchIconCtl))
        return
    key := ""
    if (rowIconsEnabled && gdiplusToken && !isShowingGameSearchHint) {
        matched := ResolveTypedGameTitle()           ; exact, case-sensitive match with a title of the dropdown list
        if (matched != "")
            key := StrLower(matched)
    }
    if (key = "") {
        if (searchIconKey != "" || searchIconOff != 0)
            HideSearchIcon()
        return
    }
    master := GetGameIconBitmap(key)
    real := master ? 1 : (GameIconIsMissing(key) ? 2 : 0)             ; 1 = the game's picture, 2 = "?" icon (no picture exists), 0 = still loading
    if (!force && key = searchIconKey && real = searchIconReal && searchIconOff > 0)
        return
    px := SearchIconPx()
    hbm := MakeIconHBitmap(master, px, real = 2)
    if (!hbm)
        return
    inset := SearchLeftInset()
    PositionSearchIconAt(inset, px)
    old := SendMessage(0x0172, 0, hbm, searchIconCtl.Hwnd)           ; STM_SETIMAGE (IMAGE_BITMAP)
    if (old)
        DllCall("Gdi32\DeleteObject", "Ptr", old)
    searchIconHbm := hbm
    searchIconKey := key, searchIconReal := real
    searchIconCtl.Opt("-Hidden")
    newOff := px + SearchIconGap()
    if (newOff != searchIconOff) {
        searchIconOff := newOff
        SetSearchEditMargins(inset)                                   ; the text starts after the icon
    }
    ; The icon sits on top of the edit's left margin. A control that was created later is NOT always above an older one, and the
    ; edit paints that margin black: when the edit is above, the icon is completely covered (seen as a black spot). So the icon is
    ; put on top of everything in the box explicitly, AFTER the margin change (which repaints the edit), and repainted.
    DllCall("User32\SetWindowPos", "Ptr", searchIconCtl.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")   ; HWND_TOP, no move / size / activate
    DllCall("User32\RedrawWindow", "Ptr", searchIconCtl.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0101, "Int")                             ; INVALIDATE | UPDATENOW
}

; Top of the search icon: centred exactly on the VISIBLE box (the rounded-corner region drops the last row, so ch - 1 rows are visible):
; equal gap above and below, and the same centre PositionChildWindows gives the edit's text.
SearchIconTop(ch, px) {
    return Round((ch - 1) / 2 - px / 2)
}

PositionSearchIconAt(inset, px) {
    global searchIconCtl, selectGui, searchIconX
    try {
        selectGui.GetClientPos(, , , &ch)
        MoveCtlIfChanged(searchIconCtl, searchIconX, SearchIconTop(ch, px), px, px)
    }
}

; ---- icon in front of the warning's title -------------------------------------------------------------------------
FreeRiskIcon() {
    global riskIconCtl, riskIconHbm, riskIconKey, riskIconReal
    riskIconCtl := ""
    riskIconKey := "", riskIconReal := false
    if (riskIconHbm) {
        DllCall("Gdi32\DeleteObject", "Ptr", riskIconHbm)
        riskIconHbm := 0
    }
}

; An icon that was still loading when the warning was built is swapped in the moment it arrives.
RiskIconRefresh(key) {
    global riskIconCtl, riskIconHbm, riskIconKey, riskIconReal, riskIconPx
    if (riskIconKey = "" || key != riskIconKey || !IsWindowValid(riskIconCtl))
        return
    master := GetGameIconBitmap(key)
    missing := (!master && GameIconIsMissing(key))
    if (!master && !missing)
        return
    hbm := MakeIconHBitmap(master, riskIconPx, missing)
    if (!hbm)
        return
    old := SendMessage(0x0172, 0, hbm, riskIconCtl.Hwnd)
    if (old)
        DllCall("Gdi32\DeleteObject", "Ptr", old)
    riskIconHbm := hbm
    riskIconReal := master ? 1 : 2
    DllCall("User32\RedrawWindow", "Ptr", riskIconCtl.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0101, "Int")
}

FlushBufferedRow(realHdc, bufDc, bufBmp, bufOldBmp, left, top, w, h) {
    ; The back-buffer stays alive for the next row (see DrawSelectorItem); only the row is copied to the screen.
    DllCall("Gdi32\BitBlt", "Ptr", realHdc, "Int", left, "Int", top, "Int", w, "Int", h, "Ptr", bufDc, "Int", left, "Int", top, "UInt", 0x00CC0020)
}

; Returns true (and tells the user why) when a refresh must not run because a created process is active.
; isRunning is true for the compiled helper process AND for Rich Presence (including while Discord is still connecting).
RefreshBlockedWhileActive() {
    global isRunning, activeProcessName, currentStatusTextOnly, currentStatusColor
    global refreshBlockMsg, refreshBlockPrevText, refreshBlockPrevType
    if (!isRunning)
        return false
    name := (activeProcessName != "") ? activeProcessName : "Process"
    msg := "Refresh unavailable: '" name "' is active. Press Stop first, then refresh."
    ; remember the status that was showing (unless the block message itself is already showing)
    if (currentStatusTextOnly != refreshBlockMsg) {
        refreshBlockPrevText := currentStatusTextOnly
        switch currentStatusColor {
            case "E50914": refreshBlockPrevType := "error"
            case "3A86FF": refreshBlockPrevType := "running"
            case "F2A900": refreshBlockPrevType := "stopped"
            default: refreshBlockPrevType := "ready"
        }
    }
    refreshBlockMsg := msg
    ; FLICKER FIX: the message was rebuilt by SetStatus on EVERY click (text measuring, new marquee strip, scroll position reset,
    ; dot / text controls re-set). Each rebuild made Windows re-print the layered + composited main window, which showed as a flicker
    ; of the refresh button (and a restart of the scrolling line) when it was clicked quickly many times. When the message is
    ; already showing there is nothing to change: only the 4 s restore timer is re-armed.
    if (currentStatusTextOnly == msg) {
        SetTimer(RestoreStatusAfterRefreshBlock, -4000)
        return true
    }
    SetStatus(msg, "ready")
    SetTimer(RestoreStatusAfterRefreshBlock, -4000)   ; re-arming resets the 4 s on repeated clicks
    return true
}

RestoreStatusAfterRefreshBlock() {
    global isRunning, isExiting, currentStatusTextOnly, refreshBlockMsg, refreshBlockPrevText, refreshBlockPrevType
    if (isExiting || !isRunning || currentStatusTextOnly != refreshBlockMsg)
        return                                         ; Stop was pressed or something else already changed the status
    SetStatus(refreshBlockPrevText, refreshBlockPrevType)
    refreshBlockMsg := ""
}

; The refresh button is unavailable (drawn disabled, no hover / press effects, "not allowed" cursor) while a created process is
; active (exe or Rich Presence) OR during the 60 s pause between two refreshes.
RefreshDisabled() {
    global isRunning
    return connLost || isRunning || RefreshCooldownMs() > 0
}

; One-shot timer set when the 60 s pause starts: the button leaves the disabled look exactly when the pause is over.
RefreshCooldownEnded(*) {
    global isExiting, lastHover
    if (isExiting)
        return
    if (RefreshCooldownMs() > 0) {                 ; a newer pause is running: wait for that one
        SetTimer(RefreshCooldownEnded, -(RefreshCooldownMs() + 50))
        return
    }
    lastHover := -1                                ; hover logic re-checks (hover colour if the cursor is on the button)
    RepaintRefreshButtonNoErase()
    UpdateButtonHover()
}

; Milliseconds left of the 60 s pause between two refreshes (0 = a refresh may start).
RefreshCooldownMs() {
    global lastGameRefreshAt
    if (lastGameRefreshAt <= 0)
        return 0
    return Max(0, 60000 - (A_TickCount - lastGameRefreshAt))
}

; True when the computer can really reach the internet (tries three well-known hosts; any one answering is enough).
IsInternetAvailable() {
    for url in ["http://www.msftconnecttest.com/connecttest.txt", "https://discord.com", "https://www.google.com"] {
        if (DllCall("wininet\InternetCheckConnectionW", "Str", url, "UInt", 1, "UInt", 0, "Int"))
            return true
    }
    return false
}

; ======================================================================================================================================
; CONNECTION LOSS HANDLING
;   ConnectionWatchTick  every 1.5 s asks one of three hosts (asynchronously: the window never waits for a dead connection). Two failed
;                        answers in a row (always two DIFFERENT hosts) = the connection is lost; any good answer while lost = restored.
;   HandleConnectionLoss freezes Start / Continue / Refresh, aborts a running list load (the list is NOT loaded), pauses a running process
;                        (exe or Rich Presence: the button goes back to Start) and shows ONE lost message that nothing else may replace
;                        (see ConnStatusBlocked in SetStatus) except a "restored" message.
;   HandleConnectionRestored  unfreezes everything and shows "restored"; when a process was paused it shows the second restored message and
;                        starts the same process again automatically (ResumeAfterReconnect).
; ======================================================================================================================================

; Connection lost (process paused) and the moment the paused process becomes active again (ResumeAfterReconnect, NOT the "restored"
; message): the search box ("textarea") loses the focus and its dropdown closes, so the user is never left typing into a box
; while the app pauses / continues by itself.
RemoveSearchFocusForConnection() {
    global mainGui, processSelect, isGameSearchFocused, isExiting
    if (isExiting || !IsSet(mainGui) || !mainGui || !IsWindowValid(mainGui))
        return
    try {
        if (IsProcessSelectorOpen())
            CloseProcessSelector()
        if (isGameSearchFocused || (IsWindowValid(processSelect) && DllCall("User32\GetFocus", "Ptr") = processSelect.Hwnd)) {
            isGameSearchFocused := false
            DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)   ; focus leaves the search box (its lose-focus handler restores the hint text)
        }
    }
}

; True when SetStatus must refuse this text: the connection is lost and the text is neither the locked lost message nor a restored one.
ConnStatusBlocked(text) {
    global connLost, connMsg, internetMsgBack, internetMsgBackResume
    return connLost && text != connMsg && text != internetMsgBack && text != internetMsgBackResume
}

; Kept for the existing call sites of the game-list load (their load failed AND the internet is gone).
SetInternetProblemStatus(lost) {
    HandleConnectionLoss(lost ? "refresh" : "watch")
}

SetNoInternetStatus() {
    HandleConnectionLoss("watch")
}

SetInternetLostStatus() {
    HandleConnectionLoss("refresh")
}

; kind: "refresh" = the game-list load failed because of the missing connection, "watch" = the watcher noticed it.
; Only the FIRST call of an outage does anything: the message that was chosen then stays until the connection is back.
HandleConnectionLoss(kind := "watch") {
    global connLost, connMsg, connBusy, connResume, connLastStart, connResumeToken
    global isRunning, rpcConnecting, rpcCancel, activeProcessName, lastHover, isExiting
    global gameFetchPending, asyncXhr, suppressFilterStatus, lastGameRefreshAt
    global internetMsgLost, internetMsgGeneral, internetMsgPaused
    if (isExiting || connLost)
        return
    wasActive := isRunning
    refreshInterrupted := (gameFetchPending || kind = "refresh")
    pendingResume := IsObject(connResume)           ; a process that an earlier outage paused is still waiting to be started again
    if (wasActive || pendingResume)
        connMsg := internetMsgPaused
    else if (refreshInterrupted)
        connMsg := internetMsgLost
    else
        connMsg := internetMsgGeneral
    connLost := true                                ; from here on SetStatus accepts only connMsg / the restored messages
    connBusy := true
    connResumeToken += 1                            ; cancels an automatic restart that was still waiting
    try {
        ; 1) a refresh that is still loading: stop it, the list must NOT be loaded
        if (gameFetchPending) {
            try asyncXhr.abort()
            gameFetchPending := false
            asyncXhr := ""
            suppressFilterStatus := false
            SetTimer(CheckDiscordGameLoad, 0)
        }
        if (refreshInterrupted) {
            CancelRefreshArrowAnimation()           ; spin stops, no check mark (the refresh did NOT succeed)
            lastGameRefreshAt := 0                  ; the interrupted refresh does not cost the 60 s pause
        }
        ; 2) a running process (exe or Rich Presence): pause it. Same steps as pressing Stop.
        if (wasActive) {
            rpcConnecting := false, rpcCancel := true
            if (!CancelHelperLaunch())
                StopTargetProcess()
            isRunning := false
            if (IsObject(connLastStart))
                connResume := connLastStart         ; started again by itself when the connection is back
            SetActionLabel("Start")
            SetActionColor("208A4E")
            RepaintActionButtonNoErase()
        }
    } finally {
        connBusy := false
    }
    RemoveSearchFocusForConnection()                ; the search box loses the focus when the connection is lost
    UpdaterConnectionChanged()                      ; a running update check / download is cancelled, the Update button freezes
    SetStatus(connMsg, "error")
    lastHover := -1
    RepaintRefreshButtonNoErase()                   ; Refresh now looks disabled
    RepaintActionButtonNoErase()
    UpdateButtonHover()
}

; The connection is back. Never runs while HandleConnectionLoss is still stopping the process (the next probe asks again).
HandleConnectionRestored() {
    global connLost, connMsg, connBusy, connResume, connResumeToken, connResumeDelayMs, isExiting, lastHover
    global internetMsgBack, internetMsgBackResume
    if (isExiting || !connLost || connBusy)
        return
    connLost := false
    connMsg := ""
    lastHover := -1
    UpdaterConnectionChanged()                      ; the Update button works again
    RepaintRefreshButtonNoErase()                   ; Refresh looks enabled again
    if (IsObject(connResume)) {
        connResumeToken += 1
        SetStatus(internetMsgBackResume, "ready")   ; restored message 2: the system was paused and now continues
        SetTimer(ResumeAfterReconnect.Bind(connResumeToken), -connResumeDelayMs)
    } else {
        SetStatus(internetMsgBack, "ready")         ; restored message 1: all the other lost / interrupted messages
    }
    RepaintActionButtonNoErase()
    UpdateButtonHover()
}

; Starts the paused process again (the "restored + continuing" message has been on screen for a moment).
; Skipped when the connection went away again, the user already started something, or the warning is open.
ResumeAfterReconnect(token) {
    global connResume, connResumeToken, connLost, isRunning, isExiting, riskViewActive, riskViewBusy, toggleRunning, actionLocked
    if (isExiting || token != connResumeToken || !IsObject(connResume))
        return
    if (connLost)
        return                                      ; lost again: connResume is kept for the next restore
    resume := connResume
    if (isRunning || riskViewActive || riskViewBusy || toggleRunning || actionLocked) {
        connResume := ""                            ; the user took over: nothing to resume
        return
    }
    connResume := ""
    RemoveSearchFocusForConnection()                ; the search box loses the focus when the paused process becomes active again (not at the "restored" message)
    if (resume[1] = "rpc")
        RpcBeginConnect(resume[2], resume[3])       ; (the risk warning was accepted before: it is not shown again)
    else
        BeginHelperLaunch(resume[2], resume[3], resume[4])
}

ConnectionWatchTick(*) {
    global connProbe, isExiting
    if (isExiting) {
        SetTimer(ConnectionWatchTick, 0)
        if (IsObject(connProbe))
            try connProbe.abort()
        connProbe := ""
        return
    }
    if (IsObject(connProbe)) {
        res := ConnProbeResult()
        if (res < 0)
            return                                  ; the answer has not arrived yet
        connProbe := ""
        ConnProbeDone(res = 1)
    }
    StartConnProbe()
}

ConnProbeDone(ok) {
    global connFails, connLost
    if (ok) {
        connFails := 0
        if (connLost)
            HandleConnectionRestored()
    } else {
        connFails += 1
        if (connFails >= 2 && !connLost)
            HandleConnectionLoss("watch")
    }
}

StartConnProbe() {
    global connProbe, connProbeStart, connProbeIdx
    static urls := ["http://www.msftconnecttest.com/connecttest.txt", "https://discord.com/api/v10/gateway", "http://clients3.google.com/generate_204"]
    connProbeIdx := Mod(connProbeIdx, urls.Length) + 1      ; the hosts take turns: two failures in a row are two different hosts
    x := ""
    for cls in ["MSXML2.XMLHTTP.6.0", "MSXML2.XMLHTTP", "WinHttp.WinHttpRequest.5.1"] {
        try {
            x := ComObject(cls)
            if IsObject(x)
                break
        }
    }
    if (!IsObject(x))
        return
    try {
        x.Open("GET", urls[connProbeIdx] "?t=" A_TickCount, true)
        x.SetRequestHeader("Cache-Control", "no-cache")
        x.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        x.Send()
        connProbe := x
        connProbeStart := A_TickCount
    } catch {
        connProbe := ""
        ConnProbeDone(false)
    }
}

; 1 = this host answered correctly, 0 = it did not (error / wrong page / more than 4 s), -1 = still waiting.
ConnProbeResult() {
    global connProbe, connProbeStart, connProbeIdx
    try {
        if (connProbe.readyState != 4) {
            if (A_TickCount - connProbeStart > 4000) {
                try connProbe.abort()
                return 0
            }
            return -1
        }
        st := connProbe.status
        if (connProbeIdx = 1)
            return (st = 200 && InStr(connProbe.responseText, "Microsoft Connect Test")) ? 1 : 0
        return (st = 200 || st = 204) ? 1 : 0
    } catch {
        return 0
    }
}

RefreshProcessList(*) {
    global gameFetchPending, lastGameRefreshAt, refreshIsLocked, currentStatusTextOnly
    if (refreshIsLocked || gameFetchPending || connLost)
        return
    if (RefreshBlockedWhileActive())
        return
    if (gameFetchPending) {
        SetStatus("Discord game titles are still loading. Please wait...", "ready")
        return
    }

    if (lastGameRefreshAt > 0) {
        remainingMs := 60000 - (A_TickCount - lastGameRefreshAt)
        if (remainingMs > 0) {
            remainingSeconds := Ceil(remainingMs / 1000)
            cooldownMsg := Format("Refresh available in {} seconds.", remainingSeconds)
            if (currentStatusTextOnly != cooldownMsg)      ; same message already showing (rapid clicks): do not rebuild it = no flicker
                SetStatus(cooldownMsg, "ready")
            return
        }
    }

    ; (No "no internet" pre-check any more: the refresh always starts. If the connection is missing or drops while the list is
    ;  loading, the load fails and the status line shows "Internet connection was interrupted" - see SetInternetLostStatus.)

    ; Lock the button (its locked colour equals the pressed colour) BEFORE the load starts, so no hover
    ; fade or repaint can run in between and show a different colour.
    StartRefreshArrowAnimation()
    if (StartDiscordGameLoad()) {
        lastGameRefreshAt := A_TickCount
        SetTimer(RefreshCooldownEnded, -(60000 + 50))   ; the button turns enabled again when the 60 s pause ends
        SetStatus("Connecting & reading Discord game titles carefully...", "ready")
    } else {
        CancelRefreshArrowAnimation()
    }
}

OnGameSearchFocus(*) {
    global processSelect, isShowingGameSearchHint, isGameSearchFocused, processOptions, gameFetchPending
    isGameSearchFocused := true
    if (isShowingGameSearchHint) {
        isFilteringGameList := true
        processSelect.Value := ""
        isFilteringGameList := false
        isShowingGameSearchHint := false
    }
    UpdateSearchIcon()
    if (processOptions.Length = 0 && gameFetchPending) {
        ; keep the "Connecting & reading..." status that is already shown (no rebuild while the button spins)
    } else if (processOptions.Length = 0)
        SetStatus("No game list loaded. Press refresh to fetch Discord titles.", "ready")
}

OnGameSearchLoseFocus(*) {
    global processSelect, selectedProcessTitle, isShowingGameSearchHint, isFilteringGameList, gameSearchHint, isGameSearchFocused, gameFetchPending, appIsInactive
    ; Pressing (left or right) on the dropdown, its titles or its scroll buttons keeps the focus in the search box.
    if ((GetKeyState("LButton", "P") || GetKeyState("RButton", "P")) && (IsMouseOverScrollArrowButton() || IsMouseOverDropdownArea())) {
        SetTimer(EnsureGameSearchFocus, -1)
        return
    }
    isGameSearchFocused := false
    ; The whole app lost focus (Alt+Tab etc.): the box keeps its focus inside the window,
    ; so do not swap the placeholder text in.
    if (appIsInactive || !IsForegroundOurProcess())
        return
    if (processSelect.Value = "" && selectedProcessTitle = "") {
        isFilteringGameList := true
        processSelect.Value := gameSearchHint
        isFilteringGameList := false
        isShowingGameSearchHint := true
    }
    UpdateSearchIcon()
}

OnGameSearchChange(*) {
    global isFilteringGameList, isSelectingGame, selectedProcessTitle, selectorFrameGui, processOptions, gameFetchPending, processSelect, isShowingGameSearchHint
    UpdateSearchIcon()                 ; icon appears when the text becomes a valid game title, and goes when it stops being one
    if (isFilteringGameList)
        return
    if (!isSelectingGame)
        selectedProcessTitle := ""
    if (processOptions.Length = 0) {
        if (!gameFetchPending)
            SetStatus("No game list loaded. Press refresh to fetch Discord titles.", "ready")
        return
    }

    query := isShowingGameSearchHint ? "" : Trim(processSelect.Value)
    if (query != "") {
        matchFound := false
        for title in processOptions {
            if (InStr(title, query, false)) {
                matchFound := true
                break
            }
        }
        if (!matchFound) {
            CloseProcessSelector()
            SetStatus("No game titles match: " . query . ".", "ready")
            return
        }
    }

    if (query != "" && !IsWindowValid(selectorFrameGui)) {
        OpenProcessSelector()
    } else if (IsWindowValid(selectorFrameGui)) {
        selectorWasVisible := IsProcessSelectorOpen()
        FilterDiscordGameList()
        if (!selectorWasVisible && IsWindowValid(selectorFrameGui))
            ResizeProcessSelector()
    }
    EnsureGameSearchFocus()
}

DropdownPaintLock(lock) {
    global selectorFrameGui
    try {
        if (!IsWindowValid(selectorFrameGui))
            return
        hwnd := selectorFrameGui.Hwnd
        DllCall("User32\SendMessage", "Ptr", hwnd, "UInt", 0x000B, "Ptr", lock ? 0 : 1, "Ptr", 0, "Ptr")
        if (!lock)
            DllCall("User32\RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0181)
    }
}

DropdownZOrderGuard(*) {
    global selectorFrameGui, isExiting
    if (isExiting || !IsSet(selectorFrameGui)) {
        SetTimer(DropdownZOrderGuard, 0)
        return
    }
    try {
        popupHwnd := selectorFrameGui.Hwnd
        if (!DllCall("User32\IsWindow", "Ptr", popupHwnd, "Int"))
            return
        if (!DllCall("User32\IsWindowVisible", "Ptr", popupHwnd, "Int"))
            return
    } catch {
        return
    }
}

CloseProcessSelector(*) {
    global selectorFrameGui, selectorPopup, selectorList, selectorHoveredIndex, selectorPreviousHoveredIndex, selectorPressedIndex, selectorPressPhase, selectorMouseLeaveTracking, isExiting
    global selectorClickIndex, selectorCommitIndex, isDraggingThumb, selectorScrollThumb, scrollContinuousAction, dropdownMarqueeIndex, isKeyboardNavigating
    if (IsWindowValid(selectorScrollThumb)
        && DllCall("User32\GetCapture", "Ptr") = selectorScrollThumb.Hwnd)
        DllCall("User32\ReleaseCapture", "Int")
    selectorClickIndex := -1
    selectorCommitIndex := -1
    isDraggingThumb := false
    scrollContinuousAction := ""
    dropdownMarqueeIndex := -1
    FreeDropdownStrip()
    isKeyboardNavigating := false
    SetTimer(ProcessContinuousScroll, 0)
    SetTimer(UpdateSelectorHover, 0)
    SetTimer(UpdateSelectorPressAnimation, 0)
    SetTimer(UpdateScrollControllerHover, 0)
    SetTimer(DropdownZOrderGuard, 0)
    selectorHoveredIndex := -1
    selectorPreviousHoveredIndex := -1
    selectorMouseLeaveTracking := false
    selectorPressedIndex := -1
    selectorPressPhase := "idle"
    if (IsWindowValid(selectorFrameGui))
        selectorFrameGui.Hide()
}

CommitDropdownSelection(*) {
    global selectorPopup, selectorList, selectorCommitIndex
    clickedIndex := selectorCommitIndex
    selectorCommitIndex := -1
    if (clickedIndex < 0 || !IsWindowValid(selectorPopup) || !IsWindowValid(selectorList))
        return
    SendMessage(0x0186, clickedIndex, 0, selectorList.Hwnd)
    ChooseProcessFromList(selectorList)
}

StartDiscordGameLoad(*) {
    global gameFetchPending, gameFetchStartedAt, asyncXhr
    if (gameFetchPending)
        return false

    asyncXhr := ""
    comClasses := ["MSXML2.XMLHTTP.6.1", "MSXML2.XMLHTTP", "WinHttp.WinHttpRequest.5.1", "Microsoft.XMLHTTP"]
    
    for cls in comClasses {
        try {
            asyncXhr := ComObject(cls)
            if IsObject(asyncXhr)
                break
        }
    }

    if (!IsObject(asyncXhr)) {
        SetStatus("System Error: No HTTP COM components registered on Windows.", "error")
        return false
    }

    try {
        asyncXhr.Open("GET", "https://discord.com/api/v10/applications/detectable", true)
        asyncXhr.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        asyncXhr.Send()

        gameFetchPending := true
        gameFetchStartedAt := A_TickCount
        SetStatus("Connecting & reading Discord game titles carefully...", "ready")
        SetTimer(CheckDiscordGameLoad, 50)      ; poll often so the result is picked up right when it arrives
        return true
    } catch Error as err {
        asyncXhr := ""
        if (!IsInternetAvailable())
            SetInternetLostStatus()
        else
            SetStatus("System Error: Discord game list failed. " err.Message, "error")
        return false
    }
}

CheckDiscordGameLoad(*) {
    global processOptions, selectorFrameGui, gameFetchPending, gameFetchStartedAt, asyncXhr, suppressFilterStatus
    if (!gameFetchPending || !IsObject(asyncXhr))
        return

    try {
        readyState := asyncXhr.readyState
        if (readyState != 4) {
            if (A_TickCount - gameFetchStartedAt > 35000) {
                try asyncXhr.abort()
                FinishDiscordGameLoad()
                if (!IsInternetAvailable())
                    SetInternetLostStatus()
                else
                    SetStatus("System Error: Loading Discord game titles timed out.", "error")
            }
            return
        }

        elapsed := A_TickCount - gameFetchStartedAt
        if (elapsed < 1200)
            return

        status := asyncXhr.status
        if (status != 200) {
            FinishDiscordGameLoad()
            if (!IsInternetAvailable())
                SetInternetLostStatus()
            else
                SetStatus("System Error: Discord returned HTTP " status, "error")
            return
        }

        responseText := asyncXhr.responseText

        if (responseText = "") {
            FinishDiscordGameLoad()
            SetStatus("System Error: The response was empty.", "error")
            return
        }

        if (SubStr(responseText, 1, 1) = Chr(0xFEFF))
            responseText := SubStr(responseText, 2)
        
        fetchedTitles := ParseDiscordGameTitles(responseText)
        
        rawString := ""
        for title in fetchedTitles {
            title := Trim(title)
            if (title != "")
                rawString .= title . "`n"
        }
        rawString := RTrim(rawString, "`n")
        sortedString := Sort(rawString, "C0")
        processOptions := StrSplit(sortedString, "`n")
        FinishDiscordGameLoad()          ; stop the spin / draw the check mark FIRST; nothing heavy runs before this
        if (processOptions.Length = 0) {
            SetStatus("System Error: The response did not contain game titles.", "error")
            return
        }

        ; The button has just finished (spin stopped, check mark drawn, cursor back to the hand). Show the final status
        ; and return to the message loop so Windows can present all of that; the dropdown is opened a moment later,
        ; instead of making the button's "finished" state wait for the dropdown to be built.
        SetStatus(Format("Loaded and sorted {} Discord game titles.", processOptions.Length), "ready")
        GameIconIndexEnsure()                      ; (already read in the background at start-up: no wait)
        PrefetchGameIcons(processOptions, 80)      ; the first titles' icons start loading (or come from disk) the moment the list is there
        StartBulkIconPreload(processOptions)       ; ...and then ALL the other icons, quietly in the background
        UpdateSearchIcon()                         ; text that is already a valid title gets its icon now
        SetTimer(OpenDropdownAfterLoad, -40)
    } catch Error as err {
        suppressFilterStatus := false
        FinishDiscordGameLoad()
        if (!IsInternetAvailable())
            SetInternetLostStatus()
        else
            SetStatus("System Error: Discord game list failed. " err.Message, "error")
    }
}

; Creating the dropdown (popup window, list box, scrollbar controls, fonts) the first time costs noticeable time.
; Doing it while the download is still running means the real open, after loading, only fills and shows it.
; OpenProcessSelector refuses to run without a loaded list, so it is given a one-item placeholder list for the
; duration of this call (Critical keeps every timer from seeing that temporary state) and stops before filling.
PrewarmDropdown(*) {
    global selectorFrameGui, processOptions, gameFetchPending, prewarmBuildActive, isExiting, isWindowVisible
    global mainGui, processSelect, isShowingGameSearchHint, refreshIsLocked, animationActive
    if (isExiting || IsWindowValid(selectorFrameGui))
        return
    ; Runs while the app is idle (shortly after start-up), NEVER during a refresh: building the window is the one
    ; step that cannot be sliced, so it must not happen while the button is spinning. Try again later otherwise.
    if (!isWindowVisible || animationActive || refreshIsLocked || gameFetchPending || !IsWindowValid(mainGui) || !IsWindowValid(processSelect)
        || DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int") || IsContextMenuOpen()) {
        SetTimer(PrewarmDropdown, -700)
        return
    }
    if (!isShowingGameSearchHint && Trim(processSelect.Value) != "")     ; something typed: that real open will build it
        return
    Critical("On")
    savedOptions := processOptions, savedPending := gameFetchPending
    processOptions := ["x"], gameFetchPending := false, prewarmBuildActive := true
    try
        OpenProcessSelector()
    finally {
        processOptions := savedOptions, gameFetchPending := savedPending, prewarmBuildActive := false
        Critical("Off")
    }
}

; Runs shortly after the list finished loading: opens / refreshes the dropdown if the user is waiting on it.
OpenDropdownAfterLoad(*) {
    global processOptions, gameFetchPending, isExiting, suppressFilterStatus, isGameSearchFocused, processSelect
    if (isExiting || gameFetchPending || processOptions.Length = 0)
        return
    ; Only now (the button has long finished) is the empty-search list prepared, and only when someone is waiting for it.
    if (IsProcessSelectorOpen() || isGameSearchFocused || DllCall("User32\GetFocus", "Ptr") = processSelect.Hwnd)
        BuildEmptyQueryTitles()
    suppressFilterStatus := true
    try {
        if (IsProcessSelectorOpen())
            FilterDiscordGameList()
        loadedMessage := ""
        ; Something incomplete was typed in the search box while the list was loading: open the dropdown for it.
        pendingQuery := ""
        pendingState := 0
        try pendingState := OpenDropdownForPendingSearch(&pendingQuery)
        if (pendingState = 1)
            loadedMessage := Format("Loaded {} Discord game titles. {} match: {}.", processOptions.Length, selectorDisplayedOptions.Length, pendingQuery)
        else if (pendingState = 2)
            loadedMessage := Format("Loaded {} Discord game titles. No game titles match: {}.", processOptions.Length, pendingQuery)
        ; Search box focused/selected but empty (or showing the placeholder): show the full list.
        else if (OpenDropdownIfSearchFocused())
            loadedMessage := Format("Loaded and sorted {} Discord game titles. Pick one from the list.", processOptions.Length)
    } finally {
        suppressFilterStatus := false
    }
    if (loadedMessage != "")
        SetStatus(loadedMessage, "ready")
}

; Builds (once per loaded list) the titles shown when the search box is empty: well-known numeric titles first,
; then every title that starts with a letter. FilterDiscordGameList reuses it, so opening the empty list is instant.
BuildEmptyQueryTitles() {
    global processOptions, emptyQueryTitles, emptyQuerySource
    numeric := "", alpha := []
    for title in processOptions {
        firstChar := SubStr(title, 1, 1)
        if (RegExMatch(firstChar, "[0-9]")) {
            if (IsWellKnownNumberTitle(title))
                numeric .= title "`n"
        } else if (RegExMatch(firstChar, "i)[A-Za-z]"))
            alpha.Push(title)
    }
    combined := []
    numeric := RTrim(numeric, "`n")
    if (numeric != "")
        for title in StrSplit(Sort(numeric, "C0"), "`n")
            combined.Push(title)
    for title in alpha
        combined.Push(title)
    emptyQueryTitles := combined
    emptyQuerySource := processOptions
}

; Called when the game list has just finished loading. When the search box holds an unfinished entry (text that is not
; yet an exact game title), the dropdown is opened filtered for it. Returns 0 = nothing to do, 1 = dropdown opened,
; 2 = the text matches no title.
OpenDropdownForPendingSearch(&query) {
    global processSelect, processOptions, isShowingGameSearchHint, selectedProcessTitle, isExiting, isWindowVisible, mainGui
    query := ""
    if (isExiting || !isWindowVisible || !IsWindowValid(processSelect) || !IsWindowValid(mainGui))
        return 0
    if (DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int") || processOptions.Length = 0)
        return 0
    if (isShowingGameSearchHint || Trim(selectedProcessTitle) != "")
        return 0
    query := Trim(processSelect.Value)
    if (query = "" || ResolveTypedGameTitle() != "")        ; empty, or already a complete title: nothing to suggest
        return 0
    matchFound := false
    for title in processOptions {
        if (InStr(title, query, false)) {
            matchFound := true
            break
        }
    }
    if (!matchFound)
        return 2
    if (!IsProcessSelectorOpen())
        OpenProcessSelector()
    return IsProcessSelectorOpen() ? 1 : 0
}

; Called when the game list has just finished loading. If the search box has the keyboard focus (focused or its text
; selected) and no game is chosen yet, open the dropdown. Returns true when it opened.
OpenDropdownIfSearchFocused() {
    global processSelect, processOptions, selectedProcessTitle, isExiting, isWindowVisible, mainGui, isGameSearchFocused
    if (isExiting || !isWindowVisible || !IsWindowValid(processSelect) || !IsWindowValid(mainGui) || processOptions.Length = 0)
        return false
    if (DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int") || IsContextMenuOpen() || IsProcessSelectorOpen())
        return false
    hasFocus := DllCall("User32\GetFocus", "Ptr") = processSelect.Hwnd
    if (!(isGameSearchFocused || hasFocus) || !IsForegroundOurProcess())
        return false
    if (Trim(selectedProcessTitle) != "" || ResolveTypedGameTitle() != "")   ; a game is already chosen/typed in full
        return false
    OpenProcessSelector()
    return IsProcessSelectorOpen()
}

FinishDiscordGameLoad() {
    global gameFetchPending, asyncXhr
    StopRefreshArrowAnimation()
    gameFetchPending := false
    asyncXhr := ""
    SetTimer(CheckDiscordGameLoad, 0)
}

ParseDiscordGameTitles(json) {
    global gameExecutables, gameAppIds, gameIconHashes, gameIconState
    gameExecutables := Map()
    gameAppIds := Map()
    gameIconHashes := Map()
    failedIcons := []
    for k, v in gameIconState
        if (v = 3)
            failedIcons.Push(k)
    for k in failedIcons                      ; a refresh gives icons that failed earlier another chance
        gameIconState.Delete(k)
    titles := []
    seen := Map()
    position := 1
    segmentStart := 1
    pattern := '"id"\s*:\s*"((?:\\.|[^"\\])*)"\s*,\s*"name"\s*:\s*"((?:\\.|[^"\\])*)"'
    while (position <= StrLen(json)) {
        matchPosition := RegExMatch(json, pattern, &match, position)
        if (!matchPosition)
            break

        ; In Discord's list the "executables" array of an app sits right BEFORE its "id"/"name" pair,
        ; so the text between the previous app's name and this one holds this app's executables.
        segment := SubStr(json, segmentStart, matchPosition - segmentStart)

        encodedTitle := '"' match[2] '"'
        titlePosition := 1
        title := Trim(ReadJsonString(encodedTitle, &titlePosition))
        key := StrLower(title)
        if (title != "" && !seen.Has(key)) {
            seen[key] := true
            titles.Push(title)
            if (RegExMatch(match[1], "^\d+$"))
                gameAppIds[key] := match[1]
            ; Discord lists an app's keys alphabetically, so its "icon" hash sits in the text right BEFORE its "id" (the last one wins).
            if (InStr(segment, '"icon') && RegExMatch(segment, 's)^.*"icon(?:_hash)?"\s*:\s*"([A-Za-z0-9_]+)"', &iconMatch))
                gameIconHashes[key] := iconMatch[1]
            exePath := PickDetectableExecutable(segment, title)
            if (exePath != "")
                gameExecutables[key] := exePath
        }
        position := matchPosition + StrLen(match[0])
        segmentStart := position
    }
    GameIconRefreshCycle()                   ; the icon check starts over: every cached icon is compared with this fresh list (Discord hash changes = new icon)
    return titles
}

; Picks the MAIN Windows executable Discord detects for one app, from the text that holds its "executables" array.
; When an app lists several win32 .exe files, every candidate is scored and the best one wins, so the result is the
; real game executable and not a random one (launcher, crash reporter, updater, anti-cheat, editor, dedicated server...).
; Returns a relative, filesystem-safe path (sub folders kept, because Discord matches the END of the running process
; path), or "" when the app has no win32 .exe. Launchers are only used when there is nothing better.
PickDetectableExecutable(segment, title := "") {
    if (!RegExMatch(segment, '"executables"\s*:\s*\[([^\]]*)\]', &arr))
        return ""
    body := arr[1]
    bestGame := "", bestGameScore := -999999
    bestLauncher := "", bestLauncherScore := -999999
    pos := 1, index := 0
    while (p := RegExMatch(body, '\{([^{}]*)\}', &obj, pos)) {
        pos := p + StrLen(obj[0])
        entry := obj[1]
        if (!RegExMatch(entry, '"os"\s*:\s*"win32"'))
            continue
        if (!RegExMatch(entry, '"name"\s*:\s*"((?:\\.|[^"\\])*)"', &nm))
            continue
        namePos := 1
        rawName := Trim(ReadJsonString('"' nm[1] '"', &namePos))
        rel := SanitizeExecutablePath(rawName)
        if (rel = "")
            continue
        index += 1
        isLauncher := RegExMatch(entry, '"is_launcher"\s*:\s*true') ? true : false
        isExact := (SubStr(rawName, 1, 1) = ">")
        score := ScoreExecutableCandidate(rel, title, isExact)
        score -= index * 0.01          ; tie-break: Discord usually lists the primary executable first
        if (isLauncher) {
            if (score > bestLauncherScore) {
                bestLauncherScore := score
                bestLauncher := rel
            }
        } else if (score > bestGameScore) {
            bestGameScore := score
            bestGame := rel
        }
    }
    return bestGame != "" ? bestGame : bestLauncher
}

; Higher score = more likely to be the main executable of the game with this title.
ScoreExecutableCandidate(rel, title, isExact := false) {
    SplitPath(rel, &fileName, , , &baseName)
    exeKey := NormalizeForExeMatch(baseName)
    titleKey := NormalizeForExeMatch(title)
    lowerBase := StrLower(baseName)
    score := 0

    ; 1) how well the file name matches the game title (strongest signal)
    if (titleKey != "" && exeKey != "") {
        if (exeKey = titleKey) {
            score += 120
        } else if (StrLen(exeKey) >= 4 && InStr(titleKey, exeKey)) {
            score += 90
        } else if (StrLen(titleKey) >= 4 && InStr(exeKey, titleKey)) {
            score += 80
        } else {
            hits := 0
            for word in StrSplit(StrLower(title), [" ", ":", "-", "_", "'", ".", ",", "&", "!"]) {
                word := NormalizeForExeMatch(word)
                if (StrLen(word) < 3 || RegExMatch(word, "^(the|and|for|edition|remastered|game|online|of)$"))
                    continue
                if (InStr(exeKey, word))
                    hits += 1
            }
            score += Min(hits * 25, 75)
        }
    }

    ; 2) shipping / 64-bit builds are the real game binaries
    if (RegExMatch(lowerBase, "-win64-shipping$"))
        score += 45
    else if (RegExMatch(lowerBase, "-win(32|gdk|64)?-shipping$|shipping$"))
        score += 20
    if (RegExMatch(lowerBase, "(64|x64|_64|win64)$"))
        score += 15
    else if (RegExMatch(lowerBase, "(x86|_32|win32|32)$"))
        score -= 15

    ; 3) helper / non-game executables (skipped when the word is part of the game's own title)
    junkWords := ["unins", "setup", "install", "crash", "report", "helper", "updat", "patch", "redist", "bootstrap"
        , "anticheat", "battleye", "webhelper", "subprocess", "diagnos", "benchmark", "editor", "dedicated", "server"
        , "sentry", "notification", "launcher", "config", "settings", "vcredist", "dxsetup", "cleanup", "migrat"]
    for junk in junkWords {
        if (InStr(exeKey, junk) && !InStr(titleKey, junk)) {
            score -= 150
            break
        }
    }

    ; 4) small bonuses: Discord's exact-match marker, shallow paths
    if (isExact)
        score += 5
    depth := StrSplit(rel, "\").Length
    if (depth <= 2)
        score += 5
    return score
}

NormalizeForExeMatch(text) {
    return RegExReplace(StrLower(text), "[^\p{L}\p{N}]", "")
}

SanitizeExecutablePath(name) {
    name := Trim(name)
    if (SubStr(name, 1, 1) = ">")          ; Discord marker meaning "exact match"; not part of the real path
        name := SubStr(name, 2)
    name := StrReplace(name, "/", "\")
    parts := []
    for part in StrSplit(name, "\") {
        part := Trim(RegExReplace(part, '[<>:"|?*]', "_"))
        if (part = "" || part = "." || part = "..")
            continue
        parts.Push(part)
    }
    if (parts.Length = 0 || !RegExMatch(parts[parts.Length], "i)\.exe$"))
        return ""
    result := ""
    for part in parts
        result .= (result = "" ? "" : "\") part
    return result
}

ReadJsonString(json, &position) {
    if (SubStr(json, position, 1) != '"')
        return ""
    position += 1
    result := ""
    jsonLength := StrLen(json)
    while (position <= jsonLength) {
        character := SubStr(json, position, 1)
        position += 1
        if (character = '"')
            return result
        if (character != "\") {
            result .= character
            continue
        }
        escaped := SubStr(json, position, 1)
        position += 1
        switch escaped {
            case '"': result .= '"'
            case "\": result .= "\"
            case "/": result .= "/"
            case "b": result .= Chr(8)
            case "f": result .= Chr(12)
            case "n": result .= "`n"
            case "r": result .= "`r"
            case "t": result .= "`t"
            case "u":
                hexValue := StrLen(json) >= position + 3 ? SubStr(json, position, 4) : "0000"
                position += Min(4, StrLen(json) - position + 1)
                codePoint := Integer("0x" hexValue)
                if (codePoint >= 0xD800 && codePoint <= 0xDBFF && SubStr(json, position, 2) = "\u") {
                    lowValue := Integer("0x" SubStr(json, position + 2, 4))
                    if (lowValue >= 0xDC00 && lowValue <= 0xDFFF) {
                        position += 6
                        codePoint := 0x10000 + ((codePoint - 0xD800) << 10) + (lowValue - 0xDC00)
                    }
                }
                result .= Chr(codePoint)
        }
    }
    return result
}

SkipJsonWhitespace(json, &position) {
    while (position <= StrLen(json)) {
        character := SubStr(json, position, 1)
        if (character != " " && character != "`t" && character != "`r" && character != "`n")
            return
        position += 1
    }
}

IsWellKnownNumberTitle(title) {
    wellKnownNumbers := Map(
        "007 first light", true,
        "7 days to die", true,
        "7 billion humans", true,
        "80 days", true,
        "11-11 memories retold", true,
        "12 is better than 6", true,
        "12 labours of hercules", true,
        "20 minutes till dawn", true,
        "20xx", true,
        "30xx", true,
        "33 immortals", true,
        "60 seconds!", true,
        "60 parsecs!", true,
        "428: shibuya scramble", true,
        "911 operator", true,
        "1000xresist", true,
        "100% orange juice", true,
        "1v1.lol", true
    )
    return wellKnownNumbers.Has(StrLower(title))
}

FilterDiscordGameList(*) {
    global processOptions, processSelect, selectorList, selectorDisplayedOptions, selectorFrameGui, isFilteringGameList, isShowingGameSearchHint, gameFetchPending
    global selectorClickIndex
    if (!IsWindowValid(processSelect) || !IsWindowValid(selectorList))
        return
    global emptyQueryTitles, emptyQuerySource
    selectorClickIndex := -1
    query := isShowingGameSearchHint ? "" : Trim(processSelect.Value)

    matchFound := false
    if (query != "") {
        for title in processOptions {
            if (InStr(title, query, false)) {
                matchFound := true
                break
            }
        }
    }

    if (query != "" && !matchFound) {
        CloseProcessSelector()
        SetStatus("No game titles match: " . query . ".", "ready")
        return
    }

    isFilteringGameList := true
    SendMessage(0x000B, 0, 0, selectorList.Hwnd)
    try {
        SendMessage(0x184, 0, 0, selectorList.Hwnd)
        selectorDisplayedOptions := []
        shownCount := 0
        if (query = "" && IsObject(emptyQueryTitles) && IsObject(emptyQuerySource) && ObjPtr(emptyQuerySource) = ObjPtr(processOptions)) {
            combinedTitles := emptyQueryTitles          ; empty search: reuse the list built the first time
        } else {

        matchingItems := []
        for title in processOptions {
            includeInDropdown := false
            if (query != "") {
                if (InStr(title, query, false))
                    includeInDropdown := true
            } else {
                firstChar := SubStr(title, 1, 1)
                if (RegExMatch(firstChar, "[0-9]")) {
                    if (IsWellKnownNumberTitle(title))
                        includeInDropdown := true
                } else if (RegExMatch(firstChar, "i)[A-Za-z]")) {
                    includeInDropdown := true
                }
            }

            if (includeInDropdown) {
                matchingItems.Push(title)
            }
        }

        numericTitles := []
        alphaTitles := []
        for title in matchingItems {
            firstChar := SubStr(title, 1, 1)
            if (RegExMatch(firstChar, "[0-9]"))
                numericTitles.Push(title)
            else
                alphaTitles.Push(title)
        }

        rawNumericString := ""
        for title in numericTitles {
            rawNumericString := rawNumericString . title . "`n"
        }
        rawNumericString := RTrim(rawNumericString, "`n")
        if (rawNumericString != "") {
            sortedNumericString := Sort(rawNumericString, "C0")
            numericTitles := StrSplit(sortedNumericString, "`n")
        }

        combinedTitles := []
        for title in numericTitles
            combinedTitles.Push(title)
        for title in alphaTitles
            combinedTitles.Push(title)
        if (query = "") {
            emptyQueryTitles := combinedTitles
            emptyQuerySource := processOptions
        }
        }

        ; The list box is virtual (LBS_NODATA): rows are drawn from selectorDisplayedOptions by index, so there is no
        ; need to add thousands of strings one by one. One LB_SETCOUNT makes any number of titles appear instantly.
        selectorDisplayedOptions := combinedTitles
        PrefetchGameIcons(combinedTitles, 15)      ; the rows that are about to be seen
        shownCount := combinedTitles.Length
        SendMessage(0x01A7, shownCount, 0, selectorList.Hwnd)   ; LB_SETCOUNT
    } finally {
        isFilteringGameList := false
        SendMessage(0x000B, 1, 0, selectorList.Hwnd)
        selectorList.Redraw()
        if (selectorDisplayedOptions.Length > 3)
            UpdateScrollThumbPosition()
        UpdateRowSeparators()
    }

    if (processOptions.Length = 0 && gameFetchPending) {
        SetStatus("Discord game titles are loading. Please wait...", "ready")
    } else if (shownCount = 0) {
        CloseProcessSelector()
        if (query != "")
            SetStatus("No game titles match: " . query . ".", "ready")
        else
            SetStatus("No Discord game titles are available. Press refresh to try again.", "ready")
        return
    } else if (suppressFilterStatus) {
        ; the caller sets the final status message (avoids rebuilding the status line several times in a row)
    } else if (query != "")
        SetStatus(shownCount . " game titles match: " . query . ".", "ready")
    else
        SetStatus(Format("Showing {} filtered Discord game titles in dropdown.", shownCount), "ready")

    if (IsWindowValid(selectorFrameGui)
        && DllCall("User32\IsWindowVisible", "Ptr", selectorFrameGui.Hwnd, "Int"))
        ResizeProcessSelector()
    EnsureGameSearchFocus()
}

ChooseProcessFromList(ctrl, *) {
    global mainGui, processSelect, selectGui, selectorDisplayedOptions, selectedProcessTitle, isSelectingGame, isFilteringGameList, isShowingGameSearchHint, selectorFrameGui
    if (isFilteringGameList)
        return
    selectedIndex := SendMessage(0x0188, 0, 0, ctrl.Hwnd)
    if (selectedIndex < 0 || selectedIndex >= selectorDisplayedOptions.Length)
    	return
    selectedTitle := selectorDisplayedOptions[selectedIndex + 1]
    if (selectedTitle = "")
        return
    selectedProcessTitle := selectedTitle
    isShowingGameSearchHint := false
    isFilteringGameList := true
    
    processSelect.Value := selectedTitle
    processSelect.SetFont("s12 cFFFFFF", "Segoe UI")
    
    WinGetPos(,, &selectW,, selectGui.Hwnd)
    selectionWidth := selectW - 2
    leftTextInset := searchTextLeftInset          ; its own value (no longer 2 % of the box width)
    SetSearchEditMargins(leftTextInset)

    UpdateSearchIcon(true)
    titleLen := StrLen(processSelect.Value)
    SendMessage(0x00B1, titleLen, titleLen, processSelect.Hwnd)
    
    isFilteringGameList := false
    CloseProcessSelector()
    if (IsWindowValid(selectorFrameGui))
        selectorFrameGui.Hide()
    isSelectingGame := true
    DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
    isSelectingGame := false
    SetStatus("Selected game: " selectedTitle ".", "ready")
}

; Valid title + Start: close the dropdown and take the focus off the search box.
DismissSearchAfterValidStart() {
    global mainGui, isGameSearchFocused
    if (IsProcessSelectorOpen())
        CloseProcessSelector()
    if (isGameSearchFocused) {
        isGameSearchFocused := false
        if (IsWindowValid(mainGui))
            DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
    }
}

; ---------------------------------------------------------------------------------------------
; Rich Presence risk warning. There is no pop-up: the main window itself switches to the warning (search box,
; Start button and status line are hidden, the title bar / name / tagline stay) and switches back after a button
; is pressed. Same fonts, colours, rounded buttons and hover / press colours as the Start / Stop button (at 75% of the size).
; ---------------------------------------------------------------------------------------------
MeasureWrappedTextHeight(text, width, pointSize, weight := 400, face := "Segoe UI") {
    hdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
    if (!hdc)
        return 22
    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(pointSize * DllCall("Gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 90) / 72), "Int", 0, "Int", 0, "Int", 0, "Int", weight, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", face, "Ptr")
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
    rc := Buffer(16, 0)
    NumPut("Int", width, rc, 8)
    DllCall("User32\DrawTextW", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", rc, "UInt", 0x00000410)   ; DT_CALCRECT | DT_WORDBREAK
    height := NumGet(rc, 12, "Int")
    DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)
    DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return height
}

; Width of a single line of text (bold optional), in pixels.
MeasureTextWidth(text, pointSize, weight := 400, face := "Segoe UI") {
    hdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
    if (!hdc)
        return 0
    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(pointSize * DllCall("Gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 90) / 72), "Int", 0, "Int", 0, "Int", 0, "Int", weight, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", face, "Ptr")
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
    size := Buffer(8, 0)
    DllCall("Gdi32\GetTextExtentPoint32W", "Ptr", hdc, "Str", text, "Int", StrLen(text), "Ptr", size)
    DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)
    DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return NumGet(size, 0, "Int")
}

; Splits text into lineCount lines of nearly equal pixel width (breaks only between words) and returns them joined with
; a line feed. widest = the width in pixels of the widest resulting line. Every combination of break positions is tried;
; the one whose longest and shortest line differ least wins.
BalanceTextLines(text, lineCount, pointSize, &widest, weight := 400, topBias := 0, face := "Segoe UI") {
    words := StrSplit(Trim(text), " ")
    n := words.Length
    widest := MeasureTextWidth(text, pointSize, weight, face)
    if (n < lineCount || lineCount < 2)
        return text
    spaceW := MeasureTextWidth("a a", pointSize, weight, face) - MeasureTextWidth("aa", pointSize, weight, face)
    prefix := [0]
    for w in words
        prefix.Push(prefix[prefix.Length] + MeasureTextWidth(w, pointSize, weight, face) + spaceW)
    m := lineCount - 1                      ; number of breaks; breaks[k] = index of the last word of line k
    breaks := []
    Loop m
        breaks.Push(A_Index)
    bestBreaks := breaks.Clone(), bestRange := 1.0e9, bestMax := 1.0e9
    Loop {
        hi := 0, lo := 1.0e9, prev := 0, firstW := 0, lastW := 0
        Loop lineCount {
            last := (A_Index <= m) ? breaks[A_Index] : n
            lineW := prefix[last + 1] - prefix[prev + 1] - spaceW      ; words prev+1 .. last joined by single spaces
            hi := Max(hi, lineW), lo := Min(lo, lineW)
            if (A_Index = 1)
                firstW := lineW
            lastW := lineW
            prev := last
        }
        ; topBias > 0 (two lines): the first line should be wider than the last one by about topBias pixels.
        score := (topBias > 0) ? Abs((firstW - lastW) - topBias) : hi - lo
        if (score < bestRange || (score = bestRange && hi < bestMax)) {
            bestRange := score, bestMax := hi, bestBreaks := breaks.Clone()
        }
        ; next combination (odometer): move the rightmost break that can still move
        k := m
        while (k >= 1 && breaks[k] >= n - (m - k))
            k -= 1
        if (k < 1)
            break
        breaks[k] += 1
        t := k + 1
        while (t <= m) {
            breaks[t] := breaks[t - 1] + 1
            t += 1
        }
    }
    lines := []
    Loop lineCount
        lines.Push("")
    for k, word in words {
        idx := 1
        while (idx <= m && k > bestBreaks[idx])
            idx += 1
        lines[idx] .= (lines[idx] = "" ? "" : " ") word
    }
    result := "", widest := 0
    for ln in lines {
        widest := Max(widest, MeasureTextWidth(ln, pointSize, weight, face))
        result .= (result = "" ? "" : "`n") ln
    }
    return result
}

; One button of the warning. It is built exactly like the Start / Stop button: a rounded, borderless child window whose
; background colour equals the button colour, holding one owner-drawn label (DrawPillButton, the same painter).
MakeRiskButton(name, parentGui, label, x, y, w, h, fontSize, normal, hover, pressed) {
    global riskBtnRegistry
    g := Gui("-Caption +0x40000000", "")
    g.Opt("+Parent" parentGui.Hwnd)
    g.BackColor := normal
    ctl := g.Add("Text", Format("x0 y0 w{} h{} -Theme +0x100", w, h), label)
    ctl.SetFont("s" Round(fontSize) " Bold", "Segoe UI")
    ctl.Opt("+0x000D")
    ; The button object is built and REGISTERED before the window is shown: the very first paint (WM_DRAWITEM) can arrive
    ; during Show, when the global riskBtnAccept / riskBtnCancel still point to the previous (destroyed) buttons or are
    ; empty. Back then the label was not drawn and stayed missing until the mouse hovered it or a later repaint.
    obj := {name: name, gui: g, ctl: ctl, Hwnd: g.Hwnd, label: label, fontSize: fontSize, baseFont: fontSize
        , color: normal, normal: normal, hover: hover, pressed: pressed, x: x, y: y, w: w, h: h, scale: 1.0}
    riskBtnRegistry[ctl.Hwnd] := obj
    g.Show(Format("NA x{} y{} w{} h{}", x, y, w, h))
    ApplyRoundedCorners(g, 16)
    return obj
}

RiskButtonOwnerDraw(hwnd, itemHwnd, lParam) {
    global riskBtnAccept, riskBtnCancel, riskBtnRegistry
    if (riskBtnRegistry.Has(itemHwnd)) {
        rb := riskBtnRegistry[itemHwnd]
        if (hwnd = rb.gui.Hwnd)
            return DrawPillButton(lParam, rb.color, rb.label, rb.fontSize, rb.scale, 16)
    }
    for b in [riskBtnAccept, riskBtnCancel] {
        if (IsObject(b) && IsWindowValid(b.gui) && hwnd = b.gui.Hwnd && itemHwnd = b.ctl.Hwnd)
            return DrawPillButton(lParam, b.color, b.label, b.fontSize, b.scale, 16)
    }
    return ""
}

; Same as SetActionColor: the button is fully owner-drawn, so its colour is painted directly. gui.BackColor is NOT assigned any more:
; that runs InvalidateRect(erase = true) on a child of the composited main window, which made Windows re-print the whole window
; tree (the scrolling popup title included) on every hover / press colour change = the title shook when a button was touched.
SetRiskBtnColor(b, color, paint := true) {
    if (b.color = color)
        return
    b.color := color
    if (paint)
        RepaintRiskButtonNoErase(b)     ; paint := false when AnimateRiskButton follows: its first step paints the new colour anyway
}

RepaintRiskButtonNoErase(b) {
    if (!IsWindowValid(b.ctl))
        return
    ; Direct paint: only the button's own pixels are touched, nothing is invalidated (no window-tree re-print).
    if (PaintControlDirect(b.ctl, (ds) => DrawPillButton(ds, b.color, b.label, b.fontSize, b.scale, 16)))
        return
    DllCall("User32\InvalidateRect", "Ptr", b.ctl.Hwnd, "Ptr", 0, "Int", false)
    DllCall("User32\UpdateWindow", "Ptr", b.ctl.Hwnd)
}

; Same press / release motion as AnimateActionButton (button and label shrink to 94% and spring back, 45 ms).
AnimateRiskButton(b, pressed, onComplete := "") {
    global riskBtnAnimating, riskAnimTick
    global riskTitleActive, riskTitlePauseUntil
    riskBtnAnimating := true
    riskAnimTick := A_TickCount
    flagCleared := false
    try {
        ; Same technique as AnimateActionButton: the button WINDOW never moves, resizes or changes its region (each of those made
        ; Windows re-print the whole composited window tree = the scrolling popup title shook on every press). Only the scale
        ; changes; the shrunken pill + label are painted INSIDE the fixed window with a direct paint, and between two steps the
        ; marquee gets its display-refresh-locked frames (ServiceMarqueesDuringAnimation) instead of a Sleep.
        scaleStart := b.scale
        scaleEnd := pressed ? 0.94 : 1.0
        ; ALIGN TO THE REFRESH: the click arrives at a random moment inside a refresh interval. If the title is moving, first wait
        ; for the next refresh and give it its frame, so the first button paints (several ms of GDI work) happen right AFTER a
        ; title frame, inside a fresh interval, and can never push the title's next frame past its refresh (= the 1-frame shake).
        if (riskTitleActive && NowMs() >= riskTitlePauseUntil)
            ServiceMarqueesDuringAnimation()
        startTime := A_TickCount, duration := 45
        Loop {
            progress := Min((A_TickCount - startTime) / duration, 1.0)
            eased := 1 - (1 - progress) ** 3
            currScale := scaleStart + (scaleEnd - scaleStart) * eased
            b.scale := currScale
            b.fontSize := (currScale >= 0.999) ? b.baseFont : Max(8, Round(b.baseFont * currScale, 1))
            RepaintRiskButtonNoErase(b)
            if (progress >= 1.0)
                break
            ServiceMarqueesDuringAnimation()
        }
        if (!pressed) {
            b.scale := 1.0
            b.fontSize := b.baseFont
            RepaintRiskButtonNoErase(b)
        }
        ; the animation stalls the marquee's frames; drop the missed refreshes instead of catching up
        ResyncMarqueeClocks()
        ; The animation is over: release the flag BEFORE the action runs. The action (Continue = connect to Discord) can
        ; take seconds, and a flag held that long blocked every later click / key press on the warning.
        riskBtnAnimating := false
        flagCleared := true
        if (!pressed && IsObject(onComplete))
            onComplete()
    } finally {
        if (!flagCleared)
            riskBtnAnimating := false
    }
}

; Builds the warning view (a borderless child window of the main window, below the app name), for the
; title / ID stored in riskPendingName / riskPendingAppId.
;   line 1: <name>                 (16 pt bold; scrolls with the shared marquee engine when it is too wide)
;   line 2: ID: <id>               (12 pt bold)
;   line 3: This game has no detectable executable ...   (10 pt)
;   line 4: WARNING ...            (10 pt bold, 3 lines of equal width)
; Below the app name a 3 px line (as wide as "RAGNIOUS", pointed ends) replaces the tagline while the warning is shown.
EnsureRiskView(mainWidth, mainHeight) {
    global mainGui, riskGui, riskBtnAccept, riskBtnCancel, riskPendingName, riskPendingAppId, riskTosGui, riskTosCtl
    global riskTitleCtl, riskTitleActive, riskTitleText, riskTitleOffset, riskTitleOverflowW, riskTitleCycleW, riskTitleTrackW, riskTitleInset
    global riskTitleRenderedX, riskTitleFrames, riskTitleLastTick, riskTitlePauseUntil, riskTitleStripDirty, riskLineGui, riskLineCtl
    global riskTitleRenderedPhase
    global riskIconCtl, riskIconHbm, riskIconKey, riskIconReal, riskIconPx, rowIconsEnabled, gdiplusToken, riskIconTitleGap, riskIconSize, riskTitleSideInset
    global riskWarnSign, riskWarnSignPs, riskWarnBlinkStep, riskWarnBmps, riskWarnShown, dotBlinkStep, riskHandCtl, riskHandBmp
    global riskTitleVNudge, riskBtnAcceptX, riskBtnCancelX, riskBtnW, riskBtnH, riskBtnFontSize
    global riskGapLineToTitle, riskGapTitleToId, riskGapIdToDesc, riskGapDescToWarn, riskGapWarnToButtons
    if (IsWindowValid(riskGui))
        return
    ; "&" would be read as a keyboard-accelerator marker in a Text control, so it is doubled for display.
    pTitle := StrReplace(riskPendingName, "&", "&&")
    pId := "ID: " riskPendingAppId
    p2 := "This game has no detectable executable in Discord’s database, so the system will connect to Discord’s local IPC using the game’s application ID and send a SET_ACTIVITY request. Discord will then display the game as the current activity without requiring a running executable."
    p3 := "WARNING: This may Violate Discord’s Platform Manipulation`nPolicy and could result in account suspension or termination`nContinue at your own risk?"

    ; The warning view starts right under the white line. Everything from that line down to the bottom of the window
    ; (title + ID, description, warning, buttons) is placed with the fixed riskGap... margins (see the gap chain below).
    ; Gaps are measured between the visible ink (top of the capitals / bottom of the descenders, button edges).
    pad := 36, fullW := mainWidth - pad * 2
    btnW := riskBtnW, btnH := riskBtnH, btnGap := 32   ; popup buttons: their own size (no longer the Start / Stop button's size minus 35 %)
    fs := riskBtnFontSize                          ; popup button label: its own size
    ps := 10
    titlePs := 16                                  ; title
    idPs := 12                                     ; ID line
    warnPs := 10                                   ; warning line (bold)

    ; The title scrolls (marquee) when it does not fit on one line. The scrolling strip is one off-screen bitmap, which
    ; Windows limits in size, so an enormous title is cut (with "...") to at most 29000 px; the full name is untouched
    ; (riskPendingName is what gets saved). Without this the end of the scroll ran past the bitmap and glitched.
    ; Padding (free space) before AND after the title = riskTitleSideInset (its own value; it used to be copied from the
    ; free space in front of the status dot and no longer follows it). The title's viewport uses it on both sides, so the
    ; title starts at the first point and ends at the last point of the viewport.
    riskTitleInset := riskTitleSideInset + Round(A_ScreenDPI / 96)   ; its own padding (no longer the status dot's position)
    titleX := riskTitleInset, titleW := mainWidth - 1 - riskTitleInset * 2
    displayName := riskPendingName
    titleTextW := MeasureTextWidth(displayName, titlePs, 700)
    if (titleTextW > 28000) {
        while (StrLen(displayName) > 4 && titleTextW > 28000) {
            displayName := SubStr(displayName, 1, Floor(StrLen(displayName) * 0.9))
            titleTextW := MeasureTextWidth(displayName "…", titlePs, 700)
        }
        displayName .= "…"
    }
    ; Game icon in front of the title: same size as the title's text (16 pt), the same picture as in the dropdown.
    riskIconKey := (rowIconsEnabled && gdiplusToken) ? FindGameKey(riskPendingName, riskPendingAppId) : ""
    ; The icon has EXACTLY the same size as the icon in the search box (RowIconSize). It is centred on the centre of the capital letters
    ; (see iconY below); that is the same pixel position only when the icon and the capitals are both an even or both an odd number of rows
    ; tall (otherwise it is half a pixel off). riskIconMatchCenterParity = true trades 1 px of icon size for that exact centre.
    popIconPx := riskIconSize                     ; its own size (no longer the search box's / dropdown's icon size)
    if (riskIconMatchCenterParity && riskIconKey != "" && MeasureInkSpan("H", titlePs, 700, 200, Round(FontEmPx(titlePs) * 3) + 8, &capTop0, &capBot0)) {
        if (Mod(popIconPx - (capBot0 - capTop0), 2) != 0)
            popIconPx -= 1
    }
    popIconOff := (riskIconKey != "") ? popIconPx + riskIconTitleGap : 0   ; [inset][icon][gap][title]: gap = riskIconTitleGap (its own value)
    titleMarquee := (titleTextW > titleW - popIconOff)
    if (titleMarquee)
        hTitleRaw := MeasureWrappedTextHeight("Ag", titleW, titlePs, 700)
    else
        hTitleRaw := MeasureWrappedTextHeight(pTitle, titleW, titlePs, 700)
    hTitle := hTitleRaw + 4
    hIdRaw := MeasureWrappedTextHeight(pId, fullW, idPs, 700)
    hId := hIdRaw + 4
    ; The description is shown on exactly 4 lines of (as near as possible) equal width: the line breaks are chosen
    ; by BalanceTextLines. It gets (almost) the full window width and, only if the widest line still does not fit,
    ; its font shrinks in half-point steps (10 pt whenever it fits).
    descX := 8, descW := mainWidth - descX * 2, descPs := 10
    descFace := "Segoe UI Semibold"           ; the description is semi-bold (title, ID and warning are bold)
    Loop {
        descText := BalanceTextLines(p2, 4, descPs, &descWidest, 400, 0, descFace)
        if (descWidest <= descW - 2 || descPs <= 7)
            break
        descPs -= 0.5
    }
    h2Raw := MeasureWrappedTextHeight(descText, descW, descPs, 400, descFace)
    h2 := h2Raw + 4
    ; The warning is shown on exactly 3 fixed lines (the line breaks are written into p3). It gets (almost) the full
    ; window width and, only if the widest line does not fit, its font shrinks in half-point steps (10 pt whenever it fits).
    warnX := 8, warnW := mainWidth - warnX * 2
    warnText := p3
    Loop {
        warnWidest := 0
        for ln in StrSplit(warnText, "`n")
            warnWidest := Max(warnWidest, MeasureTextWidth(ln, warnPs, 700))
        if (warnWidest <= warnW - 2 || warnPs <= 8)
            break
        warnPs -= 0.5
    }
    h3Raw := MeasureWrappedTextHeight(warnText, warnW, warnPs, 700)
    h3 := h3Raw + 4

    ; Visible top / bottom of every element, measured from the top of its control. (The scrolling title is centred
    ; vertically in its control, i.e. 2 px lower than a normal static text.)
    ; titleTopEm: how far the title's ink reaches above its baseline (em). Calibrated from a screenshot where the gap
    ; under the white line was 2 px bigger than the gap above it (0.76 -> 0.675). Raise it to move the title down,
    ; lower it to move the title up.
    titleTopEm := 0.675
    RiskInkSpan(titlePs, 700, hTitleRaw, titleTopEm, 0.21, titleMarquee ? 2 : 0, &aTitle, &bTitle)
    ; The icon is taller than the title's letters: it is centred on the capital letters and counts as part of the title's visible
    ; height, so the equal gaps (line -> title, title -> ID, ...) are measured from the icon's top / bottom, not from the letters.
    capCenterRel := aTitle + 0.325 * FontEmPx(titlePs)            ; estimate, used only if the letters can't be measured
    ; The real centre of the title's capital letters: an "H" is drawn off-screen with the title's font and its ink is read back.
    if (MeasureInkSpan("H", titlePs, 700, 100, hTitleRaw + 8, &hTop, &hBot))
        capCenterRel := (titleMarquee ? 2 : 0) + (hTop + hBot) / 2
    if (popIconOff > 0) {
        aTitle := Min(aTitle, capCenterRel - popIconPx / 2)
        bTitle := Max(bTitle, capCenterRel + popIconPx / 2)
    }
    ; The ID, description and warning are MEASURED: the real text is drawn off-screen with the very same font and the
    ; first / last row that has ink is read back, so the three gaps below are equal to the pixel (the old em estimates
    ; were up to 1 px off, which showed as 17 / 18 / 18 px). The estimate stays only as a fallback.
    if (!MeasureInkSpan(pId, idPs, 700, fullW, hId + 8, &aId, &bId))
        RiskInkSpan(idPs, 700, hIdRaw, 0.71, 0.0, 0, &aId, &bId)
    if (!MeasureInkSpan(descText, descPs, 400, descW, h2 + 8, &a2, &b2, descFace))
        RiskInkSpan(descPs, 400, h2Raw, 0.76, 0.21, 0, &a2, &b2)
    if (!MeasureInkSpan(warnText, warnPs, 700, warnW, h3 + 8, &a3, &b3))
        RiskInkSpan(warnPs, 700, h3Raw, 0.76, 0.21, 0, &a3, &b3)
    spans := [[aTitle, bTitle], [aId, bId], [a2, b2], [a3, b3], [0, btnH - 1]]   ; button: visible height = h - 1
    sumInk := 0
    for sp in spans
        sumInk += sp[2] - sp[1]
    ; Every margin is its own fixed value (see the riskGap... settings at the top of the script); nothing follows another margin.
    ; The reference positions are built ONCE from the factory margins (20 / 5 / 13 / 13 / 14). Each riskGap... value then moves ONLY
    ; the element right below it (see the deltas after the icon fix), so changing one margin never pushes everything under it.
    topGap := 20
    titleIdGapUsed := 5
    gaps := [13, 13, 14]
    cursor := topGap
    ys := []
    for i, sp in spans {
        ys.Push(Round(cursor - sp[1]))
        cursor += (sp[2] - sp[1]) + (i = 1 ? titleIdGapUsed : (i <= 4 ? gaps[i - 1] : 0))   ; i = 5 is the buttons: nothing follows them
        cursor := Round(cursor)
    }
    ; With the icon, the ICON (not the letters) is the top of the title group, so the icon's top edge must land exactly on topGap
    ; (the yellow margin = the red margin). The title and the icon move together, so their alignment does not change.
    if (popIconOff > 0 && Abs(aTitle - (capCenterRel - popIconPx / 2)) < 0.001)
        ys[1] += Round(topGap) - Round(ys[1] + capCenterRel - popIconPx / 2)
    ys[1] += Round(riskGapLineToTitle - 20)          ; line -> icon / title
    ys[2] += Round(riskGapTitleToId - 5)             ; title -> ID
    ys[3] += Round(riskGapIdToDesc - 13)             ; ID -> description
    ys[4] += Round(riskGapDescToWarn - 13)           ; description -> warning
    ys[5] += Round(riskGapWarnToButtons - 14)        ; warning -> buttons

    riskGui := Gui("-Caption -Border -E0x200 +0x40000000", "")
    riskGui.Opt("+Parent" mainGui.Hwnd)
    riskGui.BackColor := "000000"
    riskGui.MarginX := 0, riskGui.MarginY := 0
    RemoveNativeOutline(riskGui.Hwnd)

    if (titleMarquee) {
        riskTitleCtl := riskGui.Add("Text", Format("x{} y{} w{} h{} +0x000D", titleX + popIconOff, ys[1] + riskTitleVNudge, titleW - popIconOff, hTitle), "")
        riskTitleText := displayName
        ; Same engine as the status line: one cycle = [title][padding]; the strip holds the cycle twice, so when the
        ; offset reaches one cycle the view is identical to the start (title's first letter at the first point of the
        ; viewport; the cycle ends exactly where the padding after the title ends) and the loop wraps without a jump.
        ; SAME movement as the dropdown titles (StartDropdownMarquee / UpdateDropdownMarquee): the title starts at the left
        ; edge of the viewport, slides left until its LAST letter reaches the right edge, holds there for the equivalent of
        ; the two side insets, then jumps back to the start and pauses. No looping copy / padding.
        riskTitleOverflowW := titleTextW - (titleW - popIconOff)
        riskTitleCycleW := riskTitleOverflowW + riskTitleInset * 2
        riskTitleTrackW := titleTextW
        riskTitleOffset := 0.0, riskTitleFrames := 0, riskTitleRenderedX := 0, riskTitleRenderedPhase := 0
        riskTitleLastTick := FrameStamp()
        riskTitlePauseUntil := NowMs() + MarqueePauseMs()
        riskTitleStripDirty := true
        riskTitleActive := true
        ; Render the whole title strip NOW, before the warning is shown, instead of inside the very first paint: for a
        ; huge title that first paint was slow, so the title popped in late / flashed while the view was appearing.
        stripRefDc := DllCall("User32\GetDC", "Ptr", mainGui.Hwnd, "Ptr")
        if (stripRefDc) {
            BuildRiskTitleStrip(stripRefDc, hTitle)
            DllCall("User32\ReleaseDC", "Ptr", mainGui.Hwnd, "Ptr", stripRefDc)
        }
    } else {
        riskTitleActive := false
        riskTitleCtl := ""
        if (popIconOff > 0) {              ; [icon + title] is centred as ONE unit
            unitW := popIconOff + titleTextW
            unitX := titleX + (titleW - unitW) // 2
            tTitle := riskGui.Add("Text", Format("x{} y{} w{} h{} Left Background000000 cFFFFFF", unitX + popIconOff, ys[1] + riskTitleVNudge, titleTextW + 6, hTitle), pTitle)
        } else {
            tTitle := riskGui.Add("Text", Format("x{} y{} w{} h{} Center Background000000 cFFFFFF", titleX, ys[1] + riskTitleVNudge, titleW, hTitle), pTitle)
        }
        tTitle.SetFont("s" titlePs " Bold", "Segoe UI")
    }
    if (popIconOff > 0) {
        iconX := titleMarquee ? titleX : (titleX + (titleW - (popIconOff + titleTextW)) // 2)
        ; vertically on the centre of the capital letters of the title (same parity as the letters, so the two centres are identical)
        iconY := Round(ys[1] + capCenterRel - popIconPx / 2) + riskIconVNudge
        riskIconPx := popIconPx
        riskIconCtl := riskGui.Add("Text", Format("x{} y{} w{} h{} +0xE +0x04000000", iconX, iconY, popIconPx, popIconPx), "")
        master := GetGameIconBitmap(riskIconKey)
        riskMissing := (!master && GameIconIsMissing(riskIconKey))
        riskIconReal := master ? 1 : (riskMissing ? 2 : 0)
        riskIconHbm := MakeIconHBitmap(master, popIconPx, riskMissing)
        if (riskIconHbm)
            SendMessage(0x0172, 0, riskIconHbm, riskIconCtl.Hwnd)
    } else {
        riskIconCtl := ""
    }
    tId := riskGui.Add("Text", Format("x{} y{} w{} h{} Center Background000000 cFFFFFF", pad, ys[2], fullW, hId), pId)
    tId.SetFont("s" idPs " Bold", "Segoe UI")
    t2 := riskGui.Add("Text", Format("x{} y{} w{} h{} Center Background000000 cA0A0A0", descX, ys[3], descW, h2), descText)
    t2.SetFont("s" descPs " Norm", descFace)
    ; Line 3 is a control of its own so that [hand + "Continue at your own risk?"] is centred as ONE unit (the hand is part
    ; of the line). Lines 1 and 2 stay in the big control, exactly where they were.
    warnLines := StrSplit(warnText, "`n")
    t3 := riskGui.Add("Text", Format("x{} y{} w{} h{} Center +0x04000000 Background000000 cF2A900", warnX, ys[4], warnW, 2 * Round(h3Raw / 3) + 4), warnLines[1] "`n" warnLines[2])   ; only the 2 lines it shows: it must not cover line 3
    t3.SetFont("s" warnPs " Bold", "Segoe UI")
    ; Warning sign in front of "WARNING" (first line): same point size as the text, blinking like the status dot
    ; (see UpdateWarnSignBlink). The first line stays centred like the other two; the sign hangs just left of it.
    firstLine := StrSplit(warnText, "`n")[1]
    line1W := MeasureTextWidth(firstLine, warnPs, 700)
    spaceW := MeasureTextWidth("a a", warnPs, 700) - MeasureTextWidth("aa", warnPs, 700)
    ; The sign is part of the first line, directly in front of "WARNING" (one space away). It is a solid triangle in the
    ; animated amber with the exclamation mark cut out in black (#000000 = the window background). A font glyph cannot
    ; be filled like that, so it is drawn as a small bitmap (one per colour step, see BuildWarnSignBitmaps) and the
    ; status dot's timer swaps them (UpdateWarnSignBlink). Its height is the height of the capitals of "WARNING" (+2 px).
    GetFontAscentH("Segoe UI", warnPs, 700, &ascText, &hText)
    capT := 0, capB := 0
    if (!MeasureInkSpan("WARNING", warnPs, 700, 240, Round(warnPs * 4), &capT, &capB)) {
        capB := ascText
        capT := ascText - Round(0.72 * warnPs * 96 / 72)
    }
    signH := (capB - capT) + 2
    signW := Round(signH * 1.15)
    signX := warnX + (warnW - line1W) // 2 - signW - spaceW
    signY := ys[4] + capT - 1                              ; 1 px above the capitals and 1 px below the baseline
    FreeWarnBitmaps()
    riskWarnBmps := BuildWarnSignBitmaps(signW, signH)
    riskWarnBlinkStep := 0
    ; Both icons are OWNER-DRAWN (SS_OWNERDRAW, like the line / logo / buttons of this view): the control repaints its whole
    ; area from a ready bitmap with one BitBlt and never fills its background first, so swapping frames cannot flash.
    riskWarnSign := riskGui.Add("Text", Format("x{} y{} w{} h{} +0x000D +0x04000000", signX, signY, signW, signH), "")
    ; Start on the step the status dot is on right now, so the sign never jumps when its updates begin.
    riskWarnShown := 0
    if (riskWarnBmps.Length) {
        startIdx := (dotBlinkStep > 0) ? Mod(dotBlinkStep - 1, riskWarnBmps.Length) + 1 : 1
        riskWarnBlinkStep := startIdx
        riskWarnShown := startIdx
    }
    ; WS_CLIPSIBLINGS on both controls: the full-width warning text (black background) overlaps the sign's rectangle and
    ; used to repaint over it. Also keep the sign on top of its sibling.
    DllCall("User32\SetWindowPos", "Ptr", riskWarnSign.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")

    ; Pointing hand (solid, like the 👉 emoji) in front of the third line ("Continue at your own risk?"): fixed (no animation),
    ; filled with the colour of the warning text (#F2A900), the same height as the sign, on the same line.
    handH := (capB - capT) + 2                       ; its own height (no longer the warning sign's height)
    handW := Round(handH * 192 / 148)
    line3W := MeasureTextWidth(warnLines[3], warnPs, 700)
    lh := Round(h3Raw / 3)
    line3Y := ys[4] + 2 * lh
    startX := warnX + (warnW - (handW + spaceW + line3W)) // 2        ; [hand][space][text] centred as one unit
    t3b := riskGui.Add("Text", Format("x{} y{} w{} h{} Left +0x04000000 Background000000 cF2A900", startX + handW + spaceW, line3Y, line3W + 8, lh + 4), warnLines[3])
    t3b.SetFont("s" warnPs " Bold", "Segoe UI")
    DllCall("User32\SetWindowPos", "Ptr", t3b.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")   ; on top of everything created before it
    handX := startX
    handY := line3Y + capT - 1
    if (riskHandBmp)
        DllCall("Gdi32\DeleteObject", "Ptr", riskHandBmp)
    riskHandBmp := BuildHandBitmap(handW, handH)
    riskHandCtl := riskGui.Add("Text", Format("x{} y{} w{} h{} +0x000D +0x04000000", handX, handY, handW, handH), "")
    DllCall("User32\SetWindowPos", "Ptr", riskHandCtl.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")

    ; The free space between the left and right edge of the description text (its widest line) is divided into THREE equal
    ; paddings: left edge -> Continue, Continue -> Cancel, Cancel -> right edge. (Whole pixels: a remainder of 1 goes to
    ; the middle gap, a remainder of 2 to the two outer paddings, so the layout stays symmetrical.)
    areaLeft := descX + (descW - descWidest) // 2
    freeW := descWidest - btnW * 2
    padG := freeW // 3, padR := freeW - padG * 3
    padOuter := padG + (padR = 2 ? 1 : 0)
    padMid := padG + (padR = 1 ? 1 : 0)
    btnX := areaLeft + padOuter
    btnGap := padMid
    acceptX := (riskBtnAcceptX = "") ? btnX : Integer(riskBtnAcceptX)                    ; fixed positions when set, otherwise the three-equal-gaps layout
    cancelX := (riskBtnCancelX = "") ? btnX + btnW + btnGap : Integer(riskBtnCancelX)
    riskBtnAccept := MakeRiskButton("accept", riskGui, "Continue", acceptX, ys[5], btnW, btnH, fs, "208A4E", "279B5A", "186B3C")
    riskBtnCancel := MakeRiskButton("cancel", riskGui, "Cancel", cancelX, ys[5], btnW, btnH, fs, "B42318", "D12F26", "9A1E15")

    ; The 3 px line that replaces the tagline: as wide as "RAGNIOUS", with thin pointed ends (see PositionRiskLine).
    riskLineGui := Gui("-Caption -Border -E0x200 +0x40000000", "")
    riskLineGui.Opt("+Parent" mainGui.Hwnd)
    riskLineGui.BackColor := "000000"
    riskLineGui.MarginX := 0, riskLineGui.MarginY := 0
    riskLineCtl := riskLineGui.Add("Text", "x0 y0 w10 h3 +0x000D", "")
    RemoveNativeOutline(riskLineGui.Hwnd)

    ; The terms-of-service icon: takes the place of the version text (top left) while the warning is shown.
    riskTosGui := Gui("-Caption -Border -E0x200 +0x40000000", "")
    riskTosGui.Opt("+Parent" mainGui.Hwnd)
    riskTosGui.BackColor := "000000"
    riskTosGui.MarginX := 0, riskTosGui.MarginY := 0
    riskTosCtl := riskTosGui.Add("Text", "x0 y0 w58 h56 +0x000D", "")
    RemoveNativeOutline(riskTosGui.Hwnd)
}

; Top of the warning view = the bottom edge of the 3 px white line (the line replaces the tagline, see PositionRiskLine).
RiskViewTopY() {
    global riskContentTopY
    return riskContentTopY                               ; its own value (no longer computed from the white line)
}

; Visible gap between the bottom of the capitals of "RAGNIOUS" and the top of the white line (the red gap).
; The same gap is left between the bottom of the line and the top of the popup title.
RiskTitleTopGap() {
    nameY := 50, nameH := 74
    rawH := MeasureWrappedTextHeight("RAGNIOUS", 587, 40, 700)
    RiskInkSpan(40, 700, rawH, 0.70, 0.0, (nameH - rawH) // 2, &capTop, &capBottom)
    lineTop := (50 + 74 - 18) + 3 + (42 - 3) // 2
    return Max(0, Round(lineTop - (nameY + capBottom)))
}

; Visible gap under the status message of the main window: from the bottom of its text (descenders) to the last
; visible row of the window. The popup leaves exactly this under the Continue / Cancel buttons.
RiskButtonsBottomGap(mainHeight) {
    statusHeight := 42
    statusY := Floor(mainHeight - statusHeight - 10 - (statusHeight * 0.05))   ; identical to PositionStatusControls
    rawH := MeasureWrappedTextHeight("Ag", 468, 12, 400)
    RiskInkSpan(12, 400, rawH, 0.76, 0.21, (statusHeight - rawH) // 2, &inkTop, &inkBottom)
    return Max(0, Round((mainHeight - 1) - (statusY + inkBottom)))
}

; Space between the bottom of the title bar (its buttons are 56 px tall) and the top of the capitals of "RAGNIOUS".
; The warning view leaves exactly this much room under the buttons.
RiskBottomGap() {
    nameY := 50, nameH := 74
    rawH := MeasureWrappedTextHeight("RAGNIOUS", 587, 40, 700)
    RiskInkSpan(40, 700, rawH, 0.70, 0.0, (nameH - rawH) // 2, &capTop, &unused)   ; the name is centred vertically in its control
    return Max(0, Round(nameY + capTop - 56))
}

; Exact visible span of a text: draws it off-screen (white on black, same font and centring as the control) and returns
; the first row with ink (inkTop) and the row after the last one (inkBottom), measured from the top of the control.
; Returns false when the measurement could not be made (the caller then falls back to RiskInkSpan).
MeasureInkSpan(text, pointSize, weight, w, h, &inkTop, &inkBottom, fontName := "Segoe UI") {
    inkTop := 0, inkBottom := 0
    w := Max(8, Round(w)), h := Max(8, Round(h))
    hdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
    if (!hdc)
        return false
    memDc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", hdc, "Ptr")
    ok := false
    if (memDc) {
        bi := Buffer(40, 0)
        NumPut("UInt", 40, bi, 0), NumPut("Int", w, bi, 4), NumPut("Int", -h, bi, 8), NumPut("UShort", 1, bi, 12), NumPut("UShort", 32, bi, 14)
        bits := 0
        dib := DllCall("Gdi32\CreateDIBSection", "Ptr", memDc, "Ptr", bi, "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
        if (dib && bits) {
            oldBmp := DllCall("Gdi32\SelectObject", "Ptr", memDc, "Ptr", dib, "Ptr")
            hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(pointSize * DllCall("Gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 90) / 72), "Int", 0, "Int", 0, "Int", 0, "Int", weight, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 4, "UInt", 0, "Str", fontName, "Ptr")
            oldFont := DllCall("Gdi32\SelectObject", "Ptr", memDc, "Ptr", hFont, "Ptr")
            DllCall("Gdi32\SetBkMode", "Ptr", memDc, "Int", 1)
            DllCall("Gdi32\SetTextColor", "Ptr", memDc, "UInt", 0x00FFFFFF)
            rc := Buffer(16, 0)
            NumPut("Int", w, rc, 8), NumPut("Int", h, rc, 12)
            ; DT_CENTER | DT_NOCLIP | DT_NOPREFIX
            DllCall("User32\DrawTextW", "Ptr", memDc, "Str", text, "Int", -1, "Ptr", rc, "UInt", 0x00000901)
            DllCall("Gdi32\GdiFlush")
            first := -1, last := -1
            pairs := w // 2
            Loop h {
                y := A_Index - 1
                rowPtr := bits + y * w * 4
                hit := false
                Loop pairs {
                    ; two pixels per read; ink = blue channel >= 0x40 (about 25 % coverage) in either pixel
                    if (NumGet(rowPtr, (A_Index - 1) * 8, "UInt64") & 0x0000004000000040) {
                        hit := true
                        break
                    }
                }
                if (!hit && (w & 1) && (NumGet(rowPtr, (w - 1) * 4, "UInt") & 0x40))
                    hit := true
                if (hit) {
                    if (first < 0)
                        first := y
                    last := y
                }
            }
            if (first >= 0) {
                inkTop := first, inkBottom := last + 1
                ok := true
            }
            DllCall("Gdi32\SelectObject", "Ptr", memDc, "Ptr", oldFont, "Ptr")
            DllCall("Gdi32\DeleteObject", "Ptr", hFont)
            DllCall("Gdi32\SelectObject", "Ptr", memDc, "Ptr", oldBmp, "Ptr")
            DllCall("Gdi32\DeleteObject", "Ptr", dib)
        }
        DllCall("Gdi32\DeleteDC", "Ptr", memDc)
    }
    DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return ok
}

; Visible span of a text control: distance from the control's top to the top of the ink (first line) and to the bottom
; of the ink (last line). topEm / botEm = how far the ink reaches above / below the baseline, in em
; (capitals and ascenders ~0.76, descenders ~0.21). rawH = height of the text itself (without the +4 of the control).
RiskInkSpan(pointSize, weight, rawH, topEm, botEm, ctrlOffset, &inkTop, &inkBottom) {
    hdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(pointSize * DllCall("Gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 90) / 72), "Int", 0, "Int", 0, "Int", 0, "Int", weight, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", "Segoe UI", "Ptr")
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
    tm := Buffer(80, 0)
    DllCall("Gdi32\GetTextMetricsW", "Ptr", hdc, "Ptr", tm)
    lineH := NumGet(tm, 0, "Int"), ascent := NumGet(tm, 4, "Int"), internalLeading := NumGet(tm, 12, "Int")
    DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)
    DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    em := lineH - internalLeading
    inkTop := ctrlOffset + ascent - topEm * em
    inkBottom := ctrlOffset + (rawH - lineH) + ascent + botEm * em
}

; Places the soft line where the tagline was: 3 px tall, as wide as "RAGNIOUS" (see DrawRiskLine for the look).
PositionRiskLine(mainWidth) {
    global riskLineGui, riskLineCtl, appNameY, appNameH, appTaglineH
    if (!IsWindowValid(riskLineGui) || !IsWindowValid(riskLineCtl))
        return
    lineW := MeasureTextWidth("RAGNIOUS", 40, 700)     ; same length as the app name (allowed group: app name + white line)
    lineH := 3
    lineX := (mainWidth - lineW) // 2
    lineY := (appNameY + appNameH - 18) + 3 + (appTaglineH - lineH) // 2   ; vertical centre of the old tagline
    static lastLineKey := ""
    lineKey := Format("{}|{}|{}|{}|{}", riskLineGui.Hwnd, lineX, lineY, lineW, lineH)
    DllCall("User32\SetWindowPos", "Ptr", riskLineGui.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")
    if (lineKey = lastLineKey && DllCall("User32\IsWindowVisible", "Ptr", riskLineGui.Hwnd, "Int"))
        return
    lastLineKey := lineKey
    riskLineGui.Show(Format("NA x{} y{} w{} h{}", lineX, lineY, lineW, lineH))
    riskLineCtl.Move(0, 0, lineW, lineH)
    DllCall("User32\SetWindowPos", "Ptr", riskLineGui.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")
    DllCall("User32\InvalidateRect", "Ptr", riskLineCtl.Hwnd, "Ptr", 0, "Int", false)
}

RiskLineOwnerDraw(hwnd, itemHwnd, lParam) {
    global riskLineGui, riskLineCtl
    if (IsObject(riskLineGui) && IsWindowValid(riskLineGui) && IsWindowValid(riskLineCtl) && hwnd = riskLineGui.Hwnd && itemHwnd = riskLineCtl.Hwnd)
        return DrawRiskLine(lParam)
    return ""
}

RiskTosOwnerDraw(hwnd, itemHwnd, lParam) {
    global riskTosGui, riskTosCtl
    if (IsObject(riskTosGui) && IsWindowValid(riskTosGui) && IsWindowValid(riskTosCtl) && hwnd = riskTosGui.Hwnd && itemHwnd = riskTosCtl.Hwnd)
        return DrawRiskTosIcon(lParam)
    return ""
}

; Discord logo (terms-of-service link, top left of the warning view). Vector path drawn with GDI+ off-screen and copied
; once (no flicker); the two eyes are holes of the same path. Same motion language as the refresh button:
;   hover  -> the logo fades grey -> Discord blurple (it keeps its size)
;   press  -> darker blurple while the button is held (the logo does not shrink)
;   click  -> a thin ripple ring leaves the logo and fades out
; The logo's left edge sits on the same x as the left edge of the version text; its centre is on the centre line of
; the minimize / close buttons.
DrawRiskTosIcon(drawItemStruct) {
    global gdiplusToken, tosIconPressed, tosRippleStart, tosRippleDuration
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    targetHdc := NumGet(drawItemStruct, itemHwndOffset + A_PtrSize, "Ptr")
    rectOffset := itemHwndOffset + A_PtrSize * 2
    left := NumGet(drawItemStruct, rectOffset, "Int")
    top := NumGet(drawItemStruct, rectOffset + 4, "Int")
    width := NumGet(drawItemStruct, rectOffset + 8, "Int") - left
    height := NumGet(drawItemStruct, rectOffset + 12, "Int") - top
    if (width <= 0 || height <= 0 || !targetHdc)
        return 1
    memoryDc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", targetHdc, "Ptr")
    if (!memoryDc)
        return 1
    bitmap := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", targetHdc, "Int", width, "Int", height, "Ptr")
    if (!bitmap) {
        DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
        return 1
    }
    oldBitmap := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", bitmap, "Ptr")
    localRect := Buffer(16, 0)
    NumPut("Int", width, localRect, 8)
    NumPut("Int", height, localRect, 12)
    ; Plain icon on the black window background (no button background).
    hover := TosHoverValue()
    bg := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00000000, "Ptr")
    DllCall("User32\FillRect", "Ptr", memoryDc, "Ptr", localRect, "Ptr", bg)
    DllCall("Gdi32\DeleteObject", "Ptr", bg)

    if (gdiplusToken) {
        graphicsBuffer := Buffer(A_PtrSize, 0)
        if (DllCall("gdiplus\GdipCreateFromHDC", "Ptr", memoryDc, "Ptr", graphicsBuffer, "UInt") = 0) {
            graphics := NumGet(graphicsBuffer, 0, "Ptr")
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4, "UInt")

            colorHex := tosIconPressed ? "4752C4" : BlendHexColor("A0A0A0", "5865F2", hover)
            argb := 0xFF000000 | Integer("0x" colorHex)
            ; The "?" badge uses a red that sits on the same saturation / brightness as Discord's blurple
            ; (5865F2: S 64 %, V 95 %  ->  F2585F;  pressed 4752C4: V 77 %  ->  C4474E), so the two read as one icon.
            badgeHex := tosIconPressed ? "C4474E" : BlendHexColor("A0A0A0", "F2585F", hover)
            badgeArgb := 0xFF000000 | Integer("0x" badgeHex)
            ; Original size of the logo: about 28 px wide (1.17 x its 23.9 units), 21 px tall.
            baseScale := 1.17
            sc := baseScale                                    ; the logo never changes size (no grow on hover, no shrink on click)
            logoCX := 11.95, logoCY := 12.0                    ; centre of the logo in its own coordinates
            ; The logo's left edge sits on x 25 of the main window = the left edge of the version text's ink. This control
            ; starts at x 12 of the main window (see PositionRiskTosIcon).
            cx := (25 - 12) + logoCX * baseScale
            cy := height / 2.0                                 ; same centre line as the minimize / close icons

            path := 0
            pathBuffer := Buffer(A_PtrSize, 0)
            if (DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr", pathBuffer, "UInt") = 0) {
                path := NumGet(pathBuffer, 0, "Ptr")
                segs := [
        [15.4319, 2.8546],
        [15.3534, 2.8917],
        [15.1424, 3.2670, 14.9087, 3.7565, 14.7451, 4.1412],
        [12.9004, 3.8650, 11.0651, 3.8650, 9.2583, 4.1412],
        [9.0947, 3.7479, 8.8525, 3.2670, 8.6406, 2.8917],
        [8.5621, 2.8547],
        [3.6769, 4.3697],
        [3.6448, 4.3974],
        [0.5334, 9.0458, -0.3190, 13.5799, 0.0992, 18.0578],
        [0.1304, 18.1139],
        [2.1832, 19.6215, 4.1717, 20.5367, 6.1233, 21.1433],
        [6.2075, 21.1157],
        [6.6691, 20.4853, 7.0806, 19.8205, 7.4335, 19.1215],
        [7.3919, 19.0158],
        [6.7391, 18.7682, 6.1176, 18.4663, 5.5197, 18.1235],
        [5.5121, 17.9958],
        [5.6379, 17.9015, 5.7638, 17.8035, 5.8839, 17.7044],
        [5.9615, 17.6939],
        [9.8893, 19.4872, 14.1415, 19.4872, 18.0229, 17.6939],
        [18.1014, 17.7034],
        [18.2216, 17.8024, 18.3474, 17.9015, 18.4742, 17.9958],
        [18.4676, 18.1234],
        [16.5946, 19.0148],
        [16.5539, 19.1215],
        [16.9143, 19.8195, 17.3258, 20.4843, 17.7789, 21.1147],
        [17.8631, 21.1433],
        [19.8241, 20.5366, 21.8126, 19.6214, 23.8654, 18.1139],
        [23.8967, 18.0587],
        [24.3971, 12.8817, 23.0585, 8.3848, 20.3482, 4.3983],
        [20.3170, 4.3697]
                ]
                px := 20.317, py := 4.3698
                for sg in segs {
                    if (sg.Length = 2) {
                        DllCall("gdiplus\GdipAddPathLine", "Ptr", path, "Float", px, "Float", py, "Float", sg[1], "Float", sg[2], "UInt")
                        px := sg[1], py := sg[2]
                    } else {
                        DllCall("gdiplus\GdipAddPathBezier", "Ptr", path, "Float", px, "Float", py, "Float", sg[1], "Float", sg[2], "Float", sg[3], "Float", sg[4], "Float", sg[5], "Float", sg[6], "UInt")
                        px := sg[5], py := sg[6]
                    }
                }
                DllCall("gdiplus\GdipClosePathFigure", "Ptr", path, "UInt")
                ; the eyes (holes: the path uses the alternate fill mode)
                DllCall("gdiplus\GdipAddPathEllipse", "Ptr", path, "Float", 5.8631, "Float", 10.4934, "Float", 4.3138, "Float", 4.8378, "UInt")
                DllCall("gdiplus\GdipAddPathEllipse", "Ptr", path, "Float", 13.8379, "Float", 10.4934, "Float", 4.3138, "Float", 4.8378, "UInt")

                brushBuffer := Buffer(A_PtrSize, 0)
                if (DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr", brushBuffer, "UInt") = 0) {
                    brush := NumGet(brushBuffer, 0, "Ptr")
                    DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", graphics, "Float", cx, "Float", cy, "Int", 0, "UInt")
                    DllCall("gdiplus\GdipScaleWorldTransform", "Ptr", graphics, "Float", sc, "Float", sc, "Int", 0, "UInt")
                    DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", graphics, "Float", -logoCX, "Float", -logoCY, "Int", 0, "UInt")
                    DllCall("gdiplus\GdipFillPath", "Ptr", graphics, "Ptr", brush, "Ptr", path, "UInt")
                    DllCall("gdiplus\GdipResetWorldTransform", "Ptr", graphics, "UInt")
                    DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush, "UInt")
                }
                DllCall("gdiplus\GdipDeletePath", "Ptr", path, "UInt")
            }

            ; Question mark (no circle) at the top-right corner of the logo, merged into it by a thin black gap
            DrawTosBadge(graphics, cx + 14.0, cy - 10.0, badgeArgb)

            ; click ripple: a thin ring that grows and fades out (same as the refresh button)
            if (tosRippleStart > 0) {
                rippleProgress := (A_TickCount - tosRippleStart) / tosRippleDuration
                if (rippleProgress < 1.0) {
                    rippleRadius := 16.0 + 8.0 * EaseOutCubic(rippleProgress)
                    rcx := cx + 3.5, rcy := cy - 2                       ; centre of the whole icon (logo + badge)
                    rippleAlpha := Round(150 * (1.0 - rippleProgress) ** 1.5)
                    ripplePenBuffer := Buffer(A_PtrSize, 0)
                    if (DllCall("gdiplus\GdipCreatePen1", "UInt", (rippleAlpha << 24) | 0xFFFFFF, "Float", 1.5, "Int", 2, "Ptr", ripplePenBuffer, "UInt") = 0) {
                        ripplePen := NumGet(ripplePenBuffer, 0, "Ptr")
                        DllCall("gdiplus\GdipDrawEllipse", "Ptr", graphics, "Ptr", ripplePen, "Float", rcx - rippleRadius, "Float", rcy - rippleRadius, "Float", rippleRadius * 2, "Float", rippleRadius * 2, "UInt")
                        DllCall("gdiplus\GdipDeletePen", "Ptr", ripplePen, "UInt")
                    }
                }
            }
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics, "UInt")
        }
    }
    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBitmap, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", bitmap)
    DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
    return 1
}

; Question mark (no circle): a clean geometric mark - a round hook that closes into a straight stem, and a round dot - in
; thick rounded strokes. It leans like an italic (slight shear) and is tilted a few degrees on top of that, which gives
; it a fast, modern look. A black outline stroke is drawn first and cuts a thin gap into the logo where they overlap (the
; window background is black), so mark and logo read as one icon.
DrawTosBadge(graphics, bx, by, argb) {
    gap := 2.2                      ; width of the black gap on each side of the mark
    lineW := 2.5                    ; stroke width of the mark
    ; local coordinates: origin = centre of the mark, y down
    DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", graphics, "Float", bx, "Float", by, "Int", 0, "UInt")
    DllCall("gdiplus\GdipRotateWorldTransform", "Ptr", graphics, "Float", 6, "Int", 0, "UInt")
    ; Italic lean to the right: shear matrix x' = x + (-0.2 * y) (GDI+ has no shear call, so multiply by a matrix)
    shearBuffer := Buffer(A_PtrSize, 0)
    if (DllCall("gdiplus\GdipCreateMatrix2", "Float", 1, "Float", 0, "Float", -0.2, "Float", 1, "Float", 0, "Float", 0, "Ptr", shearBuffer, "UInt") = 0) {
        shearMatrix := NumGet(shearBuffer, 0, "Ptr")
        DllCall("gdiplus\GdipMultiplyWorldTransform", "Ptr", graphics, "Ptr", shearMatrix, "Int", 0, "UInt")
        DllCall("gdiplus\GdipDeleteMatrix", "Ptr", shearMatrix, "UInt")
    }

    penBuffer := Buffer(A_PtrSize, 0)
    brushBuffer := Buffer(A_PtrSize, 0)
    arcR := 3.9, arcCy := -3.0                  ; the hook: 270 degrees, from the left over the top down to the bottom
    stemEndY := 2.9
    dotY := 6.5, dotR := 1.45
    Loop 2 {
        outline := (A_Index = 1)
        penColor := outline ? 0xFF000000 : argb
        penWidth := outline ? lineW + gap * 2 : lineW
        extra := outline ? gap : 0
        if (DllCall("gdiplus\GdipCreatePen1", "UInt", penColor, "Float", penWidth, "Int", 2, "Ptr", penBuffer, "UInt") = 0) {
            pen := NumGet(penBuffer, 0, "Ptr")
            DllCall("gdiplus\GdipSetPenStartCap", "Ptr", pen, "Int", 2, "UInt")
            DllCall("gdiplus\GdipSetPenEndCap", "Ptr", pen, "Int", 2, "UInt")
            DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", pen, "Int", 2, "UInt")
            DllCall("gdiplus\GdipDrawArc", "Ptr", graphics, "Ptr", pen, "Float", -arcR, "Float", arcCy - arcR, "Float", arcR * 2, "Float", arcR * 2, "Float", 180, "Float", 270, "UInt")
            DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", 0, "Float", arcCy + arcR, "Float", 0, "Float", stemEndY, "UInt")
            DllCall("gdiplus\GdipDeletePen", "Ptr", pen, "UInt")
        }
        if (DllCall("gdiplus\GdipCreateSolidFill", "UInt", penColor, "Ptr", brushBuffer, "UInt") = 0) {
            brush := NumGet(brushBuffer, 0, "Ptr")
            r := dotR + extra
            DllCall("gdiplus\GdipFillEllipse", "Ptr", graphics, "Ptr", brush, "Float", -r, "Float", dotY - r, "Float", r * 2, "Float", r * 2, "UInt")
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush, "UInt")
        }
    }
    DllCall("gdiplus\GdipResetWorldTransform", "Ptr", graphics, "UInt")
}

; White soft line: brightest and thickest (3 px) in the middle, fading smoothly to nothing at both ends, where it
; thins to a single faint row (like a blurred, tapered stroke). Painted pixel by pixel on the black background.
DrawRiskLine(drawItemStruct) {
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    targetHdc := NumGet(drawItemStruct, itemHwndOffset + A_PtrSize, "Ptr")
    rectOffset := itemHwndOffset + A_PtrSize * 2
    left := NumGet(drawItemStruct, rectOffset, "Int")
    top := NumGet(drawItemStruct, rectOffset + 4, "Int")
    width := NumGet(drawItemStruct, rectOffset + 8, "Int") - left
    height := NumGet(drawItemStruct, rectOffset + 12, "Int") - top
    if (width <= 0 || height <= 0 || !targetHdc)
        return 1
    memoryDc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", targetHdc, "Ptr")
    if (!memoryDc)
        return 1
    bmi := Buffer(40, 0)
    NumPut("UInt", 40, bmi, 0)
    NumPut("Int", width, bmi, 4)
    NumPut("Int", -height, bmi, 8)          ; top-down
    NumPut("UShort", 1, bmi, 12)
    NumPut("UShort", 32, bmi, 14)
    bits := 0
    dib := DllCall("Gdi32\CreateDIBSection", "Ptr", memoryDc, "Ptr", bmi, "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
    if (!dib || !bits) {
        DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
        return 1
    }
    oldBmp := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", dib, "Ptr")
    midRow := (height - 1) / 2
    Loop width {
        x := A_Index - 1
        u := Abs(((x + 0.5) / width) * 2 - 1)                 ; 0 in the middle, 1 at the ends
        prof := Cos(u * 1.5707963) ** 1.6                      ; smooth fade along the length
        Loop height {
            row := A_Index - 1
            if (Abs(row - midRow) < 0.6)
                inten := prof                                   ; centre row
            else
                inten := Max(0.0, (prof - 0.22) / 0.78) * 0.85   ; outer rows exist only near the middle (taper)
            v := Round(255 * Min(1.0, inten))
            NumPut("UInt", (v << 16) | (v << 8) | v, bits, (row * width + x) * 4)
        }
    }
    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBmp, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", dib)
    DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
    return 1
}

; ---- Popup title marquee (same engine as the status message and the dropdown titles) ----------------------------
; Movement style of the dropdown titles: slide to the end of the title, hold, jump back, pause; one pixel per
; marqueeFrameStep screen refreshes via MarqueeAdvance, driven by MarqueeMaster.
RiskTitleOwnerDraw(hwnd, itemHwnd, lParam) {
    global riskGui, riskTitleCtl, riskTitleActive
    if (riskTitleActive && IsObject(riskGui) && IsWindowValid(riskGui) && IsWindowValid(riskTitleCtl) && hwnd = riskGui.Hwnd && itemHwnd = riskTitleCtl.Hwnd)
        return DrawRiskTitle(lParam)
    return ""
}

FreeRiskTitleStrip() {
    global riskTitleStripDc, riskTitleStripBmp, riskTitleStripOld
    if (riskTitleStripDc) {
        DllCall("Gdi32\SelectObject", "Ptr", riskTitleStripDc, "Ptr", riskTitleStripOld, "Ptr")
        DllCall("Gdi32\DeleteObject", "Ptr", riskTitleStripBmp)
        DllCall("Gdi32\DeleteDC", "Ptr", riskTitleStripDc)
    }
    riskTitleStripDc := 0, riskTitleStripBmp := 0, riskTitleStripOld := 0
}

; The whole title (16 pt bold, white) is rendered ONCE off-screen; each frame only copies a window of it.
BuildRiskTitleStrip(refDc, height) {
    global riskTitleText, riskTitleTrackW, riskTitleInset, riskTitleCycleW
    global riskTitleStripDc, riskTitleStripBmp, riskTitleStripOld, riskTitleStripH, riskTitleStripDirty, riskTitleStripPhases
    FreeRiskTitleStrip()
    riskTitleStripDirty := false
    riskTitleStripPhases := 1
    stripW := Min(Max(riskTitleTrackW + 64, 64), 30000)
    ; Smooth mode: `phases` bands, band i = the title shifted left by i/phases px (see BuildSubpixelBands).
    phases := (riskTitleText != "" && riskTitleTrackW > 0) ? MarqueeChoosePhases(stripW, height) : 1
    dc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", refDc, "Ptr")
    if (!dc)
        return
    bmp := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", refDc, "Int", stripW, "Int", height * phases, "Ptr")
    if (!bmp && phases > 1) {
        phases := 1
        bmp := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", refDc, "Int", stripW, "Int", height, "Ptr")
    }
    if (!bmp) {
        DllCall("Gdi32\DeleteDC", "Ptr", dc)
        return
    }
    oldBmp := DllCall("Gdi32\SelectObject", "Ptr", dc, "Ptr", bmp, "Ptr")
    fullRect := Buffer(16, 0)
    NumPut("Int", stripW, fullRect, 8)
    NumPut("Int", height * phases, fullRect, 12)
    brush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00000000, "Ptr")
    DllCall("User32\FillRect", "Ptr", dc, "Ptr", fullRect, "Ptr", brush)
    DllCall("Gdi32\DeleteObject", "Ptr", brush)

    dpi := DllCall("Gdi32\GetDeviceCaps", "Ptr", refDc, "Int", 90)
    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(16 * dpi / 72), "Int", 0, "Int", 0, "Int", 0, "Int", 700, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", "Segoe UI", "Ptr")
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", dc, "Ptr", hFont, "Ptr")

    smoothOk := false
    if (phases > 1) {
        tm := Buffer(80, 0)
        DllCall("Gdi32\GetTextMetricsW", "Ptr", dc, "Ptr", tm)
        tmHeight := NumGet(tm, 0, "Int")
        ; one copy (dropdown style: no second copy), stretched to the GDI-measured width so the end-of-title stop lands on the same pixel
        smoothOk := BuildSubpixelBands(dc, stripW, height, phases, riskTitleText, 1, 0, riskTitleTrackW
            , "Segoe UI", Round(16 * dpi / 72), true, "FFFFFF", tmHeight)
        if (!smoothOk) {
            phases := 1
            NumPut("Int", height, fullRect, 12)
            brush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00000000, "Ptr")
            DllCall("User32\FillRect", "Ptr", dc, "Ptr", fullRect, "Ptr", brush)
            DllCall("Gdi32\DeleteObject", "Ptr", brush)
        }
    }
    if (!smoothOk) {
        DllCall("Gdi32\SetBkMode", "Ptr", dc, "Int", 1)
        DllCall("Gdi32\SetTextColor", "Ptr", dc, "UInt", 0x00FFFFFF)
        textRect := Buffer(16, 0)
        NumPut("Int", stripW, textRect, 8)
        NumPut("Int", height, textRect, 12)
        ; DT_SINGLELINE | DT_VCENTER | DT_NOCLIP | DT_NOPREFIX (same flags as the status marquee)
        ; the title is drawn ONCE (dropdown style: no second copy, the strip is just the title)
        NumPut("Int", 0, textRect, 0)
        DllCall("User32\DrawTextW", "Ptr", dc, "Str", riskTitleText, "Int", -1, "Ptr", textRect, "UInt", 0x00000B24)
    }
    DllCall("Gdi32\SelectObject", "Ptr", dc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)
    riskTitleStripDc := dc, riskTitleStripBmp := bmp, riskTitleStripOld := oldBmp, riskTitleStripH := height
    riskTitleStripPhases := phases
}

DrawRiskTitle(drawItemStruct) {
    global riskTitleRenderedX, riskTitleStripDc, riskTitleStripH, riskTitleStripDirty, riskTitleStripPhases, riskTitleRenderedPhase
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    targetHdc := NumGet(drawItemStruct, itemHwndOffset + A_PtrSize, "Ptr")
    rectOffset := itemHwndOffset + A_PtrSize * 2
    left := NumGet(drawItemStruct, rectOffset, "Int")
    top := NumGet(drawItemStruct, rectOffset + 4, "Int")
    width := NumGet(drawItemStruct, rectOffset + 8, "Int") - left
    height := NumGet(drawItemStruct, rectOffset + 12, "Int") - top
    if (width <= 0 || height <= 0 || !targetHdc)
        return 1
    if (riskTitleStripDirty || riskTitleStripH != height || !riskTitleStripDc)
        BuildRiskTitleStrip(targetHdc, height)
    if (riskTitleStripDc) {
        srcX := Max(0, -riskTitleRenderedX)
        srcY := 0
        if (riskTitleStripPhases > 1) {
            srcX += 1                           ; smooth strip: text origin is 1 px in; pick the band for the current sub-pixel shift
            srcY := Min(Max(riskTitleRenderedPhase, 0), riskTitleStripPhases - 1) * height
        }
        DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", riskTitleStripDc, "Int", srcX, "Int", srcY, "UInt", 0x00CC0020)
    }
    return 1
}

; Restarts the title from its beginning with the usual hold before it starts moving.
RiskTitleRestart() {
    global riskTitleActive, riskTitleOffset, riskTitleFrames, riskTitleRenderedX, riskTitleLastTick, riskTitlePauseUntil, riskTitleCtl
    global riskTitleRenderedPhase
    if (!riskTitleActive)
        return
    riskTitleOffset := 0.0, riskTitleFrames := 0, riskTitleRenderedX := 0, riskTitleRenderedPhase := 0
    riskTitleLastTick := FrameStamp()
    riskTitlePauseUntil := NowMs() + MarqueePauseMs()
    if (IsWindowValid(riskTitleCtl)) {
        DllCall("User32\InvalidateRect", "Ptr", riskTitleCtl.Hwnd, "Ptr", 0, "Int", false)
        DllCall("User32\UpdateWindow", "Ptr", riskTitleCtl.Hwnd)
    }
}

UpdateRiskTitleMarquee() {
    global isExiting, mainGui, isWindowVisible, riskViewActive, riskViewBusy, riskTitleActive, riskTitleCtl
    global riskTitleOffset, riskTitleLastTick, riskTitlePauseUntil, riskTitleOverflowW, riskTitleCycleW, riskTitleRenderedX, riskTitleFrames
    global riskTitleStripPhases, riskTitleRenderedPhase
    if (isExiting || !riskViewActive || riskViewBusy || !riskTitleActive || riskTitleCycleW <= 0 || !IsWindowValid(riskTitleCtl))
        return
    if (!isWindowVisible || DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd))
        return
    ; holds at the end of the title (the hold position is a whole pixel, so it lands exactly as before)
    if (!MarqueeTick(&riskTitleOffset, &riskTitleFrames, &riskTitleLastTick, &riskTitlePauseUntil, &riskTitleRenderedX, &riskTitleRenderedPhase
        , riskTitleCycleW, riskTitleOverflowW, riskTitleStripPhases))
        return
    ; Direct paint (own pixels only, no window-tree re-print); falls back to a normal repaint.
    if (PaintControlDirect(riskTitleCtl, DrawRiskTitle))
        return
    DllCall("User32\InvalidateRect", "Ptr", riskTitleCtl.Hwnd, "Ptr", 0, "Int", false)
    DllCall("User32\UpdateWindow", "Ptr", riskTitleCtl.Hwnd)
}

; Hides everything that belongs to the normal view (search box, Start button, status line).
HideMainWidgetsForRisk() {
    global frameGui, selectGui, actionGui, statusDot, statusText, statusMarqueeGui, marqueeViewportNeedsShow, appTagline
    if (IsWindowValid(appTagline))
        appTagline.Opt("+Hidden")       ; the 3 px line takes the tagline's place
    for g in [frameGui, selectGui, actionGui] {
        if (IsWindowValid(g) && DllCall("User32\IsWindowVisible", "Ptr", g.Hwnd, "Int"))
            g.Hide()
    }
    if (IsWindowValid(statusDot))
        statusDot.Opt("+Hidden")
    if (IsWindowValid(statusText))
        statusText.Opt("+Hidden")
    if (IsWindowValid(statusMarqueeGui)) {
        if (DllCall("User32\IsWindowVisible", "Ptr", statusMarqueeGui.Hwnd, "Int"))
            statusMarqueeGui.Hide()
        marqueeViewportNeedsShow := true
    }
}

PositionRiskTosIcon() {
    global riskTosGui, riskTosCtl, versionText, updateBtn, updateSep
    if (!IsWindowValid(riskTosGui) || !IsWindowValid(riskTosCtl))
        return
    if (IsWindowValid(versionText))
        versionText.Opt("+Hidden")
    if (IsWindowValid(updateBtn))
        updateBtn.Opt("+Hidden")                  ; "version | Update" is replaced by the terms-of-service icon in the warning view
    if (IsWindowValid(updateSep))
        updateSep.Opt("+Hidden")
    static lastTosHwnd := 0
    if (lastTosHwnd = riskTosGui.Hwnd && DllCall("User32\IsWindowVisible", "Ptr", riskTosGui.Hwnd, "Int")) {
        DllCall("User32\SetWindowPos", "Ptr", riskTosGui.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")
        return
    }
    lastTosHwnd := riskTosGui.Hwnd
    riskTosGui.Show("NA x12 y0 w58 h56")
    riskTosCtl.Move(0, 0, 58, 56)
    DllCall("User32\SetWindowPos", "Ptr", riskTosGui.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")
    DllCall("User32\InvalidateRect", "Ptr", riskTosCtl.Hwnd, "Ptr", 0, "Int", false)
}

PositionRiskView(mainWidth, mainHeight) {
    global riskGui
    EnsureRiskView(mainWidth, mainHeight)
    HideMainWidgetsForRisk()
    riskTop := RiskViewTopY()
    static lastRiskKey := ""
    riskKey := Format("{}|{}|{}|{}", riskGui.Hwnd, riskTop, mainWidth, mainHeight)
    if (riskKey != lastRiskKey || !DllCall("User32\IsWindowVisible", "Ptr", riskGui.Hwnd, "Int")) {
        riskGui.Show(Format("NA x0 y{} w{} h{}", riskTop, mainWidth, mainHeight - riskTop))
        lastRiskKey := riskKey
    }
    PositionRiskLine(mainWidth)
    PositionRiskTosIcon()
    ; SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE, HWND_TOP: always above the hidden normal-view controls
    DllCall("User32\SetWindowPos", "Ptr", riskGui.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")
}

; Short fade of the whole window used for the switch (same easing as the window's own show / hide animation).
; Nothing heavy may happen while the window is partly transparent: the new view is built and fully painted while the
; window is still invisible (alpha 0), see PrepaintMainWindow, so every frame of the fade is only an opacity change.
RiskViewFade(fadeIn, softPaint := false, lateWork := "") {
    global isExiting, animationDuration, fadeInTail, isMarqueeActive, marqueeLastTick
    fadeInTail := false
    lateDone := false
    ; Everything heavy happens BEFORE the clock starts, while the window is still fully transparent. Repainting controls inside
    ; the loop (it used to, at the start and halfway) froze the fade for a moment (stutter) and the plain text controls, which
    ; erase their background before they draw the text, flashed while the window was already partly visible.
    if (fadeIn && softPaint) {
        ; POPUP-BUTTONS-LATE FIX: the window was still at opacity 0 here, and DWM does not take the picture of a fully transparent
        ; layered window. The buttons (separate child windows, owner-drawn) and their labels were therefore painted into nothing
        ; and only appeared when something repainted them later (the -80 ms timer, a hover, ...) = buttons / text shown late.
        ; Opacity 1/255 is invisible, but forces DWM to capture the finished picture NOW, before the first visible fade step.
        SetWindowOpacity(1)
        RiskSoftPaint()
        DllCall("Dwmapi\DwmFlush", "Int")
        DllCall("Dwmapi\DwmFlush", "Int")
    }
    ; FADE-IN FIRST-FRAME FIX: when the normal view comes back (softPaint = false) it was repainted while the window was at opacity 0,
    ; and the compositor does not really draw a fully transparent window. So its first real composition of the whole window happened
    ; during the first visible frame of the fade: that frame took longer than one refresh and the status line, counting real
    ; refreshes, jumped ahead once = the single shake at the start of the fade-in. Opacity 1/255 is invisible, but makes the
    ; compositor take the finished picture NOW, before the fade clock starts.
    if (fadeIn && !softPaint) {
        SetWindowOpacity(1)
        DllCall("Dwmapi\DwmFlush", "Int")
        DllCall("Dwmapi\DwmFlush", "Int")
    }
    ; FADE-SHAKE FIX (1/2): resync the marquee's refresh counter AFTER all of the above (MarqueeMaster is parked while a fade runs,
    ; so the counter is stale). Without this its first update counted every refresh since the last frame and jumped ahead.
    if (isMarqueeActive)
        marqueeLastTick := FrameStamp()
    startMs := NowMs(), duration := animationDuration     ; same duration as the window's own show / hide fade
    Loop {
        progress := Min((NowMs() - startMs) / duration, 1)
        eased := (progress < 0.5) ? (4 * progress ** 3) : (1 - (-2 * progress + 2) ** 3 / 2)
        SetWindowOpacity(Round(255 * (fadeIn ? eased : 1 - eased)))
        if (fadeIn && progress >= 0.6)
            fadeInTail := true                 ; eased >= 0.65: the window is visibly there, presses are kept from now on
        ; lateWork (fade-out only): heavy work that must not freeze the scrolling status line is run once the window is at <= ~3 %
        ; opacity (progress 0.8 of the fade-out), i.e. when nobody can see a hold any more.
        if (!fadeIn && lateWork && !lateDone && progress >= 0.8 && progress < 1 && !isExiting) {
            lateDone := true
            lateWork()
            continue                           ; the clock kept running: re-evaluate (the fade is practically over)
        }
        if (progress >= 1 || isExiting)
            break
        ; one opacity step per real display refresh (DwmFlush paces it); Sleep(8) is only ~15 ms granular, which made the steps uneven
        flushed := (DllCall("Dwmapi\DwmFlush", "Int") = 0)
        ; FADE-SHAKE FIX (2/2): the status line is drawn RIGHT AFTER the refresh, as the very first thing of the frame (its cost is
        ; constant). It used to be drawn after the window-opacity update, whose cost varies (several layered windows are
        ; re-blended); when that ran long the text landed after the next refresh, so some frames got two steps and some none = shake.
        UpdateMarquee()                        ; status line keeps scrolling during the fade (one step per refresh, same pacing)
        if (flushed)
            Sleep(-1)
        else
            Sleep(8)
    }
    if (fadeIn && !isExiting)
        SetWindowOpacity(255)
}

; Paints the whole main window (all children) right now, while it is still fully transparent, so the fade-in does not
; have to paint anything.
PrepaintMainWindow() {
    global mainGui
    if (!IsWindowValid(mainGui))
        return
    ; RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN | RDW_UPDATENOW
    DllCall("User32\RedrawWindow", "Ptr", mainGui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0185, "Int")
}

ShowRpcRiskView(cleanName, appId) {
    global mainGui, isExiting, riskViewActive, riskViewBusy, riskGui, riskPressedName, riskKeyHeld, riskWarnSign
    global riskPendingName, riskPendingAppId, riskDeferredStatus, riskTitleActive, riskTitleCtl, riskLineGui, riskLineCtl, riskTosGui, riskTosCtl
    global riskBtnRegistry, riskPrevDown, isKeyActionDown, enterBuffered, riskTitleLastTick, riskTitlePauseUntil, riskFadeEndTick, riskBuildDone
    if (isExiting || riskViewActive || riskViewBusy || !IsWindowValid(mainGui))
        return
    try WinGetPos(,, &mainWidth, &mainHeight, "ahk_id " mainGui.Hwnd)
    catch
        return
    riskViewBusy := true
    enterBuffered := false
    try {
        riskPendingName := cleanName, riskPendingAppId := appId, riskDeferredStatus := ""
        riskPressedName := "", riskKeyHeld := false, riskPrevDown := GetKeyState("LButton", "P")
        ; BUILD-STALL FIX: building the warning view (text measuring, ink measuring, dozens of controls, bitmaps) takes a long time on
        ; the one script thread. It used to run HERE, while the main window was still fully visible, so the scrolling status line
        ; froze for that whole time right after the click on Start. It now runs at the very end of the fade-out (window at ~3 %),
        ; or right after it, so the line keeps scrolling smoothly through the visible part of the fade.
        riskBuildDone := false
        buildFn := () => RiskBuildView(mainWidth, mainHeight)
        StatusFadeOverlayOn(255)
        RiskViewFade(false, false, buildFn)
        StatusFadeOverlayOff(false)
        if (!riskBuildDone && !isExiting)
            RiskBuildView(mainWidth, mainHeight)
        riskViewActive := true
        SetWindowOpacity(1)               ; 1/255 = invisible, but DWM only captures child-window paints of a window that is not fully transparent
        PositionRiskView(mainWidth, mainHeight)
        PrepaintMainWindow()
        RiskForcePaint()                  ; window is practically transparent here: the full (erasing) paint is invisible
        DllCall("Dwmapi\DwmFlush", "Int")
        DllCall("Dwmapi\DwmFlush", "Int")
        RiskTitleRestart()
        FocusMainWindowAfterFade()        ; focused BEFORE it becomes visible, so Enter / Escape work from the first frame
        RiskViewFade(true, true)          ; repaints WITHOUT erasing during the fade, so nothing can flash
        RiskSoftPaint()
        FocusMainWindowAfterFade()
    } finally {
        StatusFadeOverlayOff(!riskViewActive)
        riskViewBusy := false
        riskFadeEndTick := A_TickCount
        ; Whatever happened above, a visible warning must always have its timers (no timer = dead buttons) and a visible window.
        if (riskViewActive) {
            if (riskTitleActive) {              ; the title's hold starts now, when the window is fully there (not before the fade)
                riskTitleLastTick := FrameStamp()
                riskTitlePauseUntil := NowMs() + MarqueePauseMs()
            }
            SetTimer(RiskViewTick, 15)
            if (!dotBlinkTimerRunning)
                SetTimer(UpdateWarnSignBlink, 80)   ; fallback only: normally the dot timer drives the sign
            RiskSoftPaint()                     ; buttons + labels are re-sent to DWM the moment the window is fully there
            SetTimer(RiskSoftPaint, -40)
            SetTimer(() => RiskSoftPaint(), -160)   ; safety net only
        }
        isKeyActionDown := false              ; presses made during the fade must not leave a half-pressed state behind
        if (!isExiting) {
            SetWindowOpacity(255)
            FocusMainWindowAfterFade()
            SetTimer(FocusMainWindowAfterFade, -40)
            SetTimer(FlushBufferedEnter, -1)    ; re-assert: Enter must work from the very first frame after the fade
        }
    }
}

; Builds the warning view for the pending title (the heavy part of ShowRpcRiskView, see BUILD-STALL FIX there).
RiskBuildView(mainWidth, mainHeight) {
    global riskBuildDone, riskTitleActive, riskTitleCtl, riskLineGui, riskLineCtl, riskTosGui, riskTosCtl, riskGui, riskWarnSign, riskBtnRegistry
    if (riskBuildDone)
        return
    riskBuildDone := true
    ; The message contains the title and its Discord ID, so the view is rebuilt for every title.
    FreeRiskTitleStrip()
    riskTitleActive := false, riskTitleCtl := ""
    if (IsWindowValid(riskLineGui))
        try riskLineGui.Destroy()
    riskLineGui := "", riskLineCtl := ""
    if (IsWindowValid(riskTosGui))
        try riskTosGui.Destroy()
    riskTosGui := "", riskTosCtl := ""
    if (IsWindowValid(riskGui))
        try riskGui.Destroy()
    riskGui := "", riskWarnSign := ""
    FreeRiskIcon()
    riskBtnRegistry.Clear()
    EnsureRiskView(mainWidth, mainHeight)
}

; Switches the main window back to its normal view.
HideRpcRiskView() {
    global statusFadeInOverlay
    global riskFadeEndTick
    global mainGui, isExiting, riskViewActive, riskViewBusy, riskGui, riskDeferredStatus, riskKeyHeld, lastToggleDoneTick, isKeyActionDown, enterBuffered
    global frameGui, selectGui, actionGui, statusDot, statusText, isMarqueeActive, marqueeViewportNeedsShow
    global appTagline, riskLineGui, riskTitleActive, riskTosGui, versionText, updateBtn, updateSep
    if (!riskViewActive)
        return
    riskViewBusy := true
    enterBuffered := false
    try {
        SetTimer(RiskViewTick, 0)
        SetTimer(UpdateWarnSignBlink, 0)
        riskKeyHeld := false
        RiskViewFade(false)
        DbgLog("continue: fade-out finished")
        riskViewActive := false
        riskTitleActive := false
        FreeRiskTitleStrip()
        if (IsWindowValid(riskGui))
            riskGui.Hide()
        if (IsWindowValid(riskLineGui))
            riskLineGui.Hide()
        TosResetState()
        if (IsWindowValid(riskTosGui))
            riskTosGui.Hide()
        if (IsWindowValid(versionText))
            versionText.Opt("-Hidden")
        if (IsWindowValid(updateBtn))
            updateBtn.Opt("-Hidden")
        if (IsWindowValid(updateSep))
            updateSep.Opt("-Hidden")
        if (IsWindowValid(appTagline))
            appTagline.Opt("-Hidden")
        frameGui.Show("NA")
        selectGui.Show("NA")
        actionGui.Show("NA")
        if (IsWindowValid(statusDot))
            statusDot.Opt("-Hidden")
        if (isMarqueeActive)
            marqueeViewportNeedsShow := true
        else if (IsWindowValid(statusText))
            statusText.Opt("-Hidden")
        PositionChildWindows()
        PositionStatusControls()
        if (IsObject(riskDeferredStatus)) {
            pending := riskDeferredStatus
            riskDeferredStatus := ""
            SetStatus(pending[1], pending[2])
            DbgLog("continue: Active status built")
        }
        RepaintActionButtonNoErase()
        RepaintRefreshButtonNoErase()
        PrepaintMainWindow()
        FocusMainWindowAfterFade()
        if (statusFadeInOverlay)
            StatusFadeOverlayOn(0)
        RiskViewFade(true)
        StatusFadeOverlayOff(true)
        FocusMainWindowAfterFade()
    } finally {
        StatusFadeOverlayOff(true)
        riskViewBusy := false
        riskFadeEndTick := A_TickCount
        riskViewActive := false
        ; The frame driver was parked for the whole switch: catch the status line up with the display clock RIGHT NOW and wake the
        ; driver with a posted message, instead of waiting for its next 8 ms timer tick (that wait was a visible hold + jump).
        if (!isExiting) {
            try UpdateMarquee()
            DllCall("User32\PostMessageW", "Ptr", A_ScriptHwnd, "UInt", 0x8001, "Ptr", 0, "Ptr", 0, "Int")
        }
        ; The warning is closed: Enter / click works on Start / Stop immediately (no cool-down after the fade).
        ; Presses made DURING the fade were already dropped (riskViewBusy / actionLocked).
        lastToggleDoneTick := 0
        isKeyActionDown := false
        if (!isExiting) {
            SetWindowOpacity(255)
            FocusMainWindowAfterFade()
            SetTimer(FocusMainWindowAfterFade, -40)
            SetTimer(FlushBufferedEnter, -1)
        }
    }
}

; After a view switch (fade-in of the warning, fade-out back to the normal view) the main window itself is the focused,
; active window, so Enter / Escape / the keyboard hotkeys work at once and no old control keeps the focus.
FocusMainWindowAfterFade() {
    global mainGui, isExiting, isWindowVisible, isGameSearchFocused
    if (isExiting || !IsWindowValid(mainGui))
        return
    if (IsSet(isWindowVisible) && !isWindowVisible)
        return
    isGameSearchFocused := false
    hwnd := mainGui.Hwnd
    try {
        if (DllCall("User32\GetForegroundWindow", "Ptr") != hwnd && (A_TimeIdlePhysical < 4000 || WinActive("ahk_pid " ProcessExist()))) {
            ; Windows only lets a window take the foreground from another one when the two input queues are joined for a
            ; moment; without this the window stayed un-focused until it was clicked.
            fg := DllCall("User32\GetForegroundWindow", "Ptr")
            myThread := DllCall("Kernel32\GetCurrentThreadId", "UInt")
            fgThread := fg ? DllCall("User32\GetWindowThreadProcessId", "Ptr", fg, "Ptr", 0, "UInt") : 0
            attached := (fgThread && fgThread != myThread) ? DllCall("User32\AttachThreadInput", "UInt", myThread, "UInt", fgThread, "Int", 1, "Int") : false
            DllCall("User32\SetForegroundWindow", "Ptr", hwnd)
            if (attached)
                DllCall("User32\AttachThreadInput", "UInt", myThread, "UInt", fgThread, "Int", 0)
        }
    }
    DllCall("User32\SetFocus", "Ptr", hwnd)
}

; Runs the Enter that was pressed during the end of a fade-in, right after the view switch is completely finished.
FlushBufferedEnter() {
    global enterBuffered, fadeInTail, riskViewBusy, actionLocked, isExiting
    fadeInTail := false
    if (!enterBuffered || isExiting)
        return
    if (riskViewBusy || actionLocked) {        ; the caller of the switch has not unlocked yet: try again in a moment
        SetTimer(FlushBufferedEnter, -5)
        return
    }
    enterBuffered := false
    if (!IsMyGuiActive())
        return
    TriggerActionDown()
    if (!GetKeyState("Enter", "P") && !GetKeyState("NumpadEnter", "P"))
        TriggerActionUp()                      ; the key was already released: finish the press at once
}

DeferRiskStatus(text, type) {
    global riskDeferredStatus
    riskDeferredStatus := [text, type]
}

RpcRiskAccept(*) {
    global riskViewActive, riskViewBusy, riskPendingName, riskPendingAppId
    if (!riskViewActive || riskViewBusy || connLost)
        return                                 ; connection lost: Continue is frozen
    DbgLog("continue: Accept pressed")
    global actionLocked, togglePending
    name := riskPendingName, appId := riskPendingAppId
    ; While the warning fades out and Discord is being connected, Start / Stop presses are ignored (they used to run on top of
    ; the connection and break it); everything pressed before that has been handled already.
    ; Only the fade-out is locked. The connection itself runs UNLOCKED: a Start / Stop press while connecting cancels it
    ; (before, the buttons were dead for as long as Discord took to answer, sometimes many seconds).
    actionLocked := true
    try {
        RpcBeginConnect(name, appId)      ; Active / Stop is shown at once; the connection runs in the background (also during the fade)
        DbgLog("continue: connection started, closing warning")
        HideRpcRiskView()
        DbgLog("continue: warning closed, main view visible")
    } finally {
        actionLocked := false
        togglePending := 0
    }
}

RpcRiskDecline(*) {
    global riskViewActive, riskViewBusy
    if (!riskViewActive || riskViewBusy)
        return
    HideRpcRiskView()
}

#HotIf IsSet(riskViewActive) && riskViewActive && IsMyGuiActive()
Escape::RpcRiskDecline()
#HotIf

; Starts the Rich Presence session (called after "Continue"). The window switches to Active / Stop IMMEDIATELY and the
; connection to Discord is made in the background (RpcConnectTick, short attempts every 30 ms), so a slow or busy
; Discord never makes the button wait or look stuck. Only if Discord cannot be reached for 30 s the state is rolled back.
RpcBeginConnect(cleanName, appId) {
    global isRunning, lastHover, rpcConnecting, rpcCancel, rpcConnectName, rpcConnectAppId, rpcConnectStart, lastToggleDoneTick
    global rpcConnPhase, connLastStart
    connLastStart := ["rpc", cleanName, appId]                         ; used to start it again after a connection loss
    StopDiscordRichPresence()              ; also drops a half-finished attempt of an earlier connect
    rpcCancel := false
    rpcConnectName := cleanName, rpcConnectAppId := appId, rpcConnectStart := A_TickCount
    rpcConnPhase := 0
    rpcConnecting := true
    isRunning := true
    SetActionLabel("Stop")
    SetActionColor("B42318")
    SetStatus("Active: '" cleanName "' is shown through Discord Rich Presence.", "running")
    SetTimer(MonitorProcess, 1000)
    RepaintActionButtonNoErase(), lastHover := -1
    UpdateButtonHover()
    lastToggleDoneTick := A_TickCount
    SetTimer(RpcConnectTick, -1)           ; the connection starts NOW, before the warning has even finished fading out
}

FinishRichPresenceStart(cleanName, appId) {
    RpcBeginConnect(cleanName, appId)
}

; One more SET_ACTIVITY about 2 s after connecting, with the SAME start time (the timer on the profile does not restart).
; Only if the very same connection is still the active one. Discord's answer is read and ignored by RpcKeepAlive.
RpcResendActivity() {
    global rpcPipe, rpcResendHandle, rpcStartUnix, isRunning, isExiting
    if (isExiting || !isRunning || !rpcPipe || rpcPipe != rpcResendHandle || !rpcStartUnix)
        return
    nonce := "rs" A_TickCount "x" Random(1000, 9999)
    payload := '{"cmd":"SET_ACTIVITY","args":{"pid":' DllCall("GetCurrentProcessId") ',"activity":{"instance":false,"timestamps":{"start":' rpcStartUnix '}}},"nonce":"' nonce '"}'
    RpcWriteFrame(rpcPipe, 1, payload)
}

; Closes the handle of a connection attempt that is still in progress (no-op when there is none).
RpcConnAbort() {
    global rpcConnHandle, rpcConnPhase
    if (rpcConnHandle) {
        DllCall("CloseHandle", "Ptr", rpcConnHandle)
        rpcConnHandle := 0
    }
    rpcConnPhase := 0
}

; Background connection to Discord as a NON-BLOCKING state machine. Every tick only does work that is ready right now
; (open pipe / write one frame / read the frames that already arrived) and returns within about a millisecond, then
; re-arms itself. It used to run the whole handshake (WaitNamedPipe, Sleep(1) read loops, 2.5 s deadlines) inside ONE
; timer call; that timer fired in the middle of the warning's fade animation, the single script thread stayed blocked for
; seconds with the window transparent and un-pumped, and Windows hid it (no window, no taskbar button) until it finished.
;   phase 0: open a discord-ipc-N pipe and send HANDSHAKE
;   phase 1: wait for READY, then send SET_ACTIVITY
;   phase 2: wait for the answer to SET_ACTIVITY -> connected
RpcConnectTick() {
    global isRunning, lastHover, rpcConnecting, rpcCancel, rpcPipe, rpcLastError, rpcConnectName, rpcConnectAppId, rpcConnectStart, isExiting
    global rpcConnHandle, rpcConnPhase, rpcConnPhaseStart, rpcConnNonce, rpcLastStopTick, rpcStartUnix, rpcResendHandle
    if (!rpcConnecting) {
        RpcConnAbort()
        return
    }
    if (isExiting || rpcCancel || !isRunning) {
        RpcConnAbort()
        rpcConnecting := false
        return
    }
    delay := 4
    failed := false
    if (rpcConnPhase = 0 && A_TickCount - rpcLastStopTick < 400) {
        SetTimer(RpcConnectTick, -(400 - (A_TickCount - rpcLastStopTick) + 5))   ; let Discord finish closing the previous connection first
        return
    }
    if (rpcConnPhase = 0) {
        h := RpcOpenPipe(true)
        if (h) {
            if (RpcWriteFrame(h, 0, '{"v":1,"client_id":"' rpcConnectAppId '"}')) {
                rpcConnHandle := h, rpcConnPhase := 1, rpcConnPhaseStart := A_TickCount
            } else {
                DllCall("CloseHandle", "Ptr", h)
                failed := true
            }
        } else {
            rpcLastError := "Discord's IPC pipe was not found (is the Discord desktop app running and logged in?)."
            delay := 25
        }
    } else {
        Loop 12 {                          ; handle every frame that is already waiting, never wait for one
            reply := RpcReadFrame(rpcConnHandle, 0)
            if (!IsObject(reply)) {
                if (reply != "")           ; -1: the pipe broke
                    failed := true
                break
            }
            op := reply["op"], data := reply["data"]
            if (op = 2) {
                rpcLastError := (rpcConnPhase = 1) ? "Discord did not accept the application id." : "Discord rejected the connection."
                failed := true
                break
            }
            if (op = 3) {                  ; PING -> PONG
                RpcWriteFrame(rpcConnHandle, 4, data)
                continue
            }
            if (rpcConnPhase = 1) {
                if (InStr(data, '"READY"')) {
                    startUnix := DateDiff(A_NowUTC, "19700101000000", "Seconds")
                    rpcStartUnix := startUnix
                    rpcConnNonce := "rp" A_TickCount "x" Random(1000, 9999)
                    payload := '{"cmd":"SET_ACTIVITY","args":{"pid":' DllCall("GetCurrentProcessId") ',"activity":{"instance":false,"timestamps":{"start":' startUnix '}}},"nonce":"' rpcConnNonce '"}'
                    if (!RpcWriteFrame(rpcConnHandle, 1, payload)) {
                        failed := true
                        break
                    }
                    rpcConnPhase := 2, rpcConnPhaseStart := A_TickCount
                }
            } else {
                if (!InStr(data, rpcConnNonce)) {
                    if (InStr(data, '"evt":"ERROR"')) {
                        rpcLastError := "Discord rejected the connection."
                        failed := true
                        break
                    }
                    continue               ; some other event, not the answer to our request
                }
                if (InStr(data, '"ERROR"')) {
                    rpcLastError := "Discord rejected the activity."
                    failed := true
                    break
                }
                DbgLog("rpc: Discord confirmed the activity")
                rpcPipe := rpcConnHandle   ; connected
                rpcConnHandle := 0, rpcConnPhase := 0
                rpcConnecting := false
                rpcResendHandle := rpcPipe
                SetTimer(RpcResendActivity, -2000)   ; Discord sometimes drops the first update (rate limit / race): send it once more, same start time
                return
            }
        }
        if (!failed && A_TickCount - rpcConnPhaseStart > 2500) {
            rpcLastError := "Discord did not answer the handshake."
            failed := true
        }
    }
    if (failed) {
        RpcConnAbort()                     ; next tick starts a clean attempt (Discord needs a moment to release the pipe)
        delay := 40
    }
    if (A_TickCount - rpcConnectStart > 30000) {
        RpcConnAbort()
        rpcConnecting := false
        isRunning := false
        SetActionLabel("Start")
        SetActionColor("208A4E")
        RepaintActionButtonNoErase(), lastHover := -1
        SetStatus("System Error: Could not connect '" rpcConnectName "' to Discord. " rpcLastError, "error")
        UpdateButtonHover()
        return
    }
    SetTimer(RpcConnectTick, -delay)
}

; Enter / NumpadEnter pressed in the warning: presses "Continue" exactly like Enter presses the Start button
; (pressed colour + shrink now; on release hover colour, spring back, then the action).
RiskKeyDown() {
    global riskViewActive, riskViewBusy, riskBtnAccept, riskPressedName, riskBtnAnimating, riskKeyHeld, riskKeyCancel
    if (riskKeyHeld && !riskBtnAnimating && riskPressedName = "")
        riskKeyHeld := false                   ; stale: nothing is pressed any more
    if (connLost)
        return                                 ; connection lost: Continue is frozen (no press, no animation)
    if (riskKeyHeld || !riskViewActive || riskViewBusy || riskBtnAnimating || riskPressedName != "")
        return
    if (!IsObject(riskBtnAccept) || !IsWindowValid(riskBtnAccept.gui))
        return
    riskKeyHeld := true
    riskKeyCancel := false
    riskPressedName := "accept"
    try {
        SetRiskBtnColor(riskBtnAccept, riskBtnAccept.pressed)
        AnimateRiskButton(riskBtnAccept, true)
    } catch {
        riskKeyHeld := false, riskPressedName := ""       ; never leave the warning stuck in a half-pressed state
    }
}

; The warning sign blinks with the very same tone cycle and timing as the status dot (UpdateDotBlink, 80 ms steps).
UpdateWarnSignBlink(toneIndex := 0) {
    global riskWarnSign, riskWarnBlinkStep, riskWarnBmps, riskWarnShown, riskViewActive, isExiting
    ; No "busy" gate: the sign keeps stepping in time with the dot during the fade-in too (a swap of a tiny bitmap is
    ; cheap). Freezing it while fading made it jump to the dot's step afterwards, which looked like a stutter.
    if (isExiting || !riskViewActive || !IsWindowValid(riskWarnSign) || !riskWarnBmps.Length)
        return
    ; Called by UpdateDotBlink with the dot's own tone index, so both are always on the same step. Without an index
    ; (fallback timer) it counts on its own.
    if (!toneIndex) {
        toneIndex := Mod(riskWarnBlinkStep, riskWarnBmps.Length) + 1
        riskWarnBlinkStep++
    }
    toneIndex := Min(toneIndex, riskWarnBmps.Length)
    if (toneIndex = riskWarnShown)
        return
    riskWarnShown := toneIndex
    ; Repaint right now, WITHOUT erasing, and without involving the composited window tree: only the sign's own pixels are
    ; touched (same blink-hitch fix as the status dot). RedrawWindow stays as the fallback.
    bmp := riskWarnBmps[toneIndex]
    if (PaintControlDirect(riskWarnSign, (fake) => DrawBitmapItem(fake, bmp)))
        return
    DllCall("User32\RedrawWindow", "Ptr", riskWarnSign.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0101, "Int")
}

; The 12 amber steps of the status dot (same list as UpdateDotBlink uses for amber).
GetWarnTones() {
    return ["F2A900", "D79500", "BD8200", "A36F00", "895C00", "6F4900", "553600", "6F4900", "895C00", "A36F00", "BD8200", "D79500"]
}

FreeWarnBitmaps() {
    global riskWarnBmps
    for hbm in riskWarnBmps
        DllCall("Gdi32\DeleteObject", "Ptr", hbm)
    riskWarnBmps := []
}

; Draws the warning sign (solid triangle, black exclamation mark cut out of it) once at 8x size, shrinks it with a box
; filter (smooth edges) and returns one HBITMAP per colour step: pixel = tone * coverage on black.
BuildWarnSignBitmaps(W, H) {
    bmps := []
    S := 8, Ws := W * S, Hs := H * S
    hdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
    memDc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", hdc, "Ptr")
    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0), NumPut("Int", Ws, bi, 4), NumPut("Int", -Hs, bi, 8), NumPut("UShort", 1, bi, 12), NumPut("UShort", 32, bi, 14)
    bits := 0
    big := DllCall("Gdi32\CreateDIBSection", "Ptr", memDc, "Ptr", bi, "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
    if (big && bits) {
        oldBmp := DllCall("Gdi32\SelectObject", "Ptr", memDc, "Ptr", big, "Ptr")
        whiteBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0xFFFFFF, "Ptr")
        blackBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x000000, "Ptr")
        nullPen := DllCall("Gdi32\GetStockObject", "Int", 8, "Ptr")
        oldPen := DllCall("Gdi32\SelectObject", "Ptr", memDc, "Ptr", nullPen, "Ptr")
        oldBrush := DllCall("Gdi32\SelectObject", "Ptr", memDc, "Ptr", whiteBrush, "Ptr")
        pts := Buffer(24, 0)
        NumPut("Int", Ws // 2, "Int", 0, "Int", Ws, "Int", Hs, "Int", 0, "Int", Hs, pts)
        DllCall("Gdi32\Polygon", "Ptr", memDc, "Ptr", pts, "Int", 3)
        DllCall("Gdi32\SelectObject", "Ptr", memDc, "Ptr", blackBrush, "Ptr")
        cx := Ws // 2, hw := Max(Round(Ws * 0.075), S // 2 + 1)
        DllCall("Gdi32\Rectangle", "Ptr", memDc, "Int", cx - hw, "Int", Round(Hs * 0.38), "Int", cx + hw, "Int", Round(Hs * 0.67))
        DllCall("Gdi32\Rectangle", "Ptr", memDc, "Int", cx - hw, "Int", Round(Hs * 0.75), "Int", cx + hw, "Int", Round(Hs * 0.87))
        DllCall("Gdi32\GdiFlush")
        cov := []
        Loop H {
            y := A_Index - 1
            Loop W {
                x := A_Index - 1
                sum := 0
                Loop S {
                    rowPtr := bits + ((y * S + A_Index - 1) * Ws + x * S) * 4
                    Loop S
                        sum += NumGet(rowPtr, (A_Index - 1) * 4, "UChar")
                }
                cov.Push(sum / (255 * S * S))
            }
        }
        DllCall("Gdi32\SelectObject", "Ptr", memDc, "Ptr", oldPen, "Ptr")
        DllCall("Gdi32\SelectObject", "Ptr", memDc, "Ptr", oldBrush, "Ptr")
        DllCall("Gdi32\SelectObject", "Ptr", memDc, "Ptr", oldBmp, "Ptr")
        DllCall("Gdi32\DeleteObject", "Ptr", whiteBrush)
        DllCall("Gdi32\DeleteObject", "Ptr", blackBrush)
        DllCall("Gdi32\DeleteObject", "Ptr", big)
        for tone in GetWarnTones() {
            v := Integer("0x" tone)
            r := (v >> 16) & 255, g := (v >> 8) & 255, b := v & 255
            NumPut("Int", W, bi, 4), NumPut("Int", -H, bi, 8)
            sbits := 0
            hbm := DllCall("Gdi32\CreateDIBSection", "Ptr", hdc, "Ptr", bi, "UInt", 0, "Ptr*", &sbits, "Ptr", 0, "UInt", 0, "Ptr")
            if (!hbm || !sbits)
                continue
            for i, c in cov
                NumPut("UInt", (Round(r * c) << 16) | (Round(g * c) << 8) | Round(b * c), sbits, (i - 1) * 4)
            bmps.Push(hbm)
        }
    }
    DllCall("Gdi32\DeleteDC", "Ptr", memDc)
    DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return bmps
}

; Owner-draw dispatch for the two warning icons (the sign and the pointing hand).
RiskIconOwnerDraw(hwnd, itemHwnd, lParam) {
    global riskGui, riskWarnSign, riskWarnBmps, riskWarnShown, riskHandCtl, riskHandBmp
    if (!IsObject(riskGui) || !IsWindowValid(riskGui) || hwnd != riskGui.Hwnd)
        return ""
    if (IsWindowValid(riskWarnSign) && itemHwnd = riskWarnSign.Hwnd) {
        idx := Min(Max(riskWarnShown, 1), Max(riskWarnBmps.Length, 1))
        return DrawBitmapItem(lParam, riskWarnBmps.Length ? riskWarnBmps[idx] : 0)
    }
    if (IsWindowValid(riskHandCtl) && itemHwnd = riskHandCtl.Hwnd)
        return DrawBitmapItem(lParam, riskHandBmp)
    return ""
}

; Copies a ready bitmap over the whole item rectangle (one BitBlt, no background fill first).
DrawBitmapItem(drawItemStruct, hbm) {
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    targetHdc := NumGet(drawItemStruct, itemHwndOffset + A_PtrSize, "Ptr")
    rectOffset := itemHwndOffset + A_PtrSize * 2
    left := NumGet(drawItemStruct, rectOffset, "Int")
    top := NumGet(drawItemStruct, rectOffset + 4, "Int")
    width := NumGet(drawItemStruct, rectOffset + 8, "Int") - left
    height := NumGet(drawItemStruct, rectOffset + 12, "Int") - top
    if (width <= 0 || height <= 0 || !targetHdc || !hbm)
        return 1
    memDc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", targetHdc, "Ptr")
    if (!memDc)
        return 1
    oldBmp := DllCall("Gdi32\SelectObject", "Ptr", memDc, "Ptr", hbm, "Ptr")
    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memDc, "Ptr", oldBmp, "Ptr")
    DllCall("Gdi32\DeleteDC", "Ptr", memDc)
    return 1
}

; The pointing hand (the 👉 emoji silhouette), stored as a 192 x 148 coverage mask (hand = 255, outside = 0), shrunk with a
; box filter to W x H and filled solid with #F2A900 (the colour of the warning text) on black.
BuildHandBitmap(W, H) {
    MW := 192, MH := 148
    b64 := HandMaskB64()
    size := 0
    DllCall("Crypt32\CryptStringToBinaryW", "Str", b64, "UInt", StrLen(b64), "UInt", 1, "Ptr", 0, "UInt*", &size, "Ptr", 0, "Ptr", 0)
    if (size < MW * MH)
        return 0
    mask := Buffer(size, 0)
    DllCall("Crypt32\CryptStringToBinaryW", "Str", b64, "UInt", StrLen(b64), "UInt", 1, "Ptr", mask, "UInt*", &size, "Ptr", 0, "Ptr", 0)
    hdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0), NumPut("Int", W, bi, 4), NumPut("Int", -H, bi, 8), NumPut("UShort", 1, bi, 12), NumPut("UShort", 32, bi, 14)
    bits := 0
    hbm := DllCall("Gdi32\CreateDIBSection", "Ptr", hdc, "Ptr", bi, "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
    DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    if (!hbm || !bits)
        return 0
    r := 0xF2, g := 0xA9, bl := 0x00
    Loop H {
        y := A_Index - 1
        y0 := Floor(y * MH / H), y1 := Max(y0 + 1, Ceil((y + 1) * MH / H))
        Loop W {
            x := A_Index - 1
            x0 := Floor(x * MW / W), x1 := Max(x0 + 1, Ceil((x + 1) * MW / W))
            sum := 0, n := 0
            yy := y0
            while (yy < y1 && yy < MH) {
                xx := x0
                while (xx < x1 && xx < MW) {
                    sum += NumGet(mask, yy * MW + xx, "UChar")
                    n++
                    xx++
                }
                yy++
            }
            c := n ? sum / (255 * n) : 0                    ; solid silhouette: coverage = anti-aliased edge
            NumPut("UInt", (Round(r * c) << 16) | (Round(g * c) << 8) | Round(bl * c), bits, (y * W + x) * 4)
        }
    }
    return hbm
}

HandMaskB64() {
    b := ""
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAANKgpl+RAUAAgAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIANLT7////+L1HAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AwBa7f///f39///4cwABAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAFnz//z+/////vz//GYAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAPOv//f/////////9/+gvAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAezv/9/////////////f+cAQEAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAgWj//3//////////////v7qLQACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAG38"
    b .= "/f7///////////////7/dAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAO+n//v////////////////3/sgIAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAgAWyv/9//////////////////3/1xcAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAgSi//3///////////////////7/8DUAAgAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEDAHb//f////////////////////7/+0QAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMAU/f+/v//"
    b .= "/////////////////////1EAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwA16f/+///////////////////////+/1YAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAADACLa//3//////////////////////////1MAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAFMb//P////////////////////////7//k0AAwAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAJsP/8//////////////////////////7/+UIAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAef//3/////////"
    b .= "//////////////////7/7jQAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIABZj//f7///////////////////////////3/2hoAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAQAHk//9//////////////////////////////3/wAYAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAeT//7+//////////////////////////////3/lwABAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIACZb//v7///////////////////////////////7/ZwADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwARov/+/v//////////////"
    b .= "/////////////////v/wNgACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEDACK2//3+/////////////////////////////////f/FDAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAgEAO9D//f///////////////////////////////////f+GAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEDAABk6f/9///////////////////////////////////+//ZBAAMAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAIKH+//3////////////////////////////////////9/8QMAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAICAAJe3P///v//////////////////////"
    b .= "///////////////+/3MAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAgAAPbX///3+//////////////////////////////////////3+4SAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQMAACaV"
    b .= "9f/+/f////////////////////////////////////////3/jAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAECAAAchen///z//////////////////////////////////////////v7lJgACAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAABAwAAFnXc///8/v///////////////////////////////////////////f9/AAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQIAABVw1v///f7/////////////////////////////////"
    b .= "///////////9/9YYAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAECAAAVb9P///39//////////////////////////////////////////////79/VwAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAgAAGXTT///+/f//////"
    b .= "//////////////////////////////////////////3/qAQCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQIAABx31////v3//////////////////////////////////////////////////f/hIgACAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAECAAAffNn///39///////////////////////////////////////////////////+/fxaAAMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAFnHY///9/f//////////////////////////////////////////////"
    b .= "///////8/5MAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIBAAlj0P///f3///////////////////////////////////////////////////////3/wQ0BAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwAARbr///7+////////////////////"
    b .= "/////////////////////////////////////f/eKQACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEBACCX9f/+/f/////////////////////////////////////////////////////////+//BFAAMAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwAA"
    b .= "WNn///3///////////////////////////////////////////////////////////7++2IAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADABOX/P/9/v//////////////////////////////////////////////////////////"
    b .= "/v7/dgACAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAMANcv///3///////////////////////////////////////////////////////////////99AAMBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAgBY7P/9/v//////////////////////////////"
    b .= "//////////////////////////////7/9XQAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAQEBAQEBAQICAgIDAwMDAwMDAwMDAwMDAwMDAwMDAwICAgICAQEAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEBAHj8//z///////////////////////////////////////////////////////////////7+igAAAQIEBQcHCAgICAgICAgHBwcHBwcH"
    b .= "BwYFBQUFBQQDAwMCAgICAgEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAwIBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQEAhf///f//"
    b .= "///////////////////////////////////////////////////////////////9zqyyt7zCxcvMzM3Pz8/Ozs3MzMvLzMrLysjGxcXFxMPBwb69vL26u7m5trKvrq2lpqWlp6SjoJqXlI6FgX98eXZzcXBsZ2Je"
    b .= "WlZWVVJRUEhDOCwlGAMAAAAAAgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAQKK//7+////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////////////////////////////////////37+PLr276gcTcIAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAECAIL//v7//////////////////////////////////////////////////////////////////////vz9/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/f39/fz8"
    b .= "/Pz8/Pz8/Pz8/Pz8/Pz8/f39/f39/f7+/v7+/v////////////////PCbREAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQMAbv3+/v//////////////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////7+/v7+/f39/f///8U4AAIA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgBL8f/+////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////////////////79/f/kQAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACACrd//3/////////"
    b .= "////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////v/2yIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEBDLb//f//////////////////////////////////////////////////////////////////////////"
    b .= "///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8/5sBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAIAev/9////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "///////////////////////////////////////////////////////////+/usrAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgA67f7+////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////v90"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAQ28//3/////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////////////////////f+vAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAHD//f//////////////"
    b .= "////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////v/TAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAJuP//v//////////////////////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////v/eAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAQIDp//9////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////v/dAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgBV+/3+////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////v/Q"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACABva//3/////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////////////////////f+mAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEDAZ3//f//////////////////"
    b .= "////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////v9rAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMAX/z9/v//////////////////////////////////////////////////////////////////////////////////"
    b .= "///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+/uUkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAwAq5//+////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "///////////////////////////////////////////////////////////8/4sAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABARDB//3/////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////z/2B0B"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAECAZb//P//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////////////////79/f/mQAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQMAdP79/v//////////////////////"
    b .= "////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////7+/f39/v///8s9AAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAgBf9v/+////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////////////////v7+/v7+/v39/f39/Pz9/v////////C/bRUAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQMB"
    b .= "AFrx//7////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+"
    b .= "/v7+/v39/f39/f39/f39/f3+/v////////////////////vv2bqWZzUJAAACAAAAAAAAAAAAAQEBAQEBAgICAgICAwMDAAACcPP//v//////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////v7+/v79/f39/Pz9/f7///////////////////////////348+/q4dvWz8a4oo1+ZEMxGgMAAAAAAgEAAAAA"
    b .= "AAAAAwMBAAAAAAAAAAAAAAAAAAAAAzqo/v/+////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//79/fz9/f3+///////////////////89vDo4trPxbmzrqaflYl+b2FaVEtBODAoGhUSDwsFAAAAAAAAAAABAwIBAAAAAAAAAAAAAAAAAAcPExgaGyIjJy40O1WCtvL///7/////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////////////////////////////////////////358efd08i5pYx6bVlEMiokHhcPCAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAQICAgICAQEAAAAAAAAAAAAAAQAAQoCrv8vT193e4Obn6/H0+v/////9/v//////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "///////////////////////////////+9uXFpI5/cWFRSkM9MCMUCwcCAAAAAAAAAAAAAAAAAAABAQEBAgICAwMDAwMCAgICAQEBAQEBAAAAAAAAAAAAAAAAAAAAAAAAAQaV/P////////////////////79/f7/"
    b .= "///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////52a9+RRUAAAAAAAAAAAAAAAAAAQIDAwMC"
    b .= "AgICAgEBAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFj///z9/f39/f3+/f7+/v7+/v7/////////////////////////////////////////////////////////////////////"
    b .= "///////////////////////////////////////////////////////////////++/r8+um+bhcABAMCAgIBAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AKP+/P//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////9VUAAEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADcz//f//////////////////////////////////////////////////////////"
    b .= "///////////////////////////////////////////////////////////////////////////////////////////////////+/v79/f/7fQACAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAH+T//v//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////3//3IAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALvD//v//////////////////////////"
    b .= "///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9/vM9AAIAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAARfj//v//////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////P+3BQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "Wf7/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////////v75PQADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAZ//+////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////////////////////////////////////////z/kAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcf/+////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////////3/zAYAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAeP/+////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////7/7SUAAgAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAff/9////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////////7//kYAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "hP/9////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "///////////////+/1AAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAiv/9////////////////////////////////////////////////////////////"
    b .= "///////////////////////////////////////////////////////////////////////////////////////////////////////////////+/1AAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAlv/9////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////////7//kYAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAn//9////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////7/7ycAAgAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAApP/9////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////////3/zAUAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "qP/9////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////z/jAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAsP/9////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////////////////////////////////////v73OAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuP/9////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////P+lAwIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuv/9////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////78/9okAAIAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAvf/+////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////7+/f//4TwAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "wf/+////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////f////y2LwACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAv//+////////////////////////////////////////////////////////////"
    b .= "///////////////////////////////////////////////////////////////////////////////////////////////////////colIIAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwP/+////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "///////////////////////////////////xmFEfAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAxf/+////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////v/rWAAAAwIBAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAx//+////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "////////////////////////////////////////////////////////////////////9qAeAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "x//+////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "///////LKwACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAy//+////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////////////////////////////vz/zyAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAy//+////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "///////////////////////////////////////8/6QEAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAzP/+////////////////////////////"
    b .= "///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+/fpLAAIAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAy//+////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////f+pAgEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "yf/+////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////v/jHwACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAyP/+////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////////////////////////////////v/8TAADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAyf/+////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////7/ZgADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAx//+////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////3/bgADAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAyf/+////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////3/bAADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "xf/+////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////v7/XAADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAw//+////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////////////////////////////////v/0OQACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwv/+////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////f7SEQABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuv/+////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////f+OAAEAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAt//9////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "///////////////////////////////////////////////////////////////////////+/vA0AAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "tP/9////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "///////8/48AAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAq//9////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////////////////////////////vz/xBYAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAo//9////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////78///GJAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAmv/9////////////////////////////"
    b .= "////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9ZYVAAIAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAiv/9////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////dqTOAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "gf/9//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////7/"
    b .= "+EoAAAEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAe//9////////////////////////////////////////////////////////////"
    b .= "///////////////////////////////////////////////////////////////////////////////////////////////+/6kLBAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAdf/+////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////v93AAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAbf/+////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////v/kJgACAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAYv//////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////7/dQACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "V/7/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//3+qwIBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAASvr//v//////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////////////////////////////3/yg0AAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOvT//v//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////3/1RMAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJ+3//v//////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////3/zQ8AAQAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHuL+/v//////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//////////////////////////////////////////////////////////////////3/sQMAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "CMb/+/39/Pz8/Pz8/Pz8/Pz9/f7+/v//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    b .= "//3/hQACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGH0//////////////////////////38/f7/////////////////////////////"
    b .= "/////////////////////////////////////////////////////////////////////////////////////////////////v74RgADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAxZX6GioqGhYmMkZSboqq6zuDv/v/////9/f7/////////////////////////////////////////////////////////////////////////////////////////"
    b .= "/////////////////////////////////f/ECgABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAChYjQ2qh"
    b .= "0fj////9/f7//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////f5bAAIAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAwMDAwMDAwMDAwMDAwIAAAAAAAAACzp/xvj////9/v//////////////////////////////////////////////////"
    b .= "///////////////////////////////////////////////////////////////8/7AGAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAQECAwMCAAAACD+L0/////39//////////////////////////////////////////////////////////////////////////////////////////////////////////////z/"
    b .= "1yAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQIDAAAAE1Op7v///v3/////////////"
    b .= "///////////////////////////////////////////////////////////////////////////////////////////+/P/gNgACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQICAAAAM4fZ///+/f7/////////////////////////////////////////////////////////////////////////"
    b .= "/////////////////////////v3//8kwAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAQMAAAAbc9D////9/v////////////////////////////////////////////////////////////////////////////////////////////79///ujBUAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgIAABVnyf////3+////////////////////////////////////"
    b .= "//////////////////////////////////////////////////79/f//9aQ1AAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAgAAEGHB+v///f3+//////////////////////////////////////////////////////////////////////////7+/f39/v///+6oRAAAAgEA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAECAAAKTqfr////"
    b .= "/f3+///////////////////////////////////////////////////////////////+/v38/f///////+/FfzQAAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQMAAAAueMP1/////v39/v////////////////////////////////////////////////////79"
    b .= "/f3////////y2ruRXzILAAAAAgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAABAgAAAAo7fr7q//////78/f7+///////////////////////////////////////+/v38/f/////74sacdVEyGwMAAAAAAgIBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAECAgAAAAYpYJvN8f///////f38/f3+/v7/////"
    b .= "//////////////7+/v39/P3+//////rZq3hHHgoAAAAAAAABAwIBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAECAgAAAAAOMWKTwuP8/////////////v79/f39/f39/f3+////////////7tCkcj8XAAAAAAABAgICAQEAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAECAwEAAAAABBs+Younwtnp8/r///////////////////rx5NS3mXNLKgoAAAAAAQIDAgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAgMCAAAAAAAABhYiM0pdbHZ/iI+PlZSOgXpxY0owHhMAAAAAAAABAwIB"
    b .= "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    return b
}

; Repaints every owner-drawn piece of the warning (buttons, logo, line, title). Called right after the fade-in (and once
; more shortly after), because the layered window sometimes composed the new children without their first paint, so the
; button labels / icons only appeared once the mouse hovered them.
RiskForcePaint() {
    global riskViewActive, riskGui, riskLineGui, riskTosGui, riskBtnAccept, riskBtnCancel, riskTitleCtl, mainGui
    if (!riskViewActive || !IsWindowValid(mainGui))
        return
    list := [riskGui, riskLineGui, riskTosGui, riskTitleCtl]
    if (IsObject(riskBtnAccept))
        list.Push(riskBtnAccept.gui)
    if (IsObject(riskBtnCancel))
        list.Push(riskBtnCancel.gui)
    for g in list {
        if (IsWindowValid(g))
            DllCall("User32\RedrawWindow", "Ptr", g.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0185, "Int")   ; INVALIDATE|ERASE|ALLCHILDREN|UPDATENOW
    }
}

; Same as RiskForcePaint but WITHOUT erasing (the owner-drawn pieces repaint their whole area from memory), so it can run
; while the warning is visible without any flicker.
RiskSoftPaint() {
    global riskViewActive, riskGui, riskLineGui, riskTosGui, riskBtnAccept, riskBtnCancel, riskTitleCtl, riskWarnSign, riskHandCtl, mainGui, riskIconCtl
    if (!riskViewActive || !IsWindowValid(mainGui))
        return
    ; Only the OWNER-DRAWN pieces: each one repaints its whole area from a ready bitmap with one BitBlt and never fills its
    ; background first, so repainting them can not flash. The plain text controls (ID, description, warning) are NOT touched here:
    ; a static control erases its background and then draws the text, which showed as a flicker of the text.
    list := [riskLineGui, riskTosGui]
    if (IsObject(riskBtnAccept))
        list.Push(riskBtnAccept.gui)
    if (IsObject(riskBtnCancel))
        list.Push(riskBtnCancel.gui)
    for g in list {
        if (IsWindowValid(g))
            DllCall("User32\RedrawWindow", "Ptr", g.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0181, "Int")   ; INVALIDATE|ALLCHILDREN|UPDATENOW (no ERASE)
    }
    for c in [riskTitleCtl, riskWarnSign, riskHandCtl, riskIconCtl] {
        if (IsWindowValid(c))
            DllCall("User32\RedrawWindow", "Ptr", c.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0101, "Int")    ; INVALIDATE|UPDATENOW (no ERASE)
    }
}

; Same as CursorOverActionButtonNormalSize, for a warning button (it shrinks to 94 % while pressed).
RiskBtnCursorOverNormalSize(b) {
    global riskGui
    try {
        WinGetPos(&gx, &gy,,, "ahk_id " riskGui.Hwnd)
        CoordMode("Mouse", "Screen")
        MouseGetPos(&cx, &cy)
        return cx >= gx + b.x && cx < gx + b.x + b.w && cy >= gy + b.y && cy < gy + b.y + b.h
    }
    return false
}

; Hover / press behaviour of the two warning buttons, identical to the Start / Stop button: hover colour while the
; mouse is over it, pressed colour + shrink while held, and on release (still over it) the spring-back and then the action.
RiskViewTick() {
    global riskViewActive, riskViewBusy, riskBtnAccept, riskBtnCancel, riskPressedName, riskBtnAnimating, riskKeyHeld, riskKeyCancel
    global riskPrevDown, riskAnimTick
    if (!riskViewActive) {
        SetTimer(RiskViewTick, 0)
        return
    }
    if (!IsObject(riskBtnAccept) || !IsObject(riskBtnCancel) || !IsWindowValid(riskBtnAccept.gui) || !IsWindowValid(riskBtnCancel.gui))
        return                                   ; (never switch the timer off here: that left the warning dead)
    try {
        TosHoverPoll()
        down := GetKeyState("LButton", "P")
        edge := down && !riskPrevDown
        riskPrevDown := down
        ; Safety nets: an animation flag that is stuck for seconds (an animation lasts 45 ms) is released.
        if (riskBtnAnimating && A_TickCount - riskAnimTick > 2500)
            riskBtnAnimating := false
        if (riskBtnAnimating || riskViewBusy)
            return
        MouseGetPos(,,, &hovered, 2)
        viaKey := false
        ; Esc while a warning button is held down (Enter on Continue, or the mouse on either button): cancel the press -
        ; spring back, no action, like releasing the mouse outside the button. Done here (not in the hotkey) because this
        ; point is only reached once the press animation has finished, so the two animations can never overlap.
        if (riskKeyCancel) {
            riskKeyCancel := false
            if (riskPressedName != "") {
                b := (riskPressedName = "accept") ? riskBtnAccept : riskBtnCancel
                riskPressedName := ""
                riskKeyHeld := false
                over := (hovered = b.ctl.Hwnd || hovered = b.gui.Hwnd)
                SetRiskBtnColor(b, over ? b.hover : b.normal, false)
                AnimateRiskButton(b, false)
            }
            return
        }
        if (connLost && riskPressedName = "accept") {
            ; the connection dropped while Continue was held down: spring back at once, no action (frozen)
            riskPressedName := ""
            riskKeyHeld := false
            SetRiskBtnColor(riskBtnAccept, riskBtnAccept.normal, false)
            AnimateRiskButton(riskBtnAccept, false)
            return
        }
        if (riskKeyHeld) {
            ; Enter holds "Continue" down: wait for the key itself to be released (polled, so a lost key-up cannot stick it)
            if (GetKeyState("Enter", "P") || GetKeyState("NumpadEnter", "P"))
                return
            riskKeyHeld := false
            viaKey := true
        }
        ; A click is also detected here (mouse polled), not only through WM_LBUTTONDOWN, so a lost message cannot make a button dead.
        if (edge && riskPressedName = "" && !viaKey) {
            for b in [riskBtnAccept, riskBtnCancel] {
                if (connLost && b.name = "accept")
                    continue                       ; connection lost: Continue is frozen
                if (hovered = b.ctl.Hwnd || hovered = b.gui.Hwnd) {
                    riskPressedName := b.name
                    riskKeyCancel := false
                    SetRiskBtnColor(b, b.pressed, false)
                    AnimateRiskButton(b, true)
                    return
                }
            }
        }
        if (riskPressedName != "" && (!down || viaKey)) {
            b := (riskPressedName = "accept") ? riskBtnAccept : riskBtnCancel
            riskPressedName := ""
            over := viaKey || (hovered = b.ctl.Hwnd || hovered = b.gui.Hwnd) || RiskBtnCursorOverNormalSize(b)
            SetRiskBtnColor(b, over ? b.hover : b.normal, false)
            AnimateRiskButton(b, false, over ? (b.name = "accept" ? RpcRiskAccept : RpcRiskDecline) : "")
            return
        }
        for b in [riskBtnAccept, riskBtnCancel] {
            over := (hovered = b.ctl.Hwnd || hovered = b.gui.Hwnd) && !(connLost && b.name = "accept")
            if (riskPressedName = b.name)
                want := b.pressed
            else
                want := (over && riskPressedName = "") ? b.hover : b.normal
            SetRiskBtnColor(b, want)
        }
    } catch {
        riskPressedName := "", riskKeyHeld := false     ; any error: drop the half-pressed state, the next tick starts clean
    }
}

; While the warning is shown: pressing a button starts its press effect; dragging the window, minimize and close keep
; working like in the normal view.
RiskViewLeftDown(hwnd) {
    global mainGui, titleBar, versionText, minBtn, closeBtn, riskGui, pressedControl
    global riskBtnAccept, riskBtnCancel, riskPressedName, riskViewBusy, riskBtnAnimating, riskLineGui, riskTitleCtl, riskKeyCancel
    if (IsTosIconHwnd(hwnd)) {
        TosIconDown()
        return
    }
    if (hwnd = mainGui.Hwnd || hwnd = titleBar.Hwnd || hwnd = versionText.Hwnd || (IsWindowValid(riskGui) && hwnd = riskGui.Hwnd)
        || (IsWindowValid(riskLineGui) && hwnd = riskLineGui.Hwnd) || (IsWindowValid(riskTitleCtl) && hwnd = riskTitleCtl.Hwnd)) {
        StartWindowDrag()
        return
    }
    MouseGetPos(,,, &hovered, 2)
    for b in [riskBtnAccept, riskBtnCancel] {
        if (IsObject(b) && IsWindowValid(b.gui) && (hovered = b.ctl.Hwnd || hovered = b.gui.Hwnd)) {
            if (riskViewBusy || riskBtnAnimating || riskPressedName != "" || (connLost && b.name = "accept"))
                return
            riskPressedName := b.name
            riskKeyCancel := false
            try {
                SetRiskBtnColor(b, b.pressed, false)
                AnimateRiskButton(b, true)
            } catch {
                riskPressedName := ""
            }
            return
        }
    }
    pressedControl := ""
    if (hovered = minBtn.Hwnd || hovered = closeBtn.Hwnd)
        MarqueeFrameAlign()
    if (hovered = minBtn.Hwnd) {
        pressedControl := "min"
        SetTopButtonBg("min", "555555")
        PressIcon("min")
    } else if (hovered = closeBtn.Hwnd) {
        pressedControl := "close"
        SetTopButtonBg("close", "B30710")
        PressIcon("close")
    }
}

; Hand cursor over the two warning buttons. Returns true when it handled the message.
RiskDialogCursor(hwnd) {
    global riskViewActive, riskBtnAccept, riskBtnCancel
    if (!riskViewActive || !IsObject(riskBtnAccept) || !IsObject(riskBtnCancel))
        return false
    MouseGetPos(,,, &hovered, 2)
    for b in [riskBtnAccept, riskBtnCancel] {
        if (IsWindowValid(b.gui) && (hovered = b.ctl.Hwnd || hovered = b.gui.Hwnd)) {
            ; connection lost: Continue is frozen exactly like Start / Refresh ("not allowed" cursor, no hover, no press, no action)
            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", (connLost && b.name = "accept") ? 32648 : 32649, "Ptr"))
            return true
        }
    }
    if (IsTosIconHwnd(hovered)) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32649, "Ptr"))
        return true
    }
    return false
}

ToggleAction(*) {
    global rpcConnecting, rpcCancel

    global actionGui, actionBtn, isRunning, lastHover, processSelect, selectedProcessTitle, targetPid, tempExePath, tempScriptPath, tempWorkDir, activeProcessName, isExiting
    if (isExiting)
        return
    DbgLog("Start/Stop pressed: ToggleAction running")
    if (isRunning) {
        rpcConnecting := false, rpcCancel := true
        stoppedName := activeProcessName != "" ? activeProcessName : "Process"
        ; Stop pressed while the helper is still being built: the build is aborted at once and its own thread removes the files
        if (!CancelHelperLaunch())
            StopTargetProcess()
        isRunning := false
        SetActionLabel("Start")
        SetActionColor("208A4E")
        RepaintActionButtonNoErase(), lastHover := -1
        SetStatus("Inactive: '" stoppedName "' has been stopped.", "stopped")
        UpdateButtonHover()
        return
    }

    procName := Trim(selectedProcessTitle)
    if (procName = "") {
        procName := ResolveTypedGameTitle()
        if (procName != "")
            selectedProcessTitle := procName
    }
    if (procName = "") {
        SetStatus("System Error: Search for and select a game first.", "error")
        return
    }
    DismissSearchAfterValidStart()

    cleanName := RegExReplace(procName, "i)\.exe$", "")
    activeProcessName := cleanName
    
    safeDirName := RegExReplace(cleanName, '[\\/<>:"|?*]', "_")
    
    ; The process itself is Discord's detectable executable for this game (taken from the fetched list);
    ; the title only becomes the window / tray / file-description name of that process.
    global gameExecutables, gameAppIds
    titleKey := StrLower(procName)
    detectedExe := ""
    ; 1) manual override file (next to the script/exe):  [Executables]  Game Title=folder\game.exe
    try {
        overrideValue := IniRead(A_ScriptDir "\Ragnious_overrides.ini", "Executables", procName, "")
        if (overrideValue != "")
            detectedExe := SanitizeExecutablePath(overrideValue)
    }
    ; 2) the Windows executable from Discord's detectable list
    if (detectedExe = "" && gameExecutables.Has(titleKey))
        detectedExe := gameExecutables[titleKey]
    if (detectedExe = "" && StrLower(cleanName) = "valorant")
        detectedExe := "Riot Games\VALORANT\live\ShooterGame\Binaries\Win64\VALORANT-Win64-Shipping.exe"

    ; 3) no Windows executable anywhere: show the game through Discord Rich Presence instead of a fake process
    if (detectedExe = "") {
        appId := gameAppIds.Has(titleKey) ? gameAppIds[titleKey] : ""
        if (appId = "") {
            SetStatus("System Error: '" cleanName "' has no Discord application id, so it cannot be started.", "error")
            return
        }
        ; Warn first: spoofing a game through Rich Presence can get the account flagged. The main window switches to
        ; the warning; nothing is sent unless "Accept risk and continue" is pressed (see RpcRiskAccept).
        ShowRpcRiskView(cleanName, appId)
        return
    }

    ; ROOT-CAUSE FIX: the helper .exe has to be COMPILED first (Ahk2Exe, a few seconds). That used to run right here, inside the
    ; click, and the button / status only changed to Active / Stop AFTER it finished - so for seconds nothing happened, and every
    ; extra press was thrown away because the Start request was still "running". Now the window switches to Active / Stop
    ; IMMEDIATELY (exactly like the Rich Presence start does) and the build runs in the background.
    BeginHelperLaunch(cleanName, safeDirName, detectedExe)
}


; Shows Active / Stop at once and starts the background build of the helper executable.
BeginHelperLaunch(cleanName, safeDirName, detectedExe) {
    global helperLaunchId, helperLaunching, helperLaunchStart, isRunning, lastHover, lastToggleDoneTick, connLastStart
    connLastStart := ["exe", cleanName, safeDirName, detectedExe]     ; used to start it again after a connection loss
    SplitPath(detectedExe, &executable)
    helperLaunchId += 1
    myId := helperLaunchId
    helperLaunching := true
    helperLaunchStart := A_TickCount
    isRunning := true
    SetActionLabel("Stop")
    SetActionColor("B42318")
    RepaintActionButtonNoErase(), lastHover := -1
    DbgLog("exe: button now shows Stop")
    SetTimer(MonitorProcess, 1000)
    UpdateButtonHover()
    lastToggleDoneTick := A_TickCount
    ; The status line (long text = pre-rendered scrolling strip, the heavy part) is built in its own short timer thread, AFTER the
    ; button already shows Stop. The compile starts a little later so the status is on screen first.
    SetTimer(ShowHelperActiveStatus.Bind(myId, cleanName, executable), -1)
    SetTimer(RunHelperLaunch.Bind(myId, cleanName, safeDirName, detectedExe), -40)
}

ShowHelperActiveStatus(myId, cleanName, executable) {
    global helperLaunchId, isRunning, isExiting
    if (isExiting || !isRunning || myId != helperLaunchId)   ; stopped / failed / replaced meanwhile: never overwrite a newer status
        return
    SetStatus("Active: '" cleanName "' is running as " executable "...", "running")
    DbgLog("exe: Active status built")
}

; Aborts a helper build that is still in progress (Stop pressed / app closing). Returns true when there was one.
CancelHelperLaunch() {
    global helperLaunchId, helperLaunching, helperCompilerPid
    if (!helperLaunching)
        return false
    helperLaunching := false
    helperLaunchId += 1                      ; the build thread notices the new id and gives up
    if (helperCompilerPid)
        try ProcessClose(helperCompilerPid)  ; no waiting for the compiler to finish
    return true
}

; Background thread: builds + starts the helper (up to 3 attempts). Only touches the UI when the build FAILED.
RunHelperLaunch(myId, cleanName, safeDirName, detectedExe) {
    global helperLaunchId, helperLaunching, helperThreadBusy, isRunning, lastHover, isExiting
    waitStart := A_TickCount
    while (helperThreadBusy && A_TickCount - waitStart < 3000)   ; a cancelled earlier build is still cleaning up: let it finish first
        Sleep(10)
    if (myId != helperLaunchId || isExiting)
        return
    helperThreadBusy := true
    ok := false, lastError := "Unknown error."
    try {
        Loop 3 {
            if (myId != helperLaunchId || isExiting)
                break
            StopTargetProcess()                  ; clean state: old helper closed, old files / folder removed
            lastError := TryLaunchHelper(myId, cleanName, safeDirName, detectedExe)
            if (lastError = "") {
                ok := true
                break
            }
            if (myId != helperLaunchId || isExiting)
                break
            StopTargetProcess()
            Sleep(250 * A_Index)
        }
        if (myId != helperLaunchId || isExiting) {
            CleanupHelperFiles()                 ; cancelled: the UI was already reverted by whoever cancelled
            return
        }
        helperLaunching := false
        if (ok)
            return                               ; the UI already shows Active / Stop
        StopTargetProcess()
        isRunning := false
        SetActionLabel("Start")
        SetActionColor("208A4E")
        RepaintActionButtonNoErase(), lastHover := -1
        SetStatus("System Error: Failed to process setup. (" lastError ")", "error")
        UpdateButtonHover()
    } finally {
        helperThreadBusy := false
    }
}


; Builds and starts the helper executable once. Returns "" on success, otherwise the reason (or "Cancelled." when Stop was pressed meanwhile).
TryLaunchHelper(myId, cleanName, safeDirName, detectedExe) {
    global targetPid, tempExePath, tempScriptPath, tempWorkDir, isRunning, helperLaunchId, helperLaunching, helperCompilerPid, isExiting
    try {
        baseDir := A_Temp "\Ragnious_" safeDirName
        tempWorkDir := baseDir
        if (DirExist(baseDir)) {
            try DirDelete(baseDir, true)
            if (DirExist(baseDir))               ; something still holds the old folder: use a fresh one instead of failing
                tempWorkDir := baseDir "_" A_TickCount
        }
        SplitPath(detectedExe, &executable, &exeSubDir)
        tempExeDir := exeSubDir != "" ? tempWorkDir "\" exeSubDir : tempWorkDir
        DirCreate(tempExeDir)
        tempExePath := tempExeDir "\" executable
        tempScriptPath := tempWorkDir "\" safeDirName ".ahk"

        shownTitle := cleanName
        safeTitle := StrReplace(StrReplace(shownTitle, "``", "````"), '"', '``"')
        metaTitle := RegExReplace(shownTitle, "[\r\n]+", " ")
        scriptContent := ""
        scriptContent .= ';@Ahk2Exe-SetName ' metaTitle '`n;@Ahk2Exe-SetDescription ' metaTitle '`n;@Ahk2Exe-SetProductName ' metaTitle '`n'
        scriptContent .= '#Requires AutoHotkey v2.0`n#SingleInstance Ignore`nPersistent()`n'
        scriptContent .= 'A_IconTip := "' safeTitle '"`n'
        scriptContent .= 'try A_TrayMenu.Delete()`n'
        scriptContent .= 'try A_TrayMenu.Add("Show ' safeTitle '", ShowPlaceholder)`n'
        scriptContent .= 'try A_TrayMenu.Add("Exit", (*) => ExitApp())`n'
        scriptContent .= 'try A_TrayMenu.Default := ""`n'
        scriptContent .= 'try A_TrayMenu.ClickCount := 0`n'
        scriptContent .= 'placeholderGui := Gui("+ToolWindow -Resize", "' safeTitle '")`n'
        scriptContent .= 'placeholderGui.Add("Text", "w280 Center", "' safeTitle '")`n'
        scriptContent .= 'placeholderGui.OnEvent("Close", HidePlaceholder)`n'
        scriptContent .= 'placeholderGui.Show("NA x-1000000 y-1000000 w300 h90")`n'
        scriptContent .= 'HidePlaceholder(guiObj, *) {`n    guiObj.Hide()`n    return true`n}`n'
        scriptContent .= 'ShowPlaceholder(*) {`n    global placeholderGui`n    placeholderGui.Show("Center w300 h90")`n}`n'
        try FileDelete(tempScriptPath)
        FileAppend(scriptContent, tempScriptPath, "UTF-8")
        ahkPath := GetAutoHotkeyInterpreter()
        if (!ahkPath || !FileExist(ahkPath))
            return "Runtime interpreter not found."
        compilerPath := GetAutoHotkeyCompiler(ahkPath)
        if (!compilerPath || !FileExist(compilerPath))
            return "AutoHotkey compiler not found."
        try FileDelete(tempExePath)
        if (myId != helperLaunchId || isExiting)
            return "Cancelled."
        compilePid := 0
        Run(Format('"{1}" /in "{2}" /out "{3}" /base "{4}" /compress 0 /silent', compilerPath, tempScriptPath, tempExePath, ahkPath), tempWorkDir, "Hide", &compilePid)
        helperCompilerPid := compilePid
        try ProcessSetPriority("BelowNormal", compilePid)   ; the build must never steal CPU from the window
        compileStart := A_TickCount
        ; polled (not RunWait) so the window keeps answering - and a Stop press can abort the compile immediately
        while (compilePid && ProcessExist(compilePid)) {
            if (myId != helperLaunchId || isExiting) {
                try ProcessClose(compilePid)
                break
            }
            if (A_TickCount - compileStart > 60000) {
                try ProcessClose(compilePid)
                helperCompilerPid := 0
                return "The compiler took too long."
            }
            Sleep(10)
        }
        helperCompilerPid := 0
        DbgLog("exe: compile finished")
        if (myId != helperLaunchId || isExiting)
            return "Cancelled."
        if (!FileExist(tempExePath))
            return "Failed to compile the helper executable."
        try FileDelete(tempScriptPath)
        tempScriptPath := ""
        launchOptions := ""   ; never start hidden, otherwise the helper's Show window can't be displayed
        outPid := 0
        Run(Format('"{1}"', tempExePath), tempWorkDir, launchOptions, &outPid)
        if (!outPid)
            return "The helper executable did not start."
        if (myId != helperLaunchId || isExiting) {       ; Stop was pressed while it was starting: close it again
            try ProcessClose(outPid)
            return "Cancelled."
        }
        DbgLog("exe: helper process started")
        targetPid := outPid
        helperLaunching := false                          ; the UI already shows Active / Stop since the first click
        return ""
    } catch Error as err {
        return err.Message
    }
}

StopTargetProcess() {
    StopDiscordRichPresence()
    CleanupHelperFiles()
}

; Closes the helper process and deletes its files / folder (does NOT touch the Rich Presence connection).
CleanupHelperFiles() {
    global targetPid, tempExePath, tempScriptPath, tempWorkDir
    try {
        if (targetPid && ProcessExist(targetPid)) {
            ProcessClose(targetPid)
            ProcessWaitClose(targetPid, 2)       ; the exe stays locked until the process is really gone
        }
    }
    ; Delete the helper files / folder; if Windows still holds them for a moment, retry instead of leaving them behind.
    Loop 10 {
        try {
            if (tempExePath && FileExist(tempExePath))
                FileDelete(tempExePath)
        }
        try {
            if (tempScriptPath && FileExist(tempScriptPath))
                FileDelete(tempScriptPath)
        }
        try {
            if (tempWorkDir && DirExist(tempWorkDir))
                DirDelete(tempWorkDir, true)
        }
        if (!(tempExePath && FileExist(tempExePath)) && !(tempWorkDir && DirExist(tempWorkDir)))
            break
        Sleep(100)
    }
    targetPid := 0, tempExePath := "", tempScriptPath := "", tempWorkDir := ""
}

MonitorProcess(*) {
    global isRunning, targetPid, activeProcessName, isExiting, rpcPipe
    if (isExiting || !isRunning)
        return
    if ((targetPid && !ProcessExist(targetPid)) || (rpcPipe && !RpcKeepAlive())) {
        global actionGui, actionBtn, lastHover
        stoppedName := activeProcessName != "" ? activeProcessName : "Process"
        StopTargetProcess()
        isRunning := false
        SetActionLabel("Start")
        SetActionColor("208A4E")
        RepaintActionButtonNoErase(), lastHover := -1
        SetStatus("Inactive: '" stoppedName "' has been terminated.", "stopped")
        UpdateButtonHover()
    }
}

SetWindowOpacity(alpha) {
    global mainGui, selectorFrameGui, selectorPopup, selectorList, statusMarqueeGui, isExiting, statusFadeOv, statusFadeShown, windowAlphaNow
    windowAlphaNow := alpha
    if (statusFadeShown && IsWindowValid(statusFadeOv))
        try DllCall("User32\SetLayeredWindowAttributes", "Ptr", statusFadeOv.Hwnd, "UInt", 0, "UChar", alpha, "UInt", 3, "Int")
    if (mainGui && mainGui.Hwnd)
        try DllCall("User32\SetLayeredWindowAttributes", "Ptr", mainGui.Hwnd, "UInt", 0, "UChar", alpha, "UInt", 2, "Int")
    if (IsWindowValid(selectorFrameGui))
        try DllCall("User32\SetLayeredWindowAttributes", "Ptr", selectorFrameGui.Hwnd, "UInt", 0, "UChar", alpha, "UInt", 2, "Int")
    if (IsWindowValid(selectorPopup))
        try DllCall("User32\SetLayeredWindowAttributes", "Ptr", selectorPopup.Hwnd, "UInt", 0, "UChar", alpha, "UInt", 2, "Int")
    if (IsWindowValid(selectorList))
        try DllCall("User32\SetLayeredWindowAttributes", "Ptr", selectorList.Hwnd, "UInt", 0, "UChar", alpha, "UInt", 2, "Int")
    if (IsWindowValid(statusMarqueeGui))
        try DllCall("User32\SetLayeredWindowAttributes", "Ptr", statusMarqueeGui.Hwnd, "UInt", 0, "UChar", alpha, "UInt", 2, "Int")
}

ApplyAllCorners() {
    global mainGui, actionGui, isExiting
    if (isExiting || !IsSet(mainGui) || !mainGui)
        return
    ApplyRoundedCorners(mainGui, 29)
    ApplyRoundedCorners(actionGui, 24)
}

RemoveNativeOutline(hwnd) {
    if (!hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int"))
        return
    style := DllCall("User32\GetWindowLongW", "Ptr", hwnd, "Int", -16, "Int")
    exStyle := DllCall("User32\GetWindowLongW", "Ptr", hwnd, "Int", -20, "Int")
    style := style & ~0x00C00000 & ~0x00800000
    exStyle := exStyle & ~0x00020301 & ~0x00000200
    DllCall("User32\SetWindowLongW", "Ptr", hwnd, "Int", -16, "Int", style, "Int")
    DllCall("User32\SetWindowLongW", "Ptr", hwnd, "Int", -20, "Int", exStyle, "Int")
    DllCall("User32\SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0037, "Int")
}

ApplyRoundedCorners(target, cornerSize := 29, redraw := true) {
    rect := Buffer(16, 0)
    if !DllCall("User32\GetWindowRect", "Ptr", target.Hwnd, "Ptr", rect, "Int")
        return
    width := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")
    height := NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int")
    ; The same region on the same window size is not set again (every SetWindowRgn repaints the whole window = flicker).
    static applied := Map()
    sig := width "|" height "|" cornerSize
    if (applied.Has(target.Hwnd) && applied[target.Hwnd] = sig) {
        probe := DllCall("Gdi32\CreateRectRgn", "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr")
        hasRgn := probe ? DllCall("User32\GetWindowRgn", "Ptr", target.Hwnd, "Ptr", probe, "Int") : 0
        if (probe)
            DllCall("Gdi32\DeleteObject", "Ptr", probe)
        if (hasRgn)
            return
    }
    region := DllCall("Gdi32\CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", width, "Int", height, "Int", cornerSize, "Int", cornerSize, "Ptr")
    if (!region)
        return
    if (DllCall("User32\SetWindowRgn", "Ptr", target.Hwnd, "Ptr", region, "Int", redraw, "Int"))
        applied[target.Hwnd] := sig
    else
        DllCall("Gdi32\DeleteObject", "Ptr", region)
}

; ---------------------------------------------------------------------------------------------
; Discord Rich Presence over the local IPC pipe (\\.\pipe\discord-ipc-0..9). Used for games whose
; Discord entry has no Windows executable. The pipe stays open while "active"; closing it clears the status.
; ---------------------------------------------------------------------------------------------
StartDiscordRichPresence(appId) {
    global rpcPipe, rpcLastError, rpcCancel
    StopDiscordRichPresence()
    rpcLastError := "Make sure the Discord desktop app is running."
    ; Discord needs a moment to release the previous connection after a Stop. Instead of failing (the old "glitch"
    ; after many start / stop cycles) every step is retried: busy pipe, no READY, no answer to SET_ACTIVITY.
    Loop 25 {
        attempt := A_Index
        if (rpcCancel)
            return false
        handle := RpcOpenPipe()
        if (handle) {
            if (RpcHandshake(handle, appId)) {
                rpcPipe := handle
                return true
            }
            DllCall("CloseHandle", "Ptr", handle)
        } else {
            rpcLastError := "Discord's IPC pipe was not found (is the Discord desktop app running and logged in?)."
        }
        if (attempt < 25)
            Sleep(40)      ; give Discord time to release the previous connection
    }
    return false
}

; Opens the first free discord-ipc-N pipe (0..9). A busy pipe (ERROR_PIPE_BUSY) is waited for instead of skipped.
RpcOpenPipe(nonBlocking := false) {
    Loop 10 {
        pipeName := "\\.\pipe\discord-ipc-" (A_Index - 1)
        Loop 2 {
            h := DllCall("CreateFileW", "Str", pipeName, "UInt", 0xC0000000, "UInt", 0, "Ptr", 0, "UInt", 3, "UInt", 0, "Ptr", 0, "Ptr")
            if (h != -1 && h != 0)
                return h
            if (A_LastError = 231 && !nonBlocking)   ; ERROR_PIPE_BUSY: Discord is still serving the previous client
                DllCall("WaitNamedPipeW", "Str", pipeName, "UInt", 100)
            else
                break                       ; (non-blocking: a busy pipe is simply retried by the next tick)
        }
    }
    return 0
}

; HANDSHAKE + SET_ACTIVITY on an open pipe. Frames that are not the awaited reply (PING, other events) are answered /
; skipped instead of being taken for the reply. Returns true only when Discord confirmed the activity.
RpcHandshake(handle, appId) {
    global rpcLastError, rpcCancel
    if (!RpcWriteFrame(handle, 0, '{"v":1,"client_id":"' appId '"}'))
        return false
    ready := false
    deadline := A_TickCount + 2500
    while (A_TickCount < deadline && !rpcCancel) {
        reply := RpcReadFrame(handle, 200)
        if (!IsObject(reply)) {
            if (reply = "")
                continue
            return false
        }
        if (reply["op"] = 2) {
            rpcLastError := "Discord did not accept the application id."
            return false
        }
        if (reply["op"] = 3) {
            RpcWriteFrame(handle, 4, reply["data"])
            continue
        }
        if (InStr(reply["data"], '"READY"')) {
            ready := true
            break
        }
    }
    if (!ready) {
        if (rpcLastError = "" || InStr(rpcLastError, "not found"))
            rpcLastError := "Discord did not answer the handshake."
        return false
    }

    startUnix := DateDiff(A_NowUTC, "19700101000000", "Seconds")
    nonce := "rp" A_TickCount "x" Random(1000, 9999)
    payload := '{"cmd":"SET_ACTIVITY","args":{"pid":' DllCall("GetCurrentProcessId") ',"activity":{"instance":false,"timestamps":{"start":' startUnix '}}},"nonce":"' nonce '"}'
    if (!RpcWriteFrame(handle, 1, payload))
        return false
    deadline := A_TickCount + 2500
    while (A_TickCount < deadline && !rpcCancel) {
        reply := RpcReadFrame(handle, 200)
        if (!IsObject(reply)) {
            if (reply = "")
                continue
            return false
        }
        if (reply["op"] = 2)
            return false
        if (reply["op"] = 3) {
            RpcWriteFrame(handle, 4, reply["data"])
            continue
        }
        if (!InStr(reply["data"], nonce)) {
            if (InStr(reply["data"], '"evt":"ERROR"')) {
                rpcLastError := "Discord rejected the connection."
                return false
            }
            continue                         ; some other event, not the answer to our request
        }
        if (InStr(reply["data"], '"ERROR"')) {
            rpcLastError := "Discord rejected the activity."
            return false
        }
        return true
    }
    return false
}

StopDiscordRichPresence() {
    global rpcPipe, rpcLastStopTick, rpcConnHandle
    if (rpcConnHandle)
        rpcLastStopTick := A_TickCount
    RpcConnAbort()
    if (rpcPipe) {
        rpcLastStopTick := A_TickCount
        ; Clear the activity EXPLICITLY and wait (max 150 ms) for Discord to confirm it, so the old connection's clear can never be
        ; processed after the NEXT connection's activity was set (that wiped the new game: "sometimes detected, sometimes not").
        try {
            clearNonce := "cl" A_TickCount "x" Random(1000, 9999)
            if (RpcWriteFrame(rpcPipe, 1, '{"cmd":"SET_ACTIVITY","args":{"pid":' DllCall("GetCurrentProcessId") ',"activity":null},"nonce":"' clearNonce '"}')) {
                deadline := A_TickCount + 150
                while (A_TickCount < deadline) {
                    fr := RpcReadFrame(rpcPipe, 20)
                    if (IsObject(fr)) {
                        if (fr["op"] = 3)
                            RpcWriteFrame(rpcPipe, 4, fr["data"])
                        else if (InStr(fr["data"], clearNonce))
                            break
                    } else if (fr != "")
                        break
                }
            }
        }
        ; polite goodbye (CLOSE frame) so Discord frees the pipe at once, then a short settle time before the next start
        try RpcWriteFrame(rpcPipe, 2, "{}")
        DllCall("FlushFileBuffers", "Ptr", rpcPipe)
        DllCall("CloseHandle", "Ptr", rpcPipe)
        rpcPipe := 0
        Sleep(15)
    }
}

; Answers Discord's PING frames; returns false once the pipe is closed or broken.
RpcKeepAlive() {
    global rpcPipe
    if (!rpcPipe)
        return false
    Loop 20 {
        frame := RpcReadFrame(rpcPipe, 0)
        if (!IsObject(frame))
            return (frame = "")              ; "" = nothing waiting (fine), -1 = pipe broken
        if (frame["op"] = 2)
            return false
        if (frame["op"] = 3)
            RpcWriteFrame(rpcPipe, 4, frame["data"])
    }
    return true
}

RpcWriteFrame(handle, opcode, json) {
    byteCount := StrPut(json, "UTF-8") - 1
    buf := Buffer(8 + byteCount + 1, 0)
    NumPut("UInt", opcode, buf, 0)
    NumPut("UInt", byteCount, buf, 4)
    StrPut(json, buf.Ptr + 8, byteCount + 1, "UTF-8")
    written := 0
    return DllCall("WriteFile", "Ptr", handle, "Ptr", buf, "UInt", 8 + byteCount, "UInt*", &written, "Ptr", 0, "Int") && written = 8 + byteCount
}

; Returns a Map("op", "data"), "" when nothing arrived within timeoutMs, or -1 when the pipe is broken.
RpcReadFrame(handle, timeoutMs) {
    deadline := A_TickCount + timeoutMs
    avail := 0
    Loop {
        if (!DllCall("PeekNamedPipe", "Ptr", handle, "Ptr", 0, "UInt", 0, "Ptr", 0, "UInt*", &avail, "Ptr", 0, "Int"))
            return -1
        if (avail >= 8)
            break
        if (A_TickCount >= deadline)
            return ""
        Sleep(1)
    }
    header := Buffer(8, 0), got := 0
    if (!DllCall("ReadFile", "Ptr", handle, "Ptr", header, "UInt", 8, "UInt*", &got, "Ptr", 0, "Int") || got != 8)
        return -1
    opcode := NumGet(header, 0, "UInt"), length := NumGet(header, 4, "UInt")
    if (length > 1048576)
        return -1
    data := ""
    if (length > 0) {
        bodyDeadline := A_TickCount + 2000
        Loop {
            if (!DllCall("PeekNamedPipe", "Ptr", handle, "Ptr", 0, "UInt", 0, "Ptr", 0, "UInt*", &avail, "Ptr", 0, "Int"))
                return -1
            if (avail >= length)
                break
            if (A_TickCount >= bodyDeadline)
                return -1
            Sleep(1)
        }
        body := Buffer(length, 0)
        if (!DllCall("ReadFile", "Ptr", handle, "Ptr", body, "UInt", length, "UInt*", &got, "Ptr", 0, "Int") || got != length)
            return -1
        data := StrGet(body, length, "UTF-8")
    }
    return Map("op", opcode, "data", data)
}
