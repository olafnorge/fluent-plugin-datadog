# Load the dogstats module.
require 'datadog/statsd'
require 'fluent/output'

module Fluent
    class DatadogOut < BufferedOutput
        # First, register the plugin. NAME is the name of this plugin
        # and identifies the plugin in the configuration file.
        Fluent::Plugin.register_output('datadog', self)

        # config_param defines a parameter. You can refer a parameter via @port instance variable
        # :default means this parameter is optional
        config_param :host, :string, default: 'localhost'
        config_param :port, :string, default: '8125'
        config_param :tags, :string, default: nil

        # This method is called before starting.
        def configure(conf)
            super
            $log.info 'Datadog Output initializing'
        end

        # This method is called when starting.
        def start
            super

            # Create a stats instance.
            @statsd = Datadog::Statsd.new(@host, @port)

            # create default tags
            @tags = if @tags.nil?
                        []
                    else
                        @tags.split(',')
                    end
        rescue Exception => e
            $log.warn "dogstatsd: #{e}"
        end

        # This method is called when shutting down.
        def shutdown
            super
            $log.info 'Datadog Output shutting down'
        end

        # This method is called when an event reaches to Fluentd.
        # Convert the event to a raw string.
        def format(tag, time, record)
            # [tag, time, record].to_json + "\n"
            ## Alternatively, use msgpack to serialize the object.
            [tag, time, record].to_msgpack
        end

        # This method is called every flush interval. Write the buffer chunk
        # to files or databases here.
        # 'chunk' is a buffer chunk that includes multiple formatted
        # events. You can use 'data = chunk.read' to get all events and
        # 'chunk.open {|io| ... }' to get IO objects.
        #
        # NOTE! This method is called by internal thread, not Fluentd's main thread. So IO wait doesn't affect other plugins.
        # def write(chunk)
        #    data = chunk.read
        #    print data
        # end

        ## Optionally, you can use chunk.msgpack_each to deserialize objects.
        def write(chunk)
            # Send several metrics at the same time
            # All metrics will be buffered and sent in one packet when the block completes
            @statsd.batch do |s|
                chunk.msgpack_each do |(_tag, _time, record)|
                    if record.key? 'log'
                        record = record['log']

                        if !(record.key? 'type') || !(record.key? 'key') || !(record.key? 'value')
                            raise KeyError, 'log entry in wrong format'
                        end

                        dd_tags = if record.key? 'tags'
                                      @tags + record['tags']
                                  else
                                      @tags
                                  end
                        type = record['type']
                        dd_key = record['key']
                        dd_value = record['value']

                        case type
                        when 'count'
                            s.count(dd_key, dd_value, tags: dd_tags)
                        when 'decrement'
                            s.decrement(dd_key, dd_value, tags: dd_tags)
                        when 'event'
                            s.event(dd_key, dd_value, tags: dd_tags)
                        when 'gauge'
                            s.gauge(dd_key, dd_value, tags: dd_tags)
                        when 'histogram'
                            s.histogram(dd_key, dd_value, tags: dd_tags)
                        when 'increment'
                            s.increment(dd_key, dd_value, tags: dd_tags)
                        when 'set'
                            s.set(dd_key, dd_value, tags: dd_tags)
                        when 'timing'
                            s.timing(dd_key, dd_value, tags: dd_tags)
                        end
                    else
                        raise KeyError, 'record in wrong format'
                    end
                end
            end
        rescue Exception => e
            $log.warn "dogstatsd: #{e}"
        end
    end
end
