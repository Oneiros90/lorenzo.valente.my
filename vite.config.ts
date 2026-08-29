import { defineConfig, type Plugin } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import path from 'node:path';

function enceladusSlash(): Plugin {
  return {
    name: 'enceladus-slash',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        if (req.url === '/enceladus') {
          res.statusCode = 302;
          res.setHeader('Location', '/enceladus/');
          res.end();
          return;
        }
        next();
      });
    }
  };
}

export default defineConfig({
  plugins: [svelte(), enceladusSlash()],
  resolve: {
    alias: {
      $lib: path.resolve('src/lib'),
      $site: path.resolve('src/site')
    }
  },
  build: {
    target: 'esnext',
    cssCodeSplit: true,
    modulePreload: { polyfill: false },
    rollupOptions: {
      input: {
        main: path.resolve('index.html'),
        enceladus: path.resolve('enceladus/index.html')
      },
      output: {
        manualChunks(id) {
          if (id.includes('node_modules/@chenglou/pretext')) return 'pretext';
          if (id.includes('src/lib/webgl') || id.includes('src/lib/shaders')) return 'enceladus-gl';
        }
      }
    }
  }
});
