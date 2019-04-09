require 'binding_of_caller'

module Raven
  module ExceptionExtension
    prepend_features Exception

    def set_backtrace(*)
      if caller_locations.none? { |loc| loc.path == __FILE__ }
        @__binding_errors = ::Kernel.binding.callers.drop(1)
      end

      super
    end

    def __binding_errors
      @__binding_errors || []
    end

    def bind_errors_to_backtrace!
      @bind_errors_to_backtrace ||= __binding_errors.map do |line|
        file = line.instance_variable_get(:@iseq).path
        next unless ::Raven::Backtrace::Line.in_app?(file)

        ::Raven::Backtrace::Line.new(
          line.eval('__FILE__'),
          line.eval('__LINE__'),
          line.frame_description,
          nil,
          assign_verbose_local_variables_for(line).except(
            :view, :block # view and block don't have much useful info
          )
        )
     end.compact
    end

    def assign_verbose_local_variables_for(line)
      locals = (line.eval('local_variables') rescue [])
      locals.inject({}) do |memo, key|
        value = (line.eval(key.to_s) rescue nil)
        memo.merge!({
          key.to_sym => value_to_log(value)
        })
      end
    end

    def verbose_local_variables
      (@bind_errors_to_backtrace || []).map do |line|
        { line.to_s => line.local_variables }
      end
    end

    def value_to_log(value)
      if [Hash].include?(value.class )
        value.each_with_object({}) do |(k, v), memo|
          memo[k] = value_to_log(v)
        end
      elsif value.respond_to?(:to_a)
        value.to_a.map do |v|
          if v.respond_to?(:id)
            { id: v.try(:id), name: v.try(:name) }
          else
            v
          end
        end
      else
        value.inspect
      end
    rescue
      value
    end
  end
end
