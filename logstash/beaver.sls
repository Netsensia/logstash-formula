include:
  - python
  - apparmor


beaver:
  pip.installed:
    - require:
      - pkg: python-pip
  service.running:
    - require:
      - pip: beaver
    - watch:
      - file: /etc/init/beaver.conf
      - file: /etc/beaver.conf


/etc/supervisor.d/beaver.conf:
  file.absent

/etc/beaver.conf:
  file:
    - managed
    - source: salt://logstash/templates/beaver/beaver.conf
    - template: jinja

/etc/beaver.d:
  file:
    - directory

/etc/init/beaver.conf:
  file.managed:
    - source: salt://logstash/templates/beaver/upstart-beaver.conf
    - template: jinja

/etc/apparmor.d/beaver_local:
  file.directory:
    - mode: 755
    - user: root
    - group: root

/etc/apparmor.d/usr.local.bin.beaver:
  file.managed:
    - source: salt://logstash/templates/beaver_apparmor_profile
    - template: jinja
    - watch_in:
      - service: beaver