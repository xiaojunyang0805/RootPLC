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
        rootplc_driver::mutate::mutation_report(sources, &[], None, 1000).expect("mutation run");
    assert!(m.baseline.ok(), "block tests fail");
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
