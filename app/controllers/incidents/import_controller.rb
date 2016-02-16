class Incidents::ImportController < ApplicationController
  skip_before_filter :require_valid_user!, only: [:import_dispatch, :import]
  before_filter :validate_webhook
  protect_from_forgery except: [:import_dispatch]

  def user_for_paper_trail
    params[:action].to_s.titleize
  end

  def webhook_valid? key, url, params, signature
    data = url
    params.sort.each {|k,v| data = url + k + v}
    digest = OpenSSL::Digest::Digest.new('sha1')
    expected = Base64.encode64(OpenSSL::HMAC.digest(digest, key, data)).strip
    expected == signature
  end

  def validate_webhook
    return if request.head?

    key_env = "WEBHOOK_#{[params[:action], params[:route]].compact.map(&:to_s).join("_").upcase}_KEY"
    key = ENV[key_env]

    url = request.original_url
    signature = request.env['HTTP_X_MANDRILL_SIGNATURE']

    head :unauthorized unless webhook_valid? key, url, request.POST, signature
  end

  def import_dispatch
    if request.head?
      head :ok and return
    end

    json = JSON.parse( params[:mandrill_events])
    json.each do |evt|
      Core::JobLog.capture(self.class.to_s + '#import_dispatch') do |logger, import_log|
        message = evt['msg']
        import_log.message_subject = message['subject']

        import_dispatch_body_handler message, message['text'], import_log
      end
    end

    head :ok
  end

  def import
    if request.head?
      head :ok and return
    end

    json = JSON.parse( params[:mandrill_events])
    json.each do |evt|
      Core::JobLog.capture(self.class.to_s + '#' + params[:route]) do |logger, import_log|
        message = evt['msg']
        import_log.message_subject = message['subject']

        public_send("import_#{params[:route]}", message, import_log)
      end
    end

    head :ok
  end

  def import_dispatch_body_handler(message, body, import_log)
    # Todo: move this to the importer where it belongs
    matches = body.match(/Account: (\d+)/i)
    if matches
      account_number = matches[1]
      chapter = Roster::Chapter.with_directline_account_number_value(account_number).first!
    end
    chapter ||= Roster::Chapter.find(1)

    Incidents::DispatchLog.transaction do
      importer.import_data(chapter, body)
    end
  end

  def importer
    @importer ||= Incidents::DispatchImporter.new
  end

  def import_rco_id(message, log)
    message['attachments'].each do |fname, attach|
      body = attach['content']
      body = Base64.decode64 body if attach['base64']

      puts body

      Roster::RcoIdImporter.new(body).import
    end
  end

end
