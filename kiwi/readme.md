# Creating qcow2 images for libvirt/kvm

For now only *libvirt*/*qcow2* images are built/configured. And everything is hardcoded.

The other presumption is you have access to the Suse IBS OBS instance. Changing this is a TODO item.

But to build sles 15 sp2 images just type:

```
make
```

Should do it, note as kiwi runs outside of obs via this setup, you can end up with timeouts at build time where the rpm metadata changed out from underneath you. If so, just rebuild until it works, such is life if using OBS as an rpm metadata source, you can catch it mid updates to rpm repo metadata.

## Rebuilding qcow2 images

If you have a vm running already, you can re-run kiwi by just running:

```
make kiwi
```