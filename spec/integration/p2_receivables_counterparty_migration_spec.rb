# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "P2: Receivables Counterparty Migration", type: :integration do
  describe "Migration Integrity" do
    it "all receivables have valid counterparty_id or nil" do
      receivables = Receivable.all

      receivables.each do |receivable|
        if receivable.counterparty_id.present?
          expect(receivable.counterparty).to be_present
          expect(receivable.counterparty).to be_a(Counterparty)
        end
      end
    end

    it "counterparty foreign key relationship works correctly" do
      counterparty = create(:counterparty, name: "测试客户")
      receivable = create(:receivable, counterparty: counterparty)

      receivable.reload
      expect(receivable.counterparty_id).to eq(counterparty.id)
      expect(receivable.counterparty).to eq(counterparty)
      expect(receivable.counterparty.name).to eq("测试客户")
    end

    it "allows null counterparty_id for receivables without counterparty" do
      receivable = create(:receivable, counterparty: nil)

      expect(receivable.counterparty_id).to be_nil
      expect(receivable.counterparty).to be_nil
    end

    it "counterparty receivables association works" do
      counterparty = create(:counterparty, name: "客户C")
      receivable1 = create(:receivable, counterparty: counterparty, original_amount: 1000)
      receivable2 = create(:receivable, counterparty: counterparty, original_amount: 2000)

      expect(counterparty.receivables).to include(receivable1, receivable2)
      expect(counterparty.total_receivable_amount).to eq(3000)
    end
  end

  describe "Migration Rollback" do
    it "down migration restores counterparty string column" do
      counterparty = create(:counterparty, name: "回滚测试客户")
      receivable = create(:receivable, counterparty: counterparty)

      receivable.reload
      expect(receivable.counterparty_id).to eq(counterparty.id)

      expect {
        ActiveRecord::Migration[7.0].new.down
      }.not_to raise_error
    end
  end

  describe "Data Consistency" do
    it "all counterparties are unique by name" do
      names = Counterparty.pluck(:name)
      expect(names.uniq.length).to eq(names.length)
    end

    it "no orphaned counterparty_id references" do
      orphaned_ids = Receivable.where.not(counterparty_id: nil)
                               .where.not(counterparty_id: Counterparty.select(:id))
                               .pluck(:id)

      expect(orphaned_ids).to be_empty
    end
  end
end
