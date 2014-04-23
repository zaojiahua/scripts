local print_loggers = {}

function AddPrintLogger( fn )
    table.insert(print_loggers, fn)
end

global("CWD")-- current working directory ��ǰ����Ŀ¼

local dir = CWD or ""
dir = string.gsub(dir, "\\", "/") .. "/"-- ��·���е�'\'�ַ������'//'
local oldprint = print
-- ������Lua�е���������ƥ���ַ���^$()%.[]*+-?z��
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
-- ��pattern�е����������ַ�����ת��
function escape_lua_pattern(s)
	return (s:gsub(".", matches))-- gsub�˴�����ԭ������s�е�ÿ���ַ��������matches�е�һ��index������������Ӧ��ֵ�滻����ַ���
end
-- ������ַ������ӳ�һ���ַ�����ʹ��\t�ָ�
local function packstring(...)
    local str = ""
    for i,v in ipairs({...}) do
        str = str..tostring(v).."\t"
    end
    return str
end
--this wraps print in code that shows what line number it is coming from, and pushes it out to all of the print loggers
--���°�װһ��print������֮����Ҫ��װ����Ϊ����ͬʱ���ö����ӡ����������ͬʱ��ӡ����Ļ����־�ļ���
print = function(...)
	-- Sl��ʾϣ����õ���Ϣ����
	-- source,short_src,linedefined,lastlinedefined,what;  currentline;
	local info = debug.getinfo(2, "Sl")
	local source = info.source
	local str = ""	
	if info.source and string.sub(info.source,1,1)=="@" then-- sub����������ȡsource�ַ����ĵ�һ���ַ�
		source = source:sub(2)
		source = source:gsub("^"..escape_lua_pattern(dir), "")-- ���Ǹ���ģ�ȥ��·�����𣿣�����todo
		str = string.format("%s(%d,1) %s", tostring(source), info.currentline, packstring(...))
	else
		str = packstring(...)--�ϲ����в���Ϊһ���ַ���
	end

	for i,v in ipairs(print_loggers) do-- �������еĴ�ӡ������
		v(str)
	end

end

--This is for times when you want to print without showing your line number (such as in the interactive console)
-- ֱ�Ӵ�ӡ�������ɣ�
nolineprint = function(...)
    for i,v in ipairs(print_loggers) do
        v(...)
    end
    
end

-- ���涨���ӡ����PrintLogger��
---- This keeps a record of the last n print lines, so that we can feed it into the debug console when it is visible
local debugstr = {}-- ����Ctrl+L�Ϳ��Կ�����ӡ�����ĺܶ�����Ϣ�ˣ���Щ��Ϣ�ͱ���������ѽ��
local MAX_CONSOLE_LINES = 20

local consolelog = function(...)
    
    local str = packstring(...)
    str = string.gsub(str, dir, "")

    for idx,line in ipairs(string.split(str, "\r\n")) do-- ������Ϳ���֪�����ǿ���һ�ε��ô�ӡ���У�ֻҪ������\r\n�ָ����ɣ�
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
-- ���������һ������Ļ�����ӡ��Ϣ�ĺ�����Ҳ����Ϸ�����Ψһһ��PrintLogger�������������������ǿ�����Ӹ���PrintLogger��
-- consolelogҲֻ�Ǽ�¼Ҫ��ӡ����Ϣ���ѣ�����Ĵ�ӡ�����������ɣ�ͨ��GetConsoleOutputList��ȡ�ַ�����Ȼ��������ɴ�ӡ��
AddPrintLogger(consolelog)

