#!/bin/bash

export PATH=${PWD}/bin:${PWD}:$PATH
export VERBOSE=false

function usage() {
     echo "Usage: "
     echo "  $(basename $0) <mode> [-c <channel name>] [-t <timeout>] [-d <delay>] [-f <docker-compose-file>] [-s <dbtype>] [-l <language>] [-i <imagetag>] [-v]"
     echo "    <mode> - one of 'up', 'down', 'restart', 'generate' or 'upgrade'"
     echo "      - 'up' - bring up the network with docker-compose up"
     echo "      - 'down' - clear the network with docker-compose down"
     echo "      - 'restart' - restart the network"
     echo "      - 'generate' - generate required certificates and genesis block"
     echo "      - 'upgrade'  - upgrade the network from version 1.2.x to 1.3.x"
     echo "    -c <channel name> - channel name to use (defaults to \"mychannel\")"
     echo "    -t <timeout> - CLI timeout duration in seconds (defaults to 10)"
     echo "    -d <delay> - delay duration in seconds (defaults to 3)"
     echo "    -f <docker-compose-file> - specify which docker-compose file use (defaults to docker-compose-cli.yaml)"
     echo "    -s <dbtype> - the database backend to use: goleveldb (default) or couchdb"
     echo "    -l <language> - the chaincode language: golang (default) or node"
     echo "    -i <imagetag> - the tag to be used to launch the network (defaults to \"latest\")"
     echo "    -v - verbose mode"
     echo "  $(basename $0) -h (print this message)"
     echo
     echo "Typically, one would first generate the required certificates and "
     echo "genesis block, then bring up the network. e.g.:"
     echo "	$(basename $0) generate -c mychannel"
     echo "	$(basename $0) up -c mychannel -s couchdb"
     echo "        $(basename $0) up -c mychannel -s couchdb -i 1.2.x"
     echo "	$(basename $0) up -l node"
     echo "	$(basename $0) down -c mychannel"
     echo "        $(basename $0) upgrade -c mychannel"
     echo
     echo "Taking all defaults:"
     echo "	$(basename $0) generate"
     echo "	$(basename $0) up"
     echo "	$(basename $0) down"
}

# Ask user for confirmation to proceed
function askProceed() {
     read -p "Continue? [Y/n]" ans
     case $ans in 
     y | Y)
          echo "proceeding ..."
          ;;
     n | N)
          echo "existing ..."
          exit 1
          ;;
     *)
          echo "invalid response ..."
          askProceed
          ;;
     esac
}

# Obtain CONTAINER_IDS and remove them
function clearContainers() {
    #  CONTAINER_IDS=$(docker ps -a | aws '($2 ~ /dev-peer.*.mycc.*/) {print $1}')
    CONTAINER_IDS=$(docker ps -a)
     if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " "]; then
          echo "---- No containers available for deletion ----"
     else
          docker rm -f $CONTAINER_IDS
     fi
}

# Delete any images that were generated as a part of this setup
function removeUnwantedImages() {
    #  DOCKER_IMAGE_IDS=$(docker images | aws '($1 ~ /dev-peer.*.mycc.*/) {print $3}')
    DOCKER_IMAGE_IDS=$(docker images)
     if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" == " " ]; then
          echo "---- No images available for deletion ----"
     else
          docker rmi -f $DOCKER_IMAGE_IDS
     fi
}

# Generate the needed certificates, the genesis block and start the network.
function networkUp() {
    # generate artifacts if they don't exist
    if [ ! -d "crypto-config" ]; then
      generateCertificates
      replacePrivateKey
      generateChannelArtifacts
    fi
    if [ "${IF_COUCHDB}" == "couchdb" ]; then
      IMAGE_TAG=$IMAGETAG docker-compose -f $COMPOSE_FILE -f $COMPOSE_FILE_COUCH up -d 2>&1
    else
      IMAGE_TAG=$IMAGETAG docker-compose -f $COMPOSE_FILE up -d 2>&1
    fi
    if [ $? -ne 0 ]; then
      echo "ERROR !!!! Unable to start network"
      exit 1
    fi
    # now run the end to end script
    docker exec cli scripts/script.sh $CHANNEL_NAME $CLI_DELAY $LANGUAGE $CLI_TIMEOUT $VERBOSE
    if [ $? -ne 0 ]; then
      echo "ERROR !!!! Test failed"
      exit 1
    fi
}

