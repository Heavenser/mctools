#!/usr/bin/env bash

AUTO_COMP=(zstd lz4 gzip)
AUTO_COMP_SUF=(zst lz4 gz)
PG_NAME=$(basename $0)

root_check(){
    if [ $(whoami) != 'root' ]; then
        echo "${PG_NAME}: Permission denied. Must be superuser."
        exit 1
    fi
}

get_opts(){
    if [ ! $1 ]; then
        usage
        exit 0
    fi

    while [ $# -gt 0 ]; do
        case $1 in
            backup)
                export MODE=$1
                ;;
            rollback)
                export MODE=$1
                ;;
            clean)
                export MODE=$1
                shift
                export BACKUP_DIR=$1
                ;;
            from)
                shift
                export GAME_DIR=$1
                ;;
            to)
                shift
                export BACKUP_DIR=$1
                ;;
            use)
                shift 
                export CUST_COMP=$1
                ;;
            *)
                usage
                exit 0
                ;;
        esac
        shift
    done
}

var_check(){
    # Minecraft service check
    if [ "${MODE}" != "clean" ]; then
        if [ $(ps aux | grep minecraft-server.jar | grep -v grep | wc -l) -ne 0 ]; then
            echo "Minecraft server is running."
            echo "Please stop Minecraft server before backup or rollback."
            exit 1
        fi
    fi

    # Rollback var swap
    if [ "${MODE}" = "rollback" ]; then
        swap=${GAME_DIR}
        export GAME_DIR=${BACKUP_DIR}
        export BACKUP_DIR=${swap}
        unset swap
    fi

    # GAME_DIR check
    if [ "${MODE}" != "clean" ]; then
        if [ ! ${GAME_DIR} ] || [ ! -d ${GAME_DIR} ]; then
            echo "Error: Game directory not exist."
            echo "Please check you minecraft directory."
            exit 1
        fi
    fi

    # LEVEL_NAME check
    if [ "${MODE}" != "clean" ]; then
        if [ ! -f ${GAME_DIR}/server.properties ]; then
            echo "Error: File server.properties not found."
            echo "Please check you minecraft directory."
            exit 1
        else
            export LEVEL_NAME=$(grep level-name ${GAME_DIR}/server.properties | cut -d '=' -f 2)
        fi
        if [ -z "${LEVEL_NAME}" ]; then
            echo "Error: Cannot get the level name."
            echo "Plesae check you server.properties."
            exit 1
        fi
    fi

    # BACKUP_DIR check
    if [ ! ${BACKUP_DIR} ]; then
        echo "Error: Backup directory not exist."
        echo "Please check you backup directory."
        exit 1
    elif [ -f ${BACKUP_DIR} ]; then
        export BACKUP_FILE=$(basename ${BACKUP_DIR})
    elif [ ! -d ${BACKUP_DIR} ]; then
        read -p "Backup directory: ${BACKUP_DIR} not exist. Create it? [Y/n] " yn
        case ${yn} in
            [Nn])
                echo "Backup not completed."
                exit 1
                ;;
            *)
                mkdir -p ${BACKUP_DIR}
                ;;
        esac
    fi

    # BACKUP_FILE set
    if [ "${MODE}" = "backup" ] && [ ! ${BACKUP_FILE}]; then
        export BACKUP_FILE=$(date +%Y%m%d_%H%M%S)-${LEVEL_NAME}.tar
    fi
}

comp_var_check(){
    # CUST_COMP check
    if [ ! ${CUST_COMP} ]; then
        for x in ${AUTO_COMP[@]}; do
            type ${x} > /dev/null
            if [ $? = 0 ]; then
                export CUST_COMP=${x}
                break
            fi
        done
    fi

    if [[ ! "${AUTO_COMP[@]}" =~ "${CUST_COMP}" ]]; then
        echo "Error: Unsuported compressino algo."
        exit 2
    else
        type ${CUST_COMP} > /dev/null
        if [ $? != 0 ]; then 
            echo "Error: ${CUST_COMP} not found. Install it before use."
            exit 1
        fi
    fi

    # CUST_COMP_SUF check
    for x in ${!AUTO_COMP[@]}; do
        if [ "${AUTO_COMP[x]}" = "${CUST_COMP}" ]; then
            export CUST_COMP_SUF=${AUTO_COMP_SUF[x]}
        fi
    done
}

