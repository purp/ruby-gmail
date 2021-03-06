class Gmail
  class Message
    attr_reader :mail, :uid

    # FIXME: mailbox includes its parent gmail connection, so we shouldn't need it here.
    # FIXME: make mailbox an attr and stop touching @mailbox
    def initialize(gmail, mailbox, uid)
      raise "uid cannot be nil" unless uid
      @gmail = gmail
      @mailbox = mailbox
      @uid = uid
    end

    def inspect
      "<#Message:#{object_id} mailbox=#{@mailbox.name}#{' uid='+@uid.to_s if @uid}#{' message_id='+@message_id.to_s if @message_id}>"
    end

    # # Auto IMAP info
    # def uid
    #   @uid ||= @gmail.imap.uid_search(['HEADER', 'Message-ID', message_id])[0]
    # end

    # IMAP Operations
    def flag(flg)
      @gmail.in_mailbox(@mailbox) do
        @gmail.imap.uid_store(uid, "+FLAGS", [flg])
      end ? true : false
    end

    def unflag(flg)
      @gmail.in_mailbox(@mailbox) do
        @gmail.imap.uid_store(uid, "-FLAGS", [flg])
      end ? true : false
    end

    # Gmail Operations
    def mark(flag)
      case flag
      when :read
        flag(:Seen)
      when :unread
        unflag(:Seen)
      when :deleted
        flag(:Deleted)
      when :spam
        move_to('[Gmail]/Spam')
      end ? true : false
    end

    def delete!
      @mailbox.messages.delete(uid)
      flag(:Deleted)
    end

    def label(name)
      @gmail.in_mailbox(@mailbox) do
        begin
          @gmail.imap.uid_copy(uid, name)
        rescue Net::IMAP::NoResponseError
          raise Gmail::NoLabel, "No label `#{name}' exists!"
        end
      end
    end

    def label!(name)
      @gmail.in_mailbox(@mailbox) do
        begin
          @gmail.imap.uid_copy(uid, name)
        rescue Net::IMAP::NoResponseError
          # need to create the label first
          @gmail.create_label(name)
          retry
        end
      end
    end

    # We're not sure of any 'labels' except the 'mailbox' we're in at the moment.
    # Research whether we can find flags that tell which other labels this email is a part of.
    # def remove_label(name)
    # end

    def move_to(name)
      label(name) && delete!
    end

    def archive!
      move_to('[Gmail]/All Mail')
    end

    def save_attachments_to(path=nil)
      attachments.each {|a| a.save_to_file(path) }
    end

    private

    # Parsed MIME message object
    def mime_message
      return @mail if @mail
      require 'mail'
      _body = @gmail.in_mailbox(@mailbox) { @gmail.imap.uid_fetch(uid, "RFC822")[0].attr["RFC822"] }
      @mail = Mail.new(_body)
    end

    # Delegate all other methods to the Mail message
    def method_missing(*args, &block)
      if block_given?
        mime_message.send(*args, &block)
      else
        mime_message.send(*args)
      end
    end
  end
end