# recipes-aws-infra

Terraform + GitHub Actions for the AWS infrastructure behind the `recipes` project: the VPC and EKS cluster the application platform runs on, and the OIDC/IAM roles GitHub Actions assumes to manage all of it — no long-lived AWS credentials anywhere in CI.

The actual Kubernetes-side GitOps config (Argo CD Applications, Helm charts, manifests) lives in a separate repo: [`recipes-gitops`](https://github.com/sami-nyx/recipes-gitops), applied by `bootstrap.sh` after the cluster comes up. The application itself lives in [`recipes`](https://github.com/sami-nyx/protfolio-recipes).

## Architecture

```text
                              GitHub Actions (OIDC, no static AWS keys)
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
                    ▼                     ▼                     ▼
          role: github-actions-   role: github-actions-   per-repo push roles
          terraform (applies      bootstrap (runs         (ECR / S3 / CloudFront -
          eks-platform)           bootstrap.sh)            see recipes' own infra)
                    │                     │
                    ▼                     ▼
     ┌──────────────────────────────────────────────────────┐
     │                     AWS Account                       │
     │                                                        │
     │   ┌────────────────────────────────────────────────┐   │
     │   │                     VPC                         │   │
     │   │                                                  │   │
     │   │   Public Subnet(s)         Private Subnet(s)      │   │
     │   │   (per AZ, count = ha)     (only when              │   │
     │   │                             nodes_in_public=false, │   │
     │   │                             routed via NAT)         │   │
     │   │        │                        │                   │   │
     │   │        └───────────┬────────────┘                   │   │
     │   │                    ▼                                │   │
     │   │            EKS Cluster (control plane)               │   │
     │   │                    │                                 │   │
     │   │                    ▼                                 │   │
     │   │        Managed Node Group (EC2, node_type/            │   │
     │   │        node_counts - min/desired/max)                  │   │
     │   │                    │                                   │   │
     │   │        coredns · kube-proxy · vpc-cni ·                 │   │
     │   │        aws-ebs-csi-driver (IRSA) ·                        │   │
     │   │        network-policy-agent (enforces NetworkPolicy)       │   │
     │   └────────────────────────────────────────────────────────┘   │
     │                                                                  │
     │   S3: Loki log storage (IRSA-scoped)                             │
     │   S3: Terraform state (one bucket per stack, native locking)      │
     │   IAM: EKS Access Entries (API auth mode - no aws-auth ConfigMap)  │
     │   IAM: cert-manager IRSA role (Route53 DNS-01, zone created         │
     │        manually - not this repo's Terraform)                       │
     └──────────────────────────────────────────────────────────────────┘
                    │
                    ▼
     bootstrap.sh → External Secrets Operator + Argo CD →
     reconciles recipes-gitops (separate repo)
```

## Layout

```text
terraform/
  eks-platform/  # The EKS cluster itself: VPC, subnets, node group, IRSA roles, Loki S3 bucket
  oidc-roles/    # IAM roles GitHub Actions assumes via OIDC (no long-lived AWS keys in CI)

.github/
  workflows/
    tf-apply-eks.yaml    # workflow_dispatch: terraform apply -> bootstrap the cluster via recipes-gitops
    destroy-cluster.yaml # workflow_dispatch: drain Argo CD + load balancers, then terraform destroy
    eks-platform.yaml    # CI: fmt/init/validate on push, and on PRs touching terraform/eks-platform/**
    oidc-roles.yaml      # CI: same, for terraform/oidc-roles/**
  actions/tf-offline-test/ # Composite action shared by both CI-validation workflows above
```

## Terraform stacks

Each stack is independent: its own S3 backend, its own state file, applied separately. None of them share a `terraform apply` run.

| Stack | Backend bucket | What it creates |
|---|---|---|
| `eks-platform` | `tf-state-bucket-eks-platform-recipes` | VPC/subnets (public-only or public+private+NAT, via `nodes_in_public`), the EKS cluster and managed node group, EKS Access Entries, IRSA roles for the EBS CSI driver, Loki, cert-manager's Route53 solver, and `cloudfront-sync`, the Loki S3 bucket |
| `oidc-roles` | `tf-state-bucket-gh-actions-oidc-roles` | The GitHub Actions OIDC provider trust + IAM roles: `github-actions-terraform` (applies `eks-platform`), `github-actions-bootstrap` (runs `bootstrap.sh` against the cluster), plus per-repo push roles for ECR/S3/CloudFront |

Each stack's `terraform.tfvars` is generated at CI time from `terraform.tfvars.template` via `envsubst`, populated from the GitHub variables/secrets listed below — it's never committed (see `.gitignore`).

### Why custom modules instead of an off-the-shelf one

`eks-platform` doesn't wrap a published community module (e.g. `terraform-aws-modules/eks/aws`) — the VPC, the EKS cluster, the node group, IAM roles, and access entries are all hand-written resources under `modules/network` and `modules/eks-core`. That was a deliberate choice to demonstrate module design directly rather than configuring someone else's abstraction — the trade-off is more code to own, in exchange for full visibility into exactly what every resource does and why.

### NetworkPolicy enforcement

The `vpc-cni` addon is configured with `enableNetworkPolicy = "true"`, which runs AWS's `network-policy-agent` DaemonSet on every node. This repo only provides that enforcement capability — without it, a `NetworkPolicy` manifest applies cleanly (the API server accepts it) but restricts nothing, since nothing is actually watching for it. The policies themselves (restricting which namespaces can reach Postgres, for example) are Kubernetes manifests, so they belong in and are defined by `recipes-gitops`, not here.

## Prerequisites

* **Terraform** — `eks-platform` requires `>= 1.15.0` (uses S3 native state locking via `use_lockfile`, not a separate DynamoDB lock table); `oidc-roles` requires `>= 1.11.0`. CI pins `1.15.9` for both.
* **AWS CLI**, configured with credentials for account `889867978066` (or your own account, with the variables below updated to match) if running Terraform locally instead of through GitHub Actions.
* **IAM permissions** to create/destroy VPCs, EKS clusters and node groups, IAM roles/policies, S3 buckets, and the GitHub OIDC provider — broad enough that local runs are expected to use an admin-equivalent role; CI uses the narrower `github-actions-terraform` role instead.

## State management

Every stack's state lives in its own S3 bucket (see the table above), keyed by `<environment>/terraform.tfstate`. Locking is S3's own native lock support (`use_lockfile = true`, Terraform >= 1.11) rather than a separate DynamoDB table — one less resource to provision and pay for. State is never stored locally or committed; `.gitignore` excludes `*.tfstate*` outright as a second layer of protection even if someone forgets `-backend=false` during local testing.

## Workflows

- **`tf-apply-eks.yaml`** (`workflow_dispatch`) — applies `eks-platform`, then three jobs run in parallel: `bootstrap-cluster` checks out `recipes-gitops` and runs its `bootstrap.sh` against the new cluster (installs External Secrets Operator + Argo CD, points Argo CD at the GitOps repo) - re-running it against an already-bootstrapped cluster requires the `confirm_rebootstrap` input, since `bootstrap.sh` guards against that; `sync-cert-issuer-config` writes the current `EMAIL`/`REGION`/`ROUTE53_ZONE_ID` variables and this apply's `cert_manager_route53_role_arn` output straight into `recipes-gitops` (`apps/cert-issuer/values.yaml` and `cert-manager.yaml`'s Helm values); `sync-cloudfront-config` does the same for `CLOUDFRONT_DISTRIBUTION_ID` and this apply's `cloudfront_sync_role_arn` output (`apps/cloudfront-sync/values.yaml`) - both commit directly to `recipes-gitops`'s `main`, see that repo's readme.md for why (neither value is sensitive, and the role ARNs get a new random suffix every apply, so a human retyping them every session isn't a reasonable ask).
- **`destroy-cluster.yaml`** (`workflow_dispatch`) — the reverse, and the more involved of the two: connects to the cluster named by the `CLUSTER_NAME` variable, disables auto-sync on every Argo CD Application and cascades their deletion (so any AWS load balancer or leftover `LoadBalancer` Service/Ingress they provisioned is torn down *before* Terraform tries to delete the VPC), then runs `terraform destroy` on `eks-platform`. Requires typing the exact `CLUSTER_NAME` value as confirmation. This automates the exact manual cleanup a stuck `terraform destroy` usually needs (orphaned ELBs/security groups blocking subnet deletion) instead of requiring it after the fact.
- **`eks-platform.yaml` / `oidc-roles.yaml`** — CI only: `terraform fmt -check`, `init -backend=false`, `validate` on every push, and on PRs whose changed files fall under that stack's own directory. No AWS credentials involved.

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
| `ROUTE53_ZONE_ID` | Hosted zone ID cert-manager's Route53 DNS-01 solver is scoped to. The zone itself isn't managed by this repo - see "DNS: GoDaddy → Route53" below |
| `CLOUDFRONT_DISTRIBUTION_ID` | The CloudFront distribution `cloudfront-sync` (a `recipes-gitops`-managed Argo CD sync-hook Job) is scoped to - it repoints that distribution's `nginx-ingress` origin at the current ELB DNS name on every apply, since a fresh ELB gets a new random DNS name every time this stack is destroyed and re-applied. The distribution itself isn't managed by this repo |
| `EMAIL` | ACME account email for the `letsencrypt-prod` `ClusterIssuer` - Let's Encrypt sends expiry/account notices here |

