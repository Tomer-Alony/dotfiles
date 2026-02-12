# Jira CLI Skill

Use the `jira` CLI tool to interact with Jira. The CLI is pre-configured for the SP project.

## Prerequisites

The JIRA_API_TOKEN environment variable must be set. It's configured in ~/.zshrc.

## Common Commands

### View Issue
```bash
jira issue view SP-12345
```

### Create Issue
```bash
jira issue create -t"Task" -s"Summary" -b"Description" -a"email@torq.io" --no-input
```

Issue types: `Task`, `Bug`, `Internal Bug`, `Story`, `Epic`, `Tech Debt`, `Sub-task`

### List Issues
```bash
# My open issues
jira issue list -a"tomera@torq.io" --status "~Done"

# Issues in current sprint
jira sprint list --current
```

### Move Issue
```bash
jira issue move SP-12345 "In Progress"
```

### Assign Issue
```bash
jira issue assign SP-12345 "email@torq.io"
```

### Add Comment
```bash
jira issue comment add SP-12345 "Comment text"
```

### Search with JQL
```bash
jira issue list --jql "project = SP AND status = 'In Progress' AND assignee = currentUser()"
```

## Project Info
- **Instance**: stackpulse.atlassian.net
- **Project**: SP
- **Board**: Platform Board

## Boards and Sprints

### List All Boards
```bash
jira board list
```

Key boards:
| Board ID | Name | Type |
|----------|------|------|
| 701 | Infra | scrum |
| 50 | Platform Board | scrum |
| 338 | Automation Team | scrum |
| 76 | DevOps Team | scrum |
| 105 | Runtime | scrum |

### Get Sprint IDs from Board

Use the REST API to get sprint IDs by state (active, future, closed):

```bash
# Get future sprints from Infra board (701)
curl -s -u "tomera@torq.io:$JIRA_API_TOKEN" \
  "https://stackpulse.atlassian.net/rest/agile/1.0/board/701/sprint?state=future"

# Get active sprints
curl -s -u "tomera@torq.io:$JIRA_API_TOKEN" \
  "https://stackpulse.atlassian.net/rest/agile/1.0/board/701/sprint?state=active"
```

Response includes sprint ID, name, and dates:
```json
{"values":[{"id":11169,"name":"Infra -  Sprint 156 [Future]","state":"future",...}]}
```

### Add Issues to Sprint

Once you have the sprint ID, use:
```bash
jira sprint add <SPRINT_ID> SP-12345 SP-12346
```

Example:
```bash
jira sprint add 11169 SP-66640
```

## Custom Fields

All custom fields show a warning about "invalid custom fields" but they still work. Verify with JQL after setting.

### Set Group (works via CLI)
```bash
jira issue edit SP-12345 --custom "Group=Infra" --no-input
```

### Set Sub-team (works via CLI)
```bash
jira issue edit SP-12345 --custom "Sub-team=Core" --no-input
```

Sub-team values for Infra: `Core`, `Automation`, `DevOps`

### Set Parent Epic
```bash
jira issue edit SP-12345 -P SP-EPIC-KEY --no-input
```

### Team Field
The Team field (`customfield_10001`) requires a team ID format and doesn't work easily via CLI. Set via Jira web UI.

## Groups and Teams Reference

### Groups (customfield_10059)
Groups in Jira: `Infra`, `Runtime`, `Platform`, etc.

JQL example:
```bash
jira issue list --jql "project = SP AND 'Group' = 'Infra'"
```

### Teams
For Infra group, team options include:
- Core (Frontend + Backend)
- Automation Team
- DevOps

## Complete Workflow Example

Create an Epic with a Story assigned to Infra Sprint 156:

```bash
# 1. Create Epic
jira issue create -t"Epic" -s"My Epic Title" -b"Description" -a"tomera@torq.io" --no-input
# Returns: SP-XXXXX

# 2. Create Story
jira issue create -t"Story" -s"My Story Title" -b"Description" -a"tomera@torq.io" --no-input
# Returns: SP-YYYYY

# 3. Set Group and Sub-team on both
jira issue edit SP-XXXXX --custom "Group=Infra" --custom "Sub-team=Core" --no-input
jira issue edit SP-YYYYY --custom "Group=Infra" --custom "Sub-team=Core" --no-input

# 4. Link Story to Epic
jira issue edit SP-YYYYY -P SP-XXXXX --no-input

# 5. Get Sprint ID (if needed)
curl -s -u "tomera@torq.io:$JIRA_API_TOKEN" \
  "https://stackpulse.atlassian.net/rest/agile/1.0/board/701/sprint?state=future"

# 6. Add Story to Sprint
jira sprint add 11169 SP-YYYYY
```

## Notes
- Use `--no-input` flag to skip interactive prompts
- Use `--debug` flag for troubleshooting
- Team field must be set via Jira web UI
