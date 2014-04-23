--[[
目的：
1.给不存在的全局变量赋值的时候报错;
2.定义一个声明全局变量的函数 global(全局变量的名称)
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
    local w = debug.getinfo(2, "S").what -- 获取发生赋值的函数的源码信息（包含“是不是Lua源码？”，如果是Lua源码则what是字符串“Lua”）
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