**Secrets** (`secrets.*`):

| Secret | Used for |
|---|---|
| `PRINCIPAL_ARN` | IAM principal granted cluster-admin EKS access |
| `BOOTSTRAP_ARN` | The `github-actions-bootstrap` role ARN - both the EKS access entry Terraform grants it, and the `role-to-assume` the bootstrap/drain jobs authenticate with |
| `TERRAFORM_ROLE_ARN` | The `github-actions-terraform` role ARN - `role-to-assume` for every job that runs `terraform apply`/`destroy` |
| `RECIPES_GITOPS_PAT` | Checks out the private `recipes-gitops` repo during bootstrap, and - needs write access, not just read - pushed directly to its `main` by `sync-cert-issuer-config` (see "Workflows" above) |
| `SLACK_WEBHOOK_URL` | Deploy/destroy start/success/failure notifications |

## Running it

**Through GitHub Actions (recommended path):**

- **Deploy**: Actions → *Apply Terraform EKS Cluster* → Run workflow.
- **Tear down**: Actions → *Destroy EKS Cluster* → Run workflow, typing the current `CLUSTER_NAME` value when prompted.

**Locally**, against a real account (requires AWS credentials and the variables above as environment variables, or a manually-written `terraform.tfvars`):

```bash
cd terraform/eks-platform    # or terraform/oidc-roles

terraform init
terraform plan
terraform apply
# ...when you're done for the day:
terraform destroy
```

