local PopupDialogScreen = require "screens/popupdialog"
local ScriptErrorScreen = require "screens/scripterrorscreen"

-- 保存数据！
-- TheSim导出的功能。
function SavePersistentString(name, data, encode, callback)
	if TheFrontEnd then
		TheFrontEnd:ShowSavingIndicator()-- 显示游戏界面上方正在保存的动画！
		local function cb()
			TheFrontEnd:HideSavingIndicator()-- 关闭“正在保存”动画！
			if callback then
				callback()
			end
		end
		TheSim:SetPersistentString(name, data, encode or true, cb)
	else
		TheSim:SetPersistentString(name, data, encode or true, callback)
	end
end
-- 删除数据。TheSim导出功能。
function ErasePersistentString(name, callback)
   
	if TheFrontEnd then
		TheFrontEnd:ShowSavingIndicator()
		local function cb()		
			TheFrontEnd:HideSavingIndicator()
			if callback then
				callback()
			end
		end
		TheSim:ErasePersistentString(name, cb)
	else
		TheSim:ErasePersistentString(name, callback)
	end 
end

function Print( msg_verbosity, ... )
	if msg_verbosity <= VERBOSITY_LEVEL then
		print( ... )
	end
end


---PREFABS AND ENTITY INSTANTIATION
-- 注册物件！
-- 每个Prefab都返回了一个Prefab( name, fn, assets, prefabs)，所以每个Prefab都有assets等 
-- 这个函数载入一个Prefab，并保存在Prefabs表中，以便在SpawnPrefab时查阅。
function RegisterPrefabs(...)
    for i, prefab in ipairs({...}) do
        --print ("Register " .. tostring(prefab))
		-- allow mod-relative asset paths
		for i,asset in ipairs(prefab.assets) do
			local resolvedpath = resolvefilepath(asset.file)-- 麻烦的路径格式处理。返回是否存在这个路径。
			assert(resolvedpath, "Could not find "..asset.file.." required by "..prefab.name)
			TheSim:OnAssetPathResolve(asset.file, resolvedpath)			
			asset.file = resolvedpath
		end
        prefab.modfns = ModManager:GetPostInitFns("PrefabPostInit", prefab.name)
		--保存！
		Prefabs[prefab.name] = prefab
        
		TheSim:RegisterPrefab(prefab.name, prefab.assets, prefab.deps)
    end
end

function LoadPrefabFile( filename )
	--print("Loading prefab file "..filename)
    local fn, r = loadfile(filename)
    assert(fn, "Could not load file ".. filename)
	if type(fn) == "string" then
		assert(false, "Error loading file "..filename.."\n"..fn)
	end
    assert( type(fn) == "function", "Prefab file doesn't return a callable chunk: "..filename)
	local ret = {fn()}

	if ret then
		for i,val in ipairs(ret) do
			if type(val)=="table" and val.is_a and val:is_a(Prefab) then
				RegisterPrefabs(val)
			end
		end
	end

	return ret
end

function RegisterAchievements(achievements)
    for i, achievement in ipairs(achievements) do
        --print ("Registering achievement:", achievement.name, achievement.id.steam, achievement.id.psn)
        TheGameService:RegisterAchievement(achievement.name, achievement.id.steam, achievement.id.psn)        
    end
end

function LoadAchievements( filename )
	--print("Loading achievement file "..filename)
    local fn, r = loadfile(filename)
    assert(fn, "Could not load file ".. filename)
	if type(fn) == "string" then
		assert(false, "Error loading file "..filename.."\n"..fn)
	end
    assert( type(fn) == "function", "Achievements file doesn't return a callable chunk: "..filename)
	local ret = {fn()}

	if ret then
		for i,val in ipairs(ret) do
			if type(val)=="table" then --and val.is_a and val:is_a(Achievements)then
				RegisterAchievements(val)
			end
		end
	end

	return ret
end

function SpawnPrefabFromSim(name)
    name = string.sub(name, string.find(name, "[^/]*$"))      
	name = string.lower(name)
	
    local prefab = Prefabs[name]
	if prefab == nil then
		print( "Can't find prefab " .. tostring(name) )
		return -1
	end

    if prefab then
        local inst = prefab.fn(TheSim)

        if inst ~= nil then

            inst:SetPrefabName(inst.prefab or name)

			for k,mod in pairs(prefab.modfns) do
				mod(inst)
			end
            
            return inst.entity:GetGUID()
        else
            print( "Failed to spawn", name )
            return -1
        end
    end
