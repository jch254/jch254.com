---
title: "The Interesting Part of Claude Tag Is Not Slack"
description: "Anthropic put Claude in our Slack channels as Claude Tag. The part that mattered was not the chatbot. It was that non-engineers can now ask cross-system questions from where work already happens, and the answer lands in front of the whole team."
date: 2026-07-08
tags: ["ai", "developer tools", "team workflow"]
draft: true
---

A version of this happens in product teams all the time. A support teammate posts in a channel: a customer is seeing failures after a release, and the message ends the way these ones usually do. Can someone take a look?

Normally that question has a fixed shape. Someone technical picks it up, opens the support tool to read the report, checks the error tracker for matches, pulls the latest deploy diff, and glances at cloud metrics to see if anything looks off. Four tools, one engineer, and a support teammate waiting on a reply that might come in ten minutes or in two hours, depending on what else is on fire.

Now it does not have to go that way. Someone tags @Claude.

Claude replies in the same thread. It says what it is checking, works through the tools one by one, and comes back with a summary: which errors match the report, which deploy introduced them, what the metrics do and do not show, and a call on whether this looks like a product bug, an infra problem, or user error. Then it offers to open a ticket.

The useful part is not that Claude answers. Claude has been able to answer things for a while. The useful part is that the whole channel watches it happen. The support person does not have to hand the problem off and lose sight of it. The engineer who eventually reads the thread does not have to reconstruct the context. The reasoning is sitting right there, in the place the question was asked.

## The feature is not the interesting part

