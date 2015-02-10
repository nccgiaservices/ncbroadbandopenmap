ActiveAdmin.register Provider do

  menu :parent => "Broadband Data"

  permit_params :name, :name_dba, :name_short, :website

  config.sort_order = "name_asc"

  index do
    selectable_column
    column :name
    column :name_dba
    column :name_short
    column :website
    actions
  end

  show do
    attributes_table do
      row :name
      row :name_dba
      row :name_short
      row :website
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs :name, :name_dba, :name_short, :website
    f.actions
  end

end
