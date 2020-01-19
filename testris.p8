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

BTN_LEFT = 0
BTN_RIGHT = 1
BTN_UP = 2
BTN_DOWN = 3
-- actions buttons B A (like the NES)
BTN_B = 4
BTN_A = 5

-- math constants
-- infinity
oo = 9999

-- game constants
ROWS = 13
COLS = 8
BLK = 8

COLOURS = { 12, 10, 8, 15, 11, 14, 7 }
NUM_COLOURS = #COLOURS

-- sprite index for the ghost block
GHOST_BLK = 8

-- wallkicks
--
-- the first 4 kicks are going to be the basic ←↑→↓
-- (contrary to the Super Rotation System - SRS)
BASIC_WALLKICKS = {
 -- basic wallkicks for all pieces (except I)
 { 0,-1,  -1, 0,  0, 1,  1, 0 },
 -- basic wallkicks for I
 { 0,-1,  -1, 0,  0, 1,  1, 0,  0,-2, -2, 0,  0, 2,  2, 0 }
}
-- the next 4 come from the SRS table:
-- https://harddrop.com/wiki/SRS#Wall_Kicks
SRS_WALLKICKS = {
 -- SRS wallkicks for all pieces (except I)
 {
  { 0,-1,  1,-1, -2, 0, -2,-1 }, -- 0 -> R
  { 0, 1, -1, 1,  2, 0,  2, 1 }, -- R -> 2
  { 0, 1,  1, 1, -2, 0, -2, 1 }, -- 2 -> L
  {-1, 0, -1,-1,  0, 2,  2,-1 }  -- L -> 0
 },
 -- SRS wallkicks for I
 {
  { 0,-2,  0, 1, -1,-2,  2, 1 }, -- 0 -> R
  { 0,-1,  0, 2,  2,-1, -1, 2 }, -- R -> 2
  { 0, 2,  0,-1,  1, 2, -2,-1 }, -- 2 -> L
  { 0, 1,  0,-2, -2, 1,  1,-2 }  -- L -> 0
 }
}

-- tetraminoes
--
-- default attribute values:
-- rotates = true
-- size = 3
-- wallkicks = 1
O = {
 rotates = false,
 size = 2,
 blocks = { {1, 1, 1, 2, 2, 1, 2, 2} },
 -- 11
 -- 11
 mins = { {1, 1} },
 maxs = { {2, 2} }
}
L = {
 blocks = { {1, 2, 2, 2, 3, 2, 3, 3} },
 -- 010
 -- 010
 -- 011
 mins = { {2, 1} },
 maxs = { {3, 3} }
}
J = {
 blocks = { {1, 2, 2, 2, 3, 2, 1, 3} },
 -- 010
 -- 010
 -- 110
 mins = { {1, 1} },
 maxs = { {2, 3} }
}
Z = {
 blocks = { {2, 1, 2, 2, 3, 2, 3, 3} },
 -- 000
 -- 110
 -- 011
 mins = { {1, 2} },
 maxs = { {3, 3} }
}
S = {
 blocks = { {2, 2, 2, 3, 3, 1, 3, 2} },
 -- 000
 -- 011
 -- 110
 mins = { {1, 2} },
 maxs = { {3, 3} }
}
T = {
 blocks = { {2, 1, 2, 2, 2, 3, 3, 2} },
 -- 000
 -- 111
 -- 010
 mins = { {1, 2} },
 maxs = { {3, 3} }
}
I = {
 wallkicks = 2,
 size = 4,
 blocks = { {1, 2, 2, 2, 3, 2, 4, 2} },
 -- 0100
 -- 0100
 -- 0100
 -- 0100
 mins = { {2, 1} },
 maxs = { {2, 4} }
}

PIECES = { L, J, Z, S, T, O }

--[[
rotation states of the tetromino
states:
       0         1         2         3
       O         R         2         L
     _____     _____     _____     _____
  1 |_|▇|_|   |_|_|_|   |▇|▇|_|   |_|_|▇|
  2 |_|▇|_|   |▇|▇|▇|   |_|▇|_|   |▇|▇|▇|
  3 |_|▇|▇|   |▇|_|_|   |_|▇|_|   |_|_|_|
     1 2 3     1 2 3     1 2 3     1 2 3

        0           1           2           3
        O           R           2           L
     _______     _______     _______     _______
  1 |_|▇|_|_|   |_|_|_|_|   |_|_|▇|_|   |_|_|_|_|
  2 |_|▇|_|_|   |▇|▇|▇|▇|   |_|_|▇|_|   |_|_|_|_|
  3 |_|▇|_|_|   |_|_|_|_|   |_|_|▇|_|   |▇|▇|▇|▇|
  4 |_|▇|_|_|   |_|_|_|_|   |_|_|▇|_|   |_|_|_|_|
     1 2 3 4     1 2 3 4     1 2 3 4     1 2 3 4
]]
-- STATE_O = 0
-- STATE_R = 1
-- STATE_2 = 2
-- STATE_L = 3

