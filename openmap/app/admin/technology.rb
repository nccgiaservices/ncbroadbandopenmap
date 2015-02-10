ActiveAdmin.register Technology do

  menu :parent => "Broadband Data"

  permit_params :name, :description, :position

  config.sort_order = "name_asc"

  index do
    selectable_column
    column :name
    column :position
    column :description
    actions
  end

  show do
    attributes_table do
      row :name
      row :description
      row :position
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs :name, :description, :position
    f.actions
  end

end
