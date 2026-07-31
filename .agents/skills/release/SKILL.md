---
name: release
description: Build, tag and publish a Pixel General release on GitHub.
disable-model-invocation: true
---

# Release

Argument: the version, e.g. `0.9` (a leading `v` is accepted and stripped). Tag is `v<version>`.
An optional second argument is the release title; it defaults to the tag.

Releases are published with the `gh` CLI. Immutable releases are enabled on the repo, so
assets must be uploaded **before** publishing: create a draft with the asset attached, then
publish it. A published release can no longer be edited.

Shell state does not persist between commands: re-derive `TAG` and `DIR` in every call that
needs them (each snippet below does).

```sh
TAG="v${1#v}"; DIR="tmp/release/$TAG"
```

## 1. Preflight

`${1#v}` must match `^[0-9]+(\.[0-9]+)*(-[A-Za-z0-9.]+)?$`. Then:

```sh
gh auth status                    # must be logged in to github.com
git status --porcelain            # must be empty
git rev-parse --abbrev-ref HEAD   # must be main
git fetch origin --tags
git rev-list --count HEAD..origin/main   # must be 0 — push or rebase first
git tag -l "$TAG"; git ls-remote --tags origin "$TAG"   # both must be empty
```

Stop and ask the user if any check fails. A tag that already exists means that release was
likely already published — do not force it.

## 2. Bump version

```sh
VERSION="${1#v}"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" PG/Info.plist
```

If it already matches `VERSION`, skip to step 3. Otherwise set it and commit directly to main
(the build in step 3 must embed this version):

```sh
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" PG/Info.plist
git add PG/Info.plist
git commit -m "Bump version to $VERSION"
git push origin main
```

## 3. Build and zip

```sh
TAG="v${1#v}"; DIR="tmp/release/$TAG"; mkdir -p "$DIR"
xcodebuild build -scheme PG -configuration Release -destination 'platform=macOS' \
  -derivedDataPath "$DIR/dd" 2>&1 | tail -30
APP=$(ls -d "$DIR"/dd/Build/Products/Release*/PG.app | head -1)   # Catalyst: Release-maccatalyst
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIR/PG.zip"
unzip -l "$DIR/PG.zip" | grep -q 'PG.app/Contents/MacOS/PG' && ls -lh "$DIR/PG.zip"
```

`tmp/` is gitignored. Build failures are fatal — fix or report, never ship a stale binary.

## 4. Changelog

```sh
git log --no-merges --pretty=format:'- %s' "$(git describe --tags --abbrev=0)..HEAD"
```

Condense into a short bullet list of user-visible changes in the repo's style (see previous
releases: a handful of terse bullets, no headings, no commit hashes). Drop pure-noise commits
("Cleanup", "Simplify", doc tweaks, "Bump version to ..."). Write the result to `$DIR/notes.md`.

Show the user the tag, title and changelog, and get an explicit OK before step 5 — pushing the
tag and publishing an immutable release cannot be undone.

## 5. Tag and push

```sh
TAG="v${1#v}"
git tag "$TAG" && git push origin "$TAG"
```

## 6. Publish

Create the draft, upload the asset, then publish. Releases here are marked `prerelease: true`,
matching every previous one.

```sh
TAG="v${1#v}"; DIR="tmp/release/$TAG"; NAME="${2:-$TAG}"

gh release create "$TAG" "$DIR/PG.zip" --draft --prerelease \
  --title "$NAME" --notes-file "$DIR/notes.md"
gh release view "$TAG" --json assets \
  --jq '.assets[] | "\(.name) \(.size) \(.state)"'   # PG.zip must be listed as uploaded

gh release edit "$TAG" --draft=false
gh release view "$TAG" --json url,isDraft,isImmutable
```

If any `gh` step fails, stop and report it — a leftover draft can be deleted with
`gh release delete "$TAG" --yes`, and the tag with `git push origin :refs/tags/$TAG`.

Confirm to the user with the release URL and `"isImmutable": true`.
