---
title: "Google, NZ Post, and Internet Archaeology"
description: "A normal parcel-status search found an old CourierPost interface. The risk was not one page, but what Google made discoverable."
date: 2026-05-13
tags: ["security", "responsible disclosure", "internet"]
draft: true
---

After almost two months of silence, NZ Post replied to my disclosure on the same day I sent a firmer follow-up.

Two days later, they confirmed the affected legacy page had been expedited for decommissioning. It now redirected to the modern parcel tracking service, and they had asked for the outdated result to be removed from public search.

Good outcome.

Still a weird one.

The part that stuck with me was not that I had found some clever exploit. I had not. I was trying to understand a parcel status on one of my own deliveries, searched Google, and ended up looking at an old CourierPost interface that should not have been discoverable that way.

That pattern felt familiar.

Years before LLMs, I used Google from New Zealand to track down and eventually make contact with my German father. It was not magic. It was fragments. Names, old pages, cached traces, technical communities, and enough patience to keep following the edges.

That changed how I saw search. It was never just a convenience layer over the web. It was a way to connect things that were technically public, but not obvious.

That was a good outcome for me, but it also made the web feel different. Less like a set of pages. More like a memory system nobody fully controls.

I am writing about it now because the affected page has been decommissioned, and because I am leaving out the details that would make it reproducible.

---

## Search has always been stranger than people think

The status was "Redirection requested". I Googled the phrase to find out how long that usually took. One of the results was an older CourierPost track-and-trace page.

It had an account number prefilled and a date field. I ran the search out of curiosity. The interface came back with a warning that more than 200 records were available.

That was the bit that changed it.

The interface was not asking for a tracking number. It was offering me a way to discover them.

---

## What I found

I am not going to walk anyone through how to reproduce this. The URL does not matter here. The shape of the system does.

An older public search page on a CourierPost track-and-trace host. It took an account number and a date and returned shipment records. The account number was already filled in. Narrowing by status returned a list of tracking numbers.

Each record had the usual tracking-page information. Status history. Movement timestamps. The sender business that booked the courier. The name of whoever signed. Some signature metadata. A rough delivery locality.

If you already know a tracking number, none of that is surprising. Tracking pages are designed to be reachable. That is fair.

The concern was that the search interface flipped the direction. You did not need a tracking number. You arrived with a date and walked away with a list.

That is a different security posture. There was no credential boundary. The real boundary was obscurity.

---

## Boring metadata, in aggregate

A single tracking record looks mundane. That is true.

It only stays mundane while records stay isolated.

The same fields at scale tell a different story. The senders are businesses with logistics patterns. The signers are real people. The dates form timelines. The localities form rough maps. Across enough records, you can describe how a sender ships, when, where, and to whom.

None of that is a credit card number or a home address. That is part of why I tried to be measured in the disclosure.

But this is the aggregation problem. Boring metadata stops being boring once you can stack it.

---

## The disclosure

I asked for advice before doing anything public. Someone with more infosec and media experience sanity-checked it.

Tracking data is often already accessible if you know the tracking number. There were no addresses or contact details in the records. What stood out was access to lists of tracking numbers, the prefilled account number, and an old corporate-facing interface ending up in Google. There also appeared to be an indexing-control mismatch. The kind of small legacy detail that looks boring until it leaves the wrong thing visible in search. Old-school Google dorking, basically. Not against some hardened target. Against software nobody seemed to be thinking about anymore.

On 13 March 2026 I sent NZ Post Cyber Security a responsible disclosure. I described it as a legacy CourierPost search interface enabling enumeration of tracking numbers and shipment metadata. I estimated severity as medium to high, mostly because of discoverability rather than per-record sensitivity. I said I had not collected data beyond confirming the behaviour, and offered to provide additional details privately if needed.

I followed up on 24 March. Nothing.

On 6 May, after almost two months of silence, I sent a firmer follow-up and asked whether it would be better with media involvement. They replied the same day. They apologised for missing the earlier emails and said they were reviewing it.

On 8 May, NZ Post replied again. They said the affected legacy page had already been scheduled for decommissioning, and that after confirming my report they expedited that work. The page now redirected to the modern parcel tracking service. They had also submitted a request to remove the outdated result from public search.

That was enough to write about it at a high level. I am still leaving out the details that would help someone rediscover the old interface.

I am not going to dunk on them for the silence. The eventual response was reasonable and the fix was correct.

I will say this. Disclosure channels need to work. Silence puts the reporter in an awkward position, and two months of it made me consider going to media to force movement. That is bad for everyone involved.

---

## Internet archaeology

Old systems do not become safe because nobody remembers them. Internet-facing legacy software becomes archaeology. It sits there, still running, still indexed, still answering requests, until a search engine, a crawler, a cache, or a curious person follows an edge into it.

Most organisations have something like this. A reporting screen from a previous platform. A search page built for staff workflows. A PDF generator that was never meant to be indexed.

These are usually the result of operational drift rather than a single decision. Someone who owned the page left. Someone else assumed it had been turned off. Someone else assumed search engines would not find it. The system kept running because it was easier to leave it running than to argue about decommissioning it.

Then one day a parcel status phrase points back at it.

---

## The next version of this problem

I found this with ordinary Google. That is worth saying clearly.

The economics of this kind of discovery are changing.

LLMs lower the cost of connecting fragments, classifying pages, summarising what an old interface is for, and turning a vague discovery into a plan. They are good at the patient part. Labelling pages. Comparing fragments. Explaining what an old form probably does. Suggesting the next thing to check.

Indexed legacy interfaces are going to be discovered more reliably and described more usefully than before. The cost of doing what I did sits a step lower than it did a year ago, and is going to keep falling.

Indexed legacy pages are not really dormant. They are inputs for whatever finds them next.

---

## What stayed with me

I am glad I handled it through responsible disclosure. I am glad it was fixed.

What stays with me is how ordinary the discovery was. No zero-day. No clever exploit chain. Just search, weak boundaries, and an old interface that should not have been reachable.

Search turns weak assumptions into maps. That has been true for a long time. The map is just easier to read now.
