# Ads, as a plugin. Every table is the plugin's own (ads_*), pointing at core records by id.
#
# - settings: one row. Where LuminAds is and its token, the default fee terms (whichever is greater
#   of a minimum and a share of spend), the day of the month last month's figure is final, and
#   invoicing (off until switched on): who reviews drafts and the QuickBooks product on the line.
# - quickbooks_connections: one row. The Intuit app and the QuickBooks company it signed in to;
#   used only while invoicing is on.
# - plans: one per piece of work tagged as an ad service (kind: ppc). Which LuminAds accounts are
#   its spend, any fee terms of its own (blank: the defaults), and the QuickBooks customer billed.
# - statements: one per plan per month. Spend so far (through_on) and the fee it comes to: running
#   while the month is open, refreshed nightly; final once the month has settled; then invoiced or
#   skipped while invoicing is on.
class CreateAds < ActiveRecord::Migration[8.1]
  def change
    create_table :ads_settings do |t|
      t.string :luminads_url
      t.text :luminads_token
      t.string :default_rule, null: false, default: "greater_of"
      t.integer :default_minimum_cents, null: false, default: 100_000
      t.decimal :default_percent, precision: 6, scale: 2, null: false, default: 20
      t.integer :run_on_day, null: false, default: 3
      t.boolean :invoicing, null: false, default: false
      t.integer :reviewer_id
      t.string :quickbooks_item_id
      t.string :quickbooks_item_name
      t.timestamps
    end

    create_table :ads_quickbooks_connections do |t|
      t.string :client_id
      t.text :client_secret
      t.string :environment, null: false, default: "production"
      t.string :realm_id
      t.string :company_name
      t.text :access_token
      t.text :refresh_token
      t.datetime :access_expires_at
      t.datetime :refresh_expires_at
      t.string :oauth_state
      t.datetime :connected_at
      t.text :last_error
      t.timestamps
    end

    create_table :ads_plans do |t|
      t.integer :work_id, null: false
      t.integer :client_id, null: false
      t.string :kind, null: false, default: "ppc"
      t.json :luminads_accounts, null: false, default: []
      t.string :rule
      t.integer :minimum_cents
      t.decimal :percent, precision: 6, scale: 2
      t.date :starts_on, null: false
      t.boolean :active, null: false, default: true
      t.string :quickbooks_customer_id
      t.string :quickbooks_customer_name
      t.integer :reviewer_id
      t.text :last_error
      t.timestamps
    end
    add_index :ads_plans, :work_id, unique: true
    add_index :ads_plans, :client_id

    create_table :ads_statements do |t|
      t.integer :plan_id, null: false
      t.integer :work_id, null: false
      t.integer :client_id, null: false
      t.date :period_on, null: false
      t.date :through_on, null: false
      t.string :state, null: false, default: "running"
      t.integer :spend_cents, null: false, default: 0
      t.json :spend_detail, null: false, default: []
      t.string :rule, null: false
      t.integer :minimum_cents, null: false
      t.decimal :percent, precision: 6, scale: 2, null: false
      t.integer :fee_cents, null: false
      t.string :basis, null: false
      t.datetime :refreshed_at, null: false
      t.integer :task_id
      t.datetime :invoice_requested_at
      t.string :invoice_qbo_id
      t.string :invoice_doc_number
      t.datetime :invoiced_at
      t.integer :invoiced_by_id
      t.datetime :skipped_at
      t.integer :skipped_by_id
      t.string :skip_reason
      t.text :last_error
      t.timestamps
    end
    add_index :ads_statements, %i[plan_id period_on], unique: true
    add_index :ads_statements, :period_on
    add_index :ads_statements, :work_id
    add_index :ads_statements, :task_id
  end
end
