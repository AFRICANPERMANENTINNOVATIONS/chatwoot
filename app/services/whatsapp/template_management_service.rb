class Whatsapp::TemplateManagementService
  WHATSAPP_API_VERSION = 'v14.0'.freeze

  MEDIA_CONTENT_TYPES = {
    'image' => 'image/png',
    'video' => 'video/mp4',
    'document' => 'application/pdf'
  }.freeze

  def initialize(whatsapp_channel)
    @whatsapp_channel = whatsapp_channel
  end

  def create_template(params)
    validate_template_name!(params[:name])

    components = params[:components] || []
    components = process_media_header(components) if media_header?(components)

    response = HTTParty.post(
      "#{business_account_path}/message_templates",
      headers: api_headers,
      body: {
        name: params[:name],
        language: params[:language] || 'en',
        category: params[:category] || 'UTILITY',
        components: components
      }.to_json
    )

    if response.success?
      {
        success: true,
        template_id: response['id'],
        template_name: response['name'] || params[:name],
        status: response['status'] || 'PENDING',
        language: params[:language] || 'en'
      }
    else
      Rails.logger.error "WhatsApp template creation failed: #{response.code} - #{response.body}"
      { success: false, error: 'Template creation failed', response_body: response.body }
    end
  end

  def delete_template(template_name)
    response = HTTParty.delete(
      "#{business_account_path}/message_templates?name=#{template_name}",
      headers: api_headers
    )
    { success: response.success?, response_body: response.body }
  end

  def list_templates
    fetch_all_templates("#{business_account_path}/message_templates?access_token=#{@whatsapp_channel.provider_config['api_key']}")
  end

  def get_template(template_name)
    response = HTTParty.get(
      "#{business_account_path}/message_templates?name=#{template_name}",
      headers: api_headers
    )

    if response.success? && response['data']&.any?
      { success: true, templates: response['data'] }
    else
      { success: false, error: 'Template not found' }
    end
  rescue StandardError => e
    Rails.logger.error "Error fetching template: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def media_header?(components)
    header = components.find { |c| c['type'] == 'HEADER' || c[:type] == 'HEADER' }
    return false unless header

    format = header['format'] || header[:format]
    %w[IMAGE VIDEO DOCUMENT].include?(format&.upcase)
  end

  def process_media_header(components)
    components.map do |component|
      comp = (component.is_a?(ActionController::Parameters) ? component.to_unsafe_h : component).deep_symbolize_keys
      next component unless comp[:type] == 'HEADER' && %w[IMAGE VIDEO DOCUMENT].include?(comp[:format]&.upcase)

      media_url = comp.dig(:example, :media_url)
      raise ArgumentError, 'Media URL is required for media header templates' if media_url.blank?

      handle = upload_media_to_meta(media_url, comp[:format].downcase)
      raise ArgumentError, 'Failed to upload media to Meta' if handle.blank?

      # Build the header component with the handle (Meta's required format)
      {
        type: 'HEADER',
        format: comp[:format].upcase,
        example: { header_handle: [handle] }
      }
    end
  end

  def upload_media_to_meta(media_url, media_type)
    # Step 1: Get the file data (from Active Storage or external URL)
    blob = find_active_storage_blob(media_url)
    if blob
      file_data = blob.download
      content_type = blob.content_type
    else
      file_data = download_file(media_url)
      content_type = MEDIA_CONTENT_TYPES[media_type] || 'application/octet-stream'
    end
    raise ArgumentError, "Failed to download media from #{media_url}" if file_data.blank?

    file_length = file_data.bytesize

    # Step 2: Create an upload session
    app_id = @whatsapp_channel.provider_config['app_id'].presence || GlobalConfigService.load('WHATSAPP_APP_ID', '')
    raise ArgumentError, 'WHATSAPP_APP_ID is not configured. Set it in channel provider config or Super Admin > Installation Configs.' if app_id.blank?

    Rails.logger.info "Meta upload: file_length=#{file_length}, content_type=#{content_type}, app_id=#{app_id}"

    upload_url = "#{api_base_path}/#{WHATSAPP_API_VERSION}/#{app_id}/uploads"
    session_response = HTTParty.post(
      upload_url,
      headers: api_headers,
      body: {
        file_length: file_length,
        file_type: content_type
      }.to_json
    )

    unless session_response.success? && session_response['id'].present?
      Rails.logger.error "Media upload session failed: #{session_response.code} - #{session_response.body}"
      error_msg = extract_meta_error(session_response.body) || 'Failed to create upload session with Meta'
      raise ArgumentError, error_msg
    end

    upload_session_id = session_response['id']
    Rails.logger.info "Meta upload session created: #{upload_session_id}"

    # Step 3: Upload the file bytes to the session
    upload_response = HTTParty.post(
      "#{api_base_path}/#{WHATSAPP_API_VERSION}/#{upload_session_id}",
      headers: {
        'Authorization' => "OAuth #{@whatsapp_channel.provider_config['api_key']}",
        'file_offset' => '0',
        'Content-Type' => content_type
      },
      body: file_data
    )

    unless upload_response.success? && upload_response['h'].present?
      Rails.logger.error "Media upload failed: #{upload_response.code} - #{upload_response.body}"
      error_msg = extract_meta_error(upload_response.body) || 'Failed to upload media to Meta'
      raise ArgumentError, error_msg
    end

    upload_response['h']
  end

  def download_file(url)
    blob = find_active_storage_blob(url)
    return blob.download if blob

    response = HTTParty.get(url, follow_redirects: true, timeout: 30)
    response.success? ? response.body : nil
  rescue StandardError => e
    Rails.logger.error "Failed to download file from #{url}: #{e.message}"
    nil
  end

  def find_active_storage_blob(url)
    uri = URI.parse(url)
    return nil unless uri.path.include?('/rails/active_storage/')

    # Extract signed_id from redirect blob URLs: /rails/active_storage/blobs/redirect/:signed_id/:filename
    match = uri.path.match(%r{/rails/active_storage/blobs/redirect/([^/]+)})
    # Also handle proxy URLs: /rails/active_storage/blobs/proxy/:signed_id/:filename
    match ||= uri.path.match(%r{/rails/active_storage/blobs/proxy/([^/]+)})
    return nil unless match

    ActiveStorage::Blob.find_signed(match[1])
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound => e
    Rails.logger.error "Failed to find Active Storage blob: #{e.message}"
    nil
  end

  def validate_template_name!(name)
    raise ArgumentError, 'Template name is required' if name.blank?
    raise ArgumentError, 'Template name must contain only lowercase letters, numbers, and underscores' unless name.match?(/\A[a-z0-9_]+\z/)
  end

  def fetch_all_templates(url)
    response = HTTParty.get(url)
    return [] unless response.success?

    next_url = response.dig('paging', 'next')
    templates = response['data'] || []
    templates += fetch_all_templates(next_url) if next_url.present?
    templates
  end

  def business_account_path
    "#{api_base_path}/#{WHATSAPP_API_VERSION}/#{@whatsapp_channel.provider_config['business_account_id']}"
  end

  def api_headers
    {
      'Authorization' => "Bearer #{@whatsapp_channel.provider_config['api_key']}",
      'Content-Type' => 'application/json'
    }
  end

  def extract_meta_error(response_body)
    return nil if response_body.blank?

    data = JSON.parse(response_body)
    error = data['error'] || {}
    error['error_user_msg'] || error['message']
  rescue JSON::ParserError
    nil
  end

  def api_base_path
    ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
  end
end
