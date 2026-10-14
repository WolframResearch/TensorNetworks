#!/bin/bash
# wolframscript with its arguments, retried for a minute on exit 255:
# a transient activation refusal ("No valid password found") in the CI container
for attempt in $(seq 1 60); do
    echo "::group::wolframscript attempt $attempt"
    wolframscript "$@"
    rc=$?
    echo "::endgroup::"
    [ "$rc" -ne 255 ] && exit "$rc"
    sleep 1
done
exit 255
