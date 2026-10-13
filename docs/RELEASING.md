# Native builds and Android releases

CI uses Flutter **3.47.7** and Temurin **JDK 17**. Every push and pull request runs
the app, core and visualization checks plus two independent native builds:

- Android: `flutter build apk --debug`. Download the ZIP named
  `neural-idle-debug-apk` under **Actions → CI → run → Artifacts**. It contains
  `app-debug.apk`; this is a debug build, not a production release.
- iOS: `flutter build ios --release --no-codesign` on macOS. This verifies the
  native project compiles; it does not produce an installable signed IPA or
  publish to the App Store. Distribution signing requires your Apple setup.

The Android CI job also creates a disposable test keystore and verifies the
release signing certificate through Gradle for both environment variables and
`android/key.properties`, plus the debug fallback. No production key is needed
for CI and the disposable keystore is not uploaded.

## 1. Create the production Android keystore

Use JDK 17's `keytool`. Keep the keystore outside the repository. On Windows,
run this in PowerShell:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.android" | Out-Null
keytool -genkeypair -v -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload -keystore "$env:USERPROFILE\.android\neural-idle-upload.jks"
```

On macOS/Linux:

```bash
mkdir -p "$HOME/.android"
keytool -genkeypair -v -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload -keystore "$HOME/.android/neural-idle-upload.jks"
```

Record the store password, alias and key password. Pressing Enter at the key
password prompt uses the store password. Back up the keystore and credentials:
updates to a directly distributed APK must use the same signing certificate.
Never commit the keystore, passwords or base64 text. Base64 is encoding, not
encryption. `android/key.properties`, `*.jks` and `*.keystore` are already ignored
inside `android/`.

## 2. Configure repository secrets

Open **Settings → Secrets and variables → Actions → New repository secret** in
`matiasstr/IDLE-game`. Add all four secrets:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64 of the complete binary keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Store password entered in keytool |
| `ANDROID_KEY_ALIAS` | `upload`, or the alias you chose |
| `ANDROID_KEY_PASSWORD` | Key password, possibly the same as the store password |

Copy the base64 value to your clipboard in PowerShell:

```powershell
Set-Clipboard -Value ([Convert]::ToBase64String([IO.File]::ReadAllBytes(
  "$env:USERPROFILE\.android\neural-idle-upload.jks"
)))
```

On Linux, `base64 -w 0 "$HOME/.android/neural-idle-upload.jks"`; on macOS,
`base64 -i "$HOME/.android/neural-idle-upload.jks" | tr -d '\n'`. Paste the
result into the base64 repository secret, not a committed file or an issue.

Gradle decodes the CI key under `RUNNER_TEMP/neural-idle-signing/` and the release
workflow removes it in an always-run cleanup step. If you use these environment
variables locally without RUNNER_TEMP, the decoded key goes under the ignored
`android/.gradle/neural-idle-signing/` directory.

## 3. Optional local signed build

Create `android/key.properties` locally with these four entries:

```properties
storeFile=C:/Users/YOUR_USER/.android/neural-idle-upload.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=upload
keyPassword=YOUR_KEY_PASSWORD
```

Use forward slashes for Windows paths. Absolute paths work on all platforms;
relative paths resolve from `android/`. Java properties escapes apply to
passwords containing backslashes or control characters.

From the repository root:

```bash
flutter pub get
flutter build apk --release
flutter build appbundle --release
```

Environment signing takes precedence when any of the four environment variables
is set; all four must then be present. Otherwise Gradle reads key.properties.
An incomplete configuration or missing keystore fails clearly. If neither source
exists, release-mode local runs use the debug key, preserving
`flutter run --release`. Such a build is for local testing only.

## 4. Cut a release when ready

First merge the release workflow into main, configure the secrets, and confirm
the commit you intend to release has green CI. The workflow reads the app
version and build number from `pubspec.yaml`, without overriding or bumping
them. The current version is `1.0.0+1`. A Git tag does not change that app version;
before a future release, update pubspec through your normal development process.

Only the user should run the following commands to cut the first release:

```bash
git switch main
git pull --ff-only origin main
git tag -a v1.0.0 -m "Neural Idle 1.0.0"
git push origin v1.0.0
```

Every pushed `v*` tag triggers **Android release**. It validates all four secrets
before building, creates a signed APK and AAB, then creates a GitHub Release with
both attached and generated release notes. Missing secrets stop the workflow
with their names and instructions; a published release never falls back to debug
signing. Tag pushes also trigger ordinary CI.

Find the downloads at **GitHub → Releases → tag**:

- `app-release.apk`: directly installable Android release.
- `app-release.aab`: Android App Bundle, for a distribution service when needed.

Local build outputs are `build/app/outputs/flutter-apk/app-release.apk` and
`build/app/outputs/bundle/release/app-release.aab`. Follow the **Android release**
run in Actions for build or signing errors. The workflow verifies the tag already
exists and does not create or push tags. If publication alone failed after a
release was created, inspect the existing release before rerunning; the create
step intentionally does not overwrite an existing release.

## Pages only deploys a green main

Pages waits for **CI** to complete successfully on a push to main, checks out
that exact `head_sha`, and builds with `--base-href /IDLE-game/`. Before building
and publishing it checks that the commit is still current main and its latest
push CI run is green. Failed, cancelled or pending CI cannot publish, and a stale
build cannot replace a newer main.

**Run workflow** remains available for Pages: select **main**, after its exact
commit has green push CI. Manual runs follow the same gate. In **Settings → Pages**,
keep **Source: GitHub Actions**. The workflow_run trigger takes effect after this
workflow is merged into the default branch. This change does not configure Play
Store distribution or create any Google Play assets.

References: [Flutter Android signing](https://docs.flutter.dev/deployment/android#sign-the-app),
[GitHub workflow_run](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run),
[GitHub CLI release creation](https://cli.github.com/manual/gh_release_create).
