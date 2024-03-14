--[[

Lua Module, required by PiperTTSManager.lua
Licensed under the EUPL v1.2: https://eupl.eu/

]]
--[[

VARIABLES (local to this module)

]]
local PTTSM_SaveFileDelimiter = "#"       -- The delimiter between value and type in the save file
local PTTSM_LogFile = MODULES_DIRECTORY.."PiperTTSManager/PTTSM_Log.txt"          -- Log file path
PTTSM_SettingsFile = MODULES_DIRECTORY.."PiperTTSManager/Settings.cfg"   -- Settings file path

PTTSM_Settings = {
    {"PTTSM_Settings"},
    {"WindowIsOpen",0},         -- Window open/close status
    {"Window",100,400,530,600}, -- Window 2:X,3:Y,4:W,5:H
    {"Debug",0},                -- Enable debug output
}

--[[

LOGGING

]]
--[[ Write to log file ]]
function PTTSM_Log_Write(string)
    local file = io.open(PTTSM_LogFile, "a") -- Check if file exists
    file:write(os.date("%x, %H:%M:%S"),": ",string,"\n")
    file:close()
end
--[[ Delete log file ]]
function PTTSM_Log_Delete()
    os.remove(PTTSM_LogFile)
end
--[[

FOREIGN FUNCTION INTERFACE (FFI)

]]
PTTSM_XPLM = nil                              -- Define namespace for XPLM library
--[[ Load XPLM library ]]
PTTSM_Log_Write(string.format("FFI XPLM: Operating system is: %s",PTTSM_ffi.os))
if SYSTEM == "IBM" then PTTSM_XPLM = PTTSM_ffi.load("XPLM_64")  -- Windows 64bit
    elseif SYSTEM == "LIN" then PTTSM_XPLM = PTTSM_ffi.load("Resources/plugins/XPLM_64.so")  -- Linux 64bit (Requires "Resources/plugins/" for some reason)
    elseif SYSTEM == "APL" then PTTSM_XPLM = PTTSM_ffi.load("Resources/plugins/XPLM.framework/XPLM") -- 64bit MacOS (Requires "Resources/plugins/" for some reason)
    else return 
end
if PTTSM_XPLM ~= nil then PTTSM_Log_Write("FFI XPLM: Initialized!") end
--[[

C DEFINITIONS AND VARIABLES

]]
--[[ Add C definitions to FFI ]]
PTTSM_ffi.cdef([[
    /* XPLMUtilities*/
    typedef void *XPLMCommandRef;
    /* XPLMMenus */
    typedef int XPLMMenuCheck;
    typedef void *XPLMMenuID;
    typedef void (*XPLMMenuHandler_f)(void *inMenuRef,void *inItemRef);
    XPLMMenuID XPLMFindPluginsMenu(void);
    XPLMMenuID XPLMFindAircraftMenu(void);
    XPLMMenuID XPLMCreateMenu(const char *inName, XPLMMenuID inParentMenu, int inParentItem, XPLMMenuHandler_f inHandler,void *inMenuRef);
    void XPLMDestroyMenu(XPLMMenuID inMenuID);
    void XPLMClearAllMenuItems(XPLMMenuID inMenuID);
    int XPLMAppendMenuItem(XPLMMenuID inMenu,const char *inItemName,void *inItemRef,int inDeprecatedAndIgnored);
    int XPLMAppendMenuItemWithCommand(XPLMMenuID inMenu,const char *inItemName,XPLMCommandRef inCommandToExecute);
    void XPLMAppendMenuSeparator(XPLMMenuID inMenu);      
    void XPLMSetMenuItemName(XPLMMenuID inMenu,int inIndex,const char *inItemName,int inForceEnglish);
    void XPLMCheckMenuItem(XPLMMenuID inMenu,int index,XPLMMenuCheck inCheck);
    void XPLMCheckMenuItemState(XPLMMenuID inMenu,int index,XPLMMenuCheck *outCheck);
    void XPLMEnableMenuItem(XPLMMenuID inMenu,int index,int enabled);      
    void XPLMRemoveMenuItem(XPLMMenuID inMenu,int inIndex);
    /* XPLMDataAccess - inop because they're dumb cunts and can not be accessed */
    /* typedef void *XPLMDataRef;
    int XPLMGetDatab(XPLMDataRef inDataRef,void *outValue,int inOffset,int inMaxBytes);
    void XPLMSetDatab(XPLMDataRef inDataRef,void *inValue,int inOffset,int inLength); */
    ]])
