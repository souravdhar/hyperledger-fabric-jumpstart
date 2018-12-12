# hyperledger-fabric-jumpstart
This is step by step process to spin hyperledger-fabric in you machine and deploy your first nework

# Download binaries into local directory and the fabric, fabric-ca, third-party images

## Option 1
Run following command in your terminal. Provide required version numbers in the following command for fabric, fabric-ca and third party. By default it take the latest one.
     curl -sSL http://bit.ly/2ysbOFE | bash -s <fabric> <fabric-ca> <thirdparty>

## Option 2
Download the bootstrap.sh file from https://raw.githubusercontent.com/hyperledger/fabric/master/scripts/bootstrap.sh
I have reduced the additional code from the script and kept with bare minimum required

Execute the bootstrap script with fillowing parameters:
     bootstrap.sh [version [ca_version [thirdparty_version]]] [options]
     options:
          -h : this help
          -d : bypass docker image download
          -b : bypass download of platform-specific binaries

     e.g. bootstrap.sh 1.3.0 -d
     would download binaries for version 1.3.0

     e.g. bootstrap.sh 1.3.0
     would download docker images and binaries for version 1.3.0