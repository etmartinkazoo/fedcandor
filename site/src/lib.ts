// Prefix a site-relative path with the deploy base (/fedcandor/).
export function url(path = ''): string {
	const base = import.meta.env.BASE_URL.replace(/\/$/, '');
	const clean = path.replace(/^\//, '');
	return `${base}/${clean}`;
}

export const REPO = 'https://github.com/etmartinkazoo/fedcandor';
export const IMAGE = 'ghcr.io/etmartinkazoo/fedcandor';

export const SECTIONS = ['Start here', 'Using fedcandor', 'Running it', 'Reference'] as const;
