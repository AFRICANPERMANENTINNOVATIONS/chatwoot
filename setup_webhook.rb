# Setup unified WhatsApp webhook for PerfectCX
# Usage: bundle exec rails runner setup_webhook.rb

WEBHOOK_TOKEN = ENV.fetch('WHATSAPP_WEBHOOK_VERIFY_TOKEN', '33fb9dc0e921effd4a96d65713943041')

config = InstallationConfig.find_by(name: 'WHATSAPP_WEBHOOK_VERIFY_TOKEN')
if config
  config.value = WEBHOOK_TOKEN
  config.save!
else
  InstallationConfig.create!(name: 'WHATSAPP_WEBHOOK_VERIFY_TOKEN', value: WEBHOOK_TOKEN)
end

puts "WHATSAPP_WEBHOOK_VERIFY_TOKEN: #{WEBHOOK_TOKEN}"
puts ''
puts 'Configure in Meta Developer Dashboard:'
puts "  Webhook URL: #{ENV.fetch('FRONTEND_URL', 'https://app.perfectcx.africa')}/webhooks/whatsapp"
puts "  Verify Token: #{WEBHOOK_TOKEN}"
puts '  Subscribe to: messages'
puts ''
puts 'Done'
