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

plan: modules/ | bolt
	${bolt} plan --verbose run --noop dashboard::server --nodes ${nodes} ${args}

apply: modules/ | bolt
	${bolt} plan --verbose run dashboard::server --nodes ${nodes} ${args}

bolt: ${bolt}
puppet-lint: ${puppet-lint}

ifeq ($(UNAME_S),Darwin)
${bolt}:
	brew cask install puppetlabs/puppet/puppet-bolt
${puppet-lint}:
	brew tap rockyluke/devops
	brew install puppet-lint
else ifneq (,$(shell grep ubuntu /etc/os-release))
${bolt}:
	wget https://apt.puppet.com/puppet6-release-$(shell lsb_release -c -s).deb
	sudo dpkg -i puppet6-release-$(shell lsb_release -c -s).deb
	rm -f puppet6-release-$(shell lsb_release -c -s).deb
	sudo apt-get update -qq
	sudo apt-get install -yqq puppet-bolt
${puppet-lint}:
	sudo apt-get install -yqq puppet-lint
else
$(error Unsupported system ${os})
endif



clean:
	rm -rf .make.*

mrproper: clean
	rm -rf modules/
