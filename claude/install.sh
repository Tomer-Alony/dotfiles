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

# Set up global CLAUDE.md
echo "› Setting up global CLAUDE.md"
CLAUDE_MD_SOURCE="$SCRIPT_DIR/CLAUDE.md"
CLAUDE_MD_TARGET="$HOME/.claude/CLAUDE.md"

if [ -f "$CLAUDE_MD_SOURCE" ]; then
    if [ -L "$CLAUDE_MD_TARGET" ]; then
        current_target=$(readlink "$CLAUDE_MD_TARGET")
        if [ "$current_target" = "$CLAUDE_MD_SOURCE" ]; then
            echo "  ✓ Global CLAUDE.md already linked"
        else
            rm "$CLAUDE_MD_TARGET"
            ln -s "$CLAUDE_MD_SOURCE" "$CLAUDE_MD_TARGET"
            echo "  ✅ Global CLAUDE.md symlink updated"
        fi
    elif [ -f "$CLAUDE_MD_TARGET" ]; then
        mv "$CLAUDE_MD_TARGET" "$CLAUDE_MD_TARGET.backup.$(date +%Y%m%d%H%M%S)"
        ln -s "$CLAUDE_MD_SOURCE" "$CLAUDE_MD_TARGET"
        echo "  ✅ Global CLAUDE.md linked (backup created)"
    else
        ln -s "$CLAUDE_MD_SOURCE" "$CLAUDE_MD_TARGET"
        echo "  ✅ Global CLAUDE.md linked"
    fi
else
    echo "  ⚠️  No CLAUDE.md found in dotfiles"
fi

# Set up commands directory symlinks
echo "› Setting up Claude Code commands"
COMMANDS_SOURCE="$SCRIPT_DIR/commands"
COMMANDS_TARGET="$HOME/.claude/commands"

mkdir -p "$COMMANDS_TARGET"

for cmd in "$COMMANDS_SOURCE"/*.md; do
    if [ -f "$cmd" ]; then
        cmd_name=$(basename "$cmd")
        target_link="$COMMANDS_TARGET/$cmd_name"
        if [ -L "$target_link" ]; then
            current=$(readlink "$target_link")
            if [ "$current" != "$cmd" ]; then
                rm "$target_link"
                ln -s "$cmd" "$target_link"
            fi
        else
            ln -sf "$cmd" "$target_link"
        fi
    fi
done
echo "  ✅ Commands linked"

# List available skills
echo "› Available skills:"
for skill in "$SKILLS_SOURCE"/*.md; do
    if [ -f "$skill" ]; then
        skill_name=$(basename "$skill" .md)
        echo "  - /$skill_name"
    fi
done

# List available commands
echo "› Available commands:"
for cmd in "$COMMANDS_SOURCE"/*.md; do
    if [ -f "$cmd" ]; then
        cmd_name=$(basename "$cmd" .md)
        echo "  - /$cmd_name"
    fi
done