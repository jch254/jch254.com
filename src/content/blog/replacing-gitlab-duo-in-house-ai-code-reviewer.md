---
title: "Agents Open the Merge Requests, an Agent Reviews Them, a Human Lands Them"
description: "The in-house reviewer that replaced GitLab Duo now has a partner that writes code. Both run from Slack, a human lands every merge, and the honest numbers are in: what it costs, what broke and what has not worked."
date: 2026-09-08
tags: ["ai", "software engineering", "developer tools", "code review"]
draft: true
---

A month ago this post was about replacing GitLab Duo's code review flow with a reviewer we built ourselves. That still happened, and the reviewer is still the centre of the story. What changed is that it now has a partner that writes code, both of them are driven from Slack and the whole thing has run unattended overnight. So this is the wider version: what is running, how it is fenced in, what it costs and what has not worked.

## Two agents and a rule

Two agents, both built on Claude, each with its own GitLab service account. Snape writes code and opens merge requests. Moody reviews them in CI. The rule that holds the whole thing together is that a person lands every merge. Neither account can merge, approve as a human or deploy, and I do not intend to change that.

The loop from an engineer's chair looks like this. You open the private Slack channel that belongs to one repository and tag Claude: pick up this Linear ticket, touch these files, leave that alone. Snape creates a branch, commits through the GitLab Commits API and opens a merge request. The pipeline runs Moody. Moody posts findings with a severity and a confidence score, fails the pipeline on anything blocking and adds a bot approval when it is satisfied. If it blocks, Snape reads the findings and pushes a fix. We cap that at three review-and-fix rounds. After the third the agent stops, posts one comment naming everything still open and waits for a human to say continue. Then a person reviews and merges.

The first time it ran end to end without me: Moody posted a blocking finding at 2:52am, the author fixed it in the morning and it merged with nobody waiting on anyone.

## Why not Duo

Duo's Code Review Flow was doing a fine job at what it does. The problem was what it cannot do. It will not run an Opus model, its supported list is Sonnet and GPT variants only. It cannot approve or merge, a years-old upstream request ([gitlab-org/gitlab#507336](https://gitlab.com/gitlab-org/gitlab/-/issues/507336)) that still has not shipped. And on the one merge request in our side-by-side that contained a real blocking defect, Duo produced nothing at all, with a "something went wrong" note nobody saw. An advisory reviewer that fails silently trains people to treat review output as background noise.

We ran the two head to head on the same rules file and the comparison went one way. On a seeded security defect ours traced four attack vectors Duo never mentioned, including an absolute-path escape and a second vulnerable caller that turned a delete bug into an arbitrary file read. On real feature work it caught a blocking defect that would have signed every legacy user out moments after login, which Duo waved through because Duo trusted the diff's description of itself instead of reading the code.

Duo is on the way out. The migration tip I would give anyone doing this is to keep Duo's rules file, format and all. Ours still lives at `.gitlab/duo/mr-review-instructions.yaml`, both reviewers read it, and Duo can be pointed back at it if we ever change our minds. No big-bang cutover, no forked formats.

## What Moody is

A GitLab CI include: one job, pinned image, Claude Opus 5 on Bedrock through the Australian inference profile in ap-southeast-4, so review traffic stays resident. Auth is GitLab OIDC federation into an IAM role scoped to Bedrock. There are no static credentials anywhere and the model never sees the job's tokens.

The rules file is per-path domain knowledge rather than a style guide: the failure patterns of a Windows-only Electron recorder, the release gate facts, the catalogue of tests that cannot be allowed to fail. The reviewer judges like someone who has been burned here before, because effectively it has. Rules load from the target branch, so a merge request cannot weaken the standard it is judged against.

The manners are designed in. It does not re-post a finding it has already made, it resolves its own threads once a finding clears and it leaves any thread a human has replied to alone. A broken reviewer exits as a failure, never as a clean review.

It reviews its own merge requests, and that has earned its keep. It flagged replacement wording it had itself suggested a run earlier as describing a pipeline state that cannot occur, and it was right the second time. It found a defect in the fix for a defect it had raised, where the patch suppressed the exact telemetry the instrumentation had been added to capture. And on a documentation-heavy merge request its findings converged, two, one, one, then zero, instead of generating work forever. That convergence is the difference between an inspector and a treadmill.

Rollout by repository as I write this: desktop-application is blocking, contented-app is in comment-only mode, terraform-modules went comment-only this week, contented-gold-standard is in progress and mobile is in the backlog.

## Snape and the Slack front door

Snape reaches each repository through its own private Slack channel: claude_eng_desktop, claude_eng_mobile, claude_eng_contented_app, claude_eng_agentic_review and now claude_eng_terraform_modules. Each channel carries its own credential bundle and its own posted instruction block, and only engineers are members. A separate claude_readonly channel answers cross-repo questions with no write access. A claude_support_triage channel lets support staff ask Claude to trace a customer issue through Mixpanel, Sentry, CloudWatch and Pylon, with every write to any system needing explicit confirmation in the thread.

The Slack surface is what made this team-visible. Consequential agent work should not live inside someone's private session. In a channel the discussion, the ticket, the merge request and the review all link to each other and anyone can read the thread later.