--[[

FUNCTIONS

]]
--[[ Accessor: Get sub-table index by finding the value in first field ]]
function PTTSM_SubTableIndex(inputtable,target)
    for i=1,#inputtable do
       if inputtable[i][1] == target then return i end
    end
end

--[[ Accessor: Get sub-table length by finding the value in first field ]]
function PTTSM_SubTableLength(inputtable,target)
    for i=1,#inputtable do
       if inputtable[i][1] == target then return #inputtable[i] end
    end
end

--[[ Accessor: Add sub-table ]]
function PTTSM_SubTableAdd(outputtable,target,inputtable)
    for i=1,#outputtable do
       if outputtable[i][1] == target then
           outputtable[i][#outputtable[i]+1] = inputtable
       end
    end
end

--[[ Accessor: Remove sub-table ]]
function PTTSM_ItemRemove(outputtable,target,index)
    for i=1,#outputtable do
       if outputtable[i][1] == target then
           outputtable[i][index] = nil
       end
    end
end

--[[ Accessor: Get indexed sub-table value by finding the value in first field, consider further subtables ]]
function PTTSM_Get_TableVal(inputtable,target,subtabindex,index)
    for i=1,#inputtable do
       if inputtable[i][1] == target then
           if subtabindex > 0 and subtabindex ~= nil then
                return inputtable[i][subtabindex][index]
            else
                return inputtable[i][index]
           end
       end
    end
end

--[[ Accessor: Set indexed sub-table value by finding the target value in first field, consider further subtables ]]
function PTTSM_Set_TableVal(outputtable,target,subtabindex,index,newvalue)
    for i=1,#outputtable do
       if outputtable[i][1] == target then
           if subtabindex > 0 and subtabindex ~= nil then
                outputtable[i][subtabindex][index] = newvalue
            else
                outputtable[i][index] = newvalue
           end
       end
    end
end

--[[ Writes a file ]]
function PTTSM_FileWrite(inputtable,outputfile,log)
    local temptable = { }
    PTTSM_Log_Write("FILE INIT WRITE: "..outputfile)
    local file = io.open(outputfile,"r")
    if file then
        --Read output file and store all lines not part of inputtable and temptable
        for line in io.lines(outputfile) do
            if not string.match(line,"^"..inputtable[1][1]..",") then
                temptable[(#temptable+1)] = line
                --print(temptable[#temptable])
            end
        end
    end 
    -- Start writing to output file, write temptable and then inputtable
    file = io.open(outputfile,"w")
    file:write("MaryTTS Manager interface file created/updated on ",os.date("%x, %H:%M:%S"),"\n")
    file:write("\n")
    for j=3,#temptable do
        file:write(temptable[j].."\n")
    end
    for j=2,#inputtable do
        file:write(inputtable[1][1]..",")
        for k=1,#inputtable[j] do
            if type(inputtable[j][k]) == "string" or type(inputtable[j][k]) == "number" then file:write(inputtable[j][k]..PTTSM_SaveFileDelimiter..type(inputtable[j][k])) end
            if type(inputtable[j][k]) == "table" then
                file:write("{")
                for l=1,#inputtable[j][k] do
                    file:write(inputtable[j][k][l]..PTTSM_SaveFileDelimiter..type(inputtable[j][k][l]))
                    if l < #inputtable[j][k] then file:write(";") end
                end
                file:write("}")
            end
            if k < #inputtable[j] then file:write(",") else file:write("\n") end
        end    
    end
    if file:seek("end") > 0 then 
        if log == "log" then PTTSM_Log_Write("FILE WRITE SUCCESS: "..outputfile) else PTTSM_Log_Write("FILE WRITE SUCCESS: "..outputfile,"Success") end
    else 
        if log == "log" then PTTSM_Log_Write("FILE WRITE ERROR: "..outputfile) else PTTSM_Log_Write("FILE WRITE ERROR: "..outputfile,"Error") end
    end
    file:close()
end
--[[ Splits a line at the designated delimiter, returns a table ]]
function PTTSM_SplitString(input,delim)
    local output = {}
	--print("Line splitting in: "..input)
	for i in string.gmatch(input,delim) do table.insert(output,i) end
	--print("Line splitting out: "..table.concat(output,",",1,#output))
	return output
end

--[[ Merges subtables for printing ]]
function PTTSM_TableMergeAndPrint(intable)
    local tmp = {}
    for i=1,#intable do
        if type(intable[i]) ~= "table" then tmp[i] = tostring(intable[i]) end
        if type(intable[i]) == "table" then tmp[i] = tostring("{"..table.concat(intable[i],",").."}") end
    end
    return tostring(table.concat(tmp,","))
end

--[[ Read file ]]
function PTTSM_FileRead(inputfile,outputtable)
    -- Start reading input file
    local file = io.open(inputfile,"r")
    if file then
        PTTSM_Log_Write("FILE INIT READ: "..inputfile)
        local i = 0
        for line in file:lines() do
            -- Find lines matching first subtable of output table
            if string.match(line,"^"..outputtable[1][1]..",") then
                local temptable = {}
                local splitline = PTTSM_SplitString(line,"([^,]+)")
                for j=2,#splitline do
                   if string.match(splitline[j],"{") then -- Handle tables
                       local tempsubtable = {}
                       local splittable = PTTSM_SplitString(splitline[j],"{(.*)}") -- Strip brackets
                       local splittableelements = PTTSM_SplitString(splittable[1],"([^;]+)") -- Split at ;
                       for k=1,#splittableelements do
                          local substringtemp = PTTSM_SplitString(splittableelements[k],"([^"..PTTSM_SaveFileDelimiter.."]+)")
                          if substringtemp[2] == "string" then tempsubtable[k] = tostring(substringtemp[1]) end
                          if substringtemp[2] == "number" then tempsubtable[k] = tonumber(substringtemp[1]) end
                       end
                       temptable[j-1] = tempsubtable
                       --print("Table: "..table.concat(temptable[j-1],"-"))
                   else -- Handle regular variables
                        local substringtemp = PTTSM_SplitString(splitline[j],"([^"..PTTSM_SaveFileDelimiter.."]+)")
                        if substringtemp[2] == "string" then substringtemp[1] = tostring(substringtemp[1]) end
                        if substringtemp[2] == "number" then substringtemp[1] = tonumber(substringtemp[1]) end
                        temptable[j-1] = substringtemp[1]
                   end
                end
                --print(PTTSM_TableMergeAndPrint(temptable))
                -- Find matching line in output table
                for m=2,#outputtable do
                    -- Handle string at index 1
                    if type(temptable[1]) ~= "table" and temptable[1] == outputtable[m][1] then
                        --print("Old: "..PTTSM_TableMergeAndPrint(outputtable[m]))
                        for n=2,#temptable do
                            outputtable[m][n] = temptable[n]
                        end
                        --print("New: "..PTTSM_TableMergeAndPrint(outputtable[m]))
                    elseif type(temptable[1]) == "table" and temptable[1][1] == outputtable[m][1][1] then
                        --print("Old: "..PTTSM_TableMergeAndPrint(outputtable[m]))
                        for n=1,#temptable do
                            outputtable[m][n] = temptable[n]
                        end
                        --print("New: "..PTTSM_TableMergeAndPrint(outputtable[m]))
                    end
                end
            end
            i = i+1
        end
        file:close()
        if i ~= nil and i > 0 then PTTSM_Log_Write("FILE READ SUCCESS: "..inputfile) else PTTSM_Log_Write("FILE READ ERROR: "..inputfile) end
    else
        PTTSM_Log_Write("FILE NOT FOUND: "..inputfile)
	end
end
--[[ Displays a tooltip ]]
function PTTSM_ItemTooltip(string)
    if imgui.IsItemActive() or imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.PushTextWrapPos(imgui.GetFontSize() * 30)
        imgui.TextUnformatted(string)
        imgui.PopTextWrapPos()
        imgui.EndTooltip()
    end
end

--[[ Update window position information ]]
function PTTSM_GetWindowInfo()
		if PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4) ~= imgui.GetWindowWidth() or PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,5) ~= imgui.GetWindowHeight() or PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,2) ~= PTTSM_Window_Pos[1] or PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,3) ~= PTTSM_Window_Pos[2] then
			PTTSM_Set_TableVal(PTTSM_Settings,"Window",0,4,imgui.GetWindowWidth())
			PTTSM_Set_TableVal(PTTSM_Settings,"Window",0,5,imgui.GetWindowHeight())
			PTTSM_Set_TableVal(PTTSM_Settings,"Window",0,2,PTTSM_Window_Pos[1])
			PTTSM_Set_TableVal(PTTSM_Settings,"Window",0,3,PTTSM_Window_Pos[2])
		end
end
