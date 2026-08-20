# GitHub Actions Lab — Tasks 7–12

This document contains the notes and practical lessons from Tasks 7 through 12 of the GitHub Actions Lab.

The lab follows an **isolated-task approach**:

- Each task focuses on one GitHub Actions concept.
- Previous concepts are not unnecessarily carried into the next task.
- Experiments are used to understand behavior rather than simply copying syntax.
- Important concepts are documented here for later reference.
- More advanced workflows can combine these concepts later as a capstone exercise.

---

# Task 7 — Job Outputs

## Objective

Learn how to pass values:

```text
Step → Job → Another Job
```

GitHub Actions has different levels of outputs.

A step can create an output, and a job can expose that step output as a job output.

Another job can then consume that job output using the `needs` context.

---

## Step Output

A step can create an output by writing a value to:

```text
$GITHUB_OUTPUT
```

Example:

```yaml
- name: Generate version
  id: generate_version
  run: |
    echo "step_version=1.0.${{ github.run_number }}" >> "$GITHUB_OUTPUT"
```

The step has an identifier:

```yaml
id: generate_version
```

This allows another step or the job to reference its outputs.

The output created above is:

```text
step_version
```

It can be referenced as:

```yaml
${{ steps.generate_version.outputs.step_version }}
```

---

## Why the `id` Is Required

The `id` identifies the step within the job.

For example:

```yaml
id: generate_version
```

allows us to reference:

```yaml
steps.generate_version.outputs.step_version
```

The step's display name:

```yaml
name: Generate version
```

is not what is used in the expression.

The `id` is the identifier used by GitHub Actions expressions.

---

## Multiple Step Outputs

A single step can create multiple outputs.

Example:

```yaml
- name: Generate version
  id: generate_version
  run: |
    echo "step_version=1.0.${{ github.run_number }}" >> "$GITHUB_OUTPUT"
    echo "delta=3.0.0${{ github.run_number }}" >> "$GITHUB_OUTPUT"
```

The step now exposes:

```text
step_version
delta
```

They can be referenced independently:

```yaml
${{ steps.generate_version.outputs.step_version }}
```

and:

```yaml
${{ steps.generate_version.outputs.delta }}
```

---

## Job Outputs

A job can expose step outputs as job outputs.

Example:

```yaml
build:
  outputs:
    app_version: ${{ steps.generate_version.outputs.step_version }}
```

Here:

```text
app_version
```

is the **job output name**.

It receives its value from:

```text
steps.generate_version.outputs.step_version
```

---

## The Names Do Not Need to Match

This is important.

The following is perfectly valid:

```yaml
outputs:
  app_version: ${{ steps.generate_version.outputs.step_version }}
```

There are two different names:

```text
step_version
    ↓
step output name

app_version
    ↓
job output name
```

The job output is simply mapping the step output to a new name.

---

## Passing the Output to Another Job

Another job must depend on the producing job:

```yaml
deploy:
  needs: build
```

It can then access the job output:

```yaml
${{ needs.build.outputs.app_version }}
```

Example:

```yaml
deploy:
  needs: build
  runs-on: ubuntu-latest

  steps:
    - name: Deploy
      run: |
        echo "Deploying version: ${{ needs.build.outputs.app_version }}"
```

---

## Complete Flow

```text
Generate version step
        │
        │
        │ step output
        ▼
steps.generate_version.outputs.step_version
        │
        │
        │ mapped to job output
        ▼
needs.build.outputs.app_version
        │
        ▼
Deploy job
```

---

## Important Lesson

There are three separate concepts:

```text
Step ID
Step Output
Job Output
```

For example:

```yaml
id: generate_version

run: |
  echo "step_version=1.0.10" >> "$GITHUB_OUTPUT"

outputs:
  app_version: ${{ steps.generate_version.outputs.step_version }}
```

Think of it as:

```text
generate_version
      │
      ▼
step_version
      │
      ▼
app_version
```

---

# Task 8 — Artifacts

## Objective

Learn how to create files during a workflow and preserve them as GitHub Actions artifacts.

Artifacts are useful for passing or preserving files produced by a workflow.

