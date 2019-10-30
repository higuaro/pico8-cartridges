pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
----------------------------------------
-- Constants
----------------------------------------
SCR_W = 128
SCR_H = 128
HLF_W = 64
HLF_H = 64


BTN_LEFT_1 = 0
BTN_RIGHT_1 = 1
BTN_UP_1 = 2
BTN_DOWN_1 = 3
-- actions buttons B A (like the NES)
BTN_B_1 = 4
BTN_A_1 = 5

-- math constants
-- infinity
oo = 9999

-- game constants
ROWS = 13
COLS = 8
BLOCK = 8

COLOURS = 7

-- predefined tetraminoes
L = {
 {0, 1, 0},
 {0, 1, 0},
 {0, 1, 1}
}
J = {
 {0, 1, 0},
 {0, 1, 0},
 {1, 1, 0}
}
Z = {
 {0, 0, 0},
 {1, 1, 0},
 {0, 1, 1}
}
S = {
 {0, 0, 0},
 {0, 1, 1},
 {1, 1, 0}
}
T = {
 {0, 0, 0},
 {1, 1, 1},
 {0, 1, 0}
}
O = {
 {1, 1},
 {1, 1}
}
I = {
 {0, 1, 0, 0},
 {0, 1, 0, 0},
 {0, 1, 0, 0},
 {0, 1, 0, 0}
}
PIECES = { L, J, Z, S, T, O, I }


----------------------------------------
-- Globals
----------------------------------------

-- difficulty : int[0..10] = level of difficulty
--                           0 (easiest)
--                           10 (most difficult)
difficulty = 0

timers = nil

players = nil


----------------------------------------
-- Classes
----------------------------------------

----------------------------------------
-- class Scheduler
----------------------------------------
Scheduler = {}
Scheduler.__index = Scheduler

-- constructor
function Scheduler.new()
 local self = setmetatable({}, Scheduler)
 self.last_time = time()
 self.timers = {}
 return self
end

--[[
 Adds a timer

 params:
 -------
 id : string = id of the timer
 time : float = seconds before a timer tick
 on_step : f(timer) -- function to run on each tick
 [ctx : {}] = additional data to pass to the timer
 [steps : int] = max number of ticks for the timer,
                 omit it to run indefinitely
]]--
function Scheduler:add_timer(id, time, on_step, ctx, steps)
 self.timers[id] = {
  time = time,
  ellapsed = 0,
  step = 0,
  steps = steps,
  ctx = ctx and ctx or {},
  step_fn = on_step
 }
end

function Scheduler:remove(name)
 if self.timers[name] then
  rawset(self.timers, name, nil)
 end
end

function Scheduler:reset(name)
 self.timers[name].step = 0
 self.timers[name].ellapsed = 0
end

function Scheduler:update()
 local dt = time() - self.last_time
 for id, timer in pairs(self.timers) do
  timer.ellapsed += dt
  if timer.ellapsed >= timer.time then
   timer.step += 1
   timer:step_fn()
   timer.ellapsed = 0
   if timer.steps and timer.step >= timer.steps then 
    self:remove(id)
   end
  end
 end
 self.last_time = time()
end

----------------------------------------
-- class RNG (Random Number Gen)
----------------------------------------
RNG = {}
RNG.__index = RNG

-- constructor
function RNG.new(seed)
 local self = setmetatable({}, RNG)
 self.state = seed
 return self
end

--[[
 Produces a random value within [a, b]
 (both inclusive), using LCG algorithm:
   r_n = (A * r_n-1) mod C
 Values for A and C come from paper:
 "Tables of Linear Congruential Generators of
  Different Sizes and good Lattice Structure"
 (A, C) = (219, 30805)

 params
 ------
 a : int = min value of the range
 b : int = max value of the range
]]--

function RNG:rand(a, b)
 if a == b then return a end
 local s = self.state
 s = (219 * s) % 30805
 self.state = s
 return (s % (b - a + 1)) + a
end

----------------------------------------
-- class Piece
----------------------------------------
Piece = {}
Piece.__index = Piece

--[[
 Constructor

 params
 ------
 attributes : {} = {
   1 : int[1..7] = index to use in the PIECE array
   2 : int[1..7] = colour
   3 : int[0..3] = number of 90° rotations to apply
 }
]]--
function Piece.new(attributes)
 local self = setmetatable({}, Piece)

 local index = attributes[1]
 local colour = attributes[2]
 local steps = attributes[3]

 local blocks = PIECES[index]
 local rows = #blocks
 local cols = #blocks[1]

 self.colour = colour
 self.rows = rows
 self.cols = cols

printh("blocks")
printh(a2s(blocks, rows, cols))
 self.blocks = array2d(rows, cols, blocks, colour)
 self:rotate(steps)
printh("after rotate steps="..steps)
printh(a2s(self.blocks, rows, cols))
printh("---")

 -- position within a board
 self.row, self.col = 0, 0

 return self
end

