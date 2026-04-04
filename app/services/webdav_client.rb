# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "fileutils"

# WebDAV client for remote backup storage.
# Handles upload, download, list, delete, and connection testing.
class WebDAVClient
  class WebDAVError < StandardError; end

  def initialize(url:, username:, password:, directory: "/")
    @url = url.chomp("/")
    @username = username
    @password = password
    @directory = directory
  end

  def configured?
    @url.present?
  end

  def test_connection
    uri = build_uri("")
    request = Net::HTTP::Propfind.new(uri)
    request.basic_auth(@username, @password)
    request["Depth"] = "0"

    response = execute_request(uri, request)

    if response.code.to_i < 400
      { success: true, message: "连接成功" }
    else
      { success: false, error: "连接失败: #{response.code} #{response.message}" }
    end
  rescue StandardError => e
    { success: false, error: "连接失败: #{e.message}" }
  end

  def upload(file_path, filename)
    remote_path = "#{@directory}/#{filename}".gsub("//", "/")
    uri = build_uri(remote_path)

    ensure_directory

    request = Net::HTTP::Put.new(uri)
    request.basic_auth(@username, @password)
    request.content_type = "application/octet-stream"
    request.body_stream = File.open(file_path, "rb")

    response = execute_request(uri, request)

    if response.code.to_i < 400
      { success: true, url: uri.to_s }
    else
      { success: false, error: "上传失败: #{response.code}" }
    end
  rescue StandardError => e
    { success: false, error: "上传失败: #{e.message}" }
  end

  def download(filename, local_path)
    remote_path = "#{@directory}/#{filename}".gsub("//", "/")
    uri = build_uri(remote_path)

    request = Net::HTTP::Get.new(uri)
    request.basic_auth(@username, @password)

    response = execute_request(uri, request)

    if response.code.to_i == 200
      File.open(local_path, "wb") { |f| f.write(response.body) }
      { success: true, path: local_path }
    else
      { success: false, error: "下载失败: #{response.code}" }
    end
  rescue StandardError => e
    { success: false, error: "下载失败: #{e.message}" }
  end

  def list_files
    uri = build_uri("")

    request = Net::HTTP::Propfind.new(uri)
    request.basic_auth(@username, @password)
    request["Depth"] = "1"
    request.content_type = "application/xml"

    response = execute_request(uri, request)

    return [] unless response.code.to_i == 207

    parse_propfind_response(response.body)
  rescue StandardError => e
    Rails.logger.error("WebDAV list failed: #{e.message}")
    []
  end

  def delete(filename)
    remote_path = "#{@directory}/#{filename}".gsub("//", "/")
    uri = build_uri(remote_path)

    request = Net::HTTP::Delete.new(uri)
    request.basic_auth(@username, @password)

    response = execute_request(uri, request)

    if response.code.to_i < 400
      { success: true }
    else
      { success: false, error: "删除失败: #{response.code}" }
    end
  end

  def url_for(filename)
    "#{@url}#{@directory}/#{filename}".gsub("//", "/")
  end

  private

  def build_uri(path)
    URI.parse("#{@url}#{@directory}/#{path}".gsub("//", "/"))
  end

  def execute_request(uri, request)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.read_timeout = 60
    http.request(request)
  end

  def ensure_directory
    return if @directory == "/" || @directory.empty?

    uri = build_uri("")
    request = Net::HTTP::Mkcol.new(uri)
    request.basic_auth(@username, @password)

    execute_request(uri, request)
  rescue StandardError
    nil
  end

  def parse_propfind_response(xml_body)
    require "nokogiri"

    doc = Nokogiri::XML(xml_body)
    doc.remove_namespaces!

    doc.xpath("//response").filter_map do |response|
      href = response.at_xpath("href")&.text
      next if href.nil?

      filename = File.basename(URI.decode_www_form_component(href))
      next if filename.empty?

      {
        name: filename,
        href: href,
        size: response.at_xpath("propstat/prop/getcontentlength")&.text&.to_i,
        last_modified: response.at_xpath("propstat/prop/getlastmodified")&.text
      }
    end
  rescue StandardError => e
    Rails.logger.error("Failed to parse WebDAV response: #{e.message}")
    []
  end
end
