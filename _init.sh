#!/bin/bash

#********************************************************************************
# Copyright 2014 IBM
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#********************************************************************************

#############
# Colors    #
#############
export green='\e[0;32m'
export red='\e[0;31m'
export label_color='\e[0;33m'
export no_color='\e[0m' # No Color

##################################################
# Simple function to only run command if DEBUG=1 # 
### ###############################################
debugme() {
  [[ $DEBUG = 1 ]] && "$@" || :
}
export -f debugme 
installwithpython27() {
    echo "Installing Python 2.7"
    sudo apt-get update &> /dev/null
    sudo apt-get -y install python2.7 &> /dev/null
    python --version 
    wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py &> /dev/null
    python get-pip.py --user &> /dev/null
    export PATH=$PATH:~/.local/bin
    if [ -f icecli-2.0.zip ]; then 
        debugme echo "there was an existing icecli.zip"
        debugme ls -la 
        rm -f icecli-2.0.zip
    fi 
    wget https://static-ice.ng.bluemix.net/icecli-2.0.zip &> /dev/null
    pip install --user icecli-2.0.zip > cli_install.log 2>&1 
    debugme cat cli_install.log 
}
installwithpython34() {
    curl -kL http://xrl.us/pythonbrewinstall | bash
    source $HOME/.pythonbrew/etc/bashrc
    sudo apt-get install zlib1g-dev libexpat1-dev libdb4.8-dev libncurses5-dev libreadline6-dev
    sudo apt-get update &> /dev/null
    debugme pythonbrew list -k
    echo "Installing Python 3.4.1"
    pythonbrew install 3.4.1 &> /dev/null
    debugme cat /home/jenkins/.pythonbrew/log/build.log 
    pythonbrew switch 3.4.1
    python --version 
    echo "Installing pip"
    wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py &> /dev/null
    python get-pip.py --user
    export PATH=$PATH:~/.local/bin
    which pip 
    echo "Installing ice cli"
    wget https://static-ice.ng.bluemix.net/icecli-2.0.zip &> /dev/null
    wget https://static-ice.ng.bluemix.net/icecli-2.0.zip
    pip install --user icecli-2.0.zip > cli_install.log 2>&1 
    debugme cat cli_install.log 
}

installwithpython277() {
    pushd . 
    cd $EXT_DIR
    echo "Installing Python 2.7.7"
    curl -kL http://xrl.us/pythonbrewinstall | bash
    source $HOME/.pythonbrew/etc/bashrc

    sudo apt-get update &> /dev/null
    sudo apt-get build-dep python2.7
    sudo apt-get install zlib1g-dev
    debugme pythonbrew list -k
    echo "Installing Python 2.7.7"
    pythonbrew install 2.7.7 --no-setuptools &> /dev/null
    debugme cat /home/jenkins/.pythonbrew/log/build.log 
    pythonbrew switch 2.7.7
    python --version 
    echo "Installing pip"
    wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py &> /dev/null
    python get-pip.py --user &> /dev/null
    debugme pwd 
    debugme ls 
    popd 
    pip remove requests
    pip install --user -U requests 
    pip install --user -U pip
    export PATH=$PATH:~/.local/bin
    which pip 
    echo "Installing ice cli"
    wget https://static-ice.ng.bluemix.net/icecli-2.0.zip &> /dev/null
    pip install --user icecli-2.0.zip > cli_install.log 2>&1 
    debugme cat cli_install.log 
}
installwithpython3() {

    sudo apt-get update &> /dev/null
    sudo apt-get upgrade &> /dev/null 
    sudo apt-get -y install python3 &> /dev/null
    python3 --version 
    echo "installing pip"
    wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py 
    python3 get-pip.py --user &> /dev/null
    export PATH=$PATH:~/.local/bin
    which pip 
    echo "installing ice cli"

    wget https://static-ice.ng.bluemix.net/icecli-2.0.zip
    pip install --user icecli-2.0.zip > cli_install.log 2>&1 
    debugme cat cli_install.log 
}

if [[ $DEBUG = 1 ]]; then 
    export ICE_ARGS="--verbose"
else
    export ICE_ARGS=""
fi 

set +e
set +x 

###############################
# Configure extension PATH    #
###############################
if [ -n $EXT_DIR ]; then 
    export PATH=$EXT_DIR:$PATH
fi 

