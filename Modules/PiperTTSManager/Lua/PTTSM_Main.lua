--[[

Lua Module, required by PiperTTSManager.lua
Licensed under the EUPL v1.2: https://eupl.eu/

]]
--[[

VARIABLES (local to this module)

]]
local PTTSM_PageTitle = "Server and Interface"      -- Page title
local PTTSM_PageInitStatus = 0            -- Page initialization variable
local PTTSM_BaseFolder_Abs = SYSTEM_DIRECTORY.."PiperTTSManager/Resources/"
local PTTSM_BaseFolder = MODULES_DIRECTORY.."PiperTTSManager/Resources/"

local PTTSM_InterfFolder = MODULES_DIRECTORY.."PiperTTSManager/Interfaces"
local PTTSM_TempFile = MODULES_DIRECTORY.."PiperTTSManager/temp.wav" -- Temporary output file for loudness correction

local PTTSM_InputBaseFolder = {
    {"PiperTTSManager Directory",MODULES_DIRECTORY.."PiperTTSManager/"},
    {"X-Plane Plugins Directory",SYSTEM_DIRECTORY.."Resources"..DIRECTORY_SEPARATOR.."plugins/"},
    {"X-Plane Base Directory",SYSTEM_DIRECTORY},
    {"Current Aircraft Directory",AIRCRAFT_PATH},
    {"FWL Scripts Directory",SCRIPT_DIRECTORY},
    }
local PTTSM_InterfaceContainer = {  -- Container for interfaces
{"None/Testing"},       -- Default interface for local output
{"Create New Interface"}, -- Creates new interface
}
local PTTSM_InterfaceData = {
{"PluginName"},           -- SAVE FILE IDENTIFIER; KEEP UNIQUE TO THIS ARRAY
{"Dataref","None"},
{"Input",PTTSM_InputBaseFolder[1][1],"Input_PiperTTS.txt","::"},
{"Output",PTTSM_InputBaseFolder[1][1],"transmission.wav","FlyWithLua"},
{"Voicemap"},
{"VolumeGain",0},
}
local PTTSM_PlaybackAgent = {"FlyWithLua","Plugin"}

local PTTSM_InterfaceSelected = PTTSM_InterfaceContainer[1][1] --"Select an interface"
local PTTSM_InterfaceEditMode = 0
local PTTSM_VoiceList = { }
local PTTSM_VoiceSelected = " "
local PTTSM_PrevActor = {"None","None"}  -- The actor of the previous voice communication
local PTTSM_TestString = " "
local PTTSM_ActiveInterfaces = { }
local PTTSM_ServerProcessQueue = { }
local PTTSM_PlaybackTimer_Ref = {os.time(),0}
local PTTSM_PhoneticCorrections = { -- Table with phonetic corrections
{"you're","you are"},
{"I'm","I am"},
{"he's","he is"},
{"'ll"," will"},
{"can't","can not"},
{"won't","will not"},
{"don't","do not"},
{"didn't","did not"},
{"haven't","have not"},
{"shouldn't","should not"},
{"shan't","shall not"},
{"'",""}, -- Should always be last
}
-- Prime random number generator
math.randomseed(os.time())
math.random(); math.random(); math.random()
--[[

FUNCTIONS

]]
--[[
DYNAMIC PATHS
]]
local function PTTSM_PathConstructor(interface,mode,size)
    local inputtable = PTTSM_InterfaceContainer
    local tabindex = PTTSM_SubTableIndex(inputtable,interface)
    if mode == "Input" or mode == "Output" then
        if size == "Full" then
            return PTTSM_Get_TableVal(PTTSM_InputBaseFolder,PTTSM_Get_TableVal(inputtable[tabindex][2],tostring(mode),0,2),0,2)..PTTSM_Get_TableVal(inputtable[tabindex][2],tostring(mode),0,3)
        end
        if size == "Base" then
            return PTTSM_Get_TableVal(PTTSM_InputBaseFolder,PTTSM_Get_TableVal(inputtable[tabindex][2],tostring(mode),0,2),0,2)
        end
    end
end
--[[
PLAYBACK
]]
--[[ Determines the filesize ]]
local function MTTS_GetFileSize(file)
        local current = file:seek()      -- get current position
        local size = file:seek("end")    -- get file size
        file:seek("set", current)        -- restore position
        return size
