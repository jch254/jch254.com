# [jch254.com](https://jch254.com)

Personal website and blog, built with [Astro](https://astro.build) + React + TypeScript + Tailwind CSS. See [blog post](https://jch254.com/blog/fingertip-to-github-astro) for more details.

## Stack

- **Astro** — static site generator (content-first, zero JS by default)
- **React** — interactive islands where needed (`@astrojs/react`)
- **MDX** — JSX-in-Markdown for rich blog posts with embeds (`@astrojs/mdx`)
- **Tailwind CSS** — utility-first styling (`@astrojs/tailwind`) + `@tailwindcss/typography`
- **Content Collections** — type-safe blog post schema in `src/content/blog/`
- **Sitemap** — auto-generated at build time (`@astrojs/sitemap`)
- **Auto Import** — embed components auto-imported into MDX (`astro-auto-import`)
- **Sharp** — image optimization at build time

## Project Structure

```text
/
├── public/              # Static assets (CNAME, robots.txt, favicon.ico, favicon.svg, og-default.png)
├── src/
│   ├── components/      # Astro components (Hero, BlogCard, Breadcrumb, SectionCard, etc.)
│   │   └── embeds/      # Media embed components (YouTube, SoundCloud, Spotify, Vimeo, Instagram)
│   ├── content/
│   │   └── blog/        # Markdown / MDX blog posts (Content Collection)
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
| `pnpm install`     | Install dependencies                         |
| `pnpm run dev`     | Start dev server at `localhost:4321`          |
| `pnpm run build`   | Build production site to `./dist/`           |
| `pnpm run preview` | Preview the production build locally         |

## Deployment

Deployed to **GitHub Pages** via GitHub Actions:

1. In your repo, go to **Settings > Pages** and set the source to **GitHub Actions**
2. Every push to `main` or `master` triggers the workflow in `.github/workflows/deploy-gh-pages.yml`
3. The workflow installs dependencies, builds with Astro, and deploys the `dist/` output to GitHub Pages
4. Custom domain is configured via `public/CNAME`

## Adding a Blog Post

Create a new `.md` or `.mdx` file in `src/content/blog/`. Use `.mdx` if you need embed components:

```markdown
---
title: "Your Post Title"
description: "A brief description for cards and meta tags."
date: 2026-03-05
tags: ["tag1", "tag2"]
heroImage: ./your-hero-image.png   # optional — used as og:image for social sharing
heroImageCaption: "Alt text"       # optional
draft: false
---

Your content here...
```

The post will appear on the blog listing page and get its own URL at `/blog/<filename>/`.

## Embed Components

Five media embed components are auto-imported into all MDX blog posts via `astro-auto-import` — no manual imports needed:

| Component      | Props                                     | Example                                              |
| :------------- | :---------------------------------------- | :--------------------------------------------------- |
| `<YouTube />`  | `id` (required), `title?`                 | `<YouTube id="dQw4w9WgXcQ" />`                       |
| `<SoundCloud />`| `url` (required), `height?`              | `<SoundCloud url="https://soundcloud.com/..." />`     |
| `<Spotify />`  | `src` (URI or path), `height?`            | `<Spotify src="track/4uLU6hMCjMI75M1A2tKUQC" />`     |
| `<Vimeo />`    | `id` (required), `title?`                 | `<Vimeo id="123456789" />`                            |
| `<Instagram />` | `url` (URL or ID), `title?`              | `<Instagram url="https://instagram.com/p/..." />`     |

## SEO & Social Sharing

Every page includes full meta tags and structured data:

- **Open Graph & Twitter cards** — `og:image`, `twitter:image`, and related meta tags for link previews on LinkedIn, Twitter/X, etc.
- **JSON-LD structured data** — `Article` schema for blog posts, `WebSite` schema for other pages
- **Canonical URLs** — auto-generated for all pages
- **Blog posts with a `heroImage`** use that image as the OG image.
- **All other pages** fall back to `public/og-default.png`.

Use [LinkedIn's Post Inspector](https://www.linkedin.com/post-inspector/) or [Facebook's Sharing Debugger](https://developers.facebook.com/tools/debug/) to verify previews after deploying.

## License

MIT
