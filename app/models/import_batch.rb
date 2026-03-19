class ImportBatch < ApplicationRecord
  attribute :summary, :json, default: {}
  attribute :records, :json, default: []

  has_many :transactions, dependent: :nullify

  scope :recent, -> { order(created_at: :desc) }
end
