# Phase Progress Tracker

Track your progress through the Supabase Realtime learning phases.

## Progress

| Phase | Name                         | Status | Completed Date |
|-------|------------------------------|--------|----------------|
| 0     | Mental Model & Taxonomy      | [x]    | 2025-12-30     |
| 1     | Project & Environment Setup  | [x]    | 2026-01-02     |
| 2     | Tables & Data Modeling       | [x]    | 2026-01-02     |
| 3     | Database Realtime (CDC)      | [x]    | 2026-01-03     |
| 4     | Flutter Local State & Canvas | [x]    | 2026-01-06     |
| 5     | Database Integration (CRUD)  | [ ]    |                |
| 6     | Presence                     | [ ]    |                |
| 7     | Broadcast                    | [ ]    |                |
| 8     | Integration                  | [ ]    |                |

> **Mark complete**: Change `[ ]` to `[x]` and add the date (e.g., `2024-01-15`)

---

## How to Start a Phase

1. Open a new chat
2. Say: **"I'm starting Phase N"** or **"Apply phase-N rules"**

The global rules (`.cursor/rules/global.mdc`) are always active.
Phase-specific rules are in `.cursor/rules/phase-N.mdc`.

---

## Phase Overview

| Phase | Focus                    | Key Deliverable                         |
|-------|--------------------------|-----------------------------------------|
| 0     | Mental model             | Understand CDC vs Presence vs Broadcast |
| 1     | Setup                    | Flutter + Supabase connected            |
| 2     | Data modeling            | `sessions` table designed               |
| 3     | Database CDC             | Realtime enabled, payloads understood   |
| 4     | Flutter UI               | Canvas + shapes rendering (local)       |
| 5     | Database Integration     | DTOs, DataSources, Supabase CRUD        |
| 6     | Presence                 | User list, join/leave handling          |
| 7     | Broadcast                | Cursor sharing                          |
| 8     | Integration              | All systems working together            |

---

## Phase 0 — Mental Model & Taxonomy

- [x] Read `supabase/notes/concepts.md` thoroughly
- [x] Write a one-paragraph explanation for each realtime tool (in your own words)
- [x] Decide which tool fits each use case:
  - Shape creation → ?
  - Cursor movement → ?
  - User list → ?
- [x] Draw your own data flow diagram showing how the three tools interact

---

## Phase 1 — Project & Environment Setup

- [x] Create a Supabase project at supabase.com
- [x] Run the app with your credentials:
  ```bash
  cd flutter
  flutter run \
    --dart-define=SUPABASE_URL=https://xxx.supabase.co \
    --dart-define=SUPABASE_ANON_KEY=your-anon-key
  ```
- [x] Verify the app starts without throwing an exception
- [x] Break it intentionally — try running without the `--dart-define` flags and see the error
- [x] Answer: Why is the anon key dangerous without RLS?

---

## Phase 2 — Tables & Data Modeling

- [x] Run `supabase/schema/sessions.sql` in Supabase SQL Editor
- [x] Design the `shapes` table
- [x] Decide: columns vs JSON for shape properties (width, height, x, y, color, rotation)
- [x] Justify each design decision in comments

**Questions to answer in your design:**

| Question | Think About... |
|----------|----------------|
| What's the primary key? | UUID? Same reasoning as sessions? |
| How do shapes relate to sessions? | Foreign key to `sessions.id`? |
| What shape types exist? | Rectangle, circle, line — same columns or different? |
| Which properties change often? | Position? Size? Color? |
| Will you query by shape properties? | "Find all red shapes"? Probably not. |

---

## Phase 3 — Database Realtime (CDC)

- [x] Run the realtime SQL in Supabase SQL Editor:
  ```sql
  ALTER PUBLICATION supabase_realtime ADD TABLE sessions;
  ```
- [x] Enable realtime on the `shapes` table (same pattern as sessions)
- [x] Test with the Supabase Dashboard:
  1. Go to Table Editor → sessions
  2. Open browser DevTools → Network → WS tab
  3. Insert a row manually
  4. Observe the realtime payload in the WebSocket connection
- [x] Answer: Which UPDATE events on shapes actually matter?
  - Position changes (x, y)?
  - Size changes (width, height)?
  - Color changes?
  - Which ones happen frequently enough to consider Broadcast instead?
- [x] Identify potentially "noisy" events (changes that fire too often)

---

## Phase 4 — Flutter Local State & Canvas

### Collaborative Whiteboard Architecture

The canvas follows a **single CustomPainter** architecture for real-time collaboration:

| Component | Responsibility |
|-----------|----------------|
| **WhiteboardCanvas** | Receives pointer events, performs hit testing, emits operations |
| **WhiteboardPainter** | Single CustomPainter that renders ALL shapes |
| **CanvasVM** | Single source of truth, applies operations immutably |
| **EditIntent** | What kind of edit (move, resize, rotate) |
| **EditOperation** | The actual change to broadcast |

