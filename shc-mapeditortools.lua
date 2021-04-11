
-- /////////////////////
-- // config and data //
-- /////////////////////


MIRROR_MODE = "off"
MIRROR_MODE2 = "off"


-- brush config
BRUSH = "normal"


-- spray config
BRUSH_SPRAY_EXP = 3 -- defines how centered the random positions should be (higher -> more centered, should be bigger than 1)
BRUSH_SPRAY_SIZE = 8 -- TEMP? Would need reliable way to get the set brush size, regardless of the action
BRUSH_SPRAY_INT = 0.25 -- intensity -> 0 to 1, if random number bigger, skips the draw call


-- shape config
BRUSH_SHAPE = "line" -- shapes: "line", "rect", "rect45", "circle"
-- shape data
BRUSH_SHAPE_LAST = {} -- last selected points



-- //////////////////////
-- // helper functions //
-- //////////////////////


-- source: https://stackoverflow.com/a/1252776
function isTableEmpty(t)
  local next = next
  return next(t) == nil
end


--[[
  Apparently there is #, but this only works on array-style tables.
   -> Here good enough, but these functions should work in general.
  O(N) is the most efficient this can get without meta structures (a "count" variable for example)
]]--
-- source: https://stackoverflow.com/a/2705804
function getTableLength(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end


-- source: https://scriptinghelpers.org/questions/4850/how-do-i-round-numbers-in-lua-answered
-- Note: 0.5 -> 1, -0.5 -> 0
function round(x)
  return x + 0.5 - (x + 0.5) % 1
end


-- find coord duplicates in "coordTable"
-- if "display" true -> prints duplicates
function countCoordDuplicates(coordTable, display)
  if display ~= false and display ~= true then
    display = false -- default
  end
  
  local numberOfDuplicates = 0
  for keyOne, coordOne in pairs(coordTable) do
    for keyTwo, coordTwo in pairs(coordTable) do
      -- also ignore the same entry
      if keyOne ~= keyTwo and coordOne[1] == coordTwo[1] and coordOne[2] == coordTwo[2] then
        numberOfDuplicates = numberOfDuplicates + 1
      
        if display then
          print("Duplicate found: " ..coordOne[1] ..":" ..coordOne[2])
        end
      end
    end
  end
  return numberOfDuplicates
end


-- /////////////////////////////
-- // brush support functions //
-- /////////////////////////////


-- // spray brush //


-- generates a random deviation for the spray brush using the size
function randomSprayDeviation(size)
  local rand = round((math.random()^BRUSH_SPRAY_EXP) * size)
  rand = math.random() < 0.5 and -rand or rand -- plus or minus
  return rand
end


-- // shape brush //


-- Fills coordTable with {x,y} int coordinates using Bresenham's line algorithm.
-- According to source, this version does not guarantee a coordinate order. Could be x0, y0 to x1, y1 or vise versa.
-- source: https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm 
function fillWithLineCoords(x0, y0, x1, y1, coordTable)      
  local dx = math.abs(x1 - x0)
  local sx = x0 < x1 and 1 or -1
  local dy = -math.abs(y1 - y0)
  local sy = y0 < y1 and 1 or -1
  local err = dx + dy  -- error value e_xy
  while true do  -- loop
    table.insert(coordTable, {x0, y0})
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 >= dy then -- e_xy+e_x > 0
        err = err + dy
        x0 = x0 + sx
    end
    if e2 <= dx then -- e_xy+e_y < 0
        err = err + dx
        y0 = y0 + sy
    end
  end
end


-- create coords in such a way that the player sees a rectangle
-- used weird own function, maybe change to four "fillWithLineCoords" one day
function fillWithRectCoords(x0, y0, x1, y1, coordTable)
  local xDiff = x1 - x0
  local yDiff = y1 - y0
  local stepsSide = (xDiff - yDiff) / 2
  local stepsDown = (xDiff + yDiff) / 2

  -- prevent duplicates (could also use line algorithm instead?)
  if stepsSide == 0 or stepsDown == 0 then
    local isDownLine = stepsSide == 0
    local steps = isDownLine and stepsDown or stepsSide
    for i = 0, steps, 0 < steps and 1 or -1 do
      if isDownLine then
        table.insert(coordTable, {x0 + i, y0 + i})
      else
        table.insert(coordTable, {x0 + i, y0 - i})
      end
    end
    return
  end

  for i = 0, stepsSide, 0 < stepsSide and 1 or -1 do
    table.insert(coordTable, {x0 + i, y0 - i})
    table.insert(coordTable, {x1 - i, y1 + i})
  end

  local ySign = 0 < stepsDown and 1 or -1
  for i = 0 + ySign, stepsDown - ySign + ySign * (stepsDown % 1 ~= 0 and 1 or 0), ySign do
    table.insert(coordTable, {x0 + i, y0 + i})
    table.insert(coordTable, {x1 - i, y1 - i})
  end
end


-- create coords in such a way that the player sees a rectangle rotated by 45 degree
function fillWithRect45Coords(x0, y0, x1, y1, coordTable)
  -- prevent duplicates (could also use line algorithm instead?)
  if x0 == x1 or y0 == y1 then
    local xLine = x0 == x1
    local startPos = xLine and y0 or x0
    local endPos = xLine and y1 or x1
    for i = startPos, endPos, startPos < endPos and 1 or -1 do
      if xLine then
        table.insert(coordTable, {x0, i})
      else
        table.insert(coordTable, {i, y0})
      end
    end
    return
  end

  for i = x0, x1, x0 < x1 and 1 or -1 do
    table.insert(coordTable, {i, y0})
    table.insert(coordTable, {i, y1})
  end
  
  local ySign = y0 < y1 and 1 or -1
  for i = y0 + ySign, y1 - ySign, ySign do -- skip edges set by run over x
    table.insert(coordTable, {x0, i})
    table.insert(coordTable, {x1, i})
  end
end


--[[
-- as long as there is a limit on the input actions, this function does not make much sense

-- create coords in such a way that the player sees a filled rectangle rotated by 45 degree
function fillWithFilledRect45Coords(x0, y0, x1, y1, coordTable)  
  for i = x0, x1, x0 < x1 and 1 or -1 do
    for j = y0, y1, y0 < y1 and 1 or -1 do
      table.insert(coordTable, {i, j})
    end
  end
end
]]--


-- // mirror support //


-- mirror all coordinates and add the new coordinates to the coordTable
function applyMirrors(coordTable, size)
  -- I lack LUA knowledge, so there might be a more efficient way than a second array...
  local dummyCoordTable = {}
  for _, coord in pairs(coordTable) do
    if MIRROR_MODE ~= "off" then
      local firstMirror = applyMirror(coord[1], coord[2], size, MIRROR_MODE)
      table.insert(dummyCoordTable, firstMirror)
      
      if MIRROR_MODE2 ~= "off" then
        table.insert(dummyCoordTable, applyMirror(coord[1], coord[2], size, MIRROR_MODE2))
        table.insert(dummyCoordTable, applyMirror(firstMirror[1], firstMirror[2], size, MIRROR_MODE2))
      end
    end
  end
  for _, coord in pairs(dummyCoordTable) do
    table.insert(coordTable, coord)
  end
end


function applyMirror(x, y, size, mirrorMode)
  local newx = x
  local newy = y
  
  --[[
    SUGGESTION: "point" is more a rotation
    -> maybe add the ability to apply a point rotation to the action instead
      - so that I could mirror the action in 4 corners, or even 8
      - point mirror 1 + point mirror 2 does what it should (looks like only one mirror), but maybe not what is expected
  ]]--
  if mirrorMode == "point" then
    newx = (399 - x) - (size - 1)
    newy = (399 - y) - (size - 1)
  elseif mirrorMode == "horizontal" then
    newx = (399 - y) - (size - 1)
    newy = (399 - x) - (size - 1)
  elseif mirrorMode == "vertical" then
    newx = y
    newy = x
  elseif mirrorMode == "diagonal_x" then
    newx = x
    newy = 399 - y - (size - 1)
  elseif mirrorMode == "diagonal_y" then
    newx = 399 - x - (size - 1)
    newy = y
  else
    print("Don't know this MIRROR_MODE: " .. mirrorMode)
  end
  return {newx, newy}
end



-- ///////////////////////
-- // control functions //
-- ///////////////////////


function applyBrushModification(x, y, size)
  print("Current Coord: " ..x ..":" ..y)

  coordlist = {} -- If I understand LUA right, this is a global variable and is reset every call, right?
  
  -- apply spray brush
  if BRUSH == "spray" then
  
    -- return empty coordlist to skip drawing
    if math.random() > BRUSH_SPRAY_INT then
      return coordlist
    end
  
    x = x + randomSprayDeviation(BRUSH_SPRAY_SIZE)
    y = y + randomSprayDeviation(BRUSH_SPRAY_SIZE)
  end
  
  --[[
    apply shape brush
    BUG?: Big draw requests are not completely applied. Some sort of limit?
    TODO?: shape coords are not applied in a very structured order, currently it seems to be:
      - actual coords (direction not defined currently) -> mirrors of first point, mirrors of second point,...
        - this could be better
  ]]--
  if BRUSH == "shape" then
    
    -- currently no shape that takes three point, so this can be general
    if isTableEmpty(BRUSH_SHAPE_LAST) then
      BRUSH_SHAPE_LAST = {x,y}
      return coordlist -- skip drawing, only remember
    end
  
    if BRUSH_SHAPE == "line" then
      fillWithLineCoords(BRUSH_SHAPE_LAST[1], BRUSH_SHAPE_LAST[2], x, y, coordlist)
    elseif BRUSH_SHAPE == "rect" then
      fillWithRectCoords(BRUSH_SHAPE_LAST[1], BRUSH_SHAPE_LAST[2], x, y, coordlist)
    elseif BRUSH_SHAPE == "rect45" then
      fillWithRect45Coords(BRUSH_SHAPE_LAST[1], BRUSH_SHAPE_LAST[2], x, y, coordlist)
    else
      print("No valid shape: " ..BRUSH_SHAPE)
    end
    
    BRUSH_SHAPE_LAST = {} -- remove point after shape was applied (or failed to do so)
  else
    BRUSH_SHAPE_LAST = {} -- remove last entry, even on brush switch (could be better...)
    
    table.insert(coordlist, {x,y}) -- add coords -> I do not like this placement, but shape would add them twice otherwise
  end
  
  applyMirrors(coordlist, size)
  
  print("Number of duplicates: " ..countCoordDuplicates(coordlist))
  
  return coordlist
end


function erase(x, y, brush)
  return applyBrush(x, y, brush)
end

function setTerrainTypeEarth(x, y, brush)
  return applyBrush(x, y, brush)
end

 -- change is actually a signed byte, it can be -1 for example to decrease terrain height
function changeTerrainHeight(x, y, brush, change)
  return transformTerrain(x, y, brush, change)
end

function levelTerrain(x, y, brush, unknown)
  return transformTerrain(x, y, brush, unknown)
end

function minHeightTerrain(x, y, brush, unknown)
  return transformTerrain(x, y, brush, unknown)
end

function createPlateau(x, y, brush, intensity)
  return transformTerrain(x, y, brush, intensity)
end

function createHill(x, y, intensity)
  return applyBrush(x, y, intensity)
end

function placeAnimal(x, y, animalType)
  return applyBrush(x, y, animalType)
end


 -- functions that now do the actual thing required :)

function applyBrush (x, y, brush)
  coordinatelist = applyBrushModification(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, brush)
  end
  
  return coordinatelist
end

function transformTerrain(x, y, brush, change)
  coordinatelist = applyBrushModification(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, brush)
    table.insert(coordpair, change)
  end
  
  return coordinatelist
end

function setTerrainType(x, y, brush, terrainType, unknown)
  coordinatelist = applyBrushModification(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, brush)
    table.insert(coordpair, terrainType)
    table.insert(coordpair, unknown)
  end
  
  return coordinatelist
end

 -- objectType == 20 means the object is a rock and math.floor(rockType / 4)+1 will indicate the rock size
function placeTreeOrRock(x, y, objectType, rockType)
  
  if objectType == 20 then -- adjust with a translation for the fact that a rock can be larger than 1x1
    coordinatelist = applyBrushModification(x, y, math.floor(rockType/4)+1)  
  else
    coordinatelist = applyBrushModification(x, y, 1)  
  end
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, objectType)
    table.insert(coordpair, rockType)
  end
  
  return coordinatelist  
end