---
title: "Replacing GitLab Duo With an In-House AI Code Reviewer (and Why: Delta)"
description: "We're swapping GitLab Duo's Code Review Flow for a reviewer we built ourselves. Not because Duo is bad, but because the reviewer is about to become the most important gate in how we build, and I wanted to own it."
date: 2026-08-27
tags: ["ai", "software engineering", "developer tools", "code review"]
draft: true
---

We are replacing GitLab Duo's Code Review Flow with a reviewer we built ourselves.

Duo does a fine job at what it does. The problem is what it cannot do. The flow will not run an Opus model, its supported list is Sonnet and GPT variants only. It cannot approve or merge, a years-old upstream request ([gitlab-org/gitlab#507336](https://gitlab.com/gitlab-org/gitlab/-/issues/507336)) that still has not shipped. And we kept watching Sonnet wave through things a second Opus pass then found. Sitting on Duo means our review quality moves on GitLab's schedule.

The reviewer is about to become the most important gate in how we build, and I wanted to own it.

## The migration is deliberately boring

The component is a GitLab CI include: one job, pinned image, Claude Opus 5 on Bedrock through the AU inference profile, so review traffic stays resident in Australia. Auth is GitLab OIDC federation with no static credentials anywhere, and the environment the model runs in is scrubbed of the job's tokens.

The part I would recommend to anyone doing this: we kept Duo's rules file, format and all. Our repo instructions still live at `.gitlab/duo/mr-review-instructions.yaml` and both reviewers read the same file, so running them side by side cost nothing and the comparison was direct.

The comparison went one way. On a seeded security defect ours traced four attack vectors Duo never saw, including an absolute-path escape and a second vulnerable caller that turned a delete bug into an arbitrary file read. On real feature work it caught a blocking defect that would have signed every legacy user out moments after login, which Duo waved through because Duo trusted the diff's description of itself instead of reading the code. And on the one merge request that contained a real blocking defect, Duo failed silently, posting nothing but a "something went wrong" note nobody saw.

So Duo is on the way out. The rules file stays exactly where it is, since our reviewer reads it, and Duo can be pointed back at the same file if we ever change our minds. No big-bang cutover, no forked formats.

## What in-house bought us

Calibration, mostly. The rules file is per-path domain knowledge rather than a style guide: the failure patterns of a Windows-only Electron recorder, the release gate facts, the catalogue of tests that cannot be allowed to fail. The reviewer judges like someone who has been burned here before, because effectively it has. On real merge requests we have watched five of the seven rule entries fire on a single diff.

The manners are designed in rather than hoped for. It does not re-post a finding it has already made, it resolves its own threads once a finding clears, and it leaves any thread a human has replied to alone. A broken reviewer exits as a failure, never as a clean review. Duo's silent failure above is exactly the behaviour we designed against: an advisory reviewer that fails silently trains people to treat review output as background noise.

The gate is real. Blocking findings fail the pipeline, a bot-only approval rule sits alongside the unchanged human rule, approvals reset when new commits land, and the bot approves but never merges. Rules load from the target branch, so a change cannot weaken the standards it is judged by. Duo comments; this one decides.

The full loop has already run unattended overnight: blocking finding posted at 2:52am, the author fixed it, the finding cleared and the merge went through with nobody waiting on me.

The economics are honest. Duo is 25 US cents per review, flat. Ours measured US$0.62 to $1.05 per review on the desktop app across six passes, and the worst case so far is $4.72 over 35 turns on a 17-file prose-heavy diff in the component's own repo. More expensive, and worth it: the extra spend is the difference between "tidy up some Sentry noise" and "this signs every legacy user out". That $4.72 run also told us exactly where the money goes, which is what the next section is about.

## It reviews itself, and that is the QA

The component reviews its own merge requests, and the self-review has already earned its keep.

It flagged replacement wording it had itself suggested one run earlier as describing a pipeline state that cannot occur, and it was right the second time. On another pass it found a defect in the fix for a defect it had raised: the patch suppressed the exact telemetry the instrumentation had been added to capture. And on a documentation-heavy MR its findings converged, two, then one, then one, then zero posted, instead of generating work forever, which is the difference between an inspector and a treadmill.

An inspector strict enough to fail its own paperwork is the one I trust with what comes next.

## Next for the reviewer: a staged pipeline

This one is a plan rather than shipped code, and the spec lives in the component repo (`docs/review-pipeline.md`). It exists because of what the cost numbers are made of.

Nearly all of the spend on an expensive review is the flagship model exploring: dozens of turns reading files to verify claims, 4.7 million cache-read input tokens on the $4.72 run. The judgement at the end, the severity calls and the decision to gate, is a small fraction of the bill. Exploration is work a cheaper model can do. Judgement is what earns the flagship rate.

So the plan is two stages behind the existing adapter contract. Stage one is a cheap model, Sonnet-class or an open-weight model on Bedrock's Mantle endpoint once one passes evaluation, and it does the exploration: it reads the repo, drafts candidate findings and assembles an evidence dossier of the excerpts, callers and cross-references that justify each candidate, plus anything it checked and found clean. Stage two is the flagship judge, Opus today with Fable as an opt-in if a review turns out to need it. It receives the diff, the rules, the candidates and the dossier, with no exploration of its own, and it audits each candidate, scans the diff for what stage one missed and emits the final findings. Ideally one turn instead of 35.

The invariants are the point. Gating authority never leaves the flagship: stage-one findings are never posted, never approve and never gate. A stage-one failure falls back to today's single-pass review, because a cost optimisation must never reduce reliability. Stage-one output is treated as untrusted input, since it is model output steered by an untrusted diff, and the judge is explicitly told that rejecting every candidate is a valid outcome, so the pipeline never anchors on its weakest model. Confidence scores are not comparable across models, so only the judge's scores ever touch the threshold.

It ships opt-in through one new input, `triage_model`, which defaults to empty and means today's single-pass behaviour, so no consumer changes on a version bump. And it rolls out the same way everything else here has: shadow mode first, with stage one running log-only beside the current review so we can measure overlap, missed-blocking rate and real cost per stage before anything changes what gets posted.

The tempting shortcut, skipping the judge entirely when triage reports a clean diff, is the biggest saving and the biggest risk, since it makes a cheap model's silence load-bearing. It comes last, and only if the shadow data earns it.

## What comes next: non-engineers shipping via Delta

Here is the actual point. Once the desktop app has been stable behind the gate, the reviewer rolls onto contented-app (Contented 2.0), and then we change who builds.

First me, hands tied. I will implement features exclusively through [Delta](https://zed.dev/blog/introducing-delta), the new agent coding environment from the Zed team: describe the change, an agent writes the code, the reviewer inspects it, I pull it in. DeltaDB syncs the agent conversation and the worktree into a shared thread anyone can open in a browser, and it sits on top of a normal git repo, so our GitLab flow is untouched. If the workflow cannot survive me, it cannot survive anyone.

Then Siena, our product manager, builds a feature herself through the same pipeline.

The uncomfortable truth about AI-written code is that it always looks right. I have [written before](/blog/beyond-vibe-coding/) about the gap between looking right and being right. That gap is fine when the author can tell the difference and dangerous when they cannot. The reviewer is what makes the second step responsible rather than reckless: every change gets senior-level inspection with our institutional knowledge baked in, dealbreakers are blocked automatically, feedback lands as plain-English notes the author or their agent can act on, and because the rules load from the target branch a change cannot weaken the standards it is judged by.

Delta makes building cheap and the reviewer makes it safe. Together they turn "non-engineers shipping to production" from a leap of faith into a pipeline with quality control built in.

`[placeholder: what actually happened when I built my first feature Delta-only. Findings count, rounds, anything it caught]`

`[placeholder: first PM-built feature, and her unfiltered reaction to being reviewed by a robot]`
