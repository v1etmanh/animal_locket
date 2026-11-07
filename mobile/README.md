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

No secrets belong in the repository. The demo route can be opened from the sign-in screen without a backend.

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
