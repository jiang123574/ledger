class GenerateDuePlansJob < ApplicationJob
  queue_as :default

  def perform
    Plan.generate_all_due!
  end
end
