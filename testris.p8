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
--[[
 what are wallkicks?
 https://harddrop.com/wiki/SRS#Wall_Kicks

 legend of piece rotation states and their values:
 name value description
   O    1   initial state, no rotation
   R    2   one clockwise 90 degress rotation applied
   2    3   180 degress rotation
   L    4   three clockwise 90 degress rotations

 clockwise 90 deg rotation state transitions:

     value of 'new_rotation'
          v
 0(1) ->R(2) will use wallkicks from row 2
 R(2) ->2(3) from row 4
 2(3) ->L(4) from row 6
 L(4) ->0(1) from row 8
   ^
 value of 'rotation'

 wallkick_index = 2 * rotation

 counter-clockwise 90 deg rotation state transitions:

 0(1) -> L(4) will use wallkicks from row 7
 L(2) -> 2(3) from row 5
 2(3) -> R(2) from row 3
 R(4) -> 0(1) from row 1

 wallkick_index = 7 - 2 * (rotation - 1) = 9 - 2 * rotation

 contrary to the Super Rotation System - SRS
 the first 4 kicks (BASIC_KICKS) are for basic ←↑→↓
]]--
BASIC_WALLKICKS = {
 -- basic wallkicks for all pieces (except I)
 { {0,0}, {0,-1}, {-1,0}, {0,1}, {1,0} },
 -- basic wallkicks for I
 { {0,0}, {0,-1}, {-1,0}, {0,1}, {1,0}, {0,-2}, {-2,0}, {0,2}, {2,0} }
}
SRS_WALLKICKS = {
 {
-- SRS wallkicks for all pieces (except I)
--{{ 0,+1}, {-1,+1}, {+2, 0}, {+2,+1} }, -- R -> 0 -- generated during _init
  {{ 0,-1}, { 1,-1}, {-2, 0}, {-2,-1} }, -- 0 -> R
--{{ 0,-1}, {+1,-1}, {-2, 0}, {-2,-1} }, -- 2 -> R -- "
  {{ 0, 1}, {-1, 1}, { 2, 0}, { 2, 1} }, -- R -> 2
--{{ 0,-1}, {-1,-1}, {+2, 0}, {+2,-1} }, -- L -> 2 -- "
  {{ 0, 1}, { 1, 1}, {-2, 0}, {-2, 1} }, -- 2 -> L
--{{+1, 0}, {+1,+1}, { 0,-2}, {-2,+1} }, -- 0 -> L -- "
  {{-1, 0}, {-1,-1}, { 0, 2}, { 2,-1} }  -- L -> 0
 },
-- SRS wallkicks for I
 {
--{ {0,+2}, {0,-1}, {+1,+2}, {-2,-1} }, -- R -> 0 -- generated during _init
  { {0,-2}, {0, 1}, {-1,-2}, { 2, 1} }, -- 0 -> R
--{ {0,+1}, {0,-2}, {-2,+1}, {+1,-2} }, -- 2 -> R -- "
  { {0,-1}, {0, 2}, { 2,-1}, {-1, 2} }, -- R -> 2
--{ {0,-2}, {0,+1}, {-1,-2}, {+2,+1} }, -- L -> 2 -- "
  { {0, 2}, {0,-1}, { 1, 2}, {-2,-1} }, -- 2 -> L
--{ {0,-1}, {0,+2}, {+2,-1}, {-1,+2} }  -- 0 -> L -- "
  { {0, 1}, {0,-2}, {-2, 1}, { 1,-2} }  -- L -> 0
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
 -- 11
 -- 11
 blks = { { {0, 0}, {1, 0}, {0, 1}, {1, 1}} },
}
L = {
 -- 010
 -- 010
 -- 011
 blks = { {{1, 0}, {1, 1}, {1, 2}, {2, 2}} },
}
J = {
 -- 010
 -- 010
 -- 110
 blks = { {{1, 0}, {1, 1}, {0, 2}, {1, 2}} },
}
Z = {
 -- 000
 -- 110
 -- 011
 blks = { {{0, 1}, {1, 1}, {1, 2}, {2, 2}} },
}
S = {
 -- 000
 -- 011
 -- 110
 blks = { {{1, 1}, {2, 1}, {0, 2}, {1, 2}} },
}
T = {
 -- 000
 -- 111
 -- 010
 blks = { {{0, 1}, {1, 1}, {2, 1}, {1, 2}} },
}
I = {
 kicks_index = 2,
 size = 4,
 -- 0100
 -- 0100
 -- 0100
 -- 0100
 blks = { {{1, 0}, {1, 1}, {1, 2}, {1, 3}} },
}

PIECES = { L, J, Z, S, T, O, I }

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

particles = {}

-- vertical offset for ghost dotted lines
dot_offset = 0

-- number of active human players
-- (1 for human vs cpu, 2 for human vs human)
human_players = 1

particles = {}
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
 time : int = number of frames before each animation step
 on_step : f(timer) -- function to run on each tick
 [steps : int] = max number of ticks for the timer,
                 omit it to run indefinitely
 [ctx : {}] = additional data to pass to the timer
]]--
function Scheduler:add(time, on_step, steps, ctx)
 add(self.timers, {
  frames = 0,
  time = time,
  ellapsed = 0,
  step = 0,
  steps = steps,
  ctx = ctx and ctx or {},
  step_fn = on_step
 })
 return #self.timers
