require 'open3'
require 'logger'
require 'trollop'
require 'json'


class MailStatusNotifier

  def initialize(opts)
    @logger = Logger.new(File.open(opts[:log_file], File::WRONLY | File::APPEND | File::CREAT))
    @track_ids = get_track_ids(opts[:track_id_list])
    @config = JSON.load(IO.read(opts[:config_file]))
  end

  def run
    @track_ids.each do |track_id|
      status = get_status(track_id)
      if check_if_status_changed(track_id)
        send_email(track_id, status)
      end
    end

  end

  private

  def run_command(command_line)
    @logger.info("execute #{command_line}")
    errors = nil
    process_status = nil
    out = nil
    Open3.popen3(command_line) do |stdin, stdout, stderr, wait_thread|
      stdout.set_encoding("ASCII-8BIT") if stdout.respond_to? :set_encoding
      stderr.set_encoding("ASCII-8BIT") if stderr.respond_to? :set_encoding
      out = stdout.read
      errors = stderr.read
      # Wait for the program to finish
      process_status = wait_thread.value
    end
    if(process_status.exitstatus != 0)
      @logger.error("Failed to execute #{command_line}, error = #{errors}")
    end
    out
  end

  def check_if_status_changed(track_id)
    true
  end

  def get_status(track_ids)
    run_command("phantomjs /home/dev/mail_notification/mail_notification.js")
  end

  def get_track_ids(track_id_list)
    return [] if !track_id_list
    IO.readlines(track_id_list).map { |m| m.chomp }
  end

  def send_email(track_id, status_string)
    from = @config["email"]["from"]
    to_list = @config["email"]["to_list"]
    body = <<-EOK
      The Status of your delivery has changed to:
      #{status_string}
    EOK
    to_list.each do |to|
      run_command("mail -r #{from} -s \"status of tracking id #{track_id}\" has changed! #{to} #{body}")
    end
  end
end

opts = Trollop::options do
  opt :log_file, "Log file", :type => :string, :required => true
  opt :config_file, "Config file", :type => :string, :required => true
  opt :track_id_list, "File that list track ids", :type => :string, :required => true
end

mail_notifier = MailStatusNotifier.new(opts)
mail_notifier.run
