# Flutter

This folder contains the Flutter application code for the Whiteboard collaborative canvas.

## Structure

```
flutter/
├── README.md
├── pubspec.yaml
└── lib/
    ├── main.dart
    │
    ├── app/                    # App-level configuration
    │   └── supabase_config.dart
    │
    ├── core/                   # Cross-cutting concerns
    │   ├── errors/             # Base exceptions, error handling
    │   │   └── base_exception.dart
    │   └── config/             # Environment configuration
    │       └── env_config.dart
    │
    ├── domain/                 # Business logic layer
    │   ├── entities/           # Immutable domain models
    │   │   ├── session.dart
    │   │   └── shape.dart
    │   └── services/           # Interface + implementation
    │       ├── session_services.dart
    │       └── shape_services.dart
    │
    ├── data/                   # Data layer
    │   ├── dtos/               # Data Transfer Objects
    │   │   ├── session_dto.dart
    │   │   └── shape_dto.dart
    │   └── datasources/        # Remote data sources
    │       ├── session_remote.dart
    │       └── shape_remote.dart
    │
    └── presentation/           # UI layer
        ├── pages/              # Feature pages + ViewModels
        │   ├── sessions/
        │   │   ├── sessions_page.dart
        │   │   └── sessions_vm.dart
        │   └── canvas/
        │       ├── canvas_page.dart
        │       ├── canvas_vm.dart
        │       └── shape_renderer.dart
        ├── widgets/            # Reusable widgets
        │   ├── loading_widget.dart
        │   └── error_retry_widget.dart
        └── view_models/        # Global providers
            └── global_providers.dart
```

## Architecture Overview

This project follows **DDD (Domain-Driven Design)** with clean architecture:

| Layer | Purpose | Contains |
|-------|---------|----------|
| **Core** | Cross-cutting concerns | Exceptions, config |
| **Domain** | Business logic | Entities, Services |
| **Data** | External data access | DTOs, DataSources |
| **Presentation** | UI | Pages, Widgets, ViewModels |

See `.cursor/rules/architecture.mdc` for detailed patterns.

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
SELECT * FROM sessions;
DELETE FROM shapes;
```

**Always enable RLS on your tables.** The anon key is safe only when RLS policies restrict what anonymous users can do.

---

## Key Patterns

### Services (Domain Layer)
Interface and implementation in the same file:

```dart
// lib/domain/services/shape_services.dart
abstract class ShapeServices {
  Future<Either<BaseException, List<Shape>>> getSessionShapes(String sessionId);
}

class ShapeServicesImpl implements ShapeServices {
  ShapeServicesImpl(this._dataSource);
  final ShapeRemoteDataSource _dataSource;
  
  @override
  Future<Either<BaseException, List<Shape>>> getSessionShapes(String sessionId) async {
    try {
      final dtos = await _dataSource.getShapesData(sessionId);
      return right(dtos.map((d) => d.toEntity()).toList());
    } catch (e) {
      return left(ShapeException.unknown(e.toString()));
    }
  }
}
```

### DTOs (Data Layer)
With all 4 conversion methods:

```dart
// lib/data/dtos/shape_dto.dart
class ShapeDto {
  factory ShapeDto.fromMap(Map<String, dynamic> map);  // DB → DTO
  Map<String, dynamic> toMap();                         // DTO → DB
  Shape toEntity();                                     // DTO → Entity
  factory ShapeDto.fromEntity(Shape entity);            // Entity → DTO
}
```

### ViewModels (Presentation Layer)
StateNotifier with Riverpod:

```dart
// lib/presentation/pages/canvas/canvas_vm.dart
final canvasVM = StateNotifierProvider.family<CanvasVM, CanvasState, String>(
  (ref, sessionId) => CanvasVM(ref.watch(shapeServices), sessionId),
);

class CanvasVM extends StateNotifier<CanvasState> {
  CanvasVM(this._services, this.sessionId) : super(const CanvasLoading()) {
    _loadShapes();
  }
}
```

---

## Phases

| Phase | What's Added                             |
|-------|------------------------------------------|
| 1     | Project initialization, Supabase SDK     |
| 2     | Tables & data modeling                   |
| 3     | Database Realtime (CDC)                  |
| 4     | Local state management, canvas rendering |
| 5     | Presence (online users)                  |
| 6     | Broadcast (cursors)                      |
| 7     | Integration                              |

---

## Related Documentation

- [Architecture Rules](../.cursor/rules/architecture.mdc) — DDD patterns
- [DTO & Entities](../.cursor/rules/dto-entities.mdc) — Data transformation
- [State Management](../.cursor/rules/state-management.mdc) — Riverpod patterns
- [View Models](../.cursor/rules/view-models.mdc) — ViewModel patterns
- [UI Components](../.cursor/rules/ui-components.mdc) — Widget patterns
