Ruby client for Estonian DigiDoc service authentication and signing API.

## Installation

Add gem dependency in your `Gemfile` and install the gem:

    gem 'digidoc_client'

## Usage

### Authentication

    client = Digidoc::Client.new
    client.authenticate(
      :phone => '+3725012345', :message_to_display => 'Authenticating',
      :service_name => 'Testing'
    )
    client.authentication_status

### Signing

    c = Digidoc::Client.new
    c.start_session
    c.create_signed_doc 
    c.signed_doc_info
    
    file1 = File.open('file1.pdf')
    c.add_datafile(file1)
    file2 = File.open('file2.pdf')
    c.add_datafile(file2)
    
    c.mobile_sign(:phone => '5012345', :role => ' My Company LLC / CTO')
    c.sign_status
    
    c.save_signed_doc do |content|
      File.open('signed_document.ddoc', 'w') { |f| f.write(content) }
    end
    
    c.close_session

## Digidoc specifications

TODO: add links to digidoc specifications

## Authors

[See this list](https://github.com/tarmotalu/digidoc_client/contributors)
