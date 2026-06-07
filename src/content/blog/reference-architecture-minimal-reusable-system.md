---
title: "I Stopped Rebuilding the Same System"
description: "Over ten years, my projects kept turning into the same backend, infrastructure, tenancy, auth, deployment, and validation. I stopped treating those as fresh decisions for every product and pulled them into one reusable system."
date: 2026-06-08
tags: ["architecture", "aws", "infrastructure"]
draft: true
---

Over the last ten years, nearly every system I built kept converging into the same shape.

It didn't matter whether the project was a Spotify analytics tool, a Pokemon Go API, a Messenger bot, a GTD app, or an email-driven music sharing platform. After enough iterations, they all ended up looking similar underneath.

Stateless API. Docker container. Terraform. Multi-tenant data model. Auth boundary. CI/CD pipeline. Push to main, deploy to ECS, wait for stabilisation.

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

The deployment patterns settled into one model.

Auth stopped being per-project code and became a provider boundary.

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

The backend is a NestJS app with request context middleware that resolves the tenant and attaches a `requestId` to every request.

Tenant resolution is explicit now, not implicit. `TENANT_RESOLUTION_MODE` is either `fixed` or `subdomain`.

In `fixed` mode the tenant comes from `APP_TENANT_ID`. That suits single-product deployments where there is only ever one tenant.

In `subdomain` mode the tenant resolves from a subdomain under `BASE_DOMAIN`. Apex domains and localhost fall back to `default`. That suits multi-tenant deployments where each tenant gets its own subdomain.

Both modes produce tenant-prefixed DynamoDB keys, so the data model does not change when the resolution mode does. The earlier host-derived version was too implicit. Making the mode explicit removed a class of "which tenant am I" surprises.

Controllers delegate to services. Services talk to DynamoDB. Nothing else sits in the request path.

The Dockerfile is a multi-stage build. `node dist/main.js` runs the compiled output. Non-root user. Port 3000. Same image locally and in ECS Fargate.

The build pipeline does five things.

* Install dependencies
* Build the app
* Push the image to ECR
* Run Terraform
* Wait for ECS stabilisation

Then it applies the Cloudflare DNS layer and, when validation is enabled for that deployment, checks the live system. If a required step fails, the build fails.

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

Single DynamoDB table. PAY_PER_REQUEST.

Resources are scoped by tenant and user:

```text
PK = TENANT#<tenantId>
SK = USER#<userId>#EXAMPLE#<exampleId>
```

Tenant isolation and user ownership are separate boundaries. The partition keeps tenants apart. The sort key keeps users within a tenant apart. A client cannot supply its own `tenantId` or `userId` to reach across either boundary. The tenant comes from request context. The user comes from the local user mapping.

The local user is tenant-scoped:

```text
PK = TENANT#<tenantId>
SK = USER#<userId>
```

Auth identity maps to a local user through an identity record:

```text
PK = TENANT#<tenantId>
SK = USER_IDENTITY#<provider>#<sha256(providerSubject)>
```

The provider subject does not become the app's user model. It maps to a local user. That keeps the user model stable when the auth provider changes, and keeps provider subjects out of resource keys.

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

## The auth boundary

Auth used to be project-specific code. Now it is a provider boundary.

`AUTH_PROVIDER` is `none`, `internal_magic_link`, or `oidc`.

Internal magic-link auth covers first-party and simple apps. OIDC, backed by Auth0 in the demo deployment, covers deployments that need an external identity provider. The choice is configuration, not a rewrite.

For authenticated modes, the guard normalises provider identity into the same `AuthPrincipal`. Controllers and services do not know whether the request came through internal magic link or OIDC. `AUTH_PROVIDER=none` keeps protected routes closed unless a route is explicitly public.

`/api/auth/check` is a lightweight protected route that confirms the principal. `/api/me` is the local user boundary. It finds or creates a tenant-scoped user from the current `AuthPrincipal`.

