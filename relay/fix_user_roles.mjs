
import PocketBase from 'pocketbase';

const pb = new PocketBase('http://pocketbase:8090');

async function fix() {
    try {
        // Log in as superuser to have full rights
        await pb.collection('_superusers').authWithPassword('user@pocketcoder.app', 'DbAQOXs4gO4pK0h0pmlp8kyLF0Sr1BzO');
        console.log("✅ Superuser Auth Success");

        // Fix Agent
        const agent = await pb.collection('users').getFirstListItem('email = "agent@pocketcoder.local"');
        await pb.collection('users').update(agent.id, { role: 'agent' });
        console.log("✅ Updated agent role to 'agent'");

        // Fix Admin
        const admin = await pb.collection('users').getFirstListItem('email = "admin@pocketcoder.local"');
        await pb.collection('users').update(admin.id, { role: 'admin' });
        console.log("✅ Updated admin role to 'admin'");

    } catch (e) {
        console.error("❌ Fix failed:", e.message);
        if (e.response) console.error("Response:", JSON.stringify(e.response, null, 2));
    }
}

fix();
