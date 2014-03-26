#!/bin/bash

containsElement(){ for e in "${@:2}"; do [[ "$e" = "$1" ]] && return 0; done; return 1; }

textConjunction(){

        local text_array=(${!1})
        local conjuction="or"
        local length=${#text_array[@]}

        printf "%s" ${text_array[0]}
        if (( "$length" > "2" ));then
                printf "$result, %s" ${text_array[@]:1:$(($length - 2))}
        fi
        if (( "$length" > "1" ));then
                printf "$result $conjuction %s" ${text_array[$((length - 1))]}
        fi
        printf "\n"
}

stringMatches(){
        local value=$1
        local regex=$2
        local result=`echo $value | grep -E $regex`
        [[ ! -z $result ]] && return 0
        return 1
}

firstFile(){
        local file_dir=$1
        local file_pattern=$2
        local result=`ls -1 $file_dir | grep -iE $file_pattern | head -1`
        echo $result
}
