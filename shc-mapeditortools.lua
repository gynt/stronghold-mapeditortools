
--[[
  @TheRedDaemon:
  Some bigger restructuring might be necessary (one day). Among that:
    - from table.insert to direct index
    - even more visual space between function complexes
    - restructure function complexes
    - remove control functions where not needed anymore
    - a table of contents at the start, so that one could better CTRL+F to the intended place
]]--

-- //////////////////////////
-- // help text and status //
-- //////////////////////////


--[[
  Help text displayed by the console.
  
  Help text is created during start-up and can not be changed without restart?

  @TheRedDaemon
]]--
HELP = [[
This console is used to configure the additional map editor features.

    FEATURE.parameter = value           assign a new value to a feature parameter
    return FEATURE.parameter            return the current parameter value

As an example:

    MIRROR.mirrorMode = 'horizontal'    sets the mirror to 'horizontal'.
    return MIRROR.mirrorMode            returns the current MIRROR_MODE
    
Parameters are explained like this:

    FEATURE.parameter -> additional explanation
        possibleValues      additional value explanation
        ...
    
WARNING: Currently max 200 actions are supported. Big shapes, especially when mirrored, reach
         this limit very fast. So do not be surprised if only one half of a shape appears.

The following features are implemented and currently applied in the order they are mentioned:

    ## Shape Brush ##
    Uses the coordinates of two clicks (the first one does nothing) to create a shape.
    WARNING: The first coordinate is only invalidated after use or after disabling the shape brush.
             
    SHAPE.active -> deactivate/activate
        boolean             false or true
             
    SHAPE.shape -> the shape to apply
        "line"              a simple line between two points
        "rect"              rectangle seen from the front; clicks define edges
        "rect45"            rectangle along the diagonals; clicks define edges
        "circle"            a circle; first click sets middle, second border
        
    SHAPE.removeRememberedCoords -> if "true", than the first click is not drawn
        boolean             false or true
        
    SHAPE.connectShapes -> decides how shapes are drawn if multiple coordinates reach this phase
        true                coordinates are reused; for example, lines are connected
        false               coordinates are only used once
    
    ## Spray Brush ##
    "Sprays" the current coordinates by displacing them by a random amount.
    
    SPRAY.active -> deactivate/activate
        boolean             false or true
        
    SPRAY.sprayExp -> higher values lead to more positions close to the actual brush position
        Integer             whole numbers, should be bigger than 1
    
    SPRAY.spraySize -> max deviation from the actual brush position for both axes
        Integer             whole numbers
    
    SPRAY.sprayInt -> intensity; if random number bigger, skips the draw call
        Float               value between 0 to 1, inclusive   

    ## Shape Brush 2 ##
    Functions like "Shape Brush", but instead of "SHAPE", the feature name is "SHAPE_2".

    ## Mirroring ##
    Actions are mirrored around one axis.
    
    MIRROR.active -> deactivate/activate
        boolean             false or true
                            
    MIRROR.mirrorMode
        "horizontal"
        "vertical"
        "diagonal_x"
        "diagonal_y"
        "point"             mirror around the center of the map
        
    MIRROR.coordOrder -> order of coordinates after mirroring
        "shape"             draws original shape first, then the mirror
        "coord"             every single coordinate of the original shape is mirrored one after another
        
    ## Mirroring 2 ##
    Functions like "Mirroring", but instead of "MIRROR", the feature name is "MIRROR_2".
    Allows to apply a second mirror.
    Using the same mirror mode twice however will only apply the original coordinates a second time.

Available commands:
        help                display this help text again
        reload              reload the shc-mapmakerstools.lua file without restarting Stronghold.
        stack               get the current lua stack size
]]


--[[
  Creates status text.
  
  The text will contain the value "active". However, non-active features are filtered.
  
  Note: The "func" value is received, but is not placed into the string.

  @TheRedDaemon
]]--
function getStatus()
  local statusTable = {}
  statusTable[1] = "\nSTATUS (in execution order):\n" -- first new line
  
  local count = 2
  local featureCounter = 1
  for _, feature in ipairs(ACTIVE_TRANSFORMATIONS) do
    local featureStatus = feature:getPublicStatus()

    -- only active
    if featureStatus.active ~= nil and featureStatus.active == true then
      statusTable[count] = "\n" .. tostring(featureCounter) .. ". " .. tostring(featureStatus.__name) .. "\n"
      count = count + 1
      featureCounter = featureCounter + 1
      
      for field, value in pairs(featureStatus) do
        if not (field == "__name" or field == "func") then
          local toPad = 30 - string.len(field)
          local featStr = tostring(field) .. string.rep(" ", toPad) .. ":    " .. tostring(value)
          statusTable[count] = "\t" .. featStr .. "\n"
          count = count + 1
        end
      end
    end
  end
  
  if count < 3 then
    statusTable[count] = "No feature active at the moment.\n"
  end

  return table.concat(statusTable)
