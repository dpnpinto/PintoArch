#!/usr/bin/env bash
#github-action genshdoc
#-------------------------------------------------------------------------
#  ____  _       _      _             _
# |  _ \(_)_ __ | |_   / \   _ __ ___| |__
# | |_) | | '_ \| __| / _ \ | '__/ __| '_ \
# |  __/| | | | | |_ / ___ \| | | (__| | | |
# |_|   |_|_| |_|\__/_/   \_|_|  \___|_| |_|
#
#-------------------------------------------------------------------------
# @file Startup
# @brief This script will setup my inicial prefrences like disk, file system, timezone, keyboard layout, user name, ask for password, etc.
# @stdout Output routed to startup.log
# @stderror Output routed to startup.log

# @setting-header General Settings
# @setting CONFIG_FILE string[$CONFIGS_DIR/setup.conf] Location of setup.conf to be used by set_option and all subsequent scripts. 
CONFIG_FILE=$CONFIGS_DIR/setup.conf
if [ ! -f $CONFIG_FILE ]; then # check if file exists
    touch -f $CONFIG_FILE # create file if not exists
fi

# @description set options in setup.conf
# @arg $1 string Configuration variable.
# @arg $2 string Configuration value.
set_option() {
    if grep -Eq "^${1}.*" $CONFIG_FILE; then # check if option exists
        sed -i -e "/^${1}.*/d" $CONFIG_FILE # delete option if exists
    fi
    echo "${1}=${2}" >>$CONFIG_FILE # add option
}

set_password() {
    read -rs -p "Qual a palavra passe (password): " PASSWORD1
    echo -ne "\n"
    read -rs -p "Escreva novamente a palavra passe: " PASSWORD2
    echo -ne "\n"
    if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
        set_option "$1" "$PASSWORD1"
    else
        echo -ne "ERROR! Palavras passe não são iguais. \n"
        set_password
    fi
}

root_check() {
    if [[ "$(id -u)" != "0" ]]; then
        echo -ne "ERRO! Este script tem de ser executado com o utilizador 'root' !\n"
        exit 0
    fi
}

docker_check() {
    if awk -F/ '$2 == "docker"' /proc/self/cgroup | read -r; then
        echo -ne "ERRO! Esta instalação não está preparada para embiente em Containers !\n"
        exit 0
    elif [[ -f /.dockerenv ]]; then
        echo -ne "ERRO! Esta instalação não está preparada para embiente em Containers !\n"
        exit 0
    fi
}

arch_check() {
    if [[ ! -e /etc/arch-release ]]; then
        echo -ne "ERRO! Este script de instalação é para o Arch Linux !\n"
        exit 0
    fi
}

pacman_check() {
    if [[ -f /var/lib/pacman/db.lck ]]; then
        echo "ERRO! O gestor de pacotes Pacman está bloqueado !\n"
        echo -ne "Se não consegue correr, remover o ficheiro /var/lib/pacman/db.lck. !\n"
        exit 0
    fi
}

# verify if we have conditions to run the scripts
background_checks() { 
    root_check
    arch_check
    pacman_check
    docker_check
}

