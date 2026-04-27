# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

# Note: Turbo navigates by replacing body content, including inline scripts.
# When nonce is present in CSP, browsers ignore 'unsafe-inline', causing Turbo navigation to fail.
# We use 'unsafe-inline' for script-src to support Turbo, which is acceptable for a personal finance app.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.style_src :self, :unsafe_inline
    policy.script_src :self, :unsafe_inline
    policy.img_src :self, :data, :blob
    policy.font_src :self
    policy.connect_src :self
    policy.frame_ancestors :self
  end

  # Report violations without enforcing the policy.
  # config.content_security_policy_report_only = true
end
