local print_loggers = {}

function AddPrintLogger( fn )
    table.insert(print_loggers, fn)
end

global("CWD")-- current working directory 当前工作目录

local dir = CWD or ""
dir = string.gsub(dir, "\\", "/") .. "/"-- 将路径中的'\'字符都变成'//'
local oldprint = print
-- 下面是Lua中的所有特殊匹配字符（^$()%.[]*+-?z）
matches =
{
	["^"] = "%^",
	["$"] = "%$",
	["("] = "%(",
	[")"] = "%)",
	["%"] = "%%",
	["."] = "%.",
	["["] = "%[",
	["]"] = "%]",
	["*"] = "%*",
	["+"] = "%+",
	["-"] = "%-",
	["?"] = "%?",
	["\0"] = "%z",
}
-- 将pattern中的所有特殊字符进行转义
function escape_lua_pattern(s)
	return (s:gsub(".", matches))-- gsub此处工作原理：查找s中的每个字符，如果是matches中的一个index，则用索引对应的值替换这个字符。
end
-- 将多个字符串链接成一个字符串，使用\t分隔
local function packstring(...)
    local str = ""
    for i,v in ipairs({...}) do
        str = str..tostring(v).."\t"
    end
    return str
end
--this wraps print in code that shows what line number it is coming from, and pushes it out to all of the print loggers
--重新包装一下print函数。之所以要包装是因为可以同时调用多个打印函数，比如同时打印到屏幕和日志文件！
print = function(...)
	-- Sl表示希望获得的信息包括
	-- source,short_src,linedefined,lastlinedefined,what;  currentline;
	local info = debug.getinfo(2, "Sl")
	local source = info.source
	local str = ""	
	if info.source and string.sub(info.source,1,1)=="@" then-- sub函数用来获取source字符串的第一个字符
		source = source:sub(2)
		source = source:gsub("^"..escape_lua_pattern(dir), "")-- 这是干嘛的？去掉路径的吗？？？？todo
		str = string.format("%s(%d,1) %s", tostring(source), info.currentline, packstring(...))
	else
		str = packstring(...)--合并所有参数为一个字符串
	end

	for i,v in ipairs(print_loggers) do-- 调用所有的打印函数！
		v(str)
	end

end

--This is for times when you want to print without showing your line number (such as in the interactive console)
-- 直接打印参数即可！
nolineprint = function(...)
    for i,v in ipairs(print_loggers) do
        v(...)
    end
    
end

-- 下面定义打印函数PrintLogger！
---- This keeps a record of the last n print lines, so that we can feed it into the debug console when it is visible
local debugstr = {}-- 按下Ctrl+L就可以看到打印出来的很多行信息了，这些信息就保存在这里呀！
local MAX_CONSOLE_LINES = 20

local consolelog = function(...)
    
    local str = packstring(...)
    str = string.gsub(str, dir, "")

    for idx,line in ipairs(string.split(str, "\r\n")) do-- 从这里就可以知道我们可以一次调用打印多行，只要将其用\r\n分隔即可！
        table.insert(debugstr, line)
    end

    while #debugstr > MAX_CONSOLE_LINES do
        table.remove(debugstr,1)
    end
end

function GetConsoleOutputList()
    return debugstr
end

-- add our print loggers
-- 这里添加了一个向屏幕输出打印信息的函数，也是游戏里面的唯一一个PrintLogger。不过这里的设计让我们可以添加更多PrintLogger！
-- consolelog也只是记录要打印的信息而已，具体的打印操作由外界完成（通过GetConsoleOutputList获取字符串，然后真正完成打印）
AddPrintLogger(consolelog)

