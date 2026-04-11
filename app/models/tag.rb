# frozen_string_literal: true

class Tag < ApplicationRecord
  has_many :taggings, dependent: :destroy

  validates :name, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_nil: true

  before_validation :set_default_color

  scope :alphabetically, -> { order(:name) }
  scope :by_usage, -> {
    left_joins(:taggings)
      .group(:id)
      .order(Arel.sql("COUNT(taggings.id) DESC"))
  }

  def self.ransackable_attributes(auth_object = nil)
    %w[name color created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[taggings]
  end

  # 兼容视图：如果数据库没有 description 字段，返回 nil
  def description
    read_attribute(:description) if has_attribute?(:description)
  end

  private

  def set_default_color
    self.color ||= generate_random_color
  end

  def generate_random_color
    hue = SecureRandom.rand(360)
    ColorUtils.hsl_to_hex(hue, 65, 55)
  end
end

# 颜色工具类
class ColorUtils
  def self.hsl_to_hex(h, s, l)
    s = s / 100.0
    l = l / 100.0

    c = (1 - (2 * l - 1).abs) * s
    x = c * (1 - ((h / 60.0) % 2 - 1).abs)
    m = l - c / 2

    r, g, b = if h < 60
      [ c, x, 0 ]
    elsif h < 120
      [ x, c, 0 ]
    elsif h < 180
      [ 0, c, x ]
    elsif h < 240
      [ 0, x, c ]
    elsif h < 300
      [ x, 0, c ]
    else
      [ c, 0, x ]
    end

    "##{((r + m) * 255).round.to_s(16).rjust(2, '0')}" \
    "#{((g + m) * 255).round.to_s(16).rjust(2, '0')}" \
    "#{((b + m) * 255).round.to_s(16).rjust(2, '0')}"
  end
end
