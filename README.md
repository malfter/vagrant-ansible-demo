# vagrant-ansible-demo

[![pipeline status](https://gitlab.com/malfter/vagrant-ansible-demo/badges/master/pipeline.svg)](https://gitlab.com/malfter/vagrant-ansible-demo/-/commits/master)

![Logo](./logo.png)

This demo project shows how (custom) vagrant options can be used to run through only specific ansible tasks controlled by ansible tags.

## Table of Contents

- [vagrant-ansible-demo](#vagrant-ansible-demo)
  - [Table of Contents](#table-of-contents)
  - [How it works](#how-it-works)
  - [Usage of demo](#usage-of-demo)
    - [Vagrant Option `--ansible-tags`](#vagrant-option---ansible-tags)
    - [Vagrant Option `--ansible-skip-tags`](#vagrant-option---ansible-skip-tags)

## How it works

With the Ruby library `GetoptLong` it is possible to parse command line options.

We define the options in a `Vagrantfile` as follows:

```ruby
require 'yaml'
require 'getoptlong'

opts = GetoptLong.new(
  [ '--ansible-tags',      GetoptLong::OPTIONAL_ARGUMENT ], # comma separated string, e.g. "--ansible-tags='base,java'"
  [ '--ansible-skip-tags', GetoptLong::OPTIONAL_ARGUMENT ]  # comma separated string, e.g. "--ansible-skip-tags='java'"
)

$ansibleTags=''
$ansibleSkipTags=''

opts.ordering=(GetoptLong::REQUIRE_ORDER)

opts.each do |opt, arg|
  case opt
    when '--ansible-tags'
      $ansibleTags=arg
    when '--ansible-skip-tags'
      $ansibleSkipTags=arg
  end
end
```

Now we use the options and pass them to Ansible:

```ruby
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  machines.each do |opts|
    config.vm.define opts[:name] do |config|
      config.ssh.forward_agent     = true
      config.vm.box                = 'debian/contrib-buster64'
      ###
      config.vm.provision           "ansible_local" do |ansible|
        ####
        ansible.raw_arguments      = ["--vault-password-file=/vagrant_ansible/.ansible_vault_pass_file", "--connection=local"]
        unless $ansibleTags.to_s.strip.empty?
          # use vagrant tags from vagrant argument --ansible-tags
          ansible.tags             = "#{$ansibleTags}".split(/\s*,\s*/)
        else
          # use default tags from vagrant machine options
          ansible.tags             = opts[:tags] if opts[:tags]
        end
        unless $ansibleSkipTags.to_s.strip.empty?
          # use vagrant skip_tags from vagrant argument --ansible-skip-tags
          ansible.skip_tags        = "#{$ansibleSkipTags}".split(/\s*,\s*/)
        end
```

## Usage of demo

You can `cd` into the included directory `vagrant/demo-server` and run `vagrant up`, and a Debian Linux VM will be booted and configured in a few minutes. You just need to install [Vagrant](https://www.vagrantup.com/), [VirtualBox](https://www.virtualbox.org/), and [Ansible](https://www.ansible.com/).

Create new `demo-server`
```bash
$ cd vagrant/demo-server

$ vagrant up
```

### Vagrant Option `--ansible-tags`

Run only Ansible tasks with the tag `makalu`:
```bash
$ vagrant --ansible-tags=makalu provision
```

Run only Ansible tasks with the tag `k2` (This tag is only executed if it is explicitly specified, see [demo-playbook.yml](./ansible/demo_playbook.yml)):
```bash
$ vagrant --ansible-tags=k2 provision
```

### Vagrant Option `--ansible-skip-tags`

Run all Ansible tasks without the tag `lhotse`:
```bash
$ vagrant --ansible-skip-tags=lhotse provision
```
