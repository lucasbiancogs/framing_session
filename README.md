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
| 5 | Database Integration (CRUD) | `flutter/lib/data/`, DTOs & DataSources |
| 6 | Presence | `supabase/realtime/presence.md` |
| 7 | Broadcast | `supabase/realtime/broadcast.md` |
| 8 | Integration | You drive |

---
