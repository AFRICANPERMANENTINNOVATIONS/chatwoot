# Setup trial period for all active accounts without a trial date
# Usage: bundle exec rails runner setup_trial.rb
#
# To set trial for a specific account:
#   ACCOUNT_ID=1 bundle exec rails runner setup_trial.rb
#
# To set custom trial days:
#   TRIAL_DAYS=14 bundle exec rails runner setup_trial.rb

trial_days = ENV.fetch('TRIAL_DAYS', 7).to_i
account_id = ENV.fetch('ACCOUNT_ID', nil)

if account_id
  accounts = Account.where(id: account_id)
else
  accounts = Account.where(status: :active)
end

count = 0
accounts.find_each do |account|
  next if account.custom_attributes['trial_expires_at'].present?

  expires_at = (Time.current + trial_days.days).iso8601
  account.custom_attributes['trial_expires_at'] = expires_at
  account.save!
  count += 1
  puts "Account ##{account.id} (#{account.name}): trial expires #{expires_at}"
end

puts "Done — #{count} account(s) updated with #{trial_days}-day trial"
