---
title: "I Stopped Rebuilding the Same System"
description: "Over ten years, my projects kept turning into the same backend, infrastructure, and deploy pipeline. I stopped treating that as coincidence and pulled the shared pieces into one reusable system."
date: 2026-05-20
tags: ["architecture", "aws", "infrastructure"]
draft: true
---

Over the last ten years, nearly every system I built kept converging into the same shape.

It didn't matter whether the project was a Spotify analytics tool, a Pokemon Go API, a Messenger bot, a GTD app, or an email-driven music sharing platform. After enough iterations, they all ended up looking similar underneath.

Stateless API. Docker container. Terraform. Multi-tenant data model. CI/CD pipeline. Push to main, deploy to ECS, wait for stabilisation.

For years I kept rebuilding that stack from scratch.

Not because the patterns changed. They mostly didn't. I'd copy infrastructure between repos, strip out domain logic, rename things, then spend days reconnecting plumbing I already understood.

The systems were different.

The operational shape wasn't.

A lot of the earlier open source repos came from patterns I was already using professionally. I generalised them, cleaned them up, and published them. Over time those repos started converging too.

The old serverless repos. The ECS infrastructure repos. Docker build environments. CI/CD tooling. Terraform modules. Different generations of the same system.

Eventually I stopped treating that convergence as accidental.

