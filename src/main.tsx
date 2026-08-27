/**
 * Boots the Lovable-style React interface. It is called by index.html, talks only
 * to authenticated Supabase Edge Functions, and is the browser entry to the RAG pipeline.
 */
import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App";
import "./styles.css";

/** Mounts the application; failures are surfaced by React rather than hiding configuration errors. */
ReactDOM.createRoot(document.getElementById("root")!).render(<React.StrictMode><BrowserRouter><App /></BrowserRouter></React.StrictMode>);
