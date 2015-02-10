ActiveAdmin.register District do

  menu :parent => "Census Data"

  permit_params :state_id, :name, :geoid, :gid

  config.sort_order = "name_asc"

  index do
    selectable_column
    column :name
    column :geoid
    column :gid
    column :state
    actions
  end

  show do
    attributes_table do
      row :name
      row :geoid
      row :gid
      row :state
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :name
      f.input :geoid
      f.input :gid
      f.input :state,  :as => :select, :collection => State.all
    end
    f.actions
  end

end
