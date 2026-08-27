# Edge Functions guide

## Shared server code

`_shared/core.ts` builds the service client, verifies JWTs and the database admin role, creates the Gemini client from server-only `GEMINI_API_KEY`, generates 1,536-dimensional embeddings, hashes content, and performs conservative classification.

## `kb-admin`

1. Authenticate; require admin for every action except a signed citation lookup.
2. **Sync Manifest:** download the private CSV, parse quoted fields, skip manifest/archive/index rows, selectively upsert by `document_id`, preserve metadata not owned by the manifest, never delete absent rows, and return inserted/updated/skipped/errors.
3. **Scan Storage:** recursively discover PDFs, create disabled `UNMAPPED-*` records, and never delete objects.
4. **Ingest/Re-index:** create a visible queued job and a five-minute PDF URL for browser PDF.js.
5. Validate page ranges and update metadata. Toggle RAG without deleting sources.
6. **View Source:** decode only a server-produced document token, resolve the stored path, and return a 60-second signed URL.

## `ingest-document`

1. Require an admin and validate page-numbered text.
2. Refuse an unrestricted manual over 300 pages.
3. Mark job/document `PROCESSING`.
4. Split at legal/engineering headings and paragraph boundaries, aiming at 300–900 tokens.
5. hash chunks, reuse unchanged vectors, and retry Gemini embedding calls three times.
6. Store page-aware chunks in Supabase, record `gemini-embedding-001` / 1536, then mark `READY`. Persist safe failures as `FAILED`.

## `ask-supervisor`

1. Authenticate and validate 1–2,000 characters.
2. Load active project and classify language, intent, jurisdiction, location, and needs without guessing location.
3. Embed the query with Gemini and invoke `hybrid_search_kb`.
4. Recheck forbidden city scopes, construct an evidence pack, and call existing generation model `gemini-2.5-flash` with a JSON schema.
5. Return concise answer/script/status/confidence/warnings and evidence-derived citation tokens.

## `run-rag-evals`

Require admin, run every active case through deployed `ask-supervisor`, calculate retrieval/jurisdiction/citation/concept/language/status checks, and store visible results.

All functions log error messages, never keys, PDF contents, authorization headers, or service credentials.
