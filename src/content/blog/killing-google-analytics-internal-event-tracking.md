---
title: "Why Google Analytics Was Useless for My Product"
description: "Google Analytics tracked page views in a product where page views don't matter. I ripped it out and replaced it with internal event tracking and Cloudflare. Here's what I built and what I learned."
date: 2026-04-08
tags: ["analytics", "architecture", "cloudflare"]
#heroImage: "killing-google-analytics-internal-event-tracking-hero.png"
draft: true
---

Google Analytics was useless for this product.

Not broken. Just measuring the wrong things.

[Lush Aural Treats](https://lushauraltreats.com) is an email-driven music sharing platform. Users submit albums by sending an email. A backend pipeline parses the submission, enriches it with metadata, generates a review, and persists it to a tenant-scoped feed. Other members get notified. They react, browse, listen.

The product is the pipeline and the email loop. Page views are just a side effect.

Google Analytics sat on the frontend collecting session data and bounce rates. The product ran on the backend. I was looking at dashboards that told me nothing about whether the system was working.

So I killed it.

## What the product actually does

The real flow looks like this:

```text
Email → SES → Lambda → NestJS pipeline → DynamoDB → Feed → Email notification → Interaction
```

A member sends an album link in the subject line of an email. The system validates the sender, resolves the tenant, enriches metadata from Spotify, generates an AI review, and writes the album to the feed. Other members get notified. They visit the feed, react, browse, maybe submit their own album. That triggers the loop again.

In a [previous post](/blog/email-driven-multi-tenant-ingestion-pipeline) I covered the ingestion pipeline in detail. The point here is simpler: **the interesting behavior happens server-side**. A user opening the feed page is the least interesting event in the chain. The interesting events are: did someone submit an album? Did the pipeline complete? Did anyone react?

Google Analytics couldn't answer any of those questions.

## What I actually needed to know

The questions I kept asking weren't "how many page views did the feed get?" They were:

- Did a new exchange actually activate after setup?
- Did someone send the first album?
- Did the pipeline finish without errors?
- How long did the pipeline take?
- Did other members respond with reactions?
- How long between the first album and the first reaction?

These are product health questions. Some are backend events. Some are timing. None map to a page view.

I was opening Google Analytics, staring at traffic graphs, then switching to CloudWatch logs for the answers that actually mattered. Two systems. Only one useful.

## Separating concerns

Different layers answer different questions.

**Traffic and referrers** are infrastructure concerns. How much traffic is hitting the site? Where is it coming from? Is anything getting hammered? I already had Cloudflare in front of the app. DNS, CDN, WAF, DDoS protection. The analytics dashboard shows requests, bandwidth, top paths, referrers, and country breakdown. I was paying for this data and ignoring it.

**Product behavior** is an application concern. Which events happened? In what order? How long did things take? This is what I needed to build.

Google Analytics didn't fit either layer. Too shallow for product insight, too heavy for traffic monitoring. Cloudflare covers one side. Internal tracking covers the other.

## Removing Google Analytics

It was anticlimactic. Delete the script tag. Delete the gtag config. Deploy.

The frontend got slightly cleaner. No third-party scripts loading on every page. No cookie consent concerns. No data flowing to Google for a product where I wasn't using it anyway.

The real benefit was clarity. One fewer system to check, one fewer dashboard showing numbers that don't connect to product decisions.

## Building internal event tracking

I replaced it with an append-only event system in DynamoDB, alongside the rest of the application data. The same single-table design from the [previous post](/blog/email-driven-multi-tenant-ingestion-pipeline), extended with an `ANALYTICS_EVENT` entity type.

The event model:

```text
PK: ANALYTICS#<tenantId>#<partition>
SK: <timestamp>#<eventId>
```

Each event has a type, tenant, timestamp, and an optional metadata object. Events are partitioned by tenant, so queries are always scoped. No cross-tenant reads. The partition suffix spreads writes across multiple physical partitions to avoid hot keys.

The event set is small. About 15 types total:

```text
Backend events:
album_submitted
pipeline_started
pipeline_completed
pipeline_failed
metadata_fetched
review_generated
reaction_added
reaction_removed
notification_sent

Frontend events:
feed_viewed
album_viewed
preview_played
filter_applied
```

Backend events fire inside the NestJS service layer. When the pipeline processes an album, it emits `pipeline_started` at the beginning and `pipeline_completed` or `pipeline_failed` at the end. Reactions emit when toggled. Notifications emit when sent.

Frontend events are minimal. Four types, all tracked via a simple POST from the client. The `feed_viewed` event fires once per page load with a guard to prevent duplicates from BFCache `pageshow` events.

The whole thing is fire-and-forget. Event tracking never blocks the main flow. If DynamoDB write fails, the event is lost. That's fine. Analytics data doesn't need the same durability guarantees as album data.

## Pipeline timing

This was the most useful part of the system.

Each pipeline run records timing across its stages:

```text
{
  type: "pipeline_completed",
  durationMs: 4200,
  metadata: {
    stageDurations: {
      metadata_fetch: 800,
      review_generation: 2900,
      persistence: 150,
      notification: 350
    }
  }
}
```

A few things stood out quickly.

**AI review generation dominates pipeline time.** The OpenAI call for generating album reviews takes 2-4 seconds on average. Everything else combined is under a second. If the pipeline feels slow, that's where the time goes.

**Spotify metadata fetch is fast but occasionally spikes.** Usually 200-400ms. Sometimes over a second. Enough variance to notice, not enough to fix.

**The gap between the first album and the first reaction tells you if an exchange is alive.** If someone submits an album and nobody reacts within a few days, the exchange isn't working. This metric, `time_to_first_reaction`, was impossible to measure with Google Analytics. With internal events it's a derived query across two event types.

## Guardrails

Building your own analytics is easy. Keeping it from becoming messy is the hard part.

I've seen internal analytics systems turn into unmanageable monsters. Every team adds their own events. Metadata blobs grow unbounded. Queries slow down. Nobody trusts the data. I didn't want that.

**Metadata caps.** Every event metadata object is capped at 1KB. Each event type has a whitelist of allowed fields. Unknown fields get stripped. String values get truncated. This prevents the "let me just add one more field" creep that bloats analytics tables.

**Per-event schemas.** Not every event gets the same metadata. `pipeline_completed` includes `stageDurations`. `reaction_added` includes `albumId`. `feed_viewed` includes the tenant slug and not much else. The validation layer enforces this per event type.

**Dedup on both sides.** The frontend deduplicates `feed_viewed` so rapid page transitions don't generate noise. Five-second dedup window on the backend prevents duplicate writes from retries or race conditions. The dedup key includes the event type, tenant, and relevant entity ID.

**Bounded queries.** Pipeline timing queries cap at 500 items. Global summary queries cap at 5,000 items. No unbounded scans. The admin endpoints include a 30-second in-memory cache so repeated requests don't hammer DynamoDB.

**No dashboards.** This one surprised me. I built admin API endpoints for querying analytics, not a dashboard UI. The data is available via authenticated GET requests. I check it when I need to. Not having a dashboard means I don't compulsively refresh metrics. It also means I didn't spend a week building charts.

## What I lost

To be fair, I did lose a few things.

**Traffic funnels.** I can't see the path a user takes through the site. Cloudflare shows top pages but not navigation flow. For this product that's fine. The "funnel" is email to feed to reaction. It doesn't run through multiple pages.

**Session tracking.** I don't know how long someone spends on the feed or how many pages they visit per session. Cloudflare gives me unique visitors and total requests, but not session depth. The product uses token-based auth via email links, not traditional sessions. Session tracking was already unreliable.

**Historical comparison.** Google Analytics had months of data. Starting fresh means no baseline. The first few weeks of internal analytics are just establishing what normal looks like.

## What I gained

**Actual product visibility.** I can see when exchanges are active, when pipelines fail, how long things take, and which tenants are engaged. None of this was visible before.

**A simpler system.** One fewer third-party dependency. No cookie banners. No client-side SDK. No data processor agreement with Google. The analytics live in the same DynamoDB table as everything else.

**Performance visibility.** Pipeline timing showed me where time was going. The AI review generation stage was the obvious bottleneck. Without this, I would have been guessing.

**Privacy by default.** No personal data in the analytics. Events are tenant-scoped, not user-scoped. I store what happened, not who did it. No IP addresses, no device fingerprints, no tracking cookies. This wasn't a design goal. It just fell out of tracking product events instead of user behavior.

## When this approach works

This isn't universal advice. Internal analytics made sense here because:

**The product is backend-heavy.** Most meaningful events happen server-side. If your product is a rich client-side app where the interesting behavior is clicks and scrolls, Google Analytics or something like it might still be the right tool.

**The user flow is non-standard.** Email-driven, token-based, multi-tenant. Standard analytics tools assume browser sessions with authenticated users navigating pages. That's not this product.

**It's early-stage.** A small event set covering the core product loop is enough. If Lush Aural Treats had 50 features and 200 event types, I'd probably want a proper analytics platform. At 15 events, a DynamoDB table and a few API endpoints do the job.

**Cloudflare is already there.** Traffic-level analytics are covered. I didn't need to build that part. If I didn't have Cloudflare, I'd still need something for traffic visibility and removing Google Analytics would have left a bigger gap.

## Closing

The whole change took less time than I expected. Remove GA. Add a DynamoDB entity type. Instrument the pipeline. Add a few client events. Wire up admin endpoints. Deploy.

The system now tells me what I actually want to know, not how many visitors hit the landing page. Whether the product is working. Whether albums are flowing through the pipeline. Whether people are reacting. How fast things run.

Google Analytics is good software. It just wasn't the right fit for a product where the inbox is the interface and the backend is the product.
