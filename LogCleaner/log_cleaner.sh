#!/bin/bash
set -e

# 设置英文环境，以免脚本执行出错
export LANG=en_US.UTF-8

function GetDate {
    date +"%Y-%m-%dT%H:%M:%S%:z"
}

printf "Script start at %s @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n" "$(GetDate)"

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
# 按行删除文件中超过X天的日志，日志文件如果太大则速度很慢
function function1 {
    printf " --------- function1 start at %s ----------- \n" "$(GetDate)"
    for id in ${!FILES_OF_REMOVE_BY_LINE_MAP[@]};do
        local FILE=$(echo ${FILES_OF_REMOVE_BY_LINE_MAP["$id"]} | cut -d'|' -f1)
        local PATTERN=$(echo ${FILES_OF_REMOVE_BY_LINE_MAP["$id"]} | cut -d'|' -f2)
        local DAYS=$(echo ${FILES_OF_REMOVE_BY_LINE_MAP["$id"]} | cut -d'|' -f3)

        printf "按行号清理过时日志，当前文件:%s  过期天数:%s\n" "$FILE" "$DAYS"
        # 支持匹配四种格式日期
        local format=$(date -d "$DAYS days ago" +"$PATTERN")
 
        local TARGET_LINE=$(grep -nE "$format" $FILE | tail -n 1 | cut -d: -f1)

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
    printf " --------- function1 end at %s ----------- \n" "$(GetDate)"
}
# function 1 end ------------------------------------------------------------

# function 2 ----------------------------------------------------------------
# 删除超过X天的日期格式的目录 
function function2 {
    printf " --------- function2 start at %s ----------- \n" "$(GetDate)"
    for i in ${!DATE_DIR_MAP[@]};do
        local DIR=$(echo ${DATE_DIR_MAP["$i"]} | cut -d'|' -f1)
        local Pattern=$(echo ${DATE_DIR_MAP["$i"]} | cut -d'|' -f2)
        local Days$(echo ${DATE_DIR_MAP["$i"]} | cut -d'|' -f3)
        if [ -d ${DIR} ];then
            local TARGET_DATE=$(date -d "$Days days ago" +"$Pattern")
            for date_dir in ${DIR}/*; do
                if [ -d $date_dir ];then
                    # 判断文件夹名是否合规
                    if date -d "$(basename $date_dir)" +"$Pattern" > /dev/null 2>&1;then
                        # 文件夹日期早于目标日期则删除
                        if [[ $(echo "$(basename $date_dir) < $TARGET_DATE" | bc) -eq 1 ]];then
                            rm_file $date_dir
                        fi
                    else
                        printf "无效的目录：%s\n" $date_dir
                    fi
                fi
            done
        else
            printf "目录:%s 不存在，跳过目录清理\n" "$DIR"
        fi
    done
    
    printf " --------- function2 end at %s ----------- \n" "$(GetDate)"
}
# function 2 end ------------------------------------------------------------


# function 3 ----------------------------------------------------------------
# 按日分隔日志文件清理
function function3 {
    printf " --------- function3 start at %s ----------- \n" "$(GetDate)"
    for index in ${!DAY_LOG_MAP[@]};do
        local DAY_LOG_PATH=$(echo ${DAY_LOG_MAP["$index"]} | cut -d'|' -f1)
        local DAY_LOG_PATTERN=$(echo ${DAY_LOG_MAP["$index"]} | cut -d'|' -f2)
        local OUT_DAY=$(echo ${DAY_LOG_MAP["$index"]} | cut -d'|' -f3)
        printf "开始清理按日分隔日志,当前检测路径:%s\n" "$DAY_LOG_PATH"
        if [ -d $DAY_LOG_PATH ];then
            if [[ $yes_flag -eq 1 ]]; then
                printf "删除目录:%s的按日分隔过期日志\n"  "$DAY_LOG_PATH"
                find $DAY_LOG_PATH -maxdepth 1 -type f -mtime +$OUT_DAY -name "$DAY_LOG_PATTERN" -print -delete
            else
                printf "列出目录:%s的按日分隔过期日志\n" "$DAY_LOG_PATH"
                find $DAY_LOG_PATH -maxdepth 1 -type f -mtime +$OUT_DAY -name "$DAY_LOG_PATTERN" 
            fi
        else
            printf "目录:%s not exist \n" "$DAY_LOG_PATH"
        fi
    done
    printf " --------- function3 end at %s ----------- \n" "$(GetDate)"
}
# function 3 end ----------------------------------------------------------

# function 4
function function4 {
    printf " --------- function4 start at %s ----------- \n" "$(GetDate)"
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
    printf " --------- function4 end at %s ----------- \n" "$(GetDate)"
}
# function 4 end ---------------------------------------------------------

# function 5
# SELF日志清理
function function5 {
    printf " --------- function5 start at %s ----------- \n" "$(GetDate)"
    printf "SELF日志清理:%s \n" "$SELF_LOG_FILE"
    if [ -w $SELF_LOG_FILE ];then

        local format=$(date -d "$SELF_LOG_OUT_DAYS days ago" +"%Y-%m-%d")
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
    printf " --------- function5 end at %s ----------- \n" "$(GetDate)"
}
# function 5 end -------------------------------------------------------------

function1
function2
function3
function4
function5

# end:  重要，SELF日志清理需要匹配该时间--------------------------------------------
printf "Script end at %s @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n" "$(GetDate)"