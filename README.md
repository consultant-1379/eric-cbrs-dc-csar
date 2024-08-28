# eric-cbrs-dc-package-csar

Build the full csar:
```shell
./build.sh -C <chart> [-l]
```
e.g:
```shell
./build.sh -C ../eric-cbrs-dc-package-0.1.0.tgz
```

To build a light version:
```shell
./build.sh -C ../eric-cbrs-dc-package-0.1.0.tgz -l
```

To clean the build:
```shell
./build.sh -c
```