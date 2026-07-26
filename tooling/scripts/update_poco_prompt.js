const fs = require('fs');
const path = require('path');
const http = require('http');

function request(url, options, data) {
    return new Promise((resolve, reject) => {
        const req = http.request(url, options, (res) => {
            let body = '';
            res.on('data', (chunk) => body += chunk);
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    try {
                        resolve(JSON.parse(body));
                    } catch (e) {
                        resolve(body);
                    }
                } else {
                    reject(new Error(`Request failed: ${res.statusCode} ${body}`));
                }
            });
        });

        req.on('error', reject);

        if (data) {
            req.write(data);
        }
        req.end();
    });
}

async function main() {
    // 1. Load Config
    const envPath = path.resolve(__dirname, '../.env');
    if (!fs.existsSync(envPath)) {
        console.error('❌ .env file not found');
        process.exit(1);
    }
    const envContent = fs.readFileSync(envPath, 'utf8');
    const emailMatch = envContent.match(/POCKETBASE_SUPERUSER_EMAIL=(.*)/);
    const passMatch = envContent.match(/POCKETBASE_SUPERUSER_PASSWORD=(.*)/);

    const email = emailMatch ? emailMatch[1].trim() : '';
    const pass = passMatch ? passMatch[1].trim() : '';
    const pbUrl = 'http://127.0.0.1:8090';

    if (!email || !pass) {
        console.error('❌ Could not find credentials in .env');
        process.exit(1);
    }

    // 2. Auth
    console.log('🔐 Authenticating...');
    const authData = await request(`${pbUrl}/api/collections/_superusers/auth-with-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
    }, JSON.stringify({ identity: email, password: pass }));

    const token = authData.token;

    if (!token) {
        console.error('❌ Auth failed', authData);
        process.exit(1);
    }

    // 3. Read Personality
    const personalityPath = path.resolve(__dirname, '../backend/pb_data/seeds/poco-personality.txt');
    if (!fs.existsSync(personalityPath)) {
        console.error(`❌ Personality file not found at ${personalityPath}`);
        process.exit(1);
    }
    const personality = fs.readFileSync(personalityPath, 'utf8');
    console.log(`📖 Read personality (${personality.length} chars)`);

    // 4. Find Prompt Record
    // URL encode the filter
    const filter = encodeURIComponent("name='Poco Core'");
    const promptsData = await request(`${pbUrl}/api/collections/ai_prompts/records?filter=${filter}`, {
        headers: { 'Authorization': token }
    });

    const promptRecord = promptsData.items && promptsData.items[0];

    if (!promptRecord) {
        console.error('❌ "Poco Core" prompt not found!');
        process.exit(1);
    }

    // 5. Update Prompt
    console.log(`📝 Updating Prompt (${promptRecord.id})...`);
    await request(`${pbUrl}/api/collections/ai_prompts/records/${promptRecord.id}`, {
        method: 'PATCH',
        headers: {
            'Authorization': token,
            'Content-Type': 'application/json'
        }
    }, JSON.stringify({ body: personality }));

    // 6. Trigger Agent Update (Touch)
    const agentFilter = encodeURIComponent("name='poco'");
    const agentsData = await request(`${pbUrl}/api/collections/ai_agents/records?filter=${agentFilter}`, {
        headers: { 'Authorization': token }
    });
    const agentRecord = agentsData.items && agentsData.items[0];

    if (!agentRecord) {
        console.error('❌ "poco" agent not found!');
        process.exit(1);
    }

    console.log(`🔄 Touching Agent (${agentRecord.id}) to trigger assembly...`);
    await request(`${pbUrl}/api/collections/ai_agents/records/${agentRecord.id}`, {
        method: 'PATCH',
        headers: {
            'Authorization': token,
            'Content-Type': 'application/json'
        }
    }, JSON.stringify({ mode: 'primary' })); // No-op change effectively

    console.log('✅ Done.');
}

main().catch(console.error);
