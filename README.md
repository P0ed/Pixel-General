# Panzer General inspired game engine

<img width="1172" height="668" src="https://github.com/user-attachments/assets/9d72f87c-3776-45bd-968d-2d9c5f236dd6" />

## Build & Test

```bash
# Build
xcodebuild build -scheme PG -configuration Release -destination 'platform=macOS,variant=Mac Catalyst'

# Run the COR package tests
swift test --package-path COR
```

## Docs
- [Architecture](./Docs/Architecture.md)
- [Mechanics](./Docs/Mechanics.md)
- [AI](./Docs/AI.md)
- [Roadmap](./Docs/Roadmap.md)
