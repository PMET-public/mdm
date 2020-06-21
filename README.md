# Development and testing

Since the included Travis CI and GitHub Workflow configuration use Ubuntu Bionic (18.04) for testing, you will probably also want a local version for faster feedback and debugging.

You can use the default included Vagrantfile and remember to install the vagrant-diskzie plugin first.

```
$ vagrant plugin install vagrant-disksize
$ vagrant up
$ vagrant ssh
```

In your test vm, there's are just a few remaining setup steps.

1. add the default user to the docker group

```
$ sudo apt update && sudo apt upgrade -y
$ sudo apt install docker-compose -y
$ sudo usermod -aG docker vagrant
$ sudo shutdown -r now
```

2. clone this repo

```
$ git clone https://github.com/PMET-public/mdm.git
$ cd mdm
```

3. set up your env

```
$ export debug=1 REPO_DIR=. COMPOSER_AUTH='{"github-oauth":{"github.com":"..."}}'
```
