class Campaigns::Twilio::SendBatchJob < ApplicationJob
  queue_as :low

  def perform(campaign_id, contact_ids)
    campaign = Campaign.find_by(id: campaign_id)
    return if campaign.nil?
    return unless campaign.inbox&.inbox_type == 'Twilio SMS'

    Twilio::OneoffSmsCampaignService.new(campaign: campaign).process_contact_ids(contact_ids)
  end
end
