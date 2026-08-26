# recipes-aws-infra

Terraform + GitHub Actions for the AWS infrastructure behind the `recipes` project: an EKS cluster (the app platform), the OIDC/IAM roles GitHub Actions assumes to manage it, and a standalone self-hosted CI runner.

The actual Kubernetes-side GitOps config (Argo CD Applications, Helm charts, manifests) lives in a separate repo: [`recipes-gitops`](https://github.com/sami-nyx/recipes-gitops), applied by `bootstrap.sh` after the cluster comes up.

## Layout

```
terraform/
  eks-platform/       # The EKS cluster itself: VPC, subnets, node group, IRSA roles, Loki S3 bucket
  oidc-roles/         # IAM roles GitHub Actions assumes via OIDC (no long-lived AWS keys in CI)
  self-hosted-runner/ # One EC2 instance running a self-hosted GitHub Actions runner

.github/
  workflows/
    tf-apply-eks.yaml       # workflow_dispatch: terraform apply -> bootstrap the cluster via recipes-gitops
    destroy-cluster.yaml    # workflow_dispatch: tear the cluster + its Argo CD apps down, then terraform destroy
    eks-platform.yaml       # CI: fmt/init/validate on push + PR touching terraform/eks-platform
    oidc-roles.yaml         # CI: same, for terraform/oidc-roles
    self-hosted-runner.yaml # CI: same, for terraform/self-hosted-runner
  actions/tf-offline-test/  # Composite action shared by the three CI workflows above
```

## Terraform stacks

Each stack is independent: its own S3 backend, its own state file, applied separately. None of them share a `terraform apply` run.

| Stack | Backend bucket | What it creates |
|---|---|---|
| `eks-platform` | `tf-state-bucket-eks-platform-recipes` | VPC/subnets (public-only or public+private+NAT, via `nodes_in_public`), the EKS cluster and managed node group, IRSA roles for External Secrets/EBS CSI/Loki, the Loki S3 bucket |
| `oidc-roles` | `tf-state-bucket-gh-actions-oidc-roles` | The GitHub Actions OIDC provider trust + IAM roles: `github-actions-terraform` (applies `eks-platform`), `github-actions-bootstrap` (runs `bootstrap.sh` against the cluster), plus per-repo push roles for ECR/S3/CloudFront |
| `self-hosted-runner` | `tf-state-bucket-self-hosted-runner-protfolio` | A standalone EC2 instance registered as a self-hosted GitHub Actions runner |

Each stack's `terraform.tfvars` is generated at CI time from `terraform.tfvars.template` via `envsubst`, populated from the GitHub variables/secrets listed below — it's never committed (see `.gitignore`).

## Workflows

- **`tf-apply-eks.yaml`** (`workflow_dispatch`) — applies `eks-platform`, then checks out `recipes-gitops` and runs its `bootstrap.sh` against the new cluster (installs External Secrets Operator + Argo CD, points Argo CD at the GitOps repo). Re-running it against an already-bootstrapped cluster requires the `confirm_rebootstrap` input, since `bootstrap.sh` guards against that.
- **`destroy-cluster.yaml`** (`workflow_dispatch`) — the reverse: connects to the cluster named by the `CLUSTER_NAME` variable, force-cascades and deletes every Argo CD Application (so any AWS load balancer they provisioned is torn down *before* Terraform tries to delete the VPC), then runs `terraform destroy` on `eks-platform`. Requires typing the exact `CLUSTER_NAME` value as confirmation.
- **`eks-platform.yaml` / `oidc-roles.yaml` / `self-hosted-runner.yaml`** — CI only: `terraform fmt -check`, `init -backend=false`, `validate` on every push and on PRs touching that stack. No AWS credentials involved.

## Required GitHub configuration

**Repository/environment variables** (`vars.*`, environment `staging`):

| Variable | Used for |
|---|---|
| `OWNER`, `MANAGED_BY`, `USAGE`, `APP_NAME` | `common_tags` on every AWS resource |
| `REGION` | AWS region for `eks-platform` |
| `VPC_CIDRS` | VPC CIDR block |
| `HA` | Number of AZs to span (2–3) |
| `NODES_IN_PUBLIC` | `true`: nodes in public subnets, no NAT gateway. `false`: private subnets + NAT |
| `NODE_MIN`, `NODE_DESIRED`, `NODE_MAX` | Node group scaling config |
| `NODE_TYPE` | EC2 instance type for nodes |
| `CLUSTER_NAME` | The live cluster's name (e.g. `sami-cluster`) — used only by `destroy-cluster.yaml` to reach the cluster and as its confirmation phrase, independent of any `terraform apply` output |

**Secrets** (`secrets.*`):

| Secret | Used for |
|---|---|
| `PRINCIPAL_ARN` | IAM principal granted cluster-admin EKS access |
| `BOOTSTRAP_ARN` | The `github-actions-bootstrap` role ARN, also granted cluster-admin EKS access |
| `RECIPES_GITOPS_PAT` | Checks out the private `recipes-gitops` repo during bootstrap |
| `SLACK_WEBHOOK_URL` | Deploy/destroy start/success/failure notifications |

## Running it

- **Deploy**: Actions → *Apply Terraform EKS Cluster* → Run workflow.
- **Tear down**: Actions → *Destroy EKS Cluster* → Run workflow, typing the current `CLUSTER_NAME` value when prompted.
- **Local validation**: `cd terraform/<stack> && terraform fmt -check && terraform init -backend=false && terraform validate` — the same checks CI runs, no AWS credentials needed.
