#!/usr/bin/env bash
#
APP='Kraken'
version=0.0.32

# ANSI Colors
function load_ansi_colors() {
  # @C FG Color
  #    |-- foreground color
  export CReset='\e[m' CFGBlack='\e[30m' CFGRed='\e[31m' CFGGreen='\e[32m' \
    CFGYellow='\e[33m' CFGBlue='\e[34m' CFGPurple='\e[35m' CFGCyan='\e[36m' \
    CFGWhite='\e[37m'
  # @C BG Color
  #    |-- background color
  export CBGBlack='\e[40m' CBGRed='\e[41m' CBGGreen='\e[42m' CBGYellow='\e[43m' \
    CBGBlue='\e[44m' CBGPurple='\e[45m' CBGCyan='\e[46m' CBGWhite='\e[47m'
  # @C Attribute
  #    |-- text attribute
  export CBold='\e[1m' CFaint='\e[2m' CItalic='\e[3m' CUnderline='\e[4m' \
    CSBlink='\e[5m' CFBlink='\e[6m' CReverse='\e[7m' CConceal='\e[8m' \
    CCrossed='\e[9m' CDoubleUnderline='\e[21m'
}

progressbar() {
  local progressbar="$workdir/vendor/NRZCode/progressbar/ProgressBar.sh"
  [[ -x "$progressbar" && -z $APP_DEBUG ]] && $progressbar "$@" || cat
}

elapsedtime() {
  code=$?

  printtime=$SECONDS
  [[ $1 == '-p' ]] && {
    ((printtime=SECONDS - partialtime))
    partialtime=$SECONDS
    shift
  }

  status=SUCCESS
  color=${CFGGreen}
  color_status='\e[92m'
  [[ $code -ne 0 ]] && {
    status=ERROR
    color=${CFGRed}
    color_status='\e[91m'
  }

  fmt='+%_Mmin %_Ss'
  [[ $printtime -ge 3600 ]] && fmt='+%_Hh %_Mmin %_Ss'
  elapsed_time=$(date -u -d "@$printtime" "$fmt")

  printf "${CBold}%b%s complete with %b%s%b in %s${CReset}\n" \
    "$color" \
    "$1" \
    "$color_status" \
    "$status" \
    "$color" \
    "${elapsed_time//  / }"
}

cfg_listsections() {
  local file=$1
  grep -oP '(?<=^\[)[^]]+' "$file"
}

read_package_ini() {
  cfg_parser "$inifile"
  while read sec; do
    unset description depends command
    cfg_section_$sec 2>&-
    if [[ $command ]]; then
      descriptions[${sec,,}]="$sec|$description"
      tools[${sec,,}]="$sec|$depends|$command"
    fi
  done < <(cfg_listsections "$inifile")
}

check_dependencies() {
  local exit_code=0
  for pkg in $required_packages; do
    if ! type -t $pkg >/dev/null; then
      printf '%s: ERROR: Required package %s.\n' "$basename" "$pkg" 1>&2
      exit_code=1
    fi
  done
  [[ $exit_code == 1 ]] && exit $exit_code

  if [[ ! -r "$workdir/vendor/NRZCode/bash-ini-parser/bash-ini-parser" ]]; then
    git clone -q 'https://github.com/NRZCode/bash-ini-parser' "$workdir/vendor/NRZCode/bash-ini-parser"
    git clone -q 'https://github.com/NRZCode/progressbar' "$workdir/vendor/NRZCode/progressbar"
  fi
  source "$workdir/vendor/NRZCode/bash-ini-parser/bash-ini-parser"
}

check_inifile() {
  if [[ ! -r "$inifile" ]]; then
    [[ -r "$workdir/package-dist.ini" ]] &&
      cp "$workdir"/package{-dist,}.ini \
        || wget -qO "$workdir/package.ini" https://github.com/DonatoReis/Kraken/raw/master/package-dist.ini
  fi
  [[ -r "$inifile" ]] || exit 1
}

check_environments() {
  if [[ ! -r "$workdir/.env" ]]; then
    [[ -r "$workdir/.env-dist" ]] &&
      cp "$workdir"/.env{-dist,}
  fi
  [[ -r "$workdir/.env" ]] && source "$workdir/.env"
}

