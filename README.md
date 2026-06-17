# Panzer General inspired game engine

<img width="1172" height="668" src="https://github.com/user-attachments/assets/9d72f87c-3776-45bd-968d-2d9c5f236dd6" />

PG is a single UIKit codebase that runs on iOS/iPadOS and on macOS via Mac
Catalyst.

## Build & Test

```bash
# Build for macOS (Mac Catalyst)
xcodebuild -scheme PG -configuration Release -destination 'platform=macOS,variant=Mac Catalyst' build

# Build for iOS
xcodebuild -scheme PG -configuration Release -destination 'generic/platform=iOS' build

# Run tests (any iOS Simulator)
xcodebuild -scheme PG test -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Docs
- [Architecture](./docs/Architecture.md)
- [Mechanics](./docs/GameMechanics.md)
- [Roadmap](./docs/Roadmap.md)
