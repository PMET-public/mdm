# Testing notes

Not all tests are appropiate for all environments, so some tests may be designated for specific testing environments or conditions. For example, some environments will not run docker commands (e.g. continuous integration (CI) cloud services are prevented from running docker on OSX as a service). Other tests may be very time consuming and disruptive to conduct locally on an actively used, developer machine.

To help quickly identify these tests, use these labels: 

- [CI] - run only on CI envs
- [dev] - run only on dev envs
- [osx|win|linux] - run only on the specified platform (i.e. OS X, Linux, or Windows)
- [docker] - require docker to run

Labels may be combined to describe multiple requirements (e.g. [CI][osx] - only CI envs running OS X)

## CI testing

CI only tests are labeled with [CI] and can assume a blank slate with each test suite run. Tests that would otherwise require extensive resetting or clean up of a developer's machine will be only be run in CI envs.

## Developer testing

Dev only tests are labeled with [dev]. They may make assumptions about the current development environment and will avoid disruptive tests.


Labels are simply designations. They are not enforced unless there is specific code in the setup or test that forces those conditions to be met independently.