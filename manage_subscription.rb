# Manage PerfectCX subscriptions
# Usage:
#   ACTION=status bundle exec rails runner manage_subscription.rb
#   ACTION=activate ACCOUNT_ID=1 PLAN=pro_2 MONTHS=1 bundle exec rails runner manage_subscription.rb
#   ACTION=renew ACCOUNT_ID=1 MONTHS=1 bundle exec rails runner manage_subscription.rb
#   ACTION=suspend ACCOUNT_ID=1 bundle exec rails runner manage_subscription.rb
#   ACTION=plans bundle exec rails runner manage_subscription.rb

action = ENV.fetch('ACTION', 'status')
account_id = ENV.fetch('ACCOUNT_ID', nil)

case action
when 'status'
  puts "%-6s %-25s %-12s %-10s %-6s %-22s %s" % %w[ID Name Status Plan Agents Expires Days]
  puts '-' * 110

  Account.order(:id).find_each do |account|
    service = Perfectcx::SubscriptionService.new(account)
    s = service.status

    puts "%-6d %-25s %-12s %-10s %-6d %-22s %s" % [
      account.id,
      account.name.truncate(23),
      s[:status],
      s[:plan],
      s[:agents_used],
      s[:expires_at] || '-',
      s[:active] ? "#{s[:days_remaining]}d" : 'EXPIRED'
    ]
  end

when 'activate'
  raise 'ACCOUNT_ID required' if account_id.blank?

  plan = ENV.fetch('PLAN', 'pro_2')
  months = ENV.fetch('MONTHS', 1).to_i
  ref = ENV.fetch('REF', "manual_#{Time.current.to_i}")

  account = Account.find(account_id)
  service = Perfectcx::SubscriptionService.new(account)
  result = service.activate_plan(plan, months: months, payment_reference: ref)

  puts "Account ##{account.id} (#{account.name}): #{plan} activated, expires #{result[:expires_at]}"

when 'renew'
  raise 'ACCOUNT_ID required' if account_id.blank?

  months = ENV.fetch('MONTHS', 1).to_i
  ref = ENV.fetch('REF', "manual_renewal_#{Time.current.to_i}")

  account = Account.find(account_id)
  service = Perfectcx::SubscriptionService.new(account)
  result = service.renew(months: months, payment_reference: ref)

  puts "Account ##{account.id} (#{account.name}): renewed, expires #{result[:expires_at]}"

when 'suspend'
  raise 'ACCOUNT_ID required' if account_id.blank?

  account = Account.find(account_id)
  service = Perfectcx::SubscriptionService.new(account)
  service.suspend

  puts "Account ##{account.id} (#{account.name}): suspended"

when 'plans'
  puts "Available plans:"
  Perfectcx::SubscriptionService::PLANS.each do |key, plan|
    price = plan[:price].positive? ? "#{plan[:price]} FCFA/mois" : (key == 'trial' ? 'Gratuit 7 jours' : 'Sur devis')
    puts "  %-12s %-25s %d agents   %s" % [key, plan[:label] || key, plan[:agents], price]
  end

else
  puts "Unknown action: #{action}"
  puts 'Available: status, activate, renew, suspend, plans'
end
