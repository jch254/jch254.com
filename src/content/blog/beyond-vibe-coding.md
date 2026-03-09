---
title: "Beyond Vibe Coding: Using AI as an Engineering Collaborator"
description: "Most AI dev content is about vibe coding or tool comparisons. Here's the structured workflow I've been using across real projects — and why it actually works."
date: 2026-03-10
tags: ["ai", "software engineering", "developer tools"]
draft: false
---

Most writing about AI-assisted development falls into two camps: vibe-coding hype ("I built an app in 30 minutes with ChatGPT") or shallow tool comparisons (Copilot vs Cursor vs Claude). Neither is particularly useful if you're building real systems.

Over the last few projects I've been experimenting with a different approach — treating AI less like a magic code generator and more like a technical collaborator across the full development lifecycle. The difference matters: vibe coding is blind prompting and hoping for the best. What I'm describing is closer to **AI-assisted systems engineering**.

The most effective way I've found to use AI in development isn't to generate software from scratch — it's to use it as a continuous feedback system across the entire build cycle.

## The problem with vibe coding

Vibe coding works for prototypes and throwaway demos. It falls apart the moment you need:

- Scalable architecture
- Proper error handling
- Concurrency safety
- Production infrastructure
- Anything that has to work next week

Prompting an LLM to "build me an app" gives you something that looks right. Looking right and being right are different things entirely. Anyone who's shipped production software knows this.

## The workflow: design → implement → audit → refine

The workflow looks simple, but each stage uses AI in a different way.

I've been using this loop on a couple of recent projects — from refining my portfolio site to building a more complex backend system. In both cases the pattern held: design the architecture myself, use AI to stress-test assumptions, implement quickly with Copilot, then run an audit pass before refining the product. The biggest improvement wasn't that the AI wrote the code — it was that the feedback loop got dramatically shorter.

What's been working for me is a simple 4-stage loop where AI plays a different role at each step. The human stays in control of architecture and direction. The AI accelerates everything else.

## A real example

Here's a simplified example of the audit stage.

Given a service that processes asynchronous jobs, I'll run a prompt like:

```
Audit this codebase for:

1. Async / concurrency bugs
2. Resource leaks
3. Lifecycle issues
4. Cache misuse
5. Error handling gaps
```

Typical things it will flag:

- Inconsistent async interfaces between services
- Temporary files not being cleaned up
- Missing retry logic for external APIs
- Dependency initialisation happening at request time

None of these are glamorous problems, but they're exactly the kind of issues that cause production incidents later. Catching them early is where the real leverage comes from.

### 1. Architecture stage — design the system

The goal here is to stress-test your design before writing too much code.

You still do the core engineering thinking: service boundaries, data models, pipelines, infrastructure. That part is human-driven. The goal isn't to have AI design the system — it's to **pressure-test assumptions and identify problems early**.

Once you have a design, you feed it into GPT and ask it to poke holes. Structured prompts work best here:

```
Review this architecture for:

1. Scalability bottlenecks
2. Failure modes
3. Missing components
4. Observability gaps
5. Security risks
```

This is basically **free architecture review**. Large language models are surprisingly good at pattern recognition across systems — they'll flag things like missing retry logic, async interface mismatches, lifecycle issues with external services, or temporary resource handling problems you might not catch until production.

The key is being specific. Open-ended prompts like "review my code" get vague answers. Structured prompts get actionable feedback.

### 2. Implementation stage — accelerate coding

The goal here is to turn clear architecture into working code as fast as possible.

Once architecture is clear, Copilot becomes the accelerator. The critical difference from vibe coding: **you're directing the implementation, not asking for random code.**

Instead of:

> "build me a web app"

You prompt:

```
Implement an async worker that:

- pulls jobs from a queue
- processes them through a pipeline
- retries failures safely
- writes results to storage
```

That's a specific, well-scoped task with clear boundaries. Copilot excels at this. It can churn out clean implementations when you've already done the design thinking.

In this stage, AI tools work best as **pair programmers, not system designers**. The division of labour is simple:

- **GPT** = architecture and reasoning
- **Copilot** = code production and iteration

The architecture still needs to come from you.

### 3. Audit stage — automated code review

The goal here is to catch bugs and design issues before they reach production.

This is where the workflow gets powerful. Once you have working code, you run a structured audit:

