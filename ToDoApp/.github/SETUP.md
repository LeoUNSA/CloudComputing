# GitHub Actions CI/CD Setup Guide

Quick reference for setting up GitHub Actions for this project.

## Overview

- **CI**: Automatic build/test on every push/PR
- **CD**: Automatic deploy to GKE on push to main
- **Cleanup**: Manual workflow to destroy all GCP resources

## Quick Setup

### 1. Create GCP Service Account

```bash
# Create service account
gcloud iam service-accounts create github-actions-deployer \
  --display-name="GitHub Actions Deployer" \
  --project=todoapp-autoscaling-demo

# Grant necessary roles
gcloud projects add-iam-policy-binding todoapp-autoscaling-demo \
  --member="serviceAccount:github-actions-deployer@todoapp-autoscaling-demo.iam.gserviceaccount.com" \
  --role="roles/container.admin"

gcloud projects add-iam-policy-binding todoapp-autoscaling-demo \
  --member="serviceAccount:github-actions-deployer@todoapp-autoscaling-demo.iam.gserviceaccount.com" \
  --role="roles/compute.admin"

gcloud projects add-iam-policy-binding todoapp-autoscaling-demo \
  --member="serviceAccount:github-actions-deployer@todoapp-autoscaling-demo.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding todoapp-autoscaling-demo \
  --member="serviceAccount:github-actions-deployer@todoapp-autoscaling-demo.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# Create JSON key
gcloud iam service-accounts keys create ~/gcp-key.json \
  --iam-account=github-actions-deployer@todoapp-autoscaling-demo.iam.gserviceaccount.com

# Display key (for copying)
cat ~/gcp-key.json
```

### 2. Add GitHub Secret

**Option A: Via GitHub CLI**
```bash
gh secret set GCP_SA_KEY < ~/gcp-key.json
gh secret list
```

**Option B: Via GitHub UI**
1. Go to repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `GCP_SA_KEY`
4. Value: Paste entire content of `~/gcp-key.json`
5. Click "Add secret"

### 3. Enable Workflows

Workflows are already configured in `.github/workflows/`:
- ✅ `ci.yml` - Runs on every push/PR
- ✅ `deploy-gcp.yml` - Runs on push to main (or manual)
- ✅ `cleanup-gcp.yml` - Manual only

Just push to trigger!

## Using the Workflows

### Automatic CI (on every push/PR)
```bash
git add .
git commit -m "Your changes"
git push
```

CI will automatically:
- Build backend and frontend
- Run tests
- Validate Kubernetes manifests
- Validate Ansible playbooks
- Run security scanning

### Automatic Deployment (on push to main)
```bash
git push origin main
```

CD will automatically:
- Deploy to GKE using Ansible
- Build and push images to GCR
- Deploy app with Helm
- Run smoke tests
- Display external IP

### Manual Deployment
```bash
# Via GitHub CLI
gh workflow run deploy-gcp.yml

# Or via GitHub UI:
# Actions → Deploy to GCP → Run workflow
```

### Manual Cleanup
```bash
# Via GitHub CLI
gh workflow run cleanup-gcp.yml -f confirm=destroy

# Or via GitHub UI:
# Actions → Cleanup → Run workflow → Type "destroy"
```

## Environment Protection (Optional)

Add deployment approvals:

1. Go to Settings → Environments
2. Create environment: `prod`
3. Add required reviewers
4. Now deployments to prod require approval

## Monitoring

**View workflow runs:**
```bash
gh run list
gh run view <run-id>
gh run watch  # Watch current run
```

**Check deployment status:**
```bash
# After deployment completes
kubectl get all -n todoapp
kubectl get svc todoapp-frontend -n todoapp
```

## Troubleshooting

### "Bad credentials" error
```bash
# Re-create and set the secret
gcloud iam service-accounts keys create ~/gcp-key-new.json \
  --iam-account=github-actions-deployer@todoapp-autoscaling-demo.iam.gserviceaccount.com

gh secret set GCP_SA_KEY < ~/gcp-key-new.json
```

### "Permission denied" error
```bash
# Verify service account has required roles
gcloud projects get-iam-policy todoapp-autoscaling-demo \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:github-actions-deployer*"
```

### Deployment takes too long
- Check GCP quotas
- Verify billing is enabled
- Check GKE cluster creation status in GCP Console

## Complete Example

```bash
# 1. Setup (one-time)
# Create service account and get key
gcloud iam service-accounts create github-actions-deployer --project=todoapp-autoscaling-demo
# ... (run all commands from "Quick Setup" section) ...
gh secret set GCP_SA_KEY < ~/gcp-key.json

# 2. Development workflow
git checkout -b feature/my-feature
# ... make changes ...
git add .
git commit -m "Add feature"
git push origin feature/my-feature  # ← Triggers CI

# 3. Create PR and merge
gh pr create --title "My feature" --body "Description"
gh pr merge  # ← Triggers CD on main

# 4. Verify deployment
gh run watch
kubectl get svc todoapp-frontend -n todoapp

# 5. Cleanup when done
gh workflow run cleanup-gcp.yml -f confirm=destroy
```

## Security Best Practices

1. **Use least privilege:** Only grant necessary IAM roles
2. **Rotate keys:** Regularly rotate service account keys
3. **Use environments:** Require approvals for production
4. **Monitor logs:** Check workflow logs for suspicious activity
5. **Protected branches:** Require PR reviews for main branch

## Cost Management

To avoid unexpected charges:

1. **Always cleanup:** Run cleanup workflow after testing
2. **Set budget alerts:** Configure in GCP Console
3. **Monitor costs:** Check billing dashboard regularly
4. **Use schedules:** Consider scheduled cleanup workflows

Example scheduled cleanup (every Sunday):
```yaml
on:
  schedule:
    - cron: '0 0 * * 0'  # Every Sunday at midnight
```

## Next Steps

- ✅ Service account created
- ✅ Secret configured
- ✅ Workflows enabled
- ⏭️ Push code to trigger CI
- ⏭️ Merge to main to deploy
- ⏭️ Monitor workflow runs
- ⏭️ Cleanup when done

For detailed documentation, see: [ANSIBLE-DEPLOYMENT.md](ANSIBLE-DEPLOYMENT.md#cicd-integration-with-github-actions)
