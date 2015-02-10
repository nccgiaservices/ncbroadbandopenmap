ActiveAdmin.register SpeedTier do

  menu :parent => "Broadband Data"

  permit_params :code, :description

  config.sort_order = "code_asc"

  index do
    selectable_column
    column :code
    column :description
    actions
  end

  show do
    attributes_table do
      row :code
      row :description
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :code
      f.input :description
    end
    f.actions
  end

end