# Renders a text based list of options that can be selected by the
# user using up, down and enter keys and returns the chosen option.
#
#   Arguments   : list of options, maximum of 256
#                 "opt1" "opt2" ...
#   Return value: selected index (0 for opt1, 1 for opt2 ...)
select_option() {

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "$2   $1 "; }
    print_selected()   { printf "$2  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    get_cursor_col()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${COL#*[}; }
    key_input()         {
                        local key
                        IFS= read -rsn1 key 2>/dev/null >&2
                        if [[ $key = ""      ]]; then echo enter; fi;
                        if [[ $key = $'\x20' ]]; then echo space; fi;
                        if [[ $key = "k" ]]; then echo up; fi;
                        if [[ $key = "j" ]]; then echo down; fi;
                        if [[ $key = "h" ]]; then echo left; fi;
                        if [[ $key = "l" ]]; then echo right; fi;
                        if [[ $key = "a" ]]; then echo all; fi;
                        if [[ $key = "n" ]]; then echo none; fi;
                        if [[ $key = $'\x1b' ]]; then
                            read -rsn2 key
                            if [[ $key = [A || $key = k ]]; then echo up;    fi;
                            if [[ $key = [B || $key = j ]]; then echo down;  fi;
                            if [[ $key = [C || $key = l ]]; then echo right;  fi;
                            if [[ $key = [D || $key = h ]]; then echo left;  fi;
                        fi 
    }
    print_options_multicol() {
        # print options by overwriting the last lines
        local curr_col=$1
        local curr_row=$2
        local curr_idx=0

        local idx=0
        local row=0
        local col=0
        
        curr_idx=$(( $curr_col + $curr_row * $colmax ))
        
        for option in "${options[@]}"; do

            row=$(( $idx/$colmax ))
            col=$(( $idx - $row * $colmax ))

            cursor_to $(( $startrow + $row + 1)) $(( $offset * $col + 1))
            if [ $idx -eq $curr_idx ]; then
                print_selected "$option"
            else
                print_option "$option"
            fi
            ((idx++))
        done
    }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local return_value=$1
    local lastrow=`get_cursor_row`
    local lastcol=`get_cursor_col`
    local startrow=$(($lastrow - $#))
    local startcol=1
    local lines=$( tput lines )
    local cols=$( tput cols ) 
    local colmax=$2
    local offset=$(( $cols / $colmax ))

    local size=$4
    shift 4

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local active_row=0
    local active_col=0
    while true; do
        print_options_multicol $active_col $active_row 
        # user key control
        case `key_input` in
            enter)  break;;
            up)     ((active_row--));
                    if [ $active_row -lt 0 ]; then active_row=0; fi;;
            down)   ((active_row++));
                    if [ $active_row -ge $(( ${#options[@]} / $colmax ))  ]; then active_row=$(( ${#options[@]} / $colmax )); fi;;
            left)     ((active_col=$active_col - 1));
                    if [ $active_col -lt 0 ]; then active_col=0; fi;;
            right)     ((active_col=$active_col + 1));
                    if [ $active_col -ge $colmax ]; then active_col=$(( $colmax - 1 )) ; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $(( $active_col + $active_row * $colmax ))
}
# @description Displays ArchTitus logo
# @noargs
logo () {
# This will be shown on every set as user is progressing
echo -ne "
-------------------------------------------------------------------------
    ____  _       _      _             _
   |  _ \(_)_ __ | |_   / \   _ __ ___| |__
   | |_) | | '_ \| __| / _ \ | '__/ __| '_ \ NOVO
   |  __/| | | | | |_ / ___ \| | | (__| | | |
   |_|   |_|_| |_|\__/_/   \_|_|  \___|_| |_|

-------------------------------------------------------------------------
             Seleciona as definições para configuração              
-------------------------------------------------------------------------
"
}
# @description This function will handle file systems. At this movement we are handling only
# btrfs and ext4. Others will be added in future.
filesystem () {
echo -ne "
Seleciona o formato sistema de ficheiros para o boot e a root
"
options=("btrfs" "ext4" "luks" "exit")
select_option $? 1 "${options[@]}"

case $? in
0) set_option FS btrfs;;
1) set_option FS ext4;;
2) 
    set_password "LUKS_PASSWORD"
    set_option FS luks
    ;;
3) exit ;;
*) echo "Opção errada, seleciona de novo"; filesystem;;
esac
}
# @description Detects and sets timezone. 
timezone () {
# Added this from arch wiki https://wiki.archlinux.org/title/System_time
time_zone="$(curl --fail https://ipapi.co/timezone)"
#time_zone="$(curl ipapi.co/timezone)"
echo -ne "
O sistema detetou a sua timezone como '$time_zone' \n"
echo -ne "Está correto?
" 
options=("Sim" "Não")
select_option $? 1 "${options[@]}"

case ${options[$?]} in
    s|S|sim|Sim|SIM)
    echo "${time_zone} colocado como a sua timezone"
    set_option TIMEZONE $time_zone;;
    n|N|no|NO|No)
    echo "Por favor coloca a tua timezone exemplo Atlantic/Azores :" 
    read new_timezone
    echo "${new_timezone} colocado como a sua timezone"
    set_option TIMEZONE $new_timezone;;
    *) echo "Opção errada. Tente novamente:";timezone;;
