class AutomationRules::ActionService < ActionService
  def initialize(rule, account, conversation)
    super(conversation)
    @rule = rule
    @account = account
    Current.executed_by = rule
  end

  def perform
    @rule.actions.each do |action|
      @conversation.reload
      action = action.with_indifferent_access
      begin
        send(action[:action_name], action[:action_params])
      rescue StandardError => e
        ChatwootExceptionTracker.new(e, account: @account).capture_exception
      end
    end
  ensure
    Current.reset
  end

  private

  def send_attachment(blob_ids)
    return if conversation_a_tweet?

    return unless @rule.files.attached?

    blobs = ActiveStorage::Blob.where(id: blob_ids)

    return if blobs.blank?

    params = { content: nil, private: false, attachments: blobs }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_webhook_event(webhook_url)
    payload = @conversation.webhook_data.merge(event: "automation_event.#{@rule.event_name}")
    WebhookJob.perform_later(webhook_url[0], payload)
  end

  def send_message(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: false, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_interactive_message(message)
    dispatch_whatsapp_interactive(message[0])
  end

  # Send a WhatsApp list message
  # Params: ["body_text", "button_label", "section_title", "row1_title:row1_id", "row2_title:row2_id", ...]
  def send_interactive_list(params)
    body_text = params[0]
    button_label = params[1] || 'Menu'
    section_title = params[2] || 'Options'
    rows = params[3..].map do |row|
      title, id, description = row.split(':')
      { id: id || title.parameterize, title: title.truncate(24) }.tap do |r|
        r[:description] = description.truncate(72) if description.present?
      end
    end

    payload = {
      type: 'list',
      body: { text: body_text },
      action: { button: button_label.truncate(20), sections: [{ title: section_title, rows: rows }] }
    }
    dispatch_whatsapp_interactive(payload.to_json)
  end

  # Send WhatsApp reply buttons (max 3)
  # Params: ["body_text", "button1_title:button1_id", "button2_title:button2_id", ...]
  def send_interactive_buttons(params)
    body_text = params[0]
    buttons = params[1..3].map do |btn|
      title, id = btn.split(':')
      { type: 'reply', reply: { id: id || title.parameterize, title: title.truncate(20) } }
    end

    payload = { type: 'button', body: { text: body_text }, action: { buttons: buttons } }
    dispatch_whatsapp_interactive(payload.to_json)
  end

  # Send WhatsApp CTA URL button
  # Params: ["body_text", "button_label", "url"]
  def send_interactive_cta(params)
    body_text = params[0]
    button_label = params[1] || 'Visiter'
    url = params[2]

    payload = {
      type: 'cta_url',
      body: { text: body_text },
      action: { name: 'cta_url', parameters: { display_text: button_label.truncate(20), url: url } }
    }
    dispatch_whatsapp_interactive(payload.to_json)
  end

  def add_private_note(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: true, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation.reload, params).perform
  end

  def send_email_to_team(params)
    teams = Team.where(id: params[0][:team_ids])

    teams.each do |team|
      break unless @account.within_email_rate_limit?

      TeamNotifications::AutomationNotificationMailer.conversation_creation(@conversation, team, params[0][:message])&.deliver_now
      @account.increment_email_sent_count
    end
  end

  def dispatch_whatsapp_interactive(json_content)
    return if conversation_a_tweet?

    channel = @conversation.inbox&.channel
    return send_message([json_content]) unless channel.is_a?(Channel::Whatsapp)

    phone_number = @conversation.contact&.phone_number
    return if phone_number.blank?

    parsed = JSON.parse(json_content)
    msg = OpenStruct.new(content: json_content, content_attributes: {})
    response = channel.provider_service.send_whatsapp_interactive_message(phone_number, msg)

    @conversation.messages.create!(
      account_id: @account.id,
      inbox_id: @conversation.inbox_id,
      message_type: :outgoing,
      content: parsed.dig('body', 'text') || json_content,
      content_attributes: { automation_rule_id: @rule.id, interactive_payload: parsed },
      source_id: response
    )
  rescue JSON::ParserError
    send_message([json_content])
  end
end