end
--[[ Writes to the selected output file ]]
local function PTTSM_OutputToFile(interface,voice,string)
    --print(voice.." says: "..string)
    local inputtable = PTTSM_InterfaceContainer
    local tabindex = PTTSM_SubTableIndex(inputtable,interface)
    local textfile = io.open(PTTSM_PathConstructor(interface,"Input","Full"),"a")
    if textfile then
        textfile:write(voice,PTTSM_Get_TableVal(inputtable[tabindex][2],"Input",0,4),string,"\n")
        --print("PTTSM: Writing \""..voice..PTTSM_Get_TableVal(inputtable[tabindex][2],"Input",0,4)..string.."\\n\" to "..PTTSM_PathConstructor(interface,"Input","Full"))
        textfile:close()
    end
end
--[[ Corrects the volume of the selected voice ]]
local function PTTSM_VoiceVolumeCorrection(input,table)
	local output = 1.0 
	for i=1,#table do
		if input == table[i][1] then 
			output = table[i][2]
			--print("Volume correction for "..input.." is "..output.." dB")
		end
	end
	return output
end
--[[ Corrects problematic strings in an input string according to the resolution dictionary ]]
local function PTTSM_ApplyPhoneticCorrection(input,dictionary)
    local tempvar = input
    for i=1,#dictionary do
        tempvar = tempvar:gsub(dictionary[i][1],dictionary[i][2])
    end
    return tempvar
end


