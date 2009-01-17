require 'memcache'
require 'digest/md5'

module Sinatra
  class Cache
    def self.cache(key, &block)
      unless CONFIG['memcached']
        raise "Configure CONFIG['memcached'] to be a string like 'localhost:11211' "
      end
      begin
        key = Digest::MD5.hexdigest(key)
        @@connection ||= MemCache.new(CONFIG['memcached'], :namespace => 'Sinatra/')
        result = @@connection.get(key)
        return result if result
        result = yield
        @@connection.set(key, result)
        result
      rescue
        yield
      end
    end
  end
end

module CacheableEventContext
  
  def self.included(base)
    base.send :include, CacheableEventContext::InstanceMethods
    base.class_eval do
      alias_method :_instance_eval_without_caching, :instance_eval unless method_defined?(:_instance_eval_without_caching)
      alias_method :instance_eval, :_instance_eval_with_caching      
    end
  end
  
  module InstanceMethods
    def _instance_eval_with_caching(*args, &block)
      if block && block.instance_variable_get("@cache_key")
        key = block.instance_variable_get("@cache_key") + "/" + params.to_a.join("-")
        Sinatra::Cache.cache(key) do 
          _instance_eval_without_caching(*args, &block)
        end
      else
        _instance_eval_without_caching(*args, &block)
      end
    end
  end
end

module CacheableApplication
  def self.included(base)
    base.send :include, CacheableApplication::InstanceMethods
    base.class_eval do
      alias_method :_get_without_caching, :get unless method_defined?(:_get_without_caching)
      alias_method :get, :_get_with_caching   
    end
  end
  
  module InstanceMethods
    def _get_with_caching(path, options={}, &b)
      if options[:cache_key]
        b.instance_variable_set("@cache_key", options[:cache_key])
      end
      _get_without_caching(path, options, &b)
    end
  end
  
end

