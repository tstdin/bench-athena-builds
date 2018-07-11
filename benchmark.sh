#!/bin/bash
#
# Originally:
#     Installation script of ATLAS CMake nightly RPMs
#     Author: Johannes Elmsheuser, Attila Krasznahorkay
#     Date: April 2016
# Modified:
#     Benchmarking of build to CVMFS
#     Author: Tomáš Stefan
#     Date: July 2018

show_help() {
    echo
    echo "USAGE"
    echo "./benchmark.sh -r <nightly_ver> -d <install_dir> [-t <date_str>] [-c <cvmfs_repo>] [-T <seconds_since_epoch>] pkg1 [pkg2 ...]"
    echo "EXAMPLE"
    echo "./benchmark.sh -r master/x86_64-centos7-gcc62-opt/2018-07-03T2137 -d /build/athena Athena_22.0.1_x86_64-centos7-gcc62-opt"
    echo "NOTE"
    echo "-c is required even if there is only one CVMFS repository in order to decide whether starting a transaction is needed"
    echo "    When testing simultaneous publications, specify repository name followed by the subtree."
    echo "-T accepts seconds since 1970-01-01 UTC, used for starting parallel installations from different machines at the same time"
    echo "    provide such a value that all machines have enough time to download all the packages and prepare for the installation"
    echo
}

parse_args() {
    OPTIND=1

    while getopts ":r:d:t:c:T:" opt; do
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
            T)
                START_AT=$OPTARG
                ;;
            c)
                CVMFS_REPO=$OPTARG
                ;;
        esac
    done

    # Remove parsed options
    shift $((OPTIND-1))
    PROJECTS=$@
}

check_commands() {
    if ! hash git 2>/dev/null; then
        echo "ERROR: missing git command"
        exit 1
    fi

    if ! hash cvmfs_server 2>/dev/null && [ ! -z "$CVMFS_REPO" ]; then
        echo "ERROR: missing cvmfs_server command"
        exit 1
    fi

    if ! hash yumdownloader 2>/dev/null && [ ! -z "$CVMFS_REPO" ]; then
        echo "ERROR: missing yumdownloader command"
        exit 1
    fi

    if ! hash createrepo 2>/dev/null && [ ! -z "$CVMFS_REPO" ]; then
        echo "missing createrepo command"
        exit 1
    fi
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

    echo
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

    # (re)create directory for local repository
    rm -rf /root/rpm_download; mkdir /root/rpm_download

    # Create RPM directory:
    if [ ! -d "$INSTALLDIR" ]; then
        echo "Creating directory $INSTALLDIR"

        # If destination inside of CVMFS, start transaction
        if [ ! -z "$CVMFS_REPO" ]; then
            cvmfs_server transaction "$CVMFS_REPO"
        fi

        mkdir -p "$INSTALLDIR"
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

    # Setup local repository file to ayum (created later)
    cat <<EOF >./etc/yum.repos.d/rpm_download.repo
[rpm-download]
name=Local Repository of downloaded RPMs
baseurl=file:///root/rpm_download
enabled=1
EOF

    # Setup yum repositories for downloading of the packages
    cat <<EOF > /etc/yum.repos.d/lcg.repo
[lcg-repo]
name=LCG Repository
baseurl=http://lcgpackages.web.cern.ch/lcgpackages/rpms
prefix=${INSTALLDIR}/sw/lcg/releases
enabled=1
EOF

    cat <<EOF > /etc/yum.repos.d/tdaq-nightly.repo
[tdaq-nightly]
name=nightly snapshots of TDAQ releases
baseurl=http://cern.ch/atlas-tdaq-sw/yum/tdaq/nightly
enabled=1
EOF

    cat <<EOF > /etc/yum.repos.d/tdaq-testing.repo
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

    cat <<EOF > /etc/yum.repos.d/atlas-offline-data.repo
[atlas-offline-data]
name=ATLAS offline data packages
baseurl=http://cern.ch/atlas-software-dist-eos/RPMs/data
enabled=1
EOF

    cat <<EOF > /etc/yum.repos.d/atlas-offline-nightly.repo
[atlas-offline-nightly]
name=ATLAS offline nightly releases
baseurl=http://cern.ch/atlas-software-dist-eos/RPMs/nightlies/${NIGHTLYVER}
prefix=${INSTALLDIR}/${DATEDIR}
enabled=1
EOF

    # CentOS 7
    cat <<EOF > /etc/yum.repos.d/tdaq-common-centos7.repo
[tdaq-common-centos7]
name=tdaq-common-centos7
baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/tdaq-common/centos7
enabled=1
EOF

    cat <<EOF > /etc/yum.repos.d/dqm-common-centos7.repo
[dqm-common-centos7]
name=dqm-common-centos7
baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/dqm-common/centos7
enabled=1
EOF

    cat <<EOF > /etc/yum.repos.d/tdaq-centos7.repo
[tdaq-centos7]
name=TDAQ releases - Centos 7
baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/tdaq/centos7
enabled=1
EOF

    # Additional extracted from ayum
    cat <<EOF > /etc/yum.repos.d/tdaq.repo
[tdaq-common-slc6]
name=tdaq-common
baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/tdaq-common/slc6
enabled=1
[dqm-common-slc6]
name=dqm-common
baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/dqm-common/slc6
enabled=1
[tdaq-slc6]
name=TDAQ releases
baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/tdaq/slc6
enabled=1
[external]
name=external sw
baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/external
EOF

    cat <<EOF > /etc/yum.repos.d/offline.repo
[offline-lcg-slc6]
name=LCG SLC6
baseurl=http://cern.ch/atlas-software-dist-eos/RPMs/lcg/slc6/yum
enabled=1

[offline-slc6]
name=ATLAS offline releases SLC6
baseurl=http://atlas-computing.web.cern.ch/atlas-computing/links/reposDirectory/offline/slc6/yum
enabled=1
EOF

    # Tell the user what happened:
    echo "Configured AYUM"

    # Setup environment to run the ayum command:
    shopt -s expand_aliases
    source ./setup.sh
    cd $CURDIR
}

