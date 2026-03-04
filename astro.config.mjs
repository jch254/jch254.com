// @ts-check
import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import mdx from '@astrojs/mdx';
import tailwind from '@astrojs/tailwind';
import sitemap from '@astrojs/sitemap';
import AutoImport from 'astro-auto-import';

// https://astro.build/config
export default defineConfig({
  site: 'https://jch254.com',
  integrations: [
    AutoImport({
      imports: [
        './src/components/embeds/YouTube.astro',
        './src/components/embeds/SoundCloud.astro',
        './src/components/embeds/Spotify.astro',
        './src/components/embeds/Vimeo.astro',
        './src/components/embeds/Instagram.astro',
      ],
    }),
    react(),
    mdx(),
    tailwind(),
    sitemap(),
  ],
  output: 'static',
});