end

function PrefabExists(name)
    return Prefabs[name] ~= nil
end

local renames = 
{
    feather = "feather_crow",
}

function SpawnPrefab(name)
    name = string.sub(name, string.find(name, "[^/]*$"))      
    name = renames[name] or name
    local guid = TheSim:SpawnPrefab(name)
    return Ents[guid]
end

function SpawnSaveRecord(saved, newents)
    --print(string.format("SpawnSaveRecord [%s, %s, %s]", tostring(saved.id), tostring(saved.prefab), tostring(saved.data)))
    
    local inst = SpawnPrefab(saved.prefab)
    
    if inst then
		inst.Transform:SetPosition(saved.x or 0, saved.y or 0, saved.z or 0)
        if newents then
            
            --this is kind of weird, but we can't use non-saved ids because they might collide
            if saved.id  then
				newents[saved.id] = {entity=inst, data=saved.data} 
			else
				newents[inst] = {entity=inst, data=saved.data} 
			end
			
        end

		-- Attach scenario. This is a special component that's added based on save data, not prefab setup.
		if saved.scenario or (saved.data and saved.data.scenariorunner) then
			if inst.components.scenariorunner == nil then
				inst:AddComponent("scenariorunner")
			end
			if saved.scenario then
				inst.components.scenariorunner:SetScript(saved.scenario)
			end
		end

        inst:SetPersistData(saved.data, newents)

    else
        print(string.format("SpawnSaveRecord [%s, %s] FAILED", tostring(saved.id), saved.prefab))
    end

    return inst
end

function CreateEntity()
    local ent = TheSim:CreateEntity()
    local guid = ent:GetGUID()
    local scr = EntityScript(ent)
    Ents[guid] = scr
    NumEnts = NumEnts + 1
    return scr
end


local debug_entity = nil

function OnRemoveEntity(entityguid)
    
    PhysicsCollisionCallbacks[entityguid] = nil

    local ent = Ents[entityguid]
    if ent then
    	
		if debug_entity == ent then
			debug_entity = nil
		end
		
        BrainManager:OnRemoveEntity(ent)
        SGManager:OnRemoveEntity(ent)
        ent:KillTasks()
        NumEnts = NumEnts - 1
        Ents[entityguid] = nil
        
        if UpdatingEnts[entityguid] then
            UpdatingEnts[entityguid] = nil
            num_updating_ents = num_updating_ents - 1
        end

        if WallUpdatingEnts[entityguid] then
            WallUpdatingEnts[entityguid] = nil
        end
    end
end


function PushEntityEvent(guid, event, data)
    local inst = Ents[guid]
    if inst then
        inst:PushEvent(event, data)
    end
end

------TIME FUNCTIONS

function GetTickTime()
    return TheSim:GetTickTime()
end

local ticktime = GetTickTime()
function GetTime()
    return TheSim:GetTick()*ticktime
end

function GetTick()
    return TheSim:GetTick()
end

function GetTimeReal()
    return TheSim:GetRealTime()
end

---SCRIPTING
local Scripts = {}

function LoadScript(filename)
    if not Scripts[filename] then
        local scriptfn = loadfile("scripts/" .. filename)
    	assert(type(scriptfn) == "function", scriptfn)
        Scripts[filename] = scriptfn()
    end
    return Scripts[filename]
end


function RunScript(filename)
    local fn = LoadScript(filename)
    if fn then
        fn()
    end
end

function GetEntityString(guid)
    local ent = Ents[guid]

    if ent then
        return ent:GetDebugString()
    end

    return ""
end

function GetExtendedDebugString()
	if debug_entity and debug_entity.brain then
		return debug_entity:GetBrainString()
	elseif SOUNDDEBUG_ENABLED then
	    return GetSoundDebugString()
	end
	return ""
end

function GetDebugString()
 
	local str = {}
	table.insert(str, tostring(scheduler))
	
	if debug_entity then
		table.insert(str, "\n-------DEBUG-ENTITY-----------------------\n")
		table.insert(str, debug_entity.GetDebugString and debug_entity:GetDebugString() or "<no debug string>")
	end
	
    return table.concat(str)
end

function GetDebugEntity()
	return debug_entity
end

