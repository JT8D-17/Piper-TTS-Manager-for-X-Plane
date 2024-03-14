--[[ 

Piper TTS Manager
Licensed under the EUPL v1.2: https://eupl.eu/

BK, xxyyzzzz
 ]]
--[[

REQUIREMENTS

]]
if not SUPPORTS_FLOATING_WINDOWS then
	print("Imgui not supported by your FlyWithLua version. Please update to the latest release")
	return
end
--[[ Required modules,DO NOT MODIFY LOAD ORDER! ]]
PTTSM_ffi = require ("ffi")                     -- LuaJIT FFI module
require('lfs_ffi')								-- LuaJIT LuaFileSystem via FFI
require("PiperTTSManager/Lua/PTTSM_Common")     -- Common items
require("PiperTTSManager/Lua/PTTSM_Menu")       -- Menu entries for the plugins menu
require("PiperTTSManager/Lua/PTTSM_Main")       -- PiperTTS manager main module
--[[

VARIABLES (local or global)

]]
PTTSM_ScriptName = "Piper TTS Manager"   -- Name of the script
local PTTSM_Initialized = false       -- Has the script been initialized?
PTTSM_Window_Pos={0,0}                -- Window position x,y
PTTSM_ImguiColors={0x33FFAE00,0xBBFFAE00,0xFFC8C8C8,0xFF0000FF,0xFF19CF17,0xFFB6CDBA,0xFF40aee5} -- Imgui: Control elements passive, control elements active, text, negative, positive, neutral, caution
PTTSM_Menu_ID = nil                   -- ID of the main PTTSM menu
PTTSM_Menu_Index = nil                -- Index of the PTTSM menu in the plugins menu
--[[

INITIALIZATION

]]
local function PTTSM_Main_Init()
    PTTSM_Log_Delete()					-- Delete the old log file
    PTTSM_Log_Write("INIT: Beginning "..PTTSM_ScriptName.." initialization")
	PTTSM_FileRead(PTTSM_SettingsFile,PTTSM_Settings)
    if PTTSM_Get_TableVal(PTTSM_Settings,"WindowIsOpen",0,2) == 1 then PTTSM_Window_Show() end -- If window open flag was true, build the window
    PTTSM_ModuleInit_Main()
	PTTSM_Menu_Init()
    PTTSM_Initialized = true
    if PTTSM_Initialized then print("---> "..PTTSM_ScriptName.." initialized.") PTTSM_Log_Write("INIT: Finished "..PTTSM_ScriptName.." initialization") end
end
--[[

FUNCTIONS

]]
--[[ Show Window ]]
function PTTSM_Window_Show()
	PTTSM_Window = float_wnd_create(PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4), PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,5), 1, true)
	float_wnd_set_position(PTTSM_Window, PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,2), PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,3))
	float_wnd_set_title(PTTSM_Window, PTTSM_ScriptName)
	float_wnd_set_imgui_builder(PTTSM_Window, "PTTSM_Window_Build")
	float_wnd_set_onclose(PTTSM_Window, "PTTSM_Window_Hide")
	PTTSM_Set_TableVal(PTTSM_Settings,"WindowIsOpen",0,2,1)
	--print("Window open: "..PTTSM_Get_TableVal(PTTSM_Settings,"WindowIsOpen",0,2))
	--PTTSM_Log_Write("Window Opening")
    PTTSM_Menu_Watchdog(1)
end
--[[ Hide Window ]]
function PTTSM_Window_Hide()
	if PTTSM_Window then float_wnd_destroy(PTTSM_Window) PTTSM_Window = nil end
	PTTSM_Set_TableVal(PTTSM_Settings,"WindowIsOpen",0,2,0)
	--print("Window open: "..PTTSM_Get_TableVal(PTTSM_Settings,"WindowIsOpen",0,2))
	--PTTSM_Log_Write("Window Closing")
    PTTSM_Menu_Watchdog(1)
end
--[[ Toggle Window ]]
function PTTSM_Window_Toggle()
	if PTTSM_Get_TableVal(PTTSM_Settings,"WindowIsOpen",0,2) == 0 then PTTSM_Window_Show() else PTTSM_Window_Hide(PTTSM_Window) end
end
--[[ 

IMGUI WINDOW ELEMENT

]]
--[[ Imgui window builder ]]
function PTTSM_Window_Build(PTTSM_Window,xpos,ypos)
	PTTSM_Window_Pos={xpos,ypos}
	PTTSM_GetWindowInfo()
	--[[ Window styling ]]
	imgui.PushStyleColor(imgui.constant.Col.Button,PTTSM_ImguiColors[1])
	imgui.PushStyleColor(imgui.constant.Col.ButtonHovered,PTTSM_ImguiColors[2])
	imgui.PushStyleColor(imgui.constant.Col.ButtonActive,PTTSM_ImguiColors[2])
	imgui.PushStyleColor(imgui.constant.Col.Text,PTTSM_ImguiColors[3])
	imgui.PushStyleColor(imgui.constant.Col.TextSelectedBg,PTTSM_ImguiColors[2])
	imgui.PushStyleColor(imgui.constant.Col.FrameBg,PTTSM_ImguiColors[1])
	imgui.PushStyleColor(imgui.constant.Col.FrameBgHovered,PTTSM_ImguiColors[2])
	imgui.PushStyleColor(imgui.constant.Col.FrameBgActive,PTTSM_ImguiColors[2])
	imgui.PushStyleColor(imgui.constant.Col.Header,PTTSM_ImguiColors[1])
	imgui.PushStyleColor(imgui.constant.Col.HeaderActive,PTTSM_ImguiColors[2])
	imgui.PushStyleColor(imgui.constant.Col.HeaderHovered,PTTSM_ImguiColors[2])
	imgui.PushStyleColor(imgui.constant.Col.CheckMark,PTTSM_ImguiColors[3])
    imgui.PushTextWrapPos(PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-30)
    imgui.Dummy((PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-30),10)
	--[[ Window Content ]]
    PTTSM_Win_Main()
	--[[ End Window Styling ]]
    imgui.PopStyleColor(12)
    imgui.PopTextWrapPos()
--[[ End Imgui Window ]]
end
--[[

INITIALIZATION

]]
--[[ Has to run in a 1 second loop to work ]]
function PTTSM_Main_1sec()
    if not PTTSM_Initialized then
        PTTSM_Main_Init()
    else
        PTTSM_Watchdog()
    end
end
do_often("PTTSM_Main_1sec()")
--[[

EXIT

]]
function PTTSM_Exit()
	PTTSM_FileWrite(PTTSM_Settings,PTTSM_SettingsFile,"log")
	PTTSM_Menu_CleanUp()
    PTTSM_Log_Write("SHUTDOWN: Completed.")
end
do_on_exit("PTTSM_Exit()")
--[[

MACROS AND COMMANDS

]]
add_macro("Piper TTS Manager: Toggle Window","PTTSM_Window_Show()","PTTSM_Window_Hide()","deactivate")
create_command("Piper TTS Manager/Window/Toggle","Toggle Window","PTTSM_Window_Toggle()", "", "")
