import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Mesa autenticada: cada tela depende da sessão. Cache Components
  // ficaria em conflito com cookies e dados por jogador.
  experimental: {
    authInterrupts: true,
    serverActions: {
      bodySizeLimit: "8mb",
    },
  },
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