Examples include:

- Build packages
- Reports
- Test results
- Logs
- Build metadata
- Deployment packages

---

# Creating Build Information

Example:

```yaml
- name: Create Build Info
  run: |
    mkdir -p build_artifacts

    echo "Application version: ${{ steps.generate_version.outputs.step_version }}" \
      > build_artifacts/build-info.txt

    echo "Running version: ${{ steps.generate_version.outputs.delta }}" \
      >> build_artifacts/build-info.txt

    echo "Build run: ${{ github.run_number }}" \
      >> build_artifacts/build-info.txt
```

This creates:

```text
build_artifacts/
└── build-info.txt
```

---

# Uploading the Artifact

Use:

```yaml
- name: Upload Build Info
  uses: actions/upload-artifact@v4
  with:
    name: build-info
    path: build_artifacts/
```

The artifact is now associated with the workflow run.

---

# Downloading an Artifact

A later job can download it:

```yaml
- name: Download Build Info
  uses: actions/download-artifact@v5
  with:
    name: build-info
    path: build_artifacts
```

The file can then be used normally:

```bash
cat build_artifacts/build-info.txt
```

---

# Artifact Flow

```text
Build Job
    │
    ├── Create files
    │
    ▼
Upload Artifact
    │
    ▼
GitHub Actions Artifact Storage
    │
    ▼
Deploy Job
    │
    ▼
Download Artifact
    │
    ▼
Use files
```

---

# Artifact vs Job Output

A job output is best suited for passing a value:

```text
version = 1.0.25
```

An artifact is suited for files:

```text
build_artifacts/
├── build-info.txt
├── application.zip
└── test-results/
```

Think:

```text
Job Output
    ↓
"Here is a value."

Artifact
    ↓
"Here are some files."
```

---

# Important Lesson

Artifacts allow files generated by one part of a workflow to be preserved and consumed later.

They are particularly useful in CI/CD pipelines where:

```text
Build
  ↓
Package
  ↓
Artifact
  ↓
Deploy
```

---

# Task 9 — Caching

## Objective

Understand how GitHub Actions caching can reuse data between workflow runs.

Caching is primarily about improving performance by avoiding repeated work.

Typical real-world examples include:

- Dependency caches
- Package manager caches
- Build caches
- Tool caches

---

# Basic Cache

Example:

```yaml
- name: Restore dependencies cache
  uses: actions/cache@v4
  with:
    path: dependencies
    key: dependencies-${{ runner.os }}
```

Two important parameters are:

```yaml
path:
key:
```

---

## `path`

The path specifies what data should be cached.

Example:

```yaml
path: dependencies
```

This means the contents of:

```text
dependencies/
```

are associated with the cache.

---

## `key`

The key identifies the cache.

Example:

```yaml
key: dependencies-${{ runner.os }}
```

On Ubuntu this could resolve to:

```text
dependencies-Linux
```

The cache key is extremely important.

---

# First Run

If the cache doesn't exist:

```text
Cache lookup
     │
     ▼
MISS
     │
     ▼
Create dependency data
     │
     ▼
Cache saved
```

---

# Later Run

If the same cache key exists:

```text
Cache lookup
     │
     ▼
HIT
     │
     ▼
Restore dependency data
```

---

# Experiment Used in the Lab

We created a dependency file:

```yaml
- name: Create Dependency Data
  run: |
    mkdir -p dependencies

    if [ -f dependencies/dependency.txt ]; then
      echo "Dependency already exists — using cached dependency"
    else
      echo "Dependency created during the run ${{ github.run_number }}" \
        > dependencies/dependency.txt

      echo "Dependency created — cache was empty"
    fi
```

The Bash statement:

```bash
if [ -f dependencies/dependency.txt ]; then
```

checks whether the file exists.

The Bash conditional ends with:

```bash
fi
```

`fi` is simply the Bash way of ending an `if` block.

---

# Cache Hit Experiment

After the first run created and saved the cache, later runs restored the file.

For example:

```text
Cache → HIT

Dependency already exists — using cached dependency
```

The dependency file contained the original run number.

This demonstrated that the file was restored from the cache rather than recreated.

