# hyperledger-fabric-jumpstart
This is step by step process to spin hyperledger-fabric in you machine and deploy your first nework.

## Download binaries into local directory and the fabric, fabric-ca, third-party images

### Option 1 :
Run following command in your terminal. Provide required version numbers in the following command for fabric, fabric-ca and third party. By default it take the latest one.
     
     curl -sSL http://bit.ly/2ysbOFE | bash -s <fabric> <fabric-ca> <thirdparty>

### Option 2 :
Download the bootstrap.sh file from (https://raw.githubusercontent.com/hyperledger/fabric/master/scripts/bootstrap.sh). I have downloaded the script and reduced the additional code from the script and kept with bare minimum required.

Execute the bootstrap script with fillowing parameters:
     
     ./bootstrap.sh [version [ca_version [thirdparty_version]]] [options]
     options:
          -h : this help
          -d : bypass docker image download
          -b : bypass download of platform-specific binaries

     e.g. ./bootstrap.sh 1.3.0 -d
     would download binaries for version 1.3.0

     e.g. ./bootstrap.sh 1.3.0
     would download docker images and binaries for version 1.3.0

It will download the following images with the version as mentioned in the input parameter. It will also make a copy of the image with the tag latest:

     hyperledger/fabric-javaenv
     hyperledger/fabric-ca
     hyperledger/fabric-tools
     hyperledger/fabric-ccenv
     hyperledger/fabric-orderer
     hyperledger/fabric-peer
     hyperledger/fabric-zookeeper
     hyperledger/fabric-kafka
     hyperledger/fabric-couchdb

It will also download the list of binaries and a script inside a bin directory. These binaries will be used by deployment script to deploy the blockchan network.

     configtxgen, configtxlator, cryptogen, discover, fabric-ca-client, get-docker-images.sh, idemixgen, orderer, peer

## Build your first blockchain network
Run blockchain_bfs.sh script to build the block chain network.

     Usage of these script is as following
     Usage:
     ./blockchain_bfs.sh <mode> [-c <channel name>] [-t <timeout>] [-d <delay>] [-f <docker-compose-file>] [-s <dbtype>] [-l <language>] [-i <imagetag>] [-v]
     
          <mode> - one of 'up', 'down', 'restart', 'generate' or 'upgrade'
               - 'up' - bring up the network with docker-compose up
               - 'down' - clear the network with docker-compose down
               - 'restart' - restart the network
               - 'generate' - generate required certificates and genesis block
               - 'upgrade'  - upgrade the network from version 1.2.x to 1.3.x
          -c <channel name> - channel name to use (defaults to \"mychannel\")
          -t <timeout> - CLI timeout duration in seconds (defaults to 10)
          -d <delay> - delay duration in seconds (defaults to 3)
          -f <docker-compose-file> - specify which docker-compose file use (defaults to docker-compose-cli.yaml)
          -s <dbtype> - the database backend to use: goleveldb (default) or couchdb
          -l <language> - the chaincode language: golang (default) or node
          -i <imagetag> - the tag to be used to launch the network (defaults to \"latest\")
          -v - verbose mode
     
     ./blockchain_bfs.sh -h (print this message)
     
     Typically, one would first generate the required certificates and genesis block, then bring up the network. e.g.:
          $(basename $0) generate -c mychannel
          $(basename $0) up -c mychannel -s couchdb
          $(basename $0) up -c mychannel -s couchdb -i 1.2.x
          $(basename $0) up -l node
          $(basename $0) down -c mychannel
          $(basename $0) upgrade -c mychannel
     
     Taking all defaults:
          $(basename $0) generate
          $(basename $0) up
          $(basename $0) down

Lets start the script in verbose mode with world state database as couchdb instead of default goleveldb

     ./blockchain_bfs.sh up -s couchdb -v


