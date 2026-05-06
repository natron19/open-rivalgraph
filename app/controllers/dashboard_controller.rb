class DashboardController < ApplicationController
  def show
    @products_count    = current_user.own_products.count
    @competitors_count = current_user.competitors.count
    @battlecards_count = current_user.competitor_analyses.complete.count
    @recent_analyses   = current_user.competitor_analyses
                                     .complete
                                     .includes(competitor: :own_product)
                                     .order(researched_at: :desc)
                                     .limit(3)
  end
end