function upgradeNetwork() {
     echo "upgradeNetwork called"
}

# Tear down running network
function networkDown() {
    # stop org3 containers also in addition to org1 and org2, in case we were running sample to add org3
    docker-compose -f $COMPOSE_FILE -f $COMPOSE_FILE_COUCH -f $COMPOSE_FILE_ORG3 down --volumes --remove-orphans

    # Don't remove the generated artifacts -- note, the ledgers are always removed
    if [ "$MODE" != "restart" ]; then
      # Bring down the network, deleting the volumes
      #Delete any ledger backups
      docker run -v $PWD:/tmp/first-network --rm hyperledger/fabric-tools:$IMAGETAG rm -Rf /tmp/first-network/ledgers-backup
      #Cleanup the chaincode containers
      clearContainers
      #Cleanup images
      removeUnwantedImages
      # remove orderer block and other channel configuration transactions and certs
      rm -rf channel-artifacts/*.block channel-artifacts/*.tx crypto-config ./org3-artifacts/crypto-config/ channel-artifacts/org3.json
      # remove the docker-compose yaml file that was customized to the example
      rm -f docker-compose-e2e.yaml
    fi
}

function replacePrivateKey() {
     # sed on MacOSX does not support -i flag with a null extension. We will use
     # 't' for our back-up's extension and delete it at the end of the function
     ARCH=$(uname -s | grep Darwin)
     if [ "$ARCH" == "Darwin" ]; then
          OPTS="-it"
     else
          OPTS="-i"
     fi

     # Copy the template to the file that will be modified to add the private key
     cp docker-compose-e2e-template.yaml docker-compose-e2e.yaml
     # askProceed
     # The next steps will replace the template's contents with the
     # actual values of the private key file names for the two CAs.
     CURRENT_DIR=$PWD
     cd crypto-config/peerOrganizations/org1.example.com/ca/
     PRIV_KEY=$(ls *_sk)
     cd "$CURRENT_DIR"
     sed $OPTS "s/CA1_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-e2e.yaml
     cd crypto-config/peerOrganizations/org2.example.com/ca/
     PRIV_KEY=$(ls *_sk)
     cd "$CURRENT_DIR"
     sed $OPTS "s/CA2_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-e2e.yaml
     # If MacOSX, remove the temporary backup of the docker-compose file
     if [ "$ARCH" == "Darwin" ]; then
     rm docker-compose-e2e.yamlt
     fi
}

# Generates Org certs using cryptogen tool
function generateCertificates() {
     which cryptogen
     if [ "$?" -ne 0 ]; then
     echo "cryptogen tool not found. exiting"
     exit 1
     fi
     echo
     echo "##########################################################"
     echo "##### Generate certificates using cryptogen tool #########"
     echo "##########################################################"

     if [ -d "crypto-config" ]; then
          rm -Rf crypto-config
     fi
     set -x
     cryptogen generate --config=./crypto-config.yaml
     res=$?
     set +x
     if [ $res -ne 0 ]; then
     echo "Failed to generate certificates..."
     exit 1
     fi
     echo
}

# Generate orderer genesis block, channel configuration transaction and
# anchor peer update transactions
function generateChannelArtifacts() {
     which configtxgen
     if [ "$?" -ne 0 ]; then
          echo "configtxgen tool not found. exiting"
          exit 1
     fi

     echo "##########################################################"
     echo "#########  Generating Orderer Genesis block ##############"
     echo "##########################################################"
     # Note: For some unknown reason (at least for now) the block file can't be
     # named orderer.genesis.block or the orderer will fail to launch!
     set -x
     configtxgen -profile TwoOrgsOrdererGenesis -outputBlock \
     ./channel-artifacts/genesis.block
     res=$?
     set +x
     if [ $res -ne 0 ]; then
          echo "Failed to generate orderer genesis block..."
          exit 1
     fi
     echo
     echo "#################################################################"
     echo "### Generating channel configuration transaction 'channel.tx' ###"
     echo "#################################################################"
     set -x
     configtxgen -profile TwoOrgsChannel -outputCreateChannelTx \
     ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME
     res=$?
     set +x
     if [ $res -ne 0 ]; then
          echo "Failed to generate channel configuration transaction..."
          exit 1
     fi

     echo
     echo "#################################################################"
     echo "#######    Generating anchor peer update for Org1MSP   ##########"
     echo "#################################################################"
     set -x
     configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate \
     ./channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP
     res=$?
     set +x
     if [ $res -ne 0 ]; then
          echo "Failed to generate anchor peer update for Org1MSP..."
          exit 1
     fi

     echo
     echo "#################################################################"
     echo "#######    Generating anchor peer update for Org2MSP   ##########"
     echo "#################################################################"
     set -x
     configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate \
     ./channel-artifacts/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP
     res=$?
     set +x
     if [ $res -ne 0 ]; then
          echo "Failed to generate anchor peer update for Org2MSP..."
          exit 1
     fi
     echo
}

# Obtain the OS and Architecture string that will be used to select the correct
# native binaries for your platform, e.g., darwin-amd64 or linux-amd64
OS_ARCH=$(echo "$(uname -s | tr '[:upper:]' '[:lower:]' | sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
# timeout duration - the duration the CLI should wait for a response from
# another container before giving up
CLI_TIMEOUT=10
# default for delay between commands
CLI_DELAY=3
# channel name defaults to "mychannel"
CHANNEL_NAME="mychannel"
# use this as the default docker-compose yaml definition
COMPOSE_FILE=docker-compose-cli.yaml
COMPOSE_FILE_COUCH=docker-compose-couch.yaml
# org3 docker compose file
COMPOSE_FILE_ORG3=docker-compose-org3.yaml
# use golang as the default language for chaincode
LANGUAGE=golang
# default image tag
IMAGETAG="latest"
MODE=$1
shift

# Determine whether starting, stopping, restarting, generating or upgrading
if [ "$MODE" == "up" ]; then
  EXPMODE="Starting"
elif [ "$MODE" == "down" ]; then
  EXPMODE="Stopping"
elif [ "$MODE" == "restart" ]; then
  EXPMODE="Restarting"
elif [ "$MODE" == "generate" ]; then
  EXPMODE="Generating certificates and genesis block"
elif [ "$MODE" == "upgrade" ]; then
  EXPMODE="Upgrading the network"
else
  usage
  exit 1
fi

while getopts "h?c:t:d:f:s:l:i:v" opt; do
  case "$opt" in
  h | \?)
    usage
    exit 0
    ;;
  c)
    CHANNEL_NAME=$OPTARG
    ;;
  t)
    CLI_TIMEOUT=$OPTARG
    ;;
  d)
    CLI_DELAY=$OPTARG
    ;;
  f)
    COMPOSE_FILE=$OPTARG
    ;;
  s)
    IF_COUCHDB=$OPTARG
    ;;
  l)
    LANGUAGE=$OPTARG
    ;;
  i)
    IMAGETAG=$(go env GOARCH)"-"$OPTARG
    ;;
  v)
    VERBOSE=true
    ;;
  esac
done

# Announce what was requested
if [ "${IF_COUCHDB}" == "couchdb" ]; then
  echo
  echo "${EXPMODE} for channel '${CHANNEL_NAME}' with CLI timeout of '${CLI_TIMEOUT}' seconds and CLI delay of '${CLI_DELAY}' seconds and using database '${IF_COUCHDB}'"
else
  echo "${EXPMODE} for channel '${CHANNEL_NAME}' with CLI timeout of '${CLI_TIMEOUT}' seconds and CLI delay of '${CLI_DELAY}' seconds"
fi
# ask for confirmation to proceed
askProceed

#Create the network using docker compose
if [ "${MODE}" == "up" ]; then
  networkUp
elif [ "${MODE}" == "down" ]; then ## Clear the network
  networkDown
elif [ "${MODE}" == "generate" ]; then ## Generate Artifacts
  generateCertificates
  replacePrivateKey
  generateChannelArtifacts
elif [ "${MODE}" == "restart" ]; then ## Restart the network
  networkDown
  networkUp
elif [ "${MODE}" == "upgrade" ]; then ## Upgrade the network from version 1.2.x to 1.3.x
  upgradeNetwork
else
  usage
  exit 1
fi
