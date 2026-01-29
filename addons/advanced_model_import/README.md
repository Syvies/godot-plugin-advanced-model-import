<h1 align="center">
  <br>
  <a href="https://github.com/Syvies/godot-plugin-advanced-model-import"><img src="https://raw.githubusercontent.com/Syvies/godot-plugin-advanced-model-import/main/icon.svg" alt="Advanced Model Import icon" width="256"></a>
  <br>Advanced Model Import<br>
</h1>

<h4 align="center">A Godot 4.6+ plugin adding some bulk model import options.</h4>

<p align="center">
  <a href="https://skillicons.dev">
    <img src="https://skillicons.dev/icons?i=godot" />
  </a>
</p>

<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#how-to-use">How To Use</a> •
  <a href="#install">Install</a> •
  <a href="#download">Download</a> •
  <a href="#credits">Credits</a> •
  <a href="#license">License</a>
</p>

## Key Features

- Extract all meshes from multiple models.
- Extract all materials from multiple models.
- Set external materials for multiple models.
- See the affected model's paths depending on your selection in the FileSystem Dock.

## How To Use

<p align="center">
  <a href="https://github.com/Syvies/godot-plugin-advanced-model-import">
    <img src="https://raw.githubusercontent.com/Syvies/godot-plugin-advanced-model-import/main/images/dock.png" alt="Screen capture of the plugin's dock" width="256"/>
  </a>
</p>

### Extract Meshes

When selecting the option to extract meshes from models, you'll have access to additional options:

| Option | Description |
| :----: | ----------- |
| `Meshes Name` | Decide on whether to use the name of the original mesh or the name of the MeshInstance3D node for the extracted meshes. |
| `Mirror Directory Structure` | If you have subfolders in your selection, the extraction paths will try to mirror the directory structure in the destination folder. |
| `Meshes Extract Path` | The path to the destination folder for the extracted meshes. |

> [!WARNING]
> The path to the destination folder is mandatory when this option is selected.

### Extract Materials

When selecting the option to extract materials from models, you just need to provide the path to the destination folder in `Materials Extract Path` field.

> [!WARNING]
> The path to the destination folder is mandatory when this option is selected.

### Replace Materials

When selecting the option to extract materials from models, you'll need to provide two informations per material:
- The material name in the meshes.
- The path to the replacing material Resource.

> [!TIP]
> Some asset packs may have models with similar materials with different names, you can add the same material path for multiple material names.

> [!WARNING]
> The material Resource path is mandatory for each material name entry.

## Install

You can install it via the Asset Library or import the content of the downloaded .zip in your Godot project.

Make sure that the path to the plugin is `res://addons/advanced_model_import/plugin.cfg`.

## Download

- ~~[Asset Library](https://godotengine.org/asset-library/)~~
- ~~[Godot Asset Store](https://store-beta.godotengine.org/)~~
- [Direct download](https://github.com/Syvies/godot-plugin-advanced-model-import/releases/latest)

## Credits

- Code: [Syvies](https://github.com/Syvies) (me)
- Icon: [Game-icons.net](https://game-icons.net/)

> [!NOTE]
> Inspired by [dragon1freak](https://github.com/dragon1freak)'s [Bulk Model Manager](https://github.com/dragon1freak/godot-bulk-model-manager).

## License

[MIT](https://github.com/Syvies/godot-plugin-advanced-model-import/blob/main/LICENSE)
