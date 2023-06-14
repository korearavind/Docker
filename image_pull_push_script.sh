#!/bin/bash

#variable defination
PROXY_path=/etc/systemd/system/docker.service.d/proxy.conf
Image_store_path=/home/script/stat/image_$(date +"%Y-%m-%d").csv
Artifactory=ARTIFACTORY_TO_PUSH_IMAGE
PROXY_FILE=/home/arvund/script/proxy_pomerum_VPN.conf


#Proxy file verfication
ls ${PROXY_path} > /dev/null 2>&1;
exitcode=$?
if [ "$exitcode" == '0' ]
then
        #remove the proxy file and restart the docker for Pulling the image
        sudo rm ${PROXY_path}
        sudo systemctl daemon-reload
        sudo systemctl restart docker

fi ;
echo -e "##############################\n"
echo -e "Make sure you have connected to the RAKUTEN VPN \n"
echo -e "Provide the docker image to pull:\n"

#reading the image details
read image_pull
image_read=`echo $image_pull | awk -F":" '{print $NF}'`
image_data=`docker image ls $image_pull | tail -1 | awk '{print $2}'`
if [ "$image_data" != "$image_read" ] #verifying that the image TAG is already present
then
        #pulling the image from artifactory
        docker pull $image_pull
        pullingexitcode=$?
        if [ "$pullingexitcode" == '0' ]
        then
                echo -e "\nsuccessfully pulled the image from artifactory"
                echo -e "##############################\n"
                docker image ls $image_pull #listing the image
                sleep 5
                image_tag=`echo $image_pull | awk -F"/" '{print $NF}'`
                echo -e "##############################\n"
                echo -e "Tagging the Image \n"
                echo -e "From : $image_pull \n"
                echo -e "  To : ${Artifactory}/$image_tag \n"

                #Verification image storage file
                ls ${Image_store_path}> /dev/null 2>&1;
                fileexitcode=$?
                if [ "$fileexitcode" != '0' ]
                then
                        echo "DATE,REPOSITORY,TAG,IMAGE ID,SIZE" > ${Image_store_path} #Adding the header into the image store file
                fi ;

                #Tagging the image
                docker tag $image_pull ${Artifactory}/$image_tag

                tagexitcode=$?
                if [ "$tagexitcode" == '0' ]
                then
                        echo -e "\nsuccessfully tagged the image"
                        echo -e "##############################"
                        docker image ls ${Artifactory}/$image_tag
                        docker image ls ${Artifactory}/$image_tag | tail -1 | awk '{print strftime("%d-%m-%Y")","$1","$2","$3","$7}' >> ${Image_store_path}
                        sleep 5

                        #Proxy file verfication
                        ls ${PROXY_path} > /dev/null 2>&1;
                        pushexitcode=$?
                        if ([ "$pushexitcode" -ne '0' ] && [ "$tagexitcode" -eq '0' ])
                        then
                                #Copy the Proxy file and restart the docker for pushing the Image to artifactory
                                sudo cp -p ${PROXY_FILE} ${PROXY_path}
                                sudo systemctl daemon-reload
                                sudo systemctl restart docker
                                echo -e "pushing the below image to artifactory\n"
                                echo -e "${Artifactory}/$image_tag\n"

                                #Pushing the image to Artifactory
                                docker push ${Artifactory}/$image_tag
                                lstexitcode=$?
                                if [ "$lstexitcode" == '0' ]
                                then
                                        echo -e "\nsuccessfully pushed the image to artifactory of rakuten"
                                else
                                        echo -e "\nerror while pushing the image to artifactory"
                                fi;
                                echo -e "##############################"
                        fi;
                else
                        echo -e "\nerror while tagging the image"
                fi;
        else
                echo -e "\nerror while pulling the image from artifactory"
        fi;
else
        echo -e "\nIMAGE: $image_pull with the TAG: $image_read already present in the local hub"
        echo "Exiting !Nothing to do.."
fi;
