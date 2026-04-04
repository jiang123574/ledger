class CategoriesController < ApplicationController
  before_action :set_category, only: [ :update, :destroy ]

  def create
    @category = Category.new(category_params)
    if @category.save
      CacheBuster.bump(:accounts)
      CacheBuster.bump(:categories)
      redirect_to settings_path(section: 'categories'), notice: "分类已创建"
    else
      redirect_to settings_path(section: 'categories'), alert: @category.errors.full_messages.join(', ')
    end
  end

  def update
    if @category.update(category_params)
      CacheBuster.bump(:accounts)
      CacheBuster.bump(:categories)
      redirect_to settings_path(section: 'categories'), notice: "分类已更新"
    else
      redirect_to settings_path(section: 'categories'), alert: @category.errors.full_messages.join(', ')
    end
  end

  def destroy
    @category.destroy
    CacheBuster.bump(:accounts)
    CacheBuster.bump(:categories)
    redirect_to settings_path(section: 'categories'), notice: "分类已删除"
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :category_type, :parent_id, :sort_order)
  end
end
