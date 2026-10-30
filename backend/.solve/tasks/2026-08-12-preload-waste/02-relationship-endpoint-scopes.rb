# bin/rails runner .solve/tasks/2026-08-12-preload-waste/02-relationship-endpoint-scopes.rb
Current.without_organization_and_membership_scopes do
  pp linkable_attributes: Component.linkable.first.attributes
  pp includable_no_fields: Component.includable({ fields: {} }).preload_values
  pp includable_name_only: Component.includable({ fields: { 'components' => ['name'] } }).preload_values
end
