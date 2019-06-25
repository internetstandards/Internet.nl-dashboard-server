SHELL = /bin/bash

# Set paths for binaries used
bolt = /opt/puppetlabs/bin/bolt

ifeq ($(shell uname -s),Darwin)
bin = /usr/local/bin
else
bin = /usr/bin
endif

puppet-lint = ${bin}/puppet-lint
vagrant = ${bin}/vagrant
virtualbox = ${bin}/virtualbox
inspec = ${bin}/inspec

# Default action is to install dependencies
all: | ${bolt}

# Targets to perform update of the Dashboard application
promote_latest_to_staging:
	docker pull internetstandards/dashboard:latest
	docker tag internetstandards/dashboard:latest internetstandards/dashboard:staging
	docker push internetstandards/dashboard:staging

promote_staging_to_live:
	docker pull internetstandards/dashboard:latest
	docker tag internetstandards/dashboard:latest internetstandards/dashboard:live
	docker push internetstandards/dashboard:live

update_staging update_live: update_%:
	${bolt} command run "/usr/local/bin/dashboard-update" -n $*

# Spin up and provision local VM for testing
lab: labhost apply_lab
labhost: | ${vagrant} ${virtualbox}
	# check if testhost is up or start it
	nc 172.30.1.5 -z 22 -w 3 -n || ${vagrant} up

# Local integrationtesting
test: lab test_inspec
test_inspec: | ${inspec}
	${inspec} exec spec/ \
		-t ssh://vagrant@172.30.1.5 \
		-i .vagrant/machines/default/virtualbox/private_key

# Apply server configuration to nodes
apply_lab apply_staging apply_live apply_all: apply_%: Boltdir/modules/ | ${bolt}
	${bolt} plan --verbose run dashboard::server --nodes $* ${args}

plan_lab plan_staging plan_live plan_all: plan_%: Boltdir/modules/ | ${bolt}
	${bolt} plan --verbose run dashboard::server --nodes $* --params='{"noop": true}' ${args}

# Development workflow
fix: .make.fix
.make.fix: $(shell find Boltdir/site-modules/ -name *.pp) | ${puppet-lint}
	${puppet-lint} --fix Boltdir/site-modules
	@touch $@

check: .make.check
.make.check: $(shell find Boltdir/site-modules/ -name *.pp)
	${puppet-lint} Boltdir/site-modules

Boltdir/modules/: Boltdir/Puppetfile | ${bolt}
	${bolt} puppetfile install
	@touch $@

# Install dependencies
ifeq ($(shell uname -s),Darwin)
${vagrant} ${virtualbox}:
	brew cask install ${@F}
${bolt}:
	brew cask install puppetlabs/puppet/puppet-bolt
${puppet-lint}:
	brew tap rockyluke/devops
	brew install puppet-lint
${inspec}:
	brew cask install chef/chef/inspec
else ifneq (,$(shell grep ubuntu /etc/os-release))
${puppet-lint} ${vagrant} ${virtualbox}:
	sudo apt-get install -yqq ${@F}
${bolt}:
	wget https://apt.puppet.com/puppet6-release-$(shell lsb_release -c -s).deb
	sudo dpkg -i puppet6-release-$(shell lsb_release -c -s).deb
	rm -f puppet6-release-$(shell lsb_release -c -s).deb
	sudo apt-get update -qq
	sudo apt-get install -yqq puppet-bolt
${inspec}:
	wget https://packages.chef.io/files/stable/inspec/4.3.2/ubuntu/18.04/inspec_4.3.2-1_amd64.deb
	sudo dpkg -i inspec_4.3.2-1_amd64.deb
	rm -f inspec_4.3.2-1_amd64.deb
	${inspec} version --chef-license=accept-silent >/dev/null
else
$(error Unsupported system ${os})
endif

clean:
	rm -rf .make.*

mrproper: destroy_vm clean
	rm -rf Boltdir/modules/

destroy_lab:
	-vagrant destroy -f
