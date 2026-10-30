Rails.application.configure do
  console do
    module ConsoleScopeHelper
      def unscope!
        Current.membership = Current::ALL_MEMBERSHIPS
        Current.organization = Current::ALL_ORGANIZATIONS
      end

      def scope!(record)
        case record
        when Membership
          Current.membership = record
          Current.organization = record.organization
        when Organization
          Current.membership = nil
          Current.organization = record
        else
          raise(ArgumentError, "expected a Membership or Organization, got #{record.class}")
        end
      end
    end

    TOPLEVEL_BINDING.eval('self').extend(ConsoleScopeHelper)
  end
end
