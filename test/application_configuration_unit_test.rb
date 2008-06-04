require File.join(File.dirname(__FILE__), 'test_helper')
require 'webrick'
include WEBrick

class ConfServlet < HTTPServlet::AbstractServlet
  def do_GET(request, response)
    # puts "request: #{request.inspect}"
    h = {"url_test" => "remote", "some_remote_config" => "wizbang!"}
    response.status = 200
    response.body = h.to_yaml
    response["Content-Type"] = "text/yaml"
  end

  alias :do_POST :do_GET
end

class ConfServer
  
  class << self
    
    attr_accessor :server
    
    def start
      server = HTTPServer.new(:Port => 8000)
      server.mount("/conf", ConfServlet)

      ["TERM", "INT"].each do |signal|
        trap(signal){server.shutdown}
      end
      server.start
    end
    
    def stop
      server.shutdown
    end
    
  end
  
end


class ApplicationConfigurationUnitTest < Test::Unit::TestCase

  def setup
    Application::Configuration.whiny_config_missing = false
  end
  
  def teardown
    Application::Configuration.whiny_config_missing = true
  end
  
  def test_false
    assert !app_config.should_be_false
    assert_not_nil app_config.should_be_false
  end

  def test_param_doesnt_exist
    assert_nil Application::Configuration.asldkfjasdfkljasdfsldj
  end

  def test_loads_application_configuration
    assert_equal "bar", Application::Configuration.foo
    assert_equal 4, Application::Configuration.four
    assert_equal({"one" => 1, "two" => 2, "three" => 3}, Application::Configuration.my_hash)
    assert_equal Time.now.beginning_of_month, Time.parse(Application::Configuration.my_time)
    assert_equal([1, 2, 3, "mark", "bates"], Application::Configuration.my_array)
  end
  
  def test_environment_overrides
    assert_equal "rock!", Application::Configuration.pickles
  end
  
  def test_reload_every
    time = Application::Configuration.instance.last_reload_time
    assert_not_nil time
    assert_equal "bar", Application::Configuration.foo
    sleep(3)
    assert_equal "bar", Application::Configuration.foo
    assert Application::Configuration.instance.last_reload_time > time
  end
  
  def test_nested_arrays
    assert_equal([["Pro", "Con"], ["Yes", "No"], ["For", "Against"], ["Agree", "Disagree"], ["Support", "Oppose"], ["True", "False"], ["Innocent", "Guilty"], ["Right", "Wrong"]], Application::Configuration.all_debate_pairing_options)
  end
  
  def test_namespaces
    assert_equal "my foo", Application::Configuration::instance.final_configuration_settings["my__foo"]
    assert_equal "my foo", Application::Configuration.my__foo
    assert_equal "my foo", Application::Configuration.my.foo
    assert_equal Application::Configuration.my__foo, Application::Configuration.my.foo
    assert_equal "marky kang", Application::Configuration::mark__name
    assert_equal "marky kang", Application::Configuration::mark.name
    assert_equal Application::Configuration::mark__name, Application::Configuration::mark.name
  end
  
  def test_object_hook
    assert_equal Application::Configuration.pickles, app_config.pickles
  end
  
  def test_load_file
    # assert_nil Application::Configuration.add
    assert_nil Application::Configuration.add
    assert_instance_of Application::Configuration, Application::Configuration.load_file("#{RAILS_ROOT}/config/application_configuration_additional.yml")
    assert_equal 2, Application::Configuration.add
    assert_equal "bar", Application::Configuration.foo
    Application::Configuration.reload
    assert_equal 2, Application::Configuration.add
    assert_equal "bar", Application::Configuration.foo
  end
  
  def test_load_file_not_found
    assert_nil Application::Configuration.load_file("asldfjasdfljasdflsdfjasdl")
  end
  
  def test_load_url_not_found
    assert_nil Application::Configuration.load_url("asldfjasdfljasdflsdfjasdl")
  end
  
  def test_load_url
    t = Thread.new do
      ConfServer.start
    end
    sleep(2)
    assert_nil Application::Configuration.some_remote_config
    assert_equal "local", Application::Configuration.url_test
    assert_instance_of Application::Configuration, Application::Configuration.load_url("http://localhost:8000/conf")
    assert_equal "wizbang!", Application::Configuration.some_remote_config
    assert_equal "remote", Application::Configuration.url_test
  end
  
  def test_load_hash
    # puts "start of test_load_hash:"
    assert_nil app_config.some_hash_config
    # puts "load hash:"
    app_config.load_hash({"some_hash_config" => 1}, :test_load_hash_settings)
    assert_equal 1, app_config.some_hash_config
    # puts "reload"
    app_config.reload
    assert_equal 1, app_config.some_hash_config
    # puts "load_hash 2"
    app_config.load_hash({"some_hash_config" => 2}, :test_load_hash_settings_two)
    assert_equal 2, app_config.some_hash_config
    # puts "reload 2"
    app_config.reload
    assert_equal 2, app_config.some_hash_config
  end
  
  def test_revert
    assert_nil app_config.my_revert_test
    app_config.load_hash({:my_revert_test => 1}, :revert_test_1)
    assert_equal 1, app_config.my_revert_test
    app_config.revert
    assert_nil app_config.my_revert_test
    5.times do |i|
      app_config.load_hash({:my_revert_test => i}, "revert_test_#{i}")
      assert_equal i, app_config.my_revert_test
    end
    app_config.revert(2)
    assert_equal 2, app_config.my_revert_test
  end

end
