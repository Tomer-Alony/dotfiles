---
name: fix-security-dep
description: Fix security vulnerabilities from Jira tickets. Use when given a Jira URL for a security/vulnerability ticket to create a branch, update dependencies, and open a PR with breaking change analysis.
---

# Security Dependency Fix Skill

Automatically fix security vulnerabilities from Jira tickets by creating a branch, updating dependencies, and opening a PR. Includes version analysis, breaking change detection, and documentation options.

## Prerequisites

**Required: Atlassian Claude Code Plugin**

This skill requires the Atlassian MCP plugin to fetch Jira ticket details and add comments.

**If not installed, the skill will display:**
```
❌ Error: Atlassian plugin not installed.

To install:
1. Run: claude mcp add atlassian
2. Follow the authentication prompts
3. Try this command again.

Alternatively, install via Claude Code settings → Plugins/MCP Servers → Atlassian
```

## Usage

Provide a Jira security ticket URL:
```
/fix-security-dep https://stackpulse.atlassian.net/browse/SP-65058
```

Or with the full board URL:
```
/fix-security-dep https://stackpulse.atlassian.net/jira/software/c/projects/SP/boards/701/backlog?selectedIssue=SP-65058
```

## Workflow Overview

1. Parse Jira URL → Extract ticket number
2. Verify Atlassian plugin is available
3. Fetch ticket details → Extract vulnerability info
4. **Analyze version change** → Detect major/minor/patch
5. **Fetch release notes** → Check for breaking changes
6. **If major upgrade** → Present options including documentation-only
7. Based on user choice: Create PR, document findings, or skip
8. **Include breaking change details** in PR or Jira comment

---

## Instructions for Claude

### Step 1: Verify Prerequisites

First, use ToolSearch to find `+atlassian jira issue`. If no tools are found, display:

```
❌ Error: Atlassian plugin not installed.

To install:
1. Run: claude mcp add atlassian
2. Follow the authentication prompts
3. Try this command again.

Alternatively, install via Claude Code settings → Plugins/MCP Servers → Atlassian
```

Then STOP - do not proceed further.

### Step 2: Parse URL and Extract Ticket

Extract the ticket number from the URL. Patterns to match:
- `selectedIssue=SP-12345` (board URL)
- `/browse/SP-12345` (direct URL)
- Just `SP-12345` (if user provides ticket number directly)

### Step 3: Fetch Ticket Details

Use `mcp__plugin_atlassian_atlassian__getJiraIssue` with:
- `cloudId`: Extract domain from URL (e.g., `stackpulse.atlassian.net`)
- `issueIdOrKey`: The ticket number (e.g., `SP-65058`)

### Step 4: Parse Vulnerability Information

The ticket description typically contains a table with:
- `Library` - The package name (e.g., `apache-airflow`)
- `vulnerable_version` - Current vulnerable version (e.g., `2.10.3`)
- `fixed_version` - Version to upgrade to (e.g., `3.1.6`)
- `Path` - File path to update (e.g., `/requirements.txt`)
- `VulnerabilityId` - CVE identifier (e.g., `CVE-2025-68675`)

### Step 5: Analyze Version Change (CRITICAL)

Parse the semantic versions and determine the upgrade type:

```
Given: old_version = "2.10.3", new_version = "3.1.6"

Parse as: MAJOR.MINOR.PATCH
- Old: 2.10.3 → major=2, minor=10, patch=3
- New: 3.1.6 → major=3, minor=1, patch=6

Determine upgrade type:
- If major changed: MAJOR UPGRADE ⚠️
- Else if minor changed: MINOR UPGRADE
- Else: PATCH UPGRADE
```

Display to user:
```
📦 Version Analysis:
   Library: {library}
   Current: {old_version}
   Target:  {new_version}
   Type:    {MAJOR|MINOR|PATCH} UPGRADE
```

### Step 6: Fetch Release Notes and Breaking Changes

Use WebSearch to find release notes:
```
{library} {new_major_version}.0 release notes breaking changes migration guide
```

Example: `Apache Airflow 3.0 release notes breaking changes migration guide`

Then use WebFetch on the official release notes/migration guide URL to extract:
- Breaking changes
- Migration steps required
- Deprecated features

Summarize findings for the user:
```
📋 Release Notes Summary:

**Breaking Changes Found:**
- [List each breaking change briefly]

**Migration Steps Required:**
- [List required migration actions]

**Official Migration Guide:**
{url_to_migration_guide}
```

