=======
RECIPES
=======
Iterate an array:
```lua
for e in all(array) do
 ...
end
```

-----------------

Adding an element to an array:
```lua
add(array, e)
```

=========
 TRICKS
=========
Functions can return tuples:
```lua
function f()
  return 1, 3
end
a, b = f()
print(a..','..b) -- output: "1,3"
```

===============
DEBUG FUNCTIONS
===============
```lua
-- converts anything to string, even nested tables
function to_json(any, indent)
 if (type(any) ~= 'table') return tostr(any)

 local indent = indent and indent or 0
 local tab = ''
 for i = 1, indent do tab = tab..' ' end
 local str = '{\n'
 local first = true
 for k, v in pairs(any) do
  if (not first) str = str..',\n'
  str = str..tab..' "'..to_json(k)..'":'..to_json(v, indent + 1)
  first = false
 end
 return str..'\n'..tab..'}'
end

function stats()
  local cpu = flr(stat(1) * 100)
  local fps = stat(7)
  local perf = cpu.."% cpu @ "..fps.." fps"
  print(perf, 31, 2, 0)
  print(perf, 30, 1, 7)
end
```
=============
SAVING TOKENS
=============

Assigning `nil` costs 2 tokens:
```lua
-- 1 token
local a

-- 3 tokens
local a = nil
```

-----------------
Iterating over a sequence:

```lua
-- 9 tokens (6 without the local var v)
foreach(array, function(e) 
  local v=e
end)

-- 12 tokens
for i=1,#array do
  local v=array[i]
done
```

-----------------
Accessing a bidimensional array:
```lua
-- 18 tokens
-- treats 'a' as a bidimensional array
a={1,2,3, 2,3,4}
print(a[3*2+2])

-- also 18 tokens
-- 'a' is a bidimensional array
a={{1,2,3}, {2,3,4}}
print(a[2][2])
```

-----------------

Declaring a class with a method takes 27 tokens, initially:

```lua
p={}
p.__index = p
function p.new()
 local self = setmetatable({}, p)
 self.a={}
 return self
end

function p:a()
end
```

-----------------

Declaring a string doesn't take tokens for chars used:
```lua
a='aaaaaa'
```

is the same num of tokens as
```lua
a='a'
```

-----------------

Given the following table (bidimensional array):
```lua
t={
 {1,'a',3,'a'},
 {5,'b',4,'b'},
 {6,'c',4,'c'}, 
 {2,'d',6,'d'}
}
```

Deleting an element by reference:
```lua
-- 17 toks
foreach(t,function(tmr)
 if tmr[2]=='c' then
  del(t, tmr)
 end
end)

-- 18 toks
for tmr in all(t) do
 if tmr[2]=='c' then
  del(t, tmr)
 end
end

-----------------
Declaring an empty sequence takes 3 tokens:
```lua
a={} -- 3 tokens
```
Then one token for each element:
```lua
a={0,0,0,0,0,0,0,0} -- 8 + 3 = 11 tokens
```

Doing a `for` loop invoking `add` only pays off after
more than `10` elements:
```lua
--13 toks
a={}
for i=1,8 do
 add(a,0)
end
```

-----------------

Function declarations take 3 tokens, and 1 token
for each function parameter:

```lua
function f() -- 3 tokens
end

function h(a) -- 3 + 1 = 4 tokens
end

function g(a, b) -- 3 + 2 = 5 tokens
end
```

-----------------

Passing parameters as arrays can backfire
when it comes to token count:

```lua
-- 20 tokens
function f(c)
 print(c[1]..','..c[2])
end
f({1,2})
```

```lua
-- 12 tokens
function f(x, y)
  print(x..','..y)
end
```

==================
TOKEN SAVING MYTHS
==================

Declaring multiple local variables in one single line has the 
same token count:
```lua
-- 7 tokens
local a, b = 1

-- also 7 tokens
local a=1
local b
```
