# Real-world PLC code corpus

Public PLC projects (TwinCAT, CODESYS, B&R, plain ST) used to measure how
much real code `rootplc` accepts and which constructs block the rest.

```sh
cargo build --release
python corpus/corpus.py fetch      # shallow clones into corpus/.cache (git-ignored)
python corpus/corpus.py analyse    # writes REPORT.md
```

The repository holds only `manifest.toml` (URL, licence, format) and the
tools. Code is never copied here. Only projects with permissive licences
(`redistribute = true`) may go into a published dataset.

Latest result: [REPORT.md](REPORT.md).
