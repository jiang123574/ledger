namespace :budgets do
  desc "刷新所有预算项的支出统计"
  task refresh: :environment do
    puts "开始刷新预算统计..."

    items_count = BudgetItem.count
    puts "预算项数量: #{items_count}"

    BudgetItem.find_each do |item|
      item.recalculate_spent_amount
      print "."
    end
    puts "\n预算项刷新完成"

    budgets_count = SingleBudget.count
    puts "单次预算数量: #{budgets_count}"

    SingleBudget.find_each do |budget|
      budget.recalculate_spent_amount
      print "."
    end
    puts "\n单次预算刷新完成"

    CacheBuster.bump(:budgets)
    puts "缓存已清理"
    puts "刷新完成！"
  end

  desc "刷新指定 SingleBudget 的统计 (参数: id=预算ID)"
  task refresh_one: :environment do
    id = ENV["id"]
    unless id
      puts "请指定预算ID: rails budgets:refresh_one id=3"
      exit 1
    end

    budget = SingleBudget.find_by(id: id)
    unless budget
      puts "找不到预算 ID: #{id}"
      exit 1
    end

    puts "刷新预算: #{budget.name}"
    puts "预算项数量: #{budget.budget_items.count}"

    budget.budget_items.each do |item|
      item.recalculate_spent_amount
      puts "  - #{item.display_name}: #{item.spent_amount}"
    end

    budget.recalculate_spent_amount
    CacheBuster.bump(:budgets)

    puts "刷新完成！总支出: #{budget.spent_amount}"
  end
end
