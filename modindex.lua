require("mods")
require("modutil")

local function modprint(...)
	--print(type(...) == "table" and unpack(...) or ...)
end


ModIndex = Class(function(self)
	self.startingup = false
	self.cached_data = {}
	self.savedata =
	{
		known_mods = { },
		known_api_version = 0,
	}
end)
--[[
known_mods = {
	[modname] = {
		enabled = true,
		disabled_bad = true,
		disabled_old = true,
		modinfo = {
			version = "1.2",
			api_version = 2,
			old = true,
			failed = false,
		},
	}
}
--]]

function ModIndex:GetModIndexName()
	local name = "modindex" 
	if BRANCH ~= "release" then
		name = name .. "_"..BRANCH
	end
	return name
end

function ModIndex:BeginStartupSequence(callback)
	self.startingup = true
	local filename = "boot_"..self:GetModIndexName()
	TheSim:GetPersistentString(filename,
		function(load_success, str)
			if load_success and str == "loading" then
				local modsenabled = self:GetModsToLoad()
				if #modsenabled > 0 then
					self.badload = true
					print("ModIndex: Detected bad load, disabling all mods.")
					self:DisableAllMods()
					self:Save(nil) -- write to disk that all mods were disabled!
				end
				callback()
			else
				--print("ModIndex: Beginning normal load sequence.\n")
				SavePersistentString(filename, "loading", false, callback)
			end
		end)
end

function ModIndex:EndStartupSequence(callback)
	self.startingup = false
	local filename = "boot_"..self:GetModIndexName()
	SavePersistentString(filename, "done", false, callback)
	print("ModIndex: Load sequence finished successfully.\n")
end

function ModIndex:WasLoadBad()
	return self.badload == true
end

function ModIndex:GetModNames()
	local names = {}
	for name,_ in pairs(self.savedata.known_mods) do
		table.insert(names, name)
	end
	return names
end

function ModIndex:Save(callback)
    if PLATFORM == "PS4" then
        return
    end
    
	local newdata = { known_mods = {} }
	newdata.known_api_version = MOD_API_VERSION

	for name, data in pairs(self.savedata.known_mods) do
		newdata.known_mods[name] = {}
		newdata.known_mods[name].enabled = data.enabled
		newdata.known_mods[name].disabled_bad = data.disabled_bad
		newdata.known_mods[name].disabled_old = data.disabled_old
		newdata.known_mods[name].seen_api_version = MOD_API_VERSION
		newdata.known_mods[name].modinfo = data.modinfo
	end

	--print("\n\n---SAVING MOD INDEX---\n\n")
	--dumptable(newdata)
	--print("\n\n---END SAVING MOD INDEX---\n\n")

	local data = DataDumper(newdata, nil, false)
    local insz, outsz = SavePersistentString(self:GetModIndexName(), data, ENCODE_SAVES, callback)
end

function ModIndex:GetModsToLoad(usecached)
	local cached = usecached or false

	local ret = {}
	if not cached then
		local moddirs = TheSim:GetModDirectoryNames()
		for i,moddir in ipairs(moddirs) do
			if self:IsModEnabled(moddir) or self:IsModForceEnabled(moddir) then
				table.insert(ret, moddir)
			end
		end
	else
		if self.savedata and self.savedata.known_mods then
			for modname, moddata in pairs(self.savedata.known_mods) do
				if self:IsModEnabled(modname) or self:IsModForceEnabled(modname) then
					table.insert(ret, modname)
				end
			end
		end
	end
	for i,modname in ipairs(ret) do
		if self:IsModStandalone(modname) then
			print("\n\n"..ModInfoname(modname).." Loading a standalone mod! No other mods will be loaded.\n")
			return { modname }
		end
	end
	return ret
end

function ModIndex:GetModInfo(modname)
	return self.savedata.known_mods[modname].modinfo or {}
end

function ModIndex:UpdateModInfo()
	modprint("Updating all mod info.")

	local modnames = TheSim:GetModDirectoryNames()

	for modname,moddata in pairs(self.savedata.known_mods) do
		if not table.contains(modnames, modname) then
			self.savedata.known_mods[modname] = nil
		end
	end
			

	for i,modname in ipairs(modnames) do
		if not self.savedata.known_mods[modname] then
			self.savedata.known_mods[modname] = {}
		end
		self.savedata.known_mods[modname].modinfo = self:LoadModInfo(modname)
	end