--[[ Reads the selected input file ]]
local function PTTSM_InputFromFile(interface)
    local inputtable = PTTSM_InterfaceContainer
    local tabindex = PTTSM_SubTableIndex(inputtable,interface)
    local textfile = io.open(PTTSM_PathConstructor(interface,"Input","Full"),"r")
    local oldqueuesize = #PTTSM_ServerProcessQueue
    if textfile then
        for line in textfile:lines() do     -- Fill process queue
            local splitline = PTTSM_SplitString(line,"([^"..PTTSM_Get_TableVal(inputtable[tabindex][2],"Input",0,4).."]+)")
            PTTSM_ServerProcessQueue[#PTTSM_ServerProcessQueue+1] = splitline
            PTTSM_ServerProcessQueue[#PTTSM_ServerProcessQueue][#PTTSM_ServerProcessQueue[#PTTSM_ServerProcessQueue]+1] = PTTSM_PathConstructor(interface,"Output","Full")
        end
        textfile:close()
        os.remove(PTTSM_PathConstructor(interface,"Input","Full"))
        --print("PTTSM: PiperTTS Input Queue Length Size: "..#PTTSM_ServerProcessQueue.." (+"..(#PTTSM_ServerProcessQueue-oldqueuesize)..")")
    end
    -- Sends the first item from the process queue to the PiperTTS server
    if #PTTSM_ServerProcessQueue > 0 then
        -- PART 1: GENERATE TEMPORARY FILE FROM MARYTTS
        local f = io.open(PTTSM_TempFile,"r") -- Check for presence of temporary WAV
        if f == nil then
            -- Assigns a a voice from the voice mapping or randomly
            if PTTSM_SubTableLength(inputtable[tabindex][2],"Voicemap") > 1 then
                for j=2,PTTSM_SubTableLength(inputtable[tabindex][2],"Voicemap") do
                    if PTTSM_ServerProcessQueue[1][1] == PTTSM_Get_TableVal(inputtable[tabindex][2],"Voicemap",j,1) then PTTSM_ServerProcessQueue[1][1] = PTTSM_Get_TableVal(inputtable[tabindex][2],"Voicemap",j,2) -- Voice mapping found
                    elseif j == PTTSM_SubTableLength(inputtable[tabindex][2],"Voicemap") then -- Voice mapping not found
                        if PTTSM_ServerProcessQueue[1][1] ~= PTTSM_PrevActor[1] then -- Actor different to previous one
                            local newactorname = PTTSM_ServerProcessQueue[1][1]
                            PTTSM_ServerProcessQueue[1][1] = PTTSM_VoiceList[math.random(1,#PTTSM_VoiceList)]
                            for k=2,PTTSM_SubTableLength(inputtable[tabindex][2],"Voicemap") do
                                if PTTSM_ServerProcessQueue[1][1] == PTTSM_Get_TableVal(inputtable[tabindex][2],"Voicemap",k,1) then
                                    PTTSM_ServerProcessQueue[1][1] = PTTSM_VoiceList[math.random(1,#PTTSM_VoiceList)]
                                    PTTSM_Log_Write("PTTSM: Voice already mapped. Retrying...")
                                end
                            end
                            PTTSM_Log_Write("Actor Change (Random Voice): "..PTTSM_PrevActor[1].." ("..PTTSM_PrevActor[2]..") -> "..newactorname.." ("..PTTSM_ServerProcessQueue[1][1]..")")
                            PTTSM_PrevActor[1] = newactorname                   -- Update old actor table: Name
                            PTTSM_PrevActor[2] = PTTSM_ServerProcessQueue[1][1] -- Update old actor table: Voice
                        else
                            PTTSM_ServerProcessQueue[1][1] = PTTSM_PrevActor[2]
                        end
                    end
                end
            end
            if PTTSM_Get_TableVal(PTTSM_Settings,"Debug",0,2) == 1 then PTTSM_Log_Write("PTTSM: "..PTTSM_ServerProcessQueue[1][1].." says \""..PTTSM_ServerProcessQueue[1][2].."\" and outputs to "..PTTSM_ServerProcessQueue[1][3]) end
            -- Apply phonetic correction
            local temp = PTTSM_ApplyPhoneticCorrection(PTTSM_ServerProcessQueue[1][2],PTTSM_PhoneticCorrections)
            --print(temp)
            -- If loudness correction has to be reinstated, use PTTSM_TempFile as output instead of PTTSM_ServerProcessQueue[1][3]
            if SYSTEM == "IBM" then io.popen('echo '..temp..' | "'..PTTSM_BaseFolder..'Piper_WIN/piper.exe" --model "'..PTTSM_BaseFolder.."/piper_voices/"..PTTSM_ServerProcessQueue[1][1]..'".onnx --output_file "'..PTTSM_ServerProcessQueue[1][3]..'"')
            elseif SYSTEM == "LIN" then os.execute('echo '..temp..' | "'..PTTSM_BaseFolder..'"Piper_LIN/piper --model "'..PTTSM_BaseFolder.."/piper_voices/"..PTTSM_ServerProcessQueue[1][1]..'".onnx --output_file "'..PTTSM_ServerProcessQueue[1][3]..'"')
            elseif SYSTEM == "APL" then os.execute('echo '..temp..' | "'..PTTSM_BaseFolder..'"Piper_MAC/piper --model "'..PTTSM_BaseFolder.."/piper_voices/"..PTTSM_ServerProcessQueue[1][1]..'".onnx --output_file "'..PTTSM_ServerProcessQueue[1][3]..'"')
            else return end
        end
        -- Debug
        if PTTSM_Get_TableVal(PTTSM_Settings,"Debug",0,2) == 1 then
            --lfs.mkdir()
            local file = io.open(PTTSM_ServerProcessQueue[1][3],"r") -- Check for presence of output WAV
            local bitrate = 44100 -- Divider tro calculate audio length
            if file ~= nil then
                local fsize = MTTS_GetFileSize(file)
                PTTSM_Log_Write("PTTSM: Filesize is "..fsize.." bytes; length is "..(fsize/bitrate).." seconds")
                io.close(file)
            end
        end
        table.remove(PTTSM_ServerProcessQueue,1)
    end
    -- If playback is set to FWL, play WAV file there
    if PTTSM_Get_TableVal(inputtable[tabindex][2],"Output",0,4) == "FlyWithLua" then
        local out_wav = PTTSM_PathConstructor(interface,"Output","Full")
        local bitrate = 44100 -- Divider tro calculate audio length
        local f = io.open(out_wav,"r") -- Check for presence of output WAV
        if f ~= nil then
            local fsize = MTTS_GetFileSize(f)
            --print("PTTSM: Filesize is "..fsize.." bytes; length is "..(fsize/bitrate).." seconds")
            io.close(f)
            -- Timer:
            if PTTSM_PlaybackTimer_Ref[2] == 1 then -- Unlock delay before first playback
                if os.time() > (PTTSM_PlaybackTimer_Ref[1] + math.ceil(fsize/bitrate)) then
                    PTTSM_Log_Write("PTTSM: Playing back "..out_wav.." with "..PTTSM_Get_TableVal(inputtable[tabindex][2],"Output",0,4))
                    -- OpenAL
                    if OutputWav == nil then OutputWav = load_WAV_file(out_wav) else replace_WAV_file(OutputWav,out_wav) end
                    play_sound(OutputWav)
                    -- Fmod
                    --local test_wav = load_fmod_sound(SYSTEM_DIRECTORY .. "Resources/plugins/FlyWithLua/Modules/PiperTTSManager/transmission.wav")
                    --play_sound_on_master_bus(test_wav)
                    -- Clean up
                    os.remove(out_wav)
                    PTTSM_PlaybackTimer_Ref[1] = os.time()
                end
            else
                PTTSM_PlaybackTimer_Ref[2] = 1
            end
        end
    end
end
--[[
PROCESS
]]
--[[ PiperTTS watchdog - runs every second in PTTSM_Main_1sec() in PiperTTSManager.lua ]]
function PTTSM_Watchdog()
    for i=1,#PTTSM_ActiveInterfaces do -- Iterate through active interfaces
        for j=1,#PTTSM_InterfaceContainer do
            if PTTSM_InterfaceContainer[j][2][1][1] == PTTSM_ActiveInterfaces[i] then -- Match active interface to subtable index in container
                PTTSM_InputFromFile(PTTSM_InterfaceContainer[j][2][1][1])
            end
        end
    end
end
--[[
INTERFACES
]]
--[[ Get a list of files and save it to a table ]]
local function PTTSM_GetFileList(inputdir,outputtable,filter)
    local resfile = nil
    if SYSTEM == "IBM" then resfile = io.popen('dir "'..inputdir..'" /b')
    elseif SYSTEM == "LIN" then resfile = io.popen('ls -AU1N "'..inputdir..'"')
    elseif SYSTEM == "APL" then 
    else return end
    if resfile ~= nil then
        if filter == "voice" then for i= 1, #outputtable do outputtable[i] = nil end end -- Reset output table
        if filter == "*.cfg" then for i= 3, #outputtable do outputtable[i] = nil end end -- Reset output table
        for filename in resfile:lines() do
            -- Voices
            if filter == "voice" and string.find(filename,".onnx.json") then
                outputtable[#outputtable+1] = filename:gsub("%.onnx.json","")
                if #outputtable > 1 then PTTSM_VoiceSelected = outputtable[1] PTTSM_TestString = "Hello, I am "..PTTSM_VoiceSelected..", a TTS voice." end
            end
            -- Interface files
            if filter == "*.cfg" then 
                if string.gmatch(filename,filter) then
                    outputtable[#outputtable+1] = { }
                    outputtable[#outputtable][1] = filename:match "[^.]+" 
                end
            end
        end
        resfile:close()
        if filter == "voice" then PTTSM_Log_Write("Found voices: "..table.concat(outputtable,", ")) end -- Debug output
        if filter == "*.cfg" then PTTSM_Log_Write("Found interfaces: ") for j=1,#outputtable do PTTSM_Log_Write("- "..outputtable[j][1]) end end -- Debug output
    end
    return outputtable
end
--[[ Load an interface ]]
local function PTTSM_InterfaceLoad(inputfolder,container,datatable)
    PTTSM_GetFileList(inputfolder,container,"*.cfg")                              -- Obtains the list of interfaces
    for i=1,#container do
        local indexvar = nil
        container[i][2] = { } -- Create empty table in container table
        for j=1,#datatable do container[i][2][j] = { } end -- Fill container subtable with empty tables corresponding to the size of the input datatable
        -- Build subtables in container table
        if i ~= 2 then container[i][2][1][1] = container[i][1] else container[i][2][1][1] = "New Interface" end -- First subtable in container subtable is reserved for the interface name
        indexvar = PTTSM_SubTableIndex(datatable,"Dataref")
        for k =1,#PTTSM_InterfaceData[indexvar] do container[i][2][indexvar][k] = PTTSM_InterfaceData[indexvar][k] end -- Write default values for dataref subtable to subtable in container
        indexvar = PTTSM_SubTableIndex(datatable,"Input")
        for k =1,#PTTSM_InterfaceData[indexvar] do container[i][2][indexvar][k] = PTTSM_InterfaceData[indexvar][k] end -- Write default values for input subtable to subtable in container
        indexvar = PTTSM_SubTableIndex(datatable,"Output")
        for k =1,#PTTSM_InterfaceData[indexvar] do container[i][2][indexvar][k] = PTTSM_InterfaceData[indexvar][k] end -- Write default values for output subtable to subtable in container
        indexvar = PTTSM_SubTableIndex(datatable,"Voicemap")
        for k =1,#PTTSM_InterfaceData[indexvar] do container[i][2][indexvar][k] = PTTSM_InterfaceData[indexvar][k] end -- Write default values for voicemap subtable to subtable in container
        indexvar = PTTSM_SubTableIndex(datatable,"VolumeGain")
        for k =1,#PTTSM_InterfaceData[indexvar] do container[i][2][indexvar][k] = PTTSM_InterfaceData[indexvar][k] end -- Write default values for dataref subtable to subtable in container
        -- Read interface files
        if i >= 4 then PTTSM_FileRead(inputfolder.."/"..container[i][1]..".cfg",container[i][2]) end -- Read data from file into interface data table
    end
    --for m=1,#container do print(container[m][2][5][1]) print(#container[m][2][5]) end
end
--[[ Select an interface ]]
local function PTTSM_InterfaceSelector(inputtable)
    imgui.TextUnformatted("Selected Interface  ") imgui.SameLine()
    imgui.PushItemWidth(PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-278)
    if imgui.BeginCombo("##ComboInterfaceSelect",PTTSM_InterfaceSelected) then
        -- Loop over all choices
        for i = 1, #inputtable do
            if imgui.Selectable(inputtable[i][1], choice == i) then
                PTTSM_InterfaceSelected = inputtable[i][1]
                --print(PTTSM_InterfaceSelected)
                if PTTSM_InterfaceSelected == "Create New Interface" then if PTTSM_InterfaceEditMode == 0 then PTTSM_InterfaceEditMode = 1 end
                else if PTTSM_InterfaceEditMode == 1 then PTTSM_InterfaceEditMode = 0 end end
                choice = i
            end
        end
    imgui.EndCombo()
    end
    imgui.PopItemWidth()
    imgui.SameLine()
    if imgui.Button("Rescan",90,20) then PTTSM_InterfaceLoad(PTTSM_InterfFolder,PTTSM_InterfaceContainer,PTTSM_InterfaceData) end
end
--[[ Add a voice mapping ]]
local function PTTSM_AddVoiceMapping(inputtable)
    --local index = PTTSM_SubTableIndex(inputtable,"Voicemap")
    --print(inputtable[index][1])
    local temptable = {"None","None"}
    PTTSM_SubTableAdd(inputtable,"Voicemap",temptable)
end
--[[ Find active interfaces ]]
local function PTTSM_FindActiveInterfaces(container)
    local inactiveifs = { }
    PTTSM_ActiveInterfaces[1] = container[1][2][1][1]
    for i=3,#container do
        if XPLMFindDataRef(PTTSM_Get_TableVal(container[i][2],"Dataref",0,2)) then
            PTTSM_ActiveInterfaces[#PTTSM_ActiveInterfaces+1] = container[i][2][1][1]
        else
            inactiveifs[#inactiveifs+1] = container[i][2][1][1]
        end
    end
    PTTSM_Log_Write("PiperTTS Interfaces (Active): "..table.concat(PTTSM_ActiveInterfaces,", "))
    PTTSM_Log_Write("PiperTTS Interfaces (Inactive): "..table.concat(inactiveifs,", "))
end
--[[

UI ELEMENTS

]]
--[[ Interface status/editor ]]
local function PTTSM_InterfaceStatus(inputtable)
    --PTTSM_InterfaceSelected = "SimpleATC"
    local tabindex = PTTSM_SubTableIndex(inputtable,PTTSM_InterfaceSelected)
    local editstring = "    "
    if PTTSM_InterfaceEditMode == 1 then editstring = "New " else editstring = "    " end
    imgui.PushItemWidth(PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-180)
    if PTTSM_InterfaceSelected == PTTSM_InterfaceContainer[2][1] then
        imgui.TextUnformatted(editstring.."Interface Name  ") imgui.SameLine()
        local changed,buffer = imgui.InputText("##InterfaceName "..PTTSM_InterfaceSelected,inputtable[tabindex][2][1][1], 256)
        if changed and buffer ~= "" and tostring(buffer) then inputtable[tabindex][2][1][1] = tostring(buffer) buffer = nil end
        PTTSM_ItemTooltip("The name of the interface and file name of its config file.")
    end
    if PTTSM_InterfaceSelected ~= PTTSM_InterfaceContainer[1][1] then
        imgui.TextUnformatted(editstring.."Plugin Dataref  ") imgui.SameLine()
        local changed,buffer = imgui.InputText("##Dataref"..PTTSM_InterfaceSelected,PTTSM_Get_TableVal(inputtable[tabindex][2],"Dataref",0,2), 256)
        if PTTSM_InterfaceEditMode == 1 then if changed and buffer ~= "" and tostring(buffer) then PTTSM_Set_TableVal(inputtable[tabindex][2],"Dataref",0,2,tostring(buffer)) buffer = nil end end
        PTTSM_ItemTooltip("The dataref that is used to check whether another plugin is active or not. Currently set to:\n"..PTTSM_Get_TableVal(inputtable[tabindex][2],"Dataref",0,2))
    end
    imgui.TextUnformatted(editstring.."Input Base Path ") imgui.SameLine()
    if imgui.BeginCombo("##ComboInputFile",PTTSM_Get_TableVal(inputtable[tabindex][2],"Input",0,2)) then
        for i = 1, #PTTSM_InputBaseFolder do
            if imgui.Selectable(PTTSM_InputBaseFolder[i][1], choice == i) then
                PTTSM_Set_TableVal(inputtable[tabindex][2],"Input",0,2,PTTSM_InputBaseFolder[i][1])
                --print(PTTSM_Get_TableVal(inputtable[tabindex][2],"Input",0,2).." -> "..PTTSM_Get_TableVal(PTTSM_InputBaseFolder,PTTSM_InputBaseFolder[i][1],0,2))
                choice = i
            end
        end
        imgui.EndCombo()
    end
    PTTSM_ItemTooltip("The base folder from which the location of the input text file is defined. Absolute path on *your system*:\n"..PTTSM_PathConstructor(PTTSM_InterfaceSelected,"Input","Base"))
    --PTTSM_ItemTooltip("The text file the plugin writes its PiperTTS information into. Currently set to:\n"..PTTSM_Get_TableVal(inputtable[tabindex][2],"Input",0,3))
    imgui.TextUnformatted(editstring.."Input Text File ") imgui.SameLine()
    local changed,buffer = imgui.InputText("##Input"..PTTSM_InterfaceSelected,PTTSM_Get_TableVal(inputtable[tabindex][2],"Input",0,3), 1024)
    if PTTSM_InterfaceEditMode == 1 then if changed and buffer ~= "" and tostring(buffer) then PTTSM_Set_TableVal(inputtable[tabindex][2],"Input",0,3,tostring(buffer)) buffer = nil end end
    PTTSM_ItemTooltip("The location and filename of the input text file relative to the base folder above. The complete, absolute path on *your system*:\n"..PTTSM_PathConstructor(PTTSM_InterfaceSelected,"Input","Full"))
    imgui.TextUnformatted(editstring.."Input Delimiter ") imgui.SameLine()
    local changed,buffer = imgui.InputText("##Delimiter"..PTTSM_InterfaceSelected,PTTSM_Get_TableVal(inputtable[tabindex][2],"Input",0,4), 1024)
    if PTTSM_InterfaceEditMode == 1 then if changed and buffer ~= "" and tostring(buffer) then PTTSM_Set_TableVal(inputtable[tabindex][2],"Input",0,4,tostring(buffer)) buffer = nil end end
    PTTSM_ItemTooltip("The sign that is used to separate voice and string to be spoken in the text file.")
    imgui.Dummy((PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-30),10)
    imgui.TextUnformatted(editstring.."Output Base Path") imgui.SameLine()
    if imgui.BeginCombo("##ComboOutputWAV",PTTSM_Get_TableVal(inputtable[tabindex][2],"Output",0,2)) then
        for i = 1, #PTTSM_InputBaseFolder do
            if imgui.Selectable(PTTSM_InputBaseFolder[i][1], choice == i) then
                PTTSM_Set_TableVal(inputtable[tabindex][2],"Output",0,2,PTTSM_InputBaseFolder[i][1])
                --print(PTTSM_Get_TableVal(inputtable[tabindex][2],"Output",0,2).." -> "..PTTSM_Get_TableVal(PTTSM_InputBaseFolder,PTTSM_InputBaseFolder[i][1],0,2))
                choice = i
            end
        end
        imgui.EndCombo()
    end
    PTTSM_ItemTooltip("The base folder from which the location of the output WAV file is defined. Absolute path on *your system*:\n"..PTTSM_PathConstructor(PTTSM_InterfaceSelected,"Output","Base"))
    imgui.TextUnformatted(editstring.."Output WAV File ") imgui.SameLine()
    local changed,buffer = imgui.InputText("##Output"..PTTSM_InterfaceSelected,PTTSM_Get_TableVal(inputtable[tabindex][2],"Output",0,3), 1024)
    if PTTSM_InterfaceEditMode == 1 then if changed and buffer ~= "" and tostring(buffer) then PTTSM_Set_TableVal(inputtable[tabindex][2],"Output",0,3,tostring(buffer)) buffer = nil end end
    PTTSM_ItemTooltip("The location and filename of the output WAV file relative to the base folder above. The complete, absolute path on *your system*:\n"..PTTSM_PathConstructor(PTTSM_InterfaceSelected,"Output","Full"))
    imgui.TextUnformatted(editstring.."Play WAV With   ") imgui.SameLine()
    if imgui.BeginCombo("##ComboPlaybackAgent",PTTSM_Get_TableVal(inputtable[tabindex][2],"Output",0,4)) then
        for i = 1, #PTTSM_PlaybackAgent do
            if imgui.Selectable(PTTSM_PlaybackAgent[i], choice == i) then
                PTTSM_Set_TableVal(inputtable[tabindex][2],"Output",0,4,PTTSM_PlaybackAgent[i])
                choice = i
            end
        end
        imgui.EndCombo()
    end
    PTTSM_ItemTooltip("The agent that plays back the output WAV file.")
    --[[
    imgui.TextUnformatted(editstring.."Volume Gain     ") imgui.SameLine()
    local changed, newVal = imgui.SliderFloat("##volslider2",PTTSM_Get_TableVal(inputtable[tabindex][2],"VolumeGain",0,2),-12,12, "%.2f dB")
    if changed then PTTSM_Set_TableVal(inputtable[tabindex][2],"VolumeGain",0,2,newVal) end
    PTTSM_ItemTooltip("The offset, in decibels, to the regular volume of the generated audio files.")
    ]]
    imgui.PopItemWidth()
    if PTTSM_InterfaceSelected ~= PTTSM_InterfaceContainer[1][1] then
        if PTTSM_SubTableLength(inputtable[tabindex][2],"Voicemap") > 1 then
            for j=2,PTTSM_SubTableLength(inputtable[tabindex][2],"Voicemap") do
                imgui.PushItemWidth(PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-370)
                imgui.TextUnformatted(editstring.."Voice Mapping "..string.format("%02d",(j-1))) imgui.SameLine()
                local changed,buffer = imgui.InputText("##Mapping"..PTTSM_InterfaceSelected..(j-1),PTTSM_Get_TableVal(inputtable[tabindex][2],"Voicemap",j,1), 256)
                if PTTSM_InterfaceEditMode == 1 then if changed and buffer ~= "" and tostring(buffer) then PTTSM_Set_TableVal(inputtable[tabindex][2],"Voicemap",j,1,tostring(buffer)) buffer = nil end end
                PTTSM_ItemTooltip("This is the keyword from the plugin's output text file that will be associated to the voice on the right. If the keyword does not match the one in the plugin output, a random voice will be selected.")
                imgui.PopItemWidth()
                imgui.SameLine()
                imgui.PushItemWidth(182)
                if imgui.BeginCombo("##Combo"..PTTSM_InterfaceSelected..(j-1), PTTSM_Get_TableVal(inputtable[tabindex][2],"Voicemap",j,2)) then
                    for k = 1, #PTTSM_VoiceList do
                        if imgui.Selectable(PTTSM_VoiceList[k], choice == k) then
                            if PTTSM_InterfaceEditMode == 1 then PTTSM_Set_TableVal(inputtable[tabindex][2],"Voicemap",j,2,PTTSM_VoiceList[k]) end
                            choice = j
                        end
                    end
                imgui.EndCombo()
                end
                PTTSM_ItemTooltip("The voice associated with the keyword to the left. If the voice is not installed, an installed voice will be randomly selected.")
                imgui.PopItemWidth()
            end
        end
        if PTTSM_InterfaceEditMode == 1 then
            imgui.TextUnformatted("    Voice Mapping   ") imgui.SameLine()
            if PTTSM_SubTableLength(inputtable[tabindex][2],"Voicemap") > 1 then
                if imgui.Button("Remove",100,20) then PTTSM_ItemRemove(inputtable[tabindex][2],"Voicemap",PTTSM_SubTableLength(inputtable[tabindex][2],"Voicemap")) end
                PTTSM_ItemTooltip("Will remove voice mapping "..string.format("%02d",PTTSM_SubTableLength(inputtable[tabindex][2],"Voicemap")-1)..".")
            else
                imgui.Dummy(100,20)
            end
            imgui.SameLine() imgui.Dummy((PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-395),20) imgui.SameLine()
            if imgui.Button("Add",100,20) then PTTSM_AddVoiceMapping(inputtable[tabindex][2]) end
            PTTSM_ItemTooltip("Add a new voice mapping (number "..string.format("%02d",PTTSM_SubTableLength(inputtable[tabindex][2],"Voicemap"))..").")
            imgui.Dummy((PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-30),10)
            imgui.Dummy(19,20) imgui.SameLine()
            if imgui.Button("Save Interface Configuration File",(PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-59),20) then PTTSM_FileWrite(inputtable[tabindex][2],PTTSM_InterfFolder.."/"..inputtable[tabindex][2][1][1]..".cfg") PTTSM_InterfaceEditMode = 0 end
            PTTSM_ItemTooltip("Save interface file to "..PTTSM_InterfFolder.."/"..inputtable[tabindex][2][1][1]..".cfg")
            imgui.Dummy((PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-30),10)
        else
            imgui.Dummy((PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-30),20)
        end
    else
        imgui.Dummy((PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-30),20)
    end
    local buttonstring = "Disable"
    if PTTSM_InterfaceEditMode == 1 then buttonstring = "Disable" else buttonstring = "Enable" end
    imgui.Dummy(19,20) imgui.SameLine()
    if PTTSM_InterfaceSelected ~= PTTSM_InterfaceContainer[1][1] and imgui.Button(buttonstring.." Edit Mode",(PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-59),20) then if PTTSM_InterfaceEditMode == 0 then PTTSM_InterfaceEditMode = 1 else PTTSM_InterfaceEditMode = 0 end end
    if buttonstring == "Enable" then PTTSM_ItemTooltip("Enter interface edit mode (will stop input text file processing watchdog!)") end
    if buttonstring == "Disable" then PTTSM_ItemTooltip("Leave interface edit mode (will (re)start input text file processing watchdog!)") end
    imgui.Dummy((PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-30),20)
end
--[[ Testing area ]]
local function PTTSM_Testing(inputtable)
    -- Only display this if there are available voices
    if #inputtable >= 1 then
        imgui.PushItemWidth(PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-180)
        imgui.TextUnformatted("    String To Speak ") imgui.SameLine()
        local changed,buffer = imgui.InputText("##SpeakString",PTTSM_TestString, 512)
        if changed and buffer ~= "" and tostring(buffer) then PTTSM_TestString = buffer buffer = nil end
        PTTSM_ItemTooltip("The string that is to be spoken.")
        imgui.TextUnformatted("    Voice To Use    ") imgui.SameLine()
        if imgui.BeginCombo("##Combo2", PTTSM_VoiceSelected) then
            -- Loop over all choices
            for i = 1, #inputtable do
                if imgui.Selectable(inputtable[i], choice == i) then
                    PTTSM_VoiceSelected = inputtable[i]
                    choice = i
                    PTTSM_TestString = "Hello, I am "..PTTSM_VoiceSelected..", a TTS voice."
                end
            end
            imgui.EndCombo()
        end
        PTTSM_ItemTooltip("The voice actor that speaks the above string.")
        imgui.PopItemWidth()
        imgui.Dummy(19,20) imgui.SameLine()
        if imgui.Button("Speak",PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-59,20) then PTTSM_OutputToFile(PTTSM_InterfaceContainer[1][1],PTTSM_VoiceSelected,PTTSM_TestString) end
        PTTSM_ItemTooltip("Speaks the string with the selected voice.")
    else
        imgui.Dummy(19,20) imgui.SameLine()
        imgui.TextUnformatted("No Piper voices found; testing area disabled!")
        imgui.Dummy((PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-30),40)
    end
    imgui.Dummy((PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-30),20)
end
--[[ 

INITIALIZATION

]]
function PTTSM_ModuleInit_Main()
    PTTSM_InterfaceLoad(PTTSM_InterfFolder,PTTSM_InterfaceContainer,PTTSM_InterfaceData)
    PTTSM_GetFileList(PTTSM_BaseFolder.."/piper_voices",PTTSM_VoiceList,"voice")
    PTTSM_FindActiveInterfaces(PTTSM_InterfaceContainer)
end
--[[ 

IMGUI WINDOW ELEMENT

]]
--[[ Window page initialization ]]
local function PTTSM_Page_Init()
    if PTTSM_PageInitStatus == 0 then PTTSM_Refresh_PageDB(PTTSM_PageTitle) PTTSM_PageInitStatus = 1 end
end
--[[ Window content ]]
function PTTSM_Win_Main()
	--[[ File content ]]
	-- Interface selector
	PTTSM_InterfaceSelector(PTTSM_InterfaceContainer)
	imgui.Dummy((PTTSM_Get_TableVal(PTTSM_Settings,"Window",0,4)-30),10)
	PTTSM_InterfaceStatus(PTTSM_InterfaceContainer)
	-- Testing area
	if PTTSM_InterfaceSelected == PTTSM_InterfaceContainer[1][1] then PTTSM_Testing(PTTSM_VoiceList) end
end
