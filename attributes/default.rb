id = 'themis-finals'

default[id]['user'] = 'vagrant'
default[id]['group'] = 'vagrant'

default[id]['ruby']['version'] = '2.3.1'
default[id]['bundler_version'] = '1.12.5'

default[id]['postgres']['version'] = '9.5'
default[id]['postgres']['dbname'] = 'themis-finals'
default[id]['postgres']['username'] = 'themis_finals_user'
default[id]['postgres']['host'] = '127.0.0.1'
default[id]['postgres']['port'] = 5432

default[id]['redis']['host'] = '127.0.0.1'
default[id]['redis']['port'] = 6379

default[id]['supervisor']['namespace'] = 'themis.finals'
default[id]['supervisor']['host'] = '0.0.0.0'
default[id]['supervisor']['port'] = 9001

default[id]['basedir'] = '/var/themis/finals'

default[id]['backend']['github_repository'] = 'aspyatkin/themis-finals-backend'
default[id]['backend']['revision'] = 'master'
default[id]['backend']['debug'] = true
default[id]['backend']['queue']['redis_db'] = 2
default[id]['backend']['queue']['processes'] = 2
default[id]['backend']['server']['processes'] = 2
default[id]['backend']['server']['port_range_start'] = 3000

default[id]['frontend']['github_repository'] = 'aspyatkin/themis-finals-frontend'
default[id]['frontend']['revision'] = 'master'

default[id]['stream']['github_repository'] = 'aspyatkin/themis-finals-stream'
default[id]['stream']['revision'] = 'master'
default[id]['stream']['redis_db'] = 1
default[id]['stream']['redis_channel_namespace'] = 'themis.finals'
default[id]['stream']['port_range_start'] = 4000
default[id]['stream']['processes'] = 2
default[id]['stream']['debug'] = true

default[id]['visualization']['github_repository'] = 'VolgaCTF/rcc-2016-visualization'
default[id]['visualization']['revision'] = 'master'

# default[id]['sentry']['postgres']['username'] = 'sentry_user'
# default[id]['sentry']['postgres']['dbname'] = 'sentry'
# default[id]['sentry']['redis']['db'] = 2
# default[id]['sentry']['listen']['address'] = '0.0.0.0'
# default[id]['sentry']['listen']['port'] = 9000

default[id]['post_scoreboard'] = true

default[id]['key_nonce_size'] = 16
default[id]['auth_token_header'] = 'X-Themis-Finals-Auth-Token'
