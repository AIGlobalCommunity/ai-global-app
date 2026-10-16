# AI Global Community

Social platform in Flutter (Android, iOS and web), connected to the live Supabase project.

## Features

- Public home feed, community editorial discussion starters, member posts, comments and likes.
- Public/private groups, membership, invitation and acceptance.
- Group and member search, editable profiles, personal post history.
- Photos and HTTPS links; public posts share through a server-rendered Open Graph preview with image.
- Authenticated AI chat with conversation history and a welcome message for new users.
- Data access protected by Supabase Row Level Security.

## Run

Install Flutter, then run:

```sh
flutter create --project-name ai_global_community --platforms=android,ios,web .
flutter pub get
flutter run -d chrome
```

The Flutter app uses the public Supabase publishable key; no secret is embedded in client code. The backend AI function `agc-ai-chat` is deployed. **To activate live model replies**, configure `OPENAI_API_KEY` in Supabase Edge Function secrets. Optionally configure `OPENAI_MODEL` (default: `gpt-4.1-mini`). Without the key, the chat displays an explicit service-unavailable error; it never fabricates AI answers.

## Social sharing

Public posts share through `https://gjnddmurmegbklvedhnp.supabase.co/functions/v1/genesis-share?id=<post-id>`. This endpoint emits Open Graph and X/Twitter image metadata for compatible sharing platforms. Some platforms choose their own preview behavior.

## Deployment

GitHub Actions builds the Flutter web app and deploys it to GitHub Pages (repository Settings → Pages → Source: GitHub Actions). Mobile builds require normal platform signing/configuration. The app does not create fake accounts or pass synthetic posts off as member conversations. Editorial discussion starters are attributed to the AGC team.

## Security

Never add service-role keys or OpenAI keys to Flutter source. Private-group content is only available to authorized members. Public images are for public posts only. For production, finish moderation, privacy policy, reporting workflows and full end-to-end tests before launch.