DOT_LINE_GAP = 3

-- movements
LEFT = -1
RIGHT = 1
DOWN = 2
UP = 0
ROT_L = 3
ROT_R = 4
MOVES = { LEFT, RIGHT, UP, DOWN, ROT_L, ROT_R }

----------------------------------------
-- Globals
----------------------------------------
timers = nil

players = nil

-- vertical offset for ghost dotted lines
dot_offset = 0

-- number of active human players
-- (1 for human vs cpu, 2 for human vs human)
human_players = 1

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
function Scheduler:add(id, time, on_step, ctx, steps)
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

function Scheduler:set_timeout(id, timeout)
 self.timers[name].time = timeout
end

function Scheduler:reset(id)
 self.timers[id].step = 0
 self.timers[id].ellapsed = 0
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
 (both inclusive), using the LCG algorithm:
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
-- class Board
----------------------------------------
Board = {}
Board.__index = Board

--[[
 Constructor
]]

function Board.new(player_index)
 local self = setmetatable({}, Board)
 self.index = player_index
 self.x = player_index * HLF_W
 self.y = 0
 self.blks = array2d(ROWS, COLS)

 -- TODO remove the following test data
 self.blks[ROWS][1] = 1
 self.blks[ROWS][2] = 2
 self.blks[ROWS][3] = 3
 self.blks[ROWS][4] = 4
 self.blks[ROWS][5] = 5
 self.blks[ROWS][6] = 6
 self.blks[ROWS][7] = 7

 return self
end

--[[
 Finds the first available position
 on the board's top row that fits the given
 piece without applying rotations.

 param
 -----
 piece : Piece = piece to fit at the top of the board

 returns : array[2] = the coordinates of the found slot,
                      nil if not slot was found
]]--
function Board:find_slot(piece)
 local p = piece
 local b = bbox(piece.blks, piece.rows, piece.cols)
 local w = b.max_c - b.min_c + 1

 -- row = (-box.min_row + 1) + 1
 --     = 1 - box.min_row + 1
 local row = 2 - b.min_r

 -- center = [(COLS - w) / 2] + [(-b.min_c + 1) + 1]
 local center = flr((COLS - w) / 2) + 2 - b.min_c

 local min_d, col = oo
 for c = -p.cols, COLS do
  if not piece:collides(self, row, c) then
   local d = abs(center - c)
   if d < min_d then
    min_d = d
    col = c
   end
  end
 end

 return min_d != oo and { row, col } or nil
end

function Board:clear_lines(lines)
 if #lines > 0 then
  local i = lines[#lines]
  local j = i > 1 and i - 1 or 1
  while j > 0 do
   while contains(lines, j) and j > 0 do
    j -= 1
   end
printh('i='..i..',j='..j)
   for k = 1, COLS do
    self.blks[i][k] = self.blks[j][k]
   end
   i -= 1
   j -= 1
  end
  while i > 0 do
   for k = 1, COLS do
    self.blks[i][k] = 0
   end
   i -= 1
  end
 end
end

function Board:lock(piece)
 local p = piece
 for r = 1, p.rows do
  for c = 1, p.cols do
   if p.blks[r][c] != 0 then
     self.blks[p.row + r - 1][p.col + c - 1] = p.colour
   end
  end
 end
 -- TO-DO: add locking animation
end

function Board:lines()
 local b = self.blks
 local lines = {}
 for row = 1, ROWS do
  local is_full = true
  for col = 1, COLS do
   if self.blks[row][col] == 0 then
    is_full = false
    break
   end
  end
  if is_full then add(lines, row) end
 end
 return lines
end

function Board:draw()
 local x0 = self.x
 local y0 = self.y

 rect(x0, y0, -->
      x0 + COLS * BLK - 1, -->
      y0 + ROWS * BLK, 5)
 local y = y0
 for r = 1, ROWS do
  local x = x0
  for c = 1, COLS do
   local b = self.blks[r][c]
   if b != 0 then
    draw_blk(x, y, b, BLK)
   end
   x += BLK
  end
  y += BLK
 end
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
   3 : int[0..3] = number of 90° rotations
 }
]]--
function Piece.new(attributes)
 local self = setmetatable({}, Piece)

 local index = attributes[1]
 local colour = attributes[2]
 local rotation = attributes[3]

 local p = PIECES[index]
 self.blks = p.blocks[rotation]
 self.size = p.size

 self.colour = colour

 self.index = index
 self.rotation = rotation

 -- position within a board
 self.board_x, self.board_y = 0, 0
 

 return self
