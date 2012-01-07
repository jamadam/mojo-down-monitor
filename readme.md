MojoDownMonitor 0.01 ALPHA
---------------

## DESCRIPTION

This is a web monitoring tool to detect your sites down.

MojoDownMonitor gets multiple URIs in regular basis and checks if the response
fulfills given conditions. 

![Site list](./screenshot/01.jpg "Site list")

![Site edit](./screenshot/02.jpg "Site edit")

![Site log](./screenshot/03.jpg "Site log")

## INSTALLATION

To install this module, run the following commands:

    $ perl Makefile.PL
    $ make
    $ make test
    $ make install

## GETTING STARTED

    $ hypnotoad ./script/mojo_down_monitor
    Server available at http://127.0.0.1:8010.

    $ hypnotoad ./script/mojo_down_monitor --stop

Copyright (c) 2011 [jamadam]
[jamadam]: http://blog2.jamadam.com/

Dual licensed under the MIT and GPL licenses:

- [http://www.opensource.org/licenses/mit-license.php]
- [http://www.gnu.org/licenses/gpl.html]
[http://www.opensource.org/licenses/mit-license.php]: http://www.opensource.org/licenses/mit-license.php
[http://www.gnu.org/licenses/gpl.html]:http://www.gnu.org/licenses/gpl.html
