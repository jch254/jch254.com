---
title: "The Way of Code Against Production"
description: "Rick Rubin rewrote the Tao Te Ching as vibe-coding aphorisms. Some of it maps cleanly to how I build. Some of it falls apart the moment a pager goes off."
date: 2026-06-30
tags: ["ai", "software engineering", "vibe coding"]
heroImage: "the-way-of-code-principles-against-how-i-build-hero.jpeg"
draft: true
---

Someone sent me [The Way of Code](https://www.thewayofcode.com/) last week, and they knew exactly what they were doing. I make music, and Rick Rubin is one of the reasons I hear records the way I do: the Chili Peppers albums I wore out, the spare menace of "99 Problems". Rubin's public mythology was never about technical knob-twiddling. He doesn't sell himself as the person engineering the sessions or playing on the records. His method, at least from the outside, is reduction: strip the song back, stay out of the artist's way, and react honestly to what's left. So when I learned he'd reworked the Tao Te Ching into 81 short chapters about building software, I did not close the tab. Lao Tzu's sage had been renamed The Vibe Coder, and the whole thing was wrapped in an interactive site Anthropic built. I was already sold.

Then the engineer caught up with the fan. I read it once for the pleasure of it, and again with a narrower question: ignore the romance, what does it actually claim about building software, and does any of it survive contact with production?

More of it survives than I expected. Under the mysticism is a set of principles I already argue for in reviews, plus one I argue against. The fair way to test that is to put the words next to production habits and see which ones still hold.

So here they are. Rubin's principles, quoted word for word, against how I build.

## The three treasures

There's only one chapter where Rubin stops being oblique and just enumerates. Chapter 67:

> I have three great treasures to share:
> Simplicity
> Patience
> Humility

He spends the next few lines glossing each one. Simplicity returns you to "the origin of being", humility lets you "inhabit the oneness of the cosmos". Drop the cosmos and you have a code review rubric. Simplicity, patience, humility. I've watched all three fail in production, and each one maps onto a habit I can point at in my own work. So let me take them in that order, with the lines that back them up.

## Simplicity

Chapter 31 states it without hedging:

> The Vibe Coder chooses simplicity.
> Only when there is no choice
> will he work with complexity.

Chapter 08 expands the idea into a short code of conduct: depth in thought, kindness in relations, competence in work, good timing in action. The first item is the one I'd staple to most of my infrastructure work: "In design: remain simple."

When I [redesigned Lush Aural Treats to cut a four-figure AWS bill to almost nothing](/blog/lush-aural-treats-aws-cost-redesign/), the win wasn't a clever piece of engineering. It was deletion. Fewer always-on components, fewer moving parts, less surface to pay for and reason about at 2am. The only complexity I kept was the complexity I had no way around.

"Only when there is no choice" is the half people skip. Complexity isn't banned, it's billed. You take it on deliberately, when the problem genuinely demands it, not because a pattern looked impressive in someone's conference talk. Building that same project multi-tenant from day one was real, chosen complexity. I paid for it up front because the alternative was a migration I'd hate later. That's the whole distinction, and it's the one I try to hold in design review: simple until the problem leaves you no choice.

## Patience

The patience chapters are the ones about not forcing the system. Chapter 63:

> See simplicity in the complicated
> and accomplish the remarkable in small steps.
> Meet the difficult while it's still simple.
> Solve the major while it's still minor.

"Meet the difficult while it's still simple" is the entire argument for catching problems at design time instead of in an incident channel. A concurrency bug is cheap in review and expensive in production, and the gap between those two prices is most of what good process buys you. It's why I run an audit pass before code ships rather than after it pages someone, and why chapter 64's warning that "those who rush to action defeat themselves" reads less like mysticism and more like a postmortem finding.

The same chapter tells you to "deal with things before they appear", which is harder than it sounds, because tooling is very good at hiding the thing you should be dealing with. Patience here isn't waiting. It's going to look for the confusion before it arrives on its own schedule.

## Humility

This is the cluster that gets misread as "let the AI do everything", which is the opposite of what it says. Chapter 17 ranks leaders by how invisible they are: the best one is barely known to exist, and when the work is finished the team says, "Amazing. We did it all ourselves." Chapter 10 gives the instruction directly:

> Love your project
> and lead without controlling.
> Do nothing
> and allow all things to be done.

The trap is reading "do nothing and allow all things to be done" as a licence to hand an agent an open-ended prompt and wander off. That's vibe coding in the worst sense, and it's the thing I keep arguing against. The closer reading is about *where* you spend control. You own the direction, the boundaries, the architecture, and then you stay out of the implementation's way. "Lead without controlling" is the exact [division of labour I use with coding assistants](/blog/beyond-vibe-coding/): I hold the system design, the model holds the keyboard. The architecture still has to come from a human. What you let go of is the line-by-line grip, not the responsibility.

"Amazing. We did it all ourselves" is the part I like most, because it doubles as a test. When my involvement was actually good, the system holds together and nobody remembers me wrestling it into shape. The same is true of a well-scoped agent session: the output looks obvious in hindsight, which usually means the direction was right and I can stop taking credit for the typing.

## The principle I argue with

Not all of it lands. Chapter 18:

> When the way of code is abandoned,
> doctrines of 'best practices' and 'standards' appear.
> When intuition is dismissed,
> cleverness and pretense follow.
> When harmony is unnoticed,
> rules and processes multiply.
> When software fails,
> zealous testers arise.

There's a real observation buried in here. Process does metastasise to paper over a lack of shared judgement, and I've sat through enough governance meetings to recognise rules multiplying in place of trust. But read straight, this is the most dangerous chapter in the book for a working engineer. "When software fails, zealous testers arise" is framed as decay. In my experience software fails because the testing wasn't zealous enough. Best practices aren't the symptom of some fall from grace. Most of them are scar tissue from real outages, written down so the next person doesn't have to bleed for the same lesson.

So I read 18 as a warning about cargo-culting, not an argument against rigour. Follow a standard because you understand the failure it prevents, never because it's a standard. That reading is defensible. The literal one gets you paged.

## Truthful words are not beautiful

One more line earns its place outside the three treasures. Chapter 81:

> Truthful words are not beautiful.
> Beautiful words are not truthful.

I keep arriving at the same idea from the operational side. A status that *reads* reassuring and a status that *is* accurate are different objects, and the distance between them is where you get hurt. A green CI run, a `latest` tag, a billing preview, [a screen that says "up to date"](/blog/up-to-date-wrong-future/): all beautiful words, none of them automatically true. The plain, unglamorous number is often the whole thing. The same chapter adds that "grounded men don't need to prove their point", which is also the best editing advice in the book.

## Where the metaphor breaks

I don't want to oversell this. The Way of Code is a poem, not a methodology, and the phrase "vibe coding" is doing an enormous amount of quiet work. The text is strongest as a set of dispositions: prefer the simple thing, move in small steps, hold direction lightly, don't mistake the reassuring word for the true one. It's weakest the instant you try to run it as an instruction. "Do nothing and allow all things to be done" is a lovely line and a catastrophic deployment strategy. Lao Tzu never had to roll back a migration at 2am.

And the version that resonates with me is the one where the human stays firmly in charge and the tooling disappears into the background. That isn't what most people mean by vibe coding, and it's the opposite of handing an agent the wheel. So I'm reading the book somewhat against its own branding. The principles survive. The label on the cover doesn't describe how I work.

## Which ones survive contact with production

Stripped down, here's what I'd keep:

- **Simplicity is the default. Complexity is a deliberate cost.** Chapters 31 and 08. The most useful idea in the book.
- **Meet problems while they're still small.** Chapters 63 and 64. Design and audit before shipping, not after the page goes off.
- **Lead without controlling.** Chapters 17 and 10. Own the architecture, let go of the keystrokes. The right posture for working with AI tools.
- **Truthful words are not beautiful.** Chapter 81. Distrust the reassuring status. Predictable beats impressive.

And the one I'd hand back: that best practices and tests are a sign of decay. They're scar tissue, and scar tissue is just information about where it hurt last time.

Rubin found these principles in a 2,500-year-old text about water and valleys. I keep finding the same ones in postmortems and AWS bills. That's either a coincidence or a hint that the good ideas in software were never really about software. Either way, the words held up better than I expected from a book that insists on calling me a Vibe Coder.

---

*The Way of Code is © Rick Rubin and Anthropic, all rights reserved. The passages above are short excerpts quoted for commentary and criticism. Read the whole thing, with its generative artwork, at [thewayofcode.com](https://www.thewayofcode.com/).*
