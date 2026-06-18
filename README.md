# Panzer General inspired game engine

<img width="1172" height="668" src="https://github.com/user-attachments/assets/9d72f87c-3776-45bd-968d-2d9c5f236dd6" />

## Build & Test

```bash
# Build
xcodebuild -scheme PG -configuration Release -destination 'platform=macOS,variant=Mac Catalyst' build

# Run tests
xcodebuild -scheme PG test -destination 'platform=macOS,variant=Mac Catalyst'
```

## Docs
- [Architecture](./docs/Architecture.md)
- [Mechanics](./docs/GameMechanics.md)
- [Roadmap](./docs/Roadmap.md)
