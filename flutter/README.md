# Flutter

This folder contains the Flutter application code.

## Structure

```
flutter/
├── README.md
├── pubspec.yaml
└── lib/
    ├── main.dart
    ├── app/              # App-level configuration
    │   └── supabase_config.dart
    ├── features/         # Feature modules (session, canvas, etc.)
    ├── data/             # Data layer (repositories, models)
    └── ui/               # Shared UI components
```

## Setup

### 1. Create a Supabase Project

Go to [supabase.com](https://supabase.com) and create a new project. You'll need:

- **Project URL** — `https://xxx.supabase.co`
- **Anon Key** — Found in Project Settings → API

### 2. Run the App

Pass your credentials via `--dart-define`:

```bash
cd flutter

flutter run \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### 3. VS Code Launch Config (Optional)

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter (Supabase)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "args": [
        "--dart-define=SUPABASE_URL=https://xxx.supabase.co",
        "--dart-define=SUPABASE_ANON_KEY=your-anon-key"
      ]
    }
  ]
}
```

---

## Environment Variables

### Why `--dart-define`?

- Values are compiled into the app (not readable at runtime from a file)
- Works across all platforms (iOS, Android, Web)
- No `.env` file to accidentally commit

### Why NOT Hardcode?

```dart
// ❌ Never do this
final supabase = Supabase.initialize(
  url: 'https://xxx.supabase.co',
  anonKey: 'eyJhbGciOiJI...', // Committed to repo!
);
```

The anon key is **public** and will be in your compiled app. That's fine — it's designed to be public. But:

1. Different environments (dev/staging/prod) need different keys
2. If you rotate keys, you don't want to grep through code
3. It's a bad habit that leads to committing **secret** keys

---

## ⚠️ Why Anon Key Is Dangerous

The anon key grants access to your database **as an anonymous user**. Without Row Level Security (RLS):

```sql
-- Anyone with your anon key can run this
SELECT * FROM users;
DELETE FROM users;
```

**Always enable RLS on your tables.** The anon key is safe only when RLS policies restrict what anonymous users can do.

---

## Phases

| Phase | What's Added                             |
|-------|------------------------------------------|
| 1     | Project initialization, Supabase SDK     |
| 4     | Local state management, canvas rendering |
| 5+    | Realtime integrations                    |