#########################################
# Configure log file to store errors  #
#########################################
if [ -z "$ERROR_LOG_FILE" ]; then
    ERROR_LOG_FILE="${EXT_DIR}/errors.log"
    export ERROR_LOG_FILE
fi

########################################################################
# Fix timestamps so that caching will be leveraged on the remove host  #
########################################################################
if [ -z "${USE_CACHED_LAYERS}" ]; then 
    export USE_CACHED_LAYERS="true"
fi 
if [ "${USE_CACHED_LAYERS}" == "true" ]; then 
    if [ "${MAX_CACHING_TIME}x" == "x" ]; then
        MAX_CACHING_TIME=300
    fi
    if [ "${MAX_CACHING_TIME_LEFT}x" == "x" ]; then
        MAX_CACHING_TIME_LEFT=120
    fi
    echo "Adjusting timestamps for files to allow cached layers"
    tsadj_start_time=$(date +"%s")

    update_file_timestamp() {
        local file_time=$(git log --pretty=format:%cd -n 1 --date=iso $1)
        touch -d "$file_time" "$1"
    }

    old_ifs=$IFS
    IFS=$'\n' 
    FILE_COUNTER=0
    all_file_count=`git ls-files | wc | awk '{print $1}'`
    eta_total=0
    eta_remaining=0
    for file in $(git ls-files)
    do
        update_file_timestamp "${file}"
        FILE_COUNTER=$((FILE_COUNTER+1));
        if ! ((FILE_COUNTER % 50)); then
            # check if we're timeboxed
            if [ $MAX_CACHING_TIME -gt 0 ]; then
                # calculate roughly how much time left
                tsadj_end_time=$(date +"%s")
                tsadj_diff=$(($tsadj_end_time-$tsadj_start_time))
                (( eta_total = all_file_count * tsadj_diff / FILE_COUNTER ));
                (( eta_remaining = eta_total - tsadj_diff ));
                if [ $eta_total -gt $MAX_CACHING_TIME ] && [ $eta_remaining -gt $MAX_CACHING_TIME_LEFT ]; then
                    debugme echo "$FILE_COUNTER files processed in `date -u -d @"$tsadj_diff" +'%-Mm %-Ss'`"
                    debugme echo "eta total ( `date -u -d @"$eta_total" +'%-Mm %-Ss'` ) and remaining ( `date -u -d @"$eta_remaining" +'%-Mm %-Ss'` )"
                    debugme echo "Would take too much time to adjust timestamps, skipping"
                    eta_total=-1
                    break;
                fi 
            fi
            echo -n "."
        fi
        if ! ((FILE_COUNTER % 1000)); then
            tsadj_end_time=$(date +"%s")
            tsadj_diff=$(($tsadj_end_time-$tsadj_start_time))
            echo "$FILE_COUNTER files processed in `date -u -d @"$tsadj_diff" +'%-Mm %-Ss'`"
        fi
    done
    IFS=$old_ifs
    if [ $eta_total -ge 0 ]; then
        if ((FILE_COUNTER % 1000)); then
            tsadj_end_time=$(date +"%s")
            tsadj_diff=$(($tsadj_end_time-$tsadj_start_time))
            echo "$FILE_COUNTER files processed in `date -u -d @"$tsadj_diff" +'%-Mm %-Ss'`"
        fi
    fi
    echo "Timestamps adjusted"
fi 

################################
# Application Name and Version #
################################
# The build number for the builder is used for the version in the image tag 
# For deployers this information is stored in the $BUILD_SELECTOR variable and can be pulled out
if [ -z "$APPLICATION_VERSION" ]; then
    export SELECTED_BUILD=$(grep -Eo '[0-9]{1,100}' <<< "${BUILD_SELECTOR}")
    if [ -z $SELECTED_BUILD ]
    then 
        if [ -z $BUILD_NUMBER ]
        then 
            export APPLICATION_VERSION=$(date +%s)
        else 
            export APPLICATION_VERSION=$BUILD_NUMBER    
        fi
    else
        export APPLICATION_VERSION=$SELECTED_BUILD
    fi 
fi 
debugme echo "installing bc"
sudo apt-get install bc >/dev/null 2>&1
debugme echo "done installing bc"
if [ -n "$BUILD_OFFSET" ]; then 
    echo "Using BUILD_OFFSET of $BUILD_OFFSET"
    export APPLICATION_VERSION=$(echo "$APPLICATION_VERSION + $BUILD_OFFSET" | bc)
    export BUILD_NUMBER=$(echo "$BUILD_NUMBER + $BUILD_OFFSET" | bc)
