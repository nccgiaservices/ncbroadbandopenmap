ActiveAdmin.register TechType do

  menu :parent => "Broadband Data"

  permit_params :name, :code, :technology_id

  config.sort_order = "name_asc"

  index do
    selectable_column
    column :name
    column :code
    column :technology
    actions
  end

  show do
    attributes_table do
      row :name
      row :code
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :name
      f.input :code
      f.input :technology,  :as => :select, :collection => Technology.all
    end
    f.actions
  end

end
