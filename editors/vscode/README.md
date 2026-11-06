# RootPLC Structured Text for VS Code

IEC 61131-3 Structured Text with the `rootplc` language server
([spec/19-lsp.md](../../spec/19-lsp.md)):

- **Diagnostics while you type**, the same as `rootplc check`: stable codes
  (`RPnnnn`), exact ranges and fix hints; vendor forms are warnings, so
  code without warnings is IEC Structured Text.
- **Hover** on a diagnostic shows the spec rule behind its code; on a name
  it shows the declaration.
- **Go to definition** for variables, blocks, functions, types, methods and
  global variables.
- **Outline** of programs, blocks, functions, types and their variables,
  also while the code does not compile.
- Syntax highlighting, comments, brackets and folding for `.st` files.

The extension has no dependencies: it starts `rootplc lsp` and talks to it
with a small client of its own (`client.js`).

## Use it

1. Install `rootplc` (see the main [README](../../README.md)) so that
   `rootplc` is on your PATH, or set `rootplc.path`.
2. Run the extension from this folder:
   `code --extensionDevelopmentPath=/path/to/RootPLC/editors/vscode /your/project`
3. For TwinCAT code, set `rootplc.libraries` to e.g.
   `["Tc2_System", "TwinCAT_BuiltIns"]`.

A packaged `.vsix` and a Marketplace listing come later (they need a
publisher account).

## Check it

`node test/lsp-smoke.js path/to/rootplc` starts the language server through
the extension's client and checks diagnostics, hover, clearing, the outline,
go to definition and shutdown. CI runs it on every change.
