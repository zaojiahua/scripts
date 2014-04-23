-- Override the package.path in luaconf.h because it is impossible to find
package.path = "scripts\\?.lua;scriptlibs\\?.lua"

--defines
MAIN = 1
ENCODE_SAVES = false--BRANCH ~= "dev"
CHEATS_ENABLED = true--BRANCH == "dev"
SOUNDDEBUG_ENABLED = false
MODS_ENABLED = true--PLATFORM ~= "PS4" and PLATFORM ~= "NACL"
ACCOMPLISHMENTS_ENABLED = false--PLATFORM == "PS4"
DEBUG_MENU_ENABLED = true --BRANCH == "dev" or PLATFORM == "PS4"
METRICS_ENABLED = true--PLATFORM ~= "WIN32"

--debug.setmetatable(nil, {__index = function() return nil end})  -- Makes  foo.bar.blat.um  return nil if table item not present   See Dave F or Brook for details

local servers =
{
	release = "http://dontstarve-release.appspot.com",
	dev = "http://dontstarve-dev.appspot.com",
	staging = "http://dontstarve-staging.appspot.com",
}
GAME_SERVER = servers[BRANCH]


TheSim:SetReverbPreset("default")

if PLATFORM == "NACL" then
	VisitURL = function(url, notrack)
		if notrack then
			TheSim:SendJSMessage("VisitURLNoTrack:"..url)
		else
			TheSim:SendJSMessage("VisitURL:"..url)
		end
	end
end

package.path = package.path .. ";scripts/?.lua"

if PLATFORM == "WIN32" then
	package.path = package.path .. ";scriptlibs/?.lua"
	--this is done strangely, because we statically link to luasocket. We statically link to lusocket because we statically link to lua. We statically link to lua because of NaCl. Boo.
	--anyway, you should be able to use luasocket as you would expect from this point forward (on windows at least).
	dofile("scriptlibs/socket.lua")
	dofile("scriptlibs/mime.lua")
end

--used for A/B testing and preview features. Gets serialized into and out of save games
GameplayOptions =
{
}


--install our crazy loader!
local loadfn = function(modulename)
	--print (modulename, package.path)
    local errmsg = ""
    local modulepath = string.gsub(modulename, "%.", "/")
    for path in string.gmatch(package.path, "([^;]+)") do
        local filename = string.gsub(path, "%?", modulepath)
        filename = string.gsub(filename, "\\", "/")
        local result = kleiloadlua(filename)-- 这应该是exe注册到lua中的一个全局函数
        if result then
            return result
        end
        errmsg = errmsg.."\n\tno file '"..filename.."' (checked with custom loader)"
    end
  return errmsg
end
table.insert(package.loaders, 1, loadfn)-- 替换掉默认的注册函数

--patch this function because NACL has no fopen
if TheSim then
    function loadfile(filename)
        filename = string.gsub(filename, ".lua", "")
        filename = string.gsub(filename, "scripts/", "")
        return loadfn(filename)
    end
end

if PLATFORM == "NACL" then
    package.loaders[2] = nil
elseif PLATFORM == "WIN32" then
end
-- 定义global函数；阻止使用未定义的全局变量！
require("strict")
-- 从这里开始所有的全局变量必须要用global函数“严格”声明！
-- 重新定义print为输出到屏幕的打印！
require("debugprint");
-- 从这里开始可以使用print来向屏幕输出一些东西了！
-- add our print loggers
AddPrintLogger(function(...) TheSim:LuaPrint(...) end)--估计TheSim:LuaPrint是调用了Lua函数GetConsoleOutputList获取字符串并打印的！

-- config里面require了class.lua文件，所以从这里开始就可以使用Class函数了！
-- 初始化TheConfig表，里面有配置信息
require("config")
-- Start函数中了gamelogic.lua哦！
require("mainfunctions")
require("mods")
require("json")
require("vector3")
require("tuning")
require("languages/language")
require("strings")
require("stringutil")
require("constants")
require("class")
require("actions")
require("debugtools")
require("simutil")
require("util")
require("scheduler")
require("stategraph")
require("behaviourtree")
require("prefabs")
require("entityscript")
require("profiler")
require("recipes")
require("brain")
require("emitters")
require("dumper")
require("input")
require("upsell")
require("stats")
require("frontend")

if METRICS_ENABLED then
require("overseer")
end

require("fileutil")
require("screens/scripterrorscreen")
require("prefablist")
require("standardcomponents")
require("update")
require("fonts")
require("physics")
require("modindex")
require("mathutil")
require("components/lootdropper")

require("saveindex") -- Added by Altgames for Android focus lost handling

if TheConfig:IsEnabled("force_netbookmode") then
	TheSim:SetNetbookMode(true)
