#!/usr/bin/env bash
# Description: Improved version based on Superbench
# Copyright (C) 2023 open@no1bench.com
# URL: https://www.no1bench.com
# Thanks: Superbench.sh <oooldking@gmail.com>

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
SKYBLUE='\033[0;36m'
PLAIN='\033[0m'

about() {
  echo ""
  echo " ========================================================= "
  echo " \                      No1Bench.sh                      / "
  echo " \           Improved version based on Superbench        / "
  echo " \                   v1.0.0 (2023/11/11)                 / "
  echo " \                 Created by No1Bench.com               / "
  echo " ========================================================= "
  echo ""
  echo " URL: https://www.no1bench.com"
  echo " Copyright (C) 2023 open@no1bench.com"
  echo ""
}

print_intro() {
  echo -e " No1Bench.sh -- https://www.no1bench.com\n" | tee -a $log
  echo -e " Mode  : \e${GREEN}%s\e${PLAIN}    Version : \e${GREEN}%s${PLAIN}\n" $mode_name 1.0.0 | tee -a $log
  echo -e " Usage : wget -qO- sh.no1bench.com | bash\n" | tee -a $log
}

cancel() {
  echo ""
  next
  echo " Abort ..."
  echo " Cleanup ..."
  cleanup
  echo " Done"
  exit
}

trap cancel SIGINT

benchinit() {
  if [ -f /etc/redhat-release ]; then
    release="centos"
  elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
  elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
  elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
  elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
  elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
  elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
  fi

  [[ $EUID -ne 0 ]] && echo -e "${RED}Error:${PLAIN} This script must be run as root!" && exit 1

  if [ ! -e '/usr/bin/python3' ]; then
    echo " Installing Python3 ..."
    if [ "${release}" == "centos" ]; then
      yum update
      yum -y install python3
    else
      apt-get update
      apt-get -y install python3 python3-pip
    fi

  fi

  if [ ! -e '/usr/bin/curl' ]; then
    echo " Installing Curl ..."
    if [ "${release}" == "centos" ]; then
      yum update
      yum -y install curl
    else
      apt-get update
      apt-get -y install curl
    fi
  fi

  if [ ! -e '/usr/bin/wget' ]; then
    echo " Installing Wget ..."
    if [ "${release}" == "centos" ]; then
      yum update
      yum -y install wget
    else
      apt-get update
      apt-get -y install wget
    fi
  fi

  if [ ! -e './speedtest-cli/speedtest' ]; then
    echo " Installing Speedtest-cli ..."
    wget -4 --no-check-certificate -qO speedtest.tgz https://cdn.jsdelivr.net/gh/oooldking/script@1.1.7/speedtest_cli/ookla-speedtest-1.0.0-$(uname -m)-linux.tgz
  fi
  mkdir -p speedtest-cli && tar zxvf speedtest.tgz -C ./speedtest-cli/ && chmod a+rx ./speedtest-cli/speedtest

  if [ ! -e 'tools.py' ]; then
    echo " Installing tools.py ..."
    wget -4 --no-check-certificate https://cdn.jsdelivr.net/gh/oooldking/script@1.1.7/tools.py
  fi
  chmod a+rx tools.py

  if [ ! -e 'fast_com.py' ]; then
    echo " Installing Fast.com-cli ..."
    wget -4 --no-check-certificate https://cdn.jsdelivr.net/gh/sanderjo/fast.com@master/fast_com.py
    wget -4 --no-check-certificate https://cdn.jsdelivr.net/gh/sanderjo/fast.com@master/fast_com_example_usage.py
  fi
  chmod a+rx fast_com.py
  chmod a+rx fast_com_example_usage.py

  sleep 5

  start=$(date +%s)
}

