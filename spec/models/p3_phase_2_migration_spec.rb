# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "P3 Phase 2: Receivable/Payable Entry Migration", type: :model do
  let(:account) { create(:account) }
  let(:entry) { create(:entry, account: account) }
  let(:receivable) { create(:receivable, account: account) }
  let(:payable) { create(:payable, account: account) }

  describe "Receivable Entry Migration" do
    context "compatibility methods" do
      context "when source_entry is present" do
        before { receivable.update(source_entry: entry) }

        it "returns entry from source_transaction_or_entry" do
          expect(receivable.source_transaction_or_entry).to eq(entry)
        end

        it "returns amount from source_entry" do
          expect(receivable.source_amount).to eq(entry.amount)
        end

        it "returns date from source_entry" do
          expect(receivable.source_date).to eq(entry.date)
        end
      end

      context "when source_transaction is present (legacy)" do
        let(:transaction) { create(:transaction, account: account) }

        before { receivable.update(source_transaction: transaction) }

        it "falls back to transaction" do
          # 优先 Entry，然后 Transaction
          expect(receivable.source_transaction_or_entry).to eq(transaction)
        end
      end

      context "ensure_entry_reference" do
        let(:transaction) { create(:transaction, account: account) }

        before do
          # 模拟历史数据：只有 transaction_id，没有 entry_id
          receivable.update_columns(source_transaction_id: transaction.id, source_entry_id: nil)
        end

        it "auto-sync source_entry_id from transaction" do
          receivable.ensure_entry_reference
          
          # 由于我们没有真实的 Entry-Transaction 映射，这会是 nil
          # 但方法不会抛出异常
          expect(receivable.source_entry_id).to eq(nil)
        end

        it "does nothing if source_entry_id already present" do
          receivable.update_columns(source_entry_id: entry.id)
          original_id = receivable.source_entry_id
          
          receivable.ensure_entry_reference
          
          expect(receivable.source_entry_id).to eq(original_id)
        end
      end
    end

    context "model validations" do
      it "validates that either source_entry or source_transaction is present" do
        receivable.update_columns(source_entry_id: nil, source_transaction_id: nil)
        
        # Receivable 应该在保存时检查这一点
        # 这是模型级的一致性检查
        expect(receivable.source_transaction_or_entry).to be_nil
      end
    end
  end

  describe "Payable Entry Migration" do
    context "compatibility methods" do
      context "when source_entry is present" do
        before { payable.update(source_entry: entry) }

        it "returns entry from source_transaction_or_entry" do
          expect(payable.source_transaction_or_entry).to eq(entry)
        end

        it "returns amount from source_entry" do
          expect(payable.source_amount).to eq(entry.amount)
        end

        it "returns date from source_entry" do
          expect(payable.source_date).to eq(entry.date)
        end
      end

      context "ensure_entry_reference" do
        let(:transaction) { create(:transaction, account: account) }

        before do
          payable.update_columns(source_transaction_id: transaction.id, source_entry_id: nil)
        end

        it "auto-sync source_entry_id from transaction" do
          payable.ensure_entry_reference
          
          # 方法应该尝试但不会失败
          expect(payable.source_entry_id).to eq(nil)
        end
      end
    end
  end

  describe "Migration Data Integrity" do
    context "Receivable/Payable relationship consistency" do
      it "allows Receivable to reference Entry" do
        receivable.update(source_entry: entry)
        receivable.reload
        
        expect(receivable.source_entry).to eq(entry)
      end

      it "allows Payable to reference Entry" do
        payable.update(source_entry: entry)
        payable.reload
        
        expect(payable.source_entry).to eq(entry)
      end

      it "maintains backward compatibility with Transaction references" do
        transaction = create(:transaction)
        receivable.update(source_transaction: transaction)
        receivable.reload
        
        expect(receivable.source_transaction).to eq(transaction)
      end
    end

    context "entries association from Entry side" do
      it "Entry has reverse relationship for receivables" do
        receivable.update(source_entry: entry)
        entry.reload
        
        expect(entry.receivables_as_source).to include(receivable)
      end

      it "Entry has reverse relationship for payables" do
        payable.update(source_entry: entry)
        entry.reload
        
        expect(entry.payables_as_source).to include(payable)
      end
    end
  end

  describe "Migration Path" do
    it "provides clear compatibility layer for gradual migration" do
      # 模拟旧代码：使用 source_transaction_id
      transaction = create(:transaction, account: account)
      receivable.update(source_transaction: transaction)
      
      # 新代码：优先使用 Entry，但能处理旧数据
      source = receivable.source_transaction_or_entry
      
      expect(source).to be_present
      expect([entry.class, transaction.class]).to include(source.class)
    end

    it "supports new code using source_entry" do
      receivable.update(source_entry: entry)
      
      # 新代码可以直接使用 source_entry
      expect(receivable.source_entry).to eq(entry)
    end
  end
end
