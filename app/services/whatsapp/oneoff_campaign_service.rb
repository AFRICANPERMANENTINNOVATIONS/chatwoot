class Whatsapp::OneoffCampaignService
  pattr_initialize [:campaign!]

  def perform
    validate_campaign!
    # marks campaign completed so that other jobs won't pick it up
    campaign.completed!
    process_audience(extract_audience_labels)
  end

  # Iterates contacts identified by ids and sends the template message.
  # Used by Campaigns::Whatsapp::SendBatchJob when a campaign is split into
  # spaced batches; safe to call in isolation.
  def process_contact_ids(contact_ids)
    campaign.account.contacts.where(id: contact_ids).find_each do |contact|
      process_contact(contact)
    end
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def validate_campaign_type!
    raise "Invalid campaign #{campaign.id}" unless whatsapp_campaign? && campaign.one_off?
  end

  def whatsapp_campaign?
    campaign.inbox.inbox_type == 'Whatsapp'
  end

  def validate_campaign_status!
    raise 'Completed Campaign' if campaign.completed?
  end

  def validate_provider!
    raise 'WhatsApp Cloud provider required' if channel.provider != 'whatsapp_cloud'
  end

  def validate_feature_flag!
    raise 'WhatsApp campaigns feature not enabled' unless campaign.account.feature_enabled?(:whatsapp_campaign)
  end

  def validate_campaign!
    validate_campaign_type!
    validate_campaign_status!
    validate_provider!
    validate_feature_flag!
  end

  def extract_audience_labels
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    campaign.account.labels.where(id: audience_label_ids).pluck(:title)
  end

  def process_contact(contact)
    Rails.logger.info "Processing contact: #{contact.name} (#{contact.phone_number})"

    if contact.phone_number.blank?
      Rails.logger.info "Skipping contact #{contact.name} - no phone number"
      return
    end

    if campaign.template_params.blank?
      Rails.logger.error "Skipping contact #{contact.name} - no template_params found for WhatsApp campaign"
      return
    end

    send_whatsapp_template_message(to: contact.phone_number, contact: contact)
  end

  def process_audience(audience_labels)
    contact_ids = campaign.account.contacts.tagged_with(audience_labels, any: true).pluck(:id)
    Rails.logger.info "Processing #{contact_ids.size} contacts for campaign #{campaign.id}"

    if batching_enabled?
      enqueue_batches(contact_ids)
    else
      process_contact_ids(contact_ids)
    end

    Rails.logger.info "Campaign #{campaign.id} processing completed"
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
      Campaigns::Whatsapp::SendBatchJob
        .set(wait: (index * batch_interval_minutes).minutes)
        .perform_later(campaign.id, slice)
    end
  end

  def send_whatsapp_template_message(to:, contact:)
    personalized_params = interpolate_contact_variables(campaign.template_params, contact)

    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: personalized_params
    )

    name, namespace, lang_code, processed_parameters = processor.call

    return if name.blank?

    channel.send_template(to, {
                            name: name,
                            namespace: namespace,
                            lang_code: lang_code,
                            parameters: processed_parameters
                          }, nil)

  rescue StandardError => e
    Rails.logger.error "Failed to send WhatsApp template message to #{to}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
    # continue processing remaining contacts
    nil
  end

  def interpolate_contact_variables(params, contact)
    liquid_service = Liquid::CampaignTemplateService.new(campaign: campaign, contact: contact)
    deep_interpolate(params, liquid_service)
  end

  def deep_interpolate(obj, liquid_service)
    case obj
    when String
      obj.include?('{{') ? liquid_service.call(obj) : obj
    when Hash
      obj.transform_values { |v| deep_interpolate(v, liquid_service) }
    when Array
      obj.map { |v| deep_interpolate(v, liquid_service) }
    else
      obj
    end
  end
end
