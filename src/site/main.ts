import '@fontsource-variable/space-grotesk/wght.css';
import '@fontsource/fraunces/400.css';
import '@fontsource/fraunces/600.css';
import '@fontsource/ibm-plex-mono/400.css';
import '@fontsource/ibm-plex-mono/500.css';
import { mount } from 'svelte';
import Site from './Site.svelte';
import { applyTheme, getInitialTheme } from './lib/theme';
import './styles/tokens.css';
import './styles/site.css';

applyTheme(getInitialTheme());
mount(Site, { target: document.getElementById('app')! });
