set shell := ["bash", "-euo", "pipefail", "-c"]

# Lists the source and native verification commands.
default:
    @just --list

# Checks authored sources, formatting, workflows and the exact secret scope.
check base="" head="":
    just --fmt --check
    cargo fmt --all --check
    python tools/check_ci_source.py
    actionlint
    zizmor --offline --no-progress .github
    python tools/check_secrets.py {{ quote(base) }} {{ quote(head) }}

# Formats command declarations and Rust sources.
fix:
    just --fmt
    cargo fmt --all

# Retains Clippy, build, crate projection self-check and native Rust tests.
test:
    python tools/with_libclang.py cargo clippy --locked --all-targets -- -D warnings
    just build
    python tools/with_libclang.py python tools/build_crates_io.py --self-check
    just ci-test

# Builds every target with the selected compiler and existing libclang prerequisite.
build:
    python tools/with_libclang.py cargo build --locked --all-targets

# Verifies the Unix native profile; CI also selects Windows tests and MSRV.
verify: check test ci-supply ci-boundary

# Retains the original Linux Rust role.
[group("ci")]
ci-rust:
    cargo fmt --all --check
    just test

# Runs the existing native Rust suite on the selected executor.
[group("ci")]
ci-test:
    python tools/with_libclang.py cargo test --locked --all-targets

# Retains all existing dependency, license, advisory and unused-dependency gates.
[group("ci")]
ci-supply:
    cargo-deny --version
    cargo-audit --version
    cargo-machete --version
    cargo deny --all-features check bans licenses advisories sources
    cargo audit
    cargo-machete

# Measures the freshly built provider imports without a restored build cache.
[group("ci")]
ci-boundary:
    python tools/with_libclang.py cargo build --locked --release
    bash tools/check_boundary.sh

# Checks with the minimum compiler selected by CI from Cargo.toml.
[group("ci")]
ci-msrv:
    python tools/with_libclang.py cargo check --locked --all-targets

# Retains the original native OSV source scan and its failing outcomes.
[group("ci")]
ci-osv:
    osv-scanner --version
    osv-scanner scan source --recursive .
