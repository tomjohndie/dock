=>  root @ 󰌽 almalinux: 󰉋 /tmp/docker-xxx------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- main (1!)
➜ cat .github/ISSUE_TEMPLATE/mirror-multiple.md
---
name: hub-mirror-multiple issue template
about: 用于执行 hub-mirror-by-issue-multiple workflow 的 issue 模板
title: "[仓库地址TARGET_REGISTRY]:registry.cn-hangzhou.aliyuncs.com[空间名称TARGET_REPOSITORY]:library[平台 amd64(默认)、arm64、arm/v7等等TARGET_ARCH]:amd64"
labels: ["hub-mirror-multiple"]
---
 
**[需要同步的镜像列表，根据你的需求增加与减少]**
busybox:latest
nginx:latest
 
=>  root @ 󰌽 almalinux: 󰉋 /tmp/docker-xxx------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- main (1!)
➜ cat .github/workflows/hub-mirror-by-issue-multiple.yaml
name: hub-mirror-by-issue-multiple
 
on:
  issues:
    types:
      - opened
 
# https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token
permissions:
  issues: write
 
jobs:
  build:
    runs-on: ubuntu-latest
    if: contains(github.event.issue.labels.*.name, 'hub-mirror-multiple')
    env:
      QYWX_ROBOT_URL: "${{ secrets.QYWX_ROBOT_URL }}"
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          token: "${{ secrets.DOCKER_XXX_TOKEN }}"
 
      - name: Print image info to comment
        id: print-image-info
        env:
          GH_TOKEN: "${{ github.token }}"
          TITLE: "${{ github.event.issue.title }}"
          BODY: "${{ github.event.issue.body }}"
        run: |
          # [仓库地址TARGET_REGISTRY]:registry.cn-hangzhou.aliyuncs.com[空间名称TARGET_REPOSITORY]:library[平台 amd64(默认)、arm64、arm/v7等等TARGET_ARCH]:amd64
          # 仓库地址
          TARGET_REGISTRY="$(echo "${TITLE}" | awk -F ":" '{print $2}' | awk -F "[" '{print $1}' | awk '{print $1}')"
          echo "仓库地址：${TARGET_REGISTRY}"
          # 仓库名称空间
          TARGET_REPOSITORY="$(echo "${TITLE}" | awk -F ":" '{print $3}' | awk -F "[" '{print $1}' | awk '{print $1}')"
          echo "仓库名称空间：${TARGET_REPOSITORY}"
          # 架构
          TARGET_ARCH="$(echo "${TITLE}" | awk -F ":" '{print $4}' | awk -F "[" '{print $1}' | awk '{print $1}')"
          echo "架构：${TARGET_ARCH}"
          reg_exp="^[a-z0-9\/\:\.\-]+$"
          echo "###需要同步的镜像清单" >"image.txt"
          IFS=$'\n'
#          for item in ${BODY}; do
#            item="$(echo "${item}" | awk '{gsub(/ /,"",$0);print $0}' | awk '{print $1}')"
#            if [[ "${item}" =~ ${reg_exp} ]]; then
#              echo "${item}" >>"image.txt"
#            fi
#          done
          # 清除空行、空格和制表符，并过滤合法镜像名称
          reg_exp="^[a-zA-Z0-9\/\:\.\-]+$"  # 扩展正则表达式允许大写字母
          echo "####需要同步的镜像清单" > "image.txt"
          while IFS= read -r line; do
            # 删除行首行尾空格、中间空格及特殊字符（如 \r）
            clean_line=$(echo "${line}" | tr -d '\r' | awk '{gsub(/^[ \t]+|[ \t]+$/, ""); gsub(/ /, "", $0); print}')
            # 检查非空且符合正则表达式
            if [[ -n "${clean_line}" ]] && [[ "${clean_line}" =~ ${reg_exp} ]]; then
              # 提取镜像名和版本（示例：busybox:latest -> busybox 和 latest）
              image_name=$(echo "${clean_line}" | awk -F ":" '{print $1}')
              image_version=$(echo "${clean_line}" | awk -F ":" '{print $2}')
              # 写入 image.txt
              echo "${clean_line}" >> "image.txt"
              # 设置变量（假设只处理第一个有效镜像）
              echo "IMAGE_NAME=${image_name}" >> "${GITHUB_OUTPUT}"
              echo "IMAGE_VERSION=${image_version}" >> "${GITHUB_OUTPUT}"
              break  # 如果只需要处理第一个镜像，则跳出循环
            fi
          done <<< "${BODY}"           
          IMAGE_TXT="$(cat image.txt)"
          gh issue comment "${{ github.event.issue.html_url }}" -b "$(echo -e "\n镜像仓库：${TARGET_REGISTRY}\n仓库名称空间：${TARGET_REPOSITORY}\n架构：${TARGET_ARCH}\n\`\`\`sh\n${IMAGE_TXT}\n\`\`\`\n")"
          gh issue comment "${{ github.event.issue.html_url }}" -b "镜像同步中...[详情请查看](https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}) 如果还需要同步, 请重新提交issue"
          echo "target_registry=${TARGET_REGISTRY}" >>"${GITHUB_OUTPUT}"
          echo "target_repository=${TARGET_REPOSITORY}" >>"${GITHUB_OUTPUT}"
          echo "target_arch=${TARGET_ARCH}" >>"${GITHUB_OUTPUT}"
 
      - name: Login to Docker Registry
        env:
          GH_TOKEN: "${{ github.token }}"
          TARGET_REGISTRY: "${{ steps.print-image-info.outputs.target_registry }}"
          TARGET_REPOSITORY: "${{ steps.print-image-info.outputs.target_repository }}"
          TARGET_ARCH: "${{ steps.print-image-info.outputs.target_arch }}"
        run: |
          docker login -u "${{ secrets.DOCKER_USERNAME }}" -p "${{ secrets.DOCKER_PASSWORD }}" "${TARGET_REGISTRY}"
 
      - name: Pull, tag, and push Docker image
        id: pull-tag-push-image
        env:
          GH_TOKEN: "${{ github.token }}"
          TARGET_REGISTRY: "${{ steps.print-image-info.outputs.target_registry }}"
          TARGET_REPOSITORY: "${{ steps.print-image-info.outputs.target_repository }}"
          TARGET_ARCH: "${{ steps.print-image-info.outputs.target_arch }}"
        run: |
          if [ "${TARGET_ARCH}" != "" ]; then
            bash docker_image_pull.sh --image-from-file="image.txt" --tag --push --repo="${TARGET_REGISTRY}/${TARGET_REPOSITORY}" --arch="${TARGET_ARCH}"
          else
            bash docker_image_pull.sh --image-from-file="image.txt" --tag --push --repo="${TARGET_REGISTRY}/${TARGET_REPOSITORY}"
          fi
          echo "build_log<<EOF" >>"${GITHUB_OUTPUT}"
          cat build.log >>"${GITHUB_OUTPUT}"
          echo "EOF" >>"${GITHUB_OUTPUT}"
 
      - name: qyweixin send message
        if: ${{ env.QYWX_ROBOT_URL != '' }}
        uses: chf007/action-wechat-work@master
        env:
          WECHAT_WORK_BOT_WEBHOOK: "${{secrets.QYWX_ROBOT_URL}}"
          IMAGE_URL: "${{ steps.pull-tag-push-image.outputs.build_log }}"
        with:
          msgtype: markdown
          content: |
            # 镜像同步成功
            ```
            "${{ env.IMAGE_URL }}"
            ```
      - name: Close issue
        env:
          GH_TOKEN: "${{ github.token }}"
          TARGET_REGISTRY: "${{ steps.print-image-info.outputs.target_registry }}"
          TARGET_REPOSITORY: "${{ steps.print-image-info.outputs.target_repository }}"
          TARGET_ARCH: "${{ steps.print-image-info.outputs.target_arch }}"
          BUILD_LOG: "${{ steps.pull-tag-push-image.outputs.build_log }}"
        run: |
          gh issue comment "${{ github.event.issue.html_url }}" -b "$(echo -e "镜像同步完成，详细日志\n\`\`\`sh\n${BUILD_LOG}\n\`\`\`\n")"
          gh issue edit "${{ github.event.issue.html_url }}" --add-label "succeeded" -b "IMAGE SYNC"
          gh issue close "${{ github.event.issue.html_url }}" --reason "completed"
 
      - name: Failed Sync and Close issue
        if: failure()
        env:
          GH_TOKEN: "${{ github.token }}"
          TARGET_REGISTRY: "${{ steps.print-image-info.outputs.target_registry }}"
          TARGET_REPOSITORY: "${{ steps.print-image-info.outputs.target_repository }}"
          TARGET_ARCH: "${{ steps.print-image-info.outputs.target_arch }}"
          BUILD_LOG: "${{ steps.pull-tag-push-image.outputs.build_log }}"
        run: |
          gh issue comment "${{ github.event.issue.html_url }}" -b "镜像同步失败...[详情请查看](https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }})，请检查参数..."
          gh issue edit "${{ github.event.issue.html_url }}" --add-label "failure" -b "IMAGE SYNC"
          gh issue close "${{ github.event.issue.html_url }}" --reason "not planned"
 
=>  root @ 󰌽 almalinux: 󰉋 /tmp/docker-xxx------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- main (1!)
➜ cat .editorconfig
# EditorConfig is awesome: https://EditorConfig.org
 
# top-most EditorConfig file
root = true
 
# Unix-style newlines with a newline ending every file
[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
 
# For all *.sh file indent_size is 4, indent_style is space
[*.sh]
indent_style = space
indent_size = 4
 
# For all *.lua file indent_size is 2, indent_style is space
[*.lua]
indent_style = space
indent_size = 2
 
# For all *.yml and *.yaml file indent_size is 2, indent_style is space
[*.{yml,yaml}]
indent_style = space
indent_size = 2
 
# For file name is Dockerfile indent_size is 4, indent_style is space
[Dockerfile]
indent_style = space
indent_size = 4
 
=>  root @ 󰌽 almalinux: 󰉋 /tmp/docker-xxx------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- main (1!)
➜ cat docker_image_pull.sh
#!/bin/bash
#
#******************************************************************************************
#Author:                QianSong
#QQ:                    xxxxxxxxxx
#Date:                  2024-09-06
#FileName:              docker_image_pull.sh
#URL:                   https://github.com
#Description:           The test script
#Copyright (C):         QianSong 2024 All rights reserved
#******************************************************************************************
 
#######################################
# 打印使用方法
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   none
# Returns:
#   none
#######################################
function print_usage() {
 
    echo "用法：bash $0 [选项] [选项值]"
    echo ""
    echo "选项："
    echo "  --image                镜像列表: --image=iamge1,image2,image3.... (与--image-from-file互斥)"
    echo "  --image-from-file      镜像清单文件: --image-from-file=file (与--image互斥)"
    echo "  -t, --tag              启用tag，默认不会启用tag，如果启用--tag，必须同时启用--repo"
    echo "  -p, --push             启用push，默认不会push，如果启用--push，必须同时启用--tag与--repo"
    echo "  --repo                 镜像仓库域名: --repo=example.repo.com"
    echo "  --arch                 镜像架构: --arch=[amd64,arm64,arm/v7,arm/v6,ppc64le,s390x]"
    echo "  -h, --help             输出此帮助信息并退出"
}
 
#######################################
# 初始化全局变量
# Globals:
#   ${image_list} ${image_file} ${enable_tag}
#   ${enable_push} ${repo_domain}
# Arguments:
#   none
# Outputs:
#   none
# Returns:
#   none
#######################################
function init_global_vars() {
 
    #work_dir
    work_dir="$(dirname "$(realpath -s "$0")")"
 
    #work genarl var
    image_list=""
    image_file=""
    enable_tag=0
    enable_push=0
    repo_domain=""
    target_arch="amd64"
 
    #color
    hei_color="\033[1;30m"
    hong_color="\033[1;31m"
    lv_color="\033[1;32m"
    huang_color="\033[1;33m"
    lan_color="\033[1;34m"
    zi_color="\033[1;35m"
    tianlan_color="\033[1;36m"
    bai_color="\033[1;37m"
    normal_color="\033[0m"
}
 
#######################################
# 获取用户传入的脚本参数，并作相应处理
# Globals:
#   ${image_list} ${image_file} ${enable_tag}
#   ${enable_push} ${repo_domain}
# Arguments:
#   "$@"
# Outputs:
#   none
# Returns:
#   none
#######################################
function get_user_option_paramater() {
 
    if [ $# -eq 0 ]; then
        print_usage
        exit 0
    fi
 
    local opts
    opts="$(getopt -q -o t,p,h -l image:,image-from-file:,tag,push,repo:,arch:,help -- "$@")"
    if [ $? -ne 0 ]; then
        print_usage
        exit 1
    fi
 
    eval set -- "${opts}"
    while true; do
        case "$1" in
        --image)
            local danger_exp1="[ ]+"
 
            if [[ ! "$2" =~ ${danger_exp1} ]]; then
                image_list="$2"
            else
                echo -e "${hong_color}Bad option ${bai_color}$1 $2 \n${zi_color}String contain spaces ${bai_color}($2)${normal_color}"
                exit 1
            fi
            shift 2
            ;;
        --image-from-file)
            local danger_exp2="^\/+$"
            local trim_space2
            trim_space2="$(echo "$2" | awk '{gsub(/ /,"",$0); print $0}')"
 
            if [[ ! "${trim_space2}" =~ ${danger_exp2} ]] && [ -f "$2" ]; then
                image_file="$2"
            else
                echo -e "${hong_color}Bad option ${bai_color}$1 $2 \n${zi_color}No such file ${bai_color}($2)${zi_color} Or file can not be ${bai_color}\"/\"${normal_color}"
                exit 1
            fi
            shift 2
            ;;
        -t | --tag)
            enable_tag=1
            shift 1
            ;;
        -p | --push)
            enable_push=1
            shift 1
            ;;
        --repo)
            local danger_exp3="(--)|(\/\/)|[ ]+"
 
            local arepo_exp1 arepo_exp2
            arepo_exp1="^([a-z0-9])([a-z0-9\.\/\-])+(\/)([a-z0-9])+$"
            arepo_exp2="^([a-z0-9])([a-z0-9\.\/\-])+(\/)([a-z0-9])+(\/)$"
 
            local brepo_exp1 brepo_exp2
            brepo_exp1="^([a-z0-9])([a-z0-9\.\-])+([a-z0-9])$"
            brepo_exp2="^([a-z0-9])([a-z0-9\.\-])+(\/)$"
 
            if [[ "$2" =~ ${danger_exp3} ]]; then
                echo -e "${hong_color}Bad option ${bai_color}$1 $2 \n${zi_color}String contain danger stuff be like \"//\" \"--\" and space ${bai_color}($2)${normal_color}"
                exit 1
            elif [[ "$2" =~ ${arepo_exp1} ]] || [[ "$2" =~ ${arepo_exp2} ]] || [[ "$2" =~ ${brepo_exp1} ]] || [[ "$2" =~ ${brepo_exp2} ]]; then
                repo_domain="$2"
            else
                echo -e "${hong_color}Bad option ${bai_color}$1 $2 \n${zi_color}String is a bad domain ${bai_color}($2)${normal_color}"
                exit 1
            fi
            shift 2
            ;;
        --arch)
            local reg_exp_arch="^amd64$|^arm64$|^arm/v7$|^arm/v6$|^ppc64le$|^s390x$|^$"
            if [[ "$2" =~ ${reg_exp_arch} ]]; then
                case "$2" in
                "amd64")
                    target_arch="amd64"
                    ;;
                "arm64")
                    target_arch="arm64"
                    ;;
                "arm/v7")
                    target_arch="arm/v7"
                    ;;
                "arm/v6")
                    target_arch="arm/v6"
                    ;;
                "ppc64le")
                    target_arch="ppc64le"
                    ;;
                "s390x")
                    target_arch="s390x"
                    ;;
                "")
                    target_arch="amd64"
                    ;;
                esac
            else
                echo -e "${hong_color}Bad option ${bai_color}$1 $2 \n${zi_color}String is a bad arch for docker ${bai_color}($2)${normal_color}"
                exit 1
            fi
            shift 2
            ;;
        -h | --help)
            print_usage
            shift 1
            exit 0
            ;;
        --)
            shift 1
            break
            ;;
        *)
            echo -e "${hong_color}Internal error${normal_color}"
            exit 1
            ;;
        esac
    done
}
 
#######################################
# 检查用户传入的参数，严格限制参数的依赖性
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   none
# Returns:
#   none
#######################################
function check_paramater_to_work() {
 
    # NOTE: 如果 --image 与 --image-from-file 都没有指定，则阻止运行
    if [ -z "${image_list}" ] && [ -z "${image_file}" ]; then
        echo -e "${hong_color}Error: ${bai_color}--image 或 --image-from-file 没有指定，不能继续...${normal_color}"
        exit 1
    fi
 
    # NOTE: 如果 --image 与 --image-from-file 都指定，则阻止运行
    if [ -n "${image_list}" ] && [ -n "${image_file}" ]; then
        echo -e "${hong_color}Error: ${bai_color}--image 与 --image-from-file 互斥且只能指定其中一个，不能继续...${normal_color}"
        exit 1
    fi
 
    # NOTE: 如果 --tag 指定，然而却没有指定 --repo，则阻止运行
    if [ "${enable_tag}" == "1" ]; then
        if [ -z "${repo_domain}" ]; then
            echo -e "${hong_color}Error: ${bai_color}--tag 与 --repo 强行依赖，缺少 --repo，不能继续...${normal_color}"
            exit 1
        fi
    fi
 
    # NOTE: 如果 --push 指定，然而却没有指定 --repo 与 --tag，则阻止运行
    if [ "${enable_push}" == "1" ]; then
        if [ -z "${repo_domain}" ] || [ "${enable_tag}" == "0" ]; then
            echo -e "${hong_color}Error: ${bai_color}--push 与 --repo\--tag 强行依赖，缺少 --repo\--tag，不能继续...${normal_color}"
            exit 1
        fi
    fi
}
 
#######################################
# LOGO
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   none
# Returns:
#   none
#######################################
function print_logo() {
 
    echo -e "${zi_color}▜▘▞▀▖▙▗▌▞▀▖▛▀▘   ▞▀▖▞▀▖▙▗▌▛▀▖▛▀▖▛▀▘▞▀▖▞▀▖${normal_color}"
    echo -e "${zi_color}▐ ▙▄▌▌▘▌▌▄▖▙▄    ▌  ▌ ▌▌▘▌▙▄▘▙▄▘▙▄ ▚▄ ▚▄${normal_color}"
    echo -e "${zi_color}▐ ▌ ▌▌ ▌▌ ▌▌     ▌ ▖▌ ▌▌ ▌▌  ▌▚ ▌  ▖ ▌▖ ▌${normal_color}"
    echo -e "${zi_color}▀▘▘ ▘▘ ▘▝▀ ▀▀▘▀▀▀▝▀ ▝▀ ▘ ▘▘  ▘ ▘▀▀▘▝▀ ▝▀${normal_color}"
}
 
#######################################
# 镜像拉取函数
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   none
# Returns:
#   none
#######################################
function pull_image_from_docker() {
 
    local image_pull_list=()
 
    if [ -n "${image_list}" ]; then
        local item
        IFS=,
        for item in ${image_list}; do
            image_pull_list+=("${item}")
        done
    elif [ -n "${image_file}" ]; then
        local item
        local contain_space_exp="[[:blank:]]+"
        local contain_jing_exp="^[[:blank:]]*#"
 
        while IFS=$'\n' read -r item; do
            if [[ "${#item}" -gt 0 ]] && [[ ! "${item}" =~ ${contain_space_exp} ]] && [[ ! "${item}" =~ ${contain_jing_exp} ]]; then
                image_pull_list+=("${item}")
            fi
        done <"${image_file}"
    fi
 
    local image pull_status image_tag push_status
 
    declare -a failed_images
    declare -a succeed_images
    declare -a pushed_images
 
    failed_images=()
    succeed_images=()
    pushed_images=()
 
    local arepo_exp1 arepo_exp2
    arepo_exp1="^([a-z0-9])([a-z0-9\.\/\-])+(\/)([a-z0-9])+$"
    arepo_exp2="^([a-z0-9])([a-z0-9\.\/\-])+(\/)([a-z0-9])+(\/)$"
 
    local brepo_exp1 brepo_exp2
    brepo_exp1="^([a-z0-9])([a-z0-9\.\-])+([a-z0-9])$"
    brepo_exp2="^([a-z0-9])([a-z0-9\.\-])+(\/)$"
 
    IFS=$' \n\t'
    for image in "${image_pull_list[@]}"; do
        echo
        echo -e "${lv_color}开始拉取镜像 ${bai_color}${image} ${lv_color}...${normal_color}"
        sleep 2
        docker image pull --platform "${target_arch}" "${image}"
        pull_status="$?"
 
        if [ "${pull_status}" -ne 0 ]; then
            echo
            echo -e "${hong_color}Bad: ${bai_color}镜像 ${image} 拉取失败...${normal_color}"
            failed_images+=("${image}")
            continue
        else
            echo
            echo -e "${lv_color}Good: ${bai_color}镜像 ${image} 拉取完毕...${normal_color}"
            succeed_images+=("${image}")
 
            if [ "${enable_tag}" == "1" ]; then
                if [[ "${repo_domain}" =~ ${arepo_exp1} ]]; then
                    image_tag="${repo_domain}/${image##*/}"
                elif [[ "${repo_domain}" =~ ${arepo_exp2} ]]; then
                    image_tag="${repo_domain}${image##*/}"
                elif [[ "${repo_domain}" =~ ${brepo_exp1} ]]; then
                    image_tag="${repo_domain}/library/${image##*/}"
                elif [[ "${repo_domain}" =~ ${brepo_exp2} ]]; then
                    image_tag="${repo_domain}library/${image##*/}"
                else
                    echo -e "${hong_color}Error: ${bai_color}糟糕的镜像仓库域名 ${lv_color}${repo_domain} ${bai_color}，请检查后重试...${normal_color}"
                    exit 1
                fi
 
                echo
                echo -e "${lv_color}开始标记 ${bai_color}${image} ${lv_color}为${bai_color} ${image_tag} ${lv_color}...${normal_color}"
                docker image tag "${image}" "${image_tag}"
 
                # NOTE: 如果启用 --push，则推送镜像
                if [ "${enable_push}" == "1" ]; then
                    echo
                    echo -e "${lv_color}开始推送 ${bai_color}${image_tag} ${lv_color}...${normal_color}"
                    docker image push "${image_tag}"
                    push_status="$?"
 
                    if [ "${push_status}" -ne 0 ]; then
                        echo
                        echo -e "${hong_color}Error: ${bai_color}镜像 ${image_tag} 推送失败，操作终止，请排查原因后继续...${normal_color}"
                        exit 1
                    else
                        pushed_images+=("${image_tag}")
                    fi
                fi
            fi
        fi
    done
 
    # 输出操作结果概览
    echo
    print_logo
 
    if [ "${#succeed_images[@]}" -ne 0 ]; then
        echo
        echo -e "${lv_color}成功的镜像列表:${normal_color}"
        echo -e "--------------------------------------"
 
        IFS=$' \n\t'
        for item in "${succeed_images[@]}"; do
            echo -e "${item}"
        done
    fi
 
    if [ "${#failed_images[@]}" -ne 0 ]; then
        echo
        echo -e "${hong_color}失败的镜像列表:${normal_color}"
        echo -e "--------------------------------------"
 
        IFS=$' \n\t'
        for item in "${failed_images[@]}"; do
            echo -e "${item}"
        done
    fi
 
    if [ "${#pushed_images[@]}" -ne 0 ]; then
        echo
        echo -e "${hong_color}新的镜像列表:${normal_color}"
        echo -e "--------------------------------------"
 
        IFS=$' \n\t'
        for item in "${pushed_images[@]}"; do
            echo -e "${item}"
        done
    fi
 
    # NOTE:生成构建报告log
    {
        if [ "${#succeed_images[@]}" -ne 0 ]; then
            echo
            echo -e "成功的镜像列表:"
            echo -e "--------------------------------------"
 
            IFS=$' \n\t'
            for item in "${succeed_images[@]}"; do
                echo -e "${item}"
            done
        fi
 
        if [ "${#failed_images[@]}" -ne 0 ]; then
            echo
            echo -e "失败的镜像列表:"
            echo -e "--------------------------------------"
 
            IFS=$' \n\t'
            for item in "${failed_images[@]}"; do
                echo -e "${item}"
            done
        fi
 
        if [ "${#pushed_images[@]}" -ne 0 ]; then
            echo
            echo -e "新的镜像列表:"
            echo -e "--------------------------------------"
 
            IFS=$' \n\t'
            for item in "${pushed_images[@]}"; do
                echo -e "${item}"
            done
        fi
    } >"${work_dir:?}/build.log"
}
 
#######################################
# 检查docker是否安装
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   none
# Returns:
#   1: 表示没有安装或没有运行
#   0: 表示一切正常，可以继续
#######################################
function check_if_docker_installed() {
 
    local docker_pid_num
 
    docker_pid_num="$(ps -ef | awk '{if ($8 ~ "dockerd$") {k++}} END{print k}')"
 
    if ! type docker >/dev/null 2>&1; then
        return 1
    fi
 
    if [[ "${docker_pid_num:-0}" -eq 0 ]]; then
        return 1
    fi
 
    return 0
}
 
#######################################
# 脚本的入口，程序执行的起点函数main
# Globals:
#   none
# Arguments:
#   "$@"
# Outputs:
#   none
# Returns:
#   none
#######################################
function main() {
 
    init_global_vars
 
    if ! check_if_docker_installed; then
        echo -e "${hong_color}Error: ${bai_color}docker 没有安装或没有运行，不能继续...${normal_color}"
        exit 1
    fi
 
    get_user_option_paramater "$@"
    check_paramater_to_work
    pull_image_from_docker
}
 
main "$@"
