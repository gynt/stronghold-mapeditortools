
MIRROR_MODE = "point"

function applyMirror(x, y, size)
  newx = x
  newy = y
  if MIRROR_MODE == "point" then
    newx = 399 - x
    newy = 399 - y
  elseif MIRROR_MODE == "horizontal" then
    newx = 399 - y
    newy = 399 - x
  elseif MIRROR_MODE == "vertical" then
    newx = y
    newy = x
  elseif MIRROR_MODE == "diagonal_x" then
    newx = x
    newy = 399 - y
  elseif MIRROR_MODE == "diagonal_y" then
    newx = 399 - x
    newy = y
  else
    print("Don't know this MIRROR_MODE: " .. MIRROR_MODE)
  end
  
  if MIRROR_MODE == "horizontal" or "diagonal_x" or "diagonal_y" then
    newx = newx - (size - 1)
    newy = newy - (size - 1)
  end
  return newx, newy
end

function erase(x, y, brush)
  newx, newy = applyMirror(x, y, 1)
  return {{x, y, brush},
          {newx, newy, brush}}
end

function setTerrainTypeEarth(x, y, brush)
  newx, newy = applyMirror(x, y, 1)
  return {{x, y, brush},
          {newx, newy, brush}}
end

 -- change is actually a signed byte, it can be -1 for example to decrease terrain height
function changeTerrainHeight(x, y, brush, change)
  newx, newy = applyMirror(x, y, 1)
  return {{x, y, brush, change},
          {newx, newy, brush, change}}
end

function setTerrainType(x, y, brush, terrainType, unknown)
  newx, newy = applyMirror(x, y, 1)
  return {{x, y, brush, terrainType, unknown},
          {newx, newy, brush, terrainType, unknown}}
end

function levelTerrain(x, y, brush, unknown)
  newx, newy = applyMirror(x, y, 1)
  return {{x, y, brush, unknown},
          {newx, newy, brush, unknown}}
end

function minHeightTerrain(x, y, brush, unknown)
  newx, newy = applyMirror(x, y, 1)
  return {{x, y, brush, unknown},
          {newx, newy, brush, unknown}}
end

function createPlateau(x, y, brush, intensity)
  newx, newy = applyMirror(x, y, 1)
  return {{x, y, brush, intensity},
          {newx, newy, brush, intensity}}
end

 -- objectType == 20 means the object is a rock and math.floor(rockType / 4) + 1 will indicate the rock size
function placeTreeOrRock(x, y, objectType, rockType)
  print(rockType)
  if objectType == 20 then
    newx, newy = applyMirror(x, y, math.floor(rockType / 4) + 1)
    return {{x, y, objectType, rockType},
            {newx, newy, objectType, rockType}}  
  else
    newx, newy = applyMirror(x, y, 1)
    return {{x, y, objectType, rockType},
            {newx, newy, objectType, rockType}}  
  end
end

function createHill(x, y, intensity)
  newx, newy = applyMirror(x, y, 1)
  return {{x, y, intensity},
          {newx, newy, intensity}}
end

function placeAnimal(x, y, animalType)
  newx, newy = applyMirror(x, y, 1)
  return {{x, y, animalType},
          {newx, newy, animalType}}
end