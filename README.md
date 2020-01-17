# Init docker

<h2>Installation</h2>

```bash
cd /root/; apt install git -y --no-install-recommends; git clone https://github.com/paubarranca/init.git; bash /root/init/bootstrap.sh
```

<h2>Utilization and cases of use</h2>
<h4>Basic use</h4>

```bash
/root/init/init.sh
```

* Create and pull the containers specified in the docker-compose.yml root file

<h4>Pull images</h4>

```
/root/init/init.sh --pull
```
* Create and pull the containers specified in the docker-compose.yml root file, also refreshes the existing images

<h4>Stop containers</h4>

```bash
/root/init/init.sh --stop
```

* Stop and delete all the existing containers

<h4>Recreate containers</h4>

```bash
/root/init/init.sh --recreate
```

* Stop and delete all the existing containers, and create the ones that are defined in the docker-compose

<h4>Cleanup</h4>

```bash
/root/init/init.sh --clean
```
* Stop and delete all the containers that are not running, and delete all unused images

<h4>Update</h4>

```bash
/root/init/init.sh --update
```

* Makes a copy of the docker-compose and install the latest version of init