end


function ModIndex:LoadModInfo(modname)
	modprint(string.format("Updating mod info for '%s'", modname))

	local info = self:InitializeModInfo(modname)

	if info.old and self:IsModNewlyOld(modname) then
		modprint("  It's using an old api_version.")
		self:DisableBecauseOld(modname)
	elseif info.failed then
		modprint("  But there was an error loading it.")
		self:DisableBecauseBad(modname)
	else
		-- we've already "dealt" with this in the past; if the user
		-- chooses to enable it, then try loading it!
	end

	self.savedata.known_mods[modname].modinfo = info

	return info
end

function ModIndex:InitializeModInfo(modname)
	local env = {}
	local fn = kleiloadlua("../mods/"..modname.."/modinfo.lua")
	local modinfo_message = ""
	if type(fn) == "string" then
		print("Error loading mod: "..ModInfoname(modname).."!\n "..fn.."\n")
		--table.insert( self.failedmods, {name=modname,error=fn} )
		env.failed = true
	elseif not fn then
		modinfo_message = modinfo_message.."No modinfo.lua, using defaults... "
		env.old = true
	else
		local status, r = RunInEnvironment(fn,env)

		if status == false then
			print("Error loading mod: "..ModInfoname(modname).."!\n "..r.."\n")
			--table.insert( self.failedmods, {name=modname,error=r} )
			env.failed = true
		elseif env.api_version == nil or env.api_version < MOD_API_VERSION then
			local old = "Mod "..modname.." was built for an older version of the game and requires updating. (api_version is version "..tostring(env.api_version)..", game is version "..MOD_API_VERSION..".)"
			modinfo_message = modinfo_message.."Old API! (mod: "..tostring(env.api_version).." game: "..MOD_API_VERSION..") "
			env.old = true
		elseif env.api_version > MOD_API_VERSION then
			local old = "api_version for "..modname.." is in the future, please set to the current version. (api_version is version "..env.api_version..", game is version "..MOD_API_VERSION..".)"
			print("Error loading mod: "..ModInfoname(modname).."!\n "..old.."\n")
			--table.insert( self.failedmods, {name=modname,error=old} )
			env.failed = true
		else
			local checkinfo = { "name", "description", "author", "version", "forumthread", "api_version" }
			local missing = {}
			for i,v in ipairs(checkinfo) do
				if env[v] == nil then
					table.insert(missing, v)
				end
			end
			if #missing > 0 then
				local e = "Error loading modinfo.lua. These fields are required: " .. table.concat(missing, ", ")
				print (e)
				--table.insert( self.failedmods, {name=modname,error=e} )
				env.failed = true
			else
				-- everything loaded okay!
			end
		end
	end

	env.modinfo_message = modinfo_message

	return env
end


function ModIndex:GetModFancyName(modname)
	local knownmod = self.savedata.known_mods[modname]
	if knownmod and knownmod.modinfo and knownmod.modinfo.name then
		return knownmod.modinfo.name
	else
		return modname
	end
end

function ModIndex:Load(callback)

	self:UpdateModSettings()

    local filename = self:GetModIndexName()
    TheSim:GetPersistentString(filename,
        function(load_success, str)
        	if load_success == true then
				local success, savedata = RunInSandbox(str)
				if success and string.len(str) > 0 then
					self.savedata = savedata
					for k,info in pairs(self.savedata.known_mods) do
						info.was_enabled = info.enabled
					end
					--print ("loaded "..filename)
		--print("\n\n---LOADING MOD INDEX---\n\n")
		--dumptable(self.savedata)
		--print("\n\n---END LOADING MOD INDEX---\n\n")
				else
					print ("Could not load "..filename)
				end
			else
				print ("Could not load "..filename)
			end

			callback()
        end)
end

function ModIndex:IsModEnabled(modname)
	local known_mod = self.savedata.known_mods[modname]
	return known_mod and known_mod.enabled
end

function ModIndex:IsModForceEnabled(modname)
	return self.modsettings.forceenable[modname]
end

function ModIndex:IsModStandalone(modname)
	local known_mod = self.savedata.known_mods[modname]
	return known_mod and known_mod.modinfo and known_mod.modinfo.standalone == true
end

function ModIndex:IsModInitPrintEnabled()
	return self.modsettings.initdebugprint
end

