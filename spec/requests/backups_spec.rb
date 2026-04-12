# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Backups", type: :request do
  before do
    login
  end

  describe "GET /backups" do
    before do
      allow(BackupService).to receive(:list_backups).and_return([])
      allow(BackupService).to receive(:webdav_configured?).and_return(false)
      allow(BackupService).to receive(:auto_backup_enabled?).and_return(false)
    end

    it "returns success" do
      get backups_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /backups" do
    context "when backup succeeds" do
      before do
        allow(BackupService).to receive(:create_backup).and_return({
          success: true,
          file_name: "backup_20240101.sql"
        })
      end

      it "redirects with success notice" do
        post backups_path
        expect(response).to redirect_to(backups_path)
        expect(flash[:notice]).to include("backup_20240101.sql")
      end
    end

    context "when backup fails" do
      before do
        allow(BackupService).to receive(:create_backup).and_return({
          success: false,
          error: "备份失败"
        })
      end

      it "redirects with error alert" do
        post backups_path
        expect(response).to redirect_to(backups_path)
        expect(flash[:alert]).to eq("备份失败")
      end
    end
  end

  describe "GET /backups/:id/download" do
    let(:backup_record) { create(:backup_record) }

    context "when file does not exist" do
      it "redirects with error alert" do
        get download_backup_path(backup_record)
        expect(response).to redirect_to(backups_path)
        expect(flash[:alert]).to eq("备份文件不存在")
      end
    end
  end

  describe "DELETE /backups/:id" do
    context "when deletion succeeds" do
      before do
        allow(BackupService).to receive(:delete_backup).and_return({ success: true })
      end

      it "redirects with success notice" do
        delete backup_path(1)
        expect(response).to redirect_to(backups_path)
        expect(flash[:notice]).to eq("备份已删除")
      end
    end

    context "when deletion fails" do
      before do
        allow(BackupService).to receive(:delete_backup).and_return({
          success: false,
          error: "删除失败"
        })
      end

      it "redirects with error alert" do
        delete backup_path(1)
        expect(response).to redirect_to(backups_path)
        expect(flash[:alert]).to eq("删除失败")
      end
    end
  end

  describe "GET /backups/webdav_test" do
    before do
      allow(BackupService).to receive(:test_webdav_connection).and_return({ success: true })
    end

    it "returns JSON result" do
      get webdav_test_backups_path
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["success"]).to be true
    end
  end

  describe "POST /backups/webdav_connect" do
    context "when connection succeeds" do
      before do
        allow(BackupService).to receive(:configure_webdav).and_return({ success: true })
      end

      it "redirects with success notice" do
        post webdav_connect_backups_path, params: {
          url: "https://example.com/dav",
          username: "user",
          password: "pass"
        }
        expect(response).to redirect_to(backups_path)
        expect(flash[:notice]).to eq("WebDAV 连接成功")
      end
    end

    context "when connection fails" do
      before do
        allow(BackupService).to receive(:configure_webdav).and_return({
          success: false,
          error: "连接失败"
        })
      end

      it "redirects with error alert" do
        post webdav_connect_backups_path, params: {
          url: "https://example.com/dav",
          username: "user",
          password: "pass"
        }
        expect(response).to redirect_to(backups_path)
        expect(flash[:alert]).to eq("连接失败")
      end
    end
  end
end
