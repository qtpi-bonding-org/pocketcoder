import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
    integrations: [
        starlight({
            title: 'PocketCoder',
            social: {
                github: 'https://github.com/pocketcoder-ai/pocketcoder',
            },
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
                    autogenerate: { directory: 'reference' },
                },
            ],
        }),
    ],
});
