# Editor support: the language server

`rootplc lsp` is a Language Server Protocol server on stdio, so editors
(VS Code, Neovim, Emacs, JetBrains, Zed …) show RootPLC's diagnostics while
a person types, with hover, go-to-definition and an outline. It is the
human side of the same checks agents get through `rootplc check` and MCP:
the diagnostics, codes and hints are identical.

**[lsp.transport]** Messages are JSON-RPC 2.0 framed with a
`Content-Length` header, as the LSP specification defines. The server
answers `initialize` with its capabilities (full text synchronisation,
hover, definition, document symbols), handles `initialized`, `shutdown`
and `exit`, and ignores notifications it does not know. A request it does
not know gets the error `MethodNotFound` (-32601). Positions are 0-based
lines and characters; RootPLC counts characters in code points.

**[lsp.project]** The project is every `.st` file under the workspace
folder given in `initialize` (`rootUri` or the first `workspaceFolders`
entry) plus documents the editor opened outside it. An open document's
text in the editor replaces the file on disk. `initializationOptions` may
give `{"libraries": ["Tc2_System", ...]}` to activate compatibility
libraries, as `--library` does.

**[lsp.diagnostics]** After `didOpen`, `didChange` and `didSave` the
server checks the project and sends `textDocument/publishDiagnostics` for
every project file that has diagnostics, and an empty list for a file whose
diagnostics went away. Each diagnostic has the range of the rootplc
diagnostic, its severity (error 1, warning 2), its code (`RPnnnn`), the
source `rootplc` and the message, followed by the hint when there is one.

**[lsp.symbols]** `textDocument/documentSymbol` lists the declarations of
the document: programs, function blocks, functions, methods, interfaces,
types, TEST blocks and global variable lists, each with the variables it
declares as children. It works on text that does not compile.

**[lsp.definition]** `textDocument/definition` on a name finds its
declaration: a variable of the enclosing POU (or the global variables),
then a POU, type, method or global variable anywhere in the project. Names
compare case-insensitively.

**[lsp.hover]** `textDocument/hover` on a position inside a diagnostic's
range shows the explanation of its code (the text of `rootplc explain`);
on a declared name it shows the declaration's line.
