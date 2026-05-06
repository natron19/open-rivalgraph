class OwnProductsController < ApplicationController
  before_action :set_own_product, only: [:show, :edit, :update, :destroy]

  def index
    @own_products = current_user.own_products.order(created_at: :desc)
  end

  def new
    @own_product = OwnProduct.new
  end

  def create
    @own_product = current_user.own_products.build(own_product_params)
    if @own_product.save
      redirect_to @own_product, notice: "Product created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @competitors = @own_product.competitors.order(created_at: :desc)
  end

  def edit; end

  def update
    if @own_product.update(own_product_params)
      redirect_to @own_product, notice: "Product updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @own_product.destroy
    redirect_to own_products_path, notice: "Product deleted."
  end

  private

  def set_own_product
    @own_product = current_user.own_products.find(params[:id])
  end

  def own_product_params
    params.require(:own_product).permit(:name, :differentiator_1, :differentiator_2, :differentiator_3)
  end
end