end

function Piece:draw(base_x, base_y, colour, blk_size, is_ghost)
 local b = self.blks
 local size = self.size
 colour = colour and colour or self.colour
 local bs = blk_size and blk_size or BLK
 for i = 1, #b, 2 do
  local x, y = b[i], b[i + 1]
  draw_blk(base_x + (x + self.board_x - 1) * bs,
           base_y + (y + self.board_y - 1) * bs,
           colour, bs, is_ghost)
 end
end

----------------------------------------
-- class Piece Generator (Bag of pieces)
----------------------------------------
Bag = {}
Bag.__index = Bag

-- constructor
function Bag.new(rng)
 local self = setmetatable({}, Bag)
 self.rng = rng
 self.bag = {}
 self.n = 0
 self:_refill()
 return self
end

function Bag:_refill()
 local n = #PIECES
 local rng = self.rng
 local bag = self.bag

 self.n = n

 for i = 1, n do
  bag[i] = {
   i, -- tetrominoe index
   rng:rand(1, NUM_COLOURS), -- colour
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

function Bag:next()
 local n = self.n
 if n == 0 then self:_refill() end
 local attributes = self.bag[n]
 self.bag[n] = nil
 self.n = n - 1
-- BEGIN DEBUG BLOCK
-- default to the L piece for debugging
-- attributes[1] = 1
-- default to the I piece for debugging
-- attributes[1] = #PIECES
-- END DEBUG BLOCK
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
 type : string['h','c'] = player type: 'h' for human, 'c' for cpu
 gravity_speed : int[0..10] = gravity speed: 0 (slow), 10 (fast)
 timers : Scheduler = .
 seed : int[0..100] = seed for random generators
]]--
function Player.new(index, type, gravity_speed, timers, seed)
 local self = setmetatable({}, Player)

 self.index = index
 self.type = type
 self.timers = timers
 self.id = 'p'..index

 self.game_over = false

 self.rng = RNG.new(seed)

 self.board = Board.new(index)

 self.bag = Bag.new(self.rng)

 self:spawn_piece()

 -- self.next = self.bag:next()

 -- timers
 self.gravity = 1.3 - (gravity_speed / 10)
 timers:add('gravity_'..self.id,
  self.gravity,
  function(tmr)
   -- printh('gravity timer, ply-id:'..self.id)
   self:on_gravity()
  end
 )

 return self
end

function Player:on_gravity()
--[[
 local b = self.board
 local p = self.piece
 if p then
  if p:collides(b, p.board_x, p.board_y + 1) then
   self.board:lock(p)
   self.piece = nil
   self:start_line_erasing()
  else
   p.board_y += 1
  end
 end
]]--
end

function Player:start_line_erasing()
--[[
 local lines = self.board:lines()
 if #lines > 0 then 
  local ctx = {
   x = self.index * HLF_W,
   lines = lines
  }
  timers:add('lines-erasing-'..self.index, 0.01,
   function (tmr)
    -- TO-DO add line erasing animation
    if tmr.step == 62 then
     self.board:clear_lines(lines)
     self:start_line_erasing()
    end
   end,
   ctx, 62)
 else
  self:spawn_piece()
 end
]]--
end

function Player:spawn_piece()
--[[
 self.piece = self.next and self.next or self.gen:next()
 local p = self.piece
 local pos = self.board:find_slot(p)
printh("spawn_piece: pos="..(pos and '[obj]' or 'nil'))
 if pos then
  p.row, p.col = pos[1], pos[2]
 else
  self.game_over = true
  self.piece = nil
 end
 -- self.next = self.gen:next()
]]--
 self.next = self.bag:next()
end

