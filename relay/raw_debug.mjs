
import PocketBase from 'pocketbase';

const pb = new PocketBase('http://pocketbase:8090');

async function debug() {
    try {
        console.log("🔑 Logging in...");
        await pb.collection('users').authWithPassword('agent@pocketcoder.local', 'Ns1q3wYCetyu+Ad6yudzXmqJJsf7cERS');
        console.log("✅ Logged in.");

        console.log("📡 Fetching messages via raw fetch to see errors...");
        const res = await fetch('http://pocketbase:8090/api/collections/messages/records?limit=1', {
            headers: {
                'Authorization': pb.authStore.token
            }
        });

        const data = await res.json();
        console.log("Status:", res.status);
        console.log("Body:", JSON.stringify(data, null, 2));

    } catch (e) {
        console.error("❌ Debug script failed:", e.message);
    }
}

debug();
