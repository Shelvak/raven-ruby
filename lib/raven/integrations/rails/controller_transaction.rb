module Raven
  class Rails
    module ControllerTransaction
      def self.included(base)
        base.around_action do |controller, block|
          Raven.context.transaction.push "#{controller.class}##{controller.action_name}"
          block.call
          Raven.context.transaction.pop
        end
      rescue => e
        byebug
      end
    end
  end
end
