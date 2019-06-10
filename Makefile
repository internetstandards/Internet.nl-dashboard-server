node ?= all

bolt = /opt/puppetlabs/bin/bolt
pdk = /opt/puppetlabs/pdk/bin/pdk

all: | bolt pdk

test: node=lab
test: modules/
	bolt plan -v run dashboard::server -n lab

modules/: Puppetfile | bolt
	bolt puppetfile install
	@touch $@

plan: modules/ | bolt
	bolt plan --verbose run --noop dashboard::server --nodes ${node}

apply: modules/ | bolt
	bolt plan run dashboard::server --nodes ${node} ${args}

bolt: ${bolt}
${bolt}:
	brew cask install puppetlabs/puppet/puppet-bolt

pdk: ${pdk}
${pdk}:
	brew cask install puppetlabs/puppet/pdk
