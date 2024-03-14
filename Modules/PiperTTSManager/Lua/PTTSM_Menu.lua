--[[

Lua module, required by MaryTTSManager.lua
Licensed under the EUPL v1.2: https://eupl.eu/

]]
--[[

MENU LABELS, ITEMS AND ACTIONS

]]
local Menu_Name = "Piper TTS Manager" -- Menu title
local Menu_Items = {" Window","Debug Output"}  -- Menu entries, index starts at 1
--[[ Menu item callbacks ]]
local function Menu_Callback(itemref)
    if itemref == Menu_Items[1] then 
        if PTTSM_Get_TableVal(PTTSM_Settings,"WindowIsOpen",0,2) == 0 then PTTSM_Window_Show()
        elseif PTTSM_Get_TableVal(PTTSM_Settings,"WindowIsOpen",0,2) == 1 then PTTSM_Window_Hide(PTTSM_Window) end
        PTTSM_Menu_Watchdog(1)
    end
    if itemref == Menu_Items[2] then
        if PTTSM_Get_TableVal(PTTSM_Settings,"Debug",0,2) == 0 then PTTSM_Set_TableVal(PTTSM_Settings,"Debug",0,2,1)
        elseif PTTSM_Get_TableVal(PTTSM_Settings,"Debug",0,2) == 1 then PTTSM_Set_TableVal(PTTSM_Settings,"Debug",0,2,0) end
        PTTSM_Menu_Watchdog(2)
    end
end
--[[

INITIALIZATION

]]
local Menu_Indices = {}
for i=1,#Menu_Items do 
    Menu_Indices[i] = 0 
end
--[[

MENU INITALIZATION AND CLEANUP

]]
--[[ Variables for FFI ]]
local Menu_Pointer = PTTSM_ffi.new("const char")
--[[ Menu initialization ]]
function PTTSM_Menu_Init()
    if PTTSM_XPLM ~= nil then
        PTTSM_Menu_Index = PTTSM_XPLM.XPLMAppendMenuItem(PTTSM_XPLM.XPLMFindPluginsMenu(),Menu_Name,PTTSM_ffi.cast("void *","None"),1)
        PTTSM_Menu_ID = PTTSM_XPLM.XPLMCreateMenu(Menu_Name,PTTSM_XPLM.XPLMFindPluginsMenu(),PTTSM_Menu_Index, function(inMenuRef,inItemRef) Menu_Callback(inItemRef) end,PTTSM_ffi.cast("void *",Menu_Pointer))
        for i=1,#Menu_Items do
            if Menu_Items[i] ~= "[Separator]" then
                Menu_Pointer = Menu_Items[i]
                Menu_Indices[i] = PTTSM_XPLM.XPLMAppendMenuItem(PTTSM_Menu_ID,Menu_Items[i],PTTSM_ffi.cast("void *",Menu_Pointer),1)
            else
                PTTSM_XPLM.XPLMAppendMenuSeparator(PTTSM_Menu_ID)
            end
        end
        PTTSM_Menu_Watchdog(1)        -- Watchdog for menu item 1
        PTTSM_Menu_Watchdog(2)        -- Watchdog for menu item 2
        PTTSM_Log_Write("INIT: "..Menu_Name.." menu initialized!")
    end
end
--[[ Menu cleanup upon script reload or session exit ]]
function PTTSM_Menu_CleanUp()
   PTTSM_XPLM.XPLMClearAllMenuItems(PTTSM_Menu_ID)
   PTTSM_XPLM.XPLMDestroyMenu(PTTSM_Menu_ID)
   PTTSM_XPLM.XPLMRemoveMenuItem(PTTSM_XPLM.XPLMFindPluginsMenu(),PTTSM_Menu_Index)
end
--[[

MENU MANIPULATION WRAPPERS

]]
--[[ Menu item name change ]]
local function PTTSM_Menu_ChangeItemPrefix(index,prefix)
    PTTSM_XPLM.XPLMSetMenuItemName(PTTSM_Menu_ID,index-1,prefix.." "..Menu_Items[index],1)
end
--[[ Menu item check status change ]]
function PTTSM_Menu_CheckItem(index,state)
    index = index - 1
    local out = PTTSM_ffi.new("XPLMMenuCheck[1]")
    PTTSM_XPLM.XPLMCheckMenuItemState(PTTSM_Menu_ID,index-1,PTTSM_ffi.cast("XPLMMenuCheck *",out))
    if tonumber(out[0]) == 0 then PTTSM_XPLM.XPLMCheckMenuItem(PTTSM_Menu_ID,index,1) end
    if state == "Activate" and tonumber(out[0]) ~= 2 then PTTSM_XPLM.XPLMCheckMenuItem(PTTSM_Menu_ID,index,2)
    elseif state == "Deactivate" and tonumber(out[0]) ~= 1 then PTTSM_XPLM.XPLMCheckMenuItem(PTTSM_Menu_ID,index,1)
    end
end
--[[ Watchdog to track window state changes ]]
function PTTSM_Menu_Watchdog(index)
    if index == 1 then
        if PTTSM_Get_TableVal(PTTSM_Settings,"WindowIsOpen",0,2) == 0 then PTTSM_Menu_ChangeItemPrefix(index,"Open")
        elseif PTTSM_Get_TableVal(PTTSM_Settings,"WindowIsOpen",0,2) == 1 then PTTSM_Menu_ChangeItemPrefix(index,"Close") end
    end
    if index == 2 then
        if PTTSM_Get_TableVal(PTTSM_Settings,"Debug",0,2) == 0 then PTTSM_Menu_CheckItem(index,"Deactivate")
        elseif PTTSM_Get_TableVal(PTTSM_Settings,"Debug",0,2) == 1 then PTTSM_Menu_CheckItem(index,"Activate") end
    end
end