```
Audit this codebase for:

1. Async bugs
2. Resource leaks
3. Race conditions
4. Cache misuse
5. Error handling gaps
6. Security vulnerabilities
```

GPT acts as a codebase reviewer. I've had it catch real issues this way:

- Inconsistent async interfaces
- Missing cleanup of temporary resources
- Poorly handled dependency initialisation
- Hidden coupling between services
- Cache lifecycle bugs

Issues that would normally surface as production incidents get caught during the review loop instead. They won't catch everything, but they catch enough issues to justify the five minutes it takes to run the audit. It's essentially an automated engineering sanity check.

### 4. Refinement stage — product and UX iteration

The goal here is to polish everything around the code: copy, structure, documentation.

AI isn't just useful for code. Because the system already exists at this point, the AI's job is mostly to improve clarity and usability rather than invent new functionality.

On my portfolio site I used the same iterative loop for:

- Copy refinement
- UI structure improvements
- Design hierarchy
- Project positioning
- Documentation

The workflow was: design review → copy improvement → structure improvement. This stage tends to produce lots of small improvements that add up quickly. Iterating with AI on the non-code aspects of a project is underrated — it's fast, and it gives you a second perspective that's often surprisingly useful.

## The full loop

```
┌─────────────────────────┐
│       Architecture      │  ← design the system
└────────────┬────────────┘
             ↓
┌─────────────────────────┐
│      Implementation     │  ← directed, well-scoped tasks
└────────────┬────────────┘
             ↓
┌─────────────────────────┐
│          Audit          │  ← automated code review
└────────────┬────────────┘
             ↓
┌─────────────────────────┐
│       Refinement        │  ← UX, copy, documentation
└────────────┬────────────┘
             ↺ iterate
```

Each cycle tightens the system. Architecture mistakes get caught early. Implementation is faster because direction is clear. Audits catch bugs before they ship. Refinement polishes the product. Then you loop back and do it again.

This is fundamentally different from:

```
think → prompt → ship → pray
```

## What changed in practice

After using this workflow across a few recent projects, the biggest difference wasn't that AI wrote the code — it was that problems surfaced earlier.

Architecture issues that normally appear weeks later show up during the design review. Implementation moves faster because the direction is clear. And the audit stage regularly catches small bugs and lifecycle issues before they ever reach production.

The end result isn't "AI-built software". It's simply tighter engineering loops.

## What AI is actually good at

After running this workflow across multiple projects, here's where AI consistently delivers:

- **Architecture critique** — identifying bottlenecks, failure modes, and missing components
- **Code review** — pattern matching across files, catching resource leaks and concurrency issues
- **Implementation speed** — producing clean code when given specific, well-scoped tasks
- **Copy and UX refinement** — iterating on language, structure, and presentation

## What it's not good at

Equally important:

- **System design decisions** — it can critique your architecture, but it shouldn't be making the architectural calls. That requires context it doesn't have.
- **Domain modelling** — it doesn't understand your business, your users, or your constraints the way you do.
- **Trade-offs between technologies** — it can list pros and cons, but it can't weigh them against your operational reality.
- **Long-term thinking** — it optimises for the current prompt, not for where your system needs to be in six months.

AI has no operational accountability — it doesn't run your systems in production. It can highlight issues, but it doesn't truly understand the context of a system the way an engineer does. That's exactly why the human stays in the driver's seat.

## The real productivity boost

The biggest benefit of this workflow isn't that AI writes the code. It's that it **shortens the feedback loop**.

Instead of discovering architectural issues weeks later, you surface them early. Instead of waiting for a code review, you run an automated audit. Instead of rewriting documentation from scratch, you iterate on it interactively.

Used this way, AI becomes less of a novelty and more of a **continuous engineering feedback system**.

## The takeaway

The narrative around AI development often focuses on replacing engineers. In practice, the most effective use I've found is much simpler: treat AI as a collaborative reviewer that helps you iterate faster on systems you're already building.

The result isn't "AI building the software."
It's better engineering loops.

AI isn't most useful when it's generating software. It's most useful when it tightens the feedback loop around engineering decisions. And in complex systems, tighter feedback loops are where the real productivity gains come from.

If you're doing serious engineering work with AI tools, stop vibe coding. Design the system, implement it, audit it, refine it, repeat. That loop is where the actual leverage is.
