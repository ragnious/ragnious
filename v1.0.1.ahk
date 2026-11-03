#Requires AutoHotkey v2.0
#SingleInstance Off

global mutexName := "Local\MyProject_AHK_SingleInstance_7A3D91", gdiplusToken := 0, mainWindowComposited := false, previewFixDropLayered := false
global appVersion := "1.0.1", appChannel := "Stable", headerText := "1.0.1 Stable", riskHeaderText := "Policy Explainer", updateInfoUrl := "https://raw.githubusercontent.com/ragnious/ragnious/refs/heads/main/version.txt"
global tosPageUrl := "https://discord.com/safety/platform-manipulation-policy-explainer"

global internetMsgLost := "Connection lost while loading game titles. Reconnect and try again."
global internetMsgBack := "Connection restored. You can continue."
global internetMsgUpdate := "Connection lost during the update. It will resume when you reconnect."
global internetMsgUpdCheck := "Connection lost while checking for updates. Reconnect and try again."
global internetMsgGeneral := "No internet connection. Reconnect to continue."
global internetMsgPaused := "Connection lost, so '{game}' was stopped. It will restart when you reconnect."
global internetMsgBackResume := "Connection restored. Restarting '{game}'…"
global internetMsgUpdPaused := "Update paused at {P}% because the connection was lost. It will resume when you reconnect."
global internetMsgUpdBack := "Connection restored. Resuming the update from {P}%."

global connLastStart := "", connLastTick := 0, connResume := "", connResumeToken := 0, connResumeDelayMs := 2500, connProbe := "", connProbeStart := 0, connProbeIdx := 0
global connLost := false, connMsg := "", connBusy := false, connFails := 0, connGraceUntil := 0, connOkTick := A_TickCount

; Status dwell: a message stays visible at least this long before a different one may replace it.
global statusMinDwellMs := 1000, statusShownTick := 0, statusPendingOn := false, statusPendingText := "", statusPendingType := "ready", stopInProgress := false
global isExiting := false, mainOutlineColor := "303030", appIsInactive := false, globalExitAppAfter := false, globalMinimizeAfter := false, hasMinimizedBefore := false
global windowDragActive := false, windowDragMouseX := 0, windowDragMouseY := 0, windowDragWinX := 0, windowDragWinY := 0, windowDragLastX := 0, windowDragLastY := 0
global mainOutlineGui := "", mainOutlineKey := "", isWindowMoving := false
global headerPrimed := false, animationActive := false, animationShowing := false, animationStart := 0, mainFadeDuration := 450, riskFadeDuration := 450, exitFadeDuration := 450

global enterRefreshHeld := false, enterRefreshBlocked := false
global lastHover := 0, keyNavMouseX := 0, keyNavMouseY := 0, isKeyActionDown := false, enterBuffered := false, enterPressCancelled := false, pressedControl := ""
global fadeInTail := false, actionLocked := false, toggleRunning := false, togglePending := 0, dropdownToggleCooldown := 0, isActionAnimating := false, currentAnimId := 0
global lastToggleDoneTick := 0, isKeyboardNavigating := false
global keepSearchStatus := false, lastSearchStatusTick := 0
global toggleGen := 0, toggleStartTick := 0, togglePendingTick := 0

global actionBtnColor := "208A4E", actionBtnLabel := "Start", actionBtnBaseFontSize := 22.5, actionBtnFontSize := 22.5, actionBtnScale := 1.0, actionBtnPosX := 188
global actionBtnPosW := 210, actionBtnPosH := 60

global exitOutlineColor := "303030", exitDlgOpen := false, exitDlgBusy := false, exitDlgActive := false, exitDlgClosing := false, exitFollowMain := false, exitFollowCap := 255
global exitFadeMode := "", exitFadeStart := 0, exitFadeFrom := 255, exitKeyHeld := false, exitKeyName := "", exitKeyCancel := false, exitLastX := 0, exitLastY := 0
global exitFadeRunning := false
global exitRetry := 0, exitClosingTick := 0, exitConfirmed := false, exitAlphaNow := 0, exitBlockKey := "", exitPrevDown := false, exitScrim := ""
global exitGui := "", exitInner := "", exitYes := "", exitNo := "", exitPressed := ""

global searchMenuGui := "", searchMenuItems := [], searchMenuPressed := 0, searchMenuLeftWasDown := false, searchMenuAnyWasDown := false
global searchMenuSwallowRightUp := false, isSearchMenuOpen := false

global rpcConnectStart := 0, rpcConnectName := "", rpcConnectAppId := "", helperLaunchStart := 0, helperLaunchId := 0, rpcLastError := "", rpcLastStopTick := 0
global rpcConnHandle := 0, rpcConnPhase := 0, rpcConnPhaseStart := 0, rpcConnNonce := "", rpcConnecting := false, helperLaunching := false, isRunning := false, targetPid := 0
global tempExePath := "", tempScriptPath := "", tempWorkDir := "", activeProcessName := "", rpcCancel := false, rpcPipe := 0, rpcStartUnix := 0, rpcResendHandle := 0
global helperThreadBusy := false
global exeEmbeddedScript := true ; embeds the launch-token-guarded helper script as the executable's default script
global exeVersionPatch := true
global exeIconPatch := true   ; embed the game's icon into the generated process exe (set false to keep the stock icon)
global exeUniquePath := true   ; the title folder gets an invisible (zero-width) tag so every launch has a path Windows has never cached an icon for; it looks like plain <Game Title> in Explorer

global statusMarqueeGui := "", statusMarqueeText := "", statusFadeOv := "", statusFadeCtl := "", statusFadeShown := false, refreshBlockMsg := ""
global refreshBlockPrevText := "", refreshBlockPrevType := "ready", currentStatusRaw := "", currentStatusColor := "208A4E", currentStatusTextOnly := "", dotBlinkStep := 0
global dotBlinkTimerRunning := false, suppressFilterStatus := false, dotPaintHex := "", statusRightPad := 25, statusDotX := 25, statusTextX := 27

global marqueeTrackText := "", marqueeTrackWidth := 0, marqueeStripDc := 0, marqueeStripBmp := 0, marqueeStripOld := 0, marqueeStripH := 0, marqueeStripDirty := true
global marqueeStripPhases := 1, marqueeViewportX := 0, marqueeViewportY := 0, marqueeViewportW := 0, marqueeViewportH := 0, marqueeViewportNeedsShow := true
global marqueeRenderedX := 0, marqueeRenderedPhase := 0, marqueeCycleText := "", marqueeCycleWidth := 0, marqueeFrames := 0
global marqueeOffset := 0.0, marqueeTimerRunning := false, marqueeLastTick := 0, marqueePauseUntil := 0

global marqueeFloorSpeed := 29.9, marqueeFloorLowSpeed := 23.9, marqueeSubpxPhases := 8, marqueeSubpxYAdjust := 0.0, marqueeSubpxUsePath := true, marqueeSubpxGamma := true
global marqueeTopSpeed := 40, marqueeMinSpeed := 30, marqueeCapSpeed := 43, marqueeLowHz := 60, marqueePeakHz := 240, marqueePxStep := 1, marqueeRefreshHz := 60
global marqueeFrameStep := 1, marqueeSubpixel := true, marqueeBudgetMs := 20, dropdownSmooth := false

global dropdownMarqueeFrames := 0, dropdownMarqueeOffset := 0.0, dropdownMarqueeIndex := -1, dropdownMarqueeLastTick := 0, dropdownMarqueePauseUntil := 0
global dropdownMarqueeTitle := "", dropdownMarqueeOverflowW := 0, dropdownMarqueeCycleW := 0, dropdownMarqueeRenderedX := 0, dropdownMarqueeTextW := 0, dropdownStripDc := 0
global dropdownStripBmp := 0, dropdownStripOld := 0, dropdownStripH := 0, dropdownStripPhases := 1, dropdownStripText := "", dropdownSubpxYAdjust := 0.0
global dropdownRenderedPhase := 0, dropdownStripDirty := true

global riskKeyHeld := false, riskKeyCancel := false, riskViewActive := false, riskViewBusy := false, riskBtnAnimating := false, riskBtnAccept := "", riskBtnCancel := ""
global riskBtnRegistry := Map(), riskAcceptBtnX := 144, riskAcceptBtnW := 137, riskAcceptBtnH := 39, riskAcceptBtnFontSize := 15, riskAcceptBtnYAdjust := 0
global riskCancelBtnX := 306, riskCancelBtnW := 137, riskCancelBtnH := 39, riskCancelBtnFontSize := 15, riskCancelBtnYAdjust := 0, riskPendingName := ""
global riskPendingAppId := "", riskPressedName := "", riskBuildDone := false, riskFadeEndTick := 0, riskGui := "", riskDeferredStatus := "", riskPrevDown := false
global riskAnimTick := 0
global riskAcceptBtnRadius := 16, riskAcceptBtnPressScale := 0.94, riskAcceptBtnPressMs := 45, riskAcceptBtnNormal := "208A4E", riskAcceptBtnHover := "279B5A", riskAcceptBtnPressed := "186B3C"
global riskCancelBtnRadius := 16, riskCancelBtnPressScale := 0.94, riskCancelBtnPressMs := 45, riskCancelBtnNormal := "B42318", riskCancelBtnHover := "D12F26", riskCancelBtnPressed := "9A1E15"
global exitYesBtnFontSize := 15, exitYesBtnRadius := 16, exitYesBtnPressScale := 0.94, exitYesBtnPressMs := 45, exitYesBtnNormal := "B42318", exitYesBtnHover := "D12F26", exitYesBtnPressed := "9A1E15"
global exitNoBtnFontSize := 15, exitNoBtnRadius := 16, exitNoBtnPressScale := 0.94, exitNoBtnPressMs := 45, exitNoBtnNormal := "208A4E", exitNoBtnHover := "279B5A", exitNoBtnPressed := "186B3C"
global actionBtnPressScale := 0.94, actionBtnPressMs := 45

global riskTitleStripPhases := 1, riskTitleRenderedPhase := 0, riskTitleCtl := "", riskTitleActive := false, riskTitleText := "", riskTitleOffset := 0.0, riskTitleLastTick := 0
global riskTitlePauseUntil := 0, riskTitleOverflowW := 0, riskTitleCycleW := 0, riskTitleTrackW := 0, riskTitleInset := 8, riskTitleRenderedX := 0, riskTitleFrames := 0
global riskTitleStripDc := 0, riskTitleStripBmp := 0, riskTitleStripOld := 0, riskTitleStripH := 0, riskTitleStripDirty := true, riskTitleSideInset := 25, riskTitleVNudge := 0

global riskTosCy := 28.0
global riskTosInkOff := 13.0
global riskLineGui := "", riskLineCtl := "", riskTosGui := "", riskTosCtl := "", riskWarnSign := "", riskWarnBlinkStep := 0, riskWarnBmps := [], riskWarnShown := 0
global riskHandCtl := "", riskHandBmp := 0, riskIconCtl := "", riskIconHbm := 0, riskIconKey := "", riskIconReal := false, riskIconPx := 0, riskIconVNudge := 0
global riskIconTitleGap := 12, riskIconSize := 32, riskIconMatchCenterParity := false

global riskGapLineToTitle := 20, riskGapTitleToId := 5, riskGapIdToDesc := 13, riskGapDescToWarn := 13, riskGapWarnToButtons := 14, riskContentTopY := 131

global updOverlay := "", updOverlayCtl := "", updOverlayShown := false, updOverlayGeom := "", tosHoverFrom := 0.0, tosHoverTo := 0, tosHoverStartedAt := 0
global tosHoverDuration := 130, tosRippleStart := 0, tosRippleDuration := 550, tosIconPressed := false

global updIconPx := 42, updIconHoverHex := "FFFFFF", updIconDx := 0.0, updIconX := 0, updIconW := 18, updSpinAngle := 0.0, updSpinStart := 0, updSpinStopFrom := 0.0
global updSpinStopDur := 1.0, updSpinStopStart := 0.0, updSpinFinishing := false, updSpinGrey := false, updSpinStopAt := 0.0, updMinCheckMs := 1500, updMinDownloadMs := 3000
global updSepX := 0, updSepW := 22, hdrBarRows := 0, hdrBarCols := [], hdrBarAdv := 0, hdrBarShift := 0, updSpinning := false, hdrOk := false, hdrTextY := 0
global hdrCenterY := 0.0, updSpinDuration := 2600

global updBgCurrent := "000000", updBgFrom := "000000", updBgTo := "000000", updBgStartedAt := 0, updBgDuration := 130
global updateReq := "", updateReqStart := 0, updateState := "idle", updateInfo := "", updateHovered := false, updateFile := "", updRetried := false, updNetFailTick := 0
global updGot := 0, updTotal := 0, updResumable := false, updResumePending := false, updValidator := "", updDlDone := false, updLastPct := -1
global updDlUrl := "", updDlStart := 0, updFreshTried := false, updChunkRetries := 0, updHoldStatusUntil := 0, updChunkSize := 524288

global rowIconPx := 32, rowIconTextGap := 9, gameIconMasterPx := 32, gameIconFetchPx := 128, gameIconRadiusRatio := 0.25, gameIconHashes := Map(), gameIconBitmaps := Map()
global gameIconState := Map(), gameIconNoIcon := Map(), gameIconNoIconDays := 1, gameIconUnknownFile := "", gameIconUpdateTried := Map(), gameIconBitmapCap := 20000

global gameIconQueue := [], gameIconJobs := [], gameIconPrefetch := [], gameIconArrived := [], gameIconMaxJobs := 32, gameIconBulkList := "", gameIconBulkPos := 1
global gameIconBulkStartAt := 0, gameIconRetryAt := 0

global gameIconFileNames := Map(), gameIconPackLoc := Map(), gameIconPackSegs := [], gameIconPackPend := Map(), gameIconSegCache := Map(), gameIconSegOrder := []
global gameIconPackDead := 0, gameIconPackNeedsRewrite := false, gameIconComp := 0, gameIconDecomp := 0, gameIconMig := "", gameIconIdxReady := false, gameIconIdxStage := 0
global gameIconIdxSegs := "", gameIconIdxSegPos := 1, gameIconIdxLines := "", gameIconIdxLinePos := 1, gameIconIdxOff := 0, gameIconDir := A_AppData "\Ragnious\icons"
global gameIconPackPath := gameIconDir "\icons.pack", gameIconUnknownKey := Chr(7) "unknown"

global searchIconCtl := "", searchIconKey := "", searchIconReal := false, searchIconOff := 0, searchIconSize := 32, searchIconTextGap := 9, searchIconX := 10

global rowBufDc := 0, rowBufBmp := 0, rowBufOld := 0, rowBufW := 0, rowBufH := 0, rowIconsEnabled := true, unknownIconMaster := 0, rowTextCache := Map()

global refreshOverlay := "", refreshOverlayCtl := "", refreshOverlayShown := false, refreshOverlayGeom := "", refreshSepX := 409, refreshSepY := 1, refreshSepW := 1
global refreshSepH := 49, refreshBtnX := 410, refreshBtnY := 1, refreshBtnW := 51, refreshBtnH := 49, refreshKickStart := 0, refreshKickDuration := 550

global refreshButtonBgCurrent := "000000", refreshButtonBgFrom := "000000", refreshButtonBgTo := "000000", refreshButtonAnimationStartedAt := 0
global refreshButtonAnimationDuration := 130, refreshArrowAngle := 0.0, refreshArrowAnimating := false, refreshArrowStartedAt := 0, refreshArrowDuration := 2600
global gameFetchPending := false, gameFetchStartedAt := 0, refreshIsLocked := false, refreshShowCheck := false, asyncXhr := "", lastGameRefreshAt := 0, refreshBgBrushes := Map()

global minBtnPressScale := 0.78, minBtnPressDuration := 90, minBtnReleaseDuration := 170, closeBtnPressScale := 0.78, closeBtnPressDuration := 90, closeBtnReleaseDuration := 170, donateBtnPressScale := 0.78, donateBtnPressDuration := 90, donateBtnReleaseDuration := 170
global scrollUpBtnPressScale := 0.78, scrollUpBtnPressDuration := 90, scrollDownBtnPressScale := 0.78, scrollDownBtnPressDuration := 90, iconAnimState := Map()
global minBtnBg := "000000", closeBtnBg := "000000", donateBtnBg := "000000"
global minStroke := 2, closeStroke := 2, donateStroke := 1.3, updateStroke := 1.8, refreshRingStroke := 1.8, refreshCheckStroke := 1.8
global scrollUpStroke := 1.8, scrollDownStroke := 1.8

global selectorScrollUpBtn := "", selectorScrollDownBtn := "", selectorScrollThumb := "", selectorScrollThumbTrack := "", selectorScrollSeparator := ""
global selectorScrollHoverTarget := "", thumbDragStartY := 0, thumbDragStartThumbY := 0, thumbDragTrackTopY := 0, thumbDragTrackTravel := 0
global scrollContinuousAction := "", scrollContinuousNextTick := 0, selectorListFrozen := false
global wheelPendingLines := 0, isDraggingThumb := false

global scrollUpBtnReleaseDuration := 170, scrollDownBtnReleaseDuration := 170, scrollUpBtnW := 18, scrollUpBtnH := 20, scrollUpBtnTopInset := 0, scrollDownBtnW := 18
global scrollDownBtnH := 20, scrollDownBtnBottomInset := 21, scrollTrackW := 18, scrollTrackTopInset := 20, scrollTrackBottomInset := 21, scrollThumbW := 6
global scrollThumbRightInset := 13, scrollSepW := 1, scrollSepRightInset := 19, scrollListReserveW := 18

global selectorUpdating := false, dropdownPaintLockDepth := 0, dropdownPaintLockActive := false
; Typing pipeline: keystrokes are coalesced (gsApplyDelayMs) and results are cached per query (filterCache*).
global searchEditHold := false, gsApplyDelayMs := 35, gsApplying := false, gsDirty := false, filterCacheQuery := "", filterCacheList := "", filterCacheSrc := ""
global emptyQueryTitles := "", emptyQuerySource := "", selectorRowHeight := 37, selectorRowSep1 := "", selectorRowSep2 := "", selectorHoverProgress := 1.0
global selectorPressColorCurrent := "3A3A3A", selectorPressColorFrom := "3A3A3A", selectorPressColorTo := "5C5C5C"
global selectorPressStartedAt := 0, selectorPressDuration := 75, selectorPressPhase := "idle", selectorList := "", selectorDisplayedOptions := [], selectorHoveredIndex := -1
global selectorPreviousHoveredIndex := -1, selectorMouseLeaveTracking := false, selectorPressedIndex := -1, selectorClickIndex := -1, selectorCommitIndex := -1
global dropdownRowHeightPx := 39, dropdownGapBelowSearch := 0, rowRightPad := 9, rowLeftInset := 9

global searchEditX := 1, searchEditW := 398, isGameSearchFocused := false, selectorFrameGui := "", selectorPopup := "", prewarmBuildActive := false, processOptions := []
global gameAppIds := Map(), gameExecutables := Map(), gameExeArgs := Map(), selectedProcessTitle := "", gameSearchHint := "Search game titles (e.g., Minecraft)"
global isShowingGameSearchHint := true, isFilteringGameList := false, isSelectingGame := false

global verTextX := 24, verTextY := 1, verTextW := 120, verTextH := 55, updSepY := 1, updSepH := 55, updIconY := 1, updIconH := 55, titleBarX := 144, titleBarY := 1
global titleBarW := 269, titleBarH := 56, minBtnX := 471, minBtnY := 1, minBtnW := 58, minBtnH := 55, closeBtnX := 529, closeBtnY := 1, closeBtnW := 57, closeBtnH := 55, donateBtnX := 413, donateBtnY := 1, donateBtnW := 58, donateBtnH := 55
global appNameX := 0, appNameY := 50, appNameW := 587, appNameH := 74, searchFrameX := 61, searchFrameW := 464, searchFrameH := 53, searchInnerX := 62, searchInnerY := 181
global searchInnerW := 462, searchInnerH := 51, searchEditVNudge := 0, dropdownRowVNudge := 0, searchRightPad := 9, mainSearchY := 180, mainActionY := 273, statusDotY := 358
global statusDotH := 42, statusTextY := 358, statusTextH := 42, appTaglineH := 42, searchTextLeftInset := 9

DllCall("SetLastError", "UInt", 0)
mutexHandle := DllCall("CreateMutexW", "Ptr", 0, "Int", 0, "Str", mutexName, "Ptr")
if (A_LastError = 183) {
    DllCall("CloseHandle", "Ptr", mutexHandle)
    MsgBox("The application is already running in the background.", "Ragnious: Discord Quests Completer", "Iconi")
    ExitApp()
}
while (!IsInternetAvailable()) {
    if (MsgBox("No internet connection detected. Check your connection and retry.", "Ragnious: Discord Quests Completer", "RetryCancel Iconi") != "Retry")
        ExitApp()
}

CleanupOldVersion(A_ScriptFullPath ".old")
try FileDelete(A_AppData "\Ragnious\update.download")
try FileDelete(A_AppData "\Ragnious\update.chunk")
CleanStaleHelperDirs()
for i, arg in A_Args
    if (arg = "/cleanup" && i < A_Args.Length)
        CleanupOldVersion(A_Args[i + 1])

Persistent()
DllCall("winmm\timeBeginPeriod", "UInt", 1)
try ProcessSetPriority("AboveNormal")

gdiplusStartupInput := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
NumPut("UInt", 1, gdiplusStartupInput, 0)
gdiplusTokenBuffer := Buffer(A_PtrSize, 0)
if (DllCall("gdiplus\GdiplusStartup", "Ptr", gdiplusTokenBuffer, "Ptr", gdiplusStartupInput, "Ptr", 0, "UInt") = 0)
    gdiplusToken := NumGet(gdiplusTokenBuffer, 0, "UPtr")

InitMarqueeTiming()
OnMessage(0x8001, MarqueeKickMsg)

mainGui := Gui("-Caption +E0x80000" . (mainWindowComposited ? " +E0x02000000" : ""), "Ragnious")
mainGui.BackColor := "000000"
mainGui.OnEvent("Close", CloseApplication)
updateBtn := "", updateSep := "", updateIcon := ""
versionText := mainGui.Add("Text", "x24 y0 w120 h56 Background000000 cA0A0A0 +0x200 +0x100", appVersion " " appChannel)
versionText.SetFont("s12 Norm", "Segoe UI Semibold")
versionText.Opt("+0x000D")
titleBar := mainGui.Add("Text", "x144 y0 w319 h57 Background000000 cA0A0A0 +0x200 +0x100", "")
titleBar.SetFont("", "Segoe UI")
updateSep := mainGui.Add("Text", "x144 y0 w22 h56 Center Background000000 cA0A0A0 +0x200 +0x100", "|")
updateSep.SetFont("s12 Norm", "Segoe UI Semibold")
updateSep.Opt("+0x000D")
updateIcon := mainGui.Add("Text", "x166 y0 w36 h56 Background000000 +0x200 +0x100", "")
updateIcon.Opt("+0x000D")
updateIcon.Text := ""
updateBtn := updateIcon
minBtn := mainGui.Add("Text", "x371 y0 w58 h56 Center +0x200 +0x100 Background000000 cFFFFFF", "—")
minBtn.SetFont("s16", "Segoe UI")
minBtn.Opt("+0x000D")
minBtn.Text := ""
closeBtn := mainGui.Add("Text", "x429 y0 w58 h56 Center +0x200 +0x100 Background000000 cFFFFFF", "✕")
closeBtn.SetFont("s16", "Segoe UI")
closeBtn.Opt("+0x000D")
closeBtn.Text := ""
donateBtn := mainGui.Add("Text", "x313 y0 w58 h56 Center +0x200 +0x100 Background000000 cFFFFFF", "")
donateBtn.SetFont("s16", "Segoe UI")
donateBtn.Opt("+0x000D")
donateBtn.Text := ""
minBtn.Opt("+0x04000000")
closeBtn.Opt("+0x04000000")
donateBtn.Opt("+0x04000000")
appName := mainGui.Add("Text", "x0 y50 w587 h74 Center +0x200 BackgroundTrans cFFFFFF", "RAGNIOUS")
appName.SetFont("s40 Bold", "Segoe UI")
taglineY := (50 + 74 - 18) + 3
appTagline := mainGui.Add("Text", Format("x0 y{} w587 h42 Center +0x200 BackgroundTrans cA0A0A0", taglineY), "Discord Quests Completer")
appTagline.SetFont("s16 Norm", "Segoe UI Semibold")
frameGui := Gui("-Caption -Border -E0x200 +0x40000000", "")
frameGui.Opt("+Parent" mainGui.Hwnd)
frameGui.BackColor := "FFFFFF"
; WS_CLIPSIBLINGS: the white frame sits underneath the black search box (selectGui). Without this style every
; paint of the frame (WM_ERASEBKGND, RedrawWindow in SettleRepaint at the end of the fade-in, GetDC fills)
; could draw straight over the box and its text for a moment = the one-time flicker right after startup.
frameGui.Opt("+0x04000000")
RemoveNativeOutline(frameGui.Hwnd)

selectGui := Gui("-Caption -Border -E0x200 +0x40000000 +0x02000000", "")
selectGui.Opt("+Parent" mainGui.Hwnd)
selectGui.BackColor := "000000"
RemoveNativeOutline(selectGui.Hwnd)
InitUpdaterLayout()

processSelect := selectGui.Add("Edit", "x0 y0 w382 h49 -Theme -Border -E0x200 -Multi -VScroll -HScroll cFFFFFF Background000000", gameSearchHint)
processSelect.SetFont("s12 cFFFFFF", "Segoe UI")
searchEditBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00000000, "Ptr")
scrollHoverBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00303030, "Ptr")
refreshLockedBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00555555, "Ptr")
processSelect.OnEvent("Focus", OnGameSearchFocus)
processSelect.OnEvent("LoseFocus", OnGameSearchLoseFocus)
processSelect.OnEvent("Change", OnGameSearchChange)
RemoveNativeOutline(processSelect.Hwnd)
processSelect.Opt("+0x04000000")
SubclassSearchEditDoubleBuffer()
searchIconCtl := selectGui.Add("Text", "x0 y0 w1 h1 +0xE +0x04000000 Hidden", "")
DllCall("User32\SetWindowPos", "Ptr", searchIconCtl.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")
refreshSeparator := selectGui.Add("Text", "x407 y1 w1 h47 BackgroundFFFFFF", "")
refreshButton := selectGui.Add("Text", "x408 y0 w52 h49 Center +0x200 +0x100 -Theme -Border cFFFFFF", "↻")
refreshButton.SetFont("s18", "Segoe UI")
refreshButton.Opt("+0x000D")
refreshButton.Text := ""
RemoveNativeOutline(refreshButton.Hwnd)

actionGui := Gui("-Caption +0x40000000", "")
actionGui.Opt("+Parent" mainGui.Hwnd)
actionGui.BackColor := "000000"
actionBtn := actionGui.Add("Text", "x0 y0 w210 h60 -Theme +0x100", "Start")
actionBtn.SetFont("s" Round(actionBtnBaseFontSize) " Bold", "Segoe UI")
actionBtn.Opt("+0x000D")
statusDot := mainGui.Add("Text", "x0 y0 w16 h42 +0x200 BackgroundTrans c208A4E", "●")
statusDot.SetFont("s12 Norm", "Segoe UI Semibold")
statusDot.Opt("+0x000D")
statusText := mainGui.Add("Text", "x0 y0 w453 h42 +0x200 BackgroundTrans c208A4E", "Ready. Select a game title to begin.")
statusText.SetFont("s12 Norm", "Segoe UI Semibold")
global statusGlyph, statusGlyphOn := false, statusGlyphX := 0, statusDisplayText := ""
global showAllMsg := "", showAllPrevText := "", showAllPrevType := "ready"
statusGlyph := mainGui.Add("Text", "x0 y0 w16 h16 +0x200 BackgroundTrans Hidden", "")
statusGlyph.Opt("+0x000D")

statusMarqueeGui := Gui("-Caption -Border -E0x200 +0x40000000", "")
statusMarqueeGui.Opt("+Parent" mainGui.Hwnd)
statusMarqueeGui.BackColor := "000000"
RemoveNativeOutline(statusMarqueeGui.Hwnd)
statusMarqueeText := statusMarqueeGui.Add("Text", "x0 y0 w468 h42 +0x000D", "")
statusMarqueeText.SetFont("s12 Norm", "Segoe UI Semibold")

A_TrayMenu.Delete()
A_TrayMenu.Add("Show", RestoreWindow)
A_TrayMenu.Add("Hide", HideWindowFromTray)
A_TrayMenu.Add("Exit", CloseApplication)
A_TrayMenu.Default := "Show"
A_TrayMenu.ClickCount := 2
isWindowVisible := false
helperFocusPollUntil := 0
SetTimer(UpdateButtonHover, 25)
SetTimer(ReleaseWatchdog, 20)
SetTimer(PollDropdownHover, 15)
SetTimer(MarqueeMaster, 8)
isMarqueeActive := false

Critical("Off")
SetWindowOpacity(0)
mainGui.Show("NA w587 h413")
PositionChildWindows()
ApplyAllCorners()
AnimateVisibility(true)
SetStatus("Ready. Select a game title to begin.", "ready")
SetTimer(ConnectionWatchTick, 1500)
HeaderRepaintAll()
SetTimer(HeaderGuardTick, 1000)

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
OnMessage(0x0203, HandleActionDoubleClick)
OnMessage(0x0100, OnWmKeyDown)
OnMessage(0x0102, OnWmChar)
OnMessage(0x0021, OnMouseActivate)
OnMessage(0x0204, HandleRightButtonDown)
OnMessage(0x0205, HandleRightButtonUp)
OnMessage(0x007B, HandleContextMenuMsg)
OnMessage(0x0014, OnEraseBackground)
OnMessage(0x0318, PrintClientFrame)
OnMessage(0x0317, PrintClientFrame)
OnMessage(0x0084, RefreshOverlayHitTest)

SetTimer(PrewarmDropdown, -900)
GameIconNetworkTune()
OnExit(OnExitStopProcess)
OnExit(GameIconPackOnExit)
SetTimer(GameIconIndexTick, -300)

refreshButton.Redraw()
minBtn.Redraw()
closeBtn.Redraw()
donateBtn.Redraw()
RepaintActionButtonNoErase()

#HotIf ExitDlgKeysLive()
Enter::ExitKeyDown("Enter")
NumpadEnter::ExitKeyDown("Enter")
Enter Up::ExitKeyUp()
NumpadEnter Up::ExitKeyUp()
y::ExitKeyDown("y")
n::ExitKeyDown("n")
Escape::ExitKeyDown("Escape")
#HotIf
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
    if (EnterShouldPressRefresh()) {
        RefreshKeyDown()
        return
    }
    TriggerActionDown()
}
Enter Up:: {
    global enterPressCancelled
    if (!GetKeyState("Enter", "P") && !GetKeyState("NumpadEnter", "P"))
        enterPressCancelled := false
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
    if (enterRefreshHeld) {
        RefreshKeyUp()
        return
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
    if (EnterShouldPressRefresh()) {
        RefreshKeyDown()
        return
    }
    TriggerActionDown()
}
NumpadEnter Up:: {
    global enterPressCancelled
    if (!GetKeyState("Enter", "P") && !GetKeyState("NumpadEnter", "P"))
        enterPressCancelled := false
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
    if (enterRefreshHeld) {
        RefreshKeyUp()
        return
    }
    TriggerActionUp()
}
+Enter::return
+NumpadEnter::return
Tab::
+Tab:: {
    if (!IsGameSearchControlFocused())
        FocusGameSearchFromKeyboard()
}
!F4::CloseApplication()
#HotIf
#HotIf IsPressCancellable()
Escape:: {
    global pressedControl, riskPressedName, riskKeyHeld, riskKeyCancel, enterBuffered, enterPressCancelled, isKeyActionDown
    if (GetKeyState("LButton", "P")) {
        if (pressedControl != "")
            CancelMousePress()
        else if (riskViewActive && riskPressedName != "" && !riskKeyHeld)
            riskKeyCancel := true
    }
    if ((GetKeyState("Enter", "P") || GetKeyState("NumpadEnter", "P")) && (isKeyActionDown || enterBuffered || riskKeyHeld || enterRefreshHeld)) {
        enterPressCancelled := true
        enterBuffered := false
        if (enterRefreshHeld)
            RefreshKeyCancel()
        else if (riskViewActive) {
            if (riskKeyHeld)
                riskKeyCancel := true
        } else
            CancelActionPress()
    }
}
#HotIf
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
#HotIf
#HotIf IsProcessSelectorOpen() && IsMyGuiActive() && IsMouseOverDropdownArea()
WheelUp:: {
    QueueWheelScroll(-1)
}
WheelDown:: {
    QueueWheelScroll(1)
}
#HotIf
#HotIf isSearchMenuOpen
Escape::CloseSearchMenu()
#HotIf
#HotIf IsSet(riskViewActive) && riskViewActive && IsMyGuiActive()
Escape::RpcRiskDecline()
#HotIf

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

IsWindowValid(ctrl) {
    try {
        return IsObject(ctrl) && ctrl.Hwnd && DllCall("User32\IsWindow", "Ptr", ctrl.Hwnd, "Int")
    } catch {
        return false
    }
}

EaseOutCubic(t) => 1 - (1 - t) ** 3

EaseOutBack(t) {
    c1 := 1.70158, c3 := c1 + 1
    return 1 + c3 * (t - 1) ** 3 + c1 * (t - 1) ** 2
}

CreateIconPen(penWidth) {
    penBuffer := Buffer(A_PtrSize, 0)
    if (DllCall("gdiplus\GdipCreatePen1", "UInt", 0xFFFFFFFF, "Float", penWidth, "Int", 2, "Ptr", penBuffer, "UInt") != 0)
        return 0
    pen := NumGet(penBuffer, 0, "Ptr")
    DllCall("gdiplus\GdipSetPenStartCap", "Ptr", pen, "Int", 2, "UInt")
    DllCall("gdiplus\GdipSetPenEndCap", "Ptr", pen, "Int", 2, "UInt")
    DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", pen, "Int", 2, "UInt")
    return pen
}

IsMyGuiActive() {
    global mainGui, frameGui, selectGui, actionGui, selectorFrameGui, selectorPopup, isExiting, exitDlgActive, targetPid
    if ((IsSet(isExiting) && isExiting) || !IsSet(mainGui) || !mainGui)
        return false
    if (exitDlgActive)
        return false
    if (IsContextMenuOpen())
        return false
    curr := WinExist("A")
    if (curr && IsSet(targetPid) && targetPid) {
        fgPid := 0
        DllCall("User32\GetWindowThreadProcessId", "Ptr", curr, "UInt*", &fgPid, "UInt")
        if (fgPid = targetPid)
            return true
    }
    return (curr = mainGui.Hwnd || curr = frameGui.Hwnd || curr = selectGui.Hwnd || curr = actionGui.Hwnd || (IsWindowValid(selectorFrameGui) && curr = selectorFrameGui.Hwnd) || (IsWindowValid(selectorPopup) && curr = selectorPopup.Hwnd))
}

ReclaimFocusFromHelper(*) {
    global targetPid, mainGui, isExiting, isWindowVisible, helperFocusPollUntil
    if (A_TickCount > helperFocusPollUntil || isExiting || !targetPid) {
        SetTimer(ReclaimFocusFromHelper, 0)
        return
    }
    if (!isWindowVisible || !IsWindowValid(mainGui) || DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int"))
        return
    fg := DllCall("User32\GetForegroundWindow", "Ptr"), pid := 0
    if (fg)
        DllCall("User32\GetWindowThreadProcessId", "Ptr", fg, "UInt*", &pid, "UInt")
    if (fg && pid = targetPid)
        FocusMainWindowAfterFade()
}

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

FrameStamp() {
    vc := GetDwmRefreshCount()
    return vc ? vc : NowMs()
}

PaintControlDirect(ctl, drawFunc) {
    global minBtn, closeBtn, donateBtn
    if (!IsWindowValid(ctl))
        return false
    if (!DllCall("User32\IsWindowVisible", "Ptr", ctl.Hwnd, "Int"))
        return false
    rc := Buffer(16, 0)
    if (!DllCall("User32\GetClientRect", "Ptr", ctl.Hwnd, "Ptr", rc, "Int"))
        return false
    clipSib := (IsWindowValid(minBtn) && ctl.Hwnd = minBtn.Hwnd) || (IsWindowValid(closeBtn) && ctl.Hwnd = closeBtn.Hwnd) || (IsWindowValid(donateBtn) && ctl.Hwnd = donateBtn.Hwnd)
    hdc := clipSib ? DllCall("User32\GetDCEx", "Ptr", ctl.Hwnd, "Ptr", 0, "UInt", 0x12, "Ptr") : DllCall("User32\GetDC", "Ptr", ctl.Hwnd, "Ptr")
    if (!hdc)
        return false
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    fake := Buffer(itemHwndOffset + A_PtrSize * 2 + 16 + A_PtrSize, 0)
    NumPut("Ptr", hdc, fake, itemHwndOffset + A_PtrSize)
    rectOffset := itemHwndOffset + A_PtrSize * 2
    NumPut("Int", 0, "Int", 0, "Int", NumGet(rc, 8, "Int"), "Int", NumGet(rc, 12, "Int"), fake, rectOffset)
    drawFunc(fake)
    DllCall("User32\ReleaseDC", "Ptr", ctl.Hwnd, "Ptr", hdc)
    DllCall("Gdi32\GdiFlush")
    return true
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

GetMainLayoutY(mainHeight, &textY, &actionY) {
    global mainSearchY, mainActionY
    textY := mainSearchY, actionY := mainActionY
}

MoveCtlIfChanged(ctl, x, y, w, h) {
    try {
        ctl.GetPos(&cx, &cy, &cw, &ch)
        if (cx = x && cy = y && cw = w && ch = h)
            return
    }
    ctl.Move(x, y, w, h)
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

GetTextInk(text, fontName, pointSize, weight := 400) {
    m := Map("a", 0, "c", 0, "adv", GetTextWidth(text, fontName, pointSize, weight))
    hdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
    if (!hdc)
        return m
    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(pointSize * DllCall("Gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 90) / 72), "Int", 0, "Int", 0, "Int", 0, "Int", weight, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", fontName, "Ptr")
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
    abc := Buffer(12, 0)
    first := Ord(SubStr(text, 1, 1)), last := Ord(SubStr(text, -1))
    if (DllCall("Gdi32\GetCharABCWidthsW", "Ptr", hdc, "UInt", first, "UInt", first, "Ptr", abc, "Int"))
        m["a"] := NumGet(abc, 0, "Int")
    if (DllCall("Gdi32\GetCharABCWidthsW", "Ptr", hdc, "UInt", last, "UInt", last, "Ptr", abc, "Int"))
        m["c"] := NumGet(abc, 8, "Int")
    DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)
    DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return m
}

HdrCompatBitmap(w, h) {
    sdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
    bmp := 0
    if (sdc) {
        bmp := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", sdc, "Int", w, "Int", h, "Ptr")
        DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", sdc)
    }
    return bmp
}

FillWhite(hdc, hwnd) {
    rc := Buffer(16, 0)
    DllCall("User32\GetClientRect", "Ptr", hwnd, "Ptr", rc)
    brush := DllCall("Gdi32\GetStockObject", "Int", 0, "Ptr")
    DllCall("User32\FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", brush)
}

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

GetFontCenterMetrics(hdc, &lineH, &capCenter) {
    tm := Buffer(80, 0)
    DllCall("Gdi32\GetTextMetricsW", "Ptr", hdc, "Ptr", tm)
    lineH := NumGet(tm, 0, "Int")
    ascent := NumGet(tm, 4, "Int")
    internalLeading := NumGet(tm, 12, "Int")
    capCenter := ascent - ((lineH - internalLeading) * 0.7) / 2
    gm := Buffer(20, 0), mat := Buffer(16, 0)
    NumPut("Int", 0x10000, mat, 0), NumPut("Int", 0x10000, mat, 12)
    if (DllCall("Gdi32\GetGlyphOutlineW", "Ptr", hdc, "UInt", 72, "UInt", 0, "Ptr", gm, "UInt", 0, "Ptr", 0, "Ptr", mat, "UInt") != 0xFFFFFFFF) {
        inkH := NumGet(gm, 4, "UInt"), inkTop := NumGet(gm, 12, "Int")
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

FontEmPx(pointSize) {
    return pointSize * A_ScreenDPI / 72
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

MeasureWrappedTextHeight(text, width, pointSize, weight := 400, face := "Segoe UI") {
    hdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
    if (!hdc)
        return 22
    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(pointSize * DllCall("Gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 90) / 72), "Int", 0, "Int", 0, "Int", 0, "Int", weight, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", face, "Ptr")
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
    rc := Buffer(16, 0)
    NumPut("Int", width, rc, 8)
    DllCall("User32\DrawTextW", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", rc, "UInt", 0x00000410)
    height := NumGet(rc, 12, "Int")
    DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)
    DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return height
}

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
    m := lineCount - 1
    breaks := []
    Loop m
        breaks.Push(A_Index)
    bestBreaks := breaks.Clone(), bestRange := 1.0e9, bestMax := 1.0e9
    Loop {
        hi := 0, lo := 1.0e9, prev := 0, firstW := 0, lastW := 0
        Loop lineCount {
            last := (A_Index <= m) ? breaks[A_Index] : n
            lineW := prefix[last + 1] - prefix[prev + 1] - spaceW
            hi := Max(hi, lineW), lo := Min(lo, lineW)
            if (A_Index = 1)
                firstW := lineW
            lastW := lineW
            prev := last
        }
        score := (topBias > 0) ? Abs((firstW - lastW) - topBias) : hi - lo
        if (score < bestRange || (score = bestRange && hi < bestMax)) {
            bestRange := score, bestMax := hi, bestBreaks := breaks.Clone()
        }
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
            DllCall("User32\DrawTextW", "Ptr", memDc, "Str", text, "Int", -1, "Ptr", rc, "UInt", 0x00000901)
            DllCall("Gdi32\GdiFlush")
            first := -1, last := -1
            pairs := w // 2
            Loop h {
                y := A_Index - 1
                rowPtr := bits + y * w * 4
                hit := false
                Loop pairs {
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

IsContextMenuOpen() {
    global isSearchMenuOpen
    return (isSearchMenuOpen || WinExist("ahk_class #32768")) ? true : false
}

OnMouseActivate(wParam, lParam, msg, hwnd) {
    global isExiting, isGameSearchFocused
    if (ExitDlgOwns(hwnd))
        return 3
    if (isExiting || !isGameSearchFocused)
        return
    if (IsMouseOverScrollArrowButton() || IsMouseOverDropdownArea())
        return 3
}

OnEraseBackground(wParam, lParam, msg, hwnd) {
    global refreshButton, minBtn, closeBtn, donateBtn, selectorList, selectorDisplayedOptions, selectorRowHeight
    global versionText, updateSep, updateIcon, frameGui, selectorFrameGui
    if (IsWindowValid(selectorFrameGui) && hwnd = selectorFrameGui.Hwnd) {
        FillWhite(wParam, hwnd)
        return 1
    }
    if (IsWindowValid(versionText) && hwnd = versionText.Hwnd)
        return 1
    if (IsWindowValid(updateSep) && hwnd = updateSep.Hwnd)
        return 1
    if (IsWindowValid(updateIcon) && hwnd = updateIcon.Hwnd)
        return 1
    if (IsWindowValid(frameGui) && hwnd = frameGui.Hwnd) {
        FillWhite(wParam, hwnd)
        return 1
    }
    if (IsObject(selectorList) && IsWindowValid(selectorList) && hwnd = selectorList.Hwnd) {
        rc := Buffer(16, 0)
        DllCall("User32\GetClientRect", "Ptr", hwnd, "Ptr", rc)
        topIndex := SendMessage(0x018E, 0, 0, hwnd)
        if (topIndex < 0)
            topIndex := 0
        usedBottom := (selectorDisplayedOptions.Length - topIndex) * selectorRowHeight
        if (usedBottom < NumGet(rc, 12, "Int")) {
            NumPut("Int", Max(0, usedBottom), rc, 4)
            brush := DllCall("Gdi32\GetStockObject", "Int", 4, "Ptr")
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
    if (IsWindowValid(donateBtn) && hwnd = donateBtn.Hwnd)
        return 1
}

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
    DllCall("User32\SetWindowPos", "Ptr", mainGui.Hwnd, "Ptr", 0, "Int", newX, "Int", newY, "Int", 0, "Int", 0, "UInt", 0x0015, "Int")
    SyncRefreshOverlay()
    SyncUpdateOverlay()
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
    global mainGui, isExiting, isWindowVisible, frameGui, selectGui, actionGui
    if (isExiting || !IsSet(mainGui) || !mainGui)
        return
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
    global mainGui, actionGui, isExiting, isWindowVisible, frameGui, selectGui, appIsInactive, riskViewBusy, riskFadeEndTick
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
        if (riskViewBusy || A_TickCount - riskFadeEndTick < 500)
            return
        ResumeMarquee()
        SetTimer(ActivationRepaint, -15)
    }
}

ActivationRepaint(*) {
    global mainGui, minBtn, closeBtn, donateBtn, statusDot, isExiting, isWindowVisible
    global animationActive
    if (isExiting || animationActive || !isWindowVisible || !IsWindowValid(mainGui) || DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int"))
        return
    PositionChildWindows()
    HeaderRepaintAll()
    PaintSearchFrameDirect()
    RepaintRefreshButtonNoErase()
    RepaintActionButtonNoErase()
    PaintControlDirect(minBtn, (d) => DrawTopButton(d, "min"))
    PaintControlDirect(closeBtn, (d) => DrawTopButton(d, "close"))
    PaintControlDirect(donateBtn, (d) => DrawTopButton(d, "donate"))
    PaintControlDirect(statusDot, DrawStatusDot)
}

OnSetCursor(wParam, lParam, msg, hwnd) {
    global minBtn, closeBtn, donateBtn, refreshButton, processSelect, selectorList, actionBtn, actionGui, mainGui, isExiting, refreshIsLocked
    global selectorPopup, selectorScrollUpBtn, selectorScrollDownBtn, selectorScrollThumb, selectorScrollThumbTrack, selectorScrollSeparator, selectorDisplayedOptions
    if (RiskDialogCursor(hwnd))
        return true
    if (ExitDlgCursor(hwnd))
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
    if (IsUpdateBtnHwnd(hovered)) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", UpdateBtnClickable() ? 32649 : 32648, "Ptr"))
        return true
    }
    if (IsWindowValid(refreshButton) && hovered = refreshButton.Hwnd) {
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
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32648, "Ptr"))
        return true
    }
    if (hovered = minBtn.Hwnd || hovered = closeBtn.Hwnd || hovered = donateBtn.Hwnd || hovered = actionBtn.Hwnd || hovered = actionGui.Hwnd) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32649, "Ptr"))
        return true
    }
    DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32512, "Ptr"))
    return true
}

WmCtlColorStatic(wParam, lParam, msg, hwnd) {
    global appName, appTagline, statusText, statusDot, isExiting, refreshSeparator, versionText, titleBar
    global selectorPopup, selectorScrollThumb, selectorScrollThumbTrack, selectorScrollSeparator, selectorScrollHoverTarget, searchEditBrush, scrollHoverBrush, selectorDisplayedOptions
    global refreshButton, refreshIsLocked, selectorRowSep1, selectorRowSep2, refreshButtonBgCurrent
    if (isExiting || !IsSet(mainGui) || !mainGui)
        return
    if (IsWindowValid(refreshButton) && (hwnd = refreshButton.Hwnd || lParam = refreshButton.Hwnd)) {
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
    global updateBtn, updateSep, updateIcon
    if (IsSet(updateBtn) && IsObject(updateBtn) && IsSet(updateSep) && IsObject(updateSep) && IsSet(updateIcon) && IsObject(updateIcon)
        && (hwnd = updateBtn.Hwnd || hwnd = updateIcon.Hwnd || hwnd = updateSep.Hwnd)) {
        DllCall("Gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
        DllCall("Gdi32\SetTextColor", "Ptr", wParam, "UInt", (hwnd = updateSep.Hwnd) ? 0x00A0A0A0 : HexToColorRef(UpdateBtnTextHex()))
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

OpenDonatePage(*) {
    try Run("https://bio.site/ragnious")
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
}

CloseApplication(*) {
    global isExiting, gameFetchPending, asyncXhr, isRunning, exitConfirmed
    global helperLaunching, rpcConnecting, rpcPipe, targetPid
    global exitDlgActive, exitDlgBusy, exitDlgOpen, exitDlgClosing, exitFadeMode, exitFollowMain, exitFollowCap, exitAlphaNow
    global exitKeyHeld, exitKeyName, exitKeyCancel, exitPressed
    if (isExiting)
        return
    if (exitDlgActive && !exitDlgBusy && !exitConfirmed) {
        SetTimer(ExitDlgTick, 0)
        SetTimer(ExitDlgFadeTick, 0)
        exitDlgOpen := false, exitDlgClosing := true
        exitKeyHeld := false, exitKeyName := "", exitKeyCancel := false, exitPressed := ""
        exitConfirmed := true
        exitFadeMode := ""
        exitFollowCap := exitAlphaNow
        exitFollowMain := true
    }
    processActive := isRunning || helperLaunching || rpcConnecting || rpcPipe || (targetPid && ProcessExist(targetPid))
    if (processActive && !exitConfirmed) {
        SetTimer(ShowExitConfirm, -1)
        return
    }
    isExiting := true
    try PostHelperExit()
    if (gameFetchPending) {
        try asyncXhr.abort()
        FinishDiscordGameLoad()
    }
    AnimateVisibility(false, true, false)
}

AnimateVisibility(show, exitAppAfter := false, minimizeAfter := false) {
    global headerPrimed, mainGui, animationActive, animationShowing, animationStart, isWindowVisible, globalExitAppAfter, globalMinimizeAfter
    CloseProcessSelector()
    headerPrimed := false, animationActive := true, animationShowing := show, animationStart := A_TickCount, isWindowVisible := show, globalExitAppAfter := exitAppAfter, globalMinimizeAfter := minimizeAfter
    if show {
        SetWindowOpacity(0)
        mainGui.Show("NA")
        PositionChildWindows()
        ApplyAllCorners()
        TrayTip()
        ForceActivateMainGui()
        SetTimer(ForceActivateMainGui, -60)
    }
    SetTimer(AnimationFrame, 16)
}

ForceActivateMainGui(*) {
    global mainGui, isExiting, isWindowVisible
    if ((IsSet(isExiting) && isExiting) || !IsSet(mainGui) || !mainGui || !isWindowVisible)
        return
    try {
        hwnd := mainGui.Hwnd
        if (!DllCall("User32\IsWindow", "Ptr", hwnd, "Int") || DllCall("User32\IsIconic", "Ptr", hwnd, "Int"))
            return
        fg := DllCall("User32\GetForegroundWindow", "Ptr")
        if (fg = hwnd)
            return
        curTid := DllCall("Kernel32\GetCurrentThreadId", "UInt")
        fgTid := fg ? DllCall("User32\GetWindowThreadProcessId", "Ptr", fg, "Ptr", 0, "UInt") : 0
        attached := (fgTid && fgTid != curTid) ? DllCall("User32\AttachThreadInput", "UInt", curTid, "UInt", fgTid, "Int", true, "Int") : false
        DllCall("User32\AllowSetForegroundWindow", "UInt", 0xFFFFFFFF)
        DllCall("User32\BringWindowToTop", "Ptr", hwnd)
        DllCall("User32\SetForegroundWindow", "Ptr", hwnd)
        if (attached)
            DllCall("User32\AttachThreadInput", "UInt", curTid, "UInt", fgTid, "Int", false, "Int")
    }
}

AnimationFrame() {
    Critical("Off")
    global frameGui, selectGui, actionGui, mainGui, animationActive, animationShowing, animationStart, mainFadeDuration, globalExitAppAfter, globalMinimizeAfter
    global headerPrimed
    if (animationShowing && !headerPrimed) {
        headerPrimed := true
        SetWindowOpacity(0)
        HeaderRepaintAll(true)
        PrimeOwnerDrawnControls()
        animationStart := A_TickCount
        return
    }
    progress := Min((A_TickCount - animationStart) / mainFadeDuration, 1)
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
                ShutdownCleanup()
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
            HeaderRepaintAll(true)
            SettleRepaint()
            SetTimer(SettleRepaint, -60)
            SetTimer(SettleRepaint2, -450)
            SetTimer(SettleRepaint3, -1300)
            ResumeMarquee()
        }
    }
}

ShutdownCleanup() {
    global isExiting
    isExiting := true
    try CancelHelperLaunch()
    try StopTargetProcess()
}

OnExitStopProcess(*) {
    ShutdownCleanup()
    return 0
}

SettleRepaint(*) {
    global mainGui, minBtn, closeBtn, donateBtn, statusDot, isExiting, isWindowVisible, animationActive
    if (isExiting || animationActive || !isWindowVisible || !IsWindowValid(mainGui) || DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int"))
        return
    global frameGui, selectGui
    if (IsWindowValid(frameGui))
        DllCall("User32\RedrawWindow", "Ptr", frameGui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0181, "Int")
    if (IsWindowValid(selectGui))
        DllCall("User32\RedrawWindow", "Ptr", selectGui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0181, "Int")
    PaintSearchFrameDirect()
    RepaintRefreshButtonNoErase(true)
    RepaintActionButtonNoErase()
    HeaderRepaintAll()
    PaintControlDirect(minBtn, (d) => DrawTopButton(d, "min"))
    PaintControlDirect(closeBtn, (d) => DrawTopButton(d, "close"))
    PaintControlDirect(donateBtn, (d) => DrawTopButton(d, "donate"))
    PaintControlDirect(statusDot, DrawStatusDot)
    RedrawMainOutline()
}

PrimeOwnerDrawnControls() {
    global minBtn, closeBtn, donateBtn, statusDot, isExiting
    if (isExiting)
        return
    PaintSearchFrameDirect()
    RepaintRefreshButtonNoErase(true)
    RepaintActionButtonNoErase()
    PaintControlDirect(minBtn, (d) => DrawTopButton(d, "min"))
    PaintControlDirect(closeBtn, (d) => DrawTopButton(d, "close"))
    PaintControlDirect(donateBtn, (d) => DrawTopButton(d, "donate"))
    PaintControlDirect(statusDot, DrawStatusDot)
}

SettleRepaintNow() {
    global riskViewActive, riskTitleActive, riskTitleCtl, riskTosGui, mainGui
    if (!IsWindowValid(mainGui))
        return
    SettleRepaint()
    if (riskViewActive) {
        if (riskTitleActive && IsWindowValid(riskTitleCtl))
            PaintControlDirect(riskTitleCtl, DrawRiskTitle)
        if (IsWindowValid(riskTosGui))
            PaintTosDirect()
        RiskSoftPaint()
    }
}

; Repaint that is correct on the FIRST try after the main window leaves/enters layered mode.
; Root cause of "parts of the GUI appear 1-2 s late" (Policy Explainer, after fades, tray restore ...): SetWindowOpacity
; drops WS_EX_LAYERED at alpha 255 (and re-adds it below 255). DWM then swaps the window's composition surface
; asynchronously. A repaint issued in the same instant lands on the OLD surface and is thrown away, so owner-drawn /
; direct-painted parts stayed blank until the next unrelated repaint (SettleRepaint timers at 60 / 450 / 1300 ms, or the
; title marquee after its pause). Fix: let DWM finish the swap first (DwmFlush), THEN repaint the whole window tree and
; the custom-painted parts, then flush once more so the result is presented immediately.
SettleRepaintSync() {
    global mainGui, isExiting, riskViewActive
    if (isExiting || !IsSet(mainGui) || !mainGui || !IsWindowValid(mainGui))
        return
    if (DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int") || !DllCall("User32\IsWindowVisible", "Ptr", mainGui.Hwnd, "Int"))
        return
    DllCall("Dwmapi\DwmFlush", "Int")
    PrepaintMainWindow(false)
    SettleRepaintNow()
    if (riskViewActive)
        RiskForcePaint(false)
    DllCall("Dwmapi\DwmFlush", "Int")
}

SettleRepaintSyncTimer(*) => SettleRepaintSync()

SettleRepaint2(*) => SettleRepaint()

SettleRepaint3(*) => SettleRepaint()

PositionChildWindows() {
    global mainGui, titleBar, appName, appTagline, minBtn, closeBtn, donateBtn, versionText, frameGui, selectGui, actionGui, actionBtn, processSelect, refreshSeparator, refreshButton, selectorFrameGui, selectorPopup, selectorList, selectorDisplayedOptions, isExiting, isActionAnimating, selectorRowHeight, isWindowMoving
    global verTextX, verTextY, verTextW, verTextH, titleBarX, titleBarY, titleBarW, titleBarH, minBtnX, minBtnY, minBtnW, minBtnH, closeBtnX, closeBtnY, closeBtnW, closeBtnH, donateBtnX, donateBtnY, donateBtnW, donateBtnH
    global appNameX, appNameY, appNameW, appNameH, appTaglineH
    global updateSep, updateIcon, updSepX, updSepW, updIconX, updIconW
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
    taglineY := (appNameY + appNameH - 18) + 3
    MoveCtlIfChanged(versionText, verTextX, verTextY, verTextW, verTextH)
    MoveCtlIfChanged(updateSep, updSepX, updSepY, updSepW, updSepH)
    MoveCtlIfChanged(updateIcon, updIconX, updIconY, updIconW, updIconH)
    MoveCtlIfChanged(titleBar, titleBarX, titleBarY, titleBarW, titleBarH)
    MoveCtlIfChanged(minBtn, minBtnX, minBtnY, minBtnW, minBtnH)
    MoveCtlIfChanged(closeBtn, closeBtnX, closeBtnY, closeBtnW, closeBtnH)
    MoveCtlIfChanged(donateBtn, donateBtnX, donateBtnY, donateBtnW, donateBtnH)
    MoveCtlIfChanged(appName, appNameX, appNameY, appNameW, appNameH)
    MoveCtlIfChanged(appTagline, appNameX, taglineY, appNameW, appTaglineH)
    if (riskViewActive) {
        PositionRiskView(mainWidth, mainHeight)
        return
    }
    static lastFrameKey := "", lastInnerKey := "", lastActionKey := "", lastMarginKey := "", lastSelectLayout := "", lastDropKey := ""
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
    GetControlFontCenterMetrics(processSelect.Hwnd, &editHeight, &editCapCenter)
    editHeight := Max(editHeight, 1)
    editY := Floor((searchInnerH - 1) / 2 - editCapCenter + 0.5) + searchEditVNudge
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
        listW := (selectorDisplayedOptions.Length <= 3) ? innerPopupW : (innerPopupW - scrollListReserveW - 2)
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

MainGuiMoved(wParam, lParam, msg, hwnd) {
    global mainGui, isExiting, isWindowMoving
    if (isExiting || !IsSet(mainGui) || !mainGui || isWindowMoving)
        return
    if (hwnd = mainGui.Hwnd)
        PositionChildWindows()
}

PrintClientFrame(wParam, lParam, msg, hwnd) {
    global frameGui
    if (!IsObject(frameGui) || !IsWindowValid(frameGui) || hwnd != frameGui.Hwnd)
        return
    FillWhite(wParam, hwnd)
    return 0
}

PrepaintMainWindow(erase := true) {
    global mainGui
    if (!IsWindowValid(mainGui))
        return
    ; erase=false (RDW_ERASE dropped) for repaints done while the window is visible: an erase wipes every child to black
    ; for a frame before it is redrawn, which is the visible flicker of icons / line / button text.
    DllCall("User32\RedrawWindow", "Ptr", mainGui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", erase ? 0x0185 : 0x0181, "Int")
}

FocusMainWindowAfterFade() {
    global mainGui, isExiting, isWindowVisible, isGameSearchFocused
    if (isExiting || !IsWindowValid(mainGui))
        return
    if (IsSet(isWindowVisible) && !isWindowVisible)
        return
    global processSelect
    if (IsWindowValid(processSelect) && DllCall("User32\GetFocus", "Ptr") = processSelect.Hwnd
        && DllCall("User32\GetForegroundWindow", "Ptr") = mainGui.Hwnd)
        return
    isGameSearchFocused := false
    hwnd := mainGui.Hwnd
    try {
        if (DllCall("User32\GetForegroundWindow", "Ptr") != hwnd && (A_TimeIdlePhysical < 4000 || WinActive("ahk_pid " ProcessExist()))) {
            fg := DllCall("User32\GetForegroundWindow", "Ptr")
            myThread := DllCall("Kernel32\GetCurrentThreadId", "UInt")
            fgThread := fg ? DllCall("User32\GetWindowThreadProcessId", "Ptr", fg, "Ptr", 0, "UInt") : 0
            attached := (fgThread && fgThread != myThread && WindowResponsive(fg)) ? DllCall("User32\AttachThreadInput", "UInt", myThread, "UInt", fgThread, "Int", 1, "Int") : false
            DllCall("User32\SetForegroundWindow", "Ptr", hwnd)
            if (attached)
                DllCall("User32\AttachThreadInput", "UInt", myThread, "UInt", fgThread, "Int", 0)
        }
    }
    DllCall("User32\SetFocus", "Ptr", hwnd)
}

SetWindowOpacity(alpha) {
    if (!A_IsCritical)
        Critical("Off")
    global mainGui, selectorFrameGui, selectorPopup, selectorList, statusMarqueeGui, statusFadeOv, statusFadeShown, previewFixDropLayered
    global exitFollowMain, exitFollowCap
    if (exitFollowMain && alpha < 255)
        ExitDlgSetAlpha(Min(alpha, exitFollowCap))
    if (statusFadeShown && IsWindowValid(statusFadeOv))
        try DllCall("User32\SetLayeredWindowAttributes", "Ptr", statusFadeOv.Hwnd, "UInt", 0, "UChar", alpha, "UInt", 3, "Int")
    if (mainGui && mainGui.Hwnd) {
        mh := mainGui.Hwnd
        if (previewFixDropLayered) {
            ex := DllCall("User32\GetWindowLongW", "Ptr", mh, "Int", -20, "Int")
            if (alpha >= 255) {
                if (ex & 0x80000) {
                    DllCall("User32\SetWindowLongW", "Ptr", mh, "Int", -20, "Int", ex & ~0x80000, "Int")
                    SettleRepaintSync()
                    SetTimer(SettleRepaint2, -20)
                    SetTimer(SettleRepaintSyncTimer, -120)
                    SetTimer(SettleRepaint3, -250)
                }
            } else {
                if !(ex & 0x80000)
                    DllCall("User32\SetWindowLongW", "Ptr", mh, "Int", -20, "Int", ex | 0x80000, "Int")
                try DllCall("User32\SetLayeredWindowAttributes", "Ptr", mh, "UInt", 0, "UChar", alpha, "UInt", 2, "Int")
            }
        } else
            try DllCall("User32\SetLayeredWindowAttributes", "Ptr", mh, "UInt", 0, "UChar", alpha, "UInt", 2, "Int")
    }
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
    EnsureMainOutline()
}

EnsureMainOutline() {
    global mainGui, mainOutlineGui, mainOutlineKey, mainOutlineColor
    if (!IsSet(mainGui) || !mainGui || !IsWindowValid(mainGui))
        return
    try {
        WinGetPos(,, &w, &h, "ahk_id " mainGui.Hwnd)
        if (w < 50 || h < 50)
            return
        if (!IsWindowValid(mainOutlineGui)) {
            mainOutlineGui := Gui("-Caption -Border -DPIScale +0x40000000", "")
            mainOutlineGui.Opt("+Parent" mainGui.Hwnd)
            mainOutlineGui.BackColor := mainOutlineColor
            mainOutlineKey := ""
        }
        key := w "x" h
        if (key != mainOutlineKey) {
            mainOutlineGui.Show(Format("NA x0 y0 w{} h{}", w, h))
            outer := DllCall("Gdi32\CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", 29, "Int", 29, "Ptr")
            inner := DllCall("Gdi32\CreateRoundRectRgn", "Int", 1, "Int", 1, "Int", w - 1, "Int", h - 1, "Int", 27, "Int", 27, "Ptr")
            DllCall("Gdi32\CombineRgn", "Ptr", outer, "Ptr", outer, "Ptr", inner, "Int", 4, "Int")
            DllCall("Gdi32\DeleteObject", "Ptr", inner)
            if (!DllCall("User32\SetWindowRgn", "Ptr", mainOutlineGui.Hwnd, "Ptr", outer, "Int", 1, "Int"))
                DllCall("Gdi32\DeleteObject", "Ptr", outer)
            mainOutlineKey := key
        } else if (!DllCall("User32\IsWindowVisible", "Ptr", mainOutlineGui.Hwnd, "Int")) {
            mainOutlineGui.Show("NA")
        }
        if (DllCall("User32\GetWindow", "Ptr", mainGui.Hwnd, "UInt", 5, "Ptr") != mainOutlineGui.Hwnd)
            DllCall("User32\SetWindowPos", "Ptr", mainOutlineGui.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")
    }
}

RedrawMainOutline() {
    global mainOutlineGui
    if (IsWindowValid(mainOutlineGui) && DllCall("User32\IsWindowVisible", "Ptr", mainOutlineGui.Hwnd, "Int"))
        DllCall("User32\RedrawWindow", "Ptr", mainOutlineGui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0101, "Int")
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

MeasureSelectorItem(wParam, lParam, msg, hwnd) {
    global selectorPopup, selectorRowHeight
    if (!IsWindowValid(selectorPopup) || hwnd != selectorPopup.Hwnd || NumGet(lParam, 0, "UInt") != 2)
        return
    NumPut("UInt", selectorRowHeight, lParam, 16)
    return 1
}

DrawSelectorItem(wParam, lParam, msg, hwnd) {
    global selectorPopup, selectorList, selectorDisplayedOptions, refreshButton, selectGui
    global selectorScrollUpBtn, selectorScrollDownBtn, selectorScrollThumbTrack, selectorScrollThumb
    global selectorHoveredIndex
    global selectorPressedIndex, selectorPressColorCurrent, selectorPressPhase
    global dropdownMarqueeIndex, dropdownMarqueeOffset, isKeyboardNavigating, actionGui, actionBtn
    global dropdownMarqueeRenderedX, dropdownRenderedPhase, dropdownStripDc, dropdownStripH, dropdownStripDirty, dropdownStripPhases, dropdownStripText
    global statusGlyph, statusMarqueeGui, statusMarqueeText, mainGui, minBtn, closeBtn, donateBtn, statusDot, updateIcon, updateSep, versionText, updOverlay, updOverlayCtl
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
        if (IsWindowValid(statusGlyph) && itemHwnd = statusGlyph.Hwnd)
            return DrawStatusGlyph(lParam)
        if (IsWindowValid(minBtn) && itemHwnd = minBtn.Hwnd)
            return DrawTopButton(lParam, "min")
        if (IsWindowValid(closeBtn) && itemHwnd = closeBtn.Hwnd)
            return DrawTopButton(lParam, "close")
        if (IsWindowValid(donateBtn) && itemHwnd = donateBtn.Hwnd)
            return DrawTopButton(lParam, "donate")
        if (IsWindowValid(updateIcon) && itemHwnd = updateIcon.Hwnd)
            return DrawUpdateIcon(lParam)
        if (IsWindowValid(updateSep) && itemHwnd = updateSep.Hwnd)
            return DrawUpdateSep(lParam)
        if (IsWindowValid(versionText) && itemHwnd = versionText.Hwnd)
            return DrawHeaderVersion(lParam)
    }
    if (IsWindowValid(refreshButton) && IsObject(selectGui) && hwnd = selectGui.Hwnd) {
        if (itemHwnd = refreshButton.Hwnd)
            return DrawRefreshButton(lParam)
    }
    if (IsObject(refreshOverlay) && IsWindowValid(refreshOverlayCtl) && hwnd = refreshOverlay.Hwnd && itemHwnd = refreshOverlayCtl.Hwnd)
        return DrawRefreshButton(lParam)
    if (IsObject(updOverlay) && IsWindowValid(updOverlayCtl) && hwnd = updOverlay.Hwnd && itemHwnd = updOverlayCtl.Hwnd)
        return DrawUpdateIcon(lParam)
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
    realHdc := hdc
    bufW := right - left, bufH := bottom - top
    if (bufW <= 0 || bufH <= 0)
        return 1
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
    contentBottom := bottom - 1
    isPressed := (itemIndex = selectorPressedIndex && selectorPressPhase != "idle")
    isHighlightedViaKeyboard := isKeyboardNavigating && (itemIndex = SendMessage(0x0188, 0, 0, selectorList.Hwnd))
    rowFillHex := ""
    fillBottom := contentBottom
    if (isPressed || itemIndex = selectorHoveredIndex || isHighlightedViaKeyboard) {
        rowColor := isPressed ? selectorPressColorCurrent : "3A3A3A"
        rowFillHex := rowColor
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
    DllCall("Gdi32\SetBkMode", "Ptr", hdc, "Int", 1)
    DllCall("Gdi32\SetTextColor", "Ptr", hdc, "UInt", 0xFFFFFF)
    leftTextInset := rowLeftInset
    titleText := selectorDisplayedOptions[itemIndex + 1]
    GetRowTextBearings(titleText, &bearingA, &bearingC)
    iconOff := RowIconOffset(leftTextInset)
    exactTextLeft := left + leftTextInset + iconOff
    gapRight := rowRightPad + 1 + bearingA
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
    rowCenterY := top + (contentBottom - top) / 2
    textTop := Floor(rowCenterY - textCapCenter + 0.5) + dropdownRowVNudge
    if (iconOff > 0) {
        iconY := Round(rowCenterY - RowIconSize() / 2)
        DrawRowIcon(hdc, left, top, left + leftTextInset, iconY, titleText)
    }
    textRect := Buffer(16, 0)
    NumPut("Int", textX, textRect, 0)
    NumPut("Int", textTop, textRect, 4)
    NumPut("Int", exactTextRight, textRect, 8)
    NumPut("Int", textTop + textLineH + 2, textRect, 12)
    drawnSmooth := false
    if (isScrollingRow && dropdownStripPhases > 1 && dropdownStripDc && !dropdownStripDirty && dropdownStripH = bufH
        && dropdownStripText == titleText && rowFillHex = "3A3A3A") {
        clipL := exactTextLeft + bearingA
        clipW := exactTextRight - clipL
        srcX := (clipL - exactTextLeft) - dropdownMarqueeRenderedX + 1
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
        DllCall("User32\DrawTextW", "Ptr", hdc, "Str", titleText, "Int", -1, "Ptr", textRect, "UInt", 0x00000820)
        if (isScrollingRow)
            DllCall("Gdi32\SelectClipRgn", "Ptr", hdc, "Ptr", 0)
    }
    FlushBufferedRow(realHdc, bufDc, bufBmp, bufOldBmp, left, top, bufW, bufH)
    return 1
}

IsPressCancellable() {
    global isKeyActionDown, enterBuffered, riskKeyHeld, pressedControl, riskPressedName
    held := false
    if ((isKeyActionDown || enterBuffered || riskKeyHeld || enterRefreshHeld) && (GetKeyState("Enter", "P") || GetKeyState("NumpadEnter", "P")))
        held := true
    else if ((pressedControl != "" || (riskViewActive && riskPressedName != "")) && GetKeyState("LButton", "P"))
        held := true
    return held && IsMyGuiActive()
}

ReleaseWatchdog() {
    global pressedControl, isKeyActionDown, isExiting, mainGui, enterPressCancelled
    if (isExiting || !IsSet(mainGui) || !mainGui)
        return
    if (enterPressCancelled && !GetKeyState("Enter", "P") && !GetKeyState("NumpadEnter", "P"))
        enterPressCancelled := false
    if (pressedControl != "" && !GetKeyState("LButton", "P")) {
        try HandleLeftButtonUp(0, 0, 0x0202, mainGui.Hwnd)
        pressedControl := ""
    }
    if (isKeyActionDown && !GetKeyState("Enter", "P") && !GetKeyState("NumpadEnter", "P"))
        TriggerActionUp()
    if (enterRefreshHeld && !GetKeyState("Enter", "P") && !GetKeyState("NumpadEnter", "P"))
        RefreshKeyUp()
}

EnterShouldPressRefresh() {
    global processOptions, riskViewActive, isKeyActionDown, enterRefreshHeld
    if (enterRefreshHeld)
        return true
    if (riskViewActive || isKeyActionDown)
        return false
    return processOptions.Length = 0
}

RefreshKeyDown() {
    global enterRefreshHeld, enterRefreshBlocked, enterPressCancelled, refreshIsLocked, connLost
    if (enterRefreshHeld)
        return
    if (enterPressCancelled) {
        if (GetKeyState("Enter", "P") || GetKeyState("NumpadEnter", "P"))
            return
        enterPressCancelled := false
    }
    if (refreshIsLocked || connLost)
        return
    enterRefreshHeld := true
    if (RefreshDisabled()) {
        enterRefreshBlocked := true
        return
    }
    enterRefreshBlocked := false
    StartRefreshButtonStyle("pressed")
}

RefreshKeyUp() {
    global enterRefreshHeld, enterRefreshBlocked, refreshIsLocked, isGameSearchFocused, mainGui, lastHover
    if (!enterRefreshHeld)
        return
    enterRefreshHeld := false
    blocked := enterRefreshBlocked
    enterRefreshBlocked := false
    if (blocked) {
        if (!RefreshBlockedWhileActive() && RefreshCooldownMs() > 0)
            RefreshProcessList()
        return
    }
    if (refreshIsLocked)
        return
    MarqueeFrameAlign()
    if (RefreshBlockedWhileActive()) {
        lastHover := -1
        UpdateButtonHover()
        return
    }
    CloseProcessSelector()
    isGameSearchFocused := false
    if (IsWindowValid(mainGui))
        DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
    StartRefreshKick()
    RefreshProcessList()
    lastHover := -1
    UpdateButtonHover()
}

RefreshKeyCancel() {
    global enterRefreshHeld, enterRefreshBlocked, refreshIsLocked, lastHover
    if (!enterRefreshHeld)
        return
    enterRefreshHeld := false
    wasBlocked := enterRefreshBlocked
    enterRefreshBlocked := false
    if (wasBlocked || refreshIsLocked)
        return
    lastHover := -1
    StartRefreshButtonStyle("normal")
    UpdateButtonHover()
}

TriggerActionDown() {
    global isRunning, isKeyActionDown, actionLocked, rpcConnecting, rpcConnectStart, fadeInTail, enterBuffered, riskViewBusy, enterPressCancelled
    global helperLaunching, helperLaunchStart
    if (connLost)
        return
    if (enterPressCancelled) {
        if (GetKeyState("Enter", "P") || GetKeyState("NumpadEnter", "P"))
            return
        enterPressCancelled := false
    }
    if (fadeInTail && riskViewBusy) {
        enterBuffered := true
        return
    }
    if (riskViewActive) {
        RiskKeyDown()
        return
    }
    if (isKeyActionDown && !GetKeyState("Enter", "P") && !GetKeyState("NumpadEnter", "P"))
        isKeyActionDown := false
    if (isKeyActionDown || actionLocked || (rpcConnecting && A_TickCount - rpcConnectStart < 700) || (helperLaunching && A_TickCount - helperLaunchStart < 700))
        return
    isKeyActionDown := true
    SetActionColor(isRunning ? "9A1E15" : "186B3C", false)
    AnimateActionButton(true)
}

TriggerActionUp() {
    global isRunning, isKeyActionDown
    if (riskViewActive)
        return
    if (!isKeyActionDown)
        return
    isKeyActionDown := false
    SetActionColor(isRunning ? "D12F26" : "279B5A", false)
    AnimateActionButton(false, QueueToggle)
}

CancelActionPress() {
    global actionGui, actionBtn, isRunning, isKeyActionDown, lastHover
    if (!isKeyActionDown)
        return
    isKeyActionDown := false
    MouseGetPos(,,, &hoveredControl, 2)
    over := (hoveredControl = actionGui.Hwnd || hoveredControl = actionBtn.Hwnd)
    SetActionColor(isRunning ? (over ? "D12F26" : "B42318") : (over ? "279B5A" : "208A4E"), false)
    lastHover := -1
    AnimateActionButton(false)
}

CancelMousePress() {
    global pressedControl, lastHover, iconAnimState, updateHovered
    target := pressedControl
    if (target = "")
        return
    pressedControl := ""
    if (target = "tos") {
        TosIconUp(0)
    } else if (target = "min" || target = "close" || target = "donate") {
        if (iconAnimState.Has(target))
            ReleaseIcon(target)
    } else if (target = "action") {
        AnimateActionButton(false)
    } else if (target = "update") {
        StartUpdateBgStyle(updateHovered ? "hover" : "normal")
    }
    lastHover := -1
    UpdateButtonHover()
}

QueueToggle(*) {
    global togglePending, actionLocked, isExiting, toggleRunning, rpcConnecting, rpcConnectStart, riskViewActive, riskViewBusy, lastToggleDoneTick
    global helperLaunching, helperLaunchStart
    global toggleGen, toggleStartTick, togglePendingTick
    if (isExiting || actionLocked || connLost)
        return
    ; Self-heal: a toggle now only holds the lock for a few ms. If it is still held (or still "pending") after
    ; seconds, its thread is wedged under another thread; release it so the button can never stay dead.
    if (toggleRunning && A_TickCount - toggleStartTick > 4000) {
        toggleGen += 1
        toggleRunning := false
        togglePending := 0
    }
    if (togglePending > 0 && !toggleRunning && A_TickCount - togglePendingTick > 1000)
        togglePending := 0
    if (toggleRunning || (rpcConnecting && A_TickCount - rpcConnectStart < 700) || riskViewActive || riskViewBusy || togglePending > 0)
        return
    if (A_TickCount - lastToggleDoneTick < 250)
        return
    togglePending := 1
    togglePendingTick := A_TickCount
    SetTimer(ProcessToggleQueue, -1)
}

ProcessToggleQueue() {
    global toggleRunning, togglePending, actionLocked, isExiting, riskViewActive, riskViewBusy, lastToggleDoneTick
    global toggleGen, toggleStartTick
    if (toggleRunning)
        return
    toggleRunning := true
    toggleStartTick := A_TickCount
    myGen := ++toggleGen
    try {
        while (togglePending > 0 && !isExiting) {
            togglePending -= 1
            try {
                ToggleAction()
            } catch Error as err {
                SetStatus("Unexpected error. Try again, or restart the application if it keeps happening.", "error")
            }
            if (riskViewActive || riskViewBusy || actionLocked) {
                togglePending := 0
                break
            }
        }
    } finally {
        if (myGen = toggleGen) {
            toggleRunning := false
            togglePending := 0
        }
        lastToggleDoneTick := A_TickCount
    }
}

HandleRightButtonDown(wParam, lParam, msg, hwnd) {
    global mainGui, processSelect, selectorFrameGui, isGameSearchFocused, isExiting, isSearchMenuOpen, searchMenuSwallowRightUp, exitDlgActive
    if (exitDlgActive)
        return 0
    if (isExiting || !IsSet(mainGui) || !mainGui || !IsOwnGuiWindow(hwnd))
        return
    if (isSearchMenuOpen) {
        CloseSearchMenu(false)
        searchMenuSwallowRightUp := true
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
    global selectorFrameGui, processSelect, isExiting, searchMenuSwallowRightUp, exitDlgActive
    if (exitDlgActive)
        return 0
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
    global processSelect, isExiting, exitDlgActive
    if (exitDlgActive)
        return 0
    if (isExiting || !IsWindowValid(processSelect) || hwnd != processSelect.Hwnd)
        return
    SetTimer(ShowSearchContextMenu, -1)
    return 0
}

OnWmChar(wParam, lParam, msg, hwnd) {
    global mainGui, processSelect, selectorList, isExiting, exitDlgActive, riskViewActive, riskViewBusy, isWindowVisible
    if (isExiting || !IsSet(mainGui) || !mainGui || !IsWindowValid(processSelect))
        return
    if (hwnd = processSelect.Hwnd || (IsWindowValid(selectorList) && hwnd = selectorList.Hwnd))
        return
    if (exitDlgActive || riskViewActive || riskViewBusy || !isWindowVisible || !IsOwnGuiWindow(hwnd))
        return
    if (wParam < 32 || wParam = 127)
        return
    ; First keystroke typed while the search box is not focused: focusing it clears the hint text, and the character
    ; used to be POSTED, i.e. delivered later. In between, one frame with an EMPTY box was painted = the one-time
    ; flicker at the very start of typing. Hold painting, deliver the character synchronously, and let the box
    ; paint once, already containing the character.
    global searchEditHold
    searchEditHold := true
    try {
        DllCall("User32\SetFocus", "Ptr", processSelect.Hwnd)
        DllCall("User32\SendMessageW", "Ptr", processSelect.Hwnd, "UInt", 0x0102, "Ptr", wParam, "Ptr", lParam, "Ptr")
    } finally {
        searchEditHold := false
    }
    DllCall("User32\InvalidateRect", "Ptr", processSelect.Hwnd, "Ptr", 0, "Int", false)
    return 0
}

OnWmKeyDown(wParam, lParam, msg, hwnd) {
    global selectorList, isExiting
    if (isExiting || !IsWindowValid(selectorList) || hwnd != selectorList.Hwnd)
        return
    if (wParam = 38 || wParam = 40 || wParam = 33 || wParam = 34)
        return
    return 0
}

HandleLeftButtonDown(wParam, lParam, msg, hwnd) {
    global mainGui, titleBar, versionText, processSelect, selectGui, selectorFrameGui, selectorPopup, selectorList, selectorScrollUpBtn, selectorScrollDownBtn, selectorScrollThumb, selectorScrollThumbTrack, minBtn, closeBtn, donateBtn, refreshButton, actionGui, actionBtn, isRunning, pressedControl, isExiting, selectorDisplayedOptions
    global dropdownToggleCooldown, refreshIsLocked, isGameSearchFocused, isSearchMenuOpen
    global updateSep, exitDlgActive
    if (exitDlgActive)
        return 0
    if (isExiting || !IsSet(mainGui) || !mainGui || !IsOwnGuiWindow(hwnd))
        return
    if (riskViewActive) {
        RiskViewLeftDown(hwnd)
        return
    }
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
    searchRightPad := 10
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
        return 0
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
    if (hoveredControl = minBtn.Hwnd || hoveredControl = closeBtn.Hwnd || hoveredControl = donateBtn.Hwnd || (IsWindowValid(refreshButton) && (hoveredControl = refreshButton.Hwnd || hwnd = refreshButton.Hwnd)))
        MarqueeFrameAlign()
    if (hoveredControl = minBtn.Hwnd) {
        pressedControl := "min"
        SetTopButtonBg("min", "555555")
        PressIcon("min")
    } else if (hoveredControl = donateBtn.Hwnd) {
        pressedControl := "donate"
        SetTopButtonBg("donate", "555555")
        PressIcon("donate")
    } else if (hoveredControl = closeBtn.Hwnd) {
        pressedControl := "close"
        SetTopButtonBg("close", "B30710")
        PressIcon("close")
    } else if (IsWindowValid(refreshButton) && (hoveredControl = refreshButton.Hwnd || hwnd = refreshButton.Hwnd)) {
        if (refreshIsLocked || connLost)
            return
        if (RefreshDisabled()) {
            pressedControl := "refreshblocked"
            return
        }
        pressedControl := "refresh"
        StartRefreshButtonStyle("pressed")
    } else if (IsUpdateBtnHwnd(hoveredControl) || IsUpdateBtnHwnd(hwnd)) {
        if (!UpdateBtnClickable()) {
            if (isRunning && !connLost && !riskViewActive && (updateState = "idle" || updateState = "available"))
                RefreshBlockedWhileActive("Updating", "update")
            return
        }
        pressedControl := "update"
        StartUpdateBgStyle("pressed")
    } else if (hoveredControl = actionGui.Hwnd || hoveredControl = actionBtn.Hwnd) {
        if (connLost)
            return
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
    global mainGui, pressedControl, minBtn, closeBtn, donateBtn, refreshButton, actionGui, actionBtn, isRunning, isExiting, refreshIsLocked
    global exitDlgActive, isGameSearchFocused
    if (exitDlgActive)
        return 0
    if (isExiting || !IsSet(mainGui) || !mainGui || !IsOwnGuiWindow(hwnd))
        return
    MouseGetPos(,,, &hoveredControl, 2)
    if (pressedControl = "")
        return
    activeTarget := pressedControl
    pressedControl := ""
    if (activeTarget = "min" || activeTarget = "close" || activeTarget = "donate" || activeTarget = "refresh" || activeTarget = "tos")
        MarqueeFrameAlign()
    if (activeTarget = "tos") {
        TosIconUp(hoveredControl)
    } else if (activeTarget = "update") {
        if (IsUpdateBtnHwnd(hoveredControl)) {
            StartUpdateBgStyle("hover")
            UpdateButtonClicked()
        } else {
            StartUpdateBgStyle("normal")
        }
    } else if (activeTarget = "min" && hoveredControl = minBtn.Hwnd) {
        SetTopButtonBg("min", "3A3A3A")
        MinimizeWindow()
    } else if (activeTarget = "donate" && hoveredControl = donateBtn.Hwnd) {
        SetTopButtonBg("donate", "3A3A3A")
        OpenDonatePage()
    } else if (activeTarget = "close" && hoveredControl = closeBtn.Hwnd) {
        SetTopButtonBg("close", "E50914")
        CloseApplication()
    } else if (activeTarget = "action" && (hoveredControl = actionGui.Hwnd || hoveredControl = actionBtn.Hwnd || CursorOverActionButtonNormalSize())) {
        SetActionColor(isRunning ? "D12F26" : "279B5A", false)
        AnimateActionButton(false, QueueToggle)
    } else if (activeTarget = "refreshblocked") {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&bX, &bY)
        if (IsWindowValid(refreshButton)) {
            WinGetPos(&brX, &brY, &brW, &brH, "ahk_id " refreshButton.Hwnd)
            if (bX >= brX && bX < brX + brW && bY >= brY && bY < brY + brH) {
                if (!RefreshBlockedWhileActive() && RefreshCooldownMs() > 0)
                    RefreshProcessList()
            }
        }
    } else if (activeTarget = "refresh") {
        if (!refreshIsLocked) {
            CoordMode("Mouse", "Screen")
            MouseGetPos(&mX, &mY)
            if (IsWindowValid(refreshButton)) {
                WinGetPos(&rX, &rY, &rW, &rH, "ahk_id " refreshButton.Hwnd)
                if (mX >= rX && mX < rX + rW && mY >= rY && mY < rY + rH) {
                    if (RefreshBlockedWhileActive()) {
                        StartRefreshButtonStyle("hover")
                        return
                    }
                    CloseProcessSelector()
                    isGameSearchFocused := false
                    if (IsWindowValid(mainGui))
                        DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
                    StartRefreshKick()
                    RefreshProcessList()
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
    global minBtn, closeBtn, donateBtn, refreshButton, actionBtn, actionGui, isRunning, lastHover, mainGui, isWindowVisible, isExiting, pressedControl, isActionAnimating, refreshIsLocked, refreshButtonBgCurrent
    global updateHovered, exitDlgActive, iconAnimState
    static lastRunLock := false
    if (!isExiting && lastRunLock != (isRunning ? true : false)) {
        lastRunLock := isRunning ? true : false
        updateHovered := false
        ResetUpdateBg()
        lastHover := -1
        RedrawUpdateBtn()
    }
    if (isExiting || !isWindowVisible || !IsSet(mainGui) || !mainGui || pressedControl != "" || isActionAnimating || IsContextMenuOpen())
        return
    MouseGetPos(,,, &hoveredControl, 2)
    if (exitDlgActive) {
        if (iconAnimState.Has("close") || iconAnimState.Has("min") || iconAnimState.Has("donate"))
            return
        hoveredControl := 0
    }
    isActionHovered := (hoveredControl = actionGui.Hwnd || hoveredControl = actionBtn.Hwnd) && !connLost
    refreshHovered := IsWindowValid(refreshButton) && hoveredControl = refreshButton.Hwnd && !RefreshDisabled()
    updHovered := IsUpdateBtnHwnd(hoveredControl) && UpdateBtnClickable()
    currentHoverState := isActionHovered ? 1 : (hoveredControl = minBtn.Hwnd ? 2 : (hoveredControl = donateBtn.Hwnd ? 6 : (hoveredControl = closeBtn.Hwnd ? 3 : (refreshHovered ? 4 : (updHovered ? 5 : 0)))))
    if (currentHoverState = lastHover)
        return
    if (updHovered != updateHovered) {
        updateHovered := updHovered
        StartUpdateBgStyle(updHovered ? "hover" : "normal")
        RedrawUpdateBtn()
    }
    SetTopButtonBg("min", hoveredControl = minBtn.Hwnd ? "3A3A3A" : "000000")
    SetTopButtonBg("donate", hoveredControl = donateBtn.Hwnd ? "3A3A3A" : "000000")
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

FlushBufferedRow(realHdc, bufDc, bufBmp, bufOldBmp, left, top, w, h) {
    DllCall("Gdi32\BitBlt", "Ptr", realHdc, "Int", left, "Int", top, "Int", w, "Int", h, "Ptr", bufDc, "Int", left, "Int", top, "UInt", 0x00CC0020)
}

FlushBufferedEnter() {
    global enterBuffered, fadeInTail, riskViewBusy, actionLocked, isExiting
    fadeInTail := false
    if (!enterBuffered || isExiting)
        return
    if (riskViewBusy || actionLocked) {
        SetTimer(FlushBufferedEnter, -5)
        return
    }
    enterBuffered := false
    if (!IsMyGuiActive())
        return
    TriggerActionDown()
    if (!GetKeyState("Enter", "P") && !GetKeyState("NumpadEnter", "P"))
        TriggerActionUp()
}

ToggleAction(*) {
    global rpcConnecting, rpcCancel
    global isRunning, lastHover, selectedProcessTitle, activeProcessName, isExiting, stopInProgress
    if (isExiting)
        return
    if (isRunning) {
        global rpcPipe, rpcConnHandle
        useRpc := (rpcConnecting || rpcPipe || rpcConnHandle)
        rpcConnecting := false, rpcCancel := true
        stoppedName := activeProcessName != "" ? activeProcessName : "Process"
        if (useRpc) {
            ; Discord RPC teardown is short and must finish before a reconnect, so it stays inline.
            stopInProgress := true
            try {
                if (!CancelHelperLaunch())
                    StopTargetProcess()
            } finally {
                stopInProgress := false
            }
        } else {
            ; Helper teardown (kill, wait for exit, delete files) can take seconds. Doing it here kept the toggle
            ; lock held and the button on "Stop" while every click was dropped. Flip the UI now, clean up after.
            CancelHelperLaunch()
            QueueHelperTeardown()
        }
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
        SetStatus("Select a game title first, then press Start.", "stopped")
        return
    }
    DismissSearchAfterValidStart()
    cleanName := RegExReplace(procName, "i)\.exe$", "")
    activeProcessName := cleanName
    safeDirName := RegExReplace(cleanName, '[\\/<>:"|?*]', "_")
    global gameExecutables, gameAppIds
    titleKey := StrLower(procName)
    detectedExe := ""
    try {
        overrideValue := IniRead(A_ScriptDir "\Ragnious_overrides.ini", "Executables", procName, "")
        if (overrideValue != "")
            detectedExe := SanitizeExecutablePath(overrideValue)
    }
    if (detectedExe = "" && gameExecutables.Has(titleKey))
        detectedExe := gameExecutables[titleKey]
    if (detectedExe = "") {
        appId := gameAppIds.Has(titleKey) ? gameAppIds[titleKey] : ""
        if (appId = "") {
            SetStatus("Couldn't start '" cleanName "': Discord has no application ID for it. Try another title.", "error")
            return
        }
        ShowRpcRiskView(cleanName, appId)
        return
    }
    BeginHelperLaunch(cleanName, safeDirName, detectedExe)
}

SetActionColor(color, paint := true) {
    global actionBtnColor
    if (actionBtnColor = color)
        return
    actionBtnColor := color
    if (paint)
        RepaintActionButtonNoErase()
}

SetActionLabel(text) {
    global actionBtnLabel
    actionBtnLabel := text
}

RepaintActionButtonNoErase() {
    global actionBtn
    if (PaintControlDirect(actionBtn, DrawActionButton))
        return
    if (IsWindowValid(actionBtn)) {
        DllCall("User32\InvalidateRect", "Ptr", actionBtn.Hwnd, "Ptr", 0, "Int", false)
        DllCall("User32\UpdateWindow", "Ptr", actionBtn.Hwnd)
    }
}

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
    GetFontCenterMetrics(memoryDc, &labelLineH, &labelCapCenter)
    labelTop := py0 + Ceil((ph - 1) / 2 - labelCapCenter - 0.5)
    labelRect := Buffer(16, 0)
    NumPut("Int", px0, labelRect, 0)
    NumPut("Int", labelTop, labelRect, 4)
    NumPut("Int", px0 + pw, labelRect, 8)
    NumPut("Int", labelTop + labelLineH + 2, labelRect, 12)
    DllCall("User32\DrawTextW", "Ptr", memoryDc, "Str", btnLabel, "Int", -1, "Ptr", labelRect, "UInt", 0x00000021)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)
    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBitmap, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", bitmap)
    DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
    return 1
}

AnimateActionButton(pressed, onComplete := "") {
    global mainGui, isActionAnimating, currentAnimId, actionBtnFontSize, actionBtnBaseFontSize, actionBtnScale
    global marqueeTimerRunning, isMarqueeActive, marqueePauseUntil
    if (!IsSet(mainGui) || !mainGui)
        return
    local thisAnimId := ++currentAnimId
    isActionAnimating := true
    local callbackFired := false
    try {
        scaleStart := actionBtnScale
        scaleEnd := pressed ? actionBtnPressScale : 1.0
        if (marqueeTimerRunning && isMarqueeActive && NowMs() >= marqueePauseUntil)
            ServiceMarqueesDuringAnimation()
        startTime := A_TickCount, duration := actionBtnPressMs
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
        if (!pressed) {
            actionBtnScale := 1.0
            actionBtnFontSize := actionBtnBaseFontSize
        }
        ResyncMarqueeClocks()
        if (!pressed && IsObject(onComplete)) {
            callbackFired := true
            onComplete()
        }
    } finally {
        if (thisAnimId = currentAnimId)
            isActionAnimating := false
        if (!pressed && !callbackFired && IsObject(onComplete)) {
            callbackFired := true
            onComplete()
        }
    }
}

ShowSearchContextMenu() {
    global processSelect, mainGui, isExiting, isSearchMenuOpen, searchMenuGui, searchMenuItems
    global searchMenuPressed, searchMenuLeftWasDown, searchMenuAnyWasDown
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
    defs := [["Undo", canUndo, 0x00C7, 0, 0], [""], ["Cut", hasSelection, 0x0300, 0, 0], ["Copy", hasSelection, 0x0301, 0, 0]
        , ["Paste", canPaste, 0x0302, 0, 0], ["Delete", hasSelection, 0x0303, 0, 0], [""]
        , ["Select All", (textLength > 0 && !allSelected), 0x00B1, 0, -1]]
    menuW := 190, rowH := 34, sepH := 9
    totalH := 2
    for d in defs
        totalH += (d.Length = 1) ? sepH : rowH
    searchMenuGui := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x08000000 +Owner" mainGui.Hwnd, "")
    searchMenuGui.BackColor := "454545"
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
    searchMenuPressed := 0
    searchMenuLeftWasDown := GetKeyState("LButton", "P")
    searchMenuAnyWasDown := searchMenuLeftWasDown || GetKeyState("RButton", "P")
    isSearchMenuOpen := true
    ClearDropdownHover()
    SetTimer(SearchMenuTick, 10)
}

ClearDropdownHover() {
    global selectorList, dropdownMarqueeIndex, isKeyboardNavigating
    isKeyboardNavigating := false
    dropdownMarqueeIndex := -1
    if (IsProcessSelectorOpen() && IsWindowValid(selectorList))
        SetSelectorHoverIndex(-1)
}

SetSearchMenuRowColor(item, state) {
    color := (!item.enabled || state = 0) ? "1E1E1E" : (state = 1 ? "3A3A3A" : "505050")
    MarqueeFrameAlign()
    item.ctrl.Opt("+Background" color)
    item.ctrl.Redraw()
}

SearchMenuTick() {
    global searchMenuGui, searchMenuItems, searchMenuPressed, isSearchMenuOpen
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
    if (anyDown && !searchMenuAnyWasDown && !insideMenu) {
        CloseSearchMenu()
        return
    }
    if (leftDown && !searchMenuLeftWasDown && hovered > 0 && searchMenuItems[hovered].enabled)
        searchMenuPressed := hovered
    if (!leftDown && searchMenuLeftWasDown && searchMenuPressed > 0) {
        item := searchMenuItems[searchMenuPressed]
        run := (hovered = searchMenuPressed && item.enabled)
        searchMenuPressed := 0
        searchMenuLeftWasDown := false
        searchMenuAnyWasDown := false
        if (run) {
            SetSearchMenuRowColor(item, 2)
            MarqueeSafeWait(60)
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
    switch key {
        case "min":
            StartIconAnim(key, minBtnPressScale, minBtnPressDuration, "cubic", true)
        case "close":
            StartIconAnim(key, closeBtnPressScale, closeBtnPressDuration, "cubic", true)
        case "donate":
            StartIconAnim(key, donateBtnPressScale, donateBtnPressDuration, "cubic", true)
        case "up":
            StartIconAnim(key, scrollUpBtnPressScale, scrollUpBtnPressDuration, "cubic", true)
        case "down":
            StartIconAnim(key, scrollDownBtnPressScale, scrollDownBtnPressDuration, "cubic", true)
        default:
            StartIconAnim(key, 0.78, 90, "cubic", true)
    }
}

ReleaseIcon(key) {
    switch key {
        case "min":
            StartIconAnim(key, 1.0, minBtnReleaseDuration, "back", false)
        case "close":
            StartIconAnim(key, 1.0, closeBtnReleaseDuration, "back", false)
        case "donate":
            StartIconAnim(key, 1.0, donateBtnReleaseDuration, "back", false)
        case "up":
            StartIconAnim(key, 1.0, scrollUpBtnReleaseDuration, "back", false)
        case "down":
            StartIconAnim(key, 1.0, scrollDownBtnReleaseDuration, "back", false)
        default:
            StartIconAnim(key, 1.0, 170, "back", false)
    }
}

RepaintIconButton(key) {
    global minBtn, closeBtn, donateBtn, refreshButton, selectorScrollUpBtn, selectorScrollDownBtn
    if (key = "tos") {
        PaintTosDirect()
        return
    }
    ctrl := ""
    switch key {
        case "min": ctrl := minBtn
        case "close": ctrl := closeBtn
        case "donate": ctrl := donateBtn
        case "refresh": ctrl := refreshButton
        case "up": ctrl := selectorScrollUpBtn
        case "down": ctrl := selectorScrollDownBtn
    }
    if (!IsWindowValid(ctrl))
        return
    if (key = "min" || key = "close" || key = "donate") {
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
    global iconAnimState
    if (iconAnimState.Count = 0) {
        SetTimer(IconAnimTick, 0)
        return
    }
    buttonDown := GetKeyState("LButton", "P")
    keys := []
    for key in iconAnimState
        keys.Push(key)
    anyActive := false
    MarqueeFrameAlign()
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
    ResyncMarqueeClocks()
}

DrawDollarSign(graphics, pen, cx, cy, rx, ry, bar) {
    DllCall("gdiplus\GdipDrawArc", "Ptr", graphics, "Ptr", pen, "Float", cx - rx, "Float", cy - 2 * ry, "Float", 2 * rx, "Float", 2 * ry, "Float", 325.0, "Float", -235.0, "UInt")
    DllCall("gdiplus\GdipDrawArc", "Ptr", graphics, "Ptr", pen, "Float", cx - rx, "Float", cy, "Float", 2 * rx, "Float", 2 * ry, "Float", 270.0, "Float", 235.0, "UInt")
    DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", cx, "Float", cy - bar, "Float", cx, "Float", cy + bar, "UInt")
}

DrawRoundRectOutline(graphics, pen, x1, y1, x2, y2, r) {
    d := 2 * r
    DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", x1 + r, "Float", y1, "Float", x2 - r, "Float", y1, "UInt")
    DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", x1 + r, "Float", y2, "Float", x2 - r, "Float", y2, "UInt")
    DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", x1, "Float", y1 + r, "Float", x1, "Float", y2 - r, "UInt")
    DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", x2, "Float", y1 + r, "Float", x2, "Float", y2 - r, "UInt")
    DllCall("gdiplus\GdipDrawArc", "Ptr", graphics, "Ptr", pen, "Float", x2 - d, "Float", y1, "Float", d, "Float", d, "Float", 270.0, "Float", 90.0, "UInt")
    DllCall("gdiplus\GdipDrawArc", "Ptr", graphics, "Ptr", pen, "Float", x2 - d, "Float", y2 - d, "Float", d, "Float", d, "Float", 0.0, "Float", 90.0, "UInt")
    DllCall("gdiplus\GdipDrawArc", "Ptr", graphics, "Ptr", pen, "Float", x1, "Float", y2 - d, "Float", d, "Float", d, "Float", 90.0, "Float", 90.0, "UInt")
    DllCall("gdiplus\GdipDrawArc", "Ptr", graphics, "Ptr", pen, "Float", x1, "Float", y1, "Float", d, "Float", d, "Float", 180.0, "Float", 90.0, "UInt")
}

DrawIconGlyph(graphics, kind, cx, cy, scale) {
    global minStroke, closeStroke, donateStroke, scrollUpStroke, scrollDownStroke
    if (kind = "min")
        strokeW := minStroke
    else if (kind = "close")
        strokeW := closeStroke
    else if (kind = "donate")
        strokeW := donateStroke
    else if (kind = "up")
        strokeW := scrollUpStroke
    else
        strokeW := scrollDownStroke
    donateTotalH := 20.0
    donateFit := (kind = "donate") ? ((donateTotalH - strokeW) / 21.6) : 1.0
    pen := CreateIconPen(strokeW / donateFit)
    if (!pen)
        return
    DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", graphics, "Float", cx, "Float", cy, "Int", 0, "UInt")
    DllCall("gdiplus\GdipScaleWorldTransform", "Ptr", graphics, "Float", scale, "Float", scale, "Int", 0, "UInt")
    if (donateFit != 1.0)
        DllCall("gdiplus\GdipScaleWorldTransform", "Ptr", graphics, "Float", donateFit, "Float", donateFit, "Int", 0, "UInt")
    if (kind = "min") {
        half := (16.0 - strokeW) / 2
        DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", -half, "Float", 0.0, "Float", half, "Float", 0.0, "UInt")
    } else if (kind = "close") {
        half := (16.0 - strokeW) / 2
        DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", -half, "Float", -half, "Float", half, "Float", half, "UInt")
        DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", -half, "Float", half, "Float", half, "Float", -half, "UInt")
    } else if (kind = "donate") {
        DrawRoundRectOutline(graphics, pen, -15.0, -10.8, 15.0, 10.8, 2.4)
        DllCall("gdiplus\GdipDrawEllipse", "Ptr", graphics, "Ptr", pen, "Float", -11.75, "Float", -0.35, "Float", 0.7, "Float", 0.7, "UInt")
        DllCall("gdiplus\GdipDrawEllipse", "Ptr", graphics, "Ptr", pen, "Float", 11.05, "Float", -0.35, "Float", 0.7, "Float", 0.7, "UInt")
        DllCall("gdiplus\GdipDrawEllipse", "Ptr", graphics, "Ptr", pen, "Float", -4.8, "Float", -7.1, "Float", 9.6, "Float", 9.6, "UInt")
        DllCall("gdiplus\GdipDrawArc", "Ptr", graphics, "Ptr", pen, "Float", -7.1, "Float", 5.3, "Float", 14.2, "Float", 3.6, "Float", 180.0, "Float", 180.0, "UInt")
        thinBuf := Buffer(A_PtrSize, 0)
        if (DllCall("gdiplus\GdipCreatePen1", "UInt", 0xFFFFFFFF, "Float", strokeW / donateFit, "Int", 2, "Ptr", thinBuf, "UInt") = 0) {
            thinPen := NumGet(thinBuf, 0, "Ptr")
            DllCall("gdiplus\GdipSetPenStartCap", "Ptr", thinPen, "Int", 2, "UInt")
            DllCall("gdiplus\GdipSetPenEndCap", "Ptr", thinPen, "Int", 2, "UInt")
            DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", thinPen, "Int", 2, "UInt")
            DrawDollarSign(graphics, thinPen, 0.0, -2.3, 1.7, 1.4, 3.3)
            DllCall("gdiplus\GdipDeletePen", "Ptr", thinPen, "UInt")
        }
    } else {
        sign := (kind = "up") ? 1.0 : -1.0
        pts := Buffer(24, 0)
        NumPut("Float", -4.5, "Float", 2.2 * sign, "Float", 0.0, "Float", -2.2 * sign, "Float", 4.5, "Float", 2.2 * sign, pts)
        DllCall("gdiplus\GdipDrawLines", "Ptr", graphics, "Ptr", pen, "Ptr", pts, "Int", 3, "UInt")
    }
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen, "UInt")
}

SetTopButtonBg(which, color) {
    global minBtn, closeBtn, donateBtn, minBtnBg, closeBtnBg, donateBtnBg
    if (which = "min") {
        if (minBtnBg = color)
            return
        minBtnBg := color
        ctrl := minBtn
    } else if (which = "donate") {
        if (donateBtnBg = color)
            return
        donateBtnBg := color
        ctrl := donateBtn
    } else {
        if (closeBtnBg = color)
            return
        closeBtnBg := color
        ctrl := closeBtn
    }
    kind := which
    if (PaintControlDirect(ctrl, (d) => DrawTopButton(d, kind)))
        return
    if (IsWindowValid(ctrl)) {
        DllCall("User32\InvalidateRect", "Ptr", ctrl.Hwnd, "Ptr", 0, "Int", false)
        DllCall("User32\UpdateWindow", "Ptr", ctrl.Hwnd)
    }
}

DrawTopButton(drawItemStruct, kind) {
    global minBtnBg, closeBtnBg, donateBtnBg, gdiplusToken
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
    brush := DllCall("Gdi32\CreateSolidBrush", "UInt", HexToColorRef(kind = "min" ? minBtnBg : (kind = "donate" ? donateBtnBg : closeBtnBg)), "Ptr")
    DllCall("User32\FillRect", "Ptr", memoryDc, "Ptr", localRect, "Ptr", brush)
    DllCall("Gdi32\DeleteObject", "Ptr", brush)
    if (gdiplusToken) {
        graphicsBuffer := Buffer(A_PtrSize, 0)
        if (DllCall("gdiplus\GdipCreateFromHDC", "Ptr", memoryDc, "Ptr", graphicsBuffer, "UInt") = 0) {
            graphics := NumGet(graphicsBuffer, 0, "Ptr")
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4, "UInt")
            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 4, "UInt")
            closeNudgeX := 0.0, closeNudgeY := 0.0
            DrawIconGlyph(graphics, kind, width / 2.0 + (kind = "close" ? closeNudgeX : 0.0), height / 2.0 + (kind = "close" ? closeNudgeY : 0.0), GetIconScale(kind))
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics, "UInt")
        }
    }
    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBitmap, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", bitmap)
    DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
    return 1
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

GetRefreshBgBrush(hex) {
    global refreshBgBrushes
    if (!refreshBgBrushes.Has(hex))
        refreshBgBrushes[hex] := DllCall("Gdi32\CreateSolidBrush", "UInt", HexToColorRef(hex), "Ptr")
    return refreshBgBrushes[hex]
}

StartRefreshButtonStyle(state) {
    global refreshButtonBgCurrent, refreshButtonBgFrom, refreshButtonBgTo, refreshButtonAnimationStartedAt, refreshIsLocked
    if (refreshIsLocked) {
        SetTimer(AnimateRefreshButtonStyle, 0)
        refreshButtonBgCurrent := "555555"
        return
    }
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
    if (refreshButtonBgCurrent = refreshButtonBgTo) {
        SetTimer(AnimateRefreshButtonStyle, 0)
        return
    }
    refreshButtonAnimationStartedAt := A_TickCount
    SetTimer(AnimateRefreshButtonStyle, 16)
}

AnimateRefreshButtonStyle(*) {
    global refreshButtonBgCurrent, refreshButtonBgFrom, refreshButtonBgTo
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
    global refreshIsLocked, refreshShowCheck, lastHover, refreshButtonBgCurrent
    refreshIsLocked := true
    lastHover := -1
    refreshShowCheck := false
    refreshButtonBgCurrent := "555555"
    SetTimer(AnimateRefreshButtonStyle, 0)
    SyncRefreshOverlay()
    SetTimer(SyncRefreshOverlay, 10)
    RepaintRefreshButtonNoErase(true)
    refreshArrowAnimating := true
    refreshArrowStartedAt := NowMs()
    refreshArrowAngle := 0.0
    SetTimer(AnimateRefreshArrow, 16)
}

AnimateRefreshArrow(*) {
    global refreshArrowAnimating, refreshArrowStartedAt, refreshArrowDuration, refreshArrowAngle
    if (!refreshArrowAnimating)
        return
    newAngle := Mod((NowMs() - refreshArrowStartedAt) * 360.0 / refreshArrowDuration, 360.0)
    if (Abs(newAngle - refreshArrowAngle) < 0.3)
        return
    refreshArrowAngle := newAngle
    RepaintRefreshButtonNoErase(true)
}

RepaintRefreshButtonNoErase(force := false) {
    global refreshButton, refreshIsLocked
    if (refreshIsLocked && !force)
        return
    if (force && refreshIsLocked) {
        PaintRefreshButtonDirect()
        return
    }
    if (PaintControlDirect(refreshButton, DrawRefreshButton))
        return
    if (IsWindowValid(refreshButton)) {
        DllCall("User32\InvalidateRect", "Ptr", refreshButton.Hwnd, "Ptr", 0, "Int", false)
        DllCall("User32\UpdateWindow", "Ptr", refreshButton.Hwnd)
    }
}

PaintRefreshButtonDirect() {
    global refreshButton, isExiting, isWindowVisible, mainGui, refreshOverlayShown, refreshOverlayCtl
    if (isExiting || !isWindowVisible || !IsWindowValid(refreshButton) || !IsWindowValid(mainGui))
        return
    if (DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int") || !DllCall("User32\IsWindowVisible", "Ptr", refreshButton.Hwnd, "Int"))
        return
    target := (refreshOverlayShown && IsWindowValid(refreshOverlayCtl)) ? refreshOverlayCtl : refreshButton
    rc := Buffer(16, 0)
    if (!DllCall("User32\GetClientRect", "Ptr", target.Hwnd, "Ptr", rc, "Int"))
        return
    hdc := DllCall("User32\GetDC", "Ptr", target.Hwnd, "Ptr")
    if (!hdc)
        return
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    fake := Buffer(itemHwndOffset + A_PtrSize * 2 + 16 + A_PtrSize, 0)
    NumPut("Ptr", hdc, fake, itemHwndOffset + A_PtrSize)
    rectOffset := itemHwndOffset + A_PtrSize * 2
    NumPut("Int", 0, "Int", 0, "Int", NumGet(rc, 8, "Int"), "Int", NumGet(rc, 12, "Int"), fake, rectOffset)
    DrawRefreshButton(fake)
    DllCall("User32\ReleaseDC", "Ptr", target.Hwnd, "Ptr", hdc)
}

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
    rgn := DllCall("Gdi32\CreateRectRgn", "Int", 0, "Int", 0, "Int", bw, "Int", bh, "Ptr")
    selRgn := DllCall("Gdi32\CreateRoundRectRgn", "Int", sx - bx, "Int", sy - by, "Int", sx - bx + sw, "Int", sy - by + sh, "Int", 22, "Int", 22, "Ptr")
    if (rgn && selRgn) {
        DllCall("Gdi32\CombineRgn", "Ptr", rgn, "Ptr", rgn, "Ptr", selRgn, "Int", 1)
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

RefreshOverlayHitTest(wParam, lParam, msg, hwnd) {
    global refreshOverlay, statusFadeOv, updOverlay
    if ((IsObject(refreshOverlay) && hwnd = refreshOverlay.Hwnd) || (IsObject(statusFadeOv) && hwnd = statusFadeOv.Hwnd) || (IsObject(updOverlay) && hwnd = updOverlay.Hwnd))
        return -1
}

CancelRefreshArrowAnimation() {
    global refreshArrowAnimating, refreshArrowAngle, refreshIsLocked, refreshShowCheck, lastHover, refreshButtonBgCurrent
    refreshArrowAnimating := false
    refreshArrowAngle := 0.0
    refreshIsLocked := false
    refreshShowCheck := false
    lastHover := -1
    refreshButtonBgCurrent := "555555"
    SetTimer(AnimateRefreshArrow, 0)
    RepaintRefreshButtonNoErase()
    SetTimer(SyncRefreshOverlay, 0)
    SyncRefreshOverlay()
    SetTimer(SettleRepaint2, -40)
}

StopRefreshArrowAnimation() {
    global refreshArrowAnimating, refreshArrowAngle, refreshIsLocked, refreshShowCheck, lastHover, refreshButtonBgCurrent
    refreshArrowAnimating := false
    refreshArrowAngle := 0.0
    refreshIsLocked := false
    refreshShowCheck := true
    lastHover := -1
    refreshButtonBgCurrent := "000000"
    SetTimer(AnimateRefreshArrow, 0)
    RepaintRefreshButtonNoErase()
    SetTimer(SyncRefreshOverlay, 0)
    SyncRefreshOverlay()
    SetTimer(SettleRepaint2, -40)
}

DrawRefreshButton(drawItemStruct) {
    global refreshButtonBgCurrent, refreshArrowAngle, gdiplusToken, refreshIsLocked, refreshShowCheck, refreshKickStart, refreshKickDuration, refreshRingStroke, refreshCheckStroke
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
            ringPenW := refreshRingStroke
            radius := (28.0 - ringPenW) / 2
            headHalfW := 3.3, headLen := 5.0, headEdgePenW := 1.0
            gapStart := -30.0, sweepAngle := 300.0
            rad := 0.0174532925199433
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
            buttonCX := left + width / 2.0
            buttonCY := top + height / 2.0 - 0.5
            centerX := buttonCX - (minX + maxX) / 2
            centerY := buttonCY
            penBuffer := Buffer(A_PtrSize, 0)
            if (DllCall("gdiplus\GdipCreatePen1", "UInt", iconArgb, "Float", ringPenW, "Int", 2, "Ptr", penBuffer, "UInt") = 0) {
                pen := NumGet(penBuffer, 0, "Ptr")
                DllCall("gdiplus\GdipSetPenStartCap", "Ptr", pen, "Int", 2, "UInt")
                DllCall("gdiplus\GdipSetPenEndCap", "Ptr", pen, "Int", 2, "UInt")
                DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", pen, "Int", 2, "UInt")
                startAngle := gapStart + refreshArrowAngle
                DllCall("gdiplus\GdipDrawArc", "Ptr", graphics, "Ptr", pen, "Float", centerX - radius, "Float", centerY - radius, "Float", radius * 2, "Float", radius * 2, "Float", startAngle, "Float", sweepAngle, "UInt")
                endRadians := (startAngle + sweepAngle) * rad
                baseX := centerX + radius * Cos(endRadians)
                baseY := centerY + radius * Sin(endRadians)
                tangentX := -Sin(endRadians), tangentY := Cos(endRadians)
                radialX := Cos(endRadians), radialY := Sin(endRadians)
                headPoints := Buffer(24, 0)
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
                    DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", edgePen, "Int", 2, "UInt")
                    DllCall("gdiplus\GdipDrawPolygon", "Ptr", graphics, "Ptr", edgePen, "Ptr", headPoints, "Int", 3, "UInt")
                    DllCall("gdiplus\GdipDeletePen", "Ptr", edgePen, "UInt")
                }
                DllCall("gdiplus\GdipDeletePen", "Ptr", pen, "UInt")
            }
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
                checkColor := procDisabled ? iconArgb : 0xFF2FB36C
                checkPenBuffer := Buffer(A_PtrSize, 0)
                if (DllCall("gdiplus\GdipCreatePen1", "UInt", checkColor, "Float", refreshCheckStroke, "Int", 2, "Ptr", checkPenBuffer, "UInt") = 0) {
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

RefreshBlockedWhileActive(what := "Refresh", verb := "refresh") {
    global isRunning, activeProcessName, currentStatusTextOnly, currentStatusColor
    global refreshBlockMsg, refreshBlockPrevText, refreshBlockPrevType
    if (!isRunning)
        return false
    name := (activeProcessName != "") ? activeProcessName : "Process"
    msg := what " is unavailable while '" name "' is running. Press Stop first."
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
    if (currentStatusTextOnly == msg) {
        SetTimer(RestoreStatusAfterRefreshBlock, -4000)
        return true
    }
    SetStatus(msg, "stopped")
    SetTimer(RestoreStatusAfterRefreshBlock, -4000)
    return true
}

RestoreStatusAfterRefreshBlock() {
    global isRunning, isExiting, currentStatusTextOnly, refreshBlockMsg, refreshBlockPrevText, refreshBlockPrevType
    if (isExiting || currentStatusTextOnly != refreshBlockMsg)
        return
    SetStatus(refreshBlockPrevText, refreshBlockPrevType)
    refreshBlockMsg := ""
}

RefreshDisabled() {
    global isRunning
    return connLost || isRunning || RefreshCooldownMs() > 0
}

RefreshCooldownEnded(*) {
    global isExiting, lastHover
    if (isExiting)
        return
    if (RefreshCooldownMs() > 0) {
        SetTimer(RefreshCooldownEnded, -(RefreshCooldownMs() + 50))
        return
    }
    lastHover := -1
    RepaintRefreshButtonNoErase()
    UpdateButtonHover()
}

RefreshCooldownMs() {
    global lastGameRefreshAt
    if (lastGameRefreshAt <= 0)
        return 0
    return Max(0, 60000 - (A_TickCount - lastGameRefreshAt))
}

RefreshProcessList(*) {
    global gameFetchPending, lastGameRefreshAt, refreshIsLocked, currentStatusTextOnly, currentStatusColor
    global refreshBlockMsg, refreshBlockPrevText, refreshBlockPrevType
    if (refreshIsLocked || gameFetchPending || connLost)
        return
    if (RefreshBlockedWhileActive())
        return
    if (gameFetchPending) {
        SetStatus("Loading game titles from Discord…", "running")
        return
    }
    if (lastGameRefreshAt > 0) {
        remainingMs := 60000 - (A_TickCount - lastGameRefreshAt)
        if (remainingMs > 0) {
            remainingSeconds := Ceil(remainingMs / 1000)
            cooldownMsg := (remainingSeconds = 1) ? "Refresh is on cooldown. Try again in 1 second." : Format("Refresh is on cooldown. Try again in {} seconds.", remainingSeconds)
            if (currentStatusTextOnly != refreshBlockMsg) {
                refreshBlockPrevText := currentStatusTextOnly
                switch currentStatusColor {
                    case "E50914": refreshBlockPrevType := "error"
                    case "3A86FF": refreshBlockPrevType := "running"
                    case "F2A900": refreshBlockPrevType := "stopped"
                    default: refreshBlockPrevType := "ready"
                }
            }
            refreshBlockMsg := cooldownMsg
            if (currentStatusTextOnly != cooldownMsg)
                SetStatus(cooldownMsg, "stopped")
            SetTimer(RestoreStatusAfterRefreshBlock, -4000)
            return
        }
    }
    StartRefreshArrowAnimation()
    if (StartDiscordGameLoad()) {
        lastGameRefreshAt := A_TickCount
        SetTimer(RefreshCooldownEnded, -(60000 + 50))
        SetStatus("Loading game titles from Discord…", "running")
    } else {
        CancelRefreshArrowAnimation()
    }
}

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

IsSearchStatusText(text) {
    return text != "" && RegExMatch(text, "^(No game titles match '|Showing all \d+ game titles|Showing \d+ of \d+ game titles matching '|Loaded \d+ game titles\. None match '|\d+ game titles? match(es)? ')")
}

CaptureStatusBeforeSearch(newText) {
    global currentStatusTextOnly, currentStatusColor, showAllPrevText, showAllPrevType
    if (!IsSearchStatusText(newText) || IsSearchStatusText(currentStatusTextOnly) || currentStatusTextOnly = "")
        return
    showAllPrevText := currentStatusTextOnly
    switch currentStatusColor {
        case "E50914": showAllPrevType := "error"
        case "3A86FF": showAllPrevType := "running"
        case "F2A900": showAllPrevType := "stopped"
        default: showAllPrevType := "ready"
    }
}

; Echoing a long query into the status makes it overflow into the scrolling marquee, which rebuilds (and blanks)
; on every keystroke. Keep the echoed part short so typing never triggers that.
ShortQuery(q) {
    ; Full query, never cut with "...". Long text is scrolled by the status marquee instead.
    return q
}

; Closing the dropdown because nothing matches must not flash "Ready" before the "No game titles match" message.
CloseSelectorKeepStatus() {
    global keepSearchStatus
    keepSearchStatus := true
    try CloseProcessSelector()
    finally keepSearchStatus := false
}

RevertSearchStatus() {
    global currentStatusTextOnly, showAllPrevText, showAllPrevType, showAllMsg, isRunning, rpcConnecting, keepSearchStatus
    global processSelect, processOptions, isShowingGameSearchHint
    if (keepSearchStatus)
        return
    showAllMsg := ""
    if (!IsSearchStatusText(currentStatusTextOnly))
        return
    if (isRunning || rpcConnecting) {
        if (showAllPrevText != "")
            SetStatus(showAllPrevText, showAllPrevType)
        return
    }
    ; The text in the search box still matches nothing: the "No game titles match" message stays true, so keep it.
    ; Clicking the status line / elsewhere (focus loss, dropdown close) used to flip it back to "Ready. Select a game
    ; title to begin." while the unmatched text was still sitting in the box.
    if (IsObject(processOptions) && processOptions.Length > 0 && IsWindowValid(processSelect) && !isShowingGameSearchHint) {
        query := Trim(processSelect.Value)
        if (query != "" && GetFilteredTitles(query).Length = 0) {
            SetStatusIfChanged("No game titles match '" . ShortQuery(query) . "'.", "ready")
            return
        }
    }
    matched := ResolveTypedGameTitle()
    if (matched != "")
        SetStatus("Selected: '" matched "'. Press Start to begin.", "ready")
    else
        SetStatus("Ready. Select a game title to begin.", "ready")
}

SetStatusIfChanged(text, type := "ready") {
    global currentStatusTextOnly, currentStatusColor, riskViewActive, statusPendingOn
    want := (type = "error") ? "E50914" : (type = "running") ? "3A86FF" : (type = "stopped") ? "F2A900" : "208A4E"
    if (!riskViewActive && currentStatusTextOnly == text && currentStatusColor = want) {
        ; The newest intent is what is already on screen, so drop any older message still waiting its turn.
        if (statusPendingOn) {
            statusPendingOn := false
            SetTimer(FlushPendingStatus, 0)
        }
        return
    }
    SetStatus(text, type)
}

; Messages that must always appear instantly (user-driven feedback, connection state, same-kind updates).
StatusDwellBypass(text) {
    global statusMinDwellMs, currentStatusTextOnly, refreshBlockMsg, connLost, connMsg, isExiting, riskViewActive
    if (statusMinDwellMs <= 0 || isExiting || riskViewActive || connLost || currentStatusTextOnly = "")
        return true
    if (connMsg != "" && text = connMsg)
        return true
    if (RegExMatch(text, "^Connection restored"))
        return true
    if (refreshBlockMsg != "" && text = refreshBlockMsg)
        return true
    if (IsSearchStatusText(text) || IsSearchStatusText(currentStatusTextOnly) || SubStr(text, 1, 9) = "Selected:")
        return true
    if (text = currentStatusTextOnly)
        return true
    ; Direct results of a Start/Stop click must show instantly; a dwell here read as lag.
    if (SubStr(text, 1, 8) = "Active: " || SubStr(text, 1, 10) = "Inactive: ")
        return true
    ; The Discord game-title loading message is exempt from the minimum dwell; show it immediately.
    if (text = "Loading game titles from Discord…")
        return true
    ; Progress ticks ("Downloading version X... 37%") may update each other without delay.
    if (RegExMatch(text, "^Downloading version ") && RegExMatch(currentStatusTextOnly, "^Downloading version "))
        return true
    return false
}

; Status colours: "ready" = green (idle, success, results, good news) | "running" = blue (working: loading, checking, downloading, installing, or a game active)
;                 "stopped" = yellow (needs attention: empty state, action blocked, stopped, cancelled) | "error" = red (a failure, including connection lost).
; Public entry point. If the visible message is younger than statusMinDwellMs, the new one waits (newest wins).
SetStatus(text, type := "ready") {
    global statusMinDwellMs, statusShownTick, statusPendingOn, statusPendingText, statusPendingType, currentStatusTextOnly, currentStatusColor, riskViewActive, lastSearchStatusTick
    wantColor := (type = "error") ? "E50914" : (type = "running") ? "3A86FF" : (type = "stopped") ? "F2A900" : "208A4E"
    if (!riskViewActive && currentStatusTextOnly == text && currentStatusColor = wantColor) {
        ; Already showing exactly this: do nothing, and drop any older message still waiting (newest wins).
        if (statusPendingOn) {
            statusPendingOn := false
            SetTimer(FlushPendingStatus, 0)
        }
        return
    }
    if (statusPendingOn && statusPendingText == text && statusPendingType = type)
        return
    ; Fast typing fires a search status per keystroke. Throttle instead of debounce: the first one is drawn at
    ; once, and during a burst at most one repaint per 70 ms is made (always the newest text), so the status
    ; never waits for typing to stop and never repaints on every key.
    if (!riskViewActive && IsSearchStatusText(text)) {
        sinceLast := A_TickCount - lastSearchStatusTick
        if (sinceLast < 70) {
            statusPendingOn := true
            statusPendingText := text
            statusPendingType := type
            SetTimer(FlushPendingStatus, -(70 - sinceLast + 1))
            return
        }
    }
    remaining := statusMinDwellMs - (A_TickCount - statusShownTick)
    if (remaining <= 0 || StatusDwellBypass(text)) {
        statusPendingOn := false
        SetTimer(FlushPendingStatus, 0)
        SetStatusNow(text, type)
        return
    }
    statusPendingOn := true
    statusPendingText := text
    statusPendingType := type
    SetTimer(FlushPendingStatus, -(remaining + 5))
}

FlushPendingStatus(*) {
    global statusPendingOn, statusPendingText, statusPendingType, isExiting
    if (!statusPendingOn)
        return
    statusPendingOn := false
    if (isExiting)
        return
    SetStatusNow(statusPendingText, statusPendingType)
}

SetStatusNow(text, type := "ready") {
    global mainGui, statusText, statusDot, statusMarqueeGui
    global marqueeTimerRunning, currentStatusRaw, currentStatusColor
    global dotBlinkTimerRunning, currentStatusTextOnly, isMarqueeActive, dotBlinkStep, isExiting
    global marqueeCycleWidth, marqueeTrackWidth, marqueeOffset, marqueeLastTick, marqueePauseUntil
    global marqueeViewportNeedsShow, marqueeRenderedX, marqueeTrackText, marqueeFrames
    global marqueeCycleText, marqueeRenderedPhase
    global statusGlyph, statusGlyphOn, lastSearchStatusTick
    if (isExiting || !IsSet(mainGui) || !mainGui)
        return
    if (ConnStatusBlocked(text))
        return
    if (riskViewActive) {
        DeferRiskStatus(text, type)
        return
    }
    if (currentStatusTextOnly == text && currentStatusColor = ((type = "error") ? "E50914" : (type = "running") ? "3A86FF" : (type = "stopped") ? "F2A900" : "208A4E"))
        return
    CaptureStatusBeforeSearch(text)
    if (IsSearchStatusText(text))
        lastSearchStatusTick := A_TickCount
    global statusShownTick
    statusShownTick := A_TickCount
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
    if marqueeTimerRunning {
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
        marqueeCycleText := marqueeCycle
        marqueeOffset := 0.0
        marqueeFrames := 0
        marqueeRenderedX := -2147483648
        marqueeRenderedPhase := 0
        marqueeLastTick := FrameStamp()
        marqueePauseUntil := NowMs() + MarqueePauseMs()
        PrebuildStatusMarqueeStrip()
        SetStatusDotBase(currentStatusColor)
        ; The old plain message must be gone from the screen BEFORE the marquee window appears. Before, the
        ; marquee was shown first and the plain text was only hidden afterwards; hiding a transparent control
        ; leaves its pixels until the parent repaints, so for a frame or two both messages were visible.
        HidePlainStatusNow()
        PositionStatusControls()
        statusGlyphOn := false
        if (!marqueeTimerRunning) {
            SetTimer(MarqueeMaster, 8)
            marqueeTimerRunning := true
        }
    } else {
        isMarqueeActive := false
        if (!marqueeViewportNeedsShow)
            statusMarqueeGui.Hide()
        marqueeViewportNeedsShow := true
        statusText.Opt("-Hidden")
        marqueeCycleWidth := 0
        marqueeTrackWidth := 0
        marqueeOffset := 0.0
        if marqueeTimerRunning {
            marqueeTimerRunning := false
        }
        SetStatusDotBase(currentStatusColor)
        ; Every SetFont/Value on this transparent control repaints it (a visible blink), so only touch what changed.
        static shownFontColor := "", shownDisplayText := ""
        if (shownFontColor != currentStatusColor) {
            statusText.SetFont("s12 Norm c" currentStatusColor, "Segoe UI Semibold")
            shownFontColor := currentStatusColor
        }
        if (statusDot.Value != "●")
            statusDot.Value := "●"
        newDisplay := ApplyStatusGlyphText()
        if (shownDisplayText !== newDisplay || statusText.Value !== newDisplay) {
            statusText.Value := newDisplay
            shownDisplayText := newDisplay
        }
        PositionStatusControls()
        dotBlinkStep := 0
        if (!dotBlinkTimerRunning) {
            SetTimer(UpdateDotBlink, 80)
            dotBlinkTimerRunning := true
        }
    }
    Critical("Off")
}

HidePlainStatusNow() {
    global statusText, statusGlyph, mainGui
    if (!IsWindowValid(statusText))
        return
    if (DllCall("User32\IsWindowVisible", "Ptr", statusText.Hwnd, "Int")) {
        statusText.GetPos(&x, &y, &w, &h)
        statusText.Opt("+Hidden")
        if (IsWindowValid(statusGlyph))
            statusGlyph.Opt("+Hidden")
        parent := DllCall("User32\GetParent", "Ptr", statusText.Hwnd, "Ptr")
        if (!parent)
            parent := mainGui.Hwnd
        rc := Buffer(16, 0)
        NumPut("Int", x, "Int", y, "Int", x + w, "Int", y + h, rc)
        ; RDW_INVALIDATE | RDW_ERASE | RDW_UPDATENOW: repaint the freed area right now.
        DllCall("User32\RedrawWindow", "Ptr", parent, "Ptr", rc, "Ptr", 0, "UInt", 0x0105, "Int")
    } else {
        statusText.Opt("+Hidden")
        if (IsWindowValid(statusGlyph))
            statusGlyph.Opt("+Hidden")
    }
}

UpdateDotBlink() {
    global statusDot, dotBlinkStep, currentStatusColor, isExiting, dotPaintHex
    if (isExiting || !IsSet(mainGui) || !mainGui)
        return
    switch currentStatusColor {
        case "E50914": toneList := ["cE50914", "cC90812", "cAD0710", "c92060D", "c76050B", "c5A0408", "c3F0306", "c5A0408", "c76050B", "c92060D", "cAD0710", "cC90812"]
        case "3A86FF": toneList := ["c3A86FF", "c3476E3", "c2E65C6", "c2954AA", "c23438E", "c1D3272", "c182255", "c1D3272", "c23438E", "c2954AA", "c2E65C6", "c3476E3"]
        case "F2A900": toneList := ["cF2A900", "cD79500", "cBD8200", "cA36F00", "c895C00", "c6F4900", "c553600", "c6F4900", "c895C00", "cA36F00", "cBD8200", "cD79500"]
        default: toneList := ["c208A4E", "c1C7B45", "c186B3C", "c145C33", "c104D2A", "c0C3E21", "c082F18", "c0C3E21", "c104D2A", "c145C33", "c186B3C", "c1C7B45"]
    }
    toneIndex := Mod(dotBlinkStep, toneList.Length) + 1
    dotPaintHex := SubStr(toneList[toneIndex], 2)
    if (!PaintControlDirect(statusDot, DrawStatusDot))
        statusDot.SetFont("s12 Norm " toneList[toneIndex], "Segoe UI Semibold")
    dotBlinkStep++
    UpdateWarnSignBlink(toneIndex)
}

SetStatusDotBase(hex) {
    global statusDot, dotPaintHex
    dotPaintHex := hex
    if (!PaintControlDirect(statusDot, DrawStatusDot))
        statusDot.SetFont("s12 Norm c" hex, "Segoe UI Semibold")
}

PrebuildStatusMarqueeStrip() {
    global statusMarqueeText, marqueeStripDirty
    if (!IsWindowValid(statusMarqueeText))
        return
    hdc := DllCall("User32\GetDC", "Ptr", statusMarqueeText.Hwnd, "Ptr")
    if (!hdc) {
        marqueeStripDirty := true
        return
    }
    BuildStatusMarqueeStrip(hdc, 42)
    DllCall("User32\ReleaseDC", "Ptr", statusMarqueeText.Hwnd, "Ptr", hdc)
}

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
    try hFont := SendMessage(0x31, 0, 0, statusDot.Hwnd)
    oldFont := hFont ? DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", hFont, "Ptr") : 0
    DllCall("Gdi32\SetBkMode", "Ptr", memoryDc, "Int", 1)
    DllCall("Gdi32\SetTextColor", "Ptr", memoryDc, "UInt", HexToColorRef((dotPaintHex != "") ? dotPaintHex : currentStatusColor))
    DllCall("User32\DrawTextW", "Ptr", memoryDc, "Str", "●", "Int", -1, "Ptr", localRect, "UInt", 0x00000924)
    if (oldFont)
        DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBitmap, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", bitmap)
    DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
    return 1
}

StatusGlyphSize() {
    return Round(18 * A_ScreenDPI / 96)
}

; Splits the status text around the refresh symbol, reserves blank space for it and records where the arrow goes.
ApplyStatusGlyphText() {
    global currentStatusTextOnly, statusGlyphOn, statusGlyphX, statusDisplayText
    idx := InStr(currentStatusTextOnly, "↻")
    if (!idx) {
        statusGlyphOn := false
        statusDisplayText := currentStatusTextOnly
        return currentStatusTextOnly
    }
    before := SubStr(currentStatusTextOnly, 1, idx - 1)
    after := SubStr(currentStatusTextOnly, idx + 1)
    gw := StatusGlyphSize()
    nb := Chr(0xA0)
    nbW := Max(1, GetTextWidth(nb, "Segoe UI Semibold", 12))
    n := Ceil(gw / nbW)
    pipeW := GetTextWidth("|", "Segoe UI Semibold", 12)
    statusGlyphX := GetTextWidth(before "|", "Segoe UI Semibold", 12) - pipeW + (n * nbW - gw) // 2
    pad := ""
    Loop n
        pad .= nb
    statusGlyphOn := true
    statusDisplayText := before . pad . after
    return statusDisplayText
}

PositionStatusGlyph(textX, statusY, statusHeight) {
    global statusGlyph, statusGlyphOn, statusGlyphX, isMarqueeActive, riskViewActive
    if (!IsWindowValid(statusGlyph))
        return
    if (!statusGlyphOn || isMarqueeActive || riskViewActive) {
        statusGlyph.Opt("+Hidden")
        return
    }
    gs := StatusGlyphSize()
    statusGlyph.Move(textX + statusGlyphX, statusY + (statusHeight - gs) // 2 + 1, gs, gs)
    statusGlyph.Opt("-Hidden")
    PaintControlDirect(statusGlyph, DrawStatusGlyph)
}

; Draws the same ring-and-arrowhead as the refresh button, scaled down, in the current status colour.
DrawStatusGlyph(drawItemStruct) {
    global gdiplusToken, currentStatusColor
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
    if (gdiplusToken) {
        graphicsBuffer := Buffer(A_PtrSize, 0)
        if (DllCall("gdiplus\GdipCreateFromHDC", "Ptr", memoryDc, "Ptr", graphicsBuffer, "UInt") = 0) {
            graphics := NumGet(graphicsBuffer, 0, "Ptr")
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4, "UInt")
            k := A_ScreenDPI / 96
            penW := 2.0 * k, radius := 6.0 * k, headHalfW := 2.8 * k, headLen := 4.2 * k
            gapStart := -30.0, sweepAngle := 300.0, rad := 0.0174532925199433
            minX := 1.0e9, maxX := -1.0e9
            sampleAngle := gapStart
            Loop 61 {
                sx := radius * Cos(sampleAngle * rad)
                minX := Min(minX, sx), maxX := Max(maxX, sx)
                sampleAngle := Min(gapStart + sweepAngle, sampleAngle + 5.0)
            }
            endRad := (gapStart + sweepAngle) * rad
            bx := radius * Cos(endRad), by := radius * Sin(endRad)
            for hx in [bx + Cos(endRad) * headHalfW, bx - Cos(endRad) * headHalfW, bx - Sin(endRad) * headLen]
                minX := Min(minX, hx), maxX := Max(maxX, hx)
            minX -= penW / 2, maxX += penW / 2
            centerX := width / 2.0 - (minX + maxX) / 2
            centerY := height / 2.0
            argb := 0xFF000000 | Integer("0x" currentStatusColor)
            penBuffer := Buffer(A_PtrSize, 0)
            if (DllCall("gdiplus\GdipCreatePen1", "UInt", argb, "Float", penW, "Int", 2, "Ptr", penBuffer, "UInt") = 0) {
                pen := NumGet(penBuffer, 0, "Ptr")
                DllCall("gdiplus\GdipSetPenStartCap", "Ptr", pen, "Int", 2, "UInt")
                DllCall("gdiplus\GdipSetPenEndCap", "Ptr", pen, "Int", 2, "UInt")
                DllCall("gdiplus\GdipDrawArc", "Ptr", graphics, "Ptr", pen, "Float", centerX - radius, "Float", centerY - radius, "Float", radius * 2, "Float", radius * 2, "Float", gapStart, "Float", sweepAngle, "UInt")
                DllCall("gdiplus\GdipDeletePen", "Ptr", pen, "UInt")
            }
            baseX := centerX + bx, baseY := centerY + by
            tangentX := -Sin(endRad), tangentY := Cos(endRad)
            radialX := Cos(endRad), radialY := Sin(endRad)
            headPoints := Buffer(24, 0)
            NumPut("Float", baseX + radialX * headHalfW, "Float", baseY + radialY * headHalfW
                 , "Float", baseX + tangentX * headLen, "Float", baseY + tangentY * headLen
                 , "Float", baseX - radialX * headHalfW, "Float", baseY - radialY * headHalfW, headPoints)
            headBrushBuffer := Buffer(A_PtrSize, 0)
            if (DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr", headBrushBuffer, "UInt") = 0) {
                headBrush := NumGet(headBrushBuffer, 0, "Ptr")
                DllCall("gdiplus\GdipFillPolygon", "Ptr", graphics, "Ptr", headBrush, "Ptr", headPoints, "Int", 3, "Int", 0, "UInt")
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", headBrush, "UInt")
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

PositionStatusControls() {
    global mainGui, statusDot, statusText, statusMarqueeGui, statusMarqueeText, statusFadeShown
    if (statusFadeShown)
        return
    global currentStatusTextOnly, isExiting, isWindowVisible
    global isMarqueeActive, marqueeOffset
    global marqueeViewportX, marqueeViewportY, marqueeViewportW, marqueeViewportH, marqueeViewportNeedsShow, marqueeRenderedX
    global marqueeStripPhases, marqueeRenderedPhase, statusRightPad
    if (isExiting || !isWindowVisible || !IsSet(mainGui) || !mainGui)
        return
    try {
        WinGetPos(,, &mainWidth, &mainHeight, "ahk_id " mainGui.Hwnd)
    } catch {
        return
    }
    if (riskViewActive)
        return
    statusHeight := statusTextH
    statusY := statusTextY
    dotY := statusDotY
    dotX := GetStatusDotX(mainWidth)
    static dotWidthCache := 0
    if (!dotWidthCache)
        dotWidthCache := GetTextWidth("●", "Segoe UI Semibold", 12)
    dotWidth := dotWidthCache
    statusDot.GetPos(&curDotX, &curDotY, &curDotW, &curDotH)
    if (curDotX != dotX || curDotY != dotY || curDotW != dotWidth || curDotH != statusDotH)
        statusDot.Move(dotX, dotY, dotWidth, statusDotH)
    textX := GetStatusTextX(mainWidth)
    if (isMarqueeActive) {
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
        msgWidth := GetTextWidth(statusDisplayText != "" ? statusDisplayText : currentStatusTextOnly, "Segoe UI Semibold", 12)
        statusText.GetPos(&curTxtX, &curTxtY, &curTxtW, &curTxtH)
        if (curTxtX != textX || curTxtY != statusY || curTxtW != msgWidth + 20 || curTxtH != statusHeight)
            statusText.Move(textX, statusY, msgWidth + 20, statusHeight)
        PositionStatusGlyph(textX, statusY, statusHeight)
    }
}

RepaintStatusMarquee() {
    global statusMarqueeText, riskViewActive, statusFadeShown
    if (riskViewActive)
        return
    if (statusFadeShown) {
        PaintStatusFadeOverlay()
        return
    }
    if (PaintControlDirect(statusMarqueeText, DrawStatusMarquee))
        return
    if (IsWindowValid(statusMarqueeText)) {
        DllCall("User32\InvalidateRect", "Ptr", statusMarqueeText.Hwnd, "Ptr", 0, "Int", false)
        DllCall("User32\UpdateWindow", "Ptr", statusMarqueeText.Hwnd)
    }
}

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
    DllCall("User32\SetLayeredWindowAttributes", "Ptr", statusFadeOv.Hwnd, "UInt", 0, "UChar", alpha, "UInt", 3, "Int")
    statusFadeOv.Show(Format("NA x{} y{} w{} h{}", x, y, w, h))
    statusFadeShown := true
    PaintStatusFadeOverlay()
    statusMarqueeGui.Hide()
}

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
    global statusFadeCtl, statusFadeShown, isExiting
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

InitMarqueeTiming() {
    ApplyMarqueeRefresh(GetMarqueeHz(0))
}

MarqueePauseMs() {
    return 750
}

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
        marqueeFrames := Integer(Round(marqueeOffset * newStep / newPx))
        dropdownMarqueeFrames := Integer(Round(dropdownMarqueeOffset * newStep / newPx))
        riskTitleFrames := Integer(Round(riskTitleOffset * newStep / newPx))
        marqueeFrameStep := newStep
        marqueePxStep := newPx
        marqueeStripDirty := true
        riskTitleStripDirty := true
        dropdownStripDirty := true
    }
}

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
    info := Buffer(304, 0)
    NumPut("UInt", 304, info, 0)
    if (DllCall("Dwmapi\DwmGetCompositionTimingInfo", "Ptr", 0, "Ptr", info, "Int") = 0) {
        num := NumGet(info, 4, "UInt"), den := NumGet(info, 8, "UInt")
        if (den > 0 && Abs(num / den - hz) < 1.5)
            hz := num / den
    }
    return hz
}

MarqueeAdvance(&lastTick, &frames, now, fine := false) {
    global marqueeRefreshHz, marqueeFrameStep, marqueePxStep
    cap := fine ? 2 : marqueeFrameStep
    vc := GetDwmRefreshCount()
    if (vc) {
        passed := vc - lastTick
        if (passed < 1)
            return -1
        lastTick := vc
        frames += Min(passed, cap)
    } else {
        passed := Round((now - lastTick) * marqueeRefreshHz / 1000)
        if (passed < 1)
            return -1
        lastTick := now
        frames += Min(passed, cap)
    }
    if (fine)
        return frames * marqueePxStep / marqueeFrameStep
    return (frames // marqueeFrameStep) * marqueePxStep
}

MarqueeMaster() {
    global marqueeTimerRunning, isMarqueeActive, isExiting, marqueePauseUntil, dropdownMarqueeIndex, dropdownMarqueePauseUntil
    global riskViewActive, riskViewBusy, riskTitleActive, riskTitlePauseUntil, marqueeBudgetMs, exitFadeRunning, exitDlgBusy
    static busy := false
    if (isExiting || busy || riskViewBusy || exitFadeRunning || exitDlgBusy)
        return
    busy := true
    try {
        loopStart := 0
        Loop {
            if (riskViewBusy)
                break
            now := NowMs()
            statusMoving := (marqueeTimerRunning && isMarqueeActive && now >= marqueePauseUntil)
            dropdownMoving := (!riskViewActive && dropdownMarqueeIndex != -1 && now >= dropdownMarqueePauseUntil)
            riskTitleMoving := (riskViewActive && riskTitleActive && now >= riskTitlePauseUntil)
            moving := (statusMoving || dropdownMoving || riskTitleMoving)
            if (moving) {
                if (DllCall("Dwmapi\DwmFlush", "Int") != 0)
                    Sleep(1)
                if (!loopStart)
                    loopStart := NowMs()
            }
            UpdateMarquee()
            if (!riskViewActive)
                UpdateDropdownMarquee()
            UpdateRiskTitleMarquee()
            if (isExiting || !moving)
                break
            Sleep(-1)
            if (isExiting)
                break
            if (loopStart && NowMs() - loopStart >= marqueeBudgetMs) {
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

MarqueeChoosePhases(stripW, bandH) {
    global marqueeSubpxPhases, marqueeSubpixel, gdiplusToken, marqueeFrameStep
    if (!marqueeSubpixel || !gdiplusToken)
        return 1
    n := Max(1, Integer(marqueeFrameStep))
    m := Max(1, Round(Max(1, Integer(marqueeSubpxPhases)) / n))
    while (m >= 1) {
        k := n * m
        if (stripW * bandH * k * 4 <= 50331648)
            return (k >= 2) ? k : 1
        m -= 1
    }
    return 1
}

BuildSubpixelBands(dc, stripW, bandH, phases, text, copies, copyStepPx, targetWidthPx, fontName, emPx, bold, colorHex, tmHeight, yTopOverride := "", noGamma := false) {
    global gdiplusToken, marqueeSubpxYAdjust, marqueeSubpxUsePath, marqueeSubpxGamma
    if (!gdiplusToken || phases < 2 || text = "" || !dc)
        return false
    g := 0, fam := 0, font := 0, fmt := 0, brush := 0, gpath := 0, ok := false
    try {
        if (DllCall("gdiplus\GdipCreateFromHDC", "Ptr", dc, "Ptr*", &g, "Int") != 0 || !g)
            throw Error("graphics")
        DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", g, "Int", 4, "Int")
        if (marqueeSubpxGamma && !noGamma)
            DllCall("gdiplus\GdipSetCompositingQuality", "Ptr", g, "Int", 3, "Int")
        if (DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", fontName, "Ptr", 0, "Ptr*", &fam, "Int") != 0 || !fam) {
            fam := 0
            if (DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &fam, "Int") != 0 || !fam)
                throw Error("family")
        }
        if (DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", emPx + 0.0, "Int", bold ? 1 : 0, "Int", 2, "Ptr*", &font, "Int") != 0 || !font)
            throw Error("font")
        gf := 0
        DllCall("gdiplus\GdipStringFormatGetGenericTypographic", "Ptr*", &gf, "Int")
        if (!gf || DllCall("gdiplus\GdipCloneStringFormat", "Ptr", gf, "Ptr*", &fmt, "Int") != 0 || !fmt)
            throw Error("format")
        fl := 0
        DllCall("gdiplus\GdipGetStringFormatFlags", "Ptr", fmt, "Int*", &fl, "Int")
        DllCall("gdiplus\GdipSetStringFormatFlags", "Ptr", fmt, "Int", fl | 0x1000 | 0x4000 | 0x800, "Int")
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
        yTop := ((bandH - tmHeight) // 2) + marqueeSubpxYAdjust
        if (yTopOverride != "")
            yTop := yTopOverride
        usePath := false
        if (marqueeSubpxUsePath) {
            if (DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &gpath, "Int") = 0 && gpath) {
                NumPut("Float", 0.0, "Float", 0.0, "Float", 100000.0, "Float", bandH + 0.0, layout, 0)
                if (DllCall("gdiplus\GdipAddPathString", "Ptr", gpath, "WStr", text, "Int", -1, "Ptr", fam, "Int", bold ? 1 : 0, "Float", emPx + 0.0, "Ptr", layout, "Ptr", fmt, "Int") = 0) {
                    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4, "Int")
                    usePath := true
                }
            }
        }
        Loop phases {
            i := A_Index - 1
            yBase := i * bandH
            DllCall("gdiplus\GdipResetWorldTransform", "Ptr", g, "Int")
            DllCall("gdiplus\GdipSetClipRectI", "Ptr", g, "Int", 0, "Int", yBase, "Int", stripW, "Int", bandH, "Int", 0, "Int")
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

FreeStatusMarqueeStrip() {
    global marqueeStripDc, marqueeStripBmp, marqueeStripOld
    if (marqueeStripDc) {
        DllCall("Gdi32\SelectObject", "Ptr", marqueeStripDc, "Ptr", marqueeStripOld, "Ptr")
        DllCall("Gdi32\DeleteObject", "Ptr", marqueeStripBmp)
        DllCall("Gdi32\DeleteDC", "Ptr", marqueeStripDc)
    }
    marqueeStripDc := 0, marqueeStripBmp := 0, marqueeStripOld := 0
}

BuildStatusMarqueeStrip(refDc, height) {
    global marqueeTrackText, marqueeTrackWidth, currentStatusColor, marqueeCycleText, marqueeCycleWidth
    global marqueeStripDc, marqueeStripBmp, marqueeStripOld, marqueeStripH, marqueeStripDirty, marqueeStripPhases
    FreeStatusMarqueeStrip()
    marqueeStripDirty := false
    marqueeStripPhases := 1
    stripW := Min(Max(marqueeTrackWidth + 64, 64), 30000)
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
        smoothOk := BuildSubpixelBands(dc, stripW, height, phases, marqueeCycleText, 4, marqueeCycleWidth, marqueeCycleWidth
            , "Segoe UI Semibold", Round(12 * dpi / 72), false, currentStatusColor, tmHeight, "", true)
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
        DllCall("Gdi32\SetTextColor", "Ptr", dc, "UInt", HexToColorRef(currentStatusColor))
        NumPut("Int", height, fullRect, 12)
        DllCall("User32\DrawTextW", "Ptr", dc, "Str", marqueeTrackText, "Int", -1, "Ptr", fullRect, "UInt", 0x00000B24)
    }
    DllCall("Gdi32\SelectObject", "Ptr", dc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)
    marqueeStripDc := dc, marqueeStripBmp := bmp, marqueeStripOld := oldBmp, marqueeStripH := height
    marqueeStripPhases := phases
}

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
    if (marqueeStripDirty || marqueeStripH != height || !marqueeStripDc)
        BuildStatusMarqueeStrip(targetHdc, height)
    if (marqueeStripDc) {
        srcX := (marqueeRenderedX < -1000000) ? 0 : -marqueeRenderedX
        srcY := 0
        if (marqueeStripPhases > 1) {
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
    global marqueeTimerRunning, isExiting, isMarqueeActive, isWindowVisible
    global marqueeCycleWidth, marqueeOffset, marqueeLastTick, marqueePauseUntil, marqueeRenderedX
    global marqueeFrames, marqueeStripPhases, marqueeRenderedPhase
    if (isExiting || !isMarqueeActive || !IsSet(mainGui) || !mainGui)
        return
    if (!isWindowVisible || DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd)) {
        if (marqueeTimerRunning) {
            marqueeTimerRunning := false
        }
        return
    }
    if (marqueeCycleWidth <= 0)
        return
    if (MarqueeTick(&marqueeOffset, &marqueeFrames, &marqueeLastTick, &marqueePauseUntil, &marqueeRenderedX, &marqueeRenderedPhase
        , marqueeCycleWidth, -1, marqueeStripPhases))
        RepaintStatusMarquee()
}

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

MarqueeSafeWait(ms) {
    t0 := A_TickCount
    while (A_TickCount - t0 < ms)
        ServiceMarqueesDuringAnimation()
    ResyncMarqueeClocks()
}

HeaderCreateFont(hdc, fontName := "Segoe UI Semibold", pointSize := 12) {
    return DllCall("Gdi32\CreateFontW", "Int", -Round(pointSize * DllCall("Gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 90) / 72), "Int", 0, "Int", 0, "Int", 0, "Int", 400, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", fontName, "Ptr")
}

HeaderInkScan(text, fontName, pointSize) {
    m := Map("ok", false, "top", 0, "bottom", 0, "tmH", 0, "adv", 0, "cols", [], "left", 0, "right", 0)
    sdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
    if (!sdc)
        return m
    hFont := HeaderCreateFont(sdc, fontName, pointSize)
    mdc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", sdc, "Ptr")
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", mdc, "Ptr", hFont, "Ptr")
    tm := Buffer(64, 0)
    DllCall("Gdi32\GetTextMetricsW", "Ptr", mdc, "Ptr", tm, "Int")
    tmH := NumGet(tm, 0, "Int")
    sz := Buffer(8, 0)
    DllCall("Gdi32\GetTextExtentPoint32W", "Ptr", mdc, "Str", text, "Int", StrLen(text), "Ptr", sz, "Int")
    adv := NumGet(sz, 0, "Int")
    padX := 8, padY := 4
    w := adv + padX * 2, h := tmH + padY * 2
    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0)
    NumPut("Int", w, bi, 4)
    NumPut("Int", -h, bi, 8)
    NumPut("UShort", 1, bi, 12)
    NumPut("UShort", 32, bi, 14)
    bits := 0
    dib := 0
    if (tmH > 0 && adv > 0)
        dib := DllCall("Gdi32\CreateDIBSection", "Ptr", sdc, "Ptr", bi, "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
    if (dib && bits) {
        oldBmp := DllCall("Gdi32\SelectObject", "Ptr", mdc, "Ptr", dib, "Ptr")
        DllCall("Gdi32\SetBkMode", "Ptr", mdc, "Int", 1)
        DllCall("Gdi32\SetTextColor", "Ptr", mdc, "UInt", 0xFFFFFF)
        DllCall("Gdi32\TextOutW", "Ptr", mdc, "Int", padX, "Int", padY, "Str", text, "Int", StrLen(text))
        DllCall("Gdi32\GdiFlush")
        topRow := -1, botRow := -1, leftCol := -1, rightCol := -1
        Loop h {
            y := A_Index - 1
            rowMax := 0
            Loop w {
                v := NumGet(bits, (y * w + A_Index - 1) * 4 + 1, "UChar")
                if (v > rowMax)
                    rowMax := v
                if (v >= 40) {
                    if (leftCol < 0 || A_Index - 1 < leftCol)
                        leftCol := A_Index - 1
                    if (A_Index - 1 > rightCol)
                        rightCol := A_Index - 1
                }
            }
            if (rowMax >= 40) {
                if (topRow < 0)
                    topRow := y
                botRow := y
            }
        }
        if (topRow >= 0) {
            m["top"] := topRow - padY
            m["bottom"] := botRow - padY
            m["left"] := leftCol - padX
            m["right"] := rightCol - padX
            midY := (topRow + botRow) // 2
            Loop w {
                x := A_Index - 1
                v := NumGet(bits, (midY * w + x) * 4 + 1, "UChar")
                if (v >= 6)
                    m["cols"].Push([x - padX, v / 255.0])
            }
            m["tmH"] := tmH
            m["adv"] := adv
            m["ok"] := m["cols"].Length > 0
        }
        DllCall("Gdi32\SelectObject", "Ptr", mdc, "Ptr", oldBmp, "Ptr")
    }
    if (dib)
        DllCall("Gdi32\DeleteObject", "Ptr", dib)
    DllCall("Gdi32\SelectObject", "Ptr", mdc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)
    DllCall("Gdi32\DeleteDC", "Ptr", mdc)
    DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", sdc)
    return m
}

InitUpdaterLayout() {
    global headerText, verTextX, verTextW, verTextH, updSepX, updSepW, updIconX, updIconW, titleBarX, titleBarW, donateBtnX, updIconPx, updIconDx
    global hdrOk, hdrTextY, hdrCenterY, hdrBarRows, hdrBarCols, hdrBarAdv, hdrBarShift, appVersion, appChannel
    f := A_ScreenDPI / 96
    ver := GetTextInk(headerText, "Segoe UI Semibold", 12)
    bar := GetTextInk("|", "Segoe UI Semibold", 12)
    halfW := UpdateIconRestHalfWidth()
    verTextW := Ceil(ver["adv"] / f) + 6
    updSepX := verTextX + verTextW
    updIconW := Ceil(updIconPx / f)
    updIconDx := 0.0
    verInkRight := verTextX + ver["adv"] / f - ver["c"] / f
    barX := updSepX + (updSepW - bar["adv"] / f) / 2
    barInkLeft := barX + bar["a"] / f
    barInkRight := barX + bar["adv"] / f - bar["c"] / f
    gap := barInkLeft - verInkRight
    updIconX := Round(barInkRight + gap - (updIconPx / 2.0 - halfW) / f)
    ctrlH := Round(verTextH * f)
    vm := HeaderInkScan(headerText, "Segoe UI Semibold", 12)
    bm := HeaderInkScan("|", "Segoe UI Semibold", 12)
    hdrOk := false
    hdrBarShift := 0
    if (vm["ok"] && bm["ok"]) {
        hdrCenterY := ctrlH / 2.0
        vz := HeaderInkScan("0", "Segoe UI Semibold", 12)
        vTop := vz["ok"] ? vz["top"] : vm["top"]
        vBot := vz["ok"] ? vz["bottom"] : vm["bottom"]
        hdrTextY := Round(hdrCenterY - (vTop + vBot + 1) / 2.0)
        hdrBarRows := bm["bottom"] - bm["top"] + 1
        hdrBarCols := bm["cols"]
        hdrBarAdv := bm["adv"]
        hdrOk := true
        verX_d := Round(verTextX * f)
        verInkR := verX_d + vm["right"] + 1
        sepX_d := Round(updSepX * f)
        sepW_d := Round(updSepW * f)
        xBar0 := (sepW_d - bm["adv"]) // 2
        edgeL := "", edgeR := ""
        for col in bm["cols"] {
            if (col[2] >= 0.16) {
                if (edgeL = "")
                    edgeL := col[1]
                edgeR := col[1]
            }
        }
        if (edgeL = "")
            edgeL := bm["cols"][1][1], edgeR := bm["cols"][bm["cols"].Length][1]
        barL := sepX_d + xBar0 + edgeL
        barR := sepX_d + xBar0 + edgeR + 1
        gap_d := barL - verInkR
        ; The text-to-"|" gap must be the same for every header text (version text and "Policy Explainer"): measure it for the
        ; version header and nudge the "|" (and with it the icon) by the difference in device pixels.
        refText := appVersion " " appChannel
        if (headerText != refText) {
            refInk := GetTextInk(refText, "Segoe UI Semibold", 12)
            refVm := HeaderInkScan(refText, "Segoe UI Semibold", 12)
            if (refVm["ok"]) {
                refSepX_d := Round((verTextX + Ceil(refInk["adv"] / f) + 6) * f)
                refGap_d := (refSepX_d + xBar0 + edgeL) - (verX_d + refVm["right"] + 1)
                shiftPx := refGap_d - gap_d
                if (Abs(shiftPx) <= 8) {
                    hdrBarShift := shiftPx
                    barL += shiftPx
                    barR += shiftPx
                    gap_d := refGap_d
                }
            }
        }
        iconW_d := Round(updIconW * f)
        target := barR + gap_d
        updIconX := Floor((target - iconW_d / 2.0 + halfW) / f)
        iconX_d := Round(updIconX * f)
        updIconDx := target - (iconX_d + iconW_d / 2.0 - halfW)
        if (Abs(updIconDx) > 4)
            updIconDx := 0.0
    }
    titleBarX := updIconX + updIconW
    titleBarW := donateBtnX - titleBarX
}

UpdateIconGeom(&r, &h, &penW) {
    global updateStroke
    penW := updateStroke
    r := (20.0 - penW) / 2
    h := r * 0.46
}

UpdateIconRestHalfWidth() {
    UpdateIconGeom(&r, &h, &penW)
    rad := 0.0174532925199433
    maxX := 0.0
    for start in [205, 25] {
        a := start
        while (a <= start + 130) {
            maxX := Max(maxX, Abs(r * Cos(a * rad)))
            a += 2
        }
        th := (start + 130) * rad
        nx := Cos(th), ny := Sin(th)
        tx := -ny, ty := nx
        bx := r * nx
        tipx := bx + tx * h * 0.35
        for px in [tipx - tx * h + nx * h * 0.95, tipx, tipx - tx * h - nx * h * 0.95]
            maxX := Max(maxX, Abs(px))
    }
    return maxX + penW / 2
}

RepaintUpdateIcon() {
    global updateIcon, updOverlayShown, updOverlayCtl, isExiting, isWindowVisible, mainGui
    if (isExiting || !isWindowVisible || !IsWindowValid(updateIcon) || !IsWindowValid(mainGui))
        return
    if (DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int"))
        return
    target := (updOverlayShown && IsWindowValid(updOverlayCtl)) ? updOverlayCtl : updateIcon
    if (PaintControlDirect(target, DrawUpdateIcon))
        return
    if (DllCall("User32\IsWindowVisible", "Ptr", target.Hwnd, "Int")) {
        DllCall("User32\InvalidateRect", "Ptr", target.Hwnd, "Ptr", 0, "Int", false)
        DllCall("User32\UpdateWindow", "Ptr", target.Hwnd)
    }
}

SyncUpdateSpin() {
    global updateState, updSpinning, updSpinStart, updSpinAngle, updSpinFinishing, updSpinGrey, updSpinStopAt, updSpinDuration, updSpinStopFrom, updSpinStopDur, updSpinStopStart
    want := (updateState = "checking" || updateState = "downloading" || updateState = "installing")
    if (want && !updSpinning) {
        updSpinning := true
        updSpinFinishing := false
        updSpinGrey := (updateState = "checking")
        updSpinStart := NowMs()
        updSpinAngle := 0.0
        SyncUpdateOverlay()
        SetTimer(SyncUpdateOverlay, 40)
        SetTimer(AnimateUpdateIcon, 16)
    } else if (want && updSpinning) {
        updSpinFinishing := false
        if (updateState != "checking")
            updSpinGrey := false
    } else if (!want && updSpinning && !updSpinFinishing) {
        total := (NowMs() - updSpinStart) * 360.0 / updSpinDuration
        updSpinStopFrom := total
        updSpinStopAt := Ceil(total / 180.0 - 0.001) * 180.0
        updSpinStopDur := 150 + (updSpinStopAt - total) * 2.2
        updSpinStopStart := NowMs()
        updSpinFinishing := true
        if (updSpinStopAt - total < 1)
            FinishUpdateSpin()
    }
}

FinishUpdateSpin() {
    global updSpinning, updSpinAngle, updSpinFinishing
    updSpinning := false
    updSpinFinishing := false
    updSpinAngle := 0.0
    SetTimer(AnimateUpdateIcon, 0)
    SetTimer(SyncUpdateOverlay, 0)
    SyncUpdateOverlay()
}

SyncUpdateOverlay(*) {
    global updOverlay, updOverlayCtl, updOverlayShown, updOverlayGeom, updSpinning, updateIcon, mainGui, isExiting, isWindowVisible, animationActive
    want := !isExiting && updSpinning && isWindowVisible && !animationActive && IsWindowValid(updateIcon) && IsWindowValid(mainGui)
    if (want)
        want := !DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int") && DllCall("User32\IsWindowVisible", "Ptr", updateIcon.Hwnd, "Int")
    if (!want) {
        if (updOverlayShown && IsWindowValid(updOverlay)) {
            updOverlayShown := false
            RepaintUpdateIcon()
            updOverlay.Hide()
        }
        updOverlayShown := false
        updOverlayGeom := ""
        return
    }
    try {
        WinGetPos(&bx, &by, &bw, &bh, "ahk_id " updateIcon.Hwnd)
    } catch {
        return
    }
    geom := bx "|" by "|" bw "|" bh
    if (updOverlayShown && geom = updOverlayGeom)
        return
    if (!IsWindowValid(updOverlay)) {
        updOverlay := Gui("-Caption +ToolWindow +E0x08000000 +Owner" mainGui.Hwnd, "")
        updOverlay.BackColor := "000000"
        updOverlay.MarginX := 0, updOverlay.MarginY := 0
        updOverlayCtl := updOverlay.Add("Text", Format("x0 y0 w{} h{} +0x000D", bw, bh), "")
        RemoveNativeOutline(updOverlay.Hwnd)
        RemoveNativeOutline(updOverlayCtl.Hwnd)
    }
    updOverlayCtl.Move(0, 0, bw, bh)
    updOverlay.Show(Format("NA x{} y{} w{} h{}", bx, by, bw, bh))
    updOverlayShown := true
    updOverlayGeom := geom
    RepaintUpdateIcon()
}

AnimateUpdateIcon(*) {
    global updSpinning, updSpinStart, updSpinAngle, updSpinDuration, updSpinFinishing, updSpinStopAt, updSpinStopFrom, updSpinStopDur, updSpinStopStart
    if (!updSpinning) {
        SetTimer(AnimateUpdateIcon, 0)
        return
    }
    total := (NowMs() - updSpinStart) * 360.0 / updSpinDuration
    if (updSpinFinishing) {
        t := (NowMs() - updSpinStopStart) / updSpinStopDur
        if (t >= 1) {
            FinishUpdateSpin()
            return
        }
        total := updSpinStopFrom + (updSpinStopAt - updSpinStopFrom) * (1 - (1 - t) * (1 - t))
    }
    newAngle := Mod(total, 360.0)
    if (Abs(newAngle - updSpinAngle) < 0.3)
        return
    updSpinAngle := newAngle
    RepaintUpdateIcon()
}

DrawUpdateIcon(drawItemStruct) {
    global gdiplusToken, updSpinAngle, hdrOk, hdrCenterY, updIconDx, updBgCurrent
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
    bitmap := HdrCompatBitmap(width, height)
    if (!bitmap) {
        DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
        return 1
    }
    oldBitmap := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", bitmap, "Ptr")
    localRect := Buffer(16, 0)
    NumPut("Int", 0, "Int", 0, "Int", width, "Int", height, localRect, 0)
    backgroundBrush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x000000, "Ptr")
    if (backgroundBrush) {
        DllCall("User32\FillRect", "Ptr", memoryDc, "Ptr", localRect, "Ptr", backgroundBrush)
        DllCall("Gdi32\DeleteObject", "Ptr", backgroundBrush)
    }
    if (gdiplusToken) {
        graphicsBuffer := Buffer(A_PtrSize, 0)
        if (DllCall("gdiplus\GdipCreateFromHDC", "Ptr", memoryDc, "Ptr", graphicsBuffer, "UInt") = 0) {
            graphics := NumGet(graphicsBuffer, 0, "Ptr")
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4, "UInt")
            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 4, "UInt")
            iconArgb := 0xFF000000 | Integer("0x" UpdateBtnTextHex())
            UpdateIconGeom(&r, &h, &penW)
            pi := 3.14159265358979
            centerX := width / 2.0 + updIconDx
            centerY := hdrOk ? hdrCenterY : height / 2.0
            if (updBgCurrent != "000000" && UpdateBtnClickable()) {
                hovBrushBuf := Buffer(A_PtrSize, 0)
                if (DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000 | Integer("0x" updBgCurrent), "Ptr", hovBrushBuf, "UInt") = 0) {
                    hovBrush := NumGet(hovBrushBuf, 0, "Ptr")
                    hovR := Min(20.0, width / 2.0 - 0.5)
                    DllCall("gdiplus\GdipFillEllipse", "Ptr", graphics, "Ptr", hovBrush, "Float", centerX - hovR, "Float", centerY - hovR, "Float", hovR * 2, "Float", hovR * 2, "UInt")
                    DllCall("gdiplus\GdipDeleteBrush", "Ptr", hovBrush, "UInt")
                }
            }
            penBuffer := Buffer(A_PtrSize, 0)
            if (DllCall("gdiplus\GdipCreatePen1", "UInt", iconArgb, "Float", penW, "Int", 2, "Ptr", penBuffer, "UInt") = 0) {
                pen := NumGet(penBuffer, 0, "Ptr")
                DllCall("gdiplus\GdipSetPenStartCap", "Ptr", pen, "Int", 2, "UInt")
                DllCall("gdiplus\GdipSetPenEndCap", "Ptr", pen, "Int", 2, "UInt")
                DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", pen, "Int", 2, "UInt")
                for start in [205, 25] {
                    st := start + updSpinAngle
                    sweep := 130
                    DllCall("gdiplus\GdipDrawArc", "Ptr", graphics, "Ptr", pen, "Float", centerX - r, "Float", centerY - r, "Float", r * 2, "Float", r * 2, "Float", st, "Float", sweep, "UInt")
                    th := (st + sweep) * pi / 180
                    nx := Cos(th), ny := Sin(th)
                    tx := -ny, ty := nx
                    bx := centerX + r * nx, by := centerY + r * ny
                    tipx := bx + tx * h * 0.35, tipy := by + ty * h * 0.35
                    pts := Buffer(24, 0)
                    NumPut("Float", tipx - tx * h + nx * h * 0.95, "Float", tipy - ty * h + ny * h * 0.95
                         , "Float", tipx, "Float", tipy
                         , "Float", tipx - tx * h - nx * h * 0.95, "Float", tipy - ty * h - ny * h * 0.95, pts, 0)
                    DllCall("gdiplus\GdipDrawLines", "Ptr", graphics, "Ptr", pen, "Ptr", pts, "Int", 3, "UInt")
                }
                DllCall("gdiplus\GdipDeletePen", "Ptr", pen, "UInt")
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

DrawHeaderVersion(drawItemStruct) {
    global headerText, hdrOk, hdrTextY
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
    bitmap := HdrCompatBitmap(width, height)
    if (!bitmap) {
        DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
        return 1
    }
    oldBitmap := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", bitmap, "Ptr")
    localRect := Buffer(16, 0)
    NumPut("Int", 0, "Int", 0, "Int", width, "Int", height, localRect, 0)
    brush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x000000, "Ptr")
    DllCall("User32\FillRect", "Ptr", memoryDc, "Ptr", localRect, "Ptr", brush)
    DllCall("Gdi32\DeleteObject", "Ptr", brush)
    hFont := HeaderCreateFont(memoryDc)
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", hFont, "Ptr")
    y := hdrOk ? hdrTextY : 0
    if (!hdrOk) {
        tm := Buffer(64, 0)
        DllCall("Gdi32\GetTextMetricsW", "Ptr", memoryDc, "Ptr", tm, "Int")
        y := (height - NumGet(tm, 0, "Int")) // 2
    }
    DllCall("Gdi32\SetBkMode", "Ptr", memoryDc, "Int", 1)
    DllCall("Gdi32\SetTextColor", "Ptr", memoryDc, "UInt", 0xA0A0A0)
    text := headerText
    DllCall("Gdi32\TextOutW", "Ptr", memoryDc, "Int", 0, "Int", y, "Str", text, "Int", StrLen(text))
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)
    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBitmap, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", bitmap)
    DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
    return 1
}

HeaderRepaintAll(force := false) {
    global versionText, updateSep, mainGui, isExiting, isWindowVisible, updSpinning, animationActive
    if (animationActive && force != true)
        return
    if (isExiting || !isWindowVisible || !IsWindowValid(mainGui) || !IsWindowValid(versionText) || !IsWindowValid(updateSep))
        return
    if (DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int"))
        return
    PaintControlDirect(versionText, DrawHeaderVersion)
    PaintControlDirect(updateSep, DrawUpdateSep)
    if (!updSpinning)
        RepaintUpdateIcon()
}

HeaderGuardTick(*) {
    HeaderRepaintAll()
    PaintSearchFrameDirect()
}

DrawUpdateSep(drawItemStruct) {
    global gdiplusToken, hdrOk, hdrCenterY, hdrBarRows, hdrBarCols, hdrBarAdv, hdrBarShift
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
    bitmap := HdrCompatBitmap(width, height)
    if (!bitmap) {
        DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
        return 1
    }
    oldBitmap := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", bitmap, "Ptr")
    localRect := Buffer(16, 0)
    NumPut("Int", 0, "Int", 0, "Int", width, "Int", height, localRect, 0)
    brush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x000000, "Ptr")
    DllCall("User32\FillRect", "Ptr", memoryDc, "Ptr", localRect, "Ptr", brush)
    DllCall("Gdi32\DeleteObject", "Ptr", brush)
    if (hdrOk && gdiplusToken) {
        graphicsBuffer := Buffer(A_PtrSize, 0)
        if (DllCall("gdiplus\GdipCreateFromHDC", "Ptr", memoryDc, "Ptr", graphicsBuffer, "UInt") = 0) {
            graphics := NumGet(graphicsBuffer, 0, "Ptr")
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4, "UInt")
            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 4, "UInt")
            xBar0 := (width - hdrBarAdv) // 2 + hdrBarShift
            yTop := hdrCenterY - hdrBarRows / 2.0
            for col in hdrBarCols {
                alpha := Min(255, Round(col[2] * 255))
                brushBuffer := Buffer(A_PtrSize, 0)
                if (DllCall("gdiplus\GdipCreateSolidFill", "UInt", (alpha << 24) | 0xA0A0A0, "Ptr", brushBuffer, "UInt") = 0) {
                    stemBrush := NumGet(brushBuffer, 0, "Ptr")
                    DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", stemBrush, "Float", xBar0 + col[1], "Float", yTop, "Float", 1.0, "Float", hdrBarRows, "UInt")
                    DllCall("gdiplus\GdipDeleteBrush", "Ptr", stemBrush, "UInt")
                }
            }
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics, "UInt")
        }
    } else {
        hFont := HeaderCreateFont(memoryDc)
        oldFont := DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", hFont, "Ptr")
        DllCall("Gdi32\SetBkMode", "Ptr", memoryDc, "Int", 1)
        DllCall("Gdi32\SetTextColor", "Ptr", memoryDc, "UInt", 0xA0A0A0)
        rc := Buffer(16, 0)
        NumPut("Int", 0, "Int", 0, "Int", width, "Int", height, rc, 0)
        DllCall("User32\DrawTextW", "Ptr", memoryDc, "Str", "|", "Int", 1, "Ptr", rc, "UInt", 0x0025)
        DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldFont, "Ptr")
        DllCall("Gdi32\DeleteObject", "Ptr", hFont)
    }
    DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("Gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBitmap, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", bitmap)
    DllCall("Gdi32\DeleteDC", "Ptr", memoryDc)
    return 1
}

IsUpdateBtnHwnd(h) {
    global updateIcon
    return h && IsWindowValid(updateIcon) && h = updateIcon.Hwnd
}

UpdateBtnClickable() {
    global updateState, riskViewActive, isRunning
    return !connLost && !isRunning && !riskViewActive && (updateState = "idle" || updateState = "available")
}

UpdateBtnTextHex() {
    global updateState, updateHovered, updIconHoverHex, updSpinning, updSpinFinishing, updSpinGrey, isRunning
    if (connLost || (isRunning && !UpdaterBusy()))
        return "5A5A5A"
    if (updateState = "available" || updateState = "downloading" || updateState = "installing")
        return "2FB36C"
    if (updateState = "checking" || (updSpinning && updSpinFinishing && updSpinGrey))
        return "A0A0A0"
    return updateHovered ? updIconHoverHex : "FFFFFF"
}

RedrawUpdateBtn() {
    global updateIcon, isExiting
    if (isExiting || !IsWindowValid(updateIcon))
        return
    SyncUpdateSpin()
    RepaintUpdateIcon()
}

StartUpdateBgStyle(state) {
    global updBgCurrent, updBgFrom, updBgTo, updBgStartedAt
    updBgFrom := updBgCurrent
    if (state = "pressed") {
        SetTimer(AnimateUpdateBgStyle, 0)
        updBgCurrent := "555555"
        RepaintUpdateIcon()
        return
    } else if (state = "hover") {
        updBgTo := "3A3A3A"
    } else {
        updBgTo := "000000"
    }
    if (updBgCurrent = updBgTo) {
        SetTimer(AnimateUpdateBgStyle, 0)
        return
    }
    updBgStartedAt := A_TickCount
    SetTimer(AnimateUpdateBgStyle, 16)
}

AnimateUpdateBgStyle(*) {
    global updBgCurrent, updBgFrom, updBgTo, updBgStartedAt, updBgDuration, isExiting
    if (isExiting) {
        SetTimer(AnimateUpdateBgStyle, 0)
        return
    }
    progress := Min(1.0, (A_TickCount - updBgStartedAt) / updBgDuration)
    eased := progress * progress * (3 - 2 * progress)
    updBgCurrent := BlendHexColor(updBgFrom, updBgTo, eased)
    if (progress >= 1.0) {
        updBgCurrent := updBgTo
        SetTimer(AnimateUpdateBgStyle, 0)
    }
    RepaintUpdateIcon()
}

ResetUpdateBg() {
    global updBgCurrent, updBgFrom, updBgTo
    SetTimer(AnimateUpdateBgStyle, 0)
    updBgCurrent := "000000", updBgFrom := "000000", updBgTo := "000000"
}

SetUpdateState(state) {
    global updateState, updateHovered, connGraceUntil
    wasBusy := UpdaterBusy()
    updateState := state
    connGraceUntil := A_TickCount + 20000
    if (wasBusy && !UpdaterBusy())
        ConnProbeReset()
    if (!UpdateBtnClickable()) {
        updateHovered := false
        ResetUpdateBg()
    }
    RedrawUpdateBtn()
}

UpdaterConnectionChanged() {
    global updateState, updateReq, updateInfo, updateHovered, updGot, updResumable, updResumePending
    if (connLost) {
        SetTimer(UpdateCheckPoll, 0)
        SetTimer(UpdateDownloadPoll, 0)
        SetTimer(UpdateRetryChunk, 0)
        if (updateState = "checking") {
            try updateReq.abort()
            updateReq := ""
            updateState := "idle"
        } else if (updateState = "downloading") {
            try updateReq.abort()
            updateReq := ""
            if (updGot > 0 && updResumable) {
                updResumePending := true
            } else {
                UpdateDiscardPartial()
                updateState := IsObject(updateInfo) ? "available" : "idle"
            }
        }
        updateHovered := false
        ResetUpdateBg()
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
        SetStatus("Update checking isn't available in this version.", "stopped")
        return
    }
    SetUpdateState("checking")
    SetStatus("Checking for updates…", "running")
    updateInfo := ""
    req := NewUpdateHttp()
    if (!IsObject(req)) {
        UpdateFailed("Update check failed: A required Windows component is missing. Update Windows and try again.")
        return
    }
    try {
        url := updateInfoUrl (InStr(updateInfoUrl, "?") ? "&" : "?") "nocache=" A_TickCount
        req.Open("GET", url, true)
        req.SetRequestHeader("Cache-Control", "no-cache")
        req.SetRequestHeader("User-Agent", "Ragnious-Updater")
        req.Send()
    } catch {
        UpdateFailed("Update check failed: Unable to reach the update server. Check your connection and try again.", true)
        return
    }
    updateReq := req
    updateReqStart := A_TickCount
    SetTimer(UpdateCheckPoll, 60)
}

UpdateFailed(msg, transport := false) {
    global updateInfo, updateReq, updNetFailTick, connLost
    SetTimer(UpdateCheckPoll, 0)
    SetTimer(UpdateDownloadPoll, 0)
    try updateReq.abort()
    updateReq := ""
    UpdateDiscardPartial()
    SetUpdateState(IsObject(updateInfo) ? "available" : "idle")
    if (connLost)
        return
    SetStatus(msg, "error")
    if (transport) {
        updNetFailTick := A_TickCount
    }
}

UpdateCheckPoll(*) {
    global updateState, updateReq, updateReqStart, updateInfo, appVersion, isExiting, updMinCheckMs, updRetried
    if (isExiting || updateState != "checking" || !IsObject(updateReq)) {
        SetTimer(UpdateCheckPoll, 0)
        return
    }
    try {
        if (updateReq.readyState != 4) {
            if (A_TickCount - updateReqStart > 20000)
                UpdateFailed("Update check failed: The update server timed out. Try again later.", true)
            return
        }
        if (A_TickCount - updateReqStart < updMinCheckMs)
            return
        status := updateReq.status
        text := updateReq.responseText
        if (status > 0 && status < 12000)
            ConnProbeReset()
    } catch {
        UpdateFailed("Update check failed: The server sent an invalid response. Try again later.", true)
        return
    }
    SetTimer(UpdateCheckPoll, 0)
    updateReq := ""
    if (status != 200) {
        if (!updRetried) {
            updRetried := true
            StartUpdateCheck()
            return
        }
        updRetried := false
        UpdateFailed("Update check failed: The update server returned error " status ". Try again later.", status = 0 || status >= 12000)
        return
    }
    updRetried := false
    info := ParseUpdateInfo(text)
    if (!IsObject(info)) {
        UpdateFailed("Update check failed: The update data is invalid. Try again later.")
        return
    }
    if (VerCompare(info["version"], appVersion) > 0) {
        updateInfo := info
        SetUpdateState("available")
        SetStatus("Version " info["version"] " is available. Press the update icon to install it.", "ready")
    } else {
        updateInfo := ""
        SetUpdateState("idle")
        SetStatus("You already have the latest version (" appVersion ").", "ready")
    }
}

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
    if (m.Has("filename")) {
        ext := A_IsCompiled ? "exe" : "ahk"
        if (!RegExMatch(m["filename"], "i)^[^\\/:*?`"<>|]{1,120}\." ext "$") || RegExMatch(m["filename"], "^\.+$"))
            m.Delete("filename")
    }
    return m
}

StartUpdateDownload() {
    global updateInfo, isRunning, rpcConnecting, helperLaunching, updRetried
    global updDlUrl, updDlStart, updFreshTried, updChunkRetries, updHoldStatusUntil, activeProcessName
    if (!IsObject(updateInfo))
        return
    if (isRunning || rpcConnecting || helperLaunching) {
        SetStatus("Updating is unavailable while '" (activeProcessName != "" ? activeProcessName : "Process") "' is running. Press Stop first.", "stopped")
        return
    }
    UpdateDiscardPartial()
    updFreshTried := false, updChunkRetries := 0, updHoldStatusUntil := 0, updDlStart := A_TickCount
    updDlUrl := updateInfo["url"]
    if (updRetried)
        updDlUrl .= (InStr(updDlUrl, "?") ? "&" : "?") "nocache=" A_TickCount
    SetUpdateState("downloading")
    SetStatus("Updating to version " updateInfo["version"] "…", "running")
    UpdateRequestChunk()
}

UpdateRequestChunk() {
    global updateReq, updateReqStart, updDlUrl, updGot, updChunkSize, updValidator, updResumable
    req := NewUpdateHttp()
    if (!IsObject(req)) {
        UpdateChunkFailed("Download failed: A required Windows component is missing. Update Windows and try again.", false)
        return
    }
    try {
        req.Open("GET", updDlUrl, true)
        req.SetRequestHeader("Cache-Control", "no-cache")
        req.SetRequestHeader("Pragma", "no-cache")
        req.SetRequestHeader("User-Agent", "Ragnious-Updater")
        try {
            req.SetRequestHeader("Range", "bytes=" updGot "-" (updGot + updChunkSize - 1))
            if (updGot > 0 && updValidator != "")
                req.SetRequestHeader("If-Range", updValidator)
        } catch {
            if (updGot > 0) {
                UpdateRestartFresh("Resuming downloads isn't supported on this system.")
                return
            }
        }
        req.Send()
    } catch {
        UpdateChunkFailed("Download failed: Couldn't reach the download server. Check your connection and try again.", true)
        return
    }
    updateReq := req
    updateReqStart := A_TickCount
    SetTimer(UpdateDownloadPoll, 80)
}

UpdateDownloadPoll(*) {
    global updateState, updateReq, updateReqStart, isExiting, updMinDownloadMs, updDlDone, updDlStart
    if (isExiting || updateState != "downloading") {
        SetTimer(UpdateDownloadPoll, 0)
        return
    }
    if (updDlDone) {
        if (A_TickCount - updDlStart < updMinDownloadMs)
            return
        SetTimer(UpdateDownloadPoll, 0)
        UpdateFinishDownload()
        return
    }
    if (!IsObject(updateReq)) {
        SetTimer(UpdateDownloadPoll, 0)
        return
    }
    status := 0
    try {
        if (updateReq.readyState != 4) {
            if (A_TickCount - updateReqStart > 60000) {
                SetTimer(UpdateDownloadPoll, 0)
                UpdateChunkFailed("Download failed: The download server did not respond in time. Try again later.", true)
            }
            return
        }
        status := updateReq.status
    } catch {
        SetTimer(UpdateDownloadPoll, 0)
        UpdateChunkFailed("Download interrupted. It will resume when your connection is back.", true)
        return
    }
    SetTimer(UpdateDownloadPoll, 0)
    if (status > 0 && status < 12000)
        ConnProbeReset()
    UpdateHandleChunk(status)
}

UpdateSaveBody(req, path) {
    DirCreate(A_AppData "\Ragnious")
    stm := ComObject("ADODB.Stream")
    stm.Type := 1
    stm.Open()
    stm.Write(req.responseBody)
    stm.SaveToFile(path, 2)
    stm.Close()
}

UpdateFileSize(path) {
    try
        return FileGetSize(path)
    return -1
}

UpdateHandleChunk(status) {
    global updateReq, updateInfo, updRetried, updGot, updTotal, updResumable, updValidator
    global updDlDone, updChunkRetries, updLastPct, updHoldStatusUntil
    file := A_AppData "\Ragnious\update.download"
    chunk := A_AppData "\Ragnious\update.chunk"
    req := updateReq
    if (status = 206) {
        cr := ""
        try cr := req.getResponseHeader("Content-Range")
        if (!RegExMatch(cr, "i)bytes\s+(\d+)-(\d+)/(\d+)", &m)) {
            UpdateRestartFresh("The download server sent an unexpected response.")
            return
        }
        first := m[1] + 0, last := m[2] + 0, total := m[3] + 0
        if (first != updGot || last < first || last >= total || (updTotal > 0 && total != updTotal)) {
            UpdateRestartFresh("The update file changed during download.")
            return
        }
        try {
            UpdateSaveBody(req, chunk)
        } catch {
            UpdateChunkFailed("Download interrupted. It will resume when your connection is back.", true)
            return
        }
        len := last - first + 1
        if (UpdateFileSize(chunk) != len) {
            try FileDelete(chunk)
            UpdateChunkFailed("Download interrupted. It will resume when your connection is back.", true)
            return
        }
        if (UpdateFileSize(file) != updGot && !(updGot = 0 && !FileExist(file))) {
            UpdateRestartFresh("The partial download was corrupted.")
            return
        }
        wrote := false
        loop 5 {
            try {
                buf := FileRead(chunk, "RAW")
                f := FileOpen(file, "a")
                f.RawWrite(buf)
                f.Close()
                wrote := true
                break
            }
            Sleep(150)
        }
        if (!wrote) {
            UpdateFailed("Download failed: Unable to save the update file. Check available disk space and folder permissions.")
            return
        }
        try FileDelete(chunk)
        if (UpdateFileSize(file) != updGot + len) {
            UpdateRestartFresh("The partial download couldn't be saved.")
            return
        }
        if (updGot = 0) {
            v := ""
            try v := req.getResponseHeader("ETag")
            if (v = "" || SubStr(v, 1, 2) = "W/") {
                v := ""
                try v := req.getResponseHeader("Last-Modified")
            }
            updValidator := v
        }
        updGot := last + 1
        updTotal := total
        updResumable := true
        updRetried := false
        updChunkRetries := 0
        updateReq := ""
        UpdateShowProgress()
        if (updGot >= updTotal)
            UpdateMarkDone()
        else
            UpdateRequestChunk()
        return
    }
    if (status = 200) {
        try {
            UpdateSaveBody(req, file)
        } catch {
            UpdateFailed("Download failed: Unable to save the update file. Check available disk space and folder permissions.")
            return
        }
        size := UpdateFileSize(file)
        cl := ""
        try cl := req.getResponseHeader("Content-Length")
        if (size <= 0 || (RegExMatch(cl, "^\d+$") && cl + 0 != size)) {
            UpdateChunkFailed("Download interrupted. It will resume when your connection is back.", true)
            return
        }
        updGot := size, updTotal := size
        updResumable := false
        updRetried := false
        updateReq := ""
        UpdateMarkDone()
        return
    }
    if (status = 416) {
        if (updGot > 0 && updTotal > 0 && updGot >= updTotal) {
            updateReq := ""
            UpdateMarkDone()
        } else
            UpdateRestartFresh("The download server refused to resume.")
        return
    }
    if (status = 0 || status >= 12000 || (status >= 500 && updGot > 0)) {
        UpdateChunkFailed("Download failed: The download server returned error " status ". Try again later.", true)
        return
    }
    if (!updRetried && updGot = 0) {
        updRetried := true
        updateReq := ""
        StartUpdateDownload()
        return
    }
    updRetried := false
    UpdateFailed("Download failed: The download server returned error " status ". Try again later.")
}

UpdateMarkDone() {
    global updDlDone
    updDlDone := true
    SetTimer(UpdateDownloadPoll, 80)
}

UpdateShowProgress() {
    global updGot, updTotal, updLastPct, updHoldStatusUntil, updateInfo
    if (updTotal <= 0)
        return
    pct := Floor(updGot * 100 / updTotal)
    if (pct = updLastPct || A_TickCount < updHoldStatusUntil)
        return
    updLastPct := pct
    SetStatus("Downloading version " updateInfo["version"] "… " pct "%", "running")
}

UpdatePctNow() {
    global updGot, updTotal
    return updTotal > 0 ? Floor(updGot * 100 / updTotal) : 0
}

UpdateChunkFailed(msg, transport := false) {
    global updGot, updResumable, updResumePending, updChunkRetries, updateReq, connLost
    if (transport && updGot > 0 && updResumable) {
        SetTimer(UpdateDownloadPoll, 0)
        try updateReq.abort()
        updateReq := ""
        if (connLost) {
            updResumePending := true
            return
        }
        updChunkRetries += 1
        if (updChunkRetries <= 5) {
            SetTimer(UpdateRetryChunk, -3000)
            return
        }
    }
    UpdateFailed(msg, transport)
}

UpdateRetryChunk() {
    global updateState, isExiting, connLost
    if (isExiting || updateState != "downloading" || connLost)
        return
    UpdateRequestChunk()
}

UpdateDiscardPartial() {
    global updGot, updTotal, updResumable, updResumePending, updValidator, updDlDone, updLastPct
    SetTimer(UpdateRetryChunk, 0)
    try FileDelete(A_AppData "\Ragnious\update.download")
    try FileDelete(A_AppData "\Ragnious\update.chunk")
    updGot := 0, updTotal := 0, updResumable := false, updResumePending := false
    updValidator := "", updDlDone := false, updLastPct := -1
}

UpdateRestartFresh(reason) {
    global updFreshTried, updHoldStatusUntil, updDlStart
    SetTimer(UpdateDownloadPoll, 0)
    if (updFreshTried) {
        UpdateFailed("Update failed: The download was incomplete or invalid. Try again later.")
        return
    }
    updFreshTried := true
    UpdateDiscardPartial()
    updHoldStatusUntil := A_TickCount + 5000
    updDlStart := A_TickCount
    SetStatus(reason " Restarting the download from the beginning…", "running")
    UpdateRequestChunk()
}

UpdateFinishDownload() {
    global updateReq, updateInfo, updateFile, updTotal, updFreshTried
    file := A_AppData "\Ragnious\update.download"
    updateReq := ""
    if (updTotal > 0 && UpdateFileSize(file) != updTotal) {
        UpdateRestartFresh("The downloaded file is incomplete.")
        return
    }
    got := Sha256OfFile(file)
    if (got = "" || got != StrLower(updateInfo["sha256"])) {
        if (!updFreshTried) {
            UpdateRestartFresh("The downloaded file failed verification.")
            return
        }
        UpdateDiscardPartial()
        SetUpdateState("available")
        SetStatus("Update failed: The downloaded file failed verification. Try again later.", "error")
        return
    }
    if (!UpdateFileLooksRight(file)) {
        UpdateDiscardPartial()
        SetUpdateState("available")
        SetStatus("Update failed: The downloaded file isn't a valid application file. Try again later.", "error")
        return
    }
    updateFile := file
    InstallUpdate()
}

ResumeUpdateAfterReconnect(token) {
    global connResumeToken, connLost, isExiting, updResumePending, updateState, updHoldStatusUntil
    global isRunning, rpcConnecting, helperLaunching, updDlDone, updGot
    if (isExiting || token != connResumeToken || !updResumePending || updateState != "downloading")
        return
    if (connLost)
        return
    if (isRunning || rpcConnecting || helperLaunching) {
        UpdateDiscardPartial()
        SetUpdateState("available")
        return
    }
    updResumePending := false
    updHoldStatusUntil := A_TickCount + 5000
    if (updDlDone) {
        UpdateMarkDone()
        return
    }
    if (UpdateFileSize(A_AppData "\Ragnious\update.download") != updGot) {
        UpdateRestartFresh("The partial download was corrupted.")
        return
    }
    UpdateRequestChunk()
}

UpdateFileLooksRight(file) {
    try {
        if (A_IsCompiled) {
            buf := FileRead(file, "RAW m2")
            return buf.Size >= 2 && NumGet(buf, 0, "UShort") = 0x5A4D
        }
        head := FileRead(file, "UTF-8 m400")
        return InStr(head, "#Requires AutoHotkey")
    }
    return false
}

CleanupOldVersion(path, tries := 60) {
    if (!FileExist(path))
        return
    try {
        FileDelete(path)
        return
    }
    if (tries > 0)
        SetTimer(CleanupOldVersion.Bind(path, tries - 1), -500)
}

InstallUpdate() {
    global updateFile, updateInfo, mutexHandle, mutexName
    SetUpdateState("installing")
    SetStatus("Update verified. Installing version " updateInfo["version"] " and restarting…", "running")
    oldPath := A_ScriptFullPath
    target := oldPath
    if (updateInfo.Has("filename")) {
        cand := A_ScriptDir "\" updateInfo["filename"]
        if (cand = oldPath || !FileExist(cand))
            target := cand
    }
    backup := oldPath ".old"
    try FileDelete(backup)
    try {
        FileMove(oldPath, backup, 1)
        FileMove(updateFile, target, 1)
    } catch {
        try {
            if (!FileExist(oldPath) && FileExist(backup))
                FileMove(backup, oldPath, 1)
        }
        SetUpdateState("available")
        SetStatus("Update failed: Unable to replace the application file. Check that the app's folder isn't read-only or protected.", "error")
        return
    }
    if (mutexHandle) {
        DllCall("CloseHandle", "Ptr", mutexHandle)
        mutexHandle := 0
    }
    try {
        cleanArg := ' /cleanup "' backup '"'
        Run(A_IsCompiled ? '"' target '"' cleanArg : '"' A_AhkPath '" "' target '"' cleanArg, A_ScriptDir)
    } catch {
        try {
            FileMove(target, updateFile, 1)
            FileMove(backup, oldPath, 1)
        }
        mutexHandle := DllCall("CreateMutexW", "Ptr", 0, "Int", 0, "Str", mutexName, "Ptr")
        SetUpdateState("available")
        SetStatus("Update failed: The new version couldn't be started. The old version was restored.", "error")
        return
    }
    try Run(A_ComSpec ' /c ping -n 3 127.0.0.1 >nul & del /f /q "' backup '"', , "Hide")
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

UpdaterBusy() {
    global updateState
    return updateState = "checking" || updateState = "downloading" || updateState = "installing"
}

IsInternetAvailable() {
    for url in ["http://www.msftconnecttest.com/connecttest.txt", "https://discord.com", "https://www.google.com"] {
        if (DllCall("wininet\InternetCheckConnectionW", "Str", url, "UInt", 1, "UInt", 0, "Int"))
            return true
    }
    return false
}

RemoveSearchFocusForConnection() {
    global mainGui, processSelect, isGameSearchFocused, isExiting
    if (isExiting || !IsSet(mainGui) || !mainGui || !IsWindowValid(mainGui))
        return
    try {
        if (IsProcessSelectorOpen())
            CloseProcessSelector()
        if (isGameSearchFocused || (IsWindowValid(processSelect) && DllCall("User32\GetFocus", "Ptr") = processSelect.Hwnd)) {
            isGameSearchFocused := false
            DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
        }
    }
}

ConnStatusBlocked(text) {
    global connLost, connMsg, connResume, internetMsgBack, internetMsgBackResume, internetMsgUpdBack
    return connLost && text != connMsg && text != internetMsgBack && text != StrReplace(internetMsgBackResume, "{game}", IsObject(connResume) ? connResume[2] : "") && text != StrReplace(internetMsgUpdBack, "{P}", UpdatePctNow())
}

SetInternetLostStatus() {
    HandleConnectionLoss("refresh")
}

HandleConnectionLoss(kind := "watch") {
    global connLost, connMsg, connBusy, connResume, connLastStart, connResumeToken
    global isRunning, rpcConnecting, rpcCancel, lastHover, isExiting
    global gameFetchPending, asyncXhr, suppressFilterStatus, lastGameRefreshAt
    global internetMsgLost, internetMsgGeneral, internetMsgPaused, internetMsgUpdate, internetMsgUpdCheck, updateState, updNetFailTick
    global internetMsgUpdPaused, updGot, updResumable
    if (isExiting || connLost)
        return
    wasActive := isRunning
    refreshInterrupted := (gameFetchPending || kind = "refresh")
    updDownloading := (updateState = "downloading" || updateState = "installing")
    updChecking := (updateState = "checking")
    if (!updDownloading && !updChecking && updNetFailTick && A_TickCount - updNetFailTick < 20000)
        updDownloading := true
    pendingResume := IsObject(connResume)
    if (updateState = "downloading" && updGot > 0 && updResumable)
        connMsg := StrReplace(internetMsgUpdPaused, "{P}", UpdatePctNow())
    else if (wasActive || pendingResume)
        connMsg := StrReplace(internetMsgPaused, "{game}", pendingResume ? connResume[2] : (IsObject(connLastStart) ? connLastStart[2] : "The game"))
    else if (refreshInterrupted)
        connMsg := internetMsgLost
    else if (updDownloading)
        connMsg := internetMsgUpdate
    else if (updChecking)
        connMsg := internetMsgUpdCheck
    else
        connMsg := internetMsgGeneral
    connLost := true
    connBusy := true
    connResumeToken += 1
    try {
        if (gameFetchPending) {
            try asyncXhr.abort()
            gameFetchPending := false
            asyncXhr := ""
            suppressFilterStatus := false
            SetTimer(CheckDiscordGameLoad, 0)
        }
        if (refreshInterrupted) {
            CancelRefreshArrowAnimation()
            lastGameRefreshAt := 0
        }
        if (wasActive) {
            rpcConnecting := false, rpcCancel := true
            if (!CancelHelperLaunch())
                StopTargetProcess()
            isRunning := false
            if (IsObject(connLastStart))
                connResume := connLastStart
            SetActionLabel("Start")
            SetActionColor("208A4E")
            RepaintActionButtonNoErase()
        }
    } finally {
        connBusy := false
    }
    RemoveSearchFocusForConnection()
    UpdaterConnectionChanged()
    SetStatus(connMsg, "error")
    lastHover := -1
    RepaintRefreshButtonNoErase()
    RepaintActionButtonNoErase()
    UpdateButtonHover()
}

HandleConnectionRestored() {
    global connLost, connMsg, connBusy, connResume, connResumeToken, connResumeDelayMs, isExiting, lastHover
    global internetMsgBack, internetMsgBackResume, internetMsgUpdBack, updResumePending, updateState
    if (isExiting || !connLost || connBusy)
        return
    connLost := false
    connMsg := ""
    lastHover := -1
    UpdaterConnectionChanged()
    RepaintRefreshButtonNoErase()
    if (updResumePending && updateState = "downloading") {
        connResumeToken += 1
        SetStatus(StrReplace(internetMsgUpdBack, "{P}", UpdatePctNow()), "running")
        SetTimer(ResumeUpdateAfterReconnect.Bind(connResumeToken), -connResumeDelayMs)
    } else if (IsObject(connResume)) {
        connResumeToken += 1
        SetStatus(StrReplace(internetMsgBackResume, "{game}", connResume[2]), "running")
        SetTimer(ResumeAfterReconnect.Bind(connResumeToken), -connResumeDelayMs)
    } else {
        SetStatus(internetMsgBack, "ready")
    }
    RepaintActionButtonNoErase()
    UpdateButtonHover()
}

ResumeAfterReconnect(token) {
    global connResume, connResumeToken, connLost, isRunning, isExiting, riskViewActive, riskViewBusy, toggleRunning, actionLocked
    if (isExiting || token != connResumeToken || !IsObject(connResume))
        return
    if (connLost)
        return
    resume := connResume
    if (isRunning || riskViewActive || riskViewBusy || toggleRunning || actionLocked) {
        connResume := ""
        return
    }
    connResume := ""
    RemoveSearchFocusForConnection()
    if (resume[1] = "rpc")
        RpcBeginConnect(resume[2], resume[3])
    else
        BeginHelperLaunch(resume[2], resume[3], resume[4])
}

ConnProbeReset() {
    global connProbe, connFails, connLost
    if (connLost)
        return
    if (IsObject(connProbe))
        try connProbe.abort()
    connProbe := ""
    connFails := 0
}

ConnectionWatchTick(*) {
    global connProbe, isExiting, connLastTick, connFails
    if (isExiting) {
        SetTimer(ConnectionWatchTick, 0)
        if (IsObject(connProbe))
            try connProbe.abort()
        connProbe := ""
        return
    }
    now := A_TickCount
    if (connLastTick && now - connLastTick > 3000) {
        if (IsObject(connProbe))
            try connProbe.abort()
        connProbe := ""
        if (!connLost)
            connFails := 0
    }
    connLastTick := now
    if (IsObject(connProbe)) {
        res := ConnProbeResult()
        if (res < 0)
            return
        connProbe := ""
        ConnProbeDone(res = 1)
    }
    StartConnProbe()
}

ConnProbeDone(ok) {
    global connFails, connLost, connOkTick
    if (ok) {
        connFails := 0
        connOkTick := A_TickCount
        if (connLost)
            HandleConnectionRestored()
    } else {
        if (!connLost && (UpdaterBusy() || A_TickCount < connGraceUntil) && NlmInternetState() = 1) {
            connFails := 0
            return
        }
        connFails += 1
        need := UpdaterBusy() ? 4 : 2
        nlm := NlmInternetState()
        if (!connLost && nlm = 1)
            need := Max(need, 6)
        quiet := (nlm = 0) ? 6000 : 10000
        if (connFails >= need && !connLost && A_TickCount - connOkTick >= quiet)
            HandleConnectionLoss("watch")
    }
}

NlmInternetState() {
    static nlm := ""
    try {
        if (!IsObject(nlm))
            nlm := ComObject("{DCB00C01-570F-4A9B-8D69-199FDBA5723B}", "{DCB00000-570F-4A9B-8D69-199FDBA5723B}")
        return nlm.IsConnectedToInternet ? 1 : 0
    } catch {
        nlm := ""
        return -1
    }
}

StartConnProbe() {
    global connProbe, connProbeStart, connProbeIdx
    static urls := ["http://www.msftconnecttest.com/connecttest.txt", "https://discord.com/api/v10/gateway", "http://clients3.google.com/generate_204"]
    connProbeIdx := Mod(connProbeIdx, urls.Length) + 1
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

ConnProbeResult() {
    global connProbe, connProbeStart, connProbeIdx
    try {
        if (connProbe.readyState != 4) {
            if (A_TickCount - connProbeStart > (UpdaterBusy() ? 10000 : 4000)) {
                try connProbe.abort()
                return 0
            }
            return -1
        }
        st := connProbe.status
        if (connProbeIdx = 1)
            return (st = 200 && InStr(connProbe.responseText, "Microsoft Connect Test")) ? 1 : 0
        return (st >= 100 && st < 600) ? 1 : 0
    } catch {
        return 0
    }
}

QueueWheelScroll(dir) {
    global wheelPendingLines
    if (!IsMouseOverDropdownArea()) {
        wheelPendingLines := 0
        return
    }
    wheelPendingLines += dir
    SetTimer(FlushWheelScroll, -1)
}

FlushWheelScroll(*) {
    global wheelPendingLines
    lines := wheelPendingLines
    wheelPendingLines := 0
    if (lines != 0 && IsMouseOverDropdownArea())
        ScrollListLines(lines)
}

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

GetActiveHoverIndex() {
    global selectorHoveredIndex
    if (RefreshKeyboardNavMode())
        return selectorHoveredIndex
    return GetDropdownItemAtMouse()
}

IsMouseOverScrollArrowButton() {
    global selectorScrollUpBtn, selectorScrollDownBtn, selectorDisplayedOptions
    if (!IsProcessSelectorOpen() || selectorDisplayedOptions.Length <= 3)
        return false
    MouseGetPos(,,, &hoveredCtl, 2)
    return (IsWindowValid(selectorScrollUpBtn) && hoveredCtl = selectorScrollUpBtn.Hwnd)
        || (IsWindowValid(selectorScrollDownBtn) && hoveredCtl = selectorScrollDownBtn.Hwnd)
}

IsDropdownPressHeld() {
    global selectorClickIndex, selectorPressPhase
    return (selectorClickIndex >= 0 && (selectorPressPhase = "press" || selectorPressPhase = "held"))
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
    global selectorDisplayedOptions, selectorHoveredIndex, dropdownMarqueeIndex
    if (itemIndex < 0 || itemIndex >= selectorDisplayedOptions.Length)
        return
    if (dropdownMarqueeIndex != itemIndex) {
        if (!StartDropdownMarquee(itemIndex))
            dropdownMarqueeIndex := -1
    }
    if (itemIndex != selectorHoveredIndex) {
        SetSelectorHoverIndex(itemIndex)
    }
}

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
    leftTextInset := rowLeftInset
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
    BuildDropdownStrip()
    return true
}

PollDropdownHover(*) {
    global selectorList, selectorDisplayedOptions, dropdownMarqueeIndex, selectorUpdating
    if (selectorUpdating || IsContextMenuOpen())
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
    global dropdownMarqueeFrames
    global selectorDisplayedOptions, selectorRowHeight
    global dropdownStripPhases, dropdownRenderedPhase, dropdownStripDirty, selectorUpdating
    if (selectorUpdating || IsContextMenuOpen())
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
    if (dropdownStripDirty)
        BuildDropdownStrip()
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
    global processSelect, isShowingGameSearchHint
    hasQuery := (!isShowingGameSearchHint && IsWindowValid(processSelect) && Trim(processSelect.Value) != "")
    activeIdx := GetActiveHoverIndex()
    anchored := (activeIdx >= 0)
    currSel := activeIdx
    if (!anchored) {
        if (selectorHoveredIndex >= 0 && selectorHoveredIndex < selectorDisplayedOptions.Length) {
            currSel := selectorHoveredIndex
            anchored := true
        } else {
            cs := SendMessage(0x0188, 0, 0, selectorList.Hwnd)
            if (cs >= topIndex && cs < Min(topIndex + visibleRows, selectorDisplayedOptions.Length)) {
                currSel := cs
                anchored := true
            } else
                currSel := topIndex
        }
    }
    if (!anchored && topIndex = 0) {
        newSel := 0
        newTop := 0
    } else if (hasQuery) {
        if (!anchored) {
            newSel := 0
            newTop := 0
        } else {
            newSel := Max(0, Min(selectorDisplayedOptions.Length - 1, currSel + lines))
            newTop := topIndex
            if (newSel < topIndex)
                newTop := newSel
            else if (newSel >= topIndex + visibleRows)
                newTop := newSel - visibleRows + 1
            newTop := Max(0, Min(maxTop, newTop))
        }
    } else {
        newSel := Max(0, Min(selectorDisplayedOptions.Length - 1, currSel + lines))
        newTop := Max(0, Min(maxTop, newSel - 1))
    }
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
    global selectorClickIndex, selectorCommitIndex, isDraggingThumb, selectorScrollThumb, scrollContinuousAction
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
        return
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

IsProcessSelectorOpen() {
    global selectorFrameGui, isExiting
    return (IsSet(isExiting) && IsSet(selectorFrameGui) && !isExiting && IsWindowValid(selectorFrameGui) && DllCall("User32\IsWindowVisible", "Ptr", selectorFrameGui.Hwnd, "Int"))
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

FreeDropdownStrip() {
    global dropdownStripDc, dropdownStripBmp, dropdownStripOld
    if (dropdownStripDc) {
        DllCall("Gdi32\SelectObject", "Ptr", dropdownStripDc, "Ptr", dropdownStripOld, "Ptr")
        DllCall("Gdi32\DeleteObject", "Ptr", dropdownStripBmp)
        DllCall("Gdi32\DeleteDC", "Ptr", dropdownStripDc)
    }
    dropdownStripDc := 0, dropdownStripBmp := 0, dropdownStripOld := 0
}

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
    rowH := SendMessage(0x01A1, 0, 0, selectorList.Hwnd)
    if (dropdownMarqueeIndex >= 0) {
        rc := Buffer(16, 0)
        if (SendMessage(0x0198, dropdownMarqueeIndex, rc.Ptr, selectorList.Hwnd) != -1)
            rowH := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
    }
    if (rowH <= 4 || rowH > 200)
        rowH := selectorRowHeight
    refDc := DllCall("User32\GetDC", "Ptr", selectorList.Hwnd, "Ptr")
    if (!refDc)
        return
    listFont := SendMessage(0x0031, 0, 0, selectorList.Hwnd)
    oldFont := listFont ? DllCall("Gdi32\SelectObject", "Ptr", refDc, "Ptr", listFont, "Ptr") : 0
    face := "Segoe UI", bold := false
    emPx := Round(12 * DllCall("Gdi32\GetDeviceCaps", "Ptr", refDc, "Int", 90) / 72)
    lf := Buffer(92, 0)
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
    yTop := Floor((rowH - 1) / 2 - capCenter + 0.5) + dropdownRowVNudge + dropdownSubpxYAdjust
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

TrackSelectorMouseMove(wParam, lParam, msg, hwnd) {
    global selectorList, selectorFrameGui, selectorDisplayedOptions, selectorMouseLeaveTracking, isDraggingThumb, thumbDragStartY, thumbDragStartThumbY, thumbDragTrackTopY, thumbDragTrackTravel, selectorRowHeight
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
    global selectorFrameGui, selectorScrollUpBtn, selectorScrollDownBtn, selectorScrollThumb, selectorScrollThumbTrack, selectorScrollHoverTarget, isDraggingThumb, selectorDisplayedOptions
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
    RepaintSelectorRows(selectorPreviousHoveredIndex, selectorHoveredIndex)
}

RepaintSelectorList() {
    global selectorList, selectorListFrozen
    if (!IsWindowValid(selectorList))
        return
    DllCall("User32\InvalidateRect", "Ptr", selectorList.Hwnd, "Ptr", 0, "Int", false)
    if (!selectorListFrozen)
        DllCall("User32\UpdateWindow", "Ptr", selectorList.Hwnd)
}

RepaintSelectorRows(indexA, indexB := -1) {
    global selectorList, selectorDisplayedOptions, selectorListFrozen
    if (!IsWindowValid(selectorList))
        return
    rc := Buffer(16, 0)
    for idx in [indexA, indexB] {
        if (idx < 0 || idx >= selectorDisplayedOptions.Length)
            continue
        if (SendMessage(0x0198, idx, rc.Ptr, selectorList.Hwnd) = -1)
            continue
        DllCall("User32\InvalidateRect", "Ptr", selectorList.Hwnd, "Ptr", rc, "Int", false)
    }
    if (!selectorListFrozen)
        DllCall("User32\UpdateWindow", "Ptr", selectorList.Hwnd)
}

UpdateSelectorHover(*) {
    global selectorFrameGui, selectorList, selectorHoverProgress
    if (!IsWindowValid(selectorFrameGui) || !IsWindowValid(selectorList)
        || !DllCall("User32\IsWindowVisible", "Ptr", selectorFrameGui.Hwnd, "Int")) {
        SetTimer(UpdateSelectorHover, 0)
        return
    }
    selectorHoverProgress := 1.0
    RepaintSelectorList()
    SetTimer(UpdateSelectorHover, 0)
}

UpdateRowSeparators() {
    global selectorList, selectorRowSep1, selectorRowSep2, selectorRowHeight, selectorDisplayedOptions
    if (!IsWindowValid(selectorList) || !IsWindowValid(selectorRowSep1) || !IsWindowValid(selectorRowSep2))
        return
    selectorList.GetPos(&listX, &listY, &listW)
    visibleItems := Min(3, selectorDisplayedOptions.Length)
    static lastSepGeom := Map()
    for k, sep in [selectorRowSep1, selectorRowSep2] {
        if (k < visibleItems) {
            sepGeom := listX "|" (listY + k * selectorRowHeight - 1) "|" listW
            DllCall("User32\SetWindowPos", "Ptr", sep.Hwnd, "Ptr", 0, "Int", listX, "Int", listY + k * selectorRowHeight - 1, "Int", listW, "Int", 1, "UInt", 0x0050, "Int")
            if (!lastSepGeom.Has(sep.Hwnd) || lastSepGeom[sep.Hwnd] != sepGeom) {
                lastSepGeom[sep.Hwnd] := sepGeom
                DllCall("User32\InvalidateRect", "Ptr", sep.Hwnd, "Ptr", 0, "Int", false)
                DllCall("User32\UpdateWindow", "Ptr", sep.Hwnd)
            }
        } else {
            DllCall("User32\SetWindowPos", "Ptr", sep.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0097, "Int")
            if (lastSepGeom.Has(sep.Hwnd))
                lastSepGeom.Delete(sep.Hwnd)
        }
    }
}

PositionScrollbarControls(popupW, popupH) {
    global selectorScrollUpBtn, selectorScrollDownBtn, selectorScrollThumb, selectorScrollThumbTrack, selectorScrollSeparator, selectorList
    global selectorDisplayedOptions, selectorScrollHoverTarget
    if (!IsWindowValid(selectorScrollUpBtn) || !IsWindowValid(selectorScrollDownBtn) || !IsWindowValid(selectorScrollThumb) || !IsWindowValid(selectorScrollThumbTrack) || !IsWindowValid(selectorScrollSeparator))
        return
    innerPopupW := popupW - 2
    innerPopupH := popupH - 2
    static lastBarKey := ""
    barKey := Format("{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}", selectorScrollUpBtn.Hwnd, popupW, popupH, scrollUpBtnW, scrollUpBtnH, scrollUpBtnTopInset, scrollDownBtnW, scrollDownBtnH, scrollDownBtnBottomInset, scrollTrackW, scrollTrackTopInset, scrollTrackBottomInset, scrollThumbW, scrollThumbRightInset, scrollSepW, scrollSepRightInset, scrollListReserveW)
    if (selectorDisplayedOptions.Length > 3 && barKey = lastBarKey && DllCall("User32\IsWindowVisible", "Ptr", selectorScrollUpBtn.Hwnd, "Int")) {
        if (IsWindowValid(selectorList))
            MoveCtlIfChanged(selectorList, 1, 0, innerPopupW - scrollListReserveW - 2, innerPopupH)
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
    selectorScrollUpBtn.Move(innerPopupW - scrollUpBtnW, scrollUpBtnTopInset, scrollUpBtnW, scrollUpBtnH)
    selectorScrollDownBtn.Move(innerPopupW - scrollDownBtnW, popupH - 2 - scrollDownBtnBottomInset, scrollDownBtnW, scrollDownBtnH)
    trackY := scrollTrackTopInset
    trackH := Max(1, popupH - 2 - scrollTrackTopInset - scrollTrackBottomInset)
    selectorScrollThumbTrack.Move(innerPopupW - scrollTrackW, trackY, scrollTrackW, trackH)
    selectorScrollSeparator.Move(innerPopupW - scrollSepRightInset, 0, scrollSepW, innerPopupH)
    selectorScrollUpBtn.Opt("-Hidden")
    selectorScrollDownBtn.Opt("-Hidden")
    selectorScrollThumbTrack.Opt("-Hidden")
    selectorScrollThumb.Opt("-Hidden")
    selectorScrollSeparator.Opt("-Hidden")
    selectorScrollUpBtn.Redraw()
    selectorScrollDownBtn.Redraw()
    selectorScrollSeparator.Redraw()
    if (IsWindowValid(selectorList))
        MoveCtlIfChanged(selectorList, 1, 0, innerPopupW - scrollListReserveW - 2, innerPopupH)
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
    global selectorList, selectorDisplayedOptions, selectorScrollThumb, selectorScrollThumbTrack, selectorRowHeight
    if (!IsWindowValid(selectorList) || !IsWindowValid(selectorScrollThumb) || !IsWindowValid(selectorScrollThumbTrack))
        return
    if (selectorDisplayedOptions.Length <= 3)
        return
    selectorScrollThumbTrack.GetPos(&trackX, &trackY, &trackW, &trackH)
    selectorList.GetPos(,, &listW, &listHeight)
    thumbWidth := scrollThumbW
    thumbX := trackX + trackW - scrollThumbRightInset
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
    global selectorScrollHoverTarget, selectorScrollUpBtn, selectorScrollDownBtn
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
    DllCall("Gdi32\SetBkMode", "Ptr", layerDc, "Int", 1)
    DllCall("Gdi32\SetTextColor", "Ptr", layerDc, "UInt", 0x00FFFFFF)
    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(12 * DllCall("Gdi32\GetDeviceCaps", "Ptr", targetHdc, "Int", 90) / 72), "Int", 0, "Int", 0, "Int", 0, "Int", 700, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", "Segoe UI Symbol", "Ptr")
    oldFont := DllCall("Gdi32\SelectObject", "Ptr", layerDc, "Ptr", hFont, "Ptr")
    glyph := isUpButton ? "⌃" : "⌄"
    shiftRight := 0.5
    nudgeUpPct := isUpButton ? 0.0 : 0.03
    posX := -Round(width * 0.025) - Round(width * 0.01) - 1 + shiftRight
    posY := (isUpButton ? Round(height * 0.20) : -Round(height * 0.27)) - height * nudgeUpPct
    ix := Floor(posX), iy := Floor(posY), fx := posX - ix, fy := posY - iy
    passes := []
    for dy in [0, 1] {
        wy := dy ? fy : 1 - fy
        for dx in [0, 1] {
            wx := dx ? fx : 1 - fx
            if (wx * wy > 0.004)
                passes.Push([ix + dx, iy + dy, wx * wy])
        }
    }
    if (passes.Length = 0)
        passes.Push([ix, iy, 1.0])
    textRect := Buffer(16, 0)
    layer2Dc := 0, layer2Bitmap := 0, oldLayer2Bitmap := 0, oldFont2 := 0, cumW := 0.0
    for pass in passes {
        cumW += pass[3]
        drawDc := layerDc
        if (A_Index > 1) {
            if (!layer2Dc) {
                layer2Dc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", targetHdc, "Ptr")
                layer2Bitmap := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", targetHdc, "Int", width, "Int", height, "Ptr")
                if (!layer2Dc || !layer2Bitmap)
                    break
                oldLayer2Bitmap := DllCall("Gdi32\SelectObject", "Ptr", layer2Dc, "Ptr", layer2Bitmap, "Ptr")
                oldFont2 := DllCall("Gdi32\SelectObject", "Ptr", layer2Dc, "Ptr", hFont, "Ptr")
                DllCall("Gdi32\SetBkMode", "Ptr", layer2Dc, "Int", 1)
                DllCall("Gdi32\SetTextColor", "Ptr", layer2Dc, "UInt", 0x00FFFFFF)
            }
            bgBrush2 := DllCall("Gdi32\CreateSolidBrush", "UInt", bgColor, "Ptr")
            DllCall("User32\FillRect", "Ptr", layer2Dc, "Ptr", localRect, "Ptr", bgBrush2)
            DllCall("Gdi32\DeleteObject", "Ptr", bgBrush2)
            drawDc := layer2Dc
        }
        NumPut("Int", pass[1], textRect, 0)
        NumPut("Int", pass[2], textRect, 4)
        NumPut("Int", width + pass[1], textRect, 8)
        NumPut("Int", height + pass[2], textRect, 12)
        DllCall("User32\DrawTextW", "Ptr", drawDc, "Str", glyph, "Int", -1, "Ptr", textRect, "UInt", 0x00000025)
        if (A_Index > 1) {
            DllCall("Msimg32\AlphaBlend", "Ptr", layerDc, "Int", 0, "Int", 0, "Int", width, "Int", height, "Ptr", layer2Dc, "Int", 0, "Int", 0, "Int", width, "Int", height, "UInt", Round(255 * pass[3] / cumW) << 16)
        }
    }
    if (layer2Dc) {
        if (oldFont2)
            DllCall("Gdi32\SelectObject", "Ptr", layer2Dc, "Ptr", oldFont2, "Ptr")
        if (oldLayer2Bitmap)
            DllCall("Gdi32\SelectObject", "Ptr", layer2Dc, "Ptr", oldLayer2Bitmap, "Ptr")
        DllCall("Gdi32\DeleteDC", "Ptr", layer2Dc)
    }
    if (layer2Bitmap)
        DllCall("Gdi32\DeleteObject", "Ptr", layer2Bitmap)
    DllCall("Gdi32\SelectObject", "Ptr", layerDc, "Ptr", oldFont, "Ptr")
    DllCall("Gdi32\DeleteObject", "Ptr", hFont)
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

OpenProcessSelector(*) {
    global processSelect, selectorFrameGui, selectorPopup, selectorList, selectGui, mainGui, isExiting, processOptions, gameFetchPending, selectorRowHeight
    global selectorScrollUpBtn, selectorScrollDownBtn, selectorScrollThumb, selectorScrollThumbTrack, selectorScrollSeparator, selectorRowSep1, selectorRowSep2, isShowingGameSearchHint, selectorDisplayedOptions
    if (isExiting)
        return
    if (gameFetchPending) {
        return
    }
    if (processOptions.Length = 0) {
        SetStatusIfChanged("No game titles loaded. Press ↻ to load them.", "stopped")
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
    contentWidth := (selectorDisplayedOptions.Length <= 3) ? innerPopupW : (innerPopupW - scrollListReserveW - 2)
    selectorList := selectorPopup.Add("ListBox", Format("x1 y0 w{} h{} -Theme -Border -HScroll -VScroll +0x04000000 +0x1000 +0x0001 +0x0010 +0x2000 +0x0100 cFFFFFF Background000000", contentWidth, innerPopupH), [])
    selectorList.SetFont("s12", "Segoe UI")
    RemoveNativeOutline(selectorList.Hwnd)
    selectorScrollUpBtn := selectorPopup.Add("Text", Format("x{} y{} w{} h{} +0x000D Hidden Background000000 cFFFFFF", innerPopupW - scrollUpBtnW, scrollUpBtnTopInset + 1, scrollUpBtnW, scrollUpBtnH), "")
    RemoveNativeOutline(selectorScrollUpBtn.Hwnd)
    selectorScrollDownBtn := selectorPopup.Add("Text", Format("x{} y{} w{} h{} +0x000D Hidden Background000000 cFFFFFF", innerPopupW - scrollDownBtnW, innerPopupH - scrollDownBtnH - 1, scrollDownBtnW, scrollDownBtnH), "")
    RemoveNativeOutline(selectorScrollDownBtn.Hwnd)
    selectorScrollThumbTrack := selectorPopup.Add("Text", Format("x{} y{} w{} h{} +0x000D Hidden Background000000", innerPopupW - scrollTrackW, scrollTrackTopInset + 1, scrollTrackW, innerPopupH - scrollTrackTopInset - scrollTrackBottomInset - 1), "")
    RemoveNativeOutline(selectorScrollThumbTrack.Hwnd)
    selectorScrollThumb := selectorPopup.Add("Text", Format("x{} y{} w{} h{} +0x000D Hidden BackgroundFFFFFF", innerPopupW - scrollThumbRightInset, scrollTrackTopInset + 1, scrollThumbW, 30), "")
    RemoveNativeOutline(selectorScrollThumb.Hwnd)
    selectorScrollSeparator := selectorPopup.Add("Text", Format("x{} y1 w{} h{} Hidden +0x04000000 BackgroundFFFFFF", innerPopupW - scrollSepRightInset, scrollSepW, innerPopupH), "")
    RemoveNativeOutline(selectorScrollSeparator.Hwnd)
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
        return
    FilterDiscordGameList()
    ResizeProcessSelector(selectScreenX, dropdownY, selectW, availableHeight, true)
    initialHover := GetDropdownItemAtMouse()
    if (initialHover >= 0 && initialHover < selectorDisplayedOptions.Length) {
        UpdateDropdownItemHover(initialHover)
    }
    EnsureGameSearchFocus()
}

ResizeProcessSelector(popupX := "", popupY := "", popupW := "", availableHeight := "", animateOpen := false) {
    global selectGui, selectorFrameGui, selectorPopup, selectorList, selectorDisplayedOptions, selectorRowHeight
    global selectorHoveredIndex, selectorPreviousHoveredIndex, selectorHoverProgress, selectorScrollSeparator, selectorUpdating
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
    listW := (selectorDisplayedOptions.Length <= 3) ? innerPopupW : (innerPopupW - scrollListReserveW - 2)
    if (!selectorUpdating && !DllCall("User32\IsWindowVisible", "Ptr", selectorFrameGui.Hwnd, "Int"))
        animateOpen := true
    needMove := animateOpen
    if (!needMove) {
        curRc := Buffer(16, 0)
        if (DllCall("User32\GetWindowRect", "Ptr", selectorFrameGui.Hwnd, "Ptr", curRc, "Int")) {
            curX := NumGet(curRc, 0, "Int"), curY := NumGet(curRc, 4, "Int")
            curW := NumGet(curRc, 8, "Int") - curX, curH := NumGet(curRc, 12, "Int") - curY
            needMove := (curX != popupX || curY != popupY || curW != popupClientW || curH != dropdownHeight)
        } else
            needMove := true
    }
    wasUpdating := selectorUpdating
    if (!needMove && wasUpdating) {
        selectorList.Move(1, 0, listW, innerPopupH)
        PositionScrollbarControls(popupClientW, dropdownHeight)
        return
    }
    DropdownPaintLock(true)
    try {
        ; Always reposition with Move. Show() re-shows the frame, which silently cancels the paint lock, so every
        ; step below (popup, list, scroll controls, rounded regions) reached the screen one by one while the row
        ; count changed (3 -> 2 -> 1 rows). The explicit Show() at the end is only for the first open.
        selectorFrameGui.Move(popupX, popupY, popupClientW, dropdownHeight)
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
    if (wasUpdating)
        return
    if (IsWindowValid(selectorScrollSeparator))
        selectorScrollSeparator.Redraw()
    selectorHoveredIndex := -1
    selectorPreviousHoveredIndex := -1
    selectorHoverProgress := 1.0
    SetTimer(UpdateSelectorHover, 0)
    HoverBestMatchForQuery()
    SetTimer(RefreshInitialScrollThumbShape, -30)
    SetTimer(UpdateScrollControllerHover, 40)
    DropdownZOrderGuard()
    SetTimer(DropdownZOrderGuard, 50)
    EnsureGameSearchFocus()
}

UpdateDropdownRowHeight(dropdownTop) {
    global selectorRowHeight, dropdownRowHeightPx
    selectorRowHeight := dropdownRowHeightPx
}

DropdownPaintLock(lock) {
    global selectorFrameGui, dropdownPaintLockDepth, dropdownPaintLockActive
    if (lock) {
        dropdownPaintLockDepth += 1
        if (dropdownPaintLockDepth = 1) {
            dropdownPaintLockActive := false
            try {
                if (IsWindowValid(selectorFrameGui)) {
                    hwnd := selectorFrameGui.Hwnd
                    ; Only freeze a frame that is really on screen. WM_SETREDRAW(TRUE) sets WS_VISIBLE, so unlocking a frame
                    ; that was hidden when the lock began used to pop it open at its OLD size and content (the flash
                    ; before the dropdown settled), long before the new geometry was ready.
                    if (DllCall("User32\IsWindowVisible", "Ptr", hwnd, "Int")) {
                        dropdownPaintLockActive := true
                        DllCall("User32\SendMessage", "Ptr", hwnd, "UInt", 0x000B, "Ptr", 0, "Ptr", 0, "Ptr")
                    }
                }
            }
        }
        return
    }
    if (dropdownPaintLockDepth <= 0)
        return
    dropdownPaintLockDepth -= 1
    if (dropdownPaintLockDepth > 0)
        return
    wasActive := dropdownPaintLockActive
    dropdownPaintLockActive := false
    try {
        if (!IsWindowValid(selectorFrameGui))
            return
        hwnd := selectorFrameGui.Hwnd
        if (wasActive)
            DllCall("User32\SendMessage", "Ptr", hwnd, "UInt", 0x000B, "Ptr", 1, "Ptr", 0, "Ptr")
        ; One synchronous repaint of the frame and all its children, drawn from the final state.
        if (DllCall("User32\IsWindowVisible", "Ptr", hwnd, "Int"))
            ; Erase ONLY the frame itself (INVALIDATE|ERASE, no ALLCHILDREN). The frame has WS_CLIPCHILDREN, so this just
            ; repaints its white 1px outline, which after a 1 -> 3 row growth was never repainted and stayed black.
            ; Children are then repainted WITHOUT erase (as before), so the popup/list do not flash.
            DllCall("User32\RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0005)
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
    global selectorFrameGui, selectorHoveredIndex, selectorPreviousHoveredIndex, selectorPressedIndex, selectorPressPhase, selectorMouseLeaveTracking
    global selectorClickIndex, selectorCommitIndex, isDraggingThumb, selectorScrollThumb, scrollContinuousAction, dropdownMarqueeIndex, isKeyboardNavigating
    RevertSearchStatus()
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

PrewarmDropdown(*) {
    global selectorFrameGui, processOptions, gameFetchPending, prewarmBuildActive, isExiting, isWindowVisible
    global mainGui, processSelect, isShowingGameSearchHint, refreshIsLocked, animationActive
    if (isExiting || IsWindowValid(selectorFrameGui))
        return
    if (!isWindowVisible || animationActive || refreshIsLocked || gameFetchPending || !IsWindowValid(mainGui) || !IsWindowValid(processSelect)
        || DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int") || IsContextMenuOpen()) {
        SetTimer(PrewarmDropdown, -700)
        return
    }
    if (!isShowingGameSearchHint && Trim(processSelect.Value) != "")
        return
    if (isGameSearchFocused || DllCall("User32\GetFocus", "Ptr") = processSelect.Hwnd || GetKeyState("LButton", "P") || A_TimeIdlePhysical < 1200) {
        SetTimer(PrewarmDropdown, -1500)
        return
    }
    focusBefore := DllCall("User32\GetFocus", "Ptr")
    Critical("On")
    savedOptions := processOptions, savedPending := gameFetchPending
    processOptions := ["x"], gameFetchPending := false, prewarmBuildActive := true
    try
        OpenProcessSelector()
    finally {
        processOptions := savedOptions, gameFetchPending := savedPending, prewarmBuildActive := false
        Critical("Off")
    }
    if (focusBefore && DllCall("User32\GetFocus", "Ptr") != focusBefore && DllCall("User32\IsWindow", "Ptr", focusBefore, "Int"))
        DllCall("User32\SetFocus", "Ptr", focusBefore)
}

OpenDropdownAfterLoad(*) {
    global processOptions, gameFetchPending, isExiting, suppressFilterStatus, isGameSearchFocused, processSelect, selectorDisplayedOptions, isShowingGameSearchHint
    if (isExiting || gameFetchPending || processOptions.Length = 0)
        return
    if (IsProcessSelectorOpen() || isGameSearchFocused || DllCall("User32\GetFocus", "Ptr") = processSelect.Hwnd)
        BuildEmptyQueryTitles()
    suppressFilterStatus := true
    try {
        if (IsProcessSelectorOpen())
            FilterDiscordGameList()
        loadedMessage := ""
        pendingQuery := ""
        pendingState := 0
        try pendingState := OpenDropdownForPendingSearch(&pendingQuery)
        if (pendingState = 1)
            loadedMessage := Format("Showing {} of {} game titles matching '{}'.", selectorDisplayedOptions.Length, processOptions.Length, pendingQuery)
        else if (pendingState = 2)
            loadedMessage := Format("Loaded {} game titles. None match '{}'.", processOptions.Length, pendingQuery)
        else {
            OpenDropdownIfSearchFocused()
            ; The dropdown's own status must replace "Loaded N game titles." instead of lingering behind it.
            if (IsProcessSelectorOpen() && selectorDisplayedOptions.Length > 0) {
                q := Trim(processSelect.Value)
                shown := selectorDisplayedOptions.Length
                if (q != "" && !isShowingGameSearchHint)
                    loadedMessage := (shown = 1) ? "1 game title matches '" . q . "'." : shown . " game titles match '" . q . "'."
                else
                    loadedMessage := Format("Showing all {} game titles.", processOptions.Length)
            }
        }
    } finally {
        suppressFilterStatus := false
    }
    ; Titles just loaded and the box already holds an exact title: show the selected-title status.
    validTitle := ResolveTypedGameTitle()
    if (validTitle != "")
        loadedMessage := "Selected: '" validTitle "'. Press Start to begin."
    if (loadedMessage = "")
        loadedMessage := Format("Loaded {} game titles. Select one to begin.", processOptions.Length)
    SetStatus(loadedMessage, "ready")
}

HoverBestMatchForQuery(repaint := true) {
    global processSelect, selectorList, selectorDisplayedOptions, selectorRowHeight, isShowingGameSearchHint
    global isKeyboardNavigating, keyNavMouseX, keyNavMouseY, selectorListFrozen, selectorHoveredIndex, selectorUpdating
    global selectorPreviousHoveredIndex, selectorHoverProgress
    if ((!selectorUpdating && !IsProcessSelectorOpen()) || !IsWindowValid(selectorList) || !IsWindowValid(processSelect))
        return
    if (isShowingGameSearchHint || selectorDisplayedOptions.Length = 0)
        return
    query := StrLower(Trim(processSelect.Value))
    if (query = "")
        return
    bestIdx := -1, bestScore := 0
    for idx, title in selectorDisplayedOptions {
        tl := StrLower(title)
        pos := InStr(tl, query)
        if (!pos)
            continue
        if (tl = query)
            score := 0
        else if (pos = 1)
            score := 1000 + StrLen(title)
        else if (!RegExMatch(SubStr(tl, pos - 1, 1), "[a-z0-9]"))
            score := 2000 + pos * 100 + StrLen(title)
        else
            score := 3000 + pos * 100 + StrLen(title)
        if (bestIdx < 0 || score < bestScore) {
            bestIdx := idx - 1
            bestScore := score
        }
    }
    if (bestIdx < 0)
        return
    listRc := Buffer(16, 0)
    DllCall("User32\GetWindowRect", "Ptr", selectorList.Hwnd, "Ptr", listRc)
    listHeight := NumGet(listRc, 12, "Int") - NumGet(listRc, 4, "Int")
    visibleRows := Max(1, Floor(listHeight / selectorRowHeight))
    maxTop := Max(0, selectorDisplayedOptions.Length - visibleRows)
    newTop := Max(0, Min(maxTop, bestIdx - 1))
    CoordMode("Mouse", "Screen")
    MouseGetPos(&keyNavMouseX, &keyNavMouseY)
    isKeyboardNavigating := true
    wasFrozen := selectorListFrozen
    selectorListFrozen := true
    SendMessage(0x000B, 0, 0, selectorList.Hwnd)
    try {
        SendMessage(0x0186, bestIdx, 0, selectorList.Hwnd)
        SendMessage(0x0197, newTop, 0, selectorList.Hwnd)
        selectorHoveredIndex := bestIdx
        selectorPreviousHoveredIndex := -1
        selectorHoverProgress := 1.0
    } finally {
        SendMessage(0x000B, 1, 0, selectorList.Hwnd)
        selectorListFrozen := wasFrozen
    }
    if (repaint) {
        RepaintSelectorList()
        UpdateScrollThumbPosition()
    }
}

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
    if (query = "" || ResolveTypedGameTitle() != "")
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

OpenDropdownIfSearchFocused() {
    global processSelect, processOptions, selectedProcessTitle, isExiting, isWindowVisible, mainGui, isGameSearchFocused
    if (isExiting || !isWindowVisible || !IsWindowValid(processSelect) || !IsWindowValid(mainGui) || processOptions.Length = 0)
        return false
    if (DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int") || IsContextMenuOpen() || IsProcessSelectorOpen())
        return false
    hasFocus := DllCall("User32\GetFocus", "Ptr") = processSelect.Hwnd
    if (!(isGameSearchFocused || hasFocus) || !IsForegroundOurProcess())
        return false
    if (Trim(selectedProcessTitle) != "" || ResolveTypedGameTitle() != "")
        return false
    OpenProcessSelector()
    return IsProcessSelectorOpen()
}

RowRightEdgeInset() {
    global selectorDisplayedOptions
    return (selectorDisplayedOptions.Length > 3) ? 0 : 2
}

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
    abc := Buffer(12, 0)
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
    DllCall("User32\DrawTextW", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", calcRect, "UInt", 0x00000C20)
    width := NumGet(calcRect, 8, "Int")
    if (oldFont)
        DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
    DllCall("User32\ReleaseDC", "Ptr", selectorList.Hwnd, "Ptr", hdc)
    StoreRowTextCache(text, width)
    return width
}

RowIconSize() {
    global rowIconPx, selectorRowHeight
    return Max(14, Min(rowIconPx, selectorRowHeight - 5))
}

RowIconOffset(leftTextInset) {
    global rowIconsEnabled, gdiplusToken, rowIconTextGap
    return (rowIconsEnabled && gdiplusToken) ? RowIconSize() + rowIconTextGap : 0
}

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
            GdipDrawIconUnknown(g, x - originLeft, y - originTop, size)
        else
            GdipDrawIconPlaceholder(g, x - originLeft, y - originTop, size)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g, "Int")
    }
    DllCall("Gdi32\SetViewportOrgEx", "Ptr", hdc, "Int", -originLeft, "Int", -originTop, "Ptr", 0)
}

GdipDrawMasterIcon(g, master, x, y, size) {
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4, "Int")
    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", g, "Int", 7, "Int")
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", g, "Int", 2, "Int")
    DllCall("gdiplus\GdipDrawImageRectI", "Ptr", g, "Ptr", master, "Int", x, "Int", y, "Int", size, "Int", size, "Int")
}

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

GameIconIsMissing(title) {
    global gameIconState, gameIconBitmaps
    key := StrLower(title)
    if (gameIconBitmaps.Has(key))
        return false
    return ((gameIconState.Has(key) && gameIconState[key] = 3) || GameIconNoIconFresh(key))
}

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
        path := GdipRoundedSquarePath(0, 0, M)
        if (!path)
            throw Error("path")
        inset := M * 0.19, dotR := M * 0.07
        for pt in [[inset, inset], [M - inset, inset], [inset, M - inset], [M - inset, M - inset]]
            DllCall("gdiplus\GdipAddPathEllipse", "Ptr", path, "Float", pt[1] - dotR, "Float", pt[2] - dotR, "Float", dotR * 2, "Float", dotR * 2, "Int")
        if (DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &fam, "Int") != 0 || !fam)
            throw Error("family")
        DllCall("gdiplus\GdipStringFormatGetGenericTypographic", "Ptr*", &gf, "Int")
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
    GameIconPackDrop(gameIconUnknownKey)
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

GdipDrawIconUnknown(g, x, y, size) {
    master := GetUnknownIconMaster()
    if (master)
        GdipDrawMasterIcon(g, master, x, y, size)
    else
        GdipDrawIconPlaceholder(g, x, y, size)
}

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

GameIconKeyIsSafe(key) {
    return !(InStr(key, "`t") || InStr(key, "`n") || InStr(key, "`r"))
}

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
    f.Seek(0, 2)
    startLen := f.Pos
    extra := (startLen = 0) ? 8 : 0
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
        gameIconPackNeedsRewrite := true
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
    if (IsObject(gameIconMig)) {
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
        return true
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
                continue
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
    if (ok && newSegs.Length = 0) {
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

GameIconLegacyApplyLine(line) {
    global gameIconUnknownFile, gameIconFileNames
    if (line = "")
        return
    f := StrSplit(line, "`t")
    if (f.Length < 2)
        return
    key := f[1]
    if (key = "") {
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
            continue
        isUnknown := (key = gameIconUnknownKey)
        name := isUnknown ? gameIconUnknownFile : (gameIconFileNames.Has(key) ? gameIconFileNames[key] : "")
        if (name = "")
            continue
        buf := 0
        try buf := FileRead(gameIconDir "\" name ".png", "RAW")
        if (!buf || buf.Size < 16) {
            if (!isUnknown && gameIconFileNames.Has(key))
                gameIconFileNames.Delete(key)
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
    if (gameIconPackPend.Count > 0) {
        SetTimer(GameIconMigrateTick, -5000)
        return
    }
    final := gameIconDir "\icons.pack"
    try FileMove(gameIconPackPath, final, 1)
    if (FileExist(final) && !FileExist(gameIconPackPath))
        gameIconPackPath := final
    if (gameIconPackPath = final)
        try Run(A_ComSpec ' /c del /q "' gameIconDir '\*.png" "' gameIconDir '\icons.idx"', , "Hide")
    gameIconMig := ""
    SetTimer(GameIconPackMaintain, -3000)
}

GameIconIndexStart() {
    global gameIconPackPath, gameIconDir, gameIconIdxStage, gameIconIdxSegPos, gameIconIdxLines, gameIconIdxLinePos
    try FileDelete(gameIconPackPath ".new")
    if (FileExist(gameIconPackPath)) {
        if (GameIconPackScan()) {
            gameIconIdxStage := 1
            gameIconIdxSegPos := 1
            return
        }
        try FileDelete(gameIconPackPath)
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
        try Run(A_ComSpec ' /c del /q "' gameIconDir '\*.png" "' gameIconDir '\icons.idx"', , "Hide")
    SetTimer(GameIconPackMaintain, -2500)
}

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

GameIconIndexEnsure() {
    global gameIconIdxReady
    while (!gameIconIdxReady)
        GameIconIndexStep(0)
}

GameIconEncodeMaster(master) {
    if (!master)
        return 0
    stm := 0, hg := 0, len := 0, out := 0
    try {
        clsid := Buffer(16, 0)
        DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)
        if (DllCall("ole32\CreateStreamOnHGlobal", "Ptr", 0, "Int", true, "Ptr*", &stm, "Int") != 0 || !stm)
            return 0
        if (DllCall("gdiplus\GdipSaveImageToStream", "Ptr", master, "Ptr", stm, "Ptr", clsid, "Ptr", 0, "Int") = 0) {
            ComCall(5, stm, "Int64", 0, "UInt", 1, "UInt64*", &len)
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
    if (gameIconBitmaps.Count > gameIconBitmapCap) {
        for k, b in gameIconBitmaps
            DllCall("gdiplus\GdipDisposeImage", "Ptr", b, "Int")
        gameIconBitmaps.Clear()
    }
    if (gameIconBitmaps.Has(key) && gameIconBitmaps[key] != master)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", gameIconBitmaps[key], "Int")
    gameIconBitmaps[key] := master
    GameIconForgetState(key)
}

GameIconNeedsUpdate(key) {
    global gameIconFileNames, gameIconHashes
    if (!gameIconFileNames.Has(key))
        return true
    return gameIconHashes.Has(key) && gameIconHashes[key] != gameIconFileNames[key]
}

GameIconToday() {
    return DateDiff(A_NowUTC, "20000101", "Days")
}

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

GameIconIsCurrent(key) {
    global gameIconFileNames, gameIconUpdateTried
    if (gameIconUpdateTried.Has(key))
        return true
    if (gameIconFileNames.Has(key))
        return !GameIconNeedsUpdate(key)
    return GameIconNoIconFresh(key)
}

GameIconRefreshCycle() {
    global gameIconUpdateTried
    gameIconUpdateTried := Map()
}

TryLoadIconFromDisk(key) {
    global gameIconFileNames
    GameIconIndexEnsure()
    if (!gameIconFileNames.Has(key))
        return 0
    master := GameIconPackLoadMaster(key)
    if (!master) {
        GameIconIndexForget(key)
        return 0
    }
    GameIconCacheStore(key, master)
    return master
}

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
            return 0
        QueueGameIcon(title)
    }
    return 0
}

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

QueueGameIcon(title) {
    global gameIconState, gameIconQueue, gdiplusToken
    if (!gdiplusToken)
        return
    key := StrLower(title)
    if (gameIconState.Has(key))
        return
    gameIconState[key] := 1
    gameIconQueue.Push(title)
    if (gameIconQueue.Length > 40) {
        dropped := gameIconQueue.RemoveAt(1)
        GameIconForgetState(StrLower(dropped))
    }
    SetTimer(GameIconTick, 10)
}

PrefetchGameIcons(titles, count) {
    global gameIconState, gameIconPrefetch, gdiplusToken, rowIconsEnabled
    if (!gdiplusToken || !rowIconsEnabled || !IsObject(titles))
        return
    n := Min(count, titles.Length)
    queued := 0
    Loop n {
        t := titles[A_Index]
        key := StrLower(t)
        if (gameIconState.Has(key) || GameIconIsCurrent(key))
            continue
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

StartBulkIconPreload(titles) {
    global gameIconBulkList, gameIconBulkPos, gameIconBulkStartAt, gdiplusToken, rowIconsEnabled
    if (!gdiplusToken || !rowIconsEnabled || !IsObject(titles) || titles.Length = 0)
        return
    gameIconBulkList := titles
    gameIconBulkPos := 1
    gameIconBulkStartAt := A_TickCount + 600
    SetTimer(GameIconTick, 20)
}

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
            continue
        gameIconState[key] := 1
        return t
    }
    gameIconBulkList := ""
    return ""
}

GameIconRequeue(job) {
    global gameIconPrefetch, gameIconRetryAt, gameIconMaxJobs
    gameIconMaxJobs := Max(10, gameIconMaxJobs - 6)
    wait := 0.0
    try wait := Number(job.xhr.getResponseHeader("Retry-After"))
    gameIconRetryAt := A_TickCount + Max(1500, Round(wait * 1000) + 250)
    gameIconPrefetch.InsertAt(1, job.title)
}

GameIconNetworkTune() {
    v := Buffer(4, 0)
    NumPut("UInt", 32, v, 0)
    try DllCall("wininet\InternetSetOptionW", "Ptr", 0, "UInt", 73, "Ptr", v.Ptr, "UInt", 4, "Int")
    try DllCall("wininet\InternetSetOptionW", "Ptr", 0, "UInt", 74, "Ptr", v.Ptr, "UInt", 4, "Int")
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

GameIconFail(job, definitive := false) {
    global gameIconState, gameIconBitmaps, gameIconArrived
    if (gameIconBitmaps.Has(job.key)) {
        GameIconForgetState(job.key)
        return
    }
    gameIconState[job.key] := 3
    if (definitive)
        GameIconNoIconSet(job.key, job.hash)
    gameIconArrived.Push(job.key)
}

GameIconBegin(job) {
    return (job.appId != "" && GameIconStartRequest(job, job.hash != "" ? "img" : "meta"))
}

GameIconTick(*) {
    global gameIconQueue, gameIconPrefetch, gameIconJobs, gameIconHashes, gameAppIds, gameIconBitmaps, isExiting, gameIconArrived
    global gameIconBulkList, gameIconRetryAt, isWindowMoving, animationActive
    global gameIconUpdateTried, gameIconState, gameIconMaxJobs
    if (isExiting) {
        SetTimer(GameIconTick, 0)
        return
    }
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
        else if (gameIconJobs.Length < maxJobs - 6)
            title := NextBulkIconTitle()
        if (title = "")
            break
        key := StrLower(title)
        hadOld := gameIconBitmaps.Has(key)
        if (!hadOld && TryLoadIconFromDisk(key)) {
            hadOld := true
            gameIconArrived.Push(key)
        }
        if (hadOld && !GameIconNeedsUpdate(key)) {
            GameIconForgetState(key)
            continue
        }
        if (hadOld)
            gameIconState[key] := 1
        gameIconUpdateTried[key] := true
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
    try UpdateSearchIcon(forceSearch)
    for key in keys {
        try RiskIconRefresh(key)
    }
}

RepaintArrivedRows(keys) {
    global selectorList, selectorDisplayedOptions, selectorRowHeight, selectorListFrozen
    if (!IsWindowValid(selectorList) || selectorDisplayedOptions.Length = 0)
        return
    want := Map()
    for k in keys
        want[k] := true
    top := SendMessage(0x018E, 0, 0, selectorList.Hwnd)
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
        if (SendMessage(0x0198, idx, rc.Ptr, selectorList.Hwnd) = -1)
            continue
        DllCall("User32\InvalidateRect", "Ptr", selectorList.Hwnd, "Ptr", rc, "Int", false)
        hit := true
    }
    if (hit && !selectorListFrozen)
        DllCall("User32\UpdateWindow", "Ptr", selectorList.Hwnd)
}

GameIconJobDone(job) {
    global gameIconHashes, gameIconArrived
    stage := job.stage
    status := job.xhr.status
    if (status = 429) {
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
        return GameIconDiscordFailed(job, !hasIcon)
    }
    arr := job.xhr.responseBody
    size := arr.MaxIndex() + 1
    pData := NumGet(ComObjValue(arr), 8 + A_PtrSize, "Ptr")
    master := GameIconBuildMaster(pData, size)
    if (!master)
        return GameIconDiscordFailed(job)
    GameIconCacheStore(job.key, master)
    gameIconArrived.Push(job.key)
    GameIconSaveMaster(job.key, master, job.hash)
    return true
}

GameIconDiscordFailed(job, definitive := false) {
    GameIconFail(job, definitive)
    return true
}

GameIconBuildMaster(pData, size, isMaster := false) {
    global gdiplusToken, gameIconMasterPx
    if (!gdiplusToken || size < 16)
        return 0
    stream := DllCall("shlwapi\SHCreateMemStream", "Ptr", pData, "UInt", size, "Ptr")
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
            throw Error("size")
        if (isMaster && sw = M && sh = M) {
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
        sc := M / Min(sw, sh)
        dw := sw * sc, dh := sh * sc
        dx0 := (M - dw) / 2, dy0 := (M - dh) / 2
        if (DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", M, "Int", M, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &tmp, "Int") != 0 || !tmp)
            throw Error("bitmap")
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", tmp, "Ptr*", &g1, "Int")
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", g1, "UInt", 0x00000000, "Int")
        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", g1, "Int", 7, "Int")
        DllCall("gdiplus\GdipSetCompositingQuality", "Ptr", g1, "Int", 2, "Int")
        DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", g1, "Int", 2, "Int")
        DllCall("gdiplus\GdipCreateImageAttributes", "Ptr*", &ia, "Int")
        if (ia)
            DllCall("gdiplus\GdipSetImageAttributesWrapMode", "Ptr", ia, "Int", 3, "UInt", 0, "Int", 0, "Int")
        DllCall("gdiplus\GdipDrawImageRectRect", "Ptr", g1, "Ptr", src
            , "Float", dx0, "Float", dy0, "Float", dw, "Float", dh
            , "Float", 0.0, "Float", 0.0, "Float", sw + 0.0, "Float", sh + 0.0
            , "Int", 2, "Ptr", ia, "Ptr", 0, "Ptr", 0, "Int")
        if (DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", M, "Int", M, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &dst, "Int") != 0 || !dst)
            throw Error("bitmap")
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", dst, "Ptr*", &g2, "Int")
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g2, "Int", 4, "Int")
        if (DllCall("gdiplus\GdipCreateTexture", "Ptr", tmp, "Int", 4, "Ptr*", &brush, "Int") != 0 || !brush)
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
        DllCall("gdiplus\GdipDisposeImage", "Ptr", src, "Int")
    ObjRelease(stream)
    if (!ok) {
        if (dst)
            DllCall("gdiplus\GdipDisposeImage", "Ptr", dst, "Int")
        return 0
    }
    return dst
}

SearchIconPx() {
    global searchIconSize
    return searchIconSize
}

SearchIconGap() {
    global searchIconTextGap
    return searchIconTextGap
}

SearchLeftInset() {
    global searchTextLeftInset
    return searchTextLeftInset
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

UpdateSearchIcon(force := false) {
    global processSelect, searchIconCtl, searchIconKey, searchIconReal, searchIconOff
    global isShowingGameSearchHint, rowIconsEnabled, gdiplusToken, isExiting
    if (isExiting || !IsWindowValid(processSelect) || !IsWindowValid(searchIconCtl))
        return
    key := ""
    if (rowIconsEnabled && gdiplusToken && !isShowingGameSearchHint) {
        matched := ResolveTypedGameTitle()
        if (matched != "")
            key := StrLower(matched)
    }
    if (key = "") {
        if (searchIconKey != "" || searchIconOff != 0)
            HideSearchIcon()
        return
    }
    master := GetGameIconBitmap(key)
    real := master ? 1 : (GameIconIsMissing(key) ? 2 : 0)
    if (!force && key = searchIconKey && real = searchIconReal && searchIconOff > 0)
        return
    px := SearchIconPx()
    hbm := MakeIconHBitmap(master, px, real = 2)
    if (!hbm)
        return
    inset := SearchLeftInset()
    PositionSearchIconAt(inset, px)
    old := SendMessage(0x0172, 0, hbm, searchIconCtl.Hwnd)
    if (old)
        DllCall("Gdi32\DeleteObject", "Ptr", old)
    searchIconKey := key, searchIconReal := real
    searchIconCtl.Opt("-Hidden")
    newOff := px + SearchIconGap()
    if (newOff != searchIconOff) {
        searchIconOff := newOff
        SetSearchEditMargins(inset)
    }
    DllCall("User32\SetWindowPos", "Ptr", searchIconCtl.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")
    DllCall("User32\RedrawWindow", "Ptr", searchIconCtl.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0101, "Int")
}

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

IsGameSearchControlFocused() {
    global isGameSearchFocused, isExiting
    return (IsSet(isExiting) && IsSet(isGameSearchFocused) && !isExiting && isGameSearchFocused)
}

; On every (re)load: the longest fetched game title sets the search box's max input (its character count).
; EM_LIMITTEXT does not touch text set with .Value (hint text, picked titles).
ApplySearchMaxLen() {
    global processSelect, processOptions
    if (!IsWindowValid(processSelect) || !IsObject(processOptions) || processOptions.Length = 0)
        return
    longest := 0
    for title in processOptions {
        n := StrLen(title)
        if (n > longest)
            longest := n
    }
    if (longest > 0)
        SendMessage(0x00C5, longest, 0, processSelect.Hwnd)
}

EnsureGameSearchFocus(*) {
    global processSelect, isExiting
    if (!IsSet(isExiting) || isExiting || !IsWindowValid(processSelect))
        return
    DllCall("User32\SetFocus", "Ptr", processSelect.Hwnd)
}

; Keyboard (Tab / Shift+Tab) entry into the search box: focus it and put the caret at the END of the
; existing text, scrolled into view, so typing continues from the right instead of the left.
FocusGameSearchFromKeyboard() {
    global processSelect, isExiting, isShowingGameSearchHint
    if (!IsSet(isExiting) || isExiting || !IsWindowValid(processSelect))
        return
    DllCall("User32\SetFocus", "Ptr", processSelect.Hwnd)
    if (isShowingGameSearchHint)
        return
    len := StrLen(processSelect.Value)
    SendMessage(0x00B1, len, len, processSelect.Hwnd)
    SendMessage(0x00B7, 0, 0, processSelect.Hwnd)
}

; Search box anti-flicker. A stock Edit paints in two visible steps on every key: WM_ERASEBKGND wipes the line to black,
; then WM_PAINT draws the text. When keys arrive faster than the screen refresh, a frame can be presented between
; the two steps = the text blinks. This subclass skips the erase and renders the whole edit into an off-screen bitmap
; (via WM_PRINTCLIENT), then copies it to the screen in a single blit, so only complete frames are ever visible.
SubclassSearchEditDoubleBuffer() {
    global processSelect, searchEditSubCb
    if (!IsWindowValid(processSelect))
        return
    searchEditSubCb := CallbackCreate(SearchEditSubProc, , 6)
    DllCall("Comctl32\SetWindowSubclass", "Ptr", processSelect.Hwnd, "Ptr", searchEditSubCb, "UPtr", 1, "UPtr", 0, "Int")
}

SearchEditSubProc(hWnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) {
    if (uMsg = 0x0014)
        return 1
    if (uMsg = 0x000F) {
        ps := Buffer(A_PtrSize = 8 ? 72 : 64, 0)
        hdc := DllCall("User32\BeginPaint", "Ptr", hWnd, "Ptr", ps, "Ptr")
        if (!hdc)
            return 0
        rc := Buffer(16, 0)
        DllCall("User32\GetClientRect", "Ptr", hWnd, "Ptr", rc)
        w := NumGet(rc, 8, "Int"), h := NumGet(rc, 12, "Int")
        if (w > 0 && h > 0) {
            mem := DllCall("Gdi32\CreateCompatibleDC", "Ptr", hdc, "Ptr")
            bmp := mem ? DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", hdc, "Int", w, "Int", h, "Ptr") : 0
            if (mem && bmp) {
                old := DllCall("Gdi32\SelectObject", "Ptr", mem, "Ptr", bmp, "Ptr")
                DllCall("User32\FillRect", "Ptr", mem, "Ptr", rc, "Ptr", DllCall("Gdi32\GetStockObject", "Int", 4, "Ptr"))
                DllCall("User32\SendMessageW", "Ptr", hWnd, "UInt", 0x0318, "Ptr", mem, "Ptr", 0x4, "Ptr")
                DllCall("Gdi32\BitBlt", "Ptr", hdc, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", mem, "Int", 0, "Int", 0, "UInt", 0x00CC0020, "Int")
                DllCall("Gdi32\SelectObject", "Ptr", mem, "Ptr", old, "Ptr")
            }
            if (bmp)
                DllCall("Gdi32\DeleteObject", "Ptr", bmp)
            if (mem)
                DllCall("Gdi32\DeleteDC", "Ptr", mem)
        }
        DllCall("User32\EndPaint", "Ptr", hWnd, "Ptr", ps)
        return 0
    }
    return DllCall("Comctl32\DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
}

PaintSearchFrameDirect() {
    global frameGui, selectGui, isExiting, isWindowVisible
    if (isExiting || !isWindowVisible || !IsObject(frameGui) || !IsWindowValid(frameGui))
        return
    if (!DllCall("User32\IsWindowVisible", "Ptr", frameGui.Hwnd, "Int"))
        return
    hdc := DllCall("User32\GetDC", "Ptr", frameGui.Hwnd, "Ptr")
    if (!hdc)
        return
    ; frameGui has no WS_CLIPSIBLINGS, so a plain FillRect on its DC can paint straight over the black search box
    ; (selectGui + the edit) that sits on top of it. This runs from HeaderGuardTick every second, so keep the white
    ; fill out of the box: exclude its rectangle and only touch the frame's own 1px outline.
    if (IsObject(selectGui) && IsWindowValid(selectGui)) {
        fr := Buffer(16, 0), sr := Buffer(16, 0)
        if (DllCall("User32\GetWindowRect", "Ptr", frameGui.Hwnd, "Ptr", fr, "Int")
            && DllCall("User32\GetWindowRect", "Ptr", selectGui.Hwnd, "Ptr", sr, "Int")) {
            fx := NumGet(fr, 0, "Int"), fy := NumGet(fr, 4, "Int")
            DllCall("Gdi32\ExcludeClipRect", "Ptr", hdc
                , "Int", NumGet(sr, 0, "Int") - fx, "Int", NumGet(sr, 4, "Int") - fy
                , "Int", NumGet(sr, 8, "Int") - fx, "Int", NumGet(sr, 12, "Int") - fy, "Int")
        }
    }
    FillWhite(hdc, frameGui.Hwnd)
    DllCall("User32\ReleaseDC", "Ptr", frameGui.Hwnd, "Ptr", hdc)
}

; A rapid second click on the Start/Stop button is delivered as WM_LBUTTONDBLCLK instead of WM_LBUTTONDOWN.
; Without this it was swallowed, so spamming Start/Stop silently lost every other click.
HandleActionDoubleClick(wParam, lParam, msg, hwnd) {
    global actionGui, actionBtn, isExiting, exitDlgActive
    if (isExiting || exitDlgActive || !IsWindowValid(actionBtn))
        return
    if (hwnd != actionBtn.Hwnd && !(IsWindowValid(actionGui) && hwnd = actionGui.Hwnd))
        return
    HandleLeftButtonDown(wParam, lParam, 0x0201, hwnd)
}

OnSearchBoxDoubleClick(wParam, lParam, msg, hwnd) {
    global processSelect, isExiting, exitDlgActive
    if (exitDlgActive)
        return 0
    if (!IsSet(isExiting) || isExiting || !IsWindowValid(processSelect) || hwnd != processSelect.Hwnd)
        return
    SendMessage(0x00B1, 0, -1, processSelect.Hwnd)
    return 0
}

SetSearchEditMargins(inset) {
    global processSelect
    global searchIconOff
    SendMessage(0x00D3, 0x0003, inset + searchIconOff, processSelect.Hwnd)
}

OnGameSearchFocus(*) {
    global processSelect, isShowingGameSearchHint, isGameSearchFocused, processOptions, gameFetchPending, gameSearchHint, isFilteringGameList
    isGameSearchFocused := true
    if (isShowingGameSearchHint && processSelect.Value != gameSearchHint)
        TakeOverTypingFromHint()
    if (isShowingGameSearchHint) {
        isFilteringGameList := true
        SearchEditRedraw(false)
        try {
            processSelect.Value := ""
        } finally {
            SearchEditRedraw(true)
        }
        isFilteringGameList := false
        isShowingGameSearchHint := false
    }
    UpdateSearchIcon()
    if (processOptions.Length = 0 && gameFetchPending) {
    } else if (processOptions.Length = 0)
        SetStatusIfChanged("No game titles loaded. Press ↻ to load them.", "stopped")
}

OnGameSearchLoseFocus(*) {
    global processSelect, selectedProcessTitle, isShowingGameSearchHint, isFilteringGameList, gameSearchHint, isGameSearchFocused, appIsInactive
    if ((GetKeyState("LButton", "P") || GetKeyState("RButton", "P")) && (IsMouseOverScrollArrowButton() || IsMouseOverDropdownArea())) {
        SetTimer(EnsureGameSearchFocus, -1)
        return
    }
    isGameSearchFocused := false
    if (appIsInactive || !IsForegroundOurProcess())
        return
    RevertSearchStatus()
    if (processSelect.Value = "" && selectedProcessTitle = "") {
        isFilteringGameList := true
        SearchEditRedraw(false)
        try {
            processSelect.Value := gameSearchHint
        } finally {
            SearchEditRedraw(true)
        }
        isFilteringGameList := false
        isShowingGameSearchHint := true
    }
    UpdateSearchIcon()
}

TakeOverTypingFromHint() {
    global processSelect, isShowingGameSearchHint, isFilteringGameList, gameSearchHint
    if (!isShowingGameSearchHint || !IsWindowValid(processSelect))
        return
    v := processSelect.Value
    if (v = gameSearchHint)
        return
    typed := InStr(v, gameSearchHint) ? StrReplace(v, gameSearchHint, "", false, , 1) : v
    wasFiltering := isFilteringGameList
    isFilteringGameList := true
    ; hint text + first typed character -> only the typed character: do it with painting frozen so the
    ; intermediate "hint+char" text (and the empty state) is never put on screen. One repaint at the end.
    SearchEditRedraw(false)
    try {
        processSelect.Value := typed
        SendMessage(0x00B1, StrLen(typed), StrLen(typed), processSelect.Hwnd)
    } finally {
        SearchEditRedraw(true)
    }
    isFilteringGameList := wasFiltering
    isShowingGameSearchHint := false
}

; Freeze/unfreeze painting of the search edit around a multi-step text change (WM_SETTEXT, EM_SETSEL ...).
; Unfreezing repaints once; the edit's subclass paints double-buffered, so that single repaint is flicker-free.
SearchEditRedraw(on) {
    global processSelect, searchEditHold
    if (!IsWindowValid(processSelect))
        return
    h := processSelect.Hwnd
    if (!on) {
        DllCall("User32\SendMessageW", "Ptr", h, "UInt", 0x000B, "Ptr", 0, "Ptr", 0, "Ptr")
        return
    }
    DllCall("User32\SendMessageW", "Ptr", h, "UInt", 0x000B, "Ptr", 1, "Ptr", 0, "Ptr")
    if (searchEditHold)
        DllCall("User32\InvalidateRect", "Ptr", h, "Ptr", 0, "Int", false)
    else
        DllCall("User32\RedrawWindow", "Ptr", h, "Ptr", 0, "Ptr", 0, "UInt", 0x0101)
}

OnGameSearchChange(*) {
    global isFilteringGameList, isSelectingGame, selectedProcessTitle, processSelect
    global gsApplying, gsDirty, gsApplyDelayMs
    if (!isFilteringGameList)
        TakeOverTypingFromHint()
    ; Was RedrawWindow(...INVALIDATE|UPDATENOW): a forced synchronous repaint on every key, right after the
    ; edit already painted itself = flicker when typing fast. Just mark it dirty; Windows paints once.
    if (IsWindowValid(processSelect))
        DllCall("User32\InvalidateRect", "Ptr", processSelect.Hwnd, "Ptr", 0, "Int", false)
    if (isFilteringGameList) {
        ; isFilteringGameList is also true while our own filter runs. A key typed in that window used to be dropped
        ; here, leaving the list one keystroke behind the text. Remember it and re-run when the filter is done.
        if (gsApplying) {
            gsDirty := true
            return
        }
        ; A programmatic change (item picked, hint restored) supersedes typing that is still waiting.
        SetTimer(ApplyGameSearchChange, 0)
        UpdateSearchIcon()
        return
    }
    if (!isSelectingGame)
        selectedProcessTitle := ""
    ; Typing only records the change. The heavy work (filter, dropdown resize, status) runs once the key backlog is
    ; drained, so a fast burst updates the dropdown for the text you ended up with, not once per intermediate key.
    SetTimer(ApplyGameSearchChange, -gsApplyDelayMs)
}

ApplyGameSearchChange(*) {
    global isExiting, processSelect, gsApplying, gsDirty, gsApplyDelayMs
    if (isExiting || !IsWindowValid(processSelect))
        return
    if (gsApplying) {
        gsDirty := true
        return
    }
    gsApplying := true
    try
        ApplyGameSearchChangeCore()
    finally
        gsApplying := false
    if (gsDirty) {
        gsDirty := false
        SetTimer(ApplyGameSearchChange, -gsApplyDelayMs)
    }
}

ApplyGameSearchChangeCore() {
    global processSelect, selectorFrameGui, processOptions, gameFetchPending, isShowingGameSearchHint
    UpdateSearchIcon()
    if (processOptions.Length = 0) {
        if (!gameFetchPending)
            SetStatusIfChanged("No game titles loaded. Press ↻ to load them.", "stopped")
        return
    }
    query := isShowingGameSearchHint ? "" : Trim(processSelect.Value)
    if (query != "" && GetFilteredTitles(query).Length = 0) {
        CloseSelectorKeepStatus()
        SetStatusIfChanged("No game titles match '" . ShortQuery(query) . "'.", "ready")
        return
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

; Titles that contain `query` (case-insensitive), in dropdown order: numeric-leading titles first (sorted), then the rest.
; Every keystroke used to rescan all ~25k titles several times (match check x3, filter, sort). Now the result is
; cached per query, and when the new query contains the previous one (typing forward) only the previous, much
; smaller result list is filtered. The returned array is shared; callers must not modify it.
GetFilteredTitles(query) {
    global processOptions, filterCacheQuery, filterCacheList, filterCacheSrc
    if (query = "")
        return []
    if (IsObject(filterCacheList) && IsObject(filterCacheSrc) && filterCacheQuery != ""
        && ObjPtr(filterCacheSrc) = ObjPtr(processOptions)) {
        if (query = filterCacheQuery)
            return filterCacheList
        if (InStr(query, filterCacheQuery)) {
            narrowed := []
            for title in filterCacheList {
                if (InStr(title, query, false))
                    narrowed.Push(title)
            }
            filterCacheQuery := query, filterCacheList := narrowed
            return narrowed
        }
    }
    numericRaw := "", alphaTitles := []
    for title in processOptions {
        if (!InStr(title, query, false))
            continue
        if (RegExMatch(SubStr(title, 1, 1), "[0-9]"))
            numericRaw .= title . "`n"
        else
            alphaTitles.Push(title)
    }
    result := []
    if (numericRaw != "") {
        for title in StrSplit(Sort(RTrim(numericRaw, "`n"), "C0"), "`n")
            result.Push(title)
    }
    for title in alphaTitles
        result.Push(title)
    filterCacheQuery := query, filterCacheList := result, filterCacheSrc := processOptions
    return result
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
        SetStatus("Unable to load game titles: A required Windows component is missing. Update Windows and try again.", "error")
        return false
    }
    try {
        asyncXhr.Open("GET", "https://discord.com/api/v10/applications/detectable", true)
        asyncXhr.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        asyncXhr.Send()
        gameFetchPending := true
        gameFetchStartedAt := A_TickCount
        SetStatus("Loading game titles from Discord…", "running")
        SetTimer(CheckDiscordGameLoad, 50)
        return true
    } catch Error as err {
        asyncXhr := ""
        if (!IsInternetAvailable())
            SetInternetLostStatus()
        else
            SetStatus("Couldn't load game titles. Check your connection and try again.", "error")
        return false
    }
}

CheckDiscordGameLoad(*) {
    global processOptions, gameFetchPending, gameFetchStartedAt, asyncXhr, suppressFilterStatus
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
                    SetStatus("Loading game titles timed out. Check your connection and try again.", "error")
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
                SetStatus("Couldn't load game titles: Discord returned error " status ". Try again later.", "error")
            return
        }
        responseText := asyncXhr.responseText
        if (responseText = "") {
            FinishDiscordGameLoad()
            SetStatus("Discord returned an empty response. Try again in a moment.", "error")
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
        ApplySearchMaxLen()
        FinishDiscordGameLoad()
        if (processOptions.Length = 0) {
            SetStatus("Discord returned no game titles. Try again in a moment.", "error")
            return
        }
        ; The final status is set by OpenDropdownAfterLoad so "Loaded N game titles." never flashes before another message.
        GameIconIndexEnsure()
        PrefetchGameIcons(processOptions, 80)
        StartBulkIconPreload(processOptions)
        UpdateSearchIcon()
        SetTimer(OpenDropdownAfterLoad, -40)
    } catch Error as err {
        suppressFilterStatus := false
        FinishDiscordGameLoad()
        if (!IsInternetAvailable())
            SetInternetLostStatus()
        else
            SetStatus("Couldn't load game titles. Check your connection and try again.", "error")
    }
}

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

FinishDiscordGameLoad() {
    global gameFetchPending, asyncXhr
    StopRefreshArrowAnimation()
    gameFetchPending := false
    asyncXhr := ""
    SetTimer(CheckDiscordGameLoad, 0)
}

ParseDiscordGameTitles(json) {
    global gameExecutables, gameAppIds, gameIconHashes, gameIconState, gameExeArgs
    gameExecutables := Map()
    gameExeArgs := Map()
    gameAppIds := Map()
    gameIconHashes := Map()
    failedIcons := []
    for k, v in gameIconState
        if (v = 3)
            failedIcons.Push(k)
    for k in failedIcons
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
            if (InStr(segment, '"icon') && RegExMatch(segment, 's)^.*"icon(?:_hash)?"\s*:\s*"([A-Za-z0-9_]+)"', &iconMatch))
                gameIconHashes[key] := iconMatch[1]
            exePath := PickDetectableExecutable(segment, title)
            if (exePath != "")
                gameExecutables[key] := exePath
        }
        position := matchPosition + StrLen(match[0])
        segmentStart := position
    }
    GameIconRefreshCycle()
    return titles
}

PickDetectableExecutable(segment, title := "") {
    global gameExeArgs
    if (!RegExMatch(segment, '"executables"\s*:\s*\[([^\]]*)\]', &arr))
        return ""
    body := arr[1]
    bestGame := "", bestGameScore := -999999, bestGameArgs := ""
    bestLauncher := "", bestLauncherScore := -999999, bestLauncherArgs := ""
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
        score -= index * 0.01
        ; Discord also requires the command line to contain "arguments" when an entry has them
        entryArgs := ""
        if (RegExMatch(entry, '"arguments"\s*:\s*"((?:\\.|[^"\\])*)"', &am)) {
            argPos := 1
            entryArgs := Trim(ReadJsonString('"' am[1] '"', &argPos))
        }
        ; prefer entries that match by file name alone: fewer things that can fail
        if (entryArgs != "")
            score -= 50
        if (InStr(rel, "\"))
            score -= 20
        if (isLauncher) {
            if (score > bestLauncherScore) {
                bestLauncherScore := score
                bestLauncher := rel
                bestLauncherArgs := entryArgs
            }
        } else if (score > bestGameScore) {
            bestGameScore := score
            bestGame := rel
            bestGameArgs := entryArgs
        }
    }
    chosen := bestGame != "" ? bestGame : bestLauncher
    chosenArgs := bestGame != "" ? bestGameArgs : bestLauncherArgs
    if (chosen != "" && title != "")
        gameExeArgs[StrLower(title)] := [chosen, chosenArgs]
    return chosen
}

ScoreExecutableCandidate(rel, title, isExact := false) {
    SplitPath(rel, &fileName, , , &baseName)
    exeKey := NormalizeForExeMatch(baseName)
    titleKey := NormalizeForExeMatch(title)
    lowerBase := StrLower(baseName)
    score := 0
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
    if (RegExMatch(lowerBase, "-win64-shipping$"))
        score += 45
    else if (RegExMatch(lowerBase, "-win(32|gdk|64)?-shipping$|shipping$"))
        score += 20
    if (RegExMatch(lowerBase, "(64|x64|_64|win64)$"))
        score += 15
    else if (RegExMatch(lowerBase, "(x86|_32|win32|32)$"))
        score -= 15
    junkWords := ["unins", "setup", "install", "crash", "report", "helper", "updat", "patch", "redist", "bootstrap"
        , "anticheat", "battleye", "webhelper", "subprocess", "diagnos", "benchmark", "editor", "dedicated", "server"
        , "sentry", "notification", "launcher", "config", "settings", "vcredist", "dxsetup", "cleanup", "migrat"]
    for junk in junkWords {
        if (InStr(exeKey, junk) && !InStr(titleKey, junk)) {
            score -= 150
            break
        }
    }
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
    if (SubStr(name, 1, 1) = ">")
        name := SubStr(name, 2)
    name := StrReplace(name, "/", "\")
    parts := []
    for part in StrSplit(name, "\") {
        part := Trim(RegExReplace(part, '[<>:"|?*]', "_"))
        if (part = "" || part = "." || part = "..")
            continue
        ; Keep these Discord path components out of the generated process folder tree.
        if (StrLower(part) = "menu" || StrLower(part) = "dialog" || StrLower(part) = "accelerators" || StrLower(part) = "manifest" || StrLower(part) = "mainfiest")
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
    global selectorClickIndex, selectorUpdating, dropdownMarqueeIndex
    if (!IsWindowValid(processSelect) || !IsWindowValid(selectorList))
        return
    global emptyQueryTitles, emptyQuerySource
    global showAllMsg, showAllPrevText, showAllPrevType, currentStatusTextOnly, currentStatusColor
    selectorClickIndex := -1
    query := isShowingGameSearchHint ? "" : Trim(processSelect.Value)
    ; One cached lookup replaces the old "any match?" scan plus the full filter/sort pass (see GetFilteredTitles).
    if (query != "" && GetFilteredTitles(query).Length = 0) {
        CloseSelectorKeepStatus()
        SetStatusIfChanged("No game titles match '" . ShortQuery(query) . "'.", "ready")
        return
    }
    shownCount := 0
    try {
        if (query != "") {
            combinedTitles := GetFilteredTitles(query)
        } else if (IsObject(emptyQueryTitles) && IsObject(emptyQuerySource) && ObjPtr(emptyQuerySource) = ObjPtr(processOptions)) {
            combinedTitles := emptyQueryTitles
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
        shownCount := combinedTitles.Length
        PrefetchGameIcons(combinedTitles, 15)
    } catch {
        return
    }
    frameWasVisible := IsWindowValid(selectorFrameGui)
        && DllCall("User32\IsWindowVisible", "Ptr", selectorFrameGui.Hwnd, "Int")
    selectorUpdating := true
    isFilteringGameList := true
    DropdownPaintLock(true)
    SendMessage(0x000B, 0, 0, selectorList.Hwnd)
    try {
        selectorDisplayedOptions := combinedTitles
        dropdownMarqueeIndex := -1
        SendMessage(0x184, 0, 0, selectorList.Hwnd)
        SendMessage(0x01A7, shownCount, 0, selectorList.Hwnd)
        if (shownCount > 0 && frameWasVisible)
            ResizeProcessSelector()
        HoverBestMatchForQuery(false)
        if (selectorDisplayedOptions.Length > 3)
            UpdateScrollThumbPosition()
        UpdateRowSeparators()
    } finally {
        SendMessage(0x000B, 1, 0, selectorList.Hwnd)
        isFilteringGameList := false
        selectorUpdating := false
        DropdownPaintLock(false)
        DllCall("User32\RedrawWindow", "Ptr", selectorList.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0181)
    }
    if (processOptions.Length = 0 && gameFetchPending) {
        SetStatusIfChanged("Loading game titles from Discord…", "running")
    } else if (shownCount = 0) {
        CloseSelectorKeepStatus()
        if (query != "")
            SetStatusIfChanged("No game titles match '" . ShortQuery(query) . "'.", "ready")
        else
            SetStatusIfChanged("No game titles are available. Press ↻ to try again.", "stopped")
        return
    } else if (suppressFilterStatus) {
    } else if (query != "")
        SetStatus(shownCount = 1 ? "1 game title matches '" . ShortQuery(query) . "'." : shownCount . " game titles match '" . ShortQuery(query) . "'.", "ready")
    else {
        SetStatus(Format("Showing all {} game titles.", processOptions.Length), "ready")
    }
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
    leftTextInset := searchTextLeftInset
    SetSearchEditMargins(leftTextInset)
    UpdateSearchIcon(true)
    SendMessage(0x00B1, 0, 0, processSelect.Hwnd)
    SendMessage(0x00B7, 0, 0, processSelect.Hwnd)
    isFilteringGameList := false
    CloseProcessSelector()
    if (IsWindowValid(selectorFrameGui))
        selectorFrameGui.Hide()
    isSelectingGame := true
    DllCall("User32\SetFocus", "Ptr", mainGui.Hwnd)
    isSelectingGame := false
    SetStatus("Selected: '" selectedTitle "'. Press Start to begin.", "ready")
}

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

IsTosIconHwnd(h) {
    global riskTosGui, riskTosCtl
    return IsWindowValid(riskTosGui) && IsWindowValid(riskTosCtl) && h && (h = riskTosGui.Hwnd || h = riskTosCtl.Hwnd)
}

TosIconDown() {
    global pressedControl, tosIconPressed
    pressedControl := "tos"
    tosIconPressed := true
    PaintTosDirect()
}

TosIconUp(hoveredControl) {
    global tosIconPressed, tosPageUrl
    tosIconPressed := false
    if (IsTosIconHwnd(hoveredControl))
        try Run(tosPageUrl)
    PaintTosDirect()
}

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
    itemHwndOffset := (A_PtrSize = 8) ? 24 : 20
    fake := Buffer(itemHwndOffset + A_PtrSize * 2 + 16 + A_PtrSize, 0)
    NumPut("Ptr", hdc, fake, itemHwndOffset + A_PtrSize)
    rectOffset := itemHwndOffset + A_PtrSize * 2
    NumPut("Int", 0, "Int", 0, "Int", NumGet(rc, 8, "Int"), "Int", NumGet(rc, 12, "Int"), fake, rectOffset)
    DrawRiskTosIcon(fake)
    DllCall("User32\ReleaseDC", "Ptr", riskTosCtl.Hwnd, "Ptr", hdc)
}

TosHoverValue() {
    global tosHoverFrom, tosHoverTo, tosHoverStartedAt, tosHoverDuration
    p := Min(1.0, (A_TickCount - tosHoverStartedAt) / tosHoverDuration)
    return tosHoverFrom + (tosHoverTo - tosHoverFrom) * (p * p * (3 - 2 * p))
}

TosHoverPoll() {
    global tosHoverFrom, tosHoverTo, tosHoverStartedAt, tosIconPressed
    if (tosIconPressed)
        return
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
    global tosHoverStartedAt, tosHoverDuration, tosRippleStart, tosRippleDuration
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

FreeRiskIcon() {
    global riskIconCtl, riskIconHbm, riskIconKey, riskIconReal
    riskIconCtl := ""
    riskIconKey := "", riskIconReal := false
    if (riskIconHbm) {
        DllCall("Gdi32\DeleteObject", "Ptr", riskIconHbm)
        riskIconHbm := 0
    }
}

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

MakeRiskButton(name, parentGui, label, x, y, w, h, fontSize, normal, hover, pressed, radius, pressScale, pressMs) {
    global riskBtnRegistry
    g := Gui("-Caption +0x40000000", "")
    g.Opt("+Parent" parentGui.Hwnd)
    g.BackColor := normal
    ctl := g.Add("Text", Format("x0 y0 w{} h{} -Theme +0x100", w, h), label)
    ctl.SetFont("s" Round(fontSize) " Bold", "Segoe UI")
    ctl.Opt("+0x000D")
    obj := {name: name, gui: g, ctl: ctl, Hwnd: g.Hwnd, label: label, fontSize: fontSize, baseFont: fontSize
        , color: normal, normal: normal, hover: hover, pressed: pressed, x: x, y: y, w: w, h: h, scale: 1.0
        , radius: radius, pressScale: pressScale, pressMs: pressMs}
    riskBtnRegistry[ctl.Hwnd] := obj
    g.Show(Format("NA x{} y{} w{} h{}", x, y, w, h))
    ApplyRoundedCorners(g, radius)
    return obj
}

RiskButtonOwnerDraw(hwnd, itemHwnd, lParam) {
    global riskBtnAccept, riskBtnCancel, riskBtnRegistry
    if (riskBtnRegistry.Has(itemHwnd)) {
        rb := riskBtnRegistry[itemHwnd]
        if (hwnd = rb.gui.Hwnd)
            return DrawPillButton(lParam, rb.color, rb.label, rb.fontSize, rb.scale, rb.radius)
    }
    for b in [riskBtnAccept, riskBtnCancel] {
        if (IsObject(b) && IsWindowValid(b.gui) && hwnd = b.gui.Hwnd && itemHwnd = b.ctl.Hwnd)
            return DrawPillButton(lParam, b.color, b.label, b.fontSize, b.scale, b.radius)
    }
    return ""
}

SetRiskBtnColor(b, color, paint := true) {
    if (b.color = color)
        return
    b.color := color
    if (paint)
        RepaintRiskButtonNoErase(b)
}

RepaintRiskButtonNoErase(b) {
    if (!IsWindowValid(b.ctl))
        return
    if (PaintControlDirect(b.ctl, (ds) => DrawPillButton(ds, b.color, b.label, b.fontSize, b.scale, b.radius)))
        return
    DllCall("User32\InvalidateRect", "Ptr", b.ctl.Hwnd, "Ptr", 0, "Int", false)
    DllCall("User32\UpdateWindow", "Ptr", b.ctl.Hwnd)
}

AnimateRiskButton(b, pressed, onComplete := "") {
    global riskBtnAnimating, riskAnimTick
    global riskTitleActive, riskTitlePauseUntil
    riskBtnAnimating := true
    riskAnimTick := A_TickCount
    flagCleared := false
    try {
        scaleStart := b.scale
        scaleEnd := pressed ? b.pressScale : 1.0
        if (riskTitleActive && NowMs() >= riskTitlePauseUntil)
            ServiceMarqueesDuringAnimation()
        startTime := A_TickCount, duration := b.pressMs
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
        ResyncMarqueeClocks()
        riskBtnAnimating := false
        flagCleared := true
        if (!pressed && IsObject(onComplete))
            onComplete()
    } finally {
        if (!flagCleared)
            riskBtnAnimating := false
    }
}

EnsureRiskView(mainWidth, mainHeight) {
    global mainGui, riskGui, riskBtnAccept, riskBtnCancel, riskPendingName, riskPendingAppId, riskTosGui, riskTosCtl
    global riskTitleCtl, riskTitleActive, riskTitleText, riskTitleOffset, riskTitleOverflowW, riskTitleCycleW, riskTitleTrackW, riskTitleInset
    global riskTitleRenderedX, riskTitleFrames, riskTitleLastTick, riskTitlePauseUntil, riskTitleStripDirty, riskLineGui, riskLineCtl
    global riskTitleRenderedPhase
    global riskIconCtl, riskIconHbm, riskIconKey, riskIconReal, riskIconPx, rowIconsEnabled, gdiplusToken, riskIconTitleGap, riskIconSize, riskTitleSideInset
    global riskWarnSign, riskWarnBlinkStep, riskWarnBmps, riskWarnShown, dotBlinkStep, riskHandCtl, riskHandBmp
    global riskTitleVNudge
    global riskGapLineToTitle, riskGapTitleToId, riskGapIdToDesc, riskGapDescToWarn, riskGapWarnToButtons
    if (IsWindowValid(riskGui))
        return
    pTitle := StrReplace(riskPendingName, "&", "&&")
    pId := "ID: " riskPendingAppId
    p2 := "This game has no detectable executable in Discord's database, so the system will connect to Discord's local IPC using the game's application ID and send a SET_ACTIVITY request. Discord will then display the game as the current activity without requiring a running executable."
    p3 := "WARNING: This may Violate Discord's Platform Manipulation`nPolicy and could result in account suspension or termination.`nContinue at your own risk?"
    pad := 36, fullW := mainWidth - pad * 2
    btnW := riskAcceptBtnW, btnH := Max(riskAcceptBtnH, riskCancelBtnH), btnGap := 32
    titlePs := 16
    idPs := 12
    warnPs := 10
    riskTitleInset := riskTitleSideInset + Round(A_ScreenDPI / 96)
    titleX := riskTitleInset, titleW := mainWidth - 2 - riskTitleInset * 2
    displayName := riskPendingName
    titleTextW := MeasureTextWidth(displayName, titlePs, 700)
    if (titleTextW > 28000) {
        while (StrLen(displayName) > 4 && titleTextW > 28000) {
            displayName := SubStr(displayName, 1, Floor(StrLen(displayName) * 0.9))
            titleTextW := MeasureTextWidth(displayName "…", titlePs, 700)
        }
        displayName .= "…"
    }
    riskIconKey := (rowIconsEnabled && gdiplusToken) ? FindGameKey(riskPendingName, riskPendingAppId) : ""
    popIconPx := riskIconSize
    if (riskIconMatchCenterParity && riskIconKey != "" && MeasureInkSpan("H", titlePs, 700, 200, Round(FontEmPx(titlePs) * 3) + 8, &capTop0, &capBot0)) {
        if (Mod(popIconPx - (capBot0 - capTop0), 2) != 0)
            popIconPx -= 1
    }
    popIconOff := (riskIconKey != "") ? popIconPx + riskIconTitleGap : 0
    unitX := titleX, textCtlX := titleX
    if (popIconOff > 0) {
        titleInk := GetTextInk(displayName, "Segoe UI", titlePs, 700)
        titleInkW := titleTextW - titleInk["a"] - titleInk["c"]
        unitX := titleX + (titleW - (popIconOff + titleInkW)) // 2
        textCtlX := unitX + popIconOff - titleInk["a"]
    }
    titleMarquee := (titleTextW > titleW - popIconOff)
    if (titleMarquee)
        hTitleRaw := MeasureWrappedTextHeight("Ag", titleW, titlePs, 700)
    else
        hTitleRaw := MeasureWrappedTextHeight(pTitle, titleW, titlePs, 700)
    hTitle := hTitleRaw + 4
    hIdRaw := MeasureWrappedTextHeight(pId, fullW, idPs, 700)
    hId := hIdRaw + 4
    descX := 8, descW := mainWidth - descX * 2, descPs := 10
    descFace := "Segoe UI Semibold"
    Loop {
        descText := BalanceTextLines(p2, 4, descPs, &descWidest, 400, 0, descFace)
        if (descWidest <= descW - 2 || descPs <= 7)
            break
        descPs -= 0.5
    }
    h2Raw := MeasureWrappedTextHeight(descText, descW, descPs, 400, descFace)
    h2 := h2Raw + 4
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
    titleTopEm := 0.675
    RiskInkSpan(titlePs, 700, hTitleRaw, titleTopEm, 0.21, titleMarquee ? 2 : 0, &aTitle, &bTitle)
    capCenterRel := aTitle + 0.325 * FontEmPx(titlePs)
    if (MeasureInkSpan("H", titlePs, 700, 100, hTitleRaw + 8, &hTop, &hBot))
        capCenterRel := (titleMarquee ? 2 : 0) + (hTop + hBot) / 2
    if (popIconOff > 0) {
        aTitle := Min(aTitle, capCenterRel - popIconPx / 2)
        bTitle := Max(bTitle, capCenterRel + popIconPx / 2)
    }
    if (!MeasureInkSpan(pId, idPs, 700, fullW, hId + 8, &aId, &bId))
        RiskInkSpan(idPs, 700, hIdRaw, 0.71, 0.0, 0, &aId, &bId)
    if (!MeasureInkSpan(descText, descPs, 400, descW, h2 + 8, &a2, &b2, descFace))
        RiskInkSpan(descPs, 400, h2Raw, 0.76, 0.21, 0, &a2, &b2)
    if (!MeasureInkSpan(warnText, warnPs, 700, warnW, h3 + 8, &a3, &b3))
        RiskInkSpan(warnPs, 700, h3Raw, 0.76, 0.21, 0, &a3, &b3)
    spans := [[aTitle, bTitle], [aId, bId], [a2, b2], [a3, b3], [0, btnH - 1]]
    sumInk := 0
    for sp in spans
        sumInk += sp[2] - sp[1]
    topGap := 20
    titleIdGapUsed := 5
    gaps := [13, 13, 14]
    cursor := topGap
    ys := []
    for i, sp in spans {
        ys.Push(Round(cursor - sp[1]))
        cursor += (sp[2] - sp[1]) + (i = 1 ? titleIdGapUsed : (i <= 4 ? gaps[i - 1] : 0))
        cursor := Round(cursor)
    }
    if (popIconOff > 0 && Abs(aTitle - (capCenterRel - popIconPx / 2)) < 0.001)
        ys[1] += Round(topGap) - Round(ys[1] + capCenterRel - popIconPx / 2)
    ys[1] += Round(riskGapLineToTitle - 20)
    ys[2] += Round(riskGapTitleToId - 5)
    ys[3] += Round(riskGapIdToDesc - 13)
    ys[4] += Round(riskGapDescToWarn - 13)
    ys[5] += Round(riskGapWarnToButtons - 14)
    riskGui := Gui("-Caption -Border -E0x200 +0x40000000", "")
    riskGui.Opt("+Parent" mainGui.Hwnd)
    riskGui.BackColor := "000000"
    riskGui.MarginX := 0, riskGui.MarginY := 0
    RemoveNativeOutline(riskGui.Hwnd)
    if (titleMarquee) {
        riskTitleCtl := riskGui.Add("Text", Format("x{} y{} w{} h{} +0x000D", titleX + popIconOff, ys[1] + riskTitleVNudge, titleW - popIconOff, hTitle), "")
        riskTitleText := displayName
        riskTitleOverflowW := titleTextW - (titleW - popIconOff)
        riskTitleCycleW := riskTitleOverflowW + riskTitleInset * 2
        riskTitleTrackW := titleTextW
        riskTitleOffset := 0.0, riskTitleFrames := 0, riskTitleRenderedX := 0, riskTitleRenderedPhase := 0
        riskTitleLastTick := FrameStamp()
        riskTitlePauseUntil := NowMs() + MarqueePauseMs()
        riskTitleStripDirty := true
        riskTitleActive := true
        stripRefDc := DllCall("User32\GetDC", "Ptr", mainGui.Hwnd, "Ptr")
        if (stripRefDc) {
            BuildRiskTitleStrip(stripRefDc, hTitle)
            DllCall("User32\ReleaseDC", "Ptr", mainGui.Hwnd, "Ptr", stripRefDc)
        }
    } else {
        riskTitleActive := false
        riskTitleCtl := ""
        if (popIconOff > 0) {
            tTitle := riskGui.Add("Text", Format("x{} y{} w{} h{} Left Background000000 cFFFFFF", textCtlX, ys[1] + riskTitleVNudge, titleTextW + 6, hTitle), pTitle)
        } else {
            tTitle := riskGui.Add("Text", Format("x{} y{} w{} h{} Center Background000000 cFFFFFF", titleX, ys[1] + riskTitleVNudge, titleW, hTitle), pTitle)
        }
        tTitle.SetFont("s" titlePs " Bold", "Segoe UI")
    }
    if (popIconOff > 0) {
        iconX := titleMarquee ? titleX : unitX
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
    warnLines := StrSplit(warnText, "`n")
    t3 := riskGui.Add("Text", Format("x{} y{} w{} h{} Center +0x04000000 Background000000 cF2A900", warnX, ys[4], warnW, 2 * Round(h3Raw / 3) + 4), warnLines[1] "`n" warnLines[2])
    t3.SetFont("s" warnPs " Bold", "Segoe UI")
    firstLine := StrSplit(warnText, "`n")[1]
    line1W := MeasureTextWidth(firstLine, warnPs, 700)
    spaceW := MeasureTextWidth("a a", warnPs, 700) - MeasureTextWidth("aa", warnPs, 700)
    GetFontAscentH("Segoe UI", warnPs, 700, &ascText, &hText)
    capT := 0, capB := 0
    if (!MeasureInkSpan("WARNING", warnPs, 700, 240, Round(warnPs * 4), &capT, &capB)) {
        capB := ascText
        capT := ascText - Round(0.72 * warnPs * 96 / 72)
    }
    signH := (capB - capT) + 2
    signW := Round(signH * 1.15)
    signX := warnX + (warnW - line1W) // 2 - signW - spaceW
    signY := ys[4] + capT - 1
    FreeWarnBitmaps()
    riskWarnBmps := BuildWarnSignBitmaps(signW, signH)
    riskWarnBlinkStep := 0
    riskWarnSign := riskGui.Add("Text", Format("x{} y{} w{} h{} +0x000D +0x04000000", signX, signY, signW, signH), "")
    riskWarnShown := 0
    if (riskWarnBmps.Length) {
        startIdx := (dotBlinkStep > 0) ? Mod(dotBlinkStep - 1, riskWarnBmps.Length) + 1 : 1
        riskWarnBlinkStep := startIdx
        riskWarnShown := startIdx
    }
    DllCall("User32\SetWindowPos", "Ptr", riskWarnSign.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")
    handH := (capB - capT) + 2
    handW := Round(handH * 192 / 148)
    line3W := MeasureTextWidth(warnLines[3], warnPs, 700)
    lh := Round(h3Raw / 3)
    line3Y := ys[4] + 2 * lh
    startX := warnX + (warnW - (handW + spaceW + line3W)) // 2
    t3b := riskGui.Add("Text", Format("x{} y{} w{} h{} Left +0x04000000 Background000000 cF2A900", startX + handW + spaceW, line3Y, line3W + 8, lh + 4), warnLines[3])
    t3b.SetFont("s" warnPs " Bold", "Segoe UI")
    DllCall("User32\SetWindowPos", "Ptr", t3b.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")
    handX := startX
    handY := line3Y + capT - 1
    if (riskHandBmp)
        DllCall("Gdi32\DeleteObject", "Ptr", riskHandBmp)
    riskHandBmp := BuildHandBitmap(handW, handH)
    riskHandCtl := riskGui.Add("Text", Format("x{} y{} w{} h{} +0x000D +0x04000000", handX, handY, handW, handH), "")
    DllCall("User32\SetWindowPos", "Ptr", riskHandCtl.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")
    areaLeft := descX + (descW - descWidest) // 2
    freeW := descWidest - btnW * 2
    padG := freeW // 3, padR := freeW - padG * 3
    padOuter := padG + (padR = 2 ? 1 : 0)
    padMid := padG + (padR = 1 ? 1 : 0)
    btnGap := padMid
    riskBtnAccept := MakeRiskButton("accept", riskGui, "Continue", riskAcceptBtnX, ys[5] + riskAcceptBtnYAdjust, riskAcceptBtnW, riskAcceptBtnH, riskAcceptBtnFontSize, riskAcceptBtnNormal, riskAcceptBtnHover, riskAcceptBtnPressed, riskAcceptBtnRadius, riskAcceptBtnPressScale, riskAcceptBtnPressMs)
    riskBtnCancel := MakeRiskButton("cancel", riskGui, "Cancel", riskCancelBtnX, ys[5] + riskCancelBtnYAdjust, riskCancelBtnW, riskCancelBtnH, riskCancelBtnFontSize, riskCancelBtnNormal, riskCancelBtnHover, riskCancelBtnPressed, riskCancelBtnRadius, riskCancelBtnPressScale, riskCancelBtnPressMs)
    riskLineGui := Gui("-Caption -Border -E0x200 +0x40000000", "")
    riskLineGui.Opt("+Parent" mainGui.Hwnd)
    riskLineGui.BackColor := "000000"
    riskLineGui.MarginX := 0, riskLineGui.MarginY := 0
    riskLineCtl := riskLineGui.Add("Text", "x0 y0 w10 h3 +0x000D", "")
    RemoveNativeOutline(riskLineGui.Hwnd)
    riskTosGui := Gui("-Caption -Border -E0x200 +0x40000000", "")
    riskTosGui.Opt("+Parent" mainGui.Hwnd)
    riskTosGui.BackColor := "000000"
    riskTosGui.MarginX := 0, riskTosGui.MarginY := 0
    riskTosCtl := riskTosGui.Add("Text", "x0 y0 w58 h56 +0x000D", "")
    RemoveNativeOutline(riskTosGui.Hwnd)
}

RiskViewTopY() {
    global riskContentTopY
    return riskContentTopY
}

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

PositionRiskLine(mainWidth) {
    global riskLineGui, riskLineCtl, appNameY, appNameH, appTaglineH
    if (!IsWindowValid(riskLineGui) || !IsWindowValid(riskLineCtl))
        return
    lineW := MeasureTextWidth("RAGNIOUS", 40, 700)
    lineH := 3
    lineX := (mainWidth - lineW) // 2
    lineY := (appNameY + appNameH - 18) + 3 + (appTaglineH - lineH) // 2
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

DrawRiskTosIcon(drawItemStruct) {
    global gdiplusToken, tosIconPressed, tosRippleStart, tosRippleDuration, riskTosInkOff, riskTosCy
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
    hover := TosHoverValue()
    bg := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00000000, "Ptr")
    DllCall("User32\FillRect", "Ptr", memoryDc, "Ptr", localRect, "Ptr", bg)
    DllCall("Gdi32\DeleteObject", "Ptr", bg)
    if (gdiplusToken) {
        graphicsBuffer := Buffer(A_PtrSize, 0)
        if (DllCall("gdiplus\GdipCreateFromHDC", "Ptr", memoryDc, "Ptr", graphicsBuffer, "UInt") = 0) {
            graphics := NumGet(graphicsBuffer, 0, "Ptr")
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4, "UInt")
            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 4, "UInt")
            colorHex := tosIconPressed ? "4752C4" : BlendHexColor("FFFFFF", "5865F2", hover)
            argb := 0xFF000000 | Integer("0x" colorHex)
            baseScale := 20.0 / 18.2887
            sc := baseScale
            logoCX := 11.95, logoCY := 11.99895
            cx := riskTosInkOff + logoCX * baseScale
            cy := riskTosCy
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
            badgeHex := "F2A900"
            DrawTosBadge(graphics, cx + 12.84 * sc / 1.17 + 0.5, cy - 8.29 * sc / 1.17 - 0.5, 0xFF000000 | Integer("0x" badgeHex), 0.92)
            if (tosRippleStart > 0) {
                rippleProgress := (A_TickCount - tosRippleStart) / tosRippleDuration
                if (rippleProgress < 1.0) {
                    rippleRadius := 16.0 + 8.0 * EaseOutCubic(rippleProgress)
                    rcx := cx + 3.5, rcy := cy - 2
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

DrawTosBadge(graphics, bx, by, argb, k := 1.0) {
    DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", graphics, "Float", bx, "Float", by + 0.5 * k, "Int", 0, "UInt")
    DllCall("gdiplus\GdipScaleWorldTransform", "Ptr", graphics, "Float", k, "Float", k, "Int", 0, "UInt")
    pathBuf := Buffer(A_PtrSize, 0)
    if (DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr", pathBuf, "UInt") = 0) {
        shield := NumGet(pathBuf, 0, "Ptr")
        DllCall("gdiplus\GdipAddPathLine", "Ptr", shield, "Float", 0, "Float", -7.4, "Float", 5.8, "Float", -5.3, "UInt")
        DllCall("gdiplus\GdipAddPathLine", "Ptr", shield, "Float", 5.8, "Float", -5.3, "Float", 5.8, "Float", 0.4, "UInt")
        DllCall("gdiplus\GdipAddPathBezier", "Ptr", shield, "Float", 5.8, "Float", 0.4, "Float", 5.8, "Float", 4.4, "Float", 3.0, "Float", 6.5, "Float", 0, "Float", 7.6, "UInt")
        DllCall("gdiplus\GdipAddPathBezier", "Ptr", shield, "Float", 0, "Float", 7.6, "Float", -3.0, "Float", 6.5, "Float", -5.8, "Float", 4.4, "Float", -5.8, "Float", 0.4, "UInt")
        DllCall("gdiplus\GdipAddPathLine", "Ptr", shield, "Float", -5.8, "Float", 0.4, "Float", -5.8, "Float", -5.3, "UInt")
        DllCall("gdiplus\GdipClosePathFigure", "Ptr", shield, "UInt")
        penBuf := Buffer(A_PtrSize, 0)
        if (DllCall("gdiplus\GdipCreatePen1", "UInt", 0xFF000000, "Float", 3.6, "Int", 2, "Ptr", penBuf, "UInt") = 0) {
            pen := NumGet(penBuf, 0, "Ptr")
            DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", pen, "Int", 2, "UInt")
            DllCall("gdiplus\GdipDrawPath", "Ptr", graphics, "Ptr", pen, "Ptr", shield, "UInt")
            DllCall("gdiplus\GdipDeletePen", "Ptr", pen, "UInt")
        }
        brushBuf := Buffer(A_PtrSize, 0)
        if (DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr", brushBuf, "UInt") = 0) {
            brush := NumGet(brushBuf, 0, "Ptr")
            DllCall("gdiplus\GdipFillPath", "Ptr", graphics, "Ptr", brush, "Ptr", shield, "UInt")
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush, "UInt")
        }
        DllCall("gdiplus\GdipDeletePath", "Ptr", shield, "UInt")
    }
    penBuf := Buffer(A_PtrSize, 0)
    if (DllCall("gdiplus\GdipCreatePen1", "UInt", 0xFF000000, "Float", 1.9, "Int", 2, "Ptr", penBuf, "UInt") = 0) {
        pen := NumGet(penBuf, 0, "Ptr")
        DllCall("gdiplus\GdipSetPenStartCap", "Ptr", pen, "Int", 2, "UInt")
        DllCall("gdiplus\GdipSetPenEndCap", "Ptr", pen, "Int", 2, "UInt")
        DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", pen, "Int", 2, "UInt")
        DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", -2.6, "Float", 0.2, "Float", -0.7, "Float", 2.2, "UInt")
        DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", -0.7, "Float", 2.2, "Float", 2.8, "Float", -2.0, "UInt")
        DllCall("gdiplus\GdipDeletePen", "Ptr", pen, "UInt")
    }
    DllCall("gdiplus\GdipResetWorldTransform", "Ptr", graphics, "UInt")
}

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
    NumPut("Int", -height, bmi, 8)
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
        u := Abs(((x + 0.5) / width) * 2 - 1)
        prof := Cos(u * 1.5707963) ** 1.6
        Loop height {
            row := A_Index - 1
            if (Abs(row - midRow) < 0.6)
                inten := prof
            else
                inten := Max(0.0, (prof - 0.22) / 0.78) * 0.85
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

BuildRiskTitleStrip(refDc, height) {
    global riskTitleText, riskTitleTrackW
    global riskTitleStripDc, riskTitleStripBmp, riskTitleStripOld, riskTitleStripH, riskTitleStripDirty, riskTitleStripPhases
    FreeRiskTitleStrip()
    riskTitleStripDirty := false
    riskTitleStripPhases := 1
    stripW := Min(Max(riskTitleTrackW + 64, 64), 30000)
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
            srcX += 1
            srcY := Min(Max(riskTitleRenderedPhase, 0), riskTitleStripPhases - 1) * height
        }
        DllCall("Gdi32\BitBlt", "Ptr", targetHdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", riskTitleStripDc, "Int", srcX, "Int", srcY, "UInt", 0x00CC0020)
    }
    return 1
}

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
    if (!MarqueeTick(&riskTitleOffset, &riskTitleFrames, &riskTitleLastTick, &riskTitlePauseUntil, &riskTitleRenderedX, &riskTitleRenderedPhase
        , riskTitleCycleW, riskTitleOverflowW, riskTitleStripPhases))
        return
    if (PaintControlDirect(riskTitleCtl, DrawRiskTitle))
        return
    DllCall("User32\InvalidateRect", "Ptr", riskTitleCtl.Hwnd, "Ptr", 0, "Int", false)
    DllCall("User32\UpdateWindow", "Ptr", riskTitleCtl.Hwnd)
}

HideMainWidgetsForRisk() {
    global frameGui, selectGui, actionGui, statusDot, statusText, statusMarqueeGui, marqueeViewportNeedsShow, appTagline
    if (IsWindowValid(appTagline))
        appTagline.Opt("+Hidden")
    for g in [frameGui, selectGui, actionGui] {
        if (IsWindowValid(g) && DllCall("User32\IsWindowVisible", "Ptr", g.Hwnd, "Int"))
            g.Hide()
    }
    if (IsWindowValid(statusDot))
        statusDot.Opt("+Hidden")
    if (IsWindowValid(statusText))
        statusText.Opt("+Hidden")
    if (IsWindowValid(statusGlyph))
        statusGlyph.Opt("+Hidden")
    if (IsWindowValid(statusMarqueeGui)) {
        if (DllCall("User32\IsWindowVisible", "Ptr", statusMarqueeGui.Hwnd, "Int"))
            statusMarqueeGui.Hide()
        marqueeViewportNeedsShow := true
    }
}

PositionRiskTosIcon() {
    global riskTosGui, riskTosCtl, updateBtn, updateIcon, riskTosInkOff, riskTosCy, updIconX, updIconY, updIconW, updIconH, updIconDx, hdrOk, hdrCenterY, closeBtn, mainGui
    if (!IsWindowValid(riskTosGui) || !IsWindowValid(riskTosCtl))
        return
    if (IsWindowValid(updateBtn))
        updateBtn.Opt("+Hidden")
    if (IsWindowValid(updateIcon))
        updateIcon.Opt("+Hidden")
    f := A_ScreenDPI / 96
    inkLeft := Round(updIconX * f) + Round(updIconW * f) / 2.0 + updIconDx - UpdateIconRestHalfWidth()
    tosX := Floor(inkLeft) - 4
    newOff := inkLeft - tosX
    newCy := Round(updIconY * f) + (hdrOk ? hdrCenterY : Round(updIconH * f) / 2.0)
    if (IsWindowValid(closeBtn) && IsWindowValid(mainGui)) {
        cbRect := Buffer(16, 0), cbPt := Buffer(8, 0)
        if (DllCall("User32\GetWindowRect", "Ptr", closeBtn.Hwnd, "Ptr", cbRect, "Int")) {
            NumPut("Int", NumGet(cbRect, 0, "Int"), "Int", NumGet(cbRect, 4, "Int"), cbPt, 0)
            if (DllCall("User32\ScreenToClient", "Ptr", mainGui.Hwnd, "Ptr", cbPt, "Int"))
                newCy := NumGet(cbPt, 4, "Int") + (NumGet(cbRect, 12, "Int") - NumGet(cbRect, 4, "Int")) / 2.0
        }
    }
    static lastTosHwnd := 0, lastTosX := -99999
    wasVisible := (lastTosHwnd = riskTosGui.Hwnd && DllCall("User32\IsWindowVisible", "Ptr", riskTosGui.Hwnd, "Int"))
    if (wasVisible && tosX = lastTosX && Abs(newOff - riskTosInkOff) < 0.001 && Abs(newCy - riskTosCy) < 0.001) {
        DllCall("User32\SetWindowPos", "Ptr", riskTosGui.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")
        return
    }
    riskTosInkOff := newOff, riskTosCy := newCy
    lastTosHwnd := riskTosGui.Hwnd, lastTosX := tosX
    if (!wasVisible) {
        riskTosGui.Show(Format("NA x{} y0 w58 h56", Round(tosX / f)))
        riskTosCtl.Move(0, 0, 58, 56)
    }
    DllCall("User32\SetWindowPos", "Ptr", riskTosGui.Hwnd, "Ptr", 0, "Int", tosX, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0011, "Int")
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
        riskGui.Show(Format("NA x1 y{} w{} h{}", riskTop, mainWidth - 2, mainHeight - riskTop - 1))
        lastRiskKey := riskKey
    }
    PositionRiskLine(mainWidth)
    PositionRiskTosIcon()
    DllCall("User32\SetWindowPos", "Ptr", riskGui.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")
    EnsureMainOutline()
}

RiskViewFade(fadeIn, softPaint := false, lateWork := "") {
    global isExiting, riskFadeDuration, fadeInTail, isMarqueeActive, marqueeLastTick
    fadeInTail := false
    lateDone := false
    if (fadeIn && softPaint) {
        SetWindowOpacity(1)
        RiskSoftPaint()
        DllCall("Dwmapi\DwmFlush", "Int")
        DllCall("Dwmapi\DwmFlush", "Int")
    }
    if (fadeIn && !softPaint) {
        SetWindowOpacity(1)
        DllCall("Dwmapi\DwmFlush", "Int")
        DllCall("Dwmapi\DwmFlush", "Int")
    }
    if (isMarqueeActive)
        marqueeLastTick := FrameStamp()
    startMs := NowMs(), duration := riskFadeDuration
    Loop {
        progress := Min((NowMs() - startMs) / duration, 1)
        eased := (progress < 0.5) ? (4 * progress ** 3) : (1 - (-2 * progress + 2) ** 3 / 2)
        SetWindowOpacity(Round(255 * (fadeIn ? eased : 1 - eased)))
        if (fadeIn && progress >= 0.6)
            fadeInTail := true
        if (!fadeIn && lateWork && !lateDone && progress >= 0.8 && progress < 1 && !isExiting) {
            lateDone := true
            lateWork()
            continue
        }
        if (progress >= 1 || isExiting)
            break
        flushed := (DllCall("Dwmapi\DwmFlush", "Int") = 0)
        UpdateMarquee()
        if (flushed)
            Sleep(-1)
        else
            Sleep(8)
    }
    if (fadeIn && !isExiting)
        SetWindowOpacity(255)
}

ShowRpcRiskView(cleanName, appId) {
    global previewFixDropLayered
    global mainGui, isExiting, riskViewActive, riskViewBusy, riskPressedName, riskKeyHeld
    global riskPendingName, riskPendingAppId, riskDeferredStatus, riskTitleActive
    global riskPrevDown, isKeyActionDown, enterBuffered, riskTitleLastTick, riskTitlePauseUntil, riskFadeEndTick, riskBuildDone
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
        riskBuildDone := false
        buildFn := () => RiskBuildView(mainWidth, mainHeight)
        StatusFadeOverlayOn(255)
        RiskViewFade(false, false, buildFn)
        StatusFadeOverlayOff(false)
        if (!riskBuildDone && !isExiting)
            RiskBuildView(mainWidth, mainHeight)
        riskViewActive := true
        SetWindowOpacity(1)
        PositionRiskView(mainWidth, mainHeight)
        PrepaintMainWindow()
        RiskForcePaint()
        DllCall("Dwmapi\DwmFlush", "Int")
        DllCall("Dwmapi\DwmFlush", "Int")
        RiskTitleRestart()
        FocusMainWindowAfterFade()
        RiskViewFade(true, true)
        SettleRepaintNow()
        FocusMainWindowAfterFade()
    } finally {
        StatusFadeOverlayOff(!riskViewActive)
        riskViewBusy := false
        riskFadeEndTick := A_TickCount
        if (riskViewActive) {
            if (riskTitleActive) {
                riskTitleLastTick := FrameStamp()
                riskTitlePauseUntil := NowMs() + MarqueePauseMs()
            }
            SetTimer(RiskViewTick, 15)
            if (!dotBlinkTimerRunning)
                SetTimer(UpdateWarnSignBlink, 80)
            RiskSoftPaint()
            if (previewFixDropLayered) {
                SetTimer(RiskSoftPaint, -40)
                SetTimer(() => RiskSoftPaint(), -160)
            }
        }
        isKeyActionDown := false
        if (!isExiting) {
            SetWindowOpacity(255)
            FocusMainWindowAfterFade()
            SetTimer(FocusMainWindowAfterFade, -40)
            SetTimer(FlushBufferedEnter, -1)
        }
    }
}

RiskBuildView(mainWidth, mainHeight) {
    global riskBuildDone, riskTitleActive, riskTitleCtl, riskLineGui, riskLineCtl, riskTosGui, riskTosCtl, riskGui, riskWarnSign, riskBtnRegistry
    if (riskBuildDone)
        return
    riskBuildDone := true
    RiskHeaderApply(true)
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

RiskHeaderApply(risk) {
    global headerText, riskHeaderText, appVersion, appChannel, versionText, updateSep, updateIcon, titleBar
    global verTextX, verTextY, verTextH, updSepX, updSepY, updSepW, updSepH, updIconX, updIconY, updIconW, updIconH, titleBarX, titleBarY, titleBarW, titleBarH
    headerText := risk ? riskHeaderText : appVersion " " appChannel
    InitUpdaterLayout()
    global verTextW
    MoveCtlIfChanged(versionText, verTextX, verTextY, verTextW, verTextH)
    MoveCtlIfChanged(updateSep, updSepX, updSepY, updSepW, updSepH)
    MoveCtlIfChanged(updateIcon, updIconX, updIconY, updIconW, updIconH)
    MoveCtlIfChanged(titleBar, titleBarX, titleBarY, titleBarW, titleBarH)
    HeaderRepaintAll(true)
}

HideRpcRiskView() {
    global riskFadeEndTick
    global isExiting, riskViewActive, riskViewBusy, riskGui, riskDeferredStatus, riskKeyHeld, lastToggleDoneTick, isKeyActionDown, enterBuffered
    global previewFixDropLayered
    global frameGui, selectGui, actionGui, statusDot, statusText, isMarqueeActive, marqueeViewportNeedsShow
    global appTagline, riskLineGui, riskTitleActive, riskTosGui, versionText, updateBtn, updateSep, updateIcon
    if (!riskViewActive)
        return
    riskViewBusy := true
    enterBuffered := false
    try {
        SetTimer(RiskViewTick, 0)
        SetTimer(UpdateWarnSignBlink, 0)
        riskKeyHeld := false
        RiskViewFade(false)
        riskViewActive := false
        riskTitleActive := false
        FreeRiskTitleStrip()
        if (IsWindowValid(riskGui))
            riskGui.Hide()
        if (IsWindowValid(riskLineGui))
            riskLineGui.Hide()
        TosResetState()
        RiskHeaderApply(false)
        if (IsWindowValid(riskTosGui))
            riskTosGui.Hide()
        if (IsWindowValid(versionText))
            versionText.Opt("-Hidden")
        if (IsWindowValid(updateBtn))
            updateBtn.Opt("-Hidden")
        if (IsWindowValid(updateSep))
            updateSep.Opt("-Hidden")
        if (IsWindowValid(updateIcon))
            updateIcon.Opt("-Hidden")
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
        }
        RepaintActionButtonNoErase()
        RepaintRefreshButtonNoErase()
        PrepaintMainWindow()
        FocusMainWindowAfterFade()
        RiskViewFade(true)
        StatusFadeOverlayOff(true)
        SettleRepaintNow()
        if (previewFixDropLayered)
            SetTimer(SettleRepaint, -60)
        FocusMainWindowAfterFade()
    } finally {
        StatusFadeOverlayOff(true)
        riskViewBusy := false
        riskFadeEndTick := A_TickCount
        riskViewActive := false
        if (!isExiting) {
            try UpdateMarquee()
            DllCall("User32\PostMessageW", "Ptr", A_ScriptHwnd, "UInt", 0x8001, "Ptr", 0, "Ptr", 0, "Int")
        }
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

DeferRiskStatus(text, type) {
    global riskDeferredStatus
    riskDeferredStatus := [text, type]
}

RpcRiskAccept(*) {
    global riskViewActive, riskViewBusy, riskPendingName, riskPendingAppId
    if (!riskViewActive || riskViewBusy || connLost)
        return
    global actionLocked, togglePending
    name := riskPendingName, appId := riskPendingAppId
    actionLocked := true
    try {
        RpcBeginConnect(name, appId)
        HideRpcRiskView()
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

RiskKeyDown() {
    global riskViewActive, riskViewBusy, riskBtnAccept, riskPressedName, riskBtnAnimating, riskKeyHeld, riskKeyCancel
    if (riskKeyHeld && !riskBtnAnimating && riskPressedName = "")
        riskKeyHeld := false
    if (connLost)
        return
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
        riskKeyHeld := false, riskPressedName := ""
    }
}

UpdateWarnSignBlink(toneIndex := 0) {
    global riskWarnSign, riskWarnBlinkStep, riskWarnBmps, riskWarnShown, riskViewActive, isExiting
    if (isExiting || !riskViewActive || !IsWindowValid(riskWarnSign) || !riskWarnBmps.Length)
        return
    if (!toneIndex) {
        toneIndex := Mod(riskWarnBlinkStep, riskWarnBmps.Length) + 1
        riskWarnBlinkStep++
    }
    toneIndex := Min(toneIndex, riskWarnBmps.Length)
    if (toneIndex = riskWarnShown)
        return
    riskWarnShown := toneIndex
    bmp := riskWarnBmps[toneIndex]
    if (PaintControlDirect(riskWarnSign, (fake) => DrawBitmapItem(fake, bmp)))
        return
    DllCall("User32\RedrawWindow", "Ptr", riskWarnSign.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0101, "Int")
}

GetWarnTones() {
    return ["F2A900", "D79500", "BD8200", "A36F00", "895C00", "6F4900", "553600", "6F4900", "895C00", "A36F00", "BD8200", "D79500"]
}

FreeWarnBitmaps() {
    global riskWarnBmps
    for hbm in riskWarnBmps
        DllCall("Gdi32\DeleteObject", "Ptr", hbm)
    riskWarnBmps := []
}

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
            c := n ? sum / (255 * n) : 0
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

RiskForcePaint(erase := true) {
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
            DllCall("User32\RedrawWindow", "Ptr", g.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", erase ? 0x0185 : 0x0181, "Int")
    }
}

RiskSoftPaint() {
    global riskViewActive, riskLineGui, riskTosGui, riskBtnAccept, riskBtnCancel, riskTitleCtl, riskWarnSign, riskHandCtl, mainGui, riskIconCtl
    if (!riskViewActive || !IsWindowValid(mainGui))
        return
    list := [riskLineGui, riskTosGui]
    if (IsObject(riskBtnAccept))
        list.Push(riskBtnAccept.gui)
    if (IsObject(riskBtnCancel))
        list.Push(riskBtnCancel.gui)
    for g in list {
        if (IsWindowValid(g))
            DllCall("User32\RedrawWindow", "Ptr", g.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0181, "Int")
    }
    for c in [riskTitleCtl, riskWarnSign, riskHandCtl, riskIconCtl] {
        if (IsWindowValid(c))
            DllCall("User32\RedrawWindow", "Ptr", c.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0101, "Int")
    }
}

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

RiskViewTick() {
    global riskViewActive, riskViewBusy, riskBtnAccept, riskBtnCancel, riskPressedName, riskBtnAnimating, riskKeyHeld, riskKeyCancel
    global riskPrevDown, riskAnimTick
    if (!riskViewActive) {
        SetTimer(RiskViewTick, 0)
        return
    }
    if (!IsObject(riskBtnAccept) || !IsObject(riskBtnCancel) || !IsWindowValid(riskBtnAccept.gui) || !IsWindowValid(riskBtnCancel.gui))
        return
    try {
        TosHoverPoll()
        down := GetKeyState("LButton", "P")
        edge := down && !riskPrevDown
        riskPrevDown := down
        if (riskBtnAnimating && A_TickCount - riskAnimTick > 2500)
            riskBtnAnimating := false
        if (riskBtnAnimating || riskViewBusy)
            return
        MouseGetPos(,,, &hovered, 2)
        viaKey := false
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
            riskPressedName := ""
            riskKeyHeld := false
            SetRiskBtnColor(riskBtnAccept, riskBtnAccept.normal, false)
            AnimateRiskButton(riskBtnAccept, false)
            return
        }
        if (riskKeyHeld) {
            if (GetKeyState("Enter", "P") || GetKeyState("NumpadEnter", "P"))
                return
            riskKeyHeld := false
            viaKey := true
        }
        if (edge && riskPressedName = "" && !viaKey) {
            for b in [riskBtnAccept, riskBtnCancel] {
                if (connLost && b.name = "accept")
                    continue
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
        riskPressedName := "", riskKeyHeld := false
    }
}

RiskViewLeftDown(hwnd) {
    global mainGui, titleBar, versionText, updateSep, minBtn, closeBtn, donateBtn, riskGui, pressedControl
    global riskBtnAccept, riskBtnCancel, riskPressedName, riskViewBusy, riskBtnAnimating, riskLineGui, riskTitleCtl, riskKeyCancel
    if (IsTosIconHwnd(hwnd)) {
        TosIconDown()
        return
    }
    if (hwnd = mainGui.Hwnd || hwnd = titleBar.Hwnd || hwnd = versionText.Hwnd || (IsWindowValid(updateSep) && hwnd = updateSep.Hwnd) || (IsWindowValid(riskGui) && hwnd = riskGui.Hwnd)
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
    if (hovered = minBtn.Hwnd || hovered = closeBtn.Hwnd || hovered = donateBtn.Hwnd)
        MarqueeFrameAlign()
    if (hovered = minBtn.Hwnd) {
        pressedControl := "min"
        SetTopButtonBg("min", "555555")
        PressIcon("min")
    } else if (hovered = donateBtn.Hwnd) {
        pressedControl := "donate"
        SetTopButtonBg("donate", "555555")
        PressIcon("donate")
    } else if (hovered = closeBtn.Hwnd) {
        pressedControl := "close"
        SetTopButtonBg("close", "B30710")
        PressIcon("close")
    }
}

RiskDialogCursor(hwnd) {
    global riskViewActive, riskBtnAccept, riskBtnCancel
    if (!riskViewActive || !IsObject(riskBtnAccept) || !IsObject(riskBtnCancel))
        return false
    MouseGetPos(,,, &hovered, 2)
    for b in [riskBtnAccept, riskBtnCancel] {
        if (IsWindowValid(b.gui) && (hovered = b.ctl.Hwnd || hovered = b.gui.Hwnd)) {
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

RpcBeginConnect(cleanName, appId) {
    global isRunning, lastHover, rpcConnecting, rpcCancel, rpcConnectName, rpcConnectAppId, rpcConnectStart, lastToggleDoneTick
    global rpcConnPhase, connLastStart
    connLastStart := ["rpc", cleanName, appId]
    StopDiscordRichPresence()
    rpcCancel := false
    rpcConnectName := cleanName, rpcConnectAppId := appId, rpcConnectStart := A_TickCount
    rpcConnPhase := 0
    rpcConnecting := true
    isRunning := true
    SetActionLabel("Stop")
    SetActionColor("B42318")
    SetStatus("Connecting '" cleanName "' to Discord…", "running")
    SetTimer(MonitorProcess, 250)
    RepaintActionButtonNoErase(), lastHover := -1
    UpdateButtonHover()
    lastToggleDoneTick := A_TickCount
    SetTimer(RpcConnectTick, -1)
}

RpcResendActivity() {
    global rpcPipe, rpcResendHandle, rpcStartUnix, isRunning, isExiting
    if (isExiting || !isRunning || !rpcPipe || rpcPipe != rpcResendHandle || !rpcStartUnix)
        return
    nonce := "rs" A_TickCount "x" Random(1000, 9999)
    payload := '{"cmd":"SET_ACTIVITY","args":{"pid":' DllCall("GetCurrentProcessId") ',"activity":{"instance":false,"timestamps":{"start":' rpcStartUnix '}}},"nonce":"' nonce '"}'
    RpcWriteFrame(rpcPipe, 1, payload)
}

RpcConnAbort() {
    global rpcConnHandle, rpcConnPhase
    if (rpcConnHandle) {
        DllCall("CloseHandle", "Ptr", rpcConnHandle)
        rpcConnHandle := 0
    }
    rpcConnPhase := 0
}

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
        SetTimer(RpcConnectTick, -(400 - (A_TickCount - rpcLastStopTick) + 5))
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
            rpcLastError := "Couldn't reach Discord. Make sure the desktop application is open and logged in."
            delay := 25
        }
    } else {
        Loop 12 {
            reply := RpcReadFrame(rpcConnHandle, 0)
            if (!IsObject(reply)) {
                if (reply != "")
                    failed := true
                break
            }
            op := reply["op"], data := reply["data"]
            if (op = 2) {
                rpcLastError := (rpcConnPhase = 1) ? "Discord rejected this application ID. It may be invalid or outdated." : "Discord rejected the connection. Restart Discord and try again."
                failed := true
                break
            }
            if (op = 3) {
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
                        rpcLastError := "Discord rejected the connection. Restart Discord and try again."
                        failed := true
                        break
                    }
                    continue
                }
                if (InStr(data, '"ERROR"')) {
                    rpcLastError := "Discord refused to show the activity. Make sure Activity Status is enabled in Discord settings."
                    failed := true
                    break
                }
                rpcPipe := rpcConnHandle
                rpcConnHandle := 0, rpcConnPhase := 0
                rpcConnecting := false
                SetStatus("Active: Discord Rich Presence is showing '" rpcConnectName "'.", "running")
                rpcResendHandle := rpcPipe
                SetTimer(RpcResendActivity, -2000)
                return
            }
        }
        if (!failed && A_TickCount - rpcConnPhaseStart > 2500) {
            rpcLastError := "Discord didn't respond. Make sure the desktop application is open and try again."
            failed := true
        }
    }
    if (failed) {
        RpcConnAbort()
        delay := 40
    }
    if (A_TickCount - rpcConnectStart > 30000) {
        RpcConnAbort()
        rpcConnecting := false
        isRunning := false
        SetActionLabel("Start")
        SetActionColor("208A4E")
        RepaintActionButtonNoErase(), lastHover := -1
        SetStatus(rpcLastError, "error")
        UpdateButtonHover()
        return
    }
    SetTimer(RpcConnectTick, -delay)
}

BeginHelperLaunch(cleanName, safeDirName, detectedExe) {
    global helperLaunchId, helperLaunching, helperLaunchStart, isRunning, lastHover, lastToggleDoneTick, connLastStart
    connLastStart := ["exe", cleanName, safeDirName, detectedExe]
    SplitPath(detectedExe, &executable)
    helperLaunchId += 1
    myId := helperLaunchId
    helperLaunching := true
    helperLaunchStart := A_TickCount
    isRunning := true
    SetActionLabel("Stop")
    SetActionColor("B42318")
    RepaintActionButtonNoErase(), lastHover := -1
    SetTimer(MonitorProcess, 250)
    UpdateButtonHover()
    lastToggleDoneTick := A_TickCount
    SetTimer(ShowHelperActiveStatus.Bind(myId, cleanName, executable), -1)
    SetTimer(RunHelperLaunch.Bind(myId, cleanName, safeDirName, detectedExe), -1)
}

ShowHelperActiveStatus(myId, cleanName, executable) {
    global helperLaunchId, isRunning, isExiting
    if (isExiting || !isRunning || myId != helperLaunchId)
        return
    SetStatus("Active: '" cleanName "' is running in the background (" executable ").", "running")
}

CancelHelperLaunch() {
    global helperLaunchId, helperLaunching
    if (!helperLaunching)
        return false
    helperLaunching := false
    helperLaunchId += 1
    return true
}

RunHelperLaunch(myId, cleanName, safeDirName, detectedExe, waitStart := 0) {
    global helperLaunchId, helperLaunching, helperThreadBusy, isRunning, lastHover, isExiting, toggleRunning
    if (myId != helperLaunchId || isExiting)
        return
    if (!waitStart)
        waitStart := A_TickCount
    ; Never wait inside this thread: a waiting thread sits on top of the older launch/stop threads and keeps them
    ; from finishing (that froze the Stop button when Start/Stop were spammed). Re-queue and let them unwind first.
    if ((helperThreadBusy || toggleRunning) && A_TickCount - waitStart < 8000) {
        SetTimer(RunHelperLaunch.Bind(myId, cleanName, safeDirName, detectedExe, waitStart), -25)
        return
    }
    ; The title's icon may still be downloading (it is only fetched when a row is shown). Re-queue instead of blocking
    ; until it is loaded or confirmed missing, so the process exe can be built with the right icon.
    if (exeIconPatch && !LaunchIconReady(cleanName) && A_TickCount - waitStart < 5000) {
        SetTimer(RunHelperLaunch.Bind(myId, cleanName, safeDirName, detectedExe, waitStart), -30)
        return
    }
    helperThreadBusy := true
    ok := false, lastError := "Couldn't start '" cleanName "'. Try again, or restart the application if it keeps failing."
    try {
        Loop 3 {
            if (myId != helperLaunchId || isExiting)
                break
            StopTargetProcess()
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
            CleanupHelperFiles()
            return
        }
        helperLaunching := false
        if (ok)
            return
        StopTargetProcess()
        isRunning := false
        SetActionLabel("Start")
        SetActionColor("208A4E")
        RepaintActionButtonNoErase(), lastHover := -1
        SetStatus((SubStr(lastError, 1, 15) = "Couldn't start " || SubStr(lastError, 1, 10) = "Starting '") ? lastError : "Couldn't start '" cleanName "': " lastError, (SubStr(lastError, 1, 10) = "Starting '") ? "stopped" : "error")
        UpdateButtonHover()
    } finally {
        helperThreadBusy := false
    }
}

TryLaunchHelper(myId, cleanName, safeDirName, detectedExe) {
    global targetPid, tempExePath, tempScriptPath, tempWorkDir, helperLaunchId, helperLaunching, isExiting, gameAppIds, gameExeArgs, mainGui, helperFocusPollUntil
    try {
        dirName := RegExReplace(safeDirName, '[\\/<>:"|?*\x00-\x1F]', "_")
        dirName := Trim(RTrim(dirName, ". "))
        if (dirName = "" || StrLower(dirName) = "icons" || RegExMatch(dirName, "i)^(CON|PRN|AUX|NUL|COM\d|LPT\d)(\..*)?$"))
            dirName .= "_game"
        baseDir := A_AppData "\Ragnious\" dirName
        ; Windows (Explorer / Task Manager) caches an exe's icon per full path, and the exe is rebuilt on every launch, so a
        ; path that ever showed the stock icon keeps showing it. The folder is still <AppData>\Ragnious\<Game Title>\
        ; <process>.exe, but its name ends in a few zero-width characters: invisible everywhere, yet a new path for Windows.
        if (exeUniquePath)
            baseDir .= InvisiblePathTag()
        tempWorkDir := baseDir
        if (DirExist(baseDir)) {
            try DirDelete(baseDir, true)
            if (DirExist(baseDir))
                tempWorkDir := baseDir "_" A_TickCount
        }
        SplitPath(detectedExe, &executable)
        executable := RegExReplace(executable, '[\\/<>:"|?*\x00-\x1F]', "_")
        ; Layout: <AppData>\Ragnious\<Game Title>\[<folders from Discord's entry>\]<process>.exe
        ; Discord matches an entry such as "arma 3\arma3.exe" against the END of the running exe's full path, so any
        ; folders in the entry MUST exist (they sit below the title folder, which is not part of the match).
        relPath := SanitizeExecutablePath(detectedExe)
        relSub := ""
        SplitPath(relPath, , &relSub)
        tempExeDir := (relSub != "") ? tempWorkDir "\" relSub : tempWorkDir
        DirCreate(tempExeDir)
        tempExePath := tempExeDir "\" executable
        ; The helper script is embedded in the generated executable; no sidecar script is needed.
        tempScriptPath := ""
        launchToken := "rh" DllCall("GetCurrentProcessId")
        shownTitle := cleanName
        safeTitle := StrReplace(StrReplace(shownTitle, "``", "````"), '"', '``"')
        metaTitle := RegExReplace(shownTitle, "[\r\n]+", " ")
        scriptContent := ""
        scriptContent .= '#Requires AutoHotkey v2.0`n#SingleInstance Ignore`n#NoTrayIcon`n'
        ; Opened by hand (without the launch token) -> silently do nothing.
        scriptContent .= 'if (A_Args.Length < 1 || A_Args[1] != "' launchToken '")`n    ExitApp()`nPersistent()`n'
        scriptContent .= 'parentPid := ' DllCall("GetCurrentProcessId") '`n'
        scriptContent .= 'parentHwnd := ' (IsWindowValid(mainGui) ? mainGui.Hwnd : 0) '`n'
        scriptContent .= 'ParentWatch() {`n    global parentPid`n    if (!ProcessExist(parentPid))`n        ExitApp()`n}`n'
        scriptContent .= 'if (!ProcessExist(parentPid))`n    ExitApp()`n'
        scriptContent .= 'SetTimer(ParentWatch, 1000)`n'
        scriptContent .= 'A_IconTip := "' safeTitle '"`n'
        scriptContent .= 'try A_TrayMenu.Delete()`n'
        scriptContent .= 'A_TrayMenu.Add("Show", ShowPlaceholder)`n'
        scriptContent .= 'A_TrayMenu.Add("Exit", ClosePlaceholder)`n'
        scriptContent .= 'A_TrayMenu.Default := "Show"`n'
        scriptContent .= 'A_TrayMenu.ClickCount := 2`n'
        helperAppId := ""
        helperKey := FindGameKey(cleanName)
        if (helperKey != "" && gameAppIds.Has(helperKey))
            helperAppId := RegExReplace(gameAppIds[helperKey], "[^\w\-]", "")
        helperIconB64 := ""
        try {
            iconMaster := GetGameIconBitmap(cleanName)
            if (iconMaster) {
                iconPng := GameIconEncodeMaster(iconMaster)
                if (iconPng)
                    helperIconB64 := BufferToBase64(iconPng)
            }
        }
        safeExe := StrReplace(StrReplace(executable, "``", "````"), '"', '``"')
        scriptContent .= 'helperTitle := "' safeTitle '"`n'
        scriptContent .= 'helperExe := "' safeExe '"`n'
        scriptContent .= 'helperId := "' helperAppId '"`n'
        scriptContent .= 'helperIcon := "' helperIconB64 '"`n'
        scriptContent .= 'global placeholderGui := "", phInner := "", phW := 0, phH := 0, phShown := false`n'
        scriptContent .= 'global phMqActive := false, phMqCtl := "", phMqText := "", phMqTrackW := 0, phMqViewW := 0, phMqH := 0, phGdipToken := 0`n'
        scriptContent .= 'global phMqOverflowW := 0, phMqCycleW := 0, phMqOffset := 0.0, phMqFrames := 0, phMqLastTick := 0, phMqPauseUntil := 0`n'
        scriptContent .= 'global phMqRenderedX := 0, phMqRenderedPhase := 0, phMqStripDc := 0, phMqStripBmp := 0, phMqStripOld := 0, phMqStripH := 0`n'
        scriptContent .= 'global phMqStripDirty := true, phMqStripPhases := 1, phMqStep := 2, phMqHz := 60.0`n'
        scriptContent .= 'PhApplyIcons()`n'
        scriptContent .= 'BuildPlaceholder()`n'
        scriptContent .= 'PhApplyIcons()`n'
        scriptContent .= 'OnMessage(0x0201, PhDragMove)`n'
        scriptContent .= 'OnMessage(0x002B, PhDrawItem)`n'
        scriptContent .= 'PhMakeHIcon(b64, size) {`n'
        scriptContent .= '    si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)`n'
        scriptContent .= '    NumPut("UInt", 1, si, 0)`n'
        scriptContent .= '    tok := Buffer(A_PtrSize, 0)`n'
        scriptContent .= '    if (DllCall("gdiplus\GdiplusStartup", "Ptr", tok, "Ptr", si, "Ptr", 0, "UInt") != 0)`n'
        scriptContent .= '        return 0`n'
        scriptContent .= '    bmp := 0, g := 0, hic := 0, src := 0, stm := 0`n'
        scriptContent .= '    if (DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", size, "Int", size, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp, "Int") = 0 && bmp) {`n'
        scriptContent .= '        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &g, "Int")`n'
        scriptContent .= '        if (g) {`n'
        scriptContent .= '            DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", 0x00000000, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", g, "Int", 7, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", g, "Int", 2, "Int")`n'
        scriptContent .= '            cb := 0`n'
        scriptContent .= '            if (b64 != "" && DllCall("Crypt32\CryptStringToBinaryW", "Str", b64, "UInt", StrLen(b64), "UInt", 1, "Ptr", 0, "UInt*", &cb, "Ptr", 0, "Ptr", 0, "Int") && cb > 0) {`n'
        scriptContent .= '                data := Buffer(cb)`n'
        scriptContent .= '                if (DllCall("Crypt32\CryptStringToBinaryW", "Str", b64, "UInt", StrLen(b64), "UInt", 1, "Ptr", data, "UInt*", &cb, "Ptr", 0, "Ptr", 0, "Int")) {`n'
        scriptContent .= '                    stm := DllCall("shlwapi\SHCreateMemStream", "Ptr", data, "UInt", cb, "Ptr")`n'
        scriptContent .= '                    if (stm)`n'
        scriptContent .= '                        DllCall("gdiplus\GdipCreateBitmapFromStream", "Ptr", stm, "Ptr*", &src, "Int")`n'
        scriptContent .= '                }`n'
        scriptContent .= '            }`n'
        scriptContent .= '            if (src) {`n'
        scriptContent .= '                DllCall("gdiplus\GdipDrawImageRectI", "Ptr", g, "Ptr", src, "Int", 0, "Int", 0, "Int", size, "Int", size, "Int")`n'
        scriptContent .= '                DllCall("gdiplus\GdipDisposeImage", "Ptr", src, "Int")`n'
        scriptContent .= '            } else`n'
        scriptContent .= '                PhDrawPlaceholder(g, size)`n'
        scriptContent .= '            if (stm)`n'
        scriptContent .= '                ObjRelease(stm)`n'
        scriptContent .= '            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g, "Int")`n'
        scriptContent .= '        }`n'
        scriptContent .= '        DllCall("gdiplus\GdipCreateHICONFromBitmap", "Ptr", bmp, "Ptr*", &hic, "Int")`n'
        scriptContent .= '        DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp, "Int")`n'
        scriptContent .= '    }`n'
        scriptContent .= '    return hic`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhApplyIcons() {`n'
        scriptContent .= '    global placeholderGui, helperIcon`n'
        scriptContent .= '    static hBig := 0, hSm := 0, trayDone := false`n'
        scriptContent .= '    if (!hBig) {`n'
        scriptContent .= '        hBig := PhMakeHIcon(helperIcon, DllCall("GetSystemMetrics", "Int", 11, "Int"))`n'
        scriptContent .= '        hSm := PhMakeHIcon(helperIcon, DllCall("GetSystemMetrics", "Int", 49, "Int"))`n'
        scriptContent .= '    }`n'
        scriptContent .= '    if (!hBig || !hSm)`n'
        scriptContent .= '        return`n'
        scriptContent .= '    if (!trayDone) {`n'
        scriptContent .= '        trayDone := true`n'
        scriptContent .= '        try {`n'
        scriptContent .= '            TraySetIcon("HICON:" hSm, , true)`n'
        scriptContent .= '            A_IconHidden := false`n'
        scriptContent .= '        }`n'
        scriptContent .= '    }`n'
        scriptContent .= '    hwnds := [A_ScriptHwnd]`n'
        scriptContent .= '    if (IsObject(placeholderGui))`n'
        scriptContent .= '        hwnds.Push(placeholderGui.Hwnd)`n'
        scriptContent .= '    for h in hwnds {`n'
        scriptContent .= '        DllCall("SendMessageW", "Ptr", h, "UInt", 0x80, "Ptr", 0, "Ptr", hSm, "Ptr")`n'
        scriptContent .= '        DllCall("SendMessageW", "Ptr", h, "UInt", 0x80, "Ptr", 1, "Ptr", hBig, "Ptr")`n'
        scriptContent .= '    }`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhHideTaskbarTab(hwnd) {`n'
        scriptContent .= '    try {`n'
        scriptContent .= '        tbl := ComObject("{56FDF344-FD6D-11d0-958A-006097C9A090}", "{56FDF342-FD6D-11d0-958A-006097C9A090}")`n'
        scriptContent .= '        ComCall(3, tbl)`n'
        scriptContent .= '        ComCall(5, tbl, "Ptr", hwnd)`n'
        scriptContent .= '    }`n'
        scriptContent .= '}`n'
        scriptContent .= 'ClosePlaceholder(*) {`n'
        scriptContent .= '    ExitApp()`n'
        scriptContent .= '}`n'
        scriptContent .= 'HidePlaceholder(*) {`n'
        scriptContent .= '    global placeholderGui, phShown`n'
        scriptContent .= '    phShown := false`n'
        scriptContent .= '    try placeholderGui.Hide()`n'
        scriptContent .= '    return true`n'
        scriptContent .= '}`n'
        scriptContent .= 'ShowPlaceholder(*) {`n'
        scriptContent .= '    global placeholderGui, phW, phH, phShown`n'
        scriptContent .= '    if (!IsObject(placeholderGui))`n'
        scriptContent .= '        return`n'
        scriptContent .= '    if (PhMainRect(&mx, &my, &mw, &mh))`n'
        scriptContent .= '        placeholderGui.Show("x" (mx + (mw - phW) // 2) " y" (my + (mh - phH) // 2) " w" phW " h" phH)`n'
        scriptContent .= '    else`n'
        scriptContent .= '        placeholderGui.Show("Center")`n'
        scriptContent .= '    phShown := true`n'
        scriptContent .= '    PhMarqueeOnShow()`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhDragMove(wParam, lParam, msg, hwnd) {`n'
        scriptContent .= '    global placeholderGui`n'
        scriptContent .= '    if (!IsObject(placeholderGui))`n'
        scriptContent .= '        return`n'
        scriptContent .= '    root := DllCall("User32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")`n'
        scriptContent .= '    if (root != placeholderGui.Hwnd)`n'
        scriptContent .= '        return`n'
        scriptContent .= '    DllCall("User32\ReleaseCapture")`n'
        scriptContent .= '    PostMessage(0x00A1, 2, 0, , "ahk_id " placeholderGui.Hwnd)`n'
        scriptContent .= '    return 0`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhMainRect(&x, &y, &w, &h) {`n'
        scriptContent .= '    global parentHwnd`n'
        scriptContent .= '    if (!parentHwnd || !DllCall("User32\IsWindow", "Ptr", parentHwnd, "Int"))`n'
        scriptContent .= '        return false`n'
        scriptContent .= '    if (!DllCall("User32\IsIconic", "Ptr", parentHwnd, "Int")) {`n'
        scriptContent .= '        rc := Buffer(16, 0)`n'
        scriptContent .= '        if (!DllCall("User32\GetWindowRect", "Ptr", parentHwnd, "Ptr", rc, "Int"))`n'
        scriptContent .= '            return false`n'
        scriptContent .= '        x := NumGet(rc, 0, "Int"), y := NumGet(rc, 4, "Int")`n'
        scriptContent .= '        w := NumGet(rc, 8, "Int") - x, h := NumGet(rc, 12, "Int") - y`n'
        scriptContent .= '        return (w > 0 && h > 0)`n'
        scriptContent .= '    }`n'
        scriptContent .= '    wp := Buffer(44, 0)`n'
        scriptContent .= '    NumPut("UInt", 44, wp, 0)`n'
        scriptContent .= '    if (!DllCall("User32\GetWindowPlacement", "Ptr", parentHwnd, "Ptr", wp, "Int"))`n'
        scriptContent .= '        return false`n'
        scriptContent .= '    x := NumGet(wp, 28, "Int"), y := NumGet(wp, 32, "Int")`n'
        scriptContent .= '    w := NumGet(wp, 36, "Int") - x, h := NumGet(wp, 40, "Int") - y`n'
        scriptContent .= '    mi := Buffer(40, 0)`n'
        scriptContent .= '    NumPut("UInt", 40, mi, 0)`n'
        scriptContent .= '    hMon := DllCall("User32\MonitorFromPoint", "Int64", 0, "UInt", 1, "Ptr")`n'
        scriptContent .= '    if (hMon && DllCall("User32\GetMonitorInfoW", "Ptr", hMon, "Ptr", mi, "Int")) {`n'
        scriptContent .= '        x += NumGet(mi, 20, "Int") - NumGet(mi, 4, "Int")`n'
        scriptContent .= '        y += NumGet(mi, 24, "Int") - NumGet(mi, 8, "Int")`n'
        scriptContent .= '    }`n'
        scriptContent .= '    return (w > 0 && h > 0)`n'
        scriptContent .= '}`n'
        scriptContent .= 'BuildPlaceholder() {`n'
        scriptContent .= '    global placeholderGui, phInner, phW, phH, helperTitle, helperExe, helperId, helperIcon, phMqCtl`n'
        scriptContent .= '    f := A_ScreenDPI / 96`n'
        scriptContent .= '    phW := Round(380 * f), phH := Round(212 * f)`n'
        scriptContent .= '    if (PhMainRect(&mx, &my, &mw, &mh))`n'
        scriptContent .= '        phW += Mod(Abs(mw - phW), 2), phH += Mod(Abs(mh - phH), 2)`n'
        scriptContent .= '    cr := Round(26 * f)`n'
        scriptContent .= '    iw := phW - 2, ih := phH - 2`n'
        scriptContent .= '    placeholderGui := Gui("-Caption -DPIScale", helperExe)`n'
        scriptContent .= '    placeholderGui.BackColor := "303030"`n'
        scriptContent .= '    placeholderGui.OnEvent("Close", ClosePlaceholder)`n'
        scriptContent .= '    placeholderGui.OnEvent("Escape", HidePlaceholder)`n'
        scriptContent .= '    placeholderGui.Show("NA x-1000000000 y-1000000000 w" phW " h" phH)`n'
        scriptContent .= '    PhHideTaskbarTab(placeholderGui.Hwnd)`n'
        scriptContent .= '    SetTimer(PhHideTaskbarTab.Bind(placeholderGui.Hwnd), -200)`n'
        scriptContent .= '    SetTimer(PhHideTaskbarTab.Bind(placeholderGui.Hwnd), -1200)`n'
        scriptContent .= '    PhRound(placeholderGui.Hwnd, phW, phH, cr)`n'
        scriptContent .= '    phInner := Gui("-Caption -Border -DPIScale +0x40000000", "")`n'
        scriptContent .= '    phInner.Opt("+Parent" placeholderGui.Hwnd)`n'
        scriptContent .= '    phInner.BackColor := "000000"`n'
        scriptContent .= '    phInner.OnEvent("Escape", HidePlaceholder)`n'
        scriptContent .= '    phInner.Show("NA x1 y1 w" iw " h" ih)`n'
        scriptContent .= '    PhRound(phInner.Hwnd, iw, ih, cr - 2)`n'
        scriptContent .= '    pad := Round(20 * f)`n'
        scriptContent .= '    iconPx := Round(32 * f), gap := Round(12 * f)`n'
        scriptContent .= '    rowH := Round(36 * f), lineH := Round(24 * f)`n'
        scriptContent .= '    gapA := Round(8 * f), gapB := Round(2 * f)`n'
        scriptContent .= '    hasId := (helperId != "")`n'
        scriptContent .= '    totalH := rowH + gapA + lineH + (hasId ? gapB + lineH : 0)`n'
        scriptContent .= '    y0 := (ih - totalH) // 2`n'
        scriptContent .= '    titlePad := Round(25 * f) + Round(f)`n'
        scriptContent .= '    maxGroupW := iw - titlePad * 2`n'
        scriptContent .= '    PhTextInk(helperTitle, 16, 700, &titleAdv, &titleBA, &titleBC)`n'
        scriptContent .= '    textPad := Round(6 * f)`n'
        scriptContent .= '    maxTitleW := maxGroupW - iconPx - gap`n'
        scriptContent .= '    titleClipped := (titleAdv > maxTitleW)`n'
        scriptContent .= '    titleW := titleClipped ? maxTitleW : titleAdv + textPad`n'
        scriptContent .= '    inkW := titleClipped ? titleW : titleAdv - titleBA - titleBC`n'
        scriptContent .= '    gx := Round((iw - (iconPx + gap + inkW)) / 2)`n'
        scriptContent .= '    tx := titleClipped ? gx + iconPx + gap : Round(gx + iconPx + gap - titleBA - (titleW - titleAdv) / 2)`n'
        scriptContent .= '    iconCtl := phInner.Add("Text", Format("x{} y{} w{} h{} +0xE +0x04000000", gx, y0 + (rowH - iconPx) // 2, iconPx, iconPx), "")`n'
        scriptContent .= '    hbm := PhIconHBitmap(helperIcon, iconPx)`n'
        scriptContent .= '    if (hbm)`n'
        scriptContent .= '        SendMessage(0x0172, 0, hbm, iconCtl.Hwnd)`n'
        scriptContent .= '    if (titleClipped) {`n'
        scriptContent .= '        phMqCtl := phInner.Add("Text", Format("x{} y{} w{} h{} +0x000D", tx, y0, titleW, rowH), "")`n'
        scriptContent .= '        PhMarqueeStart(helperTitle, titleAdv, titleW, rowH, titlePad)`n'
        scriptContent .= '    } else {`n'
        scriptContent .= '        tTitle := phInner.Add("Text", Format("x{} y{} w{} h{} Center +0x200 +0x80 +0x4000 Background000000 cFFFFFF", tx, y0, titleW, rowH), helperTitle)`n'
        scriptContent .= '        tTitle.SetFont("s16 Bold", "Segoe UI")`n'
        scriptContent .= '    }`n'
        scriptContent .= '    tExe := phInner.Add("Text", Format("x{} y{} w{} h{} Center +0x200 +0x80 +0x4000 Background000000 cA0A0A0", pad, y0 + rowH + gapA, iw - pad * 2, lineH), "(" helperExe ")")`n'
        scriptContent .= '    tExe.SetFont("s12 Norm", "Segoe UI Semibold")`n'
        scriptContent .= '    if (hasId) {`n'
        scriptContent .= '        tId := phInner.Add("Text", Format("x{} y{} w{} h{} Center +0x200 +0x80 +0x4000 Background000000 cA0A0A0", pad, y0 + rowH + gapA + lineH + gapB, iw - pad * 2, lineH), "ID: " . helperId)`n'
        scriptContent .= '        tId.SetFont("s12 Norm", "Segoe UI Semibold")`n'
        scriptContent .= '    }`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhNowMs() {`n'
        scriptContent .= '    static freq := 0`n'
        scriptContent .= '    if (!freq) {`n'
        scriptContent .= '        f := 0`n'
        scriptContent .= '        DllCall("QueryPerformanceFrequency", "Int64*", &f)`n'
        scriptContent .= '        freq := f / 1000.0`n'
        scriptContent .= '    }`n'
        scriptContent .= '    c := 0`n'
        scriptContent .= '    DllCall("QueryPerformanceCounter", "Int64*", &c)`n'
        scriptContent .= '    return c / freq`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhDwmCount() {`n'
        scriptContent .= '    static info := Buffer(304, 0), ok := true`n'
        scriptContent .= '    if (!ok)`n'
        scriptContent .= '        return 0`n'
        scriptContent .= '    NumPut("UInt", 304, info, 0)`n'
        scriptContent .= '    if (DllCall("Dwmapi\DwmGetCompositionTimingInfo", "Ptr", 0, "Ptr", info, "Int") != 0) {`n'
        scriptContent .= '        ok := false`n'
        scriptContent .= '        return 0`n'
        scriptContent .= '    }`n'
        scriptContent .= '    return NumGet(info, 40, "Int64")`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhFrameStamp() {`n'
        scriptContent .= '    vc := PhDwmCount()`n'
        scriptContent .= '    return vc ? vc : PhNowMs()`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhGetHz(hwnd) {`n'
        scriptContent .= '    hz := 0`n'
        scriptContent .= '    hMon := DllCall("User32\MonitorFromWindow", "Ptr", hwnd, "UInt", 1, "Ptr")`n'
        scriptContent .= '    mi := Buffer(104, 0)`n'
        scriptContent .= '    NumPut("UInt", 104, mi, 0)`n'
        scriptContent .= '    if (hMon && DllCall("User32\GetMonitorInfoW", "Ptr", hMon, "Ptr", mi, "Int")) {`n'
        scriptContent .= '        dm := Buffer(220, 0)`n'
        scriptContent .= '        NumPut("UShort", 220, dm, 68)`n'
        scriptContent .= '        if (DllCall("User32\EnumDisplaySettingsW", "Ptr", mi.Ptr + 40, "UInt", 0xFFFFFFFF, "Ptr", dm, "Int"))`n'
        scriptContent .= '            hz := NumGet(dm, 184, "UInt")`n'
        scriptContent .= '    }`n'
        scriptContent .= '    if (hz < 30 || hz > 600) {`n'
        scriptContent .= '        hdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")`n'
        scriptContent .= '        hz := hdc ? DllCall("Gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 116, "Int") : 60`n'
        scriptContent .= '        if (hdc)`n'
        scriptContent .= '            DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", hdc)`n'
        scriptContent .= '    }`n'
        scriptContent .= '    hz := (hz < 30 || hz > 600) ? 60 : hz`n'
        scriptContent .= '    info := Buffer(304, 0)`n'
        scriptContent .= '    NumPut("UInt", 304, info, 0)`n'
        scriptContent .= '    if (DllCall("Dwmapi\DwmGetCompositionTimingInfo", "Ptr", 0, "Ptr", info, "Int") = 0) {`n'
        scriptContent .= '        num := NumGet(info, 4, "UInt"), den := NumGet(info, 8, "UInt")`n'
        scriptContent .= '        if (den > 0 && Abs(num / den - hz) < 1.5)`n'
        scriptContent .= '            hz := num / den`n'
        scriptContent .= '    }`n'
        scriptContent .= '    return hz`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhChooseStep(hz) {`n'
        scriptContent .= '    static table := Map(30,1, 48,2, 50,2, 60,2, 72,2, 75,2, 90,3, 100,3, 120,4, 144,4, 165,5, 180,5, 200,5, 240,6, 280,7, 300,8, 360,9, 480,12, 500,12, 540,13, 600,14)`n'
        scriptContent .= '    r := Round(hz)`n'
        scriptContent .= '    if (table.Has(r))`n'
        scriptContent .= '        return table[r]`n'
        scriptContent .= '    t := Max(0.0, Min(1.0, (hz - 60) / 180))`n'
        scriptContent .= '    target := 30 + 10 * t`n'
        scriptContent .= '    floorSpeed := (hz >= 59.5) ? 29.9 : 23.9`n'
        scriptContent .= '    bestErr := 1.0e9`n'
        scriptContent .= '    bestN := 0`n'
        scriptContent .= '    n := 1`n'
        scriptContent .= '    while (n <= 120) {`n'
        scriptContent .= '        speed := hz / n`n'
        scriptContent .= '        if (speed < floorSpeed - 0.000001)`n'
        scriptContent .= '            break`n'
        scriptContent .= '        if (speed <= 43.001) {`n'
        scriptContent .= '            err := Abs(speed - target) + (Mod(n, 2) ? 0.7 : 0)`n'
        scriptContent .= '            if (err < bestErr - 0.001) {`n'
        scriptContent .= '                bestErr := err`n'
        scriptContent .= '                bestN := n`n'
        scriptContent .= '            }`n'
        scriptContent .= '        }`n'
        scriptContent .= '        n += 1`n'
        scriptContent .= '    }`n'
        scriptContent .= '    return bestN ? bestN : 2`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhMarqueeApplyHz() {`n'
        scriptContent .= '    global placeholderGui, phMqStep, phMqHz, phMqFrames, phMqOffset, phMqStripDirty`n'
        scriptContent .= '    hz := PhGetHz(placeholderGui.Hwnd)`n'
        scriptContent .= '    den := PhChooseStep(hz)`n'
        scriptContent .= '    phMqHz := hz`n'
        scriptContent .= '    if (den != phMqStep) {`n'
        scriptContent .= '        phMqFrames := Integer(Round(phMqOffset * den))`n'
        scriptContent .= '        phMqStep := den`n'
        scriptContent .= '        phMqStripDirty := true`n'
        scriptContent .= '    }`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhMarqueeStart(text, trackW, viewW, h, inset) {`n'
        scriptContent .= '    global phMqActive, phMqText, phMqTrackW, phMqViewW, phMqH, phMqOverflowW, phMqCycleW, phMqStripDirty, phMqCtl, phGdipToken`n'
        scriptContent .= '    DllCall("winmm\timeBeginPeriod", "UInt", 1)`n'
        scriptContent .= '    if (!phGdipToken) {`n'
        scriptContent .= '        si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)`n'
        scriptContent .= '        NumPut("UInt", 1, si, 0)`n'
        scriptContent .= '        tok := Buffer(A_PtrSize, 0)`n'
        scriptContent .= '        if (DllCall("gdiplus\GdiplusStartup", "Ptr", tok, "Ptr", si, "Ptr", 0, "UInt") = 0)`n'
        scriptContent .= '            phGdipToken := NumGet(tok, 0, "UPtr")`n'
        scriptContent .= '    }`n'
        scriptContent .= '    phMqText := text, phMqTrackW := trackW, phMqViewW := viewW, phMqH := h`n'
        scriptContent .= '    phMqOverflowW := trackW - viewW`n'
        scriptContent .= '    phMqCycleW := phMqOverflowW + inset * 2`n'
        scriptContent .= '    phMqStripDirty := true`n'
        scriptContent .= '    PhMarqueeApplyHz()`n'
        scriptContent .= '    hdc := DllCall("User32\GetDC", "Ptr", phMqCtl.Hwnd, "Ptr")`n'
        scriptContent .= '    if (hdc) {`n'
        scriptContent .= '        PhMarqueeBuildStrip(hdc, h)`n'
        scriptContent .= '        DllCall("User32\ReleaseDC", "Ptr", phMqCtl.Hwnd, "Ptr", hdc)`n'
        scriptContent .= '    }`n'
        scriptContent .= '    phMqActive := true`n'
        scriptContent .= '    PhMarqueeRestart()`n'
        scriptContent .= '    SetTimer(PhMarqueeTick, 8)`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhMarqueeOnShow() {`n'
        scriptContent .= '    global phMqActive`n'
        scriptContent .= '    if (!phMqActive)`n'
        scriptContent .= '        return`n'
        scriptContent .= '    PhMarqueeApplyHz()`n'
        scriptContent .= '    PhMarqueeRestart()`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhMarqueeRestart() {`n'
        scriptContent .= '    global phMqOffset, phMqFrames, phMqRenderedX, phMqRenderedPhase, phMqLastTick, phMqPauseUntil`n'
        scriptContent .= '    phMqOffset := 0.0, phMqFrames := 0, phMqRenderedX := 0, phMqRenderedPhase := 0`n'
        scriptContent .= '    phMqLastTick := PhFrameStamp()`n'
        scriptContent .= '    phMqPauseUntil := PhNowMs() + 750`n'
        scriptContent .= '    PhMarqueePaint()`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhMarqueeAdvance(now) {`n'
        scriptContent .= '    global phMqLastTick, phMqFrames, phMqStep, phMqStripPhases, phMqHz`n'
        scriptContent .= '    fine := (phMqStripPhases > 1)`n'
        scriptContent .= '    cap := fine ? 2 : phMqStep`n'
        scriptContent .= '    vc := PhDwmCount()`n'
        scriptContent .= '    if (vc) {`n'
        scriptContent .= '        passed := vc - phMqLastTick`n'
        scriptContent .= '        if (passed < 1)`n'
        scriptContent .= '            return -1`n'
        scriptContent .= '        phMqLastTick := vc`n'
        scriptContent .= '        phMqFrames += Min(passed, cap)`n'
        scriptContent .= '    } else {`n'
        scriptContent .= '        passed := Round((now - phMqLastTick) * phMqHz / 1000)`n'
        scriptContent .= '        if (passed < 1)`n'
        scriptContent .= '            return -1`n'
        scriptContent .= '        phMqLastTick := now`n'
        scriptContent .= '        phMqFrames += Min(passed, cap)`n'
        scriptContent .= '    }`n'
        scriptContent .= '    if (fine)`n'
        scriptContent .= '        return phMqFrames / phMqStep`n'
        scriptContent .= '    return phMqFrames // phMqStep`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhMarqueeStep() {`n'
        scriptContent .= '    global phMqOffset, phMqFrames, phMqLastTick, phMqPauseUntil, phMqRenderedX, phMqRenderedPhase, phMqCycleW, phMqOverflowW, phMqStripPhases`n'
        scriptContent .= '    if (phMqCycleW <= 0)`n'
        scriptContent .= '        return`n'
        scriptContent .= '    now := PhNowMs()`n'
        scriptContent .= '    if (now < phMqPauseUntil) {`n'
        scriptContent .= '        phMqLastTick := PhFrameStamp()`n'
        scriptContent .= '        return`n'
        scriptContent .= '    }`n'
        scriptContent .= '    newOffset := PhMarqueeAdvance(now)`n'
        scriptContent .= '    if (newOffset < 0)`n'
        scriptContent .= '        return`n'
        scriptContent .= '    phMqOffset := newOffset`n'
        scriptContent .= '    if (phMqOffset >= phMqCycleW) {`n'
        scriptContent .= '        phMqOffset := 0.0`n'
        scriptContent .= '        phMqFrames := 0`n'
        scriptContent .= '        phMqPauseUntil := now + 750`n'
        scriptContent .= '    }`n'
        scriptContent .= '    k := Max(1, phMqStripPhases)`n'
        scriptContent .= '    pos := Min(phMqOffset, phMqOverflowW)`n'
        scriptContent .= '    q := Floor(pos * k + 0.000001)`n'
        scriptContent .= '    x := -(q // k)`n'
        scriptContent .= '    p := Mod(q, k)`n'
        scriptContent .= '    if (x = phMqRenderedX && p = phMqRenderedPhase)`n'
        scriptContent .= '        return`n'
        scriptContent .= '    phMqRenderedX := x`n'
        scriptContent .= '    phMqRenderedPhase := p`n'
        scriptContent .= '    PhMarqueePaint()`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhMarqueeTick() {`n'
        scriptContent .= '    global phMqActive, phMqPauseUntil, placeholderGui, phShown`n'
        scriptContent .= '    static busy := false`n'
        scriptContent .= '    if (busy || !phMqActive || !phShown || !IsObject(placeholderGui))`n'
        scriptContent .= '        return`n'
        scriptContent .= '    if (!DllCall("User32\IsWindowVisible", "Ptr", placeholderGui.Hwnd, "Int") || DllCall("User32\IsIconic", "Ptr", placeholderGui.Hwnd, "Int"))`n'
        scriptContent .= '        return`n'
        scriptContent .= '    busy := true`n'
        scriptContent .= '    try {`n'
        scriptContent .= '        loopStart := 0`n'
        scriptContent .= '        Loop {`n'
        scriptContent .= '            moving := (PhNowMs() >= phMqPauseUntil)`n'
        scriptContent .= '            if (moving) {`n'
        scriptContent .= '                if (DllCall("Dwmapi\DwmFlush", "Int") != 0)`n'
        scriptContent .= '                    Sleep(1)`n'
        scriptContent .= '                if (!loopStart)`n'
        scriptContent .= '                    loopStart := PhNowMs()`n'
        scriptContent .= '            }`n'
        scriptContent .= '            PhMarqueeStep()`n'
        scriptContent .= '            if (!moving || !phShown)`n'
        scriptContent .= '                break`n'
        scriptContent .= '            Sleep(-1)`n'
        scriptContent .= '            if (loopStart && PhNowMs() - loopStart >= 20)`n'
        scriptContent .= '                break`n'
        scriptContent .= '        }`n'
        scriptContent .= '    } finally {`n'
        scriptContent .= '        busy := false`n'
        scriptContent .= '    }`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhMarqueePaint() {`n'
        scriptContent .= '    global phMqCtl, phMqViewW, phMqH`n'
        scriptContent .= '    if (!IsObject(phMqCtl))`n'
        scriptContent .= '        return`n'
        scriptContent .= '    hwnd := phMqCtl.Hwnd`n'
        scriptContent .= '    if (!DllCall("User32\IsWindowVisible", "Ptr", hwnd, "Int"))`n'
        scriptContent .= '        return`n'
        scriptContent .= '    hdc := DllCall("User32\GetDC", "Ptr", hwnd, "Ptr")`n'
        scriptContent .= '    if (!hdc)`n'
        scriptContent .= '        return`n'
        scriptContent .= '    PhMarqueeBlit(hdc, 0, 0, phMqViewW, phMqH)`n'
        scriptContent .= '    DllCall("User32\ReleaseDC", "Ptr", hwnd, "Ptr", hdc)`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhMarqueeBlit(hdc, left, top, width, height) {`n'
        scriptContent .= '    global phMqStripDc, phMqStripH, phMqStripDirty, phMqStripPhases, phMqRenderedX, phMqRenderedPhase`n'
        scriptContent .= '    if (phMqStripDirty || phMqStripH != height || !phMqStripDc)`n'
        scriptContent .= '        PhMarqueeBuildStrip(hdc, height)`n'
        scriptContent .= '    if (!phMqStripDc)`n'
        scriptContent .= '        return`n'
        scriptContent .= '    srcX := Max(0, -phMqRenderedX)`n'
        scriptContent .= '    srcY := 0`n'
        scriptContent .= '    if (phMqStripPhases > 1) {`n'
        scriptContent .= '        srcX += 1`n'
        scriptContent .= '        srcY := Min(Max(phMqRenderedPhase, 0), phMqStripPhases - 1) * height`n'
        scriptContent .= '    }`n'
        scriptContent .= '    DllCall("Gdi32\BitBlt", "Ptr", hdc, "Int", left, "Int", top, "Int", width, "Int", height, "Ptr", phMqStripDc, "Int", srcX, "Int", srcY, "UInt", 0x00CC0020)`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhDrawItem(wParam, lParam, msg, hwnd) {`n'
        scriptContent .= '    global phMqActive, phMqCtl, phInner`n'
        scriptContent .= '    if (!phMqActive || !IsObject(phInner) || !IsObject(phMqCtl))`n'
        scriptContent .= '        return`n'
        scriptContent .= '    if (hwnd != phInner.Hwnd)`n'
        scriptContent .= '        return`n'
        scriptContent .= '    off := (A_PtrSize = 8) ? 24 : 20`n'
        scriptContent .= '    if (NumGet(lParam, off, "Ptr") != phMqCtl.Hwnd)`n'
        scriptContent .= '        return`n'
        scriptContent .= '    hdc := NumGet(lParam, off + A_PtrSize, "Ptr")`n'
        scriptContent .= '    ro := off + A_PtrSize * 2`n'
        scriptContent .= '    left := NumGet(lParam, ro, "Int")`n'
        scriptContent .= '    top := NumGet(lParam, ro + 4, "Int")`n'
        scriptContent .= '    width := NumGet(lParam, ro + 8, "Int") - left`n'
        scriptContent .= '    height := NumGet(lParam, ro + 12, "Int") - top`n'
        scriptContent .= '    if (width > 0 && height > 0 && hdc)`n'
        scriptContent .= '        PhMarqueeBlit(hdc, left, top, width, height)`n'
        scriptContent .= '    return 1`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhMarqueeFreeStrip() {`n'
        scriptContent .= '    global phMqStripDc, phMqStripBmp, phMqStripOld`n'
        scriptContent .= '    if (phMqStripDc) {`n'
        scriptContent .= '        DllCall("Gdi32\SelectObject", "Ptr", phMqStripDc, "Ptr", phMqStripOld, "Ptr")`n'
        scriptContent .= '        DllCall("Gdi32\DeleteObject", "Ptr", phMqStripBmp)`n'
        scriptContent .= '        DllCall("Gdi32\DeleteDC", "Ptr", phMqStripDc)`n'
        scriptContent .= '    }`n'
        scriptContent .= '    phMqStripDc := 0, phMqStripBmp := 0, phMqStripOld := 0`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhMarqueeChoosePhases(stripW, bandH) {`n'
        scriptContent .= '    global phGdipToken, phMqStep`n'
        scriptContent .= '    if (!phGdipToken)`n'
        scriptContent .= '        return 1`n'
        scriptContent .= '    n := Max(1, Integer(phMqStep))`n'
        scriptContent .= '    m := Max(1, Round(8 / n))`n'
        scriptContent .= '    while (m >= 1) {`n'
        scriptContent .= '        k := n * m`n'
        scriptContent .= '        if (stripW * bandH * k * 4 <= 50331648)`n'
        scriptContent .= '            return (k >= 2) ? k : 1`n'
        scriptContent .= '        m -= 1`n'
        scriptContent .= '    }`n'
        scriptContent .= '    return 1`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhMarqueeBuildStrip(refDc, height) {`n'
        scriptContent .= '    global phMqText, phMqTrackW, phMqStripDc, phMqStripBmp, phMqStripOld, phMqStripH, phMqStripDirty, phMqStripPhases`n'
        scriptContent .= '    PhMarqueeFreeStrip()`n'
        scriptContent .= '    phMqStripDirty := false`n'
        scriptContent .= '    phMqStripPhases := 1`n'
        scriptContent .= '    stripW := Min(Max(phMqTrackW + 64, 64), 30000)`n'
        scriptContent .= '    phases := (phMqText != "" && phMqTrackW > 0) ? PhMarqueeChoosePhases(stripW, height) : 1`n'
        scriptContent .= '    dc := DllCall("Gdi32\CreateCompatibleDC", "Ptr", refDc, "Ptr")`n'
        scriptContent .= '    if (!dc)`n'
        scriptContent .= '        return`n'
        scriptContent .= '    bmp := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", refDc, "Int", stripW, "Int", height * phases, "Ptr")`n'
        scriptContent .= '    if (!bmp && phases > 1) {`n'
        scriptContent .= '        phases := 1`n'
        scriptContent .= '        bmp := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", refDc, "Int", stripW, "Int", height, "Ptr")`n'
        scriptContent .= '    }`n'
        scriptContent .= '    if (!bmp) {`n'
        scriptContent .= '        DllCall("Gdi32\DeleteDC", "Ptr", dc)`n'
        scriptContent .= '        return`n'
        scriptContent .= '    }`n'
        scriptContent .= '    oldBmp := DllCall("Gdi32\SelectObject", "Ptr", dc, "Ptr", bmp, "Ptr")`n'
        scriptContent .= '    fullRect := Buffer(16, 0)`n'
        scriptContent .= '    NumPut("Int", stripW, fullRect, 8)`n'
        scriptContent .= '    NumPut("Int", height * phases, fullRect, 12)`n'
        scriptContent .= '    brush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00000000, "Ptr")`n'
        scriptContent .= '    DllCall("User32\FillRect", "Ptr", dc, "Ptr", fullRect, "Ptr", brush)`n'
        scriptContent .= '    DllCall("Gdi32\DeleteObject", "Ptr", brush)`n'
        scriptContent .= '    dpi := DllCall("Gdi32\GetDeviceCaps", "Ptr", refDc, "Int", 90)`n'
        scriptContent .= '    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(16 * dpi / 72), "Int", 0, "Int", 0, "Int", 0, "Int", 700, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", "Segoe UI", "Ptr")`n'
        scriptContent .= '    oldFont := DllCall("Gdi32\SelectObject", "Ptr", dc, "Ptr", hFont, "Ptr")`n'
        scriptContent .= '    smoothOk := false`n'
        scriptContent .= '    if (phases > 1) {`n'
        scriptContent .= '        tm := Buffer(80, 0)`n'
        scriptContent .= '        DllCall("Gdi32\GetTextMetricsW", "Ptr", dc, "Ptr", tm)`n'
        scriptContent .= '        tmHeight := NumGet(tm, 0, "Int")`n'
        scriptContent .= '        smoothOk := PhSubpixelBands(dc, stripW, height, phases, phMqText, phMqTrackW, Round(16 * dpi / 72), tmHeight)`n'
        scriptContent .= '        if (!smoothOk) {`n'
        scriptContent .= '            phases := 1`n'
        scriptContent .= '            NumPut("Int", height, fullRect, 12)`n'
        scriptContent .= '            brush := DllCall("Gdi32\CreateSolidBrush", "UInt", 0x00000000, "Ptr")`n'
        scriptContent .= '            DllCall("User32\FillRect", "Ptr", dc, "Ptr", fullRect, "Ptr", brush)`n'
        scriptContent .= '            DllCall("Gdi32\DeleteObject", "Ptr", brush)`n'
        scriptContent .= '        }`n'
        scriptContent .= '    }`n'
        scriptContent .= '    if (!smoothOk) {`n'
        scriptContent .= '        DllCall("Gdi32\SetBkMode", "Ptr", dc, "Int", 1)`n'
        scriptContent .= '        DllCall("Gdi32\SetTextColor", "Ptr", dc, "UInt", 0x00FFFFFF)`n'
        scriptContent .= '        textRect := Buffer(16, 0)`n'
        scriptContent .= '        NumPut("Int", stripW, textRect, 8)`n'
        scriptContent .= '        NumPut("Int", height, textRect, 12)`n'
        scriptContent .= '        DllCall("User32\DrawTextW", "Ptr", dc, "Str", phMqText, "Int", -1, "Ptr", textRect, "UInt", 0x00000B24)`n'
        scriptContent .= '    }`n'
        scriptContent .= '    DllCall("Gdi32\SelectObject", "Ptr", dc, "Ptr", oldFont, "Ptr")`n'
        scriptContent .= '    DllCall("Gdi32\DeleteObject", "Ptr", hFont)`n'
        scriptContent .= '    phMqStripDc := dc, phMqStripBmp := bmp, phMqStripOld := oldBmp, phMqStripH := height`n'
        scriptContent .= '    phMqStripPhases := phases`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhSubpixelBands(dc, stripW, bandH, phases, text, targetW, emPx, tmHeight) {`n'
        scriptContent .= '    global phGdipToken`n'
        scriptContent .= '    if (!phGdipToken || phases < 2 || text = "" || !dc)`n'
        scriptContent .= '        return false`n'
        scriptContent .= '    g := 0, fam := 0, font := 0, fmt := 0, brush := 0, gpath := 0, ok := false`n'
        scriptContent .= '    try {`n'
        scriptContent .= '        if (DllCall("gdiplus\GdipCreateFromHDC", "Ptr", dc, "Ptr*", &g, "Int") != 0 || !g)`n'
        scriptContent .= '            throw Error("graphics")`n'
        scriptContent .= '        DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", g, "Int", 4, "Int")`n'
        scriptContent .= '        DllCall("gdiplus\GdipSetCompositingQuality", "Ptr", g, "Int", 3, "Int")`n'
        scriptContent .= '        if (DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &fam, "Int") != 0 || !fam)`n'
        scriptContent .= '            throw Error("family")`n'
        scriptContent .= '        if (DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", emPx + 0.0, "Int", 1, "Int", 2, "Ptr*", &font, "Int") != 0 || !font)`n'
        scriptContent .= '            throw Error("font")`n'
        scriptContent .= '        gf := 0`n'
        scriptContent .= '        DllCall("gdiplus\GdipStringFormatGetGenericTypographic", "Ptr*", &gf, "Int")`n'
        scriptContent .= '        if (!gf || DllCall("gdiplus\GdipCloneStringFormat", "Ptr", gf, "Ptr*", &fmt, "Int") != 0 || !fmt)`n'
        scriptContent .= '            throw Error("format")`n'
        scriptContent .= '        fl := 0`n'
        scriptContent .= '        DllCall("gdiplus\GdipGetStringFormatFlags", "Ptr", fmt, "Int*", &fl, "Int")`n'
        scriptContent .= '        DllCall("gdiplus\GdipSetStringFormatFlags", "Ptr", fmt, "Int", fl | 0x1000 | 0x4000 | 0x800, "Int")`n'
        scriptContent .= '        if (DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFFFFFFFF, "Ptr*", &brush, "Int") != 0 || !brush)`n'
        scriptContent .= '            throw Error("brush")`n'
        scriptContent .= '        layout := Buffer(16, 0)`n'
        scriptContent .= '        bbox := Buffer(16, 0)`n'
        scriptContent .= '        NumPut("Float", 0.0, "Float", 0.0, "Float", 100000.0, "Float", bandH + 0.0, layout, 0)`n'
        scriptContent .= '        fitChars := 0, fitLines := 0`n'
        scriptContent .= '        sx := 1.0`n'
        scriptContent .= '        if (DllCall("gdiplus\GdipMeasureString", "Ptr", g, "WStr", text, "Int", -1, "Ptr", font, "Ptr", layout, "Ptr", fmt, "Ptr", bbox, "Int*", &fitChars, "Int*", &fitLines, "Int") = 0) {`n'
        scriptContent .= '            mw := NumGet(bbox, 8, "Float")`n'
        scriptContent .= '            if (mw > 1 && targetW > 1)`n'
        scriptContent .= '                sx := Max(0.9, Min(1.1, targetW / mw))`n'
        scriptContent .= '        }`n'
        scriptContent .= '        yTop := (bandH - tmHeight) // 2`n'
        scriptContent .= '        usePath := false`n'
        scriptContent .= '        if (DllCall("gdiplus\GdipCreatePath", "Int", 1, "Ptr*", &gpath, "Int") = 0 && gpath) {`n'
        scriptContent .= '            NumPut("Float", 0.0, "Float", 0.0, "Float", 100000.0, "Float", bandH + 0.0, layout, 0)`n'
        scriptContent .= '            if (DllCall("gdiplus\GdipAddPathString", "Ptr", gpath, "WStr", text, "Int", -1, "Ptr", fam, "Int", 1, "Float", emPx + 0.0, "Ptr", layout, "Ptr", fmt, "Int") = 0) {`n'
        scriptContent .= '                DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4, "Int")`n'
        scriptContent .= '                usePath := true`n'
        scriptContent .= '            }`n'
        scriptContent .= '        }`n'
        scriptContent .= '        Loop phases {`n'
        scriptContent .= '            i := A_Index - 1`n'
        scriptContent .= '            yBase := i * bandH`n'
        scriptContent .= '            DllCall("gdiplus\GdipResetWorldTransform", "Ptr", g, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipSetClipRectI", "Ptr", g, "Int", 0, "Int", yBase, "Int", stripW, "Int", bandH, "Int", 0, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipResetWorldTransform", "Ptr", g, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", g, "Float", 1.0 - i / phases, "Float", yBase + yTop + 0.0, "Int", 0, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipScaleWorldTransform", "Ptr", g, "Float", sx, "Float", 1.0, "Int", 0, "Int")`n'
        scriptContent .= '            if (usePath) {`n'
        scriptContent .= '                DllCall("gdiplus\GdipFillPath", "Ptr", g, "Ptr", brush, "Ptr", gpath, "Int")`n'
        scriptContent .= '            } else {`n'
        scriptContent .= '                NumPut("Float", 0.0, "Float", 0.0, "Float", 100000.0, "Float", bandH + 0.0, layout, 0)`n'
        scriptContent .= '                DllCall("gdiplus\GdipDrawString", "Ptr", g, "WStr", text, "Int", -1, "Ptr", font, "Ptr", layout, "Ptr", fmt, "Ptr", brush, "Int")`n'
        scriptContent .= '            }`n'
        scriptContent .= '        }`n'
        scriptContent .= '        DllCall("gdiplus\GdipFlush", "Ptr", g, "Int", 1, "Int")`n'
        scriptContent .= '        ok := true`n'
        scriptContent .= '    } catch {`n'
        scriptContent .= '        ok := false`n'
        scriptContent .= '    }`n'
        scriptContent .= '    if (gpath)`n'
        scriptContent .= '        DllCall("gdiplus\GdipDeletePath", "Ptr", gpath, "Int")`n'
        scriptContent .= '    if (brush)`n'
        scriptContent .= '        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush, "Int")`n'
        scriptContent .= '    if (fmt)`n'
        scriptContent .= '        DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", fmt, "Int")`n'
        scriptContent .= '    if (font)`n'
        scriptContent .= '        DllCall("gdiplus\GdipDeleteFont", "Ptr", font, "Int")`n'
        scriptContent .= '    if (fam)`n'
        scriptContent .= '        DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", fam, "Int")`n'
        scriptContent .= '    if (g)`n'
        scriptContent .= '        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g, "Int")`n'
        scriptContent .= '    return ok`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhRound(hwnd, w, h, c) {`n'
        scriptContent .= '    rgn := DllCall("Gdi32\CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", c, "Int", c, "Ptr")`n'
        scriptContent .= '    if (rgn && !DllCall("User32\SetWindowRgn", "Ptr", hwnd, "Ptr", rgn, "Int", true, "Int"))`n'
        scriptContent .= '        DllCall("Gdi32\DeleteObject", "Ptr", rgn)`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhTextW(text, pt, weight) {`n'
        scriptContent .= '    hdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")`n'
        scriptContent .= '    if (!hdc)`n'
        scriptContent .= '        return 0`n'
        scriptContent .= '    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(pt * DllCall("Gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 90) / 72), "Int", 0, "Int", 0, "Int", 0, "Int", weight, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", "Segoe UI", "Ptr")`n'
        scriptContent .= '    oldFont := DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")`n'
        scriptContent .= '    size := Buffer(8, 0)`n'
        scriptContent .= '    DllCall("Gdi32\GetTextExtentPoint32W", "Ptr", hdc, "Str", text, "Int", StrLen(text), "Ptr", size)`n'
        scriptContent .= '    DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")`n'
        scriptContent .= '    DllCall("Gdi32\DeleteObject", "Ptr", hFont)`n'
        scriptContent .= '    DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", hdc)`n'
        scriptContent .= '    return NumGet(size, 0, "Int")`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhTextInk(text, pt, weight, &adv, &bA, &bC) {`n'
        scriptContent .= '    adv := PhTextW(text, pt, weight), bA := 0, bC := 0`n'
        scriptContent .= '    if (text = "")`n'
        scriptContent .= '        return`n'
        scriptContent .= '    hdc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")`n'
        scriptContent .= '    if (!hdc)`n'
        scriptContent .= '        return`n'
        scriptContent .= '    hFont := DllCall("Gdi32\CreateFontW", "Int", -Round(pt * DllCall("Gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 90) / 72), "Int", 0, "Int", 0, "Int", 0, "Int", weight, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", "Segoe UI", "Ptr")`n'
        scriptContent .= '    oldFont := DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")`n'
        scriptContent .= '    abc := Buffer(12, 0)`n'
        scriptContent .= '    first := Ord(SubStr(text, 1, 1)), last := Ord(SubStr(text, -1))`n'
        scriptContent .= '    if (DllCall("Gdi32\GetCharABCWidthsW", "Ptr", hdc, "UInt", first, "UInt", first, "Ptr", abc, "Int"))`n'
        scriptContent .= '        bA := NumGet(abc, 0, "Int")`n'
        scriptContent .= '    if (DllCall("Gdi32\GetCharABCWidthsW", "Ptr", hdc, "UInt", last, "UInt", last, "Ptr", abc, "Int"))`n'
        scriptContent .= '        bC := NumGet(abc, 8, "Int")`n'
        scriptContent .= '    DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")`n'
        scriptContent .= '    DllCall("Gdi32\DeleteObject", "Ptr", hFont)`n'
        scriptContent .= '    DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", hdc)`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhDrawPlaceholder(g, size) {`n'
        scriptContent .= '    brush := 0, path := 0`n'
        scriptContent .= '    if (DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF4F4F4F, "Ptr*", &brush, "Int") = 0 && brush) {`n'
        scriptContent .= '        if (DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path, "Int") = 0 && path) {`n'
        scriptContent .= '            d := size * 0.5`n'
        scriptContent .= '            e := size - d`n'
        scriptContent .= '            DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", 0.0, "Float", 0.0, "Float", d, "Float", d, "Float", 180.0, "Float", 90.0, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", e, "Float", 0.0, "Float", d, "Float", d, "Float", 270.0, "Float", 90.0, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", e, "Float", e, "Float", d, "Float", d, "Float", 0.0, "Float", 90.0, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", 0.0, "Float", e, "Float", d, "Float", d, "Float", 90.0, "Float", 90.0, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipClosePathFigure", "Ptr", path, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipFillPath", "Ptr", g, "Ptr", brush, "Ptr", path, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipDeletePath", "Ptr", path, "Int")`n'
        scriptContent .= '        }`n'
        scriptContent .= '        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush, "Int")`n'
        scriptContent .= '    }`n'
        scriptContent .= '}`n'
        scriptContent .= 'PhIconHBitmap(b64, size) {`n'
        scriptContent .= '    si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)`n'
        scriptContent .= '    NumPut("UInt", 1, si, 0)`n'
        scriptContent .= '    tok := Buffer(A_PtrSize, 0)`n'
        scriptContent .= '    if (DllCall("gdiplus\GdiplusStartup", "Ptr", tok, "Ptr", si, "Ptr", 0, "UInt") != 0)`n'
        scriptContent .= '        return 0`n'
        scriptContent .= '    token := NumGet(tok, 0, "UPtr")`n'
        scriptContent .= '    bmp := 0, g := 0, hbm := 0, src := 0, stm := 0`n'
        scriptContent .= '    if (DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", size, "Int", size, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp, "Int") = 0 && bmp) {`n'
        scriptContent .= '        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &g, "Int")`n'
        scriptContent .= '        if (g) {`n'
        scriptContent .= '            DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", 0xFF000000, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", g, "Int", 7, "Int")`n'
        scriptContent .= '            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", g, "Int", 2, "Int")`n'
        scriptContent .= '            cb := 0`n'
        scriptContent .= '            if (b64 != "" && DllCall("Crypt32\CryptStringToBinaryW", "Str", b64, "UInt", StrLen(b64), "UInt", 1, "Ptr", 0, "UInt*", &cb, "Ptr", 0, "Ptr", 0, "Int") && cb > 0) {`n'
        scriptContent .= '                data := Buffer(cb)`n'
        scriptContent .= '                if (DllCall("Crypt32\CryptStringToBinaryW", "Str", b64, "UInt", StrLen(b64), "UInt", 1, "Ptr", data, "UInt*", &cb, "Ptr", 0, "Ptr", 0, "Int")) {`n'
        scriptContent .= '                    stm := DllCall("shlwapi\SHCreateMemStream", "Ptr", data, "UInt", cb, "Ptr")`n'
        scriptContent .= '                    if (stm)`n'
        scriptContent .= '                        DllCall("gdiplus\GdipCreateBitmapFromStream", "Ptr", stm, "Ptr*", &src, "Int")`n'
        scriptContent .= '                }`n'
        scriptContent .= '            }`n'
        scriptContent .= '            if (src) {`n'
        scriptContent .= '                DllCall("gdiplus\GdipDrawImageRectI", "Ptr", g, "Ptr", src, "Int", 0, "Int", 0, "Int", size, "Int", size, "Int")`n'
        scriptContent .= '                DllCall("gdiplus\GdipDisposeImage", "Ptr", src, "Int")`n'
        scriptContent .= '            } else`n'
        scriptContent .= '                PhDrawPlaceholder(g, size)`n'
        scriptContent .= '            if (stm)`n'
        scriptContent .= '                ObjRelease(stm)`n'
        scriptContent .= '            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g, "Int")`n'
        scriptContent .= '        }`n'
        scriptContent .= '        DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bmp, "Ptr*", &hbm, "UInt", 0xFF000000, "Int")`n'
        scriptContent .= '        DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp, "Int")`n'
        scriptContent .= '    }`n'
        scriptContent .= '    return hbm`n'
        scriptContent .= '}`n'
        if (myId != helperLaunchId || isExiting)
            return "Starting '" cleanName "' was cancelled."
        ; Helper exe is created from the bundled runtime and written under the game's exe name.
        try FileDelete(tempExePath)
        if (!ExtractBundledInterpreter(tempExePath))
            return "Couldn't prepare the process executable. Check that antivirus isn't blocking it."
        ; Patch the version resource (and verify it) so Task Manager shows the game title from the first moment.
        ; Set exeVersionPatch := false to skip it.
        if (exeVersionPatch) {
            SplitPath(tempExePath, &exeBaseName)
            try SetExeVersionInfo(tempExePath, shownTitle, exeBaseName)
        }
        ; Give the process exe the same icon the game title has in the list (Task Manager, Explorer, taskbar).
        ; A private copy is used so the icon cache can't dispose the bitmap while it is being written.
        ; Titles without an icon get the same "unknown" icon the list shows for them.
        if (exeIconPatch) {
            exeIconBmp := 0
            try {
                exeIconBmp := LaunchIconClone(cleanName)
                if (!exeIconBmp) {
                    um := GetUnknownIconMaster()
                    if (um)
                        DllCall("gdiplus\GdipCloneImage", "Ptr", um, "Ptr*", &exeIconBmp, "Int")
                }
                if (exeIconBmp && !SetExeIcon(tempExePath, exeIconBmp)) {
                    Sleep(300)
                    SetExeIcon(tempExePath, exeIconBmp)
                }
            }
            if (exeIconBmp)
                DllCall("gdiplus\GdipDisposeImage", "Ptr", exeIconBmp, "Int")
        }
        ; Remove Resource Hacker categories that should not be present in the generated process exe.
        resourceResult := RemoveExeResourceTypes(tempExePath, [4, 5, 9, 24]) ; RT_MENU, RT_DIALOG, RT_ACCELERATOR, RT_MANIFEST
        if (resourceResult != true)
            return "Could not clean generated executable resources: " resourceResult
        if (exeEmbeddedScript && !EmbedExeScript(tempExePath, scriptContent))
            return "Could not embed the process script in the generated executable."
        if (myId != helperLaunchId || isExiting)
            return "Starting '" cleanName "' was cancelled."
        launchOptions := "Hide"
        outPid := 0
        extraArgs := ""
        if (helperKey != "" && gameExeArgs.Has(helperKey) && gameExeArgs[helperKey][1] = detectedExe)
            extraArgs := gameExeArgs[helperKey][2]
        Run('"' tempExePath '" ' launchToken (extraArgs != "" ? " " extraArgs : ""), tempWorkDir, "Hide", &outPid)
        if (!outPid)
            return "The process was created but didn't start. Try again, or check whether antivirus is blocking it."
        AssignToKillJob(outPid)
        if (myId != helperLaunchId || isExiting) {
            try ProcessClose(outPid)
            return "Starting '" cleanName "' was cancelled."
        }
        ; the interpreter reads the whole script at startup; once its window exists the file is no longer needed
        prevDhw := A_DetectHiddenWindows
        DetectHiddenWindows(true)
        loadStart := A_TickCount
        while (ProcessExist(outPid) && !WinExist("ahk_class AutoHotkey ahk_pid " outPid) && A_TickCount - loadStart < 5000 && myId = helperLaunchId && !isExiting)
            Sleep(10)
        DetectHiddenWindows(prevDhw)
        if (myId != helperLaunchId || isExiting) {
            try ProcessClose(outPid)
            return "Starting '" cleanName "' was cancelled."
        }
        targetPid := outPid
        helperLaunching := false
        helperFocusPollUntil := A_TickCount + 3000
        SetTimer(ReclaimFocusFromHelper, 50)
        return ""
    } catch Error as err {
        ; Show and log the real reason instead of a generic message.
        try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "  " cleanName "  | " err.Message " | " err.What " | line " err.Line "`n", A_AppData "\Ragnious\launch_error.log", "UTF-8")
        return "Something went wrong while launching '" cleanName "' (" err.Message "). Try again."
    }
}

; Starts `exe` hidden and hands it `script` through its standard input ("*" script name), so no script file exists on disk.
StartWithStdinScript(exe, args, workDir, script, &pid) {
    pid := 0
    p8 := (A_PtrSize = 8)
    sa := Buffer(p8 ? 24 : 12, 0)
    NumPut("UInt", sa.Size, sa, 0)
    NumPut("Int", 1, sa, p8 ? 16 : 8)
    hRead := 0, hWrite := 0
    if (!DllCall("Kernel32\CreatePipe", "Ptr*", &hRead, "Ptr*", &hWrite, "Ptr", sa, "UInt", 0, "Int"))
        return false
    DllCall("Kernel32\SetHandleInformation", "Ptr", hWrite, "UInt", 1, "UInt", 0, "Int")
    si := Buffer(p8 ? 104 : 68, 0)
    NumPut("UInt", si.Size, si, 0)
    NumPut("UInt", 0x101, si, p8 ? 60 : 44)
    NumPut("UShort", 0, si, p8 ? 64 : 48)
    NumPut("Ptr", hRead, si, p8 ? 80 : 56)
    pi := Buffer(p8 ? 24 : 16, 0)
    cmdStr := '"' exe '" ' args
    cmd := Buffer((StrLen(cmdStr) + 1) * 2, 0)
    StrPut(cmdStr, cmd, "UTF-16")
    ok := DllCall("Kernel32\CreateProcessW", "Ptr", 0, "Ptr", cmd, "Ptr", 0, "Ptr", 0, "Int", true, "UInt", 0x08000000, "Ptr", 0, "WStr", workDir, "Ptr", si, "Ptr", pi, "Int")
    DllCall("Kernel32\CloseHandle", "Ptr", hRead)
    if (!ok) {
        DllCall("Kernel32\CloseHandle", "Ptr", hWrite)
        return false
    }
    pid := NumGet(pi, 2 * A_PtrSize, "UInt")
    n := StrPut(script, "UTF-8") - 1
    data := Buffer(n + 1, 0)
    StrPut(script, data, "UTF-8")
    written := 0
    DllCall("Kernel32\WriteFile", "Ptr", hWrite, "Ptr", data, "UInt", n, "UInt*", &written, "Ptr", 0, "Int")
    DllCall("Kernel32\CloseHandle", "Ptr", hWrite)
    DllCall("Kernel32\CloseHandle", "Ptr", NumGet(pi, 0, "Ptr"))
    DllCall("Kernel32\CloseHandle", "Ptr", NumGet(pi, A_PtrSize, "Ptr"))
    return pid != 0
}

ExtractBundledInterpreter(dest) {
    try {
        FileInstall("AutoHotkey64.exe", dest, 1)
        if (FileExist(dest))
            return true
    }
    src := GetAutoHotkeyInterpreter()
    if (src && FileExist(src)) {
        try {
            FileCopy(src, dest, 1)
            return FileExist(dest) != ""
        }
    }
    return false
}

class VerWriter {
    __New() {
        this.buf := Buffer(16384, 0)
        this.pos := 0
    }
    Align() {
        this.pos := (this.pos + 3) & ~3
    }
    U16(v) {
        NumPut("UShort", v, this.buf, this.pos)
        this.pos += 2
    }
    U32(v) {
        NumPut("UInt", v, this.buf, this.pos)
        this.pos += 4
    }
    Str(text) {
        ; StrPut returns bytes in AutoHotkey v2, so its return value must not be doubled: count the UTF-16 bytes ourselves.
        n := StrLen(text) + 1
        StrPut(text, this.buf.Ptr + this.pos, n, "UTF-16")
        this.pos += n * 2
    }
    Begin(key, valueLen, wType) {
        this.Align()
        start := this.pos
        this.pos += 2
        this.U16(valueLen)
        this.U16(wType)
        this.Str(key)
        this.Align()
        return start
    }
    End(start) {
        NumPut("UShort", this.pos - start, this.buf, start)
    }
}

BuildVersionResource(title, exeName) {
    title := Trim(RegExReplace(title, "[\r\n]+", " "))
    if (title = "")
        title := exeName
    w := VerWriter()
    root := w.Begin("VS_VERSION_INFO", 52, 0)
    for dw in [0xFEEF04BD, 0x00010000, 0x00010000, 0, 0x00010000, 0, 0x3F, 0, 0x00040004, 1, 0, 0, 0]
        w.U32(dw)
    sfi := w.Begin("StringFileInfo", 0, 1)
    st := w.Begin("040904B0", 0, 1)
    for pair in [["FileDescription", title], ["FileVersion", "1.0.0.0"], ["InternalName", exeName], ["LegalCopyright", "Ragnious"], ["OriginalFilename", exeName], ["ProductName", title], ["ProductVersion", "1.0.0.0"]] {
        sb := w.Begin(pair[1], StrLen(pair[2]) + 1, 1)
        w.Str(pair[2])
        w.End(sb)
    }
    w.End(st)
    w.End(sfi)
    vfi := w.Begin("VarFileInfo", 0, 1)
    vb := w.Begin("Translation", 4, 0)
    w.U32(0x04B00409)
    w.End(vb)
    w.End(vfi)
    w.End(root)
    out := Buffer(w.pos, 0)
    DllCall("Kernel32\RtlMoveMemory", "Ptr", out, "Ptr", w.buf, "UPtr", w.pos)
    return out
}

EnumVersionLangCb(list, hMod, type, name, lang, lParam) {
    list.Push(lang & 0xFFFF)
    return 1
}

EnumStripLangCb(ctx, type, name, hMod, enumType, enumName, lang, lParam) {
    savedName := name <= 0xFFFF ? name : StrGet(name, "UTF-16")
    ctx.resources.Push([type, savedName, lang & 0xFFFF])
    return 1
}

EnumStripNameCb(ctx, hMod, type, name, lParam) {
    langCb := CallbackCreate(EnumStripLangCb.Bind(ctx, type, name), "F", 5)
    DllCall("Kernel32\EnumResourceLanguagesW", "Ptr", hMod, "Ptr", type, "Ptr", name, "Ptr", langCb, "Ptr", 0, "Int")
    CallbackFree(langCb)
    return 1
}

RemoveExeResourceTypes(path, typeIds) {
    ctx := {resources: []}
    hMod := DllCall("Kernel32\LoadLibraryExW", "WStr", path, "Ptr", 0, "UInt", 0x2, "Ptr")
    if (!hMod)
        return "resource read failed (Win32 " A_LastError ")"
    for resourceType in typeIds {
        nameCb := CallbackCreate(EnumStripNameCb.Bind(ctx), "F", 4)
        DllCall("Kernel32\EnumResourceNamesW", "Ptr", hMod, "Ptr", resourceType, "Ptr", nameCb, "Ptr", 0, "Int")
        CallbackFree(nameCb)
    }
    DllCall("Kernel32\FreeLibrary", "Ptr", hMod)
    if (ctx.resources.Length = 0)
        return true
    hUpd := DllCall("Kernel32\BeginUpdateResourceW", "WStr", path, "Int", 0, "Ptr")
    if (!hUpd)
        return "resource update could not start (Win32 " A_LastError ")"
    ok := true
    for item in ctx.resources {
        namePtr := Type(item[2]) = "Integer" ? item[2] : StrPtr(item[2])
        if (!DllCall("Kernel32\UpdateResourceW", "Ptr", hUpd, "Ptr", item[1], "Ptr", namePtr, "UShort", item[3], "Ptr", 0, "UInt", 0, "Int")) {
            ok := false
            err := A_LastError
            break
        }
    }
    endOk := DllCall("Kernel32\EndUpdateResourceW", "Ptr", hUpd, "Int", ok ? 0 : 1, "Int")
    if (!ok)
        return "Windows rejected a resource deletion (Win32 " err ")"
    if (!endOk)
        return "resource update could not be saved (Win32 " A_LastError ")"
    verify := {types: Map(), found: false}
    for id in typeIds
        verify.types[id] := true
    hMod := DllCall("Kernel32\LoadLibraryExW", "WStr", path, "Ptr", 0, "UInt", 0x2, "Ptr")
    if (!hMod)
        return "resource verification could not reopen the executable (Win32 " A_LastError ")"
    verifyCb := CallbackCreate(VerifyExeResourceTypeCb.Bind(verify), "F", 3)
    DllCall("Kernel32\EnumResourceTypesW", "Ptr", hMod, "Ptr", verifyCb, "Ptr", 0, "Int")
    CallbackFree(verifyCb)
    DllCall("Kernel32\FreeLibrary", "Ptr", hMod)
    return verify.found ? "one or more resource types remain after updating" : true
}

VerifyExeResourceTypeCb(verify, hMod, type, lParam) {
    if (type <= 0xFFFF && verify.types.Has(type))
        verify.found := true
    return verify.found ? 0 : 1
}
; Rewrites the RT_VERSION resource of an exe that is not running yet, so Task Manager shows `title` as its name from
; the moment the process exists. Every existing language entry is removed first, otherwise Windows can pick the old
; one (the stock interpreter's) over ours and Task Manager keeps showing the exe name until the window title appears.
SetExeVersionInfo(path, title, exeName) {
    data := BuildVersionResource(title, exeName)
    langs := []
    hMod := DllCall("Kernel32\LoadLibraryExW", "WStr", path, "Ptr", 0, "UInt", 0x2, "Ptr")
    if (hMod) {
        cb := CallbackCreate(EnumVersionLangCb.Bind(langs), "F", 5)
        DllCall("Kernel32\EnumResourceLanguagesW", "Ptr", hMod, "Ptr", 16, "Ptr", 1, "Ptr", cb, "Ptr", 0, "Int")
        CallbackFree(cb)
        DllCall("Kernel32\FreeLibrary", "Ptr", hMod)
    }
    Loop 4 {
        hUpd := DllCall("Kernel32\BeginUpdateResourceW", "WStr", path, "Int", 0, "Ptr")
        if (hUpd) {
            for lang in langs
                if (lang != 0x0409)
                    DllCall("Kernel32\UpdateResourceW", "Ptr", hUpd, "Ptr", 16, "Ptr", 1, "UShort", lang, "Ptr", 0, "UInt", 0, "Int")
            ok := DllCall("Kernel32\UpdateResourceW", "Ptr", hUpd, "Ptr", 16, "Ptr", 1, "UShort", 0x0409, "Ptr", data, "UInt", data.Size, "Int")
            endOk := DllCall("Kernel32\EndUpdateResourceW", "Ptr", hUpd, "Int", ok ? 0 : 1, "Int")
            if (endOk && ok)
                return true
        }
        Sleep(50)
    }
    return false
}

; Embeds the complete helper script as the standard AutoHotkey resource (RT_RCDATA, ID 1).
; Its launch-token guard exits silently when the exe is opened manually; the app supplies that token when launching it.
EmbedExeScript(path, script) {
    script := Chr(0xFEFF) script ; UTF-8 BOM keeps embedded non-ASCII titles and labels readable.
    byteCount := StrPut(script, "UTF-8") - 1
    data := Buffer(byteCount, 0)
    StrPut(script, data, "UTF-8")
    hUpd := DllCall("Kernel32\BeginUpdateResourceW", "WStr", path, "Int", 0, "Ptr")
    if (!hUpd)
        return false
    ok := DllCall("Kernel32\UpdateResourceW", "Ptr", hUpd, "Ptr", 10, "Ptr", 1, "UShort", 0x0409, "Ptr", data, "UInt", data.Size, "Int")
    endOk := DllCall("Kernel32\EndUpdateResourceW", "Ptr", hUpd, "Int", ok ? 0 : 1, "Int")
    return ok && endOk
}

; True once the title's icon is in memory/disk cache, or known to have none (the list then shows the "unknown" icon).
; Calling GetGameIconBitmap also queues the download when the icon was never requested.
LaunchIconReady(title) {
    global gdiplusToken
    if (!gdiplusToken)
        return true
    if (GetGameIconBitmap(title))
        return true
    return GameIconIsMissing(title)
}

; Returns a private GDI+ copy (caller disposes it) of the title's icon, or of the "unknown" icon for titles without one.
LaunchIconClone(title) {
    master := GetGameIconBitmap(title)
    if (!master && GameIconIsMissing(title))
        master := GetUnknownIconMaster()
    if (!master)
        return 0
    copy := 0
    DllCall("gdiplus\GdipCloneImage", "Ptr", master, "Ptr*", &copy, "Int")
    return copy
}

EnumResNameCb(list, hMod, type, name, lParam) {
    ; name is either an integer id (IS_INTRESOURCE) or a pointer to a string
    if (name >= 0 && name < 0x10000)
        list.Push(Integer(name))
    else
        list.Push(StrGet(name, "UTF-16"))
    return 1
}

; Scales the (already rounded, 32-bit ARGB) game icon master to s x s, keeping per-pixel alpha.
IconScaledBitmap(master, s) {
    dst := 0, g := 0, ia := 0, ok := false
    mw := 0, mh := 0
    DllCall("gdiplus\GdipGetImageWidth", "Ptr", master, "UInt*", &mw, "Int")
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", master, "UInt*", &mh, "Int")
    if (mw < 1 || mh < 1)
        return 0
    if (DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", s, "Int", s, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &dst, "Int") != 0 || !dst)
        return 0
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", dst, "Ptr*", &g, "Int")
    if (g) {
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", 0x00000000, "Int")
        DllCall("gdiplus\GdipSetCompositingMode", "Ptr", g, "Int", 1, "Int")
        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", g, "Int", 7, "Int")
        DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", g, "Int", 2, "Int")
        DllCall("gdiplus\GdipCreateImageAttributes", "Ptr*", &ia, "Int")
        if (ia)
            DllCall("gdiplus\GdipSetImageAttributesWrapMode", "Ptr", ia, "Int", 3, "UInt", 0, "Int", 0, "Int")
        ok := DllCall("gdiplus\GdipDrawImageRectRect", "Ptr", g, "Ptr", master
            , "Float", 0.0, "Float", 0.0, "Float", s + 0.0, "Float", s + 0.0
            , "Float", 0.0, "Float", 0.0, "Float", mw + 0.0, "Float", mh + 0.0
            , "Int", 2, "Ptr", ia, "Ptr", 0, "Ptr", 0, "Int") = 0
        if (ia)
            DllCall("gdiplus\GdipDisposeImageAttributes", "Ptr", ia, "Int")
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g, "Int")
    }
    if (!ok) {
        DllCall("gdiplus\GdipDisposeImage", "Ptr", dst, "Int")
        return 0
    }
    return dst
}

; Turns an s x s 32-bit ARGB GDI+ bitmap into the bytes of one RT_ICON image (BITMAPINFOHEADER + BGRA rows + AND mask).
IconDibBytes(bmp, s) {
    rect := Buffer(16, 0)
    NumPut("Int", 0, "Int", 0, "Int", s, "Int", s, rect)
    bd := Buffer(A_PtrSize = 8 ? 32 : 24, 0)
    if (DllCall("gdiplus\GdipBitmapLockBits", "Ptr", bmp, "Ptr", rect, "UInt", 1, "Int", 0x26200A, "Ptr", bd, "Int") != 0)
        return 0
    stride := NumGet(bd, 8, "Int")
    scan0 := NumGet(bd, 16, "Ptr")
    maskRow := ((s + 31) >> 5) << 2
    out := Buffer(40 + s * s * 4 + maskRow * s, 0)
    NumPut("UInt", 40, "Int", s, "Int", s * 2, "UShort", 1, "UShort", 32, "UInt", 0, "UInt", s * s * 4, out)
    Loop s {
        y := A_Index - 1
        DllCall("Kernel32\RtlMoveMemory", "Ptr", out.Ptr + 40 + (s - 1 - y) * s * 4, "Ptr", scan0 + y * stride, "UPtr", s * 4)
    }
    DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", bmp, "Ptr", bd, "Int")
    return out
}

; 12 zero-width characters (U+200B / U+200C) that encode a random number: invisible, but different on (almost) every launch.
InvisiblePathTag() {
    tag := ""
    v := Random(0, 0xFFF)
    Loop 12 {
        tag .= Chr((v & 1) ? 0x200C : 0x200B)
        v >>= 1
    }
    return tag
}

; Removes helper folders left behind if the app was closed abnormally (invisible-tag folders and the older ~<id> forms).
; Runs once at startup.
CleanStaleHelperDirs() {
    tagRe := "[" Chr(0x200B) Chr(0x200C) "]{12}$"
    try {
        Loop Files A_AppData "\Ragnious\*", "D" {
            if (RegExMatch(A_LoopFileName, "~[0-9A-F]{1,6}$") || RegExMatch(A_LoopFileName, tagRe))
                try DirDelete(A_LoopFileFullPath, true)
        }
    }
    try FileDelete(A_AppData "\Ragnious\icon_patch.log")
}

; True when the exe on disk now holds an icon group of the expected size under that name/language.
IconGroupVerify(path, name, lang, expectSize) {
    hMod := DllCall("Kernel32\LoadLibraryExW", "WStr", path, "Ptr", 0, "UInt", 0x2, "Ptr")
    if (!hMod)
        return false
    nt := IsInteger(name) ? "Ptr" : "WStr"
    h := DllCall("Kernel32\FindResourceExW", "Ptr", hMod, "Ptr", 14, nt, name, "UShort", lang, "Ptr")
    got := h ? DllCall("Kernel32\SizeofResource", "Ptr", hMod, "Ptr", h, "UInt") : 0
    DllCall("Kernel32\FreeLibrary", "Ptr", hMod)
    return got = expectSize
}

; Replaces EVERY icon group of an exe that is not running yet with the game icon (16/24/32/48/64 px).
; Every group is replaced because the shell uses the first group, while the process's own tray/window icons load a
; specific id; leaving any of them untouched is what kept the stock AutoHotkey icon on some titles.
; `master` is the GDI+ bitmap from LaunchIconClone(); it is only read, never disposed here.
SetExeIcon(path, master) {
    global gdiplusToken
    if (!gdiplusToken || !master)
        return false
    images := []
    for s in [16, 24, 32] {   ; 32px is the largest size stored for any title, so this is also the largest useful here
        bmp := IconScaledBitmap(master, s)
        if (!bmp)
            continue
        data := IconDibBytes(bmp, s)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp, "Int")
        if (data)
            images.Push({size: s, data: data})
    }
    if (images.Length = 0) {
        return false
    }

    ; Read the exe's current icon layout. The freshly written exe can be locked for a moment (antivirus scan), so retry.
    groups := [], icons := [], langsOf := Map(), iconLangsOf := Map()
    Loop 8 {
        groups := [], icons := [], langsOf := Map(), iconLangsOf := Map()
        hMod := DllCall("Kernel32\LoadLibraryExW", "WStr", path, "Ptr", 0, "UInt", 0x2, "Ptr")
        if (hMod) {
            cb := CallbackCreate(EnumResNameCb.Bind(groups), "F", 4)
            DllCall("Kernel32\EnumResourceNamesW", "Ptr", hMod, "Ptr", 14, "Ptr", cb, "Ptr", 0, "Int")
            CallbackFree(cb)
            cb := CallbackCreate(EnumResNameCb.Bind(icons), "F", 4)
            DllCall("Kernel32\EnumResourceNamesW", "Ptr", hMod, "Ptr", 3, "Ptr", cb, "Ptr", 0, "Int")
            CallbackFree(cb)
            for g in groups {
                gl := []
                gt := IsInteger(g) ? "Ptr" : "WStr"
                cb := CallbackCreate(EnumVersionLangCb.Bind(gl), "F", 5)
                DllCall("Kernel32\EnumResourceLanguagesW", "Ptr", hMod, "Ptr", 14, gt, g, "Ptr", cb, "Ptr", 0, "Int")
                CallbackFree(cb)
                langsOf[g] := gl
            }
            for ic in icons {
                il := []
                it := IsInteger(ic) ? "Ptr" : "WStr"
                cb := CallbackCreate(EnumVersionLangCb.Bind(il), "F", 5)
                DllCall("Kernel32\EnumResourceLanguagesW", "Ptr", hMod, "Ptr", 3, it, ic, "Ptr", cb, "Ptr", 0, "Int")
                CallbackFree(cb)
                iconLangsOf[ic] := il
            }
            DllCall("Kernel32\FreeLibrary", "Ptr", hMod)
        }
        if (groups.Length)
            break
        Sleep(80)
    }
    ; If the exe could not be read at all, fall back to the interpreter's main icon id (159) and a high free icon id range.
    if (!groups.Length) {
        groups := [159]
        langsOf[159] := [0x0409]
    }
    iconLang := langsOf[groups[1]].Length ? langsOf[groups[1]][1] : 0x0409
    ; The stock RT_ICON images are deleted below (so no AutoHotkey icon data stays inside the exe), which frees ids 1..n.
    nextId := 1

    n := images.Length
    grp := Buffer(6 + 14 * n, 0)
    NumPut("UShort", 0, "UShort", 1, "UShort", n, grp, 0)
    for i, im in images
        NumPut("UChar", im.size, "UChar", im.size, "UChar", 0, "UChar", 0, "UShort", 1, "UShort", 32
            , "UInt", im.data.Size, "UShort", nextId + i - 1, grp, 6 + 14 * (i - 1))

    Loop 8 {
        hUpd := DllCall("Kernel32\BeginUpdateResourceW", "WStr", path, "Int", 0, "Ptr")
        if (hUpd) {
            ok := true
            for ic in icons {
                it := IsInteger(ic) ? "Ptr" : "WStr"
                for l in (iconLangsOf.Has(ic) ? iconLangsOf[ic] : [iconLang])
                    DllCall("Kernel32\UpdateResourceW", "Ptr", hUpd, "Ptr", 3, it, ic, "UShort", l, "Ptr", 0, "UInt", 0, "Int")
            }
            for i, im in images
                if (!DllCall("Kernel32\UpdateResourceW", "Ptr", hUpd, "Ptr", 3, "Ptr", nextId + i - 1, "UShort", iconLang, "Ptr", im.data, "UInt", im.data.Size, "Int"))
                    ok := false
            for g in groups {
                gt := IsInteger(g) ? "Ptr" : "WStr"
                gl := langsOf[g]
                lg := gl.Length ? gl[1] : iconLang
                for l in gl
                    if (l != lg)
                        DllCall("Kernel32\UpdateResourceW", "Ptr", hUpd, "Ptr", 14, gt, g, "UShort", l, "Ptr", 0, "UInt", 0, "Int")
                if (!DllCall("Kernel32\UpdateResourceW", "Ptr", hUpd, "Ptr", 14, gt, g, "UShort", lg, "Ptr", grp, "UInt", grp.Size, "Int"))
                    ok := false
            }
            endOk := DllCall("Kernel32\EndUpdateResourceW", "Ptr", hUpd, "Int", ok ? 0 : 1, "Int")
            if (ok && endOk) {
                g1 := groups[1]
                gl1 := langsOf[g1]
                if (IconGroupVerify(path, g1, gl1.Length ? gl1[1] : iconLang, grp.Size)) {
                    ; Tell the shell the file changed so it doesn't keep showing an icon it cached for this same path earlier.
                    SplitPath(path, , &exeDir)
                    DllCall("Shell32\SHChangeNotify", "Int", 0x00002000, "UInt", 0x1005, "WStr", path, "Ptr", 0)
                    DllCall("Shell32\SHChangeNotify", "Int", 0x00001000, "UInt", 0x1005, "WStr", exeDir, "Ptr", 0)
                    return true
                }
            }
        }
        Sleep(100)
    }
    return false
}

BufferToBase64(buf) {
    if (!IsObject(buf) || buf.Size < 1)
        return ""
    n := 0
    if (!DllCall("Crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", buf.Size, "UInt", 0x40000001, "Ptr", 0, "UInt*", &n, "Int") || n < 1)
        return ""
    out := Buffer(n * 2, 0)
    if (!DllCall("Crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", buf.Size, "UInt", 0x40000001, "Ptr", out, "UInt*", &n, "Int"))
        return ""
    return StrGet(out, n, "UTF-16")
}

AssignToKillJob(pid) {
    static job := 0
    if (!pid)
        return false
    if (!job) {
        job := DllCall("Kernel32\CreateJobObjectW", "Ptr", 0, "Ptr", 0, "Ptr")
        if (!job)
            return false
        info := Buffer(A_PtrSize = 8 ? 144 : 112, 0)
        NumPut("UInt", 0x2000, info, 16)
        if (!DllCall("Kernel32\SetInformationJobObject", "Ptr", job, "Int", 9, "Ptr", info, "UInt", info.Size, "Int")) {
            DllCall("Kernel32\CloseHandle", "Ptr", job)
            job := 0
            return false
        }
    }
    hProc := DllCall("Kernel32\OpenProcess", "UInt", 0x0101, "Int", 0, "UInt", pid, "Ptr")
    if (!hProc)
        return false
    ok := DllCall("Kernel32\AssignProcessToJobObject", "Ptr", job, "Ptr", hProc, "Int")
    DllCall("Kernel32\CloseHandle", "Ptr", hProc)
    return ok
}

KillHelperProcess() {
    global targetPid
    pid := targetPid
    if (!pid || !ProcessExist(pid))
        return
    prev := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try {
        hwnd := WinExist("ahk_class AutoHotkey ahk_pid " pid)
        if (hwnd)
            PostMessage(0x0111, 65405, 0, , "ahk_id " hwnd)
    }
    DetectHiddenWindows(prev)
    try ProcessWaitClose(pid, 0.3)
    if (ProcessExist(pid)) {
        try ProcessClose(pid)
        try ProcessWaitClose(pid, 2)
    }
}

PostHelperExit() {
    global targetPid
    pid := targetPid
    if (!pid || !ProcessExist(pid))
        return
    prev := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try {
        hwnd := WinExist("ahk_class AutoHotkey ahk_pid " pid)
        if (hwnd)
            PostMessage(0x0111, 65405, 0, , "ahk_id " hwnd)
    }
    DetectHiddenWindows(prev)
}

; Background cleanup after Stop. Shares helperThreadBusy with RunHelperLaunch so the two never overlap, and is
; dropped if a newer Start/Stop bumped helperLaunchId (that launch cleans up first thing on its own).
QueueHelperTeardown() {
    global helperLaunchId
    SetTimer(HelperTeardownTick.Bind(helperLaunchId, A_TickCount), -1)
}

HelperTeardownTick(gen, queuedAt) {
    global helperLaunchId, helperThreadBusy, isExiting
    if (isExiting || gen != helperLaunchId)
        return
    if (helperThreadBusy && A_TickCount - queuedAt < 8000) {
        SetTimer(HelperTeardownTick.Bind(gen, queuedAt), -25)
        return
    }
    helperThreadBusy := true
    try {
        StopTargetProcess()
    } finally {
        helperThreadBusy := false
    }
}

StopTargetProcess() {
    try KillHelperProcess()
    try StopDiscordRichPresence()
    try CleanupHelperFiles()
}

CleanupHelperFiles() {
    global targetPid, tempExePath, tempScriptPath, tempWorkDir
    try KillHelperProcess()
    ; the per-launch parent folder (~<id>) that holds the title folder
    uniqRoot := ""
    try {
        if (tempWorkDir) {
            SplitPath(tempWorkDir, , &parentDir)
            SplitPath(parentDir, &parentName)
            if (RegExMatch(parentName, "^~[0-9A-F]{1,6}$"))
                uniqRoot := parentDir
        }
    }
    Loop 10 {
        try {
            if (tempExePath && FileExist(tempExePath))
                FileDelete(tempExePath)
        }
        try {
            if (tempScriptPath && FileExist(tempScriptPath)) {
                try FileSetAttrib("-HS", tempScriptPath)
                FileDelete(tempScriptPath)
            }
        }
        try {
            if (tempWorkDir && DirExist(tempWorkDir))
                DirDelete(tempWorkDir, true)
        }
        try {
            if (uniqRoot != "" && DirExist(uniqRoot))
                DirDelete(uniqRoot, true)
        }
        if (!(tempExePath && FileExist(tempExePath)) && !(tempWorkDir && DirExist(tempWorkDir)) && !(uniqRoot != "" && DirExist(uniqRoot)))
            break
        Sleep(100)
    }
    targetPid := 0, tempExePath := "", tempScriptPath := "", tempWorkDir := ""
}

; Safety net: UI says "running" (Stop button) but nothing is launching, connecting or alive. Reset it after ~3 s.
GhostRunningCheck() {
    global isRunning, helperLaunching, helperThreadBusy, rpcConnecting, targetPid, rpcPipe, toggleRunning, actionLocked
    global riskViewActive, riskViewBusy, connLost, stopInProgress, activeProcessName, lastHover
    static ghostTicks := 0
    if (!isRunning || helperLaunching || helperThreadBusy || rpcConnecting || targetPid || rpcPipe || toggleRunning || actionLocked
        || riskViewActive || riskViewBusy || connLost || stopInProgress) {
        ghostTicks := 0
        return false
    }
    ghostTicks += 1
    if (ghostTicks < 3)
        return false
    ghostTicks := 0
    stoppedName := activeProcessName != "" ? activeProcessName : "Process"
    isRunning := false
    SetActionLabel("Start")
    SetActionColor("208A4E")
    RepaintActionButtonNoErase(), lastHover := -1
    SetStatus("Inactive: '" stoppedName "' stopped unexpectedly. Press Start to run it again.", "stopped")
    UpdateButtonHover()
    return true
}

MonitorProcess(*) {
    global isRunning, targetPid, activeProcessName, isExiting, rpcPipe, stopInProgress, helperThreadBusy
    if (isExiting || !isRunning || stopInProgress || helperThreadBusy)
        return
    if (GhostRunningCheck())
        return
    if ((targetPid && !ProcessExist(targetPid)) || (rpcPipe && !RpcKeepAlive())) {
        global lastHover
        stoppedName := activeProcessName != "" ? activeProcessName : "Process"
        isRunning := false
        SetActionLabel("Start")
        SetActionColor("208A4E")
        RepaintActionButtonNoErase(), lastHover := -1
        QueueHelperTeardown()
        SetStatus("Inactive: '" stoppedName "' stopped unexpectedly. Press Start to run it again.", "stopped")
        UpdateButtonHover()
    }
}

RpcOpenPipe(nonBlocking := false) {
    Loop 10 {
        pipeName := "\\.\pipe\discord-ipc-" (A_Index - 1)
        Loop 2 {
            h := DllCall("CreateFileW", "Str", pipeName, "UInt", 0xC0000000, "UInt", 0, "Ptr", 0, "UInt", 3, "UInt", 0, "Ptr", 0, "Ptr")
            if (h != -1 && h != 0)
                return h
            if (A_LastError = 231 && !nonBlocking)
                DllCall("WaitNamedPipeW", "Str", pipeName, "UInt", 100)
            else
                break
        }
    }
    return 0
}

StopDiscordRichPresence() {
    global rpcPipe, rpcLastStopTick, rpcConnHandle
    if (rpcConnHandle)
        rpcLastStopTick := A_TickCount
    RpcConnAbort()
    if (rpcPipe) {
        rpcLastStopTick := A_TickCount
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
        try RpcWriteFrame(rpcPipe, 2, "{}")
        DllCall("CloseHandle", "Ptr", rpcPipe)
        rpcPipe := 0
        Sleep(15)
    }
}

RpcKeepAlive() {
    global rpcPipe
    if (!rpcPipe)
        return false
    Loop 20 {
        frame := RpcReadFrame(rpcPipe, 0)
        if (!IsObject(frame))
            return (frame = "")
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

WindowResponsive(hwnd) {
    if (!hwnd)
        return false
    if (DllCall("User32\IsHungAppWindow", "Ptr", hwnd, "Int"))
        return false
    result := 0
    return DllCall("User32\SendMessageTimeoutW", "Ptr", hwnd, "UInt", 0, "Ptr", 0, "Ptr", 0, "UInt", 0x2, "UInt", 60, "Ptr*", &result, "Ptr") != 0
}

WaitMainWindowShown(maxMs) {
    global mainGui, animationActive
    t0 := A_TickCount
    while (A_TickCount - t0 < maxMs) {
        if (IsWindowValid(mainGui) && DllCall("User32\IsWindowVisible", "Ptr", mainGui.Hwnd, "Int")
            && !DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int") && !animationActive)
            return
        Sleep(10)
    }
}

ShowExitConfirm() {
    global mainGui, isExiting, activeProcessName, exitDlgOpen, exitDlgBusy, exitDlgActive, exitDlgClosing, exitFollowMain, exitScrim, exitGui, exitInner, exitYes, exitNo, exitPressed
    global exitFadeMode, exitFadeStart, exitKeyHeld, exitKeyName, exitKeyCancel, exitBlockKey, exitLastX, exitLastY, exitOutlineColor, exitRetry
    if (exitDlgActive && !exitDlgBusy && !IsWindowValid(exitGui))
        DestroyExitDialog()
    if (isExiting || exitDlgActive || exitDlgBusy || !IsWindowValid(mainGui))
        return
    startFade := false
    exitDlgBusy := true
    exitDlgActive := true
    exitDlgOpen := false, exitDlgClosing := false, exitFollowMain := false, exitFadeMode := ""
    exitKeyHeld := false, exitKeyName := "", exitKeyCancel := false, exitBlockKey := "", exitPressed := ""
    try {
        CloseProcessSelector()
        if (!DllCall("User32\IsWindowVisible", "Ptr", mainGui.Hwnd, "Int")) {
            RestoreWindow()
            WaitMainWindowShown(450)
        } else if (DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int")) {
            mainGui.Restore()
            WaitMainWindowShown(220)
        }
        Critical("On")
        f := A_ScreenDPI / 96
        WinGetPos(&mx, &my, &mw, &mh, "ahk_id " mainGui.Hwnd)
        exitLastX := mx, exitLastY := my
        W := Round(380 * f), H := Round(212 * f)
        W += Mod(Abs(mw - W), 2), H += Mod(Abs(mh - H), 2)
        dx := mx + (mw - W) // 2, dy := my + (mh - H) // 2
        name := (activeProcessName != "") ? activeProcessName : "The game"
        if (StrLen(name) > 25)
            name := RTrim(SubStr(name, 1, 24)) "…"
        maxLineW := (W - 2) - Round(24 * f)
        if (MeasureTextWidth("'" name "' is still running.", 12, 400, "Segoe UI Semibold") > maxLineW) {
            base := name
            while (StrLen(base) > 1) {
                base := SubStr(base, 1, StrLen(base) - 1)
                name := RTrim(base) "…"
                if (MeasureTextWidth("'" name "' is still running.", 12, 400, "Segoe UI Semibold") <= maxLineW)
                    break
            }
        }
        exitScrim := Gui("-Caption -DPIScale +ToolWindow +E0x80000 +E0x08000000 +Owner" mainGui.Hwnd, "")
        exitScrim.BackColor := "000000"
        DllCall("User32\SetLayeredWindowAttributes", "Ptr", exitScrim.Hwnd, "UInt", 0, "UChar", 0, "UInt", 2, "Int")
        exitScrim.Show(Format("NA x{} y{} w{} h{}", mx, my, mw, mh))
        ApplyRoundedCorners(exitScrim, 29)
        exitGui := Gui("-Caption -DPIScale +ToolWindow +E0x80000 +E0x08000000 +Owner" mainGui.Hwnd, "")
        exitGui.BackColor := exitOutlineColor
        DllCall("User32\SetLayeredWindowAttributes", "Ptr", exitGui.Hwnd, "UInt", 0, "UChar", 0, "UInt", 2, "Int")
        exitGui.Show(Format("NA x{} y{} w{} h{}", dx, dy, W, H))
        ApplyRoundedCorners(exitGui, Round(26 * f))
        DllCall("User32\SetWindowPos", "Ptr", exitScrim.Hwnd, "Ptr", exitGui.Hwnd, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")
        exitInner := Gui("-Caption -Border -DPIScale +0x40000000", "")
        exitInner.Opt("+Parent" exitGui.Hwnd)
        exitInner.BackColor := "000000"
        exitInner.Show(Format("NA x1 y1 w{} h{}", W - 2, H - 2))
        ApplyRoundedCorners(exitInner, Round(26 * f) - 2)
        iw := W - 2
        title := exitInner.Add("Text", Format("x0 y{} w{} h{} Center Background000000 cFFFFFF", Round(28 * f), iw, Round(36 * f)), "Exit")
        title.SetFont("s18 Bold", "Segoe UI")
        msg := exitInner.Add("Text", Format("x{} y{} w{} h{} Center +0x80 Background000000 cA0A0A0", Round(12 * f), Round(72 * f), iw - Round(24 * f), Round(56 * f)), "'" name "' is still running.`nExiting will stop it.")
        msg.SetFont("s12 Norm", "Segoe UI Semibold")
        bw := Round(154 * f), bh := Round(46 * f), gap := Round(16 * f)
        bx := (iw - (bw * 2 + gap)) // 2, by := Round(140 * f)
        exitYes := MakeRiskButton("exitYes", exitInner, "Exit", bx / f, by / f, bw / f, bh / f, exitYesBtnFontSize, exitYesBtnNormal, exitYesBtnHover, exitYesBtnPressed, exitYesBtnRadius, exitYesBtnPressScale, exitYesBtnPressMs)
        exitNo := MakeRiskButton("exitNo", exitInner, "Stay", (bx + bw + gap) / f, by / f, bw / f, bh / f, exitNoBtnFontSize, exitNoBtnNormal, exitNoBtnHover, exitNoBtnPressed, exitNoBtnRadius, exitNoBtnPressScale, exitNoBtnPressMs)
        exitPressed := ""
        ExitDlgSetAlpha(1)
        DllCall("User32\RedrawWindow", "Ptr", exitGui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0185, "Int")
        PrimeExitDialogButtons()
        exitFadeMode := "in"
        exitFadeStart := A_TickCount
        exitRetry := 0
        startFade := true
    } catch as err {
        SetTimer(ExitDlgFadeTick, 0)
        DestroyExitDialog()
        if (exitRetry < 2) {
            exitRetry += 1
            SetTimer(ShowExitConfirm, -80)
        }
    } finally {
        Critical("Off")
        exitDlgBusy := false
    }
    if (startFade) {
        SetTimer(ExitDlgFadeInStart, -1)
        SetTimer(ExitDlgWatchdog, 700)
    }
}

ExitDlgFadeInStart(*) => ExitDlgRunFade(true)

ExitDlgFadeOutStart(*) => ExitDlgRunFade(false)

ExitDlgWatchdog(*) {
    global exitDlgActive, exitDlgBusy, exitDlgOpen, exitDlgClosing, exitFollowMain, exitConfirmed, exitClosingTick, exitFadeStart
    global exitFadeDuration, exitGui, riskBtnAnimating, riskAnimTick, isExiting
    if (!exitDlgActive) {
        SetTimer(ExitDlgWatchdog, 0)
        return
    }
    if (exitDlgBusy || exitFadeRunning || exitFollowMain || exitConfirmed || isExiting)
        return
    if (!IsWindowValid(exitGui)) {
        DestroyExitDialog()
        return
    }
    if (exitDlgClosing) {
        if (A_TickCount - exitClosingTick > exitFadeDuration + 1200)
            DestroyExitDialog()
        return
    }
    if (!exitDlgOpen) {
        if (A_TickCount - exitFadeStart > exitFadeDuration + 1200) {
            ExitDlgSetAlpha(255)
            PrimeExitDialogButtons()
            ExitDlgBecomeInteractive()
            ExitDlgGrabFocus()
        }
        return
    }
    SetTimer(ExitDlgTick, 15)
    if (riskBtnAnimating && A_TickCount - riskAnimTick > 1500)
        riskBtnAnimating := false
}

ExitDlgRunFade(fadeIn) {
    Critical("Off")
    global exitFadeFrom, exitFadeDuration, exitDlgOpen, exitDlgClosing, exitDlgActive, exitFollowMain, exitGui, exitFadeMode, isMarqueeActive, marqueeLastTick, exitFadeRunning
    if (isMarqueeActive)
        marqueeLastTick := FrameStamp()
    startMs := NowMs(), duration := exitFadeDuration, from := exitFadeFrom
    exitFadeRunning := true
    try {
        Loop {
            if (!exitDlgActive || !IsWindowValid(exitGui) || exitFollowMain)
                return
            progress := Min((NowMs() - startMs) / duration, 1)
            eased := (progress < 0.5) ? (4 * progress ** 3) : (1 - (-2 * progress + 2) ** 3 / 2)
            ExitDlgSetAlpha(fadeIn ? 255 * eased : from * (1 - eased))
            if (fadeIn) {
                if (exitDlgClosing)
                    return
                if (!exitDlgOpen && progress >= 0.6)
                    ExitDlgBecomeInteractive()
            }
            if (progress >= 1)
                break
            UpdateMarquee()
            if (DllCall("Dwmapi\DwmFlush", "Int") != 0)
                Sleep(8)
            else
                Sleep(-1)
        }
    } catch {
    } finally {
        exitFadeRunning := false
    }
    if (!exitDlgActive || exitFollowMain)
        return
    exitFadeMode := ""
    if (fadeIn) {
        ExitDlgSetAlpha(255)
        PrimeExitDialogButtons()
        ExitDlgGrabFocus()
    } else
        DestroyExitDialog()
}

PrimeExitDialogButtons() {
    global exitYes, exitNo
    for b in [exitYes, exitNo]
        if (IsObject(b))
            RepaintRiskButtonNoErase(b)
}

ExitDlgSetAlpha(a) {
    global exitScrim, exitGui, exitAlphaNow
    a := Max(0, Min(255, Round(a)))
    if (a = exitAlphaNow)
        return
    exitAlphaNow := a
    if (IsWindowValid(exitScrim))
        DllCall("User32\SetLayeredWindowAttributes", "Ptr", exitScrim.Hwnd, "UInt", 0, "UChar", Round(a * 0.68), "UInt", 2, "Int")
    if (IsWindowValid(exitGui))
        DllCall("User32\SetLayeredWindowAttributes", "Ptr", exitGui.Hwnd, "UInt", 0, "UChar", a, "UInt", 2, "Int")
}

ExitDlgFadeTick() {
    Critical("Off")
    global exitFadeMode, exitFadeStart, exitFadeFrom, exitFadeDuration, exitDlgOpen, exitDlgClosing, exitFollowMain
    if (exitFadeMode = "" || exitFollowMain) {
        SetTimer(ExitDlgFadeTick, 0)
        return
    }
    progress := Min((A_TickCount - exitFadeStart) / exitFadeDuration, 1)
    eased := (progress < 0.5) ? (4 * progress ** 3) : (1 - (-2 * progress + 2) ** 3 / 2)
    if (exitFadeMode = "in") {
        ExitDlgSetAlpha(255 * eased)
        if (!exitDlgOpen && !exitDlgClosing && progress >= 0.6)
            ExitDlgBecomeInteractive()
        if (progress >= 1) {
            SetTimer(ExitDlgFadeTick, 0)
            exitFadeMode := ""
            ExitDlgSetAlpha(255)
            PrimeExitDialogButtons()
        }
    } else {
        ExitDlgSetAlpha(exitFadeFrom * (1 - eased))
        if (progress >= 1) {
            SetTimer(ExitDlgFadeTick, 0)
            exitFadeMode := ""
            DestroyExitDialog()
        }
    }
}

ExitDlgBecomeInteractive() {
    global exitDlgOpen, exitDlgClosing, exitBlockKey, exitPrevDown
    if (exitDlgOpen || exitDlgClosing)
        return
    exitBlockKey := (GetKeyState("Enter", "P") || GetKeyState("NumpadEnter", "P")) ? "Enter" : ""
    exitPrevDown := GetKeyState("LButton", "P")
    exitDlgOpen := true
    SetTimer(ExitDlgTick, 15)
}

ExitDlgKeysLive() {
    global exitDlgActive
    if (!exitDlgActive)
        return false
    try {
        fg := DllCall("User32\GetForegroundWindow", "Ptr")
        if (!fg)
            return true
        pid := 0
        DllCall("User32\GetWindowThreadProcessId", "Ptr", fg, "UInt*", &pid, "UInt")
        if (pid = DllCall("Kernel32\GetCurrentProcessId", "UInt"))
            return true
        return StrLower(WinGetProcessName("ahk_id " fg)) = "explorer.exe"
    }
    return false
}

ExitDlgGrabFocus() {
    global mainGui
    static lastTry := 0
    if (A_TickCount - lastTry < 120)
        return
    lastTry := A_TickCount
    if (!IsWindowValid(mainGui) || DllCall("User32\IsIconic", "Ptr", mainGui.Hwnd, "Int"))
        return
    hwnd := mainGui.Hwnd
    try {
        fg := DllCall("User32\GetForegroundWindow", "Ptr")
        if (fg = hwnd)
            return
        if (fg) {
            fgPid := 0
            DllCall("User32\GetWindowThreadProcessId", "Ptr", fg, "UInt*", &fgPid, "UInt")
            if (fgPid != DllCall("Kernel32\GetCurrentProcessId", "UInt") && StrLower(WinGetProcessName("ahk_id " fg)) != "explorer.exe")
                return
        }
        myThread := DllCall("Kernel32\GetCurrentThreadId", "UInt")
        fgThread := fg ? DllCall("User32\GetWindowThreadProcessId", "Ptr", fg, "Ptr", 0, "UInt") : 0
        attached := (fgThread && fgThread != myThread && WindowResponsive(fg)) ? DllCall("User32\AttachThreadInput", "UInt", myThread, "UInt", fgThread, "Int", 1, "Int") : false
        DllCall("User32\BringWindowToTop", "Ptr", hwnd)
        DllCall("User32\SetForegroundWindow", "Ptr", hwnd)
        DllCall("User32\SetFocus", "Ptr", hwnd)
        if (attached)
            DllCall("User32\AttachThreadInput", "UInt", myThread, "UInt", fgThread, "Int", 0)
    }
}

ExitKeyPhysicallyDown(k) {
    if (k = "Enter")
        return GetKeyState("Enter", "P") || GetKeyState("NumpadEnter", "P")
    return GetKeyState(k, "P")
}

ExitKeyDown(k) {
    global exitDlgOpen, exitYes, exitNo, exitPressed, exitKeyHeld, exitKeyName, exitKeyCancel, exitBlockKey, riskBtnAnimating
    if (!exitDlgOpen || !IsObject(exitYes) || !IsObject(exitNo))
        return
    if (exitBlockKey = k)
        return
    if (k = "Escape") {
        if (exitPressed != "") {
            exitKeyCancel := true
            return
        }
        if (exitKeyHeld || riskBtnAnimating)
            return
        ExitDlgAnswer(false)
        return
    }
    if (exitKeyHeld || exitPressed != "" || riskBtnAnimating)
        return
    b := (k = "Enter" || k = "y") ? exitYes : exitNo
    exitKeyHeld := true
    exitKeyName := k
    exitKeyCancel := false
    exitPressed := b
    try {
        SetRiskBtnColor(b, b.pressed)
        AnimateRiskButton(b, true)
    } catch {
        exitKeyHeld := false, exitKeyName := "", exitPressed := ""
    }
}

ExitKeyUp() {
    global exitDlgOpen, exitKeyHeld
    if (!exitDlgOpen || !exitKeyHeld)
        return
    ExitDlgTick()
}

ExitBtnUnder(hwnd) {
    global exitYes, exitNo
    for b in [exitYes, exitNo] {
        if (IsObject(b) && IsWindowValid(b.gui) && (hwnd = b.ctl.Hwnd || hwnd = b.gui.Hwnd))
            return b
    }
    return ""
}

ExitBtnCursorOverNormalSize(b) {
    try {
        WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " b.gui.Hwnd)
        CoordMode("Mouse", "Screen")
        MouseGetPos(&cx, &cy)
        return cx >= gx && cx < gx + gw && cy >= gy && cy < gy + gh
    }
    return false
}

ExitDlgTick() {
    Critical("Off")
    global exitDlgOpen, exitYes, exitNo, exitPressed, exitKeyHeld, exitKeyName, exitKeyCancel, exitBlockKey, exitPrevDown, riskBtnAnimating, riskAnimTick
    if (!exitDlgOpen || !IsObject(exitYes) || !IsObject(exitNo) || !IsWindowValid(exitYes.gui) || !IsWindowValid(exitNo.gui))
        return
    try {
        ExitDlgKeepTogether()
        if (exitBlockKey != "" && !ExitKeyPhysicallyDown(exitBlockKey))
            exitBlockKey := ""
        if (riskBtnAnimating && A_TickCount - riskAnimTick > 2500)
            riskBtnAnimating := false
        if (riskBtnAnimating)
            return
        down := GetKeyState("LButton", "P")
        edge := down && !exitPrevDown
        exitPrevDown := down
        MouseGetPos(,,, &hovered, 2)
        over := ExitBtnUnder(hovered)
        viaKey := false
        if (exitKeyCancel) {
            exitKeyCancel := false
            if (exitPressed != "") {
                b := exitPressed
                if (exitKeyHeld && exitKeyName != "")
                    exitBlockKey := exitKeyName
                exitPressed := "", exitKeyHeld := false, exitKeyName := ""
                SetRiskBtnColor(b, (over = b) ? b.hover : b.normal, false)
                AnimateRiskButton(b, false)
            }
            return
        }
        if (exitKeyHeld) {
            if (ExitKeyPhysicallyDown(exitKeyName))
                return
            exitKeyHeld := false
            viaKey := true
        }
        if (edge && exitPressed = "" && !viaKey && over != "") {
            exitPressed := over
            exitKeyCancel := false
            SetRiskBtnColor(over, over.pressed, false)
            AnimateRiskButton(over, true)
            return
        }
        if (exitPressed != "" && (!down || viaKey)) {
            b := exitPressed
            exitPressed := "", exitKeyName := ""
            isOver := viaKey || (over = b) || ExitBtnCursorOverNormalSize(b)
            SetRiskBtnColor(b, isOver ? b.hover : b.normal, false)
            AnimateRiskButton(b, false, isOver ? ExitDlgAnswer.Bind(b = exitYes) : "")
            return
        }
        for b in [exitYes, exitNo] {
            if (exitPressed = b)
                want := b.pressed
            else
                want := (over = b && exitPressed = "") ? b.hover : b.normal
            SetRiskBtnColor(b, want)
        }
    } catch {
        exitPressed := "", exitKeyHeld := false, exitKeyName := ""
    }
}

ExitDlgKeepTogether() {
    global mainGui, exitScrim, exitGui, exitLastX, exitLastY
    if (!IsWindowValid(exitScrim) || !IsWindowValid(exitGui) || !IsWindowValid(mainGui))
        return
    w := exitGui.Hwnd
    Loop 8 {
        w := DllCall("User32\GetWindow", "Ptr", w, "UInt", 3, "Ptr")
        if (!w)
            break
        if (w = exitScrim.Hwnd) {
            DllCall("User32\SetWindowPos", "Ptr", exitScrim.Hwnd, "Ptr", exitGui.Hwnd, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013, "Int")
            break
        }
    }
    WinGetPos(&mx, &my,,, "ahk_id " mainGui.Hwnd)
    if (mx < -30000 || (mx = exitLastX && my = exitLastY))
        return
    dx := mx - exitLastX, dy := my - exitLastY
    exitLastX := mx, exitLastY := my
    DllCall("User32\SetWindowPos", "Ptr", exitScrim.Hwnd, "Ptr", 0, "Int", mx, "Int", my, "Int", 0, "Int", 0, "UInt", 0x0015, "Int")
    WinGetPos(&cx, &cy,,, "ahk_id " exitGui.Hwnd)
    DllCall("User32\SetWindowPos", "Ptr", exitGui.Hwnd, "Ptr", 0, "Int", cx + dx, "Int", cy + dy, "Int", 0, "Int", 0, "UInt", 0x0015, "Int")
}

ExitDlgOwns(hwnd) {
    global exitDlgActive, exitScrim, exitGui
    if (!exitDlgActive || !hwnd)
        return false
    root := DllCall("User32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    if (!root)
        root := hwnd
    return (IsWindowValid(exitScrim) && root = exitScrim.Hwnd) || (IsWindowValid(exitGui) && root = exitGui.Hwnd)
}

ExitDlgCursor(hwnd) {
    global exitDlgActive, exitDlgOpen
    if (!exitDlgActive)
        return false
    if (exitDlgOpen) {
        MouseGetPos(,,, &c, 2)
        if (ExitBtnUnder(c) != "") {
            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32649, "Ptr"))
            return true
        }
    }
    if (ExitDlgOwns(hwnd)) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32512, "Ptr"))
        return true
    }
    return false
}

ExitDlgAnswer(yes) {
    global exitDlgOpen, exitDlgClosing, exitConfirmed, exitFollowMain, exitFollowCap, exitAlphaNow, exitFadeMode, exitFadeStart, exitFadeFrom
    global exitKeyHeld, exitKeyName, exitKeyCancel, exitPressed, exitClosingTick
    if (!exitDlgOpen || exitDlgClosing)
        return
    exitDlgOpen := false
    exitDlgClosing := true
    exitClosingTick := A_TickCount
    SetTimer(ExitDlgTick, 0)
    SetTimer(ExitDlgFadeTick, 0)
    exitKeyHeld := false, exitKeyName := "", exitKeyCancel := false, exitPressed := ""
    if (yes) {
        exitConfirmed := true
        exitFadeMode := ""
        exitFollowCap := exitAlphaNow
        exitFollowMain := true
        CloseApplication()
        return
    }
    exitFadeFrom := exitAlphaNow
    exitFadeStart := A_TickCount
    exitFadeMode := "out"
    SetTimer(ExitDlgFadeOutStart, -1)
}

DestroyExitDialog() {
    global exitScrim, exitGui, exitInner, exitYes, exitNo, exitPressed, riskBtnRegistry
    global exitDlgOpen, exitDlgClosing, exitDlgActive, exitFollowMain, exitFadeMode, exitAlphaNow, exitKeyHeld, exitKeyName, exitKeyCancel, lastHover
    SetTimer(ExitDlgTick, 0)
    SetTimer(ExitDlgFadeTick, 0)
    SetTimer(ExitDlgWatchdog, 0)
    for b in [exitYes, exitNo] {
        if (IsObject(b)) {
            try riskBtnRegistry.Delete(b.ctl.Hwnd)
            try b.gui.Destroy()
        }
    }
    try exitInner.Destroy()
    try exitGui.Destroy()
    try exitScrim.Destroy()
    exitScrim := "", exitGui := "", exitInner := "", exitYes := "", exitNo := "", exitPressed := ""
    exitDlgOpen := false, exitDlgClosing := false, exitFollowMain := false, exitFadeMode := "", exitAlphaNow := 0
    exitKeyHeld := false, exitKeyName := "", exitKeyCancel := false
    exitDlgActive := false
    lastHover := -1
    RedrawMainOutline()
}
