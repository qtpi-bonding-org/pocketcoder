import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
    integrations: [
        starlight({
            title: 'PocketCoder',
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
                        { label: 'Relay (Node.js)', link: '/reference/relay' },
                        { label: 'Proxy (Rust)', link: '/reference/proxy' },
                    ],
                },
            ],
            social: [
                {
                    label: 'GitHub',
                    href: 'https://github.com/pocketcoder-ai/pocketcoder',
                    icon: 'github',
                },
            ],
        }),
    ],
});
