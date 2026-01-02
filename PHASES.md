# Phase Progress Tracker

Track your progress through the Supabase Realtime learning phases.

## Progress

| Phase | Name                         | Status | Completed Date |
|-------|------------------------------|--------|----------------|
| 0     | Mental Model & Taxonomy      | [x]    | 2025-12-30     |
| 1     | Project & Environment Setup  | [x]    | 2026-01-02     |
| 2     | Tables & Data Modeling       | [ ]    |                |
| 3     | Database Realtime (CDC)      | [ ]    |                |
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
- [ ] Design the `shapes` table
- [ ] Decide: columns vs JSON for shape properties (width, height, x, y, color, rotation)
- [ ] Justify each design decision in comments

**Questions to answer in your design:**

| Question | Think About... |
|----------|----------------|
| What's the primary key? | UUID? Same reasoning as sessions? |
| How do shapes relate to sessions? | Foreign key to `sessions.id`? |
| What shape types exist? | Rectangle, circle, line — same columns or different? |
| Which properties change often? | Position? Size? Color? |
| Will you query by shape properties? | "Find all red shapes"? Probably not. |

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
