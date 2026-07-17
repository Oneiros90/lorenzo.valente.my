import { copyFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

mkdirSync('dist', { recursive: true });
copyFileSync('dist/index.html', 'enceladus.html');
console.log('Built enceladus.html');