end


-- //////////////////////
-- // helper functions //
-- //////////////////////


--[[
  Returns "true" should the table be empty.

  source: https://stackoverflow.com/a/1252776
  
  @TheRedDaemon
]]--
function isTableEmpty(t)
  local next = next
  return next(t) == nil
end


--[[
  Gets the number of entries in a table.
  
  Apparently there is #, but this only works on array-style tables.
  O(N) is the most efficient this can get without meta structures (a "count" variable for example)
  source: https://stackoverflow.com/a/2705804
  
  @TheRedDaemon
]]--
function getTableLength(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end


--[[
  A simple rounding to full numbers function.
  
  Note: 0.5 -> 1, but -0.5 -> 0
  source: https://scriptinghelpers.org/questions/4850/how-do-i-round-numbers-in-lua-answered
  
  @TheRedDaemon
]]--
function round(x)
  return x + 0.5 - (x + 0.5) % 1
end


--[[
  Find coord duplicates in "coordTable".
  
  If "display" true -> prints duplicates
  
  @TheRedDaemon
]]--
function countCoordDuplicates(coordTable, display)
  if display ~= false and display ~= true then
    display = false -- default
  end
  
  local numberOfDuplicates = 0
  for indexOne, coordOne in ipairs(coordTable) do
    for indexTwo, coordTwo in ipairs(coordTable) do
      -- also ignore the same and previous entries to prevent duplicates of duplicates
      if indexOne < indexTwo and coordOne[1] == coordTwo[1] and coordOne[2] == coordTwo[2] then
        numberOfDuplicates = numberOfDuplicates + 1
      
        if display then
          print("Duplicate found: " ..coordOne[1] ..":" ..coordOne[2])
        end
      end
    end
  end
  return numberOfDuplicates
end



-- ////////////////////////////////////////
-- // brush and mirror support functions //
-- ////////////////////////////////////////


-- // spray brush //


--[[
  Generates a random deviation for the spray brush.
  
  "centeringExp" is the exponent used on a random value between 0 and 1. Higher values increase
  the chance that the deviation is small and the resulting coord more centered. Should be 1 or bigger.
  Max deviation for both axes is set by "size".
  
  @TheRedDaemon
]]--
function randomSprayDeviation(centeringExp, size)
  local rand = round((math.random()^centeringExp) * size)
  rand = math.random() < 0.5 and -rand or rand -- plus or minus
  return rand
end


-- // shape brush //


--[[
  Fills coordTable with {x,y} int coordinates using Bresenham's line algorithm.
  
  According to source, this version does not guarantee a coordinate order. Could be x0, y0 to x1, y1 or vise versa.
  source: https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm

  @TheRedDaemon
]]--
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


--[[
  Create coords in such a way that the player sees a rectangle.
  
  Used own function, maybe change to four "fillWithLineCoords" one day?
  (But this would only save visual space in this file.)

  @TheRedDaemon
]]--
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


--[[
  Create coords in such a way that the player sees a rectangle rotated by 45 degree.

  @TheRedDaemon
]]--
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
-- @TheRedDaemon: as long as there is a limit on the input actions, this function does not make much sense


  Create coords in such a way that the player sees a filled rectangle rotated by 45 degree.

  @TheRedDaemon

function fillWithFilledRect45Coords(x0, y0, x1, y1, coordTable)  
  for i = x0, x1, x0 < x1 and 1 or -1 do
    for j = y0, y1, y0 < y1 and 1 or -1 do
      table.insert(coordTable, {i, j})
    end
  end
end
]]--


