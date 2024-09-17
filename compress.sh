#!/bin/bash

setup_shortcut() {
    local script_path="$(readlink -f "$0")"
    local link_path="/usr/local/bin/yasuo"

    if [ ! -L "$link_path" ] || [ "$(readlink -f "$link_path")" != "$script_path" ]; then
        ln -sf "$script_path" "$link_path"
        chmod +x "$link_path"
        echo "快捷命令 yasuo 已创建。"
    fi
}

install_build_tools() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                 apt-get update
                 apt-get install -y build-essential
                ;;
            centos|fedora|rhel)
                 yum groupinstall -y "Development Tools" || dnf groupinstall -y "Development Tools"
                ;;
            arch)
                 pacman -S --noconfirm base-devel
                ;;
            *)
                echo "未知的发行版，请手动安装 'make' 和相关的编译工具."
                exit 1
                ;;
        esac
    else
        echo "无法确定系统类型，请手动安装 'make' 和相关的编译工具."
        exit 1
    fi
}

install_rar_from_source() {
    if ! command -v make &> /dev/null; then
        echo "'make' 未安装，正在安装必要的编译工具..."
        install_build_tools
    fi

    echo "正在从官方网站下载 RAR..."
    wget -O rarlinux.tar.gz https://www.rarlab.com/rar/rarlinux-x64-623.tar.gz

    if [ $? -ne 0 ]; then
        echo "下载失败，请检查网络连接。"
        exit 1
    fi

    echo "解压 RAR..."
    tar -xzf rarlinux.tar.gz

    cd rar || exit
    make install

    if [ $? -eq 0 ]; then
        echo "RAR 安装成功！"
    else
        echo "安装失败，请手动检查。"
        exit 1
    fi

    cd ..
    rm -rf rar rarlinux.tar.gz
}

install_tool() {
    local tool=$1
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                apt-get update
                if [ "$tool" = "rar" ] || [ "$tool" = "unrar" ]; then
                    if ! apt-get install -y unrar rar; then
                        echo "Debian/Ubuntu 官方源中未找到 $tool 包。尝试从官方网站下载安装。"
                        install_rar_from_source
                    fi
                elif [ "$tool" = "7z" ]; then
                    apt-get install -y p7zip-full
                else
                    apt-get install -y "$tool"
                fi
                ;;
            centos|fedora|rhel)
                if [ "$tool" = "rar" ]; then
                    yum install -y epel-release && yum install -y rar unrar || dnf install -y rar unrar
                elif [ "$tool" = "7z" ]; then
                    yum install -y p7zip || dnf install -y p7zip
                else
                    yum install -y "$tool" || dnf install -y "$tool"
                fi
                ;;
            arch)
                if [ "$tool" = "rar" ]; then
                    pacman -S --noconfirm rar
                elif [ "$tool" = "7z" ]; then
                    pacman -S --noconfirm p7zip
                else
                    pacman -S --noconfirm "$tool"
                fi
                ;;
            *)
                echo "未知的发行版，请手动安装 '$tool'."
                ;;
        esac
    else
        echo "无法确定系统类型，请手动安装 '$tool'."
    fi
}

check_tool() {
    local tool=$1
    if ! command -v $tool &> /dev/null; then
        echo "未检测到 '$tool'，需要安装。"
        read -p "是否安装 '$tool'? (y/n): " choice
        case "$choice" in
            y|Y) install_tool "$tool" ;;
            n|N) echo "跳过安装 '$tool'." ;;
            *) echo "无效选择，跳过安装 '$tool'." ;;
        esac
    fi
}

# 检查所需工具
check_tool "zip"
check_tool "unzip"
check_tool "rar"
check_tool "unrar"
check_tool "7z"
check_tool "tar"

# 显示菜单
echo "请选择操作类型:"
echo "1. 压缩"
echo "2. 解压"

read -p "请输入选项号: " op_type

