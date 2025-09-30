# BeamNG.drive World Editor Community Toolpack

A collection of extensions for the BeamNG.drive World Editor, designed to streamline and enhance map editing workflows. This toolpack aims to provide map creators with powerful utilities for road generation, conversion, and terrain painting.

The extensions contained in this toolpack were first written by Stuffi3000.

# Included Extensions

The extensions below are presented in order of publication, for the oldest to the newest.

## Mesh - Decal Road Convert

The Mesh - Decal Road Convert extension can be used for the following purposes:
- Seamlessly convert between MeshRoad and DecalRoad objects.
- Preserve properties such as name, position, rotation, scale, and optionally materials and advanced fields.
- Batch conversion and optional deletion of old roads, with collision rebuilding support.

Check this forum post for more information: https://www.beamng.com/threads/release-world-editor-extension-mesh-decal-road-convert.92927/

### Changelog

* 1.0: Initial release
* 1.1: Added possibility for converting multiple roads at once (select all in the editor, click the select button in the window and convert)

## Road-edge Generator

The Road-edge Generator extension does as it same says:
- Automatically generates road-edge DecalRoads alongside existing roads.
- Supports customizable profiles, edge width, material, fade, randomization, and side selection.
- Profile management for quick parameter switching and reuse.

Check this forum post for more information: https://www.beamng.com/threads/release-world-editor-extension-road-edge-generator.98175/

### Changelog


* 1.0: Initial release
* 1.1: Small update:
  - Added start fade and end fade parameters
  - Added option to randomise node placement
  - Clarified tooltips and interface
  - Road-edge width can now be a decimal value
* 1.2: Small update:
  - Added option to specify texture length
  - Fixed startFade & endFade numbers being merged together for only the startFade property for number higher than 1.0
* 1.3: Small update:
  - Added "overObjects" option
* 1.4: QoL update:
  - Added loading and saving of profiles
  - Profiles are saved in your userfolder/settings
* 1.5: Bugfix update:
  - Fixed saved profiles not loading properly

## Road Terrain/Material Painter

The Road Material Painter extension has these functions:
- Paint terrain materials underneath selected DecalRoads for seamless road–terrain integration.
- Supports margin adjustment, material selection, and batch painting.
- Includes terraforming features to blend terrain with road geometry.

Check this forum post for more information: https://www.beamng.com/threads/release-world-editor-extension-road-terrain-material-painter.106566/

### Changelog

* 1.0: Initial release
* 1.1: Added terraforming

# Installation

To install these extensions, follow these steps:
1. Download the repository as a .zip file
2.1. Open up the file and place it's content into your userfolder.
2.2. Alternatively, open up the file and place its content into your BeamNG.drive root directory (can be easily found by right-clicking on BeamNG Drive in Steam -> Manage -> Browse local files): Place the lua folder where the lua folder is.
2.3. Alternatively, navigate through all folders in the .zip attached and place the .lua files in BeamNG.drive\lua\ge\extensions\editor.

Once done, all extensions should automatically show up in your editor under Window -> <Name of the extension\>.

If it doesn't show up:
- Make sure you placed the .lua files in the right directory and no other software is blocking its execution
- In your editor, go to Window -> Extensions Editor and check whenever the extensions are enabled
- Restart BeamNG drive
- As a last resort: post an issue here.

If you run into any problems, you can check one of the forum posts for more information and guidance.

# Contribution

Contributions are very much welcome! These can be expansions of the existing tools or new useful tools to add to the toolpack. 

I do nevertheless reserve myself the right to accept or deny the addition of new tools or the modification of existing extensions.

# Licence

All tools are licensed under the bCDDL v1.1.
