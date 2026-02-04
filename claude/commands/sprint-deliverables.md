---
name: sprint-deliverables
description: Summarize a Jira sprint by team and sprint number. Shows TL;DR themes, status overview, and detailed ticket breakdown.
argument-hint: <team> <sprint-number>
---

# Sprint Deliverables Summary

Generate a comprehensive summary of a Jira sprint, organized by themes with status breakdown.

## Prerequisites

**Required: Atlassian Claude Code Plugin**

This skill requires the Atlassian MCP plugin to fetch Jira sprint data.

## Usage

```
/sprint-deliverables Infra 155
/sprint-deliverables DevOps 154
/sprint-deliverables "Case Bears" 153
```

## Arguments

The user invoked this command with: $ARGUMENTS

Parse as: `<team-name> <sprint-number>`

---

## Instructions for Claude

### Step 1: Parse Arguments

Extract team name and sprint number from `$ARGUMENTS`.

Examples:
- `Infra 155` → team="Infra", sprint=155
- `DevOps 154` → team="DevOps", sprint=154
- `"Case Bears" 153` → team="Case Bears", sprint=153

If arguments are missing or invalid, ask the user:
```
Please provide team name and sprint number.
Example: /sprint-deliverables Infra 155
```

### Step 2: Verify Prerequisites

Use ToolSearch to find `+atlassian jira jql`. If no tools are found, display:

```
❌ Error: Atlassian plugin not installed.

To install:
1. Run: claude mcp add atlassian
2. Follow the authentication prompts
3. Try this command again.
```

Then STOP.

### Step 3: Query Jira Sprint

Use `mcp__plugin_atlassian_atlassian__searchJiraIssuesUsingJql` with:
- `cloudId`: `stackpulse.atlassian.net`
- `jql`: `project = SP AND sprint = "{team} -  Sprint {number}" ORDER BY status DESC, created DESC`
- `fields`: `["summary", "status", "assignee", "issuetype", "parent"]`
- `maxResults`: 100

**IMPORTANT:** Note the double space in sprint name format: `{team} -  Sprint {number}`

If no results, try alternate formats:
- `{team} - Sprint {number}` (single space)
- `{team} Sprint {number}` (no dash)

### Step 4: Parse Results

If results are saved to a file due to size, use jq to extract:

```bash
# Get total count
jq -r '.issues.totalCount' {file}

# Get status breakdown
jq -r '[.issues.nodes[].fields.status.name] | group_by(.) | map({status: .[0], count: length}) | .[] | "\(.status): \(.count)"' {file}

# Get all tickets
jq -r '.issues.nodes[] | "\(.key): \(.fields.summary) | \(.fields.status.name) | \(.fields.assignee.displayName // "Unassigned")"' {file}
```

### Step 5: Categorize Tickets by Theme

Analyze ticket summaries and group them into themes. Use keyword matching:

| Theme | Keywords to Match |
|-------|-------------------|
| R&D Alerting & Dashboards | alert, dashboard, grafana, monitor, observability, runbook, threshold |
| Monorepo / CI/CD | monorepo, nx, ci, cd, pipeline, build, vite, webpack, eslint, prettier, github actions, workflow |
| Design System | DS, storybook, component, ui, chip, button, dialog, token, color, tq- |
| Security Updates | vulnerability, CVE, security, HIGH, CRITICAL, Infra-Core |
| Data & Infrastructure | data, pipeline, bigquery, datos, dataflow, cloud, cost, BI |
| Observability | o11y, observability, tracing, metrics, logging |
| Bug Fixes | fix, bug, error, issue, broken |
| Features | feature, add, implement, support, new |

If a ticket doesn't match any theme, put it in "Other".

### Step 6: Generate Summary Report

Output the report in this exact format:

```markdown
# 📊 {Team} - Sprint {Number} Summary

## TL;DR
| Theme | Tickets |
|-------|---------|
| {emoji} {Theme1} | {count1} |
| {emoji} {Theme2} | {count2} |
| ... | ... |
| **Total** | **{total}** |

## Status Overview
| Status | Count |
|--------|-------|
| {status1} | {count1} |
| {status2} | {count2} |
| ... | ... |

---

## Deliverables by Theme

### {emoji} {Theme1} ({count} tickets)
| Ticket | Summary | Status | Assignee |
|--------|---------|--------|----------|
| {key} | {summary} | {status} | {assignee} |
| ... | ... | ... | ... |

### {emoji} {Theme2} ({count} tickets)
...

---

## ⚠️ Observations
- {observation1}
- {observation2}
```

### Theme Emojis

Use these emojis for themes:
- 🔔 R&D Alerting & Dashboards
- 🏗️ Monorepo / CI/CD
- 🎨 Design System
- 🔐 Security Updates
- 📈 Data & Infrastructure
- 👁️ Observability
- 🐛 Bug Fixes
- ✨ Features
- 📦 Other

### Observations to Include

Generate 2-4 observations based on:
- Percentage of tickets still in "To Do" (high % = sprint just started or at risk)
- Number of unassigned tickets
- Number of tickets marked Done
- Any blocked/waiting tickets
- Distribution across themes

---

## Example Output

```markdown
# 📊 Infra - Sprint 155 Summary

## TL;DR
| Theme | Tickets |
|-------|---------|
| 🎨 Design System | 11 |
| 🏗️ Monorepo / CI/CD | 10 |
| 🔔 R&D Alerting & Dashboards | 7 |
| 🔐 Security Updates | 6 |
| 📈 Data & Infrastructure | 4 |
| 👁️ Observability | 1 |
| **Total** | **39** |

## Status Overview
| Status | Count |
|--------|-------|
| To Do | 29 |
| Waiting for | 4 |
| In Progress | 3 |
| Development | 2 |
| Requirements | 1 |

---

## Deliverables by Theme

### 🔔 R&D Alerting & Dashboards (7 tickets)
| Ticket | Summary | Status | Assignee |
|--------|---------|--------|----------|
| SP-65536 | Map all existing grafana, GCP, BQ, Looker dashboards | In Progress | Bar Shnayder |
| SP-65443 | Airflow - tag relevant teams on dag failures alerts | In Progress | Bar Shnayder |
| ... | ... | ... | ... |

...

---

## ⚠️ Observations
- **29 of 39 tickets (74%) still in "To Do"** - sprint just started?
- **14 tickets unassigned**
- No tickets marked as Done yet
```
