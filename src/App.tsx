/**
 * Defines the field and admin routes while preserving one compact responsive visual shell.
 * Browser pages call Supabase Edge Functions; server functions own Storage, pgvector, and Gemini.
 * This file sits at the presentation end of both ingestion and question-answer pipelines.
 */
import { NavLink, Route, Routes } from "react-router-dom";
import { AssistantPage } from "./pages/AssistantPage";
import { KnowledgeBasePage } from "./pages/KnowledgeBasePage";
import { EvaluationsPage } from "./pages/EvaluationsPage";

/** Renders navigation and routes. Authentication is enforced again by every Edge Function. */
export default function App() {
  return <div className="app"><header><div><strong>HDD Supervisor</strong><small> Utah field knowledge</small></div><nav><NavLink to="/">Assistant</NavLink><NavLink to="/admin/knowledge-base">Knowledge Base</NavLink><NavLink to="/admin/rag-evals">Evaluations</NavLink></nav></header><main><Routes><Route path="/" element={<AssistantPage/>}/><Route path="/admin/knowledge-base" element={<KnowledgeBasePage/>}/><Route path="/admin/rag-evals" element={<EvaluationsPage/>}/></Routes></main></div>;
}
