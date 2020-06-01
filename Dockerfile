FROM ubuntu

RUN apt-get update -y && \
	DEBIAN_FRONTEND=noninteractive apt-get install clevis -y