I extracted the common structure into [reference-architecture](https://github.com/jch254/reference-architecture).

Not a template. A system I could keep evolving under real usage.

---

## The convergence happened slowly

The earlier projects solved isolated problems.

One repo handled Serverless APIs. Another handled Dockerised CI builds. Another focused on ECS autoscaling. Another was a React starter kit with auth already wired in.

At the time they felt separate.

Looking back, they were all solving the same operational problems from different angles.

- How do you deploy safely?
- How do you keep environments consistent?
- How do you isolate tenants?
- How do you structure infrastructure so you can reuse it later?
- How do you stop every new project becoming a pile of slightly different decisions?

Over time the repo set got smaller.

The Docker build repos became one build model.

The Terraform repos became reusable modules.

The deployment patterns standardised.

The auth flows standardised.

The infrastructure got smaller.

I removed things more often than I added them.

That was the real direction of the system.

---

## What I actually needed

After enough projects, the list became pretty small.

- A backend that handles requests, resolves the tenant, and talks to a database
- A runtime that behaves the same locally and in production
- Infrastructure that deploys from one pipeline with no manual steps
- A data model that isolates tenants from day one
- A way to know the system actually works after deploy
- A web or mobile client that can sit on top without changing the backend

That's the system.

No queues by default. No event buses. No staging environment. No extra services for problems that don't exist yet.

I've built systems with all of those pieces before. Most created operational drag long before they created value.

Most of the decisions were removals.

---

## The layers

Four layers. Each lines up with the one below it.

```text
/src/backend                → API (NestJS)
Dockerfile                  → runtime
buildspec.yml               → CI/CD (CodeBuild)
/infrastructure/terraform   → deployment (AWS + Cloudflare)
```

Web and mobile clients sit above the same API. No extra backend. Just different entry points.

The backend is a NestJS app with request context middleware that resolves the tenant from the `Host` header. Every request gets a `tenantSlug` and a `requestId`.

Controllers delegate to services. Services talk to DynamoDB. Nothing else sits in the request path.

The Dockerfile is a multi-stage build. `node dist/main.js` runs the compiled output. Non-root user. Port 3000. Same image locally and in ECS Fargate.

The build pipeline does five things.

* Install dependencies
* Build the app
* Push the image to ECR
* Run Terraform
* Wait for ECS stabilisation

Then it applies the Cloudflare DNS layer and runs validation against the live system. If any step fails, the build fails.

Infrastructure is split into two Terraform layers.

AWS handles ECS, API Gateway, DynamoDB, ECR, Cloud Map, and IAM.

Cloudflare reads outputs from AWS remote state and creates DNS records. Cloudflare handles TLS termination.

The system stays small enough that I can still hold the whole thing in my head.

I also kept repos self-contained.

The app, infrastructure, deployment pipeline, runtime, and validation all live together. If you clone the repo, you can see how the system runs and how it deploys without chasing dependencies across other repos.

Shared pieces only get extracted once they survive repeated use across projects. Terraform modules, SES infrastructure, auth patterns. The projects stay independently deployable systems.

That matters.

---

## The data model

Single DynamoDB table. PAY_PER_REQUEST. Two key patterns.

Tenant-scoped entities:

```text
PK = TENANT#<tenantId>
SK = EXAMPLE#<entityId>
```

Every query stays inside a tenant partition. No scans. No cross-tenant queries.

Analytics events use the same table:

```text
PK = TENANT#<tenantId>
SK = EVENT#<timestamp>#<eventName>#<requestId>
```

Append-only. No updates. No deletes.

The analytics service resolves tenant and request ID from the request context and writes directly with `putItem`.

No buffering layer. No retry workers. No extra infrastructure.

Analytics and domain data share the same table, the same IAM policy, and the same Terraform resource.

One table. One permission boundary.

---

## What I removed

Most architecture discussions focus on what got added.

The useful decisions were usually the opposite.

### Async pipelines

Early versions had background processing.

I removed it.

If the system needs queues or workers later, I can add them. Carrying async infrastructure from day one meant more moving parts for workloads that didn't exist yet.

### DTOs and validation frameworks

The controller checks `if (!body.name)` and throws a `BadRequestException`.

That's enough here.

No decorators. No transformation pipes. No validation class hierarchy.

The system does not need more than that.

### Abstractions over DynamoDB

The `DynamoDbService` is flat.

* `getItem`
* `putItem`
* `updateItem`
* `query`
* `deleteItem`

It wraps the SDK client and nothing else.

No ORM. No repository pattern.

### Staging environments

One environment. One deploy target.

After deployment, validation runs against the live URL. If validation fails, the build fails.

I spent years maintaining staging environments that drifted from production and still failed to catch real issues.

I trust live validation more.

### Infrastructure layers

No ALB.

API Gateway connects directly to ECS through VPC Link and Cloud Map.

Public subnets only. No NAT gateway.

Security groups restrict ingress to port 3000 from the VPC Link.

Rolling deploys. Circuit breaker enabled. Health check grace period configured.

Boring infrastructure survives longer.

---

## The validation layer

After every deploy, a validation script runs against the live system.

No mocks. No test harness. Just `fetch` against real endpoints.

```text
GET  /api/health        → status is "ok"
POST /api/example       → item created
GET  /api/example       → item visible
DELETE /api/example/:id → cleanup
```

It also checks tenant isolation by overriding the `Host` header and verifying the created item is not visible across tenants.

If validation fails, the build fails.

There is no separate concept of "deployment succeeded" and "the system works".

They are the same thing.

The whole validation layer is one TypeScript file. It runs in a few seconds.

Every heavier post-deploy setup I built before this gave me more maintenance than confidence.

---

## The AI part changed the equation

This architecture existed before AI tooling.

AI made the repo more valuable.

The repo stopped being documentation. It became operational context.

When I start a new project, I point Copilot or Claude at the example project and tell it to scaffold a module that follows the same patterns.

The AI sees:

* controller structure
* DynamoDB key builders
* request context flow
* response envelopes
* Terraform conventions
* deployment patterns
* auth flows
* analytics integration

The generated code tends to fit because the patterns already exist in working systems.

The AI is not inventing architecture.

It's copying from a real operational baseline.

The same thing happens with infrastructure.

The Terraform already exists. The naming conventions already exist. IAM structure already exists. ECS wiring already exists.

I don't need giant prompts explaining conventions because the conventions are embedded in the repo itself.

AI tooling works best against systems that are internally consistent.

The architecture matters more now, not less.

Good patterns keep showing up because the AI reuses what is already there.

---

## What changed after real usage

The first version of this was mostly extraction.

Remove domain logic. Keep the structure. Make it reusable.

That changed once I started building real products on top of it.

I had already spent years building reusable Terraform modules, CI/CD pipelines, and ECS infrastructure patterns across different projects.

The current shape came together while building an email-driven album sharing platform. Multi-tenancy, inbound email handling, deployment flow, analytics, auth, and client boundaries all started using the same repo structure.

That became the basis for `reference-architecture`.

From there I used the reference architecture to scaffold newer systems, including a GTD app with web and mobile clients sharing the same backend and auth flow.

As the apps expanded, shared infrastructure kept moving out of product repos.

SES inbound routing. Terraform modules. Shared deployment patterns. Common auth flows.

Anything that survived repeated real usage moved down into the platform.

Auth stopped being demo code.

Magic links, session handling, mobile deep links, token verification, rate limiting. The implementation stayed small, but it became production code.

Mobile became a first-class client.

The backend did not need special mobile infrastructure. That was the point. Web and mobile stayed thin layers over the same API.

The architecture got tighter under pressure.

Anything that created friction got simplified or removed.

The system didn't really get bigger.

It got sharper.

---

## Why the architecture converged

Some of this looks like the Twelve-Factor App model.

Stateless processes. Config from environment variables. Disposable containers. Logs as streams.

That part wasn't planned. Those patterns survived because they made deploys and debugging less annoying.

Other decisions came from repeatedly building systems in AWS.

Multi-tenancy became a first-class constraint because retrofitting tenant isolation later is painful.

Async infrastructure stopped being the default because most early workloads did not justify it.

I stayed AWS-native because portability layers usually added more code without solving my actual problems.

The architecture wasn't designed upfront.

It slowly compressed under real usage.

---

## What this gives me now

The pipeline is deterministic.

Push to main. Build Docker image. Terraform apply. ECS stabilisation. Cloudflare apply. Validation.

Same steps every time.

The app binds to port 3000. The Dockerfile exposes 3000. ECS maps 3000. Security groups allow 3000. Health checks hit 3000.

Simple systems are easier to reason about. Easier to debug. Easier for AI tooling to work against.

Most importantly, new projects no longer start from infrastructure decisions.

They start from product logic.

The deployment plumbing already exists.

After ten years of rebuilding variations of the same backend, infrastructure, and deployment pipeline, I stopped treating them as separate projects.

Now there is one operational system.

New apps inherit it.

It keeps evolving under real pressure.
