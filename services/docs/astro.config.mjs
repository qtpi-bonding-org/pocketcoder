import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
    integrations: [
        starlight({
            title: 'PocketCoder',
            description: 'PocketCoder Documentation',
            customCss: ['./src/custom.css'],
            head: [],
            sidebar: [
                {
                    label: 'Guides',
                    items: [
                        { label: 'Architecture', link: '/architecture' },
                        { label: 'Development', link: '/development' },
                        { label: 'Adding Tools', link: '/guides/adding_tools' },
                    ],
                },
                {
                    label: 'Reference',
                    items: [
                        { label: 'Backend (Go)', link: '/reference/backend' },
                        { label: 'Proxy (Rust)', link: '/reference/proxy' },
                        { label: 'Tools & Interface (TS)', link: '/reference/tools' },
                    ],
                },
            ],
            social: [
                {
                    label: 'Codeberg',
                    href: 'https://codeberg.org/qtpi-bonding-org/pocketcoder',
                    icon: 'codeberg',
                },
            ],
        }),
    ],
});
