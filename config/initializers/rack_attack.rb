# frozen_string_literal: true

# API Rate Limiting Configuration
# Protects against abuse and ensures fair usage

Rack::Attack.throttle("api/ip", limit: 100, period: 1.minute) do |req|
  req.ip if req.path.start_with?("/api/")
end

# Throttle POST requests more strictly
Rack::Attack.throttle("api/post", limit: 20, period: 1.minute) do |req|
  req.ip if req.post? && req.path.start_with?("/api/")
end

# Throttle transaction creation
Rack::Attack.throttle("transactions/create", limit: 30, period: 1.minute) do |req|
  req.ip if req.post? && req.path.include?("/transactions")
end

# Block clearly malicious bots (only aggressive scanners, not search engines or monitoring)
Rack::Attack.blocklist("block malicious bots") do |req|
  req.user_agent&.match?(/(masscan|nikto|nmap|sqlmap|dirbuster|gobuster|zgrab)/i)
end

# Allow localhost in development
if Rails.env.development?
  Rack::Attack.safelist("allow localhost") do |req|
    req.ip == "127.0.0.1" || req.ip == "::1"
  end
end

# Custom throttle response
Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env["rack.attack.match_data"]
  retry_after = match_data[:period]
  [
    429,
    { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
    [ { error: "请求过于频繁，请稍后再试", retry_after: retry_after }.to_json ]
  ]
end
