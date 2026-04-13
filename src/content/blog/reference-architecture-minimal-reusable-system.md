---
title: "I Kept Rebuilding the Same System"
description: "Every new project started with the same backend, the same infra, the same pipeline. I got tired of it, so I extracted the minimal patterns that actually matter into a reusable reference architecture."
date: 2026-04-22
tags: ["architecture", "aws", "infrastructure"]
draft: true
---

Every backend I've built in the last few years looks the same. Stateless API. Multi-tenant data model. Docker container. Terraform. Push to main, deploy to ECS, wait for stabilization.

I kept building it from scratch each time.

Not because the patterns changed. They didn't. I'd copy files between repos, rip out domain logic, adjust names, fix the parts that didn't survive the transplant. By the time the foundation worked, I'd spent days on plumbing that had nothing to do with the product.

So I extracted it. Stripped out the domain logic. Removed everything that wasn't structural. What was left became [reference-architecture](https://github.com/jch254/reference-architecture).

---

## What I actually needed

- A backend that handles requests, resolves the tenant, and talks to a database
- A runtime that works the same locally and in production
- Infrastructure that deploys from a single pipeline with no manual steps
- A data model that isolates tenants from day one
- A way to know the system actually works after deploy

That's it. No message queues. No async pipelines. No event buses. No staging environment. No separate services for things that don't need to be separate.

I've built systems with all of those pieces. Most weren't needed at the start, and they created drag long before they created value.

---

## The layers

Four layers. Each aligns with the one below it.

```text
/src/backend                → API (NestJS)
Dockerfile                  → runtime
buildspec.yml               → CI/CD (CodeBuild)
/infrastructure/terraform   → deployment (AWS + Cloudflare)
```

The backend is a NestJS app with request context middleware that resolves the tenant from the `Host` header. Every request gets a `tenantSlug` and a `requestId`. Controllers delegate to services. Services talk to DynamoDB. Nothing else.

The Dockerfile is a multi-stage build. `node dist/main.js` runs the compiled output. Non-root user. Port 3000. Works locally in Docker Compose and in ECS Fargate in production. Same image, same behavior.

The buildspec does five things: install, build, push Docker image to ECR, run Terraform, wait for ECS to stabilize. Then it applies the Cloudflare DNS layer and runs system validation. If any step fails, the build fails.

Infrastructure is two Terraform layers. AWS handles ECS, API Gateway, DynamoDB, ECR, Cloud Map, and IAM. Cloudflare reads outputs from AWS via remote state and creates DNS records. Cloudflare handles TLS termination.

---

## The data model

Single DynamoDB table. PAY_PER_REQUEST. Two key patterns.

Tenant-scoped entities:

```text
PK = TENANT#<tenantId>
SK = EXAMPLE#<entityId>
```

Every query is scoped to a tenant partition. No scans. No GSIs. Cross-tenant access is impossible because the partition key enforces it.

Analytics events use the same table:

```text
PK = TENANT#<tenantId>
SK = EVENT#<timestamp>#<eventName>#<requestId>
```

Append-only. No updates, no deletes. The analytics service resolves the tenant and request ID from the request context and writes via `putItem`. No buffering, no retries, no additional infrastructure.

Analytics and domain data share the same table, the same Terraform resource, the same IAM policy. One table, one permission boundary, one billing mode.

---

## What I removed

The decisions were about what to take out.

**Async pipelines.** Early versions had background processing. I removed it. If the system needs async later, add it then. Starting with it meant carrying complexity for a scenario that hadn't arrived.

**DTOs and validation frameworks.** The controller checks `if (!body.name)` and throws a `BadRequestException`. Inline validation. No class-validator decorators, no transformation pipes, no DTO classes. The right level of indirection for this: none.

**Abstractions over DynamoDB.** The `DynamoDbService` is flat. `getItem`, `putItem`, `updateItem`, `query`, `deleteItem`. It wraps the SDK client and nothing else. No repository pattern. No ORM.

**Staging environments.** One environment. One deploy target. System validation runs against the live URL after deploy. If it's broken, the build fails. Staging adds a second environment to maintain without adding confidence.

**Unnecessary infrastructure.** No ALB. API Gateway connects to ECS via VPC Link and Cloud Map. Public subnets only, no NAT gateway. Security groups restrict ingress to port 3000 from the VPC Link. Circuit breaker with rollback. Rolling deploys with a health check grace period.

---

## The validation layer

After every deploy, a validation script runs against the live system. No test frameworks. No mocks. Just `fetch` calls against real endpoints.

```text
GET  /api/health        → status is "ok"
POST /api/example       → item created, response shape correct
GET  /api/example       → created item present in list
DELETE /api/example/:id → cleanup
```

It tests tenant isolation by sending a request with a different `Host` header and verifying the created item isn't visible. If the proxy strips the override, the test skips instead of failing.

The script exits non-zero on failure. CodeBuild treats that as a failed build. Deploy equals validated system.

One TypeScript file. Runs in 2-3 seconds. Every other post-deploy check I've used was either too heavy or too shallow.

---

## How I use it

The repo stays clean. No domain logic, no product code. When I start a new project, I include the reference architecture as an `/example-project` folder. The new repo gets its own code, its own infra, its own pipeline. But the example project sits right there as a working reference for every pattern.

Six months in, when I need to remember how tenant middleware was wired or how the DynamoDB keys work, I open `/example-project` and read the code. It's always the same minimal system.

The real speed comes from combining this with Copilot and Claude.

I point the AI at the example project and tell it to scaffold a new module following the same patterns. It sees the controller structure, the service layer, the DynamoDB key builders, the analytics integration, the response wrapping. It produces code that matches. Not perfect every time, but structurally correct.

Same for infrastructure. The Terraform in `/example-project` is a complete working deployment. The AI generates Terraform that fits the style because the patterns are already in the codebase. Correct variable naming. Correct tag structure. Correct IAM scoping. No long prompt explaining conventions.

Frontend works the same way. The reference architecture includes a React demo UI served from the same container. When scaffolding a new frontend, the example project shows the API contract, how tenant context flows, how the build packages everything into one Docker image. Copilot reads that context and produces components that integrate correctly from the start.

The workflow: create a repo, drop in the example project folder, point the AI at it, scaffold. Backend, infrastructure, frontend. The AI has a concrete reference instead of general training data.

---

## What this gives me

Everything in the repo exists because it's needed, not because it might be useful.

The pipeline is deterministic. Push to main, Docker build, Terraform apply, ECS stabilize, Cloudflare apply, validate. Same steps every time. No branching logic. No conditional deploys.

Each layer lines up with the one below it. The app binds to port 3000. The Dockerfile exposes 3000. The ECS task maps 3000. The security group allows 3000 from the VPC Link. The health check hits 3000. Boring. That's correct.

I've already used this for the next thing I'm building. Copied the repo, added domain logic, deployed. No infra redesign. No pipeline changes. Multi-tenant data model already there. Analytics already wired. Validation script adapted with a few extra assertions.

I'm already using this as the base for the next product.

Build it once. Stop rebuilding it.
