# Ansible Deployment Guide

This guide shows how to deploy and destroy the entire TodoApp infrastructure on GCP using Ansible.

## Prerequisites

1. **Install Ansible**:
   ```bash
   # On Arch Linux
   sudo pacman -S ansible
   
   # On Ubuntu/Debian
   sudo apt install ansible
   
   # Via pip
   pip install ansible
   ```

2. **Install and configure gcloud CLI**:
   ```bash
   # Install gcloud (if not already installed)
   # Follow: https://cloud.google.com/sdk/docs/install
   
   # Authenticate
   gcloud auth login
   
   # Set your project
   gcloud config set project todoapp-autoscaling-demo
   
   # Enable billing (required for GKE)
   # Visit: https://console.cloud.google.com/billing
   ```

3. **Install kubectl and helm**:
   ```bash
   # kubectl
   gcloud components install kubectl
   
   # helm
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
   ```

4. **Install Docker** (for building images):
   ```bash
   # On Arch Linux
   sudo pacman -S docker
   sudo systemctl start docker
   
   # On Ubuntu/Debian
   sudo apt install docker.io
   sudo systemctl start docker
   ```

## Configuration

The deployment is configured via `ansible/inventories/gcp/group_vars/all.yml`.

Key variables:
- `gcp_project_id`: Your GCP project ID (default: `todoapp-autoscaling-demo`)
- `gcp_region`: GCP region (default: `us-central1`)
- `gcp_zone`: GCP zone (default: `us-central1-a`)
- `gke_cluster_name`: Name of the GKE cluster (default: `todoapp-autoscaling-cluster`)

You can override these by:
1. Editing `ansible/inventories/gcp/group_vars/all.yml`
2. Setting environment variables (e.g., `export GCP_PROJECT_ID=my-project`)
3. Passing `-e` flags to ansible-playbook

## Deploy Everything

Deploy the complete stack (GKE cluster, networking, images, application, HPA):

```bash
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml
```

**What this does:**
1. Enables required GCP APIs (compute, container, container registry)
2. Creates VPC network and subnet
3. Creates GKE cluster with autoscaling enabled (2-10 nodes)
4. Configures kubectl context
5. Builds Docker images (backend, frontend)
6. Pushes images to Google Container Registry (GCR)
7. Installs metrics-server (if needed)
8. Deploys the TodoApp via Helm with HPA configured
9. Waits for all pods to be ready
10. Displays the LoadBalancer external IP

**Estimated time:** 8-12 minutes (cluster creation is the slowest part)

### Verbose output

For detailed logs:
```bash
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml -v
```

For very detailed debugging:
```bash
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml -vvv
```

### Dry-run / Check mode

To see what would be changed without actually making changes:
```bash
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml --check
```