check_domain() {
  if [[ $domainfile ]]; then
    [[ -r "$domainfile" ]] || { printf '%s\n' "INVALID domain file: $domainfile"; exit 1; }
    domainslist=$(<$domainfile)
  fi
  [[ -t 0 ]] || domainslist="$(</dev/stdin)"
  if [[ -z $domainslist ]]; then
    [[ -z "$target_domain" ]] && { banner_logo; read -p 'Enter domain: ' target_domain; }
    domainslist="$target_domain"
  fi
}

update_tools() {
  echo '[+] wait a moment...'
  git -C "$workdir" pull --all
  while read sec; do
    unset url script depends post_install
    cfg_section_$sec 2>&-
    repo=${url%%+(.git|/)}
    : "${repo%/*}"
    vendor=${_##*/}
    dir="/usr/local/$vendor/${repo##*/}"
    if [[ -d "$dir/.git" ]]; then
      branch=$(git -C "$dir" branch --show-current)
      git -C "$dir" pull -q origin $branch
    fi
  done < <(cfg_listsections "$inifile")
}

mklogdir() {
  local logdir=$1
  mkdir -p "$logdir"
  export dtreport=$(date '+%Y%m%d%H%M')
}

form() {
  [[ $dg_checklist_mode == 0 ]] && return 0
  backtitle="Reconnaissence tools [$APP]"
  title="Target's Reconnaissence [$target_domain]"
  text='Select tools:'
  width=0
  dialog=dialog
  [[ $XAUTHORITY ]] && dialog=yad

  # menu checklist
  case $dialog in
    dialog)
      dg=(dialog --stdout --title "$title" --backtitle "$backtitle" --ok-label 'Run tools' --checklist "$text" 0 "$width" 0)
      [[ $dg_checklist_status == 'checked' ]] && dg_checklist_status=ON || dg_checklist_status=OFF
      items_fmt="%s\n%s\n$dg_checklist_status\n"
      ;;
    yad)
      dg=(yad --height 600 --width 800 --center --window-icon="$workdir/share/icons/logo-48x48.png" --image="$workdir/share/icons/logo-48x48.png" --title "$backtitle" --text "$title" --button='Run tools!gtk-ok:0' --button='gtk-cancel:1' --buttons-layout=spread --list --checklist --column '#' --column Tool --column Description)
      [[ $dg_checklist_status == 'checked' ]] && dg_checklist_status=TRUE || dg_checklist_status=FALSE
      items_fmt="$dg_checklist_status\n%s\n%s\n"
      ;;
      *) echo 'ERROR: Dialog not defined!'; exit 1;;
  esac
  mapfile -t checklist_items < <(for tool in "${!descriptions[@]}"; do IFS='|' read t d <<< "${descriptions[$tool]}"; printf "$items_fmt" "$t" "$d"; done)
  selection=$("${dg[@]}" "${checklist_items[@]}")
  [[ $? == @(1|252) ]] && return 1
  case $dialog in
    yad)
      selection=$(while IFS='|' read status tool description; do [[ $status == TRUE ]] && echo "$tool"; done <<< "$selection")
      ;;
  esac
  return 0
}

interrupt_handler() {
  if [[ $interrupt_handler == 1 ]]; then
    printf "\rCTRL+C: Aborted by user!\n"
  fi
}
trap interrupt_handler SIGINT

