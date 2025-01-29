#!/bin/bash

# Faz download do google drive
# $1 - idGoogleFile - id of Google Drive File
# $2 - outFile - name of file
gDriveDown() {
    echo -e "\nDownloading $2 from Google Drive\n"
    URL="https://docs.google.com/uc?export=download&id=$1"

    if [ -e "$2" ]; then
        echo -e "\nArquivo $2 já existe... Se você quer baixar novamente apague esse arquivo!"
    else
        echo -e "Arquivo não existe, fazendo o download..."
        # verificando se há permissão de gravação - se não, não dá para fazer o download
        if [ ! -e `dirname "$2"` ]; then
            echo -e "Diretório $(dirname "$2") não existe!"
            exit 1
        fi
        wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate $URL -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=$1" -O $2 && rm -rf /tmp/cookies.txt
        echo -e "Download completo!"
    fi
}

# Verifica se o arquivo existe - caso contrário termina
verifyFile () {
    if [ ! -e $1 ]; then
        echo -e "ERROR - file not found: $1"
        exit 1
    fi
}

# O script inicia sua execução aqui!!!

echo -e "Instalação e configuração do GNS3 e Docker, bem como da configuração das permissões dos usuários criados pelo LDAP.\n"

# Verificar se você tem permissão de root - se não tiver termina.
echo -e "Verificando se o usuário atual tem permissão de administrador/root."
if [ "$UID" -ne 0 ]; then
    echo -e "\n\tERRO - Logue como root ou utilize o comando sudo para executar esse script!"
    exit 1
fi

echo -e "1. Configurando permissões dos diretórios dos usuários ldap:"

echo -e "\t - configurando permissões dos diretórios. "
# não fiz -R pq pode já existir diretório de usuários lá dentro e ai mudaria a permissão 700 esperada!
chmod 775 /home/usuarios/
chmod 775 /home/usuarios/pessoas/

echo -e "\t - configurando permissões do diretório home. "
echo -e "\t\t* common-session - umask 077"
cp etc/common-session /etc/pam.d/
echo -e "\t\t* login.defs - umask 022"
cp etc/login.defs /etc/

echo -e "\n2. Instalando e configurando Docker:"

echo -e "\t - Instalando. "
apt install -y apt-transport-https ca-certificates curl gnupg

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update

apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo -e "\t - Configurando. "
echo -e "\t\t* Usuários LDAP devem fazer parte do grupo Docker."
echo -e "\t\t\t+ nsswitch.conf."
cp etc/nsswitch.conf /etc/
echo -e "\t\t\t+ group.conf."
cp etc/group.conf /etc/security/
echo -e "\t\t\t+ common-auth."
cp etc/common-auth /etc/pam.d/

echo -e "\t\t* Mudando a rede do Docker para não dar conflito com o rede da UTFPR-CM."
cp etc/daemon.json /etc/docker/

echo -e "\t\t* Reiniciando o Docker para aplicar as configurações."
systemctl restart docker


echo -e "3. Configurando e instalando o GNS3:"

echo -e "\t - Instalando. "
apt install -y gns3-server gns3-gui gns3-webclient-pack dynamips vpcs ubridge wireshark xfce4-terminal

echo -e "\t - Configurando. "
echo -e "\t\t* Criando diretório /etc/gns3."
mkdir /etc/gns3
echo -e "\t\t* gns3_server.conf."
cp etc/gns3_server.conf /etc/gns3
cp etc/gns3_controller.conf /etc/gns3
echo -e "\t\t* Criando usuário gns3."
adduser --system --group gns3
usermod -g ldap gns3
echo -e "\t\t* Adicionando usuário gns3 aos grupos necessários."
usermod -aG ldap,docker,vboxusers,libvirt-qemu,ubridge gns3
usermod -aG ldap,docker,vboxusers,libvirt-qemu,ubridge suporte
usermod -aG ldap,docker,vboxusers,libvirt-qemu,ubridge aluno
echo -e "\t\t* Alterando dono e permissão do arquivo de configuração do GNS3."
setfacl -d -m u::rwx,g::rwx,o::rx /var/gns3/
setfacl -d -m u::rwx,g::rwx,o::rx /var/gns3/projects
chown -R gns3:ldap /etc/gns3
chmod -R 775 /etc/gns3
chmod g+s /var/gns3/
chmod g+s /var/gns3/projects

echo -e "\t\t* Copiando arquivo de configurações, imagens, appliances, etc."
cp -rf gns3 /var

echo -e "\t\t* Baixando imagens."

dirImg="/var/gns3/images/IOS/"

file7200="c7200-adventerprisek9-mz.124-24.T5.bin"
googleID7200="1uR5e3nsfgvpRE9bNXSok4rZO4HCkqjET"
echo -e "\t\t\t+ Baixando $dirImg$file7200"
gDriveDown $googleID7200 $dirImg$file7200
verifyFile $dirImg$file7200

file3640="c3640-a3js-mz.124-25d.image"
googleIDc3640="1sKkWOzx0Cl-TvwGBQufpmmQerAYpSznM"
echo -e "\t\t\t+ Baixando $dirImg$file3640"
gDriveDown $googleIDc3640 $dirImg$file3640
verifyFile $dirImg$file3640

#não sei para que o GNS3 utiliza esse diretório, mas está utilizando
echo -e "\t\t* criando diretório /nonexistent/."
mkdir /nonexistent/

echo -e "\t\t* Configurando permissões."
chown -R gns3:ldap /var/gns3/ /nonexistent/
chmod -R 775 /var/gns3 /nonexistent/


echo -e "\t\t* Alterando nome do executável do GNS3."
if [ ! -e /usr/bin/gns3-gui ]; then
    echo -e "\t\t\t+ Arquivo não existia, então foi renomeado!."
    mv /usr/bin/gns3 /usr/bin/gns3-gui
else
    echo -e "\t\t\t+ Arquivo já existia, então nada foi feito."
fi

echo -e "\t\t* Criando novo executável do GNS3 que copia o arquivo de configuração do ambiente gráfico quando for executado pela primeira vez."
cp bin/gns3 /usr/bin/
chmod a+rx /usr/bin/gns3

echo -e "\t\t* Criando arquivo para o GNS3 ser executado como servidor e no processo de boot"
cp etc/gns3.service /etc/systemd/system/gns3.service

echo -e "\t\t\t+ Iniciando o GNS3 e habilitando para o servidor funcionar no processo de boot"
systemctl daemon-reload
systemctl start gns3
systemctl enable gns3

echo -e "3. Configurando e instalando o UFTP:"

echo -e "\t - Instalando UFTP - esse é utilizando no script ClusterFTP "
apt -y install uftp
systemctl disable uftp


echo -e "Instalação e configuração terminada..."
