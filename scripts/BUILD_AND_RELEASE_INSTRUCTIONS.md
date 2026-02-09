# Claude Code: Build, Package, and Release ProseKit v0.1.0

## Overview

Build ProseKit into a distributable DMG, create a GitHub release, and set up
a Homebrew Cask formula. Execute each section in order.

## Step 1: Verify the Project Builds

```bash
cd ~/Projects/GrammarlyReplacement

# Clean build to make sure everything compiles
xcodebuild clean build \
    -project ProseKit/ProseKit.xcodeproj \
    -scheme ProseKit \
    -configuration Release \
    -destination "generic/platform=macOS" \
    2>&1 | tail -20
```

If the build fails, fix any errors before proceeding.

## Step 2: Build the DMG

```bash
cd ~/Projects/GrammarlyReplacement

# Unsigned build (no Apple Developer account needed)
./scripts/build_dmg.sh --version 0.1.0
```

This will:
1. Build a Release archive via xcodebuild
2. Export the .app bundle
3. Package it into `build/ProseKit-v0.1.0.dmg` with an Applications symlink

**If you have an Apple Developer certificate:**
```bash
# Find your signing identity
security find-identity -v -p codesigning

# Signed build
./scripts/build_dmg.sh --version 0.1.0 --sign "Developer ID Application: Mohammad Abdurraafay (TEAMID)"

# Signed + notarized
./scripts/build_dmg.sh --version 0.1.0 \
    --sign "Developer ID Application: Mohammad Abdurraafay (TEAMID)" \
    --notarize "TEAMID"
```

The script will print the SHA256 hash of the DMG — save this for the Homebrew
Cask formula.

## Step 3: Test the DMG

Before releasing, verify the DMG works:

```bash
# Mount and inspect
hdiutil attach build/ProseKit-v0.1.0.dmg

# Check the app exists and has correct structure
ls -la /Volumes/ProseKit/ProseKit.app/Contents/
cat /Volumes/ProseKit/ProseKit.app/Contents/Info.plist | head -30

# Check the Applications symlink exists
ls -la /Volumes/ProseKit/Applications

# Unmount
hdiutil detach /Volumes/ProseKit
```

Optionally, copy ProseKit.app to /Applications and launch it to verify it
runs correctly (model download, menu bar icon, hotkey).

## Step 4: Create GitHub Repository

If the repo doesn't exist yet on GitHub:

```bash
cd ~/Projects/GrammarlyReplacement

# Initialize git if needed
git init

# Add remote
git remote add origin https://github.com/iamraafay/ProseKit.git

# Commit everything
git add -A
git commit -m "ProseKit v0.1.0 — local Grammarly replacement for macOS

Initial release: menu bar app with four rewrite modes (Grammar, Concise,
Casual, Professional) powered by Qwen3-8B running locally via Apple MLX.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

# Push
git push -u origin main
```

## Step 5: Create GitHub Release

```bash
cd ~/Projects/GrammarlyReplacement

# Create a git tag
git tag -a v0.1.0 -m "ProseKit v0.1.0 — Initial Release"
git push origin v0.1.0

# Create GitHub release with the DMG attached
gh release create v0.1.0 \
    build/ProseKit-v0.1.0.dmg \
    --title "ProseKit v0.1.0" \
    --notes "$(cat <<'EOF'
## ProseKit v0.1.0 — Initial Release

A free, open-source macOS menu bar app that rewrites text in place using a local LLM. No cloud, no accounts, no telemetry.

### Features

- **Four rewrite modes:** Grammar Only, Concise, Casual, Professional
- **Works in any app:** Slack, Mail, Chrome, iMessage, Safari, and more
- **Fully local:** Qwen3-8B-4bit runs on your Mac's GPU via Apple MLX
- **Global hotkey:** Press ⌘⇧G from anywhere to rewrite
- **Undo:** Press ⌘⇧Z to restore original text

### Requirements

- macOS 14+ (Sonoma)
- Apple Silicon (M1 or later)
- 8 GB unified memory
- ~4.3 GB disk (model downloaded on first launch)

### Install

1. Download `ProseKit-v0.1.0.dmg` below
2. Open the DMG, drag ProseKit to Applications
3. Launch ProseKit — grant Accessibility permission when prompted
4. Wait for the model to download (~4.3 GB, one-time)
5. Type anywhere, press ⌘⇧G

> **Note:** This build is unsigned. On first launch, right-click ProseKit.app → Open to bypass Gatekeeper.

### Or install via Homebrew

```
brew tap iamraafay/prosekit
brew install --cask prosekit
```
EOF
)"
```

## Step 6: Set Up Homebrew Tap

Create a separate repo for the Homebrew tap:

```bash
# Create the tap repo
gh repo create iamraafay/homebrew-prosekit --public --description "Homebrew Cask for ProseKit"

# Clone it
cd /tmp
git clone https://github.com/iamraafay/homebrew-prosekit.git
cd homebrew-prosekit

mkdir -p Casks
```

Get the SHA256 from the build output, or compute it:
```bash
shasum -a 256 ~/Projects/GrammarlyReplacement/build/ProseKit-v0.1.0.dmg
```

Create the Cask formula (replace SHA256_HASH with the actual hash):

```bash
cat > Casks/prosekit.rb << 'RUBY'
cask "prosekit" do
  version "0.1.0"
  sha256 "SHA256_HASH"

  url "https://github.com/iamraafay/ProseKit/releases/download/v#{version}/ProseKit-v#{version}.dmg"
  name "ProseKit"
  desc "Local-first text rewriter for macOS — free Grammarly alternative"
  homepage "https://github.com/iamraafay/ProseKit"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "ProseKit.app"

  postflight do
    system "open", "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  end

  zap trash: [
    "~/Library/Application Support/ProseKit",
    "~/Library/Preferences/com.abdurraafay.prosekit.plist",
    "~/Library/Caches/com.abdurraafay.prosekit",
  ]

  caveats <<~EOS
    ProseKit requires Accessibility permission to read and write text fields.
    System Settings will open after installation — add ProseKit to the list.

    On first launch, ProseKit downloads Qwen3-8B-4bit (~4.3 GB) from HuggingFace.
    This is a one-time download.

    Usage: Press ⌘⇧G in any app to rewrite the focused text field.
  EOS
end
RUBY
```

**IMPORTANT:** Replace `SHA256_HASH` in the file with the actual SHA256 hash
from Step 2.

Then commit and push:

```bash
cd /tmp/homebrew-prosekit
git add -A
git commit -m "Add ProseKit v0.1.0 Cask"
git push origin main
```

Users can then install with:
```bash
brew tap iamraafay/prosekit
brew install --cask prosekit
```

## Step 7: Verify Installation

Test both installation methods:

```bash
# Method 1: DMG
open ~/Projects/GrammarlyReplacement/build/ProseKit-v0.1.0.dmg
# Drag to Applications, launch, verify menu bar icon appears

# Method 2: Homebrew (after Step 6)
brew tap iamraafay/prosekit
brew install --cask prosekit
# Launch from Applications, verify menu bar icon appears
```

## Checklist

- [ ] Release build compiles without errors
- [ ] DMG contains ProseKit.app + Applications symlink
- [ ] App launches from DMG and shows menu bar icon
- [ ] Model downloads successfully on first launch
- [ ] ⌘⇧G hotkey works from another app
- [ ] GitHub release created with DMG attached
- [ ] Homebrew tap repo created with Cask formula
- [ ] `brew install --cask prosekit` works
