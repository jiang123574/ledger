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
        expect(result[:success]).to be true
        # 验证记录已被删除
        expect { BackupRecord.find(backup_record.id) }.to raise_error(ActiveRecord::RecordNotFound)
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

    let(:backup_path) { Rails.root.join('tmp', 'backups', 'restore_test.sql').to_s }

    before do
      FileUtils.mkdir_p(File.dirname(backup_path))
    end

    after do
      FileUtils.rm_f(backup_path)
    end

    context 'when backup file does not exist' do
      it 'returns error' do
        result = described_class.restore_backup('/nonexistent/backup.sql')

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end

    context 'when restore succeeds' do
      before do
        File.write(backup_path, "-- dummy backup content\n")
        allow(described_class).to receive(:execute_psql_restore).and_return(success: true)
        allow(described_class).to receive(:update_caches_after_restore)
      end

      it 'returns success and updates caches' do
        result = described_class.restore_backup(backup_path)

        expect(result[:success]).to be true
        expect(described_class).to have_received(:update_caches_after_restore)
      end
    end

    context 'when restore fails due to psql error' do
      before do
        File.write(backup_path, "-- dummy backup content\n")
        allow(described_class).to receive(:execute_psql_restore).and_return(success: false, error: 'psql: error')
      end

      it 'returns false and forwards the error message' do
        result = described_class.restore_backup(backup_path)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('psql: error')
      end
    end

    it 'restores with ON_ERROR_STOP and single-transaction options' do
      db_config = {
        'database' => 'ledger_test',
        'host' => 'localhost',
        'username' => 'postgres',
        'password' => 'secret'
      }
      restore_path = Rails.root.join('tmp', 'backups', 'restore_command_test.sql').to_s
      File.write(restore_path, "-- dummy backup content\n")
      status = instance_double(Process::Status, success?: true)

      expect(Open3).to receive(:capture3).with(
        { 'PGPASSWORD' => 'secret' },
        'psql',
        '-h', 'localhost',
        '-U', 'postgres',
        '-d', 'ledger_test',
        '-1',
        '-v', 'ON_ERROR_STOP=1',
        '-f', restore_path
      ).and_return(['', '', status])

      described_class.send(:execute_psql_restore, db_config, restore_path)

      FileUtils.rm_f(restore_path)
    end
  end
end