fi 

echo "APPLICATION_VERSION: $APPLICATION_VERSION"

if [ -z $IMAGE_NAME ]; then 
    echo -e "${red}Please set IMAGE_NAME in the environment to desired name ${no_color}" | tee -a "$ERROR_LOG_FILE"
    ${EXT_DIR}/print_help.sh
    exit 1
fi 

if [ -f ${EXT_DIR}/builder_utilities.sh ]; then
    source ${EXT_DIR}/builder_utilities.sh 
    debugme echo "Validating image name"
    pipeline_validate_full ${IMAGE_NAME} >validate.log 2>&1 
    VALID_NAME=$?
    if [ ${VALID_NAME} -ne 0 ]; then     
        echo -e "${red}${IMAGE_NAME} is not a valid image name for Docker${no_color}" | tee -a "$ERROR_LOG_FILE"
        cat validate.log 
        ${EXT_DIR}/print_help.sh
        exit ${VALID_NAME}
    else 
        debugme cat validate.log 
    fi 
else 
    echo -e "${red}Warning could not find utilities in ${EXT_DIR}${no_color}" | tee -a "$ERROR_LOG_FILE"
fi 

################################
# Setup archive information    #
################################
if [ -z $WORKSPACE ]; then 
    echo -e "${red}Please set WORKSPACE in the environment${no_color}" | tee -a "$ERROR_LOG_FILE"
    ${EXT_DIR}/print_help.sh
    exit 1
fi 

if [ -z $ARCHIVE_DIR ]; then
    echo -e "${label_color}ARCHIVE_DIR was not set, setting to WORKSPACE ${no_color}"
    export ARCHIVE_DIR="${WORKSPACE}"
fi

if [ "$ARCHIVE_DIR" == "./" ]; then
    echo -e "${label_color}ARCHIVE_DIR set relative, adjusting to current dir absolute ${no_color}"
    export ARCHIVE_DIR=`pwd`
fi

if [ -d $ARCHIVE_DIR ]; then
  echo -e "Archiving to $ARCHIVE_DIR"
else 
  echo -e "Creating archive directory $ARCHIVE_DIR"
  mkdir $ARCHIVE_DIR 
fi 
export LOG_DIR=$ARCHIVE_DIR

######################
# Install ICE CLI    #
######################
echo "Installing IBM Container Service CLI"
ice help &> /dev/null
RESULT=$?
if [ $RESULT -ne 0 ]; then
#    installwithpython3
    installwithpython27
#    installwithpython277
#    installwithpython34
    ice help &> /dev/null
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo -e "${red}Failed to install IBM Container Service CLI ${no_color}" | tee -a "$ERROR_LOG_FILE"
        debugme python --version
        ${EXT_DIR}/print_help.sh
        exit $RESULT
    fi
    echo -e "${label_color}Successfully installed IBM Container Service CLI ${no_color}"
fi 

#############################
# Install Cloud Foundry CLI #
#############################
cf help &> /dev/null
RESULT=$?
if [ $RESULT -ne 0 ]; then
    echo "Installing Cloud Foundry CLI"
    pushd . 
    cd $EXT_DIR 
    gunzip cf-linux-amd64.tgz &> /dev/null
    tar -xvf cf-linux-amd64.tar  &> /dev/null
    cf help &> /dev/null
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo -e "${red}Could not install the cloud foundry CLI ${no_color}" | tee -a "$ERROR_LOG_FILE"
        ${EXT_DIR}/print_help.sh    
        exit 1
    fi  
    popd
    echo -e "${label_color}Successfully installed Cloud Foundry CLI ${no_color}"
fi 

