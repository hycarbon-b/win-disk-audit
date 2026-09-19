# Standard report format

Use this format for every user-facing audit so reports remain comparable across machines and over time.

## Terminology

| Term | Meaning |
|---|---|
| Logical size | Sum of file lengths visible to software; may overstate local use for sparse/cloud-placeholder files. |
| Allocated size | Bytes currently allocated on the Windows filesystem. |
| Internal used | Space used inside a filesystem container, such as `df` inside WSL. |
| Reclaim estimate | Candidate space; not guaranteed until cleanup and, for VHDX, compaction complete. |
| Confidence | `measured`, `estimated`, or `upper bound`. |

## Required structure

```markdown
# Windows Developer Disk Usage Audit

Generated: YYYY-MM-DD HH:mm:ss Z
Scope: C:, Windows profile, WSL, VS Code, Codex, Claude Code
Mode: Fast | Full

## Executive summary

| Metric | Value |
|---|---:|
| Drive capacity | ... |
| Used | ... |
| Free | ... |
| Used percent | ... |
| High-confidence reclaim candidate | ... |

One short paragraph that identifies the actual cause. Explicitly say whether WSL swap is or is not material.

## Largest consumers

| Rank | Category | Path/item | Size | Size basis | Confidence |
|---:|---|---|---:|---|---|

Do not sum overlapping rows.

## Reclaim opportunities

| Priority | Candidate | Estimated reclaim | Risk | Consequence |
|---:|---|---:|---|---|

## WSL analysis

- VHDX allocated size
- Linux internal usage, when inspected
- Active swap size and usage, when inspected
- Docker reclaimability, when inspected
- Whether VHDX compaction is required

## Developer tooling footprint

| Tool | Path | Size | Classification | Notes |
|---|---|---:|---|---|

## Recommended action order

1. Lowest-risk, high-return action.
2. Next action.
3. Stateful or system action last.

## Commands requiring approval

List proposed commands but state that none were executed. Omit destructive commands when exact targets are unknown.

## Limitations and scan coverage

- Access-denied locations
- Logical-versus-allocated limitations
- Whether stopped WSL distributions were started
- Whether Docker runtime data was available
- Whether administrator-only data was unavailable
```

## Risk labels

| Label | Meaning |
|---|---|
| Low | Rebuildable cache or disposable temporary data; may cause re-download/rebuild. |
| Medium | Usually recoverable, but can remove useful state or require substantial downloads. |
| High | System-managed or stateful data; changing it can disrupt applications or boot/runtime behavior. |
