# Manage trial accounts
# Usage:
#   ACTION=status bundle exec rails runner manage_trial.rb
#   ACTION=extend ACCOUNT_ID=1 DAYS=7 bundle exec rails runner manage_trial.rb
#   ACTION=activate ACCOUNT_ID=1 bundle exec rails runner manage_trial.rb
#   ACTION=remove_trial ACCOUNT_ID=1 bundle exec rails runner manage_trial.rb

action = ENV.fetch('ACTION', 'status')
account_id = ENV.fetch('ACCOUNT_ID', nil)

case action
when 'status'
  puts "%-6s %-30s %-12s %-25s %s" % ['ID', 'Name', 'Status', 'Trial Expires', 'Days Left']
  puts '-' * 100

  Account.order(:id).find_each do |account|
    expires = account.custom_attributes['trial_expires_at']
    if expires.present?
      expires_at = Time.zone.parse(expires)
      days_left = (expires_at.to_date - Time.current.to_date).to_i
      days_display = days_left.negative? ? "EXPIRED (#{days_left.abs}d ago)" : "#{days_left} days"
    else
      expires_at = nil
      days_display = 'No trial'
    end

    puts "%-6d %-30s %-12s %-25s %s" % [
      account.id,
      account.name.truncate(28),
      account.status,
      expires_at&.strftime('%Y-%m-%d %H:%M') || '-',
      days_display
    ]
  end

when 'extend'
  raise 'ACCOUNT_ID required' if account_id.blank?

  days = ENV.fetch('DAYS', 7).to_i
  account = Account.find(account_id)
  current_expires = account.custom_attributes['trial_expires_at']

  base_time = if current_expires.present?
                [Time.zone.parse(current_expires), Time.current].max
              else
                Time.current
              end

  new_expires = (base_time + days.days).iso8601
  account.custom_attributes['trial_expires_at'] = new_expires
  account.update!(status: :active) if account.suspended?
  account.save!

  puts "Account ##{account.id} (#{account.name}): trial extended to #{new_expires}"

when 'activate'
  raise 'ACCOUNT_ID required' if account_id.blank?

  account = Account.find(account_id)
  account.custom_attributes.delete('trial_expires_at')
  account.update!(status: :active)
  account.save!

  puts "Account ##{account.id} (#{account.name}): activated (trial removed, full access)"

when 'remove_trial'
  raise 'ACCOUNT_ID required' if account_id.blank?

  account = Account.find(account_id)
  account.custom_attributes.delete('trial_expires_at')
  account.save!

  puts "Account ##{account.id} (#{account.name}): trial removed (keeps current status: #{account.status})"

else
  puts "Unknown action: #{action}"
  puts 'Available: status, extend, activate, remove_trial'
end