function SetDebugEntity(inst)
	if debug_entity then
		debug_entity.entity:SetSelected(false)
	end
	debug_entity = inst
	if inst then
		inst.entity:SetSelected(true)
	end
end

function OnEntitySleep(guid)
    local inst = Ents[guid]
    if inst then
        
        if inst.OnEntitySleep then
			inst:OnEntitySleep()
        end
        
        
		inst:StopBrain()        

        if inst.sg then
            SGManager:Hibernate(inst.sg)
        end

		if inst.emitter then
			EmitterManager:Hibernate(inst.emitter)
		end

        for k,v in pairs(inst.components) do
            
            if v.OnEntitySleep then
                v:OnEntitySleep()
            end
        end

    end
end

function OnEntityWake(guid)
    local inst = Ents[guid]
    if inst then
    
        if inst.OnEntityWake then
			inst:OnEntityWake()
        end

        if not inst:IsInLimbo() then
			inst:RestartBrain()
			if inst.sg then
	            SGManager:Wake(inst.sg)
			end
		end
		
		if inst.emitter then
			EmitterManager:Wake(inst.emitter)
		end


        for k,v in pairs(inst.components) do
            if v.OnEntityWake then
                v:OnEntityWake()
            end
        end
    end
end

------------------------------

function PlayNIS(nisname, lines)
    local nis = require ("nis/"..nisname)
    local inst = CreateEntity()

    inst:AddComponent("nis")
    inst.components.nis:SetName(nisname)
    inst.components.nis:SetInit(nis.init)
    inst.components.nis:SetScript(nis.script)
    inst.components.nis:SetCancel(nis.cancel)
    inst.entity:CallPrefabConstructionComplete()
    inst.components.nis:Play(lines)
    return inst
end



local paused = false
local default_time_scale = 1

function IsPaused()
    return paused
end

global("PlayerPauseCheck")  -- function not defined when this file included


function SetDefaultTimeScale(scale)
	default_time_scale = scale
	if not paused then
		TheSim:SetTimeScale(default_time_scale)
	end
end

function SetPause(val,reason)
    if val ~= paused then
		if val then
			paused = true
			TheSim:SetTimeScale(0)
			TheMixer:PushMix("pause")
		else
			paused = false
			TheSim:SetTimeScale(default_time_scale)
			TheMixer:PopMix("pause")
			--ShowHUD(true)
		end
        if PlayerPauseCheck then   -- probably don't need this check
            PlayerPauseCheck(val,reason)  -- must be done after SetTimeScale
        end
	end
end

function IsPaused()
    return paused
end


--- EXTERNALLY SET GAME SETTINGS ---
Settings = {}
function SetInstanceParameters(settings)
    if settings ~= "" then
        --print("SetInstanceParameters:",settings)
        Settings = json.decode(settings)
    end
end

Purchases = {}
function SetPurchases(purchases)
	if purchases ~= "" then
		Purchases = json.decode(purchases)
	end
end


