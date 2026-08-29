import type { Attachment } from 'svelte/attachments';
import { saveDataEnabled } from './capabilities';

type SceneOptions = {
	desktopOnly?: boolean;
	track?: string;
};

const clamp = (value: number) => Math.min(1, Math.max(0, value));

function motionQuery(desktopOnly: boolean) {
	const desktop = desktopOnly ? ' and (min-width: 900px) and (pointer: fine)' : '';
	return window.matchMedia(`(prefers-reduced-motion: no-preference)${desktop}`);
}

export function scrollScene({ desktopOnly = true, track }: SceneOptions = {}): Attachment<HTMLElement> {
	return (element) => {
		const media = motionQuery(desktopOnly);
		const observer = new IntersectionObserver(
			([entry]) => {
				element.toggleAttribute('data-in-view', entry.isIntersecting);
			},
			{ rootMargin: '-12% 0px -12%' }
		);
		observer.observe(element);

		let active = false;
		let raf = 0;
		let resize: ResizeObserver | null = null;
		const connection = (
			navigator as Navigator & {
				connection?: { addEventListener?: (type: string, listener: () => void) => void; removeEventListener?: (type: string, listener: () => void) => void };
			}
		).connection;

		const setNeutral = () => {
			element.toggleAttribute('data-static-scene', true);
			element.style.setProperty('--scene-progress', '0.5');
			element.style.setProperty('--scene-x', '0px');
			element.style.setProperty('--scene-y', '0px');
			element.style.setProperty('--scene-y-reverse', '0px');
		};

		const update = () => {
			raf = 0;
			if (!active) return;
			const rect = element.getBoundingClientRect();
			const distance = Math.max(1, element.offsetHeight - window.innerHeight);
			const progress = clamp(-rect.top / distance);
			const offset = (progress - 0.5) * window.innerHeight * 0.12;
			element.style.setProperty('--scene-progress', progress.toFixed(4));
			element.style.setProperty('--scene-y', `${offset.toFixed(2)}px`);
			element.style.setProperty('--scene-y-reverse', `${(-offset).toFixed(2)}px`);
			const trackElement = track ? element.querySelector<HTMLElement>(track) : null;
			if (trackElement) {
				const viewportWidth = trackElement.parentElement?.clientWidth ?? element.clientWidth;
				const travel = Math.max(0, trackElement.scrollWidth - viewportWidth);
				element.style.setProperty('--scene-x', `${(-travel * progress).toFixed(2)}px`);
			}
		};

		const requestUpdate = () => {
			if (!raf) raf = requestAnimationFrame(update);
		};

		const stop = () => {
			if (active) {
				active = false;
				cancelAnimationFrame(raf);
				raf = 0;
				resize?.disconnect();
				resize = null;
				window.removeEventListener('scroll', requestUpdate);
				window.removeEventListener('resize', requestUpdate);
			}
			setNeutral();
		};

		const start = () => {
			if (active) return;
			active = true;
			element.removeAttribute('data-static-scene');
			resize = new ResizeObserver(requestUpdate);
			resize.observe(element);
			const trackElement = track ? element.querySelector<HTMLElement>(track) : null;
			if (trackElement) {
				resize.observe(trackElement);
				if (trackElement.parentElement) resize.observe(trackElement.parentElement);
			}
			window.addEventListener('scroll', requestUpdate, { passive: true });
			window.addEventListener('resize', requestUpdate);
			requestUpdate();
		};

		const reconcile = () => {
			if (media.matches && !saveDataEnabled()) start();
			else stop();
		};

		media.addEventListener('change', reconcile);
		connection?.addEventListener?.('change', reconcile);
		reconcile();

		return () => {
			if (active) {
				active = false;
				cancelAnimationFrame(raf);
				resize?.disconnect();
				window.removeEventListener('scroll', requestUpdate);
				window.removeEventListener('resize', requestUpdate);
			}
			observer.disconnect();
			media.removeEventListener('change', reconcile);
			connection?.removeEventListener?.('change', reconcile);
		};
	};
}

export function navigationProgress(
	ids: string[],
	onChapter: (id: string) => void
): Attachment<HTMLElement> {
	return (element) => {
		let raf = 0;

		const update = () => {
			raf = 0;
			const root = document.documentElement;
			const distance = Math.max(1, root.scrollHeight - window.innerHeight);
			element.style.setProperty('--page-progress', clamp(window.scrollY / distance).toFixed(4));

			const line = window.innerHeight * 0.42;
			let current = ids[0] ?? '';
			let nearest = Number.POSITIVE_INFINITY;
			for (const id of ids) {
				const section = document.getElementById(id);
				if (!section) continue;
				const rect = section.getBoundingClientRect();
				const distanceFromLine = Math.abs(rect.top - line);
				if (rect.top <= line && rect.bottom > line) {
					current = id;
					break;
				}
				if (distanceFromLine < nearest) {
					nearest = distanceFromLine;
					current = id;
				}
			}
			onChapter(current);
		};

		const requestUpdate = () => {
			if (!raf) raf = requestAnimationFrame(update);
		};

		window.addEventListener('scroll', requestUpdate, { passive: true });
		window.addEventListener('resize', requestUpdate);
		requestUpdate();

		return () => {
			cancelAnimationFrame(raf);
			window.removeEventListener('scroll', requestUpdate);
			window.removeEventListener('resize', requestUpdate);
		};
	};
}