If no release notes found:
```
⚠️ Could not fetch release notes for {library} {new_version}.
Please review manually: https://pypi.org/project/{library}/{new_version}/
```

### Step 7: Handle Major Upgrades (REQUIRE APPROVAL)

**If MAJOR upgrade detected, you MUST ask for approval before proceeding:**

Use AskUserQuestion:
```
question: "This is a MAJOR version upgrade ({old_major}.x → {new_major}.x) with breaking changes. How would you like to proceed?"
header: "Major Upgrade"
options:
  - label: "Proceed with upgrade"
    description: "I understand the breaking changes and want to proceed. I will handle any required migrations."
  - label: "Document findings only"
    description: "Add a detailed comment to the Jira ticket with breaking change analysis. No code changes."
  - label: "Find latest {old_major}.x version"
    description: "Search for a version in the current major that might fix the CVE."
  - label: "Skip this ticket"
    description: "Do not make changes. I'll handle this manually."
```

**If no fix exists in the current major version:** Ask again with updated options:
```
question: "No fix available in {old_major}.x series. CVE is only fixed in {new_version}. How would you like to proceed?"
header: "No Backport"
options:
  - label: "Proceed with major upgrade"
    description: "Upgrade to {new_version}. I'll handle the breaking changes."
  - label: "Document findings only"
    description: "Add a detailed comment to the Jira ticket explaining the situation and breaking changes."
  - label: "Skip this ticket"
    description: "Do not make changes. I'll evaluate the migration separately."
```

### Step 8: Execute Based on User Choice

#### Option A: Document Findings Only

Add a comment to the Jira ticket using `mcp__plugin_atlassian_atlassian__addCommentToJiraIssue`:

```markdown
## ⚠️ Analysis: Major Version Upgrade Required

**{CVE}** is only fixed in {library} **{new_version}**. {Note about backport availability}

### Version Impact
- **Current version:** {old_version}
- **Fixed version:** {new_version}
- **Upgrade type:** ⚠️ **MAJOR** ({old_major}.x → {new_major}.x)

### Breaking Changes in {library} {new_major}.0

{List all breaking changes found}

### Migration Resources
- [Migration Guide]({migration_guide_url})
- [Release Notes]({release_notes_url})

### Recommendation
This requires a planned migration effort rather than a simple dependency bump. Consider:
1. {List specific recommendations based on breaking changes}

---
🤖 *Analysis performed by Claude Code*
```

Display to user:
```
📝 Documented findings on Jira ticket.

📋 Ticket: {jira_url}
📦 Library: {library} {old_version} → {new_version}
⚠️ Status: Major upgrade required - documented for planning

No code changes were made.
```

#### Option B: Skip

Display:
```
⏭️ Skipped. No changes made.
To handle manually, see: {jira_url}
```

#### Option C: Proceed with Upgrade

Continue to steps 9-14.

### Step 9: Verify Clean Working Directory

Run `git status --porcelain` and abort if there are uncommitted changes:
```
❌ Error: Working directory has uncommitted changes.
Please commit or stash your changes first.
```

### Step 10: Create Branch

```bash
git checkout -b {TICKET}-fix-security-vulnerability
```

### Step 11: Update Dependency

Edit the dependency file (usually `requirements.txt` or `package.json`) to update the version.

For Python `requirements.txt`:
```
{library}=={new_version}
```

### Step 12: Run Tests (Optional)

If `make test` or `pytest` is available, attempt to run tests.
- If tests pass: Note in PR
- If tests fail due to missing local dependencies: Note that CI will validate
- If tests fail due to breaking changes: Include failures in PR for visibility

### Step 13: Commit and Push

```bash
git add {file}
git commit -m "[{TICKET}] Fix {severity} vulnerability in {library}

Upgrade {library} from {old_version} to {new_version} to address {CVE}.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"

git push -u origin {branch}
```

### Step 14: Create PR with Breaking Change Details

