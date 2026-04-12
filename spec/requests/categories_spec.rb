# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Categories", type: :request do
  before { login }

  let(:category) { create(:category, :expense) }

  describe "POST /categories" do
    let(:valid_params) do
      {
        category: {
          name: "新分类",
          category_type: "expense",
          sort_order: 1
        }
      }
    end

    it "creates a new category" do
      expect {
        post categories_path, params: valid_params
      }.to change(Category, :count).by(1)

      expect(response).to redirect_to(settings_path(section: "categories"))
      expect(flash[:notice]).to eq("分类已创建")
    end

    it "creates a subcategory with parent_id" do
      params = valid_params.deep_merge(category: { parent_id: category.id })
      post categories_path, params: params
      expect(Category.last.parent_id).to eq(category.id)
    end

    it "sets sort_order on create" do
      post categories_path, params: valid_params
      expect(Category.last.sort_order).to eq(1)
    end

    it "bumps accounts cache on create" do
      expect(CacheBuster).to receive(:bump).with(:accounts)
      expect(CacheBuster).to receive(:bump).with(:categories)
      post categories_path, params: valid_params
    end

    context "with invalid params" do
      it "redirects with alert when save fails" do
        # Name is required by validation
        post categories_path, params: { category: { name: "" } }
        expect(response).to redirect_to(settings_path(section: "categories"))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH /categories/:id" do
    it "updates the category name" do
      patch category_path(category), params: { category: { name: "更新后的分类" } }
      expect(category.reload.name).to eq("更新后的分类")
      expect(response).to redirect_to(settings_path(section: "categories"))
      expect(flash[:notice]).to eq("分类已更新")
    end

    it "updates sort_order" do
      patch category_path(category), params: { category: { sort_order: 99 } }
      expect(category.reload.sort_order).to eq(99)
    end

    it "updates category_type" do
      patch category_path(category), params: { category: { category_type: "income" } }
      expect(category.reload.category_type).to eq("income")
    end

    it "bumps cache on update" do
      expect(CacheBuster).to receive(:bump).with(:accounts)
      expect(CacheBuster).to receive(:bump).with(:categories)
      patch category_path(category), params: { category: { name: "更新" } }
    end

    context "with invalid params" do
      it "redirects with alert when update fails" do
        patch category_path(category), params: { category: { name: "" } }
        expect(response).to redirect_to(settings_path(section: "categories"))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "DELETE /categories/:id" do
    it "destroys the category" do
      category # ensure created
      expect {
        delete category_path(category)
      }.to change(Category, :count).by(-1)

      expect(response).to redirect_to(settings_path(section: "categories"))
      expect(flash[:notice]).to eq("分类已删除")
    end

    it "bumps cache on destroy" do
      expect(CacheBuster).to receive(:bump).with(:accounts)
      expect(CacheBuster).to receive(:bump).with(:categories)
      delete category_path(category)
    end
  end
end
