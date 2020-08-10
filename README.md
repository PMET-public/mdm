# Development and testing

Since the included Travis CI and GitHub Workflow configuration use Ubuntu Bionic (18.04) for testing, you will probably also want a local version for faster feedback and debugging.

You can use the default included Vagrantfile. Remember to install the vagrant-diskzie plugin first.

```
$ vagrant plugin install vagrant-disksize
$ vagrant up
$ vagrant ssh
```

In your test vm, there's are just a few remaining setup steps.

1. add the default user to the docker group

```
$ sudo apt update && sudo apt upgrade -y
$ sudo apt install docker-compose php -y
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
$ export debug=1 MDM_REPO_DIR=. COMPOSER_AUTH='{"github-oauth":{"github.com":"..."}}'
```

## Additional troubleshooting notes

To debug the launching script, `export debug_launcher=1`, too. This is currently a separate var because the launching script debugging output would otherwise pollute the menu output before the logging initialization can run. Also, it represents the output of the app's `<osx_appp>/Contents/Resources/script`, not the output of ~/.mdm/current/launcher because it is bundled with the app.  The launcher should not need to be debugged often because it's relatively minimal, stable code to bootstrap the app.


## Using sudo 

Some funcitonality will require sudo functionality (e.g. modifying the hosts file). Remember to start an interactive terminal when that functionality is required.

## Using mkcert

Install but do not enable the mkcert until explicit permission is received from the user.