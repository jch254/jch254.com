---
title: "Even the People Who Build Claude Code Got Lonely"
description: "Anthropic's own engineering lead said Claude Code made her team lonely. We spent two years measuring what agents do to velocity and cost, and nobody costed out what they do to the room."
date: 2026-06-26
tags: ["ai", "software engineering", "developer tools"]
heroImage: optimised-the-pair-out-of-pair-programming-hero.jpeg
draft: false
---

Anthropic's own engineering lead just said the quiet part out loud: building with Claude Code made her team lonely.

Read that again. The people who make the agent got lonely working with the agent. If anyone was going to make agent-first engineering feel socially healthy, it was the team building the agent. Best model, most context, every incentive for it to feel great. It didn't.

Fiona Fung, on Lenny's Podcast:

> After a while, we felt it could start being a lonely experience because we all started just working with our agents so much.

That snagged on something. We have spent two years arguing about whether these tools make us faster, and almost no time on what they quietly switch off.

## Nobody costed out the room

Look at what got measured in those two years. Velocity. Cost per task. PRs merged, time to first commit, lines shipped and lines deleted. Defect rates, lint scores, review turnaround. All of it tracked, charted, and A/B tested to three decimal places.

Nobody costed out what agents do to the room.

That is not an oversight so much as a habit. The things that got cheaper to measure got measured. Throughput fits on a dashboard. A team getting better at its craft does not, and it never did, so it fell off the edge of the spreadsheet the moment something easier to count showed up.

The agent optimises the number you were already watching. It says nothing about the one you were never able to graph. And the ungraphable one turns out to be load-bearing.

## The human pair quietly leaves

When the agent becomes your default pair, the human one quietly leaves. Nobody decides this. It just happens.

You stop turning to the person next to you to ask how they'd approach the thing. Why would you. The agent is right there, it answers in a second, it never sighs, it never makes you feel slow for asking. So you ask it instead. Every time. The friction that used to push you toward a colleague is gone, and so is the colleague.

You also stop watching anyone work. That is the part that took me a while to notice, because it is a loss of something you were getting for free without ever putting it on a list of things you'd miss.

## Most of what I know, I watched someone do first

This is the bit I take personally.

Roughly ninety percent of what I know about building software I learned by watching people better than me do it. Not from docs, not from a course, not from a finished pull request. From sitting close enough to see the order they did things in. What they checked first. The command they reached for without thinking. The thing they pointedly did *not* bother with. The quiet swearing when it broke anyway.

The other ten percent I learned by breaking prod and finding out.

None of that lives in the output. It lives in the process, and the process is exactly what an agent collapses into a single quiet exchange between one human and one model. The screen recording of how my mentor actually worked got switched off, and I switched it off myself, one convenient prompt at a time.

## A diff is the destination, never the route

Here is the thing a pull request cannot show you: everyone drives these tools completely differently.

Watch ten engineers use the same agent and you get ten genuinely different working styles. How they scope a prompt. When they let it run and when they yank the wheel back. What they paste in, what they refuse to. Whether they read the plan or skim it. The diff at the end is the cleaned-up destination. The route is where all the learning was, and the route never makes it into review.

I've written before about treating [AI as a collaborator rather than a code generator](/blog/beyond-vibe-coding/), with the human owning architecture and the model owning the typing. I still think that division is right. The [way of code](/blog/the-way-of-code-principles-against-how-i-build/) version of it, lead without controlling, is how I actually work.

What I undersold in both is simpler. A pair programmer was never only there for the code. Half the value was the second human in the loop, and you don't notice that half until you replace the human with a model and keep only the code half. The work still ships. The apprenticeship quietly stops.

## The fix has a name

Anthropic's fix has a name, because of course it does. Maker time. Lunches, hackathons, blocks carved out specifically so engineers sit together and watch each other actually use the tools.

Fung again:

> Every time I watch someone work, I learn something myself as well.

Sit with what that fix is. It is an admission. If you have to schedule humans into a room to watch each other work, then watching each other work was a real input all along, and the new workflow had quietly removed it. You don't put a process around something that wasn't load-bearing. Maker time is a patch for a dependency nobody listed until it went missing.

I'm not being smug here. I'd have removed the same thing, and largely did. Faster is a very easy yes. The cost shows up on a different page from the benefit, on a slower clock, and by the time you feel it you've forgotten what you traded for it.

## Faster alone, or better together

So here is where I've landed.

The agent makes you faster on your own. That part is real and I'm not giving it back. It does not make your team a team. That part is still on us, and it was always going to be, because it was never something a tool could do for you in the first place.

Shipping alone faster and getting better together are not the same win. They feel adjacent because both get filed under improvement, but only one of them compounds. Velocity is a rate you have to keep paying for. A team that learns from each other gets quietly more valuable every week without anyone running the agent any harder.

If even the people who build the agent had to schedule their way back into the same room, the rest of us should probably take the hint before we need the patch.

---

*Fiona Fung's comments are from her appearance on Lenny's Podcast, reported by Business Insider.*
