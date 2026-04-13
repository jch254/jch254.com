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

CodeBuild does not follow the redirect. The source URL still points to the old repo name. The webhook is tied to the old mapping. GitHub moves the webhook to the renamed repo, but CodeBuild does not update its internal linkage.

The webhook fires. CodeBuild ignores it.

No error. No log entry. The build never starts.

## Symptoms

- Pushes to the renamed repo don't trigger builds
- The CodeBuild project shows no recent build history
- `git push` works fine, no errors
- GitHub shows the webhook as active and delivering successfully (200 responses)
- The CodeBuild console still shows the old repo name in the source config
- CloudWatch has no CodeBuild logs for the period

The GitHub webhook returning 200 is the worst part. It makes the integration look healthy. The payload is delivered. CodeBuild drops it.

## The fix

Update the source location in your Terraform config to match the new repo name.

```hcl
source {
  type     = "GITHUB"
  location = "https://github.com/org/new-repo-name"
}
```

Run `terraform plan`. If it shows an update, apply it.

But updating the source URL alone wasn't enough. The existing OAuth connection between CodeBuild and GitHub goes stale when the repo is renamed. That is what actually breaks the webhook.

After `terraform apply`, go to the AWS Console. Open the CodeBuild project, edit the source, and re-authorize the GitHub connection. Re-select the renamed repo. This re-establishes the OAuth link that the webhook depends on.

If builds still don't trigger after that, destroy and recreate the webhook resource directly.

```bash
terraform destroy -target=aws_codebuild_webhook.main
terraform apply -target=aws_codebuild_webhook.main
```

Then push to main and check CodeBuild for a triggered build.

If you added SNS notifications in the same apply, confirm the subscription email before testing. AWS sends a confirmation link immediately. Nothing fires until you click it.

If you're not using Terraform, delete the webhook in GitHub and reconnect the source in the CodeBuild console. Same outcome.

## Why this is dangerous

GitHub repo renames are supposed to be safe. Git operations keep working. Links redirect. Everything looks fine.

The problem is that redirects do not propagate through integrations. Git follows them. Browsers follow them. AWS does not.

You rename the repo with confidence, and nothing breaks visibly. The pipeline just stops running.

There is no alert for "builds that should have started but didn't". The only signal is absence.

## I didn't have build notifications set up

That made this worse. A few commits went in before I noticed nothing was deploying.

Failure alerts would not have helped here. The builds never started. There were no failures.

What would have helped is noticing missing success notifications. If you're used to seeing "build succeeded" emails and they stop, that is your signal.

CodeBuild supports this with SNS. Small setup:

- Create an SNS topic
- Subscribe your email
- Add a notification rule to the CodeBuild project

I only enabled two events:

- Build succeeded
- Build failed

That is enough signal without noise. Worth doing early. Otherwise you end up checking the console after every push, or not checking at all.

## Region gotcha

I tried to set this up using CodeStar Notifications. It's not available in `ap-southeast-4`.

That means the SNS + notification rule approach isn't an option in some regions.

The workaround is EventBridge. CodeBuild emits build state events to EventBridge by default. You create a rule that matches on build state changes for your project, send that to an SNS topic, and subscribe your email.

More setup, but it works in every region and gives you more control over filtering. In hindsight, it's probably the better default anyway.

## Takeaway

- If CodeBuild stops triggering after a repo rename, check the webhook first
- The OAuth connection between CodeBuild and GitHub goes stale on rename. Re-authorize it in the console
- GitHub redirects do not extend to AWS integrations
- Update the source URL, re-authorize, and recreate the webhook
- `destroy -target` and `apply -target` on the webhook resource if a full apply doesn't fix it
