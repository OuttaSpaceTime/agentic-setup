org = Organization.first
Current.organization = org

relation_class = MonitoringListMonitoringListRelation
relation_table_name = relation_class.table_name

anchor = relation_class
  .where(monitoring_list_from_id: ['dummy-id'])
  .select(:monitoring_list_to_id, :organization_id)

recursive = relation_class
  .joins("JOIN descendants ON descendants.monitoring_list_to_id = #{relation_table_name}.monitoring_list_from_id")
  .select("#{relation_table_name}.monitoring_list_to_id", :organization_id)

final = relation_class
  .with_recursive(descendants: Arel.sql("#{anchor.to_sql} UNION #{recursive.to_sql}"))
  .from("descendants AS #{relation_table_name}")
  .select(:monitoring_list_to_id)

puts final.to_sql
