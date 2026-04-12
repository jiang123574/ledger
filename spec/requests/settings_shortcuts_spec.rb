# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings Shortcuts", type: :request do
  before { login }

  let(:shortcuts_file) { Rails.root.join("tmp", "shortcuts.json") }

  after do
    File.delete(shortcuts_file) if File.exist?(shortcuts_file)
  end

  describe "GET /settings/shortcuts" do
    it "returns success" do
      get settings_shortcuts_path
      expect(response).to have_http_status(:ok)
    end

    it "loads default shortcuts content" do
      get settings_shortcuts_path
      expect(response.body).to include("新建交易")
    end

    it "handles custom shortcuts from file" do
      FileUtils.mkdir_p(File.dirname(shortcuts_file))
      File.write(shortcuts_file, { "n" => "自定义动作" }.to_json)

      get settings_shortcuts_path
      expect(response).to have_http_status(:ok)
    end

    it "handles missing shortcuts file gracefully" do
      File.delete(shortcuts_file) if File.exist?(shortcuts_file)
      get settings_shortcuts_path
      expect(response).to have_http_status(:ok)
    end

    it "handles invalid JSON in shortcuts file gracefully" do
      FileUtils.mkdir_p(File.dirname(shortcuts_file))
      File.write(shortcuts_file, "invalid json {{{")

      get settings_shortcuts_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /settings/shortcuts/reset" do
    it "clears custom shortcuts file" do
      FileUtils.mkdir_p(File.dirname(shortcuts_file))
      File.write(shortcuts_file, { "n" => "custom" }.to_json)

      post reset_shortcuts_path
      expect(response).to redirect_to(settings_path)
      expect(flash[:notice]).to eq("已恢复默认快捷键")
      expect(File.exist?(shortcuts_file)).to be false
    end

    it "handles missing file gracefully" do
      File.delete(shortcuts_file) if File.exist?(shortcuts_file)
      post reset_shortcuts_path
      expect(response).to redirect_to(settings_path)
      expect(flash[:notice]).to eq("已恢复默认快捷键")
    end
  end
end