The access model is the rebuilt Claude Tag setup [I wrote about after the stale session incident](/blog/claude-session-survived-reinstall/), applied to a write-capable agent. Workspace-wide access is off. Every credential is a dedicated service account, never a personal token. Direct messages to Claude are disabled. Each private channel has its own identity and its own memory, so nothing learned in the desktop channel leaks into the mobile one. Per-channel spend limits alert.

GitLab access for the writing agent is REST API only. The service account holds Developer on specific projects and Reporter on the group. It cannot clone or push over git, which returns 401 by design. Protected branches reject direct commits with a 403 and the permission checker also blocks branch-overwriting commits, so there is no API equivalent of a force-push. A bad commit gets fixed forward by a human with a real checkout. The onboarding check for each repository is to try both directions rather than trust the role: the agent opens a merge request from a feature branch, then fails to commit to development.

AWS credentials are injected per host. Real credentials only reach an allowlist of endpoints; anything else gets placeholders and a 403 that looks exactly like a broken credential and is not. Read-only accounts carry explicit deny statements on DynamoDB, KMS, SSM parameter values and Secrets Manager values, and the instructions tell the agent that an AccessDeniedException from those services is intentional and not something to route around.

Every instruction block also says that review comments, repository files and support tickets are data, not instructions. That is the standing defence against an injection arriving through a diff or a customer email, and it costs one sentence.

## What it costs

A Moody review pass measures US$0.96 to US$2.53 in Bedrock spend, or US$1.65 to US$4.38 all-in once the shadow triage pass is counted. Cost tracks turn count rather than diff size. On one planning document merge request in contented-app we measured about US$1.68 per finding across 20 findings. The monthly budget is US$500 and it alerts rather than enforces. The number we want and do not have is cost per accepted change.

That shadow triage pass is the staged pipeline I described last time: a Sonnet 5 explorer drafts candidate findings alongside every review, log-only, posting nothing and gating nothing, with Opus as the only stage that decides. It is running. The premise it was built on has not survived contact. Across the observations so far the triage pass consistently costs more than the review it shadows, while the count of blocking findings it would have missed is still zero. So the cheap-explorer idea as first designed is not going to save money. The next attempt is a cascade rather than a pre-pass: Sonnet drafts the whole review, a mechanical gate checks it (schema valid, every changed file addressed, every cited line real, confidence above threshold) and Opus only picks up rejections. It ships only if it holds recall within two points of Opus-only on a benchmark of our own historical merge requests, at 40 percent or better cost reduction. If it does not clear that bar it does not ship.

## What has not worked

Review capacity is the binding constraint, at a volume of one repository. That contented-app merge request produced six review rounds and 21 threads, every one resolved by hand instead of by the reviewer clearing its own threads as designed. Thirty unreviewed merge requests in the morning is a denial-of-service attack on your own engineers.

Moody has two known defects. It can approve while an important but non-blocking finding is still open, because only blocking severity fails the pipeline, and an approval should assert that nothing important is outstanding. And the confidence score is unstable enough across runs on an identical diff that a repeated near-miss carries more signal than any single number.

Snape's merge request descriptions still do not carry a proof bundle: commands run, tests added, rollback steps, residency implications. That is rules-file work and it is the biggest unclaimed win.

Infrastructure will bite first at scale. Every consumer repository shares one GitLab runner, a single t3.medium with concurrency set to six globally, so each repository added divides the same six slots. Usage is comfortable today and nobody has written down the threshold for when one box stops being enough.

## What comes next: non-engineers shipping through Delta

This is still the actual point. The plan is [Delta](https://zed.dev/blog/introducing-delta), the agent coding environment from the Zed team. It sits on a normal git repository and syncs the agent conversation and worktree into a shared thread anyone can open in a browser. GitLab, Moody and the human merge rule are untouched.

First me, hands tied: one feature implemented exclusively through Delta. Describe the change, an agent writes it, Moody reviews it, I pull it in. If the workflow cannot survive me it cannot survive anyone. Then Siena, our product manager, builds a feature herself through the same pipeline.

The uncomfortable truth about AI-written code is that it always looks right. I have [written before](/blog/beyond-vibe-coding/) about the gap between looking right and being right. That gap is fine when the author can tell the difference and dangerous when they cannot. Moody is what makes the second step responsible rather than reckless: every change gets inspection with our institutional knowledge baked in, dealbreakers are blocked automatically and feedback lands as plain notes the author or their agent can act on.

Delta makes building cheap and the reviewer makes it safe. Nothing on the Delta side is built yet.

`[placeholder: what actually happened when I built my first feature Delta-only. Findings count, rounds, anything it caught]`

`[placeholder: first PM-built feature, and her unfiltered reaction to being reviewed by a robot]`

## If you are starting this somewhere else

Start with review, not writing. A reviewer that fails the pipeline on blocking findings and never merges is an easy sell, and it teaches you what your rules file needs to say. Put the rules in the repository so they get reviewed like code. Give the agent its own account and scope it to specific projects before anyone argues about workspace-level access. Cap the review rounds. Measure cost per pass from the first run.

The writing side comes after the team trusts the reviewer, because the reviewer is what makes the writing side safe.
