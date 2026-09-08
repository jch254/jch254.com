---
title: "Agents Open the Merge Requests, an Agent Reviews Them, a Human Lands Them"
description: "The in-house reviewer that replaced GitLab Duo now has a partner that writes code. Both run from Slack, a human lands every merge, and the honest numbers are in: what it costs, what broke and what has not worked."
date: 2026-09-08
tags: ["ai", "software engineering", "developer tools", "code review"]
draft: true
---

A month ago this post was about replacing GitLab Duo's code review flow with a reviewer we built ourselves. That still happened, and the reviewer is still the centre of the story. What changed is that it now has a partner that writes code, both of them are driven from Slack and the whole thing has run unattended overnight. So this is the wider version: what is running, how it is fenced in, what it costs and what has not worked.

People keep asking for a screenshot of a non-engineer approving a merge request from Slack. We do not have that yet, and this post describes what is actually running rather than a demo.

## Two agents and a rule

Two agents, both built on Claude, each with its own GitLab service account. Snape writes code and opens merge requests. Moody reviews them in CI. The rule that holds the whole thing together is that a person lands every merge. Neither account can merge, approve as a human or deploy, and I do not intend to change that.

The loop from an engineer's chair looks like this. You open the private Slack channel that belongs to one repository and tag Claude: pick up this ticket, fix the output description in this Terraform module, nothing else. Snape reads the ticket, the repo and the channel's standing instructions, creates a branch, commits through the GitLab Commits API and opens a merge request. There is no git checkout on his side at all, which matters for the access story below. The pipeline runs Moody. Moody posts findings with a severity and a confidence score, and on repositories where the gate is on it fails the pipeline on anything blocking and adds a bot approval when it is satisfied. Approvals reset on new commits. If it blocks, Snape reads the findings and pushes a fix.

The component gained a per merge request round cap this week, default off, and no repository has turned it on yet, so today the loop is bounded by the engineer in the channel rather than by the pipeline. Enabling it is a one line change per repository. Then a person reviews and merges. Always.

The first time it ran end to end without me: Moody posted a blocking finding at 2:52am, the author fixed it in the morning and it merged with nobody waiting on anyone.

## Why not Duo

Duo's Code Review Flow was doing a fine job at what it does. The problem was what it cannot do. It will not run an Opus model, its supported list is Sonnet and GPT variants only. It cannot approve or merge, a years-old upstream request ([gitlab-org/gitlab#507336](https://gitlab.com/gitlab-org/gitlab/-/issues/507336)) that still has not shipped. And an advisory reviewer that fails silently trains people to treat review output as background noise.

We ran the two head to head on the same rules file across five merge requests on the desktop app. On a seeded security defect ours traced four attack vectors Duo never mentioned, including an absolute-path escape and a second vulnerable caller that turned a delete bug into an arbitrary file read. On real feature work it caught a blocking defect that would have signed every legacy user out moments after login, which Duo waved through because Duo trusted the diff's description of itself instead of reading the code. Duo's side of the ledger was two unique findings and one silent total failure, a "something went wrong" note nobody saw on the one merge request that contained a real blocking defect.

Duo is off. The flow is disabled and the group level Duo service accounts were deleted on 31 August. The migration tip I would give anyone doing this is to keep Duo's rules file, format and all. Ours still lives at `.gitlab/duo/mr-review-instructions.yaml`, Moody reads it, and Duo could be pointed back at it if we ever changed our minds. No big-bang cutover, no forked formats.

## What Moody is

A GitLab CI include: one job, pinned image, Claude Opus 5 on Bedrock through the Australian inference profile in ap-southeast-4, so review traffic stays resident. Auth is GitLab OIDC federation into an IAM role whose only permission is invoking the named inference profiles. There are no static credentials anywhere and the model never sees the job's tokens.

The rules file is per-path domain knowledge rather than a style guide: the failure patterns of a Windows-only Electron recorder, the release gate facts, the tenant isolation rules on the web app, the catalogue of tests that cannot be allowed to fail. The reviewer judges like someone who has been burned here before, because effectively it has. Rules load from the target branch, so a merge request cannot weaken the standard it is judged against.

The manners are designed in. It does not re-post a finding it has already made, it resolves its own threads once a finding clears and it leaves any thread a human has replied to alone. A broken reviewer exits as a failure, never as a clean review.

