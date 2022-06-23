# Kraken
Shell script to easy install and use reconnaissance tools
Complete shell script tool for Bug bounty or Pentest ! It will save 90% of your time when setting up your machine to work.
It already configures all the tools for you to work, you won't need to configure it manually.


1. [Installation](#installation)
   1. [Minimal installation](#minimal-installation)
   2. [Full installation](#full-installation)

2. [Usage](#usage)
   1. [Simple and fast](simple-usage)
   2. [Parameters options](#parameters-options)

## Installation
Run as root
### Minimal installation
through git
```sh
git clone https://github.com/DonatoReis/kraken
sudo kraken/install.sh httpx anonsurf amass aquatone dirsearch feroxbuster
```
or through curl
```sh
curl -sL https://github.com/DonatoReis/kraken/raw/master/install.sh \
  | sudo bash -s httpx anonsurf amass aquatone dirsearch feroxbuster
```
### Full installation
through git
```sh
git clone https://github.com/DonatoReis/kraken
sudo kraken/install.sh
```
or through curl
```sh
curl -sL https://github.com/DonatoReis/kraken/raw/master/install.sh | sudo bash
```
## Usage
### Reconnaissance Tools
Simple and fast recon
```sh
kraken -f -d domain.com
```
### Parameters options
```sh
  General options
    -d, --domain           Scan domain and subdomains
    -dL,--domain-list      File containing list of domains for subdomain discovery
    -a, --anon             Setup usage of anonsurf change IP 〔 Default: On 〕
    -A, --agressive        Use all sources (slow) for enumeration 〔 Default: Off 〕
    -n, --no-subs          Scan only the domain given in -d domain.com
    -f, --fast-scan        Scan without options menu
    -u, --update           Update script for better performance
    -V, --version          Print current version
    -h, --help             Show the help message and exit
    --delay                Seconds waiting between tools execution 〔 Default: 5 〕
```
