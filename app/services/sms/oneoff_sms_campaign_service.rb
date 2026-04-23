class Sms::OneoffSmsCampaignService
  pattr_initialize [:campaign!]

  def perform
    raise "Invalid campaign #{campaign.id}" if campaign.inbox.inbox_type != 'Sms' || !campaign.one_off?
    raise 'Completed Campaign' if campaign.completed?

    # marks campaign completed so that other jobs won't pick it up
    campaign.completed!

    process_audience(resolve_audience_contact_ids)
  end

  def process_contact_ids(contact_ids)
    campaign.account.contacts.where(id: contact_ids).find_each do |contact|
      process_contact(contact)
    end
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def resolve_audience_contact_ids
    Campaigns::AudienceResolver.new(account: campaign.account, audience: campaign.audience).contact_ids
  end

  def process_audience(contact_ids)
    Rails.logger.info "Processing #{contact_ids.size} contacts for campaign #{campaign.id}"

    if batching_enabled?
      enqueue_batches(contact_ids)
    else
      process_contact_ids(contact_ids)
    end

    Rails.logger.info "Campaign #{campaign.id} processing completed"
  end

  def process_contact(contact)
    return if contact.phone_number.blank?

    content = Liquid::CampaignTemplateService.new(campaign: campaign, contact: contact).call(campaign.message)
    send_message(to: contact.phone_number, content: content)
  end

  def send_message(to:, content:)
    channel.send_text_message(to, content)
  rescue StandardError => e
    Rails.logger.error("[SMS Campaign #{campaign.id}] Failed to send to #{to}: #{e.message}")
  end

  def batching_enabled?
    batch_size.positive?
  end

  def batch_size
    campaign.trigger_rules&.dig('batch_size').to_i
  end

  def batch_interval_minutes
    [campaign.trigger_rules&.dig('batch_interval_minutes').to_i, 0].max
  end

  def enqueue_batches(contact_ids)
    contact_ids.each_slice(batch_size).with_index do |slice, index|
      Campaigns::Sms::SendBatchJob
        .set(wait: (index * batch_interval_minutes).minutes)
        .perform_later(campaign.id, slice)
    end
  end
end
