FROM amazonlinux:2023

RUN yum update -y \
  && yum install -y --allowerasing python3 python3-devel python3-pip openssl git rpmdevtools rpmlint \
    systemd-units git gnupg2 jq createrepo rpm-sign epel-release rustc cargo \
    curl wget \
    && yum install -y patchelf
