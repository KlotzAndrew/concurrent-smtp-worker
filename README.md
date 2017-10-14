# SmtpTest

```shell
export SMTP_USERNAME=
export SMTP_PASSWORD=
export SMTP_HOSTNAME=127.0.0.1
export SMTP_PORT=1025
```

uses mailcatcher
```shell
gem install mailcatcher
mailcatcher
# visit http://127.0.0.1:1080/
# send mail to smtp://127.0.0.1:1025
```

starting the app
```shell
mix deps.get
mix phx.server
```