--[[
 handles tetramino's rotation with wallkicks

 params
 ------
  dir : int[-1, 1] = rotation direction left=-1, right=1
]]--
function Player:rotate(dir)
--[[
 local p = self.piece
 local rows = p.rows
 local cols = p.cols

 -- current rotation plus new rotation give us next state
printh("\nmino="..p.index)
printh("current state="..p.state)
printh("p.r, p.c="..p.row..", "..p.col)
printh("dir="..dir)
 local new_state = (p.state + dir) % 4

printh("new state:"..new_state)

 --[[
   states (and value): O=0 R=1 2=2 L=3

   clockwise 90 deg rotation state transitions:

   0(0) ->R uses kicks row #1
   R(1) ->2 row #2
   2(2) ->L row #3
   L(3) ->0 row #4
     ^
     initial state

   counter-clockwise 90 deg rotation state transitions:

   0-> L(3) uses kicks row #4, multiplied by -1
   L-> 2(2) row #3 (mult by -1)
   2-> R(1) row #2 (mult by -1)
   R-> 0(0) row #1 (mult by -1)
         ^
         new state
 ]]--
--[[
 local index = dir > 0 and p.state or new_state
 index += 1

 printh("srs wallkick row to use: "..index)

 -- the I tetromino has a different wallkick
 -- table from the rest of tetrominoes
 local kicks
 local srs_kicks
 if p.index == #PIECES then
-- printh("I wallkicks")
  kicks = I_WALLKICKS
  srs_kicks = I_SRS_WALLKICKS[index]
 else
  kicks = WALLKICKS
  srs_kicks = SRS_WALLKICKS[index]
 end

 local num_kicks = #kicks
 local blks = rotate_blks(p.blks, rows, cols, dir)
 local b = self.board.blks
 for i = 1, num_kicks + #srs_kicks do
  local r = p.row
  local c = p.col
  if i > 1 then
   local kick
   if i < 1 + num_kicks then
    kick = kicks[i - 1]
   else
    kick = srs_kicks[i - num_kicks]
   end
   r += dir * kick[1]
   c += dir * kick[2]
  end
-- printh("will try r,c="..r..","..c)
  if not collides(blks, rows, cols, b, r, c) then
   p.row, p.col = r, c
   p.state = new_state
   p:set_blks(blks)
   return
  end
 end
]]--
end

function Player:move(btn)
--[[
 local p = self.piece
 if p and self.kind == 'h' then
  if btn == LEFT or btn == RIGHT then
   -- LEFT is -1, RIGHT is +1
   if not p:collides(self.board, p.row, p.col + btn) then
    p.col += btn
   end
  elseif btn == ROT_R or btn == ROT_L then
   self:rotate(button == ROT_R and 1 or -1)
  end
 end
]]--
end

function Player:ai_play()
end

function Player:draw()
 self.board:draw()
--[[
 if not self.game_over then
  local bx = self.board.x
  local by = self.board.y

  local p = self.piece
  if p then
   local px = bx + (p.col - 1) * BLK
   local py = by + (p.row - 1) * BLK
   p:project_ghost(self.board, px, py)
   p:draw(px, py)
  end
 end
]]--
end

----------------------------------------
-- Utility Functions
----------------------------------------
--[[
 Checks if a piece either is out of bounds
 or collides with the board's content.

 params
 ------
 blks : array2d = piece's blks
 rows : int = piece number of rows
 cols : int = piece number of columns
 board : array2d = current player's board
 pos_r : int = piece left-top corner row
 pos_c : int = piece left-top corner column

 returns: bool
]]--
function collides(board_blks, piece_blks, x, y)
--[[
 for i = 1, #piece_blks, 2 do
   if piece_blks[r][c] != 0 then
    local b_r = pos_r + r - 1
    local b_c = pos_c + c - 1
    if  b_r < 1 or b_r > ROWS
     or b_c < 1 or b_c > COLS
     or board_blks[b_r][b_c] != 0
    then
     return true
    end
   end
  end
 end
 return false
--]]
 return false
end


--[[
 Rotates the piece 90 degrees.

 counter clockwise rotations:
 steps = 0        -1        -2        -3
       _____     _____     _____     _____
    1 |_|▇|_|   |_|_|▇|   |▇|▇|_|   |_|_|_|
    2 |_|▇|_|   |▇|▇|▇|   |_|▇|_|   |▇|▇|▇|
    3 |_|▇|▇|   |_|_|_|   |_|▇|_|   |▇|_|_|
       1 2 3     1 2 3     1 2 3     1 2 3

 clockwise rotations:
 steps = 0         1         2         3
       _____     _____     _____     _____
    1 |_|▇|_|   |_|_|_|   |▇|▇|_|   |_|_|▇|
    2 |_|▇|_|   |▇|▇|▇|   |_|▇|_|   |▇|▇|▇|
    3 |_|▇|▇|   |▇|_|_|   |_|▇|_|   |_|_|_|
       1 2 3     1 2 3     1 2 3     1 2 3

 param
 -----
 blks : array2d = tetrominos' blks
 rows : int = number of rows of the tetromino
 cols : int = number of columns of the tetromino
 steps : int[-3..3]: number of 90° rotations
]]--
function rotate_blks(blks, rows, cols, steps)
--[[
 steps = steps % 4
 local dest = array2d(rows, cols)
 for r = 1, rows do
  for c = 1, cols do
   local R = rows - r + 1
   local C = cols - c + 1

   local dr, dc = r, c
   if steps == 1 then
    dr, dc = c, R
   elseif steps == 2 then
    dr, dc = C, R
   elseif steps == 3 then
    dr, dc = C, r
   end

   dest[dr][dc] = blks[r][c]
  end
 end

 return dest
--]]
end

function dot_vert_line(x, yo, yf, colour)
--[[
 -- dot_offset is global and updated by a timer
 local gap = DOT_LINE_GAP
 local solid = true
 local y = yo
 local yy = y + dot_offset - gap
 while y < yf do
  if solid then
   if yy >= y then
    line(x, y, x, yy, colour)
   end
   solid = false
  else
   solid = true
  end
  y = yy + 1
  yy += gap
  if yy > yf then
   yy = yf
  end
 end
]]--
end

--[[
 Draws a (filled or outlined) single tetrominoe's block.

 params
 ------
 x : int = screen x coordinate of left/top corder of the block
 y : int = screen y coordinate of left/top corder of the block
 colour : int[1..NUM_COLOURS] = colour of the block
 blk_size : int = block's width/height
 is_ghost : bool = draws the block's outline, only available
                   for blks of size BLK, ignored otherwise
]]--
function draw_blk(x, y, colour, blk_size, is_ghost)
 local bs = blk_size
 if bs == BLK then
  if is_ghost then
  -- ghost block is light gray, swap
  -- light gray with the piece colour
   pal(6, colour)
   spr(GHOST_BLK - 1, x, y)
   pal()
  else
   spr(colour - 1, x, y)
  end
 else
  rect(x, y, x + bs, y + bs, colour)
 end
end

function contains(l, v)
 for e in all(l) do
  if v == e then return true end
 end
 return false
end

function array2d(num_rows, num_cols)
 local a = {}
 for r = 1, num_rows do
  a[r] = {}
  for c = 1, num_cols do
   a[r][c] = 0
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

--[[
 pre-builds all the rotations for each piece
]]--
function _init()
 -----------------------------------
 -- pre-generate all the rotations,
 -- along with mins and maxs
 -----------------------------------
 for n = 1, #PIECES do
  local p = PIECES[n]
  if not p.rotates then goto continue end
  local SIZE = p.size and p.size or 3
  local blks = p.blocks[1]
  for _ = 1, 3 do
   local min_x, min_y = oo, oo
   local max_x, min_y = 0, 0
   local rot = {}
   for i = 1, #p, 2 do
    -- 90° rotation = (x, y) -> (-y, x)
    -- -y -> SIZE - y + 1 (1-index y's mirror)
    local x, y = blks[i + 1], SIZE - blks[i] + 1
    if x > max_x then max_x = x end
    if x < min_x then min_x = x end
    if y > max_y then max_y = y end
    if y > min_y then min_y = y end
    add(rot, x)
    add(rot, y)
   end
   add(PIECES[n].blocks, rot)
   add(PIECES[n].mins, {min_x, min_y})
   add(PIECES[n].maxs, {max_x, max_y})
   blks = rot
  end
  ::continue::
 end
 -----------------------------------

 -----------------------------------
 -- fill the wallkicks
 -----------------------------------
 for n = 1, #PIECES do
  local p = PIECES[n]
  local W = p.wallkicks and p.wallkicks or 1
  local bk = BASIC_WALLKICKS[W]
  local srs = SRS_WALLKICKS[W]
  p.kicks = {}
  for k in all(bk) do
   add(p.kicks, k)
  end
  for k in all(srs) do
   add(p.kicks, k)
  end
 end
 -----------------------------------

 timers = Scheduler.new()
 local seed = abs(flr(rnd() * 1000))

 -- players configuration
 players = {
  Player.new(0, 'h', 10, timers, seed),
  Player.new(1, 'c', 10, timers, seed)
 }
 human_players = 1

 -- register timers
 timers:add('dot-line',
  0.05, -- segs
  function(tmr)
   dot_offset = (dot_offset + 1) % (2 * DOT_LINE_GAP)
  end
 )
end

function _update()
 for p = 1, human_players do
  local player = players[p]
  for m = 1, #MOVES do
   -- btn() uses 0-index for both button and player
   if btnp(m - 1, p - 1) then
    player:move(MOVES[m])
   end
  end
 end
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
