# Setup installation limits for PerfectCX
# Usage: bundle exec rails runner setup_limits.rb

configs = {
  'INSTALLATION_PRICING_PLAN_QUANTITY' => 999999,
  'ACCOUNT_AGENTS_LIMIT' => 999999,
  'INSTALLATION_PRICING_PLAN' => 'enterprise'
}

configs.each do |name, value|
  config = InstallationConfig.find_or_create_by(name: name)
  config.update!(value: value)
  puts "#{name}: #{value}"
end

# Update all existing accounts
Account.find_each do |account|
  account.update!(limits: { 'agents' => 100_000, 'inboxes' => 100_000 })
  puts "Account ##{account.id} (#{account.name}): limits updated"
end

puts "Done - All limits removed"