**For PATCH/MINOR upgrades:**
```bash
gh pr create --title "[{TICKET}] Fix {severity} vulnerability in {library}" --body "## Summary
- Upgrade \`{library}\` from {old_version} to {new_version}
- Addresses: {CVE}
- Upgrade type: **{MINOR|PATCH}** (no breaking changes expected)

## Jira Ticket
{jira_url}

## Test Plan
- [ ] CI pipeline passes
- [ ] Staging deployment succeeds
- [ ] Application loads correctly

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

**For MAJOR upgrades (user approved):**
```bash
gh pr create --title "[{TICKET}] ⚠️ MAJOR: Fix {severity} vulnerability in {library}" --body "## Summary
- Upgrade \`{library}\` from {old_version} to {new_version}
- Addresses: {CVE}
- Upgrade type: **⚠️ MAJOR VERSION UPGRADE**

## ⚠️ Breaking Changes

{List all breaking changes discovered from release notes}

### Required Migration Steps:
{List migration steps from the release notes}

### Migration Guide:
{Link to official migration guide}

## How This PR Addresses Breaking Changes

{If Claude made any code changes to handle breaking changes, describe them here}
{If no code changes were made, note: "This PR only updates the version. Additional migration work may be required."}

## Jira Ticket
{jira_url}

## Test Plan
- [ ] CI pipeline passes
- [ ] Review breaking changes above
- [ ] Verify no deprecated APIs are used
- [ ] Staging deployment succeeds
- [ ] Application loads correctly
- [ ] Test critical workflows

**⚠️ Reviewer: Please carefully review the breaking changes before merging.**

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

### Step 15: Report Results

**For successful PATCH/MINOR:**
```
✅ Security fix complete!

📦 {library}: {old_version} → {new_version} ({MINOR|PATCH} upgrade)
🔒 Fixes: {CVE}
🌿 Branch: {branch}
🔗 PR: {pr_url}
📋 Jira: {jira_url}
```

**For successful MAJOR:**
```
✅ Security fix complete (MAJOR UPGRADE)

📦 {library}: {old_version} → {new_version} (⚠️ MAJOR upgrade)
🔒 Fixes: {CVE}
🌿 Branch: {branch}
🔗 PR: {pr_url}
📋 Jira: {jira_url}

⚠️ Important: This is a major version upgrade. Please:
1. Review the breaking changes in the PR description
2. Test thoroughly before merging
3. Consider additional migration work if needed
```

**For documentation only:**
```
📝 Documented findings on Jira ticket.

📋 Ticket: {jira_url}
📦 Library: {library} {old_version} → {new_version}
⚠️ Status: Major upgrade required - documented for planning

No code changes were made.
```

---

## Example Sessions

### Example 1: Minor Upgrade (Auto-proceed)

**User:** `/fix-security-dep https://stackpulse.atlassian.net/browse/SP-12345`

**Claude:**
```
🔍 Fetching ticket SP-12345...

📦 Version Analysis:
   Library: requests
   Current: 2.28.1
   Target:  2.28.3
   Type:    PATCH UPGRADE

No breaking changes expected. Proceeding with fix...

✅ Security fix complete!

📦 requests: 2.28.1 → 2.28.3 (PATCH upgrade)
🔒 Fixes: CVE-2023-XXXXX
🌿 Branch: SP-12345-fix-security-vulnerability
🔗 PR: https://github.com/org/repo/pull/123
📋 Jira: https://company.atlassian.net/browse/SP-12345
```

### Example 2: Major Upgrade with Documentation

**User:** `/fix-security-dep https://stackpulse.atlassian.net/browse/SP-65058`

**Claude:**
```
🔍 Fetching ticket SP-65058...

📦 Version Analysis:
   Library: apache-airflow
   Current: 2.10.3
   Target:  3.1.6
   Type:    ⚠️ MAJOR UPGRADE (2.x → 3.x)

📋 Release Notes Summary:

**Breaking Changes Found:**
- CLI: `airflow db init/upgrade` removed → use `airflow db migrate`
- Task Isolation: Operators cannot access metadata database directly
- API: REST API defaults to `logical_date=None` for DAG runs
- Imports: Standard operators moved to `apache-airflow-providers-standard`

**Migration Guide:**
https://airflow.apache.org/docs/apache-airflow/stable/installation/upgrading_to_airflow3.html
```

**Claude asks:** "This is a MAJOR version upgrade (2.x → 3.x) with breaking changes. How would you like to proceed?"

**User selects:** "Document findings only"

**Claude:**
```
📝 Documented findings on Jira ticket.

📋 Ticket: https://stackpulse.atlassian.net/browse/SP-65058
📦 Library: apache-airflow 2.10.3 → 3.1.6
⚠️ Status: Major upgrade required - documented for planning

No code changes were made.
```