case $op_type in
    1)
        echo "请选择要压缩的文件或文件夹（支持多个，以空格分隔）："
        read -r -a files_to_compress

        for file in "${files_to_compress[@]}"; do
            if [ ! -e "$file" ]; then
                echo "提示：没有找到文件或文件夹 '$file'，请重新输入!"
                exit 1
            fi
        done

        if [ ${#files_to_compress[@]} -eq 1 ]; then
            timestamp=$(date +"%Y%m%d_%H%M%S")
            base_name=$(basename "${files_to_compress[0]}")
            output_file="${base_name}_${timestamp}"
        else
            read -p "请输入压缩文件名（不含扩展名）：" output_file
            if [ -z "$output_file" ]; then
                echo "提示：压缩文件名不能为空，程序退出."
                exit 1
            fi
        fi

        echo "请选择压缩算法:"
        echo "1. zip"
        echo "2. rar"
        echo "3. 7z"
        echo "4. tar (gzip)"
        echo "5. tar (bz2)"
        echo "6. tar (xz)"

        read -p "请输入选项号: " algorithm

        case $algorithm in
            1) compress_algorithm="zip" ;;
            2) compress_algorithm="rar" ;;
            3) compress_algorithm="7z" ;;
            4) compress_algorithm="tar_gzip" ;;
            5) compress_algorithm="tar_bz2" ;;
            6) compress_algorithm="tar_xz" ;;
            *) echo "无效选项，默认使用zip"; compress_algorithm="zip" ;;
        esac

        echo "提示：正在压缩..."
        case $compress_algorithm in
            zip)
                zip -rq "${output_file}.zip" "${files_to_compress[@]}"
                if [ $? -eq 0 ]; then
                    echo "压缩完成!"
                else
                    echo "压缩失败!"
                fi
                ;;
            rar)
                rar a "${output_file}.rar" "${files_to_compress[@]}"
                if [ $? -eq 0 ]; then
                    echo "压缩完成!"
                else
                    echo "压缩失败!"
                fi
                ;;
            7z)
                7z a "${output_file}.7z" "${files_to_compress[@]}"
                if [ $? -eq 0 ]; then
                    echo "压缩完成!"
                else
                    echo "压缩失败!"
                fi
                ;;
            tar_gzip)
                tar -czf "${output_file}.tar.gz" "${files_to_compress[@]}"
                if [ $? -eq 0 ]; then
                    echo "压缩完成!"
                else
                    echo "压缩失败!"
                fi
                ;;
            tar_bz2)
                tar -cjf "${output_file}.tar.bz2" "${files_to_compress[@]}"
                if [ $? -eq 0 ]; then
                    echo "压缩完成!"
                else
                    echo "压缩失败!"
                fi
                ;;
            tar_xz)
                tar -cJf "${output_file}.tar.xz" "${files_to_compress[@]}"
                if [ $? -eq 0 ]; then
                    echo "压缩完成!"
                else
                    echo "压缩失败!"
                fi
                ;;
        esac

    ;;
    2)
        echo "请选择要解压的文件（支持多个，以空格分隔）："
        read -r -a files_to_decompress

        for file in "${files_to_decompress[@]}"; do
            if [ ! -f "$file" ]; then
                echo "提示：没有找到文件 '$file'，请重新输入!"
                exit 1
            fi
        done

        echo "请选择解压选项:"
        echo "1. 解压到当前目录"
        echo "2. 指定解压目录"

        read -p "请输入选项号: " decomp_option

        case $decomp_option in
            1)
                echo "提示：正在解压..."
                for file in "${files_to_decompress[@]}"; do
                    case ${file##*.} in
                        zip) unzip -q "$file" ;;
                        rar) unrar e -q "$file" ;;
                        7z) 7z x -y "$file" ;;
                        tar) tar -xf "$file" ;;
                        gz) tar -xzf "$file" ;;
                        bz2) tar -xjf "$file" ;;
                        xz) tar -xJf "$file" ;;
                        *) echo "未知文件格式: $file" ;;
                    esac
                done
                echo "解压完成!"
                ;;
            2)
                echo "请输入解压目录："
                read -r decomp_dir

                if [ ! -d "$decomp_dir" ]; then
                    read -p "提示：没有找到该目录，是否创建新目录？(y/n) " choice
                    case $choice in
                        y|Y) mkdir -p "$decomp_dir" ;;
                        n|N) echo "提示：解压失败!"; exit 1 ;;
                        *) echo "提示：无效选择，解压失败!"; exit 1 ;;
                    esac
                fi

                echo "提示：正在解压..."
                for file in "${files_to_decompress[@]}"; do
                    case ${file##*.} in
                        zip) unzip -q "$file" -d "$decomp_dir" ;;
                        rar) unrar e -q "$file" "$decomp_dir" ;;
                        7z) 7z x -y "$file" -o"$decomp_dir" ;;
                        tar) tar -xf "$file" -C "$decomp_dir" ;;
                        gz) tar -xzf "$file" -C "$decomp_dir" ;;
                        bz2) tar -xjf "$file" -C "$decomp_dir" ;;
                        xz) tar -xJf "$file" -C "$decomp_dir" ;;
                        *) echo "未知文件格式: $file" ;;
                    esac
                done
                echo "解压完成!"
                ;;
            *) echo "无效选项，解压失败!"; exit 1 ;;
        esac
    ;;
    *) echo "无效选项，程序退出."; exit 1 ;;
esac
