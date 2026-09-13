import { existsSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const BLOG_BASE = './src/content/blog';
const BLOG_ROOT = path.resolve(process.cwd(), BLOG_BASE);

// Root-absolute so it resolves the same way regardless of where the post file
// lives inside the collection.
const DRAFT_PLACEHOLDER = '/src/assets/draft-placeholder.svg';

/**
 * Astro's `image()` helper defers resolution to the build, so a frontmatter
 * image that does not exist on disk fails the whole build (ImageNotFound)
 * even when the post is an unpublished draft. Check the file up front so we
 * can decide what to do about it.
 */
function blogImageExists(imagePath: string): boolean {
  if (existsSync(path.resolve(BLOG_ROOT, imagePath))) {
    return true;
  }

  // Posts nested in subdirectories resolve bare filenames against their own
  // directory, so fall back to a basename lookup before declaring it missing.
  const basename = path.basename(imagePath);

  return readdirSync(BLOG_ROOT, { recursive: true }).some(
    (entry) => path.basename(String(entry)) === basename,
  );
}

/**
 * Swaps in a placeholder when a draft's `heroImage` is missing, so an
 * in-progress post cannot break the build and still previews with a hero in
 * `astro dev`. Published posts still fail loudly, because a live post silently
 * losing its hero image is the worse outcome.
 */
function replaceMissingDraftHeroImage(raw: unknown): unknown {
  if (raw === null || typeof raw !== 'object') {
    return raw;
  }

  const data = raw as Record<string, unknown>;
  const heroImage = data.heroImage;

  if (data.draft !== true || typeof heroImage !== 'string' || heroImage.length === 0) {
    return raw;
  }

  if (blogImageExists(heroImage)) {
    return raw;
  }

  console.warn(
    `[content] Draft "${String(data.title ?? 'untitled')}" references a missing heroImage ` +
      `("${heroImage}"). Using the draft placeholder — add the file before publishing.`,
  );

  return { ...data, heroImage: DRAFT_PLACEHOLDER };
}

const blog = defineCollection({
  loader: glob({ pattern: '**/*.{md,mdx}', base: BLOG_BASE }),
  schema: ({ image }) =>
    z.preprocess(
      replaceMissingDraftHeroImage,
      z.object({
        title: z.string(),
        description: z.string(),
        date: z.coerce.date(),
        updatedDate: z.coerce.date().optional(),
        heroImage: image().optional(),
        heroImageCaption: z.string().optional(),
        tags: z.array(z.string()).default([]),
        draft: z.boolean().default(false),
        unlisted: z.boolean().default(false),
      }),
    ),
});

export const collections = { blog };
