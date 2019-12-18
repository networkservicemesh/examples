# Building the virtual L3 NSE

1. This currently only builds with a custom version of the NSM installation.

   ```bash
   $ cd $GOPATH/src/github.com/
   $ mkdir networkservicemesh
   $ cd networkservicemesh
   $ git clone https://github.com/tiswanso/networkservicemesh
   $ cd networkservicemesh
   $ git checkout vl3_api_rebase
   ```

1. To build the vL3 NSE, clone this repo and checkout this branch:

   ```bash
   $ cd $GOPATH/src/github.com/networkservicemesh
   $ git clone https://github.com/tiswanso/examples
   $ cd examples
   $ git checkout <this branch >
   ```

1. Build the vL3 NSE:

   ```bash
   $ ORG=myuser TAG=foo make docker-vl3
   ```

   - The result is an image called `myorg/vl3_ucnf-vl3-nse:foo`