function SaveGame(savename, cb)
	local callback = function() SaveGameIndex:Save(cb) end

    local save = {}
    save.ents = {}

    --print("Saving...")
    
    --save the entities
    local nument = 0
    local saved_ents = {}
    local references = {}
    for k,v in pairs(Ents) do
        if v.persists and v.prefab and v.Transform and v.entity:GetParent() == nil and v:IsValid() then
            local x, y, z = v.Transform:GetWorldPosition()
            local record, new_references = v:GetSaveRecord()
            record.prefab = nil
            
            if new_references then
				references[v.GUID] = true
				for k,v in pairs(new_references) do
					references[v] = true
				end
			end
			
			saved_ents[v.GUID] = record
			
			if save.ents[v.prefab] == nil then
				save.ents[v.prefab] = {}
			end
            table.insert(save.ents[v.prefab], record)
			record.prefab = nil
            nument = nument + 1
        end
    end
    

    --save out the map
    save.map = {
        revealed = "",
        tiles = "",
        roads = Roads,
    }
    
    local new_refs = nil
    local ground = GetWorld()
    assert(ground, "Cant save world without ground entity")
    if ground then
        save.map.prefab = ground.prefab
        save.map.tiles = ground.Map:GetStringEncode()
        save.map.nav = ground.Map:GetNavStringEncode()
        save.map.width, save.map.height = ground.Map:GetSize()
        save.map.topology = ground.topology
        save.map.persistdata, new_refs = ground:GetPersistData()
        save.meta = ground.meta
        save.map.hideminimap = ground.hideminimap
        
        
		if new_refs then
			for k,v in pairs(new_refs) do
				references[v] = true
			end
		end
    end
    
    local player = GetPlayer()
    assert(player, "Cant save world without player entity")
    if player then
        save.playerinfo = {}
        save.playerinfo, new_refs = player:GetSaveRecord()
        save.playerinfo.id = player.GUID --force this for the player
		if new_refs then
			for k,v in pairs(new_refs) do
				references[v] = true
			end
		end
    end   
    
    
    for k,v in pairs(references) do
		if saved_ents[k] then
			saved_ents[k].id = k
		else
			print ("Can't find", k, Ents[k])
		end
    end

	save.mods = ModManager:GetModRecords()
    save.super = WasSuUsed()
    
    assert(save.map, "Map missing from savedata on save")
    assert(save.map.prefab, "Map prefab missing from savedata on save")
    assert(save.map.tiles, "Map tiles missing from savedata on save")
    assert(save.map.width, "Map width missing from savedata on save")
   	assert(save.map.height, "Map height missing from savedata on save")
	--assert(save.map.topology, "Map topology missing from savedata on save")
        
	assert(save.playerinfo, "Playerinfo missing from savedata on save")
	assert(save.playerinfo.x, "Playerinfo.x missing from savedata on save")
	--assert(save.playerinfo.y, "Playerinfo.y missing from savedata on save")   --y is often omitted for space, don't check for it
	assert(save.playerinfo.z, "Playerinfo.z missing from savedata on save")
	--assert(save.playerinfo.day, "Playerinfo day missing from savedata on save")
		
	assert(save.ents, "Entites missing from savedata on save")
	assert(save.mods, "Mod records missing from savedata on save")
    
    
	local data = DataDumper(save, nil, BRANCH ~= "dev")
    local insz, outsz = SavePersistentString(savename, data, ENCODE_SAVES, callback)
    print ("Saved", savename, outsz)
    
    
    if player.HUD then
		player:PushEvent("ontriggersave")
    end
    
end

function ShowHUD(val)
    local MainCharacter = GetPlayer()
	if MainCharacter then
		local HUD = MainCharacter.HUD
		if HUD then
			if val then
				HUD:Show()	
			else
				HUD:Hide()	
			end
		end
	end
end


function ProcessJsonMessage(message)
    --print("ProcessJsonMessage", message)
	
	local player = GetPlayer()
    
    local command = TrackedAssert("ProcessJsonMessage",  json.decode, message) 
    
    -- Sim commands
    if command.sim ~= nil then
		--print( "command.sim: ", command.sim )
    	--print("Sim command", message)
    	if command.sim == 'toggle_pause' then
    		--TheSim:TogglePause()
			SetPause(not IsPaused())
		elseif command.sim == 'upsell_closed' then
			HandleUpsellClose()
		elseif command.sim == 'quit' then
    		if player then
    			player:PushEvent("quit", {})
    		end
    	elseif type(command.sim) == 'table' and command.sim.playerid then
			TheFrontEnd:SendScreenEvent("onsetplayerid", command.sim.playerid)
    	end
    end
end

function LoadFonts()
	for k,v in pairs(FONTS) do
		TheSim:LoadFont(v.filename, v.alias)
	end
end

function UnloadFonts()
	for k,v in pairs(FONTS) do
		TheSim:UnloadFont(v.filename)
	end
end

function Start()
	if SOUNDDEBUG_ENABLED then
		require "debugsounds"
	end
	-- 界面管理器。不管它了。
	---The screen manager
	TheFrontEnd = FrontEnd()-- FrontEnd在frontend.lua中定义的	
	-- 载入游戏逻辑！关键部分！
	require ("gamelogic")
	-- 载入mod？todo
    if MODS_ENABLED then
        --after starting everything up, give the mods additional environment variables
        ModManager:SetPostEnv(GetPlayer())
	    --By this point the game should have either a) disabled bad mods, or b) be interactive
	    KnownModIndex:EndStartupSequence(nil) -- no callback, this doesn't need to block and we don't need the results
	end
	-- 显示初始化过程中的错误信息
	--If we collected a non-fatal error during startup, display it now!
	for i,err in ipairs(PendingErrors) do
		DisplayError(err)
	end
