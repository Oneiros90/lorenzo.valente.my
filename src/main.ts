import { mount } from 'svelte';
import App from './App.svelte';
import '$lib/styles/global.css';
import '$lib/styles/hud.css';
import '$lib/styles/boot.css';
import '$lib/styles/panels.css';

mount(App, { target: document.getElementById('app')! });
