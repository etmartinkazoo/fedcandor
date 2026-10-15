// @ts-check
import { defineConfig } from 'astro/config';

// Served from GitHub Pages at https://etmartinkazoo.github.io/fedcandor/
export default defineConfig({
	site: 'https://etmartinkazoo.github.io',
	base: '/fedcandor',
	trailingSlash: 'always',
	markdown: {
		shikiConfig: { theme: 'github-dark-default', wrap: true },
	},
});
