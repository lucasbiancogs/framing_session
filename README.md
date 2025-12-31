# Framing Session

A multi-phase learning project for **Supabase Realtime** (Tables, Presence, Broadcast) with **Flutter**.

## Project Philosophy

This is a restartable, phase-based learning system:

- **Each phase is self-contained** — No phase assumes previous phases were completed
- **README-first** — Every phase produces documentation before code
- **Example, not completion** — One correct pattern per phase; you finish the rest
- **Folder separation is mandatory** — Flutter ≠ Supabase; backend concepts never buried in UI code

## Repository Structure

```
/
├── README.md
│
├── supabase/
│   ├── README.md
│   ├── schema/
│   │   └── sessions.sql
│   ├── realtime/
│   │   ├── presence.md
│   │   └── broadcast.md
│   └── notes/
│       └── concepts.md
│
└── flutter/
    ├── README.md
    └── lib/
        ├── app/
        ├── features/
        ├── data/
        └── ui/
```

---

## Phase Overview

| Phase | Focus | Files Touched |
|-------|-------|---------------|
| 0 | Mental Model & Realtime Taxonomy | `README.md`, `supabase/notes/concepts.md` |
| 1 | Project & Environment Setup | `flutter/README.md`, `supabase/README.md` |
| 2 | Tables & Data Modeling | `supabase/schema/sessions.sql` |
| 3 | Database Realtime (CDC) | `supabase/realtime/README.md` |
| 4 | Flutter Local State & Canvas | `flutter/lib/ui/`, `flutter/lib/features/` |
| 5 | Presence | `supabase/realtime/presence.md` |
| 6 | Broadcast | `supabase/realtime/broadcast.md` |
| 7 | Integration | You drive |

---

# PHASE 0 — Mental Model & Realtime Taxonomy

## Context (Standalone)

You are starting with zero Supabase code.
This phase is about understanding what tools exist and why.

## Learning Goals

- Understand the difference between:
  - Database realtime (CDC)
  - Presence
  - Broadcast
- Know which problems each tool solves
- Avoid common misuse early

## Concepts Covered

- Source of truth vs transient state
- Why realtime ≠ syncing everything
- Whiteboard as a distributed system

## What Is Done

- Written explanations in `supabase/notes/concepts.md`
- Diagrams and flows in markdown
- Mental model for choosing the right tool

## What Is NOT Done

- No Flutter
- No Supabase project
- No SQL

## Files Touched

- `README.md` (this file)
- `supabase/notes/concepts.md`

---

## Phase 0 Checklist

Complete these tasks to finish Phase 0:

- [ ] Read `supabase/notes/concepts.md` thoroughly
- [ ] Write a one-paragraph explanation for each realtime tool (in your own words)
- [ ] Decide which tool fits each use case:
  - Shape creation → ?
  - Cursor movement → ?
  - User list → ?
- [ ] Draw your own data flow diagram showing how the three tools interact

---

## ⛔ STOP HERE

Do not proceed to Phase 1 unless explicitly prompted.

Phase 1 will cover project and environment setup.

