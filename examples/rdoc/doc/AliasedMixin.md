---
type: Ruby Module
title: AliasedMixin
description: "Exercises a constant alias that a signature file redeclares as a module."
---

# module AliasedMixin

- **Defined in:** `examples/rdoc/lib/aliased_mixin.rb`

Exercises a constant alias that a signature file redeclares as a module.

YARD's RBS handler records the constant alias itself as a mixin of `Host`, alongside the module that later replaces it. The `Includes` and `Extends` lines and the member roster must show `Filtering` once, as the module, and must not fail on the stale constant. The shape comes from `OAuth2::FilteredAttributes` in the `oauth2` gem.

## Member Summary

**Nested Classes & Modules**

- [`Filtering`](AliasedMixin/Filtering.md) — Removes secrets from text.
- [`Host`](AliasedMixin/Host.md) — Includes and extends the aliased mixin.
