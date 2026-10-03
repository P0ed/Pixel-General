### Build

```
xcodebuild build -scheme PG -configuration Release -destination 'platform=macOS'
```

### Test

```
swift test --package-path COR
```

### Render units

Render every unit shape in both facings to a labeled PNG:
```sh
swift run --package-path GFX GFXUnitSheet /tmp/units.png && open /tmp/units.png
```