**Note:** `--check` mode has limitations with shell/command tasks (they won't execute), so it's not 100% accurate but useful for validation.

## Destroy Everything

Delete the GKE cluster, network, and all associated resources:

```bash
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/cleanup.yml
```

**What this does:**
1. Asks for confirmation (type `yes` to proceed)
2. Deletes the Helm release (todoapp)
3. Deletes the Kubernetes namespace
4. Deletes the GKE cluster
5. Deletes the subnet
6. Deletes the VPC network

**Estimated time:** 3-5 minutes

### Force cleanup without confirmation

If you want to skip the interactive confirmation (useful for CI/CD):

```bash
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/cleanup.yml -e "confirm_user_input=yes"
```

Or modify the playbook to remove the pause task.

## Verify Deployment

After deployment completes, verify the resources:

```bash
# Check cluster
gcloud container clusters list --project=todoapp-autoscaling-demo

# Get kubectl credentials (if not already set)
gcloud container clusters get-credentials todoapp-autoscaling-cluster \
  --zone=us-central1-a \
  --project=todoapp-autoscaling-demo

# Check pods
kubectl get pods -n todoapp

# Check services (get external IP)
kubectl get svc -n todoapp

# Check HPA
kubectl get hpa -n todoapp

# Check nodes
kubectl get nodes
```

## Access the Application

After deployment, get the external IP:

```bash
kubectl get svc todoapp-frontend -n todoapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Access the application:
```
http://<EXTERNAL_IP>:3000
```

## Customize Deployment

### Change project ID

```bash
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml \
  -e "gcp_project_id=my-custom-project"
```

### Change cluster size

Edit `ansible/inventories/gcp/group_vars/all.yml`:
```yaml
gke_node_pool:
  min_node_count: 3
  max_node_count: 20
```

### Change autoscaling settings

Edit `ansible/inventories/gcp/group_vars/all.yml`:
```yaml
autoscaling:
  backend:
    min_replicas: 3
    max_replicas: 15
    target_cpu_utilization: 60
```

## Troubleshooting

### Authentication errors
```bash
gcloud auth login
gcloud config set project todoapp-autoscaling-demo
```

### Billing not enabled
Visit: https://console.cloud.google.com/billing and link billing to your project.

### Cluster already exists
If you get "already exists" errors, either:
1. Run cleanup first: `ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/cleanup.yml`
2. The playbook is idempotent — it will skip resources that already exist

### View Ansible logs
Add `-vvv` for very verbose output to debug issues.

## CI/CD Integration with GitHub Actions

This project includes complete GitHub Actions workflows for continuous integration and deployment.

### Available Workflows

Three workflows are configured in `.github/workflows/`:

1. **`ci.yml`** - Continuous Integration (runs on every push/PR)
2. **`deploy-gcp.yml`** - Continuous Deployment to GCP (runs on push to main)
3. **`cleanup-gcp.yml`** - Manual cleanup workflow (manual trigger only)

### Setup Instructions

#### Step 1: Create GCP Service Account

1. Go to [GCP Console](https://console.cloud.google.com/) → IAM & Admin → Service Accounts
2. Create a new service account: `github-actions-deployer`
3. Grant the following roles:
   - **Kubernetes Engine Admin** (`roles/container.admin`)
   - **Compute Admin** (`roles/compute.admin`)
   - **Service Account User** (`roles/iam.serviceAccountUser`)
   - **Storage Admin** (`roles/storage.admin`) - for GCR

4. Create a JSON key for this service account:
   ```bash
   gcloud iam service-accounts keys create ~/gcp-key.json \
     --iam-account=github-actions-deployer@todoapp-autoscaling-demo.iam.gserviceaccount.com
   ```

#### Step 2: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following secrets:

1. **`GCP_SA_KEY`** (Required)
   - Copy the entire content of the JSON key file
   - This is used for authentication

2. **`GCP_SA_KEY_FILE`** (Optional, for advanced use)
   - Same as GCP_SA_KEY, used in some contexts

Example using GitHub CLI:
```bash
# Set GCP_SA_KEY
gh secret set GCP_SA_KEY < ~/gcp-key.json

# Verify
gh secret list
```

#### Step 3: Configure GitHub Environments (Optional)

For better control and approvals:

1. Go to Settings → Environments
2. Create environments: `dev`, `prod`, `cleanup`
3. Configure protection rules:
   - **dev**: No restrictions
   - **prod**: Require reviewers before deployment
   - **cleanup**: Require reviewers (prevents accidental deletion)

### Workflow Details

#### 1. CI Workflow (`ci.yml`)

**Trigger:** Every push or pull request to `main` or `develop` branches

**What it does:**
- ✅ Builds and tests backend (Node.js)
- ✅ Builds and tests frontend (React)
- ✅ Validates Kubernetes manifests with Helm lint
- ✅ Validates Ansible playbooks (syntax check + ansible-lint)
- ✅ Runs security scanning with Trivy
- ✅ Builds Docker images and runs basic smoke tests

**Example run:**
```bash
# This runs automatically on every push/PR
# Check: https://github.com/<your-repo>/actions
```

**Manual trigger:**
```bash
# Push to trigger
git push origin main
```

#### 2. Deploy Workflow (`deploy-gcp.yml`)

**Trigger:** 
- Automatic: Push to `main` branch
- Manual: Via GitHub Actions UI (workflow_dispatch)

**What it does:**
- 🚀 Deploys complete infrastructure with Ansible
- 🏗️ Creates GKE cluster, VPC, subnet
- 🐳 Builds and pushes images to GCR
- ⚙️ Deploys application via Helm
- 🔍 Runs smoke tests
- 📊 Creates deployment summary

**Manual trigger via UI:**
1. Go to Actions → Deploy to GCP → Run workflow
2. Select branch and environment (dev/prod)
3. Click "Run workflow"

**Manual trigger via CLI:**
```bash
gh workflow run deploy-gcp.yml
```

**Deployment summary:** Check the workflow run for:
- External IP address
- Resource status
- Smoke test results

#### 3. Cleanup Workflow (`cleanup-gcp.yml`)

**Trigger:** Manual only (workflow_dispatch)

**What it does:**
- 🧹 Destroys all GCP resources
- ❌ Deletes GKE cluster
- ❌ Deletes VPC network and subnet
- ❌ Deletes orphaned resources (load balancers, disks)
- 💰 Verifies no resources are left incurring costs

**Manual trigger via UI:**
1. Go to Actions → Cleanup - Destroy GCP Resources
2. Click "Run workflow"
3. **Type `destroy`** in the confirmation field
4. Click "Run workflow"

**Manual trigger via CLI:**
```bash
gh workflow run cleanup-gcp.yml -f confirm=destroy
```

**Safety features:**
- ⚠️ Requires typing "destroy" to confirm
- 🛡️ Can require approval if using protected environments
- 📊 Generates cleanup summary
- 💰 Verifies all resources are deleted

### Customizing Workflows

#### Change GCP project or region

Edit the workflow files (`.github/workflows/*.yml`) and update the `env` section:

```yaml
env:
  GCP_PROJECT_ID: your-project-id
  GCP_REGION: europe-west1
  GCP_ZONE: europe-west1-b
  CLUSTER_NAME: your-cluster-name
```

Or use repository variables (Settings → Secrets and variables → Variables):
- `GCP_PROJECT_ID`
- `GCP_REGION`
- `GCP_ZONE`

Then reference them in workflows:
```yaml
env:
  GCP_PROJECT_ID: ${{ vars.GCP_PROJECT_ID }}
```

#### Add notifications

Add a notification step to workflows:

**Slack notification:**
```yaml
- name: Notify Slack
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Deployment to GKE completed'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
  if: always()
```

**Email notification:**
GitHub automatically sends emails on workflow failures if enabled in your account settings.

### Monitoring Workflows

**View workflow runs:**
```bash
# List recent workflow runs
gh run list

# View specific run
gh run view <run-id>

# Watch a running workflow
gh run watch
```

**Check logs:**
1. Go to Actions tab in GitHub
2. Click on a workflow run
3. Expand job steps to see logs

### Troubleshooting CI/CD

#### Authentication errors

```bash
# Verify service account has correct permissions
gcloud projects get-iam-policy todoapp-autoscaling-demo \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:github-actions-deployer*"
```

#### Workflow fails at deployment step

- Check GCP quotas: https://console.cloud.google.com/iam-admin/quotas
- Verify billing is enabled
- Check service account permissions
- Review workflow logs for specific errors

#### Secrets not found

```bash
# List configured secrets
gh secret list

# Update a secret
gh secret set GCP_SA_KEY < ~/gcp-key.json
```

### Best Practices

1. **Use protected branches:** Require PR reviews before merging to `main`
2. **Use environments:** Set up approval gates for production deployments
3. **Monitor costs:** Check GCP billing after each deployment
4. **Clean up regularly:** Run cleanup workflow when not using the cluster
5. **Review logs:** Check workflow logs for warnings or optimization opportunities
6. **Pin versions:** Use specific versions for actions (e.g., `@v4` instead of `@latest`)

### Example Workflow

Complete development cycle:

```bash
# 1. Create feature branch
git checkout -b feature/new-endpoint

# 2. Make changes
# ... edit code ...

# 3. Commit and push (triggers CI)
git add .
git commit -m "Add new endpoint"
git push origin feature/new-endpoint

# 4. CI runs automatically (build, test, validate)
# Check: https://github.com/<your-repo>/actions

# 5. Create PR and merge to main
gh pr create --title "Add new endpoint" --body "Description"

# 6. After merge, CD deploys automatically to GKE
# Deployment runs on main branch

# 7. Access the deployed app
kubectl get svc todoapp-frontend -n todoapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# 8. When done testing, destroy resources
# Go to Actions → Cleanup workflow → Run manually
```

## Comparison with Shell Scripts

This repository also includes shell scripts (`scripts/full-deploy.sh`, etc.) for local Kind-based deployments.

**When to use Ansible:**
- Deploying to GCP/GKE
- CI/CD pipelines
- Production or demo environments
- Need for idempotency and declarative infrastructure

**When to use shell scripts:**
- Local development with Kind
- Quick testing
- Simpler local setup without cloud resources

## Next Steps

After deployment:
1. Run load tests to trigger autoscaling: See `docs/05-MANUAL-AUTOSCALING-TEST.md`
2. Monitor metrics: Check HPA and cluster autoscaler behavior
3. View Prometheus metrics (if monitoring is enabled)
4. Test the application: Add/remove tasks via the web UI

## Clean Up

Always remember to destroy resources when done to avoid GCP charges:

```bash
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/cleanup.yml
```
