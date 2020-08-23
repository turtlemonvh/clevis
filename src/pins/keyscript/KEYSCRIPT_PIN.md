# Notes on setting up a key script pin

See [issue 191](https://github.com/latchset/clevis/issues/191) for details on the keyscript pin idea.

## Keyscript pin

Ensure `clevis-encrypt-keyscript` and `clevis-decrypt-keyscript` are on your path.

```bash
# Encrypt
$ echo "hi there" | ./src/pins/keyscript/clevis-encrypt-keyscript '{"keyscript": "/tmp/keyscript"}' > keyscript.jwe
$ cat keyscript.jwe ; echo
eyJhbGciOiJkaXIiLCJjbGV2aXMiOnsiY2ZnIjp7ImtleXNjcmlwdCI6Ii90bXAva2V5c2NyaXB0In0sInBpbiI6ImtleXNjcmlwdCJ9LCJlbmMiOiJBMjU2R0NNIn0..9ZmxtknGj5qtka_P.DBq9JLBWRkMQ.ETuFwW5MG00lQuGT46uABg
$ cat keyscript.jwe | cut -d"." -f1 | jose b64 dec -i- ; echo
{"alg":"dir","clevis":{"cfg":{"keyscript":"/tmp/keyscript"},"pin":"keyscript"},"enc":"A256GCM"}

# Decrypt
$ cat keyscript.jwe | ./src/pins/keyscript/clevis-decrypt-keyscript
hi there
```

# Notes

## Digging into pin structure via the test pins

```bash
## Encrypt

# `clevis` translates commands into `clevis-$arg1-$arg2`, etc until it finds a matching exe
# https://github.com/turtlemonvh/clevis/blob/v13/src/clevis#L21-L36
# So `clevis encrypt test` -> `clevis-encrypt-test`

# Generate key
is-mbp-timothy4:clevis timothy$ jwk="$(jose jwk gen -i '{"alg":"A256GCM"}')"
is-mbp-timothy4:clevis timothy$ echo $jwk
{"alg":"A256GCM","k":"7ftFk4_zo2sLNYLClGC28sZnzNcu09ZqYDiXQOflsLs","key_ops":["encrypt","decrypt"],"kty":"oct"}

# Generate stuff to encrypt
is-mbp-timothy4:clevis timothy$ jwe='{"protected":{"clevis":{"pin":"test","test":{}}}}'
is-mbp-timothy4:clevis timothy$ echo $jwe
{"protected":{"clevis":{"pin":"test","test":{}}}}

# Put the key inside the json
# This command looks weird but it is really just nesting "jwk" at "protected.clevis.test" inside "jwe"
is-mbp-timothy4:clevis timothy$ jwe="$(jose fmt -j "$jwe" -Og protected -g clevis -g test -j "$jwk" -Os jwk -UUUUo-)"
is-mbp-timothy4:clevis timothy$ echo $jwe
{"protected":{"clevis":{"pin":"test","test":{"jwk":{"alg":"A256GCM","k":"7ftFk4_zo2sLNYLClGC28sZnzNcu09ZqYDiXQOflsLs","key_ops":["encrypt","decrypt"],"kty":"oct"}}}}}

# Encrypt
is-mbp-timothy4:clevis timothy$ ct=$(echo "hi there" | jose jwe enc -i- -k- -I- -c < <(echo -n "$jwe$jwk"; /bin/cat))
is-mbp-timothy4:clevis timothy$ echo $ct
eyJhbGciOiJkaXIiLCJjbGV2aXMiOnsicGluIjoidGVzdCIsInRlc3QiOnsiandrIjp7ImFsZyI6IkEyNTZHQ00iLCJrIjoiN2Z0Rms0X3pvMnNMTllMQ2xHQzI4c1puek5jdTA5WnFZRGlYUU9mbHNMcyIsImtleV9vcHMiOlsiZW5jcnlwdCIsImRlY3J5cHQiXSwia3R5Ijoib2N0In19fSwiZW5jIjoiQTI1NkdDTSJ9..IEF_Hw2DkurslWM2.DAykUlAcZJ7q._bJ49s8AMoOi4b_9CLGcdQ

## Decrypt

# Note that the first output must have a header (section before first ".") that is valid json with a "clevis.pin" property
# After this clevis just calls out to `clevis-decrypt-$pin`
# https://github.com/turtlemonvh/clevis/blob/master/src/clevis-decrypt

# Read in the first part
is-mbp-timothy4:clevis timothy$ read -r -d . hdr < <(echo $ct)
is-mbp-timothy4:clevis timothy$ echo $hdr
eyJhbGciOiJkaXIiLCJjbGV2aXMiOnsicGluIjoidGVzdCIsInRlc3QiOnsiandrIjp7ImFsZyI6IkEyNTZHQ00iLCJrIjoiN2Z0Rms0X3pvMnNMTllMQ2xHQzI4c1puek5jdTA5WnFZRGlYUU9mbHNMcyIsImtleV9vcHMiOlsiZW5jcnlwdCIsImRlY3J5cHQiXSwia3R5Ijoib2N0In19fSwiZW5jIjoiQTI1NkdDTSJ9
is-mbp-timothy4:clevis timothy$ echo $hdr | base64 -D ; echo
{"alg":"dir","clevis":{"pin":"test","test":{"jwk":{"alg":"A256GCM","k":"7ftFk4_zo2sLNYLClGC28sZnzNcu09ZqYDiXQOflsLs","key_ops":["encrypt","decrypt"],"kty":"oct"}}},"enc":"A256GCM"}

# Get the name of the pin so we can make sure it is "test"
is-mbp-timothy4:clevis timothy$ jose fmt -q "$hdr" -SyOg clevis -g pin -u-
test

# Get the jwk
is-mbp-timothy4:clevis timothy$ jwk="$(jose fmt -q "$hdr" -SyOg clevis -g test -g jwk -Oo-)"
is-mbp-timothy4:clevis timothy$ echo $jwk
{"alg":"A256GCM","k":"JLVj1IY9NczfxPsopGTAdCzkXQRCO2AnTLAjk3x2xn4","key_ops":["encrypt","decrypt"],"kty":"oct"}

# Decrypt ciphertext
# 'read' has already captured up through the first '.'. Calling 'cat' will send through the rest of the input.
# We emulate this with "cut" here, grabbing everything after the first ".".
is-mbp-timothy4:clevis timothy$ echo $ct | cut -f2- -d"." | jose jwe dec -k- -i- < <(echo -n "$jwk$hdr."; /bin/cat)
hi there

# Alternative form; just put the jwk in front and pass the whole ciphertext
is-mbp-timothy4:clevis timothy$ echo $ct | jose jwe dec -k- -i- < <(echo -n "$jwk"; /bin/cat)
hi there
```

## Testing out pins in a docker container

```bash
# Show contents of files
is-mbp-timothy4:clevis timothy$ cat docker-run.sh
# After: `docker build . -t clevis`

docker run -it -v "$(pwd):/home/ubuntu/clevis" clevis bash

is-mbp-timothy4:clevis timothy$ cat Dockerfile
FROM ubuntu

RUN apt-get update -y && \
	DEBIAN_FRONTEND=noninteractive apt-get install clevis -y

# Build the docker container
is-mbp-timothy4:clevis timothy$ docker build . -t clevis
```

To use

```bash
# Get into the docker container
is-mbp-timothy4:clevis timothy$ bash docker-run.sh
```

Test out running the test pin

```bash
# Add test scripts to path
root@c831788f9946:/# ln -s /home/ubuntu/clevis/src/pins/sss/clevis-encrypt-test /usr/local/bin/
root@c831788f9946:/# ln -s /home/ubuntu/clevis/src/pins/sss/clevis-decrypt-test /usr/local/bin/
root@c831788f9946:/# clevis encrypt test '{}' < <(echo "hi there") > ct.jwe
root@c831788f9946:/# cat ct.jwe ; echo
eyJhbGciOiJkaXIiLCJjbGV2aXMiOnsicGluIjoidGVzdCIsInRlc3QiOnsiandrIjp7ImFsZyI6IkEyNTZHQ00iLCJrIjoid0V1RzM0cThaWmdOYjl3bTZ1aTdGekRHaEZIMjV3NGJPUktIZnplRGY4OCIsImtleV9vcHMiOlsiZW5jcnlwdCIsImRlY3J5cHQiXSwia3R5Ijoib2N0In19fSwiZW5jIjoiQTI1NkdDTSJ9..MemW63-4sZmNadlT.5pK8dI4iKtoT.jyET-HKiCY1u3BeDv08Egw
root@c831788f9946:/#
root@c831788f9946:/# clevis decrypt < ct.jwe
hi there
```

## Checking interaction with luks

Just notes for now.

- https://github.com/latchset/clevis/blob/v13/src/luks/clevis-luks-bind.in#L135-L136
  - just calls `clevis encrypt`
- https://github.com/latchset/clevis/blob/v13/src/luks/clevis-luks-unlock.in#L81-L105
  - just calls `clevis decrypt`
- https://github.com/latchset/clevis/blob/master/src/luks/clevis-luks-common-functions
    - uses `jose` quite a bit, but just for formatting


## Formatting arbitrary binary key as a jwk

```bash
# Generate a random key
is-mbp-timothy4:clevis timothy$ key=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | jose b64 enc -I-)
is-mbp-timothy4:clevis timothy$ echo $key
9Q-ooVkE4rF3zRgGEIx9u3eVnFoTMtNu89Rg1_jIqyw

# Set it in the JWK
is-mbp-timothy4:clevis timothy$ key=abc4567890
is-mbp-timothy4:clevis timothy$ jose jwk gen -i '{"alg":"A256GCM"}' | jose fmt -j- -O -q $key -Ss k -Uo-
{"alg":"A256GCM","k":"abc4567890","key_ops":["encrypt","decrypt"],"kty":"oct"}
```

## On AWS EC2

After configuring `/etc/luks-keyscript/service-mount-helper` and `/etc/luks-keyscript/machina-fetch-keyscript` to use credentials for a free-tier Machina tenant and changing the disk to `/dev/xvdb` (and extra ebs volume added to the instance), I was able to manually starting the service.

```bash
root@ip-172-31-53-254:/home/ubuntu# systemctl status mount-enc-secret-dirb
● mount-enc-secret-dirb.service - Mount clevis-keyscript managed directory
   Loaded: loaded (/etc/systemd/system/mount-enc-secret-dirb.service; enabled; vendor preset: enabled)
   Active: active (exited) since Sun 2020-08-23 02:04:36 UTC; 13min ago
  Process: 1668 ExecStart=/etc/luks-keyscript/service-mount-helper (code=exited, status=0/SUCCESS)
  Process: 1652 ExecStartPre=/etc/luks-keyscript/service-mount-helper -w (code=exited, status=0/SUCCESS)
 Main PID: 1668 (code=exited, status=0/SUCCESS)

Aug 23 02:04:31 ip-172-31-53-254 systemd[1]: Starting Mount clevis-keyscript managed directory...
Aug 23 02:04:31 ip-172-31-53-254 service-mount-helper[1652]: > Checking that machina service is reachable
Aug 23 02:04:31 ip-172-31-53-254 service-mount-helper[1652]: TenantID: 5e1a345203b62b28090008a0
Aug 23 02:04:31 ip-172-31-53-254 service-mount-helper[1652]: FQDN: b.6.b.c.6.0.ks.kns.ionic.com
Aug 23 02:04:31 ip-172-31-53-254 service-mount-helper[1652]: API URL: https://api.ionic.com
Aug 23 02:04:31 ip-172-31-53-254 service-mount-helper[1652]: Enrollment URL: https://enrollment.ionic.com/keyspace/Bstr/register
Aug 23 02:04:31 ip-172-31-53-254 service-mount-helper[1668]: > Unlock and mount /secretb
Aug 23 02:04:36 ip-172-31-53-254 systemd[1]: Started Mount clevis-keyscript managed directory.
```

But I see this after reboot:

```bash
root@ip-172-31-53-254:/home/ubuntu# systemctl status mount-enc-secret-dirb
● mount-enc-secret-dirb.service - Mount clevis-keyscript managed directory
   Loaded: loaded (/etc/systemd/system/mount-enc-secret-dirb.service; enabled; vendor preset: enabled)
   Active: inactive (dead)
```

After some digging (nothing showed up in `journalctl -u mount-enc-secret-dirb.service` post-boot) it turned out `NetworkManager-wait-online` doesn't exist on the AWS version of Ubuntu 18.04.

```bash
root@ip-172-31-53-254:/home/ubuntu# systemctl is-enabled NetworkManager-wait-online
Failed to get unit file state for NetworkManager-wait-online.service: No such file or directory
root@ip-172-31-53-254:/home/ubuntu# systemctl list-unit-files | grep -i network
networkd-dispatcher.service                    enabled
systemd-networkd-wait-online.service           enabled
systemd-networkd.service                       enabled
systemd-networkd.socket                        enabled
network-online.target                          static
network-pre.target                             static
network.target                                 static
```

Changing `NetworkManager-wait-online.service` to `systemd-networkd-wait-online.service` and calling `systemctl reenable mount-enc-secret-dirb` fixes the service so it comes up and the drive auto-mounts.

There are several comments out there saying that `NetworkManager-wait-online` slows down boot and is commonly disabled for that reason, which may explain why the AWS AMI doesn't have the service.
