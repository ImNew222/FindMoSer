# Legacy locator notes (historical)

Earlier FindMoSer prototypes included a faculty-locator map (student browser of teacher positions) and an "AI assistant" experiment. These were removed from active navigation during the 2026 flow review.

What remains, deliberately:

- **Deterministic assistant**: students can ask "where is Dr. Santos" and receive an answer derived live from `faculty_presence` (the faculty member's own sharing toggle controls visibility). It is a rules-based lookup, not a language model — there is no AI service call in the app.
- Raw `locations/{facultyId}` documents remain faculty-private; the student-readable `faculty_presence` projection is sanitized by Firestore rules.

See `docs/improvement-plan.md` for the phase-by-phase removal record.
