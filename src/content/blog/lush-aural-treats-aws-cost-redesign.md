---
title: "How a $1,000 AWS Bill Made Me Redesign My ECS Architecture"
description: "I deployed a standard ECS architecture for Lush Aural Treats and didn't watch the bill. NAT gateways and ALBs quietly ate $1,000. Here's how I redesigned the whole thing to cost almost nothing."
date: 2026-03-24
tags: ["aws", "infrastructure", "ecs", "cost optimisation"]
draft: true
---

I've been building on AWS for over a decade. I know how the pricing works. I've designed cost-conscious architectures for companies that process millions of requests. I still managed to rack up a **$1,000 AWS bill** on a side project.

The project is [Lush Aural Treats](https://lushauraltreats.com), a music-focused API service running on ECS Fargate. Nothing exotic. Standard containerised workload, standard AWS architecture. The kind of setup you'd find in any "deploy to ECS" tutorial.

That's exactly the problem.

## TL;DR

I accidentally spent ~$1,000 running a small ECS project on AWS.

The main culprits:

- NAT Gateway
- Application Load Balancer

Original architecture:

```text
Cloudflare → ALB → ECS Fargate → NAT Gateway
```

New architecture:

```text
Cloudflare → API Gateway → Cloud Map → ECS Fargate
```

Baseline infrastructure cost dropped from ~$50/month to near zero.

The next step would be replacing Fargate with Lambda for event-driven workloads. Haven't done that yet, but it's on the list.

## The "standard" architecture

When I deployed Lush Aural Treats, I reached for the usual AWS primitives:

```text
Cloudflare
   ↓
ALB
   ↓
ECS Fargate (private subnet)
   ↓
NAT Gateway
   ↓
Internet APIs (Spotify, etc.)
```

**VPC with public and private subnets.** ECS tasks in the private subnet. An **Application Load Balancer** in the public subnet to route traffic in. A **NAT gateway** so the containers could reach external APIs. Cloudflare in front for DNS and CDN.

Textbook stuff. AWS themselves recommend this pattern. Deploy it, move on, build features.

I moved on. I built features. I didn't look at the bill.

## The bill

A few months later, I checked AWS Cost Explorer and the number staring back at me was roughly **$1,000**. For a side project. Running a handful of containers. Serving modest traffic.

My first thought was that something was misconfigured. A runaway task, maybe. A logging pipeline gone haywire. But the breakdown told a different story.

## Investigating the cost

The expensive parts weren't compute. They almost never are.

| Service | What I expected | What actually happened |
| --- | --- | --- |
| **NAT Gateway** | A few dollars | ~$32/month base + data processing fees |
| **ALB** | Cheap | ~$16/month base + LCU charges |
| **CloudWatch Logs** | Negligible | Log ingestion costs added up |
| **Data Transfer** | Minimal | NAT processing + cross-AZ traffic |
| **ECS Tasks** | The main cost | Actually the cheapest part |

The **NAT gateway** was the killer. It charges $0.045/hr in most regions, *plus* a per-GB data processing fee. If your containers are doing anything chatty (pulling images, polling APIs, downloading packages) that data processing fee compounds fast. Spotify API polling, container image pulls, health checks, dependency fetches. All of it flowing through NAT.

The **ALB** has its own baseline cost. Even idle, you're paying ~$16/month before a single request hits it. Add LCU-based charges for actual traffic and it's more.

**CloudWatch Logs** sneak up on you. Ingestion is priced per GB. If your containers are verbose (and most are by default), you're paying for every line.

Then there's **cross-AZ data transfer**. The ALB distributes across availability zones. Each cross-AZ hop costs money. Not a lot per request, but it adds up when you're not paying attention.

None of these are bugs. This is just how AWS pricing works for "standard" architectures. Nobody warns you in the getting-started guides.

The surprising part was that compute wasn't the problem. Most of the cost came from always-on infrastructure: the NAT gateway and Application Load Balancer.

## Rethinking the architecture

The goal was simple:

- **Keep ECS Fargate.** It works, I like it, the containerised workflow is solid.
- **Remove the NAT gateway.** The single biggest cost driver.
- **Remove the ALB.** Unnecessary overhead for my use case.
- **Keep service discovery.** Traffic still needs to find the right container.

What replaces them?

**API Gateway HTTP API + VPC Link + AWS Cloud Map.**

```text
Cloudflare
   ↓
API Gateway HTTP API
   ↓
VPC Link
   ↓
Cloud Map
   ↓
ECS Fargate (public subnet)
```

## Why this works

**API Gateway HTTP API** is AWS's lighter, cheaper alternative to REST API Gateway. Routing, throttling, auth. Pricing is pure pay-per-request: **$1 per million requests**. No hourly baseline. If nothing hits it, you pay nothing.

**VPC Link** connects API Gateway directly into your VPC without a public-facing load balancer. It replaces the ALB.

**AWS Cloud Map** handles service discovery. When ECS tasks launch, they register themselves in Cloud Map automatically. API Gateway resolves the service through Cloud Map to find the running container. No load balancer required.

**ECS tasks move to a public subnet** with a public IP. They reach external APIs directly. No NAT gateway. Security groups still control inbound access. The containers aren't exposed to the internet because API Gateway is the only ingress path through the VPC Link.

Most engineers haven't seen this pattern. Cloud Map has been around for years but rarely shows up in tutorials. Not glamorous. Just works.

## Cost comparison

| Component | Old | New |
| --- | --- | --- |
| ALB | ~$16/month | $0 |
| NAT Gateway | ~$32/month + data processing | $0 |
| API Gateway | — | ~$1/million requests |
| Cloud Map | — | $0.10/discovery query (negligible) |
| **Total baseline** | **~$50+/month before traffic** | **Near zero** |

The old architecture had a **$50+/month floor** just for existing. The new one is effectively **zero**. You only pay for what you use.

Over the months I wasn't paying attention, that $50+/month baseline plus NAT data processing fees and log ingestion quietly compounded into a four-figure bill. The kind of number that makes you rethink your entire approach to AWS side projects.

## The Cloudflare bonus

Cloudflare was already in front of everything, so the final stack picks up a few things for free:

- **WAF** at the edge
- **CDN** for static responses
- **DDoS protection** (Cloudflare absorbs volumetric attacks)
- **Cheap API routing** via API Gateway

Cloudflare, API Gateway HTTP API, VPC Link, Cloud Map, ECS Fargate. That's the entire production path. Five components. No load balancer, no NAT gateway, no idle costs.

Pretty modern infrastructure pattern. Simple enough to reason about, cheap enough to forget about.

## Tradeoffs

There are downsides.

**Fewer routing features.** ALBs give you path-based routing, host-based routing, weighted target groups, sticky sessions. API Gateway HTTP API is simpler. Fine for my use case. If you need advanced L7 routing, you'll miss the ALB.

**Less mature ecosystem.** Thousands of tutorials exist for ALB + ECS. VPC Link + Cloud Map has far fewer. When something breaks, you're reading AWS docs, not Stack Overflow.

**API Gateway limits.** 10 MB payload limit. 30-second timeout for HTTP APIs. Integration quirks. Know them before you commit.

For what Lush Aural Treats needs (a few API endpoints, modest traffic, external API integration) this is more than enough. Also fine for microservices, small SaaS products, and side projects where the alternative is quietly haemorrhaging money on idle infrastructure.

## What's next: replacing Fargate with Lambda

Once the architecture was simplified, it became obvious that the ECS service itself might also be overkill for this workload.

Fargate still means always-running compute. Even a small task (0.25 vCPU, 0.5 GB memory) costs ~$8-12/month just to exist. For a low-traffic side project, that's still paying for idle.

The Lush Aural Treats submission flow is event-driven by nature. An email arrives with an album link in the subject line. The system parses the link, fetches metadata, stores the submission, notifies users. Not a long-running server workload. A series of discrete events. Would map naturally to Lambda.

The architecture would become:

```text
Cloudflare
   ↓
API Gateway HTTP API
   ↓
Lambda
   ↓
S3 / DynamoDB / SES
```

This would remove **four components** at once: ECS cluster, Fargate tasks, Cloud Map, and VPC Link. The entire system would become event-driven. No orchestration. No service discovery. No container management.

For the email-based flow:

```text
SES inbound email
   ↓
Lambda
   ↓
Parse subject link → Fetch metadata → Store in DynamoDB → Notify via SES
```

For the web interface, API Gateway routes directly to Lambda. Same pattern, different trigger.

### What the costs would look like

| Component | Fargate (Version 2) | Lambda (Version 3) |
| --- | --- | --- |
| Compute | ~$8–12/month | Often < $1/month |
| API Gateway HTTP API | ~$1/million requests | ~$1/million requests |
| Cloud Map + VPC Link | ~$0.10 | $0 |
| **Total** | **~$10–13/month** | **Effectively free-tier** |

For low-traffic workloads, a Lambda version would fit inside the free tier. Fractions of a cent per invocation instead of dollars per month for idle containers.

### Why I haven't migrated yet

Fargate still makes sense for parts of the system that don't fit Lambda:

- **Long-running workers.** Lambda has a 15-minute execution limit. Background jobs that take longer need a container.
- **Heavy dependencies.** Some workloads have large runtime environments that push against Lambda's package size limits or cold start times.
- **Persistent connections.** WebSockets, long-polling, connection pooling. Containers handle these natively. Lambda doesn't.
- **Local development.** Running a container locally mirrors production almost exactly. Lambda local dev tooling exists but adds friction.

For the request-driven API endpoints and the email processing pipeline, Lambda would win. For everything else, Fargate would stay. I'll probably get around to this at some point, but the current architecture is already cheap enough that it's not urgent.

### Cold starts

Lambda cold starts are real. Typically ~100-300ms for Node.js or Python. For an API serving real users, that's noticeable on the first request after idle. Provisioned concurrency fixes it but adds cost, which defeats the purpose.

For Lush Aural Treats the traffic is bursty and infrequent enough that occasional cold starts are fine. If this were a user-facing app with latency SLAs, I'd think harder about it.

### The potential three-stage evolution

Looking back (and forward), the architecture has evolved through two stages with a third on the horizon:

**Version 1, Standard AWS:**

```text
Cloudflare → ALB → ECS Fargate → NAT Gateway
```

Cost surprise. ~$50+/month baseline before a single request. $1,000 bill.

**Version 2, Lean ECS (current):**

```text
Cloudflare → API Gateway → VPC Link → Cloud Map → ECS Fargate
```

Much cheaper. Near-zero baseline for routing. Still paying for always-on compute.

**Version 3, Fully Serverless (future):**

```text
Cloudflare → API Gateway → Lambda
```

Near-zero baseline cost. Pay only for what runs.

Each version removed components and cost. Each got simpler. Usually a good sign.

## The lesson

AWS's "standard" architectures are optimised for enterprise resilience, not cost. NAT gateways, ALBs, multi-AZ redundancy. They exist because large organisations need them and can afford them. When you copy-paste that architecture into a side project, you inherit the cost profile without needing the resilience.

The infrastructure that runs your side project shouldn't cost more than the side project earns. If it does, the architecture is wrong. Not the project.

I should have caught this earlier. I didn't. The rebuild is simpler, cheaper, and honestly better than what I had before. Sometimes the expensive mistakes teach you the most.
