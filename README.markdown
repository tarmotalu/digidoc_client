Ruby client for Estonian DigiDoc service authentication and signing API.

## Installation

Add gem dependency in your `Gemfile` and install the gem:

    gem 'digidoc_client'

## Usage

### Authentication

    client = Digidoc::Client.new
    client.authenticate(
      :phone => '+37260000007', :message_to_display => 'Authenticating',
      :service_name => 'Testing'
    )
    client.authentication_status

### Signing

    client = Digidoc::Client.new
    client.logger = Logger.new('digidoc_service.log')
    client.start_session
    client.create_signed_doc
    client.signed_doc_info

    file1 = File.open('file1.pdf')
    client.add_datafile(file1)
    file2 = File.open('file2.pdf')
    client.add_datafile(file2)

    client.mobile_sign(:phone => '+37260000007', :role => ' My Company LLC / CTO')
    client.sign_status

    # Check signature status here...

    client.save_signed_doc do |content, format|
      File.open("signed_document.#{format}", 'w') do |f|
        if format == :bdoc
          f.binmode
          f.write(Base64.decode64(content))
        else
          f.write(content)
        end
      end
    end

    client.close_session

### More test numbers and details
[In English](http://www.id.ee/?id=36381)

## Digidoc specifications

[In English](http://www.sk.ee/upload/files/DigiDocService_spec_eng.pdf)

[In Estonian](http://www.sk.ee/upload/files/DigiDocService_spec_est.pdf)

## Authors

[See this list](https://github.com/tarmotalu/digidoc_client/contributors)
