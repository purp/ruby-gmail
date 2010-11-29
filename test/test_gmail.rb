require File.expand_path('test_helper', File.dirname(__FILE__))

class GmailTest < Test::Unit::TestCase
  def test_initialize
    imap = mock('imap')
    Net::IMAP.expects(:new).with('imap.gmail.com', 993, true, nil, false).returns(imap)
    gmail = Gmail.new('test', 'password')
  end
  
  def test_imap_does_login
    setup_gmail_mock

    @gmail.imap
    breakdown_mocks
  end

  def test_imap_does_login_only_once
    setup_gmail_mock(:login_attempts => 1)

    @gmail.imap
    @gmail.imap
    @gmail.imap
  end

  def test_imap_does_login_without_appending_gmail_domain
    setup_gmail_mock

    @gmail.imap
  end
  
  def test_imap_logs_out
    setup_gmail_mock

    # @imap.expects(:disconnected?).at_least_once.returns(true).then.returns(false)
    # @imap.expects(:login).with('test@gmail.com', 'password')
    @gmail.imap
    @gmail.logout
    assert !@gmail.logged_in?
  end

  def test_imap_logout_does_nothing_if_not_logged_in
    setup_gmail_mock(:at_exit => false)

    @gmail.logout
  end
  
  def test_imap_calls_create_label
    setup_gmail_mock
    @imap.expects(:create).with('foo')
    @gmail.create_label('foo')
  end
  
  def test_mailbox_calls_return_existing_mailbox
    setup_gmail_mock
    mailbox = Gmail::Mailbox.new(@gmail, 'test')
    @gmail.expects(:mailboxes).returns({'test' => mailbox})
    
    assert_equal @gmail.mailbox('test'), mailbox
  end
  
  def test_mailbox_returns_new_mailbox_object_for_mailboxes_it_has_not_yet_seen
    setup_gmail_mock
    @gmail.expects(:mailboxes).returns({})    
    Gmail::Mailbox.expects(:new).with(@gmail, 'test').returns('This is my mailbox.')
    
    assert_equal @gmail.mailbox('test'), 'This is my mailbox.'
  end
  
  private
  def setup_gmail_mock(options = {})
    options = {:at_exit => true, :login_attempts => 0, :user => 'test', :password => 'password'}.merge(options)
    user_name = options[:user]
    password = options[:password]
    
    @res = mock('imap_result')
    @res.expects(:name).at_least(0).returns("OK")

    @imap = mock('imap')
    @imap.expects(:login).at_least(options[:login_attempts]).with("#{user_name}@gmail.com", 'password').returns(@res)
    # need this for the at_exit block that auto-exits after this test method completes
    @imap.expects(:logout).at_least(0).returns(@res) if options[:at_exit]
    
    Net::IMAP.expects(:new).with('imap.gmail.com', 993, true, nil, false).returns(@imap)
    @gmail = Gmail.new(user_name, password)
  end
  
  def breakdown_mocks
    @gmail.logout
  end
end

