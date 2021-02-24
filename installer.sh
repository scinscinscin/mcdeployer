#!/bin/bash
# mcdeployer by Scinorandex
# Built upon mcserverinstaller
STARTDIR=$PWD
pathToJar=${STARTDIR}/mcserver/server.jar
MAXRAM=$(($(free -m | grep Mem: | awk '{print $2}') - 1000))

echo -e "Use the numbers to select options"

function killscript(){
    echo -e "Script has finished"
    exit
}

function checkIfSure(){
    echo -e "Are you sure you want to deploy a $1-$2 server?"
    select option in "yes" "no"; do
        case $option in
            yes )
                break;;
            no )
                rm -rf "${STARTDIR}/mcserver"
                killscript
        esac
    done
}

# Handles getting latestSuccessfulBuilds from jenkins
function getJenkins(){
    wget "$1"
    unzip archive.zip
    mv archive/build/distributions/* . 2>> /dev/null
    mv archive/build/libs/* . 2>> /dev/null
    mv archive/projects/mohist/build/libs/* . 2>> /dev/null
    rm -rf archive*
}

function bukkitSpigot(){
    echo -e "Enter the version you want to deploy. Only works for versions supported by BuildTools"
    echo -e "Ex: 1.8, 1.15.2, default is latest"
    while :
    do
        read -r version
        if [[ ${version} == "" ]]; then version="latest"; fi
        if curl -s -o /dev/null -w "%{http_code}" curl "https://hub.spigotmc.org/versions/${version}.json" | grep 200 >> /dev/null ; then
            checkIfSure "$1" "${version}"
            wget https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
            break
        else 	
            echo "${version} isn't supported by BuildTools, Please try again."
        fi
    done
}

# Check if PWD/mcserver exists
if [ -d "$STARTDIR/mcserver" ]; then
    echo -e "$STARTDIR/mcserver exists, Do you want to delete it?"
    select option in "yes" "no"; do
        case $option in
            yes ) rm -rf "$STARTDIR/mcserver"; break;;
            no ) break;;
        esac
    done  
fi

# Agree to the EULA so we don't get sued
echo -e "By continuing to run this script you agree to the Minecraft EULA found at https://account.mojang.com/documents/minecraft_eula"
echo -e "Do you agree to the Minecraft EULA?"
select option in "yes" "no"; do
    case $option in
        yes ) break;;
        no ) killscript
    esac
done

mkdir -p -- "$STARTDIR/mcserver"
cd -- "$STARTDIR/mcserver" || { echo "Failed to CD into $STARTDIR/mcserver. Aborting"; exit 1; }

echo -e "What platform do you want to deploy a server for?"
select platform in "Java" "Bedrock"; do
    case $platform in
	    Java ) 
            # Install dependencies for java edition
            echo -e "Install the following dependencies using which package-manager?"
            select command in "none" "apt" "pacman" "yum"; do
                case $command in
                    none ) echo -e "Parts of this script will fail if the dependencies are not installed"; break;;                
                    apt ) sudo apt-get -y install openjdk-8-jre-headless git jq unzip curl; break;;
                    pacman ) sudo pacman --noconfirm -S jre8-openjdk-headless git jq unzip curl; break;;
                    yum ) sudo yum -y install openjdk8-jre-headless git jq unzip curl; break;;
                esac
            done

            # Ask which server software to use
            echo -e "What server software do you want to use?"
            select server in "Vanilla" "Fabric" "CraftBukkit" "Spigot" "Paper" "Tuinity" "Forge" "SpongeVanilla" "Mohist" "Magma"; do
                case $server in
                    Vanilla )
                        echo -e "Enter the version you want to deploy. Also works with snapshots and pre-releases."
		                echo -e "Ex: 1.8.9, 1.15.2, 13w16a, 1.9-pre1"
                        while :
                        do 
                            read -r version
                            json=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq  -r --arg version "$version" '.versions[] | select(.id==$version)' | grep url | awk '{ print $2 }')
                            if [[ "${json}" == "" ]] || [[ "${json}" == "null" ]]; then 
                                    echo -e "This version is invalid, Please try again."
                            else
                                json=${json//,}; json="${json%\"}"; json="${json#\"}" # Clean the json to get the link of the specific version
                                dlLink=$(curl -s "${json}" | jq .downloads.server.url)
                                dlLink="${dlLink%\"}"; dlLink="${dlLink#\"}" # remove the quotes surrounding the dlLink

                                checkIfSure "Vanilla" "${version}"
                                echo "Downloading ${version} server.jar from ${dlLink}"
                                wget "${dlLink}" -O "${STARTDIR}/mcserver/server.jar"
                                break
                            fi
                        done
                    break;;

                    Fabric )
                        pathToJar=${STARTDIR}/mcserver/fabric-server-launch.jar
                        echo -e "Enter the version you want to deploy. Supports 18w43b and above."
                        while :
                        do 
                            read -r version
                            releaseTime=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq  -r --arg version "$version" '.versions[] | select(.id==$version)' | grep releaseTime | awk '{print $2}' )
                            releaseTime="${releaseTime%\"}"; releaseTime="${releaseTime#\"}"; releaseTime="${releaseTime:0:10}"
                            if [[ "${releaseTime}" == "" ]]; then
                                echo -e "This is invalid, Please try again."    
                            elif [[ "${releaseTime}" <  "2018-10-23" ]] || [ "${version}" == "18w43a" ]; then
                                echo -e "This version is not supported by Fabric, Please try again."
                            else
                                checkIfSure "Fabric" "${version}"
                                #Have to do this since Fabric's jenkins disappeared
                                latestBuild=$(curl https://maven.fabricmc.net/net/fabricmc/fabric-installer/maven-metadata.xml | grep latest)
                                latestBuild=${latestBuild#"    <latest>"}
                                latestBuild=${latestBuild%"</latest>"}
                                
                                wget https://maven.fabricmc.net/net/fabricmc/fabric-installer/${latestBuild}/fabric-installer-${latestBuild}.jar
                                java -jar ./fabric-installer*.jar server -mcversion "${version}" -downloadMinecraft
                                rm fabric-installer-${latestBuild}.jar
                                break
                            fi
                        done
                    break;;

                    CraftBukkit )
                        bukkitSpigot "CraftBukkit"
                        java -jar BuildTools.jar --compile craftbukkit --rev "${version}"
                        rm -- BuildTools.jar
                        mv craftbukkit-*.jar "server.jar"
                    break;;
                    
                    Spigot )
                        bukkitSpigot "Spigot"
                        java -jar BuildTools.jar --rev "${version}"
                        rm -- BuildTools.jar
                        mv spigot-*.jar "server.jar"
                    break;;
                    
                    Paper )
                        # The following terrible lines of code are sponsored by Paper locking their Jenkins server behind GitHub
                        echo -e "Select which major version of Paper you want to deploy from the options below."
                        curl -s https://papermc.io/api/v2/projects/paper/ | jq -r --compact-output .version_groups
                        while :
                        do 
                            read -r version_groups
                            status=$(curl -s https://papermc.io/api/v2/projects/paper/version_group/${version_groups} | jq -r .error)
                            if [[ "${status}" == "no such version group" ]]; then
                                echo -e "${version_groups} is invalid, Please try again."    
                            else
                                break
                            fi
                        done

                        echo -e "Select which minor version of Paper you want to deploy from the options below."
                        curl -s https://papermc.io/api/v2/projects/paper/version_group/${version_groups} | jq -r --compact-output .versions
                        while :
                        do 
                            read -r version
                            status=$(curl -s https://papermc.io/api/v2/projects/paper/versions/${version} | jq -r .error)
                            if [[ "${status}" == "no such version" ]]; then
                                echo -e "${version} is invalid, Please try again."    
                            else
                                break
                            fi
                        done

                        latestBuild=$(curl -s https://papermc.io/api/v2/projects/paper/versions/${version} | jq -r .builds[-1])
                        latestName=$(curl -s https://papermc.io/api/v2/projects/paper/versions/${version}/builds/${latestBuild}/ | jq -r .downloads.application.name)
                        checkIfSure "Paper" "${version}-${latestBuild}"
                        wget https://papermc.io/api/v2/projects/paper/versions/${version}/builds/${latestBuild}/downloads/${latestName} -O "${STARTDIR}/mcserver/server.jar"
                    break;;

                    Tuinity )
                        echo -e "Enter the build number you want to deploy."
                        echo -e "Ex: 100. Default is lastSuccessfulBuild"
                        while :
                        do
                            read -r version
                            if [[ ${version} == "" ]]; then version="lastSuccessfulBuild"; fi
                            if curl -s -o /dev/null -w "%{http_code}" curl "https://ci.codemc.io/job/Spottedleaf/job/Tuinity/${version}/artifact/tuinity-paperclip.jar" | grep 200 >> /dev/null ; then
                                checkIfSure "Tuinity" "${version}"
                                wget https://ci.codemc.io/job/Spottedleaf/job/Tuinity/${version}/artifact/tuinity-paperclip.jar -O "${STARTDIR}/mcserver/server.jar"
                                break
                            else 	
                                echo "${version} isn't a Tuinity build number, Please try again."
                            fi
                        done
                    break;;
                    
                    Forge )
                        echo -e "Enter which version you want to deploy Forge on."
                        echo -e "Ex: 1.1, 1.10, 1.12."
                        promotions=$(curl -s https://files.minecraftforge.net/maven/net/minecraftforge/forge/promotions_slim.json | jq -r .promos)
                        while :
                        do
                            read -r version
                            build=$(echo ${promotions} | jq -r --arg version "${version}-latest" '.[$version]')
                            if [[ ${build} == "null" ]]; then 
                                echo "${version} is not a Forge version, Please try again."
                            else
                                checkIfSure "Forge" "${version}-${build}"
                                wget "https://files.minecraftforge.net/maven/net/minecraftforge/forge/${version}-${build}/forge-${version}-${build}-installer.jar"
                                java -jar ./forge-${version}-${build}-installer.jar --installServer
                                rm forge-${version}-${build}-installer.jar
                                mv forge-*.jar server.jar
                                break
                            fi
                        done
                    break;;
                    
                    SpongeVanilla )
                        checkIfSure "SpongeVanilla" "1.12.2"
		                wget https://repo.spongepowered.org/maven/org/spongepowered/spongevanilla/1.12.2-7.2.2/spongevanilla-1.12.2-7.2.2.jar -O "${STARTDIR}/mcserver/server.jar"
                    break;;
                    
                    Mohist )
                        echo -e "Enter the version you want to deploy. Only works with versions that Mohist supports."
                        echo -e "Ex: 1.12.2, 1.16.5, 1.7.10"
                        while :
                        do
                            read -r version
                            if curl -s -o /dev/null -w "%{http_code}" curl "https://ci.codemc.io/job/Mohist-Community/job/Mohist-${version}/lastSuccessfulBuild/artifact/*zip*/archive.zip" | grep 200 >> /dev/null ; then
                                checkIfSure "Mohist" "${version}"
                                getJenkins https://ci.codemc.io/job/Mohist-Community/job/Mohist-${version}/lastSuccessfulBuild/artifact/*zip*/archive.zip
                                mv *.jar server.jar
                                break
                            else 	
                                echo "${version} isn't a Mohist version, Please try again."
                            fi
                        done
                    break;;
                    
                    Magma )
                        checkIfSure "Magma" "1.12.2"
		                getJenkins "https://ci.hexeption.dev/job/Magma%20Foundation/job/Magma/job/master/lastSuccessfulBuild/artifact/*zip*/archive.zip"
                        mv *.jar server.jar

                        # Magma 1.15 and 1.16 support
                        # echo -e "Enter the version you want to deploy. Only works with major versions of Minecraft"
                        # echo -e "Ex: 1.15, 1.16. Default is 1.12"
                        # while :
                        # do
                        #     read -r version
                        #     if [[ ${version} == "" ]]; then
                        #         checkIfSure "Magma" "1.12"
                        #         getJenkins "https://ci.hexeption.dev/job/Magma%20Foundation/job/Magma/job/master/lastSuccessfulBuild/artifact/*zip*/archive.zip"
                        #         break
                        #     else
                        #         if curl -s -o /dev/null -w "%{http_code}" curl "https://ci.hexeption.dev/job/Magma%20Foundation/job/Magma-${version}.x/job/master/lastSuccessfulBuild/artifact/*zip*/archive.zip" | grep 200 >> /dev/null ; then
                        #             checkIfSure "Magma" "${version}"
                        #             getJenkins https://ci.hexeption.dev/job/Magma%20Foundation/job/Magma-${version}.x/job/master/lastSuccessfulBuild/artifact/*zip*/archive.zip
                        #             break
                        #         else 	
                        #             echo "${version} isn't a Magma version, Please try again."
                        #         fi
                        #     fi
                        # done
                    break;;
                esac
            done

            echo -e "How much RAM should be allocated to the server in MiB (Mibibytes)? 1024 - ${MAXRAM}"            
            while :
            do
                read -r allocatedRam
                if ! [[ "$allocatedRam" =~ ^[0-9]+$ ]]; then
                    echo -e "Sorry positive integers only."
                elif ((allocatedRam > MAXRAM ||  allocatedRam < 1024)); then
                    echo -e "${allocatedRam} is outside of range 1024-${MAXRAM}"
                else
                    echo "java -Xms${allocatedRam}M -Xmx${allocatedRam}M -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -jar ${pathToJar} nogui" >> ${STARTDIR}/mcserver/start.sh
                    chmod +x ${STARTDIR}/mcserver/start.sh
                    break
                fi
            done

            echo "eula=true" >> ${STARTDIR}/mcserver/eula.txt

            echo -e "What do you want to do?"
            echo -e "Start the server? Make a Systemd service? or Quit?"
            select option in "start" "systemd" "quit"; do
                case $option in
                    start )
                        echo -e "Starting the minecraft server now...."
                        bash ${STARTDIR}/mcserver/start.sh
                    break;;
                    
                    systemd )
                        echo -e "You selected to create a systemd service for minecraft. This is saved in /etc/systemd/system/minecraft.service"
                        echo "[Unit]">> sy
                        echo "Description=Minecraft Server Systemd Service.">> sy
                        echo "">> sy
                        echo "[Service]">> sy
                        echo "User=$USER">> sy
                        echo "Group=$USER">> sy
                        echo "Type=simple">> sy
                        echo "ExecStart=/bin/bash ${STARTDIR}/mcserver/start.sh">> sy
                        echo "WorkingDirectory= ${STARTDIR}/mcserver">> sy
                        echo "[Install]">> sy
                        echo "WantedBy=multi-user.target">> sy
                        sudo mv sy /etc/systemd/system/minecraft.service
                        sudo systemctl enable minecraft.service
                        sudo systemctl start minecraft.service
                    break;;
                    
                    quit ) break;;
                esac
            done
		break;;
	    Bedrock ) echo -e "What server software do you want to use?"
            select server in "Bedrock Dedicated Server" "Nukkit"; do
                case $server in
                    "Bedrock Dedicated Server" )
                        wget -O bedrock.zip https://minecraft.azureedge.net/bin-linux/bedrock-server-1.16.0.2.zip
		                unzip bedrock.zip
		                rm bedrock.zip
		                echo "LD_LIBRARY_PATH=. ./bedrock_server" >> start.sh
                    break;;
                    
                    Nukkit )
                    echo "Nukkit"
                        wget -O nukkit.jar https://ci.nukkitx.com/job/NukkitX/job/Nukkit/job/master/lastSuccessfulBuild/artifact/target/nukkit-1.0-SNAPSHOT.jar
		                echo "java -jar nukkit.jar" >> start.sh
                    break;;
                esac
            done
            chmod +x start.sh

            echo -e "${body}Server is done installing, ${head}Choose to start the server, or exit${NC}"
            select post in "start" "exit"; do
                case $post in
                    start ) echo -e "${body}Starting server now${NC}"
                        ./start.sh
                    break;;
                    exit ) break;;
                esac
            done
        break;;
    esac
done

echo -e "Script is finished"