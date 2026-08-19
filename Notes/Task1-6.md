# GitHub Actions Lab — Tasks 1–6

## Task 1 — Pull Request / Workflow Basics

### Goal

Understand the basic GitHub Actions workflow lifecycle and how workflow execution relates to branches and pull requests.

### Key concepts

- Workflows are stored under `.github/workflows/`.
- Workflows can be triggered by events such as:
  - `push`
  - `pull_request`
- A workflow can run against a feature branch without changing `main`.
- The normal development flow is:

```text
Feature branch
      ↓
Push to GitHub
      ↓
GitHub Actions runs
      ↓
Pull Request → main
      ↓
Review
      ↓
Merge
```

### Key lesson

Pushing a feature branch to GitHub does **not** update `main`.

The branch must exist remotely so that GitHub can:

- Run Actions against it.
- Create a Pull Request.
- Perform checks and reviews.

---

# Task 2 — Pull Request Review / Branch Protection

### Goal

Understand how GitHub controls changes going into `main`.

### Concepts covered

- Pull Requests
- Required reviews
- Review requirements
- Code Owners
- Branch protection/rules
- Keeping work on a feature branch until approved

The important distinction is:

```text
Push feature branch
        ≠
Update main
```

The feature branch can contain workflow changes and trigger GitHub Actions while `main` remains unchanged.

### Key lesson

The Pull Request is the controlled path for getting tested and reviewed changes into `main`.

---

# Task 3 — GitHub Actions Workflow Execution

### Goal

Build and run a GitHub Actions workflow and understand the relationship between workflows, jobs, and steps.

### Basic workflow structure

```yaml
name: Example

on:
  push:
  pull_request:

jobs:
  example:
    runs-on: ubuntu-latest

    steps:
      - name: Example step
        run: echo "Hello GitHub Actions"
```

### Hierarchy

```text
Workflow
   ↓
Job
   ↓
Step
```

A workflow can contain multiple jobs.

Each job contains one or more steps.

### Key lesson

- **Workflow** = overall automation definition
- **Job** = unit of execution
- **Step** = individual command or action within a job

---

# Task 4 — Environment Variable Scope

## Goal

Understand environment-variable scope and precedence.

We deliberately defined the **same variable** at three different levels:

```text
Workflow
   ↓
Job
   ↓
Step
```

For example:

```yaml
env:
  SCOPE_TEST: workflow-value

jobs:
  test:
    env:
      SCOPE_TEST: job-value

    steps:
      - name: Normal step
        run: echo "$SCOPE_TEST"

      - name: Step override
        env:
          SCOPE_TEST: step-value
        run: echo "$SCOPE_TEST"
```

## Variable precedence

```text
Step
  ↑
Job
  ↑
Workflow
```

A narrower scope overrides a broader scope.

### Experiment 1 — All three levels defined

```text
Workflow → workflow-value
Job      → job-value
Step     → step-value
```

Effective values:

```text
Normal step         → job-value
Step override       → step-value
Another normal step → job-value
```

### Experiment 2 — Job-level variable removed

After removing the job-level variable:

```text
Normal step         → workflow-value
Step override       → step-value
Another normal step → workflow-value
```

This demonstrated that when the narrower scope disappears, GitHub Actions falls back to the broader scope.

### Key lesson

> An environment variable defined at a narrower scope overrides the same variable defined at a broader scope.

---

# Task 5 — Job Dependencies with `needs`

## Goal

Understand how jobs depend on one another and how GitHub Actions builds a job dependency graph.

Example:

```yaml
jobs:
  test:
    ...

  build:
    needs: test
    ...

  deploy:
    needs: build
    ...
```

This produces:

```text
test
 ↓
build
 ↓
deploy
```

## Important observation

The order of jobs in the YAML does **not** determine their execution order.

`needs` determines the dependency.

For example, even if the YAML lists:

```text
deploy
build
test
```

GitHub Actions can still execute:

```text
test → build → deploy
```

if the `needs` relationships specify that dependency chain.

## Multiple dependencies

`needs` can create a dependency graph rather than just a linear chain.

For example:

