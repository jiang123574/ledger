class TagsController < ApplicationController
  def index
    @tags = Tag.order(:name)
  end

  def create
    @tag = Tag.new(tag_params)
    if @tag.save
      redirect_to tags_path, notice: "标签已创建"
    else
      @tags = Tag.order(:name)
      render :index
    end
  end

  def update
    @tag = Tag.find(params[:id])
    if @tag.update(tag_params)
      redirect_to tags_path, notice: "标签已更新"
    else
      redirect_to tags_path, alert: @tag.errors.full_messages.join(", ")
    end
  end

  def destroy
    @tag = Tag.find(params[:id])
    @tag.destroy
    redirect_to tags_path, notice: "标签已删除"
  end

  private

  def tag_params
    params.require(:tag).permit(:name, :color)
  end
end