--[[
  Function used to draw a circle using Mid-Point Circle Drawing Algorithm.
  
  source: https://www.geeksforgeeks.org/mid-point-circle-drawing-algorithm/
  
  Note:
    - originally used Bresenham’s Algorithm (source: https://www.geeksforgeeks.org/bresenhams-circle-drawing-algorithm/)
    - but it produced duplicates I was unable to remove
    
  @TheRedDaemon
]]--
function fillWithCircleCoords(x_centre, y_centre, xr, yr, coordTable)
  local r = round(math.sqrt((x_centre - xr)^2 + (y_centre - yr)^2))
  local x = r
  local y = 0
    
  -- Slightly changed for SHC, since it produced duplicates and wrong output:
  -- Printing the initial points on the axes after translation
  table.insert(coordTable, {r + x_centre, y_centre})
  if r > 0 then --When radius is zero only a single point will be printed
    table.insert(coordTable, {-r + x_centre, y_centre})
    table.insert(coordTable, {x_centre, r + y_centre})
    table.insert(coordTable, {x_centre, -r + y_centre})
  end
    
  -- Initializing the value of P
  local P = 1 - r
  while x > y do 
    y = y + 1
    
    if P <= 0 then -- Mid-point is inside or on the perimeter
      P = P + 2 * y + 1     
    else -- Mid-point is outside the perimeter
      x = x - 1
      P = P + 2 * y - 2 * x + 1
    end
      
    -- All the perimeter points have already been printed
    if x < y then break end
      
    -- Printing the generated point and its reflection in the other octants after translation
    table.insert(coordTable, {x + x_centre, y + y_centre})
    table.insert(coordTable, {-x + x_centre, y + y_centre})
    table.insert(coordTable, {x + x_centre, -y + y_centre})
    table.insert(coordTable, {-x + x_centre, -y + y_centre})
      
    -- If the generated point is on the line x = y then the perimeter points have already been printed
    if x ~= y then
      table.insert(coordTable, {y + x_centre, x + y_centre})
      table.insert(coordTable, {-y + x_centre, x + y_centre})
      table.insert(coordTable, {y + x_centre, -x + y_centre})
      table.insert(coordTable, {-y + x_centre, -x + y_centre})
    end
  end
end


-- // mirror support //


--[[
  Checks if the "mirrorMode" is supported.
  If not, returns "false" and sends message to console.

  @TheRedDaemon
]]--
function isValidMirrorMode(mirrorMode)
  if mirrorMode == "point" or mirrorMode == "horizontal" or mirrorMode == "vertical" or
      mirrorMode == "diagonal_x" or mirrorMode == "diagonal_y" then
    return true
  else
    print("Don't know this mirror mode: " .. mirrorMode)
    return false
  end
end


-- @gynt
function applyMirror(x, y, size, mirrorMode)
  local newx = x
  local newy = y
  
  --[[
    @TheRedDaemon:
  
    SUGGESTION: "point" is also a rotation
    -> maybe add the ability to apply a point rotation to the action instead
      - so that I could mirror the action in 4 corners, or even 8
      - center is between 199 and 200, so rotation likely requires translation by -199.5 before
      - Note -> do not forget to also use "size" for this rotations in some way; it is ignored by
                other modifications so far...
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
  end
  -- @TheRedDaemon: Fails silently to not clutter the console.
  
  return {newx, newy}
end



-- ///////////////////////
-- // control functions //
-- ///////////////////////


--[[
  Uses a previous click and the current click to generate NEW "coordlist" that forms a shape.
  Or will try to create multiple shapes in a NEW "coordlist" if it receives multiple coords.
  
  Returns an empty "coordlist" after it stored the first coordinate for the shape if
  "config.removeRememberedCoords" is set to "true".
  If multiple coords are received, then setting "config.connectShapes" to "true" will use non
  start or end coords twice and will result in connected shapes.
  A single shape should not produce duplicates. Multiple will.
  
  WARNING: Currently maximal 200 coords can be applied. This easily results in incomplete big shapes.
  WARNING: The first coordinate is only invalidated after use, after receiving multiple coords
           or after disabling the shape brush.
  
  @TheRedDaemon
]]--
function applyShape(config, coordlist, size)
  if not config.active or isTableEmpty(coordlist) then
    config.lastCoords = {} -- remove last entry if brush inactive (sadly happens on every call)
    return coordlist
  end
  local newCoordlist = {}
  
  -- trusting on continuous index (should this make issues: get length)
  -- currently no shape that takes three points, so this can be general
  if coordlist[2] == nil and isTableEmpty(config.lastCoords) then
    config.lastCoords = coordlist
    return config.removeRememberedCoords and newCoordlist or coordlist
  end
  
  local shape = config.shape
  local fillFunction = nil
  
  if shape == "line" then
    fillFunction = fillWithLineCoords
  elseif shape == "rect" then
    fillFunction = fillWithRectCoords
  elseif shape == "rect45" then
    fillFunction = fillWithRect45Coords
  elseif shape == "circle" then
    fillFunction = fillWithCircleCoords
  end
  
  if fillFunction == nil then
    print("No valid shape: " ..shape)
    config.lastCoords = {} -- remove due to invalid shape
    return coordlist
  end
  
  if coordlist[2] == nil then
    -- no shape with more than two coords, so:
    fillFunction(config.lastCoords[1][1], config.lastCoords[1][2],
        coordlist[1][1], coordlist[1][2], newCoordlist)
  else
    local connectShapes = config.connectShapes
  
    -- no shape with anything other than two coords, so the loop can be simple
    local lastCoord = nil
    for _, coord in ipairs(coordlist) do
      if lastCoord ~= nil then
        fillFunction(lastCoord[1], lastCoord[2], coord[1], coord[2], newCoordlist)
        lastCoord = connectShapes and coord or nil
      else
        lastCoord = coord
      end
    end
  end
  
  config.lastCoords = {} -- remove points after any kind of shape was applied
  
  -- print("Number of coord duplicates after applying shape: " ..countCoordDuplicates(newCoordlist)) -- debug
  
  return newCoordlist
end


--[[
  Modifies all coords in coordlist by adding a random deviation.
  
  If config.sprayInt < 1, this function will build a new coordlist with the remaining coords. 
  Produces coordinate duplicates.

  @TheRedDaemon
]]--
function applySpray(config, coordlist, size)
  if not config.active or isTableEmpty(coordlist) then
    return coordlist
  end
  
  local sprayInt = config.sprayInt
  local sprayExp = config.sprayExp
  local spraySize = config.spraySize
  
  if sprayInt < 1 then
    local newCoordlist = {}
  
    for _, coord in ipairs(coordlist) do
      -- only add coord if random number smaller then sprayInt
      if math.random() < sprayInt then
        coord[1] = coord[1] + randomSprayDeviation(sprayExp, spraySize)
        coord[2] = coord[2] + randomSprayDeviation(sprayExp, spraySize)
        table.insert(newCoordlist, coord)
      end
    end
    
    coordlist = newCoordlist
  else
    for _, coord in ipairs(coordlist) do
      coord[1] = coord[1] + randomSprayDeviation(sprayExp, spraySize)
      coord[2] = coord[2] + randomSprayDeviation(sprayExp, spraySize)
    end
  end
  
  -- print("Number of coord duplicates after applying spray: " ..countCoordDuplicates(coordlist)) -- debug
  
  return coordlist
end


--[[
  Mirror all coordinates and return a modified or new "coordlist" with all coordinates.
  
  The coordinate structure after mirroring might have some effects on the results.
  For example, bigger rocks might block each other.
  The order types are shown here, using an example where the shape "line" is used to draw a 3 coord line,
  which is then mirrored two times (first with vertical mirror, then horizontal):
  
   1     |     4                 1     |     4                 1     |     3
    2    |    7                   2    |    5                   5    |    7  
     3   |  10                     3   |   6                     9   |  11   
  _______|_______               _______|_______               _______|_______
         |                             |                             |       
     11  |  12                     9   |  12                     10  |  12   
    8    |    9                   8    |    11                  6    |    8  
   5     |     6                 7     |     10                2     |     4 
   
  original order                ordered by original shape     ordered by original coordinates
  (not supported anymore)       .coordOrder(both): "shape"    .coordOrder(both): "coord"
  
  Produces coordinate duplicates.
  
  @gynt (original), @TheRedDaemon
]]--
function applyMirrors(config, coordlist, size)
  local mirrorMode = config.mirrorMode
  if not config.active or isTableEmpty(coordlist) or not isValidMirrorMode(mirrorMode) then
    return coordlist
  end
  local coordOrder = config.coordOrder
  
  if coordOrder == "coord" then
    local newCoordTable = {}
    
    for _, coord in ipairs(coordlist) do
      table.insert(newCoordTable, coord)
      table.insert(newCoordTable, applyMirror(coord[1], coord[2], size, mirrorMode))
    end
    coordlist = newCoordTable
    
  elseif coordOrder == "shape" then
    -- @TheRedDaemon: # should only have number indexes, so this should be fine.
    for index = 1, #coordlist do
      table.insert(coordlist, applyMirror(coordlist[index][1], coordlist[index][2], size, mirrorMode))
    end
  else
    print("No valid coordinate order: " ..coordOrder)
  end
  
  -- print("Number of coord duplicates after applying mirrors: " ..countCoordDuplicates(coordlist)) -- debug
  
  return coordlist
end


-- @gynt
function erase(x, y, brush)
  return applyBrush(x, y, brush)
end


-- @gynt
function setTerrainTypeEarth(x, y, brush)
  return applyBrush(x, y, brush)
end


--[[
  change is actually a signed byte, it can be -1 for example to decrease terrain height

  @gynt
]]--
function changeTerrainHeight(x, y, brush, change)
  return transformTerrain(x, y, brush, change)
end


-- @gynt
function levelTerrain(x, y, brush, unknown)
  return transformTerrain(x, y, brush, unknown)
end


-- @gynt
function minHeightTerrain(x, y, brush, unknown)
  return transformTerrain(x, y, brush, unknown)
end


-- @gynt
function createPlateau(x, y, brush, intensity)
  return transformTerrain(x, y, brush, intensity)
end


-- @gynt
function createHill(x, y, intensity)
  return applyBrush(x, y, intensity)
end


-- @gynt
function placeAnimal(x, y, animalType)
  return applyBrush(x, y, animalType)
end


-- @gynt: functions that now do the actual thing required :)


--[[
  General function to create coordinatelist.
  
  WARNING: The only coordinate modification so far that respects "size" is "applyMirror".
  
  @TheRedDaemon 
]]--
function applyCoordModification(x, y, size)
  -- print("Current Coord: " ..x ..":" ..y) -- debug
  
  local coordinatelist = {{x, y}}
  for _, config in ipairs(ACTIVE_TRANSFORMATIONS) do -- ipairs to guarantee order
    coordinatelist = config.func(config, coordinatelist, size)
  end
  
  -- print("Total number of coords: " ..getTableLength(coordinatelist)) -- debug
  
  return coordinatelist
end


-- @gynt
function applyBrush (x, y, brush)
  coordinatelist = applyCoordModification(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, brush)
  end
  
  return coordinatelist
end


-- @gynt
function transformTerrain(x, y, brush, change)
  coordinatelist = applyCoordModification(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, brush)
    table.insert(coordpair, change)
  end
  
  return coordinatelist
end


-- @gynt
function setTerrainType(x, y, brush, terrainType, unknown)
  coordinatelist = applyCoordModification(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, brush)
    table.insert(coordpair, terrainType)
    table.insert(coordpair, unknown)
  end
  
  return coordinatelist
end


--[[
  objectType == 20 means the object is a rock and math.floor(rockType / 4)+1 will indicate the rock size
  
  @gynt
]]--
function placeTreeOrRock(x, y, objectType, rockType)
  
  if objectType == 20 then -- adjust with a translation for the fact that a rock can be larger than 1x1
    coordinatelist = applyCoordModification(x, y, math.floor(rockType/4)+1)  
  else
    coordinatelist = applyCoordModification(x, y, 1)  
  end
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, objectType)
    table.insert(coordpair, rockType)
  end
  
  return coordinatelist  
end



-- /////////////////////
-- // config and data //
-- /////////////////////


--[[
  Create default modification configurations using simple LUA OOP.
  Source: https://www.lua.org/pil/16.2.html

  Wrapped it in different scope to also test scoping and function assign.
  This can be changed.

  @TheRedDaemon
]]--
ConfigConstructor = {} -- default constructors
do

  
  -- // assert functions //
  
  
  -- @TheRedDaemon
  local function checkType(value, intendedType, failMessage)
    local res = type(value) == intendedType
    if not res and failMessage ~= nil then
      print(failMessage)
    end
    return res
  end

  
  -- @TheRedDaemon
  local function isBoolean(value)
    return checkType(value, "boolean", "The given parameter value was not true or false (Boolean).")
  end
  
  
  -- @TheRedDaemon
  local function isNumber(value)
    return checkType(value, "number", "The given parameter value was no number.")
  end
  
  
  -- @TheRedDaemon
  local function isInteger(value)
    local res = isNumber(value)
    if res and math.floor(value) ~= value then
      print("The given parameter value was no whole number (Integer).")
      res = false
    end
    return res
  end
  
  
  -- @TheRedDaemon
  local function isString(value)
    return checkType(value, "string", "The given parameter value was no string.")
  end
  
  
  --[[
    Checks if a number is in a specific range (inclusive).
    Setting "minRange" or "maxRange" to "nil" will assume no border.
  
    @TheRedDaemon
  ]]--
  local function isInRange(number, minRange, maxRange, rangeMessage)
    if minRange ~= nil and number < minRange then
      print("The given number is too small. Allowed range: ", rangeMessage)
      return false
    end
    
    if maxRange ~= nil and number > maxRange then
      print("The given number is too big. Allowed range: ", rangeMessage)
      return false
    end
    
    return true
  end
  
  
  -- // configuration tables //
  
  
  --[[
    Create default configuration base table.
  
    @TheRedDaemon
  ]]--
  local DefaultBase = {
    active      =   false   ,   -- is the modification active
    
    _FieldUtil_ =   {}      ,   -- includes check functions and help texts by parameter name
    __name = "Base Configuration Object", -- debug info
  }
  
  
  --[[
    Add dummy "func" to "DefaultBase".
    Executed if func in config not set. Returns "coordinatelist" unchanged.
  
    @TheRedDaemon
  ]]--
  function DefaultBase.func(config, coordinatelist, size)
    print("Noticed config without a valid function. No changes to coords.")
    return coordinatelist
  end
  
  
  --[[
    General function to set a field in the configuration.
    Also prints help texts.
    
    Returns true if any field was set. Might not be the field requested through "field".
  
    @TheRedDaemon
  ]]--
  function DefaultBase:setField(field, value)
    if field == nil then
      local featureCon = self._FieldUtil_[self.__name]
      local featureText = featureCon ~= nil and featureCon.help or nil
      if featureText == nil then
        featureText = "No feature description found."
      end
      
      print(featureText)
      return false
    end
    
    local fieldUtil = nil
    local currentClass = self
    repeat
      fieldUtil = currentClass._FieldUtil_[field]
      if fieldUtil == nil then
        currentClass = getmetatable(currentClass) -- check parent for validation or help text
        if currentClass == nil then
          print("No parameter handler for this name found: ", field)
          return false
        end
      end
    until (fieldUtil ~= nil)
    
    if value == nil then
      local fieldText = fieldUtil.help
      if fieldText == nil then
        fieldText = "No parameter description found."
      end
      print(fieldText)
      return false
    end
    
    return fieldUtil.set(self, field, value)
  end
  
  
  --[[
    Creates a status using the structure in _FieldUtil_.
    Aliases will be filtered by using rawget(), so that they do not fall through on accident.
    
    Will return a table of key value pairs. Keys are the parameter.
    The configuration description will be in "__name"..
  
    @TheRedDaemon
  ]]--
  function DefaultBase:getPublicStatus()
    local statusTable = {}
    
    statusTable.__name = self._FieldUtil_[self.__name] ~= nil and self.__name or "Unknown"
    
    local currentClass = self
    repeat
      local currentFieldUtil = nil
      repeat
        currentFieldUtil = rawget(currentClass, "_FieldUtil_")
        if currentFieldUtil == nil then
          currentClass = getmetatable(currentClass) -- check parent
        end
        if currentClass == nil then
          return statusTable -- we are done
        end
      until (currentFieldUtil ~= nil)

      for field, _ in pairs(currentFieldUtil) do
      
        -- will notice default fields, filters aliases, does not override (keeps specialized)
        if rawget(currentClass, field) ~= nil and statusTable[field] == nil then
          statusTable[field] = self[field] -- add current value
        end
      end
      
      currentClass = getmetatable(currentClass)
    until (currentClass == nil)
    
    return statusTable
  end
  
  
  --[[
    Constructs new object (or class, there does not seem to be a difference) from the default base values.
    "fields" is a table that can already provide values that extend the object or override functions.
  
    @TheRedDaemon
  ]]--
  function DefaultBase:new(fields)
    fields = fields or {}
    setmetatable(fields, self)
    self.__index = self
    self.__call = DefaultBase.setField -- sets __call always to default handler
    return fields
  end


  -- @TheRedDaemon: Create default configuration tables:


  local DefaultShape = DefaultBase:new{
    shape                   =   "line"          ,   -- shapes: "line", "rect", "rect45", "circle"
    removeRememberedCoords  =   true            ,   -- "true": coord added to "lastCoords" is removed from the pipeline
    connectShapes           =   false           ,   -- connectShapes: "true": coordlist index is only moved by 1 before the next shape is drawn
                                                    --                "false": uses coords only once, unused remainders are silently discarded
                            
    lastCoords              =   {}              ,   -- data: last selected points
                            
    func                    =   applyShape      ,
    
    __name = "Shape Feature Configuration", -- debug info
  }
  
  local DefaultMirror = DefaultBase:new{
    mirrorMode  =   "horizontal"    ,   -- mirroring type: "horizontal", "vertical", "diagonal_x", "diagonal_y", "point"
    coordOrder  =   "coord"         ,   -- order of coordinates after mirroring: "shape", "coord"
    
    func        =   applyMirrors    ,
    
    __name = "Mirror Feature Configuration", -- debug info
  }
  
  
  local DefaultSpray = DefaultBase:new{
    sprayExp    =   3               ,   -- defines how centered the random positions should be (higher -> more centered, should be bigger than 1)
    spraySize   =   8               ,   -- max spray deviation for both axes
    sprayInt    =   0.25            ,   -- intensity -> 0 to 1, if random number bigger, skips the draw call
    
    func        =   applySpray      ,
    
    __name = "Spray Feature Configuration", -- debug info
  }
  

  --[[
    Create all _FieldUtil_ for the configurations.
    
    @TheRedDaemon
  ]]--
  
  -- @TheRedDaemon: Do the (...).set functions need the field value?
  -- @TheRedDaemon: It might be beneficial in the future to create some helper functions.
  
  
  -- // base
  local baseFieldUtil = DefaultBase._FieldUtil_
  
  baseFieldUtil[DefaultBase.__name] = {}
  baseFieldUtil[DefaultBase.__name].help = [[
    
      ## Base Configuration ##
      This is a raw configuration object.
      If you can read this and you did not intend to experiment with the functions,
      please report this as a bug on github.]]
  
  -- func
  baseFieldUtil.func = {}
  
  function baseFieldUtil.func.set(config, field, value)
    print("The function of this configuration can not be changed with this method.")
  end
  
  baseFieldUtil.func.help = [[
    
      "func"
      The parameter "func" contains the function which will be called with this configuration.
      This is an internal value and should not be changed.]]
      
  -- active
  baseFieldUtil.active = {}
  
  function baseFieldUtil.active.set(config, field, value)
    local res = isBoolean(value)
    if res then
      config.active = value
      if value then
        print("Feature activated.")
      else
        print("Feature deactivated.")
      end
    end
    return res
  end
  
  baseFieldUtil.active.help = [[
    
      "active"
      General activation parameter. Controls whether the feature is active or not.
      "active" is a likely candidate for a parameter that is set by other parameter changes.
      
          false                 feature is deactivated
          true                  feature is active
          
      Default: false]]
  
  
  -- // spray
  DefaultSpray._FieldUtil_ = {}
  local sprayFieldUtil = DefaultSpray._FieldUtil_
  
  sprayFieldUtil[DefaultSpray.__name] = {}
  sprayFieldUtil[DefaultSpray.__name].help = [[
    
      ## Spray Modification ##
      TODO
  ]]
  
  -- sprayExp
  sprayFieldUtil.sprayExp = {}
  
  function sprayFieldUtil.sprayExp.set(config, field, value)
    local res = isNumber(value) and isInRange(value, 1, nil, ">= 1")
    if res then
      config.sprayExp = value
      print("Set spray exponent to: ", value)
    end
    return res
  end
  
  sprayFieldUtil.sprayExp.help = [[
    
      "sprayExp", alias: "exp"
      TODO
  ]]
  
  sprayFieldUtil.exp = sprayFieldUtil.sprayExp -- alias
  
  -- sprayInt
  sprayFieldUtil.sprayInt = {}
  
  function sprayFieldUtil.sprayInt.set(config, field, value)
    local res = isNumber(value) and isInRange(value, 0, 1, "0 <= value <= 1.0")
    if res then
      config.sprayInt = value
      print("Set spray intensity to: ", value)
    end
    return res
  end
  
  sprayFieldUtil.sprayInt.help = [[
    
      "sprayInt", alias: "int"
      TODO
  ]]
  
  sprayFieldUtil.int = sprayFieldUtil.sprayInt -- alias
  
  -- spraySize
  sprayFieldUtil.spraySize = {}
  
  function sprayFieldUtil.spraySize.set(config, field, value)
    local res = isInteger(value) and isInRange(value, 0, nil, ">= 0")
    if res then
      config.spraySize = value
      print("Set spray size to: ", value)
    end
    return res
  end
  
  sprayFieldUtil.spraySize.help = [[
    
      "spraySize", alias: "size"
      TODO
  ]]
  
  sprayFieldUtil.size = sprayFieldUtil.spraySize -- alias
  
  
  -- // mirror
  DefaultMirror._FieldUtil_ = {}
  local mirrorFieldUtil = DefaultMirror._FieldUtil_
  
  mirrorFieldUtil[DefaultMirror.__name] = {}
  mirrorFieldUtil[DefaultMirror.__name].help = [[
    
      ## Mirror Modification ##
      TODO
  ]]
  
  -- mirrorMode
  mirrorFieldUtil.mirrorMode = {}
  
  function mirrorFieldUtil.mirrorMode.set(config, field, value)
    local res = isString(value)
    if res then
      if value == "none" or value == "off" then
        config.active = false
        print("Mirror deactivated.")
      elseif value == "horizontal" or value == "vertical" or
          value == "diagonal_x" or value == "diagonal_y" or
          value == "point" then
        config.mirrorMode = value
        config.active = true
        print("Set mirror active and to mode: ", value)
      else
        res = false
        print("No valid mirror mode: ", value)
      end
    end
    return res
  end
  
  mirrorFieldUtil.mirrorMode.help = [[
    
      "mirrorMode", alias: "mode"
      TODO
  ]]
  
  mirrorFieldUtil.mode = mirrorFieldUtil.mirrorMode -- alias
  
  -- coordOrder
  mirrorFieldUtil.coordOrder = {}
  
  function mirrorFieldUtil.coordOrder.set(config, field, value)
    local res = isString(value)
    if res then
      if value == "shape" or value == "coord" then
        config.coordOrder = value
        print("Set coordinate order to: ", value)
      else
        res = false
        print("No valid coordinate order: ", value)
      end
    end
    return res
  end
  
  mirrorFieldUtil.coordOrder.help = [[
    
      "coordOrder", alias: "order"
      TODO
  ]]
  
  mirrorFieldUtil.order = mirrorFieldUtil.coordOrder -- alias
  
  
  -- // shape
  DefaultShape._FieldUtil_ = {}
  local shapeFieldUtil = DefaultShape._FieldUtil_
  
  shapeFieldUtil[DefaultShape.__name] = {}
  shapeFieldUtil[DefaultShape.__name].help = [[
    
      ## Shape Modification ##
      TODO
  ]]
  
  -- shape
  shapeFieldUtil.shape = {}
  
  function shapeFieldUtil.shape.set(config, field, value)
    local res = isString(value)
    if res then
      if value == "none" or value == "off" then
        config.active = false
        print("Shape brush deactivated.")
      elseif value == "line" or value == "rect" or
          value == "rect45" or value == "circle" then
        config.shape = value
        config.active = true
        print("Set shape brush active and to shape: ", value)
      else
        res = false
        print("No valid shape: ", value)
      end
    end
    return res
  end
  
  shapeFieldUtil.shape.help = [[
    
      "shape"
      TODO
  ]]
  
  -- removeRememberedCoords
  shapeFieldUtil.removeRememberedCoords = {}
  
  function shapeFieldUtil.removeRememberedCoords.set(config, field, value)
    local res = isBoolean(value)
    if res then
      config.removeRememberedCoords = value
      if value then
        print("Remembered coordinates are now removed from the pipeline.")
      else
        print("Remembered coordinates will stay in the pipeline.")
      end
    end
    return res
  end
  
  shapeFieldUtil.removeRememberedCoords.help = [[
    
      "removeRememberedCoords", alias: "remove"
      TODO
  ]]
   
  shapeFieldUtil.remove = shapeFieldUtil.removeRememberedCoords -- alias
  
  -- connectShapes
  shapeFieldUtil.connectShapes = {}
  
  function shapeFieldUtil.connectShapes.set(config, field, value)
    local res = isBoolean(value)
    if res then
      config.connectShapes = value
      if value then
        print("Coordinates will be reused between shapes.")
      else
        print("Coordinates are only used once.")
      end
    end
    return res
  end
  
  shapeFieldUtil.connectShapes.help = [[
    
      "connectShapes", alias: "connect"
      TODO
  ]]
   
  shapeFieldUtil.connect = shapeFieldUtil.connectShapes -- alias


  -- Add the default new functions to "ConfigConstructor":
  
  
  -- @TheRedDaemon 
  function ConfigConstructor.newBaseConfig(fields)
    return DefaultBase:new(fields)
  end
  
  
  -- @TheRedDaemon
  function ConfigConstructor.newSprayConfig(fields)
    return DefaultSpray:new(fields)
  end
  
  
  -- @TheRedDaemon
  function ConfigConstructor.newShapeConfig(fields)
    return DefaultShape:new(fields)
  end
  
  
  -- @TheRedDaemon
  function ConfigConstructor.newMirrorConfig(fields)
    return DefaultMirror:new(fields)
  end
end


-- @TheRedDaemon: Create modification configurations:


mirror = ConfigConstructor.newMirrorConfig()

-- @TheRedDaemon: Second mirror. Sends table with from default deviating value.
mirror2 = ConfigConstructor.newMirrorConfig{ mirrorMode = "vertical" }

spray = ConfigConstructor.newSprayConfig()

shape = ConfigConstructor.newShapeConfig()

shape2 = ConfigConstructor.newShapeConfig{ connectShapes = true }


--[[
  Coordinate modification order
  
  Lua was seemingly not able to add global function refs at the start (before definition?).
  So the array and it's values are created here.

  @TheRedDaemon
]]--
ACTIVE_TRANSFORMATIONS = {
   shape        ,           -- 1. draw shape
   spray        ,           -- 2. mess it up
   shape2       ,           -- 3. maybe create more complex shape
   mirror       ,           -- 4. mirror
   mirror2      ,           -- 5. second mirror
}