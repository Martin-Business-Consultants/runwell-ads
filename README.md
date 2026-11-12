# Ads, a Runwell plugin

What each ad service costs, kept current. Tag a piece of work as **PPC**, link its
[LuminAds](https://luminads.com) accounts, and its Ads tab shows this month so far: ad spend, the
management fee it comes to, and where the month is heading at its pace. The fee is **a minimum or a
share of spend, whichever is greater** ($1,000 or 20% by default), and each service may have its own.

Invoicing (unsent QuickBooks drafts) is built in and **off** until you switch it on.

## How it works

1. **Settings › Plugins › Ads**: the default fee, the day each month last month becomes final (the
   3rd: ad platforms settle late), and LuminAds' address with an API token.
2. **A piece of work's Ads tab** (a service, project or work order): **Tag as PPC**, pick its LuminAds
   accounts, and give it its own fee if it's on different terms. Tagged work shows a PPC badge under
   its title.
3. **Every night** each active service's month so far is read again from LuminAds (and last month,
   until it's final). **Refresh now** reads it on the spot.
4. **Ads in the nav** lists every service's figure for a month, this month by default. Owners see the
   total of the listed fees, and where they're heading, by hovering over the Fee header.

### Invoicing, when you're ready

Switch on **Draft invoices in QuickBooks** in Settings › Plugins › Ads, connect QuickBooks there (your
own Intuit app; its redirect URI is `/ads/authorization` on your Runwell), choose the product or
service for the line, and pick each service's QuickBooks customer. Each final month is then created in
QuickBooks **unsent**, with a task for someone to check it and send it there. Nothing is ever sent to a
client from Runwell.

## Agent tools

`show_ads_settings`, `update_ads_settings`, `list_ads_choices`, `show_ppc_service`,
`tag_ppc_service`, `untag_ppc_service`, `refresh_ad_costs`, `list_ad_costs`, and while invoicing is on
`draft_ad_invoice`, `skip_ad_month`, `restore_ad_month`. The keys to LuminAds and QuickBooks are
entered in the browser only.

## Develop

From a Runwell checkout beside it: `bin/rails "plugins:link[../runwell-ads]"`, `bin/rails db:migrate`,
`bin/dev`, then switch it on in Settings › Plugins.

## Release

Bump `lib/ads/version.rb`, commit, then `git tag v0.3.0 && git push --tags`.
