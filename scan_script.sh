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
#    (If RL_STORE is configured you must also configure RL_PACKAGE and vice versa)
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

verify_paths()
{
    [ -z "${REPORT_PATH}" ] && {
        msg="FATAL: 'REPORT_PATH' is not specified"
        fatal "$msg"
    }
    if rmdir "${REPORT_PATH}"
    then

    else

    fi
    mkdir -p "${REPORT_PATH}"

    [ -f "./${PACKAGE_PATH}/${MY_ARTIFACT_TO_SCAN}" ] || {
        msg="missing artifact to scan: no file found at: ${PACKAGE_PATH}/${MY_ARTIFACT_TO_SCAN}"
        fatal "$msg"
    }
}

run_scan_nostore()
{
    rl-scan \
        --package-path="./${PACKAGE_PATH}/${MY_ARTIFACT_TO_SCAN}" \
        --report-path="${REPORT_PATH}" \
        --report-format=all 1>1 2>2
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
    # show stdout of the scan command
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
    if [ -z "${RL_STORE}" ]
    then
        run_scan_nostore
    else
        run_scan_withstore
    fi
    get_scan_result_or_fail
    process_scan_result
}

main
