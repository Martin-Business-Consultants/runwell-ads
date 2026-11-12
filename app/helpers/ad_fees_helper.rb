# Ad fees' view helpers.
module AdFeesHelper
  AD_FEES_TONES = { "calculated" => :attention, "invoiced" => :ok, "skipped" => :neutral }.freeze
  AD_FEES_STATE_LABELS = { "calculated" => "To draft", "invoiced" => "Drafted", "skipped" => "Skipped" }.freeze

  def ad_fees_state_tag(statement)
    label = statement.invoicing? ? "Drafting…" : AD_FEES_STATE_LABELS[statement.state]
    badge(statement.state, label, tone: statement.invoicing? ? :busy : AD_FEES_TONES[statement.state])
  end

  def ad_fees_percent(value) = AdFees::Terms.percent_label(value)

  # The Fee column's header. For owners it carries the whole total of the rows listed as its tooltip
  # (title, so it shows on hover and is read out), not printed on the page; everyone else sees the
  # plain header.
  def ad_fees_amount_header(label, statements)
    return label unless Current.user&.owner?

    billed = statements.reject(&:skipped?)
    total = billed.sum(&:fee_cents)
    tip = "Total: #{money(total)} across #{billed.size} #{"month".pluralize(billed.size)}" \
      "#{" (skipped months left out)" if billed.size < statements.size}, on #{money(billed.sum(&:spend_cents))} of ad spend"
    tag.span(label, title: tip, class: "ad-fees-total", tabindex: 0, aria: { description: tip })
  end

  # A QuickBooks invoice, linked to where it's checked and sent.
  def ad_fees_invoice_link(statement)
    return if statement.invoice_qbo_id.blank?

    connection = AdFees::QuickbooksConnection.current
    label = "Invoice #{statement.invoice_doc_number.presence || statement.invoice_qbo_id}"
    connection ? link_to(label, connection.invoice_url(statement.invoice_qbo_id), target: "_blank", rel: "noopener") : label
  end
end