---

# Changing the Cache Key

The original key:

```yaml
key: dependencies-${{ runner.os }}
```

was changed to:

```yaml
key: dependencies-${{ runner.os }}-v2
```

This resulted in a different cache namespace.

For example:

```text
dependencies-Linux
```

and:

```text
dependencies-Linux-v2
```

are different cache keys.

Therefore:

```text
Old key
dependencies-Linux
        │
        └── existing cache

New key
dependencies-Linux-v2
        │
        └── cache MISS
```

---

# Important Lesson

The key determines which cache GitHub Actions looks for.

Same key:

```text
→ existing cache can be reused
```

Different key:

```text
→ different cache
```

---

# Cache vs Artifact

This distinction is extremely important.

## Artifact

Use an artifact when you want to preserve or pass files.

```text
"I need this output later."
```

Example:

```text
application.zip
test-report.html
build-info.txt
```

## Cache

Use a cache when you want to reuse data to avoid repeating work.

```text
"I want this data available for future runs."
```

Example:

```text
dependency cache
package manager cache
build cache
```

Simple rule:

```text
Artifact → preserve/pass outputs

Cache → speed up future work
```

---

# Task 10 — Secrets

## Objective

Learn how to securely store and consume sensitive values in GitHub Actions.

Sensitive information should not be hardcoded into workflow files.

Examples:

- API keys
- Passwords
- Access tokens
- Deployment credentials
- Cloud credentials

---

# Repository Secret

A repository secret was created:

```text
LAB_SECRET
```

The actual value was a harmless lab value.

The important part is that the value is stored in GitHub rather than inside the workflow YAML.

---

# Accessing a Secret

Secrets can be accessed using:

```yaml
${{ secrets.LAB_SECRET }}
```

Example:

```yaml
- name: Use Lab Secret
  run: |
    echo "The secret is: ${{ secrets.LAB_SECRET }}"
```

GitHub masks the value in the workflow log.

Instead of seeing the actual secret:

```text
The secret is: github-actions-lab-secret
```

the log shows:

```text
The secret is: ***
```

---

# Mapping a Secret to an Environment Variable

The secret can be mapped to an environment variable.

The names do not have to be the same.

Example:

```yaml
- name: Use Lab Secret
  env:
    APP_TOKEN: ${{ secrets.LAB_SECRET }}
  run: |
    echo "Environment variable contains: $APP_TOKEN"
```

The mapping is:

```text
GitHub Secret
LAB_SECRET
     │
     ▼
Environment Variable
APP_TOKEN
     │
     ▼
Shell
$APP_TOKEN
```

---

# Secret Masking

We deliberately attempted to print the environment variable:

```bash
echo "$APP_TOKEN"
```

The workflow output still showed:

```text
***
```

This demonstrated that changing the environment variable name does not bypass GitHub's masking behavior.

The secret remained protected in the logs.

---

# Important Lessons

Do not put sensitive values directly into workflow YAML:

```yaml
# DON'T DO THIS
password: "my-password"
```

Instead:

```yaml
env:
  APP_TOKEN: ${{ secrets.LAB_SECRET }}
```

The application or command can then use:

```bash
$APP_TOKEN
```

without knowing that the value originated from a GitHub repository secret.

---

# Task 11 — Job-Level Environment Variables

## Objective

Learn how to define an environment variable at the job level so that all steps in that job can access it.

---

# Job-Level Environment Variable

Example:

```yaml
jobs:
  config:
    runs-on: ubuntu-latest

    env:
      APP_ENV: lab

    steps:
      - name: Show environment
        run: |
          echo "Application environment: $APP_ENV"

      - name: Use environment
        run: |
          echo "Running application in $APP_ENV environment"
```

The variable is defined once:

```yaml
env:
  APP_ENV: lab
```

and is available to all steps within the job.

---

# Scope

The scope is:

```text
config job
│
├── APP_ENV = lab
│
├── Step 1
│   └── $APP_ENV
│
└── Step 2
    └── $APP_ENV
```

Both steps can access:

```bash
$APP_ENV
```

---

# Why Job-Level Environment Variables Are Useful

