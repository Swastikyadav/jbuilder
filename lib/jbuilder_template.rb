class JbuilderTemplate < Jbuilder
  def initialize(context, *args)
    @context = context
    super(*args)
  end

  def partial!(options, locals = {})
    case options
    when ::Hash
      options[:locals] ||= {}
      options[:locals].merge!(:json => self)
      @context.render(options)
    else
      @context.render(options, locals.merge(:json => self))
    end
  end

  # Caches the json constructed within the block passed. Has the same signature as the `cache` helper 
  # method in `ActionView::Helpers::CacheHelper` and so can be used in the same way.
  #
  # Example:
  #
  #   json.cache! ['v1', @person], :expires_in => 10.minutes do |json|
  #     json.extract! @person, :name, :age
  #   end
  def cache!(key=nil, options={}, &block)
    pos = @context.output_buffer.length
    output_safe = @context.output_buffer.html_safe?
    if output_safe
      @context.output_buffer = @context.output_buffer.class.new(@context.output_buffer)
    end
    @context.cache(key, options) do
      jb = ::JbuilderTemplate.new(@context)
      block.call(jb)
      @context.safe_concat(jb.target!.html_safe)
    end
    fragment = @context.output_buffer.slice!(pos..-1)
    value = ::MultiJson.load(fragment)

    if value.is_a?(::Array)
      array! value
    else
      value.each do |k, v|
        set! k, v
      end
    end
  end
end

class JbuilderHandler
  cattr_accessor :default_format
  self.default_format = Mime::JSON

  def self.call(template)
    # this juggling is required to keep line numbers right in the error
    %{__already_defined = defined?(json); json||=JbuilderTemplate.new(self); #{template.source}
      json.target! unless __already_defined}
  end
end

ActionView::Template.register_template_handler :jbuilder, JbuilderHandler
