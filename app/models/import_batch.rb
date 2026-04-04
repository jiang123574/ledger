class ImportBatch < ApplicationRecord
  attribute :summary, :json, default: {}
  attribute :records, :json, default: []

  has_many :entries, dependent: :nullify

  scope :recent, -> { order(created_at: :desc) }
end
