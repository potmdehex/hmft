* Support all devices 14.2-14.8 (currently the sandbox escape has hardcoded offsets that only work on some devices as commented in the code)
* Support all devices 14.0-14.2 (currently pre-14.2 offsets for kmsg are hardcoded)
* Use a better sandbox escape than the current label NULLing
* Fix/work around memory issues with libarchive when many files are selected to be archived
* Fix cleanup