#################################
# Set Bluemix Host Information  #
#################################
if [ -n "$BLUEMIX_TARGET" ]; then
    if [ "$BLUEMIX_TARGET" == "staging" ]; then 
        export CCS_API_HOST="api-ice.stage1.ng.bluemix.net" 
        export CCS_REGISTRY_HOST="registry-ice.stage1.ng.bluemix.net"
        export BLUEMIX_API_HOST="api.stage1.ng.bluemix.net"
        export ICE_CFG="ice-cfg-staging.ini"
    elif [ "$BLUEMIX_TARGET" == "prod" ]; then 
        echo -e "Targetting production Bluemix"
        export CCS_API_HOST="api-ice.ng.bluemix.net" 
        export CCS_REGISTRY_HOST="registry-ice.ng.bluemix.net"
        export BLUEMIX_API_HOST="api.ng.bluemix.net"
        export ICE_CFG="ice-cfg-prod.ini"
    else 
        echo -e "${red}Unknown Bluemix environment specified${no_color}" | tee -a "$ERROR_LOG_FILE"
    fi 
else 
    echo -e "Targetting production Bluemix"
    export CCS_API_HOST="api-ice.ng.bluemix.net" 
    export CCS_REGISTRY_HOST="registry-ice.ng.bluemix.net"
    export BLUEMIX_API_HOST="api.ng.bluemix.net"
    export ICE_CFG="ice-cfg-prod.ini"

fi  

################################
# Login to Container Service   #
################################
if [ -n "$API_KEY" ]; then 
    echo -e "${label_color}Logging on with API_KEY${no_color}"
    debugme echo "Login command: ice $ICE_ARGS login --key ${API_KEY}"
    #ice $ICE_ARGS login --key ${API_KEY} --host ${CCS_API_HOST} --registry ${CCS_REGISTRY_HOST} --api ${BLUEMIX_API_HOST} 
    ice $ICE_ARGS login --key ${API_KEY} 2> /dev/null
    RESULT=$?
elif [ -n "$BLUEMIX_USER" ] || [ ! -f ~/.cf/config.json ]; then
    # need to gather information from the environment 
    # Get the Bluemix user and password information 
    if [ -z "$BLUEMIX_USER" ]; then 
        echo -e "${red} Please set BLUEMIX_USER on environment ${no_color}" | tee -a "$ERROR_LOG_FILE"
        ${EXT_DIR}/print_help.sh
        exit 1
    fi 
    if [ -z "$BLUEMIX_PASSWORD" ]; then 
        echo -e "${red} Please set BLUEMIX_PASSWORD as an environment property environment ${no_color}" | tee -a "$ERROR_LOG_FILE"
        ${EXT_DIR}/print_help.sh    
        exit 1 
    fi 
    if [ -z "$BLUEMIX_ORG" ]; then 
        export BLUEMIX_ORG=$BLUEMIX_USER
        echo -e "${label_color} Using ${BLUEMIX_ORG} for Bluemix organization, please set BLUEMIX_ORG if on the environment if you wish to change this. ${no_color} "
    fi 
    if [ -z "$BLUEMIX_SPACE" ]; then
        export BLUEMIX_SPACE="dev"
        echo -e "${label_color} Using ${BLUEMIX_SPACE} for Bluemix space, please set BLUEMIX_SPACE if on the environment if you wish to change this. ${no_color} "
    fi 
    echo -e "${label_color}Targetting information.  Can be updated by setting environment variables${no_color}"
    echo "BLUEMIX_USER: ${BLUEMIX_USER}"
    echo "BLUEMIX_SPACE: ${BLUEMIX_SPACE}"
    echo "BLUEMIX_ORG: ${BLUEMIX_ORG}"
    echo "BLUEMIX_PASSWORD: xxxxx"
    echo ""
    echo -e "${label_color}Logging in to Bluemix and IBM Container Service using environment properties${no_color}"
    debugme echo "login command: ice $ICE_ARGS login --cf --host ${CCS_API_HOST} --registry ${CCS_REGISTRY_HOST} --api ${BLUEMIX_API_HOST} --user ${BLUEMIX_USER} --psswd ${BLUEMIX_PASSWORD} --org ${BLUEMIX_ORG} --space ${BLUEMIX_SPACE}"
    ice $ICE_ARGS login --cf --host ${CCS_API_HOST} --registry ${CCS_REGISTRY_HOST} --api ${BLUEMIX_API_HOST} --user ${BLUEMIX_USER} --psswd ${BLUEMIX_PASSWORD} --org ${BLUEMIX_ORG} --space ${BLUEMIX_SPACE} 2> /dev/null
    RESULT=$?
