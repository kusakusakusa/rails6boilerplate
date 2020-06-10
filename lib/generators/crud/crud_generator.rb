# frozen_string_literal: true

class CrudGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  def copy_initializer_file
    template "index.html.slim", "app/views/cms/#{file_name}/index.html.slim"
    template "edit.html.slim", "app/views/cms/#{file_name}/edit.html.slim"
    template "show.html.slim", "app/views/cms/#{file_name}/show.html.slim"
    template "new.html.slim", "app/views/cms/#{file_name}/new.html.slim"
    template "_form.html.slim", "app/views/cms/#{file_name}/_form.html.slim"
    template "controller.rb", "app/controllers/cms/#{file_name}_controller.rb"
    inject_into_file("config/routes.rb", "    resources :#{file_name}\n", after: "namespace :cms do\n")
    puts "Remember to handle the strong params in app/controllers/cms/#{file_name}_controller.rb"
  end

  private

  def underscored
    name.underscore.singularize
  end

  def file_name
    underscored.pluralize
  end
end
