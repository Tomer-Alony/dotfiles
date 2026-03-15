---
name: investigate-ci
description: Investigate CI/CD failures in the torqio/app monorepo. Provide a GitHub Actions URL or PR number to diagnose build, test, and pipeline issues.
---

# CI/CD Failure Investigation Skill

Quickly diagnose CI/CD failures in the `torqio/app` monorepo using accumulated knowledge of the pipeline architecture, common failure modes, and debugging techniques.

## Usage

```
/investigate-ci https://github.com/torqio/app/actions/runs/12345678
/investigate-ci https://github.com/torqio/app/actions/runs/12345678/job/67890
/investigate-ci 13892
```

## Instructions for Claude

### Step 1: Parse Input and Fetch Run Data

Extract the run ID (and optional job ID) from the URL or PR number.

If given a PR number:
```bash
gh api "repos/torqio/app/actions/runs?branch=$(gh pr view {PR} --repo torqio/app --json headRefName -q .headRefName)&per_page=5" --jq '.workflow_runs[] | "\(.id) | \(.name) | \(.conclusion) | \(.created_at)"'
```

If given a run URL:
```bash
gh run view {RUN_ID} --repo torqio/app --json status,conclusion,name,event,headBranch
```

### Step 2: Identify Failed Jobs

```bash
gh api repos/torqio/app/actions/runs/{RUN_ID}/jobs --paginate | python3 -c "
import sys, json
data = json.load(sys.stdin)
for job in data['jobs']:
    if job['conclusion'] == 'failure':
        print(f\"FAILED: {job['name']} (ID: {job['id']})\")
        for step in job['steps']:
            if step['conclusion'] == 'failure':
                print(f\"  Step: {step['name']} (#{step['number']})\")
"
```

### Step 3: Pull Logs for Failed Jobs

```bash
gh api repos/torqio/app/actions/jobs/{JOB_ID}/logs 2>&1 | grep -E "ERR_|error|Error|FAIL|fatal|Cannot find" | grep -v "endgroup\|CLOUDSDK" | tail -20
```

### Step 4: Diagnose Using Known Failure Patterns

Check against these known failure modes, **in order of likelihood**:

---

#### Pattern 1: `ERR_PNPM_FETCH_403` — Package Registry Auth Failure

**Symptoms:**
```
ERR_PNPM_FETCH_403  GET https://npm.pkg.github.com/download/@torqio/{pkg}/{version}/...: Forbidden - 403
```
Followed by `ERR_MODULE_NOT_FOUND: Cannot find package 'prom-client'` (or other packages) because `pnpm install` failed partway through.

**Root Cause:** The `GITHUB_TOKEN` (`${{ github.token }}`) used for npm registry auth can't access a private package from another repo.

**Diagnosis Steps:**
1. Identify which `@torqio/*` package returned 403
2. Check if it's a NEW dependency in this PR: `gh pr diff {PR} --repo torqio/app --name-only | grep package.json`
3. Check which repo publishes it: `gh api orgs/torqio/packages/npm/{pkg-name} --jq '.repository.full_name'`
4. Check if it exists on master: search the lockfile on master for the package name

**Fix:** The publishing repo's package needs `torqio/app` added under Package Settings > Manage Actions access > Add Repository. This is required for any private package from a different repo.

---

#### Pattern 2: `setup-node` Timeout (Node.js Download)

**Symptoms:**
- `Run actions/setup-node@v6` step hangs or times out after 5 minutes
- Happens inside Docker containers (Playwright `mcr.microsoft.com/playwright:v1.43.0-jammy`)
- Does NOT happen on bare-metal self-hosted runners

**Root Cause:** `setup-node@v6` downloads Node from GitHub's `actions/node-versions` releases. GCP self-hosted runners have slow paths to GitHub CDN. The mirror input is ineffective because setup-node prioritizes its manifest over the mirror URL.

**Fix (already applied to master):** Node is installed via `curl` from `nodejs.org` BEFORE `setup-node`, then `node-version-file` is omitted so setup-node only handles caching/registry:
```yaml
- name: Install Node.js from nodejs.org
  run: |
    NODE_VERSION=$(cat "$GITHUB_WORKSPACE/.nvmrc")
    ARCH=$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')
    curl -fsSL "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-${ARCH}.tar.gz" \
      | tar xz --strip-components=1 -C /usr/local
- uses: actions/setup-node@v6
  with:
    # Omit node-version so setup-node uses the Node we installed
    cache: pnpm
```

**Check if this is the issue:** Look for download timing in logs — should be 2-6 seconds. If it's >60 seconds, the fix may have been reverted.

---

#### Pattern 3: Zombie Queued Runs Blocking Concurrency

**Symptoms:**
- Workflow shows as `queued` for hours
- Other runs on the same branch are stuck waiting
- `cancel-in-progress: true` doesn't help

**Root Cause:** GitHub Actions `cancel-in-progress` only cancels `in_progress` runs, NOT `queued` runs. When runner pool is starved (all runners busy), jobs get stuck in `queued` indefinitely, blocking the concurrency group.

