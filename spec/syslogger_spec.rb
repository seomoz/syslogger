require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Syslogger" do

  expected_info_level = Syslog::LOG_NOTICE
  test_formatter = Proc.new { |severity, time, progname, message| message }

  describe "formatter" do
    before(:each) do
      @logger = Syslogger.new("my_app", Syslog::LOG_PID | Syslog::LOG_CONS, nil)
    end

    it 'is applied when set' do
      @logger.formatter = Proc.new { 'success' }
      expect(Syslog).to receive(:open).and_yield(syslog=double('syslog', :mask= => true))

      expect(syslog).to receive(:log).with(Syslog::LOG_WARNING, 'success')

      @logger.warn('test message')
    end

    it 'can be read back' do
      @logger.formatter = test_formatter

      expect(@logger.formatter).to be(test_formatter)
    end

    it 'is applied to the message, all params passed' do
      expect(Syslog).to receive(:open).and_yield(syslog=double('syslog', :mask= => true))
      expect(syslog).to receive(:log)
      args = nil
      @logger.formatter  = Proc.new { |severity, time, progname, message|
        args = { severity: severity, time: time, progname: progname, message: message }
      }
      @logger.ident = 'my-prog'

      before = Time.now
      @logger.warn('my-message')
      after = Time.now

      expect(args).to include(
        severity: 'WARN',
        time: a_value_between(before, after),
        progname: 'my-prog',
        message: 'my-message'
      )
    end
  end

  it "should log to the default syslog facility, with the default options" do
    logger = Syslogger.new
    logger.formatter = test_formatter
    expect(Syslog).to receive(:open).with($0, Syslog::LOG_PID | Syslog::LOG_CONS, nil).
        and_yield(syslog=double("syslog", :mask= => true))
    expect(syslog).to receive(:log).with(Syslog::LOG_WARNING, "Some message")
    logger.warn "Some message"
  end

  it "should log to the user facility, with specific options" do
    logger = Syslogger.new("my_app", Syslog::LOG_PID, Syslog::LOG_USER)
    logger.formatter = test_formatter
    expect(Syslog).to receive(:open).with("my_app", Syslog::LOG_PID, Syslog::LOG_USER).
        and_yield(syslog=double("syslog", :mask= => true))
    expect(syslog).to receive(:log).with(Syslog::LOG_WARNING, "Some message")
    logger.warn "Some message"
  end

  %w{debug info warn error fatal unknown}.each do |logger_method|
    it "should respond to the #{logger_method.inspect} method" do
      expect(Syslogger.new).to respond_to(logger_method.to_sym)
    end

    it "should log #{logger_method} without raising an exception if called with a block" do
      logger = Syslogger.new
      logger.formatter = test_formatter
      logger.level = Logger.const_get(logger_method.upcase)
      expect(Syslog).to receive(:open).and_yield(syslog=double("syslog", :mask= => true))
      severity = Syslogger::MAPPING[Logger.const_get(logger_method.upcase)]
      expect(syslog).to receive(:log).with(severity, "A message that doesn't need to be in a block")
      expect {
        logger.send(logger_method.to_sym) { "A message that doesn't need to be in a block" }
      }.not_to raise_error
    end

    it "should log #{logger_method} without raising an exception if called with a nil message" do
      logger = Syslogger.new
      expect {
        logger.send(logger_method.to_sym, nil)
      }.not_to raise_error
    end

    it "should log #{logger_method} without raising an exception if called with a no message" do
      logger = Syslogger.new
      expect {
        logger.send(logger_method.to_sym)
      }.not_to raise_error
    end

    it "should log #{logger_method} without raising an exception if message splits on an escape" do
      logger = Syslogger.new
      logger.max_octets=100
      msg="A"*99
      msg+="%BBB"
      expect {
        logger.send(logger_method.to_sym,msg)
      }.not_to raise_error
    end

  end

  %w{debug info warn error}.each do |logger_method|
    it "should not log #{logger_method} when level is higher" do
      logger = Syslogger.new
      logger.level = Logger::FATAL
      expect(Syslog).not_to receive(:open).with($0, Syslog::LOG_PID | Syslog::LOG_CONS, nil).
          and_yield(syslog=double("syslog", :mask= => true))
      expect(syslog).not_to receive(:log).with(Syslog::LOG_NOTICE, "Some message")
      logger.send(logger_method.to_sym, "Some message")
    end

    it "should not evaluate a block or log #{logger_method} when level is higher" do
      logger = Syslogger.new
      logger.level = Logger::FATAL
      expect(Syslog).not_to receive(:open).with($0, Syslog::LOG_PID | Syslog::LOG_CONS, nil).
          and_yield(syslog=double("syslog", :mask= => true))
      expect(syslog).not_to receive(:log).with(Syslog::LOG_NOTICE, "Some message")
      logger.send(logger_method.to_sym) { violated "This block should not have been called" }
    end
  end

  it "should respond to <<" do
    logger = Syslogger.new("my_app", Syslog::LOG_PID, Syslog::LOG_USER)
    logger.formatter = test_formatter
    expect(logger).to respond_to(:<<)
    expect(Syslog).to receive(:open).with("my_app", Syslog::LOG_PID, Syslog::LOG_USER).
        and_yield(syslog=double("syslog", :mask= => true))
    expect(syslog).to receive(:log).with(expected_info_level, "yop")
    logger << "yop"
  end

  it "should respond to write" do
    logger = Syslogger.new("my_app", Syslog::LOG_PID, Syslog::LOG_USER)
    logger.formatter = test_formatter
    expect(logger).to respond_to(:write)
    expect(Syslog).to receive(:open).with("my_app", Syslog::LOG_PID, Syslog::LOG_USER).
        and_yield(syslog=double("syslog", :mask= => true))
    expect(syslog).to receive(:log).with(expected_info_level, "yop")
    logger.write "yop"
  end

  describe "add" do
    before do
      @logger = Syslogger.new("my_app", Syslog::LOG_PID, Syslog::LOG_USER)
      @logger.formatter = test_formatter
    end

    it "should respond to add" do
      expect(@logger).to respond_to(:add)
    end
    it "should correctly log" do
      expect(Syslog).to receive(:open).with("my_app", Syslog::LOG_PID, Syslog::LOG_USER).
          and_yield(syslog=double("syslog", :mask= => true))
      expect(syslog).to receive(:log).with(expected_info_level, "message")
      @logger.add(Logger::INFO, "message")
    end
    it "should take the message from the block if :message is nil" do
      expect(Syslog).to receive(:open).with("my_app", Syslog::LOG_PID, Syslog::LOG_USER).
          and_yield(syslog=double("syslog", :mask= => true))
      expect(syslog).to receive(:log).with(expected_info_level, "my message")
      @logger.add(Logger::INFO) { "my message" }
    end
    it "should use the given progname" do
      expect(Syslog).to receive(:open).with("progname", Syslog::LOG_PID, Syslog::LOG_USER).
          and_yield(syslog=double("syslog", :mask= => true))
      expect(syslog).to receive(:log).with(expected_info_level, "message")
      @logger.add(Logger::INFO, "message", "progname") { "my message" }
    end

    it "should use the default progname when message is passed in progname" do
      expect(Syslog).to receive(:open).
        with("my_app", Syslog::LOG_PID, Syslog::LOG_USER).
        and_yield(syslog = double("syslog", :mask= => true))

      expect(syslog).to receive(:log).with(expected_info_level, "message")
      @logger.add(Logger::INFO, nil, "message")
    end

    it "should use the given progname if message is passed in block" do
      expect(Syslog).to receive(:open).
        with("progname", Syslog::LOG_PID, Syslog::LOG_USER).
        and_yield(syslog = double("syslog", :mask= => true))

      expect(syslog).to receive(:log).with(expected_info_level, "message")
      @logger.add(Logger::INFO, nil, "progname") { "message" }
    end

    it "should substitute '%' for '%%' before adding the :message" do
      expect(Syslog).to receive(:open).and_yield(syslog=double("syslog", :mask= => true))
      expect(syslog).to receive(:log).with(expected_info_level, "%%me%%ssage%%")
      @logger.add(Logger::INFO, "%me%ssage%")
    end

    it "should strip the :message" do
      expect(Syslog).to receive(:open).and_yield(syslog=double("syslog", :mask= => true))
      expect(syslog).to receive(:log).with(expected_info_level, "message")
      @logger.add(Logger::INFO, "\n\nmessage  ")
    end

    it "should not raise exception if asked to log with a nil message and body" do
      expect(Syslog).to receive(:open).
        with("my_app", Syslog::LOG_PID, Syslog::LOG_USER).
        and_yield(syslog=double("syslog", :mask= => true))
      expect(syslog).to receive(:log).with(expected_info_level, "")
      expect {
        @logger.add(Logger::INFO, nil)
      }.not_to raise_error
    end

    it "should send an empty string if the message and block are nil" do
      expect(Syslog).to receive(:open).
        with("my_app", Syslog::LOG_PID, Syslog::LOG_USER).
        and_yield(syslog=double("syslog", :mask= => true))
      expect(syslog).to receive(:log).with(expected_info_level, "")
      @logger.add(Logger::INFO, nil)
    end

    it "should split string over the max octet size" do
      @logger.max_octets = 480
      expect(Syslog).to receive(:open).
        with("my_app", Syslog::LOG_PID, Syslog::LOG_USER).
        and_yield(syslog=double("syslog", :mask= => true))
      expect(syslog).to receive(:log).with(expected_info_level, "a"*480).twice
      @logger.add(Logger::INFO, "a"*960)
    end
  end # describe "add"

  describe "max_octets=" do
    before(:each) do
      @logger = Syslogger.new("my_app", Syslog::LOG_PID, Syslog::LOG_USER)
    end

    it "should set the max_octets for the logger" do
      expect { @logger.max_octets = 1 }.to change(@logger, :max_octets)
      expect(@logger.max_octets).to eq(1)
    end

  end

  describe "level=" do
    before(:each) do
      @logger = Syslogger.new("my_app", Syslog::LOG_PID, Syslog::LOG_USER)
    end

    { :debug => Logger::DEBUG,
      :info  => Logger::INFO,
      :warn  => Logger::WARN,
      :error => Logger::ERROR,
      :fatal => Logger::FATAL
    }.each_pair do |level_symbol, level_value|
      it "should allow using :#{level_symbol}" do
        @logger.level = level_symbol
        expect(@logger.level).to eq(level_value)
      end

      it "should allow using Fixnum #{level_value}" do
        @logger.level = level_value
        expect(@logger.level).to eq(level_value)
      end
    end

    it "should not allow using random symbols" do
      expect {
        @logger.level = :foo
      }.to raise_error
    end

    it "should not allow using symbols mapping back to non-level constants" do
      expect {
        @logger.level = :version
      }.to raise_error
    end

    it "should not allow using strings" do
      expect {
        @logger.level = "warn"
      }.to raise_error
    end
  end # describe "level="

  describe "ident=" do
    before(:each) do
      @logger = Syslogger.new("my_app", Syslog::LOG_PID | Syslog::LOG_CONS, nil)
    end

    it "should permanently change the ident string" do
      @logger.ident = "new_ident"
      expect(Syslog).to receive(:open).with("new_ident", Syslog::LOG_PID | Syslog::LOG_CONS, nil).and_yield(syslog=double("syslog", :mask= => true))
      expect(syslog).to receive(:log)
      @logger.warn("should get the new ident string")
    end
  end

  describe ":level? methods" do
    before(:each) do
      @logger = Syslogger.new("my_app", Syslog::LOG_PID, Syslog::LOG_USER)
    end

    %w{debug info warn error fatal}.each do |logger_method|
      it "should respond to the #{logger_method}? method" do
        expect(@logger).to respond_to(:"#{logger_method}?")
      end
    end

    it "should not have unknown? method" do
      expect(@logger).not_to respond_to(:unknown?)
    end

    it "should return true for all methods" do
      @logger.level = Logger::DEBUG
      %w{debug info warn error fatal}.each do |logger_method|
        expect(@logger.send("#{logger_method}?")).to be(true)
      end
    end

    it "should return true for all except debug?" do
      @logger.level = Logger::INFO
      %w{info warn error fatal}.each do |logger_method|
        expect(@logger.send("#{logger_method}?")).to be(true)
      end
      expect(@logger.debug?).to be(false)
    end

    it "should return true for warn?, error? and fatal? when WARN" do
      @logger.level = Logger::WARN
      %w{warn error fatal}.each do |logger_method|
        expect(@logger.send("#{logger_method}?")).to be(true)
      end
      %w{debug info}.each do |logger_method|
        expect(@logger.send("#{logger_method}?")).to be(false)
      end
    end

    it "should return true for error? and fatal? when ERROR" do
      @logger.level = Logger::ERROR
      %w{error fatal}.each do |logger_method|
        expect(@logger.send("#{logger_method}?")).to be(true)
      end
      %w{warn debug info}.each do |logger_method|
        expect(@logger.send("#{logger_method}?")).to be(false)
      end
    end

    it "should return true only for fatal? when FATAL" do
      @logger.level = Logger::FATAL
      expect(@logger.fatal?).to be(true)
      %w{error warn debug info}.each do |logger_method|
        expect(@logger.send("#{logger_method}?")).to be(false)
      end
    end
  end # describe ":level? methods"


end # describe "Syslogger"