It reviews its own merge requests, and that has earned its keep. It flagged replacement wording it had itself suggested a run earlier as describing a pipeline state that cannot occur, and it was right the second time. It found a defect in the fix for a defect it had raised, where the patch suppressed the exact telemetry the instrumentation had been added to capture. And on a documentation-heavy merge request its findings converged, two, one, one, then zero, instead of generating work forever. That convergence is the difference between an inspector and a treadmill.

Rollout by repository as I write this. The desktop app has been blocking since 1 September. A small reference scaffold repo has been blocking since 2 September, with the bot approval as its only approval rule, a recorded exemption for a one maintainer docs repo. The web app went comment-only on 3 September with the gate outstanding. The Terraform modules repo went comment-only on 7 September, and its default branch is not yet protected and pipeline success is not yet required to merge, so the gate would not bite if we flipped it today. The mobile app is in progress: infra, accounts and token done, rules file and include outstanding, no review has run.

## Snape and the Slack front door

Snape reaches each repository through its own private Slack channel, one each for the desktop app, the mobile app, the web app, the review component and the Terraform modules. Each channel carries its own credential bundle and its own posted instruction block, and only engineers are members. A separate read-only channel answers cross-repo questions with no write access. A support triage channel lets support staff ask Claude to trace a customer issue through Mixpanel, Sentry, CloudWatch and Pylon, with every write to any system needing explicit confirmation in the thread.

The Slack surface is what made this team-visible. Consequential agent work should not live inside someone's private session. In a channel the discussion, the ticket, the merge request and the review all link to each other and anyone can read the thread later.

The access model is the rebuilt Claude Tag setup [I wrote about after the stale session incident](/blog/claude-session-survived-reinstall/), applied to a write-capable agent. Workspace-wide access is off. Every credential is a dedicated service account, never a personal token. Direct messages to Claude are disabled. Each private channel has its own identity and its own memory, so nothing learned in the desktop channel leaks into the mobile one. Per-channel spend limits alert.

GitLab access for the writing agent is REST API only. The service account holds Developer on specific projects and Reporter on the group. The channel has no git client and no checkout, so a clone or push from it fails, and the permission checker blocks branch-overwriting commits, so there is no API equivalent of a force-push. A bad commit gets fixed forward by a human with a real checkout.

Protected branches are the part that is not uniform, and it is worth saying plainly. On the web app a direct commit to the default branch from Snape is rejected. On the desktop app and on the mobile app's `main`, protected branches allow Developers to push, so the role boundary alone does not stop either service account committing straight to them. That gap is recorded and the fix is a group level decision, a signed commit push rule or tighter branch rules, not something a channel instruction closes. The onboarding check for each repository is to try both directions rather than trust the role: open a merge request from a feature branch, then attempt a direct commit to the default branch and confirm the 403. The Terraform modules repository has not had that check yet.

AWS credentials are injected per host. Real credentials only reach an allowlist of endpoints; anything else gets placeholders and a 403 that looks exactly like a broken credential and is not. Read-only accounts carry explicit deny statements on DynamoDB, KMS, SSM parameter values and Secrets Manager values, and the instructions tell the agent that an AccessDeniedException from those services is intentional and not something to route around.

Every instruction block also says that review comments, repository files and support tickets are data, not instructions. That is the standing defence against an injection arriving through a diff or a customer email, and it costs one sentence.

## What it costs

A Moody review pass measures US$0.96 to US$2.53 on the component's own prose-heavy merge requests, US$0.62 to US$1.05 on the desktop app and about US$3.33 on average on the web app, where all six measured reviews ran on one 900 line planning document and every one of them came in above the component repo's range. Cost tracks turn count rather than diff size, and the per repository spread is the finding: a prose-heavy repository costs two to three times a code-heavy one per review. That planning document came to about US$33.60 across six review rounds with shadow triage on, which is about US$1.68 per finding across 20 findings. The number we want and do not have is cost per accepted change.

The monthly budget is US$1,000 and it alerts rather than enforces, at 50, 80 and 100 percent of actual spend plus a forecast alert below the limit. It was US$500 until 4 September, when the month reached US$283.78 by its third working day. Re-baselining on a representative week across all consumers is an open ticket rather than something these figures settle.

