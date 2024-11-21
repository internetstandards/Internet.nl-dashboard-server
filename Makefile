SHELL = /bin/bash

# Set paths for binaries used
bolt ?= /opt/puppetlabs/bin/bolt

ifeq ($(shell uname -s),Darwin)
bin = /usr/local/bin
else
bin = /usr/bin
endif

puppet-lint = ${bin}/puppet-lint
inspec = ${bin}/inspec

hetzner_ssh_key_name = default
ssh_user = root

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
	${bolt} command run "/usr/local/bin/dashboard-update" --targets $*

# Spin up and provision local VM for testing
lab: labhost apply_lab
labhost:
	hcloud server describe internetnl-dashboard-lab --output json 2>/dev/null | jq -e '.status == "running"' >/dev/null || \
	hcloud server create --name=internetnl-dashboard-lab --image=debian-12 --type cpx31 --ssh-key ${hetzner_ssh_key_name}
	timeout --foreground 30 sh -c 'while ! ssh -oStrictHostKeyChecking=no ${ssh_user}@$$(hcloud server ip internetnl-dashboard-lab) exit 0;do sleep 1; done'

# Local integrationtesting
test: lab test_inspec
test_inspec: | ${inspec}
	${inspec} exec spec/ \
		-t ssh://${ssh_user}@$$(hcloud server ip internetnl-dashboard-lab)

# Apply server configuration to nodes
apply_staging apply_live apply_all: apply_%: Boltdir/.modules/ | ${bolt}
	${bolt} apply --verbose Boltdir/modules/dashboard/manifests/site.pp --targets $* ${args}

apply_lab: apply_%: Boltdir/.modules/ | ${bolt}
	LAB_URI=$$(hcloud server ip internetnl-dashboard-lab) \
	SSH_USER=${ssh_user} \
	${bolt} apply --verbose Boltdir/modules/dashboard/manifests/site.pp --targets $* ${args}

plan_staging plan_live plan_all: plan_%: Boltdir/.modules/ | ${bolt}
	${bolt} apply --noop --verbose Boltdir/modules/dashboard/manifests/site.pp --targets $* ${args}

plan_lab: plan_%: Boltdir/.modules/ | ${bolt}
	LAB_URI=$$(hcloud server ip internetnl-dashboard-lab) \
	SSH_USER=${ssh_user} \
	${bolt} apply --noop --verbose Boltdir/modules/dashboard/manifests/site.pp --targets $* ${args}

# Development workflow
fix: .make.fix
.make.fix: $(shell find Boltdir/modules/ -name *.pp) | ${puppet-lint}
	${puppet-lint} --fix Boltdir/modules
	@touch $@

check: .make.check
.make.check: $(shell find Boltdir/modules/ -name *.pp)
	${puppet-lint} Boltdir/modules

Boltdir/.modules/: Boltdir/Puppetfile Boltdir/bolt-project.yaml| ${bolt}
	${bolt} module install
	@touch $@

# Install dependencies
ifeq ($(shell uname -s),Darwin)
${bolt}:
	brew tap puppetlabs/puppet
	brew install --cask puppet-bolt
${puppet-lint}:
	brew tap rockyluke/devops
	brew install puppet-lint
${inspec}:
	brew install --cask chef/chef/inspec
else ifneq (,$(shell grep ubuntu /etc/os-release))
${puppet-lint}
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
	rm -rf Boltdir/.modules/

destroy_lab:
	hcloud server delete internetnl-dashboard-lab