**Mental Model:**
```
Canvas decides WHO receives input
Shapes decide WHAT it means
Operations decide WHAT changes
ViewModel decides WHAT is true
```

### Concepts to Understand

- [x] Read the architecture files and understand the data flow:
  - `WhiteboardCanvas` → hit test → `EditIntent` → `EditOperation` → `CanvasVM.applyOperation()`
  - **Local state** (CanvasLoaded): `panOffset`, `zoom`, `currentTool`, `selectedShapeId`
  - **Shared state** (CanvasLoaded): `shapes` — will come from DB in Phase 5+
- [x] Why are shapes painted in a single CustomPainter (not widgets)?
- [x] Why do we broadcast operations, not full shape state?
- [x] Understand the difference between `ref.watch()` and `ref.read()`

### Tasks to Complete

- [x] Run `flutter pub get` in the `flutter/` directory
- [x] Run the app and verify the canvas works with mock shapes
- [x] Try each tool (Select, Rectangle, Circle, Triangle, Text)
- [x] Create new shapes by double-tapping the canvas
- [x] Select shapes by tapping, drag to move/resize
- [x] Delete shapes with the delete button

### Features to Build (You Drive)

- [x] Create `SessionServices` (interface + `MockSessionServices` implementation)
- [x] Create `SessionsPage` with a list of sessions
- [x] Create `SessionsVM` to manage session list state
- [x] Add navigation: `SessionsPage` → `CanvasPage`
- [x] Add "Create Session" functionality

### Stretch Goals (Optional)

- [ ] Implement pan gesture (two-finger drag updates `panOffset`)
- [ ] Implement pinch-to-zoom (updates `zoom` in CanvasVM)
- [ ] Add color picker for creating shapes
- [ ] Add rotation handles

### Architecture Questions

| Question | Answer |
|----------|--------|
| Why no widget per shape? | Widgets are heavy. CustomPainter can render 1000s of shapes efficiently. |
| Why operations, not state? | Operations are small. State is large. Broadcasting operations = less bandwidth. |
| What if ops arrive out of order? | Operations carry `revision` numbers for ordering. |
| What if I miss an operation? | Resync via snapshot (later phases). |
| What happens with two users editing? | Presence lock (Phase 6) — only one user edits at a time. |

---

## Phase 5 — Database Integration (Supabase CRUD)

### Learning Goals

- Connect Flutter to Supabase for basic CRUD operations
- Implement DTOs with proper conversion methods
- Create DataSources that talk to Supabase
- Replace mock services with Supabase-backed implementations

### Tasks to Complete

- [x] Create `SessionDto` with all 4 methods (`fromMap`, `toMap`, `toEntity`, `fromEntity`)
- [x] Create `SupabaseSessionDataSource` implementing CRUD operations
- [x] Create `SessionServicesImpl` using the DataSource
- [x] Wire up providers in `global_providers.dart`
- [x] Test: Create a session from Flutter, see it in Supabase Dashboard
- [x] Create `ShapeDto` following the same pattern
- [x] Create `SupabaseShapeDataSource` for shapes CRUD
- [x] Create `ShapeServicesImpl` using the DataSource

### Key Files to Create

```
flutter/lib/data/
├── dtos/
│   ├── session_dto.dart
│   └── shape_dto.dart
└── datasources/
    ├── session_remote.dart
    └── shape_remote.dart
```

### Verification

- [x] Create a session → appears in Supabase Dashboard
- [x] Delete a session → removed from Supabase Dashboard
- [x] Create a shape → appears in Supabase Dashboard
- [x] Refresh the app → data persists (not lost like mock data)

---

## Phase 6 — Presence

- [ ] Display connected users in the UI
- [ ] Handle join/leave events gracefully
- [ ] Decide what user metadata to track

---

## Phase 7 — Broadcast

- [ ] Broadcast cursor movement
- [ ] Render other users' cursors
- [ ] Handle stale/dropped messages safely
- [ ] Implement throttling

---

## Phase 8 — Integration

- [ ] Document responsibility per realtime tool
- [ ] Implement full sync logic (join → hydrate → subscribe)
- [ ] Identify potential race conditions in your app
- [ ] Handle reconnection gracefully
- [ ] Test with multiple clients

---

## Rules Location

```
.cursor/rules/
├── global.mdc      ← Always active (project context, feature mapping)
├── phase-0.mdc     ← Mental Model
├── phase-1.mdc     ← Setup
├── phase-2.mdc     ← Tables
├── phase-3.mdc     ← Database CDC
├── phase-4.mdc     ← Flutter Canvas
├── phase-5.mdc     ← Database Integration (CRUD)
├── phase-6.mdc     ← Presence
├── phase-7.mdc     ← Broadcast
└── phase-8.mdc     ← Integration
```
