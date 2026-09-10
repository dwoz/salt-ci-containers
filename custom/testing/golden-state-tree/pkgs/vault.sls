{#- Whether HashiCorp's package repo covers a given distro/release changes over
   time in both directions (they drop EOL releases, they add new ones), so
   instead of hardcoding a list of excluded releases here, probe the repo at
   build time and skip vault gracefully - without leaving a broken repo file
   behind - when it isn't covered. #}

{%- if grains['os_family'] == 'Debian' %}
vault-prereqs:
  pkg.installed:
    - pkgs:
      - apt-transport-https
      - ca-certificates
      - curl
      - gnupg
      - lsb-release

vault-repo:
  cmd.run:
    - name: |
        set -e
        CODENAME=$(lsb_release -cs)
        if curl -fsS -o /dev/null "https://apt.releases.hashicorp.com/dists/${CODENAME}/Release"; then
          curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
          echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${CODENAME} main" | tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
        else
          echo "HashiCorp apt repo does not (yet) cover '${CODENAME}'; skipping vault install" >&2
          rm -f /etc/apt/sources.list.d/hashicorp.list /usr/share/keyrings/hashicorp-archive-keyring.gpg
        fi
    - require:
      - vault-prereqs

install-vault:
  pkg.installed:
    - name: vault
    - refresh: True
    - onlyif: test -f /etc/apt/sources.list.d/hashicorp.list
    - require:
      - vault-repo

{%- elif grains['os_family'] == 'RedHat' %}

{%- if grains['os'] == 'Fedora' %}
{%- set hashicorp_repo_url = 'https://rpm.releases.hashicorp.com/fedora/hashicorp.repo' %}
{%- elif grains['os'] == 'Amazon' %}
{%- set hashicorp_repo_url = 'https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo' %}
{%- else %}
{%- set hashicorp_repo_url = 'https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo' %}
{%- endif %}

vault-repo:
  cmd.run:
    - name: |
        set -e
        if curl -fsS -o /dev/null "{{ hashicorp_repo_url }}"; then
          {%- if grains['os'] == 'Fedora' %}
          dnf -y install dnf-plugins-core
          dnf config-manager --add-repo {{ hashicorp_repo_url }}
          {%- else %}
          yum install -y yum-utils
          yum-config-manager --add-repo {{ hashicorp_repo_url }}
          {%- endif %}
        else
          echo "HashiCorp repo unavailable at {{ hashicorp_repo_url }}; skipping vault install" >&2
          rm -f /etc/yum.repos.d/hashicorp.repo
        fi

install-vault:
  cmd.run:
    - name: |
        set -e
        if [ ! -f /etc/yum.repos.d/hashicorp.repo ]; then
          exit 0
        fi
        {%- if grains['os'] == 'Fedora' %}
        PKG_MGR=dnf
        {%- else %}
        PKG_MGR=yum
        {%- endif %}
        # HashiCorp rotated their RPM package-signing key on 2026-09-09
        # without warning (see
        # https://github.com/hashicorp/vault/issues/32109). Some
        # architectures are still serving vault builds signed with the
        # outgoing key while /gpg already advertises the new one, so a
        # freshly-imported key can still fail the package's GPG check.
        # Retry a few times in case HashiCorp's rollout catches up
        # mid-build, but don't fail the whole image build over an
        # upstream signing incident we don't control - skip vault
        # instead, same as when the repo doesn't cover a release at all.
        for i in 1 2 3 4 5; do
          $PKG_MGR install -y vault && exit 0
          echo "vault install attempt $i failed, retrying..." >&2
          $PKG_MGR clean all
          sleep 10
        done
        echo "vault install kept failing (likely a HashiCorp key-rotation incident); skipping vault" >&2
        exit 0
    - require:
      - vault-repo

{%- else %}
install-vault:
  pkg.installed:
    - name: vault
{%- endif %}