The app does not trust auth or JWT claims for tenancy. Tenancy comes from the resolution mode. The principal identifies a provider subject, not a tenant. Keeping those separate is what lets the same backend run as a fixed-tenant app or a subdomain-tenant app without branching the code.

The browser frontend reads its auth behaviour at runtime from `/api/config`. The same frontend bundle supports different deployment auth modes. OIDC deployments expose only the public Auth0 SPA config they need. Magic-link deployments do not activate the OIDC UI. Nothing about the deployment's auth mode gets baked into the frontend build.

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

One deploy target per deployment. No fake staging copy by default.

This does not mean one deployment exists. Separate products and demos each get their own deployment. What I dropped is the mirror staging environment that sits alongside production and pretends to be it.

After deployment, validation can run against the live URL. If enabled validation fails, the build fails.

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

After deploy, a validation script can run against the live system.

No mocks. No test harness. Just `fetch` against real endpoints.

```text
GET  /api/health        → status is "ok"
POST /api/example       → item created
GET  /api/example       → item visible
DELETE /api/example/:id → cleanup
```

Validation is aware of the auth provider mode. The health check stays public. `AUTH_PROVIDER=none` validates the public surface only. Internal magic-link deployments run the full CRUD smoke path above. OIDC deployments check that `/api/auth/check` rejects missing bearer tokens, then validate the same route with a supplied bearer token when one is available.

In magic-link mode it also attempts a light tenant isolation check by resolving a second tenant and verifying the created item is not visible across tenants. If the proxy does not forward the overridden host, the script reports that check as skipped instead of pretending it proved isolation.

If validation fails, the build fails.

There is no separate concept of "deployment succeeded" and "the system works".

They are the same thing.

The whole validation layer is one TypeScript file. It runs in a few seconds.

Every heavier post-deploy setup I built before this gave me more maintenance than confidence.

---

## What changed after real usage

The first version of this was mostly extraction.

Remove domain logic. Keep the structure. Make it reusable.

That changed once I started building real products on top of it.

I had already spent years building reusable Terraform modules, CI/CD pipelines, and ECS infrastructure patterns across different projects.

The current shape came together while building an email-driven album sharing platform. Multi-tenancy, inbound email handling, deployment flow, analytics, auth, and client boundaries all started using the same repo structure.

That became the basis for `reference-architecture`.

From there I used the reference architecture to scaffold newer systems, including a GTD app with web and mobile clients sharing the same backend and auth boundary.

As the apps expanded, shared infrastructure kept moving out of product repos.

SES inbound routing. Terraform modules. Shared deployment patterns. The auth provider boundary.

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

## The part that changed under pressure

The shape held. The boundaries inside it got more deliberate.

Tenant resolution became explicit. A mode, not a guess off the `Host` header.

Auth became provider-neutral. A configured boundary, not a hard-wired flow.

Users became local app entities. Provider subjects map in, they do not leak through.

Resources became user-owned. Tenant isolation and user ownership are separate boundaries now.

Frontend config moved to runtime. One bundle, many deployment auth modes.

Validation became auth-provider-aware. It checks the system that actually got deployed.

None of these made the system bigger. Each one removed an assumption that only worked for one kind of deployment.

The same baseline now runs in more than one shape. The internal magic-link reference demo and a separate Auth0 OIDC demo come from the same architecture. They are not forks. They are the same system with different modes selected.

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
* the auth provider boundary
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

The deployment plumbing already exists. So does the tenancy model, the auth boundary, and the validation.

After ten years of rebuilding variations of the same backend, infrastructure, auth, tenancy, deployment, and validation, I stopped treating them as fresh decisions for every product.

`reference-architecture` is not just a starter template I copy and abandon. It is where architecture decisions go after they survive real use.

A new product can choose fixed or subdomain tenancy, internal magic-link or OIDC auth, web or mobile clients. It still inherits the same operational baseline.

That is the part worth keeping. Not the code. The decisions that stopped needing to be made again.
