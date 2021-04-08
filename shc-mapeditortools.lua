MIRROR_MODE = "point"
MIRROR_MODE2 = "off"

-- brush config
BRUSH = "normal"
BRUSH_SPRAY_EXP = 3 -- defines how centered the random positions should be (higher -> more centered, should be bigger than 1)
BRUSH_SPRAY_SIZE = 8 -- TEMP? Would need reliable way to get the set brush size, regardless of the action
BRUSH_SPRAY_INT = 0.25 -- intensity -> 0 to 1, if random number bigger, skips the draw call


-- helper 

-- source: https://scriptinghelpers.org/questions/4850/how-do-i-round-numbers-in-lua-answered
function round(x)
  return x + 0.5 - (x + 0.5) % 1
end

-- generates a random deviation for the spray brush using the size
function randomSprayDeviation(size)
  local rand = round((math.random()^BRUSH_SPRAY_EXP) * size)
  rand = math.random() < 0.5 and -rand or rand -- plus or minus
  return rand
end

-- helper end


function applyMirrors(x, y, size)
  coordlist = {}
  
  -- apply spray brush, position does not feel really right in applyMirrors, though
  if BRUSH == "spray" then
  
    -- return empty coordlist to skip drawing
    if math.random() > BRUSH_SPRAY_INT then
      return coordlist
    end
  
    x = x + randomSprayDeviation(BRUSH_SPRAY_SIZE)
    y = y + randomSprayDeviation(BRUSH_SPRAY_SIZE)
  end
  
  table.insert(coordlist, {x,y})
  
  if MIRROR_MODE ~= "off" then
    table.insert(coordlist, applyMirror(x, y, size, MIRROR_MODE))
    if MIRROR_MODE2 ~= "off" then
      table.insert(coordlist, applyMirror(x, y, size, MIRROR_MODE2))
      table.insert(coordlist, applyMirror(coordlist[2][1], coordlist[2][2], size, MIRROR_MODE2))
    end
  end
  return coordlist
end

function applyMirror(x, y, size, mirrorMode)
  newx = x
  newy = y
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
  coordinatelist = applyMirrors(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, brush)
  end
  
  return coordinatelist
end

function transformTerrain(x, y, brush, change)
  coordinatelist = applyMirrors(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, brush)
    table.insert(coordpair, change)
  end
  
  return coordinatelist
end

function setTerrainType(x, y, brush, terrainType, unknown)
  coordinatelist = applyMirrors(x, y, 1)  
  
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
    coordinatelist = applyMirrors(x, y, math.floor(rockType/4)+1)  
  else
    coordinatelist = applyMirrors(x, y, 1)  
  end
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, objectType)
    table.insert(coordpair, rockType)
  end
  
  return coordinatelist  
end
