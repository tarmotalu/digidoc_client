require 'ostruct'
require 'httpclient'
require 'savon'
require 'cgi'
require 'crack/xml'
require 'mime/types'
require 'digest/sha1'
require 'nokogiri'

class NestedOpenStruct < OpenStruct
  def initialize(hash = nil)
    @table = {}
    if hash
      for k, v in hash
        @table[k.to_sym] = v.instance_of?(Hash) ? NestedOpenStruct.new(v) : v
        new_ostruct_member(k)
      end
    end
  end
end

module Digidoc
  TargetNamespace = 'http://www.sk.ee/DigiDocService/DigiDocService_2_3.wsdl'
  TestEndpointUrl = 'https://openxades.org:9443/DigiDocService'

  class Client
    cattr_accessor :logger
    attr_accessor :session_code, :endpoint_url, :respond_with_nested_struct, :embedded_datafiles

    def initialize(endpoint_url = TestEndpointUrl)
      self.endpoint_url = endpoint_url || TestEndpointUrl
      self.respond_with_nested_struct = true
      self.embedded_datafiles = []
    end

    # Authentication message
    def authenticate(*args)
      options = args.last || {}

      phone = options.delete(:phone)
      personal_code = options.delete(:personal_code)
      country_code = options.delete(:country_code) || 'EE'
      language = options.delete(:language) || 'EST'
      service_name = options.delete(:service_name) || 'Testimine'
      message_to_display = options.delete(:message_to_display) || 'Tuvastamine'
      messaging_mode =  options.delete(:messaging_mode) || 'asynchClientServer'
      async_configuration = options.delete(:async_configuration) || 0
      return_cert_data = options.key?(:return_cert_data) ? options.delete(:return_cer_data) : true
      return_revocation_data = options.key?(:return_revocation_data) ? options.delete(:return_revocation_data) : true

      # SP challenge token
      sp_challenge = generate_sp_challenge
      phone = ensure_area_code(phone)
      self.session_code = nil

      # Make webservice call
      response = savon_client.call('MobileAuthenticate') do |locals|
        locals.message 'CountryCode' => country_code, 'PhoneNo' => phone, 'Language' => language, 'ServiceName' => service_name,
          'MessageToDisplay' => message_to_display, 'SPChallenge' => sp_challenge, 'MessagingMode' => messaging_mode,
          'AsyncConfiguration' => async_configuration, 'ReturnCertData' => return_cert_data,
          'ReturnRevocationData' => return_revocation_data, 'IdCode' => personal_code
      end

      if soap_fault?(response)
        result = response.to_hash[:fault]
      else
        result = response.to_hash[:mobile_authenticate_response]
        self.session_code = result[:sesscode]
      end
      respond_with_hash_or_nested(result)
    end

    # Authentication status
    def authentication_status(session_code = self.session_code)
      response = savon_client.call('GetMobileAuthenticateStatus') do |locals|
        locals.message 'Sesscode' => session_code
      end

      result = soap_fault?(response) ? response.to_hash[:fault] : response.to_hash[:get_mobile_authenticate_status_response]
      respond_with_hash_or_nested(result)
    end

    # Starts and holds session
    def start_session(*args)
      self.session_code = nil
      self.embedded_datafiles = []
      options = args.last || {}
      signed_doc_file = options.delete(:signed_doc_file)
      signed_doc_xml = signed_doc_file.read if signed_doc_file

      response = savon_client.call('StartSession') do |locals|
        locals.message 'bHoldSession' => true, 'SigDocXML' => signed_doc_xml
      end

      if soap_fault?(response)
        result = response.to_hash[:fault]
      else
        result = response.to_hash[:start_session_response]
        self.session_code = result[:sesscode]
      end
      respond_with_hash_or_nested(result)
    end

    # Creates DigiDoc container
    def create_signed_doc(*args)
      options = args.last || {}

      session_code = options.delete(:session_code) || self.session_code
      version = options.delete(:version) || '1.3'

      response = savon_client.call('CreateSignedDoc') do |locals|
        locals.message 'Sesscode' => session_code, 'Format' => 'DIGIDOC-XML', 'Version' => version
      end

      result = soap_fault?(response) ? response.to_hash[:fault] : response.to_hash[:create_signed_doc_response]
      respond_with_hash_or_nested(result)
    end

    def prepare_signature(*args)
      options = args.last || {}

      session_code = options.delete(:session_code) || self.session_code
      signers_certificate = options.delete(:signers_certificate)
      signers_token_id = options.delete(:signers_token_id)
      signing_profile = options.delete(:signing_profile)
      country_name = options.delete(:country_name) || 'Eesti'
      state_or_province = options.delete(:state_or_province)
      role = options.delete(:role)
      city = options.delete(:city)
      postal_code = options.delete(:postal_code)

      response = savon_client.call('PrepareSignature') do |locals|
        locals.message 'Sesscode' => session_code, 'SignersCertificate' => signers_certificate,
          'SignersTokenId' => signers_token_id, 'Role' => role, 'City' => city,
          'State' => state_or_province, 'PostalCode' => postal_code, 'Country' => country_name, 'SigningProfile' => signing_profile
      end

      result = soap_fault?(response) ? response.to_hash[:fault] : response.to_hash[:prepare_signature_response]
      respond_with_hash_or_nested(result)
    end

    def finalize_signature(*args)
      options = args.last || {}

      session_code = options.delete(:session_code) || self.session_code
      signature = options.delete(:signature)
      signature_id = options.delete(:signature_id)

      response = savon_client.call('FinalizeSignature') do |locals|
        locals.message 'Sesscode' => session_code, 'SignatureValue' => signature, 'SignatureId' => signature_id
      end

      result = soap_fault?(response) ? response.to_hash[:fault] : response.to_hash[:finalize_signature_response]
      respond_with_hash_or_nested(result)
    end

    def notary(*args)
      options = args.last || {}

      session_code = options.delete(:session_code) || self.session_code
      signature_id = options.delete(:signature_id)

      response = savon_client.call('GetNotary') do |locals|
        locals.message 'Sesscode' => session_code, 'SignatureId' => signature_id
      end

      result = soap_fault?(response) ? response.to_hash[:fault] : response.to_hash[:get_notary_response]
      respond_with_hash_or_nested(result)
    end

    # Sign DigiDoc container
    def mobile_sign(*args)
      options = args.last || {}

      session_code = options.delete(:session_code) || self.session_code
      phone = options.delete(:phone)
      personal_code = options.delete(:personal_code)
      country_code = options.delete(:country_code) || 'EE'
      country_name = options.delete(:country_name) || 'Eesti'
      language = options.delete(:language) || 'EST'
      service_name = options.delete(:service_name) || 'Testimine'
      message_to_display = options.delete(:message_to_display) || 'Allkirjastamine'
      messaging_mode =  options.delete(:messaging_mode) || 'asynchClientServer'
      async_configuration = options.delete(:async_configuration) || 0
      return_doc_info = options.key?(:return_doc_info) ? options.delete(:return_doc_info) : true
      return_doc_data = options.key?(:return_doc_data) ? options.delete(:return_doc_data) : true
      state_or_province = options.delete(:state_or_province)
      role = options.delete(:role)
      city = options.delete(:city)
      postal_code = options.delete(:postal_code)
      phone = ensure_area_code(phone)

      response = savon_client.call('MobileSign') do |locals|
        locals.message 'Sesscode' => session_code, 'SignersCountry' => country_code, 'CountryName' => country_name,
          'SignerPhoneNo' => phone, 'Language' => language, 'ServiceName' => service_name,
          'AdditionalDataToBeDisplayed' => message_to_display, 'MessagingMode' => messaging_mode,
          'AsyncConfiguration' => async_configuration, 'ReturnDocInfo' => return_doc_info,
          'ReturnDocData' => return_doc_data, 'SignerIDCode' => personal_code, 'Role' => role, 'City' => city,
           'StateOrProvince' => state_or_province, 'PostalCode' => postal_code
      end

      result = soap_fault?(response) ? response.to_hash[:fault] : response.to_hash[:mobile_sign_response]
      respond_with_hash_or_nested(result)
    end

    # Get session status info.
    def sign_status(*args)
      options = args.last || {}

      session_code = options.delete(:session_code) || self.session_code
      return_doc_info = options.key?(:return_doc_info) ? options.delete(:return_doc_info) : false
      wait_signature = options.key?(:wait_signature) ? options.delete(:wait_signature) : false

      response = savon_client.call('GetStatusInfo') do |locals|
        locals.message 'Sesscode' => session_code, 'ReturnDocInfo' => return_doc_info, 'WaitSignature' => wait_signature
      end

      result = soap_fault?(response) ? response.to_hash[:fault] : response.to_hash[:get_status_info_response]
      respond_with_hash_or_nested(result)
    end

    # Get DigiDoc container status
    def signed_doc_info(*args)
      options = args.last || {}
      session_code = options.delete(:session_code) || self.session_code

      response = savon_client.call('GetSignedDocInfo') do |locals|
        locals.message 'Sesscode' => session_code
      end

      result = soap_fault?(response) ? response.to_hash[:fault] : response.to_hash[:get_signed_doc_info_response]
      respond_with_hash_or_nested(result)
    end

    # Get DigiDoc container
    def save_signed_doc(*args, &block)
      options = args.last || {}
      session_code = options.delete(:session_code) || self.session_code

      response = savon_client.call('GetSignedDoc') do |locals|
        locals.message 'Sesscode' => session_code
      end

      if soap_fault?(response)
        result = respond_with_hash_or_nested(response.to_hash[:fault])
      else
        escaped = Crack::XML.parse(response.http.body).to_hash['SOAP_ENV:Envelope']['SOAP_ENV:Body']['dig:GetSignedDocResponse']['SignedDocData']
        # TODO: is escaping needed? - it removes original escaped & form XML
        digidoc_container = escaped#CGI.unescapeHTML(escaped)

        if embedded_datafiles.present?
          xmldata = Nokogiri::XML(digidoc_container)
          xmldata.root.elements.each { |el| el.replace(embedded_datafiles.shift) if el.name == 'DataFile' }
          digidoc_container = xmldata.to_xml
        end

        if block_given?
          yield digidoc_container
        else
          digidoc_container
        end
      end
    end

    # Closes current session
    def close_session(session_code = self.session_code)
      response = savon_client.call('CloseSession') do |locals|
        locals.message 'Sesscode' => session_code
      end
      self.session_code = nil

      result = soap_fault?(response) ? response.to_hash[:fault] : response.to_hash[:close_session_response]
      respond_with_hash_or_nested(result)
    end

    # Add datafile to DigiDoc container
    def add_datafile(file, *args)
      options = args.last || {}

      session_code = options.delete(:session_code) || self.session_code
      filename = options.delete(:filename) || File.basename(file.path)
      mime_type = options[:mime_type] || calc_mime_type(file)
      use_hashcode = false #options.key?(:use_hashcode) || true
      filename = filename.gsub('/', '-')

      response = savon_client.call('AddDataFile') do |locals|
        file_content = Base64.encode64(file.read)
        # Upload file to webservice
        if use_hashcode
          # Calculate sha1 from file
          datafile = datafile(filename, mime_type, file.size, file_content, embedded_datafiles.size)
          self.embedded_datafiles << datafile
          hex_sha1 = Digest::SHA1.hexdigest(datafile)
          digest_value = Base64.encode64(hex_sha1.lines.to_a.pack('H*'))
          locals.message 'Sesscode' => session_code, 'FileName' => filename, 'MimeType' => mime_type, 'ContentType' => 'HASHCODE',
            'Size' => file.size, 'DigestType' => 'sha1', 'DigestValue' => digest_value
        else
          locals.message'Sesscode' => session_code, 'FileName' => filename, 'MimeType' => mime_type, 'ContentType' => 'EMBEDDED_BASE64', 'Size' => file.size, 'Content' => file_content
        end
      end

      result = soap_fault?(response) ? response.to_hash[:fault] : response.to_hash[:add_data_file_response]
      respond_with_hash_or_nested(result)
    end

    private

    def soap_fault?(response)
      response.http.body =~ /<*Fault>/
    end

    def ensure_area_code(phone)
      phone =~ /^\+/ ? phone : "+372#{phone}" unless phone.blank?
    end

    def savon_client
      Savon.client(
        raise_errors: false,
        endpoint: self.endpoint_url,
        namespace: TargetNamespace,
        open_timeout: 10,
        ssl_version: :TLSv1,
        ssl_verify_mode: :none,
        logger: Client.logger,
        log_level: :debug,
        log: true
      )
    end

    def datafile(filename, mime_type, size, content, id)
      datafile = "<DataFile ContentType=\"EMBEDDED_BASE64\" Filename=\"#{filename}\" Id=\"D#{id}\" MimeType=\"#{mime_type}\" Size=\"#{size}\">#{content}</DataFile>"
    end

    def calc_mime_type(file)
      return unless file
      MIME::Types.type_for(File.basename(file.path)).first.try(:content_type) || 'text/plain'
    end

    def respond_with_hash_or_nested(hash)
      if respond_with_nested_struct
        NestedOpenStruct.new(hash)
      else
        hash
      end
    end

    # Hex ID generator
    def generate_unique_hex(codeLength)
      validChars = ("A".."F").to_a + ("0".."9").to_a
      length = validChars.size
      hexCode = ''
      1.upto(codeLength) { |i| hexCode << validChars[rand(length-1)] }
      hexCode
    end

    # Generates unique challenge code (consumer token that gets scrumbled by gateway)
    def generate_sp_challenge
      generate_unique_hex(20)
    end
  end
end