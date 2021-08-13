# stronghold-mapeditortools
Map Editor Tool Set for Stronghold (in the future) and Stronghold Crusader

## Features
Make your custom maps symmetrical by mirroring every action in the map editor.  
Or use brush-modifiers to either deviate the position of the current selected action in spray-like manner or apply multiple types of shapes.

## Installation instructions
1. Download the files from this repository for your version of Stronghold (currently only Stronghold Crusader 1.41 is supported)
2. Rename the existing `binkw32.dll` in your game folder to `binkw32_real.dll`
3. Move the files from the zip file (`binkw32.dll, lua54.dll, shc-mapeditortools.lua`) to your game folder

## Usage instructions
When starting up the game, you will get your normal game window, and an extra console window. You can run LUA code in this console window. Type `help` to see the instructions for changing the active mirror mode and more.

## Modification instructions
To modify the way mirroring is done or other drawing behaviors, modify the `shc-mapeditortools.lua` file.

## Copyright
The custom binkw32.dll of this project does not have a license. I am the copyright holder. You are free to use it, but not allowed to distribute it or modify it.
```
Copyright Edward Gynt - All Rights Reserved
Written by Edward Gynt <gynt@users.noreply.github.com>, March 2021
```
