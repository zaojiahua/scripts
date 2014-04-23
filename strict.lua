--[[
Ŀ�ģ�
1.�������ڵ�ȫ�ֱ�����ֵ��ʱ�򱨴�;
2.����һ������ȫ�ֱ����ĺ��� global(ȫ�ֱ���������)
]]
local mt = getmetatable(_G)
if mt == nil then
  mt = {}
  setmetatable(_G, mt)
end

__STRICT = true
mt.__declared = {}

mt.__newindex = function (t, n, v)-- table index value
  if __STRICT and not mt.__declared[n] then
    local w = debug.getinfo(2, "S").what -- ��ȡ������ֵ�ĺ�����Դ����Ϣ���������ǲ���LuaԴ�룿���������LuaԴ����what���ַ�����Lua����
    if w ~= "main" and w ~= "C" then
      error("assign to undeclared variable '"..n.."'", 2)
    end
    mt.__declared[n] = true
  end
  rawset(t, n, v)
end
  
mt.__index = function (t, n)
  if not mt.__declared[n] and debug.getinfo(2, "S").what ~= "C" then
    error("variable '"..n.."' is not declared", 2)
  end
  return rawget(t, n)
end

function global(...)
   for _, v in ipairs{...} do mt.__declared[v] = true end
end