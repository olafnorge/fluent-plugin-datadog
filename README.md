# Fluent::Plugin::DatadogOut, a plugin for [Fluentd](http://fluentd.org) to send metrics to [datadog](https://datadoghq.com/)

## Configuration

Adding the following source block will enable the datadog out plugin for FluentD

    <match datadog.***>
        @type datadog
    </match>


## Options
| Key           | Default         | Required  |
|:------------- |:---------------:|:---------:|
| `host`        | `localhost`     |    no    |
| `port`        | `8125`          |    no     |
| `tags`        | `nil`           |    no     |

# Fluent::Plugin::PhpFpmStatusDatadogOut, a plugin for [Fluentd](http://fluentd.org) to emit php-fpm metrics gathered from log lines and prepare for further use with Fluent::Plugin::DatadogOut.

## Configuration

Adding the following source block will enable the datadog out plugin for FluentD

    <match php-fpm.***>
      @type rewrite_tag_filter
      rewriterule1 log ^\{"pool":".+",.+\}$ status.$tag
    </match>

    <match status.php-fpm.***>
      @type php_fpm_status_datadog
    </match>


## Options
| Key             | Default         | Required  |
|:--------------- |:---------------:|:---------:|
| `fluent_tag`    | `nil`           |    no    |
| `datadog_tags`  | `nil`           |    no     |
