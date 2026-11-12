# Ad fees, a Runwell plugin

A monthly management fee on ad spend: **a minimum or a share of what was spent, whichever is
greater** ($1,000 or 20% by default), worked out from [LuminAds](https://luminads.com) each month
and drafted as a QuickBooks invoice for someone to check and send.

## How it works

1. **Settings › Plugins › Ad fees**: the default terms, the day each month last month's fees are
   worked out (the 3rd: ad platforms settle late), who reviews them, the QuickBooks product or
   service on the line, LuminAds' address and an API token, and the business's Intuit app (its
   redirect URI is `/ad-fees/authorization` on your Runwell).
2. **A piece of work's Ad fees tab** (any kind: a service, a project, a work order): which LuminAds
   accounts are its spend, which QuickBooks customer is billed, and any terms of its own. Blank
   terms follow the defaults; a client on other terms gets a flat fee, a share only, or other numbers.
3. **Each month**, on the run day, every active plan gets a statement: the spend LuminAds reports for
   the month before, the terms used, the fee and why. Its invoice is created in QuickBooks **unsent**,
   and a task on the work asks the reviewer (or Intake) to check it and send it from QuickBooks.
4. **Ad fees in the nav** lists every month, by month and state, with anything that couldn't be
   worked out. Owners see the total of the listed fees by hovering over the Fee header.

Nothing is sent to a client: the draft waits in QuickBooks until someone sends it there.

## Agent tools

`show_ad_fee_settings`, `update_ad_fee_settings`, `list_ad_fee_choices`, `show_ad_fee_plan`,
`set_ad_fee_plan`, `remove_ad_fee_plan`, `calculate_ad_fees`, `list_ad_fee_statements`,
`draft_ad_fee_invoice`, `recalculate_ad_fee`, `skip_ad_fee`, `restore_ad_fee`. The keys to LuminAds
and QuickBooks are entered in the browser only.

## Develop

From a Runwell checkout beside it: `bin/rails "plugins:link[../runwell-ad-fees]"`,
`bin/rails db:migrate`, `bin/dev`, then switch it on in Settings › Plugins.

## Release

Bump `lib/ad_fees/version.rb`, commit, then `git tag v0.2.0 && git push --tags`.