Without a job-level variable, the same value might need to be repeated:

```yaml
- name: Step 1
  env:
    APP_ENV: lab

- name: Step 2
  env:
    APP_ENV: lab
```

Instead, define it once:

```yaml
jobs:
  config:
    env:
      APP_ENV: lab
```

This is cleaner when multiple steps use the same configuration value.

---

# Branch Filtering

The Task 11 workflow was configured to run on pushes to branches other than `main`.

One approach is:

```yaml
on:
  push:
    branches:
      - "**"
      - "!main"
```

The pattern:

```text
**
```

matches all branches.

The pattern:

```text
!main
```

excludes `main`.

Therefore:

```text
feature/task-11 → RUN
feature/task-12 → RUN
main            → NO RUN
```

---

# Alternative: `branches-ignore`

If the requirement is simply:

> Run on every branch except main.

Use:

```yaml
on:
  push:
    branches-ignore:
      - main
```

This is often clearer for a simple exclusion.

---

# `branches` vs `branches-ignore`

Do not define both for the same event filter.

This should not be used:

```yaml
on:
  push:
    branches:
      - "**"

    branches-ignore:
      - main
```

Instead, choose one approach.

### Inclusion/exclusion patterns

```yaml
branches:
  - "**"
  - "!main"
```

### Simple exclusion

```yaml
branches-ignore:
  - main
```

---

# Task 12 — Step-Level Environment Override

## Objective

Learn how a step-level environment variable can override a job-level variable for one specific step.

---

# Job-Level Variable

The job defines:

```yaml
env:
  APP_ENV: lab
```

Therefore the default value is:

```text
APP_ENV = lab
```

---

# Step-Level Override

A step can define the same variable name:

```yaml
- name: Override
  env:
    APP_ENV: Test
  run: |
    echo "Step_var: $APP_ENV"
```

The same variable exists at two levels:

```text
Job:
APP_ENV = lab

Step:
APP_ENV = Test
```

The step-level value has higher precedence for that step.

---

# Complete Experiment

```yaml
name: ci_1

on:
  push:
    branches:
      - "**"
      - "!main"

jobs:
  config:
    runs-on: ubuntu-latest

    env:
      APP_ENV: lab

    steps:
      - name: Default
        run: |
          echo "Job_var: $APP_ENV"

      - name: Override
        env:
          APP_ENV: Test
        run: |
          echo "Step_var: $APP_ENV"

      - name: After Override
        run: |
          echo "APP_ENV: $APP_ENV"
```

Expected result:

```text
Job_var: lab
Step_var: Test
APP_ENV: lab
```

---

# What Is Actually Happening?

The step-level value does not modify the job-level value.

Instead, the more specific scope takes precedence while that step is executing.

Think of it as:

```text
Job
APP_ENV = lab
│
├── Step 1
│   └── sees lab
│
├── Step 2
│   ├── job value = lab
│   ├── step value = Test
│   └── sees Test
│
└── Step 3
    └── sees lab
```

The job-level variable remains:

```text
APP_ENV = lab
```

throughout the job.

The step temporarily sees:

```text
APP_ENV = Test
```

because the step-level definition has higher precedence.

---

# Environment Variable Scope Summary

The lab has now demonstrated different environment variable scopes.

Conceptually:

```text
Workflow
    │
    ▼
Job
    │
    ▼
Step
```

A more specific scope can override a broader scope.

Example:

```yaml
# Job
env:
  APP_ENV: lab
```

Then:

```yaml
# Step
env:
  APP_ENV: test
```

The step sees:

```text
test
```

while other steps continue to see:

```text
lab
```

---

# Tasks 7–12 Quick Reference

| Task | Topic | Main Concept |
|------|-------|--------------|
| 7 | Job Outputs | Pass values between jobs |
| 8 | Artifacts | Preserve/pass files |
| 9 | Caching | Reuse data between runs |
| 10 | Secrets | Secure sensitive configuration |
| 11 | Job-level Environment | Share configuration across job steps |
| 12 | Step-level Override | Override job configuration for one step |

---

# Core Concepts Learned

## 1. Step Outputs

