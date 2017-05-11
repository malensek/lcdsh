
lcd_init() {
    if [[ ${#} -ne 2 ]]; then
        echo "fail"
        return
    fi
    host="${1}"
    port="${2}"

    exec 3<>/dev/tcp/${host}/${port}

    if [[ ${?} -eq 0 ]]; then
        echo "hello" >&3
        response=$(lcd_get_response)
        export LCD_WIDTH=$(lcd_parse_info "${response}" "wid")
        export LCD_HEIGHT=$(lcd_parse_info "${response}" "hgt")
        export LCD_CELL_WIDTH=$(lcd_parse_info "${response}" "cellwid")
        export LCD_CELL_HEIGHT=$(lcd_parse_info "${response}" "cellhgt")
    else
        echo "fail"
        return 1
    fi

    echo "initialized!"
}

lcd_parse_info() {
    sed "s/.* ${2} \([0-9.]*\).*/\1/g" <<< "${1}"
}

lcd_get_response() {
    timeout=0
    if [[ -n ${1} ]]; then
        timeout=${1}
    fi
    read -u 3 response
    echo "${response}"
}

echo_color() {
    color="${1}"
    shift 1
    num_colors=$(tput colors 2> /dev/null)
    if [[ ! -t 1 || ${num_colors} -lt 8 ]]; then
        # Not a terminal; print without color
        echo "${@}"
        return 0
    fi

    echo -e $'\e[0;'${color}'m'${@}$'\e[0m'
}
