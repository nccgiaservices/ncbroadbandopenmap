ActiveAdmin.register State do

  menu :parent => "Census Data"

  permit_params :name, :code, :technology_id

  config.sort_order = "name_asc"

  index do
    selectable_column
    column :name
    column :statefp
    column :geoid
    actions
  end

  show do
    attributes_table do
      row :name
      row :statefp
      row :geoid
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :name
      f.input :statefp
      f.input :geoid
    end
    f.actions
  end

end