After a local `apply`, the cluster still isn't bootstrapped - `tf-apply-eks.yaml` does that as a second job, using `terraform apply`'s outputs. `recipes-gitops/bootstrap/bootstrap_local.sh` does the same thing locally, for when you'd rather not spend GitHub Actions minutes on it - see that repo's readme.

**Local validation only** (no AWS credentials needed — the same checks CI runs):

```bash
cd terraform/<stack>
terraform fmt -check
terraform init -backend=false
terraform validate
```

## DNS: GoDaddy → Route53

The domain was registered at GoDaddy, and DNS-01 certificate challenges went through a third-party `cert-manager-webhook-godaddy` chart authenticating with a GoDaddy API key. That's been replaced with cert-manager's native Route53 support - no third-party webhook, no long-lived API key, just IRSA like everything else in this project (`cluster_roles.cert_manager_route53_irsa_role`, above).

The hosted zone itself is deliberately **not** Terraform-managed - this repo only owns cluster bootstrap and the IRSA roles workloads need, not DNS. Steps, in order:

1. **Create the hosted zone manually** (AWS Console → Route53 → Create hosted zone, or `aws route53 create-hosted-zone --name <domain> --caller-reference <anything-unique>`). Note the Zone ID and the 4 assigned name servers.
2. **Recreate every other record that currently exists at GoDaddy** in the new zone before cutting over - not just the one this cluster's Ingress needs. Nothing here can see GoDaddy's DNS panel; check it yourself for anything else pointed at this domain (email, other subdomains) and recreate those records too, or they break silently the moment nameservers flip.
3. **Set `ROUTE53_ZONE_ID` and `EMAIL`** (the repo variables above) to the zone ID from step 1 and the address Let's Encrypt should notify, then run `tf-apply-eks.yaml` - this creates the cert-manager IRSA role scoped to that zone, and its `sync-cert-issuer-config` job automatically writes the zone ID, email, region, and the role's ARN straight into `recipes-gitops` (`apps/cert-issuer/values.yaml` and `cert-manager.yaml`) on every apply. Nothing to manually fill in - see that repo's readme.md for why this is committed directly rather than left as a placeholder.
4. **At GoDaddy** (registrar side, not code): log into the GoDaddy account, open DNS management for the domain, replace the nameservers with the 4 from step 1. This is **not** a domain transfer - the domain stays registered at GoDaddy, only who answers DNS queries for it changes. Lower the TTL on existing GoDaddy records a day ahead if possible, to speed convergence.
5. **Verify before considering it done**: `dig NS <domain>` should eventually return the Route53 nameservers, not GoDaddy's. Propagation is usually fast but isn't instant - there's a real window where some resolvers still answer from GoDaddy.
6. Once a certificate has actually renewed successfully through Route53, delete the old `godaddy-api-credentials` secret from AWS Secrets Manager - it's dead the moment the webhook's gone, no reason to leave a GoDaddy API key sitting there.

## Cost

This cluster is not meant to run continuously. `terraform apply` at the start of a work session, `terraform destroy` (or the `destroy-cluster.yaml` workflow) at the end of one — every day, and always over a weekend or break. Nothing in this repo assumes the cluster is always up; `tf-apply-eks.yaml`'s `confirm_rebootstrap` guard and `destroy-cluster.yaml`'s cluster-existence check are both written expecting the cluster to come and go repeatedly, not run once and stay up.