end

function Scheduler:remove(index)
 del(self.timers, self.timers[index])
end

function Scheduler:set_timeout(index, timeout)
 self.timers[index].time = timeout
end

function Scheduler:reset(index)
 self.timers[index].step = 0
 self.timers[index].ellapsed = 0
end

function Scheduler:update()
 foreach(self.timers, function (timer)
  timer.frames += 1
  if timer.frames >= timer.time then
   timer.step += 1
   timer:step_fn()
   timer.frames -= timer.time
   if timer.steps and timer.step >= timer.steps then
    del(self.timers, timer)
   end
  end
 end)
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

 -- self.tops = {0, 0, 0, 0, 0, 0, 0, 0}
 self.tops = {ROWS, ROWS, ROWS, ROWS, ROWS, ROWS, ROWS, ROWS + 1}

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
]]--
function Board:find_slot(piece)
 local p = piece

 -- anchor_y = (initial_board_y = 1) - piece.min_y
 local anchor_y = 1 - p.min_y
 local w = p.width
 local center = flr((COLS - w) / 2) + 1

 local min_d, anchor_x = oo
 for col = 1, COLS - w do
  local d = abs(center - col)
  local anc_x = col - p.min_x
  if d < min_d and
   not collides(self, p.index, p.rot, anc_x, anchor_y)
  then
   min_d, anchor_x = d, anc_x
  end
 end

 if min_d == oo then
  return oo, oo
 else
  return anchor_x, anchor_y
 end
end

function Board:clear_lines(lines)
-- if #lines > 0 then
--  local i = lines[#lines]
--  local j = i > 1 and i - 1 or 1
--  while j > 0 do
--   while contains(lines, j) and j > 0 do
--    j -= 1
--   end
--printh('i='..i..',j='..j)
--   for k = 1, COLS do
--    self.blks[i][k] = self.blks[j][k]
--   end
--   i -= 1
--   j -= 1
--  end
--  while i > 0 do
--   for k = 1, COLS do
--    self.blks[i][k] = 0
--   end
--   i -= 1
--  end
-- end
end

function Board:lock(piece)
 foreach(piece.blks, function (b)
  local x = piece.anchor_x + b[1]
  local y = piece.anchor_y + b[2]
  self.blks[y][x] = piece.colour
  self.tops[x] = y
 end)
end

function Board:lines()
-- local b = self.blks
-- local lines = {}
-- for row = 1, ROWS do
--  local is_full = true
--  for col = 1, COLS do
--   if self.blks[row][col] == 0 then
--    is_full = false
--    break
--   end
--  end
--  if is_full then add(lines, row) end
-- end
-- return lines
end

function Board:draw()
 local x0 = self.x
 local y0 = self.y

 rect(x0, y0,
      x0 + COLS * BLK - 1,
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

function Board:drop_dist(blks, anchor_x, anchor_y)
 local dist = oo
 foreach(blks, function (blk)
  local x, y = anchor_x + blk[1], anchor_y + blk[2]
  dist = min(dist, self.tops[x] - y - 1)
 end)
 return dist
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
   3 : int[1..4] = the rotated position of the piece
 }
]]--
function Piece.new(attributes)
 local self = setmetatable({}, Piece)

 local index = attributes[1]
 local colour = attributes[2]
 local rot = attributes[3]

 self.index = index
 self.colour = colour
 self.rot = rot

 local P = PIECES[index]

 -- shorter/easier to keep a ref to the blocks instead
 -- of always doing PIECES[p.index].blks[p.rot]
 self.blks = P.blks[rot]

 self.size = P.size
 self.min_x = P.mins[rot][1]
 self.min_y = P.mins[rot][2]
 self.max_x = P.maxs[rot][1]
 self.max_y = P.maxs[rot][2]
 self.width = self.max_x - self.min_x + 1

 -- position of the piece's top-left corner
 self.anchor_x = oo
 self.anchor_y = oo

 return self
