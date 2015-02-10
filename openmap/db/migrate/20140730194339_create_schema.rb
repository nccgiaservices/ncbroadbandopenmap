class CreateSchema < ActiveRecord::Migration

  def self.up

    enable_extension "postgis"

    create_table :user_profile do |t|
      t.string  :username,      null: false
      t.string  :email,         null: false
      t.string  :name,          null: false
      t.boolean :active,        default: true
      ## Devise Authenticable
      t.string :encrypted_password
      ## Devise Recoverable (not yet implemented)
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      ## Devise Rememberable
      t.datetime :remember_created_at
      ## Devise Trackable
      t.integer :sign_in_count, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip
      ## Devise Lockable
      t.integer :failed_attempts, default: 0          # Only if lock strategy is :failed_attempts
      t.string :unlock_token                          # Only if unlock strategy is :email or :both
      t.datetime :locked_at

      t.timestamps

      t.index :username, unique: true
      t.index :email, unique: true
    end


    ############################################################################################
    # US Census Tiger imported shapefile tables
    #
    # The gid column is their promary key, which we import to use with the Geoserver because
    # for some reason, Geoserver does not like using the actual Postgres id primary key column!
    ############################################################################################
    create_table :state do |t|
      t.integer  :gid,     null: false
      t.string   :name,    null: false
      t.string   :statefp, null: false
      t.string   :geoid,   null: false
      t.geometry :geometry
      t.timestamps

      t.index :gid,     unique: true
      t.index :geoid,   unique: true
      t.index :statefp, unique: true
    end

    add_index :state, :geometry, spatial: true


    create_table :county do |t|
      t.integer    :gid,      null: false
      t.string     :name,     null: false
      t.string     :geoid,    null: false
      t.references :state,    null: false             # counties are always associated with a state, so this is an easy convenience reference
      t.geometry   :geometry
      t.timestamps

      t.index :gid, unique: true
      t.index :geoid, unique: true
      t.index :name                                   # county names can repeat across states
    end

    add_index :county, :geometry, spatial: true


    create_table :zip_code do |t|
      t.integer  :gid,   null: false
      t.string   :name,  null: false
      t.string   :geoid, null: false
      t.geometry :geometry
      t.timestamps

      t.index :gid, unique: true
      t.index :geoid, unique: true
      t.index :name, unique: true
    end

    add_index :zip_code, :geometry, spatial: true


    create_table :district do |t|
      t.integer    :gid,      null: false
      t.string     :name,     null: false           # Congressional districts are numbered, this may be called something else
      t.string     :geoid,    null: false
      t.references :state,    null: false           # districts are always associated with a state, so this is an easy convenience reference
      t.geometry   :geometry
      t.string     :representative                  # won't get this from census data but a placeholder to add the name of the Rep, Senator, etc
      t.timestamps

      t.index :gid, unique: true
      t.index :geoid, unique: true
      t.index :name
      t.index :state_id
    end

    add_index :district, :geometry, spatial: true



    ############################################################################################
    # Dictionary tables
    ############################################################################################

    # cai_category - e.g. 'Government', 'Library', 'Post Secondary School'
    create_table :cai_category do |t|
      t.integer  :code, null: false                         # this maps to the caicat value
      t.string   :name, null: true                          # 'Government', 'Library', 'Post Secondary School', 'School' (nullable so we can self-detect and add new caicat codes)
      t.integer  :position, null: false, default: 0
      t.boolean  :display, null: false, default: true
      t.timestamps

      t.index :code, unique: true
    end


    # speed tiers - the descriptions will be the wordy explanation (see setup data)
    create_table :speed_tier do |t|
      t.integer :code, null: false
      t.string :description                        # allow nulls for when data auto-populated from self discovery
      t.timestamps

      t.index :code, unique: true
    end


    # technology - e.g. Cable/DSL etc.
    create_table :technology do |t|
      t.string     :name,  null: false
      t.text       :description
      t.integer    :position
      t.geometry   :geometry
      t.timestamps

      t.index :name, unique: true
    end


    # tech_types - e.g. Asymmetric xDSL, Symmetric xDSL...
    create_table :tech_type do |t|
      t.integer    :code, null: false
      t.string     :name
      t.references :technology
      t.timestamps

      t.index :code, unique: true
      t.index :technology_id
    end



    ############################################################################################
    # Shapefile imported data tables
    ############################################################################################

    create_table :institution do |t|
      t.references :cai_category
      t.string     :name,  null: false
      t.string     :address
      t.string     :url
      t.string     :caiid
      t.geometry   :geometry
      t.timestamps

      t.index :name                           # do not enforce a unique constraint because we get the data imported XX unique: true
      t.index :cai_category_id
    end

    add_index :institution, :geometry, spatial: true


    # provider
    create_table :provider do |t|
      t.string :name,  null: false
      t.string :name_dba
      t.string :name_short
      t.string :website
      t.timestamps

      t.index [:name, :name_dba]
    end


    # providers can have more than one FRN
    create_table :provider_frn do |t|
      t.references :provider,   null: false
      t.string     :frn,        null: false
      t.timestamps

      t.index :provider_id
    end


    # provider_service = provider query layers - typically NOT displayed
    create_table :provider_service do |t|
      t.references :provider,    null: false
      t.references :technology,  null: false
      t.references :speed_up,    null: false, class_name: "SpeedTier"
      t.references :speed_down,  null: false, class_name: "SpeedTier"
      t.boolean    :commercial,  null: false, default: true
      t.boolean    :residential, null: false, default: true
      t.geometry   :geometry
      t.timestamps

      t.index [:provider_id, :technology_id]
    end

    add_index :provider_service, :geometry, spatial: true



    # served area are the display layers to be used on the GeoServer
    # there must be one aggregate row for each technology being served, but not necessarily unique
    #   because a given technology may have two rows, one for commercial and one for residential
    create_table :served_area do |t|
      t.references :technology,  null: false
      t.boolean    :commercial,  null: false, default: true
      t.boolean    :residential, null: false, default: true
      t.geometry   :geometry
      t.timestamps

      t.index :technology_id
    end

    add_index :served_area, :geometry, spatial: true


    ############################################################################################
    # Geoserver reference tables
    ############################################################################################

    # The map usually belongs to a state, but can optionaly have a geometry, for example, for a partial state map or a multi-state map.
    # We would normally validate a map to have either a state_id or a geometry, but because of the openmap setup and load
    # tasks, we have to allow the map to exist and be updated with those attributes later in the stepped process.
    # TODO: consider adding logo_image and logo_link attributes to configure/upload the map page logo image, and the corresponding link
    create_table :map do |t|
      t.string      :name,  null: false
      t.references  :state
      t.text        :disclaimer
      t.integer     :initial_zoom, null: false, default: 7
      t.geometry    :geometry                  # Used to find intersecting objects like zip_codes, and optionally the state the map is in
      t.point       :centroid
      t.timestamps

    end

    add_index :map, :geometry, spatial: true


    # Specifics for the creation of an SLD Style on the GeoServer
    create_table :map_style do |t|
      t.references :map,  null: false
      t.references :layerable, polymorphic: true
      t.string     :name
      t.string     :color
      t.string     :graphic_name
      t.decimal    :opacity
      t.timestamps

      t.index :map_id
    end


    # create_table :map_layer do |t|
    #   t.references :map
    #   t.string     :name
    #   t.string     :classification
    #   t.boolean    :visibility
    #   t.timestamps

    #   t.index :map_id
    # end


    ##############################################
    # foreign key constraints
    ##############################################
    foreign_key_definitions = [
      { :table => :map_style,        :relation => :map,          :column => :map_id          },
      { :table => :served_area,      :relation => :technology,   :column => :technology_id   },
      { :table => :provider_service, :relation => :provider,     :column => :provider_id     },
      { :table => :provider_service, :relation => :technology,   :column => :technology_id   },
      { :table => :provider_service, :relation => :speed_tier,   :column => :speed_up_id     },
      { :table => :provider_service, :relation => :speed_tier,   :column => :speed_down_id   },
      { :table => :provider_frn,     :relation => :provider,     :column => :provider_id     },
      { :table => :institution,      :relation => :cai_category, :column => :cai_category_id },
      { :table => :tech_type,        :relation => :technology,   :column => :technology_id   },
      { :table => :district,         :relation => :state,        :column => :state_id        },
      { :table => :county,           :relation => :state,        :column => :state_id        }
    ]

    foreign_key_definitions.each{ |fk|
      execute "ALTER TABLE #{fk[:table]} ADD CONSTRAINT fk_#{fk[:table]}_#{fk[:column]} FOREIGN KEY (#{fk[:column]}) REFERENCES #{fk[:relation]}(id)"
    }

  end


  def self.down
    # NOP
  end

end