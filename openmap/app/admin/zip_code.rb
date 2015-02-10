ActiveAdmin.register ZipCode do

  menu :parent => "Census Data"

  permit_params :name, :gid, :geoid

  config.sort_order = "name_asc"

  index do
    selectable_column
    column :name
    column :geoid
    column :gid
    actions
  end

    show do
    attributes_table do
      row :name
      row :geoid
      row :gid
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs :name, :geoid, :gid
    f.actions
  end

end
