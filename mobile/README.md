# Animal Locket Mobile

Flutter client for iOS and Android based on `../docs/17-flutter-app-requirements.md` and the API contract in `../docs/06-api-reference.md`.

## Run

```powershell
D:\fluttersdk\flutter\bin\flutter.bat run `
  --dart-define=API_BASE_URL=https://your-gateway.example `
  --dart-define=WS_URL=wss://your-gateway.example/ws/chat `
  --dart-define=KEYCLOAK_ISSUER=https://identity.example/realms/animal-locket `
  --dart-define=KEYCLOAK_CLIENT_ID=animal-locket-mobile
```

Shortcut for the shared demo server (real data, values in `env/demo-server.json`; extra `flutter run` arguments pass through):

```powershell
.\run-demo.cmd            # or: .\run-demo.cmd -d chrome
```

No secrets belong in the repository. The demo route can be opened from the sign-in screen without a backend.

## Push notifications

Push is disabled unless the build supplies `ENABLE_PUSH=true`. Supply Firebase
client settings from the **same project as the server's service account** using
`--dart-define` (or an ignored local `--dart-define-from-file` JSON file):

```text
ENABLE_PUSH=true
FIREBASE_API_KEY=<Firebase client API key>
FIREBASE_PROJECT_ID=<Firebase project id>
FIREBASE_MESSAGING_SENDER_ID=<Firebase project number>
FIREBASE_ANDROID_APP_ID=<Android Firebase app id>
FIREBASE_IOS_APP_ID=<iOS Firebase app id, when building iOS>
FIREBASE_IOS_BUNDLE_ID=com.animallocket.app
```

These are client settings, **never the service-account private key**. Firebase is
initialized explicitly from these values; no generated Firebase options file is
required. Register `com.animallocket.app` in Firebase for each target platform.
For iOS, enable Push Notifications for the Apple App ID, regenerate provisioning
profiles, and upload its APNs authentication key to Firebase. Debug uses the
development APNs entitlement; Release/Profile use production.

For the configured demo Android build, use the ignored local file
`config/demo.local.json` (contains client configuration only):

```powershell
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/demo.local.json
```

Install `build/app/outputs/flutter-apk/app-debug.apk` on Android, sign in, grant
notification permission, and check the registration status in Settings. The local
configuration file is not committed; each developer must supply their own copy.

Device registration (`PUT /devices`) runs only after live login and profile
creation. Settings shows disabled/loading/denied/error/registered status and
offers a retry. Returning to the app retries registration. This status confirms
device registration, not successful delivery by the server. Foreground Android
messages show a generic in-app banner; iOS also enables native presentation.
Tapping a message opens its chat or friends page; post notifications open the
feed because the MVP has no standalone post route.

Server prerequisite: put a Firebase Admin service-account JSON in the shared
`/opt/animal-locket/deploy/secrets/` directory and set
`FCM_CREDENTIALS_FILE=/secrets/<filename>.json` in the server's `.env`. The CD
overlay already mounts this shared directory. Without the variable, the backend
deliberately uses `LoggingPushSender` and **does not send notifications**. Never
copy a service-account key into this app or commit it.

The runtime container uses UID/GID `10001` (`app`). Keep the directory owned by
`root:10001` with mode `710`, and the key owned by `root:10001` with mode `640`:

```bash
chown root:10001 /opt/animal-locket/deploy/secrets /opt/animal-locket/deploy/secrets/fcm.json
chmod 710 /opt/animal-locket/deploy/secrets
chmod 640 /opt/animal-locket/deploy/secrets/fcm.json
```

A root-owned key with mode `600` is unreadable by the app and prevents Firebase
initialization. Never make the key world-readable or run the container as root.

Read-only server check (no tokens, keys or chat content printed):

```bash
docker exec animal-locket-notification-service-1 sh -c '
  if [ -z "$FCM_CREDENTIALS_FILE" ]; then
    echo "Push simulated: FCM_CREDENTIALS_FILE is empty"; exit 1
  elif [ ! -r "$FCM_CREDENTIALS_FILE" ]; then
    echo "FCM credentials file is not readable"; exit 1
  else
    echo "FCM credentials file is present (delivery still needs a device test)"
  fi'
```

After setting credentials, recreate only `notification-service` with the three
Compose files in the **current release**, the shared `.env`, correct `DEPLOY_TAG`
and project name `animal-locket`; a plain `docker restart` does not reload `.env`.
Use the existing deployment runbook for the exact `dc` helper.

Verify on two physical devices/accounts: grant notification permission, log in,
check Settings registration, then send a friend request/message or publish a post.
Check foreground, background, terminated app, tap navigation, denied permission,
retry after a failed request, logout and login as another account. Never print
device tokens or message payloads in diagnostics.

## Implemented foundation

- Vietnamese UI with ARB localization generation.
- Four-tab GoRouter shell and routes for S01-S13.
- Shared glass, gradient button, animal avatar, typography, and color system.
- Dio API client that strips `X-Public-Id`, adds bearer tokens from secure storage, and supports one auth refresh attempt.
- Central RFC 7807 `code` to Vietnamese-message mapping.
- Interactive demo states for onboarding, camera/preview, feed likes, discovery swipes, friends, chat, profile, Pro, settings, and public profiles.
- Unit and widget smoke tests.

## Integration boundary

The screens currently use deterministic demo data so development does not depend on unverified infrastructure. Production integration still needs Keycloak realm details, Firebase files, App Store/Play SKUs, real animal PNGs, and the backend or the required mock server fixtures. Camera, push, location, purchases, media multipart upload, polling, and WebSocket reconnect must be connected after those inputs are supplied.

## Quality commands

```powershell
D:\fluttersdk\flutter\bin\flutter.bat analyze
D:\fluttersdk\flutter\bin\flutter.bat test
```
