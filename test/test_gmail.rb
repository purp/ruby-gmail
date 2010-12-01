require File.expand_path('test_helper', File.dirname(__FILE__))

class GmailTest < Test::Unit::TestCase
  def setup
    @gmail = setup_gmail_mock(:user => 'test', :password => 'password')
    assert_equal @imap_connection, @gmail.instance_variable_get('@imap')
  end

  def test_non_email_username_gets_gmail_domain
    assert_equal 'test@gmail.com', @gmail.send('meta').username
  end

  def test_email_address_as_username_remains_intact
    @gmail = setup_gmail_mock(:user => 'test@example.com', :password => 'password')
    assert_equal 'test@example.com', @gmail.send('meta').username
  end

  def test_login_logs_in_once_and_only_once
    assert !@gmail.logged_in?
    @gmail.login
    assert @gmail.logged_in?

    assert_nothing_raised { @gmail.login }
  end

  def test_imap_automatically_logs_in_and_out
    ### TODO: Figure out how to test an at_exit block
    # @imap_connection.expects(:logout).once
    # Kernel.expects(:at_exit).once

    assert !@gmail.logged_in?
    @gmail.imap
    assert @gmail.logged_in?
  end

  def test_log_out_actually_logs_out
    @gmail.login
    @gmail.logout
    assert !@gmail.logged_in?
  end

  def test_logout_does_nothing_if_not_logged_in
    @gmail = setup_gmail_mock
    @imap_connection.expects(:logout).never

    assert !@gmail.logged_in?
    @gmail.logout
    assert !@gmail.logged_in?
  end

  def test_imap_calls_create_label
    setup_gmail_mock
    @gmail.imap.expects(:create).with('foo')
    assert_nothing_raised { @gmail.create_label('foo') }
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
end

class GmailMailboxTest < Test::Unit::TestCase
  def setup
    @mailbox = setup_mailbox_mock(:name => 'I know my name')
  end

  def test_mailbox_knows_its_name
    assert_equal @mailbox.name, 'I know my name'
    assert_equal @mailbox.to_s, @mailbox.name
  end

  def test_mailbox_has_default_empty_message_hash
    assert_equal @mailbox.messages, {}
  end

  def test_mailbox_has_proper_count
    @imap_connection.expects(:uid_search).once.returns([])
    assert_equal 0, @mailbox.count

    @imap_connection.expects(:uid_search).once.returns(%w(Sam Cassie Ellie))
    assert_equal 3, @mailbox.count
  end

  def test_mailbox_emails_search_defaults_to_all
    @imap_connection.expects(:uid_search).with(['ALL']).once.returns([])
    assert_equal [], @mailbox.emails
  end

  def test_mailbox_emails_handles_aliases
    @imap_connection.expects(:uid_search).with(['ALL']).once.returns([])
    assert_equal [], @mailbox.emails(:all)

    @imap_connection.expects(:uid_search).with(['SEEN']).once.returns([])
    assert_equal [], @mailbox.emails(:read)

    @imap_connection.expects(:uid_search).with(['UNSEEN']).once.returns([])
    assert_equal [], @mailbox.emails(:unread)
  end

  def test_mailbox_emails_accepts_direct_array_of_search_options
    search_opts = %w(Beth Sam Cassie Ellie)
    @imap_connection.expects(:uid_search).with(search_opts).once.returns([])
    assert_equal [], @mailbox.emails(search_opts)
  end

  def test_mailbox_emails_translates_options_to_search_params_properly
    right_now = Time.now

    @imap_connection.expects(:uid_search).with(['ALL', 'SINCE', right_now.to_imap_date]).once.returns([])
    assert_equal [], @mailbox.emails(:after => right_now)

    @imap_connection.expects(:uid_search).with(['ALL', 'BEFORE', right_now.to_imap_date]).once.returns([])
    assert_equal [], @mailbox.emails(:before => right_now)

    @imap_connection.expects(:uid_search).with(['ALL', 'ON', right_now.to_imap_date]).once.returns([])
    assert_equal [], @mailbox.emails(:on => right_now)

    @imap_connection.expects(:uid_search).with(['ALL', 'SUBJECT', 'With love ...']).once.returns([])
    assert_equal [], @mailbox.emails(:subject => 'With love ...')

    @imap_connection.expects(:uid_search).with(['ALL', 'FROM', 'Me']).once.returns([])
    assert_equal [], @mailbox.emails(:from => 'Me')

    @imap_connection.expects(:uid_search).with(['ALL', 'TO', 'You']).once.returns([])
    assert_equal [], @mailbox.emails(:to => 'You')

    @imap_connection.expects(:uid_search).with(['ALL', 'BODY', "I've got arms that long to hold you ..."]).once.returns([])
    assert_equal [], @mailbox.emails(:body => "I've got arms that long to hold you ...")
  end
end

class GmailMessageTest < Test::Unit::TestCase
  def setup
    @mailbox = setup_mailbox_mock
    @message = Gmail::Message.new(@gmail, @mailbox, '03040226041410160927@mail.example.com')
  end

  def test_message_knows_its_uid
    assert_equal '03040226041410160927@mail.example.com', @message.uid
  end

  def test_new_message_must_have_uid_to_avoid_circular_dependency
    assert_raise RuntimeError do
      Gmail::Message.new(@gmail, @mailbox, nil)
    end
  end
end