require 'net/imap'

class Gmail
  VERSION = '0.0.9'

  class NoLabel < RuntimeError; end

  ##################################
  #  Gmail.new(username, password)
  ##################################
  def initialize(username, password)
    # This is to hide the username and password, not like it REALLY needs hiding, but ... you know.
    # Could be helpful when demoing the gem in irb, these bits won't show up that way.
    class << self
      class << self
        attr_accessor :username, :password
      end
    end
    meta.username = username =~ /@/ ? username : username + '@gmail.com'
    meta.password = password
    @imap = Net::IMAP.new('imap.gmail.com',993,true,nil,false)
    if block_given?
      login # This is here intentionally. Normally, we get auto logged-in when first needed.
      yield self
      logout
    end
  end

  ###########################
  #  READING EMAILS
  # 
  #  gmail.inbox
  #  gmail.label('News')
  #  
  ###########################

  def inbox
    in_label('inbox')
  end

  def create_label(name)
    imap.create(name)
  end

  # List the available labels
  def labels
    (imap.list("", "%") + imap.list("[Gmail]/", "%")).inject([]) { |labels,label|
      label[:name].each_line { |l| labels << l }; labels }
  end

  # gmail.label(name)
  def label(name)
    mailboxes[name] ||= Mailbox.new(self, name)
  end
  alias :mailbox :label

  ###########################
  #  MAKING EMAILS
  # 
  #  gmail.generate_message do
  #    ...inside Mail context...
  #  end
  # 
  #  gmail.deliver do ... end
  # 
  #  mail = Mail.new...
  #  gmail.deliver!(mail)
  ###########################
  def generate_message(&block)
    require 'net/smtp'
    require 'smtp_tls'
    require 'mail'
    mail = Mail.new(&block)
    mail.delivery_method(*smtp_settings)
    mail
  end

  def deliver(mail=nil, &block)
    require 'net/smtp'
    require 'smtp_tls'
    require 'mail'
    mail = Mail.new(&block) if block_given?
    mail.delivery_method(*smtp_settings)
    mail.from = meta.username unless mail.from
    mail.deliver!
  end

  ###########################
  #  LOGIN
  ###########################
  def login
    unless logged_in?
      @logged_in = true if @imap.login(meta.username, meta.password).name == 'OK'
    end
  end

  def logged_in?
    !!@logged_in
  end

  def logout
    if logged_in?
      @logged_in = false if @imap.logout.name == 'OK'
    end
  end

  def in_mailbox(mailbox, &block)
    if block_given?
      mailbox_stack << mailbox
      unless @selected == mailbox.name
        imap.select(mailbox.name)
        @selected = mailbox.name
      end
      value = block.arity == 1 ? block.call(mailbox) : block.call
      mailbox_stack.pop
      # Select most recently selected mailbox if there is one
      if mailbox_stack.last
        imap.select(mailbox_stack.last.name)
        @selected = mailbox.name
      end
      return value
    else
      label(mailbox)
    end
  end
  alias :in_label :in_mailbox

  ###########################
  #  Other...
  ###########################
  def inspect
    "#<Gmail:#{'0x%x' % (object_id << 1)} (#{meta.username}) #{'dis' if !logged_in?}connected>"
  end

  # Accessor for @imap, but ensures that it's logged in first.
  def imap
    # Since we're auto-logging-in, set up auto-logout for later. Can't use #logout since
    # we need to bind @imap's current context in the block. Yay, closures!
    at_exit { @imap.logout } unless logged_in?
    login
    @imap
  end

  private
  
  def mailboxes
    @mailboxes ||= {}
  end
  
  def mailbox_stack
    @mailbox_stack ||= []
  end
  
  def meta
    class << self; self end
  end
  
  def domain
    meta.username.split('@')[0]
  end
  
  def smtp_settings
    [:smtp, {:address => "smtp.gmail.com",
      :port => 587,
      :domain => domain,
      :user_name => meta.username,
      :password => meta.password,
      :authentication => 'plain',
      :enable_starttls_auto => true}]
  end
end

  ### FIXME: We should factor this upward in the file or move to a gmail/base.rb model
  require 'gmail/mailbox'
  require 'gmail/message'