-- Note: Installed means enabled + ran in this terminology
function ModIndex:WasModEnabled(modname)
	local known_mod = self.savedata.known_mods[modname]
	return known_mod and known_mod.was_enabled
end

function ModIndex:Disable(modname)
	if not self.savedata.known_mods[modname] then
		self.savedata.known_mods[modname] = {}
	end
	self.savedata.known_mods[modname].enabled = false
end

function ModIndex:DisableAllMods()
	for k,v in pairs(self.savedata.known_mods) do
		self:Disable(k)
	end
end

function ModIndex:DisableBecauseBad(modname)
	if not self.savedata.known_mods[modname] then
		self.savedata.known_mods[modname] = {}
	end
	self.savedata.known_mods[modname].disabled_bad = true
	self.savedata.known_mods[modname].enabled = false
end

function ModIndex:DisableBecauseOld(modname)
	if not self.savedata.known_mods[modname] then
		self.savedata.known_mods[modname] = {}
	end
	self.savedata.known_mods[modname].disabled_old = true
	self.savedata.known_mods[modname].enabled = false
end

function ModIndex:Enable(modname)
	if not self.savedata.known_mods[modname] then
		self.savedata.known_mods[modname] = {}
	end
	self.savedata.known_mods[modname].enabled = true
	self.savedata.known_mods[modname].disabled_bad = false
	self.savedata.known_mods[modname].disabled_old = false
end

function ModIndex:IsModNewlyBad(modname)
	local known_mod = self.savedata.known_mods[modname]
	if known_mod and known_mod.modinfo.failed then
		-- After a mod is disabled it can no longer fail;
		-- in addition, the index is saved when a mod fails.
		-- So we just have to check if the mod failed in the index
		-- and that indicates what happened last time.
		return true
	end
	return false
end

function ModIndex:KnownAPIVersion(modname)
	local known_mod = self.savedata.known_mods[modname]
	if not known_mod or not known_mod.modinfo then
		return -2 -- If we've never seen the mod before, we assume it's REALLY old
	elseif not known_mod.modinfo.api_version then
		return -1 -- If we've seen it but it has no info, it's just "Old"
	else
		return known_mod.modinfo.api_version
	end
end

function ModIndex:IsModNewlyOld(modname)
	if self:KnownAPIVersion(modname) < MOD_API_VERSION and
			self.savedata.known_mods[modname] and
			self.savedata.known_mods[modname].seen_api_version and
			self.savedata.known_mods[modname].seen_api_version < MOD_API_VERSION then
		return true
	end
	return false
end

function ModIndex:IsModNew(modname)
	return not self.savedata.known_mods[modname] or not self.savedata.known_mods[modname].modinfo
end

function ModIndex:IsModKnownBad(modname)
	return self.savedata.known_mods[modname] and self.savedata.known_mods[modname].disabled_bad
end

-- When the user changes settings it messes directly with the index data, so make a backup
function ModIndex:CacheSaveData()
	self.cached_data = {}
	self.cached_data.savedata = deepcopy(self.savedata)
	self.cached_data.modsettings = deepcopy(self.modsettings)
	return self.cached_data
end

-- If the user cancels their mod changes, restore the index to how it was prior the changes.
function ModIndex:RestoreCachedSaveData(ext_data)
	if ext_data then
		self.savedata = ext_data.savedata
		self.modsettings = ext_data.modsettings
	elseif self.cached_data then
		self.savedata = self.cached_data.savedata
		self.modsettings = self.cached_data.modsettings
	end
end
	
function ModIndex:UpdateModSettings()

	self.modsettings = {
		forceenable = {}
	}

	local function ForceEnableMod(modname)
		print("WARNING: Force-enabling mod '"..ModInfoname(modname).."' from modsettings.lua! If you are not developing a mod, please use the in-game menu instead.")
		self.modsettings.forceenable[modname] = true
	end
	local function EnableModDebugPrint()
		self.modsettings.initdebugprint = true
	end
	
	local env = {
		ForceEnableMod = ForceEnableMod,
		EnableModDebugPrint = EnableModDebugPrint,
	}

	local filename = "../mods/modsettings.lua"
	local fn = kleiloadlua( filename )
	assert(fn, "could not load modsettings: "..filename)
	if type(fn)=="string" then
		error("Error loading modsettings:\n"..fn)
	end
	setfenv(fn, env)
	fn()
end


KnownModIndex = ModIndex()