risk_rating_levels() {
  local file=$1
  scores=($(awk 'BEGIN {
    count_high=0
    count_medium=0
    count_low=0
    count_info=0
    total=0
  }
  /^\|/ && $3 ~ /[0-9]+\.[0-9]/ {
    if (+$3 >= 10) {
      count_high++
    } else if (+$3 >= 7) {
      count_medium++
    } else if (+$3 >= 4) {
      count_low++
    } else {
      count_info++
    }
    if (max < +$3)
      max=$3
    total++
  } END {
    level_high=0
    level_medium=0
    level_low=0
    level_info=0
    if (total) {
      level_high=100*count_high/total
      level_medium=100*count_medium/total
      level_low=100*count_low/total
      level_info=100*count_info/total
    }
    printf "%d %d\n%d %d\n%d %d\n%d %d\n%d\n",
      count_high, level_high,
      count_medium, level_medium,
      count_low, level_low,
      count_info, level_info,
      max
  }' "$file"))
  level_high=(${scores[0]} ${scores[1]})
  level_medium=(${scores[2]} ${scores[3]})
  level_low=(${scores[4]} ${scores[5]})
  level_info=(${scores[6]} ${scores[7]})
  max_score=${scores[8]}
}

nmap_report() {
  local file=$1
  [[ -r "$file" ]] && awk '/^PORT/{flag=1} /^Service/{flag=0} flag {gsub(/\\/, "\\\\"); gsub(/\|/, "\\|"); printf "%s\\n", $0}' "$file"
}

domain_info_report() {
  if [[ $1 == @(host|whois|dig) ]]; then
    $1 "$2" | awk '$0 !~ /^%/{gsub(/\|/, "\\|"); printf "%s\\n", $0}'
  fi
}

report_tools() {
  tools[mrx]='Enum subdomains|amass|amass enum -passive -d "$target_domain" -o "$logfile"; httpx -silent < "$logfile" > "$logdir/${dtreport}httpx.log"'
  tools[dirsearch]='directories|dirsearch|dirsearch -q -e php,aspx,jsp,html,cgi -x 404-499,500-599 -w "$dicc" -t 20 --random-agent --skip-on-status 429,999 -o "$logfile" --url "$target_domain"'
  tools[whatweb]='web|whatweb|whatweb -q -t 50 --no-errors "$target_domain" --log-brief="$logfile"'
  tools[owasp]='getallurls|waybackurls uro anew|cat "$logdir/${dtreport}httpx.log" | waybackurls | uro | anew | sort -u > "$logfile"'
  tools[crt]='certificate|curl|curl -s "https://crt.sh/?q=%25.${target_domain}&output=json" | anew | jq > "$logfile"'
  tools[nmap]='ports|nmap|nmap -sS -sCV "$target_domain" -T4 -Pn -oN "$logfile"'
  tools[nmap-cvss]='vulnerability|nmap|nmap -sV --script vulners --script-args mincvss=1.0 "$target_domain" -oN "$logfile"'
  tools[fnmap]='ports|nmap|nmap -n -Pn -sS "$target_domain" -T4 --open -sV -oN "$logfile"'
}

report() {
  local tbody
  datetime=$(date -d "$(sed -E 's/^.{10}/&:/;s/^.{8}/& /;s/^.{6}/&-/;s/^.{4}/&-/;' <<< "$dtreport")")
  download=${dtreport}${target_domain}.zip
  ##
  # Page reports
  for report in "${!pagereports[@]}"; do
    [[ -s ${pagereports[$report]} ]] || unset pagereports[$report]
  done
  ##
  # Subdomains reports
  while read subdomain; do
    if [[ $subdomain ]]; then
      logfile="$logdir/${dtreport}${subdomain/:\/\//.}.log"
      n=$(($([[ -f "$logfile" ]] && wc -l < "$logfile" 2>&-)))
      ((scanned_urls+=n))

      href="${dtreport}${subdomain/:\/\//.}.html"
      host=$(domain_info_report host "${subdomain#@(ht|f)tp?(s)://}")
      nmap=$(nmap_report "$logdir/${dtreport}${subdomain#@(ht|f)tp?(s)://}nmap.log")
      d="${subdomain#@(ht|f)tp?(s)://}"
      for png in $logdir/screenshots/*${d//./_}*png; do
        re="(https?)__${d//./_}__(([0-9]+)__)?[[:alnum:]]+\.png"
        if [[ $png =~ $re ]]; then
          if [[ ${BASH_REMATCH[1]} == https ]]; then
            port=443
          elif [[ ${BASH_REMATCH[1]} == http ]]; then
            port=80
          fi
          port=${BASH_REMATCH[4]:-$port}
          printf -v "screenshot_$port" '%s' "$png"
        fi
      done
      if [[ $screenshot_80 ]]; then
        (
          sed '1,/{{screenshot-80}}/!d; s/{{screenshot-80}}.*/\n/' "$workdir/resources/subreport.tpl"
          echo "data:image/png;base64,$(base64 -w0 "$screenshot_80")"
          sed '/{{screenshot-80}}/,$!d; s/.*{{screenshot-80}}/\n/' "$workdir/resources/subreport.tpl"
        ) > "$logdir/temp.tpl"
        mv "$logdir/temp.tpl" "$logdir/$href"
      fi
      if [[ $screenshot_443 ]]; then
        (
          sed '1,/{{screenshot-443}}/!d; s/{{screenshot-443}}.*/\n/' "$logdir/$href"
          echo "data:image/png;base64,$(base64 -w0 "$screenshot_443")"
          sed '/{{screenshot-443}}/,$!d; s/.*{{screenshot-443}}/\n/' "$logdir/$href"
        ) > "$logdir/temp.tpl"
        mv "$logdir/temp.tpl" "$logdir/$href"
      fi
      (
        sed '1,/{{response-headers}}/!d; s/{{response-headers}}.*/\n/'  "$logdir/$href"
        : "${subdomain#@(ht|f)tp?(s)://}"
        for f in "$logdir/"headers/*${_//./_}*txt; do
          if [[ -s "$f" ]]; then
            printf "==> %s <==\n%s\n" "$f" "$(<$f)"
          fi
        done
        sed '/{{response-headers}}/,$!d; s/.*{{response-headers}}/\n/'  "$logdir/$href"
      ) > "$logdir/temp.tpl"
      mv "$logdir/temp.tpl" "$logdir/$href"
      (
        sed '1,/{{subdomains}}/!d; s/{{subdomains}}.*/\n/' "$logdir/$href"
        while read code length url; do
          url=$(sed -E 's@((ht|f)tps?[^[:space:]]+)@<a href="\1" target="_blank">\1</a>@g' <<< "$url")
          printf '<tr><td>%s</td><td>%s</td><td>%s</td></tr>' "$code" "$length" "$url"
        done < <(grep -Ev '^(#|$)' "$logfile")
        sed '/{{subdomains}}/,$!d; s/.*{{subdomains}}/\n/' "$logdir/$href"
      ) > "$logdir/temp.tpl"
      mv "$logdir/temp.tpl" "$logdir/$href"
      sed -i "s|{{domain}}|$subdomain|g;
        s|{{app}}|$APP|;
        s|{{datetime}}|$datetime|;
        s|{{screenshot-80}}||g;
        s|{{screenshot-443}}||g;
        s|{{year}}|$(date +%Y)|;
        s|{{nmap}}|$nmap|;
        s|{{host}}|$host|;" "$logdir/$href"

      tbody+=$(printf "<tr><td><a href='%s'>%s</a></td><td>%s</td></tr>" "$href" "$subdomain" "$n")
      ((subdomains_qtde++))
    fi
  done < "$logdir/${dtreport}httpx.log"
  ##
  # Domain report
  dig=$(domain_info_report dig "$target_domain")
  host=$(domain_info_report host "$target_domain")
  whois=$(domain_info_report whois "$target_domain")
  nmap=$(nmap_report "$logdir/${dtreport}nmap.log")
  risk_rating_levels "$logdir/${dtreport}nmap-cvss.log"
  (
    sed '1,/{{nmap-cvss}}/!d; s/{{nmap-cvss}}.*/\n/' "$workdir/resources/report.tpl"
    while read p cve score url; do
      if [[ $p == '|' && $score =~ [0-9]+\.[0-9] && $url =~ (ht|f)tp ]]; then
        url=$(sed -E 's@((ht|f)tps?[^[:space:]]+)@<a href="\1" target="_blank">\1</a>@g' <<< "$url")
        printf '<tr><td>%s</td><td>%s</td><td>%s</td></tr>' "$cve" "$score" "$url"
      fi
    done < "$logdir/${dtreport}nmap-cvss.log"
    sed '/{{nmap-cvss}}/,$!d; s/.*{{nmap-cvss}}/\n/' "$workdir/resources/report.tpl"
  ) > "$logdir/temp.tpl"
  unset pagereports[nmap] pagereports[nmap-cvss]
  ##
  # Cards report
  (
    sed '1,/{{cards-reports}}/!d; s/{{cards-reports}}.*/\n/' "$logdir/temp.tpl"
    while read paginate; do
      i=1
      while read cards; do
        sed '1,/{{row}}/!d; s/{{row}}.*/\n/' "$workdir/resources/card-row.tpl"
        for card in $cards; do
          printf -v template "$workdir/resources/card-%02d.tpl" $((i++))
          sed "1,/{{logfile}}/!d; s/{{title}}/${card^}/; s/{{logfile}}.*/\n/" "$template"
          cat "${pagereports[$card]}"
          sed '/{{logfile}}/,$!d; s/.*{{logfile}}/\n/' "$template"
        done
        sed '/{{row}}/,$!d; s/.*{{row}}/\n/' "$workdir/resources/card-row.tpl"
      done < <(xargs -n2 <<< $paginate)
    done < <(xargs -n4 <<< ${!pagereports[@]})
    sed '/{{cards-reports}}/,$!d; s/.*{{cards-reports}}/\n/' "$logdir/temp.tpl"
  ) > "$logdir/${dtreport}report-01.html"
  rm "$logdir/temp.tpl"
  sed -i "s|{{domain}}|$target_domain|g;
    s|{{app}}|$APP|;
    s|{{datetime}}|$datetime|;
    s|{{year}}|$(date +%Y)|;
    s|{{subdomains}}|$tbody|;
    s|{{dig}}|$dig|;
    s|{{host}}|$host|;
    s|{{whois}}|$whois|;
    s|{{scanned-urls}}|$scanned_urls|g;
    s|{{subdomains-qtde}}|$subdomains_qtde|g;
    s|{{count-high}}|${level_high[0]}|g;
    s|{{level-high}}|${level_high[1]}|g;
    s|{{count-medium}}|${level_medium[0]}|g;
    s|{{level-medium}}|${level_medium[1]}|g;
    s|{{count-low}}|${level_low[0]}|g;
    s|{{level-low}}|${level_low[1]}|g;
    s|{{count-info}}|${level_info[0]}|g;
    s|{{level-info}}|${level_info[1]}|g;
    s|{{max-score}}|$max_score|g;
    s|{{download}}|$download|;
    s|{{nmap}}|$nmap|;" "$logdir/${dtreport}report-01.html"
  [[ $max_score -eq 0 ]] && sed -i '/{{risk-ratings-report}}/,/{{risk-ratings-report}}/d' "$logdir/${dtreport}report-01.html"
  ##
  # Compact reports
  cp $logdir/${dtreport}report-01.html $logdir/report.html
  cd "$logdir"
  zip -q -r ${dtreport}${target_domain}.zip ${dtreport}*html report.html screenshots/ headers/
  xdg-open "$logdir/${dtreport}report-01.html" &
  ##
  # Menu reports
  btview='<a href="%s" class="btn-menu"><i class="fa fa-bar-chart"></i>&nbsp;Visualizar</a>'
  btdownload='<a href="%s" class="btn-menu"><i class="fa fa-file-archive-o"></i>&nbsp;Download</a>'
  rows=$(
  for str_domain in $workdir/log/*; do
    for report in $str_domain/*; do
      if [[ ${report##*/} =~ ^(([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})).* ]]; then
        echo  "${str_domain##*/}/${BASH_REMATCH[1]}"
      fi
    done
  done | sort -u
  )
  (
  sed '1,/{{reports}}/!d; s/{{reports}}.*/\n/' "$workdir/resources/menu.tpl"
  while read report; do
    str_domain=${report%%/*}
    if [[ $report =~ (([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})) ]]; then
      printf -v bt1 "$btview" "$str_domain/${BASH_REMATCH[1]}report-01.html"
      printf -v bt2 "$btdownload" "$str_domain/${BASH_REMATCH[1]}.zip"
      printf '<tr><td><a href="%s">%s %s/%s/%s %s:%s</a></td><td>%s&nbsp;&nbsp;%s</td></tr>' \
        "$str_domain/${BASH_REMATCH[1]}report-01.html" \
        "$str_domain" "${BASH_REMATCH[4]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[5]}" "${BASH_REMATCH[6]}" \
        "$bt1" "$bt2"
    fi
  done <<< "$rows"
  sed '/{{reports}}/,$!d; s/.*{{reports}}/\n/' "$workdir/resources/menu.tpl"
  ) > "$workdir/log/menu.html"
  sed -i "s|{{app}}|$APP|g;
    s|{{year}}|$(date +%Y)|;" "$workdir/log/menu.html"
  xdg-open "$workdir/log/menu.html" &
}

lolcat() {
  lolcat=/usr/games/lolcat
  if type -t $lolcat >/dev/null; then $lolcat; else cat; fi <<< "$1"
}

banner_logo() {
  lolcat "
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⣴⣾⡿⠟⠻⢿⣷⣦⣄⡀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣶⣿⠿⠛⠉⠀⣠⣶⣦⣀⠈⠉⠛⠿⣷⣦⣤⣀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣶⡿⠟⠋⠁⠀⠀⠀⣠⣾⣿⣿⣿⣿⣷⣄⠀⠀⠀⠉⠛⠿⢿⣶⣤⣀
⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⠟⠋⠁⠀⠀⠀⠀⠀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣷⡄⠀⠀⠀⠀⠀⠈⠙⠿⣷⣦
⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⠃⠀⠀⣀⡀⠀⠀⠀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣆⠀⠀⠀⠀⠀⠀⠀⡻⣿⣇
⠀⠀⠀⠀⠀⠀⠀⢠⣿⣏⣀⡀⠉⠉⠛⠿⣷⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣾⠿⠛⠛⠉⣀⣀⣿⣿
⠀⠀⠀⠀⠀⠀⢀⣼⣿⠿⠿⢿⣿⣶⣄⠀⠈⠻⣿⣦⡉⠻⢿⣿⣿⣿⣿⡿⠛⣡⣾⣿⠟⠁⢀⣤⣾⣿⠿⠿⠿⣿⣦⠀⠀⠀⣀⠀⠀⠀⣀⠀⢀⣀⣀⣀⡀⠀⠀⠀⢀⣀⡀⠀⠀⢀⡀⠀⠀⢀⡀⠀⣀⣀⣀⣀⣀⡀⢀⣀⠀⠀⢀⡀
⠀⠀⠀⠀⠀⠀⡿⠋⢀⡄⠀⠀⠈⠻⣿⣷⡄⠀⠘⣿⣿⣿⣾⣿⣿⣿⣿⣾⣿⣿⣿⠁⠀⣠⣿⡿⠋⠁⠀⠀⢠⡀⠙⡇⠀⠀⣿⠀⠀⣰⡟⠀⢸⡏⠉⠉⢻⡆⠀⠀⣾⠙⣧⠀⠀⢸⡇⠀⠀⣸⠇⠀⣿⡏⠉⠉⠉⠁⢸⡿⣧⠀⢸⡇
⠀⠀⠀⠀⠀⠀⠀⢰⣿⡇⠀⠀⠀⠀⠈⢿⣿⠀⠀⣿⣿⠻⣿⣿⣿⣿⣿⣿⠟⣿⣿⠀⠀⣿⡟⠁⠀⠀⠀⠀⣸⣿⠀⠀⠀⠀⣿⣤⢶⣏⠀⠀⢸⡷⠶⣶⡟⠁⠀⣸⣏⣀⣻⡆⠀⢸⣧⣤⢾⡏⠀⠀⣿⡗⠒⠒⠂⠀⢸⣷⠘⣧⢸⡇
⠀⠀⠀⠀⠀⠀⣠⣼⣿⣿⣶⣦⣄⠀⠀⠈⠃⠀⣸⣿⡇⠀⠹⣿⣿⣿⣿⠃⠀⢻⣿⡄⠀⠙⠀⠀⢀⣤⣶⣶⣿⣿⣦⣄⠀⠀⣿⠀⠀⠻⣦⠀⢸⡇⠀⠈⢷⡄⢠⡿⠉⠉⠉⣿⡀⢸⡇⠀⠈⢻⣆⠀⣿⣧⣤⣤⣤⡀⢸⣿⠀⠘⣿⡇
⠀⢀⡀⠀⣠⣾⡿⠋⢀⣤⡄⠙⠻⣿⠆⠀⠀⣠⣿⣿⣀⠀⠀⣿⣿⣿⡇⠀⢀⣨⣿⣿⡄⠀⠀⢴⣿⠟⠉⣠⣄⠈⠙⢿⣷⡀⠀⢀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀      version: $version
⠀⠈⠿⣶⡿⠏⠀⠀⠀⢻⣿⡄⠀⠈⠀⠀⣴⣿⣏⣹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣋⣻⣿⣆⠀⠈⠁⠀⣰⣿⡟⠀⠀⠈⠻⣿⡶⠏
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠛⠛⠀⠀⠀⢸⣿⠛⠛⠛⠛⠋⢹⣿⣿⣿⣿⡉⠛⠛⠛⠛⢻⣿⡇⠀⠀⠐⠛⠛
⠀⠀⠀⠀⠀⠀⠀⠀⣠⣶⠿⣿⣦⣄⠀⠸⣿⡀⠀⠀⠀⢀⣾⡿⠁⠘⣿⣧⠀⠀⠀⠀⣸⣿⠃⠀⣠⣶⡿⢿⣶⣄
⠀⠀⠀⠀⠀⠀⠀⢰⠏⠁⠀⠀⠙⢿⣷⣄⡈⠛⠒⠀⣠⣾⡿⠁⠀⠀⠘⢿⣷⣄⠀⠚⠋⢁⣴⣾⡿⠋⠀⠀⠈⠻⠆
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠻⠿⢿⡿⠿⠟⠋⠀⠀⠀⠀⠀⠀⠙⠻⠿⣿⠿⠿⠛⠁
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢤⣤⣦⣄⡀⠀⠀⠀⠀⢀⣠⣤⣤⠄
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠻⢿⣷⣦⣴⣾⡿⠛⠉
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉"
}

banner() {
  banner_logo
  lolcat $'\n 🐙 Powerful scan tool and parameter analyzer.'
  printf "
 🎯   Target                         〔${CBold}${CFGYellow}https://$target_domain/${CReset}〕
 🚪   Scan Port                      〔${CBold}${CFGGreen}true${CReset}〕
 🧰   Redirect                       〔${CBold}${CFGGreen}true${CReset}〕
 🕘   Started at                     〔%(%Y/%m/%d %H:%M:%S)T〕"
}

usage() {
  usage="  Usage: $basename -d DOMAIN [OPTIONS]

DESCRIPTION
  Reconnaissance tool's collection

OPTIONS
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

Example of use:
# $basename -d example.com -a off -n"
  printf "$usage\n${*:+\n$*\n}"
}

init() {
  local OPTIND OPTARG
  load_ansi_colors

  export target_domain=${target_domain#@(ht|f)tp?(s)://}

  [[ -z "$target_domain" ]] && { usage "$basename: ERROR: Invalid domain"; return 1; }
  export target_ip=$(nslookup "$target_domain"|grep -oP 'Address: \K.*([0-9]{1,3}\.){3}[0-9]{1,3}')

  export delay
  return 0
}

user_notification() {
  local summary body urgency \
    icon=$workdir/share/icons/logo-48x48.png
  [[ -z $XAUTHORITY ]] && return
  while [[ $1 ]]; do
    case $1 in
      -u|--urgency) urgency=$2; shift 2;;
      -s|--summary) summary=$2; shift 2;;
      -b|--body) body=$2; shift 2;;
    esac
  done
  notify-send -u ${urgency:-low} -i "$icon" "$summary" "$body"
}

run_tools() {
  local file speed list=()
  export logfile
  while [[ $1 ]]; do
    case $1 in
      -f|--logfile) file=$2; shift 2;;
      -s) speed=$2; shift 2;;
      *)  list+=("$1"); shift;;
    esac
  done
  for tool in "${list[@]}"; do
    [[ $anon_mode == 1 ]] && anonsurf change &> /dev/null
    IFS='|' read app depends cmd <<< ${tools[${tool,,}]}
    if type -t $depends > /dev/null; then
      printf "\n\n${CBold}${CFGCyan}[${CFGWhite}+${CFGCyan}] Starting scan in ${app}${CReset}\n"
      logfile="$file"
      if [[ -z "$file" ]]; then
        logfile="$logdir/${dtreport}${tool,,}.log";
        pagereports[${tool,,}]="$logfile"
      fi
      > $logfile
      interrupt_handler=1
      result=$(bash -c "$cmd" 2>>$logerr) | progressbar -s ${speed:-slow} -m "${tool^} $target_domain"
      interrupt_handler=0
      user_notification -s "$APP Reconnaissance" -b "Scanning ${tool^} completed"
      elapsedtime -p "${tool^}"
      sleep $delay
    fi
  done
}

run() {
  export logdir=$workdir/log/$target_domain
  export logerr="$workdir/${basename%.*}.err"
  mklogdir "$logdir"

  if form menu checklist; then
    clear

    banner

    # Tools for report
    run_tools nmap nmap-cvss
    [[ $anon_mode == 1 ]] && anonsurf start &> /dev/null
    run_tools mrx whatweb owasp crt ${selection,,}

    ##
    # Search and report subdomains
    if [[ $subdomains_scan_mode == 1 ]]; then
      printf "\n\n${CBold}${CFGCyan}»»»»»»»»»»»» Enabling brute force on subdirectories${CReset}\n"
      (
        while read target_domain; do
          [[ $target_domain ]] && run_tools -f "$logdir/${dtreport}${target_domain/:\/\//.}.log" -s slowest dirsearch
        done < "$logdir/${dtreport}httpx.log"
      )

      [[ $anon_mode == 1 ]] && anonsurf stop &> /dev/null
      (
        anon_mode=0
        while read target_domain; do
          [[ $target_domain ]] && run_tools -f "$logdir/${dtreport}${target_domain}nmap.log" fnmap
        done < "$logdir/${dtreport}mrx.log"
      )
    fi
    [[ $anon_mode == 1 ]] && anonsurf stop &> /dev/null
    aquatone -chrome-path /usr/bin/chromium -out "$logdir" 2>>$logerr >/dev/null < "$logdir/${dtreport}mrx.log"
    report

    user_notification -u critical -s "$APP Reconnaissance" -b "Recon of $target_domain completed"
    elapsedtime 'TOTAL Reconnaissance'
    return 0
  fi

  clear
}

main() {
  script=$(realpath $BASH_SOURCE)
  dirname=${script%/*}
  readonly basename=${0##*/}
  while [[ $1 ]]; do
    case $1 in
      -h|--help|help) usage; exit 0;;
      -V|--version) echo "$version"; exit 0;;
      -u|--update) update_mode=1; shift;;
      -d|--domain) target_domain=$2; shift 2;;
     -dL|--domain-list) domainfile=$2; shift 2;;
      -f|--fast-scan) dg_checklist_mode=0; shift;;
      -A|--agressive) dg_checklist_status=checked; shift;;
      -n|--no-subs) subdomains_scan_mode=0; shift;;
      --delay) delay=$2; shift 2;;
      -a|--anon) [[ ${2,,} == @(0|false|off) ]] && anon_mode=0; shift 2;;
      *) shift;;
    esac
  done
  if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
    printf '%s: ERROR: Need shell %s %s or greater.\n' "$basename" 'bash' '4.0' 1>&2
    exit 1
  fi
  if [[ 0 != $EUID ]]; then
    usage
    printf 'This script must be run as root!\nRun as:\n# %s\n' "$(realpath $0) $*"
    exit 1
  fi
  workdir=$dirname
  wordlistdir="$workdir/share/wordlists"
  inifile="$workdir/package.ini"
  required_packages='git dialog yad nmap httpx anonsurf assetfinder findomain-linux subfinder aquatone dirsearch anew waybackurls EmailHarvester emailfinder holehe'
  check_dependencies
  check_inifile
  check_environments

  SECONDS=0
  read_package_ini
  report_tools

  [[ $update_mode == 1 ]] && update_tools
  shopt -s extglob
  check_domain
  while read target_domain; do
    init || continue
    run
  done <<< "$domainslist"
}

declare -A tools
declare -A descriptions
declare -A pagereports
dg_checklist_mode=1
subdomains_scan_mode=1
anon_mode=1
delay=5
[[ $BASH_SOURCE == $0 ]] && main "$@"
