require "test_helper"

class ImportServiceTest < ActiveSupport::TestCase
  setup do
    @csv_content = <<~CSV
      日期,类型,金额,账户,分类,备注
      2024-01-15,收入,5000,现金,工资,月薪
      2024-01-16,支出,100,现金,餐饮,午餐
      2024-01-17,支出,50,现金,交通,地铁
    CSV
    
    @temp_file = Tempfile.new([ "test", ".csv" ])
    @temp_file.write(@csv_content)
    @temp_file.rewind
  end

  teardown do
    @temp_file.close
    @temp_file.unlink
  end

  test "should detect CSV format" do
    file = fixture_file_upload(@temp_file.path, "text/csv")
    format = ImportService.send(:detect_format, file)
    assert_equal "csv", format
  end

  test "should parse date correctly" do
    date = ImportService.send(:parse_date, "2024-01-15")
    assert_equal Date.new(2024, 1, 15), date
  end

  test "should parse Chinese date format" do
    date = ImportService.send(:parse_date, "2024年01月15日")
    assert_equal Date.new(2024, 1, 15), date
  end

  test "should parse type correctly" do
    assert_equal "INCOME", ImportService.send(:parse_type, "收入")
    assert_equal "EXPENSE", ImportService.send(:parse_type, "支出")
    assert_equal "TRANSFER", ImportService.send(:parse_type, "转账")
    assert_nil ImportService.send(:parse_type, "其他")
  end

  test "should parse amount correctly" do
    assert_equal 100.5, ImportService.send(:parse_amount, "100.5")
    assert_equal 1000, ImportService.send(:parse_amount, "¥1,000")
    assert_equal -50, ImportService.send(:parse_amount, "(50)")
  end

  test "should suggest field mapping" do
    headers = [ "日期", "类型", "金额", "账户", "分类", "备注" ]
    mapping = ImportService.send(:suggest_mapping, headers)

    assert_equal "date", mapping["日期"]
    assert_equal "type", mapping["类型"]
    assert_equal "amount", mapping["金额"]
    assert_equal "account", mapping["账户"]
    assert_equal "category", mapping["分类"]
    assert_equal "note", mapping["备注"]
  end

  test "should import CSV transactions" do
    file = fixture_file_upload(@temp_file.path, "text/csv")
    results = ImportService.import_csv(file)

    assert_equal 3, results[:success]
    assert_equal 0, results[:failed]
    assert_equal 3, results[:imported_ids].length
  end

  test "should create accounts during import" do
    file = fixture_file_upload(@temp_file.path, "text/csv")
    ImportService.import_csv(file)

    assert Account.exists?(name: "现金")
  end

  test "should create categories during import" do
    file = fixture_file_upload(@temp_file.path, "text/csv")
    ImportService.import_csv(file)

    assert Category.exists?(name: "工资")
    assert Category.exists?(name: "餐饮")
  end

  test "should return templates" do
    templates = ImportService.templates

    assert_instance_of Array, templates
    assert templates.any? { |t| t[:name] == "标准格式" }
  end

  test "should validate file size" do
    # Create a mock file that's too large
    large_file = fixture_file_upload(@temp_file.path, "text/csv")
    large_file.stub(:size, 20.megabytes) do
      validation = ImportService.validate_file(large_file)
      assert_not validation[:valid]
    end
  end
end