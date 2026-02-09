
import PocketBase from 'pocketbase';

const pb = new PocketBase('http://127.0.0.1:8090');

async function check() {
    try {
        await pb.collection('users').authWithPassword('agent@pocketcoder.local', 'EJ6IiRKdHR8Do6IogD7PApyErxDZhUmp');
        console.log("✅ Agent Auth Success");

        const messages = await pb.collection('messages').getList(1, 1, {
            sort: '-created',
        });
        console.log("Latest Message:", JSON.stringify(messages.items[0], null, 2));

        const perms = await pb.collection('permissions').getList(1, 1, {
            sort: '-created',
        });
        console.log("Latest Permission:", JSON.stringify(perms.items[0], null, 2));

    } catch (e) {
        console.error("❌ Link failed:", e.message);
        if (e.response) console.error("Response:", JSON.stringify(e.response, null, 2));
    }
}

check();
