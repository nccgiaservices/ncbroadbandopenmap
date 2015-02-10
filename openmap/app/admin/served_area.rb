ActiveAdmin.register ServedArea do

  menu :parent => "Broadband Data"

  permit_params :technology_id, :commercial, :residential

  config.sort_order = "technology"

  index do
    selectable_column
    column :technology
    column :commercial
    column :residential
    actions
  end

  show do
    attributes_table do
      row :technology
      row :commercial
      row :residential
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :technology,  :as => :select, :collection => Technology.all
      f.input :commercial
      f.input :residential
    end
    f.actions
  end

end
