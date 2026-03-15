# PocketCoder — Consolidated Infrastructure Setup Guide

Everything you need to set up before shipping. Accounts, keys, deploys — in order.

**Prerequisite**: A Cloudflare account (free tier is fine for Workers + R2).

---

## Phase 1: Accounts & App Listings

These are the slow steps (identity verification, approvals). Start here.

### 1.1 Google Play Console

1. Go to [play.google.com/console](https://play.google.com/console/)
2. Create developer account → **$25 one-time fee**
3. Complete identity verification (1-3 days for orgs)
4. Create app → `PocketCoder`, Free, App
5. Fill minimum store listing:
   - Short description (80 chars): `Your sovereign AI coding assistant`
   - App icon (512x512), feature graphic (1024x500), 2+ screenshots
6. Complete **Content rating** questionnaire → `Utility`
7. Complete **App content** declarations (privacy policy URL, data safety, no ads)
8. Create subscription: **Monetize → Subscriptions → Create**
   - Product ID: `pocketcoder_pro_monthly`
   - Billing period: 1 month, price: $0.49
   - Activate the base plan
9. Note your **license key**: Setup → App signing → Monetization setup (Base64 RSA public key)

### 1.2 Apple Developer

1. Go to [developer.apple.com](https://developer.apple.com/) → Enroll → **$99/year**
2. If org: get D-U-N-S number first (free, ~5 business days)
3. Wait for enrollment approval (24-48h)

#### Register App ID
1. Certificates, Identifiers & Profiles → Identifiers → **+**
2. App IDs → App → Bundle ID: `org.pocketcoder.app`
3. Enable **Push Notifications** capability → Register

#### Create APNs Key
1. Keys → **+** → name: `PocketCoder Push`
2. Check **Apple Push Notifications service (APNs)** → Register
3. **Download the .p8 file** (one-time download!)
4. Note the **Key ID** and your **Team ID**

#### App Store Connect
1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com/) → My Apps → **+** → New App
2. iOS, name: `PocketCoder`, bundle: `org.pocketcoder.app`, SKU: `pocketcoder`
3. Create subscription group `PocketCoder Pro`:
   - Product ID: `pocketcoder_pro_monthly`, Duration: 1 month, price ≈ $0.49
4. Generate **App-Specific Shared Secret** (App Info → Manage)

### 1.3 F-Droid

F-Droid builds from the FOSS `pocketcoder_flutter` package (no Firebase, no RevenueCat).

#### Option A: Submit to official F-Droid repo
1. Fork [fdroiddata](https://gitlab.com/fdroid/fdroiddata)
2. Create `metadata/org.pocketcoder.app.yml`:
   ```yaml
   Categories:
     - Development
   License: AGPL-3.0-only
   SourceCode: https://github.com/qtpi-bonding-org/pocketcoder
   IssueTracker: https://github.com/qtpi-bonding-org/pocketcoder/issues

   AutoName: PocketCoder
   Description: |
     Sovereign AI coding assistant. Self-hosted on your own server.
     Control plane on your phone, execution on your hardware.

   RepoType: git
   Repo: https://github.com/qtpi-bonding-org/pocketcoder.git

   Builds:
     - versionName: '1.0.0'
       versionCode: 1
       commit: v1.0.0
       subdir: client/packages/pocketcoder_flutter
       output: build/app/outputs/flutter-apk/app-release.apk
       build:
         - cd ../..
         - flutter pub get
         - flutter build apk --flavor foss

   AutoUpdateMode: Version
   UpdateCheckMode: Tags
   CurrentVersion: '1.0.0'
   CurrentVersionCode: 1
   ```
3. Submit merge request to fdroiddata

#### Option B: Self-hosted F-Droid repo (faster, no review wait)
1. Build the FOSS APK: `flutter build apk` from `client/packages/pocketcoder_flutter`
2. Set up an [F-Droid repo](https://f-droid.org/docs/Setup_an_F-Droid_App_Repo/) on your server or GitHub Pages
3. Users add your repo URL in the F-Droid client

#### Key difference from Play Store build
- FOSS build uses `pocketcoder_flutter/lib/main.dart` (no Firebase, no RevenueCat)
- Pro build uses `apps/app/lib/main.dart` (FCM + RevenueCat + Linode deploy)
- Application ID stays `org.pocketcoder.app` for both (or use `org.pocketcoder.app.foss` for F-Droid if you want them installable side-by-side)

---

## Phase 2: Firebase

### 2.1 Create Firebase Project

1. Go to [console.firebase.google.com](https://console.firebase.google.com/)
2. Add project → `pocketcoder` → **disable** Google Analytics → Create

### 2.2 Register Apps

**Android:**
1. Add app → Android → package: `org.pocketcoder.app`
2. Download `google-services.json` → save to:
   ```
   client/apps/app/android/app/google-services.json
   ```

**iOS:**
1. Add app → iOS → bundle: `org.pocketcoder.app`
2. Download `GoogleService-Info.plist` → save to:
   ```
   client/apps/app/ios/Runner/GoogleService-Info.plist
   ```

### 2.3 Enable Cloud Messaging

1. Project settings → Cloud Messaging tab
2. Ensure **Firebase Cloud Messaging API (V1)** is **Enabled**

### 2.4 Upload APNs Key

1. Still in Cloud Messaging tab → Apple app configuration → Upload
2. Upload the `.p8` file, enter Key ID and Team ID

### 2.5 Generate Service Account Key

1. Project settings → Service accounts → **Generate new private key**
2. Download JSON file — you'll extract 3 values for the Cloudflare Worker:
   ```
   project_id    → already in wrangler.toml as FCM_PROJECT_ID
   client_email  → Worker secret: FCM_CLIENT_EMAIL
   private_key   → Worker secret: FCM_PRIVATE_KEY (base64-encode it)
   ```

Base64-encode the private key:
```bash
cat service-account.json | jq -r '.private_key' | base64 | tr -d '\n'
```

---

## Phase 3: RevenueCat

1. Go to [app.revenuecat.com](https://app.revenuecat.com/) → New Project → `PocketCoder`

### 3.1 Add Google Play App
- Package: `org.pocketcoder.app`
- Upload Google Play service account JSON (create in GCP console, grant access in Play Console → API access)
- Paste license key from Play Console

### 3.2 Add Apple App Store App
- Bundle: `org.pocketcoder.app`
- Paste App-Specific Shared Secret from App Store Connect

### 3.3 Configure Products
1. Entitlements → New → identifier: `premium`
2. Products → New:
   - Google: `pocketcoder_pro_monthly` → attach to `premium`
   - Apple: `pocketcoder_pro_monthly` → attach to `premium`
3. Offerings → default → add package `$rc_monthly` → attach both products

### 3.4 Note API Keys
- **Public** keys (for Flutter `.env`):
  - Apple: `REVENUE_CAT_APPLE_KEY=appl_xxxxx`
  - Google: `REVENUE_CAT_GOOGLE_KEY=goog_xxxxx`
- **Secret** key V2 (for CF Worker only): `REVENUECAT_SECRET_KEY`

---

## Phase 4: Supabase

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard) → New project
2. Name: `pocketcoder-usage`, Region: closest to server, Plan: **Free**
3. SQL Editor → New query → Run:

```sql
CREATE TABLE daily_usage (
  user_id TEXT PRIMARY KEY,
  push_count INTEGER DEFAULT 0,
  last_push_date DATE DEFAULT CURRENT_DATE
);

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

4. Note credentials from Settings → API:
   - `SUPABASE_URL` = project URL
   - `SUPABASE_SERVICE_KEY` = service_role key (NOT anon key)

---

## Phase 5: Cloudflare — Workers & R2

### 5.1 Create R2 Bucket

```bash
npx wrangler login
npx wrangler r2 bucket create pocketcoder-images
```

This bucket stores the NixOS image. Used by CI (upload) and the image relay worker (stream to Linode).

### 5.2 Deploy Push Notification Relay Worker

```bash
cd relay-worker
npm install

# Set 6 secrets (you'll paste each value when prompted)
npx wrangler secret put PN_RELAY_SECRET           # strong random string — shared with PocketBase
npx wrangler secret put REVENUECAT_SECRET_KEY     # RevenueCat V2 secret key
npx wrangler secret put FCM_CLIENT_EMAIL          # from Firebase service account JSON
npx wrangler secret put FCM_PRIVATE_KEY           # base64-encoded (see Phase 2.5)
npx wrangler secret put SUPABASE_URL              # from Supabase
npx wrangler secret put SUPABASE_SERVICE_KEY      # from Supabase

npx wrangler deploy
```

Note the deployed URL: `https://pocketcoder-relay.<account>.workers.dev`

### 5.3 Deploy Image Relay Worker

```bash
cd deploy/image-relay-worker
npm install
npx wrangler deploy
```

This worker has no secrets — it uses the R2 bucket binding from `wrangler.toml`.

### 5.4 Set GitHub Actions Secrets

Go to your GitHub repo → Settings → Secrets and variables → Actions → New repository secret:

| Secret | Value |
|--------|-------|
| `CLOUDFLARE_API_TOKEN` | API token with R2 + Pages permissions |
| `CLOUDFLARE_ACCOUNT_ID` | Your Cloudflare account ID |

---

## Phase 6: NixOS Image Pipeline

### 6.1 Trigger First Build

Go to GitHub → Actions → **Build NixOS Image** → Run workflow (manual dispatch)

This will:
1. Build the NixOS image via `nix build .#linode-image`
2. Compress to `.img.gz`
3. Upload to R2 bucket as `pocketcoder-nixos-latest.img.gz`

### 6.2 Verify Image Boots (one-time manual test)

1. Get a Linode API token (temporary, for testing)
2. Upload image manually or via the image relay worker:
   ```bash
   curl -X POST https://pocketcoder-image-relay.<account>.workers.dev/upload-image \
     -H "Authorization: Bearer <LINODE_TOKEN>" \
     -H "Content-Type: application/json" \
     -d '{"label": "pocketcoder-nixos", "description": "PocketCoder NixOS"}'
   ```
3. Create a Linode instance with that image
4. SSH in, verify bootstrap runs, Docker starts, Caddy gets TLS cert

---

## Phase 7: Flutter App Configuration

### 7.1 Android Package Name

Change `com.example.pocketcoder_app` → `org.pocketcoder.app` in:

```
client/apps/app/android/app/build.gradle.kts
```
- `namespace = "org.pocketcoder.app"`
- `applicationId = "org.pocketcoder.app"`

Also update:
- `AndroidManifest.xml` package reference
- Kotlin source directory: `com/example/pocketcoder_app/` → `org/pocketcoder/app/`

### 7.2 iOS Bundle ID

Verify `PRODUCT_BUNDLE_IDENTIFIER = org.pocketcoder.app` in:
```
client/apps/app/ios/Runner.xcodeproj/project.pbxproj
```

### 7.3 Firebase Config Files

```
client/apps/app/android/app/google-services.json     ← from Phase 2.2
client/apps/app/ios/Runner/GoogleService-Info.plist   ← from Phase 2.2
```

### 7.4 Environment Variables

Create `client/apps/app/.env`:
```bash
REVENUE_CAT_APPLE_KEY=appl_xxxxx
REVENUE_CAT_GOOGLE_KEY=goog_xxxxx
```

### 7.5 Release Signing (Android)

1. Generate upload keystore:
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA \
     -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `client/apps/app/android/key.properties`:
   ```
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```
3. Update `build.gradle.kts` to use the keystore for release builds
4. **Do NOT commit** the keystore or `key.properties`

### 7.6 Release Signing (iOS)

1. In Xcode: Signing & Capabilities → select your team
2. Or use Fastlane Match for CI signing

---

## Phase 8: Docker Compose (Server Side)

Update your server `.env`:

```bash
# Push notifications
PN_PROVIDER=FCM
PN_URL=https://pocketcoder-relay.<account>.workers.dev
PN_RELAY_SECRET=<same value as Worker secret>
```

---

## Phase 9: Deploy to Stores

### Google Play
```bash
cd client/apps/app
flutter build appbundle --release
```
Upload the `.aab` to Play Console → Production → Create new release.

### Apple App Store
```bash
cd client/apps/app
flutter build ipa --release
```
Upload via Transporter app or `xcrun altool` to App Store Connect → submit for review.

### F-Droid (FOSS build)
```bash
cd client/packages/pocketcoder_flutter
flutter build apk --release
```
Submit to fdroiddata repo (see Phase 1.3) or host in self-hosted repo.

---

## Master Checklist

### Accounts
- [ ] Google Play developer account ($25)
- [ ] Apple Developer Program ($99/year)
- [ ] Firebase project (`pocketcoder`)
- [ ] RevenueCat project (`PocketCoder`)
- [ ] Supabase project (`pocketcoder-usage`)
- [ ] Cloudflare account (free)

### App Store Listings
- [ ] Google Play: app listing, screenshots, content rating, data safety
- [ ] Apple: App Store Connect listing, screenshots, description
- [ ] F-Droid: metadata YAML submitted or self-hosted repo

### Subscriptions (push notifications — $0.49/month)
- [ ] Google Play: `pocketcoder_pro_monthly` subscription created + activated
- [ ] Apple: `pocketcoder_pro_monthly` subscription in group `PocketCoder Pro`
- [ ] RevenueCat: `premium` entitlement, products linked, default offering configured

### Deploy Button IAP ($4.99 / 24h)
- [ ] Google Play: in-app product for deploy button created
- [ ] Apple: in-app purchase for deploy button created
- [ ] RevenueCat: deploy entitlement + products configured

### Firebase
- [ ] Android app registered, `google-services.json` downloaded
- [ ] iOS app registered, `GoogleService-Info.plist` downloaded
- [ ] Cloud Messaging v1 enabled
- [ ] APNs key (.p8) uploaded with Key ID + Team ID
- [ ] Service account key generated, values extracted

### RevenueCat
- [ ] Google Play app with service credentials + license key
- [ ] Apple app with shared secret
- [ ] Public API keys noted for Flutter `.env`
- [ ] Secret API key noted for CF Worker

### Supabase
- [ ] `daily_usage` table + `increment_push()` function created
- [ ] Project URL + service_role key noted

### Cloudflare
- [ ] R2 bucket `pocketcoder-images` created
- [ ] Push relay worker deployed with 6 secrets
- [ ] Image relay worker deployed
- [ ] GitHub secrets set (`CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`)

### NixOS Image Pipeline
- [ ] First CI build triggered (workflow_dispatch)
- [ ] Image uploaded to R2
- [ ] Image boots on Linode (manual verification)
- [ ] Image relay worker streams to Linode (curl test)

### Flutter App
- [ ] Android package name: `org.pocketcoder.app`
- [ ] iOS bundle ID: `org.pocketcoder.app`
- [ ] `google-services.json` in place
- [ ] `GoogleService-Info.plist` in place
- [ ] `.env` with RevenueCat keys
- [ ] Android release signing configured
- [ ] iOS release signing configured

### Server
- [ ] `PN_PROVIDER`, `PN_URL`, `PN_RELAY_SECRET` in docker-compose `.env`

---

## Cost Summary

| Service | Cost | Notes |
|---------|------|-------|
| Google Play | $25 one-time | Developer account |
| Apple Developer | $99/year | Required for App Store + APNs |
| Firebase | Free | FCM has no per-message cost |
| RevenueCat | Free | Free tier: <$2.5k MTR |
| Supabase | Free | 1 table, minimal usage |
| Cloudflare Workers | Free | Free tier: 100k req/day |
| Cloudflare R2 | Free | Free tier: 10GB storage |
| **Total** | **$124 first year** | **$99/year after** |

## Revenue

| Stream | Price | Type |
|--------|-------|------|
| Push notifications | $0.49/month | Subscription |
| Deploy button | $4.99 | One-time (24h unlock) |
| Linode referral | $100 credit per signup | Referral bonus |
| Elestio | Revenue share | TBD with Elestio |
