#!/bin/bash
set -e

# 设置英文环境，以免脚本执行出错
export LANG=en_US.UTF-8

StartDate=$(date +"%Y-%m-%dT%H:%M:%S%:z")
printf "Script start at %s @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n" "$StartDate"

# 载入配置
cd $(dirname $0)
source ./log_cleaner.rc

# 日志文件权限
if [ ! -d $(dirname $SELF_LOG_FILE) ];then
    mkdir -p $(dirname $SELF_LOG_FILE)
fi
if [ ! -a $SELF_LOG_FILE ];then
    touch $SELF_LOG_FILE
fi
chmod 777 -R $(dirname $SELF_LOG_FILE)

#不使用-y参数执行脚本则仅统计出待删除文件，不直接清理
yes_flag=0
while getopts ":y" opt; do
    case $opt in
        y)
            yes_flag=1
            ;;
    esac
done

# 根据yes_flag删除或列出文件
function rm_file {
    file=$1
    if [ $yes_flag -eq 1 ];then
        rm -rf $file
        printf "已删除文件：%s\n" "$file"
    else
        printf "待删除文件：%s\n" "$file" 
    fi
}

# function 1 --------------------------------------------------------------
# 按行删除文件中超过RETENTION_DAYS天的日志
function function1 {
    for FILE in ${!FILES_OF_REMOVE_BY_LINE_MAP[@]};do
        local DAYS=${FILES_OF_REMOVE_BY_LINE_MAP[$FILE]}
        printf "按行号清理过时日志，当前文件:%s  过期天数:%s\n" "$FILE" "$DAYS"
        # 支持匹配四种格式日期
        local format1=$(date -d "$DAYS days ago" +"%Y%m%d")
        local format2=$(date -d "$DAYS days ago" +"%Y-%m-%d")
        local format3=$(date -d "$DAYS days ago" +"%Y/%m/%d")
        local format4=$(date -d "$DAYS days ago" +"%d %b %Y")
 
        local TARGET_LINE=$(grep -nE "$format1|$format2|$format3|$format4" $FILE | tail -n 1 | cut -d: -f1)

        if [ ! -z $TARGET_LINE ];then
            if [[ $yes_flag -eq 1 ]]; then
                sed -i "1,${TARGET_LINE}d" $FILE
                printf "文件:%s  删除了前%s行\n" "$FILE" "$TARGET_LINE"
            else
                printf "文件:%s  待删除前%s行\n" "$FILE" "$TARGET_LINE"
            fi
        else
            printf "文件:%s  TARGET_LINE未找到\n" "$FILE" 
        fi

    done
}
# function 1 end ------------------------------------------------------------

# function 2 ----------------------------------------------------------------
# 删除超过RETENTION_DAYS天的备份目录 
function function2 {
    for BACKUP_OF_USER in ${BACKUP_OF_USER_LIST[*]};do
        if ! getent passwd $BACKUP_OF_USER > /dev/null 2>&1 ;then
            printf "User not exist:%s\n" "$BACKUP_OF_USER"
            continue
        fi
        local USER_HOME=$(getent passwd $BACKUP_OF_USER | cut -d: -f6)
        printf "开始清理backup目录,当前检测路径:%s\n" "$USER_HOME"
        if [ -d ${USER_HOME}/backup ];then
            local TARGET_DATE=$(date -d "$RETENTION_DAYS days ago" +"%Y%m%d")
            for dir in ${USER_HOME}/backup/*; do
                if [ -d $dir ];then
                    # 判断文件夹名是否合规
                    if date -d "$(basename $dir)" +"%Y%m%d" > /dev/null 2>&1;then
                        # 文件夹日期早于目标日期则删除
                        if [[ $(echo "$(basename $dir) < $TARGET_DATE" | bc) -eq 1 ]];then
                            rm_file $dir
                        fi
                    else
                        printf "无效的目录：%s\n" $dir
                    fi
                fi
            done
        else
            printf "用户:%s backup目录不存在，跳过备份目录清理\n" "$BACKUP_OF_USER"
        fi
    done
}
# function 2 end ------------------------------------------------------------


# function 3 ----------------------------------------------------------------
# 按日分隔日志目录清理
function function3 {
    for DAY_LOG_PATH in ${!DAY_LOG_MAP[@]};do
        printf "开始清理按日分隔日志,当前检测路径:%s\n" "$DAY_LOG_PATH"
        if [ -d $DAY_LOG_PATH ];then
            if [[ $yes_flag -eq 1 ]]; then
                printf "删除目录:%s的按日分隔过期日志\n"  "$DAY_LOG_PATH"
                find $DAY_LOG_PATH -maxdepth 1 -type f -mtime +$RETENTION_DAYS -name "${DAY_LOG_MAP[$DAY_LOG_PATH]}" -print -delete
            else
                printf "列出目录:%s的按日分隔过期日志\n" "$DAY_LOG_PATH"
                find $DAY_LOG_PATH -maxdepth 1 -type f -mtime +$RETENTION_DAYS -name "${DAY_LOG_MAP[$DAY_LOG_PATH]}" 
            fi
        else
            printf "目录:%s not exist \n" "$DAY_LOG_PATH"
        fi
    done
}
# function 3 end ----------------------------------------------------------

# function 4
function function4 {
    for FILE in ${CLEAN_BY_REDIRECTION_FILES[@]};do 
        if [ -w $FILE ];then
            if [[ $yes_flag -eq 1 ]];then
                > $FILE
                printf "已使用>清理:%s\n" $FILE
            else
                printf "待使用>清理:%s\n" $FILE
            fi
        fi
    done
}
# function 4 end ---------------------------------------------------------

# function 5
# SELF日志清理
function function5 {
    printf "SELF日志清理:%s" "$SELF_LOG_FILE"
    if [ -w $SELF_LOG_FILE ];then

        local format=$(date -d "$RETENTION_DAYS days ago" +"%Y-%m-%d")
        local format_str="Script end at $format"
        local TARGET_LINE=$(grep -n "$format_str" $SELF_LOG_FILE | tail -n 1 | cut -d: -f1)

        if [ ! -z $TARGET_LINE];then
            if [[ $yes_flag -eq 1 ]]; then
                sed -i "1,${TARGET_LINE}d" $SELF_LOG_FILE
                printf "文件:%s  删除了前%s行\n" "$SELF_LOG_FILE" "$TARGET_LINE"
            else
                printf "文件:%s  待删除前%s行\n" "$SELF_LOG_FILE" "$TARGET_LINE"
            fi
        else
            printf "文件:%s  TARGET_LINE未找到\n" "$SELF_LOG_FILE"
        fi
    else
        printf "文件:%s  不存在或者无写入权限\n" "$SELF_LOG_FILE"
    fi
}
# function 5 end -------------------------------------------------------------

function1
function2
function3
function4
function5

# end:  重要，SELF日志清理需要匹配该时间--------------------------------------------
EndDate=$(date +"%Y-%m-%dT%H:%M:%S%:z")
printf "Script end at %s @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n" "$EndDate"
