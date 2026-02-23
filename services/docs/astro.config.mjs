import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
    integrations: [
        starlight({
            title: 'PocketCoder',
            description: 'PocketCoder Documentation',
            head: [],
            sidebar: [
                {
                    label: 'Guides',
                    items: [
                        { label: 'Architecture', link: '/architecture' },
                        { label: 'Development', link: '/development' },
                    ],
                },
                {
                    label: 'Reference',
                    items: [
                        { label: 'Backend (Go)', link: '/reference/backend' },
                        { label: 'Proxy (Rust)', link: '/reference/proxy' },
                    ],
                },
            ],
            social: [
                {
                    label: 'GitHub',
                    href: 'https://github.com/qtpi-bonding-org/pocketcoder',
                    icon: 'github',
                },
            ],
        }),
    ],
});
