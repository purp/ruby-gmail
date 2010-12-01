$LOAD_PATH << File.expand_path(File.join(%w(.. lib)), File.dirname(__FILE__))

require 'test/unit'
require 'rubygems'
require 'mocha'

require 'gmail'

def setup_gmail_mock(options = {})
  options = {:user => 'test', :password => 'password'}.merge(options)
  user_name = options[:user]
  email_address = user_name.match('@') ? user_name : "#{user_name}@gmail.com" 
  password = options[:password]
  
  @imap_result = mock('imap_result')
  @imap_result.expects(:name).at_least(0).returns("OK")

  @imap_connection = mock('imap')
  @imap_connection.stubs(:login).with(email_address, password).returns(@imap_result)
  
  # need this for the at_exit block that auto-exits after this test method completes
  @imap_connection.stubs(:logout).returns(@imap_result)
  
  Net::IMAP.expects(:new).with('imap.gmail.com', 993, true, nil, false).returns(@imap_connection)
  Gmail.new(user_name, password)
end

def setup_mailbox_mock(options = {})
  options = {:name => 'Mailbox Name'}.merge(options)
  @gmail = setup_gmail_mock
  @imap_connection.stubs(:select).with(options[:name])
  Gmail::Mailbox.new(@gmail, options[:name])
end

def breakdown_mocks
  @gmail.logout
end
