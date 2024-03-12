#!/bin/sh

export TEST_FILE=$0

if [[ "`basename $0`" = "tesht.sh" ]]; then
    declare -i failed_tests=0
    declare -i run_tests=0
    echo "tesht - the swabian housewife's testing framework"
    echo Running tests...

    shopt -s nullglob
    for t in ${1:-tests}/test-*; do
        if [[ -x "$t" ]]; then
            run_tests+=1
            echo && $t
            if [[ $? -gt 0 ]]; then
                failed_tests+=1
            fi
        fi
    done
    shopt -u nullglob

    if [[ $run_tests -eq 0 ]]; then
        echo "No tests found."
    fi


    exit $failed_tests
fi

MOCKS+=()
declare -gi assertions=0
declare -i failures=0

__gray() {
    echo "\e[90m$*\e[0m"
}

__red() {
    echo "\e[31m$*\e[0m"
}

__green() {
    echo "\e[32m$*\e[0m"
}

echo -e "`__gray $TEST_FILE`"


__cleanup() {
    if [[ $failures -eq 0 ]]; then
        echo -e "`__green SUCCESS` ($assertions/$assertions assertions passed)"
    else 
        echo -e "`__red FAILURE` (`expr $assertions - $failures`/$assertions assertions passed)"
    fi

    for mock in ${MOCKS[*]} ; do
        [[ -f $mock ]] && rm $mock
    done

    exit $failures
}

trap "__cleanup" EXIT

contains() {
    grep -- "$1" >/dev/null
}

__print_reference() {
    caller $1 | awk '{ print $3":"$1 }'
}

__fail() {
    failures+=1
    local -i stack_depth=`expr $2 + 1`
    local reference=`__print_reference $stack_depth`
    echo -e "`__red ✗` $1\n`__gray $reference`" 1>&2

}

__assert() {
    local result=$?
    assertions+=1
    if [ ! "$result" -eq 0 ]
    then
        __fail "$1" 2
    fi
}

assert() {
    __assert "$1"
}

assert_fail() {
    false
    __assert "$1"
}

assert_contains() {
    local input=`cat`
    echo "$input" | contains "$1"
    __assert "\"$input\" contains \"$1\""
}

__mock_trace() {
    echo "${*:2}" >> "$1"
}

make_mock() {
    local mock=`mktemp`
    echo $mock
}

__noop() {
    :
}

mock() {
    local mock="$1"
    local name="$2"
    local mock_fn="${3:-"__noop"}"
    local impl="function $name() { __mock_trace \"$mock\" \"\$@\"; $mock_fn \$@; }"
    eval $impl
    export -f "$name" "$mock_fn"

    MOCKS+=("$mock")
    echo $name > $mock
}

mock_name() {
    head -n 1 "$1"
}

mock_calls() {
    tail -n +2 "$1"
}

mock_reset() {
    local mock=$1
    local name=`mock_name "$mock"`
    echo "$name" > "$mock"
}

assert_called() {
    local name=`mock_name "$1"`
    [[ "`mock_calls "$1" | wc -l`" -gt 0 ]]
    __assert "$name was called"
}

assert_called_with() {
    local mock="$1"
    local name=`mock_name "$mock"`
    local calls=`mock_calls "$mock"`
    echo "$calls" | while IFS= read -r call ; do 
        (for arg in "${@:2}" ; do
            echo "$call" | contains "$arg" || exit 1
        done) && break
        false
    done
    __assert "$name was called with args\nExpected:\n${*:2}\nActual:\n$calls"
}

export -f __mock_trace
