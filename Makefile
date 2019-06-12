nodes ?= all

bolt = /opt/puppetlabs/bin/bolt
pdk = /opt/puppetlabs/pdk/bin/pdk
puppet-lint = /usr/local/bin/puppet-lint
vagrant = /usr/local/bin/vagrant

all: | bolt

promote_latest_to_staging:
	docker pull internetstandards/dashboard:latest
	docker tag internetstandards/dashboard:latest internetstandards/dashboard:staging
	docker push internetstandards/dashboard:staging

promote_staging_tolive:
	docker pull internetstandards/dashboard:staging
	docker tag internetstandards/dashboard:staging internetstandards/dashboard:live
	docker push internetstandards/dashboard:live

update_staging: nodes=staging
update_staging: update

update_live: nodes=live
update_live: update

update:
	${bolt} command run "/usr/local/bin/dashboard-update" -n ${nodes}

test: nodes=lab
test: testhost apply

testhost: | ${vagrant}
	# check if testhost is up or start it
	nc 172.30.1.5 -z 22 || ${vagrant} up

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

plan=server

plan: modules/ | bolt
	${bolt} plan --verbose run --noop dashboard::${plan} --nodes ${nodes} ${args}

apply: modules/ | bolt
	${bolt} plan --verbose run dashboard::${plan} --nodes ${nodes} ${args}

bolt: ${bolt}
puppet-lint: ${puppet-lint}

ifeq ($(shell uname -s),Darwin)
${bolt}:
	brew cask install puppetlabs/puppet/puppet-bolt
${puppet-lint}:
	brew tap rockyluke/devops
	brew install puppet-lint
${vagrant}:
	brew install vagrant
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
	-vagrant destroy -f