backup(){
    comp_var_check
    echo "Backup start."
    echo "Backing up ${BACKUP_FILE}..."
    cd ${GAME_DIR}
    tar -I ${CUST_COMP} -cpf ${BACKUP_DIR}/${BACKUP_FILE}.${CUST_COMP_SUF} ${LEVEL_NAME}
    echo "Backup completed."
}

rollback(){
    root_check
    echo "Rollback start."
    
    # Choose backup file (Interactive)
    if [ ! ${BACKUP_FILE} ]; then
        echo "Choose a backup file you want to rollback: "
        ls -1t ${BACKUP_DIR} | nl -n rn -s '. '
        read -p "You choose: " num
        if [ $(ls -1t ${BACKUP_DIR} | wc -l) -lt ${num} ]; then
            echo "Error: Invalid number."
            exit 2
        fi
        export BACKUP_FILE=$(ls -1t ${BACKUP_DIR} | head -${num} | tail -1)
    fi

    # Clean backup directory
    read -p "We will OVERWRITE ${GAME_DIR}/${LEVEL_NAME} ! Contiune? [N/y] " yn
    case ${yn} in
        [Yy])
            echo "Cleaning ${GAME_DIR}/${LEVEL_NAME}..."
            rm -rf ${GAME_DIR}/${LEVEL_NAME}
            echo "Cleaned completed."
            ;;
        *)
            echo "World directory will not clean."
            exit 0
            ;;
    esac

    # Determine compression algo
    export CUST_COMP=$(file --mime-type ${BACKUP_DIR}/${BACKUP_FILE} | grep -oE 'x-(zstd|lz4|xz|bzip2|gzip)' | cut -d '-' -f 2)
    type ${CUST_COMP} > /dev/null
    if [ $? = 0 ]; then
        echo "Rolling back ${BACKUP_FILE}..."
        tar -I ${CUST_COMP} -xpf ${BACKUP_DIR}/${BACKUP_FILE} -C ${GAME_DIR}
    else
        echo "Error: ${CUST_COMP} not found. Install it before use."
        exit 1
    fi
    echo "Rollback completed."
}

clean(){
    echo "Clean start."

    # Backup files amount less than or equal 3
    if [ $(ls -1t ${BACKUP_DIR} | wc -l ) -le 3 ]; then
        echo "No need to clean."
        exit 1
    fi

    # Clean backup directory (Interactive)
    echo "We will clean your backup files and only stay the NEWEST 3 backup!"
    echo "These files will be removed from ${BACKUP_DIR}: "
    ls -1t ${BACKUP_DIR} | tail -n +4 | nl -n rn -s '. '
    read -p "Contiune clean? [N/y] " yn
    case ${yn} in
        [Yy])
            while [ $(ls -1t ${BACKUP_DIR} | wc -l) -gt 3 ]; do
                export BACKUP_FILE=$(ls -1t ${BACKUP_DIR} | tail -1)
                rm -f ${BACKUP_DIR}/${BACKUP_FILE}
                echo "Removed ${BACKUP_FILE}."
            done
            ;;
        *)
            echo "Backup files will not clean."
            exit 0
            ;;
    esac
    echo "Clean completed."
}

usage(){
    echo "${PG_NAME}: Minecraft server backup and rollback tools"
    echo "Usage: ${PG_NAME} backup from [ GAME_DIR ] to [ BACKUP_DIR ] < use [ zstd | lz4 | gzip ] >"
    echo "       ${PG_NAME} rollback from [ BACKUP_DIR ] to [ GAME_DIR ]"
    echo "       ${PG_NAME} clean [ BACKUP_DIR ]"
    echo "       ${PG_NAME} help"
    echo ""
    echo "where GAME_DIR is your Minecraft game directory (not world directory)"
    echo "      BACKUP_DIR is your backup directory"
    echo ""
    echo "when  return 0 means normal exit"
    echo "      return 1 means file or dir problems"
    echo "      return 2 means parameters problems"
    echo ""
    echo "type '${PG_NAME} help' for this menu"
}

main(){
    get_opts $*
    var_check
    ${MODE}
}

main $*
