#include "menu_common.lua"
#include "game.lua"
#include "options.lua"
#include "score.lua"
#include "promo.lua"
#include "slideshow.lua"
#include "ui_helpers.lua"
#include "script/challenge.lua"
#include "components/challenges_view.lua"
#include "components/sandbox_view.lua"
#include "components/expansions_view.lua"
#include "components/mod_viewer.lua"
#include "components/eula.lua"
#include "components/mod_manager.lua"
#include "multiplayer_menu.lua"
#include "multiplayer_browser.lua"
#include "debug.lua"
#include "script/player_characters.lua"

gCustomFolderScale = 0

MainMenu.activationsCount = 0

local gForcedFocus = nil
local gPlayFocus = nil
local disableFocusRestore = false

local notification = ""
gMenuNotificationAlpha = 0.0
local currentSession = nil

gDeploy = nil

function resetAllWindows()
	gOptionsScale = 0
	gSandboxScale = 0
	gMultiplayerScale = 0
	gChallengesScale = 0
	gExpansionsScale =0
	gPlayScale = 0

	gPlayDropdownShowRequest = false
	gPlayDropdownFullyOpened = false
	gPlayDropdownCouldBeFastClosed = false

	gMultiplayerDropdownShowRequest = false
	gMultiplayerDropdownFullyOpened = false
	gMultiplayerDropdownCouldBeFastClosed = false

	gCreateScale = 0

    Ui.runOnceOnDraw(function()
        ChallengesView:init()
        SandboxView:init()
        ExpansionsView:init()
        UiForceFocus(gForcedFocus)

        ModManager.Window:hide()
        ModManager.Window.animator:reset(0)
        ModViewer.MainWindow:hide()
        ModViewer.MainWindow.animator:reset(0)

        Options:Init()
        Slideshow:init()
    end)
end


function init()
	resetAllWindows()

	gDeploy = GetBool("game.deploy")

	handleIntent()

    ModFolderManager:UpdateTree() 
    
    Ui.runOnceOnInit(function()
        -- preload fonts with common sizes
        UiFont("arial.ttf", 27)
        UiFont("regular.ttf", 26)
        UiFont("regular.ttf", 52)
        UiFont("medium.ttf", 26)
        UiFont("medium.ttf", 52)
        UiFont("bold.ttf", 26)
        UiFont("bold.ttf", 52)
    end)
end


-- main menu is considered visible when none of windows is drawn above it
function isMainMenuVisible()
    return gOptionsScale == 0 and
           gSandboxScale == 0 and
           gChallengesScale == 0 and
           gExpansionsScale == 0 and
           gCreateScale == 0 and
           ModViewer.MainWindow.visible == false and
           Promo.Window.visible == false and
           ModManager.Window.visible == false
end


MainMenuButtons = {}
MainMenuButtons.width = 250
MainMenuButtons.height = 48
MainMenuButtons.totalWidth = 820
MainMenuButtons.PlayDropDown = {}
MainMenuButtons.PlayDropDown.contentHeight = 350
MainMenuButtons.MultiplayerDropDown = {}
MainMenuButtons.MultiplayerDropDown.contentHeight = 136

MainMenuButtons.drawGamepadHint = function()
	if not isMainMenuVisible() then
		return
	end

	UiPush()
		local safeCanvas = UiSafeCanvasSize()
		local realCanvas = UiCanvasSize()

		UiPush()
			UiTranslateToScreenBottomEdge(0, -160)
			UiColor(1,1,1)
			UiImage("menu/bottom-gradient.png")
		UiPop()

		UiTranslateToScreenBottomEdge(0, -(realCanvas.h - safeCanvas.h) / 2 - 70)
		UiTranslateToScreenLeftEdge(40, 0)
		UiColor(1, 1, 1, 1)
	UiPop()
end

