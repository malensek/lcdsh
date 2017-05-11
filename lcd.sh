
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
}

lcd_parse_info() {
    sed "s/.* ${2} \([0-9.]*\).*/\1/g" <<< "${1}"
}

