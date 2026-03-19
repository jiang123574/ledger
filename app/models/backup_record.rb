class BackupRecord < ApplicationRecord
  validates :filename, :file_path, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: "completed") }

  def human_size
    return 0 unless file_size.to_i > 0
    size = file_size.to_i
    if size < 1024
      "#{size} B"
    elsif size < 1024 * 1024
      "#{(size / 1024.0).round(2)} KB"
    else
      "#{(size / (1024.0 * 1024.0)).round(2)} MB"
    end
  end
end
