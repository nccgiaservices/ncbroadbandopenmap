ActiveAdmin.register ProviderService do

  menu :parent => "Broadband Data"

  permit_params :provider_id, :technology_id, :commercial, :residential

  config.sort_order = "provider"

  index do
    selectable_column
    column :provider
    column :technology
    column :speed_up
    column :speed_down
    column :commercial
    column :residential
    actions
  end

  show do
    attributes_table do
      row :provider
      row :technology
      row :speed_up
      row :speed_down
      row :commercial
      row :residential
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :provider,    :as => :select, :collection => Provider.all
      f.input :technology,  :as => :select, :collection => Technology.all
      f.input :speed_up,    :as => :select, :collection => SpeedTier.all.pluck(:code, :id)
      f.input :speed_down,  :as => :select, :collection => SpeedTier.all.pluck(:code, :id)
      f.input :commercial
      f.input :residential
    end
    f.actions
  end

end