--[[
 Rotates the piece 90 degrees clockwise

 param
 -----
 steps : int[0..3]: number of 90° rotations
]]--
function Piece:rotate(steps)
 if steps == 0 then return end
 local rows = self.rows
 local cols = self.cols
 local dest = array2d(rows, cols)
 for r = 1, rows do
  for c = 1, cols do
   local nr = rows - r + 1
   local nc = cols - c + 1

   local dr, dc = c, nr
   if steps == 2 then
    dr, dc = nc, nr
   elseif steps == 3 then
    dr, dc = nc, r
   end

   dest[dr][dc] = self.blocks[r][c]
  end
 end

 local trash = self.blocks
 self.blocks = dest

 -- Discard previous blocks
 for k in next, trash do
  rawset(trash, k, nil)
 end
end

--[[
 Finds the first available position
 on the top row of the board, where this
 piece fits without applying any rotation.

 If found, assigns this piece's (row, col)
 positions, otherwise, sets them to (0, 0)

 param
 -----
 board : array2d = current game board for player

 returns : bool = if a slot that fits is found
]]--
function Piece:find_slot(board)
 local s = self
 local b = bbox(s.blocks, s.rows, s.cols)
 local w = b.max_c - b.min_c + 1

 -- row = 1 - box.min_row + 1
 local row = 2 - b.min_r

 -- center = [(COLS - w) / 2] + 1 - (b.min_c - 1)
 local center = flr((COLS - w) / 2) + 2 - b.min_c
 local slots = {}
 for c = -s.cols, COLS do
  if not self:collides(board, row, c) then
   -- record slot pos and dist to center
   add(slots, {c, abs(center - c)})
  end
 end

 local min_d, col = oo, 0
 for _, slot in pairs(slots) do
  if slot[2] < min_d then
   col = slot[1]
   min_d = slot[2]
  end
 end

 if min_d != oo then
  self.row, self.col = row, col
  return true
 else
  self.row, self.col = 0, 0
  return false
 end
end

--[[
 Checks if this piece either is out of bounds
 or if the piece collides with the board's content

 params
 ------
 board : array2d = current player's board
 pos_r : int = piece left-top corner row
 pos_c : int = piece left-top corner column

 returns: bool
]]--
function Piece:collides(board, pos_r, pos_c)
 local b = self.blocks
 for r = 1, self.rows do
  for c = 1, self.cols do
   if b[r][c] != 0 then
    local b_r = pos_r + r - 1
    local b_c = pos_c + c - 1
    if  b_r < 1 or b_r > ROWS
     or b_c < 1 or b_c > COLS
     or board[b_r][b_c] != 0
    then
     return true
    end
   end
  end
 end
 return false
end

function Piece:draw(x, y, block_size)
 local b = self.blocks
 local bs = block_size
 for r = 1, self.rows do
  for c = 1, self.cols do
   if b[r][c] != 0 then
    draw_block(x + (c - 1) * bs, --
               y + (r - 1) * bs, --
               self.colour, bs)
   end
  end
 end
end

function Piece:draw_ghost(board, x, y)
 local b = self.blocks
 local left = oo
 local right = 0
 for c = 1, cols do
  local top = 0
  for r = rows, 1 do
   if b[r][c] != 0 then
    left = min(left, c)
  end

end

function Piece:to_str()
 local s = "rows="..self.rows
 s = s..", cols="..self.cols
 s = s..", colour="..self.colour.."\n"
 s = s.."row="..self.row
 s = s..", col="..self.col.."\n\n"
 return s..a2s(self.blocks, self.rows, self.cols)
end

----------------------------------------
-- class Piece Generator (Bag of pieces)
----------------------------------------
PieceGen = {}
PieceGen.__index = PieceGen

-- constructor
function PieceGen.new(rng)
 local self = setmetatable({}, PieceGen)
 self.rng = rng
 self.bag = {}
 self.n = 0
 self:_refill()
 return self
end

function PieceGen:_refill()
 local repetitions = 15
 local n = #PIECES * repetitions
 local rng = self.rng
 local bag = self.bag

 self.n = n

 for i = 0, n - 1 do
  bag[i + 1] = {
   flr(i / repetitions) + 1, -- tetrominoe index
   rng:rand(1, COLOURS),     -- colour
   rng:rand(0, 3)            -- rotation
  }
 end

 -- Fisher-Yates shuffle algorithm (modern version)
 for i = n, 2, -1 do
  local j = rng:rand(1, i)
  local tmp = bag[i]
  bag[i] = bag[j]
  bag[j] = tmp
 end
end

function PieceGen:next()
 local n = self.n
 if n == 0 then self:_refill() end
 local attributes = self.bag[n]
 self.bag[n] = nil
 self.n = n - 1
 return Piece.new(attributes)
end

----------------------------------------
-- class Player --
----------------------------------------
Player = {}
Player.__index = Player

