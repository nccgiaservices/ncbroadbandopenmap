namespace :deploy do

  DEFAULT_EXCLUDES = ['/log', '/tmp', '/doc', '/db', '/test', '/.gem', '/sqlnet.log', '.DS_Store',
              '/.project', '/.idea',
              '.git*', '.gitattributes', '.gitignore',
              '/.bundle', '/vendor/bundle', # bundler settings should be local to the deployment env. Making sure to not copy DEV's over
              '/public/assets',
              '/public/images/calendar_date_select', '/public/javascripts/calendar_date_select', '/public/stylesheets/calendar_date_select',
              '/public/system/dragonfly']

  task :ncc432 do
    deploy("low00001@ncc432.its.state.nc.us", '/brim/topsail/openmap', 'production', true, 'sudo su - topsail')
  end

  # ncc431 - the public webserver
  task :production do
    deploy("low00001@ncc431.its.state.nc.us", '/brim/topsail/openmap', 'production', true, 'sudo su - topsail')
  end

  ####################################################################
  private
  ####################################################################

  def deploy(ssh_connect, app_base_path, env, asset_clean=false, ssh_shell_init_cmd=nil)
    # hand-rolled deploy because of user low00001 to topsail requirement

    validate_deploy_ignore()

    ssh_shell_init_cmd = ssh_shell_init_cmd && (ssh_shell_init_cmd + ';')

    ###### ====> change puts to sh  ## this doesn't work - so puts the command and run by hand
    # sync files
    puts "rsync -rCv '#{Rails.root}'/ --delete --exclude-from='#{Rails.root}/.deploy_ignore' #{ssh_connect}:#{app_base_path}"

    # rsync files as low00001 then set group permissions the same as owner so topsail can do it's stuff
    ###### this only needs to be done once - done.
    puts "ssh #{ssh_connect} \"cd #{app_base_path}; chmod -R g=u * \""

    # the production server at has ruby 2.0.0-p451 installed so fixup the .ruby-version
    puts "ssh #{ssh_connect} \"#{ssh_shell_init_cmd} echo '2.0.0-p451' > #{app_base_path}/.ruby-version"

    # bundle
    puts "ssh #{ssh_connect} \"#{ssh_shell_init_cmd} cd #{app_base_path}; bundle install --deployment --without test development\""

    # create assets
    puts "ssh #{ssh_connect} \"#{ssh_shell_init_cmd} cd #{app_base_path}; bundle exec rake #{'assets:clean' if asset_clean} assets:precompile RAILS_ENV=#{env}\""

    # restart
    puts "ssh #{ssh_connect} \"#{ssh_shell_init_cmd} mkdir -p #{app_base_path}/tmp; echo `date` > #{app_base_path}/tmp/restart.txt\""
  end

  def validate_deploy_ignore
    unless File.file?("#{Rails.root}/.deploy_ignore")
      puts "Your aplication's root directory must have a .deploy_ignore file!"
      puts "A good file to start with could be:"
      puts
      DEFAULT_EXCLUDES.each{ |f| puts f }
      puts
      raise "File /.deploy_ignore missing!"
    end
  end

end