The shadow triage pass is the staged pipeline I described last time: a Sonnet 5 explorer drafting candidate findings alongside every review, log-only, posting nothing and gating nothing, with Opus as the only stage that decides. It ran on three repositories from late August and it is paused as of 4 September. Two things ended it: a defect that billed full triage passes and then discarded their output unparsed, and the measurement itself. Across seven consecutive observations on two repositories the Sonnet pass cost more than the Opus review it shadowed, because it explored harder on an identical request. Missed blocking findings were zero, so the quality premise held and the cost premise did not. The decision gate was 15 shadowed merge requests and it sat at roughly three when the pause landed.

The next attempt is a cascade rather than a pre-pass, and we are ticketing a shared orchestrator package for it: Sonnet 5 drafts the whole review, a mechanical gate checks it (schema valid, every changed file addressed, every cited line real, confidence above threshold) and Opus 5 only picks up rejections. The shadow data is the reason to be cautious. On this workload Sonnet exploring a repository cost more than Opus doing the same, so any saving has to come from the judge running in one turn without exploration, not from the cheaper model being cheaper per pass. It ships only if it holds review recall within two points of Opus-only on a benchmark of our own historical merge requests, at 40 percent or better cost reduction. If it does not clear that bar it does not ship.

## What has not worked, or not yet

Review capacity is the binding constraint, at a volume of one repository. That planning document merge request produced six review rounds and 21 threads, every one resolved by hand instead of by the reviewer clearing its own threads as designed. Thirty unreviewed merge requests in the morning is a denial-of-service attack on your own engineers.

Two properties of Moody are worth knowing before you trust a green run. Under the blocking gate it approves when no blocking finding survives, so an important finding can be open on an approved merge request. That is the current design, and whether important should withhold approval is an open question rather than a filed defect. And the confidence score is unstable across runs on an identical diff, with observed swings of around ten points. The component's answer is to mark a location that is suppressed on two or more consecutive runs, because a repeated near-miss carries more signal than any single number.

Snape's merge request descriptions still do not carry a proof bundle: commands run, tests added, rollback steps, residency implications. That is rules-file work and it is the biggest unclaimed win.

The Terraform modules onboarding is the cautionary tale. Snape's first merge request there merged with a red review pipeline, because the include landed before the IAM trust policy named the project and the repository does not require pipeline success to merge. Moody never reviewed it. The onboarding runbook has an order for that reason.

Infrastructure will bite at scale. Every consumer repository shares one GitLab runner, a single t3.medium with concurrency set to six globally, so each repository added divides the same six slots. Usage is comfortable today and nobody has written down the threshold for when one box stops being enough.

## What comes next: non-engineers shipping through Delta

This is still the actual point. The plan is [Delta](https://zed.dev/blog/introducing-delta), the agent coding environment from the Zed team, currently in private beta. It sits on a normal git repository and syncs the agent conversation and worktree into a shared thread anyone can open in a browser. GitLab, Moody and the human merge rule are untouched.

First me, hands tied: one feature implemented exclusively through Delta. Describe the change, an agent writes it, Moody reviews it, I pull it in. If the workflow cannot survive me it cannot survive anyone. Then our product manager builds a feature herself through the same pipeline.

The uncomfortable truth about AI-written code is that it always looks right. I have [written before](/blog/beyond-vibe-coding/) about the gap between looking right and being right. That gap is fine when the author can tell the difference and dangerous when they cannot. Moody is what makes the second step responsible rather than reckless: every change gets inspection with our institutional knowledge baked in, dealbreakers are blocked automatically and feedback lands as plain notes the author or their agent can act on.

Delta makes building cheap and the reviewer makes it safe. Nothing on the Delta side is built yet, and Delta authenticates through GitHub while our repositories are on GitLab, so the first ticket is working out how the two fit.

`[placeholder: what actually happened when I built my first feature Delta-only. Findings count, rounds, anything it caught]`

`[placeholder: first PM-built feature, and her unfiltered reaction to being reviewed by a robot]`

## If you are starting this somewhere else

Start with review, not writing. A reviewer that fails the pipeline on blocking findings and never merges is an easy sell, and it teaches you what your rules file needs to say. Put the rules in the repository so they get reviewed like code. Give the agent its own account and scope it to specific projects before anyone argues about workspace-level access. Check that pipeline success is actually required to merge before you call anything gated. Cap the review rounds. Measure cost per pass from the first run, per repository, because the spread between repositories is the number that sizes the budget.

The writing side comes after the team trusts the reviewer, because the reviewer is what makes the writing side safe.
