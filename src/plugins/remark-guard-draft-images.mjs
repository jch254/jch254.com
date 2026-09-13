import { existsSync } from 'node:fs';
import path from 'node:path';

const PLACEHOLDER = path.resolve(process.cwd(), 'src/assets/draft-placeholder.svg');

/**
 * Walks an mdast tree depth-first, calling `visitor` for every node.
 * Hand-rolled to avoid pulling in `unist-util-visit` for one guard.
 *
 * @param {any} node
 * @param {(node: any) => void} visitor
 */
function walk(node, visitor) {
  visitor(node);

  if (Array.isArray(node.children)) {
    for (const child of node.children) {
      walk(child, visitor);
    }
  }
}

/**
 * Points references to missing local images in **draft** posts at the draft
 * placeholder, so a work-in-progress post whose screenshots have not been
 * captured yet cannot fail the build and still previews with images in
 * `astro dev`. Published posts are left untouched and still fail loudly,
 * because shipping a live post with a broken image is worse than a red build.
 */
export default function remarkGuardDraftImages() {
  return (/** @type {any} */ tree, /** @type {any} */ file) => {
    if (file.data?.astro?.frontmatter?.draft !== true) {
      return;
    }

    const filePath = file.path;

    if (!filePath) {
      return;
    }

    const dir = path.dirname(filePath);

    walk(tree, (node) => {
      if (node.type !== 'image' || typeof node.url !== 'string') {
        return;
      }

      // Only guard relative paths; remote and root-absolute URLs are not
      // resolved off disk at build time.
      if (!node.url.startsWith('.')) {
        return;
      }

      if (existsSync(path.resolve(dir, node.url))) {
        return;
      }

      console.warn(
        `[markdown] Draft "${path.basename(filePath)}" references a missing image ` +
          `("${node.url}"). Using the draft placeholder — add the file before publishing.`,
      );

      // Markdown bodies only bundle relative paths, so point at the placeholder
      // relative to this post rather than using a root-absolute path.
      const relativePlaceholder = path.relative(dir, PLACEHOLDER);

      node.alt = `${node.alt || 'Draft placeholder'} (placeholder — ${node.url} not found)`;
      node.url = relativePlaceholder.startsWith('.')
        ? relativePlaceholder
        : `./${relativePlaceholder}`;
    });
  };
}
