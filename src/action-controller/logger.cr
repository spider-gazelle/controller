require "logger"
require "http/server/context"

class HTTP::Server::Context
  @logger : ActionController::Logger::TaggedLogger? = nil
  def logger
    @logger ||= ActionController::Logger::TaggedLogger.new(
      ActionController::Base.settings.logger
    )
  end
end

class ActionController::Logger < Logger
  TAGS = [] of Nil

  macro add_tag(name)
    {% TAGS << name.id %}
  end

  class TaggedLogger
    def initialize(@logger : Logger)
    end

    macro finished
      {% for tag in TAGS %}
        property {{tag}} : String?
      {% end %}

      def tags
        {
          {% for tag in TAGS %}
            {{tag}}: @{{tag}},
          {% end %}
        }
      end
    end

    {% for name in Logger::Severity.constants %}
      def {{name.id.downcase}}(message, progname = nil)
        severity = Severity::{{name.id}}
        return if severity < @logger.level

        progname = build_tags(progname)
        @logger.log(severity, message, progname)
      end

      def {{name.id.downcase}}(progname = nil)
        severity = Severity::{{name.id}}
        return if severity < @logger.level

        message = yield
        progname = build_tags(progname)
        @logger.log(severity, build_message(message), progname)
      end
    {% end %}

    def build_tags(progname)
      text = String.build do |str|
        str << " progname=" << progname if progname
        tags.each do |tag, value|
          str << " " << tag << "=" << value if value
        end
      end
    end

    forward_missing_to @logger
  end

  def initialize(io = STDOUT)
    super(io)
    self.formatter = default_format
  end

  def default_format
    Logger::Formatter.new do |severity, datetime, progname, message, io|
      label = severity.unknown? ? "ANY" : severity.to_s
      io << String.build do |str|
        str << "level=" << label << " time="
        datetime.to_rfc3339(str)
        str << progname if progname
        str << " message=" << message if message
      end
    end
  end
end
