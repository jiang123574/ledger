require 'rails_helper'

RSpec.describe ImportBatch do
  describe 'attributes' do
    it 'has summary attribute with default empty hash' do
      batch = ImportBatch.new
      expect(batch.summary).to eq({})
    end

    it 'has records attribute with default empty array' do
      batch = ImportBatch.new
      expect(batch.records).to eq([])
    end
  end

  describe 'scopes' do
    describe '.recent' do
      before do
        ImportBatch.destroy_all
      end

      it 'orders by created_at descending' do
        older = ImportBatch.create!(created_at: 2.days.ago, summary: {})
        newer = ImportBatch.create!(created_at: 1.day.ago, summary: {})

        batches = ImportBatch.recent.to_a
        expect(batches.first.id).to eq newer.id
        expect(batches.second.id).to eq older.id
      end
    end
  end

  describe 'storing summary data' do
    it 'can store summary statistics' do
      batch = ImportBatch.create!(
        summary: { 'total' => 100, 'imported' => 95, 'skipped' => 5 }
      )
      expect(batch.summary['total']).to eq 100
      expect(batch.summary['imported']).to eq 95
    end

    it 'can store record details' do
      batch = ImportBatch.create!(
        records: [
          { 'row' => 1, 'status' => 'success', 'entry_id' => 123 },
          { 'row' => 2, 'status' => 'skipped', 'reason' => 'duplicate' }
        ]
      )
      expect(batch.records.length).to eq 2
      expect(batch.records.first['status']).to eq 'success'
    end
  end

  describe 'timestamps' do
    it 'has created_at and updated_at' do
      batch = ImportBatch.create!
      expect(batch.created_at).to be_present
      expect(batch.updated_at).to be_present
    end
  end
end
