# Stappenplan voor de bewijsvideo

Neem het scherm op (Xbox Game Bar: `Win + G`, of OBS Studio) en volg deze volgorde.
Zo is in één take zichtbaar dat de VM's bestaan, dat Ansible ze beheert en dat de
website met de database werkt.

## 1. De drie machines tonen (± 30 s)

```bash
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" list runningvms
```

Of open VirtualBox zelf: `eliyah-ansible`, `eliyah-web01` en `eliyah-db01` staan op
"Running". Laat de namen en de verschillende distro's zien.

## 2. Inloggen op de Ansible host (± 20 s)

```bash
ssh -i keys/id_ed25519_eliyah eliyah@192.168.56.10
hostnamectl
cd ~/ansible-lab && ls
```

## 3. Verbinding testen (± 20 s)

```bash
ansible all -m ping
```

Verwacht: voor elke host `SUCCESS` / `pong` — bewijs dat de SSH-sleutel
`id_ed25519_eliyah` op alle machines werkt.

## 4. Playbook draaien (± 3-5 min)

```bash
ansible-playbook playbooks/site.yml
```

Laat de plays langskomen: `Basisinrichting van alle servers`, `Webserver inrichten`,
`Databaseserver inrichten`, `Website uploaden naar de webserver` en tot slot een
`PLAY RECAP` zonder `failed`.

## 5. Bewijs dat het resultaat blijft staan (± 30 s)

```bash
ansible all -m command -a "hostnamectl --static"
ansible webservers -m shell -a "nginx -v; php -v | head -1"
ansible dbservers -m shell -a 'mysql -e "SELECT COUNT(*) FROM eliyah_lab.bezoekers"'
```

## 6. Website openen (± 30 s)

Open in de browser op je eigen pc: <http://192.168.56.11/>

De pagina toont "Eliyah Impelmans", de gegevens van de webserver (Debian 12) en de
status van de databaseserver (Rocky Linux 9) met de bezoekersteller. Ververs de pagina
een paar keer: de teller loopt op, wat bewijst dat de webserver echt met MariaDB praat.

## 7. (Optioneel) Idempotentie aantonen

```bash
ansible-playbook playbooks/site.yml
```

Tweede run: vrijwel alles `ok` in plaats van `changed` — bewijs dat het playbook
herhaalbaar is.
