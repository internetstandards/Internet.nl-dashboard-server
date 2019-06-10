nodes ?= all

bolt = /opt/puppetlabs/bin/bolt
pdk = /opt/puppetlabs/pdk/bin/pdk
puppet-lint = /usr/local/bin/puppet-lint

all: | bolt

test: nodes=lab
test: apply

staging: nodes=acc.dashboard.internet.nl
staging: apply

live: nodes=dashboard.internet.nl
live: apply

fix: .make.fix
.make.fix: $(shell find site-modules/ -name *.pp) | puppet-lint
	${puppet-lint} --fix site-modules/
	@touch $@

check: .make.check
.make.check: $(shell find site-modules/ -name *.pp)
	${puppet-lint} site-modules/

modules/: Puppetfile | bolt
	${bolt} puppetfile install
	@touch $@

plan: fix modules/ | bolt
	${bolt} plan --verbose run --noop dashboard::server --nodes ${nodes} ${args}

apply: fix modules/ | bolt
	${bolt} plan --verbose run dashboard::server --nodes ${nodes} ${args}

bolt: ${bolt}
${bolt}:
	brew cask install puppetlabs/puppet/puppet-bolt

puppet-lint: ${puppet-lint}

${puppet-lint}:
	brew tap rockyluke/devops
	brew install puppet-lint

clean:
	rm -rf .make.*

mrproper: clean
	rm -rf modules/