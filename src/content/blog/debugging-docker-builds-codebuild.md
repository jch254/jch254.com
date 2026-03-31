---
title: "Debugging Docker Builds in AWS CodeBuild: When Overlay Filesystems Break Everything"
description: "A Docker build kept failing in CodeBuild with 'failed to mount overlay: invalid argument'. The problem wasn't my code, my config, or my permissions. It was the kernel."
date: 2026-04-15
tags: ["aws", "docker", "infrastructure"]
draft: true
---

I needed to build a Docker image in CodeBuild. Custom image, push to ECR, deploy to ECS. Done it plenty of times.

```
failed to mount overlay: invalid argument
```

Two hours. Everything I tried made sense. Nothing worked.

## The pipeline

CodeBuild pulls a custom Docker image with Node.js, Terraform, and the AWS CLI. The buildspec builds the app image, pushes it to ECR, then runs Terraform to update ECS.

CodeBuild → Docker build → ECR push → Terraform apply → ECS rolling deploy.

pnpm for dependencies. Multi-stage Dockerfile. Standard stuff.

## Disabling BuildKit

First thing I tried. The error looked like it could be related to BuildKit's cache mount behavior, which uses overlayfs differently than legacy builds.

```bash
export DOCKER_BUILDKIT=0
```

Same overlay error. Removed it entirely from the buildspec to rule out any interaction. Still failing.

## Shell masking failures

Build steps were "succeeding" even when commands failed. The buildspec piped output through `tee` to capture logs. `tee` always exits 0. It masks the exit code of whatever comes before it.

```bash
docker build -t myapp . 2>&1 | tee build.log
# tee succeeds even when docker build fails
```

I dropped the pipe and captured output directly instead.

```bash
docker build -t myapp . > build.log 2>&1
```

Now failures actually surfaced. Not a fix for the overlay problem, but at least the logs were honest.

## IAM and ECR timing

The ECR push was also failing intermittently with auth errors. The CodeBuild role was missing `ecr:GetAuthorizationToken` on initial deploys. Terraform creates the role and the CodeBuild project in the same apply. CodeBuild can start before IAM propagation finishes.

Added the missing permission. Added a wait-for-image step before the deploy Terraform. Race condition fixed.

Overlay error still there.

## Starting Docker manually

My custom build image doesn't include CodeBuild's managed Docker. I start `dockerd` myself. Tried switching to the managed daemon instead, thinking maybe they'd already handled the storage driver problem.

Same overlay failure. Went back to manual `dockerd` for full control over the flags.

## Retrying and logging

Added verbose logging to every step. Docker info. Storage driver. Filesystem mounts.

```bash
docker info 2>&1
mount | grep overlay
cat /proc/filesystems
```

`overlayfs` showed as the active storage driver. Everything looked correct.

## The turning point

Forced `overlay2` explicitly on the daemon.

```
driver not supported: overlay2
```

Refused to start. `fuse-overlayfs`. Same. No overlay-based driver would initialize.

The config was correct. The environment wouldn't allow it.

## The real problem

CodeBuild runs your build inside a container. Inside that container, I'm starting another Docker daemon that tries to use overlay to build images.

```
CodeBuild host
  → Build container (custom Docker image)
    → dockerd (Docker-in-Docker)
      → overlay filesystem
```

Overlay on overlay. The outer container already uses overlay for its root filesystem. The kernel won't let you stack another overlay mount on top of that. Every overlay-based driver fails for the same reason. Not a Docker problem. A kernel one.

## The fix

```bash
dockerd --storage-driver=vfs &
```

VFS is the simplest storage driver Docker has. No copy-on-write. No kernel dependencies. Every layer is a full copy of the filesystem.

Slower. More disk. But it works everywhere, including nested containers where overlay is off the table.

Build passed first try.

## DNS inside Docker-in-Docker

Overlay fixed. Build failed again. This time during `pnpm install` inside the Dockerfile.

```
getaddrinfo EAI_AGAIN registry.npmjs.org
```

DNS was broken inside the nested daemon. The inner container couldn't resolve external hostnames.

Fix: pass public DNS servers to `dockerd` directly.

```bash
dockerd --storage-driver=vfs --dns 8.8.8.8 --dns 1.1.1.1 &
```

Another thing that works on a normal host and breaks silently when nested.

## What I learned

Every fix I tried addressed a real issue. BuildKit, exit codes, IAM, logging. All legitimate. But the core failure was environmental.

Docker behaves differently inside containers. Same flags, same Dockerfile, same base images. Different results when the filesystem won't cooperate. "Failed to mount overlay: invalid argument" tells you nothing useful. You figure it out by elimination.

You look at what you control. Code, config, permissions. Sometimes the problem is below all of that.

## What's next

VFS works. The pipeline is stable. Builds are slower than they should be, and Docker-in-Docker adds complexity that a build-and-push workflow doesn't need.

Removing Docker-in-Docker entirely is the real fix. That's next.
