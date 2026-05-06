class CompetitorsController < ApplicationController
  before_action :set_own_product
  before_action :set_competitor, only: [:show, :edit, :update, :destroy]

  def new
    @competitor = @own_product.competitors.build
  end

  def create
    @competitor = @own_product.competitors.build(competitor_params.merge(user: current_user))
    if @competitor.save
      redirect_to own_product_competitor_path(@own_product, @competitor), notice: "Competitor added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @analyses = @competitor.competitor_analyses.order(created_at: :desc)
    @latest = @competitor.competitor_analyses.complete.order(researched_at: :desc).first
  end

  def edit; end

  def update
    if @competitor.update(competitor_params)
      redirect_to own_product_competitor_path(@own_product, @competitor), notice: "Competitor updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @competitor.destroy
    redirect_to @own_product, notice: "#{@competitor.company_name} removed."
  end

  private

  def set_own_product
    @own_product = current_user.own_products.find(params[:own_product_id])
  end

  def set_competitor
    @competitor = @own_product.competitors.find(params[:id])
  end

  def competitor_params
    params.require(:competitor).permit(:company_name, :website, :notes)
  end
end