end



--------------------------

exiting_game = false

-- Gets called ONCE when the sim first gets created. Does not get called on subsequent sim recreations!
function GlobalInit()
	TheSim:LoadPrefabs({"global"})
	LoadFonts()
end

function StartNextInstance(in_params, send_stats)
	local params = in_params or {}
	params.last_reset_action = Settings.reset_action

	if send_stats then
		SendAccumulatedProfileStats()
	end
	
	SimReset(params)
end

function SimReset(instanceparameters)

	ModManager:UnloadPrefabs()

	if not instanceparameters then
		instanceparameters = {}
	end
	instanceparameters.last_asset_set = Settings.current_asset_set
	local params = json.encode(instanceparameters)
	TheSim:SetInstanceParameters(params)
	TheSim:Reset()
end

function RequestShutdown()
	if exiting_game then
		return
	end
	exiting_game = true

	TheFrontEnd:PushScreen(
		PopupDialogScreen( STRINGS.UI.QUITTINGTITLE, STRINGS.UI.QUITTING,
		  {  }
		  )
	)
	
	-----------------------------------------------------------------------------	
	-- Anything below here may not run if we don't have stats that need updating
	-----------------------------------------------------------------------------
	
	local stats = GetProfileStats(true)
	if string.len(stats) <= 12 then -- empty stats are '{"stats":[]}'
		Shutdown()
		return
	end

	SubmitExitStats()
end

function Shutdown()
	Print(VERBOSITY.DEBUG, 'Ending the sim now!')
	SubmitQuitStats()
	
	UnloadFonts()
	
	for i,file in ipairs(PREFABFILES) do -- required from prefablist.lua
		LoadPrefabFile("prefabs/"..file)
	end	

	TheSim:UnloadAllPrefabs()
	ModManager:UnloadPrefabs()
		
	TheSim:Quit()
end

PendingErrors = {}

function DisplayError(error)
	if not TheFrontEnd then
		print("Error error! We tried displaying an error but TheFrontEnd isn't ready yet...")
		table.insert(PendingErrors, error)
		return
	end

    SetPause(true,"DisplayError")
    if TheFrontEnd:IsDisplayingError() then
        return nil
    end

    local modnames = ModManager:GetEnabledModNames()

    if #modnames > 0 then
        local modnamesstr = ""
        for k,modname in ipairs(modnames) do
            modnamesstr = modnamesstr.."\""..KnownModIndex:GetModFancyName(modname).."\" "
        end

        TheFrontEnd:DisplayError(
            ScriptErrorScreen(
                STRINGS.UI.MAINSCREEN.MODFAILTITLE, 
                error,
                {
                    {text=STRINGS.UI.MAINSCREEN.SCRIPTERRORQUIT, cb = function() TheSim:ForceAbort() end},
					{text=STRINGS.UI.MAINSCREEN.MODQUIT, cb = function()
																	KnownModIndex:DisableAllMods()
																	KnownModIndex:Save(function()
																		SimReset()
																	end)
																end},
                    {text=STRINGS.UI.MAINSCREEN.MODFORUMS, nopop=true, cb = function() VisitURL("http://forums.kleientertainment.com/index.php?/forum/26-dont-starve-mods-and-tools/") end }
                },
                ANCHOR_LEFT,
                STRINGS.UI.MAINSCREEN.SCRIPTERRORMODWARNING..modnamesstr,
                20
                ))
    else
        TheFrontEnd:DisplayError(
            ScriptErrorScreen(
                STRINGS.UI.MAINSCREEN.MODFAILTITLE, 
                error,
                {
                    {text=STRINGS.UI.MAINSCREEN.SCRIPTERRORQUIT, cb = function() TheSim:ForceAbort() end},
                    {text=STRINGS.UI.MAINSCREEN.FORUM, nopop=true, cb = function() VisitURL("http://forums.kleientertainment.com/index.php?/forum/26-dont-starve-mods-and-tools/") end }
                },
                ANCHOR_LEFT,
                nil,
                20
                ))
    end
end

function SetPauseFromCode(pause)
    if pause then
        if inGamePlay and not IsPaused() then
			local PauseScreen = require "screens/pausescreen"
            TheFrontEnd:PushScreen(PauseScreen())
        end
    end
end

function InGamePlay()
	return inGamePlay
end