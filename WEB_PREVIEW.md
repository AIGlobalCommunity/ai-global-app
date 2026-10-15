# AGC Safari preview

This repo supports Flutter Web as well as Android/iOS.

## Build

```sh
flutter create --platforms=web .
flutter pub get
flutter test
flutter build web --release
```

GitHub Actions workflow **AGC Safari Web Preview** publishes an artifact named `agc-safari-web` containing the compiled static site. This is *not* a hosted URL. Download artifact and deploy to a static host (e.g. Vercel). To configure OAuth/email confirmation redirects, set the final deployed domain under Supabase Authentication > URL Configuration.

## Privacy

The Supabase URL and **publishable** key are safe to embed in a browser. Never use the service-role secret in Flutter source or browser deployment.

Demo ranking is visibly labeled DEMO and remains separate from actual members. Registration is not ready for public launch pending abuse prevention and end-to-end email confirmation testing. Avoid publishing the preview URL broadly until those protections are implemented.

We keep the source repository private. Publishing it publicly is NOT necessary with an external hosting provider.
