require 'rake'
require 'rake/gempackagetask'
require 'rake/clean'
require 'rake/testtask'
require 'find'
require 'fileutils'
require 'rubyforge'
require 'ruby_forge_config'
namespace :rgem do
  
  namespace :package do
  
    desc "Package up the application_configuration gem."
    task :application_configuration do |t|
      rfc = RubyForgeConfig.load(__FILE__)
      pwd = FileUtils.pwd
      FileUtils.cd "#{RAILS_ROOT}/vendor/plugins/#{rfc.gem_name}"
      gem_spec = Gem::Specification.new do |s|
        s.name = rfc.gem_name
        s.version = rfc.version
        s.summary = rfc.gem_name
        s.description = %{#{rfc.gem_name} was developed by: markbates}
        s.author = "markbates"

        s.files = FileList["**/*.*"].exclude("pkg").exclude("#{rfc.gem_name}_tasks.rake")
        s.require_paths << 'lib'

        # This will loop through all files in your lib directory and autorequire them for you.
        # It will also ignore all Subversion files.
        s.autorequire = []
      
        ["lib"].each do |dir|
          Find.find(dir) do |f|
            if FileTest.directory?(f) and !f.match(/.svn/)
              s.require_paths << f
            else
              if FileTest.file?(f)
                m = f.match(/\/[a-zA-Z-_]*.rb/)
                if m
                  model = m.to_s
                  unless model.match("test_")
                    #puts "model = #{model}"
                    x = model.gsub('/', '').gsub('.rb', '')
                    s.autorequire << x
                  end
                  #puts x
                end
              end
            end
          end
        end

        s.rubyforge_project = rfc.project
      end
      Rake::GemPackageTask.new(gem_spec) do |pkg|
        pkg.package_dir = "#{RAILS_ROOT}/pkg"
        pkg.need_zip = false
        pkg.need_tar = false
      end
      Rake::Task["package"].invoke
      FileUtils.cd pwd
    end
  
  end
  
  namespace :install do
    
    desc "Package up and install the application_configuration gem."
    task :application_configuration => "rgem:package:application_configuration" do |t|
      rfc = RubyForgeConfig.load(__FILE__)
      rfc.install("#{RAILS_ROOT}/pkg")
    end
    
  end
  
  namespace :release do
    
    desc "Package up, install, and release the application_configuration gem."
    task :application_configuration => ["rgem:install:application_configuration"] do |t|
      rfc = RubyForgeConfig.load(__FILE__)
      rfc.release
    end
    
  end
  
end