```yaml
id: generate_version
```

combined with:

```yaml
echo "name=value" >> "$GITHUB_OUTPUT"
```

creates a step output.

Reference:

```yaml
${{ steps.generate_version.outputs.name }}
```

---

## 2. Job Outputs

Expose a step output:

```yaml
outputs:
  app_version: ${{ steps.generate_version.outputs.step_version }}
```

Consume from another job:

```yaml
${{ needs.build.outputs.app_version }}
```

---

## 3. Artifacts

Upload:

```yaml
uses: actions/upload-artifact@v4
```

Download:

```yaml
uses: actions/download-artifact@v5
```

Use artifacts for files that need to be preserved or passed around.

---

## 4. Caching

```yaml
uses: actions/cache@v4
```

A cache is identified by a key:

```yaml
key: dependencies-${{ runner.os }}
```

Same key:

```text
Potential cache HIT
```

New key:

```text
Cache MISS → new cache
```

Use caching primarily to improve workflow performance.

---

## 5. Secrets

Access:

```yaml
${{ secrets.SECRET_NAME }}
```

Map to an environment variable:

```yaml
env:
  APP_TOKEN: ${{ secrets.SECRET_NAME }}
```

GitHub masks secret values in workflow logs.

---

## 6. Environment Variables

Job-level:

```yaml
jobs:
  build:
    env:
      APP_ENV: lab
```

Step-level:

```yaml
- name: Example
  env:
    APP_ENV: test
```

A more specific environment scope can override a broader scope.

---

# Artifact vs Cache vs Secret vs Output

These concepts can initially look similar because they all allow information to move through or around a workflow.

They serve different purposes.

| Feature | Used For | Example |
|---------|----------|---------|
| Step Output | Passing a value within a job | `version=1.0.10` |
| Job Output | Passing a value between jobs | `app_version` |
| Artifact | Preserving/passing files | `application.zip` |
| Cache | Reusing data between runs | Dependencies |
| Secret | Protecting sensitive values | API token |
| Environment Variable | Supplying configuration to commands | `APP_ENV=prod` |

A useful mental model:

```text
Small value
    ↓
Step/Job Output

File
    ↓
Artifact

Reusable data
    ↓
Cache

Sensitive value
    ↓
Secret

Runtime configuration
    ↓
Environment Variable
```

---

# Lab Method Going Forward

The GitHub Actions Lab uses an **isolated-task approach**.

Each new task should:

1. Focus on one primary concept.
2. Use the smallest workflow necessary.
3. Experiment with the behavior.
4. Understand why it works.
5. Document the important lesson.
6. Move on.

Previous concepts should **not** automatically be carried into every new workflow.

For example:

```text
Task 8
Artifact experiment
```

should not necessarily contain:

```text
Caching
Secrets
Environment overrides
Job outputs
```

unless those concepts are specifically needed.

---

# Future Capstone

The individual tasks will eventually be combined into a more realistic CI/CD workflow.

For example:

```text
Test
  │
  ▼
Build
  │
  ├── Job Output → Application Version
  │
  ├── Cache → Dependencies
  │
  └── Artifact → Build Package
          │
          ▼
       Deploy
          │
          └── Secret → Deployment Credential
```

The capstone workflow will intentionally combine the concepts after they have been learned independently.

---

# Key Takeaways from Tasks 7–12

## Task 7

> Job outputs allow values to move between jobs.

## Task 8

> Artifacts preserve and transfer files produced by workflows.

## Task 9

> Caches allow reusable data to be restored across workflow runs.

## Task 10

> Secrets provide a secure way to supply sensitive values to workflows.

## Task 11

> Job-level environment variables are available to all steps in that job.

## Task 12

> Step-level environment variables can override job-level values for that step without modifying the job-level value.

---

# Current Lab Status

```text
Task 7  — Job Outputs                  ✅
Task 8  — Artifacts                    ✅
Task 9  — Caching                      ✅
Task 10 — Secrets                      ✅
Task 11 — Job-level Environment        ✅
Task 12 — Step-level Override          ✅
```

The lab will continue with the same isolated-task approach for future GitHub Actions concepts.
```