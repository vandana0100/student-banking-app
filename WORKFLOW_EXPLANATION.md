# CI/CD Pipeline Workflow Explanation

## Overview
This workflow automates the complete CI/CD process: testing, building Docker images, pushing to GitHub Container Registry (GHCR), and updating the GitOps repository with new image tags.

## Workflow Structure

### Environment Variables (Top Level)
```yaml
env:
  REGISTRY: ghcr.io
  IMAGE_PREFIX: vandana0100/student-banking-app
  GITOPS_REPO: vandana0100/module_6_part3gitops
```
**Purpose:** Centralized configuration for container registry, image naming, and GitOps repository. All values are lowercase as required by GHCR.

### Trigger Events
```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```
**Purpose:** Runs on every push to main branch and on pull requests targeting main.

---

## Job 1: `test-backend`

### Purpose
Runs automated tests to ensure code quality before building and deploying images.

### Key Components:

#### Services Section
```yaml
services:
  mongo:
    image: mongo:latest
    ports:
      - 27017:27017
```
**Purpose:** Starts a MongoDB container service that runs alongside the test job. This provides a real database for testing (though tests use mongomock, this ensures environment parity).

#### Steps Breakdown:

1. **Checkout code**
   - Downloads the repository code to the GitHub Actions runner

2. **Set up Python**
   - Installs Python 3.10 environment

3. **Install backend dependencies**
   - Installs all required Python packages from requirements.txt
   - Installs pytest for running tests

4. **Run backend tests**
   - Executes pytest to run all test files in the backend/tests directory
   - Uses MongoDB connection string pointing to the service container

---

## Job 2: `build-and-push`

### Purpose
Builds Docker images for all three microservices and pushes them to GitHub Container Registry.

### Dependencies
- `needs: test-backend` - Only runs if tests pass
- `if: github.event_name == 'push'` - Only runs on push events, not pull requests

### Permissions
```yaml
permissions:
  contents: read
  packages: write
```
**Purpose:** Grants permission to read repository contents and write packages to GHCR.

### Steps Breakdown:

1. **Checkout code**
   - Gets the source code

2. **Set up Docker Buildx**
   - Installs Docker Buildx for advanced build features (multi-platform support, caching)

3. **Log in to GitHub Container Registry**
   - Authenticates using the `CR_PAT` secret (Container Registry Personal Access Token)
   - This token has permissions: Repo, workflow, and write:packages

4. **Extract metadata for backend**
   - Generates Docker image tags automatically:
     - Branch name tag
     - SHA-based tag (includes commit hash)
     - `latest` tag (only on default branch)

5. **Build and push backend image**
   - Builds Docker image from `./backend/Dockerfile`
   - Pushes to: `ghcr.io/vandana0100/student-banking-app-backend:latest`

6-9. **Repeat for transactions and studentportfolio**
   - Same process for the other two services

10. **Output image tags**
   - Saves image tags to environment variables for use in next job

---

## Job 3: `update-gitops`

### Purpose
Updates the GitOps repository's Kubernetes manifests with the newly built image tags, enabling automated deployment.

### Dependencies
- `needs: build-and-push` - Only runs after images are successfully built
- `if: github.event_name == 'push'` - Only on push events

### Steps Breakdown:

1. **Checkout GitOps repository**
   - Clones the `module_6_part3gitops` repository
   - Uses `GITOPS_REPO` secret for authentication
   - Checks out to `gitops/` directory

2. **Update backend deployment image**
   - Uses `sed` command to find and replace the image tag in `backend-deployment.yaml`
   - Updates to: `ghcr.io/vandana0100/student-banking-app-backend:latest`

3. **Update transactions deployment image**
   - Same process for transactions service

4. **Update studentportfolio deployment image**
   - Same process for studentportfolio service

5. **Configure Git**
   - Sets Git user name and email for commits (uses GitHub Actions bot identity)

6. **Commit and push to GitOps repository**
   - Stages all modified YAML files
   - Commits with message "Update image tags from CI/CD pipeline [skip ci]"
   - The `[skip ci]` prevents infinite loops (GitOps updates shouldn't trigger CI again)
   - Pushes changes to the GitOps repository

---

## Key Concepts

### Why Three Jobs?
- **Separation of Concerns:** Testing, building, and deployment are separate concerns
- **Efficiency:** If tests fail, we don't waste time building images
- **Dependency Management:** Each job only runs when prerequisites succeed

### Why GitOps?
- **Version Control:** All deployment configurations are versioned
- **Automation:** GitOps tools (like ArgoCD) can automatically sync changes
- **Audit Trail:** Every deployment change is tracked in Git history

### Image Tagging Strategy
- `latest` tag: Always points to the most recent successful build on main branch
- SHA-based tags: Provide immutable references to specific commits
- Branch tags: Allow testing different branches

### Security
- Secrets (`CR_PAT`, `GITOPS_REPO`) are stored securely in GitHub Secrets
- Never exposed in logs or code
- Only accessible to the workflow during execution

---

## Workflow Flow Diagram

```
Push to main branch
    ↓
[Job 1: test-backend]
    ↓ (if tests pass)
[Job 2: build-and-push]
    ├─ Build backend image → Push to GHCR
    ├─ Build transactions image → Push to GHCR
    └─ Build studentportfolio image → Push to GHCR
    ↓ (if builds succeed)
[Job 3: update-gitops]
    ├─ Update backend-deployment.yaml
    ├─ Update transactions-deployment.yaml
    ├─ Update studentportfolio-deployment.yaml
    └─ Commit & Push to GitOps repo
    ↓
GitOps tool (ArgoCD/Flux) detects changes
    ↓
Automatically deploys new images to Kubernetes
```

---

## Important Notes

1. **All repository names and usernames are lowercase** - Required by GHCR
2. **Secrets must be configured** in repository settings before workflow runs
3. **GitOps repository must exist** and be accessible with `GITOPS_REPO` token
4. **Workflow only runs on push to main** - Prevents unnecessary builds on PRs
5. **`[skip ci]` in commit message** prevents infinite CI loops

