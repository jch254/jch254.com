/**
 * Static endpoint that renders the resume PDF at build time.
 * Served at /resume.pdf in the built site.
 */
import type { APIRoute } from 'astro';
import { renderToBuffer } from '@react-pdf/renderer';
import { createElement } from 'react';
import ResumePdf from '../components/pdf/ResumePdf';

export const GET: APIRoute = async () => {
  const buffer = await renderToBuffer(createElement(ResumePdf));

  return new Response(new Uint8Array(buffer), {
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': 'inline; filename="Jordan Hornblow - Resume.pdf"',
    },
  });
};
