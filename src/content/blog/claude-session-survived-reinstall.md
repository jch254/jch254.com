---
title: "The Claude Tag Session That Survived a Reinstall"
description: "One channel's Claude in Slack session pinned a six-day-old connector config and silently ignored every change after it. Removing and reinstalling the app didn't touch it. The rollout turned into a security rebuild."
date: 2026-07-09
tags: ["ai", "security", "developer tools"]
heroImage: "claude-session-survived-reinstall-hero.jpeg"
draft: false
---

I updated a connector configuration and asked Claude to use it. It answered using the old one.

I fixed a broken token, patched an allowlist, saved everything, and asked again. Old config.

So I went nuclear: removed the Slack app from the workspace entirely and reinstalled it from scratch. Claude came back up and answered using a connection configuration from six days earlier.

That was the moment a routine rollout of Claude Tag, Anthropic's Claude-in-Slack integration, turned into a security rebuild.

That mattered because Claude Tag is not being positioned as a novelty Slack bot. The [launch post](https://www.anthropic.com/news/introducing-claude-tag) frames it as the beginning of an evolution of Claude Code: more proactive, and better suited to full-team work. It also says 65% of Anthropic's product team's code is created by its internal version.

So the security model matters.

This is an agentic coding and operations surface inside the place where the team works. Identity, scope, auditability, spend limits, and reset paths deserve day-one attention.

## Broad and loose

Some context first. I'm the technical lead and admin for the rollout at work, and the initial setup was the enthusiasm-first version. One access bundle holding eight credentials, covering AWS, GitLab, Jira, Mixpanel, Notion, Pylon, Sentry, and an internal tool, inherited workspace-wide by every channel Claude was in.

In a channel, Claude's access follows the channel, not the person typing. That is the right model. It also means the scoping decision is the entire game, and we hadn't made one. With a single workspace-wide bundle, a general chat channel had identical reach to the engineering channel.

The second problem was attribution. In channels, Claude is meant to act through its own service accounts rather than as any specific user. But a connector is only as separate as the credential you configure it with, and some of ours were personal tokens. When Claude called GitLab, the audit trail showed a person.

So the real starting state was three problems stacked on top of each other: broad access, human-attributed credentials, and reset behaviour nobody understood yet.

It worked, in the way broad access always works: smoothly, right up until you think about it. I was partway through tightening it when the bug hit.

## The session that wouldn't move on

One channel's Claude session had pinned the connection configuration as it existed six days earlier, and it silently ignored every change made after that. New tokens, connectors toggled on and off, allowlists rewritten. No errors, no warnings. Claude just kept behaving like the calendar had stopped.

Some of that is by design. A session keeps the set of connections it started with, and starting a fresh thread is the documented way to pick up changes. What I saw went further. New conversations in that channel should have picked up the current configuration. They didn't. The whole channel was welded to one stale snapshot.

Debugging it surfaced real problems, which is part of what made it hard to isolate. A token had been stored without its `Bearer` prefix. An AWS host-pattern allowlist had a gap in it. Both genuine misconfigurations, both worth fixing.

Fixing them changed nothing in that channel.

The tell was a fresh channel. A brand-new channel picked up the corrected configuration immediately and worked. The original channel kept using the six-day-old version. Not a config problem. A session problem.

## Reinstalling the app fixed nothing

For most Slack integrations, removing and reinstalling the app is the reset button. Uninstall and the state goes with it. Reinstall and you start clean.

Not here. Access bundles and channel configuration for Claude Tag live on the claude.ai side, independent of the Slack installation. Removing the app from Slack removes the app from Slack. The state you're trying to escape isn't in Slack.

So the reinstall completed, the workspace re-linked, and the stale session was still there. Still pinned to a config from six days ago. Still ignoring everything.

The settings page truthfully showed my updated configuration. The session answering questions in the channel had stopped reading it days ago, and nothing anywhere said so. A status screen can be perfectly accurate within a scope you can't see, and this one was.

I reported it to Anthropic as a bug, and I'd expect it to get fixed. In the meantime, the only reliable fix I found was retiring the channel entirely. A fresh channel means a fresh session, and a fresh session reads the current configuration. If another reset path exists, I never found it.

## One more trap on the way out

After the reinstall, the Claude Tag settings appeared read-only. For a while I thought the bug had spread to the admin surface.

It hadn't. In our setup, editing Claude Tag settings required an owner-level account, not the plain Admin role I expected to be enough. Worth knowing before you're mid-incident rather than during.

## Burning it down

By this point I didn't want to patch the original setup. A workspace-wide bundle, personal tokens, and a session that had quietly detached from its own configuration is not a foundation you renovate.

So we rebuilt from zero on a different principle: lock down first, widen deliberately.

The platform detail that shaped the rebuild is where enforcement happens. Claude never holds the credentials directly. They sit behind a proxy boundary and get attached only when an outbound request matches the configured rules for that connector and host. That is the layer worth trusting. Not "Claude has been told to behave", but "Claude does not have the credential, the route, or the permission required to do the wrong thing".

Day one now looks like this:

- **Workspace-wide access is off entirely.** One access bundle, scoped to a single invite-only private channel. Channel membership is the access list. Adding someone to the channel is granting access, and it's visible when it happens.
- **Every credential is a dedicated read-only service account.** No personal tokens anywhere. GitLab runs as a group access token bot with the Reporter role, which keeps code and configuration writes out of reach from Slack. Claude has its own identity in every system it touches, and the audit trail finally says so.
- **DMs to Claude are disabled.** A DM runs on the individual's own Claude account and personal connectors, which is a different trust model from the channel's service accounts. Channel-only means every interaction goes through the audited identities, somewhere others can see it.
- **A hard spend limit** sits underneath it all as a billing tripwire.

Then the soft controls, deliberately second. Custom instructions tell Claude that retrieved content is data, not instructions. That errors get reported as-is rather than worked around. That "explicit confirmation" means confirmation for this specific action, not a general go-ahead that carries over to the next one.

All useful. All soft. Instructions shape behaviour, and behaviour can be talked out of. Credentials, permissions, host allowlists, and channel scope can't be. The hard controls do the enforcing. The soft controls just reduce how often they get tested.

Part of this design was forced, and it's worth being honest about that. Person- and role-based member restrictions are an Enterprise-plan feature. On the Team plan, the channel is the practical unit of access control. It's the only real boundary you get, so we made the channel a real boundary.

## The connectors that didn't make the cut

Two footnotes from connector land, because this is where the quiet risk decisions live.

Pylon's official MCP connector had no knowledge-base tools, which was the main thing we wanted from it. A community MCP server exists that does more, and we ruled it out: a third party's code holding a credential into our support system is a bad trade for convenience. Instead we built a small custom skill that fetches from the knowledge base over plain web requests. The knowledge base is public, so there's no credential to hold at all.

WorkOS we evaluated and deliberately excluded. Not because the connector is bad, but because the value didn't clear the bar for the surface it added. Every connector is attack surface. "We could connect it" is not an argument.

## Widening deliberately

The single channel is the deliberate starting point, not the end state.

The next step is splitting the bundle in two. A baseline bundle with low-risk, read-oriented connectors for broader channels, and an engineering bundle where AWS, GitLab, and Sentry stay confined to an engineering channel. Different rooms, different reach.

After that, the audit trail does the arguing. Because every credential is a service account, every call Claude makes is logged under its own identity. Review the log after a week or two of real usage, then extend access one deliberate grant at a time, where the usage justifies it.

And here's the honest counterweight, because a post that ends at "lock everything down" would be dishonest about why we're running this at all. Broad access is where the value compounds. Claude connecting a Sentry error to the GitLab commit that caused it and the Jira ticket that tracked it is the entire point of putting an assistant inside your tools. A permanently locked-down Claude is a worse product, and pretending otherwise is security theatre of a different kind.

The goal was never to minimise what Claude can do. It's to scope where each credential lives. Full capability in the engineering channel, appropriate capability everywhere else, and a log that justifies every step of the widening.

## Design like the reset button doesn't exist

The stale session will presumably get fixed. It's reported, I could reproduce it, and it's the kind of rough edge every young platform sheds as it matures.

But it earned its keep. The reinstall that fixed nothing taught me more about the platform than the documentation did: the state lives where it lives, not where you assume it does, and the reset paths you're counting on may not exist.

The lesson I'm keeping isn't about Claude Tag specifically. An AI assistant wired into eight systems is production infrastructure, and it deserves day-one decisions like production infrastructure. Its own identities. Read-only by default. One clear boundary. An audit trail. A spend tripwire.

Because the day something goes wrong, "remove and reinstall" might do nothing at all. When the reset button turns out not to exist, you want to be holding as little as possible that ever needs resetting.
