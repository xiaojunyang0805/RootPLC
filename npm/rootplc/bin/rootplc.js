#!/usr/bin/env node
// Launcher for the native rootplc binary, installed from the matching
// @rootplc/<platform> package (an optional dependency). stdio is passed
// through, so `npx -y rootplc mcp` works as an MCP stdio server.
"use strict";

const { spawnSync } = require("node:child_process");

const PLATFORMS = {
  "linux-x64": "@rootplc/linux-x64",
  "linux-arm64": "@rootplc/linux-arm64",
  "darwin-arm64": "@rootplc/darwin-arm64",
  "darwin-x64": "@rootplc/darwin-x64",
  "win32-x64": "@rootplc/win32-x64",
};

function fail(message) {
  process.stderr.write(`rootplc: ${message}\n`);
  process.exit(2);
}

function binaryPath() {
  if (process.env.ROOTPLC_BINARY) return process.env.ROOTPLC_BINARY;
  const key = `${process.platform}-${process.arch}`;
  const pkg = PLATFORMS[key];
  if (!pkg) fail(`no prebuilt binary for ${key}; install with cargo: cargo install rootplc`);
  const exe = process.platform === "win32" ? "rootplc.exe" : "rootplc";
  try {
    return require.resolve(`${pkg}/bin/${exe}`);
  } catch {
    return fail(`${pkg} is not installed; reinstall without --omit=optional, or: cargo install rootplc`);
  }
}

const result = spawnSync(binaryPath(), process.argv.slice(2), { stdio: "inherit" });
if (result.error) fail(result.error.message);
process.exit(result.status === null ? 1 : result.status);