esac
}
# @description Set user's keyboard mapping. 
keymap () {
echo -ne "
Seleciona o layout do teclado desta lista:"
# These are default key maps as presented in official arch repo archinstall
options=(us by ca cf cz de dk es et fa fi fr gr hu il it lt lv mk nl no pl pt ro ru sg ua uk)

select_option $? 4 "${options[@]}"
keymap=${options[$?]}

echo -ne "O layout do seu teclado é: ${keymap} \n"
set_option KEYMAP $keymap
}

# @description Choose whether drive is SSD or not.
drivessd () {
echo -ne "
O disco é um ssd? sim/não:
"

options=("Sim" "Não")
select_option $? 1 "${options[@]}"

case ${options[$?]} in
    s|S|sim|Sim|SIM)
    set_option MOUNT_OPTIONS "noatime,compress=zstd,ssd,commit=120";;
    n|N|não|NÃO|Não)
    set_option MOUNT_OPTIONS "noatime,compress=zstd,commit=120";;
    *) echo "Opção errada. Tente novamente";drivessd;;
esac
}

# @description Disk selection for drive to be used with installation.
diskpart () {
echo -ne "
------------------------------------------------------------------------
    TODA A INFORMÇÂO DO DISCO VAI SER APAGADA E FORMATADA
    Tenha toda a certeza do que está a fazer porque depois de
    formatar o seu disco não há forma de recuperr a sua informação
------------------------------------------------------------------------

"

PS3='
Seleciona o disco que rpetende fazer a instalação: '
options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

select_option $? 1 "${options[@]}"
disk=${options[$?]%|*}

echo -e "\n${disk%|*} selecionado\n"
    set_option DISK ${disk%|*}
# Is the disk a SSD
drivessd
}

# @description Gather username and password to be used for installation. 
userinfo () {
read -p "Qual o nome para o seu utilizador (username): " username
set_option USERNAME ${username,,} # convert to lower case as in issue #109 
set_password "PASSWORD"
read -rep "Qual o nome para o seu equipamento (hostname): " nameofmachine
set_option NAME_OF_MACHINE $nameofmachine
}

# @description Choose AUR helper. 
aurhelper () {
  # Let the user choose AUR helper from predefined list
  echo -ne "Please enter your desired AUR helper:\n"
  options=(paru yay picaur aura trizen pacaur none)
  select_option $? 4 "${options[@]}"
  aur_helper=${options[$?]}
  set_option AUR_HELPER $aur_helper
}

# @description Choose Desktop Environment
desktopenv () {
  # Let the user choose Desktop Enviroment from predefined list
  echo -ne "Por favor seleciona o ambiente de trabalho pretendido:\n"
  options=( `for f in pkg-files/*.txt; do echo "$f" | sed -r "s/.+\/(.+)\..+/\1/;/pkgs/d"; done` )
  select_option $? 4 "${options[@]}"
  desktop_env=${options[$?]}
  set_option DESKTOP_ENV $desktop_env
}

# @description Choose whether to do full or minimal installation. 
installtype () {
  echo -ne "Seleciona o tipo de instalação pretendida :\n\n
  Total: Instala todos os componnetes para o ambiente de desktop, com aplicações e temas necessários\n
  Minima: Instala apenas as aplicações necessárias para o arranque do sistema\n"
  options=(TOTAL MINIMA)
  select_option $? 4 "${options[@]}"
  install_type=${options[$?]}
  set_option INSTALL_TYPE $install_type
}

# Startig each step of instalation
background_checks # verify conditions
clear # clear screen
logo # Show my logo ;)
userinfo # lets set the user info
clear # clear screen
logo # Show my logo again ;)
desktopenv
# Set fixed options that installation uses if user choses server installation
set_option INSTALL_TYPE MINIMAL
set_option AUR_HELPER NONE
if [[ ! $desktop_env == server ]]; then
 clear
 logo
#  aurhelper
#  clear
#  logo
# Install the type of system that you want
 installtype
fi
clear
logo
# Chose disk to make partitions
diskpart
clear
logo
# Chose filesyetm to format disk
filesystem
clear
logo
# chose timezone
timezone
clear
logo
# Chose keymap
keymap
