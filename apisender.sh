#!/bin/bash

##############################################################################
# Definations
##############################################################################

server_ip="192.168.0.1"
server_port="443"
request_payload=""
request_uri=""

############################### Account ######################################
username="admin"
password="admin"
login_uri="/admin/login.jsp"

##############################################################################
# Library Functions
##############################################################################

is_failed()
{
    local login_failed_string="Login information is incorrect"
    local login_error_string="to see errors in the browser"
    local file="$1"
    
    cat $file | grep "$login_failed_string"
    if [ $? = 0 ]; then
        echo "See \"$login_failed_string\", exit."
        exit 1;
    fi
    cat $file | grep "$login_error_string"
    if [ $? = 0 ]; then
        echo "See \"$login_error_string\", should try different \"user_dir\"."
        return 2
    fi
    
    return 0
}

do_cleanup()
{
    rm -f /tmp/header_out
    rm -f /tmp/cookies
    rm -f /tmp/resjsp
}

send_request() {
    do_cleanup

    if [ "${server_port}" = "80" ]; then
        url_head="http://"
    else
        url_head="https://"
    fi

    # for "/user/guestinfo.jsp" request, need use "/user/user_login_guestpass.jsp" to login.
    if [ -n "$request_uri" ]; then
        if [ "${request_uri#/user/guestinfo.jsp}" != "$request_uri" ]; then
            login_uri="/user/user_login_guestpass.jsp"
        fi
    fi

    login_url="${url_head}${server_ip}:${server_port}${login_uri}"
    echo "LoginUrl:    ${login_url}"

    if [ -n "${request_uri}" ]; then
        request_url="${url_head}${server_ip}:${server_port}${request_uri}"
    elif [[ "${request_payload}" =~ 'action="getstat"' ]] || [[ "${request_payload}" =~ 'action="docmd"' ]]; then
        request_url="${url_head}${server_ip}:${server_port}/admin/_cmdstat.jsp"
    else
        request_url="${url_head}${server_ip}:${server_port}/admin/_conf.jsp"
    fi
    echo "RequestUrl:  ${request_url}"

    # Assign empty value to csrf_token
    csrf_token=""

    # If username is not empty, then do the login and retrieve the CSRF token
    if [ -n "${username}" ]; then
        curl -k -c /tmp/cookies -L -s -X POST -d "action=login.jsp&username=${username}&password=${password}&ok=whatever" -v -o /tmp/resjsp "${login_url}" 2> /tmp/header_out
        is_failed "/tmp/resjsp"

        csrf_token=`cat /tmp/resjsp | grep  "var csfrToken" | awk -F\' '{ print $2}' | awk -F\' '{ print $1}' | head -n 1`
        # get csrf token from header response, it is more graceful, but not compatible with non-admin account
        #csrf_token=`cat /tmp/header_out | grep HTTP_X_CSRF_TOKEN: | awk -F"HTTP_X_CSRF_TOKEN:  " '{print $2}' | tr -d '\r'`
        echo "CsrfToken:   ${csrf_token}"
    fi

    echo "Request: =========================================================="
    echo "${request_payload}"
    echo "Response: =========================================================="
    curl -k -b /tmp/cookies -X POST -H "X-CSRF-Token: ${csrf_token}" -d "${request_payload}" "${request_url}"
    echo -e "\n===================================================================="

    do_cleanup
}

test()
{
    server_ip="10.223.43.179"
    request_payload='<ajax-request action="getconf" comp="system" DECRYPT_X="true" ><identity /><tr069 /><unleashed-network /></ajax-request>'
    #request_payload=`cat ZD_API_tool_get_fm_token.xml`
    
    send_request
}

usage()
{
    echo "Usage: $0 server_ip username password request_payload [request_uri]"
    echo "    Example 1 \"Get system information with admin account\":"
    echo -n "       $0 "; echo '192.168.0.1 admin admin '\''<ajax-request action="getstat" comp="system" DECRYPT_X="true"><mgmt-ip/><sysinfo/></ajax-request>'\'
    echo "    Example 2 \"Create guestpass with user account\":"
    echo -n "       $0 "; echo '192.168.0.1 user user "" "/user/guestinfo.jsp?gentype=single&fullname=test-guestpass&key=ABCDE&guest-wlan=test-guest-wlan&duration=2&duration-unit=day_Days&email=test@gmail.com&phonenumber=&reauth=true&reauth-time=30&reauth-unit=min&&shared=true&limitnumber=5"'
    echo "    Example 3 \"Send request with external xml file\":"
    echo -n "       $0 "; echo '192.168.0.1 admin admin "$(cat get_ap_status.xml)"'
}

##############################################################################
# Start
##############################################################################

if [ "$#" -ge 4 ]; then
    server_ip="$1"
    username="$2"
    password="$3"
    request_payload="$4"
    if [ "$#" -ge 5 ]; then
        request_uri="$5"
    else
        request_uri=""
    fi
else
    usage
    exit
fi

send_request
