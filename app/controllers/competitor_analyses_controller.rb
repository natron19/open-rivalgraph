class CompetitorAnalysesController < ApplicationController
  before_action :set_analysis, only: [:show, :destroy, :export]

  def index
    @analyses = current_user.competitor_analyses
                            .complete
                            .includes(competitor: :own_product)
                            .order(researched_at: :desc)
  end

  def create
    @own_product = current_user.own_products.find(params[:own_product_id])
    @competitor  = @own_product.competitors.find(params[:competitor_id])
    @analysis    = @competitor.competitor_analyses.create!(
      user:   current_user,
      status: "pending"
    )
    AgentRunJob.perform_later(@analysis.id)
    redirect_to competitor_analysis_path(@analysis), notice: "Research started. This may take up to 90 seconds."
  end

  def show; end

  def export
    return head(:not_found) unless @analysis.status == "complete"

    data = begin
      @analysis.battlecard.is_a?(String) ? JSON.parse(@analysis.battlecard) : @analysis.battlecard
    rescue JSON::ParserError
      return head(:unprocessable_entity)
    end

    md = battlecard_to_markdown(data, @analysis)
    filename = "#{data["competitor_name"].to_s.parameterize}-battlecard-#{@analysis.researched_at.strftime("%Y-%m-%d")}.md"
    send_data md, filename: filename, type: "text/markdown", disposition: "attachment"
  end

  def destroy
    @competitor  = @analysis.competitor
    @own_product = @competitor.own_product
    @analysis.destroy
    redirect_to own_product_competitor_path(@own_product, @competitor), notice: "Battlecard deleted."
  end

  private

  def set_analysis
    @analysis = current_user.competitor_analyses.find(params[:id])
  end

  def battlecard_to_markdown(data, analysis)
    own_product = analysis.competitor.own_product
    lines = []

    lines << "# #{data["competitor_name"]} Battlecard"
    lines << ""
    lines << "**Product:** #{own_product.name}  "
    lines << "**Researched:** #{analysis.researched_at.strftime("%B %-d, %Y")}"
    lines << ""

    lines << "---"
    lines << ""
    lines << "## What They Offer"
    lines << ""
    lines << data["what_they_offer"].to_s
    lines << ""

    lines << "---"
    lines << ""
    lines << "## Pricing Tiers"
    lines << ""
    tiers = Array(data["pricing_tiers"])
    if tiers.any?
      tiers.each do |tier|
        lines << "- **#{tier["tier_name"]}** — #{tier["price"]}: #{tier["summary"]}"
      end
    else
      lines << "_Could not retrieve current pricing data._"
    end
    lines << ""

    lines << "---"
    lines << ""
    lines << "## Top Customer Complaints"
    lines << ""
    complaints = Array(data["top_customer_complaints"])
    if complaints.any?
      complaints.each { |c| lines << "- #{c}" }
    else
      lines << "_Could not retrieve review data._"
    end
    lines << ""

    lines << "---"
    lines << ""
    lines << "## Recent News"
    lines << ""
    lines << data["recent_news"].to_s.presence || "_No recent news found._"
    lines << ""

    lines << "---"
    lines << ""
    lines << "## Why You Win"
    lines << ""
    Array(data["talking_points"]).each { |p| lines << "- #{p}" }
    lines << ""

    lines << "---"
    lines << ""
    lines << "## Where They Are Stronger"
    lines << ""
    lines << data["competitor_strength"].to_s
    lines << ""

    lines << "---"
    lines << ""
    lines << "_Battlecard sourced from live web pages on #{analysis.researched_at.strftime("%B %-d, %Y")}. Pricing and availability change frequently. Verify all figures before using in sales or marketing materials._"
    lines << ""

    lines.join("\n")
  end
end
