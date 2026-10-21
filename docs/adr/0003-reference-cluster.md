# ADR 0003 — Reference Cluster Overlay

**Date:** 2025-01-23
**Status:** Accepted

## Context

We need a template that users can copy for their real clusters. But we don't want to ship
a real cluster's configuration (which might contain sensitive or environment-specific values).

## Decision

Ship `overlay/clusters/reference/` as a **reference** cluster with placeholder values. Users
copy it to `overlay/clusters/<their-cluster>/` and fill in real values.

## Consequences

- **Positive:** Clear starting point; validates the overlay structure; no real secrets in git.
- **Negative:** Users might accidentally apply the reference overlay.
- **Mitigation:** The reference cluster's values are clearly labeled as examples; `.env.example` (not `.env`) is committed; real `.env` is gitignored.
