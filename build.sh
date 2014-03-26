#!/bin/bash

target_server_user=$1
target_server=$2
target_server_port=$3

. ./build-conf.sh
. ./deploy-conf.sh

. ./scripts/misc-functions.sh

valid_instances=(`echo $valid_instances | sed -e 's/,[[:space:]]*/ /g'`)

valid_deployment_types=( "plugins" "ext" )
default_deployment_type=${valid_deployment_types[0]}

if [ -z $deployment_type ];then
	deployment_type=$default_deployment_type
fi

if containsElement "$deployment_type" "${valid_deployment_types[@]}"; then
        echo;
else
    echo "INVALID DEPLOYMENT TYPE! (use $(textConjunction valid_deployment_types[@] "or" ))"
    exit 2;
fi

if containsElement "$instance" "${valid_instances[@]}"; then
	echo;
else
    echo "INVALID ENVIRONMENT TYPE! (use $(textConjunction valid_instances[@] "or" ))"
    exit 2;
fi

if stringMatches "$lr_version" "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+";then
        echo "Build using Liferay $lr_version $lr_edition $lr_release_label"
	zip_file=$(firstFile $lr_bamboo_dir "^liferay-portal-${lr_version}-[[:digit:][:alpha:]-]+-bamboo.zip$")
	if [[ ! -z $zip_file ]];then
		rm -rf ./liferay-portal
		unzip ${lr_bamboo_dir}/$zip_file
	else
		echo "Unable to find \"$zip_file\" under directory \"$lr_bamboo_dir\"";
		exit 2;
	fi
        
	if [ "$lr_edition" = "EE" ];then
	        echo "applying patches"
        	rsync -a --exclude=.svn deployment/patching-tool liferay-portal/
	        cd liferay-portal/patching-tool
		sh ./patching-tool.sh auto-discovery
		sh ./patching-tool.sh install
		cd ../../
	fi

	ext_plugin=$(firstFile "ext" "^[[:digit:][:alpha:]-]+-ext$")
	if [[ ! -z $ext_plugin ]];then
		cd ext/$ext_plugin
		echo "Building EXT"
		ant clean direct-deploy
		antReturnCode=$?
		if [ $antReturnCode -ne 0 ];then
		   exit 1;
		fi
		cd ../..
	fi       
 
	if [[ $deployment_type == "plugins" ]];then
		echo "Building PLUGINS"
		ant deploy
		antReturnCode=$?
		if [ $antReturnCode -ne 0 ];then
		   exit 2;
		fi
	fi

	target_liferay_dir=/opt
	if [ ! -z $project_dir_name ];then
		target_liferay_dir=${target_liferay_dir}/$project_dir_name
	fi
        value=`echo $instance | tr '[:upper:]' '[:lower:]'`
	target_liferay_dir=${target_liferay_dir}/liferay-${value}

	if [[ $deployment_type == "plugins" ]];then
        	scp -r -P $target_server_port ./liferay-portal/deploy/* ${target_server_user}@${target_server}:${target_liferay_dir}/deploy

	elif [[ $deployment_type == "ext" ]];then
		tomcat_dir=$(firstFile "liferay-portal" "^tomcat-[[:digit:][:alpha:]\-\.]+$")
	        if [[ ! -z $tomcat_dir ]];then
			ssh ${target_server_user}@${target_server} -p $target_server_port "${target_liferay_dir}/${tomcat_dir}/bin/shutdown.sh -force; rm -rf ${target_liferay_dir}/${tomcat_dir}/work/* ${target_liferay_dir}/${tomcat_dir}/temp/*"
		        scp -r -P $target_server_port ./liferay-portal/* ${target_server_user}@${target_server}:${target_liferay_dir}
        		ssh ${target_server_user}@${target_server} -p $target_server_port "${target_liferay_dir}/${tomcat_dir}/bin/startup.sh"
		else
			echo "Unable to find the tomcat directory inside \"liferay-portal\"."
		fi
	fi
else
        echo "INVALID LIFERAY VERSION!"
fi
