
Need to run vagrant with experimental settings: https://www.vagrantup.com/docs/disks/usage
`export VAGRANT_EXPERIMENTAL="disks"` before `vagrant up`


Check disks: "fdisk -l"
Should see '/dev/sdb'

`cp /vagrant/src/pins/keyscript/clevis-* /usr/bin/`

Encrypt and decrypt

```
root@vagrant:/vagrant/src/pins/keyscript# echo "hello world" | clevis encrypt keyscript '{"keyscript": "/vagrant/src/pins/keyscript/example-keyscript"}' > enc.jwe
root@vagrant:/vagrant/src/pins/keyscript# clevis decrypt < enc.jwe
hello world
```

Disks

```
# Initial setup
cryptsetup --verify-passphrase luksFormat /dev/sdb
cryptsetup luksOpen /dev/sdb secret
mkfs.xfs /dev/mapper/secret
mkdir /secret
mount /dev/mapper/secret /secret
```

Machina CLI

```
# 
curl -L https://github.com/IonicDev/ionic-machina-cli/releases/download/1.8.0/machina-Linux-Default_1.8.0-8.tar.gz -o machina-Linux-Default_1.8.0-8.tar.g
cp machina/machina /usr/local/bin/
cp machina/machina.1 /usr/share/man/man1/

# Create key
machina -t plaintext -f ~/ionic_profile.pt key create -a 'com.ionic.application.luks.disk:/dev/sdb,com.ionic.application.luks.mount:/secret' -m 'ionic-application-name:luks-keyscript,ionic-application-version:0.0.1'

# Fetch key bytes
# See machina-fetch-keyscript
```

Clevis

```
# Bind disk
clevis bind luks -d /dev/sdb keyscript '{"keyscript": "/vagrant/src/pins/keyscript/example-keyscript"}'

# Check bound
cryptsetup luksDump /dev/sdb
luksmeta show -d /dev/sdb

# Close
cryptsetup close /dev/mapper/secret

# Manually unlock and mount
clevis luks unlock -d /dev/sdb -n secret
mount /dev/mapper/secret /secret
```

Auto-mount

```
# In crypttab
echo secret   /dev/sdb none _netdev >> /etc/crypttab

# In fstab
/dev/mapper/secret         /secret                 xfs         _netdev        1    2

# Try out unmount/mount
umount secret
ls -l /secret
mount -a
ls -l /secret

# Start repsonser service
systemctl enable clevis-luks-askpass.path
```

Here I ran into issues. The responser service seems to start too late.  This is the definition for the path file

```
root@vagrant:/home/vagrant# cat /lib/systemd/system/clevis-luks-askpass.path
[Unit]
Description=Clevis systemd-ask-password Watcher
Before=remote-fs-pre.target
Wants=remote-fs-pre.target

[Path]
PathChanged=/run/systemd/ask-password

[Install]
WantedBy=remote-fs.target
```

I tried changing `remote-fs-pre.target` to `local-fs-pre.target` (per https://www.freedesktop.org/software/systemd/man/systemd.special.html), but that didn't work.

This is what the view in the VM console looks like: it pauses for a password, then starts the service *after* I enter the pass phrase.

![fail to automount](fail-to-automount.png)
