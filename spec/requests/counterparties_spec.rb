# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Counterparties", type: :request do
  before do
    login
  end

  describe "POST /counterparties" do
    let(:valid_attributes) do
      {
        counterparty: {
          name: "Test Company",
          contact: "John Doe",
          note: "Test note"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new counterparty" do
        expect {
          post counterparties_path, params: valid_attributes
        }.to change(Counterparty, :count).by(1)
      end

      it "redirects to settings contacts section" do
        post counterparties_path, params: valid_attributes
        expect(response).to redirect_to(settings_path(section: "contacts"))
        expect(flash[:notice]).to eq("交易对方已创建")
      end
    end

    context "with invalid parameters" do
      it "does not create a counterparty without name" do
        expect {
          post counterparties_path, params: { counterparty: { name: nil } }
        }.not_to change(Counterparty, :count)
      end

      it "redirects with error alert" do
        post counterparties_path, params: { counterparty: { name: nil } }
        expect(response).to redirect_to(settings_path(section: "contacts"))
        expect(flash[:alert]).to be_present
      end
    end

    context "with duplicate name" do
      before { create(:counterparty, name: "Existing Company") }

      it "does not create a counterparty" do
        expect {
          post counterparties_path, params: { counterparty: { name: "Existing Company" } }
        }.not_to change(Counterparty, :count)
      end

      it "redirects with error alert" do
        post counterparties_path, params: { counterparty: { name: "Existing Company" } }
        expect(response).to redirect_to(settings_path(section: "contacts"))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH /counterparties/:id" do
    let(:counterparty) { create(:counterparty, name: "Original Name", contact: "Original Contact") }

    context "with valid parameters" do
      it "updates the counterparty" do
        patch counterparty_path(counterparty), params: { counterparty: { name: "Updated Name" } }
        expect(counterparty.reload.name).to eq("Updated Name")
      end

      it "redirects to settings contacts section" do
        patch counterparty_path(counterparty), params: { counterparty: { name: "Updated Name" } }
        expect(response).to redirect_to(settings_path(section: "contacts"))
        expect(flash[:notice]).to eq("交易对方已更新")
      end
    end

    context "with invalid parameters" do
      it "does not update the counterparty" do
        original_name = counterparty.name
        patch counterparty_path(counterparty), params: { counterparty: { name: nil } }
        expect(counterparty.reload.name).to eq(original_name)
      end

      it "redirects with error alert" do
        patch counterparty_path(counterparty), params: { counterparty: { name: nil } }
        expect(response).to redirect_to(settings_path(section: "contacts"))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "DELETE /counterparties/:id" do
    let!(:counterparty) { create(:counterparty, name: "Delete Me") }

    context "when counterparty has no associated receivables or payables" do
      it "destroys the counterparty" do
        expect {
          delete counterparty_path(counterparty)
        }.to change(Counterparty, :count).by(-1)
      end

      it "redirects to settings contacts section" do
        delete counterparty_path(counterparty)
        expect(response).to redirect_to(settings_path(section: "contacts"))
        expect(flash[:notice]).to eq("交易对方已删除")
      end
    end

    context "when counterparty has associated receivables" do
      let(:account) { create(:account) }

      before do
        create(:receivable, counterparty: counterparty, account: account)
      end

      it "does not destroy the counterparty" do
        expect {
          delete counterparty_path(counterparty)
        }.not_to change(Counterparty, :count)
      end

      it "redirects with error alert" do
        delete counterparty_path(counterparty)
        expect(response).to redirect_to(settings_path(section: "contacts"))
        expect(flash[:alert]).to include("应收款")
      end
    end

    context "when counterparty has associated payables" do
      let(:account) { create(:account) }

      before do
        create(:payable, counterparty_id: counterparty.id, account: account)
      end

      it "does not destroy the counterparty" do
        expect {
          delete counterparty_path(counterparty)
        }.not_to change(Counterparty, :count)
      end

      it "redirects with error alert" do
        delete counterparty_path(counterparty)
        expect(response).to redirect_to(settings_path(section: "contacts"))
        expect(flash[:alert]).to include("应付款")
      end
    end

    context "when counterparty has both receivables and payables" do
      let(:account) { create(:account) }

      before do
        create(:receivable, counterparty: counterparty, account: account)
        create(:payable, counterparty_id: counterparty.id, account: account)
      end

      it "does not destroy the counterparty" do
        expect {
          delete counterparty_path(counterparty)
        }.not_to change(Counterparty, :count)
      end

      it "redirects with error alert mentioning both" do
        delete counterparty_path(counterparty)
        expect(response).to redirect_to(settings_path(section: "contacts"))
        expect(flash[:alert]).to include("应收款")
        expect(flash[:alert]).to include("应付款")
      end
    end
  end
end
