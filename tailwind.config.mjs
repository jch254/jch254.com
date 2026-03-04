/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      colors: {
        // Dark theme palette matching the screenshots
        brand: {
          bg: '#0f0f1a',
          card: '#1a1a2e',
          'card-hover': '#222240',
          accent: '#1DB954',
          'accent-hover': '#1ed760',
          text: '#e2e2ef',
          muted: '#9a9ab0',
          border: '#2a2a45',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        mono: ['JetBrains Mono', 'Fira Code', 'monospace'],
      },
    },
  },
  plugins: [
    require('@tailwindcss/typography'),
  ],
};