wait_for_start_time() {
    if [ ! -z "$START_AT" ]; then
        SECONDS_NOW=$(date +%s)
        SECONDS_WAIT=$((START_AT - SECONDS_NOW))

        echo
        echo "#############################################"
        echo "Time now: $(date --date @${SECONDS_NOW} -u '+%d.%m.%Y %T')"
        echo "Waiting untill provided time: $(date --date @${START_AT} -u '+%d.%m.%Y %T')"
        echo

        if [ $SECONDS_WAIT -le 0 ]; then
            echo "ERROR: time is not in the future"
            exit 1
        fi

        sleep $SECONDS_WAIT
    fi
}

################################################################################
#                                Main
set -e    # stop on errors

parse_args "$@"
check_commands
pre_setup
setup_ayum

# Drop disc caches and finish pending writes
echo 3 > /proc/sys/vm/drop_caches
sync

# Download packages with all their dependencies to local storage
echo
echo "#############################################"
echo "Downloading packages to local repository"
echo
yumdownloader --destdir=/root/rpm_download --resolve --disableplugin=protectbase $PROJECTS
createrepo /root/rpm_download
ayum makecache --disablerepo='*' --enablerepo='rpm-download'

wait_for_start_time

echo
echo "#############################################"
echo "Starting measured installation"
echo

# ------------------------ START measuring time --------------------------------
START_SECONDS=$(date +%s)

# Install from the local repository
ayum -y install --disablerepo='*' --enablerepo='rpm-download' $PROJECTS

if [ ! -z "$CVMFS_REPO" ]; then
    cvmfs_server publish "$CVMFS_REPO"
fi

# ------------------------ STOP measuring time ---------------------------------
END_SECONDS=$(date +%s)

ELAPSED_TIME=$((END_SECONDS - START_SECONDS))

echo
echo "###################################"
echo "#            Benchmark             "
echo "#----------------------------------"
echo "# Start time: $(date --date @${START_SECONDS} -u '+%d.%m.%Y %T')"
echo "# End time: $(date --date @${END_SECONDS} -u '+%d.%m.%Y %T')"
echo "# TOTAL: ${ELAPSED_TIME} seconds   "
echo "#     =: $(date --date @${ELAPSED_TIME} -u +%H:%M:%S) (hh:mm:ss)"
echo "###################################"
echo
