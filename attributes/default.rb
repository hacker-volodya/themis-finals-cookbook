id = 'themis-finals'

default[id][:ruby_version] = '2.3.0'

default[id][:basedir] = '/var/themis/finals'

default[id][:user] = 'vagrant'
default[id][:group] = 'vagrant'

default[id][:repository] = 'aspyatkin/themis-finals'
default[id][:revision] = 'develop'

default[id][:log_level] = 'DEBUG'
default[id][:stdout_sync] = true
default[id][:production] = false

default[id][:queue][:processes] = 2
default[id][:backend][:processes] = 2
default[id][:stream][:processes] = 2

default[id][:postgres][:version] = '9.5'
default[id][:postgres][:dbname] = 'themis-finals'
default[id][:postgres][:username] = 'themis_finals_user'
default[id][:postgres][:listen][:address] = '127.0.0.1'
default[id][:postgres][:listen][:port] = 5432

default[id][:redis][:listen][:address] = '127.0.0.1'
default[id][:redis][:listen][:port] = 6379
default[id][:redis][:db] = 1

default[id][:beanstalkd][:listen][:address] = '127.0.0.1'
default[id][:beanstalkd][:listen][:port] = 11300
