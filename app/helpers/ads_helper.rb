# The Ads plugin's view helpers.
module AdsHelper
  # Each state's badge (ui :badge's variants): a running month in the info tone, a settled one
  # outlined, a drafted one green, a skipped one quiet; drafting in the warning tone.
  ADS_VARIANTS = { "running" => :info, "final" => :outline, "invoiced" => :success, "skipped" => :secondary }.freeze
  ADS_STATE_LABELS = { "running" => "So far", "final" => "Final", "invoiced" => "Drafted", "skipped" => "Skipped" }.freeze

  def ads_state_tag(statement)
    label = statement.invoicing? ? "Drafting…" : ADS_STATE_LABELS[statement.state]
    tip = statement.running? ? "Spend through #{statement.through_on.strftime("%b %-d")}, read #{time_ago_in_words(statement.refreshed_at)} ago" : nil
    ui :badge, content: label, variant: statement.invoicing? ? :warning : ADS_VARIANTS[statement.state], title: tip
  end

  def ads_percent(value) = Ads::Terms.percent_label(value)

  # The Fee column's header. For owners it carries the whole total of the rows listed as its tooltip
  # (title, so it shows on hover and is read out), not printed on the page; everyone else sees the
  # plain header. unit names a row ("service", "month").
  def ads_amount_header(label, statements, unit:)
    return label unless Current.user&.owner?

    counted = statements.reject(&:skipped?)
    tip = "Total: #{money(counted.sum(&:fee_cents))} across #{counted.size} #{unit.pluralize(counted.size)}" \
      "#{" (skipped left out)" if counted.size < statements.size}, on #{money(counted.sum(&:spend_cents))} of ad spend"
    if counted.any?(&:partial?)
      tip += ". Heading for #{money(counted.sum(&:projected_fee_cents))} at this pace"
    end
    tag.span(label, title: tip, class: "ads-total", tabindex: 0, aria: { description: tip })
  end

  # A QuickBooks invoice, linked to where it's checked and sent.
  def ads_invoice_link(statement)
    return if statement.invoice_qbo_id.blank?

    connection = Ads::QuickbooksConnection.current
    label = "Invoice #{statement.invoice_doc_number.presence || statement.invoice_qbo_id}"
    connection ? link_to(label, connection.invoice_url(statement.invoice_qbo_id), target: "_blank", rel: "noopener") : label
  end
end
