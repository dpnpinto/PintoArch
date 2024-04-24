#!/usr/bin/env bash
# github-action genshdoc
#
# @file User
# @brief User customizations and AUR package installation.

counter() {
echo -ne "
-------------------------------------------------------------------------
    ____  _       _      _             _
   |  _ \(_)_ __ | |_   / \   _ __ ___| |__
   | |_) | | '_ \| __| / _ \ | '__/ __| '_ \ NOVO
   |  __/| | | | | |_ / ___ \| | | (__| | | |
   |_|   |_|_| |_|\__/_/   \_|_|  \___|_| |_|

"
}

clear
counter
echo -ne "
-------------------------------------------------------------------------
               Instalação das ferramentes de UI do Arch Linux
-------------------------------------------------------------------------
"
source $HOME/PintArch/configs/setup.conf

cd ~

sed -n '/'$INSTALL_TYPE'/q;p' ~/PintArch/pkg-files/${DESKTOP_ENV}.txt | while read line
do
  if [[ ${line} == '--END OF MINIMA INSTALL--' ]]
  then
    # If selected installation type is FULL, skip the --END OF THE MINIMAL INSTALLATION-- line
    continue
  fi
  echo "A Instalar: ${line}"
  sudo pacman -S --noconfirm --needed ${line}
done

# if you need aur I don't
if [[ ! $AUR_HELPER == none ]]; then
  cd ~
  git clone "https://aur.archlinux.org/$AUR_HELPER.git"
  cd ~/$AUR_HELPER
  makepkg -si --noconfirm
  # sed $INSTALL_TYPE is using install type to check for MINIMAL installation, if it's true, stop
  # stop the script and move on, not installing any more packages below that line
  sed -n '/'$INSTALL_TYPE'/q;p' ~/ArchTitus/pkg-files/aur-pkgs.txt | while read line
  do
    if [[ ${line} == '--END OF MINIMAL INSTALL--' ]]; then
      # If selected installation type is FULL, skip the --END OF THE MINIMAL INSTALLATION-- line
      continue
    fi
    echo "INSTALLING: ${line}"
    $AUR_HELPER -S --noconfirm --needed ${line}
  done
fi

export PATH=$PATH:~/.local/bin

echo $DESKTOP_ENV
echo $DESKTOP_ENV
# Lets install My DWM
if [[ $DESKTOP_ENV == "DWM" ]]; then
   # to my dwm full install and startup
  clear
  counter
  echo -ne "
  -------------------------------------------------------------------------
                    Vamos instalar o DWM e restante software
  -------------------------------------------------------------------------
  "
  sudo pacman --noconfirm -S xorg xorg-xinit dmenu
  echo "Clone Pinto Stuff"
  git clone https://github.com/dpnpinto/PintoDWM /home/$USERNAME/.config/PintoDWM
  git clone https://github.com/dpnpinto/PintoST /home/$USERNAME/.config/PintoST
  git clone https://github.com/dpnpinto/PintoDWMBLocks /home/$USERNAME/.config/PintoDWMBlocks
  cd /home/$USERNAME/.config/PintoDWM
  sudo make install
  cd /home/$USERNAME/.config/PintoST
  sudo make install
  cd /home/$USERNAME/.config/PintoDWMBlocks
  sudo make install
  cp -r /home/$USERNAME/PintArch/configs/start_confs/.*  /home/$USERNAME/ # starting stuff
  mkdir /home/$USERNAME/.config/scripts # Scripts dir
  cp -r /home/$USERNAME/.config/PintoDWMBlocks/scripts/*  /home/$USERNAME/.config/scripts
  mkdir /home/$USERNAME/.config/backimg # Background images dir
  cp -r /home/$USERNAME/PintArch/configs/backimg/*  /home/$USERNAME/.config/backimg
  nitrogen --random --set-zoom-fill --save /home/$USERNAME/.config/backimg
  mkdir /home/$USERNAME/.themes # Create my themes folder
  unzip /home/$USERNAME/PintArch/configs/themes/Material-Black-Blueberry-2.9.9-07.zip -d /home/$USERNAME/.themes
  mkdir /home/$USERNAME/.icons # Create my Icons themes folder
  unzip /home/$USERNAME/PintArch/configs/themes/Material-Black-Blueberry-2.9.9-07.zip -d /home/$USERNAME/.icons
  #chown -R $USERNAME: /home/$USERNAME/.config
  chmod 755 /home/$USERNAME/.config/scripts/*   
fi

# Theming DE if user chose FULL installation
if [[ $INSTALL_TYPE == "TOTAL" ]]; then
  if [[ $DESKTOP_ENV == "DWM" ]]; then
    echo FULL DO DWM para steam, flatpak, bottles, OBS, CUPS, Visual studio, etc. Vou ver.
  fi
fi
clear
counter
echo -ne "
-------------------------------------------------------------------------
                    SISTEMA PRONTO PARA 3-post-setup.sh
-------------------------------------------------------------------------
"
exit
