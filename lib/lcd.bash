
lcd_init() {
    if [[ ${#} -ne 2 ]]; then
        echo "fail"
        return
    fi
    host="${1}"
    port="${2}"

    exec 3<>/dev/tcp/${host}/${port}
    if [[ ${?} -ne 0 ]]; then
        echo_error "Could not connect to ${host}:${port}"
        return 1
    fi

    if [[ ${?} -eq 0 ]]; then
        echo "hello" >&3
        response=$(lcd_get_response)
        export LCD_WIDTH=$(lcd_parse_info "${response}" "wid")
        export LCD_HEIGHT=$(lcd_parse_info "${response}" "hgt")
        export LCD_CELL_WIDTH=$(lcd_parse_info "${response}" "cellwid")
        export LCD_CELL_HEIGHT=$(lcd_parse_info "${response}" "cellhgt")
    else
        echo_error "Failed to initialize LCD connection!"
        return 1
    fi

    echo "screen_add s1" >&3
    echo "widget_add s1 w1 string" >&3
    echo "widget_add s1 w2 string" >&3
    echo "widget_add s1 w3 string" >&3
    echo "widget_add s1 w4 string" >&3

#    while true; do
#        response=$(lcd_get_response 1)
#        if [[ ${?} -eq 3 ]]; then
#            break
#        fi
#
#    done

    echo_info "Initialized LCD session on ${host}:${port}"
}

lcd_parse_info() {
    sed "s/.* ${2} \([0-9.]*\).*/\1/g" <<< "${1}"
}

lcd_msg_loop() {
    while true; do
        response=$(lcd_get_response)
        if [[ ${?} -ne 0 ]]; then
            echo "${response}"
        fi
    done
}

lcd_get_response() {
    timeout=0
    response=""

    if [[ -n ${1} ]]; then
        timeout=${1}
        read -u 3 -t "${timeout}" response
        if [[ ${?} -eq 1 ]]; then
            # Timed out
            return 3
        fi
    else
        read -u 3 response
    fi

    echo "${response}"

    if [[ "${response}" == "success" ]]; then
        return 0
    elif [[ "${response}" =~ "^huh?" ]]; then
        # Error
        return 1
    else
        # Other message (keypress etc)
        return 2
    fi
}

lcd_show() {
    text="${1}"

    if [[ ! -t 0 ]]; then
        # Text was piped into the function
        text="$(cat 2> /dev/null)"
    fi

    counter=1
    echo "${text}" | while IFS= read -r line; do
        echo "widget_set s1 w${counter} 1 ${counter} \"${line}\"" >&3
        lcd_get_response
        (( counter++ ))
        if (( counter > 4 )); then
            break
        fi
    done
}

lcd_show_line() {
    line_num="${1}"
    text="${2}"

    if [[ ! -t 0 ]]; then
        # Text was piped into the function
        text="$(cat 2> /dev/null)"
    fi

    echo "widget_set s1 w${line_num} 1 ${line_num} \"${text}\"" >&3
    lcd_get_response
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

echo_info() {
    echo_color 34 "[>] ${*}"
}

echo_error() {
    echo_color 31 "[X] ${*}"
}

die() {
    echo_error "${@}"
    exit 1
}
