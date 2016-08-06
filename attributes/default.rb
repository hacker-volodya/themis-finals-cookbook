id = 'themis-finals'

default[id]['user'] = 'vagrant'
default[id]['group'] = 'vagrant'

default[id]['ruby']['version'] = '2.3.0'

default[id]['postgres']['version'] = '9.5'
default[id]['postgres']['dbname'] = 'themis-finals'
default[id]['postgres']['username'] = 'themis_finals_user'
default[id]['postgres']['listen']['address'] = '127.0.0.1'
default[id]['postgres']['listen']['port'] = 5432

default[id]['redis']['listen']['address'] = '127.0.0.1'
default[id]['redis']['listen']['port'] = 6379
default[id]['redis']['db'] = 1

default[id]['beanstalkd']['listen']['address'] = '127.0.0.1'
default[id]['beanstalkd']['listen']['port'] = 11_300
default[id]['beanstalkd']['tube_namespace'] = 'themis.finals'

default[id]['supervisor']['namespace'] = 'themis.finals'
default[id]['supervisor']['listen']['address'] = '0.0.0.0'
default[id]['supervisor']['listen']['port'] = 9001

default[id]['basedir'] = '/var/themis/finals'

default[id]['backend']['github_repository'] = 'aspyatkin/themis-finals-backend'
default[id]['backend']['revision'] = 'develop'
default[id]['backend']['debug'] = true
default[id]['backend']['queue']['processes'] = 2
default[id]['backend']['app']['processes'] = 2
default[id]['backend']['app']['port_range_start'] = 3000

default[id]['frontend']['github_repository'] = 'aspyatkin/themis-finals-frontend'
default[id]['frontend']['revision'] = 'master'

default[id]['stream']['github_repository'] = 'aspyatkin/themis-finals-stream'
default[id]['stream']['revision'] = 'develop'
default[id]['stream']['port_range_start'] = 4000
default[id]['stream']['processes'] = 2
default[id]['stream']['debug'] = true

default[id]['visualization']['github_repository'] = 'VolgaCTF/rcc-2016-visualization'
default[id]['visualization']['revision'] = 'master'

default[id]['sentry']['postgres']['username'] = 'sentry_user'
default[id]['sentry']['postgres']['dbname'] = 'sentry'
default[id]['sentry']['redis']['db'] = 2
default[id]['sentry']['listen']['address'] = '0.0.0.0'
default[id]['sentry']['listen']['port'] = 9000

default[id]['post_scoreboard'] = true
