module AdFees
  # What a month's ad fee is: a minimum, a share of what was spent, or whichever of the two is
  # greater (the default). The install's defaults are in Settings › Plugins › Ad fees; a plan may
  # set any of the three for its own work.
  class Terms
    RULES = {
      "greater_of" => "The minimum or the share of spend, whichever is greater",
      "flat" => "A flat fee (the minimum)",
      "percent" => "A share of spend only"
    }.freeze

    # Why the fee came to what it did.
    BASES = { "minimum" => "Minimum", "flat" => "Flat fee", "percent" => "Share of spend" }.freeze

    attr_reader :rule, :minimum_cents, :percent

    def initialize(rule:, minimum_cents:, percent:)
      @rule = rule.to_s.presence_in(RULES.keys) || "greater_of"
      @minimum_cents = minimum_cents.to_i
      @percent = BigDecimal(percent.to_s)
    end

    # [fee in cents, basis]. The share rounds to the nearest cent.
    def fee_for(spend_cents)
      share = (BigDecimal(spend_cents.to_i) * percent / 100).round
      case rule
      when "flat" then [ minimum_cents, "flat" ]
      when "percent" then [ share, "percent" ]
      else share > minimum_cents ? [ share, "percent" ] : [ minimum_cents, "minimum" ]
      end
    end

    def share_of(spend_cents) = (BigDecimal(spend_cents.to_i) * percent / 100).round

    def self.percent_label(value)
      number = BigDecimal(value.to_s)
      "#{number.frac.zero? ? number.to_i : number.to_s("F")}%"
    end

    # "$1,000.00 a month or 20% of ad spend, whichever is greater"
    def to_s
      case rule
      when "flat" then "#{Money.format(minimum_cents)} a month"
      when "percent" then "#{self.class.percent_label(percent)} of ad spend"
      else "#{Money.format(minimum_cents)} a month or #{self.class.percent_label(percent)} of ad spend, whichever is greater"
      end
    end
  end
end
