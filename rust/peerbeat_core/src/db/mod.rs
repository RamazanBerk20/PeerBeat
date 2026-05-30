//! SQLite store (rusqlite, bundled) — the single source of truth.
//!
//! Owns the schema + migrations and the FTS5 (trigram + bm25) search index.
//! The scanner ([`crate::library`]) writes here and the LAN host server
//! ([`crate::net`]) reads here, both in-process, so there is no cross-FFI
//! chatter on the hot paths. The DB runs on a dedicated worker thread; the Dart
//! side observes changes through flutter_rust_bridge streams.
//!
//! See `docs/data-model.md` for the full table set and indexing strategy.
//!
//! Implemented in **M1** (schema, migrations, browse queries, FTS) and extended
//! in **M2** (smart-playlist compiler, network tables).

// Submodules land in M1:
// mod schema;       // table definitions + migrations
// mod search;       // FTS5 trigram index + bm25 query builder
// mod smart;        // injection-safe JSON-rule -> SQL compiler
