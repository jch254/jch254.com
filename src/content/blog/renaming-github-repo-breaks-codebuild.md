---
title: "Renaming a GitHub Repo Silently Breaks AWS CodeBuild"
description: "Renamed a GitHub repo. Pushed multiple commits. Nothing deployed. No errors anywhere. Turns out CodeBuild doesn't follow GitHub's repo redirects, and the webhook linkage breaks without telling you."
date: 2026-04-15
tags: ["aws", "infrastructure", "terraform"]
draft: true
---

I pushed three commits over a few hours. Nothing deployed.

No failed builds. No error emails. No Slack alerts. CodeBuild wasn't failing. It just wasn't running.

The only thing that had changed was the repo name.

## What's actually broken

When you create a CodeBuild project linked to a GitHub repo, AWS stores the full repository URL in the source configuration. It also registers a webhook on the GitHub side that points back to CodeBuild.

Renaming a repo on GitHub creates a redirect from the old URL to the new one. `git push` and `git clone` follow that redirect. So does the browser. Everything looks normal.

CodeBuild does not follow the redirect. The source URL still points to the old repo name. The webhook is tied to the old repository linkage inside CodeBuild. GitHub moves the webhook to the renamed repo, but CodeBuild does not update its internal linkage.

The webhook fires. CodeBuild ignores it.

No error. No log entry. The build never starts.

## Symptoms

- Pushes to the renamed repo don't trigger builds
- The CodeBuild project shows no recent build history
- `git push` works fine, no errors
- The webhook is missing entirely from the renamed repo's GitHub Settings
- The CodeBuild console still shows the old repo name in the source config
- CloudWatch has no CodeBuild logs for the period

The missing webhook is the key failure. GitHub didn't preserve it during the rename. It just disappeared. Terraform still thought it existed under the old repo name, so it never recreated it. Nothing to fire, nothing to deliver, nothing to fail.

## The fix

Update the source location in your Terraform config to match the new repo name.

```hcl
source {
  type     = "GITHUB"
  location = "https://github.com/org/new-repo-name"
}
```

Run `terraform plan`. If it shows an update, apply it.

That alone is not enough.

The webhook may be missing entirely. Terraform can still think it exists under the old repo name, so it never recreates it.

Force-replace it:

```bash
terraform destroy -target=aws_codebuild_webhook.main
terraform apply -target=aws_codebuild_webhook.main
```

That removes the stale state and creates a fresh webhook on the renamed repo. You should see it appear in the repo's GitHub Settings under Webhooks immediately after.

If you're not using Terraform, delete the webhook in GitHub and reconnect the source in the CodeBuild console. Same outcome.

## Why this is dangerous

GitHub repo renames are supposed to be safe. Git operations keep working. Links redirect. Everything looks fine. Everything looks correct until you notice nothing is happening.

The problem is that redirects do not propagate through integrations. Git follows them. Browsers follow them. AWS does not.

You rename the repo with confidence, and nothing breaks visibly. The pipeline just stops running.

There is no alert for "builds that should have started but didn't". The only signal is absence.

## I didn't have build notifications set up

That made this worse. A few commits went in before I noticed nothing was deploying.

Failure alerts would not have helped here. The builds never started. There were no failures.

What would have helped is noticing missing success notifications. If you're used to seeing "build succeeded" emails and they stop, that is your signal.

CodeBuild supports this with SNS. The setup went through three iterations before landing where it is now.

### Round 1: CodeStar Notifications + SNS

The first attempt used AWS CodeStar Notifications, which has native CodeBuild integration. Create a notification rule, point it at an SNS topic, add an email subscription, done. The emails were raw JSON blobs from AWS with no formatting. Functional.

This is also where the GitHub rename bug bit. The fix to `source_location` was bundled into this same commit because the rename had already silently broken the webhook.

### Round 2: EventBridge instead of CodeStar

CodeStar Notifications isn't available in `ap-southeast-4` (Melbourne). The next iteration replaced the notification rule with an EventBridge rule that watched for `CodeBuild Build State Change` events and routed them directly to SNS. Same raw JSON email output, but actually deployable in the target region.

### Round 3: Lambda formatter in the middle

Direct EventBridge to SNS produces an unreadable wall of JSON. The final iteration inserted a small Node.js Lambda between EventBridge and SNS. EventBridge triggers the Lambda, the Lambda parses the CodeBuild event payload, and SNS publishes a formatted plain-text email.

The formatter produces a human-readable layout:

```text
❌ Build FAILED
────────────────────────────────────────
Project:   namaste
Build:     #83
Status:    FAILED
Duration:  3m 37s
Commit:    797af25
Initiator: GitHub-Hookshot/d97595e

Phases:
  ✅ SUBMITTED          0s
  ✅ QUEUED             0s
  ...
  ❌ POST_BUILD         26s

Error Details:
  POST_BUILD: COMMAND_EXECUTION_ERROR: ...

Logs: https://...
```

The Lambda is bundled with esbuild, zipped by Terraform's `archive_file` data source, and deployed inline alongside the rest of the infrastructure. No separate stack, no manual steps.

This also exposed a missing IAM permission. Terraform needs `events:ListTargetsByRule` to reconcile the EventBridge target state. Without it, the plan fails. That is what caused build #83 to fail before I added it.

More setup than CodeStar Notifications, but it works in every region and gives you more control over filtering. Probably the better default.

## Takeaway

- If CodeBuild stops triggering after a repo rename, check the webhook before anything else
- GitHub redirects do not extend to AWS integrations
- Update the source URL in Terraform and recreate the webhook
- Use `destroy -target` if Terraform state prevents webhook recreation

---

If you're interested in real-world AWS behaviour and tradeoffs, I wrote about redesigning Lush Aural Treats to cut a $1,000 AWS bill down to near zero: [Lush Aural Treats AWS Cost Redesign](/blog/lush-aural-treats-aws-cost-redesign/).
