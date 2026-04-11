# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "20260411120003 ConvertTransferIdToUuidFormat", type: :migration do
  let(:account) { create(:account) }
  let(:category) { create(:category) }

  before do
    # 清理数据
    Entry.destroy_all
    Receivable.destroy_all
  end

  describe "transfer_id 格式转换" do
    context "entries 表" do
      it "将整数 transfer_id 转换为 UUID 格式" do
        # 创建测试数据：整数格式的 transfer_id
        entry1 = create(:entry, account: account, transfer_id: "12345")
        entry2 = create(:entry, account: account, transfer_id: "12345")
        entry3 = create(:entry, account: account, transfer_id: "67890")

        # 运行迁移
        ActiveRecord::Migration.suppress_messages do
          ConvertTransferIdToUuidFormat.new.up
        end

        # 验证转换结果
        entry1.reload
        entry2.reload
        entry3.reload

        # 所有 transfer_id 应该是 UUID 格式
        expect(entry1.transfer_id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
        expect(entry2.transfer_id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
        expect(entry3.transfer_id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)

        # 原来相同的整数应该映射到相同的 UUID
        expect(entry1.transfer_id).to eq(entry2.transfer_id)

        # 不同的整数应该映射到不同的 UUID
        expect(entry1.transfer_id).not_to eq(entry3.transfer_id)
      end

      it "保留已经是 UUID 格式的 transfer_id" do
        existing_uuid = SecureRandom.uuid
        entry = create(:entry, account: account, transfer_id: existing_uuid)

        ActiveRecord::Migration.suppress_messages do
          ConvertTransferIdToUuidFormat.new.up
        end

        entry.reload
        expect(entry.transfer_id).to eq(existing_uuid)
      end

      it "保留 nil 的 transfer_id" do
        entry = create(:entry, account: account, transfer_id: nil)

        ActiveRecord::Migration.suppress_messages do
          ConvertTransferIdToUuidFormat.new.up
        end

        entry.reload
        expect(entry.transfer_id).to be_nil
      end
    end

    context "receivables 表" do
      it "将整数 transfer_id 转换为 UUID 格式" do
        # 创建关联的 entries
        entry1 = create(:entry, account: account, transfer_id: "11111")
        entry2 = create(:entry, account: account, transfer_id: "11111")

        # 创建 receivable
        receivable = create(:receivable, account: account, transfer_id: "11111")

        ActiveRecord::Migration.suppress_messages do
          ConvertTransferIdToUuidFormat.new.up
        end

        receivable.reload
        entry1.reload

        # receivable 的 transfer_id 应该与对应的 entries 一致
        expect(receivable.transfer_id).to eq(entry1.transfer_id)
        expect(receivable.transfer_id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
      end

      it "将整数 reimbursement_transfer_ids 转换为 UUID 格式" do
        # 创建关联的 entries
        entry1 = create(:entry, account: account, transfer_id: "22222")
        entry2 = create(:entry, account: account, transfer_id: "22222")
        entry3 = create(:entry, account: account, transfer_id: "33333")
        entry4 = create(:entry, account: account, transfer_id: "33333")

        # 创建 receivable，包含多个 reimbursement_transfer_ids
        receivable = create(:receivable,
          account: account,
          transfer_id: nil,
          reimbursement_transfer_ids: ["22222", "33333"]
        )

        ActiveRecord::Migration.suppress_messages do
          ConvertTransferIdToUuidFormat.new.up
        end

        receivable.reload
        entry1.reload
        entry3.reload

        # 所有 reimbursement_transfer_ids 应该转换为 UUID
        expect(receivable.reimbursement_transfer_ids.size).to eq(2)
        expect(receivable.reimbursement_transfer_ids).to include(entry1.transfer_id)
        expect(receivable.reimbursement_transfer_ids).to include(entry3.transfer_id)
      end
    end

    context "数据一致性验证" do
      it "确保 entries 和 receivables 使用相同的映射" do
        # 创建转账记录（2 条 entry 共享同一个 transfer_id）
        entry1 = create(:entry, account: account, transfer_id: "99999")
        entry2 = create(:entry, account: account, transfer_id: "99999")

        # 创建对应的 receivable
        receivable = create(:receivable, account: account, transfer_id: "99999")

        ActiveRecord::Migration.suppress_messages do
          ConvertTransferIdToUuidFormat.new.up
        end

        entry1.reload
        entry2.reload
        receivable.reload

        # 三者应该有相同的 transfer_id
        expect(entry1.transfer_id).to eq(entry2.transfer_id)
        expect(entry1.transfer_id).to eq(receivable.transfer_id)
      end

      it "保持转账配对完整性（每个 transfer_id 有 2 条 entry）" do
        # 创建多个转账对
        create(:entry, account: account, transfer_id: "10001")
        create(:entry, account: account, transfer_id: "10001")
        create(:entry, account: account, transfer_id: "10002")
        create(:entry, account: account, transfer_id: "10002")

        ActiveRecord::Migration.suppress_messages do
          ConvertTransferIdToUuidFormat.new.up
        end

        # 验证每个 UUID 格式的 transfer_id 都有 2 条 entry
        Entry.where.not(transfer_id: nil).group(:transfer_id).count.each do |transfer_id, count|
          expect(transfer_id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
          expect(count).to eq(2)
        end
      end
    end
  end
end
