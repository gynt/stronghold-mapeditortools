
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

This console is used to configure additional map editor features.
(feature, parameter and value are dummy names)

    feature()                           displays feature help text
    feature("parameter")                displays parameter help text
    feature("parameter", value)         assign a new value to a feature parameter


To get the current configurations you can use:


    status                              get all parameters of the active features
    return feature.parameter            get the value of one parameter

The following features are implemented and currently applied in the order they are mentioned:

    shape, spray, shape2, mirror, mirror2

Use for example "mirror()" to get an explanation and a parameter list.

WARNING: Currently max 200 actions are supported. Big shapes, especially when mirrored, reach
         this limit very fast. So do not be surprised if only one half of a shape appears.
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
  Max deviation for both axes is set by the difference between "sizeMin" and "sizeMax".
  
  @TheRedDaemon
]]--
function randomSprayDeviation(centeringExp, sizeMin, sizeMax)
  local range = sizeMax - sizeMin
  local rand = round((math.random()^centeringExp) * range) + sizeMin
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
function applyMirrorFunction(x, y, size, mirrorMode)
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
  Modifies coords in coordlist by adding a random deviation.
  
  If config.sprayInt < 1 or config.keepOriginalCoord, this function will build
  a new coordlist with the remaining coords.
  For a description of the config parameters see default values or HELP text.
  
  Produces coordinate duplicates.

  @TheRedDaemon
]]--
function applySpray(config, coordlist, size)
  if not config.active or isTableEmpty(coordlist) then
    return coordlist
  end
  
  local sprayInt = config.sprayInt
  local sprayExp = config.sprayExp
  
  -- very simple structure, easy to break, but should be ok
  local sprayMin = config.sprayMin
  local sprayMax = config.sprayMax
  
  -- requires more complicated algorithm
  if config.keepOriginalCoord then
    local sprayIntMode = config.sprayIntMode
    local coordOrder = config.coordOrder
    local intOnOrig = sprayIntMode == "original" or sprayIntMode == "both"
    local intOnDev = sprayIntMode ~= "original" -- always needed, except when "original"
    
    if not (coordOrder == "coordOriginal" or coordOrder == "coordDeviated" or
        coordOrder == "original" or coordOrder == "deviated") then
      print("No valid coordOrder for spray: " ..coordOrder)
      return coordlist
    end
    
    if not (intOnOrig or sprayIntMode == "together" or
        sprayIntMode == "deviated" or sprayIntMode == "separator") then
      print("No valid sprayIntMode for spray: " ..sprayIntMode)
      return coordlist
    end
    
    local keepOriginFunc
    if sprayIntMode == "together" then
      keepOriginFunc = function(keepDev)
        return keepDev
      end
    elseif sprayIntMode == "separator" then
      keepOriginFunc = function(keepDev)
        return not keepDev
      end
    else
      keepOriginFunc = function(keepDev)
        return not intOnOrig or math.random() < sprayInt
      end
    end
    
    local originalCoords = {}
    local deviatedCoords = (coordOrder == "coordOriginal" or
        coordOrder == "coordDeviated") and originalCoords or {}
    
    -- switches coords apply order for "coordDeviated"
    local coordAddFunc
    if coordOrder == "coordDeviated" then
      coordAddFunc = function(origCoord, devCoord)
        if devCoord ~= nil then
          table.insert(deviatedCoords, devCoord)
        end
        if origCoord ~= nil then
          table.insert(originalCoords, origCoord)
        end
      end
    else
      coordAddFunc = function(origCoord, devCoord)
        if origCoord ~= nil then
          table.insert(originalCoords, origCoord)
        end
        if devCoord ~= nil then
          table.insert(deviatedCoords, devCoord)
        end
      end
    end
    
    for _, coord in ipairs(coordlist) do
      local keepDev = not intOnDev or math.random() < sprayInt 
      local keepOrigin = keepOriginFunc(keepDev)
    
      local origCoord = keepOrigin and coord or nil
      local devCoord = keepDev and {
            coord[1] + randomSprayDeviation(sprayExp, sprayMin, sprayMax),
            coord[2] + randomSprayDeviation(sprayExp, sprayMin, sprayMax)
          } or nil

      coordAddFunc(origCoord, devCoord)
    end
    
    -- add coords if not already one table
    if coordOrder == "original" then
      for _, coord in ipairs(deviatedCoords) do
        table.insert(originalCoords, coord)
      end
    elseif coordOrder == "deviated" then
      for _, coord in ipairs(originalCoords) do
        table.insert(deviatedCoords, coord)
      end
      
      originalCoords = deviatedCoords
    end
    
    coordlist = originalCoords
  else
    -- "sprayIntMode" or "coordOrder" only has an effect if original is kept
    if sprayInt < 1 then
      local newCoordlist = {}
    
      for _, coord in ipairs(coordlist) do
        -- only add coord if random number smaller then sprayInt
        if math.random() < sprayInt then
          coord[1] = coord[1] + randomSprayDeviation(sprayExp, sprayMin, sprayMax)
          coord[2] = coord[2] + randomSprayDeviation(sprayExp, sprayMin, sprayMax)
          table.insert(newCoordlist, coord)
        end
      end
      
      coordlist = newCoordlist
    else
      for _, coord in ipairs(coordlist) do
        coord[1] = coord[1] + randomSprayDeviation(sprayExp, sprayMin, sprayMax)
        coord[2] = coord[2] + randomSprayDeviation(sprayExp, sprayMin, sprayMax)
      end
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
function applyMirror(config, coordlist, size)
  local mirrorMode = config.mirrorMode
  if not config.active or isTableEmpty(coordlist) or not isValidMirrorMode(mirrorMode) then
    return coordlist
  end
  local coordOrder = config.coordOrder
  
  if coordOrder == "coord" then
    local newCoordTable = {}
    
    for _, coord in ipairs(coordlist) do
      table.insert(newCoordTable, coord)
      table.insert(newCoordTable, applyMirrorFunction(coord[1], coord[2], size, mirrorMode))
    end
    coordlist = newCoordTable
    
  elseif coordOrder == "shape" then
    -- @TheRedDaemon: # should only have number indexes, so this should be fine.
    for index = 1, #coordlist do
      table.insert(coordlist, applyMirrorFunction(coordlist[index][1], coordlist[index][2], size, mirrorMode))
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
    General function to guard a simple field assignment.
    If this configuration does not have an index named "field", the assignment is prevented.
    
    WARNING: Does not prevent wrong assignments to valid fields.
  
    @gynt, @TheRedDaemon
  ]]--
  function DefaultBase:guardedAssign(field, value)
    if self[field] == nil then
      print("'" .. tostring(field) .. "' is not a valid parameter for this feature.")
    else
      rawset(self, field, value)
    end
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
    self.__newindex = DefaultBase.guardedAssign -- sets __newindex always to default handler
    return fields
  end


  -- @TheRedDaemon: Create default configuration tables:


  local DefaultShape = DefaultBase:new{
    shape                   =   "line"          ,   -- shapes: "line", "rect", "rect45", "circle"
    removeRememberedCoords  =   true            ,   -- "true": coord added to "lastCoords" is removed from the pipeline
    connectShapes           =   false           ,   -- connectShapes: "true": coordlist index is only moved by 1 before the next shape is drawn
                                                    --                "false": uses coords only once, unused remainders are silently discarded
             
    --[[
      @TheRedDaemon: I am a bit annoyed that this config holds some status.
      
      SUGGESTION:
        Maybe use yet another modification "applyCollector" (or something like this), which collects an amount
        of coords before giving all of it to the next stage, so one would have an extra system for that.
        Options could be the number to collect and whether or not the collected coords should be devoured.
        Issues:
          - Too complicated for now -> Shape would need two options to work.
          - Resetting the collections would require some sort of notification, like a "changed brush" or
            "deselected" tool event.
    ]]--
    lastCoords              =   {}              ,   -- data: last selected points
                            
    func                    =   applyShape      ,
    
    __name = "Shape Feature Configuration", -- debug info
  }
  
  local DefaultMirror = DefaultBase:new{
    mirrorMode  =   "point"         ,   -- mirroring type: "horizontal", "vertical", "diagonal_x", "diagonal_y", "point"
    coordOrder  =   "coord"         ,   -- order of coordinates after mirroring: "shape", "coord"
    
    func        =   applyMirror     ,
    
    __name = "Mirror Feature Configuration", -- debug info
  }
  
  
  local DefaultSpray = DefaultBase:new{
    sprayExp            =   3               ,   -- higher -> more centered, should be bigger than 1
    sprayMax            =   8               ,   -- max spray deviation for both axes
    sprayMin            =   0               ,   -- min spray deviation for both axes
    sprayInt            =   0.25            ,   -- intensity -> 0 to 1, if random number bigger, skips the draw call
    keepOriginalCoord   =   false           ,   -- "true": also applies the original coord alongside the deviated
    sprayIntMode        =   "both"          ,   -- effect of Int on: "deviated", "original", "both", "together", "separator"
    coordOrder          =   "original"      ,   -- which coords are applied first: "original", "deviated", "coordOriginal", "coordDeviated"
    
    func                =   applySpray      ,
    
    __name = "Spray Feature Configuration", -- debug info
  }
  

  --[[
    Create all _FieldUtil_ for the configurations.
    
    @TheRedDaemon
  ]]--
  
  -- @TheRedDaemon: Do the (...).set functions need the field value?
  -- @TheRedDaemon: It might be beneficial to create some helper functions in the future.
  
  
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
      This parameter might be set by other parameter changes.
      
          false                     feature is deactivated
          true                      feature is active
          
      Default: ]] .. tostring(DefaultBase.active)
  
  
  -- // spray
  DefaultSpray._FieldUtil_ = {}
  local sprayFieldUtil = DefaultSpray._FieldUtil_
  
  sprayFieldUtil[DefaultSpray.__name] = {}
  sprayFieldUtil[DefaultSpray.__name].help = [[
    
      ## Spray Modification ##
      "Sprays" the received coordinates by displacing them by a random amount.
    
      Parameter                     Possible values
          active                        false, true
          sprayExp / exp                >= 1.0
          spraySize / size              >= 0
          sprayMin / min                0 <= value <= sprayMax
          sprayMax / max                >= sprayMin
          sprayInt / int                0.0 <= value <= 1.0
          keepOriginalCoord / keep      false, true
          sprayIntMode / mode           "deviated", "original", "both", "together", "separator",
                                            "none", "off"
          coordOrder / order            "original", "deviated", "coordOriginal", "coordDeviated"]]
  
  -- sprayExp
  sprayFieldUtil.sprayExp = {}
  
  function sprayFieldUtil.sprayExp.set(config, field, value)
    local res = isNumber(value) and isInRange(value, 1, nil, ">= 1.0")
    if res then
      config.sprayExp = value
      print("Set spray exponent to: ", value)
    end
    return res
  end
  
  sprayFieldUtil.sprayExp.help = [[
    
      "sprayExp", alias: "exp"
      This value is the exponent that is applied to a random number between 0.0 and 1.0.
      Higher values lead to smaller deviations and more positions close
      to the actual brush coordinate.
          
          >= 1.0                    numbers equal to / bigger than 1.0

      Default: ]] .. tostring(DefaultSpray.sprayExp)
  
  sprayFieldUtil.exp = sprayFieldUtil.sprayExp -- alias
  
  -- sprayInt
  sprayFieldUtil.sprayInt = {}
  
  function sprayFieldUtil.sprayInt.set(config, field, value)
    local res = isNumber(value) and isInRange(value, 0, 1, "0.0 <= value <= 1.0")
    if res then
      config.sprayInt = value
      print("Set spray intensity to: ", value)
    end
    return res
  end
  
  sprayFieldUtil.sprayInt.help = [[
    
      "sprayInt", alias: "int"
      Basically the intensity of the spray.
      If a random number between 0.0 and 1.0 is bigger than this value, a coordinate is removed.
      This check is made for every coordinate.
                
          0.0 <= value <= 1.0       numbers between 0.0 and 1.0 (inclusive)

      Default: ]] .. tostring(DefaultSpray.sprayInt)
  
  sprayFieldUtil.int = sprayFieldUtil.sprayInt -- alias
  
  -- sprayMin
  sprayFieldUtil.sprayMin = {}
  
  function sprayFieldUtil.sprayMin.set(config, field, value)
    local res = isInteger(value) and isInRange(value, 0, config.sprayMax, "0 <= value <= sprayMax")
    if res then
      config.sprayMin = value
      print("Set spray min to: ", value)
    end
    return res
  end
  
  sprayFieldUtil.sprayMin.help = [[
    
      "sprayMin", alias: "min"
      This value sets the minimal deviation from the actual brush position for both axes.

          0 <= value <= sprayMax    whole numbers equal to / bigger than 0 and
                                        smaller / equal to the parameter "sprayMax"

      Default: ]] .. tostring(DefaultSpray.sprayMin)
  
  sprayFieldUtil.min = sprayFieldUtil.sprayMin -- alias
  
  -- sprayMax
  sprayFieldUtil.sprayMax = {}
  
  function sprayFieldUtil.sprayMax.set(config, field, value)
    local res = isInteger(value) and isInRange(value, config.sprayMin, nil, ">= sprayMin")
    if res then
      config.sprayMax = value
      print("Set spray max to: ", value)
    end
    return res
  end
  
  sprayFieldUtil.sprayMax.help = [[
    
      "sprayMax", alias: "max"
      This value sets the maximal deviation from the actual brush position for both axes.

          >= sprayMin               whole numbers equal to / bigger than the parameter "sprayMin"

      Default: ]] .. tostring(DefaultSpray.sprayMax)
  
  sprayFieldUtil.max = sprayFieldUtil.sprayMax -- alias
  
  -- keepOriginalCoord
  sprayFieldUtil.keepOriginalCoord = {}
  
  function sprayFieldUtil.keepOriginalCoord.set(config, field, value)
    local res = isBoolean(value)
    if res then
      config.keepOriginalCoord = value
      if value then
        print("Original coordinates are kept in the pipeline.")
      else
        print("Original coordinates are removed from the pipeline.")
      end
    end
    return res
  end
  
  sprayFieldUtil.keepOriginalCoord.help = [[
    
      "keepOriginalCoord", alias: "keep"
      This value defines how to handle the original coordinates.
      If they are kept, then they are not effected by deviation, but potentially intensity.

          false                     original coordinates are removed
          true                      original coordinates stay and may be effected by intensity

      Default: ]] .. tostring(DefaultSpray.keepOriginalCoord)
  
  sprayFieldUtil.keep = sprayFieldUtil.keepOriginalCoord -- alias
  
  -- sprayIntMode
  sprayFieldUtil.sprayIntMode = {}
  
  function sprayFieldUtil.sprayIntMode.set(config, field, value)
    local res = isString(value)
    if res then
      if value == "none" or value == "off" then
        config.keepOriginalCoord = false
        print("Original coordinates are not kept anymore.")
      elseif value == "deviated" or value == "original" or
          value == "both" or value == "together" or
          value == "separator" then
        config.sprayIntMode = value
        config.keepOriginalCoord = true
        print("Original coordinates are kept and intensity mode is set to: ", value)
      else
        res = false
        print("No valid intensity mode: ", value)
      end
    end
    return res
  end
  
  sprayFieldUtil.sprayIntMode.help = [[
    
      "sprayIntMode", alias: "mode"
      Defines how intensity effects the deviated original and deviated coordinates.
      Only relevant if "keepOriginalCoord" is true and active.
      Setting values other than "none" or "off" will also activate "keepOriginalCoord".

          "deviated"                effects the deviated coordinates; original are always applied
          "original"                effects the original coordinates; deviated are always applied
          "both"                    effects both coordinates independent from each other
          "together"                either both or no coordinates are applied
          "separator"               intensity applies to deviated coordinates; uses original
                                        if deviated is not used
          "none" / "off"            disables "keepOriginalCoord"

      Default: ]] .. tostring(DefaultSpray.sprayIntMode)
  
  sprayFieldUtil.mode = sprayFieldUtil.sprayIntMode -- alias
  
  -- coordOrder
  sprayFieldUtil.coordOrder = {}
  
  function sprayFieldUtil.coordOrder.set(config, field, value)
    local res = isString(value)
    if res then
      if value == "original" or value == "deviated" or
          value == "coordOriginal" or value == "coordDeviated" then
        config.coordOrder = value
        print("Set coordinate order to: ", value)
      else
        res = false
        print("No valid coordinate order: ", value)
      end
    end
    return res
  end
  
  sprayFieldUtil.coordOrder.help = [[
    
      "coordOrder", alias: "order"
      Defines how the coordinates are ordered in the pipeline after the spray is applied.
      Only relevant if "keepOriginalCoord" is true and active, since this value defines
      the order of the original and deviated coordinates.

          "original"                all original coordinates first
          "deviated"                all deviated coordinates first
          "coordOriginal"           if both coordinates are applied, apply the original first,
                                        then the deviated    
          "coordDeviated"           if both coordinates are applied, apply the deviated first,
                                        then the original

      Default: ]] .. tostring(DefaultSpray.coordOrder)
  
  sprayFieldUtil.order = sprayFieldUtil.coordOrder -- alias
  
  
  -- // mirror
  DefaultMirror._FieldUtil_ = {}
  local mirrorFieldUtil = DefaultMirror._FieldUtil_
  
  mirrorFieldUtil[DefaultMirror.__name] = {}
  mirrorFieldUtil[DefaultMirror.__name].help = [[
    
      ## Mirror Modification ##
      Actions are mirrored around one axis.
      
      Parameter                     Possible values
          active                        false, true
          mirrorMode / mode             "horizontal", "vertical", "diagonal_x", "diagonal_y", "point",
                                            "none", "off"
          coordOrder / order            "shape", "coord"]]
  
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
      The type of mirror to apply.
      Setting values other than "none" or "off" will also activate this feature.

          "horizontal"              mirror around the horizontal
          "vertical"                mirror around the vertical
          "diagonal_x"              mirror around the direction of the x-coordinates
          "diagonal_y"              mirror around the direction of the y-coordinates
          "point"                   mirror around the center of the map
          "none" / "off"            disables this mirror feature

      Default: ]] .. tostring(DefaultMirror.mirrorMode)
  
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
      Defines the order of coordinates after they are mirrored.

          "shape"                   received coordinates are mirrored as a whole and then attached to the list
          "coord"                   every single coordinate will be followed by its mirrored version

      Default: ]] .. tostring(DefaultMirror.coordOrder)
  
  mirrorFieldUtil.order = mirrorFieldUtil.coordOrder -- alias
  
  
  -- // shape
  DefaultShape._FieldUtil_ = {}
  local shapeFieldUtil = DefaultShape._FieldUtil_
  
  shapeFieldUtil[DefaultShape.__name] = {}
  shapeFieldUtil[DefaultShape.__name].help = [[
    
      ## Shape Modification ##
      This feature uses the received coordinates to generate a shape of coordinates.
      If it receives only one, it is remembered until it receives a second one to build a shape with.
      Should it receive more than one, it will try to generate as many shapes as it has coordinates for.
      WARNING: The remembered coordinate is only invalidated after use or after disabling this feature.
      
      Parameter                     Possible values
          active                        false, true
          shape                         "line", "rect", "rect45", "circle", "none", "off"
          removeRememberedCoords /      false, true
            remove
          connectShapes / connect       false, true]]
  
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
      The type of shape to apply.
      Setting values other than "none" or "off" will also activate this feature.
        
          "line"                    a simple line between two points
          "rect"                    rectangle seen from the front; coordinates define edges
          "rect45"                  rectangle along the diagonals; coordinates define edges
          "circle"                  a circle; first coordinate sets middle, second the radius
          "none" / "off"            disables this shape feature

      Default: ]] .. tostring(DefaultShape.shape)
  
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
      The shape feature stores a coordinate should it receive only one without having stored any.
      This value indicates whether this first coordinate is discarded or passed further.
 
          false                     keeps the coordinate in the pipeline
          true                      remembered coordinate is discarded

      Default: ]] .. tostring(DefaultShape.removeRememberedCoords)
   
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
      The shape modification may receive multiple coordinates and then tries to create multiple shapes.
      This value decides how the coordinates are used.
      
          false                     coordinates are only used once
          true                      coordinates are reused; for example, lines are connected

      Default: ]] .. tostring(DefaultShape.connectShapes)
   
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


mirror = ConfigConstructor.newMirrorConfig{ active = true }

-- @TheRedDaemon: Second mirror. Sends table with from default deviating value.
mirror2 = ConfigConstructor.newMirrorConfig()

spray = ConfigConstructor.newSprayConfig()

shape = ConfigConstructor.newShapeConfig()

shape2 = ConfigConstructor.newShapeConfig()


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