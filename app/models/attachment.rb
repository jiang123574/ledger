class Attachment < ApplicationRecord
  belongs_to :entry, optional: true

  validates :file_path, :file_name, :file_type, presence: true
  validate :ensure_entry_present

  def image?
    file_type.to_s.start_with?("image/")
  end

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

  private

  def ensure_entry_present
    if entry.blank?
      errors.add(:base, "必须关联到 Entry")
    end
  end
end