function mainMenu()
	UiPush()
		local topMenuBackgroundHeight = 152
		local logoOffsetX = 80
		local logoOffsetY = 50
		local isInSession = #currentSession.members > 0
		local isSessionOwner = currentSession.isOwner

		if isInSession and not isSessionOwner and gPlayScale > 0  then
			gPlayScale = 0
		end

		UiAlign("top left")

		UiColor(0,0,0, 0.75)
		UiRect(UiWidth(), topMenuBackgroundHeight)
		UiColor(1,1,1)
		UiPush()
			UiTranslate(logoOffsetX, logoOffsetY)
			UiScale(0.4)
			UiImage("menu/logo.png")
		UiPop()
		UiFont("regular.ttf", 36)

		UiPush()
			UiAlign("middle left")
			UiButtonImageBox("common/box-outline-fill-6.png", 6, 6, 0.96, 0.96, 0.96)
			UiColor(0.96, 0.96, 0.96)

			local buttons = {}
			table.insert(buttons,
				{
					name = "loc@UI_BUTTON_PLAY",
					color = (isInSession and not isSessionOwner) and {0.7, 0.7, 0.7, 0.5} or {1, 1, 1, 1},
					cmd = function()
						if not isInSession or isSessionOwner then
                            gPlayFocus = UiFocusedComponentId()
							SetValue("gMultiplayerScale", 0.0, "easein", 0.25)
							if gPlayScale == 0 then
								SetValue("gPlayScale", 1.0, "easeout", 0.25)
								gPlayDropdownShowRequest = true
								gPlayDropdownCouldBeFastClosed = true
							elseif gPlayDropdownCouldBeFastClosed then
								SetValue("gPlayScale", 0.0, "easein", 0.25)
								gPlayDropdownCouldBeFastClosed = false
							end
						end
					end
				})

			table.insert(buttons,
				{
					name = "loc@UI_BUTTON_MULTIPLAYER",
					color = not isInSession and {1, 1, 1, 1} or {0.7, 0.7, 0.7, 0.5},
					cmd = function()
						if not isInSession then
				            MultiplayerBrowser.MainWindow:show()
						end
						SetValue("gPlayScale", 0.0, "easein", 0.1)
					end
				})

            local chars = ListKeys("savegame.freshcharacters")
            local drawNote = tableAny(
                                chars,
                                function(c)
                                    return GetBool("savegame.freshcharacters." .. c)
                                end)
            table.insert(buttons,
                {
                    name = "loc@UI_BUTTON_CHARACTER",
                    color = { 1, 1, 1, 1 },
                    cmd = function()
                        MainMenu.transitToState(MainMenu.State.Avatar)
						SetValue("gPlayScale", 0.0, "easein", 0.1)
                    end,
                    drawNote = drawNote
                })

			table.insert(buttons,
				{
					name = "loc@UI_BUTTON_OPTIONS",
                    color = { 1, 1, 1, 1 },
					cmd = function()
						SetValue("gOptionsScale", 1.0, "easeout", 0.25)
						SetValue("gPlayScale", 0.0, "easein", 0.25)
						SetValue("gMultiplayerScale", 0.0, "easein", 0.25)
						reloadOptions()
						gForcedFocus = UiFocusedComponentId()
					end
				})

			if IsRunningOnPC() or IsRunningOnMac() then
				table.insert(buttons,
				{
					name = "loc@UI_BUTTON_QUIT",
                    color = { 1, 1, 1, 1 },
					cmd = function()
						Command("game.quit")
						SetValue("gPlayScale", 0.0, "easein", 0.25)
						SetValue("gMultiplayerScale", 0.0, "easein", 0.25)
					end

				})
			end

			local buttonsIndent = 36
			local menuBarOffset = (UiWidth() - #buttons*MainMenuButtons.width - (#buttons-1)*buttonsIndent)/2
			menuBarOffset = menuBarOffset + (#buttons-3)*36

			if IsRunningOnPC() or IsRunningOnMac() then
				menuBarOffset = menuBarOffset + 150
			else
				menuBarOffset =  menuBarOffset + 166
			end
			UiTranslate(menuBarOffset, topMenuBackgroundHeight/2)

			for index = 1,#buttons do
				UiPush()
				if buttons[index].color then
					UiColorFilter(unpack(buttons[index].color))
				end
				UiButtonHoverColor(1,1,0.5,1)
				local button = buttons[index]
				if UiTextButton(button.name, MainMenuButtons.width, MainMenuButtons.height) then
					UiSound("common/click.ogg")
					button.cmd()
				end

                if button.drawNote then
                    UiTranslate(MainMenuButtons.width - 10, -MainMenuButtons.height / 2)
                    Ui.Color(0xD72626)
                    UiCircle(10)
                    UiColor(1,1,1)
                    UiCircleOutline(10, 1)
                end
				UiPop()
				UiTranslate(MainMenuButtons.width + buttonsIndent, 0)
			end
		UiPop()
	UiPop()

    local canRestore = isMainMenuVisible() and (gPlayScale == 1.0 or gPlayScale == 0.0) and (not gPlayDropdownShowRequest) and not disableFocusRestore
    if canRestore then
        if gForcedFocus ~= nil and UiFocusedComponentId() ~= gForcedFocus then
            UiForceFocus(gForcedFocus)
        else
            gForcedFocus = nil
        end
    end

	if gPlayScale > 0 then
		local bw = 230
		local bh = 40
		local bo = 48
		local padding = 25
		local specialIndent = 22
		local bgWidth = 280
		local bgHeight = MainMenuButtons.PlayDropDown.contentHeight / gPlayScale + padding * 2
		UiPush()
			if gPlayScale < 1.0 then
				UiNavSkipUpdate()
				gPlayDropdownFullyOpened = false
			end

			UiButtonHoverColor(1,1,0.5,1)
		 	local playMenuOffset = menuBarOffset - (bgWidth - MainMenuButtons.width) / 2
			UiTranslate(playMenuOffset, topMenuBackgroundHeight + 10)
			UiScale(1, gPlayScale)
			UiColorFilter(1,1,1,gPlayScale)

			if gPlayScale < 0.5 then
				UiColorFilter(1, 1, 1, gPlayScale * 2)
			end

			UiColor(0,0,0,0.75)
			UiFont("regular.ttf", 26)
			UiImageBox("common/box-solid-10.png", bgWidth, bgHeight, 10, 10)
			UiColor(1,1,1)
			UiButtonImageBox("common/box-outline-6.png", 6, 6, 1, 1, 1)

			UiColor(0.96, 0.96, 0.96)
			UiAlign("top left")
			UiTranslate(padding, padding)

			local gId = UiNavGroupBegin()

			local navReleased = wasAnyActionReleased(
				{
					"menu_up",
					"menu_down",
					"menu_left",
					"menu_right"
				})

			if gPlayDropdownFullyOpened then
                if (not UiIsComponentInFocus(gId)) and navReleased then
				    SetValue("gPlayScale", 0.0, "easein", 0.25)
                elseif InputPressed("menu_cancel") then
                    SetValue("gPlayScale", 0.0, "easein", 0.25)
                    gForcedFocus = gPlayFocus
                end
			end

			UiBeginFrame()

			if UiTextButton("loc@UI_BUTTON_CAMPAIGN", bw, bh) then
				gForcedFocus = UiFocusedComponentId()
				disableFocusRestore = true
                UiForceFocus("")
				UiSound("common/click.ogg")
				startHub()
			end
			UiTranslate(0, bo)

			if UiTextButton("loc@UI_BUTTON_SANDBOX", bw, bh) then
                gForcedFocus = UiFocusedComponentId()
                UiForceFocus("")
				UiSound("common/click.ogg")
				openSandboxMenu()
			end
			UiTranslate(0, bo)

			if isInSession then
				UiPush()
				UiColorFilter(0.7, 0.7, 0.7, 0.5)
				if UiTextButton("loc@UI_BUTTON_CHALLENGES", bw, bh) then
				end
				UiPop()
			else
				if UiTextButton("loc@UI_BUTTON_CHALLENGES", bw, bh) then
                    gForcedFocus = UiFocusedComponentId()
                    UiForceFocus("")
                    UiSound("common/click.ogg")
                    openChallengesMenu()
				end
			end
			UiTranslate(0, bo)

			if isInSession then
				UiPush()
				UiColorFilter(0.7, 0.7, 0.7, 0.5)
				if UiTextButton(GetTranslatedStringByKey("UI_BUTTON_EXPANSIONS"), bw, bh) then
				end
				UiPop()
			else
				if UiTextButton(GetTranslatedStringByKey("UI_BUTTON_EXPANSIONS"), bw, bh) then
                    gForcedFocus = UiFocusedComponentId()
                    UiForceFocus("")
                    UiSound("common/click.ogg")
                    openExpansionsMenu()
				end
			end

			UiTranslate(0, bo)
			UiTranslate(0, specialIndent)

			if IsRunningOnPC() or IsRunningOnMac() or GetBool("options.debug.mods") then
				UiPush()
					if not GetBool("promo.available") then
						UiDisableInput()
						UiIgnoreNavigation()
						UiColorFilter(1,1,1,0.5)
					end
					if UiTextButton("loc@UI_BUTTON_FEATURED_MODS", bw, bh) then
						gForcedFocus = UiFocusedComponentId()
                        UiForceFocus("")
						UiSound("common/click.ogg")
						Promo.Window:show()
					end
					if GetBool("savegame.promoupdated") then
						UiPush()
							UiTranslate(bw, 0)
							UiAlign("center middle")
							UiImage("menu/promo-notification.png")
						UiPop()
					end
				UiPop()
				UiTranslate(0, bo)

				if isInSession and not currentSession.modsEnabled then
					UiPush()
						UiColorFilter(0.7, 0.7, 0.7, 0.5)
						if UiTextButton("loc@UI_BUTTON_MOD_MANAGER", bw, bh) then
						end
					UiPop()
				else
					if UiTextButton("loc@UI_BUTTON_MOD_MANAGER", bw, bh) then
						gForcedFocus = UiFocusedComponentId()
						UiForceFocus("")
						UiSound("common/click.ogg")
						openModsMenu()
					end
				end

				UiTranslate(0, bo)

                if UiTextButton("folderhax", bw, bh) then
                    gForcedFocus = UiFocusedComponentId()
                    UiForceFocus("")
                    UiSound("common/click.ogg")
                    SetValue("gCustomFolderScale", 1, "cosine", 0.25)
                    ModFolderManager:UpdateTree() 
                end
				
				UiTranslate(0, bo)

				if isInSession then
					UiPush()
					UiColorFilter(0.7, 0.7, 0.7, 0.5)
					if UiTextButton("loc@UI_BUTTON_MOD_EDITOR", bw, bh) then
					end
					UiPop()
				else
					if UiTextButton("loc@UI_BUTTON_MOD_EDITOR", bw, bh) then
						gForcedFocus = UiFocusedComponentId()
						UiForceFocus("")
						UiSound("common/click.ogg")
						Command("mods.openeditor")
					end
				end
				UiTranslate(0, bo)

				if not isInSession then
					UiPush()
			        UiTranslate(0, specialIndent)
					if UiTextButton("loc@UI_BUTTON_CREDITS", bw, bh) then
						gForcedFocus = UiFocusedComponentId()
						UiForceFocus("")
						UiSound("common/click.ogg")
                        saveAndStartLevel("about", "-", "", "about.xml")
					end
					UiPop()
			    end
			end

            local isRunningOnConsole = IsRunningOnPlaystation() or IsRunningOnXbox()
			if isRunningOnConsole or IsRunningOnIOS() or GetBool("mods.pros_enabled") then
				if UiTextButton("loc@UI_MOD_BROWSER", bw, bh) then
                    if not isRunningOnConsole then
                        Command("mods.refresh")
                    end

					gForcedFocus = UiFocusedComponentId()
					UiForceFocus("")
					UiSound("common/click.ogg")
					ModViewer.MainWindow:show()
				end

				if isRunningOnConsole then
					local modsShown = ListKeys("mods.available")
					for i = 1, #modsShown do
						if not GetBool("mods.available." .. modsShown[i] .. ".shown") then
							UiPush()
								UiTranslate(bw - 5, 7.5)
								UiAlign("center middle")
								UiImage("menu/mod-manager-notification.png")
							UiPop()
							break
						end
					end
				end
			end

			_, MainMenuButtons.PlayDropDown.contentHeight = UiEndFrame()
			UiNavGroupEnd()

			if gPlayScale == 1.0 and gPlayDropdownShowRequest == true then
				gPlayDropdownShowRequest = false
				gPlayDropdownFullyOpened = true
				UiForceFocus(gId)
			end

		UiPop()
	end

	if gMultiplayerScale > 0 then
		local bw = 230
		local bh = 40
		local bo = 48
		local padding = 25
		local bgWidth = 280
		local bgHeight = MainMenuButtons.MultiplayerDropDown.contentHeight / gMultiplayerScale + padding * 2
		UiPush()
			if gMultiplayerScale < 1.0 then
				UiNavSkipUpdate()
				gMultiplayerDropdownFullyOpened = false
			end

			if gMultiplayerScale == 1.0 and InputPressed("menu_cancel") then
				SetValue("gMultiplayerScale", 0.0, "easein", 0.25)
			end

			UiButtonHoverColor(1,1,0.5,1)
		 	local multiplayerMenuOffset = menuBarOffset - (bgWidth - MainMenuButtons.width) / 2 + bgWidth
			UiTranslate(multiplayerMenuOffset, topMenuBackgroundHeight + 10)
			UiScale(1, gMultiplayerScale)
			UiColorFilter(1,1,1,gMultiplayerScale)

			if gMultiplayerScale < 0.5 then
				UiColorFilter(1, 1, 1, gMultiplayerScale * 2)
			end

			UiColor(0,0,0,0.75)
			UiFont("regular.ttf", 26)
			UiImageBox("common/box-solid-10.png", bgWidth, bgHeight, 10, 10)
			UiColor(1,1,1)
			UiButtonImageBox("common/box-outline-6.png", 6, 6, 1, 1, 1)

			UiColor(0.96, 0.96, 0.96)
			UiAlign("top left")
			UiTranslate(padding, padding)

			local gId = UiNavGroupBegin()

			local navReleased = wasAnyActionReleased(
				{
					"menu_up",
					"menu_down",
					"menu_left",
					"menu_right"
				})

			if gMultiplayerDropdownFullyOpened and (not UiIsComponentInFocus(gId)) and navReleased then
				SetValue("gMultiplayerScale", 0.0, "easein", 0.25)
			end

			UiBeginFrame()

			if UiTextButton("Create session", bw, bh) then
				gForcedFocus = UiFocusedComponentId()
				UiSound("common/click.ogg")
			end
			UiTranslate(0, bo)

			_, MainMenuButtons.MultiplayerDropDown.contentHeight = UiEndFrame()
			UiNavGroupEnd()

			if gMultiplayerScale == 1.0 and gMultiplayerDropdownShowRequest == true then
				gMultiplayerDropdownShowRequest = false
				gMultiplayerDropdownFullyOpened = true
				UiForceFocus(gId)
			end

 		UiPop()
 	end

	if isMainMenuVisible() then
		if gForcedFocus ~= nil and UiFocusedComponentId() ~= gForcedFocus then
			UiForceFocus(gForcedFocus)
		else
			gForcedFocus = nil
		end
	end

	if gSandboxScale > 0 then
        UiDrawLater(function()
            UiPush()
                UiBlur(gSandboxScale)
                UiColor(0.7,0.7,0.7, 0.25*gSandboxScale)
                UiRect(UiWidth(), UiHeight())
                if not drawSandbox(gSandboxScale) then
                    SetValue("gSandboxScale", 0, "cosine", 0.25)
                end
            UiPop()
        end)
	end
	if gChallengesScale > 0 then
        UiDrawLater(function()
            UiPush()
                UiBlur(gChallengesScale)
                UiColor(0.7,0.7,0.7, 0.25*gChallengesScale)
                UiRect(UiWidth(), UiHeight())
                if not drawChallenges(gChallengesScale) then
                    SetValue("gChallengesScale", 0, "cosine", 0.25)
                end
            UiPop()
        end)
	end
	if gExpansionsScale > 0 then
        UiDrawLater(function()
    		UiPush()
    			UiBlur(gExpansionsScale)
    			UiColor(0.7,0.7,0.7, 0.25 * gExpansionsScale)
    			UiRect(UiWidth(), UiHeight())
    			UiModalBegin()
    			if not drawExpansions(gExpansionsScale) then
    				SetValue("gExpansionsScale", 0, "cosine", 0.25)
    			end
    			UiModalEnd()
    		UiPop()
        end)
	end
	if gOptionsScale > 0 then
        UiDrawLater(function()
    		UiPush()
    			UiBlur(gOptionsScale)
    			UiColor(0.7,0.7,0.7, 0.25 * gOptionsScale)
    			UiRect(UiWidth(), UiHeight())
    			UiModalBegin()
    			SetBool("game.menu.active", true)

                if not drawOptions(gOptionsScale) and gOptionsScale == 1.0 then
                    SetValue("gOptionsScale", 0, "cosine", 0.25)
                end
    			
    			UiModalEnd()
    		UiPop()
        end)
	end

    if MainMenu.getState() == MainMenu.State.Main then
        local scale = 0.0
        if MultiplayerBrowser.MainWindow.animator then
            scale = MultiplayerBrowser.MainWindow.animator.factor
        end
        if MultiplayerMenu.state == MultiplayerMenuState.PARTY_SCREEN then
            scale = 1.0
        end
        if scale > 0 then
            UiPush()
                UiBlur(scale)
                UiColor(0.7,0.7,0.7, 0.25 * scale)
                UiRect(UiWidth(), UiHeight())
            UiPop()
        end
    end
end


function tick(dt)
    if GetString("savegame.player.character") == "" then
       SetBool("netsession.joindisabled", true)
       MainMenu.interceptStartLevel()
	   if gMultiplayerScale > 0 then
			MainMenu.transitToState(MainMenu.State.Avatar)
	   end
    else
       SetBool("netsession.joindisabled", false)
	end

    MainMenu.updateStates()

	if GetTime() > 0.1 then
		if MainMenu.activationsCount >= 2 then
			PlayMusic("menu-long.ogg")
		else
			PlayMusic("menu.ogg")
		end
	end
end

function drawNotifications()
	local notificationStr = GetString("game.menu.notification")
	if notificationStr ~= "" then
		SetValue("gMenuNotificationAlpha", 1, "linear", 1.0)
		notification = notificationStr
		SetString("game.menu.notification", "")
	end

	if gMenuNotificationAlpha == 1 then
		gMenuNotificationAlpha = gMenuNotificationAlpha - 0.01
		SetValue("gMenuNotificationAlpha", 0, "linear", 1.0)
	end

	UiPush()
		UiTranslateToPositionOnScreen(UiWidth() / 2, UiHeight() / 5)
		UiFont("bold.ttf", 32)
		UiAlign("middle center")
		UiScale(1.0)
		UiColor(0.15, 0.15, 0.15, gMenuNotificationAlpha * 0.5)
		local w, h = UiGetTextSize(notification)
		UiImageBox("common/box-solid-10.png", w + 80, h + 30, 12, 12)
		UiColor(1, 1, 1, gMenuNotificationAlpha)
		UiText(notification)
	UiPop()
end

function checkForSessionEvents()
	local sessionJoinBlocked = GetEvent(NetSessionEventType.JOIN_BLOCKED, 1)
	if sessionJoinBlocked then
		local character = GetString("savegame.player.character")
		if character == "" then
			SetString("game.ui.error.text", "Select a character first")
			MainMenu.transitToState(MainMenu.State.Avatar)
		end
	end

	local sessionEnded = GetEvent(NetSessionEventType.NET_SESSION_ENDED, 1)
	if sessionEnded then
		SetString("game.menu.notification", "Host has ended the session")
	end

	local connectionTimeout = GetEvent(NetSessionEventType.CONNECTION_TIMEOUT, 1)
	if connectionTimeout then
		SetString("game.menu.notification", "Connection timeout has expired")
	end
end


function draw()
    Ui.Init()

    if gOptionsScale > 0 or MainMenu.getState() ~= MainMenu.State.Main then
        UiEnableMenuSync(false)
    else
        UiEnableMenuSync(true)
    end

	currentSession = NetSessionGetCurrent()
	if not MainMenu.canDrawInState(MainMenu.State.Main) then
		return
	end

    local fade = MainMenu.getFadeFactor(MainMenu.State.Main)

	UiMute(fade)
    UiColorFilter(1, 1, 1, fade)

    local window = MainMenu.getVisibleWindow()
    if window then
        window.colorFilter = { 1, 1, 1, fade }
    end

    if fade ~= 1 then
        UiDisableInput()
    end

	local waseulashown = GetBool("savegame.waseulav2shown")
	if not waseulashown and EULA.Window.isClosed and not IsRunningOnPC() and not IsRunningOnApple() then
		EULA.Window:show()
	end

	if ModManager.Window.restoreOnFirstDraw and ModManager.Window.canRestore() then
		ModManager.Window:restore()
	end
	ModManager.Window.restoreOnFirstDraw = false

	UiButtonHoverColor(0.8,0.8,0.8,1)
	if LastInputDevice() == UI_DEVICE_GAMEPAD then
		UiSetCursorState(UI_CURSOR_HIDE_AND_LOCK)
	end

	UiPush()
        UiPush()
            local canvas = UiCanvasSize()
            UiColor(0, 0, 0, 1)
            UiRect(canvas.w, canvas.h)
        UiPop()

        local x0, y0, x1, y1 = UiSafeMargins()
        UiTranslate(x0, y0)
        UiWindow(x1 - x0, y1 - y0, true)

        Slideshow:draw()
        mainMenu()

        if gCustomFolderScale > 0 then
            UiPush()
                UiBlur(gCustomFolderScale)
                UiModalBegin()
                if not ModFolderManager:Draw(gCustomFolderScale) then
                    SetValue("gCustomFolderScale", 0, "cosine", 0.25)
                end
                UiModalEnd()
            UiPop()
        end

        if LastInputDevice() == UI_DEVICE_GAMEPAD then
            MainMenuButtons.drawGamepadHint()
        end
    UiPop()

	if not gDeploy and mainMenuDebug then
		mainMenuDebug()
	end

	UiPush()
		UiIgnoreNavigation()
		local version = GetString("game.version")
		local patch = GetString("game.version.patch")
		if patch ~= "" then
			version = version .. " (" .. patch .. ")"
		end
		UiTranslate(UiWidth()-10, UiHeight()-10)
		UiFont("regular.ttf", 18)
		UiAlign("right")
		UiColor(1,1,1,0.5)
		if UiTextButton(version) then
			Command("game.openurl", "http://teardowngame.com/changelog/?version="..GetString("game.version"))
		end
	UiPop()

	if gCreateScale > 0 and GetBool("game.saveerror") then
		UiDrawLater(
            function()
				UiPush()
    				UiColorFilter(1, 1, 1, gCreateScale)
    				UiFont("bold.ttf", 20)
    				UiTextOutline(0, 0, 0, 1, 0.1)
    				UiColor(1,1,.5)
    				UiAlign("center")
    				UiTranslate(UiCenter(), UiHeight() - 100)
    				UiWordWrap(600)
    				UiTextAlignment("center")
    				UiText("loc@UI_TEXT_TEARDOWN_WAS")
			    UiPop()
			end)
	end

    UiDrawLater(
        function()
            if ModViewer.MainWindow.visible and not ModViewer.MainWindow.requestHide then
                drawLocalUserTag { withBackground = true, offset = {x = 75, y = 1000} }
            else
				drawLocalUserTag { withBackground = true }
                drawLocalUserTag { withBackground = true }
            end
        end)

	drawNotifications()
	checkForSessionEvents()
end


function handleCommand(cmd)
	if cmd == "opendisplayoptions" then
		gOptionsScale = 1
		reloadOptions()
	end
	if cmd == "activate" then
		MainMenu.activationsCount = MainMenu.activationsCount + 1
		SetPresence("main_menu")
		disableFocusRestore = false
	end
	if cmd == "updatemods" then
		ModManager.Window:refresh()
		MultiplayerMenu:refreshSubscribed()
	end
	if cmd == "intent" then
		handleIntent()
	end
	if cmd == "start" then
		SetInt("savegame.startcount", GetInt("savegame.startcount")+1)
		resetActivities()
	end
end


function handleIntent()
    local intent = GetString("options.intent")
    local state = GetString("game.state")
    if intent ~= "" then
        if intent == "campaign" then
            resumeCampaign()
        elseif intent == "challenge_mansion_race" then
            tryStartMission("mansion_race")
        elseif intent == "sandbox" then
            if state ~= "MENU" then
                Menu()
                return
            else
                resetAllWindows()
                openSandboxMenu()
            end
        elseif intent == "challenges" or string.sub(intent, 1, 10) == "challenge_" then
            if state ~= "MENU" then
                Menu()
                return
            else
                resetAllWindows()
                openChallengesMenu()
            end
        elseif string.sub(intent, 1, 8) == "usedmods" or string.sub(intent, 1, 15) == "usedcustomtools" then
            if state ~= "MENU" then
                Menu()
                return
            else
                resetAllWindows()
                openModsMenu()
            end
        elseif string.sub(intent, 1, 3) == "ch_" then
            tryStartChallenge(intent)
        elseif string.sub(intent, -8, -1) == "_sandbox" then
            tryStartSandbox(intent)
        else
            tryStartMission(intent)
        end
        SetString("options.intent", "")
    end
end


function resumeCampaign()
	for id,mission in pairs(gMissions) do
		if GetInt("savegame.mission."..id) > 0 and GetInt("savegame.mission."..id..".score") < mission.required then
			ResumeLevel(id, mission.file, mission.layers, "quicksavecampaign")
			return
		end
	end
	startHub()
end


function tryStartMission(id)
	local suf = string.sub(id, -4, -1)
	if suf == "_opt" then
		id = string.sub(id, 1, -4)
	end
	if gMissions[id] and GetInt("savegame.mission."..id) > 0 then
		saveAndStartLevel(id, gMissions[id].name, "", gMissions[id].file, gMissions[id].layers)
	end
end


function tryStartChallenge(id)
	local stars = string.sub(id, -2, -1)
	if stars == "_1" or stars == "_2" or stars == "_3" or stars == "_4" or stars == "_5" then
		id = string.sub(id, 1, -2)
	end
	if gChallenges[id] and isChallengeUnlocked(id) then
		saveAndStartLevel(id, gChallenges[id].name, "", gChallenges[id].file, gChallenges[id].layers)
	end
end


function tryStartSandbox(id)
	for i=1, #gSandbox do
		if id == gSandbox[i].id then
			saveAndStartLevel(id, gSandbox[i].name, "", gSandbox[i].file, gSandbox[i].layers)
		end
	end
end


function openChallengesMenu()
	ChallengesView:reset()
	SetValue("gChallengesScale", 1, "cosine", 0.25)
end


function openSandboxMenu()
	SandboxView:reset()
	SetValue("gSandboxScale", 1, "cosine", 0.25)
end


function openModsMenu()
	SetValue("gCreateScale", 1, "cosine", 0.25)
	ModManager.Window:show()
end


function openExpansionsMenu()
	ExpansionsView:init()
	SetValue("gExpansionsScale", 1, "cosine", 0.25)
end


function MainMenu.interceptStartLevel()
    if MainMenu.startLevelIntercepted == true then
        return
    end

    local startTransitHandler = nil
    local wrappedRefs =
    {
        ["Command"] = Command,
        ["StartLevel"] = StartLevel
    }

    local logicMixin = function(funcRef, funcArgs)
        if GetString("savegame.player.character") ~= "" then
            for k, v in pairs(wrappedRefs) do
                _G[k] = v
            end

            MainMenu.startLevelIntercepted = false
            funcRef(unpack(funcArgs))
            return
        end

        MainMenu.transitToState(MainMenu.State.Avatar)

        startTransitHandler = function()
            if MainMenu.getState() ~= MainMenu.State.Main then
                return
            end

            if GetString("savegame.player.character") ~= "" then
                MainMenu.setState(MainMenu.State.Undefined)

                for k, v in pairs(wrappedRefs) do
                    _G[k] = v
                end

                MainMenu.startLevelIntercepted = false
                Ui.EventMonitor:unsubscribe("OnMainMenuStateTransitStarted", startTransitHandler)
                funcRef(unpack(funcArgs))
            else
                Ui.EventMonitor:unsubscribe("OnMainMenuStateTransitStarted", startTransitHandler)
            end
        end

        Ui.EventMonitor:subscribe("OnMainMenuStateTransitStarted", startTransitHandler)
    end

    StartLevel = function(...)
        local fArgs = tablePack(...)
        if fArgs[1] == "about" then
            wrappedRefs["StartLevel"](unpack(fArgs))
        else
            logicMixin(wrappedRefs["StartLevel"], fArgs)
        end
        SetBool("game.menu.start_level_intercepted", true)
    end

    Command = function(...)
        local fArgs = tablePack(...)
        if fArgs[1] == "mods.play"
                or fArgs[1] == "mods.openeditor"
		        or fArgs[1] == "mods.edit" then
            logicMixin(wrappedRefs["Command"], fArgs)
        else
            wrappedRefs["Command"](unpack(fArgs))
        end
    end

    MainMenu.startLevelIntercepted = true
end


MainMenu.lastVisibleWindow = nil

Ui.EventMonitor:subscribe(
    "OnMainMenuStateTransitStarted",
    function()
        if MainMenu.getState() ~= MainMenu.State.Main then
            return
        end

        if MainMenu.lastVisibleWindow then
            MainMenu.lastVisibleWindow.visible = true
        end
    end)


Ui.EventMonitor:subscribe(
    "OnMainMenuStateTransitFinished",
    function()
        if MainMenu.getState() == MainMenu.State.Main then
            return
        end

        MainMenu.lastVisibleWindow = MainMenu.getVisibleWindow()
        if MainMenu.lastVisibleWindow then
            MainMenu.lastVisibleWindow.visible = false
        end
    end)


function MainMenu.getVisibleWindow()
    local windows =
    {
        ModViewer.MainWindow,
        Promo.Window,
        ModManager.Window
    }

    local w = tableFirst(windows, function(w) return w.visible end)
    return w
end

-- =========================================================================
-- CUSTOM MOD FOLDER MANAGER (V8 - Added Filtering & Sorting)
-- =========================================================================

gNewFolderScale = 0
gFolderContextScale = 0
gFolderActionContextScale = 0 
gModSelectedScale = 0 

ModFolderManager = {
    modsFolderPath = "options.folders",
    selectedMod = "",
    selectedFolder = "",
    tree = { ["built-in"] = {}, ["subscribed"] = {}, ["localfiles"] = {} },
    uncategorized = { ["built-in"] = {}, ["subscribed"] = {}, ["localfiles"] = {} },
    scroll = { ["built-in"] = 0, ["subscribed"] = 0, ["localfiles"] = 0 },
    
    -- [NEW] State arrays for filtering and sorting
    filter = { ["built-in"] = 0, ["subscribed"] = 0, ["localfiles"] = 0 }, -- 0: All, 1: Global, 2: Content
    sort = { ["built-in"] = 1, ["subscribed"] = 1, ["localfiles"] = 1 },   -- 1: Alphabetical, 2: Recent
    
    newFolderName = "",
    newFolderCategory = "",
    
    searchQuery = "",
    searchFocused = false,

    contextMenuModId = "",
    contextMenuCategory = "",
    contextMenuFolderKey = "",
    contextMenuFolderCategory = "",
    contextPosX = 0,
    contextPosY = 0,
    frameMouseX = 0,
    frameMouseY = 0
}

function ModFolderManager:UpdateTree()
    self.tree = { ["built-in"] = {}, ["subscribed"] = {}, ["localfiles"] = {} }
    self.uncategorized = { ["built-in"] = {}, ["subscribed"] = {}, ["localfiles"] = {} }

    local allMods = ListKeys("mods.available")
    local modsData = {}

    for i = 1, #allMods do
        local id = allMods[i]
        
        -- Pull timestamp for the "Recent" sort
        local subTime = GetInt("mods.available."..id..".subscribetime")
        if subTime == 0 then subTime = GetInt("mods.available."..id..".steamtime") end
        
        local mod = {
            id = id,
            name = GetString("mods.available."..id..".listname"),
            active = GetBool("mods.available."..id..".active"),
            playable = GetBool("mods.available."..id..".playable"),
            override = GetBool("mods.available."..id..".override") and not GetBool("mods.available."..id..".playable"),
            subscribetime = subTime
        }
        
        if string.sub(id, 1, 8) == "builtin-" then table.insert(modsData, {category = "built-in", data = mod})
        elseif string.sub(id, 1, 6) == "steam-" then table.insert(modsData, {category = "subscribed", data = mod})
        elseif string.sub(id, 1, 6) == "local-" then table.insert(modsData, {category = "localfiles", data = mod})
        end
    end

    for _, category in ipairs({"built-in", "subscribed", "localfiles"}) do
        local categoryPath = self.modsFolderPath .. "." .. category
        local folderKeys = ListKeys(categoryPath)
        
        for f = 1, #folderKeys do
            local folderName = folderKeys[f]
            local folder = {
                keyName = folderName,
                name = GetString(categoryPath .. "." .. folderName),
                expanded = GetBool(categoryPath .. "." .. folderName .. ".expanded"),
                mods = {}
            }
            local folderModsPath = categoryPath .. "." .. folderName .. ".mods"
            local mappedModKeys = ListKeys(folderModsPath)
            
            for m = 1, #mappedModKeys do
                local targetId = GetString(folderModsPath .. "." .. mappedModKeys[m])
                for d = 1, #modsData do
                    if modsData[d].data.id == targetId then
                        table.insert(folder.mods, modsData[d].data)
                        modsData[d].mapped = true
                    end
                end
            end
            table.insert(self.tree[category], folder)
        end

        for d = 1, #modsData do
            if modsData[d].category == category and not modsData[d].mapped then
                table.insert(self.uncategorized[category], modsData[d].data)
            end
        end
    end
end

function ModFolderManager:Draw(scale)
    if scale <= 0 then return false end
    local open = true
    
    self.frameMouseX, self.frameMouseY = UiGetMousePos()

    if self.selectedMod ~= "" and gModSelectedScale == 0 then
        SetValue("gModSelectedScale", 1, "cosine", 0.25)
    end

    UiPush()
        local w = 890
        local h = 650 + (gModSelectedScale * 230) 
        UiTranslate(UiCenter(), UiMiddle())
        UiScale(scale)
        UiColorFilter(1, 1, 1, scale)
        UiColor(0, 0, 0, 0.5)
        UiAlign("center middle")
        UiImageBox("common/box-solid-shadow-50.png", w, h, -50, -50)
        UiWindow(w, h)
        UiAlign("left top")
        UiColor(0.96, 0.96, 0.96)

        if (InputPressed("esc") or (not UiIsMouseInRect(UiWidth(), UiHeight()) and InputPressed("lmb"))) 
           and gNewFolderScale == 0 and gFolderContextScale == 0 and gFolderActionContextScale == 0 then
            if self.searchFocused then
                self.searchFocused = false
            else
                open = false
                self.searchQuery = "" 
                self.selectedMod = "" 
                gModSelectedScale = 0 
            end
        end

        UiPush()
            UiFont("bold.ttf", 48)
            UiColor(1, 1, 1)
            UiAlign("center")
            UiTranslate(UiCenter(), 50)
            UiText("MOD FOLDERS")
        UiPop()
        
        UiPush()
            UiTranslate(UiCenter(), 105)
            UiAlign("center middle")
            
            local searchHover = UiIsMouseInRect(400, 36)
            if searchHover and InputPressed("lmb") then
                self.searchFocused = true
            elseif InputPressed("lmb") then
                self.searchFocused = false
            end
            
            if self.searchFocused then
                UiColor(1, 1, 1, 0.2)
            elseif searchHover then
                UiColor(1, 1, 1, 0.15)
            else
                UiColor(1, 1, 1, 0.1)
            end
            UiImageBox("common/box-solid-6.png", 400, 36, 6, 6)

            UiTranslate(-185, 2)
            UiAlign("left middle")
            UiFont("regular.ttf", 20)
            
            local displayText = self.searchQuery
            if self.searchQuery == "" and not self.searchFocused then
                displayText = "Search mods..."
                UiColor(0.5, 0.5, 0.5)
            else
                UiColor(0.95, 0.95, 0.95)
                if self.searchFocused then
                    displayText = displayText .. ((math.floor(GetTime() * 2) % 2 == 0) and "|" or "")
                end
            end
            UiText(displayText)
            
            if self.searchFocused then
                local acceptedChars = "abcdefghijklmnopqrstuvwxyz0123456789_-"
                for i=1, #acceptedChars do
                    local c = acceptedChars:sub(i,i)
                    if InputPressed(c) then 
                        if InputDown("shift") then
                            self.searchQuery = self.searchQuery .. string.upper(c)
                        else
                            self.searchQuery = self.searchQuery .. c 
                        end
                    end
                end
                if InputPressed("backspace") then self.searchQuery = string.sub(self.searchQuery, 1, -2) end
                if InputPressed("space") then self.searchQuery = self.searchQuery .. " " end
            end
        UiPop()

        UiPush()
            UiTranslate(30, 160)
            local categories = {"built-in", "subscribed", "localfiles"}
            local titles = {"Built-In", "Subscribed", "Local Files"}
            
            for i = 1, #categories do
                UiPush()
                    UiTranslate((i-1) * 275, 0)
                    
                    -- Headers & Folders
                    UiPush()
                        UiFont("bold.ttf", 22)
                        UiAlign("left top")
                        UiText(titles[i])
                        
                        UiAlign("right top")
                        UiTranslate(250, 0)
                        UiFont("regular.ttf", 19)
                        UiButtonImageBox("common/box-solid-4.png", 4, 4, 1, 1, 1, 0.1)
                        if UiTextButton("Add folder") and gNewFolderScale == 0 then
                            self.newFolderName = ""
                            self.newFolderCategory = categories[i]
                            SetValue("gNewFolderScale", 1, "bounce", 0.5)
                        end
                    UiPop()

                    -- [NEW] Sort and Filter Menu Row
                    UiPush()
                        UiTranslate(0, 32)
                        UiFont("regular.ttf", 16)
                        UiButtonImageBox("common/box-solid-4.png", 4, 4, 1, 1, 1, 0.1)
                        
                        -- Filter Toggle (All -> Global -> Content)
                        UiPush()
                            local filterNames = {"All", "Global", "Content"}
                            if UiTextButton(filterNames[self.filter[categories[i]] + 1], 120, 24) then
                                self.filter[categories[i]] = (self.filter[categories[i]] + 1) % 3
                                UiSound("common/click.ogg")
                            end
                        UiPop()
                        
                        -- Sort Toggle (A-Z -> Recent)
                        UiPush()
                            UiTranslate(130, 0)
                            local sortNames = {"A-Z", "Recent"}
                            if UiTextButton(sortNames[self.sort[categories[i]]], 120, 24) then
                                self.sort[categories[i]] = (self.sort[categories[i]] % 2) + 1
                                UiSound("common/click.ogg")
                            end
                        UiPop()
                    UiPop()

                    UiTranslate(0, 65)
                    self:DrawCategoryColumn(categories[i], 250, 390)
                UiPop()
            end
        UiPop()
        
        if gModSelectedScale > 0 then
            UiPush()
                UiTranslate(30, 620) 
                UiScale(1, gModSelectedScale)
                
                local mw = 830
                local mh = 200
                UiColor(1, 1, 1, 0.07)
                UiImageBox("common/box-solid-6.png", mw, mh, 6, 6)
                UiWindow(mw, mh)
                
                local modKey = "mods.available." .. self.selectedMod
                local name = GetString(modKey..".name")
                if name == "" then name = "Unknown" end
                local author = GetString(modKey..".author")
                local tags = GetString(modKey..".tags")
                local description = GetString(modKey..".description")
                local timestamp = GetString(modKey..".timestamp")

                UiPush()
                    UiTranslate(30, 35)
                    UiColor(1, 1, 1, 1)
                    UiFont("bold.ttf", 32)
                    UiText(name)
                    
                    UiTranslate(0, 25)
                    UiFont("regular.ttf", 20)
                    
                    if author ~= "" then
                        UiText("By " .. author)
                        UiTranslate(0, 22)
                    end
                    if tags ~= "" then
                        UiText("Tags: " .. tags)
                        UiTranslate(0, 22)
                    end
                    
                    UiTranslate(0, 8)
                    UiColor(0.8, 0.8, 0.8)
                    UiWordWrap(mw - 280) 
                    UiText(description)
                UiPop()
                
                if timestamp ~= "" then
                    UiPush()
                        UiTranslate(30, mh - 25)
                        UiFont("regular.ttf", 16)
                        UiColor(0.5, 0.5, 0.5)
                        UiText("Updated " .. timestamp)
                    UiPop()
                end

                UiPush()
                    UiColor(1, 1, 1, 1) 
                    UiFont("regular.ttf", 24)
                    UiButtonImageBox("common/box-outline-6.png", 6, 6, 1, 1, 1, 0.7)
                    UiAlign("center middle")
                    
                    if not GetBool(modKey..".local") then
                        UiPush()
                            UiTranslate(mw - 130, 40)
                            if UiTextButton("Make local copy", 200, 40) then
                                Command("mods.makelocalcopy", self.selectedMod)
                                Command("mods.refresh")
                                self:UpdateTree()
                            end
                        UiPop()
                    elseif GetBool(modKey..".options") then
                        UiPush()
                            UiTranslate(mw - 130, 40)
                            if UiTextButton("Options", 200, 40) then
                                Command("mods.options", self.selectedMod)
                            end
                        UiPop()
                    end
                    
                    if GetBool(modKey..".playable") then
                        UiPush()
                            UiTranslate(mw - 130, mh - 40)
                            UiPush()
                                UiColor(0.7, 1, 0.8, 0.2)
                                UiImageBox("common/box-solid-6.png", 200, 40, 6, 6)
                            UiPop()
                            if UiTextButton("Play", 200, 40) then
                                Command("mods.play", self.selectedMod)
                            end
                        UiPop()
                    elseif GetBool(modKey..".override") then
                        UiPush()
                            UiTranslate(mw - 130, mh - 40)
                            if GetBool(modKey..".active") then
                                if UiTextButton("Enabled", 200, 40) then
                                    Command("mods.deactivate", self.selectedMod)
                                    Command("mods.refresh")
                                    self:UpdateTree()
                                end
                                UiColor(1, 1, 0.5)
                                UiTranslate(-60, 0)
                                UiImage("menu/mod-active.png")
                            else
                                if UiTextButton("Disabled", 200, 40) then
                                    Command("mods.activate", self.selectedMod)
                                    Command("mods.refresh")
                                    self:UpdateTree()
                                end
                                UiTranslate(-60, 0)
                                UiImage("menu/mod-inactive.png")
                            end
                        UiPop()
                    end
                UiPop()
            UiPop()
        end
        
    UiPop()
    
    self:DrawNewFolderDialog()
    self:DrawContextMenu()
    self:DrawFolderContextMenu()
    
    return open
end

function ModFolderManager:DrawCategoryColumn(category, w, h)
    local query = string.lower(self.searchQuery)
    local isSearching = query ~= ""
    local catFilter = self.filter[category]
    local catSort = self.sort[category]

    -- [NEW] Internal filter function
    local function passFilter(mod)
        if catFilter == 1 and not mod.override then return false end
        if catFilter == 2 and not mod.playable then return false end
        return true
    end

    local visibleFolders = {}
    for f = 1, #self.tree[category] do
        local folder = self.tree[category][f]
        local vMods = {}
        for m = 1, #folder.mods do
            local mod = folder.mods[m]
            if passFilter(mod) and (not isSearching or string.find(string.lower(mod.name), query, 1, true)) then
                table.insert(vMods, mod)
            end
        end
        
        if #vMods > 0 then
            -- Apply sorting to this folder's matched mods
            if catSort == 1 then
                table.sort(vMods, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
            else
                table.sort(vMods, function(a, b) return a.subscribetime > b.subscribetime end)
            end
            table.insert(visibleFolders, { folder = folder, vMods = vMods, forceExpand = isSearching })
        elseif not isSearching then
            -- Retain empty folders only if we aren't currently searching
            table.insert(visibleFolders, { folder = folder, vMods = vMods, forceExpand = false })
        end
    end

    local vUncat = {}
    for m = 1, #self.uncategorized[category] do
        local mod = self.uncategorized[category][m]
        if passFilter(mod) and (not isSearching or string.find(string.lower(mod.name), query, 1, true)) then
            table.insert(vUncat, mod)
        end
    end
    
    -- Apply sorting to uncategorized mods
    if catSort == 1 then
        table.sort(vUncat, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
    else
        table.sort(vUncat, function(a, b) return a.subscribetime > b.subscribetime end)
    end

    UiPush()
        UiColor(1, 1, 1, 0.07)
        UiImageBox("common/box-solid-6.png", w, h, 6, 6)

        local contentHeight = 10 
        for f = 1, #visibleFolders do
            contentHeight = contentHeight + 22
            local isExpanded = visibleFolders[f].forceExpand or visibleFolders[f].folder.expanded
            if isExpanded then
                contentHeight = contentHeight + (#visibleFolders[f].vMods * 22)
            end
        end
        if not isSearching or #vUncat > 0 then
            contentHeight = contentHeight + 32 + (#vUncat * 22)
        end
        
        local maxScroll = math.max(0, contentHeight - h)
        if UiIsMouseInRect(w, h) then
            self.scroll[category] = self.scroll[category] + (InputValue("mousewheel") * 30)
        end
        if self.scroll[category] > 0 then self.scroll[category] = 0 end
        if self.scroll[category] < -maxScroll then self.scroll[category] = -maxScroll end

        UiWindow(w, h, true)
        
        UiPush()
            UiTranslate(10, 10 + self.scroll[category])
            UiAlign("left top")
            UiColor(0.95, 0.95, 0.95, 1)
            UiFont("regular.ttf", 20)

            for f = 1, #visibleFolders do
                local folderData = visibleFolders[f]
                local folder = folderData.folder
                local isExpanded = folderData.forceExpand or folder.expanded

                UiPush()
                    local folderPath = self.modsFolderPath .. "." .. category .. "." .. folder.keyName
                    if UiIsMouseInRect(w, 22) then
                        UiColor(1,1,1,0.05) UiRect(w, 22) 
                        if InputPressed("lmb") and gFolderActionContextScale == 0 then
                            folder.expanded = not folder.expanded
                            SetBool(folderPath .. ".expanded", folder.expanded)
                        elseif InputPressed("rmb") and gFolderContextScale == 0 and gNewFolderScale == 0 then
                            self.contextMenuFolderKey = folder.keyName
                            self.contextMenuFolderCategory = category
                            self.contextPosX = self.frameMouseX
                            self.contextPosY = self.frameMouseY
                            SetValue("gFolderActionContextScale", 1, "bounce", 0.3)
                        end
                    end
                    UiColor(1, 1, 0.5)
                    UiText((isExpanded and "[-] " or "[+] ") .. folder.name)
                UiPop()
                UiTranslate(0, 22)

                if isExpanded then
                    for m = 1, #folderData.vMods do
                        self:DrawModItem(folderData.vMods[m], category, w)
                        UiTranslate(0, 22)
                    end
                end
            end

            if not isSearching or #vUncat > 0 then
                UiTranslate(0, 10)
                UiColor(0.6, 0.6, 0.6)
                UiText("Uncategorized")
                UiTranslate(0, 22)
                for m = 1, #vUncat do
                    self:DrawModItem(vUncat[m], category, w)
                    UiTranslate(0, 22)
                end
            end
        UiPop()
    UiPop()
end

function ModFolderManager:DrawModItem(mod, category, w)
    local rowH = 22
    UiPush()
        local isHoveringToggle = mod.override and UiIsMouseInRect(30, rowH)
        local isHoveringRow = UiIsMouseInRect(w - 20, rowH)

        if mod.id == self.selectedMod then
            UiColor(1, 1, 1, 0.2) UiRect(w - 20, rowH)
        elseif isHoveringRow then
            UiColor(1, 1, 1, 0.1) UiRect(w - 20, rowH)
        end
        
        if isHoveringToggle and InputPressed("lmb") and gFolderContextScale == 0 then
            mod.active = not mod.active
            if mod.active then Command("mods.activate", mod.id) else Command("mods.deactivate", mod.id) end
            UiSound("common/click.ogg")
            Command("mods.refresh")
        elseif isHoveringRow and not isHoveringToggle then
            if InputPressed("lmb") and gFolderContextScale == 0 then
                self.selectedMod = mod.id
                UiSound("common/click.ogg")
            elseif InputPressed("rmb") and gNewFolderScale == 0 and gFolderActionContextScale == 0 then
                self.contextMenuModId = mod.id
                self.contextMenuCategory = category
                self.contextPosX = self.frameMouseX
                self.contextPosY = self.frameMouseY
                SetValue("gFolderContextScale", 1, "bounce", 0.3)
            end
        end
        
        if mod.override then
            UiPush()
                UiTranslate(15, rowH / 2)
                UiAlign("center middle")
                UiScale(0.5)
                if mod.active then
                    UiColor(1, 1, 0.5) UiImage("menu/mod-active.png")
                else
                    UiColor(1, 1, 1) UiImage("menu/mod-inactive.png")
                end
            UiPop()
        end

        UiPush()
            UiTranslate(30, rowH / 2)
            UiAlign("left middle")
            UiColor(1, 1, 1)
            UiText(mod.name)
        UiPop()
    UiPop()
end

function ModFolderManager:DrawNewFolderDialog()
    if gNewFolderScale <= 0 then return end
    UiPush()
        UiTranslate(UiCenter(), UiMiddle())
        UiScale(gNewFolderScale)
        UiAlign("center middle")
        UiColor(0,0,0, 0.85)
        UiImageBox("common/box-solid-shadow-50.png", 320, 140, -50, -50)

        UiPush()
            UiTranslate(-140, -40)
            UiAlign("left middle")
            UiColor(1,1,1)
            UiFont("bold.ttf", 20)
            UiText("Name new folder:")
        UiPop()

        UiPush()
            UiTranslate(0, 10)
            UiAlign("center middle")
            UiColor(1, 1, 1, 0.1)
            UiImageBox("common/box-solid-6.png", 280, 40, 6, 6)
        UiPop()

        UiPush()
            UiTranslate(-130, 10)
            UiAlign("left middle")
            UiColor(0.95, 0.95, 0.95)
            UiFont("regular.ttf", 20)
            local blink = (math.floor(GetTime() * 2) % 2 == 0) and "|" or ""
            UiText(self.newFolderName .. blink)
        UiPop()

        local acceptedChars = "abcdefghijklmnopqrstuvwxyz0123456789_-"
        for i=1, #acceptedChars do
            local c = acceptedChars:sub(i,i)
            if InputPressed(c) then 
                if InputDown("shift") then
                    self.newFolderName = self.newFolderName .. string.upper(c)
                else
                    self.newFolderName = self.newFolderName .. c 
                end
            end
        end
        if InputPressed("backspace") then self.newFolderName = string.sub(self.newFolderName, 1, -2) end
        if InputPressed("space") then self.newFolderName = self.newFolderName .. " " end

        if InputPressed("return") and self.newFolderName ~= "" then
            local safeName = string.gsub(self.newFolderName, " ", "")
            local path = self.modsFolderPath .. "." .. self.newFolderCategory .. "." .. safeName
            SetString(path, self.newFolderName)
            gNewFolderScale = 0
            self:UpdateTree() 
        end
        
        if InputPressed("esc") or (not UiIsMouseInRect(320, 140) and InputPressed("lmb")) then
            gNewFolderScale = 0
        end
    UiPop()
end

function ModFolderManager:DrawContextMenu()
    if gFolderContextScale <= 0 then return end
    UiModalBegin()
    UiPush()
        UiTranslate(self.contextPosX, self.contextPosY)
        UiScale(1, gFolderContextScale)
        UiAlign("left top")

        local folders = self.tree[self.contextMenuCategory]
        local h = (#folders + 1) * 22 + 16
        local w = 240 

        UiColor(0.2, 0.2, 0.2, 1)
        UiImageBox("common/box-solid-6.png", w, h, 6, 6)
        UiColor(1, 1, 1)
        UiImageBox("common/box-outline-6.png", w, h, 6, 6, 1)

        if InputPressed("esc") or (not UiIsMouseInRect(w, h) and InputPressed("lmb")) then
            gFolderContextScale = 0
        end

        UiTranslate(12, 8)
        UiFont("regular.ttf", 20)

        if UiIsMouseInRect(w-24, 22) then
            UiColor(1,1,1, 0.2) UiRect(w-24, 22)
            if InputPressed("lmb") then
                self:RemoveModFromFolders(self.contextMenuCategory, self.contextMenuModId)
                self:UpdateTree()
                UiSound("common/click.ogg")
            end
        end
        UiColor(0.6, 0.6, 0.6)
        UiText("[ Clear all folders ]")
        UiTranslate(0, 22)

        for f=1, #folders do
            local folder = folders[f]
            
            local inFolder = false
            for m=1, #folder.mods do
                if folder.mods[m].id == self.contextMenuModId then
                    inFolder = true
                    break
                end
            end

            if UiIsMouseInRect(w-24, 22) then
                UiColor(1,1,1, 0.2) UiRect(w-24, 22)
                if InputPressed("lmb") then
                    local path = self.modsFolderPath .. "." .. self.contextMenuCategory .. "." .. folder.keyName .. ".mods." .. self.contextMenuModId
                    
                    if inFolder then
                        ClearKey(path)
                    else
                        SetString(path, self.contextMenuModId)
                    end
                    
                    self:UpdateTree()
                    UiSound("common/click.ogg")
                end
            end
            
            UiPush()
                UiTranslate(10, 11)
                UiAlign("center middle")
                UiScale(0.4)
                if inFolder then
                    UiColor(1, 1, 0.5) 
                    UiImage("menu/mod-active.png")
                else
                    UiColor(1, 1, 1) 
                    UiImage("menu/mod-inactive.png")
                end
            UiPop()
            
            UiPush()
                UiTranslate(25, 11)
                UiAlign("left middle")
                if inFolder then
                    UiColor(0.96, 0.96, 0.96)
                else
                    UiColor(0.7, 0.7, 0.7)
                end
                UiText(folder.name)
            UiPop()
            
            UiTranslate(0, 22)
        end
    UiPop()
    UiModalEnd()
end

function ModFolderManager:DrawFolderContextMenu()
    if gFolderActionContextScale <= 0 then return end
    UiModalBegin()
    UiPush()
        UiTranslate(self.contextPosX, self.contextPosY)
        UiScale(1, gFolderActionContextScale)
        UiAlign("left top")

        local h = 46
        local w = 180 

        UiColor(0.2, 0.2, 0.2, 1)
        UiImageBox("common/box-solid-6.png", w, h, 6, 6)
        UiColor(1, 1, 1)
        UiImageBox("common/box-outline-6.png", w, h, 6, 6, 1)

        if InputPressed("esc") or (not UiIsMouseInRect(w, h) and InputPressed("lmb")) then
            gFolderActionContextScale = 0
        end

        UiTranslate(12, 12)
        UiFont("regular.ttf", 20)

        if UiIsMouseInRect(w-24, 22) then
            UiColor(1, 0.2, 0.2, 0.2) UiRect(w-24, 22)
            if InputPressed("lmb") then
                local path = self.modsFolderPath .. "." .. self.contextMenuFolderCategory .. "." .. self.contextMenuFolderKey
                ClearKey(path)
                
                gFolderActionContextScale = 0
                self:UpdateTree()
                UiSound("common/click.ogg")
            end
        end
        UiColor(1, 0.4, 0.4)
        UiText("[ Delete Folder ]")
        
    UiPop()
    UiModalEnd()
end

function ModFolderManager:RemoveModFromFolders(category, modId)
    local catPath = self.modsFolderPath .. "." .. category
    local folderKeys = ListKeys(catPath)
    for i=1, #folderKeys do
        local modPath = catPath .. "." .. folderKeys[i] .. ".mods." .. modId
        ClearKey(modPath)
    end
end