import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Static HTML/CSS/JS in `out/`, hostable anywhere (Vercel, Netlify, GitHub Pages, S3…).
  output: "export",
  // No image optimization server in a static export.
  images: { unoptimized: true },
  // Hosting under a sub-path (e.g. GitHub Pages project sites)? Set NEXT_BASE_PATH=/repo-name.
  basePath: process.env.NEXT_BASE_PATH || undefined,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
