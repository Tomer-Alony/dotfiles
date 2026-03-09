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

**IMPORTANT**: The `--custom` flag on the `jira` CLI shows a warning about "invalid custom fields" and **does NOT reliably set values**. The CLI says "Issue updated" but the fields are silently ignored.

**Use the REST API to set custom fields reliably:**

```bash
curl -s -X PUT \
  -H "Content-Type: application/json" \
  -u "tomera@torq.io:$JIRA_API_TOKEN" \
  "https://stackpulse.atlassian.net/rest/api/3/issue/SP-12345" \
  -d '{
    "fields": {
      "customfield_10059": {"id": "23341"},
      "customfield_10204": {"id": "23343"},
      "customfield_10005": {"id": "10005"},
      "customfield_10024": 0.5
    }
  }'
```

A successful update returns HTTP 204 with an empty body.

### Custom Field ID Reference

| Field Name | Custom Field Key | Common Values |
|-----------|-----------------|---------------|
| Group | `customfield_10059` | `Infra` (id: 23341), `Runtime`, `Platform` |
| Sub-team | `customfield_10204` | `Core` (id: 23343), `Automation`, `DevOps` |
| Epic type / Category | `customfield_10005` | `Investment` (id: 10005) |
| Story Points | `customfield_10024` | numeric (e.g., 0.5, 1, 2, 3, 5) |
| Epic Link | `customfield_10014` | issue key string (e.g., "SP-68039") |
| Sprint | `customfield_10020` | sprint ID (numeric) |

For option fields (Group, Sub-team, Epic type), use `{"id": "<option_id>"}`.
For numeric fields (Story Points), use the number directly.

### Set Parent Epic
```bash
jira issue create -tStory -s"Summary" -P SP-EPIC-KEY --no-input
# Or edit existing:
jira issue edit SP-12345 -P SP-EPIC-KEY --no-input
```

### Team Field
The Team field (`customfield_10001`) requires a team ID format and doesn't work easily via CLI or REST. Set via Jira web UI.

### Set Multiple Custom Fields on Multiple Tickets

Loop pattern for batch updates:
```bash
for ticket in SP-11111 SP-22222 SP-33333; do
  curl -s -X PUT \
    -H "Content-Type: application/json" \
    -u "tomera@torq.io:$JIRA_API_TOKEN" \
    "https://stackpulse.atlassian.net/rest/api/3/issue/${ticket}" \
    -d '{
      "fields": {
        "customfield_10059": {"id": "23341"},
        "customfield_10204": {"id": "23343"},
        "customfield_10005": {"id": "10005"},
        "customfield_10024": 0.5
      }
    }'
  echo "${ticket}: done"
done
```

## Groups and Teams Reference

### Groups (customfield_10059)
Groups in Jira: `Infra`, `Runtime`, `Platform`, etc.

JQL example:
```bash
jira issue list --jql "project = SP AND 'Group' = 'Infra'"
```

### Sub-teams (customfield_10204)
Sub-team values for Infra: `Core`, `Automation`, `DevOps`

## Complete Workflow Examples

### Create an Epic with Stories

```bash
# 1. Create Epic
jira issue create -t"Epic" -s"My Epic Title" -b"Description" --no-input --raw
# Returns JSON: {"id":"...","key":"SP-XXXXX"}

# 2. Create Story under the Epic
jira issue create -tStory -P SP-XXXXX -s"My Story Title" -b"Description" --no-input --raw
# Returns JSON: {"id":"...","key":"SP-YYYYY"}

# 3. Set custom fields via REST API
curl -s -X PUT \
  -H "Content-Type: application/json" \
  -u "tomera@torq.io:$JIRA_API_TOKEN" \
  "https://stackpulse.atlassian.net/rest/api/3/issue/SP-YYYYY" \
  -d '{
    "fields": {
      "customfield_10059": {"id": "23341"},
      "customfield_10204": {"id": "23343"},
      "customfield_10005": {"id": "10005"},
      "customfield_10024": 0.5
    }
  }'

# 4. Get Sprint ID (if needed)
curl -s -u "tomera@torq.io:$JIRA_API_TOKEN" \
  "https://stackpulse.atlassian.net/rest/agile/1.0/board/701/sprint?state=future"

# 5. Add Story to Sprint
jira sprint add <SPRINT_ID> SP-YYYYY
```

### Enrich an Epic with Tech Design Tickets

When creating multiple tech design tickets under an existing epic:

1. **Reference an existing ticket** for format (e.g., `jira issue view SP-XXXXX --raw` to see field structure)
2. **Create tickets** with the `[Tech Design] -` prefix:
```bash
jira issue create -tStory -P SP-EPIC-KEY \
  -s "[Tech Design] - <topic> for <goal>" \
  -b $'<Current state explanation>\n\n<Problem/motivation>\n\nThings to consider:\n1. Item one\n2. Item two' \
  -e 4h --no-input --raw
```
3. **Set custom fields via REST API** (Group, Sub-team, Story Points, Epic type) - see batch update pattern above
4. **Do NOT assign** - leave unassigned unless explicitly asked

## Fetching Issue Details

### View raw JSON (for inspecting field IDs and values)
```bash
jira issue view SP-12345 --raw
```

### Read specific fields via REST API
```bash
curl -s -u "tomera@torq.io:$JIRA_API_TOKEN" \
  "https://stackpulse.atlassian.net/rest/api/3/issue/SP-12345?fields=summary,description,customfield_10059,customfield_10204,customfield_10005,customfield_10024"
```

## Notes
- Use `--no-input` flag to skip interactive prompts
- Use `--raw` flag on create to get JSON output with the new issue key
- Use `--debug` flag for troubleshooting
- Team field must be set via Jira web UI
- The `--custom` CLI flag is **unreliable** - always use the REST API for custom fields
- Auth for REST API: `$JIRA_API_TOKEN` env var (set in ~/.zshrc). Fallback: macOS keychain entry `jira:https://stackpulse.atlassian.net`
