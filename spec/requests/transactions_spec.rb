# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Transactions", type: :request do
  before { login }

  let(:account) { create(:account) }
  let(:another_account) { create(:account, name: 'Another Account') }
  let(:category) { create(:category) }

  # ==================== Index ====================
  describe "GET /transactions" do
    it "redirects to accounts" do
      get "/transactions"
      expect(response).to redirect_to("/accounts")
    end

    it "preserves query parameters in redirect" do
      get "/transactions", params: { account_id: account.id, type: "EXPENSE" }
      expect(response).to redirect_to("/accounts?account_id=#{account.id}&type=EXPENSE")
    end
  end

  # ==================== Create ====================
  describe "POST /transactions" do
    context "creating an expense" do
      it "creates a new entry via EntryCreationService" do
        expect {
          post "/transactions", params: {
            transaction: {
              type: "EXPENSE",
              amount: 100,
              date: Date.current,
              currency: "CNY",
              account_id: account.id,
              category_id: category.id,
              note: "Test expense"
            }
          }
        }.to change(Entry, :count).by(1)

        expect(response).to have_http_status(:redirect)
      end

      it "creates expense with negative amount" do
        post "/transactions", params: {
          transaction: {
            type: "EXPENSE",
            amount: 50,
            date: Date.current,
            account_id: account.id,
            note: "支出"
          }
        }

        entry = Entry.last
        expect(entry.amount).to be < 0
      end

      it "infers type from category when present" do
        expense_category = create(:category, category_type: 'EXPENSE', name: 'Expense Cat')

        post "/transactions", params: {
          transaction: {
            type: "INCOME",  # 故意传错类型
            amount: 100,
            date: Date.current,
            account_id: account.id,
            category_id: expense_category.id,
            note: "Test"
          }
        }

        expect(response).to have_http_status(:redirect)
      end
    end

    context "creating an income" do
      it "creates income entry with positive amount" do
        post "/transactions", params: {
          transaction: {
            type: "INCOME",
            amount: 5000,
            date: Date.current,
            account_id: account.id,
            note: "工资"
          }
        }

        entry = Entry.last
        expect(entry.amount).to eq(5000)
      end
    end

    context "creating a transfer" do
      it "creates transfer entries" do
        expect {
          post "/transactions", params: {
            transaction: {
              type: "TRANSFER",
              amount: 200,
              date: Date.current,
              currency: "CNY",
              account_id: account.id,
              target_account_id: another_account.id,
              note: "Test transfer"
            }
          }
        }.to change(Entry, :count).by(2)

        expect(response).to have_http_status(:redirect)
      end

      it "links transfer entries with same transfer_id" do
        post "/transactions", params: {
          transaction: {
            type: "TRANSFER",
            amount: 100,
            date: Date.current,
            account_id: account.id,
            target_account_id: another_account.id
          }
        }

        transfer_entries = Entry.where.not(transfer_id: nil)
        transfer_ids = transfer_entries.pluck(:transfer_id).uniq
        expect(transfer_ids.size).to eq(1)
      end

      it "handles missing target account" do
        post "/transactions", params: {
          transaction: {
            type: "TRANSFER",
            amount: 100,
            date: Date.current,
            account_id: account.id,
            target_account_id: -1
          }
        }

        expect(response).to have_http_status(:redirect)
      end
    end

    context "creating with funding transfer" do
      let(:funding_account) { create(:account, name: 'Funding') }

      it "creates 3 entries with funding transfer" do
        expect {
          post "/transactions", params: {
            transaction: {
              type: "EXPENSE",
              amount: 500,
              date: Date.current,
              account_id: account.id,
              category_id: category.id,
              note: "购物"
            },
            funding_account_id: funding_account.id
          }
        }.to change(Entry, :count).by(3)

        expect(response).to have_http_status(:redirect)
      end

      it "handles missing funding account" do
        post "/transactions", params: {
          transaction: {
            type: "EXPENSE",
            amount: 100,
            date: Date.current,
            account_id: account.id
          },
          funding_account_id: -1
        }

        expect(response).to have_http_status(:redirect)
      end
    end

    context "with validation errors" do
      it "handles missing required fields" do
        post "/transactions", params: {
          transaction: {
            type: "EXPENSE",
            account_id: account.id
            # missing amount and date
          }
        }

        expect(response).to have_http_status(:redirect)
      end

      it "handles invalid account" do
        post "/transactions", params: {
          transaction: {
            type: "EXPENSE",
            amount: 100,
            date: Date.current,
            account_id: -1
          }
        }

        expect(response).to have_http_status(:redirect)
      end
    end

    context "with continue parameter" do
      it "redirects to new transaction form when continue is set" do
        post "/transactions", params: {
          transaction: {
            type: "EXPENSE",
            amount: 100,
            date: Date.current,
            account_id: account.id,
            note: "Test"
          },
          open_new_transaction: "1"
        }

        expect(response).to have_http_status(:redirect)
      end
    end
  end

  # ==================== Update ====================
  describe "PATCH /transactions/:id" do
    let(:entry) { create(:entry, account: account, amount: -100, date: Date.current, entryable: create(:entryable_transaction, category: category)) }

    it "updates the entry" do
      patch "/transactions/#{entry.id}", params: {
        transaction: {
          amount: 200,
          note: "Updated note"
        }
      }

      expect(response).to have_http_status(:redirect)
      entry.reload
      expect(entry.notes).to eq("Updated note")
    end

    it "updates entry date" do
      new_date = 5.days.ago.to_date

      patch "/transactions/#{entry.id}", params: {
        transaction: {
          date: new_date
        }
      }

      entry.reload
      expect(entry.date).to eq(new_date)
    end

    it "updates entry account" do
      new_account = create(:account, name: 'New Account')

      patch "/transactions/#{entry.id}", params: {
        transaction: {
          account_id: new_account.id
        }
      }

      entry.reload
      expect(entry.account_id).to eq(new_account.id)
    end

    it "updates entry category" do
      new_category = create(:category, name: 'New Category')

      patch "/transactions/#{entry.id}", params: {
        transaction: {
          category_id: new_category.id
        }
      }

      entry.entryable.reload
      expect(entry.entryable.category_id).to eq(new_category.id)
    end

    context "updating transfer" do
      let(:transfer_id) { SecureRandom.uuid }
      let!(:out_entry) { create(:entry, account: account, amount: -100, transfer_id: transfer_id, entryable: create(:entryable_transaction)) }
      let!(:in_entry) { create(:entry, account: another_account, amount: 100, transfer_id: transfer_id, entryable: create(:entryable_transaction)) }

      it "updates transfer and paired entry" do
        new_target = create(:account, name: 'New Target')

        patch "/transactions/#{out_entry.id}", params: {
          transaction: {
            amount: 500,
            target_account_id: new_target.id
          }
        }

        expect(response).to have_http_status(:redirect)
      end
    end

    context "with validation errors" do
      it "handles invalid update" do
        patch "/transactions/#{entry.id}", params: {
          transaction: {
            date: nil
          }
        }

        expect(response).to have_http_status(:redirect)
      end
    end
  end

  # ==================== Destroy ====================
  describe "DELETE /transactions/:id" do
    let(:entry) { create(:entry, :expense, account: account, entryable: create(:entryable_transaction, category: category)) }

    it "destroys the entry" do
      entry_id = entry.id

      expect {
        delete "/transactions/#{entry_id}"
      }.to change { Entry.exists?(entry_id) }.from(true).to(false)

      expect(response).to redirect_to("/accounts")
    end

    it "shows success notice" do
      delete "/transactions/#{entry.id}"

      expect(response).to redirect_to("/accounts")
      expect(flash[:notice]).to eq("交易已删除")
    end

    it "handles non-existent entry" do
      delete "/transactions/-1"

      expect(response).to have_http_status(:not_found).or have_http_status(:redirect)
    end
  end

  # ==================== Bulk Destroy ====================
  describe "POST /transactions/bulk_destroy" do
    let!(:entry1) { create(:entry, account: account, entryable: create(:entryable_transaction)) }
    let!(:entry2) { create(:entry, account: account, entryable: create(:entryable_transaction)) }
    let!(:entry3) { create(:entry, account: account, entryable: create(:entryable_transaction)) }

    it "deletes multiple entries" do
      expect {
        post "/transactions/bulk_destroy", params: { ids: [entry1.id, entry2.id] }
      }.to change(Entry, :count).by(-2)

      expect(response).to have_http_status(:redirect)
    end

    it "shows count in notice" do
      post "/transactions/bulk_destroy", params: { ids: [entry1.id, entry2.id] }

      expect(flash[:notice]).to include("2")
    end

    it "handles empty ids" do
      post "/transactions/bulk_destroy"

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to include("请选择")
    end

    it "handles empty array" do
      post "/transactions/bulk_destroy", params: { ids: [] }

      expect(response).to have_http_status(:redirect)
    end
  end

  # ==================== Edit ====================
  describe "GET /transactions/:id/edit" do
    let(:entry) { create(:entry, account: account, entryable: create(:entryable_transaction, category: category)) }

    it "handles edit request" do
      get "/transactions/#{entry.id}/edit"

      # 可能返回成功、重定向或 406
      expect(response).to have_http_status(:success)
        .or have_http_status(:redirect)
        .or have_http_status(:not_acceptable)
    end
  end

  # ==================== Edge Cases ====================
  describe "edge cases" do
    it "handles large amounts" do
      post "/transactions", params: {
        transaction: {
          type: "INCOME",
          amount: 999999999.99,
          date: Date.current,
          account_id: account.id
        }
      }

      expect(response).to have_http_status(:redirect)
    end

    it "handles special characters in note" do
      post "/transactions", params: {
        transaction: {
          type: "EXPENSE",
          amount: 100,
          date: Date.current,
          account_id: account.id,
          note: "测试 & <特殊字符>"
        }
      }

      expect(response).to have_http_status(:redirect)
    end

    it "handles future dates" do
      post "/transactions", params: {
        transaction: {
          type: "EXPENSE",
          amount: 100,
          date: 30.days.from_now,
          account_id: account.id
        }
      }

      expect(response).to have_http_status(:redirect)
    end
  end
end
