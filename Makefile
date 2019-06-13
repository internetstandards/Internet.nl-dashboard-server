nodes ?= all

bolt = /opt/puppetlabs/bin/bolt
pdk = /opt/puppetlabs/pdk/bin/pdk
ifeq ($(shell uname -s),Darwin)
puppet-lint = /usr/local/bin/puppet-lint
vagrant = /usr/local/bin/vagrant
virtualbox = /usr/local/bin/virtualbox
else
puppet-lint = /usr/bin/puppet-lint
vagrant = /usr/bin/vagrant
virtualbox = /usr/bin/virtualbox
endif


all: | ${bolt}

promote_latest_to_staging:
	docker pull internetstandards/dashboard:latest
	docker tag internetstandards/dashboard:latest internetstandards/dashboard:staging
	docker push internetstandards/dashboard:staging

promote_staging_to_live:
	docker pull internetstandards/dashboard:staging
	docker tag internetstandards/dashboard:staging internetstandards/dashboard:live
	docker push internetstandards/dashboard:live

update_staging: nodes=staging
update_staging: update

update_live: nodes=live
update_live: update

update:
	${bolt} command run "/usr/local/bin/dashboard-update" -n ${nodes}

# Spin up and provision local VM for testing
lab: nodes=lab
lab: labhost apply_lab

labhost: | ${vagrant} ${virtualbox}
	# check if testhost is up or start it
	nc 172.30.1.5 -z 22 || ${vagrant} up

# Provision online nodes
staging: nodes=acc.dashboard.internet.nl
staging: apply_staging

live: nodes=dashboard.internet.nl
live: apply_live

apply_%: plan=server
apply_%: modules/ | ${bolt}
	${bolt} plan --verbose run dashboard::${plan} --nodes $* ${args}

# Development workflow
fix: .make.fix
.make.fix: $(shell find site-modules/ -name *.pp) | ${puppet-lint}
	${puppet-lint} --fix site-modules/
	@touch $@

check: .make.check
.make.check: $(shell find site-modules/ -name *.pp)
	${puppet-lint} site-modules/

modules/: Puppetfile | ${bolt}
	${bolt} puppetfile install
	@touch $@

# Install dependencies
ifeq ($(shell uname -s),Darwin)
${bolt}:
	brew cask install puppetlabs/puppet/puppet-bolt
${puppet-lint}:
	brew tap rockyluke/devops
	brew install puppet-lint
${vagrant}:
	brew cask install vagrant
${virtualbox}:
	brew cask install virtualbox
else ifneq (,$(shell grep ubuntu /etc/os-release))
${bolt}:
	wget https://apt.puppet.com/puppet6-release-$(shell lsb_release -c -s).deb
	sudo dpkg -i puppet6-release-$(shell lsb_release -c -s).deb
	rm -f puppet6-release-$(shell lsb_release -c -s).deb
	sudo apt-get update -qq
	sudo apt-get install -yqq puppet-bolt
${puppet-lint} ${vagrant} ${virtualbox}:
	sudo apt-get install -yqq $@
else
$(error Unsupported system ${os})
endif

clean:
	rm -rf .make.*

mrproper: clean
	rm -rf modules/
	-vagrant destroy -f
