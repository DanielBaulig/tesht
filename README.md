# tesht 

*The [Swabian Housewife's](https://www.wikidata.org/wiki/Q19307530) Testing Framework*

`tesht` is a minimalist and thrifty shell script testing framework. I had the need
to test some simple shell scripts and didn't want to pull in testing frameworks
that are ten to a hrundred times the size of the actual code I am testing, so I
wrote tesht.

## Usage

tests/test-mytest.sh
```tests/test-mytest.sh
source ../lib/tesht.sh

../myscript.sh
assert "../myscript exits without an error code"
```

```
> lib/tesht.sh tests/
```

## Features

### Return code assertions

The core building block for all assertions in tesht is a generic return code
assertion `assert`.

```test-mytest.sh
source ../lib/tesht.sh

true
assert "Will pass"

false
assert "Will fail"

[[ -f "file.txt" ]]
assert "Will fail if file.txt doesn't exist"
```

### Mocks
tesht will help you with mocking and tracking calls to functions and other
commands using it's simple mock implementation.

```test-mytest.sh
source ../lib/tesht.sh

function mock_ip_impl() {
    # By defining a mock implementation we can control the behavior of our mock
    case "$@" in
        "route")
            # myscript_using_ip.sh will query ip route to see if a specific
            # route exists. So echo a table without that specific route
            echo "default via 10.0.0.1 dev eth0 proto kernel"
            ;;
    esac
    # All other invokcations will not print anything
}

ip_mock=`make_mock ip mock_ip_impl`

../myscript_using_ip.sh

# Make sure a new route was added by myscript_using_ip.sh
assert_called_with $ip_mock "route add 192.168.0.0/24"
```
