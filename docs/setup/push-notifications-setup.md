# Push Notifications & App Store Setup Guide

All the clicky dashboard stuff in one place: Google Play, Apple Developer, Firebase, RevenueCat, Supabase, Cloudflare.

**Time estimate**: ~1-2 hours of clicking around dashboards

---

## 1. Google Play Console

Go to [play.google.com/console](https://play.google.com/console/)

### Create Developer Account (if you don't have one)

1. Sign in with your Google account
2. Click **"Create developer account"**
3. Pay the **$25 one-time fee**
4. Fill in developer name: `Qtpi Bonding LLC` (or your entity)
5. Complete identity verification (takes 1-3 days for organizations)

### Create App Listing

1. Click **"Create app"**
2. App name: `PocketCoder`
3. Default language: English
4. App or Game: **App**
5. Free or Paid: **Free** (subscriptions are in-app purchases)
6. Accept declarations → **Create app**

### Store Listing (minimum to proceed)

1. Go to **Main store listing** in the left sidebar
2. Fill in:
   - Short description (up to 80 chars): `Your sovereign AI coding assistant`
   - Full description (up to 4000 chars): describe PocketCoder
3. Upload graphics:
   - App icon: 512x512 PNG
   - Feature graphic: 1024x500 PNG
   - Phone screenshots: at least 2, between 320px-3840px on each side
4. Click **Save**

### Content Rating

1. Go to **Content rating** in the left sidebar
2. Click **Start questionnaire**
3. Category: **Utility** → answer the questions (no violence, no gambling, etc.)
4. Submit → you'll get an **Everyone** or similar rating

### App Content

1. Go to **App content** in the left sidebar
2. Fill in required declarations:
   - **Privacy policy**: add your URL (required for apps with accounts)
   - **Ads**: declare "No ads"
   - **App access**: if the app requires login, provide test credentials
   - **Data safety**: declare what data you collect (account info, device tokens)
   - **Government apps**: No
   - **Financial features**: No (subscriptions are handled by Play, not custom payment)

### Create Subscription Product

1. Go to **Monetize** → **Subscriptions** in the left sidebar
2. Click **"Create subscription"**
3. Product ID: `pocketcoder_pro_monthly`
4. Name: `PocketCoder Pro`
5. Add a **base plan**:
   - Billing period: **1 month**
   - Price: set your price (e.g., $0.49)
   - Auto-renewing
6. **Activate** the base plan

### Upload Signing Key (for later)

1. Go to **Setup** → **App signing** in the left sidebar
2. Choose **"Let Google manage and protect your app signing key"** (recommended)
3. You'll upload your AAB (Android App Bundle) later when the Flutter build is ready

### Connect RevenueCat (do after RevenueCat setup in section 4)

1. Go to **Monetize** → **Monetization setup**
2. Copy your **license key** (Base64-encoded RSA public key)
3. You'll paste this into RevenueCat's Google Play app settings

---

## 2. Apple Developer

Go to [developer.apple.com](https://developer.apple.com/)

### Enroll in Apple Developer Program (if you haven't)

1. Click **"Account"** → sign in with your Apple ID
2. Click **"Enroll"** in the Apple Developer Program
3. **$99/year** fee
4. For organizations: need a D-U-N-S number (free to get, takes ~5 business days)
5. Complete enrollment → wait for approval (usually 24-48 hours)

### Register App ID

1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. Click **"Certificates, Identifiers & Profiles"**
3. Click **"Identifiers"** → **"+"** button
4. Select **"App IDs"** → Continue
5. Select **"App"** → Continue
6. Description: `PocketCoder`
7. Bundle ID: **Explicit** → `org.pocketcoder.app`
8. Under Capabilities, check:
   - **Push Notifications** (required for FCM/APNs)
9. Click **Register**

### Create Push Notification Key (APNs Key)

1. Go to **"Keys"** → **"+"** button
2. Key Name: `PocketCoder Push`
3. Check **"Apple Push Notifications service (APNs)"**
4. Click **Continue** → **Register**
5. **Download the .p8 key file** — you can only download it ONCE
6. Note the **Key ID** (shown on the page)
7. Note your **Team ID** (shown in top-right of the developer portal, or Membership page)

You'll need these for Firebase (so Firebase can send APNs on your behalf):
- The `.p8` file
- Key ID
- Team ID

### Create App in App Store Connect

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com/)
2. Click **"My Apps"** → **"+"** → **"New App"**
3. Platforms: **iOS**
4. Name: `PocketCoder`
5. Primary language: English
6. Bundle ID: select `org.pocketcoder.app` (from the ID you just registered)
7. SKU: `pocketcoder` (internal identifier, anything unique)
8. User Access: Full Access
9. Click **Create**

### Create Subscription in App Store Connect

1. In your app, go to **Subscriptions** in the left sidebar (under "Features" or "In-App Purchases")
2. Click **"+"** to create a **Subscription Group**
3. Group name: `PocketCoder Pro`
4. Click **Create**
5. Inside the group, click **"+"** to create a subscription:
   - Reference Name: `Pro Monthly`
   - Product ID: `pocketcoder_pro_monthly` (match Google Play for simplicity)
6. Set up pricing:
   - Subscription Duration: **1 Month**
   - Price: select your price tier (closest to $0.49)
7. Add at least one **Localization**:
   - Display Name: `PocketCoder Pro`
   - Description: `Unlock push notifications and premium features`
8. **Save**

### Upload APNs Key to Firebase

1. Go back to **Firebase Console** → Project Settings → **Cloud Messaging** tab
2. Under **Apple app configuration**, click **Upload** next to "APNs Authentication Key"
3. Upload the `.p8` file from earlier
4. Enter the **Key ID** and **Team ID**
5. Click **Upload**

---

## 3. Firebase Console

Go to [console.firebase.google.com](https://console.firebase.google.com/)

### Create Project

1. Click **"Add project"**
2. Project name: `pocketcoder`
3. **Disable** Google Analytics (not needed for push notifications)
4. Click **Create project** → wait for it to provision

### Register Android App

1. In the project dashboard, click the **Android icon** (Add app)
2. Android package name: `org.pocketcoder.app`
3. App nickname: `PocketCoder`
4. Skip the SHA-1 for now (can add later for production)
5. Click **Register app**
6. **Download `google-services.json`** → save to `client/apps/app/android/app/google-services.json`
7. Skip the remaining steps in the wizard (SDK is already in Flutter)

### Register iOS App

1. Click **Add app** → iOS icon
2. Bundle ID: `org.pocketcoder.app`
3. App nickname: `PocketCoder iOS`
4. Skip App Store ID for now
5. **Download `GoogleService-Info.plist`** → save to `client/apps/app/ios/Runner/GoogleService-Info.plist`

### Enable Cloud Messaging v1

1. Click the **gear icon** → **Project settings**
2. Go to **Cloud Messaging** tab
3. Under "Firebase Cloud Messaging API (V1)", make sure it says **Enabled**
   - If it says "Disabled", click the three-dot menu → **Enable**

### Upload APNs Key (if you did the Apple section above)

1. Still in **Cloud Messaging** tab
2. Under **Apple app configuration**, click **Upload**
3. Upload the `.p8` file, enter Key ID and Team ID

### Generate Service Account Key

1. Still in **Project settings**, go to **Service accounts** tab
2. Click **"Generate new private key"**
3. Confirm → a JSON file downloads
4. **Keep this file safe** — it contains the private key for the Cloudflare Worker

From this JSON file, you'll need these three values later:
```
"project_id": "pocketcoder"           ← for wrangler.toml
"client_email": "firebase-adminsdk-xxxxx@pocketcoder.iam.gserviceaccount.com"  ← Worker secret
"private_key": "-----BEGIN RSA PRIVATE KEY-----\n..."  ← Worker secret (base64 encode it)
```

---

## 4. RevenueCat Dashboard

Go to [app.revenuecat.com](https://app.revenuecat.com/)

### Create Project

1. Click **"+ New"** → **Project**
2. Name: `PocketCoder`

### Add Google Play App

1. In the project, click **"+ New"** → **App**
2. Platform: **Google Play**
3. App name: `PocketCoder Android`
4. Package name: `org.pocketcoder.app`
5. **Service credentials**: you'll need a Google Play service account JSON
   - In Google Cloud Console: create a service account with "Service Account User" role
   - In Google Play Console: go to **Setup** → **API access** → grant the service account access
   - Download the JSON key and upload it here
   - (RevenueCat docs walk through this: [RevenueCat Google Play setup](https://www.revenuecat.com/docs/getting-started/creating-a-project#google-play-store))
6. Paste the **license key** from Google Play Console (Monetize → Monetization setup)

### Add Apple App Store App

1. Click **"+ New"** → **App**
2. Platform: **App Store**
3. App name: `PocketCoder iOS`
4. Bundle ID: `org.pocketcoder.app`
5. **Shared secret**: get from App Store Connect → your app → General → App Information → "App-Specific Shared Secret" → **Manage** → **Generate**
6. Paste the shared secret into RevenueCat

### Create Entitlement

1. Go to **Entitlements** in the left sidebar
2. Click **"+ New"**
3. Identifier: `premium`
4. Display name: `Premium`

### Create Products

1. Go to **Products** in the left sidebar
2. Click **"+ New"**
3. For Google Play:
   - App: PocketCoder Android
   - Product ID: `pocketcoder_pro_monthly` (must match what you created in Play Console)
4. Click **"+ New"** again for Apple:
   - App: PocketCoder iOS
   - Product ID: `pocketcoder_pro_monthly` (must match App Store Connect)
5. Attach both products to the `premium` entitlement

### Create Offering

1. Go to **Offerings** in the left sidebar
2. The **default** offering should already exist
3. Add a **Package** to the default offering:
   - Identifier: `$rc_monthly` (RevenueCat's standard monthly identifier)
   - Attach your Google Play product
   - Attach your Apple product
4. **Save**

### Note Your API Keys

1. Go to **API Keys** in the left sidebar
2. Copy the **Public app-specific API keys**:
   - Google Play key → this is your `REVENUE_CAT_GOOGLE_KEY`
   - Apple App Store key → this is your `REVENUE_CAT_APPLE_KEY`
3. Copy the **Secret API key** (V2) → this is your `REVENUECAT_SECRET_KEY` for the Worker
   - **Never put this in client code** — it goes in Cloudflare Worker secrets only

---

## 5. Supabase

Go to [supabase.com/dashboard](https://supabase.com/dashboard)

### Create Project

1. Click **"New project"**
2. Name: `pocketcoder-usage`
3. Database password: generate a strong one (save it somewhere)
4. Region: choose the closest to your server (e.g., East US)
5. Plan: **Free** (more than enough — we're storing 1 row per user)

### Create Table & Function

1. Go to **SQL Editor** in the left sidebar
2. Click **"New query"**
3. Paste this and click **Run**:

```sql
-- The one tiny table for rate limiting
CREATE TABLE daily_usage (
  user_id TEXT PRIMARY KEY,
  push_count INTEGER DEFAULT 0,
  last_push_date DATE DEFAULT CURRENT_DATE
);

-- Atomic increment-and-check function
-- Resets count to 1 if it's a new day, otherwise increments
CREATE OR REPLACE FUNCTION increment_push(p_user_id TEXT, p_limit INTEGER DEFAULT 1000)
RETURNS INTEGER AS $$
DECLARE
  current_count INTEGER;
BEGIN
  INSERT INTO daily_usage (user_id, push_count, last_push_date)
  VALUES (p_user_id, 1, CURRENT_DATE)
  ON CONFLICT (user_id) DO UPDATE SET
    push_count = CASE
      WHEN daily_usage.last_push_date < CURRENT_DATE THEN 1
      ELSE daily_usage.push_count + 1
    END,
    last_push_date = CURRENT_DATE
  RETURNING push_count INTO current_count;

  RETURN current_count;
END;
$$ LANGUAGE plpgsql;
```

4. You should see "Success" — that's it for the database

### Note Your Credentials

1. Go to **Settings** → **API** in the left sidebar
2. Copy:
   - **Project URL**: `https://xxxxx.supabase.co` → this is your `SUPABASE_URL`
   - **service_role key** (under "Project API keys"): → this is your `SUPABASE_SERVICE_KEY`
   - Use the `service_role` key, NOT the `anon` key (service_role bypasses RLS)

---

## 6. Cloudflare Worker Deploy

```bash
cd relay-worker
npm install
npx wrangler login                               # authenticate with Cloudflare

# Set all secrets (you'll be prompted to paste each value)
npx wrangler secret put PN_RELAY_SECRET           # make up a strong random string
npx wrangler secret put REVENUECAT_SECRET_KEY     # from RevenueCat → API Keys → Secret
npx wrangler secret put FCM_CLIENT_EMAIL          # from Firebase service account JSON
npx wrangler secret put FCM_PRIVATE_KEY           # see below for how to encode
npx wrangler secret put SUPABASE_URL              # from Supabase → Settings → API
npx wrangler secret put SUPABASE_SERVICE_KEY      # from Supabase → Settings → API

# Deploy
npx wrangler deploy
```

### Encoding the FCM Private Key

The Firebase service account JSON has a `private_key` field with `\n` escaped newlines. Base64-encode it:

```bash
cat your-service-account.json | jq -r '.private_key' | base64 | tr -d '\n'
```

Paste the output when prompted for `FCM_PRIVATE_KEY`.

The deployed URL (e.g. `https://pocketcoder-relay.<account>.workers.dev`) goes into your docker-compose config.

---

## 7. Docker Compose Configuration

Update your `.env` or `docker-compose.yml`:

```bash
PN_PROVIDER=FCM
PN_URL=https://pocketcoder-relay.<your-account>.workers.dev
PN_RELAY_SECRET=<same value you set as the Worker secret>
```

---

## 8. Flutter Configuration

### Config Files

- Place `google-services.json` at: `client/apps/app/android/app/google-services.json`
- Place `GoogleService-Info.plist` at: `client/apps/app/ios/Runner/GoogleService-Info.plist`

### RevenueCat Keys

Add to `client/apps/app/.env`:
```
REVENUE_CAT_APPLE_KEY=appl_xxxxx
REVENUE_CAT_GOOGLE_KEY=goog_xxxxx
```

### Package Name (Android)

Change `com.example.pocketcoder_app` → `org.pocketcoder.app` in:
- `client/apps/app/android/app/build.gradle.kts` (namespace + applicationId)
- `client/apps/app/android/app/src/main/AndroidManifest.xml`
- Kotlin source directory structure (`com/example/pocketcoder_app/` → `org/pocketcoder/app/`)

### Bundle ID (iOS)

Should already be `org.pocketcoder.app` if set correctly in Xcode. Verify in:
- `client/apps/app/ios/Runner.xcodeproj/project.pbxproj` (PRODUCT_BUNDLE_IDENTIFIER)

---

## 9. Verification Checklist

### Google Play
- [ ] Developer account created and verified
- [ ] App listing created with name, description, screenshots
- [ ] Content rating questionnaire completed
- [ ] Subscription product `pocketcoder_pro_monthly` created and activated
- [ ] License key copied for RevenueCat

### Apple
- [ ] Apple Developer Program enrollment complete
- [ ] App ID registered with Push Notifications capability
- [ ] APNs key (.p8) downloaded, Key ID and Team ID noted
- [ ] App created in App Store Connect
- [ ] Subscription `pocketcoder_pro_monthly` created in subscription group
- [ ] App-Specific Shared Secret generated for RevenueCat

### Firebase
- [ ] Project created
- [ ] Android app registered, `google-services.json` downloaded
- [ ] iOS app registered, `GoogleService-Info.plist` downloaded
- [ ] Cloud Messaging v1 enabled
- [ ] APNs key uploaded (Apple .p8 file)
- [ ] Service account key generated, values extracted

### RevenueCat
- [ ] Project created
- [ ] Google Play app added with service credentials + license key
- [ ] Apple App Store app added with shared secret
- [ ] `premium` entitlement created
- [ ] Products created and attached to entitlement
- [ ] Default offering with monthly package configured
- [ ] API keys noted (public for Flutter, secret for Worker)

### Supabase
- [ ] Project created
- [ ] `daily_usage` table + `increment_push` function created
- [ ] Project URL and service_role key noted

### Cloudflare Worker
- [ ] All 6 secrets set
- [ ] Worker deployed
- [ ] Worker URL noted

### Docker Compose
- [ ] `PN_PROVIDER=FCM` set
- [ ] `PN_URL` set to Worker URL
- [ ] `PN_RELAY_SECRET` matches Worker secret

### Flutter
- [ ] `google-services.json` placed in Android app
- [ ] `GoogleService-Info.plist` placed in iOS app
- [ ] RevenueCat keys in `.env`
- [ ] Package name `org.pocketcoder.app`
- [ ] Bundle ID `org.pocketcoder.app`

---

## Architecture Recap

```
Pro App User (FCM)                    FOSS User (UnifiedPush)
       │                                       │
   Firebase                                    │
   gets token                                  │
       │                                       │
   registers device                    registers device
   in PocketBase                       in PocketBase
   (push_service=fcm)                 (push_service=unifiedpush)
       │                                       │
       │      ┌─── permission created ───┐     │
       │      │    (user is offline)     │     │
       │      └──────────┬───────────────┘     │
       │                 │                     │
       │        ┌────────┴────────┐            │
       │        │  notifications  │            │
       │        │     .go         │            │
       │        └───┬────────┬────┘            │
       │            │        │                 │
       ▼            │        │                 ▼
  Cloudflare        │        └──────► ntfy endpoint
  Worker            │                  (direct POST)
       │            │
  ┌────┴────┐       │
  │ RevCat  │       │
  │ check   │       │
  └────┬────┘       │
  ┌────┴────┐       │
  │Supabase │       │
  │ quota   │       │
  └────┬────┘       │
  ┌────┴────┐       │
  │  FCM    │       │
  │  v1 API │       │
  └────┬────┘       │
       │            │
       ▼            │
  Google delivers   │
  to device         │
```

**Cost: $0/month (after $25 Google + $99/year Apple). Revenue: $0.49/user/month.**
