import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import { viteSingleFile } from 'vite-plugin-singlefile';
import path from 'node:path';
import { cvProfilePlugin } from './scripts/vite-plugin-cv-profile';

export default defineConfig({
  plugins: [cvProfilePlugin(), svelte(), viteSingleFile()],
  resolve: {
    alias: {
      $lib: path.resolve('src/lib')
    }
  },
  build: {
    target: 'esnext',
    assetsInlineLimit: 100000000,
    cssCodeSplit: false,
    rollupOptions: {
      output: {
        inlineDynamicImports: true
      }
    }
  }
});
