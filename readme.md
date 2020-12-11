# suse terraform setups

## What is it?

Terraform configuration to setup/run suse images and provide a simple way to test things.

## Intended Audience

For now, people not worried about getting their hands dirty and for things to be incomplete. This is more a POC/MVP for the moment of a world that can be.

## Current limitations

Right now, this *only* works with terraform libvirt as a provider. Future updates may add more providers but for now kvm/libvirt is the only color car you can get out of this. As such its also restricted to linux only for now.

## Prerequisites

- Terraform 0.12+ (tested with 0.12.29) https://www.terraform.io/downloads.html
- Terraform libvirt (tested with 0.6.2)
- libvirt+kvm installed
- Gnu make (optional)
- a posix shell and time

## How can I create images to boot?

Look at the readme in the [kiwi](./kiwi/readme.md) directory.

## Booting the images

Pretty easy, just run:

```
make
```

You may optionally just run `terraform apply`/etc... directly instead of using `make`. The makefile setup is to be lazy as typing make up/down is shorter than typing the terraform commands. Yes you can alias things, I'm just used to having make do all the work.

This will get you a single vm instance of a sles 15 sp2 vm to abuse at your leisure.

## How the hell do I ssh to the vm's?

If you want the hostname/ip combinations, you can use terraform output to snag that information. Example:

```
$ terraform output hosts
{
  "largely-active-squid" = "10.86.53.128"
  "really-content-silkworm" = "10.86.53.60"
  "yearly-trusting-termite" = "10.86.53.213"
}
```

But there is a file named ssh-config-WORKSPACE that you can use instead. Note, WORKSPACE is `default` unless you've changed the terraform workspace. So for that prior example one can simply do the following:

```
$ ssh -F ssh-config-default largely-active-squid
largely-active-squid:~ #
```

Scp/rsync work the same way. Just note with rsync you'll need to use -e to pass in the config file to use ssh similarly.

Example:

```
rsync -avz -e 'ssh -F ./ssh-config-default' root@largely-active-squid:/etc/hosts /dev/null
```

## Structure of providers/modules

To give a more complete breakdown of the intent. The goal is for this terraform setup to behave as follows:

- Provider(s) should be selectable, we will only have one provider active at a time (this could be changed later, though not sure of the utility of doing so)
- The providers setup vm's such that the modules only need to worry about ssh'ing in a remote-exec can happen.
- The providers call specific modules, say k3s like a function call with: here are your host->ip mappings, as well as ssh keys, and anything else you'll need.
- The modules that implement things then go off and do their thing being blissfully ignorant of the provider they're running on.

Note: This isn't intended to be a secure production setup, storing the ssh/host keys in the terraform layout is not a good production practice. It is done here for the sake of expediency and simplicity. These environments are setup to be expendable and temporary. Productionizing anything based off this environment is left as an exercise to the reader.

## FAQ

### The hostnames suck I want to change them to something meaningful

The hostnames are from the terraform `random_pet` module. Feel free to update libvirt.tf file for yourself. But the reason for the names to be random and to not make sense, is to divorce or force the idea of these vm's as being ephemeral.

But even more important to that is a technical reason, some providers, like libvirt which is currently the only setup provider, requires libvirt domain names to be unique. If we setup a host with a unique name, terraform workspaces won't work as the names will collide in the provider. Which means we'd end up tacking on some sort of uniqueness to the host, like cep-master0-aabbccddeeff etc... at which point the hostname has already lost/divorced all meaning.

Embracing entirely silly and random names means we can avoid all of this nonsense entirely.

### I want my own ssh key in the vm's!

No. Been down that trail in the past, not doing it again. Terraform is setup to build ssh keys alongside the vm's it sets up. This is to ensure that terraform provision steps that use ssh are guaranteed to work. If I let people pick and choose their own unicorn ssh keys, I end up having to deal with ssh keys that end up in some bucket of:

- Has a passphrase, and isn't using ssh-agent, so builds fail and the automation "sucks"
- Has weird ciphers that may not be usable, also causing automation to fail
- Have to try to check all the ways a key can't work, this is a losing proposition

So to work around all of this, terraform manages the ssh keys for the vms it sets up.

End of story, changes to this will be rejected. Note this isn't an endorsement of using ssh keys to the root user as being a good security measure, these vm's are intended for testing or rapid development or other tasks where security isn't a concern. If you were to deploy vms for production there are better ways to handle most of this, but that is out of scope of this repositories intent. This is more to show a happy path to a working system you can use to understand what needs to happen.

### It doesn't do X Y or Z

I know it isn't perfect, feel free to add things and PR it, just ping me first as like the above two FAQ entries hopefully get across some missing things are very much intentional and won't be merged due to past experience.

But adding things like making N vm's have M cpus and Y amounts of ram is something I will get to in time, just wanted an initial way to build sles vm's for testing.

## Todos

- TODO Finish module setup for k3s/rke
- TODO Opensuse support? Non sles support?
- TODO Add modules for ses7/caasp and wire that up into this basic setup.
- TODO Setup an OBS multibuild to build images internally so one need not build themselves
- TODO Update kiwi builds to allow for customizing the install or adding new packages
- TODO Also make it so that I can use make to autgenerate config.xml files for sles15/sles15sp2 etc...
- Many more...

## License

As noted in the license.spdx file, this repo is released under the Blue Oak 1.0 license.