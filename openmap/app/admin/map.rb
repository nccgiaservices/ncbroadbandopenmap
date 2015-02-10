ActiveAdmin.register Map do

  permit_params :state_id, :name, :disclaimer

  config.sort_order = "name_asc"

  index do
    selectable_column
    column :name
    column :state
    actions
  end

  show do
    attributes_table do
      row :name
      row :state
      row :disclaimer
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :name
      f.input :state,  :as => :select, :collection => State.all
      f.input :disclaimer
    end
    f.actions
  end

end
