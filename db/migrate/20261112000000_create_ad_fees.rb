# Ad fees, as a plugin. Every table is the plugin's own (ad_fees_*), pointing at core records by id.
#
# - settings: one row. Where LuminAds is and its token, the default terms (whichever is greater of a
#   minimum and a share of spend), the day of the month the fees are worked out, who reviews them and the QuickBooks product or
#   service the invoice line uses.
# - quickbooks_connections: one row. The Intuit app and the QuickBooks company it signed in to.
# - plans: one per piece of work with an ad fee. Which LuminAds accounts are its spend, which
#   QuickBooks customer is billed, and any terms of its own (blank: the defaults).
# - statements: one per plan per month. The spend read, the terms used, the fee and why (the minimum or
#   the share), and the QuickBooks invoice drafted from it.
class CreateAdFees < ActiveRecord::Migration[8.1]
  def change
    create_table :ad_fees_settings do |t|
      t.string :luminads_url
      t.text :luminads_token
      t.string :default_rule, null: false, default: "greater_of"
      t.integer :default_minimum_cents, null: false, default: 100_000
      t.decimal :default_percent, precision: 6, scale: 2, null: false, default: 20
      t.integer :run_on_day, null: false, default: 3
      t.boolean :draft_invoices, null: false, default: true
      t.integer :reviewer_id
      t.string :quickbooks_item_id
      t.string :quickbooks_item_name
      t.timestamps
    end

    create_table :ad_fees_quickbooks_connections do |t|
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

    create_table :ad_fees_plans do |t|
      t.integer :work_id, null: false
      t.integer :client_id, null: false
      t.json :luminads_accounts, null: false, default: []
      t.string :quickbooks_customer_id
      t.string :quickbooks_customer_name
      t.string :rule
      t.integer :minimum_cents
      t.decimal :percent, precision: 6, scale: 2
      t.date :starts_on, null: false
      t.boolean :active, null: false, default: true
      t.integer :reviewer_id
      t.text :last_error
      t.timestamps
    end
    add_index :ad_fees_plans, :work_id, unique: true
    add_index :ad_fees_plans, :client_id

    create_table :ad_fees_statements do |t|
      t.integer :plan_id, null: false
      t.integer :work_id, null: false
      t.integer :client_id, null: false
      t.date :period_on, null: false
      t.string :state, null: false, default: "calculated"
      t.integer :spend_cents, null: false, default: 0
      t.json :spend_detail, null: false, default: []
      t.string :rule, null: false
      t.integer :minimum_cents, null: false
      t.decimal :percent, precision: 6, scale: 2, null: false
      t.integer :fee_cents, null: false
      t.string :basis, null: false
      t.datetime :calculated_at, null: false
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
    add_index :ad_fees_statements, %i[plan_id period_on], unique: true
    add_index :ad_fees_statements, :period_on
    add_index :ad_fees_statements, :work_id
    add_index :ad_fees_statements, :task_id
  end
end
