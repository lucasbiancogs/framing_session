# Phase Progress Tracker

Track your progress through the Supabase Realtime learning phases.

## Progress

| Phase | Name                         | Status | Completed Date |
|-------|------------------------------|--------|----------------|
| 0     | Mental Model & Taxonomy      | [x]    | 2025-12-30     |
| 1     | Project & Environment Setup  | [x]    | 2026-01-02     |
| 2     | Tables & Data Modeling       | [x]    | 2026-01-02     |
| 3     | Database Realtime (CDC)      | [x]    | 2026-01-03     |
| 4     | Flutter Local State & Canvas | [ ]    |                |
| 5     | Presence                     | [ ]    |                |
| 6     | Broadcast                    | [ ]    |                |
| 7     | Integration                  | [ ]    |                |

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
| 5     | Presence                 | User list, join/leave handling          |
| 6     | Broadcast                | Cursor sharing                          |
| 7     | Integration              | All systems working together            |

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
| What happens with two users editing? | Presence lock (Phase 5) — only one user edits at a time. |

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
├── phase-5.mdc     ← Presence
├── phase-6.mdc     ← Broadcast
└── phase-7.mdc     ← Integration
```
