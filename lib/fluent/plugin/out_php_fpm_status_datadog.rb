require 'fluent/output'

module Fluent
    class PhpFpmStatusDatadogOut < BufferedOutput
        # First, register the plugin. NAME is the name of this plugin
        # and identifies the plugin in the configuration file.
        Fluent::Plugin.register_output('php_fpm_status_datadog', self)

        # config_param defines a parameter. You can refer a parameter via @port instance variable
        # :default means this parameter is optional
        config_param :fluent_tag, :string, default: nil
        config_param :datadog_tags, :string, default: nil

        # This method is called before starting.
        # 'conf' is a Hash that includes configuration parameters.
        # If the configuration is invalid, raise Fluent::ConfigError.
        def configure(conf)
            super
            $log.info 'php_fpm_status_datadog output initializing'
        end

        # This method is called when starting.
        # Open sockets or files here.
        def start
            super
            @datadog_tags = if @datadog_tags.nil?
                                []
                            else
                                @datadog_tags.split(',')
                            end
        end

        # This method is called when shutting down.
        # Shutdown the thread and close sockets or files here.
        def shutdown
            super
            $log.info 'php_fpm_status_datadog output shutting down'
        end

        # This method is called when an event reaches to Fluentd.
        # Convert the event to a raw string.
        def format(tag, time, record)
            [tag, time, record].to_msgpack
        end

        # This method is called every flush interval. Write the buffer chunk
        # to files or databases here.
        # 'chunk' is a buffer chunk that includes multiple formatted
        # events. You can use 'data = chunk.read' to get all events and
        # 'chunk.open {|io| ... }' to get IO objects.
        #
        # NOTE! This method is called by internal thread, not Fluentd's main thread. So IO wait doesn't affect other plugins.
        def write(chunk)
            chunk.msgpack_each do |(_tag, _time, record)|
                # override the tag if set in config else prefix it with datadog
                _tag = if @fluent_tag.nil?
                           'datadog.' + _tag
                       else
                           @fluent_tag
                       end
                status = JSON.parse(record['log'], :symbolize_names => true)
                pool_name = if status.key? :pool
                                status[:pool]
                            else
                                'default'
                            end
                metric_tags = @datadog_tags + ['pool:%{pool_name}' % { pool_name: pool_name }]

                if record.key? 'container_id'
                  metric_tags += ['container_id:%{container_id}' % {container_id: record['container_id']}]
                end

                if record.key? 'container_name'
                  metric_tags += ['container_name:%{container_name}' % {container_name: record['container_name']}]
                end

                gauges = {
                    'listen queue': 'php_fpm.listen_queue.size',
                    'idle processes': 'php_fpm.processes.idle',
                    'active processes': 'php_fpm.processes.active',
                    'total processes': 'php_fpm.processes.total',
                }

                gauges.each do |(fpm_key, datadog_key)|
                  fpm_key = fpm_key.to_sym

                  if status.key? fpm_key
                    router.emit(_tag, _time, 'log' => {'key' => datadog_key, 'value' => status[fpm_key], 'tags' => metric_tags, 'type' => 'gauge'})
                  end
                end

                monotonic_counts = {
                    'accepted conn': 'php_fpm.requests.accepted',
                    'max children reached': 'php_fpm.processes.max_reached',
                    'slow requests': 'php_fpm.requests.slow',
                }

                monotonic_counts.each do |(fpm_key, datadog_key)|
                  fpm_key = fpm_key.to_sym

                  if status.key? fpm_key
                    router.emit(_tag, _time, 'log' => {'key' => datadog_key, 'value' => status[fpm_key], 'tags' => metric_tags, 'type' => 'count'})
                  end
                end

                if status.key? :processes
                  index = 0
                  status[:processes].each {|metrics|
                    process_gauges = {
                        :'request duration' => 'php_fpm.processes.%{process_index}.request_duration',
                        :'content length' => 'php_fpm.processes.%{process_index}.content_length',
                        :'last request cpu' => 'php_fpm.processes.%{process_index}.request_cpu',
                        :'last request memory' => 'php_fpm.processes.%{process_index}.request_memory',
                    }

                    process_monotonic_counts = {
                        :'requests' => 'php_fpm.processes.%{process_index}.requests',
                    }

                    metrics.each do |(metric_key, metric_value)|
                      if process_gauges.key? metric_key
                        datadog_key = process_gauges[metric_key] % { process_index: index }
                        router.emit(_tag, _time, 'log' => {'key' => datadog_key, 'value' => metric_value, 'tags' => metric_tags, 'type' => 'gauge'})
                      elsif process_monotonic_counts.key? metric_key
                        datadog_key = process_monotonic_counts[metric_key] % { process_index: index }
                        router.emit(_tag, _time, 'log' => {'key' => datadog_key, 'value' => metric_value, 'tags' => metric_tags, 'type' => 'count'})
                      end
                    end

                    index += 1
                  }
                end
            end
        end
    end
end
