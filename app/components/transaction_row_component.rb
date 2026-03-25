class TransactionRowComponent < ViewComponent::Base
  include ApplicationComponent

  def initialize(transaction:, show_account: true)
    @transaction = transaction
    @show_account = show_account
  end

  def call
    content_tag(:div, class: "flex justify-between items-center py-3 border-b border-gray-100 last:border-b-0") do
      concat(left_content)
      concat(right_content)
    end
  end

  private

  def left_content
    content_tag(:div) do
      concat(content_tag(:p, @transaction.category || "未分类", class: "font-medium text-gray-900"))
      concat(content_tag(:p, details_text, class: "text-sm text-gray-500"))
    end
  end

  def right_content
    content_tag(:div, class: "text-right") do
      concat(content_tag(:span, @transaction.display_amount, class: amount_class))
      if @transaction.note.present?
        concat(content_tag(:p, @transaction.note, class: "text-xs text-gray-400 mt-1 max-w-[150px] truncate"))
      end
    end
  end

  def amount_class
    base = "font-medium"
    @transaction.income? ? "#{base} text-income" : "#{base} text-expense"
  end

  def details_text
    parts = []
    parts << @transaction.date.strftime("%Y-%m-%d")
    parts << @transaction.account_name if @show_account
    parts.join(" · ")
  end
end
