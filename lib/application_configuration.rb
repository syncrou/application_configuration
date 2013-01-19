require 'rubygems'
require 'singleton'
require 'yaml'
require 'erb'
module Application
  
  class Configuration
    
    DEFAULT_RELOAD_SETTINGS_EVERY = 1200
    
    include Singleton
    
    class << self
      
      def method_missing(sym, *args)
        inst = Application::Configuration.instance
        # check to see if the configuration needs to be reloaded.
        unless inst.reload_settings_every == -1
          if (Time.now - (inst.reload_settings_every || DEFAULT_RELOAD_SETTINGS_EVERY)) > inst.last_reload_time
            inst.reload
          end
        end
        inst.send(sym, *args)
      end
      
    end

    attr_reader   :final_configuration_settings #stores the final configuration settings
    attr_reader   :last_reload_time #stores the last time settings were reloaded
    attr_reader   :is_rails #stores whether or not we're in a rails app
    attr_reader   :loaded_files
    attr_reader   :rails_root
    attr_reader   :rails_env
    attr_accessor :whiny_config_missing
    
    def initialize
      self.whiny_config_missing = false
      @loaded_files = []
      @final_configuration_settings = {:reload_settings_every => DEFAULT_RELOAD_SETTINGS_EVERY}
      @last_reload_time = Time.now # set the first load time
      @is_rails = Rails.class == Module && Rails.respond_to?(:env) # set whether it's rails
      if self.is_rails
        @rails_root = Rails.root
        @rails_env = Rails.env
        self.whiny_config_missing = true unless Rails.env == "production"
        self.loaded_files << Application::Configuration::Location.new("#{Rails.root}/config/application_configuration.yml")
        self.loaded_files << Application::Configuration::Location.new("#{Rails.root}/config/application_configuration_#{Rails.env}.yml")
        self.loaded_files.uniq!
      end
      reload # do the work!
    end
    
    def load_file(path_to_file)
      unless path_to_file.nil?
        begin
          path_to_file = Application::Configuration::Location.new(path_to_file) if path_to_file.is_a? String
          settings = load_from_file(path_to_file.name)
          handle_settings(settings, path_to_file)
          return self
        rescue Exception => e
          puts e.message
          return nil
        end
      end
    end
    
    def load_url(path_to_file)
      require 'open-uri'
      unless path_to_file.nil?
        begin
          path_to_file = Application::Configuration::Location.new(path_to_file, Application::Configuration::Location::URL) if path_to_file.is_a? String
          settings = load_from_url(path_to_file.name)
          handle_settings(settings, path_to_file)
          return self
        rescue Exception => e
          puts e.message
          return nil
        end
      end
    end
    
    def load_hash(settings, name)
      loc = Application::Configuration::Location.new(name, Application::Configuration::Location::HASH)
      loc.options = settings
      handle_settings(settings, loc)
      return self
    end
    
    def reload
      #puts "Loading Configuration Settings!"
      @final_configuration_settings = {:reload_settings_every => DEFAULT_RELOAD_SETTINGS_EVERY} # reset the configuration

      self.loaded_files.each do |lf|
        case lf.type
        when Application::Configuration::Location::FILE
          #puts "Loading Configuration Settings from file: #{lf.name}"
          load_file(lf)
        when Application::Configuration::Location::URL
          #puts "Loading Configuration Settings from url: #{lf.name}"
          load_url(lf)
        when Application::Configuration::Location::HASH
          #puts "Loading Configuration Settings from hash: #{lf.name}"
          load_hash(lf.options, lf.name)
        else
          raise TypeError.new("The Application::Configuration::Location type '#{lf.type}' is not supported!")
        end
      end
      @last_reload_time = Time.now
    end
    
    def revert(step = 1)
      step.times {self.loaded_files.pop}
      reload
    end
    
    def dump_to_screen
      y = self.final_configuration_settings.to_yaml
      puts y
      y
    end
    
    def dump_to_file(file_name = (self.is_rails ? "#{self.rails_root}/config/application_configuration_dump.yml" : "application_configuration_dump.yml"))
      File.open(file_name, "w") {|file| file.puts self.final_configuration_settings.to_yaml}
      puts "Dumped configuration settings to: #{file_name}"
      dump_to_screen
    end
    
    def method_missing(sym, *args)
      puts %{
WARNING: Tried to access configuration parameter: #{sym}, but there is no configuration parameter defined with this name. This is not an error, just an informative message. There is no need to open a bug report for this. Sometimes developers only use a configuration parameter to help debug in testing or development, and there is no need to litter other configuration files with these unnecessary parameters. Thank you.
      } if self.whiny_config_missing
      return nil
    end
    
    private
    def load_from_file(file)
      template = ERB.new(File.open(file).read)
      YAML.load(template.result)
    end
    
    def load_from_url(file)
      template = ERB.new(open(file).read)
      YAML.load(template.result)
    end
    
    def handle_settings(settings, location)
      @final_configuration_settings.merge!(settings || {})
      # puts "@final_configuration_settings: #{@final_configuration_settings.inspect}"
      fcs = @final_configuration_settings.dup
      self.final_configuration_settings.dup.each_pair do |k,v|
        k = k.to_s.downcase
        # start a list of methods that need to be generated
        # methods can't have :: in them so convert these to __.
        e_meths = [k.gsub("::", "__")]
        if k.match("::")
          vars = k.split("::") # get the namespace and the method names
          mod = vars.first # namespace
          e_meths << mod # generate a method for the namespace
          # create a new Namespace object for this name space and assign it to the final_configuration_settings hash.
          fcs[mod.to_s] = Application::Configuration::Namespace.new(mod.to_s)
          # add an entry for the __ version of the key so our __ method can call it.
          fcs[e_meths.first] = v
        end
        # generate all the necessary getter methods
        e_meths.each do |m|
          eval %{
            def #{m}
              v = self.final_configuration_settings["#{m}"]
              if v.nil?
                return self.final_configuration_settings[:#{m}]
              end
              return v
            end
          }
        end
      end
      @final_configuration_settings = fcs
      @loaded_files << location
      @loaded_files.uniq!
    end
    
    # this class is used to namespace configurations
    class Namespace
      
      attr_accessor :namespace_name
      
      def initialize(name)
        self.namespace_name = name
      end
      
      def to_s
        self.namespace_name
      end
      
      def method_missing(sym, *args)
        Application::Configuration.send("#{self}__#{sym}", *args)
      end
      
    end
    
    class Location
      
      attr_accessor :type
      attr_accessor :name
      attr_accessor :options
      
      def initialize(loc, type = Application::Configuration::Location::FILE)
        self.type = type
        self.name = loc
      end
      
      def self.supported_types
        [Application::Configuration::Location::FILE, Application::Configuration::Location::URL, Application::Configuration::Location::HASH]
      end
      
      FILE = :file
      URL  = :url
      HASH = :hash
      
      def ==(other)
        self.name.to_s == other.name.to_s
      end
      
      def eql?(other)
        self.name.to_s == other.name.to_s
      end
      
      def hash
        self.name.to_s.hash
      end
      
    end
    
  end
  
end

class Object
  
  def app_config
    Application::Configuration
  end
  
end
