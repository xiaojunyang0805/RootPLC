//! RootBlocks catalog rules (spec/15-blocks.md, blocks/README.md): every
//! `RB_` block has a card that names it, the block tests pass, and the
//! library's mutation score against them is at least 90%.

use std::path::{Path, PathBuf};

fn repo() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../..")
}

fn library_sources() -> Vec<(PathBuf, String)> {
    let libs = rootplc_stdlib::compat::resolve(&["RootBlocks".to_string()]).expect("bundled");
    libs.iter()
        .flat_map(|l| l.files.iter())
        .map(|(name, text)| (PathBuf::from(name), (*text).to_string()))
        .collect()
}

fn block_tests() -> Vec<(PathBuf, String)> {
    rootplc_driver::read_sources(&[repo().join("conformance/cases/blocks")]).expect("block tests")
}

fn block_names(src: &str) -> Vec<String> {
    src.lines()
        .filter_map(|l| l.trim().strip_prefix("FUNCTION_BLOCK "))
        .map(|n| n.trim().to_string())
        .filter(|n| n.starts_with("RB_"))
        .collect()
}

#[test]
fn every_block_has_a_card_and_tests() {
    let Ok(cards) = std::fs::read_dir(repo().join("blocks/cards")) else {
        return; // not shipped with the published crate
    };
    let cards: Vec<String> = cards
        .flatten()
        .filter_map(|e| std::fs::read_to_string(e.path()).ok())
        .collect();
    let tests: String = block_tests().into_iter().map(|(_, s)| s).collect();
    let names: Vec<String> = library_sources()
        .iter()
        .flat_map(|(_, s)| block_names(s))
        .collect();
    assert!(!names.is_empty());
    for n in names {
        assert!(
            cards.iter().any(|c| c
                .lines()
                .next()
                .is_some_and(|h| h.contains(&format!("`{n}`")))),
            "{n} has no card in blocks/cards"
        );
        assert!(
            tests.contains(&format!(": {n};")),
            "{n} is not used by any block test"
        );
    }
}

#[test]
fn block_tests_kill_at_least_90_percent_of_mutants() {
    if !repo().join("conformance/cases/blocks").exists() {
        return;
    }
    let mut sources = library_sources();
    sources.extend(block_tests());
    let m =
        rootplc_driver::mutate::mutation_report(sources, &[], None, 10_000).expect("mutation run");
    assert!(m.baseline.ok(), "block tests fail");
    // every mutant runs: a capped run would leave the last blocks unchecked
    assert_eq!(m.mutants.len(), m.candidates, "mutation run was truncated");
    // only the library's own mutants count: helper blocks in the test files
    // are fixtures, not catalog code
    let lib = |p: &std::path::Path| p.file_name().is_some_and(|n| n == "RootBlocks.st");
    let mine: Vec<_> = m.mutants.iter().filter(|(mu, _)| lib(&mu.path)).collect();
    let viable = mine
        .iter()
        .filter(|(_, o)| *o != rootplc_driver::mutate::Outcome::NotViable)
        .count();
    let killed = mine
        .iter()
        .filter(|(_, o)| *o == rootplc_driver::mutate::Outcome::Killed)
        .count();
    assert!(viable > 0, "no viable mutants in the library");
    let score = killed as f64 / viable as f64;
    eprintln!("RootBlocks mutation score: {killed} of {viable} library mutants killed");
    let survivors: Vec<String> = m
        .survivors()
        .filter(|s| lib(&s.path))
        .map(|s| {
            format!(
                "{}:{} {} -> {}",
                s.path.display(),
                s.line,
                s.original,
                s.replacement
            )
        })
        .collect();
    assert!(
        score >= 0.9,
        "mutation score {:.0}%: {survivors:?}",
        score * 100.0
    );
}

/// The bundled library passes every check user code gets: library sources
/// are loaded without diagnostics, so a reserved word or a name clash
/// (e.g. an output `Min` hiding `MIN()`) would otherwise only show up as a
/// VM fault at run time.
#[test]
fn library_passes_the_checker_as_user_code() {
    let check = rootplc_driver::check_sources_with(library_sources(), &[]).expect("check");
    for f in &check.files {
        assert!(
            f.diagnostics.is_empty(),
            "{}: {:?}",
            f.path.display(),
            f.diagnostics
        );
    }
    assert!(check.ok());
}

/// The libraries a template uses, as its sources name them
/// (`--library RootBlocks --library RootMotion`); RootBlocks always.
fn template_libraries(sources: &[(PathBuf, String)]) -> Vec<String> {
    let mut libs = vec!["RootBlocks".to_string()];
    for (_, text) in sources {
        for part in text.split("--library").skip(1) {
            let name: String = part
                .trim_start()
                .chars()
                .take_while(|c| c.is_ascii_alphanumeric() || *c == '_')
                .collect();
            if !name.is_empty() && !libs.contains(&name) {
                libs.push(name);
            }
        }
    }
    libs
}

/// L4 templates (blocks/templates/<name>/): they compile with RootBlocks
/// and the libraries they name (warnings only in their test files), their
/// tests pass, and the tests kill at least 70% of the mutants of the
/// template's logic (the I/O map `io_map.st` is wiring and is checked on
/// the runtime instead).
#[test]
fn templates_compile_pass_and_are_mutation_tested() {
    let Ok(dirs) = std::fs::read_dir(repo().join("blocks/templates")) else {
        return;
    };
    let mut seen = 0;
    for d in dirs.flatten().filter(|d| d.path().is_dir()) {
        seen += 1;
        let name = d.file_name().to_string_lossy().to_string();
        let all = rootplc_driver::read_sources(&[d.path()]).expect("template sources");
        let libs = template_libraries(&all);
        let is_test = |p: &std::path::Path| p.components().any(|c| c.as_os_str() == "tests");
        let check = rootplc_driver::check_sources_with(all.clone(), &libs).expect("check");
        assert!(check.ok(), "{name}: does not compile");
        for f in check
            .files
            .iter()
            .filter(|f| !f.library && !is_test(&f.path))
        {
            assert!(
                f.diagnostics.is_empty(),
                "{name}: {} has diagnostics",
                f.path.display()
            );
        }
        let report = rootplc_driver::test_report(check, None);
        assert!(
            !report.outcomes.is_empty() && report.ok(),
            "{name}: tests fail"
        );
        let logic: Vec<_> = all
            .into_iter()
            .filter(|(p, _)| p.file_name().is_none_or(|n| n != "io_map.st"))
            .collect();
        let m =
            rootplc_driver::mutate::mutation_report(logic, &libs, None, 10_000).expect("mutate");
        assert_eq!(
            m.mutants.len(),
            m.candidates,
            "{name}: mutation run truncated"
        );
        let mine: Vec<_> = m
            .mutants
            .iter()
            .filter(|(mu, _)| !is_test(&mu.path))
            .collect();
        let viable = mine
            .iter()
            .filter(|(_, o)| *o != rootplc_driver::mutate::Outcome::NotViable)
            .count();
        let killed = mine
            .iter()
            .filter(|(_, o)| *o == rootplc_driver::mutate::Outcome::Killed)
            .count();
        eprintln!("template {name}: {killed} of {viable} mutants killed");
        assert!(
            viable > 0 && killed * 10 >= viable * 7,
            "{name}: {killed} of {viable}"
        );
    }
    assert!(seen > 0, "no templates found");
}
