{%- if grains['os_family'] in ('RedHat') or grains['os'] == 'VMware Photon OS' %}
  {%- set pkg = "iproute" %}
{%- else %}
  {%- set pkg = "iproute2" %}
{%- endif %}

iproute2:
  pkg.installed:
    - name: {{ pkg }}
