ActiveAdmin.register Institution do

  menu :parent => "Broadband Data"

  permit_params :cai_category_id, :name, :address, :url, :caiid

  config.sort_order = "name_asc"

  index do
    selectable_column
    column :name
    column :cai_category
    column :caiid
    column :address
    actions
  end

  show do
    attributes_table do
      row :name
      row :cai_category
      row :caiid
      row :address
      row :url
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :name
      f.input :cai_category,  :as => :select, :collection => CaiCategory.all
      f.input :caiid
      f.input :address
      f.input :url
    end
    f.actions
  end

end