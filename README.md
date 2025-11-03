# RecoverX — Cloud Build Pack (Upload to Codemagic or GitHub)

This package lets you generate an **APK** without installing any dev tools locally.

## Option A — Codemagic (recommended)
1. Zip this folder as `recoverx_pack.zip` (if not already zipped).
2. Go to https://codemagic.io/start/ and create a free account.
3. Create a new app from **"App from custom sources" → Upload Zip"** (or connect GitHub).
4. Keep the default repository settings. Codemagic will detect **codemagic.yaml** automatically.
5. Run the workflow. When it finishes, download **app-release.apk** from build artifacts.

## Option B — GitHub Actions
1. Create a new GitHub repo and upload the *contents* of this folder.
2. Go to the **Actions** tab → enable workflows → run "Build RecoverX APK".
3. Download the artifact **recoverx-apk** (contains `app-release.apk`).

---

## What this does
- The pipeline runs `flutter create .` to scaffold a full Flutter project during the build.
- It copies the custom **RecoverX** files into the scaffold (Dart & Kotlin).
- It adds required dependencies and permissions.
- It builds a **release APK** as an artifact.

After download, copy the APK to your phone and install (enable *Install unknown apps*).
