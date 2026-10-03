# Panzer General inspired game engine

<img width="1172" height="668" src="https://github.com/user-attachments/assets/9d72f87c-3776-45bd-968d-2d9c5f236dd6" />

## Unit sprite sheet

Render every unit shape in both facings to a labeled PNG on macOS 27 with Swift 6.4:

```sh
swift run --package-path GFX GFXUnitSheet /tmp/units.png
```

The sheet uses the game's renderer, neutral backgrounds, and crisp integer scaling.
New unit shapes are included automatically. The output defaults to `units.png` in the
current directory; parent directories are created as needed.

```sh
swift run --package-path GFX GFXUnitSheet /tmp/units.png --scale 3 --columns 4
swift run --package-path GFX GFXUnitSheet --help
```

`--scale` defaults to 4 and `--columns` to 4 unit pairs per row. Both accept values from 1 to 8.

## Docs

- [Architecture](./Docs/Architecture.md)
- [Mechanics](./Docs/Mechanics.md)
- [AI](./Docs/AI.md)
