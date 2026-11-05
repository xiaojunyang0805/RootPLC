//! `TEST ... END_TEST` blocks: discovery, runner and results
//! (spec/07-test-blocks.md).
//!
//! Roadmap phase: 1. See `ARCHITECTURE.md`. Each TEST block runs once on a
//! fresh virtual machine; assertions record failures and execution continues;
//! a fault ends the test.

use rootplc_sema::ir::Program;
use rootplc_vm::{AssertFailure, AxisStats, Fault, Vm};

/// Result of one TEST block.
#[derive(Debug, Clone)]
pub struct TestOutcome {
    /// Name of the TEST block.
    pub name: String,
    /// Index of its source file.
    pub file: usize,
    /// Failed assertions.
    pub failures: Vec<AssertFailure>,
    /// Fault that ended the test, if any.
    pub fault: Option<Fault>,
    /// Axes RootMotion moved during the test, [motion.observe].
    pub axes: Vec<AxisStats>,
}

impl TestOutcome {
    /// Passed: no failed assertion and no fault.
    pub fn passed(&self) -> bool {
        self.failures.is_empty() && self.fault.is_none()
    }
}

/// Run one TEST block (definition index).
pub fn run_test(prog: &Program, def: usize) -> TestOutcome {
    let mut vm = Vm::new(prog);
    let root = vm.instantiate(def);
    let fault = vm.cycle(root, def).err();
    TestOutcome {
        name: prog.defs[def].name.clone(),
        file: prog.defs[def].file,
        failures: vm.failures,
        fault,
        axes: vm.axes,
    }
}

/// Run every TEST block, optionally only those whose name contains `filter`.
pub fn run_tests(prog: &Program, filter: Option<&str>) -> Vec<TestOutcome> {
    prog.tests()
        .into_iter()
        .filter(|&t| {
            filter.is_none_or(|f| {
                prog.defs[t]
                    .name
                    .to_ascii_lowercase()
                    .contains(&f.to_ascii_lowercase())
            })
        })
        .map(|t| run_test(prog, t))
        .collect()
}
