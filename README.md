<p align="center" dir="auto">
  <a target="_blank" rel="noopener noreferrer" href="https://imgbb.com/"><img src="https://i.ibb.co/k2cb5fw/icon.png" alt="icon" border="0" height="240" style="max-width: 100%;"></a>
  <br>
  <strong>Kraken - script to easy install and use reconnaissance tools</strong> 
  <br><br>
  <strong>Recode The Copyright Is Not Make You A Coder</strong>
</p><br><br>


# Kraken

#### Shell script that uses together the best and most used tools in the world to find a fault, bugs or even Pentest. Treated in the best way to facilitate use in the terminal, it contains a report in modern and easy to understand html. you can export the entire report in a zip file, and in addition it has a menu that contains all the reports already carried out in the past. light, easy and fast to use!

#### by default kraken will recognize "subdomains, ports, services, technologies, subdirectories and urls"
#### there is a list of tools available for you to use when running kraken. it returns a window with several tool options available for you to select.


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
#

### Warning: This code was originally created for personal use, it generates a substantial amount of traffic, please use with caution.
