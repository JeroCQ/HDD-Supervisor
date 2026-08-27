# Database guide

The database is the user's existing external Supabase Postgres. All tables use RLS; browser code does not directly read KB evidence. Edge Functions authenticate the caller and use the server-held service role.

- **`projects`** — project identity and applicable jurisdiction. `project_code` is the stable selector; `authorization_status` deliberately distinguishes `PARTIAL` from `VERIFIED`; `metadata` holds future site facts such as confirmed UDOT ROW. EP-22349 is seeded as Saratoga Springs and `PARTIAL`.
- **`kb_documents`** — one source identity. `storage_bucket/path` locate the private PDF; jurisdiction/project and `authority_rank` control applicability; `rag_ingest`, `is_current`, and `superseded_by` control retrieval; ranges constrain parsing; parser/model/dimensions and hashes make indexing auditable; ingestion status/error/count expose lifecycle.
- **`kb_chunks`** — retrieved evidence. `content` and `normalized_content` support display/FTS; `embedding vector(1536)` supports cosine search; page/section/legal citation produce exact citations; scope/project filter first; tags describe intent; hash makes re-indexing idempotent.
- **`kb_ingestion_jobs`** — each admin request, requesting user, selected ranges, page/chunk progress, timestamps, safe error, and JSON logs.
- **`rag_eval_cases`** — expected and forbidden source IDs, expected concepts/status, language, project, and notes for repeatable acceptance tests.
- **`rag_eval_runs`** — answer and returned sources plus retrieval, jurisdiction, citation, behavior, and overall PASS/FAIL.
- **`profiles`** — an Auth user ID and trusted `is_admin`. Grant this only in Dashboard Table Editor; browser input cannot grant roles.

`hybrid_search_kb` filters applicable/current/READY sources, ranks semantic and keyword candidates, applies reciprocal-rank fusion, and returns source metadata. HNSW indexes vectors; GIN indexes FTS and arrays; B-tree indexes scope/project/state. The function is executable only by `service_role`.
