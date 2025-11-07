# Required GCP Permissions for GitHub Actions

## Service Account Permissions

The GitHub Actions service account `github-actions-deployer@todoapp-autoscaling-demo.iam.gserviceaccount.com` requires the following permissions:

### Required APIs to Enable
Before running the workflows, ensure these APIs are enabled in your GCP project:
```bash
gcloud services enable serviceusage.googleapis.com --project=todoapp-autoscaling-demo
gcloud services enable cloudresourcemanager.googleapis.com --project=todoapp-autoscaling-demo
gcloud services enable compute.googleapis.com --project=todoapp-autoscaling-demo
gcloud services enable container.googleapis.com --project=todoapp-autoscaling-demo
gcloud services enable containerregistry.googleapis.com --project=todoapp-autoscaling-demo
gcloud services enable artifactregistry.googleapis.com --project=todoapp-autoscaling-demo
```

### Required IAM Roles

Grant these roles to the service account:

```bash
# Kubernetes Engine Admin - to create and manage GKE clusters
gcloud projects add-iam-policy-binding todoapp-autoscaling-demo \
  --member="serviceAccount:github-actions-deployer@todoapp-autoscaling-demo.iam.gserviceaccount.com" \
  --role="roles/container.admin"

# Compute Network Admin - to create VPC and subnets
gcloud projects add-iam-policy-binding todoapp-autoscaling-demo \
  --member="serviceAccount:github-actions-deployer@todoapp-autoscaling-demo.iam.gserviceaccount.com" \
  --role="roles/compute.networkAdmin"

# Storage Admin - to push Docker images to GCR/Artifact Registry
gcloud projects add-iam-policy-binding todoapp-autoscaling-demo \
  --member="serviceAccount:github-actions-deployer@todoapp-autoscaling-demo.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# Service Usage Admin - to enable APIs programmatically (optional)
gcloud projects add-iam-policy-binding todoapp-autoscaling-demo \
  --member="serviceAccount:github-actions-deployer@todoapp-autoscaling-demo.iam.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageAdmin"

# Artifact Registry Writer - to push to Artifact Registry
gcloud projects add-iam-policy-binding todoapp-autoscaling-demo \
  --member="serviceAccount:github-actions-deployer@todoapp-autoscaling-demo.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"
```

## Common Errors and Solutions

### Error: "Permission denied on resource"
**Solution**: Ensure all required APIs are enabled and IAM roles are granted to the service account.

### Error: "Service Usage API has not been used"
**Solution**: Enable the Service Usage API manually in the GCP Console or via gcloud CLI.

### Error: "artifactregistry.repositories.uploadArtifacts denied"
**Solution**: Grant the `roles/storage.admin` or `roles/artifactregistry.writer` role to the service account.

## Verification

To verify the service account has the correct permissions:

```bash
# List all IAM policy bindings for the service account
gcloud projects get-iam-policy todoapp-autoscaling-demo \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:github-actions-deployer@todoapp-autoscaling-demo.iam.gserviceaccount.com"

# Check enabled APIs
gcloud services list --enabled --project=todoapp-autoscaling-demo
```

## Note

The Ansible playbooks are configured with `ignore_errors: true` for tasks that may fail due to permission issues. This allows the deployment to continue even if some operations fail. However, for full functionality, all the above permissions should be granted.