--[[
 Constructor

 params
 ------
 index : int = 0-based index of the player
               from left to right
 kind : string['human','cpu'] = type of player
 timers : Scheduler = .
 seed : int[0..100] = seed from random generators
]]--
function Player.new(index, kind, timers, seed)
 local self = setmetatable({}, Player)
 self.index = index
 self.kind = kind
 self.timers = timers
 self.id = 'player_'..index

 self.rng = RNG.new(seed)

 -- board
 self.board = array2d(ROWS, COLS)
 -- TODO remove the following test data
 -- self.board[1][1] = 1
 -- self.board[1][2] = 2
 -- self.board[1][3] = 3
 -- self.board[1][4] = 4
 -- self.board[1][6] = 5

 self.board_x = HLF_W * index
 self.board_y = 0

 -- piece(s)
 self.gen = PieceGen.new(self.rng)

 self.piece = self.gen:next()

 self.piece:find_slot(self.board)

 -- self.next = self.gen:next()

 local fall_time = 1.3 - (difficulty / 10)
 timers:add_timer(self.id..'piece_fall',
  fall_time,
  function(tmr)
  end
 )
-- printh("current="..self.piece:to_str())
-- printh("next="..self.next:to_str())
 return self
end

function Player:draw()
 self:draw_board()

 local bx = self.board_x
 local by = self.board_y

 local p = self.piece
 local px = bx + (p.col - 1) * BLOCK
 local py = by + (p.row - 1) * BLOCK
 p:draw(px, py, BLOCK)
end

function Player:draw_board()
 local b = self.board
 local x0 = self.board_x
 local y0 = self.board_y

 rect(x0, y0, --
      x0 + COLS * BLOCK - 1, --
      y0 + ROWS * BLOCK, 5)
 local y = y0
 for r = 1, ROWS do
  local x = x0
  for c = 1, COLS do
   if b[r][c] != 0 then
    draw_block(x, y, b[r][c], BLOCK)
   end
   x += BLOCK
  end
  y += BLOCK
 end
end

----------------------------------------
-- Utility Functions
----------------------------------------
function bbox(blocks, rows, cols)
 local min_r, min_c = rows, cols
 local max_r, max_c = 1, 1
 for r = 1, rows do
  for c = 1, cols do
   if blocks[r][c] != 0 then
    if r < min_r then min_r = r end
    if r > max_r then max_r = r end
    if c < min_c then min_c = c end
    if c > max_c then max_c = c end
   end
  end
 end
 return {
  min_r = min_r,
  max_r = max_r,
  min_c = min_c,
  max_c = max_c
 }
end

function draw_block(x, y, colour, block_size)
 local bs = block_size
 if bs == BLOCK then
  spr(colour, x, y)
 else
  rect(x, y, x + bs, y + bs, colour)
 end
end

function a2s(array, rows, cols)
 local s = ""
 for r = 1, rows do
  for c = 1, cols do
   s=s..array[r][c]
  end
  s=s.."\n"
 end
 return s
end

function array2d(num_rows, num_cols, copy, colour)
 local a = {}
 for r = 1, num_rows do
  a[r] = {}
  for c = 1, num_cols do
   if copy and copy[r][c] != 0 then
    a[r][c] = colour
   else
    a[r][c] = 0
   end
   -- Alternatevely:
   -- a[r][c] = (copy and copy[r][c]) and colour or 0
  end
 end
 return a
end

-- function stats()
--  local cpu = flr(stat(1) * 100)
--  local fps = stat(7)
--  local perf = cpu.."% cpu @ "..fps.." fps"
--  print(perf, 31, 2, 0)
--  print(perf, 30, 1, 7)
-- end


function _init()
 timers = Scheduler.new()
 local seed = abs(flr(rnd() * 1000))
 players = {
  Player.new(0, 'human', timers, seed),
  Player.new(1, 'cpu', timers, seed)
 }
end

function _update()
end

function _draw()
 cls()
 for i = 1, #players do
  players[i]:draw()
 end
 timers:update()
end
__gfx__
0cccccc00aaaaaa0088888800afafaf00bbbbbb00eeeeee007777770060606000000000000000000000000000000000000000000000000000000000000000000
6cccccc19aaaaaa4e88888829fafafa43bbbbbb58eeeeee267777775000000060000000000000000000000000000000000000000000000000000000000000000
6cccccc19aaaaaa4e88888829afafaf43bbbbbb58eeeeee267777775600000000000000000000000000000000000000000000000000000000000000000000000
6cccccc19aaaaaa4e88888829fafafa43bbbbbb58eeeeee267777775000000060000000000000000000000000000000000000000000000000000000000000000
6cccccc19aaaaaa4e88888829afafaf43bbbbbb58eeeeee267777775600000000000000000000000000000000000000000000000000000000000000000000000
6cccccc19aaaaaa4e88888829fafafa43bbbbbb58eeeeee267777775000000060000000000000000000000000000000000000000000000000000000000000000
6766666197999994e7eeeee297999994373333358788888267666665600000000000000000000000000000000000000000000000000000000000000000000000
01111110044444400222222004444440055555500222222005555550006060600000000000000000000000000000000000000000000000000000000000000000
