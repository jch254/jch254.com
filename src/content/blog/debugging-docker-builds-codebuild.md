---
title: "Debugging Docker Builds in AWS CodeBuild: When Overlay Filesystems Break Everything"
description: "A Docker build kept failing in CodeBuild with 'failed to mount overlay: invalid argument'. The problem wasn't my code, my config, or my permissions. It was the kernel."
date: 2026-04-08
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

## Architecture mismatch

Deployed. ECS task crashed immediately.

```
exec /usr/local/bin/docker-entrypoint.sh: exec format error
```

That error means one thing. The image was built for the wrong CPU architecture. My build produced an ARM image. ECS was running x86.

The default `docker build` uses the host architecture. CodeBuild was running on an ARM instance. The resulting image only contained ARM binaries.

Fix was to use buildx and specify the platform explicitly.

```bash
docker buildx build \
  --platform linux/amd64 \
  --push \
  -t $IMAGE_URI .
```

Buildx with the container driver also handles cross-compilation through QEMU. No need to change the build instance type.

## The second mismatch

New error.

```
image Manifest does not contain descriptor matching platform 'linux/arm64/v8'
```

The image was amd64 now. But ECS was still configured for ARM64. The Terraform task definition had:

```hcl
runtime_platform {
  cpu_architecture = "ARM64"
}
```

Changed it to match the image.

```hcl
runtime_platform {
  cpu_architecture = "X86_64"
}
```

That's it. Not a new problem. Just alignment between what the build produces and what the runtime expects.

## The actual end state

Final working setup:

- vfs storage driver for Docker-in-Docker
- DNS configured on dockerd with `--dns 8.8.8.8 --dns 1.1.1.1`
- buildx with container driver for cross-platform builds
- linux/amd64 image pushed to ECR
- ECS task definition set to X86_64

Took a while to get there. But it worked.

## The cache that made builds slower

With the pipeline working, I added pnpm caching. Standard approach. Save the pnpm store between builds so installs run faster.

It looked like it was working. Logs showed pnpm fetch reusing packages from the cache. Installs were quick. Everything seemed fine.

Then I looked at the total build time.

Cache upload took around 5 minutes every build. Cache download on the next run took 50 to 60 seconds. The actual `pnpm install` took 13 to 20 seconds.

I was spending 5 minutes uploading a cache to save 13 seconds of install time. The caching worked. It also made builds slower.

## Removing the cache

Removed the pnpm cache from CodeBuild entirely. Kept Terraform plugin cache because that one actually pays for itself. Simplified the install step back to a clean `pnpm install` with no cache restore or save.

Builds dropped from around 15 minutes to around 7 minutes 30 seconds.

## Final build times

Before: 15 to 16 minutes per build.

After: 7 minutes 30 seconds.

Roughly 50 percent reduction. About 8 minutes saved per build.

## What I learned

Every fix I tried addressed a real issue. BuildKit, exit codes, IAM, logging. All legitimate. But the core failure was environmental.

Docker behaves differently inside containers. Same flags, same Dockerfile, same base images. Different results when the filesystem won't cooperate. "Failed to mount overlay: invalid argument" tells you nothing useful. You figure it out by elimination.

You look at what you control. Code, config, permissions. Sometimes the problem is below all of that.

Caching is not automatically a win. Measure the total system cost, not individual steps. `pnpm install` was already cheap at 13 seconds. The expensive part was the cache upload that ran every single build. I optimised the build for hours. The biggest win was deleting the optimisation.

## The cost impact

CodeBuild was the largest cost in the account. Around $14 per month. ECS was lower. Everything else was smaller.

CodeBuild bills per build minute. Build time dropped from around 15 minutes to 7 minutes 30 seconds. That roughly halved the CodeBuild cost.

No architecture change. No new service. Just fewer minutes per build. The performance fix was also a cost fix.

## What's next

VFS works. The pipeline is stable. But Docker-in-Docker is still the wrong tool for a build-and-push workflow. It adds complexity, slows builds down, and introduces problems that don't exist on a normal host.

Removing Docker-in-Docker entirely is the next step.

Sometimes the fastest build is the one where you delete something.
