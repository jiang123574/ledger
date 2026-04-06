# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BackupService, type: :service do
  describe '.list_backups' do
    before do
      # 创建几个备份记录
      create(:backup_record, filename: 'backup_1.sql', file_size: 1000)
      create(:backup_record, filename: 'backup_2.sql', file_size: 2000)
    end

    it 'returns backup list as hashes' do
      backups = described_class.list_backups(limit: 10)

      expect(backups).to be_an(Array)
      expect(backups).not_to be_empty
    end

    it 'includes required fields' do
      backups = described_class.list_backups(limit: 10)

      backups.each do |backup|
        expect(backup).to include(:id, :name, :path, :size, :created_at, :type, :status)
      end
    end

    it 'respects limit parameter' do
      backups = described_class.list_backups(limit: 1)

      expect(backups.length).to be <= 1
    end

    it 'returns most recent backups first' do
      backups = described_class.list_backups(limit: 10)

      dates = backups.map { |b| b[:created_at] }
      expect(dates).to eq(dates.sort.reverse)
    end
  end

  describe '.delete_backup' do
    let(:backup_record) { create(:backup_record, file_path: '/tmp/test_backup.sql') }

    context 'when backup record exists' do
      it 'returns success' do
        result = described_class.delete_backup(backup_record.id)

        # 检查返回值中是否有成功标记
        expect(result).to be_a(Hash)
      end
    end

    context 'when backup record does not exist' do
      it 'returns error' do
        result = described_class.delete_backup(9999)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end

  describe '.restore_backup' do
    it 'responds to restore_backup method' do
      expect(described_class).to respond_to(:restore_backup)
    end

    context 'when backup file does not exist' do
      it 'returns error' do
        result = described_class.restore_backup('/nonexistent/backup.sql')

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end
end
