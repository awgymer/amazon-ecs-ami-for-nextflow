# CI/CD Documentation

## Workflows

There are four GitHub Actions workflows in this repository.

### `static.yml` — Static Checks

Runs on every pull request. Executes `make static-check`, which validates Packer HCL formatting, shell script formatting (shfmt), and shell script linting (shellcheck). No AWS credentials required.

### `gitsecrets.yml` — Git Secrets Scan

Runs on every push and pull request. Installs [git-secrets](https://github.com/awslabs/git-secrets), registers AWS credential patterns, and scans the full commit history for accidentally committed secrets.

### `initiaterelease.yml` — Initiate Release

Runs on a schedule (weekdays at 18:00 UTC) or manually via `workflow_dispatch`. Checks whether a new AL2023 source AMI or security updates are available. If updates are detected, it creates a dated `release-YYYYMMDD` branch, commits the updated release variable files, and opens a pull request against `main`.

The update check works by launching a temporary EC2 instance using the current ECS-optimized AMI, running `dnf check-upgrade` on it via SSM Run Command, then terminating it. This requires the `AMI_GENERATE_CONFIG_ROLE` and `IAM_INSTANCE_PROFILE_ARN` to be configured (see [Secrets](#secrets) below).

### `build.yml` — Build AMIs

Triggers when a `release-*` branch is merged into `main`, or manually via `workflow_dispatch`. Runs `al2023` and `al2023gpu` builds in parallel using Packer. On success, each built AMI ID is published to SSM Parameter Store at:

```
/<environment>/ecs-ami/<AWS_REGION>/<variant>/latest
```

For example: `/prod/ecs-ami/us-east-1/al2023/latest`

The environment prefix is derived automatically from the GitHub environment name (`github.environment`), so no additional variable is needed.

SSM Parameter Store automatically retains the full version history of each parameter, so previous AMI IDs remain retrievable by version number.

---

## Required Configuration

All secrets and variables are configured per GitHub environment. Navigate to **Settings → Environments → prod** to set them.

### Secrets

| Secret | Used by | Description |
|---|---|---|
| `AMI_GENERATE_CONFIG_ROLE` | `initiaterelease.yml` | ARN of an IAM role assumed by GitHub Actions via OIDC to run the update check. Needs permissions to describe EC2 images, query SSM parameters, launch/terminate EC2 instances, and send SSM Run Commands. |
| `IAM_INSTANCE_PROFILE_ARN` | `initiaterelease.yml` | ARN of an EC2 instance profile attached to the temporary probe instances launched during the update check. Attach the AWS managed policy `AmazonSSMManagedInstanceCore` to the underlying role. |
| `PACKER_ROLE_ARN` | `build.yml` | ARN of an IAM role assumed by GitHub Actions via OIDC to run Packer builds. Needs EC2 permissions for AMI creation (see [HashiCorp's minimal Packer IAM policy](https://developer.hashicorp.com/packer/integrations/hashicorp/amazon#iam-task-or-instance-role)) plus `iam:PassRole` and `ssm:PutParameter`. |
| `PAT_TOKEN` | `initiaterelease.yml` | A GitHub fine-grained personal access token used to push the release branch and open the PR. Using a PAT instead of the default `github.token` ensures CI checks (e.g. `static.yml`) are triggered on the release PR. Requires **Contents** (read & write) and **Pull requests** (read & write) permissions on this repository. Generate one under **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**. |

### Variables

| Variable | Used by | Description | Example |
|---|---|---|---|
| `AWS_REGION` | `initiaterelease.yml`, `build.yml` | AWS region to build AMIs in and write SSM parameters to. | `us-east-1` |

---

## AWS Setup

### OIDC Authentication

Both `AMI_GENERATE_CONFIG_ROLE` and `PACKER_ROLE_ARN` are assumed by GitHub Actions using OIDC — no long-lived access keys are stored in GitHub.

To enable this, create an IAM OIDC Identity Provider in your AWS account pointing at `token.actions.githubusercontent.com`. Each role's trust policy should then allow GitHub Actions to assume it, scoped to your repository:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:<your-org>/<your-repo>:*"
    }
  }
}
```

### IAM Role Permissions Summary

**`AMI_GENERATE_CONFIG_ROLE`**
- `ssm:GetParameters` — look up current ECS-optimized AMI IDs from public SSM paths
- `ssm:SendCommand`, `ssm:GetCommandInvocation`, `ssm:DescribeInstanceInformation` — run `dnf check-upgrade` on probe instances via SSM Run Command
- `ec2:RunInstances`, `ec2:TerminateInstances`, `ec2:DescribeInstances`, `ec2:CreateTags` — launch and terminate probe instances
- `ec2:DescribeImages` — find source AMI IDs for release variable generation
- `iam:PassRole` — attach the instance profile to probe instances

**`PACKER_ROLE_ARN`**
- EC2 permissions for AMI creation — see [HashiCorp's minimal Packer IAM policy](https://developer.hashicorp.com/packer/integrations/hashicorp/amazon#iam-task-or-instance-role)
- `iam:PassRole` — attach an instance profile to the Packer builder instance
- `ssm:PutParameter` — write built AMI IDs to SSM Parameter Store

**Instance profile role (for `IAM_INSTANCE_PROFILE_ARN`)**

Attach the AWS managed policy `AmazonSSMManagedInstanceCore`. This allows SSM Run Command to connect to and execute commands on the probe instances.
