// Assemble the npm packages for a release.
//
//   node npm/build.mjs <version> <bin-dir> <out-dir>
//
// <bin-dir> holds one folder per Rust target with the binary inside, e.g.
// bin/x86_64-pc-windows-msvc/rootplc.exe. Writes <out-dir>/rootplc (the
// launcher) and <out-dir>/<platform> (one package per binary), all at
// <version>. Publish the platform packages first, then the launcher.
import { cpSync, existsSync, mkdirSync, readFileSync, writeFileSync, chmodSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const [version, binDir, outDir] = process.argv.slice(2);
if (!version || !binDir || !outDir) {
  console.error("usage: node npm/build.mjs <version> <bin-dir> <out-dir>");
  process.exit(2);
}

const TARGETS = [
  { target: "x86_64-unknown-linux-gnu", os: "linux", cpu: "x64", libc: "glibc" },
  { target: "aarch64-unknown-linux-gnu", os: "linux", cpu: "arm64", libc: "glibc" },
  { target: "aarch64-apple-darwin", os: "darwin", cpu: "arm64" },
  { target: "x86_64-apple-darwin", os: "darwin", cpu: "x64" },
  { target: "x86_64-pc-windows-msvc", os: "win32", cpu: "x64" },
];

const launcher = JSON.parse(readFileSync(join(here, "rootplc", "package.json"), "utf8"));
const readme = readFileSync(join(here, "..", "crates", "rootplc-cli", "README.md"), "utf8");
const built = [];

for (const t of TARGETS) {
  const exe = t.os === "win32" ? "rootplc.exe" : "rootplc";
  const src = join(binDir, t.target, exe);
  if (!existsSync(src)) {
    console.warn(`skip ${t.target}: ${src} not found`);
    continue;
  }
  const name = `@rootplc/${t.os}-${t.cpu}`;
  const dir = join(outDir, `${t.os}-${t.cpu}`);
  mkdirSync(join(dir, "bin"), { recursive: true });
  cpSync(src, join(dir, "bin", exe));
  if (t.os !== "win32") chmodSync(join(dir, "bin", exe), 0o755);
  const pkg = {
    name,
    version,
    description: `rootplc binary for ${t.os}-${t.cpu}. Install the rootplc package instead.`,
    license: launcher.license,
    homepage: launcher.homepage,
    repository: launcher.repository,
    os: [t.os],
    cpu: [t.cpu],
    ...(t.libc ? { libc: [t.libc] } : {}),
    files: ["bin"],
    preferUnplugged: true,
  };
  writeFileSync(join(dir, "package.json"), JSON.stringify(pkg, null, 2) + "\n");
  writeFileSync(join(dir, "README.md"), `# ${name}\n\nPlatform binary of [rootplc](https://www.npmjs.com/package/rootplc). Install \`rootplc\`, not this package.\n`);
  built.push(name);
}

const out = join(outDir, "rootplc");
cpSync(join(here, "rootplc"), out, { recursive: true });
launcher.version = version;
launcher.optionalDependencies = Object.fromEntries(
  TARGETS.map((t) => [`@rootplc/${t.os}-${t.cpu}`, version]),
);
writeFileSync(join(out, "package.json"), JSON.stringify(launcher, null, 2) + "\n");
writeFileSync(join(out, "README.md"), readme);
console.log(`built rootplc ${version} and ${built.length} platform package(s): ${built.join(", ")}`);