Anthropic shipped this as [Claude Tag](https://www.anthropic.com/news/introducing-claude-tag) on 23 June, replacing the old Claude in Slack app. You add Claude to selected channels, anyone in the channel can tag it, admins decide what it can see, and it runs in an Anthropic-hosted sandbox using Anthropic's current Claude model for Tag. There is one shared Claude per channel rather than everyone's private session, it builds context the longer it sits there, and it can keep working across hours or days rather than one synchronous reply.

That is the announcement, and I do not want to spend long on it. What I care about is what it did to how our team works.

## The old shape was individual

I have spent two years getting good at AI tools that are, underneath, single-player.

Claude Code and claude.ai are strong, and I use them every day. But they assume a particular person is driving. That person has to know what to ask, where the context lives, and how to move between the repo, the ticket, the metric, and the customer report. They carry the question into the tool and carry the answer back out.

That works well for engineers. Knowing where the context lives is most of the job. It works much less well for the people whose actual operating surface is Slack.

At Contented a lot of the team does not live in an IDE. Support, product, operations, the people closest to customers. Their day happens in Slack threads. For them the old workflow had a tax on it that engineers stopped noticing years ago. To get an answer they had to leave Slack, open another tool, know it existed, know how to phrase the question, or, most often, find an engineer to be the bridge.

I [wrote recently](/blog/optimised-the-pair-out-of-pair-programming/) that agents quietly emptied the room, that when the model becomes your default pair the shared work becomes a private exchange between one human and one model. That post was about engineers. This is the same effect pointed at everyone else. The context, and the ability to ask questions of it, had concentrated into a small number of technical people.

## What actually changed

The change is not that Claude is in Slack. It is that the interface to AI-assisted work moved into the shared surface.

@Claude is in the channel. It has the access we chose for it. It can read the thread it is tagged in, so it inherits the context already there. It can use the systems we connected. And it returns the answer where the discussion started, in front of everyone who was already part of it.

That last point is the whole thing. The request, the progress, and the result are all visible to the team by default. Nobody has to relay anything.

## What we point it at

The reads get interesting when the tools are connected. Ours currently reaches the usual stack: version control, issue tracking, error tracking, analytics, customer support, docs, and cloud metrics. Mostly readonly.

The releases-and-debugging one is the example I opened with. Error tracking next to the deploy history and cloud metrics turns "a customer is seeing errors" into an actual triage:

> @Claude We have a customer reporting failures after the latest release. Check the support tool for the report, Sentry for matching errors, GitLab for the latest deploy diff, and AWS metrics for anything unusual. Summarise whether this looks like a product bug, an infra issue, or user error, then open a Jira ticket if needed.

The product-signal one is the one product and growth reach for. Analytics next to the change history tells you whether a metric moved because of something we did:

> @Claude Activation seems lower this week. Pull the relevant Mixpanel funnel, compare it against recent Jira and GitLab changes, check the product docs for any intended behaviour changes, and give us the most likely explanation in this thread.

And the one that settles arguments. Half our "is this a bug?" debates are really "what is this supposed to do?", which is a documentation question wearing an engineering costume:

> @Claude We are debating whether this behaviour is expected. Read the product docs, check related Jira tickets, look for recent GitLab changes, and tell us what the system currently does versus what the product docs say it should do.

None of these are clever prompts. They are the questions people were already asking each other. The difference is that answering them used to require a person who knew the map.

## The non-engineers are the story

This is the part I did not expect to matter as much as it does.

The people getting the most out of this are not the engineers. It is the people who can now ask a product, support, or operations question without needing to know the backend at all. They do not have to know that errors live in Sentry, usage in Mixpanel, deploys in GitLab. They describe what they want to know, and the model figures out where to look.

They also do not have to become prompt engineers. The channel context does a lot of the work, and the good prompts are just clear questions. And they do not have to interrupt someone technical for every lookup, so the lookups that used to die in a backlog now get done.

They still get output the rest of us can see and check. That combination, a non-technical person asking a real question and getting a reviewable answer in public, is new for us.

## Engineers did not get less important

If anything the opposite. What changed is where the engineering effort goes.

Claude is good at the gathering. It collects the evidence, lines up the timeline, and proposes a cause. That is most of the tedious part of an investigation, and handing it over is a real saving.

It is not the one who decides. The proposed cause is a hypothesis, not a verdict. The drafted ticket is a draft. Judgement, review, and anything that touches production still sit with a person, and they should. The value is that the person now starts from a filled-in picture instead of a blank one.

The healthiest pattern we have landed on is Claude collects, a human confirms, in public. The confirming and the correcting happen in the same thread, where everyone can see both the answer and the correction. When Claude gets something wrong, and it does, the correction is part of the record too.

## The real question is access, not capability

The hard question with this is not "can the model do it?". It is "what should this channel's Claude be allowed to see, and what should it be allowed to do?".

Reads are where the early value is, and reads are much safer. Investigation, triage, summaries, cross-tool lookup, and drafting tickets or PRs pay off immediately and are hard to get badly wrong. Most of our tools are connected readonly for exactly this reason. A model that can look at everything and change nothing is a very useful and fairly low-stakes thing.

Write access is a separate decision and should be made deliberately, tool by tool, not switched on because it is available. Opening a Jira ticket is low risk. Merging to a repo or touching infrastructure is not, and that boundary wants a human on it.

There is also a noise problem. A shared assistant that can post in channels, and act on its own if you enable ambient behaviour, can generate clutter as easily as signal. We have kept the proactive behaviour off in most channels for now. A bot that volunteers things nobody asked for is worse than one that waits to be tagged.

And because the work is metered, spend matters. I have [written before](/blog/github-copilot-became-a-meter-in-my-editor/) about what happens when a tool's cost becomes unpredictable, and a shared assistant that anyone can hand an open-ended task to is exactly the shape that can surprise you. Claude Tag has usage-based billing with spend limits. Set the limits.

So the work is mostly configuration and habit, not capability. Which channels have Claude. What each can see. Which tools are readonly. Where writes are allowed. What the audit trail captures. The value depends far more on getting those right, and on basic channel hygiene, than on anything the model does.

## Where I have landed

The most useful AI tools are quietly moving toward the place where work already happens, rather than asking the work to come to them.

For our team Slack is not just chat. It is where decisions get made, where ambiguity gets argued out, where customer signal shows up first, and where operational context accumulates whether we file it anywhere or not. Putting a scoped, visible, shared Claude in that surface did not make the model smarter. It changed who gets to ask the system questions, and put the asking, the working, and the answer in the same place the team already was.

That is the part worth paying attention to. Not that Claude is in Slack. The important part is who gets to ask now.

---

*Claude Tag is currently in beta for Claude Enterprise and Team. The example prompts above are lightly cleaned-up versions of real patterns we use at Contented.*
