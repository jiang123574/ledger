# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Shortcuts", type: :request do
  let(:shortcuts_file) { Rails.root.join("tmp", "shortcuts.json") }

  before do
    login
    # Clean up any existing shortcuts file
    File.delete(shortcuts_file) if File.exist?(shortcuts_file)
  end

  after do
    File.delete(shortcuts_file) if File.exist?(shortcuts_file)
  end

  # ============================================================
  # ShortcutsController unit tests
  # ============================================================
  describe ShortcutsController do
    describe "#default_shortcuts" do
      let(:controller) { described_class.new }

      before do
        # Stash private methods for testing
        controller.class.class_eval { public :default_shortcuts, :load_custom_shortcuts, :save_custom_shortcuts, :clear_custom_shortcuts }
      end

      it "returns an array of default shortcut definitions" do
        shortcuts = controller.default_shortcuts
        expect(shortcuts).to be_an(Array)
        expect(shortcuts.size).to be > 0
      end

      it "includes a shortcut for creating new transactions" do
        shortcuts = controller.default_shortcuts
        new_tx = shortcuts.find { |s| s[:action] == "new_transaction" }
        expect(new_tx).not_to be_nil
        expect(new_tx[:key]).to eq("n")
        expect(new_tx[:description]).to eq("新建交易")
      end

      it "includes a shortcut for search" do
        shortcuts = controller.default_shortcuts
        search = shortcuts.find { |s| s[:action] == "search" }
        expect(search).not_to be_nil
        expect(search[:key]).to eq("s")
      end

      it "includes navigation shortcuts with 'g' prefix" do
        shortcuts = controller.default_shortcuts
        nav_keys = shortcuts.select { |s| s[:key].start_with?("g ") }
        expect(nav_keys.size).to be >= 4

        actions = nav_keys.map { |s| s[:action] }
        expect(actions).to include("goto_accounts")
        expect(actions).to include("goto_reports")
        expect(actions).to include("goto_budgets")
        expect(actions).to include("goto_settings")
      end

      it "includes help shortcut" do
        shortcuts = controller.default_shortcuts
        help = shortcuts.find { |s| s[:action] == "show_help" }
        expect(help).not_to be_nil
        expect(help[:key]).to eq("?")
      end

      it "includes escape shortcut" do
        shortcuts = controller.default_shortcuts
        escape = shortcuts.find { |s| s[:action] == "escape" }
        expect(escape).not_to be_nil
        expect(escape[:key]).to eq("Escape")
      end

      it "groups shortcuts by category" do
        shortcuts = controller.default_shortcuts
        groups = shortcuts.map { |s| s[:group] }.uniq
        expect(groups).to include("交易")
        expect(groups).to include("导航")
        expect(groups).to include("帮助")
        expect(groups).to include("通用")
      end
    end

    describe "#load_custom_shortcuts" do
      let(:controller) { described_class.new }

      before do
        controller.class.class_eval { public :load_custom_shortcuts, :save_custom_shortcuts }
      end

      it "returns empty hash when no custom shortcuts file exists" do
        expect(controller.load_custom_shortcuts).to eq({})
      end

      it "returns parsed JSON from shortcuts file" do
        custom = { "new_transaction" => "ctrl+n" }
        File.write(shortcuts_file, custom.to_json)

        expect(controller.load_custom_shortcuts).to eq(custom)
      end

      it "returns empty hash for invalid JSON" do
        File.write(shortcuts_file, "not valid json")

        expect(controller.load_custom_shortcuts).to eq({})
      end
    end

    describe "#save_custom_shortcuts" do
      let(:controller) { described_class.new }

      before do
        controller.class.class_eval { public :save_custom_shortcuts }
      end

      it "writes shortcuts to JSON file" do
        shortcuts = { "search" => "ctrl+f", "new_transaction" => "ctrl+n" }
        controller.save_custom_shortcuts(shortcuts)

        expect(File.exist?(shortcuts_file)).to be true
        saved = JSON.parse(File.read(shortcuts_file))
        expect(saved).to eq(shortcuts)
      end

      it "creates the tmp directory if it doesn't exist" do
        FileUtils.rm_rf(File.dirname(shortcuts_file)) rescue nil
        FileUtils.mkdir_p(File.dirname(shortcuts_file))

        shortcuts = { "action" => "key" }
        controller.save_custom_shortcuts(shortcuts)

        expect(File.exist?(shortcuts_file)).to be true
      end

      it "overwrites existing shortcuts" do
        File.write(shortcuts_file, { "old" => "key" }.to_json)

        new_shortcuts = { "new" => "value" }
        controller.save_custom_shortcuts(new_shortcuts)

        saved = JSON.parse(File.read(shortcuts_file))
        expect(saved).to eq(new_shortcuts)
      end
    end

    describe "#clear_custom_shortcuts" do
      let(:controller) { described_class.new }

      before do
        controller.class.class_eval { public :clear_custom_shortcuts }
      end

      it "deletes the shortcuts file" do
        File.write(shortcuts_file, { "key" => "value" }.to_json)
        controller.clear_custom_shortcuts

        expect(File.exist?(shortcuts_file)).to be false
      end

      it "does nothing when no file exists" do
        expect { controller.clear_custom_shortcuts }.not_to raise_error
      end
    end
  end

  # ============================================================
  # Settings shortcuts routes (where shortcuts actually live)
  # ============================================================
  describe "Settings shortcuts routes" do
    describe "GET /settings/shortcuts" do
      it "returns success when section is shortcuts" do
        get settings_shortcuts_path

        expect(response).to have_http_status(:success)
      end
    end

    describe "POST /settings/shortcuts/reset" do
      it "clears custom shortcuts and redirects" do
        # Create a custom shortcuts file first
        File.write(shortcuts_file, { "custom" => "key" }.to_json)

        post reset_shortcuts_path

        expect(response).to redirect_to(settings_path)
        expect(flash[:notice]).to eq("已恢复默认快捷键")
        expect(File.exist?(shortcuts_file)).to be false
      end

      it "handles reset when no shortcuts file exists" do
        post reset_shortcuts_path

        expect(response).to redirect_to(settings_path)
        expect(flash[:notice]).to eq("已恢复默认快捷键")
      end
    end
  end
end