**Diagnosis:**
```bash
# Find stuck queued runs
gh api "repos/torqio/app/actions/runs?status=queued" --jq '.workflow_runs[] | "\(.id) | \(.name) | \(.created_at) | \(.head_branch)"'
```

**Fix:** Force-cancel zombie runs:
```bash
gh api -X POST repos/torqio/app/actions/runs/{RUN_ID}/force-cancel
```

**WARNING:** Normal cancel (`/cancel`) won't work on queued runs. Must use `force-cancel`.

---

#### Pattern 4: NX Affected Detection Issues

**Symptoms:**
- Wrong projects detected as affected (too many or too few)
- `NX_BASE` or `NX_HEAD` resolution errors
- Shallow clone warnings

**Diagnosis:**
```bash
# Check NX_BASE and NX_HEAD in the logs
gh api repos/torqio/app/actions/jobs/{JOB_ID}/logs 2>&1 | grep "NX_BASE\|NX_HEAD\|affected\|Git history depth"
```

**Common causes:**
- `fetch-depth: 0` missing from `actions/checkout` (shallow clone can't compute affected)
- Branch not up to date with master (NX_BASE points to old commit)

---

#### Pattern 5: Asset Loading / Build Artifacts Missing

**Symptoms:**
- E2E tests fail with assets not loading
- Preview environment shows broken pages
- Specific apps' assets return 404

**Root Cause:** The preview Dockerfile (`build/preview/Dockerfile`) builds only affected apps, but the GCS asset fallback (`prepare-assets/action.yml`) was deleted in commit `3a93f6cd02` (Mar 9, 2025). Non-affected apps have no pre-built assets to fall back on.

**Diagnosis:** Check if the PR only modifies a subset of apps, and whether the preview includes all necessary assets.

---

#### Pattern 6: Integration Test Failures (Playwright)

**Symptoms:** Playwright tests fail in `integration_test.yml`

**Key files:**
- Workflow: `.github/workflows/integration_test.yml`
- Caller: `.github/workflows/run_integration_tests.yml`
- Container: `mcr.microsoft.com/playwright:v1.43.0-jammy`
- App served via pm2: `pnpm exec nx run ui:serve:integration`

**Diagnosis:**
1. Check if the local app started: look for `wait for local app be ready` step
2. Check pm2 logs in `output app logs` step
3. Look for test-specific failures in the playwright report artifact

**Requires `testable` label** on the PR to trigger.

---

#### Pattern 7: Merge Gate Failures (`merge_keeper`)

**Symptoms:** `merge_keeper / check_for_failed_jobs` fails even though you think tests passed.

**Root Cause:** `merge_keeper` checks ALL upstream jobs. If ANY job failed (even `Workflow Metrics` which is non-critical), it blocks merge.

**Diagnosis:**
```bash
gh api repos/torqio/app/actions/runs/{RUN_ID}/jobs --jq '.jobs[] | select(.conclusion == "failure") | .name'
```

Look for non-test failures (Workflow Metrics, CI Timing Report) that cascaded to merge_keeper.

---

### Pipeline Architecture Reference

#### Workflows triggered on PR:
| Workflow | File | Trigger |
|----------|------|---------|
| `build_and_test_nx` | `pr.yaml` | All PRs |
| `pr_checker` | `pr_checker.yml` | All PRs |
| `run_integration_tests` | `run_integration_tests.yml` | PRs with `testable` label |
| `Github workflow linter` | `github_workflow_linter.yml` | All PRs |

#### `build_and_test_nx` job dependency chain:
```
pre_build → Build / NX Build → Build / NX Test → merge_keeper
                             → Build / Build Docker Preview → Create App Preview
         → Build / Build Webserver ↗
         → Build / Quality Checks ↗
```

#### Key files:
- **NX setup**: `.github/actions/nx-setup/action.yml` — installs pnpm, Node, GCS auth, pnpm install
- **Build workflow**: `.github/workflows/build-nx.yml` — reusable, called by pr.yaml
- **NX config**: `nx.json` — parallelism (line 304, currently 3), GCS cache (line 308, read-only)
- **Preview Dockerfile**: `build/preview/Dockerfile` — hardcodes COPY for all 12 apps

#### Runner infrastructure:
- Self-hosted on GCP Kubernetes
- Labels: `small` (lightweight jobs), `large` (build/test jobs)
- Group: `torqio-self-hosted-runners`

#### Auth for npm packages:
- Token: `${{ github.token }}` passed as `node-auth-token` to nx-setup
- Registry: `https://npm.pkg.github.com` (scope `@torqio`)
- Private packages from OTHER repos need explicit Actions access grant

#### Concurrency groups:
All PR-triggered workflows should have:
```yaml
concurrency:
  group: "${{ github.workflow }} @ ${{ github.ref }}"
  cancel-in-progress: true
```
**Known missing:** `microcopy_review.yaml`, `header_based.yml`

### Step 5: Report Findings

Provide a concise summary:
```
Root cause: {one-line description}
Failed step: {step name} in {job name}
Error: {key error message}
Fix: {actionable fix}
```

If the issue matches a known pattern, reference the pattern by name so the user can quickly understand. If it's a new failure mode, investigate deeper and suggest adding it to this skill.
