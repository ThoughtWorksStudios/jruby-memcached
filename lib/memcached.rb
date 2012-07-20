require 'java'
require 'memcached/version'
require 'memcached/exceptions'
require 'target/spymemcached-ext-0.0.1.jar'

class Memcached
  include_class 'java.net.InetSocketAddress'
  include_class 'net.spy.memcached.MemcachedClient'
  include_class 'net.spy.memcached.ConnectionFactoryBuilder'
  include_class 'net.spy.memcached.ConnectionFactoryBuilder$Locator'
  include_class 'net.spy.memcached.DefaultHashAlgorithm'
  include_class 'com.openfeint.memcached.transcoders.SimpleTranscoder'

  FLAGS = 0x0

  attr_reader :default_ttl

  def initialize(addresses, options={})
    @servers = Array(addresses).map do |address|
      host, port = address.split(":")
      InetSocketAddress.new host, port.to_i
    end
    builder = ConnectionFactoryBuilder.new.
                                       setLocatorType(Locator::CONSISTENT).
                                       setHashAlg(DefaultHashAlgorithm::FNV1_32_HASH)
    # jruby is not smart enough to use MemcachedClient(ConnectionFactory cf, List<InetSocketAddress> addrs)
    @client = MemcachedClient.new @servers
    # MemcachedClient has no interface to set connFactory, has to do manually
    @client.instance_variable_set :@connFactory, builder

    @default_ttl = options[:default_ttl] || 604800 # 7 days
    @flags = options[:flags]

    @simple_transcoder = SimpleTranscoder.new
  end

  def set(key, value, ttl=@default_ttl, marshal=true, flags=FLAGS)
    value = marshal ? Marshal.dump(value) : value
    @simple_transcoder.setFlags(flags)
    @client.set(key, ttl, value.to_java_bytes, @simple_transcoder)
  end

  def get(key, marshal=true)
    ret = @client.get(key, @simple_transcoder)
    if ret.nil?
      raise Memcached::NotFound
    end
    flags, data = ret.flags, ret.data
    value = String.from_java_bytes data
    marshal ? Marshal.load(value) : value
  end

  def servers
    @servers.map { |server| server.to_s[1..-1] }
  end

  def close
    @client.shutdown
  end
end