get_opsy() {
  [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
  [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
  [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

next() {
  printf "%-70s\n" "-" | sed 's/\s/-/g' | tee -a $log
}

speed_fast_com() {
  temp=$(python3 fast_com_example_usage.py 2>&1)
  is_down=$(echo "$temp" | grep 'Result')
  if [[ ${is_down} ]]; then
    temp1=$(echo "$temp" | awk -F ':' '/Result/{print $2}')
    temp2=$(echo "$temp1" | awk -F ' ' '/Mbps/{print $1}')
    local REDownload="$temp2 Mbit/s"
    local reupload="0.00 Mbit/s"
    local relatency="-"
    local nodeName="Fast.com"
    local loss="0%"

    printf "${YELLOW}%-20s${GREEN}%-16s${RED}%-16s${SKYBLUE}%-16s${RED}%-16s${PLAIN}\n" " ${nodeName}" "${reupload}" "${REDownload}" "${relatency}" "${loss}" | tee -a $log
  else
    local cerror="ERROR"
  fi
  #rm -rf fast_com_example_usage.py
  #rm -rf fast_com.py
}

speed_test() {
  if [[ $1 == '' ]]; then
    speedtest-cli/speedtest -p no --accept-license >$speedLog 2>&1
    is_upload=$(cat $speedLog | grep 'Upload')
    result_speed=$(cat $speedLog | awk -F ' ' '/Result/{print $3}')
    if [[ ${is_upload} ]]; then
      local REDownload=$(cat $speedLog | awk -F ' ' '/Download/{print $3}')
      local reupload=$(cat $speedLog | awk -F ' ' '/Upload/{print $3}')
      local relatency=$(cat $speedLog | awk -F ' ' '/Latency/{print $2}')
      local loss=$(cat $speedLog | awk -F ' ' '/Packet Loss/{print $3}')

      temp=$(echo "$relatency" | awk -F '.' '{print $1}')
      if [[ ${temp} -gt 50 ]]; then
        relatency="(*)"${relatency}
      fi
      local nodeName=$2

      temp=$(echo "${REDownload}" | awk -F ' ' '{print $1}')
      if [[ $(awk -v num1=${temp} -v num2=0 'BEGIN{print(num1>num2)?"1":"0"}') -eq 1 ]]; then
        printf "${YELLOW}%-20s${GREEN}%-16s${RED}%-16s${SKYBLUE}%-16s${RED}%-16s${PLAIN}\n" " ${nodeName}" "${reupload} Mbit/s" "${REDownload} Mbit/s" "${relatency} ms" "${loss}" | tee -a $log
      fi
    else
      local cerror="ERROR"
    fi
  else
    speedtest-cli/speedtest -p no -s $1 --accept-license >$speedLog 2>&1
    is_upload=$(cat $speedLog | grep 'Upload')
    if [[ ${is_upload} ]]; then
      local REDownload=$(cat $speedLog | awk -F ' ' '/Download/{print $3}')
      local reupload=$(cat $speedLog | awk -F ' ' '/Upload/{print $3}')
      local relatency=$(cat $speedLog | awk -F ' ' '/Latency/{print $2}')
      local loss=$(cat $speedLog | awk -F ' ' '/Packet Loss/{print $3}')
      local nodeName=$2

      temp=$(echo "${REDownload}" | awk -F ' ' '{print $1}')
      if [[ $(awk -v num1=${temp} -v num2=0 'BEGIN{print(num1>num2)?"1":"0"}') -eq 1 ]]; then
        printf "${YELLOW}%-20s${GREEN}%-16s${RED}%-16s${SKYBLUE}%-16s${RED}%-16s${PLAIN}\n" " ${nodeName}" "${reupload} Mbit/s" "${REDownload} Mbit/s" "${relatency} ms" "${loss}" | tee -a $log
      fi
    else
      local cerror="ERROR"
    fi
  fi
}

print_speedtest_chinatelecom(){
  next
  printf "%-20s%-18s%-18s%-18s%-18s\n" "电信节点" "上传" "下载" "延迟" "丢包率" | tee -a $log
  next
  # speed_fast_com
  speed_test '35722' '天津电信'
  speed_test '34115' '天津电信5G'
  speed_test '5317' '南京电信5G'
  speed_test '36663' '镇江电信5G'
  speed_test '5396' '苏州电信5G'
  speed_test '26352' '南京电信5G'
  speed_test '17145' '合肥电信5G'
  speed_test '28225' '长沙电信5G'
  speed_test '59387' '宁波电信'
  speed_test '59386' '杭州电信'
  speed_test '3973' '兰州电信'  
  speed_test '29071' '成都电信'
  #rm -rf speedtest*
}

print_speedtest_chinaunicom(){
  next
  printf "%-20s%-18s%-18s%-18s%-18s\n" "联通节点" "上传" "下载" "延迟" "丢包率" | tee -a $log
  next
  speed_fast_com
  speed_test '4870' '长沙联通5G'
  speed_test '43752' '北京联通'
  speed_test '37235' '沈阳联通'
  speed_test '36646' '郑州联通'
  speed_test '24447' '上海联通'
  speed_test '45170' '无锡联通'
  speed_test '56354' '福州联通'
  speed_test '54432' '海口联通'
  speed_test '37695' '香港联通'
  #rm -rf speedtest*
}

print_speedtest_chinamobile() {
  next
  printf "%-20s%-18s%-18s%-18s%-18s\n" "移动节点" "上传" "下载" "延迟" "丢包率" | tee -a $log
  next
  speed_fast_com
  speed_test '25858' '北京移动5G'
  speed_test '29105' '西安移动5G'
  speed_test '54312' '杭州移动5G'
  speed_test '60794' '广州移动5G'
  speed_test '16145' '兰州移动'
  speed_test '4575' '成都移动'
  speed_test '58591' '深圳移动'
  speed_test '32155' '香港移动'
  speed_test '37639' '香港移动'
  #rm -rf speedtest*
}

print_speedtest_other() {
  next
  printf "%-20s%-18s%-18s%-18s%-18s\n" "其他节点" "上传" "下载" "延迟" "丢包率" | tee -a $log
  next
  speed_fast_com
  speed_test '30852' '昆山杜克大学'
  speed_test '35527' '成都广电'
  speed_test '5530' '重庆广电'
  speed_test '1536' '香港STC'
  speed_test '60273' '香港LINKCHINA'
  #rm -rf speedtest*
}

print_speedtest_fast() {
  next
  printf "%-20s%-18s%-18s%-18s%-18s\n" "节点" "上传" "下载" "延迟" "丢包率" | tee -a $log
  next
  speed_test '' 'Speedtest.net'
  speed_fast_com
  speed_test '5317' '南京电信5G'
  speed_test '4870' '长沙联通5G'
  speed_test '25858' '北京移动5G'
  speed_test '60273' '香港LINKCHINA'
  #rm -rf speedtest*
}

io_test() {
  (LANG=C dd if=/dev/zero of=test_file_$$ bs=512K count=$1 conv=fdatasync && rm -f test_file_$$) 2>&1 | awk -F, '{io=$NF} END { print io}' | sed 's/^[ \t]*//;s/[ \t]*$//'
}

calc_disk() {
  local total_size=0
  local array=$@
  for size in ${array[@]}; do
    [ "${size}" == "0" ] && size_t=0 || size_t=$(echo ${size:0:${#size}-1})
    [ "$(echo ${size:(-1)})" == "K" ] && size=0
    [ "$(echo ${size:(-1)})" == "M" ] && size=$(awk 'BEGIN{printf "%.1f", '$size_t' / 1024}')
    [ "$(echo ${size:(-1)})" == "T" ] && size=$(awk 'BEGIN{printf "%.1f", '$size_t' * 1024}')
    [ "$(echo ${size:(-1)})" == "G" ] && size=${size_t}
    total_size=$(awk 'BEGIN{printf "%.1f", '$total_size' + '$size'}')
  done
  echo ${total_size}
}

power_time() {

  result=$(smartctl -a $(result=$(cat /proc/mounts) && echo $(echo "$result" | awk '/data=ordered/{print $1}') | awk '{print $1}') 2>&1) && power_time=$(echo "$result" | awk '/Power_On/{print $10}') && echo "$power_time"
}

install_smart() {
  if [ ! -e '/usr/sbin/smartctl' ]; then
    echo "Installing Smartctl ..."
    if [ "${release}" == "centos" ]; then
      yum update
      yum -y install smartmontools
    else
      apt-get update
      apt-get -y install smartmontools
    fi
  fi
}

ip_info4() {
  ip_date=$(curl -4 -s http://ip-api.com/json)
  echo $ip_date >ip_json.json
  isp=$(python3 tools.py geoip isp)
  as_tmp=$(python3 tools.py geoip as)
  asn=$(echo $as_tmp | awk -F ' ' '{print $1}')
  org=$(python3 tools.py geoip org)
  if [ -z "ip_date" ]; then
    echo $ip_date
    echo "hala"
    country=$(python3 tools.py ipip country_name)
    city=$(python3 tools.py ipip city)
    countryCode=$(python3 tools.py ipip country_code)
    region=$(python3 tools.py ipip province)
  else
    country=$(python3 tools.py geoip country)
    city=$(python3 tools.py geoip city)
    countryCode=$(python3 tools.py geoip countryCode)
    region=$(python3 tools.py geoip regionName)
  fi
  if [ -z "$city" ]; then
    city=${region}
  fi

  echo -e " ASN & ISP            : ${SKYBLUE}$asn, $isp${PLAIN}" | tee -a $log
  echo -e " Organization         : ${YELLOW}$org${PLAIN}" | tee -a $log
  echo -e " Location             : ${SKYBLUE}$city, ${YELLOW}$country / $countryCode${PLAIN}" | tee -a $log
  echo -e " Region               : ${SKYBLUE}$region${PLAIN}" | tee -a $log

  #rm -rf tools.py
  #rm -rf ip_json.json
}

virt_check() {
  if hash ifconfig 2>/dev/null; then
    eth=$(ifconfig)
  fi

  virtualx=$(dmesg) 2>/dev/null

  if [ $(which dmidecode) ]; then
    sys_manu=$(dmidecode -s system-manufacturer) 2>/dev/null
    sys_product=$(dmidecode -s system-product-name) 2>/dev/null
    sys_ver=$(dmidecode -s system-version) 2>/dev/null
  else
    sys_manu=""
    sys_product=""
    sys_ver=""
  fi

  if grep docker /proc/1/cgroup -qa; then
    virtual="Docker"
  elif grep lxc /proc/1/cgroup -qa; then
    virtual="Lxc"
  elif grep -qa container=lxc /proc/1/environ; then
    virtual="Lxc"
  elif [[ -f /proc/user_beancounters ]]; then
    virtual="OpenVZ"
  elif [[ "$virtualx" == *kvm-clock* ]]; then
    virtual="KVM"
  elif [[ "$cname" == *KVM* ]]; then
    virtual="KVM"
  elif [[ "$cname" == *QEMU* ]]; then
    virtual="KVM"
  elif [[ "$virtualx" == *"VMware Virtual Platform"* ]]; then
    virtual="VMware"
  elif [[ "$virtualx" == *"Parallels Software International"* ]]; then
    virtual="Parallels"
  elif [[ "$virtualx" == *VirtualBox* ]]; then
    virtual="VirtualBox"
  elif [[ -e /proc/xen ]]; then
    virtual="Xen"
  elif [[ "$sys_manu" == *"Microsoft Corporation"* ]]; then
    if [[ "$sys_product" == *"Virtual Machine"* ]]; then
      if [[ "$sys_ver" == *"7.0"* || "$sys_ver" == *"Hyper-V" ]]; then
        virtual="Hyper-V"
      else
        virtual="Microsoft Virtual Machine"
      fi
    fi
  else
    virtual="Dedicated"
  fi
}

power_time_check() {
  echo -ne " Power time of disk   : "
  install_smart
  ptime=$(power_time)
  echo -e "${SKYBLUE}$ptime Hours${PLAIN}"
}

freedisk() {
  freespace=$(df -m . | awk 'NR==2 {print $4}')
  if [[ $freespace == "" ]]; then
    $freespace=$(df -m . | awk 'NR==3 {print $3}')
  fi
  if [[ $freespace -gt 512 ]]; then
    printf "%s" $((512))
  elif [[ $freespace -gt 256 ]]; then
    printf "%s" $((256))
  elif [[ $freespace -gt 128 ]]; then
    printf "%s" $((128))
  elif [[ $freespace -gt 64 ]]; then
    printf "%s" $((64))
  else
    printf "1"
  fi
}

print_io() {
  if [[ $1 == "fast" ]]; then
    writemb=$((128 * 2))
  else
    writemb=$(freedisk)
  fi

  echo -e "writemb:$writemb" | tee -a $log

  writemb_size="$((writemb / 2))MB"
  if [[ $writemb_size == "1024MB" ]]; then
    writemb_size="1.0GB"
  fi

  if [[ $writemb != "1" ]]; then
    echo -n " I/O Speed( $writemb_size )   : " | tee -a $log
    io1=$(io_test $writemb)
    echo -e "${YELLOW}$io1${PLAIN}" | tee -a $log
    echo -n " I/O Speed( $writemb_size )   : " | tee -a $log
    io2=$(io_test $writemb)
    echo -e "${YELLOW}$io2${PLAIN}" | tee -a $log
    echo -n " I/O Speed( $writemb_size )   : " | tee -a $log
    io3=$(io_test $writemb)
    echo -e "${YELLOW}$io3${PLAIN}" | tee -a $log
    ioraw1=$(echo $io1 | awk 'NR==1 {print $1}')
    [ "$(echo $io1 | awk 'NR==1 {print $2}')" == "GB/s" ] && ioraw1=$(awk 'BEGIN{print '$ioraw1' * 1024}')
    ioraw2=$(echo $io2 | awk 'NR==1 {print $1}')
    [ "$(echo $io2 | awk 'NR==1 {print $2}')" == "GB/s" ] && ioraw2=$(awk 'BEGIN{print '$ioraw2' * 1024}')
    ioraw3=$(echo $io3 | awk 'NR==1 {print $1}')
    [ "$(echo $io3 | awk 'NR==1 {print $2}')" == "GB/s" ] && ioraw3=$(awk 'BEGIN{print '$ioraw3' * 1024}')
    ioall=$(awk 'BEGIN{print '$ioraw1' + '$ioraw2' + '$ioraw3'}')
    ioavg=$(awk 'BEGIN{printf "%.1f", '$ioall' / 3}')
    echo -e " Average I/O Speed    : ${YELLOW}$ioavg MB/s${PLAIN}" | tee -a $log
  else
    echo -e " ${RED}Not enough space!${PLAIN}"
  fi
}

print_system_info() {
  echo -e " CPU Model            : ${SKYBLUE}$cname${PLAIN}" | tee -a "$log"
  echo -e " CPU Cores            : ${YELLOW}$cores Cores ${SKYBLUE}$freq MHz $arch${PLAIN}" | tee -a "$log"
  echo -e " CPU Cache            : ${SKYBLUE}$corescache ${PLAIN}" | tee -a "$log"
  echo -e " OS                   : ${SKYBLUE}$opsy ($lbit Bit) ${YELLOW}$virtual${PLAIN}" | tee -a "$log"
  echo -e " Kernel               : ${SKYBLUE}$kern${PLAIN}" | tee -a "$log"
  echo -e " Total Space          : ${SKYBLUE}$disk_used_size GB / ${YELLOW}$disk_total_size GB ${PLAIN}" | tee -a "$log"
  echo -e " Total RAM            : ${SKYBLUE}$uram MB / ${YELLOW}$tram MB ${SKYBLUE}($bram MB Buff)${PLAIN}" | tee -a "$log"
  echo -e " Total SWAP           : ${SKYBLUE}$uswap MB / $swap MB${PLAIN}" | tee -a "$log"
  echo -e " Uptime               : ${SKYBLUE}$up${PLAIN}" | tee -a "$log"
  echo -e " Load Average         : ${SKYBLUE}$load${PLAIN}" | tee -a "$log"
  echo -e " TCP CC               : ${YELLOW}$tcpctrl${PLAIN}" | tee -a "$log"
}

print_end_time() {
  end=$(date +%s)
  # shellcheck disable=SC2004
  time=$(($end - $start))
  if [[ $time -gt 60 ]]; then
    # shellcheck disable=SC2003
    min=$(expr $time / 60)
    # shellcheck disable=SC2003
    sec=$(expr $time % 60)
    echo -ne " Finished in  : ${min} min ${sec} sec" | tee -a $log
  else
    echo -ne " Finished in  : ${time} sec" | tee -a $log
  fi

  printf '\n' | tee -a $log

  bj_time=$(curl -s http://cgi.im.qq.com/cgi-bin/cgi_svrtime)

  # shellcheck disable=SC2143
  if [[ $(echo $bj_time | grep "html") ]]; then
    bj_time=$(date -u +%Y-%m-%d" "%H:%M:%S -d '+8 hours')
  fi
  echo " Timestamp    : $bj_time GMT+8" | tee -a $log
  echo " Results      : $log"
}

get_system_info() {
  cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
  cores=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
  freq=$(awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
  corescache=$(awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
  tram=$(free -m | awk '/Mem/ {print $2}')
  uram=$(free -m | awk '/Mem/ {print $3}')
  bram=$(free -m | awk '/Mem/ {print $6}')
  swap=$(free -m | awk '/Swap/ {print $2}')
  uswap=$(free -m | awk '/Swap/ {print $3}')
  up=$(awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days %d hour %d min\n",a,b,c)}' /proc/uptime)
  load=$(w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
  opsy=$(get_opsy)
  arch=$(uname -m)
  lbit=$(getconf LONG_BIT)
  kern=$(uname -r)

  disk_size1=$(LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $2}')
  disk_size2=$(LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $3}')
  # shellcheck disable=SC2068
  disk_total_size=$(calc_disk ${disk_size1[@]})
  # shellcheck disable=SC2068
  disk_used_size=$(calc_disk ${disk_size2[@]})

  tcpctrl=$(sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}')

  virt_check
}

sharetest() {
  echo " Share result:" | tee -a $log
  echo " · $result_speed" | tee -a $log
  log_preupload
  case $1 in
  'ubuntu')
    share_link="https://paste.ubuntu.com"$(curl -v --data-urlencode "content@$log_up" -d "poster=superbench.sh" -d "syntax=text" "https://paste.ubuntu.com" 2>&1 |
      grep "Location" | awk '{print $3}')
    ;;
  'haste')
    share_link=$(curl -X POST -s -d "$(cat $log)" https://hastebin.com/documents | awk -F '"' '{print "https://hastebin.com/"$4}')
    ;;
  'clbin')
    share_link=$(curl -sF 'clbin=<-' https://clbin.com <$log)
    ;;
  'ptpb')
    share_link=$(curl -sF c=@- https://ptpb.pw/?u=1 <$log)
    ;;
  esac

  echo " · $share_link" | tee -a $log
  next
  echo ""
  rm -f $log_up

}

log_preupload() {
  log_up="$HOME/superbench_upload.log"
  true >$log_up
  $(cat superbench.log 2>&1 | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" >$log_up)
}

cleanup() {
  rm -f test_file_*
  #rm -rf speedtest*
  #rm -f fast_com*
  #rm -f tools.py
  #rm -f ip_json.json
  echo ""
}

bench_all() {
  mode_name="Standard"
  about
  benchinit
  clear
  next
  print_intro
  next
  get_system_info
  print_system_info
  ip_info4
  next
  # print_io
  print_speedtest_chinatelecom
  print_speedtest_chinaunicom
  print_speedtest_chinamobile
  print_speedtest_other
  next
  print_end_time
  next
  cleanup
  sharetest ubuntu
}

fast_bench() {
  mode_name="Fast"
  about
  benchinit
  clear
  next
  print_intro
  next
  get_system_info
  print_system_info
  ip_info4
  next
  # print_io fast
  print_speedtest_fast
  next
  print_end_time
  next
  cleanup
}

log="./superbench.log"
true >$log
speedLog="./speedtest.log"
true >$speedLog

case $1 in
'info' | '-i' | '--i' | '-info' | '--info')
  about
  sleep 3
  next
  get_system_info
  print_system_info
  next
  ;;
'version' | '-v' | '--v' | '-version' | '--version')
  next
  about
  next
  ;;
'io' | '-io' | '--io' | '-drivespeed' | '--drivespeed')
  next
  print_io
  next
  ;;
'speed' | '-speed' | '--speed' | '-speedtest' | '--speedtest' | '-speedcheck' | '--speedcheck')
  about
  benchinit
  next
  print_speedtest
  next
  cleanup
  ;;
'ip' | '-ip' | '--ip' | 'geoip' | '-geoip' | '--geoip')
  about
  benchinit
  next
  ip_info4
  next
  cleanup
  ;;
'bench' | '-a' | '--a' | '-all' | '--all' | '-bench' | '--bench')
  bench_all
  ;;
'about' | '-about' | '--about')
  about
  ;;
'fast' | '-f' | '--f' | '-fast' | '--fast')
  fast_bench
  ;;
'share' | '-s' | '--s' | '-share' | '--share')
  bench_all
  is_share="share"
  if [[ $2 == "" ]]; then
    sharetest ubuntu
  else
    sharetest $2
  fi
  ;;
'debug' | '-d' | '--d' | '-debug' | '--debug')
  get_ip_whois_org_name
  ;;
*)
  bench_all
  ;;
esac

if [[ ! $is_share == "share" ]]; then
  case $2 in
  'share' | '-s' | '--s' | '-share' | '--share')
    if [[ $3 == '' ]]; then
      sharetest ubuntu
    else
      sharetest $3
    fi
    ;;
  esac
fi
