# Animal Locket Flutter Agent Rules

## Scope

- Only implement the Flutter mobile client in `mobile/` unless the user explicitly expands the scope.
- Do not modify Java services, Python workers, infrastructure, deployment files, or backend behavior.
- Treat `docs/17-flutter-app-requirements.md` as the mobile product requirement and `docs/06-api-reference.md` as the API contract.
- If a requested UI behavior is unsupported by the API, follow the documented MVP decision and keep the limitation visible in code comments or feature flags instead of inventing an endpoint.

## Flutter requirements

- Target iOS and Android only with Dart 3 and null safety.
- Use feature-first organization under `lib/features/<feature>/{data,domain,presentation}`.
- Use Riverpod for state, Dio for HTTP, GoRouter for navigation, and ARB localization for user-facing text.
- Never send `X-Public-Id`; the gateway owns that header. Authenticated API calls use `Authorization: Bearer <JWT>`.
- Map RFC 7807 errors by stable `code`, never by `detail`.
- Never log tokens, signed media URLs, photos, locations, or chat content.
- Store credentials only through secure storage. All environment URLs and client identifiers come from `--dart-define`; do not commit secrets.
- Keep tap targets at least 44x44 logical pixels and add Vietnamese `Semantics` labels to icon-only controls.

## Quality gate

- Every completed feature includes loading, empty, error, and success states where applicable.
- Add or update unit/widget tests with each change.
- Before handoff, run `flutter analyze` and `flutter test` from `mobile/` when the SDK is available.
- Preserve backend and documentation files unless the user explicitly requests changes to them.
