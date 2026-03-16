---
title: "Building an Email-Driven Multi-Tenant Ingestion Pipeline"
description: "Most write interfaces are HTTP forms posting JSON. For Lush Aural Treats, submissions enter through email. Here's the architecture behind a tenant-aware ingestion pipeline where the inbox is the API."
date: 2026-03-31
tags: ["aws", "architecture", "serverless"]
draft: true
---

Most web applications expose their write interface through HTTP. A form posts JSON to an API endpoint, the backend validates it, stores it, and the UI updates. Standard.

For [Lush Aural Treats](https://lushauraltreats.com) I took a different approach. Submissions enter the system through email.

A user sends a message containing a link to an album. The system parses the email, validates the sender, resolves the tenant, enriches the metadata, and persists the album. The frontend surfaces it in the exchange feed.

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

Email avoids all of it. Authorised senders can submit from any device without visiting the site. Each exchange has a membership list. If your email is on it, you can submit. No login, no password, no session.

A submission looks like this:

```text
To: collective@parse.lushauraltreats.com
Subject: https://open.spotify.com/album/<id>
```

The subject line contains the album URL. No attachments, no body parsing, no structured payload. The email itself is the request.

---

## System overview

Once the email arrives it moves through a small ingestion pipeline. The pipeline validates the submission, resolves the tenant, enriches the album metadata, and persists it to the exchange feed.

Each stage has a single responsibility:

```text
Email
  ↓
SES (receive)
  ↓
Lambda (forward to API)
  ↓
NestJS application
  ├─ Resolve tenant
  ├─ Validate sender
  ├─ Extract + validate link
  ├─ Deduplicate
  ├─ Enrich metadata (Spotify API)
  └─ Persist album
  ↓
Frontend read model
```

Six things happen:

1. SES receives the email and triggers a Lambda
2. The Lambda forwards the payload to the application as an HTTP POST
3. The application resolves the tenant and validates the sender against the membership list
4. It extracts and validates the album link from the subject line
5. Spotify enrichment fetches metadata (titles, artwork, genres)
6. The album is persisted to DynamoDB

The controller returns a 202 immediately. Enrichment and persistence continue asynchronously inside the service layer after the HTTP response is sent. The sender gets an acknowledgement email right away, then a second email with the result once processing finishes.

The frontend reads from DynamoDB via the albums API. No websockets, no push notifications, no real-time sync. Just a read model that reflects the current state of the exchange.

---

## Email ingestion

Inbound email is routed through SES to a Lambda function. The Lambda is a thin HTTP bridge. It extracts three fields from the SES event and POSTs them to the application:

```json
{
  "from": "user@example.com",
  "subject": "https://open.spotify.com/album/...",
  "to": "collective@parse.lushauraltreats.com"
}
```

That's all the Lambda does. No parsing, no validation, no business logic. It translates an SES event into an HTTP request.

The NestJS application receives the payload and runs the pipeline. The first step is link extraction. Only the subject line matters. No multipart parsing, no attachment handling, no content decoding.

```text
albumUrl = extractMusicLink(subject)

if (!albumUrl) {
  rejectSubmission()
  return
}
```

Early rejection keeps the pipeline clean. If the subject line isn't a recognisable album URL, the submission is dropped immediately.

---

## Sender validation

Not anyone can submit. Each exchange maintains a membership list stored in DynamoDB as `MEMBER#` records under the tenant partition. The security service checks whether the sender's email appears in that list before the pipeline continues.

```text
securityCheck = validateSender(tenantSlug, senderEmail)

if (!securityCheck.allowed) {
  rejectWithReason(securityCheck.reason)
  return
}
```

Rate limiting runs alongside the membership check. Each member has a submission cap per rolling period to prevent flooding. The rate limit records use DynamoDB's TTL to auto-expire after each period ends.

In development, tenants with no member records allow all senders. In production, every exchange requires explicit membership.

---

## Normalising album links

Album URLs appear in different formats depending on how they're shared. Copy from the Spotify app, the web player, or a share sheet and you get different strings for the same album:

```text
https://open.spotify.com/album/<id>
https://open.spotify.com/album/<id>?si=abc123
https://spotify.link/<shortcode>
```

Short links (`spotify.link`) are resolved by following the redirect to get the full `open.spotify.com` URL. Query parameters are stripped. The result is a consistent URL that can be used for deduplication and API lookups.

Not glamorous, but essential. Without it, the same album submitted twice via different URL formats would be stored as two separate entries.

The system also validates the content type. Only albums are accepted. Tracks and playlists get rejected with a descriptive error message sent back to the submitter.

---

## Tenant resolution

Lush Aural Treats is a **multi-tenant system**. Every submission must resolve to a tenant before being persisted. There is no default fallback.

It started as a single tenant. The original feed lived on the apex domain at lushauraltreats.com. As the product evolved, the apex became a landing page linking out to separate exchanges. The original feed moved to Lush Collective under collective.lushauraltreats.com.

The email address is the routing key. Each tenant has its own submission address:

```text
collective@parse.lushauraltreats.com  → TENANT#collective
demo@parse.lushauraltreats.com        → TENANT#demo
```

The local part maps directly to a tenant slug. No lookup table, no API call. The routing information is in the address itself.

```text
tenant = extractLocalPart(toAddress)
```

For the web frontend, the application resolves tenant from the hostname instead. A middleware extracts the subdomain:

```text
collective.lushauraltreats.com  → slug = "collective"
demo.lushauraltreats.com        → slug = "demo"
```

Either way, tenant resolution happens at the start of the pipeline. Everything downstream already knows which tenant it's dealing with.

---

## DynamoDB data model

Albums are stored in DynamoDB using a **single-table design**.

The primary key identifies each album:

```text
PK: ALBUM#<spotify_album_id>
SK: META
```

A global secondary index (GSI) partitions albums by tenant:

```text
GSI1PK: TENANT#collective
GSI1SK: <created_at>
```

This gives two access patterns from one table.

**Direct lookup** uses the primary key. Given a Spotify album ID, fetch the full record in a single read. This powers deduplication checks and individual album pages.

**Tenant feed** uses the GSI. The most common read operation is "fetch recent albums for an exchange":

```text
GSI1PK = TENANT#collective
ScanIndexForward = false
```

One query, sorted by date, scoped to a single tenant. No joins, no secondary filtering. DynamoDB returns exactly what the frontend needs, in the order it needs it.

Other entity types share the same table: tenants (`TENANT#<slug>` / `META`), members (`TENANT#<slug>` / `MEMBER#<email>`), and rate limit counters (`RATE_LIMIT#<tenant>#<email>` / `<period>`). Different key prefixes, same table.

Because albums are append-only, the model maps well to DynamoDB's strengths. That property removes a large class of concurrency and consistency problems. No updates to existing items, no complex transactions, no read-modify-write cycles. Write an album, read it back later. That's the entire data flow.

---

## Idempotency

Email systems occasionally retry deliveries or duplicate messages. SES can invoke the Lambda more than once for the same inbound email. If the pipeline isn't idempotent, you get duplicate albums.

Two checks run before persisting:

```text
if (existsBySpotifyId(albumId, tenant)) {
  return  // duplicate submission
}

if (existsByTitleAndArtist(title, artist, tenant)) {
  return  // different edition, same album
}
```

The first catches exact duplicates, same Spotify ID submitted twice. The second catches different editions or regional releases where the Spotify ID differs but the album is effectively the same.

No distributed locks, no deduplication queues. Two conditional checks at the persistence boundary.

---

## Metadata enrichment

Once the link passes validation and deduplication, the background pipeline kicks in. For Spotify submissions, the application calls the Spotify API (client credentials flow) to fetch album metadata: title, artist, artwork, release date, track count, genres.

This metadata is stored alongside the album record and powers the frontend display. Without it, each album in the feed would be a bare URL.

If the Spotify API call fails, the album is still persisted with whatever information is available. Enrichment failure doesn't block submission. The album shows up in the feed either way.

---

## Why multi-tenant from the start

Most side projects start single-tenant and retrofit multi-tenancy later. I went the other way.

In this system the overhead was small:

- A `resolveTenant()` function that returns a slug
- A tenant-prefixed partition key in DynamoDB
- A routing decision at ingestion time

Three small additions, but they keep the data model explicit and make adding new exchanges trivial. In return:

**Cleaner domain model.** Every entity belongs to a tenant. There's no ambiguity about scope or ownership. The data model is explicit about boundaries from the start.

**Simple routing.** New tenants don't require new infrastructure, new databases, or new deployments. They need a new GSI partition key value and a DNS record.

**Adding tenants is additive.** When I added the Demo Exchange, the work was: pick a slug, configure a route, deploy. No migration, no refactor, no downtime.

Retrofitting multi-tenancy into a single-tenant system sounds straightforward. It never is. Data needs migrating, queries need scoping, isolation needs verifying across every access path. Cheaper to model it correctly from the start.

---

## The complete picture

At this point the pieces fit together into a single pipeline.

The full flow:

```text
User sends email
  ↓
SES receives at <slug>@parse.lushauraltreats.com
  ↓
Lambda forwards { from, to, subject } to API
  ↓
Application: resolve tenant from to-address
  ↓
Validate sender against membership list
  ↓
Extract album link from subject, validate platform
  ↓
Deduplication check (Spotify ID + title/artist)
  ↓
Return 202, send acknowledgement email
  ↓
Background: Spotify enrichment → persist to DynamoDB
  ↓
Send result email to submitter
  ↓
Frontend queries DynamoDB → renders feed
```

Each step does one thing. The entire pipeline from email to UI is a straight line.

No message queues. No event buses. No saga orchestrators. The Lambda forwards, the application processes, DynamoDB stores. If validation fails, the sender gets an error email explaining what went wrong. If it succeeds, they get a confirmation with the album details.

---

## Lessons learned

After building and running the pipeline for a while, a few patterns became clear.

**Email works well as an ingestion interface** when the payload is simple. A subject line containing a URL is about as minimal as input gets. No schema versioning, no content negotiation, no API contracts to maintain. The tradeoff is that you can't do anything complex with it. For album links, that's fine.

**Minimal inputs simplify everything downstream.** One URL in, one canonical form out. Validation is a single function. Parsing is a single function. The entire ingestion layer fits in a few hundred lines. Simple inputs create simple systems.

**Multi-tenant modelling is easier at the start.** Once the key structure includes a tenant prefix, every query is automatically scoped. It's the kind of decision that costs almost nothing to make on day one and costs a lot to make on day one hundred.

**Ingestion pipelines don't need to be complicated.** There's a temptation to reach for Step Functions, SQS, SNS, EventBridge, the full AWS eventing toolkit. For a pipeline with simple validation and a single persistence target, a Lambda bridge and an application service are enough. Add complexity when the requirements demand it, not before.

---

## Closing thoughts

Together with the [infrastructure redesign](/blog/lush-aural-treats-aws-cost-redesign), these two posts cover both sides of the Lush Aural Treats architecture. The first dealt with infrastructure and cost. This one covers application design and data flow.

The interesting thing about this system isn't any one component. It's that the simplest possible interface, a single email, drives a tenant-aware pipeline from ingestion to persistence to UI.

No forms, no auth flows, no elaborate API contracts. Just a subject line and a pipeline that knows what to do with it.
