---
title: "Replacing GitLab Duo With an In-House AI Code Reviewer (and Why: Delta)"
description: "We're swapping GitLab Duo's Code Review Flow for a reviewer we built ourselves. Not because Duo is bad, but because the reviewer is about to become the most important gate in how we build, and I wanted to own it."
date: 2026-09-04
tags: ["ai", "software engineering", "developer tools", "code review"]
draft: true
---

We are replacing GitLab Duo's Code Review Flow with a reviewer we built ourselves.

Duo does a fine job at what it does. The problem is what it cannot do. The flow will not run an Opus model, its supported list is Sonnet and GPT variants only. It cannot approve or merge, a years-old upstream request ([gitlab-org/gitlab#507336](https://gitlab.com/gitlab-org/gitlab/-/issues/507336)) that still has not shipped. And we kept watching Sonnet wave through things a second Opus pass then found. Sitting on Duo means our review quality moves on GitLab's schedule.

The reviewer is about to become the most important gate in how we build, and I wanted to own it.

## The migration is deliberately boring

The component is a GitLab CI include: one job, pinned image, Claude Opus 5 on Bedrock through the AU inference profile, so review traffic stays resident in Australia. Auth is GitLab OIDC federation with no static credentials anywhere, and the environment the model runs in is scrubbed of the job's tokens.

The latest tag is v0.1.18. Opus 5 does the review. A Sonnet 5 pass runs beside it in shadow, log-only, posting nothing and gating nothing, which I come back to further down.

The part I would recommend to anyone doing this: we kept Duo's rules file, format and all. Our repo instructions still live at `.gitlab/duo/mr-review-instructions.yaml` and both reviewers read the same file, so running them side by side cost nothing and the comparison was direct.

The comparison went one way. On a seeded security defect ours traced four attack vectors Duo never saw, including an absolute-path escape and a second vulnerable caller that turned a delete bug into an arbitrary file read. On real feature work it caught a blocking defect that would have signed every legacy user out moments after login, which Duo waved through because Duo trusted the diff's description of itself instead of reading the code. And on the one merge request that contained a real blocking defect, Duo failed silently, posting nothing but a "something went wrong" note nobody saw.

So Duo is on the way out. The rules file stays exactly where it is, since our reviewer reads it, and Duo can be pointed back at the same file if we ever change our minds. No big-bang cutover, no forked formats.

## What in-house bought us

Calibration, mostly. The rules file is per-path domain knowledge rather than a style guide: the failure patterns of a Windows-only Electron recorder, the release gate facts, the catalogue of tests that cannot be allowed to fail. The reviewer judges like someone who has been burned here before, because effectively it has. On real merge requests we have watched five of the seven rule entries fire on a single diff.

The rules are written for precision rather than coverage. A rule that fires on clean code costs more than a rule you left out.

The manners are designed in rather than hoped for. It does not re-post a finding it has already made, it resolves its own threads once a finding clears, and it leaves any thread a human has replied to alone. A broken reviewer exits as a failure, never as a clean review. Duo's silent failure above is exactly the behaviour we designed against: an advisory reviewer that fails silently trains people to treat review output as background noise.

The gate is real. Blocking findings fail the pipeline, a bot-only approval rule sits alongside the unchanged human rule, approvals reset when new commits land, and the bot approves but never merges. Rules load from the target branch, so a change cannot weaken the standards it is judged by. Duo comments; this one decides.

The full loop has already run unattended overnight: blocking finding posted at 2:52am, the author fixed it, the finding cleared and the merge went through with nobody waiting on me.

The economics are honest. Duo is 25 US cents per review, flat. Ours measures US$0.96 to $2.53 for a review pass, and US$1.65 to $4.38 all-in once the Sonnet 5 shadow triage pass is counted, which adds 58 to 106 percent on top. That is six reviews of the component's own merge requests. The figures live in `infra/cost.tf` and `docs/rollout/agentic-review.md`, and a test guards them against drift. An earlier number, US$0.62 to $1.05, is still quoted in the repo. It was a single-pass measurement on desktop-application !182 taken before shadow triage existed, so it is not what a review costs today. The worst case so far is $4.72 over 35 turns on a 17-file prose-heavy diff in the component's own repo. Cost tracks turn count, not diff size. At the volume we expect that is US$165 to $438 a month against a $500 budget that alerts and does not enforce. More expensive, and worth it: the extra spend is the difference between "tidy up some Sentry noise" and "this signs every legacy user out". That $4.72 run also told us exactly where the money goes, which is what the staged pipeline further down is about.

The concrete example is contented-app !46, and it is not flattering. Six review rounds on one planning document cost US$33.62 and 55.4 minutes of model time for 20 findings, which is about US$1.68 a finding. US$13.62 of that is the shadow triage pass, which produced nothing user-facing because it runs log-only, and one triage run failed outright after 33 turns and US$2.33 with its output containing no usable JSON.

## The reviewer has a name now

There are two GitLab service accounts. [snape-contentedai](https://gitlab.com/snape-contentedai) opens the merge requests and pushes the branches. [moody-contentedai](https://gitlab.com/moody-contentedai) posts the review findings. Both were renamed and re-avatared into those handles within about three minutes of each other on the afternoon of 3 September 2026, shortly after the team voted. The coding account is a day old. It was created the night before and opened its first merge request six minutes after it existed.

Before that they were the component, agentic-review, and a service account. The names came out of a poll in #general on the day, which closed with Snape on six votes and nib on four from five respondents. My rule was that there are two agents, so the top two win. Snape got there as a write-in: Lucy Pink posted "I would like to add snape" and Siena replied "SNAPE yes", and I changed my own vote to it. nib collected "lol nib" and "isnt that the name of health insurance?", and then Frances, who had proposed it, said "I feel like we should have another Harry Potter name", so the second name went back open. Moody came out of Claude's own recommendation and I took it: "Moody is the best fit. 'Constant vigilance' is the code reviewer's entire job, and Mad-Eye is the one who spots what everyone else walked past."

Snape is not arbitrary either. Our values workshop on 17 March 2026 mapped each company value to a Harry Potter character, and "Execution Beats Talk" went to Snape, described in the notes as a tenacious doer who got things done without fanfare. So the coding agent carries the name of the value it embodies, picked by vote, and the reviewer carries the thing it reviews for.

The naming then broke the agent's own commits. On !46 the `dco-check` job failed on four consecutive pipelines while the review job passed every time. The account was renamed partway through the merge request, so the sign-off line on two commits still read the old name while the author field read the new one, and the check rejected the mismatch. The first commit on that branch is authored under the old name and the later ones under the new one, so the rename is legible in the history. The agent could not fix it itself, because it has no git and no working tree, so I rebased the branch and force-pushed at 8:54pm and the check passes now. Renaming the reviewer's counterpart after a fictional character is what made a compliance check reject its work. That is not a failure mode I had budgeted for.

Naming them changed how people talk about them. Within a few hours of the poll I was writing "Best adhere to Moody's review" in Slack, which is a sentence you write about a colleague and not about a CI job. I am not sure that is a problem, since a reviewer people argue with is the better failure mode over one they ignore.

## It reviews itself, and that is the QA

The component reviews its own merge requests, and the self-review has already earned its keep.

It flagged replacement wording it had itself suggested one run earlier as describing a pipeline state that cannot occur, and it was right the second time. On another pass it found a defect in the fix for a defect it had raised: the patch suppressed the exact telemetry the instrumentation had been added to capture. And on a documentation-heavy MR its findings converged, two, then one, then one, then zero posted, instead of generating work forever, which is the difference between an inspector and a treadmill.

An inspector strict enough to fail its own paperwork is the one I trust with what comes next.

## The test that could not fail

The best finding so far is not on the component's own code. It is on desktop-application [!201](https://gitlab.com/development9650648/desktop-application/-/merge_requests/201), `fix(recorder): reduce visualizer overhead`, Richard Carvalho's visualizer work, merged at 3:06pm on 3 September.

The reviewer flagged a test that could not fail. In `src/renderer/components/volume-tracks.test.tsx`, `requestAnimationFrame` never fires under the test environment, so the draw ran once at zero progress and collapsed every point to zero regardless of the input. The assertion could not have failed. Posted 6:51am, severity important, confidence 88.

Then the part I am not happy about. Three seconds later, at 6:51am, the bot approved the merge request with that finding unaddressed. It did the same thing in all ten review rounds on that merge request: post important findings, approve in the same run, get unapproved by the next push. Only findings at blocking severity fail the pipeline, so an important finding and an approval can coexist. That is wrong. An approval should carry an assertion that nothing important is outstanding, and ours does not. It is the next thing to fix in the component.

The human loop still worked, because Richard drove it. The test now stubs `requestAnimationFrame`, drives the frames with fake timers and asserts real resampled geometry. He added a missing test for the visualizer hook. And while fixing the guard the reviewer had asked for he found a genuine latent bug of his own, a zero-length buffer producing a modulo by zero and `NaN` indices, which nothing had flagged. Two approvals were required and both landed: moody-contentedai at 1:53pm, me at 3:06pm.

## The confidence gate is the wrong instrument

The second thing I am not happy about is the confidence gate. A finding scoring below 80 is recorded and not posted, and on !46 that dropped four important-severity findings across the six rounds, the closest of them at 78. Rounds five and six reviewed a byte-identical diff and posted one finding and then three, at different cost.

The reviewer says the same thing about itself in its own suppression note: its confidence is unstable enough across runs on an identical diff that a near-miss repeated across runs carries more signal than any single score does. I agree with it. A fixed numeric threshold on an unstable score is the wrong instrument, and the signal worth acting on is the near-miss that keeps coming back. We do not act on it yet.

## Next for the reviewer: a staged pipeline

This one is mostly a plan rather than shipped code, and the spec lives in the component repo (`docs/review-pipeline.md`). Phase one is already running: the Sonnet 5 shadow triage pass is it, log-only beside every review. Phases two to four remain a plan. It exists because of what the cost numbers are made of.

Nearly all of the spend on an expensive review is the flagship model exploring: dozens of turns reading files to verify claims, 4.7 million cache-read input tokens on the $4.72 run. The judgement at the end, the severity calls and the decision to gate, is a small fraction of the bill. Exploration is work a cheaper model can do. Judgement is what earns the flagship rate.

So the plan is two stages behind the existing adapter contract. Stage one is a cheap model, Sonnet-class or an open-weight model on Bedrock's Mantle endpoint once one passes evaluation, and it does the exploration: it reads the repo, drafts candidate findings and assembles an evidence dossier of the excerpts, callers and cross-references that justify each candidate, plus anything it checked and found clean. Stage two is the flagship judge, Opus today with Fable as an opt-in if a review turns out to need it. It receives the diff, the rules, the candidates and the dossier, with no exploration of its own, and it audits each candidate, scans the diff for what stage one missed and emits the final findings. Ideally one turn instead of 35.

The invariants are the point. Gating authority never leaves the flagship: stage-one findings are never posted, never approve and never gate. A stage-one failure falls back to today's single-pass review, because a cost optimisation must never reduce reliability. That fallback has now fired in production rather than only being specified, on the triage run above that returned prose instead of JSON. Stage-one output is treated as untrusted input, since it is model output steered by an untrusted diff, and the judge is explicitly told that rejecting every candidate is a valid outcome, so the pipeline never anchors on its weakest model. Confidence scores are not comparable across models, so only the judge's scores ever touch the threshold.

It ships opt-in through one new input, `triage_model`, which defaults to empty and means today's single-pass behaviour, so no consumer changes on a version bump. And it rolls out the same way everything else here has: shadow mode first, with stage one running log-only beside the current review so we can measure overlap, missed-blocking rate and real cost per stage before anything changes what gets posted.

The tempting shortcut, skipping the judge entirely when triage reports a clean diff, is the biggest saving and the biggest risk, since it makes a cheap model's silence load-bearing. It comes last, and only if the shadow data earns it.

None of that is the thing that will bite first. Every consumer repository shares one GitLab runner. It is a single t3.medium with `runner_concurrency` set to 6, and that cap is global across all repos rather than per project, so each repository we add divides the same six slots. The sizing is measured rather than guessed: average CPU 0.61 percent, peak memory 180 MiB against a 512 MiB budget, and 173 jobs with zero out-of-memory events on the smaller instance it ran on before. At five or ten repositories the problem is queueing on one box, not the bill. Autoscaling and a second runner were deliberately deferred, and no threshold was ever written down for when one box stops being enough. That is a gap.

## Where the reviewer actually is

One correction to something I would have written a week ago. contented-app already has the reviewer, and it has not earned the word rollout.

[contented-app !45](https://gitlab.com/development9650648/contented-app/-/merge_requests/45) onboarded the component in `comment_only` mode and merged at 2:58pm on 3 September. Comment only, so not blocking. Before it merged the reviewer found two real blockers in the rules file itself: the secrets rule did not match `infra/envs/*.tfvars` and explicitly exempted it, even though both environment files carry a WorkOS client id, and no rule checked new SQL migrations for row-level security, so a tenant table missing its policy would have passed silently. A fix commit the same day addressed both.

The trap in !45 is worth writing down. Its own `code-review` job came back green, and green because the review skipped. The component reads the rules from the target branch, and !45 was the merge request adding that file to `development`, so there was nothing to read. The job posted "Review skipped", ran no review and gave no approval. A green review job is not evidence that a review happened.

Exactly one contented-app merge request has been opened since. [!46](https://gitlab.com/development9650648/contented-app/-/merge_requests/46), `docs: plan the contented-app UI and BFF repository split`, is where the reviewer genuinely ran on that repo for the first time: six rounds, 20 posted findings, still open. All 21 threads are resolved and I resolved every one of them myself, which is not the reviewer clearing its own threads as designed. The merge is armed and waiting on approval, nothing else.

The findings are on prose rather than code, which does not make them cheap. Step 6 of the plan listed its cut-over as exhaustive, remove `web-test`, `ship-web-dev` and `ship-web-prod` from `.gitlab-ci.yml`, but two `needs:` arrays elsewhere in the file still named `web-test`. A `needs:` entry naming a job that is not in the pipeline is a config error at pipeline creation rather than a skipped job, so following step 6 as written would have broken the `development` and `main` pipelines at once, on the one step the plan itself called irreversible. Severity important, confidence 90, posted 4:05pm. Snape wrote the fix and the thread is resolved.

The best of them is a production defect in a document. The plan deleted the front-end ship jobs at step 6, but until then the repository ships the front end on every merge to `development`. So once step 5 had pointed the new repository's UI at the BFF, the next unrelated backend merge would have redeployed the old bundle over it, deleted the new bundle's hashed assets and invalidated the edge, and the dev site would have quietly reverted. Severity important, confidence 85, posted in the fourth round. The fix was to gate those jobs at step 5 rather than delete them at step 6. That is a reviewer catching a production-affecting defect in a plain-English plan, before any of the code existed.

Every fix on that merge request is the agent's own. My only hands-on work was the rebase and resolving the threads.

So the honest state is this. One repository live and blocking, desktop-application. One repository with a single genuinely reviewed merge request still open, contented-app in comment-only mode. contented-gold-standard in progress and Mobile in the backlog.

## What comes next: non-engineers shipping via Delta

Here is the actual point. Once the desktop app has been stable behind the gate and contented-app (Contented 2.0) has moved from comment-only to the gate, we change who builds.

First me, hands tied. I will implement features exclusively through [Delta](https://zed.dev/blog/introducing-delta), the new agent coding environment from the Zed team: describe the change, an agent writes the code, the reviewer inspects it, I pull it in. DeltaDB syncs the agent conversation and the worktree into a shared thread anyone can open in a browser, and it sits on top of a normal git repo, so our GitLab flow is untouched. If the workflow cannot survive me, it cannot survive anyone.

Then Siena, our product manager, builds a feature herself through the same pipeline.

The uncomfortable truth about AI-written code is that it always looks right. I have [written before](/blog/beyond-vibe-coding/) about the gap between looking right and being right. That gap is fine when the author can tell the difference and dangerous when they cannot. The reviewer is what makes the second step responsible rather than reckless: every change gets senior-level inspection with our institutional knowledge baked in, dealbreakers are blocked automatically, feedback lands as plain-English notes the author or their agent can act on, and because the rules load from the target branch a change cannot weaken the standards it is judged by.

Delta makes building cheap and the reviewer makes it safe. Together they turn "non-engineers shipping to production" from a leap of faith into a pipeline with quality control built in.

The nearest thing to that loop so far is !46. Snape wrote the plan, Moody found the defect that would have quietly reverted the dev site, Snape wrote the fix, and I rebased the branch and resolved the threads. That is the whole loop running with a human as the last step rather than the middle one. It is also a planning document rather than a feature, and the Delta step has not started.

`[placeholder: what actually happened when I built my first feature Delta-only. Findings count, rounds, anything it caught]`

`[placeholder: first PM-built feature, and her unfiltered reaction to being reviewed by a robot]`
