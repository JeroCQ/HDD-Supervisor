# How HDD RAG works

## The short version

RAG means **retrieval-augmented generation**: Gemini does not answer from memory alone. The system first retrieves applicable passages from the owner's documents, then asks Gemini to explain only that evidence.

```text
USER QUESTION
      |
      v
Lovable UI
      |
      v
External Supabase Edge Function
      |
      +--> Project/Jurisdiction Classifier
      |
      +--> Gemini Query Embedding
      |
      v
Hybrid Search
  |              |
  v              v
Keyword       pgvector
Search         Search
  \              /
   \            /
    v          v
      Merge / Rank
           |
           v
 Jurisdiction Filter
           |
           v
 Authority Reranker
           |
           v
 Evidence Pack
           |
           v
        Gemini
           |
           v
 Answer + Source Citations
```

## Upload and indexing

1. An administrator uploads a PDF into the private `kb-source-documents` bucket. The original stays there; database rows store only its private path and metadata.
2. **Sync Manifest** reads `manifests/HDD_Knowledge_Base_Source_Manifest.csv` and safely upserts metadata. **Scan Storage** finds unregistered PDFs without deleting anything.
3. **Parsing** means turning each PDF page into text. A short-lived signed URL lets authenticated browser PDF.js read the file. Its `DocumentParser` output keeps every `pageNumber`. Scans without a text layer need review/OCR outside this implementation.
4. A page range such as `55-59` limits large manuals. More than 300 pages without ranges becomes `NEEDS_REVIEW`.
5. A **chunk** is one useful evidence passage. The chunker recognizes statutes, rules, articles, engineering details, headings, and paragraph groups rather than blindly cutting characters. It aims for about 300–900 tokens, keeps a condition with its heading, never joins documents, and records page, section, citation, scope, project, and authority.
6. An **embedding** is a numeric meaning fingerprint. The server sends chunk text to Gemini `gemini-embedding-001`, asks for 1,536 values, and stores those values in `vector(1536)`. A SHA-256 content hash reuses an unchanged embedding during re-indexing.
7. `pgvector` finds passages whose meaning resembles a question. PostgreSQL full-text search finds literal words using the language-neutral `simple` configuration. Together they handle precise citations and paraphrases better than either method alone.

## Asking and authority

1. The field UI sends the question, language, and project to authenticated `ask-supervisor`.
2. Deterministic classification records language, intent, jurisdiction, project, location type, and evidence needs. Unknown location stays `UNKNOWN`.
3. Metadata filters run **before generation**. For EP-22349, Saratoga Springs, statewide Utah, federal, general, and project evidence are eligible; Provo/West Jordan are excluded. UDOT-only material requires an explicit UDOT context. This prevents a highly ranked but inapplicable city rule from becoming authority.
4. Gemini creates a query embedding. `hybrid_search_kb` independently ranks vector and keyword candidates, merges them with reciprocal-rank fusion, then modestly reranks applicable material by authority: project 100, municipal 90, Utah 80, government guidance 70, federal 60, technical 40, communication 20.
5. The evidence pack includes source labels, sections, pages, scope, and authority. Gemini `gemini-2.5-flash` returns schema-validated JSON. It must not treat LEAPS, technical manuals, or Blue Stakes guidance as law.
6. Citation cards are built only from retrieved rows. Their opaque token is exchanged server-side for a signed private Storage URL that expires after 60 seconds.

`VERIFIED` means the evidence actually establishes the requested authority. `PARTIAL` means relevant authority exists but something essential—often accepted plans, a permit, or an easement for the exact location—is absent. `NOT_VERIFIED` means evidence cannot establish it. `NOT_APPLICABLE` is used when legal authority is not the nature of the answer.

## Replacement, re-indexing, and evaluation

Replacing a PDF does not silently erase history. Mark the older document superseded, keep its row, register the replacement, and re-index it. Re-indexing extracts selected pages again; unchanged chunk hashes reuse vectors, while changed chunks receive new Gemini embeddings. Only after a successful insert does the document become `READY`.

The ten seeded evaluations ask the production function and store results. They check expected top-five documents, forbidden-source contamination, jurisdiction, citations, expected concepts, language, and authority status. The admin screen makes regressions visible. Production targets are at least 90% expected-document retrieval, 100% jurisdiction exclusions, citations in every legal answer, no unsupported `VERIFIED`, and Spanish queries retrieving English evidence.
