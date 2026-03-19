class ImportBatch < ApplicationRecord
  serialize :summary, JSON
  serialize :records, JSON

  has_many :transactions, dependent: :nullify

  scope :recent, -> { order(created_at: :desc) }
end
