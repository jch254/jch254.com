---
title: "From Fingertip to GitHub Pages + Astro: Taking Back Control"
description: "Why I ditched Fingertip's no-code website builder and rebuilt jch254.com from scratch with Astro, Tailwind CSS, and GitHub Pages — and why it was worth every line of code."
date: 2026-03-05
tags: ["astro", "open source", "github pages"]
heroImage: ./fingertip-to-github-astro-hero.png
heroImageCaption: "Screenshot of the old jch254.com on Fingertip before the migration"
draft: false
---

I've been a software engineer for over 15 years. I've built platforms that scale to millions of users. And yet, for the longest time, my personal website lived on Fingertip - a no-code website builder.

It worked. Sort of. But "sort of" eventually stops being good enough. And as it turns out, my timing was impeccable - Fingertip has since been acquired by LinkTree and is shutting down in May 2026.

## Why Fingertip?

When I first set up jch254.com, I wanted something quick and low-friction. Fingertip delivered on that promise: drag, drop, publish, done. No build tools, no deploys, no thinking about infrastructure. For a personal landing page that mostly just pointed people to my GitHub and LinkedIn, it was fine.

## Where it fell short

**No real ownership.** My content lived on someone else's platform, behind someone else's CMS. If Fingertip shut down tomorrow, I'd be scrambling - and that's exactly what happened. LinkTree acquired Fingertip and is winding it down. For someone who preaches infrastructure resilience at work, the irony of being caught out by platform risk on my own personal site wasn't lost on me.

**Limited customisation.** Want a dark theme with a custom colour palette and pixel-perfect layout? Good luck. No-code tools give you freedom within a box - and the box is smaller than it looks. Every time I wanted to tweak something, I hit a wall that a few lines of CSS would have solved instantly.

**No blog workflow that made sense.** I write in Markdown. I think in Markdown. Fingertip's content editing felt like fighting the tool instead of working with it. For someone who lives in a code editor, it was friction I didn't need.

**Performance and SEO.** No-code builders ship JavaScript-heavy pages with bloated bundles. My personal site is mostly static text - it should load instantly, not carry the weight of a framework I don't need.

**Cost.** I was paying a recurring fee for a service I could replace with free hosting and open-source tools. That's not thrift - it's just common sense.

## Why Astro?

I'd been watching [Astro](https://astro.build) for a while. The pitch is compelling: a content-first static site generator that ships zero JavaScript by default, with the option to hydrate interactive components (React, in my case) only where needed. It's the "islands architecture" done right.

Here's what sold me:

- **Content Collections** - type-safe Markdown/MDX with Zod schemas. My blog posts have validated frontmatter, and I get autocomplete in my editor. It's the kind of DX that makes you wonder why other tools don't do this.
- **Tailwind CSS integration** - first-class support via `@astrojs/tailwind`. I designed the entire site with utility classes and a custom colour palette. No CSS files to maintain, no naming conventions to argue about.
- **Static output** - the entire site builds to plain HTML, CSS, and minimal JS. The `dist/` folder is just files. No server, no runtime, no cold starts.
- **MDX support** - when I want to drop a React component into a blog post, I can. When I don't, plain Markdown works perfectly.
- **Sitemap generation** - automatic, zero config, via `@astrojs/sitemap`.

The stack is simple: **Astro + React + TypeScript + Tailwind CSS**. That's it. No state management libraries, no API layers, no over-engineering. Just a personal site that does exactly what it needs to.

## Why GitHub Pages?

Free. Fast. Reliable. Deployed via GitHub Actions on every push to `main`. The workflow is straightforward:

1. Checkout the repo
2. Install dependencies with pnpm
3. Build with Astro
4. Deploy the `dist/` folder to GitHub Pages

Custom domain? Just a `CNAME` file in the `public/` directory. SSL? Handled automatically. CDN? GitHub's global edge network. Total monthly cost: **$0**.

For a static personal site, anything more than this is over-engineering.

## The build process

The migration itself was surprisingly quick. GitHub Copilot did a lot of the heavy lifting - scaffolding components, generating Tailwind utility classes, wiring up content collections. The AI-assisted workflow meant I could focus on design decisions and content rather than boilerplate.

The site structure is clean:

- `src/pages/` - Astro pages (home, resume, blog listing, blog post detail, 404)
- `src/components/` - reusable Astro components (Hero, BlogCard, Breadcrumb, Footer)
- `src/content/blog/` - Markdown blog posts with type-safe schemas
- `src/layouts/` - base layout with meta tags, fonts, and global styles

Every blog post is a `.md` file with frontmatter. No CMS, no database, no admin panel. I write in my editor, commit, push, and it's live. The workflow I always wanted.

## What I gained

**Full ownership.** The source code is on GitHub. The content is in Markdown files I control. If GitHub Pages disappeared tomorrow, I could deploy the same `dist/` folder to Cloudflare Pages, Netlify, or an S3 bucket in minutes.

**Performance.** The site loads almost instantly. Zero JavaScript on most pages. Lighthouse scores that actually mean something.

**Creative freedom.** The dark theme with the green accent colour, the card-based layouts, the responsive hero with social icons - all built exactly how I envisioned them. Try getting that level of control from a no-code builder.

**A proper blog.** Markdown files, version-controlled, with tags, dates, and descriptions. No more fighting a WYSIWYG editor that mangles my formatting.

**Cost savings.** From a monthly subscription to $0/month. The domain registration is the only ongoing cost.

## The takeaway

If you're a developer hosting your personal site on a no-code platform, ask yourself: why? The tools available today - Astro, Tailwind, GitHub Pages, Copilot - make it trivially easy to build something better, faster, and cheaper than what any drag-and-drop builder can offer. You get full control, better performance, and a site that actually represents your craft.

Fingertip served its purpose. But for a software engineer, there's something deeply satisfying about a personal site that's just code, content, and a deploy pipeline. No middleman. No compromises.

The source code is open: [github.com/jch254/jch254.com](https://github.com/jch254/jch254.com)