else 
    # we are already logged in.  Simply check via ice command 
    echo -e "${label_color}Logging into IBM Container Service using credentials passed from IBM DevOps Services ${no_color}"
    mkdir -p ~/.ice
    debugme cat "${EXT_DIR}/${ICE_CFG}"
    cp ${EXT_DIR}/${ICE_CFG} ~/.ice/ice-cfg.ini
    debugme cat ~/.ice/ice-cfg.ini
    debugme echo "config.json:"
    debugme cat /home/jenkins/.cf/config.json | cut -c1-2
    debugme cat /home/jenkins/.cf/config.json | cut -c3-
    debugme echo "testing ice login via ice info command"
    ice --verbose info > info.log 2> /dev/null
    RESULT=$?
    debugme cat info.log 
    if [ $RESULT -eq 0 ]; then
        echo "ice info was successful.  Checking login to registry server" 
        ice images &> /dev/null
        RESULT=$? 
    else 
        echo "ice info did not return successfully.  Login failed."
    fi 
fi 

printEnablementInfo() {
    echo -e "${label_color}No namespace has been defined for this user ${no_color}"
    echo -e "${label_color}A common cause of this is when the user has not been enabled for IBM Containers on Bluemix${no_color}"
    echo -e "Please check the following: "
    echo -e "   - Login to Bluemix (https://console.ng.bluemix.net)"
    echo -e "   - Select the 'IBM Containers' icon from the Dashboard" 
    echo -e "   - Select 'Create a Container'"
    echo -e "" 
    echo -e "If there is a message indicating that your account needs to be enabled for IBM Containers, confirm that you would like to do so, and wait for confirmation that your account has been enabled"
}


# check login result 
if [ $RESULT -eq 1 ]; then
    echo -e "${red}Failed to login to IBM Container Service${no_color}" | tee -a "$ERROR_LOG_FILE"
    ice namespace get 2> /dev/null
    HAS_NAMESPACE=$?
    if [ $HAS_NAMESPACE -eq 1 ]; then 
        printEnablementInfo        
    fi
    ${EXT_DIR}/print_help.sh
    exit $RESULT
else 
    echo -e "${green}Successfully logged into IBM Container Service${no_color}"
    ice info 2> /dev/null
fi 

########################
# Setup git_retry      #
########################
source ${EXT_DIR}/git_util.sh

################################
# get the extensions utilities #
################################
pushd . >/dev/null
cd $EXT_DIR 
git_retry clone https://github.com/Osthanes/utilities.git utilities
popd >/dev/null

############################
# enable logging to logmet #
############################
source $EXT_DIR/utilities/logging_utils.sh
setup_met_logging "${BLUEMIX_USER}" "${BLUEMIX_PASSWORD}" "${BLUEMIX_SPACE}" "${BLUEMIX_ORG}" "${BLUEMIX_TARGET}"


########################
# REGISTRY INFORMATION #
########################
export NAMESPACE=$(ice namespace get)
RESULT=$?
if [ $RESULT -eq 0 ]; then
    if [ -z $NAMESPACE ]; then
        log_and_echo "$ERROR" "Did not discover namespace using ice namespace get, but no error was returned"
        printEnablementInfo
        ${EXT_DIR}/print_help.sh
        exit $RESULT
    fi
else 
    log_and_echo "$ERROR" "ice namespace get' returned an error"
    printEnablementInfo
    ${EXT_DIR}/print_help.sh    
    exit 1
fi 

log_and_echo "$LABEL" "Users namespace is $NAMESPACE"
export REGISTRY_URL=${CCS_REGISTRY_HOST}/${NAMESPACE}
export FULL_REPOSITORY_NAME=${REGISTRY_URL}/${IMAGE_NAME}:${APPLICATION_VERSION}
log_and_echo "$LABEL" "The desired image repository name will be ${FULL_REPOSITORY_NAME}"

debugme echo "Validating full repository name"
pipeline_validate_full  ${FULL_REPOSITORY_NAME} >validate.log 2>&1 
VALID_NAME=$?
if [ ${VALID_NAME} -ne 0 ]; then    
    log_and_echo "$ERROR" " ${FULL_REPOSITORY_NAME} is not a valid repository name"
    log_and_echo `cat validate.log` 
    ${EXT_DIR}/print_help.sh
    exit ${VALID_NAME}
else 
    debugme cat validate.log 
fi 

log_and_echo "$LABEL" "Initialization complete"

# run image cleanup if necessary
. $EXT_DIR/image_utilities.sh
