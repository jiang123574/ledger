# frozen_string_literal: true

require "rails_helper"

RSpec.describe GenerateDuePlansJob, type: :job do
  it "calls Plan.generate_all_due!" do
    expect(Plan).to receive(:generate_all_due!)
    described_class.perform_now
  end

  it "is enqueued on the default queue" do
    expect(described_class.new.queue_name).to eq("default")
  end
end
