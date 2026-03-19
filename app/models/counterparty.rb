class Counterparty < ApplicationRecord
  has_many :receivables, dependent: :nullify

  validates :name, presence: true, uniqueness: true
end
