# bench-athena-builds

## Description
The tests are comparing installation time with an ayum command to  destination on a local storage versus destination inside of a CVMFS repository. Also includes tests for a new feature allowing parallel CVMFS transactions from multiple release managers to single gateway.

Packages are downloaded to local repository before the measuring starts. That excludes problems with network instability.

Output of each test is included in the *logs* directory.

The tests were performed on five physical machines: *cvm-perf04 - cvm-perf08* running CentOS 7.5. Each of them has:

  - RAM: 64 GB
  - CPU(s): 32 (16 cores * 2 threads)
    - Model: Intel(R) Xeon(R) CPU E5-2630 v3 @ 2.40GHz
  - HDD: 1 TB
    - Model: SAMSUNG MZ7KM960 Rev: 003Q

## Tests
1. Install *Athena_22.0.1_x86_64-centos7-gcc62-opt* from *master/x86_64-centos7-gcc62-opt/2018-07-04T2126* to local disk.
  - Prerequisite:
    ```
    rm -rf /build /root/rpm_download
    yum clean all
    mkdir /build
    mkdir /root/rpm_download
    ```
2. Install *Athena_22.0.1_x86_64-slc6-gcc62-opt* from *master/x86_64-slc6-gcc62-opt/2018-07-04T2055* to local disk.
  - Prerequisite:
    ```
    rm -rf /build /root/rpm_download
    yum clean all
    mkdir /build
    mkdir /root/rpm_download
    ```

## Results

### 1a. (cvm-perf04)
```
[root@cvm-perf04 bench-athena-builds]# ./benchmark.sh -r master/x86_64-centos7-gcc62-opt/2018-07-04T2126 -d /build/athena Athena_22.0.1_x86_64-centos7-gcc62-opt |tee benchmark_1a.log
```

##### Time
```
# TOTAL: 800 seconds   
#     =: 00:13:20 (hh:mm:ss)
```

### 1b. (cvm-perf05)
```
[root@cvm-perf05 bench-athena-builds]# ./benchmark.sh -r master/x86_64-centos7-gcc62-opt/2018-07-04T2126 -d /build/athena Athena_22.0.1_x86_64-centos7-gcc62-opt |tee benchmark_1b.log
```

##### Time
```
# TOTAL: 804 seconds
#     =: 00:13:24 (hh:mm:ss)
```

### 1c. (cvm-perf06)
```
[root@cvm-perf06 bench-athena-builds]# ./benchmark.sh -r master/x86_64-centos7-gcc62-opt/2018-07-04T2126 -d /build/athena Athena_22.0.1_x86_64-centos7-gcc62-opt |tee benchmark_1c.log
```

##### Time
```
# TOTAL: 802 seconds
#     =: 00:13:22 (hh:mm:ss)
```

### 1d. (cvm-perf07)
```
[root@cvm-perf07 bench-athena-builds]# ./benchmark.sh -r master/x86_64-centos7-gcc62-opt/2018-07-04T2126 -d /build/athena Athena_22.0.1_x86_64-centos7-gcc62-opt |tee benchmark_1d.log
```

##### Time
```
# TOTAL: 799 seconds   
#     =: 00:13:19 (hh:mm:ss)
```

### 1e. (cvm-perf08)
```
[root@cvm-perf08 bench-athena-builds]# ./benchmark.sh -r master/x86_64-centos7-gcc62-opt/2018-07-04T2126 -d /build/athena Athena_22.0.1_x86_64-centos7-gcc62-opt |tee benchmark_1e.log
```

##### Time
```
# TOTAL: 799 seconds
#     =: 00:13:19 (hh:mm:ss)
```

---

### 2a. (cvm-perf04)
```
[root@cvm-perf04 bench-athena-builds]# ./benchmark.sh -r master/x86_64-slc6-gcc62-opt/2018-07-04T2055 -d /build/athena Athena_22.0.1_x86_64-slc6-gcc62-opt |tee benchmark_2a.log
```

##### Time
```
# TOTAL: 823 seconds   
#     =: 00:13:43 (hh:mm:ss)
```

### 2b. (cvm-perf05)
```
[root@cvm-perf05 bench-athena-builds]# ./benchmark.sh -r master/x86_64-slc6-gcc62-opt/2018-07-04T2055 -d /build/athena Athena_22.0.1_x86_64-slc6-gcc62-opt |tee benchmark_2b.log
```

##### Time
```
# TOTAL: 825 seconds
#     =: 00:13:45 (hh:mm:ss)
```

### 2c. (cvm-perf06)
```
[root@cvm-perf06 bench-athena-builds]# ./benchmark.sh -r master/x86_64-slc6-gcc62-opt/2018-07-04T2055 -d /build/athena Athena_22.0.1_x86_64-slc6-gcc62-opt |tee benchmark_2c.log
```

##### Time
```
# TOTAL: 824 seconds
#     =: 00:13:44 (hh:mm:ss)
```

### 2d. (cvm-perf07)
```
[root@cvm-perf07 bench-athena-builds]# ./benchmark.sh -r master/x86_64-slc6-gcc62-opt/2018-07-04T2055 -d /build/athena Athena_22.0.1_x86_64-slc6-gcc62-opt |tee benchmark_2d.log
```

##### Time
```
# TOTAL: 823 seconds
#     =: 00:13:43 (hh:mm:ss)
```

### 2e. (cvm-perf08)
```
[root@cvm-perf08 bench-athena-builds]# ./benchmark.sh -r master/x86_64-slc6-gcc62-opt/2018-07-04T2055 -d /build/athena Athena_22.0.1_x86_64-slc6-gcc62-opt |tee benchmark_2e.log
```

##### Time
```
# TOTAL: 823 seconds
#     =: 00:13:43 (hh:mm:ss)
```

---
