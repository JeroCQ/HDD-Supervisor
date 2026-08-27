# Cloud-only manual test procedure

## One-time browser setup

1. Open the **user-owned Supabase Dashboard → SQL Editor**, paste `supabase/migrations/202608270001_hdd_rag.sql` from GitHub, and choose **Run**.
2. In **Edge Functions**, create/deploy `_shared`, `kb-admin`, `ingest-document`, `ask-supervisor`, and `run-rag-evals` using the matching GitHub files (or connect the repository deployment integration).
3. Open **Edge Functions → Secrets** and add `GEMINI_API_KEY`. Never place it in Lovable variables or tables.
4. In **Table Editor → profiles**, add the intended Auth user's UUID and set `is_admin` true.
5. In Lovable's browser environment settings, retain the external project's URL and publishable key as `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`. These are designed for browser use; never add service-role or Gemini secrets.

## Ingestion

1. In **Storage → kb-source-documents**, confirm the bucket is private, PDFs exist, and the manifest is at the documented path.
2. Open **Lovable → Preview → Knowledge Base**. Choose **Sync Manifest** and verify counts in the message and rows in **Table Editor → kb_documents**.
3. Choose **Scan Storage** and confirm unmapped PDFs appear disabled; no Storage object should disappear.
4. For a large manual choose **Set ranges** (for example `760-850`), then **Ingest**. Browser PDF.js extracts page text; the hosted function chunks/embeds it.
5. Watch **Table Editor → kb_ingestion_jobs** and **Edge Functions → Logs**. A success ends `READY`; a failure is visible and safe to retry. Inspect `kb_chunks` pages, sections, hashes, and 1,536-value vectors in Table Editor.

## Assistant and citations

1. In **Field Assistant**, select EP-22349 and ask each quick question in English and Spanish.
2. Confirm FIELD ANSWER, WHAT TO SAY when useful, authority/confidence, and source cards.
3. Choose **View Source**. The PDF should open; retry the captured link after one minute and confirm it expired.
4. Ask about Provo for EP-22349: it must not be authority. Ask specifically for Provo depth: Provo evidence may appear. Ask about UDOT ROW explicitly: UDOT evidence may appear. Do not provide a location: the response must not invent one.

## Evaluations and inspection

1. Open **RAG Evaluations → Run All Evaluations** and inspect per-check PASS/FAIL.
2. In **Table Editor → rag_eval_runs**, inspect source IDs, authority status, and details.
3. Use **Edge Function Test UI** with an authenticated JWT to test invalid/empty input and observe a safe 400 response. Use Logs to confirm errors contain no secrets.
4. Before production require the targets in `TESTING_GUIDE.md`. A red result is evidence to fix metadata/ranges/content—not a reason to weaken the expectation.
