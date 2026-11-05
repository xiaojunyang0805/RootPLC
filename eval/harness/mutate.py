"""Mutation testing for Structured Text (prototype of `rootplc test --mutate`, WP C5).

A mutant changes one token of the program: a comparison, a logical or
arithmetic operator, a boolean or integer literal, a duration (doubled), or
drops a NOT. A mutant
is *killed* when the tests fail on it (an assertion fails, a fault occurs, or
the code no longer compiles counts as "not viable" and is skipped).
Mutation score = killed / viable mutants.
"""
from __future__ import annotations

import re
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

from bench import run_rootplc

# Tokens: comments and strings are kept intact; literals with '#' are one token.
TOKEN = re.compile(
    r"""(?P<comment>\(\*.*?\*\)|/\*.*?\*/|//[^\n]*)
      |(?P<string>'(?:\$.|[^'$])*'|"(?:\$.|[^"$])*")
      |(?P<typed>[A-Za-z_][A-Za-z0-9_]*\#[A-Za-z0-9_.:+\-\#]+)
      |(?P<number>\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?)
      |(?P<word>[A-Za-z_][A-Za-z0-9_]*)
      |(?P<op>:=|=>|<=|>=|<>|\*\*|\.\.|[-+*/<>=&()\[\];:,.^\#%])
      |(?P<ws>\s+)
      |(?P<other>.)""",
    re.S | re.X,
)

DURATION = re.compile(r"^(T|TIME|LT|LTIME)#(\d+)([A-Za-z]+)$", re.I)

SWAP = {"<": "<=", "<=": "<", ">": ">=", ">=": ">", "=": "<>", "<>": "=", "+": "-", "-": "+",
        "AND": "OR", "OR": "AND", "XOR": "OR", "TRUE": "FALSE", "FALSE": "TRUE"}


@dataclass
class Mutant:
    file: Path
    offset: int
    original: str
    replacement: str

    def describe(self, text: str) -> str:
        line = text.count("\n", 0, self.offset) + 1
        return f"{self.file.name}:{line}: {self.original!r} -> {self.replacement!r}"


def mutants_of(path: Path) -> list[Mutant]:
    text = path.read_text(encoding="utf-8")
    out = []
    in_decl = False
    prev_sig = ""
    for m in TOKEN.finditer(text):
        kind, tok = m.lastgroup, m.group()
        up = tok.upper()
        if kind == "word" and up.startswith("VAR"):
            in_decl = True
        elif kind == "word" and up == "END_VAR":
            in_decl = False
        if kind in ("comment", "string", "ws"):
            continue
        if not in_decl:
            key = up if kind == "word" else tok
            if kind in ("op", "word") and key in SWAP:
                # unary minus after an operator or '(' stays unary
                if not (tok == "-" and prev_sig in ("(", ":=", ",", "", "THEN", "ELSE")):
                    out.append(Mutant(path, m.start(), tok, SWAP[key]))
            elif kind == "word" and up == "NOT":
                out.append(Mutant(path, m.start(), tok, ""))
            elif kind == "typed" and DURATION.match(tok):
                d = DURATION.match(tok)
                out.append(Mutant(path, m.start(), tok, f"{d.group(1)}#{int(d.group(2)) * 2}{d.group(3)}"))
            elif kind == "number" and "." not in tok:
                n = int(tok.replace("_", ""))
                out.append(Mutant(path, m.start(), tok, str(n + 1)))
        prev_sig = up if kind == "word" else tok
    return out


@dataclass
class MutationResult:
    viable: int
    killed: int
    survivors: list[str]

    @property
    def score(self) -> float:
        return self.killed / self.viable if self.viable else 0.0


def mutation_score(src: list[Path], tests: list[Path], limit: int = 200,
                   extra_args: list[str] | None = None) -> MutationResult:
    """Mutate each file in `src` once per mutant; run `tests` against it."""
    base = Path(tempfile.mkdtemp(prefix="plcmut-"))
    try:
        names = {}
        for i, f in enumerate(src + tests):
            dst = base / f"{i:02d}_{f.name}"
            shutil.copyfile(f, dst)
            names[f] = dst
        files = [str(names[f]) for f in src + tests]
        extra = extra_args or []
        if not run_rootplc(["test", *files, *extra], timeout=300).get("ok"):
            return MutationResult(0, 0, ["tests do not pass on the original"])
        viable = killed = 0
        survivors = []
        for f in src:
            text = f.read_text(encoding="utf-8")
            for mu in mutants_of(f)[:limit]:
                mutated = text[: mu.offset] + mu.replacement + text[mu.offset + len(mu.original):]
                names[f].write_text(mutated, encoding="utf-8")
                rep = run_rootplc(["test", *files, *extra], timeout=300)
                names[f].write_text(text, encoding="utf-8")
                if not rep.get("compiled", rep.get("ok", False)):
                    continue  # not viable
                viable += 1
                if rep.get("ok"):
                    survivors.append(mu.describe(text))
                else:
                    killed += 1
        return MutationResult(viable, killed, survivors)
    finally:
        shutil.rmtree(base, ignore_errors=True)
