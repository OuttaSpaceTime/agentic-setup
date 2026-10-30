class Inbox::MonitoringListComponentEol::DeliveryJob < ApplicationJob
  include ActiveJob::Continuable

  def perform(event, organization)
    Current.set(organization: organization) do
      step :deliver_items, start: nil do |step|
        ml_ids_by_membership(event, after: step.cursor).each do |membership_id, ml_ids|
          Inbox::Item.create!(
            membership_id: membership_id,
            itemable: Inbox::Item::MonitoringList::ComponentEol.new(
              event: event, membership_id: membership_id, monitoring_list_ids: ml_ids
            )
          )
          step.set!(membership_id)
        end
      end
    end
  end
