
import PocketBase from 'pocketbase';

const pb = new PocketBase('http://pocketbase:8090');

async function check() {
    try {
        await pb.collection('users').authWithPassword('agent@pocketcoder.local', 'Ns1q3wYCetyu+Ad6yudzXmqJJsf7cERS');
        console.log("✅ Agent Auth Success");

        // const usersColl = await pb.collection('users').getOne(pb.authStore.model.id);
        // console.log("User Record:", JSON.stringify(usersColl, null, 2));

        const users = await pb.collection('users').getList(1, 1);
        console.log("Latest User:", JSON.stringify(users.items[0], null, 2));

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
