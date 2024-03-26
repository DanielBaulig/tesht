#!/bin/bash

__gray() {
    echo "\033[90m$*\033[0m"
}

__red() {
    echo "\033[31m$*\033[0m"
}

__green() {
    echo "\033[32m$*\033[0m"
}

if [[ "$(basename $0)" = "tesht.sh" ]]; then
    declare -i failed_tests=0
    declare -i run_tests=0
    echo "tesht - the swabian housewife's testing framework"
    echo Running tests...

    export TESHT_MOCK_PATH=$(mktemp -d)
    export PATH=$TESHT_MOCK_PATH:$PATH

    shopt -s nullglob
    for t in ${1:-tests}/test-*; do
        if [[ -x "$t" ]]; then
            run_tests=$((run_tests + 1))
            echo ""
            echo -e "$(__gray $t)"


            $t 
            if [[ $? -ne 0 ]]; then
                failed_tests=$((failed_tests + 1))
            fi
        fi
    done
    shopt -u nullglob

    if [[ $run_tests -eq 0 ]]; then
        echo "No tests found."
    fi

    rm -rf $TESHT_MOCK_PATH


    exit $failed_tests
fi

MOCKS+=()
declare -i assertions=0
declare -i failures=0

__cleanup() {
    if [[ $failures -eq 0 ]]; then
        echo -e "$(__green SUCCESS) ($assertions/$assertions assertions passed)"
    else 
        echo -e "$(__red FAILURE) ($(expr $assertions - $failures)/$assertions assertions passed)"
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
    failures=$((failures +1))
    local -i stack_depth=`expr $2 + 1`
    local reference=`__print_reference $stack_depth`
    echo -e "$(__red ✗) $([[ $__ASSERT_FAILURE -ne 0 ]] && echo "Not ")$1\n$(__gray $reference)" 1>&2

}


__ASSERT_FAILURE=0
__assert() {
    local result=$?
    assertions=$((assertions + 1))
    if [[ "$__ASSERT_FAILURE" -eq 0 ]]
    then
      if [ "$result" -ne 0 ]
      then
          __fail "$1" 2
      fi
    else
      if [ "$result" -eq 0 ]
      then
          __fail "$1" 2
      fi
    fi
    __ASSERT_FAILURE=0
}

assert_not() {
  __ASSERT_FAILURE=$((1 - __ASSERT_FAILURE))
  $@
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

    local name="$1"
    local mock_fn="$2"
    local mock_impl=""
    if [[ ! -z $mock_fn ]]; then
      mock_impl="\n`declare -f $mock_fn`\n$mock_fn \$@"
    fi
    local impl="#!/bin/sh\n__mock_trace \"$mock\" \"\$@\"$mock_impl"
    echo -e "$impl" > $TESHT_MOCK_PATH/$name
    chmod u+x $TESHT_MOCK_PATH/$name

    MOCKS+=("$mock")
    echo $name > $mock

    echo $mock
}

__noop() {
    :
}

mock() {
    local mock="$1"
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