end

function Piece:draw(base_x, base_y, colour, blk_size, is_ghost)
 local size = self.size
 colour = colour and colour or self.colour
 local BS = blk_size and blk_size or BLK

 if self.anchor_x != oo then
  base_x += (self.anchor_x - 1) * BS
  base_y += (self.anchor_y - 1) * BS
 end

 foreach(self.blks, function (b)
  draw_blk(base_x + b[1] * BS,
           base_y + b[2] * BS,
           colour, BS, is_ghost)
 end)
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
 local b = self.bag

 self.n = n

 for i = 1, n do
  b[i] = {
   i, -- tetrominoe index
   rng:rand(1, NUM_COLOURS), -- colour
   rng:rand(1, #PIECES[i].blks)  -- rotation
  }
 end

 -- Fisher-Yates shuffle algorithm (modern version)
 for i = n, 2, -1 do
  local j = rng:rand(1, i)
  local tmp = b[i]
  b[i] = b[j]
  b[j] = tmp
 end
end

function Bag:next()
 local n = self.n
 if n == 0 then self:_refill() end
 local attributes = self.bag[n]
 self.bag[n] = nil
 self.n -= 1
 return attributes
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
 self.gravity = 20 - gravity_speed
 self.grav_timer_id = timers:add(self.gravity,
  function(tmr)
   -- printh('gravity timer, ply-id:'..self.id)
   self:on_gravity()
  end)

 return self
end

function Player:draw()
 self.board:draw()

 if not self.game_over then
  local bx = self.board.x
  local by = self.board.y

  local p = self.piece
  if p then
   p:draw(bx, by)
  end
 end
end

function Player:on_gravity()
 local b = self.board
 local p = self.piece
 if p then
  if collides(b, p.index, p.rot, p.anchor_x, p.anchor_y + 1) then
   self.board:lock(p)
   self.piece = nil
   self:start_line_erasing()
  else
   p.anchor_y += 1
  end
 end
end

function Player:start_line_erasing()
 -- first gather lines ranges and their connections
 local B = self.board.blks
 local lines = {}
 local l_start, l_end, prev_line = 0, 0, 0
 for row = 1, ROWS do
  local is_line = true
  for col = 1, COLS do
   if B[row][col] == 0 then
    is_line = false
    break
   end
  end

  if is_line then
   if l_start == 0 then
    -- mark the start of a (potential) line range
    l_start, l_end = row, row
   elseif l_end == row - 1 then
    -- extend the line range
    l_end += 1
   else
    -- close and add the range
    add(lines, {l_start, l_end, find_connected(prev_line, l_start, B)})
    prev = r_end
    r_start, r_end = row, row
   end
  end
 end
 if l_start > 0 then
  add(lines, {l_start, l_end, find_connected(prev_line, l_start, B)})
 end
printh("lines:")
printh(to_json(lines))
 foreach(lines, function (line)
  for y = line[1], line[2] do
   for x = 1, COLS do
    add_particles(10,
     self.board.x, y * BLK_SIZE - flr(BLK_SIZE / 2),
     { B[y][x] },
     -5, 5, 1, 5, 0, -0.3, 10, 20, 3, 5, {})
   end
  end
 end)
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
 local p = Piece.new(self.bag:next())
 local anc_x, anc_y = self.board:find_slot(p)
 if anc_x != oo then
  p.anchor_x, p.anchor_y = anc_x, anc_y
  self.piece = p
 else
  self.game_over = true
  self.piece = nil
 end
end

--[[
 params
 ------
  dir : int[-1, 1] = 90 degree rotation direction
                     ccw=-1, cw=1
]]--
function Player:rotate(dir)
 local p = self.piece
 local P = PIECES[p.index]
 if (not P.rotates) return

 local new_rot = p.rot + dir
 if (new_rot < 1) new_rot = 4
 if (new_rot > 4) new_rot = 1

 local kicks = P.kicks[dir > 0 and (2 * p.rot) or (9 - 2 * p.rot)]
 for kick in all(kicks) do
  local xx = p.anchor_x + kick[1]
  local yy = p.anchor_y + kick[2]
  if not collides(self.board, p.index, new_rot, xx, yy) then
   p.rot = new_rot
   p.blks = PIECES[p.index].blks[new_rot]
   p.anchor_x, p.anchor_y = xx, yy
   return
  end
 end
end

function Player:move(btn)
 local p = self.piece
 local b = self.board
 if btn == LEFT or btn == RIGHT then
  -- LEFT is -1, RIGHT is +1
  local anc_x = p.anchor_x + btn
  if not collides(b, p.index, p.rot, anc_x, p.anchor_y) then
   p.anchor_x = anc_x
  end
 elseif btn == ROT_R or btn == ROT_L then
  self:rotate(btn == ROT_R and 1 or -1)
 elseif btn == DOWN then
  p.anchor_y += b:drop_dist(p.blks, p.anchor_x, p.anchor_y)
 end
end

function Player:ai_play()
end

----------------------------------------
-- Functions
----------------------------------------
function collides(board, piece_index, rotation, new_anc_x, new_anc_y)
 local B = board.blks
 local b = PIECES[piece_index].blks[rotation]
 for i = 1, #b do
  local xx = new_anc_x + b[i][1]
  local yy = new_anc_y + b[i][2]
  if xx < 1 or COLS < xx or
     yy < 1 or ROWS < yy or
     B[yy][xx] != 0
  then
   return true
  end
 end
 return false
end

function rand(a, b)
 return a == b and a or (rnd() * (b - a) + a)
end

function find_connected(prev_line, l_start, B)
 -- add the connected components to the line range
 local visited_size = l_start - prev_line - 1
 if (visited_size <= 0) return {}

 local connected = {}
 -- bfs style flood-fill to get the connected comps
 local ox = {-1, 0, 1, 0}
 local oy = { 0,-1, 0, 1}
 local visited = array2d(visited_size, COLS)
 for x = 1, COLS do
  local y = l_start - 1
  if y > 0 and B[y][x] != 0 and visited[y][x] == 0 then
   local conn = {}
   local min_x, min_y = oo, oo
   local max_x, max_y = 0, 0
   local queue = {{x, y}}
   while #queue > 0 do
    local top = queue[#queue]
    queue[#queue] = nil
    local xx, yy = top[1], top[2]
    if B[yy][xx] != 0 then
     local off_y = l_start - yy
     min_x, min_y = min(min_x, xx), min(min_y, off_y)
     max_x, max_y = max(max_x, xx), max(max_y, off_y)
     add(conn, {xx, off_y, B[yy][xx]})
    end
    visited[yy][xx] = 1
    for k = 1, 4 do
     local nx = xx + ox[k]
     local ny = yy + oy[k]
     if 1 <= nx and nx <= COLS and
      prev_line < ny and ny < l_start and
      visited[ny][nx] == 0 and B[ny][nx] != 0
     then
      add(queue, {nx, ny})
     end
    end
   end
   conn.mins = {min_x, min_y}
   conn.maxs = {max_x, max_y}
   if (#conn > 0) add(connected, conn)
  end
 end

 return connected
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

function add_particles(count, cx, cy, colours,
 min_vx, max_vx, min_vy, max_vy,
 min_acc_x, max_acc_x, min_acc_y, max_acc_y,
 min_duration, max_duration,
 min_size, max_size)
 local parts = {}
 for c = 1, count do
  --[[
   1 = duration
   2, 3 = x, y
   4, 5 = vx, vy
   6, 7 = acc_x, acc_y
   8, 9 = size, delta size
   10 = colour
  ]]--
  local duration = flr(rand(min_duration, max_duration))
  local size = rand(min_size, max_size)
  add(particles, {
   duration,
   -- xo, yo
   cx, cy,
   -- vx, vy
   rand(min_vx, max_vx), rand(min_vy, max_vy),
   -- acc_x, acc_y
   rand(min_acc_x, max_acc_x), rand(min_acc_y, max_acc_y),
   -- size, delta_size
   size, (size - min_size) / duration,
   -- colour
   colours[flr(rand(1, #colours))]
  })
 end
end

----------------------------------------
-- DEBUG Functions
----------------------------------------
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

--[[
 pre-builds all the rotations for each piece
]]--
function _init()
 -----------------------------------
 -- pre-generate all rotations, calculate
 -- mins, maxs and wallkicks for
 -- each piece
 -----------------------------------
 foreach(PIECES, function(piece)
  -- compute the piece's size
  -- size = piece.size != null ? piece.size : 3
  piece.size = piece.size and piece.size or 3

  -- rotations and wallkicks
  --
  -- rotates = piece.rotates != null ? piece.rotates : true
  piece.kicks = {}
  local rotates = true
  if (piece.rotates != nil) rotates = piece.rotates
  piece.rotates = rotates

  if rotates then
   -- rotations
   local blks = piece.blks[1]
   for _ = 1, 3 do
    local rot = {}
    foreach(blks, function (blk)
     -- rotation:
     -- 90° rotation = (x, y) -> (-y, x)
     -- x = -y -> SIZE - 1 - y (reflection)
     -- y = x
     add(rot, {piece.size - 1 - blk[2], blk[1]})
    end)
    add(piece.blks, rot)
    blks = rot
   end

   -- wallkicks
   local I = piece.kicks_index and piece.kicks_index or 1
   local basic_kicks = BASIC_WALLKICKS[I]
   local srs_kicks = SRS_WALLKICKS[I]

   for i = 1, 8 do
    local wallkicks = {}
    -- all kicks start with the basic offsets
    for k in all(basic_kicks) do
     add(wallkicks, k)
    end
    -- even row indexes are for clockwise rotations kicks,
    -- odd row indexes are for counter-clockwise rotation kicks
    for k in all(srs_kicks[flr((i + 1) / 2)]) do
     -- odd multiplies k by -1
     local sign = (-1) ^ (i % 2)
     add(wallkicks, {sign * k[1], sign * k[2]})
    end
    add(piece.kicks, wallkicks)
   end
  end

  -- mins and maxs
  piece.mins, piece.maxs = {}, {}
  for i = 1, #piece.blks do
   local min_x, min_y = oo, oo
   local max_x, max_y = 0, 0
   foreach(piece.blks, function (blk)
    local x, y = blk[1], blk[2]
    min_x, min_y = min(x, min_x), min(y, min_y)
    max_x, max_y = max(x, max_x), max(y, max_y)
   end)
   add(piece.mins, {min_x, min_y})
   add(piece.maxs, {max_x, max_y})
  end
 end)
 -----------------------------------
--printh(to_json(PIECES))
 timers = Scheduler.new()

 -- players configuration
 local seed = abs(flr(rnd() * 1000))

 players = {
  Player.new(0, 'h', 5, timers, seed),
  Player.new(1, 'c', 5, timers, seed)
 }
 human_players = 1

 -- register timers
 -- timers:add('dot-line',
 --  0.05, -- segs
 --  function(tmr)
 --   dot_offset = (dot_offset + 1) % (2 * DOT_LINE_GAP)
 --  end
 -- )
end

function _update()
 for p = 1, human_players do
  local player = players[p]
  for m = 1, #MOVES do
   -- btn() uses 0-index for both button and player
   if btn(m - 1, p - 1) then
    player:move(MOVES[m])
   end
  end
 end

 foreach(particles, function (p)
  if p[1] <= 0 then
   del(particles, p)
   return
  end
  p[1] -= 1    -- duration--
  p[2] += p[4] -- x += vx
  p[3] += p[5] -- y += vy
  p[4] += p[6] -- vx += acc_x
  p[5] += p[7] -- vy += acc_y
  p[8] += p[9] -- size += Δsize
 end)
end

function _draw()
 cls()
 foreach(players, Player.draw)
 foreach(particles, function (p)
  circfill(p[2], p[3], flr(p[8]), p[10])
 end)
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
