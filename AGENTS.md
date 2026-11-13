# A Runwell plugin — guide for AI agents

This repository is a plugin for Runwell (a Rails 8.1 engine loaded into a Runwell install). It is
not an app on its own: run it from a Runwell checkout with `bin/rails "plugins:link[path]"`.

Read first, in Runwell's repository:
- `docs/plugin-contract.md`: everything a plugin may rely on, with versions. Use nothing else of
  the core's. Raise `requires:` in the manifest to the newest version you use.
- `AGENTS.md`: the core's conventions, which plugin code follows too.

## Rules

- Own your tables, prefixed with the key (`ads_*`), pointing at core records by id. Never
  add columns to core tables or write core rows except through core model verbs.
- Register everything in `config.to_prepare`, keyed by the plugin's key. Controllers inherit
  `Ads::ApplicationController` (404 while switched off); subscribers check
  `Runwell::Plugins.enabled?(:ads)`.
- Every controller action declares an authorization rule (`allow_staff`, `require_permission`)
  and an `agent_tool` or `agent_exempt`. Reads get a `.json.jbuilder` view with `agent_ref` and a
  `summary`. Write notices an AI can act on.
- Views follow the core's ReActionView rules: strict locals on every partial's first line,
  `<%# herb:key %>` before each loop row, no inline CSS, no partials inside `form_with`. Use the
  core's helpers and shared partials (listed in the contract) and `term()` for the core's nouns.
- Views draw with runeui, Runwell 6.0's UI kit: `ui :card`, `ui :table`, `ui :badge`, `ui :alert`,
  `ui :button` (or `class: "ui-button"` with `data-variant`/`data-size` on `button_to`), and
  `form.ui :field` around each control (its errors come from the record). No rune_ui helpers or classes.
- CSS reads runeui's tokens only (shadcn's names: `--foreground`, `--muted-foreground`, `--border`,
  `--primary` for the brand, `--destructive`…; runeui's `--ui-*` scale; `docs/theming.md`), never
  rune_ui's old names (`--text-*`, `--line`, `--s-*`, `--accent` as the brand). Spacing in rems.
- Migrations are safe on a live install: add in one release, remove only in a later one.
- Use only gems Runwell bundles: plugins load outside Bundler.
- JavaScript is the plugin's own, in `app/javascript/ads/`: Stimulus controllers in
  `controllers/` (the core registers them as `ads--name`; it has none yet,
  modules imported as `"ads/…"`. Import only `@hotwired/stimulus`,
  `@hotwired/turbo-rails`, `@rails/request.js` and your own files; use only the core controllers
  the contract lists; never patch the core's. No inline scripts, no CDNs (vendor a library into
  `app/javascript/ads/vendor/`). Everything still works for agents, which run no JavaScript.
- Keep it in the plugin: ask the core only for a real extension point, documented in the contract.
- Write for anyone running something (a business, a team, a household): never one industry's jargon.

## Layout

- `lib/ads/engine.rb`: routes, model hooks, event subscriber, registrations
- `app/`: models, controllers, views, stylesheets and JavaScript under `ads/`
- `db/migrate/`: the plugin's tables

## This plugin

- A plan is a piece of work tagged as an ad service (`Ads::Plan::KINDS`: ppc). Its cost is kept
  current: `Ads::Statement` per month, running (refreshed nightly by `RefreshJob` and on request by
  `RefreshPlanJob`), final on the run day (`Setting#final?`), then invoiced or skipped only while
  invoicing is on. Verbs refuse what the state doesn't allow (`Statement::Refused`); views and tools
  ask the predicates (`refreshable?`, `invoiceable?`…).
- `Ads::Terms` is the fee rule (greater_of, flat, percent). Money is integer cents; a share of spend is
  a decimal percent (20 for 20%).
- LuminAds and QuickBooks are called only from jobs and, cached for ten minutes, for the form's
  pickers (`Ads::Directory`).
- Invoicing is off by default. The only write to QuickBooks is `QuickbooksApi#create_invoice`, unsent.
  Keep it that way unless sending is asked for: that reaches the client and needs `confirm:` on its tool.
