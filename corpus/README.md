# Real-world PLC code corpus

Public PLC projects (TwinCAT, CODESYS, B&R, plain ST) used to measure how
much real code `rootplc` accepts and which constructs block the rest.

```sh
cargo build --release
python corpus/corpus.py fetch      # shallow clones into corpus/.cache (git-ignored)
python corpus/corpus.py analyse    # writes REPORT.md
python corpus/corpus.py run        # run smoke test: execute each application program (adds to REPORT.md)
```

The repository holds only `manifest.toml` (URL, licence, format) and the
tools. Code is never copied here. Only projects with permissive licences
(`redistribute = true`) may go into a published dataset.

Every project is reviewed and given a `category`; the headline figures use
applications, libraries and samples only, and a holdout set (never used to
choose fixes) shows whether improvements generalise. Projects that are empty,
duplicated, not Structured Text or too small to matter are removed and listed
under `[[excluded]]` in the manifest. *Clean* is rootplc's own verdict, not a
vendor compiler's.

Latest result: [REPORT.md](REPORT.md).
