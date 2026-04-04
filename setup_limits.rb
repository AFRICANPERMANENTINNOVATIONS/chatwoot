# Setup installation limits for PerfectCX
# Usage: bundle exec rails runner setup_limits.rb

configs = {
  'INSTALLATION_PRICING_PLAN_QUANTITY' => 999_999,
  'ACCOUNT_AGENTS_LIMIT' => 999_999,
  'INSTALLATION_PRICING_PLAN' => 'premium'
}

configs.each do |name, val|
  config = InstallationConfig.find_by(name: name)
  if config
    config.value = val
    config.save!
  else
    InstallationConfig.create!(name: name, value: val)
  end
  puts "#{name}: #{val}"
end

# Update all existing accounts
Account.find_each do |account|
  account.update!(limits: { 'agents' => 999_999, 'inboxes' => 999_999 })
  puts "Account ##{account.id} (#{account.name}): limits updated"
end

puts 'Done - All limits removed'
