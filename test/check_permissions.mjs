import PocketBase from 'pocketbase';

const pb = new PocketBase('http://127.0.0.1:8090');

async function check() {
    try {
        // Just use the agent login if we can't do admin easily
        await pb.collection('users').authWithPassword('agent@pocketcoder.local', 'EJ6IiRKdHR8Do6IogD7PApyErxDZhUmp');
        const records = await pb.collection('permissions').getList(1, 1, {
            sort: '-created',
        });
        console.log(JSON.stringify(records.items[0], null, 2));
    } catch (e) {
        console.error(e.message);
    }
}

check();
