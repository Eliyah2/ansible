# Ansible-lab — Eliyah Impelmans

Drie virtuele machines in VirtualBox, waarin één Ansible-playbook de webserver en de
databaseserver inricht en daarna de PHP-website uploadt.

| Machine | Distro | IP | Rol |
| --- | --- | --- | --- |
| `eliyah-ansible` | Ubuntu 24.04 | 192.168.56.10 | Ansible host (stuurt de playbooks aan) |
| `eliyah-web01` | Debian 12 | 192.168.56.11 | Webserver: nginx + PHP-FPM |
| `eliyah-db01` | Rocky Linux 9 | 192.168.56.12 | Databaseserver: MariaDB |

De webserver en de databaseserver zijn bewust **verschillende distro's** (Debian vs.
RHEL-family). Alle machines hebben het account **`eliyah`** en de SSH-sleutel
**`id_ed25519_eliyah`** (commentaar: `eliyah@eliyah-ansible`).

## Snelstart

```bash
# 1. Eenmalig: drie VM's aanmaken, repo kopiëren en Ansible installeren
bash scripts/bootstrap.sh

# 2. Inloggen op de Ansible host
ssh -i keys/id_ed25519_eliyah eliyah@192.168.56.10

# 3. Playbook draaien
cd ~/ansible-lab
ansible all -m ping
ansible-playbook playbooks/site.yml
```

Daarna is de site bereikbaar op <http://192.168.56.11/>.

`bootstrap.sh` doet drie dingen: `scripts/create-vms.sh` (VM's importeren en inrichten),
`scripts/sync.sh` (repo naar de Ansible host kopiëren) en
`scripts/setup-controller.sh` (Ansible + collecties installeren).

## Mappenstructuur

```
ansible-lab/
├── ansible.cfg                      # inventory, SSH-sleutel, become
├── requirements.yml                 # benodigde collecties
├── inventory/
│   ├── hosts.ini                    # groepen webservers / dbservers
│   └── group_vars/                  # all.yml, webservers.yml, dbservers.yml
├── playbooks/
│   ├── site.yml                     # één play per serverrol + website-play
│   ├── website.yml                  # aparte play: website uploaden
│   └── templates/config.php.j2      # databaseconfig voor de site
├── roles/
│   ├── common/                      # gedeelde basis (pakketten, tijdzone, MOTD)
│   ├── webserver/                   # nginx + PHP-FPM
│   └── dbserver/                    # MariaDB + firewall + database/user
├── website/                         # de PHP-site die wordt geüpload
├── scripts/                         # VM's aanmaken, repo syncen, controller instellen
└── keys/                            # publieke sleutel (privé staat in .gitignore)
```

## Waarom deze opzet

- **Geen dubbele code.** Wat beide servers nodig hebben (basispakketten, tijdzone,
  MOTD) staat in de rol `common`. De rollen `webserver` en `dbserver` bevatten alleen
  wat hun eigen rol betreft. Databasegegevens (`db_name`, `db_user`, `db_password`)
  staan één keer in `inventory/group_vars/all.yml` en worden door zowel de
  database- als de website-play gebruikt.
- **Eén play per rol.** `playbooks/site.yml` heeft een aparte play voor de
  basisinrichting, de webserver en de databaseserver. De website wordt in een
  **onafhankelijke play** (`playbooks/website.yml`) geüpload, zodat je die los kunt
  draaien: `ansible-playbook playbooks/website.yml`.
- **Rechten.** De privésleutel staat buiten de repo (`.gitignore`) en wordt in de
  Ansible host met mode `0600` in `~/.ssh` geplaatst; alleen `id_ed25519_eliyah.pub`
  staat in de repo. Bestanden die Ansible plaatst krijgen expliciet een owner en mode
  (bijv. de vhost-config `0644 root:root`, `config.php` `0640 www-data:www-data`).

## Wat het playbook doet

1. **Play 1 – basisinrichting (`servers`)** — rol `common`: basispakketten, tijdzone
   `Europe/Amsterdam`, MOTD met machinegegevens.
2. **Play 2 – webserver (`webservers`)** — rol `webserver`: nginx + PHP-FPM + php-mysql,
   documentroot `/var/www/eliyah-web`, vhost in `sites-available`/`sites-enabled`,
   standaardsite uit, services enabled.
3. **Play 3 – databaseserver (`dbservers`)** — rol `dbserver`: MariaDB + PyMySQL,
   `bind-address` in `/etc/my.cnf.d/lab.cnf`, firewalld-poort 3306 alleen open voor
   `192.168.56.11`, database `eliyah_lab`, gebruiker `eliyah_app`@`192.168.56.%`
   en het schema (`bezoekers`-tabel).
4. **Play 4 – website (`playbooks/website.yml`)** — kopieert `website/` naar de
   documentroot, genereert `config.php` met de databasegegevens en controleert met
   `uri` + `assert` dat de pagina draait én de database bereikt.

## Verifiëren

```bash
curl http://192.168.56.11/ | head -20
ssh -i keys/id_ed25519_eliyah eliyah@192.168.56.11 'hostname; php -v | head -1'
ssh -i keys/id_ed25519_eliyah eliyah@192.168.56.12 'sudo mysql -e "SELECT COUNT(*) FROM eliyah_lab.bezoekers"'
```

## Opnieuw beginnen

```bash
bash scripts/delete-vms.sh     # VM's verwijderen
bash scripts/bootstrap.sh      # opnieuw opbouwen
```

## Video-opname

Zie `DEMO.md` voor een kant-en-klaar stappenplan om de werking te filmen.