end


--debug key init
if true then --CHEATS_ENABLED then
	require "debugkeys"
end


TheSystemService:SetStalling(true)

VERBOSITY_LEVEL = VERBOSITY.ERROR
if CONFIGURATION ~= "Production" then
	VERBOSITY_LEVEL = VERBOSITY.DEBUG
end

-- uncomment this line to override
VERBOSITY_LEVEL = VERBOSITY.WARNING

math.randomseed(TheSim:GetRealTime())

--instantiate the mixer
local Mixer = require("mixer")
TheMixer = Mixer.Mixer()
require("mixes")
TheMixer:PushMix("start")


Prefabs = {}
Ents = {}
AwakeEnts = {}
UpdatingEnts = {}
NewUpdatingEnts = {}
WallUpdatingEnts = {}
NewWallUpdatingEnts = {}
num_updating_ents = 0
NumEnts = 0

TheGlobalInstance = nil

global("TheCamera")
TheCamera = nil
global("SplatManager")
SplatManager = nil
global("ShadowManager")
ShadowManager = nil
global("RoadManager")
RoadManager = nil
global("EnvelopeManager")
EnvelopeManager = nil
global("PostProcessor")
PostProcessor = nil

global("FontManager")
FontManager = nil
global("MapLayerManager")
MapLayerManager = nil
global("Roads")
Roads = nil
global("TheFrontEnd")
TheFrontEnd = nil

inGamePlay = false

local function ModSafeStartup()

	-- If we failed to boot last time, disable all mods
	-- Otherwise, set a flag file to test for boot success.

	---PREFABS AND ENTITY INSTANTIATION

	ModManager:LoadMods()
	-- Apply translations
	TranslateStringTable( STRINGS )

	-- Register every standard prefab with the engine
	-- 哈哈，这里载入了所有的prefabs文件夹里面的文件！所以添加新物体需要到 PREFABFILES 里面去注册一下！
	for i,file in ipairs(PREFABFILES) do -- required from prefablist.lua
		LoadPrefabFile("prefabs/"..file)
	end
	ModManager:RegisterPrefabs()

    LoadAchievements("achievements.lua")

    require("cameras/followcamera")
    TheCamera = FollowCamera()

	--- GLOBAL ENTITY ---
	TheGlobalInstance = CreateEntity()
	TheGlobalInstance.entity:SetCanSleep( false )
	TheGlobalInstance.entity:AddTransform()

	if RUN_GLOBAL_INIT then
		GlobalInit()
	end
	SplatManager = TheGlobalInstance.entity:AddSplatManager()
	ShadowManager = TheGlobalInstance.entity:AddShadowManager()
	ShadowManager:SetTexture( "images/shadow.tex" )
	RoadManager = TheGlobalInstance.entity:AddRoadManager()
	EnvelopeManager = TheGlobalInstance.entity:AddEnvelopeManager()

	PostProcessor = TheGlobalInstance.entity:AddPostProcessor()
	local IDENTITY_COLOURCUBE = "images/colour_cubes/identity_colourcube.tex"
	PostProcessor:SetColourCubeData( 0, IDENTITY_COLOURCUBE, IDENTITY_COLOURCUBE )
	PostProcessor:SetColourCubeData( 1, IDENTITY_COLOURCUBE, IDENTITY_COLOURCUBE )

	FontManager = TheGlobalInstance.entity:AddFontManager()
	MapLayerManager = TheGlobalInstance.entity:AddMapLayerManager()

end

if not MODS_ENABLED then
	-- No mods in nacl, and the below functions are async in nacl
	-- so they break because Main returns before ModSafeStartup has run.
	ModSafeStartup()
else
	KnownModIndex:Load(function()
		KnownModIndex:BeginStartupSequence(function()
			ModSafeStartup()
		end)
	end)
end
TheSystemService:SetStalling(false)



TheInput:AddKeyUpHandler( KEY_J, function()
	local rabbit = SpawnPrefab( "trap");
	if rabbit then
		rabbit.Transform:SetPosition( TheInput:GetWorldPosition():Get());
	end
end);
TheInput:AddKeyUpHandler( KEY_K, function()
	local rabbit = SpawnPrefab( "houserabbit");
	if rabbit then
		rabbit.Transform:SetPosition( TheInput:GetWorldPosition():Get());
	end
end);
TheInput:AddKeyUpHandler( KEY_P, function()
	local rabbit = SpawnPrefab( "rabbit");
	if rabbit then
		rabbit.Transform:SetPosition( TheInput:GetWorldPosition():Get());
	end
end)
TheInput:AddKeyUpHandler( KEY_N, function()
	GetClock():NextPhase();
end);
