# jch254.com

Personal website and blog for Jordan Hornblow, built with [Astro](https://astro.build) + React + TypeScript + Tailwind CSS.

## Stack

- **Astro** — static site generator (content-first, zero JS by default)
- **React** — interactive islands where needed (`@astrojs/react`)
- **MDX** — JSX-in-Markdown for rich blog posts (`@astrojs/mdx`)
- **Tailwind CSS** — utility-first styling (`@astrojs/tailwind`)
- **Content Collections** — type-safe blog post schema in `src/content/blog/`
- **Sitemap** — auto-generated at build time (`@astrojs/sitemap`)

## Project Structure

```text
/
├── public/              # Static assets (_redirects, _headers, robots.txt, favicon)
├── src/
│   ├── components/      # Astro components (Hero, BlogCard, SectionCard, etc.)
│   ├── content/
│   │   └── blog/        # Markdown blog posts (Content Collection)
│   ├── layouts/
│   │   └── BaseLayout.astro
│   └── pages/
│       ├── index.astro       # Home page
│       ├── resume.astro      # Resume page
│       ├── 404.astro         # Custom 404
│       └── blog/
│           ├── index.astro   # Blog listing
│           └── [slug].astro  # Blog post detail
├── astro.config.mjs
├── tailwind.config.mjs
├── tsconfig.json
└── package.json
```

## Commands

| Command           | Action                                       |
| :---------------- | :------------------------------------------- |
| `npm install`     | Install dependencies                         |
| `npm run dev`     | Start dev server at `localhost:4321`          |
| `npm run build`   | Build production site to `./dist/`           |
| `npm run preview` | Preview the production build locally         |

## Deployment

Designed for **Cloudflare Pages** with Git integration:

1. Connect your repo to Cloudflare Pages
2. Set build command: `npm run build`
3. Set output directory: `dist`
4. Every push to `main` triggers an automatic build and deploy

The `public/_redirects` and `public/_headers` files are picked up automatically by Cloudflare Pages.

## Adding a Blog Post

Create a new `.md` file in `src/content/blog/`:

```markdown
---
title: "Your Post Title"
description: "A brief description for cards and meta tags."
date: 2026-03-05
tags: ["tag1", "tag2"]
draft: false
---

Your content here...
```

The post will appear on the blog listing page and get its own URL at `/blog/<filename>/`.

## License

MIT
