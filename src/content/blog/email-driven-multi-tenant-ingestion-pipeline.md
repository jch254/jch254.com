---
title: "Building an Email-Driven Multi-Tenant Ingestion Pipeline"
description: "Most write interfaces are HTTP forms posting JSON. For Lush Aural Treats, submissions enter through email. Here's the architecture behind a tenant-aware ingestion pipeline where the inbox is the API."
date: 2026-03-17
tags: ["aws", "architecture", "serverless", "lush aural treats"]
draft: true
---

Most web applications expose their write interface through HTTP. A form posts JSON to an API endpoint, the backend validates it, stores it, and the UI updates. Standard stuff.

For [Lush Aural Treats](https://lushauraltreats.com) I took a different approach. Submissions enter the system through email.

A user sends a message containing a link to an album. The system parses the email, validates the link, resolves the tenant, and persists the submission. The frontend surfaces the album in the exchange feed.

In effect, **email becomes the ingestion API**.

In a [previous post](/blog/lush-aural-treats-aws-cost-redesign), I covered the infrastructure side: how a $1,000 AWS bill forced a complete architecture redesign. This post covers the application side: the ingestion pipeline that processes submissions and why building it as multi-tenant from day one was worth the effort.

---

## The goal: zero-friction submissions

The product constraint was simple. Submitting an album should be as frictionless as possible.

Traditional approaches introduce overhead that doesn't serve the user:

- **Authentication flows.** Sign up, verify email, log in, stay logged in. All of that for a single album link.
- **Form validation UX.** Client-side validation, error states, loading spinners, success toasts.
- **Mobile friction.** Tiny input fields, soft keyboards, slow page loads on cellular.
- **Another UI surface to maintain.** Another page, another component, another thing that can break.

Email avoids all of it. Anyone can submit from any device without visiting the site.

A submission looks like this:

```text
To: music@parse.lushauraltreats.com
Subject: https://open.spotify.com/album/<id>
```

The subject line contains the album URL. No attachments, no body parsing, no structured payload. The email itself is the request.

---

## System overview

The pipeline is conceptually simple. A series of stages, each with a single responsibility:

```text
Email
  ↓
Inbound email handler (SES)
  ↓
Lambda
  ↓
Application service
  ↓
Tenant resolution
  ↓
DynamoDB persistence
  ↓
Frontend read model
```

Five things happen in sequence:

1. Accept the email event
2. Parse the submission
3. Validate the album link
4. Determine the tenant
5. Persist the submission

The frontend reads from the resulting dataset. No websockets, no push notifications, no real-time sync. Just a read model that reflects the current state of submissions.

---

## Email ingestion

Inbound email is routed through SES to a parsing endpoint. The parser extracts a minimal payload:

```json
{
  "from": "user@example.com",
  "subject": "https://open.spotify.com/album/...",
  "to": "music@parse.lushauraltreats.com"
}
```

Only the subject line matters. No multipart parsing, no attachment handling, no content decoding. The interesting part of the email is a single string.

The ingestion Lambda performs the first validation step:

```text
albumUrl = parseSubject(subject)

if (!isValidAlbumUrl(albumUrl)) {
  rejectSubmission()
  return
}
```

Early rejection keeps the pipeline clean and prevents unnecessary downstream processing. If the subject line isn't a recognisable album URL, the submission is dropped immediately. No queuing, no retry, no dead letter queue for malformed input.

---

## Canonicalising album links

Album URLs appear in different formats depending on how they're shared. Copy from the Spotify app, the web player, or a share sheet and you get different strings for the same album:

```text
https://open.spotify.com/album/<id>
https://open.spotify.com/album/<id>?si=abc123
spotify:album:<id>
```

The ingestion layer normalises these into a canonical form before anything else happens:

```text
albumId = extractSpotifyAlbumId(url)
canonicalUrl = "https://open.spotify.com/album/" + albumId
```

Not glamorous, but essential. Without it, deduplication breaks. The same album submitted twice via different URL formats would be stored as two separate submissions. Consistent storage depends on consistent input.

---

## Tenant resolution

Lush Aural Treats is designed as a **multi-tenant system** even though it currently runs with a single tenant. Every submission must resolve to a tenant before being persisted.

The backend performs resolution using the request context:

```text
tenant = resolveTenant(hostHeader)
```

When submissions originate from email, resolution falls back to a default tenant:

```text
tenant = DEFAULT_TENANT
```

But the architecture is designed so that the email address itself can become the routing key. Future versions could support tenant-aware addresses:

```text
lush@parse.domain.com     → TENANT#lush
jazz@parse.domain.com     → TENANT#jazz
friends@parse.domain.com  → TENANT#friends
```

The local part of the email address maps directly to a tenant. No additional configuration, no lookup table, no API call. The routing information is embedded in the address.

```text
tenant = resolveTenant(emailLocalPart)
```

This is the bridge between ingestion and multi-tenancy. The pipeline is tenant-aware from the very first stage. It doesn't bolt on tenant resolution later. It doesn't retrofit isolation. The submission knows where it belongs before it's even validated.

---

## DynamoDB data model

Submissions are stored in DynamoDB using a **single-table design**.

The key structure:

```text
PK: TENANT#lush
SK: SUBMISSION#<timestamp>
```

Simple partition strategy. It works well for a few reasons.

**Tenant isolation** is a natural property of the key structure. Every query is scoped to a partition key. One tenant can never accidentally read another tenant's data. There's no `WHERE tenant = ?` filter to forget. The isolation is structural.

**Query patterns** map directly to the access pattern. The most common read operation is "fetch recent submissions for a tenant":

```text
PK = TENANT#lush
SK begins_with SUBMISSION#
ScanIndexForward = false
```

That's a single query. No joins, no secondary indices, no aggregation. DynamoDB returns exactly what the frontend needs, in the order it needs it.

**Scaling** is handled by DynamoDB's partitioning. Each tenant lives in its own partition space. As tenants are added, capacity scales horizontally. No sharding logic, no connection pooling headaches, no migration scripts.

Because submissions are append-only, the model maps well to DynamoDB's strengths. There are no updates to existing items, no complex transactions, no read-modify-write cycles. Write a submission, read it back later. That's the entire data flow.

---

## Idempotency

Email systems occasionally retry deliveries or duplicate messages. SES can invoke the Lambda more than once for the same inbound email. If the pipeline isn't idempotent, you get duplicate submissions.

Before persisting, check whether the canonical album ID already exists for the tenant:

```text
if (submissionExists(canonicalAlbumId, tenant)) {
  return  // already submitted
}
```

This keeps the pipeline safe from repeated deliveries without distributed locks, deduplication queues, or coordination between services. A simple conditional check at the persistence boundary.

---

## Why multi-tenant from the start

Most side projects don't bother with multi-tenancy. Single user, single tenant, ship it. Refactor later if it ever matters.

I went the other way. And it was cheap to do.

The overhead of multi-tenancy in this system is minimal:

- A `resolveTenant()` function that returns a string
- A partition key prefix in DynamoDB
- A routing decision at ingestion time

That's it. Three small additions to the codebase. In return:

**Cleaner domain model.** Every entity belongs to a tenant. There's no ambiguity about scope or ownership. The data model is explicit about boundaries from the start.

**Simple routing.** New tenants don't require new infrastructure, new databases, or new deployments. They require a new partition key value.

**Easier future expansion.** If Lush Aural Treats ever supports multiple exchanges (and the architecture already anticipates it), the work is additive. Add a tenant, configure a route, done. No migration, no refactor, no downtime.

Retrofitting multi-tenancy into a single-tenant system sounds straightforward. It never is. Data needs to be migrated, queries need scoping, isolation needs verifying across every access path. It's cheaper to model it correctly from the start, even if you only have one tenant.

---

## The complete picture

The full flow:

```text
User sends email
  ↓
SES receives and parses
  ↓
Lambda: parse subject → validate URL → canonicalise
  ↓
Resolve tenant from email address or default
  ↓
Idempotency check against DynamoDB
  ↓
Persist submission (PK: TENANT#x, SK: SUBMISSION#timestamp)
  ↓
Frontend queries DynamoDB → renders feed
```

Seven stages. Each one does one thing. The entire pipeline from email to UI is a straight line.

No message queues. No event buses. No saga orchestrators. No retry policies with exponential backoff. Just a Lambda that parses, validates, resolves, checks, and writes. If any step fails, the submission is dropped. Email is inherently fault-tolerant. The sender can always resend.

---

## Lessons learned

**Email works well as an ingestion interface** when the payload is simple. A subject line containing a URL is about as minimal as input gets. No schema versioning, no content negotiation, no API contracts to maintain. The tradeoff is that you can't do anything complex with it. For album links, that's fine.

**Minimal inputs simplify everything downstream.** One URL in, one canonical form out. Validation is a single function. Parsing is a single function. The entire ingestion layer fits in a few hundred lines. Simple inputs create simple systems.

**Multi-tenant modelling is easier at the start.** Once the partition key includes a tenant prefix, every query is automatically scoped. It's the kind of decision that costs almost nothing to make on day one and costs a lot to make on day one hundred.

**Ingestion pipelines don't need to be complicated.** There's a temptation to reach for Step Functions, SQS, SNS, EventBridge, the full AWS eventing toolkit. For a synchronous pipeline with simple validation and a single persistence target, a Lambda function is enough. Add complexity when the requirements demand it, not before.

---

## Closing thoughts

Together with the [infrastructure redesign](/blog/lush-aural-treats-aws-cost-redesign), these two posts cover both sides of the Lush Aural Treats architecture. The first dealt with infrastructure and cost. This one covers application design and data flow.

The interesting thing about this system isn't any one component. It's that the simplest possible interface, a single email, drives a tenant-aware pipeline from ingestion to persistence to UI.

No forms, no auth flows, no elaborate API contracts. Just a subject line and a pipeline that knows what to do with it.
