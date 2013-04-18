require 'pry'
class ExceptionNotifier
  class WebhookNotifier

    def initialize(options)
      @default_options = options
    end

    def call(exception, options={})
      options = options.reverse_merge(@default_options)
      url = options.delete(:url)
      http_method = options.delete(:http_method) || :post

      binding.pry
      @exception = exception
      @kcontroller = options[:env]["action_controller.instance"] || MissingController.new
      @request = ActionDispatch::Request.new(options[:env])

      options[:body] ||= {}
      options[:body][:app_name]         = collect_app_name
      options[:body][:current_env]      = Rails.env
      options[:body][:language_version] = collect_language_version
      options[:body][:exception]        = collect_exception
      options[:body][:kcontroller]      = collect_controller
      options[:body][:request]          = collect_request
      options[:body][:session]          = collect_sessions
      options[:body][:environment]      = collect_environment

      HTTParty.send(http_method, url, options)
    end

    class MissingController
      def method_missing(*args, &block)
      end
    end

    private
    def collect_app_name
      Rails.application.engine_name.sub("_application", "")
    end

    def collect_language_version
      "ruby: #{RUBY_VERSION rescue '?.?.?'} p#{RUBY_PATCHLEVEL rescue '???'},ruby_plamform: #{RUBY_PLATFORM rescue '????'}"
    end

    def collect_exception
      {
        error_class: @exception.class.name,
        message: @exception.message.inspect,
        backtrace: @exception.backtrace
      }
    end

    def collect_controller
      {
        controller: @kcontroller.controller_name,
        action: @kcontroller.action_name
      }
    end

    def collect_request
      {
        url: @request.url,
        remote_ip: @request.remote_ip,
        params: inspect_object(@request.filtered_parameters),
        rails_root: Rails.root,
        timestamp: Time.current.inspect
      }
    end

    def collect_sessions
      {
        session_id: @request.ssl? ? "[FILTERED]" : ((@request.session['session_id'] || @request.env["rack.session.options"][:id]).inspect),
        data: inspect_object(@request.session)
      }
    end

    def collect_environment
      filtered_env = @request.filtered_env
      max = filtered_env.keys.map(&:to_s).max { |a, b| a.length <=> b.length }

      env_str = ""

      filtered_env.keys.map(&:to_s).sort.each do |key|
        env_str << "* :#{key} => #{inspect_object(filtered_env[key])}\n"
      end

      env_str
    end

  # helper methods for private methods
    def inspect_object(object)
      case object
      when Array
        object.inspect
      when Hash
        extra_hash(object)
      else
        object.to_s
      end
    end

    def extra_hash(hash)
      object_str = "{\n"
      hash.each do |key, value|
        object_str << ":#{key} => #{value.inspect}\n"
      end
      object_str << "}"
    end

  end

end
