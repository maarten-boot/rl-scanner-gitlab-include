#! /bin/bash
# PARAMS:
# A) We expect the calling environment to define the License secrets required for rl-scanner
#  - RLSECURE_SITE_KEY:
#    must be declared as global variables type 'variable'
#  - RLSECURE_ENCODED_LICENSE:
#    must be declared as global variables type 'variable'
#
# B) We expect the calling pipeline to set the following 3 environment variables
# - MY_ARTIFACT_TO_SCAN:
#   The artifact we will be scanning (the file name)
# - PACKAGE_PATH:
#   The relative location (relative to the checkout) of the artifact we will scan,
#   we expect to find the artifact to scan at: ${PACKAGE_PATH}/${MY_ARTIFACT_TO_SCAN}
# - REPORT_PATH:
#   A location where the reports will be created, (relative to the checkout).
#   Best provide a empty directory as all data currently present in REPORT_PATH
#   will be deleted before the scan starts.
#
# C) We support a optional Proxy configuration,
# - RL_PROXY_SERVER: optional, string, default ''.
# - RL_PROXY_PORT: optional, string, default ''.
# - RL_PROXY_USER: optional, string, default ''.
# - RL_PROXY_PASSWORD: optional, string, default ''.
#
# D) If we have a local runner configured using the docker gitlab runner procedure,
#    we can store scan results local and optionally perform diff scan with:
#    (If RL_STORE is configured you must also configure RL_PACKAGE_URL and vice versa)
# - RL_STORE: optional, string, default ''.
# - RL_PACKAGE_URL: optional, string, default ''.
# - RL_DIFF_WITH: optional, string, default ''.
#
set +e # we handle errors ourselves in this script
fatal()
{
    local msg="$1"
    echo "${msg}" >&2
    DESCRIPTION="${msg}"
    STATUS="error"
    exit 101
}
verify_licence()
{
    [ -z "${RLSECURE_SITE_KEY}" ] && {
        msg="we require 'RSECURE_SITE_KEY' to exist as a env variable"
        fatal "${msg}"
    }
    [ -z "${RLSECURE_ENCODED_LICENSE}" ] && {
        msg="we require 'RLSECURE_ENCODED_LICENSE' to exist as a env variable"
        fatal "${msg}"
    }
}
prep_report()
{
    if [ -d "${REPORT_PATH}" ]
    then
        if rmdir "${REPORT_PATH}"
        then
            :
        else
            msg="FATAL: your current REPORT_PATH is not empty"
            DESCRIPTION="${msg}"
            STATUS="error"
            exit 101
        fi
    fi
    mkdir -p "${REPORT_PATH}"
}
verify_paths()
{
    [ -z "${REPORT_PATH}" ] && {
        msg="FATAL: 'REPORT_PATH' is not specified"
        fatal "$msg"
    }
    [ -f "./${PACKAGE_PATH}/${MY_ARTIFACT_TO_SCAN}" ] || {
        msg="missing artifact to scan: no file found at: ${PACKAGE_PATH}/${MY_ARTIFACT_TO_SCAN}"
        fatal "$msg"
    }
}
extractProjectFromPackageUrl()
{
    echo "${RL_PACKAGE_URL}" |
    awk '{
        sub(/@.*/,"")       # remove the @Version part
        split($0, a , "/")  # we expect $Project/$Package
        print a[1]          # print Project
    }'
}
extractPackageFromPackageUrl()
{
    echo "${RL_PACKAGE_URL}" |
    awk '{
        sub(/@.*/,"")       # remove the @Version part
        split($0, a , "/")  # we expect $Project/$Package
        print a[2]          # print Package
    }'
}
makeDiffWith()
{
    DIFF_WITH=""
    if [ -z "$RL_STORE" ]
    then
        return
    fi
    if [ -z "${RL_PACKAGE_URL}" ]
    then
        return
    fi
    if [ -z "${RL_DIFF_WITH}" ]
    then
        return
    fi
    # Split the package URL and find Project and Package
    Project=$( extractProjectFromPackageUrl )
    Package=$( extractPackageFromPackageUrl )
    if [ ! -d "$RL_STORE/.rl-secure/projects/${Project}/packages/${Package}/versions/${RL_DIFF_WITH}" ]
    then
        echo "That version has not been scanned yet: ${RL_DIFF_WITH} in Project: ${Project} and Package: ${Package}"
        echo "No diff scan will be executed, only ${RL_PACKAGE_URL} will be scanned"
        return
    fi
    DIFF_WITH="--diff-with=${RL_DIFF_WITH}"
}
prep_proxy_data()
{
    PROXY_DATA=""
    if [ ! -z "${RLSECURE_PROXY_SERVER}" ]
    then
        PROXY_DATA="${PROXY_DATA} -e RLSECURE_PROXY_SERVER=${RLSECURE_PROXY_SERVER}"
    fi
    if [ ! -z "${RLSECURE_PROXY_PORT}" ]
    then
        PROXY_DATA="${PROXY_DATA} -e RLSECURE_PROXY_PORT=${RLSECURE_PROXY_PORT}"
    fi
    if [ ! -z "${RLSECURE_PROXY_USER}" ]
    then
        PROXY_DATA="${PROXY_DATA} -e RLSECURE_PROXY_USER=${RLSECURE_PROXY_USER}"
    fi
    if [ ! -z "${RLSECURE_PROXY_PASSWORD}" ]
    then
        PROXY_DATA="${PROXY_DATA} -e RLSECURE_PROXY_PASSWORD=${RLSECURE_PROXY_PASSWORD}"
    fi
}
run_scan_nostore()
{
    rl-scan \
        ${PROXY_DATA} \
        --package-path="./${PACKAGE_PATH}/${MY_ARTIFACT_TO_SCAN}" \
        --report-path="${REPORT_PATH}" \
        --report-format=all 1>1 2>2
    RR=$?
}
run_scan_withstore()
{
    rl-scan \
        ${PROXY_DATA} \
        --rl-store="${RL_STORE}" \
        --purl="${RL_PACKAGE_URL}" \
        --replace \
        --package-path="./${PACKAGE_PATH}/${MY_ARTIFACT_TO_SCAN}" \
        --report-path="${REPORT_PATH}" \
        --report-format=all \
        ${DIFF_WITH} 1>1 2>2
    RR=$?
}
get_scan_result_or_fail()
{
    DESCRIPTION=$( grep 'Scan result:' 1 )
    [ -z "${DESCRIPTION}" ] && {
        # show stderr of the scan command on error
        echo "# StdErr:"
        cat 2
        echo
        echo "# StdOut:"
        cat 1
        echo
        msg="rl-scan exit with: $RR"
        fatal "${msg}"
    }
}
process_scan_result()
{
    echo "# StdOut:"
    cat 1
    echo
    STATUS="failed"
    [ "${RR}" == "0" ] && {
        STATUS="success"
    }
    echo "Status: ${STATUS}; ${DESCRIPTION}"
    exit ${RR}
}
main()
{
    verify_licence
    verify_paths
    prep_report
    prep_proxy_data
    makeDiffWith
    if [ -z "${RL_STORE}" ]
    then
        run_scan_nostore
    else
        run_scan_withstore
    fi
    get_scan_result_or_fail
    process_scan_result
}
main $*
