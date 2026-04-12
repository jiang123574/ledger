# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tags", type: :request do
  before do
    login
  end

  describe "GET /tags" do
    it "returns success" do
      get tags_path
      expect(response).to have_http_status(:success)
    end

    it "displays tag names in the page" do
      tag_z = create(:tag, name: "Zebra")
      tag_a = create(:tag, name: "Apple")

      get tags_path

      expect(response.body).to include("Zebra")
      expect(response.body).to include("Apple")
    end
  end

  describe "POST /tags" do
    let(:valid_attributes) do
      {
        tag: {
          name: "New Tag",
          color: "#FF5733"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new tag" do
        expect {
          post tags_path, params: valid_attributes
        }.to change(Tag, :count).by(1)
      end

      it "redirects to tags index with success notice" do
        post tags_path, params: valid_attributes
        expect(response).to redirect_to(tags_path)
        expect(flash[:notice]).to eq("标签已创建")
      end
    end

    context "with invalid parameters" do
      it "does not create a tag without name" do
        expect {
          post tags_path, params: { tag: { name: nil } }
        }.not_to change(Tag, :count)
      end

      it "renders index template with unprocessable_entity status" do
        post tags_path, params: { tag: { name: nil } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with invalid color format" do
      it "does not create a tag" do
        expect {
          post tags_path, params: { tag: { name: "Test", color: "invalid" } }
        }.not_to change(Tag, :count)
      end
    end

    context "without color (uses default)" do
      it "creates a tag with auto-generated color" do
        post tags_path, params: { tag: { name: "Auto Color Tag" } }
        tag = Tag.last
        expect(tag.color).to match(/\A#[0-9A-Fa-f]{6}\z/)
      end
    end
  end

  describe "PATCH /tags/:id" do
    let(:tag) { create(:tag, name: "Original Name", color: "#000000") }

    context "with valid parameters" do
      it "updates the tag name" do
        patch tag_path(tag), params: { tag: { name: "Updated Name" } }
        expect(tag.reload.name).to eq("Updated Name")
      end

      it "updates the tag color" do
        patch tag_path(tag), params: { tag: { color: "#FF0000" } }
        expect(tag.reload.color).to eq("#FF0000")
      end

      it "redirects to tags index with success notice" do
        patch tag_path(tag), params: { tag: { name: "Updated Name" } }
        expect(response).to redirect_to(tags_path)
        expect(flash[:notice]).to eq("标签已更新")
      end
    end

    context "with invalid parameters" do
      it "does not update the tag" do
        original_name = tag.name
        patch tag_path(tag), params: { tag: { name: nil } }
        expect(tag.reload.name).to eq(original_name)
      end

      it "redirects to tags index with error alert" do
        patch tag_path(tag), params: { tag: { name: nil } }
        expect(response).to redirect_to(tags_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "DELETE /tags/:id" do
    let!(:tag) { create(:tag, name: "Delete Me") }

    it "destroys the tag" do
      expect {
        delete tag_path(tag)
      }.to change(Tag, :count).by(-1)
    end

    it "redirects to tags index with success notice" do
      delete tag_path(tag)
      expect(response).to redirect_to(tags_path)
      expect(flash[:notice]).to eq("标签已删除")
    end
  end
end
