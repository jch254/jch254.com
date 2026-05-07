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

The site is served by **GitHub Pages** with the custom domain in `public/CNAME`.
Primary deployment runs through **AWS CodeBuild**. The previous GitHub Actions
workflow is kept as a disabled backup at
`.github/workflows/deploy-gh-pages.yml.disabled`.

Deploys use [`buildspec.yml`](buildspec.yml):

1. CodeBuild clones `jch254/jch254.com`
2. `pnpm install --frozen-lockfile` installs dependencies
3. CodeBuild applies Terraform through `infrastructure/deploy-infrastructure.bash`
4. `pnpm run build` generates the Astro static site in `dist/`
5. CodeBuild commits `dist/` to the `gh-pages` branch
6. GitHub Pages serves the `gh-pages` branch

### CodeBuild setup

The CodeBuild project and service role are managed by Terraform in
`infrastructure/`. In GitHub, set **Settings > Pages > Build and deployment**
to deploy from the `gh-pages` branch, `/ (root)`.
If the live site stays stale while `gh-pages` contains the expected HTML, check
that Pages is not still set to **GitHub Actions** / workflow mode. The minimal
CodeBuild deploy token cannot change this setting; use the GitHub UI or a
temporary admin/Pages-write token for that one-time switch.
If automatic push deploys are enabled, the AWS account also needs CodeBuild's
GitHub source connection/credentials configured for webhook creation.

Terraform-managed CodeBuild environment variables:

| Variable | Type | Description |
| :------- | :--- | :---------- |
| `AWS_DEFAULT_REGION` | Plaintext | Defaults to `ap-southeast-4` |
| `REMOTE_STATE_BUCKET` | Plaintext | Defaults to `jch254-terraform-remote-state` |
| `TF_STATE_KEY` | Plaintext | Defaults to `jch254dotcom-prod-infrastructure` |
| `GITHUB_REPOSITORY` | Plaintext | Defaults to `jch254/jch254.com` |
| `PAGES_BRANCH` | Plaintext | Defaults to `gh-pages` |
| `BUILD_OUTPUT_DIR` | Plaintext | Defaults to `dist` |
| `GIT_COMMITTER_NAME` | Plaintext, optional | Commit author name for deploy commits |
| `GIT_COMMITTER_EMAIL` | Plaintext, optional | Commit author email for deploy commits |

Buildspec-managed SSM environment variables:

| Variable | Parameter | Description |
| :------- | :-------- | :---------- |
| `GITHUB_TOKEN` | `/jch254dotcom/github-token` | GitHub token used only to push `gh-pages` |
| `CLOUDFLARE_API_TOKEN` | `/jch254dotcom/cloudflare-api-token` | Cloudflare token used by Terraform |

SSM parameters managed as placeholders by Terraform:

| Parameter | Description |
| :------- | :---------- |
| `/jch254dotcom/github-token` | GitHub token used by CodeBuild to push `gh-pages` |
| `/jch254dotcom/cloudflare-api-token` | Cloudflare token used by Terraform |

In CodeBuild, the buildspec loads the Cloudflare token from SSM into
`CLOUDFLARE_API_TOKEN` before running plan/apply; there is no plaintext
Terraform variable for it.

The GitHub token should be a fine-grained token scoped to this repository with
**Contents: Read and write**. No Pages, Actions, admin, package, or workflow
permissions are required for the branch-push deploy.

Update the placeholder values in SSM:

```bash
aws ssm put-parameter \
  --region ap-southeast-4 \
  --name /jch254dotcom/github-token \
  --type SecureString \
  --value "$GITHUB_TOKEN" \
  --overwrite

aws ssm put-parameter \
  --region ap-southeast-4 \
  --name /jch254dotcom/cloudflare-api-token \
  --type SecureString \
  --value "$CLOUDFLARE_API_TOKEN" \
  --overwrite
```

Manual deploy:

```bash
aws codebuild start-build \
  --region ap-southeast-4 \
  --project-name jch254dotcom
```

To use the GitHub Actions backup later:

1. Rename `.github/workflows/deploy-gh-pages.yml.disabled` back to `.github/workflows/deploy-gh-pages.yml`
2. Keep **Settings > Pages > Build and deployment** pointed at the `gh-pages` branch, `/ (root)`
3. Pause the CodeBuild trigger/project while the backup workflow is active

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
