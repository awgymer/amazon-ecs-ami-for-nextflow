# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is the **Amazon ECS-optimized AMI Build Recipes** repository — a Packer-based project for building official AWS ECS-optimized Amazon Machine Images (AMIs) for Amazon Linux 2 (AL2) and Amazon Linux 2023 (AL2023), across x86_64, ARM, GPU, and Neuron/Inferentia variants.

## Build Commands

All build targets require the `REGION` environment variable. Release variable files (`release-al2.auto.pkrvars.hcl`, `release-al2023.auto.pkrvars.hcl`) must exist before building.

```bash
# Build specific AMI variants
REGION=us-west-2 make al2              # Amazon Linux 2 x86_64
REGION=us-west-2 make al2arm           # Amazon Linux 2 ARM
REGION=us-west-2 make al2gpu           # AL2 with GPU/NVIDIA support
REGION=us-west-2 make al2inf           # AL2 with Inferentia (Neuron)
REGION=us-west-2 make al2kernel5dot10  # AL2 with kernel 5.10
REGION=us-west-2 make al2023           # Amazon Linux 2023 x86_64
REGION=us-west-2 make al2023arm        # AL2023 ARM
REGION=us-west-2 make al2023gpu        # AL2023 with GPU/NVIDIA
REGION=us-west-2 make al2023neu        # AL2023 with Neuron/Inferentia
```

## Validation & Static Checks

```bash
make init          # Initialize Packer and download plugins (run before validate)
make validate      # Validate all Packer configs (requires REGION)
make static-check  # Full static analysis: packer fmt check + shfmt + shellcheck
make fmt           # Auto-format Packer HCL files and shell scripts in-place
make packer-fmt    # Check Packer HCL formatting only
```

## Tooling Setup

```bash
make packer      # Download Packer binary (v1.7.4) to ./packer
make shellcheck  # Download shellcheck (v0.7.2) to ./shellcheck
make shfmt       # Download shfmt (v3.4.0) to ./shfmt
make clean       # Remove all downloaded tools and artifacts
```

## Architecture

### Packer Configuration Files

Each AMI variant has its own `.pkr.hcl` source file:
- `al2.pkr.hcl`, `al2arm.pkr.hcl`, `al2gpu.pkr.hcl`, `al2inf.pkr.hcl`, `al2kernel5dot10.pkr.hcl` — AL2 variants
- `al2023.pkr.hcl`, `al2023arm.pkr.hcl`, `al2023gpu.pkr.hcl`, `al2023neu.pkr.hcl` — AL2023 variants
- `variables.pkr.hcl` — All shared variable declarations (component versions, instance types, block device config, AMI naming)
- `release-al2.auto.pkrvars.hcl` / `release-al2023.auto.pkrvars.hcl` — Release variable values (required, committed)
- `overrides.auto.pkrvars.hcl` — Local overrides (git-ignored, for developer use)

### Provisioning Scripts (`/scripts/`)

Shell scripts are invoked by Packer in sequence during the build. Key scripts:
- `install-docker.sh`, `install-ecs-init.sh`, `install-containerd.sh` — Core ECS stack
- `install-gpu-driver.sh`, `install-neuron-driver.sh` — Accelerator support
- `install-ssm-agent.sh`, `install-aws-cli.sh` — AWS tooling
- `cleanup.sh` — Final image cleanup before snapshot

### Static Files (`/files/`)

Configuration files copied into the AMI:
- `ecs.config` — ECS agent configuration
- `cloud-init-al2023.cfg` — Cloud-init config for AL2023
- `cloudwatch-agent.config` — CloudWatch agent configuration

### Build Sequence

A typical AL2023 build (from `al2023.pkr.hcl`) follows this order:
1. Copy cloud-init config and setup scripts
2. System package update (`dnf`)
3. Install base packages (EFS utils, SSM agent)
4. Configure ECS directories and settings
5. Install Docker, containerd, runc
6. Install ECS init
7. Install AWS CLI and SSM exec dependencies
8. Reboot (to apply kernel updates)
9. Install GPU/Neuron drivers (accelerator variants only)
10. Configure Docker group membership and systemd services
11. Install ECS Logs Collector (`/amazon-ecs-logs-collector/`)
12. Cleanup

### CI/CD (`.github/workflows/`)

- **static.yml** — Runs `make static-check` on every PR
- **gitsecrets.yml** — Git secrets scanning on push/PR
- **initiaterelease.yml** — Scheduled daily (18:00 UTC weekdays); checks for upstream AL2/AL2023 updates, creates release branches, mirrors to AWS CodeCommit, and publishes CloudWatch metrics
- **manualtrigger.yml** — Manually mirrors main branch to CodeCommit

### Notable Patterns

- **Air-gapped region support**: Build paths for restricted networks are handled via custom endpoint variables in `variables.pkr.hcl`.
- **Version locking**: Critical packages (NVIDIA drivers, kernel) are pinned in AL2023 GPU AMIs to prevent unexpected upgrades.
- **IMDSv2 enforcement**: All AMIs are built with `http_tokens = required` metadata options.
- **Multi-architecture**: x86_64 and ARM builds use separate instance types configured as variables.
