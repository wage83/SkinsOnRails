module SkinsOnRails
  module Config
    extend self

    # Config file at level application
    CONFIG_FILE = File.join(RAILS_ROOT, "config", "skin.yml")

    # Directory where skins will be saved
    SKIN_DIR = File.join(RAILS_ROOT, "skins")

    # Public skins directory
    PUBLIC_DIR = "public/"

    # Prefix for skin public directory
    PUBLIC_PREFIX = "skin_"

    # Skin on use
    attr_accessor :skin_name

    # Final skin directory
    attr_accessor :skin_final_dir

    # Skin public access directory
    attr_accessor :skin_public

    # Establish skin_final_dir with skin_name
    def skin_name=(name)
      # Is skin already defined?
      if !skin_name.nil?
        raise RuntimeError, "Skin can be set only once. It tried to change to #{name}"
      end

      # Mongrel prefix
      mongrel_prefix = nil
      ObjectSpace.each_object(Mongrel::Rails::RailsConfigurator) {|o| mongrel_prefix = o.defaults[:prefix] }
      mongrel_prefix = "#{mongrel_prefix}/"

      @skin_name = name
      self.skin_final_dir = File.join(SKIN_DIR, skin_name, "views")

      self.skin_public = mongrel_prefix + PUBLIC_PREFIX + skin_name + "/"

      # Register URI and adds new DirHandler for skin public directory
      if defined?(Mongrel::HttpServer)
        ObjectSpace.each_object(Mongrel::HttpServer) { |mongrel|
          mongrel.register([mongrel_prefix, PUBLIC_PREFIX, skin_name].join,
                           Mongrel::DirHandler.new(File.join(SKIN_DIR, skin_name, PUBLIC_DIR), false))
        }
      end

      # Load code for the skin, if any
      init_skin_file = File.join(SKIN_DIR, skin_name, "init.rb")
      if File.exist?(init_skin_file)
        load init_skin_file
      end
    end

    # Path to the routes files
    def routes_file
      fn = File.join SKIN_DIR, skin_name.to_s, "routes.rb"
      File.exist?(fn) ? fn : File.join(RAILS_ROOT, "config", "default_routes.rb")
    end
  end

  def self.is_skin_set?
    Config.skin_name.nil? ? false : true
  end

  def self.init!
    if File.exist?(SkinsOnRails::Config::CONFIG_FILE)
      YAML.load(File.read(SkinsOnRails::Config::CONFIG_FILE)).each_pair {|key, value|
        SkinsOnRails::Config.send("#{key}=", value)
      }
    end
  end
end

module ActionController
  class Base

  protected
    def render_with_skin(*args, &block)
      if SkinsOnRails.is_skin_set? and not @skin_path_loaded
        @skin_path_loaded = true
        if self.respond_to?("finder") # for rails 2.1
          self.finder.prepend_view_path(SkinsOnRails::Config::skin_final_dir)
        else
          self.prepend_view_path(SkinsOnRails::Config::skin_final_dir)
        end
      end

      render_without_skin(*args, &block)
    end

    alias_method_chain :render, :skin

  end
end

module ActionView

  module Helpers::AssetTagHelper

    def skin_public_file_abs_path(filename)
      File.join(SkinsOnRails::Config::SKIN_DIR,
                SkinsOnRails::Config.skin_name,
                SkinsOnRails::Config::PUBLIC_DIR,
                filename)
    end

    def image_path_with_skin(path)
      if SkinsOnRails.is_skin_set? and File.exists?(skin_public_file_abs_path("images/#{path}"))
        compute_public_path(path, SkinsOnRails::Config::PUBLIC_PREFIX + SkinsOnRails::Config.skin_name + "/images")
      else
        image_path_without_skin(path)
      end
    end

    alias_method_chain :image_path, :skin
    alias_method :path_to_image, :image_path

    def stylesheet_path_with_skin(source)
      if SkinsOnRails.is_skin_set? and File.exists?(skin_public_file_abs_path("stylesheets/#{source}"))
        SkinsOnRails::Config.skin_public + "stylesheets/" + source
      else
        stylesheet_path_without_skin source
      end
    end

    alias_method_chain :stylesheet_path, :skin
    alias_method :path_to_stylesheet, :stylesheet_path

    def skin_javascript_path(source)
        if File.extname(source).blank?
          source = source + ".js"
        end
        if SkinsOnRails.is_skin_set? and File.exists?(skin_public_file_abs_path("javascripts/#{source}"))
          SkinsOnRails::Config.skin_public + "javascripts/" + source
        else
          default_javascript_path(source)
        end
    end

    alias_method :default_javascript_path, :javascript_path
    alias_method :javascript_path, :skin_javascript_path
    alias_method :path_to_javascript, :skin_javascript_path
  end

end

# vim: sw=2 sts=2
