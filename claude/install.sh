#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "› Setting up Claude Code"

# Install Claude Code if not present
if command -v claude &> /dev/null; then
    echo "  ✓ Claude Code is already installed"
    claude --version
else
    # Check if npm is available
    if ! command -v npm &> /dev/null; then
        echo "  ❌ npm is not installed. Please install Node.js first."
        exit 1
    fi

    # Install Claude Code using npm
    echo "  Installing Claude Code via npm..."
    npm install -g @anthropic-ai/claude-code

    # Verify installation
    if command -v claude &> /dev/null; then
        echo "  ✅ Claude Code installed successfully"
        claude --version
    else
        echo "  ❌ Claude Code installation failed"
        exit 1
    fi

    echo "  💡 Run 'claude auth login' to authenticate with your Anthropic account"
fi

# Set up skills directory symlink
echo "› Setting up Claude Code skills"
SKILLS_SOURCE="$SCRIPT_DIR/skills"
SKILLS_TARGET="$HOME/.claude/skills"

# Create ~/.claude if it doesn't exist
mkdir -p "$HOME/.claude"

if [ -L "$SKILLS_TARGET" ]; then
    # Already a symlink - check if pointing to correct location
    current_target=$(readlink "$SKILLS_TARGET")
    if [ "$current_target" = "$SKILLS_SOURCE" ]; then
        echo "  ✓ Skills directory already linked"
    else
        echo "  Updating skills symlink..."
        rm "$SKILLS_TARGET"
        ln -s "$SKILLS_SOURCE" "$SKILLS_TARGET"
        echo "  ✅ Skills symlink updated"
    fi
elif [ -d "$SKILLS_TARGET" ]; then
    # Existing directory - back it up and replace with symlink
    echo "  Backing up existing skills directory..."
    mv "$SKILLS_TARGET" "$SKILLS_TARGET.backup.$(date +%Y%m%d%H%M%S)"
    ln -s "$SKILLS_SOURCE" "$SKILLS_TARGET"
    echo "  ✅ Skills directory linked (backup created)"
else
    # No existing directory - create symlink
    ln -s "$SKILLS_SOURCE" "$SKILLS_TARGET"
    echo "  ✅ Skills directory linked"
fi

# List available skills
echo "› Available skills:"
for skill in "$SKILLS_SOURCE"/*.md; do
    if [ -f "$skill" ]; then
        skill_name=$(basename "$skill" .md)
        echo "  - /$skill_name"
    fi
done