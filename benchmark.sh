#!/bin/bash
#
# Originally:
#     Installtion script of ATLAS CMake nightly RPMs
#     Author: Johannes Elmsheuser, Attila Krasznahorkay
#     Date: April 2016
# Modified:
#     Benchmarking of build to CVMFS
#     Author: Tomáš Stefan
#     Date: July 2018

show_help() {
    echo "USAGE"
    echo "./benchmark.sh -r <nightly_ver> -d <install_dir> -t <date_str> pkg1 [pkg2 ...]"
    echo "EXAMPLE"
    echo "./benchmark.sh -r master/x86_64-centos7-gcc62-opt/2018-07-03T2137 -d /build/athena Athena_22.0.1_x86_64-centos7-gcc62-opt"
}

parse_args() {
    OPTIND=1

    while getopts ":r:d:t:" opt; do
        case "$opt" in
            h|\?)
                show_help
                exit 0
                ;;
            r)
                NIGHTLYVER=$OPTARG
                ;;
            d)
                INSTALLDIR=`readlink -f $OPTARG`
                ;;
            t)
                DATEDIR=$OPTARG
                ;;
        esac
    done

    # Remove parsed options
    shift $((OPTIND-1))
    PROJECTS=$@
}

pre_setup() {
    if [ ! -d "$TMPDIR" ]; then
        if [ -d "/tmp/$USER" ]; then
            export TMPDIR=/tmp/$USER
        else
            export TMPDIR=$HOME
        fi
    fi

    # ayum directory
    AYUMDIR=$TMPDIR
    # Directory name with the date
    if [ -z "$DATEDIR" ]; then
        DATEDIR=`date "+%FT%H%M"`
    fi

    echo "#############################################"
    echo "Installing project(s) $PROJECTS"
    echo "  from nightly  : $NIGHTLYVER"
    echo "  into directory: $INSTALLDIR/$DATEDIR"
    echo "  AYUM directory: $AYUMDIR"
    echo "#############################################"
    echo

    # Check that everything was specified:
    if [ -z "$NIGHTLYVER" ] || [ -z "$INSTALLDIR" ] || [ -z "$PROJECTS" ]; then
        show_help
        exit 1
    fi

    # Create RPM directory:
    if [ ! -d "$INSTALLDIR" ]; then
        echo "Creating directory $INSTALLDIR"
        mkdir -p $INSTALLDIR
    fi

    # Get the branch name only and then the main base from it
    NIGHTLYBRANCH=`echo $NIGHTLYVER |cut -d'/' -f 1 |cut -d'-' -f 1`
    echo $NIGHTLYBRANCH
    MAINBASEREL=`echo $NIGHTLYBRANCH | sed '/^[^\.]\+\.[^\.]\+\./!d;s,^\([^\.]\+\.[^\.]\+\)\..*$,\1,'`
}

setup_ayum() {
    #Download ayum
    CURDIR=$PWD
    cd $AYUMDIR
    rm -rf ayum/
    git clone https://gitlab.cern.ch/rhauser/ayum.git
    cd ayum
    ./configure.ayum -i $INSTALLDIR -D > yum.conf

    # Remove the unnecessary line from the generated file:
    sed 's/AYUM package location.*//' yum.conf > yum.conf.fixed
    mv yum.conf.fixed yum.conf

    #Setup ayum repositories
    cat - >./etc/yum.repos.d/lcg.repo <<EOF
    [lcg-repo]
    name=LCG Repository
    baseurl=http://lcgpackages.web.cern.ch/lcgpackages/rpms
    prefix=${INSTALLDIR}/sw/lcg/releases
    enabled=1
    EOF

    cat - >./etc/yum.repos.d/tdaq-nightly.repo <<EOF
    [tdaq-nightly]
    name=nightly snapshots of TDAQ releases
    baseurl=http://cern.ch/atlas-tdaq-sw/yum/tdaq/nightly
    enabled=1
    EOF

    cat - >./etc/yum.repos.d/tdaq-testing.repo <<EOF
    [tdaq-testing]
    name=non-official updates and patches for TDAQ releases
    baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/tdaq/testing
    enabled=1

    [dqm-common-testing]
    name=dqm-common projects
    baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/dqm-common/testing
    enabled=1

    [tdaq-common-testing]
    name=non-official updates and patches for TDAQ releases
    baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/tdaq-common/testing
    enabled=1
    EOF

    cat - >./etc/yum.repos.d/atlas-offline-data.repo <<EOF
    [atlas-offline-data]
    name=ATLAS offline data packages
    baseurl=http://cern.ch/atlas-software-dist-eos/RPMs/data
    enabled=1
    EOF

    cat - >./etc/yum.repos.d/atlas-offline-nightly.repo <<EOF
    [atlas-offline-nightly]
    name=ATLAS offline nightly releases
    baseurl=http://cern.ch/atlas-software-dist-eos/RPMs/nightlies/${NIGHTLYVER}
    prefix=${INSTALLDIR}/${DATEDIR}
    enabled=1
    EOF

    # CentOS 7
    cat - >./etc/yum.repos.d/tdaq-common-centos7.repo <<EOF
    [tdaq-common-centos7]
    name=tdaq-common-centos7
    baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/tdaq-common/centos7
    enabled=1
    EOF

    cat - >./etc/yum.repos.d/dqm-common-centos7.repo <<EOF
    [dqm-common-centos7]
    name=dqm-common-centos7
    baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/dqm-common/centos7
    enabled=1
    EOF

    cat - >./etc/yum.repos.d/tdaq-centos7.repo <<EOF
    [tdaq-centos7]
    name=TDAQ releases - Centos 7
    baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/tdaq/centos7
    enabled=1
    EOF

    # Tell the user what happened:
    echo "Configured AYUM"

    # Setup environment to run the ayum command:
    shopt -s expand_aliases
    source ./setup.sh
    cd $CURDIR
}

################################################################################
#                                Main
set -e    # stop on errors

parse_args
pre_setup
setup_ayum

# Drop disc caches and finish pending writes
echo 3 > /proc/sys/vm/drop_caches
sync

# Start measuring time
START_SECONDS=$(date +%s)

ayum -y install $PROJECTS

# Stop measuring time
END_SECONDS=$(date +%s)

ELAPSED_TIME=$((END_SECONDS - START_SECONDS))

echo
echo "#####################################################"
echo "#                    Benchmark                      #"
echo "#---------------------------------------------------#"
echo " Start time: $(date --date @${START_SECONDS})        "
echo " End time: $(date --date @${END_SECONDS})            "
echo " TOTAL: ${ELAPSED_TIME} seconds                      "
echo "     =: $(date --date @${ELAPSED_TIME} -u +%H:%M:%S) (hh:mm:ss)"
echo "#####################################################"
