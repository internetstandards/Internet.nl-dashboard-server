nodes ?= all

bolt = /opt/puppetlabs/bin/bolt
pdk = /opt/puppetlabs/pdk/bin/pdk
ifeq ($(shell uname -s),Darwin)
puppet-lint = /usr/local/bin/puppet-lint
vagrant = /usr/local/bin/vagrant
virtualbox = /usr/local/bin/virtualbox
inspec = /usr/local/bin/inspec
else
puppet-lint = /usr/bin/puppet-lint
vagrant = /usr/bin/vagrant
virtualbox = /usr/bin/virtualbox
inspec = /usr/bin/inspec
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

update_staging update_live: update_%:
	${bolt} command run "/usr/local/bin/dashboard-update" -n $*

# Spin up and provision local VM for testing
lab: labhost provision_lab

labhost: | ${vagrant} ${virtualbox}
	# check if testhost is up or start it
	nc 172.30.1.5 -z 22 || ${vagrant} up

# Local integrationtesting
test: lab test_inspec
test_inspec: | ${inspec}
	${inspec} exec spec/ \
		-t ssh://vagrant@172.30.1.5 \
		-i .vagrant/machines/default/virtualbox/private_key

# Provision online nodes
provision_lab provision_staging provision_live: provision_%: Boltdir/modules/ | ${bolt}
	${bolt} plan --verbose run dashboard::server --nodes $* ${args}

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
${bolt}:
	brew cask install puppetlabs/puppet/puppet-bolt
${puppet-lint}:
	brew tap rockyluke/devops
	brew install puppet-lint
${vagrant}:
	brew cask install vagrant
${virtualbox}:
	brew cask install virtualbox
${inspec}:
	brew cask install chef/chef/inspec
else ifneq (,$(shell grep ubuntu /etc/os-release))
${bolt}:
	wget https://apt.puppet.com/puppet6-release-$(shell lsb_release -c -s).deb
	sudo dpkg -i puppet6-release-$(shell lsb_release -c -s).deb
	rm -f puppet6-release-$(shell lsb_release -c -s).deb
	sudo apt-get update -qq
	sudo apt-get install -yqq puppet-bolt
${puppet-lint} ${vagrant} ${virtualbox}:
	sudo apt-get install -yqq $@
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

mrproper: clean
	rm -rf Boltdir/modules/
	-vagrant destroy -f
