# Global Claude Code Instructions

These instructions apply to all projects and sessions.

## Branch & PR Naming Convention

When creating branches and PRs for any task:

1. **Branch naming**: Always use ticket number as prefix
   - Format: `{TICKET-NUMBER}-{brief-description}`
   - Example: `SP-65420-fix-version-bump-flakiness`

2. **PR title**: Always prefix with ticket number in brackets
   - Format: `[{TICKET-NUMBER}] {Description}`
   - Example: `[SP-65420] Fix intermittent version bump failures`

3. **Commit messages**: Include ticket number
   - Format: `[{TICKET-NUMBER}] {message}`

### Extracting Ticket Numbers

When the user provides a Jira URL or mentions a ticket:
- Extract from URL: `selectedIssue=SP-12345` or `/browse/SP-12345`
- Direct mention: `SP-12345`
- If no ticket is mentioned, ask for one before creating branches/PRs

## Dotfiles Synchronization

The user's dotfiles are located at: `/Users/tomeralony/go/src/github.com/dotfiles`

When creating new Claude skills or commands:
1. Create the file in the dotfiles repo: `/Users/tomeralony/go/src/github.com/dotfiles/claude/commands/`
2. Create a symlink in `~/.claude/commands/` pointing to the dotfiles version
3. Commit the changes to the dotfiles repo

This ensures all custom commands are version-controlled and synced across machines.

## Skill/Command Creation

When the user asks to create a new skill or command:
1. Create the `.md` file in `/Users/tomeralony/go/src/github.com/dotfiles/claude/commands/`
2. Create symlink: `ln -sf {dotfiles-path} ~/.claude/commands/{name}.md`
3. Offer to commit to dotfiles repo

## Jira Integration

The Jira instance is: `stackpulse.atlassian.net`
Project key: `SP`

### How to interact with Jira

**ALWAYS use the `jira` CLI tool and the Jira REST API** (documented in the `/jira` skill).
- Use `jira` CLI for creating/viewing/editing issues, sprints, and boards
- Use the REST API (via `curl -s -u "tomera@torq.io:$JIRA_API_TOKEN"`) for setting custom fields that the CLI can't handle reliably
- The Atlassian MCP plugin may also be available for read operations (search, fetch), but **prefer the CLI for all create/edit operations**
- **DO NOT** use WebFetch for Jira/Confluence URLs
- **DO NOT** delegate Jira operations to subagents (Task tool) - always use the CLI directly in the main context
