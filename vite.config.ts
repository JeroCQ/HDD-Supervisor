/** Configures the browser bundle and Vitest without introducing server secrets. */
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
export default defineConfig({ plugins: [react()], test: { environment: "node" } });
