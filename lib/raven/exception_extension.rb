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
      rails_root = ::Rails.root.to_s
      (self.backtrace || []).each_with_index do |line, i|
        if line.start_with?(rails_root)
          line.instance_variable_set(
            :@__local_variables,
            assign_redacted_local_variables_for(__binding_errors[i])
          )
        end
      end
    end

    def assign_redacted_local_variables_for(line)
      locals = (line.eval('local_variables') rescue [])
      locals.inject({}) do |memo, key|
        value = (line.eval(key.to_s) rescue nil)
        memo.merge!({
          key.to_sym => value_to_log(value)
        })
      end
    end

    def redacted_local_variables_for(line)
      line.instance_variable_get(:@__local_variables) || {}
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
