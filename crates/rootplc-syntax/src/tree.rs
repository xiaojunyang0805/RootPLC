//! Lossless concrete syntax tree, [syntax.lossless].
//!
//! A [`Node`] holds child nodes and token indices in source order. Every token
//! the lexer produced, trivia included, appears exactly once in the tree, so
//! printing the tree returns the exact source.

use crate::token::Token;

/// Kind of a syntax-tree node.
#[allow(missing_docs)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NodeKind {
    SourceFile,
    Program,
    Function,
    FunctionBlock,
    Test,
    TypeBlock,
    TypeDecl,
    VarSection,
    VarDecl,
    TypeSpec,
    StructType,
    EnumType,
    EnumValue,
    ArrayType,
    ArrayDim,
    Initializer,
    ArrayInit,
    StructInit,
    StmtList,
    AssignStmt,
    CallStmt,
    IfStmt,
    CaseStmt,
    CaseElement,
    ForStmt,
    WhileStmt,
    RepeatStmt,
    ExitStmt,
    ContinueStmt,
    ReturnStmt,
    EmptyStmt,
    BinExpr,
    UnaryExpr,
    ParenExpr,
    Literal,
    NameRef,
    MemberExpr,
    IndexExpr,
    DerefExpr,
    CallExpr,
    ArgList,
    Arg,
    RefExpr,
    /// Tokens skipped during error recovery, [syntax.recovery].
    Error,
}

/// A child of a node: another node or the index of a token.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Element {
    /// A child node.
    Node(Node),
    /// Index into the token vector.
    Token(usize),
}

/// A syntax-tree node.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Node {
    /// Kind.
    pub kind: NodeKind,
    /// Children in source order.
    pub children: Vec<Element>,
}

impl Node {
    /// Reconstruct the exact source text covered by this node.
    pub fn text(&self, tokens: &[Token], source: &str) -> String {
        let mut out = String::new();
        self.write_text(tokens, source, &mut out);
        out
    }

    fn write_text(&self, tokens: &[Token], source: &str, out: &mut String) {
        for c in &self.children {
            match c {
                Element::Node(n) => n.write_text(tokens, source, out),
                Element::Token(i) => out.push_str(tokens[*i].text(source)),
            }
        }
    }

    /// Child nodes of a given kind.
    pub fn nodes(&self, kind: NodeKind) -> impl Iterator<Item = &Node> {
        self.children.iter().filter_map(move |c| match c {
            Element::Node(n) if n.kind == kind => Some(n),
            _ => None,
        })
    }

    /// Count nodes of a kind in the whole subtree (including this node).
    pub fn count(&self, kind: NodeKind) -> usize {
        let own = usize::from(self.kind == kind);
        own + self
            .children
            .iter()
            .map(|c| match c {
                Element::Node(n) => n.count(kind),
                Element::Token(_) => 0,
            })
            .sum::<usize>()
    }
}

/// Builds a tree with a stack of open nodes.
#[derive(Debug, Default)]
pub(crate) struct Builder {
    stack: Vec<Node>,
}

impl Builder {
    pub(crate) fn start(&mut self, kind: NodeKind) {
        self.stack.push(Node {
            kind,
            children: Vec::new(),
        });
    }

    /// Position for a later [`Builder::start_at`].
    pub(crate) fn checkpoint(&self) -> usize {
        self.stack.last().map_or(0, |n| n.children.len())
    }

    /// Open a node that adopts the children added since `checkpoint`.
    pub(crate) fn start_at(&mut self, checkpoint: usize, kind: NodeKind) {
        let adopted = match self.stack.last_mut() {
            Some(top) => top.children.split_off(checkpoint.min(top.children.len())),
            None => Vec::new(),
        };
        self.stack.push(Node {
            kind,
            children: adopted,
        });
    }

    pub(crate) fn finish(&mut self) {
        if self.stack.len() > 1 {
            if let Some(done) = self.stack.pop() {
                if let Some(parent) = self.stack.last_mut() {
                    parent.children.push(Element::Node(done));
                }
            }
        }
    }

    pub(crate) fn token(&mut self, index: usize) {
        if let Some(top) = self.stack.last_mut() {
            top.children.push(Element::Token(index));
        }
    }

    pub(crate) fn into_root(mut self) -> Node {
        while self.stack.len() > 1 {
            self.finish();
        }
        self.stack.pop().unwrap_or(Node {
            kind: NodeKind::SourceFile,
            children: Vec::new(),
        })
    }
}
