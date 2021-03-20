# whmcs-inbound-piped


## Local testing

```bash
$ make build
$ ./whms-inbound-piped
```

```bash
$ echo 'Message body' | \
  docker run -it --rm s-nail \
    -vv \
    --set=mta='smtp://host.docker.internal' \
    --subject='A subject' \
    'Foobar <foobar@host.docker.internal>'
```
