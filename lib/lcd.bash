#!/usr/bin/env bash
################################################################################
# lcdsh - A small bash 'library' for manipulating LCD displays driven by
# LCDproc.
#
# Version 1
# Matthew Malensek <matt@malensek.net>
################################################################################


# lcd_init hostname [port]
# Where:
# - hostname is the host driving the LCD
# - port is the port of the LCDproc server (default: 13666)
# Returns:
# - 0 on success, nonzero on failure
#
# This function initializes the LCD. This involves:
# - Connecting to the host driving the LCD
# - Gathering LCD parameters (width, height, etc). These are exported as:
#     > LCD_WIDTH
#     > LCD_HEIGHT
#     > LCD_CELL_WIDTH
#     > LCD_CELL_HEIGHT
# - Creating a screen object and the necessary text widgets (one per line)
lcd_init() {
    port=13666

    [[ -n ${LCD_HOST} ]] && host="${LCD_HOST}"
    [[ -n ${LCD_PORT} ]] && port="${LCD_PORT}"
    [[ -n ${1} ]] && host="${1}"
    [[ -n ${2} ]] && port="${2}"

    if [[ -z ${host} || -z ${port} ]]; then
        echo_error "Usage: lcd_init hostname [port]"
        echo_error "Default port: ${port}"
        echo_error "(or set LCD_HOST/LCD_PORT environment variables)"
        return 1
    fi

    if ! exec 3<>"/dev/tcp/${host}/${port}"; then
        echo_error "Could not connect to ${host}:${port}"
        return 1
    fi

    export LCD_WIDTH
    export LCD_HEIGHT
    export LCD_CELL_WIDTH
    export LCD_CELL_HEIGHT

    echo "hello" >&3
    response=$(lcd_get_response)
    LCD_WIDTH=$(lcd_parse_info "${response}" "wid")
    LCD_HEIGHT=$(lcd_parse_info "${response}" "hgt")
    LCD_CELL_WIDTH=$(lcd_parse_info "${response}" "cellwid")
    LCD_CELL_HEIGHT=$(lcd_parse_info "${response}" "cellhgt")

    echo "screen_add s1" >&3

    for (( i = 1; i <= LCD_HEIGHT; ++i )); do
        echo "widget_add s1 w${i} string" >&3
    done

    echo_info "Initialized LCD session on ${host}:${port}" \
        "(${LCD_WIDTH}x${LCD_HEIGHT})"
    return 0
}

lcd_parse_info() {
    sed "s/.* ${2} \([0-9.]*\).*/\1/g" <<< "${1}"
}

lcd_msg_loop() {
    while true; do
        if ! kill -0 "${PPID}"; then
            echo "parent dead"
        fi

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
        IFS= read -r -u 3 -t "${timeout}" response
        if [[ ${?} -eq 1 ]]; then
            # Timed out
            return 3
        fi
    else
        IFS= read -r -u 3 response
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
        if (( counter > LCD_HEIGHT )); then
            break
        fi
    done
}

lcd_show_line() {
    line_num="${1}"
    if [[ ${line_num} -le 0 || ${line_num} -gt ${LCD_HEIGHT} ]]; then
        echo_error "Specified line (${line_num}) out of LCD bounds"
        return
    fi
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
        echo "${*}"
        return 0
    fi

    echo -e $'\e[0;'"${color}"'m'"${*}"$'\e[0m'
}

echo_info() {
    echo_color 34 "[>] ${*}"
}

echo_error() {
    echo_color 31 "[X] ${*}"
}

die() {
    echo_error "${*}"
    exit 1
}
