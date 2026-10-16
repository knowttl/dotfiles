import { spawn } from "node:child_process";
import { createInterface } from "node:readline";

const settings = {
  "analytics.enabled": false,
  "feedback.enabled": false,
  "otel.exporter": "none",
  "otel.metrics_exporter": "none",
  "otel.trace_exporter": "none",
  "otel.log_user_prompt": false,
};

// Use Codex's atomic config writer to preserve unrelated TOML and comments.
// Apply the same opt-outs at startup before the existing config is updated.
const server = spawn("codex", [
  ...Object.entries(settings).flatMap(([key, value]) => [
    "--config", `${key}=${JSON.stringify(value)}`,
  ]),
  "app-server", "--listen", "stdio://",
], { stdio: ["pipe", "pipe", "inherit"] });
server.on("error", (error) => {
  console.error(error.message);
  process.exitCode = 1;
});
const responses = createInterface({ input: server.stdout })[Symbol.asyncIterator]();
const timeout = setTimeout(() => server.kill(), 30_000);

async function request(id, method, params) {
  server.stdin.write(JSON.stringify({ id, method, params }) + "\n");
  while (true) {
    const { value, done } = await responses.next();
    if (done) throw new Error("Codex exited before saving telemetry settings");
    const response = JSON.parse(value);
    if (response.id !== id) continue;
    if (response.error) throw new Error(response.error.message);
    return response.result;
  }
}

try {
  await request(1, "initialize", {
    clientInfo: { name: "dotfiles", version: "1.0.0" },
  });
  server.stdin.write(JSON.stringify({ method: "initialized" }) + "\n");
  await request(2, "config/batchWrite", {
    edits: Object.entries(settings).map(([keyPath, value]) => ({
      keyPath, value, mergeStrategy: "replace",
    })),
  });
} finally {
  clearTimeout(timeout);
  server.stdin.end();
  server.kill();
}
