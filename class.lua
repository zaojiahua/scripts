-- class.lua
-- Compatible with Lua 5.1 (not 5.0).

local TrackClassInstances = false-- 这里还没有看懂？？？？？？？todo

if TrackClassInstances == true then
    global("ClassTrackingTable")
    global("ClassTrackingInterval")-- avoid warning :) 不这样的话就会被 strict.lua 文件报错哦 :)

    ClassTrackingInterval = 100
end

--[[
]]
function Class(base, _ctor) 
    local c = {}    -- _ctor的参数列表是 (self,...)，其中的self就是这里的c
	-- 如果是 Class(_ctor)形式进行调用的
    if not _ctor and type(base) == 'function' then
        _ctor = base
        base = nil
	-- 如果是 Class(baseTable,_ctor)形式调用的
    elseif type(base) == 'table' then
		-- our new class is a shallow copy of the base class!
		-- 相比于我的class继承的实现（metatable实现的），这里会占用更多的资源，但是更快（不用查metatable了）。
        for i,v in pairs(base) do
            c[i] = v
        end
        c._base = base-- 保存父类的信息（看来饥荒的class只支持单继承），以便在多级继承的时候判断一个实例是否是一个类或其子类的实例！见下面的is_a函数的实现！
    end
    
    -- the class will be the metatable for all its objects,
    -- and they will look up their methods in it.
    c.__index = c-- 这有什么意义呢？不懂！可能后来会把实例的__index执行class的__index吧？todo

    -- expose a constructor which can be called by <classname>(<args>)
	-- 下面使得类可以使用 ClassName( Arguments) 的形式创建实例！原理是 metatable.__call
    local mt = {}
    
    if TrackClassInstances == true then
        if ClassTrackingTable == nil then-- 第一次调用的时候创建table！
            ClassTrackingTable = {}
        end
        ClassTrackingTable[mt] = {}
		local dataroot = "@"..CWD.."\\"
        local tablemt = {}
        setmetatable(ClassTrackingTable[mt], tablemt)
        tablemt.__mode = "k"         -- now the instancetracker has weak keys
    
        local source = "**unknown**"
        if _ctor then
  	    -- what is the file this ctor was created in?

	    local info = debug.getinfo(_ctor, "S")
	    -- strip the drive letter
	    -- convert / to \\
	    source = info.source
	    source = string.gsub(source, "/", "\\")
            source = string.gsub(source, dataroot, "")
	    local path = source

	    local file = io.open(path, "r")
	    if file ~= nil then
	        local count = 1
   	        for i in file:lines() do
	            if count == info.linedefined then
                        source = i
		        -- okay, this line is a class definition
		        -- so it's [local] name = Class etc
		        -- take everything before the =
		        local equalsPos = string.find(source,"=")
		        if equalsPos then
			    source = string.sub(source,1,equalsPos-1)
		        end	
		        -- remove trailing and leading whitespace
                        source = source:gsub("^%s*(.-)%s*$", "%1")
		        -- do we start with local? if so, strip it
                        if string.find(source,"local ") ~= nil then
                            source = string.sub(source,7)
                        end
	                -- trim again, because there may be multiple spaces
                        source = source:gsub("^%s*(.-)%s*$", "%1")
                        break
	            end
                    count = count + 1
	        end
	        file:close()
	    end
        end
                             
        mt.__call = function(class_tbl, ...)
            local obj = {}
            setmetatable(obj,c)
            ClassTrackingTable[mt][obj] = source
            if c._ctor then
                c._ctor(obj,...)
            end
            return obj
        end    
    else
		-- 创建一个新的类实例的函数，相当于我写的类机制实现中的new函数，呵呵 :）
        mt.__call = function(class_tbl, ...)
            local obj = {}-- 新实例
            setmetatable(obj,c)
            if c._ctor then
               c._ctor(obj,...)
            end
            return obj
        end    
    end
    -- 保存构造函数
    c._ctor = _ctor	
    c.is_a = function(self, klass)
        local m = getmetatable(self)
        while m do 
            if m == klass then return true end
            m = m._base
        end
        return false
    end
    setmetatable(c, mt)
    return c
end

local lastClassTrackingDumpTick = 0

function HandleClassInstanceTracking()
    if TrackClassInstances then
        lastClassTrackingDumpTick = lastClassTrackingDumpTick + 1

        if lastClassTrackingDumpTick >= ClassTrackingInterval then
            collectgarbage()
            print("------------------------------------------------------------------------------------------------------------")
            lastClassTrackingDumpTick = 0
            if ClassTrackingTable then
                local sorted = {}
                local index = 1
                for i,v in pairs(ClassTrackingTable) do
                    local count = 0
                    local first = nil
                    for j,k in pairs(v) do
                        if count == 1 then
                            first = k
                        end
                        count = count + 1
                    end
                    if count>1 then
                        sorted[#sorted+1] = {first, count-1}
                    end
                    index = index + 1
                end
                -- get the top 10
                table.sort(sorted, function(a,b) return a[2] > b[2] end )
                for i=1,10 do
                    local entry = sorted[i]
                    if entry then
                        print(tostring(i).." : "..tostring(sorted[i][1]).." - "..tostring(sorted[i][2]))
                    end 
                end
                print("------------------------------------------------------------------------------------------------------------")
            end
        end
    end
end