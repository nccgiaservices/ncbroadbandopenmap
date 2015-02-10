ActiveAdmin.register CaiCategory do

  menu :parent => "Broadband Data"

  permit_params :code, :name, :display, :position

  config.sort_order = "name_asc"

  index do
    selectable_column
    column :name
    column :code
    column :position
    column :display
    actions
  end

  show do
    attributes_table do
      row :name
      row :code
      row :position
      row :display
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs :name, :code, :position, :display
    f.actions
  end

end
