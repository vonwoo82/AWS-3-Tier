# AWS 3-Tier Architecture — Terraform

A production-ready, modular Terraform configuration that deploys a classic
**Web → App → Database** three-tier architecture on AWS.

---

## Architecture Overview

```
Internet
   │
   ▼
┌──────────────────────────────────────────────┐
│           Public ALB  (port 80/443)           │  ← Web Tier (public subnets)
└──────────────┬───────────────────────────────┘
               │
   ┌───────────▼───────────┐
   │   Web EC2 ASG (Nginx) │  auto-scales 2–6 instances across 2 AZs
   └───────────┬───────────┘
               │
┌──────────────▼───────────────────────────────┐
│         Internal ALB  (port 80)               │  ← App Tier (private subnets)
└──────────────┬───────────────────────────────┘
               │
   ┌───────────▼────────────┐
   │  App EC2 ASG (port 8080)│  auto-scales 2–6 instances across 2 AZs
   └───────────┬────────────┘
               │
┌──────────────▼───────────────────────────────┐
│    RDS MySQL 8.0  Multi-AZ  (port 3306)       │  ← DB Tier (isolated subnets)
└──────────────────────────────────────────────┘
```

### Key AWS Services Used

| Layer | Services |
|-------|----------|
| Networking | VPC, Public/Private Subnets (×2 AZ), IGW, NAT Gateways, Route Tables, VPC Flow Logs |
| Web Tier | Application Load Balancer (public), EC2 Auto Scaling Group, Nginx |
| App Tier | Application Load Balancer (internal), EC2 Auto Scaling Group |
| DB Tier | RDS MySQL 8.0 (Multi-AZ), Secrets Manager, Parameter Group |
| Security | Security Groups (least-privilege), IMDSv2, SSM Session Manager |
| Observability | CloudWatch Alarms, RDS Enhanced Monitoring, Performance Insights |

---

## Directory Structure

```
aws-3tier-terraform/
├── main.tf                   # Root — wires all modules together
├── variables.tf              # All input variables
├── outputs.tf                # Key outputs (ALB DNS, endpoints …)
├── terraform.tfvars          # Your environment values (edit this)
├── versions.tf               # Provider version constraints
└── modules/
    ├── vpc/                  # VPC, subnets, IGW, NAT GWs, flow logs
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security-groups/      # Five security groups with least-privilege rules
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── web-tier/             # Public ALB + EC2 ASG (Nginx reverse proxy)
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── user_data.sh
    ├── app-tier/             # Internal ALB + EC2 ASG (application server)
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── user_data.sh
    └── db-tier/              # RDS MySQL + Secrets Manager + CW Alarms
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── versions.tf
```

---

## Prerequisites

| Tool | Minimum Version |
|------|----------------|
| Terraform | 1.5.0 |
| AWS CLI | 2.x |
| AWS credentials | IAM permissions for VPC, EC2, RDS, ALB, IAM, Secrets Manager, CloudWatch |

---

## Quick Start

### 1 — Clone and configure

```bash
git clone <your-repo>
cd aws-3tier-terraform
```

Edit `terraform.tfvars` with your values:

```hcl
aws_region   = "us-east-1"
project_name = "myapp"
environment  = "prod"
```

### 2 — Initialise

```bash
terraform init
```

### 3 — Preview

```bash
terraform plan -out=tfplan
```

### 4 — Apply

```bash
terraform apply tfplan
```

Deployment typically takes **10–15 minutes** (RDS is the slowest resource).

### 5 — Get the entry-point URL

```bash
terraform output web_alb_dns_name
```

Open that URL in your browser — traffic flows through:
`Internet → Public ALB → Nginx (web) → Internal ALB → App Server → RDS`

---

## Configuration Reference

### Networking

| Variable | Default | Description |
|----------|---------|-------------|
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `az_count` | `2` | Number of Availability Zones (2 or 3) |

Subnets are carved automatically:
- **Public** (web/ALB): `10.0.0.x/24`, `10.0.1.x/24`
- **Private App**: `10.0.10.x/24`, `10.0.11.x/24`
- **Private DB**: `10.0.20.x/24`, `10.0.21.x/24`

### Web Tier

| Variable | Default | Description |
|----------|---------|-------------|
| `web_instance_type` | `t3.micro` | EC2 instance size |
| `web_min_size` | `2` | Minimum ASG instances |
| `web_max_size` | `6` | Maximum ASG instances |
| `enable_https` | `false` | Enable HTTPS on public ALB |
| `certificate_arn` | `""` | ACM certificate ARN (required if HTTPS) |

### App Tier

| Variable | Default | Description |
|----------|---------|-------------|
| `app_instance_type` | `t3.small` | EC2 instance size |
| `app_min_size` | `2` | Minimum ASG instances |
| `app_max_size` | `6` | Maximum ASG instances |

### Database Tier

| Variable | Default | Description |
|----------|---------|-------------|
| `db_instance_class` | `db.t3.medium` | RDS instance size |
| `db_engine_version` | `8.0` | MySQL version |
| `db_multi_az` | `true` | Multi-AZ standby |
| `db_allocated_storage` | `20` | Storage in GiB (auto-scales up to 3×) |
| `db_deletion_protection` | `true` | Prevent accidental deletion |

---

## Security Design

- **No SSH** — instances are accessed exclusively via AWS Systems Manager Session Manager (no key pairs, no port 22)
- **IMDSv2 enforced** on all launch templates
- **Least-privilege security groups**: each tier only accepts traffic from the tier directly above it
- **DB password** is auto-generated and stored in AWS Secrets Manager — never in Terraform state as plain text
- **Storage encryption** enabled on RDS (`storage_encrypted = true`)
- **VPC Flow Logs** enabled for network traffic auditing

---

## Enabling HTTPS

1. Request or import a certificate in AWS Certificate Manager (ACM)
2. Set in `terraform.tfvars`:

```hcl
enable_https    = true
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxxxxx"
```

3. Re-apply — the HTTP listener will automatically redirect to HTTPS (301).

---

## Remote State (recommended for teams)

Uncomment the `backend "s3"` block in `main.tf` and create the bucket + DynamoDB table first:

```bash
aws s3api create-bucket --bucket my-tf-state --region us-east-1
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

---

## Tear Down

```bash
# Disable deletion protection on RDS first (if enabled)
terraform apply -var="db_deletion_protection=false"

# Then destroy everything
terraform destroy
```

> **Note:** A final RDS snapshot is created automatically before the instance is deleted.

---

## Cost Estimate (us-east-1, 2 AZs)

| Resource | Approx. monthly cost |
|----------|---------------------|
| 2× NAT Gateways | ~$65 |
| 2× Web EC2 (t3.micro) | ~$15 |
| 2× App EC2 (t3.small) | ~$30 |
| RDS db.t3.medium Multi-AZ | ~$100 |
| 2× ALBs | ~$30 |
| **Total** | **~$240/month** |

Costs vary by traffic volume and region.
