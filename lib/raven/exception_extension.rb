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
      self.backtrace.each_with_index do |line, i|
        if line.start_with?(rails_root)
          line.instance_variable_set(
            :@__local_variables,
            redacted_local_variables_for(__binding_errors[i])
          )
        end
      end
    end

    def redacted_local_variables_for(line)
      locals = (line.eval('local_variables') rescue [])
      locals.inject({}) do |memo, key|
        memo.merge!({
          key.to_sym => (line.eval(key.to_s) rescue nil)
        })
      end
    end
  end
end