```text
          ┌→ build ──┐
test ─────┤           ├→ deploy
          └→ scan ────┘
```

A job can depend on multiple other jobs.

### Key lesson

> `needs` controls job dependency and therefore execution order.

Without `needs`, independent jobs can execute independently or in parallel.

---

# Task 6 — Conditional Job Execution

## Goal

Understand how `if:` controls whether a job executes based on the result of previous jobs.

Our dependency chain was:

```text
test
 ↓
build
 ↓
deploy
```

We then experimented with different conditions for `deploy`.

---

## 6.1 Success condition

We used:

```yaml
deploy:
  needs: build
  if: ${{ needs.build.result == 'success' }}
```

When `build` succeeded:

```text
test  ✅
  ↓
build ✅
  ↓
deploy ✅
```

When we intentionally made `build` fail:

```text
test  ✅
  ↓
build ❌
  ↓
deploy ⏭️
```

The deployment job was skipped.

### Lesson

The condition:

```text
needs.build.result == 'success'
```

allows `deploy` to execute only when the `build` dependency succeeded.

---

# 6.2 `failure()`

We then changed the condition to:

```yaml
deploy:
  needs: build
  if: ${{ failure() }}
```

With `build` intentionally failing:

```text
test  ✅
  ↓
build ❌
  ↓
deploy ✅
```

The `deploy` job ran because something in its dependency chain had failed.

### Useful scenarios

`failure()` can be useful for:

- Failure notifications
- Diagnostics
- Log collection
- Failure handling
- Cleanup actions

---

# 6.3 `always()`

Finally, we tested:

```yaml
deploy:
  needs: build
  if: ${{ always() }}
```

With a failed `build`:

```text
build  ❌
   ↓
deploy ✅
```

With a successful `build`:

```text
build  ✅
   ↓
deploy ✅
```

So `always()` allows the job to run regardless of whether the dependency succeeded or failed.

---

## Does `always()` remove the dependency?

**No.**

This is an important distinction.

With:

```yaml
deploy:
  needs: build
  if: ${{ always() }}
```

`deploy` still depends on `build`.

GitHub Actions still waits for `build` to finish:

```text
build
  │
  │ finishes
  ▼
deploy
```

`always()` changes what happens **after the dependency finishes**.

Normally:

```text
build ❌
   ↓
deploy ⏭️
```

With `always()`:

```text
build ❌
   ↓
deploy ✅
```

So:

> `needs` controls the dependency/order, while `always()` prevents the dependency's failure from automatically skipping the downstream job.

---

# Why Use `always()`?

A common real-world use case is **cleanup**.

For example:

```text
setup
  ↓
test
  ↓
cleanup
```

If testing fails:

```text
setup  ✅
  ↓
test   ❌
  ↓
cleanup ✅
```

You may still need to:

- Delete temporary infrastructure
- Shut down test environments
- Release resources
- Collect diagnostic information
- Upload logs
- Send notifications

Example:

```yaml
cleanup:
  needs: test
  if: ${{ always() }}
  runs-on: ubuntu-latest

  steps:
    - name: Cleanup
      run: echo "Cleaning temporary resources"
```

The cleanup job still waits for `test`, but it will run whether `test` succeeds or fails.

---

# Overall Concepts Learned — Tasks 1–6

We have now progressed from basic workflow execution to several core GitHub Actions concepts.

## Workflow structure

```text
                WORKFLOW
                   │
             ┌─────┴─────┐
             │           │
            JOB         JOB
             │
           STEPS
```

## Environment variable scope

```text
Workflow
   ↓
Job
   ↓
Step
```

Narrower scopes override broader scopes.

## Job dependencies

```text
test → build → deploy
```

Controlled with:

```yaml
needs:
```

## Conditional execution

Controlled with:

```yaml
if:
```

Different conditions include:

```text
success condition
failure()
always()
```

## The core mental model

```text
Workflow
   ↓
Jobs
   ↓
Steps

needs → controls relationships/order

if → controls whether a job executes

env → controls configuration scope
```

### Most important takeaway

> **Workflow defines the automation → jobs perform units of work → `needs` controls relationships → `if` controls execution conditions → `env` controls configuration scope.**