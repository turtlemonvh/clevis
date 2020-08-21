#!/usr/bin/env bash

apt-get update

# https://www.redhat.com/en/blog/easier-way-manage-disk-decryption-boot-red-hat-enterprise-linux-75-using-nbde
apt-get install -y clevis clevis-luks clevis-dracut

apt-get install -y haveged
