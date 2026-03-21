class CategoriesController < ApplicationController
  before_action :set_category, only: [ :edit, :update, :destroy ]

  def index
    @categories = Category.includes(:parent).order(:sort_order, :name)
    @category = Category.new
  end

  def edit
    @categories = Category.includes(:parent).order(:sort_order, :name)
  end

  def create
    @category = Category.new(category_params)
    if @category.save
      redirect_to categories_path, notice: "分类已创建"
    else
      @categories = Category.includes(:parent).order(:sort_order, :name)
      render :index
    end
  end

  def update
    if @category.update(category_params)
      redirect_to categories_path, notice: "分类已更新"
    else
      render :edit
    end
  end

  def destroy
    @category.destroy
    redirect_to categories_url, notice: "分类已删除"
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :category_type, :parent_id, :sort_order)
  end
end
